#!/usr/bin/env bash

# Toggle floating and re-apply border from appearance.conf
# GTK/Electron apps often lose their border when floated since
# for_window rules only match new windows.

APPEARANCE="$HOME/.config/sway/conf/appearance.conf"
FLOAT_W=$(awk '/^default_floating_border/{print $3}' "$APPEARANCE")
TILE_W=$(awk '/^default_border/{print $3}' "$APPEARANCE")

swaymsg floating toggle
swaymsg "[con_id=__focused__ floating] border pixel ${FLOAT_W:-3}"
swaymsg "[con_id=__focused__ tiling] border pixel ${TILE_W:-3}"
