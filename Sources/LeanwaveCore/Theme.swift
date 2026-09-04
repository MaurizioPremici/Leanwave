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
    case aqua, electricBlue, violet, coral, acidGreen, amber

    public var displayName: String {
        switch self {
        case .electricBlue: "Electric Blue"
        case .acidGreen: "Acid Green"
        default: rawValue.capitalized
        }
    }

    public var palette: ThemePalette {
        let accent: RGBAColor = switch self {
        case .aqua: .init(0.30, 0.91, 0.82)
        case .electricBlue: .init(0.20, 0.55, 1.0)
        case .violet: .init(0.68, 0.43, 1.0)
        case .coral: .init(1.0, 0.39, 0.35)
        case .acidGreen: .init(0.60, 0.96, 0.22)
        case .amber: .init(1.0, 0.68, 0.16)
        }
        return ThemePalette(
            background: .init(0.035, 0.041, 0.052),
            surface: .init(0.075, 0.085, 0.105),
            primaryText: .init(0.96, 0.97, 0.99),
            secondaryText: .init(0.54, 0.58, 0.65),
            accent: accent,
            separator: .init(0.15, 0.17, 0.21)
        )
    }
}
