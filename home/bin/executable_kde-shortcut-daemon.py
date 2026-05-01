#!/usr/bin/env python3
"""
Registers kglobalaccel shortcuts that run shell commands for KDE Plasma 6 / Wayland.
Runs as an autostart daemon. Shortcuts persist via kglobalshortcutsrc.
"""
import dbus
import dbus.mainloop.glib
from gi.repository import GLib
import os
import signal
import subprocess
import sys

if os.environ.get("XDG_CURRENT_DESKTOP", "") != "KDE":
    sys.exit(0)

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()

kga_obj = bus.get_object("org.kde.kglobalaccel", "/kglobalaccel")
kga = dbus.Interface(kga_obj, "org.kde.KGlobalAccel")

SHORTCUTS = [
    # (component, action, friendly_name, command)
    ("toggle-dnd", "toggle", "Toggle Do Not Disturb", os.path.expanduser("~/bin/toggle-dnd.sh")),
]

handlers = {}

for component, action, friendly, cmd in SHORTCUTS:
    action_id = dbus.Array([component, "", action, friendly], signature="s")
    kga.doRegister(action_id)

    comp_path = kga.getComponent(component)
    comp_obj = bus.get_object("org.kde.kglobalaccel", str(comp_path))
    comp_iface = dbus.Interface(comp_obj, "org.kde.kglobalaccel.Component")

    _action = action
    _cmd = cmd

    def make_handler(a, c):
        def on_pressed(unique_name, timestamp):
            if str(unique_name) == a:
                subprocess.Popen([c])
        return on_pressed

    comp_iface.connect_to_signal("globalShortcutPressed", make_handler(_action, _cmd))

loop = GLib.MainLoop()
signal.signal(signal.SIGTERM, lambda *_: loop.quit())
signal.signal(signal.SIGINT, lambda *_: loop.quit())
loop.run()
