import XCTest
@testable import LeanwaveCore

final class TimeTextTests: XCTestCase {
    func testFormatsPlaybackTimeWithoutAllocatingAFormatter() {
        XCTAssertEqual(TimeText.format(0), "0:00")
        XCTAssertEqual(TimeText.format(65), "1:05")
        XCTAssertEqual(TimeText.format(3_661), "1:01:01")
        XCTAssertEqual(TimeText.format(-3), "0:00")
    }
}
