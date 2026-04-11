#!/bin/bash
set -euo pipefail

# Snap packages — re-runs when this list changes

SNAPS=(
    "foliate"
    "notion-desktop"
    "slack --classic"
    "spotify"
)

for entry in "${SNAPS[@]}"; do
    read -r name flags <<< "$entry"
    if ! snap list "$name" &>/dev/null; then
        printf "Installing snap: %s\n" "$name"
        sudo snap install $flags "$name"
    fi
done

printf "All snap packages installed.\n"
