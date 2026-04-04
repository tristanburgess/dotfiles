#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Helpers ──────────────────────────────────────────────────────

info()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m    ✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }
skip()  { printf '\033[0;90m    – %s (already installed)\033[0m\n' "$*"; }

command_exists() { command -v "$1" &>/dev/null; }

# ── 1. System packages ──────────────────────────────────────────

info "Installing system packages"
sudo apt update -qq
sudo apt install -y \
    curl wget git build-essential pkg-config libssl-dev \
    wmctrl xprintidle keychain libnotify-bin \
    python3 python3-pip python3-venv fontconfig unzip
ok "System packages"

# ── 1b. jq (from GitHub releases — apt's version lags behind) ───

info "Installing jq"
if command_exists jq; then
    skip "jq $(jq --version 2>/dev/null)"
else
    JQ_LATEST=$(curl -fsSL https://api.github.com/repos/jqlang/jq/releases/latest | grep -Po '"tag_name": *"\K[^"]+')
    JQ_URL="https://github.com/jqlang/jq/releases/download/${JQ_LATEST}/jq-linux-amd64"
    curl -fsSL "$JQ_URL" -o /tmp/jq
    chmod +x /tmp/jq
    sudo mv /tmp/jq /usr/local/bin/jq
    ok "jq $(/usr/local/bin/jq --version 2>/dev/null)"
fi

# ── 2. Rust ──────────────────────────────────────────────────────

info "Installing Rust"
if command_exists rustc; then
    skip "Rust $(rustc --version | awk '{print $2}')"
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    ok "Rust $(rustc --version | awk '{print $2}')"
fi

# Make sure cargo is on PATH for the rest of the script
export PATH="$HOME/.cargo/bin:$PATH"

# ── 3. Jujutsu ───────────────────────────────────────────────────

info "Installing Jujutsu (jj)"
if command_exists jj; then
    skip "jj $(jj --version 2>/dev/null | head -1)"
else
    warn "Building jj from source with cargo — this may take a few minutes"
    cargo install --locked jj-cli
    ok "jj $(jj --version 2>/dev/null | head -1)"
fi

# ── 4. Go ────────────────────────────────────────────────────────

info "Installing Go"
if command_exists go; then
    skip "Go $(go version | awk '{print $3}')"
else
    GO_VERSION=$(curl -sSL 'https://go.dev/VERSION?m=text' | head -1)
    GO_TAR="${GO_VERSION}.linux-amd64.tar.gz"
    curl -sSLO "https://go.dev/dl/${GO_TAR}"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "$GO_TAR"
    rm -f "$GO_TAR"

    # Add to PATH if not already present
    if ! grep -q '/usr/local/go/bin' "$HOME/.bashrc"; then
        echo 'export PATH="/usr/local/go/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    export PATH="/usr/local/go/bin:$PATH"
    ok "Go $(go version | awk '{print $3}')"
fi

# ── 5. Node.js (nvm) ────────────────────────────────────────────

info "Installing Node.js via nvm"
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    source "$NVM_DIR/nvm.sh"
    if command_exists node; then
        skip "Node $(node --version)"
    else
        nvm install --lts
        ok "Node $(node --version)"
    fi
else
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    source "$NVM_DIR/nvm.sh"
    nvm install --lts
    ok "Node $(node --version)"
fi

# ── 6. GitHub CLI ────────────────────────────────────────────────

info "Installing GitHub CLI (gh)"
if command_exists gh; then
    skip "gh $(gh --version | head -1 | awk '{print $3}')"
else
    (type -p wget >/dev/null || sudo apt install -y wget) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) \
        && wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
        && sudo apt update -qq \
        && sudo apt install -y gh \
        && rm -f "$out"
    ok "gh $(gh --version | head -1 | awk '{print $3}')"
fi

# ── 7. Kitty terminal ───────────────────────────────────────────

info "Installing Kitty"
if command_exists kitty; then
    skip "Kitty $(kitty --version | awk '{print $2}')"
else
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n

    # Desktop integration
    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/kitty"
    ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"

    mkdir -p "$HOME/.local/share/applications"
    cp "$HOME/.local/kitty.app/share/applications/kitty.desktop" \
        "$HOME/.local/share/applications/"
    sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" \
        "$HOME/.local/share/applications/kitty.desktop"
    sed -i "s|Exec=kitty|Exec=$HOME/.local/bin/kitty|g" \
        "$HOME/.local/share/applications/kitty.desktop"

    ok "Kitty $(kitty --version 2>/dev/null | awk '{print $2}')"
fi

# ── 8. Neovim ───────────────────────────────────────────────────
# Install from GitHub releases (apt's version is too old for many plugins)

info "Installing Neovim"
if command_exists nvim; then
    skip "Neovim $(nvim --version | head -1 | awk '{print $2}')"
else
    # Remove apt version if present (too old — typically 0.9.x)
    if dpkg -l neovim &>/dev/null; then
        sudo apt remove -y neovim neovim-runtime
    fi

    curl -sSLO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    rm -f nvim-linux-x86_64.tar.gz

    # Add to PATH if not already present
    if ! grep -q '/opt/nvim-linux-x86_64/bin' "$HOME/.bashrc"; then
        echo 'export PATH="/opt/nvim-linux-x86_64/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    ok "Neovim (source your .bashrc or open a new shell to use)"
fi

# ── 9. JetBrainsMono Nerd Font ──────────────────────────────────

info "Installing JetBrainsMono Nerd Font"
if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    skip "JetBrainsMono Nerd Font"
else
    FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
    mkdir -p "$FONT_DIR"
    FONT_URL=$(curl -sSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
        | jq -r '.assets[] | select(.name == "JetBrainsMono.zip") | .browser_download_url')
    curl -sSL "$FONT_URL" -o /tmp/JetBrainsMono.zip
    unzip -qo /tmp/JetBrainsMono.zip -d "$FONT_DIR"
    rm -f /tmp/JetBrainsMono.zip
    fc-cache -f
    ok "JetBrainsMono Nerd Font"
fi

# ── 10. Starship prompt ─────────────────────────────────────────

info "Installing Starship"
if command_exists starship; then
    skip "Starship $(starship --version | head -1 | awk '{print $2}')"
else
    curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
    ok "Starship $(starship --version | head -1 | awk '{print $2}')"
fi

# Add starship init to bashrc if not already present
if ! grep -q 'starship init bash' "$HOME/.bashrc"; then
    echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
    ok "Added starship init to .bashrc"
fi

# ── 11. Claude Code ─────────────────────────────────────────────

info "Installing Claude Code"
# Ensure npm is available (nvm may need re-sourcing)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"

if command_exists claude; then
    skip "Claude Code $(claude --version 2>/dev/null | head -1)"
else
    npm install -g @anthropic-ai/claude-code
    ok "Claude Code"
fi

# ── 12. Deploy config files ─────────────────────────────────────

info "Deploying config files"

# Kitty
mkdir -p "$HOME/.config/kitty"
cp "$DOTFILES_DIR/configs/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
cp "$DOTFILES_DIR/configs/kitty/current-theme.conf" "$HOME/.config/kitty/current-theme.conf"
ok "Kitty config"

# Starship
mkdir -p "$HOME/.config"
cp "$DOTFILES_DIR/configs/starship.toml" "$HOME/.config/starship.toml"
ok "Starship config"

# Jujutsu
mkdir -p "$HOME/.config/jj"
cp "$DOTFILES_DIR/configs/jj/config.toml" "$HOME/.config/jj/config.toml"
ok "Jujutsu config"

# Neovim
mkdir -p "$HOME/.config/nvim"
cp "$DOTFILES_DIR/configs/nvim/init.lua" "$HOME/.config/nvim/init.lua"
NVIM_BIN="${NVIM_BIN:-$(command -v nvim || echo /opt/nvim-linux-x86_64/bin/nvim)}"
"$NVIM_BIN" --headless "+Lazy! sync" +qa 2>/dev/null
ok "Neovim config + plugins"

# Claude Code
mkdir -p "$HOME/.claude/hooks"
cp "$DOTFILES_DIR/configs/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
cp "$DOTFILES_DIR/configs/claude/settings.json" "$HOME/.claude/settings.json"
cp "$DOTFILES_DIR/configs/claude/hooks/session-color.sh" "$HOME/.claude/hooks/session-color.sh"
cp "$DOTFILES_DIR/configs/claude/notify.sh" "$HOME/.claude/notify.sh"
chmod +x "$HOME/.claude/hooks/session-color.sh" "$HOME/.claude/notify.sh"
ok "Claude Code config + hooks"

# Download Claude logo for notifications (if missing)
if [ ! -f "$HOME/.claude/claude-logo.png" ]; then
    curl -sSL "https://avatars.githubusercontent.com/u/76263028" -o "$HOME/.claude/claude-logo.png"
    ok "Claude logo"
fi

# Auto-update hook: keeps kitty, starship, and neovim updated whenever apt runs
mkdir -p "$HOME/bin"
cp "$DOTFILES_DIR/configs/bin/update-custom-tools.sh" "$HOME/bin/update-custom-tools.sh"
chmod +x "$HOME/bin/update-custom-tools.sh"
sed "s|##HOME##|$HOME|g" "$DOTFILES_DIR/configs/apt/99-custom-updates" \
    | sudo tee /etc/apt/apt.conf.d/99-custom-updates > /dev/null
ok "Apt post-invoke hook (auto-updates jq, kitty, starship, neovim)"

# ── Done ─────────────────────────────────────────────────────────

info "Setup complete!"
echo ""
echo "  Remaining manual steps:"
echo "    1. Run: source ~/.bashrc   (to pick up new PATH entries)"
echo "    2. Run: gh auth login"
echo "    3. Run: claude   (to authenticate Claude Code)"
echo "    4. Open a new Kitty terminal to see the new prompt"
echo ""
