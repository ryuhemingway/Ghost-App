import Foundation

struct GhostTaskContext: Equatable, Sendable {
    var kind: GhostIntentKind
    var originalPrompt: String
    var lastOutputTheme: String?
    var fileExtension: String?
    var destination: String?
    var route: ExecutionEngine
    var createdAt: Date

    var isArtifactTask: Bool {
        kind == .createArtifact || kind == .coding
    }

    var isFresh: Bool {
        Date().timeIntervalSince(createdAt) < 20 * 60
    }
}
