import Foundation

enum GhostProvider: String, CaseIterable, Identifiable, Sendable {
    case lmStudio
    case ollama
    case claude
    case gemini
    case deepSeek
    case openCodeGo

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
        case .openCodeGo:
            "OpenCode Go"
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
        case .openCodeGo:
            "OpenCode Go API"
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
        case .openCodeGo:
            "opencode-go"
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
        case .openCodeGo:
            "opencode-go"
        }
    }

    var isLocal: Bool {
        switch self {
        case .lmStudio, .ollama:
            true
        case .claude, .gemini, .deepSeek, .openCodeGo:
            false
        }
    }

    func supportsVision(model: String) -> Bool {
        switch self {
        case .claude, .gemini:
            return true
        case .lmStudio, .ollama:
            let normalized = model.lowercased()
            return [
                "vision",
                "vl",
                "llava",
                "moondream",
                "bakllava",
                "minicpm-v",
                "qwen2-vl",
                "qwen2.5-vl",
                "qwen-vl",
                "gemma3",
                "pixtral"
            ].contains { normalized.contains($0) }
        case .deepSeek, .openCodeGo:
            return false
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
        case .openCodeGo:
            ["opencode-go", "opencode", "go"]
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
        case .openCodeGo:
            "Uses your OpenCode Go API key and syncs models from OpenCode Go."
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
        case .openCodeGo:
            return "globe"
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
