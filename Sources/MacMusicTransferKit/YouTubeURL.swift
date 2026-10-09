import Foundation

/// One YouTube video, from what the user pasted (§8.1; Y3). Only a single
/// video: a playlist in the address is dropped, never followed.
public struct YouTubeVideo: Sendable, Equatable {
    public let id: String

    /// The plain address of the video alone, given to yt-dlp.
    public var url: URL { URL(string: "https://www.youtube.com/watch?v=\(id)")! }

    public enum Problem: Error, Equatable, Sendable {
        case empty
        case notAnAddress
        case notYouTube
        /// A YouTube address, but of a playlist or channel, not one video.
        case notAVideo
    }

    /// Accepts youtube.com/watch?v=, youtu.be/, youtube.com/shorts/, the
    /// m. and music. sites, and youtube-nocookie.com/embed/; with or
    /// without "https://".
    public static func parse(_ text: String) -> Result<YouTubeVideo, Problem> {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return .failure(.empty) }
        if !s.contains("://") { s = "https://" + s }
        guard let parts = URLComponents(string: s), let scheme = parts.scheme?.lowercased(),
              scheme == "https" || scheme == "http", let rawHost = parts.host?.lowercased(), !rawHost.isEmpty
        else { return .failure(.notAnAddress) }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        let path = parts.path.split(separator: "/").map(String.init)

        let id: String?
        switch host {
        case "youtube.com", "m.youtube.com", "music.youtube.com":
            if path.first == "watch" {
                id = parts.queryItems?.first { $0.name == "v" }?.value
            } else if ["shorts", "live", "embed"].contains(path.first ?? ""), path.count >= 2 {
                id = path[1]
            } else {
                return .failure(.notAVideo)
            }
        case "youtu.be":
            id = path.first
        case "youtube-nocookie.com":
            id = path.first == "embed" && path.count >= 2 ? path[1] : nil
        default:
            return .failure(.notYouTube)
        }
        guard let id, isVideoID(id) else { return .failure(.notAVideo) }
        return .success(YouTubeVideo(id: id))
    }

    /// Eleven characters of letters, digits, "-" and "_".
    public static func isVideoID(_ s: String) -> Bool {
        s.count == 11 && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
}

extension YouTubeVideo.Problem {
    public var message: UserMessage {
        switch self {
        case .empty: UserMessage(summary: "Paste the address of a YouTube video.", detail: nil)
        case .notAnAddress: UserMessage(summary: "That isn't a web address.", detail: nil)
        case .notYouTube: UserMessage(summary: "That isn't a YouTube address.", detail: nil)
        case .notAVideo: UserMessage(summary: "That's a YouTube address, but not of one video (a playlist or a channel, perhaps).",
                                     detail: nil)
        }
    }
}
