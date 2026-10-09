// swift-tools-version: 6.0
// MacMusic Converter Utility (Documentation/SPECIFICATION.md, decision T4):
// the engine as a library, the SwiftUI app as an executable, and the
// engine's tests. tools/build-app.sh wraps the app into a .app bundle.
import PackageDescription

let package = Package(
    name: "MacMusicConverter",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "MacMusicConverter", targets: ["MacMusicConverter"]),
        .executable(name: "mmc-convert", targets: ["mmc-convert"]),
        .library(name: "MacMusicConverterKit", targets: ["MacMusicConverterKit"]),
    ],
    targets: [
        // The conversion engine: no SwiftUI (§7.2).
        .target(name: "MacMusicConverterKit"),
        // The app: the window, and nothing the engine needs.
        .executableTarget(name: "MacMusicConverter", dependencies: ["MacMusicConverterKit"]),
        // A developer's tool (decision S5): one file into one MacMusic WAV.
        .executableTarget(name: "mmc-convert", dependencies: ["MacMusicConverterKit"]),
        .testTarget(name: "MacMusicConverterKitTests", dependencies: ["MacMusicConverterKit"]),
    ]
)
