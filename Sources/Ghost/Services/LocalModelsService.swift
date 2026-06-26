import Foundation

struct LocalModelsService: Sendable {
    var lmStudioBaseURL = URL(string: "http://localhost:1234/v1")!

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
}

enum LocalModelsError: LocalizedError {
    case invalidURL
    case requestFailed(String, Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The local model server URL is invalid."
        case .requestFailed(let provider, let status):
            "\(provider) returned HTTP \(status)."
        }
    }
}
