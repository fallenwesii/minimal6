#!/usr/bin/env bash
# live-wallpaper-switcher.sh — launcher for the GTK live wallpaper picker
# (live-wallpaper-switcher.py, same directory).
#
# Responsibilities:
#   1. Make sure the gif wallpaper and thumbnail cache directories exist.
#   2. Hand the background cache generation to sway via `swaymsg exec`
#      so it runs detached.
#   3. Exec the GTK picker UI.

set -u

WALLPAPER_DIR="$HOME/Pictures/wallpapers/gif"
CACHE_DIR="$HOME/.cache/live-wallpaper-picker"
UI_SCRIPT="$HOME/.config/sway/scripts/live-wallpaper-switcher.py"

mkdir -p "$WALLPAPER_DIR" "$CACHE_DIR"

if ! swaymsg exec "python3 '$UI_SCRIPT' --generate-cache" >/dev/null 2>&1; then
  python3 "$UI_SCRIPT" --generate-cache >/dev/null 2>&1 &
fi

exec python3 "$UI_SCRIPT" "$@"
