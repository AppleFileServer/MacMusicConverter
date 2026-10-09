#!/bin/sh
# Builds "MacMusic Converter Utility.app" in build/ (decisions T4, T8):
# the release build of the app, wrapped in a bundle with its Info.plist,
# signed ad hoc. (Later stages also copy FFmpeg and yt-dlp in, T6.)
#
# Usage: tools/build-app.sh

set -eu
cd "$(dirname "$0")/.."
# xcrun's default SDK lookup fails on this Mac (BUILDING.md): name it.
SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export SDKROOT
VERSION=$(sed -n 's/.*static let string = "\(.*\)".*/\1/p' Sources/MacMusicConverterKit/Version.swift)

swift build -c release --product MacMusicConverter
BIN=$(swift build -c release --show-bin-path)/MacMusicConverter

APP="build/MacMusic Converter Utility.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacMusicConverter"
sed "s/@VERSION@/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/THIRD-PARTY-NOTICES.md "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "built $APP ($VERSION)"
