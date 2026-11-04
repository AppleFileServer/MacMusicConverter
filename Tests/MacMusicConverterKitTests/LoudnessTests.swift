import Foundation
import Testing
@testable import MacMusicConverterKit

/// The loudness meter (L2): the standard's figures on known signals, its
/// gates, and agreement with FFmpeg's own EBU R128 meter.
@Suite struct LoudnessTests {
    /// A sine of `amplitude` at `frequency` Hz for `seconds`, fed straight
    /// to a meter.
    func sine(_ amplitude: Double, _ frequency: Double = 1000, seconds: Double,
              rate: Int = 48_000, into meter: inout LoudnessMeter) {
        let n = Int(seconds * Double(rate))
        for i in 0..<n {
            meter.add(amplitude * sin(2 * Double.pi * frequency * Double(i) / Double(rate)))
        }
    }

    func silence(seconds: Double, rate: Int = 48_000, into meter: inout LoudnessMeter) {
        for _ in 0..<Int(seconds * Double(rate)) { meter.add(0) }
    }

    /// BS.1770's calibration: a full-scale 1 kHz sine in one channel reads
    /// −3.01 LUFS, at any sample rate.
    @Test(arguments: [22_050, 44_100, 48_000, 96_000])
    func fullScaleSineIsMinus3(rate: Int) {
        var m = LoudnessMeter(sampleRate: rate)
        sine(1, seconds: 3, rate: rate, into: &m)
        let l = m.integrated
        #expect(l != nil && abs(l! - -3.01) < 0.05, "\(String(describing: l)) at \(rate) Hz")
    }

    @Test func levelFollowsAmplitude() {
        var m = LoudnessMeter(sampleRate: 44_100)
        sine(0.1, seconds: 3, rate: 44_100, into: &m)        // −20 dBFS
        #expect(abs(m.integrated! - -23.01) < 0.05)
    }

    @Test func silenceHasNoLoudness() {
        var m = LoudnessMeter(sampleRate: 48_000)
        silence(seconds: 3, into: &m)
        #expect(m.integrated == nil)
    }

    @Test func tooShortHasNoLoudness() {
        var m = LoudnessMeter(sampleRate: 48_000)
        sine(1, seconds: 0.35, into: &m)                     // under one 400 ms block
        #expect(m.integrated == nil)
    }

    /// Below −70 LUFS counts as nothing.
    @Test func belowTheAbsoluteGateHasNoLoudness() {
        var m = LoudnessMeter(sampleRate: 48_000)
        sine(0.000_1, seconds: 3, into: &m)                  // about −83 LUFS
        #expect(m.integrated == nil)
    }

    /// Silence around a song is gated out. Only the blocks overlapping the
    /// sound count: a 3 s tone fills 27 blocks, and the six that straddle
    /// its edges are 1/4, 1/2 and 3/4 full (within 10 LU, so counted), so
    /// the mean is 30/33 of the tone's power.
    @Test func silenceIsGatedOut() {
        var m = LoudnessMeter(sampleRate: 48_000)
        silence(seconds: 5, into: &m)
        sine(0.1, seconds: 3, into: &m)
        silence(seconds: 5, into: &m)
        let expected = -23.01 + 10 * log10(30.0 / 33.0)      // −23.42
        #expect(abs(m.integrated! - expected) < 0.05, "\(m.integrated!)")
    }

    /// A quiet passage more than 10 LU below the rest is left out by the
    /// relative gate; one within 10 LU is counted.
    @Test func quietPassagesAreGatedRelatively() {
        var far = LoudnessMeter(sampleRate: 48_000)
        sine(0.1, seconds: 10, into: &far)                   // −23 LUFS
        sine(0.01, seconds: 10, into: &far)                  // −43 LUFS
        #expect(abs(far.integrated! - -23.01) < 0.1, "\(far.integrated!)")

        var near = LoudnessMeter(sampleRate: 48_000)
        sine(0.1, seconds: 10, into: &near)                  // −23 LUFS
        sine(0.05, seconds: 10, into: &near)                 // −29 LUFS
        // Both halves counted: the power mean, (1 + 1/4) / 2 of the louder
        // half's power, about −25.05 LUFS.
        #expect(abs(near.integrated! - -25.05) < 0.1, "\(near.integrated!)")
    }

    // MARK: - Against FFmpeg

    /// FFmpeg's ebur128 reading of the mono mix (the channels averaged, as
    /// the WAV is made). Only for checking: the app measures in Swift (N1).
    func ffmpegLoudness(_ url: URL, channels: Int, tools: Tools) async throws -> Double {
        var filter = "ebur128"
        if channels > 1 {
            let share = 1.0 / Double(channels)
            let sum = (0..<channels).map { "\(share)*c\($0)" }.joined(separator: "+")
            filter = "pan=mono|c0=\(sum)," + filter
        }
        let r = try await ProcessRunner().run(tools.ffmpeg, arguments: [
            "-nostdin", "-hide_banner", "-nostats", "-i", url.path, "-af", filter, "-f", "null", "-",
        ])
        // The summary's last "I:" line: "    I:         -18.4 LUFS".
        let line = r.stderrText.split(separator: "\n")
            .last { $0.trimmingCharacters(in: .whitespaces).hasPrefix("I:") }
        let value = line.flatMap { $0.split(separator: " ").dropFirst().first }.flatMap { Double($0) }
        guard let value else { throw FixtureError.ffmpeg("no ebur128 reading: \(r.stderrText)") }
        return value
    }

    /// Music-like sources (noise and tones, stereo and mono, several rates,
    /// level changes and silences) read the same as FFmpeg, within 0.1 LU
    /// (ebur128 prints one decimal place).
    @Test(arguments: [
        ("pink.wav", "anoisesrc=color=pink:amplitude=0.4:d=8", 44_100, 2),
        ("pinkmono.wav", "anoisesrc=color=pink:amplitude=0.2:d=8", 22_050, 1),
        ("brown.wav", "anoisesrc=color=brown:amplitude=0.6:d=8", 48_000, 2),
        ("bass.wav", "aevalsrc='0.5*sin(2*PI*60*t)|0.3*sin(2*PI*90*t)':d=6", 44_100, 2),
        ("treble.wav", "aevalsrc='0.3*sin(2*PI*6000*t)':d=6", 44_100, 1),
        // Loud, then 20 dB down, then silence: both gates at work.
        ("steps.wav", "aevalsrc='(lt(t,4)*0.5+between(t,4,8)*0.05)*sin(2*PI*440*t)|(lt(t,4)*0.4+between(t,4,8)*0.04)*sin(2*PI*660*t)':d=12",
         44_100, 2),
    ])
    func agreesWithFFmpeg(name: String, source: String, rate: Int, channels: Int) async throws {
        let f = try Fixtures()
        defer { f.remove() }
        let url = try await f.pcm(name, source: source, rate: rate, channels: channels)
        let ours = try await AudioAnalyser(tools: f.tools)
            .analyse(url, sampleRate: rate, channels: channels).loudness
        let theirs = try await ffmpegLoudness(url, channels: channels, tools: f.tools)
        #expect(ours != nil && abs(ours! - theirs) <= 0.1,
                "\(name): ours \(String(describing: ours)), FFmpeg \(theirs)")
    }

    /// The analysis of a silent source reports no loudness.
    @Test func silentSourceHasNoLoudness() async throws {
        let f = try Fixtures()
        defer { f.remove() }
        let url = try await f.pcm("silent.wav", source: "anullsrc=r=44100:cl=stereo:d=3")
        let a = try await AudioAnalyser(tools: f.tools).analyse(url, sampleRate: 44_100, channels: 2)
        #expect(a.loudness == nil)
    }
}
