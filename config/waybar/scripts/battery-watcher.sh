#!/usr/bin/env bash
set -euo pipefail

# Battery Watcher for Waybar
# Triggers low battery notifications when discharging

STATE_FILE="/battery_watcher_state"

get_battery_info() {
  local bat_dir=""
  for b in /sys/class/power_supply/BAT* /sys/class/power_supply/battery; do
    if [[ -d "$b" ]]; then
      bat_dir="$b"
      break
    fi
  done

  if [[ -z "$bat_dir" ]]; then
    exit 0
  fi

  local capacity status
  capacity="$(cat "$bat_dir/capacity" 2>/dev/null || echo "100")"
  status="$(cat "$bat_dir/status" 2>/dev/null || echo "Unknown")"

  echo "$capacity" "$status"
}

notify_user() {
  local msg="$1"
  local urgency="${2:-normal}"
  if command -v dunstify >/dev/null 2>&1; then
    dunstify -u "$urgency" -a "Battery" "Battery" "$msg" -i "battery-caution" -r 9991
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send -u "$urgency" -a "Battery" "Battery" "$msg" -i "battery-caution" -r 9991
  fi
}

read -r cap stat < <(get_battery_info)

# Read previous notified state: 0=none, 1=low (14%), 2=critical (5%)
last_state=0
if [[ -f "$STATE_FILE" ]]; then
  last_state="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
fi

if [[ "$stat" == "Discharging" ]]; then
  if (( cap <= 5 )); then
    if [[ "$last_state" -ne 2 ]]; then
      notify_user "battery too low, charging recomended" "critical"
      echo 2 > "$STATE_FILE"
    fi
  elif (( cap <= 14 )); then
    if [[ "$last_state" -ne 1 && "$last_state" -ne 2 ]]; then
      notify_user "battery low" "normal"
      echo 1 > "$STATE_FILE"
    fi
  else
    if [[ "$last_state" -ne 0 ]]; then
      echo 0 > "$STATE_FILE"
    fi
  fi
else
  # Charging or Full: reset notification state
  if [[ "$last_state" -ne 0 ]]; then
    echo 0 > "$STATE_FILE"
  fi
fi
