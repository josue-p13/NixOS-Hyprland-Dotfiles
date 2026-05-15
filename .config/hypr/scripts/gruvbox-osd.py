#!/usr/bin/env python3

import gi
import sys
import os
import signal
gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, GtkLayerShell, GLib, Gio, Gdk

FIFO_PATH = "/tmp/gruvbox_osd_fifo"

class OSD(Gtk.Window):
    def __init__(self):
        super().__init__()
        
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 120)
        
        # CSS Gruvbox
        css_provider = Gtk.CssProvider()
        css = b"""
        window {
            background-color: rgba(40, 40, 40, 0.95);
            border: 2px solid #fe8019;
            border-radius: 20px;
        }
        box {
            padding: 12px 24px;
        }
        label {
            font-size: 24px;
            color: #ebdbb2;
            margin-right: 15px;
            font-family: "JetBrains Mono", "Fira Code", monospace;
        }
        progressbar {
            min-height: 12px;
        }
        progressbar trough {
            background-color: #3c3836;
            border-radius: 10px;
            min-height: 12px;
            min-width: 220px;
        }
        progressbar progress {
            background-color: #fabd2f;
            border-radius: 10px;
        }
        """
        css_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), 
            css_provider, 
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.add(self.box)

        self.icon_label = Gtk.Label(label="🔊")
        self.box.pack_start(self.icon_label, False, False, 0)

        self.progress = Gtk.ProgressBar()
        self.progress.set_valign(Gtk.Align.CENTER)
        self.box.pack_start(self.progress, True, True, 0)

        self.timeout_id = None

    def show_osd(self, osd_type, value):
        if osd_type == "vol":
            if value == 0:
                self.icon_label.set_text("🔇")
            elif value < 30:
                self.icon_label.set_text("🔈")
            elif value < 70:
                self.icon_label.set_text("🔉")
            else:
                self.icon_label.set_text("🔊")
        elif osd_type == "bri":
            self.icon_label.set_text("☀️")
            
        self.progress.set_fraction(value / 100.0)
        
        self.show_all()
        
        if self.timeout_id:
            GLib.source_remove(self.timeout_id)
        self.timeout_id = GLib.timeout_add(2000, self.hide_osd)

    def hide_osd(self):
        self.hide()
        self.timeout_id = None
        return False

def fifo_cb(channel, cond, osd):
    try:
        status, line, _, _ = channel.read_line()
        if status == GLib.IOStatus.NORMAL and line:
            line = line.strip()
            parts = line.split()
            if len(parts) >= 2:
                osd_type = parts[0]
                value = min(100.0, max(0.0, float(parts[1])))
                osd.show_osd(osd_type, value)
    except Exception as e:
        print(f"Error reading FIFO: {e}")
    return True

if __name__ == "__main__":
    if not os.path.exists(FIFO_PATH):
        os.mkfifo(FIFO_PATH)
    
    osd = OSD()
    
    # Open FIFO non-blocking
    fd = os.open(FIFO_PATH, os.O_RDWR | os.O_NONBLOCK)
    channel = GLib.IOChannel.unix_new(fd)
    GLib.io_add_watch(channel, GLib.PRIORITY_DEFAULT, GLib.IOCondition.IN, fifo_cb, osd)
    
    def on_sigint(sig, frame):
        Gtk.main_quit()
        sys.exit(0)

    signal.signal(signal.SIGINT, on_sigint)
    
    Gtk.main()