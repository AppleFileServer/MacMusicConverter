import SwiftUI
import MacMusicConverterKit

/// MacMusic Converter Utility: one window (Stage 4, W1-W8).
@main
struct MacMusicConverterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    /// `--self-test` (decision P5): no window; the app's own tools only;
    /// prints the report and quits, 0 if it passed.
    init() {
        guard CommandLine.arguments.contains("--self-test") else { return }
        Task.detached {
            let (passed, report) = await SelfTest.run(helpers: Tools.bundledHelpers)
            for line in report { print(line) }
            exit(passed ? 0 : 1)
        }
        DispatchSemaphore(value: 0).wait()          // until the test exits
    }

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
