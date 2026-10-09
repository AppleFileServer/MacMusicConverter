import Foundation

/// The names a job will save as, worked out before it runs (W4): for the
/// window's "Saves as" line, and to ask about taken names before starting.
public struct PlannedOutput: Sendable, Equatable {
    public let kind: OutputKind
    /// The name it gets if nothing is in the way.
    public let name: String
    /// Something already has that name.
    public let taken: Bool
    /// ... and it's the source itself, which is never replaced: it will get
    /// the next free name whatever the user chooses.
    public let isSource: Bool
}

public enum OutputPreview {
    public static func plan(_ job: ConversionJob) -> [PlannedOutput] {
        job.outputs.kinds.map { kind in
            let name = OutputNaming.name(kind, job.baseName)
            let url = job.outputFolder.appendingPathComponent(name)
            let taken = FileManager.default.fileExists(atPath: url.path)
            return PlannedOutput(kind: kind, name: name, taken: taken,
                                 isSource: taken && sameFile(url, job.source))
        }
    }

    /// The outputs whose names are taken by something other than the source:
    /// the ones to ask about.
    public static func conflicts(_ job: ConversionJob) -> [PlannedOutput] {
        plan(job).filter { $0.taken && !$0.isSource }
    }
}
