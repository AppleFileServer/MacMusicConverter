# MacMusic Converter Utility 1.0

A Mac app that turns music into WAV files the MacMusic player can import
on a Macintosh Plus, and into MP3s.

## Installing

Unzip `MacMusic-Converter-Utility-1.0.zip` and drag **MacMusic
Converter Utility** to Applications. Everything it needs is inside it
(FFmpeg, yt-dlp, Deno). It needs an Apple silicon Mac with macOS 26.

It's signed ad hoc, for its owner's own use; not notarised. If macOS
won't open it the first time, Control-click it and choose Open.

## What it does

- **Local files:** choose or drop a sound file (MP3, AAC/M4A, WAV, FLAC,
  Opus and others FFmpeg reads).
- **YouTube:** paste the address of a video you own or have permission
  to save; Look Up shows its title, channel and length. One video only:
  a playlist in the address is ignored. No sign-in, no cookies; private,
  age-restricted, members-only and region-blocked videos are refused.
- **Outputs:** a **MacMusic WAV** (mono, 22,050 Hz, 8-bit: exactly what
  MacMusic imports, checked against its own rules), an **MP3** (192 kbps,
  stereo when the source is), or both, from one job: the audio is read
  (or downloaded) once.
- **Title:** typed (or taken from the file or the video) and stored in
  the WAV, so MacMusic fills it in when you import; other details are
  entered in MacMusic.
- **Normalise:** raises or lowers the loudest peak to −1 dBFS (adjustable
  in Advanced).
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
see Advanced > Licences… in the app.

## Known limits

- MacMusic's names are at most 31 characters, so long titles give
  shortened WAV names; type a File name for a better one.
- YouTube changes from time to time; when the app says yt-dlp may need
  updating, the developer runs `tools/update-yt-dlp.sh` and rebuilds.
- Peak normalisation isn't loudness levelling: songs may still sound
  different in loudness.
