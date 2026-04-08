#!/bin/bash
set -euo pipefail

NEED_CACHE=false

# JetBrainsMono Nerd Font
if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
    mkdir -p "$FONT_DIR"
    curl -sSL -o /tmp/JetBrainsMono.zip \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -qo /tmp/JetBrainsMono.zip -d "$FONT_DIR"
    rm -f /tmp/JetBrainsMono.zip
    NEED_CACHE=true
fi

# VT323 (retro terminal font)
if ! fc-list | grep -qi "VT323"; then
    FONT_DIR="$HOME/.local/share/fonts/VT323"
    mkdir -p "$FONT_DIR"
    curl -sSL -o "$FONT_DIR/VT323-Regular.ttf" \
        "https://raw.githubusercontent.com/google/fonts/main/ofl/vt323/VT323-Regular.ttf"
    NEED_CACHE=true
fi

if [ "$NEED_CACHE" = true ]; then
    fc-cache -f
fi
