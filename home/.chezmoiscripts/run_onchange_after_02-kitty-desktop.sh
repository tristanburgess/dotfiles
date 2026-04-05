#!/bin/bash
set -euo pipefail

# Patch kitty .desktop files so GNOME can find the mise-managed kitty
eval "$("$HOME/.local/bin/mise" activate bash)"

KITTY_INSTALL="$(mise where kitty)"
KITTY_SHIM="$HOME/.local/share/mise/shims/kitty"

mkdir -p "$HOME/.local/share/applications"
for desktop in kitty.desktop kitty-open.desktop; do
    src="$KITTY_INSTALL/share/applications/$desktop"
    [ -f "$src" ] || continue
    dest="$HOME/.local/share/applications/$desktop"
    cp "$src" "$dest"
    sed -i "s|^Icon=kitty|Icon=$KITTY_INSTALL/share/icons/hicolor/256x256/apps/kitty.png|" "$dest"
    sed -i "s|^Exec=kitty|Exec=$KITTY_SHIM|" "$dest"
    sed -i "s|^TryExec=kitty|TryExec=$KITTY_SHIM|" "$dest"
done
