#!/usr/bin/env bash

# Check dependencies
for cmd in fzf; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "$cmd is required. Please install it."
    exit 1
  fi
done

# Fetch variables from programs.conf to ensure consistency
HYPR_CONF="$HOME/.config/hypr/conf/programs.conf"
TERMINAL=$(grep -Po '^\$terminal\s*=\s*\K.*' "$HYPR_CONF" || echo "kitty")
FILE_MANAGER=$(grep -Po '^\$fileManager\s*=\s*\K.*' "$HYPR_CONF" || echo "nautilus")
MENU=$(grep -Po '^\$menu\s*=\s*\K.*' "$HYPR_CONF" || echo "wofi --show drun")

# Define your shortcuts
declare -A KEYBINDS=(
  ["SUPER + Return       │ Open Terminal"]="hyprctl dispatch exec $TERMINAL"
  ["SUPER + C            │ Clipboard History Menu"]="hyprctl dispatch exec \"cliphist list | wofi --dmenu --pre-display-cmd 'echo \"%s\" | cut -f 2' | cliphist decode | wl-copy\""
  ["SUPER + Q            │ Close Active Window"]="hyprctl dispatch killactive"
  ["SUPER + M            │ System Monitor (btop)"]="hyprctl dispatch exec \"kitty --class btop -e btop\""
  ["SUPER + SHIFT + M    │ Exit Hyprland Session"]="hyprctl dispatch exit"
  ["SUPER + E            │ Open File Manager"]="hyprctl dispatch exec \"$FILE_MANAGER\""
  ["SUPER + V            │ Toggle Floating Window"]="hyprctl dispatch togglefloating"
  ["SUPER + Space        │ Application Launcher (wofi)"]="hyprctl dispatch exec \"$MENU\""
  ["SUPER + R            │ Run Application Launcher (wofi)"]="hyprctl dispatch exec \"$MENU\""
  ["SUPER + P            │ Dwindle Pseudo-mode"]="hyprctl dispatch pseudo"
  ["SUPER + T            │ Dwindle Toggle Split Layout"]="hyprctl dispatch layoutmsg togglesplit"
  ["SUPER + F            │ Toggle Fullscreen Mode"]="hyprctl dispatch fullscreen"
  ["SUPER + L            │ Lock Screen (hyprlock)"]="hyprctl dispatch exec hyprlock"
  ["SUPER + SHIFT + Q    │ Power / Logout Menu (wlogout)"]="hyprctl dispatch exec \"wlogout -p layer-shell\""
  ["SUPER + SHIFT + B    │ Toggle Waybar Status Bar"]="hyprctl dispatch exec ~/.config/hypr/scripts/toggle-waybar.sh"
  ["SUPER + .            │ Open Emoji Picker (wofi-emoji)"]="hyprctl dispatch exec wofi-emoji"
  ["SUPER + CTRL + C     │ Edit Hyprland Config (ghostty)"]="hyprctl dispatch exec \"ghostty -e bash -c 'cd ~/.config/hypr/ && nvim ~/.config/hypr/hyprland.conf'\""
  ["SUPER + CTRL + R     │ Reload Hyprland Config"]="hyprctl reload"
  ["SUPER + CTRL + G     │ Toggle Grayscale Mode"]="hyprctl dispatch exec ~/.config/hypr/scripts/toggle-grayscale.sh"
  ["SUPER + CTRL + L     │ Toggle Light Mode"]="hyprctl dispatch exec ~/.config/hypr/scripts/light-mode.sh"
  ["SUPER + CTRL + W     │ Wallpaper Switcher"]="hyprctl dispatch exec \"kitty --class wallpaper-picker -e ~/.config/hypr/scripts/wallpaper-switcher.sh\""
  ["SUPER + O            │ Centered Floating Window"]="hyprctl dispatch exec ~/.config/hypr/scripts/centered-floating-window.sh"
  ["SUPER + ALT + E      │ File Manager (yazi terminal)"]="hyprctl dispatch exec \"kitty --class yazi -e yazi\""
  ["SUPER + B            │ Open Brave Browser"]="hyprctl dispatch exec brave"
  ["SUPER + ALT + W      │ WhatsApp Web App"]="hyprctl dispatch exec \"brave --app=https://web.whatsapp.com\""
  ["SUPER + ALT + G      │ Gemini AI Web App"]="hyprctl dispatch exec \"brave --app=https://gemini.google.com\""
  ["SUPER + S            │ Quick Settings Menu"]="hyprctl dispatch exec \"kitty --class quick-settings -e ~/.local/bin/minimal6\""
  ["SUPER + N            │ Notification History (fzf)"]="hyprctl dispatch exec \"kitty --class notifications -e ~/.config/hypr/scripts/notifications.sh\""
  ["SUPER + H            │ Toggle Help Menu Screen"]="hyprctl dispatch exec \"kitty --class hypr_help -e ~/.config/hypr/scripts/help.sh\""
  ["SUPER + I            │ Launch Sublime Text"]="hyprctl dispatch exec subl --launch-or-new-window"
  ["Print                │ Screenshot Region (Save File)"]="hyprctl dispatch exec \"grim -g \\\"\$(slurp)\\\" ~/Pictures/Screenshots/\$(date +'%Y-%m-%d_%H-%M-%S').png\""
  ["SUPER + SHIFT + S    │ Screenshot Region (To Clipboard)"]="hyprctl dispatch exec \"grim -g \\\"\$(slurp)\\\" - | wl-copy\""
  ["SUPER + ALT + S      │ Fullscreen Screenshot (Save File)"]="hyprctl dispatch exec \"grim ~/Pictures/Screenshots/\$(date +'%Y-%m-%d_%H-%M-%S').png\""
  ["SUPER + SHIFT +CTRL+B│ Toggle Compact Mode Layout"]="hyprctl dispatch exec ~/.config/hypr/scripts/toggle-compact.sh"
  ["SUPER + Z            │ Jump Directly to 1.4x Screen Zoom"]="hyprctl keyword cursor:zoom_factor 1.4"
  ["SUPER + SHIFT + Z    │ Reset Screen Zoom Factor to 1.0"]="hyprctl keyword cursor:zoom_factor 1.0"
)

# Parse a color variable from colors.conf, returning a #RRGGBB hex string
COLORS_CONF="$HOME/.config/hypr/colors.conf"
get_color() {
  local var="$1"
  # Extract value from lines like:  $primary = rgba(88d1ebff)
  local raw
  raw=$(grep -Po "^\\\$$var\s*=\s*rgba\(\K[0-9a-fA-F]+" "$COLORS_CONF" 2>/dev/null | head -1)
  # raw is 8 hex chars (RRGGBBAA); we only want the first 6
  echo "#${raw:0:6}"
}

# Map matugen semantic colors to fzf roles
C_PROMPT=$(get_color "primary")
C_POINTER=$(get_color "primary")
C_HEADER=$(get_color "primary")
C_HL=$(get_color "secondary")
C_HLplus=$(get_color "primary_fixed")
C_BORDER=$(get_color "outline_variant")
C_BG=$(get_color "background")
C_FG=$(get_color "on_surface")
C_BGplus=$(get_color "surface_container_high")
C_FGplus=$(get_color "on_surface")

# Print lines to fzf, sort them, and capture the human selection
SELECTION=$(for key in "${!KEYBINDS[@]}"; do echo "$key"; done | sort | fzf \
  --prompt=" Search Shortcuts: " \
  --height=100% \
  --border=rounded \
  --layout=reverse \
  --color="bg:${C_BG},fg:${C_FG},bg+:${C_BGplus},fg+:${C_FGplus},prompt:${C_PROMPT},pointer:${C_POINTER},hl:${C_HL},hl+:${C_HLplus},border:${C_BORDER},header:${C_HEADER}" \
  --no-info)

# Extract and fire the command
if [ -n "$SELECTION" ]; then
  COMMAND="${KEYBINDS[$SELECTION]}"
  eval "$COMMAND"
fi
