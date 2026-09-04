import Foundation
import XCTest
@testable import LeanwaveCore

final class LivePlaybackTests: XCTestCase {
    func testStreamsYouTubeAudioWithoutBrowserCookies() throws {
        guard ProcessInfo.processInfo.environment["LEANWAVE_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set LEANWAVE_LIVE_TEST=1 to run the live YouTube check.")
        }
        let youtube = try XCTUnwrap(YouTubeURL("https://www.youtube.com/watch?v=araHHgik8FQ"))
        let media = try YTDLPMediaResolver.resolve(url: youtube, executablePath: "/opt/homebrew/bin/yt-dlp")
        if let availableAt = media.availableAt {
            Thread.sleep(forTimeInterval: max(0, availableAt.timeIntervalSinceNow + 3))
        }
        let proxy = HTTPRangeProxy(remoteURL: media.url, headers: media.httpHeaders)
        let localURL = try proxy.start()
        defer { proxy.stop() }

        let mpv = Process()
        mpv.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mpv")
        mpv.arguments = ["--no-config", "--no-video", "--ytdl=no", "--start=30", "--length=1", localURL.absoluteString]
        let errors = Pipe()
        mpv.standardError = errors
        try mpv.run()
        mpv.waitUntilExit()
        let detail = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(mpv.terminationStatus, 0, detail)
    }
}
