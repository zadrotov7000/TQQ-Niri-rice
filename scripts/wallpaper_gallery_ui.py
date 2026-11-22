#!/usr/bin/env python3
"""Transparent, animated GTK3/Cairo presentation layer for the TQQ wallpaper gallery."""
from __future__ import annotations

import math
import sys
from collections import OrderedDict
from pathlib import Path
from typing import Callable

import gi
import cairo

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")
try:
    gi.require_foreign("cairo")
except ImportError as error:
    raise RuntimeError(
        "GTK's Cairo bridge is missing. Install python3-gi-cairo on Debian/Ubuntu "
        "or the equivalent PyGObject Cairo integration package for your distribution."
    ) from error

from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk, Pango, PangoCairo

APP_ID = "io.github.tqqniri.WallpaperGallery"
FG = (0.97, 0.95, 1.0)
MUTED = (0.82, 0.80, 0.90)
ACCENT = (0.78, 0.55, 0.96)
ANIMATION_MS = 320


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
    """Draws floating wallpaper cards over a transparent window."""

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
        self.position = float(self.index)
        self.animation_start = self.position
        self.animation_target = self.position
        self.animation_started_at = 0
        self.animation_source = None

        self.cache: OrderedDict[Path, GdkPixbuf.Pixbuf] = OrderedDict()
        self.hit_boxes = []
        self.palette = []

        self.set_decorated(False)
        self.set_resizable(True)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_default_size(1120, 720)
        self.set_size_request(680, 480)
        self.set_app_paintable(True)
        self.connect("key-press-event", self.on_key)

        screen = Gdk.Screen.get_default()
        if screen:
            # Request an alpha-capable surface so the desktop remains visible
            # anywhere this window does not paint a card or a text glyph.
            rgba_visual = screen.get_rgba_visual()
            if rgba_visual is not None:
                self.set_visual(rgba_visual)

            provider = Gtk.CssProvider()
            provider.load_from_data(b"""
                window, drawingarea {
                    background-color: transparent;
                    background-image: none;
                    border: none;
                    box-shadow: none;
                }
            """)
            Gtk.StyleContext.add_provider_for_screen(
                screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

        self.area = Gtk.DrawingArea()
        self.area.set_can_focus(True)
        self.area.set_hexpand(True)
        self.area.set_vexpand(True)
        self.area.set_app_paintable(True)
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
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(path), 900, 620, True)
        except GLib.Error as error:
            print(f"Cannot load {path}: {error}", file=sys.stderr)
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

        # Small shadow keeps text readable without adding any panel behind it.
        cr.save()
        cr.move_to(x + 1, y + 2)
        cr.set_source_rgba(0.0, 0.0, 0.0, 0.58)
        PangoCairo.show_layout(cr, layout)
        cr.restore()

        cr.move_to(x, y)
        set_source_rgba(cr, color)
        PangoCairo.show_layout(cr, layout)

    def draw_card(self, cr, path, center_x, center_y, width, height, angle, alpha, focus):
        pixbuf = self.get_pixbuf(path)
        cr.save()
        cr.translate(center_x, center_y)
        cr.rotate(angle)
        x, y = -width / 2, -height / 2

        # Floating shadow and a thin accent rim; no solid card or window backdrop.
        rounded_rectangle(cr, x - 3, y + 13, width + 6, height + 8, 20)
        cr.set_source_rgba(0, 0, 0, 0.52 * alpha)
        cr.fill()

        rounded_rectangle(cr, x - 1.5, y - 1.5, width + 3, height + 3, 19)
        cr.set_source_rgba(
            ACCENT[0], ACCENT[1], ACCENT[2],
            (0.88 if focus else 0.30) * alpha,
        )
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
        cr.restore()

    def draw(self, _area, cr):
        allocation = self.area.get_allocation()
        w, h = allocation.width, allocation.height

        # Clear to transparent, not to a solid color.
        cr.save()
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.restore()

        center_x = w * 0.5
        center_y = h * 0.47
        base_w = min(590, w * 0.49)
        base_h = min(390, h * 0.52)
        spacing = min(218, w * 0.195)
        self.hit_boxes = []

        count = len(self.images)
        nearest = int(round(self.position))
        cards = []
        seen = set()
        for offset in range(-3, 4):
            idx = (nearest + offset) % count
            if idx in seen:
                continue
            seen.add(idx)
            delta = idx - self.position
            delta = (delta + count / 2) % count - count / 2
            cards.append((delta, idx))

        # Paint distant cards first so the focused image stays above them.
        cards.sort(key=lambda item: abs(item[0]), reverse=True)
        for delta, idx in cards:
            distance = abs(delta)
            focus = max(0.0, 1.0 - distance)
            scale = 0.76 + 0.24 * focus
            card_w = base_w * scale
            card_h = base_h * (0.82 + 0.18 * focus)
            x = center_x + delta * spacing
            angle = max(-0.34, min(0.34, delta * 0.23))
            alpha = 0.54 + 0.46 * focus
            selected = distance < 0.5
            self.draw_card(
                cr, self.images[idx], x, center_y, card_w, card_h,
                angle, alpha, selected,
            )
            if distance <= 1.15:
                self.hit_boxes.append((
                    x - card_w / 2, center_y - card_h / 2,
                    card_w, card_h, idx, selected,
                ))

        selected_index = int(round(self.position)) % count
        current = self.images[selected_index]
        self.draw_text(
            cr, label_for(current), 0, h * 0.79, 19, FG,
            Pango.Weight.BOLD, align=1,
        )
        self.draw_text(
            cr, current.name, 0, h * 0.79 + 29, 10, MUTED, align=1,
        )

        self.palette = self.get_palette(self.get_pixbuf(current))
        swatch_size, gap = 17, 11
        total = len(self.palette) * swatch_size + (len(self.palette) - 1) * gap
        start = (w - total) / 2
        for i, color in enumerate(self.palette):
            rounded_rectangle(
                cr, start + i * (swatch_size + gap), h * 0.87,
                swatch_size, swatch_size, 6,
            )
            set_source_rgba(cr, color, 0.95)
            cr.fill()

        self.draw_text(
            cr, "← / →  browse     scroll  browse     enter  apply     esc  close",
            0, h - 35, 10, MUTED, align=1,
        )
        return False

    def animate_to(self, destination):
        self.animation_start = self.position
        self.animation_target = float(destination)
        self.animation_started_at = GLib.get_monotonic_time()
        self.index = int(round(self.animation_target)) % len(self.images)
        if self.animation_source is None:
            self.animation_source = GLib.timeout_add(16, self.on_animation_frame)
        self.area.queue_draw()

    def animate_to_index(self, index):
        count = len(self.images)
        current = self.animation_target
        current_mod = current % count
        delta = (index - current_mod + count / 2) % count - count / 2
        self.animate_to(current + delta)

    def on_animation_frame(self):
        elapsed_ms = (GLib.get_monotonic_time() - self.animation_started_at) / 1000
        progress = min(1.0, elapsed_ms / ANIMATION_MS)
        eased = 1.0 - (1.0 - progress) ** 3
        self.position = (
            self.animation_start
            + (self.animation_target - self.animation_start) * eased
        )
        self.area.queue_draw()
        if progress >= 1.0:
            self.position = self.animation_target
            self.animation_source = None
            self.area.queue_draw()
            return False
        return True

    def step(self, amount):
        self.animate_to(self.animation_target + amount)

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
            self.animate_to_index(0)
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
            for x, y, width, height, idx, selected in reversed(self.hit_boxes):
                if x <= event.x <= x + width and y <= event.y <= y + height:
                    if selected:
                        self.index = idx
                        self.apply()
                    else:
                        self.animate_to_index(idx)
                    return True
        return False

    def apply(self):
        if self.animation_source is not None:
            GLib.source_remove(self.animation_source)
            self.animation_source = None
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
