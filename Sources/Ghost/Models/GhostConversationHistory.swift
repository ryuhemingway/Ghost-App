import Foundation

struct PersistedMessage: Codable, Equatable, Identifiable {
    var id: UUID
    var role: String
    var text: String
    var date: Date
    var providerTitle: String?
    var model: String?
    var effortTitle: String?
    var approvalMode: String?

    init(from message: GhostMessage) {
        self.id = message.id
        self.role = message.role.rawValue
        self.text = message.text
        self.date = message.date
        if let meta = message.runMetadata {
            self.providerTitle = meta.providerTitle
            self.model = meta.model
            self.effortTitle = meta.effortTitle
            self.approvalMode = meta.approvalMode
        } else {
            self.providerTitle = nil
            self.model = nil
            self.effortTitle = nil
            self.approvalMode = nil
        }
    }

    init(id: UUID, role: String, text: String, date: Date, providerTitle: String?, model: String?, effortTitle: String?, approvalMode: String?) {
        self.id = id
        self.role = role
        self.text = text
        self.date = date
        self.providerTitle = providerTitle
        self.model = model
        self.effortTitle = effortTitle
        self.approvalMode = approvalMode
    }
}

struct PersistedConversation: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [PersistedMessage]

    static func == (lhs: PersistedConversation, rhs: PersistedConversation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension PersistedMessage {
    var ghostRole: GhostMessage.Role {
        GhostMessage.Role(rawValue: role) ?? .system
    }

    func toGhostMessage() -> GhostMessage {
        let metadata: GhostRunMetadata? = providerTitle.map {
            GhostRunMetadata(
                providerTitle: $0,
                providerRawValue: "",
                model: model ?? "",
                effortTitle: effortTitle ?? "",
                effortRawValue: "",
                reasoningEffort: "",
                maxTurns: 0,
                maxTokens: 0,
                approvalMode: approvalMode ?? "",
                startedAt: date,
                finishedAt: nil,
                workingDirectory: "",
                launchedArguments: []
            )
        }
        return GhostMessage(role: ghostRole, text: text, date: date, runMetadata: metadata)
    }
}

extension PersistedConversation {
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "New conversation"
        }
        return trimmed
    }

    var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: updatedAt)
    }
}