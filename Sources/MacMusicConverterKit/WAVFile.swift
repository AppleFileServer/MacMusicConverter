import Foundation

/// A chunk of a RIFF WAVE file: its id, where its body starts, its length.
public struct WAVChunk: Sendable, Equatable {
    public let id: String
    public let offset: Int
    public let size: Int
}

/// Reading and amending WAV files, chunk by chunk, as MacMusic's importer
/// walks them (its src/wav.c).
public enum WAVFile {
    public enum Error: Swift.Error, Equatable {
        case notWAV
        case chunkPastEnd(String)
    }

    /// The file's chunks, in order. Reads only the chunk headers.
    public static func chunks(of url: URL) throws -> (fileLength: Int, chunks: [WAVChunk]) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let length = Int(try handle.seekToEnd())
        try handle.seek(toOffset: 0)
        let header = try handle.read(upToCount: 12) ?? Data()
        guard header.count == 12, header.prefix(4) == Data("RIFF".utf8),
              header.subdata(in: 8..<12) == Data("WAVE".utf8) else { throw Error.notWAV }
        var found: [WAVChunk] = []
        var at = 12
        while at + 8 <= length {
            try handle.seek(toOffset: UInt64(at))
            guard let head = try handle.read(upToCount: 8), head.count == 8 else { break }
            let id = String(decoding: head.prefix(4), as: UTF8.self)
            let size = Int(head.littleEndianUInt32(at: 4))
            at += 8
            guard size <= length - at else { throw Error.chunkPastEnd(id) }
            found.append(WAVChunk(id: id, offset: at, size: size))
            at += size + (size & 1)
        }
        return (length, found)
    }

    /// Reads part of a file.
    public static func read(_ url: URL, offset: Int, count: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        return try handle.read(upToCount: count) ?? Data()
    }

    /// Appends a LIST/INFO chunk holding just INAM (the title) and updates
    /// the RIFF size. MacMusic reads the chunk wherever it is; its own
    /// "iPod" chunk, added on import, then follows it.
    public static func appendTitle(_ title: Data, to url: URL) throws {
        var name = title
        name.append(0)                                  // INFO text ends in a NUL
        var inam = Data("INAM".utf8)
        inam.appendLittleEndian(UInt32(name.count))
        inam.append(name)
        if name.count & 1 == 1 { inam.append(0) }       // chunks are even
        var list = Data("LIST".utf8)
        list.appendLittleEndian(UInt32(4 + inam.count))
        list.append(Data("INFO".utf8))
        list.append(inam)

        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        var end = Int(try handle.seekToEnd())
        if end & 1 == 1 {                               // a missing pad byte
            handle.write(Data([0]))
            end += 1
        }
        handle.write(list)
        end += list.count
        try handle.seek(toOffset: 4)
        var riffSize = Data()
        riffSize.appendLittleEndian(UInt32(end - 8))
        handle.write(riffSize)
    }
}

extension Data {
    func littleEndianUInt32(at offset: Int) -> UInt32 {
        let b = [UInt8](self[(startIndex + offset)..<(startIndex + offset + 4)])
        return UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
    }

    func littleEndianUInt16(at offset: Int) -> UInt16 {
        let b = [UInt8](self[(startIndex + offset)..<(startIndex + offset + 2)])
        return UInt16(b[0]) | UInt16(b[1]) << 8
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF),
                            UInt8(value >> 16 & 0xFF), UInt8(value >> 24 & 0xFF)])
    }

    mutating func appendLittleEndian(_ value: UInt16) {
        append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)])
    }
}
