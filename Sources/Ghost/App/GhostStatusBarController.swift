import AppKit
import SwiftUI

@MainActor
final class GhostStatusBarController: NSObject {
    private static let screenInset: CGFloat = 12
    private static let menuBarOverlap: CGFloat = 1

    private let store: GhostConversationStore
    private var statusItem: NSStatusItem?
    private var panelWindow: GhostMenuBarPanel?
    private var toggleObserver: NSObjectProtocol?
    private var localMouseDownMonitor: Any?
    private var globalMouseDownMonitor: Any?

    init(store: GhostConversationStore) {
        self.store = store
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }

        button.image = GhostMenuBarIcon.make()
        button.image?.isTemplate = true
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        button.toolTip = "Ghost - Option+Space"

        self.statusItem = item

        toggleObserver = NotificationCenter.default.addObserver(
            forName: .ghostTogglePanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.togglePanel()
            }
        }
    }

    @objc private func statusItemClicked() {
        togglePanel()
    }

    private func togglePanel() {
        if panelWindow?.isVisible == true {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard panelWindow?.isVisible != true else { return }

        let initialSize = constrainedPanelSize(for: store.preferredPanelSize)
        let finalFrame = anchoredPanelFrame(for: initialSize)
        let panel = GhostMenuBarPanel(
            contentRect: finalFrame,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.animationBehavior = .none
        panel.alphaValue = 0
        panel.contentViewController = NSHostingController(
            rootView: GhostPanelView(
                store: store,
                configuresWindow: false,
                panelSizeProvider: { [weak self] size in
                    self?.constrainedPanelSize(for: size) ?? size
                },
                onPanelSizeChange: { [weak self] size in
                    Task { @MainActor in
                        self?.resizePanel(to: size)
                    }
                }
            )
        )

        panelWindow = panel
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        panel.orderFrontRegardless()
        installMouseDownMonitorsAfterOpen()
        animatePanelOpen(panel)
    }

    private func closePanel() {
        guard let panel = panelWindow else { return }
        removeMouseDownMonitors()
        panelWindow = nil

        animatePanelClose(panel) {
            Task { @MainActor in
                panel.close()
            }
        }
    }

    private func resizePanel(to preferredSize: CGSize) {
        guard let panel = panelWindow, panel.isVisible else { return }
        let size = constrainedPanelSize(for: preferredSize)
        let frame = anchoredPanelFrame(for: size)
        guard panel.frame != frame else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func constrainedPanelSize(for preferredSize: CGSize) -> CGSize {
        let visibleFrame = statusItemScreen?.visibleFrame
        guard let visibleFrame else { return preferredSize }

        return CGSize(
            width: min(preferredSize.width, max(1, visibleFrame.width - Self.screenInset * 2)),
            height: min(preferredSize.height, max(1, visibleFrame.height - Self.screenInset))
        )
    }

    private func anchoredPanelFrame(for size: CGSize) -> NSRect {
        let visibleFrame = statusItemScreen?.visibleFrame ?? .zero
        let anchorFrame = statusButtonFrameInScreen ?? NSRect(
            x: visibleFrame.maxX - size.width,
            y: visibleFrame.maxY,
            width: 1,
            height: 1
        )

        let minX = visibleFrame.minX + Self.screenInset
        let maxX = max(minX, visibleFrame.maxX - size.width - Self.screenInset)
        let x = min(max(anchorFrame.midX - size.width / 2, minX), maxX)
        let topY = visibleFrame.maxY + Self.menuBarOverlap
        return NSRect(x: x, y: topY - size.height, width: size.width, height: size.height)
    }

    private var statusButtonFrameInScreen: NSRect? {
        guard let button = statusItem?.button, let window = button.window else { return nil }
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(buttonRectInWindow)
    }

    private var statusItemScreen: NSScreen? {
        guard let buttonFrame = statusButtonFrameInScreen else {
            return statusItem?.button?.window?.screen ?? NSScreen.main
        }

        let anchorPoint = CGPoint(x: buttonFrame.midX, y: buttonFrame.midY)
        return NSScreen.screens.first { $0.frame.contains(anchorPoint) }
            ?? statusItem?.button?.window?.screen
            ?? NSScreen.main
    }

    private func animatePanelOpen(_ panel: NSWindow) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func animatePanelClose(_ panel: NSWindow, completion: @escaping @Sendable () -> Void) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            completion()
        }
    }

    private func installMouseDownMonitors() {
        guard localMouseDownMonitor == nil, globalMouseDownMonitor == nil else { return }

        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.closePanelIfClickIsOutside()
            }
            return event
        }

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePanelIfClickIsOutside()
            }
        }
    }

    private func installMouseDownMonitorsAfterOpen() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.installMouseDownMonitors()
        }
    }

    private func removeMouseDownMonitors() {
        if let localMouseDownMonitor {
            NSEvent.removeMonitor(localMouseDownMonitor)
            self.localMouseDownMonitor = nil
        }
        if let globalMouseDownMonitor {
            NSEvent.removeMonitor(globalMouseDownMonitor)
            self.globalMouseDownMonitor = nil
        }
    }

    private func closePanelIfClickIsOutside() {
        guard !store.isPersistentWindow else { return }
        let mouseLocation = NSEvent.mouseLocation
        if panelWindow?.frame.contains(mouseLocation) == true {
            return
        }
        if statusButtonFrameInScreen?.contains(mouseLocation) == true {
            return
        }
        closePanel()
    }
}

private final class GhostMenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
