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
| `ConversionTests` (8) | real conversions: stereo, mono and 48 kHz MP3s; low bitrate; 0.2 s; the downmix averages the channels (a right-only tone at half the level); silence stays silent and full length; a corrupt file refused, nothing left behind; a truncated MP3 converted to its real length, with a warning; an existing output and the source left untouched, no partial file left |

Stage 1: 20 tests, all passing (2026-10-09), in about 0.4 s.

## Checking a file in MacMusic (from Stage 1)

A converted WAV is only known to work once MacMusic has imported and
played it (§13.5). The route: copy it onto MacMusic's `Transfer.dsk`
with hfsutils, import it in Mini vMac, play it; then on the real Plus.
Steps to be written in Stage 1.
