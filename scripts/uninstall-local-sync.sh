#!/bin/bash
# Undoes install-local-sync.sh: stops the nightly job, removes the Desktop
# alias. Leaves the inbox folder and its photos alone.
set -euo pipefail
LABEL="${VIBES_LABEL:-com.$(whoami | tr -cd 'a-zA-Z0-9').vibes-daily}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -f "$HOME/Desktop/vibes-inbox"

echo "Nightly sync stopped and Desktop alias removed. Your images and the ~/vibes-inbox folder are untouched."
