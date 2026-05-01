#!/bin/bash
set -euo pipefail

# DND toggle for Cinnamon. KDE Plasma 6 has a built-in DND toggle action
# (System Settings → Notifications) and a state-watcher daemon
# (kde-dnd-watcher.py) that surfaces the OSD on toggle, so KDE does not
# need this script.

if [[ "${XDG_CURRENT_DESKTOP:-}" == *"Cinnamon"* ]]; then
    current=$(gsettings get org.cinnamon.desktop.notifications display-notifications)
    if [ "$current" = "true" ]; then
        gsettings set org.cinnamon.desktop.notifications display-notifications false
        STATE="ON"
    else
        gsettings set org.cinnamon.desktop.notifications display-notifications true
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
    echo "Unsupported DE for this script: ${XDG_CURRENT_DESKTOP:-unknown}" >&2
    echo "On KDE Plasma 6, configure DND shortcut in System Settings → Notifications." >&2
    exit 1
fi
