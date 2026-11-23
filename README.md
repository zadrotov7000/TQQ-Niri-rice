# TQQ Niri rice

A lightweight Niri desktop setup for Linux, themed around *The Quintessential Quintuplets*. TQQ uses Quickshell for its interactive desktop panels and keeps optional visual features separate so they can be enabled only when needed.

## Included

- **Control Center:** the animated Quickshell dashboard with calendar, clock, weather, media, network, system information, volume and brightness controls. The power menu is in its top-right corner beside the close button.
- **Application launcher:** the Waybar magnifying-glass button opens the Quickshell application search. The panel expands from a compact box under the launcher icon. `Mod+D` remains available as a keyboard shortcut.
- **Wi-Fi panel:** `Mod+N` (or the installer's free fallback) opens a Quickshell network panel. It scans NetworkManager, shows signal strength and security, prompts for a password when needed, and connects without Fuzzel.
- **Lock screen:** Quickshell uses the native Wayland `WlSessionLock` protocol and PAM authentication, with the current wallpaper blurred behind the clock/date and a password form revealed by Enter. The lock remains held by the compositor if Quickshell exits unexpectedly.
- **Radial window switcher:** `Alt+Tab` opens a circular window selector. Repeated `Alt+Tab` moves forward; `Alt+Shift+Tab` moves backward. The highlighted window is focused when the switcher times out, and Escape cancels.
- **Squishy Physics:** a free `Mod+F`-family shortcut opens an interactive wallpaper overlay. Draw a lasso with the left mouse button, then hold the right mouse button and drag inside the selected area. The selected patch is rendered on a 128×72 GPU mesh and follows the pointer with a damped spring response, elastic tension ripple, and spring-back on release. Canvas is used only to rasterize the lasso mask and draw its outline; image deformation is rendered by Qt Quick `ShaderEffect` shaders. This is the native Qt graphics pipeline (OpenGL/Vulkan and other Qt RHI backends), not an embedded browser/WebGL2 context. Backspace clears the selection and Escape closes the overlay. Backspace clears the selection and Escape closes the overlay.
- **Wallpaper gallery:** a transparent Rust/GTK4 Layer Shell surface opens above the desktop. Browse with Left/Right or the mouse wheel, click a side card to move, click the centered card or press Enter to apply, and press Escape to close.
- **Wallpaper transition:** the repository uses `awww` when available. Wallpaper changes use a circular center-out reveal; `swaybg` remains the fallback. Wallpaper changes regenerate Matugen colors and do not reload the Niri config.
- **Wallpaper persistence:** the selected image is restored when Niri starts.
- **Optional Waybar theme:** `config/waybar/` contains the Island bar configuration. Waybar is started by Niri only when installed.
- **SwayNC:** notifications, quick settings, media controls, Do Not Disturb, and volume/brightness controls.
- **3D Fetch support:** optional config for [areofyl/fetch](https://github.com/areofyl/fetch). Existing Fetch/Fastfetch startup is preserved.

## Install

Clone the repository and enter the directory:

```bash
git clone https://github.com/zadrotov7000/TQQ-Niri-rice.git
cd TQQ-Niri-rice
./install.sh
```

The installer checks dependencies and asks whether to install missing packages. Use `./install.sh --install-deps` to install them explicitly or `./install.sh --skip-deps` to skip the prompt.

Before replacing configs, TQQ stores dated backups under `~/.local/state/tqq-niri-rice/backups/`. During migration, old Fuzzel and GTKLock config folders and helper scripts are backed up and retired. The installer does not automatically uninstall a Fuzzel package that may have been installed separately by the user; TQQ no longer uses or installs it.

## Dependencies

The desktop requires Niri, Quickshell (including its PAM service module), SwayNC, Matugen, NetworkManager (`nmcli`), PipeWire/WirePlumber (`wpctl`), `playerctl`, `pavucontrol`, `blueman-manager`, `brightnessctl`, Python 3, Rust/Cargo, GTK4 and GTK4 Layer Shell development files for the native wallpaper gallery, Qt ShaderTools (`qsb`, build-time only, to compile the Squishy vertex/fragment shaders), and common process tools (`pgrep`, `pkill`). For wallpaper display, install `awww` and its daemon or `swaybg`.

`scripts/check-dependencies` reports missing commands and package hints. The installer compiles the Squishy `.vert` and `.frag` sources into Qt `.qsb` shader packages before copying the Quickshell configuration. `scripts/install-dependencies` includes package recipes for Debian/Ubuntu, Arch, Fedora, and openSUSE. Quickshell is installed from Debian Backports on Debian 13. Niri and `awww` may need to be installed separately depending on the distribution.

## Keybindings

| Action | Shortcut |
| --- | --- |
| Wallpaper gallery and Matugen palette | `Mod+B` |
| Dashboard / Control Center | `Mod+Shift+Space` (free fallback if occupied) |
| Application launcher | Waybar magnifying glass, or `Mod+D` |
| Wi-Fi panel | `Mod+N` (free fallback if occupied) |
| Lock screen | First free key from `Mod+L`, `Mod+Shift+L`, `Mod+Ctrl+L`, `Mod+Alt+L`, `Mod+Ctrl+Shift+L`, `Mod+Alt+Shift+L` |
| Radial window switcher | `Alt+Tab` / `Alt+Shift+Tab` |
| Squishy Physics overlay | First free key from `Mod+F`, `Mod+Shift+F`, `Mod+Alt+F`, `Mod+Ctrl+F` |

The installer preserves existing Niri settings and unrelated keybindings. It reserves Alt+Tab and Alt+Shift+Tab for the TQQ radial switcher.

## Project layout

- `quickshell/tqq-dashboard/` — Control Center and embedded power menu.
- `quickshell/tqq-launcher/` — expanding application launcher.
- `quickshell/tqq-wifi/` — Wi-Fi picker.
- `quickshell/tqq-lock/` — PAM-authenticated lock screen.
- `quickshell/tqq-switcher/` — radial Alt+Tab selector.
- `quickshell/tqq-squishy/` — wallpaper lasso and spring-drag overlay.
- `wallpaper-gallery/` — native Rust/GTK4 wallpaper gallery.
- `config/matugen/` — wallpaper-derived palette templates.
- `config/swaync/` and `config/waybar/` — notification and bar styling.
- `scripts/` — installers, launchers, wallpaper handling, and Niri integration helpers.
- `wallpapers/` — included TQQ wallpaper collection.
