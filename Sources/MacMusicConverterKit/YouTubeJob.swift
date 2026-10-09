import Foundation

extension ConversionEngine {
    /// A YouTube job (Workflows A-C; Y2): the video's audio downloaded
    /// once, into a temporary folder, then converted by the same engine
    /// as a local file into every output asked for; the download deleted
    /// afterwards, whatever happens. `job` gives the outputs, options and
    /// folder; its source is replaced by the download.
    public func run(youTube video: YouTubeVideo, details: VideoDetails?, using youTube: YouTubeTools,
                    job: ConversionJob,
                    onProgress: @escaping @Sendable (JobProgress) -> Void) async throws -> JobResult {
        let files = FileManager.default
        let folder = files.temporaryDirectory.appendingPathComponent("mmc-youtube-\(UUID().uuidString)")
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: folder) }

        let retrieving = ProgressThrottle(onProgress)
        retrieving.send(JobProgress(stage: .retrieving))
        let audio: URL
        do {
            audio = try await YouTubeSource(tools: youTube).retrieveAudio(video, into: folder) { f in
                retrieving.send(JobProgress(stage: .retrieving, fraction: f))
            }
        } catch YouTubeError.cancelled {
            onProgress(JobProgress(stage: .cancelled))
            throw ConversionError.cancelled(kept: [])
        }
        if Task.isCancelled {
            onProgress(JobProgress(stage: .cancelled))
            throw ConversionError.cancelled(kept: [])
        }

        var local = job
        local.source = audio
        local.sourceName = details?.title ?? video.id
        return try await run(local, onProgress: onProgress)
    }
}
