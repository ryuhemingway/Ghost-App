import SwiftUI

enum GhostTerminalTheme: String, CaseIterable, Identifiable, Sendable {
    case ghost
    case classic
    case matrix
    case solarized
    case midnight
    case rose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ghost: "Ghost"
        case .classic: "Classic"
        case .matrix: "Matrix"
        case .solarized: "Solarized"
        case .midnight: "Midnight"
        case .rose: "Rose"
        }
    }

    var subtitle: String {
        switch self {
        case .ghost: "Slate, violet, cyan"
        case .classic: "Black, green, amber"
        case .matrix: "Black, phosphor green"
        case .solarized: "Ink, teal, gold"
        case .midnight: "Deep navy, blue, mint"
        case .rose: "Warm charcoal, rose, cream"
        }
    }

    static var saved: GhostTerminalTheme {
        GhostTerminalTheme(
            rawValue: UserDefaults.standard.string(forKey: "ghostTerminalTheme") ?? GhostTerminalTheme.ghost.rawValue
        ) ?? .ghost
    }

    var appBackground: Color {
        switch self {
        case .ghost: Color(red: 0.095, green: 0.115, blue: 0.145)
        case .classic: Color(red: 0.015, green: 0.016, blue: 0.014)
        case .matrix: Color(red: 0.018, green: 0.030, blue: 0.018)
        case .solarized: Color(red: 0.000, green: 0.169, blue: 0.212)
        case .midnight: Color(red: 0.030, green: 0.055, blue: 0.110)
        case .rose: Color(red: 0.125, green: 0.090, blue: 0.100)
        }
    }

    var transcriptBackground: Color {
        switch self {
        case .ghost: Color(red: 0.125, green: 0.150, blue: 0.185)
        case .classic: Color(red: 0.025, green: 0.026, blue: 0.023)
        case .matrix: Color(red: 0.025, green: 0.045, blue: 0.025)
        case .solarized: Color(red: 0.027, green: 0.212, blue: 0.259)
        case .midnight: Color(red: 0.045, green: 0.075, blue: 0.145)
        case .rose: Color(red: 0.160, green: 0.115, blue: 0.125)
        }
    }

    var sidebarBackground: Color {
        switch self {
        case .ghost: Color(red: 0.100, green: 0.125, blue: 0.155)
        case .classic: Color(red: 0.020, green: 0.022, blue: 0.020)
        case .matrix: Color(red: 0.020, green: 0.040, blue: 0.020)
        case .solarized: Color(red: 0.020, green: 0.185, blue: 0.230)
        case .midnight: Color(red: 0.035, green: 0.065, blue: 0.130)
        case .rose: Color(red: 0.140, green: 0.100, blue: 0.112)
        }
    }

    var promptBackground: Color {
        switch self {
        case .ghost: Color(red: 0.145, green: 0.170, blue: 0.205)
        case .classic: Color(red: 0.040, green: 0.042, blue: 0.037)
        case .matrix: Color(red: 0.035, green: 0.070, blue: 0.035)
        case .solarized: Color(red: 0.035, green: 0.245, blue: 0.290)
        case .midnight: Color(red: 0.060, green: 0.095, blue: 0.175)
        case .rose: Color(red: 0.190, green: 0.135, blue: 0.145)
        }
    }

    var border: Color {
        switch self {
        case .ghost: Color.white.opacity(0.055)
        case .classic: Color.green.opacity(0.16)
        case .matrix: Color.green.opacity(0.20)
        case .solarized: Color(red: 0.513, green: 0.580, blue: 0.588).opacity(0.20)
        case .midnight: Color(red: 0.320, green: 0.520, blue: 0.850).opacity(0.18)
        case .rose: Color(red: 1.000, green: 0.675, blue: 0.720).opacity(0.18)
        }
    }

    var text: Color {
        switch self {
        case .ghost: Color(red: 0.72, green: 0.76, blue: 0.82)
        case .classic: Color(red: 0.74, green: 0.88, blue: 0.66)
        case .matrix: Color(red: 0.58, green: 0.98, blue: 0.56)
        case .solarized: Color(red: 0.576, green: 0.631, blue: 0.631)
        case .midnight: Color(red: 0.760, green: 0.840, blue: 0.940)
        case .rose: Color(red: 0.930, green: 0.850, blue: 0.830)
        }
    }

    var muted: Color {
        switch self {
        case .ghost: Color(red: 0.44, green: 0.49, blue: 0.58)
        case .classic: Color(red: 0.44, green: 0.62, blue: 0.40)
        case .matrix: Color(red: 0.28, green: 0.62, blue: 0.30)
        case .solarized: Color(red: 0.396, green: 0.482, blue: 0.514)
        case .midnight: Color(red: 0.450, green: 0.560, blue: 0.700)
        case .rose: Color(red: 0.650, green: 0.530, blue: 0.540)
        }
    }

    var faint: Color {
        switch self {
        case .ghost: Color(red: 0.32, green: 0.37, blue: 0.45)
        case .classic: Color(red: 0.30, green: 0.42, blue: 0.28)
        case .matrix: Color(red: 0.18, green: 0.42, blue: 0.20)
        case .solarized: Color(red: 0.345, green: 0.431, blue: 0.459)
        case .midnight: Color(red: 0.300, green: 0.390, blue: 0.520)
        case .rose: Color(red: 0.480, green: 0.380, blue: 0.400)
        }
    }

    var orange: Color {
        switch self {
        case .ghost: Color(red: 1.00, green: 0.61, blue: 0.28)
        case .classic: Color(red: 1.00, green: 0.72, blue: 0.28)
        case .matrix: Color(red: 0.75, green: 1.00, blue: 0.45)
        case .solarized: Color(red: 0.796, green: 0.294, blue: 0.086)
        case .midnight: Color(red: 0.980, green: 0.650, blue: 0.320)
        case .rose: Color(red: 1.000, green: 0.610, blue: 0.520)
        }
    }

    var green: Color {
        switch self {
        case .ghost: Color(red: 0.55, green: 0.86, blue: 0.43)
        case .classic: Color(red: 0.58, green: 0.95, blue: 0.45)
        case .matrix: Color(red: 0.42, green: 1.00, blue: 0.38)
        case .solarized: Color(red: 0.522, green: 0.600, blue: 0.000)
        case .midnight: Color(red: 0.480, green: 0.950, blue: 0.760)
        case .rose: Color(red: 0.620, green: 0.840, blue: 0.650)
        }
    }

    var yellow: Color {
        switch self {
        case .ghost: Color(red: 0.95, green: 0.74, blue: 0.34)
        case .classic: Color(red: 1.00, green: 0.82, blue: 0.32)
        case .matrix: Color(red: 0.82, green: 1.00, blue: 0.45)
        case .solarized: Color(red: 0.710, green: 0.537, blue: 0.000)
        case .midnight: Color(red: 1.000, green: 0.820, blue: 0.420)
        case .rose: Color(red: 0.960, green: 0.760, blue: 0.480)
        }
    }

    var cyan: Color {
        switch self {
        case .ghost: Color(red: 0.55, green: 0.75, blue: 0.95)
        case .classic: Color(red: 0.58, green: 0.86, blue: 0.95)
        case .matrix: Color(red: 0.48, green: 1.00, blue: 0.75)
        case .solarized: Color(red: 0.165, green: 0.631, blue: 0.596)
        case .midnight: Color(red: 0.460, green: 0.780, blue: 1.000)
        case .rose: Color(red: 0.740, green: 0.860, blue: 0.900)
        }
    }

    var purple: Color {
        switch self {
        case .ghost: Color(red: 0.86, green: 0.42, blue: 1.0)
        case .classic: Color(red: 0.78, green: 0.62, blue: 1.0)
        case .matrix: Color(red: 0.54, green: 0.90, blue: 0.50)
        case .solarized: Color(red: 0.424, green: 0.443, blue: 0.769)
        case .midnight: Color(red: 0.620, green: 0.650, blue: 1.000)
        case .rose: Color(red: 1.000, green: 0.520, blue: 0.700)
        }
    }
}
