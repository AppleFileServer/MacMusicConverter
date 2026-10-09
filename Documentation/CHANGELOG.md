# Changelog

## 0.1.0 (in development)

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
