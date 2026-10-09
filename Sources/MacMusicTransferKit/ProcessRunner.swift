import Foundation

/// What an external tool did: its exit status and everything it wrote.
public struct ProcessOutput: Sendable {
    public let status: Int32
    public let stdout: Data
    public let stderr: Data

    public var stdoutText: String { String(decoding: stdout, as: UTF8.self) }
    public var stderrText: String { String(decoding: stderr, as: UTF8.self) }
}

public enum ProcessRunnerError: Error, Equatable, Sendable {
    /// The tool isn't there (or can't be run): not a conversion failure.
    case executableNotFound(String)
    case launchFailed(String)
    case cancelled
}

/// Runs external tools (FFmpeg, ffprobe, later yt-dlp) for the engine
/// (SPECIFICATION.md §7.3): the arguments as an array, never through a
/// shell, so no file name or URL is ever parsed as a command; standard
/// output and error captured (into temporary files, so a chatty tool can't
/// fill a pipe and stall); off the main thread; cancelled with its task,
/// which terminates the tool.
public struct ProcessRunner: Sendable {
    public init() {}

    public func run(_ executable: URL, arguments: [String]) async throws -> ProcessOutput {
        let files = FileManager.default
        guard files.isExecutableFile(atPath: executable.path) else {
            throw ProcessRunnerError.executableNotFound(executable.path)
        }
        let dir = files.temporaryDirectory.appendingPathComponent("mmt-process-\(UUID().uuidString)")
        try files.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: dir) }
        let outURL = dir.appendingPathComponent("stdout")
        let errURL = dir.appendingPathComponent("stderr")
        files.createFile(atPath: outURL.path, contents: nil)
        files.createFile(atPath: errURL.path, contents: nil)
        let out = try FileHandle(forWritingTo: outURL)
        let err = try FileHandle(forWritingTo: errURL)

        let box = ProcessBox()
        let status: Int32 = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (done: CheckedContinuation<Int32, Error>) in
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = out
                process.standardError = err
                process.terminationHandler = { done.resume(returning: $0.terminationStatus) }
                do {
                    try box.start(process)
                } catch {
                    done.resume(throwing: error)
                }
            }
        } onCancel: {
            box.cancel()
        }
        try? out.close()
        try? err.close()
        if box.wasCancelled {
            throw ProcessRunnerError.cancelled
        }
        return ProcessOutput(status: status,
                             stdout: (try? Data(contentsOf: outURL)) ?? Data(),
                             stderr: (try? Data(contentsOf: errURL)) ?? Data())
    }
}

extension ProcessRunner {
    /// Runs a tool and hands its standard output to `receive` as it comes,
    /// a piece at a time, on a background thread (for decoded audio, too
    /// large to keep: decision N1). Standard error is captured as `run`
    /// does; the returned output's `stdout` is empty.
    public func stream(_ executable: URL, arguments: [String],
                       receive: @escaping @Sendable (Data) -> Void) async throws -> ProcessOutput {
        let files = FileManager.default
        guard files.isExecutableFile(atPath: executable.path) else {
            throw ProcessRunnerError.executableNotFound(executable.path)
        }
        let dir = files.temporaryDirectory.appendingPathComponent("mmt-process-\(UUID().uuidString)")
        try files.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: dir) }
        let errURL = dir.appendingPathComponent("stderr")
        files.createFile(atPath: errURL.path, contents: nil)
        let err = try FileHandle(forWritingTo: errURL)
        let pipe = Pipe()

        let box = ProcessBox()
        let status: Int32 = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (done: CheckedContinuation<Int32, Error>) in
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = pipe
                process.standardError = err
                // Finished when both the output has been read to its end
                // and the tool has exited (its termination handler: not
                // waitUntilExit, which can hang off the main thread).
                let finished = DispatchGroup()
                let exit = ExitStatus()
                finished.enter()
                finished.enter()
                process.terminationHandler = { exit.set($0.terminationStatus); finished.leave() }
                do {
                    try box.start(process)
                } catch {
                    done.resume(throwing: error)
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let reader = pipe.fileHandleForReading
                    while true {
                        let piece = reader.availableData
                        if piece.isEmpty { break }
                        receive(piece)
                    }
                    finished.leave()
                }
                finished.notify(queue: .global()) { done.resume(returning: exit.value) }
            }
        } onCancel: {
            box.cancel()
        }
        try? err.close()
        if box.wasCancelled {
            throw ProcessRunnerError.cancelled
        }
        return ProcessOutput(status: status, stdout: Data(),
                             stderr: (try? Data(contentsOf: errURL)) ?? Data())
    }
}

/// A tool's exit status, set by its termination handler.
private final class ExitStatus: @unchecked Sendable {
    private let lock = NSLock()
    private var status: Int32 = -1
    func set(_ s: Int32) { lock.withLock { status = s } }
    var value: Int32 { lock.withLock { status } }
}

/// The running process, shared between the task and its cancellation
/// handler.
private final class ProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var wasCancelled: Bool { lock.withLock { cancelled } }

    func start(_ process: Process) throws {
        try lock.withLock {
            if cancelled { throw ProcessRunnerError.cancelled }
            self.process = process
            do {
                try process.run()
            } catch {
                throw ProcessRunnerError.launchFailed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        let running: Process? = lock.withLock {
            cancelled = true
            return process
        }
        if let running, running.isRunning {
            running.terminate()
        }
    }
}
