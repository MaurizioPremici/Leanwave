import Foundation

struct ResolvedMedia: Decodable {
    let url: URL
    let title: String?
    let httpHeaders: [String: String]
    let availableAt: Date?

    enum CodingKeys: String, CodingKey {
        case url
        case title
        case httpHeaders = "http_headers"
        case availableAt = "available_at"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let urlString = try values.decode(String.self, forKey: .url)
        guard let parsedURL = URL(string: urlString), parsedURL.scheme == "https" else {
            throw DecodingError.dataCorruptedError(forKey: .url, in: values, debugDescription: "Invalid media URL")
        }
        url = parsedURL
        title = try values.decodeIfPresent(String.self, forKey: .title)
        httpHeaders = try values.decodeIfPresent([String: String].self, forKey: .httpHeaders) ?? [:]
        availableAt = try values.decodeIfPresent(Double.self, forKey: .availableAt).map(Date.init(timeIntervalSince1970:))
    }
}

enum YTDLPMediaResolver {
    static func resolve(url: YouTubeURL, executablePath: String) throws -> ResolvedMedia {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = [
            "--no-cookies", "--no-playlist",
            "--extractor-args", "youtube:player_client=web_embedded",
            "--format", "bestaudio/best",
            "--dump-single-json", "--", url.normalizedString,
        ]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PlayerControllerError.launchFailed("yt-dlp could not resolve this audio stream.")
        }
        return try JSONDecoder().decode(ResolvedMedia.self, from: data)
    }
}
