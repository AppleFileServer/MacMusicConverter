import Foundation
import Darwin
import Testing
@testable import MacMusicTransferKit

/// Stage 6: failures handled safely, nothing incomplete passed off as
/// finished, nothing left running or lying about (H1-H5).
@Suite struct HardeningTests {
    let f: Fixtures
    let engine: ConversionEngine
    init() throws {
        f = try Fixtures()
        engine = ConversionEngine(tools: f.tools)
    }

    func noPartials(_ folder: URL) throws -> Bool {
        try !FileManager.default.contentsOfDirectory(atPath: folder.path).contains { $0.hasSuffix(".partial") }
    }

    // MARK: Stopping tools

    /// Stopping a tool stops what it started, too.
    @Test func stoppingStopsTheWholeFamily() async throws {
        // The script writes down its own process ID (other tests run tools
        // at the same time), then starts two children and waits.
        let script = f.url("family.sh"), pidFile = f.url("family.pid")
        try "#!/bin/sh\necho $$ > '\(pidFile.path)'\nsleep 32 &\nsleep 32 &\nwait\n"
            .write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let task = Task { try await ProcessRunner().run(script, arguments: []) }
        var parent: pid_t = 0, children: [pid_t] = []
        for _ in 0..<60 where children.count < 2 {
            try await Task.sleep(for: .milliseconds(50))
            if let text = try? String(contentsOf: pidFile, encoding: .utf8),
               let p = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                parent = p
                children = ProcessTree.descendants(of: p)
            }
        }
        try #require(children.count == 2, "the script's children didn't start")
        #expect(RunningTools.shared.running.contains(parent))
        task.cancel()
        await #expect(throws: ProcessRunnerError.cancelled) { try await task.value }
        try await Task.sleep(for: .milliseconds(300))
        for p in [parent] + children { #expect(!ProcessTree.isAlive(p), "\(p) still running") }
        #expect(!RunningTools.shared.running.contains(parent))
    }

    /// What quitting does, on this test's own processes only (other tests
    /// run tools at the same time).
    @Test func stoppingAListStopsThemAll() async throws {
        let t1 = Task { try await ProcessRunner().run(URL(fileURLWithPath: "/bin/sleep"), arguments: ["31"]) }
        let t2 = Task { try await ProcessRunner().run(URL(fileURLWithPath: "/bin/sleep"), arguments: ["31"]) }
        try await Task.sleep(for: .milliseconds(300))
        let before = RunningTools.shared.running.filter { pid in
            var buffer = [CChar](repeating: 0, count: 4096)
            return proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 && String(cString: buffer) == "/bin/sleep"
        }
        #expect(before.count >= 2)
        RunningTools.shared.stop(before, wait: 2)
        for p in before { #expect(!ProcessTree.isAlive(p)) }
        _ = try? await t1.value
        _ = try? await t2.value
    }

    // MARK: Leftovers (H1)

    @Test func leftoversOldAndOursOnly() throws {
        let files = FileManager.default
        let hourAgo = Date().addingTimeInterval(-3_700)
        func make(_ name: String, old: Bool, folder: Bool = false) throws -> URL {
            let url = f.url(name)
            if folder { try files.createDirectory(at: url, withIntermediateDirectories: true) }
            else { try Data("x".utf8).write(to: url) }
            if old { try files.setAttributes([.modificationDate: hourAgo], ofItemAtPath: url.path) }
            return url
        }
        let oldPartial = try make(".mmt-1234.wav.partial", old: true)
        let newPartial = try make(".mmt-5678.mp3.partial", old: false)
        let oldDownload = try make("mmt-youtube-abcd", old: true, folder: true)
        let someoneElses = try make("song.wav.partial", old: true)
        let aSong = try make("Song.wav", old: true)
        let removed = Leftovers.clean([f.folder])
        #expect(Set(removed.map(\.lastPathComponent)) == [oldPartial.lastPathComponent, oldDownload.lastPathComponent])
        for kept in [newPartial, someoneElses, aSong] { #expect(files.fileExists(atPath: kept.path)) }
    }

    // MARK: Names and paths (H3)

    @Test func awkwardSourceNames() async throws {
        let names = ["-rf.wav", "concat:a|b.wav", "it's \"quoted\".wav", "🎵 song.wav", "back\\slash.wav",
                     "Cafe\u{301}.wav"]          // "Café" with the accent as a separate character
        for name in names {
            let wav = try await f.pcm(name, source: "sine=f=440:d=1")
            let out = f.url("out-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let r = try await engine.run(ConversionJob(source: wav, outputFolder: out, outputs: .both))
            #expect(r.stage == .completed, "\(name): \(r.outputs.map(\.problems))")
            for o in r.outputs { #expect(o.url?.deletingLastPathComponent().standardizedFileURL == out.standardizedFileURL) }
        }
        // The accent is joined to its letter in the output's name.
        #expect(OutputNaming.safeBase("Cafe\u{301}") == "Café")
        #expect(OutputNaming.safeBase("Cafe\u{301}").unicodeScalars.count == 4)
    }

    @Test func longTitlesStayWithinTheLimits() {
        let title = String(repeating: "Très long titre ", count: 20)          // over 300 bytes
        let mp3 = OutputNaming.name(.mp3, title)
        #expect(mp3.utf8.count <= 200 && mp3.hasSuffix(".mp3") && !mp3.hasSuffix(" .mp3"))
        #expect(OutputNaming.name(.mp3, title, suffix: " 12").utf8.count <= 200)
        #expect(OutputNaming.name(.macMusicWAV, title).count <= 31)
        let emoji = String(repeating: "🎵", count: 80)                       // 4 bytes each
        let e = OutputNaming.name(.mp3, emoji)
        #expect(e.utf8.count <= 200 && e.hasPrefix("🎵"))                    // never cut inside one
    }

    @Test func longTitleConverts() async throws {
        let wav = try await f.pcm("src-long.wav", source: "sine=f=440:d=1")
        let title = String(repeating: "A very long title ", count: 20)
        let r = try await engine.run(ConversionJob(source: wav, outputFolder: f.folder, title: title, outputs: .both))
        #expect(r.stage == .completed, "\(r.outputs.map(\.problems))")
    }

    // MARK: Disks and folders

    @Test func readOnlyFolder() async throws {
        let wav = try await f.pcm("src-ro.wav", source: "sine=f=440:d=1")
        let locked = f.url("locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
        await #expect(throws: ConversionError.destinationUnavailable(locked.path)) {
            try await engine.run(ConversionJob(source: wav, outputFolder: locked))
        }
    }

    /// The folder removed while converting: both outputs fail, nothing is
    /// claimed, nothing crashes.
    @Test func folderRemovedMidJob() async throws {
        let wav = try await f.pcm("src-gone.wav", source: "sine=f=440:d=2")
        let doomed = f.url("doomed")
        try FileManager.default.createDirectory(at: doomed, withIntermediateDirectories: true)
        let r = try await engine.run(ConversionJob(source: wav, outputFolder: doomed, outputs: .both)) { p in
            if p.stage == .converting { try? FileManager.default.removeItem(at: doomed) }
        }
        #expect(r.stage == .failed)
        #expect(r.outputs.allSatisfy { !$0.succeeded && $0.url == nil && !$0.problems.isEmpty })
    }

    /// The source deleted once converting has begun.
    @Test func sourceRemovedMidJob() async throws {
        let wav = try await f.pcm("src-vanish.wav", source: "sine=f=440:d=2")
        let r = try await engine.run(ConversionJob(source: wav, outputFolder: f.folder, name: "vanish")) { p in
            if p.stage == .converting { try? FileManager.default.removeItem(at: wav) }
        }
        #expect(r.stage == .failed && r.outputs[0].url == nil)
        #expect(try noPartials(f.folder))
    }

    /// A small disk (H4): the estimate refuses up front; and, with the
    /// estimate skipped, a disk filling mid-write fails that output and
    /// leaves no partial file.
    @Test(.enabled(if: FileManager.default.isExecutableFile(atPath: "/usr/bin/hdiutil")))
    func fullDisk() async throws {
        let image = f.url("small.dmg"), mount = f.url("small")
        let hdiutil = URL(fileURLWithPath: "/usr/bin/hdiutil")
        let made = try await ProcessRunner().run(hdiutil, arguments: [
            "create", "-size", "4m", "-fs", "HFS+", "-volname", "mmt-small", "-quiet", image.path])
        try #require(made.status == 0, "\(made.stderrText)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        let attached = try await ProcessRunner().run(hdiutil, arguments: [
            "attach", "-nobrowse", "-noverify", "-mountpoint", mount.path, "-quiet", image.path])
        try #require(attached.status == 0, "\(attached.stderrText)")
        defer { _ = Process.launchedProcess(launchPath: "/usr/bin/hdiutil", arguments: ["detach", "-force", "-quiet", mount.path]).waitUntilExitSafely() }

        let wav = try await f.pcm("src-big.wav", source: "sine=f=440:d=240")    // a 5 MB MacMusic WAV
        await #expect(throws: ConversionError.self) {
            try await engine.run(ConversionJob(source: wav, outputFolder: mount))
        }
        var reckless = engine
        reckless.checksSpace = false
        let r = try await reckless.run(ConversionJob(source: wav, outputFolder: mount))
        #expect(r.stage == .failed && r.outputs[0].url == nil)
        #expect(try noPartials(mount))
    }

    // MARK: No tools (H5)

    @Test func noToolsIsAPlainMessage() throws {
        let empty = f.url("no-tools")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        do {
            _ = try Tools.locate(environment: [:], resources: nil, pinned: empty)
            Issue.record("found tools in an empty folder")
        } catch let error as ToolsError {
            #expect(error.message.summary == "ffmpeg, which the conversion needs, couldn't be found.")
            #expect(error.message.detail?.contains(empty.path) == true)
        }
    }

    @Test func ytdlpGetsANetworkTimeout() throws {
        let yt = YouTubeTools(ytdlp: URL(fileURLWithPath: "/x"), deno: URL(fileURLWithPath: "/y"),
                              ffmpegFolder: URL(fileURLWithPath: "/z"))
        let common = YouTubeSource(tools: yt).common
        #expect(common.firstIndex(of: "--socket-timeout").map { common[$0 + 1] } == "30")
    }
}

private extension Process {
    func waitUntilExitSafely() { while isRunning { usleep(50_000) } }
}
