/// The WAV format the Converter makes for MacMusic, as verified against its
/// importer (MacMusic's src/wav.c; SPECIFICATION.md §18.2). The validator
/// (Stage 1) checks converted files against exactly these values.
///
/// From 1.1 (§18.25, K1) the rate is the Plus's own, 22,254 Hz (the
/// hardware's 22,254.5 to the whole number a WAV can hold), so songs play
/// at their true speed and pitch (MacMusic's issue I4). MacMusic 1.1
/// imports only 22,050 Hz; these files need MacMusic 1.2 (K2).
public enum MacMusicFormat {
    /// WAVE format tag 1: plain linear PCM. Extensible (0xFFFE) is refused.
    public static let formatTag: UInt16 = 1
    public static let channels: UInt16 = 1
    public static let sampleRate: UInt32 = 22_254
    /// 8-bit WAV samples are unsigned by definition.
    public static let bitsPerSample: UInt16 = 8
    public static let blockAlign: UInt16 = 1
    public static let byteRate: UInt32 = 22_254

    /// The longest song detail MacMusic keeps (title, artist ...).
    public static let maxDetailLength = 63
    /// The longest file name on the Mac's HFS disks (decision T7).
    public static let maxFileNameLength = 31
    /// How much of a LIST/INFO chunk MacMusic reads.
    public static let maxInfoBytes = 1_024
}
