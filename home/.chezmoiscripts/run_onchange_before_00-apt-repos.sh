#!/bin/bash
set -euo pipefail

# Custom APT repositories with GPG keys
# Base: Ubuntu 24.04 (noble) via Linux Mint
# Re-runs when this script changes (add new repos here)

ensure_deps() {
    if ! command -v curl &>/dev/null || ! command -v gpg &>/dev/null; then
        sudo apt update -qq
        sudo apt install -y curl gnupg
    fi
    if ! command -v add-apt-repository &>/dev/null; then
        sudo apt install -y software-properties-common
    fi
}

add_repo() {
    local name="$1" keyring="$2" key_url="$3" repo_line="$4"
    local keyring_dir
    keyring_dir="$(dirname "$keyring")"

    if [[ -f "/etc/apt/sources.list.d/${name}.list" ]]; then
        return 0
    fi

    printf "Adding repo: %s\n" "$name"
    sudo mkdir -p "$keyring_dir"
    curl -fsSL "$key_url" | sudo gpg --dearmor -o "$keyring"
    printf '%s\n' "$repo_line" | sudo tee "/etc/apt/sources.list.d/${name}.list" > /dev/null
}

# For keys already in binary/dearmored format
add_repo_raw_key() {
    local name="$1" keyring="$2" key_url="$3" repo_line="$4"
    local keyring_dir
    keyring_dir="$(dirname "$keyring")"

    if [[ -f "/etc/apt/sources.list.d/${name}.list" ]]; then
        return 0
    fi

    printf "Adding repo: %s\n" "$name"
    sudo mkdir -p "$keyring_dir"
    curl -fsSL "$key_url" | sudo tee "$keyring" > /dev/null
    printf '%s\n' "$repo_line" | sudo tee "/etc/apt/sources.list.d/${name}.list" > /dev/null
}

ensure_deps

# --- Docker ---
add_repo_raw_key "docker" \
    "/etc/apt/keyrings/docker.asc" \
    "https://download.docker.com/linux/ubuntu/gpg" \
    "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu jammy stable"

# --- VS Code ---
if [[ ! -f /etc/apt/sources.list.d/vscode.list ]]; then
    printf "Adding repo: vscode\n"
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
    printf 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main\n' \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
fi

# --- Google Chrome ---
add_repo "google-chrome" \
    "/usr/share/keyrings/google-chrome.gpg" \
    "https://dl.google.com/linux/linux_signing_key.pub" \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main"

# --- OneDrive (abraunegg) ---
add_repo "onedrive" \
    "/usr/share/keyrings/obs-onedrive.gpg" \
    "https://download.opensuse.org/repositories/home:/npreining:/debian-ubuntu-onedrive/xUbuntu_24.04/Release.key" \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/obs-onedrive.gpg] https://download.opensuse.org/repositories/home:/npreining:/debian-ubuntu-onedrive/xUbuntu_24.04/ ./"

# --- OpenShot PPA ---
if [[ ! -f /etc/apt/sources.list.d/openshot_developers-ppa-noble.list ]] && \
   ! find /etc/apt/sources.list.d/ -name '*openshot*' -print -quit 2>/dev/null | grep -q .; then
    printf "Adding PPA: openshot.developers\n"
    sudo add-apt-repository -y ppa:openshot.developers/ppa
fi

sudo apt update -qq
printf "All custom APT repos configured.\n"
