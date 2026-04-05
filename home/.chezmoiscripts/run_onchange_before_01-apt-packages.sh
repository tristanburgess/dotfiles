#!/bin/bash
set -euo pipefail

# System packages needed by other tools
sudo apt update -qq
sudo apt install -y \
    curl wget git build-essential pkg-config libssl-dev \
    wmctrl xprintidle keychain libnotify-bin \
    python3 python3-pip python3-venv fontconfig unzip
