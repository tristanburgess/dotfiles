#!/bin/bash
set -euo pipefail

# Standalone .deb installs — no apt repos available
# No version pinning needed: these apps auto-update themselves once installed
# Re-runs when this script changes

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

# --- Discord ---
if ! dpkg -s discord &>/dev/null; then
    printf "Installing Discord...\n"
    curl -fsSL "https://discord.com/api/download?platform=linux&format=deb" -o "${TMPDIR}/discord.deb"
    sudo dpkg -i "${TMPDIR}/discord.deb" || sudo apt-get install -f -y
fi

# --- Zoom ---
if ! dpkg -s zoom &>/dev/null; then
    printf "Installing Zoom...\n"
    ARCH=$(dpkg --print-architecture)
    curl -fsSL "https://zoom.us/client/latest/zoom_${ARCH}.deb" -o "${TMPDIR}/zoom.deb"
    sudo dpkg -i "${TMPDIR}/zoom.deb" || sudo apt-get install -f -y
fi

printf "All standalone .deb installs complete.\n"
