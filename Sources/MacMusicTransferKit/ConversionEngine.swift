import Foundation

/// The shared conversion engine (§7.2): no SwiftUI; the window, the
/// command-line tool and the tests all use it. Stage 2: a local source
/// into a MacMusic WAV, with optional normalisation and silence trimming.
public struct ConversionEngine: Sendable {
    let tools: Tools
    let runner = ProcessRunner()

    public init(tools: Tools) { self.tools = tools }

    public func run(_ job: ConversionJob,
                    onStage: @escaping @Sendable (JobStage) -> Void = { _ in }) async throws -> JobResult {
        do {
            return try await perform(job, onStage: onStage)
        } catch ProcessRunnerError.cancelled {
            onStage(.cancelled)
            throw ConversionError.cancelled
        } catch is CancellationError {
            onStage(.cancelled)
            throw ConversionError.cancelled
        } catch ProcessRunnerError.executableNotFound(let path) {
            onStage(.failed)
            throw ConversionError.toolMissing(path)
        } catch {
            onStage(.failed)
            throw error
        }
    }

    func perform(_ job: ConversionJob, onStage: @escaping @Sendable (JobStage) -> Void) async throws -> JobResult {
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
        let kept = trim?.duration ?? analysis.duration

        // Where it goes, and whether it fits.
        let destination = try OutputNaming.macMusicDestination(
            folder: job.outputFolder, base: job.baseName, policy: job.conflict)
        let needed = DiskSpace.macMusicBytes(seconds: kept)
        if let free = DiskSpace.available(at: job.outputFolder), free < needed {
            throw ConversionError.insufficientSpace(needed: needed, available: free)
        }
        try Task.checkCancellation()

        // Converting, into a temporary file beside the destination, under
        // a name nobody would take for a finished file (§10, §11.2).
        onStage(.converting)
        let temporary = job.outputFolder.appendingPathComponent(".mmt-\(UUID().uuidString).wav.partial")
        defer { try? files.removeItem(at: temporary) }
        let made = try await runner.run(tools.ffmpeg, arguments: [
            "-nostdin", "-hide_banner", "-v", "error", "-n",
            "-i", job.source.path,
            "-map", "0:a:0", "-vn", "-sn", "-dn",
            "-map_metadata", "-1", "-map_chapters", "-1",
            "-af", Self.filter(channels: max(source.channels, 1), trim: trim, gain: normalisation.dB),
            "-c:a", "pcm_u8", "-ar", String(MacMusicFormat.sampleRate), "-ac", "1",
            "-fflags", "+bitexact", "-flags:a", "+bitexact",
            "-f", "wav", temporary.path,
        ])
        guard made.status == 0 else {
            throw ConversionError.conversionFailed(made.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let title = job.title, let bytes = MacMusicText.infoTitle(title) {
            try WAVFile.appendTitle(bytes, to: temporary)
        }
        try Task.checkCancellation()

        // Validating the output: MacMusic's rules, ffprobe, a full decode,
        // the length.
        onStage(.validatingOutputs)
        let report = MacMusicWAVValidator.check(temporary)
        var problems = report.problems
        if let checked = try? await AudioInspector(tools: tools).inspect(temporary) {
            if checked.codec != "pcm_u8" || checked.sampleRate != 22_050 || checked.channels != 1
                || checked.bitsPerSample != 8 {
                problems.append("ffprobe reads it as \(checked.codec), \(checked.sampleRate) Hz, \(checked.channels) channel(s), \(checked.bitsPerSample)-bit.")
            }
        } else {
            problems.append("ffprobe can't read it.")
        }
        let decode = try await runner.run(tools.ffmpeg, arguments: [
            "-nostdin", "-hide_banner", "-v", "error", "-i", temporary.path, "-f", "null", "-",
        ])
        if decode.status != 0 || !decode.stderr.isEmpty {
            problems.append("It doesn't decode cleanly: \(decode.stderrText)")
        }
        if abs(report.duration - kept) > 0.1 + kept * 0.01 {
            problems.append(String(format: "Its length is %.2f s; it should be %.2f s.", report.duration, kept))
        }
        try Task.checkCancellation()

        var warnings = MacMusicText.fileNameProblems(destination.lastPathComponent)
        if let said = source.duration, abs(said - analysis.duration) > 1 + said * 0.02 {
            warnings.append(String(format: "The source says it lasts %.1f s, but only %.1f s of it could be read: it may be damaged or cut short.",
                                   said, analysis.duration))
        }
        if let title = job.title, !title.trimmingCharacters(in: .whitespaces).isEmpty,
           MacMusicText.infoTitle(title) == nil {
            warnings.append("The title has nothing MacMusic can show, so none was stored.")
        }
        let peak = Self.peak(of: temporary)
        if case .gain(_, false) = normalisation, let peak, peak < job.options.target - 1.5 {
            warnings.append(String(format: "The WAV peaks at %.1f dBFS, below the target: its channels differ, and mixing them into one lowers the peak.", peak))
        }

        guard problems.isEmpty else {
            onStage(.failed)
            return JobResult(stage: .failed, source: source, analysis: analysis, normalisation: normalisation,
                             trim: trim, outputs: [OutputResult(kind: .macMusicWAV, url: nil, problems: problems,
                                                                warnings: warnings, report: report, size: nil, peak: peak)])
        }

        // Into place. Replacing only when the job says so (confirmed by the
        // user); otherwise the name was free a moment ago, and moveItem
        // refuses rather than overwrite if that has changed.
        if job.conflict == .replace, files.fileExists(atPath: destination.path) {
            _ = try files.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try files.moveItem(at: temporary, to: destination)
        }
        let size = (try? files.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? nil
        onStage(.completed)
        return JobResult(stage: .completed, source: source, analysis: analysis, normalisation: normalisation,
                         trim: trim, outputs: [OutputResult(kind: .macMusicWAV, url: destination, problems: [],
                                                            warnings: warnings, report: report, size: size, peak: peak)])
    }

    /// The FFmpeg filter (S3, N2, N4): keep the part to keep; apply the
    /// gain in float; average the channels into one; resample with
    /// FFmpeg's own resampler at high quality (§18.5); dither to unsigned
    /// 8-bit.
    public static func filter(channels: Int, trim: Trim? = nil, gain: Double = 0) -> String {
        var parts: [String] = []
        if let trim, trim.trims {
            parts.append("atrim=start_sample=\(trim.start):end_sample=\(trim.end)")
            parts.append("asetpts=PTS-STARTPTS")
        }
        if gain != 0 {
            parts.append(String(format: "volume=%.4fdB:precision=float", gain))
        }
        if channels > 1 {
            let share = 1.0 / Double(channels)
            let sum = (0..<channels).map { "\(share)*c\($0)" }.joined(separator: "+")
            parts.append("pan=mono|c0=\(sum)")
        }
        parts.append("aresample=\(MacMusicFormat.sampleRate):filter_size=128:phase_shift=14"
                     + ":cutoff=0.97:linear_interp=1:osf=u8:dither_method=triangular")
        return parts.joined(separator: ",")
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
