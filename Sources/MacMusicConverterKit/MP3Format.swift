/// The MP3 this app makes (§5.3; decisions M1, M3, M4).
public enum MP3Format {
    /// 192 kbps, constant: the one bitrate (the owner's choice, M1).
    public static let bitRate = 192_000
    /// The sample rates MPEG audio allows; a source at another rate is
    /// given the nearest one below it (or 44,100 Hz).
    public static let sampleRates = [8_000, 11_025, 12_000, 16_000, 22_050, 24_000, 32_000, 44_100, 48_000]

    public static func sampleRate(for source: Int) -> Int {
        if sampleRates.contains(source) { return source }
        return sampleRates.last { $0 < source } ?? 44_100
    }

    /// Stereo whenever the source has two or more channels (more are mixed
    /// down to two); a mono source stays mono (M4, the owner's choice).
    public static func channels(for source: Int) -> Int { source >= 2 ? 2 : 1 }
}
