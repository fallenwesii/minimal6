#!/usr/bin/env bash

# Send focused window to scratchpad (excluding kitty-scratchpad)
FOCUSED=$(swaymsg -t get_tree | jq -r '.. | select(.focused? == true) | select(.type == "con" or .type == "floating_con") | "\(.id)\t\(.app_id // "window")\t\(.name)"')

if [ -z "$FOCUSED" ]; then
  exit 0
fi

WIN_ID=$(echo "$FOCUSED" | cut -f1)
APP_ID=$(echo "$FOCUSED" | cut -f2)
TITLE=$(echo "$FOCUSED" | cut -f3)

if [ "$APP_ID" = "kitty-scratchpad" ]; then
  exit 0
fi

APPEARANCE="$HOME/.config/sway/conf/appearance.conf"
FLOAT_W=$(awk '/^default_floating_border/{print $3}' "$APPEARANCE" 2>/dev/null)

swaymsg "[con_id=$WIN_ID] move scratchpad, resize set 950 600, move position center, border pixel ${FLOAT_W:-3}"
notify-send -a "Scratchpad" -u low -t 2000 "Stashed in scratchpad" "${TITLE:-$APP_ID}"
