import Foundation

struct GhostRunMetadata: Equatable, Sendable {
    let providerTitle: String
    let providerRawValue: String
    let model: String
    let effortTitle: String
    let effortRawValue: String
    let reasoningEffort: String
    let maxTurns: Int
    let maxTokens: Int
    let approvalMode: String
    let startedAt: Date
    let finishedAt: Date?
    let workingDirectory: String
    let launchedArguments: [String]

    var summaryLine: String {
        "\(providerTitle) · \(model) · \(effortTitle) · \(approvalMode)"
    }
}

struct GhostMessage: Identifiable, Equatable {
    enum Role: String {
        case user = "You"
        case ghost = "Ghost"
        case system = "Status"
    }

    let id = UUID()
    let role: Role
    var text: String
    let date: Date
    var runMetadata: GhostRunMetadata?

    init(role: Role, text: String, date: Date = .now, runMetadata: GhostRunMetadata? = nil) {
        self.role = role
        self.text = text
        self.date = date
        self.runMetadata = runMetadata
    }
}
