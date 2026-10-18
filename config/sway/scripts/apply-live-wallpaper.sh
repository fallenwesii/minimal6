#!/usr/bin/env bash
# apply-live-wallpaper.sh — show the animated GIF immediately via awww,
# and retheme behind it via matugen using an extracted static frame.
#
# Usage:
#   apply-live-wallpaper.sh <gif_path> [frame_png_path]
#
# Handed to sway via `swaymsg exec` by live-wallpaper-switcher.sh so it keeps
# running after the picker window dies.

set -u

PIDFILE="$HOME/.cache/live-wallpaper-apply.pid"
CACHE_DIR="$HOME/.cache/live-wallpaper-picker"
TRANSITION_DURATION=2

GIF="${1:-}"
FRAME="${2:-}"

if [ -z "$GIF" ] || [ ! -f "$GIF" ]; then
  exit 1
fi

mkdir -p "$CACHE_DIR"

# If no frame PNG was passed or it doesn't exist, resolve or extract one
if [ -z "$FRAME" ] || [ ! -f "$FRAME" ]; then
  BASE_NAME="$(basename "$GIF")"
  STEM="${BASE_NAME%.*}"
  CACHED_FRAME="${CACHE_DIR}/${STEM}.frame.png"

  if [ -f "$CACHED_FRAME" ]; then
    FRAME="$CACHED_FRAME"
  else
    # Extract the first frame as fallback
    ffmpeg -v error -ss 0.5 -i "$GIF" -frames:v 1 -update 1 -y "$CACHED_FRAME" 2>/dev/null || true
    FRAME="$CACHED_FRAME"
  fi
fi

# Cancel a previous still-running apply (guarded: pid recycling can't
# match unless the cmdline really is this script).
if [ -r "$PIDFILE" ]; then
  old="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$old" ] && [ "$old" != "$$" ] &&
    ps -p "$old" -o args= 2>/dev/null | grep -q "apply-live-wallpaper"; then
    pkill -P "$old" 2>/dev/null # its children (matugen/sleep/awww)
    kill "$old" 2>/dev/null
  fi
fi

# Exclusive lock for the rest of this pass.
if command -v flock >/dev/null 2>&1; then
  exec 9>"$HOME/.cache/live-wallpaper-apply.lock"
  flock -w 5 9 || {
    notify-send -a 'Live Wallpaper Picker' 'Wallpaper apply busy' \
      'Another apply is stuck holding the lock' 2>/dev/null
    exit 1
  }
fi

echo $$ >"$PIDFILE"

# Apply animated GIF to desktop
awww img --transition-type grow --transition-duration "$TRANSITION_DURATION" "$GIF" >/dev/null 2>&1 9>&-
sleep "$TRANSITION_DURATION"

# Apply matugen theme using the static frame
if command -v matugen >/dev/null 2>&1 && [ -f "$FRAME" ]; then
  matugen image "$FRAME" -m dark --source-color-index 0 --lightness-dark 0.14 --contrast 0 >/dev/null 2>&1 9>&-
fi

# Keep gsettings in sync (picker always applies a dark palette).
command -v gsettings >/dev/null 2>&1 &&
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

NOTIF_ICON="$GIF"
if [ -f "$FRAME" ]; then
  NOTIF_ICON="$FRAME"
fi

notify-send -a 'Live Wallpaper Picker' -i "$NOTIF_ICON" 'Theme Updated' "Applied live wallpaper: ${GIF##*/}" 2>/dev/null
echo dark >"$HOME/.cache/matugen_mode"
