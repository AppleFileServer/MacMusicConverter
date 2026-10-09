import Foundation

public enum ToolsError: Error, Equatable, Sendable {
    /// FFmpeg or ffprobe wasn't found in any of these folders.
    case notFound(tool: String, searched: [String])
}

/// Where FFmpeg and ffprobe are (decisions T6, S1, S2, P1). Looked for, in
/// order: the folder named by MMC_TOOLS_BIN; inside the app,
/// Contents/Helpers (a release: the app is self-contained); the
/// developer's pinned copy, ~/MacPlusProjects/converter-tools/ffmpeg-9.0.2/bin
/// (BUILDING.md).
public struct Tools: Sendable {
    public let ffmpeg: URL
    public let ffprobe: URL

    public static let pinnedFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("MacPlusProjects/converter-tools/ffmpeg-9.0.2/bin")

    /// The app's own Contents/Helpers, when running as an app.
    public static var bundledHelpers: URL? {
        let app = Bundle.main.bundleURL
        return app.pathExtension == "app" ? app.appendingPathComponent("Contents/Helpers") : nil
    }

    /// `pinned` nil looks nowhere but the folders before it (the
    /// self-test: the app's own tools only).
    public static func locate(environment: [String: String] = ProcessInfo.processInfo.environment,
                              helpers: URL? = bundledHelpers,
                              pinned: URL? = pinnedFolder) throws -> Tools
    {
        var folders: [URL] = []
        if let named = environment["MMC_TOOLS_BIN"], !named.isEmpty {
            folders.append(URL(fileURLWithPath: named))
        }
        if let helpers { folders.append(helpers) }
        if let pinned { folders.append(pinned) }

        func find(_ name: String) throws -> URL {
            for folder in folders {
                let url = folder.appendingPathComponent(name)
                if FileManager.default.isExecutableFile(atPath: url.path) { return url }
            }
            throw ToolsError.notFound(tool: name, searched: folders.map(\.path))
        }
        return Tools(ffmpeg: try find("ffmpeg"), ffprobe: try find("ffprobe"))
    }
}
