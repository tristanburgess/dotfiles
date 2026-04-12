#!/bin/bash
# Claude Code notification with response preview, click-to-focus, and logo
# Triggered by Stop and Notification hooks.
# Linux bare-metal: only notifies if terminal is unfocused (or user idle).
# WSL2: always fires (WSLg's RAIL compositor hides root-window props).
# Windows (Git Bash): uses BurntToast PowerShell module if installed.

ICON="$HOME/.claude/claude-logo.png"

# ── Parse hook input (shared) ───────────────────────────────────
INPUT=$(cat)

HOOK_EVENT=$(jq -r '.hook_event_name // ""' <<< "$INPUT")
NOTIF_TYPE=$(jq -r '.notification_type // ""' <<< "$INPUT")
NOTIF_MSG=$(jq -r '.message // ""' <<< "$INPUT")
TRANSCRIPT=$(jq -r '.transcript_path // ""' <<< "$INPUT")
LAST_MSG=$(jq -r '.last_assistant_message // ""' <<< "$INPUT")

if [ "$HOOK_EVENT" = "Notification" ]; then
    if [ "$NOTIF_TYPE" = "permission_prompt" ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
        TOOL_DETAIL=$(tail -20 "$TRANSCRIPT" \
            | jq -r 'select(.message.role == "assistant") | .message.content[] | select(.type == "tool_use") | "\(.name): \(.input.description // .input.command // .input.file_path // "")"' 2>/dev/null \
            | tail -1)
        RAW="${NOTIF_MSG}${TOOL_DETAIL:+
${TOOL_DETAIL}}"
    else
        RAW="${NOTIF_MSG:-Notification from Claude Code}"
    fi
else
    RAW="${LAST_MSG:-Response ready}"
fi

# ── Helpers (shared) ────────────────────────────────────────────
pango_escape() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

gvariant_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//\'/\\\'}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    printf '"%s"' "$s"
}

MESSAGE=$(pango_escape "$(printf '%.300s' "$RAW")")

# ── Linux bare-metal: gdbus + X11 focus tracking + auto-dismiss ─
notify_linux() {
    # Hooks don't inherit the shell's env, so fall back to reading
    # WINDOWID from the ancestor Claude process's /proc/PID/environ.
    local WINDOW_ID=""
    if [ -n "${WINDOWID:-}" ] && [ "$WINDOWID" -gt 0 ] 2>/dev/null; then
        WINDOW_ID=$(printf "0x%08x" "$WINDOWID")
    else
        local _pid=$$
        while [ "$_pid" -gt 1 ]; do
            if [ "$(ps -o comm= -p "$_pid" 2>/dev/null)" = "claude" ]; then
                local _wid
                _wid=$(tr '\0' '\n' < "/proc/$_pid/environ" 2>/dev/null \
                    | sed -n 's/^WINDOWID=//p' | head -1)
                [ -n "$_wid" ] && [ "$_wid" -gt 0 ] 2>/dev/null \
                    && WINDOW_ID=$(printf "0x%08x" "$_wid")
                break
            fi
            _pid=$(ps -o ppid= -p "$_pid" 2>/dev/null | tr -d ' ')
        done
    fi

    # Skip if terminal is focused and user is active
    if [ -n "$WINDOW_ID" ]; then
        local ACTIVE
        ACTIVE=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $NF}')
        if [ "$(printf '%x' "$ACTIVE" 2>/dev/null)" = "$(printf '%x' "$WINDOW_ID" 2>/dev/null)" ]; then
            local IDLE_MS
            IDLE_MS=$(xprintidle 2>/dev/null || echo 0)
            [ "$IDLE_MS" -lt 15000 ] && return 0
        fi
    fi

    # Extract session name from window title
    local SESSION=""
    if [ -n "$WINDOW_ID" ]; then
        local TITLE
        TITLE=$(wmctrl -l | grep -i "$WINDOW_ID" | sed 's/^[^ ]* *[^ ]* *[^ ]* //')
        SESSION=$(pango_escape "$(printf '%s' "$TITLE" | sed 's/^[^a-zA-Z0-9]*//')")
    fi

    local BODY
    if [ -n "$SESSION" ]; then
        BODY="<b>${SESSION}</b>
${MESSAGE}"
    else
        BODY="$MESSAGE"
    fi

    local NOTIF_ID
    NOTIF_ID=$(gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        -- '"Claude Code"' 0 "$(gvariant_escape "$ICON")" '"Claude Code"' \
        "$(gvariant_escape "$BODY")" \
        '["default", "Open Terminal"]' '{"urgency": <byte 2>}' \
        -1 2>/dev/null | grep -oP 'uint32 \K\d+')

    if [ -n "$NOTIF_ID" ]; then
        (
            set -m

            gdbus monitor --session \
                --dest org.freedesktop.Notifications \
                --object-path /org/freedesktop/Notifications 2>/dev/null |
            while IFS= read -r line; do
                case "$line" in
                    *"ActionInvoked (uint32 $NOTIF_ID,"*)
                        [ -n "$WINDOW_ID" ] && wmctrl -i -a "$WINDOW_ID" 2>/dev/null
                        break ;;
                    *"NotificationClosed (uint32 $NOTIF_ID,"*)
                        break ;;
                esac
            done &
            MONITOR_PID=$!

            if [ -n "$WINDOW_ID" ]; then
                WIN_NORM=$(printf "%x" "$WINDOW_ID" 2>/dev/null)
                for _ in {1..150}; do
                    sleep 2
                    kill -0 "$MONITOR_PID" 2>/dev/null || break
                    CURR=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $NF}')
                    CURR_NORM=$(printf "%x" "$CURR" 2>/dev/null)
                    IDLE_MS=$(xprintidle 2>/dev/null || echo 999999)
                    if [ "$CURR_NORM" = "$WIN_NORM" ] && [ "$IDLE_MS" -lt 5000 ]; then
                        gdbus call --session \
                            --dest org.freedesktop.Notifications \
                            --object-path /org/freedesktop/Notifications \
                            --method org.freedesktop.Notifications.CloseNotification \
                            "$NOTIF_ID" >/dev/null 2>&1
                        break
                    fi
                done
            fi

            kill -- -"$MONITOR_PID" 2>/dev/null
            wait "$MONITOR_PID" 2>/dev/null
        ) &
        disown
    else
        # Fallback: notify-send without auto-dismiss (if gdbus unavailable)
        (
            ACTION=$(notify-send \
                --urgency=critical \
                --app-name="Claude Code" \
                --icon="$ICON" \
                --action="default=Open Terminal" \
                'Claude Code' \
                "$BODY" 2>/dev/null)

            if [ "$ACTION" = "default" ] && [ -n "$WINDOW_ID" ]; then
                wmctrl -i -a "$WINDOW_ID" 2>/dev/null
            fi
        ) &
        disown
    fi
}

# ── WSL2: notify-send relays to Windows toast via WSLg ──────────
notify_wsl() {
    # WSLg's RAIL compositor doesn't expose _NET_ACTIVE_WINDOW or
    # _NET_CLIENT_LIST on the root window — `xprop -root` is empty and
    # `wmctrl -l` errors. So: no focus tracking, no window resolution,
    # no auto-dismiss loop. Always fire.
    (
        notify-send \
            --urgency=critical \
            --app-name="Claude Code" \
            --icon="$ICON" \
            'Claude Code' \
            "$MESSAGE" 2>/dev/null || true
    ) &
    disown
}

# ── Windows (Git Bash): BurntToast or silent fallback ───────────
notify_windows() {
    if ! command -v powershell.exe >/dev/null 2>&1; then
        return 0
    fi
    # Strip pango markup for the toast (BurntToast renders plain text)
    local BODY="$RAW"
    BODY="${BODY//\"/\`\"}"
    powershell.exe -NoProfile -Command "
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast
            New-BurntToastNotification -Text 'Claude Code', \"$BODY\"
        }
    " >/dev/null 2>&1 &
    disown
}

# ── Dispatch ────────────────────────────────────────────────────
case "$(uname -s)" in
    Linux*)
        if grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null; then
            notify_wsl
        else
            notify_linux
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        notify_windows
        ;;
esac
