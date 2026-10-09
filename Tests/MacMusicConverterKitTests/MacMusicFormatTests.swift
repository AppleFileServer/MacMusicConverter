import Testing
@testable import MacMusicConverterKit

/// The contract's values hang together: one byte a sample, one channel,
/// so the byte rate and block align follow from the rest (§18.2).
@Test func formatIsSelfConsistent() {
    #expect(MacMusicFormat.blockAlign
            == MacMusicFormat.channels * MacMusicFormat.bitsPerSample / 8)
    #expect(MacMusicFormat.byteRate
            == MacMusicFormat.sampleRate * UInt32(MacMusicFormat.blockAlign))
}
