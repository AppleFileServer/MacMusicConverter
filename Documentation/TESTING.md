# Testing

## Automated (`tools/test.sh`)

The engine's tests, with Swift Testing. They must run without a network
connection (§13.4).

| Test | Checks |
|---|---|
Fixtures are made by FFmpeg during the tests (decision S4), so the tests
need the pinned FFmpeg (BUILDING.md) but no network and no music files.

| Suite | Checks |
|---|---|
| `formatIsSelfConsistent` | the MacMusic contract's byte rate and block align follow from its other values |
| `MacMusicTextTests` (6) | the title as MacMusic will store it: plain titles kept; curly punctuation made plain; Latin-1 letters kept, others transliterated (Ł, Cyrillic); cut to 63; blank gives none; file names over 31 characters or with a colon |
| `ValidatorTests` (5) | MacMusic's import rules against hand-made WAVs: a good file passes; not a WAV; stereo, 44.1 kHz, 16-bit, extensible, inconsistent, no data, empty data and an iPod chunk all refused; a chunk past the end; an appended title read back |
| `ProcessingTests` (9) | the gain (to the target, lowering, the +20 dB cap, silence skipped) and the trim (cut to a gap, short silence kept, 2 s vs 3 s, all-silent), and the filter's order |
| `NamingTests` (4) | unsafe characters, path tricks, hidden names, transliteration; names within 31 characters, cut at a word; refuse, next free name, replace; the space estimate |
| `EngineTests` (15) | a source over full scale warned about unless lowered; normalising a quiet tone to −1 dBFS, lowering a full-scale one, the cap, near-silence left alone, uneven channels warned about; trimming 4 s and 3 s ends, the 3 s threshold, silence in the middle kept, trimming off; conflict policies; NaN samples refused; cancelling mid-job and before starting, leaving nothing; the stages in order; missing source and destination |
| `DualOutputTests` (11) | MP3 only (192 kbps, stereo, the title, the name); both from one job; both sharing the gain and trim (same length, both at −1 dBFS); mono, surround, 48 and 96 kHz sources; an MP3 from an MP3 refused unconfirmed, nothing written, then confirmed; one output failing (each way) keeping the other, both failing; any characters in the MP3's title; no title, no tag; cancelling with both; the source never replaced, not even by case; the MP3 rates |
| `WindowLogicTests` (8) | preferences saved, loaded and tidied; the default folder; the "Saves as" names and the taken ones (the source never asked about); FFmpeg's progress read; the throttle; progress through a real two-output job; plain messages |
| `YouTubeTests` (12 + 1 live) | accepted and refused addresses (a playlist dropped); yt-dlp's errors sorted; progress lines; through a stand-in yt-dlp: the look-up and its arguments (no playlist, no cookies, the age workaround off, the address after "--"), a private video, a playlist refused, both outputs from one retrieval named after the video, an untitled job named after it, a retrieval error stopping the job, cancelling the download. The live test runs only when MMC_LIVE_YOUTUBE_URL is set |
| `HardeningTests` (12) | stopping a tool stops its children; stopping a list stops them all; leftovers (old and ours only); awkward source names (a leading "-", `concat:`, quotes, emoji, backslash, a separate accent); long titles within the limits, and converting; a read-only folder; the folder and the source removed mid-job; a full disk (a 4 MB disk image): refused up front, and, with the estimate skipped, failing mid-write with no partial file; no tools found; yt-dlp's network timeout |
| `SelfTestTests` (2) | the self-test passes with tools, and fails, saying why, without |
| `ProcessRunnerTests` (3) | a missing tool named; arguments never parsed by a shell; cancelling stops the tool |
| `ConversionTests` (8) | real conversions: stereo, mono and 48 kHz MP3s; low bitrate; 0.2 s; the downmix averages the channels (a right-only tone at half the level); silence stays silent and full length; a corrupt file refused, nothing left behind; a truncated MP3 converted to its real length, with a warning; an existing output and the source left untouched, no partial file left |

Stage 6: 95 tests, all passing (2026-10-09), in about 12 s (the disk
image), run three times, the live test skipped. Stage 5's live test: the live test passed with "Chill Dreamy Lounge" by
unfeel (No Copyright Music, the artist's channel), in about 25 s. The live test, with a video you may save:

    MMC_LIVE_YOUTUBE_URL="https://www.youtube.com/watch?v=..." tools/test.sh --filter live Fixtures that aren't MP3s (so an MP3 can be
made from them unasked) are 16-bit WAVs.

Not covered yet: a full disk (the estimate is tested; Stage 6).

## Checking a file in MacMusic (from Stage 1)

A converted WAV is only known to work once MacMusic has imported and
played it (§13.5). The route: copy it onto MacMusic's `Transfer.dsk`
with hfsutils, import it in Mini vMac, play it; then on the real Plus.
Steps to be written in Stage 1.

## Trying the window (Stage 4)

The window shows the engine's results; its logic is tested above
(`WindowLogicTests`). The window itself is checked by trying it:

    tools/build-app.sh && open "build/MacMusic Converter Utility.app"

1. **A song, both outputs:** choose (or drop) an MP3; Make: Both; type a
   title; Normalise and Trim on. Convert. Expect the re-encode question
   (it's an MP3): Re-encode. The progress line names each stage, with a
   percentage. Results: two rows (✓), sizes, Show in Finder works.
2. **Names already taken:** Convert the same again. Expect "... already
   exist": Keep Both gives "... 2.wav" and "... 2.mp3"; Replace puts the
   new ones in place; Cancel does nothing.
3. **WAV Only:** Both again, then WAV Only at the question: just the WAV.
4. **Cancel:** a long file; Cancel (or Esc) during "Making ...": "Cancelled.
   Nothing was saved."; no stray files in the folder.
5. **A file that isn't audio:** a text file renamed .mp3: the source shows
   "couldn't be read as audio"; Convert stays dimmed.
6. **The folder:** Choose… another folder; Use Default goes back to
   ~/Music/MacMusic Converter.
7. **Remembered:** quit and reopen: Make, Normalise, Trim, its seconds,
   the target (Advanced) and the folder are as left; the source, title
   and file name are not.
8. **YouTube:** paste a video's address (with a playlist in it too):
   Look Up shows its title, channel and length, and fills in the Title;
   Convert shows "Retrieving the audio from YouTube… n%", then the
   usual stages; the results as for a file. A playlist address, or a
   non-YouTube one, gets a plain message. Cancel during retrieving.
9. **Quitting mid-job:** start a conversion (YouTube, or a long file);
   press ⌘Q: "Stop the conversion and quit?"; Keep Converting carries
   on; ⌘Q again, Stop and Quit: the app quits, and nothing is left
   running (`pgrep -l "ffmpeg|yt-dlp|deno"` shows nothing).
10. **Closing mid-job:** the same with the window's close button.
11. **Closing when idle:** the app quits; no question.
12. **Licences:** Advanced, Licences… opens the notices.

## The self-test (P5)

    "<the app>/Contents/MacOS/MacMusicConverter" --self-test

No window: finds the tools inside the app only, converts a generated
tone to both outputs in a temporary folder, checks them, prints the
report, and quits (0 if it passed). `tools/make-release.sh` runs it on a
copy outside the repository.

## Before a release: the owner's acceptance run (§13.5; P7)

On the release's app, unzipped and dragged to Applications:

1. It opens from Applications; Advanced shows FFmpeg, yt-dlp and Deno
   inside the app (`…/MacMusic Converter Utility.app/Contents/Helpers`).
2. **A local MP3 to a MacMusic WAV**; the WAV's details (its row) are
   right.
3. **Into MacMusic:** copy the WAV onto `Transfer.dsk` (or the real
   Plus's disk), import it, play it; the title comes in.
4. **YouTube to MP3**, with a video you may save.
5. **The same video to both.**
6. **Cancel** a job part-way.
7. **A missing or invalid input:** a non-audio file; a non-YouTube
   address.
8. **A name already taken:** Keep Both, then Replace.
9. **The originals unchanged:** the source files as they were.
10. **Restart:** quit and reopen; your choices are remembered.

Optional, when you next use the Plus: steps 2-3 on the real Macintosh
Plus (outstanding since Stage 1).
