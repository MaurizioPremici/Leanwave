import XCTest
@testable import LeanwaveCore

final class ChromeScriptTests: XCTestCase {
    func testParsesFetchedTabReference() throws {
        let reference = try ChromeScriptBuilder.parseTab("42\t3\thttps://youtu.be/abc")

        XCTAssertEqual(reference.windowID, 42)
        XCTAssertEqual(reference.tabIndex, 3)
        XCTAssertEqual(reference.url.normalizedString, "https://youtu.be/abc")
    }

    func testRejectsMalformedOrNonYouTubeTabResponses() {
        XCTAssertThrowsError(try ChromeScriptBuilder.parseTab("bad response"))
        XCTAssertThrowsError(try ChromeScriptBuilder.parseTab("42\t3\thttps://example.com"))
        XCTAssertThrowsError(try ChromeScriptBuilder.parseTab("0\t3\thttps://youtu.be/abc"))
    }

    func testParsesAllYouTubeTabsAndIgnoresOtherPages() {
        let response = "42\t1\thttps://example.com\n42\t2\thttps://youtu.be/abc\n84\t1\thttps://www.youtube.com/watch?v=xyz"

        let references = ChromeScriptBuilder.parseTabs(response)

        XCTAssertEqual(references.map(\.windowID), [42, 84])
        XCTAssertEqual(references.map(\.tabIndex), [2, 1])
    }

    func testCloseScriptUsesOnlyValidatedNumericIdentity() throws {
        let reference = try ChromeScriptBuilder.parseTab("42\t3\thttps://youtu.be/abc")
        let script = ChromeScriptBuilder.closeTab(reference)

        XCTAssertTrue(script.contains("id of chromeWindow is 42"))
        XCTAssertTrue(script.contains("tab 3 of chromeWindow"))
        XCTAssertTrue(script.contains("if (count of tabs of chromeWindow) is 1"))
        XCTAssertTrue(script.contains("make new tab"))
        XCTAssertFalse(script.contains("youtu.be"))
    }

    func testScriptsTargetGoogleChrome() {
        XCTAssertTrue(ChromeScriptBuilder.fetchActiveTab.contains("Google Chrome"))
        XCTAssertTrue(ChromeScriptBuilder.listTabs.contains("Google Chrome"))
        XCTAssertTrue(ChromeScriptBuilder.quitChrome.contains("quit"))
        XCTAssertTrue(ChromeScriptBuilder.fetchActiveTab.contains("ASCII character 9"))
        XCTAssertTrue(ChromeScriptBuilder.listTabs.contains("ASCII character 10"))
        XCTAssertTrue(ChromeScriptBuilder.openYouTube.contains("https://www.youtube.com/"))
        XCTAssertTrue(ChromeScriptBuilder.openYouTube.contains("Google Chrome"))
    }
}
