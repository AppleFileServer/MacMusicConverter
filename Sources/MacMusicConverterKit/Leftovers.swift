import Foundation

/// What a crash or a power cut can leave (Stage 6; H1): the app's own
/// temporary files, recognised by their names, and only once they're over
/// an hour old, so a job still running in another copy of the app is left
/// alone.
public enum Leftovers {
    public static let minimumAge: TimeInterval = 3_600

    /// Is this one of ours? ".mmc-<uuid>.wav.partial" or ".mp3.partial" in
    /// a save folder; "mmc-youtube-<uuid>" or "mmc-process-<uuid>" in the
    /// temporary folder. Also the "mmt-" names the app used before it was
    /// renamed (R7), so an earlier version's leftovers still go.
    public static func isOurs(_ name: String) -> Bool {
        ["mmc-", "mmt-"].contains { p in
            (name.hasPrefix("." + p) && name.hasSuffix(".partial"))
                || name.hasPrefix(p + "youtube-") || name.hasPrefix(p + "process-")
        }
    }

    /// Removes our leftovers from `folders`; returns what was removed.
    @discardableResult
    public static func clean(_ folders: [URL], now: Date = Date()) -> [URL] {
        let files = FileManager.default
        var removed: [URL] = []
        for folder in folders {
            guard let items = try? files.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else { continue }
            for item in items where isOurs(item.lastPathComponent) {
                let changed = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? now
                if now.timeIntervalSince(changed) >= minimumAge, (try? files.removeItem(at: item)) != nil {
                    removed.append(item)
                }
            }
        }
        return removed
    }
}
