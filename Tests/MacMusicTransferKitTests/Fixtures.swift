import Foundation
@testable import MacMusicTransferKit

/// Test files, made on the spot by FFmpeg (decision S4: no music in the
/// repository), in a fresh folder for each test.
struct Fixtures {
    let folder: URL
    let tools: Tools

    init() throws {
        tools = try Tools.locate()
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("mmt-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(at: folder) }

    func url(_ name: String) -> URL { folder.appendingPathComponent(name) }

    /// An MP3 made from an FFmpeg source description (lavfi), e.g. a tone.
    @discardableResult
    func mp3(_ name: String, source: String, rate: Int = 44_100, channels: Int = 2,
             bitrate: String = "128k") async throws -> URL {
        let out = url(name)
        let r = try await ProcessRunner().run(tools.ffmpeg, arguments: [
            "-nostdin", "-v", "error", "-f", "lavfi", "-i", source,
            "-ar", String(rate), "-ac", String(channels),
            "-c:a", "libmp3lame", "-b:a", bitrate, out.path,
        ])
        precondition(r.status == 0, r.stderrText)
        return out
    }

    /// A WAV header and body written byte by byte.
    func wav(_ name: String, format: UInt16 = 1, channels: UInt16 = 1, rate: UInt32 = 22_050,
             bits: UInt16 = 8, blockAlign: UInt16 = 1, byteRate: UInt32 = 22_050,
             data: Data? = Data(repeating: 128, count: 100), extra: [(String, Data)] = []) throws -> URL {
        var fmt = Data()
        fmt.appendLittleEndian(format); fmt.appendLittleEndian(channels)
        fmt.appendLittleEndian(rate); fmt.appendLittleEndian(byteRate)
        fmt.appendLittleEndian(blockAlign); fmt.appendLittleEndian(bits)
        var chunks: [(String, Data)] = [("fmt ", fmt)]
        if let data { chunks.append(("data", data)) }
        chunks += extra
        var body = Data("WAVE".utf8)
        for (id, content) in chunks {
            body.append(Data(id.utf8)); body.appendLittleEndian(UInt32(content.count))
            body.append(content)
            if content.count & 1 == 1 { body.append(0) }
        }
        var file = Data("RIFF".utf8); file.appendLittleEndian(UInt32(body.count)); file.append(body)
        let out = url(name)
        try file.write(to: out)
        return out
    }

    /// The 8-bit samples of a WAV's data chunk.
    func samples(_ wav: URL) throws -> [UInt8] {
        let walk = try WAVFile.chunks(of: wav)
        let data = walk.chunks.first { $0.id == "data" }!
        return [UInt8](try WAVFile.read(wav, offset: data.offset, count: data.size))
    }
}
