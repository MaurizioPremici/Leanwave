import XCTest
@testable import LeanwaveCore

final class PlayerStateTests: XCTestCase {
    func testLoadingThenPlaybackConfirmationOffersChromeChoiceOnce() {
        var state = PlayerState()
        state = PlayerEventReducer.reduce(state: state, event: .loading)
        XCTAssertEqual(state.phase, .loading)

        state = PlayerEventReducer.reduce(state: state, event: .playbackConfirmed)
        XCTAssertEqual(state.phase, .playing)
        XCTAssertTrue(state.closeChoicePending)

        state = PlayerEventReducer.reduce(state: state, event: .closeChoiceHandled)
        XCTAssertFalse(state.closeChoicePending)
        state = PlayerEventReducer.reduce(state: state, event: .playbackConfirmed)
        XCTAssertFalse(state.closeChoicePending)
    }

    func testUpdatesObservedPlaybackProperties() {
        var state = PlayerEventReducer.reduce(state: PlayerState(), event: .loading)
        state = PlayerEventReducer.reduce(state: state, event: .titleChanged("A title"))
        state = PlayerEventReducer.reduce(state: state, event: .pauseChanged(true))
        state = PlayerEventReducer.reduce(state: state, event: .positionChanged(-5))
        state = PlayerEventReducer.reduce(state: state, event: .durationChanged(120))
        state = PlayerEventReducer.reduce(state: state, event: .volumeChanged(72))
        state = PlayerEventReducer.reduce(state: state, event: .muteChanged(true))

        XCTAssertEqual(state.title, "A title")
        XCTAssertTrue(state.isPaused)
        XCTAssertEqual(state.position, 0)
        XCTAssertEqual(state.duration, 120)
        XCTAssertEqual(state.volume, 72)
        XCTAssertTrue(state.isMuted)
    }

    func testEndAndFailureResetTransientPlaybackState() {
        var state = PlayerEventReducer.reduce(state: PlayerState(), event: .loading)
        state = PlayerEventReducer.reduce(state: state, event: .playbackConfirmed)
        state = PlayerEventReducer.reduce(state: state, event: .ended)
        XCTAssertEqual(state.phase, .idle)
        XCTAssertFalse(state.closeChoicePending)

        state = PlayerEventReducer.reduce(state: state, event: .failed("Extraction failed"))
        XCTAssertEqual(state.phase, .failed("Extraction failed"))
        XCTAssertFalse(state.closeChoicePending)
    }

    func testNewLoadingSessionResetsConfirmationAndMetadata() {
        var state = PlayerEventReducer.reduce(state: PlayerState(), event: .loading)
        state = PlayerEventReducer.reduce(state: state, event: .playbackConfirmed)
        state = PlayerEventReducer.reduce(state: state, event: .titleChanged("Old"))
        state = PlayerEventReducer.reduce(state: state, event: .loading)

        XCTAssertFalse(state.didConfirmPlayback)
        XCTAssertFalse(state.closeChoicePending)
        XCTAssertEqual(state.title, "Loading audio…")
        XCTAssertEqual(state.position, 0)
        XCTAssertNil(state.duration)
    }
}
