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
      --foreground 196 --border-foreground 196 --border double \
      --align center --width 50 --margin "1 2" --padding "2 4" \
      "minimal6 dotfiles" "Uninstall Wizard"
  else
    echo -e "${RED}"
    echo "=================================================="
    echo "          MINIMAL6 DOTFILES UNINSTALLER           "
    echo "=================================================="
    echo -e "${NC}"
  fi
}

show_header

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONF_DIR="$HOME/.config"

echo -e "${YELLOW}This script will remove symlinks, wallpapers, and scripts installed by minimal6.${NC}"
echo -e "${YELLOW}It will NOT uninstall any packages/applications.${NC}"
echo ""
read -p "Are you sure you want to proceed? (y/n): " proceed
if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
  echo -e "${BLUE}Uninstall cancelled.${NC}"
  exit 0
fi

# --- Helper function to undo symlinks and restore backups ---
undo_link() {
  local target=$1
  local name=$2

  if [[ -L "$target" ]]; then
    # Read where the link points to
    local link_target=$(readlink "$target")
    # Resolve absolute path of link_target
    local abs_link_target=$(realpath -m "$link_target")
    local abs_dotfiles_dir=$(realpath -m "$DOTFILES_DIR")

    # Only remove if it points inside our dotfiles directory
    if [[ "$abs_link_target" == "$abs_dotfiles_dir"* ]]; then
      echo -e "Removing symlink: ${BLUE}$target${NC} (points to $link_target)"
      rm "$target"
      echo -e "${GREEN}Removed symlink for $name.${NC}"

      # Look for backups
      # backups are created as target.bak_YYYYMMDD_HHMMSS
      local backups
      mapfile -t backups < <(find "$(dirname "$target")" -maxdepth 1 -name "$(basename "$target").bak_*" 2>/dev/null | sort -V)
      if [ ${#backups[@]} -gt 0 ]; then
        local latest_backup="${backups[-1]}"
        echo -e "${YELLOW}Found backup: $(basename "$latest_backup"). Restoring...${NC}"
        mv "$latest_backup" "$target"
        echo -e "${GREEN}Restored $name from backup.${NC}"
      fi
    else
      echo -e "${YELLOW}Skipping $target: Symlink does not point to minimal6 dotfiles directory ($link_target).${NC}"
    fi
  elif [[ -e "$target" ]]; then
    echo -e "${YELLOW}Skipping $target: It exists but is not a symbolic link.${NC}"
  else
    echo -e "${BLUE}No symlink or file found for $name at $target.${NC}"
  fi
}

# --- 1. Undo config symlinks ---
echo -e "\n${YELLOW}Undoing configuration symlinks...${NC}"
for dir in "$DOTFILES_DIR/config"/*; do
  dir_name=$(basename "$dir")
  undo_link "$CONF_DIR/$dir_name" "$dir_name"
done

# --- 2. Undo special file symlinks ---
undo_link "$HOME/.themes" ".themes"
undo_link "$HOME/.icons" ".icons"
undo_link "$HOME/.bashrc" ".bashrc"

# Kvantum themes
undo_link "$CONF_DIR/Kvantum" "kvantum-themes"

# --- 3. Remove installed scripts ---
echo -e "\n${YELLOW}Removing scripts...${NC}"
NET_SPEED_SCRIPT="$HOME/.local/bin/net-speed.sh"
if [[ -f "$NET_SPEED_SCRIPT" ]]; then
  echo -e "Removing $NET_SPEED_SCRIPT"
  rm "$NET_SPEED_SCRIPT"
  echo -e "${GREEN}Removed net-speed.sh${NC}"
else
  echo -e "${BLUE}net-speed.sh not found at $NET_SPEED_SCRIPT${NC}"
fi

# --- 4. Remove wallpapers ---
echo -e "\n${YELLOW}Removing wallpapers...${NC}"
WALLPAPERS_DIR="$HOME/Pictures/wallpapers"
if [[ -d "$WALLPAPERS_DIR" ]]; then
  read -p "Do you want to delete the wallpapers directory ($WALLPAPERS_DIR)? (y/n): " rm_wallpapers
  if [[ "$rm_wallpapers" == "y" || "$rm_wallpapers" == "Y" ]]; then
    rm -rf "$WALLPAPERS_DIR"
    echo -e "${GREEN}Removed wallpapers directory.${NC}"
  else
    echo -e "${BLUE}Skipped removing wallpapers.${NC}"
  fi
else
  echo -e "${BLUE}Wallpapers directory not found at $WALLPAPERS_DIR${NC}"
fi

# --- 5. Clean up Flatpak overrides ---
if command -v flatpak &>/dev/null; then
  echo -e "\n${YELLOW}Cleaning up Flatpak theme overrides...${NC}"
  flatpak override --user --nofilesystem="$HOME/.themes" 2>/dev/null
  flatpak override --user --nofilesystem="$HOME/.icons" 2>/dev/null
  flatpak override --user --unset-env=GTK_THEME 2>/dev/null
  echo -e "${GREEN}Flatpak overrides removed.${NC}"
fi

# --- 6. Final Message ---
echo -e "\n${GREEN}Uninstall Complete!${NC}"
