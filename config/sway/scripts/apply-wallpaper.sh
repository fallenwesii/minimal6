#!/usr/bin/env bash
# apply-wallpaper.sh — show the wallpaper immediately, retheme behind it.
#
# Handed to sway via `swaymsg exec` by wallpaper-switcher.sh so it keeps
# running after the picker window dies. Order matters:
#   1. awww img — wallpaper visible in ~0.2s, 2s grow transition starts.
#   2. sleep    — wait the transition out; matugen's `swaymsg reload`
#      (1.3s of sway main-loop time) would otherwise hard-freeze the
#      animation for ~1s mid-flight.
#   3. matugen  — templates + hooks (~8s), wallpaper untouched
#      (config.toml has no [config.wallpaper] section anymore).
# A pidfile guard kills any previous run still in flight, so switching
# wallpapers rapidly can never pile up matugen/reload spikes. An flock on
# top of it closes the remaining hole: the pidfile check is read-then-act,
# so two applies starting in the same instant could both pass it and both
# run matugen. Only the lock holder applies.

set -u

PIDFILE="$HOME/.cache/wallpaper-apply.pid"
TRANSITION_DURATION=2

IMAGE="${1:-}"
if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
  exit 1
fi

# Cancel a previous still-running apply (guarded: pid recycling can't
# match unless the cmdline really is this script).
if [ -r "$PIDFILE" ]; then
  old="$(cat "$PIDFILE" 2>/dev/null)"
  if [ -n "$old" ] && [ "$old" != "$$" ] &&
    ps -p "$old" -o args= 2>/dev/null | grep -q "apply-wallpaper"; then
    pkill -P "$old" 2>/dev/null # its children (matugen/sleep/awww)
    kill "$old" 2>/dev/null
  fi
fi

# Exclusive lock for the rest of this pass. Held on fd 9 for the lifetime
# of the script, and dropped by the kernel if the pass is killed, so it
# cannot go stale the way a pid file can.
#
# Children MUST NOT inherit fd 9: matugen's post-hooks start long-lived
# daemons (quickshell via `qs -d`, which itself spawns `swaymsg --monitor`),
# and an inherited fd keeps the flock's open file description alive forever
# after this script exits. That leaked lock made every later apply time out
# at `flock -w 5` and silently do nothing. Every external command below is
# therefore run with fd 9 closed (`9>&-`); closing an unopened fd is a no-op,
# so this stays safe when flock is unavailable.
if command -v flock >/dev/null 2>&1; then
  exec 9>"$HOME/.cache/wallpaper-apply.lock"
  flock -w 5 9 || {
    notify-send -a 'Wallpaper Picker' 'Wallpaper apply busy' \
      'Another apply is stuck holding the lock' 2>/dev/null
    exit 1
  }
fi

echo $$ >"$PIDFILE"

awww img --transition-type grow --transition-duration "$TRANSITION_DURATION" "$IMAGE" >/dev/null 2>&1 9>&-
sleep "$TRANSITION_DURATION"

if command -v matugen >/dev/null 2>&1; then
  matugen image "$IMAGE" -m dark --source-color-index 0 --lightness-dark 0.14 --contrast 0 >/dev/null 2>&1 9>&-
fi

# Keep gsettings in sync (picker always applies a dark palette).
command -v gsettings >/dev/null 2>&1 &&
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

notify-send -a 'Wallpaper Picker' -i "$IMAGE" 'Theme Updated' "Applied wallpaper: ${IMAGE##*/}" 2>/dev/null
echo dark >"$HOME/.cache/matugen_mode"
