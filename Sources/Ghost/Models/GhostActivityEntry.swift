import Foundation

struct GhostActivityEntry: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case info
        case command
        case output
        case error
        case success
    }

    let id = UUID()
    let date: Date
    let kind: Kind
    let title: String
    let detail: String

    init(kind: Kind, title: String, detail: String = "", date: Date = .now) {
        self.date = date
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}
