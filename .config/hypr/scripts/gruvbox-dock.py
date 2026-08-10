#!/usr/bin/env python3

import gi
import sys
import os
import subprocess
import signal
import threading
import json
gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, GtkLayerShell, GLib, Gdk

FIFO = "/tmp/gruvbox_dock_fifo"

APPS = [
    ("Zen", "zen-beta", ""),
    ("Code", "code", "󰨞"),
    ("WhatsApp", "brave --profile-directory=Default --app-id=hnpfjngllnobngcgfapefoaidbinmjnm", ""),
    ("Zed", "zeditor", "󰏫"),
    ("Spotify", "spotify", ""),
    ("Mail", "thunderbird", ""),
]

def get_colors():
    cache_file = os.path.expanduser("~/.cache/wallust/colors.json")
    c = {
        "bg": "#282828", "bg2": "#3c3836", "bg3": "#504945",
        "fg": "#ebdbb2", "orange": "#fe8019", "yellow": "#fabd2f",
        "purple": "#d3869b", "gray": "#928374",
    }
    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r") as f:
                w = json.load(f)
                cl = w['colors']
                c.update({
                    "bg": w['background'], "bg2": cl['color8'], "bg3": cl['color0'],
                    "fg": w['foreground'], "orange": cl['color9'], "yellow": cl['color3'],
                    "purple": cl['color5'], "gray": cl['color7']
                })
        except: pass
    return c

GRUVBOX = get_colors()

class GruvboxDock(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.set_name("dock-window")

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 8)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        css = f"""
        #dock-window {{
            background-color: rgba(0,0,0,0);
        }}
        #dock-box {{
            background-color: {GRUVBOX["bg"]};
            border: 1px solid {GRUVBOX["orange"]};
            border-radius: 20px;
            padding: 10px 14px;
        }}
        .d-icon {{
            font-size: 26px;
            color: {GRUVBOX["gray"]};
        }}
        .d-icon-active {{
            font-size: 26px;
            color: {GRUVBOX["yellow"]};
        }}
        .d-name {{
            font-size: 10px;
            font-weight: 600;
            color: {GRUVBOX["gray"]};
            font-family: "JetBrains Mono", monospace;
        }}
        .d-name-active {{
            font-size: 10px;
            font-weight: 700;
            color: {GRUVBOX["orange"]};
            font-family: "JetBrains Mono", monospace;
        }}
        .d-item {{
            background: transparent;
            border: none;
            border-radius: 14px;
            padding: 6px 8px;
        }}
        .d-item-active {{
            background-color: transparent;
            border: 2px solid {GRUVBOX["orange"]};
            border-radius: 14px;
            padding: 4px 6px;
        }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        outer.set_halign(Gtk.Align.CENTER)
        self.add(outer)

        self.dock_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        self.dock_box.set_name("dock-box")
        outer.pack_start(self.dock_box, False, False, 0)

        self._items = []
        self._boxes = []
        self._icons = []
        self._names = []
        self._commands = []
        self._index = 0

        for name, cmd, icon in APPS:
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            box.set_size_request(72, 72)
            box.get_style_context().add_class("d-item")

            icon_lbl = Gtk.Label(label=icon)
            icon_lbl.get_style_context().add_class("d-icon")
            icon_lbl.set_halign(Gtk.Align.CENTER)
            box.pack_start(icon_lbl, False, False, 0)

            name_lbl = Gtk.Label(label=name)
            name_lbl.get_style_context().add_class("d-name")
            name_lbl.set_halign(Gtk.Align.CENTER)
            box.pack_start(name_lbl, False, False, 0)

            self.dock_box.pack_start(box, False, False, 0)

            self._boxes.append(box)
            self._icons.append(icon_lbl)
            self._names.append(name_lbl)
            self._commands.append(cmd)

        self.connect("key-press-event", self._on_key)
        self._hide_timer = None

        self._grabbed = False

    def _launch(self, cmd):
        subprocess.Popen(["hyprctl", "dispatch", "exec", cmd],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def _on_key(self, widget, event):
        key = event.keyval
        ks = event.get_state()

        if key == Gdk.KEY_Escape:
            self.hide()
            return True
        if key == Gdk.KEY_Left or key == Gdk.KEY_h:
            self._index = (self._index - 1) % len(self._boxes)
            self._update_highlight()
            self._reset_hide_timer()
            return True
        if key == Gdk.KEY_Right or key == Gdk.KEY_l:
            self._index = (self._index + 1) % len(self._boxes)
            self._update_highlight()
            self._reset_hide_timer()
            return True
        if key == Gdk.KEY_Return or key == Gdk.KEY_KP_Enter:
            cmd = self._commands[self._index]
            self.hide()
            self._launch(cmd)
            return True
        return False

    def _update_highlight(self):
        for i, (box, icon, name) in enumerate(zip(self._boxes, self._icons, self._names)):
            ic = icon.get_style_context()
            nc = name.get_style_context()
            bc = box.get_style_context()
            if i == self._index:
                ic.remove_class("d-icon")
                ic.add_class("d-icon-active")
                nc.remove_class("d-name")
                nc.add_class("d-name-active")
                bc.remove_class("d-item")
                bc.add_class("d-item-active")
            else:
                ic.remove_class("d-icon-active")
                ic.add_class("d-icon")
                nc.remove_class("d-name-active")
                nc.add_class("d-name")
                bc.remove_class("d-item-active")
                bc.add_class("d-item")

    def _reset_hide_timer(self):
        if self._hide_timer:
            GLib.source_remove(self._hide_timer)
        self._hide_timer = GLib.timeout_add(4000, self._do_hide)

    def _do_hide(self):
        self.hide()
        self._hide_timer = None
        return False

    def show(self):
        Gtk.Window.show(self)
        self._index = 0
        self._update_highlight()
        self.present()
        self._reset_hide_timer()

    def toggle(self):
        if self.get_visible():
            self.hide()
        else:
            self.show_all()
            self.show()


def fifo_reader(dock):
    if not os.path.exists(FIFO):
        os.mkfifo(FIFO)
    while True:
        try:
            with open(FIFO, "r") as f:
                for line in f:
                    GLib.idle_add(dock.toggle)
        except:
            pass


if __name__ == "__main__":
    signal.signal(signal.SIGINT, lambda s, f: (Gtk.main_quit(), sys.exit(0)))
    dock = GruvboxDock()
    t = threading.Thread(target=fifo_reader, args=(dock,), daemon=True)
    t.start()
    Gtk.main()
