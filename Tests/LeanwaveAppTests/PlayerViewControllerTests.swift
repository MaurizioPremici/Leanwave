import AppKit
import LeanwaveCore
import XCTest
@testable import LeanwaveApp

@MainActor
final class PlayerViewControllerTests: XCTestCase {
    func testCustomWindowControlsUseExpectedSymbolsAndLabels() {
        let controller = PlayerViewController()
        controller.loadView()

        XCTAssertEqual(controller.minimizeButton.title, "−")
        XCTAssertEqual(controller.minimizeButton.accessibilityLabel(), "Minimize window")
        XCTAssertEqual(controller.closeButton.title, "×")
        XCTAssertEqual(controller.closeButton.accessibilityLabel(), "Close window")
    }

    func testAppWindowFloatsAndKeepsNativeWindowActionsAvailable() {
        let controller = PlayerViewController()
        let window = AppWindowFactory.make(contentViewController: controller)

        XCTAssertEqual(window.level, .floating)
        XCTAssertTrue(window.styleMask.contains(.closable))
        XCTAssertTrue(window.styleMask.contains(.miniaturizable))
        XCTAssertTrue(window.standardWindowButton(.closeButton)?.isHidden == true)
        XCTAssertTrue(window.standardWindowButton(.miniaturizeButton)?.isHidden == true)
    }

    func testUsesEnglishActionsAndExposesEveryTheme() {
        let controller = PlayerViewController()
        controller.loadView()

        XCTAssertEqual(controller.urlField.placeholderString, "Paste a YouTube URL")
        XCTAssertEqual(controller.pasteButton.title, "Paste")
        XCTAssertEqual(controller.fetchButton.title, "Fetch Again")
        XCTAssertEqual(controller.playButton.title, "Play")
        XCTAssertEqual(
            controller.themePopup.itemTitles,
            ["Carbon", "Arctic", "Sunset", "Forest", "Violet", "Paper"]
        )
    }

    func testTransportControlsHaveAccessibleEnglishLabels() {
        let controller = PlayerViewController()
        controller.loadView()

        XCTAssertEqual(controller.backButton.accessibilityLabel(), "Back 15 seconds")
        XCTAssertEqual(controller.playPauseButton.accessibilityLabel(), "Play or pause")
        XCTAssertEqual(controller.forwardButton.accessibilityLabel(), "Forward 15 seconds")
        XCTAssertEqual(controller.stopButton.accessibilityLabel(), "Stop")
        XCTAssertEqual(controller.muteButton.accessibilityLabel(), "Mute or unmute")
    }

    func testLightAndDarkThemesSetMatchingControlAppearance() {
        let controller = PlayerViewController()
        controller.loadView()

        controller.applyTheme(.paper)
        XCTAssertEqual(controller.view.appearance?.name, .aqua)
        controller.applyTheme(.carbon)
        XCTAssertEqual(controller.view.appearance?.name, .darkAqua)
    }
}
