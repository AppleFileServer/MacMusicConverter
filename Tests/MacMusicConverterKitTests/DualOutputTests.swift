import Foundation
import Testing
@testable import MacMusicConverterKit

/// MP3 output and both outputs from one job (§2.3, §5.3, §13.3; M1-M7).
@Suite struct DualOutputTests {
    let f: Fixtures
    let engine: ConversionEngine
    init() throws {
        f = try Fixtures()
        engine = ConversionEngine(tools: f.tools)
    }

    func job(_ source: URL, _ outputs: OutputSelection, title: String? = nil,
             options: ConversionOptions = ConversionOptions(), reencode: Bool = false) -> ConversionJob {
        ConversionJob(source: source, outputFolder: f.folder, title: title, options: options,
                      outputs: outputs, reencodeConfirmed: reencode)
    }

    @Test func mp3Only() async throws {
        let wav = try await f.pcm("cd.wav", source: "sine=f=440:d=3")
        let r = try await engine.run(job(wav, .mp3, title: "A Tone"))
        #expect(r.stage == .completed)
        let o = try #require(r.outputs.first)
        #expect(r.outputs.count == 1 && o.kind == .mp3 && o.succeeded, "\(o.problems)")
        let c = try #require(o.checked)
        #expect(c.codec == "mp3" && c.sampleRate == 44_100 && c.channels == 2)
        #expect(abs((c.bitRate ?? 0) - 192_000) < 2_000)
        #expect(c.title == "A Tone")
        #expect(o.url?.lastPathComponent == "A Tone.mp3")
    }

    @Test func bothFromOneJob() async throws {
        let wav = try await f.pcm("src-both.wav", source: "sine=f=440:d=3")
        let r = try await engine.run(job(wav, .both, title: "Both"))
        #expect(r.stage == .completed)
        #expect(r.outputs.map(\.kind) == [.macMusicWAV, .mp3])
        let allPassed = r.outputs.allSatisfy { $0.succeeded }
        #expect(allPassed, "\(r.outputs.map(\.problems))")
        #expect(r.outputs[0].report?.title == "Both" && r.outputs[1].checked?.title == "Both")
        #expect(FileManager.default.fileExists(atPath: f.url("Both.wav").path))
        #expect(FileManager.default.fileExists(atPath: f.url("Both.mp3").path))
    }

    /// One analysis, one gain and one trim for both (§6.3): the outputs
    /// have the same length and both reach the target.
    @Test func bothShareTheGainAndTrim() async throws {
        let wav = try await f.pcm("src-shape.wav",
            source: "aevalsrc='if(between(t,4,7),0.25*sin(2*PI*440*t),0)|if(between(t,4,7),0.25*sin(2*PI*440*t),0)':d=10:s=44100")
        let r = try await engine.run(job(wav, .both, options: ConversionOptions(normalise: true, trimSilence: true)))
        let (w, m) = (r.outputs[0], r.outputs[1])
        #expect(w.succeeded && m.succeeded, "\(w.problems) \(m.problems)")
        #expect(abs(w.report!.duration - 4) < 0.15)
        #expect(abs((m.checked?.duration ?? 0) - 4) < 0.15)
        #expect(abs(w.peak! - -1) < 0.6 && abs(m.peak! - -1) < 0.6, "\(w.peak!) \(m.peak!)")
    }

    @Test func mp3KeepsStereoAndMonoAndMixesDownSurround() async throws {
        let mono = try await f.pcm("mono.wav", source: "sine=f=440:d=1", channels: 1)
        let surround = try await f.pcm("six.wav", source: "sine=f=440:d=1", channels: 6)
        let k48 = try await f.pcm("k48.wav", source: "sine=f=440:d=1", rate: 48_000)
        let k96 = try await f.pcm("k96.wav", source: "sine=f=440:d=1", rate: 96_000)
        #expect(try await engine.run(job(mono, .mp3)).outputs[0].checked?.channels == 1)
        #expect(try await engine.run(job(surround, .mp3)).outputs[0].checked?.channels == 2)
        #expect(try await engine.run(job(k48, .mp3)).outputs[0].checked?.sampleRate == 48_000)
        #expect(try await engine.run(job(k96, .mp3)).outputs[0].checked?.sampleRate == 48_000)
    }

    /// An MP3 from an MP3 stops before doing anything, unless confirmed
    /// (M2); the WAV alone needs no confirmation.
    @Test func mp3FromMP3NeedsConfirmation() async throws {
        let mp3 = try await f.mp3("song.mp3", source: "sine=f=440:d=1")
        await #expect(throws: ConversionError.needsReencodeConfirmation) {
            try await engine.run(job(mp3, .both))
        }
        let left = try FileManager.default.contentsOfDirectory(atPath: f.folder.path)
        #expect(left == ["song.mp3"], "\(left)")
        #expect(try await engine.run(job(mp3, .wav)).stage == .completed)
        // Confirmed, it goes ahead; named like its source, it gets the next
        // free name rather than overwrite it.
        let r = try await engine.run(job(mp3, .mp3, reencode: true))
        #expect(r.stage == .completed && r.outputs[0].url?.lastPathComponent == "song 2.mp3")
    }

    /// One output failing leaves the other, and says so (§2.3, §13.3).
    @Test func oneFailingKeepsTheOther() async throws {
        let wav = try await f.pcm("src-part.wav", source: "sine=f=440:d=1")
        var broken = engine
        broken.faults = [.mp3]
        let r = try await broken.run(job(wav, .both, title: "Part"))
        #expect(r.stage == .completedWithErrors)
        #expect(r.outputs[0].succeeded && !r.outputs[1].succeeded)
        #expect(r.outputs[1].url == nil && !r.outputs[1].problems.isEmpty)
        #expect(FileManager.default.fileExists(atPath: f.url("Part.wav").path))
        #expect(!FileManager.default.fileExists(atPath: f.url("Part.mp3").path))
        let left = try FileManager.default.contentsOfDirectory(atPath: f.folder.path)
        #expect(!left.contains { $0.hasSuffix(".partial") })

        broken.faults = [.macMusicWAV]
        let other = try await broken.run(job(wav, .both, title: "Other"))
        #expect(other.stage == .completedWithErrors && !other.outputs[0].succeeded && other.outputs[1].succeeded)

        broken.faults = [.macMusicWAV, .mp3]
        #expect(try await broken.run(job(wav, .both, title: "None")).stage == .failed)
    }

    @Test func titleWithAnyCharactersInTheMP3() async throws {
        let wav = try await f.pcm("u.wav", source: "sine=f=440:d=1")
        let r = try await engine.run(job(wav, .both, title: "Café \u{2014} Москва"))
        #expect(r.outputs[1].checked?.title == "Café \u{2014} Москва")       // the MP3 keeps it all
        #expect(r.outputs[0].report?.title == "Café - Moskva")                // the WAV, as MacMusic will
    }

    @Test func noTitleNoTag() async throws {
        let wav = try await f.pcm("plain.wav", source: "sine=f=440:d=1")
        let r = try await engine.run(job(wav, .mp3))
        #expect(r.outputs[0].checked?.title == nil)
        #expect(r.outputs[0].url?.lastPathComponent == "plain.mp3")
    }

    @Test func cancellingBothLeavesNothing() async throws {
        let wav = try await f.pcm("long.wav", source: "sine=f=440:d=600")
        let task = Task { try await engine.run(job(wav, .both)) }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("it wasn't cancelled")
        } catch ConversionError.cancelled(let kept) {
            // Anything kept is a finished, checked output (§11.2).
            for path in kept { #expect(MacMusicWAVValidator.check(URL(fileURLWithPath: path)).accepted
                                       || path.hasSuffix(".mp3")) }
        }
        let left = try FileManager.default.contentsOfDirectory(atPath: f.folder.path)
        #expect(!left.contains { $0.hasSuffix(".partial") }, "\(left)")
    }

    /// Even "replace" never overwrites the source (§9.3).
    @Test func theSourceIsNeverReplaced() async throws {
        let wav = try await f.pcm("Same.wav", source: "sine=f=440:d=1")
        let before = try Data(contentsOf: wav)
        let r = try await engine.run(ConversionJob(source: wav, outputFolder: f.folder, conflict: .replace))
        #expect(r.outputs[0].url?.lastPathComponent == "Same 2.wav")
        #expect(try Data(contentsOf: wav) == before)
        // Nor by case alone: this Mac's disk ignores it.
        let lower = try await engine.run(ConversionJob(source: wav, outputFolder: f.folder, name: "same",
                                                       conflict: .replace))
        #expect(lower.outputs[0].url?.lastPathComponent != "same.wav" || !sameFile(lower.outputs[0].url!, wav))
        #expect(try Data(contentsOf: wav) == before)
    }

    @Test func mp3Rates() {
        #expect(MP3Format.sampleRate(for: 44_100) == 44_100)
        #expect(MP3Format.sampleRate(for: 96_000) == 48_000)
        #expect(MP3Format.sampleRate(for: 88_200) == 48_000)
        #expect(MP3Format.sampleRate(for: 7_000) == 44_100)
        #expect(MP3Format.channels(for: 1) == 1 && MP3Format.channels(for: 2) == 2 && MP3Format.channels(for: 6) == 2)
    }
}
