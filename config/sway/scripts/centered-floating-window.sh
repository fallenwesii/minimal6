#!/usr/bin/env bash

# centered-floating-window.sh — Toggle focused window to/from a centered float
#
# In sway, we query the tree via swaymsg to detect if the focused window is
# already floating, then toggle it and resize+center if making it float.

# Get focused node info
FOCUSED=$(swaymsg -t get_tree | python3 -c "
import json, sys
def find_focused(node):
    if node.get('focused'):
        return node
    for c in node.get('nodes', []) + node.get('floating_nodes', []):
        r = find_focused(c)
        if r:
            return r
tree = json.load(sys.stdin)
focused = find_focused(tree)
if focused:
    print(focused.get('type', ''))
    print('floating' if focused.get('type') == 'floating_con' else 'tiled')
" 2>/dev/null)

TYPE=$(echo "$FOCUSED" | head -1)
FLOAT_STATE=$(echo "$FOCUSED" | tail -1)

APPEARANCE="$HOME/.config/sway/conf/appearance.conf"
FLOAT_W=$(awk '/^default_floating_border/{print $3}' "$APPEARANCE")
TILE_W=$(awk '/^default_border/{print $3}' "$APPEARANCE")

# Toggle floating
swaymsg floating toggle

# If the window was NOT floating before, resize and center it
if [ "$FLOAT_STATE" = "tiled" ]; then
  sleep 0.05
  swaymsg resize set 950 600
  swaymsg move position center
fi

# Re-apply border — GTK/Electron apps often lose it when floated
swaymsg "[con_id=__focused__ floating] border pixel ${FLOAT_W:-3}"
swaymsg "[con_id=__focused__ tiling] border pixel ${TILE_W:-3}"
