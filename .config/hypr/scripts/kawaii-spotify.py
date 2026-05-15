#!/usr/bin/env python3

import gi
import sys
import subprocess
import signal
import random
import math
gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, GtkLayerShell, GLib, Gdk

EQ_BARS = 8

class KawaiiSpotify(Gtk.Window):
    def __init__(self):
        super().__init__()

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 40)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 40)

        css_provider = Gtk.CssProvider()
        css = b"""
        window {
            background-color: rgba(40, 40, 40, 0.88);
            border: 2px solid #fe8019;
            border-radius: 20px;
        }
        .title-label {
            font-size: 14px;
            font-weight: 900;
            color: #fe8019;
            margin-bottom: 4px;
            font-family: "JetBrains Mono", "Fira Code", monospace;
        }
        .song {
            font-size: 16px;
            font-weight: 900;
            color: #fabd2f;
            font-family: "JetBrains Mono", "Fira Code", monospace;
        }
        .artist {
            font-size: 12px;
            font-weight: 600;
            color: #a89984;
            font-family: "JetBrains Mono", "Fira Code", monospace;
        }
        .face {
            font-size: 16px;
            font-weight: bold;
            color: #d3869b;
            font-family: "JetBrains Mono", "Fira Code", monospace;
        }
        .nada {
            font-size: 13px;
            font-weight: 600;
            color: #928374;
            font-family: "JetBrains Mono", "Fira Code", monospace;
        }
        button {
            background: rgba(60, 56, 54, 0.8);
            border: none;
            border-radius: 10px;
            padding: 6px 12px;
            font-size: 18px;
            color: #ebdbb2;
            font-family: "JetBrains Mono", "Fira Code", monospace;
        }
        button:hover {
            background: rgba(254, 128, 25, 0.5);
            color: #282828;
        }
        """
        css_provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.main_box.set_border_width(18)
        self.add(self.main_box)

        titulo = Gtk.Label(label="Music")
        titulo.get_style_context().add_class("title-label")
        titulo.set_halign(Gtk.Align.CENTER)
        self.main_box.pack_start(titulo, False, False, 4)

        self.face = Gtk.Label(label="( ˘ ɜ˘) ♬♪♫")
        self.face.get_style_context().add_class("face")
        self.face.set_halign(Gtk.Align.CENTER)
        self.main_box.pack_start(self.face, False, False, 0)

        # --- Equalizador ---
        self.eq_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=3)
        self.eq_box.set_halign(Gtk.Align.CENTER)
        self.eq_box.set_size_request(-1, 36)
        self.eq_bars = []
        for i in range(EQ_BARS):
            bar = Gtk.ProgressBar()
            bar.set_orientation(Gtk.Orientation.VERTICAL)
            bar.set_inverted(True)
            bar.set_size_request(14, 36)
            bar.set_valign(Gtk.Align.END)
            # Color alternando amarillo y naranja gruvbox
            bar_context = bar.get_style_context()
            bar_context.add_class("eq-bar")
            self.eq_bars.append(bar)
            self.eq_box.pack_start(bar, False, False, 0)
        self.main_box.pack_start(self.eq_box, False, False, 4)

        self.song_label = Gtk.Label(label="─ Nada sonando ─")
        self.song_label.get_style_context().add_class("nada")
        self.song_label.set_halign(Gtk.Align.CENTER)
        self.song_label.set_max_width_chars(28)
        self.song_label.set_ellipsize(3)
        self.main_box.pack_start(self.song_label, False, False, 0)

        self.artist_label = Gtk.Label(label="")
        self.artist_label.get_style_context().add_class("artist")
        self.artist_label.set_halign(Gtk.Align.CENTER)
        self.artist_label.set_max_width_chars(28)
        self.artist_label.set_ellipsize(3)
        self.main_box.pack_start(self.artist_label, False, False, 4)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        btn_box.set_halign(Gtk.Align.CENTER)

        self.btn_prev = Gtk.Button(label="⏮")
        self.btn_prev.connect("clicked", self.cmd_prev)
        btn_box.pack_start(self.btn_prev, False, False, 0)

        self.btn_play = Gtk.Button(label="⏯")
        self.btn_play.connect("clicked", self.cmd_playpause)
        btn_box.pack_start(self.btn_play, False, False, 0)

        self.btn_next = Gtk.Button(label="⏭")
        self.btn_next.connect("clicked", self.cmd_next)
        btn_box.pack_start(self.btn_next, False, False, 0)

        self.main_box.pack_start(btn_box, False, False, 2)

        # Inyectar CSS dinámico para las barras del equalizador
        self._inject_eq_css()

        self._has_music = False
        self._anim_frame = 0
        self._eq_heights = [0.0] * EQ_BARS
        self._eq_speeds = [random.uniform(0.04, 0.12) for _ in range(EQ_BARS)]
        self._eq_phases = [random.uniform(0, math.pi * 2) for _ in range(EQ_BARS)]

        self.update_player()
        GLib.timeout_add(2000, self.update_player)
        GLib.timeout_add(50, self.animate_eq)

    def _inject_eq_css(self):
        # Asignar colores alternados a las barras
        for i, bar in enumerate(self.eq_bars):
            color = "#fabd2f" if i % 2 == 0 else "#fe8019"
            css = f"""
            .eq-bar-i{i} trough {{
                background-color: #3c3836;
                border-radius: 4px;
                min-width: 14px;
            }}
            .eq-bar-i{i} progress {{
                background-color: {color};
                border-radius: 4px;
            }}
            """.encode()
            provider = Gtk.CssProvider()
            provider.load_from_data(css)
            ctx = bar.get_style_context()
            ctx.add_provider(provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            ctx.add_class(f"eq-bar-i{i}")

    def get_player_status(self):
        try:
            status = subprocess.check_output(
                ["playerctl", "status"], stderr=subprocess.DEVNULL
            ).decode().strip()
        except:
            return None, None, None
        try:
            title = subprocess.check_output(
                ["playerctl", "metadata", "title"], stderr=subprocess.DEVNULL
            ).decode().strip()
        except:
            title = ""
        try:
            artist = subprocess.check_output(
                ["playerctl", "metadata", "artist"], stderr=subprocess.DEVNULL
            ).decode().strip()
        except:
            artist = ""
        return status, title, artist

    def cmd_prev(self, btn):
        subprocess.run(["playerctl", "previous"], stderr=subprocess.DEVNULL)

    def cmd_playpause(self, btn):
        subprocess.run(["playerctl", "play-pause"], stderr=subprocess.DEVNULL)

    def cmd_next(self, btn):
        subprocess.run(["playerctl", "next"], stderr=subprocess.DEVNULL)

    def update_player(self):
        status, title, artist = self.get_player_status()
        has_music = bool(status and title)

        if not has_music:
            self.song_label.set_text("─ Nada sonando ─")
            self.song_label.get_style_context().remove_class("song")
            self.song_label.get_style_context().add_class("nada")
            self.artist_label.set_text("")
            self.face.set_text("( ˘ ɜ˘) ♬♪♫")
            self.btn_play.set_label("▶")
            self.eq_box.hide()
            self._has_music = False
            return True

        if not self._has_music:
            self.eq_box.show()
            self._has_music = True

        self.song_label.set_text(title)
        self.song_label.get_style_context().remove_class("nada")
        self.song_label.get_style_context().add_class("song")
        self.artist_label.set_text(artist or "Artista desconocido")

        if status == "Playing":
            self.face.set_text("♪♪(o*゜∇゜)o～♪♪")
            self.btn_play.set_label("⏸")
        else:
            self.face.set_text("( ˘ ɜ˘) ♬♪♫")
            self.btn_play.set_label("▶")

        return True

    def animate_eq(self):
        if not self._has_music:
            self._anim_frame += 1
            return True

        self._anim_frame += 1
        t = self._anim_frame * 0.05  # tiempo base

        for i, bar in enumerate(self.eq_bars):
            # Onda sinusoidal con fase y velocidad únicas por barra
            wave = math.sin(t * self._eq_speeds[i] * 3 + self._eq_phases[i])
            # Segunda onda para más variación
            wave2 = math.cos(t * self._eq_speeds[i] * 5 + self._eq_phases[i] * 2)
            # Tercera onda rápida (detalle)
            wave3 = math.sin(t * self._eq_speeds[i] * 8 + self._eq_phases[i] * 3)

            # Combinar ondas y normalizar a 0-1
            height = abs(wave * 0.5 + wave2 * 0.3 + wave3 * 0.2)
            # Suavizar con frame anterior
            self._eq_heights[i] = self._eq_heights[i] * 0.7 + height * 0.3
            # Asegurar un mínimo para que no quede vacío
            bar.set_fraction(0.1 + self._eq_heights[i] * 0.9)

        return True

if __name__ == "__main__":
    signal.signal(signal.SIGINT, lambda s, f: (Gtk.main_quit(), sys.exit(0)))
    app = KawaiiSpotify()
    app.show_all()
    app.eq_box.hide()
    Gtk.main()
