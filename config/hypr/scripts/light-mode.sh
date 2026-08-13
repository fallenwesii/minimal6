#!/usr/bin/env bash

awww_cache="$HOME/.cache/awww"
state_file="$HOME/.cache/matugen_mode"

cache_file=$(find "$awww_cache" -type f -print -quit)

if [[ ! -f "$cache_file" ]]; then
  echo "Could not find awww wallpaper cache."
  exit 1
fi

wallpaper=$(sed "s|.*\($HOME/.*\)|\1|" "$cache_file")

if [[ ! -f "$wallpaper" ]]; then
  echo "Could not find current wallpaper: $wallpaper"
  exit 1
fi

# Ensure parent directory exists if ~/.cache was removed
mkdir -p "$(dirname "$state_file")"

# If state file exists AND contains "outdoor", switch to Normal Mode.
# If missing, deleted, or set to "normal", switch to Outdoor Mode and create state file.
if [[ -f "$state_file" ]] && [[ $(cat "$state_file") == "dark" ]]; then
  # Switch to Normal Mode
  matugen image "$wallpaper" \
    --mode light \
    --source-color-index 0 \
    --lightness-light 0

  echo "light" >"$state_file"

  if command -v notify-send &>/dev/null; then
    notify-send -a "Matugen" -i "style" "Theme Mode" "Switched to Light Mode"
  fi
else
  # Switch to dark Mode (default fallback if state file is missing)
  matugen image "$wallpaper" \
    --mode dark \
    --source-color-index 0 \
    --contrast 0 \
    --lightness-dark 0.08
  # --opacity 0.95

  echo "dark" >"$state_file"

  if command -v notify-send &>/dev/null; then
    notify-send -a "Matugen" -i "style" "Theme Mode" "Switched to dark mode"
  fi
fi
