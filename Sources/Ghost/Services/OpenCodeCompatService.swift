import AppKit
import Foundation

struct OpenCodeCustomCommand: Sendable, Identifiable, Equatable {
    let name: String
    let description: String
    let agent: String?
    let model: String?
    let template: String

    var id: String { name }

    func render(arguments: String) -> String {
        var rendered = template
        rendered = rendered.replacingOccurrences(of: "$ARGUMENTS", with: arguments)
        let parts = arguments.split(separator: " ").map(String.init)
        for index in 0..<10 {
            let value = index < parts.count ? parts[index] : ""
            rendered = rendered.replacingOccurrences(of: "$\(index + 1)", with: value)
        }
        return rendered.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct OpenCodeCompatService: Sendable {
    func createOrUpdateAgentsFile(root: URL, projectFiles: [String]) throws -> String {
        try ensureOpenCodeDirectories(root: root)
        let agentsURL = root.appendingPathComponent("AGENTS.md")
        let existed = FileManager.default.fileExists(atPath: agentsURL.path)
        let existingBlock: String
        if existed, let existing = try? String(contentsOf: agentsURL, encoding: .utf8), !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            existingBlock = """

            ## Existing notes preserved from previous AGENTS.md
            \(existing)
            """
        } else {
            existingBlock = ""
        }

        let contents = """
        # AGENTS.md

        Project instructions for Ghost Code / OpenCode-compatible agent sessions.

        ## Project root
        `\(root.path)`

        ## Operating rules
        - Work from this project root unless the user explicitly changes directories.
        - Prefer small, reviewable patches.
        - Explain the plan before large or risky edits.
        - Use `@path/to/file` when referencing files.
        - Use `!command` output as ground truth for build, test, git, and shell state.
        - Never edit secrets, `.env`, credentials, private keys, generated build output, or dependency folders.
        - After code edits, run the narrowest useful verification command.
        - If you cannot run a command or edit a file, say that clearly instead of pretending it happened.

        ## Useful project map
        \(projectFiles.prefix(160).map { "- \($0)" }.joined(separator: "\n"))
        \(existingBlock)
        """

        try contents.write(to: agentsURL, atomically: true, encoding: .utf8)
        return existed ? "Updated AGENTS.md" : "Created AGENTS.md"
    }

    func ensureOpenCodeDirectories(root: URL) throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".opencode/commands", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".ghost/exports", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    func agentInstructionsBlock(root: URL) -> String {
        let candidates = [
            root.appendingPathComponent("AGENTS.md"),
            root.appendingPathComponent("GHOST.md")
        ]

        for url in candidates {
            guard
                FileManager.default.fileExists(atPath: url.path),
                let contents = try? String(contentsOf: url, encoding: .utf8),
                !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }

            return """

            Project instructions from \(url.lastPathComponent):
            \(String(contents.prefix(24_000)))
            """
        }
        return ""
    }

    func loadCustomCommands(root: URL) -> [OpenCodeCustomCommand] {
        let commandRoots = [
            root.appendingPathComponent(".opencode/commands", isDirectory: true),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/opencode/commands", isDirectory: true)
        ]

        var commands: [OpenCodeCustomCommand] = []
        var seen = Set<String>()

        for directory in commandRoots {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in urls where url.pathExtension.lowercased() == "md" {
                let name = url.deletingPathExtension().lastPathComponent
                guard !name.isEmpty, seen.insert(name).inserted else { continue }
                guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
                commands.append(parseCommand(name: name, raw: raw))
            }
        }

        return commands.sorted { $0.name < $1.name }
    }

    func customCommand(named rawName: String, root: URL) -> OpenCodeCustomCommand? {
        let name = rawName.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")).lowercased()
        return loadCustomCommands(root: root).first { $0.name.lowercased() == name }
    }

    func renderHelp(customCommands: [OpenCodeCustomCommand]) -> String {
        var sections = ["""
        [help]
        OpenCode-compatible commands:
          /help                 Show commands
          /connect              Open provider/API settings
          /compact, /summarize  Compact visible session context
          /details              Toggle tool/detail rendering
          /view markdown|terminal Toggle Ghost Code output renderer
          /markdown             Render assistant answers as Markdown
          /terminal             Render assistant answers as raw terminal text
          /editor               Open a prompt draft in the default editor
          /exit, /quit, /q      Quit Ghost
          /export               Export current session to Markdown
          /init                 Create/update AGENTS.md and .opencode folders
          /models               Show model/provider options
          /new, /clear          Start a new session
          /sessions             List exported Ghost Code sessions
          /resume, /continue    Alias for /sessions
          /undo                 Undo last tracked Build-mode file changes
          /redo                 Redo last undone Build-mode file changes
          /share                Export a local shareable Markdown transcript

        Ghost Code commands:
          /plan                 Read-only planning mode
          /build                Coding build mode with tracked changes
          /explore              Codebase exploration mode
          /review               Show git status and diff
          /pwd                  Show current workspace
          /cd path              Change workspace folder
          /files [query]        List workspace files as @file references
          /open @file           Print a file into the terminal
          /grep text            Search workspace text
          /ls                   List current directory
          /copy                 Copy last answer
          /stop                 Stop current run
          !command              Run a shell command in the workspace
          @file                 Attach file context to the next AI request
        """]

        if !customCommands.isEmpty {
            let rendered = customCommands.map { command in
                let detail = command.description.isEmpty ? "Custom command" : command.description
                return "  /\(command.name.padding(toLength: 20, withPad: " ", startingAt: 0)) \(detail)"
            }.joined(separator: "\n")
            sections.append("""

            Project/user custom commands:
            \(rendered)
            """)
        }

        return sections.joined()
    }

    func exportTranscript(messages: [GhostMessage], root: URL) throws -> URL {
        try ensureOpenCodeDirectories(root: root)
        let timestamp = Self.timestampFormatter.string(from: Date())
        let url = root.appendingPathComponent(".ghost/exports/ghost-code-\(timestamp).md")
        let body = messages.map(renderMarkdown).joined(separator: "\n\n---\n\n")
        let contents = """
        # Ghost Code Session

        Exported: \(Date())
        Workspace: `\(root.path)`

        ---

        \(body.isEmpty ? "No messages yet." : body)
        """
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func listExports(root: URL, limit: Int = 20) -> [String] {
        let directory = root.appendingPathComponent(".ghost/exports", isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { lhs, rhs in
                let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lDate > rDate
            }
            .prefix(limit)
            .map { $0.path }
    }

    func openEditorDraft(root: URL, seed: String) throws -> URL {
        try ensureOpenCodeDirectories(root: root)
        let url = root.appendingPathComponent(".ghost/prompt-draft.md")
        try seed.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(url)
        return url
    }

    private func parseCommand(name: String, raw: String) -> OpenCodeCustomCommand {
        var description = ""
        var agent: String?
        var model: String?
        var body = raw

        if raw.hasPrefix("---"), let endRange = raw.range(of: "\n---", range: raw.index(raw.startIndex, offsetBy: 3)..<raw.endIndex) {
            let frontmatter = String(raw[raw.index(raw.startIndex, offsetBy: 3)..<endRange.lowerBound])
            body = String(raw[endRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            for line in frontmatter.split(separator: "\n") {
                let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard parts.count == 2 else { continue }
                switch parts[0].lowercased() {
                case "description": description = parts[1]
                case "agent": agent = parts[1]
                case "model": model = parts[1]
                default: break
                }
            }
        }

        return OpenCodeCustomCommand(
            name: name,
            description: description,
            agent: agent,
            model: model,
            template: body
        )
    }

    private func renderMarkdown(_ message: GhostMessage) -> String {
        let role: String
        switch message.role {
        case .user: role = "User"
        case .ghost: role = "Ghost"
        case .system: role = "System"
        }
        return """
        ## \(role)

        ```text
        \(message.text)
        ```
        """
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
