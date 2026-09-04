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
        XCTAssertEqual(window.contentLayoutRect.size.width, 520, accuracy: 1)
        XCTAssertEqual(window.contentLayoutRect.size.height, 182, accuracy: 1)
        XCTAssertEqual(window.minSize, window.maxSize)
        XCTAssertEqual(window.contentMinSize, NSSize(width: 520, height: 210))
        XCTAssertEqual(window.contentMaxSize, NSSize(width: 520, height: 210))
    }

    func testLayoutDoesNotContainNegativeFixedDimensions() {
        let controller = PlayerViewController()
        controller.loadView()

        let invalidConstraints = allConstraints(in: controller.view).filter {
            ($0.firstAttribute == .width || $0.firstAttribute == .height)
                && $0.relation == .equal
                && $0.secondItem == nil
                && $0.constant < 0
        }

        XCTAssertTrue(invalidConstraints.isEmpty)
    }

    func testWindowSizeIsIdenticalForIdleAndLoadedChromeChoiceStates() {
        let controller = PlayerViewController()
        let window = AppWindowFactory.make(contentViewController: controller)
        window.contentView?.layoutSubtreeIfNeeded()
        let idleSize = window.contentView?.bounds.size

        var loaded = PlayerState()
        loaded.phase = .playing
        loaded.title = "A deliberately long YouTube title that must truncate inside the compact player"
        loaded.duration = 3 * 60 * 60 + 18 * 60 + 53
        loaded.isPaused = false
        loaded.closeChoicePending = true
        controller.render(loaded)
        window.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(idleSize, NSSize(width: 520, height: 210))
        XCTAssertEqual(window.contentView?.bounds.size, idleSize)
    }

    func testLinkControlIsCompactAndSitsAboveTransportPlayButton() {
        let controller = PlayerViewController()
        let window = AppWindowFactory.make(contentViewController: controller)
        window.contentView?.layoutSubtreeIfNeeded()

        let linkFrame = controller.linkButton.convert(controller.linkButton.bounds, to: controller.view)
        let playFrame = controller.playPauseButton.convert(controller.playPauseButton.bounds, to: controller.view)

        XCTAssertEqual(linkFrame.midX, playFrame.midX, accuracy: 1, "Link: \(linkFrame), play: \(playFrame)")
        XCTAssertGreaterThanOrEqual(linkFrame.minY - playFrame.maxY, 6, "Link: \(linkFrame), play: \(playFrame)")
        XCTAssertLessThanOrEqual(linkFrame.minY - playFrame.maxY, 10, "Link: \(linkFrame), play: \(playFrame)")
        XCTAssertGreaterThanOrEqual(linkFrame.width, 90)
        XCTAssertLessThanOrEqual(linkFrame.width, 105)
        XCTAssertGreaterThanOrEqual(linkFrame.height, 30)
        XCTAssertLessThanOrEqual(linkFrame.height, 35)
    }

    func testLinkControlReceivesClicksAtItsVisibleCenter() {
        let controller = PlayerViewController()
        let window = AppWindowFactory.make(contentViewController: controller)
        window.contentView?.layoutSubtreeIfNeeded()

        let center = controller.linkButton.convert(
            NSPoint(x: controller.linkButton.bounds.midX, y: controller.linkButton.bounds.midY),
            to: controller.view
        )

        XCTAssertTrue(controller.view.hitTest(center) === controller.linkButton)
    }

    func testYouTubeControlBelongsToTheRightHeaderGroup() {
        let controller = PlayerViewController()
        let window = AppWindowFactory.make(contentViewController: controller)
        window.contentView?.layoutSubtreeIfNeeded()

        let frame = controller.youtubeButton.convert(controller.youtubeButton.bounds, to: controller.view)
        let themeFrame = controller.themePopup.convert(controller.themePopup.bounds, to: controller.view)
        let gap = themeFrame.minX - frame.maxX

        XCTAssertGreaterThanOrEqual(gap, 4, "YouTube: \(frame), theme: \(themeFrame)")
        XCTAssertLessThanOrEqual(gap, 12, "YouTube: \(frame), theme: \(themeFrame)")
        XCTAssertEqual(frame.midY, themeFrame.midY, accuracy: 2)
        XCTAssertEqual(
            controller.youtubeButton.alignmentRect(forFrame: controller.youtubeButton.frame).size,
            NSSize(width: 44, height: 44)
        )
    }

    func testOpeningLinkPanelFetchesTheCurrentChromeYouTubeURL() {
        let executor = AppRecordingScriptExecutor(
            responses: ["42\t3\thttps://youtu.be/current-video"]
        )
        let controller = PlayerViewController(
            chrome: ChromeController(executor: executor)
        )
        controller.loadView()

        controller.linkButton.performClick(nil)

        XCTAssertFalse(controller.sourceCardIsHidden)
        XCTAssertEqual(controller.urlField.stringValue, "https://youtu.be/current-video")
        XCTAssertEqual(executor.executionCount, 1)
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

    private func allConstraints(in view: NSView) -> [NSLayoutConstraint] {
        view.constraints + view.subviews.flatMap(allConstraints(in:))
    }

}

private final class AppRecordingScriptExecutor: AppleScriptExecuting {
    private var responses: [String]
    private(set) var executionCount = 0

    init(responses: [String]) {
        self.responses = responses
    }

    func execute(_ source: String) throws -> String {
        executionCount += 1
        return responses.isEmpty ? "" : responses.removeFirst()
    }
}
