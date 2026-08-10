#!/usr/bin/env python3
import subprocess
import json
import urllib.request
import sys
import os

# Import GTK
try:
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, Gdk, Pango
except ImportError:
    print("GTK no disponible, usando notificaciones.")
    Gtk = None

# Configuration
MODEL = "qwen2.5:1.5b"
OLLAMA_URL = "http://localhost:11434/api/generate"

def get_selected_text():
    try:
        # Get the primary selection (highlighted text)
        result = subprocess.run(['wl-paste', '-p'], capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        # Fallback to clipboard if primary is empty
        try:
            result = subprocess.run(['wl-paste'], capture_output=True, text=True, check=True)
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            return None

def translate_text(text):
    if not text:
        return "No hay texto seleccionado."
    
    prompt = f"Translate to Spanish. Output only the translation:\n\n{text}"
    data = {"model": MODEL, "prompt": prompt, "stream": False}
    
    try:
        req = urllib.request.Request(
            OLLAMA_URL, 
            data=json.dumps(data).encode('utf-8'), 
            headers={'Content-Type': 'application/json'}
        )
        with urllib.request.urlopen(req, timeout=30) as response:
            res_data = json.loads(response.read().decode('utf-8'))
            return res_data.get("response", "Error: No response").strip()
    except Exception as e:
        return f"Error: {e}"

def get_colors():
    cache_file = os.path.expanduser("~/.cache/wallust/colors.json")
    c = {
        "bg": "#282828",
        "fg": "#ebdbb2",
        "orange": "#fe8019",
        "yellow": "#fabd2f",
        "bg2": "#3c3836"
    }
    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r") as f:
                w = json.load(f)
                cl = w['colors']
                c.update({
                    "bg": w['background'],
                    "fg": w['foreground'],
                    "orange": cl['color9'],
                    "yellow": cl['color3'],
                    "bg2": cl['color8']
                })
        except Exception:
            pass
    return c

class TranslationWindow(Gtk.Window):
    def __init__(self, original, translation):
        super().__init__(title="Traducción")
        self.set_border_width(15)
        self.set_default_size(400, 200)
        self.set_keep_above(True)
        self.set_position(Gtk.WindowPosition.CENTER)
        
        # Style (Gruvbox-ish / Wallust dynamic)
        colors = get_colors()
        style_provider = Gtk.CssProvider()
        css = f"""
        window {{ background-color: {colors['bg']}; color: {colors['fg']}; border-radius: 10px; border: 2px solid {colors['orange']}; }}
        label {{ font-size: 14px; }}
        .title {{ color: {colors['yellow']}; font-weight: bold; margin-bottom: 5px; }}
        """
        style_provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            style_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.add(vbox)

        # Original label
        orig_title = Gtk.Label(label="Original:")
        orig_title.get_style_context().add_class("title")
        orig_title.set_xalign(0)
        vbox.pack_start(orig_title, False, False, 0)

        orig_label = Gtk.Label(label=original)
        orig_label.set_line_wrap(True)
        orig_label.set_xalign(0)
        vbox.pack_start(orig_label, False, False, 0)

        # Separator
        vbox.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 5)

        # Translation label
        trans_title = Gtk.Label(label="Traducción:")
        trans_title.get_style_context().add_class("title")
        trans_title.set_xalign(0)
        vbox.pack_start(trans_title, False, False, 0)

        trans_label = Gtk.Label(label=translation)
        trans_label.set_line_wrap(True)
        trans_label.set_xalign(0)
        vbox.pack_start(trans_label, False, False, 0)

        self.connect("key-press-event", self.on_key_press)
        self.connect("focus-out-event", lambda w, e: self.destroy())
        self.show_all()

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()

def notify(text):
    subprocess.run(['notify-send', '-a', 'Traductor IA', 'Traduciendo...'])

if __name__ == "__main__":
    text = get_selected_text()
    if not text:
        subprocess.run(['notify-send', 'Traductor', 'Selecciona texto primero'])
        sys.exit(0)

    notify("Procesando...")
    translation = translate_text(text)

    if Gtk:
        window = TranslationWindow(text, translation)
        window.connect("destroy", Gtk.main_quit)
        Gtk.main()
    else:
        subprocess.run(['notify-send', '-a', 'Traducción', translation])
