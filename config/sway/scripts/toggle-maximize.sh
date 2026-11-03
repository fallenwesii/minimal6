#!/usr/bin/env bash

# Toggle maximize: fills screen keeping waybar, toggles back to tiling
APPEARANCE="$HOME/.config/sway/conf/appearance.conf"
FLOAT_W=$(awk '/^default_floating_border/{print $3}' "$APPEARANCE" 2>/dev/null)
TILE_W=$(awk '/^default_border/{print $3}' "$APPEARANCE" 2>/dev/null)

if swaymsg -t get_tree | grep -q '"_maximized"'; then
  swaymsg '[con_mark="_maximized"] floating disable'
  swaymsg '[con_mark="_maximized"] unmark _maximized'
  sleep 0.05
  # Some GTK/Electron windows drop their border when leaving floating mode.
  swaymsg '[con_id=__focused__ tiling] border pixel '"${TILE_W:-3}"
else
  swaymsg 'mark --add _maximized'
  swaymsg 'floating enable'
  swaymsg 'resize set width 100ppt height 100ppt'
  swaymsg 'move position center'
  sleep 0.05
  # Re-apply the floating border after the maximize transition.
  swaymsg '[con_id=__focused__ floating] border pixel '"${FLOAT_W:-3}"
fi
