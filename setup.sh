#!/bin/bash

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Initial Setup ---
clear

show_header() {
  if command -v gum &>/dev/null; then
    gum style \
      --foreground 82 --border-foreground 82 --border double \
      --align center --width 50 --margin "1 2" --padding "2 4" \
      "minimal6 dotfiles" "Setup Wizard"
  else
    echo -e "${BLUE}"
    echo ""
    echo -e "${NC}"
  fi
}

show_header

# --- Package Lists ---
PACMAN_PKGS=(
  "hyprland" "hypridle" "hyprlock" "hyprsunset" "gammastep"
  "xdg-desktop-portal-hyprland" "waybar" "dunst" "wofi" "nwg-look"
  "fzf" "gum" "figlet" "grim" "slurp" "wl-clipboard" "cliphist"
  "brightnessctl" "pavucontrol" "polkit-gnome" "gvfs" "tuned" "jq"
  "xdg-utils" "git" "libnotify" "psmisc" "procps-ng" "iproute2"
  "pipewire" "wireplumber" "blueman" "bluez" "bluez-utils"
  "kitty" "alacritty" "nautilus" "yazi" "btop"
  "ttf-jetbrains-mono-nerd" "noto-fonts" "qt5-wayland" "qt5ct" "qt6ct"
  "networkmanager" "base-devel" "xorg-xhost" "gamemode" "quickshell"
  "neovim" "kvantum" "ghostty" "awww"
  "python3" "python-pyfiglet" "matugen"
)

AUR_PKGS=(
  "wlogout" "wofi-emoji" "brave-bin" "nm-connection-editor"
  "bibata-cursor-theme"
)

# --- 2. Check for Build Tools and AUR Helper ---
echo -e "${YELLOW}Checking for build tools...${NC}"

check_package() {
  pacman -Qi "$1" &>/dev/null
}

install_if_missing() {
  local pkg=$1
  if ! check_package "$pkg"; then
    echo -n "Installing $pkg "
    sudo pacman -S --noconfirm "$pkg" &>/dev/null
    echo -e "${GREEN}*********.......... Done${NC}"
  else
    echo -e "${BLUE}$pkg is already installed.${NC}"
  fi
}

# Essential build tools for starting
for tool in base-devel git; do
  install_if_missing "$tool"
done

# Check for AUR helper (yay)
if ! command -v yay &>/dev/null; then
  echo -e "${YELLOW}yay not found. Installing yay...${NC}"
  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
  cd /tmp/yay-bin || exit
  makepkg -si --noconfirm &>/dev/null
  cd - || exit
  echo -e "${GREEN}yay installed successfully.${NC}"
else
  echo -e "${BLUE}yay is already installed.${NC}"
fi

# Warning for important components
if ! command -v sddm &>/dev/null && ! command -v gdm &>/dev/null && ! command -v ly &>/dev/null; then
  echo -e "${RED}Warning: No Login Manager (SDDM/GDM/LY) detected.${NC}"
  echo -e "${YELLOW}Minimal6 installs only the required packages but a login manager is recommended for a seamless experience.${NC}"
  sleep 2
fi

# --- 3. Terms and Conditions ---
echo -e "\v"
echo -e "Wait! i almost forgot, i have realised you haven't read the terms and conditions 😂 "
sleep 5
clear
echo -e "\v\v\t\t${NC}Terms and conditions${NC} "
echo -e "\tAs a condition of using minimal6 dotfiles you agree to: "
echo -e "\t1. Tell everyone that you use linux"
echo -e "\t2. Hate windows 11 as much as you can"
echo -e "\v\v\v\v\v\v\v"
echo -e "\v\v\v\v"
echo -e "\v\v\v"
sleep 5

# --- 4. Installation Block ---
echo -e "${BLUE}Starting installation of dependencies...${NC}"

# Install Pacman packages
for pkg in "${PACMAN_PKGS[@]}"; do
  if ! check_package "$pkg"; then
    echo -e "${BLUE}Installing pacman package: $pkg${NC}"
    sudo pacman -S --noconfirm "$pkg"
  else
    echo -e "${GREEN}$pkg is already installed.${NC}"
  fi
done

# Install AUR packages
for pkg in "${AUR_PKGS[@]}"; do
  if ! yay -Qi "$pkg" &>/dev/null; then
    echo -e "${YELLOW}Installing AUR package: $pkg${NC}"
    yay -S --noconfirm "$pkg"
  else
    echo -e "${GREEN}$pkg (AUR) is already installed.${NC}"
  fi
done

# Optional: libadwaita-without-adwaita (allows theming of libadwaita apps)
if ! yay -Qi libadwaita-without-adwaita &>/dev/null; then
  echo -e "${YELLOW}libadwaita-without-adwaita allows proper theming of GNOME/libadwaita apps.${NC}"
  read -p "Install libadwaita-without-adwaita? (y/n): " install_libadwaita
  if [[ "$install_libadwaita" == "y" || "$install_libadwaita" == "Y" ]]; then
    yay -S --noconfirm libadwaita-without-adwaita
  else
    echo -e "${BLUE}Skipping libadwaita-without-adwaita.${NC}"
  fi
else
  echo -e "${GREEN}libadwaita-without-adwaita is already installed.${NC}"
fi

# --- 5. Make all scripts executable ---
echo -e "${YELLOW}Making scripts executable...${NC}"
find . -name "*.sh" -exec chmod +x {} +

# --- 6. Configuration & Symlinking ---
DOTFILES_DIR=$(pwd)
CONF_DIR="$HOME/.config"
mkdir -p "$HOME/.local/bin"

# Detect whether a target already belongs to the minimal6 dotfiles repo
# (i.e. resolves inside $DOTFILES_DIR). Only this repo is treated as
# dotfiles-managed; anything else is a foreign config and gets backed up.
is_dotfiles_dir() {
  local dir=$1
  [[ "$(readlink -f "$dir" 2>/dev/null)" == "$DOTFILES_DIR"* ]]
}

is_dotfiles_link() {
  is_dotfiles_dir "$1"
}

confirm_and_link() {
  local source=$1
  local target=$2
  local name=$3

  if [[ -e "$target" || -L "$target" ]]; then
    if is_dotfiles_link "$target"; then
      # Already points into $DOTFILES_DIR: it's ours, just remove and relink.
      echo -e "${YELLOW}Removing existing $name (points to dotfiles)...${NC}"
      rm -rf "$target"
    else
      echo -e "${YELLOW}Backing up existing $name...${NC}"
      mv "$target" "${target}.bak_$(date +%Y%m%d_%H%M%S)"
    fi
    ln -sf "$source" "$target"
    echo -e "${GREEN}Linked $name${NC}"
  else
    ln -sf "$source" "$target"
    echo -e "${GREEN}Linked $name${NC}"
  fi
}

# Remove bookmarks file/link in target directories to avoid git tracking them
rm -f "$CONF_DIR/gtk-3.0/bookmarks" "$CONF_DIR/gtk-4.0/bookmarks"

for dir in "$DOTFILES_DIR/config"/*; do
  dir_name=$(basename "$dir")
  if [[ "$dir_name" == "gtk-3.0" ]]; then
    # Handle gtk-3.0 specially because of private bookmarks file
    if [[ -L "$CONF_DIR/$dir_name" ]]; then
      echo "Removing old gtk-3.0 directory symlink..."
      rm -f "$CONF_DIR/$dir_name"
    fi
    mkdir -p "$CONF_DIR/$dir_name"
    for file in "$dir"/*; do
      file_name=$(basename "$file")
      if [[ "$file_name" != "bookmarks" ]]; then
        confirm_and_link "$file" "$CONF_DIR/$dir_name/$file_name" "$dir_name/$file_name"
      fi
    done
  else
    confirm_and_link "$dir" "$CONF_DIR/$dir_name" "$dir_name"
  fi
done

# Clean up stale *.bak_* symlinks that were produced by previous buggy runs.
# These are useless: they are just symlinks back into a minimal6 repo, not
# real backups. Remove them so they stop accumulating.
echo -e "${YELLOW}Removing stale dotfiles backup symlinks...${NC}"
for bak in "$CONF_DIR"/*.bak_*; do
  [ -L "$bak" ] || continue
  if is_dotfiles_link "$bak"; then
    rm -f "$bak"
    echo -e "  ${BLUE}Removed $bak${NC}"
  fi
done

# Handle special files/dirs
confirm_and_link "$DOTFILES_DIR/.themes" "$HOME/.themes" ".themes"
confirm_and_link "$DOTFILES_DIR/.icons" "$HOME/.icons" ".icons"

# .bashrc is sensitive — always ask before touching it.
read -p "Link minimal6 ~/.bashrc to your home? (y/n): " link_bashrc
if [[ "$link_bashrc" == "y" || "$link_bashrc" == "Y" ]]; then
  confirm_and_link "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc" ".bashrc"
else
  echo -e "${BLUE}Skipping .bashrc. Your current ~/.bashrc is untouched.${NC}"
fi

# Kvantum themes
if command -v kvantummanager &>/dev/null; then
  confirm_and_link "$DOTFILES_DIR/kvantum-themes" "$HOME/.config/Kvantum" "kvantum-themes"
fi

# --- 7. Paths and Assets ---
echo -e "${YELLOW}Setting up scripts and wallpapers...${NC}"

# net-speed.sh
if [ -f "$HOME/.local/bin/net-speed.sh" ]; then
  read -p "Overwrite existing ~/.local/bin/net-speed.sh? (y/n): " choice
  if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    cp "$DOTFILES_DIR/net-speed.sh" "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/net-speed.sh"
    echo -e "${GREEN}Updated net-speed.sh${NC}"
  else
    echo "Skipping net-speed.sh"
  fi
else
  cp "$DOTFILES_DIR/net-speed.sh" "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/net-speed.sh"
  echo -e "${GREEN}Installed net-speed.sh${NC}"
fi

# minimal6 python script
if [ -f "$HOME/.local/bin/minimal6" ]; then
  read -p "Overwrite existing ~/.local/bin/minimal6? (y/n): " choice
  if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    cp "$DOTFILES_DIR/minimal6" "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/minimal6"
    echo -e "${GREEN}Updated minimal6${NC}"
  else
    echo "Skipping minimal6"
  fi
else
  cp "$DOTFILES_DIR/minimal6" "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/minimal6"
  echo -e "${GREEN}Installed minimal6${NC}"
fi

# --- 8. Resolve Hardcoded Paths ---
# Some config files were originally copied from the author's system and contain
# hardcoded paths (e.g. /home/wesii). This section fixes them for the current user.
echo -e "${YELLOW}Resolving hardcoded paths for your system...${NC}"

# Helper: in-place sed that works on both GNU and BSD
sed_inplace() {
  sed -i "$1" "$2"
}

# -- quickshell/shell.qml: resolve hardcoded home paths --
SHELL_QML="$CONF_DIR/quickshell/shell.qml"
REAL_SHELL_QML=$(realpath "$SHELL_QML" 2>/dev/null || echo "")
if [ -n "$REAL_SHELL_QML" ] && [ -f "$REAL_SHELL_QML" ]; then
  sed_inplace "s|/home/[^/]*/\.config|/home/wesii/\.config|g" "$REAL_SHELL_QML" # Ensure consistency
  sed_inplace "s|/home/[^/]*/\.config|$HOME/.config|g" "$REAL_SHELL_QML"
  echo -e "${GREEN}Fixed paths in quickshell/shell.qml${NC}"
fi

# -- hypr/colors.conf: resolve hardcoded wallpaper image path --
COLORS_CONF="$CONF_DIR/hypr/colors.conf"
REAL_COLORS=$(realpath "$COLORS_CONF" 2>/dev/null || echo "")
if [ -n "$REAL_COLORS" ] && [ -f "$REAL_COLORS" ]; then
  sed_inplace "s|/home/[^/]*/Pictures|$HOME/Pictures|g" "$REAL_COLORS"
  echo -e "${GREEN}Fixed \$image path in hypr/colors.conf${NC}"
fi

# -- GTK symlinks: recreate the gtk-4.0 and gtk-3.0 symlinks that pointed --
# -- to /home/wesii/.themes/... so they point to the current user's ~/.themes --
echo -e "${YELLOW}Recreating GTK theme symlinks...${NC}"
ADW_GTK4="$HOME/.themes/adw-gtk3-dark/gtk-4.0"
ADW_GTK3="$HOME/.themes/adw-gtk3-dark/gtk-3.0"
GTK4_CONF="$CONF_DIR/gtk-4.0"
GTK3_CONF="$CONF_DIR/gtk-3.0"

# Only proceed if the .themes dir actually landed in $HOME (via symlink or copy)
if [ -d "$HOME/.themes/adw-gtk3-dark" ]; then
  # gtk-4.0 files that should be symlinked from ~/.config/gtk-4.0/ into the theme
  for gtkfile in gtk.css gtk-dark.css libadwaita.css libadwaita-tweaks.css matugen-override.css colors.css assets; do
    TARGET_LINK="$GTK4_CONF/$gtkfile"
    THEME_SRC="$ADW_GTK4/$gtkfile"
    if [ -e "$THEME_SRC" ]; then
      # Remove old (possibly broken) symlink or file, then recreate
      rm -f "$TARGET_LINK"
      ln -sf "$THEME_SRC" "$TARGET_LINK"
      echo -e "  ${GREEN}Linked gtk-4.0/$gtkfile${NC}"
    fi
  done
  # gtk-3.0/colors.css symlink
  GTK3_COLORS="$GTK3_CONF/colors.css"
  THEME_GTK3_COLORS="$ADW_GTK3/colors.css"
  if [ -e "$THEME_GTK3_COLORS" ]; then
    rm -f "$GTK3_COLORS"
    ln -sf "$THEME_GTK3_COLORS" "$GTK3_COLORS"
    echo -e "  ${GREEN}Linked gtk-3.0/colors.css${NC}"
  fi
else
  echo -e "  ${YELLOW}~/.themes/adw-gtk3-dark not found yet — GTK symlinks will be created after theme setup.${NC}"
fi

echo -e "${GREEN}Hardcoded path resolution complete.${NC}"

# -- wofi/style.css: @import needs absolute path from root --
WOI_CSS="$CONF_DIR/wofi/style.css"
REAL_WOI_CSS=$(realpath "$WOI_CSS" 2>/dev/null || echo "")
if [ -n "$REAL_WOI_CSS" ] && [ -f "$REAL_WOI_CSS" ]; then
  sed_inplace "s|/home/wesii/\.config/wofi/colors\.css|$HOME/.config/wofi/colors.css|g" "$REAL_WOI_CSS"
  # Also handle fallback replacement if it was imported relative/without home originally
  sed_inplace "s|@import \"colors\.css\";|@import \"$HOME/.config/wofi/colors.css\";|g" "$REAL_WOI_CSS"
  echo -e "${GREEN}Fixed @import path in wofi/style.css to $HOME/.config/wofi/colors.css${NC}"
fi

# -- wlogout/style.css: icon paths are absolute and must point to this user's home --
# Follows the symlink to the real dotfiles file and replaces any /home/wesii/.config/wlogout/
# with the current user's path. Safe to re-run (already-correct paths are left unchanged).
WLOGOUT_CSS="$CONF_DIR/wlogout/style.css"
REAL_WLOGOUT_CSS=$(realpath "$WLOGOUT_CSS" 2>/dev/null || echo "")
if [ -n "$REAL_WLOGOUT_CSS" ] && [ -f "$REAL_WLOGOUT_CSS" ]; then
  sed_inplace "s|file:///home/wesii/\.config/wlogout/|file://$HOME/.config/wlogout/|g" "$REAL_WLOGOUT_CSS"
  echo -e "${GREEN}Fixed wlogout icon paths in style.css to use $HOME/.config/wlogout/${NC}"
fi

# --- 9. Wallpapers ---
echo -e "${YELLOW}Setting up wallpapers...${NC}"
WALLPAPERS_DEST="$HOME/Pictures/wallpapers"

if [ -d "$WALLPAPERS_DEST" ]; then
  echo -e "${YELLOW}A wallpapers directory already exists at $WALLPAPERS_DEST.${NC}"
  echo -e "${YELLOW}This setup avoids overwriting your existing wallpapers.${NC}"
  echo ""
  read -p "Would you like to back it up first before adding new wallpapers? (y/n): " backup_choice
  if [[ "$backup_choice" == "y" || "$backup_choice" == "Y" ]]; then
    BACKUP_PATH="${WALLPAPERS_DEST}.bak_$(date +%Y%m%d_%H%M%S)"
    cp -r "$WALLPAPERS_DEST" "$BACKUP_PATH"
    echo -e "${GREEN}Backed up your wallpapers to: $BACKUP_PATH${NC}"
    echo ""
    read -p "Now copy new wallpapers from dotfiles into $WALLPAPERS_DEST? (y/n): " copy_choice
    if [[ "$copy_choice" == "y" || "$copy_choice" == "Y" ]]; then
      mkdir -p "$WALLPAPERS_DEST"
      cp "$DOTFILES_DIR/wallpapers/"* "$WALLPAPERS_DEST/" 2>/dev/null
      echo -e "${GREEN}Copied new wallpapers into $WALLPAPERS_DEST${NC}"
    else
      echo -e "${BLUE}Skipping wallpaper copy. Your existing wallpapers are untouched.${NC}"
    fi
  else
    echo -e "${BLUE}Skipping wallpaper setup. Your existing wallpapers are safe.${NC}"
  fi
else
  mkdir -p "$WALLPAPERS_DEST"
  cp "$DOTFILES_DIR/wallpapers/"* "$WALLPAPERS_DEST/"
  echo -e "${GREEN}Wallpapers installed to $WALLPAPERS_DEST${NC}"
fi

# --- 10. Final Verification ---
echo -e "${YELLOW}Verifying important Hyprland packages...${NC}"
HYPR_PKGS=("hyprland" "hypridle" "hyprlock" "waybar")
for pkg in "${HYPR_PKGS[@]}"; do
  if ! check_package "$pkg"; then
    echo -e "${RED}$pkg is missing! Attempting to install...${NC}"
    sudo pacman -S --noconfirm "$pkg"
  fi
done

# --- 11. Configure Tuned service and passwordless execution ---
echo -e "${YELLOW}Configuring Tuned and passwordless tuned-adm profile switching...${NC}"
# Enable and start tuned service
if systemctl is-active --quiet tuned; then
  echo -e "${GREEN}Tuned service is already running.${NC}"
else
  echo -e "${BLUE}Starting and enabling tuned service...${NC}"
  sudo systemctl enable --now tuned
fi

# Create sudoers rule for passwordless tuned-adm profile switching
TUNED_SUDOERS_FILE="/etc/sudoers.d/99-tuned-adm"
if [ ! -f "$TUNED_SUDOERS_FILE" ]; then
  echo -e "${BLUE}Creating sudoers rule to allow running tuned-adm without a password...${NC}"
  echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/tuned-adm" | sudo tee "$TUNED_SUDOERS_FILE" > /dev/null
  sudo chmod 440 "$TUNED_SUDOERS_FILE"
  echo -e "${GREEN}Sudoers rule created successfully.${NC}"
else
  echo -e "${GREEN}Sudoers rule for tuned-adm already exists.${NC}"
fi

# --- 12. Setting up themes ---
echo -e "${YELLOW}Setting up themes...${NC}"
read -p "Apply adw-gtk3 theme and generate dynamic colors with matugen? (y/n): " setup_themes
if [[ "$setup_themes" == "y" || "$setup_themes" == "Y" ]]; then

  # Flatpak theming
  if command -v flatpak &>/dev/null; then
    echo -e "${YELLOW}Allowing Flatpak apps to access themes, icons, and configurations...${NC}"
    flatpak override --user --filesystem="$HOME"/.themes
    flatpak override --user --filesystem="$HOME"/.icons
    flatpak override --user --filesystem=xdg-config/gtk-4.0:ro
    flatpak override --user --filesystem=xdg-config/gtk-3.0:ro
    echo -e "${GREEN}Flatpak apps can now access themes, icons, and configurations.${NC}"
  fi

  # Set adw-gtk3 theme via gsettings
  echo -e "${BLUE}Applying adw-gtk3-dark theme via gsettings...${NC}"
  gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
  echo -e "${GREEN}adw-gtk3-dark theme applied.${NC}"

  # Run matugen for dynamic coloring
  MATUGEN_WALLPAPER="$HOME/Pictures/wallpapers/building.png"
  if [ -f "$MATUGEN_WALLPAPER" ]; then
    echo -e "${BLUE}Generating dynamic colors with matugen...${NC}"
    matugen -m dark image "$MATUGEN_WALLPAPER" --source-color-index 0
    echo -e "${GREEN}Dynamic colors applied via matugen.${NC}"

    # Re-run GTK symlinks now that .themes is in place and matugen has written colors
    echo -e "${BLUE}Re-linking GTK theme files...${NC}"
    ADW_GTK4="$HOME/.themes/adw-gtk3-dark/gtk-4.0"
    ADW_GTK3="$HOME/.themes/adw-gtk3-dark/gtk-3.0"
    GTK4_CONF="$CONF_DIR/gtk-4.0"
    GTK3_CONF="$CONF_DIR/gtk-3.0"
    mkdir -p "$GTK4_CONF" "$GTK3_CONF"
    if [ -d "$HOME/.themes/adw-gtk3-dark" ]; then
      for gtkfile in gtk.css gtk-dark.css libadwaita.css libadwaita-tweaks.css matugen-override.css colors.css assets; do
        TARGET_LINK="$GTK4_CONF/$gtkfile"
        THEME_SRC="$ADW_GTK4/$gtkfile"
        if [ -e "$THEME_SRC" ]; then
          rm -f "$TARGET_LINK"
          ln -sf "$THEME_SRC" "$TARGET_LINK"
        fi
      done
      if [ -e "$ADW_GTK3/colors.css" ]; then
        rm -f "$GTK3_CONF/colors.css"
        ln -sf "$ADW_GTK3/colors.css" "$GTK3_CONF/colors.css"
      fi
      echo -e "${GREEN}GTK theme symlinks updated.${NC}"
    fi
  else
    sleep 8
    echo -e "${YELLOW}Warning: $MATUGEN_WALLPAPER not found.${NC}"
    echo -e "${YELLOW}You can run matugen manually with: matugen -m dark image <path-to-wallpaper> --source-color-index 0${NC}"
  fi

else
  echo -e "${BLUE}Skipping theme setup.${NC}"
fi

# --- 13. Monitor Configuration ---
echo -e "${YELLOW}Detecting monitor...${NC}"

# Detect connected monitors and their highest resolution and refresh rate
# Uses hyprctl if active, with fallback to DRM sysfs and EDID inspection.
DETECTED_MONITORS=$(python3 - <<'EOF'
import json, os, glob, subprocess, struct, re

def get_monitors_hyprctl():
    try:
        res = subprocess.run(["hyprctl", "monitors", "all", "-j"], capture_output=True, text=True, timeout=2)
        if res.returncode == 0:
            data = json.loads(res.stdout)
            monitors = []
            for m in data:
                name = m.get("name")
                if not name:
                    continue
                modes = m.get("availableModes", [])
                parsed_modes = []
                for mode in modes:
                    match = re.match(r"(\d+)x(\d+)@([\d\.]+)Hz?", mode)
                    if match:
                        w, h, r = int(match.group(1)), int(match.group(2)), float(match.group(3))
                        parsed_modes.append((w, h, r))
                if not parsed_modes and "width" in m and "height" in m:
                    w = int(m["width"])
                    h = int(m["height"])
                    r = float(m.get("refreshRate", 60.0))
                    parsed_modes.append((w, h, r))
                if parsed_modes:
                    parsed_modes.sort(key=lambda x: (x[0]*x[1], x[2]), reverse=True)
                    best = parsed_modes[0]
                    monitors.append((name, best[0], best[1], best[2]))
            return monitors
    except Exception:
        pass
    return []

def parse_edid(edid_bytes):
    if len(edid_bytes) < 128 or edid_bytes[:8] != b"\x00\xff\xff\xff\xff\xff\xff\x00":
        return []
    modes = []
    for offset in (54, 72, 90, 108):
        block = edid_bytes[offset:offset+18]
        if len(block) < 18:
            continue
        pixel_clock = struct.unpack("<H", block[0:2])[0] * 10000
        if pixel_clock == 0:
            continue
        h_active = block[2] | ((block[4] & 0xf0) << 4)
        h_blank = block[3] | ((block[4] & 0x0f) << 8)
        v_active = block[5] | ((block[7] & 0xf0) << 4)
        v_blank = block[6] | ((block[7] & 0x0f) << 8)
        h_total = h_active + h_blank
        v_total = v_active + v_blank
        if h_total > 0 and v_total > 0:
            refresh = pixel_clock / (h_total * v_total)
            modes.append((h_active, v_active, refresh))
    return modes

def get_monitors_drm():
    monitors = []
    for card_conn in sorted(glob.glob("/sys/class/drm/card*-*")):
        status_file = os.path.join(card_conn, "status")
        if os.path.isfile(status_file):
            try:
                with open(status_file, "r") as f:
                    if f.read().strip() != "connected":
                        continue
            except Exception:
                continue
            raw_name = os.path.basename(card_conn)
            conn_name = raw_name.split("-", 1)[1] if "-" in raw_name else raw_name
            modes = []
            edid_file = os.path.join(card_conn, "edid")
            if os.path.isfile(edid_file):
                try:
                    with open(edid_file, "rb") as f:
                        modes = parse_edid(f.read())
                except Exception:
                    pass
            modes_file = os.path.join(card_conn, "modes")
            if not modes and os.path.isfile(modes_file):
                try:
                    with open(modes_file, "r") as f:
                        for line in f:
                            line = line.strip()
                            if "x" in line:
                                parts = line.split("x")
                                modes.append((int(parts[0]), int(parts[1]), 60.00))
                except Exception:
                    pass
            if modes:
                modes.sort(key=lambda x: (x[0]*x[1], x[2]), reverse=True)
                best = modes[0]
                monitors.append((conn_name, best[0], best[1], best[2]))
    return monitors

monitors = get_monitors_hyprctl() or get_monitors_drm()
for name, w, h, hz in monitors:
    print(f"{name}|{w}x{h}|{hz:.2f}")
EOF
)

echo -e "${YELLOW}Fixing monitors...${NC}"
MONITORS_CONF_FILE="$DOTFILES_DIR/config/hypr/conf/monitors.conf"

if [ -n "$DETECTED_MONITORS" ]; then
  echo "# Auto-generated by minimal6 setup wizard" > "$MONITORS_CONF_FILE"
  echo "" >> "$MONITORS_CONF_FILE"
  while IFS='|' read -r mon_name mon_res mon_hz; do
    [ -z "$mon_name" ] && continue
    echo -e "  ${GREEN}Found monitor:${NC} $mon_name ($mon_res @ ${mon_hz}Hz)"
    echo "monitor=$mon_name,${mon_res}@${mon_hz}Hz,auto,1" >> "$MONITORS_CONF_FILE"
  done <<< "$DETECTED_MONITORS"
  echo "" >> "$MONITORS_CONF_FILE"
  echo -e "${GREEN}Updated monitors.conf successfully.${NC}"
else
  echo -e "${YELLOW}No active monitors detected automatically. Using default fallback.${NC}"
  echo "# Fallback monitor configuration" > "$MONITORS_CONF_FILE"
  echo "monitor=,preferred,auto,1" >> "$MONITORS_CONF_FILE"
fi

# If ~/.config/hypr/conf/monitors.conf is a separate copy and not a symlink, sync it as well
if [ -f "$CONF_DIR/hypr/conf/monitors.conf" ] && [ ! -L "$CONF_DIR/hypr/conf/monitors.conf" ]; then
  cp "$MONITORS_CONF_FILE" "$CONF_DIR/hypr/conf/monitors.conf"
fi

# --- 14. Final Message ---
clear
show_header
if command -v gum &>/dev/null; then
  gum style --foreground 82 --border-foreground 82 --border normal --align center --width 50 \
    "Setup Complete!" "Press Super + H for Keybinds Help"
else
  echo -e "${GREEN}Setup Complete!${NC}"
  echo -e "${YELLOW}Press Super + H for Keybinds Help${NC}"
fi
