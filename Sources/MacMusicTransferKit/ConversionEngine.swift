import Foundation

/// The shared conversion engine (§7.2): no SwiftUI; the window, the
/// command-line tool and the tests all use it. A local source into a
/// MacMusic WAV, an MP3, or both (Stage 3), with optional normalisation
/// and silence trimming decided once for both (§6.3).
public struct ConversionEngine: Sendable {
    let tools: Tools
    let runner = ProcessRunner()
    /// For the tests only: outputs whose conversion is made to fail, to
    /// show the other output survives (§13.3).
    var faults: Set<OutputKind> = []

    public init(tools: Tools) { self.tools = tools }

    public func run(_ job: ConversionJob,
                    onStage: @escaping @Sendable (JobStage) -> Void = { _ in }) async throws -> JobResult {
        let kept = Kept()
        do {
            return try await perform(job, kept: kept, onStage: onStage)
        } catch ProcessRunnerError.cancelled {
            onStage(.cancelled)
            throw ConversionError.cancelled(kept: kept.paths)
        } catch is CancellationError {
            onStage(.cancelled)
            throw ConversionError.cancelled(kept: kept.paths)
        } catch ConversionError.needsReencodeConfirmation {
            throw ConversionError.needsReencodeConfirmation        // nothing done: not a failure
        } catch ProcessRunnerError.executableNotFound(let path) {
            onStage(.failed)
            throw ConversionError.toolMissing(path)
        } catch {
            onStage(.failed)
            throw error
        }
    }

    /// One output on its way: where it goes, and its temporary file.
    struct Pending {
        let kind: OutputKind
        let destination: URL
        let temporary: URL
        var problems: [String] = []
        var warnings: [String] = []
        var report: MacMusicWAVReport?
        var checked: AudioInfo?
        var peak: Double?
    }

    func perform(_ job: ConversionJob, kept: Kept,
                 onStage: @escaping @Sendable (JobStage) -> Void) async throws -> JobResult {
        let files = FileManager.default

        // Validating: the source, the destination, what the source is.
        onStage(.validating)
        guard files.fileExists(atPath: job.source.path) else {
            throw ConversionError.sourceMissing(job.source.path)
        }
        guard files.isReadableFile(atPath: job.source.path) else {
            throw ConversionError.sourceUnreadable("The file can't be read.")
        }
        var isFolder: ObjCBool = false
        guard files.fileExists(atPath: job.outputFolder.path, isDirectory: &isFolder), isFolder.boolValue,
              files.isWritableFile(atPath: job.outputFolder.path) else {
            throw ConversionError.destinationUnavailable(job.outputFolder.path)
        }
        let source: AudioInfo
        do {
            source = try await AudioInspector(tools: tools).inspect(job.source)
        } catch AudioInspectorError.noAudio {
            throw ConversionError.noAudio
        } catch AudioInspectorError.unreadable(let why) {
            throw ConversionError.sourceUnreadable(why)
        }
        let kinds = job.outputs.kinds
        // An MP3 from an MP3 loses a little more each time: ask first (M2).
        if kinds.contains(.mp3), source.codec == "mp3", !job.reencodeConfirmed {
            throw ConversionError.needsReencodeConfirmation
        }
        try Task.checkCancellation()

        // Analysing: one pass, then one decision for every output (§6.3).
        onStage(.analysing)
        let analysis = try await AudioAnalyser(tools: tools)
            .analyse(job.source, sampleRate: source.sampleRate, channels: source.channels)
        guard analysis.brokenSamples == 0 else { throw ConversionError.brokenAudio(analysis.brokenSamples) }
        guard analysis.frames > 0 else { throw ConversionError.noAudio }
        let trim = job.options.trimSilence ? Trim.decide(analysis, threshold: job.options.trimThreshold) : nil
        let normalisation = job.options.normalise
            ? Normalisation.decide(peak: analysis.peak, target: job.options.target) : .off
        let length = trim?.duration ?? analysis.duration

        // Where each goes (a taken name stops the job before any work, so
        // the user can choose), and whether they fit.
        var pending = try kinds.map { kind in
            Pending(kind: kind,
                    destination: try OutputNaming.destination(kind, folder: job.outputFolder,
                                                              base: job.baseName, policy: job.conflict,
                                                              source: job.source),
                    temporary: job.outputFolder.appendingPathComponent(
                        ".mmt-\(UUID().uuidString).\(kind == .mp3 ? "mp3" : "wav").partial"))
        }
        let temporaries = pending.map(\.temporary)
        defer { for t in temporaries { try? files.removeItem(at: t) } }
        let needed = kinds.reduce(Int64(0)) {
            $0 + ($1 == .mp3 ? DiskSpace.mp3Bytes(seconds: length) : DiskSpace.macMusicBytes(seconds: length))
        }
        if let free = DiskSpace.available(at: job.outputFolder), free < needed {
            throw ConversionError.insufficientSpace(needed: needed, available: free)
        }
        try Task.checkCancellation()

        // Converting: each output in its own FFmpeg run, from the same
        // source with the same trim and gain, so one failing can't stop the
        // other (M5).
        onStage(.converting)
        for i in pending.indices {
            let p = pending[i]
            let made = try await runner.run(tools.ffmpeg, arguments: arguments(
                for: p.kind, job: job, source: source, trim: trim, gain: normalisation.dB, into: p.temporary))
            if made.status != 0 {
                pending[i].problems.append("The conversion failed: "
                    + made.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
            } else if p.kind == .macMusicWAV, let title = job.title, let bytes = MacMusicText.infoTitle(title) {
                try WAVFile.appendTitle(bytes, to: p.temporary)
            }
            try Task.checkCancellation()
        }

        // Validating each output on its own.
        onStage(.validatingOutputs)
        for i in pending.indices where pending[i].problems.isEmpty {
            switch pending[i].kind {
            case .macMusicWAV: await checkWAV(&pending[i], job: job, expected: length, normalisation: normalisation)
            case .mp3: await checkMP3(&pending[i], job: job, source: source, expected: length)
            }
            try Task.checkCancellation()
        }

        // Warnings about the source and the title, on every output.
        var shared: [String] = []
        if let said = source.duration, abs(said - analysis.duration) > 1 + said * 0.02 {
            shared.append(String(format: "The source says it lasts %.1f s, but only %.1f s of it could be read: it may be damaged or cut short.",
                                 said, analysis.duration))
        }
        if let title = job.title, !title.trimmingCharacters(in: .whitespaces).isEmpty,
           MacMusicText.infoTitle(title) == nil, kinds.contains(.macMusicWAV) {
            shared.append("The title has nothing MacMusic can show, so the WAV has none.")
        }

        // Into place: only the outputs that passed. Replacing only when the
        // job says so (confirmed by the user); otherwise moveItem refuses
        // rather than overwrite.
        var outputs: [OutputResult] = []
        for p in pending {
            guard p.problems.isEmpty else {
                outputs.append(OutputResult(kind: p.kind, url: nil, problems: p.problems,
                                            warnings: shared + p.warnings, report: p.report,
                                            checked: p.checked, size: nil, peak: p.peak))
                continue
            }
            if job.conflict == .replace, files.fileExists(atPath: p.destination.path) {
                _ = try files.replaceItemAt(p.destination, withItemAt: p.temporary)
            } else {
                try files.moveItem(at: p.temporary, to: p.destination)
            }
            kept.add(p.destination.path)
            let size = (try? files.attributesOfItem(atPath: p.destination.path)[.size] as? Int64) ?? nil
            outputs.append(OutputResult(kind: p.kind, url: p.destination, problems: [],
                                        warnings: shared + p.warnings, report: p.report,
                                        checked: p.checked, size: size, peak: p.peak))
        }

        let passed = outputs.filter(\.succeeded).count
        let stage: JobStage = passed == outputs.count ? .completed : passed == 0 ? .failed : .completedWithErrors
        onStage(stage)
        return JobResult(stage: stage, source: source, analysis: analysis, normalisation: normalisation,
                         trim: trim, outputs: outputs)
    }

    /// FFmpeg's arguments for one output.
    func arguments(for kind: OutputKind, job: ConversionJob, source: AudioInfo, trim: Trim?,
                   gain: Double, into temporary: URL) -> [String] {
        var a = ["-nostdin", "-hide_banner", "-v", "error", "-n",
                 "-i", job.source.path,
                 "-map", "0:a:0", "-vn", "-sn", "-dn",
                 "-map_metadata", "-1", "-map_chapters", "-1"]
        switch kind {
        case .macMusicWAV:
            a += ["-af", Self.filter(channels: max(source.channels, 1), trim: trim, gain: gain),
                  "-c:a", "pcm_u8",
                  "-ar", faults.contains(.macMusicWAV) ? "nonsense" : String(MacMusicFormat.sampleRate),
                  "-ac", "1",
                  "-fflags", "+bitexact", "-flags:a", "+bitexact",
                  "-f", "wav"]
        case .mp3:
            a += ["-af", Self.mp3Filter(trim: trim, gain: gain),
                  "-c:a", "libmp3lame", "-b:a", faults.contains(.mp3) ? "nonsense" : "192k",
                  "-ar", String(MP3Format.sampleRate(for: source.sampleRate)),
                  "-ac", String(MP3Format.channels(for: source.channels)),
                  "-id3v2_version", "3", "-write_xing", "1",
                  "-fflags", "+bitexact"]
            if let title = job.title?.trimmingCharacters(in: .whitespaces), !title.isEmpty {
                a += ["-metadata", "title=\(title)"]          // ID3v2.3, any characters (M3)
            }
            a += ["-f", "mp3"]
        }
        return a + [temporary.path]
    }

    /// The WAV's checks: MacMusic's rules, ffprobe, a full decode, the
    /// length.
    func checkWAV(_ p: inout Pending, job: ConversionJob, expected: Double,
                  normalisation: Normalisation) async {
        let report = MacMusicWAVValidator.check(p.temporary)
        p.report = report
        p.problems += report.problems
        if let checked = try? await AudioInspector(tools: tools).inspect(p.temporary) {
            p.checked = checked
            if checked.codec != "pcm_u8" || checked.sampleRate != 22_050 || checked.channels != 1
                || checked.bitsPerSample != 8 {
                p.problems.append("ffprobe reads it as \(checked.codec), \(checked.sampleRate) Hz, \(checked.channels) channel(s), \(checked.bitsPerSample)-bit.")
            }
        } else {
            p.problems.append("ffprobe can't read it.")
        }
        await checkDecodes(&p)
        if abs(report.duration - expected) > 0.1 + expected * 0.01 {
            p.problems.append(String(format: "Its length is %.2f s; it should be %.2f s.", report.duration, expected))
        }
        p.warnings += MacMusicText.fileNameProblems(p.destination.lastPathComponent)
        p.peak = Self.peak(of: p.temporary)
        if case .gain(_, false) = normalisation, let peak = p.peak, peak < job.options.target - 1.5 {
            p.warnings.append(String(format: "The WAV peaks at %.1f dBFS, below the target: its channels differ, and mixing them into one lowers the peak.", peak))
        }
    }

    /// The MP3's checks (M6): ffprobe's reading (MP3, 192 kbps, the rate,
    /// the channels, the title), a full decode, the length, the peak.
    func checkMP3(_ p: inout Pending, job: ConversionJob, source: AudioInfo, expected: Double) async {
        guard let checked = try? await AudioInspector(tools: tools).inspect(p.temporary) else {
            p.problems.append("ffprobe can't read it.")
            return
        }
        p.checked = checked
        let rate = MP3Format.sampleRate(for: source.sampleRate)
        let channels = MP3Format.channels(for: source.channels)
        if checked.codec != "mp3" || !checked.formatName.contains("mp3") {
            p.problems.append("ffprobe reads it as \(checked.codec) in \(checked.formatName), not MP3.")
        }
        if checked.sampleRate != rate || checked.channels != channels {
            p.problems.append("It is \(checked.sampleRate) Hz with \(checked.channels) channel(s); it should be \(rate) Hz with \(channels).")
        }
        if let bits = checked.bitRate, abs(bits - MP3Format.bitRate) > MP3Format.bitRate / 20 {
            p.problems.append("Its bit rate is \(bits / 1000) kbps, not 192.")
        }
        if let title = job.title?.trimmingCharacters(in: .whitespaces), !title.isEmpty, checked.title != title {
            p.problems.append("Its title tag reads \"\(checked.title ?? "")\", not \"\(title)\".")
        }
        await checkDecodes(&p)
        // The length and the peak, from the MP3 itself.
        if let measured = try? await AudioAnalyser(tools: tools)
            .analyse(p.temporary, sampleRate: checked.sampleRate, channels: checked.channels) {
            if abs(measured.duration - expected) > 0.1 + expected * 0.01 {
                p.problems.append(String(format: "Its length is %.2f s; it should be %.2f s.", measured.duration, expected))
            }
            let peak = Double(measured.peak)
            let dB = peak > 0 ? 20 * log10(peak) : -Double.infinity
            p.peak = dB
            if peak > 1 {
                p.warnings.append(String(format: "The MP3 peaks at %+.1f dBFS: encoding pushed it past full scale, so it may clip on playback.", dB))
            }
        } else {
            p.problems.append("It couldn't be measured.")
        }
    }

    func checkDecodes(_ p: inout Pending) async {
        guard let decode = try? await runner.run(tools.ffmpeg, arguments: [
            "-nostdin", "-hide_banner", "-v", "error", "-i", p.temporary.path, "-f", "null", "-",
        ]) else {
            p.problems.append("It couldn't be decoded.")
            return
        }
        if decode.status != 0 || !decode.stderr.isEmpty {
            p.problems.append("It doesn't decode cleanly: \(decode.stderrText)")
        }
    }

    /// The WAV's FFmpeg filter (S3, N2, N4): keep the part to keep; apply
    /// the gain in float; average the channels into one; resample with
    /// FFmpeg's own resampler at high quality (§18.5); dither to unsigned
    /// 8-bit.
    public static func filter(channels: Int, trim: Trim? = nil, gain: Double = 0) -> String {
        var parts = shared(trim: trim, gain: gain)
        if channels > 1 {
            let share = 1.0 / Double(channels)
            let sum = (0..<channels).map { "\(share)*c\($0)" }.joined(separator: "+")
            parts.append("pan=mono|c0=\(sum)")
        }
        parts.append("aresample=\(MacMusicFormat.sampleRate):filter_size=128:phase_shift=14"
                     + ":cutoff=0.97:linear_interp=1:osf=u8:dither_method=triangular")
        return parts.joined(separator: ",")
    }

    /// The MP3's filter: the same trim and gain as the WAV, nothing more
    /// (its rate and channels are set by -ar and -ac).
    public static func mp3Filter(trim: Trim? = nil, gain: Double = 0) -> String {
        let parts = shared(trim: trim, gain: gain)
        return parts.isEmpty ? "anull" : parts.joined(separator: ",")
    }

    static func shared(trim: Trim?, gain: Double) -> [String] {
        var parts: [String] = []
        if let trim, trim.trims {
            parts.append("atrim=start_sample=\(trim.start):end_sample=\(trim.end)")
            parts.append("asetpts=PTS-STARTPTS")
        }
        if gain != 0 {
            parts.append(String(format: "volume=%.4fdB:precision=float", gain))
        }
        return parts
    }

    /// An 8-bit WAV's peak, in dBFS.
    static func peak(of wav: URL) -> Double? {
        guard let walk = try? WAVFile.chunks(of: wav),
              let data = walk.chunks.first(where: { $0.id == "data" }),
              let bytes = try? WAVFile.read(wav, offset: data.offset, count: data.size) else { return nil }
        let top = bytes.reduce(0) { max($0, abs(Int($1) - 128)) }
        return top == 0 ? -.infinity : 20 * log10(Double(top) / 128)
    }
}

/// The outputs already in place, for a cancelled job's report (§11.2).
final class Kept: @unchecked Sendable {
    private let lock = NSLock()
    private var list: [String] = []
    func add(_ path: String) { lock.withLock { list.append(path) } }
    var paths: [String] { lock.withLock { list } }
}
