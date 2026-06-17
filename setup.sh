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

# --- Package Lists---
PACMAN_PKGS=(
  "hyprland" "hypridle" "hyprlock" "hyprsunset" "gammastep"
  "xdg-desktop-portal-hyprland" "waybar" "dunst" "wofi" "nwg-look"
  "fzf" "gum" "figlet" "grim" "slurp" "wl-clipboard" "cliphist"
  "brightnessctl" "pavucontrol" "polkit-gnome" "gvfs" "tuned" "jq"
  "xdg-utils" "git" "libnotify" "psmisc" "procps-ng" "iproute2"
  "pipewire" "wireplumber" "blueman" "bluez" "bluez-utils"
  "kitty" "alacritty" "nautilus" "yazi" "btop"
  "ttf-jetbrains-mono-nerd" "noto-fonts" "qt5-wayland" "qt5ct" "qt6ct"
  "networkmanager" "base-devel" "xorg-xhost" "quickshell"
  "neovim" "kvantum" "ghostty" "awww"
)

AUR_PKGS=(
  "wlogout" "wofi-emoji" "brave-bin" "nm-connection-editor"
  "python-pywal" "bibata-cursor-theme")

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

confirm_and_link() {
  local source=$1
  local target=$2
  local name=$3

  if [[ -e "$target" ]]; then
    echo -e "${YELLOW}An existing configuration for $name was found.${NC}"
    read -p "Do you want to replace it? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
      echo "Backing up existing $name..."
      mv "$target" "${target}.bak_$(date +%Y%m%d_%H%M%S)"
      ln -sf "$source" "$target"
      echo -e "${GREEN}Linked $name${NC}"
    else
      echo "Skipping $name"
    fi
  else
    ln -sf "$source" "$target"
    echo -e "${GREEN}Linked $name${NC}"
  fi
}

# Link config directories
for dir in "$DOTFILES_DIR/config"/*; do
  dir_name=$(basename "$dir")
  confirm_and_link "$dir" "$CONF_DIR/$dir_name" "$dir_name"
done

# Handle special files/dirs
confirm_and_link "$DOTFILES_DIR/.themes" "$HOME/.themes" ".themes"
confirm_and_link "$DOTFILES_DIR/.icons" "$HOME/.icons" ".icons"
confirm_and_link "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc" ".bashrc"

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

# Wallpapers
mkdir -p "$HOME/Pictures"
cp -r "$DOTFILES_DIR/wallpapers" "$HOME/Pictures"

# --- 8. Theming consistency for Flatpak ---
if command -v flatpak &>/dev/null; then
  echo -e "${YELLOW}Setting up Flatpak theme consistency...${NC}"
  flatpak override --user --filesystem=$"HOME"/.themes
  echo -e "${GREEN}Flatpak apps can now access ~/.themes${NC}"
fi

# --- 9. Final Verification ---
echo -e "${YELLOW}Verifying important Hyprland packages...${NC}"
HYPR_PKGS=("hyprland" "hypridle" "hyprlock" "waybar")
for pkg in "${HYPR_PKGS[@]}"; do
  if ! check_package "$pkg"; then
    echo -e "${RED}$pkg is missing! Attempting to install...${NC}"
    sudo pacman -S --noconfirm "$pkg"
  fi
done

# --- 10. Setting up themes ---
echo -e "${YELLOW}Setting up themes...${NC}"
read -p "Generate theme configs and apply Gruvbox theme? (y/n): " setup_themes
if [[ "$setup_themes" == "y" || "$setup_themes" == "Y" ]]; then
  THEME_SWITCHER="$DOTFILES_DIR/config/theme-switcher"
  if [ -f "$THEME_SWITCHER/generate_themes.sh" ]; then
    echo -e "${BLUE}Generating theme configurations...${NC}"
    bash "$THEME_SWITCHER/generate_themes.sh"
  fi

  if [ -f "$THEME_SWITCHER/theme-switcher.sh" ]; then
    echo -e "${BLUE}Applying Gruvbox theme...${NC}"
    bash "$THEME_SWITCHER/theme-switcher.sh" "Gruvbox-Dark-Soft"
  fi
else
  echo -e "${BLUE}Skipping theme setup.${NC}"
fi

# Flatpak theming
if command -v flatpak &>/dev/null; then
  echo -e "${YELLOW}Allowing Flatpak apps to access themes...${NC}"
  flatpak override --user --filesystem="$HOME"/.themes
  flatpak override --user --filesystem="$HOME"/.icons
  flatpak override --user --env=GTK_THEME=Gruvbox-Dark-Soft
  echo -e "${GREEN}Flatpak apps can now access themes and icons.${NC}"
fi

# --- 11. Final Message ---
clear
show_header
if command -v gum &>/dev/null; then
  gum style --foreground 82 --border-foreground 82 --border normal --align center --width 50 \
    "Setup Complete!" "Press Super + H for Keybinds Help"
else
  echo -e "${GREEN}Setup Complete!${NC}"
  echo -e "${YELLOW}Press Super + H for Keybinds Help${NC}"
fi
