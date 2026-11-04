import Foundation

/// How the sound is to be changed, decided once from the analysis and
/// applied to every output alike (§6.3; decisions N2-N4).

public enum Normalisation: Sendable, Equatable {
    /// Not asked for.
    case off
    /// Asked for, but not done: the source is effectively silent (N3).
    case skipped(reason: String)
    /// The gain to apply, in dB (negative lowers it); `capped` when the
    /// +20 dB limit held it back (N3).
    case gain(dB: Double, capped: Bool)

    public static let maximumGain = 20.0

    /// From the source's loudest channel (N2), to reach `target` dBFS.
    public static func decide(peak: Float, target: Double) -> Normalisation {
        guard peak.isFinite, peak > AudioAnalyser.silenceThreshold else {
            return .skipped(reason: "The source is too quiet to normalise: it never rises above −50 dBFS.")
        }
        let needed = target - 20 * log10(Double(peak))
        if needed > maximumGain { return .gain(dB: maximumGain, capped: true) }
        return .gain(dB: needed, capped: false)
    }

    /// L4: from the mono mix's loudness, to reach `target` LUFS; the same
    /// +20 dB cap, and nothing for a source that never rises above
    /// −50 dBFS (N3) or that the meter finds no loudness in.
    public static func decide(loudness: Double?, peak: Float, target: Double) -> Normalisation {
        guard peak.isFinite, peak > AudioAnalyser.silenceThreshold, let loudness, loudness.isFinite else {
            return .skipped(reason: "The source is too quiet to level: it never rises above −50 dBFS.")
        }
        let needed = target - loudness
        if needed > maximumGain { return .gain(dB: maximumGain, capped: true) }
        return .gain(dB: needed, capped: false)
    }

    public var dB: Double {
        if case .gain(let dB, _) = self { return dB }
        return 0
    }
}

/// L5, L7: what the limiter is expected to take off the loudest peak, in
/// dB: the source's loudest channel after the gain, above the ceiling. It
/// bounds the WAV's figure (the mono mix's peak can only be lower).
public enum Limiter {
    /// L7: more than this, and the song may sound squashed.
    public static let warnAbove = 6.0

    public static func reduction(peak: Float, gain: Double,
                                 ceiling: Double = ConversionOptions.ceiling) -> Double {
        guard peak.isFinite, peak > 0 else { return 0 }
        return max(0, 20 * log10(Double(peak)) + gain - ceiling)
    }

    /// FFmpeg's alimiter at the ceiling: 5 ms attack, 50 ms release, no
    /// gain of its own (level=0), and its delay taken back (latency=1) so
    /// the length is unchanged.
    public static func filter(ceiling: Double = ConversionOptions.ceiling) -> String {
        String(format: "alimiter=limit=%.6f:attack=5:release=50:level=0:latency=1", pow(10, ceiling / 20))
    }
}

/// The part of the source to keep (S7, N4), in frames at its own rate.
public struct Trim: Sendable, Equatable {
    public let start: Int
    public let end: Int            // exclusive
    public let sampleRate: Int
    /// What was cut from each end, in seconds; 0 if nothing.
    public let cutFromStart: Double
    public let cutFromEnd: Double
    /// Why nothing was cut, when trimming was asked for but not done.
    public let note: String?

    public static let gap = 0.5

    public var duration: Double { Double(end - start) / Double(max(sampleRate, 1)) }
    public var trims: Bool { cutFromStart > 0 || cutFromEnd > 0 }

    /// Everything: no trim.
    public static func whole(_ a: AudioAnalysis, note: String? = nil) -> Trim {
        Trim(start: 0, end: a.frames, sampleRate: a.sampleRate, cutFromStart: 0, cutFromEnd: 0, note: note)
    }

    /// Silence at an end lasting longer than `threshold` seconds is cut down
    /// to a half-second gap; the middle is never touched (S7).
    public static func decide(_ a: AudioAnalysis, threshold: Double) -> Trim {
        guard let first = a.firstSound, let last = a.lastSound else {
            return whole(a, note: "The whole source is silent, so nothing was trimmed.")
        }
        let rate = Double(a.sampleRate)
        let limit = Int(threshold * rate), gapFrames = Int(gap * rate)
        let leading = first, trailing = a.frames - 1 - last
        let start = leading > limit ? first - gapFrames : 0
        let end = trailing > limit ? last + 1 + gapFrames : a.frames
        return Trim(start: start, end: end, sampleRate: a.sampleRate,
                    cutFromStart: Double(start) / rate,
                    cutFromEnd: Double(a.frames - end) / rate, note: nil)
    }
}
