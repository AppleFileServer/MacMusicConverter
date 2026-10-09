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
| `YouTubeTests` (12 + 1 live) | accepted and refused addresses (a playlist dropped); yt-dlp's errors sorted; progress lines; through a stand-in yt-dlp: the look-up and its arguments (no playlist, no cookies, the age workaround off, the address after "--"), a private video, a playlist refused, both outputs from one retrieval named after the video, an untitled job named after it, a retrieval error stopping the job, cancelling the download. The live test runs only when MMT_LIVE_YOUTUBE_URL is set |
| `ProcessRunnerTests` (3) | a missing tool named; arguments never parsed by a shell; cancelling stops the tool |
| `ConversionTests` (8) | real conversions: stereo, mono and 48 kHz MP3s; low bitrate; 0.2 s; the downmix averages the channels (a right-only tone at half the level); silence stays silent and full length; a corrupt file refused, nothing left behind; a truncated MP3 converted to its real length, with a warning; an existing output and the source left untouched, no partial file left |

Stage 5: 83 tests, all passing (2026-10-09), in about 5 s, with the
live test skipped; the live test passed with "Chill Dreamy Lounge" by
unfeel (No Copyright Music, the artist's channel), in about 25 s. The live test, with a video you may save:

    MMT_LIVE_YOUTUBE_URL="https://www.youtube.com/watch?v=..." tools/test.sh --filter live Fixtures that aren't MP3s (so an MP3 can be
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

    tools/build-app.sh && open "build/MacMusic Transfer Utility.app"

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
   ~/Music/MacMusic Transfer.
7. **Remembered:** quit and reopen: Make, Normalise, Trim, its seconds,
   the target (Advanced) and the folder are as left; the source, title
   and file name are not.
8. **YouTube:** paste a video's address (with a playlist in it too):
   Look Up shows its title, channel and length, and fills in the Title;
   Convert shows "Retrieving the audio from YouTube… n%", then the
   usual stages; the results as for a file. A playlist address, or a
   non-YouTube one, gets a plain message. Cancel during retrieving.
