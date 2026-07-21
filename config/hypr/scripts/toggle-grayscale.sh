#!/usr/bin/env bash

THE_SHADER="$HOME/.config/hypr/shaders/warm_monochrome.frag"

# Query Hyprland to see if a screen shader is currently active
CURRENT_SHADER=$(hyprctl getoption decoration:screen_shader -j | jq -r '.str')

# Toggle the shader on or off
if [ "$CURRENT_SHADER" = "[[EMPTY]]" ] || [ "$CURRENT_SHADER" = "None" ] || [ -z "$CURRENT_SHADER" ]; then
  hyprctl keyword decoration:screen_shader "$THE_SHADER"
else
  hyprctl keyword decoration:screen_shader "[[EMPTY]]"
fi
