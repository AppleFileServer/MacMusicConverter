#!/bin/sh
# Builds "MacMusic Transfer Utility.app" in build/ (decisions T4, T8):
# the release build of the app, wrapped in a bundle with its Info.plist,
# signed ad hoc. (Later stages also copy FFmpeg and yt-dlp in, T6.)
#
# Usage: tools/build-app.sh

set -eu
cd "$(dirname "$0")/.."
# xcrun's default SDK lookup fails on this Mac (BUILDING.md): name it.
SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export SDKROOT
VERSION=$(sed -n 's/.*static let string = "\(.*\)".*/\1/p' Sources/MacMusicTransferKit/Version.swift)

swift build -c release --product MacMusicTransfer
BIN=$(swift build -c release --show-bin-path)/MacMusicTransfer

APP="build/MacMusic Transfer Utility.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacMusicTransfer"
sed "s/@VERSION@/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "built $APP ($VERSION)"
