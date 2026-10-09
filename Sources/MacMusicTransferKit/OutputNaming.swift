import Foundation

/// What to do when an output's name is already taken (§9.3, §10; N7).
public enum ConflictPolicy: Sendable, Equatable {
    /// Stop, and say so (the default: existing files are preserved).
    case refuse
    /// Use the next free name: "Song 2.wav", "Song 3.wav" ...
    case uniqueName
    /// Replace it, only once the user has confirmed (Stage 4's window).
    case replace
}

/// Safe file names for the outputs (§10; N7).
public enum OutputNaming {
    /// A name that's safe as one file name: no folders, no colons, no
    /// control characters, not hidden; letters the Mac can't show
    /// transliterated; "Untitled" if nothing is left.
    public static func safeBase(_ raw: String) -> String {
        var text = raw.unicodeScalars.map { s -> String in
            if s.value < 0x20 || s.value == 0x7F { return "" }
            if s == "/" || s == ":" || s == "\\" { return "-" }
            let c = String(s)
            if c.data(using: .macOSRoman) != nil { return c }
            let plain = c.applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false) ?? ""
            return plain.data(using: .macOSRoman) != nil && !plain.isEmpty ? plain : "_"
        }.joined()
        text = text.replacingOccurrences(of: "\u{2019}", with: "'")
        while text.hasPrefix(".") || text.hasPrefix(" ") { text.removeFirst() }
        text = text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? "Untitled" : text
    }

    /// The MacMusic WAV's file name: at most 31 characters with ".wav"
    /// (the Mac's limit), cut at a word where it can be.
    public static func macMusicName(_ base: String, suffix: String = "") -> String {
        let room = MacMusicFormat.maxFileNameLength - ".wav".count - suffix.count
        var name = safeBase(base)
        if name.count > room {
            let cut = String(name.prefix(room))
            if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) >= room / 2 {
                name = String(cut[..<space])
            } else {
                name = cut
            }
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: " ,;-_"))
        }
        return name + suffix + ".wav"
    }

    /// Where the WAV goes in `folder`, by `policy`. Throws if the name is
    /// taken and the policy is to refuse.
    public static func macMusicDestination(folder: URL, base: String, policy: ConflictPolicy) throws -> URL {
        let files = FileManager.default
        let first = folder.appendingPathComponent(macMusicName(base))
        guard files.fileExists(atPath: first.path) else { return first }
        switch policy {
        case .refuse:
            throw ConversionError.outputExists(first.path)
        case .replace:
            return first
        case .uniqueName:
            for n in 2...999 {
                let url = folder.appendingPathComponent(macMusicName(base, suffix: " \(n)"))
                if !files.fileExists(atPath: url.path) { return url }
            }
            throw ConversionError.outputExists(first.path)
        }
    }
}

/// Room on the destination's disk (N8).
public enum DiskSpace {
    /// The MacMusic WAV's size for `seconds` of sound, plus a margin.
    public static func macMusicBytes(seconds: Double) -> Int64 {
        Int64(seconds * Double(MacMusicFormat.byteRate)) + 1_048_576
    }

    public static func available(at folder: URL) -> Int64? {
        let values = try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey,
                                                          .volumeAvailableCapacityKey])
        return values?.volumeAvailableCapacityForImportantUsage
            ?? values?.volumeAvailableCapacity.map(Int64.init)
    }
}
