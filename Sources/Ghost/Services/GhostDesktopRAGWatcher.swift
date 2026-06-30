import Foundation
import Dispatch
import Darwin

final class GhostDesktopRAGWatcher: @unchecked Sendable {
    private let store: GhostRAGStore
    private let queue = DispatchQueue(label: "ghost.desktop-rag-watcher", qos: .utility)
    private let rescanIntervalNanoseconds: UInt64
    private let maxFiles: Int

    private var watchedURL: URL?
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var periodicTask: Task<Void, Never>?
    private var pendingSync: DispatchWorkItem?
    private var isRunning = false

    init(
        store: GhostRAGStore = GhostRAGStore(),
        rescanInterval: TimeInterval = 900,
        maxFiles: Int = 20_000
    ) {
        self.store = store
        self.rescanIntervalNanoseconds = UInt64(max(30, rescanInterval) * 1_000_000_000)
        self.maxFiles = maxFiles
    }

    func start(
        watchedURL: URL,
        workspace: URL,
        onActivity: @escaping @Sendable (GhostActivityEntry) -> Void
    ) {
        queue.async { [weak self] in
            guard let self, !self.isRunning else { return }
            self.watchedURL = watchedURL
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
            self.watchedURL = nil
        }
    }

    private func startFileSystemSource(
        workspace: URL,
        onActivity: @escaping @Sendable (GhostActivityEntry) -> Void
    ) {
        guard let watchedURL else {
            onActivity(GhostActivityEntry(kind: .error, title: "RAG watcher", detail: "No folder selected."))
            return
        }

        descriptor = open(watchedURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            onActivity(GhostActivityEntry(kind: .error, title: "RAG watcher", detail: "Could not watch \(watchedURL.path)."))
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.scheduleSync(reason: "folder changed", workspace: workspace, delay: 2, onActivity: onActivity)
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.descriptor >= 0 else { return }
            close(self.descriptor)
            self.descriptor = -1
        }
        self.source = source
        source.resume()

        onActivity(GhostActivityEntry(kind: .info, title: "RAG watcher", detail: "Watching \(watchedURL.path)."))
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
        guard let watchedURL else {
            onActivity(GhostActivityEntry(kind: .error, title: "RAG sync failed", detail: "No folder selected."))
            return
        }

        let result = store.syncFolder(
            path: watchedURL.path,
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
            title = truncated ? "RAG folder synced (truncated)" : "RAG folder synced"
            kind = .success
        } else {
            title = "RAG sync failed"
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
