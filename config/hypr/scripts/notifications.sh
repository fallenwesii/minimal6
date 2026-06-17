#!/usr/bin/env bash

# Check dependencies
for cmd in jq fzf dunstctl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "$cmd is required. Please install it."
    exit 1
  fi
done

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
  --prompt=" Notifications: " \
  --header="Enter or Double-click to open, ESC to quit" \
  --bind 'double-click:accept' \
  --layout=reverse \
  --border=rounded \
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
