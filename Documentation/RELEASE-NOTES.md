# MacMusic Converter Utility 1.1

A Mac app that turns music into WAV files the MacMusic player can import
on a Macintosh Plus, and into MP3s.

## What's new in 1.1

- **Every song equally loud:** each song is levelled by loudness to
  −16 LUFS, with a limiter keeping the loudest moments under −1 dBFS.
  There's nothing to set; 1.0's Normalise and its level are gone. Results
  say where a song was levelled from, by how much, and what the limiter
  took off; each file shows its loudness.
- **The Plus's own rate:** MacMusic WAVs are made at 22,254 Hz, the
  Macintosh Plus's own rate, not 22,050, so songs play at their true speed
  and pitch.
- **They need MacMusic 1.2,** which accepts the new rate; MacMusic 1.0 and
  1.1 refuse them. MacMusic 1.2 isn't released yet (its candidate plays
  them); nor is the Transfer Utility 2.0, which takes them (1.0 takes only
  22,050 Hz). Until then, keep 1.0 for songs for MacMusic 1.1.

## Installing

Unzip `MacMusic-Converter-Utility-1.1.zip` and drag **MacMusic
Converter Utility** to Applications, replacing 1.0; your settings are
kept. Everything it needs is inside it (FFmpeg, yt-dlp, Deno). It needs
an Apple silicon Mac with macOS 26.

It's signed ad hoc, for its owner's own use; not notarised. If macOS
won't open it the first time, Control-click it and choose Open.

## What it does

- **Local files:** choose or drop a sound file (MP3, AAC/M4A, WAV, FLAC,
  Opus and others FFmpeg reads).
- **YouTube:** paste the address of a video you own or have permission
  to save; Look Up shows its title, channel and length. One video only:
  a playlist in the address is ignored. No sign-in, no cookies; private,
  age-restricted, members-only and region-blocked videos are refused.
- **Outputs:** a **MacMusic WAV** (mono, 22,254 Hz, 8-bit: exactly what
  MacMusic 1.2 imports, checked against its own rules), an **MP3**
  (192 kbps, stereo when the source is), or both, from one job: the audio
  is read (or downloaded) once.
- **Title:** typed (or taken from the file or the video) and stored in
  the WAV, so MacMusic fills it in when you import; other details are
  entered in MacMusic.
- **Loudness:** every song to −16 LUFS, the limiter at −1 dBFS; a very
  quiet song is raised by 20 dB at most.
- **Trim silence:** cuts silence of more than 2 or 3 seconds at the start
  or end down to half a second; never in the middle.
- **Safe with your files:** never writes to the source; asks before
  replacing anything; nothing half-made is left behind, even when you
  cancel or quit mid-job; every output is checked before it's kept.

Files are saved to `~/Music/MacMusic Converter` unless you choose
another folder. Then copy the WAV to the Mac and import it with
MacMusic's File > Import Song.

## Bundled software

FFmpeg 9.0.2 (GPL v3), yt-dlp 2026.08.19 (Unlicense), Deno 2.9.7 (MIT):
see Advanced > Licences… in the app. For the owner's own use: a shared
copy would need FFmpeg's source and licence, or the LGPL build of 1.0.1.

## Known limits

- MacMusic's names are at most 31 characters, so long titles give
  shortened WAV names; type a File name for a better one.
- YouTube changes from time to time; when the app says yt-dlp may need
  updating, the developer runs `tools/update-yt-dlp.sh` and rebuilds.
- A song with very loud moments may be limited by more than 6 dB to
  reach the loudness, and may sound squashed; Results says so.
