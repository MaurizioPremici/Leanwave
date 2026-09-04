import Foundation

public struct RGBAColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public var components: [Double] { [red, green, blue, alpha] }

    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct ThemePalette: Equatable, Sendable {
    public let background: RGBAColor
    public let surface: RGBAColor
    public let primaryText: RGBAColor
    public let secondaryText: RGBAColor
    public let accent: RGBAColor
    public let separator: RGBAColor
}

public enum LeanwaveTheme: String, CaseIterable, Sendable {
    case carbon, arctic, sunset, forest, violet, paper

    public var displayName: String { rawValue.capitalized }

    public var palette: ThemePalette {
        switch self {
        case .carbon:
            ThemePalette(background: .init(0.055, 0.063, 0.078), surface: .init(0.10, 0.11, 0.14), primaryText: .init(0.95, 0.96, 0.98), secondaryText: .init(0.60, 0.64, 0.70), accent: .init(0.27, 0.85, 0.72), separator: .init(0.18, 0.20, 0.24))
        case .arctic:
            ThemePalette(background: .init(0.91, 0.96, 0.98), surface: .init(0.98, 1.0, 1.0), primaryText: .init(0.08, 0.16, 0.20), secondaryText: .init(0.34, 0.46, 0.52), accent: .init(0.06, 0.55, 0.72), separator: .init(0.78, 0.87, 0.91))
        case .sunset:
            ThemePalette(background: .init(0.15, 0.075, 0.09), surface: .init(0.22, 0.105, 0.12), primaryText: .init(1.0, 0.94, 0.90), secondaryText: .init(0.80, 0.62, 0.58), accent: .init(1.0, 0.42, 0.25), separator: .init(0.34, 0.16, 0.18))
        case .forest:
            ThemePalette(background: .init(0.055, 0.105, 0.085), surface: .init(0.085, 0.16, 0.125), primaryText: .init(0.92, 0.98, 0.93), secondaryText: .init(0.58, 0.72, 0.62), accent: .init(0.36, 0.82, 0.48), separator: .init(0.15, 0.26, 0.19))
        case .violet:
            ThemePalette(background: .init(0.075, 0.055, 0.14), surface: .init(0.13, 0.09, 0.22), primaryText: .init(0.96, 0.93, 1.0), secondaryText: .init(0.67, 0.59, 0.80), accent: .init(0.65, 0.42, 1.0), separator: .init(0.22, 0.15, 0.34))
        case .paper:
            ThemePalette(background: .init(0.96, 0.95, 0.91), surface: .init(1.0, 0.995, 0.97), primaryText: .init(0.12, 0.115, 0.10), secondaryText: .init(0.43, 0.41, 0.36), accent: .init(0.13, 0.38, 0.76), separator: .init(0.82, 0.80, 0.74))
        }
    }
}
