#!/usr/bin/env python3

import os
import gi
import subprocess
import signal

gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, Gdk, GdkPixbuf, GtkLayerShell, GLib

WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
SWAYBG_PATH = "/nix/store/lfzixjiiirjinvdxhi7kch3fg4fgh2m6-swaybg-1.2.2/bin/swaybg"

class WallpaperCarousel(Gtk.Window):
    def __init__(self):
        super().__init__(title="Wallpaper Carousel")
        
        # Hyprland Layer Shell configuration
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_interactivity(self, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)

        self.set_name("main-window")
        
        # List of wallpapers
        self.wallpapers = []
        for f in os.listdir(WALLPAPER_DIR):
            if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                self.wallpapers.append(f)
        self.wallpapers.sort()
        
        if not self.wallpapers:
            print("No wallpapers found")
            sys.exit(1)
            
        self.current_index = 0

        # UI Components
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main_box.set_valign(Gtk.Align.CENTER)
        main_box.set_halign(Gtk.Align.CENTER)
        self.add(main_box)

        # Carousel container
        self.carousel_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
        self.carousel_box.set_halign(Gtk.Align.CENTER)
        main_box.pack_start(self.carousel_box, True, True, 0)

        # Load images
        self.update_carousel()

        # Label for selection
        self.label = Gtk.Label(label=self.wallpapers[self.current_index])
        self.label.set_name("wp-label")
        main_box.pack_start(self.label, False, False, 20)

        # CSS Styling
        style_provider = Gtk.CssProvider()
        css = b"""
        #main-window {
            background-color: rgba(29, 32, 33, 0.85);
        }
        #wp-label {
            color: #ebdbb2;
            font-size: 24px;
            font-weight: bold;
        }
        .wp-item {
            border: 4px solid #3c3836;
            border-radius: 15px;
            background-color: #282828;
            margin: 10px;
        }
        .wp-item-selected {
            border: 6px solid #fe8019;
            box-shadow: 0px 0px 20px #fe8019;
        }
        """
        style_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.connect("key-press-event", self.on_key_press)
        self.show_all()

    def update_carousel(self):
        # Clear previous items
        for child in self.carousel_box.get_children():
            self.carousel_box.remove(child)

        # Show 3 items: Prev, Current, Next (Simple carousel)
        indices = [
            (self.current_index - 1) % len(self.wallpapers),
            self.current_index,
            (self.current_index + 1) % len(self.wallpapers)
        ]

        for i, idx in enumerate(indices):
            wp_name = self.wallpapers[idx]
            wp_path = os.path.join(WALLPAPER_DIR, wp_name)
            
            # Create a box for the image to apply styles
            box = Gtk.Box()
            box.get_style_context().add_class("wp-item")
            if i == 1: # Middle is selected
                box.get_style_context().add_class("wp-item-selected")
            
            # Load and scale image
            try:
                # Target size: 400x225 for middle, 300x168 for side
                w, h = (480, 270) if i == 1 else (320, 180)
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(wp_path, w, h, True)
                image = Gtk.Image.new_from_pixbuf(pixbuf)
                box.add(image)
            except Exception as e:
                print(f"Error loading {wp_name}: {e}")
            
            self.carousel_box.pack_start(box, False, False, 0)
        
        self.carousel_box.show_all()
        if hasattr(self, 'label'):
            self.label.set_text(self.wallpapers[self.current_index])

    def on_key_press(self, widget, event):
        keyval = event.keyval
        if keyval == Gdk.KEY_Left:
            self.current_index = (self.current_index - 1) % len(self.wallpapers)
            self.update_carousel()
        elif keyval == Gdk.KEY_Right:
            self.current_index = (self.current_index + 1) % len(self.wallpapers)
            self.update_carousel()
        elif keyval in [Gdk.KEY_Return, Gdk.KEY_KP_Enter]:
            self.apply_wallpaper()
        elif keyval == Gdk.KEY_Escape:
            Gtk.main_quit()

    def apply_wallpaper(self):
        wp_path = os.path.join(WALLPAPER_DIR, self.wallpapers[self.current_index])
        
        # Lógica de cambio sin parpadeo
        subprocess.Popen([SWAYBG_PATH, "-i", wp_path, "-m", "fill"])
        
        # Matamos los antiguos tras un breve delay
        GLib.timeout_add(500, self.cleanup_old_swaybg)
        
        # Notificar y salir
        subprocess.run(["notify-send", "Wallpaper", f"Cambiado a {self.wallpapers[self.current_index]}"])
        Gtk.main_quit()

    def cleanup_old_swaybg(self):
        # Buscamos el PID más reciente para NO matarlo
        try:
            pids = subprocess.check_output(["pgrep", "swaybg"]).decode().split()
            if len(pids) > 1:
                # Matamos todos menos el último (el más nuevo)
                newest = pids[-1]
                for pid in pids[:-1]:
                    os.kill(int(pid), signal.SIGTERM)
        except:
            pass
        return False

if __name__ == "__main__":
    win = WallpaperCarousel()
    Gtk.main()
