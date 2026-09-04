import Foundation

public enum ExecutableLocator {
    public static func resolve(
        named name: String,
        fileExists: (String) -> Bool = FileManager.default.isExecutableFile(atPath:),
        pathEnvironment: String = ProcessInfo.processInfo.environment["PATH"] ?? ""
    ) -> String? {
        let knownDirectories = ["/opt/homebrew/bin", "/usr/local/bin"]
        for directory in knownDirectories {
            let candidate = "\(directory)/\(name)"
            if fileExists(candidate) { return candidate }
        }
        for directory in pathEnvironment.split(separator: ":") where !directory.isEmpty {
            let candidate = "\(directory)/\(name)"
            if fileExists(candidate) { return candidate }
        }
        return nil
    }
}

public enum MPVEventParser {
    public static func parse(_ line: String) throws -> PlayerEvent? {
        guard let data = line.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = object["event"] as? String
        else {
            return nil
        }

        if event == "playback-restart" { return .playbackConfirmed }
        if event == "end-file" || event == "shutdown" { return .ended }
        guard event == "property-change", let name = object["name"] as? String else {
            return nil
        }

        let value = object["data"]
        switch name {
        case "time-pos": return (value as? NSNumber).map { .positionChanged($0.doubleValue) }
        case "duration":
            guard !(value is NSNull) else { return .durationChanged(nil) }
            return (value as? NSNumber).map { .durationChanged($0.doubleValue) }
        case "pause": return (value as? Bool).map(PlayerEvent.pauseChanged)
        case "mute": return (value as? Bool).map(PlayerEvent.muteChanged)
        case "volume": return (value as? NSNumber).map { .volumeChanged($0.doubleValue) }
        case "media-title": return (value as? String).map(PlayerEvent.titleChanged)
        default: return nil
        }
    }
}
