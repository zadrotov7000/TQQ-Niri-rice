#!/usr/bin/env python3
"""Wallpaper picker controller: find images, launch the gallery, return selection."""
from __future__ import annotations

import sys
from pathlib import Path

from wallpaper_gallery_ui import run_gallery

EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} WALLPAPER_DIR CURRENT_WALLPAPER_FILE", file=sys.stderr)
        return 2

    wallpaper_dir = Path(sys.argv[1]).expanduser()
    state_file = Path(sys.argv[2]).expanduser()
    if not wallpaper_dir.is_dir():
        print(f"Wallpaper folder not found: {wallpaper_dir}", file=sys.stderr)
        return 1

    images = sorted(
        (
            path for path in wallpaper_dir.rglob("*")
            if path.is_file() and path.suffix.lower() in EXTENSIONS
        ),
        key=lambda path: path.name.casefold(),
    )
    if not images:
        print(f"No wallpaper images found in {wallpaper_dir}", file=sys.stderr)
        return 1

    current = None
    if state_file.is_file():
        try:
            current = Path(state_file.read_text(encoding="utf-8").strip()).expanduser()
        except OSError as error:
            print(f"Cannot read current wallpaper state: {error}", file=sys.stderr)

    try:
        return run_gallery(images, current)
    except (ImportError, RuntimeError) as error:
        print(f"Cannot start TQQ Wallpaper Gallery: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
