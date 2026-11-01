#!/usr/bin/env bash
# toggle-corners.sh — toggle quickshell's rounded screen corners on/off.
#
# Writes ~/.cache/quickshell-corners ("0"=off, "1"=on). shell.qml watches
# this file via FileView and applies the change instantly — no quickshell
# restart needed. State persists across quickshell restarts (matugen
# relaunches qs on every wallpaper change).
#
# Keybind: Super + Ctrl + Q
set -u

STATE_FILE="$HOME/.cache/quickshell-corners"

# Default (no file yet) = corners on, matching shell.qml's initial value.
current="$(cat "$STATE_FILE" 2>/dev/null || echo 1)"

if [ "$current" = "1" ]; then
  echo 0 >"$STATE_FILE"
  notify-send -a 'Quickshell' -t 1500 'Rounded corners: off' '' 2>/dev/null
else
  echo 1 >"$STATE_FILE"
  notify-send -a 'Quickshell' -t 1500 'Rounded corners: on' '' 2>/dev/null
fi
