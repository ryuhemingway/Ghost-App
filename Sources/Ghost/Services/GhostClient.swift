import Foundation

enum LocalAgentKind: String, CaseIterable, Identifiable, Sendable {
    case ghost
    case hermes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ghost:
            "Ghost Agent"
        case .hermes:
            "Hermes Agent"
        }
    }

    var executableName: String {
        switch self {
        case .ghost:
            "ghost"
        case .hermes:
            "hermes"
        }
    }

    var defaultExecutablePath: String {
        switch self {
        case .ghost:
            return "\(NSHomeDirectory())/.local/bin/ghost"
        case .hermes:
            return "\(NSHomeDirectory())/.local/bin/hermes"
        }
    }
}

final class LockedTextBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = ""

    func append(_ value: String) {
        lock.lock()
        storage += value
        lock.unlock()
    }

    var value: String {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class ProcessStreamToken: @unchecked Sendable {
    private let handle: FileHandle
    private let outputBuffer: LockedTextBuffer
    private let kind: GhostActivityEntry.Kind
    private let title: String
    private let onActivity: @Sendable (GhostActivityEntry) -> Void
    private let lock = NSLock()
    private var isStopped = false

    init(
        pipe: Pipe,
        kind: GhostActivityEntry.Kind,
        title: String,
        outputBuffer: LockedTextBuffer,
        onActivity: @escaping @Sendable (GhostActivityEntry) -> Void
    ) {
        self.handle = pipe.fileHandleForReading
        self.kind = kind
        self.title = title
        self.outputBuffer = outputBuffer
        self.onActivity = onActivity
    }

    func start() {
        handle.readabilityHandler = { [weak self] fileHandle in
            guard let self else { return }

            let data = fileHandle.availableData

            guard !data.isEmpty else {
                return
            }

            let text = String(decoding: data, as: UTF8.self)
            self.outputBuffer.append(text)

            self.onActivity(
                GhostActivityEntry(
                    kind: self.kind,
                    title: self.title,
                    detail: text
                )
            )
        }
    }

    func stopAndFlush() {
        lock.lock()
        if isStopped {
            lock.unlock()
            return
        }

        isStopped = true
        lock.unlock()

        handle.readabilityHandler = nil

        let remaining = handle.availableData

        guard !remaining.isEmpty else {
            return
        }

        let text = String(decoding: remaining, as: UTF8.self)
        outputBuffer.append(text)

        onActivity(
            GhostActivityEntry(
                kind: kind,
                title: title,
                detail: text
            )
        )
    }
}

struct GhostRunResult: Sendable {
    let output: String
    let launchedArguments: [String]
    let provider: GhostProvider
    let model: String
    let effortMode: EffortMode
    let maxTurns: Int
    let maxTokens: Int
    let reasoningEffort: String
    let workingDirectory: String
    let exitStatus: Int32
}

struct GhostClient: Sendable {
    var fallbackExecutableURL: URL {
        URL(fileURLWithPath: LocalAgentKind.ghost.defaultExecutablePath)
    }

    func send(
        _ prompt: String,
        settings: GhostRunSettings,
        onActivity: (@Sendable (GhostActivityEntry) -> Void)? = nil
    ) async throws -> GhostRunResult {
        guard !settings.provider.isLocal else {
            throw GhostClientError.commandFailed(
                "Provider isolation blocked Agent launch: \(settings.provider.title) is selected, so Ghost must use the local Direct API tool loop instead of Hermes/Ghost Agent. This prevents accidental DeepSeek calls."
            )
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        let stdoutBuffer = LockedTextBuffer()
        let stderrBuffer = LockedTextBuffer()

        let agentURL = settings.agentExecutableURL
        guard FileManager.default.isExecutableFile(atPath: agentURL.path) else {
            throw GhostClientError.launchFailed(
                "\(settings.agentKind.title) is not connected. Install Hermes Agent, choose its binary, or switch to Direct API mode."
            )
        }

        process.executableURL = agentURL
        var arguments: [String]

        switch settings.agentKind {
        case .ghost:
            arguments = [
                "chat",
                "-q", prompt,
                "-Q",
                "--provider", settings.provider.ghostProvider,
                "-m", settings.model,
                "--max-turns", String(settings.effortMode.maxTurns)
            ]

            if settings.approvalMode == .yolo {
                arguments.append("--yolo")
            } else if settings.approvalMode == .safeAuto {
                arguments.append("--accept-hooks")
            }

            if !settings.toolsets.isEmpty {
                arguments.append(contentsOf: ["--toolsets", settings.toolsets])
            }

        case .hermes:
            arguments = []

            if settings.approvalMode == .yolo {
                arguments.append("--yolo")
            }

            arguments.append(contentsOf: [
                "chat",
                "-q", prompt,
                "-Q"
            ])

            let modelArgument = hermesModelArgument(for: settings)
            if !modelArgument.isEmpty {
                arguments.append(contentsOf: ["-m", modelArgument])
            }

            if !settings.toolsets.isEmpty {
                arguments.append(contentsOf: ["--toolsets", settings.toolsets])
            }
        }
        let launchedArgs = arguments
        let environment = ghostEnvironment(settings: settings)
        try validateProviderIsolation(settings: settings, arguments: arguments, environment: environment)

        process.arguments = arguments
        process.currentDirectoryURL = settings.workingDirectory
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = environment
        onActivity?(
            GhostActivityEntry(
                kind: .command,
                title: "Starting \(settings.agentKind.title)",
                detail: "\(settings.provider.title) · \(settings.model) · \(settings.effortMode.title(for: settings.provider))"
            )
        )
        onActivity?(
            GhostActivityEntry(
                kind: .info,
                title: "Provider: \(settings.provider.title)",
                detail: settings.provider.ghostProvider
            )
        )
        onActivity?(
            GhostActivityEntry(
                kind: .info,
                title: "Model: \(settings.model)",
                detail: ""
            )
        )
        onActivity?(
            GhostActivityEntry(
                kind: .info,
                title: "Effort: \(settings.effortMode.title(for: settings.provider))",
                detail: "Reasoning: \(settings.effortMode.ghostReasoningEffort)"
            )
        )
        onActivity?(
            GhostActivityEntry(
                kind: .info,
                title: "Max turns: \(settings.effortMode.maxTurns)",
                detail: "Max tokens: \(settings.effortMode.maxTokens)"
            )
        )
        onActivity?(
            GhostActivityEntry(
                kind: .info,
                title: "Approval: \(settings.approvalMode.title)",
                detail: ""
            )
        )
        onActivity?(
            GhostActivityEntry(
                kind: .info,
                title: "Working directory",
                detail: settings.workingDirectory.path
            )
        )

        let onActivitySend = onActivity ?? { _ in }

        let stdoutStream = ProcessStreamToken(
            pipe: stdoutPipe,
            kind: .output,
            title: "",
            outputBuffer: stdoutBuffer,
            onActivity: onActivitySend
        )

        let stderrStream = ProcessStreamToken(
            pipe: stderrPipe,
            kind: .error,
            title: "",
            outputBuffer: stderrBuffer,
            onActivity: onActivitySend
        )

        stdoutStream.start()
        stderrStream.start()

        do {
            try configureGhostIfNeeded(settings: settings)
            try process.run()
            onActivity?(
                GhostActivityEntry(
                    kind: .command,
                    title: "\(settings.agentKind.title) started",
                    detail: process.executableURL?.path ?? ""
                )
            )
        } catch {
            throw GhostClientError.launchFailed(error.localizedDescription)
        }

        let exitStatus = await waitForProcessExit(process)

        stdoutStream.stopAndFlush()
        stderrStream.stopAndFlush()

        let stdout = stdoutBuffer.value
        let stderr = stderrBuffer.value

        let trimmedOutput = cleanedGhostOutput(stdout)
        let trimmedError = stderr.trimmingCharacters(in: .whitespacesAndNewlines)

        if exitStatus == 0 {
            let launchLine = "Launched with: \(settings.agentKind.executableName) \(launchedArgs.joined(separator: " "))"
            onActivity?(
                GhostActivityEntry(kind: .success, title: "\(settings.agentKind.title) finished", detail: "Exit status \(exitStatus)")
            )
            onActivity?(
                GhostActivityEntry(kind: .info, title: "Command", detail: launchLine)
            )
            return GhostRunResult(
                output: trimmedOutput,
                launchedArguments: launchedArgs,
                provider: settings.provider,
                model: settings.model,
                effortMode: settings.effortMode,
                maxTurns: settings.effortMode.maxTurns,
                maxTokens: settings.effortMode.maxTokens,
                reasoningEffort: settings.effortMode.ghostReasoningEffort,
                workingDirectory: settings.workingDirectory.path,
                exitStatus: exitStatus
            )
        } else {
            let message = trimmedError.isEmpty ? "Ghost exited with status \(exitStatus)." : trimmedError
            onActivity?(
                GhostActivityEntry(kind: .error, title: "\(settings.agentKind.title) failed", detail: message)
            )
            throw GhostClientError.commandFailed(message)
        }
    }

    func cancelRunningMenuRuns() {
        for processName in ["ghost", "hermes"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            process.arguments = [
                "-P",
                String(ProcessInfo.processInfo.processIdentifier),
                "-f",
                processName
            ]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()
        }
    }

    private func waitForProcessExit(_ process: Process) async -> Int32 {
        await withCheckedContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
        }
    }

    /// Hermes/OpenCode-style agents often infer the provider from the model
    /// string. The selected Ghost provider is the source of truth, so we always
    /// scope the model to that provider before launching Hermes. This is
    /// especially important for local model ids such as `google/gemma-4-e4b` or
    /// `qwen/qwen3.6-35b-a3b`: those slashes are part of the local model name,
    /// not a request to use Google/Qwen as a remote provider.
    private func hermesModelArgument(for settings: GhostRunSettings) -> String {
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { return "" }

        switch settings.provider {
        case .lmStudio:
            return forceProviderScopedModel(model, prefix: "lmstudio")

        case .ollama:
            return forceProviderScopedModel(model, prefix: "ollama")

        case .claude:
            return providerScopedModel(
                model,
                preferredPrefix: "anthropic",
                acceptedPrefixes: settings.provider.acceptedAgentModelPrefixes
            )

        case .gemini:
            return providerScopedModel(
                model,
                preferredPrefix: "gemini",
                acceptedPrefixes: settings.provider.acceptedAgentModelPrefixes
            )

        case .deepSeek:
            // DeepSeek's API expects bare model names such as deepseek-v4-pro.
            // Keep them unprefixed so DeepSeek runs continue to work.
            return model.removingProviderPrefix("deepseek")
        }
    }

    private func forceProviderScopedModel(_ model: String, prefix: String) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let wantedPrefix = prefix.lowercased() + "/"
        if trimmed.lowercased().hasPrefix(wantedPrefix) {
            return trimmed
        }

        return "\(prefix)/\(trimmed)"
    }

    private func providerScopedModel(
        _ model: String,
        preferredPrefix: String,
        acceptedPrefixes: [String]
    ) -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if acceptedPrefixes.contains(where: { lower.hasPrefix($0.lowercased() + "/") }) {
            return trimmed
        }

        return "\(preferredPrefix)/\(trimmed)"
    }

    private func validateProviderIsolation(
        settings: GhostRunSettings,
        arguments: [String],
        environment: [String: String]
    ) throws {
        if settings.provider != .deepSeek {
            let leakedDeepSeekValues = [
                "DEEPSEEK_API_KEY",
                "DEEPSEEK_BASE_URL",
                "DEEPSEEK_API_BASE",
                "DEEPSEEK_API_URL",
                "DEEPSEEK_ENDPOINT",
                "DEEPSEEK_MODEL"
            ].filter { key in
                environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }

            if !leakedDeepSeekValues.isEmpty {
                throw GhostClientError.commandFailed(
                    "Provider isolation blocked a run before launch: \(settings.provider.title) was selected, but DeepSeek environment keys were still present (\(leakedDeepSeekValues.joined(separator: ", ")))."
                )
            }
        }

        switch settings.agentKind {
        case .ghost:
            if let providerArgument = value(after: "--provider", in: arguments),
               providerArgument.lowercased() != settings.provider.ghostProvider.lowercased() {
                throw GhostClientError.commandFailed(
                    "Provider isolation blocked a run before launch: Ghost Agent provider was `\(providerArgument)`, but the selected provider is `\(settings.provider.ghostProvider)`."
                )
            }

        case .hermes:
            guard let modelArgument = value(after: "-m", in: arguments) else {
                return
            }

            let lowerModel = modelArgument.lowercased()
            let acceptedPrefixes = settings.provider.acceptedAgentModelPrefixes
            let hasAcceptedPrefix = acceptedPrefixes.contains { prefix in
                lowerModel.hasPrefix(prefix.lowercased() + "/")
            }

            switch settings.provider {
            case .deepSeek:
                // DeepSeek Hermes runs may use a bare DeepSeek model or a deepseek/ prefix.
                return

            case .lmStudio, .ollama, .claude, .gemini:
                if !hasAcceptedPrefix {
                    throw GhostClientError.commandFailed(
                        "Provider isolation blocked a run before launch: \(settings.provider.title) was selected, but Hermes would have launched model `\(modelArgument)`. Expected prefix: \(acceptedPrefixes.map { $0 + "/" }.joined(separator: " or "))."
                    )
                }

                if lowerModel.hasPrefix("deepseek/") || lowerModel == "deepseek-v4-pro" || lowerModel == "deepseek-v4-flash" {
                    throw GhostClientError.commandFailed(
                        "Provider isolation blocked a run before launch: \(settings.provider.title) was selected, but Hermes would have launched DeepSeek model `\(modelArgument)`."
                    )
                }
            }
        }
    }

    private func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let next = arguments.index(after: index)
        guard next < arguments.endIndex else { return nil }
        return arguments[next]
    }

    private func ghostEnvironment(settings: GhostRunSettings) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        scrubInferenceEnvironment(&environment, selectedProvider: settings.provider)

        environment["HOME"] = NSHomeDirectory()
        environment["PATH"] = [
            "\(NSHomeDirectory())/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")
        environment["GHOST_HOME"] = "\(NSHomeDirectory())/.ghost"
        environment["GHOST_CWD"] = settings.workingDirectory.path
        environment["TERMINAL_CWD"] = settings.workingDirectory.path
        environment["GHOST_INFERENCE_PROVIDER"] = settings.provider.ghostProvider
        environment["GHOST_SELECTED_PROVIDER"] = settings.provider.ghostProvider
        environment["GHOST_EXPECTED_PROVIDER"] = settings.provider.ghostProvider
        environment["GHOST_INFERENCE_MODEL"] = settings.model
        environment["GHOST_MODEL"] = settings.model
        environment["GHOST_MAX_ITERATIONS"] = String(settings.effortMode.maxTurns)
        environment["GHOST_MAX_TOKENS"] = String(settings.effortMode.maxTokens)
        environment["GHOST_MENU_EFFORT"] = settings.effortMode.rawValue

        for (key, value) in scopedAPIKeys(settings.apiKeys, selectedProvider: settings.provider) {
            environment[key] = value
        }

        switch settings.provider {
        case .lmStudio:
            let lmStudioHost = "http://localhost:1234"
            environment["GHOST_MENU_LOCAL_CONTEXT_WINDOW"] = String(settings.localContextWindow)
            environment["GHOST_LOCAL_MODEL_PROVIDER"] = settings.provider.ghostProvider
            environment["GHOST_LOCAL_MODEL"] = settings.model
            environment["LMSTUDIO_HOST"] = lmStudioHost
            environment["LMSTUDIO_BASE_URL"] = lmStudioHost
            environment["OPENAI_BASE_URL"] = "\(lmStudioHost)/v1"
            environment["OPENAI_API_KEY"] = "lm-studio"

        case .ollama:
            let ollamaHost = settings.ollamaBaseURL.absoluteString
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            environment["GHOST_MENU_LOCAL_CONTEXT_WINDOW"] = String(settings.localContextWindow)
            environment["GHOST_LOCAL_MODEL_PROVIDER"] = settings.provider.ghostProvider
            environment["GHOST_LOCAL_MODEL"] = settings.model
            environment["OLLAMA_HOST"] = ollamaHost
            environment["OLLAMA_BASE_URL"] = ollamaHost
            environment["OPENAI_BASE_URL"] = "\(ollamaHost)/v1"
            environment["OPENAI_API_KEY"] = "ollama"

        case .claude, .gemini, .deepSeek:
            break
        }

        scrubInferenceEnvironment(&environment, selectedProvider: settings.provider)
        restoreSelectedLocalEndpointIfNeeded(&environment, settings: settings)
        return environment
    }

    private func scrubInferenceEnvironment(_ environment: inout [String: String], selectedProvider: GhostProvider) {
        let allowedKeys = allowedInferenceKeys(for: selectedProvider)
        for key in allInferenceEnvironmentKeys where !allowedKeys.contains(key) {
            environment.removeValue(forKey: key)
        }

        if selectedProvider != .lmStudio {
            environment.removeValue(forKey: "LMSTUDIO_HOST")
            environment.removeValue(forKey: "LMSTUDIO_BASE_URL")
        }

        if selectedProvider != .ollama {
            environment.removeValue(forKey: "OLLAMA_HOST")
            environment.removeValue(forKey: "OLLAMA_BASE_URL")
        }
    }

    private func restoreSelectedLocalEndpointIfNeeded(
        _ environment: inout [String: String],
        settings: GhostRunSettings
    ) {
        switch settings.provider {
        case .lmStudio:
            let lmStudioHost = "http://localhost:1234"
            environment["LMSTUDIO_HOST"] = lmStudioHost
            environment["LMSTUDIO_BASE_URL"] = lmStudioHost
            environment["OPENAI_BASE_URL"] = "\(lmStudioHost)/v1"
            environment["OPENAI_API_KEY"] = "lm-studio"

        case .ollama:
            let ollamaHost = settings.ollamaBaseURL.absoluteString
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            environment["OLLAMA_HOST"] = ollamaHost
            environment["OLLAMA_BASE_URL"] = ollamaHost
            environment["OPENAI_BASE_URL"] = "\(ollamaHost)/v1"
            environment["OPENAI_API_KEY"] = "ollama"

        case .claude, .gemini, .deepSeek:
            break
        }
    }

    private func scopedAPIKeys(
        _ apiKeys: [String: String],
        selectedProvider: GhostProvider
    ) -> [String: String] {
        let allowedKeys = allowedInferenceKeys(for: selectedProvider)
        var scoped: [String: String] = [:]
        for (key, value) in apiKeys {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard allowedKeys.contains(key), !trimmed.isEmpty else { continue }
            scoped[key] = trimmed
        }
        return scoped
    }

    private func allowedInferenceKeys(for provider: GhostProvider) -> Set<String> {
        switch provider {
        case .lmStudio:
            // LM Studio is local. Use its OpenAI-compatible localhost endpoint,
            // never a user's cloud OpenAI or DeepSeek key.
            return ["OPENAI_API_KEY", "OPENAI_BASE_URL"]

        case .ollama:
            // Ollama is local. Keep only the local OpenAI-compatible shim and
            // optional Ollama Cloud key if the user's Ollama setup needs it.
            return ["OPENAI_API_KEY", "OPENAI_BASE_URL", "OLLAMA_API_KEY"]

        case .claude:
            return ["ANTHROPIC_API_KEY"]

        case .gemini:
            return ["GEMINI_API_KEY", "GOOGLE_API_KEY"]

        case .deepSeek:
            return ["DEEPSEEK_API_KEY"]
        }
    }

    private var allInferenceEnvironmentKeys: Set<String> {
        [
            "ANTHROPIC_API_KEY",
            "GEMINI_API_KEY",
            "GOOGLE_API_KEY",
            "DEEPSEEK_API_KEY",
            "DEEPSEEK_BASE_URL",
            "DEEPSEEK_API_BASE",
            "DEEPSEEK_API_URL",
            "DEEPSEEK_ENDPOINT",
            "DEEPSEEK_MODEL",
            "OPENAI_API_KEY",
            "OPENAI_BASE_URL",
            "OPENROUTER_API_KEY",
            "GROQ_API_KEY",
            "XAI_API_KEY",
            "MISTRAL_API_KEY",
            "TOGETHER_API_KEY",
            "FIREWORKS_API_KEY",
            "NVIDIA_API_KEY",
            "MOONSHOT_API_KEY",
            "OLLAMA_API_KEY"
        ]
    }

    private func configureGhostIfNeeded(settings: GhostRunSettings) throws {
        guard settings.agentKind == .ghost else { return }
        try runGhostConfigSet(key: "agent.reasoning_effort", value: settings.effortMode.ghostReasoningEffort)
        if settings.provider == .lmStudio || settings.provider == .ollama {
            try runGhostConfigSet(key: "model.context_length", value: String(settings.localContextWindow))
        }
    }

    private func runGhostConfigSet(key: String, value: String) throws {
        let process = Process()
        process.executableURL = fallbackExecutableURL
        process.arguments = ["config", "set", key, value]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        process.environment = ghostEnvironment(
            settings: GhostRunSettings(
                provider: .lmStudio,
                model: "",
                localContextWindow: 65_536,
                workingDirectory: FileManager.default.homeDirectoryForCurrentUser,
                apiKeys: [:],
                approvalMode: .ask,
                toolsets: "",
                effortMode: .low,
                ollamaBaseURL: URL(string: "http://localhost:11434")!,
                agentKind: .ghost,
                agentExecutableURL: fallbackExecutableURL
            )
        )

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw GhostClientError.commandFailed("Could not update Ghost \(key).")
        }
    }

    private func cleanedGhostOutput(_ outputText: String) -> String {
        outputText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("session_id:") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct GhostRunSettings: Sendable {
    let provider: GhostProvider
    let model: String
    let localContextWindow: Int
    let workingDirectory: URL
    let apiKeys: [String: String]
    let approvalMode: ApprovalMode
    let toolsets: String
    let effortMode: EffortMode
    let ollamaBaseURL: URL
    let agentKind: LocalAgentKind
    let agentExecutableURL: URL
}

enum GhostClientError: LocalizedError {
    case launchFailed(String)
    case commandFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            "Could not launch Ghost: \(message)"
        case .commandFailed(let message):
            message
        case .emptyResponse:
            "Ghost finished but returned no text. Try Low or Medium effort, or check Ghost logs for the completed session."
        }
    }
}

private extension String {
    func removingProviderPrefix(_ prefix: String) -> String {
        let wanted = prefix.lowercased() + "/"
        if lowercased().hasPrefix(wanted) {
            return String(dropFirst(wanted.count))
        }
        return self
    }
}

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func snapshot() -> Data {
        lock.lock()
        let copy = data
        lock.unlock()
        return copy
    }
}
