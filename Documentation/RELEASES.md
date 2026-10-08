# Releases

## Distribution (decision T8)

For the owner's own use on their MacBook Neo: a `.app` signed ad hoc,
not sandboxed, not notarised. If it is ever shared, signing,
notarisation and the bundled tools' licences need revisiting.

## Bundled tools (decision T6; from Stage 1)

Pinned and checksum-verified, copied into the bundle at build time
(Stage 7). Details in `~/MacPlusProjects/transfer-tools/MANIFEST.txt`
and BUILDING.md.

| Tool | Version | Licence | Notes |
|---|---|---|---|
| FFmpeg, ffprobe | 9.0.2 (Martin Riedl's static arm64 build) | GPL v3 (built with `--enable-gpl --enable-version3`; includes LAME) | own use: fine. Shared copies of the app would have to offer FFmpeg's source and carry its licence |
| yt-dlp | (Stage 5) | Unlicense | |

## Making a release (Stage 7)

To be written.
