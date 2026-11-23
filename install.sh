#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
BACKUP="$STATE_HOME/tqq-niri-rice/backups/$(date +%Y%m%d-%H%M%S)"
INSTALL_DEPS=0
SKIP_DEPS=0

usage() {
    cat <<'USAGE'
Usage: ./install.sh [--install-deps | --skip-deps]

  --install-deps  Install missing system dependencies using the distro package manager.
  --skip-deps     Do not ask about dependencies; print the checker command instead.
USAGE
}

for arg in "$@"; do
    case "$arg" in
        --install-deps) INSTALL_DEPS=1 ;;
        --skip-deps) SKIP_DEPS=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

if ((INSTALL_DEPS)); then
    "$ROOT/scripts/install-dependencies"
elif ((!SKIP_DEPS)) && ! "$ROOT/scripts/check-dependencies"; then
    if [[ -t 0 ]]; then
        read -r -p "Install the missing dependencies now? [y/N] " answer
        case "$answer" in
            y|Y|yes|YES) "$ROOT/scripts/install-dependencies" ;;
            *) echo "Dependency installation skipped. Run $ROOT/scripts/install-dependencies or install.sh --install-deps later." ;;
        esac
    else
        echo "Dependency installation skipped in non-interactive mode. Run $ROOT/scripts/install-dependencies or install.sh --install-deps." >&2
    fi
fi

mkdir -p "$BACKUP" "$LOCAL_BIN" "$DATA_HOME/tqq-niri-rice/wallpapers" "$CONFIG_HOME/tqq-niri-rice"

# Build and install the native Rust wallpaper gallery.
if [[ -e "$LOCAL_BIN/tqq-wallpaper-gallery" ]]; then
    mkdir -p "$BACKUP/local-bin"
    cp -a "$LOCAL_BIN/tqq-wallpaper-gallery" "$BACKUP/local-bin/tqq-wallpaper-gallery"
fi
bash "$ROOT/scripts/build-wallpaper-gallery" "$LOCAL_BIN/tqq-wallpaper-gallery"

# Retire the previous Python gallery modules after preserving a backup.
for legacy_script in wallpaper-picker.py wallpaper_gallery_ui.py; do
    if [[ -e "$LOCAL_BIN/$legacy_script" ]]; then
        mkdir -p "$BACKUP/local-bin"
        cp -a "$LOCAL_BIN/$legacy_script" "$BACKUP/local-bin/$legacy_script"
        rm -f -- "$LOCAL_BIN/$legacy_script"
    fi
done

backup_config_dir() {
    local name="$1"
    if [[ -d "$CONFIG_HOME/$name" ]]; then
        mkdir -p "$BACKUP/config/$name"
        cp -a "$CONFIG_HOME/$name/." "$BACKUP/config/$name/"
    fi
}

# Copy only config directories that actually exist in the repository. Quickshell
# lives at the repository root (./quickshell), not under ./config/quickshell.
for config_name in matugen swaync fuzzel fetch gtklock waybar; do
    source_dir="$ROOT/config/$config_name"
    [[ -d "$source_dir" ]] || continue
    backup_config_dir "$config_name"
    mkdir -p "$CONFIG_HOME/$config_name"
    cp -a "$source_dir/." "$CONFIG_HOME/$config_name/"
done

if [[ -d "$ROOT/quickshell" ]]; then
    backup_config_dir quickshell
    mkdir -p "$CONFIG_HOME/quickshell"
    cp -a "$ROOT/quickshell/." "$CONFIG_HOME/quickshell/"
fi

# Rofi was used by an earlier setup; retain a backup, then remove the old config.
if [[ -d "$CONFIG_HOME/rofi" ]]; then
    backup_config_dir rofi
    rm -rf -- "$CONFIG_HOME/rofi"
fi

if [[ "$CONFIG_HOME" != "$HOME/.config" ]]; then
    python3 - "$CONFIG_HOME" "$CONFIG_HOME/matugen/config.toml" "$CONFIG_HOME/fuzzel/fuzzel.ini" <<'PYXDG'
from pathlib import Path
import sys

config_home = sys.argv[1]
for raw_path in sys.argv[2:]:
    path = Path(raw_path)
    content = path.read_text()
    path.write_text(content.replace("~/.config", config_home))
PYXDG
fi

cp -an "$ROOT/wallpapers/." "$DATA_HOME/tqq-niri-rice/wallpapers/"

for script_name in select-wallpaper power-menu tqq-dashboard tqq-launcher tqq-wifi tqq-region tqq-lock-screen configure-fetch-autostart check-dependencies install-dependencies configure-swaync.py; do
    if [[ -e "$LOCAL_BIN/$script_name" ]]; then
        mkdir -p "$BACKUP/local-bin"
        cp -a "$LOCAL_BIN/$script_name" "$BACKUP/local-bin/$script_name"
    fi
    install -m 0755 "$ROOT/scripts/$script_name" "$LOCAL_BIN/$script_name"
done

if [[ -e "$LOCAL_BIN/wifi-menu.py" ]]; then
    mkdir -p "$BACKUP/local-bin"
    cp -a "$LOCAL_BIN/wifi-menu.py" "$BACKUP/local-bin/wifi-menu.py"
    rm -f -- "$LOCAL_BIN/wifi-menu.py"
fi

if [[ -e "$LOCAL_BIN/integrate-niri.py" ]]; then
    mkdir -p "$BACKUP/local-bin"
    cp -a "$LOCAL_BIN/integrate-niri.py" "$BACKUP/local-bin/integrate-niri.py"
fi
install -m 0755 "$ROOT/scripts/integrate-niri.py" "$LOCAL_BIN/integrate-niri.py"

NIRI_CONFIG="$CONFIG_HOME/niri/config.kdl"
NIRI_CONFIG_BACKED_UP=0
mkdir -p "$CONFIG_HOME/niri" "$BACKUP/config/niri"

# A previous rice installer replaced the full Niri file. If that generated file
# is still active, recover the newest user config backup before integrating binds.
if [[ -f "$NIRI_CONFIG" ]] && grep -q '^// TQQ Niri Rice configuration\.' "$NIRI_CONFIG"; then
    previous_config=""
    backup_root="$STATE_HOME/tqq-niri-rice/backups"
    if [[ -d "$backup_root" ]]; then
        while IFS= read -r candidate; do
            if ! grep -q '^// TQQ Niri Rice configuration\.' "$candidate"; then
                previous_config="$candidate"
                break
            fi
        done < <(find "$backup_root" -type f -path '*/config/niri/config.kdl' -print | LC_ALL=C sort -r)
    fi
    if [[ -n "$previous_config" ]]; then
        cp -a "$previous_config" "$NIRI_CONFIG"
        echo "Restored the previous Niri config from $previous_config before adding rice binds."
    else
        echo "Warning: this is a generated TQQ config and no original Niri backup was found; existing user binds cannot be recovered automatically." >&2
    fi
fi

if [[ -e "$NIRI_CONFIG" ]]; then
    cp -a "$NIRI_CONFIG" "$BACKUP/config/niri/config.kdl"
    NIRI_CONFIG_BACKED_UP=1
fi
if ! python3 "$LOCAL_BIN/integrate-niri.py" "$NIRI_CONFIG" "$LOCAL_BIN"; then
    if ((NIRI_CONFIG_BACKED_UP)); then
        cp -a "$BACKUP/config/niri/config.kdl" "$NIRI_CONFIG"
    else
        rm -f -- "$NIRI_CONFIG"
    fi
    echo "Niri config generation failed; restored the previous config when available. Backup: $BACKUP/config/niri/config.kdl" >&2
    exit 1
fi
if command -v niri >/dev/null 2>&1 && ! niri validate; then
    if ((NIRI_CONFIG_BACKED_UP)); then
        cp -a "$BACKUP/config/niri/config.kdl" "$NIRI_CONFIG"
    else
        rm -f -- "$NIRI_CONFIG"
    fi
    echo "Niri validation failed; restored the previous config when available. Backup: $BACKUP/config/niri/config.kdl" >&2
    exit 1
fi

# Seed the first wallpaper only when the user has not selected one before.
WALLPAPER_STATE_HOME="$STATE_HOME/tqq-niri-rice"
STATE_FILE="$WALLPAPER_STATE_HOME/current-wallpaper"
if [[ ! -s "$STATE_FILE" ]]; then
    first_wallpaper="$(find "$DATA_HOME/tqq-niri-rice/wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit)"
    if [[ -n "$first_wallpaper" ]]; then
        mkdir -p "$WALLPAPER_STATE_HOME"
        printf '%s\n' "$first_wallpaper" > "$STATE_FILE"
    fi
fi

if [[ -e "$HOME/.bashrc" || "$(basename "${SHELL:-bash}")" == bash ]]; then
    [[ ! -f "$HOME/.bashrc" ]] || cp -a "$HOME/.bashrc" "$BACKUP/bashrc"
fi
if [[ -e "$HOME/.zshrc" || "$(basename "${SHELL:-bash}")" == zsh ]]; then
    [[ ! -f "$HOME/.zshrc" ]] || cp -a "$HOME/.zshrc" "$BACKUP/zshrc"
fi
"$LOCAL_BIN/configure-swaync.py" "$CONFIG_HOME/swaync/config.json"
"$LOCAL_BIN/configure-fetch-autostart"

# Apply the saved (or newly seeded) wallpaper now, regenerate Matugen colors,
# and refresh running Waybar/SwayNC instances instead of waiting for a Niri restart.
if [[ -s "$STATE_FILE" ]]; then
    if ! "$LOCAL_BIN/select-wallpaper" --restore; then
        echo "Warning: the saved wallpaper could not be applied. Run $LOCAL_BIN/select-wallpaper --restore after checking awww/swaybg and Matugen." >&2
    fi
fi

echo "TQQ Niri rice installed. Dashboard: $LOCAL_BIN/tqq-dashboard (Super+Shift+Space). Backup: $BACKUP"
echo "Run $LOCAL_BIN/check-dependencies to see whether required commands are available."
