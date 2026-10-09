# Third-party software in the MacMusic Converter Utility

The MacMusic Converter Utility is © 2026 Jack McAteer. It runs these
programs, made by others, under their own licences. They are separate
programs, run as separate processes; none of their code is part of the
app's own.

## FFmpeg and ffprobe 9.0.2

Audio decoding, resampling, encoding and inspection.
Licence: **GNU General Public License, version 3** (this build is
configured with `--enable-gpl --enable-version3`).
Built by Martin Riedl (https://ffmpeg.martin-riedl.de), from FFmpeg
(https://ffmpeg.org). FFmpeg's source: https://ffmpeg.org/download.html;
this build's configuration and component versions:
`converter-tools/ffmpeg-9.0.2/zips/versions.txt`.
It includes, among others: LAME 4.0 (MP3 encoding; LGPL 2.0), x264 and
x265 (GPL 2.0+), OpenSSL 3.6 (Apache 2.0), Opus (BSD), libvorbis (BSD),
dav1d (BSD), libaom (BSD), freetype (FreeType licence), harfbuzz (MIT),
fontconfig (MIT), libxml2 (MIT), SDL (zlib).

The GPL lets anyone use and copy FFmpeg; anyone who passes a copy on
must also offer its source and these terms.

## yt-dlp 2026.08.19

Retrieving audio from YouTube. Licence: **The Unlicense** (public
domain). https://github.com/yt-dlp/yt-dlp

Its standalone build bundles Python 3.14 (PSF licence) and: yt-dlp-ejs
0.8.0 (Unlicense; bundling astring, MIT, and meriyah, ISC),
pycryptodomex (BSD and public domain), brotli (MIT), certifi (MPL 2.0),
curl_cffi (MIT, with curl-impersonate, MIT, and curl, curl licence),
mutagen (GPL 2.0+), requests (Apache 2.0), sqlite3 (public domain),
urllib3 (MIT) and websockets (BSD 3-clause). See its release notes for
the full list.

## Deno 2.9.7

The JavaScript runtime yt-dlp uses for YouTube. Licence: **MIT**.
© 2018-2026 the Deno authors. https://github.com/denoland/deno

---

MacMusic, and this utility, are independent projects, not affiliated
with Apple Inc. or Google LLC (YouTube). Apple, Macintosh and Mac are
trademarks of Apple Inc.; YouTube is a trademark of Google LLC.
