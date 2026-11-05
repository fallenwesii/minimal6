#!/bin/bash
notify_id=9901
STATE_DIR="/tmp/minimal6-${UID}"
if [ ! -d "$STATE_DIR" ]; then
    (umask 077 && mkdir "$STATE_DIR") 2>/dev/null || exit 1
fi
if [ ! -O "$STATE_DIR" ] || [ "$(stat -c '%a' "$STATE_DIR" 2>/dev/null)" != 700 ]; then
    exit 1
fi
CAFFEINE_LOCK="$STATE_DIR/sway-caffeine"

# Migrate markers from the previous locations. Only regular files owned by
# this user are eligible; never move a symlink or another user's marker.
for old_lock in "/tmp/sway-caffeine" "${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/sway-caffeine}"; do
    if [ -n "$old_lock" ] && [ "$old_lock" != "$CAFFEINE_LOCK" ] &&
       [ -f "$old_lock" ] && [ ! -L "$old_lock" ] && [ -O "$old_lock" ] &&
       [ ! -e "$CAFFEINE_LOCK" ]; then
        mv -- "$old_lock" "$CAFFEINE_LOCK" 2>/dev/null
    fi
done

if [ -f "$CAFFEINE_LOCK" ]; then
    # Disable Caffeine (Turn on idle / sleep)
    rm -f "$CAFFEINE_LOCK"
    
    # Start swayidle using swaymsg exec so it correctly binds as a child of sway
    pgrep -x swayidle >/dev/null || {
        swaymsg exec 'swayidle -w timeout 300 "swaymsg exec hyprlock" timeout 600 "swaymsg \"output * power off\"" resume "swaymsg \"output * power on\"" before-sleep "swaymsg exec hyprlock"'
    }
    
    # Always launch it: the script's own pidfile guard makes a second copy
    # a no-op, so this cannot start duplicates (unlike a loose pgrep).
    swaymsg exec ~/.config/sway/scripts/media-idle.sh

    notify-send "Caffeine OFF" "Screen will sleep normally." -a "sway" -i "sleep" -r $notify_id -t 2000
else
    # Enable Caffeine (Prevent sleep)
    touch "$CAFFEINE_LOCK"
    
    # Kill only the worker; its supervisor stays and stops respawning it
    # while the caffeine marker exists.
    # [.] so the pattern never matches the caller's own command line
    pkill -9 -f "media-idle[.]sh --worker" 2>/dev/null
    killall -9 swayidle 2>/dev/null

    notify-send "Caffeine ON" "Screen sleep prevented." -a "sway" -i "coffee" -r $notify_id -t 2000
fi
