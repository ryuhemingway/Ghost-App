import AppKit
import SwiftUI

@MainActor
final class GhostStatusBarController: NSResponder {
    private let store: GhostConversationStore
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hoverCloseWorkItem: DispatchWorkItem?
    private var hoverOpenWorkItem: DispatchWorkItem?
    private let openDelay: TimeInterval = 0.12
    private let closeDelay: TimeInterval = 0.35

    init(store: GhostConversationStore) {
        self.store = store
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }
        button.image = GhostMenuBarIcon.make()
        button.image?.isTemplate = true
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Ghost — Option+Space"

        let trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)

        self.statusItem = item
    }

    @objc private func statusItemClicked() {
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard popover?.isShown != true else { return }
        cancelPendingClose()
        cancelPendingOpen()

        let panel = GhostPanelView(store: store)
            .frame(minWidth: 420, idealWidth: 460, maxWidth: 560, minHeight: 520, idealHeight: 640, maxHeight: 760)

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        let hosting = NSHostingController(rootView: panel)
        pop.contentViewController = hosting
        pop.contentSize = NSSize(width: 460, height: 640)
        pop.delegate = self

        guard let button = statusItem?.button else { return }
        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        DispatchQueue.main.async { [weak self] in
            self?.attachPopoverTracking()
        }

        self.popover = pop
    }

    private func closePopover() {
        popover?.performClose(nil)
    }

    private func attachPopoverTracking() {
        guard let contentView = popover?.contentViewController?.view else { return }
        let trackingArea = NSTrackingArea(
            rect: contentView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView.addTrackingArea(trackingArea)
    }

    private func cancelPendingClose() {
        hoverCloseWorkItem?.cancel()
        hoverCloseWorkItem = nil
    }

    private func cancelPendingOpen() {
        hoverOpenWorkItem?.cancel()
        hoverOpenWorkItem = nil
    }

    private func scheduleClose() {
        cancelPendingClose()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if !self.isMouseOverStatusItemOrPopover {
                self.closePopover()
            }
        }
        hoverCloseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay, execute: work)
    }

    private var isMouseOverStatusItemOrPopover: Bool {
        let mouseLocation = NSEvent.mouseLocation
        if let button = statusItem?.button, button.window != nil {
            let buttonFrame = button.window!.convertToScreen(button.frame)
            if buttonFrame.contains(mouseLocation) {
                return true
            }
        }
        if let pop = popover, pop.isShown,
           let contentView = pop.contentViewController?.view,
           let window = contentView.window {
            let popFrame = window.frame
            if popFrame.contains(mouseLocation) {
                return true
            }
        }
        return false
    }

    // MARK: - Hover events (called via tracking area owner)

    override func mouseEntered(with event: NSEvent) {
        cancelPendingClose()
        cancelPendingOpen()

        let work = DispatchWorkItem { [weak self] in
            guard let self, self.popover?.isShown != true else { return }
            self.showPopover()
        }
        hoverOpenWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + openDelay, execute: work)
    }

    override func mouseExited(with event: NSEvent) {
        scheduleClose()
    }
}

extension GhostStatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        popover = nil
    }
}