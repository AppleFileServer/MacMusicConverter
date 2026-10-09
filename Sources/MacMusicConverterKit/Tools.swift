import Foundation

public enum ToolsError: Error, Equatable, Sendable {
    /// FFmpeg or ffprobe wasn't found in any of these folders.
    case notFound(tool: String, searched: [String])
}

/// Where FFmpeg and ffprobe are (decisions T6, S1, S2). Looked for, in
/// order: the folder named by MMC_TOOLS_BIN; the app bundle's
/// Resources/bin (from Stage 7); the developer's pinned copy,
/// ~/MacPlusProjects/converter-tools/ffmpeg-9.0.2/bin (BUILDING.md).
public struct Tools: Sendable {
    public let ffmpeg: URL
    public let ffprobe: URL

    public static let pinnedFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("MacPlusProjects/converter-tools/ffmpeg-9.0.2/bin")

    public static func locate(environment: [String: String] = ProcessInfo.processInfo.environment,
                              resources: URL? = Bundle.main.resourceURL,
                              pinned: URL = pinnedFolder) throws -> Tools
    {
        var folders: [URL] = []
        if let named = environment["MMC_TOOLS_BIN"], !named.isEmpty {
            folders.append(URL(fileURLWithPath: named))
        }
        if let resources {
            folders.append(resources.appendingPathComponent("bin"))
        }
        folders.append(pinned)

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
