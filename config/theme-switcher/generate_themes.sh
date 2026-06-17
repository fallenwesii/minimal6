#!/bin/bash

THEME_DIR="$HOME/.config/theme-switcher/themes"

# Define colors for each theme
# format: theme_name|bg|fg|accent|inactive|border
declare -a THEMES=(
  "Catppuccin-Dark-Frappe|#303446|#eff1f5|#8caaee|#737994|#8caaee"
  "Graphite-Dark|#242424|#eeeeee|#a0a0a0|#707070|#a0a0a0"
  "Gruvbox-Dark-Soft|#32302f|#fbf1c7|#83a598|#928374|#83a598"
  "Material-Dark-Oceanic|#263238|#eceff1|#009688|#546e7a|#009688"
  "Orchis-Dark|#2d2d2d|#e3e3e3|#999999|#666666|#999999"
  "Tokyonight-Dark-Moon|#222436|#e9e9ed|#589ed7|#565f89|#589ed7"
  "WhiteSur-Dark|#1e1e1e|#ffffff|#b0b0b0|#777777|#b0b0b0"
)

for theme_data in "${THEMES[@]}"; do
  IFS='|' read -r name bg fg accent inactive border <<<"$theme_data"

  echo "Generating config for $name..."

  # Create directories
  mkdir -p "$THEME_DIR/$name/waybar"
  mkdir -p "$THEME_DIR/$name/wofi"
  mkdir -p "$THEME_DIR/$name/dunst"
  mkdir -p "$THEME_DIR/$name/wlogout"

  # Generate border colors for Hyprland
  cat >"$THEME_DIR/$name/hyprland-colors.conf" <<EOF
col.active_border = rgba(${border:1}ee)
col.inactive_border = rgba(${inactive:1}ee)
EOF

  # Generate waybar style.css
  cat >"$THEME_DIR/$name/waybar/style.css" <<EOF
/* Theme: $name */
* {
  font-family: "JetBrainsMono Nerd Font";
}

window#waybar {
  background-color: $bg;
  color: $fg;
}

/* Tooltips / Popups styling - Themed background and border */
tooltip {
  background: $bg;
  border: 1px solid $accent;
  border-radius: 8px;
}

tooltip label {
  color: $fg;
  padding: 6px;
}

window#waybar #clock {
  color: $accent;
}

window#waybar #workspaces button {
  color: $inactive;
  padding: 0 4px;
}

window#waybar #workspaces button.active {
  color: $accent;
  font-weight: bold;
}

window#waybar #workspaces button:hover {
  color: $bg;
  background-color: $accent;
}

window#waybar #window {
  color: $accent;
}

/* Iconic Modules - Clean appearance, no hover background */
window#waybar #memory, 
window#waybar #cpu, 
window#waybar #pulseaudio, 
window#waybar #battery, 
window#waybar #custom-nightmode, 
window#waybar #custom-bluetooth, 
window#waybar #network, 
window#waybar #custom-powermenu, 
window#waybar #custom-tuned, 
window#waybar #custom-network_speed {
  color: $accent;
  padding: 0 4px;
  margin: 0;
}

window#waybar #battery.charging,
window#waybar #battery.plugged {
  color: $accent;
}
EOF

  # Generate wofi style.css
  cat >"$THEME_DIR/$name/wofi/style.css" <<EOF
window { background-color: $bg; color: $fg; font-family: "JetBrainsMono Nerd Font"; }
#input { background-color: $inactive; color: $fg; }
#entry:selected { background-color: $accent; color: $bg; }
#entry:hover { background-color: $accent; color: $bg; }
EOF

  # Generate dunstrc
  cat >"$THEME_DIR/$name/dunst/dunstrc" <<EOF
[global]
    frame_color = "$accent"
    separator_color = "$accent"
    font = JetBrainsMono Nerd Font 10
    corner_radius = 7
    background = "$bg"
    foreground = "$fg"

[urgency_low]
    background = "$bg"
    foreground = "$inactive"
    timeout = 5

[urgency_normal]
    background = "$bg"
    foreground = "$fg"
    timeout = 10

[urgency_critical]
    background = "$bg"
    foreground = "$accent"
    frame_color = "#ff5555"
    timeout = 0
EOF

  # Generate kitty.conf snippet
  cat >"$THEME_DIR/$name/kitty.conf" <<EOF
foreground $fg
background $bg
selection_foreground $bg
selection_background $accent
cursor $accent
active_border_color $accent
inactive_border_color $inactive
EOF

  # Generate ghostty config snippet
  cat >"$THEME_DIR/$name/ghostty" <<EOF
foreground = $fg
background = $bg
selection-foreground = $bg
selection-background = $accent
cursor-color = $accent
EOF

done

echo "Done generating theme configs."
