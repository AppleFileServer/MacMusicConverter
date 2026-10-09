import Foundation
import Testing
@testable import MacMusicConverterKit

@Suite struct SelfTestTests {
    /// With the pinned tools standing in for the app's own.
    @Test func passesWithTools() async {
        let (passed, report) = await SelfTest.run(helpers: nil, pinned: true)
        #expect(passed, "\(report)")
        #expect(report.last == "PASSED")
        #expect(report.contains { $0.hasPrefix("ok    MacMusic WAV") } && report.contains { $0.hasPrefix("ok    MP3") })
    }

    /// With nowhere to look (an app missing its tools), it fails, and says why.
    @Test func failsWithoutTools() async {
        let nowhere = FileManager.default.temporaryDirectory.appendingPathComponent("mmc-nothing-\(UUID().uuidString)")
        let (passed, report) = await SelfTest.run(helpers: nowhere, pinned: false)
        #expect(!passed)
        #expect(report.last?.hasPrefix("FAIL: the tools weren't found") == true)
    }
}
