import Foundation

/// What the app remembers between launches (W7): the choices, not the
/// source, title or file name.
public struct Preferences: Codable, Sendable, Equatable {
    public var outputs: String = OutputSelection.wav.rawValue
    public var normalise = false
    public var target = -1.0
    public var trimSilence = false
    public var trimThreshold = 2.0
    /// The folder outputs are saved to; nil for the default (W3).
    public var folderPath: String?

    public init() {}

    public var selection: OutputSelection {
        get { OutputSelection(rawValue: outputs) ?? .wav }
        set { outputs = newValue.rawValue }
    }

    public var options: ConversionOptions {
        ConversionOptions(normalise: normalise, target: target,
                          trimSilence: trimSilence, trimThreshold: trimThreshold)
    }

    /// `~/Music/MacMusic Transfer`, the default (W3); made when first used.
    public static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music/MacMusic Transfer", isDirectory: true)
    }

    public var folder: URL {
        folderPath.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? Self.defaultFolder
    }

    /// The target kept within −6 to 0 dBFS (W2), the threshold 2 or 3 s.
    public mutating func tidy() {
        target = min(max(target, -6), 0)
        trimThreshold = trimThreshold >= 2.5 ? 3 : 2
    }

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
