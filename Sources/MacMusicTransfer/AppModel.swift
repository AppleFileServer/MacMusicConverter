import AppKit
import Observation
import MacMusicTransferKit

/// The window's state, and the running job. The decisions it relies on
/// (names, conflicts, preferences, messages) live in the engine library,
/// where they're tested (W8); this only wires them to the window.
@MainActor @Observable
final class AppModel {
    enum Mode: String, CaseIterable { case local = "Local File", youtube = "YouTube" }

    var mode = Mode.local
    var prefs = Preferences.load() { didSet { prefs.save() } }

    // The source.
    var source: URL?
    var sourceInfo: AudioInfo?
    var sourceProblem: UserMessage?
    var title = ""
    var name = ""

    // The tools, found at launch.
    var tools: Tools?
    var toolsProblem: UserMessage?
    var ffmpegVersion = ""

    // The job.
    var running = false
    var progress: JobProgress?
    var result: JobResult?
    var jobMessage: UserMessage?
    private var task: Task<Void, Never>?

    // Questions put to the user before a job starts (W4, W5).
    var askReencode = false
    var conflicts: [PlannedOutput] = []
    var askConflicts = false
    private var reencodeConfirmed = false
    private var selectionForJob: OutputSelection = .wav

    init() {
        do {
            tools = try Tools.locate()
        } catch let error as ToolsError {
            toolsProblem = error.message
        } catch {
            toolsProblem = UserMessage(summary: "FFmpeg couldn't be found.", detail: "\(error)")
        }
        if let tools {
            Task {
                let out = try? await ProcessRunner().run(tools.ffmpeg, arguments: ["-hide_banner", "-version"])
                ffmpegVersion = out?.stdoutText.split(separator: "\n").first.map(String.init) ?? ""
            }
        }
    }

    // MARK: The source

    func chooseSource() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a sound file to convert."
        if panel.runModal() == .OK, let url = panel.url { setSource(url) }
    }

    func setSource(_ url: URL) {
        source = url
        sourceInfo = nil
        sourceProblem = nil
        result = nil
        jobMessage = nil
        title = ""
        name = ""
        guard let tools else { return }
        Task {
            do {
                let info = try await AudioInspector(tools: tools).inspect(url)
                guard source == url else { return }
                sourceInfo = info
                title = info.title ?? ""
            } catch AudioInspectorError.noAudio {
                if source == url { sourceProblem = ConversionError.noAudio.message }
            } catch AudioInspectorError.unreadable(let why) {
                if source == url { sourceProblem = ConversionError.sourceUnreadable(why).message }
            } catch {
                if source == url { sourceProblem = UserMessage(summary: "The file couldn't be read.", detail: "\(error)") }
            }
        }
    }

    var sourceIsMP3: Bool { sourceInfo?.codec == "mp3" }

    // MARK: The job

    func job(_ selection: OutputSelection, conflict: ConflictPolicy = .refuse) -> ConversionJob? {
        guard let source else { return nil }
        return ConversionJob(source: source, outputFolder: prefs.folder,
                             name: name.isEmpty ? nil : name, title: title.isEmpty ? nil : title,
                             options: prefs.options, conflict: conflict,
                             outputs: selection, reencodeConfirmed: reencodeConfirmed)
    }

    /// The "Saves as" line.
    var savesAs: [PlannedOutput] {
        guard let job = job(prefs.selection) else { return [] }
        return OutputPreview.plan(job)
    }

    var canConvert: Bool { !running && tools != nil && sourceInfo != nil }

    /// Convert: ask about re-encoding, then about taken names, then start.
    func convert() {
        guard canConvert else { return }
        reencodeConfirmed = false
        selectionForJob = prefs.selection
        if selectionForJob.kinds.contains(.mp3), sourceIsMP3 {
            askReencode = true
        } else {
            checkConflicts()
        }
    }

    func reencodeAnswered(_ answer: ReencodeAnswer) {
        switch answer {
        case .reencode: reencodeConfirmed = true
        case .wavOnly: selectionForJob = .wav
        case .cancel: return
        }
        checkConflicts()
    }

    enum ReencodeAnswer { case reencode, wavOnly, cancel }

    private func checkConflicts() {
        guard let folder = makeFolder(), let job = job(selectionForJob) else { return }
        _ = folder
        conflicts = OutputPreview.conflicts(job)
        if conflicts.isEmpty { start(.refuse) } else { askConflicts = true }
    }

    func conflictsAnswered(_ policy: ConflictPolicy?) {
        if let policy { start(policy) }
    }

    /// The save folder, made if it's the default and isn't there yet (W3).
    private func makeFolder() -> URL? {
        let folder = prefs.folder
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        } catch {
            jobMessage = ConversionError.destinationUnavailable(folder.path).message
            return nil
        }
    }

    private func start(_ policy: ConflictPolicy) {
        guard let tools, let job = job(selectionForJob, conflict: policy) else { return }
        running = true
        result = nil
        jobMessage = nil
        progress = JobProgress(stage: .validating)
        task = Task {
            do {
                let r = try await ConversionEngine(tools: tools).run(job) { p in
                    Task { @MainActor in if self.running { self.progress = p } }
                }
                result = r
                if r.stage == .failed {
                    jobMessage = UserMessage(summary: "The conversion didn't produce a usable file.", detail: nil)
                }
            } catch let error as ConversionError {
                jobMessage = error.message
            } catch {
                jobMessage = UserMessage(summary: "Something went wrong.", detail: "\(error)")
            }
            running = false
            progress = nil
            task = nil
        }
    }

    func cancel() { task?.cancel() }

    // MARK: The folder

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = prefs.folder
        panel.message = "Choose where to save the converted files."
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url { prefs.folderPath = url.path }
    }

    func useDefaultFolder() { prefs.folderPath = nil }

    func show(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
}
