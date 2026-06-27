import Foundation
import Testing
@testable import Ghost

@Suite("Ghost capability harness")
struct GhostCapabilityHarnessTests {
    private func tempWorkspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ghost-harness-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Writes and verifies UTF-8 file")
    func writesAndVerifiesTextFile() throws {
        let workspace = try tempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let harness = GhostCapabilityHarness()

        let result = harness.writeFile(
            path: "hello.txt",
            content: "hello ghost",
            overwrite: false,
            createParents: true,
            workspace: workspace
        )

        #expect(result["ok"] as? Bool == true)
        let payload = try #require(result["payload"] as? [String: Any])
        let path = try #require(payload["path"] as? String)
        #expect(FileManager.default.fileExists(atPath: path))
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "hello ghost")
    }

    @Test("Blocks path traversal outside workspace")
    func blocksPathTraversal() throws {
        let workspace = try tempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let harness = GhostCapabilityHarness()

        let result = harness.writeFile(
            path: "../escape.txt",
            content: "nope",
            overwrite: true,
            createParents: true,
            workspace: workspace
        )

        #expect(result["ok"] as? Bool == false)
    }

    @Test("Blocks sensitive credential-like paths")
    func blocksSensitivePaths() throws {
        let workspace = try tempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let harness = GhostCapabilityHarness()

        let result = harness.writeFile(
            path: ".env",
            content: "SECRET=value",
            overwrite: true,
            createParents: true,
            workspace: workspace
        )

        #expect(result["ok"] as? Bool == false)
    }

    @Test("Creates real DOCX package")
    func createsDOCXPackage() throws {
        let workspace = try tempWorkspace()
        defer { try? FileManager.default.removeItem(at: workspace) }
        let harness = GhostCapabilityHarness()

        let result = harness.createDOCX(
            path: "test.docx",
            title: "Test",
            content: "Hello DOCX",
            overwrite: false,
            workspace: workspace
        )

        #expect(result["ok"] as? Bool == true)
        let path = try #require(result["actual_path"] as? String)
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("JSON action extractor finds fallback action")
    func jsonActionExtractorFindsFallbackAction() throws {
        let text = """
        {"action":"create_file","arguments":{"path":"hello.txt","content":"hi"}}
        """
        let action = try #require(GhostJSONActionExtractor.extractAction(from: text))
        #expect(action.name == "create_file")
        #expect(action.arguments["path"] as? String == "hello.txt")
    }
}
