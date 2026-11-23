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
  --skip-deps     Skip the dependency prompt and print the checker command.
USAGE
}

for script in \
    "$ROOT/install.sh" \
    "$ROOT/scripts/check-dependencies" \
    "$ROOT/scripts/install-dependencies" \
    "$ROOT/scripts/build-wallpaper-gallery" \
    "$ROOT/scripts/build-squishy-shaders"; do
    if ! bash -n "$script"; then
        echo "Shell syntax validation failed: $script" >&2
        exit 1
    fi
done

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
        read -r -p "Install the missing dependencies now? [y/N] " answer || answer=""
        case "$answer" in
            y|Y|yes|YES) "$ROOT/scripts/install-dependencies" ;;
            *) echo "Dependency installation skipped. Run $ROOT/scripts/install-dependencies or install.sh --install-deps later." ;;
        esac
    else
        echo "Dependency installation skipped in non-interactive mode. Run $ROOT/scripts/install-dependencies or install.sh --install-deps." >&2
    fi
fi

mkdir -p "$BACKUP" "$LOCAL_BIN" "$DATA_HOME/tqq-niri-rice/wallpapers" "$CONFIG_HOME/tqq-niri-rice"

# Compile Quickshell GPU shaders before changing the installed configuration.
bash "$ROOT/scripts/build-squishy-shaders" \
    "$ROOT/quickshell/tqq-squishy" \
    "$BACKUP/squishy-shaders"

# Install the Quickshell applications into their standard config directory.
# Existing TQQ app configs are backed up before project files are updated.
QUICKSHELL_CONFIG="$CONFIG_HOME/quickshell"
mkdir -p "$QUICKSHELL_CONFIG" "$BACKUP/config/quickshell"
for source_config in "$ROOT"/quickshell/*; do
    [[ -d "$source_config" ]] || continue
    config_name="$(basename "$source_config")"
    target_config="$QUICKSHELL_CONFIG/$config_name"
    if [[ -e "$target_config" ]]; then
        cp -a "$target_config" "$BACKUP/config/quickshell/$config_name"
    fi
    mkdir -p "$target_config"
    cp -a "$source_config/." "$target_config/"
done

# ShaderEffect loads these compiled files relative to the installed Squishy config.
install -m 0644 "$BACKUP/squishy-shaders/squishy.vert.qsb" "$QUICKSHELL_CONFIG/tqq-squishy/squishy.vert.qsb"
install -m 0644 "$BACKUP/squishy-shaders/squishy.frag.qsb" "$QUICKSHELL_CONFIG/tqq-squishy/squishy.frag.qsb"

# Build and install the native Rust wallpaper gallery.
if [[ -e "$LOCAL_BIN/tqq-wallpaper-gallery" ]]; then
    mkdir -p "$BACKUP/local-bin"
    cp -a "$LOCAL_BIN/tqq-wallpaper-gallery" "$BACKUP/local-bin/tqq-wallpaper-gallery"
fi
bash "$ROOT/scripts/build-wallpaper-gallery" "$LOCAL_BIN/tqq-wallpaper-gallery"

cp -an "$ROOT/wallpapers/." "$DATA_HOME/tqq-niri-rice/wallpapers/"

# Install only the launchers and helpers used by the current Quickshell setup.
for script_name in \
    select-wallpaper tqq-dashboard tqq-launcher tqq-wifi tqq-switcher \
    tqq-squishy tqq-region tqq-lock-screen configure-fetch-autostart \
    check-dependencies install-dependencies configure-swaync.py; do
    source_file="$ROOT/scripts/$script_name"
    if [[ ! -f "$source_file" ]]; then
        echo "Required project script is missing: $source_file" >&2
        exit 1
    fi
    if [[ -e "$LOCAL_BIN/$script_name" ]]; then
        mkdir -p "$BACKUP/local-bin"
        cp -a "$LOCAL_BIN/$script_name" "$BACKUP/local-bin/$script_name"
    fi
    install -m 0755 "$source_file" "$LOCAL_BIN/$script_name"
done

if [[ -e "$LOCAL_BIN/integrate-niri.py" ]]; then
    mkdir -p "$BACKUP/local-bin"
    cp -a "$LOCAL_BIN/integrate-niri.py" "$BACKUP/local-bin/integrate-niri.py"
fi
install -m 0755 "$ROOT/scripts/integrate-niri.py" "$LOCAL_BIN/integrate-niri.py"

NIRI_CONFIG="$CONFIG_HOME/niri/config.kdl"
NIRI_CONFIG_BACKED_UP=0
mkdir -p "$CONFIG_HOME/niri" "$BACKUP/config/niri"

# If an older TQQ release replaced the whole config, restore the latest
# available user config backup before integrating the current TQQ bindings.
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
        echo "Restored the previous Niri config from $previous_config before adding TQQ bindings."
    else
        echo "Warning: generated TQQ config found, but no original Niri backup was found." >&2
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
    echo "Niri config integration failed; restored the previous config when available." >&2
    exit 1
fi

if command -v niri >/dev/null 2>&1 && ! niri validate; then
    if ((NIRI_CONFIG_BACKED_UP)); then
        cp -a "$BACKUP/config/niri/config.kdl" "$NIRI_CONFIG"
    else
        rm -f -- "$NIRI_CONFIG"
    fi
    echo "Niri validation failed; restored the previous config when available." >&2
    exit 1
fi

# Seed the first wallpaper only if the user has not selected one before.
STATE_FILE="$STATE_HOME/tqq-niri-rice/current-wallpaper"
if [[ ! -s "$STATE_FILE" ]]; then
    first_wallpaper="$(find "$DATA_HOME/tqq-niri-rice/wallpapers" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit)"
    if [[ -n "$first_wallpaper" ]]; then
        mkdir -p "$(dirname "$STATE_FILE")"
        printf '%s\n' "$first_wallpaper" > "$STATE_FILE"
    fi
fi

"$LOCAL_BIN/configure-swaync.py" "$CONFIG_HOME/swaync/config.json"
"$LOCAL_BIN/configure-fetch-autostart"

if [[ -s "$STATE_FILE" ]]; then
    if ! "$LOCAL_BIN/select-wallpaper" --restore; then
        echo "Warning: saved wallpaper could not be applied. Check awww/swaybg and Matugen." >&2
    fi
fi

echo "TQQ Niri rice installed. Dashboard: $LOCAL_BIN/tqq-dashboard (Super+Shift+Space)."
echo "Backup: $BACKUP"
echo "Run $LOCAL_BIN/check-dependencies to check required commands."
