import Foundation
import XCTest
@testable import LeanwaveCore

final class ResolvedMediaTests: XCTestCase {
    func testDecodesHTTPSStreamHeadersAndAvailability() throws {
        let data = #"{"url":"https://media.example/audio","title":"Minimal Waves","http_headers":{"User-Agent":"Leanwave"},"available_at":1000}"#.data(using: .utf8)!
        let media = try JSONDecoder().decode(ResolvedMedia.self, from: data)

        XCTAssertEqual(media.url.absoluteString, "https://media.example/audio")
        XCTAssertEqual(media.httpHeaders["User-Agent"], "Leanwave")
        XCTAssertEqual(media.title, "Minimal Waves")
        XCTAssertEqual(media.availableAt, Date(timeIntervalSince1970: 1000))
    }

    func testRejectsNonHTTPSMediaURL() {
        let data = #"{"url":"file:///tmp/audio"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ResolvedMedia.self, from: data))
    }
}
