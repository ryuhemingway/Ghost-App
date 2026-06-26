import SwiftUI
import AppKit

enum GhostColors {
    static let deepBlack = Color.ghostDynamic(
        light: Color(red: 0.96, green: 0.95, blue: 0.98), dark: .black)
    static let voidColor = Color.ghostDynamic(
        light: Color(red: 0.91, green: 0.90, blue: 0.96),
        dark: Color(red: 0.055, green: 0.018, blue: 0.10))

    static let royalViolet = Color.ghostDynamic(
        light: Color(red: 0.42, green: 0.18, blue: 0.86),
        dark: Color(red: 0.45, green: 0.20, blue: 0.95))
    static let mutedViolet = Color.ghostDynamic(
        light: Color(red: 0.52, green: 0.40, blue: 0.84),
        dark: Color(red: 0.30, green: 0.12, blue: 0.65))

    static let platinum = Color.ghostDynamic(
        light: Color(red: 0.13, green: 0.11, blue: 0.20),
        dark: Color.white.opacity(0.92))
    static let mutedPlatinum = Color.ghostDynamic(
        light: Color(red: 0.13, green: 0.11, blue: 0.20).opacity(0.62),
        dark: Color.white.opacity(0.58))
    static let faintPlatinum = Color.ghostDynamic(
        light: Color(red: 0.13, green: 0.11, blue: 0.20).opacity(0.24),
        dark: Color.white.opacity(0.22))
    static let labelPlatinum = Color.ghostDynamic(
        light: Color(red: 0.13, green: 0.11, blue: 0.20).opacity(0.70),
        dark: Color.white.opacity(0.62))

    static let champagne = Color.ghostDynamic(
        light: Color(red: 0.74, green: 0.55, blue: 0.18),
        dark: Color(red: 1.0, green: 0.84, blue: 0.55))

    static let deepIndigo = Color.ghostDynamic(
        light: Color(red: 0.72, green: 0.70, blue: 0.86),
        dark: Color(red: 0.08, green: 0.03, blue: 0.18))

    static let glassBorder = Color.ghostDynamic(
        light: Color.black.opacity(0.10), dark: Color.white.opacity(0.06))
    static let glassActiveBorder = Color.ghostDynamic(
        light: Color.black.opacity(0.16), dark: Color.white.opacity(0.10))
    static let glassFill = Color.ghostDynamic(
        light: Color.black.opacity(0.04), dark: Color.white.opacity(0.035))
    static let glassActiveFill = Color.ghostDynamic(
        light: Color(red: 0.42, green: 0.18, blue: 0.86).opacity(0.10),
        dark: Color.white.opacity(0.08))

    static let windowEdge = Color.ghostDynamic(
        light: Color.black.opacity(0.12), dark: Color.white.opacity(0.0))

    static let barFill = Color.ghostDynamic(
        light: Color.white.opacity(0.55), dark: Color.black.opacity(0.5))
    static let drawerFill = Color.ghostDynamic(
        light: Color.white.opacity(0.78), dark: Color.black.opacity(0.85))
    static let popoverFill = Color.ghostDynamic(
        light: Color.white.opacity(0.92), dark: Color.black.opacity(0.95))
    static let bubbleFill = Color.ghostDynamic(
        light: Color.white.opacity(0.66), dark: Color.black.opacity(0.55))
}

enum GhostRadii {
    static let pill: CGFloat = 10
    static let card: CGFloat = 14
    static let small: CGFloat = 8
    static let mini: CGFloat = 6
    static let window: CGFloat = 20
}

enum GhostSpacing {
    static let compact4: CGFloat = 4
    static let compact6: CGFloat = 6
    static let standard: CGFloat = 8
    static let relaxed: CGFloat = 10
    static let wide: CGFloat = 12
    static let generous: CGFloat = 16
}

enum GhostTypography {
    static func display(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let preferred: [String] = [
            "Didot",
            "Bodoni 72",
            "Bodoni 72 Oldstyle",
            "Bodoni SvtyTwo ITC TT",
            "NewYork-Regular",
            "NewYork-Medium",
            "NewYork-Bold",
            "NewYork-Semibold",
            "Source Serif Pro",
        ]

        for name in preferred {
            if let nsFont = NSFont(name: name, size: size) {
                return .custom(nsFont.fontName, size: size)
            }
        }

        return GhostFonts.sourceSerif(size: size, weight: weight)
    }

    static func displayBold(size: CGFloat) -> Font {
        let preferred: [String] = [
            "Didot-Bold",
            "Bodoni 72 Bold",
            "Bodoni SvtyTwo ITC TT-Bold",
            "NewYork-Bold",
            "Bodoni 72",
            "Didot",
            "NewYork-Semibold",
            "Source Serif Pro Bold",
            "Source Serif Pro Semibold",
            "Source Serif Pro",
        ]

        for name in preferred {
            if let nsFont = NSFont(name: name, size: size) {
                return .custom(nsFont.fontName, size: size)
            }
        }

        return GhostFonts.sourceSerif(size: size, weight: .bold)
    }

    static func glassGradientTitle(_ text: String, size: CGFloat, tracking: CGFloat = -1.0) -> some View {
        Text(text)
            .font(display(size: size, weight: .regular))
            .tracking(tracking)
            .foregroundStyle(
                LinearGradient(
                    colors: [GhostColors.platinum, GhostColors.platinum.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: GhostColors.royalViolet.opacity(0.25), radius: 16, x: 0, y: 0)
    }

    static func glassGradientDisplay(_ text: String, size: CGFloat, tracking: CGFloat = -1.0) -> some View {
        Text(text)
            .font(displayBold(size: size))
            .tracking(tracking)
            .foregroundStyle(
                LinearGradient(
                    colors: [GhostColors.platinum, GhostColors.platinum, GhostColors.mutedPlatinum],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: GhostColors.royalViolet.opacity(0.2), radius: 12, x: 0, y: 0)
    }
}

struct GhostGlassModifier: ViewModifier {
    var isActive: Bool = false
    var cornerRadius: CGFloat = GhostRadii.card

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isActive ? GhostColors.glassActiveFill : GhostColors.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isActive ? GhostColors.glassActiveBorder : GhostColors.glassBorder,
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func ghostGlass(cornerRadius: CGFloat = GhostRadii.card, isActive: Bool = false) -> some View {
        modifier(GhostGlassModifier(isActive: isActive, cornerRadius: cornerRadius))
    }

    func ghostCard() -> some View {
        modifier(GhostGlassModifier(isActive: false, cornerRadius: GhostRadii.card))
    }
}

enum GhostShadow {
    static let card = Color.purple.opacity(0.08)
    static let elevated = Color.purple.opacity(0.12)
    static let glow = GhostColors.royalViolet.opacity(0.25)
}

extension View {
    func ghostCardShadow() -> some View {
        shadow(
            color: GhostShadow.card,
            radius: 16,
            y: 6
        )
    }
}

struct PressableButtonStyle: ButtonStyle {
    var reduceMotion: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

enum GhostMenuBarIcon {
    static func make(size: CGFloat = 22) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.isTemplate = true

        image.lockFocus()
        defer { image.unlockFocus() }

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            return image
        }

        ctx.saveGState()
        defer { ctx.restoreGState() }

        ctx.translateBy(x: 0, y: size)
        ctx.scaleBy(x: 1, y: -1)

        let w = size
        let h = size

        let compound = CGMutablePath()
        compound.addPath(menuGhostBodyPath(width: w, height: h))

        compound.addEllipse(
            in: CGRect(
                x: w * 0.39,
                y: h * 0.34,
                width: w * 0.075,
                height: h * 0.17
            )
        )
        compound.addEllipse(
            in: CGRect(
                x: w * 0.57,
                y: h * 0.34,
                width: w * 0.075,
                height: h * 0.17
            )
        )

        ctx.addPath(compound)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.drawPath(using: .eoFill)

        return image
    }

    private static func menuGhostBodyPath(width w: CGFloat, height h: CGFloat) -> CGPath {
        let path = CGMutablePath()

        path.move(to: CGPoint(x: w * 0.55, y: h * 0.05))

        path.addCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.35),
            control1: CGPoint(x: w * 0.34, y: h * 0.04),
            control2: CGPoint(x: w * 0.18, y: h * 0.13)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.07, y: h * 0.58),
            control1: CGPoint(x: w * 0.16, y: h * 0.44),
            control2: CGPoint(x: w * 0.10, y: h * 0.49)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.29, y: h * 0.58),
            control1: CGPoint(x: w * 0.00, y: h * 0.76),
            control2: CGPoint(x: w * 0.20, y: h * 0.70)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.23, y: h * 0.78),
            control1: CGPoint(x: w * 0.28, y: h * 0.66),
            control2: CGPoint(x: w * 0.22, y: h * 0.72)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.36, y: h * 0.84),
            control1: CGPoint(x: w * 0.23, y: h * 0.86),
            control2: CGPoint(x: w * 0.31, y: h * 0.85)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.26, y: h * 0.96),
            control1: CGPoint(x: w * 0.31, y: h * 0.90),
            control2: CGPoint(x: w * 0.24, y: h * 0.92)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.58, y: h * 0.91),
            control1: CGPoint(x: w * 0.36, y: h * 1.02),
            control2: CGPoint(x: w * 0.51, y: h * 0.99)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.80, y: h * 0.62),
            control1: CGPoint(x: w * 0.75, y: h * 0.82),
            control2: CGPoint(x: w * 0.84, y: h * 0.71)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.95, y: h * 0.66),
            control1: CGPoint(x: w * 0.87, y: h * 0.67),
            control2: CGPoint(x: w * 0.94, y: h * 0.75)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.88, y: h * 0.44),
            control1: CGPoint(x: w * 0.99, y: h * 0.55),
            control2: CGPoint(x: w * 0.91, y: h * 0.49)
        )

        path.addCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.05),
            control1: CGPoint(x: w * 0.87, y: h * 0.17),
            control2: CGPoint(x: w * 0.75, y: h * 0.04)
        )

        path.closeSubpath()
        return path
    }
}
