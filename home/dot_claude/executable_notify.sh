#!/bin/bash
# Claude Code notification with response preview, click-to-focus, and logo.
# Triggered by Stop and Notification hooks.
#
# Linux/macOS in kitty: focus-skip + click-to-focus + auto-dismiss via
#   kitty's remote control protocol (display-server agnostic).
#   Notification emission uses `notify-send -A` so the dbus connection
#   stays open while waiting for the action — Plasma 6.5 silently expires
#   action-bearing notifications when the sender disconnects, so a one-shot
#   `gdbus call Notify` never works for click-to-focus on Plasma.
# Linux outside kitty: dumb notify-send (always fires, no smart features).
# WSL2: notify-send relays to Windows toast via WSLg.
# Windows (Git Bash): BurntToast PowerShell module if installed.

set -u

ICON="$HOME/.claude/claude-logo.png"
# Allow filesystem socket (preferred) or abstract (legacy). Reject tcp:.
KITTY_LISTEN_RE='^unix:(/[^[:space:]]+|@kitty-[0-9]+)$'

# ── Parse hook input ────────────────────────────────────────────
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

MESSAGE=$(printf '%.300s' "$RAW")

# ── Kitty env resolution ────────────────────────────────────────
# KITTY_LISTEN_ON / KITTY_WINDOW_ID are exported in kitty subshells.
# Hooks usually inherit them, but fall back to /proc walk in case
# the harness strips env.
read_proc_env() {
    local pid="$1" key="$2"
    tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null \
        | sed -n "s/^${key}=//p" | head -1
}

resolve_from_claude_env() {
    local key="$1" pid=$$
    while [ "$pid" -gt 1 ]; do
        if [ "$(ps -o comm= -p "$pid" 2>/dev/null)" = "claude" ]; then
            read_proc_env "$pid" "$key"
            return 0
        fi
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        [ -z "$pid" ] && break
    done
    return 1
}

KITTY_LISTEN_ON_RESOLVED="${KITTY_LISTEN_ON:-$(resolve_from_claude_env KITTY_LISTEN_ON || true)}"
KITTY_WINDOW_ID_RESOLVED="${KITTY_WINDOW_ID:-$(resolve_from_claude_env KITTY_WINDOW_ID || true)}"

[[ "$KITTY_LISTEN_ON_RESOLVED" =~ $KITTY_LISTEN_RE ]] || KITTY_LISTEN_ON_RESOLVED=""
[[ "$KITTY_WINDOW_ID_RESOLVED" =~ ^[0-9]+$ ]] || KITTY_WINDOW_ID_RESOLVED=""

# ── notify_kitty: primary path with full feature set ───────────
notify_kitty() {
    local listen="$KITTY_LISTEN_ON_RESOLVED"
    local win_id="$KITTY_WINDOW_ID_RESOLVED"

    local ls_json
    ls_json=$(timeout 2 kitty @ --to "$listen" ls 2>/dev/null) || {
        notify_dumb
        return
    }

    local title="" focused=""
    if [ -n "$win_id" ]; then
        title=$(jq -r --argjson w "$win_id" \
            '.[] | .tabs[] | .windows[] | select(.id == $w) | .title // ""' \
            <<< "$ls_json" 2>/dev/null | head -1)
        focused=$(jq -r --argjson w "$win_id" \
            '.[] | .tabs[] | .windows[] | select(.id == $w) | .is_focused // false' \
            <<< "$ls_json" 2>/dev/null | head -1)
    fi

    [ "$focused" = "true" ] && return 0

    local session=""
    [ -n "$title" ] && session=$(printf '%s' "$title" | sed 's/^[^a-zA-Z0-9]*//')

    local body
    if [ -n "$session" ]; then
        body="${session}: ${MESSAGE}"
    else
        body="$MESSAGE"
    fi

    # Background subshell: emit via notify-send -A (blocks until click or
    # programmatic close). Race notify-send's stdout (action key) against
    # focus-poll on the kitty window; on focus regain, kill notify-send to
    # close the toast. On click, raise the kitty window.
    (
        # coproc gives us a bidirectional pipe to notify-send so we can
        # read its action stdout non-blockingly while it blocks on --wait.
        # 2>/dev/null on stderr to avoid coproc warnings about stdin.
        coproc NS {
            notify-send \
                --urgency=critical \
                --app-name="Claude Code" \
                --icon="$ICON" \
                --action="default=Open Terminal" \
                'Claude Code' \
                "$body" 2>/dev/null
        }
        local ns_pid="${NS_PID:-}"
        local in_fd="${NS[0]:-}"

        if [ -z "$ns_pid" ] || [ -z "$in_fd" ]; then
            return 0
        fi

        local action=""
        local i max=3000  # 0.1s/iter * 3000 = 5min
        for ((i = 1; i <= max; i++)); do
            # Try to read action key (non-blocking up to 0.1s)
            if read -t 0.1 -u "$in_fd" line 2>/dev/null; then
                action="$line"
                break
            fi
            # If notify-send died (closed by daemon, killed, etc.), drain & exit
            if ! kill -0 "$ns_pid" 2>/dev/null; then
                read -t 0.5 -u "$in_fd" line 2>/dev/null && action="$line"
                break
            fi
            # Focus-poll every 2s, after 5s grace period
            if (( i > 50 && i % 20 == 0 )); then
                local poll
                poll=$(timeout 2 kitty @ --to "$listen" ls 2>/dev/null) || continue
                local now_focused
                now_focused=$(jq -r --argjson w "$win_id" \
                    '.[] | .tabs[] | .windows[] | select(.id == $w) | .is_focused // false' \
                    <<< "$poll" 2>/dev/null | head -1)
                if [ "$now_focused" = "true" ]; then
                    kill "$ns_pid" 2>/dev/null
                    break
                fi
            fi
        done

        wait "$ns_pid" 2>/dev/null

        if [ "$action" = "default" ] && [ -n "$win_id" ]; then
            timeout 2 kitty @ --to "$listen" \
                focus-window --match "id:$win_id" \
                >/dev/null 2>&1 || true
        fi
    ) &
    disown
}

# ── notify_dumb: notify-send only, no focus tracking ───────────
notify_dumb() {
    local session
    session=$(basename "$(pwd)")
    local body
    if [ -n "$session" ] && [ "$session" != "/" ]; then
        body="${session}: ${MESSAGE}"
    else
        body="$MESSAGE"
    fi
    (
        notify-send \
            --urgency=critical \
            --app-name="Claude Code" \
            --icon="$ICON" \
            'Claude Code' \
            "$body" 2>/dev/null || true
    ) &
    disown
}

# ── notify_wsl: WSLg path ──────────────────────────────────────
notify_wsl() {
    notify_dumb
}

# ── notify_windows: Git Bash + BurntToast ──────────────────────
notify_windows() {
    if ! command -v powershell.exe >/dev/null 2>&1; then
        return 0
    fi
    printf '%s' "$RAW" | powershell.exe -NoProfile -Command '
        $body = [Console]::In.ReadToEnd()
        if (Get-Module -ListAvailable -Name BurntToast) {
            Import-Module BurntToast
            New-BurntToastNotification -Text "Claude Code", $body
        }
    ' >/dev/null 2>&1 &
    disown
}

# ── Dispatch ────────────────────────────────────────────────────
if [ -n "$KITTY_LISTEN_ON_RESOLVED" ] && command -v kitty >/dev/null 2>&1; then
    notify_kitty
    exit 0
fi

case "$(uname -s)" in
    Linux*)
        if grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null; then
            notify_wsl
        else
            notify_dumb
        fi
        ;;
    Darwin*)
        notify_dumb
        ;;
    MINGW*|MSYS*|CYGWIN*)
        notify_windows
        ;;
esac
