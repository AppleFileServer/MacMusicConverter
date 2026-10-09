import Foundation
import MacMusicTransferKit

// mmt-convert: converts one audio file into a WAV MacMusic can import
// (decision S5; a developer's tool until the app's window does it).
//
//   mmt-convert <input> <output folder> [--title "Title"] [--name "File name"]
//               [--normalise [dBFS]] [--trim [2|3]] [--wav | --mp3 | --both] [--reencode]
//
// A name that's taken gets the next free one ("Song 2.wav"). An MP3 from
// an MP3 needs --reencode (decision M2).

let usage = "usage: mmt-convert <input> <output folder> [--title T] [--name N] [--normalise [dBFS]] [--trim [2|3]] [--wav | --mp3 | --both] [--reencode]\n"
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
    let engine = ConversionEngine(tools: try Tools.locate())
    let job = ConversionJob(source: URL(fileURLWithPath: args[0]),
                            outputFolder: URL(fileURLWithPath: args[1]),
                            name: name, title: title, options: options, conflict: .uniqueName,
                            outputs: outputs, reencodeConfirmed: reencode)
    let result = try await engine.run(job) { stage in print("  \(stage.rawValue)") }
    let s = result.source, a = result.analysis
    print("source:  \(s.codec), \(s.sampleRate) Hz, \(s.channels) channel(s), "
          + String(format: "%.2f s decoded, peak %.1f dBFS", a.duration, 20 * log10(Double(max(a.peak, 1e-9)))))
    switch result.normalisation {
    case .off: break
    case .skipped(let why): print("normalise: skipped. \(why)")
    case .gain(let dB, let capped):
        print(String(format: "normalise: %+.1f dB", dB) + (capped ? " (the most allowed)" : ""))
    }
    if let t = result.trim {
        if let note = t.note { print("trim:    \(note)") }
        else { print(String(format: "trim:    %.1f s from the start, %.1f s from the end", t.cutFromStart, t.cutFromEnd)) }
    }
    for o in result.outputs {
        let peak = o.peak.map { String(format: ", peak %.1f dBFS", $0) } ?? ""
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
} catch ConversionError.needsReencodeConfirmation {
    FileHandle.standardError.write(Data("""
        mmt-convert: the source is already an MP3. Making a new MP3 from it re-encodes it,
        which loses a little quality (a higher bitrate can't bring it back). To go ahead,
        add --reencode; for the MacMusic WAV alone, use --wav.

        """.utf8))
    exit(3)
} catch {
    FileHandle.standardError.write(Data("mmt-convert: \(error)\n".utf8))
    exit(1)
}
