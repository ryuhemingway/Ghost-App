import Foundation

struct GhostIntentRouter: Sendable {
    private let artifactExtensions: Set<String> = [
        "pdf", "docx", "pptx", "csv", "txt", "md", "markdown", "html", "htm", "css", "js", "ts",
        "tsx", "jsx", "json", "xml", "yaml", "yml", "py", "swift", "sh", "sql", "rtf", "log"
    ]

    private let creationVerbs: [String] = [
        "create", "make", "generate", "write", "save", "export",
        "draft", "build me", "put", "place"
    ]

    private let artifactNouns: [String] = [
        "document", "doc", "report", "letter", "resume", "essay", "proposal",
        "invoice", "pdf", "docx", "spreadsheet", "csv", "presentation", "slides",
        "file", "text file", "markdown", "html page", "script"
    ]

    private let localTargets: [String] = [
        "desktop", "downloads", "documents", "finder", "folder", "file",
        "workspace", "project", "repo", "repository", "directory",
        "~/", "/users/", "mac"
    ]

    private let localActions: [String] = [
        "create", "make", "write", "save", "export", "put", "place",
        "move", "copy", "rename", "delete", "trash", "organize",
        "open", "find", "read", "summarize"
    ]

    private let saveTargets: [String] = [
        "desktop", "downloads", "documents", "folder", "finder"
    ]

    func detect(
        prompt rawPrompt: String,
        includeClipboard: Bool,
        workspaceRoot: URL,
        hasClipboardText: Bool
    ) -> GhostDetectedIntent {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = prompt.lowercased()
        let filename = requestedFilename(in: prompt)
        let extensionFromFilename = filename.flatMap { URL(fileURLWithPath: $0).pathExtension.nonEmpty }

        let explicitExtension =
            extensionFromFilename
            ?? mentionedArtifactExtension(in: lower)
            ?? inferredDefaultArtifactExtension(in: lower)

        let mentionsLocalTarget = containsAnyWordOrPhrase(lower, localTargets)
        let mentionsArtifactNoun = containsAnyWordOrPhrase(lower, artifactNouns)
        let mentionsCreationVerb = containsAnyWordOrPhrase(lower, creationVerbs)
        let mentionsSaveTarget = containsAnyWordOrPhrase(lower, saveTargets)

        let mentionsResearch = containsAny(lower, ["research", "sources", "citations", "web", "latest", "compare", "best", "find online", "look up"])
        let mentionsClipboard = containsAny(lower, ["clipboard", "copied", "pasteboard"]) || (includeClipboard && hasClipboardText)

        let mentionsArtifactCreation =
            mentionsCreationVerb
            && (
                explicitExtension != nil
                || mentionsArtifactNoun
                || mentionsSaveTarget
                || mentionsLocalTarget
            )

        if mentionsArtifactCreation {
            return GhostDetectedIntent(
                kind: .createArtifact,
                confidence: 0.96,
                steps: ["plan artifact", "generate content", "write file", "confirm path"],
                reason: "The prompt asks Ghost to create, save, export, or place a file. This requires local tools.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: true,
                usesWeb: mentionsResearch
            )
        }
        let mentionsCoding = isExplicitCodingTask(lower)
            || containsAnyWordOrPhrase(lower, [
                "code", "coding", "implement", "implementation", "refactor", "compile", "build",
                "fix code", "bug", "debug", "stack trace", "test", "tests", "failing test",
                "function", "class", "api", "endpoint", "component", "swiftui", "typescript",
                "javascript", "python", "html", "css", "xcode", "repo", "repository",
                "package swift", "package json", "pull request"
            ])
            || containsCodeFileReference(lower)
        let mentionsReview = containsAnyWordOrPhrase(lower, ["review", "diff", "pull request", "pr", "regression", "audit changes"])
        let mentionsShell = lower.hasPrefix("run ") || lower.hasPrefix("terminal ") || lower.hasPrefix("shell ") || lower.hasPrefix("!")
        let mentionsFiles =
            containsAny(lower, ["file", "folder", "finder", "downloads", "desktop", "documents", "pdf", "docx", "csv", "zip", "archive"])
            || mentionsLocalTarget
            || mentionsArtifactNoun
        let mentionsSummary = containsAny(lower, ["summarize", "summary", "explain this file", "what's inside", "what is inside", "read this"])
        let mentionsScreenshot = containsAny(lower, ["screenshot", "image", "ocr", "extract text", "read text"])
        let mentionsAutomation = isAutomationTask(lower)
        let mentionsOrganize = containsAny(lower, ["organize", "clean", "cleanup", "rename", "move", "delete", "trash", "sort"])

        if mentionsShell {
            return GhostDetectedIntent(
                kind: .shell,
                confidence: 0.92,
                steps: ["prepare terminal", "run command", "show output"],
                reason: "The prompt asks for a terminal or shell action.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: false,
                usesWorkspace: true,
                usesWeb: false
            )
        }

        if mentionsReview && mentionsCoding {
            return GhostDetectedIntent(
                kind: .codeReview,
                confidence: 0.84,
                steps: ["inspect workspace", "read diffs", "review risks", "suggest fixes"],
                reason: "The prompt asks for coding review or diff analysis.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: true,
                usesWeb: false
            )
        }

        if containsAny(lower, ["debug", "bug", "error", "stack trace", "failing test", "crash"]) && mentionsCoding {
            return GhostDetectedIntent(
                kind: .debugging,
                confidence: 0.86,
                steps: ["inspect error", "find relevant files", "patch fix", "run verification"],
                reason: "The prompt asks Ghost to debug or fix a coding problem.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: true,
                usesWeb: false
            )
        }

        if mentionsCoding {
            return GhostDetectedIntent(
                kind: .coding,
                confidence: 0.78,
                steps: ["inspect workspace", "plan change", "edit files", "run validation"],
                reason: "The prompt is about code and should use Ghost's terminal agent.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: true,
                usesWeb: false
            )
        }

        if mentionsAutomation {
            return GhostDetectedIntent(
                kind: .automation,
                confidence: 0.72,
                steps: ["understand schedule", "confirm details", "create reminder or watch"],
                reason: "The prompt asks for a future, recurring, or conditional task.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: mentionsFiles,
                usesWeb: mentionsResearch
            )
        }

        if mentionsOrganize && mentionsFiles {
            return GhostDetectedIntent(
                kind: .organizeFiles,
                confidence: 0.82,
                steps: ["scan files", "suggest organization", "preview changes", "apply after approval"],
                reason: "The prompt asks Ghost to organize, rename, move, or clean files.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: false,
                usesWorkspace: true,
                usesWeb: false
            )
        }

        if mentionsSummary && mentionsFiles {
            return GhostDetectedIntent(
                kind: .fileSummary,
                confidence: 0.80,
                steps: ["find relevant files", "read contents", "summarize"],
                reason: "The prompt asks Ghost to read or summarize files.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: true,
                usesWeb: false
            )
        }

        if mentionsFiles {
            return GhostDetectedIntent(
                kind: .localFiles,
                confidence: 0.70,
                steps: ["search files", "rank matches", "show file cards"],
                reason: "The prompt references files, folders, or local documents.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: true,
                usesWeb: false
            )
        }

        if mentionsScreenshot {
            return GhostDetectedIntent(
                kind: .screenshotOCR,
                confidence: 0.76,
                steps: ["find image context", "extract text", "answer"],
                reason: "The prompt references a screenshot, image, or OCR task.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: false,
                usesWeb: false
            )
        }

        if mentionsClipboard {
            return GhostDetectedIntent(
                kind: .clipboardAction,
                confidence: 0.72,
                steps: ["read clipboard", "transform content", "answer"],
                reason: "The prompt asks Ghost to use the clipboard.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: true,
                usesWorkspace: false,
                usesWeb: false
            )
        }

        if mentionsResearch {
            return GhostDetectedIntent(
                kind: .research,
                confidence: 0.74,
                steps: ["search web", "read sources", "synthesize with citations"],
                reason: "The prompt asks for research or current information.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: mentionsFiles,
                usesWeb: true
            )
        }

        return GhostDetectedIntent(
            kind: .answer,
            confidence: 0.45,
            steps: ["answer"],
            reason: "Default conversational question.",
            inferredFileExtension: explicitExtension,
            requestedFilename: filename,
            usesClipboard: mentionsClipboard,
            usesWorkspace: false,
            usesWeb: false
        )
    }

    func contextChips(
        for intent: GhostDetectedIntent,
        includeClipboard: Bool,
        hasClipboardText: Bool,
        workspaceRoot: URL,
        activityCount: Int
    ) -> [GhostContextChip] {
        var chips: [GhostContextChip] = [
            GhostContextChip("Intent", intent.title, systemImage: "sparkles"),
            GhostContextChip("Permission", intent.kind.safetyLabel, systemImage: "lock.shield"),
            GhostContextChip("Workspace", workspaceRoot.lastPathComponent.nonEmpty ?? "~", systemImage: "folder")
        ]

        if includeClipboard || intent.usesClipboard {
            chips.append(GhostContextChip("Clipboard", hasClipboardText ? "available" : "empty", systemImage: "doc.on.clipboard", isActive: hasClipboardText))
        }
        if intent.usesWeb {
            chips.append(GhostContextChip("Web", "requested", systemImage: "globe"))
        }
        if let ext = intent.inferredFileExtension {
            chips.append(GhostContextChip("Output", ".\(ext)", systemImage: "doc.badge.plus"))
        }
        if activityCount > 0 {
            chips.append(GhostContextChip("Events", "\(activityCount)", systemImage: "waveform.path.ecg"))
        }
        return chips
    }

    func instructions(for intent: GhostDetectedIntent, workspaceRoot: URL) -> String {
        let outputFolder = workspaceRoot.appendingPathComponent("Ghost Outputs", isDirectory: true).path
        var lines: [String] = [
            "Ghost inferred intent: \(intent.kind.title).",
            "Ghost route: \(intent.routeLine).",
            "Permission policy: \(intent.kind.safetyLabel)."
        ]

        switch intent.kind {
        case .coding, .debugging, .codeReview, .shell:
            lines.append(contentsOf: [
                "For coding tasks, operate inside the current workspace terminal. Do not hand off to OpenCode.",
                "Inspect relevant files before editing. Prefer small patches and validation commands.",
                "When a command is destructive or broad, explain it before running it."
            ])
        case .createArtifact:
            lines.append(contentsOf: [
                "The user may ask for any file type, including PDF, DOCX, CSV, Python, HTML, TXT, Markdown, JSON, Swift, shell scripts, and more.",
                "Create the requested file directly when possible. If no save location is provided, save under: \(outputFolder).",
                "If creating a PDF, generate a valid PDF file; if creating a DOCX, generate a valid DOCX package; if creating code, create runnable source files with sensible names.",
                "After creating a file, respond with a concise artifact card: file path, format, and useful next actions."
            ])
        case .localFiles, .fileSummary:
            lines.append(contentsOf: [
                "Search and read local files only when relevant. Show the exact matched file paths.",
                "Do not modify, move, rename, or delete files during read-only file tasks."
            ])
        case .organizeFiles:
            lines.append(contentsOf: [
                "First show a before/after file operation preview.",
                "Do not rename, move, or delete files until the user approves the preview.",
                "Deletion should mean moving to Trash, not permanent deletion."
            ])
        case .research:
            lines.append("Use web research with citations when available. Clearly separate sourced facts from your reasoning.")
        case .screenshotOCR:
            lines.append("Use screenshot or image context when available. Extract text before answering OCR requests.")
        case .clipboardAction:
            lines.append("Use clipboard context only when it is explicitly included or requested.")
        case .automation:
            lines.append("Clarify timing only when necessary. Ask before creating recurring or persistent automation.")
        case .answer:
            break
        }

        return lines.joined(separator: "\n")
    }

    func requiresGhostTools(prompt rawPrompt: String, intent: GhostDetectedIntent) -> Bool {
        let lower = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if intent.kind.requiresAgentTools {
            return true
        }

        let mentionsLocalTarget = containsAny(lower, localTargets)
        let mentionsLocalAction = containsAny(lower, localActions)

        let mentionsArtifact =
            containsAny(lower, artifactNouns)
            || mentionedArtifactExtension(in: lower) != nil
            || inferredDefaultArtifactExtension(in: lower) != nil

        let mentionsContinuation = containsAny(lower, [
            "previous task context",
            "follow-up request",
            "continuation of the previous file creation task",
            "now make another",
            "make another",
            "create another",
            "another one",
            "same thing",
            "same as before"
        ])

        let mentionsClipboardWrite = containsAny(lower, [
            "copy to clipboard",
            "put on clipboard",
            "replace clipboard",
            "set clipboard"
        ])

        let mentionsPersonalApp = containsAny(lower, [
            "calendar", "email", "gmail", "finder",
            "desktop", "downloads", "documents"
        ])

        if mentionsContinuation && mentionsArtifact {
            return true
        }

        if mentionsLocalAction && (mentionsLocalTarget || mentionsArtifact) {
            return true
        }

        if mentionsArtifact && mentionsLocalTarget {
            return true
        }

        if mentionsClipboardWrite {
            return true
        }

        if mentionsPersonalApp {
            return true
        }

        return false
    }

    private func inferredDefaultArtifactExtension(in lower: String) -> String? {
        if lower.contains("pdf") {
            return "pdf"
        }

        if containsAny(lower, ["docx", "word document"]) {
            return "docx"
        }

        if containsAny(lower, ["spreadsheet", "csv"]) {
            return "csv"
        }

        if containsAny(lower, ["presentation", "slides", "slide deck"]) {
            return "pptx"
        }

        if containsAny(lower, ["markdown", "md file"]) {
            return "md"
        }

        if containsAny(lower, ["html", "web page", "html page"]) {
            return "html"
        }

        if containsAny(lower, ["python script", "python file"]) {
            return "py"
        }

        if containsAny(lower, ["swift file", "swift code"]) {
            return "swift"
        }

        if containsAny(lower, ["shell script", "bash script"]) {
            return "sh"
        }

        if containsAny(lower, ["document", "doc", "report", "letter", "resume", "essay", "proposal"]) {
            return "docx"
        }

        if containsAny(lower, ["text file", "plain text"]) {
            return "txt"
        }

        return nil
    }

    private func containsAnySubstring(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0.lowercased()) }
    }

    private func containsAnyWordOrPhrase(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { needle in
            let escaped = NSRegularExpression.escapedPattern(for: needle.lowercased())
            let pattern = #"\b"# + escaped + #"\b"#

            return value.range(
                of: pattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    private func isExplicitCodingTask(_ lower: String) -> Bool {
        containsAnyWordOrPhrase(lower, [
            "debug", "fix code", "compile", "build error",
            "run tests", "swift build", "npm", "xcode", "stack trace",
            "refactor", "implement feature", "edit the codebase",
            "open project", "repo", "repository"
        ])
    }

    private func isAutomationTask(_ lower: String) -> Bool {
        if containsAnyWordOrPhrase(lower, [
            "remind", "reminder", "notify me", "alert me", "set a timer",
            "set an alarm", "every day", "daily", "weekly", "monthly",
            "recurring", "repeat", "watch", "monitor", "schedule this",
            "schedule a", "create reminder"
        ]) {
            return true
        }

        let conditionalCues = ["when i ", "whenever ", "if "]
        guard conditionalCues.contains(where: { lower.contains($0) }) else {
            return false
        }

        return containsAnyWordOrPhrase(lower, [
            "remind", "notify", "alert", "watch", "monitor", "run",
            "open", "send", "create", "move", "copy", "delete"
        ])
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private func isCodeExtension(_ value: String?) -> Bool {
        guard let value else { return false }
        return ["py", "swift", "js", "ts", "tsx", "jsx", "html", "css", "sh", "sql", "java", "kt", "go", "rs", "cpp", "c", "h"].contains(value)
    }

    private func containsCodeFileReference(_ text: String) -> Bool {
        [".swift", ".py", ".js", ".ts", ".tsx", ".html", ".css", ".json", ".sh", "package.swift", "package.json"].contains { text.contains($0) }
    }

    private func mentionedArtifactExtension(in lower: String) -> String? {
        for ext in artifactExtensions.sorted(by: { $0.count > $1.count }) {
            if lower.contains(".\(ext)") || lower.contains(" \(ext) file") || lower.contains(" \(ext) document") {
                return ext == "markdown" ? "md" : ext
            }
        }
        return nil
    }

    private func requestedFilename(in prompt: String) -> String? {
        let patterns = [
            #"(?:named|called|save as|export as)\s+[`\"]?([A-Za-z0-9_ .\-]+\.[A-Za-z0-9]+)[`\"]?"#,
            #"[`\"]([A-Za-z0-9_ .\-]+\.[A-Za-z0-9]+)[`\"]"#,
            #"\b([A-Za-z0-9_\-]+\.[A-Za-z0-9]+)\b"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
            guard let match = regex.firstMatch(in: prompt, range: range), match.numberOfRanges > 1 else { continue }
            guard let nameRange = Range(match.range(at: 1), in: prompt) else { continue }
            let candidate = String(prompt[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let ext = URL(fileURLWithPath: candidate).pathExtension.lowercased()
            if artifactExtensions.contains(ext) || !ext.isEmpty {
                return candidate
            }
        }
        return nil
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
