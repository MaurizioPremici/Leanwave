import Foundation
import XCTest
@testable import LeanwaveCore

final class ResolvedMediaTests: XCTestCase {
    func testResolverUsesDefaultYouTubeClientWithEmbeddedFallback() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("leanwave-resolver-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("fake-yt-dlp")
        let script = """
        #!/bin/sh
        case " $* " in
          *" --cookies-from-browser "*)
            exit 65
            ;;
          *" --no-cookies "*" --extractor-args youtube:player_client=default,web_embedded "*)
            printf '%s' '{"url":"https://media.example/audio"}'
            ;;
          *)
            exit 64
            ;;
        esac
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let youtube = try XCTUnwrap(YouTubeURL("https://www.youtube.com/watch?v=7hbutztruqg"))
        let media = try YTDLPMediaResolver.resolve(url: youtube, executablePath: executable.path)

        XCTAssertEqual(media.url.absoluteString, "https://media.example/audio")
    }

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
