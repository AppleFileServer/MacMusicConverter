import Foundation
import Testing
@testable import MacMusicConverterKit

/// Loudness levelling through the engine (L3-L8): real conversions by
/// FFmpeg, measured afterwards.
@Suite struct LevellingTests {
    let f: Fixtures
    let engine: ConversionEngine
    init() throws {
        f = try Fixtures()
        engine = ConversionEngine(tools: f.tools)
    }

    func run(_ source: URL, _ options: ConversionOptions = ConversionOptions(levelling: .loudness),
             outputs: OutputSelection = .wav) async throws -> JobResult {
        try await engine.run(ConversionJob(source: source, outputFolder: f.folder,
                                           options: options, conflict: .refuse, outputs: outputs,
                                           reencodeConfirmed: true))
    }

    /// Music-like noise: pink, with nothing above 8 kHz (the WAV keeps up
    /// to 11 kHz, so resampling takes nothing audible away), turned down
    /// by `dB`. At 0 dB it measures about −22 LUFS and peaks about −8 dBFS
    /// (FFmpeg's pink noise is far quieter than its amplitude).
    func noise(_ name: String, dB: Double, seconds: Int = 6) async throws -> URL {
        try await f.pcm(name, source: "anoisesrc=color=pink:amplitude=1:d=\(seconds),lowpass=f=8000,volume=\(dB)dB")
    }

    /// A steady tone with a short burst every second: loud peaks over a
    /// quiet average, for the limiter.
    func bursts(_ name: String, tone: Double, burst: Double) async throws -> URL {
        try await f.pcm(name, source: "aevalsrc='\(tone)*sin(2*PI*440*t)+\(burst)*lt(mod(t\\,1)\\,0.01)*sin(2*PI*2000*t)':d=6:s=44100")
    }

    /// The WAV's checks for every levelled output: near the target, the
    /// peak held, the length kept.
    func expectLevelled(_ r: JobResult, target: Double = -12, _ where_: String = "") {
        let wav = r.outputs[0]
        #expect(wav.succeeded, "\(where_): \(wav.problems)")
        #expect(wav.loudness != nil && abs(wav.loudness! - target) <= 1,
                "\(where_): \(String(describing: wav.loudness)) LUFS")
        #expect(wav.peak != nil && wav.peak! <= ConversionOptions.ceiling + 0.5,
                "\(where_): peak \(String(describing: wav.peak))")
        #expect(abs(wav.report!.duration - r.analysis.duration) < 0.005,
                "\(where_): \(wav.report!.duration) s from \(r.analysis.duration) s")
    }

    @Test func quietSourceIsRaised() async throws {
        let r = try await run(try await noise("quiet.wav", dB: -8))
        #expect(r.levelling == .loudness)
        guard case .gain(let dB, false) = r.normalisation else { Issue.record("\(r.normalisation)"); return }
        #expect(dB > 0)
        expectLevelled(r, "quiet")
    }

    @Test func loudSourceIsLowered() async throws {
        // A loud steady tone, about −6 LUFS.
        let r = try await run(try await f.pcm("loud.wav", source: "aevalsrc='0.7*sin(2*PI*440*t)':d=6:s=44100"))
        #expect(r.normalisation.dB < 0, "\(r.normalisation)")
        expectLevelled(r, "loud")
    }

    @Test func anotherTarget() async throws {
        let r = try await run(try await noise("target.wav", dB: -8),
                              ConversionOptions(levelling: .loudness, loudnessTarget: -16))
        expectLevelled(r, target: -16, "−16")
    }

    /// Peaks over the ceiling after the gain are held by the limiter; a
    /// few dB of it is no cause for a warning.
    @Test func peaksAreLimited() async throws {
        let r = try await run(try await bursts("peaky.wav", tone: 0.1, burst: 0.3))
        #expect(r.limited != nil && r.limited! > 1 && r.limited! < Limiter.warnAbove, "\(String(describing: r.limited))")
        expectLevelled(r, "peaky")
        #expect(!r.outputs[0].warnings.contains { $0.contains("squashed") })
    }

    /// L7: much more, and the result says it may sound squashed.
    @Test func heavyLimitingIsWarnedAbout() async throws {
        let r = try await run(try await bursts("spiky.wav", tone: 0.1, burst: 0.95))
        #expect(r.limited != nil && r.limited! > Limiter.warnAbove, "\(String(describing: r.limited))")
        #expect(r.outputs[0].warnings.contains { $0.contains("squashed") }, "\(r.outputs[0].warnings)")
        #expect(r.outputs[0].peak! <= ConversionOptions.ceiling + 0.5)
    }

    /// L4: the +20 dB cap holds, and missing the target then isn't warned
    /// about (it couldn't be reached).
    @Test func veryQuietIsCapped() async throws {
        let r = try await run(try await noise("faint.wav", dB: -20))
        #expect(r.normalisation == .gain(dB: 20, capped: true), "\(r.normalisation)")
        #expect(r.outputs[0].succeeded)
        #expect(!r.outputs[0].warnings.contains { $0.contains("LUFS") })
    }

    @Test func silenceIsLeftAlone() async throws {
        let r = try await run(try await f.pcm("silent.wav", source: "anullsrc=r=44100:cl=stereo:d=3"))
        guard case .skipped = r.normalisation else { Issue.record("\(r.normalisation)"); return }
        #expect(r.limited == nil)
        #expect(r.outputs[0].succeeded)
    }

    /// L6: the MP3 gets the same gain and limiter; both come out near the
    /// target and the same length.
    @Test func bothOutputsAreLevelled() async throws {
        let r = try await run(try await bursts("both.wav", tone: 0.1, burst: 0.3), outputs: .both)
        expectLevelled(r, "both, WAV")
        let mp3 = r.outputs[1]
        #expect(mp3.kind == .mp3 && mp3.succeeded, "\(mp3.problems)")
        #expect(mp3.loudness != nil && abs(mp3.loudness! - -12) <= 1, "\(String(describing: mp3.loudness))")
        #expect(abs((mp3.checked?.duration ?? 0) - r.analysis.duration) < 0.1)
    }

    /// Peak (1.0's Normalise) is as it was: no limiter, the peak at −1.
    @Test func peakIsUnchanged() async throws {
        let r = try await run(try await bursts("peak.wav", tone: 0.1, burst: 0.3), ConversionOptions(normalise: true))
        #expect(r.levelling == .peak && r.limited == nil)
        #expect(abs(r.outputs[0].peak! - -1) < 0.6, "\(r.outputs[0].peak!)")
        #expect(r.outputs[0].loudness == nil)
    }
}
