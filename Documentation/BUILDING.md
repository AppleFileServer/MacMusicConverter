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
    tools/build-app.sh      # build/MacMusic Converter Utility.app, signed ad hoc
    open "build/MacMusic Converter Utility.app"

`build/` and `.build/` are not kept in the repository.

## External tools (decisions T6, S1, S2)

Kept outside the repository, in `~/MacPlusProjects/converter-tools/`,
with a `MANIFEST.txt` (versions, URLs, checksums, signatures):

| Tool | Version | From |
|---|---|---|
| FFmpeg, ffprobe | 9.0.2, static, arm64 (GPL) | Martin Riedl's builds, ffmpeg.martin-riedl.de |
| yt-dlp | 2026.08.19, `yt-dlp_macos` (Unlicense) | github.com/yt-dlp/yt-dlp releases; behind the link `converter-tools/yt-dlp` |
| Deno | 2.9.7, aarch64 (MIT) | github.com/denoland/deno releases; behind the link `converter-tools/deno` |

The engine finds them (`Tools.locate`) in: the folder `MMC_TOOLS_BIN`
names; the app's `Contents/Resources/bin` (Stage 7); then
`~/MacPlusProjects/converter-tools/ffmpeg-9.0.2/bin`.

To fetch them again:

    T=~/MacPlusProjects/converter-tools/ffmpeg-9.0.2; mkdir -p $T/zips $T/bin; cd $T/zips
    U=https://ffmpeg.martin-riedl.de/download/macos/arm64/1789931890_9.0.2
    for f in ffmpeg.zip ffmpeg.zip.sha256 ffprobe.zip ffprobe.zip.sha256 versions.txt; do
        curl -fLO $U/$f; done
    shasum -a 256 ffmpeg.zip ffprobe.zip      # must match the .sha256 files and MANIFEST.txt
    unzip -o ffmpeg.zip -d ../bin; unzip -o ffprobe.zip -d ../bin
    spctl -a -t install -vv ../bin/ffmpeg     # "Notarized Developer ID", Martin Riedl

yt-dlp needs updating whenever YouTube changes ("yt-dlp may need
updating", in the app). Never silently:

    tools/update-yt-dlp.sh      # fetches, checks the checksum, shows the version, asks

The app finds yt-dlp and Deno (`YouTubeTools.locate`) in: `MMC_TOOLS_BIN`
(`yt-dlp`, `deno`); the app's `Contents/Resources/bin`; then
`converter-tools/yt-dlp/yt-dlp_macos` and `converter-tools/deno/deno`.

This build has no SoX resampler (it isn't configured with libsoxr), so
the converter uses FFmpeg's own at high-quality settings (§18.5).

## The developer's converter

    swift build -c release --product mmc-convert     # with SDKROOT set, as above
    .build/release/mmc-convert <input file or YouTube address> <output folder> [--title "Title"] [--name "File name"] \
        [--normalise [dBFS]] [--trim [2|3]] [--wav | --mp3 | --both] [--reencode]
