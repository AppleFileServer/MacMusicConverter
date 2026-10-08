// swift-tools-version: 6.0
// MacMusic Transfer Utility (Documentation/SPECIFICATION.md, decision T4):
// the engine as a library, the SwiftUI app as an executable, and the
// engine's tests. tools/build-app.sh wraps the app into a .app bundle.
import PackageDescription

let package = Package(
    name: "MacMusicTransfer",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "MacMusicTransfer", targets: ["MacMusicTransfer"]),
        .executable(name: "mmt-convert", targets: ["mmt-convert"]),
        .library(name: "MacMusicTransferKit", targets: ["MacMusicTransferKit"]),
    ],
    targets: [
        // The conversion engine: no SwiftUI (§7.2).
        .target(name: "MacMusicTransferKit"),
        // The app: the window, and nothing the engine needs.
        .executableTarget(name: "MacMusicTransfer", dependencies: ["MacMusicTransferKit"]),
        // A developer's tool (decision S5): one file into one MacMusic WAV.
        .executableTarget(name: "mmt-convert", dependencies: ["MacMusicTransferKit"]),
        .testTarget(name: "MacMusicTransferKitTests", dependencies: ["MacMusicTransferKit"]),
    ]
)
