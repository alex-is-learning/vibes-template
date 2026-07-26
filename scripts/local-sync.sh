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

find "$CARRY" -type f -print0 | while IFS= read -r -d '' kept; do
  f="${kept#"$CARRY"/}"
  # If it moved on github.com too, yours is the one that survives — but say so,
  # because otherwise a paragraph written in the browser this morning quietly
  # disappears tonight. Nothing is destroyed; the other version stays in history.
  if ! git diff --quiet HEAD -- "$f" 2>/dev/null && ! cmp -s "$kept" "$f"; then
    echo "NOTE: $f changed here AND on github.com. Keeping your local copy;"
    echo "      the other version is still in this repo's history."
  fi
  cp "$kept" "$f"
  echo "kept your changes to $f"
done

# The inbox IS the page, so an empty one reads as "take everything down" — and it
# is far likelier that the folder got moved, renamed, or cleared to save space.
# `mkdir -p` above would have silently recreated it, so this is the only thing
# standing between a stray drag and the whole page coming down.
COUNT="$(find "$INBOX" -type f ! -path '*/.*' ! -name "$NOTICE_NAME" | wc -l | tr -d ' ')"
LIVE="$(find images -maxdepth 1 -type f -name '*.webp' | wc -l | tr -d ' ')"
if [ "$COUNT" -eq 0 ] && [ "$LIVE" -gt 0 ]; then
  echo "$INBOX is empty — refusing to take all $LIVE images off your page."
  echo "Put them back, or delete images/ on github.com if you really mean it."
  exit 1
fi

# images/ becomes exactly what's in the inbox right now — additions and
# removals both fall out of this for free. vibes.py re-encodes everything,
# but the encode is deterministic, so unchanged inputs produce byte-identical
# output and nothing gets committed.
#
# Walked recursively, because dragging a whole album out of Photos is the most
# obvious thing to do with a folder like this, and a non-recursive walk would
# have ignored every photo in it in silence. The page is flat, so a subfolder's
# name is folded into the filename rather than lost.
#
# `! -path '*/.*'` skips anything under a hidden folder, and it is not tidiness:
# vibes.py ignores dot-names, so a photo arriving as `.picasaoriginals/x.jpg`
# would be copied in, never re-encoded, never stripped of its GPS, and committed
# to a public repo as the untouched original. Deleting the whole of images/ each
# run rather than just the .webp files is the other half of that — a stray file
# from an older version would otherwise sit there permanently.
find images -maxdepth 1 -type f -delete
# Sorted, so the collision counter below hands out the same prefix every night.
# Unsorted, `find` returns whatever order the filesystem feels like, and the two
# colliding photos could swap which one is "1-" between runs — a commit and a
# reshuffled page every night, for no reason anyone could see.
find "$INBOX" -type f ! -path '*/.*' ! -name "$NOTICE_NAME" -print0 \
  | sort -z \
  | while IFS= read -r -d '' f; do
      rel="${f#"$INBOX"/}"
      # Newlines in a filename would break every line-based tool downstream, and
      # a folder called "a-b" makes "a-b/c.jpg" collide with a top-level
      # "a-b-c.jpg". Both are rare; neither should cost you a photo.
      dest="images/$(printf '%s' "$rel" | tr '/\n' '--')"
      n=1
      while [ -e "$dest" ]; do
        dest="images/${n}-$(printf '%s' "$rel" | tr '/\n' '--')"
        n=$((n + 1))
      done
      cp "$f" "$dest"
    done

./.venv/bin/python3 scripts/vibes.py

# The count check above is the cheap one and catches the common case — the folder
# got moved or renamed. This is the one that can't be fooled: an inbox holding
# nothing but files that turn out to be unpublishable (one stray video) passes
# the count and would still strip the page bare. Judge on what actually survived
# encoding, and put everything back if the answer is nothing.
if [ "$(find images -maxdepth 1 -name '*.webp' | wc -l | tr -d ' ')" -eq 0 ] \
   && [ "$LIVE" -gt 0 ]; then
  git checkout -- images image_widths_heights.json
  echo "nothing in $INBOX could be published, so all $LIVE images would have come"
  echo "down. Left the page as it was. See the note in the folder for which files."
fi

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
