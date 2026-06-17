#!/usr/bin/env bash

# Project: Hyprland Quick Settings
# Description: Modular TUI for managing Hyprland settings using gum and hyprctl.
# Dependencies: gum, fzf, hyprctl, jq, dunstify, nmcli, bluetoothctl, awww/swww, sed.

# Paths
HYPR_DIR="$HOME/.config/hypr"
CONF_DIR="$HYPR_DIR/conf"
WALL_DIR="$HOME/Pictures/wallpaper"
[ ! -d "$WALL_DIR" ] && WALL_DIR="$HOME/Pictures/wallpapers"
THEME_DIR="$HOME/.config/theme-switcher"

# Theme colors for banner
CURRENT_THEME_FILE="$THEME_DIR/current_theme"
ACCENT="#83a598"
TEXT="#fbf1c7"
if [ -f "$CURRENT_THEME_FILE" ]; then
  current_theme=$(cat "$CURRENT_THEME_FILE")
  theme_colour_file="$THEME_DIR/themes/$current_theme/hyprland-colors.conf"
  theme_kitty_file="$THEME_DIR/themes/$current_theme/kitty.conf"
  if [ -f "$theme_colour_file" ]; then
    parsed=$(grep "col.active_border" "$theme_colour_file" | sed -E 's/.*rgba\(([0-9a-fA-F]{6}).*/\1/')
    [ -n "$parsed" ] && ACCENT="#$parsed"
  fi
  if [ -f "$theme_kitty_file" ]; then
    parsed=$(grep -i "^foreground" "$theme_kitty_file" | awk '{print $2}')
    [ -n "$parsed" ] && TEXT="$parsed"
  fi
fi

notify() {
  dunstify -u low -a "Quick Settings" "$1" "$2" >/dev/null 2>&1
}

# gchoose() {
#   gum choose -- "$@"
# }
#
# gfilter() {
#   gum filter "$@"
# }

gchoose() {
  # Enforce hardcoded colors: White unselected text, Blue selected text/cursor
  gum choose \
    --cursor.foreground="4" \
    --item.foreground="7" \
    --selected.foreground="4" \
    "$@"
}

gfilter() {
  # Enforce hardcoded colors for the fuzzy finder
  gum filter \
    --indicator.foreground="4" \
    --text.foreground="7" \
    --match.foreground="4" \
    --header.foreground="7" \
    "$@"
}

show_banner() {
  gum style \
    --border rounded \
    --border-foreground "$ACCENT" \
    --foreground "$TEXT" \
    --align center \
    --width 28 \
    --padding "1 2" \
    $'QUICK SETTINGS\nminimal6'
}

run_quiet() {
  "$@" >/dev/null 2>&1
}

# Persistent config update using sed
update_conf() {
  local file="$1"
  local key="$2"
  local value="$3"
  if [ -f "$file" ]; then
    # Matches key = value, ensuring it updates the existing entry
    if grep -q "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
      sed -i "s|^\([[:space:]]*${key}[[:space:]]*=[[:space:]]*\).*|\1$value|" "$file"
    else
      echo "    $key = $value" >>"$file"
    fi
  fi
}

update_appearance_conf() {
  case "$1" in
  "gaps_in" | "gaps_out")
    update_nested_conf "$CONF_DIR/appearance.conf" "general" "" "$1" "$2"
    ;;
  "rounding")
    update_nested_conf "$CONF_DIR/appearance.conf" "decoration" "" "$1" "$2"
    ;;
  "blur:enabled")
    update_nested_conf "$CONF_DIR/appearance.conf" "decoration" "blur" "enabled" "$2"
    ;;
  "animations:enabled")
    update_nested_conf "$CONF_DIR/appearance.conf" "animations" "" "enabled" "$2"
    ;;
  *)
    update_conf "$CONF_DIR/appearance.conf" "$1" "$2"
    ;;
  esac
}

update_programs_conf() {
  update_conf "$CONF_DIR/programs.conf" "$1" "$2"
}

update_monitor_conf() {
  local monitor="$1"
  local mode="$2"
  local file="$CONF_DIR/monitors.conf"
  [ -f "$file" ] || return

  if grep -q "^monitor[[:space:]]*=[[:space:]]*$monitor" "$file"; then
    sed -i "s|^monitor[[:space:]]*=[[:space:]]*$monitor,.*|monitor=$monitor,$mode,auto,1|" "$file"
  else
    echo "monitor=$monitor,$mode,auto,1" >>"$file"
  fi
}

update_nested_conf() {
  local file="$1"
  local block="$2"
  local subblock="$3"
  local key="$4"
  local value="$5"

  [ -f "$file" ] || return

  awk -v block="$block" -v subblock="$subblock" -v key="$key" -v value="$value" '
        function indent_for(line, fallback,    match_len) {
            match(line, /^[[:space:]]*/)
            match_len = RLENGTH
            return match_len > 0 ? substr(line, 1, match_len) : fallback
        }

        {
            if ($0 ~ "^[[:space:]]*" block "[[:space:]]*\\{[[:space:]]*$") {
                in_block = 1
                block_depth = 1
            } else if (in_block) {
                if ($0 ~ /\{/) {
                    block_depth++
                }
                if ($0 ~ /\}/) {
                    block_depth--
                }
            }

            if (in_block && subblock != "" && $0 ~ "^[[:space:]]*" subblock "[[:space:]]*\\{[[:space:]]*$") {
                in_subblock = 1
                subblock_depth = 1
            } else if (in_subblock) {
                if ($0 ~ /\{/) {
                    subblock_depth++
                }
                if ($0 ~ /\}/) {
                    subblock_depth--
                }
            }

            target = in_block && ((subblock == "" && block_depth == 1) || (subblock != "" && in_subblock && subblock_depth == 1))
            if (target && $0 ~ "^[[:space:]]*" key "[[:space:]]*=") {
                print indent_for($0, "  ") key " = " value
                updated = 1
                next
            }

            print

            if (in_subblock && subblock_depth == 0) {
                in_subblock = 0
            }
            if (in_block && block_depth == 0) {
                in_block = 0
            }
        }
    ' "$file" >"$file.tmp" && mv "$file.tmp" "$file"
}

get_dnd() {
  if command -v dunstctl >/dev/null 2>&1; then
    dunstctl is-paused 2>/dev/null && return
  fi

  if command -v makoctl >/dev/null 2>&1; then
    makoctl mode 2>/dev/null | grep -qx "do-not-disturb" && echo "true" || echo "false"
    return
  fi

  if command -v swaync-client >/dev/null 2>&1; then
    swaync-client -D 2>/dev/null | grep -qi "true" && echo "true" || echo "false"
    return
  fi

  echo "false"
}

set_dnd() {
  local state="$1"

  if command -v dunstctl >/dev/null 2>&1; then
    if ! pgrep -x dunst >/dev/null 2>&1 && command -v dunst >/dev/null 2>&1; then
      dunst >/dev/null 2>&1 &
      sleep 0.2
    fi
    run_quiet dunstctl set-paused "$state"
    return
  fi

  if command -v makoctl >/dev/null 2>&1; then
    if [ "$state" = "true" ]; then
      run_quiet makoctl mode -a do-not-disturb
    else
      run_quiet makoctl mode -r do-not-disturb
    fi
    return
  fi

  if command -v swaync-client >/dev/null 2>&1; then
    run_quiet swaync-client -dn "$state"
  fi
}

# --- Sub-menus ---

theme_preview() {
  local theme="$1"
  local themes_dir="$2"

  if [ "$theme" = "random" ]; then
    printf "\n\n   \033[1mRandomize Theme\033[0m\n"
    printf "   Picks a random theme on each switch\n"
    return
  fi

  local theme_path="$themes_dir/$theme"
  local config=""

  for f in kitty.conf ghostty; do
    [ -f "$theme_path/$f" ] && config="$theme_path/$f" && break
  done

  if [ -z "$config" ]; then
    printf "   Theme: \033[1m%s\033[0m\n\n" "$theme"
    printf "   No kitty.conf or ghostty found\n"
    return
  fi

  printf "   Theme: \033[1m%s\033[0m  (\033[90m%s\033[0m)\n\n" "$theme" "$(basename "$config")"

  print_color() {
    local label="$1"
    local hex="$2"
    if [[ $hex =~ ^#[0-9a-fA-F]{6}$ ]]; then
      local r=$((16#${hex:1:2}))
      local g=$((16#${hex:3:2}))
      local b=$((16#${hex:5:2}))
      printf "   \033[48;2;%d;%d;%dm      \033[0m  \033[90m%-12s\033[0m %s\n" "$r" "$g" "$b" "$label" "$hex"
    fi
  }

  if [[ "$config" == *.toml ]]; then
    bg=$(grep -iE '^\s*background\s*=' "$config" | head -1 | sed -E 's/.*=\s*["#]?([0-9a-fA-F]{6}).*/#\1/')
    fg=$(grep -iE '^\s*foreground\s*=' "$config" | head -1 | sed -E 's/.*=\s*["#]?([0-9a-fA-F]{6}).*/#\1/')
    cur=$(grep -iE '^\s*cursor\s*=' "$config" | head -1 | sed -E 's/.*=\s*["#]?([0-9a-fA-F]{6}).*/#\1/')
  else
    bg=$(grep -iE '^(background|background_color)\s' "$config" | awk '{print $NF}' | tr -d '=' | head -1)
    fg=$(grep -iE '^(foreground|foreground_color)\s' "$config" | awk '{print $NF}' | tr -d '=' | head -1)
    cur=$(grep -iE '^cursor\s' "$config" | awk '{print $NF}' | tr -d '=' | head -1)
  fi

  [ -n "$bg" ] && print_color "Background" "$bg"
  [ -n "$fg" ] && print_color "Foreground" "$fg"
  [ -n "$cur" ] && print_color "Cursor" "$cur"

  printf "\n   \033[1mPalette:\033[0m\n   "
  grep -oE '#[0-9a-fA-F]{6}' "$config" | sort -u | while read -r hex; do
    local r=$((16#${hex:1:2}))
    local g=$((16#${hex:3:2}))
    local b=$((16#${hex:5:2}))
    printf "\033[48;2;%d;%d;%dm  \033[0m " "$r" "$g" "$b"
  done
  printf "\n\n"
}

menu_themes() {
  local themes_dir="$THEME_DIR/themes"
  [ -d "$themes_dir" ] || return

  local preview_script=$(mktemp)
  cat >"$preview_script" <<'EOF'
theme_preview() {
  local theme="$1"
  local themes_dir="$2"

  if [ "$theme" = "random" ]; then
    printf "\n\n   \033[1mRandomize Theme\033[0m\n"
    printf "   Picks a random theme on each switch\n"
    return
  fi

  local theme_path="$themes_dir/$theme"
  local config=""

  for f in kitty.conf ghostty; do
    [ -f "$theme_path/$f" ] && config="$theme_path/$f" && break
  done

  if [ -z "$config" ]; then
    printf "   Theme: \033[1m%s\033[0m\n\n" "$theme"
    printf "   No kitty.conf or ghostty found\n"
    return
  fi

  printf "   Theme: \033[1m%s\033[0m  (\033[90m%s\033[0m)\n\n" "$theme" "$(basename "$config")"

  print_color() {
    local label="$1"
    local hex="$2"
    if [[ $hex =~ ^#[0-9a-fA-F]{6}$ ]]; then
      local r=$((16#${hex:1:2}))
      local g=$((16#${hex:3:2}))
      local b=$((16#${hex:5:2}))
      printf "   \033[48;2;%d;%d;%dm      \033[0m  \033[90m%-12s\033[0m %s\n" "$r" "$g" "$b" "$label" "$hex"
    fi
  }

  if [[ "$config" == *.toml ]]; then
    bg=$(grep -iE '^\s*background\s*=' "$config" | head -1 | sed -E 's/.*=\s*["#]?([0-9a-fA-F]{6}).*/#\1/')
    fg=$(grep -iE '^\s*foreground\s*=' "$config" | head -1 | sed -E 's/.*=\s*["#]?([0-9a-fA-F]{6}).*/#\1/')
    cur=$(grep -iE '^\s*cursor\s*=' "$config" | head -1 | sed -E 's/.*=\s*["#]?([0-9a-fA-F]{6}).*/#\1/')
  else
    bg=$(grep -iE '^(background|background_color)\s' "$config" | awk '{print $NF}' | tr -d '=' | head -1)
    fg=$(grep -iE '^(foreground|foreground_color)\s' "$config" | awk '{print $NF}' | tr -d '=' | head -1)
    cur=$(grep -iE '^cursor\s' "$config" | awk '{print $NF}' | tr -d '=' | head -1)
  fi

  [ -n "$bg" ] && print_color "Background" "$bg"
  [ -n "$fg" ] && print_color "Foreground" "$fg"
  [ -n "$cur" ] && print_color "Cursor" "$cur"

  printf "\n   \033[1mPalette:\033[0m\n   "
  grep -oE '#[0-9a-fA-F]{6}' "$config" | sort -u | while read -r hex; do
    local r=$((16#${hex:1:2}))
    local g=$((16#${hex:3:2}))
    local b=$((16#${hex:5:2}))
    printf "\033[48;2;%d;%d;%dm  \033[0m " "$r" "$g" "$b"
  done
  printf "\n\n"
}
theme_preview "$1" "$2"
EOF
  chmod +x "$preview_script"

  local selected=$( (
    echo "random"
    ls -1 "$themes_dir" | grep -v "fallback-theme"
  ) | fzf \
    --header "Select Theme" \
    --ansi \
    --preview "$preview_script {} '$themes_dir'" \
    --preview-window=right:50%:wrap)

  rm -f "$preview_script"

  if [ -n "$selected" ]; then
    "$THEME_DIR/theme-switcher.sh" "$selected"
  fi
}

# A. Appearance Menu
menu_appearance() {
  while true; do
    local choice=$(gchoose "Themes" "Wallpapers" "Blur & Rounding" "Gaps" "<-- Back")
    [[ -z "$choice" || "$choice" == "<-- Back" ]] && return

    case "$choice" in
    "Themes")
      menu_themes
      ;;
    "Wallpapers")

      # Wallpaper selection with fzf, displaying relative paths while keeping absolute previews
      local wall=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null |
        sed "s|$HOME|~|" |
        fzf --preview '
          # Convert the tilde back to $HOME for kitten icat to read it properly
          real_path=$(echo {} | sed "s|^~|$HOME|")
          kitten icat --clear --transfer-mode file --stdin no --place 30x30@50x10 "$real_path"
          kitten icat --transfer-mode file --stdin no --place 30x30@50x10 "$real_path"
        ' --preview-window=right:50%:wrap)

      # Convert tilde back to absolute path for awww/swww execution
      wall=$(echo "$wall" | sed "s|^~|$HOME|")

      if [ -n "$wall" ]; then
        if command -v awww &>/dev/null; then
          run_quiet awww img "$wall" --transition-type wipe --transition-duration 2
          sed -i "s|exec-once = awww img .*|exec-once = awww img \"$wall\" --transition-type none|" "$CONF_DIR/startup.conf"
        elif command -v swww &>/dev/null; then
          run_quiet swww img "$wall" --transition-type wipe --transition-duration 2
          sed -i "s|exec-once = swww img .*|exec-once = swww img \"$wall\" --transition-type none|" "$CONF_DIR/startup.conf"
        fi
        notify "Wallpaper Changed" "$(basename "$wall")"
      fi
      ;;
    "Blur & Rounding")
      menu_blur_rounding
      ;;
    "Gaps")
      adjust_gaps
      ;;
    esac
  done
}

menu_blur_rounding() {
  while true; do
    local blur=$(hyprctl getoption decoration:blur:enabled -j | jq -r '.int')
    local rounding=$(hyprctl getoption decoration:rounding -j | jq -r '.int')

    local choice=$(gchoose "Toggle Blur (Current: $([ "$blur" -eq 1 ] && echo "ON" || echo "OFF"))" "Rounding: $rounding" "Increase Rounding" "Decrease Rounding" "Reset Default" "<-- Back")
    [[ -z "$choice" || "$choice" == "<-- Back" ]] && return

    case "$choice" in
    "Toggle Blur"*)
      local new_val=$((1 - blur))
      run_quiet hyprctl keyword decoration:blur:enabled "$new_val"
      update_appearance_conf "blur:enabled" "$([ "$new_val" -eq 1 ] && echo "true" || echo "false")"
      notify "Blur" "$([ "$new_val" -eq 1 ] && echo "Enabled" || echo "Disabled")"
      ;;
    "Increase Rounding")
      local new_val=$((rounding + 2))
      run_quiet hyprctl keyword decoration:rounding "$new_val"
      update_appearance_conf "rounding" "$new_val"
      notify "Rounding" "Set to $new_val"
      ;;
    "Decrease Rounding")
      local new_val=$((rounding - 2))
      [ $new_val -lt 0 ] && new_val=0
      run_quiet hyprctl keyword decoration:rounding "$new_val"
      update_appearance_conf "rounding" "$new_val"
      notify "Rounding" "Set to $new_val"
      ;;
    "Reset Default")
      run_quiet hyprctl keyword decoration:rounding 8
      update_appearance_conf "rounding" 8
      notify "Rounding" "Reset to 8"
      ;;
    esac
  done
}

# Gaps Logic
adjust_gaps() {
  while true; do
    # Extract current gaps values safely
    local gin=$(hyprctl getoption general:gaps_in -j | jq -r '.custom' | cut -d' ' -f1)
    [ "$gin" == "null" ] && gin=$(hyprctl getoption general:gaps_in -j | jq -r '.int')

    local gout=$(hyprctl getoption general:gaps_out -j | jq -r '.custom' | cut -d' ' -f1)
    [ "$gout" == "null" ] && gout=$(hyprctl getoption general:gaps_out -j | jq -r '.int')

    local choice=$(gchoose "Inner: $gin (+/-)" "Outer: $gout (+/-)" "Reset Gaps" "No Gaps Mode" "<-- Back")
    [[ -z "$choice" || "$choice" == "<-- Back" ]] && return

    case "$choice" in
    "Inner"*)
      local sub=$(gchoose "+2" "-2")
      if [ "$sub" == "+2" ]; then
        run_quiet hyprctl keyword general:gaps_in "$((gin + 2))"
        update_appearance_conf "gaps_in" $((gin + 2))
        notify "Inner Gaps" "Set to $((gin + 2))"
      elif [ "$sub" == "-2" ]; then
        local nv=$((gin - 2))
        [ $nv -lt 0 ] && nv=0
        run_quiet hyprctl keyword general:gaps_in "$nv"
        update_appearance_conf "gaps_in" "$nv"
        notify "Inner Gaps" "Set to $nv"
      fi
      ;;
    "Outer"*)
      local sub=$(gchoose "+2" "-2")
      if [ "$sub" == "+2" ]; then
        run_quiet hyprctl keyword general:gaps_out "$((gout + 2))"
        update_appearance_conf "gaps_out" $((gout + 2))
        notify "Outer Gaps" "Set to $((gout + 5))"
      elif [ "$sub" == "-2" ]; then
        local nv=$((gout - 2))
        [ $nv -lt 0 ] && nv=0
        run_quiet hyprctl keyword general:gaps_out "$nv"
        update_appearance_conf "gaps_out" "$nv"
        notify "Outer Gaps" "Set to $nv"
      fi
      ;;
    "Reset Gaps")
      run_quiet hyprctl keyword general:gaps_in 3
      run_quiet hyprctl keyword general:gaps_out 5
      update_appearance_conf "gaps_in" 3
      update_appearance_conf "gaps_out" 5
      notify "Gaps" "Reset to inner 3, outer 5"
      ;;
    "No Gaps Mode")
      run_quiet hyprctl keyword general:gaps_in 0
      run_quiet hyprctl keyword general:gaps_out 0
      update_appearance_conf "gaps_in" 0
      update_appearance_conf "gaps_out" 0
      notify "Gaps" "No gaps mode enabled"
      ;;
    esac
  done
}

# B. Toggles Menu
menu_toggles() {
  while true; do
    local blur=$(hyprctl getoption decoration:blur:enabled -j | jq -r '.int')
    local anim=$(hyprctl getoption animations:enabled -j | jq -r '.int')
    local dnd=$(get_dnd)
    local caffeine=$(pgrep -x hypridle >/dev/null && echo "OFF" || echo "ON")

    local game_mode="OFF"
    [ -f /tmp/hypr_gamemode.lock ] && game_mode="ON"

    local choice=$(gchoose \
      "Blur: $([ "$blur" -eq 1 ] && echo "●" || echo "○")" \
      "Animations: $([ "$anim" -eq 1 ] && echo "●" || echo "○")" \
      "DND: $([ "$dnd" == "true" ] && echo "●" || echo "○")" \
      "Caffeine: $([ "$caffeine" == "ON" ] && echo "●" || echo "○")" \
      "Game Mode: $game_mode" \
      "<-- Back")
    [[ -z "$choice" || "$choice" == "<-- Back" ]] && return

    case "$choice" in
    "Blur"*)
      local nv=$((1 - blur))
      run_quiet hyprctl keyword decoration:blur:enabled "$nv"
      update_appearance_conf "blur:enabled" "$([ "$nv" -eq 1 ] && echo "true" || echo "false")"
      notify "Blur" "$([ "$nv" -eq 1 ] && echo "Enabled" || echo "Disabled")"
      ;;
    "Animations"*)
      local nv=$((1 - anim))
      run_quiet hyprctl keyword animations:enabled "$nv"
      update_appearance_conf "animations:enabled" "$([ "$nv" -eq 1 ] && echo "true" || echo "false")"
      notify "Animations" "$([ "$nv" -eq 1 ] && echo "Enabled" || echo "Disabled")"
      ;;
    "DND"*)
      if [ "$dnd" = "true" ]; then
        set_dnd false
        notify "DND" "Disabled"
      else
        notify "DND" "Enabled"
        set_dnd true
      fi
      ;;
    "Caffeine"*)
      if pgrep -x hypridle >/dev/null; then
        pkill hypridle
        notify "Caffeine" "Enabled (Hypridle stopped)"
      else
        hyprctl dispatch exec hypridle &
        notify "Caffeine" "Disabled (Hypridle started)"
      fi
      ;;
    "Game Mode"*)
      if [ -f /tmp/hypr_gamemode.lock ]; then
        rm /tmp/hypr_gamemode.lock
        run_quiet hyprctl reload
        notify "Game Mode" "Disabled. Restoring settings."
      else
        touch /tmp/hypr_gamemode.lock
        run_quiet hyprctl --batch "\
                        keyword animations:enabled 0;\
                        keyword decoration:drop_shadow 0;\
                        keyword decoration:blur:enabled 0;\
                        keyword general:gaps_in 0;\
                        keyword general:gaps_out 0;\
                        keyword general:border_size 1;\
                        keyword decoration:rounding 0"
        notify "Game Mode" "Enabled. Performance optimized."
      fi
      ;;
    esac
  done
}

# C. Display/Monitor Menu
menu_display() {
  while true; do
    local choice=$(gchoose "Resolution" "Profiles" "<-- Back")
    [[ -z "$choice" || "$choice" == "<-- Back" ]] && return

    case "$choice" in
    "Resolution")
      local monitor=$(hyprctl monitors -j | jq -r '.[0].name')
      local modes=$(printf "%s\n%s\n" \
        "$(hyprctl monitors -j | jq -r '.[0].availableModes | .[]')" \
        "3840x2160@60 2560x1440@60 1920x1080@60 1600x900@60 1366x768@60 1280x720@60" |
        tr ' ' '\n' | awk 'NF && !seen[$0]++')
      local selected_mode=$(echo "$modes" | gfilter --placeholder "Select Resolution...")
      if [ -n "$selected_mode" ]; then
        if run_quiet hyprctl keyword monitor "$monitor,$selected_mode,auto,1"; then
          update_monitor_conf "$monitor" "$selected_mode"
          notify "Display" "Resolution set to $selected_mode"
        else
          notify "Display" "Failed to set $selected_mode"
        fi
      fi
      ;;
    "Profiles")
      local profile=$(gchoose "Laptop Only" "External Only" "Dual Monitor" "Mirror" "<-- Back")
      case "$profile" in
      "Laptop Only")
        run_quiet hyprctl keyword monitor "eDP-1,preferred,auto,1"
        run_quiet hyprctl keyword monitor "HDMI-A-1,disable"
        notify "Display" "Laptop only profile applied"
        ;;
      "External Only")
        run_quiet hyprctl keyword monitor "eDP-1,disable"
        run_quiet hyprctl keyword monitor "HDMI-A-1,preferred,auto,1"
        notify "Display" "External only profile applied"
        ;;
      "Dual Monitor")
        run_quiet hyprctl keyword monitor "eDP-1,preferred,auto,1"
        run_quiet hyprctl keyword monitor "HDMI-A-1,preferred,auto,1,left"
        notify "Display" "Dual monitor profile applied"
        ;;
      "Mirror")
        run_quiet hyprctl keyword monitor "eDP-1,preferred,auto,1"
        run_quiet hyprctl keyword monitor "HDMI-A-1,preferred,auto,1,mirror,eDP-1"
        notify "Display" "Mirror profile applied"
        ;;
      esac
      ;;
    esac
  done
}

# D. System & Defaults
menu_system() {
  while true; do
    local choice=$(gchoose "Default Apps" "Network" "Bluetooth" "Power" "<-- Back")
    [[ -z "$choice" || "$choice" == "<-- Back" ]] && return

    case "$choice" in
    "Default Apps")
      local app_type=$(gchoose "Terminal" "File Manager" "Browser" "Editor" "<-- Back")
      [ "$app_type" == "<-- Back" ] && continue
      local app_cmd=$(gum input --placeholder "Enter command for $app_type...")
      if [ -n "$app_cmd" ]; then
        case "$app_type" in
        "Terminal") update_programs_conf "terminal" "$app_cmd" ;;
        "File Manager") update_programs_conf "file_manager" "$app_cmd" ;;
        "Browser") update_programs_conf "browser" "$app_cmd" ;;
        "Editor") update_programs_conf "editor" "$app_cmd" ;;
        esac
        notify "System" "Default $app_type updated to $app_cmd"
      fi
      ;;
    "Network")
      local ssid=$(nmcli -t -f SSID device wifi list 2>/dev/null | awk 'NF && !seen[$0]++' | gfilter --placeholder "Select WiFi...")
      if [ -n "$ssid" ]; then
        if run_quiet nmcli device wifi connect "$ssid"; then
          notify "Network" "Connected to $ssid"
        else
          local password=$(gum input --password --placeholder "Password for $ssid...")
          if [ -n "$password" ] && run_quiet nmcli device wifi connect "$ssid" password "$password"; then
            notify "Network" "Connected to $ssid"
          else
            notify "Network" "Failed to connect to $ssid"
          fi
        fi
      fi
      ;;
    "Bluetooth")
      local device=$(bluetoothctl devices 2>/dev/null | gfilter --placeholder "Select Device...")
      local mac=$(awk '{print $2}' <<<"$device")
      local name=$(cut -d' ' -f3- <<<"$device")
      if [ -n "$mac" ]; then
        if run_quiet bluetoothctl connect "$mac"; then
          notify "Bluetooth" "Connected to $name"
        else
          notify "Bluetooth" "Failed to connect to $name"
        fi
      fi
      ;;
    "Power")
      local op=$(gchoose "Lock" "Logout" "Suspend" "Reboot" "Shutdown" "<-- Back")
      case "$op" in
      "Lock") hyprlock || swaylock ;;
      "Logout") run_quiet hyprctl dispatch exit ;;
      "Suspend") systemctl suspend ;;
      "Reboot") systemctl reboot ;;
      "Shutdown") systemctl poweroff ;;
      esac
      ;;
    esac
  done
}

# --- Main Logic ---

main_menu() {
  while true; do
    local choice=$(gchoose "Appearance" "Toggles" "Display" "System" "Exit")

    # Bug Fix: Handle ESC or empty choice or "Exit"
    if [[ -z "$choice" || "$choice" == "Exit" ]]; then
      break
    fi

    case "$choice" in
    "Appearance") menu_appearance ;;
    "Toggles") menu_toggles ;;
    "Display") menu_display ;;
    "System") menu_system ;;
    esac
  done
}

cleanup() {
  rm -f /tmp/quick-settings-preview-*.sh 2>/dev/null
}

trap cleanup EXIT INT TERM

# Ensure script only exits when the main loop naturally ends
show_banner
main_menu
exit 0
