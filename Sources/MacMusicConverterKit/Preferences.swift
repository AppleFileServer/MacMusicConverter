import Foundation

/// What the app remembers between launches (W7): the choices, not the
/// source, title or file name.
public struct Preferences: Codable, Sendable, Equatable {
    public var outputs: String = OutputSelection.wav.rawValue
    /// Off, Peak or Loudness (1.1, L1); Off by default.
    public var levelling = Levelling.off
    /// Peak's target, in dBFS.
    public var target = -1.0
    /// Loudness's target, in LUFS (L3).
    public var loudnessTarget = ConversionOptions.defaultLoudness
    public var trimSilence = false
    public var trimThreshold = 2.0
    /// The folder outputs are saved to; nil for the default (W3).
    public var folderPath: String?

    public init() {}

    /// 1.0's Normalise: Peak.
    public var normalise: Bool {
        get { levelling == .peak }
        set { levelling = newValue ? .peak : (levelling == .peak ? .off : levelling) }
    }

    public var selection: OutputSelection {
        get { OutputSelection(rawValue: outputs) ?? .wav }
        set { outputs = newValue.rawValue }
    }

    public var options: ConversionOptions {
        ConversionOptions(levelling: levelling, target: target, loudnessTarget: loudnessTarget,
                          trimSilence: trimSilence, trimThreshold: trimThreshold)
    }

    /// `~/Music/MacMusic Converter`, the default (W3); made when first used.
    public static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/MacMusic Converter", isDirectory: true)
    }

    public var folder: URL {
        folderPath.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultFolder
    }

    /// The targets kept within −6 to 0 dBFS (W2) and −16 to −8 LUFS (L3),
    /// the threshold 2 or 3 s.
    public mutating func tidy() {
        target = min(max(target, -6), 0)
        loudnessTarget = min(max(loudnessTarget, -16), -8)
        trimThreshold = trimThreshold >= 2.5 ? 3 : 2
    }

    /// Kept from the app's earlier name, "MacMusic Transfer Utility", so the
    /// choices saved then are still read (decision R6). Not shown anywhere.
    static let key = "MacMusicTransfer.preferences"

    public static func load(from defaults: UserDefaults = .standard) -> Preferences {
        guard let data = defaults.data(forKey: key),
              var p = try? JSONDecoder().decode(Preferences.self, from: data) else { return Preferences() }
        p.tidy()
        return p
    }

    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}

/// 1.1 (L1): read by hand, so that 1.0's saved choices, which have no
/// levelling, are still read (a ticked Normalise becomes Peak), and a
/// value that can't be read is left at its default rather than losing
/// every choice. `normalise` is still written, for 1.0.
extension Preferences {
    enum CodingKeys: String, CodingKey {
        case outputs, levelling, normalise, target, loudnessTarget, trimSilence, trimThreshold, folderPath
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> T? {
            (try? c.decodeIfPresent(type, forKey: key)) ?? nil
        }
        outputs = read(String.self, .outputs) ?? outputs
        let normalised = read(Bool.self, .normalise) ?? false
        levelling = read(Levelling.self, .levelling) ?? (normalised ? .peak : .off)
        target = read(Double.self, .target) ?? target
        loudnessTarget = read(Double.self, .loudnessTarget) ?? loudnessTarget
        trimSilence = read(Bool.self, .trimSilence) ?? trimSilence
        trimThreshold = read(Double.self, .trimThreshold) ?? trimThreshold
        folderPath = read(String.self, .folderPath)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(outputs, forKey: .outputs)
        try c.encode(levelling, forKey: .levelling)
        try c.encode(normalise, forKey: .normalise)
        try c.encode(target, forKey: .target)
        try c.encode(loudnessTarget, forKey: .loudnessTarget)
        try c.encode(trimSilence, forKey: .trimSilence)
        try c.encode(trimThreshold, forKey: .trimThreshold)
        try c.encodeIfPresent(folderPath, forKey: .folderPath)
    }
}
