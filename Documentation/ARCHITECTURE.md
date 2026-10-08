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

## Now (Stage 0)

- `MacMusicFormat`: the MacMusic WAV contract's values (§18.2).
- `AppVersion`.
- The app: one window showing the format and the version.
