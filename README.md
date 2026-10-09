# MacMusic Converter Utility

A macOS app for the MacMusic project: it turns music into the WAV files
the MacMusic player imports on a Macintosh Plus (mono, 22,050 samples a
second, 8-bit), and optionally into MP3s.

**Status: Stage 2 done** (`Documentation/SPECIFICATION.md` §14): the
shared engine converts local files to MacMusic WAVs, optionally
normalised and with long silence trimmed from the ends, through the
developer's command-line tool, `mmc-convert` (BUILDING.md); checked
against MacMusic's own import rules, and confirmed in MacMusic. Stage 3
added MP3s (192 kbps) and both outputs from one job; Stage 4, the
window; Stage 5, YouTube; Stage 6, hardening.

Using it: open the app, choose or drop a sound file (or, in YouTube,
paste the address of a video you may save and Look Up), pick MacMusic WAV,
MP3 or both, type a title, and Convert. The files go to
`~/Music/MacMusic Converter` unless you choose another folder. Then copy
the WAV to the Mac and import it in MacMusic.

## Building

On an Apple silicon Mac with Xcode 26:

    tools/test.sh
    tools/build-app.sh
    open "build/MacMusic Converter Utility.app"

Details: `Documentation/BUILDING.md`.

## Documents

| | |
|---|---|
| `Documentation/SPECIFICATION.md` | the requirements; decisions and findings in §18 |
| `Documentation/ARCHITECTURE.md` | how it's put together |
| `Documentation/BUILDING.md` | building, and the environment |
| `Documentation/TESTING.md` | the tests, and checking files in MacMusic |
| `Documentation/RELEASES.md` | packaging, the bundled tools and their licences |
| `Documentation/SECURITY.md` | what it does and never does with your files, network and information |
| `Resources/THIRD-PARTY-NOTICES.md` | the bundled tools' licences |
| `Documentation/CHANGELOG.md` | changes by version |

Copyright © 2026 Jack McAteer. Not affiliated with Apple or YouTube.
