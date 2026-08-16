#!/bin/bash

# Configuration Paths
WALL_DIR="$HOME/Pictures/wallpapers"
CACHE_DIR="$HOME/.cache/wallpaper-picker"
TMP_DIR=""

# Ensure directories exist
mkdir -p "$WALL_DIR"
mkdir -p "$CACHE_DIR"

# Fallback to wallpaper (singular) if wallpapers is empty/does not exist
if [ ! -d "$WALL_DIR" ] || [ -z "$(ls -A "$WALL_DIR" 2>/dev/null)" ]; then
  WALL_DIR="$HOME/Pictures/wallpaper"
fi

# Check if the wallpapers directory is empty
if [ ! -d "$WALL_DIR" ] || [ -z "$(ls -A "$WALL_DIR" 2>/dev/null)" ]; then
  if command -v dunstify &>/dev/null; then
    dunstify -u critical -a "Wallpaper Picker" "No wallpapers found in $WALL_DIR"
  else
    notify-send "Wallpaper Picker" "No wallpapers found in $WALL_DIR"
  fi
  exit 1
fi

# Must run exclusively in Kitty (check $KITTY_PID)
if [ -z "$KITTY_PID" ]; then
  echo "Error: This script must be run inside Kitty terminal." >&2
  exit 1
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/wallpaper-picker.XXXXXX")

# Asynchronously generate thumbnails for any new or modified wallpapers
generate_thumbnails() {
  find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) | while read -r file; do
    filename=$(basename "$file")
    thumb_path="$CACHE_DIR/${filename}.png"
    border_thumb_path="$CACHE_DIR/${filename}.border.png"
    color_path="$CACHE_DIR/${filename}.colors"

    # Run thumbnail generation and color extraction sequentially in background
    (
      local generated=false
      if [ ! -f "$thumb_path" ] || [ "$file" -nt "$thumb_path" ]; then
        if [[ "$file" =~ \.[gG][iI][fF]$ ]]; then
          magick "${file}[0]" -resize 200x200^ -gravity center -extent 200x200 \
            \( +clone -alpha transparent -fill white -draw "roundrectangle 0,0 199,199 15,15" -alpha extract \) \
            -compose CopyOpacity -composite "$thumb_path" &>/dev/null
        else
          magick "$file" -resize 200x200^ -gravity center -extent 200x200 \
            \( +clone -alpha transparent -fill white -draw "roundrectangle 0,0 199,199 15,15" -alpha extract \) \
            -compose CopyOpacity -composite "$thumb_path" &>/dev/null
        fi
        generated=true
      fi

      local colors_generated=false
      if [ ! -f "$color_path" ] || [ "$file" -nt "$color_path" ]; then
        if command -v matugen &>/dev/null && command -v jq &>/dev/null; then
          # Extract colors from the original wallpaper file in Pictures/wallpapers
          matugen image "$file" -j hex --dry-run 2>/dev/null | jq -r '.colors.primary.default.color, .colors.on_primary.default.color, .colors.primary_container.default.color, .colors.on_primary_container.default.color' >"$color_path"
          colors_generated=true
        else
          echo -e "#ffffff\n#000000\n#333333\n#ffffff" >"$color_path"
        fi
      fi

      # Generate a 3px border-stroked thumbnail using the wallpaper's primary color
      if [ ! -f "$border_thumb_path" ] || [ "$file" -nt "$border_thumb_path" ] || [ "$generated" = true ] || [ "$colors_generated" = true ]; then
        local primary_color="#ffffff"
        if [ -f "$color_path" ]; then
          primary_color=$(head -n 1 "$color_path")
        fi
        magick "$thumb_path" \( +clone -fill none -stroke "$primary_color" -strokewidth 3 -draw "roundrectangle 1.5,1.5 198.5,198.5 15,15" \) -composite "$border_thumb_path" &>/dev/null
      fi
    ) &

    # Limit parallel jobs to 4 to avoid lagging the CPU
    while [ "$(jobs -rp | wc -l)" -ge 4 ]; do
      sleep 0.1
    done
  done
}
# Start thumbnail generation in background (double-forked so it persists after script exits)
(generate_thumbnails &) &>/dev/null

# Find all wallpapers in WALL_DIR, and shuffle them on launch using shuf
mapfile -t ALL_WALLPAPERS < <(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) | shuf)

# State variables
QUERY=""
FILTERED_WALLPAPERS=("${ALL_WALLPAPERS[@]}")
FILTERED_COUNT=${#FILTERED_WALLPAPERS[@]}
current_idx=0
SEARCH_FOCUSED=false
KEY=""
LAST_RENDER_SIGNATURE=""

# Helper: Convert hex to RGB (R;G;B)
hex_to_rgb() {
  local hex="${1#\#}"
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  echo "${r};${g};${b}"
}

# Helper: Retrieve colors for a wallpaper (cached or defaults)
get_wallpaper_colors() {
  local filename="${1##*/}"
  local color_path="$CACHE_DIR/${filename}.colors"

  if [ -f "$color_path" ]; then
    mapfile -t colors <"$color_path"
    if [ ${#colors[@]} -eq 4 ]; then
      primary_color="${colors[0]}"
      return
    fi
  fi

  primary_color="#ffffff"
}

# Layout settings
N=5
T_WIDTH=20
T_HEIGHT=10
SPACING=4
START_COL=0
START_ROW=0

calculate_layout() {
  COLS=$(tput cols)
  LINES=$(tput lines)

  if ! [[ "$COLS" =~ ^[0-9]+$ ]]; then COLS=80; fi
  if ! [[ "$LINES" =~ ^[0-9]+$ ]]; then LINES=24; fi

  # Choose 5 or 7 thumbnails based on screen width
  if ((COLS >= 160)); then
    N=7
  else
    N=5
  fi

  # Reset defaults
  T_WIDTH=20
  T_HEIGHT=10
  SPACING=4

  # Scale layout if it doesn't fit the screen width
  while ((N * T_WIDTH + (N - 1) * SPACING > COLS - 4)) && ((T_WIDTH > 10)); do
    T_WIDTH=$((T_WIDTH - 2))
    T_HEIGHT=$((T_WIDTH / 2))
    if ((SPACING > 2)); then
      SPACING=$((SPACING - 1))
    fi
  done

  local total_w=$((N * T_WIDTH + (N - 1) * SPACING))
  START_COL=$(((COLS - total_w) / 2))
  if ((START_COL < 1)); then START_COL=1; fi

  # Center the combined block of height T_HEIGHT + 3
  START_ROW=$(((LINES - T_HEIGHT - 3) / 2))
  if ((START_ROW < 1)); then START_ROW=1; fi
}

draw_search_bar() {
  local primary_rgb
  if ((FILTERED_COUNT > 0)); then
    primary_rgb=$(hex_to_rgb "$primary_color")
  else
    primary_rgb="255;255;255"
  fi

  local search_text=""
  if [ -z "$QUERY" ]; then
    if [ "$SEARCH_FOCUSED" = true ]; then
      search_text="  \e[38;2;${primary_rgb}m|\e[38;5;244mSearch\e[0m"
    else
      search_text="  \e[38;5;244mSearch\e[0m"
    fi
  else
    if [ "$SEARCH_FOCUSED" = true ]; then
      search_text="  ${QUERY}\e[38;2;${primary_rgb}m|\e[0m"
    else
      search_text="  ${QUERY}"
    fi
  fi

  local s_row=$((START_ROW + T_HEIGHT + 2))
  echo -ne "\e[${s_row};1H\e[K"

  local display_len=$((3 + ${#QUERY}))
  if [ -z "$QUERY" ]; then
    display_len=9
  fi

  local search_col=$(((COLS - display_len) / 2))
  if ((search_col < 1)); then search_col=1; fi

  echo -ne "\e[${s_row};${search_col}H${search_text}"
}

update_filter() {
  if [ -z "$QUERY" ]; then
    FILTERED_WALLPAPERS=("${ALL_WALLPAPERS[@]}")
  else
    FILTERED_WALLPAPERS=()
    local query_lc="${QUERY,,}"
    local file basename_lc path_lc

    for file in "${ALL_WALLPAPERS[@]}"; do
      basename_lc="${file##*/}"
      basename_lc="${basename_lc,,}"
      path_lc="${file,,}"

      if [[ "$basename_lc" == *"$query_lc"* || "$path_lc" == *"$query_lc"* ]]; then
        FILTERED_WALLPAPERS+=("$file")
      fi
    done
  fi
  FILTERED_COUNT=${#FILTERED_WALLPAPERS[@]}

  if ((FILTERED_COUNT == 0)); then
    current_idx=0
  elif ((current_idx >= FILTERED_COUNT)); then
    current_idx=$((FILTERED_COUNT - 1))
  elif ((current_idx < 0)); then
    current_idx=0
  fi
}

visible_signature() {
  if ((FILTERED_COUNT == 0)); then
    printf 'empty:%s' "$QUERY"
    return
  fi

  local display_n=$((N < FILTERED_COUNT ? N : FILTERED_COUNT))
  local half_n=$((display_n / 2))
  local signature="count:${FILTERED_COUNT}:idx:${current_idx}:"
  local i offset w_idx

  for ((i = 0; i < display_n; i++)); do
    offset=$((i - half_n))
    w_idx=$(((current_idx + offset + FILTERED_COUNT) % FILTERED_COUNT))
    signature+="${FILTERED_WALLPAPERS[w_idx]}|"
  done

  printf '%s' "$signature"
}

redraw_screen() {
  COLS=$(tput cols)
  LINES=$(tput lines)

  if ! [[ "$COLS" =~ ^[0-9]+$ ]]; then COLS=80; fi
  if ! [[ "$LINES" =~ ^[0-9]+$ ]]; then LINES=24; fi

  if ((FILTERED_COUNT == 0)); then
    # Clear screen to show "No matching wallpapers"
    kitty +kitten icat --clear 2>/dev/null
    echo -ne "\e[H\e[2J"
    local msg="No matching wallpapers found"
    local msg_col=$(((COLS - ${#msg}) / 2))
    echo -ne "\e[$((LINES / 2));${msg_col}H\e[1;31m$msg\e[0m"
    LAST_RENDER_SIGNATURE=""
    draw_search_bar
    return
  fi

  local render_signature
  render_signature=$(visible_signature)
  if [ "$render_signature" = "$LAST_RENDER_SIGNATURE" ]; then
    draw_search_bar
    return
  fi

  local active_wall="${FILTERED_WALLPAPERS[current_idx]}"
  get_wallpaper_colors "$active_wall"

  # Draw thumbnails in parallel to temporary buffer files to prevent interleaving and reduce latency
  local display_n=$((N < FILTERED_COUNT ? N : FILTERED_COUNT))
  local half_n=$((display_n / 2))
  for ((i = 0; i < display_n; i++)); do
    local offset=$((i - half_n))
    local w_idx=$(((current_idx + offset + FILTERED_COUNT) % FILTERED_COUNT))
    local slot_col=$((START_COL + (i + (N - display_n) / 2) * (T_WIDTH + SPACING)))

    local wall_path="${FILTERED_WALLPAPERS[w_idx]}"
    local wall_name="${wall_path##*/}"
    local thumb_path="$CACHE_DIR/${wall_name}.png"
    local border_thumb_path="$CACHE_DIR/${wall_name}.border.png"
    local preview_file

    if ((offset == 0)); then
      # Selected thumbnail uses the 3px bordered cached image
      if [ -f "$border_thumb_path" ]; then
        preview_file="$border_thumb_path"
      elif [ -f "$thumb_path" ]; then
        preview_file="$thumb_path"
      else
        preview_file="$wall_path"
      fi
    else
      # Unselected thumbnail uses the regular rounded cached image
      if [ -f "$thumb_path" ]; then
        preview_file="$thumb_path"
      else
        preview_file="$wall_path"
      fi
    fi

    # Render into buffer files in parallel
    kitty +kitten icat --transfer-mode=file --stdin=no --scale-up --place="${T_WIDTH}x${T_HEIGHT}@${slot_col}x${START_ROW}" "$preview_file" >"$TMP_DIR/icat_$i" 2>/dev/null &
  done
  wait

  # Clear terminal images and move cursor home
  echo -ne "\e[H" # Do NOT clear screen text (prevents background flash)
  kitty +kitten icat --clear 2>/dev/null

  # Instantly dump all buffered images sequentially
  for ((i = 0; i < N; i++)); do
    cat "$TMP_DIR/icat_$i" 2>/dev/null
    rm -f "$TMP_DIR/icat_$i"
  done

  LAST_RENDER_SIGNATURE="$render_signature"

  # Draw search bar
  draw_search_bar
}

# Cleanup and exit window on q/ESC/interrupts
cleanup() {
  tput cnorm
  tput rmcup
  printf '\e[?7h'
  kitty +kitten icat --clear 2>/dev/null
  if [ -n "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi

  # Kill parent Kitty window process if set
  if [ -n "$KITTY_PID" ]; then
    kill -9 "$KITTY_PID" 2>/dev/null
  fi
  exit 0
}
trap cleanup SIGINT SIGTERM

# shellcheck disable=SC2329 # Called by the SIGWINCH trap.
handle_resize() {
  calculate_layout
  LAST_RENDER_SIGNATURE=""
  redraw_screen
}
trap handle_resize SIGWINCH

read_key() {
  KEY=""
  IFS= read -r -s -n1 KEY || return 1

  if [[ "$KEY" == $'\e' ]]; then
    local next_chars
    read -r -s -n2 -t 0.05 next_chars
    KEY+="$next_chars"
  fi
}

# Enter alternate screen buffer, hide cursor, disable wrap
tput smcup
tput civis
printf '\e[?7l'

calculate_layout
update_filter
redraw_screen

# Input loop
while true; do
  read_key || continue

  # Fast-drain stdin if typing normal characters in search mode to prevent dropped inputs
  if [ "$SEARCH_FOCUSED" = true ] && [[ ${#KEY} -eq 1 && "$KEY" =~ [[:print:]] ]]; then
    QUERY+="$KEY"
    while IFS= read -r -s -n1 -t 0.001 next_char; do
      if [[ "$next_char" == $'\x7f' || "$next_char" == $'\b' ]]; then
        QUERY="${QUERY%?}"
      elif [[ "$next_char" == $'\e' || -z "$next_char" ]]; then
        break
      elif [[ "$next_char" =~ [[:print:]] ]]; then
        QUERY+="$next_char"
      fi
    done
    update_filter
    redraw_screen
    continue
  fi

  case "$KEY" in
  # Arrow keys (always navigate)
  $'\e[D')
    if ((FILTERED_COUNT > 0)); then
      current_idx=$(((current_idx - 1 + FILTERED_COUNT) % FILTERED_COUNT))
      redraw_screen
    fi
    ;;
  $'\e[C')
    if ((FILTERED_COUNT > 0)); then
      current_idx=$(((current_idx + 1) % FILTERED_COUNT))
      redraw_screen
    fi
    ;;
  # Enter (apply selection)
  "")
    if ((FILTERED_COUNT > 0)); then
      break
    fi
    ;;
  # Escape
  $'\e')
    if [ "$SEARCH_FOCUSED" = true ]; then
      SEARCH_FOCUSED=false
      redraw_screen
    else
      cleanup
    fi
    ;;
  # Backspace (only in search mode)
  $'\x7f' | $'\b')
    if [ "$SEARCH_FOCUSED" = true ]; then
      if [ -n "$QUERY" ]; then
        QUERY="${QUERY%?}"
        update_filter
        redraw_screen
      fi
    fi
    ;;
  # Other keys
  *)
    if [ "$SEARCH_FOCUSED" = false ]; then
      case "$KEY" in
      h | H)
        if ((FILTERED_COUNT > 0)); then
          current_idx=$(((current_idx - 1 + FILTERED_COUNT) % FILTERED_COUNT))
          redraw_screen
        fi
        ;;
      l | L)
        if ((FILTERED_COUNT > 0)); then
          current_idx=$(((current_idx + 1) % FILTERED_COUNT))
          redraw_screen
        fi
        ;;
      q | Q)
        cleanup
        ;;
      i | I | s | S | /)
        SEARCH_FOCUSED=true
        redraw_screen
        ;;
      esac
    else
      if [[ ${#KEY} -eq 1 && "$KEY" =~ [[:print:]] ]]; then
        QUERY+="$KEY"
        update_filter
        redraw_screen
      fi
    fi
    ;;
  esac
done

# Restore terminal state for image/wallpaper application sequence
tput cnorm
tput rmcup
printf '\e[?7h'
kitty +kitten icat --clear 2>/dev/null
clear
if [ -n "$TMP_DIR" ]; then
  rm -rf "$TMP_DIR"
fi

# Apply chosen wallpaper using preserved backend
FULL_PATH="${FILTERED_WALLPAPERS[current_idx]}"

if [ -n "$FULL_PATH" ] && [ -f "$FULL_PATH" ]; then
  # Run matugen: this both applies the wallpaper (via its own [config.wallpaper]
  # hook, which calls awww) and regenerates all color templates (sway, waybar,
  # wofi, gtk, kitty, etc.), reloading each one via their post_hooks.
  if command -v matugen &>/dev/null; then
    matugen image "$FULL_PATH" -m dark --source-color-index 0 --lightness-dark 0.08 --contrast 0
  fi

  # Desktop notification indicating success
  if command -v dunstify &>/dev/null; then
    dunstify -u low -a "Wallpaper Picker" -i "$FULL_PATH" "Theme Updated" "Applied wallpaper: $(basename "$FULL_PATH")"
    echo "dark" >~/.cache/matugen_mode

  else
    echo "dark" >~/.cache/matugen_mode
    notify-send "Theme Updated" "Applied wallpaper: $(basename "$FULL_PATH")"
  fi
fi

# Close host Kitty window process on normal completion
if [ -n "$KITTY_PID" ]; then
  kill -9 "$KITTY_PID" 2>/dev/null
fi

exit 0
