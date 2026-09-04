import Foundation
import XCTest
@testable import LeanwaveCore

final class LivePlaybackTests: XCTestCase {
    func testStreamsForThirtySecondsAndTogglesMuteWithoutBrowserCookies() throws {
        guard ProcessInfo.processInfo.environment["LEANWAVE_LIVE_TEST"] == "1" else {
            throw XCTSkip("Set LEANWAVE_LIVE_TEST=1 to run the live YouTube check.")
        }
        let youtube = try XCTUnwrap(YouTubeURL("https://www.youtube.com/watch?v=araHHgik8FQ"))
        let player = PlayerController()
        defer { player.stop() }

        try player.play(url: youtube)
        XCTAssertTrue(waitUntil(player: player, timeout: 20) { $0.phase == .playing }, "Playback did not start: \(player.state)")
        player.setVolume(0)

        player.toggleMute()
        XCTAssertTrue(waitUntil(player: player, timeout: 3) { $0.isMuted }, "Mute did not activate")
        player.toggleMute()
        XCTAssertTrue(waitUntil(player: player, timeout: 3) { !$0.isMuted }, "Mute did not deactivate")

        let startingPosition = player.state.position
        XCTAssertTrue(
            waitUntil(player: player, timeout: 40) { $0.position >= startingPosition + 30 },
            "Playback stopped advancing: \(player.state)"
        )
    }

    private func waitUntil(player: PlayerController, timeout: TimeInterval, condition: (PlayerState) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition(player.state) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return condition(player.state)
    }
}
