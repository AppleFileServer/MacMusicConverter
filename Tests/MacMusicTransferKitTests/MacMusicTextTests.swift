import Foundation
import Testing
@testable import MacMusicTransferKit

@Suite struct MacMusicTextTests {
    @Test func plainTitleIsKept() {
        #expect(MacMusicText.infoTitle("Good Luck, Babe!") == Data("Good Luck, Babe!".utf8))
    }

    @Test func curlyPunctuationBecomesPlain() {
        let bytes = MacMusicText.infoTitle("Don\u{2019}t Stop \u{2014} \u{201C}Live\u{201D}\u{2026}")!
        #expect(String(data: bytes, encoding: .isoLatin1) == "Don't Stop - \"Live\"...")
    }

    @Test func latin1AccentsStayOthersFold() {
        let bytes = MacMusicText.infoTitle("Café Łódź")!
        #expect(String(data: bytes, encoding: .isoLatin1) == "Café Lódz")   // ó is Latin-1
        #expect(MacMusicText.infoTitle("Москва") == Data("Moskva".utf8))
        #expect(bytes.allSatisfy { $0 < 0x80 || $0 >= 0xA0 })   // nothing MacMusic drops
    }

    @Test func titleIsCutTo63() {
        #expect(MacMusicText.infoTitle(String(repeating: "a", count: 80))?.count == 63)
    }

    @Test func blankTitleIsNone() {
        #expect(MacMusicText.infoTitle("   ") == nil)
        #expect(MacMusicText.infoTitle("\u{1F3B5}") == Data("?".utf8))
    }

    @Test func fileNames() {
        #expect(MacMusicText.fileNameProblems("Good Luck, Babe!.wav").isEmpty)
        #expect(MacMusicText.fileNameProblems("A Very Long Song Title Indeed Here.wav").count == 1)
        #expect(MacMusicText.fileNameProblems("Side A: Song.wav").count == 1)
    }
}
