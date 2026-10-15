#!/usr/bin/env bash
# wallpaper-switcher.sh — launcher for the GTK wallpaper picker
# (wallpaper-switcher.py, same directory).
#
# Responsibilities:
#   1. Make sure the thumbnail cache directory exists.
#   2. Hand the long-running cache generation to sway via `swaymsg exec`
#      so it keeps running after the picker window is closed.
#   3. exec the GTK picker UI on top of this process (the keybind points
#      here, so the PID file toggle still lands on this entry point).

set -u

CACHE_DIR="$HOME/.cache/wallpaper-picker"
UI_SCRIPT="$HOME/.config/sway/scripts/wallpaper-switcher.py"

# 1. Cache directory must exist before anything runs
mkdir -p "$CACHE_DIR"

# 2. Cache generation handed to sway; falls back to a local background
#    job only if sway IPC is unavailable (e.g. running outside a session)
if ! swaymsg exec "python3 '$UI_SCRIPT' --generate-cache" >/dev/null 2>&1; then
  python3 "$UI_SCRIPT" --generate-cache >/dev/null 2>&1 &
fi

# 3. UI
exec python3 "$UI_SCRIPT" "$@"
