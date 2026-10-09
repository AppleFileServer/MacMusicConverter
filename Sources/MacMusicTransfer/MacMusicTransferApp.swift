import SwiftUI
import MacMusicTransferKit

/// MacMusic Transfer Utility: one window (Stage 4, W1-W8).
@main
struct MacMusicTransferApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("MacMusic Transfer Utility", id: "main") {
            MainWindowView(model: model)
                .onAppear { delegate.model = model }
                .background(WindowFinder { delegate.watch($0) })
        }
        .defaultSize(width: 580, height: 760)
        .windowResizability(.contentMinSize)
    }
}
