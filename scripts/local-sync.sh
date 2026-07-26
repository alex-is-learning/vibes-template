#!/bin/bash
# Nightly sync: rebuilds images/ from a local inbox folder, converts, commits, pushes.
# Installed by install-local-sync.sh (launchd calls this). Safe to run by hand anytime.
set -euo pipefail
cd "$(dirname "$0")/.."

INBOX="${VIBES_INBOX:-$HOME/vibes-inbox}"
BRANCH="$(git symbolic-ref --short HEAD)"

# This script's own note-to-self, written at the bottom. It lives in the inbox so
# it's seen, which means it must be excluded from the copy below — otherwise it
# gets published, rejected for not being an image, and named in its own next
# edition, forever.
NOTICE_NAME="⚠️ THESE DIDN'T GO UP.txt"
NOTICE="$INBOX/$NOTICE_NAME"

echo "--- $(date '+%Y-%m-%d %H:%M') ---"
mkdir -p "$INBOX"

git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

# images/ becomes exactly what's in the inbox right now — additions and
# removals both fall out of this for free. vibes.py re-encodes everything,
# but the encode is deterministic, so unchanged inputs produce byte-identical
# output and nothing gets committed.
rm -f images/*.webp
find "$INBOX" -maxdepth 1 -type f ! -name '.*' ! -name "$NOTICE_NAME" -exec cp {} images/ \;

./.venv/bin/python3 scripts/vibes.py

if [[ -n "$(git status --porcelain -- images image_widths_heights.json)" ]]; then
  git add -A -- images image_widths_heights.json
  git commit -m "vibes sync $(date '+%Y-%m-%d %H:%M')" --quiet
  git push origin "$BRANCH"
  echo "pushed"
else
  echo "no changes"
fi

# A rejected file is silent otherwise: it just never shows up on the page, night
# after night, and the log that says why is a file nobody opens. So the notice
# goes into the inbox itself — the one folder you actually look at. It's rewritten
# every run and deleted when there's nothing left to say.
if [[ -s .vibes-rejected ]]; then
  echo "rejected (not published — unreadable or not an image): $(paste -sd, .vibes-rejected)"
  {
    echo "These files are in this folder but are not on your page:"
    echo
    sed 's/^/  · /' .vibes-rejected
    echo
    echo "Either they aren't images (a video off a camera roll, a PDF), or the file"
    echo "is damaged and can't be opened. Re-save them as JPEGs and drop them back in,"
    echo "or drag them out of this folder — nothing else needs doing."
    echo
    echo "Last checked $(date '+%-d %B %Y, %H:%M'). This file rewrites itself, so"
    echo "there's no point editing it; it disappears once the folder is clean."
  } > "$NOTICE"
else
  rm -f "$NOTICE"
fi
