#!/bin/bash
set -euo pipefail

if [ -f "$HOME/.claude/claude-logo.png" ]; then
    echo "Claude logo already present"
    exit 0
fi

curl -sSL "https://avatars.githubusercontent.com/u/76263028" -o "$HOME/.claude/claude-logo.png"
