import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class GhostConversationStore {
    enum PanelMode {
        case chat
        case settings
    }

    enum OnboardingStep: String, CaseIterable, Identifiable {
        case welcome
        case connect
        case personalize
        case learn
        case rag

        var id: String { rawValue }

        var title: String {
            switch self {
            case .welcome:
                "Welcome"
            case .connect:
                "Connect"
            case .personalize:
                "Personalize"
            case .learn:
                "Use Ghost"
            case .rag:
                "RAG Index"
            }
        }

        var systemImage: String {
            switch self {
            case .welcome:
                "sparkles"
            case .connect:
                "network"
            case .personalize:
                "slider.horizontal.3"
            case .learn:
                "keyboard"
            case .rag:
                "doc.text.magnifyingglass"
            }
        }
    }

    var isOnboardingPresented = false
    var onboardingStep: OnboardingStep = .welcome

    var prompt = ""
    var queuedQuickAskPrompt: String?
    var panelMode: PanelMode = .chat
    var effortMode: EffortMode {
        didSet {
            UserDefaults.standard.set(effortMode.rawValue, forKey: Self.effortModeDefaultsKey)
        }
    }
    var approvalMode: ApprovalMode {
        didSet {
            UserDefaults.standard.set(approvalMode.rawValue, forKey: Self.approvalModeDefaultsKey)
        }
    }
    var includeClipboard: Bool {
        didSet {
            UserDefaults.standard.set(includeClipboard, forKey: Self.includeClipboardDefaultsKey)
        }
    }
    var toolsets: String {
        didSet {
            UserDefaults.standard.set(toolsets, forKey: Self.toolsetsDefaultsKey)
        }
    }

    var useHermesAgent: Bool {
        didSet {
            UserDefaults.standard.set(useHermesAgent, forKey: Self.useHermesAgentDefaultsKey)
        }
    }

    var hermesExecutablePath: String {
        didSet {
            UserDefaults.standard.set(hermesExecutablePath, forKey: Self.hermesExecutablePathDefaultsKey)
        }
    }

    var detectedHermesPath: String?
    var isCheckingHermes = false
    var hermesStatusMessage: String?
    /// This is the actual engine chosen for the current/last run.
    /// Do not persist this. Auto routing updates this per prompt.
    var executionEngine: ExecutionEngine = .ghostAgent

    var enginePreference: EnginePreference {
        didSet {
            UserDefaults.standard.set(enginePreference.rawValue, forKey: Self.enginePreferenceDefaultsKey)
        }
    }
    var interfacePreference: GhostInterfacePreference {
        didSet {
            UserDefaults.standard.set(interfacePreference.rawValue, forKey: Self.interfacePreferenceDefaultsKey)
        }
    }

    var interfaceMode: GhostInterfaceMode = .glass

    var visibleInterfaceMode: GhostInterfaceMode {
        switch interfacePreference {
        case .glass:
            return .glass
        case .terminal:
            return .terminal
        case .adaptive:
            return interfaceMode
        }
    }
    var panelSizeMode: GhostPanelSizeMode {
        didSet {
            UserDefaults.standard.set(panelSizeMode.rawValue, forKey: Self.panelSizeModeDefaultsKey)
        }
    }
    var codeAgentMode: GhostCodeAgentMode {
        didSet {
            UserDefaults.standard.set(codeAgentMode.rawValue, forKey: Self.codeAgentModeDefaultsKey)
        }
    }
    var ghostCodeOutputMode: GhostCodeOutputMode {
        didSet {
            UserDefaults.standard.set(ghostCodeOutputMode.rawValue, forKey: Self.ghostCodeOutputModeDefaultsKey)
        }
    }
    var selectedProvider: GhostProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: Self.providerDefaultsKey)
            if selectedProvider == .ollama {
                refreshOllamaModels()
            } else if selectedProvider == .openCodeGo {
                refreshOpenCodeGoModels()
            }
        }
    }
    var selectedLocalModel: String {
        didSet {
            UserDefaults.standard.set(selectedLocalModel, forKey: Self.localModelDefaultsKey)
        }
    }

    var selectedOllamaModel: String {
        didSet {
            UserDefaults.standard.set(selectedOllamaModel, forKey: Self.ollamaModelDefaultsKey)
        }
    }

    var ollamaBaseURLString: String {
        didSet {
            UserDefaults.standard.set(ollamaBaseURLString, forKey: Self.ollamaBaseURLDefaultsKey)
        }
    }

    var ollamaModels: [LocalModel] = []
    var isRefreshingOllamaModels = false
    var selectedOpenCodeGoModel: String {
        didSet {
            UserDefaults.standard.set(selectedOpenCodeGoModel, forKey: Self.openCodeGoModelDefaultsKey)
        }
    }
    var openCodeGoModels: [LocalModel] = []
    var isRefreshingOpenCodeGoModels = false
    var selectedDeepSeekModel: String {
        didSet {
            UserDefaults.standard.set(selectedDeepSeekModel, forKey: Self.deepSeekModelDefaultsKey)
        }
    }
    var localContextWindow: Int {
        didSet {
            localContextWindow = min(max(localContextWindow, 4_096), 1_000_000)
            UserDefaults.standard.set(localContextWindow, forKey: Self.localContextDefaultsKey)
        }
    }
    var workingDirectoryPath: String {
        didSet {
            UserDefaults.standard.set(workingDirectoryPath, forKey: Self.workingDirectoryDefaultsKey)
        }
    }
    var documentOutputDirectoryPath: String {
        didSet {
            UserDefaults.standard.set(documentOutputDirectoryPath, forKey: Self.documentOutputDirectoryDefaultsKey)
            ensureDocumentOutputDirectory()
        }
    }
    var ragRootPath: String {
        didSet {
            UserDefaults.standard.set(ragRootPath, forKey: Self.ragRootDefaultsKey)
            if isRAGEnabled {
                desktopRAGWatcher.stop()
                startDesktopRAGWatcher()
            }
        }
    }
    var isRAGEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isRAGEnabled, forKey: Self.ragEnabledDefaultsKey)
            if isRAGEnabled {
                startDesktopRAGWatcher()
                syncSelectedRAGFolder(reason: "enabled")
            } else {
                desktopRAGWatcher.stop()
            }
        }
    }
    var isPersistentWindow: Bool {
        didSet {
            UserDefaults.standard.set(isPersistentWindow, forKey: Self.persistentWindowDefaultsKey)
        }
    }
    var terminalTheme: GhostTerminalTheme {
        didSet {
            UserDefaults.standard.set(terminalTheme.rawValue, forKey: Self.terminalThemeDefaultsKey)
        }
    }
    var localModels: [LocalModel] = []
    var isRefreshingLocalModels = false
    var settingsMessage: String?
    var apiKeyDrafts: [ProviderAPIKey: String] = [:]
    var savedAPIKeyProviders: Set<ProviderAPIKey> = []
    var recentPrompts: [String] = []
    var taskQueue: [QueuedHarnessTask] = []
    var isRunningQueue = false
    var messages: [GhostMessage] = []
    var activityEntries: [GhostActivityEntry] = []
    var isActivityVisible = false
    var isDocumentStudioVisible = false
    var producedDocuments: [GhostProducedDocument] = [] {
        didSet {
            persistProducedDocuments()
        }
    }
    var isPinnedToBottom = true
    var isScrolledAwayFromBottom: Bool { !isPinnedToBottom && !messages.isEmpty }

    // MARK: - Conversation history & prompt library
    var conversations: [PersistedConversation] = []
    var currentConversationID: UUID?
    var isHistoryVisible = false
    var isPromptLibraryVisible = false
    var savedPrompts: [SavedPrompt] = []
    private let historyStore = GhostHistoryStore()
    private let promptLibrary = GhostPromptLibrary()
    private var persistenceDebounceTask: Task<Void, Never>?
    var isTerminalToolDetailsVisible = true {
        didSet {
            UserDefaults.standard.set(isTerminalToolDetailsVisible, forKey: Self.terminalToolDetailsDefaultsKey)
        }
    }
    var isTaskVerificationEnabled = true {
        didSet {
            UserDefaults.standard.set(isTaskVerificationEnabled, forKey: Self.taskVerificationDefaultsKey)
        }
    }
    var isSending = false
    var activeRunStartedAt: Date?
    var currentIntent: GhostDetectedIntent = .idle
    var activeContextChips: [GhostContextChip] = []

    var taskTimeline: GhostTaskTimeline = .idle
    var taskTimelineAnchorMessageID: GhostMessage.ID?

    var lastTaskContext: GhostTaskContext?
    var pendingImageAttachment: GhostImageAttachment?

    private var progressMarkerBuffer = ""
    private var ghostFallbackOutputTicks = 0
    private var lastTimelineAutoAdvanceAt: Date?

    var ghostOrbState: GhostOrbState {
        if isSending {
            if currentIntent.kind == .createArtifact {
                return .writingFile
            }

            if executionEngine == .ghostAgent || currentIntent.kind.requiresAgentTools {
                return .usingTools
            }

            return .thinking
        }

        switch lastRunStatus {
        case .completed:
            return .success
        case .failed, .stopped:
            return .error
        case .idle:
            return .idle
        case .running:
            return .thinking
        }
    }

    var currentWorkLine: String {
        taskTimeline.isVisible ? taskTimeline.currentLine : "Thinking"
    }

    var presenceState: GhostPresenceState {
        if isSending {
            if taskTimeline.isWaitingForGhostPlan {
                return GhostPresenceState(
                    mode: .planning,
                    title: "Planning",
                    detail: "Creating the task plan",
                    systemImage: "list.bullet.clipboard"
                )
            }

            let lowerLine = currentWorkLine.lowercased()
            if lowerLine.contains("verify")
                || lowerLine.contains("test")
                || lowerLine.contains("build")
                || lowerLine.contains("checking")
                || lowerLine.contains("confirmed") {
                return GhostPresenceState(
                    mode: .verifying,
                    title: "Verifying",
                    detail: currentWorkLine,
                    systemImage: "checkmark.seal"
                )
            }

            if lowerLine.contains("read")
                || lowerLine.contains("search")
                || lowerLine.contains("rag")
                || lowerLine.contains("lookup")
                || lowerLine.contains("reference") {
                return GhostPresenceState(
                    mode: .reading,
                    title: "Reading",
                    detail: currentWorkLine,
                    systemImage: "doc.text.magnifyingglass"
                )
            }

            if executionEngine == .ghostAgent || currentIntent.kind.requiresAgentTools {
                return GhostPresenceState(
                    mode: .working,
                    title: "Working",
                    detail: currentWorkLine,
                    systemImage: "hammer"
                )
            }

            return GhostPresenceState(
                mode: .waiting,
                title: "Thinking",
                detail: currentWorkLine,
                systemImage: "sparkles"
            )
        }

        switch lastRunStatus {
        case .completed:
            return GhostPresenceState(
                mode: .done,
                title: "Ready",
                detail: lastRunDuration.map { "Last run \(GhostTelemetrySnapshot.formatDuration($0))" } ?? "Last task finished",
                systemImage: "checkmark.circle"
            )
        case .failed, .stopped:
            return GhostPresenceState(
                mode: .blocked,
                title: "Needs attention",
                detail: lastRunStatus == .stopped ? "Last run was stopped" : "Last run failed",
                systemImage: "exclamationmark.triangle"
            )
        case .idle:
            return GhostPresenceState(
                mode: .ready,
                title: "Ready",
                detail: "Ask anything",
                systemImage: "sparkles"
            )
        case .running:
            return GhostPresenceState(
                mode: .waiting,
                title: "Thinking",
                detail: currentWorkLine,
                systemImage: "sparkles"
            )
        }
    }

    var routingShortLine: String {
        if currentIntent == .idle {
            return "Waiting for prompt"
        }

        let reason = currentIntent.reason
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty ?? currentIntent.shortTitle
        return "\(executionEngine.title): \(reason)"
    }

    var routingExplanation: String {
        if currentIntent == .idle {
            return "Ghost is waiting for a prompt before choosing a route."
        }

        var parts: [String] = []
        parts.append("Route: \(executionEngine.title)")
        parts.append("Intent: \(currentIntent.title)")
        parts.append("Reason: \(currentIntent.reason)")
        if !currentIntent.routeLine.isEmpty {
            parts.append("Plan: \(currentIntent.routeLine)")
        }
        let activeChips = activeContextChips
            .filter(\.isActive)
            .map { "\($0.title): \($0.detail)" }
        if !activeChips.isEmpty {
            parts.append("Context: \(activeChips.joined(separator: ", "))")
        }
        return parts.joined(separator: "\n")
    }

    var lastRunStartedAt: Date?
    var lastRunFinishedAt: Date?
    var lastRunDuration: TimeInterval?
    var lastExitStatus: Int32?
    var lastRunStatus: GhostRunStatus = .idle
    var lastPromptCharacterCount: Int = 0
    var lastResponseCharacterCount: Int = 0
    var activeProcessIdentifier: Int32?

    private var activeRunTask: Task<Void, Never>?
    private var activeStreamingMessageID: GhostMessage.ID?
    private var lastGhostCodeChangeSet: GhostCodeChangeSet?
    private var undoneGhostCodeChangeSet: GhostCodeChangeSet?

    var appearanceMode: GhostAppearance = GhostAppearance(
        rawValue: UserDefaults.standard.string(forKey: "ghost.appearance") ?? "system"
    ) ?? .system {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "ghost.appearance")
            applyAppearance()
        }
    }

    func applyAppearance() {
        NSApp.appearance = appearanceMode.nsAppearance
    }

    func cycleAppearance() {
        let all = GhostAppearance.allCases
        if let idx = all.firstIndex(of: appearanceMode) {
            appearanceMode = all[(idx + 1) % all.count]
        }
    }

    var telemetrySnapshot: GhostTelemetrySnapshot {
        GhostTelemetrySnapshot(
            status: isSending ? .running : lastRunStatus,
            providerTitle: effectiveProvider.title,
            model: modelDisplayName,
            effortTitle: effortMode.title(for: selectedProvider),
            approvalMode: runModeLabel,
            workingDirectory: workingDirectoryPath.expandingTildeInPath,
            activeRunStartedAt: activeRunStartedAt,
            lastRunStartedAt: lastRunStartedAt,
            lastRunFinishedAt: lastRunFinishedAt,
            lastRunDuration: lastRunDuration,
            exitStatus: lastExitStatus,
            estimatedPromptTokens: TelemetryTokenEstimator.estimateTokens(characterCount: lastPromptCharacterCount),
            estimatedResponseTokens: TelemetryTokenEstimator.estimateTokens(characterCount: lastResponseCharacterCount),
            activityEventCount: activityEntries.count,
            queuedTaskCount: taskQueue.count,
            includeClipboard: includeClipboard,
            isDictating: speechRecognizer.isRecording,
            processIdentifier: activeProcessIdentifier
        )
    }

    let speechRecognizer: SpeechTranscriber

    private let ghostClient: GhostClient
    private let directAPIClient = DirectAPIClient()
    private let reminderParser = DeterministicReminderParser()
    private let calendarEventParser = DeterministicCalendarEventParser()
    private let calendarQueryParser = DeterministicCalendarQueryParser()
    private let nativeReminderService = NativeReminderService()
    private let nativeCalendarService = NativeCalendarService()
    private let shellCommandService = ShellCommandService()
    private let projectContextService = ProjectContextService()
    private let openCodeCompatService = OpenCodeCompatService()
    private let ghostCodeChangeSetService = GhostCodeChangeSetService()
    private let intentRouter = GhostIntentRouter()
    private let ragStore = GhostRAGStore()
    private var desktopRAGWatcher = GhostDesktopRAGWatcher()

    var isRAGWatcherPaused: Bool {
        get { UserDefaults.standard.bool(forKey: Self.ragPausedDefaultsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.ragPausedDefaultsKey)
            if newValue { desktopRAGWatcher.stop() }
            else if isRAGEnabled { startDesktopRAGWatcher() }
        }
    }

    private static let ragPausedDefaultsKey = "Ghost.ragPaused"

    var ragDocumentCount: Int {
        let result = ragStore.status()
        guard result["ok"] as? Bool == true,
              let payload = result["payload"] as? [String: Any],
              let count = payload["document_count"] as? Int
        else { return 0 }
        return count
    }

    var ragChunkCount: Int {
        let result = ragStore.status()
        guard result["ok"] as? Bool == true,
              let payload = result["payload"] as? [String: Any],
              let count = payload["chunk_count"] as? Int
        else { return 0 }
        return count
    }

    var isRAGIndexing: Bool { activeRunStartedAt != nil && activeProcessIdentifier == nil }
    private let localModelsService: LocalModelsService
    private let secretsService: GhostSecretsService
    private static let providerDefaultsKey = "selectedGhostProvider"
    private static let executionEngineDefaultsKey = "executionEngine"
    private static let enginePreferenceDefaultsKey = "enginePreference"
    private static let interfaceModeDefaultsKey = "ghostInterfaceMode"
    private static let interfacePreferenceDefaultsKey = "ghostInterfacePreference"
    private static let panelSizeModeDefaultsKey = "ghostPanelSizeMode"
    private static let codeAgentModeDefaultsKey = "ghostCodeAgentMode"
    private static let ghostCodeOutputModeDefaultsKey = "ghostCodeOutputMode"
    private static let localModelDefaultsKey = "selectedLocalModel"
    private static let deepSeekModelDefaultsKey = "selectedDeepSeekModel"
    private static let localContextDefaultsKey = "localContextWindow"
    private static let workingDirectoryDefaultsKey = "workingDirectoryPath"
    private static let documentOutputDirectoryDefaultsKey = "documentOutputDirectoryPath"
    private static let ragRootDefaultsKey = "ragRootPath"
    private static let ragEnabledDefaultsKey = "ragEnabled"
    private static let persistentWindowDefaultsKey = "persistentWindow"
    private static let terminalThemeDefaultsKey = "ghostTerminalTheme"
    private static let effortModeDefaultsKey = "effortMode"
    private static let approvalModeDefaultsKey = "approvalMode"
    private static let includeClipboardDefaultsKey = "includeClipboard"
    private static let toolsetsDefaultsKey = "toolsets"
    private static let recentPromptsDefaultsKey = "recentPrompts"
    private static let terminalToolDetailsDefaultsKey = "terminalToolDetailsVisible"
    private static let taskVerificationDefaultsKey = "taskVerificationMode"
    private static let producedDocumentsDefaultsKey = "ghostProducedDocuments"
    private static let onboardingCompleteDefaultsKey = "ghost.onboarding.completed.v1"
    private static let useHermesAgentDefaultsKey = "useHermesAgent"
    private static let hermesExecutablePathDefaultsKey = "hermesExecutablePath"
    private static let ollamaModelDefaultsKey = "ollamaModel"
    private static let ollamaBaseURLDefaultsKey = "ollamaBaseURL"
    private static let openCodeGoModelDefaultsKey = "openCodeGoModel"

    init(
        ghostClient: GhostClient,
        speechRecognizer: SpeechTranscriber,
        localModelsService: LocalModelsService = LocalModelsService(),
        secretsService: GhostSecretsService = GhostSecretsService()
    ) {
        self.ghostClient = ghostClient
        self.speechRecognizer = speechRecognizer
        self.localModelsService = localModelsService
        self.secretsService = secretsService
        let savedProvider = UserDefaults.standard.string(forKey: Self.providerDefaultsKey)
        selectedProvider = savedProvider.flatMap(GhostProvider.init(rawValue:)) ?? .deepSeek
        let savedEnginePreference = UserDefaults.standard.string(forKey: Self.enginePreferenceDefaultsKey)
        enginePreference = savedEnginePreference.flatMap(EnginePreference.init(rawValue:)) ?? .auto
        executionEngine = .ghostAgent

        let savedInterfacePreference = UserDefaults.standard.string(forKey: Self.interfacePreferenceDefaultsKey)
        interfacePreference = savedInterfacePreference.flatMap(GhostInterfacePreference.init(rawValue:)) ?? .adaptive

        let savedInterfaceMode = UserDefaults.standard.string(forKey: Self.interfaceModeDefaultsKey)
        interfaceMode = savedInterfaceMode.flatMap(GhostInterfaceMode.init(rawValue:)) ?? .glass

        let savedPanelSizeMode = UserDefaults.standard.string(forKey: Self.panelSizeModeDefaultsKey)
        panelSizeMode = savedPanelSizeMode.flatMap(GhostPanelSizeMode.init(rawValue:)) ?? .normal

        let savedCodeAgentMode = UserDefaults.standard.string(forKey: Self.codeAgentModeDefaultsKey)
        codeAgentMode = savedCodeAgentMode.flatMap(GhostCodeAgentMode.init(rawValue:)) ?? .plan
        let savedGhostCodeOutputMode = UserDefaults.standard.string(forKey: Self.ghostCodeOutputModeDefaultsKey)
        ghostCodeOutputMode = savedGhostCodeOutputMode.flatMap(GhostCodeOutputMode.init(rawValue:)) ?? .terminal
        let savedEffort = UserDefaults.standard.string(forKey: Self.effortModeDefaultsKey)
        effortMode = savedEffort.flatMap(EffortMode.init(rawValue:)) ?? .low
        let savedApproval = UserDefaults.standard.string(forKey: Self.approvalModeDefaultsKey)
        approvalMode = savedApproval.flatMap(ApprovalMode.init(rawValue:)) ?? .ask
        includeClipboard = UserDefaults.standard.object(forKey: Self.includeClipboardDefaultsKey) as? Bool ?? false
        isTerminalToolDetailsVisible = UserDefaults.standard.object(forKey: Self.terminalToolDetailsDefaultsKey) as? Bool ?? true
        isTaskVerificationEnabled = UserDefaults.standard.object(forKey: Self.taskVerificationDefaultsKey) as? Bool ?? true
        toolsets = UserDefaults.standard.string(forKey: Self.toolsetsDefaultsKey) ?? ""
        useHermesAgent = UserDefaults.standard.object(forKey: Self.useHermesAgentDefaultsKey) as? Bool ?? false
        hermesExecutablePath = UserDefaults.standard.string(forKey: Self.hermesExecutablePathDefaultsKey) ?? ""
        selectedLocalModel = UserDefaults.standard.string(forKey: Self.localModelDefaultsKey) ?? "qwen/qwen3.6-35b-a3b"
        selectedOllamaModel = UserDefaults.standard.string(forKey: Self.ollamaModelDefaultsKey) ?? "llama3.1:8b"
        selectedOpenCodeGoModel = UserDefaults.standard.string(forKey: Self.openCodeGoModelDefaultsKey) ?? "deepseek-v4-flash"
        ollamaBaseURLString = UserDefaults.standard.string(forKey: Self.ollamaBaseURLDefaultsKey) ?? "http://localhost:11434"
        selectedDeepSeekModel = UserDefaults.standard.string(forKey: Self.deepSeekModelDefaultsKey) ?? "deepseek-v4-pro"
        let savedContext = UserDefaults.standard.integer(forKey: Self.localContextDefaultsKey)
        localContextWindow = savedContext == 0 ? 65_536 : savedContext
        workingDirectoryPath = UserDefaults.standard.string(forKey: Self.workingDirectoryDefaultsKey) ?? NSHomeDirectory()
        documentOutputDirectoryPath = UserDefaults.standard.string(forKey: Self.documentOutputDirectoryDefaultsKey) ?? "\(NSHomeDirectory())/Ghost Outputs"
        ragRootPath = UserDefaults.standard.string(forKey: Self.ragRootDefaultsKey) ?? "\(NSHomeDirectory())/Desktop"
        isRAGEnabled = UserDefaults.standard.object(forKey: Self.ragEnabledDefaultsKey) as? Bool ?? false
        isPersistentWindow = UserDefaults.standard.object(forKey: Self.persistentWindowDefaultsKey) as? Bool ?? false
        let savedTerminalTheme = UserDefaults.standard.string(forKey: Self.terminalThemeDefaultsKey)
        terminalTheme = savedTerminalTheme.flatMap(GhostTerminalTheme.init(rawValue:)) ?? .ghost
        recentPrompts = UserDefaults.standard.stringArray(forKey: Self.recentPromptsDefaultsKey) ?? []
        producedDocuments = Self.loadProducedDocuments()
        conversations = historyStore.listConversations()
        savedPrompts = promptLibrary.load()
        restoreMostRecentConversation()
        enforceInterfacePreference()
        activeContextChips = intentRouter.contextChips(
            for: currentIntent,
            includeClipboard: includeClipboard,
            hasClipboardText: ClipboardService().readText()?.isEmpty == false,
            workspaceRoot: workspaceRootURL,
            activityCount: 0
        )
        loadSavedAPIKeyState()
        if selectedProvider == .openCodeGo, savedAPIKeyProviders.contains(.openCodeGo) {
            refreshOpenCodeGoModels()
        }
        isOnboardingPresented = !UserDefaults.standard.bool(forKey: Self.onboardingCompleteDefaultsKey)
        if isOnboardingPresented {
            panelMode = .chat
            panelSizeMode = .normal
        }
        detectHermesAgent()
        applyAppearance()
        ensureDocumentOutputDirectory()
        if isRAGEnabled && !isRAGWatcherPaused { startDesktopRAGWatcher() }
    }

    private var ragRootURL: URL {
        resolvedPath(ragRootPath)
    }

    private var documentOutputDirectoryURL: URL {
        resolvedPath(documentOutputDirectoryPath)
    }

    private func startDesktopRAGWatcher() {
        guard isRAGEnabled, !isRAGWatcherPaused else { return }
        desktopRAGWatcher.start(watchedURL: ragRootURL, workspace: workspaceRootURL, onActivity: activityRecorder())
    }

    private func ensureDocumentOutputDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: documentOutputDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            settingsMessage = "Could not create output folder: \(error.localizedDescription)"
        }
    }

    func chooseRAGFolder() {
        chooseFolder(title: "Choose RAG Folder", currentPath: ragRootPath) { [weak self] url in
            guard let self else { return }
            ragRootPath = url.path
            if isRAGEnabled {
                syncSelectedRAGFolder(reason: "folder selected")
            }
        }
    }

    func chooseDocumentOutputFolder() {
        chooseFolder(title: "Choose Ghost Output Folder", currentPath: documentOutputDirectoryPath) { [weak self] url in
            guard let self else { return }
            documentOutputDirectoryPath = url.path
            settingsMessage = "Ghost documents will be saved in \(url.path)."
        }
    }

    func chooseWorkingDirectory() {
        chooseFolder(title: "Choose Working Folder", currentPath: workingDirectoryPath) { [weak self] url in
            self?.workingDirectoryPath = url.path
        }
    }

    private func chooseFolder(title: String, currentPath: String, onSelect: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = resolvedPath(currentPath)
        if panel.runModal() == .OK, let url = panel.url {
            onSelect(url)
        }
    }

    func syncSelectedRAGFolder(reason: String = "manual sync") {
        guard isRAGEnabled else {
            settingsMessage = "Turn on RAG before indexing a folder."
            return
        }

        let root = ragRootURL
        let workspace = workspaceRootURL
        let onActivity = activityRecorder()
        Task.detached(priority: .utility) { [ragStore] in
            onActivity(GhostActivityEntry(kind: .info, title: "RAG sync", detail: "Indexing \(root.path)..."))
            let result = ragStore.syncFolder(
                path: root.path,
                recursive: true,
                removeMissing: true,
                maxFiles: 50_000,
                workspace: workspace
            )

            let ok = result["ok"] as? Bool == true
            onActivity(
                GhostActivityEntry(
                    kind: ok ? .success : .error,
                    title: ok ? "RAG folder synced" : "RAG sync failed",
                    detail: result["summary"] as? String ?? result["error"] as? String ?? reason
                )
            )
        }
    }

    private func ingestIBooks() {
        let ibooksPath = NSHomeDirectory() + "/Library/Mobile Documents/iCloud~com~apple~iBooks/Documents"
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: ibooksPath, isDirectory: &isDir), isDir.boolValue else { return }

        let onActivity = activityRecorder()
        Task.detached(priority: .utility) { [ragStore, workspaceRootURL] in
            onActivity(GhostActivityEntry(kind: .info, title: "iBooks RAG", detail: "Indexing iBooks library..."))

            let result = ragStore.ingestFolder(path: ibooksPath, recursive: true, maxFiles: 1_000, workspace: workspaceRootURL)

            if result["ok"] as? Bool == true {
                let payload = result["payload"] as? [String: Any] ?? [:]
                let indexed = payload["indexed_files"] as? Int ?? 0
                onActivity(GhostActivityEntry(kind: .success, title: "iBooks RAG", detail: "Indexed \(indexed) book(s) from iBooks."))
            } else {
                onActivity(GhostActivityEntry(kind: .error, title: "iBooks RAG", detail: result["error"] as? String ?? "iBooks indexing failed."))
            }
        }
    }

    func clearRAGIndex() {
        let result = ragStore.clearIndex()
        let ok = result["ok"] as? Bool == true
        recordActivity(
            GhostActivityEntry(
                kind: ok ? .success : .error,
                title: ok ? "RAG index cleared" : "RAG clear failed",
                detail: result["summary"] as? String ?? result["error"] as? String ?? ""
            )
        )
    }

    func reindexRAG() {
        guard isRAGEnabled else {
            settingsMessage = "Turn on RAG before reindexing."
            return
        }
        let result = ragStore.reindex(workspace: workspaceRootURL)
        let ok = result["ok"] as? Bool == true
        recordActivity(
            GhostActivityEntry(
                kind: ok ? .success : .error,
                title: ok ? "RAG reindex" : "RAG reindex failed",
                detail: result["summary"] as? String ?? result["error"] as? String ?? ""
            )
        )
    }

    func ingestRAGFile(path: String) {
        guard isRAGEnabled else {
            settingsMessage = "Turn on RAG before indexing files."
            return
        }
        let result = ragStore.ingestFile(path: path, workspace: workspaceRootURL)
        let ok = result["ok"] as? Bool == true
        recordActivity(
            GhostActivityEntry(
                kind: ok ? .success : .error,
                title: ok ? "RAG file ingested" : "RAG ingest failed",
                detail: result["summary"] as? String ?? result["error"] as? String ?? ""
            )
        )
    }

    func ingestRAGFolder(path: String) {
        guard isRAGEnabled else {
            settingsMessage = "Turn on RAG before indexing folders."
            return
        }
        let result = ragStore.ingestFolder(path: path, recursive: true, maxFiles: 50_000, workspace: workspaceRootURL)
        let ok = result["ok"] as? Bool == true
        recordActivity(
            GhostActivityEntry(
                kind: ok ? .success : .error,
                title: ok ? "RAG folder ingested" : "RAG folder ingest failed",
                detail: result["summary"] as? String ?? result["error"] as? String ?? ""
            )
        )
    }

    var preferredPanelSize: CGSize {
        let fallback = panelSizeMode.fallbackSize(for: visibleInterfaceMode)

        guard panelSizeMode == .full,
              let visibleFrame = NSScreen.main?.visibleFrame
        else {
            return fallback
        }

        return CGSize(
            width: max(panelSizeMode.minimumSize.width, visibleFrame.width - 48),
            height: max(panelSizeMode.minimumSize.height, visibleFrame.height - 48)
        )
    }

    var minimumPanelSize: CGSize {
        panelSizeMode.minimumSize
    }

    func selectPanelSize(_ mode: GhostPanelSizeMode) {
        panelSizeMode = mode
    }

    var canSend: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    func send() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let imageAttachment = pendingImageAttachment

        if isSending {
            queueQuickAskFollowUp(text)
            return
        }

        if interfaceMode == .terminal, text.hasPrefix("!") {
            prompt = ""
            saveRecentPrompt(text)
            messages.append(GhostMessage(role: .user, text: text))
            schedulePersist()
            runShellCommand(String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines))
            return
        }

        if handleLocalCommand(text) {
            if prompt.trimmingCharacters(in: .whitespacesAndNewlines) == text {
                prompt = ""
            }
            saveRecentPrompt(text)
            return
        }

        if handleDeterministicReminderIfPossible(text) {
            return
        }

        if handleDeterministicCalendarEventIfPossible(text) {
            return
        }

        if handleDeterministicCalendarQueryIfPossible(text) {
            return
        }

        prompt = ""
        isSending = true
        activeRunStartedAt = Date()
        lastRunStartedAt = Date()
        lastPromptCharacterCount = text.count
        lastRunStatus = .running
        activeProcessIdentifier = nil
        let clipboardText = shouldReadClipboard(for: text) ? ClipboardService().readText() : nil
        let routingSeed = imageAttachment == nil ? text : "\(text)\n\n[Pasted screenshot attached]"
        let routingPrompt = contextualPromptForRouting(routingSeed)

        let detectedIntent = intentRouter.detect(
            prompt: routingPrompt,
            includeClipboard: includeClipboard,
            workspaceRoot: workspaceRootURL,
            hasClipboardText: clipboardText?.isEmpty == false
        )

        let runPrompt = executionPromptForRun(
            rawPrompt: text,
            routingPrompt: routingPrompt
        )

        let runEngine = resolvedEngine(for: routingPrompt, intent: detectedIntent)

        applyAdaptiveRoute(for: detectedIntent, engine: runEngine)

        currentIntent = detectedIntent
        activeContextChips = contextChips(
            for: detectedIntent,
            prompt: routingPrompt,
            runEngine: runEngine,
            hasClipboardText: clipboardText?.isEmpty == false
        )
        progressMarkerBuffer = ""

        beginTaskTimeline(
            prompt: text,
            intent: detectedIntent,
            runEngine: runEngine
        )

        updateLastTaskContext(
            rawPrompt: text,
            intent: detectedIntent,
            runEngine: runEngine
        )
        let clipboard = includeClipboard || detectedIntent.usesClipboard ? clipboardText : nil
        let context = recentConversationContext()
        let fileContexts = shouldResolveFileContexts(for: text, intent: detectedIntent)
            ? projectContextService.resolvedFileContexts(in: text, root: workspaceRootURL)
            : []
        let ragContext: String?
        if isRAGEnabled, detectedIntent.kind == .fileSummary {
            let ragResult = ragStore.query(runPrompt, maxResults: selectedProvider.isLocal ? 4 : 8, workspace: workspaceRootURL)
            if ragResult["ok"] as? Bool == true,
               let payload = ragResult["payload"] as? [String: Any],
               let chunks = payload["chunks"] as? [[String: Any]],
               !chunks.isEmpty {
                ragContext = chunks.enumerated().map { index, chunk in
                    let doc = chunk["document"] as? String ?? ""
                    let page = (chunk["page"] as? Int).map { " (page \($0))" } ?? ""
                    let text = chunk["text"] as? String ?? ""
                    return "[\(index + 1)] from \(doc)\(page):\n\(text)"
                }.joined(separator: "\n\n")
            } else {
                ragContext = nil
            }
        } else {
            ragContext = nil
        }
        let snapshotSettings = runSettings()
        let snapshotRunEngine = runEngine
        let snapshotEffectiveRunEngine: ExecutionEngine = snapshotSettings.provider.isLocal && snapshotRunEngine == .ghostAgent
            ? .directAPI
            : snapshotRunEngine
        let imageForDirectAPI = imageAttachmentForDirectAPI(
            imageAttachment,
            engine: snapshotEffectiveRunEngine,
            settings: snapshotSettings
        )
        let runPromptWithAttachment = runPrompt + imageAttachmentPromptBlock(
            imageAttachment,
            engine: snapshotEffectiveRunEngine,
            settings: snapshotSettings
        )
        let finalPrompt: String
        if selectedProvider.isLocal {
            let clip = clipboard?.trimmingCharacters(in: .whitespacesAndNewlines)
            let clipped = clip.map { "\n\nClipboard context:\n\($0)" } ?? ""
            let ragBlock = ragContext.map { "\n\nRAG document context:\n\($0)" } ?? ""
            let fileCtx = terminalFileContextBlock(fileContexts)
            let conv = context.map { "\n\nRecent conversation:\n\($0)" } ?? ""
            finalPrompt = "\(runPromptWithAttachment)\(clipped)\(ragBlock)\(conv)\(fileCtx)"
        } else {
            finalPrompt = promptWithEffort(
                runPromptWithAttachment,
                clipboard: clipboard,
                conversationContext: context,
                fileContexts: fileContexts,
                ragContext: ragContext,
                detectedIntent: detectedIntent,
                runEngine: runEngine
            )
        }
        let snapshotRunModeLabel = runModeLabel(for: snapshotRunEngine)
        let snapshotStartedAt = Date()
        saveRecentPrompt(text)
        let userMessage = GhostMessage(role: .user, text: visibleUserText(text, imageAttachment: imageAttachment))
        messages.append(userMessage)
        taskTimelineAnchorMessageID = userMessage.id
        pendingImageAttachment = nil
        schedulePersist()

        if !fileContexts.isEmpty {
            recordActivity(
                GhostActivityEntry(
                    kind: .info,
                    title: "Referenced files",
                    detail: fileContexts.map(\.relativePath).joined(separator: ", ")
                )
            )
        }

        recordActivity(
            GhostActivityEntry(
                kind: .info,
                title: "Prompt sent",
                detail: text
            )
        )

        let codeSnapshotBefore = shouldTrackCodeChanges(runEngine: snapshotRunEngine)
            ? ghostCodeChangeSetService.captureSnapshot(root: workspaceRootURL)
            : nil

        activeStreamingMessageID = nil
        activeRunTask = Task {
            do {
                let result = try await runHarness(
                    engine: snapshotRunEngine,
                    prompt: finalPrompt,
                    settings: snapshotSettings,
                    imageAttachment: imageForDirectAPI,
                    onActivity: activityRecorder(),
                    onToken: snapshotRunEngine == .directAPI && imageForDirectAPI == nil ? directTokenRecorder() : nil
                )
                let finishedAt = Date()
                lastRunFinishedAt = finishedAt
                lastRunDuration = finishedAt.timeIntervalSince(snapshotStartedAt)
                lastExitStatus = result.exitStatus
                lastRunStatus = result.exitStatus == 0 ? .completed : .failed
                lastResponseCharacterCount = result.output.count
                let metadata = GhostRunMetadata(
                    providerTitle: result.provider.title,
                    providerRawValue: result.provider.ghostProvider,
                    model: result.model,
                    effortTitle: result.effortMode.title(for: result.provider),
                    effortRawValue: result.effortMode.rawValue,
                    reasoningEffort: result.reasoningEffort,
                    maxTurns: result.maxTurns,
                    maxTokens: result.maxTokens,
                    approvalMode: snapshotRunModeLabel,
                    startedAt: snapshotStartedAt,
                    finishedAt: finishedAt,
                    workingDirectory: result.workingDirectory,
                    launchedArguments: result.launchedArguments
                )
                flushLiveProgressMarkerBuffer()

                applyProgressMarkers(from: result.output)

                let cleanedOutput = stripGhostProgressMarkers(
                    from: result.output.isEmpty ? "Ghost finished but returned no output." : result.output
                )

                let producedDocuments = registerProducedDocuments(
                    from: cleanedOutput,
                    source: snapshotRunEngine.title
                )

                let baseResponseText = formatGhostResponse(cleanedOutput)
                let verificationBlock = taskVerificationBlock(
                    result: result,
                    runEngine: snapshotRunEngine,
                    intent: detectedIntent,
                    producedDocuments: producedDocuments
                )
                let responseText = appendVerificationBlock(
                    verificationBlock,
                    to: baseResponseText
                )

                finishTaskTimeline(
                    success: result.exitStatus == 0,
                    summary: result.exitStatus == 0 ? "Finished successfully" : "Finished with errors"
                )

                if activeStreamingMessageID != nil {
                    finishDirectStream(text: responseText, metadata: metadata)
                } else {
                    messages.append(GhostMessage(role: .ghost, text: responseText, runMetadata: metadata))
                }
                schedulePersist()
                if let codeSnapshotBefore {
                    trackCodeChanges(after: codeSnapshotBefore, command: text)
                }
            } catch is CancellationError {
                lastRunFinishedAt = Date()
                if let startedAt = lastRunStartedAt {
                    lastRunDuration = Date().timeIntervalSince(startedAt)
                }
                lastRunStatus = .stopped
            } catch {
                lastRunFinishedAt = Date()
                if let startedAt = lastRunStartedAt {
                    lastRunDuration = Date().timeIntervalSince(startedAt)
                }
                lastRunStatus = .failed

                flushLiveProgressMarkerBuffer()

                finishTaskTimeline(
                    success: false,
                    summary: error.localizedDescription
                )

                messages.append(GhostMessage(role: .system, text: error.localizedDescription))
            }
            let queuedFollowUp = queuedQuickAskPrompt
            queuedQuickAskPrompt = nil
            isSending = false
            activeRunStartedAt = nil
            activeRunTask = nil
            activeStreamingMessageID = nil

            if let queuedFollowUp {
                prompt = queuedFollowUp
                send()
            }
        }
    }

    private func handleDeterministicReminderIfPossible(_ text: String) -> Bool {
        guard let parsed = reminderParser.parse(text) else {
            return false
        }

        let reminderIntent = GhostDetectedIntent(
            kind: .automation,
            confidence: parsed.confidence,
            steps: ["parse schedule", "create reminder", "confirm setup"],
            reason: "Ghost parsed a simple one-shot reminder locally without asking the model.",
            inferredFileExtension: nil,
            requestedFilename: nil,
            usesClipboard: false,
            usesWorkspace: false,
            usesWeb: false
        )

        prompt = ""
        saveRecentPrompt(text)
        let userMessage = GhostMessage(role: .user, text: text)
        messages.append(userMessage)
        taskTimelineAnchorMessageID = userMessage.id

        isSending = true
        activeRunStartedAt = Date()
        lastRunStartedAt = Date()
        lastPromptCharacterCount = text.count
        lastRunStatus = .running
        activeProcessIdentifier = nil
        currentIntent = reminderIntent
        executionEngine = .directAPI
        activeContextChips = [
            GhostContextChip("Route", "Native · reminder", systemImage: "bell.badge"),
            GhostContextChip("Reminders", "macOS", systemImage: "checklist"),
            GhostContextChip("Time", parsed.formattedDueDate(), systemImage: "clock")
        ]
        progressMarkerBuffer = ""

        taskTimeline = GhostTaskTimeline(
            title: "Creating reminder",
            subtitle: text,
            route: "Native · deterministic schedule parser",
            steps: [
                GhostTaskStep(title: "Parse reminder date", detail: parsed.formattedDueDate(), state: .completed),
                GhostTaskStep(title: "Create macOS reminder", detail: parsed.title, state: .running),
                GhostTaskStep(title: "Confirm setup", state: .pending)
            ],
            summary: nil,
            error: nil,
            startedAt: Date(),
            finishedAt: nil,
            lastUpdatedAt: Date(),
            isVisible: true,
            isWaitingForGhostPlan: false,
            isUsingGhostPlan: false,
            pendingGhostPlanItems: []
        )

        recordActivity(
            GhostActivityEntry(
                kind: .info,
                title: "Parsed reminder locally",
                detail: "\(parsed.title) · \(parsed.formattedDueDate())"
            )
        )

        let startedAt = Date()
        activeRunTask = Task {
            do {
                recordActivity(GhostActivityEntry(kind: .command, title: "Creating reminder", detail: parsed.title))
                let result = try await nativeReminderService.createReminder(parsed)
                let finishedAt = Date()

                lastRunFinishedAt = finishedAt
                lastRunDuration = finishedAt.timeIntervalSince(startedAt)
                lastExitStatus = 0
                lastRunStatus = .completed
                lastResponseCharacterCount = result.confirmationText().count

                if taskTimeline.steps.indices.contains(1) {
                    taskTimeline.steps[1].state = .completed
                    taskTimeline.steps[1].detail = result.backend
                }
                if taskTimeline.steps.indices.contains(2) {
                    taskTimeline.steps[2].state = .completed
                    taskTimeline.steps[2].detail = result.confirmationText()
                }
                finishTaskTimeline(success: true, summary: "Reminder created")

                recordActivity(GhostActivityEntry(kind: .success, title: "Reminder created", detail: result.confirmationText()))
                messages.append(GhostMessage(role: .ghost, text: result.confirmationText()))
            } catch {
                let finishedAt = Date()
                lastRunFinishedAt = finishedAt
                lastRunDuration = finishedAt.timeIntervalSince(startedAt)
                lastExitStatus = 1
                lastRunStatus = .failed
                finishTaskTimeline(success: false, summary: error.localizedDescription)
                recordActivity(GhostActivityEntry(kind: .error, title: "Reminder failed", detail: error.localizedDescription))
                messages.append(GhostMessage(role: .system, text: error.localizedDescription))
            }

            isSending = false
            activeRunStartedAt = nil
            activeRunTask = nil
            activeStreamingMessageID = nil
        }

        return true
    }

    private func handleDeterministicCalendarEventIfPossible(_ text: String) -> Bool {
        guard let parsed = calendarEventParser.parse(text) else {
            return false
        }

        let calendarIntent = GhostDetectedIntent(
            kind: .automation,
            confidence: parsed.confidence,
            steps: ["parse event", "create calendar event", "confirm setup"],
            reason: "Ghost parsed a simple calendar event locally without asking the model.",
            inferredFileExtension: nil,
            requestedFilename: nil,
            usesClipboard: false,
            usesWorkspace: false,
            usesWeb: false
        )

        prompt = ""
        saveRecentPrompt(text)
        let userMessage = GhostMessage(role: .user, text: text)
        messages.append(userMessage)
        taskTimelineAnchorMessageID = userMessage.id

        isSending = true
        activeRunStartedAt = Date()
        lastRunStartedAt = Date()
        lastPromptCharacterCount = text.count
        lastRunStatus = .running
        activeProcessIdentifier = nil
        currentIntent = calendarIntent
        executionEngine = .directAPI
        activeContextChips = [
            GhostContextChip("Route", "Native · calendar", systemImage: "calendar.badge.plus"),
            GhostContextChip("Calendar", "macOS", systemImage: "calendar"),
            GhostContextChip("Time", parsed.formattedTime(), systemImage: "clock")
        ]
        progressMarkerBuffer = ""

        taskTimeline = GhostTaskTimeline(
            title: "Creating calendar event",
            subtitle: text,
            route: "Native · deterministic calendar parser",
            steps: [
                GhostTaskStep(title: "Parse event time", detail: parsed.formattedTime(), state: .completed),
                GhostTaskStep(title: "Create macOS Calendar event", detail: parsed.title, state: .running),
                GhostTaskStep(title: "Confirm setup", state: .pending)
            ],
            summary: nil,
            error: nil,
            startedAt: Date(),
            finishedAt: nil,
            lastUpdatedAt: Date(),
            isVisible: true,
            isWaitingForGhostPlan: false,
            isUsingGhostPlan: false,
            pendingGhostPlanItems: []
        )

        recordActivity(
            GhostActivityEntry(
                kind: .info,
                title: "Parsed calendar event locally",
                detail: "\(parsed.title) · \(parsed.formattedTime())"
            )
        )

        let startedAt = Date()
        activeRunTask = Task {
            do {
                recordActivity(GhostActivityEntry(kind: .command, title: "Creating calendar event", detail: parsed.title))
                let result = try await nativeCalendarService.createEvent(
                    title: parsed.title,
                    startDate: parsed.startDate,
                    endDate: parsed.endDate,
                    notes: parsed.notes,
                    location: parsed.location
                )
                let finishedAt = Date()
                let confirmation = result.confirmationText()

                lastRunFinishedAt = finishedAt
                lastRunDuration = finishedAt.timeIntervalSince(startedAt)
                lastExitStatus = 0
                lastRunStatus = .completed
                lastResponseCharacterCount = confirmation.count

                if taskTimeline.steps.indices.contains(1) {
                    taskTimeline.steps[1].state = .completed
                    taskTimeline.steps[1].detail = result.calendarTitle
                }
                if taskTimeline.steps.indices.contains(2) {
                    taskTimeline.steps[2].state = .completed
                    taskTimeline.steps[2].detail = confirmation
                }
                finishTaskTimeline(success: true, summary: "Calendar event created")

                recordActivity(GhostActivityEntry(kind: .success, title: "Calendar event created", detail: confirmation))
                messages.append(GhostMessage(role: .ghost, text: confirmation))
            } catch {
                let finishedAt = Date()
                lastRunFinishedAt = finishedAt
                lastRunDuration = finishedAt.timeIntervalSince(startedAt)
                lastExitStatus = 1
                lastRunStatus = .failed
                finishTaskTimeline(success: false, summary: error.localizedDescription)
                recordActivity(GhostActivityEntry(kind: .error, title: "Calendar event failed", detail: error.localizedDescription))
                messages.append(GhostMessage(role: .system, text: error.localizedDescription))
            }

            isSending = false
            activeRunStartedAt = nil
            activeRunTask = nil
            activeStreamingMessageID = nil
        }

        return true
    }

    private func handleDeterministicCalendarQueryIfPossible(_ text: String) -> Bool {
        guard let parsed = calendarQueryParser.parse(text) else {
            return false
        }

        let calendarIntent = GhostDetectedIntent(
            kind: .answer,
            confidence: parsed.confidence,
            steps: ["parse date range", "read calendar", "summarize events"],
            reason: "Ghost parsed a simple read-only calendar question locally without asking the model.",
            inferredFileExtension: nil,
            requestedFilename: nil,
            usesClipboard: false,
            usesWorkspace: false,
            usesWeb: false
        )

        prompt = ""
        saveRecentPrompt(text)
        let userMessage = GhostMessage(role: .user, text: text)
        messages.append(userMessage)
        taskTimelineAnchorMessageID = userMessage.id

        isSending = true
        activeRunStartedAt = Date()
        lastRunStartedAt = Date()
        lastPromptCharacterCount = text.count
        lastRunStatus = .running
        activeProcessIdentifier = nil
        currentIntent = calendarIntent
        executionEngine = .directAPI
        activeContextChips = [
            GhostContextChip("Route", "Native · calendar", systemImage: "calendar"),
            GhostContextChip("Calendar", "macOS", systemImage: "calendar.badge.clock"),
            GhostContextChip("Range", parsed.label, systemImage: "clock")
        ]
        progressMarkerBuffer = ""

        taskTimeline = GhostTaskTimeline(
            title: "Reading calendar",
            subtitle: text,
            route: "Native · deterministic calendar parser",
            steps: [
                GhostTaskStep(title: "Parse calendar range", detail: parsed.formattedRange(), state: .completed),
                GhostTaskStep(title: "Read macOS Calendar", detail: parsed.label, state: .running),
                GhostTaskStep(title: "Summarize events", state: .pending)
            ],
            summary: nil,
            error: nil,
            startedAt: Date(),
            finishedAt: nil,
            lastUpdatedAt: Date(),
            isVisible: true,
            isWaitingForGhostPlan: false,
            isUsingGhostPlan: false,
            pendingGhostPlanItems: []
        )

        recordActivity(
            GhostActivityEntry(
                kind: .info,
                title: "Parsed calendar query locally",
                detail: "\(parsed.label) · \(parsed.formattedRange())"
            )
        )

        let startedAt = Date()
        activeRunTask = Task {
            do {
                recordActivity(GhostActivityEntry(kind: .command, title: "Reading calendar", detail: parsed.formattedRange()))
                let events = try await nativeCalendarService.queryEvents(
                    startDate: parsed.startDate,
                    endDate: parsed.endDate,
                    limit: 80
                )
                let finishedAt = Date()

                lastRunFinishedAt = finishedAt
                lastRunDuration = finishedAt.timeIntervalSince(startedAt)
                lastExitStatus = 0
                lastRunStatus = .completed

                if taskTimeline.steps.indices.contains(1) {
                    taskTimeline.steps[1].state = .completed
                    taskTimeline.steps[1].detail = "\(events.count) event\(events.count == 1 ? "" : "s")"
                }
                if taskTimeline.steps.indices.contains(2) {
                    taskTimeline.steps[2].state = .completed
                    taskTimeline.steps[2].detail = "Calendar summary prepared"
                }

                let answer = formatCalendarQueryResult(events, query: parsed)
                lastResponseCharacterCount = answer.count
                finishTaskTimeline(success: true, summary: events.isEmpty ? "No calendar events found" : "Calendar read")

                recordActivity(GhostActivityEntry(kind: .success, title: "Calendar read", detail: "\(events.count) event\(events.count == 1 ? "" : "s")"))
                messages.append(GhostMessage(role: .ghost, text: answer))
            } catch {
                let finishedAt = Date()
                lastRunFinishedAt = finishedAt
                lastRunDuration = finishedAt.timeIntervalSince(startedAt)
                lastExitStatus = 1
                lastRunStatus = .failed
                finishTaskTimeline(success: false, summary: error.localizedDescription)
                recordActivity(GhostActivityEntry(kind: .error, title: "Calendar failed", detail: error.localizedDescription))
                messages.append(GhostMessage(role: .system, text: error.localizedDescription))
            }

            isSending = false
            activeRunStartedAt = nil
            activeRunTask = nil
            activeStreamingMessageID = nil
        }

        return true
    }

    private func formatCalendarQueryResult(
        _ events: [NativeCalendarEventSummary],
        query: DeterministicCalendarQuery
    ) -> String {
        let rangeText = query.formattedRange()
        guard !events.isEmpty else {
            return "I don’t see anything on your calendar for \(query.label) (\(rangeText))."
        }

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale.current
        dayFormatter.timeZone = Calendar.current.timeZone
        dayFormatter.dateStyle = .full
        dayFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale.current
        timeFormatter.timeZone = Calendar.current.timeZone
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        var lines: [String] = []
        lines.append("Here’s what’s on your calendar for \(query.label) (\(rangeText)):")

        var lastDay: String?
        for event in events {
            let day = dayFormatter.string(from: event.startDate)
            if day != lastDay {
                lines.append("")
                lines.append("**\(day)**")
                lastDay = day
            }

            let timeText: String
            if event.isAllDay {
                timeText = "All day"
            } else {
                timeText = "\(timeFormatter.string(from: event.startDate))–\(timeFormatter.string(from: event.endDate))"
            }

            var line = "- \(timeText): \(event.title)"
            if let location = event.location, !location.isEmpty {
                line += " — \(location)"
            }
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    private func queueQuickAskFollowUp(_ text: String) {
        guard panelSizeMode == .mini else { return }
        queuedQuickAskPrompt = text
        prompt = ""
    }

    private func directTokenRecorder() -> @Sendable (String) async -> Void {
        { [weak self] token in
            await MainActor.run {
                self?.appendDirectStreamToken(token)
            }
        }
    }

    private func appendDirectStreamToken(_ token: String) {
        if activeStreamingMessageID == nil {
            let message = GhostMessage(role: .ghost, text: "")
            activeStreamingMessageID = message.id
            messages.append(message)
        }

        guard let activeStreamingMessageID,
              let index = messages.firstIndex(where: { $0.id == activeStreamingMessageID })
        else {
            return
        }

        messages[index].text += token
        lastResponseCharacterCount = messages[index].text.count
    }

    private func finishDirectStream(text: String, metadata: GhostRunMetadata) {
        guard let activeStreamingMessageID,
              let index = messages.firstIndex(where: { $0.id == activeStreamingMessageID })
        else {
            messages.append(GhostMessage(role: .ghost, text: text, runMetadata: metadata))
            return
        }

        messages[index].text = text
        messages[index].runMetadata = metadata
        schedulePersist()
    }

    func toggleDictation() {
        speechRecognizer.toggle { [weak self] transcript in
            guard let self else { return }
            prompt = transcript
        }
    }

    func clearConversation() {
        prompt = ""
        queuedQuickAskPrompt = nil
        messages = []
        activityEntries = []
        currentIntent = .idle
        lastRunStatus = .idle
        activeRunStartedAt = nil
        activeProcessIdentifier = nil
        clearTaskTimeline()
    }

    // MARK: - Conversation history persistence

    private func restoreMostRecentConversation() {
        guard let first = conversations.first else { return }
        currentConversationID = first.id
        messages = first.messages.map { $0.toGhostMessage() }
    }

    func toggleHistory() {
        isHistoryVisible.toggle()
        if isHistoryVisible {
            isDocumentStudioVisible = false
            isPromptLibraryVisible = false
        }
    }

    func startNewConversation() {
        guard !isSending else { return }
        persistCurrentConversation()
        clearConversation()
        currentConversationID = nil
        isHistoryVisible = false
    }

    func loadConversation(id: UUID) {
        guard !isSending else { return }
        guard let conversation = conversations.first(where: { $0.id == id }) else { return }
        persistCurrentConversation()
        currentConversationID = conversation.id
        messages = conversation.messages.map { $0.toGhostMessage() }
        activityEntries = []
        currentIntent = .idle
        lastRunStatus = .idle
        clearTaskTimeline()
        isHistoryVisible = false
    }

    func deleteConversation(id: UUID) {
        historyStore.delete(id: id)
        conversations.removeAll { $0.id == id }
        if currentConversationID == id {
            currentConversationID = nil
            clearConversation()
        }
    }

    func persistCurrentConversation() {
        guard !messages.isEmpty else {
            if let id = currentConversationID {
                historyStore.delete(id: id)
                conversations.removeAll { $0.id == id }
            }
            return
        }

        let id = currentConversationID ?? UUID()
        let title = conversationTitle()
        let now = Date()
        let persisted = PersistedConversation(
            id: id,
            title: title,
            createdAt: conversations.first(where: { $0.id == id })?.createdAt ?? now,
            updatedAt: now,
            messages: messages.map { PersistedMessage(from: $0) }
        )
        historyStore.save(persisted)
        currentConversationID = id
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations[index] = persisted
        } else {
            conversations.insert(persisted, at: 0)
        }
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }

    private func conversationTitle() -> String {
        let firstUser = messages.first(where: { $0.role == .user })?.text ?? "New conversation"
        let trimmed = firstUser.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return String(trimmed.prefix(60))
    }

    func schedulePersist() {
        persistenceDebounceTask?.cancel()
        persistenceDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run { self?.persistCurrentConversation() }
        }
    }

    // MARK: - Document Studio

    func toggleDocumentStudio() {
        isDocumentStudioVisible.toggle()
        if isDocumentStudioVisible {
            isHistoryVisible = false
            isPromptLibraryVisible = false
        }
    }

    func openProducedDocument(_ document: GhostProducedDocument) {
        NSWorkspace.shared.open(URL(fileURLWithPath: document.path))
    }

    func revealProducedDocument(_ document: GhostProducedDocument) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: document.path)])
    }

    func revealDocumentOutputFolder() {
        ensureDocumentOutputDirectory()
        NSWorkspace.shared.activateFileViewerSelecting([documentOutputDirectoryURL])
    }

    func copyProducedDocumentPath(_ document: GhostProducedDocument) {
        ClipboardService().writeText(document.path)
        recordActivity(GhostActivityEntry(kind: .info, title: "Copied", detail: "Document path copied."))
    }

    func clearProducedDocuments() {
        producedDocuments.removeAll()
    }

    private static func loadProducedDocuments() -> [GhostProducedDocument] {
        guard let data = UserDefaults.standard.data(forKey: producedDocumentsDefaultsKey),
              let decoded = try? JSONDecoder().decode([GhostProducedDocument].self, from: data)
        else {
            return []
        }

        return decoded
    }

    private func persistProducedDocuments() {
        guard let data = try? JSONEncoder().encode(producedDocuments) else { return }
        UserDefaults.standard.set(data, forKey: Self.producedDocumentsDefaultsKey)
    }

    @discardableResult
    private func registerProducedDocument(path rawPath: String, source: String) -> GhostProducedDocument? {
        let url = resolvedPath(rawPath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }

        let title = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        let kind: String
        if isDirectory.boolValue {
            kind = "Folder"
        } else {
            let ext = url.pathExtension.uppercased()
            kind = ext.isEmpty ? source : ext
        }

        let document = GhostProducedDocument(
            title: title,
            path: url.path,
            kind: kind,
            createdAt: Date(),
            verified: true
        )

        producedDocuments.removeAll { $0.path == document.path }
        producedDocuments.insert(document, at: 0)
        producedDocuments = Array(producedDocuments.prefix(80))
        return document
    }

    private func registerProducedDocuments(from output: String, source: String) -> [GhostProducedDocument] {
        let lines = output.components(separatedBy: .newlines)
        var documents: [GhostProducedDocument] = []
        let pathKeywords = ["saved", "created", "wrote", "written", "exported", "path:", "file:"]

        for line in lines {
            let lower = line.lowercased()
            guard pathKeywords.contains(where: { lower.contains($0) }) else { continue }

            for path in likelyFilePaths(in: line) {
                if let document = registerProducedDocument(path: path, source: source),
                   !documents.contains(where: { $0.path == document.path }) {
                    documents.append(document)
                }
            }
        }

        return documents
    }

    private func likelyFilePaths(in text: String) -> [String] {
        let pattern = #"(?:(?:~|/Users|/Applications|/tmp|/var|/private)/[^\s`"')\]]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        return regex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty
        }
    }

    // MARK: - Message actions

    func copyMessage(id: GhostMessage.ID) {
        guard let message = messages.first(where: { $0.id == id }) else { return }
        ClipboardService().writeText(message.text)
        recordActivity(GhostActivityEntry(kind: .info, title: "Copied", detail: "Message copied to clipboard."))
    }

    func deleteMessage(id: GhostMessage.ID) {
        messages.removeAll { $0.id == id }
        schedulePersist()
    }

    func regenerateLastResponse() {
        guard !isSending else { return }
        guard let lastIndex = messages.lastIndex(where: { $0.role == .ghost || $0.role == .system }),
              let userIndex = messages.lastIndex(where: { $0.role == .user && $0.id != messages[lastIndex].id }) else {
            return
        }
        let userText = messages[userIndex].text
        messages.removeSubrange(userIndex + 1..<messages.count)
        schedulePersist()
        prompt = userText
        send()
    }

    // MARK: - Export

    func exportConversationMarkdown() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var lines: [String] = []
        lines.append("# Ghost conversation")
        lines.append("")
        lines.append("_Exported \(formatter.string(from: Date()))_")
        lines.append("")
        for message in messages {
            let heading: String
            switch message.role {
            case .user: heading = "You"
            case .ghost: heading = "Ghost"
            case .system: heading = "Status"
            }
            lines.append("### \(heading)")
            lines.append("")
            lines.append(message.text)
            lines.append("")
            if let meta = message.runMetadata {
                lines.append("> \(meta.summaryLine)")
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    func exportConversationToDesktop() {
        let markdown = exportConversationMarkdown()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let fileName = "Ghost-\(formatter.string(from: Date())).md"
        let desktop = URL(fileURLWithPath: NSHomeDirectory() + "/Desktop").appendingPathComponent(fileName)
        do {
            try markdown.write(to: desktop, atomically: true, encoding: .utf8)
            registerProducedDocument(path: desktop.path, source: "Conversation export")
            recordActivity(GhostActivityEntry(kind: .success, title: "Exported", detail: "Conversation saved to Desktop as \(fileName)."))
            messages.append(GhostMessage(role: .system, text: "Exported conversation to Desktop as \(fileName)."))
            schedulePersist()
        } catch {
            recordActivity(GhostActivityEntry(kind: .error, title: "Export failed", detail: error.localizedDescription))
        }
    }

    // MARK: - Prompt library

    func togglePromptLibrary() {
        isPromptLibraryVisible.toggle()
        if isPromptLibraryVisible {
            isHistoryVisible = false
            isDocumentStudioVisible = false
        }
    }

    func useSavedPrompt(_ prompt: SavedPrompt) {
        self.prompt = prompt.body
        isPromptLibraryVisible = false
    }

    func saveCurrentPromptAsLibraryEntry() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        savedPrompts = promptLibrary.add(title: String(text.prefix(40)), body: text)
    }

    @discardableResult
    func addPromptToLibrary(title: String, body: String) -> [SavedPrompt] {
        savedPrompts = promptLibrary.add(title: title, body: body)
        return savedPrompts
    }

    func deleteSavedPrompt(id: UUID) {
        savedPrompts = promptLibrary.remove(id: id)
    }

    var terminalPromptPrefix: String {
        projectContextService.promptPrefix(for: workingDirectoryPath)
    }

    func terminalLinePrefix(for role: GhostMessage.Role) -> String {
        switch role {
        case .user: terminalPromptPrefix
        case .ghost: "ghost"
        case .system: "[system]"
        }
    }

    func toggleGhostCodeOutputMode() {
        ghostCodeOutputMode = ghostCodeOutputMode == .terminal ? .markdown : .terminal
    }

    func selectInterfaceMode(_ mode: GhostInterfaceMode) {
        switch mode {
        case .glass:
            interfacePreference = .glass
            panelMode = .chat
            panelSizeMode = .normal
        case .terminal:
            interfacePreference = .terminal
            panelMode = .chat
            panelSizeMode = .normal
        }
    }

    func setAdaptiveInterface() {
        interfacePreference = .adaptive
    }

    private func enforceInterfacePreference() {
        switch interfacePreference {
        case .adaptive:
            break
        case .glass:
            interfaceMode = .glass
            panelMode = .chat
            panelSizeMode = .normal
        case .terminal:
            interfaceMode = .terminal
            panelMode = .chat
            panelSizeMode = .normal
        }
    }

    private func setInterfaceModeAutomatically(_ mode: GhostInterfaceMode) {
        guard interfacePreference == .adaptive else {
            enforceInterfacePreference()
            return
        }

        if interfaceMode != mode {
            interfaceMode = mode
            panelMode = .chat
            panelSizeMode = .normal
        }
    }

    private func applyInterfaceRouting(for intent: GhostDetectedIntent, engine: ExecutionEngine) {
        switch interfacePreference {
        case .glass:
            interfaceMode = .glass
            return

        case .terminal:
            interfaceMode = .terminal
            return

        case .adaptive:
            break
        }

        let shouldUseTerminal = engine == .ghostAgent && intent.kind.shouldUseTerminalUI

        setInterfaceModeAutomatically(shouldUseTerminal ? .terminal : .glass)
    }

    func toggleActivity() {
        isActivityVisible.toggle()
    }

    func clearActivity() {
        activityEntries = []
    }

    func cancelCurrentRun() {
        activeRunTask?.cancel()
        activeRunTask = nil
        activeStreamingMessageID = nil
        queuedQuickAskPrompt = nil
        ghostClient.cancelRunningMenuRuns()
        isSending = false
        lastRunStatus = .stopped
        activeRunStartedAt = nil
        activeProcessIdentifier = nil

        stopTaskTimeline()
        lastRunFinishedAt = Date()
        if let startedAt = lastRunStartedAt {
            lastRunDuration = Date().timeIntervalSince(startedAt)
        }
        lastRunStatus = .stopped
        recordActivity(GhostActivityEntry(kind: .error, title: "Stopped", detail: "Current Ghost process was terminated."))
        messages.append(GhostMessage(role: .system, text: visibleInterfaceMode == .terminal ? "[stopped]\nCurrent run stopped." : "Stopped current Ghost run."))
    }

    func selectProviderManually(_ provider: GhostProvider) {
        selectedProvider = provider
        if provider == .ollama {
            refreshOllamaModels()
        } else if provider == .openCodeGo {
            refreshOpenCodeGoModels()
        }
    }

    func useClipboard() {
        if let text = ClipboardService().readText() {
            prompt = text
        }
    }

    func attachPastedScreenshot(_ image: NSImage) {
        guard let data = pngData(from: image) else {
            messages.append(GhostMessage(role: .system, text: "Could not read the pasted screenshot."))
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let attachment = GhostImageAttachment(
            data: data,
            mimeType: "image/png",
            filename: "ghost-screenshot-\(formatter.string(from: Date())).png",
            createdAt: Date()
        )
        pendingImageAttachment = attachment
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt = "Interpret the pasted screenshot."
        }
        recordActivity(
            GhostActivityEntry(
                kind: .info,
                title: "Screenshot attached",
                detail: "\(attachment.filename) · \(attachment.sizeDescription)"
            )
        )
    }

    func clearPendingImageAttachment() {
        pendingImageAttachment = nil
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    func enqueueCurrentPrompt() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            messages.append(GhostMessage(role: .system, text: "Type a task first, then press Queue."))
            return
        }
        taskQueue.append(QueuedHarnessTask(prompt: text))
        prompt = ""
        messages.append(GhostMessage(role: .system, text: "Queued task: \(text)"))
    }

    func runQueuedTasks() {
        guard !isRunningQueue, !taskQueue.isEmpty else { return }
        isRunningQueue = true
        Task {
            for index in taskQueue.indices {
                guard taskQueue[index].status == .pending else { continue }
                taskQueue[index].status = .running
                let task = taskQueue[index]
                activeRunStartedAt = Date()
                lastRunStartedAt = Date()
                lastPromptCharacterCount = task.prompt.count
                lastRunStatus = .running
                activeProcessIdentifier = nil
                let clipboardText = shouldReadClipboard(for: task.prompt) ? ClipboardService().readText() : nil
                let routingPrompt = contextualPromptForRouting(task.prompt)

                let detectedIntent = intentRouter.detect(
                    prompt: routingPrompt,
                    includeClipboard: includeClipboard,
                    workspaceRoot: workspaceRootURL,
                    hasClipboardText: clipboardText?.isEmpty == false
                )

                let runPrompt = executionPromptForRun(
                    rawPrompt: task.prompt,
                    routingPrompt: routingPrompt
                )

                let runEngine = resolvedEngine(for: routingPrompt, intent: detectedIntent)

                applyAdaptiveRoute(for: detectedIntent, engine: runEngine)

                currentIntent = detectedIntent
                activeContextChips = contextChips(
                    for: detectedIntent,
                    prompt: routingPrompt,
                    runEngine: runEngine,
                    hasClipboardText: clipboardText?.isEmpty == false
                )
                beginTaskTimeline(
                    prompt: task.prompt,
                    intent: detectedIntent,
                    runEngine: runEngine
                )

                updateLastTaskContext(
                    rawPrompt: task.prompt,
                    intent: detectedIntent,
                    runEngine: runEngine
                )
                let finalPrompt = promptWithEffort(
                    runPrompt,
                    clipboard: includeClipboard || detectedIntent.usesClipboard ? clipboardText : nil,
                    conversationContext: recentConversationContext(),
                    detectedIntent: detectedIntent,
                    runEngine: runEngine
                )
                let snapshotSettings = runSettings()
                let snapshotRunEngine = runEngine
                let snapshotRunModeLabel = runModeLabel(for: snapshotRunEngine)
                let snapshotStartedAt = Date()
                let userMessage = GhostMessage(role: .user, text: task.prompt)
                messages.append(userMessage)
                taskTimelineAnchorMessageID = userMessage.id
                do {
                    let result = try await runHarness(
                        engine: snapshotRunEngine,
                        prompt: finalPrompt,
                        settings: snapshotSettings,
                        onActivity: activityRecorder()
                    )
                    taskQueue[index].status = .done
                    let finishedAt = Date()
                    lastRunFinishedAt = finishedAt
                    lastRunDuration = finishedAt.timeIntervalSince(snapshotStartedAt)
                    lastExitStatus = result.exitStatus
                    lastRunStatus = result.exitStatus == 0 ? .completed : .failed
                    lastResponseCharacterCount = result.output.count
                    let metadata = GhostRunMetadata(
                        providerTitle: result.provider.title,
                        providerRawValue: result.provider.ghostProvider,
                        model: result.model,
                        effortTitle: result.effortMode.title(for: result.provider),
                        effortRawValue: result.effortMode.rawValue,
                        reasoningEffort: result.reasoningEffort,
                        maxTurns: result.maxTurns,
                        maxTokens: result.maxTokens,
                        approvalMode: snapshotRunModeLabel,
                        startedAt: snapshotStartedAt,
                        finishedAt: finishedAt,
                        workingDirectory: result.workingDirectory,
                        launchedArguments: result.launchedArguments
                    )
                    applyProgressMarkers(from: result.output)

                    let cleanedOutput = stripGhostProgressMarkers(
                        from: result.output.isEmpty ? "Ghost finished but returned no output." : result.output
                    )

                    let responseText = formatGhostResponse(cleanedOutput)

                    finishTaskTimeline(
                        success: result.exitStatus == 0,
                        summary: result.exitStatus == 0 ? "Queued task finished" : "Queued task finished with errors"
                    )

                    messages.append(GhostMessage(role: .ghost, text: responseText, runMetadata: metadata))
                } catch {
                    taskQueue[index].status = .failed
                    lastRunFinishedAt = Date()
                    if let startedAt = lastRunStartedAt {
                        lastRunDuration = Date().timeIntervalSince(startedAt)
                    }
                    lastRunStatus = .failed

                    finishTaskTimeline(
                        success: false,
                        summary: error.localizedDescription
                    )

messages.append(GhostMessage(role: .system, text: error.localizedDescription))
            }
            schedulePersist()
            }
            activeRunStartedAt = nil
            isRunningQueue = false
        }
    }

    func clearQueue() {
        taskQueue.removeAll()
    }

    private func shouldReadClipboard(for prompt: String) -> Bool {
        let lower = prompt.lowercased()
        return includeClipboard || containsAny(lower, ["clipboard", "paste", "pasted", "copied", "copy this", "copy that"])
    }

    private func shouldResolveFileContexts(for prompt: String, intent: GhostDetectedIntent) -> Bool {
        if prompt.contains("@") {
            return true
        }

        switch intent.kind {
        case .localFiles, .fileSummary, .createArtifact, .organizeFiles, .coding, .debugging, .codeReview, .shell:
            return true
        case .answer, .research, .screenshotOCR, .clipboardAction, .automation:
            return false
        }
    }

    var activeLocalAgentKind: LocalAgentKind {
        useHermesAgent ? .hermes : .ghost
    }

    var activeLocalAgentExecutablePath: String {
        if useHermesAgent {
            return hermesExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? detectedHermesPath
                ?? LocalAgentKind.hermes.defaultExecutablePath
        }

        return LocalAgentKind.ghost.defaultExecutablePath
    }

    var activeLocalAgentExecutableURL: URL {
        URL(fileURLWithPath: activeLocalAgentExecutablePath)
    }

    var isHermesAvailable: Bool {
        guard let path = resolvedHermesPath else { return false }
        return FileManager.default.isExecutableFile(atPath: path)
    }

    var isHermesConnected: Bool {
        useHermesAgent && isHermesAvailable
    }

    var resolvedHermesPath: String? {
        let saved = hermesExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !saved.isEmpty {
            return saved
        }

        return detectedHermesPath
    }

    var localAgentSetupWarning: String? {
        if useHermesAgent {
            if isHermesConnected {
                return nil
            }

            return "Hermes Agent is selected but the app cannot find the Hermes executable. Choose the Hermes binary, reinstall Hermes, or switch to Direct API."
        }

        if !FileManager.default.isExecutableFile(atPath: LocalAgentKind.ghost.defaultExecutablePath) {
            return "No local tool-calling agent is connected. Simple answers can still use Direct API, but files, shell, coding, and Mac actions need Hermes Agent."
        }

        return nil
    }

    func connectDetectedHermes() {
        guard let path = resolvedHermesPath else {
            hermesStatusMessage = "Hermes was not found. Install Hermes or choose the Hermes binary manually."
            return
        }

        hermesExecutablePath = path
        useHermesAgent = true
        enginePreference = .auto
        hermesStatusMessage = "Connected to Hermes Agent at \(path)."
    }

    func disconnectHermes() {
        useHermesAgent = false
        hermesStatusMessage = "Hermes disconnected. Direct API still works for simple answers."
    }

    func chooseHermesBinary() {
        let panel = NSOpenPanel()
        panel.title = "Choose Hermes Executable"
        panel.prompt = "Connect"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                self?.hermesExecutablePath = url.path
                self?.detectedHermesPath = url.path
                self?.useHermesAgent = true
                self?.hermesStatusMessage = "Connected to Hermes Agent at \(url.path)."
            }
        }
    }

    func detectHermesAgent() {
        guard !isCheckingHermes else { return }

        isCheckingHermes = true
        hermesStatusMessage = nil

        let savedPath = hermesExecutablePath

        Task {
            let foundPath = await Self.findHermesExecutable(savedPath: savedPath)

            detectedHermesPath = foundPath

            if let foundPath {
                if hermesExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    hermesExecutablePath = foundPath
                }

                hermesStatusMessage = useHermesAgent
                    ? "Hermes Agent connected at \(foundPath)."
                    : "Hermes Agent found at \(foundPath). Connect it to enable local tools."
            } else {
                hermesStatusMessage = "Hermes Agent was not found on this Mac."
            }

            isCheckingHermes = false
        }
    }

    func runHermesDoctor() {
        guard let path = resolvedHermesPath else {
            hermesStatusMessage = "Hermes was not found. Install Hermes or choose the binary manually."
            return
        }

        isCheckingHermes = true
        hermesStatusMessage = "Running hermes doctor..."

        Task {
            let result = await Self.runProbe(executablePath: path, arguments: ["doctor"])
            hermesStatusMessage = result
            isCheckingHermes = false
        }
    }

    nonisolated private static func findHermesExecutable(savedPath: String) async -> String? {
        let expandedSavedPath = (savedPath as NSString).expandingTildeInPath
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var candidates: [String] = []

        if !expandedSavedPath.isEmpty {
            candidates.append(expandedSavedPath)
        }

        candidates.append(contentsOf: [
            "\(NSHomeDirectory())/.local/bin/hermes",
            "\(NSHomeDirectory())/.hermes/hermes-agent/venv/bin/hermes",
            "\(NSHomeDirectory())/.hermes/hermes-agent/.venv/bin/hermes",
            "/opt/homebrew/bin/hermes",
            "/usr/local/bin/hermes",
            "/usr/bin/hermes"
        ])

        let fileManager = FileManager.default

        for candidate in candidates {
            let expanded = (candidate as NSString).expandingTildeInPath
            if fileManager.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }

        return await whichHermes()
    }

    nonisolated private static func whichHermes() async -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "hermes"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return output.isEmpty ? nil : output
    }

    nonisolated private static func runProbe(executablePath: String, arguments: [String]) async -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Could not run Hermes: \(error.localizedDescription)"
        }

        let output = String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let error = String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let combined = [output, error]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if process.terminationStatus == 0 {
            return combined.isEmpty ? "Hermes doctor completed successfully." : combined
        }

        return combined.isEmpty
            ? "Hermes doctor exited with status \(process.terminationStatus)."
            : combined
    }

    func showOnboarding() {
        panelMode = .chat
        panelSizeMode = .normal
        onboardingStep = .welcome
        isOnboardingPresented = true
    }

    func advanceOnboarding() {
        let steps = OnboardingStep.allCases
        guard let index = steps.firstIndex(of: onboardingStep) else {
            onboardingStep = .welcome
            return
        }

        if index >= steps.count - 1 {
            finishOnboarding(seedPrompt: "What can you help me do in Ghost?")
        } else {
            onboardingStep = steps[index + 1]
        }
    }

    func retreatOnboarding() {
        let steps = OnboardingStep.allCases
        guard let index = steps.firstIndex(of: onboardingStep), index > 0 else {
            return
        }

        onboardingStep = steps[index - 1]
    }

    func skipOnboarding() {
        finishOnboarding(seedPrompt: nil)
    }

    func finishOnboarding(seedPrompt: String?) {
        UserDefaults.standard.set(true, forKey: Self.onboardingCompleteDefaultsKey)

        isOnboardingPresented = false
        onboardingStep = .welcome
        panelMode = .chat

        if let seedPrompt {
            let cleaned = seedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                prompt = cleaned
            }
        }

        if messages.isEmpty {
            messages.append(
                GhostMessage(
                    role: .system,
                    text: "Setup complete. Type a request, press Command-Return, or use Option-Space to bring Ghost back anytime."
                )
            )
        }
    }

    func toggleSettings() {
        panelMode = panelMode == .chat ? .settings : .chat
    }

    var ollamaBaseURL: URL {
        URL(string: ollamaBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines))
            ?? URL(string: "http://localhost:11434")!
    }

    func refreshOllamaModels() {
        guard !isRefreshingOllamaModels else { return }

        isRefreshingOllamaModels = true
        settingsMessage = nil

        Task {
            do {
                let models = try await localModelsService.fetchOllamaModels(baseURL: ollamaBaseURL)
                ollamaModels = models

                if !models.contains(where: { $0.id == selectedOllamaModel }),
                   let first = models.first {
                    selectedOllamaModel = first.id
                }

                settingsMessage = "Ollama models refreshed."
            } catch {
                settingsMessage = "Could not reach Ollama. Start Ollama, pull a model, then try again. \(error.localizedDescription)"
            }

            isRefreshingOllamaModels = false
        }
    }

    func refreshOpenCodeGoModels() {
        guard !isRefreshingOpenCodeGoModels else { return }

        isRefreshingOpenCodeGoModels = true
        settingsMessage = nil

        let apiKey = secretsService.read(for: .openCodeGo)
            ?? ProcessInfo.processInfo.environment[ProviderAPIKey.openCodeGo.environmentKey]
            ?? ""

        Task {
            do {
                let models = try await localModelsService.fetchOpenCodeGoModels(apiKey: apiKey)
                openCodeGoModels = models

                if !models.contains(where: { $0.id == selectedOpenCodeGoModel }),
                   let first = models.first {
                    selectedOpenCodeGoModel = first.id
                }

                settingsMessage = "OpenCode Go models refreshed."
            } catch {
                settingsMessage = error.localizedDescription
            }

            isRefreshingOpenCodeGoModels = false
        }
    }

    func refreshLocalModels() {
        guard !isRefreshingLocalModels else { return }
        isRefreshingLocalModels = true
        settingsMessage = nil

        Task {
            do {
                let models = try await localModelsService.fetchModels()
                localModels = models
                if !models.contains(where: { $0.id == selectedLocalModel }), let first = models.first {
                    selectedLocalModel = first.id
                }
                settingsMessage = "Local models refreshed."
            } catch {
                settingsMessage = error.localizedDescription
            }
            isRefreshingLocalModels = false
        }
    }

    func saveAPIKeys() {
        do {
            var savedOpenCodeGoKey = false
            for provider in ProviderAPIKey.allCases {
                let draft = apiKeyDrafts[provider]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !draft.isEmpty {
                    try secretsService.save(draft, for: provider)
                    if provider == .openCodeGo {
                        savedOpenCodeGoKey = true
                    }
                }
            }
            loadSavedAPIKeyState(clearDrafts: true)
            settingsMessage = "API keys saved."
            if selectedProvider == .openCodeGo && (savedOpenCodeGoKey || savedAPIKeyProviders.contains(.openCodeGo)) {
                refreshOpenCodeGoModels()
            }
        } catch {
            settingsMessage = error.localizedDescription
        }
    }

    func clearAPIKey(for provider: ProviderAPIKey) {
        do {
            try secretsService.clear(provider)
            apiKeyDrafts[provider] = ""
            loadSavedAPIKeyState()
            settingsMessage = "\(provider.title) key cleared."
        } catch {
            settingsMessage = error.localizedDescription
        }
    }

    func model(for provider: GhostProvider) -> String {
        switch provider {
        case .lmStudio:
            selectedLocalModel
        case .ollama:
            selectedOllamaModel
        case .openCodeGo:
            selectedOpenCodeGoModel
        case .claude:
            "claude-sonnet-4-6"
        case .gemini:
            "gemini-3.5-flash"
        case .deepSeek:
            selectedDeepSeekModel
        }
    }

    var effectiveProvider: GhostProvider {
        selectedProvider
    }

    var runModeLabel: String {
        runModeLabel(for: executionEngine)
    }

    private func runModeLabel(for engine: ExecutionEngine) -> String {
        switch engine {
        case .ghostAgent:
            approvalMode.title
        case .directAPI:
            "Direct API"
        }
    }

    /// A user-facing warning for the current engine + provider combination,
    /// or nil when nothing needs flagging.
    var engineWarning: String? {
        if executionEngine == .ghostAgent {
            return localAgentSetupWarning
        }

        switch selectedProvider {
        case .lmStudio:
            return "Direct API uses LM Studio at localhost:1234. Local models get Ghost-managed tools for web, workspace files, text-file creation, read-only commands, reminders, and calendar read/create actions."

        case .ollama:
            return "Direct API uses Ollama at \(ollamaBaseURLString). Local models get Ghost-managed tools for web, workspace files, text-file creation, read-only commands, reminders, and calendar read/create actions."

        case .claude, .gemini, .deepSeek, .openCodeGo:
            if directAPIKey(for: selectedProvider) == nil {
                return "No saved API key for \(selectedProvider.title). Add one under API Keys below."
            }

            if !isHermesConnected {
                return "Direct API can answer simple questions and local models can use Ghost-managed tools for web, workspace files, text-file creation, read-only commands, reminders, and calendar read/create actions. Broad Mac actions, screenshots/OCR, binary documents, and coding edits still need Hermes Agent."
            }

            return "Direct API is available for simple answers and Ghost-managed local-model tools. Hermes Agent is connected for broader Mac tools."
        }
    }

    var modelDisplayName: String {
        switch selectedProvider {
        case .deepSeek:
            DeepSeekModel(rawValue: selectedDeepSeekModel)?.shortTitle ?? selectedDeepSeekModel
        case .lmStudio:
            selectedLocalModel
        case .ollama:
            selectedOllamaModel
        case .openCodeGo:
            selectedOpenCodeGoModel
        case .claude, .gemini:
            model(for: selectedProvider)
        }
    }

    /// Routes a run to either the local Ghost CLI or the provider's HTTP API.
    private func runHarness(
        engine: ExecutionEngine,
        prompt: String,
        settings: GhostRunSettings,
        imageAttachment: GhostImageAttachment? = nil,
        onActivity: @escaping @Sendable (GhostActivityEntry) -> Void,
        onToken: (@Sendable (String) async -> Void)? = nil
    ) async throws -> GhostRunResult {
        let effectiveEngine: ExecutionEngine

        if settings.provider.isLocal, engine == .ghostAgent {
            // Absolute provider-isolation rule:
            // when LM Studio/Ollama is selected, this app must never launch
            // Hermes/Ghost Agent unless that local-agent backend has been
            // explicitly verified. Existing Hermes installations can read
            // persisted DeepSeek config outside this Process environment, so
            // environment scrubbing alone is not enough. Force local providers
            // through Ghost's managed Direct API tool loop instead.
            effectiveEngine = .directAPI
            onActivity(
                GhostActivityEntry(
                    kind: .info,
                    title: "Local provider guard",
                    detail: "Blocked Agent route and used \(settings.provider.title) Direct API instead. DeepSeek was not launched."
                )
            )
        } else {
            effectiveEngine = engine
        }

        switch effectiveEngine {
        case .ghostAgent:
            return try await ghostClient.send(prompt, settings: settings, onActivity: onActivity)

        case .directAPI:
            let key = directAPIKey(for: settings.provider) ?? ""
            return try await directAPIClient.send(
                prompt,
                imageAttachment: imageAttachment,
                settings: settings,
                apiKey: key,
                onActivity: onActivity,
                onToken: onToken
            )
        }
    }

    private func resolvedEngine(for prompt: String, intent: GhostDetectedIntent) -> ExecutionEngine {
        // Hard privacy/provider-isolation rule:
        // LM Studio and Ollama are local providers. Selecting one of them means
        // Ghost should talk to that local OpenAI-compatible endpoint only. Do
        // not route to Hermes/Ghost Agent, because those CLIs may still have
        // persisted DeepSeek defaults and can call DeepSeek even when the UI
        // shows LM Studio/Ollama. Direct API has Ghost-managed local tools for
        // web, files, text artifacts, clipboard, read-only shell, reminders,
        // and calendar read/create actions. Unsupported tasks should fail or
        // ask for a verified local agent, never silently fall back to DeepSeek.
        if usesLocalProvider(selectedProvider) {
            return .directAPI
        }

        switch enginePreference {
        case .forceGhost:
            return .ghostAgent

        case .forceDirect:
            return .directAPI

        case .auto:
            if let context = lastTaskContext,
               context.isFresh,
               isFollowUpPrompt(prompt),
               context.route == .ghostAgent {
                return .ghostAgent
            }

            return intentRouter.requiresGhostTools(prompt: prompt, intent: intent)
                ? .ghostAgent
                : .directAPI
        }
    }

    private func usesLocalProvider(_ provider: GhostProvider) -> Bool {
        provider.isLocal
    }

    private func localDirectAPIHandles(prompt: String, intent: GhostDetectedIntent) -> Bool {
        switch intent.kind {
        case .answer, .research, .clipboardAction, .automation, .localFiles, .fileSummary, .coding, .debugging, .codeReview:
            return true

        case .createArtifact:
            let ext = intent.inferredFileExtension?.lowercased()
            let binaryExtensions: Set<String> = ["pdf", "docx", "pptx", "xlsx", "pages", "key", "numbers", "zip", "png", "jpg", "jpeg", "gif", "webp"]
            return ext.map { !binaryExtensions.contains($0) } ?? true

        case .shell:
            return isReadOnlyShellPrompt(prompt)

        case .screenshotOCR, .organizeFiles:
            return false
        }
    }

    private func isReadOnlyShellPrompt(_ prompt: String) -> Bool {
        let lower = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var stripped = lower
        for prefix in ["terminal ", "shell ", "run "] where stripped.hasPrefix(prefix) {
            stripped = String(stripped.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let allowedPrefixes = [
            "pwd", "ls", "find", "grep", "sed", "cat", "wc", "head", "tail",
            "git status", "git diff", "git log", "git show", "git branch"
        ]
        let blocked = [
            " rm ", " mv ", " cp ", " mkdir ", " rmdir ", " touch ", " chmod ", " chown ",
            " sudo ", " curl ", " wget ", " npm ", " pnpm ", " yarn ", " pip ", " python ",
            " python3 ", " swift ", " xcodebuild ", " open ", " osascript ", " kill ", " pkill ",
            ";", "&&", "||", "|", ">", "<", "`", "$"
        ]
        let padded = " " + stripped + " "
        guard !blocked.contains(where: { padded.contains($0) }) else { return false }
        return allowedPrefixes.contains { stripped == $0 || stripped.hasPrefix($0 + " ") }
    }

    private func applyAdaptiveRoute(for intent: GhostDetectedIntent, engine: ExecutionEngine) {
        executionEngine = engine

        let shouldUseTerminal = engine == .ghostAgent && intent.kind.shouldUseTerminalUI

        if shouldUseTerminal {
            setInterfaceModeAutomatically(.terminal)
        } else if visibleInterfaceMode == .terminal && !shouldUseTerminal {
            setInterfaceModeAutomatically(.glass)
        }

        if let preferredAgentMode = intent.kind.preferredAgentMode, engine == .ghostAgent {
            codeAgentMode = preferredAgentMode
        }
    }

    private func contextChips(
        for intent: GhostDetectedIntent,
        prompt: String,
        runEngine: ExecutionEngine,
        hasClipboardText: Bool
    ) -> [GhostContextChip] {
        var chips = intentRouter.contextChips(
            for: intent,
            includeClipboard: includeClipboard,
            hasClipboardText: hasClipboardText,
            workspaceRoot: workspaceRootURL,
            activityCount: activityEntries.count
        )

        chips.insert(
            GhostContextChip(
                "Route",
                "\(runEngine.shortTitle) · \(routeReason(for: intent, prompt: prompt, runEngine: runEngine))",
                systemImage: runEngine.systemImage
            ),
            at: min(1, chips.count)
        )

        return chips
    }

    private func routeReason(
        for intent: GhostDetectedIntent,
        prompt: String,
        runEngine: ExecutionEngine
    ) -> String {
        switch enginePreference {
        case .forceGhost:
            if runEngine == .directAPI, usesLocalProvider(selectedProvider) {
                return "local provider override"
            }
            return "forced"

        case .forceDirect:
            return "forced"

        case .auto:
            if let context = lastTaskContext,
               context.isFresh,
               isFollowUpPrompt(prompt),
               context.route == .ghostAgent {
                return "continued task"
            }

            if runEngine == .directAPI {
                if usesLocalProvider(selectedProvider), localDirectAPIHandles(prompt: prompt, intent: intent) {
                    return intent.kind.requiresAgentTools ? "local tools" : (intent.usesWeb ? "web/text" : "answer-only")
                }

                return intent.usesWeb ? "web/text" : "answer-only"
            }

            if intent.kind.requiresAgentTools {
                return intent.kind.shortTitle
            }

            if intentRouter.requiresGhostTools(prompt: prompt, intent: intent) {
                return "local tools"
            }

            return "tools"
        }
    }

    private func beginTaskTimeline(
        prompt: String,
        intent: GhostDetectedIntent,
        runEngine: ExecutionEngine
    ) {
        ghostFallbackOutputTicks = 0
        lastTimelineAutoAdvanceAt = nil

        if runEngine == .directAPI,
           [.answer, .research, .clipboardAction].contains(intent.kind) {
            taskTimeline = .idle
            return
        }

        if runEngine == .ghostAgent {
            var timelineSteps = checklistSteps(
                for: intent,
                prompt: prompt,
                runEngine: runEngine
            ).map {
                GhostTaskStep(title: $0)
            }

            if timelineSteps.isEmpty {
                timelineSteps = [
                    GhostTaskStep(
                        title: "Prepare todo plan",
                        detail: "Waiting for live agent steps",
                        state: .running
                    )
                ]
            } else {
                timelineSteps[0].state = .running
            }

            taskTimeline = GhostTaskTimeline(
                title: titleForTask(intent: intent),
                subtitle: visibleTimelineSubtitle(prompt: prompt),
                route: "\(runEngine.shortTitle) · \(routeReason(for: intent, prompt: prompt, runEngine: runEngine))",
                steps: timelineSteps,
                summary: nil,
                error: nil,
                startedAt: Date(),
                finishedAt: nil,
                lastUpdatedAt: Date(),
                isVisible: true,
                isWaitingForGhostPlan: true,
                isUsingGhostPlan: false,
                pendingGhostPlanItems: []
            )

            return
        }

        let steps = checklistSteps(
            for: intent,
            prompt: prompt,
            runEngine: runEngine
        )

        guard !steps.isEmpty else {
            taskTimeline = .idle
            return
        }

        var timelineSteps = steps.map {
            GhostTaskStep(title: $0)
        }

        timelineSteps[0].state = .running

        taskTimeline = GhostTaskTimeline(
            title: titleForTask(intent: intent),
            subtitle: visibleTimelineSubtitle(prompt: prompt),
            route: "\(runEngine.shortTitle) · \(routeReason(for: intent, prompt: prompt, runEngine: runEngine))",
            steps: timelineSteps,
            summary: nil,
            error: nil,
            startedAt: Date(),
            finishedAt: nil,
            lastUpdatedAt: Date(),
            isVisible: true,
            isWaitingForGhostPlan: false,
            isUsingGhostPlan: false,
            pendingGhostPlanItems: []
        )
    }

    private func visibleTimelineSubtitle(prompt: String) -> String {
        guard let context = lastTaskContext,
              context.isFresh,
              isFollowUpPrompt(prompt)
        else {
            return prompt
        }

        var suffix: [String] = []

        if let ext = context.fileExtension {
            suffix.append(".\(ext)")
        }

        if let destination = context.destination {
            suffix.append(destination)
        }

        if suffix.isEmpty {
            return prompt
        }

        return "\(prompt)  ·  continuing as \(suffix.joined(separator: " → "))"
    }

    private func contextualPromptForRouting(_ prompt: String) -> String {
        guard let context = lastTaskContext,
              context.isFresh,
              isFollowUpPrompt(prompt)
        else {
            return prompt
        }

        var parts: [String] = []

        parts.append("Previous task context:")
        parts.append("Kind: \(context.kind.shortTitle)")
        parts.append("Original request: \(context.originalPrompt)")

        if let fileExtension = context.fileExtension {
            parts.append("Previous output file type: .\(fileExtension)")
        }

        if let destination = context.destination {
            parts.append("Previous destination: \(destination)")
        }

        if let theme = context.lastOutputTheme {
            parts.append("Previous theme/content: \(theme)")
        }

        parts.append("")
        parts.append("Follow-up request:")
        parts.append(prompt)

        if context.isArtifactTask {
            parts.append("")
            parts.append("Interpret this as a continuation of the previous artifact task because the follow-up explicitly asks to create, edit, save, or repeat the artifact. Reuse the same file type and destination unless the user overrides them. Do not create a separate new artifact unless the user asks for another/new/copy.")
        }

        return parts.joined(separator: "\n")
    }

    private func executionPromptForRun(rawPrompt: String, routingPrompt: String) -> String {
        guard let context = lastTaskContext,
              context.isFresh,
              isFollowUpPrompt(rawPrompt)
        else {
            return rawPrompt
        }

        var lines: [String] = []

        lines.append("The user is continuing the previous task.")
        lines.append("")
        lines.append("Previous task:")
        lines.append(context.originalPrompt)

        if let fileExtension = context.fileExtension {
            lines.append("Use the same output type unless the user overrides it: .\(fileExtension)")
        }

        if let destination = context.destination {
            lines.append("Use the same save location unless the user overrides it: \(destination)")
        }

        lines.append("")
        lines.append("New request:")
        lines.append(rawPrompt)

        lines.append("")
        lines.append("Do the new request as a concrete continuation of the previous artifact/tool task. Use tools if local files are required. If the user asks to add, edit, or change something, update or extend the previous artifact rather than creating an unrelated new one. Only create a separate new artifact when the user explicitly asks for another/new/copy.")

        return lines.joined(separator: "\n")
    }

    /// Returns true only when the next prompt is asking Ghost to continue the previous
    /// artifact/tool task, not when the user is merely asking a related question.
    ///
    /// Example bug this avoids:
    /// "What is the size of ginowan" used to match the substring "now" inside
    /// "ginowan", so the previous .html task was re-injected into routing and Ghost
    /// planned another .html file. All matching below is word/phrase based.
    private func isFollowUpPrompt(_ prompt: String) -> Bool {
        let lower = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !lower.isEmpty else {
            return false
        }

        if isExplicitContinuationAction(lower) {
            return true
        }

        if isInformationalFollowUpQuestion(lower) {
            return false
        }

        let wordCount = lower.split { $0.isWhitespace || $0.isNewline }.count
        let isShortFragment = wordCount <= 8

        if isShortFragment,
           containsAnyWordOrPhrase(lower, ["another", "same", "same thing", "again"]),
           !containsAnyWordOrPhrase(lower, ["what", "where", "who", "when", "why", "how"]) {
            return true
        }

        return false
    }

    private func isExplicitContinuationAction(_ lower: String) -> Bool {
        if containsAnyWordOrPhrase(lower, [
            "now make another",
            "make another",
            "create another",
            "generate another",
            "build another",
            "do another",
            "another one",
            "same thing",
            "same as before",
            "again but",
            "now do",
            "do the same",
            "make one about",
            "make another of",
            "now make",
            "also make",
            "also create",
            "also generate",
            "use the same",
            "continue that",
            "continue it"
        ]) {
            return true
        }

        if lower.hasPrefix("make sense") {
            return false
        }

        let startsWithActionVerb = lower.range(
            of: #"^(add|include|update|edit|change|modify|remove|replace|save|export|make|create|generate|write|continue)\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil

        guard startsWithActionVerb else {
            return false
        }

        // "Add labels", "update it", and "save that to Desktop" should continue the
        // previous task. Pure information questions are filtered before this is used.
        return true
    }

    private func isInformationalFollowUpQuestion(_ lower: String) -> Bool {
        if lower.hasSuffix("?") && !isExplicitContinuationAction(lower) {
            return true
        }

        return hasLeadingWordOrPhrase(lower, [
            "what",
            "where",
            "who",
            "when",
            "why",
            "how",
            "is",
            "are",
            "was",
            "were",
            "does",
            "do",
            "did",
            "tell me",
            "explain",
            "define"
        ])
    }

    private func hasLeadingWordOrPhrase(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { needle in
            let escaped = NSRegularExpression.escapedPattern(for: needle.lowercased())
            let pattern = #"^"# + escaped + #"\b"#

            return value.range(
                of: pattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    private func containsAnyWordOrPhrase(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { needle in
            let escaped = NSRegularExpression.escapedPattern(for: needle.lowercased())
            let pattern = #"\b"# + escaped + #"\b"#

            return value.range(
                of: pattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    private func updateLastTaskContext(
        rawPrompt: String,
        intent: GhostDetectedIntent,
        runEngine: ExecutionEngine,
        output: String? = nil
    ) {
        guard intent.kind == .createArtifact || intent.kind == .coding || intent.kind == .localFiles || intent.kind == .fileSummary else {
            return
        }

        let lower = rawPrompt.lowercased()

        let destination: String?
        if lower.contains("desktop") {
            destination = "Desktop"
        } else if lower.contains("downloads") {
            destination = "Downloads"
        } else if lower.contains("documents") {
            destination = "Documents"
        } else {
            destination = lastTaskContext?.destination
        }

        let theme = extractTaskTheme(from: rawPrompt)

        lastTaskContext = GhostTaskContext(
            kind: intent.kind,
            originalPrompt: rawPrompt,
            lastOutputTheme: theme,
            fileExtension: intent.inferredFileExtension ?? lastTaskContext?.fileExtension,
            destination: destination,
            route: runEngine,
            createdAt: Date()
        )
    }

    private func extractTaskTheme(from prompt: String) -> String? {
        let lower = prompt.lowercased()

        let markers = [
            "of ",
            "about ",
            "for "
        ]

        for marker in markers {
            if let range = lower.range(of: marker) {
                let value = String(prompt[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !value.isEmpty {
                    return value
                }
            }
        }

        return prompt.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private func appendGhostTodo(id: String, title: String) {
        guard taskTimeline.isVisible else { return }

        let cleanID = cleanTodoID(id)
        let cleanTitle = cleanOneLine(title)

        guard !cleanID.isEmpty, !cleanTitle.isEmpty else { return }

        if !taskTimeline.isUsingGhostPlan {
            taskTimeline.steps.removeAll()
            taskTimeline.isWaitingForGhostPlan = false
            taskTimeline.isUsingGhostPlan = true
        }

        if taskTimeline.pendingGhostPlanItems.contains(where: { $0.id == cleanID }) {
            return
        }

        if taskTimeline.steps.contains(where: { $0.todoID == cleanID }) {
            return
        }

        taskTimeline.steps.append(
            GhostTaskStep(
                todoID: cleanID,
                title: cleanTitle,
                detail: "",
                state: .pending
            )
        )
    }

    private func commitGhostTodoPlan() {
        guard taskTimeline.isVisible else { return }

        let newSteps = taskTimeline.pendingGhostPlanItems.compactMap { item -> GhostTaskStep? in
            guard !taskTimeline.steps.contains(where: { $0.todoID == item.id }) else {
                return nil
            }

            return GhostTaskStep(
                todoID: item.id,
                title: item.title,
                detail: "",
                state: .pending
            )
        }

        if !newSteps.isEmpty {
            if !taskTimeline.isUsingGhostPlan {
                taskTimeline.steps.removeAll()
            }

            taskTimeline.steps.append(contentsOf: newSteps)
        }

        taskTimeline.isWaitingForGhostPlan = false
        taskTimeline.isUsingGhostPlan = taskTimeline.isUsingGhostPlan || !newSteps.isEmpty
        taskTimeline.pendingGhostPlanItems = []
    }

    private func startTodo(id: String, detail: String = "") {
        guard taskTimeline.isVisible else { return }

        if taskTimeline.isWaitingForGhostPlan {
            commitGhostTodoPlan()
        }

        let cleanID = cleanTodoID(id)

        for index in taskTimeline.steps.indices {
            if taskTimeline.steps[index].state == .running {
                taskTimeline.steps[index].state = .completed

                if taskTimeline.steps[index].detail.isEmpty {
                    taskTimeline.steps[index].detail = "Advanced to next step"
                }
            }
        }

        if let index = taskTimeline.steps.firstIndex(where: { $0.todoID == cleanID }) {
            taskTimeline.steps[index].state = .running

            if !detail.isEmpty {
                taskTimeline.steps[index].detail = cleanOneLine(detail)
            }

            return
        }

        taskTimeline.steps.append(
            GhostTaskStep(
                todoID: cleanID,
                title: "Working on \(cleanID)",
                detail: cleanOneLine(detail),
                state: .running
            )
        )
    }

    private func completeTodo(id: String, detail: String = "") {
        guard taskTimeline.isVisible else { return }

        if taskTimeline.isWaitingForGhostPlan {
            commitGhostTodoPlan()
        }

        let cleanID = cleanTodoID(id)

        if let index = taskTimeline.steps.firstIndex(where: { $0.todoID == cleanID }) {
            taskTimeline.steps[index].state = .completed

            if !detail.isEmpty {
                taskTimeline.steps[index].detail = cleanOneLine(detail)
            }

            return
        }

        completeMatchingOrCurrent(detail.isEmpty ? cleanID : detail)
    }

    private func failTodo(id: String, detail: String = "") {
        guard taskTimeline.isVisible else { return }

        if taskTimeline.isWaitingForGhostPlan {
            commitGhostTodoPlan()
        }

        let cleanID = cleanTodoID(id)

        if let index = taskTimeline.steps.firstIndex(where: { $0.todoID == cleanID }) {
            taskTimeline.steps[index].state = .failed

            if !detail.isEmpty {
                taskTimeline.steps[index].detail = cleanOneLine(detail)
            }

            taskTimeline.error = cleanOneLine(detail.isEmpty ? "Task failed" : detail)
            return
        }

        handleTimelineFailure(detail.isEmpty ? "Task failed" : detail)
    }

    private func parseTodoPayload(_ value: String) -> (id: String, text: String)? {
        let parts = value
            .split(separator: "|", maxSplits: 1)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        guard parts.count == 2 else { return nil }

        let id = cleanTodoID(parts[0])
        let text = cleanOneLine(parts[1])

        guard !id.isEmpty, !text.isEmpty else { return nil }

        return (id, text)
    }

    private func cleanTodoID(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9_-]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleTimelineFailure(_ message: String) {
        guard taskTimeline.isVisible else { return }

        if let runningIndex = taskTimeline.steps.firstIndex(where: { $0.state == .running }) {
            taskTimeline.steps[runningIndex].state = .failed
            taskTimeline.steps[runningIndex].detail = cleanOneLine(message)
        }

        taskTimeline.error = cleanOneLine(message)
        taskTimeline.finishedAt = Date()
    }

    private func bestMatchingStepIndex(for title: String) -> Int? {
        let words = Set(
            normalizedStepTitle(title)
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count > 2 }
        )

        guard !words.isEmpty else {
            return nil
        }

        var bestIndex: Int?
        var bestScore = 0

        for index in taskTimeline.steps.indices {
            let stepWords = Set(
                normalizedStepTitle(taskTimeline.steps[index].title)
                    .split(separator: " ")
                    .map(String.init)
                    .filter { $0.count > 2 }
            )

            let score = words.intersection(stepWords).count

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestScore >= 2 ? bestIndex : nil
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private func checklistSteps(
        for intent: GhostDetectedIntent,
        prompt: String,
        runEngine: ExecutionEngine
    ) -> [String] {
        switch intent.kind {
        case .answer:
            return [
                "Understand the question",
                runEngine == .directAPI ? "Call Direct API" : "Ask Ghost Agent",
                "Write the answer"
            ]

        case .research:
            return [
                "Understand the research question",
                "Search for current sources",
                "Compare useful results",
                "Write answer with citations"
            ]

        case .localFiles:
            return [
                "Understand which files are needed",
                "Search local files",
                "Read matching files",
                "Summarize findings"
            ]

        case .fileSummary:
            return [
                "Find the requested file",
                "Read file contents",
                "Extract key points",
                "Write summary"
            ]

        case .screenshotOCR:
            return [
                "Read screenshot context",
                "Extract visible text",
                "Understand the screen",
                "Explain what is happening"
            ]

        case .clipboardAction:
            return [
                "Read clipboard context",
                "Transform clipboard text",
                "Prepare final output"
            ]

        case .createArtifact:
            let fileType = intent.inferredFileExtension.map { ".\($0)" } ?? "file"

            let destination: String
            let lower = prompt.lowercased()

            if lower.contains("desktop") {
                destination = "Desktop"
            } else if lower.contains("downloads") {
                destination = "Downloads"
            } else if lower.contains("documents") {
                destination = "Documents"
            } else {
                destination = "requested location"
            }

            return [
                "Plan the \(fileType) content",
                "Generate the \(fileType)",
                "Save the \(fileType) to \(destination)",
                "Confirm the saved path"
            ]

        case .organizeFiles:
            return [
                "Understand organization rules",
                "Inspect matching files",
                "Plan file moves",
                "Apply safe changes",
                "Report what changed"
            ]

        case .automation:
            return [
                "Understand the schedule",
                "Prepare automation details",
                "Create reminder or automation",
                "Confirm setup"
            ]

        case .coding:
            return [
                "Understand coding task",
                "Inspect project files",
                "Make code changes",
                "Run validation if available",
                "Summarize changes"
            ]

        case .debugging:
            return [
                "Understand the error",
                "Inspect relevant files",
                "Find likely cause",
                "Apply fix",
                "Run validation if available",
                "Summarize result"
            ]

        case .codeReview:
            return [
                "Inspect changed files",
                "Review logic and safety",
                "Find bugs or regressions",
                "Summarize review notes"
            ]

        case .shell:
            return [
                "Prepare command",
                "Run command",
                "Read output",
                "Summarize result"
            ]
        }
    }

    private func titleForTask(intent: GhostDetectedIntent) -> String {
        switch intent.kind {
        case .answer:
            return "Answering"
        case .research:
            return "Researching"
        case .localFiles:
            return "Searching files"
        case .fileSummary:
            return "Summarizing file"
        case .screenshotOCR:
            return "Reading screenshot"
        case .clipboardAction:
            return "Using clipboard"
        case .createArtifact:
            if let ext = intent.inferredFileExtension {
                return "Creating .\(ext)"
            }

            return "Creating file"
        case .organizeFiles:
            return "Organizing files"
        case .automation:
            return "Creating automation"
        case .coding:
            return "Coding"
        case .debugging:
            return "Debugging"
        case .codeReview:
            return "Reviewing code"
        case .shell:
            return "Running command"
        }
    }

    private func updateTaskTimeline(from entry: GhostActivityEntry) {
        guard taskTimeline.isVisible else { return }

        let before = taskTimeline
        defer {
            if taskTimeline != before {
                touchTaskTimeline()
            }
        }

        applyProgressMarkers(from: entry.title)
        applyProgressMarkers(from: entry.detail)

        if taskTimeline.isUsingGhostPlan || taskTimeline.isWaitingForGhostPlan {
            switch entry.kind {
            case .command:
                handleGhostAgentFallbackActivity(entry)
            case .output, .info:
                handleGhostAgentFallbackActivity(entry)
            case .success:
                completeCurrentStep(detail: entry.detail.isEmpty ? entry.title : entry.detail)
            case .error:
                handleTimelineFailure(entry.detail.isEmpty ? entry.title : entry.detail)
            }

            return
        }

        switch entry.kind {
        case .command:
            handleCommandActivity(entry)

        case .info:
            handleInfoActivity(entry)

        case .output:
            handleOutputActivity(entry)

        case .success:
            handleSuccessActivity(entry)

        case .error:
            handleErrorActivity(entry)
        }
    }

    private func handleCommandActivity(_ entry: GhostActivityEntry) {
        if executionEngine == .ghostAgent {
            handleGhostAgentFallbackActivity(entry)
            return
        }

        let text = "\(entry.title) \(entry.detail)".lowercased()

        if text.contains("searching the web") {
            startOrAppendStep("Search for current sources", detail: entry.detail)
            return
        }

        if text.contains("starting ghost") {
            completeCurrentStep(detail: "Ghost Agent started")
            startNextPendingStep(detail: entry.detail)
            return
        }

        if text.contains("calling") && text.contains("api") {
            completeCurrentStep(detail: "Direct API selected")
            startNextPendingStep(detail: entry.detail)
            return
        }

        if text.contains("command") || text.contains("shell") {
            startOrAppendStep("Run command", detail: entry.detail)
        }
    }

    private func handleInfoActivity(_ entry: GhostActivityEntry) {
        if executionEngine == .ghostAgent {
            handleGhostAgentFallbackActivity(entry)
            return
        }

        let text = "\(entry.title) \(entry.detail)".lowercased()

        let ignored = [
            "provider:",
            "model:",
            "effort:",
            "max turns:",
            "approval:",
            "working directory",
            "process launched"
        ]

        if ignored.contains(where: { text.contains($0) }) {
            return
        }

        if text.contains("referenced files") {
            startOrAppendStep("Read matching files", detail: entry.detail)
            return
        }

        if text.contains("web search") {
            startOrAppendStep("Search for current sources", detail: entry.detail)
            return
        }

        updateCurrentStepDetail(entry.title)
    }

    private func handleOutputActivity(_ entry: GhostActivityEntry) {
        if executionEngine == .ghostAgent {
            handleGhostAgentFallbackActivity(entry)
            return
        }

        let text = entry.detail.lowercased()

        if text.contains("write") || text.contains("created") || text.contains("saved") || text.contains(".pdf") || text.contains(".docx") || text.contains(".csv") {
            startOrAppendStep("Save it to the requested location", detail: cleanOneLine(entry.detail))
            return
        }

        if text.contains("test") || text.contains("build") || text.contains("swift build") || text.contains("npm test") {
            startOrAppendStep("Run validation if available", detail: cleanOneLine(entry.detail))
            return
        }

        if currentIntent.kind == .research,
           text.contains("search") {
            startOrAppendStep("Search for current sources", detail: cleanOneLine(entry.detail))
            return
        }

        if currentIntent.kind == .coding || currentIntent.kind == .debugging || currentIntent.kind == .codeReview {
            if text.contains("read") || text.contains("inspect") || text.contains("grep") {
                startOrAppendStep("Inspect project files", detail: cleanOneLine(entry.detail))
                return
            }
        }

        updateCurrentStepDetail(cleanOneLine(entry.detail))
    }

    private func handleSuccessActivity(_ entry: GhostActivityEntry) {
        if executionEngine == .ghostAgent {
            handleGhostAgentFallbackActivity(entry)
            return
        }

        let text = "\(entry.title) \(entry.detail)".lowercased()

        if currentIntent.kind == .research,
           text.contains("web search finished") {
            completeMatchingStep(containing: "Search", detail: entry.detail)
            startNextPendingStep()
            return
        }

        if text.contains("api call finished") {
            completeCurrentStep(detail: entry.detail)
            startNextPendingStep()
            return
        }

        if text.contains("ghost finished") {
            completeCurrentStep(detail: entry.detail)
            return
        }

        completeCurrentStep(detail: entry.detail.isEmpty ? entry.title : entry.detail)
    }

    private func handleErrorActivity(_ entry: GhostActivityEntry) {
        guard taskTimeline.isVisible else { return }

        if let runningIndex = taskTimeline.steps.firstIndex(where: { $0.state == .running }) {
            taskTimeline.steps[runningIndex].state = .failed
            taskTimeline.steps[runningIndex].detail = cleanOneLine(entry.detail.isEmpty ? entry.title : entry.detail)
        }

        taskTimeline.error = entry.detail.isEmpty ? entry.title : cleanOneLine(entry.detail)
        taskTimeline.finishedAt = Date()
    }

    private func startNextPendingStep(detail: String = "") {
        guard taskTimeline.isVisible else { return }

        if let runningIndex = taskTimeline.steps.firstIndex(where: { $0.state == .running }) {
            taskTimeline.steps[runningIndex].state = .completed
        }

        if let pendingIndex = taskTimeline.steps.firstIndex(where: { $0.state == .pending }) {
            taskTimeline.steps[pendingIndex].state = .running
            if !detail.isEmpty {
                taskTimeline.steps[pendingIndex].detail = cleanOneLine(detail)
            }
        }
    }

    private func completeCurrentStep(detail: String = "") {
        guard taskTimeline.isVisible else { return }

        if let runningIndex = taskTimeline.steps.firstIndex(where: { $0.state == .running }) {
            taskTimeline.steps[runningIndex].state = .completed
            if !detail.isEmpty {
                taskTimeline.steps[runningIndex].detail = cleanOneLine(detail)
            }
        }

        if !taskTimeline.isFinished,
           taskTimeline.steps.contains(where: { $0.state == .pending }),
           taskTimeline.steps.contains(where: { $0.state == .running }) == false {
            startNextPendingStep()
        }
    }

    private func updateCurrentStepDetail(_ detail: String) {
        guard taskTimeline.isVisible else { return }

        if let runningIndex = taskTimeline.steps.firstIndex(where: { $0.state == .running }) {
            taskTimeline.steps[runningIndex].detail = cleanOneLine(detail)
        }
    }

    private func startOrAppendStep(_ title: String, detail: String = "") {
        guard taskTimeline.isVisible else { return }

        if let exactIndex = taskTimeline.steps.firstIndex(where: {
            normalizedStepTitle($0.title) == normalizedStepTitle(title)
        }) {
            for index in taskTimeline.steps.indices where taskTimeline.steps[index].state == .running {
                if index != exactIndex {
                    taskTimeline.steps[index].state = .completed
                }
            }

            if taskTimeline.steps[exactIndex].state == .pending {
                taskTimeline.steps[exactIndex].state = .running
            }

            if !detail.isEmpty {
                taskTimeline.steps[exactIndex].detail = cleanOneLine(detail)
            }

            return
        }

        if let fuzzyIndex = taskTimeline.steps.firstIndex(where: {
            normalizedStepTitle($0.title).contains(normalizedStepTitle(title))
            || normalizedStepTitle(title).contains(normalizedStepTitle($0.title))
        }) {
            for index in taskTimeline.steps.indices where taskTimeline.steps[index].state == .running {
                if index != fuzzyIndex {
                    taskTimeline.steps[index].state = .completed
                }
            }

            if taskTimeline.steps[fuzzyIndex].state == .pending {
                taskTimeline.steps[fuzzyIndex].state = .running
            }

            if !detail.isEmpty {
                taskTimeline.steps[fuzzyIndex].detail = cleanOneLine(detail)
            }

            return
        }

        for index in taskTimeline.steps.indices where taskTimeline.steps[index].state == .running {
            taskTimeline.steps[index].state = .completed
        }

        taskTimeline.steps.append(
            GhostTaskStep(
                title: title,
                detail: cleanOneLine(detail),
                state: .running
            )
        )
    }

    private func completeMatchingStep(containing text: String, detail: String = "") {
        guard taskTimeline.isVisible else { return }

        let needle = text.lowercased()

        if let index = taskTimeline.steps.firstIndex(where: { $0.title.lowercased().contains(needle) }) {
            taskTimeline.steps[index].state = .completed
            if !detail.isEmpty {
                taskTimeline.steps[index].detail = cleanOneLine(detail)
            }
        }
    }

    private func finishTaskTimeline(success: Bool, summary: String) {
        guard taskTimeline.isVisible else { return }

        if taskTimeline.isWaitingForGhostPlan {
            taskTimeline.isWaitingForGhostPlan = false
        }

        if success {
            reconcileSuccessfulTimeline()
            taskTimeline.summary = summary.isEmpty ? "Finished successfully" : cleanOneLine(summary)
            taskTimeline.error = nil
        } else {
            if let runningIndex = taskTimeline.steps.firstIndex(where: { $0.state == .running }) {
                taskTimeline.steps[runningIndex].state = .failed
            }

            taskTimeline.error = summary.isEmpty ? "Task failed" : cleanOneLine(summary)
        }

        taskTimeline.finishedAt = Date()
    }

    private func reconcileSuccessfulTimeline() {
        guard taskTimeline.isVisible else { return }

        for index in taskTimeline.steps.indices {
            switch taskTimeline.steps[index].state {
            case .pending, .running:
                taskTimeline.steps[index].state = .completed

                if taskTimeline.steps[index].detail.isEmpty {
                    taskTimeline.steps[index].detail = "Completed in final result"
                }

            case .failed:
                taskTimeline.steps[index].state = .completed

                if taskTimeline.steps[index].detail.isEmpty {
                    taskTimeline.steps[index].detail = "Recovered before final result"
                }

            case .completed:
                break
            }
        }
    }

    private func stopTaskTimeline() {
        guard taskTimeline.isVisible else { return }

        if let runningIndex = taskTimeline.steps.firstIndex(where: { $0.state == .running }) {
            taskTimeline.steps[runningIndex].state = .failed
            taskTimeline.steps[runningIndex].detail = "Stopped by user"
        }

        taskTimeline.error = "Stopped"
        taskTimeline.finishedAt = Date()
    }

    private func clearTaskTimeline() {
        taskTimeline = .idle
        taskTimelineAnchorMessageID = nil
    }

    private func touchTaskTimeline() {
        guard taskTimeline.isVisible else { return }
        taskTimeline.lastUpdatedAt = Date()
    }

    private func handleGhostAgentFallbackActivity(_ entry: GhostActivityEntry) {
        guard executionEngine == .ghostAgent, taskTimeline.isVisible, !taskTimeline.isFinished else { return }

        let rawDetail = entry.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? entry.title : entry.detail
        let detail = cleanOneLine(rawDetail)

        guard !detail.isEmpty else { return }

        if taskTimeline.isWaitingForGhostPlan {
            taskTimeline.isWaitingForGhostPlan = false
        }

        if taskTimeline.steps.isEmpty {
            taskTimeline.steps.append(
                GhostTaskStep(
                    title: "Work on request",
                    detail: detail,
                    state: .running
                )
            )
            return
        }

        if !taskTimeline.steps.contains(where: { $0.state == .running }),
           let firstPending = taskTimeline.steps.firstIndex(where: { $0.state == .pending }) {
            taskTimeline.steps[firstPending].state = .running
        }

        if let runningIndex = taskTimeline.steps.firstIndex(where: { $0.state == .running }) {
            taskTimeline.steps[runningIndex].detail = fallbackDetail(from: detail)
        }

        ghostFallbackOutputTicks += 1

        if shouldAdvanceFallbackTimeline(from: detail) {
            startLikelyFallbackStep(for: detail)
            return
        }

        maybeAdvanceFallbackTimeline(detail: detail)
    }

    private func fallbackDetail(from detail: String) -> String {
        let clean = cleanOneLine(detail)

        if clean.count <= 120 {
            return clean
        }

        return String(clean.prefix(117)) + "…"
    }

    private func shouldAdvanceFallbackTimeline(from detail: String) -> Bool {
        let lower = detail.lowercased()
        return containsAny(lower, [
            "reading", "read file", "inspecting", "searching", "grep", "editing", "writing",
            "created", "saved", "running", "testing", "building", "finished", "done"
        ])
    }

    private func startLikelyFallbackStep(for detail: String) {
        let lower = detail.lowercased()

        if containsAny(lower, ["read", "inspect", "grep", "search"]) {
            startFirstMatchingPendingStep(containing: ["inspect", "search", "read", "find"], detail: detail)
            return
        }

        if containsAny(lower, ["edit", "patch", "change", "write code"]) {
            startFirstMatchingPendingStep(containing: ["make", "apply", "edit", "code"], detail: detail)
            return
        }

        if containsAny(lower, ["save", "saved", "created", "wrote", "file"]) {
            startFirstMatchingPendingStep(containing: ["save", "generate", "create", "confirm"], detail: detail)
            return
        }

        if containsAny(lower, ["test", "build", "validate"]) {
            startFirstMatchingPendingStep(containing: ["validation", "test", "build"], detail: detail)
            return
        }

        maybeAdvanceFallbackTimeline(detail: detail)
    }

    private func startFirstMatchingPendingStep(containing needles: [String], detail: String) {
        guard taskTimeline.isVisible else { return }

        let pendingIndex = taskTimeline.steps.firstIndex { step in
            step.state == .pending && needles.contains { step.title.lowercased().contains($0) }
        }

        guard let pendingIndex else {
            maybeAdvanceFallbackTimeline(detail: detail)
            return
        }

        for index in taskTimeline.steps.indices where taskTimeline.steps[index].state == .running {
            taskTimeline.steps[index].state = .completed
        }

        taskTimeline.steps[pendingIndex].state = .running
        taskTimeline.steps[pendingIndex].detail = fallbackDetail(from: detail)
        lastTimelineAutoAdvanceAt = Date()
    }

    private func maybeAdvanceFallbackTimeline(detail: String) {
        let now = Date()

        guard let lastTimelineAutoAdvanceAt else {
            self.lastTimelineAutoAdvanceAt = now
            return
        }

        let shouldAdvance = now.timeIntervalSince(lastTimelineAutoAdvanceAt) >= 1.25 || ghostFallbackOutputTicks.isMultiple(of: 6)

        guard shouldAdvance else { return }

        self.lastTimelineAutoAdvanceAt = now

        if taskTimeline.steps.contains(where: { $0.state == .pending }) {
            startNextPendingStep(detail: fallbackDetail(from: detail))
        }
    }

    private func consumeLiveProgressMarkers(from text: String) -> String {
        guard !text.isEmpty else { return "" }

        progressMarkerBuffer += text

        let endsWithNewline = progressMarkerBuffer.hasSuffix("\n") || progressMarkerBuffer.hasSuffix("\r")

        var lines = progressMarkerBuffer.components(separatedBy: .newlines)

        if !endsWithNewline {
            progressMarkerBuffer = lines.popLast() ?? ""
        } else {
            progressMarkerBuffer = ""
        }

        var visibleLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if let marker = normalizedProgressMarkerLine(trimmed) {
                applyProgressMarkerLine(marker)
                let visible = line.replacingOccurrences(of: marker, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !visible.isEmpty {
                    visibleLines.append(visible)
                }
            } else if !line.isEmpty {
                visibleLines.append(line)
            }
        }

        return visibleLines.joined(separator: "\n")
    }

    private func flushLiveProgressMarkerBuffer() {
        let trimmed = progressMarkerBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if let marker = normalizedProgressMarkerLine(trimmed) {
            applyProgressMarkerLine(marker)
        }

        progressMarkerBuffer = ""
    }

    private func isGhostProgressMarker(_ line: String) -> Bool {
        line.hasPrefix("GHOST_TODO:")
            || line == "GHOST_TODO_READY"
            || line.hasPrefix("GHOST_TODO_START:")
            || line.hasPrefix("GHOST_TODO_DONE:")
            || line.hasPrefix("GHOST_TODO_FAIL:")
            || line.hasPrefix("GHOST_SUMMARY:")
            || line.hasPrefix("GHOST_PLAN:")
            || line == "GHOST_PLAN_READY"
            || line.hasPrefix("GHOST_CURRENT:")
            || line.hasPrefix("GHOST_DONE:")
    }

    private func normalizedProgressMarkerLine(_ line: String) -> String? {
        let noANSI = line.replacingOccurrences(
            of: #"\u{001B}\[[0-9;?]*[ -/]*[@-~]"#,
            with: "",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        if isGhostProgressMarker(noANSI) {
            return noANSI
        }

        guard let range = noANSI.range(of: "GHOST_") else {
            return nil
        }

        let candidate = String(noANSI[range.lowerBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return isGhostProgressMarker(candidate) ? candidate : nil
    }

    private func applyProgressMarkers(from text: String) {
        guard !text.isEmpty else { return }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if let marker = normalizedProgressMarkerLine(line) {
                applyProgressMarkerLine(marker)
            }
        }
    }

    private func applyProgressMarkerLine(_ line: String) {
        defer { touchTaskTimeline() }

        if let value = progressValue(from: line, prefix: "GHOST_TODO:") {
            if let parsed = parseTodoPayload(value) {
                appendGhostTodo(id: parsed.id, title: parsed.text)
            }
            return
        }

        if line == "GHOST_TODO_READY" {
            commitGhostTodoPlan()
            return
        }

        if let value = progressValue(from: line, prefix: "GHOST_TODO_START:") {
            if let parsed = parseTodoPayload(value) {
                startTodo(id: parsed.id, detail: parsed.text)
            } else {
                startTodo(id: cleanTodoID(value))
            }
            return
        }

        if let value = progressValue(from: line, prefix: "GHOST_TODO_DONE:") {
            if let parsed = parseTodoPayload(value) {
                completeTodo(id: parsed.id, detail: parsed.text)
            } else {
                completeTodo(id: value)
            }
            return
        }

        if let value = progressValue(from: line, prefix: "GHOST_TODO_FAIL:") {
            if let parsed = parseTodoPayload(value) {
                failTodo(id: parsed.id, detail: parsed.text)
            } else {
                failTodo(id: value)
            }
            return
        }

        if let value = progressValue(from: line, prefix: "GHOST_SUMMARY:") {
            taskTimeline.summary = cleanOneLine(value)
            return
        }

        if let value = progressValue(from: line, prefix: "GHOST_PLAN:") {
            let plannedCount = taskTimeline.steps.filter { $0.todoID?.hasPrefix("todo") == true }.count
                + taskTimeline.pendingGhostPlanItems.count
            let id = "todo\(plannedCount + 1)"
            appendGhostTodo(id: id, title: value)
            return
        }

        if line == "GHOST_PLAN_READY" {
            commitGhostTodoPlan()
            return
        }

        if let value = progressValue(from: line, prefix: "GHOST_CURRENT:") {
            startOrAppendStep(value)
            return
        }

        if let value = progressValue(from: line, prefix: "GHOST_DONE:") {
            completeMatchingOrCurrent(value)
            return
        }
    }

    private func completeMatchingOrCurrent(_ title: String) {
        guard taskTimeline.isVisible else { return }

        let normalized = normalizedStepTitle(title)

        if let exactIndex = taskTimeline.steps.firstIndex(where: {
            normalizedStepTitle($0.title) == normalized
        }) {
            taskTimeline.steps[exactIndex].state = .completed
            return
        }

        if let fuzzyIndex = bestMatchingStepIndex(for: title) {
            taskTimeline.steps[fuzzyIndex].state = .completed
            return
        }

        completeCurrentStep(detail: title)
    }

    private func progressValue(from line: String, prefix: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }

        return String(line.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    private func stripGhostProgressMarkers(from text: String) -> String {
        text.components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                return !trimmed.hasPrefix("GHOST_TODO:")
                    && trimmed != "GHOST_TODO_READY"
                    && !trimmed.hasPrefix("GHOST_TODO_START:")
                    && !trimmed.hasPrefix("GHOST_TODO_DONE:")
                    && !trimmed.hasPrefix("GHOST_TODO_FAIL:")
                    && !trimmed.hasPrefix("GHOST_PLAN:")
                    && trimmed != "GHOST_PLAN_READY"
                    && !trimmed.hasPrefix("GHOST_STEP:")
                    && !trimmed.hasPrefix("GHOST_CURRENT:")
                    && !trimmed.hasPrefix("GHOST_DONE:")
                    && !trimmed.hasPrefix("GHOST_SUMMARY:")
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedStepTitle(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9 ]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanOneLine(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count <= 220 {
            return cleaned
        }

        return String(cleaned.prefix(220)) + "…"
    }

    /// Resolves the saved key for a provider (used by Direct API mode).
    /// LM Studio needs none, so it returns nil.
    private func directAPIKey(for provider: GhostProvider) -> String? {
        let keyType: ProviderAPIKey?
        switch provider {
        case .claude:
            keyType = .anthropic
        case .gemini:
            keyType = .gemini
        case .deepSeek:
            keyType = .deepSeek
        case .openCodeGo:
            keyType = .openCodeGo
        case .lmStudio, .ollama:
            keyType = nil
        }
        guard let keyType else { return nil }
        return secretsService.read(for: keyType)
    }

    private func runSettings(provider: GhostProvider? = nil) -> GhostRunSettings {
        let provider = provider ?? selectedProvider
        return GhostRunSettings(
            provider: provider,
            model: model(for: provider),
            localContextWindow: localContextWindow,
            workingDirectory: workspaceRootURL,
            documentOutputDirectory: documentOutputDirectoryURL,
            apiKeys: keyedEnvironment(for: provider),
            approvalMode: approvalMode,
            toolsets: toolsets.trimmingCharacters(in: .whitespacesAndNewlines),
            effortMode: effortMode,
            ollamaBaseURL: ollamaBaseURL,
            ragEnabled: isRAGEnabled,
            agentKind: activeLocalAgentKind,
            agentExecutableURL: activeLocalAgentExecutableURL
        )
    }

    private func imageAttachmentForDirectAPI(
        _ attachment: GhostImageAttachment?,
        engine: ExecutionEngine,
        settings: GhostRunSettings
    ) -> GhostImageAttachment? {
        guard let attachment, engine == .directAPI, settings.supportsVision else {
            return nil
        }
        return attachment
    }

    private func imageAttachmentPromptBlock(
        _ attachment: GhostImageAttachment?,
        engine: ExecutionEngine,
        settings: GhostRunSettings
    ) -> String {
        guard let attachment else { return "" }

        if engine == .directAPI, settings.supportsVision {
            return """


            Pasted screenshot:
            - \(attachment.filename) is attached as an image payload.
            - Read and interpret the screenshot directly.
            """
        }

        if engine == .ghostAgent, let path = saveImageAttachmentToOutputFolder(attachment) {
            return """


            Pasted screenshot:
            - The screenshot was saved at \(path).
            - If your active agent/model supports vision, inspect that image. If not, say that screenshot interpretation needs a vision-capable model.
            """
        }

        return """


        Pasted screenshot:
        - \(attachment.filename) was pasted, but \(settings.provider.title) model \(settings.model) is not marked as vision-capable in Ghost.
        - State this limitation and answer from the text prompt only, or ask the user to switch to Claude, Gemini, or a local vision model.
        """
    }

    private func visibleUserText(_ text: String, imageAttachment: GhostImageAttachment?) -> String {
        guard let imageAttachment else { return text }
        return """
        \(text)

        [Attached screenshot: \(imageAttachment.filename), \(imageAttachment.sizeDescription)]
        """
    }

    private func saveImageAttachmentToOutputFolder(_ attachment: GhostImageAttachment) -> String? {
        let directory = documentOutputDirectoryURL.appendingPathComponent("Attachments", isDirectory: true)
        let url = directory.appendingPathComponent(attachment.filename)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try attachment.data.write(to: url, options: .atomic)
            return url.path
        } catch {
            recordActivity(GhostActivityEntry(kind: .error, title: "Screenshot save failed", detail: error.localizedDescription))
            return nil
        }
    }

    private func promptWithEffort(
        _ userPrompt: String,
        clipboard: String?,
        conversationContext: String? = nil,
        fileContexts: [ResolvedFileContext] = [],
        ragContext: String? = nil,
        detectedIntent: GhostDetectedIntent? = nil,
        runEngine: ExecutionEngine
    ) -> String {
        if runEngine == .directAPI {
            return directAPIPrompt(
                userPrompt,
                clipboard: clipboard,
                conversationContext: conversationContext,
                fileContexts: fileContexts,
                ragContext: ragContext,
                detectedIntent: detectedIntent
            )
        }

        let clip = clipboard?.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = clip.map { "\n\nContext from clipboard:\n\($0)" } ?? ""
        let conversation = conversationContext.map { "\n\nRecent conversation:\n\($0)" } ?? ""
        let fileContextBlock = terminalFileContextBlock(fileContexts)
        let outputFolder = documentOutputDirectoryURL.path
        let intentInstructions = detectedIntent.map { intentRouter.instructions(for: $0, workspaceRoot: workspaceRootURL) } ?? ""
        let agentInstructions = interfaceMode == .terminal ? openCodeCompatService.agentInstructionsBlock(root: workspaceRootURL) : ""
        let effortInstruction = runEngine == .directAPI
            ? directAPIEffortInstruction
            : effortMode.promptInstruction

        let progressInstruction = """
        Todo UI protocol:
        For every Ghost Agent task, create a task-specific todo plan before doing tool work.

        You must emit the todo plan first, before shell commands, file writes, or final answer text.

        Use this exact format:

        GHOST_TODO: id | specific todo title
        GHOST_TODO: id | specific todo title
        GHOST_TODO: id | specific todo title
        GHOST_TODO_READY

        Then while working:

        GHOST_TODO_START: id
        GHOST_TODO_DONE: id | short result
        GHOST_TODO_FAIL: id | short reason
        GHOST_SUMMARY: short final summary

        Rules:
        - Emit todo markers as live progress events. Do not batch them at the end.
        - Emit GHOST_TODO_READY before starting the first todo.
        - Start a todo before doing that work.
        - Mark a todo done immediately after the work is actually completed.
        - Do not mark file save todos done unless the file was actually written.
        - Do not claim a path unless it is a real path.
        - Todo titles must be specific to the user's request.
        - Do not use generic todos like "Understand the request".
        - Never create a todo about creating, updating, or managing the todo list.
        - Todos are only for user-visible work: design, edit, write, save, validate, and confirm.
        - Keep ids lowercase with no spaces.
        - Keep markers on their own lines.
        - Do not wrap markers in markdown.
        - These markers are hidden by Ghost's UI.

        Good example:
        GHOST_TODO: design_animation | Design the atom temperature animation
        GHOST_TODO: build_html | Build the self-contained .html file
        GHOST_TODO: save_desktop | Save the .html file to Desktop
        GHOST_TODO: verify_path | Verify and report the saved path
        GHOST_TODO_READY
        GHOST_TODO_START: design_animation
        GHOST_TODO_DONE: design_animation | Planned solid, liquid, and gas motion states
        GHOST_TODO_START: build_html
        GHOST_TODO_DONE: build_html | Created the HTML, CSS, and JavaScript
        GHOST_TODO_START: save_desktop
        GHOST_TODO_DONE: save_desktop | Wrote the file to ~/Desktop
        GHOST_TODO_START: verify_path
        GHOST_TODO_DONE: verify_path | Confirmed the saved path
        GHOST_SUMMARY: Created the atom temperature HTML simulation on Desktop
        """

        let localToolInstruction = """
        Local tool and computer-use rules:
        - If the user asks to create, save, move, edit, delete, organize, or place a file on the Mac, you must actually use filesystem tools or shell commands.
        - Do not say a file was saved unless it was actually written and you verified the path.
        - Default Ghost-produced documents and code artifacts to \(outputFolder) unless the user names another folder.
        - For Desktop requests, save to ~/Desktop unless the user specifies another folder.
        - When saving a file, report the real absolute path.
        - For PDF/DOCX/PPTX/XLSX artifacts, create a valid file package, not a fake text file with that extension.
        - For reminders, calendar events, notifications, email, screenshots/OCR, and app control, use the available macOS tools when routed through Ghost Agent. Never claim setup succeeded without a tool result.
        - If you use web search, RAG, or any external lookup, end with `## References` and list the source title or file plus URL/path for every source you relied on.
        - Simple one-shot reminders may be handled by Ghost's native deterministic reminder parser before the model runs; if this prompt reaches you, the timing likely needs clarification or agent tool access.
        - If the file, reminder, event, command, or app action cannot be completed, say exactly why and what permission/setup is missing.
        """

        return """
        Ghost effort: \(effortMode.title(for: selectedProvider)).
        \(effortInstruction)

        \(progressInstruction)

        \(localToolInstruction)

        \(interfaceMode == .terminal ? terminalModeInstruction : "Return ONLY clean Markdown.")

        Formatting rules:
        - Do not print internal routing metadata such as Intent, Route, Permission, File type, Using, or Reason.
        - Use `##` for main headings only outside Terminal Mode.
        - Use `###` for subheadings only outside Terminal Mode.
        - Use `- ` for bullets.
        - Put a blank line between sections.
        - Keep the answer clear, useful, and concise.
        - Do not use Markdown tables unless explicitly requested. Prefer bullet lists.
        - If information was looked up through web, RAG, files, or another source, end with `## References` containing source titles and URLs or file paths.
        \(conversation)
        \(fileContextBlock)

        Intent router instructions:
        \(intentInstructions)
        \(agentInstructions)
        User request:
        \(userPrompt)\(clipped)
        """
    }

    private func directAPIPrompt(
        _ userPrompt: String,
        clipboard: String?,
        conversationContext: String?,
        fileContexts: [ResolvedFileContext],
        ragContext: String? = nil,
        detectedIntent: GhostDetectedIntent?
    ) -> String {
        let intentKind = detectedIntent?.kind ?? .answer
        let clip = clipboard?.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = clip.map { "\n\nClipboard context:\n\($0)" } ?? ""
        let conversation = conversationContext.map { "\n\nRecent conversation:\n\($0)" } ?? ""
        let fileContextBlock = terminalFileContextBlock(fileContexts)
        let ragBlock = ragContext.map { "\n\nRAG document context (answer from these cited chunks):\n\($0)\n\nIf these chunks answer the question, cite them inline like [1], [2] and end with `## References` listing the document names/paths used. If they do not answer the question, say so and suggest what file might help." } ?? ""
        let outputFolder = documentOutputDirectoryURL.path

        let taskInstruction: String
        switch intentKind {
        case .research:
            taskInstruction = "Answer with current sourced facts when web context is supplied. Cite provided web results inline."
        case .clipboardAction:
            taskInstruction = "Use the clipboard context only for the requested transformation or answer."
        case .fileSummary, .localFiles:
            taskInstruction = "Use provided file context and RAG document context to answer. Cite sources."
        case .createArtifact:
            taskInstruction = "Create the requested text-based artifact. For local models, Ghost's Direct API layer exposes a real file creation tool; use it. If the model cannot call tools, return the full file content in one fenced code block so Ghost can save it deterministically."
        case .automation:
            taskInstruction = "Use Ghost's native deterministic parser or Direct API tools for reminders/calendar when the date range is explicit. Ask one clear question if the schedule is ambiguous."
        default:
            taskInstruction = "Answer directly. Keep it concise, useful, and natural."
        }

        return """
        You are Ghost, a fast native macOS assistant.
        \(directAPIEffortInstruction)
        \(taskInstruction)
        \(ragBlock)
        Default Ghost-produced documents and code artifacts to \(outputFolder) unless the user names another folder.

        Formatting:
        - Return clean Markdown.
        - Do not mention internal routing, tools, timelines, permissions, or diagnostics.
        - Do not create todo lists unless the user asks for one.
        - Prefer a direct answer first.
        - If information was looked up through web, RAG, files, or another source, end with `## References` containing source titles and URLs or file paths.
        \(conversation)
        \(fileContextBlock)

        User request:
        \(userPrompt)\(clipped)
        """
    }

    private func terminalFileContextBlock(_ fileContexts: [ResolvedFileContext]) -> String {
        guard !fileContexts.isEmpty else { return "" }

        let rendered = fileContexts.map { context in
            """
            --- @\(context.relativePath)\(context.wasTruncated ? " (truncated)" : "") ---
            \(context.contents)
            --- end @\(context.relativePath) ---
            """
        }.joined(separator: "\n\n")

        return """

        Referenced workspace files:
        \(rendered)
        """
    }

    private var terminalModeInstruction: String {
        """
        You are Ghost, a universal Mac assistant with an adaptive coding terminal.

        Current workspace: \(workspaceRootURL.path)
        Default Ghost output folder: \(documentOutputDirectoryURL.path)
        Current inferred intent: \(currentIntent.title) — \(currentIntent.routeLine)
        Current internal code workflow: \(codeAgentMode.title) — \(codeAgentMode.instruction)

        Behave like a terminal agent only when the inferred task needs coding, debugging, review, or shell tools:
        - Render terminal runs as plain terminal output, not chat bubbles.
        - Use concise sections such as [plan], [read], [edit], [patch], [cmd], [output], [artifact], [changed], [actions], [done].
        - Do not echo Ghost's internal intent, route, permission, file type, tool, or reason diagnostics.
        - Respect AGENTS.md project instructions when present.
        - Treat @file references as explicit project context.
        - Treat !command results in the transcript as ground truth.
        - Mention exact files and commands when suggesting changes.
        - For coding prompts, work inside Ghost's terminal. Do not suggest handing the task to OpenCode.
        - For file creation prompts, create the requested artifact when possible and show the saved path.
        - Never invent tool results. If a command was not run, say what command should be run.
        - Do not claim a file was edited unless the tool or user-provided context proves it.
        - Keep lines terminal-friendly and avoid decorative Markdown in terminal output.
        """
    }

    private func recentConversationContext() -> String? {
        guard !messages.isEmpty else {
            return nil
        }

        let lines = messages.suffix(6).compactMap { message -> String? in
            let text = message.text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return nil
            }
            let label = message.role == .user ? "User" : "Assistant"
            return "\(label): \(String(text.prefix(700)))"
        }

        guard !lines.isEmpty else {
            return nil
        }
        return lines.joined(separator: "\n")
    }

    private var directAPIEffortInstruction: String {
        switch effortMode {
        case .low:
            "Use low effort. Answer quickly and directly."
        case .medium:
            "Use medium effort. Be practical and concise."
        case .high:
            "Use high effort. Think carefully and answer from the available prompt context."
        case .max:
            "Use maximum effort. Be thorough and answer from the available prompt context."
        }
    }

    private var workspaceRootURL: URL {
        projectContextService.workspaceRoot(from: workingDirectoryPath)
    }

    private func shouldTrackCodeChanges(runEngine: ExecutionEngine) -> Bool {
        interfaceMode == .terminal && codeAgentMode == .build && runEngine == .ghostAgent
    }

    private func trackCodeChanges(after beforeSnapshot: GhostCodeWorkspaceSnapshot, command: String) {
        let afterSnapshot = ghostCodeChangeSetService.captureSnapshot(root: workspaceRootURL)
        guard let changeSet = ghostCodeChangeSetService.changeSet(
            before: beforeSnapshot,
            after: afterSnapshot,
            command: command
        ) else { return }

        lastGhostCodeChangeSet = changeSet
        undoneGhostCodeChangeSet = nil
        messages.append(GhostMessage(role: .system, text: "[changed]\n\(changeSet.terminalSummary)"))
    }

    private func appendTerminalEchoIfNeeded(_ command: String) {
        guard interfaceMode == .terminal else { return }
        messages.append(GhostMessage(role: .user, text: command))
    }

    private func runShellCommand(_ command: String) {
        guard !command.isEmpty else {
            messages.append(GhostMessage(role: .system, text: "Usage: !command"))
            return
        }

        isSending = true
        activeRunStartedAt = Date()
        lastRunStartedAt = Date()
        lastPromptCharacterCount = command.count
        lastRunStatus = .running
        activeProcessIdentifier = nil
        let startedAt = Date()

        recordActivity(
            GhostActivityEntry(
                kind: .command,
                title: "Shell command",
                detail: command
            )
        )

        Task {
            let result = await shellCommandService.run(command, workingDirectory: workspaceRootURL)
            if let finalWorkingDirectory = result.finalWorkingDirectory {
                workingDirectoryPath = finalWorkingDirectory
            }
            lastRunFinishedAt = Date()
            lastRunDuration = Date().timeIntervalSince(startedAt)
            lastExitStatus = result.exitCode
            lastRunStatus = result.exitCode == 0 ? .completed : .failed
            lastResponseCharacterCount = result.stdout.count + result.stderr.count
            messages.append(GhostMessage(role: .system, text: result.formattedTerminalOutput))
            recordActivity(
                GhostActivityEntry(
                    kind: result.exitCode == 0 ? .success : .error,
                    title: "Shell finished",
                    detail: "exit \(result.exitCode)"
                )
            )
            isSending = false
            activeRunStartedAt = nil
        }
    }

    private func setWorkingDirectory(_ rawPath: String) {
        let url = resolvedPath(rawPath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            messages.append(GhostMessage(role: .system, text: "[error]\nDirectory not found: \(url.path)"))
            return
        }
        workingDirectoryPath = url.path
        messages.append(GhostMessage(role: .system, text: "[cwd]\n\(url.path)"))
    }

    private func resolvedPath(_ rawPath: String) -> URL {
        let expanded = (rawPath as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }
        return workspaceRootURL.appendingPathComponent(expanded).standardizedFileURL
    }

    private func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func handleLocalCommand(_ command: String) -> Bool {
        guard command.hasPrefix("/") else { return false }

        let parts = command
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)
        guard let verb = parts.first?.lowercased() else { return false }
        let arguments = parts.dropFirst().joined(separator: " ")

        if verb != "/clear", verb != "/new" {
            appendTerminalEchoIfNeeded(command)
        }

        switch verb {
        case "/help":
            messages.append(
                GhostMessage(
                    role: .system,
                    text: openCodeCompatService.renderHelp(
                        customCommands: openCodeCompatService.loadCustomCommands(root: workspaceRootURL)
                    )
                )
            )
            return true
        case "/connect":
            panelMode = .settings
            messages.append(GhostMessage(role: .system, text: "[connect]\nOpened provider and API settings."))
            return true
        case "/compact", "/summarize":
            let compacted = recentConversationContext() ?? "No visible conversation context to compact."
            messages.append(GhostMessage(role: .system, text: "[compact]\nSession context compacted for the next prompt.\n\n\(compacted)"))
            return true
        case "/details":
            isTerminalToolDetailsVisible.toggle()
            messages.append(GhostMessage(role: .system, text: "[details]\nTool details \(isTerminalToolDetailsVisible ? "shown" : "hidden")."))
            return true
        case "/markdown":
            ghostCodeOutputMode = .markdown
            messages.append(GhostMessage(role: .system, text: "[view]\nGhost Code output set to Markdown. Assistant answers will render as formatted Markdown; tool output stays terminal-style."))
            return true
        case "/terminal":
            ghostCodeOutputMode = .terminal
            messages.append(GhostMessage(role: .system, text: "[view]\nGhost Code output set to Terminal. Assistant answers will render as raw OpenCode-style terminal output."))
            return true
        case "/view":
            if parts.count > 1 {
                switch parts[1].lowercased() {
                case "markdown", "md", "rendered", "pretty":
                    ghostCodeOutputMode = .markdown
                case "terminal", "term", "raw", "opencode":
                    ghostCodeOutputMode = .terminal
                default:
                    messages.append(GhostMessage(role: .system, text: "Usage: /view markdown|terminal"))
                    return true
                }
            } else {
                toggleGhostCodeOutputMode()
            }
            messages.append(GhostMessage(role: .system, text: "[view]\nGhost Code output set to \(ghostCodeOutputMode.title)."))
            return true
        case "/editor":
            do {
                let seed = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "# Ghost Code prompt\n\n"
                    : prompt
                let url = try openCodeCompatService.openEditorDraft(root: workspaceRootURL, seed: seed)
                messages.append(GhostMessage(role: .system, text: "[editor]\nOpened draft: \(url.path)"))
            } catch {
                messages.append(GhostMessage(role: .system, text: "[error]\n\(error.localizedDescription)"))
            }
            return true
        case "/exit", "/quit", "/q":
            NSApplication.shared.terminate(nil)
            return true
        case "/export":
            do {
                let url = try openCodeCompatService.exportTranscript(messages: messages, root: workspaceRootURL)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
                messages.append(GhostMessage(role: .system, text: "[export]\nWrote transcript and copied path:\n\(url.path)"))
            } catch {
                messages.append(GhostMessage(role: .system, text: "[error]\n\(error.localizedDescription)"))
            }
            return true
        case "/new", "/clear":
            clearConversation()
            return true
        case "/sessions", "/resume", "/continue":
            let exports = openCodeCompatService.listExports(root: workspaceRootURL)
            let body = exports.isEmpty ? "No exported sessions yet. Use /export first." : exports.map { "- \($0)" }.joined(separator: "\n")
            messages.append(GhostMessage(role: .system, text: "[sessions]\n\(body)"))
            return true
        case "/share":
            do {
                let url = try openCodeCompatService.exportTranscript(messages: messages, root: workspaceRootURL)
                messages.append(GhostMessage(role: .system, text: "[share]\nGhost Code keeps sharing local/private for now. Exported transcript:\n\(url.path)"))
            } catch {
                messages.append(GhostMessage(role: .system, text: "[error]\n\(error.localizedDescription)"))
            }
            return true
        case "/undo":
            guard let changeSet = lastGhostCodeChangeSet else {
                messages.append(GhostMessage(role: .system, text: "[undo]\nNo tracked Build-mode changes to undo."))
                return true
            }
            do {
                try ghostCodeChangeSetService.undo(changeSet, root: workspaceRootURL)
                undoneGhostCodeChangeSet = changeSet
                lastGhostCodeChangeSet = nil
                messages.append(GhostMessage(role: .system, text: "[undo]\nReverted tracked changes from:\n\(changeSet.terminalSummary)"))
            } catch {
                messages.append(GhostMessage(role: .system, text: "[error]\n\(error.localizedDescription)"))
            }
            return true
        case "/redo":
            guard let changeSet = undoneGhostCodeChangeSet else {
                messages.append(GhostMessage(role: .system, text: "[redo]\nNo undone change set to restore."))
                return true
            }
            do {
                try ghostCodeChangeSetService.redo(changeSet, root: workspaceRootURL)
                lastGhostCodeChangeSet = changeSet
                undoneGhostCodeChangeSet = nil
                messages.append(GhostMessage(role: .system, text: "[redo]\nRestored tracked changes:\n\(changeSet.terminalSummary)"))
            } catch {
                messages.append(GhostMessage(role: .system, text: "[error]\n\(error.localizedDescription)"))
            }
            return true
        case "/history":
            let history = recentPrompts.isEmpty ? "No recent prompts." : recentPrompts.map { "- \($0)" }.joined(separator: "\n")
            messages.append(GhostMessage(role: .system, text: "[history]\n\(history)"))
            return true
        case "/model", "/models":
            let localModelList = localModels.isEmpty
                ? "No local models loaded. Open settings and refresh Local Models."
                : localModels.prefix(20).map { "- \($0.id)" }.joined(separator: "\n")
            messages.append(GhostMessage(role: .system, text: """
            [models]
            Active: \(effectiveProvider.title) · \(modelDisplayName)
            Routing: \(enginePreference.title)
            Current engine: \(executionEngine.title)

            Providers:
            \(GhostProvider.allCases.map { "- \($0.title): \(model(for: $0))" }.joined(separator: "\n"))

            Local models:
            \(localModelList)
            """))
            return true
        case "/effort":
            guard parts.count > 1, let mode = EffortMode(rawValue: parts[1].lowercased()) else {
                messages.append(GhostMessage(role: .system, text: "Usage: /effort low|medium|high|max"))
                return true
            }
            effortMode = mode
            messages.append(GhostMessage(role: .system, text: "[ok]\nEffort set to \(mode.title(for: selectedProvider))."))
            return true
        case "/theme":
            guard parts.count > 1 else {
                messages.append(GhostMessage(role: .system, text: "Usage: /theme glass|terminal|code"))
                return true
            }
            switch parts[1].lowercased() {
            case "glass", "ghost", "friendly":
                selectInterfaceMode(.glass)
                messages.append(GhostMessage(role: .system, text: "[ok]\nTheme set to Ghost Glass."))
            case "terminal", "term", "code", "opencode":
                selectInterfaceMode(.terminal)
                executionEngine = .ghostAgent
                messages.append(GhostMessage(role: .system, text: "[ok]\nGhost Code enabled."))
            default:
                messages.append(GhostMessage(role: .system, text: "Usage: /theme glass|terminal|code"))
            }
            return true
        case "/plan":
            codeAgentMode = .plan
            approvalMode = .ask
            messages.append(GhostMessage(role: .system, text: "[mode]\nPlan mode enabled. Ghost will inspect and propose changes before edits."))
            return true
        case "/build":
            codeAgentMode = .build
            executionEngine = .ghostAgent
            messages.append(GhostMessage(role: .system, text: "[mode]\nBuild mode enabled. File changes are tracked for /undo and /redo."))
            return true
        case "/explore":
            codeAgentMode = .explore
            messages.append(GhostMessage(role: .system, text: "[mode]\nExplore mode enabled. Ask Ghost to map or explain the codebase."))
            return true
        case "/review":
            codeAgentMode = .review
            runShellCommand("git status --short && printf '\\n--- diff stat ---\\n' && git diff --stat && printf '\\n--- diff ---\\n' && git diff --")
            return true
        case "/init":
            do {
                let files = projectContextService.listFiles(root: workspaceRootURL, limit: 200)
                let result = try openCodeCompatService.createOrUpdateAgentsFile(root: workspaceRootURL, projectFiles: files)
                messages.append(GhostMessage(role: .system, text: "[init]\n\(result) at \(workspaceRootURL.appendingPathComponent("AGENTS.md").path)\nCreated .opencode/commands for custom slash commands."))
            } catch {
                messages.append(GhostMessage(role: .system, text: "[error]\n\(error.localizedDescription)"))
            }
            return true
        case "/pwd", "/cwd":
            messages.append(GhostMessage(role: .system, text: "[cwd]\n\(workspaceRootURL.path)"))
            return true
        case "/cd":
            guard parts.count > 1 else {
                messages.append(GhostMessage(role: .system, text: "Usage: /cd path"))
                return true
            }
            setWorkingDirectory(parts.dropFirst().joined(separator: " "))
            return true
        case "/files":
            let query = arguments
            let files = projectContextService.listFiles(
                root: workspaceRootURL,
                matching: query.isEmpty ? nil : query,
                limit: 120
            )
            let body = files.isEmpty ? "No matching files." : files.map { "@\($0)" }.joined(separator: "\n")
            messages.append(GhostMessage(role: .system, text: "[files]\n\(body)"))
            return true
        case "/open", "/cat":
            guard parts.count > 1 else {
                messages.append(GhostMessage(role: .system, text: "Usage: /open @path/to/file"))
                return true
            }
            do {
                let context = try projectContextService.readFileReference(parts[1], root: workspaceRootURL, maxBytes: 32_000)
                messages.append(GhostMessage(role: .system, text: """
                [file] @\(context.relativePath)\(context.wasTruncated ? " (truncated)" : "")
                \(context.contents)
                """))
            } catch {
                messages.append(GhostMessage(role: .system, text: "[error]\n\(error.localizedDescription)"))
            }
            return true
        case "/grep":
            let pattern = arguments
            guard !pattern.isEmpty else {
                messages.append(GhostMessage(role: .system, text: "Usage: /grep search text"))
                return true
            }
            runShellCommand("grep -RIn --exclude-dir=.git --exclude-dir=.build --exclude-dir=node_modules -- \(shellQuoted(pattern)) . | head -200")
            return true
        case "/ls":
            runShellCommand("ls -la")
            return true
        case "/copy":
            let lastAnswer = messages.last { $0.role == .ghost }?.text
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(lastAnswer ?? "", forType: .string)
            messages.append(GhostMessage(role: .system, text: lastAnswer == nil ? "[copy]\nNo answer to copy." : "[copy]\nCopied last answer."))
            return true
        case "/stop":
            cancelCurrentRun()
            return true
        default:
            let rawCommandName = String(verb.dropFirst())
            if let custom = openCodeCompatService.customCommand(named: rawCommandName, root: workspaceRootURL) {
                let rendered = custom.render(arguments: arguments)
                prompt = rendered
                messages.append(GhostMessage(role: .system, text: "[command] /\(custom.name)\nExpanded custom command into the composer. Press Return to run it."))
                return true
            }
            messages.append(GhostMessage(role: .system, text: "Unknown command: \(verb). Type /help."))
            return true
        }
    }

    private func appendVerificationBlock(_ block: String, to text: String) -> String {
        let trimmedBlock = block.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBlock.isEmpty else { return text }

        return [text, trimmedBlock]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func taskVerificationBlock(
        result: GhostRunResult,
        runEngine: ExecutionEngine,
        intent: GhostDetectedIntent,
        producedDocuments: [GhostProducedDocument]
    ) -> String {
        guard isTaskVerificationEnabled else { return "" }

        let shouldVerify = runEngine == .ghostAgent
            || intent.kind.requiresAgentTools
            || intent.usesWeb
            || intent.kind == .fileSummary
            || intent.kind == .localFiles
            || !producedDocuments.isEmpty
            || result.exitStatus != 0

        guard shouldVerify else { return "" }

        let statusText = result.exitStatus == 0 ? "completed" : "failed with exit \(result.exitStatus)"
        var lines: [String] = [
            "## Verification",
            "- Status: \(statusText).",
            "- Route: \(runEngine.title) using \(result.provider.title) · \(result.model)."
        ]

        if !routingShortLine.isEmpty {
            lines.append("- Routing: \(routingShortLine).")
        }

        if producedDocuments.isEmpty {
            if intent.kind == .createArtifact {
                lines.append("- Files: no new verified output path was detected.")
            }
        } else {
            let fileList = producedDocuments
                .prefix(5)
                .map { "`\($0.path)`" }
                .joined(separator: ", ")
            lines.append("- Files: verified \(fileList).")
        }

        if intent.usesWeb {
            lines.append("- Sources: when web lookup is used, Ghost should include a References section with source URLs.")
        }

        return lines.joined(separator: "\n")
    }

    private func formatGhostResponse(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("Error: Response truncated due to output length limit")
            || trimmed.contains("Response truncated due to output length limit") {
            return "Ghost couldn't finish — the output was too long. Try increasing effort to Medium or High for longer responses."
        }

        if trimmed.hasPrefix("Error: Stream repeatedly dropped mid tool-call")
            || trimmed.contains("Stream repeatedly dropped mid tool-call") {
            return "Ghost couldn't finish — the network connection dropped repeatedly. Try again."
        }

        if trimmed.hasPrefix("Error: First response truncated due to output length limit") {
            return "Ghost couldn't start — the first response was already too long. Try a shorter prompt or increase effort to Medium or High."
        }

        var output = trimmed
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        if let savedSummary = savedFileSummary(from: output) {
            return savedSummary
        }

        output = output.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return output
    }

    private func savedFileSummary(from output: String) -> String? {
        guard output.contains("Saved to ") || output.contains("Saved ") else {
            return nil
        }

        let patterns = [
            #"Saved to ([^\s]+)(?:\s+[—-]\s+(.+))?"#,
            #"Created ([^\s]+)(?:\s+[—-]\s+(.+))?"#,
            #"Wrote ([^\s]+)(?:\s+[—-]\s+(.+))?"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            guard
                let match = regex.matches(in: output, range: range).last,
                let pathRange = Range(match.range(at: 1), in: output)
            else {
                continue
            }

            let path = String(output[pathRange])
            let detail: String
            if
                match.numberOfRanges > 2,
                match.range(at: 2).location != NSNotFound,
                let detailRange = Range(match.range(at: 2), in: output)
            {
                detail = String(output[detailRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                detail = "Done."
            }

            return """
            Saved the file.

            - Path: `\(path)`
            - \(detail)
            """
        }

        return nil
    }

    private func activityRecorder() -> @Sendable (GhostActivityEntry) -> Void {
        { [weak self] entry in
            Task { @MainActor in
                self?.recordActivity(entry)
            }
        }
    }

    private func recordActivity(_ entry: GhostActivityEntry) {
        var entryToStore = entry

        if entry.kind == .output || entry.kind == .info || entry.kind == .command || entry.kind == .success {
            let cleanedTitle = consumeLiveProgressMarkers(from: entry.title)
            let cleanedDetail = consumeLiveProgressMarkers(from: entry.detail)

            entryToStore = GhostActivityEntry(
                kind: entry.kind,
                title: cleanedTitle,
                detail: cleanedDetail
            )

            let titleIsEmpty = cleanedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let detailIsEmpty = cleanedDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            if titleIsEmpty && detailIsEmpty {
                return
            }
        }

        activityEntries.append(entryToStore)

        if activityEntries.count > 80 {
            activityEntries.removeFirst(activityEntries.count - 80)
        }

        updateTaskTimeline(from: entryToStore)

        if entryToStore.kind == .success {
            if entryToStore.title == "Harness verified" {
                registerProducedDocument(path: entryToStore.detail, source: entryToStore.title)
            }

            for path in likelyFilePaths(in: entryToStore.detail) {
                registerProducedDocument(path: path, source: entryToStore.title)
            }
        }

        if entry.title == "Process launched", entry.detail.hasPrefix("pid ") {
            let pidString = entry.detail.replacingOccurrences(of: "pid ", with: "")
            activeProcessIdentifier = Int32(pidString)
        }
    }

    private func saveRecentPrompt(_ text: String) {
        recentPrompts.removeAll { $0 == text }
        recentPrompts.insert(text, at: 0)
        recentPrompts = Array(recentPrompts.prefix(8))
        UserDefaults.standard.set(recentPrompts, forKey: Self.recentPromptsDefaultsKey)
    }

    private func keyedEnvironment(for provider: GhostProvider) -> [String: String] {
        var values: [String: String] = [:]
        for keyType in apiKeyTypes(for: provider) {
            values[keyType.environmentKey] = secretsService.read(for: keyType)
                ?? ProcessInfo.processInfo.environment[keyType.environmentKey]
                ?? ""
        }
        return values
    }

    private func apiKeyTypes(for provider: GhostProvider) -> [ProviderAPIKey] {
        switch provider {
        case .lmStudio:
            // LM Studio is local; do not pass any cloud provider key into Agent/Hermes.
            return []

        case .ollama:
            // Local Ollama normally needs no key. Keep the optional Ollama Cloud key
            // out of LM Studio/DeepSeek/Claude/Gemini runs.
            return [.ollamaCloud]

        case .claude:
            return [.anthropic]

        case .gemini:
            return [.gemini]

        case .deepSeek:
            return [.deepSeek]

        case .openCodeGo:
            return [.openCodeGo]
        }
    }

    private func loadSavedAPIKeyState(clearDrafts: Bool = false) {
        savedAPIKeyProviders = Set(
            ProviderAPIKey.allCases.filter { provider in
                secretsService.hasValue(for: provider)
            }
        )
        if clearDrafts {
            apiKeyDrafts = [:]
        }
    }
}

private extension String {
    var expandingTildeInPath: String {
        (self as NSString).expandingTildeInPath
    }

    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
