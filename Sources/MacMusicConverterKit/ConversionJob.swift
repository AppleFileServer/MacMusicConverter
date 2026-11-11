import Foundation

/// One conversion: a source, what to make of it, and where (§7.1).
public struct ConversionJob: Sendable {
    public var source: URL
    public var outputFolder: URL
    /// The output's file name, without extension; nil for the title, or
    /// else the source's name.
    public var name: String?
    /// The title stored in the WAV (S3), or nil for none.
    public var title: String?
    public var options: ConversionOptions
    public var conflict: ConflictPolicy
    /// What to make (§4.2; M7).
    public var outputs: OutputSelection
    /// The user has agreed to re-encode an MP3 source as a new MP3 (§2.5;
    /// M2). Without it, such a job stops before doing anything.
    public var reencodeConfirmed: Bool
    /// What the source is called, when its file's name means nothing (a
    /// download's): the video's title, for the output's name.
    public var sourceName: String?

    public init(source: URL, outputFolder: URL, name: String? = nil, title: String? = nil,
                options: ConversionOptions = ConversionOptions(), conflict: ConflictPolicy = .refuse,
                outputs: OutputSelection = .wav, reencodeConfirmed: Bool = false) {
        self.source = source
        self.outputFolder = outputFolder
        self.name = name
        self.title = title
        self.options = options
        self.conflict = conflict
        self.outputs = outputs
        self.reencodeConfirmed = reencodeConfirmed
        self.sourceName = nil
    }

    /// The name the output is based on.
    public var baseName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        if let sourceName, !sourceName.trimmingCharacters(in: .whitespaces).isEmpty { return sourceName }
        return source.deletingPathExtension().lastPathComponent
    }
}

/// How the level is set (L1): left alone, the loudest peak to a target
/// (1.0's Normalise, §6), or the loudness to a target, with a limiter.
public enum Levelling: String, Sendable, Equatable, CaseIterable, Codable {
    case off, peak, loudness
}

public struct ConversionOptions: Sendable, Equatable {
    public var levelling: Levelling
    /// Peak's target, in dBFS (§6).
    public var target: Double
    /// Loudness's target, in LUFS (L3).
    public var loudnessTarget: Double
    /// Trimming long silence at the ends (S7), longer than `trimThreshold`
    /// seconds (2 or 3).
    public var trimSilence: Bool
    public var trimThreshold: Double

    /// L3: the loudness every song is brought to, chosen by the owner
    /// (−12 at first; −16 from L10, for evenness with little limiting).
    public static let defaultLoudness = -16.0
    /// The limiter's ceiling (L5), in dBFS.
    public static let ceiling = -1.0

    /// `normalise: true` is 1.0's way of asking for Peak.
    public init(levelling: Levelling = .off, normalise: Bool = false, target: Double = -1,
                loudnessTarget: Double = ConversionOptions.defaultLoudness,
                trimSilence: Bool = false, trimThreshold: Double = 2) {
        self.levelling = normalise && levelling == .off ? .peak : levelling
        self.target = target
        self.loudnessTarget = loudnessTarget
        self.trimSilence = trimSilence
        self.trimThreshold = trimThreshold
    }

    /// 1.0's Normalise: Peak.
    public var normalise: Bool {
        get { levelling == .peak }
        set { levelling = newValue ? .peak : (levelling == .peak ? .off : levelling) }
    }
}

/// Where a job has got to (§7.1); retrieving only for YouTube.
public enum JobStage: String, Sendable, Equatable {
    case retrieving, validating, analysing, converting, validatingOutputs
    case completed, completedWithErrors, failed, cancelled
}

public enum OutputKind: String, Sendable {
    case macMusicWAV = "MacMusic WAV"
    case mp3 = "MP3"
}

/// The three choices of §4.2.
public enum OutputSelection: String, Sendable, CaseIterable {
    case mp3, wav, both

    /// In the order they're made: the WAV first, the app's main purpose.
    public var kinds: [OutputKind] {
        switch self {
        case .mp3: [.mp3]
        case .wav: [.macMusicWAV]
        case .both: [.macMusicWAV, .mp3]
        }
    }
}

/// One output's outcome, reported on its own (§4.1, §2.3).
public struct OutputResult: Sendable {
    public let kind: OutputKind
    /// Where the finished file is; nil if it failed (nothing is kept).
    public let url: URL?
    public let problems: [String]
    public let warnings: [String]
    /// The WAV's reading by MacMusic's rules (the WAV only).
    public let report: MacMusicWAVReport?
    /// ffprobe's reading of the finished file.
    public let checked: AudioInfo?
    public let size: Int64?
    /// The output's own peak, in dBFS.
    public let peak: Double?
    /// The output's loudness, in LUFS, measured on its mono mix (L7).
    public var loudness: Double? = nil

    public var succeeded: Bool { url != nil && problems.isEmpty }
}

public struct JobResult: Sendable {
    public let stage: JobStage
    public let source: AudioInfo
    public let analysis: AudioAnalysis
    public let normalisation: Normalisation
    public let trim: Trim?
    public let outputs: [OutputResult]
    /// How the level was set, and (Loudness) how much the limiter may have
    /// had to take off the loudest peak, in dB, 0 if nothing (L7).
    public var levelling: Levelling = .off
    public var limited: Double? = nil
}

public enum ConversionError: Error, Equatable, Sendable {
    case sourceMissing(String)
    case sourceUnreadable(String)
    case noAudio
    /// NaN or infinite samples in the decoded source: damaged audio.
    case brokenAudio(Int)
    case destinationUnavailable(String)
    case outputExists(String)
    case insufficientSpace(needed: Int64, available: Int64)
    case conversionFailed(String)
    case toolMissing(String)
    /// An MP3 from an MP3 needs the user's say-so (M2); nothing was done.
    case needsReencodeConfirmation
    /// Cancelled; any outputs already finished and checked are kept (§11.2).
    case cancelled(kept: [String])
}
