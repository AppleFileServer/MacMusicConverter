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
| `EngineTests` (14) | normalising a quiet tone to −1 dBFS, lowering a full-scale one, the cap, near-silence left alone, uneven channels warned about; trimming 4 s and 3 s ends, the 3 s threshold, silence in the middle kept, trimming off; conflict policies; NaN samples refused; cancelling mid-job and before starting, leaving nothing; the stages in order; missing source and destination |
| `DualOutputTests` (11) | MP3 only (192 kbps, stereo, the title, the name); both from one job; both sharing the gain and trim (same length, both at −1 dBFS); mono, surround, 48 and 96 kHz sources; an MP3 from an MP3 refused unconfirmed, nothing written, then confirmed; one output failing (each way) keeping the other, both failing; any characters in the MP3's title; no title, no tag; cancelling with both; the source never replaced, not even by case; the MP3 rates |
| `ProcessRunnerTests` (3) | a missing tool named; arguments never parsed by a shell; cancelling stops the tool |
| `ConversionTests` (8) | real conversions: stereo, mono and 48 kHz MP3s; low bitrate; 0.2 s; the downmix averages the channels (a right-only tone at half the level); silence stays silent and full length; a corrupt file refused, nothing left behind; a truncated MP3 converted to its real length, with a warning; an existing output and the source left untouched, no partial file left |

Stage 3: 62 tests, all passing (2026-10-09), in about 4 s; run four
times, the same each time. Fixtures that aren't MP3s (so an MP3 can be
made from them unasked) are 16-bit WAVs.

Not covered yet: a full disk (the estimate is tested; Stage 6).

## Checking a file in MacMusic (from Stage 1)

A converted WAV is only known to work once MacMusic has imported and
played it (§13.5). The route: copy it onto MacMusic's `Transfer.dsk`
with hfsutils, import it in Mini vMac, play it; then on the real Plus.
Steps to be written in Stage 1.
