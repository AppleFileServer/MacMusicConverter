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

    /// An output's file name: the WAV's within the Mac's 31 characters; the
    /// MP3's (which never goes to the Mac) the whole safe name (M4).
    public static func name(_ kind: OutputKind, _ base: String, suffix: String = "") -> String {
        switch kind {
        case .macMusicWAV: macMusicName(base, suffix: suffix)
        case .mp3: safeBase(base) + suffix + ".mp3"
        }
    }

    /// Where the WAV goes in `folder`, by `policy`. Throws if the name is
    /// taken and the policy is to refuse.
    public static func macMusicDestination(folder: URL, base: String, policy: ConflictPolicy) throws -> URL {
        try destination(.macMusicWAV, folder: folder, base: base, policy: policy)
    }

    /// Where an output goes in `folder`, by `policy`. A name that is the
    /// source itself is never replaced, whatever the policy (§9.3): it gets
    /// the next free name instead.
    public static func destination(_ kind: OutputKind, folder: URL, base: String,
                                   policy: ConflictPolicy, source: URL? = nil) throws -> URL {
        let files = FileManager.default
        let first = folder.appendingPathComponent(name(kind, base))
        guard files.fileExists(atPath: first.path) else { return first }
        var policy = policy
        if let source, sameFile(first, source) { policy = .uniqueName }
        switch policy {
        case .refuse:
            throw ConversionError.outputExists(first.path)
        case .replace:
            return first
        case .uniqueName:
            for n in 2...999 {
                let url = folder.appendingPathComponent(name(kind, base, suffix: " \(n)"))
                if !files.fileExists(atPath: url.path) { return url }
            }
            throw ConversionError.outputExists(first.path)
        }
    }
}

/// Whether two URLs are the same file on disk (this Mac's disk ignores
/// case, so names alone can't tell).
public func sameFile(_ a: URL, _ b: URL) -> Bool {
    let files = FileManager.default
    guard let x = try? files.attributesOfItem(atPath: a.path),
          let y = try? files.attributesOfItem(atPath: b.path) else { return false }
    return (x[.systemFileNumber] as? Int) == (y[.systemFileNumber] as? Int)
        && (x[.systemNumber] as? Int) == (y[.systemNumber] as? Int)
}

/// Room on the destination's disk (N8).
public enum DiskSpace {
    /// The MacMusic WAV's size for `seconds` of sound, plus a margin.
    public static func macMusicBytes(seconds: Double) -> Int64 {
        Int64(seconds * Double(MacMusicFormat.byteRate)) + 1_048_576
    }

    /// An MP3's size at 192 kbps, plus a margin (M1).
    public static func mp3Bytes(seconds: Double) -> Int64 {
        Int64(seconds * Double(MP3Format.bitRate) / 8) + 1_048_576
    }

    public static func available(at folder: URL) -> Int64? {
        let values = try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey,
                                                          .volumeAvailableCapacityKey])
        return values?.volumeAvailableCapacityForImportantUsage
            ?? values?.volumeAvailableCapacity.map(Int64.init)
    }
}
