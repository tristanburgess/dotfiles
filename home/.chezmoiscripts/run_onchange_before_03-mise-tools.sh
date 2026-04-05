#!/bin/bash
set -euo pipefail

# Ensure mise is on PATH (may not be in bashrc yet on first run)
eval "$("$HOME/.local/bin/mise" activate bash)"

mise alias set kitty github:kovidgoyal/kitty
mise use --global \
    go@latest \
    node@lts \
    rust@latest \
    jq@latest \
    jujutsu@latest \
    zoxide@latest \
    difftastic@latest \
    gh@latest \
    neovim@latest \
    starship@latest \
    claude-code@latest \
    kitty@latest \
    chezmoi@latest \
    --yes
