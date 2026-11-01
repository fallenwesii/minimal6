#!/usr/bin/env bash

# Toggle maximize: fills screen keeping waybar, toggles back to tiling
if swaymsg -t get_tree | grep -q '"_maximized"'; then
  swaymsg '[con_mark="_maximized"] floating disable, unmark _maximized'
else
  swaymsg 'mark --add _maximized, floating enable, resize set width 100ppt height 100ppt, move position center'
fi
