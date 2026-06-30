import Foundation

enum ProviderAPIKey: String, CaseIterable, Identifiable {
    case anthropic
    case gemini
    case deepSeek

    // OpenCode-compatible provider keys.
    case openAI
    case openRouter
    case groq
    case xAI
    case mistral
    case together
    case fireworks
    case nvidia
    case moonshot
    case ollamaCloud
    case openCodeGo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anthropic:
            "Claude / Anthropic"
        case .gemini:
            "Gemini"
        case .deepSeek:
            "DeepSeek"
        case .openAI:
            "OpenAI"
        case .openRouter:
            "OpenRouter"
        case .groq:
            "Groq"
        case .xAI:
            "xAI"
        case .mistral:
            "Mistral"
        case .together:
            "Together AI"
        case .fireworks:
            "Fireworks AI"
        case .nvidia:
            "NVIDIA"
        case .moonshot:
            "Moonshot AI"
        case .ollamaCloud:
            "Ollama Cloud"
        case .openCodeGo:
            "OpenCode Go"
        }
    }

    var groupTitle: String {
        switch self {
        case .anthropic, .gemini, .deepSeek:
            "Ghost direct providers"
        case .openAI, .openRouter, .groq, .xAI, .mistral, .together, .fireworks, .nvidia, .moonshot, .ollamaCloud, .openCodeGo:
            "OpenCode / agent provider keys"
        }
    }

    var keychainAccount: String {
        "\(environmentKey.lowercased())-api-key"
    }

    var environmentKey: String {
        switch self {
        case .anthropic:
            "ANTHROPIC_API_KEY"
        case .gemini:
            "GEMINI_API_KEY"
        case .deepSeek:
            "DEEPSEEK_API_KEY"
        case .openAI:
            "OPENAI_API_KEY"
        case .openRouter:
            "OPENROUTER_API_KEY"
        case .groq:
            "GROQ_API_KEY"
        case .xAI:
            "XAI_API_KEY"
        case .mistral:
            "MISTRAL_API_KEY"
        case .together:
            "TOGETHER_API_KEY"
        case .fireworks:
            "FIREWORKS_API_KEY"
        case .nvidia:
            "NVIDIA_API_KEY"
        case .moonshot:
            "MOONSHOT_API_KEY"
        case .ollamaCloud:
            "OLLAMA_API_KEY"
        case .openCodeGo:
            "OPENCODE_API_KEY"
        }
    }
}
