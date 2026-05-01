#!/usr/bin/env python3
"""
KDE Plasma 6 Do Not Disturb state watcher.

Listens for changes to the `org.freedesktop.Notifications.Inhibited` property
on `/org/freedesktop/Notifications` (the Plasma notification service) and
shows a KDE OSD when DND turns on or off.

Why: Plasma's native DND keyboard shortcut (configured via System Settings →
Notifications) does not always show user feedback. This passive watcher fills
that gap without touching kglobalaccel or KWin.
"""
import os
import signal
import sys

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

if os.environ.get("XDG_CURRENT_DESKTOP", "") != "KDE":
    sys.exit(0)

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()

NOTIF_PATH = "/org/freedesktop/Notifications"
NOTIF_IFACE = "org.freedesktop.Notifications"
PLASMA_SERVICE = "org.kde.plasmashell"


def show_osd(state):
    try:
        osd = bus.get_object(PLASMA_SERVICE, "/org/kde/osdService")
        iface = dbus.Interface(osd, "org.kde.osdService")
        iface.showText("notifications", f"Do Not Disturb: {state}")
    except dbus.exceptions.DBusException:
        pass


def on_properties_changed(interface, changed, invalidated, path=None):
    if interface != NOTIF_IFACE:
        return
    if "Inhibited" in changed:
        state = "ON" if bool(changed["Inhibited"]) else "OFF"
        show_osd(state)


bus.add_signal_receiver(
    on_properties_changed,
    signal_name="PropertiesChanged",
    dbus_interface="org.freedesktop.DBus.Properties",
    bus_name=PLASMA_SERVICE,
    path=NOTIF_PATH,
    path_keyword="path",
)

loop = GLib.MainLoop()
signal.signal(signal.SIGTERM, lambda *_: loop.quit())
signal.signal(signal.SIGINT, lambda *_: loop.quit())
loop.run()
