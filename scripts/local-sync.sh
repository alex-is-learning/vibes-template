#!/bin/bash
# Nightly sync: rebuilds images/ from a local inbox folder, converts, commits, pushes.
# Installed by install-local-sync.sh (launchd calls this). Safe to run by hand anytime.
set -euo pipefail
cd "$(dirname "$0")/.."

INBOX="${VIBES_INBOX:-$HOME/vibes-inbox}"
BRANCH="$(git symbolic-ref --short HEAD)"

echo "--- $(date '+%Y-%m-%d %H:%M') ---"
mkdir -p "$INBOX"

git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

# images/ becomes exactly what's in the inbox right now — additions and
# removals both fall out of this for free. vibes.py re-encodes everything,
# but the encode is deterministic, so unchanged inputs produce byte-identical
# output and nothing gets committed.
rm -f images/*.webp
find "$INBOX" -maxdepth 1 -type f ! -name '.*' -exec cp {} images/ \;

./.venv/bin/python3 scripts/vibes.py

if [[ -n "$(git status --porcelain -- images image_widths_heights.json)" ]]; then
  git add -A -- images image_widths_heights.json
  git commit -m "vibes sync $(date '+%Y-%m-%d %H:%M')" --quiet
  git push origin "$BRANCH"
  echo "pushed"
else
  echo "no changes"
fi

if [[ -s .vibes-rejected ]]; then
  echo "rejected (not published — unreadable or not an image): $(paste -sd, .vibes-rejected)"
fi
