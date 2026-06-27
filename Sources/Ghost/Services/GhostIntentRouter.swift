import Foundation

struct GhostIntentRouter: Sendable {
    private let artifactExtensions: Set<String> = [
        "pdf", "docx", "pptx", "csv", "txt", "md", "markdown", "html", "htm", "css", "js", "ts",
        "tsx", "jsx", "json", "xml", "yaml", "yml", "py", "swift", "sh", "sql", "rtf", "log", "svg", "toml"
    ]

    private let binaryArtifactExtensions: Set<String> = [
        "pdf", "docx", "pptx", "xlsx", "pages", "key", "numbers", "zip", "png", "jpg", "jpeg", "gif", "webp"
    ]

    // Keep this list intentionally narrow. Words like "write" and "draft" are
    // normal chat-composition verbs and should not create files unless another
    // explicit file/save cue is present.
    private let creationVerbs: [String] = [
        "create", "make", "generate", "save", "export", "build", "build me", "put", "place"
    ]

    private let conversationalWritingVerbs: [String] = [
        "write", "draft", "compose"
    ]

    private let artifactNouns: [String] = [
        "document", "doc", "report", "letter", "resume", "essay", "proposal",
        "invoice", "pdf", "docx", "spreadsheet", "csv", "presentation", "slides",
        "file", "text file", "markdown", "html page", "script"
    ]

    private let localTargets: [String] = [
        "desktop", "downloads", "documents", "finder", "folder",
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

    private let ragTargets: [String] = [
        "this document", "my document", "the document", "uploaded document",
        "my files", "my notes", "the pdf", "this pdf", "the folder",
        "the syllabus", "my syllabus", "the contract", "my contract",
        "indexed documents", "indexed files", "knowledge base", "rag"
    ]

    private let ragActions: [String] = [
        "what does", "where does", "find where", "ask questions about",
        "question about", "summarize", "compare", "mentions", "say about",
        "based on my uploaded", "based on my files", "based on these files",
        "index my", "index this", "ingest", "add to rag"
    ]

    func detect(
        prompt rawPrompt: String,
        includeClipboard: Bool,
        workspaceRoot: URL,
        hasClipboardText: Bool
    ) -> GhostDetectedIntent {
        let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = prompt.lowercased()

        if lower.hasPrefix("rag:") {
            return GhostDetectedIntent(
                kind: .fileSummary,
                confidence: 1.0,
                steps: ["retrieve document chunks", "cite sources", "answer from evidence"],
                reason: "Explicit RAG: prefix requested Ghost RAG retrieval.",
                inferredFileExtension: nil,
                requestedFilename: nil,
                usesClipboard: false,
                usesWorkspace: true,
                usesWeb: false
            )
        }

        let filename = requestedFilename(in: prompt)
        let extensionFromFilename = filename.flatMap { URL(fileURLWithPath: $0).pathExtension.nonEmpty }

        let explicitlyMentionedExtension = mentionedArtifactExtension(in: lower)
        let inferredDefaultExtension = inferredDefaultArtifactExtension(in: lower)
        let explicitExtension = extensionFromFilename ?? explicitlyMentionedExtension ?? inferredDefaultExtension

        let mentionsLocalTarget = containsAnyWordOrPhrase(lower, localTargets)
        let mentionsArtifactNoun = containsAnyWordOrPhrase(lower, artifactNouns)
        let mentionsCreationVerb = containsAnyWordOrPhrase(lower, creationVerbs)
        let mentionsConversationalWritingVerb = containsAnyWordOrPhrase(lower, conversationalWritingVerbs)
        let mentionsSaveTarget = containsAnyWordOrPhrase(lower, saveTargets)
        let mentionsExplicitSavePhrase = containsAnyWordOrPhrase(lower, [
            "save as", "export as", "save to", "save on", "put on", "put in", "place on", "place in",
            "write to", "create a file", "make a file", "generate a file", "download as"
        ])

        let responseComposition = isResponseCompositionPrompt(lower)
        let mentionsResearch = containsAny(lower, ["research", "sources", "citations", "citation", "web", "latest", "compare", "best", "find online", "look up", "references"])
        let mentionsClipboard = containsAny(lower, ["clipboard", "copied", "pasteboard"]) || (includeClipboard && hasClipboardText)

        let explicitFileNameRequested = filename != nil
        let binaryArtifactRequested = explicitExtension.map { binaryArtifactExtensions.contains($0.lowercased()) } ?? false
        let requestedActualArtifact =
            explicitFileNameRequested
            || mentionsExplicitSavePhrase
            || mentionsSaveTarget
            || binaryArtifactRequested
            || containsAnyWordOrPhrase(lower, ["make it a file", "turn this into a file", "export this", "save this"])

        let mentionsArtifactCreation =
            (mentionsCreationVerb || (mentionsConversationalWritingVerb && requestedActualArtifact))
            && (
                requestedActualArtifact
                || explicitlyMentionedExtension != nil
                || (mentionsArtifactNoun && !responseComposition)
            )

        // Critical rule: assignment/discussion/response-writing prompts answer in
        // chat by default. They only create a file when the user explicitly asks
        // for a file/export/save destination/extension.
        if mentionsArtifactCreation && (!responseComposition || requestedActualArtifact) {
            return GhostDetectedIntent(
                kind: .createArtifact,
                confidence: 0.96,
                steps: ["plan artifact", "generate content", "write file", "confirm path"],
                reason: "The prompt explicitly asks Ghost to create, save, export, or place a file.",
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
        let mentionsFiles = isLocalFileRequest(lower, mentionsLocalTarget: mentionsLocalTarget, mentionsArtifactNoun: mentionsArtifactNoun)
        let mentionsSummary = containsAny(lower, ["summarize", "summary", "explain this file", "what's inside", "what is inside", "read this"])
        let mentionsRAG = containsAny(lower, ragTargets) && containsAny(lower, ragActions)
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

        if mentionsCoding && !responseComposition {
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

        if mentionsRAG || (mentionsSummary && mentionsFiles) {
            return GhostDetectedIntent(
                kind: .fileSummary,
                confidence: 0.80,
                steps: ["retrieve document chunks", "cite sources", "answer from evidence"],
                reason: mentionsRAG ? "The prompt asks a document-grounded RAG question." : "The prompt asks Ghost to read or summarize files.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: true,
                usesWeb: false
            )
        }

        if mentionsFiles && !responseComposition {
            return GhostDetectedIntent(
                kind: .localFiles,
                confidence: 0.70,
                steps: ["search files", "rank matches", "show file cards"],
                reason: "The prompt references local files, folders, or documents.",
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
                reason: "The prompt asks for research or source-backed information.",
                inferredFileExtension: explicitExtension,
                requestedFilename: filename,
                usesClipboard: mentionsClipboard,
                usesWorkspace: false,
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
                "Create a file only because the user explicitly requested a saved/exported artifact.",
                "If the user asked for Desktop, Downloads, or Documents, save to that exact user folder, not the Ghost workspace.",
                "If no save location is provided, save under: \(outputFolder).",
                "After creating a file, verify the exact path exists before saying it was saved.",
                "If creating a PDF, generate a valid PDF file; if creating a DOCX, generate a valid DOCX package; if creating code, create runnable source files with sensible names.",
                "After creating a file, respond with a concise artifact card: file path, format, and useful next actions."
            ])
        case .localFiles, .fileSummary:
            lines.append(contentsOf: [
                "For document Q&A, use Ghost RAG retrieval before answering and cite returned chunks.",
                "If the named file or folder is not indexed yet, index it first, then query the RAG index.",
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
            lines.append(contentsOf: ["For simple one-shot reminders and calendar events, Ghost should use the native deterministic path before the model is asked.", "When running as an agent, create the actual reminder/calendar item with a real tool or a verified macOS command before confirming it.", "Clarify timing only when necessary. Ask before creating recurring or persistent automation."])
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
        let mentionsRAG = containsAny(lower, ragTargets) && containsAny(lower, ragActions)
        let responseComposition = isResponseCompositionPrompt(lower)

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

        if mentionsRAG {
            return true
        }

        if mentionsLocalAction && (mentionsLocalTarget || (mentionsArtifact && !responseComposition)) {
            return true
        }

        if mentionsArtifact && mentionsLocalTarget && !responseComposition {
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

        if containsAny(lower, ["document", "doc", "report", "letter", "resume", "proposal"]) {
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

    private func isResponseCompositionPrompt(_ lower: String) -> Bool {
        containsAny(lower, [
            "write what my response should be",
            "write what i should say",
            "write my response",
            "write my answer",
            "help me respond",
            "draft my response",
            "draft my answer",
            "discussion post",
            "assignment prompt",
            "my response should",
            "what my response should be"
        ])
    }

    private func isLocalFileRequest(_ lower: String, mentionsLocalTarget: Bool, mentionsArtifactNoun: Bool) -> Bool {
        if mentionsLocalTarget { return true }
        if containsAnyWordOrPhrase(lower, [
            "my files", "local files", "in downloads", "in documents", "on desktop", "from desktop",
            "open file", "find file", "read file", "summarize file", "this file", "that file",
            "folder", "directory", "workspace", "repo", "repository", "zip", "archive"
        ]) {
            return true
        }
        if mentionsArtifactNoun && containsAnyWordOrPhrase(lower, ["open", "find", "read", "summarize", "search", "locate"]) {
            return true
        }
        return false
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
            let normalized = ext == "markdown" ? "md" : ext
            let escaped = NSRegularExpression.escapedPattern(for: ext)
            let patterns = [
                #"(?<![A-Za-z0-9/])\."# + escaped + #"\b"#,
                #"\b"# + escaped + #"\s+file\b"#,
                #"\b"# + escaped + #"\s+document\b"#
            ]
            if patterns.contains(where: { lower.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }) {
                return normalized
            }
        }
        return nil
    }

    private func requestedFilename(in prompt: String) -> String? {
        let explicitPatterns = [
            #"(?:named|called|save as|export as|download as|filename|file name)\s+[`\"]?([A-Za-z0-9_ .()\-]+\.[A-Za-z0-9]{1,12})[`\"]?"#,
            #"(?:save|export|download|write|create|make|generate)\s+(?:it|this|the file)?\s*(?:as|to)?\s+[`\"]?([A-Za-z0-9_ .()\-]+\.[A-Za-z0-9]{1,12})[`\"]?"#
        ]

        for pattern in explicitPatterns {
            if let candidate = firstFilenameMatch(pattern: pattern, in: prompt, allowUnknownExtension: true) {
                return candidate
            }
        }

        // Quoted filenames are usually intentional. Still reject URL/domain fragments.
        if let quoted = firstFilenameMatch(
            pattern: #"[`\"]([A-Za-z0-9_ .()\-]+\.[A-Za-z0-9]{1,12})[`\"]"#,
            in: prompt,
            allowUnknownExtension: false
        ) {
            return quoted
        }

        // Bare filenames are accepted only for known artifact extensions. This
        // prevents www.acm.org / example.com from becoming bogus .acm/.com files.
        return firstFilenameMatch(
            pattern: #"\b([A-Za-z0-9_()\-]+\.(?:pdf|docx|pptx|csv|txt|md|markdown|html|htm|css|js|ts|tsx|jsx|json|xml|yaml|yml|py|swift|sh|sql|rtf|log|svg|toml))\b"#,
            in: prompt,
            allowUnknownExtension: false
        )
    }

    private func firstFilenameMatch(pattern: String, in prompt: String, allowUnknownExtension: Bool) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
        let matches = regex.matches(in: prompt, range: range)

        for match in matches where match.numberOfRanges > 1 {
            guard let nameRange = Range(match.range(at: 1), in: prompt) else { continue }
            let candidate = String(prompt[nameRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "`\"'.,;:()[]{}"))

            guard isSafeFilenameCandidate(candidate, allowUnknownExtension: allowUnknownExtension) else { continue }
            return candidate
        }

        return nil
    }

    private func isSafeFilenameCandidate(_ candidate: String, allowUnknownExtension: Bool) -> Bool {
        guard !candidate.isEmpty else { return false }
        let lower = candidate.lowercased()
        if lower.hasPrefix("http") || lower.hasPrefix("www.") { return false }
        if lower.contains("://") { return false }
        if lower.split(separator: ".").count > 2, !candidate.contains(" ") { return false }

        let ext = URL(fileURLWithPath: candidate).pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        if artifactExtensions.contains(ext) { return true }
        return allowUnknownExtension && !["com", "org", "net", "edu", "gov", "io", "co"].contains(ext)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
