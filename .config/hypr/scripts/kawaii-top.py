#!/usr/bin/env python3

import gi
import sys
import subprocess
import signal
gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, GtkLayerShell, GLib, Gdk

try:
    import psutil
except ImportError:
    sys.exit(1)

# Paleta Gruvbox
GRUVBOX = {
    "bg":      "#282828",
    "bg2":     "#3c3836",
    "bg3":     "#504945",
    "fg":      "#ebdbb2",
    "fg2":     "#a89984",
    "gray":    "#928374",
    "red":     "#fb4934",
    "green":   "#b8bb26",
    "yellow":  "#fabd2f",
    "blue":    "#83a598",
    "purple":  "#d3869b",
    "orange":  "#fe8019",
}

class StepBar(Gtk.Box):
    def __init__(self, color):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self._color = color
        self._segs = []
        for _ in range(5):
            s = Gtk.Label()
            s.set_size_request(14, 6)
            s.set_markup(f'<span size="4000" color="{GRUVBOX["bg3"]}">▒</span>')
            self.pack_start(s, False, False, 0)
            self._segs.append(s)

    def set(self, pct):
        active = int(pct * 5 / 100)
        for i, s in enumerate(self._segs):
            if i < active:
                s.set_markup(f'<span size="4000" color="{self._color}">█</span>')
            else:
                s.set_markup(f'<span size="4000" color="{GRUVBOX["bg3"]}">▒</span>')


class KawaiiTop(Gtk.Window):
    def __init__(self):
        super().__init__()

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 40)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.LEFT, 40)

        css = f"""
        window {{
            background-color: {GRUVBOX["bg"]};
            border: 1px solid {GRUVBOX["orange"]};
            border-radius: 18px;
        }}
        .card {{
            background-color: {GRUVBOX["bg2"]};
            border-radius: 12px;
            border: 1px solid {GRUVBOX["bg3"]};
            padding: 8px 6px;
        }}
        .title {{
            font-size: 10px;
            font-weight: 700;
            color: {GRUVBOX["orange"]};
            font-family: "JetBrains Mono", monospace;
            letter-spacing: 3px;
        }}
        .face {{
            font-size: 12px;
            font-weight: bold;
            color: {GRUVBOX["purple"]};
            font-family: "JetBrains Mono", monospace;
        }}
        """.encode()
        p = Gtk.CssProvider()
        p.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        vbox.set_border_width(12)
        self.add(vbox)

        title = Gtk.Label(label="SYSTEM")
        title.get_style_context().add_class("title")
        title.set_halign(Gtk.Align.CENTER)
        vbox.pack_start(title, False, False, 2)

        grid = Gtk.Grid()
        grid.set_row_spacing(5)
        grid.set_column_spacing(5)

        self._cards = {}
        self._bars = {}
        for col, (label, color) in enumerate([
            ("CPU",  GRUVBOX["yellow"]),
            ("RAM",  GRUVBOX["orange"]),
            ("GPU",  GRUVBOX["blue"]),
            ("TEMP", GRUVBOX["red"]),
            ("DISK", GRUVBOX["green"]),
            ("NET",  GRUVBOX["purple"]),
        ]):
            row = col // 2
            coln = col % 2

            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
            card.set_size_request(95, 80)
            card.get_style_context().add_class("card")

            name_lbl = Gtk.Label()
            name_lbl.set_markup(
                f'<span font="JetBrains Mono 9" weight="bold" color="{color}" '
                f'letter_spacing="2048">{label}</span>')
            name_lbl.set_halign(Gtk.Align.CENTER)
            card.pack_start(name_lbl, False, False, 0)

            val_lbl = Gtk.Label(label="--")
            val_lbl.set_name(f"val-{label.lower()}")
            val_lbl.set_halign(Gtk.Align.CENTER)
            card.pack_start(val_lbl, False, False, 0)

            bar = StepBar(color)
            card.pack_start(bar, False, False, 0)

            css_val = f"""
            #{val_lbl.get_name()} {{
                font-size: 17px;
                font-weight: 900;
                color: {color};
                font-family: "JetBrains Mono", monospace;
            }}
            """.encode()
            prov = Gtk.CssProvider()
            prov.load_from_data(css_val)
            val_lbl.get_style_context().add_provider(prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

            grid.attach(card, coln, row, 1, 1)
            self._cards[label] = val_lbl
            self._bars[label] = bar

        vbox.pack_start(grid, False, False, 0)

        self.face = Gtk.Label(label="( ˶ˆ꒳ˆ˵ )")
        self.face.get_style_context().add_class("face")
        self.face.set_halign(Gtk.Align.CENTER)
        vbox.pack_start(self.face, False, False, 2)

        self._rx = 0
        self._tx = 0
        self.update()
        GLib.timeout_add(2000, self.update)

    def get_gpu(self):
        try:
            out = subprocess.check_output(
                ["nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv,noheader"],
                stderr=subprocess.DEVNULL).decode().strip()
            return float(out.replace("%", ""))
        except:
            return None

    def get_temp(self):
        try:
            t = psutil.sensors_temperatures()
            if 'coretemp' in t: return t['coretemp'][0].current
            for k in t:
                if t[k]: return t[k][0].current
        except: pass
        return None

    def fmt(self, bps):
        if bps > 1_000_000: return f"{bps/1_000_000:.1f}M"
        if bps > 1_000: return f"{bps/1_000:.0f}K"
        return f"{bps}"

    def get_face(self, cpu, gpu, temp):
        mx = max(cpu, gpu or 0, (temp or 0) - 30)
        if mx > 90: return "(＃＞＜)"
        if mx > 70: return "(・_・;)"
        if mx > 50: return "()"
        if mx > 25: return "( ˶ )"
        return "()♡"

    def update(self):
        cpu = psutil.cpu_percent()
        ram = psutil.virtual_memory().percent
        temp = self.get_temp()
        gpu = self.get_gpu()
        disk = psutil.disk_usage('/').percent
        net = psutil.net_io_counters()
        rx, tx = net.bytes_recv - self._rx, net.bytes_sent - self._tx
        self._rx, self._tx = net.bytes_recv, net.bytes_sent

        self._cards["CPU"].set_markup(
            f'<span font="JetBrains Mono 17" weight="900" color="{GRUVBOX["yellow"]}">{cpu:.0f}%</span>')
        self._cards["RAM"].set_markup(
            f'<span font="JetBrains Mono 17" weight="900" color="{GRUVBOX["orange"]}">{ram:.0f}%</span>')
        if gpu is not None:
            self._cards["GPU"].set_markup(
                f'<span font="JetBrains Mono 17" weight="900" color="{GRUVBOX["blue"]}">{gpu:.0f}%</span>')
        else:
            self._cards["GPU"].set_markup(
                f'<span font="JetBrains Mono 17" weight="900" color="{GRUVBOX["blue"]}">--</span>')
        if temp is not None:
            self._cards["TEMP"].set_markup(
                f'<span font="JetBrains Mono 17" weight="900" color="{GRUVBOX["red"]}">{temp:.0f}°C</span>')
        else:
            self._cards["TEMP"].set_markup(
                f'<span font="JetBrains Mono 17" weight="900" color="{GRUVBOX["red"]}">--</span>')
        self._cards["DISK"].set_markup(
            f'<span font="JetBrains Mono 17" weight="900" color="{GRUVBOX["green"]}">{disk:.0f}%</span>')
        self._cards["NET"].set_markup(
            f'<span font="JetBrains Mono 17" weight="900" color="{GRUVBOX["purple"]}">↓{self.fmt(rx)}</span>')

        self._bars["CPU"].set(cpu)
        self._bars["RAM"].set(ram)
        if gpu is not None:
            self._bars["GPU"].set(gpu)
        else:
            self._bars["GPU"].set(0)
        if temp is not None:
            self._bars["TEMP"].set(min(temp, 100))
        else:
            self._bars["TEMP"].set(0)
        self._bars["DISK"].set(disk)
        self._bars["NET"].set(min((rx + tx) / 1_000_000 * 10, 100))

        self.face.set_label(self.get_face(cpu, gpu, temp))
        return True

if __name__ == "__main__":
    signal.signal(signal.SIGINT, lambda s, f: (Gtk.main_quit(), sys.exit(0)))
    app = KawaiiTop()
    app.show_all()
    Gtk.main()