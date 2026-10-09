#!/bin/sh
# Updates the pinned yt-dlp (decision Y1), never silently: fetches the
# latest release's macOS build into ~/MacPlusProjects/converter-tools/
# yt-dlp-<version>/, checks it against the release's SHA2-256SUMS, shows
# its version, and only then, if you agree, moves the "yt-dlp" link to it.
# The old version stays, so going back is moving the link back.
#
# Usage: tools/update-yt-dlp.sh

set -eu
T=${MMC_TRANSFER_TOOLS:-$HOME/MacPlusProjects/converter-tools}
CURRENT=$(readlink "$T/yt-dlp" 2>/dev/null || echo "(none)")
TAG=$(curl -fsS -m 30 https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest \
      | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')
echo "In use: $CURRENT"
echo "Latest: yt-dlp-$TAG"
if [ "$CURRENT" = "yt-dlp-$TAG" ]; then
    echo "Already up to date."
    exit 0
fi

DIR=$T/yt-dlp-$TAG
mkdir -p "$DIR"
URL=https://github.com/yt-dlp/yt-dlp/releases/download/$TAG
curl -fsSL -m 600 -o "$DIR/yt-dlp_macos" "$URL/yt-dlp_macos"
curl -fsSL -m 60 -o "$DIR/SHA2-256SUMS" "$URL/SHA2-256SUMS"
WANT=$(grep ' yt-dlp_macos$' "$DIR/SHA2-256SUMS" | awk '{print $1}')
GOT=$(shasum -a 256 "$DIR/yt-dlp_macos" | awk '{print $1}')
if [ -z "$WANT" ] || [ "$WANT" != "$GOT" ]; then
    echo "The download doesn't match the release's checksum: not used." >&2
    rm -rf "$DIR"
    exit 1
fi
chmod +x "$DIR/yt-dlp_macos"
echo "Checksum OK: $GOT"
echo "It reports version: $("$DIR/yt-dlp_macos" --version)"
printf "Use it? [y/N] "
read -r answer
case $answer in
    y|Y|yes)
        ln -sfn "yt-dlp-$TAG" "$T/yt-dlp"
        printf '\nyt-dlp-%s/  yt-dlp %s, from %s/yt-dlp_macos\n  SHA-256 %s (checked against SHA2-256SUMS), %s\n' \
            "$TAG" "$TAG" "$URL" "$GOT" "$(date '+%Y-%m-%d')" >> "$T/MANIFEST.txt"
        echo "Now using yt-dlp-$TAG (recorded in MANIFEST.txt). Update BUILDING.md's table too."
        ;;
    *)
        echo "Left as it was. The download is in $DIR if you change your mind."
        ;;
esac
