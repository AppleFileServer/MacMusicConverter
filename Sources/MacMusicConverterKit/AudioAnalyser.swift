import Foundation

/// What one pass over the decoded source found (decision N1): measured
/// from every sample, at the source's own rate, in 32-bit float.
public struct AudioAnalysis: Sendable, Equatable {
    public let sampleRate: Int
    public let channels: Int
    /// Frames decoded: the real length, whatever the file's header says.
    public let frames: Int
    /// Each channel's peak, as a fraction of full scale.
    public let channelPeaks: [Float]
    /// The first and last frame where any channel rises above the silence
    /// threshold; nil if it never does.
    public let firstSound: Int?
    public let lastSound: Int?
    /// Samples that are NaN or infinite: a damaged decode.
    public let brokenSamples: Int

    public var duration: Double { Double(frames) / Double(max(sampleRate, 1)) }
    public var peak: Float { channelPeaks.max() ?? 0 }
}

/// Decodes the source's first audio stream through FFmpeg and measures it,
/// streaming the samples rather than keeping them.
public struct AudioAnalyser: Sendable {
    /// −50 dBFS: just under what 8-bit sound can show (decisions S7, N3, N4).
    public static let silenceThreshold: Float = 0.003_162_278

    let tools: Tools
    let runner = ProcessRunner()

    public init(tools: Tools) { self.tools = tools }

    /// `expectedFrames`, if known (from the file's header), lets it report
    /// how far it has got, 0 to 1, through `progress`.
    public func analyse(_ url: URL, sampleRate: Int, channels: Int, expectedFrames: Int? = nil,
                        progress: (@Sendable (Double) -> Void)? = nil) async throws -> AudioAnalysis {
        let meter = Meter(channels: max(channels, 1))
        meter.expected = expectedFrames
        meter.progress = progress
        let result = try await runner.stream(tools.ffmpeg, arguments: [
            "-nostdin", "-hide_banner", "-v", "error", "-i", url.path,
            "-map", "0:a:0", "-vn",
            "-ac", String(max(channels, 1)), "-ar", String(sampleRate),
            "-f", "f32le", "-c:a", "pcm_f32le", "pipe:1",
        ]) { meter.add($0) }
        guard result.status == 0 else {
            throw ConversionError.sourceUnreadable(result.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return meter.result(sampleRate: sampleRate)
    }

    /// The running measurements. Pieces arrive in order on one thread.
    final class Meter: @unchecked Sendable {
        let channels: Int
        var peaks: [Float]
        var frames = 0
        var firstSound: Int?
        var lastSound: Int?
        var broken = 0
        var leftover = Data()
        var expected: Int?
        var progress: (@Sendable (Double) -> Void)?

        init(channels: Int) {
            self.channels = channels
            peaks = Array(repeating: 0, count: channels)
        }

        func add(_ piece: Data) {
            var bytes = leftover
            bytes.append(piece)
            let frameBytes = 4 * channels
            let whole = bytes.count / frameBytes * frameBytes
            leftover = bytes.subdata(in: whole..<bytes.count)
            bytes.prefix(whole).withUnsafeBytes { raw in
                // Read as unaligned: a Data's bytes needn't be 4-aligned.
                let count = whole / 4
                var i = 0
                while i < count {
                    var loud = false
                    for c in 0..<channels {
                        let x = raw.loadUnaligned(fromByteOffset: (i + c) * 4, as: Float.self)
                        if !x.isFinite { broken += 1; continue }
                        let a = abs(x)
                        if a > peaks[c] { peaks[c] = a }
                        if a > AudioAnalyser.silenceThreshold { loud = true }
                    }
                    if loud {
                        if firstSound == nil { firstSound = frames }
                        lastSound = frames
                    }
                    frames += 1
                    i += channels
                }
            }
            if let expected, expected > 0, let progress {
                progress(min(Double(frames) / Double(expected), 1))
            }
        }

        func result(sampleRate: Int) -> AudioAnalysis {
            AudioAnalysis(sampleRate: sampleRate, channels: channels, frames: frames,
                          channelPeaks: peaks, firstSound: firstSound, lastSound: lastSound,
                          brokenSamples: broken)
        }
    }
}
