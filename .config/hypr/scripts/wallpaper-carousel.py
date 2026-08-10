#!/usr/bin/env python3

import os
import gi
import subprocess
import signal
import json
import random
import colorsys
from PIL import Image

gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, Gdk, GdkPixbuf, GtkLayerShell, GLib

WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")
CACHE_FILE = os.path.expanduser("~/.cache/wallust/colors.json")
COLOR_METADATA = os.path.expanduser("~/.cache/wallpaper_colors.json")

# Definición de rangos de color (Hue en grados 0-360)
# Refinado para mejor precisión
COLOR_RANGES = {
    "Red": (0, 15, 345, 360),
    "Orange": (15, 45),
    "Yellow": (45, 70),
    "Green": (70, 165),
    "Blue": (165, 255),
    "Purple": (255, 300),
    "Pink": (300, 345),
}

COLOR_FILTERS = [
    ("All", "all", "#ffffff"),
    ("Red", "Red", "#ff5555"),
    ("Orange", "Orange", "#ffb86c"),
    ("Yellow", "Yellow", "#f1fa8c"),
    ("Green", "Green", "#50fa7b"),
    ("Blue", "Blue", "#8be9fd"),
    ("Purple", "Purple", "#bd93f9"),
    ("Pink", "Pink", "#ff79c6"),
    ("Dark", "Dark", "#282a36"),
]

def get_dominant_color_category(image_path):
    try:
        img = Image.open(image_path)
        img = img.convert('RGB')
        img.thumbnail((100, 100)) # Mayor resolución para mejor análisis
        
        pixels = list(img.getdata())
        # Muestra más grande para precisión
        sample_size = min(len(pixels), 300)
        sample = random.sample(pixels, sample_size)
        
        h_scores = {cat: 0 for cat in COLOR_RANGES}
        dark_count = 0
        vibrant_count = 0
        
        for r, g, b in sample:
            h, s, v = colorsys.rgb_to_hsv(r/255., g/255., b/255.)
            hue = h * 360
            
            # Clasificación de brillo/saturación
            if v < 0.2 or (s < 0.2 and v < 0.5):
                dark_count += 1
                continue
            
            if s > 0.3:
                vibrant_count += 1
                # Dar peso al color basado en su saturación y brillo
                weight = s * v
                for cat, ranges in COLOR_RANGES.items():
                    if len(ranges) == 2:
                        if ranges[0] <= hue <= ranges[1]: h_scores[cat] += weight
                    else:
                        if ranges[0] <= hue <= ranges[1] or ranges[2] <= hue <= ranges[3]: h_scores[cat] += weight

        if dark_count > (sample_size * 0.6): return "Dark"
        
        best_cat = max(h_scores, key=h_scores.get)
        if h_scores[best_cat] == 0: return "Dark" if dark_count > (sample_size * 0.3) else "All"
        
        return best_cat
    except:
        return "All"

def get_colors():
    c = {"bg": "#0E1011", "fg": "#FFF3DC", "accent": "#0E8ED7", "accent2": "#B08599", "bg_alt": "#373939"}
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                w = json.load(f)
                cl = w['colors']
                c.update({
                    "bg": w['background'], "fg": w['foreground'],
                    "accent": cl['color9'], "accent2": cl['color5'], "bg_alt": cl['color0']
                })
        except: pass
    return c

def hex_to_rgba(hex_color, alpha):
    hex_color = hex_color.lstrip('#')
    if len(hex_color) == 8: hex_color = hex_color[:6]
    lv = len(hex_color)
    rgb = tuple(int(hex_color[i:i + lv // 3], 16) for i in range(0, lv, lv // 3))
    return f"rgba({rgb[0]}, {rgb[1]}, {rgb[2]}, {alpha})"

class WallpaperCarousel(Gtk.Window):
    def __init__(self):
        super().__init__(title="Wallpaper Carousel")
        
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)

        self.colors = get_colors()
        self.wp_metadata = self.load_metadata()
        
        self.all_wallpapers = []
        for f in os.listdir(WALLPAPER_DIR):
            if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                self.all_wallpapers.append(f)
        self.all_wallpapers.sort()
        
        self.filtered_wallpapers = list(self.all_wallpapers)
        self.current_index = 0
        self.active_filter = "All"

        overlay = Gtk.Overlay()
        self.add(overlay)

        # Main vertical container with fixed width to prevent search bar explosion
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=25)
        vbox.set_valign(Gtk.Align.CENTER)
        vbox.set_halign(Gtk.Align.CENTER)
        vbox.set_size_request(1200, -1) 
        overlay.add(vbox)

        # Search Bar - Wrapped in another box to control size strictly
        search_wrap = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        search_wrap.set_halign(Gtk.Align.CENTER)
        self.search_entry = Gtk.Entry()
        self.search_entry.set_placeholder_text("🔍 Buscar por nombre...")
        self.search_entry.set_name("search-entry")
        self.search_entry.set_width_chars(40) # Limitar ancho por caracteres
        self.search_entry.set_max_length(50)
        self.search_entry.connect("changed", self.on_search_changed)
        search_wrap.pack_start(self.search_entry, False, False, 0)
        vbox.pack_start(search_wrap, False, False, 0)

        # Palette
        palette_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        palette_box.set_halign(Gtk.Align.CENTER)
        vbox.pack_start(palette_box, False, False, 0)

        self.filter_buttons = {}
        for name, tag, color in COLOR_FILTERS:
            btn = Gtk.Button()
            btn.set_tooltip_text(name)
            btn.get_style_context().add_class("palette-btn")
            if name == "All": btn.get_style_context().add_class("palette-btn-active")
            
            circle = Gtk.Box()
            circle.set_size_request(24, 24)
            circle.set_name(f"circle-{name.lower()}")
            btn.add(circle)
            
            btn.connect("clicked", self.on_filter_clicked, name)
            palette_box.pack_start(btn, False, False, 0)
            self.filter_buttons[name] = btn

        # Carousel Container
        self.carousel_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=40)
        self.carousel_box.set_halign(Gtk.Align.CENTER)
        vbox.pack_start(self.carousel_box, True, True, 10)

        hints = Gtk.Label(label="[ Enter ] Aplicar   [ ← / → ] Navegar   [ Esc ] Salir")
        hints.set_name("hints-label")
        vbox.pack_start(hints, False, False, 0)

        self.update_carousel()
        self.apply_styles()

        self.connect("key-press-event", self.on_key_press)
        self.connect("scroll-event", self.on_scroll_event)
        self.show_all()
        self.search_entry.grab_focus()

    def on_scroll_event(self, widget, event):
        if not self.filtered_wallpapers: return False
        
        # Debounce scroll to avoid hypersensitivity
        if event.direction == Gdk.ScrollDirection.UP or event.delta_y < 0:
            self.navigate(-1)
        elif event.direction == Gdk.ScrollDirection.DOWN or event.delta_y > 0:
            self.navigate(1)
        return True

    def navigate(self, direction):
        self.current_index = (self.current_index + direction) % len(self.filtered_wallpapers)
        # Use idle_add to keep UI buttery smooth during image loading
        GLib.idle_add(self.update_carousel)

    def load_metadata(self):
        if os.path.exists(COLOR_METADATA):
            try:
                with open(COLOR_METADATA, "r") as f:
                    return json.load(f)
            except: pass
        return {}

    def save_metadata(self):
        try:
            with open(COLOR_METADATA, "w") as f:
                json.dump(self.wp_metadata, f)
        except: pass

    def on_filter_clicked(self, btn, name):
        for b in self.filter_buttons.values():
            b.get_style_context().remove_class("palette-btn-active")
        
        self.active_filter = name
        btn.get_style_context().add_class("palette-btn-active")
        self.filter_wallpapers()

    def on_search_changed(self, entry):
        self.filter_wallpapers()

    def filter_wallpapers(self):
        query = self.search_entry.get_text().lower()
        temp_list = [w for w in self.all_wallpapers if query in w.lower()]
        
        if self.active_filter != "All":
            final_list = []
            for w in temp_list:
                if w not in self.wp_metadata:
                    self.wp_metadata[w] = get_dominant_color_category(os.path.join(WALLPAPER_DIR, w))
                    self.save_metadata()
                if self.wp_metadata[w] == self.active_filter:
                    final_list.append(w)
            self.filtered_wallpapers = final_list
        else:
            self.filtered_wallpapers = temp_list
            
        self.current_index = 0
        self.update_carousel()

    def apply_styles(self):
        style_provider = Gtk.CssProvider()
        bg_main = hex_to_rgba(self.colors['bg'], 0.92)
        accent = self.colors['accent']
        accent2 = self.colors['accent2']
        fg = self.colors['fg']
        bg_alt = hex_to_rgba(self.colors['bg_alt'], 0.6)

        css_base = f"""
        window {{ background-color: {bg_main}; }}
        #search-entry {{
            background-color: {bg_alt};
            color: {fg};
            border: 2px solid {accent};
            border-radius: 25px;
            padding: 8px 25px;
            font-size: 18px;
            font-family: "JetBrains Mono", sans-serif;
            min-width: 400px;
        }}
        .palette-btn {{
            background: {bg_alt};
            border: 2px solid transparent;
            border-radius: 50%;
            padding: 8px;
        }}
        .palette-btn-active {{
            background: {hex_to_rgba(accent, 0.4)};
            border: 2px solid {accent};
            box-shadow: 0 0 10px {accent};
        }}
        .wp-item {{
            border: 4px solid {bg_alt};
            border-radius: 30px;
        }}
        .wp-item-selected {{
            border: 6px solid {accent};
            box-shadow: 0 0 30px {accent};
        }}
        #hints-label {{ color: {fg}; font-size: 15px; font-weight: 800; opacity: 0.6; }}
        """
        for name, tag, color in COLOR_FILTERS:
            css_base += f"#circle-{name.lower()} {{ background-color: {color}; border-radius: 50%; }}\n"

        style_provider.load_from_data(css_base.encode())
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def update_carousel(self):
        for child in self.carousel_box.get_children(): self.carousel_box.remove(child)
        if not self.filtered_wallpapers:
            no_res = Gtk.Label(label="(×﹏×) Sin resultados")
            no_res.set_name("hints-label")
            self.carousel_box.add(no_res)
            self.carousel_box.show_all()
            return
        
        count = len(self.filtered_wallpapers)
        # Fix: Prevent duplication when results are fewer than the display offset
        display_offsets = [-2, -1, 0, 1, 2]
        
        for offset in display_offsets:
            if count <= abs(offset) and count > 0:
                # If only 1 result, only show the center (offset 0)
                if count == 1 and offset != 0: continue
                # If 2 results, only show center and immediate neighbors if appropriate
                if count == 2 and abs(offset) > 1: continue

            idx = (self.current_index + offset) % count
            wp_path = os.path.join(WALLPAPER_DIR, self.filtered_wallpapers[idx])
            
            box = Gtk.Box()
            box.get_style_context().add_class("wp-item")
            
            if offset == 0:
                box.get_style_context().add_class("wp-item-selected")
                w, h = 680, 382
            elif abs(offset) == 1: 
                w, h = 420, 236; 
                box.set_opacity(0.5)
            else: 
                w, h = 260, 146; 
                box.set_opacity(0.2)
            
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(wp_path, w, h, True)
                image = Gtk.Image.new_from_pixbuf(pixbuf)
                box.add(image)
            except: pass
            self.carousel_box.pack_start(box, False, False, 0)
        
        self.carousel_box.show_all()

    def on_key_press(self, widget, event):
        keyval = event.keyval
        if not self.filtered_wallpapers: return False
        
        if keyval == Gdk.KEY_Left:
            self.navigate(-1)
            return True
        elif keyval == Gdk.KEY_Right:
            self.navigate(1)
            return True
        elif keyval in [Gdk.KEY_Return, Gdk.KEY_KP_Enter]:
            self.apply_wallpaper()
            return True
        elif keyval == Gdk.KEY_Escape:
            Gtk.main_quit()
            return True
        return False

    def apply_wallpaper(self):
        if not self.filtered_wallpapers: return
        wp_path = os.path.join(WALLPAPER_DIR, self.filtered_wallpapers[self.current_index])
        subprocess.Popen([os.path.expanduser("~/dotfiles/scripts/change_wallpaper.sh"), wp_path])
        Gtk.main_quit()

if __name__ == "__main__":
    win = WallpaperCarousel()
    Gtk.main()
