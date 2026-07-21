#!/usr/bin/env bash

# 1. Get the current user preference ('prefer-dark', 'prefer-light', or 'default')
CURRENT_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme)

# 2. Toggle the theme temporarily to force a redraw event
if [ "$CURRENT_SCHEME" = "'prefer-dark'" ]; then
    # Switch to light then back to dark immediately
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    sleep 0.1
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
else
    # Switch to dark then back to light immediately
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    sleep 0.1
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
fi

# 3. Optional: Send a notification to the XDG portal for flatpaks / newer GTK4 apps
# This ensures total system compatibility across native and sandboxed apps
if command -v dconf &> /dev/null; then
    if [ "$CURRENT_SCHEME" = "'prefer-dark'" ]; then
        dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
        dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    fi
fi