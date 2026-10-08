import Foundation

/// One local file into one MacMusic WAV (Stage 1, the proof of concept;
/// SPECIFICATION.md §18.4 S3). Later stages put this inside the shared
/// engine, with normalisation, silence trimming and MP3 output.
public struct MacMusicConversion: Sendable {
    public let input: URL
    public let output: URL
    /// The title to store in the WAV (INAM), or nil for none.
    public let title: String?

    public init(input: URL, output: URL, title: String? = nil) {
        self.input = input
        self.output = output
        self.title = title
    }
}

public struct MacMusicConversionResult: Sendable {
    public let source: AudioInfo
    public let output: URL
    public let report: MacMusicWAVReport
    /// ffprobe's own reading of the output (§5.2's independent check).
    public let checked: AudioInfo
    /// How long the source really is, decoded (its header may say otherwise).
    public let decodedDuration: Double
    /// Things worth knowing that don't stop MacMusic using the file.
    public let warnings: [String]
}

public enum ConversionError: Error, Equatable, Sendable {
    case outputExists(String)
    case sourceUnreadable(String)
    case noAudio
    case conversionFailed(String)
    /// The converted file failed a check; it was not kept.
    case validationFailed([String])
}

public struct MacMusicConverter: Sendable {
    let tools: Tools
    let runner = ProcessRunner()

    public init(tools: Tools) { self.tools = tools }

    /// The FFmpeg filter: average the channels into one (never just drop
    /// one), resample with FFmpeg's own resampler at its high-quality
    /// settings (this build has no SoX resampler, §18.5), and dither to
    /// unsigned 8-bit.
    public static func filter(channels: Int) -> String {
        var parts: [String] = []
        if channels > 1 {
            let share = 1.0 / Double(channels)
            let sum = (0..<channels).map { "\(share)*c\($0)" }.joined(separator: "+")
            parts.append("pan=mono|c0=\(sum)")
        }
        parts.append("aresample=\(MacMusicFormat.sampleRate):filter_size=128:phase_shift=14"
                     + ":cutoff=0.97:linear_interp=1:osf=u8:dither_method=triangular")
        return parts.joined(separator: ",")
    }

    public func convert(_ job: MacMusicConversion) async throws -> MacMusicConversionResult {
        let files = FileManager.default
        // Never overwrite: not an existing file, and never the source (§9.3).
        if files.fileExists(atPath: job.output.path) {
            throw ConversionError.outputExists(job.output.path)
        }

        let source: AudioInfo
        do {
            source = try await AudioInspector(tools: tools).inspect(job.input)
        } catch AudioInspectorError.noAudio {
            throw ConversionError.noAudio
        } catch AudioInspectorError.unreadable(let why) {
            throw ConversionError.sourceUnreadable(why)
        }

        // How long it really is: an MP3's header only estimates it, and a
        // damaged or cut-short file decodes to less. (Stage 2's analysis
        // pass will measure this along with the peak.)
        let decodedDuration = try await decodedLength(of: job.input)

        // Converted beside its destination, under a name nobody would take
        // for the finished file, then moved into place once it passes.
        let temporary = job.output.deletingLastPathComponent()
            .appendingPathComponent(".mmt-\(UUID().uuidString).wav.partial")
        defer { try? files.removeItem(at: temporary) }

        let result = try await runner.run(tools.ffmpeg, arguments: [
            "-nostdin", "-hide_banner", "-v", "error", "-n",
            "-i", job.input.path,
            "-map", "0:a:0", "-vn", "-sn", "-dn",
            "-map_metadata", "-1", "-map_chapters", "-1",
            "-af", Self.filter(channels: max(source.channels, 1)),
            "-c:a", "pcm_u8", "-ar", String(MacMusicFormat.sampleRate), "-ac", "1",
            "-fflags", "+bitexact", "-flags:a", "+bitexact",
            "-f", "wav", temporary.path,
        ])
        guard result.status == 0 else {
            throw ConversionError.conversionFailed(result.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if let title = job.title, let bytes = MacMusicText.infoTitle(title) {
            try WAVFile.appendTitle(bytes, to: temporary)
        }

        // The checks: MacMusic's own rules, then ffprobe's reading, then a
        // full decode.
        let report = MacMusicWAVValidator.check(temporary)
        var problems = report.problems
        let checked = try await AudioInspector(tools: tools).inspect(temporary)
        if checked.codec != "pcm_u8" || checked.sampleRate != 22_050 || checked.channels != 1
            || checked.bitsPerSample != 8 {
            problems.append("ffprobe reads it as \(checked.codec), \(checked.sampleRate) Hz, \(checked.channels) channel(s), \(checked.bitsPerSample)-bit.")
        }
        let decode = try await runner.run(tools.ffmpeg, arguments: [
            "-nostdin", "-hide_banner", "-v", "error", "-i", temporary.path, "-f", "null", "-",
        ])
        if decode.status != 0 || !decode.stderr.isEmpty {
            problems.append("It doesn't decode cleanly: \(decode.stderrText)")
        }
        var warnings: [String] = []
        if abs(report.duration - decodedDuration) > 0.1 + decodedDuration * 0.01 {
            problems.append(String(format: "Its length is %.2f s; the source decodes to %.2f s.",
                                   report.duration, decodedDuration))
        }
        if let said = source.duration, abs(said - decodedDuration) > 1 + said * 0.02 {
            warnings.append(String(format: "The source says it lasts %.1f s, but only %.1f s of it could be read: it may be damaged or cut short.",
                                   said, decodedDuration))
        }
        guard problems.isEmpty else { throw ConversionError.validationFailed(problems) }

        warnings += MacMusicText.fileNameProblems(job.output.lastPathComponent)
        if let title = job.title, !title.isEmpty, MacMusicText.infoTitle(title) == nil {
            warnings.append("The title has nothing MacMusic can show, so none was stored.")
        }

        try files.moveItem(at: temporary, to: job.output)
        return MacMusicConversionResult(source: source, output: job.output, report: report,
                                        checked: checked, decodedDuration: decodedDuration,
                                        warnings: warnings)
    }

    /// Decodes the first audio stream to nowhere and reads how far it got
    /// (FFmpeg's -progress report: the last out_time_us).
    func decodedLength(of input: URL) async throws -> Double {
        let r = try await runner.run(tools.ffmpeg, arguments: [
            "-nostdin", "-hide_banner", "-v", "error", "-i", input.path,
            "-map", "0:a:0", "-f", "null", "-progress", "pipe:1", "-",
        ])
        guard r.status == 0 else {
            throw ConversionError.sourceUnreadable(r.stderrText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let times = r.stdoutText.split(separator: "\n").compactMap { line -> Double? in
            guard line.hasPrefix("out_time_us=") else { return nil }
            return Double(line.dropFirst("out_time_us=".count)).map { $0 / 1_000_000 }
        }
        return times.last ?? 0
    }
}
