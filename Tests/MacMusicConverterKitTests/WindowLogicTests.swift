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
        p.normalise = true
        p.target = -2
        p.trimSilence = true
        p.trimThreshold = 3
        p.folderPath = "/tmp/somewhere"
        p.save(to: defaults)
        #expect(Preferences.load(from: defaults) == p)
        #expect(Preferences.load(from: defaults).options
                == ConversionOptions(normalise: true, target: -2, trimSilence: true, trimThreshold: 3))
    }

    @Test func preferencesAreTidied() throws {
        let defaults = try #require(UserDefaults(suiteName: "mmc-test-\(UUID().uuidString)"))
        var p = Preferences()
        p.target = -40
        p.trimThreshold = 7
        p.save(to: defaults)
        let back = Preferences.load(from: defaults)
        #expect(back.target == -6 && back.trimThreshold == 3)
    }

    /// 1.1 (L1, L3): Loudness and its target are kept; the target is kept
    /// within −16 to −8 LUFS; Off by default.
    @Test func loudnessPreferences() throws {
        #expect(Preferences().levelling == .off && Preferences().loudnessTarget == -12)
        let defaults = try #require(UserDefaults(suiteName: "mmc-test-\(UUID().uuidString)"))
        var p = Preferences()
        p.levelling = .loudness
        p.loudnessTarget = -14
        p.save(to: defaults)
        let back = Preferences.load(from: defaults)
        #expect(back == p)
        #expect(back.options == ConversionOptions(levelling: .loudness, loudnessTarget: -14))
        p.loudnessTarget = -30
        p.save(to: defaults)
        #expect(Preferences.load(from: defaults).loudnessTarget == -16)
        p.loudnessTarget = 0
        p.save(to: defaults)
        #expect(Preferences.load(from: defaults).loudnessTarget == -8)
    }

    /// 1.0's saved choices (no levelling) are read: Normalise ticked is
    /// Peak, every other choice kept.
    @Test func choicesSavedBy10AreRead() throws {
        let defaults = try #require(UserDefaults(suiteName: "mmc-test-\(UUID().uuidString)"))
        let saved10 = #"{"outputs":"both","normalise":true,"target":-2,"trimSilence":true,"trimThreshold":3,"folderPath":"/tmp/x"}"#
        defaults.set(Data(saved10.utf8), forKey: Preferences.key)
        let p = Preferences.load(from: defaults)
        #expect(p.levelling == .peak && p.target == -2 && p.selection == .both)
        #expect(p.trimSilence && p.trimThreshold == 3 && p.folderPath == "/tmp/x")
        #expect(p.loudnessTarget == -12)

        defaults.set(Data(#"{"outputs":"mp3","normalise":false}"#.utf8), forKey: Preferences.key)
        #expect(Preferences.load(from: defaults).levelling == .off)
    }

    /// A value that can't be read is left at its default; the rest are kept.
    @Test func anUnreadableChoiceLosesOnlyItself() throws {
        let defaults = try #require(UserDefaults(suiteName: "mmc-test-\(UUID().uuidString)"))
        let saved = #"{"outputs":"both","levelling":"louder-still","target":-3}"#
        defaults.set(Data(saved.utf8), forKey: Preferences.key)
        let p = Preferences.load(from: defaults)
        #expect(p.levelling == .off && p.selection == .both && p.target == -3)
    }

    /// 1.0 can still read what 1.1 saves: `normalise` is still written.
    @Test func normaliseIsStillWritten() throws {
        var p = Preferences()
        p.levelling = .peak
        let json = try #require(String(data: try JSONEncoder().encode(p), encoding: .utf8))
        #expect(json.contains(#""normalise":true"#))
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
