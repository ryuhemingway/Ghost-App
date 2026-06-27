import Foundation

enum GhostProvider: String, CaseIterable, Identifiable, Sendable {
    case lmStudio
    case ollama
    case claude
    case gemini
    case deepSeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lmStudio:
            "LM Studio"
        case .ollama:
            "Ollama"
        case .claude:
            "Claude"
        case .gemini:
            "Gemini"
        case .deepSeek:
            "DeepSeek v4"
        }
    }

    var subtitle: String {
        switch self {
        case .lmStudio:
            "Local AI"
        case .ollama:
            "Local Ollama models"
        case .claude:
            "Anthropic API"
        case .gemini:
            "Google AI Studio"
        case .deepSeek:
            "DeepSeek API"
        }
    }

    var ghostProvider: String {
        switch self {
        case .lmStudio:
            "lmstudio"
        case .ollama:
            "ollama"
        case .claude:
            "anthropic"
        case .gemini:
            "gemini"
        case .deepSeek:
            "deepseek"
        }
    }

    /// Provider prefix used by Hermes/OpenCode-style agents when they route
    /// models through a single `-m provider/model` argument.
    var agentModelPrefix: String {
        switch self {
        case .lmStudio:
            "lmstudio"
        case .ollama:
            "ollama"
        case .claude:
            "anthropic"
        case .gemini:
            "gemini"
        case .deepSeek:
            "deepseek"
        }
    }

    var isLocal: Bool {
        switch self {
        case .lmStudio, .ollama:
            true
        case .claude, .gemini, .deepSeek:
            false
        }
    }

    var acceptedAgentModelPrefixes: [String] {
        switch self {
        case .lmStudio:
            ["lmstudio"]
        case .ollama:
            ["ollama"]
        case .claude:
            ["anthropic", "claude"]
        case .gemini:
            ["gemini", "google"]
        case .deepSeek:
            ["deepseek"]
        }
    }

    var helpText: String {
        switch self {
        case .lmStudio:
            "Uses the local LM Studio server at localhost:1234."
        case .ollama:
            "Uses local Ollama models from localhost:11434. No API key required."
        case .claude:
            "Requires an Anthropic API key."
        case .gemini:
            "Requires a Gemini API key."
        case .deepSeek:
            "Uses your DeepSeek API key."
        }
    }

    var systemImage: String {
        switch self {
        case .lmStudio:
            return "desktopcomputer"
        case .ollama:
            return "shippingbox"
        case .claude:
            return "sparkles"
        case .gemini:
            return "diamond"
        case .deepSeek:
            return "bolt.horizontal"
        }
    }
}

enum DeepSeekModel: String, CaseIterable, Identifiable, Sendable {
    case flash = "deepseek-v4-flash"
    case pro = "deepseek-v4-pro"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flash: "DeepSeek v4 Flash"
        case .pro: "DeepSeek v4 Pro"
        }
    }

    var shortTitle: String {
        switch self {
        case .flash: "Flash"
        case .pro: "Pro"
        }
    }
}
