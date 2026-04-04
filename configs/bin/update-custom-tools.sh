#!/bin/bash
# Called by apt hook to update jq, kitty, starship, and neovim after apt upgrades.
# Sends desktop notifications on success/failure.

# Detect the real user — works under sudo (SUDO_USER), pkexec/Update Manager
# (PKEXEC_UID), or direct invocation (logname/whoami fallback)
if [ -n "${SUDO_USER:-}" ]; then
    NOTIFY_USER="$SUDO_USER"
elif [ -n "${PKEXEC_UID:-}" ]; then
    NOTIFY_USER=$(getent passwd "$PKEXEC_UID" | cut -d: -f1)
else
    NOTIFY_USER=$(logname 2>/dev/null || whoami)
fi
NOTIFY_UID=$(id -u "$NOTIFY_USER" 2>/dev/null || echo 1000)
DBUS="unix:path=/run/user/${NOTIFY_UID}/bus"

notify() {
    local icon="$1" title="$2" body="$3"
    sudo -u "$NOTIFY_USER" \
        DISPLAY=:0 \
        DBUS_SESSION_BUS_ADDRESS="$DBUS" \
        notify-send -i "$icon" "$title" "$body"
}

failures=()
successes=()

# Update jq (from GitHub releases → /usr/local/bin/jq)
JQ_BIN="/usr/local/bin/jq"
JQ_CURRENT=$("$JQ_BIN" --version 2>/dev/null | sed 's/^jq-//')
JQ_LATEST=$(curl -fsSL https://api.github.com/repos/jqlang/jq/releases/latest | "$JQ_BIN" -r '.tag_name | ltrimstr("jq-")')
if [ -n "$JQ_CURRENT" ] && [ "$JQ_CURRENT" = "$JQ_LATEST" ]; then
    successes+=("jq (already $JQ_CURRENT)")
elif curl -fsSL "https://github.com/jqlang/jq/releases/download/jq-${JQ_LATEST}/jq-linux-amd64" -o /tmp/jq-update && chmod +x /tmp/jq-update && mv /tmp/jq-update "$JQ_BIN"; then
    successes+=("jq")
else
    rm -f /tmp/jq-update
    failures+=("jq")
fi

# Update kitty
NOTIFY_HOME=$(eval echo "~$NOTIFY_USER")
KITTY_BIN="$NOTIFY_HOME/.local/kitty.app/bin/kitty"
KITTY_CURRENT=$("$KITTY_BIN" --version 2>/dev/null | awk '{print $2}')
KITTY_LATEST=$(curl -fsSL https://api.github.com/repos/kovidgoyal/kitty/releases/latest | jq -r '.tag_name | ltrimstr("v")')
if [ -n "$KITTY_CURRENT" ] && [ "$KITTY_CURRENT" = "$KITTY_LATEST" ]; then
    successes+=("kitty (already $KITTY_CURRENT)")
elif sudo -u "$NOTIFY_USER" curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sudo -u "$NOTIFY_USER" sh /dev/stdin launch=n >/dev/null 2>&1; then
    successes+=("kitty")
else
    failures+=("kitty")
fi

# Update starship
STARSHIP_BIN="$NOTIFY_HOME/.local/bin/starship"
STARSHIP_CURRENT=$("$STARSHIP_BIN" --version 2>/dev/null | head -1 | awk '{print $2}')
STARSHIP_LATEST=$(curl -fsSL https://api.github.com/repos/starship/starship/releases/latest | jq -r '.tag_name | ltrimstr("v")')
if [ -n "$STARSHIP_CURRENT" ] && [ "$STARSHIP_CURRENT" = "$STARSHIP_LATEST" ]; then
    successes+=("starship (already $STARSHIP_CURRENT)")
elif sudo -u "$NOTIFY_USER" sh -c "curl -fsSL https://starship.rs/install.sh | sh -s -- -y --bin-dir '$NOTIFY_HOME/.local/bin'" >/dev/null 2>&1; then
    successes+=("starship")
else
    failures+=("starship")
fi

# Update neovim (from GitHub releases → /opt/nvim-linux-x86_64)
NVIM_DIR="/opt/nvim-linux-x86_64"
NVIM_BAK="/opt/nvim-linux-x86_64.bak"
NVIM_TAR="/tmp/nvim-linux-x86_64.tar.gz"
NVIM_CURRENT=$("$NVIM_DIR/bin/nvim" --version 2>/dev/null | head -1 | awk '{print $2}')
NVIM_LATEST=$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | jq -r .tag_name)
if [ -n "$NVIM_CURRENT" ] && [ "$NVIM_CURRENT" = "$NVIM_LATEST" ]; then
    successes+=("neovim (already $NVIM_CURRENT)")
elif rm -f "$NVIM_TAR" && curl -fsSL -o "$NVIM_TAR" https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz; then
    rm -rf "$NVIM_BAK"
    [ -d "$NVIM_DIR" ] && mv "$NVIM_DIR" "$NVIM_BAK"
    if tar -C /opt -xzf "$NVIM_TAR"; then
        rm -rf "$NVIM_BAK"
        successes+=("neovim")
    else
        # Restore previous version on extraction failure
        rm -rf "$NVIM_DIR"
        [ -d "$NVIM_BAK" ] && mv "$NVIM_BAK" "$NVIM_DIR"
        failures+=("neovim")
    fi
    rm -f "$NVIM_TAR"
else
    rm -f "$NVIM_TAR"
    failures+=("neovim")
fi

# Send notifications
if [ ${#successes[@]} -gt 0 ]; then
    notify "software-update-available" "Custom tools updated" "${successes[*]} updated successfully"
fi

if [ ${#failures[@]} -gt 0 ]; then
    notify "dialog-error" "Custom tool update failed" "Failed to update: ${failures[*]}"
fi
