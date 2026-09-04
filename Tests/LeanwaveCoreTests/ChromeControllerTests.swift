import XCTest
@testable import LeanwaveCore

final class ChromeControllerTests: XCTestCase {
    func testFetchesTheActiveYouTubeTab() throws {
        let executor = RecordingScriptExecutor(responses: ["42\t3\thttps://youtu.be/abc"])
        let controller = ChromeController(executor: executor)

        let reference = try controller.fetchActiveTab()

        XCTAssertEqual(reference.windowID, 42)
        XCTAssertEqual(reference.tabIndex, 3)
    }

    func testReportsChromeAndWindowAbsence() {
        XCTAssertThrowsError(
            try ChromeController(executor: RecordingScriptExecutor(responses: ["__LEANWAVE_NOT_RUNNING__"]))
                .fetchActiveTab()
        ) { XCTAssertEqual($0 as? ChromeControllerError, .notRunning) }

        XCTAssertThrowsError(
            try ChromeController(executor: RecordingScriptExecutor(responses: ["__LEANWAVE_NO_WINDOW__"]))
                .fetchActiveTab()
        ) { XCTAssertEqual($0 as? ChromeControllerError, .noWindow) }
    }

    func testClosesOnlyWhenRecordedTabStillMatches() throws {
        let reference = try ChromeScriptBuilder.parseTab("42\t3\thttps://youtu.be/abc")
        let matching = RecordingScriptExecutor(responses: ["42\t3\thttps://youtu.be/abc", ""])
        try ChromeController(executor: matching).closeTab(reference)
        XCTAssertEqual(matching.sources.count, 2)
        XCTAssertTrue(matching.sources[1].contains("tab 3 of chromeWindow"))

        let changed = RecordingScriptExecutor(responses: ["42\t3\thttps://youtu.be/different"])
        XCTAssertThrowsError(try ChromeController(executor: changed).closeTab(reference)) {
            XCTAssertEqual($0 as? ChromeControllerError, .tabChanged)
        }
        XCTAssertEqual(changed.sources.count, 1)
    }

    func testClosesRecordedURLAtItsCurrentIndexWhenChromeReordersTabs() throws {
        let reference = try ChromeScriptBuilder.parseTab("42\t3\thttps://youtu.be/abc")
        let executor = RecordingScriptExecutor(responses: ["42\t2\thttps://youtu.be/abc", ""])

        try ChromeController(executor: executor).closeTab(reference)

        XCTAssertEqual(executor.sources.count, 2)
        XCTAssertTrue(executor.sources[1].contains("tab 2 of chromeWindow"))
    }

    func testFindsAnExactManualURLMatch() throws {
        let executor = RecordingScriptExecutor(responses: [
            "42\t1\thttps://youtu.be/other\n84\t2\thttps://youtu.be/abc"
        ])
        let controller = ChromeController(executor: executor)

        let match = try controller.findTab(matching: try XCTUnwrap(YouTubeURL("https://youtu.be/abc")))

        XCTAssertEqual(match?.windowID, 84)
        XCTAssertEqual(match?.tabIndex, 2)
    }

    func testOpensYouTubeInGoogleChrome() throws {
        let executor = RecordingScriptExecutor(responses: [""])
        try ChromeController(executor: executor).openYouTube()
        XCTAssertEqual(executor.sources, [ChromeScriptBuilder.openYouTube])
    }
}

private final class RecordingScriptExecutor: AppleScriptExecuting {
    private var responses: [String]
    private(set) var sources: [String] = []

    init(responses: [String]) {
        self.responses = responses
    }

    func execute(_ source: String) throws -> String {
        sources.append(source)
        return responses.isEmpty ? "" : responses.removeFirst()
    }
}
