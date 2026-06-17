#!/usr/bin/env bash

# Directory containing wallpapers (as specified by user)
WALL_DIR="$HOME/Pictures/wallpaper"

# Check if directory exists, fallback to wallpapers if not
if [ ! -d "$WALL_DIR" ]; then
    WALL_DIR="$HOME/Pictures/wallpapers"
fi

# Exit if no directory found
if [ ! -d "$WALL_DIR" ]; then
    dunstify -u critical -a "Wallpaper" "Directory not found: $WALL_DIR"
    exit 1
fi

# Find a random wallpaper
RANDOM_WALL=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)

if [ -n "$RANDOM_WALL" ]; then
    # Apply wallpaper with animation
    # awww is used in this setup (likely a wrapper for swww)
    if command -v awww &> /dev/null; then
        awww img "$RANDOM_WALL" --transition-type wipe --transition-duration 2
        CMD="awww"
    else
        swww img "$RANDOM_WALL" --transition-type wipe --transition-duration 2
        CMD="swww"
    fi

    # Update startup.conf for persistence
    STARTUP_CONF="$HOME/.config/hypr/conf/startup.conf"
    if [ -f "$STARTUP_CONF" ]; then
        sed -i "s|exec-once = $CMD img .*|exec-once = $CMD img \"$RANDOM_WALL\" --transition-type none|" "$STARTUP_CONF"
    fi

    # Send notification
    dunstify -u low -a "Wallpaper" -i "$RANDOM_WALL" "Wallpaper Changed" "$(basename "$RANDOM_WALL")"
fi
