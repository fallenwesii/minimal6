#!/bin/bash
notify_id=9902
# State lives in a per-user, mode-700 directory under /tmp.
GAMEMODE_LOCK="/tmp/sway-gamemode"
GAMEMODE_PID_FILE="/tmp/sway-gamemode.pid"

if [ -f "$GAMEMODE_LOCK" ]; then
    # Disable gamemode
    rm -f "$GAMEMODE_LOCK"
    
    # Stop gamemoded daemon
    if [ -f "$GAMEMODE_PID_FILE" ]; then
        kill "$(cat "$GAMEMODE_PID_FILE")" 2>/dev/null
        rm -f "$GAMEMODE_PID_FILE"
    fi
    pkill -f "gamemoded -d" 2>/dev/null
    
    # Reload sway config to restore effects
    ~/.config/sway/scripts/reload-config.sh
    
    notify-send "Gamemode OFF" "Gamemode disabled, effects restored." -a "sway" -i "controller" -r $notify_id -t 2000
else
    # Enable gamemode
    touch "$GAMEMODE_LOCK"
    
    # Disable SwayFX effects
    swaymsg blur disable
    swaymsg shadows disable
    swaymsg corner_radius 0
    
    # Start gamemoded daemon in background
    gamemoded -d &
    GAMEMODE_DAEMON_PID=$!
    echo "$GAMEMODE_DAEMON_PID" > "$GAMEMODE_PID_FILE"
    
    notify-send "Gamemode ON" "Gamemode daemon active + effects disabled." -a "sway" -i "controller" -r $notify_id -t 2000
fi