# Changelog

## 1.1 (2026-11-12)

- Stage 1, the loudness meter (SPECIFICATION.md §18.20, L2): every
  source's loudness is measured, by ITU-R BS.1770-4 / EBU R128, on the
  mono mix the WAV is made from. Not yet used: Loudness levelling comes
  in Stage 2.
- Stage 2, the engine (§18.20, L3-L8): Loudness levelling, with a
  limiter at −1 dBFS, for the WAV and the MP3; the result gives the
  source's loudness, the gain, what the limiter takes off (a warning over
  6 dB) and each output's loudness; `mmc-convert --loudness [LUFS]`.
  Peak (1.0's Normalise) is unchanged.
- Stage 3, the window (L1, L7): Level, Off, Peak or Loudness, in place
  of Normalise, with a line saying what each does; "Loudness to" in
  Advanced; the result says where the song was levelled from and what
  the limiter took off, and each output its loudness. 1.0's saved
  choices are read (Normalise as Peak).
- Stage 4, after the owner's listening test (§18.24, L10): no level to
  choose. Every song is levelled by loudness to −16 LUFS (was −12, and a
  choice), so all songs sound equally loud with little limiting. Level,
  "Peak to" and "Loudness to" are gone from the window; earlier saved
  choices are read, their level settings ignored.
- The Plus's own rate (§18.25, K1-K6): MacMusic WAVs are made at
  22,254 Hz, not 22,050, so songs play at their true speed and pitch on
  the Plus (MacMusic's issue I4: 0.9% fast). They need MacMusic 1.2,
  which is to accept the new rate; MacMusic 1.1 refuses them.
- Released 2026-11-12 by the owner's choice ahead of MacMusic 1.2, which
  is built (its candidate plays these WAVs) but awaits its checks on the
  real Plus. Until it's released, the WAVs need the MacMusic 1.2
  candidate, and the Transfer Utility 2.0 (unreleased; 1.0 takes only
  22,050 Hz).

## 1.0 (2026-10-09)

- The app's icon: a compact computer showing a 1-bit note, with a convert
  badge in the manual's red (`Resources/Icon/AppIcon.svg`,
  `tools/make-icon.sh`).

- Stage 7, packaging: FFmpeg, ffprobe, yt-dlp and Deno inside the app
  (Contents/Helpers), keeping their signatures: the app is
  self-contained. `--self-test`. `tools/make-release.sh` (tests, the app,
  the self-test outside the repository, the zip, checksums, the source,
  the tools' manifest, the checks). Release notes.

## 0.1.0 (in development)

- Renamed: the MacMusic Transfer Utility is now the **MacMusic Converter
  Utility** (SPECIFICATION.md §18.16). The `.app`, the window, the code's
  names, the repository and tools folders, the default save folder and
  the developer's tool (`mmc-convert`) follow; the bundle identifier and
  the preferences key are kept, so saved settings carry over. Earlier
  entries keep the old names.

- Stage 6, hardening: cancelling and quitting stop every tool and what
  it started; closing the window quits, asking first during a job; a
  crash's temporary files cleaned at launch; MP3 names within 200 bytes,
  keeping every character; a vanished folder or failed move fails that
  output only; yt-dlp's network timeout and no cookie files; tests for
  awkward names, read-only and vanishing folders, a full disk, no tools.
  SECURITY.md and the third-party notices (in the app: Licences…).
  95 tests.

- Stage 5, YouTube: paste one video's address (a playlist in it
  dropped), Look Up its details, Convert: its audio retrieved once,
  converted to the WAV, the MP3 or both, the download deleted; no
  sign-in, cookies or age workaround; plain messages for what yt-dlp
  reports. yt-dlp 2026.08.19 and Deno 2.9.7 pinned;
  `tools/update-yt-dlp.sh`. 82 tests, offline, plus a live one on
  request.

- Stage 4, the window: Local File mode (YouTube "coming soon"): choose or
  drop a file; MacMusic WAV, MP3 or both; title and file name, with the
  names it'll save as; normalise and trim; the save folder
  (~/Music/MacMusic Transfer by default); Advanced (target, formats,
  FFmpeg); progress by stage and percentage; Cancel; results with Show in
  Finder; the re-encode and taken-name questions; choices remembered.
  Progress reporting in the engine. 70 tests.

- Stage 3, MP3 output and both outputs: MP3s at 192 kbps, stereo when
  the source is, titled; the WAV, the MP3 or both from one job, with one
  analysis, gain and trim; each output made, checked and reported on its
  own, one failing leaving the other; MP3 from MP3 only when confirmed;
  the source never overwritten, even under "replace"; cancelling keeps
  only finished outputs. `mmt-convert --both --reencode`. 62 tests.

- Stage 2, the shared conversion engine: the job model and its stages;
  one streamed analysis pass (real length, peaks, silent ends, broken
  samples); optional peak normalisation (−1 dBFS, +20 dB at most,
  silence left alone); the owner's optional silence trimming (ends only,
  over 2 or 3 s, cut to half a second); safe names within the Mac's 31
  characters, with conflict policies; a free-space check; cancelling
  that leaves nothing behind. `mmt-convert --normalise --trim`. 51 tests.

- Stage 1, the PCM proof of concept: the process runner, the tool
  locator, the ffprobe inspector, the title as MacMusic stores it, the
  WAV chunk reader, a validator applying MacMusic's import rules, and
  the converter (one local file into one MacMusic WAV, checked three
  ways, never overwriting); `mmt-convert`; 20 tests. FFmpeg 9.0.2 pinned
  outside the repository. "Good Luck, Babe!" converted, imported and
  played in MacMusic (Mini vMac), its title filled in from the WAV.

- Stage 0: the repository, the specification with the Stage 0 decisions
  (T1-T8) and the verified MacMusic WAV contract, a Swift package with
  the engine library, a minimal SwiftUI app and one test; the build and
  test scripts.
