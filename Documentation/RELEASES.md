# Releases

## Distribution (decision T8)

For the owner's own use on their MacBook Neo: a `.app` signed ad hoc,
not sandboxed, not notarised. If it is ever shared, signing,
notarisation and the bundled tools' licences need revisiting.

## Bundled tools (decision T6; from Stage 1)

Pinned and checksum-verified, copied into the bundle at build time
(Stage 7). Details in `~/MacPlusProjects/converter-tools/MANIFEST.txt`
and BUILDING.md.

| Tool | Version | Licence | Notes |
|---|---|---|---|
| FFmpeg, ffprobe | 9.0.2 (Martin Riedl's static arm64 build) | GPL v3 (built with `--enable-gpl --enable-version3`; includes LAME) | own use: fine. Shared copies of the app would have to offer FFmpeg's source and carry its licence |
| yt-dlp | 2026.08.19 (`yt-dlp_macos`) | Unlicense (bundles Python and libraries under their own licences, listed in its release) | updated with `tools/update-yt-dlp.sh` |
| Deno | 2.9.7 | MIT | yt-dlp's JavaScript runtime |

## Making a release (Stage 7)

To be written.
