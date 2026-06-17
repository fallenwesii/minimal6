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
  ["SUPER + E            │ Open File Manager"]="hyprctl dispatch exec $FILE_MANAGER"
  ["SUPER + V            │ Toggle Floating Window"]="hyprctl dispatch togglefloating"
  ["SUPER + Space        │ Application Launcher (wofi)"]="hyprctl dispatch exec \"$MENU\""
  ["SUPER + R            │ Run Application Launcher (wofi)"]="hyprctl dispatch exec \"$MENU\""
  ["SUPER + P            │ Dwindle Pseudo-mode"]="hyprctl dispatch pseudo"
  ["SUPER + T            │ Dwindle Toggle Split Layout"]="hyprctl dispatch layoutmsg togglesplit"
  ["SUPER + F            │ Toggle Fullscreen Mode"]="hyprctl dispatch fullscreen"
  ["SUPER + L            │ Lock Screen (hyprlock)"]="hyprctl dispatch exec hyprlock"
  ["SUPER + SHIFT + Q    │ Power / Logout Menu (wlogout)"]="hyprctl dispatch exec \"wlogout -p layer-shell\""
  ["SUPER + SHIFT + B    │ Toggle Waybar Status Bar"]="hyprctl dispatch exec ~/.config/hypr/scripts/toggle-waybar.sh"
  ["SUPER + SHIFT + W    │ Switch Wallpaper (awww)"]="hyprctl dispatch exec ~/.config/hypr/scripts/wallpaper.sh"
  ["SUPER + \            │ Switch Layout Variant 1"]="hyprctl dispatch exec ~/.config/hypr/scripts/layout.sh"
  ["SUPER + SHIFT + \    │ Switch Layout Variant 2"]="hyprctl dispatch exec ~/.config/hypr/scripts/layout2.sh"
  ["SUPER + .            │ Open Emoji Picker (wofi-emoji)"]="hyprctl dispatch exec wofi-emoji"
  ["SUPER + CTRL + R     │ Reload Hyprland Config"]="hyprctl reload"
  ["SUPER + ALT + E      │ File Manager (yazi terminal)"]="hyprctl dispatch exec \"kitty --class yazi -e yazi\""
  ["SUPER + B            │ Open Brave Browser"]="hyprctl dispatch exec brave"
  ["SUPER + ALT + W      │ WhatsApp Web App"]="hyprctl dispatch exec \"brave --app=https://web.whatsapp.com\""
  ["SUPER + ALT + G      │ Gemini AI Web App"]="hyprctl dispatch exec \"brave --app=https://gemini.google.com\""
  ["SUPER + S            │ Quick Settings Menu"]="hyprctl dispatch exec \"kitty --class quick-settings -e ~/.config/hypr/scripts/quick-settings.sh\""
  ["SUPER + N            │ Notification History (fzf)"]="hyprctl dispatch exec \"kitty --class notifications -e ~/.config/hypr/scripts/notifications.sh\""
  ["SUPER + H            │ Toggle Help Menu Screen"]="hyprctl dispatch exec \"kitty --class hypr_help -e ~/.config/hypr/scripts/help.sh\""
  ["Print                │ Screenshot Region (Save File)"]="hyprctl dispatch exec \"grim -g \\\"\$(slurp)\\\" ~/Pictures/Screenshots/\$(date +'%Y-%m-%d_%H-%M-%S').png\""
  ["SUPER + SHIFT + S    │ Screenshot Region (To Clipboard)"]="hyprctl dispatch exec \"grim -g \\\"\$(slurp)\\\" - | wl-copy\""
  ["SUPER + ALT + S      │ Fullscreen Screenshot (Save File)"]="hyprctl dispatch exec \"grim ~/Pictures/Screenshots/\$(date +'%Y-%m-%d_%H-%M-%S').png\""
  ["SUPER + SHIFT +CTRL+B│ Toggle Compact Mode Layout"]="hyprctl dispatch exec ~/.config/hypr/scripts/toggle-compact.sh"
  ["SUPER + Z            │ Jump Directly to 1.6x Screen Zoom"]="hyprctl keyword cursor:zoom_factor 1.6"
  ["SUPER + SHIFT + Z    │ Reset Screen Zoom Factor to 1.0"]="hyprctl keyword cursor:zoom_factor 1.0"
  ["SUPER + Scroll Wheel │ Cycle Active Workspaces Dynamically"]="echo 'Scroll mouse wheel while holding SUPER to shift workspaces'"
  ["SUPER + CTRL + C     │ Edit Hyprland Config (ghostty)"]="hyprctl dispatch exec \"ghostty -e bash -c 'cd ~/.config/hypr/ && nvim ~/.config/hypr/hyprland.conf'\""
  ["SUPER + SHIFT + T    │ Switch Theme Randomly"]="hyprctl dispatch exec \"~/.config/theme-switcher/theme-switcher.sh random\""
)

# Print lines to fzf, sort them, and capture the human selection
SELECTION=$(for key in "${!KEYBINDS[@]}"; do echo "$key"; done | sort | fzf \
  --prompt="⌨️ Search Shortcuts: " \
  --header="Minimal6 Keybindings" \
  --height=100% \
  --border=rounded \
  --layout=reverse \
  --color="prompt:#89dceb,pointer:#89dceb,hl:#a6e3a1,hl+:#a6e3a1,border:#313244,header:#89dceb" \
  --no-info)

# Extract and fire the command
if [ -n "$SELECTION" ]; then
  COMMAND="${KEYBINDS[$SELECTION]}"
  eval "$COMMAND"
fi
