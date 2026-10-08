import Foundation

/// Text as MacMusic will see it (SPECIFICATION.md §18.2, §18.4 S3).
public enum MacMusicText {
    /// The title as the bytes of a WAV INFO tag: Latin-1, at most 63
    /// characters, or nil if nothing is left. MacMusic drops the bytes
    /// 0x80-0x9F (where Windows keeps its curly quotes), so typographic
    /// punctuation becomes plain ASCII first, and letters outside Latin-1
    /// are transliterated (Ł becomes L); anything still unencodable becomes "?".
    public static func infoTitle(_ title: String) -> Data? {
        var text = title
        let plain: [(String, String)] = [
            ("\u{2018}", "'"), ("\u{2019}", "'"), ("\u{201A}", "'"), ("\u{2032}", "'"),
            ("\u{201C}", "\""), ("\u{201D}", "\""), ("\u{201E}", "\""), ("\u{2033}", "\""),
            ("\u{2013}", "-"), ("\u{2014}", "-"), ("\u{2212}", "-"), ("\u{2026}", "..."),
            ("\u{00A0}", " "), ("\u{2022}", "*"),
        ]
        for (from, to) in plain { text = text.replacingOccurrences(of: from, with: to) }
        text = text.unicodeScalars.map { scalar -> String in
            if scalar.value < 0x20 || (0x7F...0x9F).contains(scalar.value) { return "" }
            if scalar.value <= 0xFF { return String(scalar) }
            let plain = String(scalar).applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false)
                ?? ""
            let ok = !plain.isEmpty && plain.unicodeScalars.allSatisfy { (0x20...0x7E).contains($0.value) }
            return ok ? plain : "?"
        }.joined()
        text = text.trimmingCharacters(in: .whitespaces)
        guard var bytes = text.data(using: .isoLatin1), !bytes.isEmpty else { return nil }
        if bytes.count > MacMusicFormat.maxDetailLength {
            bytes = bytes.prefix(MacMusicFormat.maxDetailLength)
        }
        return Data(bytes)
    }

    /// What's wrong with a file name for the Mac's disks (T7): too long, or
    /// a colon. Empty if it's fine.
    public static func fileNameProblems(_ name: String) -> [String] {
        var problems: [String] = []
        let length = name.data(using: .macOSRoman, allowLossyConversion: true)?.count ?? name.count
        if length > MacMusicFormat.maxFileNameLength {
            problems.append("The name is \(length) characters; the Mac's disks allow \(MacMusicFormat.maxFileNameLength).")
        }
        if name.contains(":") {
            problems.append("The name has a colon, which the Mac's disks don't allow.")
        }
        return problems
    }
}
