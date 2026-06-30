import Foundation

struct GhostProducedDocument: Codable, Identifiable, Equatable, Sendable {
    var id: String { path }
    let title: String
    let path: String
    let kind: String
    let createdAt: Date
    let verified: Bool

    var displayPath: String {
        let home = NSHomeDirectory()
        guard path.hasPrefix(home) else { return path }
        return "~" + String(path.dropFirst(home.count))
    }
}

struct GhostPresenceState: Equatable, Sendable {
    enum Mode: String, Sendable {
        case ready
        case planning
        case reading
        case working
        case verifying
        case waiting
        case done
        case blocked
    }

    let mode: Mode
    let title: String
    let detail: String
    let systemImage: String
}
