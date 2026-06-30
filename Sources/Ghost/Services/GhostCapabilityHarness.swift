import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(CoreText)
import CoreText
#endif

/// Ghost-owned capability layer. Models can request actions, but this harness
/// performs path normalization, permission checks, execution, verification, and
/// returns a machine-readable result. User-visible confirmation must be based on
/// these results, never on the model's claim.
struct GhostCapabilityHarness: Sendable {
    enum Risk: String, Sendable {
        case low
        case medium
        case high
        case blocked
    }

    enum HarnessError: LocalizedError {
        case emptyPath
        case pathNotAllowed(String)
        case sensitivePath
        case fileMissing(String)
        case fileExists(String)
        case notDirectory(String)
        case notText(String)
        case invalidInput(String)
        case operationFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyPath:
                return "Path is required."
            case .pathNotAllowed(let message):
                return message
            case .sensitivePath:
                return "Ghost blocked access to a sensitive path or credential-like file."
            case .fileMissing(let path):
                return "File does not exist: \(path)"
            case .fileExists(let path):
                return "File already exists: \(path)"
            case .notDirectory(let path):
                return "Path is not a directory: \(path)"
            case .notText(let path):
                return "File is not UTF-8 text: \(path)"
            case .invalidInput(let message):
                return message
            case .operationFailed(let message):
                return message
            }
        }
    }

    struct Roots: Sendable {
        let workspace: URL
        let home: URL
        let customOutput: URL
        let ghostOutputs: URL
        let desktop: URL
        let downloads: URL
        let documents: URL

        var readAllowed: [URL] { [workspace, customOutput, ghostOutputs, desktop, downloads, documents] }
        var writeAllowed: [URL] { [workspace, customOutput, ghostOutputs, desktop, downloads, documents] }
        var defaultWriteRoot: URL { workspace.appendingPathComponent("Ghost Outputs", isDirectory: true) }

        init(workspace: URL) {
            let fm = FileManager.default
            self.workspace = GhostCapabilityHarness.standardized(workspace).resolvingSymlinksInPath()
            self.home = fm.homeDirectoryForCurrentUser
            let savedOutput = UserDefaults.standard.string(forKey: "documentOutputDirectoryPath")?.nonEmpty
            let outputPath = ((savedOutput ?? "\(NSHomeDirectory())/Ghost Outputs") as NSString).expandingTildeInPath
            self.customOutput = GhostCapabilityHarness.standardized(
                URL(fileURLWithPath: outputPath, isDirectory: true)
            ).resolvingSymlinksInPath()
            self.ghostOutputs = fm.homeDirectoryForCurrentUser.appendingPathComponent("Ghost Outputs", isDirectory: true)
            self.desktop = fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
            self.downloads = fm.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
            self.documents = fm.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        }
    }

    func capabilityManifest() -> [[String: Any]] {
        [
            manifest("ghost_list_directory", risk: .low, status: "implemented", description: "List entries inside workspace, Desktop, Downloads, Documents, or Ghost Outputs."),
            manifest("ghost_read_file", risk: .low, status: "implemented", description: "Read UTF-8 text from allowed folders with sensitive-file blocking."),
            manifest("ghost_search_files", risk: .low, status: "implemented", description: "Search filenames and paths inside the workspace."),
            manifest("ghost_write_file", risk: .medium, status: "implemented", description: "Write UTF-8 files to allowed folders and verify exact path."),
            manifest("ghost_create_file", risk: .medium, status: "implemented", description: "Alias for ghost_write_file."),
            manifest("ghost_update_file", risk: .medium, status: "implemented", description: "Overwrite a UTF-8 file after path validation."),
            manifest("ghost_move_file", risk: .medium, status: "implemented", description: "Move files between allowed folders."),
            manifest("ghost_copy_file", risk: .medium, status: "implemented", description: "Copy files between allowed folders."),
            manifest("ghost_delete_file", risk: .high, status: "implemented_with_trash", description: "Trash files inside allowed folders; permanent delete should require explicit high-risk approval."),
            manifest("ghost_create_folder", risk: .medium, status: "implemented", description: "Create folders inside allowed write roots."),
            manifest("ghost_get_file_info", risk: .low, status: "implemented", description: "Return verified metadata for allowed files."),
            manifest("ghost_open_file", risk: .medium, status: "implemented_macos", description: "Open an allowed file with the default app."),
            manifest("ghost_reveal_in_finder", risk: .medium, status: "implemented_macos", description: "Reveal an allowed file in Finder."),
            manifest("ghost_create_markdown", risk: .medium, status: "implemented", description: "Create real Markdown files."),
            manifest("ghost_create_html", risk: .medium, status: "implemented", description: "Create real self-contained HTML files."),
            manifest("ghost_create_txt", risk: .medium, status: "implemented", description: "Create real plain-text files."),
            manifest("ghost_create_csv", risk: .medium, status: "implemented", description: "Create real CSV files."),
            manifest("ghost_create_json", risk: .medium, status: "implemented", description: "Create validated JSON files."),
            manifest("ghost_create_pdf", risk: .medium, status: "implemented_macos", description: "Create real PDF files from text using native Core Graphics/Core Text."),
            manifest("ghost_create_docx", risk: .medium, status: "implemented", description: "Create simple valid DOCX files using OpenXML."),
            manifest("ghost_create_pptx", risk: .medium, status: "implemented", description: "Create simple valid PPTX decks using OpenXML."),
            manifest("ghost_create_xlsx", risk: .medium, status: "implemented", description: "Create simple valid XLSX spreadsheets using OpenXML inline strings."),
            manifest("ghost_convert_file", risk: .medium, status: "implemented_limited", description: "Convert UTF-8 text/Markdown to PDF, DOCX, HTML, TXT, or Markdown."),
            manifest("ghost_rag_ingest_file", risk: .low, status: "implemented", description: "Index a supported local file into Ghost RAG for cited document Q&A."),
            manifest("ghost_rag_ingest_folder", risk: .low, status: "implemented", description: "Index supported files from an allowed folder into Ghost RAG."),
            manifest("ghost_rag_sync_folder", risk: .low, status: "implemented", description: "Incrementally sync supported files from an allowed folder, skipping unchanged files and removing deleted sources."),
            manifest("ghost_rag_remove_document", risk: .medium, status: "implemented", description: "Remove a document from the local Ghost RAG index without deleting the source file."),
            manifest("ghost_rag_reindex", risk: .low, status: "implemented", description: "Re-extract and reindex currently indexed Ghost RAG documents."),
            manifest("ghost_rag_query", risk: .low, status: "implemented", description: "Retrieve cited document chunks for document-grounded answers."),
            manifest("ghost_rag_search_chunks", risk: .low, status: "implemented", description: "Search indexed chunks by keyword/FTS and return source excerpts."),
            manifest("ghost_rag_open_source", risk: .medium, status: "implemented_macos", description: "Open a cited RAG source document with the default app."),
            manifest("ghost_rag_status", risk: .low, status: "implemented", description: "Return Ghost RAG database path, document count, and chunk count."),
            manifest("ghost_rag_clear_index", risk: .high, status: "implemented_index_only", description: "Clear the local RAG index without deleting source files; requires explicit user intent."),
            manifest("ghost_run_shell_command", risk: .high, status: "approval_required", description: "Reserved for explicit user-approved commands, not exposed to unreliable local models."),
            manifest("ghost_apply_patch", risk: .high, status: "agent_or_approval_required", description: "Reserved for coding harness/OpenCode workflows."),
            manifest("ghost_email_send", risk: .high, status: "provider_required", description: "Requires email integration and explicit send intent."),
            manifest("ghost_screenshot", risk: .medium, status: "provider_required", description: "Requires screen-capture permission and explicit user intent.")
        ]
    }

    private func manifest(_ name: String, risk: Risk, status: String, description: String) -> [String: Any] {
        ["name": name, "risk": risk.rawValue, "status": status, "description": description]
    }

    // MARK: - File operations

    func listDirectory(path: String?, includeHidden: Bool, maxResults: Int, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path?.nonEmpty ?? roots.workspace.path, roots: roots, allowedRoots: roots.readAllowed, defaultRoot: roots.workspace, allowExistingSensitive: false)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { throw HarnessError.fileMissing(url.path) }
            guard isDirectory.boolValue else { throw HarnessError.notDirectory(url.path) }

            let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            let entries = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys)
                .filter { includeHidden || !$0.lastPathComponent.hasPrefix(".") }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .prefix(max(1, min(maxResults, 500)))
                .map { entry -> [String: Any] in
                    let values = try? entry.resourceValues(forKeys: Set(keys))
                    var result: [String: Any] = [
                        "name": entry.lastPathComponent,
                        "path": relativeOrAbsolutePath(entry, roots: roots),
                        "is_directory": values?.isDirectory == true,
                        "size_bytes": values?.fileSize ?? 0
                    ]
                    if let modified = values?.contentModificationDate {
                        result["modified_iso8601"] = ISO8601DateFormatter().string(from: modified)
                    }
                    return result
                }

            return ok("ghost_list_directory", summary: "Listed \(entries.count) item(s).", payload: [
                "path": url.path,
                "entries": Array(entries),
                "verified": true
            ])
        } catch {
            return fail("ghost_list_directory", error: error)
        }
    }

    func getFileInfo(path: String, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots, allowedRoots: roots.readAllowed, defaultRoot: roots.workspace, allowExistingSensitive: false)
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .isSymbolicLinkKey])
            guard FileManager.default.fileExists(atPath: url.path) else { throw HarnessError.fileMissing(url.path) }
            var payload: [String: Any] = [
                "path": url.path,
                "relative_path": relativeOrAbsolutePath(url, roots: roots),
                "is_directory": values.isDirectory == true,
                "is_symlink": values.isSymbolicLink == true,
                "size_bytes": values.fileSize ?? 0,
                "extension": url.pathExtension,
                "verified": true
            ]
            let iso = ISO8601DateFormatter()
            if let modified = values.contentModificationDate { payload["modified_iso8601"] = iso.string(from: modified) }
            if let created = values.creationDate { payload["created_iso8601"] = iso.string(from: created) }
            return ok("ghost_get_file_info", summary: "Read file metadata.", requestedPath: path, actualPath: url.path, payload: payload)
        } catch {
            return fail("ghost_get_file_info", requestedPath: path, error: error)
        }
    }

    func readFile(path: String, maxChars: Int, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots, allowedRoots: roots.readAllowed, defaultRoot: roots.workspace, allowExistingSensitive: false)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { throw HarnessError.fileMissing(url.path) }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard let text = String(data: data, encoding: .utf8) else { throw HarnessError.notText(url.path) }
            let limit = max(500, min(maxChars, 100_000))
            let truncated = text.count > limit
            return ok("ghost_read_file", summary: "Read UTF-8 file.", requestedPath: path, actualPath: url.path, payload: [
                "path": url.path,
                "relative_path": relativeOrAbsolutePath(url, roots: roots),
                "size_bytes": data.count,
                "truncated": truncated,
                "content": truncated ? String(text.prefix(limit)) : text,
                "verified": true
            ])
        } catch {
            return fail("ghost_read_file", requestedPath: path, error: error)
        }
    }

    func searchFiles(query: String, maxResults: Int, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let root = roots.workspace
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw HarnessError.invalidInput("Search query is required.") }
            let loweredQuery = trimmed.lowercased()
            let ignoredDirectoryNames: Set<String> = [".git", ".svn", ".hg", ".build", "DerivedData", "node_modules", ".venv", "venv", "__pycache__", ".cache"]
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsPackageDescendants]) else {
                throw HarnessError.operationFailed("Could not enumerate workspace.")
            }

            var matches: [[String: Any]] = []
            var visited = 0
            for case let url as URL in enumerator {
                visited += 1
                if visited > 12_000 { break }
                if ignoredDirectoryNames.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                    continue
                }
                if isSensitivePath(url.path) { continue }
                let relative = relativeOrAbsolutePath(url, roots: roots)
                let loweredRelative = relative.lowercased()
                let isMatch = loweredRelative.contains(loweredQuery)
                    || (loweredQuery.hasPrefix(".") && url.pathExtension.lowercased() == String(loweredQuery.dropFirst()))
                guard isMatch else { continue }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                matches.append([
                    "path": relative,
                    "is_directory": values?.isDirectory == true,
                    "size_bytes": values?.fileSize ?? 0
                ])
                if matches.count >= max(1, min(maxResults, 100)) { break }
            }

            return ok("ghost_search_files", summary: "Found \(matches.count) matching file(s).", payload: [
                "workspace": root.path,
                "query": trimmed,
                "results": matches,
                "truncated": visited > 12_000
            ])
        } catch {
            return fail("ghost_search_files", error: error)
        }
    }

    func writeFile(path: String, content: String, overwrite: Bool, createParents: Bool, workspace: URL, toolName: String = "ghost_write_file") -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots, allowedRoots: roots.writeAllowed, defaultRoot: roots.defaultWriteRoot, allowExistingSensitive: false)
            let binaryExtensions: Set<String> = ["pdf", "docx", "pptx", "xlsx", "pages", "key", "numbers", "zip", "png", "jpg", "jpeg", "gif", "webp"]
            if binaryExtensions.contains(url.pathExtension.lowercased()) {
                throw HarnessError.invalidInput("Use the native ghost_create_\(url.pathExtension.lowercased()) tool for .\(url.pathExtension.lowercased()) files instead of UTF-8 text writing.")
            }
            if FileManager.default.fileExists(atPath: url.path), !overwrite { throw HarnessError.fileExists(url.path) }
            if createParents { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true) }
            try content.write(to: url, atomically: true, encoding: .utf8)
            guard FileManager.default.fileExists(atPath: url.path) else { throw HarnessError.operationFailed("Write completed but the path could not be verified.") }
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? content.utf8.count
            return ok(toolName, summary: "Created and verified file.", requestedPath: path, actualPath: url.path, payload: [
                "path": url.path,
                "relative_path": relativeOrAbsolutePath(url, roots: roots),
                "bytes": size,
                "verified": true
            ])
        } catch {
            return fail(toolName, requestedPath: path, error: error)
        }
    }

    func createFolder(path: String, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots, allowedRoots: roots.writeAllowed, defaultRoot: roots.defaultWriteRoot, allowExistingSensitive: false)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw HarnessError.operationFailed("Folder creation could not be verified.")
            }
            return ok("ghost_create_folder", summary: "Created and verified folder.", requestedPath: path, actualPath: url.path, payload: ["path": url.path, "verified": true])
        } catch {
            return fail("ghost_create_folder", requestedPath: path, error: error)
        }
    }

    func copyFile(sourcePath: String, destinationPath: String, overwrite: Bool, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let source = try resolveAllowedURL(sourcePath, roots: roots, allowedRoots: roots.readAllowed, defaultRoot: roots.workspace, allowExistingSensitive: false)
            let destination = try resolveAllowedURL(destinationPath, roots: roots, allowedRoots: roots.writeAllowed, defaultRoot: roots.defaultWriteRoot, allowExistingSensitive: false)
            guard FileManager.default.fileExists(atPath: source.path) else { throw HarnessError.fileMissing(source.path) }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                guard overwrite else { throw HarnessError.fileExists(destination.path) }
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            guard FileManager.default.fileExists(atPath: destination.path) else { throw HarnessError.operationFailed("Copy could not be verified.") }
            return ok("ghost_copy_file", summary: "Copied and verified file.", requestedPath: sourcePath, actualPath: destination.path, payload: [
                "source_path": source.path,
                "destination_path": destination.path,
                "verified": true
            ])
        } catch {
            return fail("ghost_copy_file", requestedPath: sourcePath, error: error)
        }
    }

    func moveFile(sourcePath: String, destinationPath: String, overwrite: Bool, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let source = try resolveAllowedURL(sourcePath, roots: roots, allowedRoots: roots.writeAllowed, defaultRoot: roots.workspace, allowExistingSensitive: false)
            let destination = try resolveAllowedURL(destinationPath, roots: roots, allowedRoots: roots.writeAllowed, defaultRoot: roots.defaultWriteRoot, allowExistingSensitive: false)
            guard FileManager.default.fileExists(atPath: source.path) else { throw HarnessError.fileMissing(source.path) }
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                guard overwrite else { throw HarnessError.fileExists(destination.path) }
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: source, to: destination)
            guard FileManager.default.fileExists(atPath: destination.path), !FileManager.default.fileExists(atPath: source.path) else {
                throw HarnessError.operationFailed("Move could not be verified.")
            }
            return ok("ghost_move_file", summary: "Moved and verified file.", requestedPath: sourcePath, actualPath: destination.path, payload: [
                "source_path": source.path,
                "destination_path": destination.path,
                "verified": true
            ])
        } catch {
            return fail("ghost_move_file", requestedPath: sourcePath, error: error)
        }
    }

    func deleteFile(path: String, trash: Bool, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots, allowedRoots: roots.writeAllowed, defaultRoot: roots.workspace, allowExistingSensitive: false)
            guard FileManager.default.fileExists(atPath: url.path) else { throw HarnessError.fileMissing(url.path) }
            if trash {
                #if os(macOS)
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
                #else
                try FileManager.default.removeItem(at: url)
                #endif
            } else {
                try FileManager.default.removeItem(at: url)
            }
            let stillExists = FileManager.default.fileExists(atPath: url.path)
            guard !stillExists else { throw HarnessError.operationFailed("Delete/trash could not be verified.") }
            return ok("ghost_delete_file", summary: trash ? "Moved file to Trash." : "Deleted file.", requestedPath: path, actualPath: url.path, payload: [
                "path": url.path,
                "trashed": trash,
                "verified": true
            ])
        } catch {
            return fail("ghost_delete_file", requestedPath: path, error: error)
        }
    }

    func openFile(path: String, reveal: Bool, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots, allowedRoots: roots.readAllowed, defaultRoot: roots.workspace, allowExistingSensitive: false)
            guard FileManager.default.fileExists(atPath: url.path) else { throw HarnessError.fileMissing(url.path) }
            #if canImport(AppKit)
            if reveal {
                NSWorkspace.shared.activateFileViewerSelecting([url])
                return ok("ghost_reveal_in_finder", summary: "Revealed file in Finder.", requestedPath: path, actualPath: url.path, payload: ["path": url.path, "verified": true])
            } else {
                let opened = NSWorkspace.shared.open(url)
                guard opened else { throw HarnessError.operationFailed("macOS did not open the file.") }
                return ok("ghost_open_file", summary: "Opened file.", requestedPath: path, actualPath: url.path, payload: ["path": url.path, "verified": true])
            }
            #else
            return fail(reveal ? "ghost_reveal_in_finder" : "ghost_open_file", requestedPath: path, error: HarnessError.operationFailed("Opening files requires macOS AppKit."))
            #endif
        } catch {
            return fail(reveal ? "ghost_reveal_in_finder" : "ghost_open_file", requestedPath: path, error: error)
        }
    }

    // MARK: - Document generation

    func createTextDocument(toolName: String, path: String, content: String, overwrite: Bool, workspace: URL) -> [String: Any] {
        var finalContent = content
        if toolName == "ghost_create_html", !content.lowercased().contains("<html") {
            finalContent = """
            <!doctype html>
            <html lang=\"en\">
            <head>
              <meta charset=\"utf-8\">
              <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
              <title>Ghost Document</title>
            </head>
            <body>
            \(content)
            </body>
            </html>
            """
        }
        if toolName == "ghost_create_json" {
            guard let data = finalContent.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil else {
                return fail(toolName, requestedPath: path, error: HarnessError.invalidInput("ghost_create_json requires valid JSON content."))
            }
        }
        return writeFile(path: path, content: finalContent, overwrite: overwrite, createParents: true, workspace: workspace, toolName: toolName)
    }

    func createPDF(path: String, title: String?, content: String, overwrite: Bool, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots, allowedRoots: roots.writeAllowed, defaultRoot: roots.defaultWriteRoot, allowExistingSensitive: false)
            guard url.pathExtension.lowercased() == "pdf" else { throw HarnessError.invalidInput("PDF output path must end in .pdf.") }
            if FileManager.default.fileExists(atPath: url.path), !overwrite { throw HarnessError.fileExists(url.path) }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try writeSimplePDF(to: url, title: title, content: content)
            guard FileManager.default.fileExists(atPath: url.path) else { throw HarnessError.operationFailed("PDF creation could not be verified.") }
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
            return ok("ghost_create_pdf", summary: "Created and verified PDF.", requestedPath: path, actualPath: url.path, payload: [
                "path": url.path,
                "bytes": size,
                "verified": true
            ])
        } catch {
            return fail("ghost_create_pdf", requestedPath: path, error: error)
        }
    }

    func createDOCX(path: String, title: String?, content: String, overwrite: Bool, workspace: URL) -> [String: Any] {
        createOpenXMLPackage(toolName: "ghost_create_docx", path: path, expectedExtension: "docx", overwrite: overwrite, workspace: workspace) { tempDir in
            try createDOCXContents(in: tempDir, title: title, content: content)
        }
    }

    func createPPTX(path: String, title: String?, slides: [[String: Any]], fallbackContent: String?, overwrite: Bool, workspace: URL) -> [String: Any] {
        createOpenXMLPackage(toolName: "ghost_create_pptx", path: path, expectedExtension: "pptx", overwrite: overwrite, workspace: workspace) { tempDir in
            let normalizedSlides = normalizeSlides(title: title, slides: slides, fallbackContent: fallbackContent)
            try createPPTXContents(in: tempDir, title: title ?? "Ghost Presentation", slides: normalizedSlides)
        }
    }

    func createXLSX(path: String, csvContent: String, overwrite: Bool, workspace: URL) -> [String: Any] {
        createOpenXMLPackage(toolName: "ghost_create_xlsx", path: path, expectedExtension: "xlsx", overwrite: overwrite, workspace: workspace) { tempDir in
            try createXLSXContents(in: tempDir, rows: parseCSVLikeRows(csvContent))
        }
    }

    func convertFile(inputPath: String, outputPath: String, outputFormat: String, overwrite: Bool, workspace: URL) -> [String: Any] {
        let read = readFile(path: inputPath, maxChars: 250_000, workspace: workspace)
        guard read["ok"] as? Bool == true,
              let payload = read["payload"] as? [String: Any],
              let content = payload["content"] as? String else {
            return fail("ghost_convert_file", requestedPath: inputPath, error: HarnessError.operationFailed((read["error"] as? String) ?? "Could not read input file."))
        }
        switch outputFormat.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". ")) {
        case "pdf":
            return createPDF(path: outputPath, title: nil, content: content, overwrite: overwrite, workspace: workspace)
        case "docx":
            return createDOCX(path: outputPath, title: nil, content: content, overwrite: overwrite, workspace: workspace)
        case "html":
            let escaped = escapeHTML(content).replacingOccurrences(of: "\n", with: "<br>\n")
            return createTextDocument(toolName: "ghost_convert_file", path: outputPath, content: "<html><body>\(escaped)</body></html>", overwrite: overwrite, workspace: workspace)
        case "txt", "md", "markdown":
            return writeFile(path: outputPath, content: content, overwrite: overwrite, createParents: true, workspace: workspace, toolName: "ghost_convert_file")
        default:
            return fail("ghost_convert_file", requestedPath: inputPath, error: HarnessError.invalidInput("Unsupported conversion format: \(outputFormat). Supported: pdf, docx, html, txt, md."))
        }
    }

    // MARK: - Result helpers

    private func ok(_ tool: String, summary: String, requestedPath: String? = nil, actualPath: String? = nil, payload: [String: Any] = [:], warnings: [String] = []) -> [String: Any] {
        var result: [String: Any] = [
            "ok": true,
            "tool": tool,
            "verified": true,
            "summary": summary,
            "warnings": warnings,
            "payload": payload
        ]
        if let requestedPath { result["requested_path"] = requestedPath }
        if let actualPath { result["actual_path"] = actualPath }
        return result
    }

    private func fail(_ tool: String, requestedPath: String? = nil, error: Error) -> [String: Any] {
        var result: [String: Any] = [
            "ok": false,
            "tool": tool,
            "verified": false,
            "error": error.localizedDescription,
            "warnings": []
        ]
        if let requestedPath { result["requested_path"] = requestedPath }
        return result
    }

    // MARK: - Path safety

    private func resolveAllowedURL(
        _ rawPath: String,
        roots: Roots,
        allowedRoots: [URL],
        defaultRoot: URL,
        allowExistingSensitive: Bool
    ) throws -> URL {
        var trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "`\"'"))
        guard !trimmed.isEmpty else { throw HarnessError.emptyPath }
        if !allowExistingSensitive, isSensitivePath(trimmed) { throw HarnessError.sensitivePath }
        let pathComponents = trimmed.components(separatedBy: "/")
        if pathComponents.contains("..") {
            throw HarnessError.pathNotAllowed("Path traversal is not allowed.")
        }

        let lower = trimmed.lowercased()
        let candidate: URL
        if lower == "desktop" || lower.hasPrefix("desktop/") {
            let suffix = lower == "desktop" ? "" : String(trimmed.dropFirst("desktop/".count))
            candidate = roots.desktop.appendingPathComponent(suffix)
        } else if lower == "downloads" || lower.hasPrefix("downloads/") {
            let suffix = lower == "downloads" ? "" : String(trimmed.dropFirst("downloads/".count))
            candidate = roots.downloads.appendingPathComponent(suffix)
        } else if lower == "documents" || lower.hasPrefix("documents/") {
            let suffix = lower == "documents" ? "" : String(trimmed.dropFirst("documents/".count))
            candidate = roots.documents.appendingPathComponent(suffix)
        } else if lower == "ghost outputs" || lower.hasPrefix("ghost outputs/") || lower.hasPrefix("ghost outputs/") {
            let suffix = lower == "ghost outputs" ? "" : String(trimmed.dropFirst("ghost outputs/".count))
            candidate = roots.customOutput.appendingPathComponent(suffix)
        } else {
            let expanded = (trimmed as NSString).expandingTildeInPath
            if expanded.hasPrefix("/") {
                candidate = URL(fileURLWithPath: expanded)
            } else {
                candidate = defaultRoot.appendingPathComponent(expanded)
            }
        }

        let standardizedCandidate = Self.standardized(candidate).resolvingSymlinksInPath()
        if isSensitivePath(standardizedCandidate.path), !allowExistingSensitive { throw HarnessError.sensitivePath }
        guard !standardizedCandidate.path.components(separatedBy: "/").contains("..") else {
            throw HarnessError.pathNotAllowed("Path traversal is not allowed.")
        }
        guard allowedRoots.contains(where: { isContained(standardizedCandidate, in: Self.standardized($0).resolvingSymlinksInPath()) }) else {
            throw HarnessError.pathNotAllowed("Path must stay inside an allowed folder: workspace, Ghost output folder, ~/Ghost Outputs, ~/Desktop, ~/Downloads, or ~/Documents.")
        }
        return standardizedCandidate
    }

    private static func standardized(_ url: URL) -> URL {
        URL(fileURLWithPath: (url.path as NSString).standardizingPath)
    }

    private func isContained(_ candidate: URL, in root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path == root.path || candidate.path.hasPrefix(rootPath)
    }

    private func relativeOrAbsolutePath(_ url: URL, roots: Roots) -> String {
        let rootPath = roots.workspace.path.hasSuffix("/") ? roots.workspace.path : roots.workspace.path + "/"
        if url.path.hasPrefix(rootPath) { return String(url.path.dropFirst(rootPath.count)) }
        return url.path
    }

    private func isSensitivePath(_ path: String) -> Bool {
        let lower = path.lowercased()
        let sensitiveNeedles = [
            "/.ssh", ".ssh/", "id_rsa", "id_ed25519", "private_key", "private-key",
            ".env", "keychain", "credentials", "secrets", "token", "apikey", "api_key",
            "login.keychain", "cookies.sqlite", "browser profile"
        ]
        return sensitiveNeedles.contains { lower.contains($0) }
    }

    // MARK: - Native PDF

    private func writeSimplePDF(to url: URL, title: String?, content: String) throws {
        #if canImport(CoreGraphics) && canImport(CoreText)
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(url: url as CFURL), let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw HarnessError.operationFailed("Could not create PDF context.")
        }

        let fullText: String
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fullText = "\(title)\n\n\(content)"
        } else {
            fullText = content
        }

        let font = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        let attributed = NSAttributedString(
            string: fullText,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: font,
                kCTParagraphStyleAttributeName as NSAttributedString.Key: paragraph
            ]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        var range = CFRange(location: 0, length: 0)
        let margin: CGFloat = 54
        let textRect = CGRect(x: margin, y: margin, width: mediaBox.width - margin * 2, height: mediaBox.height - margin * 2)

        repeat {
            context.beginPDFPage(nil)
            context.saveGState()
            context.textMatrix = .identity
            context.translateBy(x: 0, y: mediaBox.height)
            context.scaleBy(x: 1, y: -1)
            let path = CGMutablePath()
            path.addRect(textRect)
            let frame = CTFramesetterCreateFrame(framesetter, range, path, nil)
            CTFrameDraw(frame, context)
            let visible = CTFrameGetVisibleStringRange(frame)
            range.location += visible.length
            context.restoreGState()
            context.endPDFPage()
        } while range.location < attributed.length

        context.closePDF()
        #else
        throw HarnessError.operationFailed("PDF generation requires CoreGraphics/CoreText on macOS.")
        #endif
    }

    // MARK: - OpenXML packages

    private func createOpenXMLPackage(toolName: String, path: String, expectedExtension: String, overwrite: Bool, workspace: URL, builder: (URL) throws -> Void) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots, allowedRoots: roots.writeAllowed, defaultRoot: roots.defaultWriteRoot, allowExistingSensitive: false)
            guard url.pathExtension.lowercased() == expectedExtension else { throw HarnessError.invalidInput("Output path must end in .\(expectedExtension).") }
            if FileManager.default.fileExists(atPath: url.path), !overwrite { throw HarnessError.fileExists(url.path) }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ghost-openxml-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }
            try builder(tempDir)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            try zipDirectoryContents(tempDir, output: url)
            guard FileManager.default.fileExists(atPath: url.path) else { throw HarnessError.operationFailed("OpenXML package creation could not be verified.") }
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
            return ok(toolName, summary: "Created and verified .\(expectedExtension) file.", requestedPath: path, actualPath: url.path, payload: ["path": url.path, "bytes": size, "verified": true])
        } catch {
            return fail(toolName, requestedPath: path, error: error)
        }
    }

    private func zipDirectoryContents(_ sourceDir: URL, output: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["zip", "-qr", output.path, "."]
        process.currentDirectoryURL = sourceDir
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw HarnessError.operationFailed("zip failed: \(stderr)")
        }
    }

    private func createDOCXContents(in dir: URL, title: String?, content: String) throws {
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">
          <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>
          <Default Extension=\"xml\" ContentType=\"application/xml\"/>
          <Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>
        </Types>
        """, to: dir.appendingPathComponent("[Content_Types].xml"))
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">
          <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>
        </Relationships>
        """, to: dir.appendingPathComponent("_rels/.rels"))
        let paragraphs = docxParagraphs(title: title, content: content)
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">
          <w:body>
            \(paragraphs)
            <w:sectPr><w:pgSz w:w=\"12240\" w:h=\"15840\"/><w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\"/></w:sectPr>
          </w:body>
        </w:document>
        """, to: dir.appendingPathComponent("word/document.xml"))
    }

    private func docxParagraphs(title: String?, content: String) -> String {
        var lines: [String] = []
        if let title, !title.isEmpty { lines.append(title); lines.append("") }
        lines.append(contentsOf: content.components(separatedBy: .newlines))
        return lines.map { line in
            "<w:p><w:r><w:t xml:space=\"preserve\">\(escapeXML(line))</w:t></w:r></w:p>"
        }.joined(separator: "\n")
    }

    private struct NormalizedSlide {
        let title: String
        let bullets: [String]
    }

    private func normalizeSlides(title: String?, slides: [[String: Any]], fallbackContent: String?) -> [NormalizedSlide] {
        let fromArgs = slides.compactMap { item -> NormalizedSlide? in
            let title = (item["title"] as? String)?.nonEmpty ?? "Slide"
            let bullets = (item["bullets"] as? [String])
                ?? (item["points"] as? [String])
                ?? ((item["content"] as? String)?.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? [])
            return NormalizedSlide(title: title, bullets: bullets)
        }
        if !fromArgs.isEmpty { return fromArgs }
        let fallbackLines = (fallbackContent ?? "").components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if fallbackLines.isEmpty { return [NormalizedSlide(title: title ?? "Ghost Presentation", bullets: [])] }
        return [NormalizedSlide(title: title ?? fallbackLines.first ?? "Ghost Presentation", bullets: Array(fallbackLines.dropFirst()))]
    }

    private func createPPTXContents(in dir: URL, title: String, slides: [NormalizedSlide]) throws {
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">
          <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>
          <Default Extension=\"xml\" ContentType=\"application/xml\"/>
          <Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>
          \((1...max(slides.count, 1)).map { "<Override PartName=\"/ppt/slides/slide\($0).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>" }.joined())
        </Types>
        """, to: dir.appendingPathComponent("[Content_Types].xml"))
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">
          <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"ppt/presentation.xml\"/>
        </Relationships>
        """, to: dir.appendingPathComponent("_rels/.rels"))
        let slideIds = slides.enumerated().map { index, _ in
            "<p:sldId id=\"\(256 + index)\" r:id=\"rId\(index + 1)\"/>"
        }.joined()
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <p:presentation xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">
          <p:sldMasterIdLst/>
          <p:sldIdLst>\(slideIds)</p:sldIdLst>
          <p:sldSz cx=\"9144000\" cy=\"5143500\" type=\"screen16x9\"/>
          <p:notesSz cx=\"6858000\" cy=\"9144000\"/>
        </p:presentation>
        """, to: dir.appendingPathComponent("ppt/presentation.xml"))
        let rels = slides.enumerated().map { index, _ in
            "<Relationship Id=\"rId\(index + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide\(index + 1).xml\"/>"
        }.joined()
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\(rels)</Relationships>
        """, to: dir.appendingPathComponent("ppt/_rels/presentation.xml.rels"))
        for (index, slide) in slides.enumerated() {
            try write(pptxSlideXML(slide), to: dir.appendingPathComponent("ppt/slides/slide\(index + 1).xml"))
        }
    }

    private func pptxSlideXML(_ slide: NormalizedSlide) -> String {
        let bulletText = slide.bullets.map { "• \($0)" }.joined(separator: "\n")
        return """
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">
          <p:cSld><p:spTree>
            <p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>
            <p:sp><p:nvSpPr><p:cNvPr id=\"2\" name=\"Title\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"685800\" y=\"457200\"/><a:ext cx=\"7772400\" cy=\"914400\"/></a:xfrm></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr sz=\"3600\"/><a:t>\(escapeXML(slide.title))</a:t></a:r></a:p></p:txBody></p:sp>
            <p:sp><p:nvSpPr><p:cNvPr id=\"3\" name=\"Content\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x=\"914400\" y=\"1600200\"/><a:ext cx=\"7315200\" cy=\"2971800\"/></a:xfrm></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr sz=\"2400\"/><a:t>\(escapeXML(bulletText))</a:t></a:r></a:p></p:txBody></p:sp>
          </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
        </p:sld>
        """
    }

    private func createXLSXContents(in dir: URL, rows: [[String]]) throws {
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">
          <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>
          <Default Extension=\"xml\" ContentType=\"application/xml\"/>
          <Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>
          <Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>
        </Types>
        """, to: dir.appendingPathComponent("[Content_Types].xml"))
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>
        """, to: dir.appendingPathComponent("_rels/.rels"))
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Sheet1\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>
        """, to: dir.appendingPathComponent("xl/workbook.xml"))
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>
        """, to: dir.appendingPathComponent("xl/_rels/workbook.xml.rels"))
        let sheetData = rows.enumerated().map { rowIndex, row in
            let cells = row.enumerated().map { colIndex, value in
                let cellRef = "\(columnName(colIndex + 1))\(rowIndex + 1)"
                return "<c r=\"\(cellRef)\" t=\"inlineStr\"><is><t>\(escapeXML(value))</t></is></c>"
            }.joined()
            return "<row r=\"\(rowIndex + 1)\">\(cells)</row>"
        }.joined()
        try write("""
        <?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>
        <worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>\(sheetData)</sheetData></worksheet>
        """, to: dir.appendingPathComponent("xl/worksheets/sheet1.xml"))
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func parseCSVLikeRows(_ text: String) -> [[String]] {
        text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { line in line.split(separator: ",", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: " \"")) } }
    }

    private func columnName(_ number: Int) -> String {
        var n = number
        var result = ""
        while n > 0 {
            let remainder = (n - 1) % 26
            result = String(UnicodeScalar(65 + remainder)!) + result
            n = (n - 1) / 26
        }
        return result
    }

    private func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func escapeHTML(_ text: String) -> String {
        escapeXML(text)
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
