import Foundation
import Testing
@testable import MacMusicTransferKit

/// The validator against hand-made files, one rule of MacMusic's at a time.
@Suite struct ValidatorTests {
    let f: Fixtures
    init() throws { f = try Fixtures() }

    @Test func goodFileIsAccepted() throws {
        let r = MacMusicWAVValidator.check(try f.wav("good.wav"))
        #expect(r.accepted, "\(r.problems)")
        #expect(r.dataLength == 100)
    }

    @Test func notWAV() throws {
        let url = f.url("text.wav")
        try Data("hello, this isn't audio".utf8).write(to: url)
        #expect(MacMusicWAVValidator.check(url).problems == ["This is not a WAV file."])
    }

    @Test func eachWrongFormatIsRefused() throws {
        let cases: [(String, URL)] = [
            ("stereo", try f.wav("stereo.wav", channels: 2, blockAlign: 2, byteRate: 44_100)),
            ("44.1 kHz", try f.wav("rate.wav", rate: 44_100, byteRate: 44_100)),
            ("16-bit", try f.wav("bits.wav", bits: 16, blockAlign: 2, byteRate: 44_100)),
            ("extensible", try f.wav("ext.wav", format: 0xFFFE)),
            ("inconsistent", try f.wav("incon.wav", byteRate: 11_025)),
            ("no data", try f.wav("nodata.wav", data: nil)),
            ("empty data", try f.wav("empty.wav", data: Data())),
            ("iPod chunk", try f.wav("ipod.wav", extra: [("iPod", Data(count: 10))])),
        ]
        for (name, url) in cases {
            #expect(!MacMusicWAVValidator.check(url).accepted, "\(name) was accepted")
        }
    }

    @Test func chunkPastTheEnd() throws {
        let url = try f.wav("cut.wav")
        let data = try Data(contentsOf: url)
        try data.prefix(data.count - 40).write(to: url)
        #expect(!MacMusicWAVValidator.check(url).accepted)
    }

    @Test func appendedTitleIsRead() throws {
        let url = try f.wav("titled.wav", data: Data(repeating: 128, count: 101))   // odd: padded
        try WAVFile.appendTitle(MacMusicText.infoTitle("Café")!, to: url)
        let r = MacMusicWAVValidator.check(url)
        #expect(r.accepted, "\(r.problems)")
        #expect(r.title == "Café")
    }
}
