# TQQ Niri rice

A lightweight Niri desktop setup for Linux, themed around *The Quintessential Quintuplets*. TQQ uses Quickshell for its interactive desktop panels and keeps optional visual features separate so they can be enabled only when needed.

## Included

- **Control Center:** the animated Quickshell dashboard with calendar, clock, weather, media, network, system information, volume and brightness controls. The power menu is in its top-right corner beside the close button.
- **Application launcher:** the Waybar magnifying-glass button opens the Quickshell application search. The panel expands from a compact box under the launcher icon. The installer assigns `Mod+D` when free and chooses a documented fallback if it is already used.
- **Wi-Fi panel:** `Mod+N` (or the installer's free fallback) opens a Quickshell network panel. It scans NetworkManager, shows signal strength and security, prompts for a password when needed, and connects through NetworkManager.
- **Lock screen:** Quickshell uses the native Wayland `WlSessionLock` protocol and PAM authentication, with the current wallpaper blurred behind the clock/date and a password form revealed by Enter. The lock remains held by the compositor if Quickshell exits unexpectedly.
- **Radial window switcher:** `Alt+Tab` opens a circular window selector. Repeated `Alt+Tab` moves forward; `Alt+Shift+Tab` moves backward. The highlighted window is focused when the switcher times out, and Escape cancels.
- **Squishy Physics:** a free `Mod+F`-family shortcut opens an interactive wallpaper overlay. Draw a lasso with the left mouse button, then hold the right mouse button and drag inside the selected area. The selected patch is rendered on a 128×72 GPU mesh and follows the pointer with a damped spring response, elastic tension ripple, and spring-back on release. Canvas is used only to rasterize the lasso mask and draw its outline; image deformation is rendered by Qt Quick `ShaderEffect` shaders. This is the native Qt graphics pipeline (OpenGL/Vulkan and other Qt RHI backends), not an embedded browser/WebGL2 context. Backspace clears the selection and Escape closes the overlay.
- **Wallpaper gallery:** a transparent Rust/GTK4 Layer Shell surface opens above the desktop. Browse with Left/Right or the mouse wheel, click a side card to move, click the centered card or press Enter to apply, and press Escape to close.
- **Wallpaper transition:** the repository uses `awww` when available. Wallpaper changes use a circular center-out reveal; `swaybg` remains the fallback. Wallpaper changes regenerate Matugen colors and do not reload the Niri config.
- **Wallpaper persistence:** the selected image is restored when Niri starts.
- **Waybar Island:** compact dark pills with smooth blue/purple/pink/teal animated borders (Waybar only). The launcher, clock, network, volume, disk and notification icons use Font Awesome 4 glyphs, provided by Debian's `fonts-font-awesome` package, with Nerd Fonts as optional fallback. NetworkManager and Blueman applets start with Niri when present. Clicking Waybar's Wi-Fi icon opens TQQ Wi-Fi.
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

Before changing the Niri config or replacing installed TQQ helper scripts, the installer stores dated backups under `~/.local/state/tqq-niri-rice/backups/`. It does not uninstall system packages, remove old user config folders, or delete legacy helper files. Removing unused applications is left to the user. Older SwayNC packages and files are not automatically removed; the new installer does not install, configure, start, or invoke SwayNC. The installer backs up and installs the Dunst, Matugen, Waybar, Fetch, and Quickshell configs into their standard locations (under ~/.config or $XDG_CONFIG_HOME), including the compiled Squishy shaders. The Quickshell launcher is wired to the Waybar launcher icon and the Niri launcher shortcut.

## Dependencies

The desktop requires Niri, Quickshell (including its PAM service module), Dunst (`dunst` and `dunstctl`), Waybar, Nerd Font symbols (installed by `scripts/install-icon-fonts`), the NetworkManager and Blueman tray applets, Matugen, NetworkManager (`nmcli`), PipeWire/WirePlumber (`wpctl`), `playerctl`, `pavucontrol`, `blueman-manager`, `brightnessctl`, Python 3, Rust/Cargo, GTK4 and GTK4 Layer Shell development files for the native wallpaper gallery, Qt ShaderTools (`qsb`, build-time only, to compile the Squishy vertex/fragment shaders), and common process tools (`pgrep`, `pkill`). For wallpaper display, install `awww` and its daemon or `swaybg`.

`scripts/check-dependencies` reports missing commands and package hints. The installer compiles the Squishy `.vert` and `.frag` sources into Qt `.qsb` shader packages before copying the Quickshell configuration. `scripts/install-dependencies` includes package recipes for Debian/Ubuntu, Arch, Fedora, and openSUSE. Quickshell is installed from Debian Backports on Debian 13. Niri and `awww` may need to be installed separately depending on the distribution. Run `./scripts/install-dependencies` after updating the repository to repair missing status icons without rebuilding the Rust wallpaper gallery.

## Restore full Niri defaults after an older minimal TQQ install

If an older install left you with a config containing only `// BEGIN TQQ...` blocks, run:

```bash
git pull --ff-only
./scripts/restore-niri-default
```

**This is an explicit recovery command**, not part of the normal installer. It replaces the current Niri config only after downloading official **Niri v26.04** defaults, applying TQQ binds to a temporary file and running `niri --config <candidate> validate`. It keeps a timestamped backup of your previous `config.kdl`, does not reinstall Niri, and refuses to run for other Niri versions. It does not alter personal keyboard layout preferences: edit `input.keyboard.xkb` in your own config for those.

## Update only Waybar (no rice rebuild)

```bash
sudo apt install fonts-font-awesome
cd ~/TQQ-Niri-rice && git pull --ff-only
mkdir -p ~/.config/waybar
cp ~/.config/waybar/config ~/.config/waybar/config.before-tqq-island 2>/dev/null || true
cp ~/.config/waybar/style.css ~/.config/waybar/style.css.before-tqq-island 2>/dev/null || true
cp config/waybar/config config/waybar/style.css ~/.config/waybar/
pkill -SIGUSR2 -x waybar
```

The border cycles using lightweight GTK3 CSS keyframes; it does not affect Niri window borders, Kitty or other applications. If Waybar is not running, start it with `waybar &` from your Niri session. If icons remain empty, check `fc-match FontAwesome` and restart Waybar after installing the font.

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
- `quickshell/tqq-squishy/` — wallpaper lasso and spring-drag overlay.
- `wallpaper-gallery/` — native Rust/GTK4 wallpaper gallery.
- `config/matugen/` — wallpaper-derived palette templates.
- `config/dunst/` and `config/waybar/` — notification and bar styling.
- `scripts/` — installers, launchers, wallpaper handling, and Niri integration helpers.
- `wallpapers/` — included TQQ wallpaper collection.
