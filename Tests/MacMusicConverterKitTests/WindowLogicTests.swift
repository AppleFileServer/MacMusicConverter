import Foundation
import Testing
@testable import MacMusicConverterKit

/// The window's logic, kept in the engine so it can be tested (W8).
@Suite struct WindowLogicTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    @Test func preferencesRoundTrip() throws {
        let defaults = try #require(UserDefaults(suiteName: "mmc-test-\(UUID().uuidString)"))
        #expect(Preferences.load(from: defaults) == Preferences())
        var p = Preferences()
        p.selection = .both
        p.trimSilence = true
        p.trimThreshold = 3
        p.folderPath = "/tmp/somewhere"
        p.save(to: defaults)
        #expect(Preferences.load(from: defaults) == p)
        #expect(Preferences.load(from: defaults).options
                == ConversionOptions(levelling: .loudness, loudnessTarget: -16, trimSilence: true, trimThreshold: 3))
    }

    @Test func preferencesAreTidied() throws {
        let defaults = try #require(UserDefaults(suiteName: "mmc-test-\(UUID().uuidString)"))
        var p = Preferences()
        p.trimThreshold = 7
        p.save(to: defaults)
        #expect(Preferences.load(from: defaults).trimThreshold == 3)
    }

    /// L10: there is no level to choose: every song is brought to −16 LUFS.
    @Test func alwaysLoudness() {
        let o = Preferences().options
        #expect(o.levelling == .loudness && o.loudnessTarget == -16)
    }

    /// Choices saved by 1.0 and by early 1.1 builds are read; their
    /// Normalise, Level and targets are ignored (L10).
    @Test func earlierChoicesAreRead() throws {
        let defaults = try #require(UserDefaults(suiteName: "mmc-test-\(UUID().uuidString)"))
        let saved10 = #"{"outputs":"both","normalise":true,"target":-2,"trimSilence":true,"trimThreshold":3,"folderPath":"/tmp/x"}"#
        defaults.set(Data(saved10.utf8), forKey: Preferences.key)
        var p = Preferences.load(from: defaults)
        #expect(p.selection == .both && p.trimSilence && p.trimThreshold == 3 && p.folderPath == "/tmp/x")
        #expect(p.options.levelling == .loudness && p.options.loudnessTarget == -16)

        let saved11 = #"{"outputs":"mp3","levelling":"off","loudnessTarget":-9,"normalise":false,"target":-1}"#
        defaults.set(Data(saved11.utf8), forKey: Preferences.key)
        p = Preferences.load(from: defaults)
        #expect(p.selection == .mp3 && p.options.levelling == .loudness && p.options.loudnessTarget == -16)
    }

    /// A value that can't be read is left at its default; the rest are kept.
    @Test func anUnreadableChoiceLosesOnlyItself() throws {
        let defaults = try #require(UserDefaults(suiteName: "mmc-test-\(UUID().uuidString)"))
        let saved = #"{"outputs":"both","trimThreshold":"long","trimSilence":true}"#
        defaults.set(Data(saved.utf8), forKey: Preferences.key)
        let p = Preferences.load(from: defaults)
        #expect(p.trimThreshold == 2 && p.selection == .both && p.trimSilence)
    }

    /// 1.0 can still read what 1.1 saves: it needs `normalise` and
    /// `target`, so they are written (Normalise off).
    @Test func whatOnePointOhNeedsIsWritten() throws {
        let json = try #require(String(data: try JSONEncoder().encode(Preferences()), encoding: .utf8))
        #expect(json.contains(#""normalise":false"#) && json.contains(#""target":-1"#))
    }

    @Test func defaultFolder() {
        #expect(Preferences().folder.path.hasSuffix("Music/MacMusic Converter"))
    }

    @Test func savesAsAndConflicts() throws {
        let source = f.url("Song.mp3")
        try Data("not really".utf8).write(to: source)
        try Data().write(to: f.url("Song.wav"))
        let job = ConversionJob(source: source, outputFolder: f.folder, outputs: .both)
        let plan = OutputPreview.plan(job)
        #expect(plan.map(\.name) == ["Song.wav", "Song.mp3"])
        #expect(plan.map(\.taken) == [true, true])
        #expect(plan.map(\.isSource) == [false, true])
        // The source is never asked about: it always gets a new name.
        #expect(OutputPreview.conflicts(job).map(\.name) == ["Song.wav"])
    }

    @Test func progressFromFFmpeg() {
        let text = "out_time_us=1000000\nprogress=continue\nout_time_us=2500000\n"
        #expect(JobProgress.fraction(fromFFmpegProgress: text, length: 10) == 0.25)
        #expect(JobProgress.fraction(fromFFmpegProgress: text, length: nil) == nil)
        #expect(JobProgress.fraction(fromFFmpegProgress: "progress=continue\n", length: 10) == nil)
        #expect(JobProgress.fraction(fromFFmpegProgress: "out_time_us=99000000\n", length: 10) == 1)
        #expect(JobProgress(stage: .analysing, fraction: -1).fraction == 0)
    }

    @Test func throttleOnlyPassesChanges() {
        let got = Got()
        let t = ProgressThrottle { got.add($0) }
        t.send(JobProgress(stage: .analysing, fraction: 0))
        for i in 1...1000 { t.send(JobProgress(stage: .analysing, fraction: Double(i) / 1000)) }
        t.send(JobProgress(stage: .converting))
        #expect(got.list.count <= 103 && got.list.count >= 100)
        #expect(got.list.last?.stage == .converting)
        #expect(got.list.contains { $0.fraction == 1 })
    }

    @Test func progressDuringARealJob() async throws {
        let wav = try await f.pcm("prog.wav", source: "sine=f=440:d=20")
        let got = Got()
        _ = try await ConversionEngine(tools: f.tools).run(
            ConversionJob(source: wav, outputFolder: f.folder, name: "out", outputs: .both)) { got.add($0) }
        let converting = got.list.filter { $0.stage == .converting }
        #expect(Set(converting.compactMap(\.output)) == [.macMusicWAV, .mp3])
        #expect(converting.contains { ($0.fraction ?? 0) > 0.9 })
        #expect(got.list.contains { $0.stage == .analysing && ($0.fraction ?? 0) > 0.9 })
        #expect(got.list.last?.stage == .completed)
    }

    @Test func messagesArePlain() {
        let m = ConversionError.insufficientSpace(needed: 5_000_000, available: 1_000_000).message
        #expect(m.summary.contains("enough room") && m.detail?.contains("free") == true)
        #expect(ConversionError.cancelled(kept: []).message.summary == "Cancelled. Nothing was saved.")
        #expect(!ConversionError.sourceUnreadable("Invalid data found").message.summary.contains("Invalid"))
    }
}

final class Got: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [JobProgress] = []
    func add(_ p: JobProgress) { lock.withLock { items.append(p) } }
    var list: [JobProgress] { lock.withLock { items } }
}
