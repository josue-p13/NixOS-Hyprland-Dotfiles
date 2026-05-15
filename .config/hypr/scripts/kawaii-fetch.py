#!/usr/bin/env python3

import os
import signal
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

GRUVBOX = {
    "bg": "#282828",
    "bg2": "#3c3836",
    "bg3": "#504945",
    "fg": "#ebdbb2",
    "fg2": "#a89984",
    "gray": "#928374",
    "red": "#fb4934",
    "green": "#b8bb26",
    "yellow": "#fabd2f",
    "blue": "#83a598",
    "purple": "#d3869b",
    "orange": "#fe8019",
    "aqua": "#8ec07c",
}

NIXOS_ART = [
    (r"%%%%%%%%%%%%###%%%%%%%%%****#%%%%#***%%%%%%%%%%%", GRUVBOX["blue"]),
    (r"%%%%%%%%%%%#****%%%%%%%%#****#%%#****#%%%%%%%%%%", GRUVBOX["blue"]),
    (r"%%%%%%%%%%%%#****%%%%%%%%#****#*****#%%%%%%%%%%%", GRUVBOX["blue"]),
    (r"%%%%%%%%%%%%%#****%%%%%%%%#********#%%%%%%%%%%%%", GRUVBOX["blue"]),
    (r"%%%%%%%#######****#######%%#******#%%%%%%%%%%%%%", GRUVBOX["aqua"]),
    (r"%%%%%#********************#%#*****%%%%%%**%%%%%%", GRUVBOX["aqua"]),
    (r"%%%%#**********************#%#****#%%%%****%%%%%", GRUVBOX["aqua"]),
    (r"%%%%%%%%%%%%#####%%%%%%%%%%%%%*****%%%****#%%%%%", GRUVBOX["aqua"]),
    (r"%%%%%%%%%%%*****#%%%%%%%%%%%%%%****%%****#%%%%%%", GRUVBOX["blue"]),
    (r"%%%%%%%%%%#****%%%%%%%%%%%%%%%%%**%%****#%%%%%%%", GRUVBOX["blue"]),
    (r"#*************#%%%%%%%%%%%%%%%%%%%%*****#######%", GRUVBOX["blue"]),
    (r"*************#%%%%%%%%%%%%%%%%%%%%#************#", GRUVBOX["blue"]),
    (r"#***********#%%%%%%%%%%%%%%%%%%%%#****#########%", GRUVBOX["aqua"]),
    (r"%%%%%%#****#%#*%%%%%%%%%%%%%%%%%#****%%%%%%%%%%%", GRUVBOX["aqua"]),
    (r"%%%%%#****#%#***%%%%%%%%%%%%%%%#****%%%%%%%%%%%%", GRUVBOX["aqua"]),
    (r"%%%%#****#%%#****#%%%%%%%%%%%%%####%%%%%%%%%%%%%", GRUVBOX["aqua"]),
    (r"%%%%#****%%%%#****%%**********************%%%%%%", GRUVBOX["blue"]),
    (r"%%%%%#**%%%%%%*****%%********************%%%%%%%", GRUVBOX["blue"]),
    (r"%%%%%%#%%%%%%#******#%#########*****####%%%%%%%%", GRUVBOX["blue"]),
    (r"%%%%%%%%%%%%*********%%%%%%%%%%#****#%%%%%%%%%%%", GRUVBOX["blue"]),
    (r"%%%%%%%%%%%#****%#***#%%%%%%%%%%#****#%%%%%%%%%%", GRUVBOX["aqua"]),
    (r"%%%%%%%%%%#****%%%#***#%%%%%%%%%%#****#%%%%%%%%%", GRUVBOX["aqua"]),
    (r"%%%%%%%%%%####%%%%%#####%%%%%%%%%%#***%%%%%%%%%%", GRUVBOX["aqua"]),
]


def get_info():
    info = {}

    try:
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    info["os"] = line.split("=")[1].strip().strip('"')
                    break
    except:
        info["os"] = "NixOS"

    try:
        info["kernel"] = os.popen("uname -r").read().strip().split('-')[0]
    except:
        info["kernel"] = "?"

    try:
        info["shell"] = os.path.basename(os.environ.get("SHELL", "bash"))
    except:
        info["shell"] = "bash"

    try:
        count = subprocess.check_output(
            ["nix-store", "-q", "--references", "/run/current-system/sw"],
            stderr=subprocess.DEVNULL
        ).decode()
        info["pkgs"] = str(len(count.strip().split("\n"))) + " (nix)"
    except:
        info["pkgs"] = "?"

    try:
        with open("/proc/uptime") as f:
            secs = int(float(f.read().split()[0]))
            d = secs // 86400
            h = (secs % 86400) // 3600
            m = (secs % 3600) // 60
            if d > 0:
                info["uptime"] = f"{d}d {h}h {m}m"
            elif h > 0:
                info["uptime"] = f"{h}h {m}m"
            else:
                info["uptime"] = f"{m}m"
    except:
        info["uptime"] = "?"

    try:
        mem = os.popen("free -h | awk '/^Mem:/ {print $2}'").read().strip()
        info["mem"] = mem
    except:
        info["mem"] = "?"

    gpu = "?"
    try:
        out = subprocess.check_output(
            ["lspci", "-mm"],
            stderr=subprocess.DEVNULL,
            text=True
        )
        for line in out.split('\n'):
            if 'VGA' in line or '3D' in line:
                gpu = line.split('"')[3] if '"' in line else line
                break
    except:
        pass

    if gpu == "?":
        try:
            with open("/sys/class/drm/card1/device/vendor") as f:
                if f.read().strip() == "0x10de":
                    with open("/sys/class/drm/card1/device/device") as f:
                        gpu = "NVIDIA RTX"
        except:
            pass

    info["gpu"] = gpu
    info["de"] = "Hyprland"

    return info


class KawaiiFetch(Gtk.Window):
    def __init__(self):
        super().__init__()

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 40)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.LEFT, 280)

        css = f"""
        window {{
            background-color: {GRUVBOX["bg"]};
            border: 1px solid {GRUVBOX["orange"]};
            border-radius: 18px;
        }}
        .title {{
            font-size: 10px;
            font-weight: 700;
            color: {GRUVBOX["orange"]};
            font-family: "JetBrains Mono", monospace;
            letter-spacing: 3px;
        }}
        """.encode()
        p = Gtk.CssProvider()
        p.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        vbox.set_border_width(14)
        self.add(vbox)

        title = Gtk.Label(label="NIXOS")
        title.get_style_context().add_class("title")
        title.set_halign(Gtk.Align.CENTER)
        vbox.pack_start(title, False, False, 4)

        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        logo_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        for text, color in NIXOS_ART:
            lbl = Gtk.Label()
            lbl.set_markup(f'<span font="monospace 8" color="{color}">{text}</span>')
            lbl.set_halign(Gtk.Align.START)
            logo_box.pack_start(lbl, False, False, 0)
        hbox.pack_start(logo_box, False, False, 0)

        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        self._labels = {}

        rows_data = [
            ("OS", "os", GRUVBOX["yellow"]),
            ("Kernel", "kernel", GRUVBOX["green"]),
            ("Shell", "shell", GRUVBOX["blue"]),
            ("Packages", "pkgs", GRUVBOX["orange"]),
            ("Uptime", "uptime", GRUVBOX["purple"]),
            ("RAM", "mem", GRUVBOX["red"]),
            ("GPU", "gpu", GRUVBOX["green"]),
            ("DE", "de", GRUVBOX["yellow"]),
        ]

        for label, key, color in rows_data:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            lbl = Gtk.Label()
            lbl.set_markup(
                f'<span font="JetBrains Mono 11" color="{GRUVBOX["gray"]}">{label}</span>'
            )
            lbl.set_halign(Gtk.Align.END)
            lbl.set_size_request(90, -1)
            row.pack_start(lbl, False, False, 0)

            val = Gtk.Label()
            val.set_halign(Gtk.Align.START)
            val.set_line_wrap(True)
            row.pack_start(val, False, False, 0)

            info_box.pack_start(row, False, False, 0)
            self._labels[key] = (val, color)

        hbox.pack_start(info_box, False, False, 0)
        vbox.pack_start(hbox, False, False, 0)

        self.update()
        GLib.timeout_add(10000, self.update)

    def update(self):
        info = get_info()
        for key, (label, color) in self._labels.items():
            val = info.get(key, "?")
            label.set_markup(
                f'<span font="JetBrains Mono 11" weight="bold" color="{color}">{val}</span>'
            )
        return True


if __name__ == "__main__":
    signal.signal(signal.SIGINT, lambda s, f: (Gtk.main_quit(), sys.exit(0)))
    app = KawaiiFetch()
    app.show_all()
    Gtk.main()
