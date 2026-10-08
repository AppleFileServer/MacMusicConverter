import SwiftUI
import MacMusicTransferKit

/// MacMusic Transfer Utility. Stage 0: a window that shows the app runs.
@main
struct MacMusicTransferApp: App {
    var body: some Scene {
        Window("MacMusic Transfer Utility", id: "main") {
            MainWindowView()
        }
        .windowResizability(.contentSize)
    }
}

struct MainWindowView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MacMusic Transfer Utility")
                .font(.title2.bold())
            Text("Converts audio into WAV files the MacMusic player on the Macintosh Plus can import.")
                .foregroundStyle(.secondary)
            Divider()
            LabeledContent("MacMusic format") {
                Text("WAV, \(MacMusicFormat.sampleRate) Hz, mono, \(MacMusicFormat.bitsPerSample)-bit")
            }
            LabeledContent("Version", value: AppVersion.string)
        }
        .padding(20)
        .frame(width: 440, alignment: .leading)
    }
}
