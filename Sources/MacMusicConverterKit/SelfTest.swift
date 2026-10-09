import Foundation

/// The packaged app's self-test (decision P5): run as
/// `MacMusic Converter Utility.app/Contents/MacOS/MacMusicConverter --self-test`,
/// it opens no window, finds the tools in `helpers` only (the app's own,
/// so a release is shown to be self-contained), converts a generated
/// one-second tone into both outputs in a temporary folder, checks them
/// with the engine's own checks, and reports.
public enum SelfTest {
    public static func run(helpers: URL?, pinned: Bool = false) async -> (passed: Bool, report: [String]) {
        var report: [String] = []
        func say(_ s: String) { report.append(s) }
        say("MacMusic Converter Utility \(AppVersion.string): self-test")
        let tools: Tools
        let yt: YouTubeTools
        do {
            tools = try Tools.locate(environment: [:], helpers: helpers,
                                     pinned: pinned ? Tools.pinnedFolder : nil)
            yt = try YouTubeTools.locate(tools: tools, environment: [:], helpers: helpers, pinned: pinned)
        } catch {
            say("FAIL: the tools weren't found (\(error))")
            return (false, report)
        }
        let runner = ProcessRunner()
        for (name, url, args) in [("ffmpeg", tools.ffmpeg, ["-hide_banner", "-version"]),
                                  ("ffprobe", tools.ffprobe, ["-hide_banner", "-version"]),
                                  ("yt-dlp", yt.ytdlp, ["--version"]),
                                  ("deno", yt.deno, ["--version"])] {
            guard let out = try? await runner.run(url, arguments: args), out.status == 0 else {
                say("FAIL: \(name) at \(url.path) doesn't run")
                return (false, report)
            }
            say("ok    \(name): \(out.stdoutText.split(separator: "\n").first ?? "") (\(url.path))")
        }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mmc-selftest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let tone = folder.appendingPathComponent("tone.wav")
            let made = try await runner.run(tools.ffmpeg, arguments: [
                "-nostdin", "-v", "error", "-f", "lavfi", "-i", "sine=f=440:d=1",
                "-ac", "2", "-c:a", "pcm_s16le", tone.path])
            guard made.status == 0 else { say("FAIL: the test tone couldn't be made"); return (false, report) }
            let r = try await ConversionEngine(tools: tools).run(ConversionJob(
                source: tone, outputFolder: folder, name: "Self Test", title: "Self Test",
                options: ConversionOptions(normalise: true), outputs: .both))
            for o in r.outputs {
                if o.succeeded {
                    say("ok    \(o.kind.rawValue): \(o.url?.lastPathComponent ?? "") passed its checks")
                } else {
                    say("FAIL: \(o.kind.rawValue): \(o.problems.joined(separator: "; "))")
                }
            }
            guard r.stage == .completed else { return (false, report) }
        } catch {
            say("FAIL: the conversion stopped: \(error)")
            return (false, report)
        }
        say("PASSED")
        return (true, report)
    }
}
