# Changelog

## 0.1.0 (in development)

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
