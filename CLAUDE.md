# MacMusic Converter Utility

## Project

A native macOS app (Swift, SwiftUI) that converts audio into WAV files
the MacMusic player can import on a Macintosh Plus, and optionally MP3s;
from a local file, or from one YouTube video the owner is entitled to
save. The requirements are `Documentation/SPECIFICATION.md` (the owner's
spec, §1-17, unedited; decisions and findings in §18).

Its sister project, MacMusic itself (the 68K player), is at
`~/MacPlusProjects/MacMusicPlayer/`. The WAV format this app makes must
match MacMusic's importer, `src/wav.c` there (§18.2).

## Build and test

    tools/test.sh          # the engine's tests (swift test)
    tools/build-app.sh     # build/MacMusic Converter Utility.app

See `Documentation/BUILDING.md` (this Mac needs the SDK named:
the scripts do it).

## Working rules

- **Plan before coding.** Lay out a plan with numbered decisions; wait
  for the owner's approval. Record decisions in SPECIFICATION.md §18.
- **Stage by stage** (§14): each stage has an acceptance criterion; meet
  it, run the tests, update the documents, report, then commit.
- **Never commit until the owner approves.**
- **Don't claim a feature works until it's built and tested** (§17).
  Record what couldn't be verified rather than guessing.
- **Throwaway diagnostics** go in the scratchpad, never in the project.
- **No screenshots or Accessibility control** of the screen, mouse or
  keyboard unless the owner explicitly asks.
- **Mini vMac:** ask the owner to quit it rather than quitting it
  yourself.
- **Process safety (§7.3):** external tools are run with argument
  arrays, never through a shell; never put a URL, title or file name in a
  command string.
- **YouTube (§8.3):** only content the owner is entitled to save; no
  access-control bypass; tests use a video the owner may download.
- **Tools (T6):** FFmpeg and yt-dlp are pinned and checksum-verified,
  kept outside the repository; never downloaded or replaced silently.

## Documents

- `README.md`: what it is, how to build and use it.
- `Documentation/SPECIFICATION.md`: the requirements, and §18.
- `Documentation/ARCHITECTURE.md`: the modules and the data flow.
- `Documentation/BUILDING.md`, `TESTING.md`, `RELEASES.md`, `CHANGELOG.md`.
