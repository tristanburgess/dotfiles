#!/bin/bash
set -euo pipefail

# Toggle Do Not Disturb across Cinnamon, KDE Plasma 6, Windows Git Bash, and
# WSL. Always touches/removes ~/.claude-dnd so notify.sh suppresses the
# Claude-Code toast pipeline regardless of the system DND state. Linux DEs
# additionally suppress system-wide notifications via native APIs; Windows
# additionally flips the registry ToastEnabled key (Action Center master
# toggle).
#
# Bind to a global shortcut:
#   - Cinnamon: handled by run_once_after_07-dnd-shortcut.sh.tmpl
#   - KDE Plasma 6: configure manually under System Settings → Custom Shortcuts
#     (Plasma's native "toggle do not disturb" action has bug 436415: shortcut
#      stops working after closing System Settings)
#   - Windows + WSL: AutoHotkey script registered by the winget bootstrap.

DND_FLAG="$HOME/.claude-dnd"
KDE_DND_PID_FILE="/tmp/kde-dnd-pid"

set_flag()   { touch "$DND_FLAG"; }
clear_flag() { rm -f "$DND_FLAG"; }

UNAME=$(uname -s)
IS_WSL=0
[ "$UNAME" = Linux ] && grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null && IS_WSL=1

# ── Windows Git Bash ─────────────────────────────────────────────────────
# Claude-only DND: toggle the file flag (notify.sh checks it). System-wide
# Win11 DND stays out of scope -- use Win+N native focus for that.
case "$UNAME" in
    MINGW*|MSYS*|CYGWIN*)
        if [ -f "$DND_FLAG" ]; then
            clear_flag
            STATE="OFF"
        else
            set_flag
            STATE="ON"
        fi
        # OSD via BurntToast (PowerShell-branded; AUMID branding blocked on
        # Win11 22H2+ for unpackaged callers).
        powershell.exe -NoProfile -Command "
            if (Get-Module -ListAvailable -Name BurntToast) {
                Import-Module BurntToast
                \$logo = Join-Path \$env:USERPROFILE '.claude\claude-logo.png'
                if (Test-Path \$logo) {
                    New-BurntToastNotification -Text 'Do Not Disturb', 'Do Not Disturb: $STATE' -AppLogo \$logo -Silent
                } else {
                    New-BurntToastNotification -Text 'Do Not Disturb', 'Do Not Disturb: $STATE' -Silent
                }
            }" 2>/dev/null || true
        # Mirror flag into WSL so WSL Claude panes see same DND state.
        if command -v wsl.exe >/dev/null 2>&1; then
            if [ "$STATE" = "ON" ]; then
                wsl.exe -e bash -c 'touch "$HOME/.claude-dnd"' 2>/dev/null || true
            else
                wsl.exe -e bash -c 'rm -f "$HOME/.claude-dnd"' 2>/dev/null || true
            fi
        fi
        exit 0
        ;;
esac

# ── WSL ──────────────────────────────────────────────────────────────────
if [ "$IS_WSL" = 1 ]; then
    if [ -f "$DND_FLAG" ]; then
        clear_flag
        STATE="OFF"
    else
        set_flag
        STATE="ON"
    fi
    # Mirror flag to Windows side so a Git Bash Claude pane sees same state.
    if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -Command "
            if (Get-Module -ListAvailable -Name BurntToast) {
                Import-Module BurntToast
                \$logo = Join-Path \$env:USERPROFILE '.claude\claude-logo.png'
                if (Test-Path \$logo) {
                    New-BurntToastNotification -Text 'Do Not Disturb', 'Do Not Disturb: $STATE' -AppLogo \$logo -Silent
                } else {
                    New-BurntToastNotification -Text 'Do Not Disturb', 'Do Not Disturb: $STATE' -Silent
                }
            }
            \$flag = Join-Path \$env:USERPROFILE '.claude-dnd'
            if ('$STATE' -eq 'ON') { New-Item -ItemType File -Force \$flag | Out-Null } else { Remove-Item -Force \$flag -ErrorAction SilentlyContinue }
        " 2>/dev/null || true
    fi
    # WSLg notify-send for an in-WSL OSD (best effort).
    notify-send --urgency=low --app-name="Do Not Disturb" "Do Not Disturb: $STATE" 2>/dev/null || true
    exit 0
fi

# ── Linux bare-metal: KDE / Cinnamon ─────────────────────────────────────
if [[ "${XDG_CURRENT_DESKTOP:-}" == *"KDE"* ]]; then
    if [[ -f "$KDE_DND_PID_FILE" ]] && kill -0 "$(cat "$KDE_DND_PID_FILE")" 2>/dev/null; then
        kill "$(cat "$KDE_DND_PID_FILE")"
        rm -f "$KDE_DND_PID_FILE"
        clear_flag
        STATE="OFF"
    else
        rm -f "$KDE_DND_PID_FILE"
        set_flag
        # Background Python holds the DBus Inhibit cookie open until killed.
        # Inhibit is tied to the caller's DBus connection lifetime; a one-shot
        # script would release immediately on exit.
        python3 -c "
import dbus, dbus.mainloop.glib, gi.repository.GLib as GLib, signal
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
notif = bus.get_object('org.kde.plasmashell', '/org/freedesktop/Notifications')
iface = dbus.Interface(notif, 'org.freedesktop.Notifications')
cookie = iface.Inhibit('toggle-dnd', 'Do Not Disturb', {})
loop = GLib.MainLoop()
signal.signal(signal.SIGTERM, lambda *_: (iface.UnInhibit(cookie), loop.quit()))
loop.run()
" &
        echo $! > "$KDE_DND_PID_FILE"
        disown
        STATE="ON"
    fi
    # KDE native OSD; bypasses notification suppression.
    qdbus6 org.kde.plasmashell /org/kde/osdService \
        org.kde.osdService.showText "notifications" "Do Not Disturb: ${STATE}" 2>/dev/null || true

elif [[ "${XDG_CURRENT_DESKTOP:-}" == *"Cinnamon"* ]]; then
    current=$(gsettings get org.cinnamon.desktop.notifications display-notifications)
    if [ "$current" = "true" ]; then
        gsettings set org.cinnamon.desktop.notifications display-notifications false
        set_flag
        STATE="ON"
    else
        gsettings set org.cinnamon.desktop.notifications display-notifications true
        clear_flag
        STATE="OFF"
    fi

    # Cinnamon themed GTK popup
    pkill -f "dnd-popup-proc" 2>/dev/null || true
    python3 - "$STATE" "dnd-popup-proc" <<'PYEOF' &
import gi, sys
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib

state = sys.argv[1]

provider = Gtk.CssProvider()
provider.load_from_data(b"""
window { background-color: rgba(30, 28, 68, 0.9); border-radius: 12px; }
label  { color: #4ec9b0; font-family: "VT323"; font-size: 22px; font-weight: bold; letter-spacing: 4px; padding: 10px 12px; }
""")
Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

win = Gtk.Window(title="dnd-popup")
win.set_decorated(False)
win.set_keep_above(True)
win.set_skip_taskbar_hint(True)
win.set_skip_pager_hint(True)
win.set_visual(win.get_screen().get_rgba_visual())
win.set_app_paintable(True)

opacity = [0.0]
phase = ["fade_in"]
FADE_IN_STEP = 0.05
FADE_OUT_STEP = 0.25
FADE_INTERVAL = 16  # ~60fps
HOLD_MS = 300

def on_draw(w, cr):
    cr.set_operator(0)  # CLEAR
    cr.paint()
    cr.set_operator(2)  # OVER
    cr.set_source_rgba(30/255, 28/255, 68/255, 0.9 * opacity[0])
    cr.rectangle(0, 0, w.get_allocated_width(), w.get_allocated_height())
    cr.fill()
    return False

win.connect("draw", on_draw)

label = Gtk.Label(label=f"Do Not Disturb: {state}")
win.add(label)

def tick():
    if phase[0] == "fade_in":
        opacity[0] = min(1.0, opacity[0] + FADE_IN_STEP)
        win.set_opacity(opacity[0])
        win.queue_draw()
        if opacity[0] >= 1.0:
            phase[0] = "hold"
            GLib.timeout_add(HOLD_MS, tick)
            return False
    elif phase[0] == "hold":
        phase[0] = "fade_out"
    elif phase[0] == "fade_out":
        opacity[0] = max(0.0, opacity[0] - FADE_OUT_STEP)
        win.set_opacity(opacity[0])
        win.queue_draw()
        if opacity[0] <= 0.0:
            Gtk.main_quit()
            return False
    return True

win.set_opacity(0.0)
win.show_all()

geom = win.get_screen().get_monitor_geometry(win.get_screen().get_primary_monitor())
win.resize(geom.width, 1)
win.move(geom.x, geom.y)

GLib.timeout_add(FADE_INTERVAL, tick)
Gtk.main()
PYEOF
    disown

else
    echo "Unsupported DE: ${XDG_CURRENT_DESKTOP:-unknown}" >&2
    exit 1
fi
