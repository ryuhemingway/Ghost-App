import Foundation

enum EffortMode: String, CaseIterable, Identifiable {
    case low
    case medium
    case high
    case max

    var id: String { rawValue }

    var ghostReasoningEffort: String {
        self == .max ? "xhigh" : rawValue
    }

    var maxTurns: Int {
        switch self {
        case .low: 4
        case .medium: 12
        case .high: 40
        case .max: 90
        }
    }

    var maxTokens: Int {
        switch self {
        case .low: 900
        case .medium: 1_800
        case .high: 4_000
        case .max: 8_000
        }
    }

    func title(for provider: GhostProvider) -> String {
        switch provider {
        case .deepSeek:
            switch self {
            case .low: "Low"
            case .medium: "Medium"
            case .high: "High"
            case .max: "Max"
            }
        case .lmStudio, .ollama:
            switch self {
            case .low: "Fast"
            case .medium: "Normal"
            case .high: "Deep"
            case .max: "Max"
            }
        case .claude:
            switch self {
            case .low: "Quick"
            case .medium: "Balanced"
            case .high: "Deep"
            case .max: "Max"
            }
        case .gemini:
            switch self {
            case .low: "Flash"
            case .medium: "Balanced"
            case .high: "Thinking"
            case .max: "Max"
            }
        }
    }

    var promptInstruction: String {
        switch self {
        case .low:
            "Use low effort. Answer quickly and directly."
        case .medium:
            "Use medium effort. Be practical and concise."
        case .high:
            "Use high effort. Think carefully and use tools when relevant."
        case .max:
            "Use maximum effort. Be thorough and use tools when useful."
        }
    }
}

enum ApprovalMode: String, CaseIterable, Identifiable {
    case ask
    case safeAuto
    case yolo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: "Ask"
        case .safeAuto: "Safe"
        case .yolo: "Max"
        }
    }
}

struct QueuedHarnessTask: Identifiable, Equatable {
    enum Status: String {
        case pending = "Pending"
        case running = "Running"
        case done = "Done"
        case failed = "Failed"
    }

    let id = UUID()
    let prompt: String
    var status: Status = .pending
}
