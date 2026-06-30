import AppKit
import SwiftUI

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

struct GhostPanelView: View {
    @Bindable var store: GhostConversationStore
    var configuresWindow: Bool = true
    var panelSizeProvider: ((CGSize) -> CGSize)?
    var onPanelSizeChange: ((CGSize) -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fittedPanelSize: CGSize?
    @State private var miniReplyNaturalHeight: CGFloat = 0

    var body: some View {
        let preferredSize = effectivePreferredPanelSize
        let panelSize = fittedPanelSize ?? preferredSize

        ZStack {
            VisualEffectBackground(material: .hudWindow, blending: .behindWindow)
                .ignoresSafeArea()

            if store.visibleInterfaceMode == .terminal && !store.isOnboardingPresented {
                OpenCodeColors.appBackground
                    .ignoresSafeArea()
            } else {
                CosmicBackground()
                    .opacity(1.0)
                    .ignoresSafeArea()
            }

            if store.panelSizeMode == .mini {
                miniPanel
            } else {
                standardPanel
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .clipShape(RoundedRectangle(cornerRadius: GhostRadii.window, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GhostRadii.window, style: .continuous)
                .strokeBorder(GhostColors.windowEdge, lineWidth: 1)
        )
        .background(
            Group {
                Button("") { store.send() }.keyboardShortcut(.return, modifiers: .command)
                Button("") { store.toggleSettings() }.keyboardShortcut(",", modifiers: .command)
                Button("") { store.clearConversation() }.keyboardShortcut("k", modifiers: [.command, .shift])
                Button("") { store.toggleDictation() }.keyboardShortcut("d", modifiers: .command)
            }
            .opacity(0)
            .allowsHitTesting(false)
        )
        .preferredColorScheme(store.visibleInterfaceMode == .terminal ? .dark : store.appearanceMode.colorScheme)
        .background(windowConfigurator(preferredSize: preferredSize))
        .onAppear {
            store.applyAppearance()
            onPanelSizeChange?(preferredSize)
        }
        .onChange(of: preferredSize) { _, newSize in
            onPanelSizeChange?(newSize)
        }
    }

    @ViewBuilder
    private func windowConfigurator(preferredSize: CGSize) -> some View {
        if configuresWindow {
            PanelWindowConfigurator(
                appearance: store.visibleInterfaceMode == .terminal ? NSAppearance(named: .darkAqua) : store.appearanceMode.nsAppearance,
                preferredSize: preferredSize,
                minimumSize: store.minimumPanelSize,
                sizeMode: store.panelSizeMode,
                fittedSize: $fittedPanelSize
            )
        }
    }

    private var standardPanel: some View {
        VStack(spacing: 0) {
            if store.isOnboardingPresented {
                GhostOnboardingPanelView(store: store)
            } else {
                header

                if store.panelMode == .chat {
                    if store.visibleInterfaceMode == .terminal {
                        TerminalModeView(store: store)
                    } else {
                        CompactTelemetryStrip(store: store)
                        chatSurface
                    }
                } else {
                    SettingsPanelView(store: store)
                }
            }
        }
    }

    private var miniPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                GhostLogoMark(size: 28, showContainer: false)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Ghost")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(GhostColors.platinum)

                    Text(miniHeaderStatus)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                        .lineLimit(1)
                }

                Spacer()

                PanelSizeSwitcher(store: store)
            }

            miniReplyBubble

            HStack(spacing: 8) {
                TextField(store.isSending ? "Type follow-up, press Return to queue" : "Ask Ghost anything", text: $store.prompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(GhostColors.platinum)
                    .onSubmit { store.send() }

                SendStopButton(
                    isSending: store.isSending,
                    canSend: store.canSend,
                    send: store.send,
                    stop: store.cancelCurrentRun
                )
                .scaleEffect(0.88)
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(GhostColors.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(GhostColors.glassBorder, lineWidth: 1)
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var effectivePreferredPanelSize: CGSize {
        let preferredSize = store.panelSizeMode == .mini ? miniPreferredPanelSize : store.preferredPanelSize
        return panelSizeProvider?(preferredSize) ?? preferredSize
    }

    private var miniHeaderStatus: String {
        if store.isSending {
            return "\(store.presenceState.title) · \(store.currentWorkLine)"
        }

        return store.presenceState.detail
    }

    private var miniPreferredPanelSize: CGSize {
        let baseChromeHeight: CGFloat = 136
        let bubbleHeight = miniReplyBubbleHeight
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? 900
        let maximumPanelHeight = min(640, max(260, visibleHeight - 48))

        return CGSize(
            width: 430,
            height: min(maximumPanelHeight, max(210, baseChromeHeight + bubbleHeight))
        )
    }

    private var miniReplyBubbleHeight: CGFloat {
        let contentHeight = miniReplyNaturalHeight > 1 ? miniReplyNaturalHeight : miniFallbackReplyHeight
        let visibleHeight = NSScreen.main?.visibleFrame.height ?? 900
        let maximumPanelHeight = min(640, max(260, visibleHeight - 48))
        let maximumBubbleHeight = max(96, maximumPanelHeight - 136)

        return min(maximumBubbleHeight, max(72, contentHeight + 22))
    }

    private var miniReplyNeedsScroll: Bool {
        miniReplyNaturalHeight > miniReplyBubbleHeight - 22
    }

    private var miniFallbackReplyHeight: CGFloat {
        let text = miniHeightEstimationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return 44 }

        let estimatedWrappedLines = text
            .components(separatedBy: .newlines)
            .reduce(0) { partial, line in
                partial + max(1, Int(ceil(Double(max(line.count, 1)) / 52.0)))
            }

        let baseRows = miniLastUserText == nil ? 1 : 2
        return CGFloat(min(max(estimatedWrappedLines + baseRows, 2), 28)) * 20
    }

    private var miniHeightEstimationText: String {
        var parts: [String] = []

        if let user = miniLastUserText {
            parts.append("You: \(user)")
        }

        if let queued = miniQueuedFollowUpText {
            parts.append("Queued: \(queued)")
        }

        if store.isSending {
            if let activeAssistant = miniActiveAssistantText {
                parts.append("Ghost: \(activeAssistant)")
            } else {
                parts.append("Ghost is thinking: \(store.currentWorkLine)")
            }

            if store.taskTimeline.isVisible {
                parts.append(store.taskTimeline.progressText)
            }
        } else if let assistant = miniLatestAssistantText {
            parts.append("Ghost: \(assistant)")
        } else if let status = miniLatestStatusText {
            parts.append(status)
        } else {
            parts.append("Ask Ghost anything and keep the answer in this quick bubble.")
        }

        return parts.joined(separator: "\n")
    }

    private var miniLastUserText: String? {
        store.messages
            .last(where: { $0.role == .user })?
            .text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    private var miniQueuedFollowUpText: String? {
        store.queuedQuickAskPrompt?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    private var miniLatestAssistantText: String? {
        store.messages
            .last(where: { $0.role == .ghost })?
            .text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    private var miniLatestStatusText: String? {
        store.messages
            .last(where: { $0.role == .system })?
            .text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    private var miniActiveAssistantText: String? {
        guard store.isSending,
              let latestUser = store.messages.last(where: { $0.role == .user }),
              let latestAssistant = store.messages.last(where: { $0.role == .ghost }),
              latestAssistant.date >= latestUser.date
        else {
            return nil
        }

        return latestAssistant.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }

    private var miniReplyBubble: some View {
        Group {
            if miniReplyNeedsScroll {
                ScrollView(.vertical, showsIndicators: true) {
                    miniReplyContent
                }
                .frame(height: miniReplyBubbleHeight)
            } else {
                miniReplyContent
                    .frame(minHeight: miniReplyBubbleHeight - 22, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(GhostColors.bubbleFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(GhostColors.glassBorder, lineWidth: 1)
        )
        .textSelection(.enabled)
        .onPreferenceChange(MiniReplyHeightPreferenceKey.self) { height in
            guard height.isFinite, abs(height - miniReplyNaturalHeight) > 1 else { return }
            miniReplyNaturalHeight = height
        }
    }

    private var miniReplyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let user = miniLastUserText {
                MiniQuickMessageRow(role: "You", text: user, systemImage: "person.crop.circle.fill", isUser: true)
            }

            if let queued = miniQueuedFollowUpText {
                MiniQuickMessageRow(role: "Queued", text: queued, systemImage: "text.badge.plus", isUser: true)
            }

            if store.isSending {
                if let activeAssistant = miniActiveAssistantText {
                    MiniQuickMessageRow(role: "Ghost", text: activeAssistant, systemImage: "sparkles", isUser: false, isStreaming: true)
                } else {
                    MiniThinkingStatusRow(statusLine: store.currentWorkLine)
                }

                if store.taskTimeline.isVisible {
                    MiniTaskProgressStrip(timeline: store.taskTimeline)
                }
            } else if let assistant = miniLatestAssistantText {
                MiniQuickMessageRow(role: "Ghost", text: assistant, systemImage: "sparkles", isUser: false)
            } else if let status = miniLatestStatusText {
                MiniQuickMessageRow(role: "Status", text: status, systemImage: "info.circle", isUser: false)
            } else {
                Text("Ask Ghost anything and keep the answer in this quick bubble.")
                    .font(.system(size: 12))
                    .foregroundStyle(GhostColors.mutedPlatinum)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: MiniReplyHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        )
    }

    private var header: some View {
        HStack(spacing: headerControlSpacing) {
            brandHeader

            Spacer(minLength: usesCompactHeader ? 6 : 12)

            headerSelectorPills

            Spacer(minLength: usesCompactHeader ? 4 : 8)

            if !usesCompactHeader {
                GlassIconButton(
                    systemImage: "square.and.pencil",
                    help: "New chat",
                    isActive: false
                ) { store.startNewConversation() }

                GlassIconButton(
                    systemImage: "clock.arrow.circlepath",
                    help: "History",
                    isActive: store.isHistoryVisible
                ) { store.toggleHistory() }

                GlassIconButton(
                    systemImage: "tray.full",
                    help: "Document Studio",
                    isActive: store.isDocumentStudioVisible
                ) { store.toggleDocumentStudio() }
            }

            PanelSizeSwitcher(store: store)

            GlassIconButton(
                systemImage: "terminal.fill",
                help: "Toggle terminal",
                isActive: store.visibleInterfaceMode == .terminal,
                foreground: store.visibleInterfaceMode == .terminal ? OpenCodeColors.orange : nil
            ) {
                if store.visibleInterfaceMode == .terminal {
                    store.selectInterfaceMode(.glass)
                } else {
                    store.selectInterfaceMode(.terminal)
                }
            }

            GlassIconButton(
                systemImage: store.panelMode == .settings ? "bubble.left.and.text.bubble.right" : "gearshape",
                help: store.panelMode == .settings ? "Chat" : "Settings",
                isActive: store.panelMode == .settings
            ) { store.toggleSettings() }

            headerMoreMenu
        }
        .padding(.horizontal, usesCompactHeader ? 12 : GhostSpacing.wide)
        .padding(.top, usesCompactHeader ? 7 : 10)
        .padding(.bottom, usesCompactHeader ? 5 : 6)
        .frame(maxWidth: .infinity)
        .background {
            if store.visibleInterfaceMode == .terminal {
                OpenCodeColors.appBackground
            }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: usesCompactHeader ? 6 : 10) {
            GhostLogoMark(size: usesCompactHeader ? 24 : 46)

            Text("Ghost")
                .font(GhostTypography.displayBold(size: headerTitleSize))
                .tracking(usesCompactHeader ? 0 : -0.9)
                .foregroundStyle(store.visibleInterfaceMode == .terminal ? OpenCodeColors.text : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.84)
        }
        .layoutPriority(10)
        .accessibilityElement(children: .combine)
    }

    private var headerSelectorPills: some View {
        HStack(spacing: usesCompactHeader ? 5 : 8) {
            if usesCompactHeader {
                SelectorPill(
                    icon: "cpu",
                    title: store.effectiveProvider.title,
                    subtitle: store.modelDisplayName
                ) {
                    CosmicPopover {
                        ProviderPopoverContent(store: store)
                    }
                }
                .frame(width: providerSelectorWidth)

                SelectorPill(
                    icon: "speedometer",
                    title: store.effortMode.title(for: store.selectedProvider),
                    subtitle: runModeSubtitle
                ) {
                    CosmicPopover {
                        EffortPopoverContent(store: store)
                    }
                }
                .frame(width: effortSelectorWidth)
            } else {
                SelectorPill(
                    icon: "cpu",
                    title: store.effectiveProvider.title,
                    subtitle: store.modelDisplayName
                ) {
                    CosmicPopover {
                        ProviderPopoverContent(store: store)
                    }
                }
                .frame(width: providerSelectorWidth)

                SelectorPill(
                    icon: "speedometer",
                    title: store.effortMode.title(for: store.selectedProvider),
                    subtitle: runModeSubtitle
                ) {
                    CosmicPopover {
                        EffortPopoverContent(store: store)
                    }
                }
                .frame(width: effortSelectorWidth)
            }
        }
        .frame(maxWidth: usesCompactHeader ? providerSelectorWidth + effortSelectorWidth + 5 : providerSelectorWidth + effortSelectorWidth + 8)
        .layoutPriority(4)
    }

    private var headerMoreMenu: some View {
        Menu {
            Picker("Theme", selection: $store.appearanceMode) {
                ForEach(GhostAppearance.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            Divider()
            Picker("Terminal Output", selection: $store.ghostCodeOutputMode) {
                ForEach(GhostCodeOutputMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            Divider()
            Button { store.startNewConversation() } label: {
                Label("New Chat", systemImage: "square.and.pencil")
            }
            Button { store.toggleHistory() } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            Button { store.toggleDocumentStudio() } label: {
                Label("Document Studio", systemImage: "tray.full")
            }
            Button { store.exportConversationToDesktop() } label: {
                Label("Export to Markdown", systemImage: "square.and.arrow.up")
            }
            Button { store.togglePromptLibrary() } label: {
                Label("Prompt Library", systemImage: "bookmark")
            }
            Button { GhostUpdater.shared.checkForUpdates() } label: {
                Label("Check for Updates...", systemImage: "arrow.down.circle")
            }
            .disabled(!GhostUpdater.shared.canCheckForUpdates)
            Divider()
            Button { store.clearConversation() } label: {
                Label("Clear Chat", systemImage: "trash")
            }
            Button { store.toggleActivity() } label: {
                Label(store.isActivityVisible ? "Hide Telemetry" : "Telemetry", systemImage: "chart.bar.doc.horizontal")
            }
            Divider()
            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Ghost", systemImage: "power")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GhostColors.mutedPlatinum)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Text("More actions"))
    }

    private var usesCompactHeader: Bool {
        store.panelSizeMode == .normal && store.visibleInterfaceMode == .glass
    }

    private var headerControlSpacing: CGFloat {
        usesCompactHeader ? 4 : 10
    }

    private var providerSelectorWidth: CGFloat {
        190
    }

    private var effortSelectorWidth: CGFloat {
        174
    }

    private var headerTitleSize: CGFloat {
        if usesCompactHeader {
            return 21
        }

        return store.visibleInterfaceMode == .terminal ? 34 : 36
    }

    private var chatSurface: some View {
        VStack(spacing: 0) {
            transcript
            if store.isActivityVisible {
                TelemetryDrawerView(store: store)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            composer
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.isActivityVisible)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.isHistoryVisible)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.isPromptLibraryVisible)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: store.isDocumentStudioVisible)
        .overlay(alignment: .trailing) {
            if store.isDocumentStudioVisible {
                DocumentStudioDrawerView(store: store)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if store.isHistoryVisible {
                HistoryDrawerView(store: store)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if store.isPromptLibraryVisible {
                PromptLibraryPopover(store: store)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var transcript: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    if store.messages.isEmpty && !store.isSending {
                        emptyState
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .center
                            )
                    } else {
                        LazyVStack(alignment: .leading, spacing: GhostSpacing.relaxed) {
                            ForEach(store.messages) { message in
                                FloatingMessageCard(message: message, store: store)
                                    .id(message.id)

                                if store.taskTimeline.isVisible,
                                   store.taskTimelineAnchorMessageID == message.id {
                                    GhostTaskTimelineCard(store: store)
                                        .id("task-timeline")
                                }
                            }

                            if store.taskTimeline.isVisible,
                               store.taskTimelineAnchorMessageID == nil {
                                GhostTaskTimelineCard(store: store)
                                    .id("task-timeline")
                            }

                            if store.isSending {
                                WorkingCard(statusLine: store.currentWorkLine)
                                    .id("working-card")
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("chat-bottom")
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: proxy.frame(in: .named("ghostScroll")).minY
                                        )
                                    }
                                )
                        }
                        .padding(.horizontal, GhostSpacing.wide)
                        .padding(.vertical, GhostSpacing.relaxed)
                        .padding(.bottom, GhostSpacing.wide)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .coordinateSpace(name: "ghostScroll")
                .overlay(alignment: .bottom) {
                    if !store.messages.isEmpty && store.isScrolledAwayFromBottom {
                        Button {
                            scrollToBottom(proxy, animated: true)
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(GhostColors.platinum)
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle()
                                        .fill(GhostColors.popoverFill)
                                        .overlay(Circle().stroke(GhostColors.glassBorder, lineWidth: 1))
                                )
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                        }
                        .buttonStyle(PressableButtonStyle(reduceMotion: reduceMotion))
                        .padding(.bottom, 10)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .onChange(of: store.messages.count) { _, _ in
                    scrollToBottom(proxy, animated: true)
                }
                .onChange(of: store.messages) { _, _ in
                    store.schedulePersist()
                    if store.isPinnedToBottom {
                        scrollToBottom(proxy, animated: true)
                    }
                }
                // Do not auto-scroll on every taskTimeline mutation. Timeline updates
                // stream frequently and yanking the viewport makes manual scrolling feel broken.
                .onChange(of: store.isSending) { _, isSending in
                    if isSending { scrollToBottom(proxy, animated: true) }
                }
                .onChange(of: store.isActivityVisible) { _, _ in
                    scrollToBottom(proxy, animated: true)
                }
                .onAppear {
                    scrollToBottom(proxy, animated: false)
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    store.isPinnedToBottom = value <= 48
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func scrollToBottom(
        _ proxy: ScrollViewProxy,
        fallbackID: GhostMessage.ID? = nil,
        animated: Bool = true
    ) {
        let action = {
            if store.isSending {
                proxy.scrollTo("chat-bottom", anchor: .bottom)
            } else if let fallbackID {
                proxy.scrollTo(fallbackID, anchor: .bottom)
            } else {
                proxy.scrollTo("chat-bottom", anchor: .bottom)
            }
        }

        DispatchQueue.main.async {
            if animated && !reduceMotion {
                withAnimation(.easeOut(duration: 0.12)) {
                    action()
                }
            } else {
                action()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            CenterGhostEmblem(size: 96, state: store.ghostOrbState)

            VStack(spacing: 10) {
                GhostTypography.glassGradientDisplay("How can I help?", size: 36, tracking: -0.7)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("Ask anything. Ghost will figure out whether to research, read files, create artifacts, or code in the terminal.")
                    .font(GhostFonts.hkGrotesk(size: 17, weight: .regular))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(spacing: 12) {
                EmptyChip("Explain latest screenshot") { store.prompt = "Explain the latest screenshot" }
                EmptyChip("Find a file") { store.prompt = "Find the file about " }
                EmptyChip("Create a file") { store.prompt = "Create a file named " }
                EmptyChip("Debug code") { store.prompt = "Debug this error in the current project" }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if !store.savedPrompts.isEmpty {
                VStack(spacing: 8) {
                    Text("Saved prompts")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(GhostColors.faintPlatinum)
                        .textCase(.uppercase)

                    HStack(spacing: 8) {
                        ForEach(store.savedPrompts.prefix(4)) { prompt in
                            EmptyChip(prompt.title) { store.useSavedPrompt(prompt) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.white.opacity(0.05))
                .frame(height: 1)

            if let attachment = store.pendingImageAttachment {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(attachment.filename) · \(attachment.sizeDescription)")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .lineLimit(1)
                    Spacer()
                    Button {
                        store.clearPendingImageAttachment()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help("Remove screenshot")
                }
                .foregroundStyle(GhostColors.mutedPlatinum)
                .padding(.horizontal, GhostSpacing.wide)
                .padding(.top, GhostSpacing.standard)
            }

            HStack(alignment: .bottom, spacing: GhostSpacing.standard) {
                ComposerButton(systemImage: "doc.on.clipboard", help: "Use Clipboard") {
                    store.useClipboard()
                }

                ComposerButton(
                    systemImage: "bookmark",
                    help: "Prompt Library",
                    isActive: store.isPromptLibraryVisible
                ) {
                    store.togglePromptLibrary()
                }

                ComposerButton(
                    systemImage: store.speechRecognizer.isRecording ? "mic.fill" : "mic",
                    help: store.speechRecognizer.isRecording ? "Stop Dictation" : "Dictate",
                    isActive: store.speechRecognizer.isRecording
                ) {
                    store.toggleDictation()
                }

                ComposerTextView(
                    text: $store.prompt,
                    placeholder: "How can I help?",
                    onSubmit: { store.send() },
                    onPasteImage: { image in store.attachPastedScreenshot(image) }
                )
                .frame(maxWidth: .infinity)
                .frame(height: composerHeight)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .ghostGlass(cornerRadius: 12, isActive: false)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(GhostColors.royalViolet.opacity(0.12), lineWidth: 1)
                )

                SendStopButton(
                    isSending: store.isSending,
                    canSend: store.canSend,
                    send: store.send,
                    stop: store.cancelCurrentRun
                )
            }
            .padding(.horizontal, GhostSpacing.wide)
            .padding(.vertical, GhostSpacing.standard)
        }
        .background(GhostColors.barFill)
        .background(.ultraThinMaterial.opacity(0.3))
    }

    private var composerHeight: CGFloat {
        max(32, min(CGFloat(store.prompt.split(separator: "\n").count) * 18 + 14, 100))
    }

    private var runModeSubtitle: String {
        guard store.executionEngine == .ghostAgent else {
            return "Direct API"
        }
        let base = "\(store.approvalMode.title) approval"
        return store.approvalMode == .yolo ? "\u{26A0} " + base : base
    }
}

private struct PanelSizeSwitcher: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        HStack(spacing: 2) {
            ForEach(GhostPanelSizeMode.allCases) { mode in
                Button {
                    store.selectPanelSize(mode)
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(store.panelSizeMode == mode ? GhostColors.platinum : GhostColors.mutedPlatinum)
                        .frame(width: 23, height: 24)
                        .contentShape(RoundedRectangle(cornerRadius: GhostRadii.mini, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: GhostRadii.mini, style: .continuous)
                                .fill(store.panelSizeMode == mode ? GhostColors.glassActiveFill : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(mode.help)
                .accessibilityLabel(Text(mode.help))
            }
        }
        .padding(1)
        .background(
            RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous)
                .fill(GhostColors.glassFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous)
                .stroke(GhostColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Terminal Mode

private enum OpenCodeColors {
    static var appBackground: Color { GhostTerminalTheme.saved.appBackground }
    static var transcriptBackground: Color { GhostTerminalTheme.saved.transcriptBackground }
    static var sidebarBackground: Color { GhostTerminalTheme.saved.sidebarBackground }
    static var promptBackground: Color { GhostTerminalTheme.saved.promptBackground }
    static var border: Color { GhostTerminalTheme.saved.border }
    static var text: Color { GhostTerminalTheme.saved.text }
    static var muted: Color { GhostTerminalTheme.saved.muted }
    static var faint: Color { GhostTerminalTheme.saved.faint }
    static var orange: Color { GhostTerminalTheme.saved.orange }
    static var green: Color { GhostTerminalTheme.saved.green }
    static var yellow: Color { GhostTerminalTheme.saved.yellow }
    static var cyan: Color { GhostTerminalTheme.saved.cyan }
    static var purple: Color { GhostTerminalTheme.saved.purple }
}

private struct TerminalModeView: View {
    @Bindable var store: GhostConversationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            terminalTopStatus
            GhostCodeContextStrip(store: store)

            transcriptPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            terminalPrompt
        }
        .background(OpenCodeColors.appBackground)
        .font(.system(size: 13, design: .monospaced))
    }

    private var transcriptPane: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if store.messages.isEmpty && !store.isSending {
                        OpenCodeWelcomeView(store: store)
                    }

                    ForEach(store.messages) { message in
                        TerminalMessageView(store: store, message: message, outputMode: store.ghostCodeOutputMode)
                            .id(message.id)

                        if store.taskTimeline.isVisible,
                           store.taskTimelineAnchorMessageID == message.id {
                            TerminalTaskTimelineView(store: store)
                                .id("terminal-task-timeline")
                        }
                    }

                    if store.taskTimeline.isVisible,
                       store.taskTimelineAnchorMessageID == nil {
                        TerminalTaskTimelineView(store: store)
                            .id("terminal-task-timeline")
                    }

                    if store.isSending {
                        TerminalLineView(
                            kind: .thinking,
                            text: "+ Thought: \(store.currentWorkLine.lowercased())…",
                            streaming: true
                        )
                        .id("terminal-thinking")
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("terminal-bottom")
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 34)
            }
            .background(OpenCodeColors.transcriptBackground)
            .onChange(of: store.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            // Do not auto-scroll on every taskTimeline mutation. It updates too
            // often and should not fight the user's manual scroll position.
            .onChange(of: store.isSending) { _, isSending in
                if isSending { scrollToBottom(proxy) }
            }
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
        }
    }

    private var terminalTopStatus: some View {
        let snap = store.telemetrySnapshot
        return HStack(spacing: 10) {
            Circle()
                .fill(statusColor(for: snap.status))
                .frame(width: 7, height: 7)

            Text(snap.status.rawValue.capitalized)
                .foregroundStyle(statusColor(for: snap.status))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))

            Text("·")
                .foregroundStyle(OpenCodeColors.faint)

            Text(store.currentIntent.title)
                .foregroundStyle(OpenCodeColors.orange)
                .fontWeight(.semibold)

            Text("·")
                .foregroundStyle(OpenCodeColors.faint)

            Text("@")
                .foregroundStyle(OpenCodeColors.purple)
            Text(shortWorkspaceName)
                .foregroundStyle(OpenCodeColors.text)

            Spacer()

            Text("model \(store.modelDisplayName)")
                .foregroundStyle(OpenCodeColors.muted)
            Text("effort \(store.effortMode.title(for: store.selectedProvider).lowercased())")
                .foregroundStyle(OpenCodeColors.muted)
            Text("approval \(store.approvalMode.title.lowercased())")
                .foregroundStyle(OpenCodeColors.muted)
            Text("ctx \(formattedTokens(snap.estimatedPromptTokens + snap.estimatedResponseTokens))")
                .foregroundStyle(OpenCodeColors.muted)
            Text("events \(snap.activityEventCount)")
                .foregroundStyle(OpenCodeColors.muted)

            Button {
                store.toggleGhostCodeOutputMode()
            } label: {
                Text("view \(store.ghostCodeOutputMode.rawValue)")
                    .foregroundStyle(OpenCodeColors.cyan)
            }
            .buttonStyle(.plain)
            .help("Toggle Terminal/Markdown Ghost Code output")

            Button {
                store.isTerminalToolDetailsVisible.toggle()
            } label: {
                Text("details \(store.isTerminalToolDetailsVisible ? "on" : "off")")
                    .foregroundStyle(OpenCodeColors.muted)
            }
            .buttonStyle(.plain)
            .help("Toggle command/stdout/stderr detail lines")
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(OpenCodeColors.appBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(OpenCodeColors.border)
                .frame(height: 1)
        }
    }

    private var terminalPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $store.prompt)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(OpenCodeColors.text)
                .disabled(store.isSending)
                .onSubmit { store.send() }
                .placeholder(when: store.prompt.isEmpty) {
                    Text("Ask, code, /command, !shell, or @file")
                        .foregroundStyle(OpenCodeColors.faint)
                        .font(.system(size: 14, design: .monospaced))
                }

            HStack(spacing: 6) {
                Text("Mode: \(store.codeAgentMode.title)")
                    .foregroundStyle(OpenCodeColors.purple)
                Text("·")
                    .foregroundStyle(OpenCodeColors.faint)
                Text("Model: \(store.modelDisplayName)")
                    .foregroundStyle(OpenCodeColors.text)
                Text("·")
                    .foregroundStyle(OpenCodeColors.faint)
                Text("Effort: \(store.effortMode.title(for: store.selectedProvider))")
                    .foregroundStyle(OpenCodeColors.muted)
                Text("·")
                    .foregroundStyle(OpenCodeColors.faint)
                Text("Approval: \(store.approvalMode.title)")
                    .foregroundStyle(OpenCodeColors.yellow)

                Spacer()

                Button {
                    store.isSending ? store.cancelCurrentRun() : store.send()
                } label: {
                    Text(store.isSending ? "stop" : "run")
                        .foregroundStyle(store.isSending ? .red.opacity(0.9) : OpenCodeColors.green)
                }
                .buttonStyle(.plain)
                .disabled(!store.isSending && !store.canSend)
                .opacity((store.isSending || store.canSend) ? 1 : 0.35)
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(.leading, 26)
        .padding(.trailing, 18)
        .padding(.vertical, 12)
        .background(OpenCodeColors.promptBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(OpenCodeColors.purple)
                .frame(width: 3)
                .padding(.vertical, 8)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(OpenCodeColors.border)
                .frame(height: 1)
        }
    }

    private var shortWorkspaceName: String {
        URL(fileURLWithPath: (store.workingDirectoryPath as NSString).expandingTildeInPath).lastPathComponent.nonEmpty ?? "~"
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async {
            if animated && !reduceMotion {
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo("terminal-bottom", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("terminal-bottom", anchor: .bottom)
            }
        }
    }

    private func statusColor(for status: GhostRunStatus) -> Color {
        switch status {
        case .running: OpenCodeColors.purple
        case .completed: OpenCodeColors.green
        case .failed, .stopped: .red.opacity(0.88)
        case .idle: OpenCodeColors.muted
        }
    }

    private func formattedTokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fm", Double(value) / 1_000_000.0)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000.0)
        }
        return "\(value)"
    }
}

private struct OpenCodeWelcomeView: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("[Universal prompt ready]")
                .foregroundStyle(OpenCodeColors.text)

            VStack(alignment: .leading, spacing: 4) {
                Text("[1 / 5] Ask normally — no visible modes")
                Text("[2 / 5] Coding prompts run here in Ghost's terminal")
                Text("[3 / 5] File prompts can search, summarize, or create artifacts")
                Text("[4 / 5] Use @path for explicit workspace files")
                Text("[5 / 5] Use !command for direct shell commands when needed")
            }
            .foregroundStyle(OpenCodeColors.muted)

            Text("…")
                .foregroundStyle(OpenCodeColors.muted)

            Text("Live todos appear as soon as Ghost plans work.")
                .foregroundStyle(OpenCodeColors.faint)
                .padding(.top, 6)

            Text("+ Thought: ready")
                .foregroundStyle(OpenCodeColors.yellow)
                .padding(.top, 22)
        }
        .font(.system(size: 13, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


private struct GhostCodeContextStrip: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                contextChip("Context", "\(formattedTokens(totalTokens)) tokens · \(contextPercent)%")
                ForEach(store.activeContextChips) { chip in
                    contextChip(chip.title, chip.detail, isActive: chip.isActive)
                }
                contextChip("Tools", inferredTools.joined(separator: " · "))
                contextChip("Workspace", shortPath)
                contextChip("Commands", "/ask /create /files /grep /undo /view")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
        }
        .background(OpenCodeColors.sidebarBackground.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(OpenCodeColors.border)
                .frame(height: 1)
        }
    }

    private func contextChip(_ title: String, _ value: String, isActive: Bool = true) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(OpenCodeColors.text)
            Text(value)
                .foregroundStyle(OpenCodeColors.muted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(OpenCodeColors.promptBackground.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(OpenCodeColors.border, lineWidth: 1)
        )
        .opacity(isActive ? 1.0 : 0.45)
    }

    private var totalTokens: Int {
        store.telemetrySnapshot.estimatedPromptTokens + store.telemetrySnapshot.estimatedResponseTokens
    }

    private var contextPercent: Int {
        min(99, max(0, Int((Double(totalTokens) / Double(max(store.localContextWindow, 1))) * 100.0)))
    }

    private var shortPath: String {
        let path = (store.workingDirectoryPath as NSString).expandingTildeInPath
        let home = NSHomeDirectory()
        return path.replacingOccurrences(of: home, with: "~")
    }

    private var inferredTools: [String] {
        let root = URL(fileURLWithPath: (store.workingDirectoryPath as NSString).expandingTildeInPath)
        var items: [String] = []
        let fm = FileManager.default
        if fm.fileExists(atPath: root.appendingPathComponent("Package.swift").path) { items.append("sourcekit-lsp") }
        if fm.fileExists(atPath: root.appendingPathComponent("package.json").path) { items.append("typescript-lsp") }
        if fm.fileExists(atPath: root.appendingPathComponent(".git").path) { items.append("git") }
        items.append("bash")
        return items
    }

    private func formattedTokens(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fm", Double(value) / 1_000_000.0) }
        if value >= 1_000 { return String(format: "%.1fk", Double(value) / 1_000.0) }
        return "\(value)"
    }
}

private struct GhostCodeInspectorSidebar: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Ghost OpenCode integration")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(OpenCodeColors.text)
                .padding(.top, 24)

            sidebarSection("Context") {
                let snap = store.telemetrySnapshot
                Text("\(formattedTokens(snap.estimatedPromptTokens + snap.estimatedResponseTokens)) tokens")
                Text("\(contextPercent)% used")
                Text("\(store.codeAgentMode.title.lowercased()) mode")
            }

            sidebarSection("LSP") {
                ForEach(inferredTools, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(OpenCodeColors.green)
                            .frame(width: 7, height: 7)
                        Text(item)
                    }
                }
            }

            sidebarSection("Commands") {
                Text("/init  /plan  /build")
                Text("/review  /undo  /redo")
                Text("/details  /sessions")
            }

            Spacer()

            Text(shortPath)
                .foregroundStyle(OpenCodeColors.muted)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
                .padding(.bottom, 18)
        }
        .font(.system(size: 13, design: .monospaced))
        .foregroundStyle(OpenCodeColors.muted)
        .padding(.horizontal, 20)
        .background(OpenCodeColors.sidebarBackground)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(OpenCodeColors.border)
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("▾")
                    .foregroundStyle(OpenCodeColors.text)
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(OpenCodeColors.text)
            }

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .foregroundStyle(OpenCodeColors.muted)
            .padding(.leading, 14)
        }
    }

    private var shortPath: String {
        let path = (store.workingDirectoryPath as NSString).expandingTildeInPath
        let home = NSHomeDirectory()
        return path.replacingOccurrences(of: home, with: "~")
    }

    private var contextPercent: Int {
        let total = store.telemetrySnapshot.estimatedPromptTokens + store.telemetrySnapshot.estimatedResponseTokens
        return min(99, max(0, Int((Double(total) / Double(max(store.localContextWindow, 1))) * 100.0)))
    }

    private var inferredTools: [String] {
        let root = URL(fileURLWithPath: (store.workingDirectoryPath as NSString).expandingTildeInPath)
        var items: [String] = []
        let fm = FileManager.default
        if fm.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
            items.append("sourcekit-lsp \(root.lastPathComponent)/")
        }
        if fm.fileExists(atPath: root.appendingPathComponent("package.json").path) {
            items.append("typescript-language-server \(root.lastPathComponent)/")
        }
        if fm.fileExists(atPath: root.appendingPathComponent(".git").path) {
            items.append("git \(root.lastPathComponent)/")
        }
        items.append("bash")
        return items
    }

    private func formattedTokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.0f,%03.0f", floor(Double(value) / 1_000.0), Double(value).truncatingRemainder(dividingBy: 1_000))
        }
        return "\(value)"
    }
}

private enum TerminalLineKind {
    case prompt
    case assistant
    case system
    case thinking
    case error
}

private struct TerminalTaskTimelineView: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 0.35)) { context in
            content(timeline: store.taskTimeline, now: context.date)
        }
    }

    private func content(timeline: GhostTaskTimeline, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("# Todos")
                    .foregroundStyle(OpenCodeColors.muted)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))

                if !timeline.isFinished {
                    Text("•")
                        .foregroundStyle(OpenCodeColors.faint)
                    Text(elapsedText(for: timeline, now: now))
                        .foregroundStyle(OpenCodeColors.faint)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                }
            }

            if !timeline.isFinished {
                HStack(spacing: 8) {
                    Text("[~]")
                        .foregroundStyle(OpenCodeColors.yellow)
                    Text(timeline.currentLine)
                        .foregroundStyle(OpenCodeColors.text)
                        .lineLimit(1)
                    Text(liveDots(now: now))
                        .foregroundStyle(OpenCodeColors.yellow)
                }
            }

            if timeline.isWaitingForGhostPlan && timeline.steps.isEmpty {
                HStack(spacing: 8) {
                    Text("[~]")
                        .foregroundStyle(OpenCodeColors.yellow)

                    Text("Creating todo plan")
                        .foregroundStyle(OpenCodeColors.text)
                }
            }

            if !timeline.steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(timeline.steps) { step in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(step.state.todoPrefix)
                                    .foregroundStyle(color(for: step.state))

                                Text(step.title)
                                    .foregroundStyle(color(for: step.state))
                            }

                            if !step.detail.isEmpty {
                                Text("    \(step.detail)")
                                    .foregroundStyle(OpenCodeColors.faint)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }

            if let summary = timeline.summary, timeline.isFinished {
                Text("")
                Text("# Result")
                    .foregroundStyle(OpenCodeColors.muted)

                Text(summary)
                    .foregroundStyle(OpenCodeColors.green)
            }

            if let error = timeline.error {
                Text("")
                Text("# Result")
                    .foregroundStyle(OpenCodeColors.muted)

                Text(error)
                    .foregroundStyle(.red.opacity(0.88))
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(OpenCodeColors.appBackground.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(OpenCodeColors.border, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func color(for state: GhostTaskStepState) -> Color {
        switch state {
        case .pending:
            return OpenCodeColors.muted
        case .running:
            return OpenCodeColors.yellow
        case .completed:
            return OpenCodeColors.green
        case .failed:
            return .red.opacity(0.88)
        }
    }

    private func elapsedText(for timeline: GhostTaskTimeline, now: Date) -> String {
        guard let startedAt = timeline.startedAt else { return "working" }
        let seconds = max(0, Int(now.timeIntervalSince(startedAt)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func liveDots(now: Date) -> String {
        let count = Int(now.timeIntervalSinceReferenceDate * 2).isMultiple(of: 3) ? 1 : (Int(now.timeIntervalSinceReferenceDate * 2) % 3) + 1
        return String(repeating: ".", count: count)
    }
}

private struct TerminalMessageView: View {
    @Bindable var store: GhostConversationStore
    let message: GhostMessage
    let outputMode: GhostCodeOutputMode

    var body: some View {
        if message.role == .system && !store.isTerminalToolDetailsVisible && Self.isToolDetail(message.text) {
            EmptyView()
        } else {
            switch message.role {
            case .user:
                TerminalLineView(kind: .prompt, text: "\(store.terminalLinePrefix(for: .user)) \(message.text)")
            case .ghost:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button {
                            store.copyMessage(id: message.id)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(OpenCodeColors.faint)
                                .frame(width: 26, height: 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(OpenCodeColors.appBackground.opacity(0.72))
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Copy answer")
                    }

                    if outputMode == .markdown {
                        GhostCodeMarkdownOutputView(text: message.text)
                    } else {
                        TerminalAssistantOutputView(text: message.text)
                    }
                }
            case .system:
                TerminalLineView(kind: terminalKind(for: message.text), text: message.text.hasPrefix("[") || message.text.hasPrefix("+") ? message.text : "\(store.terminalLinePrefix(for: .system)) \(message.text)")
            }
        }
    }

    private func terminalKind(for text: String) -> TerminalLineKind {
        text.hasPrefix("[error]") || text.hasPrefix("[stderr]") ? .error : .system
    }

    private static func isToolDetail(_ text: String) -> Bool {
        text.hasPrefix("[cmd]") || text.hasPrefix("[stdout]") || text.hasPrefix("[stderr]") || text.hasPrefix("[exit")
    }
}


private struct GhostCodeMarkdownOutputView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("ghost")
                    .foregroundStyle(OpenCodeColors.purple)
                    .fontWeight(.semibold)
                Text("markdown")
                    .foregroundStyle(OpenCodeColors.faint)
            }
            .font(.system(size: 12, design: .monospaced))

            MarkdownMessageText(text: text)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(OpenCodeColors.appBackground.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(OpenCodeColors.border, lineWidth: 1)
        )
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TerminalAssistantOutputView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                TerminalLineView(kind: kind(for: line), text: line)
            }
        }
    }

    private var lines: [String] {
        text.components(separatedBy: "\n")
    }

    private func kind(for line: String) -> TerminalLineKind {
        if line.hasPrefix("[error]") || line.hasPrefix("[stderr]") { return .error }
        if line.hasPrefix("+") || line.hasPrefix("[thinking]") { return .thinking }
        if line.hasPrefix("[") { return .system }
        return .assistant
    }
}

private struct TerminalLineView: View {
    let kind: TerminalLineKind
    let text: String
    var streaming: Bool = false

    var body: some View {
        Text(text + (streaming ? " █" : ""))
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(color)
            .lineSpacing(4)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var color: Color {
        switch kind {
        case .prompt:
            OpenCodeColors.purple
        case .assistant:
            OpenCodeColors.text
        case .system:
            OpenCodeColors.muted
        case .thinking:
            OpenCodeColors.yellow
        case .error:
            .red.opacity(0.9)
        }
    }
}

private extension View {
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: () -> Content) -> some View {
        overlay(alignment: alignment) {
            if shouldShow {
                placeholder()
                    .allowsHitTesting(false)
            }
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Ghost Logo

private struct GhostLogoMark: View {
    var size: CGFloat = 48
    var showContainer: Bool = true
    var showAccentStar: Bool = false

    var body: some View {
        ZStack {
            if showContainer {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                GhostColors.royalViolet.opacity(0.26),
                                Color.white.opacity(0.055),
                                Color.black.opacity(0.16)
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: size * 0.62
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        GhostColors.royalViolet.opacity(0.18),
                                        Color.white.opacity(0.045)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: GhostColors.royalViolet.opacity(0.24), radius: 14, y: 4)
            }

            GhostMascotView(
                mascotSize: size * 0.88,
                isLarge: false
            )
            .offset(y: size * 0.015)

            if showAccentStar {
                Circle()
                    .fill(GhostColors.champagne.opacity(0.95))
                    .frame(width: size * 0.075, height: size * 0.075)
                    .shadow(color: GhostColors.champagne.opacity(0.35), radius: 5)
                    .offset(x: size * 0.25, y: -size * 0.29)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Ghost logo")
    }
}

private struct GhostMascotView: View {
    var mascotSize: CGFloat
    var isLarge: Bool = false

    var body: some View {
        let bodyWidth = mascotSize * 0.78
        let bodyHeight = mascotSize * 1.02

        ZStack {
            GhostMascotShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.99),
                            Color(red: 0.94, green: 0.96, blue: 1.0).opacity(0.96),
                            Color(red: 0.82, green: 0.86, blue: 0.98).opacity(0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: bodyWidth, height: bodyHeight)
                .shadow(color: Color.white.opacity(0.26), radius: isLarge ? 12 : 7, y: 1)
                .shadow(color: GhostColors.royalViolet.opacity(isLarge ? 0.35 : 0.23), radius: isLarge ? 22 : 12, y: 5)

            GhostInnerArmShade()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.54, green: 0.60, blue: 0.86).opacity(isLarge ? 0.28 : 0.18),
                            Color(red: 0.42, green: 0.36, blue: 0.70).opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: bodyWidth, height: bodyHeight)
                .mask(
                    GhostMascotShape()
                        .frame(width: bodyWidth, height: bodyHeight)
                )
                .blendMode(.multiply)

            HStack(spacing: mascotSize * 0.15) {
                Capsule()
                    .fill(Color(red: 0.025, green: 0.030, blue: 0.095).opacity(0.90))
                    .frame(width: mascotSize * 0.075, height: mascotSize * 0.175)

                Capsule()
                    .fill(Color(red: 0.025, green: 0.030, blue: 0.095).opacity(0.90))
                    .frame(width: mascotSize * 0.075, height: mascotSize * 0.175)
            }
            .offset(x: mascotSize * 0.055, y: -mascotSize * 0.145)
        }
        .frame(width: mascotSize, height: mascotSize)
    }
}

private struct GhostMascotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.55, y: h * 0.025))

        path.addCurve(
            to: CGPoint(x: w * 0.17, y: h * 0.35),
            control1: CGPoint(x: w * 0.34, y: h * 0.015),
            control2: CGPoint(x: w * 0.18, y: h * 0.12)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.055, y: h * 0.57),
            control1: CGPoint(x: w * 0.16, y: h * 0.44),
            control2: CGPoint(x: w * 0.08, y: h * 0.48)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.285, y: h * 0.575),
            control1: CGPoint(x: w * -0.02, y: h * 0.755),
            control2: CGPoint(x: w * 0.20, y: h * 0.705)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.225, y: h * 0.785),
            control1: CGPoint(x: w * 0.275, y: h * 0.66),
            control2: CGPoint(x: w * 0.215, y: h * 0.71)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.355, y: h * 0.835),
            control1: CGPoint(x: w * 0.23, y: h * 0.855),
            control2: CGPoint(x: w * 0.31, y: h * 0.84)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.255, y: h * 0.965),
            control1: CGPoint(x: w * 0.31, y: h * 0.895),
            control2: CGPoint(x: w * 0.235, y: h * 0.925)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.585, y: h * 0.92),
            control1: CGPoint(x: w * 0.36, y: h * 1.03),
            control2: CGPoint(x: w * 0.51, y: h * 1.00)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.805, y: h * 0.615),
            control1: CGPoint(x: w * 0.755, y: h * 0.83),
            control2: CGPoint(x: w * 0.85, y: h * 0.71)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.96, y: h * 0.66),
            control1: CGPoint(x: w * 0.875, y: h * 0.67),
            control2: CGPoint(x: w * 0.94, y: h * 0.76)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.88, y: h * 0.435),
            control1: CGPoint(x: w * 0.99, y: h * 0.55),
            control2: CGPoint(x: w * 0.91, y: h * 0.49)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.025),
            control1: CGPoint(x: w * 0.875, y: h * 0.165),
            control2: CGPoint(x: w * 0.75, y: h * 0.02)
        )

        path.closeSubpath()
        return path
    }
}

private struct GhostInnerArmShade: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.19, y: h * 0.59))
        path.addCurve(
            to: CGPoint(x: w * 0.37, y: h * 0.51),
            control1: CGPoint(x: w * 0.27, y: h * 0.58),
            control2: CGPoint(x: w * 0.33, y: h * 0.54)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.30, y: h * 0.72),
            control1: CGPoint(x: w * 0.35, y: h * 0.62),
            control2: CGPoint(x: w * 0.34, y: h * 0.68)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.73),
            control1: CGPoint(x: w * 0.24, y: h * 0.76),
            control2: CGPoint(x: w * 0.18, y: h * 0.76)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.19, y: h * 0.59),
            control1: CGPoint(x: w * 0.11, y: h * 0.68),
            control2: CGPoint(x: w * 0.13, y: h * 0.63)
        )

        path.closeSubpath()
        return path
    }
}

private struct CenterGhostEmblem: View {
    var size: CGFloat = 104
    var state: GhostOrbState = .idle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var float = false
    @State private var pulse = false
    @State private var orbit = false

    var body: some View {
        ZStack {
            orbGlow

            if state == .usingTools || state == .writingFile {
                orbitDots
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.055),
                            orbColor.opacity(0.20),
                            GhostColors.deepIndigo.opacity(0.12),
                            Color.black.opacity(0.18)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: size * 0.62
                    )
                )
                .shadow(color: orbColor.opacity(shadowOpacity), radius: shadowRadius, y: 8)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            orbColor.opacity(0.42),
                            Color.white.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: state == .idle ? 1.3 : 1.8
                )

            Circle()
                .stroke(orbColor.opacity(ringOpacity), lineWidth: 2)
                .scaleEffect(pulse ? 1.18 : 0.92)
                .opacity(pulse ? 0.05 : 0.40)

            GhostMascotView(
                mascotSize: size * 0.78,
                isLarge: true
            )
            .offset(y: size * 0.015 + (float ? -6 : 6))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 3.2).repeatForever(autoreverses: true),
                value: float
            )
        }
        .frame(width: size, height: size)
        .onAppear {
            float = true

            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                pulse = true
            }

            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                orbit = true
            }
        }
        .onChange(of: state) { _, _ in
            guard !reduceMotion else { return }

            pulse = false
            orbit = false

            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                    pulse = true
                }

                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    orbit = true
                }
            }
        }
        .accessibilityLabel("Ghost emblem")
    }

    private var orbGlow: some View {
        Circle()
            .fill(orbColor.opacity(0.14))
            .frame(width: size * 1.35, height: size * 1.35)
            .blur(radius: 22)
            .scaleEffect(pulse ? 1.05 : 0.94)
            .opacity(state == .idle ? 0.45 : 0.85)
    }

    private var orbitDots: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .fill(orbColor.opacity(0.85))
                    .frame(width: size * 0.055, height: size * 0.055)
                    .offset(y: -size * 0.58)
                    .rotationEffect(.degrees(Double(index) * 120 + (orbit ? 360 : 0)))
            }
        }
        .frame(width: size, height: size)
        .animation(
            reduceMotion ? nil : .linear(duration: 2.4).repeatForever(autoreverses: false),
            value: orbit
        )
    }

    private var orbColor: Color {
        switch state {
        case .idle:
            return GhostColors.royalViolet
        case .thinking:
            return GhostColors.royalViolet
        case .usingTools:
            return Color(red: 0.62, green: 0.58, blue: 1.0)
        case .writingFile:
            return Color(red: 0.70, green: 0.82, blue: 1.0)
        case .success:
            return .green.opacity(0.85)
        case .error:
            return .red.opacity(0.82)
        }
    }

    private var ringOpacity: Double {
        switch state {
        case .idle:
            return 0.18
        case .thinking:
            return 0.38
        case .usingTools:
            return 0.46
        case .writingFile:
            return 0.50
        case .success:
            return 0.34
        case .error:
            return 0.42
        }
    }

    private var shadowOpacity: Double {
        switch state {
        case .idle:
            return 0.26
        case .thinking:
            return 0.36
        case .usingTools:
            return 0.42
        case .writingFile:
            return 0.48
        case .success:
            return 0.32
        case .error:
            return 0.34
        }
    }

    private var shadowRadius: CGFloat {
        switch state {
        case .idle:
            return 28
        case .thinking:
            return 34
        case .usingTools:
            return 38
        case .writingFile:
            return 42
        case .success:
            return 32
        case .error:
            return 34
        }
    }

    private var pulseDuration: Double {
        switch state {
        case .idle:
            return 3.2
        case .thinking:
            return 1.7
        case .usingTools:
            return 1.25
        case .writingFile:
            return 1.0
        case .success:
            return 2.4
        case .error:
            return 1.4
        }
    }
}

// MARK: - Compact Telemetry Strip

private struct CompactTelemetryStrip: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        let snap = store.telemetrySnapshot

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                StatusIndicator(status: snap.status)
                compactChip("Presence", store.presenceState.title)
                compactChip("Route", store.routingShortLine, help: store.routingExplanation)
                compactChip("Model", store.modelDisplayName)
                compactChip("Effort", snap.effortTitle)
                compactChip("Approval", snap.approvalMode)
                compactChip("Context", "↑\(snap.estimatedPromptTokens) ↓\(snap.estimatedResponseTokens)")
                ForEach(store.activeContextChips) { chip in
                    compactChip(chip.title, chip.detail, isActive: chip.isActive)
                }
                compactChip("Events", "\(snap.activityEventCount)")
                compactChip("RAG", "\(store.ragDocumentCount) docs", isActive: store.ragDocumentCount > 0)
            }
            .padding(.horizontal, GhostSpacing.wide)
            .padding(.vertical, 6)
        }
        .background(GhostColors.barFill)
        .background(.ultraThinMaterial.opacity(0.15))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.04))
                .frame(height: 1)
        }
    }

    private func compactChip(_ label: String, _ value: String, isActive: Bool = true, help: String? = nil) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .default))
                .foregroundStyle(GhostColors.faintPlatinum)
            Text(value)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(GhostColors.mutedPlatinum)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(GhostColors.glassFill.opacity(0.62))
        )
        .opacity(isActive ? 1.0 : 0.45)
        .help(help ?? "\(label): \(value)")
    }
}

private struct StatusIndicator: View {
    let status: GhostRunStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusLabel)
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundStyle(statusColor)
        }
        .padding(.trailing, 10)
    }

    private var statusColor: Color {
        switch status {
        case .idle: GhostColors.mutedPlatinum
        case .running: GhostColors.royalViolet
        case .completed: .green.opacity(0.7)
        case .failed: .red.opacity(0.7)
        case .stopped: .yellow.opacity(0.7)
        }
    }

    private var statusLabel: String {
        switch status {
        case .idle: "Idle"
        case .running: "Running"
        case .completed: "Complete"
        case .failed: "Failed"
        case .stopped: "Stopped"
        }
    }
}

private struct TelemetryItem: View {
    let label: String
    let value: String
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .default))
                .foregroundStyle(GhostColors.faintPlatinum)
                .textCase(.uppercase)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(GhostColors.mutedPlatinum)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 6)
    }
}

private struct TelemetrySeparator: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(width: 1, height: 14)
    }
}

// MARK: - Telemetry Drawer

private struct TelemetryDrawerView: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        let snap = store.telemetrySnapshot

        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(GhostColors.royalViolet.opacity(0.6))

                Text("Telemetry")
                    .font(.system(size: 11, weight: .semibold, design: .default))
                    .foregroundStyle(GhostColors.mutedPlatinum)

                Spacer()

                Button {
                    copyTelemetry(snap)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(GhostColors.faintPlatinum)
                        .frame(width: 28, height: 28)
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(GhostColors.glassFill)
                        )
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .help("Copy Telemetry")

                Button {
                    store.clearActivity()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(GhostColors.faintPlatinum)
                        .frame(width: 28, height: 28)
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(GhostColors.glassFill)
                        )
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .help("Clear Activity")
            }
            .padding(.horizontal, GhostSpacing.wide)
            .padding(.vertical, 8)

            Rectangle()
                .fill(.white.opacity(0.04))
                .frame(height: 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GhostSpacing.standard) {
                    TelemetryMetricCard(
                        icon: "clock",
                        label: "Runtime",
                        value: snap.activeRunStartedAt != nil ? snap.formattedElapsed : snap.formattedLastDuration
                    )
                    TelemetryMetricCard(
                        icon: "cpu",
                        label: "Model",
                        value: "\(snap.providerTitle) · \(snap.model)"
                    )
                    TelemetryMetricCard(
                        icon: "text.alignleft",
                        label: "Tokens est.",
                        value: "↑\(snap.estimatedPromptTokens) ↓\(snap.estimatedResponseTokens)"
                    )
                    TelemetryMetricCard(
                        icon: "list.bullet",
                        label: "Events",
                        value: "\(snap.activityEventCount)"
                    )
                    TelemetryMetricCard(
                        icon: "tray",
                        label: "Queue",
                        value: "\(snap.queuedTaskCount)"
                    )
                    TelemetryMetricCard(
                        icon: "folder",
                        label: "Directory",
                        value: snap.workingDirectory
                    )
                    if let pid = snap.processIdentifier {
                        TelemetryMetricCard(
                            icon: "terminal",
                            label: "PID",
                            value: "\(pid)"
                        )
                    }
                    TelemetryMetricCard(
                        icon: "doc.on.clipboard",
                        label: "Clipboard",
                        value: snap.includeClipboard ? "On" : "Off"
                    )
                    TelemetryMetricCard(
                        icon: "mic",
                        label: "Dictation",
                        value: snap.isDictating ? "Active" : "Off"
                    )
                }
                .padding(.horizontal, GhostSpacing.wide)
                .padding(.vertical, GhostSpacing.relaxed)
            }

            Rectangle()
                .fill(.white.opacity(0.04))
                .frame(height: 1)

            HStack(spacing: 8) {
                Label("Activity Log", systemImage: "terminal")
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .foregroundStyle(GhostColors.faintPlatinum)
                Spacer()
            }
            .padding(.horizontal, GhostSpacing.wide)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(store.activityEntries) { entry in
                            ActivityRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(.horizontal, GhostSpacing.wide)
                    .padding(.bottom, 8)
                }
                .frame(height: 110)
                .onChange(of: store.activityEntries) { _, entries in
                    guard let last = entries.last else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .background(GhostColors.drawerFill)
        .background(.ultraThinMaterial.opacity(0.2))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.05))
                .frame(height: 1)
        }
    }

    private func copyTelemetry(_ snap: GhostTelemetrySnapshot) {
        var lines: [String] = []
        lines.append("Ghost Telemetry")
        lines.append("Status: \(snap.status.rawValue)")
        lines.append("Provider: \(snap.providerTitle)")
        lines.append("Model: \(snap.model)")
        lines.append("Effort: \(snap.effortTitle)")
        lines.append("Approval: \(snap.approvalMode)")
        lines.append("Directory: \(snap.workingDirectory)")
        if snap.activeRunStartedAt != nil {
            lines.append("Elapsed: \(snap.formattedElapsed)")
        } else if snap.lastRunDuration != nil {
            lines.append("Last Duration: \(snap.formattedLastDuration)")
        }
        if let exitStatus = snap.exitStatus {
            lines.append("Exit Status: \(exitStatus)")
        }
        lines.append("Est. Prompt Tokens: \(snap.estimatedPromptTokens)")
        lines.append("Est. Response Tokens: \(snap.estimatedResponseTokens)")
        lines.append("Activity Events: \(snap.activityEventCount)")
        lines.append("Queued Tasks: \(snap.queuedTaskCount)")
        lines.append("Clipboard: \(snap.includeClipboard ? "Enabled" : "Disabled")")
        lines.append("Dictation: \(snap.isDictating ? "Active" : "Off")")
        if let pid = snap.processIdentifier {
            lines.append("Process PID: \(pid)")
        }
        lines.append("Run Status: \(snap.lastRunStartedAt != nil ? "Last run at \(snap.lastRunStartedAt!.formatted())" : "—")")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}

private struct TelemetryMetricCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(GhostColors.royalViolet.opacity(0.5))
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .default))
                    .foregroundStyle(GhostColors.faintPlatinum)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(GhostColors.platinum)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: 180, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let entry: GhostActivityEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer(minLength: 4)
                    Text(entry.date, style: .time)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(GhostColors.faintPlatinum)
                }

                if !entry.detail.isEmpty {
                    Text(trimmedDetail)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var trimmedDetail: String {
        if entry.detail.count <= 700 { return entry.detail }
        return String(entry.detail.prefix(700)) + "\n..."
    }

    private var color: Color {
        switch entry.kind {
        case .info: .white.opacity(0.3)
        case .command: .blue.opacity(0.6)
        case .output: .purple.opacity(0.5)
        case .error: .red.opacity(0.6)
        case .success: .green.opacity(0.5)
        }
    }
}

// MARK: - Cosmic Background

private struct CosmicBackground: View {
    @Environment(\.colorScheme) private var scheme
    @State private var starCache: [Star] = []

    struct Star: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                GhostColors.deepBlack

                RadialGradient(
                    colors: scheme == .dark
                        ? [GhostColors.voidColor.opacity(0.9), Color.black.opacity(0.7), Color.black]
                        : [Color.white.opacity(0.96), GhostColors.voidColor.opacity(0.30), GhostColors.voidColor.opacity(0.42)],
                    center: .center, startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * (scheme == .dark ? 0.7 : 0.85)
                )

                RadialGradient(
                    colors: [
                        GhostColors.royalViolet.opacity(scheme == .dark ? 0.08 : 0.12),
                        GhostColors.voidColor.opacity(0.03),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.9
                )

                Canvas { context, size in
                    for star in starCache {
                        let rect = CGRect(
                            x: star.x * size.width,
                            y: star.y * size.height,
                            width: star.size,
                            height: star.size
                        )
                        let color: Color = scheme == .dark
                            ? (star.opacity > 0.5 ? GhostColors.platinum : Color.white.opacity(star.opacity))
                            : GhostColors.royalViolet.opacity(star.opacity * 0.35)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(color)
            )
        }
    }

            }
        }
        .onAppear {
            if starCache.isEmpty {
                starCache = (0..<100).map { i in
                    let opacity = Double.random(in: 0.08...0.55)
                    return Star(
                        id: i,
                        x: .random(in: 0...1),
                        y: .random(in: 0...1),
                        size: .random(in: 0.5...2.2),
                        opacity: opacity
                    )
                }
            }
        }
    }
}

// MARK: - Message Cards

private struct FloatingMessageCard: View {
    let message: GhostMessage
    @Bindable var store: GhostConversationStore
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .ghost {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [GhostColors.royalViolet.opacity(0.3), .indigo.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 1.5)
                    .padding(.trailing, GhostSpacing.relaxed)
            }

            VStack(alignment: .leading, spacing: 6) {
                if message.role != .system {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(roleColor.opacity(0.5))
                            .frame(width: 6, height: 6)

                        Text(message.role.rawValue)
                            .font(.system(size: 10, weight: .medium, design: .default))
                            .foregroundStyle(GhostColors.faintPlatinum)
                            .textCase(.uppercase)

                        Spacer(minLength: 4)

                        if isHovering {
                            messageActions
                                .transition(.opacity)
                        }
                    }
                }

                MessageBodyText(message: message)
                    .textSelection(.enabled)

                if message.role == .ghost {
                    Button {
                        store.copyMessage(id: message.id)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(GhostColors.glassFill.opacity(0.7))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Copy answer")
                    .padding(.top, 2)
                }

                if message.role == .ghost, let meta = message.runMetadata {
                    RunMetadataBadge(meta: meta)
                        .padding(.top, 4)
                }
            }
            .padding(message.role == .ghost ? 14 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                message.role == .ghost
                    ? AnyShapeStyle(GhostColors.bubbleFill)
                    : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: GhostRadii.card, style: .continuous)
            )
            .overlay {
                if message.role == .ghost {
                    RoundedRectangle(cornerRadius: GhostRadii.card, style: .continuous)
                        .stroke(GhostColors.royalViolet.opacity(0.06), lineWidth: 1)
                }
            }
            .shadow(color: message.role == .ghost ? GhostShadow.card : .clear, radius: 16, y: 6)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
        }
    }

    private var messageActions: some View {
        HStack(spacing: 2) {
            actionButton(icon: "doc.on.doc", help: "Copy") {
                store.copyMessage(id: message.id)
            }
            if message.role == .ghost {
                actionButton(icon: "arrow.clockwise", help: "Regenerate") {
                    store.regenerateLastResponse()
                }
            }
            actionButton(icon: "trash", help: "Delete") {
                store.deleteMessage(id: message.id)
            }
        }
    }

    private func actionButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(GhostColors.mutedPlatinum)
                .frame(width: 22, height: 22)
                .background(
                    Circle().fill(GhostColors.glassFill)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var roleColor: Color {
        switch message.role {
        case .user: .blue
        case .ghost: .purple
        case .system: .secondary
        }
    }
}

private struct RunMetadataBadge: View {
    let meta: GhostRunMetadata

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9))
            Text(meta.providerTitle + " · " + meta.effortTitle + " · " + meta.approvalMode)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))

            if let finishedAt = meta.finishedAt {
                Text("•")
                    .foregroundStyle(GhostColors.faintPlatinum)
                let duration = finishedAt.timeIntervalSince(meta.startedAt)
                Text(GhostTelemetrySnapshot.formatDuration(duration))
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
            }
        }
        .foregroundStyle(GhostColors.mutedPlatinum)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(GhostColors.royalViolet.opacity(0.1), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct MessageBodyText: View {
    let message: GhostMessage

    var body: some View {
        Group {
            switch message.role {
            case .ghost:
                MarkdownMessageText(text: message.text)
            case .user:
                Text(message.text)
                    .font(GhostFonts.hkGrotesk(size: 15.5))
                    .lineSpacing(4)
                    .foregroundStyle(GhostColors.platinum)
            case .system:
                Text(message.text)
                    .font(.callout)
                    .lineSpacing(3)
                    .foregroundStyle(GhostColors.mutedPlatinum)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GhostTaskTimelineCard: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 0.35)) { context in
            content(timeline: store.taskTimeline, now: context.date)
        }
    }

    private func content(timeline: GhostTaskTimeline, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            header(timeline: timeline, now: now)
            progressBar(timeline: timeline, now: now)

            if !timeline.isFinished {
                LiveWorkingStrip(timeline: timeline, now: now)
            }

            if timeline.isWaitingForGhostPlan && timeline.steps.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Creating todo plan")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(GhostColors.platinum)

                    Spacer()
                }
            }

            if !timeline.steps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(timeline.steps) { step in
                        GhostTaskStepRow(step: step)
                    }
                }
            }

            if let summary = timeline.summary, timeline.isFinished {
                resultFooter(
                    icon: "checkmark.seal.fill",
                    title: "Done",
                    text: summary,
                    color: .green.opacity(0.75)
                )
            }

            if let error = timeline.error {
                resultFooter(
                    icon: "exclamationmark.triangle.fill",
                    title: "Needs attention",
                    text: error,
                    color: .red.opacity(0.75)
                )
            }
        }
        .padding(16)
        .ghostCard()
        .overlay(
            RoundedRectangle(cornerRadius: GhostRadii.card, style: .continuous)
                .strokeBorder(GhostColors.royalViolet.opacity(0.12), lineWidth: 1)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .id(timeline.steps.map { "\($0.id)-\($0.state.rawValue)-\($0.detail)" }.joined(separator: "|") + "\(timeline.isFinished)-\(timeline.currentLine)")
    }

    private func header(timeline: GhostTaskTimeline, now: Date) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(GhostColors.royalViolet.opacity(0.13))
                    .frame(width: 32, height: 32)

                Image(systemName: timeline.isFinished ? "checkmark.sparkles" : "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GhostColors.royalViolet)
                    .symbolEffect(.pulse, isActive: !timeline.isFinished && timeline.error == nil)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(timeline.title)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(GhostColors.platinum)

                Text(timeline.route)
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(GhostColors.mutedPlatinum)

                HStack(spacing: 6) {
                    Image(systemName: statusIcon(for: timeline))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(statusColor(for: timeline))

                    Text(timeline.currentLine)
                        .font(.system(size: 11, design: .default))
                        .foregroundStyle(GhostColors.faintPlatinum)
                        .lineLimit(1)

                    if !timeline.isFinished {
                        Text(elapsedText(for: timeline, now: now))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(GhostColors.faintPlatinum)
                    }
                }
            }

            Spacer()

            Text(timeline.progressText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(GhostColors.royalViolet.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(GhostColors.royalViolet.opacity(0.10))
                )
        }
    }

    private func progressBar(timeline: GhostTaskTimeline, now: Date) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(GhostColors.faintPlatinum.opacity(0.18))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [GhostColors.royalViolet.opacity(0.88), .green.opacity(0.70)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: progressWidth(for: timeline, now: now, availableWidth: proxy.size.width))
                    .animation(.easeInOut(duration: 0.25), value: timeline.progressFraction)
                    .animation(.linear(duration: 0.35), value: now)
            }
        }
        .frame(height: 4)
        .opacity(timeline.totalCount > 0 ? 1 : 0.45)
        .accessibilityLabel(Text("Task progress \(timeline.progressText)"))
    }

    private func progressWidth(for timeline: GhostTaskTimeline, now: Date, availableWidth: CGFloat) -> CGFloat {
        guard availableWidth > 0 else { return 0 }

        if timeline.totalCount > 0 {
            return max(8, availableWidth * timeline.progressFraction)
        }

        guard !timeline.isFinished else { return availableWidth }

        let phase = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2
        return max(24, availableWidth * (0.12 + 0.28 * phase))
    }

    private func statusIcon(for timeline: GhostTaskTimeline) -> String {
        if timeline.error != nil {
            return "exclamationmark.triangle.fill"
        }

        if timeline.isFinished {
            return "checkmark.circle.fill"
        }

        if timeline.isWaitingForGhostPlan {
            return "wand.and.stars"
        }

        return "bolt.fill"
    }

    private func statusColor(for timeline: GhostTaskTimeline) -> Color {
        if timeline.error != nil {
            return .red.opacity(0.78)
        }

        if timeline.isFinished {
            return .green.opacity(0.75)
        }

        if timeline.isWaitingForGhostPlan {
            return GhostColors.champagne
        }

        return GhostColors.royalViolet
    }

    private func elapsedText(for timeline: GhostTaskTimeline, now: Date) -> String {
        guard let startedAt = timeline.startedAt else { return "" }
        let seconds = max(0, Int(now.timeIntervalSince(startedAt)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func resultFooter(
        icon: String,
        title: String,
        text: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(GhostColors.platinum)

                Text(text)
                    .font(.system(size: 11, design: .default))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }
}

private struct LiveWorkingStrip: View {
    let timeline: GhostTaskTimeline
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(GhostColors.royalViolet.opacity(0.16), lineWidth: 3)
                    .frame(width: 22, height: 22)

                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(GhostColors.royalViolet.opacity(0.80), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 22, height: 22)
                    .rotationEffect(.degrees(now.timeIntervalSinceReferenceDate * (360.0 / 1.1)))
                    .animation(.linear(duration: 0.35), value: now)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Working live")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(GhostColors.platinum)

                Text(statusText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(GhostColors.royalViolet.opacity(0.06))
        )
    }

    private var statusText: String {
        if timeline.isWaitingForGhostPlan {
            return "Creating a plan before touching files or tools"
        }

        if let active = timeline.activeStep {
            return active.detail.isEmpty ? active.title : active.detail
        }

        return timeline.currentLine
    }
}

private struct GhostTaskStepRow: View {
    let step: GhostTaskStep

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: step.state.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .symbolEffect(.pulse, isActive: step.state == .running)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(step.title)
                        .font(.system(size: 12.5, weight: step.state == .running ? .semibold : .medium, design: .default))
                        .foregroundStyle(titleColor)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(statusText)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(color)
                        .textCase(.uppercase)
                }

                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.system(size: 10.5, design: .default))
                        .foregroundStyle(GhostColors.faintPlatinum)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .opacity(step.state == .pending ? 0.58 : 1.0)
    }

    private var color: Color {
        switch step.state {
        case .pending:
            return GhostColors.faintPlatinum
        case .running:
            return GhostColors.royalViolet
        case .completed:
            return .green.opacity(0.75)
        case .failed:
            return .red.opacity(0.78)
        }
    }

    private var titleColor: Color {
        switch step.state {
        case .pending:
            return GhostColors.mutedPlatinum
        case .running:
            return GhostColors.platinum
        case .completed:
            return GhostColors.mutedPlatinum
        case .failed:
            return .red.opacity(0.82)
        }
    }

    private var statusText: String {
        switch step.state {
        case .pending:
            return "queued"
        case .running:
            return "running"
        case .completed:
            return "done"
        case .failed:
            return "failed"
        }
    }
}

private struct MiniQuickMessageRow: View {
    let role: String
    let text: String
    let systemImage: String
    let isUser: Bool
    var isStreaming: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isUser ? GhostColors.champagne : GhostColors.royalViolet)
                .frame(width: 14)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(role)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isUser ? GhostColors.champagne : GhostColors.platinum)

                    if isStreaming {
                        Text("typing...")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(GhostColors.royalViolet.opacity(0.75))
                    }
                }

                if isUser {
                    Text(text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(GhostColors.platinum)
                        .lineLimit(4)
                } else {
                    MarkdownMessageText(text: text)
                        .lineLimit(12)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            Group {
                if !isUser {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                }
            }
        )
    }
}

private struct MiniThinkingStatusRow: View {
    let statusLine: String

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 0.45)) { context in
            HStack(alignment: .center, spacing: 9) {
                ProgressView()
                    .controlSize(.small)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Ghost received your request")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(GhostColors.platinum)

                        Text(liveDots(now: context.date))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(GhostColors.royalViolet.opacity(0.78))
                    }

                    Text(statusLine.isEmpty ? "Thinking" : statusLine)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(GhostColors.royalViolet.opacity(0.07))
            )
        }
    }

    private func liveDots(now: Date) -> String {
        let count = Int(now.timeIntervalSinceReferenceDate * 2) % 4
        return String(repeating: ".", count: max(1, count))
    }
}

private struct MiniTaskProgressStrip: View {
    let timeline: GhostTaskTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: timeline.isFinished ? "checkmark.circle.fill" : "list.bullet.clipboard")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(timeline.isFinished ? .green.opacity(0.75) : GhostColors.royalViolet)

                Text(timeline.progressText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(GhostColors.platinum)

                Text(timeline.currentLine)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            ProgressView(value: max(0.04, timeline.progressFraction), total: 1.0)
                .controlSize(.small)

            ForEach(timeline.steps.prefix(3)) { step in
                HStack(spacing: 6) {
                    Image(systemName: step.state.systemImage)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(color(for: step.state))
                        .frame(width: 12)

                    Text(step.title)
                        .font(.system(size: 9.5, weight: step.state == .running ? .semibold : .medium))
                        .foregroundStyle(step.state == .running ? GhostColors.platinum : GhostColors.mutedPlatinum)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .opacity(step.state == .pending ? 0.55 : 1.0)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.028))
        )
    }

    private func color(for state: GhostTaskStepState) -> Color {
        switch state {
        case .pending:
            return GhostColors.faintPlatinum
        case .running:
            return GhostColors.royalViolet
        case .completed:
            return .green.opacity(0.75)
        case .failed:
            return .red.opacity(0.78)
        }
    }
}

private struct WorkingCard: View {
    let statusLine: String

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 0.5)) { context in
            HStack(spacing: 12) {
                ThinkingDots()

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Ghost is working")
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundStyle(GhostColors.platinum)

                        Text(liveSuffix(now: context.date))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(GhostColors.royalViolet.opacity(0.75))
                    }

                    Text(statusLine)
                        .font(.system(size: 11, design: .default))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()
            }
            .padding(12)
            .ghostGlass(cornerRadius: 12)
        }
    }

    private func liveSuffix(now: Date) -> String {
        let count = Int(now.timeIntervalSinceReferenceDate * 2) % 4
        return String(repeating: ".", count: count == 0 ? 1 : count)
    }
}

private struct ThinkingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(GhostColors.royalViolet.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .opacity(reduceMotion ? 0.7 : (0.35 + 0.65 * abs(sin(phase + Double(i) * 0.6))))
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = .pi * 2 }
        }
        .accessibilityLabel(Text("Working"))
    }
}

private struct CodeBlockView: View {
    let code: String
    @State private var copied = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(GhostFonts.mono(size: 12))
                    .foregroundStyle(GhostColors.platinum)
                    .textSelection(.enabled)
                    .padding(GhostSpacing.wide)
            }
            .background(
                RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous)
                    .strokeBorder(GhostColors.glassBorder, lineWidth: 1)
            )

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(copied ? .green.opacity(0.8) : GhostColors.mutedPlatinum)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel(Text("Copy code"))
        }
    }
}

// MARK: - Composer

private struct ComposerTextView: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onPasteImage: (NSImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.appearance = NSAppearance(named: .darkAqua)

        let textView = GhostComposerTextView()
        textView.onPasteImage = { image in
            context.coordinator.parent.onPasteImage(image)
        }
        textView.delegate = context.coordinator
        textView.appearance = NSAppearance(named: .darkAqua)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 6)
        textView.minSize = NSSize(width: 0, height: 32)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.forceReadableTextStyle()

        let placeholderLabel = NSTextField(labelWithString: placeholder)
        placeholderLabel.font = .ghostHKGrotesk(size: 16, weight: .regular)
        placeholderLabel.textColor = {
            let light = NSColor(red: 0.13, green: 0.11, blue: 0.20, alpha: 0.35)
            let dark = NSColor.white.withAlphaComponent(0.22)
            return NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            }
        }()
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 2),
            placeholderLabel.centerYAnchor.constraint(equalTo: textView.centerYAnchor)
        ])

        context.coordinator.textView = textView
        context.coordinator.placeholderLabel = placeholderLabel

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? GhostComposerTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.forceReadableTextStyle()
        context.coordinator.updatePlaceholder()
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: ComposerTextView
        weak var textView: GhostComposerTextView?
        weak var placeholderLabel: NSTextField?

        init(_ parent: ComposerTextView) {
            self.parent = parent
        }

        @MainActor func updatePlaceholder() {
            let isEmpty = textView?.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
            placeholderLabel?.isHidden = !isEmpty
        }

        func textDidChange(_ notification: Notification) {
            parent.text = textView?.string ?? ""
            updatePlaceholder()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    textView.insertText("\n", replacementRange: textView.selectedRange())
                    return true
                }
                let trimmed = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    parent.onSubmit()
                }
                return true
            }
            return false
        }
    }
}

private final class GhostComposerTextView: NSTextView {
    var onPasteImage: ((NSImage) -> Void)?

    private static let composerColor: NSColor = {
        let light = NSColor(red: 0.13, green: 0.11, blue: 0.20, alpha: 1.0)
        let dark = NSColor(calibratedWhite: 0.94, alpha: 1.0)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }()

    func forceReadableTextStyle() {
        appearance = NSApp.effectiveAppearance
        backgroundColor = .clear
        drawsBackground = false
        isRichText = false
        importsGraphics = false
        isEditable = true
        isSelectable = true
        allowsUndo = true
        textColor = Self.composerColor
        insertionPointColor = NSColor.systemPurple
        font = .ghostHKGrotesk(size: 16, weight: .regular)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2

        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: Self.composerColor,
            .font: NSFont.ghostHKGrotesk(size: 16, weight: .regular),
            .paragraphStyle: paragraph
        ]

        typingAttributes = attrs

        if let storage = textStorage {
            storage.setAttributes(attrs, range: NSRange(location: 0, length: storage.length))
        }

        needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        forceReadableTextStyle()
        return result
    }

    override func didChangeText() {
        super.didChangeText()
        forceReadableTextStyle()
    }

    override func paste(_ sender: Any?) {
        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            onPasteImage?(image)
            forceReadableTextStyle()
            return
        }

        super.paste(sender)
        forceReadableTextStyle()
    }
}

// MARK: - Selectors and Popovers

private struct SelectorPill<Popover: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let popover: () -> Popover
    @State private var isPresented = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(GhostColors.faintPlatinum)
                    .frame(width: 16, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .foregroundStyle(GhostColors.platinum)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .truncationMode(.tail)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .regular, design: .default))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .truncationMode(.tail)
                }
                .layoutPriority(2)

                Spacer(minLength: 4)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(GhostColors.faintPlatinum)
                    .frame(width: 8, alignment: .trailing)
            }
            .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: GhostRadii.pill, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: GhostRadii.pill, style: .continuous)
                    .fill(isPresented ? GhostColors.glassActiveFill : GhostColors.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GhostRadii.pill, style: .continuous)
                    .stroke(isPresented ? GhostColors.glassActiveBorder : GhostColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle(reduceMotion: reduceMotion))
        .contentShape(RoundedRectangle(cornerRadius: GhostRadii.pill, style: .continuous))
        .frame(maxWidth: .infinity)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            popover()
        }
    }
}

private struct CosmicPopover<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(8)
        .frame(minWidth: 200)
        .background(GhostColors.popoverFill)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: GhostRadii.card - 2, style: .continuous)
                .stroke(GhostColors.glassBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: GhostRadii.card - 2, style: .continuous))
        .shadow(color: GhostShadow.card, radius: 20, y: 8)
    }
}

private struct ProviderPopoverContent: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PopoverLabel("PROVIDER")
            VStack(spacing: 1) {
                ForEach(GhostProvider.allCases) { provider in
                    PopoverRow(
                        title: provider.title,
                        subtitle: provider.subtitle,
                        isSelected: store.selectedProvider == provider
                    ) {
                        store.selectProviderManually(provider)
                    }
                }
            }

            if store.selectedProvider == .deepSeek {
                Divider().overlay(.white.opacity(0.08)).padding(.vertical, 4)
                PopoverLabel("MODEL")
                VStack(spacing: 1) {
                    ForEach(DeepSeekModel.allCases) { model in
                        PopoverRow(
                            title: model.title,
                            subtitle: nil,
                            isSelected: store.selectedDeepSeekModel == model.rawValue
                        ) {
                            store.selectedDeepSeekModel = model.rawValue
                        }
                    }
                }
            }

            if store.selectedProvider == .lmStudio {
                Divider().overlay(.white.opacity(0.08)).padding(.vertical, 4)
                PopoverLabel("MODEL")
                VStack(spacing: 1) {
                    ForEach(store.localModels) { model in
                        PopoverRow(
                            title: model.id,
                            subtitle: nil,
                            isSelected: store.selectedLocalModel == model.id
                        ) {
                            store.selectedLocalModel = model.id
                        }
                    }
                    if store.localModels.isEmpty {
                        PopoverRow(title: store.selectedLocalModel, subtitle: nil, isSelected: true) { }
                    }
                }
                Button("Refresh Models") { store.refreshLocalModels() }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(GhostColors.faintPlatinum)
                    .padding(.top, 4)
            }

            if store.selectedProvider == .ollama {
                Divider().overlay(.white.opacity(0.08)).padding(.vertical, 4)
                PopoverLabel("OLLAMA MODEL")
                VStack(spacing: 1) {
                    ForEach(store.ollamaModels) { model in
                        PopoverRow(
                            title: model.id,
                            subtitle: nil,
                            isSelected: store.selectedOllamaModel == model.id
                        ) {
                            store.selectedOllamaModel = model.id
                        }
                    }

                    if store.ollamaModels.isEmpty {
                        PopoverRow(title: store.selectedOllamaModel, subtitle: nil, isSelected: true) { }
                    }
                }

                Button("Refresh Ollama Models") {
                    store.refreshOllamaModels()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(GhostColors.faintPlatinum)
                .padding(.top, 4)
            }

            if store.selectedProvider == .openCodeGo {
                Divider().overlay(.white.opacity(0.08)).padding(.vertical, 4)
                PopoverLabel("OPENCODE GO MODEL")
                VStack(spacing: 1) {
                    ForEach(store.openCodeGoModels) { model in
                        PopoverRow(
                            title: model.id,
                            subtitle: model.ownedBy,
                            isSelected: store.selectedOpenCodeGoModel == model.id
                        ) {
                            store.selectedOpenCodeGoModel = model.id
                        }
                    }

                    if store.openCodeGoModels.isEmpty {
                        PopoverRow(title: store.selectedOpenCodeGoModel, subtitle: nil, isSelected: true) { }
                    }
                }

                Button("Refresh OpenCode Go Models") {
                    store.refreshOpenCodeGoModels()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(GhostColors.faintPlatinum)
                .padding(.top, 4)
            }
        }
    }
}

private struct EffortPopoverContent: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PopoverLabel("EFFORT")
            VStack(spacing: 1) {
                ForEach(EffortMode.allCases) { mode in
                    PopoverRow(
                        title: mode.title(for: store.selectedProvider),
                        subtitle: effortSubtitle(for: mode),
                        isSelected: store.effortMode == mode
                    ) {
                        store.effortMode = mode
                    }
                }
            }
            Divider().overlay(.white.opacity(0.08)).padding(.vertical, 4)
            PopoverLabel("APPROVAL")
            VStack(spacing: 1) {
                ForEach(ApprovalMode.allCases) { mode in
                    PopoverRow(
                        title: mode.title,
                        subtitle: mode == .yolo ? "Runs actions with less confirmation" : nil,
                        isSelected: store.approvalMode == mode
                    ) {
                        store.approvalMode = mode
                    }
                }
            }
        }
    }

    private func effortSubtitle(for mode: EffortMode) -> String {
        guard store.executionEngine == .directAPI else {
            return mode.promptInstruction
        }
        switch mode {
        case .low:
            return "Fast direct response; searches for live prompts."
        case .medium:
            return "Balanced direct response with web context when useful."
        case .high:
            return "More careful direct response; no computer actions."
        case .max:
            return "Most thorough direct response; no computer actions."
        }
    }
}

private struct PopoverLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .default))
            .foregroundStyle(GhostColors.faintPlatinum)
            .padding(.horizontal, 8)
            .padding(.top, 2)
    }
}

private struct PopoverRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundStyle(isSelected ? GhostColors.platinum : GhostColors.mutedPlatinum)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10, design: .default))
                            .foregroundStyle(GhostColors.faintPlatinum)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(GhostColors.royalViolet.opacity(0.7))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: GhostRadii.mini, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: GhostRadii.mini, style: .continuous)
                    .fill(isSelected ? GhostColors.glassActiveFill : .clear)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: GhostRadii.mini, style: .continuous))
    }
}

// MARK: - Buttons

private struct GlassIconButton: View {
    let systemImage: String
    let help: String
    let isActive: Bool
    var foreground: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(RoundedRectangle(cornerRadius: GhostRadii.mini, style: .continuous))
                .foregroundStyle(foreground ?? (isActive ? GhostColors.platinum : GhostColors.mutedPlatinum))
                .background(
                    RoundedRectangle(cornerRadius: GhostRadii.mini, style: .continuous)
                        .fill(isActive ? GhostColors.glassActiveFill : GhostColors.glassFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: GhostRadii.mini, style: .continuous)
                        .stroke(isActive ? GhostColors.glassActiveBorder : .white.opacity(0), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: GhostRadii.mini, style: .continuous))
        .help(help)
        .accessibilityLabel(Text(help))
    }
}

private struct SendStopButton: View {
    let isSending: Bool
    let canSend: Bool
    let send: () -> Void
    let stop: () -> Void

    var body: some View {
        Button {
            isSending ? stop() : send()
        } label: {
            Image(systemName: isSending ? "stop.fill" : "arrow.up")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 32, height: 32)
                .contentShape(RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous))
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous))
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!isSending && !canSend)
        .opacity((isSending || canSend) ? 1 : 0.3)
        .help(isSending ? "Stop" : "Send")
    }

    private var foreground: Color {
        if isSending { return .white }
        return canSend ? .black : GhostColors.mutedPlatinum
    }

    private var background: Color {
        if isSending { return .red.opacity(0.8) }
        return canSend ? .white.opacity(0.9) : GhostColors.glassFill
    }
}

private struct EmptyChip: View {
    let text: String
    let action: () -> Void

    init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, design: .default))
                .foregroundStyle(GhostColors.mutedPlatinum)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(RoundedRectangle(cornerRadius: GhostRadii.pill, style: .continuous))
                .background(GhostColors.glassFill, in: RoundedRectangle(cornerRadius: GhostRadii.pill, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: GhostRadii.pill, style: .continuous)
                        .stroke(GhostColors.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(PressableButtonStyle())
        .contentShape(RoundedRectangle(cornerRadius: GhostRadii.pill, style: .continuous))
    }
}

private struct ComposerButton: View {
    let systemImage: String
    let help: String
    var isActive = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 32, height: 32)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .foregroundStyle(isActive ? GhostColors.platinum : GhostColors.mutedPlatinum)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? .red.opacity(0.3) : GhostColors.glassFill)
                )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .disabled(isDisabled)
        .help(help)
        .accessibilityLabel(Text(help))
    }
}

// MARK: - Onboarding

private struct GhostOnboardingPanelView: View {
    @Bindable var store: GhostConversationStore

    private let samples: [GhostOnboardingSample] = [
        GhostOnboardingSample(
            title: "Ask a quick question",
            subtitle: "Best for learning what Ghost can do.",
            prompt: "What can you help me do in Ghost?"
        ),
        GhostOnboardingSample(
            title: "Summarize clipboard",
            subtitle: "Uses copied text when clipboard context is enabled.",
            prompt: "Summarize what is currently on my clipboard."
        ),
        GhostOnboardingSample(
            title: "Explore this folder",
            subtitle: "Great for projects and local files.",
            prompt: "Explore my current working folder and explain what this project does."
        )
    ]

    private var steps: [GhostConversationStore.OnboardingStep] {
        GhostConversationStore.OnboardingStep.allCases
    }

    private var stepIndex: Int {
        steps.firstIndex(of: store.onboardingStep) ?? 0
    }

    private var isLastStep: Bool {
        stepIndex == steps.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ProgressView(value: Double(stepIndex + 1), total: Double(steps.count))
                .progressViewStyle(.linear)
                .tint(GhostColors.royalViolet.opacity(0.75))
                .padding(.horizontal, GhostSpacing.wide)
                .padding(.bottom, 10)

            HStack(spacing: 0) {
                sidebar

                Rectangle()
                    .fill(GhostColors.glassBorder)
                    .frame(width: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        stepContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                }
                .scrollIndicators(.never)
            }

            footer
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            GhostLogoMark(size: 34, showContainer: true, showAccentStar: true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Set up Ghost")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(GhostColors.platinum)

                Text("A fast first-run guide so you can connect, customize, and start using the app without guessing.")
                    .font(.system(size: 12))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .lineLimit(2)
            }

            Spacer()

            Button("Skip") {
                store.skipOnboarding()
            }
            .buttonStyle(.plain)
            .foregroundStyle(GhostColors.mutedPlatinum)
            .help("Skip onboarding")
        }
        .padding(.horizontal, GhostSpacing.wide)
        .padding(.top, GhostSpacing.generous)
        .padding(.bottom, 12)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(steps) { step in
                let index = steps.firstIndex(of: step) ?? 0

                GhostOnboardingStepRow(
                    step: step,
                    isSelected: step == store.onboardingStep,
                    isComplete: index < stepIndex
                )
            }

            Spacer()

            GhostOnboardingTip(
                icon: "command",
                title: "Fast access",
                text: "Use Option-Space to toggle Ghost from anywhere."
            )
        }
        .padding(16)
        .frame(width: 190)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch store.onboardingStep {
        case .welcome:
            welcomeStep
        case .connect:
            connectStep
        case .personalize:
            personalizeStep
        case .learn:
            learnStep
        case .rag:
            ragStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            GhostOnboardingHero(
                icon: "sparkles",
                title: "Ghost is your menu bar AI assistant.",
                subtitle: "Ask everyday questions, summarize clipboard text, inspect local projects, run agent tasks, and switch between simple chat and coding workflows."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                GhostOnboardingFeatureCard(
                    icon: "text.bubble",
                    title: "Ask naturally",
                    text: "Type what you need. Ghost detects whether it should answer directly or use local tools."
                )

                GhostOnboardingFeatureCard(
                    icon: "doc.text.magnifyingglass",
                    title: "Use context",
                    text: "Optionally include clipboard text and choose the working folder for file-aware tasks."
                )

                GhostOnboardingFeatureCard(
                    icon: "terminal",
                    title: "Agent mode",
                    text: "For coding, shell, files, and multi-step work, Ghost can route to the local Ghost Agent."
                )

                GhostOnboardingFeatureCard(
                    icon: "checkmark.shield",
                    title: "You stay in control",
                    text: "Approval settings decide when Ghost asks before actions."
                )
            }

            GhostOnboardingChecklistRow(
                icon: "1.circle",
                title: "Connect a model",
                text: "Choose DeepSeek, Claude, Gemini, or LM Studio."
            )

            GhostOnboardingChecklistRow(
                icon: "2.circle",
                title: "Pick your safety level",
                text: "Use Ask mode for a safer first experience."
            )

            GhostOnboardingChecklistRow(
                icon: "3.circle",
                title: "Try one real prompt",
                text: "Finish onboarding with a ready-to-send starter prompt."
            )
        }
    }

    private var connectStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            GhostOnboardingHero(
                icon: "network",
                title: "Connect the model Ghost should use.",
                subtitle: "For the simplest setup, keep routing on Auto. Ghost will use fast direct answers when possible and the local agent when a task needs files, coding, shell, or Mac actions."
            )

            HermesAgentSetupCard(store: store)

            SettingsCard(title: "Provider", systemImage: "cpu") {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsSegmentBlock(title: "AI provider") {
                        Picker("Provider", selection: $store.selectedProvider) {
                            ForEach(GhostProvider.allCases) { provider in
                                Text(provider.title).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text(store.selectedProvider.helpText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(GhostColors.mutedPlatinum)

                    if store.selectedProvider == .deepSeek {
                        SettingsSegmentBlock(title: "DeepSeek model") {
                            Picker("DeepSeek model", selection: $store.selectedDeepSeekModel) {
                                ForEach(DeepSeekModel.allCases) { model in
                                    Text(model.title).tag(model.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    if let keyProvider = selectedKeyProvider {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(keyProvider.title) API key")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(GhostColors.labelPlatinum)

                                Spacer()

                                if store.savedAPIKeyProviders.contains(keyProvider) {
                                    Label("Saved", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.green.opacity(0.75))
                                }
                            }

                            SecureField(
                                store.savedAPIKeyProviders.contains(keyProvider) ? "Key saved — paste a new key to replace it" : "Paste API key",
                                text: apiKeyBinding(for: keyProvider)
                            )
                            .textFieldStyle(.roundedBorder)

                            HStack {
                                Text("Keys are saved through Ghost's existing secrets service.")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(GhostColors.mutedPlatinum)

                                Spacer()

                                Button("Save Key") {
                                    store.saveAPIKeys()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(GhostColors.royalViolet.opacity(0.65))
                            }
                        }
                    } else if store.selectedProvider == .ollama {
                        GhostOnboardingTip(
                            icon: "shippingbox",
                            title: "Ollama selected",
                            text: "No API key is needed. Start Ollama, pull a model, then refresh models. Example: ollama pull llama3.1:8b"
                        )

                        HStack {
                            Link(
                                "Download Ollama",
                                destination: URL(string: "https://ollama.com/download")!
                            )

                            Spacer()

                            Button("Refresh Ollama Models") {
                                store.refreshOllamaModels()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        GhostOnboardingTip(
                            icon: "desktopcomputer",
                            title: "LM Studio selected",
                            text: "No API key is needed. Make sure the LM Studio server is running at localhost:1234."
                        )
                    }

                    if let message = store.settingsMessage {
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                    }
                }
            }

            SettingsCard(title: "Routing", systemImage: "arrow.triangle.branch") {
                VStack(alignment: .leading, spacing: 12) {
                    SettingsSegmentBlock(title: "Routing") {
                        Picker("Routing", selection: $store.enginePreference) {
                            ForEach(EnginePreference.allCases) { preference in
                                Text(preference.title).tag(preference)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text(store.enginePreference.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                        .lineSpacing(3)

                    if let warning = store.engineWarning {
                        SettingsWarning(text: warning)
                    }
                }
            }
        }
    }

    private var personalizeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            GhostOnboardingHero(
                icon: "slider.horizontal.3",
                title: "Make Ghost feel right before you start.",
                subtitle: "These defaults keep the app understandable for new users while still allowing power users to grow into agent workflows."
            )

            SettingsCard(title: "Appearance", systemImage: "paintbrush") {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsSegmentBlock(title: "Theme") {
                        Picker("Theme", selection: $store.appearanceMode) {
                            ForEach(GhostAppearance.allCases) { mode in
                                Label(mode.title, systemImage: mode.symbol).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    SettingsSegmentBlock(title: "Interface") {
                        Picker("Interface", selection: $store.interfacePreference) {
                            ForEach(GhostInterfacePreference.allCases) { preference in
                                Text(preference.title).tag(preference)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text(store.interfacePreference.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                }
            }

            SettingsCard(title: "Safety", systemImage: "checkmark.shield") {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsSegmentBlock(title: "Approval") {
                        Picker("Approval", selection: $store.approvalMode) {
                            ForEach(ApprovalMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text("Recommended first-run setting: Ask. Ghost will request approval before sensitive local actions.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                        .lineSpacing(3)
                }
            }

            SettingsCard(title: "Context", systemImage: "folder") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Include clipboard context when helpful", isOn: $store.includeClipboard)
                        .toggleStyle(.switch)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Working folder")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(GhostColors.labelPlatinum)

                        TextField("Working folder", text: $store.workingDirectoryPath)
                            .textFieldStyle(.roundedBorder)

                        Text("Ghost Agent uses this folder for local file, code, and shell tasks.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                    }
                }
            }
        }
    }

    private var learnStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            GhostOnboardingHero(
                icon: "keyboard",
                title: "You are ready to use Ghost.",
                subtitle: "Here are the only controls a new user needs to remember."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                GhostOnboardingFeatureCard(
                    icon: "option",
                    title: "Option-Space",
                    text: "Open or hide Ghost from anywhere on your Mac."
                )

                GhostOnboardingFeatureCard(
                    icon: "command",
                    title: "Command-Return",
                    text: "Send the current prompt."
                )

                GhostOnboardingFeatureCard(
                    icon: "gearshape",
                    title: "Command-,",
                    text: "Open settings."
                )

                GhostOnboardingFeatureCard(
                    icon: "mic",
                    title: "Command-D",
                    text: "Start or stop dictation."
                )
            }

            SettingsCard(title: "Start with a real prompt", systemImage: "paperplane") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pick one. Ghost will close onboarding and place the prompt in the composer.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(GhostColors.mutedPlatinum)

                    ForEach(samples) { sample in
                        Button {
                            store.finishOnboarding(seedPrompt: sample.prompt)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 13, weight: .semibold))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sample.title)
                                        .font(.system(size: 12.5, weight: .semibold))

                                    Text(sample.subtitle)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(GhostColors.mutedPlatinum)
                                }

                                Spacer()
                            }
                            .foregroundStyle(GhostColors.platinum)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(GhostColors.glassFill.opacity(0.65))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(GhostColors.glassBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            GhostOnboardingTip(
                icon: "lightbulb",
                title: "Simple rule",
                text: "Use normal language. Ghost decides whether the task needs a direct answer, clipboard context, local files, coding tools, or terminal-style output."
            )
        }
    }

    private var ragStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            GhostOnboardingHero(
                icon: "doc.text.magnifyingglass",
                title: "Ghost indexes your files.",
                subtitle: "Your Desktop is automatically scanned so you can ask questions about your documents, notes, PDFs, and code — no manual setup required."
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                GhostOnboardingFeatureCard(
                    icon: "desktopcomputer",
                    title: "Desktop auto-index",
                    text: "Ghost watches your Desktop and indexes new or changed files automatically."
                )

                GhostOnboardingFeatureCard(
                    icon: "doc.richtext",
                    title: "30+ file types",
                    text: "PDFs, Word docs, Markdown, code files, CSVs, plain text, and more."
                )

                GhostOnboardingFeatureCard(
                    icon: "magnifyingglass",
                    title: "Ask naturally",
                    text: "Try \"what does my syllabus say about homework\" or \"find where I wrote about authentication.\""
                )

                GhostOnboardingFeatureCard(
                    icon: "lock.shield",
                    title: "Stays on device",
                    text: "The RAG index lives in an SQLite database on your Mac. Nothing leaves your machine."
                )
            }

            SettingsCard(title: "RAG index status", systemImage: "cylinder") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(GhostColors.royalViolet)
                        Text("\(store.ragDocumentCount) documents indexed")
                            .font(.system(size: 12.5, weight: .semibold))
                        Spacer()
                    }

                    HStack {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(GhostColors.royalViolet)
                        Text("\(store.ragChunkCount) searchable chunks")
                            .font(.system(size: 12.5, weight: .semibold))
                        Spacer()
                    }
                }
                .padding(10)
            }

            GhostOnboardingTip(
                icon: "lightbulb",
                title: "Pro tip",
                text: "Type RAG: before any question to force Ghost to search your indexed files instead of using the web or clipboard."
            )
        }
    }

    private var footer: some View {
        HStack {
            Button("Back") {
                store.retreatOnboarding()
            }
            .buttonStyle(.bordered)
            .disabled(stepIndex == 0)

            Spacer()

            Text("Step \(stepIndex + 1) of \(steps.count)")
                .font(.system(size: 11))
                .foregroundStyle(GhostColors.mutedPlatinum)

            Spacer()

            Button(isLastStep ? "Start Using Ghost" : "Continue") {
                if isLastStep {
                    store.finishOnboarding(seedPrompt: "What can you help me do in Ghost?")
                } else {
                    store.advanceOnboarding()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(GhostColors.royalViolet.opacity(0.72))
        }
        .padding(.horizontal, GhostSpacing.wide)
        .padding(.vertical, 12)
        .background(GhostColors.barFill)
    }

    private var selectedKeyProvider: ProviderAPIKey? {
        switch store.selectedProvider {
        case .claude:
            return .anthropic
        case .gemini:
            return .gemini
        case .deepSeek:
            return .deepSeek
        case .openCodeGo:
            return .openCodeGo
        case .lmStudio, .ollama:
            return nil
        }
    }

    private func apiKeyBinding(for provider: ProviderAPIKey) -> Binding<String> {
        Binding(
            get: { store.apiKeyDrafts[provider] ?? "" },
            set: { store.apiKeyDrafts[provider] = $0 }
        )
    }
}

private struct GhostOnboardingSample: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let prompt: String
}

private struct GhostOnboardingStepRow: View {
    let step: GhostConversationStore.OnboardingStep
    let isSelected: Bool
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(isSelected ? GhostColors.royalViolet.opacity(0.22) : GhostColors.glassFill)
                    .frame(width: 28, height: 28)

                Image(systemName: isComplete ? "checkmark" : step.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected || isComplete ? GhostColors.royalViolet : GhostColors.mutedPlatinum)
            }

            Text(step.title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? GhostColors.platinum : GhostColors.mutedPlatinum)

            Spacer()
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? GhostColors.glassActiveFill : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isSelected ? GhostColors.glassActiveBorder : Color.clear, lineWidth: 1)
        )
    }
}

private struct GhostOnboardingHero: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(GhostColors.royalViolet.opacity(0.14))
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(GhostColors.royalViolet.opacity(0.92))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(GhostColors.platinum)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .ghostCard()
    }
}

private struct GhostOnboardingFeatureCard: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GhostColors.royalViolet.opacity(0.85))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GhostColors.platinum)

            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(GhostColors.mutedPlatinum)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .ghostCard()
    }
}

private struct GhostOnboardingChecklistRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GhostColors.royalViolet.opacity(0.82))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(GhostColors.platinum)

                Text(text)
                    .font(.system(size: 11.5))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(GhostColors.glassFill.opacity(0.55))
        )
    }
}

private struct GhostOnboardingTip: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GhostColors.champagne.opacity(0.85))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(GhostColors.platinum)

                Text(text)
                    .font(.system(size: 10.8))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(GhostColors.champagne.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(GhostColors.champagne.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Hermes Setup

private struct HermesAgentSetupCard: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        SettingsCard(title: "Hermes Agent", systemImage: "wand.and.stars") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(statusFill)
                            .frame(width: 42, height: 42)

                        Image(systemName: statusIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(GhostColors.platinum)

                        Text(statusSubtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                            .lineSpacing(3)
                    }

                    Spacer()
                }

                if let path = store.resolvedHermesPath {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Detected path")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(GhostColors.labelPlatinum)

                        Text(path)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(GhostColors.glassFill.opacity(0.55))
                    )
                }

                if !store.isHermesAvailable {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New to Hermes?")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(GhostColors.platinum)

                        Text("Install Hermes to enable local files, shell, coding, tool calling, skills, and other agent features.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                            .lineSpacing(3)

                        Text("Terminal install:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(GhostColors.labelPlatinum)

                        Text("curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(GhostColors.platinum)
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(GhostColors.glassFill.opacity(0.65))
                            )

                        HStack {
                            Link(
                                "Download Hermes Desktop",
                                destination: URL(string: "https://hermes-agent.nousresearch.com/")!
                            )

                            Spacer()

                            Link(
                                "Open install docs",
                                destination: URL(string: "https://hermes-agent.nousresearch.com/docs/getting-started/installation")!
                            )
                        }
                        .font(.system(size: 11.5, weight: .medium))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(GhostColors.champagne.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(GhostColors.champagne.opacity(0.13), lineWidth: 1)
                    )
                }

                HStack(spacing: 8) {
                    Button {
                        store.detectHermesAgent()
                    } label: {
                        if store.isCheckingHermes {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Scan", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isCheckingHermes)

                    Button {
                        store.chooseHermesBinary()
                    } label: {
                        Label("Choose Binary", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    if store.isHermesConnected {
                        Button(role: .destructive) {
                            store.disconnectHermes()
                        } label: {
                            Text("Disconnect")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            store.connectDetectedHermes()
                        } label: {
                            Text("Connect Hermes")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GhostColors.royalViolet.opacity(0.72))
                        .disabled(!store.isHermesAvailable)
                    }
                }

                if store.isHermesAvailable {
                    Button {
                        store.runHermesDoctor()
                    } label: {
                        Label("Run hermes doctor", systemImage: "stethoscope")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .disabled(store.isCheckingHermes)
                }

                if let message = store.hermesStatusMessage {
                    Text(message)
                        .font(.system(size: 10.8))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                        .lineLimit(6)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var statusTitle: String {
        if store.isHermesConnected {
            return "Hermes connected"
        }

        if store.isHermesAvailable {
            return "Hermes found"
        }

        return "Hermes not installed"
    }

    private var statusSubtitle: String {
        if store.isHermesConnected {
            return "Ghost will use Hermes Agent for local tools, files, shell, coding, skills, and agent workflows."
        }

        if store.isHermesAvailable {
            return "Hermes was detected. Connect it only if you want this app to use Hermes for tool calling."
        }

        return "You can still use Direct API for simple chat. Install Hermes when you want local tool calling and main agent functionality."
    }

    private var statusIcon: String {
        if store.isHermesConnected {
            return "checkmark.circle.fill"
        }

        if store.isHermesAvailable {
            return "link.circle"
        }

        return "arrow.down.circle"
    }

    private var statusColor: Color {
        if store.isHermesConnected {
            return .green.opacity(0.85)
        }

        if store.isHermesAvailable {
            return GhostColors.royalViolet.opacity(0.9)
        }

        return GhostColors.champagne.opacity(0.9)
    }

    private var statusFill: Color {
        if store.isHermesConnected {
            return .green.opacity(0.12)
        }

        if store.isHermesAvailable {
            return GhostColors.royalViolet.opacity(0.12)
        }

        return GhostColors.champagne.opacity(0.10)
    }
}

// MARK: - Settings

private struct SettingsPanelView: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsHeader

                SettingsHeroCard(
                    icon: "sparkles",
                    title: "Adaptive single prompt",
                    subtitle: "Ghost detects intent automatically. Everyday answers stay fast; local files, Desktop actions, coding, and shell work route to the agent."
                )

                HermesAgentSetupCard(store: store)

                Button {
                    store.showOnboarding()
                } label: {
                    Label("Open setup guide again", systemImage: "questionmark.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)

                SettingsCard(title: "Appearance", systemImage: "paintbrush") {
                    VStack(alignment: .leading, spacing: 14) {
                        SettingsSectionIntro(
                            title: "Choose how Ghost should feel.",
                            subtitle: "Use a soft glass appearance by default, or match your system."
                        )

                        SettingsSegmentBlock(title: "Theme") {
                            Picker("Theme", selection: $store.appearanceMode) {
                                ForEach(GhostAppearance.allCases) { mode in
                                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Toggle("Persistent Window", isOn: $store.isPersistentWindow)
                            .toggleStyle(.switch)

                        Text("When on, Ghost stays open after you click another app. Use the menu bar icon or Option+Space to hide it.")
                            .font(.system(size: 11, design: .default))
                            .foregroundStyle(GhostColors.mutedPlatinum)

                        SettingsSegmentBlock(title: "Terminal theme") {
                            Picker("Terminal theme", selection: $store.terminalTheme) {
                                ForEach(GhostTerminalTheme.allCases) { theme in
                                    Text(theme.title).tag(theme)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Text(store.terminalTheme.subtitle)
                            .font(.system(size: 11, design: .default))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                    }
                }

                SettingsCard(title: "Routing", systemImage: "arrow.triangle.branch") {
                    VStack(alignment: .leading, spacing: 14) {
                        SettingsSectionIntro(
                            title: "Let Ghost decide when to use local tools.",
                            subtitle: "Auto uses Direct API for simple answers and Ghost Agent for files, Desktop, coding, shell, and multi-step Mac actions."
                        )

                        SettingsSegmentBlock(title: "Routing") {
                            Picker("Routing", selection: $store.enginePreference) {
                                ForEach(EnginePreference.allCases) { preference in
                                    Text(preference.title).tag(preference)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        HStack(spacing: 8) {
                            SettingSummaryPill(
                                icon: store.executionEngine.systemImage,
                                title: "Current route",
                                value: store.executionEngine.title
                            )

                            SettingSummaryPill(
                                icon: "info.circle",
                                title: "Reason",
                                value: store.taskTimeline.route.nonEmpty ?? "Waiting"
                            )
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label("Why this route", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .foregroundStyle(GhostColors.faintPlatinum)

                            Text(store.routingExplanation)
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(GhostColors.mutedPlatinum)
                                .textSelection(.enabled)
                                .lineLimit(5)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(GhostColors.glassFill.opacity(0.52))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(GhostColors.glassBorder.opacity(0.7), lineWidth: 1)
                        )

                        if let warning = store.engineWarning {
                            SettingsWarning(text: warning)
                        }
                    }
                }

                SettingsCard(title: "Model", systemImage: "cpu") {
                    VStack(alignment: .leading, spacing: 14) {
                        ModelSummaryCard(store: store)

                        SettingsSegmentBlock(title: "Provider") {
                            Picker("Provider", selection: $store.selectedProvider) {
                                ForEach(GhostProvider.allCases) { provider in
                                    Text(provider.title).tag(provider)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if store.selectedProvider == .deepSeek {
                            SettingsSegmentBlock(title: "DeepSeek model") {
                                Picker("DeepSeek model", selection: $store.selectedDeepSeekModel) {
                                    ForEach(DeepSeekModel.allCases) { model in
                                        Text(model.title).tag(model.rawValue)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        if store.selectedProvider == .lmStudio {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Local model")
                                    .font(.system(size: 10, weight: .semibold, design: .default))
                                    .foregroundStyle(GhostColors.labelPlatinum)

                                HStack(spacing: 8) {
                                    Picker("Model", selection: $store.selectedLocalModel) {
                                        if store.localModels.isEmpty {
                                            Text(store.selectedLocalModel).tag(store.selectedLocalModel)
                                        }

                                        ForEach(store.localModels) { model in
                                            Text(model.id).tag(model.id)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)

                                    Button {
                                        store.refreshLocalModels()
                                    } label: {
                                        if store.isRefreshingLocalModels {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(GhostColors.mutedPlatinum)
                                    .help("Refresh")
                                }

                                HStack {
                                    Text("Context window")
                                        .font(.system(size: 11, weight: .medium, design: .default))
                                        .foregroundStyle(GhostColors.mutedPlatinum)

                                    Spacer()

                                    TextField("Tokens", value: $store.localContextWindow, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 110)

                                    Stepper("", value: $store.localContextWindow, in: 4_096...1_000_000, step: 4_096)
                                        .labelsHidden()
                            }
                        }

                        if store.selectedProvider == .ollama {
                            VStack(alignment: .leading, spacing: 12) {
                                SettingsSectionIntro(
                                    title: "Use models running locally through Ollama.",
                                    subtitle: "Start Ollama, pull a model, then refresh. Example: ollama pull llama3.1:8b"
                                )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Ollama server")
                                        .font(.system(size: 10, weight: .semibold, design: .default))
                                        .foregroundStyle(GhostColors.labelPlatinum)

                                    TextField("http://localhost:11434", text: $store.ollamaBaseURLString)
                                        .textFieldStyle(.roundedBorder)

                                    HStack {
                                        Link(
                                            "Download Ollama",
                                            destination: URL(string: "https://ollama.com/download")!
                                        )

                                        Spacer()

                                        Link(
                                            "Ollama API docs",
                                            destination: URL(string: "https://docs.ollama.com/api/introduction")!
                                        )
                                    }
                                    .font(.system(size: 11.5, weight: .medium))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Ollama model")
                                        .font(.system(size: 10, weight: .semibold, design: .default))
                                        .foregroundStyle(GhostColors.labelPlatinum)

                                    HStack(spacing: 8) {
                                        Picker("Model", selection: $store.selectedOllamaModel) {
                                            if store.ollamaModels.isEmpty {
                                                Text(store.selectedOllamaModel).tag(store.selectedOllamaModel)
                                            }

                                            ForEach(store.ollamaModels) { model in
                                                Text(model.id).tag(model.id)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)

                                        Button {
                                            store.refreshOllamaModels()
                                        } label: {
                                            if store.isRefreshingOllamaModels {
                                                ProgressView()
                                                    .controlSize(.small)
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(GhostColors.mutedPlatinum)
                                        .help("Refresh Ollama models")
                                    }
                                }

                                HStack {
                                    Text("Context window")
                                        .font(.system(size: 11, weight: .medium, design: .default))
                                        .foregroundStyle(GhostColors.mutedPlatinum)

                                    Spacer()

                                    TextField("Tokens", value: $store.localContextWindow, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 110)

                                    Stepper("", value: $store.localContextWindow, in: 4_096...1_000_000, step: 4_096)
                                        .labelsHidden()
                                }

                                SettingsWarning(
                                    text: "Ollama is local and private, but tool calling, files, shell, and coding actions still need Hermes, Ghost Agent, or OpenCode-compatible agent mode."
                                )
                            }
                        }

                        if store.selectedProvider == .openCodeGo {
                            VStack(alignment: .leading, spacing: 12) {
                                SettingsSectionIntro(
                                    title: "Use OpenCode Go models.",
                                    subtitle: "Save your OpenCode Go API key under API Keys, then refresh to sync available models."
                                )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("OpenCode Go model")
                                        .font(.system(size: 10, weight: .semibold, design: .default))
                                        .foregroundStyle(GhostColors.labelPlatinum)

                                    HStack(spacing: 8) {
                                        Picker("Model", selection: $store.selectedOpenCodeGoModel) {
                                            if store.openCodeGoModels.isEmpty {
                                                Text(store.selectedOpenCodeGoModel).tag(store.selectedOpenCodeGoModel)
                                            }

                                            ForEach(store.openCodeGoModels) { model in
                                                Text(model.id).tag(model.id)
                                            }
                                        }
                                        .frame(maxWidth: .infinity)

                                        Button {
                                            store.refreshOpenCodeGoModels()
                                        } label: {
                                            if store.isRefreshingOpenCodeGoModels {
                                                ProgressView()
                                                    .controlSize(.small)
                                            } else {
                                                Image(systemName: "arrow.clockwise")
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(GhostColors.mutedPlatinum)
                                        .help("Refresh OpenCode Go models")
                                    }
                                }

                                SettingsWarning(
                                    text: "OpenCode Go uses your saved OPENCODE_API_KEY. Broad Mac actions, screenshots/OCR, binary documents, and coding edits still need Hermes Agent or Ghost Agent mode."
                                )
                            }
                        }
                    }
                }
                }

                SettingsCard(title: "Behavior", systemImage: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 14) {
                        SettingsSegmentBlock(title: "Effort") {
                            Picker("Effort", selection: $store.effortMode) {
                                ForEach(EffortMode.allCases) { mode in
                                    Text(mode.title(for: store.selectedProvider)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Text(store.effortMode.promptInstruction)
                            .font(.system(size: 11, design: .default))
                            .foregroundStyle(GhostColors.mutedPlatinum)

                        SettingsSegmentBlock(title: "Approval") {
                            Picker("Approval", selection: $store.approvalMode) {
                                ForEach(ApprovalMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Toggle("Verify completed tool work", isOn: $store.isTaskVerificationEnabled)
                            .toggleStyle(.switch)

                        Text("When enabled, Ghost adds a factual verification footer for agent, file, web, and failed runs.")
                            .font(.system(size: 11, design: .default))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                    }
                }

                SettingsCard(title: "Context", systemImage: "doc.on.clipboard") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Include clipboard context", isOn: $store.includeClipboard)
                            .toggleStyle(.switch)

                        TextField("Toolsets, comma separated", text: $store.toolsets)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                SettingsCard(title: "RAG Index", systemImage: "doc.text.magnifyingglass") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable RAG", isOn: $store.isRAGEnabled)
                        .toggleStyle(.switch)
                        .font(.system(size: 12, weight: .medium))

                        Text("RAG stays off until you opt in. When enabled, Ghost indexes only the folder you choose here.")
                            .font(.system(size: 10.5, design: .default))
                            .foregroundStyle(GhostColors.mutedPlatinum)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("RAG folder")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .foregroundStyle(GhostColors.labelPlatinum)

                            HStack(spacing: 8) {
                                TextField("Folder to index", text: $store.ragRootPath)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    store.chooseRAGFolder()
                                } label: {
                                    Label("Choose", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        Toggle("Watch selected folder for changes", isOn: Binding(
                            get: { store.isRAGEnabled && !store.isRAGWatcherPaused },
                            set: { store.isRAGWatcherPaused = !$0 }
                        ))
                        .toggleStyle(.switch)
                        .disabled(!store.isRAGEnabled)
                        .font(.system(size: 12, weight: .medium))

                        HStack {
                            Text("\(store.ragDocumentCount) documents, \(store.ragChunkCount) chunks indexed")
                                .font(.system(size: 11.5, weight: .medium, design: .default))
                                .foregroundStyle(GhostColors.platinum)
                            Spacer()
                        }

                        Text("Supported types include PDF, EPUB, DOCX, Markdown, code, CSV, plain text, JSON, HTML, and RTF.")
                            .font(.system(size: 10.5, design: .default))
                            .foregroundStyle(GhostColors.mutedPlatinum)

                        HStack(spacing: 10) {
                            Button {
                                store.clearRAGIndex()
                            } label: {
                                Label("Clear Index", systemImage: "trash")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .tint(.red.opacity(0.6))
                            .controlSize(.small)

                            Button {
                                store.syncSelectedRAGFolder()
                            } label: {
                                Label("Sync Folder", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!store.isRAGEnabled)
                        }
                    }
                }

                SettingsCard(title: "Workspace", systemImage: "folder") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Where Ghost Agent runs local tools.")
                            .font(.system(size: 11, design: .default))
                            .foregroundStyle(GhostColors.mutedPlatinum)

                        HStack(spacing: 8) {
                            TextField("Working folder", text: $store.workingDirectoryPath)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                store.chooseWorkingDirectory()
                            } label: {
                                Label("Choose", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text("Where Ghost-produced documents and code artifacts should go by default.")
                            .font(.system(size: 11, design: .default))
                            .foregroundStyle(GhostColors.mutedPlatinum)

                        HStack(spacing: 8) {
                            TextField("Output folder", text: $store.documentOutputDirectoryPath)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                store.chooseDocumentOutputFolder()
                            } label: {
                                Label("Choose", systemImage: "folder.badge.plus")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                SettingsCard(title: "How To", systemImage: "book") {
                    HowToSettingsContent()
                }

                SettingsCard(title: "Intelligence Roadmap", systemImage: "brain") {
                    IntelligenceRoadmapContent()
                }

                SettingsCard(title: "API Keys", systemImage: "key") {
                    APIKeysSettingsContent(store: store)
                }

                HStack {
                    Spacer()
                    Text("Ghost v\(GhostVersion.current)")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundStyle(GhostColors.mutedPlatinum.opacity(0.6))
                    Spacer()
                }
                .padding(.top, 4)

                if let message = store.settingsMessage {
                    Text(message)
                        .font(.system(size: 11, design: .default))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GhostSpacing.wide)
            .padding(.bottom, GhostSpacing.generous)
        }
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(GhostColors.royalViolet.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: "gearshape.2")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GhostColors.royalViolet.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Ghost Settings")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(GhostColors.platinum)

                Text("Make Ghost faster, calmer, and more aware of your Mac.")
                    .font(.system(size: 12, design: .default))
                    .foregroundStyle(GhostColors.mutedPlatinum)
            }

            Spacer()
        }
        .padding(.top, 4)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GhostColors.royalViolet.opacity(0.68))

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundStyle(GhostColors.mutedPlatinum)

                Spacer()
            }

            content
        }
        .padding(16)
        .ghostCard()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsHeroCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GhostColors.royalViolet.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GhostColors.royalViolet.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(GhostColors.platinum)

                Text(subtitle)
                    .font(.system(size: 12, design: .default))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(14)
        .ghostCard()
    }
}

private struct SettingsSectionIntro: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(GhostColors.platinum)

            Text(subtitle)
                .font(.system(size: 11.5, design: .default))
                .foregroundStyle(GhostColors.mutedPlatinum)
                .lineSpacing(3)
        }
    }
}

private struct SettingsSegmentBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundStyle(GhostColors.labelPlatinum)
                .textCase(.uppercase)

            content
                .frame(maxWidth: .infinity)
        }
    }
}

private struct SettingSummaryPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GhostColors.royalViolet.opacity(0.75))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .default))
                    .foregroundStyle(GhostColors.faintPlatinum)
                    .textCase(.uppercase)

                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(GhostColors.glassFill.opacity(0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(GhostColors.glassBorder.opacity(0.7), lineWidth: 1)
        )
    }
}

private struct SettingsWarning: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .semibold))
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 11, design: .default))
                .lineSpacing(3)
        }
        .foregroundStyle(.orange.opacity(0.78))
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.orange.opacity(0.08))
        )
    }
}

private struct HowToSettingsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionIntro(
                title: "Hermes Agent for full desktop work",
                subtitle: "Install Hermes when Ghost should edit files, run multi-step coding workflows, use approvals, and coordinate broader Mac actions."
            )

            VStack(alignment: .leading, spacing: 6) {
                howToLine("1. Download Hermes Agent from the Ghost/Hermes release source you trust.")
                howToLine("2. Put the binary somewhere stable, for example ~/.local/bin/hermes, and make it executable.")
                howToLine("3. In Settings, turn on Hermes Agent and choose the executable if Ghost does not detect it.")
                howToLine("4. Keep routing on Auto so simple answers use Direct API and desktop/coding work uses the agent.")
            }

            SettingsSectionIntro(
                title: "API-key-only mode",
                subtitle: "Direct API mode works for normal chat, web-assisted answers, local-model file tools, reminders, calendar reads, and simple document creation through Ghost's built-in harness."
            )

            SettingsWarning(
                text: "Without Hermes Agent, broad computer control, large code edits, approval-driven shell workflows, app automation, and non-text desktop actions are limited or unavailable."
            )
        }
    }

    private func howToLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, design: .default))
            .foregroundStyle(GhostColors.mutedPlatinum)
            .lineSpacing(3)
    }
}

private struct IntelligenceRoadmapContent: View {
    private let ideas = [
        "Prompt memory: remember preferred tone, output folders, recurring projects, and tool risk tolerance.",
        "Task classifier: score prompts for answer, file work, coding, automation, vision, RAG, and web before routing.",
        "Readiness checks: show whether agent, API key, local model, calendar, reminders, RAG, and shell are ready.",
        "Vision fallback: run local OCR when the selected model is not vision-capable, then send extracted text.",
        "Autonomous validation: after creating docs or code, verify files, run focused checks, and report exact evidence.",
        "Live presence: small professional status states such as reading, planning, editing, waiting for approval, and done."
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(ideas, id: \.self) { idea in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(GhostColors.royalViolet.opacity(0.78))
                        .padding(.top, 2)

                    Text(idea)
                        .font(.system(size: 11.5, design: .default))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                        .lineSpacing(3)
                }
            }
        }
    }
}

private struct ModelSummaryCard: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(GhostColors.royalViolet.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: store.effectiveProvider.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GhostColors.royalViolet.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(store.modelDisplayName)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(GhostColors.platinum)

                Text(modelSubtitle)
                    .font(.system(size: 11.5, design: .default))
                    .foregroundStyle(GhostColors.mutedPlatinum)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(GhostColors.glassFill.opacity(0.50))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(GhostColors.glassBorder.opacity(0.7), lineWidth: 1)
        )
    }

    private var modelSubtitle: String {
        switch store.selectedProvider {
        case .deepSeek:
            return "Fast everyday reasoning"
        case .claude:
            return "Strong writing and reasoning"
        case .gemini:
            return "Large-context Google model"
        case .lmStudio:
            return "Local model through LM Studio"
        case .ollama:
            return "Local model through Ollama"
        case .openCodeGo:
            return "OpenCode Go model"
        }
    }
}

private struct APIKeysSettingsContent: View {
    @Bindable var store: GhostConversationStore

    private var directProviders: [ProviderAPIKey] {
        ProviderAPIKey.allCases.filter { $0.groupTitle == "Ghost direct providers" }
    }

    private var openCodeProviders: [ProviderAPIKey] {
        ProviderAPIKey.allCases.filter { $0.groupTitle == "OpenCode / agent provider keys" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSectionIntro(
                title: "Save keys once, use them everywhere.",
                subtitle: "Ghost uses direct-provider keys itself. OpenCode/Hermes/Ghost-agent runs receive the extra provider keys as environment variables."
            )

            keyGroup(title: "Direct API keys", providers: directProviders)

            Divider()
                .overlay(GhostColors.glassBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("OpenCode-compatible keys")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(GhostColors.platinum)

                Text("OpenCode can also be configured with opencode auth login. These fields are for users who want Ghost to pass provider API keys into agent/tool-calling runs automatically.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .lineSpacing(3)

                Text("Official OpenCode CLI setup: opencode auth login")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(GhostColors.mutedPlatinum)
                    .textSelection(.enabled)
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(GhostColors.glassFill.opacity(0.55))
                    )
            }

            keyGroup(title: "Agent provider environment keys", providers: openCodeProviders)

            HStack {
                Spacer()

                Button("Save Keys") {
                    store.saveAPIKeys()
                }
                .buttonStyle(.borderedProminent)
                .tint(GhostColors.royalViolet.opacity(0.55))
            }
        }
    }

    private func keyGroup(title: String, providers: [ProviderAPIKey]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GhostColors.labelPlatinum)

            ForEach(providers) { provider in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.title)
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .foregroundStyle(GhostColors.mutedPlatinum)

                            Text(provider.environmentKey)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(GhostColors.faintPlatinum)
                        }

                        Spacer()

                        if store.savedAPIKeyProviders.contains(provider) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.green.opacity(0.65))
                                    .frame(width: 6, height: 6)

                                Text("Saved")
                                    .font(.system(size: 10, design: .default))
                            }
                            .foregroundStyle(.green.opacity(0.65))
                        }

                        Button {
                            store.clearAPIKey(for: provider)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(GhostColors.labelPlatinum)
                        }
                        .buttonStyle(.plain)
                    }

                    SecureField(
                        store.savedAPIKeyProviders.contains(provider) ? "Key saved — enter new key to replace" : "API key",
                        text: Binding(
                            get: { store.apiKeyDrafts[provider] ?? "" },
                            set: { store.apiKeyDrafts[provider] = $0 }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
}

private struct MiniReplyHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Markdown

private struct MarkdownMessageText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let value):
                    Text(inline(value))
                        .font(GhostFonts.hkGrotesk(size: level == 2 ? 17 : 15, weight: .semibold))
                        .foregroundStyle(GhostColors.platinum)
                        .padding(.top, level == 2 ? 2 : 0)

                case .paragraph(let value):
                    Text(inline(value))
                        .font(GhostFonts.hkGrotesk(size: 15))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                        .lineSpacing(4)

                case .bullet(let value):
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(GhostFonts.sourceSerif(size: 15))
                            .foregroundStyle(GhostColors.royalViolet.opacity(0.6))
                        Text(inline(value))
                            .font(GhostFonts.hkGrotesk(size: 15))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                            .lineSpacing(4)
                    }

                case .numbered(let number, let value):
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(number).")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(GhostColors.royalViolet.opacity(0.6))
                        Text(inline(value))
                            .font(GhostFonts.hkGrotesk(size: 15))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                            .lineSpacing(4)
                    }

                case .code(let value):
                    CodeBlockView(code: value)

                case .table(let headers, let rows):
                    MarkdownTableView(headers: headers, rows: rows, inline: inline)

                case .rule:
                    Rectangle()
                        .fill(GhostColors.glassBorder)
                        .frame(height: 1)
                        .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var blocks: [MarkdownBlock] {
        MarkdownBlock.parse(normalized(text))
    }

    private func inline(_ raw: String) -> AttributedString {
        (
            try? AttributedString(
                markdown: raw,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        ) ?? AttributedString(raw)
    }

    private func normalized(_ raw: String) -> String {
        var value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "⸻", with: "---")

        value = value.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        return value
    }
}

private struct MarkdownTableView: View {
    let headers: [String]
    let rows: [[String]]
    let inline: (String) -> AttributedString

    private var columnCount: Int {
        max(headers.count, rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { index in
                        tableCell(headers[safe: index] ?? "", isHeader: true)
                    }
                }

                Divider()
                    .gridCellUnsizedAxes(.horizontal)

                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { columnIndex in
                            tableCell(row[safe: columnIndex] ?? "", isHeader: false)
                                .background(rowIndex.isMultiple(of: 2) ? Color.white.opacity(0.018) : Color.clear)
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous)
                    .fill(Color.white.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous)
                    .strokeBorder(GhostColors.glassBorder, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tableCell(_ value: String, isHeader: Bool) -> some View {
        Text(inline(value))
            .font(isHeader ? GhostFonts.hkGrotesk(size: 13.5, weight: .semibold) : GhostFonts.hkGrotesk(size: 13.5))
            .foregroundStyle(isHeader ? GhostColors.platinum : GhostColors.mutedPlatinum)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 96, alignment: .leading)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(GhostColors.glassBorder.opacity(0.55))
                    .frame(width: 1)
            }
    }
}

private enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(String)
    case numbered(Int, String)
    case code(String)
    case table(headers: [String], rows: [[String]])
    case rule

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var inCodeBlock = false
        let lines = markdown.components(separatedBy: "\n")
        var index = 0

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
            paragraphLines.removeAll()
        }

        while index < lines.count {
            let rawLine = lines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                    inCodeBlock = false
                } else {
                    flushParagraph()
                    inCodeBlock = true
                }
                index += 1
                continue
            }

            if inCodeBlock {
                codeLines.append(rawLine)
                index += 1
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if let table = tableBlock(startingAt: index, in: lines) {
                flushParagraph()
                blocks.append(.table(headers: table.headers, rows: table.rows))
                index = table.nextIndex
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(.rule)
                index += 1
                continue
            }

            if trimmed.hasPrefix("### ") {
                flushParagraph()
                blocks.append(.heading(level: 3, text: String(trimmed.dropFirst(4))))
                index += 1
                continue
            }

            if trimmed.hasPrefix("## ") {
                flushParagraph()
                blocks.append(.heading(level: 2, text: String(trimmed.dropFirst(3))))
                index += 1
                continue
            }

            if trimmed.hasPrefix("# ") {
                flushParagraph()
                blocks.append(.heading(level: 2, text: String(trimmed.dropFirst(2))))
                index += 1
                continue
            }

            if let bullet = bulletText(from: trimmed) {
                flushParagraph()
                blocks.append(.bullet(bullet))
                index += 1
                continue
            }

            if let numbered = numberedText(from: trimmed) {
                flushParagraph()
                blocks.append(.numbered(numbered.number, numbered.text))
                index += 1
                continue
            }

            paragraphLines.append(trimmed)
            index += 1
        }

        if inCodeBlock {
            blocks.append(.code(codeLines.joined(separator: "\n")))
        }

        flushParagraph()

        return blocks.isEmpty ? [.paragraph(markdown)] : blocks
    }

    private static func tableBlock(startingAt startIndex: Int, in lines: [String]) -> (headers: [String], rows: [[String]], nextIndex: Int)? {
        guard startIndex + 1 < lines.count else { return nil }
        let headerLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let separatorLine = lines[startIndex + 1].trimmingCharacters(in: .whitespaces)
        guard isTableRow(headerLine), isTableSeparator(separatorLine) else { return nil }

        let headers = tableCells(from: headerLine)
        guard headers.count >= 2 else { return nil }

        var rows: [[String]] = []
        var index = startIndex + 2
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard isTableRow(line), !isTableSeparator(line) else { break }
            rows.append(tableCells(from: line))
            index += 1
        }

        return (headers, rows, index)
    }

    private static func isTableRow(_ line: String) -> Bool {
        line.contains("|") && tableCells(from: line).count >= 2
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(from: line)
        guard cells.count >= 2 else { return false }
        return cells.allSatisfy { cell in
            let value = cell.trimmingCharacters(in: .whitespaces)
            guard value.count >= 3 else { return false }
            return value.allSatisfy { char in
                char == "-" || char == ":"
            } && value.contains("-")
        }
    }

    private static func tableCells(from line: String) -> [String] {
        var value = line.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("|") { value.removeFirst() }
        if value.hasSuffix("|") { value.removeLast() }
        return value
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    private static func bulletText(from line: String) -> String? {
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return String(line.dropFirst(2))
        }
        return nil
    }

    private static func numberedText(from line: String) -> (number: Int, text: String)? {
        let parts = line.split(separator: " ", maxSplits: 1)
        guard parts.count == 2 else { return nil }

        let marker = parts[0]
        guard marker.hasSuffix("."),
              let number = Int(marker.dropLast()) else {
            return nil
        }

        return (number, String(parts[1]))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Typography Helpers

enum GhostFonts {
    static func sourceSerif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold:
            return .custom("Source Serif Pro Bold", size: size)
        case .semibold:
            return .custom("Source Serif Pro Semibold", size: size)
        default:
            return .custom("Source Serif Pro", size: size)
        }
    }

    static func hkGrotesk(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .semibold:
            return .custom("HK Grotesk SemiBold", size: size)
        case .medium:
            return .custom("HK Grotesk Medium", size: size)
        default:
            return .custom("HK Grotesk", size: size)
        }
    }

    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension NSFont {
    static func ghostSourceSerif(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let name: String
        switch weight {
        case .bold:
            name = "Source Serif Pro Bold"
        case .semibold:
            name = "Source Serif Pro Semibold"
        default:
            name = "Source Serif Pro"
        }
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }

    static func ghostHKGrotesk(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let name: String
        switch weight {
        case .semibold, .bold:
            name = "HK Grotesk SemiBold"
        case .medium:
            name = "HK Grotesk Medium"
        default:
            name = "HK Grotesk"
        }
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - Document Studio drawer

private struct DocumentStudioDrawerView: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                drawerHeader
                Divider().background(GhostColors.glassBorder)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if store.producedDocuments.isEmpty {
                            emptyState
                        } else {
                            ForEach(store.producedDocuments) { document in
                                DocumentStudioRow(
                                    document: document,
                                    onOpen: { store.openProducedDocument(document) },
                                    onReveal: { store.revealProducedDocument(document) },
                                    onCopyPath: { store.copyProducedDocumentPath(document) }
                                )
                            }
                        }
                    }
                    .padding(10)
                }
            }
            .frame(width: 320)
            .background(GhostColors.drawerFill.opacity(0.92))
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: GhostRadii.card, style: .continuous)
                    .stroke(GhostColors.glassBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: GhostRadii.card, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            .padding(8)
        }
    }

    private var drawerHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Document Studio")
                    .font(GhostTypography.displayBold(size: 18))
                    .tracking(-0.3)
                    .foregroundStyle(GhostColors.platinum)

                Text("\(store.producedDocuments.count) verified outputs")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(GhostColors.mutedPlatinum)
            }

            Spacer()

            Button {
                store.revealDocumentOutputFolder()
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GhostColors.mutedPlatinum)
            }
            .buttonStyle(.plain)
            .help("Reveal output folder")

            Button {
                store.clearProducedDocuments()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GhostColors.mutedPlatinum)
            }
            .buttonStyle(.plain)
            .help("Clear list")
            .disabled(store.producedDocuments.isEmpty)

            Button {
                store.toggleDocumentStudio()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GhostColors.mutedPlatinum)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(GhostColors.faintPlatinum)

            Text("No verified outputs yet.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GhostColors.platinum)

            Text("Files Ghost creates or verifies will appear here with open, reveal, and copy-path actions.")
                .font(.system(size: 11))
                .foregroundStyle(GhostColors.mutedPlatinum)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Button {
                store.revealDocumentOutputFolder()
            } label: {
                Label("Open output folder", systemImage: "folder")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
    }
}

private struct DocumentStudioRow: View {
    let document: GhostProducedDocument
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onCopyPath: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(GhostColors.royalViolet.opacity(0.8))
                        .frame(width: 20, height: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(document.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(GhostColors.platinum)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(document.displayPath)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(GhostColors.mutedPlatinum)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open")

            HStack(spacing: 8) {
                Text(document.kind)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(GhostColors.faintPlatinum)
                    .textCase(.uppercase)

                Text(document.createdAt, style: .date)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(GhostColors.faintPlatinum)

                Text(document.createdAt, style: .time)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(GhostColors.faintPlatinum)

                Spacer()

                rowButton(systemImage: "arrow.up.forward.app", help: "Open", action: onOpen)
                rowButton(systemImage: "magnifyingglass", help: "Reveal in Finder", action: onReveal)
                rowButton(systemImage: "doc.on.doc", help: "Copy path", action: onCopyPath)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous)
                .fill(GhostColors.glassFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous)
                .stroke(GhostColors.glassBorder.opacity(0.7), lineWidth: 1)
        )
    }

    private var icon: String {
        switch document.kind.lowercased() {
        case "folder":
            return "folder"
        case "pdf":
            return "doc.richtext"
        case "docx":
            return "doc.text"
        case "pptx":
            return "rectangle.on.rectangle"
        case "xlsx", "csv":
            return "tablecells"
        case "png", "jpg", "jpeg", "gif", "heic", "webp":
            return "photo"
        default:
            return "doc"
        }
    }

    private func rowButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(GhostColors.mutedPlatinum)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(GhostColors.glassFill.opacity(0.9))
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - History drawer

private struct HistoryDrawerView: View {
    @Bindable var store: GhostConversationStore

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                drawerHeader
                Divider().background(GhostColors.glassBorder)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if store.conversations.isEmpty {
                            Text("No conversations yet.")
                                .font(.system(size: 12))
                                .foregroundStyle(GhostColors.mutedPlatinum)
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(store.conversations) { conversation in
                                HistoryRow(
                                    conversation: conversation,
                                    isActive: conversation.id == store.currentConversationID,
                                    onLoad: { store.loadConversation(id: conversation.id) },
                                    onDelete: { store.deleteConversation(id: conversation.id) }
                                )
                            }
                        }
                    }
                    .padding(10)
                }
            }
            .frame(width: 280)
            .background(GhostColors.drawerFill.opacity(0.92))
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: GhostRadii.card, style: .continuous)
                    .stroke(GhostColors.glassBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: GhostRadii.card, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            .padding(8)
        }
    }

    private var drawerHeader: some View {
        HStack {
            Text("History")
                .font(GhostTypography.displayBold(size: 18))
                .tracking(-0.3)
                .foregroundStyle(GhostColors.platinum)
            Spacer()
            Button {
                store.startNewConversation()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GhostColors.mutedPlatinum)
            }
            .buttonStyle(.plain)
            .help("New chat")
            Button {
                store.toggleHistory()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GhostColors.mutedPlatinum)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct HistoryRow: View {
    let conversation: PersistedConversation
    let isActive: Bool
    let onLoad: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onLoad) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.displayTitle)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(GhostColors.platinum)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(conversation.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                }
                Spacer(minLength: 4)
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(GhostColors.faintPlatinum)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous)
                    .fill(isActive ? GhostColors.glassActiveFill : GhostColors.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GhostRadii.small, style: .continuous)
                    .stroke(isActive ? GhostColors.glassActiveBorder : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Prompt library popover

private struct PromptLibraryPopover: View {
    @Bindable var store: GhostConversationStore
    @State private var newTitle = ""
    @State private var newBody = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Prompt Library")
                    .font(GhostTypography.displayBold(size: 16))
                    .tracking(-0.2)
                    .foregroundStyle(GhostColors.platinum)
                Spacer()
                Button {
                    store.togglePromptLibrary()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("Title (optional)", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(GhostColors.platinum)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(GhostColors.glassFill))
                TextField("Prompt body", text: $newBody, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(GhostColors.platinum)
                    .lineLimit(1...4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(GhostColors.glassFill))
                Button {
                    guard !newBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    store.addPromptToLibrary(title: newTitle, body: newBody)
                    newTitle = ""
                    newBody = ""
                } label: {
                    Label("Save prompt", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(GhostColors.platinum)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(GhostColors.glassActiveFill))
                }
                .buttonStyle(.plain)
            }

            Divider().background(GhostColors.glassBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(store.savedPrompts) { prompt in
                        PromptRow(
                            prompt: prompt,
                            onUse: { store.useSavedPrompt(prompt) },
                            onDelete: { store.deleteSavedPrompt(id: prompt.id) }
                        )
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 420, maxHeight: 320)
        .background(GhostColors.popoverFill.opacity(0.96))
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: GhostRadii.card, style: .continuous)
                .stroke(GhostColors.glassBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: GhostRadii.card, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 76)
    }
}

private struct PromptRow: View {
    let prompt: SavedPrompt
    let onUse: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onUse) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(prompt.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GhostColors.platinum)
                        .lineLimit(1)
                    Text(prompt.body)
                        .font(.system(size: 11))
                        .foregroundStyle(GhostColors.mutedPlatinum)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(GhostColors.faintPlatinum)
            }
            .buttonStyle(.plain)
            .help("Delete")
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(GhostColors.glassFill))
    }
}
