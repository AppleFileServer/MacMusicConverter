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

## Now (Stage 1)

| File | Does |
|---|---|
| `MacMusicFormat` | the MacMusic WAV contract's values (§18.2) |
| `ProcessRunner` | runs a tool with an argument array (no shell); captures output via temporary files; cancellable; tells a missing tool from a failed run |
| `Tools` | finds FFmpeg and ffprobe |
| `AudioInspector` | ffprobe's reading of a file (§9.2) |
| `MacMusicText` | the title as MacMusic will store it; file-name limits |
| `WAVFile` | walks a WAV's chunks as MacMusic does; appends the title (LIST/INFO/INAM) |
| `MacMusicWAVValidator` | MacMusic's import rules, one by one (T5) |
| `MacMusicConverter` | one file into one MacMusic WAV: inspect, measure the real length, convert into a temporary file beside the destination, add the title, check (MacMusic's rules, ffprobe, a full decode, the length), then move into place; never overwrites |
| `mmt-convert` | the developer's command-line converter (S5) |

The conversion, as FFmpeg arguments: the first audio stream only, no
metadata, `pan` averaging the channels, `aresample` to 22,050 Hz
(filter size 128, phase shift 14, cutoff 0.97, linear interpolation)
with triangular dither to unsigned 8-bit, `pcm_u8`, bitexact.

The app: still one window showing the format and the version.
