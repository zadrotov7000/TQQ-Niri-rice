# TQQ Niri rice

A lightweight Niri desktop setup for Linux, themed around *The Quintessential Quintuplets*. TQQ uses Quickshell for its interactive desktop panels and keeps optional visual features separate so they can be enabled only when needed.

## Included

- **Control Center:** the animated Quickshell dashboard with calendar, clock, weather, media, network, system information, volume and brightness controls. Its Niri shortcut (usually Mod+Shift+Space) and the Waybar clock **toggle** the panel: press again to close with the existing animation; Escape and the X button also close it. The power menu is in its top-right corner beside the close button.
- **Application launcher:** the Waybar magnifying-glass button opens the Quickshell application search. Results use application icons from their desktop entries and the active icon theme; entries with missing icons fall back to a letter. The panel expands from a compact box under the launcher icon. The installer assigns `Mod+D` when free and chooses a documented fallback if it is already used.
- **Wi-Fi panel:** `Mod+N` (or the installer's free fallback) opens a Quickshell network panel. It scans NetworkManager, shows signal strength and security, prompts for a password when needed, and connects through NetworkManager.
- **Lock screen:** Quickshell uses the native Wayland `WlSessionLock` protocol and PAM authentication, with the current wallpaper blurred behind the clock/date and a password form revealed by Enter. The lock remains held by the compositor if Quickshell exits unexpectedly.
- **Radial window switcher:** `Alt+Tab` opens a circular window selector. Repeated `Alt+Tab` moves forward; `Alt+Shift+Tab` moves backward. The highlighted window is focused when the switcher times out, and Escape cancels.
- **Wallpaper gallery:** a transparent Rust/GTK4 Layer Shell surface opens above the desktop. **Mod+B toggles** the gallery: first press opens, second closes, without spawning extra copies. Escape closes it too. Browse with Left/Right or the mouse wheel, click a side card to move, and press Enter to apply.
- **Wallpaper transition:** the repository uses `awww` when available. Wallpaper changes use a circular center-out reveal; `swaybg` remains the fallback. Wallpaper changes regenerate Matugen colors and do not reload the Niri config.
- **Wallpaper persistence:** the selected image is restored when Niri starts.
- **Waybar Island:** compact dark pills with smooth borders cycling through the wallpaper-derived Matugen `primary`, `secondary` and `tertiary` colors (Waybar only). The launcher, clock, network, volume, disk and notification icons use Font Awesome 4 glyphs, provided by Debian's `fonts-font-awesome` package, with Nerd Fonts as optional fallback. NetworkManager and Blueman applets start with Niri when present. Clicking Waybar's Wi-Fi icon opens TQQ Wi-Fi.
- **Dunst:** lightweight notifications and notification history; the Waybar bell restores the latest notification and right-click toggles Do Not Disturb. Media, network, brightness and volume controls stay in the Quickshell dashboard.
- **3D Fetch support:** optional config for [areofyl/fetch](https://github.com/areofyl/fetch). Existing Fetch/Fastfetch startup is preserved.

## Install

Clone the repository and enter the directory:

```bash
git clone https://github.com/zadrotov7000/TQQ-Niri-rice.git
cd TQQ-Niri-rice
./install.sh
```

The installer checks dependencies and asks whether to install missing packages. Use `./install.sh --install-deps` to install them explicitly or `./install.sh --skip-deps` to skip the prompt.

Before changing the Niri config or replacing installed TQQ helper scripts, the installer stores dated backups under `~/.local/state/tqq-niri-rice/backups/`. It does not uninstall system packages, remove old user config folders, or delete legacy helper files. Removing unused applications is left to the user. Older SwayNC packages and files are not automatically removed; the new installer does not install, configure, start, or invoke SwayNC. The installer backs up and installs the Dunst, Matugen, Waybar, Fetch, and Quickshell configs into their standard locations (under ~/.config or $XDG_CONFIG_HOME). The Quickshell launcher is wired to the Waybar launcher icon and the Niri launcher shortcut.

## Dependencies

The desktop requires Niri, Quickshell (including its PAM service module), Dunst (`dunst` and `dunstctl`), Waybar, Nerd Font symbols (installed by `scripts/install-icon-fonts`), the NetworkManager and Blueman tray applets, Matugen, NetworkManager (`nmcli`), PipeWire/WirePlumber (`wpctl`), `playerctl`, `pavucontrol`, `blueman-manager`, `brightnessctl`, Python 3, Rust/Cargo, GTK4 and GTK4 Layer Shell development files for the native wallpaper gallery, and common process tools (`pgrep`, `pkill`). For wallpaper display, install `awww` and its daemon or `swaybg`.

`scripts/check-dependencies` reports missing commands and package hints. `scripts/install-dependencies` includes package recipes for Debian/Ubuntu, Arch, Fedora, and openSUSE. Quickshell is installed from Debian Backports on Debian 13. Niri and `awww` may need to be installed separately depending on the distribution. Run `./scripts/install-dependencies` after updating the repository to repair missing status icons without rebuilding the Rust wallpaper gallery.

## Restore full Niri defaults after an older minimal TQQ install

If an older install left you with a config containing only `// BEGIN TQQ...` blocks, run:

```bash
git pull --ff-only
./scripts/restore-niri-default
```

**This is an explicit recovery command**, not part of the normal installer. It replaces the current Niri config only after downloading official **Niri v26.04** defaults, applying TQQ binds to a temporary file and running `niri validate --config <candidate>`. It keeps a timestamped backup of your previous `config.kdl`, does not reinstall Niri, and refuses to run for other Niri versions. It does not alter personal keyboard layout preferences: edit `input.keyboard.xkb` in your own config for those.

## Update only Waybar (no rice rebuild)

```bash
sudo apt install fonts-font-awesome
cd ~/TQQ-Niri-rice && git pull --ff-only
mkdir -p ~/.config/waybar
cp ~/.config/waybar/config ~/.config/waybar/config.before-tqq-island 2>/dev/null || true
cp ~/.config/waybar/style.css ~/.config/waybar/style.css.before-tqq-island 2>/dev/null || true
cp config/waybar/config config/waybar/style.css ~/.config/waybar/
mkdir -p ~/.config/matugen/templates
cp config/matugen/templates/colors.css ~/.config/matugen/templates/colors.css
# Regenerate the Waybar palette from your saved wallpaper (no wallpaper switch):
wallpaper="$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/tqq-niri-rice/current-wallpaper")"
matugen -c ~/.config/matugen/config.toml image "$wallpaper" -m dark --source-color-index 0
pkill -SIGUSR2 -x waybar
```

The animated border uses the active Matugen palette, not a fixed RGB/rainbow cycle. When the wallpaper is changed using TQQ, Matugen regenerates `~/.config/waybar/colors.css` and TQQ reloads Waybar. It does not affect Niri window borders, Kitty or other applications. If Waybar is not running, start it with `waybar &` from your Niri session. If icons remain empty, check `fc-match FontAwesome` and restart Waybar after installing the font.

## TQQ WindowFX — windows and animations (Niri 26.04)

Run this **separate** script when the Niri desktop and Waybar's Matugen theme are already installed; it does not rebuild the wallpaper gallery or replace your keyboard setup:

```bash
cd ~/TQQ-Niri-rice
git pull --ff-only
./scripts/apply-windowfx
```

This compiles a small, **dependency-free Rust** color generator to `~/.local/bin/tqq-windowfx`, creates `~/.config/niri/tqq-windowfx.kdl` from the existing Matugen `~/.config/waybar/colors.css`, and adds one `include "tqq-windowfx.kdl"` to your Niri configuration (only if not already present). It saves a dated backup and runs `niri validate --config` before changing your main config. It also backs up and refreshes the installed TQQ `select-wallpaper` helper, so changing wallpapers updates the window border colors. **Your language, shortcuts, and installed applications are preserved.** On validation failure it restores the previous theme and leaves the main config alone.

Appearance: a 3px primary-to-tertiary gradient for focused windows, subtle secondary borders on others, 14px rounded/clipped corners, soft drop shadows and native GPU-accelerated Niri opening/closing/movement animations. The Rust program is **not** a background daemon; it runs once after each TQQ wallpaper change to regenerate colors. Niri watches the included file and reloads it automatically. This is not a continuously rotating RGB border; there is no per-frame Rust process.

To disable it without losing your backups, remove only the block between `// BEGIN TQQ WINDOWFX` and `// END TQQ WINDOWFX` in your Niri config. No packages are uninstalled.

## Update hotkey toggles without rebuilding Rust

The existing Niri binds are preserved. The `select-wallpaper` Bash launcher holds a `flock` lock while one picker is open; a second Mod+B closes that picker without applying a wallpaper. The gallery already responds to Escape. The Control Center uses an `IpcHandler` from Quickshell.Io: calling its launcher again closes the current panel gracefully via its existing animation. Escape and the close button still work.

```bash
cd ~/TQQ-Niri-rice
git pull --ff-only
mkdir -p ~/.local/bin ~/.config/quickshell/tqq-dashboard
cp -p ~/.local/bin/select-wallpaper ~/.local/bin/select-wallpaper.bak 2>/dev/null || true
cp -p ~/.local/bin/tqq-dashboard ~/.local/bin/tqq-dashboard.bak 2>/dev/null || true
cp -p ~/.config/quickshell/tqq-dashboard/shell.qml ~/.config/quickshell/tqq-dashboard/shell.qml.bak 2>/dev/null || true
install -m 0755 scripts/select-wallpaper ~/.local/bin/select-wallpaper
install -m 0755 scripts/tqq-dashboard ~/.local/bin/tqq-dashboard
install -m 0644 quickshell/tqq-dashboard/shell.qml ~/.config/quickshell/tqq-dashboard/shell.qml
```

Close any old dashboard window with Escape before testing the updated shortcut. The launchers require `flock` (util-linux; installed on normal Debian). Neither tool changes your Niri config, and the Rust wallpaper gallery does not need recompiling.

## Apply clean panel labels and application icons

The launcher, Control Center and Wi-Fi panel no longer show visible TQQ wordmarks. The launcher renders actual application icons through `DesktopEntry.icon` and `Quickshell.iconPath()`, with a fallback for missing icons.

```bash
cd ~/TQQ-Niri-rice && git pull --ff-only
for panel in tqq-launcher tqq-dashboard tqq-wifi; do
    mkdir -p "$HOME/.config/quickshell/$panel"
    if [ -f "$HOME/.config/quickshell/$panel/shell.qml" ]; then
        cp -p "$HOME/.config/quickshell/$panel/shell.qml" "$HOME/.config/quickshell/$panel/shell.qml.before-icons"
    fi
    install -m 644 "quickshell/$panel/shell.qml" "$HOME/.config/quickshell/$panel/shell.qml"
done
```

Close open panels with Escape, then reopen. No Niri or Rust rebuild is needed.

## Keybindings

| Action | Shortcut |
| --- | --- |
| Wallpaper gallery and Matugen palette | `Mod+B` |
| Dashboard / Control Center | `Mod+Shift+Space` (free fallback if occupied) |
| Application launcher | Waybar magnifying glass, or `Mod+D` |
| Wi-Fi panel | `Mod+N` (free fallback if occupied) |
| Lock screen | First free key from `Mod+L`, `Mod+Shift+L`, `Mod+Ctrl+L`, `Mod+Alt+L`, `Mod+Ctrl+Shift+L`, `Mod+Alt+Shift+L` |
| Radial window switcher | `Alt+Tab` / `Alt+Shift+Tab` |
| Workspaces | `Mod+1` through `Mod+9`; move the focused column with `Mod+Ctrl+1` through `Mod+Ctrl+9` |
| Screenshot | `Print`: select area; `Ctrl+Print`: full screen; `Alt+Print`: window; free fallback `Mod+Shift+S` |
| Volume | Laptop volume keys (`XF86AudioRaiseVolume`, `XF86AudioLowerVolume`, `XF86AudioMute`) through `wpctl` |

The installer preserves existing Niri settings and unrelated keybindings. It reserves Alt+Tab and Alt+Shift+Tab for the TQQ radial switcher. It restores missing workspace, screenshot and volume binds, but leaves existing shortcuts in place. Niri uses dynamic workspaces, so `Mod+9` goes to the last available workspace rather than creating nine fixed desktops. To apply new keybindings without rebuilding Rust, update the repository, back up `~/.config/niri/config.kdl`, run `python3 scripts/integrate-niri.py ~/.config/niri/config.kdl ~/.local/bin` and then `niri validate`.

## Project layout

- `quickshell/tqq-dashboard/` — Control Center and embedded power menu.
- `quickshell/tqq-launcher/` — expanding application launcher.
- `quickshell/tqq-wifi/` — Wi-Fi picker.
- `quickshell/tqq-lock/` — PAM-authenticated lock screen.
- `quickshell/tqq-switcher/` — radial Alt+Tab selector.
- `wallpaper-gallery/` — native Rust/GTK4 wallpaper gallery.
- `config/matugen/` — wallpaper-derived palette templates.
- `config/dunst/` and `config/waybar/` — notification and bar styling.
- `scripts/` — installers, launchers, wallpaper handling, and Niri integration helpers.
- `wallpapers/` — included TQQ wallpaper collection.
