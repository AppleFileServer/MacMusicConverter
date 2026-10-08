import Foundation
import Testing
@testable import MacMusicTransferKit

/// Real conversions with FFmpeg, from fixtures made on the spot (§13.2).
@Suite struct ConversionTests {
    let f: Fixtures
    let converter: MacMusicConverter
    init() throws {
        f = try Fixtures()
        converter = MacMusicConverter(tools: f.tools)
    }

    func convert(_ input: URL, title: String? = nil) async throws -> MacMusicConversionResult {
        try await converter.convert(MacMusicConversion(
            input: input, output: f.url(input.deletingPathExtension().lastPathComponent + ".wav"),
            title: title))
    }

    @Test func stereoMP3() async throws {
        let mp3 = try await f.mp3("stereo.mp3", source: "sine=f=440:d=3")
        let r = try await convert(mp3, title: "A Tone")
        #expect(r.report.accepted)
        #expect(r.report.title == "A Tone")
        #expect(abs(r.report.duration - 3) < 0.1)
        #expect(r.checked.codec == "pcm_u8")
    }

    @Test func monoAnd48k() async throws {
        let mono = try await f.mp3("mono.mp3", source: "sine=f=300:d=2", channels: 1)
        let khz48 = try await f.mp3("k48.mp3", source: "sine=f=300:d=2", rate: 48_000)
        #expect(try await convert(mono).report.accepted)
        #expect(try await convert(khz48).report.accepted)
    }

    @Test func lowBitrateAndVeryShort() async throws {
        let low = try await f.mp3("low.mp3", source: "sine=f=500:d=2", rate: 22_050, channels: 1, bitrate: "32k")
        let short = try await f.mp3("short.mp3", source: "sine=f=500:d=0.2")
        #expect(try await convert(low).report.accepted)
        let r = try await convert(short)
        #expect(r.report.accepted && r.report.dataLength > 0)
    }

    /// Mono is the average of the channels, not the left alone (§5.4): a
    /// tone in the right channel only comes out at half the level of the
    /// same tone in both. (FFmpeg's sine is at 1/8 of full scale; volume=6
    /// brings it to 3/4; the pans set each channel exactly.)
    @Test func downmixAveragesTheChannels() async throws {
        let both = try await f.mp3("both.mp3", source: "sine=f=440:d=2,volume=6,pan=stereo|c0=c0|c1=c0")
        let right = try await f.mp3("right.mp3",
            source: "sine=f=440:d=2,volume=6,pan=stereo|c0=0*c0|c1=c0")
        func peak(_ url: URL) throws -> Int {
            try f.samples(url).map { abs(Int($0) - 128) }.max() ?? 0
        }
        let full = try peak(try await convert(both).output)
        let half = try peak(try await convert(right).output)
        #expect(full > 80, "a 3/4-scale tone peaked at \(full)")
        #expect(abs(Double(half) / Double(full) - 0.5) < 0.1, "right only: \(half) of \(full)")
    }

    @Test func silenceStaysSilentAndFullLength() async throws {
        let quiet = try await f.mp3("silent.mp3", source: "anullsrc=r=44100:cl=stereo:d=2")
        let r = try await convert(quiet)
        #expect(r.report.accepted && abs(r.report.duration - 2) < 0.1)
        let samples = try f.samples(r.output)
        #expect(samples.allSatisfy { abs(Int($0) - 128) <= 1 })   // dither only
    }

    @Test func corruptInputIsRefused() async throws {
        let junk = f.url("junk.mp3")
        try Data((0..<5000).map { UInt8(truncatingIfNeeded: $0 &* 7919) }).write(to: junk)
        await #expect(throws: ConversionError.self) { try await convert(junk) }
        #expect(!FileManager.default.fileExists(atPath: f.url("junk.wav").path))
    }

    @Test func truncatedInputStillConverts() async throws {
        let mp3 = try await f.mp3("whole.mp3", source: "sine=f=440:d=4")
        let data = try Data(contentsOf: mp3)
        let cut = f.url("cut.mp3")
        try data.prefix(data.count / 2).write(to: cut)
        // A cut MP3 decodes up to the cut: converted, checked against what
        // was really there, and reported as damaged.
        let r = try await convert(cut)
        #expect(r.report.accepted && abs(r.report.duration - 2) < 0.2)
        #expect(r.warnings.contains { $0.contains("damaged or cut short") })
    }

    /// Never overwrites, and never changes the source (§9.3).
    @Test func existingOutputAndSourceAreLeftAlone() async throws {
        let mp3 = try await f.mp3("keep.mp3", source: "sine=f=440:d=1")
        let before = try Data(contentsOf: mp3)
        let existing = f.url("keep.wav")
        try Data("mine".utf8).write(to: existing)
        await #expect(throws: ConversionError.outputExists(existing.path)) { try await convert(mp3) }
        #expect(try Data(contentsOf: existing) == Data("mine".utf8))
        #expect(try Data(contentsOf: mp3) == before)
        let left = try FileManager.default.contentsOfDirectory(atPath: f.folder.path)
        #expect(!left.contains { $0.hasSuffix(".partial") })
    }
}
