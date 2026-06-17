#!/bin/sh
##!/usr/bin/env bash

# Minimum brightness percentage allowed
MIN_BRIGHTNESS=5

case "$1" in
up)
  brightnessctl set +5%
  ;;
down)
  # Get current brightness percentage
  CURRENT=$(brightnessctl i | grep -oP '\(\d+%\)' | tr -d '()%')

  # Only decrease if it sits safely above the floor
  if [ "$CURRENT" -gt "$MIN_BRIGHTNESS" ]; then
    brightnessctl set 5%-
  fi
  ;;
esac
