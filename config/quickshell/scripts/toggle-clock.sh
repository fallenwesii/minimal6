#!/usr/bin/env bash
# toggle-clock.sh — toggle the quickshell analog clock widget on/off.
#
# Writes ~/.cache/quickshell-clock ("0"=off, "1"=on). shell.qml watches
# this file via FileView and applies the change instantly — no quickshell
# restart needed. State persists across quickshell restarts (matugen
# relaunches qs on every wallpaper change).
#
# Keybind: Super + Ctrl + D
set -u

STATE_FILE="$HOME/.cache/quickshell-clock"

# Default (no file yet) = clock on, matching shell.qml's initial value.
current="$(cat "$STATE_FILE" 2>/dev/null || echo 1)"

if [ "$current" = "1" ]; then
  echo 0 >"$STATE_FILE"
  notify-send -a 'Quickshell' -t 1500 'Clock widget: off' '' 2>/dev/null
else
  echo 1 >"$STATE_FILE"
  notify-send -a 'Quickshell' -t 1500 'Clock widget: on' '' 2>/dev/null
fi
