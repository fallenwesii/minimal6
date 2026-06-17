#!/usr/bin/env bash
set -euo pipefail

CURRENT_BORDER=$(hyprctl getoption general:border_size -j | jq -r '.int')

if [ "$CURRENT_BORDER" = "0" ]; then
  hyprctl reload
else
  hyprctl --batch "\
    keyword general:border_size 0;\
    keyword general:gaps_in 0;\
    keyword general:gaps_out 0;\
    keyword decoration:rounding 0"
fi
