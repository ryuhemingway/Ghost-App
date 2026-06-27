import Foundation
import Dispatch
import Darwin

final class GhostDesktopRAGWatcher: @unchecked Sendable {
    private let store: GhostRAGStore
    private let desktopURL: URL
    private let queue = DispatchQueue(label: "ghost.desktop-rag-watcher", qos: .utility)
    private let rescanIntervalNanoseconds: UInt64
    private let maxFiles: Int

    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var periodicTask: Task<Void, Never>?
    private var pendingSync: DispatchWorkItem?
    private var isRunning = false

    init(
        store: GhostRAGStore = GhostRAGStore(),
        desktopURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true),
        rescanInterval: TimeInterval = 900,
        maxFiles: Int = 20_000
    ) {
        self.store = store
        self.desktopURL = desktopURL
        self.rescanIntervalNanoseconds = UInt64(max(30, rescanInterval) * 1_000_000_000)
        self.maxFiles = maxFiles
    }

    func start(
        workspace: URL,
        onActivity: @escaping @Sendable (GhostActivityEntry) -> Void
    ) {
        queue.async { [weak self] in
            guard let self, !self.isRunning else { return }
            self.isRunning = true
            self.startFileSystemSource(workspace: workspace, onActivity: onActivity)
            self.scheduleSync(reason: "startup", workspace: workspace, delay: 0, onActivity: onActivity)
            self.startPeriodicRescan(workspace: workspace, onActivity: onActivity)
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.isRunning = false
            self.pendingSync?.cancel()
            self.pendingSync = nil
            self.periodicTask?.cancel()
            self.periodicTask = nil
            self.source?.cancel()
            self.source = nil
            if self.descriptor >= 0 {
                close(self.descriptor)
                self.descriptor = -1
            }
        }
    }

    private func startFileSystemSource(
        workspace: URL,
        onActivity: @escaping @Sendable (GhostActivityEntry) -> Void
    ) {
        descriptor = open(desktopURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            onActivity(GhostActivityEntry(kind: .error, title: "Desktop RAG watcher", detail: "Could not watch \(desktopURL.path)."))
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleSync(reason: "Desktop changed", workspace: workspace, delay: 2, onActivity: onActivity)
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.descriptor >= 0 else { return }
            close(self.descriptor)
            self.descriptor = -1
        }
        self.source = source
        source.resume()

        onActivity(GhostActivityEntry(kind: .info, title: "Desktop RAG watcher", detail: "Watching \(desktopURL.path)."))
    }

    private func startPeriodicRescan(
        workspace: URL,
        onActivity: @escaping @Sendable (GhostActivityEntry) -> Void
    ) {
        periodicTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self.rescanIntervalNanoseconds)
                if Task.isCancelled { break }
                self.scheduleSync(reason: "periodic rescan", workspace: workspace, delay: 0, onActivity: onActivity)
            }
        }
    }

    private func scheduleSync(
        reason: String,
        workspace: URL,
        delay: TimeInterval,
        onActivity: @escaping @Sendable (GhostActivityEntry) -> Void
    ) {
        pendingSync?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.syncDesktop(reason: reason, workspace: workspace, onActivity: onActivity)
        }
        pendingSync = item
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func syncDesktop(
        reason: String,
        workspace: URL,
        onActivity: @escaping @Sendable (GhostActivityEntry) -> Void
    ) {
        let result = store.syncFolder(
            path: desktopURL.path,
            recursive: true,
            removeMissing: true,
            maxFiles: maxFiles,
            workspace: workspace
        )

        let payload = result["payload"] as? [String: Any]
        let truncated = payload?["truncated"] as? Bool == true

        let title: String
        let kind: GhostActivityEntry.Kind
        if result["ok"] as? Bool == true {
            title = truncated ? "Desktop RAG synced (truncated)" : "Desktop RAG synced"
            kind = .success
        } else {
            title = "Desktop RAG sync failed"
            kind = .error
        }

        let detail: String
        if let summary = result["summary"] as? String {
            detail = truncated
                ? "\(reason): \(summary) (limit reached, some files omitted)"
                : "\(reason): \(summary)"
        } else {
            detail = result["error"] as? String ?? reason
        }
        onActivity(GhostActivityEntry(kind: kind, title: title, detail: detail))
    }
}
