import Foundation

/// Calls a provider's HTTP API directly using the user's saved key, bypassing
/// the local `ghost` CLI. This is the fast path for users who do not have the
/// Ghost agent installed.
struct DirectAPIClient: Sendable {
    private let webSearchService = DirectWebSearchService()

    /// - Parameter apiKey: the resolved provider key (from `~/.ghost/.env`).
    ///   May be empty for LM Studio, which needs none.
    func send(
        _ prompt: String,
        settings: GhostRunSettings,
        apiKey: String,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)? = nil,
        onToken: (@Sendable (String) async -> Void)? = nil
    ) async throws -> GhostRunResult {
        onActivity?(
            GhostActivityEntry(
                kind: .command,
                title: "Calling \(settings.provider.title) API",
                detail: "\(settings.model) · max_tokens \(settings.effortMode.maxTokens)"
            )
        )
        onActivity?(
            GhostActivityEntry(
                kind: .info,
                title: "Direct API fast path",
                detail: "Using provider HTTP API directly. Search prompts get lightweight web context; computer actions still require Ghost Agent mode."
            )
        )

        let preparedPrompt = await promptWithOptionalWebSearch(prompt, onActivity: onActivity)
        let shouldStream = onToken != nil && supportsStreaming(settings.provider)
        let request = try buildRequest(
            prompt: preparedPrompt,
            settings: settings,
            apiKey: apiKey,
            stream: shouldStream
        )

        if shouldStream, let onToken {
            return try await sendStreaming(
                request,
                settings: settings,
                onActivity: onActivity,
                onToken: onToken
            )
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            onActivity?(
                GhostActivityEntry(kind: .error, title: "Request failed", detail: error.localizedDescription)
            )
            throw GhostClientError.launchFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GhostClientError.commandFailed("No HTTP response from \(settings.provider.title).")
        }

        let bodyText = String(data: data, encoding: .utf8) ?? ""

        guard (200..<300).contains(http.statusCode) else {
            let detail = extractAPIErrorMessage(from: data) ?? bodyText
            onActivity?(
                GhostActivityEntry(
                    kind: .error,
                    title: "\(settings.provider.title) HTTP \(http.statusCode)",
                    detail: detail
                )
            )
            throw GhostClientError.commandFailed(
                "\(settings.provider.title) returned HTTP \(http.statusCode): \(detail)"
            )
        }

        guard let text = extractText(from: data, provider: settings.provider), !text.isEmpty else {
            throw GhostClientError.emptyResponse
        }

        onActivity?(
            GhostActivityEntry(kind: .success, title: "API call finished", detail: "HTTP \(http.statusCode)")
        )

        return GhostRunResult(
            output: text.trimmingCharacters(in: .whitespacesAndNewlines),
            launchedArguments: ["direct-api", settings.provider.ghostProvider, settings.model],
            provider: settings.provider,
            model: settings.model,
            effortMode: settings.effortMode,
            maxTurns: 1,
            maxTokens: settings.effortMode.maxTokens,
            reasoningEffort: settings.effortMode.ghostReasoningEffort,
            workingDirectory: settings.workingDirectory.path,
            exitStatus: 0
        )
    }

    private func sendStreaming(
        _ request: URLRequest,
        settings: GhostRunSettings,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?,
        onToken: @escaping @Sendable (String) async -> Void
    ) async throws -> GhostRunResult {
        let bytes: URLSession.AsyncBytes
        let response: URLResponse

        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            onActivity?(
                GhostActivityEntry(kind: .error, title: "Stream failed", detail: error.localizedDescription)
            )
            throw GhostClientError.launchFailed(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GhostClientError.commandFailed("No HTTP response from \(settings.provider.title).")
        }

        guard (200..<300).contains(http.statusCode) else {
            var body = ""
            for try await line in bytes.lines {
                body += line
            }
            onActivity?(
                GhostActivityEntry(
                    kind: .error,
                    title: "\(settings.provider.title) HTTP \(http.statusCode)",
                    detail: body
                )
            )
            throw GhostClientError.commandFailed(
                "\(settings.provider.title) returned HTTP \(http.statusCode): \(body)"
            )
        }

        onActivity?(
            GhostActivityEntry(kind: .info, title: "Streaming response", detail: settings.provider.title)
        )

        var streamedText = ""
        for try await rawLine in bytes.lines {
            if Task.isCancelled {
                throw CancellationError()
            }

            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("data:") else { continue }

            let payload = line
                .dropFirst(5)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { break }

            guard let token = streamToken(from: payload, provider: settings.provider), !token.isEmpty else {
                continue
            }

            streamedText += token
            await onToken(token)
        }

        let output = streamedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            throw GhostClientError.emptyResponse
        }

        onActivity?(
            GhostActivityEntry(kind: .success, title: "API stream finished", detail: "HTTP \(http.statusCode)")
        )

        return GhostRunResult(
            output: output,
            launchedArguments: ["direct-api-stream", settings.provider.ghostProvider, settings.model],
            provider: settings.provider,
            model: settings.model,
            effortMode: settings.effortMode,
            maxTurns: 1,
            maxTokens: settings.effortMode.maxTokens,
            reasoningEffort: settings.effortMode.ghostReasoningEffort,
            workingDirectory: settings.workingDirectory.path,
            exitStatus: 0
        )
    }

    private func promptWithOptionalWebSearch(
        _ prompt: String,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) async -> String {
        guard shouldUseWebSearch(for: prompt) else {
            return prompt
        }

        let query = webSearchQuery(from: prompt)
        guard !query.isEmpty else {
            return prompt
        }

        onActivity?(
            GhostActivityEntry(kind: .command, title: "Searching the web", detail: query)
        )

        do {
            let results = try await webSearchService.search(query: query)
            guard !results.isEmpty else {
                onActivity?(
                    GhostActivityEntry(kind: .info, title: "Web search", detail: "No results found.")
                )
                return prompt
            }

            onActivity?(
                GhostActivityEntry(kind: .success, title: "Web search finished", detail: "\(results.count) results")
            )

            return """
            \(prompt)

            Current web search results for "\(query)":
            \(formatSearchResults(results))

            Answer using the search results as source material. Prefer specific facts, dates, locations, numbers, and named sources. Cite sources inline as [1], [2], etc. If sources conflict, say so plainly.
            """
        } catch {
            onActivity?(
                GhostActivityEntry(kind: .error, title: "Web search failed", detail: error.localizedDescription)
            )
            return prompt
        }
    }

    private func shouldUseWebSearch(for prompt: String) -> Bool {
        let text = prompt.lowercased()
        let cues = [
            "today", "current", "currently", "latest", "live", "recent",
            "news", "search", "look up", "find out", "right now",
            "earthquake", "weather", "stock", "price", "happened"
        ]
        return cues.contains { text.contains($0) }
    }

    private func webSearchQuery(from prompt: String) -> String {
        var query = prompt
        if let range = query.range(of: "User request:") {
            query = String(query[range.upperBound...])
        }
        if let range = query.range(of: "Context from clipboard:") {
            query = String(query[..<range.lowerBound])
        }
        query = query
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if isVagueFollowUp(query), let topic = recentTopic(from: prompt) {
            query = "\(topic) \(query)"
        }
        return String(query.prefix(180))
    }

    private func isVagueFollowUp(_ query: String) -> Bool {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let vaguePhrases = [
            "give me the full rundown",
            "full rundown",
            "tell me more",
            "more details",
            "what else",
            "continue",
            "go deeper",
            "explain more"
        ]
        return normalized.count < 80 && vaguePhrases.contains { normalized.contains($0) }
    }

    private func recentTopic(from prompt: String) -> String? {
        guard let contextRange = prompt.range(of: "Recent conversation:") else {
            return nil
        }

        let contextEnd = prompt.range(of: "User request:")?.lowerBound ?? prompt.endIndex
        let context = String(prompt[contextRange.upperBound..<contextEnd])
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !context.isEmpty else {
            return nil
        }

        let words = context.split(separator: " ").suffix(45).joined(separator: " ")
        return words.isEmpty ? nil : words
    }

    private func formatSearchResults(_ results: [DirectWebSearchResult]) -> String {
        results.enumerated().map { index, result in
            let extract = result.pageText.map { "\nExtract: \($0)" } ?? ""
            return """
            [\(index + 1)] \(result.title)
            URL: \(result.url)
            Snippet: \(result.snippet)\(extract)
            """
        }
        .joined(separator: "\n\n")
    }

    // MARK: - Request building

    private func buildRequest(
        prompt: String,
        settings: GhostRunSettings,
        apiKey: String,
        stream: Bool = false
    ) throws -> URLRequest {
        switch settings.provider {
        case .claude:
            return try anthropicRequest(prompt: prompt, settings: settings, apiKey: apiKey, stream: stream)
        case .gemini:
            return try geminiRequest(prompt: prompt, settings: settings, apiKey: apiKey)
        case .deepSeek:
            return try openAICompatibleRequest(
                prompt: prompt,
                settings: settings,
                apiKey: apiKey,
                endpoint: URL(string: "https://api.deepseek.com/v1/chat/completions")!,
                requiresKey: true,
                stream: stream
            )
        case .lmStudio:
            return try openAICompatibleRequest(
                prompt: prompt,
                settings: settings,
                apiKey: apiKey,
                endpoint: URL(string: "http://localhost:1234/v1/chat/completions")!,
                requiresKey: false,
                stream: stream
            )
        case .ollama:
            let base = settings.ollamaBaseURL.absoluteString
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            guard let endpoint = URL(string: "\(base)/v1/chat/completions") else {
                throw GhostClientError.commandFailed("Could not build Ollama request URL.")
            }

            return try openAICompatibleRequest(
                prompt: prompt,
                settings: settings,
                apiKey: "",
                endpoint: endpoint,
                requiresKey: false,
                stream: stream
            )
        }
    }

    private func anthropicRequest(
        prompt: String,
        settings: GhostRunSettings,
        apiKey: String,
        stream: Bool
    ) throws -> URLRequest {
        try requireKey(apiKey, provider: settings.provider)
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        var body: [String: Any] = [
            "model": settings.model,
            "max_tokens": settings.effortMode.maxTokens,
            "messages": [["role": "user", "content": prompt]]
        ]
        if stream {
            body["stream"] = true
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func geminiRequest(prompt: String, settings: GhostRunSettings, apiKey: String) throws -> URLRequest {
        try requireKey(apiKey, provider: settings.provider)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(settings.model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GhostClientError.commandFailed("Could not build Gemini request URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["maxOutputTokens": settings.effortMode.maxTokens]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func openAICompatibleRequest(
        prompt: String,
        settings: GhostRunSettings,
        apiKey: String,
        endpoint: URL,
        requiresKey: Bool,
        stream: Bool
    ) throws -> URLRequest {
        if requiresKey {
            try requireKey(apiKey, provider: settings.provider)
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        var body: [String: Any] = [
            "model": settings.model,
            "max_tokens": settings.effortMode.maxTokens,
            "messages": [["role": "user", "content": prompt]]
        ]
        if stream {
            body["stream"] = true
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func supportsStreaming(_ provider: GhostProvider) -> Bool {
        switch provider {
        case .claude, .deepSeek, .lmStudio, .ollama:
            true
        case .gemini:
            false
        }
    }

    private func requireKey(_ apiKey: String, provider: GhostProvider) throws {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GhostClientError.commandFailed(
                "No saved API key for \(provider.title). Add one in Settings > API Keys, or switch to Ghost Agent."
            )
        }
    }

    // MARK: - Response parsing

    private func extractText(from data: Data, provider: GhostProvider) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        switch provider {
        case .claude:
            guard let content = json["content"] as? [[String: Any]] else { return nil }
            let parts = content.compactMap { $0["text"] as? String }
            return parts.isEmpty ? nil : parts.joined()
        case .gemini:
            guard
                let candidates = json["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            else { return nil }
            let texts = parts.compactMap { $0["text"] as? String }
            return texts.isEmpty ? nil : texts.joined()
        case .deepSeek, .lmStudio, .ollama:
            guard
                let choices = json["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return nil }
            return content
        }
    }

    private func extractAPIErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            return message
        }
        return nil
    }

    private func streamToken(from payload: String, provider: GhostProvider) -> String? {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        switch provider {
        case .claude:
            guard json["type"] as? String == "content_block_delta",
                  let delta = json["delta"] as? [String: Any]
            else {
                return nil
            }
            return delta["text"] as? String

        case .deepSeek, .lmStudio, .ollama:
            guard let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first
            else {
                return nil
            }
            if let delta = first["delta"] as? [String: Any] {
                return delta["content"] as? String
            }
            if let message = first["message"] as? [String: Any] {
                return message["content"] as? String
            }
            return nil

        case .gemini:
            return nil
        }
    }
}
