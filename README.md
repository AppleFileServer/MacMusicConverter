# MacMusic Transfer Utility

A macOS app for the MacMusic project: it turns music into the WAV files
the MacMusic player imports on a Macintosh Plus (mono, 22,050 samples a
second, 8-bit), and optionally into MP3s.

**Status: Stage 2 done** (`Documentation/SPECIFICATION.md` §14): the
shared engine converts local files to MacMusic WAVs, optionally
normalised and with long silence trimmed from the ends, through the
developer's command-line tool, `mmt-convert` (BUILDING.md); checked
against MacMusic's own import rules, and confirmed in MacMusic. Stage 3
added MP3s (192 kbps) and both outputs from one job. The window comes in
Stage 4.

## Building

On an Apple silicon Mac with Xcode 26:

    tools/test.sh
    tools/build-app.sh
    open "build/MacMusic Transfer Utility.app"

Details: `Documentation/BUILDING.md`.

## Documents

| | |
|---|---|
| `Documentation/SPECIFICATION.md` | the requirements; decisions and findings in §18 |
| `Documentation/ARCHITECTURE.md` | how it's put together |
| `Documentation/BUILDING.md` | building, and the environment |
| `Documentation/TESTING.md` | the tests, and checking files in MacMusic |
| `Documentation/RELEASES.md` | packaging, the bundled tools and their licences |
| `Documentation/CHANGELOG.md` | changes by version |

Copyright © 2026 Jack McAteer. Not affiliated with Apple or YouTube.
