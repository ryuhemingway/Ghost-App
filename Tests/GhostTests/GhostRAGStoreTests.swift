import Foundation
import Testing
@testable import Ghost

@Suite("Ghost RAG store")
struct GhostRAGStoreTests {
    private func tempWorkspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ghost-rag-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Indexes and queries a text document with citations")
    func indexesAndQueriesTextDocument() throws {
        let workspace = try tempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let dbURL = workspace.appendingPathComponent("rag.sqlite")
        let docURL = workspace.appendingPathComponent("syllabus.md")
        try """
        # Course Policy

        Late work loses ten percent per day unless an extension is approved.
        Final projects are due during exam week.
        """.write(to: docURL, atomically: true, encoding: .utf8)

        let store = GhostRAGStore(databaseURL: dbURL)
        let ingest = store.ingestFile(path: docURL.path, workspace: workspace)
        #expect(ingest["ok"] as? Bool == true)

        let result = store.query("What does the syllabus say about late work?", maxResults: 3, workspace: workspace)
        #expect(result["ok"] as? Bool == true)
        let payload = try #require(result["payload"] as? [String: Any])
        let chunks = try #require(payload["chunks"] as? [[String: Any]])
        #expect(chunks.isEmpty == false)
        #expect((chunks.first?["text"] as? String ?? "").contains("Late work"))
        let citations = try #require(payload["citations"] as? [[String: Any]])
        #expect(citations.first?["citation"] as? String == "[1]")
    }

    @Test("Clear index keeps source files")
    func clearIndexKeepsSourceFiles() throws {
        let workspace = try tempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let docURL = workspace.appendingPathComponent("notes.txt")
        try "Bloom filters support fast membership checks.".write(to: docURL, atomically: true, encoding: .utf8)

        let store = GhostRAGStore(databaseURL: workspace.appendingPathComponent("rag.sqlite"))
        #expect(store.ingestFile(path: "notes.txt", workspace: workspace)["ok"] as? Bool == true)
        #expect(store.clearIndex()["ok"] as? Bool == true)
        #expect(FileManager.default.fileExists(atPath: docURL.path))

        let status = store.status()
        let payload = try #require(status["payload"] as? [String: Any])
        #expect(payload["document_count"] as? Int == 0)
        #expect(payload["chunk_count"] as? Int == 0)
    }

    @Test("Sync folder skips unchanged files and removes deleted files")
    func syncFolderSkipsUnchangedAndRemovesDeleted() throws {
        let workspace = try tempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let folder = workspace.appendingPathComponent("Desktop", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let docURL = folder.appendingPathComponent("desktop-note.md")
        try "A desktop note about vector search.".write(to: docURL, atomically: true, encoding: .utf8)

        let store = GhostRAGStore(databaseURL: workspace.appendingPathComponent("rag.sqlite"))
        let first = store.syncFolder(path: folder.path, recursive: true, removeMissing: true, maxFiles: 100, workspace: workspace)
        #expect(first["ok"] as? Bool == true)
        let firstPayload = try #require(first["payload"] as? [String: Any])
        #expect(firstPayload["indexed_files"] as? Int == 1)

        let second = store.syncFolder(path: folder.path, recursive: true, removeMissing: true, maxFiles: 100, workspace: workspace)
        let secondPayload = try #require(second["payload"] as? [String: Any])
        #expect(secondPayload["skipped_unchanged_files"] as? Int == 1)

        try FileManager.default.removeItem(at: docURL)
        let third = store.syncFolder(path: folder.path, recursive: true, removeMissing: true, maxFiles: 100, workspace: workspace)
        let thirdPayload = try #require(third["payload"] as? [String: Any])
        #expect(thirdPayload["removed_documents"] as? Int == 1)
    }
}
