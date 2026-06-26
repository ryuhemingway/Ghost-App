import SwiftUI
import AppKit

extension Color {
    static func ghostDynamic(light: Color, dark: Color) -> Color {
        let lightNS = NSColor(light)
        let darkNS = NSColor(dark)
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkNS : lightNS
        })
    }
}

enum GhostAppearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon.stars"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct PanelWindowConfigurator: NSViewRepresentable {
    private static let screenInset: CGFloat = 24

    let appearance: NSAppearance?
    let preferredSize: CGSize
    let minimumSize: CGSize
    let sizeMode: GhostPanelSizeMode
    @Binding var fittedSize: CGSize?

    func makeNSView(context: Context) -> NSView { NSView() }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.styleMask.remove(.resizable)
            window.isMovableByWindowBackground = true
            window.hasShadow = true
            window.appearance = appearance

            let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame
            let fittedMinimumSize = fittedContentSize(
                minimumSize,
                minimumSize: CGSize(width: 1, height: 1),
                visibleFrame: visibleFrame,
                window: window
            )
            let fittedPreferredSize = fittedPreferredContentSize(
                preferredSize,
                mode: sizeMode,
                minimumSize: fittedMinimumSize,
                visibleFrame: visibleFrame,
                window: window
            )

            window.contentMinSize = fittedMinimumSize
            window.minSize = window.frameRect(
                forContentRect: NSRect(origin: .zero, size: fittedMinimumSize)
            ).size

            if fittedSize != fittedPreferredSize {
                fittedSize = fittedPreferredSize
            }

            let visibleFrameChanged: Bool = {
                guard let visibleFrame else { return context.coordinator.lastAppliedVisibleFrame != nil }
                guard let last = context.coordinator.lastAppliedVisibleFrame else { return true }
                return !last.equalTo(visibleFrame)
            }()

            let shouldApplyPreset = context.coordinator.lastAppliedSize != fittedPreferredSize
                || context.coordinator.lastAppliedMode != sizeMode
                || visibleFrameChanged

            if shouldApplyPreset {
                applyPreferredSize(
                    fittedPreferredSize,
                    mode: sizeMode,
                    visibleFrame: visibleFrame,
                    to: window
                )
                context.coordinator.lastAppliedSize = fittedPreferredSize
                context.coordinator.lastAppliedMode = sizeMode
                context.coordinator.lastAppliedVisibleFrame = visibleFrame
            }

            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            window.contentView?.layer?.cornerRadius = GhostRadii.window
            window.contentView?.layer?.cornerCurve = .continuous
            window.contentView?.layer?.masksToBounds = true
            window.contentView?.superview?.wantsLayer = true
            window.contentView?.superview?.layer?.backgroundColor = NSColor.clear.cgColor
            window.contentView?.superview?.layer?.cornerRadius = GhostRadii.window
            window.contentView?.superview?.layer?.cornerCurve = .continuous
            window.contentView?.superview?.layer?.masksToBounds = true
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            NSApp.appearance = appearance
        }
    }

    private func fittedPreferredContentSize(
        _ size: CGSize,
        mode: GhostPanelSizeMode,
        minimumSize: CGSize,
        visibleFrame: NSRect?,
        window: NSWindow
    ) -> CGSize {
        guard mode == .full,
              let visibleFrame
        else {
            return fittedContentSize(
                size,
                minimumSize: minimumSize,
                visibleFrame: visibleFrame,
                window: window
            )
        }

        let frame = fullPanelFrame(in: visibleFrame)
        let contentRect = window.contentRect(forFrameRect: frame)
        return CGSize(
            width: max(minimumSize.width, contentRect.width),
            height: max(minimumSize.height, contentRect.height)
        )
    }

    private func fittedContentSize(
        _ size: CGSize,
        minimumSize: CGSize,
        visibleFrame: NSRect?,
        window: NSWindow
    ) -> CGSize {
        guard let visibleFrame else { return size }

        let maximumSize = maximumContentSize(visibleFrame: visibleFrame, window: window)
        return CGSize(
            width: min(max(size.width, minimumSize.width), maximumSize.width),
            height: min(max(size.height, minimumSize.height), maximumSize.height)
        )
    }

    private func fullPanelFrame(in visibleFrame: NSRect) -> NSRect {
        let insetFrame = visibleFrame.insetBy(dx: Self.screenInset, dy: Self.screenInset)

        guard insetFrame.width > 240, insetFrame.height > 240 else {
            return visibleFrame
        }

        return insetFrame
    }

    private func maximumContentSize(visibleFrame: NSRect, window: NSWindow) -> CGSize {
        let availableFrame = fullPanelFrame(in: visibleFrame)
        let contentRect = window.contentRect(forFrameRect: availableFrame)

        return CGSize(
            width: max(1, contentRect.width),
            height: max(1, contentRect.height)
        )
    }

    private func applyPreferredSize(
        _ size: CGSize,
        mode: GhostPanelSizeMode,
        visibleFrame: NSRect?,
        to window: NSWindow
    ) {
        guard let visibleFrame else {
            window.setContentSize(size)
            return
        }

        if mode == .full {
            let frame = fullPanelFrame(in: visibleFrame)
            window.setFrame(frame, display: true, animate: false)
            return
        }

        let frameSize = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: size)
        ).size
        var frame = NSRect(
            origin: targetOrigin(
                for: frameSize,
                mode: mode,
                currentFrame: window.frame,
                visibleFrame: visibleFrame
            ),
            size: frameSize
        )

        frame = clampedFrame(frame, to: visibleFrame)
        window.setFrame(frame, display: true, animate: true)
    }

    private func targetOrigin(
        for frameSize: CGSize,
        mode: GhostPanelSizeMode,
        currentFrame: NSRect,
        visibleFrame: NSRect
    ) -> CGPoint {
        guard mode != .full else {
            return CGPoint(
                x: visibleFrame.midX - frameSize.width / 2,
                y: visibleFrame.midY - frameSize.height / 2
            )
        }

        let anchorX = currentFrame.width > 1 ? currentFrame.maxX : visibleFrame.maxX
        let anchorY = currentFrame.height > 1 ? currentFrame.maxY : visibleFrame.maxY

        return CGPoint(x: anchorX - frameSize.width, y: anchorY - frameSize.height)
    }

    private func clampedFrame(_ frame: NSRect, to visibleFrame: NSRect) -> NSRect {
        var clamped = frame

        if clamped.width > visibleFrame.width {
            clamped.size.width = visibleFrame.width
        }
        if clamped.height > visibleFrame.height {
            clamped.size.height = visibleFrame.height
        }

        clamped.origin.x = min(
            max(clamped.origin.x, visibleFrame.minX),
            visibleFrame.maxX - clamped.width
        )
        clamped.origin.y = min(
            max(clamped.origin.y, visibleFrame.minY),
            visibleFrame.maxY - clamped.height
        )

        return clamped
    }

    final class Coordinator {
        var lastAppliedSize: CGSize?
        var lastAppliedMode: GhostPanelSizeMode?
        var lastAppliedVisibleFrame: NSRect?
    }
}

struct RainbowProcessing: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let spectrum: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .red]

    func body(content: Content) -> some View {
        if active {
            if reduceMotion {
                content.overlay {
                    LinearGradient(colors: Self.spectrum, startPoint: .leading, endPoint: .trailing)
                        .mask(content)
                }
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let deg = (t.truncatingRemainder(dividingBy: 3) / 3) * 360
                    content.overlay {
                        LinearGradient(colors: Self.spectrum, startPoint: .leading, endPoint: .trailing)
                            .hueRotation(.degrees(deg))
                            .mask(content)
                    }
                }
            }
        } else {
            content
        }
    }
}

struct FastRainbowPulse: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if active {
            if reduceMotion {
                content
                    .foregroundStyle(
                        LinearGradient(colors: RainbowProcessing.spectrum, startPoint: .leading, endPoint: .trailing)
                    )
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let deg = (t.truncatingRemainder(dividingBy: 1.1) / 1.1) * 360
                    let opacity = 0.42 + 0.58 * abs(sin(t * 5.2))
                    content
                        .opacity(opacity)
                        .overlay {
                            LinearGradient(colors: RainbowProcessing.spectrum, startPoint: .leading, endPoint: .trailing)
                                .hueRotation(.degrees(deg))
                                .mask(content)
                                .opacity(opacity)
                        }
                }
            }
        } else {
            content
        }
    }
}

extension View {
    func rainbowProcessing(active: Bool) -> some View {
        modifier(RainbowProcessing(active: active))
    }

    func fastRainbowPulse(active: Bool) -> some View {
        modifier(FastRainbowPulse(active: active))
    }
}
