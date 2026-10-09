#!/bin/sh
# Builds "MacMusic Converter Utility.app" in build/ (decisions T4, T8, P1):
# the release build of the app, wrapped in a bundle with its Info.plist and
# notices, with FFmpeg, ffprobe, yt-dlp and Deno copied from
# ~/MacPlusProjects/converter-tools into Contents/Helpers (each keeping its
# own signature), then signed ad hoc. The app is then self-contained.
#
# Usage: tools/build-app.sh
#   MMC_CONVERTER_TOOLS   the tools folder (default ~/MacPlusProjects/converter-tools)

set -eu
cd "$(dirname "$0")/.."
# xcrun's default SDK lookup fails on this Mac (BUILDING.md): name it.
SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
export SDKROOT
TOOLS=${MMC_CONVERTER_TOOLS:-$HOME/MacPlusProjects/converter-tools}
VERSION=$(sed -n 's/.*static let string = "\(.*\)".*/\1/p' Sources/MacMusicConverterKit/Version.swift)

swift build -c release --product MacMusicConverter
BIN=$(swift build -c release --show-bin-path)/MacMusicConverter

APP="build/MacMusic Converter Utility.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacMusicConverter"
sed "s/@VERSION@/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/THIRD-PARTY-NOTICES.md Resources/AppIcon.icns "$APP/Contents/Resources/"

# The tools (P1), as pinned (BUILDING.md); -p keeps them as they are.
mkdir -p "$APP/Contents/Helpers"
for pair in "ffmpeg-9.0.2/bin/ffmpeg:ffmpeg" "ffmpeg-9.0.2/bin/ffprobe:ffprobe" \
            "yt-dlp/yt-dlp_macos:yt-dlp" "deno/deno:deno"; do
    from=$TOOLS/${pair%%:*}
    [ -x "$from" ] || { echo "missing: $from (see BUILDING.md)" >&2; exit 1; }
    cp -pL "$from" "$APP/Contents/Helpers/${pair##*:}"
done
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "built $APP ($VERSION)"
