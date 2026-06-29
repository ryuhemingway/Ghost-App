import Foundation

@MainActor
final class GhostHistoryStore {
    private let fileManager = FileManager.default
    private let directoryURL: URL

    init(directoryName: String = "Ghost/history") {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        self.directoryURL = support.appendingPathComponent(directoryName, isDirectory: true)
    }

    private func ensureDirectory() {
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func fileURL(for id: UUID) -> URL {
        directoryURL.appendingPathComponent("\(id.uuidString).json")
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func listConversations() -> [PersistedConversation] {
        ensureDirectory()
        guard let urls = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
            return []
        }
        var conversations: [PersistedConversation] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let conversation = try? decoder.decode(PersistedConversation.self, from: data) else {
                continue
            }
            conversations.append(conversation)
        }
        return conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(_ conversation: PersistedConversation) {
        ensureDirectory()
        guard let data = try? encoder.encode(conversation) else { return }
        try? data.write(to: fileURL(for: conversation.id), options: .atomic)
    }

    func delete(id: UUID) {
        try? fileManager.removeItem(at: fileURL(for: id))
    }

    func deleteAll() {
        guard let urls = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else {
            return
        }
        for url in urls where url.pathExtension == "json" {
            try? fileManager.removeItem(at: url)
        }
    }
}