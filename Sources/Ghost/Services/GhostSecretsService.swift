import Foundation

struct GhostSecretsService: Sendable {
    private var envURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".ghost/.env")
    }

    func hasValue(for key: ProviderAPIKey) -> Bool {
        read(for: key) != nil
    }

    func read(for key: ProviderAPIKey) -> String? {
        readEnvironmentValue(key.environmentKey)
    }

    func save(_ value: String, for key: ProviderAPIKey) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try setEnvironmentValue(key.environmentKey, value: trimmed)
    }

    func clear(_ key: ProviderAPIKey) throws {
        try removeEnvironmentValue(key.environmentKey)
    }

    private func readEnvironmentValue(_ name: String) -> String? {
        guard let text = try? String(contentsOf: envURL, encoding: .utf8) else {
            return ProcessInfo.processInfo.environment[name]
        }

        let prefix = "\(name)="

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(prefix), !trimmed.hasPrefix("#") else { continue }

            var value = String(trimmed.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespaces)

            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }

            value = value
                .replacingOccurrences(of: #"\""#, with: #"""#)
                .replacingOccurrences(of: #"\\n"#, with: "\n")

            return value.isEmpty ? nil : value
        }

        return ProcessInfo.processInfo.environment[name]
    }

    private func setEnvironmentValue(_ name: String, value: String) throws {
        try FileManager.default.createDirectory(
            at: envURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let existing = (try? String(contentsOf: envURL, encoding: .utf8)) ?? ""
        let filtered = existing
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.hasPrefix("\(name)=")
            }
            .map(String.init)

        let escaped = value
            .replacingOccurrences(of: #"\"#, with: #"\\"#)
            .replacingOccurrences(of: #"""#, with: #"\""#)

        let next = (filtered + ["\(name)=\"\(escaped)\""])
            .joined(separator: "\n")

        try next.write(to: envURL, atomically: true, encoding: .utf8)
    }

    private func removeEnvironmentValue(_ name: String) throws {
        let existing = (try? String(contentsOf: envURL, encoding: .utf8)) ?? ""
        let filtered = existing
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.hasPrefix("\(name)=")
            }
            .map(String.init)

        try filtered.joined(separator: "\n")
            .write(to: envURL, atomically: true, encoding: .utf8)
    }
}

enum GhostSecretsError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let key):
            "Could not save \(key) to Ghost environment."
        }
    }
}
