import Foundation

struct LocalModel: Identifiable, Decodable, Equatable {
    let id: String
    let ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownedBy = "owned_by"
    }
}

struct LocalModelsResponse: Decodable {
    let data: [LocalModel]
}

struct OllamaTagsResponse: Decodable {
    let models: [OllamaTagModel]
}

struct OllamaTagModel: Decodable {
    let name: String
    let model: String?

    var localModel: LocalModel {
        LocalModel(id: model ?? name, ownedBy: "ollama")
    }
}
