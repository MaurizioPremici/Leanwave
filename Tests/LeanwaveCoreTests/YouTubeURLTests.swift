import XCTest
@testable import LeanwaveCore

final class YouTubeURLTests: XCTestCase {
    func testAcceptsSupportedYouTubeHosts() {
        let values = [
            "https://www.youtube.com/watch?v=abc",
            "https://youtu.be/abc",
            "https://m.youtube.com/watch?v=abc",
            "http://youtube.com/watch?v=abc",
        ]

        for value in values {
            XCTAssertNotNil(YouTubeURL(value), value)
        }
    }

    func testRejectsUnsupportedOrDeceptiveURLs() {
        let values = [
            "",
            "notaurl",
            "file:///tmp/video",
            "javascript:alert(1)",
            "https://youtube.com.example.org/watch?v=abc",
            "https://notyoutube.com/watch?v=abc",
        ]

        for value in values {
            XCTAssertNil(YouTubeURL(value), value)
        }
    }

    func testTrimsWhitespaceAndNormalizesSchemeAndHostCase() {
        let url = YouTubeURL("  HTTPS://WWW.YOUTUBE.COM/watch?v=abc  ")

        XCTAssertEqual(url?.normalizedString, "https://www.youtube.com/watch?v=abc")
    }
}
