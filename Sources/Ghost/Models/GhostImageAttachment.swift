import Foundation

struct GhostImageAttachment: Equatable, Sendable {
    let data: Data
    let mimeType: String
    let filename: String
    let createdAt: Date

    var base64String: String {
        data.base64EncodedString()
    }

    var dataURLString: String {
        "data:\(mimeType);base64,\(base64String)"
    }

    var sizeDescription: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(data.count))
    }
}
