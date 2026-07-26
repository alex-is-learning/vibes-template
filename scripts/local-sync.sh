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

# The Action rewrites history whenever an image is uploaded through github.com,
# so there's no merge to do here — lining up with the remote means a hard reset.
# That would also wipe any edit to index.html, which is where your own words at
# the top of the page live: you'd write a paragraph, see it all evening, and find
# it gone in the morning with nothing to say why. So anything changed outside the
# two paths this script owns is carried across the reset and put back after it.
#
# What counts as "yours" is measured against your own last commit, never against
# the remote — otherwise editing the text on github.com would look like a local
# change here, and this would faithfully carry the stale copy across and push it
# back over what you just wrote. Two sources: edits you haven't committed, and
# edits you committed but haven't pushed.
CARRY="$(mktemp -d)"
trap 'rm -rf "$CARRY"' EXIT
BASE="$(git merge-base "origin/$BRANCH" HEAD)"
{
  git diff --name-only HEAD -- . \
    ':(exclude)images' ':(exclude)image_widths_heights.json'
  git diff --name-only "$BASE" HEAD -- . \
    ':(exclude)images' ':(exclude)image_widths_heights.json'
} | sort -u \
  | while IFS= read -r f; do
      [ -f "$f" ] || continue
      mkdir -p "$CARRY/$(dirname "$f")"
      cp "$f" "$CARRY/$f"
    done

git reset --hard "origin/$BRANCH"

find "$CARRY" -type f | while IFS= read -r kept; do
  f="${kept#$CARRY/}"
  cp "$kept" "$f"
  echo "kept your changes to $f"
done

# images/ becomes exactly what's in the inbox right now — additions and
# removals both fall out of this for free. vibes.py re-encodes everything,
# but the encode is deterministic, so unchanged inputs produce byte-identical
# output and nothing gets committed.
#
# Walked recursively, because dragging a whole album out of Photos is the most
# obvious thing to do with a folder like this, and a non-recursive walk would
# have ignored every photo in it in silence. The page is flat, so a subfolder's
# name is folded into the filename rather than lost — that also keeps two files
# called IMG_0001.jpg in different folders from overwriting each other.
rm -f images/*.webp
find "$INBOX" -type f ! -name '.*' ! -name "$NOTICE_NAME" | while IFS= read -r f; do
  rel="${f#"$INBOX"/}"
  cp "$f" "images/$(printf '%s' "$rel" | tr '/' '-')"
done

./.venv/bin/python3 scripts/vibes.py

# index.html is in here too, not just the images: it's the file you edit to change
# the words at the top, and carrying an edit across the reset above without ever
# committing it would leave it living on your Mac and never reaching the page.
if [[ -n "$(git status --porcelain -- images image_widths_heights.json index.html)" ]]; then
  git add -A -- images image_widths_heights.json index.html
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
    echo   # .vibes-rejected has no trailing newline, so this closes the last line
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
