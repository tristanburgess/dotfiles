#!/bin/bash
set -euo pipefail

KDE_DND_PID_FILE="/tmp/kde-dnd-pid"

if [[ "${XDG_CURRENT_DESKTOP:-}" == *"KDE"* ]]; then
    if [[ -f "$KDE_DND_PID_FILE" ]] && kill -0 "$(cat "$KDE_DND_PID_FILE")" 2>/dev/null; then
        kill "$(cat "$KDE_DND_PID_FILE")"
        rm -f "$KDE_DND_PID_FILE"
        STATE="OFF"
    else
        rm -f "$KDE_DND_PID_FILE"
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
elif [[ "${XDG_CURRENT_DESKTOP:-}" == *"Cinnamon"* ]]; then
    current=$(gsettings get org.cinnamon.desktop.notifications display-notifications)
    if [ "$current" = "true" ]; then
        gsettings set org.cinnamon.desktop.notifications display-notifications false
        STATE="ON"
    else
        gsettings set org.cinnamon.desktop.notifications display-notifications true
        STATE="OFF"
    fi
else
    echo "Unsupported DE: ${XDG_CURRENT_DESKTOP:-unknown}" >&2
    exit 1
fi

# Kill any existing DND popup
pkill -f "dnd-popup-proc" 2>/dev/null || true

# Show a themed popup with fade animation using GTK
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
