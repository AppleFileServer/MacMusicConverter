import Foundation
import Testing
@testable import MacMusicConverterKit

/// The gain and trim decisions, as plain arithmetic (N2-N4).
@Suite struct ProcessingTests {
    func analysis(frames: Int, first: Int?, last: Int?, peak: Float = 0.5) -> AudioAnalysis {
        AudioAnalysis(sampleRate: 1000, channels: 1, frames: frames, channelPeaks: [peak],
                      firstSound: first, lastSound: last, brokenSamples: 0)
    }

    @Test func gainReachesTheTarget() {
        let n = Normalisation.decide(peak: 0.25, target: -1)        // -12.04 dBFS
        guard case .gain(let dB, let capped) = n else { Issue.record("\(n)"); return }
        #expect(abs(dB - 11.04) < 0.01 && !capped)
    }

    @Test func loudSourcesAreLowered() {
        #expect(Normalisation.decide(peak: 1.0, target: -1) == .gain(dB: -1, capped: false))
    }

    @Test func quietSourcesAreCapped() {
        #expect(Normalisation.decide(peak: 0.01, target: -1) == .gain(dB: 20, capped: true))   // -40 dBFS
    }

    @Test func silenceIsNotNormalised() {
        guard case .skipped = Normalisation.decide(peak: 0.001, target: -1) else {
            Issue.record("a -60 dBFS source was normalised"); return
        }
        guard case .skipped = Normalisation.decide(peak: 0, target: -1) else {
            Issue.record("silence was normalised"); return
        }
    }

    @Test func longSilenceIsCutToAGap() {
        // 4 s of silence, sound from 4 s to 7 s, 3 s of silence, at 1000/s.
        let t = Trim.decide(analysis(frames: 10_000, first: 4_000, last: 6_999), threshold: 2)
        #expect(t.start == 3_500 && t.end == 7_500)
        #expect(t.cutFromStart == 3.5 && t.cutFromEnd == 2.5)
    }

    @Test func shortSilenceIsKept() {
        let t = Trim.decide(analysis(frames: 10_000, first: 1_500, last: 8_499), threshold: 2)
        #expect(t.start == 0 && t.end == 10_000 && !t.trims)
    }

    @Test func thresholdOfThree() {
        // 2.5 s of silence at the end: cut at 2 s, kept at 3 s.
        let a = analysis(frames: 10_000, first: 4_000, last: 7_499)
        #expect(Trim.decide(a, threshold: 2).cutFromEnd == 2.0)
        #expect(Trim.decide(a, threshold: 3).cutFromEnd == 0)
        #expect(Trim.decide(a, threshold: 3).cutFromStart == 3.5)
    }

    @Test func allSilentIsNotTrimmedAway() {
        let t = Trim.decide(analysis(frames: 5_000, first: nil, last: nil), threshold: 2)
        #expect(t.start == 0 && t.end == 5_000 && t.note != nil)
    }

    @Test func filterOrder() {
        let t = Trim(start: 10, end: 20, sampleRate: 44_100, cutFromStart: 1, cutFromEnd: 1, note: nil)
        let f = ConversionEngine.filter(channels: 2, trim: t, gain: 3)
        let order = ["atrim", "volume", "pan", "aresample"].map { f.range(of: $0)!.lowerBound }
        #expect(order == order.sorted())
        #expect(!ConversionEngine.filter(channels: 1).contains("pan"))
    }
}
