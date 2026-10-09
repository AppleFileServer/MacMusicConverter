import Foundation
import Testing
@testable import MacMusicConverterKit

/// YouTube, offline (§13.4; Y8): URLs, error sorting, and the whole path
/// through a stand-in for yt-dlp, which answers with ready-made details
/// and copies a fixture as "the download".
@Suite struct YouTubeTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    // MARK: URLs (Y3)

    @Test func acceptedAddresses() throws {
        let id = "RMxRDTfzgpU"
        for text in [
            "https://www.youtube.com/watch?v=\(id)",
            "https://www.youtube.com/watch?v=\(id)&list=RD\(id)&start_radio=1",
            "youtube.com/watch?v=\(id)",
            "  https://youtu.be/\(id)?si=abc  ",
            "https://m.youtube.com/watch?v=\(id)",
            "https://music.youtube.com/watch?v=\(id)&feature=share",
            "https://www.youtube.com/shorts/\(id)",
            "https://www.youtube-nocookie.com/embed/\(id)",
            "http://www.youtube.com/watch?feature=x&v=\(id)",
        ] {
            #expect(try YouTubeVideo.parse(text).get() == YouTubeVideo(id: id), "\(text)")
        }
        #expect(YouTubeVideo(id: id).url.absoluteString == "https://www.youtube.com/watch?v=\(id)")
    }

    @Test func refusedAddresses() {
        let cases: [(String, YouTubeVideo.Problem)] = [
            ("", .empty), ("   ", .empty),
            ("https://vimeo.com/12345", .notYouTube),
            ("https://example.com/watch?v=RMxRDTfzgpU", .notYouTube),
            ("https://www.youtube.com/playlist?list=PL1234567890", .notAVideo),
            ("https://www.youtube.com/@somechannel", .notAVideo),
            ("https://www.youtube.com/watch?v=short", .notAVideo),
            ("https://www.youtube.com/watch?v=RMxRDTfzgp;", .notAVideo),
            ("ftp://youtube.com/watch?v=RMxRDTfzgpU", .notAnAddress),
        ]
        for (text, problem) in cases {
            #expect(YouTubeVideo.parse(text) == .failure(problem), "\(text)")
        }
    }

    // MARK: Errors (Y6)

    @Test func errorsAreSorted() {
        func kind(_ s: String) -> String { String("\(YouTubeError.from(s))".prefix { $0 != "(" }) }
        #expect(kind("ERROR: [youtube] abc: Video unavailable") == "unavailable")
        #expect(kind("ERROR: [youtube] abc: Private video. Sign in if you've been granted access") == "privateVideo")
        #expect(kind("ERROR: [youtube] abc: Sign in to confirm your age. This video may be inappropriate") == "signInRequired")
        #expect(kind("ERROR: [youtube] abc: Join this channel to get access to members-only content") == "signInRequired")
        #expect(kind("ERROR: [youtube] abc: Sign in to confirm you\u{2019}re not a bot") == "signInRequired")
        #expect(kind("ERROR: [youtube] abc: The uploader has not made this video available in your country") == "regionBlocked")
        #expect(kind("ERROR: Unable to download webpage: <urlopen error [Errno 8] nodename nor servname provided>") == "network")
        #expect(kind("ERROR: [youtube] abc: Requested format is not available") == "needsUpdate")
        #expect(kind("ERROR: something new") == "failed")
        // Only the ERROR lines are kept for the details.
        if case .unavailable(let d) = YouTubeError.from("[youtube] abc: Downloading\nERROR: [youtube] abc: Video unavailable") {
            #expect(d == "ERROR: [youtube] abc: Video unavailable")
        } else { Issue.record("not sorted") }
        #expect(!YouTubeError.signInRequired("x").message.summary.isEmpty)
    }

    @Test func progressLines() {
        #expect(YouTubeSource.progressFraction("mmc-progress 500 1000 NA") == 0.5)
        #expect(YouTubeSource.progressFraction("mmc-progress 500 NA 2000") == 0.25)
        #expect(YouTubeSource.progressFraction("mmc-progress 500 NA NA") == nil)
        #expect(YouTubeSource.progressFraction("[download] 50%") == nil)
    }

    // MARK: The stand-in yt-dlp

    /// A yt-dlp stand-in: prints `details` (JSON) for a look-up; for a
    /// download, prints progress and copies `audio` to the -o path (as
    /// .m4a), after `delay` seconds; or fails with `error`. It records its
    /// arguments, one a line, in args.txt.
    func fake(details: String = #"{"id":"RMxRDTfzgpU","title":"A Test Song","channel":"Me","duration":3,"_type":"video"}"#,
              audio: URL? = nil, error: String? = nil, delay: Double = 0) throws -> YouTubeTools {
        let bin = f.url("fake-bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let log = f.url("args.txt").path
        var script = """
            #!/bin/sh
            : > '\(log)'
            for a in "$@"; do printf '%s\\n' "$a" >> '\(log)'; done

            """
        if let error {
            script += "echo '\(error)' >&2\nexit 1\n"
        } else {
            script += """
                for a in "$@"; do
                  if [ "$a" = "--dump-single-json" ]; then echo '\(details)'; exit 0; fi
                done
                out=""; prev=""
                for a in "$@"; do
                  if [ "$prev" = "-o" ]; then out="$a"; fi
                  prev="$a"
                done
                out=$(echo "$out" | sed 's/%(ext)s/m4a/')
                echo "mmc-progress 0 1000 NA"
                sleep \(delay)
                echo "mmc-progress 1000 1000 NA"
                cp '\(audio?.path ?? "/dev/null")' "$out"

                """
        }
        let ytdlp = bin.appendingPathComponent("yt-dlp")
        try script.write(to: ytdlp, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ytdlp.path)
        return YouTubeTools(ytdlp: ytdlp, deno: URL(fileURLWithPath: "/usr/bin/true"),
                            ffmpegFolder: f.tools.ffmpeg.deletingLastPathComponent())
    }

    func m4a(_ name: String, seconds: Int = 3) async throws -> URL {
        let out = f.url(name)
        let r = try await ProcessRunner().run(f.tools.ffmpeg, arguments: [
            "-nostdin", "-v", "error", "-f", "lavfi", "-i", "sine=f=440:d=\(seconds)",
            "-ac", "2", "-c:a", "aac", "-b:a", "128k", out.path])
        guard r.status == 0 else { throw FixtureError.ffmpeg(r.stderrText) }
        return out
    }

    var video: YouTubeVideo { YouTubeVideo(id: "RMxRDTfzgpU") }

    func args() throws -> [String] {
        try String(contentsOf: f.url("args.txt"), encoding: .utf8).split(separator: "\n").map(String.init)
    }

    @Test func lookUpReadsTheDetails() async throws {
        let tools = try fake()
        let d = try await YouTubeSource(tools: tools).lookUp(video)
        #expect(d == VideoDetails(id: "RMxRDTfzgpU", title: "A Test Song", channel: "Me", duration: 3))
        let a = try args()
        // One video, never a playlist; no cookies; the age workaround off;
        // the address last, after "--", so it can't be read as an option.
        #expect(a.contains("--no-playlist") && a.contains("--no-cookies") && a.contains("--no-cookies-from-browser")
                && a.contains("--skip-download"))
        #expect(a.contains("youtube:player_client=default,-web_embedded"))
        #expect(a.suffix(2) == ["--", "https://www.youtube.com/watch?v=RMxRDTfzgpU"])
    }

    @Test func lookUpErrorsAreSorted() async throws {
        let tools = try fake(error: "ERROR: [youtube] RMxRDTfzgpU: Private video")
        await #expect(throws: YouTubeError.privateVideo("ERROR: [youtube] RMxRDTfzgpU: Private video")) {
            try await YouTubeSource(tools: tools).lookUp(video)
        }
    }

    @Test func aPlaylistIsRefused() async throws {
        let tools = try fake(details: #"{"id":"PL1","title":"A List","_type":"playlist"}"#)
        await #expect(throws: YouTubeError.self) { try await YouTubeSource(tools: tools).lookUp(video) }
    }

    /// Retrieved once, then both outputs from it, named after the video;
    /// the download deleted afterwards (Workflow C).
    @Test func bothOutputsFromOneRetrieval() async throws {
        let audio = try await m4a("download.m4a")
        let tools = try fake(audio: audio)
        let out = f.url("out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let got = Got()
        let r = try await ConversionEngine(tools: f.tools).run(
            youTube: video, details: VideoDetails(id: video.id, title: "A Test Song", channel: nil, duration: 3),
            using: tools, job: ConversionJob(source: video.url, outputFolder: out, title: "A Test Song", outputs: .both)) {
                got.add($0)
            }
        #expect(r.stage == .completed, "\(r.outputs.map(\.problems))")
        #expect(r.outputs.compactMap { $0.url?.lastPathComponent } == ["A Test Song.wav", "A Test Song.mp3"])
        #expect(r.source.codec == "aac")                       // not an MP3: no re-encode question (Y7)
        let stages = got.list.map(\.stage)
        #expect(stages.first == .retrieving && stages.last == .completed)
        #expect(got.list.contains { $0.stage == .retrieving && $0.fraction == 1 })
        #expect(try args().filter { $0 == "-f" }.count == 1)   // one download
        let left = try FileManager.default.contentsOfDirectory(atPath: FileManager.default.temporaryDirectory.path)
        #expect(!left.contains { $0.hasPrefix("mmc-youtube-") && $0.contains("download") })
    }

    @Test func untitledTakesTheVideosTitleForTheName() async throws {
        let audio = try await m4a("dl2.m4a")
        let tools = try fake(audio: audio)
        let r = try await ConversionEngine(tools: f.tools).run(
            youTube: video, details: VideoDetails(id: video.id, title: "Named After It", channel: nil, duration: 3),
            using: tools, job: ConversionJob(source: video.url, outputFolder: f.folder)) { _ in }
        #expect(r.outputs.first?.url?.lastPathComponent == "Named After It.wav")
    }

    @Test func retrievalErrorStopsTheJob() async throws {
        let tools = try fake(error: "ERROR: [youtube] RMxRDTfzgpU: Video unavailable")
        await #expect(throws: YouTubeError.unavailable("ERROR: [youtube] RMxRDTfzgpU: Video unavailable")) {
            try await ConversionEngine(tools: f.tools).run(
                youTube: video, details: nil, using: tools,
                job: ConversionJob(source: video.url, outputFolder: f.folder)) { _ in }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.folder.path).filter { $0.hasSuffix(".wav") }.isEmpty)
    }

    @Test func cancellingTheDownload() async throws {
        let audio = try await m4a("slow.m4a")
        let tools = try fake(audio: audio, delay: 10)
        let started = Date()
        let task = Task {
            try await ConversionEngine(tools: f.tools).run(
                youTube: video, details: nil, using: tools,
                job: ConversionJob(source: video.url, outputFolder: f.folder)) { _ in }
        }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        await #expect(throws: ConversionError.cancelled(kept: [])) { try await task.value }
        #expect(Date().timeIntervalSince(started) < 5)
        #expect(try FileManager.default.contentsOfDirectory(atPath: f.folder.path).filter { $0.hasSuffix(".wav") }.isEmpty)
    }

    // MARK: Live (only when asked: MMC_LIVE_YOUTUBE_URL; §13.4)

    @Test(.enabled(if: ProcessInfo.processInfo.environment["MMC_LIVE_YOUTUBE_URL"] != nil))
    func live() async throws {
        let text = ProcessInfo.processInfo.environment["MMC_LIVE_YOUTUBE_URL"]!
        let video = try YouTubeVideo.parse(text).get()
        let tools = try YouTubeTools.locate(tools: f.tools)
        let details = try await YouTubeSource(tools: tools).lookUp(video)
        let r = try await ConversionEngine(tools: f.tools).run(
            youTube: video, details: details, using: tools,
            job: ConversionJob(source: video.url, outputFolder: f.folder, title: details.title, outputs: .both)) { _ in }
        #expect(r.stage == .completed, "\(r.outputs.map(\.problems))")
        #expect(r.outputs.count == 2)
    }
}
