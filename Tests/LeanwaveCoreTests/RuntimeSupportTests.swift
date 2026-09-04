import XCTest
@testable import LeanwaveCore

final class RuntimeSupportTests: XCTestCase {
    func testExecutableResolutionPrefersKnownHomebrewLocations() {
        let existing = Set(["/opt/homebrew/bin/mpv", "/custom/bin/mpv"])
        let result = ExecutableLocator.resolve(
            named: "mpv",
            fileExists: { existing.contains($0) },
            pathEnvironment: "/custom/bin:/usr/bin"
        )

        XCTAssertEqual(result, "/opt/homebrew/bin/mpv")
    }

    func testExecutableResolutionFallsBackToPath() {
        let result = ExecutableLocator.resolve(
            named: "yt-dlp",
            fileExists: { $0 == "/custom/bin/yt-dlp" },
            pathEnvironment: "/missing:/custom/bin"
        )

        XCTAssertEqual(result, "/custom/bin/yt-dlp")
    }

    func testParsesPlaybackAndPropertyEvents() throws {
        XCTAssertEqual(
            try MPVEventParser.parse(#"{"event":"playback-restart"}"#),
            .playbackConfirmed
        )
        XCTAssertEqual(
            try MPVEventParser.parse(#"{"event":"property-change","name":"time-pos","data":12.5}"#),
            .positionChanged(12.5)
        )
        XCTAssertEqual(
            try MPVEventParser.parse(#"{"event":"property-change","name":"pause","data":true}"#),
            .pauseChanged(true)
        )
        XCTAssertEqual(
            try MPVEventParser.parse(#"{"event":"property-change","name":"media-title","data":"Track"}"#),
            .titleChanged("Track")
        )
        XCTAssertEqual(try MPVEventParser.parse(#"{"event":"end-file"}"#), .ended)
    }

    func testIgnoresResponsesAndUnknownProperties() throws {
        XCTAssertNil(try MPVEventParser.parse(#"{"request_id":1,"error":"success"}"#))
        XCTAssertNil(
            try MPVEventParser.parse(#"{"event":"property-change","name":"path","data":"x"}"#)
        )
    }

    func testDescribesNonZeroPlayerExitWithoutHidingTheCause() {
        XCTAssertNil(PlaybackExit.failureMessage(status: 0, stderr: ""))
        XCTAssertEqual(
            PlaybackExit.failureMessage(status: 2, stderr: "first line\nHTTP error 403 Forbidden\n"),
            "Audio playback failed (mpv 2): HTTP error 403 Forbidden"
        )
        XCTAssertEqual(
            PlaybackExit.failureMessage(status: 1, stderr: ""),
            "Audio playback failed (mpv 1)."
        )
    }
}
