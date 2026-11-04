import Foundation
import MacMusicConverterKit

// mmc-convert: converts one audio file into a WAV MacMusic can import
// (decision S5; a developer's tool until the app's window does it).
//
//   mmc-convert <input file or YouTube address> <output folder> [--title "Title"] [--name "File name"]
//               [--normalise [dBFS] | --loudness [LUFS]] [--trim [2|3]] [--wav | --mp3 | --both] [--reencode]
//
// --normalise sets the loudest peak (1.0's Normalise, Peak in the window);
// --loudness sets the loudness, −12 LUFS unless given, with a limiter (L1).
//
// A name that's taken gets the next free one ("Song 2.wav"). An MP3 from
// an MP3 needs --reencode (decision M2).

let usage = "usage: mmc-convert <input> <output folder> [--title T] [--name N] [--normalise [dBFS] | --loudness [LUFS]] [--trim [2|3]] [--wav | --mp3 | --both] [--reencode]\n"
var args = Array(CommandLine.arguments.dropFirst())
var options = ConversionOptions()
var title: String?, name: String?

@MainActor func value(after flag: String) -> String? {
    guard let i = args.firstIndex(of: flag) else { return nil }
    let next = i + 1 < args.count ? args[i + 1] : nil
    if let next, !next.hasPrefix("--") {
        args.removeSubrange(i...(i + 1))
        return next
    }
    args.remove(at: i)
    return ""
}
if let t = value(after: "--title") { title = t }
if let n = value(after: "--name") { name = n }
if let n = value(after: "--normalise") {
    options.normalise = true
    if let dB = Double(n) { options.target = dB }
}
if let n = value(after: "--loudness") {
    options.levelling = .loudness
    if let lufs = Double(n) { options.loudnessTarget = lufs }
}
if let t = value(after: "--trim") {
    options.trimSilence = true
    if let s = Double(t) { options.trimThreshold = s }
}
var outputs = OutputSelection.wav
for (flag, choice) in [("--mp3", OutputSelection.mp3), ("--both", .both), ("--wav", .wav)] {
    if let i = args.firstIndex(of: flag) { outputs = choice; args.remove(at: i) }
}
var reencode = false
if let i = args.firstIndex(of: "--reencode") { reencode = true; args.remove(at: i) }
guard args.count == 2 else {
    FileHandle.standardError.write(Data(usage.utf8))
    exit(2)
}

do {
    let tools = try Tools.locate()
    let engine = ConversionEngine(tools: tools)
    // A YouTube address (and not a file of that name): look it up, then
    // retrieve and convert (Stage 5).
    var youTube: (YouTubeVideo, VideoDetails, YouTubeTools)?
    if !FileManager.default.fileExists(atPath: args[0]), args[0].contains("://") || args[0].contains("youtu"),
       case .failure(let problem) = YouTubeVideo.parse(args[0]) {
        FileHandle.standardError.write(Data("mmc-convert: \(problem.message.summary)\n".utf8))
        exit(1)
    }
    if !FileManager.default.fileExists(atPath: args[0]), case .success(let video) = YouTubeVideo.parse(args[0]) {
        let yt = try YouTubeTools.locate(tools: tools)
        let details = try await YouTubeSource(tools: yt).lookUp(video)
        print("video:   \(details.title)" + (details.channel.map { " (\($0))" } ?? ""))
        youTube = (video, details, yt)
        if title == nil { title = details.title }
    }
    var job = ConversionJob(source: youTube?.0.url ?? URL(fileURLWithPath: args[0]),
                            outputFolder: URL(fileURLWithPath: args[1]),
                            name: name, title: title, options: options, conflict: .uniqueName,
                            outputs: outputs, reencodeConfirmed: reencode)
    job.sourceName = youTube?.1.title
    let stages = StageLog()
    let result: JobResult
    if let (video, details, yt) = youTube {
        result = try await engine.run(youTube: video, details: details, using: yt, job: job) { stages.note($0.stage) }
    } else {
        result = try await engine.run(job) { stage in print("  \(stage.rawValue)") }
    }
    let s = result.source, a = result.analysis
    print("source:  \(s.codec), \(s.sampleRate) Hz, \(s.channels) channel(s), "
          + String(format: "%.2f s decoded, peak %.1f dBFS", a.duration, 20 * log10(Double(max(a.peak, 1e-9)))))
    if let l = a.loudness { print(String(format: "         loudness %.1f LUFS (the mono mix)", l)) }
    let how = result.levelling == .loudness ? "loudness" : "normalise"
    switch result.normalisation {
    case .off: break
    case .skipped(let why): print("\(how): skipped. \(why)")
    case .gain(let dB, let capped):
        print(String(format: "\(how): %+.1f dB", dB) + (capped ? " (the most allowed)" : "")
              + (result.limited.map { String(format: "; the limiter takes off up to %.1f dB", $0) } ?? ""))
    }
    if let t = result.trim {
        if let note = t.note { print("trim:    \(note)") }
        else { print(String(format: "trim:    %.1f s from the start, %.1f s from the end", t.cutFromStart, t.cutFromEnd)) }
    }
    for o in result.outputs {
        let peak = (o.peak.map { String(format: ", peak %.1f dBFS", $0) } ?? "")
            + (o.loudness.map { String(format: ", %.1f LUFS", $0) } ?? "")
        if let url = o.url, let r = o.report {
            print("output:  \(url.path)")
            print("         \(o.kind.rawValue): \(r.bitsPerSample)-bit, \(r.sampleRate) Hz, \(r.channels) channel, "
                  + String(format: "%.2f s, %d bytes", r.duration, o.size ?? 0) + peak)
            print("         title: \(r.title ?? "(none)")")
        } else if let url = o.url, let c = o.checked {
            print("output:  \(url.path)")
            print("         \(o.kind.rawValue): \((c.bitRate ?? 0) / 1000) kbps, \(c.sampleRate) Hz, \(c.channels) channel(s), "
                  + String(format: "%.2f s, %d bytes", c.duration ?? 0, o.size ?? 0) + peak)
            print("         title: \(c.title ?? "(none)")")
        } else {
            print("output:  \(o.kind.rawValue) FAILED")
        }
        for p in o.problems { print("problem: \(p)") }
        for w in o.warnings { print("warning: \(w)") }
    }
    print("result:  \(result.stage.rawValue)")
    exit(result.stage == .completed ? 0 : 1)
} catch let error as YouTubeError {
    let m = error.message
    FileHandle.standardError.write(Data("mmc-convert: \(m.summary)\n\(m.detail ?? "")\n".utf8))
    exit(1)
} catch ConversionError.needsReencodeConfirmation {
    FileHandle.standardError.write(Data("""
        mmc-convert: the source is already an MP3. Making a new MP3 from it re-encodes it,
        which loses a little quality (a higher bitrate can't bring it back). To go ahead,
        add --reencode; for the MacMusic WAV alone, use --wav.

        """.utf8))
    exit(3)
} catch {
    FileHandle.standardError.write(Data("mmc-convert: \(error)\n".utf8))
    exit(1)
}

/// Prints each stage once.
final class StageLog: @unchecked Sendable {
    private let lock = NSLock()
    private var last: JobStage?
    func note(_ s: JobStage) {
        let new: Bool = lock.withLock { defer { last = s }; return last != s }
        if new { print("  \(s.rawValue)") }
    }
}
