#!/usr/bin/env bash

# Check dependencies
for cmd in fzf; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "$cmd is required. Please install it."
    exit 1
  fi
done

# Fetch variables from sway config to ensure consistency
SWAY_CONF="$HOME/.config/sway/config"
TERMINAL=$(grep -Po '^\s*set\s+\$term\s+\K.*' "$SWAY_CONF" | head -1 || echo "ghostty")
FILE_MANAGER=$(grep -Po '^\s*set\s+\$fileManager\s+\K.*' "$SWAY_CONF" | head -1 || echo "nautilus --new-window")
MENU=$(grep -Po '^\s*set\s+\$menu\s+\K.*' "$SWAY_CONF" | head -1 || echo "wofi --show drun")

# Define your shortcuts
declare -A KEYBINDS=(
  ["SUPER + Return       │ Open Terminal"]="swaymsg exec '$TERMINAL'"
  ["SUPER + C            │ Clipboard History Menu"]="swaymsg exec ~/.config/sway/scripts/clipboard.sh"
  ["SUPER + Q            │ Close Active Window"]="swaymsg kill"
  ["SUPER + M            │ System Monitor (btop)"]="swaymsg exec 'kitty --app-id=btop --class=btop -e btop'"
  ["SUPER + SHIFT + M    │ Exit Sway Session"]="swaymsg exit"
  ["SUPER + E            │ Open File Manager"]="swaymsg exec '$FILE_MANAGER'"
  ["SUPER + V            │ Toggle Floating Window"]="swaymsg floating toggle"
  ["SUPER + Space        │ Application Launcher (wofi)"]="swaymsg exec '$MENU'"
  ["SUPER + R            │ Run Application Launcher (wofi)"]="swaymsg exec '$MENU'"
  ["SUPER + P            │ Toggle Split Layout"]="swaymsg layout toggle split"
  ["SUPER + T            │ Toggle Split Layout"]="swaymsg layout toggle split"
  ["SUPER + F            │ Toggle Fullscreen Mode"]="swaymsg fullscreen"
  ["SUPER + CTRL + F     │ Toggle Fullscreen (Maximize)"]="swaymsg fullscreen"
  ["SUPER + SHIFT + L    │ Lock Screen"]="swaymsg exec hyprlock"
  ["SUPER + SHIFT + Q    │ Power / Logout Menu (wlogout)"]="swaymsg exec 'wlogout -p layer-shell'"
  ["SUPER + SHIFT + B    │ Toggle Waybar Status Bar"]="swaymsg exec ~/.config/sway/scripts/toggle-waybar.sh"
  ["SUPER + CTRL + B     │ Toggle Systemwide Blur"]="swaymsg exec ~/.config/sway/scripts/toggle-blur.sh"
  ["SUPER + .            │ Open Emoji Picker (wofi-emoji)"]="swaymsg exec wofi-emoji"
  ["SUPER + CTRL + C     │ Edit Sway Config (ghostty)"]="swaymsg exec \"ghostty -e bash -c 'cd ~/.config/sway/ && nvim ~/.config/sway/config'\""
  ["SUPER + CTRL + 1     │ Toggle Caffeine (Prevent Sleep)"]="swaymsg exec ~/.config/sway/scripts/toggle-caffeine.sh"
  ["SUPER + CTRL + 2     │ Toggle Gamemode (Performance)"]="swaymsg exec ~/.config/sway/scripts/toggle-gamemode.sh"
  ["SUPER + CTRL + R     │ Reload Sway Config (Full)"]="swaymsg exec ~/.config/sway/scripts/reload-config.sh"
  ["SUPER + CTRL + W     │ Wallpaper Switcher"]="swaymsg exec '~/.config/sway/scripts/wallpaper-switcher.sh'"
  ["SUPER + ALT + E      │ File Manager (yazi terminal)"]="swaymsg exec 'kitty --app-id=yazi --class=yazi -e yazi'"
  ["SUPER + D            │ Open VSCode (codium)"]="swaymsg exec codium"
  ["SUPER + B            │ Open Brave Browser"]="swaymsg exec brave"
  ["SUPER + ALT + W      │ WhatsApp Web App"]="swaymsg exec 'brave --app=https://web.whatsapp.com'"
  ["SUPER + ALT + G      │ Gemini AI Web App"]="swaymsg exec 'brave --app=https://gemini.google.com'"
  ["SUPER + ALT + P      │ Perplexity AI Web App"]="swaymsg exec 'brave --app=https://www.perplexity.ai'"
  ["SUPER + ALT + C      │ ChatGPT Web App"]="swaymsg exec 'brave --app=https://chatgpt.com'"
  ["SUPER + ALT + A      │ Claude AI Web App"]="swaymsg exec 'brave --app=https://claude.ai'"
  ["SUPER + N            │ Toggle Notification Center"]="swaymsg exec 'swaync-client -t -sw'"
  ["SUPER + SHIFT + N    │ Toggle Do Not Disturb"]="swaymsg exec 'swaync-client -d -sw'"
  ["SUPER + H            │ Toggle Help Menu Screen"]="swaymsg exec 'kitty --app-id=sway_help --class=sway_help -e ~/.config/sway/scripts/help.sh'"
  ["SUPER + I            │ Launch Sublime Text"]="swaymsg exec 'subl --launch-or-new-window'"
  ["SUPER + CTRL + P     │ Color Picker (hyprpicker)"]="swaymsg exec 'hyprpicker -a -f hex'"
  ["SUPER + Z            │ Zoom / Magnifier (wooz)"]="swaymsg exec 'wooz --zoom-in 25% --mouse-track --invert-scroll'"
  ["SUPER + Arrows       │ Move Focus Between Windows"]="echo 'Use SUPER + arrow keys to move focus'"
  ["Print                │ Screenshot Region (Save File)"]="swaymsg exec \"grim -g \\\"\$(slurp)\\\" ~/Pictures/Screenshots/\$(date +'%Y-%m-%d_%H-%M-%S').png\""
  ["SUPER + SHIFT + S    │ Screenshot Region (To Clipboard)"]="swaymsg exec \"grim -g \\\"\$(slurp)\\\" - | wl-copy\""
  ["SUPER + CTRL + S      │ Fullscreen Screenshot (Save File)"]="swaymsg exec \"grim ~/Pictures/Screenshots/\$(date +'%Y-%m-%d_%H-%M-%S').png\""
  ["SUPER + ALT + Return │ Scratchpad (kitty dropdown)"]="swaymsg exec ~/.config/sway/scripts/scratchpad-toggle.sh"
  ["SUPER + Scroll Wheel │ Cycle Active Workspaces Dynamically"]="echo 'Scroll mouse wheel while holding SUPER to shift workspaces'"
)

# Parse a color variable from palette.conf, returning a #RRGGBB hex string
COLORS_CONF="$HOME/.config/sway/palette.conf"
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
