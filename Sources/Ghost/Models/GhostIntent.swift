import Foundation

enum GhostIntentKind: String, CaseIterable, Identifiable, Sendable {
    case answer
    case research
    case localFiles
    case fileSummary
    case screenshotOCR
    case clipboardAction
    case createArtifact
    case organizeFiles
    case automation
    case coding
    case debugging
    case codeReview
    case shell

    var id: String { rawValue }

    var title: String {
        switch self {
        case .answer: "Answer"
        case .research: "Research"
        case .localFiles: "Files"
        case .fileSummary: "Summarize files"
        case .screenshotOCR: "Screenshot/OCR"
        case .clipboardAction: "Clipboard"
        case .createArtifact: "Create file"
        case .organizeFiles: "Organize files"
        case .automation: "Automation"
        case .coding: "Code"
        case .debugging: "Debug"
        case .codeReview: "Review"
        case .shell: "Terminal"
        }
    }

    var shortTitle: String {
        switch self {
        case .answer: "ask"
        case .research: "research"
        case .localFiles: "files"
        case .fileSummary: "summarize"
        case .screenshotOCR: "ocr"
        case .clipboardAction: "clipboard"
        case .createArtifact: "create"
        case .organizeFiles: "organize"
        case .automation: "automate"
        case .coding: "code"
        case .debugging: "debug"
        case .codeReview: "review"
        case .shell: "shell"
        }
    }

    var preferredAgentMode: GhostCodeAgentMode? {
        switch self {
        case .coding, .createArtifact:
            .build
        case .debugging:
            .build
        case .codeReview:
            .review
        case .shell:
            .build
        case .localFiles, .fileSummary, .screenshotOCR, .clipboardAction, .organizeFiles:
            .explore
        case .answer, .research, .automation:
            nil
        }
    }

    var shouldUseTerminalUI: Bool {
        switch self {
        case .coding, .debugging, .codeReview, .shell:
            true
        case .answer, .research, .localFiles, .fileSummary, .screenshotOCR, .clipboardAction, .createArtifact, .organizeFiles, .automation:
            false
        }
    }

    var requiresAgentTools: Bool {
        switch self {
        case .coding,
             .debugging,
             .codeReview,
             .shell,
             .localFiles,
             .fileSummary,
             .screenshotOCR,
             .createArtifact,
             .organizeFiles,
             .automation:
            true

        case .answer,
             .research,
             .clipboardAction:
            false
        }
    }

    var safetyLabel: String {
        switch self {
        case .answer, .research, .fileSummary, .screenshotOCR, .clipboardAction, .localFiles:
            "Read-only"
        case .createArtifact:
            "Create files only"
        case .organizeFiles:
            "Preview before changes"
        case .automation:
            "Ask before scheduling"
        case .coding, .debugging:
            "Edits need approval"
        case .codeReview:
            "Read diffs first"
        case .shell:
            "Ask before risky commands"
        }
    }
}

struct GhostContextChip: Identifiable, Equatable, Sendable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let isActive: Bool

    init(_ title: String, _ detail: String, systemImage: String, isActive: Bool = true) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.isActive = isActive
    }
}

struct GhostDetectedIntent: Equatable, Sendable {
    let kind: GhostIntentKind
    let confidence: Double
    let steps: [String]
    let reason: String
    let inferredFileExtension: String?
    let requestedFilename: String?
    let usesClipboard: Bool
    let usesWorkspace: Bool
    let usesWeb: Bool

    static let idle = GhostDetectedIntent(
        kind: .answer,
        confidence: 0,
        steps: ["answer"],
        reason: "Waiting for a prompt.",
        inferredFileExtension: nil,
        requestedFilename: nil,
        usesClipboard: false,
        usesWorkspace: false,
        usesWeb: false
    )

    var shortTitle: String { kind.shortTitle }
    var title: String { kind.title }

    var routeLine: String {
        steps.joined(separator: " \u{2192} ")
    }

}
