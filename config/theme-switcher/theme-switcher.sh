#!/bin/bash

# Configuration
THEME_DIR="$HOME/.config/theme-switcher/themes"
CURRENT_THEME_FILE="$HOME/.config/theme-switcher/current_theme"
FALLBACK_THEME="fallback-theme"
HYPR_APPEARANCE="$HOME/.config/hypr/conf/appearance.conf"

# Get theme list (excluding fallback-theme and other files)
get_themes() {
  ls -d "$THEME_DIR"/*/ | xargs -n 1 basename | grep -v "$FALLBACK_THEME"
}

# Function to apply a theme
apply_theme() {
  local theme=$1
  local theme_path="$THEME_DIR/$theme"

  if [ ! -d "$theme_path" ]; then
    echo "Error: Theme $theme not found!"
    return 1
  fi

  echo "Applying theme: $theme"

  # 1. Waybar
  if [ -f "$theme_path/waybar/style.css" ]; then
    ln -sf "$theme_path/waybar/style.css" "$HOME/.config/waybar/theme.css"
    pkill -USR2 waybar 2>/dev/null
  fi

  # 2. Wofi
  if [ -f "$theme_path/wofi/style.css" ]; then
    ln -sf "$theme_path/wofi/style.css" "$HOME/.config/wofi/theme.css"
  fi

  # 3. Dunst
  if [ -f "$theme_path/dunst/dunstrc" ]; then
    mkdir -p "$HOME/.config/dunst"
    ln -sf "$theme_path/dunst/dunstrc" "$HOME/.config/dunst/dunstrc"
    killall -q dunst
    sleep 0.2
    dunst -conf "$HOME/.config/dunst/dunstrc" >/dev/null 2>&1 &
  fi

  # 4. wlogout
  if [ -f "$theme_path/wlogout/style.css" ]; then
    ln -sf "$theme_path/wlogout/style.css" "$HOME/.config/wlogout/theme.css"
  fi

  # 5. Hyprland Border (In-place update)
  if [ -f "$theme_path/hyprland-colors.conf" ]; then
    local active_border=$(grep "col.active_border" "$theme_path/hyprland-colors.conf" | cut -d'=' -f2- | xargs)
    local inactive_border=$(grep "col.inactive_border" "$theme_path/hyprland-colors.conf" | cut -d'=' -f2- | xargs)

    sed -i "s|col.active_border = .*|col.active_border = $active_border|g" "$HYPR_APPEARANCE"
    sed -i "s|col.inactive_border = .*|col.inactive_border = $inactive_border|g" "$HYPR_APPEARANCE"
  fi

  # 6. GTK Theme
  local gtk_theme_name="$theme"
  gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme_name"
  flatpak override --user --env=GTK_THEME="$gtk_theme_name" 2>/dev/null

  # 7. Terminal Colors
  if [ -f "$theme_path/kitty.conf" ]; then
    cp "$theme_path/kitty.conf" "$HOME/.config/kitty/current-theme.conf"
    pkill -USR1 kitty 2>/dev/null
  fi
  if [ -f "$theme_path/ghostty" ]; then
    cp "$theme_path/ghostty" "$HOME/.config/ghostty/current-theme"
    pkill -SIGUSR2 ghostty 2>/dev/null
  fi

  # Save current theme
  echo "$theme" >"$CURRENT_THEME_FILE"

  echo "Successfully switched to $theme"
  if command -v dunstify >/dev/null 2>&1; then
    dunstify -u low -a "Theme Switcher" "Theme Applied" "Switched to $theme" >/dev/null 2>&1
  fi
}

# Main logic
if [ "$1" == "random" ] || [ -z "$1" ]; then
  current=$(cat "$CURRENT_THEME_FILE" 2>/dev/null)
  themes=($(get_themes))
  if [ ${#themes[@]} -gt 1 ]; then
    themes=($(printf "%s\n" "${themes[@]}" | grep -v "^$current$"))
  fi
  random_theme=${themes[$RANDOM % ${#themes[@]}]}
  apply_theme "$random_theme" || apply_theme "$FALLBACK_THEME"
else
  apply_theme "$1" || apply_theme "$FALLBACK_THEME"
fi
