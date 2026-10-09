import Foundation
import Testing
@testable import MacMusicConverterKit

@Suite struct NamingTests {
    @Test func unsafeCharactersGo() {
        #expect(OutputNaming.safeBase("AC/DC: Live") == "AC-DC- Live")
        #expect(OutputNaming.safeBase("../../etc/passwd") == "-..-etc-passwd")
        #expect(OutputNaming.safeBase(".hidden") == "hidden")
        #expect(OutputNaming.safeBase("tab\there") == "tabhere")
        #expect(OutputNaming.safeBase("  ") == "Untitled")
        #expect(OutputNaming.safeBase("Don\u{2019}t") == "Don't")
        #expect(OutputNaming.safeBase("Москва") == "Moskva")
        #expect(OutputNaming.safeBase("Café") == "Café")              // the Mac has é
    }

    @Test func macMusicNamesFitThirtyOne() {
        #expect(OutputNaming.macMusicName("Good Luck, Babe!") == "Good Luck, Babe!.wav")
        let long = OutputNaming.macMusicName("The Rise and Fall of a Midwest Princess")
        #expect(long.count <= 31 && long.hasSuffix(".wav"))
        #expect(long == "The Rise and Fall of a.wav")              // cut at a word
        let unbroken = OutputNaming.macMusicName(String(repeating: "x", count: 40))
        #expect(unbroken.count == 31)
        #expect(OutputNaming.macMusicName("The Rise and Fall of a Midwest", suffix: " 2").count <= 31)
    }

    @Test func conflicts() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("mmc-naming-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let taken = folder.appendingPathComponent("Song.wav")
        try Data().write(to: taken)
        try Data().write(to: folder.appendingPathComponent("Song 2.wav"))
        #expect(throws: ConversionError.outputExists(taken.path)) {
            try OutputNaming.macMusicDestination(folder: folder, base: "Song", policy: .refuse)
        }
        #expect(try OutputNaming.macMusicDestination(folder: folder, base: "Song", policy: .uniqueName)
                .lastPathComponent == "Song 3.wav")
        #expect(try OutputNaming.macMusicDestination(folder: folder, base: "Song", policy: .replace) == taken)
        #expect(try OutputNaming.macMusicDestination(folder: folder, base: "Other", policy: .refuse)
                .lastPathComponent == "Other.wav")
    }

    @Test func spaceEstimate() {
        // A minute is 1.3 MB, plus the 1 MB margin.
        #expect(DiskSpace.macMusicBytes(seconds: 60) == 1_323_000 + 1_048_576)
    }
}
