#!/usr/bin/env bash

# Approximate a conventional maximize while keeping Sway's bar visible.
# Sway has no native maximize state, so this temporarily makes the focused
# window floating and gives it the focused workspace's exact work-area size.
# Applications may still refuse a size larger than their own size hints.
set -euo pipefail

APPEARANCE="$HOME/.config/sway/conf/appearance.conf"
FLOAT_W=$(awk '/^default_floating_border/{print $3}' "$APPEARANCE" 2>/dev/null || true)
TILE_W=$(awk '/^default_border/{print $3}' "$APPEARANCE" 2>/dev/null || true)

TREE=$(swaymsg -r -t get_tree)

# Do not test the whole tree for the mark: another maximized window may exist
# on another workspace.  Always operate on the currently focused container.
read -r CON_ID CON_TYPE CON_X CON_Y CON_W CON_H < <(
    jq -r '
        [.. | objects
          | select((.type == "con" or .type == "floating_con")
                   and .focused == true)] | first
        | "\(.id) \(.type) \(.rect.x) \(.rect.y) \(.rect.width) \(.rect.height)"
    ' <<<"$TREE"
) || true

if [[ -z "${CON_ID:-}" || "$CON_ID" == "null" ]]; then
    exit 0
fi

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/minimal6-${UID}"
STATE_FILE="$STATE_DIR/maximized-$CON_ID"
mkdir -p "$STATE_DIR"

if swaymsg -r -t get_tree | jq -e --arg id "$CON_ID" '
    first(.. | objects | select((.id | tostring) == $id))
    | (.marks // []) | index("_maximized") != null
' >/dev/null; then
    # Restore the state from before maximize.  Windows that were already
    # floating should stay floating; tiled windows return to the tiling tree.
    if [[ -s "$STATE_FILE" ]] && read -r WAS_FLOATING OLD_X OLD_Y OLD_W OLD_H < "$STATE_FILE"; then
        if [[ "$WAS_FLOATING" == "floating_con" ]]; then
            swaymsg "floating enable; resize set width ${OLD_W}px height ${OLD_H}px; move absolute position ${OLD_X}px ${OLD_Y}px"
        else
            swaymsg 'floating disable'
        fi
    else
        swaymsg 'floating disable'
    fi

    swaymsg 'unmark _maximized'
    if [[ "${WAS_FLOATING:-}" == "floating_con" ]]; then
        swaymsg "border pixel ${FLOAT_W:-3}"
    else
        swaymsg "border pixel ${TILE_W:-3}"
    fi
    rm -f "$STATE_FILE"
    exit 0
fi

# Save the original geometry so maximizing an already-floating window does
# not destroy its carefully positioned size and location.
printf '%s %s %s %s %s\n' \
    "$CON_TYPE" "$CON_X" "$CON_Y" "$CON_W" "$CON_H" >"$STATE_FILE"

# The focused workspace rect is the usable area after bars.  Explicit pixels
# are more reliable than 100ppt for mixed-DPI and multi-output setups.
read -r WORK_X WORK_Y WORK_W WORK_H < <(
    jq -r '
        [.. | objects
          | select(.type == "workspace" and .focused == true) | .rect] | first
        | "\(.x) \(.y) \(.width) \(.height)"
    ' <<<"$TREE" || true
)

if [[ -z "${WORK_W:-}" || "$WORK_W" == "null" ]]; then
    # Defensive fallback for unusual Sway tree versions.
    WORK_X=0
    WORK_Y=0
    WORK_W=100
    WORK_H=100
    SIZE_UNIT=ppt
else
    SIZE_UNIT=px
fi

swaymsg 'mark --add _maximized'
swaymsg "floating enable; resize set width ${WORK_W}${SIZE_UNIT} height ${WORK_H}${SIZE_UNIT}"
if [[ "$SIZE_UNIT" == px ]]; then
    swaymsg "move absolute position ${WORK_X}px ${WORK_Y}px"
else
    swaymsg 'move position center'
fi
swaymsg "border pixel ${FLOAT_W:-3}"
