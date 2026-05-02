#!/bin/bash
# Called by apt hook to update mise-managed tools after apt upgrades.
# Sends desktop notifications on success/failure.
# Re-patches kitty .desktop files after upgrade (icon path contains version).

set -euo pipefail

# Detect the real user — works under sudo (SUDO_USER), pkexec/Update Manager
# (PKEXEC_UID), or direct invocation (logname/whoami fallback).
if [ -n "${SUDO_USER:-}" ]; then
    NOTIFY_USER="$SUDO_USER"
elif [ -n "${PKEXEC_UID:-}" ]; then
    NOTIFY_USER=$(getent passwd "$PKEXEC_UID" | cut -d: -f1)
else
    NOTIFY_USER=$(logname 2>/dev/null || whoami)
fi
NOTIFY_UID=$(id -u "$NOTIFY_USER" 2>/dev/null || echo 1000)
DBUS="unix:path=/run/user/${NOTIFY_UID}/bus"
# Resolve home via getent rather than `eval echo "~$NOTIFY_USER"` to avoid
# shell-eval on a value that originated from environment / passwd lookup.
NOTIFY_HOME=$(getent passwd "$NOTIFY_USER" | cut -d: -f6)
[ -n "$NOTIFY_HOME" ] || NOTIFY_HOME="/home/$NOTIFY_USER"
MISE_BIN="$NOTIFY_HOME/.local/bin/mise"

notify() {
    local icon="$1" title="$2" body="$3"
    sudo -u "$NOTIFY_USER" \
        DISPLAY=:0 \
        DBUS_SESSION_BUS_ADDRESS="$DBUS" \
        notify-send -i "$icon" "$title" "$body"
}

failures=()
successes=()

# Update all mise-managed tools
if sudo -u "$NOTIFY_USER" "$MISE_BIN" upgrade --yes 2>/dev/null; then
    successes+=("mise tools")
else
    failures+=("mise tools")
fi

# Re-patch kitty .desktop files (icon path contains the version number)
KITTY_INSTALL=$(sudo -u "$NOTIFY_USER" "$MISE_BIN" where kitty 2>/dev/null)
KITTY_SHIM="$NOTIFY_HOME/.local/share/mise/shims/kitty"
if [ -n "$KITTY_INSTALL" ]; then
    for desktop in kitty.desktop kitty-open.desktop; do
        src="$KITTY_INSTALL/share/applications/$desktop"
        [ -f "$src" ] || continue
        dest="$NOTIFY_HOME/.local/share/applications/$desktop"
        cp "$src" "$dest"
        sed -i "s|^Icon=kitty|Icon=$KITTY_INSTALL/share/icons/hicolor/256x256/apps/kitty.png|" "$dest"
        sed -i "s|^Exec=kitty|Exec=$KITTY_SHIM|" "$dest"
        sed -i "s|^TryExec=kitty|TryExec=$KITTY_SHIM|" "$dest"
        chown "$NOTIFY_USER:$NOTIFY_USER" "$dest"
    done
fi

# Send notifications
if [ ${#successes[@]} -gt 0 ]; then
    notify "software-update-available" "Custom tools updated" "${successes[*]} updated successfully"
fi

if [ ${#failures[@]} -gt 0 ]; then
    notify "dialog-error" "Custom tool update failed" "Failed to update: ${failures[*]}"
fi
