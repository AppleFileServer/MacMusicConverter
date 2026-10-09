import Foundation

/// An audio file's properties, as ffprobe reads them (§9.2): not its
/// extension.
public struct AudioInfo: Sendable, Equatable {
    public let formatName: String
    public let codec: String
    public let sampleRate: Int
    public let channels: Int
    public let bitsPerSample: Int
    public let duration: Double?
    /// The stream's (or else the file's) bit rate, in bits a second.
    public let bitRate: Int?
    /// The file's title tag, if it has one.
    public let title: String?

    public init(formatName: String, codec: String, sampleRate: Int, channels: Int,
                bitsPerSample: Int, duration: Double?, bitRate: Int? = nil, title: String? = nil) {
        self.formatName = formatName
        self.codec = codec
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPerSample = bitsPerSample
        self.duration = duration
        self.bitRate = bitRate
        self.title = title
    }
}

public enum AudioInspectorError: Error, Equatable, Sendable {
    /// ffprobe couldn't read it as media at all.
    case unreadable(String)
    /// It's readable, but has no audio.
    case noAudio
}

public struct AudioInspector: Sendable {
    let tools: Tools
    let runner = ProcessRunner()

    public init(tools: Tools) { self.tools = tools }

    public func inspect(_ url: URL) async throws -> AudioInfo {
        let result = try await runner.run(tools.ffprobe, arguments: [
            "-v", "error", "-print_format", "json",
            "-show_format", "-show_streams", "-select_streams", "a:0",
            "--", url.path,
        ])
        guard result.status == 0 else {
            throw AudioInspectorError.unreadable(result.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        struct Probe: Decodable {
            struct Stream: Decodable {
                let codec_name: String?
                let sample_rate: String?
                let channels: Int?
                let bits_per_sample: Int?
                let duration: String?
                let bit_rate: String?
            }
            struct Format: Decodable {
                let format_name: String?
                let duration: String?
                let bit_rate: String?
                let tags: [String: String]?
            }
            let streams: [Stream]?
            let format: Format?
        }
        let probe = try JSONDecoder().decode(Probe.self, from: result.stdout)
        guard let stream = probe.streams?.first else { throw AudioInspectorError.noAudio }
        return AudioInfo(
            formatName: probe.format?.format_name ?? "",
            codec: stream.codec_name ?? "",
            sampleRate: Int(stream.sample_rate ?? "") ?? 0,
            channels: stream.channels ?? 0,
            bitsPerSample: stream.bits_per_sample ?? 0,
            duration: Double(stream.duration ?? probe.format?.duration ?? ""),
            bitRate: Int(stream.bit_rate ?? probe.format?.bit_rate ?? ""),
            title: probe.format?.tags?.first { $0.key.lowercased() == "title" }?.value)
    }
}
