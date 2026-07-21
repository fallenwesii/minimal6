#!/usr/bin/env bash

state=$(hyprctl activewindow -j | jq -r '.floating')

hyprctl dispatch togglefloating

if [ "$state" = "false" ]; then
  sleep 0.02
  hyprctl dispatch resizeactive exact 950 600
  hyprctl dispatch centerwindow
fi
