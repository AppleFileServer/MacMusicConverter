# Building

## The environment (2026-10-08)

| | |
|---|---|
| Mac | MacBook Neo (Mac17,5, Apple A18 Pro) |
| macOS | 26.4.1 |
| Xcode | 26.6 (17F113), macOS SDK 26.5 |
| Swift | 6.3.3 |

No Xcode project: the package is built with SwiftPM from the terminal
(decision T4). Xcode can open `Package.swift` for editing, if wanted.

## This Mac's SDK quirk

`xcrun`'s default lookup looks for the SDK in the Command Line Tools and
fails ("SDK ... cannot be located"), so `swift build` can't find it
either. Naming it works:

    export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)

`tools/test.sh` and `tools/build-app.sh` do this themselves.

## Commands

    tools/test.sh           # build and run the engine's tests
    tools/build-app.sh      # build/MacMusic Transfer Utility.app, signed ad hoc
    open "build/MacMusic Transfer Utility.app"

`build/` and `.build/` are not kept in the repository.

## External tools (from Stage 1)

FFmpeg and yt-dlp: pinned versions, checksum-verified, kept outside the
repository (decision T6). Their location, versions and how to fetch them
will be recorded here in Stage 1.
