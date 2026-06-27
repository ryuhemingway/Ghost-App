import Foundation

/// Probes an OpenAI-compatible local model endpoint (LM Studio/Ollama-compatible)
/// and classifies how Ghost should use it. This lets Ghost keep the same tool
/// harness for every model while changing how much the model is trusted to emit
/// native tool calls.
struct GhostLocalModelCapabilityProbe: Sendable {
    struct Report: Codable, Sendable {
        var providerTitle: String
        var model: String
        var endpoint: String
        var basicChat: Bool = false
        var jsonMode: Bool = false
        var nativeToolCalls: Bool = false
        var functionArgumentAccuracy: Bool = false
        var recommendedMode: RecommendedMode = .answerOnly
        var warnings: [String] = []

        enum RecommendedMode: String, Codable, Sendable {
            case nativeToolCalls = "native_tool_calls"
            case jsonActionMode = "json_action_mode"
            case harnessFirst = "harness_first"
            case answerOnly = "answer_only"
        }

        var summary: String {
            """
            Model: \(model)
            Chat: \(basicChat ? "supported" : "failed")
            JSON: \(jsonMode ? "supported" : "unreliable")
            Tool calls: \(nativeToolCalls ? "supported" : "unreliable/unsupported")
            Function arguments: \(functionArgumentAccuracy ? "accurate" : "unverified")
            Recommended mode: \(recommendedMode.rawValue)
            """
        }
    }

    func probe(model: String, endpoint: URL, apiKey: String = "", providerTitle: String = "Local Model") async -> Report {
        var report = Report(providerTitle: providerTitle, model: model, endpoint: endpoint.absoluteString)

        report.basicChat = await probeBasicChat(model: model, endpoint: endpoint, apiKey: apiKey)
        report.jsonMode = await probeJSONMode(model: model, endpoint: endpoint, apiKey: apiKey)
        let toolResult = await probeNativeToolCalls(model: model, endpoint: endpoint, apiKey: apiKey)
        report.nativeToolCalls = toolResult.native
        report.functionArgumentAccuracy = toolResult.argumentsAccurate

        if report.nativeToolCalls && report.functionArgumentAccuracy {
            report.recommendedMode = .nativeToolCalls
        } else if report.jsonMode {
            report.recommendedMode = .jsonActionMode
            report.warnings.append("Model did not reliably emit OpenAI tool_calls. Use JSON action mode plus Ghost verification.")
        } else if report.basicChat {
            report.recommendedMode = .harnessFirst
            report.warnings.append("Model can chat but should not be trusted to decide or claim tool execution.")
        } else {
            report.recommendedMode = .answerOnly
            report.warnings.append("Model did not pass a basic chat probe.")
        }

        return report
    }

    private func probeBasicChat(model: String, endpoint: URL, apiKey: String) async -> Bool {
        let messages: [[String: Any]] = [
            ["role": "system", "content": "Reply with exactly: ghost-ok"],
            ["role": "user", "content": "ping"]
        ]
        guard let text = await send(model: model, endpoint: endpoint, apiKey: apiKey, messages: messages) else { return false }
        return text.lowercased().contains("ghost-ok")
    }

    private func probeJSONMode(model: String, endpoint: URL, apiKey: String) async -> Bool {
        let messages: [[String: Any]] = [
            ["role": "system", "content": "Return only compact JSON. No markdown."],
            ["role": "user", "content": "Return {\"ghost_probe\":true,\"n\":7} exactly as JSON."]
        ]
        guard let text = await send(model: model, endpoint: endpoint, apiKey: apiKey, messages: messages) else { return false }
        guard let data = GhostJSONActionExtractor.extractFirstJSONObject(from: text) else { return false }
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object?["ghost_probe"] as? Bool == true && (object?["n"] as? Int == 7 || object?["n"] as? Double == 7)
    }

    private func probeNativeToolCalls(model: String, endpoint: URL, apiKey: String) async -> (native: Bool, argumentsAccurate: Bool) {
        let tool: [String: Any] = [
            "type": "function",
            "function": [
                "name": "ghost_probe_echo",
                "description": "Echo probe arguments.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "message": ["type": "string"],
                        "number": ["type": "integer"]
                    ],
                    "required": ["message", "number"]
                ]
            ]
        ]
        let messages: [[String: Any]] = [
            ["role": "system", "content": "Call the provided tool. Do not answer in text."],
            ["role": "user", "content": "Call ghost_probe_echo with message='hello-ghost' and number=42."]
        ]
        guard let data = await sendRaw(model: model, endpoint: endpoint, apiKey: apiKey, messages: messages, tools: [tool]) else {
            return (false, false)
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let calls = message["tool_calls"] as? [[String: Any]],
              let first = calls.first,
              let function = first["function"] as? [String: Any],
              function["name"] as? String == "ghost_probe_echo" else {
            return (false, false)
        }
        let argumentText = function["arguments"] as? String ?? ""
        guard let argumentData = argumentText.data(using: .utf8),
              let arguments = try? JSONSerialization.jsonObject(with: argumentData) as? [String: Any] else {
            return (true, false)
        }
        let accurate = arguments["message"] as? String == "hello-ghost"
            && ((arguments["number"] as? Int) == 42 || (arguments["number"] as? Double) == 42)
        return (true, accurate)
    }

    private func send(model: String, endpoint: URL, apiKey: String, messages: [[String: Any]]) async -> String? {
        guard let data = await sendRaw(model: model, endpoint: endpoint, apiKey: apiKey, messages: messages, tools: nil) else { return nil }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else { return nil }
        return message["content"] as? String
    }

    private func sendRaw(model: String, endpoint: URL, apiKey: String, messages: [[String: Any]], tools: [[String: Any]]?) async -> Data? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }

        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0,
            "max_tokens": 200
        ]
        if let tools {
            body["tools"] = tools
            body["tool_choice"] = "auto"
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return data
        } catch {
            return nil
        }
    }
}
