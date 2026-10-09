# Security and privacy

How the MacMusic Converter Utility treats your files, your network and
your information (SPECIFICATION.md §12; Stage 6). Each statement was
checked against the code (2026-10-09); keep it true as the code changes.

## What it never does

- **No telemetry, no accounts, no analytics.** The app has no network
  code of its own (no URLSession or similar anywhere in it).
- **No logging to disk.** Nothing is written to a log file; messages are
  shown in the window only, and forgotten when it closes.
- **No sign-in and no cookies.** yt-dlp is always run with
  `--ignore-config` (no config file can add options), `--no-cookies` and
  `--no-cookies-from-browser`, and `--no-cache-dir`. No password,
  username or token is ever asked for, stored or passed.
- **No getting round restrictions** (§8.3). yt-dlp's embedded-player
  client, which can get round age restrictions, is switched off;
  private, members-only, age-restricted and region-blocked videos stop
  with an explanation.
- **No uploading.** Your files never leave the Mac; conversion is done
  here, by FFmpeg.
- **No shell.** Every tool is started with its arguments as a list, never
  through a shell, so no file name, title or address can be read as a
  command; addresses are passed to yt-dlp after `--`, so they can't be
  read as options; file paths are absolute, so FFmpeg can't take them
  for one of its special inputs (`concat:`, `pipe:` ...). Tested.
- **No overwriting your files.** The source is never written to, even
  when you choose Replace; existing files are replaced only when you
  say so (§9.3). Tested.

## What it does

- **Network:** only when you use YouTube mode, and only yt-dlp, to
  YouTube, for the one video you looked up: its details, then its audio.
  yt-dlp also runs Deno, locally, for YouTube's JavaScript; Deno itself
  is given no network access of its own by the app.
- **Files it reads:** the file you choose (or drop), only.
- **Files it writes:** the outputs, in the folder you chose; while
  working, temporary files beside them (`.mmc-….partial`, hidden) and in
  the system's temporary folder (`mmc-youtube-…`, `mmc-process-…`), all
  deleted when the job ends, is cancelled or fails. Anything a crash
  leaves is deleted at the next launch, once it's over an hour old (H1).
- **What it remembers:** your choices (outputs, normalise, its target,
  trim, the folder), in the app's preferences. Not the files, titles or
  addresses you used.
- **Quitting:** closing the window or quitting asks first during a job,
  then stops every tool the app started, and the tools those started
  (H2). Tested.

## The tools it runs

FFmpeg, ffprobe, yt-dlp and Deno: pinned versions, checked against
their publishers' checksums (BUILDING.md); never downloaded or replaced
by the app. yt-dlp is updated only with `tools/update-yt-dlp.sh`, which
checks the new one and asks. Their licences: THIRD-PARTY-NOTICES.md.

## Not sandboxed, not notarised (decision T8)

For the owner's own use: the app is signed ad hoc, and isn't in the
App Sandbox (running the bundled tools inside it would need more work).
If it is ever shared, revisit: the sandbox, a Developer ID signature,
notarisation, and the licence obligations below.
