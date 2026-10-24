#!/bin/bash

# Toggle systemwide blur by flipping the global wildcard opacity rules
# in windowrules.conf (swayfx only blurs windows with opacity < 1).
# This includes terminal windows and everything rendered inside them.
#
# The last ON opacity is remembered via the `# blur-preferred-opacity:`
# marker line in windowrules.conf, so a value tuned by hand (e.g. for a
# whiter wallpaper) survives an off -> on cycle instead of a fixed default.

RULES="$HOME/.config/sway/conf/windowrules.conf"
DEFAULT_ON=0.84

if [ ! -f "$RULES" ]; then
  notify-send -u critical "Blur Toggle" "Missing $RULES"
  exit 1
fi

# Current value of the [app_id=".*"] wildcard rule
current=$(grep -m1 -oP '^\s*for_window\s+\[app_id="\.\*"\]\s+opacity\s+\K[0-9.]+' "$RULES")

if [ -z "$current" ]; then
  notify-send -u critical "Blur Toggle" "No wildcard opacity rule found in windowrules.conf"
  exit 1
fi

set_preferred() {
  if grep -qE '^\s*#\s*blur-preferred-opacity:' "$RULES"; then
    sed -i -E "s|^\s*#\s*blur-preferred-opacity:.*|# blur-preferred-opacity: $1|" "$RULES"
  else
    sed -i "/^for_window \[class=\"\.\*\"\] opacity/i # blur-preferred-opacity: $1" "$RULES"
  fi
}

if awk "BEGIN{exit !($current < 1)}"; then
  # ON -> OFF: remember the value we are turning off
  set_preferred "$current"
  new=1
  state="OFF"
else
  # OFF -> ON: restore the remembered value
  preferred=$(grep -m1 -oP '^\s*#\s*blur-preferred-opacity:\s*\K[0-9.]+' "$RULES")
  new=${preferred:-$DEFAULT_ON}
  state="ON"
fi

# Flip both wildcard rules (class + app_id)
sed -i -E \
  -e "s|^(\s*for_window\s+\[class=\"\.\*\"\]\s+opacity\s+)[0-9.]+|\1$new|" \
  -e "s|^(\s*for_window\s+\[app_id=\"\.\*\"\]\s+opacity\s+)[0-9.]+|\1$new|" \
  "$RULES"

# 1. Reload config so NEW windows get the new opacity
swaymsg reload >/dev/null 2>&1

# 2. Re-apply every opacity rule to EXISTING windows, in file order.
grep -E '^\s*for_window .* opacity ' "$RULES" | while IFS= read -r line; do
  rule="${line#for_window }"
  swaymsg "$rule" >/dev/null 2>&1
done

notify-send -u low -a "Blur" "Blur $state" "Systemwide blur is now $state (opacity $new)"
