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

# ── 2. mise ─────────────────────────────────────────────────────

info "Installing mise"
if command_exists mise; then
    skip "mise $(mise --version 2>/dev/null | awk '{print $1}')"
else
    curl https://mise.run | sh
    ok "mise"
fi

# Activate mise for the rest of the script
eval "$($HOME/.local/bin/mise activate bash)"

# Add mise activation to bashrc if not already present
if ! grep -q 'mise activate bash' "$HOME/.bashrc"; then
    echo 'eval "$(mise activate bash)"' >> "$HOME/.bashrc"
    ok "Added mise activate to .bashrc"
fi

# ── 3. Developer tools (via mise) ───────────────────────────────

info "Installing developer tools via mise"
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
    --yes
ok "Developer tools"

# Shell integrations
if ! grep -q 'zoxide init bash' "$HOME/.bashrc"; then
    echo 'eval "$(zoxide init bash)"' >> "$HOME/.bashrc"
    ok "Added zoxide init to .bashrc"
fi

if ! grep -q 'starship init bash' "$HOME/.bashrc"; then
    echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
    ok "Added starship init to .bashrc"
fi

# Ensure Go binaries (go install) are on PATH
if ! grep -q 'GOPATH.*bin' "$HOME/.bashrc"; then
    echo 'export PATH="$(go env GOPATH)/bin:$PATH"' >> "$HOME/.bashrc"
    ok "Added GOPATH/bin to .bashrc"
fi

# ── 4. Kitty desktop integration ────────────────────────────────
# Kitty is installed by mise; patch .desktop files so GNOME can find it

info "Kitty desktop integration"
KITTY_INSTALL="$(mise where kitty)"
KITTY_SHIM="$HOME/.local/share/mise/shims/kitty"

mkdir -p "$HOME/.local/share/applications"
for desktop in kitty.desktop kitty-open.desktop; do
    src="$KITTY_INSTALL/share/applications/$desktop"
    [ -f "$src" ] || continue
    cp "$src" "$HOME/.local/share/applications/$desktop"
    dest="$HOME/.local/share/applications/$desktop"
    sed -i "s|^Icon=kitty|Icon=$KITTY_INSTALL/share/icons/hicolor/256x256/apps/kitty.png|" "$dest"
    sed -i "s|^Exec=kitty|Exec=$KITTY_SHIM|" "$dest"
    sed -i "s|^TryExec=kitty|TryExec=$KITTY_SHIM|" "$dest"
done
ok "Kitty desktop integration"

# ── 5. JetBrainsMono Nerd Font ──────────────────────────────────

info "Installing JetBrainsMono Nerd Font"
if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    skip "JetBrainsMono Nerd Font"
else
    FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
    mkdir -p "$FONT_DIR"
    curl -sSL -o /tmp/JetBrainsMono.zip \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -qo /tmp/JetBrainsMono.zip -d "$FONT_DIR"
    rm -f /tmp/JetBrainsMono.zip
    fc-cache -f
    ok "JetBrainsMono Nerd Font"
fi

# ── 6. Deploy config files ─────────────────────────────────────

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
nvim --headless "+Lazy! sync" +qa 2>/dev/null
ok "Neovim config + plugins"

# Claude Code
mkdir -p "$HOME/.claude/hooks"
cp "$DOTFILES_DIR/configs/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
cp "$DOTFILES_DIR/configs/claude/settings.json" "$HOME/.claude/settings.json"
cp "$DOTFILES_DIR/configs/claude/hooks/session-color.sh" "$HOME/.claude/hooks/session-color.sh"
cp "$DOTFILES_DIR/configs/claude/notify.sh" "$HOME/.claude/notify.sh"
cp "$DOTFILES_DIR/configs/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
chmod +x "$HOME/.claude/hooks/session-color.sh" "$HOME/.claude/notify.sh" "$HOME/.claude/statusline-command.sh"
ok "Claude Code config + hooks + statusline"

# Download Claude logo for notifications (if missing)
if [ ! -f "$HOME/.claude/claude-logo.png" ]; then
    curl -sSL "https://avatars.githubusercontent.com/u/76263028" -o "$HOME/.claude/claude-logo.png"
    ok "Claude logo"
fi

# Auto-update hook: keeps mise-managed tools updated whenever apt runs
mkdir -p "$HOME/bin"
cp "$DOTFILES_DIR/configs/bin/update-custom-tools.sh" "$HOME/bin/update-custom-tools.sh"
chmod +x "$HOME/bin/update-custom-tools.sh"
sed "s|##HOME##|$HOME|g" "$DOTFILES_DIR/configs/apt/99-custom-updates" \
    | sudo tee /etc/apt/apt.conf.d/99-custom-updates > /dev/null
ok "Apt post-invoke hook (auto-updates mise tools)"

# ── Done ─────────────────────────────────────────────────────────

info "Setup complete!"
echo ""
echo "  Remaining manual steps:"
echo "    1. Run: source ~/.bashrc   (to pick up new PATH entries)"
echo "    2. Run: gh auth login"
echo "    3. Run: claude   (to authenticate Claude Code)"
echo "    4. Open a new Kitty terminal to see the new prompt"
echo ""
