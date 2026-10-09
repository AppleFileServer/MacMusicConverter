# Releases

## Distribution (decisions T8, P1-P4)

For the owner's own use on their MacBook Neo: a `.app` signed ad hoc,
not sandboxed, not notarised, with its tools inside it
(`Contents/Helpers`: ffmpeg, ffprobe, yt-dlp, Deno, each keeping its own
signature), so it runs without the development folders. About 240 MB.
If it is ever shared, signing, notarisation and the bundled tools'
licences need revisiting (SECURITY.md).

## Bundled tools (decision T6; from Stage 1)

Pinned and checksum-verified, copied into the app's `Contents/Helpers`
by `tools/build-app.sh`. Details in
`~/MacPlusProjects/converter-tools/MANIFEST.txt` and BUILDING.md; the
notices in `Resources/THIRD-PARTY-NOTICES.md` (in the app: Advanced >
Licences…).

| Tool | Version | Licence | Notes |
|---|---|---|---|
| FFmpeg, ffprobe | 9.0.2 (Martin Riedl's static arm64 build) | GPL v3 (built with `--enable-gpl --enable-version3`; includes LAME) | own use: fine. Shared copies of the app would have to offer FFmpeg's source and carry its licence |
| yt-dlp | 2026.08.19 (`yt-dlp_macos`) | Unlicense (bundles Python and libraries under their own licences, listed in its release) | updated with `tools/update-yt-dlp.sh` |
| Deno | 2.9.7 | MIT | yt-dlp's JavaScript runtime |

## Making a release (Stage 7)

1. Set the version in `Sources/MacMusicConverterKit/Version.swift`; add
   it to `CHANGELOG.md`; update `RELEASE-NOTES.md`; commit.
2. `tools/make-release.sh`: refuses uncommitted changes; runs the tests;
   builds the app with its tools; runs the self-test on a copy outside
   the repository, with the app's own tools only; writes
   `~/MacPlusProjects/releases/MacMusic-Converter-Utility-<version>/`:
   the zipped app, the release notes, `SHA256SUMS`, the source (a git
   bundle), the tools' manifest, and `checks/` (the tests' output, the
   self-test's, and what made it).
3. The owner's acceptance run (TESTING.md, "Before a release") on the
   unzipped app, from Applications; its record in TESTING.md; commit.
4. Tag: `git tag -a v<version> -m "MacMusic Converter Utility <version>"`.
5. `tools/make-release.sh --bundle`: puts the tagged source bundle in the
   release, and refreshes `SHA256SUMS`.

The self-test can be run on any copy of the app:

    "/Applications/MacMusic Converter Utility.app/Contents/MacOS/MacMusicConverter" --self-test

## Updating yt-dlp (P2)

`tools/update-yt-dlp.sh` (checks and asks), then `tools/build-app.sh`, or
a new release, so the app carries the new copy. The app itself is never
changed in place (that would break its signature).
