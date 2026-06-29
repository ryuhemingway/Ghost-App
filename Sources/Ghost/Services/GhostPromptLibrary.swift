import Foundation

struct SavedPrompt: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, body: String, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}

@MainActor
final class GhostPromptLibrary {
    private static let storageKey = "ghost.promptLibrary.v1"
    private let defaults: UserDefaults
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [SavedPrompt] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let prompts = try? decoder.decode([SavedPrompt].self, from: data) else {
            return Self.defaultPrompts
        }
        return prompts
    }

    func save(_ prompts: [SavedPrompt]) {
        guard let data = try? encoder.encode(prompts) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    func add(title: String, body: String) -> [SavedPrompt] {
        var prompts = load()
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = SavedPrompt(title: trimmedTitle.isEmpty ? body.prefix(32).description : trimmedTitle, body: body)
        prompts.insert(prompt, at: 0)
        save(prompts)
        return prompts
    }

    func remove(id: UUID) -> [SavedPrompt] {
        var prompts = load()
        prompts.removeAll { $0.id == id }
        save(prompts)
        return prompts
    }

    static let defaultPrompts: [SavedPrompt] = [
        SavedPrompt(title: "Summarize a document", body: "Summarize the following document in 5 concise bullet points, then give me a one-sentence takeaway."),
        SavedPrompt(title: "Explain like I'm new", body: "Explain this concept like I'm new to it. Use a short analogy, then a clear technical explanation."),
        SavedPrompt(title: "Draft a reply", body: "Draft a polite, concise reply to the message below. Keep it professional and under 120 words."),
        SavedPrompt(title: "Refactor this code", body: "Refactor this code for readability and performance. Explain each change briefly."),
        SavedPrompt(title: "Plan my day", body: "Look at my upcoming calendar events and draft a focused plan for today with time blocks.")
    ]
}