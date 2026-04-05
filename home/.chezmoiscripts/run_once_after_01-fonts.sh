#!/bin/bash
set -euo pipefail

if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    echo "JetBrainsMono Nerd Font already installed"
    exit 0
fi

FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
mkdir -p "$FONT_DIR"
curl -sSL -o /tmp/JetBrainsMono.zip \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -qo /tmp/JetBrainsMono.zip -d "$FONT_DIR"
rm -f /tmp/JetBrainsMono.zip
fc-cache -f
