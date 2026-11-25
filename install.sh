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
    "$ROOT/scripts/install-icon-fonts" \
    "$ROOT/scripts/setup-terminal-themes" \
    "$ROOT/scripts/setup-default-terminal" \
    "$ROOT/scripts/apply-terminal-bind" \
    "$ROOT/scripts/tqq-terminal" \
    "$ROOT/scripts/restore-niri-default" \
    "$ROOT/scripts/apply-windowfx" \
    "$ROOT/scripts/build-wallpaper-gallery" \
    "$ROOT/scripts/select-wallpaper" \
    "$ROOT/scripts/tqq-refresh-rice" \
    "$ROOT/scripts/tqq-dashboard" \
    "$ROOT/scripts/tqq-launcher" \
    "$ROOT/scripts/tqq-wifi" \
    "$ROOT/scripts/tqq-switcher" \
    "$ROOT/scripts/tqq-lock-screen" \
    "$ROOT/scripts/update-lockscreen" \
    "$ROOT/scripts/setup-fastfetch" \
    "$ROOT/scripts/configure-fastfetch-autostart"; do
    if ! bash -n "$script"; then
        echo "Shell syntax validation failed: $script" >&2
        exit 1
    fi
done

# Compile Python helpers in memory so syntax checks do not leave __pycache__ files.
python3 - "$ROOT/scripts/integrate-niri.py" "$ROOT/scripts/tqq-avatar" <<'PYCHECK'
from pathlib import Path
import sys

for filename in sys.argv[1:]:
    source = Path(filename).read_text()
    compile(source, filename, "exec")
print("Python helper syntax validation passed.")
PYCHECK

for arg in "$@"; do
    case "$arg" in
        --install-deps) INSTALL_DEPS=1 ;;
        --skip-deps) SKIP_DEPS=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

# Niri creates a complete example config when it first starts.
# Avoid creating a nearly empty TQQ-only config before that happens.
EXISTING_NIRI_CONFIG="$CONFIG_HOME/niri/config.kdl"
if [[ ! -s "$EXISTING_NIRI_CONFIG" ]]; then
    echo "No Niri config found at $EXISTING_NIRI_CONFIG." >&2
    echo "Start Niri once to generate its complete default config, then rerun the installer." >&2
    echo "For Niri v26.04, use scripts/restore-niri-default to recover the full config with TQQ." >&2
    exit 1
fi

# One in-place progress bar. Percentages mean completed install stages, not elapsed time.
PROGRESS=0
PROGRESS_SPINNER_PID=""
INSTALL_LOG=""

progress_render() {
    local percent="$1" label="$2" pulse="${3:-}"
    local filled=$((percent * 24 / 100))
    local full empty
    printf -v full '%*s' "$filled" ''
    full="${full// /#}"
    printf -v empty '%*s' "$((24 - filled))" ''
    empty="${empty// /-}"
    if [[ -t 2 ]]; then
        printf '\r\033[2K[TQQ] [%s%s] %3d%% %s %s' "$full" "$empty" "$percent" "$label" "$pulse" >&2
    else
        printf '[TQQ] [%s%s] %3d%% %s\n' "$full" "$empty" "$percent" "$label" >&2
    fi
}
progress_mark() {
    PROGRESS="$1"
    progress_render "$PROGRESS" "$2"
}
progress_stop_spinner() {
    if [[ -n "$PROGRESS_SPINNER_PID" ]]; then
        kill "$PROGRESS_SPINNER_PID" 2>/dev/null || true
        wait "$PROGRESS_SPINNER_PID" 2>/dev/null || true
        PROGRESS_SPINNER_PID=""
    fi
}
progress_run() {
    local percent="$1" label="$2"
    shift 2
    progress_render "$PROGRESS" "$label"
    if [[ -t 2 ]]; then
        (
            local frames=('|' '/' '-' '\') index=0
            while :; do
                progress_render "$PROGRESS" "$label" "${frames[index % ${#frames[@]}]}"
                index=$((index + 1))
                sleep 0.25
            done
        ) &
        PROGRESS_SPINNER_PID=$!
    fi
    if "$@" >> "$INSTALL_LOG" 2>&1; then
        progress_stop_spinner
        progress_mark "$percent" "$label"
    else
        local status=$?
        progress_stop_spinner
        printf '\n[TQQ] Failed at: %s (exit %s). Last 40 log lines:\n' "$label" "$status" >&2
        tail -n 40 "$INSTALL_LOG" >&2
        return "$status"
    fi
}
progress_finish() {
    progress_stop_spinner
    if [[ -t 2 ]]; then printf '\n' >&2; fi
}
trap progress_finish EXIT

progress_mark 10 "Checking dependencies"

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

progress_mark 20 "Dependencies checked"
mkdir -p "$BACKUP" "$LOCAL_BIN" "$DATA_HOME/tqq-niri-rice/wallpapers" "$CONFIG_HOME/tqq-niri-rice"
INSTALL_LOG="$BACKUP/install.log"
: > "$INSTALL_LOG"
progress_mark 25 "Preparing installation"

# Install the shipped desktop configs (Dunst, Matugen and Waybar).
# Existing config directories are backed up before TQQ files are merged in.
mkdir -p "$BACKUP/config"
for config_name in matugen dunst waybar; do
    source_config="$ROOT/config/$config_name"
    target_config="$CONFIG_HOME/$config_name"
    [[ -d "$source_config" ]] || continue
    if [[ -e "$target_config" ]]; then
        cp -a "$target_config" "$BACKUP/config/$config_name"
    fi
    mkdir -p "$target_config"
    cp -a "$source_config/." "$target_config/"
done
progress_mark 45 "Installing desktop configs"

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

progress_mark 52 "Installing Quickshell apps"

# Theme terminals when installed; never install terminal packages or replace
# personal kitty.conf / Ghostty configuration. Backups are written by helper.
if ! bash "$ROOT/scripts/setup-terminal-themes" --auto; then
    echo "Warning: optional terminal theming skipped; TQQ desktop setup continues." >&2
fi

# Select Kitty or Ghostty for the Win+Enter launcher. The helper asks which
# one to use if both exist, and keeps a previously selected preference.
if ! bash "$ROOT/scripts/setup-default-terminal" --auto; then
    echo "Warning: install Kitty or Ghostty to activate Win+Enter." >&2
fi

# Install Fastfetch's four boxed info groups without replacing user data.
if ! bash "$ROOT/scripts/setup-fastfetch"; then
    echo "Warning: optional TQQ Fastfetch styling skipped." >&2
fi

# Build and install the native Rust wallpaper gallery.
if [[ -e "$LOCAL_BIN/tqq-wallpaper-gallery" ]]; then
    mkdir -p "$BACKUP/local-bin"
    cp -a "$LOCAL_BIN/tqq-wallpaper-gallery" "$BACKUP/local-bin/tqq-wallpaper-gallery"
fi
progress_run 75 "Building Rust wallpaper gallery" bash "$ROOT/scripts/build-wallpaper-gallery" "$LOCAL_BIN/tqq-wallpaper-gallery"

cp -an "$ROOT/wallpapers/." "$DATA_HOME/tqq-niri-rice/wallpapers/"
progress_mark 79 "Copying wallpapers"

# Install only the launchers and helpers used by the current Quickshell setup.
for script_name in \
    select-wallpaper tqq-refresh-rice tqq-dashboard tqq-launcher tqq-wifi tqq-switcher \
    tqq-region tqq-lock-screen tqq-avatar configure-fastfetch-autostart \
    check-dependencies install-dependencies install-icon-fonts restore-niri-default; do
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
progress_mark 85 "Installing launchers"

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
progress_mark 91 "Validating Niri config"

# Enable native Niri borders and animations using a tiny Rust palette generator.
# This is optional so a visual enhancement cannot break the basic rice install.
if ! bash "$ROOT/scripts/apply-windowfx"; then
    echo "Warning: TQQ WindowFX could not be enabled; your working Niri config was preserved." >&2
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

"$LOCAL_BIN/configure-fastfetch-autostart"
progress_mark 95 "Configuring desktop services"

if [[ -s "$STATE_FILE" ]]; then
    if ! progress_run 98 "Applying wallpaper" "$LOCAL_BIN/select-wallpaper" --restore; then
        echo "Warning: saved wallpaper could not be applied. Check awww/swaybg." >&2
    fi
    if ! progress_run 99 "Applying desktop colors" "$LOCAL_BIN/tqq-refresh-rice" --startup; then
        echo "Warning: palette could not be applied. Check Matugen." >&2
    fi
fi

progress_mark 100 "Installation complete"
progress_finish
trap - EXIT

echo "TQQ Niri rice installed. Dashboard: $LOCAL_BIN/tqq-dashboard (Super+Shift+Space)."
echo "Backup: $BACKUP"
echo "Installation log: $INSTALL_LOG"
echo "Run $LOCAL_BIN/check-dependencies to check required commands."
