#!/bin/bash

# Toggle kitty scratchpad - matches Hyprland togglespecialworkspace behavior
# First press: launch → park in scratchpad → show
# Subsequent presses: scratchpad show toggles (show if hidden, hide if focused)

APP_ID="kitty-scratchpad"

# Check if window already exists anywhere (scratchpad or workspace)
WIN_ID=$(swaymsg -t get_tree | jq -r '.. | select(.app_id? == "'"$APP_ID"'") | .id' | head -1)

if [ -z "$WIN_ID" ]; then
    # Not running — launch it, wait for it to appear, park in scratchpad, then show
    kitty --app-id="$APP_ID" --class="$APP_ID" &
    # Poll until the window appears (max ~3s)
    for i in $(seq 1 30); do
        sleep 0.1
        WIN_ID=$(swaymsg -t get_tree | jq -r '.. | select(.app_id? == "'"$APP_ID"'") | .id' | head -1)
        [ -n "$WIN_ID" ] && break
    done
    [ -z "$WIN_ID" ] && exit 1
    # Park it in scratchpad first, then bring it up
    swaymsg "[con_id=$WIN_ID] move scratchpad"
    swaymsg "[app_id=$APP_ID] scratchpad show"
else
    # Already running — scratchpad show toggles: shows if hidden, hides if focused
    swaymsg "[app_id=$APP_ID] scratchpad show"
fi
