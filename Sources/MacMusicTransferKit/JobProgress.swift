import Foundation

/// How far a job has got (§11.1; decision W6): its stage, and how far
/// through that stage, when that can be known honestly.
public struct JobProgress: Sendable, Equatable {
    public let stage: JobStage
    /// 0 to 1 through this stage; nil when there's no honest figure (the
    /// source's length isn't known, or the stage is too quick to measure).
    public let fraction: Double?
    /// The output being made, while converting more than one.
    public let output: OutputKind?

    public init(stage: JobStage, fraction: Double? = nil, output: OutputKind? = nil) {
        self.stage = stage
        self.fraction = fraction.map { min(max($0, 0), 1) }
        self.output = output
    }

    /// From FFmpeg's -progress report: the last "out_time_us=" line, as a
    /// fraction of `length` seconds; nil if there isn't one yet, or no
    /// length.
    public static func fraction(fromFFmpegProgress text: String, length: Double?) -> Double? {
        guard let length, length > 0 else { return nil }
        let times = text.split(separator: "\n").compactMap { line -> Double? in
            guard line.hasPrefix("out_time_us=") else { return nil }
            return Double(line.dropFirst("out_time_us=".count))
        }
        guard let us = times.last else { return nil }
        return min(max(us / 1_000_000 / length, 0), 1)
    }
}

/// Passes on progress, but only when it has moved by a whole percent or
/// the stage has changed: the window needn't redraw for every sample.
final class ProgressThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var last: JobProgress?
    private let report: @Sendable (JobProgress) -> Void

    init(_ report: @escaping @Sendable (JobProgress) -> Void) { self.report = report }

    func send(_ p: JobProgress) {
        let pass: Bool = lock.withLock {
            let ok = pass_(p)
            if ok { last = p }
            return ok
        }
        if pass { report(p) }
    }

    private func pass_(_ p: JobProgress) -> Bool {
        guard let last else { return true }
        if last.stage != p.stage || last.output != p.output { return true }
        switch (last.fraction, p.fraction) {
        case (nil, nil): return false
        case (let a?, let b?): return b - a >= 0.01 || b == 1 && a < 1
        default: return true
        }
    }
}
