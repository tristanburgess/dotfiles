#!/bin/bash
set -euo pipefail

# --- Registers: extract from tarball if present ---
TARBALL="/tmp/prose-craft-registers.tar.zst"
TARGET="$HOME/.claude/prose-craft-registers"

if [[ -f "$TARBALL" ]]; then
    printf "Extracting prose-craft registers from %s...\n" "$TARBALL"
    mkdir -p "$TARGET"
    tar --zstd -xf "$TARBALL" -C "$TARGET"
    printf "Prose-craft registers extracted to %s\n" "$TARGET"
fi

# --- SKILL.md: sync dotfiles source to marketplace + cache ---
SKILL_SRC="$HOME/.claude/prose-craft/SKILL.md"

if [[ ! -f "$SKILL_SRC" ]]; then
    exit 0
fi

# Marketplace clone
MARKETPLACE_DEST="$HOME/.claude/plugins/marketplaces/prose-craft/skills/prose-craft/SKILL.md"
if [[ -d "$(dirname "$MARKETPLACE_DEST")" ]]; then
    cp "$SKILL_SRC" "$MARKETPLACE_DEST"
    printf "Synced SKILL.md to marketplace\n"
fi

# Cache (version-agnostic glob)
for cache_skill in "$HOME"/.claude/plugins/cache/prose-craft/prose-craft/*/skills/prose-craft/SKILL.md; do
    if [[ -f "$cache_skill" ]]; then
        cp "$SKILL_SRC" "$cache_skill"
        printf "Synced SKILL.md to cache: %s\n" "$cache_skill"
    fi
done
