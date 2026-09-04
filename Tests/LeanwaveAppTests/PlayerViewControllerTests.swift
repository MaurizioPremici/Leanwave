import AppKit
import XCTest
@testable import LeanwaveApp

@MainActor
final class PlayerViewControllerTests: XCTestCase {
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
}
