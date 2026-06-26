import Foundation

enum GhostRunStatus: String, Sendable, Equatable {
    case idle
    case running
    case completed
    case failed
    case stopped
}

struct GhostTelemetrySnapshot: Equatable, Sendable {
    var status: GhostRunStatus
    var providerTitle: String
    var model: String
    var effortTitle: String
    var approvalMode: String
    var workingDirectory: String
    var activeRunStartedAt: Date?
    var lastRunStartedAt: Date?
    var lastRunFinishedAt: Date?
    var lastRunDuration: TimeInterval?
    var exitStatus: Int32?
    var estimatedPromptTokens: Int
    var estimatedResponseTokens: Int
    var activityEventCount: Int
    var queuedTaskCount: Int
    var includeClipboard: Bool
    var isDictating: Bool
    var processIdentifier: Int32?

    static let idleSnapshot = GhostTelemetrySnapshot(
        status: .idle,
        providerTitle: "—",
        model: "—",
        effortTitle: "—",
        approvalMode: "—",
        workingDirectory: "—",
        estimatedPromptTokens: 0,
        estimatedResponseTokens: 0,
        activityEventCount: 0,
        queuedTaskCount: 0,
        includeClipboard: false,
        isDictating: false
    )

    var formattedElapsed: String {
        guard let startedAt = activeRunStartedAt else { return "—" }
        let interval = Date().timeIntervalSince(startedAt)
        return GhostTelemetrySnapshot.formatDuration(interval)
    }

    var formattedLastDuration: String {
        guard let duration = lastRunDuration else { return "—" }
        return GhostTelemetrySnapshot.formatDuration(duration)
    }

    static func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

enum TelemetryTokenEstimator {
    static func estimateTokens(characterCount: Int) -> Int {
        max(1, characterCount / 4)
    }

    static func estimateTokens(text: String) -> Int {
        estimateTokens(characterCount: text.count)
    }
}
