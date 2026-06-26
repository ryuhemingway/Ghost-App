import Foundation
import CoreGraphics

/// How a prompt is executed.
///
/// - `ghostAgent`: shells out to the local `ghost` CLI (the original behavior).
///   Full agentic loop — tools, approval modes, working directory, multi-turn.
/// - `directAPI`: calls the selected provider's HTTP API directly with the
///   user's saved key. Fast single-shot inference without requiring Ghost.
enum ExecutionEngine: String, CaseIterable, Identifiable, Sendable {
    case ghostAgent
    case directAPI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ghostAgent:
            "Ghost Agent"
        case .directAPI:
            "Direct API"
        }
    }

    var shortTitle: String {
        switch self {
        case .ghostAgent:
            "Agent"
        case .directAPI:
            "Direct"
        }
    }

    var subtitle: String {
        switch self {
        case .ghostAgent:
            "Local ghost CLI · tools, approvals, multi-turn"
        case .directAPI:
            "Provider API · fastest, key-only, no local tools"
        }
    }

    var systemImage: String {
        switch self {
        case .ghostAgent:
            "terminal"
        case .directAPI:
            "network"
        }
    }
}

enum EnginePreference: String, CaseIterable, Identifiable, Sendable {
    case auto
    case forceGhost
    case forceDirect

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            "Auto"
        case .forceGhost:
            "Always Agent"
        case .forceDirect:
            "Always Direct"
        }
    }

    var subtitle: String {
        switch self {
        case .auto:
            "Ghost chooses Direct API for simple answers and Ghost Agent for local tools, files, coding, and personal actions."
        case .forceGhost:
            "Always use Ghost Agent. Best for local files, Desktop actions, coding, shell commands, and multi-step work."
        case .forceDirect:
            "Always use Direct API. Fastest, but cannot reliably use local Mac tools or write files."
        }
    }
}

enum GhostInterfaceMode: String, CaseIterable, Identifiable, Sendable {
    case glass
    case terminal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: "Ghost Glass"
        case .terminal: "Ghost Code"
        }
    }

    var systemImage: String {
        switch self {
        case .glass: "sparkles"
        case .terminal: "terminal"
        }
    }
    var preferredPanelSize: CGSize {
        switch self {
        case .glass:
            CGSize(width: 740, height: 760)
        case .terminal:
            CGSize(width: 1240, height: 760)
        }
    }
}

enum GhostPanelSizeMode: String, CaseIterable, Identifiable, Sendable {
    case mini
    case normal
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mini: "Mini"
        case .normal: "Normal"
        case .full: "Full"
        }
    }

    var systemImage: String {
        switch self {
        case .mini: "text.bubble"
        case .normal: "rectangle"
        case .full: "arrow.up.left.and.arrow.down.right"
        }
    }

    var help: String {
        switch self {
        case .mini: "Mini quick ask"
        case .normal: "Normal panel"
        case .full: "Full screen panel"
        }
    }

    func fallbackSize(for interfaceMode: GhostInterfaceMode) -> CGSize {
        switch self {
        case .mini:
            CGSize(width: 430, height: 210)
        case .normal:
            interfaceMode.preferredPanelSize
        case .full:
            CGSize(width: 1320, height: 860)
        }
    }

    var minimumSize: CGSize {
        switch self {
        case .mini:
            CGSize(width: 360, height: 160)
        case .normal:
            CGSize(width: 560, height: 520)
        case .full:
            CGSize(width: 760, height: 560)
        }
    }
}

enum GhostInterfacePreference: String, CaseIterable, Identifiable, Sendable {
    case adaptive
    case glass
    case terminal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adaptive: return "Adaptive"
        case .glass: return "Glass"
        case .terminal: return "Terminal"
        }
    }

    var subtitle: String {
        switch self {
        case .adaptive:
            return "Ghost can switch between glass and terminal when useful."
        case .glass:
            return "Always stay in the glass chat interface."
        case .terminal:
            return "Always stay in the terminal interface."
        }
    }
}


enum GhostCodeOutputMode: String, CaseIterable, Identifiable, Sendable {
    case terminal
    case markdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terminal: "Terminal"
        case .markdown: "Markdown"
        }
    }

    var subtitle: String {
        switch self {
        case .terminal: "Raw OpenCode-style event stream"
        case .markdown: "Readable rendered assistant answers"
        }
    }

    var systemImage: String {
        switch self {
        case .terminal: "terminal"
        case .markdown: "doc.richtext"
        }
    }

    var promptHint: String {
        switch self {
        case .terminal: "terminal view"
        case .markdown: "markdown view"
        }
    }
}

enum GhostCodeAgentMode: String, CaseIterable, Identifiable, Sendable {
    case plan
    case build
    case explore
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plan: "Plan"
        case .build: "Build"
        case .explore: "Explore"
        case .review: "Review"
        }
    }

    var subtitle: String {
        switch self {
        case .plan: "Inspect & propose — no edits"
        case .build: "Edit files & run commands"
        case .explore: "Read & map the codebase"
        case .review: "Inspect diffs & catch bugs"
        }
    }

    var terminalLabel: String {
        switch self {
        case .plan: "plan/read-only"
        case .build: "build/patches"
        case .explore: "explore/search"
        case .review: "review/diff"
        }
    }

    var instruction: String {
        switch self {
        case .plan:
            "Plan mode: inspect and propose steps first. Do not claim that files were changed unless a tool actually changed them."
        case .build:
            "Build mode: make small, reviewable implementation steps. Prefer patches, then recommend or run validation commands when available."
        case .explore:
            "Explore mode: focus on reading, mapping, and explaining the codebase before suggesting edits."
        case .review:
            "Review mode: inspect diffs and code for bugs, regressions, unsafe behavior, missing tests, and unclear UX."
        }
    }
}
