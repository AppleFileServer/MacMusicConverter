import Foundation

/// A video's details, read before anything is downloaded (§2.1).
public struct VideoDetails: Sendable, Equatable {
    public let id: String
    public let title: String
    public let channel: String?
    public let duration: Double?
}

/// Why a video couldn't be looked up or retrieved (§11.3; Y6), sorted
/// from what yt-dlp says; its own words are kept for "Details".
public enum YouTubeError: Error, Equatable, Sendable {
    case unavailable(String)
    case privateVideo(String)
    /// Needs signing in: age-restricted, members-only, or a bot check. Not
    /// worked around (§8.3; Y4).
    case signInRequired(String)
    case regionBlocked(String)
    case network(String)
    /// YouTube has changed and yt-dlp may need updating.
    case needsUpdate(String)
    case failed(String)
    case toolMissing(String)
    case cancelled

    /// Sorts yt-dlp's error output.
    public static func from(_ stderr: String) -> YouTubeError {
        let lines = stderr.split(separator: "\n").filter { $0.hasPrefix("ERROR") }
        let text = (lines.isEmpty ? stderr : lines.joined(separator: "\n"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let t = text.lowercased()
        func has(_ words: String...) -> Bool { words.contains { t.contains($0) } }
        if has("private video") { return .privateVideo(text) }
        if has("confirm your age", "age-restricted", "inappropriate for some users", "sign in to confirm",
               "members-only", "join this channel", "requires payment", "sign in") {
            return .signInRequired(text)
        }
        if has("in your country", "not available in your region", "geo restriction", "geo-restricted") {
            return .regionBlocked(text)
        }
        if has("unable to download webpage", "urlopen error", "timed out", "network is unreachable",
               "nodename nor servname", "name or service not known", "connection reset", "temporary failure in name resolution",
               "failed to resolve", "no route to host") {
            return .network(text)
        }
        // Before "unavailable": "Requested format is not available" is
        // yt-dlp out of date, not the video gone.
        if has("signature", "nsig", "http error 403", "requested format is not available", "unable to extract",
               "please report this issue", "js challenge") {
            return .needsUpdate(text)
        }
        if has("video unavailable", "has been removed", "is not available", "does not exist", "no longer available") {
            return .unavailable(text)
        }
        return .failed(text)
    }

    public var message: UserMessage {
        switch self {
        case .unavailable(let d):
            UserMessage(summary: "The video isn't available: it may have been removed, or the address is wrong.", detail: d)
        case .privateVideo(let d):
            UserMessage(summary: "The video is private.", detail: d)
        case .signInRequired(let d):
            UserMessage(summary: "YouTube needs signing in to play this video (it may be age-restricted or for members only). This app doesn't sign in, so it can't be saved here.", detail: d)
        case .regionBlocked(let d):
            UserMessage(summary: "The video isn't available in your country.", detail: d)
        case .network(let d):
            UserMessage(summary: "YouTube couldn't be reached. Check the internet connection, and try again.", detail: d)
        case .needsUpdate(let d):
            UserMessage(summary: "YouTube has changed in a way this version of yt-dlp can't handle. yt-dlp may need updating (see BUILDING.md).", detail: d)
        case .failed(let d):
            UserMessage(summary: "The video couldn't be retrieved.", detail: d.isEmpty ? nil : d)
        case .toolMissing(let path):
            UserMessage(summary: "yt-dlp or Deno, which YouTube needs, couldn't be found.", detail: path)
        case .cancelled:
            UserMessage(summary: "Cancelled. Nothing was saved.", detail: nil)
        }
    }
}

/// The YouTube tools: yt-dlp, and Deno for its JavaScript (Y1).
public struct YouTubeTools: Sendable {
    public let ytdlp: URL
    public let deno: URL
    public let ffmpegFolder: URL

    /// Looked for in: MMC_TOOLS_BIN; inside the app, Contents/Helpers (P1);
    /// then ~/MacPlusProjects/converter-tools/yt-dlp/yt-dlp_macos and
    /// deno/deno ("current" links, which tools/update-yt-dlp.sh moves on);
    /// `pinned` false skips that last (the self-test).
    public static func locate(tools: Tools,
                              environment: [String: String] = ProcessInfo.processInfo.environment,
                              helpers: URL? = Tools.bundledHelpers,
                              pinned: Bool = true) throws -> YouTubeTools {
        let pinnedFolder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("MacPlusProjects/converter-tools")
        var candidates: [(URL, URL)] = []
        if let named = environment["MMC_TOOLS_BIN"], !named.isEmpty {
            let f = URL(fileURLWithPath: named)
            candidates.append((f.appendingPathComponent("yt-dlp"), f.appendingPathComponent("deno")))
        }
        if let helpers {
            candidates.append((helpers.appendingPathComponent("yt-dlp"), helpers.appendingPathComponent("deno")))
        }
        if pinned {
            candidates.append((pinnedFolder.appendingPathComponent("yt-dlp/yt-dlp_macos"),
                               pinnedFolder.appendingPathComponent("deno/deno")))
        }
        let files = FileManager.default
        for (y, d) in candidates where files.isExecutableFile(atPath: y.path) && files.isExecutableFile(atPath: d.path) {
            return YouTubeTools(ytdlp: y, deno: d, ffmpegFolder: tools.ffmpeg.deletingLastPathComponent())
        }
        throw YouTubeError.toolMissing(candidates.map { $0.0.path }.joined(separator: "\n"))
    }
}

/// The YouTube source adapter (§8.2): the only part of the app that knows
/// how yt-dlp is run or what it prints.
public struct YouTubeSource: Sendable {
    let tools: YouTubeTools
    let runner = ProcessRunner()

    public init(tools: YouTubeTools) { self.tools = tools }

    /// The options every run shares: no config files, no cookies, no
    /// playlist, our Deno and FFmpeg, and the age-restriction workaround
    /// (the embedded player) left out (§8.3; Y4).
    var common: [String] {
        ["--ignore-config", "--no-playlist", "--no-cookies", "--no-cookies-from-browser", "--no-cache-dir",
         "--js-runtimes", "deno:" + tools.deno.path,
         "--ffmpeg-location", tools.ffmpegFolder.path,
         "--extractor-args", "youtube:player_client=default,-web_embedded",
         "--socket-timeout", "30",                     // a stalled network: an error, not a hang
         "--no-warnings", "--no-color"]
    }

    /// Reads the video's details, downloading nothing.
    public func lookUp(_ video: YouTubeVideo) async throws -> VideoDetails {
        let r: ProcessOutput
        do {
            r = try await runner.run(tools.ytdlp, arguments: common + [
                "--skip-download", "--dump-single-json", "--", video.url.absoluteString,
            ])
        } catch ProcessRunnerError.cancelled {
            throw YouTubeError.cancelled
        } catch ProcessRunnerError.executableNotFound(let p) {
            throw YouTubeError.toolMissing(p)
        }
        guard r.status == 0 else { throw YouTubeError.from(r.stderrText) }
        struct Info: Decodable {
            let id: String?
            let title: String?
            let channel: String?
            let uploader: String?
            let duration: Double?
            let _type: String?
        }
        guard let info = try? JSONDecoder().decode(Info.self, from: r.stdout), info._type ?? "video" == "video"
        else { throw YouTubeError.failed("yt-dlp's details couldn't be read.") }
        return VideoDetails(id: info.id ?? video.id, title: info.title ?? video.id,
                            channel: info.channel ?? info.uploader, duration: info.duration)
    }

    /// Downloads the video's best audio-only stream, as it is (no video, no
    /// conversion: the engine does that, once, Y2), into `folder`.
    /// `progress` gets 0 to 1 when yt-dlp knows the size.
    public func retrieveAudio(_ video: YouTubeVideo, into folder: URL,
                              progress: @escaping @Sendable (Double?) -> Void) async throws -> URL {
        let lines = LineBuffer()
        let r: ProcessOutput
        do {
            r = try await runner.stream(tools.ytdlp, arguments: common + [
                "-f", "bestaudio[vcodec=none]/bestaudio",
                "--newline", "--progress-template",
                "download:mmc-progress %(progress.downloaded_bytes)s %(progress.total_bytes)s %(progress.total_bytes_estimate)s",
                "-o", folder.appendingPathComponent("source.%(ext)s").path,
                "--", video.url.absoluteString,
            ]) { piece in
                for line in lines.add(piece) {
                    if let f = Self.progressFraction(line) { progress(f) }
                }
            }
        } catch ProcessRunnerError.cancelled {
            throw YouTubeError.cancelled
        } catch ProcessRunnerError.executableNotFound(let p) {
            throw YouTubeError.toolMissing(p)
        }
        guard r.status == 0 else { throw YouTubeError.from(r.stderrText) }
        let found = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        guard let file = found.first(where: { $0.lastPathComponent.hasPrefix("source.")
                                              && !$0.lastPathComponent.hasSuffix(".part") }) else {
            throw YouTubeError.failed("yt-dlp finished, but no audio file was saved.")
        }
        return file
    }

    /// "mmc-progress <downloaded> <total> <estimate>" to a fraction;
    /// yt-dlp writes "NA" for what it doesn't know.
    static func progressFraction(_ line: String) -> Double? {
        let parts = line.split(separator: " ")
        guard parts.count == 4, parts[0] == "mmc-progress", let done = Double(parts[1]) else { return nil }
        guard let total = Double(parts[2]) ?? Double(parts[3]), total > 0 else { return nil }
        return min(done / total, 1)
    }
}

/// Splits streamed output into whole lines.
final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var rest = ""
    func add(_ piece: Data) -> [String] {
        lock.withLock {
            rest += String(decoding: piece, as: UTF8.self)
            var lines = rest.components(separatedBy: "\n")
            rest = lines.removeLast()
            return lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }
}
