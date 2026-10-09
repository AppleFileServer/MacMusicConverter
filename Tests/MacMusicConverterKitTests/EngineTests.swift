import Foundation
import Testing
@testable import MacMusicConverterKit

/// The engine with its options: normalisation, trimming, conflicts,
/// cancelling and damaged audio (§6, §11, §13.2; N1-N8).
@Suite struct EngineTests {
    let f: Fixtures
    let engine: ConversionEngine
    init() throws {
        f = try Fixtures()
        engine = ConversionEngine(tools: f.tools)
    }

    func run(_ source: URL, _ options: ConversionOptions = ConversionOptions(),
             conflict: ConflictPolicy = .refuse) async throws -> JobResult {
        try await engine.run(ConversionJob(source: source, outputFolder: f.folder,
                                           options: options, conflict: conflict))
    }

    let normalise = ConversionOptions(normalise: true)

    @Test func quietToneIsRaisedToTheTarget() async throws {
        let mp3 = try await f.shaped("quiet.mp3", "0.25*sin(2*PI*440*t)|0.25*sin(2*PI*440*t)", seconds: 2)
        let r = try await run(mp3, normalise)
        #expect(abs(r.normalisation.dB - 11) < 0.5)
        #expect(abs(r.outputs[0].peak! - -1) < 0.6, "peak \(r.outputs[0].peak!)")
    }

    @Test func fullScaleIsLowered() async throws {
        let mp3 = try await f.shaped("loud.mp3", "0.99*sin(2*PI*440*t)", seconds: 2)
        let r = try await run(mp3, normalise)
        #expect(r.normalisation.dB < 0)
        #expect(abs(r.outputs[0].peak! - -1) < 0.6, "peak \(r.outputs[0].peak!)")
    }

    @Test func veryQuietIsCapped() async throws {
        let mp3 = try await f.shaped("veryquiet.mp3", "0.01*sin(2*PI*440*t)", seconds: 2)
        let r = try await run(mp3, normalise)
        #expect(r.normalisation == .gain(dB: 20, capped: true))
    }

    @Test func nearSilenceIsNotAmplified() async throws {
        let mp3 = try await f.shaped("near.mp3", "0.001*sin(2*PI*440*t)", seconds: 2)
        let r = try await run(mp3, normalise)
        guard case .skipped = r.normalisation else { Issue.record("\(r.normalisation)"); return }
        #expect(r.stage == .completed)
    }

    @Test func unevenChannelsAreWarnedAbout() async throws {
        let mp3 = try await f.shaped("uneven.mp3", "0.5*sin(2*PI*440*t)|0", seconds: 2)
        let r = try await run(mp3, normalise)
        #expect(r.outputs[0].peak! < -5)                           // mixed into one: about -7 dBFS
        #expect(r.outputs[0].warnings.contains { $0.contains("channels differ") })
    }

    /// A source over full scale, not normalised: warned about; normalised,
    /// lowered and not warned about.
    @Test func overFullScaleIsWarnedAbout() async throws {
        var samples = Data()
        for i in 0..<16_000 {
            let x: Float = 1.2 * sin(Float(i) / 5)
            withUnsafeBytes(of: x.bitPattern.littleEndian) { samples.append(contentsOf: $0) }
        }
        let wav = try f.wav("hot.wav", format: 3, rate: 8_000, bits: 32, blockAlign: 4, byteRate: 32_000,
                            data: samples)
        let plain = try await run(wav)
        #expect(plain.outputs[0].warnings.contains { $0.contains("above full scale") })
        let lowered = try await run(wav, normalise)        // named "hot 3.wav": the others are taken
        #expect(lowered.normalisation.dB < 0)
        #expect(!lowered.outputs[0].warnings.contains { $0.contains("above full scale") })
    }

    @Test func longSilenceIsTrimmed() async throws {
        // Silent 0-4 s, a tone 4-7 s, silent 7-10 s.
        let mp3 = try await f.shaped("gaps.mp3", "if(between(t,4,7),0.5*sin(2*PI*440*t),0)", seconds: 10)
        let r = try await run(mp3, ConversionOptions(trimSilence: true))
        let t = try #require(r.trim)
        #expect(abs(t.cutFromStart - 3.5) < 0.1 && abs(t.cutFromEnd - 2.5) < 0.1, "\(t)")
        #expect(abs(r.outputs[0].report!.duration - 4) < 0.15)
    }

    @Test func thresholdThreeKeepsTwoAndAHalf() async throws {
        // Silent 0-4 s, a tone 4-7.5 s, silent 7.5-10 s.
        let mp3 = try await f.shaped("gaps3.mp3", "if(between(t,4,7.5),0.5*sin(2*PI*440*t),0)", seconds: 10)
        let r = try await run(mp3, ConversionOptions(trimSilence: true, trimThreshold: 3))
        let t = try #require(r.trim)
        #expect(abs(t.cutFromStart - 3.5) < 0.1 && t.cutFromEnd == 0, "\(t)")
    }

    @Test func silenceInTheMiddleStays() async throws {
        // A tone, 4 s of silence, a tone: nothing at the ends to cut.
        let mp3 = try await f.shaped("middle.mp3",
            "if(between(t,0.2,2)+between(t,6,8),0.5*sin(2*PI*440*t),0)", seconds: 8.2)
        let r = try await run(mp3, ConversionOptions(trimSilence: true))
        #expect(r.trim?.trims == false)
        #expect(abs(r.outputs[0].report!.duration - 8.2) < 0.15)
    }

    @Test func trimmingOffChangesNothing() async throws {
        let mp3 = try await f.shaped("asis.mp3", "if(between(t,4,7),0.5*sin(2*PI*440*t),0)", seconds: 10)
        let r = try await run(mp3)
        #expect(r.trim == nil && abs(r.outputs[0].report!.duration - 10) < 0.15)
    }

    @Test func conflictPolicies() async throws {
        let mp3 = try await f.mp3("dup.mp3", source: "sine=f=440:d=1")
        try Data("mine".utf8).write(to: f.url("dup.wav"))
        let unique = try await run(mp3, conflict: .uniqueName)
        #expect(unique.outputs[0].url?.lastPathComponent == "dup 2.wav")
        #expect(try Data(contentsOf: f.url("dup.wav")) == Data("mine".utf8))
        let replaced = try await run(mp3, conflict: .replace)
        #expect(replaced.outputs[0].url?.lastPathComponent == "dup.wav")
        #expect(MacMusicWAVValidator.check(f.url("dup.wav")).accepted)
    }

    @Test func brokenSamplesAreRefused() async throws {
        // A float WAV with NaN in it.
        var samples = Data()
        for i in 0..<4_000 {
            let x: Float = i == 2_000 ? .nan : 0.1 * sin(Float(i) / 10)
            withUnsafeBytes(of: x.bitPattern.littleEndian) { samples.append(contentsOf: $0) }
        }
        let wav = try f.wav("nan.wav", format: 3, rate: 8_000, bits: 32, blockAlign: 4, byteRate: 32_000,
                            data: samples)
        await #expect(throws: ConversionError.brokenAudio(1)) { try await run(wav) }
    }

    @Test func cancellingLeavesNothing() async throws {
        let mp3 = try await f.mp3("long.mp3", source: "sine=f=440:d=600", channels: 2, bitrate: "64k")
        let job = Task { try await run(mp3, normalise) }
        try await Task.sleep(for: .milliseconds(300))
        job.cancel()
        await #expect(throws: ConversionError.cancelled(kept: [])) { try await job.value }
        let left = try FileManager.default.contentsOfDirectory(atPath: f.folder.path)
        #expect(left.filter { $0.hasSuffix(".wav") || $0.hasSuffix(".partial") }.isEmpty, "\(left)")
    }

    @Test func cancelledBeforeStarting() async throws {
        let mp3 = try await f.mp3("early.mp3", source: "sine=f=440:d=1")
        let job = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await run(mp3)
        }
        await #expect(throws: ConversionError.cancelled(kept: [])) { try await job.value }
    }

    @Test func stagesInOrder() async throws {
        let mp3 = try await f.mp3("stages.mp3", source: "sine=f=440:d=1")
        let seen = Seen()
        _ = try await engine.run(ConversionJob(source: mp3, outputFolder: f.folder)) { seen.add($0) }
        #expect(seen.stages == [.validating, .analysing, .converting, .validatingOutputs, .completed])
    }

    @Test func missingSourceAndDestination() async throws {
        await #expect(throws: ConversionError.self) { try await run(f.url("nothing.mp3")) }
        let mp3 = try await f.mp3("here.mp3", source: "sine=f=440:d=1")
        await #expect(throws: ConversionError.self) {
            try await engine.run(ConversionJob(source: mp3, outputFolder: f.url("no-such-folder")))
        }
    }
}

final class Seen: @unchecked Sendable {
    private let lock = NSLock()
    private var list: [JobStage] = []
    func add(_ s: JobStage) { lock.withLock { list.append(s) } }
    var stages: [JobStage] { lock.withLock { list } }
}

/// The process runner on its own (§7.3).
@Suite struct ProcessRunnerTests {
    @Test func missingToolIsNamed() async {
        await #expect(throws: ProcessRunnerError.executableNotFound("/no/such/tool")) {
            try await ProcessRunner().run(URL(fileURLWithPath: "/no/such/tool"), arguments: [])
        }
    }

    @Test func argumentsAreNotParsedByAShell() async throws {
        let r = try await ProcessRunner().run(URL(fileURLWithPath: "/bin/echo"),
                                              arguments: ["a; rm -rf /tmp/x", "$(whoami)"])
        #expect(r.stdoutText == "a; rm -rf /tmp/x $(whoami)\n")
    }

    @Test func cancelStopsTheTool() async throws {
        let started = Date()
        let task = Task { try await ProcessRunner().run(URL(fileURLWithPath: "/bin/sleep"), arguments: ["10"]) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        await #expect(throws: ProcessRunnerError.cancelled) { try await task.value }
        #expect(Date().timeIntervalSince(started) < 3)
    }
}
