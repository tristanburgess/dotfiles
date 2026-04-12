#!/bin/bash
# Set a unique kitty tab color on Claude Code session start.
# Derives a consistent color from the project directory name.
# No-op outside Kitty (Git Bash, Windows Terminal, tmux without Kitty, etc.)

if [ -z "${KITTY_WINDOW_ID:-}" ]; then
    exit 0
fi

DIR=$(basename "$(pwd)")
HASH=$(echo "$DIR" | md5sum | head -c 6)
COLOR="#$HASH"

kitty @ set-tab-color "active_bg=$COLOR" 2>/dev/null || true

exit 0
