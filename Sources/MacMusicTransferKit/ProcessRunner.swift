import Foundation
import Darwin

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
        // Off the running list the moment it ends, before the runner hears.
        let then = process.terminationHandler
        process.terminationHandler = { p in
            RunningTools.shared.remove(p.processIdentifier)
            then?(p)
        }
        try lock.withLock {
            if cancelled { throw ProcessRunnerError.cancelled }
            self.process = process
            do {
                try process.run()
            } catch {
                throw ProcessRunnerError.launchFailed(error.localizedDescription)
            }
            RunningTools.shared.add(process.processIdentifier)
        }
    }

    func cancel() {
        let running: Process? = lock.withLock {
            cancelled = true
            return process
        }
        if let running, running.isRunning {
            ProcessTree.stop(running.processIdentifier)
        }
    }
}

/// Stopping a tool and everything it started (Stage 6): yt-dlp's build
/// runs as a parent and a child, and runs Deno; FFmpeg runs alone. All of
/// them are asked to stop (SIGTERM), children found before the parent
/// goes; anything still running three seconds later is stopped outright
/// (SIGKILL).
public enum ProcessTree {
    public static func descendants(of pid: pid_t) -> [pid_t] {
        var found: [pid_t] = []
        var queue = [pid]
        while let next = queue.popLast() {
            var buffer = [pid_t](repeating: 0, count: 256)
            // It takes the buffer's size in bytes, but returns how many
            // children it found (not bytes).
            let count = proc_listchildpids(next, &buffer, Int32(MemoryLayout<pid_t>.size * buffer.count))
            guard count > 0 else { continue }
            let children = buffer.prefix(min(Int(count), buffer.count)).filter { $0 > 0 }
            found += children
            queue += children
        }
        return found
    }

    public static func stop(_ pid: pid_t) {
        let family = [pid] + descendants(of: pid)
        for p in family.reversed() { kill(p, SIGTERM) }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
            for p in family where isAlive(p) { kill(p, SIGKILL) }
        }
    }

    /// Running (not gone, and not a "zombie": ended, waiting to be
    /// cleared away, which kill(pid, 0) still counts).
    public static func isAlive(_ pid: pid_t) -> Bool {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return false }
        return info.pbi_status != 5            // SZOMB
    }
}

/// Every tool the app has running, so quitting can stop them all
/// (Stage 6; H2).
public final class RunningTools: @unchecked Sendable {
    public static let shared = RunningTools()
    private let lock = NSLock()
    private var pids: Set<pid_t> = []

    func add(_ pid: pid_t) { lock.withLock { _ = pids.insert(pid) } }
    func remove(_ pid: pid_t) { lock.withLock { _ = pids.remove(pid) } }
    public var running: [pid_t] { lock.withLock { Array(pids) } }

    /// Stops them all and waits (up to `wait` seconds) for them to go:
    /// for quitting, when nothing may be left behind.
    public func stopAll(wait: TimeInterval = 3) {
        stop(running, wait: wait)
    }

    /// Stops these (and their families), waiting up to `wait` seconds.
    func stop(_ all: [pid_t], wait: TimeInterval) {
        for pid in all {
            let family = [pid] + ProcessTree.descendants(of: pid)
            for p in family.reversed() { kill(p, SIGTERM) }
        }
        let deadline = Date().addingTimeInterval(wait)
        while Date() < deadline, all.contains(where: ProcessTree.isAlive) { usleep(50_000) }
        for pid in all where ProcessTree.isAlive(pid) {
            for p in [pid] + ProcessTree.descendants(of: pid) { kill(p, SIGKILL) }
        }
    }
}
