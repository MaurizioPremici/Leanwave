import Foundation
import XCTest
@testable import LeanwaveCore

final class MPVProtocolTests: XCTestCase {
    func testLaunchArgumentsKeepPlaybackAudioOnlyAndBoundTheCache() {
        let arguments = MPVLaunchConfiguration.arguments(
            url: "https://youtu.be/abc",
            socketPath: "/tmp/leanwave-test.sock",
            ytdlpPath: "/opt/homebrew/bin/yt-dlp",
            httpHeaders: ["User-Agent": "Leanwave Test", "Referer": "https://www.youtube.com/"]
        )

        XCTAssertTrue(arguments.contains("--no-video"))
        XCTAssertTrue(arguments.contains("--force-window=no"))
        XCTAssertTrue(arguments.contains("--input-ipc-server=/tmp/leanwave-test.sock"))
        XCTAssertTrue(arguments.contains("--ytdl=no"))
        XCTAssertTrue(arguments.contains("--cache=yes"))
        XCTAssertTrue(arguments.contains("--pause=yes"))
        XCTAssertTrue(arguments.contains("--demuxer-max-bytes=16MiB"))
        XCTAssertTrue(arguments.contains("--demuxer-max-back-bytes=4MiB"))
        XCTAssertFalse(arguments.contains { $0.contains("cookies-from-browser") })
        XCTAssertFalse(arguments.contains { $0.contains("web_embedded") })
        XCTAssertTrue(arguments.contains("--user-agent=Leanwave Test"))
        XCTAssertTrue(arguments.contains("--referrer=https://www.youtube.com/"))
        XCTAssertEqual(arguments.last, "https://youtu.be/abc")
    }

    func testCommandsEncodeAsNewlineTerminatedJSON() throws {
        let cases: [(MPVCommand, [Any])] = [
            (.setPause(true), ["set_property", "pause", true]),
            (.seekRelative(15), ["seek", 15.0, "relative"]),
            (.seekAbsolute(42), ["seek", 42.0, "absolute"]),
            (.setVolume(65), ["set_property", "volume", 65.0]),
            (.setMute(true), ["set_property", "mute", true]),
            (.stop, ["stop"]),
        ]

        for (command, expected) in cases {
            let data = try command.encoded(requestID: 42)
            XCTAssertEqual(data.last, Character("\n").asciiValue)
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: data.dropLast()) as? [String: Any]
            )
            XCTAssertEqual(object["request_id"] as? Int, 42)
            XCTAssertEqual(object["command"] as? NSArray, expected as NSArray)
        }
    }

    func testVolumeIsClampedAndNonFiniteNumbersAreRejected() throws {
        let high = try MPVCommand.setVolume(150).encoded(requestID: 1)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: high.dropLast()) as? [String: Any]
        )
        let command = try XCTUnwrap(object["command"] as? [Any])
        XCTAssertEqual(command[2] as? Double, 100)

        XCTAssertThrowsError(try MPVCommand.seekRelative(Double.infinity).encoded(requestID: 2))
    }
}
