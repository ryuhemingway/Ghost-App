import Foundation
import SQLite3
#if canImport(PDFKit)
import PDFKit
#endif
#if canImport(AppKit)
import AppKit
#endif

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct GhostRAGStore: Sendable {
    enum RAGError: LocalizedError {
        case emptyPath
        case pathNotAllowed(String)
        case sensitivePath
        case fileMissing(String)
        case notDirectory(String)
        case unsupportedFileType(String)
        case extractionFailed(String)
        case database(String)
        case invalidInput(String)

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
            case .notDirectory(let path):
                return "Path is not a directory: \(path)"
            case .unsupportedFileType(let ext):
                return "Unsupported RAG file type: .\(ext)"
            case .extractionFailed(let message):
                return message
            case .database(let message):
                return message
            case .invalidInput(let message):
                return message
            }
        }
    }

    struct Roots: Sendable {
        let workspace: URL
        let ghostOutputs: URL
        let desktop: URL
        let downloads: URL
        let documents: URL
        let ibooks: URL

        var readAllowed: [URL] { [workspace, ghostOutputs, desktop, downloads, documents, ibooks] }

        init(workspace: URL) {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.workspace = GhostRAGStore.standardized(workspace).resolvingSymlinksInPath()
            self.ghostOutputs = home.appendingPathComponent("Ghost Outputs", isDirectory: true)
            self.desktop = home.appendingPathComponent("Desktop", isDirectory: true)
            self.downloads = home.appendingPathComponent("Downloads", isDirectory: true)
            self.documents = home.appendingPathComponent("Documents", isDirectory: true)
            self.ibooks = home.appendingPathComponent("Library/Mobile Documents/iCloud~com~apple~iBooks/Documents", isDirectory: true)
        }
    }

    private let databaseURL: URL
    static let supportedFileExtensions: Set<String> = [
        "txt", "md", "markdown", "html", "htm", "pdf", "docx", "epub", "csv", "json", "rtf",
        "swift", "py", "js", "ts", "tsx", "jsx", "java", "cpp", "c", "h", "hpp", "m", "mm", "sql", "xml", "yaml", "yml", "toml", "log"
    ]
    private static let maxFolderSyncFiles = 50_000

    private static let ftsStopWords: Set<String> = [
        "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did", "will", "would", "shall",
        "should", "may", "might", "must", "can", "could",
        "i", "me", "my", "we", "us", "our", "you", "your", "he", "she", "it",
        "they", "them", "their", "his", "her", "its",
        "what", "which", "who", "whom", "when", "where", "why", "how",
        "this", "that", "these", "those",
        "and", "but", "or", "not", "if", "then", "else", "so", "as", "at",
        "by", "for", "with", "about", "into", "through", "during",
        "to", "from", "in", "on", "of", "up", "out", "off", "over", "under",
        "again", "further", "once", "here", "there", "all", "both", "each",
        "few", "more", "most", "other", "some", "such", "no", "only", "own",
        "same", "than", "too", "very", "just", "say", "says", "said", "tell",
        "tells", "told", "get", "got", "make", "made", "go", "went", "come",
        "came", "take", "took", "see", "saw", "know", "knew", "think",
        "thought", "give", "gave", "find", "found", "put", "let", "look",
        "looking", "doesn", "don", "didn", "isn", "aren", "wasn", "weren",
        "hasn", "haven", "hadn", "won", "wouldn", "can", "couldn", "shouldn"
    ]

    private static let excludedDirectoryNames: Set<String> = [
        "node_modules", "pods", "vendor", "bower_components",
        "dist", "build", "target", "deriveddata", "carthage",
        "__pycache__", "site-packages", "egg-info", ".eggs",
        "venv", ".tox", ".mypy_cache", ".pytest_cache",
        ".ruff_cache", ".turbo", ".cache"
    ]

    init(databaseURL: URL? = nil) {
        if let databaseURL {
            self.databaseURL = databaseURL
        } else {
            self.databaseURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Ghost/rag/ghost_rag.sqlite")
        }
    }

    func ingestFile(path: String, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots)
            let extracted = try extractText(from: url)
            let chunks = chunk(extracted)
            guard !chunks.isEmpty else {
                throw RAGError.extractionFailed("No indexable text was found in \(url.lastPathComponent).")
            }

            let db = try openDatabase()
            defer { sqlite3_close(db) }
            try createSchema(db)
            let documentID = UUID().uuidString
            try removeDocument(path: url.path, db: db)
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            let fingerprint = "\(modified)-\(size)"
            try insertDocument(
                db,
                id: documentID,
                path: url.path,
                displayName: url.lastPathComponent,
                fileType: url.pathExtension.lowercased(),
                fileHash: fingerprint,
                modifiedAt: modified,
                sourceKind: "file"
            )
            for (index, item) in chunks.enumerated() {
                try insertChunk(
                    db,
                    id: UUID().uuidString,
                    documentID: documentID,
                    chunkIndex: index,
                    text: item.text,
                    pageNumber: item.pageNumber,
                    sectionTitle: item.sectionTitle
                )
            }

            return ok("ghost_rag_ingest_file", summary: "Indexed \(chunks.count) chunk(s).", payload: [
                "document_id": documentID,
                "path": url.path,
                "display_name": url.lastPathComponent,
                "chunk_count": chunks.count,
                "database_path": databaseURL.path,
                "verified": true
            ])
        } catch {
            return fail("ghost_rag_ingest_file", requestedPath: path, error: error)
        }
    }

    func ingestFolder(path: String, recursive: Bool, maxFiles: Int, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let folder = try resolveAllowedURL(path, roots: roots)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw RAGError.notDirectory(folder.path)
            }
            let limit = max(1, min(maxFiles, Self.maxFolderSyncFiles))
            let files = try indexableFiles(in: folder, recursive: recursive, limit: limit)
            var indexed = 0
            var failed: [[String: String]] = []
            for file in files {
                let result = ingestFile(path: file.path, workspace: workspace)
                if result["ok"] as? Bool == true {
                    indexed += 1
                } else {
                    failed.append(["path": file.path, "error": result["error"] as? String ?? "Unknown error"])
                }
            }
            return ok("ghost_rag_ingest_folder", summary: "Indexed \(indexed) file(s).", payload: [
                "path": folder.path,
                "indexed_files": indexed,
                "failed_files": failed,
                "truncated": files.count >= limit,
                "verified": true
            ])
        } catch {
            return fail("ghost_rag_ingest_folder", requestedPath: path, error: error)
        }
    }

    func syncFolder(path: String, recursive: Bool, removeMissing: Bool, maxFiles: Int, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let folder = try resolveAllowedURL(path, roots: roots)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw RAGError.notDirectory(folder.path)
            }

            let limit = max(1, min(maxFiles, Self.maxFolderSyncFiles))
            let files = try indexableFiles(in: folder, recursive: recursive, limit: limit)
            let truncated = files.count >= limit
            let currentPaths = Set(files.map(\.path))

            let db = try openDatabase()
            defer { sqlite3_close(db) }
            try createSchema(db)
            let existing = try documentFingerprints(under: folder.path, db: db)

            var indexed = 0
            var skipped = 0
            var removed = 0
            var failed: [[String: String]] = []

            for file in files {
                let fingerprint = try fileFingerprint(file)
                if existing[file.path] == fingerprint {
                    skipped += 1
                    continue
                }

                let result = ingestFile(path: file.path, workspace: workspace)
                if result["ok"] as? Bool == true {
                    indexed += 1
                } else {
                    failed.append(["path": file.path, "error": result["error"] as? String ?? "Unknown error"])
                }
            }

            if removeMissing && !truncated {
                for path in existing.keys where !currentPaths.contains(path) {
                    removed += try removeDocument(path: path, db: db)
                }
            }

            return ok("ghost_rag_sync_folder", summary: "Synced \(indexed) changed file(s), skipped \(skipped), removed \(removed).", payload: [
                "path": folder.path,
                "indexed_files": indexed,
                "skipped_unchanged_files": skipped,
                "removed_documents": removed,
                "removal_deferred": removeMissing && truncated,
                "failed_files": failed,
                "truncated": truncated,
                "supported_extensions": Array(Self.supportedFileExtensions).sorted(),
                "verified": true
            ])
        } catch {
            return fail("ghost_rag_sync_folder", requestedPath: path, error: error)
        }
    }

    func query(_ query: String, maxResults: Int, workspace: URL) -> [String: Any] {
        let result = searchChunks(query, maxResults: maxResults, workspace: workspace, toolName: "ghost_rag_query")
        guard result["ok"] as? Bool == true else { return result }
        let payload = result["payload"] as? [String: Any] ?? [:]
        let chunks = payload["chunks"] as? [[String: Any]] ?? []
        let citations = chunks.enumerated().map { index, item -> [String: Any] in
            [
                "citation": "[\(index + 1)]",
                "document": item["document"] as? String ?? "",
                "path": item["path"] as? String ?? "",
                "page": item["page"] as Any,
                "section": item["section"] as Any
            ]
        }
        return ok("ghost_rag_query", summary: "Retrieved \(chunks.count) cited chunk(s).", payload: [
            "query": query,
            "chunks": chunks,
            "citations": citations,
            "answer_instruction": "Answer only from these chunks. Cite sources with [1], [2], etc. If the chunks do not answer the question, say so.",
            "verified": true
        ])
    }

    func searchChunks(_ query: String, maxResults: Int, workspace: URL, toolName: String = "ghost_rag_search_chunks") -> [String: Any] {
        do {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw RAGError.invalidInput("Query is required.") }
            let db = try openDatabase()
            defer { sqlite3_close(db) }
            try createSchema(db)
            let results = try rankedChunks(db, query: trimmed, maxResults: max(1, min(maxResults, 20)))
            return ok(toolName, summary: "Found \(results.count) relevant chunk(s).", payload: [
                "query": trimmed,
                "chunks": results,
                "database_path": databaseURL.path,
                "verified": true
            ])
        } catch {
            return fail(toolName, error: error)
        }
    }

    func status() -> [String: Any] {
        do {
            let db = try openDatabase()
            defer { sqlite3_close(db) }
            try createSchema(db)
            let documentCount = try intScalar(db, "SELECT COUNT(*) FROM documents")
            let chunkCount = try intScalar(db, "SELECT COUNT(*) FROM chunks")
            return ok("ghost_rag_status", summary: "\(documentCount) document(s), \(chunkCount) chunk(s).", payload: [
                "database_path": databaseURL.path,
                "document_count": documentCount,
                "chunk_count": chunkCount,
                "verified": true
            ])
        } catch {
            return fail("ghost_rag_status", error: error)
        }
    }

    func removeDocument(path: String, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots)
            let db = try openDatabase()
            defer { sqlite3_close(db) }
            try createSchema(db)
            let removed = try removeDocument(path: url.path, db: db)
            return ok("ghost_rag_remove_document", summary: "Removed \(removed) document(s).", requestedPath: path, actualPath: url.path, payload: [
                "path": url.path,
                "removed_documents": removed,
                "verified": true
            ])
        } catch {
            return fail("ghost_rag_remove_document", requestedPath: path, error: error)
        }
    }

    func clearIndex() -> [String: Any] {
        do {
            let db = try openDatabase()
            defer { sqlite3_close(db) }
            try createSchema(db)
            try exec(db, "DELETE FROM chunks_fts")
            try exec(db, "DELETE FROM chunks")
            try exec(db, "DELETE FROM documents")
            return ok("ghost_rag_clear_index", summary: "Cleared the Ghost RAG index.", payload: [
                "database_path": databaseURL.path,
                "verified": true
            ])
        } catch {
            return fail("ghost_rag_clear_index", error: error)
        }
    }

    func openSource(path: String, workspace: URL) -> [String: Any] {
        do {
            let roots = Roots(workspace: workspace)
            let url = try resolveAllowedURL(path, roots: roots)
            guard FileManager.default.fileExists(atPath: url.path) else { throw RAGError.fileMissing(url.path) }
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #endif
            return ok("ghost_rag_open_source", summary: "Opened source document.", requestedPath: path, actualPath: url.path, payload: [
                "path": url.path,
                "verified": true
            ])
        } catch {
            return fail("ghost_rag_open_source", requestedPath: path, error: error)
        }
    }

    func reindex(workspace: URL) -> [String: Any] {
        do {
            let db = try openDatabase()
            defer { sqlite3_close(db) }
            try createSchema(db)
            let paths = try documentPaths(db)
            var indexed = 0
            var failed: [[String: String]] = []
            for path in paths {
                let result = ingestFile(path: path, workspace: workspace)
                if result["ok"] as? Bool == true {
                    indexed += 1
                } else {
                    failed.append(["path": path, "error": result["error"] as? String ?? "Unknown error"])
                }
            }
            return ok("ghost_rag_reindex", summary: "Reindexed \(indexed) document(s).", payload: [
                "indexed_documents": indexed,
                "failed_documents": failed,
                "verified": true
            ])
        } catch {
            return fail("ghost_rag_reindex", error: error)
        }
    }

    private struct ExtractedText {
        let text: String
        let pageNumber: Int?
        let sectionTitle: String?
    }

    private func extractText(from url: URL) throws -> [ExtractedText] {
        let ext = url.pathExtension.lowercased()
        guard Self.supportedFileExtensions.contains(ext) else { throw RAGError.unsupportedFileType(ext.isEmpty ? "unknown" : ext) }
        switch ext {
        case "pdf":
            #if canImport(PDFKit)
            guard let pdf = PDFDocument(url: url) else { throw RAGError.extractionFailed("Could not open PDF.") }
            return (0..<pdf.pageCount).compactMap { index in
                guard let text = pdf.page(at: index)?.string, !text.isEmpty else { return nil }
                return ExtractedText(text: text, pageNumber: index + 1, sectionTitle: nil)
            }
            #else
            throw RAGError.unsupportedFileType("pdf")
            #endif
        case "docx":
            return [ExtractedText(text: try extractDOCXText(from: url), pageNumber: nil, sectionTitle: nil)]
        case "epub":
            return [ExtractedText(text: try extractEPUBText(from: url), pageNumber: nil, sectionTitle: nil)]
        case "rtf":
            #if canImport(AppKit)
            let attributed = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
            return [ExtractedText(text: attributed.string, pageNumber: nil, sectionTitle: nil)]
            #else
            throw RAGError.unsupportedFileType("rtf")
            #endif
        case "html", "htm":
            let raw = try String(contentsOf: url, encoding: .utf8)
            return [ExtractedText(text: stripHTML(raw), pageNumber: nil, sectionTitle: nil)]
        default:
            return [ExtractedText(text: try String(contentsOf: url, encoding: .utf8), pageNumber: nil, sectionTitle: nil)]
        }
    }

    private func chunk(_ extracted: [ExtractedText]) -> [ExtractedText] {
        extracted.flatMap { item -> [ExtractedText] in
            let paragraphs = item.text
                .components(separatedBy: CharacterSet.newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            var chunks: [ExtractedText] = []
            var current = ""
            var section = item.sectionTitle
            for paragraph in paragraphs {
                if paragraph.hasPrefix("#") {
                    section = paragraph.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
                }
                if current.count + paragraph.count > 3_500, !current.isEmpty {
                    chunks.append(ExtractedText(text: current, pageNumber: item.pageNumber, sectionTitle: section))
                    current = String(current.suffix(500))
                }
                current += current.isEmpty ? paragraph : "\n\n\(paragraph)"
            }
            if !current.isEmpty {
                chunks.append(ExtractedText(text: current, pageNumber: item.pageNumber, sectionTitle: section))
            }
            return chunks
        }
    }

    private func indexableFiles(in folder: URL, recursive: Bool, limit: Int) throws -> [URL] {
        let options: FileManager.DirectoryEnumerationOptions = recursive ? [.skipsHiddenFiles, .skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: options) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            if files.count >= limit { break }
            if isSensitivePath(url.path) { continue }

            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isPackageKey])
            if values?.isDirectory == true {
                let ext = url.pathExtension.lowercased()
                if Self.supportedFileExtensions.contains(ext) {
                    files.append(Self.standardized(url).resolvingSymlinksInPath())
                    enumerator.skipDescendants()
                } else if Self.excludedDirectoryNames.contains(url.lastPathComponent.lowercased()) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard Self.supportedFileExtensions.contains(url.pathExtension.lowercased()) else { continue }
            if values?.isRegularFile == true {
                files.append(Self.standardized(url).resolvingSymlinksInPath())
            }
        }
        return files
    }

    private func openDatabase() throws -> OpaquePointer? {
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK else {
            let message = db.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? "Could not open database."
            if let db { sqlite3_close(db) }
            throw RAGError.database(message)
        }
        return db
    }

    private func createSchema(_ db: OpaquePointer?) throws {
        try exec(db, """
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            path TEXT NOT NULL UNIQUE,
            display_name TEXT NOT NULL,
            file_type TEXT,
            file_hash TEXT NOT NULL,
            modified_at REAL,
            indexed_at REAL,
            source_kind TEXT NOT NULL,
            metadata_json TEXT
        );
        """)
        try exec(db, """
        CREATE TABLE IF NOT EXISTS chunks (
            id TEXT PRIMARY KEY,
            document_id TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            text TEXT NOT NULL,
            token_count INTEGER,
            page_number INTEGER,
            section_title TEXT,
            start_offset INTEGER,
            end_offset INTEGER,
            embedding_model TEXT,
            embedding_json TEXT,
            FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
        );
        """)
        try exec(db, """
        CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
            chunk_id UNINDEXED,
            text,
            section_title
        );
        """)
    }

    private func insertDocument(_ db: OpaquePointer?, id: String, path: String, displayName: String, fileType: String, fileHash: String, modifiedAt: TimeInterval, sourceKind: String) throws {
        try run(db, "INSERT INTO documents (id, path, display_name, file_type, file_hash, modified_at, indexed_at, source_kind, metadata_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", [
            id, path, displayName, fileType, fileHash, modifiedAt, Date().timeIntervalSince1970, sourceKind, "{}"
        ])
    }

    private func insertChunk(_ db: OpaquePointer?, id: String, documentID: String, chunkIndex: Int, text: String, pageNumber: Int?, sectionTitle: String?) throws {
        try run(db, "INSERT INTO chunks (id, document_id, chunk_index, text, token_count, page_number, section_title) VALUES (?, ?, ?, ?, ?, ?, ?)", [
            id, documentID, chunkIndex, text, max(1, text.split(whereSeparator: { $0.isWhitespace }).count), pageNumber as Any, sectionTitle as Any
        ])
        try run(db, "INSERT INTO chunks_fts (chunk_id, text, section_title) VALUES (?, ?, ?)", [
            id, text, sectionTitle as Any
        ])
    }

    @discardableResult
    private func removeDocument(path: String, db: OpaquePointer?) throws -> Int {
        let chunkIDs = try stringColumn(db, "SELECT c.id FROM chunks c JOIN documents d ON d.id = c.document_id WHERE d.path = ?", [path])
        for id in chunkIDs {
            try run(db, "DELETE FROM chunks_fts WHERE chunk_id = ?", [id])
        }
        try run(db, "DELETE FROM chunks WHERE document_id IN (SELECT id FROM documents WHERE path = ?)", [path])
        try run(db, "DELETE FROM documents WHERE path = ?", [path])
        return max(chunkIDs.isEmpty ? 0 : 1, 0)
    }

    private func documentFingerprints(under folderPath: String, db: OpaquePointer?) throws -> [String: String] {
        let normalizedFolderPath = folderPath.hasSuffix("/") ? folderPath : folderPath + "/"
        let sql = "SELECT path, file_hash FROM documents WHERE path = ? OR path LIKE ?"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw RAGError.database(lastError(db)) }
        defer { sqlite3_finalize(statement) }
        bind(folderPath, to: statement, index: 1)
        bind(normalizedFolderPath + "%", to: statement, index: 2)

        var rows: [String: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            rows[stringValue(statement, 0)] = stringValue(statement, 1)
        }
        return rows
    }

    private func fileFingerprint(_ url: URL) throws -> String {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        return "\(modified)-\(size)"
    }

    private func rankedChunks(_ db: OpaquePointer?, query: String, maxResults: Int) throws -> [[String: Any]] {
        let tokens = query
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { String($0) }
        let meaningfulTokens = tokens.filter { !Self.ftsStopWords.contains($0.lowercased()) }
        let searchTokens = meaningfulTokens.isEmpty ? tokens : meaningfulTokens

        let preciseQuery = searchTokens
            .prefix(4)
            .map { $0 + "*" }
            .joined(separator: " AND ")
        let broadQuery = searchTokens
            .prefix(8)
            .map { $0 + "*" }
            .joined(separator: " OR ")

        let results: [[String: Any]]
        if !searchTokens.isEmpty, let precise = try? executeFTSQuery(db, ftsQuery: preciseQuery, maxResults: maxResults), !precise.isEmpty {
            results = precise
        } else if let broad = try? executeFTSQuery(db, ftsQuery: broadQuery, maxResults: maxResults), !broad.isEmpty {
            results = broad
        } else {
            return try fallbackRankedChunks(db, query: query, maxResults: maxResults)
        }

        if results.count < max(maxResults / 2, 2) {
            let fallback = try fallbackRankedChunks(db, query: query, maxResults: maxResults - results.count)
            let existingIDs = Set(results.compactMap { $0["chunk_id"] as? String })
            let merged = results + fallback.filter { !existingIDs.contains($0["chunk_id"] as? String ?? "") }
            return merged
        }

        return results
    }

    private func executeFTSQuery(_ db: OpaquePointer?, ftsQuery: String, maxResults: Int) throws -> [[String: Any]] {
        let sql = """
        SELECT c.id, c.text, c.page_number, c.section_title, c.chunk_index, d.display_name, d.path, bm25(chunks_fts) AS score
        FROM chunks_fts
        JOIN chunks c ON c.id = chunks_fts.chunk_id
        JOIN documents d ON d.id = c.document_id
        WHERE chunks_fts MATCH ?
        ORDER BY score
        LIMIT ?;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw RAGError.database(lastError(db)) }
        defer { sqlite3_finalize(statement) }
        bind(ftsQuery, to: statement, index: 1)
        sqlite3_bind_int(statement, 2, Int32(maxResults))
        var results: [[String: Any]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let text = stringValue(statement, 1)
            results.append([
                "chunk_id": stringValue(statement, 0),
                "text": text,
                "preview": String(text.prefix(700)),
                "page": nullableInt(statement, 2) as Any,
                "section": nullableString(statement, 3) as Any,
                "chunk_index": Int(sqlite3_column_int(statement, 4)),
                "document": stringValue(statement, 5),
                "path": stringValue(statement, 6),
                "score": sqlite3_column_double(statement, 7)
            ])
        }
        return results
    }

    private func fallbackRankedChunks(_ db: OpaquePointer?, query: String, maxResults: Int) throws -> [[String: Any]] {
        let rawTerms = query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let meaningful = rawTerms.filter { !Self.ftsStopWords.contains($0) }
        let terms = meaningful.isEmpty ? rawTerms : meaningful
        var statement: OpaquePointer?
        let sql = "SELECT c.id, c.text, c.page_number, c.section_title, c.chunk_index, d.display_name, d.path FROM chunks c JOIN documents d ON d.id = c.document_id LIMIT 1000"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw RAGError.database(lastError(db)) }
        defer { sqlite3_finalize(statement) }
        var scored: [(Int, [String: Any])] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let text = stringValue(statement, 1)
            let displayName = stringValue(statement, 5).lowercased()
            let lower = text.lowercased()
            var score = 0
            for term in terms {
                if lower.contains(term) { score += 1 }
                if displayName.contains(term) { score += 2 }
            }
            guard score > 0 else { continue }
            scored.append((score, [
                "chunk_id": stringValue(statement, 0),
                "text": text,
                "preview": String(text.prefix(700)),
                "page": nullableInt(statement, 2) as Any,
                "section": nullableString(statement, 3) as Any,
                "chunk_index": Int(sqlite3_column_int(statement, 4)),
                "document": stringValue(statement, 5),
                "path": stringValue(statement, 6),
                "score": Double(score)
            ]))
        }
        return scored.sorted { $0.0 > $1.0 }.prefix(maxResults).map(\.1)
    }

    private func exec(_ db: OpaquePointer?, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? lastError(db)
            sqlite3_free(error)
            throw RAGError.database(message)
        }
    }

    private func run(_ db: OpaquePointer?, _ sql: String, _ values: [Any]) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw RAGError.database(lastError(db)) }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            bind(value, to: statement, index: Int32(index + 1))
        }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw RAGError.database(lastError(db)) }
    }

    private func stringColumn(_ db: OpaquePointer?, _ sql: String, _ values: [Any]) throws -> [String] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw RAGError.database(lastError(db)) }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            bind(value, to: statement, index: Int32(index + 1))
        }
        var rows: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(stringValue(statement, 0))
        }
        return rows
    }

    private func documentPaths(_ db: OpaquePointer?) throws -> [String] {
        try stringColumn(db, "SELECT path FROM documents ORDER BY display_name", [])
    }

    private func intScalar(_ db: OpaquePointer?, _ sql: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw RAGError.database(lastError(db)) }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func bind(_ value: Any, to statement: OpaquePointer?, index: Int32) {
        switch value {
        case let value as String:
            sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        case let value as Int:
            sqlite3_bind_int(statement, index, Int32(value))
        case let value as Double:
            sqlite3_bind_double(statement, index, value)
        case Optional<Int>.none, Optional<String>.none:
            sqlite3_bind_null(statement, index)
        default:
            sqlite3_bind_null(statement, index)
        }
    }

    private func stringValue(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }

    private func nullableString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : stringValue(statement, index)
    }

    private func nullableInt(_ statement: OpaquePointer?, _ index: Int32) -> Int? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, index))
    }

    private func lastError(_ db: OpaquePointer?) -> String {
        db.flatMap { sqlite3_errmsg($0).map { String(cString: $0) } } ?? "SQLite error."
    }

    private func resolveAllowedURL(_ rawPath: String, roots: Roots) throws -> URL {
        var trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "`\"'"))
        guard !trimmed.isEmpty else { throw RAGError.emptyPath }
        if isSensitivePath(trimmed) { throw RAGError.sensitivePath }
        if trimmed.components(separatedBy: "/").contains("..") { throw RAGError.pathNotAllowed("Path traversal is not allowed.") }

        let lower = trimmed.lowercased()
        let candidate: URL
        if lower == "desktop" || lower.hasPrefix("desktop/") {
            candidate = roots.desktop.appendingPathComponent(lower == "desktop" ? "" : String(trimmed.dropFirst("desktop/".count)))
        } else if lower == "downloads" || lower.hasPrefix("downloads/") {
            candidate = roots.downloads.appendingPathComponent(lower == "downloads" ? "" : String(trimmed.dropFirst("downloads/".count)))
        } else if lower == "documents" || lower.hasPrefix("documents/") {
            candidate = roots.documents.appendingPathComponent(lower == "documents" ? "" : String(trimmed.dropFirst("documents/".count)))
        } else if lower == "ibooks" || lower.hasPrefix("ibooks/") {
            candidate = roots.ibooks.appendingPathComponent(lower == "ibooks" ? "" : String(trimmed.dropFirst("ibooks/".count)))
        } else {
            let expanded = (trimmed as NSString).expandingTildeInPath
            candidate = expanded.hasPrefix("/") ? URL(fileURLWithPath: expanded) : roots.workspace.appendingPathComponent(expanded)
        }

        let standardizedCandidate = Self.standardized(candidate).resolvingSymlinksInPath()
        guard roots.readAllowed.contains(where: { isContained(standardizedCandidate, in: Self.standardized($0).resolvingSymlinksInPath()) }) else {
            throw RAGError.pathNotAllowed("Path must stay inside an allowed folder: workspace, ~/Ghost Outputs, ~/Desktop, ~/Downloads, ~/Documents, or ~/iBooks.")
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

    private func isSensitivePath(_ path: String) -> Bool {
        let lower = path.lowercased()
        return [
            "/.ssh", ".ssh/", "id_rsa", "id_ed25519", "private_key", "private-key",
            ".env", "keychain", "credentials", "credential", "secrets", "secret",
            "token", "apikey", "api_key", "password", "passwd", "recovery key",
            "seed phrase", "mnemonic", "cookies.sqlite"
        ].contains { lower.contains($0) }
    }

    private func extractDOCXText(from url: URL) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ghost-rag-docx-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["unzip", "-qq", url.path, "word/document.xml", "-d", tempDir.path]
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw RAGError.extractionFailed("Could not extract DOCX text.")
        }
        let xml = try String(contentsOf: tempDir.appendingPathComponent("word/document.xml"), encoding: .utf8)
        return stripXML(xml)
    }

    private func extractEPUBText(from url: URL) throws -> String {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        if exists && isDir.boolValue {
            let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
            var texts: [String] = []
            while let file = enumerator?.nextObject() as? URL {
                let ext = file.pathExtension.lowercased()
                guard ext == "xhtml" || ext == "html" || ext == "htm" else { continue }
                guard let raw = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let stripped = stripHTML(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                if !stripped.isEmpty { texts.append(stripped) }
            }
            guard !texts.isEmpty else {
                throw RAGError.extractionFailed("No readable text found in EPUB bundle.")
            }
            return texts.joined(separator: "\n\n")
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ghost-rag-epub-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["unzip", "-qq", url.path, "-d", tempDir.path]
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw RAGError.extractionFailed("Could not extract EPUB.")
        }

        let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
        var texts: [String] = []
        while let file = enumerator?.nextObject() as? URL {
            let ext = file.pathExtension.lowercased()
            guard ext == "xhtml" || ext == "html" || ext == "htm" else { continue }
            guard let raw = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let stripped = stripHTML(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            if !stripped.isEmpty {
                texts.append(stripped)
            }
        }
        guard !texts.isEmpty else {
            throw RAGError.extractionFailed("No readable text found in EPUB.")
        }
        return texts.joined(separator: "\n\n")
    }

    private func stripHTML(_ text: String) -> String {
        stripXML(text.replacingOccurrences(of: "(?is)<script.*?</script>|<style.*?</style>", with: " ", options: .regularExpression))
    }

    private func stripXML(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func ok(_ tool: String, summary: String, requestedPath: String? = nil, actualPath: String? = nil, payload: [String: Any] = [:]) -> [String: Any] {
        var result: [String: Any] = ["ok": true, "tool": tool, "verified": true, "summary": summary, "payload": payload]
        if let requestedPath { result["requested_path"] = requestedPath }
        if let actualPath { result["actual_path"] = actualPath }
        return result
    }

    private func fail(_ tool: String, requestedPath: String? = nil, error: Error) -> [String: Any] {
        var result: [String: Any] = ["ok": false, "tool": tool, "verified": false, "error": error.localizedDescription]
        if let requestedPath { result["requested_path"] = requestedPath }
        return result
    }
}
