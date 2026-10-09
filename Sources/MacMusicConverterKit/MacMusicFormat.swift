/// The WAV format MacMusic 1.0 imports, as verified against its importer
/// (MacMusic's src/wav.c; SPECIFICATION.md §18.2). The validator (Stage 1)
/// checks converted files against exactly these values.
public enum MacMusicFormat {
    /// WAVE format tag 1: plain linear PCM. Extensible (0xFFFE) is refused.
    public static let formatTag: UInt16 = 1
    public static let channels: UInt16 = 1
    public static let sampleRate: UInt32 = 22_050
    /// 8-bit WAV samples are unsigned by definition.
    public static let bitsPerSample: UInt16 = 8
    public static let blockAlign: UInt16 = 1
    public static let byteRate: UInt32 = 22_050

    /// The longest song detail MacMusic keeps (title, artist ...).
    public static let maxDetailLength = 63
    /// The longest file name on the Mac's HFS disks (decision T7).
    public static let maxFileNameLength = 31
    /// How much of a LIST/INFO chunk MacMusic reads.
    public static let maxInfoBytes = 1_024
}
