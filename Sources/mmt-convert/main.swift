import Foundation
import MacMusicTransferKit

// mmt-convert: converts one audio file into a WAV MacMusic can import
// (decision S5; a developer's tool until the app's window does it).
//
//   mmt-convert <input> <output.wav> [--title "Title"]

var args = Array(CommandLine.arguments.dropFirst())
var title: String?
if let i = args.firstIndex(of: "--title"), i + 1 < args.count {
    title = args[i + 1]
    args.removeSubrange(i...(i + 1))
}
guard args.count == 2 else {
    FileHandle.standardError.write(Data("usage: mmt-convert <input> <output.wav> [--title \"Title\"]\n".utf8))
    exit(2)
}

do {
    let converter = MacMusicConverter(tools: try Tools.locate())
    let result = try await converter.convert(MacMusicConversion(
        input: URL(fileURLWithPath: args[0]), output: URL(fileURLWithPath: args[1]), title: title))
    let s = result.source
    print("source:  \(s.codec), \(s.sampleRate) Hz, \(s.channels) channel(s)"
          + (s.duration.map { String(format: ", %.2f s", $0) } ?? ""))
    let r = result.report
    print("output:  \(result.output.path)")
    print("         PCM \(r.bitsPerSample)-bit, \(r.sampleRate) Hz, \(r.channels) channel, "
          + String(format: "%.2f s, %d bytes of audio", r.duration, r.dataLength))
    print("         title: \(r.title ?? "(none)")")
    print("checks:  MacMusic's rules passed; ffprobe reads \(result.checked.codec); decodes cleanly")
    for w in result.warnings { print("warning: \(w)") }
} catch {
    FileHandle.standardError.write(Data("mmt-convert: \(error)\n".utf8))
    exit(1)
}
