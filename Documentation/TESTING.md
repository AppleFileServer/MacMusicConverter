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
| `ProcessingTests` (17) | the gain (to the target, lowering, the +20 dB cap, silence skipped) and the trim (cut to a gap, short silence kept, 2 s vs 3 s, all-silent), and the filter's order; 1.1: the loudness gain (to the target, lowering, the cap, silence and no loudness skipped), the limiter's reduction and settings, the Loudness filter's order (float, limiter, then dither) and the MP3's, the options (Off by default, −12 LUFS, `normalise` as Peak) |
| `LevellingTests` (9) | 1.1, real conversions levelled by loudness (L3-L8): quiet noise raised and a loud tone lowered to −12 LUFS within 1 LU; a −16 target; peaks held at −1 dBFS with the length kept to 5 ms; a few dB of limiting not warned about, much more warned about ("squashed"); the +20 dB cap with no warning about the target; silence left alone; the WAV and MP3 both levelled; Peak unchanged (no limiter) |
| `LoudnessTests` (9 tests, 17 cases) | the meter (L2): a full-scale 1 kHz sine reads −3.01 LUFS at 22.05, 44.1, 48 and 96 kHz; the level follows the amplitude; silence, under 400 ms and below −70 LUFS read as none; silence around a tone gated out (edge blocks counted as the standard says); a passage 20 LU down left out, one 6 LU down counted; FFmpeg's `ebur128` on the mono mix agrees within 0.1 LU on six sources (pink and brown noise, bass, treble, mono and stereo, 22.05-48 kHz, level steps with silence); a silent source has none |
| `NamingTests` (4) | unsafe characters, path tricks, hidden names, transliteration; names within 31 characters, cut at a word; refuse, next free name, replace; the space estimate |
| `EngineTests` (15) | a source over full scale warned about unless lowered; normalising a quiet tone to −1 dBFS, lowering a full-scale one, the cap, near-silence left alone, uneven channels warned about; trimming 4 s and 3 s ends, the 3 s threshold, silence in the middle kept, trimming off; conflict policies; NaN samples refused; cancelling mid-job and before starting, leaving nothing; the stages in order; missing source and destination |
| `DualOutputTests` (11) | MP3 only (192 kbps, stereo, the title, the name); both from one job; both sharing the gain and trim (same length, both at −1 dBFS); mono, surround, 48 and 96 kHz sources; an MP3 from an MP3 refused unconfirmed, nothing written, then confirmed; one output failing (each way) keeping the other, both failing; any characters in the MP3's title; no title, no tag; cancelling with both; the source never replaced, not even by case; the MP3 rates |
| `WindowLogicTests` (12) | preferences saved, loaded and tidied; the default folder; the "Saves as" names and the taken ones (the source never asked about); FFmpeg's progress read; the throttle; progress through a real two-output job; plain messages; 1.1: Loudness and its target kept (−16 to −8 LUFS), Off by default; 1.0's saved choices read (Normalise as Peak, the rest kept); an unreadable choice losing only itself; `normalise` still written for 1.0 |
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

1.1, Stage 3 (2026-11-04): 128 tests, all passing, in about 16 s; the app built and its self-test passed. 1.1, Stage 2: 124 tests, all passing, in about 14 s, run twice. 1.1, Stage 1: 106 tests. Checked by hand, outside the tests (no music in the repository, S4): 13 of the owner's songs, read by the meter and by FFmpeg's `ebur128`, agree to FFmpeg's one decimal place (−12.6 to −20.2 LUFS).

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
   title; Level: Peak, and Trim on. Convert. Expect the re-encode question
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
7. **Remembered:** quit and reopen: Make, Level, Trim, its seconds,
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
13. **Level (1.1):** Off, Peak and Loudness each change the line under
   them (Peak names its dBFS, Loudness its LUFS); Advanced has "Peak to"
   (−6 to 0 dBFS) and "Loudness to" (−16 to −8 LUFS). Convert a quiet
   song with Loudness, Both: the result says "Levelled from … LUFS by …",
   with what the limiter took off; each row shows its peak and LUFS.
   A 1.0 user's Normalise comes back as Peak.

## The self-test (P5)

    "<the app>/Contents/MacOS/MacMusicConverter" --self-test

No window: finds the tools inside the app only, converts a generated
tone to both outputs in a temporary folder, checks them, prints the
report, and quits (0 if it passed). `tools/make-release.sh` runs it on a
copy outside the repository.

## Before a release: the owner's acceptance run (§13.5; P7)

On the release's app, unzipped and dragged to Applications:

1. It shows its icon (the compact computer with the red badge) in
   Applications and the Dock, and opens from Applications; Advanced shows FFmpeg, yt-dlp and Deno
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

### The 1.0 acceptance run (2026-10-09)

On the release candidate made from commit 87879f4
(`~/MacPlusProjects/releases/MacMusic-Converter-Utility-1.0/`), unzipped
and installed in Applications by the owner: "I've checked the app and it
runs very well." Recorded as given; the steps weren't reported one by
one. Checked before it by the release script: 97 tests, and the
self-test on a copy outside the repository with the app's own tools.
Earlier, in development: the owner's import and playback in MacMusic
(Mini vMac) of a converted WAV (Stage 1), and the window's checks 1-12
(Stages 4-6). Still optional: a WAV on the real Macintosh Plus.
