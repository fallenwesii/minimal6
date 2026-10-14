#!/bin/bash
notify_id=9901
CAFFEINE_LOCK="/tmp/sway-caffeine"

if [ -f "$CAFFEINE_LOCK" ]; then
    # Disable Caffeine (Turn on idle / sleep)
    rm -f "$CAFFEINE_LOCK"
    
    # Start swayidle using swaymsg exec so it correctly binds as a child of sway
    pgrep -x swayidle >/dev/null || {
        swaymsg exec 'swayidle -w timeout 300 "swaymsg exec hyprlock" timeout 600 "swaymsg \"output * power off\"" resume "swaymsg \"output * power on\"" before-sleep "swaymsg exec hyprlock"'
    }
    
    pgrep -f "media-idle.sh" >/dev/null || {
        swaymsg exec ~/.config/sway/scripts/media-idle.sh
    }

    notify-send "Caffeine OFF" "Screen will sleep normally." -a "sway" -i "sleep" -r $notify_id -t 2000
else
    # Enable Caffeine (Prevent sleep)
    touch "$CAFFEINE_LOCK"
    
    # Kill media-idle first so it cannot respawn swayidle before we kill it
    pkill -9 -f "media-idle.sh" 2>/dev/null
    killall -9 swayidle 2>/dev/null

    notify-send "Caffeine ON" "Screen sleep prevented." -a "sway" -i "coffee" -r $notify_id -t 2000
fi
