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

# --- 1. Package Lists ---
PACMAN_PKGS=(
  "swayidle" "gammastep"
  "xdg-desktop-portal-wlr" "xdg-desktop-portal-gtk" "waybar" "swaync" "wofi"
  "fzf" "gum" "figlet" "grim" "slurp" "wl-clipboard" "cliphist"
  "brightnessctl" "pavucontrol" "polkit-gnome" "gvfs" "tuned" "jq"
  "xdg-utils" "git" "libnotify" "psmisc" "procps-ng" "iproute2"
  "pipewire" "wireplumber" "blueman" "bluez" "bluez-utils"
  "kitty" "alacritty" "dolphin" "yazi" "btop"
  "ttf-jetbrains-mono-nerd" "noto-fonts" "papirus-icon-theme" "qt5-wayland" "qt5ct" "qt6ct"
  "networkmanager" "network-manager-applet" "base-devel" "xorg-xhost" "quickshell"
  "neovim" "kvantum" "ghostty" "awww"
  "python3" "python-pyfiglet" "matugen" "autotiling"
  "gsimplecal" "gamemode" "hyprlock" "hyprpicker" "playerctl" "imagemagick" "gnome-keyring"
)

AUR_PKGS=(
  "swayfx-git"
  "wlogout" "wofi-emoji" "brave-bin" "nm-connection-editor"
  "bibata-cursor-theme" "papirus-folders" "wooz-git"
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
# We need base-devel and git first
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
  echo -e "${YELLOW}minimal6 installs only the required packages but a login manager is recommended for a seamless experience.${NC}"
  sleep 2
fi

# --- 3. Terms and Conditions ---
echo -e "\v"
echo -e "Wait! i almost forgot, i have realised you haven't read the terms and conditions 😂 "
sleep 5
clear
echo -e "\v\v\t\t${NC}Terms and conditions${NC} "
echo -e "\tAs a condition of using Minimal6 dotfiles you agree to: "
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
DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONF_DIR="$HOME/.config"
mkdir -p "$HOME/.local/bin"

# Detect whether a target already belongs to the minimal6 dotfiles repo
# (i.e. resolves inside $DOTFILES_DIR or points to old msc path).
# Only dotfiles-managed links get replaced without backing up.
is_dotfiles_dir() {
  local dir=$1
  local resolved
  resolved=$(readlink -f "$dir" 2>/dev/null)
  local raw
  raw=$(readlink "$dir" 2>/dev/null)
  [[ "$resolved" == "$DOTFILES_DIR"* || "$raw" == *"/msc/"* || "$raw" == *"/minimal6/"* ]]
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

confirm_and_copy() {
  local source=$1
  local target=$2
  local name=$3

  if [[ -e "$target" || -L "$target" ]]; then
    echo -e "${YELLOW}An existing file/directory for $name was found.${NC}"
    read -p "Do you want to replace it? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
      echo "Backing up existing $name..."
      mv "$target" "${target}.bak_$(date +%Y%m%d_%H%M%S)"
      cp -r "$source" "$target"
      echo -e "${GREEN}Copied $name${NC}"
    else
      echo "Skipping $name"
    fi
  else
    cp -r "$source" "$target"
    echo -e "${GREEN}Copied $name${NC}"
  fi
}

# Link config directories
for dir in "$DOTFILES_DIR/config"/*; do
  dir_name=$(basename "$dir")
  confirm_and_link "$dir" "$CONF_DIR/$dir_name" "$dir_name"
done

# Clean up stale *.bak_* symlinks that were produced by previous buggy runs.
# These are useless: they are just symlinks back into a minimal6 repo, not
# real backups. Remove them so they stop accumulating.
echo -e "${YELLOW}Removing stale dotfiles backup symlinks...${NC}"
for bak in "$CONF_DIR"/*.bak_* "$HOME"/.themes.bak_*; do
  [ -L "$bak" ] || continue
  if is_dotfiles_link "$bak"; then
    rm -f "$bak"
    echo -e "  ${BLUE}Removed $bak${NC}"
  fi
done

# Clean up legacy .icons symlink if it points to dotfiles or is broken
if [ -L "$HOME/.icons" ]; then
  if [ ! -e "$HOME/.icons" ] || is_dotfiles_link "$HOME/.icons"; then
    echo -e "${YELLOW}Removing stale/broken .icons symlink...${NC}"
    rm -f "$HOME/.icons"
  fi
fi
mkdir -p "$HOME/.icons"

# Handle special files/dirs
confirm_and_link "$DOTFILES_DIR/.themes" "$HOME/.themes" ".themes"

# .bashrc does not work with symlinks: copy instead
confirm_and_copy "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc" ".bashrc"

# Kvantum themes
if command -v kvantummanager &>/dev/null; then
  confirm_and_link "$DOTFILES_DIR/kvantum-themes" "$HOME/.config/Kvantum" "kvantum-themes"
fi

# --- 7. Resolve Hardcoded Paths ---
# Fix hardcoded paths for the current user in configs
echo -e "${YELLOW}Resolving hardcoded paths for your system...${NC}"

sed_inplace() {
  sed -i "$1" "$2"
}

# -- gtk-3.0/bookmarks --
BOOKMARKS="$CONF_DIR/gtk-3.0/bookmarks"
if [ -f "$BOOKMARKS" ] || [ -L "$BOOKMARKS" ]; then
  REAL_BOOKMARKS=$(realpath "$BOOKMARKS" 2>/dev/null || echo "$BOOKMARKS")
  sed_inplace "s|__HOME__|$HOME|g" "$REAL_BOOKMARKS"
  sed_inplace "s|/home/[a-zA-Z0-9_-]*|$HOME|g" "$REAL_BOOKMARKS"
  echo -e "${GREEN}Fixed paths in gtk-3.0/bookmarks${NC}"
fi

# -- quickshell/shell.qml --
SHELL_QML="$CONF_DIR/quickshell/shell.qml"
if [ -f "$SHELL_QML" ] || [ -L "$SHELL_QML" ]; then
  REAL_SHELL=$(realpath "$SHELL_QML" 2>/dev/null || echo "$SHELL_QML")
  sed_inplace "s|__HOME__|$HOME|g" "$REAL_SHELL"
  sed_inplace "s|/home/[a-zA-Z0-9_-]*/.config/quickshell|$HOME/.config/quickshell|g" "$REAL_SHELL"
  echo -e "${GREEN}Fixed paths in quickshell/shell.qml${NC}"
fi



# -- sway/palette.conf --
SWAY_PALETTE="$CONF_DIR/sway/palette.conf"
if [ -f "$SWAY_PALETTE" ] || [ -L "$SWAY_PALETTE" ]; then
  REAL_PALETTE=$(realpath "$SWAY_PALETTE" 2>/dev/null || echo "$SWAY_PALETTE")
  sed_inplace "s|/home/[a-zA-Z0-9_-]*/Pictures/wallpapers|$HOME/Pictures/wallpapers|g" "$REAL_PALETTE"
  echo -e "${GREEN}Fixed \$image path in sway/palette.conf${NC}"
fi

# -- wofi/style.css --
WOI_CSS="$CONF_DIR/wofi/style.css"
ABS_PATH="$HOME/.config/wofi/colors.css"
if [ -f "$WOI_CSS" ] || [ -L "$WOI_CSS" ]; then
  REAL_WOI=$(realpath "$WOI_CSS" 2>/dev/null || echo "$WOI_CSS")
  sed_inplace "s|/home/[a-zA-Z0-9_-]*/.config/wofi/colors.css|$ABS_PATH|g" "$REAL_WOI"
  echo -e "${GREEN}Fixed @import path in wofi/style.css to $ABS_PATH${NC}"
fi

# -- GTK symlinks: Recreate gtk-4.0 and gtk-3.0 symlinks --
echo -e "${YELLOW}Recreating GTK theme symlinks...${NC}"
ADW_GTK4="$HOME/.themes/adw-gtk3-dark/gtk-4.0"
ADW_GTK3="$HOME/.themes/adw-gtk3-dark/gtk-3.0"
GTK4_CONF="$CONF_DIR/gtk-4.0"
GTK3_CONF="$CONF_DIR/gtk-3.0"

if [ -d "$HOME/.themes/adw-gtk3-dark" ]; then
  # Symlink ~/.themes/adw-gtk3-dark/gtk-4.0 to ~/.config/gtk-4.0
  rm -rf "$GTK4_CONF"
  ln -sf "$ADW_GTK4" "$GTK4_CONF"
  echo -e "  ${GREEN}Linked gtk-4.0 directory${NC}"

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

# --- 8. Wallpapers ---
echo -e "${YELLOW}Setting up wallpapers...${NC}"
WALLPAPERS_DEST="$HOME/Pictures/wallpapers"

if [ -d "$WALLPAPERS_DEST" ]; then
  echo -e "${YELLOW}A wallpapers directory already exists at $WALLPAPERS_DEST.${NC}"
  echo -e "${YELLOW}This setup will NOT overwriting your existing wallpapers .${NC}"
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
  cp "$DOTFILES_DIR/wallpapers/"* "$WALLPAPERS_DEST/" 2>/dev/null
  echo -e "${GREEN}Wallpapers installed to $WALLPAPERS_DEST${NC}"
fi

# Light-mode wallpapers: curated set shown when light mode is toggled on.
LIGHT_WALL_DEST="$WALLPAPERS_DEST/light-mode"
if [ -d "$DOTFILES_DIR/wallpapers/light-mode" ]; then
  mkdir -p "$LIGHT_WALL_DEST"
  # Copy the curated set in (never clobber files the user already added).
  cp -n "$DOTFILES_DIR/wallpapers/light-mode/"* "$LIGHT_WALL_DEST/" 2>/dev/null
  echo -e "${GREEN}Light-mode wallpapers installed to $LIGHT_WALL_DEST${NC}"
fi

# --- 9. Final Verification ---
echo -e "${YELLOW}Verifying important Sway packages...${NC}"
SWAY_PKGS=("swayfx-git" "swayidle" "waybar")
for pkg in "${SWAY_PKGS[@]}"; do
  if ! check_package "$pkg" && ! yay -Qi "$pkg" &>/dev/null; then
    echo -e "${RED}$pkg is missing! Attempting to install...${NC}"
    if [[ "$pkg" == "swayfx-git" ]]; then
      yay -S --noconfirm "$pkg"
    else
      sudo pacman -S --noconfirm "$pkg"
    fi
  fi
done

# --- 10. Setting up themes ---
echo -e "${YELLOW}Setting up themes...${NC}"
read -p "Apply adw-gtk3 theme and generate dynamic colors with matugen? (y/n): " setup_themes
if [[ "$setup_themes" == "y" || "$setup_themes" == "Y" ]]; then

  # Flatpak theming: the 3 grants + per-app GTK4 wiring for libadwaita apps.
  # Single source of truth: flatpak-theming.sh (also usable standalone,
  # see --help / theme-fix.md). Safe to re-run any time.
  if command -v flatpak &>/dev/null && [ -f "$DOTFILES_DIR/flatpak-theming.sh" ]; then
    echo -e "${YELLOW}Theming flatpak apps (grants + per-app wiring)...${NC}"
    bash "$DOTFILES_DIR/flatpak-theming.sh"
  fi

  # Set adw-gtk3 theme and icons via gsettings
  echo -e "${BLUE}Applying adw-gtk3-dark theme and FairyWren_adwaita_Dark icons via gsettings...${NC}"
  gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
  gsettings set org.gnome.desktop.interface icon-theme "FairyWren_adwaita_Dark"
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
  echo -e "${GREEN}adw-gtk3-dark theme and FairyWren_adwaita_Dark icons applied.${NC}"

  # Apply the initial wallpaper and generate dynamic colors using the same
  # awww -> matugen flow used by the wallpaper switcher. The matugen Sway
  # reload hook is guarded in config/matugen/config.toml.
  MATUGEN_WALLPAPER="$HOME/Pictures/wallpapers/building.png"
  if [ -f "$MATUGEN_WALLPAPER" ]; then
    APPLY_WALLPAPER="$DOTFILES_DIR/config/sway/scripts/apply-wallpaper.sh"
    mkdir -p "$HOME/.cache"

    if [[ "${XDG_CURRENT_DESKTOP,,}" == *sway* || "${DESKTOP_SESSION,,}" == *sway* ]] &&
      [ -n "${SWAYSOCK:-}" ] && command -v swaymsg &>/dev/null && swaymsg -t get_version &>/dev/null; then
      echo -e "${BLUE}Active Sway session detected; applying wallpaper and reloading after generation.${NC}"
    else
      echo -e "${YELLOW}SwayFX is not active; applying colors now, but awww may not be able to set the wallpaper.${NC}"
    fi

    if bash "$APPLY_WALLPAPER" "$MATUGEN_WALLPAPER"; then
      if [[ "${XDG_CURRENT_DESKTOP,,}" == *sway* || "${DESKTOP_SESSION,,}" == *sway* ]] &&
        [ -n "${SWAYSOCK:-}" ] && command -v swaymsg &>/dev/null && swaymsg -t get_version &>/dev/null; then
        echo -e "${GREEN}Initial wallpaper and dynamic colors applied.${NC}"
      else
        echo -e "${GREEN}Dynamic colors generated.${NC}"
        echo -e "${YELLOW}After logging into SwayFX, press Super + Ctrl + W to apply the wallpaper.${NC}"
      fi
    else
      echo -e "${RED}Failed to apply the initial wallpaper and dynamic colors.${NC}"
    fi

    # Re-run GTK symlinks now that .themes is in place and matugen has written colors
    echo -e "${BLUE}Re-linking GTK theme files...${NC}"
    ADW_GTK4="$HOME/.themes/adw-gtk3-dark/gtk-4.0"
    ADW_GTK3="$HOME/.themes/adw-gtk3-dark/gtk-3.0"
    GTK4_CONF="$CONF_DIR/gtk-4.0"
    GTK3_CONF="$CONF_DIR/gtk-3.0"
    mkdir -p "$GTK4_CONF" "$GTK3_CONF"
    if [ -d "$HOME/.themes/adw-gtk3-dark" ]; then
      rm -rf "$GTK4_CONF"
      ln -sf "$ADW_GTK4" "$GTK4_CONF"
      if [ -e "$ADW_GTK3/colors.css" ]; then
        rm -f "$GTK3_CONF/colors.css"
        ln -sf "$ADW_GTK3/colors.css" "$GTK3_CONF/colors.css"
      fi
      echo -e "${GREEN}GTK theme symlinks updated.${NC}"

      # Flatpak GTK4 wiring (per-app symlinks for libadwaita apps) is handled
      # by flatpak-theming.sh, which already ran earlier in this section.
    fi
  else
    echo -e "${YELLOW}Warning: $MATUGEN_WALLPAPER not found.${NC}"
    echo -e "${YELLOW}You can run matugen manually with: matugen -m dark image <path-to-wallpaper> --source-color-index 0${NC}"
    sleep 8
  fi

  # Make Dolphin follow the system/GTK color scheme dynamically so its text
  # stays visible when the light/dark mode toggles. '*' = follow system theme.
  if command -v kwriteconfig6 &>/dev/null; then
    kwriteconfig6 --file dolphinrc --group UiSettings --key ColorScheme '*'
    echo -e "${GREEN}Dolphin set to follow system color scheme (ColorScheme='*').${NC}"
  fi

else
  echo -e "${BLUE}Skipping theme setup.${NC}"
fi

# --- 11. Icon Theme Setup (FairyWren) ---
echo -e "${YELLOW}Setting up icon theme...${NC}"

# Ensure ~/.icons exists and is not a dangling symlink
if [ -L "$HOME/.icons" ] && { [ ! -e "$HOME/.icons" ] || is_dotfiles_link "$HOME/.icons"; }; then
  echo -e "${YELLOW}Removing stale/broken .icons symlink...${NC}"
  rm -f "$HOME/.icons"
fi
mkdir -p "$HOME/.icons"

# Check if any fairyw* icon theme directory is already available in ~/.icons/
found_icon=""
shopt -s nullglob nocaseglob
for entry in "$HOME/.icons"/fairyw*; do
  if [ -d "$entry" ]; then
    found_icon="$(basename "$entry")"
    break
  fi
done
shopt -u nullglob nocaseglob

if [ -n "$found_icon" ]; then
  echo -e "${GREEN}Icon theme ($found_icon) is already available at ~/.icons/${NC}"
else
  TMP_ICON_TAR="/tmp/icons.tar.xz"
  LOCAL_ASSET="$DOTFILES_DIR/assets/icons.tar.xz"
  RELEASE_URL="https://github.com/fallenwesii/minimal6/releases/latest/download/icons.tar.xz"

  DOWNLOAD_SUCCESS=false
  if [ -f "$LOCAL_ASSET" ]; then
    echo -e "${BLUE}Extracting icons from local asset...${NC}"
    cp "$LOCAL_ASSET" "$TMP_ICON_TAR"
    DOWNLOAD_SUCCESS=true
  else
    echo -e "${YELLOW}Downloading icons (attempting up to 3 times)...${NC}"
    for attempt in 1 2 3; do
      echo -e "${BLUE}Attempt $attempt/3: Downloading icon theme...${NC}"
      rm -f "$TMP_ICON_TAR"
      if curl -fL --connect-timeout 15 --max-time 180 "$RELEASE_URL" -o "$TMP_ICON_TAR" && [ -s "$TMP_ICON_TAR" ]; then
        if tar -tf "$TMP_ICON_TAR" &>/dev/null; then
          DOWNLOAD_SUCCESS=true
          break
        fi
      fi
      if [ "$attempt" -lt 3 ]; then
        echo -e "${YELLOW}Attempt $attempt failed. Retrying in 2 seconds...${NC}"
        sleep 2
      fi
    done
  fi

  if [ "$DOWNLOAD_SUCCESS" = true ] && [ -f "$TMP_ICON_TAR" ]; then
    echo -e "${YELLOW}Setting up icons...${NC}"
    if tar -xf "$TMP_ICON_TAR" -C "$HOME/.icons/"; then
      rm -f "$TMP_ICON_TAR"
      echo -e "${GREEN}Icons set up successfully!${NC}"
    else
      echo -e "${RED}Failed to extract icons archive.${NC}"
      rm -f "$TMP_ICON_TAR"
    fi
  else
    echo -e "${RED}Failed to download icon theme after 3 attempts due to network issues.${NC}"
    echo -e "${YELLOW}You can manually download and extract the icon theme using this command:${NC}"
    echo -e "${GREEN}mkdir -p ~/.icons && curl -fSL https://github.com/fallenwesii/minimal6/releases/latest/download/icons.tar.xz | tar -xJ -C ~/.icons/${NC}"
  fi
fi

# --- 12. Papirus Folders Theming ---
echo -e "${YELLOW}Theming papirus folders...${NC}"
# Set Papirus as icon theme for KDE/Qt applications
kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus
echo -e "${GREEN}Set Papirus icon theme via kdeglobals.${NC}"

# Configure passwordless sudo for papirus-folders (for dynamic folder recoloring via matugen)
PAPIRUS_SUDOERS_FILE="/etc/sudoers.d/papirus-folders"
if [ ! -f "$PAPIRUS_SUDOERS_FILE" ]; then
  echo -e "${BLUE}Creating sudoers rule for passwordless papirus-folders...${NC}"
  echo "$USER ALL=(ALL) NOPASSWD: $(which papirus-folders)" | sudo tee "$PAPIRUS_SUDOERS_FILE" > /dev/null
  sudo chmod 440 "$PAPIRUS_SUDOERS_FILE"
  echo -e "${GREEN}Sudoers rule for papirus-folders created.${NC}"
else
  echo -e "${GREEN}Sudoers rule for papirus-folders already exists.${NC}"
fi

# --- 13. Tuned Service and Passwordless tuned-adm ---
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

# --- 14. QT/Kvantum Environment configuration ---
echo -e "${YELLOW}Setting up QT/Kvantum environment...${NC}"
systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal
echo -e "${GREEN}QT/Kvantum environment configured (via 90-minimal6.conf) and systemd user manager reloaded.\nA reboot is recommended for Qt/Kvantum theming${NC}"

# --- 15. Final Message ---
if command -v gum &>/dev/null; then
  gum style --foreground 82 --border-foreground 82 --border normal --align center --width 50 \
    "Setup Complete!" "Press Super + H for Keybinds Help"
else
  echo -e "${GREEN}Setup Complete!${NC}"
  echo -e "${YELLOW}Press Super + H for Keybinds Help${NC}"
fi
