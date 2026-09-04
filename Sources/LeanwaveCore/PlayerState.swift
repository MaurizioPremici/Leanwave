import Foundation

public enum PlayerPhase: Equatable, Sendable {
    case idle
    case loading
    case playing
    case failed(String)
}

public struct PlayerState: Equatable, Sendable {
    public var phase: PlayerPhase = .idle
    public var title = "Ready"
    public var isPaused = false
    public var isMuted = false
    public var volume = 75.0
    public var position = 0.0
    public var duration: Double?
    public var didConfirmPlayback = false
    public var closeChoicePending = false

    public init() {}
}

public enum PlayerEvent: Equatable, Sendable {
    case loading
    case playbackConfirmed
    case closeChoiceHandled
    case titleChanged(String)
    case pauseChanged(Bool)
    case positionChanged(Double)
    case durationChanged(Double?)
    case volumeChanged(Double)
    case muteChanged(Bool)
    case ended
    case failed(String)
}

public enum PlayerEventReducer {
    public static func reduce(state: PlayerState, event: PlayerEvent) -> PlayerState {
        var result = state
        switch event {
        case .loading:
            result = PlayerState()
            result.phase = .loading
            result.title = "Loading audio…"
        case .playbackConfirmed:
            result.phase = .playing
            if !result.didConfirmPlayback {
                result.didConfirmPlayback = true
                result.closeChoicePending = true
            }
        case .closeChoiceHandled:
            result.closeChoicePending = false
        case .titleChanged(let title):
            if !title.isEmpty { result.title = title }
        case .pauseChanged(let paused):
            result.isPaused = paused
        case .positionChanged(let position):
            result.position = max(0, position.isFinite ? position : 0)
        case .durationChanged(let duration):
            if let duration, duration.isFinite, duration > 0 {
                result.duration = duration
            } else {
                result.duration = nil
            }
        case .volumeChanged(let volume):
            result.volume = min(max(volume.isFinite ? volume : 0, 0), 100)
        case .muteChanged(let muted):
            result.isMuted = muted
        case .ended:
            let volume = result.volume
            result = PlayerState()
            result.volume = volume
        case .failed(let message):
            result.phase = .failed(message)
            result.closeChoicePending = false
        }
        return result
    }
}
