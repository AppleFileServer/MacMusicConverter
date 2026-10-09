# Architecture

How the app is put together (SPECIFICATION.md §7, decision T4). Updated
as each stage adds to it.

## The package

| Target | What | Depends on |
|---|---|---|
| `MacMusicTransferKit` | the engine: formats, jobs, sources, processing, outputs, validation; no SwiftUI (§7.2) | Foundation |
| `MacMusicTransfer` | the SwiftUI app: windows and controls only | the engine |
| `MacMusicTransferKitTests` | the engine's tests (Swift Testing) | the engine |

## The engine (planned, §7)

    source (local file | YouTube via yt-dlp)
        -> inspect (ffprobe)
        -> decode to 32-bit float, analyse the peak (if normalising)
        -> one gain decision
        -> branch: MacMusic WAV (resample, downmix, dither, 8-bit) | MP3
        -> write to a temporary file
        -> validate (ffprobe, and MacMusic's own rules)
        -> move into place

External tools run through one process runner, with argument arrays.

## Now (Stage 3)

| File | Does |
|---|---|
| `MacMusicFormat` | the MacMusic WAV contract's values (§18.2) |
| `ProcessRunner` | runs a tool with an argument array (no shell); captures output via temporary files; cancellable; tells a missing tool from a failed run |
| `Tools` | finds FFmpeg and ffprobe |
| `AudioInspector` | ffprobe's reading of a file (§9.2) |
| `MacMusicText` | the title as MacMusic will store it; file-name limits |
| `WAVFile` | walks a WAV's chunks as MacMusic does; appends the title (LIST/INFO/INAM) |
| `MacMusicWAVValidator` | MacMusic's import rules, one by one (T5) |
| `AudioAnalyser` | one streamed pass over the decoded source: real length, peaks, silent ends, broken samples (N1) |
| `Processing` | the decisions: `Normalisation` (N2, N3) and `Trim` (N4), plain arithmetic |
| `OutputNaming`, `DiskSpace` | safe names, the 31-character WAV name, conflicts (N7); free space (N8) |
| `ConversionJob` | the job, its options, stages, per-output results and errors (§7.1) |
| `MP3Format` | the MP3: 192 kbps, the rates MPEG allows, stereo if the source has two or more channels (M1, M4) |
| `ConversionEngine` | the shared engine (§7.2): validate (and ask before re-encoding an MP3), analyse, decide once, convert each output in its own FFmpeg run into a temporary file beside its destination, check each (the WAV: MacMusic's rules, ffprobe, a decode, the length; the MP3: ffprobe, the title, a decode, the length, the peak), move the passing ones into place; reports its stages; per-output results; cancellable, keeping only finished outputs |
| `mmt-convert` | the developer's command-line converter (S5), with `--normalise`, `--trim`, `--wav`/`--mp3`/`--both` and `--reencode` |

The WAV's conversion, as FFmpeg arguments: the first audio stream only,
no metadata, `atrim` (the kept part), `volume` (the gain, in float), `pan`
averaging the channels, `aresample` to 22,050 Hz
(filter size 128, phase shift 14, cutoff 0.97, linear interpolation)
with triangular dither to unsigned 8-bit, `pcm_u8`, bitexact.

The MP3's: the same stream, trim and gain, then `libmp3lame` at
192 kbps, the rate and channels of `MP3Format`, ID3v2.3 with the title
only, a Xing header, bitexact.

The app: still one window showing the format and the version.
