import SwiftUI
import MacMusicConverterKit

/// MacMusic Converter Utility: one window (Stage 4, W1-W8).
@main
struct MacMusicConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("MacMusic Converter Utility", id: "main") {
            MainWindowView(model: model)
                .onAppear { delegate.model = model }
                .background(WindowFinder { delegate.watch($0) })
        }
        .defaultSize(width: 580, height: 760)
        .windowResizability(.contentMinSize)
    }
}
