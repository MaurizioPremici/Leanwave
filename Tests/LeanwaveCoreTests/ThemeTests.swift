import XCTest
@testable import LeanwaveCore

final class ThemeTests: XCTestCase {
    func testProvidesExactlySixStableThemes() {
        XCTAssertEqual(
            LeanwaveTheme.allCases.map(\.rawValue),
            ["carbon", "arctic", "sunset", "forest", "violet", "paper"]
        )
    }

    func testEveryThemeProvidesACompletePalette() {
        for theme in LeanwaveTheme.allCases {
            let palette = theme.palette
            XCTAssertEqual(palette.background.components.count, 4)
            XCTAssertEqual(palette.surface.components.count, 4)
            XCTAssertEqual(palette.primaryText.components.count, 4)
            XCTAssertEqual(palette.secondaryText.components.count, 4)
            XCTAssertEqual(palette.accent.components.count, 4)
            XCTAssertEqual(palette.separator.components.count, 4)
        }
    }
}
