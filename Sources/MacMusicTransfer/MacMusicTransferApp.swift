import SwiftUI
import MacMusicTransferKit

/// MacMusic Transfer Utility: one window (Stage 4, W1-W8).
@main
struct MacMusicTransferApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("MacMusic Transfer Utility", id: "main") {
            MainWindowView(model: model)
        }
        .defaultSize(width: 580, height: 760)
        .windowResizability(.contentMinSize)
    }
}
