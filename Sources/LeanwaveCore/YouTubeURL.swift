import Foundation

public struct YouTubeURL: Equatable, Sendable {
    public let url: URL
    public let normalizedString: String

    public init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(),
              host == "youtube.com" || host == "youtu.be" || host.hasSuffix(".youtube.com")
        else {
            return nil
        }

        components.scheme = scheme
        components.host = host
        guard let normalized = components.string,
              let url = URL(string: normalized)
        else {
            return nil
        }

        self.url = url
        self.normalizedString = normalized
    }
}
