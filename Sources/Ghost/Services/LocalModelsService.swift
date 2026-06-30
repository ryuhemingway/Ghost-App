import Foundation

struct LocalModelsService: Sendable {
    var lmStudioBaseURL = URL(string: "http://localhost:1234/v1")!
    var openCodeGoBaseURL = URL(string: "https://opencode.ai/zen/go/v1")!

    func fetchModels() async throws -> [LocalModel] {
        try await fetchLMStudioModels()
    }

    func fetchLMStudioModels() async throws -> [LocalModel] {
        let url = lmStudioBaseURL.appendingPathComponent("models")
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw LocalModelsError.requestFailed("LM Studio", httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(LocalModelsResponse.self, from: data)
        return decoded.data
            .filter { !$0.id.localizedCaseInsensitiveContains("embedding") && !$0.id.localizedCaseInsensitiveContains("embed") }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    func fetchOllamaModels(baseURL: URL) async throws -> [LocalModel] {
        let cleanBase = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)/api/tags") else {
            throw LocalModelsError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw LocalModelsError.requestFailed("Ollama", httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return decoded.models
            .map(\.localModel)
            .filter { !$0.id.localizedCaseInsensitiveContains("embedding") && !$0.id.localizedCaseInsensitiveContains("embed") }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }

    func fetchOpenCodeGoModels(apiKey: String) async throws -> [LocalModel] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw LocalModelsError.missingAPIKey("OpenCode Go")
        }

        let url = openCodeGoBaseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw LocalModelsError.requestFailed("OpenCode Go", httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(LocalModelsResponse.self, from: data)
        return decoded.data
            .filter { !$0.id.localizedCaseInsensitiveContains("embedding") && !$0.id.localizedCaseInsensitiveContains("embed") }
            .sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
    }
}

enum LocalModelsError: LocalizedError {
    case invalidURL
    case requestFailed(String, Int)
    case missingAPIKey(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The local model server URL is invalid."
        case .requestFailed(let provider, let status):
            "\(provider) returned HTTP \(status)."
        case .missingAPIKey(let provider):
            "No saved API key for \(provider). Add one under API Keys, then refresh models."
        }
    }
}
