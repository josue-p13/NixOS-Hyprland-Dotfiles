#!/usr/bin/env python3

import gi
import time
import os
import signal
import sys
gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, Gdk, GtkLayerShell, GLib

class KawaiiClock(Gtk.Window):
    def __init__(self):
        super().__init__()

        # Configurar la ventana para que se comporte como un widget (Layer Shell)
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 40)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 40)

        # Cargar estilos Gruvbox
        css_provider = Gtk.CssProvider()
        css = b"""
        window {
            background-color: rgba(40, 40, 40, 0.85); /* Gruvbox bg_dark */
            border: 2px solid #fe8019; /* Gruvbox orange */
            border-radius: 20px;
            padding: 20px;
        }
        .time {
            font-size: 64px;
            font-weight: 900;
            color: #fabd2f; /* Gruvbox yellow */
            text-shadow: 2px 2px 5px rgba(0,0,0,0.5);
            font-family: "JetBrains Mono", "Fira Code", monospace;
        }
        .date {
            font-size: 18px;
            font-weight: 600;
            color: #ebdbb2; /* Gruvbox fg */
            font-family: "JetBrains Mono", "Fira Code", monospace;
            margin-top: 5px;
            margin-bottom: 10px;
        }
        .kawaii {
            font-size: 24px;
            font-weight: bold;
            color: #d3869b; /* Gruvbox purple/pink */
            margin-top: 5px;
        }
        """
        css_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), 
            css_provider, 
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        # Contenedor principal
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        vbox.set_border_width(15)
        self.add(vbox)

        # Etiquetas
        self.time_label = Gtk.Label()
        self.time_label.get_style_context().add_class("time")
        vbox.pack_start(self.time_label, True, True, 0)

        self.date_label = Gtk.Label()
        self.date_label.get_style_context().add_class("date")
        vbox.pack_start(self.date_label, True, True, 0)

        self.kawaii_label = Gtk.Label(label="(≧◡≦)")
        self.kawaii_label.get_style_context().add_class("kawaii")
        vbox.pack_start(self.kawaii_label, True, True, 0)

        # Actualizar la hora inicialmente y luego cada segundo
        self.update_time()
        GLib.timeout_add_seconds(1, self.update_time)

    def update_time(self):
        current_time = time.strftime("%H:%M")
        current_date = time.strftime("%A, %d de %B") # Para español local
        self.time_label.set_text(current_time)
        self.date_label.set_text(current_date.capitalize())
        return True # Seguir ejecutando el timeout

def on_sigint(sig, frame):
    Gtk.main_quit()
    sys.exit(0)

if __name__ == "__main__":
    # Configurar locale a español si es posible
    import locale
    try:
        locale.setlocale(locale.LC_TIME, 'es_ES.UTF-8')
    except:
        try:
            locale.setlocale(locale.LC_TIME, '')
        except:
            pass

    signal.signal(signal.SIGINT, on_sigint)
    
    app = KawaiiClock()
    app.show_all()
    Gtk.main()
