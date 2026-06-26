import Foundation

struct GhostCodeWorkspaceSnapshot: Sendable {
    let capturedAt: Date
    let files: [String: Data]
}

struct GhostCodeChangeSet: Sendable {
    let createdAt: Date
    let command: String
    let before: [String: Data?]
    let after: [String: Data?]

    var changedPaths: [String] {
        Array(Set(before.keys).union(after.keys)).sorted()
    }

    var isEmpty: Bool { changedPaths.isEmpty }

    var terminalSummary: String {
        let rendered = changedPaths.map { path -> String in
            switch (before[path] ?? nil, after[path] ?? nil) {
            case (nil, .some): return "A \(path)"
            case (.some, nil): return "D \(path)"
            case (.some, .some): return "M \(path)"
            case (nil, nil): return "? \(path)"
            }
        }.joined(separator: "\n")
        return rendered.isEmpty ? "No tracked file changes." : rendered
    }
}

struct GhostCodeChangeSetService: Sendable {
    private let skippedDirectories: Set<String> = [
        ".git", ".build", ".swiftpm", "DerivedData", "node_modules", "__MACOSX", "dist"
    ]

    private let skippedFiles: Set<String> = [
        ".DS_Store"
    ]

    func captureSnapshot(root: URL, fileLimit: Int = 2_000, maxFileBytes: Int = 1_500_000) -> GhostCodeWorkspaceSnapshot {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey],
            options: []
        ) else {
            return GhostCodeWorkspaceSnapshot(capturedAt: Date(), files: [:])
        }

        let rootPath = root.standardizedFileURL.path
        var files: [String: Data] = [:]

        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if skippedDirectories.contains(name) {
                enumerator.skipDescendants()
                continue
            }
            if skippedFiles.contains(name) { continue }

            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]) else { continue }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else { continue }
            if (values.fileSize ?? 0) > maxFileBytes { continue }

            guard let data = try? Data(contentsOf: url) else { continue }
            if String(data: data, encoding: .utf8) == nil { continue }

            let filePath = url.standardizedFileURL.path
            guard filePath.hasPrefix(rootPath + "/") else { continue }
            let relative = String(filePath.dropFirst(rootPath.count + 1))
            files[relative] = data

            if files.count >= fileLimit { break }
        }

        return GhostCodeWorkspaceSnapshot(capturedAt: Date(), files: files)
    }

    func changeSet(
        before: GhostCodeWorkspaceSnapshot,
        after: GhostCodeWorkspaceSnapshot,
        command: String
    ) -> GhostCodeChangeSet? {
        let allPaths = Set(before.files.keys).union(after.files.keys)
        var beforeChanges: [String: Data?] = [:]
        var afterChanges: [String: Data?] = [:]

        for path in allPaths.sorted() {
            let old = before.files[path]
            let new = after.files[path]
            guard old != new else { continue }
            beforeChanges[path] = old
            afterChanges[path] = new
        }

        let changeSet = GhostCodeChangeSet(
            createdAt: Date(),
            command: command,
            before: beforeChanges,
            after: afterChanges
        )
        return changeSet.isEmpty ? nil : changeSet
    }

    func undo(_ changeSet: GhostCodeChangeSet, root: URL) throws {
        try apply(changeSet.before, root: root)
    }

    func redo(_ changeSet: GhostCodeChangeSet, root: URL) throws {
        try apply(changeSet.after, root: root)
    }

    private func apply(_ states: [String: Data?], root: URL) throws {
        for path in states.keys.sorted() {
            let clean = path.replacingOccurrences(of: "\\", with: "/")
            guard !clean.contains("../"), !clean.hasPrefix("/") else { continue }
            let url = root.appendingPathComponent(clean).standardizedFileURL
            guard url.path.hasPrefix(root.standardizedFileURL.path + "/") else { continue }

            if let data = states[path] ?? nil {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            } else if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
}
