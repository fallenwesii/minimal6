#!/usr/bin/env bash

# Check dependencies
for cmd in jq fzf dunstctl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "$cmd is required. Please install it."
    exit 1
  fi
done

# Parse a color variable from colors.conf, returning a #RRGGBB hex string
COLORS_CONF="$HOME/.config/hypr/colors.conf"
get_color() {
  local var="$1"
  local raw
  raw=$(grep -Po "^\\\$$var\s*=\s*rgba\(\K[0-9a-fA-F]+" "$COLORS_CONF" 2>/dev/null | head -1)
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

# Fetch Dunst history
history=$(dunstctl history)

# Parse history into a list for fzf
# Format: [ID] App: Summary | Body
# We use jq to clean up the output and handle potential special characters
entries=$(echo "$history" | jq -r '
    .data[0] | sort_by(.timestamp.data) | reverse | .[] | 
    "[\(.id.data)] \(.appname.data): \(.summary.data) | \(.body.data)"
' | sed 's/\\n/ /g')

# Run fzf
# --with-nth=2.. hides the ID from the search/display but we can still extract it
selected=$(echo "$entries" | fzf \
  --prompt=" Notifications: " \
  --header="Enter or Double-click to open, ESC to quit" \
  --bind 'double-click:accept' \
  --layout=reverse \
  --border=rounded \
  --color="bg:${C_BG},fg:${C_FG},bg+:${C_BGplus},fg+:${C_FGplus},prompt:${C_PROMPT},pointer:${C_POINTER},hl:${C_HL},hl+:${C_HLplus},border:${C_BORDER},header:${C_HEADER}" \
  --no-info)

if [[ -n "$selected" ]]; then
  # Extract ID from [ID]
  id=$(echo "$selected" | sed -n 's/^\[\([0-9]*\)\].*/\1/p')

  if [[ -n "$id" ]]; then
    # Pop the notification back to active status
    dunstctl history-pop "$id"

    # Small delay to ensure the notification is popped before calling action
    sleep 0.1

    # Trigger the default action (usually opens the app)
    dunstctl action
  fi
fi
