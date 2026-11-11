import Foundation

/// What the app remembers between launches (W7): the choices, not the
/// source, title or file name. There is no level to choose (L10): every
/// song is brought to the same loudness.
public struct Preferences: Codable, Sendable, Equatable {
    public var outputs: String = OutputSelection.wav.rawValue
    public var trimSilence = false
    public var trimThreshold = 2.0
    /// The folder outputs are saved to; nil for the default (W3).
    public var folderPath: String?

    public init() {}

    public var selection: OutputSelection {
        get { OutputSelection(rawValue: outputs) ?? .wav }
        set { outputs = newValue.rawValue }
    }

    /// L10: always Loudness, to −16 LUFS.
    public var options: ConversionOptions {
        ConversionOptions(levelling: .loudness, loudnessTarget: ConversionOptions.defaultLoudness,
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

    /// The threshold 2 or 3 s.
    public mutating func tidy() {
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

/// Read by hand, so that a value that can't be read is left at its default
/// rather than losing every choice. Choices saved by 1.0 and early 1.1
/// builds are read; their Normalise, Level and targets are ignored (L10).
/// 1.0 needs `normalise` and `target` to read the rest, so they are still
/// written: Normalise off, the target at its 1.0 default.
extension Preferences {
    enum CodingKeys: String, CodingKey {
        case outputs, normalise, target, trimSilence, trimThreshold, folderPath
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func read<T: Decodable>(_ type: T.Type, _ key: CodingKeys) -> T? {
            (try? c.decodeIfPresent(type, forKey: key)) ?? nil
        }
        outputs = read(String.self, .outputs) ?? outputs
        trimSilence = read(Bool.self, .trimSilence) ?? trimSilence
        trimThreshold = read(Double.self, .trimThreshold) ?? trimThreshold
        folderPath = read(String.self, .folderPath)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(outputs, forKey: .outputs)
        try c.encode(false, forKey: .normalise)
        try c.encode(-1.0, forKey: .target)
        try c.encode(trimSilence, forKey: .trimSilence)
        try c.encode(trimThreshold, forKey: .trimThreshold)
        try c.encodeIfPresent(folderPath, forKey: .folderPath)
    }
}
