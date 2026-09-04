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
        XCTAssertEqual(window.contentLayoutRect.size.width, 720, accuracy: 1)
        XCTAssertEqual(window.contentLayoutRect.size.height, 222, accuracy: 1)
        XCTAssertEqual(window.minSize, window.maxSize)
    }

    func testLinkControlIsCenteredInTheBottomFooter() {
        let controller = PlayerViewController()
        let window = AppWindowFactory.make(contentViewController: controller)
        window.contentView?.layoutSubtreeIfNeeded()

        let linkFrame = controller.linkButton.convert(controller.linkButton.bounds, to: controller.view)
        XCTAssertEqual(linkFrame.midX, controller.view.bounds.midX, accuracy: 2)
        XCTAssertLessThan(linkFrame.midY, 55)
        XCTAssertGreaterThanOrEqual(linkFrame.minY, controller.view.bounds.minY)
        XCTAssertLessThanOrEqual(linkFrame.maxY, controller.view.bounds.maxY)
    }

    func testUsesEnglishActionsAndExposesEveryTheme() {
        let controller = PlayerViewController()
        controller.loadView()

        XCTAssertEqual(controller.urlField.placeholderString, "Paste a YouTube URL")
        XCTAssertEqual(controller.linkButton.title, "Link")
        XCTAssertEqual(controller.youtubeButton.accessibilityLabel(), "Open YouTube in Chrome")
        XCTAssertEqual(controller.pasteButton.title, "Paste")
        XCTAssertEqual(controller.fetchButton.title, "Fetch Again")
        XCTAssertEqual(controller.playButton.title, "Play")
        XCTAssertTrue(controller.sourceCardIsHidden)
        XCTAssertEqual(controller.themePopup.itemTitles,
                       ["Aqua", "Electric Blue", "Violet", "Coral", "Acid Green", "Amber"])
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

        controller.applyTheme(.amber)
        XCTAssertEqual(controller.view.appearance?.name, .darkAqua)
    }
}
