# TQQ Niri Rice

A customizable Niri desktop rice inspired by *The Quintessential Quintuplets*, combining animated Quickshell panels, wallpaper-driven Matugen colors, Island-style Waybar and a native Rust/GTK4 wallpaper gallery. Optional window effects and terminal themes let you customize the desktop without replacing your entire setup.

**Stack:** Niri · Quickshell / QML · Rust / GTK4 · Waybar · Matugen · Dunst

## Included

- **Control Center:** the animated Quickshell dashboard with calendar, clock, weather, media, network, system information, volume and brightness controls. Its Niri shortcut (usually Mod+Shift+Space) and the Waybar clock **toggle** the panel: press again to close with the existing animation; Escape and the X button also close it. The power menu is in its top-right corner beside the close button.
- **Application launcher:** the Waybar magnifying-glass button opens the Quickshell application search. Results use application icons from their desktop entries and the active icon theme; entries with missing icons fall back to a letter. The panel expands from a compact box under the launcher icon. The installer assigns `Mod+D` when free and chooses a documented fallback if it is already used.
- **Wi-Fi panel:** `Mod+N` (or the installer's free fallback) opens a Quickshell network panel. It scans NetworkManager, shows signal strength and security, prompts for a password when needed, and connects through NetworkManager.
- **Lock screen:** the secure Quickshell `WlSessionLock` and PAM screen places the clock/date at upper left, local weather at lower left, a navigable calendar at right, and a centered profile avatar with the password field beneath it. The background uses a strongly blurred wallpaper, and the avatar can be changed through Control Center or `tqq-avatar`. The preferred shortcut is `Mod+Alt+L`. The compositor holds the lock even if Quickshell exits unexpectedly.
- **Radial window switcher:** hold `Alt` and press `Tab` to open a ring of application icons. Additional Tab presses move forward, and Shift+Tab moves backward. Release Alt to focus the highlighted window and close the ring. Escape cancels; Enter or clicking an icon also confirms. The center shows the selected application's name and window title.
- **Wallpaper gallery:** a transparent Rust/GTK4 Layer Shell surface opens above the desktop. **Mod+B toggles** the gallery: first press opens, second closes, without spawning extra copies. Escape closes it too. Browse with Left/Right or the mouse wheel, click a side card to move, and press Enter to apply.
- **Wallpaper transition:** the repository uses `awww` when available. Wallpaper changes use a circular center-out reveal; `swaybg` remains the fallback. Wallpaper changes regenerate Matugen colors and do not reload the Niri config.
- **Wallpaper persistence:** the selected image is restored when Niri starts.
- **Waybar Island:** compact dark pills with smooth borders cycling through the wallpaper-derived Matugen `primary`, `secondary` and `tertiary` colors (Waybar only). The launcher, clock, network, volume, disk and notification icons use Font Awesome 4 glyphs, provided by Debian's `fonts-font-awesome` package, with Nerd Fonts as optional fallback. NetworkManager and Blueman applets start with Niri when present. Clicking Waybar's Wi-Fi icon opens TQQ Wi-Fi.
- **Dunst:** lightweight notifications and notification history; the Waybar bell restores the latest notification and right-click toggles Do Not Disturb. Media, network, brightness and volume controls stay in the Quickshell dashboard.
- **TQQ Fastfetch:** Debian ASCII logo on the left, exactly four compact 45-column information boxes on the right: OS/Kernel/Shell, Terminal/WM, CPU/GPU, RAM/Swap. Fixed-width labels and shorter values prevent frame wrapping in an ordinary terminal window. Matugen recolors the borders and labels when the wallpaper changes.
- **Kitty and Ghostty terminals:** optional matching dark-glass themes with Matugen colors. The installer selects the available terminal for **Win+Enter**; when both are installed, it lets you choose (Kitty by default without an interactive terminal). It stores the preference and keeps it until you change it; neither terminal is installed automatically.

## Install

Clone the repository and enter the directory:

```bash
git clone https://github.com/zadrotov7000/TQQ-Niri-rice.git
cd TQQ-Niri-rice
./install.sh
```

The installer checks dependencies and asks whether to install missing packages. Use `./install.sh --install-deps` to install them explicitly or `./install.sh --skip-deps` to skip the prompt.

Before changing the Niri config or replacing installed TQQ helper scripts, the installer stores dated backups under `~/.local/state/tqq-niri-rice/backups/`. It does not uninstall system packages, remove old user config folders, or delete legacy helper files. Removing unused applications is left to the user. Older SwayNC packages and files are not automatically removed; the new installer does not install, configure, start, or invoke SwayNC. The installer backs up and installs the Dunst, Matugen, Waybar, Fastfetch, and Quickshell configs into their standard locations (under ~/.config or $XDG_CONFIG_HOME). The Quickshell launcher is wired to the Waybar launcher icon and the Niri launcher shortcut.

## Dependencies

The desktop requires Niri, Fastfetch, Quickshell (including its PAM service module), QtQuick.Effects (on Debian: `qml6-module-qtquick-effects`), Dunst (`dunst` and `dunstctl`), Waybar, Nerd Font symbols (installed by `scripts/install-icon-fonts`), the NetworkManager and Blueman tray applets, Matugen, NetworkManager (`nmcli`), PipeWire/WirePlumber (`wpctl`), `playerctl`, `pavucontrol`, `blueman-manager`, `brightnessctl`, Python 3, Rust/Cargo, GTK4 and GTK4 Layer Shell development files for the native wallpaper gallery, and common process tools (`pgrep`, `pkill`). Animated wallpaper changes require `awww` / `awww-daemon` or `swww` / `swww-daemon`. The installer automatically installs swww if neither pair is available. `swaybg` remains a static fallback when dependencies are explicitly skipped.

`scripts/check-dependencies` reports missing commands and package hints. `scripts/install-dependencies` includes package recipes for Debian/Ubuntu, Arch, Fedora, and openSUSE. Quickshell is installed from Debian Backports on Debian 13. Niri may need to be installed separately depending on the distribution. The wallpaper backend uses an existing Rust toolchain and builds pinned swww 0.11.2 (Rust 1.89+) or 0.10.3 (Rust 1.85+), one build job at a time, under `~/.cache/tqq-niri-rice/swww-build/`. No Pacstall Rust package is needed. Existing awww/swww installations are reused. Run `./scripts/install-dependencies` after updating the repository to repair missing status icons without rebuilding the Rust wallpaper gallery.

## Animated wallpaper setup on an existing TQQ installation

```bash
cd ~/TQQ-Niri-rice
git pull --ff-only
./scripts/install-dependencies
mkdir -p ~/.local/bin
install -m 0755 scripts/{select-wallpaper,tqq-refresh-rice} ~/.local/bin/
~/.local/bin/select-wallpaper --restore
```

Win+B opens the existing gallery. Confirming another wallpaper reveals it from the center (0.95 s, target 60 FPS) and refreshes Matugen automatically. The wallpaper daemon stays running; the compositor is not restarted. The separate Control Center refresh remains available. If building the backend fails, check the reported build error; swaybg cannot animate. The build cache can be deleted after a successful installation without affecting the installed binaries.

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

## TQQ Fastfetch — four info boxes

The default profile shows a Debian ASCII logo on the left. On the right are **exactly four compact 45-character bordered groups**, with each value formatted as `Label → value`:

1. `OS`, `Kernel`, `Shell`
2. `Terminal`, `WM`
3. `CPU`, `GPU`
4. `RAM`, `Swap`

Other detected fields (packages, screen, uptime, etc.) are intentionally omitted. Long CPU/GPU names are truncated to keep the boxes aligned. The palette is a Matugen template; it updates when the TQQ wallpaper changes.

Debian 13 has Fastfetch in its repositories. To set up only this theme, without reinstalling the rice:

```bash
sudo apt install fastfetch
cd ~/TQQ-Niri-rice
git pull --ff-only
./scripts/setup-fastfetch
./scripts/configure-fastfetch-autostart
fastfetch
```

The setup writes `~/.config/fastfetch/tqq.jsonc` and links the usual `config.jsonc` to it after backing up any existing regular config. Symlink-managed user configs are left alone. Backups are in `~/.local/state/tqq-niri-rice/backups/fastfetch-*`. The shell autostart helper migrates **only old TQQ-owned Fetch blocks**, retains unrelated shell configuration, and does not add a duplicate if the user already runs Fastfetch.

The original 3D Fetch config and launcher have been removed from this repository. The setup **does not uninstall** any previously installed 3D Fetch binary or erase the user's old `~/.config/fetch` directory.

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

## Win+Enter — choose Kitty or Ghostty

TQQ supports **exactly two** terminals for its main shortcut: Kitty and Ghostty. The installer detects which are installed and saves the default to `~/.config/tqq-niri-rice/default-terminal`. If both are available, it offers a choice when running interactively and remembers that selection. If the selected terminal is removed, the launcher falls back to the other installed terminal. No terminal package is installed by this feature.

To add or update **only Win+Enter** on an existing TQQ installation, without reinstalling the rice or replacing unrelated Niri binds:

```bash
cd ~/TQQ-Niri-rice
git pull --ff-only
./scripts/apply-terminal-bind
```

To explicitly choose one when both are installed:

```bash
./scripts/apply-terminal-bind --ghostty
# Or choose Kitty:
./scripts/apply-terminal-bind --kitty
```

The updater backs up `~/.config/niri/config.kdl`, changes only the `Mod+Return` shortcut, and runs `niri validate --config` before applying it. If the existing Niri config is a symlink, the updater leaves it untouched and requires manual integration. Other shortcuts, the Russian/English keyboard layout and terminal settings are preserved.

## Lock screen layout and avatar

The lock screen uses the existing Quickshell Wayland session-lock protocol and PAM authentication. Its wallpaper background uses QtQuick.Effects for strong blur. The preferred shortcut is `Mod+Alt+L` (Win+Alt+L). Its four regions are arranged as follows: **clock/date on the upper left**, **weather on the lower left** (from the same `tqq-region weather` source as Control Center), **calendar on the right**, and a **central user avatar, account name and password field**. The calendar supports changing months; weather refreshes every 15 minutes while locked, with a fallback message when unavailable.

**Control Center:** the stable dashboard now has a compact **LOCK AVATAR / CHOOSE IMAGE** card at the lower right. It launches the external image picker through `tqq-avatar pick` (requires Zenity or KDialog), without adding another QML dialog. Install Zenity on Debian with `sudo apt install zenity`. The preview refreshes after you select a new image.

You can also set the lock-screen avatar using the included helper: `~/.local/bin/tqq-avatar set /absolute/path/to/photo.png` (or `tqq-avatar pick` if Zenity/KDialog is installed). Accepted images are PNG, JPEG or WebP and at most 12 MB. The image is copied into `~/.local/share/tqq-niri-rice/`, and the lock screen reads its location through `tqq-avatar get`. No credentials are stored in the avatar helper; PAM still handles the password.

To update **only** the lock screen and Control Center (without reinstalling TQQ or altering Niri bindings):

```bash
cd ~/TQQ-Niri-rice
git pull --ff-only
./scripts/update-lockscreen
```

Close and reopen Control Center after applying. The updater backs up the previous QML files and helper under `~/.local/state/tqq-niri-rice/backups/lock-screen-*`. **Important:** The lock QML has been reorganized so the `WlSessionLock` contains exactly one `WlSessionLockSurface`; the wallpaper/weather/PAM services live in an outer `Scope`. The lock launcher writes diagnostics to `~/.local/state/tqq-niri-rice/lockscreen.log`. The script update includes the launcher, both QML files and the avatar helper. Because this is a real session lock, test it only when you know your working account password; a Quickshell error can leave the compositor's lock active until the session is recovered.

## Optional Kitty / Ghostty terminal themes

Two independent terminal themes ship with TQQ:

- Kitty: `config/kitty/tqq.conf` and `config/kitty/tqq-colors.conf`
- Ghostty: `config/ghostty/tqq.conf` and `config/ghostty/tqq-colors.conf`

To update an existing TQQ installation **without running the full rice installer**:

```bash
cd ~/TQQ-Niri-rice
git pull --ff-only
./scripts/setup-terminal-themes --all
```

`--all` prepares **both** terminal configs (even if Ghostty is not yet installed); `--kitty` or `--ghostty` enables just one; `--auto` enables only terminals already installed. The normal TQQ installer uses `--auto`. This tool does not install or uninstall terminal packages.

The script preserves existing `~/.config/kitty/kitty.conf` and Ghostty `config.ghostty` / `config` contents, adds only `include tqq.conf` or `config-file = tqq.conf`, and backs up changed files under `~/.local/state/tqq-niri-rice/backups/terminals-*`. It also backs up and refreshes an already-installed, identifiable TQQ `select-wallpaper` helper so terminal palette reloads work immediately. It never follows or overwrites symlinked main configs. If you use a symlink-managed dotfiles setup, add the include yourself. For Ghostty, the older `config` takes precedence when both files exist, so TQQ uses it for the include.

Matugen writes colors to `~/.config/kitty/tqq-colors.conf` and `~/.config/ghostty/tqq-colors.conf` when you change wallpapers through TQQ. Kitty reloads via `SIGUSR1` and Ghostty via its systemd user service or `SIGUSR2`. The theme uses about 90% opaque backgrounds. **Transparency is not blur:** stock Niri does not provide Ghostty's supported KDE/macOS application blur integration, so the theme doesn't claim to provide it. Window border gradients are handled separately by TQQ WindowFX.

To opt out, remove `include tqq.conf` from Kitty's main config or `config-file = tqq.conf` from Ghostty's main config. No user data is deleted.

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
| Terminal (automatically selected Kitty or Ghostty) | `Mod+Return` / **Win+Enter** |
| Wallpaper gallery and Matugen palette | `Mod+B` |
| Dashboard / Control Center | `Mod+Shift+Space` (free fallback if occupied) |
| Application launcher | Waybar magnifying glass, or `Mod+D` |
| Wi-Fi panel | `Mod+N` (free fallback if occupied) |
| Lock screen | `Mod+Alt+L` (installer fallback if occupied) |
| Radial window switcher | Hold `Alt`, press `Tab` / `Shift+Tab`, release Alt to confirm |
| Workspaces | `Mod+1` through `Mod+9`; move the focused column with `Mod+Ctrl+1` through `Mod+Ctrl+9` |
| Screenshot | `Print`: select area; `Ctrl+Print`: full screen; `Alt+Print`: window; free fallback `Mod+Shift+S` |
| Volume | Laptop volume keys (`XF86AudioRaiseVolume`, `XF86AudioLowerVolume`, `XF86AudioMute`) through `wpctl` |

The installer preserves existing Niri settings and unrelated keybindings. It reserves Alt+Tab and Alt+Shift+Tab for the TQQ radial switcher. It restores missing workspace, screenshot and volume binds, but leaves existing shortcuts in place. Niri uses dynamic workspaces, so `Mod+9` goes to the last available workspace rather than creating nine fixed desktops. To apply new keybindings without rebuilding Rust, update the repository, back up `~/.config/niri/config.kdl`, run `python3 scripts/integrate-niri.py ~/.config/niri/config.kdl ~/.local/bin` and then `niri validate`.

## Project layout

- `quickshell/tqq-dashboard/` — Control Center and embedded power menu.
- `quickshell/tqq-launcher/` — expanding application launcher.
- `quickshell/tqq-wifi/` — Wi-Fi picker.
- `quickshell/tqq-lock/` — secure PAM-authenticated lock screen with profile, clock, weather and calendar.
- `quickshell/tqq-switcher/` — radial Alt+Tab selector.
- `wallpaper-gallery/` — native Rust/GTK4 wallpaper gallery.
- `config/kitty/` and `config/ghostty/` — optional terminal themes and starter palettes.
- `config/fastfetch/` — boxed Fastfetch theme and its wallpaper-derived colors.
- `config/matugen/` — wallpaper-derived palette templates.
- `config/dunst/` and `config/waybar/` — notification and bar styling.
- `scripts/` — installers, launchers, wallpaper handling, and Niri integration helpers.
- `wallpapers/` — included TQQ wallpaper collection.
