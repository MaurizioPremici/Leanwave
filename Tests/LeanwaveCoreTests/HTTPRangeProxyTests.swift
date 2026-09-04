import XCTest
@testable import LeanwaveCore

final class HTTPRangeProxyTests: XCTestCase {
    func testForwardedRangeIsCappedBelowYouTubeOneMiBRejectionBoundary() {
        XCTAssertEqual(
            HTTPRangeProxy.forwardedRangeHeader(for: "GET /audio HTTP/1.1\r\nHost: localhost\r\n\r\n"),
            "Range: bytes=0-524287"
        )
        XCTAssertEqual(
            HTTPRangeProxy.forwardedRangeHeader(
                for: "GET /audio HTTP/1.1\r\nRange: bytes=786432-\r\n\r\n"
            ),
            "Range: bytes=786432-1310719"
        )
    }

    func testForwardedRangeDoesNotExceedARequestedSmallerEnd() {
        XCTAssertEqual(
            HTTPRangeProxy.forwardedRangeHeader(
                for: "GET /audio HTTP/1.1\r\nRange: bytes=100-200\r\n\r\n"
            ),
            "Range: bytes=100-200"
        )
    }
}
