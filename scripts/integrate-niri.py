#!/usr/bin/env python3
"""Migrate legacy rice leftovers and integrate TQQ startup, wallpaper, and Wi-Fi binds."""
from __future__ import annotations

from pathlib import Path
import json
import re
import shutil
import sys


def find_block_end(text: str, opening: int) -> int:
    depth = 0
    quoted = False
    escaped = False
    line_comment = False
    block_comment = False
    index = opening
    while index < len(text):
        char = text[index]
        pair = text[index:index + 2]
        if line_comment:
            if char == "\n":
                line_comment = False
        elif block_comment:
            if pair == "*/":
                block_comment = False
                index += 1
        elif quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
        elif pair == "//":
            line_comment = True
            index += 1
        elif pair == "/*":
            block_comment = True
            index += 1
        elif char == '"':
            quoted = True
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    raise ValueError("Niri config has an unclosed block")






def remove_keybindings(text: str, keys: list[str]) -> str:
    """Remove existing bindings for keys that TQQ deliberately takes over."""
    for key in keys:
        pattern = re.compile(r"(?m)^[ \t]*" + re.escape(key) + r"\b[^\n]*\{")
        match = pattern.search(text)
        while match:
            line_end = text.find("\n", match.start())
            if line_end < 0:
                line_end = len(text)
            opening = text.find("{", match.start(), line_end)
            if opening < 0:
                break
            closing = find_block_end(text, opening)
            end = closing + 1
            if end < len(text) and text[end] == "\n":
                end += 1
            text = text[:match.start()] + text[end:]
            match = pattern.search(text)
    return text

def normalize_key(key: str) -> tuple[str, ...]:
    parts = key.split("+")
    modifiers = {"Super" if part == "Mod" else "Control" if part == "Ctrl" else part for part in parts[:-1]}
    return tuple(sorted(modifiers) + [parts[-1]])


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} NIRI_CONFIG LOCAL_BIN_DIR", file=sys.stderr)
        return 2

    config_path = Path(sys.argv[1])
    local_bin = Path(sys.argv[2])
    text = config_path.read_text() if config_path.exists() else ""

    # Remove a standalone terminal-only shortcut left by the focused updater,
    # before rebuilding the managed TQQ bind block on a full install.
    text = re.sub(
        r"(?ms)^[ \\t]*// BEGIN TQQ TERMINAL BIND\\n.*?^[ \\t]*// END TQQ TERMINAL BIND[ \\t]*(?:\\n|$)",
        "",
        text,
    )
    # Remove only previously generated TQQ blocks. Every user setting and bind stays intact.
    text = re.sub(
        r"(?ms)^// BEGIN TQQ LAUNCHER WINDOW RULE\n.*?^// END TQQ LAUNCHER WINDOW RULE[ \t]*(?:\n|$)",
        "",
        text,
    )
    text = re.sub(
        r"(?ms)^// BEGIN TQQ NIRI STARTUP\n.*?^// END TQQ NIRI STARTUP[ \t]*(?:\n|$)",
        "",
        text,
    )
    text = re.sub(
        r"(?ms)^[ \t]*// BEGIN TQQ NIRI BINDS\n.*?^[ \t]*// END TQQ NIRI BINDS[ \t]*(?:\n|$)",
        "",
        text,
    )
    text = re.sub(
        r"(?ms)^// BEGIN TQQ WALLPAPER WINDOW RULE\n.*?^// END TQQ WALLPAPER WINDOW RULE[ \t]*(?:\n|$)",
        "",
        text,
    )

    text = re.sub(
        r"(?ms)^// BEGIN TQQ WALLPAPER LAYER RULE\n.*?^// END TQQ WALLPAPER LAYER RULE[ \t]*(?:\n|$)",
        "",
        text,
    )

    # Migrate standalone SwayNC autostart entries left by older TQQ releases.
    # Do not change unrelated startup commands or user settings.
    text = re.sub(
        r'(?m)^[ \t]*(?:spawn-at-startup|spawn-sh-at-startup)[ \t]+"swaync"[ \t]*(?:\n|$)',
        "",
        text,
    )

    # Remove the old simple Win+Space -> Fuzzel shortcut from earlier TQQ installs.
    # Keep other user-defined Win+Space actions untouched.
    text = re.sub(
        r'(?m)^[ \t]*(?:Super|Mod)\+Space(?:[ \t]+[^\n{}]*)?[ \t]*\{[ \t]*spawn[ \t]+"fuzzel";[ \t]*\}[ \t]*(?:\n|$)',
        "",
        text,
    )

    # Niri's stock Mod+D calls Fuzzel. Replace ONLY that known stock launcher
    # binding with TQQ; other user-defined Mod+D actions stay intact.
    text = re.sub(
        r'(?m)^[ \t]*(?:Mod|Super)\+D[^\n{}]*\{\s*spawn\s+"fuzzel";\s*\}[ \t]*(?:\n|$)',
        "",
        text,
    )

    # Remove stale dashboard launch binds left behind by older TQQ releases.
    # The managed TQQ block below will add exactly one current dashboard binding.
    text = re.sub(
        r'(?m)^[ \t]*(?:Super|Mod)\+[^\n{}]*hotkey-overlay-title="TQQ Dashboard"[^\n{}]*\{[^\n]*tqq-dashboard[^\n]*\}[ \t]*(?:\n|$)',
        "",
        text,
    )

    # Migrate known leftovers from earlier Itsuki/Miku-based configs.
    # Keep useful visual settings, but remove stale labels and the duplicate Kitty rule.
    text = re.sub(
        r"(?ms)^[ \t]*// ITSUKI_KITTY_BLUR_BEGIN\n.*?^[ \t]*// ITSUKI_KITTY_BLUR_END[ \t]*(?:\n|$)",
        "",
        text,
    )
    marker_names = {
        "BEGIN ITSUKI RICE STARTUP": "",
        "END ITSUKI RICE STARTUP": "",
        "MIKU_WINDOW_ROUNDING_START": "TQQ WINDOW ROUNDING START",
        "MIKU_WINDOW_ROUNDING_END": "TQQ WINDOW ROUNDING END",
        "MIKU_GLOBAL_BLUR": "TQQ GLOBAL BLUR",
        "MIKU_KITTY_BLUR_BEGIN": "TQQ KITTY BLUR BEGIN",
        "MIKU_KITTY_BLUR_END": "TQQ KITTY BLUR END",
    }
    text = re.sub(
        r"(?m)^([ \t]*)// (BEGIN ITSUKI RICE STARTUP|END ITSUKI RICE STARTUP|MIKU_WINDOW_ROUNDING_START|MIKU_WINDOW_ROUNDING_END|MIKU_GLOBAL_BLUR|MIKU_KITTY_BLUR_BEGIN|MIKU_KITTY_BLUR_END)[ \t]*$",
        lambda match: (match.group(1) + "// " + marker_names[match.group(2)]) if marker_names[match.group(2)] else "",
        text,
    )
    text = re.sub(
        r"(?m)^([ \t]*)Super\+Shift\+B[ \t]+hotkey-overlay-title=[^\n]*itsuki-reload-rice[^\n]*\n",
        "",
        text,
    )
    # The power menu now lives inside the Quickshell Control Center.
    text = re.sub(
        r'(?m)^[ \t]*(?:Super|Mod)\+E[ \t]+hotkey-overlay-title="(?:Miku|TQQ) Power Menu"[^\n]*(?:\n|$)',
        "",
        text,
    )
    text = text.replace('hotkey-overlay-title="Miku Quick Settings"', 'hotkey-overlay-title="TQQ Quick Settings"')

    # TQQ owns Alt+Tab for the radial switcher and Win+Enter for the selected
    # Kitty/Ghostty terminal. Remove only those explicit user-requested binds.
    text = remove_keybindings(text, [
        "Alt+Shift+Tab", "Alt+Tab",
        "Mod+Return", "Super+Return", "Mod+Enter", "Super+Enter",
    ])

    binds_match = re.search(r"(?m)^([ \t]*)binds[ \t]*\{", text)
    if binds_match:
        opening = text.find("{", binds_match.start())
        closing = find_block_end(text, opening)
        binds_body = text[opening + 1:closing]
    else:
        binds_body = ""

    # Niri binds begin with a key chord; action flags may follow before the action block.
    used = {
        normalize_key(match.group(1))
        for match in re.finditer(
            r"(?m)^[ \t]*([A-Za-z0-9_+.-]+)[ \t]*(?:[^\n{}]*)\{",
            binds_body,
        )
    }

    def choose(candidates: list[str]) -> str:
        for candidate in candidates:
            if normalize_key(candidate) not in used:
                used.add(normalize_key(candidate))
                return candidate
        raise ValueError("No free keybinding among: " + ", ".join(candidates))

    # Reserve Win+B for wallpaper selection. Never fall back to Win+Space: that is a common input/language-switch shortcut.
    # The launcher uses Win+D, then modified D combinations only.
    wallpaper_key = choose(["Mod+B", "Mod+Shift+B", "Mod+Alt+B", "Mod+Ctrl+B"])
    launcher_key = choose(["Mod+D", "Mod+Shift+D", "Mod+Alt+D", "Mod+Ctrl+D"])

    wallpaper = json.dumps(str(local_bin / "select-wallpaper"), ensure_ascii=False)
    wifi_key = choose(["Mod+N", "Mod+Shift+N", "Mod+Ctrl+N"])
    wifi_menu = json.dumps(str(local_bin / "tqq-wifi"), ensure_ascii=False)
    dashboard_key = choose(["Mod+Shift+Space", "Mod+Alt+Space", "Mod+Ctrl+Space"])
    dashboard = json.dumps(str(local_bin / "tqq-dashboard"), ensure_ascii=False)
    lock_key = choose(["Mod+L", "Mod+Shift+L", "Mod+Ctrl+L", "Mod+Alt+L", "Mod+Ctrl+Shift+L", "Mod+Alt+Shift+L"])
    lock_screen = json.dumps(str(local_bin / "tqq-lock-screen"), ensure_ascii=False)

    # Niri does not supply default keybindings once a binds block is customized.
    # Restore native screenshot actions only if the user has not bound those keys.
    screenshot_lines = []
    screenshot_actions = (
        ("Print", "screenshot", "Select Screenshot Area"),
        ("Ctrl+Print", "screenshot-screen", "Screenshot Screen"),
        ("Alt+Print", "screenshot-window", "Screenshot Window"),
    )
    for key, action, title in screenshot_actions:
        normalized = normalize_key(key)
        if normalized not in used:
            used.add(normalized)
            screenshot_lines.append(
                f'    {key} hotkey-overlay-title="{title}" {{ {action}; }}\n'
            )

    # Useful when a laptop needs Fn+Print or has an awkward Print key.
    # Do not override an existing shortcut used by other applications.
    screenshot_key = next(
        (
            candidate
            for candidate in ("Mod+Shift+S", "Mod+Alt+S", "Mod+Ctrl+S")
            if normalize_key(candidate) not in used
        ),
        None,
    )
    if screenshot_key:
        used.add(normalize_key(screenshot_key))
        screenshot_lines.append(
            f'    {screenshot_key} hotkey-overlay-title="TQQ Screenshot" {{ screenshot; }}\n'
        )

    # Restore common Niri workspace and audio controls only when unbound.
    standard_lines = []
    for index in range(1, 10):
        for key, action in (
            (f"Mod+{index}", f"focus-workspace {index}"),
            (f"Mod+Ctrl+{index}", f"move-column-to-workspace {index}"),
        ):
            normalized = normalize_key(key)
            if normalized not in used:
                used.add(normalized)
                standard_lines.append(f"    {key} {{ {action}; }}\n")

    volume_actions = (
        ("XF86AudioRaiseVolume", 'spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05+" "-l" "1.0"'),
        ("XF86AudioLowerVolume", 'spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05-"'),
        ("XF86AudioMute", 'spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"'),
        ("XF86AudioMicMute", 'spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"'),
    )
    for key, action in volume_actions:
        normalized = normalize_key(key)
        if normalized not in used:
            used.add(normalized)
            standard_lines.append(f"    {key} allow-when-locked=true {{ {action}; }}\n")

    managed_binds = (
        "\n    // BEGIN TQQ NIRI BINDS\n"
        f'    {wallpaper_key} hotkey-overlay-title="TQQ Wallpaper Picker" {{ spawn {wallpaper}; }}\n'
        f'    {wifi_key} hotkey-overlay-title="TQQ Wi-Fi" {{ spawn {wifi_menu}; }}\n'
        '    Alt+Tab hotkey-overlay-title="TQQ Window Switcher" { spawn ' + json.dumps(str(local_bin / "tqq-switcher"), ensure_ascii=False) + ' "next"; }\n'
        '    Alt+Shift+Tab hotkey-overlay-title="TQQ Window Switcher" { spawn ' + json.dumps(str(local_bin / "tqq-switcher"), ensure_ascii=False) + ' "previous"; }\n'
        f'    {dashboard_key} hotkey-overlay-title="TQQ Dashboard" {{ spawn {dashboard}; }}\n'
        f'    {launcher_key} hotkey-overlay-title="TQQ App Launcher" {{ spawn {json.dumps(str(local_bin / "tqq-launcher"), ensure_ascii=False)}; }}\n'
        f'    Mod+Return hotkey-overlay-title="TQQ Terminal" {{ spawn {json.dumps(str(local_bin / "tqq-terminal"), ensure_ascii=False)}; }}\n'
        f'    {lock_key} hotkey-overlay-title="Lock Screen" {{ spawn {lock_screen}; }}\n'
        + "".join(screenshot_lines)
        + "".join(standard_lines)
        + "    // END TQQ NIRI BINDS\n"
    )
    if binds_match:
        text = text[:closing] + managed_binds + text[closing:]
    else:
        text = text.rstrip() + "\n\nbinds {" + managed_binds + "}\n"

    startup_entries = []
    startup_apps = ["dunst"]
    if shutil.which("waybar"):
        startup_apps.append("waybar")
        # These applets supply the network and Bluetooth status tray icons.
        if shutil.which("nm-applet"):
            startup_apps.append("nm-applet")
        if shutil.which("blueman-applet"):
            startup_apps.append("blueman-applet")
    for app in startup_apps:
        if not re.search(
            r"(?m)^\s*(?:spawn-at-startup|spawn-sh-at-startup)\b[^\n]*\b" + app + r"\b",
            text,
        ):
            args = ' "--indicator"' if app == "nm-applet" else ""
            startup_entries.append(f"spawn-at-startup {json.dumps(app)}{args}")
    restore_cmd = json.dumps(str(local_bin / "select-wallpaper"), ensure_ascii=False)
    if not re.search(r"(?m)^\s*spawn-at-startup\s+\"[^\"]*select-wallpaper\"[^\n]*--restore", text):
        startup_entries.append(f"spawn-at-startup {restore_cmd} \"--restore\"")
    if startup_entries:
        startup_block = (
            "// BEGIN TQQ NIRI STARTUP\n"
            + "\n".join(startup_entries)
            + "\n// END TQQ NIRI STARTUP\n\n"
        )
        binds_match = re.search(r"(?m)^([ \t]*)binds[ \t]*\{", text)
        insertion = binds_match.start() if binds_match else len(text)
        text = text[:insertion] + startup_block + text[insertion:]


    layer_rule = (
        "\n// BEGIN TQQ WALLPAPER LAYER RULE\n"
        "layer-rule {\n"
        '    match namespace="^tqq-wallpaper-gallery$"\n'
        "    shadow {\n"
        "        off\n"
        "    }\n"
        "}\n"
        "// END TQQ WALLPAPER LAYER RULE\n"
    )
    text = text.rstrip() + "\n" + layer_rule

    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(text)
    print(
        "Preserved user Niri settings; migrated legacy rice labels, removed the duplicate Kitty rule, "
        f"and added TQQ wallpaper ({wallpaper_key}), Quickshell Wi-Fi ({wifi_key}), radial Alt+Tab, dashboard ({dashboard_key}), lock ({lock_key}), launcher ({launcher_key}), terminal (Mod+Return), screenshots ({screenshot_key or 'Print'}), native workspace/audio controls, and Dunst/Waybar/network applet startup when available."
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"Niri integration failed: {error}", file=sys.stderr)
        raise SystemExit(1)
