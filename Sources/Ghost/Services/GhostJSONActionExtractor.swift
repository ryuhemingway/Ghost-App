import Foundation

/// Fallback for local models that cannot emit native OpenAI tool_calls but can
/// produce JSON. Ghost parses the action, executes it through the harness, then
/// verifies the result. This is safer than trusting prose like "I saved it".
struct GhostJSONActionExtractor {
    struct Action {
        let name: String
        let arguments: [String: Any]
    }

    static func extractAction(from text: String) -> Action? {
        guard let data = extractFirstJSONObject(from: text),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let actionName = (object["action"] as? String)
            ?? (object["tool"] as? String)
            ?? (object["name"] as? String)
        guard let actionName, !actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let arguments = (object["arguments"] as? [String: Any])
            ?? (object["args"] as? [String: Any])
            ?? object.filter { !["action", "tool", "name"].contains($0.key) }
        return Action(name: actionName, arguments: arguments)
    }

    static func extractFirstJSONObject(from text: String) -> Data? {
        let scalars = Array(text.unicodeScalars)
        guard let start = scalars.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false

        for index in start..<scalars.count {
            let scalar = scalars[index]
            if inString {
                if escaped {
                    escaped = false
                } else if scalar == "\\" {
                    escaped = true
                } else if scalar == "\"" {
                    inString = false
                }
                continue
            }

            if scalar == "\"" {
                inString = true
            } else if scalar == "{" {
                depth += 1
            } else if scalar == "}" {
                depth -= 1
                if depth == 0 {
                    let slice = String(String.UnicodeScalarView(scalars[start...index]))
                    return slice.data(using: .utf8)
                }
            }
        }
        return nil
    }
}
