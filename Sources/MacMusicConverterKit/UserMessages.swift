import Foundation

/// What to tell the user (§11.3): a short plain explanation; the technical
/// detail kept apart, for troubleshooting.
public struct UserMessage: Sendable, Equatable {
    public let summary: String
    public let detail: String?

    public init(summary: String, detail: String?) {
        self.summary = summary
        self.detail = detail
    }
}

extension ConversionError {
    public var message: UserMessage {
        switch self {
        case .sourceMissing(let path):
            UserMessage(summary: "The file couldn't be found. It may have been moved or deleted.", detail: path)
        case .sourceUnreadable(let why):
            UserMessage(summary: "The file couldn't be read as audio. It may be damaged, or not a sound file.",
                        detail: why.isEmpty ? nil : why)
        case .noAudio:
            UserMessage(summary: "The file has no sound in it.", detail: nil)
        case .brokenAudio(let n):
            UserMessage(summary: "The file's sound is damaged, so it can't be converted.",
                        detail: "\(n) samples could not be decoded (NaN or infinite).")
        case .destinationUnavailable(let path):
            UserMessage(summary: "The folder to save to isn't available, or can't be written to. Choose another.",
                        detail: path)
        case .outputExists(let path):
            UserMessage(summary: "A file with that name is already there.", detail: path)
        case .insufficientSpace(let needed, let available):
            UserMessage(summary: "There isn't enough room on the disk to save the converted files.",
                        detail: "Needs about \(ByteCountFormatter.string(fromByteCount: needed, countStyle: .file)); "
                            + "\(ByteCountFormatter.string(fromByteCount: available, countStyle: .file)) free.")
        case .conversionFailed(let why):
            UserMessage(summary: "The conversion failed.", detail: why)
        case .toolMissing(let path):
            UserMessage(summary: "FFmpeg, which the conversion needs, couldn't be found.", detail: path)
        case .needsReencodeConfirmation:
            UserMessage(summary: "The file is already an MP3. Making a new MP3 from it loses a little quality.",
                        detail: nil)
        case .cancelled(let kept):
            UserMessage(summary: kept.isEmpty ? "Cancelled. Nothing was saved."
                                              : "Cancelled. The files already finished were kept.",
                        detail: kept.isEmpty ? nil : kept.joined(separator: "\n"))
        }
    }
}

extension ToolsError {
    public var message: UserMessage {
        switch self {
        case .notFound(let tool, let searched):
            UserMessage(summary: "\(tool), which the conversion needs, couldn't be found.",
                        detail: "Looked in:\n" + searched.joined(separator: "\n"))
        }
    }
}
