import Foundation

/// Calls a provider's HTTP API directly using the user's saved key, bypassing
/// the local `ghost` CLI. This is the fast path for users who do not have the
/// Ghost agent installed.
struct DirectAPIClient: Sendable {
    private let webSearchService = DirectWebSearchService()
    private let reminderService = NativeReminderService()
    private let calendarService = NativeCalendarService()
    private let capabilityHarness = GhostCapabilityHarness()
    private let ragStore = GhostRAGStore()

    private struct OpenAIToolCall {
        let id: String
        let name: String
        let argumentsJSON: String
        let raw: [String: Any]
    }

    /// - Parameter apiKey: the resolved provider key (from `~/.ghost/.env`).
    ///   May be empty for LM Studio, which needs none.
    func send(
        _ prompt: String,
        imageAttachment: GhostImageAttachment? = nil,
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
                detail: directAPIDetail(for: settings.provider)
            )
        )

        if usesLocalOpenAIToolLoop(settings.provider) {
            let endpoint = try openAICompatibleEndpoint(for: settings)
            let text = try await sendOpenAICompatibleToolLoop(
                prompt: prompt,
                imageAttachment: imageAttachment,
                settings: settings,
                apiKey: apiKey,
                endpoint: endpoint,
                requiresKey: false,
                onActivity: onActivity
            )

            onActivity?(
                GhostActivityEntry(kind: .success, title: "API call finished", detail: "Local tool loop")
            )

            return GhostRunResult(
                output: text.trimmingCharacters(in: .whitespacesAndNewlines),
                launchedArguments: ["direct-api-tools", settings.provider.ghostProvider, settings.model],
                provider: settings.provider,
                model: settings.model,
                effortMode: settings.effortMode,
                maxTurns: settings.effortMode.maxTurns,
                maxTokens: settings.effortMode.maxTokens,
                reasoningEffort: settings.effortMode.ghostReasoningEffort,
                workingDirectory: settings.workingDirectory.path,
                exitStatus: 0
            )
        }

        let preparedPrompt = await promptWithOptionalWebSearch(prompt, onActivity: onActivity)
        if imageAttachment != nil, !settings.supportsVision {
            throw GhostClientError.commandFailed("\(settings.provider.title) model \(settings.model) is not marked as vision-capable. Switch to Claude, Gemini, or a local vision model to interpret pasted screenshots.")
        }

        let shouldStream = onToken != nil && supportsStreaming(settings.provider) && imageAttachment == nil
        let request = try buildRequest(
            prompt: preparedPrompt,
            imageAttachment: imageAttachment,
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

        guard let extractedText = extractText(from: data, provider: settings.provider), !extractedText.isEmpty else {
            throw GhostClientError.emptyResponse
        }

        let text = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if looksLikeUnsupportedToolProtocol(text) {
            onActivity?(
                GhostActivityEntry(
                    kind: .error,
                    title: "Unsupported model tool syntax",
                    detail: "The provider returned hidden/tool protocol text instead of a user-visible answer."
                )
            )
            throw GhostClientError.commandFailed(
                "The model returned internal tool-call protocol text instead of an answer. Try Direct API with LM Studio tool routing enabled, or switch to Ghost Agent for full tool use."
            )
        }

        onActivity?(
            GhostActivityEntry(kind: .success, title: "API call finished", detail: "HTTP \(http.statusCode)")
        )

        return GhostRunResult(
            output: text,
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

        if looksLikeUnsupportedToolProtocol(output) {
            throw GhostClientError.commandFailed(
                "The model returned unsupported internal tool-call protocol text while streaming. Disable streaming for this provider or route the task through Ghost Agent."
            )
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

    // MARK: - Local OpenAI-compatible tool loop

    private func sendOpenAICompatibleToolLoop(
        prompt: String,
        imageAttachment: GhostImageAttachment? = nil,
        settings: GhostRunSettings,
        apiKey: String,
        endpoint: URL,
        requiresKey: Bool,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) async throws -> String {
        if requiresKey {
            try requireKey(apiKey, provider: settings.provider)
        }

        onActivity?(
            GhostActivityEntry(
                kind: .info,
                title: "Local tool routing",
                detail: "LM Studio/Ollama can request Ghost tools through OpenAI-compatible tool_calls."
            )
        )

        if imageAttachment != nil, !settings.supportsVision {
            throw GhostClientError.commandFailed("\(settings.provider.title) model \(settings.model) is not marked as vision-capable. Switch to a local vision model for screenshot interpretation.")
        }

        var messages: [[String: Any]] = [
            ["role": "system", "content": localToolSystemPrompt(outputDirectory: settings.documentOutputDirectory.path, ragEnabled: settings.ragEnabled)],
            ["role": "user", "content": openAICompatibleUserContent(prompt: prompt, imageAttachment: imageAttachment)]
        ]

        var lastHTTPStatus = 0
        var lastBody = ""
        var usedToolNames = Set<String>()

        for round in 1...4 {
            let data: Data
            let response: URLResponse

            do {
                let request = try openAICompatibleToolRequest(
                    endpoint: endpoint,
                    apiKey: apiKey,
                    messages: messages,
                    settings: settings
                )
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                onActivity?(
                    GhostActivityEntry(kind: .error, title: "Local tool loop failed", detail: error.localizedDescription)
                )
                throw GhostClientError.launchFailed(error.localizedDescription)
            }

            guard let http = response as? HTTPURLResponse else {
                throw GhostClientError.commandFailed("No HTTP response from \(settings.provider.title).")
            }

            lastHTTPStatus = http.statusCode
            lastBody = String(data: data, encoding: .utf8) ?? ""

            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode == 400, round == 1 {
                    let basicRequest = try openAICompatibleBasicRequest(
                        endpoint: endpoint,
                        apiKey: apiKey,
                        messages: messages,
                        settings: settings
                    )
                    let (basicData, basicResponse) = try await URLSession.shared.data(for: basicRequest)
                    guard let basicHTTP = basicResponse as? HTTPURLResponse, (200..<300).contains(basicHTTP.statusCode),
                          let basicMessage = openAIMessage(from: basicData),
                          let content = basicMessage["content"] as? String,
                          !content.isEmpty
                    else {
                        let detail = extractAPIErrorMessage(from: data) ?? lastBody
                        throw GhostClientError.commandFailed(
                            "\(settings.provider.title) returned HTTP \(http.statusCode) during local tool routing: \(detail)"
                        )
                    }
                    return content
                }
                let detail = extractAPIErrorMessage(from: data) ?? lastBody
                throw GhostClientError.commandFailed(
                    "\(settings.provider.title) returned HTTP \(http.statusCode) during local tool routing: \(detail)"
                )
            }

            guard let message = openAIMessage(from: data) else {
                throw GhostClientError.emptyResponse
            }

            let toolCalls = openAIToolCalls(from: message)
            if !toolCalls.isEmpty {
                messages.append(assistantToolCallMessage(from: message, toolCalls: toolCalls))

                for toolCall in toolCalls {
                    usedToolNames.insert(toolCall.name)
                    onActivity?(
                        GhostActivityEntry(kind: .command, title: "Tool: \(toolCall.name)", detail: toolCall.argumentsJSON)
                    )

                    let toolResult = try await executeLocalToolCall(toolCall, settings: settings, onActivity: onActivity)
                    messages.append([
                        "role": "tool",
                        "tool_call_id": toolCall.id,
                        "name": toolCall.name,
                        "content": toolResult
                    ])
                }

                continue
            }

            if let content = message["content"] as? String {
                let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    throw GhostClientError.emptyResponse
                }

                if let jsonAction = GhostJSONActionExtractor.extractAction(from: text),
                   isSupportedJSONFallbackAction(jsonAction.name) {
                    onActivity?(
                        GhostActivityEntry(
                            kind: .info,
                            title: "JSON action fallback",
                            detail: "Executing \(jsonAction.name) through Ghost harness because the model did not emit native tool_calls."
                        )
                    )
                    let argumentData = try JSONSerialization.data(withJSONObject: jsonAction.arguments)
                    let argumentText = String(data: argumentData, encoding: .utf8) ?? "{}"
                    let syntheticCall = OpenAIToolCall(
                        id: "json_action_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))",
                        name: normalizedJSONFallbackActionName(jsonAction.name),
                        argumentsJSON: argumentText,
                        raw: [
                            "id": "json_action",
                            "type": "function",
                            "function": ["name": normalizedJSONFallbackActionName(jsonAction.name), "arguments": argumentText]
                        ]
                    )
                    let toolResult = try await executeLocalToolCall(syntheticCall, settings: settings, onActivity: onActivity)
                    messages.append(["role": "assistant", "content": text])
                    messages.append([
                        "role": "user",
                        "content": """
                        Ghost executed the JSON action through the verified harness. Tool result:
                        \(toolResult)

                        Write a concise final answer based only on that result.
                        """
                    ])
                    continue
                }

                if looksLikeUnsupportedToolProtocol(text) {
                    onActivity?(
                        GhostActivityEntry(
                            kind: .info,
                            title: "Repairing local-model output",
                            detail: "The model emitted hidden/tool protocol text. Re-asking for a clean final answer."
                        )
                    )
                    return try await repairUnsupportedToolProtocolOutput(
                        originalPrompt: prompt,
                        badOutput: text,
                        settings: settings,
                        apiKey: apiKey,
                        endpoint: endpoint
                    )
                }

                if nil != requestedTextArtifact(from: extractedUserRequest(from: prompt)),
                   looksLikeFakeFileResponse(text),
                   round < 3 {
                    onActivity?(
                        GhostActivityEntry(
                            kind: .info,
                            title: "Model hallucinated a file save",
                            detail: "The model claimed to save a file without using ghost_create_file. Re-prompting with a direct tool request."
                        )
                    )
                    messages.append([
                        "role": "user",
                        "content": "You said you saved a file but did NOT call ghost_create_file. You MUST call ghost_create_file with the content, then confirm the real path. Do not describe saving a file — actually save it."
                    ])
                    continue
                }

                if !usedToolNames.contains("ghost_create_file"),
                   let savedArtifact = try maybeSaveTextArtifactFallback(
                    prompt: prompt,
                    modelOutput: text,
                    settings: settings,
                    onActivity: onActivity
                   ) {
                    onActivity?(
                        GhostActivityEntry(kind: .success, title: "Local artifact fallback saved", detail: savedArtifact)
                    )
                    return savedArtifact
                }

                onActivity?(
                    GhostActivityEntry(kind: .success, title: "Local tool loop finished", detail: "Round \(round)")
                )
                return text
            }
        }

        throw GhostClientError.commandFailed(
            "\(settings.provider.title) did not produce a final answer after local tool routing. Last HTTP status: \(lastHTTPStatus). Last body: \(lastBody.prefix(800))"
        )
    }

    private func openAICompatibleBasicRequest(
        endpoint: URL,
        apiKey: String,
        messages: [[String: Any]],
        settings: GhostRunSettings
    ) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": settings.model,
            "messages": messages,
            "max_tokens": settings.effortMode.maxTokens,
            "temperature": 0.2
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func openAICompatibleToolRequest(
        endpoint: URL,
        apiKey: String,
        messages: [[String: Any]],
        settings: GhostRunSettings
    ) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": settings.model,
            "messages": messages,
            "max_tokens": settings.effortMode.maxTokens,
            "temperature": 0.2,
            "tools": localOpenAITools(ragEnabled: settings.ragEnabled),
            "tool_choice": "auto"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func localOpenAITools(ragEnabled: Bool) -> [[String: Any]] {
        let tools = [
            openAIFunctionTool(
                name: "ghost_web_search",
                description: "Search the public web when the user asks for current, recent, source-backed, or online information. Do not use this for stable facts that can be answered directly.",
                properties: [
                    "query": [
                        "type": "string",
                        "description": "A concise search query."
                    ],
                    "max_results": [
                        "type": "integer",
                        "description": "Number of results to return. Use 4 to 6 for most tasks.",
                        "minimum": 1,
                        "maximum": 8
                    ]
                ],
                required: ["query"]
            ),
            openAIFunctionTool(
                name: "ghost_search_files",
                description: "Search filenames inside the current Ghost workspace. Use this before reading local files when the exact path is unknown.",
                properties: [
                    "query": ["type": "string", "description": "Filename or extension query, for example 'README', '.swift', or 'invoice'."],
                    "max_results": ["type": "integer", "minimum": 1, "maximum": 50]
                ],
                required: ["query"]
            ),
            openAIFunctionTool(
                name: "ghost_read_file",
                description: "Read a UTF-8 text file from the current Ghost workspace. Paths must stay inside the workspace.",
                properties: [
                    "path": ["type": "string", "description": "Workspace-relative path or absolute path under the workspace."],
                    "max_chars": ["type": "integer", "minimum": 500, "maximum": 50000]
                ],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_create_file",
                description: "Create or update a UTF-8 text artifact. Allowed destinations are the workspace, the selected Ghost output folder, ~/Ghost Outputs, ~/Desktop, ~/Downloads, and ~/Documents. If the user asks for Desktop/Downloads/Documents, pass an explicit path in that folder, such as ~/Desktop/file.html. Use this for text files, Markdown, HTML, JSON, CSV, source code, SVG, and other text-based artifacts. For binary PDF/DOCX/PPTX generation, route through Ghost Agent mode unless Ghost provides a native binary document tool.",
                properties: [
                    "path": ["type": "string", "description": "Workspace-relative path, or absolute/tilde path inside the selected Ghost output folder, ~/Desktop, ~/Downloads, ~/Documents, ~/Ghost Outputs, or the workspace."],
                    "content": ["type": "string", "description": "Full UTF-8 file content."],
                    "overwrite": ["type": "boolean", "description": "Whether to overwrite an existing file. Defaults to false."],
                    "create_parent_directories": ["type": "boolean", "description": "Whether to create missing parent folders. Defaults to true."]
                ],
                required: ["path", "content"]
            ),

            openAIFunctionTool(
                name: "ghost_list_directory",
                description: "List files/folders inside allowed Ghost roots: workspace, ~/Ghost Outputs, ~/Desktop, ~/Downloads, and ~/Documents.",
                properties: [
                    "path": ["type": "string", "description": "Optional path. Defaults to workspace. Can be workspace-relative or Desktop/Downloads/Documents/Ghost Outputs."],
                    "include_hidden": ["type": "boolean"],
                    "max_results": ["type": "integer", "minimum": 1, "maximum": 500]
                ],
                required: []
            ),
            openAIFunctionTool(
                name: "ghost_get_file_info",
                description: "Return verified metadata for a file or folder in an allowed Ghost root.",
                properties: [
                    "path": ["type": "string"]
                ],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_write_file",
                description: "Write a UTF-8 text file to an allowed folder and verify the exact path. Use native document tools for PDF/DOCX/PPTX/XLSX.",
                properties: [
                    "path": ["type": "string"],
                    "content": ["type": "string"],
                    "overwrite": ["type": "boolean"],
                    "create_parent_directories": ["type": "boolean"]
                ],
                required: ["path", "content"]
            ),
            openAIFunctionTool(
                name: "ghost_update_file",
                description: "Overwrite an existing UTF-8 text file in an allowed folder and verify it. Use only when the user asked to update/replace/edit a file.",
                properties: [
                    "path": ["type": "string"],
                    "content": ["type": "string"]
                ],
                required: ["path", "content"]
            ),
            openAIFunctionTool(
                name: "ghost_create_folder",
                description: "Create a folder inside an allowed Ghost root and verify it exists.",
                properties: ["path": ["type": "string"]],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_copy_file",
                description: "Copy a file between allowed Ghost roots.",
                properties: [
                    "source_path": ["type": "string"],
                    "destination_path": ["type": "string"],
                    "overwrite": ["type": "boolean"]
                ],
                required: ["source_path", "destination_path"]
            ),
            openAIFunctionTool(
                name: "ghost_move_file",
                description: "Move a file between allowed Ghost roots.",
                properties: [
                    "source_path": ["type": "string"],
                    "destination_path": ["type": "string"],
                    "overwrite": ["type": "boolean"]
                ],
                required: ["source_path", "destination_path"]
            ),
            openAIFunctionTool(
                name: "ghost_delete_file",
                description: "Move a file inside an allowed Ghost root to Trash. This is high-risk; only use after explicit user deletion intent.",
                properties: [
                    "path": ["type": "string"],
                    "trash": ["type": "boolean", "description": "Defaults to true. Prefer Trash over permanent deletion."]
                ],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_open_file",
                description: "Open a verified allowed file with the default macOS app.",
                properties: ["path": ["type": "string"]],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_reveal_in_finder",
                description: "Reveal a verified allowed file in Finder.",
                properties: ["path": ["type": "string"]],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_create_markdown",
                description: "Create a real .md Markdown file in an allowed folder and verify it.",
                properties: ["path": ["type": "string"], "content": ["type": "string"], "overwrite": ["type": "boolean"]],
                required: ["path", "content"]
            ),
            openAIFunctionTool(
                name: "ghost_create_html",
                description: "Create a real .html file in an allowed folder and verify it. Use for self-contained HTML/CSS/JS artifacts.",
                properties: ["path": ["type": "string"], "content": ["type": "string"], "overwrite": ["type": "boolean"]],
                required: ["path", "content"]
            ),
            openAIFunctionTool(
                name: "ghost_create_txt",
                description: "Create a real .txt file in an allowed folder and verify it.",
                properties: ["path": ["type": "string"], "content": ["type": "string"], "overwrite": ["type": "boolean"]],
                required: ["path", "content"]
            ),
            openAIFunctionTool(
                name: "ghost_create_csv",
                description: "Create a real .csv file in an allowed folder and verify it.",
                properties: ["path": ["type": "string"], "content": ["type": "string"], "overwrite": ["type": "boolean"]],
                required: ["path", "content"]
            ),
            openAIFunctionTool(
                name: "ghost_create_json",
                description: "Create a real .json file after validating JSON content, then verify it.",
                properties: ["path": ["type": "string"], "content": ["type": "string"], "overwrite": ["type": "boolean"]],
                required: ["path", "content"]
            ),
            openAIFunctionTool(
                name: "ghost_create_pdf",
                description: "Create a real PDF file from text content using Ghost's native document generator. Use when the user asks for PDF.",
                properties: ["path": ["type": "string"], "title": ["type": "string"], "content": ["type": "string"], "overwrite": ["type": "boolean"]],
                required: ["path", "content"]
            ),
            openAIFunctionTool(
                name: "ghost_create_docx",
                description: "Create a real DOCX file from text content using Ghost's native OpenXML generator. Use when the user asks for Word/DOCX.",
                properties: ["path": ["type": "string"], "title": ["type": "string"], "content": ["type": "string"], "overwrite": ["type": "boolean"]],
                required: ["path", "content"]
            ),
            openAIFunctionTool(
                name: "ghost_create_pptx",
                description: "Create a real PPTX file. Prefer slides as objects with title and bullets. Use when the user asks for PowerPoint/slides.",
                properties: [
                    "path": ["type": "string"],
                    "title": ["type": "string"],
                    "content": ["type": "string"],
                    "slides": ["type": "array", "items": ["type": "object"]],
                    "overwrite": ["type": "boolean"]
                ],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_create_xlsx",
                description: "Create a real XLSX spreadsheet from CSV-like content. Use when the user asks for Excel/XLSX.",
                properties: ["path": ["type": "string"], "csv_content": ["type": "string"], "overwrite": ["type": "boolean"]],
                required: ["path", "csv_content"]
            ),
            openAIFunctionTool(
                name: "ghost_convert_file",
                description: "Convert a UTF-8 text/Markdown file to pdf, docx, html, txt, or md.",
                properties: [
                    "input_path": ["type": "string"],
                    "output_path": ["type": "string"],
                    "output_format": ["type": "string", "description": "pdf, docx, html, txt, or md"],
                    "overwrite": ["type": "boolean"]
                ],
                required: ["input_path", "output_path", "output_format"]
            ),
            openAIFunctionTool(
                name: "ghost_rag_ingest_file",
                description: "Index a supported local document into Ghost RAG for cited document Q&A. Supports txt, md, html, pdf, docx, csv, json, rtf, and common code files.",
                properties: ["path": ["type": "string"]],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_rag_ingest_folder",
                description: "Index supported files from a local folder into Ghost RAG. Use when the user asks to index a folder or notes collection.",
                properties: [
                    "path": ["type": "string"],
                    "recursive": ["type": "boolean", "description": "Defaults to true."],
                    "max_files": ["type": "integer", "minimum": 1, "maximum": 500]
                ],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_rag_sync_folder",
                description: "Incrementally sync supported local files from a folder into Ghost RAG. Skips unchanged files and removes deleted source files from the index.",
                properties: [
                    "path": ["type": "string"],
                    "recursive": ["type": "boolean", "description": "Defaults to true."],
                    "remove_missing": ["type": "boolean", "description": "Defaults to true. Removes deleted source files from the RAG index only."],
                    "max_files": ["type": "integer", "minimum": 1, "maximum": 50000]
                ],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_rag_query",
                description: "Retrieve cited document chunks before answering questions about indexed documents, notes, PDFs, folders, syllabi, contracts, or uploaded/local files.",
                properties: [
                    "query": ["type": "string"],
                    "max_results": ["type": "integer", "minimum": 1, "maximum": 20]
                ],
                required: ["query"]
            ),
            openAIFunctionTool(
                name: "ghost_rag_search_chunks",
                description: "Search indexed document chunks and return matching source excerpts with paths, page numbers, sections, and scores.",
                properties: [
                    "query": ["type": "string"],
                    "max_results": ["type": "integer", "minimum": 1, "maximum": 20]
                ],
                required: ["query"]
            ),
            openAIFunctionTool(
                name: "ghost_rag_remove_document",
                description: "Remove one indexed document from Ghost RAG by source path.",
                properties: ["path": ["type": "string"]],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_rag_reindex",
                description: "Re-extract and reindex all documents currently known to Ghost RAG.",
                properties: [:],
                required: []
            ),
            openAIFunctionTool(
                name: "ghost_rag_status",
                description: "Show Ghost RAG database path, document count, and chunk count.",
                properties: [:],
                required: []
            ),
            openAIFunctionTool(
                name: "ghost_rag_open_source",
                description: "Open a cited RAG source document with the default macOS app.",
                properties: ["path": ["type": "string"]],
                required: ["path"]
            ),
            openAIFunctionTool(
                name: "ghost_rag_clear_index",
                description: "Clear the local Ghost RAG index. This does not delete source files. Use only after explicit user intent.",
                properties: [:],
                required: []
            ),
            openAIFunctionTool(
                name: "ghost_schedule_reminder",
                description: "Create a one-shot reminder in the macOS Reminders app. Use this only after the due date is explicit and unambiguous.",
                properties: [
                    "title": ["type": "string", "description": "Reminder text."],
                    "due_iso8601": ["type": "string", "description": "Due date as ISO-8601 date/time, preferably with timezone, e.g. 2026-06-26T21:00:00+08:00."]
                ],
                required: ["title", "due_iso8601"]
            ),
            openAIFunctionTool(
                name: "ghost_create_calendar_event",
                description: "Create a calendar event with a default 15-minute notification. Use this only after the start and end times are explicit and unambiguous.",
                properties: [
                    "title": ["type": "string", "description": "Event title."],
                    "start_iso8601": ["type": "string", "description": "Event start as ISO-8601 date/time, preferably with timezone."],
                    "end_iso8601": ["type": "string", "description": "Event end as ISO-8601 date/time, preferably with timezone."],
                    "location": ["type": "string", "description": "Optional event location."],
                    "notes": ["type": "string", "description": "Optional notes." ]
                ],
                required: ["title", "start_iso8601", "end_iso8601"]
            ),
            openAIFunctionTool(
                name: "ghost_query_calendar",
                description: "Read events from the user's macOS Calendar in a concrete date range. Use this for questions like 'what is on my calendar next week?' or 'show tomorrow's meetings'.",
                properties: [
                    "start_iso8601": ["type": "string", "description": "Range start as ISO-8601 date/time, preferably with timezone."],
                    "end_iso8601": ["type": "string", "description": "Range end as ISO-8601 date/time, preferably with timezone."],
                    "search_text": ["type": "string", "description": "Optional text to filter event title, location, notes, or calendar name."],
                    "max_results": ["type": "integer", "minimum": 1, "maximum": 80]
                ],
                required: ["start_iso8601", "end_iso8601"]
            ),
            openAIFunctionTool(
                name: "ghost_run_readonly_command",
                description: "Run a safe read-only command in the current workspace for inspection only. This rejects shells, pipes, redirects, file edits, installs, network downloads, and destructive operations.",
                properties: [
                    "command": ["type": "string", "description": "Single command line, such as 'pwd', 'ls -la', 'git status', 'git diff', 'grep -R TODO Sources'."]
                ],
                required: ["command"]
            )
        ]

        guard ragEnabled else {
            return tools.filter { tool in
                guard let function = tool["function"] as? [String: Any],
                      let name = function["name"] as? String
                else {
                    return true
                }
                return !name.hasPrefix("ghost_rag_")
            }
        }

        return tools
    }

    private func openAIFunctionTool(
        name: String,
        description: String,
        properties: [String: Any],
        required: [String]
    ) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required
                ]
            ]
        ]
    }

    private func localToolSystemPrompt(outputDirectory: String, ragEnabled: Bool) -> String {
        let ragToolSummary = ragEnabled
            ? """
            - ghost_rag_ingest_file / ghost_rag_ingest_folder / ghost_rag_sync_folder: index or refresh local documents for Ghost RAG.
            - ghost_rag_query / ghost_rag_search_chunks: retrieve cited chunks from indexed documents before answering document questions.
            - ghost_rag_status / ghost_rag_remove_document / ghost_rag_reindex / ghost_rag_open_source / ghost_rag_clear_index: manage the local RAG index.
            """
            : """
            - Ghost RAG is disabled by user preference. Do not call or mention RAG tools. If document indexing is needed, tell the user to turn on RAG in Settings first.
            """

        return """
        You are Ghost, a native macOS assistant running with a local model through LM Studio or Ollama.

        You have real Ghost-managed tools in Direct API mode:
        - ghost_web_search: public web search with source snippets.
        - ghost_search_files / ghost_list_directory / ghost_get_file_info: inspect allowed local files.
        - ghost_read_file: read UTF-8 files in allowed roots.
        - ghost_create_file / ghost_write_file / ghost_update_file: create or update UTF-8 files inside allowed folders: workspace, ~/Ghost Outputs, ~/Desktop, ~/Downloads, and ~/Documents.
        - ghost_create_markdown / ghost_create_html / ghost_create_txt / ghost_create_csv / ghost_create_json: native text artifact creation with verification.
        - ghost_create_pdf / ghost_create_docx / ghost_create_pptx / ghost_create_xlsx: native real document generation with verification.
        - ghost_create_folder / ghost_copy_file / ghost_move_file / ghost_delete_file: verified file management. Delete is high-risk; only use after explicit deletion intent.
        - ghost_open_file / ghost_reveal_in_finder: open or reveal verified allowed files.
        \(ragToolSummary)
        - ghost_schedule_reminder: create a one-shot macOS Reminder.
        - ghost_create_calendar_event: create a Calendar event with a notification.
        - ghost_query_calendar: read events from macOS Calendar for a concrete date range.
        - ghost_run_readonly_command: inspect the workspace with safe read-only commands.

        Tool-use rules:
        - Use OpenAI-compatible tool_calls when a tool is needed. Never write tool calls in normal text.
        - Never output hidden channel syntax, browser.run, analysis to=..., <|channel|>, <|message|>, JSON blobs, XML tags, or markdown tool requests.
        - Do not invent tools. Use only the listed tools.
        - Prefer deterministic tools over guessing: search before claiming file contents, create files before saying they were saved, schedule reminders before confirming them.
        - Default Ghost-produced documents and code artifacts to \(outputDirectory) unless the user names another folder.
        - When RAG is enabled and the user asks what a document, PDF, folder, syllabus, contract, uploaded document, note, or indexed file says, call ghost_rag_query first and answer only from returned chunks with citations like [1].
        - When RAG is enabled and a document question names a file or folder that has not been indexed, call ghost_rag_ingest_file or ghost_rag_ingest_folder first, then ghost_rag_query.
        - If the user asks to create, make, save, write, or generate a text-based file such as .html, .md, .txt, .json, .csv, .css, .js, .py, .swift, or .svg, you must call ghost_create_file with the full file content before your final answer.
        - If the user says Desktop, Downloads, or Documents, the ghost_create_file path must be explicit, e.g. ~/Desktop/name.html. Do not save to the workspace and claim it is on Desktop.
        - Use ghost_web_search only for current/recent/source-backed facts, or when the user asks to look something up.
        - If you use ghost_web_search or RAG results, end the final answer with `## References` and list each source title plus URL or file path you relied on.
        - Use native document tools for requested binary documents: ghost_create_pdf, ghost_create_docx, ghost_create_pptx, and ghost_create_xlsx. Do not fake these as plain text files.
        - For screenshots/OCR, email sending, broad computer control, dangerous shell actions, and large coding agent work, say Ghost Agent/OpenCode mode or explicit approval is needed unless Ghost already routed you there.
        - For reminders and calendar events, ask a clarifying question when date/time is ambiguous. For explicit one-shot reminders, call ghost_schedule_reminder. For explicit events, call ghost_create_calendar_event. For read-only calendar questions with an explicit or inferable range, call ghost_query_calendar before answering.
        - After tool results are provided, write a clean final answer in concise user-visible Markdown.
        """
    }

    private func openAIToolCalls(from message: [String: Any]) -> [OpenAIToolCall] {
        guard let rawCalls = message["tool_calls"] as? [[String: Any]] else {
            return []
        }

        return rawCalls.compactMap { raw in
            guard
                let function = raw["function"] as? [String: Any],
                let name = function["name"] as? String
            else {
                return nil
            }

            let id = (raw["id"] as? String)?.nonEmpty ?? "call_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
            let argumentsJSON = function["arguments"] as? String ?? "{}"
            return OpenAIToolCall(id: id, name: name, argumentsJSON: argumentsJSON, raw: raw)
        }
    }

    private func assistantToolCallMessage(
        from message: [String: Any],
        toolCalls: [OpenAIToolCall]
    ) -> [String: Any] {
        let rawToolCalls = message["tool_calls"] as? [[String: Any]] ?? toolCalls.map { $0.raw }
        return [
            "role": "assistant",
            "content": message["content"] as? String ?? "",
            "tool_calls": rawToolCalls
        ]
    }

    private func executeLocalToolCall(
        _ toolCall: OpenAIToolCall,
        settings: GhostRunSettings,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) async throws -> String {
        switch toolCall.name {
        case "ghost_web_search":
            return try await executeWebSearchTool(toolCall, onActivity: onActivity)

        case "ghost_search_files":
            return executeSearchFilesTool(toolCall, settings: settings)

        case "ghost_read_file":
            return executeReadFileTool(toolCall, settings: settings)

        case "ghost_create_file":
            return executeCreateFileTool(toolCall, settings: settings, onActivity: onActivity)

        case "ghost_list_directory", "ghost_get_file_info", "ghost_write_file", "ghost_update_file",
             "ghost_create_folder", "ghost_copy_file", "ghost_move_file", "ghost_delete_file",
             "ghost_open_file", "ghost_reveal_in_finder", "ghost_create_markdown", "ghost_create_html",
             "ghost_create_txt", "ghost_create_csv", "ghost_create_json", "ghost_create_pdf",
             "ghost_create_docx", "ghost_create_pptx", "ghost_create_xlsx", "ghost_convert_file":
            return executeCapabilityHarnessTool(toolCall, settings: settings, onActivity: onActivity)

        case "ghost_rag_ingest_file", "ghost_rag_ingest_folder", "ghost_rag_sync_folder", "ghost_rag_remove_document",
             "ghost_rag_reindex", "ghost_rag_query", "ghost_rag_search_chunks",
             "ghost_rag_open_source", "ghost_rag_status", "ghost_rag_clear_index":
            return executeRAGTool(toolCall, settings: settings, onActivity: onActivity)

        case "ghost_schedule_reminder":
            return try await executeScheduleReminderTool(toolCall, onActivity: onActivity)

        case "ghost_create_calendar_event":
            return try await executeCreateCalendarEventTool(toolCall, onActivity: onActivity)

        case "ghost_query_calendar":
            return try await executeQueryCalendarTool(toolCall, onActivity: onActivity)

        case "ghost_run_readonly_command":
            return executeReadOnlyCommandTool(toolCall, settings: settings, onActivity: onActivity)

        default:
            return jsonString([
                "ok": false,
                "error": "Unsupported tool '\(toolCall.name)'. Use only the tools Ghost provided. Use Ghost Agent mode for broad computer control, screenshots/OCR, email actions, binary document generation, and code edits that need approval. Calendar read/create actions are available through Ghost calendar tools."
            ])
        }
    }


    private func executeCapabilityHarnessTool(
        _ toolCall: OpenAIToolCall,
        settings: GhostRunSettings,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) -> String {
        let arguments = jsonDictionary(from: toolCall.argumentsJSON)
        let path = (arguments["path"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let content = arguments["content"] as? String ?? ""
        let overwrite = arguments["overwrite"] as? Bool ?? false
        let createParents = arguments["create_parent_directories"] as? Bool ?? true
        let workspace = settings.workingDirectory

        onActivity?(GhostActivityEntry(kind: .command, title: "Harness: \(toolCall.name)", detail: toolCall.argumentsJSON))

        let result: [String: Any]
        switch toolCall.name {
        case "ghost_list_directory":
            result = capabilityHarness.listDirectory(
                path: (arguments["path"] as? String),
                includeHidden: arguments["include_hidden"] as? Bool ?? false,
                maxResults: arguments["max_results"] as? Int ?? 200,
                workspace: workspace
            )

        case "ghost_get_file_info":
            result = capabilityHarness.getFileInfo(path: path, workspace: workspace)

        case "ghost_write_file":
            result = capabilityHarness.writeFile(path: path, content: content, overwrite: overwrite, createParents: createParents, workspace: workspace)

        case "ghost_update_file":
            result = capabilityHarness.writeFile(path: path, content: content, overwrite: true, createParents: true, workspace: workspace, toolName: "ghost_update_file")

        case "ghost_create_folder":
            result = capabilityHarness.createFolder(path: path, workspace: workspace)

        case "ghost_copy_file":
            result = capabilityHarness.copyFile(
                sourcePath: arguments["source_path"] as? String ?? "",
                destinationPath: arguments["destination_path"] as? String ?? "",
                overwrite: overwrite,
                workspace: workspace
            )

        case "ghost_move_file":
            result = capabilityHarness.moveFile(
                sourcePath: arguments["source_path"] as? String ?? "",
                destinationPath: arguments["destination_path"] as? String ?? "",
                overwrite: overwrite,
                workspace: workspace
            )

        case "ghost_delete_file":
            result = capabilityHarness.deleteFile(path: path, trash: arguments["trash"] as? Bool ?? true, workspace: workspace)

        case "ghost_open_file":
            result = capabilityHarness.openFile(path: path, reveal: false, workspace: workspace)

        case "ghost_reveal_in_finder":
            result = capabilityHarness.openFile(path: path, reveal: true, workspace: workspace)

        case "ghost_create_markdown":
            result = capabilityHarness.createTextDocument(toolName: "ghost_create_markdown", path: path, content: content, overwrite: overwrite, workspace: workspace)

        case "ghost_create_html":
            result = capabilityHarness.createTextDocument(toolName: "ghost_create_html", path: path, content: content, overwrite: overwrite, workspace: workspace)

        case "ghost_create_txt":
            result = capabilityHarness.createTextDocument(toolName: "ghost_create_txt", path: path, content: content, overwrite: overwrite, workspace: workspace)

        case "ghost_create_csv":
            result = capabilityHarness.createTextDocument(toolName: "ghost_create_csv", path: path, content: content, overwrite: overwrite, workspace: workspace)

        case "ghost_create_json":
            result = capabilityHarness.createTextDocument(toolName: "ghost_create_json", path: path, content: content, overwrite: overwrite, workspace: workspace)

        case "ghost_create_pdf":
            result = capabilityHarness.createPDF(
                path: path,
                title: arguments["title"] as? String,
                content: content,
                overwrite: overwrite,
                workspace: workspace
            )

        case "ghost_create_docx":
            result = capabilityHarness.createDOCX(
                path: path,
                title: arguments["title"] as? String,
                content: content,
                overwrite: overwrite,
                workspace: workspace
            )

        case "ghost_create_pptx":
            result = capabilityHarness.createPPTX(
                path: path,
                title: arguments["title"] as? String,
                slides: arguments["slides"] as? [[String: Any]] ?? [],
                fallbackContent: content.nonEmpty,
                overwrite: overwrite,
                workspace: workspace
            )

        case "ghost_create_xlsx":
            result = capabilityHarness.createXLSX(
                path: path,
                csvContent: arguments["csv_content"] as? String ?? content,
                overwrite: overwrite,
                workspace: workspace
            )

        case "ghost_convert_file":
            result = capabilityHarness.convertFile(
                inputPath: arguments["input_path"] as? String ?? "",
                outputPath: arguments["output_path"] as? String ?? "",
                outputFormat: arguments["output_format"] as? String ?? "",
                overwrite: overwrite,
                workspace: workspace
            )

        default:
            result = ["ok": false, "tool": toolCall.name, "verified": false, "error": "Unsupported harness tool."]
        }

        if result["ok"] as? Bool == true {
            onActivity?(GhostActivityEntry(kind: .success, title: "Harness verified", detail: (result["actual_path"] as? String) ?? (result["summary"] as? String ?? toolCall.name)))
        } else {
            onActivity?(GhostActivityEntry(kind: .error, title: "Harness tool failed", detail: result["error"] as? String ?? toolCall.name))
        }

        return jsonString(result)
    }

    private func executeRAGTool(
        _ toolCall: OpenAIToolCall,
        settings: GhostRunSettings,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) -> String {
        guard settings.ragEnabled else {
            return jsonString([
                "ok": false,
                "tool": toolCall.name,
                "verified": false,
                "error": "RAG is disabled by user preference. Turn on RAG in Ghost Settings before indexing or querying documents."
            ])
        }

        let arguments = jsonDictionary(from: toolCall.argumentsJSON)
        let path = (arguments["path"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let query = (arguments["query"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let workspace = settings.workingDirectory

        onActivity?(GhostActivityEntry(kind: .command, title: "RAG: \(toolCall.name)", detail: toolCall.argumentsJSON))

        let result: [String: Any]
        switch toolCall.name {
        case "ghost_rag_ingest_file":
            result = ragStore.ingestFile(path: path, workspace: workspace)
        case "ghost_rag_ingest_folder":
            result = ragStore.ingestFolder(
                path: path,
                recursive: arguments["recursive"] as? Bool ?? true,
                maxFiles: arguments["max_files"] as? Int ?? 100,
                workspace: workspace
            )
        case "ghost_rag_sync_folder":
            result = ragStore.syncFolder(
                path: path,
                recursive: arguments["recursive"] as? Bool ?? true,
                removeMissing: arguments["remove_missing"] as? Bool ?? true,
                maxFiles: arguments["max_files"] as? Int ?? 5_000,
                workspace: workspace
            )
        case "ghost_rag_remove_document":
            result = ragStore.removeDocument(path: path, workspace: workspace)
        case "ghost_rag_reindex":
            result = ragStore.reindex(workspace: workspace)
        case "ghost_rag_query":
            result = ragStore.query(query, maxResults: arguments["max_results"] as? Int ?? 6, workspace: workspace)
        case "ghost_rag_search_chunks":
            result = ragStore.searchChunks(query, maxResults: arguments["max_results"] as? Int ?? 10, workspace: workspace)
        case "ghost_rag_open_source":
            result = ragStore.openSource(path: path, workspace: workspace)
        case "ghost_rag_status":
            result = ragStore.status()
        case "ghost_rag_clear_index":
            result = ragStore.clearIndex()
        default:
            result = ["ok": false, "tool": toolCall.name, "verified": false, "error": "Unsupported RAG tool."]
        }

        if result["ok"] as? Bool == true {
            onActivity?(GhostActivityEntry(kind: .success, title: "RAG verified", detail: result["summary"] as? String ?? toolCall.name))
        } else {
            onActivity?(GhostActivityEntry(kind: .error, title: "RAG tool failed", detail: result["error"] as? String ?? toolCall.name))
        }

        return jsonString(result)
    }

    private func executeWebSearchTool(
        _ toolCall: OpenAIToolCall,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) async throws -> String {
        let arguments = jsonDictionary(from: toolCall.argumentsJSON)
        let rawQuery = arguments["query"] as? String ?? ""
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return jsonString([
                "ok": false,
                "error": "ghost_web_search requires a non-empty query."
            ])
        }

        let requestedMax = arguments["max_results"] as? Int ?? 6
        let maxResults = min(max(requestedMax, 1), 8)

        onActivity?(
            GhostActivityEntry(kind: .command, title: "Searching the web", detail: query)
        )

        let results = try await webSearchService.search(query: query, maxResults: maxResults)
        onActivity?(
            GhostActivityEntry(kind: .success, title: "Web search finished", detail: "\(results.count) results")
        )

        let payloadResults: [[String: Any]] = results.enumerated().map { index, result in
            var value: [String: Any] = [
                "index": index + 1,
                "title": result.title,
                "url": result.url,
                "snippet": result.snippet
            ]
            if let pageText = result.pageText, !pageText.isEmpty {
                value["extract"] = pageText
            }
            return value
        }

            return jsonString([
                "ok": true,
                "query": query,
                "results": payloadResults,
                "citation_instruction": "When using these results, cite them inline as [1], [2], etc. End the final answer with ## References listing each relied-on source title and URL."
            ])
    }

    private func executeSearchFilesTool(
        _ toolCall: OpenAIToolCall,
        settings: GhostRunSettings
    ) -> String {
        let arguments = jsonDictionary(from: toolCall.argumentsJSON)
        let query = (arguments["query"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return jsonString(["ok": false, "error": "ghost_search_files requires a non-empty query."])
        }

        let maxResults = min(max(arguments["max_results"] as? Int ?? 20, 1), 50)
        let root = standardizedURL(settings.workingDirectory)
        let fileManager = FileManager.default
        let ignoredDirectoryNames: Set<String> = [
            ".git", ".svn", ".hg", ".build", "DerivedData", "node_modules", ".venv", "venv", "__pycache__", ".cache"
        ]

        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            return jsonString(["ok": false, "error": "Could not enumerate workspace."])
        }

        let loweredQuery = query.lowercased()
        var matches: [[String: Any]] = []
        var visited = 0

        for case let url as URL in enumerator {
            visited += 1
            if visited > 8000 { break }

            let name = url.lastPathComponent
            if ignoredDirectoryNames.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            let relative = relativePath(for: url, root: root)
            let loweredRelative = relative.lowercased()
            let isMatch = loweredRelative.contains(loweredQuery)
                || (loweredQuery.hasPrefix(".") && url.pathExtension.lowercased() == String(loweredQuery.dropFirst()))

            guard isMatch else { continue }

            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            matches.append([
                "path": relative,
                "is_directory": resourceValues?.isDirectory == true,
                "size_bytes": resourceValues?.fileSize ?? 0
            ])

            if matches.count >= maxResults { break }
        }

        return jsonString([
            "ok": true,
            "workspace": root.path,
            "query": query,
            "results": matches,
            "truncated": visited > 8000
        ])
    }

    private func executeReadFileTool(
        _ toolCall: OpenAIToolCall,
        settings: GhostRunSettings
    ) -> String {
        let arguments = jsonDictionary(from: toolCall.argumentsJSON)
        let path = (arguments["path"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let maxChars = min(max(arguments["max_chars"] as? Int ?? 16000, 500), 50000)

        guard let url = safeWorkspaceURL(path, root: settings.workingDirectory) else {
            return jsonString(["ok": false, "error": "Path must stay inside the current workspace."])
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return jsonString(["ok": false, "error": "File does not exist or is a directory."])
        }

        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return jsonString(["ok": false, "error": "Could not read file."])
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return jsonString(["ok": false, "error": "File is not UTF-8 text. Use Ghost Agent mode for binary files."])
        }

        let truncated = text.count > maxChars
        let content = truncated ? String(text.prefix(maxChars)) : text

        return jsonString([
            "ok": true,
            "path": relativePath(for: url, root: settings.workingDirectory),
            "size_bytes": data.count,
            "truncated": truncated,
            "content": content
        ])
    }

    private func executeCreateFileTool(
        _ toolCall: OpenAIToolCall,
        settings: GhostRunSettings,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) -> String {
        let arguments = jsonDictionary(from: toolCall.argumentsJSON)
        let path = (arguments["path"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let content = arguments["content"] as? String ?? ""
        let overwrite = arguments["overwrite"] as? Bool ?? false
        let createParents = arguments["create_parent_directories"] as? Bool ?? true

        guard !path.isEmpty else {
            return jsonString(["ok": false, "error": "ghost_create_file requires a path."])
        }

        guard let url = safeWritableUserURL(path, root: settings.workingDirectory) else {
            return jsonString([
                "ok": false,
                "error": "Path must stay inside an allowed write folder: workspace, ~/Ghost Outputs, ~/Desktop, ~/Downloads, or ~/Documents."
            ])
        }

        let extensionLower = url.pathExtension.lowercased()
        let binaryExtensions: Set<String> = ["pdf", "docx", "pptx", "xlsx", "pages", "key", "numbers", "zip", "png", "jpg", "jpeg", "gif", "webp"]
        if binaryExtensions.contains(extensionLower) {
            return jsonString([
                "ok": false,
                "error": "ghost_create_file only writes UTF-8 text. Use Ghost Agent mode for binary .\(extensionLower) generation so a real file package can be produced."
            ])
        }

        if FileManager.default.fileExists(atPath: url.path), !overwrite {
            return jsonString([
                "ok": false,
                "error": "File already exists. Call ghost_create_file with overwrite=true only if the user asked to replace it.",
                "path": url.path
            ])
        }

        do {
            if createParents {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            }
            try content.write(to: url, atomically: true, encoding: .utf8)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return jsonString([
                    "ok": false,
                    "error": "Write completed but Ghost could not verify the file at the requested path.",
                    "path": url.path
                ])
            }
            let byteCount = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
                ?? content.data(using: .utf8)?.count
                ?? 0
            onActivity?(
                GhostActivityEntry(kind: .success, title: "File written and verified", detail: url.path)
            )
            return jsonString([
                "ok": true,
                "path": url.path,
                "relative_path": relativePath(for: url, root: settings.workingDirectory),
                "bytes": byteCount,
                "verified": true
            ])
        } catch {
            return jsonString(["ok": false, "error": error.localizedDescription, "path": url.path])
        }
    }

    private func maybeSaveTextArtifactFallback(
        prompt: String,
        modelOutput: String,
        settings: GhostRunSettings,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) throws -> String? {
        let userRequest = extractedUserRequest(from: prompt)
        guard let artifact = requestedTextArtifact(from: userRequest) else {
            return nil
        }

        guard let content = extractArtifactContent(from: modelOutput, preferredExtension: artifact.extension) else {
            return nil
        }

        let root = standardizedURL(settings.workingDirectory)
        guard let requestedURL = artifactDestinationURL(
            filename: artifact.filename,
            userRequest: userRequest,
            root: root
        ) else {
            return nil
        }
        let url = uniqueArtifactURL(for: requestedURL)

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw GhostClientError.commandFailed("Could not save generated file: \(error.localizedDescription)")
        }

        let relative = relativePath(for: url, root: root)
        onActivity?(
            GhostActivityEntry(kind: .success, title: "File written", detail: url.path)
        )

        return "Created `\(relative)` at:\n\n`\(url.path)`"
    }

    private func extractedUserRequest(from prompt: String) -> String {
        var text = prompt
        if let range = text.range(of: "User request:") {
            text = String(text[range.upperBound...])
        }
        if let clipboardRange = text.range(of: "Clipboard context:") {
            text = String(text[..<clipboardRange.lowerBound])
        }
        if let contextRange = text.range(of: "Recent conversation:") {
            text = String(text[..<contextRange.lowerBound])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestedTextArtifact(from userRequest: String) -> (filename: String, extension: String)? {
        let lower = userRequest.lowercased()
        let creationCues = ["create", "make", "save", "write", "generate", "build", "export"]
        guard creationCues.contains(where: { lower.contains($0) }) else {
            return nil
        }

        let textExtensions: Set<String> = [
            "html", "htm", "md", "txt", "json", "csv", "css", "js", "ts", "py", "swift", "xml", "svg", "yaml", "yml", "toml"
        ]

        if let match = firstRegexMatch(
            pattern: #"([A-Za-z0-9_ .()\-]+\.([A-Za-z0-9]{1,8}))"#,
            in: userRequest
        ),
           match.count >= 3 {
            let filename = sanitizeRelativeArtifactPath(match[1])
            let ext = match[2].lowercased()
            if textExtensions.contains(ext), filename.contains(".") {
                return (filename, ext)
            }
        }

        let mentionedExtension: String?
        if lower.contains(".html") || lower.contains(" html") || lower.contains("web page") || lower.contains("webpage") {
            mentionedExtension = "html"
        } else if lower.contains(".md") || lower.contains("markdown") {
            mentionedExtension = "md"
        } else if lower.contains(".txt") || lower.contains("text file") {
            mentionedExtension = "txt"
        } else if lower.contains(".json") {
            mentionedExtension = "json"
        } else if lower.contains(".csv") {
            mentionedExtension = "csv"
        } else if lower.contains(".svg") {
            mentionedExtension = "svg"
        } else if lower.contains(".css") {
            mentionedExtension = "css"
        } else if lower.contains(".js") || lower.contains("javascript") {
            mentionedExtension = "js"
        } else {
            mentionedExtension = nil
        }

        guard let ext = mentionedExtension else { return nil }
        let slug = slugFilename(from: lower, fallback: "ghost_artifact")
        return ("\(slug).\(ext)", ext)
    }

    private func extractArtifactContent(from modelOutput: String, preferredExtension: String) -> String? {
        let fencedPattern = #"```(?:([A-Za-z0-9_+\-.]+)\s*)?\n([\s\S]*?)\n```"#
        let matches = allRegexMatches(pattern: fencedPattern, in: modelOutput)
        if !matches.isEmpty {
            let preferred = matches.first { match in
                guard match.count >= 3 else { return false }
                let language = match[1].lowercased()
                return language == preferredExtension
                    || (preferredExtension == "html" && ["html", "xml"].contains(language))
                    || (preferredExtension == "js" && ["js", "javascript"].contains(language))
                    || (preferredExtension == "md" && ["md", "markdown"].contains(language))
            } ?? matches.first

            if let preferred, preferred.count >= 3 {
                let code = preferred[2].trimmingCharacters(in: .whitespacesAndNewlines)
                if !code.isEmpty { return code }
            }
        }

        let trimmed = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if ["md", "txt"].contains(preferredExtension) {
            return trimmed
        }

        if preferredExtension == "html" || preferredExtension == "htm" {
            let lower = trimmed.lowercased()
            if let doctypeRange = lower.range(of: "<!doctype") {
                let offset = lower.distance(from: lower.startIndex, to: doctypeRange.lowerBound)
                let index = trimmed.index(trimmed.startIndex, offsetBy: offset)
                return String(trimmed[index...])
            }
            if let htmlRange = lower.range(of: "<html") {
                let offset = lower.distance(from: lower.startIndex, to: htmlRange.lowerBound)
                let index = trimmed.index(trimmed.startIndex, offsetBy: offset)
                return String(trimmed[index...])
            }
            if lower.contains("<body") || lower.contains("<div") || lower.contains("<canvas") || lower.contains("<script") {
                return """
                <!doctype html>
                <html lang="en">
                <head>
                  <meta charset="utf-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1">
                  <title>Ghost Artifact</title>
                </head>
                <body>
                \(trimmed)
                </body>
                </html>
                """
            }
        }

        if ["json", "csv", "css", "js", "ts", "py", "swift", "xml", "svg", "yaml", "yml", "toml"].contains(preferredExtension) {
            return trimmed
        }

        return nil
    }

    private func artifactDestinationURL(filename: String, userRequest: String, root: URL) -> URL? {
        let lower = userRequest.lowercased()
        let path: String
        if lower.contains("desktop") {
            path = "~/Desktop/\(filename)"
        } else if lower.contains("downloads") {
            path = "~/Downloads/\(filename)"
        } else if lower.contains("documents") {
            path = "~/Documents/\(filename)"
        } else {
            path = filename
        }
        return safeWritableUserURL(path, root: root)
    }

    private func uniqueArtifactURL(for requestedURL: URL) -> URL {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: requestedURL.path) {
            return requestedURL
        }

        let directory = requestedURL.deletingLastPathComponent()
        let base = requestedURL.deletingPathExtension().lastPathComponent
        let ext = requestedURL.pathExtension
        for index in 2...999 {
            let candidate = directory.appendingPathComponent("\(base)-\(index)").appendingPathExtension(ext)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return directory.appendingPathComponent("\(base)-\(UUID().uuidString.prefix(8))").appendingPathExtension(ext)
    }

    private func sanitizeRelativeArtifactPath(_ value: String) -> String {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "~", with: "")
            .replacingOccurrences(of: "..", with: "")
            .replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "ghost_artifact.txt" : cleaned
    }

    private func slugFilename(from lowercasedRequest: String, fallback: String) -> String {
        var words = lowercasedRequest
            .replacingOccurrences(of: #"[^a-z0-9\s-]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        let stopWords: Set<String> = [
            "create", "make", "save", "write", "generate", "build", "export", "a", "an", "the", "of", "for", "to", "file", "html", "md", "txt", "json", "csv", "css", "js", "with", "in", "on", "at", "and"
        ]
        words.removeAll { stopWords.contains($0) || $0.count < 2 }
        let selected = Array(words.prefix(4))
        let slug = selected.isEmpty ? fallback : selected.joined(separator: "_")
        return String(slug.prefix(48))
    }

    private func firstRegexMatch(pattern: String, in text: String) -> [String]? {
        allRegexMatches(pattern: pattern, in: text).first
    }

    private func allRegexMatches(pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).map { result in
            (0..<result.numberOfRanges).map { index in
                let range = result.range(at: index)
                guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else {
                    return ""
                }
                return String(text[swiftRange])
            }
        }
    }

    private func executeScheduleReminderTool(
        _ toolCall: OpenAIToolCall,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) async throws -> String {
        let arguments = jsonDictionary(from: toolCall.argumentsJSON)
        let title = (arguments["title"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let dueText = (arguments["due_iso8601"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else {
            return jsonString(["ok": false, "error": "ghost_schedule_reminder requires a title."])
        }
        guard let dueDate = parseISODate(dueText), dueDate > Date().addingTimeInterval(20) else {
            return jsonString(["ok": false, "error": "due_iso8601 must be an unambiguous future ISO-8601 date/time."])
        }

        onActivity?(
            GhostActivityEntry(kind: .command, title: "Creating reminder", detail: title)
        )

        let result = try await reminderService.createReminder(title: title, dueDate: dueDate)

        onActivity?(
            GhostActivityEntry(kind: .success, title: "Reminder created", detail: result.confirmationText())
        )

        return jsonString([
            "ok": true,
            "title": result.title,
            "due_iso8601": ISO8601DateFormatter().string(from: result.dueDate),
            "backend": result.backend,
            "identifier": result.identifier ?? ""
        ])
    }

    private func executeCreateCalendarEventTool(
        _ toolCall: OpenAIToolCall,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) async throws -> String {
        let arguments = jsonDictionary(from: toolCall.argumentsJSON)
        let title = (arguments["title"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let startText = (arguments["start_iso8601"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = (arguments["end_iso8601"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let location = (arguments["location"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = (arguments["notes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else {
            return jsonString(["ok": false, "error": "ghost_create_calendar_event requires a title."])
        }
        guard let startDate = parseISODate(startText), let endDate = parseISODate(endText) else {
            return jsonString(["ok": false, "error": "start_iso8601 and end_iso8601 must be unambiguous ISO-8601 date/times."])
        }
        guard endDate > startDate else {
            return jsonString(["ok": false, "error": "Event end time must be after start time."])
        }

        onActivity?(
            GhostActivityEntry(kind: .command, title: "Creating calendar event", detail: title)
        )

        let result = try await calendarService.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: notes?.isEmpty == false ? notes : nil,
            location: location?.isEmpty == false ? location : nil
        )

        onActivity?(
            GhostActivityEntry(kind: .success, title: "Calendar event created", detail: result.confirmationText())
        )

        return jsonString([
            "ok": true,
            "title": result.title,
            "start_iso8601": ISO8601DateFormatter().string(from: result.startDate),
            "end_iso8601": ISO8601DateFormatter().string(from: result.endDate),
            "calendar": result.calendarTitle,
            "identifier": result.identifier ?? ""
        ])
    }

    private func executeQueryCalendarTool(
        _ toolCall: OpenAIToolCall,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) async throws -> String {
        let arguments = jsonDictionary(from: toolCall.argumentsJSON)
        let startText = (arguments["start_iso8601"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = (arguments["end_iso8601"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let searchText = (arguments["search_text"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        let maxResults = min(max(arguments["max_results"] as? Int ?? 50, 1), 80)

        guard let startDate = parseISODate(startText), let endDate = parseISODate(endText) else {
            return jsonString(["ok": false, "error": "start_iso8601 and end_iso8601 must be unambiguous ISO-8601 date/times."])
        }
        guard endDate > startDate else {
            return jsonString(["ok": false, "error": "Calendar query end time must be after start time."])
        }

        onActivity?(
            GhostActivityEntry(kind: .command, title: "Reading calendar", detail: "\(startText) → \(endText)")
        )

        let events = try await calendarService.queryEvents(
            startDate: startDate,
            endDate: endDate,
            matching: searchText,
            limit: maxResults
        )

        onActivity?(
            GhostActivityEntry(kind: .success, title: "Calendar read", detail: "\(events.count) event\(events.count == 1 ? "" : "s")")
        )

        let iso = ISO8601DateFormatter()
        let payloadEvents: [[String: Any]] = events.map { event in
            var value: [String: Any] = [
                "title": event.title,
                "start_iso8601": iso.string(from: event.startDate),
                "end_iso8601": iso.string(from: event.endDate),
                "calendar": event.calendarTitle,
                "is_all_day": event.isAllDay
            ]
            if let location = event.location {
                value["location"] = location
            }
            if let notes = event.notes {
                value["notes"] = String(notes.prefix(800))
                value["notes_truncated"] = notes.count > 800
            }
            return value
        }

        return jsonString([
            "ok": true,
            "start_iso8601": iso.string(from: startDate),
            "end_iso8601": iso.string(from: endDate),
            "search_text": searchText ?? "",
            "event_count": events.count,
            "events": payloadEvents,
            "instruction": "Summarize these calendar events by day and time. If there are no events, say the calendar appears free for the requested range."
        ])
    }

    private func executeReadOnlyCommandTool(
        _ toolCall: OpenAIToolCall,
        settings: GhostRunSettings,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)?
    ) -> String {
        let arguments = jsonDictionary(from: toolCall.argumentsJSON)
        let command = (arguments["command"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            return jsonString(["ok": false, "error": "ghost_run_readonly_command requires a command."])
        }
        guard let tokens = tokenizeReadOnlyCommand(command), !tokens.isEmpty else {
            return jsonString(["ok": false, "error": "Command contains unsupported shell syntax. Provide a single read-only command without pipes, redirects, semicolons, or shell expansion."])
        }
        guard isAllowedReadOnlyCommand(tokens) else {
            return jsonString(["ok": false, "error": "Command is not on Ghost's read-only allowlist. Use Ghost Agent mode for commands that can edit, install, download, delete, or launch apps."])
        }
        if let pathError = validateReadOnlyCommandPaths(tokens, root: settings.workingDirectory) {
            return jsonString(["ok": false, "error": pathError])
        }

        onActivity?(
            GhostActivityEntry(kind: .command, title: "Running read-only command", detail: command)
        )

        let result = runCommand(tokens, workingDirectory: settings.workingDirectory, timeoutSeconds: 20)
        return jsonString([
            "ok": result.exitStatus == 0,
            "command": command,
            "exit_status": Int(result.exitStatus),
            "stdout": String(result.stdout.prefix(20000)),
            "stderr": String(result.stderr.prefix(12000)),
            "truncated": result.stdout.count > 20000 || result.stderr.count > 12000
        ])
    }

    private func safeWorkspaceURL(_ path: String, root: URL) -> URL? {
        safeURL(path, allowedRoots: [root], defaultRoot: root)
    }

    private func safeWritableUserURL(_ path: String, root: URL) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let ghostOutputs = home.appendingPathComponent("Ghost Outputs", isDirectory: true)
        let desktop = home.appendingPathComponent("Desktop", isDirectory: true)
        let downloads = home.appendingPathComponent("Downloads", isDirectory: true)
        let documents = home.appendingPathComponent("Documents", isDirectory: true)

        let allowedRoots = [root, ghostOutputs, desktop, downloads, documents]
        let defaultRoot = root.appendingPathComponent("Ghost Outputs", isDirectory: true)
        return safeURL(path, allowedRoots: allowedRoots, defaultRoot: defaultRoot)
    }

    private func safeURL(_ rawPath: String, allowedRoots: [URL], defaultRoot: URL) -> URL? {
        var trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "`\"'"))
        guard !trimmed.isEmpty else { return nil }
        guard !isSensitivePathComponent(trimmed) else { return nil }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let lower = trimmed.lowercased()
        let candidate: URL

        if lower == "desktop" || lower.hasPrefix("desktop/") {
            let suffix = lower == "desktop" ? "" : String(trimmed.dropFirst("desktop/".count))
            candidate = home.appendingPathComponent("Desktop", isDirectory: true).appendingPathComponent(suffix)
        } else if lower == "downloads" || lower.hasPrefix("downloads/") {
            let suffix = lower == "downloads" ? "" : String(trimmed.dropFirst("downloads/".count))
            candidate = home.appendingPathComponent("Downloads", isDirectory: true).appendingPathComponent(suffix)
        } else if lower == "documents" || lower.hasPrefix("documents/") {
            let suffix = lower == "documents" ? "" : String(trimmed.dropFirst("documents/".count))
            candidate = home.appendingPathComponent("Documents", isDirectory: true).appendingPathComponent(suffix)
        } else {
            let expanded = (trimmed as NSString).expandingTildeInPath
            if expanded.hasPrefix("/") {
                candidate = URL(fileURLWithPath: expanded)
            } else {
                candidate = defaultRoot.appendingPathComponent(expanded)
            }
        }

        let standardizedCandidate = standardizedURL(candidate).resolvingSymlinksInPath()
        guard allowedRoots.contains(where: { allowedRoot in
            isSubpath(standardizedCandidate, containedIn: standardizedURL(allowedRoot).resolvingSymlinksInPath())
        }) else {
            return nil
        }

        return standardizedCandidate
    }

    private func isSubpath(_ candidate: URL, containedIn root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path == root.path || candidate.path.hasPrefix(rootPath)
    }

    private func standardizedURL(_ url: URL) -> URL {
        URL(fileURLWithPath: (url.path as NSString).standardizingPath)
    }


    private func isSensitivePathComponent(_ path: String) -> Bool {
        let lower = path.lowercased()
        let sensitiveNeedles = [
            "/.ssh", ".ssh/", "id_rsa", "id_ed25519", "private_key", "private-key",
            ".env", "keychain", "credentials", "secrets", "token", "apikey", "api_key"
        ]
        return sensitiveNeedles.contains { lower.contains($0) }
    }

    private func relativePath(for url: URL, root: URL) -> String {
        let rootPath = standardizedURL(root).path
        let path = standardizedURL(url).path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        if path.hasPrefix(prefix) {
            return String(path.dropFirst(prefix.count))
        }
        return path
    }

    private func parseISODate(_ text: String) -> Date? {
        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = full.date(from: text) { return date }

        let normal = ISO8601DateFormatter()
        normal.formatOptions = [.withInternetDateTime]
        if let date = normal.date(from: text) { return date }

        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.timeZone = TimeZone.current
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return localFormatter.date(from: text)
    }

    private func tokenizeReadOnlyCommand(_ command: String) -> [String]? {
        if command.range(of: #"[;&|><`$\\]"#, options: .regularExpression) != nil {
            return nil
        }

        var tokens: [String] = []
        var current = ""
        var quote: Character?

        for character in command {
            if character == "\"" || character == "'" {
                if quote == character {
                    quote = nil
                } else if quote == nil {
                    quote = character
                } else {
                    current.append(character)
                }
                continue
            }

            if character.isWhitespace, quote == nil {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        guard quote == nil else { return nil }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private func isAllowedReadOnlyCommand(_ tokens: [String]) -> Bool {
        guard let executable = tokens.first else { return false }
        let allowed: Set<String> = ["pwd", "ls", "find", "grep", "sed", "cat", "wc", "head", "tail", "git"]
        guard allowed.contains(executable) else { return false }

        let blockedTokens = [
            "rm", "mv", "cp", "mkdir", "rmdir", "touch", "chmod", "chown", "curl", "wget", "npm", "pnpm", "yarn",
            "pip", "python", "python3", "swift", "xcodebuild", "open", "osascript", "kill", "pkill", "sudo"
        ]
        if tokens.dropFirst().contains(where: { blockedTokens.contains($0.lowercased()) }) {
            return false
        }

        if executable == "git" {
            guard tokens.count >= 2 else { return false }
            let allowedGit: Set<String> = ["status", "diff", "log", "show", "branch"]
            return allowedGit.contains(tokens[1])
        }

        return true
    }

    private func validateReadOnlyCommandPaths(_ tokens: [String], root: URL) -> String? {
        for token in tokens.dropFirst() {
            let lower = token.lowercased()
            if token.hasPrefix("-") { continue }
            if ["status", "diff", "log", "show", "branch"].contains(lower) { continue }

            let isPathLike = isPathLikeReadOnlyToken(token, root: root)
            if isPathLike && isSensitivePathComponent(token) {
                return "Command touches a sensitive path or credential-like file."
            }
            if lower == ".." || lower.contains("../") || lower.contains("/..") {
                return "Command path traversal is not allowed."
            }
            if lower.hasPrefix("/") || lower.hasPrefix("~/") || lower.hasPrefix("~") {
                guard safeWorkspaceURL(token, root: root) != nil else {
                    return "Read-only commands may only inspect paths inside the current workspace."
                }
            }
        }
        return nil
    }

    private func isPathLikeReadOnlyToken(_ token: String, root: URL) -> Bool {
        let lower = token.lowercased()
        if lower.hasPrefix("/") || lower.hasPrefix("~/") || lower.hasPrefix("~") { return true }
        if lower.hasPrefix(".") || lower.contains("/") { return true }
        return FileManager.default.fileExists(atPath: root.appendingPathComponent(token).path)
    }

    private struct CommandResult {
        let exitStatus: Int32
        let stdout: String
        let stderr: String
    }

    private func runCommand(_ tokens: [String], workingDirectory: URL, timeoutSeconds: TimeInterval) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = tokens
        process.currentDirectoryURL = workingDirectory

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return CommandResult(exitStatus: 127, stdout: "", stderr: error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()

        let stdout = String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return CommandResult(exitStatus: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private func repairUnsupportedToolProtocolOutput(
        originalPrompt: String,
        badOutput: String,
        settings: GhostRunSettings,
        apiKey: String,
        endpoint: URL
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let messages: [[String: Any]] = [
            [
                "role": "system",
                "content": "You are Ghost. Return only clean user-visible Markdown. No hidden channels, no browser.run, no tool syntax, no JSON tool calls."
            ],
            [
                "role": "user",
                "content": """
                The previous response was an internal tool/protocol message instead of an answer.

                Original user request:
                \(originalPrompt)

                Bad model output:
                \(badOutput)

                Write the final answer directly. If the request needs unavailable tools, state that Ghost Agent mode is needed.
                """
            ]
        ]

        let body: [String: Any] = [
            "model": settings.model,
            "messages": messages,
            "max_tokens": settings.effortMode.maxTokens,
            "temperature": 0.2
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GhostClientError.commandFailed("No HTTP response from \(settings.provider.title) during repair.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = extractAPIErrorMessage(from: data) ?? String(data: data, encoding: .utf8) ?? ""
            throw GhostClientError.commandFailed("Repair request failed with HTTP \(http.statusCode): \(detail)")
        }
        guard let repaired = extractText(from: data, provider: settings.provider)?.trimmingCharacters(in: .whitespacesAndNewlines), !repaired.isEmpty else {
            throw GhostClientError.emptyResponse
        }
        guard !looksLikeUnsupportedToolProtocol(repaired) else {
            throw GhostClientError.commandFailed(
                "The local model kept returning internal tool-call protocol text. Try a normal instruct/chat model, or use Ghost Agent mode."
            )
        }
        return repaired
    }

    // MARK: - Optional provider-side web context

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

            Answer using the search results as source material. Prefer specific facts, dates, locations, numbers, and named sources. Cite sources inline as [1], [2], etc. End with `## References` listing every source you relied on with title and URL. If sources conflict, say so plainly.
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
        imageAttachment: GhostImageAttachment? = nil,
        settings: GhostRunSettings,
        apiKey: String,
        stream: Bool = false
    ) throws -> URLRequest {
        switch settings.provider {
        case .claude:
            return try anthropicRequest(prompt: prompt, imageAttachment: imageAttachment, settings: settings, apiKey: apiKey, stream: stream)
        case .gemini:
            return try geminiRequest(prompt: prompt, imageAttachment: imageAttachment, settings: settings, apiKey: apiKey)
        case .deepSeek:
            return try openAICompatibleRequest(
                prompt: prompt,
                imageAttachment: imageAttachment,
                settings: settings,
                apiKey: apiKey,
                endpoint: URL(string: "https://api.deepseek.com/v1/chat/completions")!,
                requiresKey: true,
                stream: stream
            )
        case .openCodeGo:
            return try openAICompatibleRequest(
                prompt: prompt,
                imageAttachment: imageAttachment,
                settings: settings,
                apiKey: apiKey,
                endpoint: openAICompatibleEndpoint(for: settings),
                requiresKey: true,
                stream: stream
            )
        case .lmStudio, .ollama:
            return try openAICompatibleRequest(
                prompt: prompt,
                imageAttachment: imageAttachment,
                settings: settings,
                apiKey: apiKey,
                endpoint: openAICompatibleEndpoint(for: settings),
                requiresKey: false,
                stream: stream
            )
        }
    }

    private func anthropicRequest(
        prompt: String,
        imageAttachment: GhostImageAttachment? = nil,
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
        var content: Any = prompt
        if let imageAttachment {
            content = [
                ["type": "text", "text": prompt],
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": imageAttachment.mimeType,
                        "data": imageAttachment.base64String
                    ]
                ]
            ]
        }

        var body: [String: Any] = [
            "model": settings.model,
            "max_tokens": settings.effortMode.maxTokens,
            "messages": [["role": "user", "content": content]]
        ]
        if stream {
            body["stream"] = true
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func geminiRequest(
        prompt: String,
        imageAttachment: GhostImageAttachment? = nil,
        settings: GhostRunSettings,
        apiKey: String
    ) throws -> URLRequest {
        try requireKey(apiKey, provider: settings.provider)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(settings.model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GhostClientError.commandFailed("Could not build Gemini request URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var parts: [[String: Any]] = [["text": prompt]]
        if let imageAttachment {
            parts.append([
                "inline_data": [
                    "mime_type": imageAttachment.mimeType,
                    "data": imageAttachment.base64String
                ]
            ])
        }
        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": ["maxOutputTokens": settings.effortMode.maxTokens]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func openAICompatibleUserContent(
        prompt: String,
        imageAttachment: GhostImageAttachment?
    ) -> Any {
        guard let imageAttachment else {
            return prompt
        }

        return [
            ["type": "text", "text": prompt],
            [
                "type": "image_url",
                "image_url": [
                    "url": imageAttachment.dataURLString
                ]
            ]
        ]
    }

    private func openAICompatibleRequest(
        prompt: String,
        imageAttachment: GhostImageAttachment? = nil,
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

        let messages: [[String: Any]]
        if usesLocalOpenAIToolLoop(settings.provider) {
            messages = [
                ["role": "system", "content": localToolSystemPrompt(outputDirectory: settings.documentOutputDirectory.path, ragEnabled: settings.ragEnabled)],
                ["role": "user", "content": openAICompatibleUserContent(prompt: prompt, imageAttachment: imageAttachment)]
            ]
        } else {
            messages = [["role": "user", "content": openAICompatibleUserContent(prompt: prompt, imageAttachment: imageAttachment)]]
        }

        var body: [String: Any] = [
            "model": settings.model,
            "max_tokens": settings.effortMode.maxTokens,
            "messages": messages,
            "temperature": 0.2
        ]
        if stream {
            body["stream"] = true
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func openAICompatibleEndpoint(for settings: GhostRunSettings) throws -> URL {
        switch settings.provider {
        case .lmStudio:
            return URL(string: "http://localhost:1234/v1/chat/completions")!
        case .ollama:
            let base = settings.ollamaBaseURL.absoluteString
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let endpoint = URL(string: "\(base)/v1/chat/completions") else {
                throw GhostClientError.commandFailed("Could not build Ollama request URL.")
            }
            return endpoint
        case .deepSeek:
            return URL(string: "https://api.deepseek.com/v1/chat/completions")!
        case .openCodeGo:
            return URL(string: "https://opencode.ai/zen/go/v1/chat/completions")!
        case .claude, .gemini:
            throw GhostClientError.commandFailed("\(settings.provider.title) does not use the OpenAI-compatible endpoint builder.")
        }
    }

    private func supportsStreaming(_ provider: GhostProvider) -> Bool {
        switch provider {
        case .claude, .deepSeek, .openCodeGo:
            true
        case .lmStudio, .ollama, .gemini:
            false
        }
    }

    private func usesLocalOpenAIToolLoop(_ provider: GhostProvider) -> Bool {
        switch provider {
        case .lmStudio, .ollama:
            true
        case .claude, .gemini, .deepSeek, .openCodeGo:
            false
        }
    }

    private func directAPIDetail(for provider: GhostProvider) -> String {
        if usesLocalOpenAIToolLoop(provider) {
            return "Using provider HTTP API directly. Local models get Ghost-managed tool_calls for web, workspace files, text-file creation, read-only commands, and simple reminders; broad computer actions still route to Ghost Agent."
        }
        return "Using provider HTTP API directly. Search prompts get lightweight web context; computer actions still require Ghost Agent mode."
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
        case .deepSeek, .lmStudio, .ollama, .openCodeGo:
            guard
                let choices = json["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any]
            else { return nil }
            return message["content"] as? String
        }
    }

    private func openAIMessage(from data: Data) -> [String: Any]? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let message = first["message"] as? [String: Any]
        else {
            return nil
        }
        return message
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

        case .deepSeek, .lmStudio, .ollama, .openCodeGo:
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

    // MARK: - JSON and protocol guards


    private func normalizedJSONFallbackActionName(_ name: String) -> String {
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch lower {
        case "create_file", "write_file": return "ghost_write_file"
        case "update_file": return "ghost_update_file"
        case "create_markdown": return "ghost_create_markdown"
        case "create_html": return "ghost_create_html"
        case "create_txt", "create_text": return "ghost_create_txt"
        case "create_csv": return "ghost_create_csv"
        case "create_json": return "ghost_create_json"
        case "create_pdf": return "ghost_create_pdf"
        case "create_docx": return "ghost_create_docx"
        case "create_pptx": return "ghost_create_pptx"
        case "create_xlsx": return "ghost_create_xlsx"
        case "list_directory": return "ghost_list_directory"
        case "read_file": return "ghost_read_file"
        case "search_files": return "ghost_search_files"
        default: return lower.hasPrefix("ghost_") ? lower : "ghost_\(lower)"
        }
    }

    private func isSupportedJSONFallbackAction(_ name: String) -> Bool {
        let normalized = normalizedJSONFallbackActionName(name)
        let supported: Set<String> = [
            "ghost_list_directory", "ghost_get_file_info", "ghost_read_file", "ghost_search_files",
            "ghost_write_file", "ghost_update_file", "ghost_create_folder", "ghost_copy_file", "ghost_move_file",
            "ghost_open_file", "ghost_reveal_in_finder", "ghost_create_markdown", "ghost_create_html",
            "ghost_create_txt", "ghost_create_csv", "ghost_create_json", "ghost_create_pdf", "ghost_create_docx",
            "ghost_create_pptx", "ghost_create_xlsx", "ghost_convert_file"
        ]
        // Deletion and shell execution are intentionally excluded from JSON fallback.
        return supported.contains(normalized)
    }

    private func jsonDictionary(from text: String) -> [String: Any] {
        guard
            let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        return object
    }

    private func jsonString(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else {
            return "\(object)"
        }
        return text
    }

    private func looksLikeUnsupportedToolProtocol(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("<|channel|>")
            || lower.contains("<|message|>")
            || lower.contains("analysis to=")
            || lower.contains("to=browser.run")
            || lower.contains("browser.run code")
            || lower.contains("browser.run")
            || lower.contains("<tool_call>")
            || lower.contains("</tool_call>")
            || lower.contains("[tool_request]")
            || lower.contains("\"tool_calls\"")
            || lower.contains("\"function_call\"")
    }

    private func looksLikeFakeFileResponse(_ text: String) -> Bool {
        let lower = text.lowercased()
        let fakePhrases = [
            "here is the", "i have created", "i've created", "i created",
            "saved as", "written to", "saved to", "file has been",
            "file is saved", "i saved", "i wrote", "i generated",
            "file is located", "you can find", "check your desktop",
            "on your desktop", "in your workspace", "i made a"
        ]
        let hasFakeClaim = fakePhrases.contains { lower.contains($0) }
        let hasRealFilePath = text.contains("/") || text.contains("~/")
        let hasCodeBlock = text.contains("```")
        return hasFakeClaim && !hasRealFilePath && !hasCodeBlock
    }
}


private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
