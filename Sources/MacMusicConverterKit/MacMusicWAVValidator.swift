import Foundation

/// What a WAV file is, as MacMusic would read it.
public struct MacMusicWAVReport: Sendable {
    /// Problems that would make MacMusic refuse the file (its own rules,
    /// src/wav.c), or that break this app's promises (no iPod chunk).
    public var problems: [String] = []
    public var formatTag: UInt16 = 0
    public var channels: UInt16 = 0
    public var sampleRate: UInt32 = 0
    public var bitsPerSample: UInt16 = 0
    public var dataLength = 0
    /// The INAM title, as stored (Latin-1), if any.
    public var title: String?

    public var accepted: Bool { problems.isEmpty }
    public var duration: Double { Double(dataLength) / Double(MacMusicFormat.sampleRate) }
}

/// Checks a WAV file against MacMusic 1.0's importer, rule by rule
/// (SPECIFICATION.md §18.2; MacMusic's Wav_Read in src/wav.c), so "MacMusic
/// will accept it" is tested directly rather than inferred (decision T5).
public enum MacMusicWAVValidator {
    public static func check(_ url: URL) -> MacMusicWAVReport {
        var report = MacMusicWAVReport()
        let walk: (fileLength: Int, chunks: [WAVChunk])
        do {
            walk = try WAVFile.chunks(of: url)
        } catch WAVFile.Error.notWAV {
            report.problems.append("This is not a WAV file.")
            return report
        } catch WAVFile.Error.chunkPastEnd(let id) {
            report.problems.append("The \"\(id)\" chunk runs past the end of the file.")
            return report
        } catch {
            report.problems.append("The file could not be read: \(error.localizedDescription)")
            return report
        }

        var haveFormat = false, haveData = false
        var byteRate: UInt32 = 0, blockAlign: UInt16 = 0
        for chunk in walk.chunks {
            switch chunk.id {
            case "fmt " where chunk.size >= 16:
                guard let body = try? WAVFile.read(url, offset: chunk.offset, count: 16),
                      body.count == 16 else { continue }
                report.formatTag = body.littleEndianUInt16(at: 0)
                report.channels = body.littleEndianUInt16(at: 2)
                report.sampleRate = body.littleEndianUInt32(at: 4)
                byteRate = body.littleEndianUInt32(at: 8)
                blockAlign = body.littleEndianUInt16(at: 12)
                report.bitsPerSample = body.littleEndianUInt16(at: 14)
                haveFormat = true
            case "data":
                report.dataLength = chunk.size
                haveData = true
            case "iPod":
                report.problems.append("The file has a MacMusic library chunk (\"iPod\"); a converted file must be a plain WAV.")
            case "LIST" where chunk.size >= 4:
                if let body = try? WAVFile.read(url, offset: chunk.offset,
                                                count: min(chunk.size, MacMusicFormat.maxInfoBytes)),
                   body.prefix(4) == Data("INFO".utf8) {
                    report.title = infoTitle(body) ?? report.title
                }
            default:
                break
            }
        }

        let f = MacMusicFormat.self
        if !haveFormat {
            report.problems.append("The file has no format information.")
        } else {
            if report.formatTag != f.formatTag {
                report.problems.append("The format is \(String(format: "0x%04X", report.formatTag)), not plain PCM (1).")
            }
            if report.channels != f.channels { report.problems.append("It has \(report.channels) channels, not 1.") }
            if report.sampleRate != f.sampleRate { report.problems.append("Its sample rate is \(report.sampleRate) Hz, not \(f.sampleRate).") }
            if report.bitsPerSample != f.bitsPerSample { report.problems.append("It is \(report.bitsPerSample)-bit, not 8-bit.") }
            if blockAlign != f.blockAlign || byteRate != f.byteRate {
                report.problems.append("Its format information is inconsistent (block align \(blockAlign), byte rate \(byteRate)).")
            }
        }
        if !haveData {
            report.problems.append("The file has no audio data.")
        } else if report.dataLength == 0 {
            report.problems.append("The file's audio is empty.")
        }
        // Not one of MacMusic's checks, but a well-made file has it right.
        if let riff = try? WAVFile.read(url, offset: 4, count: 4), riff.count == 4,
           Int(riff.littleEndianUInt32(at: 0)) != walk.fileLength - 8 {
            report.problems.append("The RIFF size doesn't match the file's length.")
        }
        return report
    }

    /// The INAM text of a LIST/INFO chunk's body (after "INFO").
    static func infoTitle(_ body: Data) -> String? {
        var at = 4
        while at + 8 <= body.count {
            let id = String(decoding: body.subdata(in: at..<(at + 4)), as: UTF8.self)
            let size = Int(body.littleEndianUInt32(at: at + 4))
            at += 8
            guard size <= body.count - at else { return nil }
            if id == "INAM" {
                var text = body.subdata(in: at..<(at + size))
                if let nul = text.firstIndex(of: 0) { text = text.prefix(upTo: nul) }
                return String(data: text, encoding: .isoLatin1)
            }
            at += size + (size & 1)
        }
        return nil
    }
}
