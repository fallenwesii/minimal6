#!/usr/bin/env bash

# Automatically detect your active default network interface
INTERFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)

# Fallback if no default route is found
if [ -z "$INTERFACE" ]; then
  echo "Offline"
  exit 0
fi

# Get initial bytes received and transmitted
R1=$(cat /sys/class/net/"$INTERFACE"/statistics/rx_bytes)
T1=$(cat /sys/class/net/"$INTERFACE"/statistics/tx_bytes)

# Wait 1 second to measure data flow
sleep 1

# Get consecutive bytes
R2=$(cat /sys/class/net/"$INTERFACE"/statistics/rx_bytes)
T2=$(cat /sys/class/net/"$INTERFACE"/statistics/tx_bytes)

# Calculate bytes per second
TBPS=$((T2 - T1))
RBPS=$((R2 - R1))

# Convert Bytes to Megabytes using awk instead of bc
DOWN=$(awk "BEGIN {printf \"%.2f\", $RBPS / 1048576}")
UP=$(awk "BEGIN {printf \"%.2f\", $TBPS / 1048576}")

# Output format for Waybar with clean spacing
echo "󰁞 ${UP}  ${DOWN}"

