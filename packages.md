# Packages

A comprehensive list of packages required for the **msc** environment.

### Core System & Compositor
- **swayfx-git(AUR)**: Sway, but with eye candy(compositor).
- **awww**: An Answer to your Wayland Wallpaper Woes (wallpaper manager).
- **swayidle**: Idle management daemon for Wayland.
- **hyprlock**: hyprland’s GPU-accelerated screen locking utility, but works on other wayland window managers
- **gammastep**: blue light filter.
- **xdg-desktop-portal-wlr**: xdg-desktop-portal backend for wlroots.
- **xdg-desktop-portal-gtk**: GTK backend for xdg-desktop-portal (file pickers).
- **autotiling**: used for dynamic tiling like master layout in Hyprland

### Interface & Shell
- **waybar**: Highly customizable Wayland bar.
- **swaync**: Notification center and control center for Wayland.
- **wofi**: A launcher/menu program for Wayland.
- **wlogout (AUR)**: A logout menu for Wayland.
- **wofi-emoji (AUR)**: Emoji picker using wofi.
- **gsimplecal**: Simple calendar for Wayland (calendar popup for Waybar).
- **nwg-look**: GTK3 settings editor (GNOME customization tool).
- **fzf**: Command-line fuzzy finder, used in help and settings scripts.
- **gum**: Tool for glamorous shell scripts (used in setup/update wizard).

### Utilities & Tools
- **grim**: Screenshot utility for Wayland.
- **slurp**: Select a region in a Wayland compositor (used with grim).
- **wl-clipboard**: Wayland command-line copy/paste utilities.
- **cliphist**: Wayland clipboard history manager.
- **hyprpicker**: Wayland color picker (bound to Super+Ctrl+P).
- **imagemagick**: Image toolkit (the wallpaper picker uses `magick` for thumbnails).
- **brightnessctl**: Lightweight tool to read and control device brightness.
- **pavucontrol**: PulseAudio Volume Control (GUI).
- **polkit-gnome**: GNOME authentication agent for Polkit.
- **gvfs**: Virtual filesystem implementation for GIO (file mounting).
- **tuned**: Daemon that performs monitoring and adaptive configuration of devices.
- **jq**: Lightweight and flexible command-line JSON processor (used in scripts).
- **xdg-utils**: Command line tools for desktop integration (xdg-open, xdg-settings).
- **git**: Distributed revision control system (required for Neovim plugins).
- **libnotify**: Library for sending desktop notifications (provides `notify-send`).
- **psmisc**: Utilities that use the proc filesystem (provides `killall`).
- **procps-ng**: Utilities for browsing procfs (provides `pgrep`, `pkill`).
- **iproute2**: Networking and traffic control engine (provides `ip`).
- **xorg-xhost**: X host access control (for root GUI apps).
- **wooz-git (AUR)**: Zoom / magnifier utility for Wayland.
- **gamemode**: Daemon/lib for optimizing gaming performance.

### Audio & Bluetooth
- **pipewire**: Low-latency audio/video router and processor.
- **wireplumber**: Session manager for PipeWire.
- **playerctl**: MPRIS media-key controller (play/pause/next/prev).
- **blueman**: GTK+ Bluetooth Manager.
- **bluez**: Official Linux Bluetooth protocol stack.
- **bluez-utils**: Development and debugging utilities for the bluetooth stack.

### Applications
- **ghostty**: A fast, feature-rich GPU-accelerated terminal emulator.
- **kitty**: Fast, feature-rich, GPU based terminal emulator.
- **alacritty**: A cross-platform, GPU-accelerated terminal emulator.
- **brave (AUR)**: Privacy-focused web browser.
- **dolphin**: KDE's file manager.
- **yazi**: Blazing fast terminal file manager written in Rust.
- **btop**: A monitor of system resources (CPU, Memory, etc.).

### Theming & Fonts
- **ttf-jetbrains-mono-nerd**: JetBrains Mono Nerd Font, used in Waybar and terminal.
- **noto-fonts**: Google Noto TTF fonts.
- **papirus-icon-theme**: Papirus icon theme for GTK/Qt applications.
- **qt5-wayland**: Wayland platform plugin for Qt5.
- **qt5ct**: Qt5 Configuration Tool.
- **qt6ct**: Qt6 Configuration Tool.
- **gtk-engine-murrine (AUR)**: Murrine GTK2 engine (required for many GTK themes).
- **bibata-cursor-theme (AUR)**: Popular material-based cursor theme.
- **papirus-folders (AUR)**: Tool to recolor Papirus folders with Material You colors.

### Editors
- **neovim**: Hyperextensible Vim-based text editor (used for config editing).

### Qt Styling
- **kvantum**: SVG-based theme engine for Qt (provides `kvantummanager`).

### Networking
- **networkmanager**: Network management daemon (provides `nmcli`, `nmtui`).
- **network-manager-applet**: NetworkManager system tray applet.