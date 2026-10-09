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

    public init(source: URL, outputFolder: URL, name: String? = nil, title: String? = nil,
                options: ConversionOptions = ConversionOptions(), conflict: ConflictPolicy = .refuse) {
        self.source = source
        self.outputFolder = outputFolder
        self.name = name
        self.title = title
        self.options = options
        self.conflict = conflict
    }

    /// The name the output is based on.
    public var baseName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        return source.deletingPathExtension().lastPathComponent
    }
}

public struct ConversionOptions: Sendable, Equatable {
    /// Peak normalisation (§6), to `target` dBFS.
    public var normalise: Bool
    public var target: Double
    /// Trimming long silence at the ends (S7), longer than `trimThreshold`
    /// seconds (2 or 3).
    public var trimSilence: Bool
    public var trimThreshold: Double

    public init(normalise: Bool = false, target: Double = -1,
                trimSilence: Bool = false, trimThreshold: Double = 2) {
        self.normalise = normalise
        self.target = target
        self.trimSilence = trimSilence
        self.trimThreshold = trimThreshold
    }
}

/// Where a job has got to (§7.1). Stage 3 adds retrieval for YouTube.
public enum JobStage: String, Sendable, Equatable {
    case validating, analysing, converting, validatingOutputs
    case completed, completedWithErrors, failed, cancelled
}

public enum OutputKind: String, Sendable {
    case macMusicWAV = "MacMusic WAV"
}

/// One output's outcome, reported on its own (§4.1, §2.3).
public struct OutputResult: Sendable {
    public let kind: OutputKind
    /// Where the finished file is; nil if it failed (nothing is kept).
    public let url: URL?
    public let problems: [String]
    public let warnings: [String]
    public let report: MacMusicWAVReport?
    public let size: Int64?
    /// The output's own peak, in dBFS.
    public let peak: Double?

    public var succeeded: Bool { url != nil && problems.isEmpty }
}

public struct JobResult: Sendable {
    public let stage: JobStage
    public let source: AudioInfo
    public let analysis: AudioAnalysis
    public let normalisation: Normalisation
    public let trim: Trim?
    public let outputs: [OutputResult]
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
    case cancelled
}
