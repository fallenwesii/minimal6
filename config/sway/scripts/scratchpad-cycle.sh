#!/usr/bin/env bash

# Cycle through scratchpad windows (excluding kitty-scratchpad)
TREE=$(swaymsg -t get_tree)

# Collect all non-kitty scratchpad window IDs
mapfile -t WIN_IDS < <(echo "$TREE" | jq -r '
  [.. | select(.scratchpad_state? and .scratchpad_state != "none" and .app_id != "kitty-scratchpad")]
  | map(.id) | .[]
')

COUNT=${#WIN_IDS[@]}

if [ "$COUNT" -eq 0 ]; then
  notify-send -a "Scratchpad" -u low -t 2000 "Scratchpad is empty" "Press Super+Ctrl+A to stash a window"
  exit 0
fi

APPEARANCE="$HOME/.config/sway/conf/appearance.conf"
FLOAT_W=$(awk '/^default_floating_border/{print $3}' "$APPEARANCE" 2>/dev/null)

if [ "$COUNT" -eq 1 ]; then
  swaymsg "[con_id=${WIN_IDS[0]}] scratchpad show, resize set 950 600, move position center, border pixel ${FLOAT_W:-3}"
  exit 0
fi

# Find if one of the scratchpad windows is currently focused
FOCUSED_ID=$(echo "$TREE" | jq -r '.. | select(.focused? == true) | .id')

NEXT_ID="${WIN_IDS[0]}"
for i in "${!WIN_IDS[@]}"; do
  if [ "${WIN_IDS[$i]}" = "$FOCUSED_ID" ]; then
    NEXT_INDEX=$(( (i + 1) % COUNT ))
    NEXT_ID="${WIN_IDS[$NEXT_INDEX]}"
    break
  fi
done

swaymsg "[con_id=$NEXT_ID] scratchpad show, resize set 950 600, move position center, border pixel ${FLOAT_W:-3}"
