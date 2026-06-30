import SwiftUI
import AppKit

struct TransparentWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.hasShadow = true
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
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        v.isEmphasized = true
        v.alphaValue = 1.0
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
        v.state = .active
        v.isEmphasized = true
        v.alphaValue = 1.0
    }
}
