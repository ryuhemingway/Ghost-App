import Foundation

enum GhostTaskStepState: String, Sendable {
    case pending
    case running
    case completed
    case failed

    var systemImage: String {
        switch self {
        case .pending:
            return "square"
        case .running:
            return "arrow.right.square"
        case .completed:
            return "checkmark.square.fill"
        case .failed:
            return "xmark.square.fill"
        }
    }

    var todoPrefix: String {
        switch self {
        case .pending:
            return "[ ]"
        case .running:
            return "[~]"
        case .completed:
            return "[x]"
        case .failed:
            return "[!]"
        }
    }
}

struct GhostTaskStep: Identifiable, Equatable, Sendable {
    let id: UUID
    var todoID: String?
    var title: String
    var detail: String
    var state: GhostTaskStepState

    init(
        id: UUID = UUID(),
        todoID: String? = nil,
        title: String,
        detail: String = "",
        state: GhostTaskStepState = .pending
    ) {
        self.id = id
        self.todoID = todoID
        self.title = title
        self.detail = detail
        self.state = state
    }
}

struct GhostPendingPlanItem: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
}

struct GhostTaskTimeline: Equatable, Sendable {
    var title: String
    var subtitle: String
    var route: String
    var steps: [GhostTaskStep]
    var summary: String?
    var error: String?
    var startedAt: Date?
    var finishedAt: Date?
    var lastUpdatedAt: Date
    var isVisible: Bool

    var isWaitingForGhostPlan: Bool
    var isUsingGhostPlan: Bool
    var pendingGhostPlanItems: [GhostPendingPlanItem]

    static let idle = GhostTaskTimeline(
        title: "",
        subtitle: "",
        route: "",
        steps: [],
        summary: nil,
        error: nil,
        startedAt: nil,
        finishedAt: nil,
        lastUpdatedAt: Date.distantPast,
        isVisible: false,
        isWaitingForGhostPlan: false,
        isUsingGhostPlan: false,
        pendingGhostPlanItems: []
    )

    var completedCount: Int {
        steps.filter { $0.state == .completed }.count
    }

    var totalCount: Int {
        steps.count
    }

    var activeStep: GhostTaskStep? {
        steps.first { $0.state == .running }
    }

    var isFinished: Bool {
        finishedAt != nil
    }

    var progressText: String {
        if isWaitingForGhostPlan && totalCount == 0 {
            return "planning"
        }

        guard totalCount > 0 else {
            return "waiting"
        }

        return "\(completedCount)/\(totalCount)"
    }

    var progressFraction: Double {
        guard totalCount > 0 else {
            return isFinished ? 1 : 0
        }

        return Double(completedCount) / Double(totalCount)
    }

    var currentLine: String {
        if let error {
            return error
        }

        if let summary, isFinished {
            return summary
        }

        if let activeStep {
            return activeStep.title
        }

        if isWaitingForGhostPlan {
            return "Creating todo plan"
        }

        if let next = steps.first(where: { $0.state == .pending }) {
            return next.title
        }

        return "Finishing up"
    }
}

enum GhostOrbState: String, Sendable {
    case idle
    case thinking
    case usingTools
    case writingFile
    case success
    case error
}
