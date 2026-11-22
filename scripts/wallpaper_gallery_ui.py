#!/usr/bin/env python3
"""GTK3/Cairo presentation layer for the TQQ wallpaper gallery."""
from __future__ import annotations

import math
from collections import OrderedDict
from pathlib import Path
from typing import Callable

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
try:
    # Registers the cairo.Context converter used by GTK's DrawingArea "draw" signal.
    gi.require_foreign("cairo")
except ImportError as error:
    raise RuntimeError(
        "GTK's Cairo bridge is missing. Install python3-gi-cairo on Debian/Ubuntu "
        "or the equivalent PyGObject Cairo integration package for your distribution."
    ) from error

import cairo
from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk, Pango, PangoCairo

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
APP_ID = "io.github.tqqniri.WallpaperGallery"
BG = (0.055, 0.055, 0.075)
FG = (0.95, 0.94, 0.98)
ACCENT = (0.78, 0.55, 0.96)


def label_for(path: Path) -> str:
    return path.stem.replace("_", " ").replace("-", " ").strip().title()


def rounded_rectangle(cr, x, y, width, height, radius):
    radius = min(radius, width / 2, height / 2)
    cr.new_sub_path()
    cr.arc(x + width - radius, y + radius, radius, -math.pi / 2, 0)
    cr.arc(x + width - radius, y + height - radius, radius, 0, math.pi / 2)
    cr.arc(x + radius, y + height - radius, radius, math.pi / 2, math.pi)
    cr.arc(x + radius, y + radius, radius, math.pi, math.pi * 1.5)
    cr.close_path()


def set_source_rgba(cr, color, alpha=1.0):
    cr.set_source_rgba(color[0], color[1], color[2], alpha)


class WallpaperGallery(Gtk.ApplicationWindow):
    """Draws the cover-flow interface and reports the selected image."""

    def __init__(
        self,
        application: Gtk.Application,
        images: list[Path],
        current: Path | None,
        on_apply: Callable[[Path], None],
    ):
        super().__init__(application=application, title="TQQ Wallpaper Gallery")
        self.images = images
        self.on_apply = on_apply
        self.index = next((i for i, image in enumerate(images) if image == current), 0)
        self.cache: OrderedDict[Path, GdkPixbuf.Pixbuf] = OrderedDict()
        self.hit_boxes = []
        self.palette = []
        self.set_decorated(False)
        self.set_resizable(True)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_default_size(1120, 720)
        self.set_size_request(680, 480)
        self.connect("key-press-event", self.on_key)

        screen = Gdk.Screen.get_default()
        if screen:
            provider = Gtk.CssProvider()
            provider.load_from_data(b"""
                window { background: #101018; color: #f2eff8; }
                label { color: #f2eff8; }
            """)
            Gtk.StyleContext.add_provider_for_screen(
                screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

        self.area = Gtk.DrawingArea()
        self.area.set_can_focus(True)
        self.area.set_hexpand(True)
        self.area.set_vexpand(True)
        self.add(self.area)
        self.area.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.BUTTON_PRESS_MASK)
        self.area.connect("draw", self.draw)
        self.area.connect("scroll-event", self.on_scroll)
        self.area.connect("button-press-event", self.on_click)
        self.show_all()
        self.area.grab_focus()

    def get_pixbuf(self, path: Path):
        if path in self.cache:
            self.cache.move_to_end(path)
            return self.cache[path]
        try:
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(path), 720, 480, True)
        except GLib.Error as error:
            print(f"Cannot load {path}: {error}", file=__import__("sys").stderr)
            return None
        self.cache[path] = pixbuf
        while len(self.cache) > 13:
            self.cache.popitem(last=False)
        return pixbuf

    def get_palette(self, pixbuf):
        if pixbuf is None:
            return [ACCENT] * 5
        width, height = pixbuf.get_width(), pixbuf.get_height()
        pixels = pixbuf.get_pixels()
        channels, stride = pixbuf.get_n_channels(), pixbuf.get_rowstride()
        colors = []
        for fraction in (0.12, 0.30, 0.50, 0.70, 0.88):
            x, y = int(width * fraction), int(height * 0.48)
            offset = y * stride + x * channels
            rgb = tuple(pixels[offset + i] / 255 for i in range(3))
            colors.append(tuple(0.18 + component * 0.82 for component in rgb))
        return colors

    def draw_text(self, cr, text, x, y, size, color=FG, weight=Pango.Weight.NORMAL, align=0):
        layout = PangoCairo.create_layout(cr)
        desc = Pango.FontDescription()
        desc.set_family("JetBrainsMono Nerd Font")
        desc.set_size(int(size * Pango.SCALE))
        desc.set_weight(weight)
        layout.set_font_description(desc)
        layout.set_text(text, -1)
        if align:
            layout.set_alignment(Pango.Alignment.CENTER)
            text_width, _text_height = layout.get_pixel_size()
            x = (self.area.get_allocation().width - text_width) / 2
        cr.move_to(x, y)
        set_source_rgba(cr, color)
        PangoCairo.show_layout(cr, layout)

    def draw_card(self, cr, path, center_x, center_y, width, height, angle, alpha, selected):
        pixbuf = self.get_pixbuf(path)
        cr.save()
        cr.translate(center_x, center_y)
        cr.rotate(angle)
        cr.scale(1.0 if selected else 0.96, 1.0 if selected else 0.96)
        x, y = -width / 2, -height / 2

        rounded_rectangle(cr, x - 3, y + 12, width + 6, height + 8, 19)
        cr.set_source_rgba(0, 0, 0, 0.52 * alpha)
        cr.fill()
        rounded_rectangle(cr, x - 1, y - 1, width + 2, height + 2, 19)
        cr.set_source_rgba(ACCENT[0], ACCENT[1], ACCENT[2], (0.9 if selected else 0.22) * alpha)
        cr.fill()

        rounded_rectangle(cr, x, y, width, height, 18)
        cr.clip()
        if pixbuf:
            pw, ph = pixbuf.get_width(), pixbuf.get_height()
            scale = max(width / pw, height / ph)
            dw, dh = pw * scale, ph * scale
            cr.translate(-dw / 2, -dh / 2)
            cr.scale(scale, scale)
            Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0)
            cr.paint_with_alpha(alpha)
        else:
            cr.set_source_rgb(0.16, 0.15, 0.20)
            cr.paint()
        cr.restore()

    def draw(self, _area, cr):
        allocation = self.area.get_allocation()
        w, h = allocation.width, allocation.height
        cr.set_source_rgb(*BG)
        cr.paint()

        pattern = cairo.RadialGradient(w * 0.5, h * 0.48, 10, w * 0.5, h * 0.48, w * 0.48)
        pattern.add_color_stop_rgba(0, 0.36, 0.20, 0.48, 0.20)
        pattern.add_color_stop_rgba(1, 0.055, 0.055, 0.075, 0)
        cr.set_source(pattern)
        cr.paint()

        self.draw_text(cr, "TQQ  /  WALLPAPER GALLERY", 42, 30, 13, ACCENT, Pango.Weight.BOLD)
        self.draw_text(cr, "Choose your next desktop atmosphere", 42, 55, 11, (0.62, 0.60, 0.69))
        self.draw_text(cr, f"{self.index + 1:02d}  /  {len(self.images):02d}", w - 118, 36, 12, (0.72, 0.70, 0.78))

        center_y = h * 0.49
        center_x = w * 0.5
        base_w = min(560, w * 0.48)
        base_h = min(350, h * 0.49)
        self.hit_boxes = []

        offsets = list(range(-3, 4))
        offsets.sort(key=lambda offset: abs(offset), reverse=True)
        for offset in offsets:
            idx = (self.index + offset) % len(self.images)
            if len(self.images) > 1 and abs(offset) >= len(self.images):
                continue
            distance = abs(offset)
            card_w = base_w * (1.0 if offset == 0 else max(0.55, 0.78 - distance * 0.035))
            card_h = base_h * (1.0 if offset == 0 else max(0.62, 0.82 - distance * 0.025))
            spacing = min(205, w * 0.19)
            x = center_x + offset * spacing
            angle = 0 if offset == 0 else (-0.24 if offset < 0 else 0.24)
            alpha = 1.0 if offset == 0 else max(0.55, 0.94 - distance * 0.12)
            self.draw_card(cr, self.images[idx], x, center_y, card_w, card_h, angle, alpha, offset == 0)
            if abs(offset) <= 1:
                self.hit_boxes.append((x - card_w / 2, center_y - card_h / 2, card_w, card_h, idx))

        current = self.images[self.index]
        self.draw_text(cr, label_for(current), 0, h * 0.79, 19, FG, Pango.Weight.BOLD, align=1)
        self.draw_text(cr, current.name, 0, h * 0.79 + 30, 10, (0.62, 0.60, 0.69), align=1)

        self.palette = self.get_palette(self.get_pixbuf(current))
        swatch_size, gap = 18, 12
        total = len(self.palette) * swatch_size + (len(self.palette) - 1) * gap
        start = (w - total) / 2
        for i, color in enumerate(self.palette):
            rounded_rectangle(cr, start + i * (swatch_size + gap), h * 0.87, swatch_size, swatch_size, 6)
            set_source_rgba(cr, color)
            cr.fill()

        self.draw_text(cr, "← / →  browse     scroll  browse     enter  apply     esc  close", 0, h - 35, 10, (0.58, 0.56, 0.65), align=1)
        return False

    def step(self, amount):
        self.index = (self.index + amount) % len(self.images)
        self.area.queue_draw()

    def on_key(self, _widget, event):
        if event.keyval in (Gdk.KEY_Left, Gdk.KEY_h):
            self.step(-1)
        elif event.keyval in (Gdk.KEY_Right, Gdk.KEY_l):
            self.step(1)
        elif event.keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            self.apply()
        elif event.keyval == Gdk.KEY_Escape:
            self.destroy()
        elif event.keyval == Gdk.KEY_Home:
            self.index = 0
            self.area.queue_draw()
        else:
            return False
        return True

    def on_scroll(self, _widget, event):
        if event.direction == Gdk.ScrollDirection.UP:
            self.step(-1)
        elif event.direction == Gdk.ScrollDirection.DOWN:
            self.step(1)
        elif event.direction == Gdk.ScrollDirection.SMOOTH:
            _dx, dy = event.get_scroll_deltas()[1:]
            if abs(dy) > 0.15:
                self.step(1 if dy > 0 else -1)
        return True

    def on_click(self, _widget, event):
        if event.button == 1:
            for x, y, width, height, idx in reversed(self.hit_boxes):
                if x <= event.x <= x + width and y <= event.y <= y + height:
                    if idx == self.index:
                        self.apply()
                    else:
                        self.index = idx
                        self.area.queue_draw()
                    return True
        return False

    def apply(self):
        self.on_apply(self.images[self.index])
        self.destroy()


def run_gallery(images: list[Path], current: Path | None) -> int:
    app = Gtk.Application(application_id=APP_ID, flags=Gio.ApplicationFlags.NON_UNIQUE)

    def activate(application):
        WallpaperGallery(
            application,
            images,
            current,
            lambda path: print(path, flush=True),
        )

    app.connect("activate", activate)
    return app.run([])
