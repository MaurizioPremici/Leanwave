import Foundation

public enum MPVLaunchConfiguration {
    public static func arguments(
        url: String,
        socketPath: String,
        ytdlpPath: String
    ) -> [String] {
        [
            "--no-video",
            "--force-window=no",
            "--input-ipc-server=\(socketPath)",
            "--ytdl=yes",
            "--ytdl-format=bestaudio/best",
            "--script-opts=ytdl_hook-ytdl_path=\(ytdlpPath)",
            "--ytdl-raw-options=no-playlist=,extractor-args=youtube:player_client=web_embedded",
            "--cache=yes",
            "--pause=yes",
            "--demuxer-max-bytes=16MiB",
            "--demuxer-max-back-bytes=4MiB",
            "--idle=no",
            url,
        ]
    }
}

public enum MPVProtocolError: Error, Equatable {
    case nonFiniteNumber
}

public enum MPVCommand: Equatable, Sendable {
    case setPause(Bool)
    case seekRelative(Double)
    case seekAbsolute(Double)
    case setVolume(Double)
    case setMute(Bool)
    case stop
    case observeProperty(id: Int, name: String)

    public func encoded(requestID: Int) throws -> Data {
        let command: [Any]
        switch self {
        case .setPause(let paused):
            command = ["set_property", "pause", paused]
        case .seekRelative(let seconds):
            guard seconds.isFinite else { throw MPVProtocolError.nonFiniteNumber }
            command = ["seek", seconds, "relative"]
        case .seekAbsolute(let seconds):
            guard seconds.isFinite else { throw MPVProtocolError.nonFiniteNumber }
            command = ["seek", max(0, seconds), "absolute"]
        case .setVolume(let volume):
            guard volume.isFinite else { throw MPVProtocolError.nonFiniteNumber }
            command = ["set_property", "volume", min(max(volume, 0), 100)]
        case .setMute(let muted):
            command = ["set_property", "mute", muted]
        case .stop:
            command = ["stop"]
        case .observeProperty(let id, let name):
            command = ["observe_property", id, name]
        }

        var data = try JSONSerialization.data(withJSONObject: [
            "command": command,
            "request_id": requestID,
        ])
        data.append(0x0A)
        return data
    }
}
