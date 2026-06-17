# Packages

A comprehensive list of packages required for the **minimal6** environment.

### Core System & Compositor
- **hyprland**: A highly customizable dynamic tiling Wayland compositor.
- **awww**: An Answer to your Wayland Wallpaper Woes (wallpaper manager).
- **hypridle**: Hyprland's idle management daemon (handles sleep/suspend).
- **hyprlock**: Hyprland's GPU-accelerated screen locking utility.
- **hyprsunset**: Wayland blue light filter (color temperature adjustment).
- **gammastep**: Alternative blue light filter (fallback for hyprsunset).
- **xdg-desktop-portal-hyprland**: Backend implementation for xdg-desktop-portal on Hyprland.

### Interface & Shell
- **waybar**: Highly customizable Wayland bar for Hyprland.
- **dunst**: Lightweight replacement for the notification-daemons.
- **wofi**: A launcher/menu program for Wayland.
- **wlogout (AUR)**: A logout menu for Wayland.
- **wofi-emoji (AUR)**: Emoji picker using wofi.
- **nwg-look**: GTK3 settings editor (GNOME customization tool).
- **fzf**: Command-line fuzzy finder, used in help and settings scripts.
- **gum**: A tool for glamorous shell scripts (used for UI elements).
- **figlet**: A program for making large letters out of ordinary text (used in banners).

### Utilities & Tools
- **grim**: Screenshot utility for Wayland.
- **slurp**: Select a region in a Wayland compositor (used with grim).
- **wl-clipboard**: Wayland command-line copy/paste utilities.
- **cliphist**: Wayland clipboard history manager.
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

### Audio & Bluetooth
- **pipewire**: Low-latency audio/video router and processor.
- **wireplumber**: Session manager for PipeWire.
- **blueman**: GTK+ Bluetooth Manager.
- **bluez**: Official Linux Bluetooth protocol stack.
- **bluez-utils**: Development and debugging utilities for the bluetooth stack.

### Applications
- **ghostty**: A fast, feature-rich GPU-accelerated terminal emulator.
- **kitty**: Fast, feature-rich, GPU based terminal emulator.
- **alacritty**: A cross-platform, GPU-accelerated terminal emulator.
- **brave (AUR)**: Privacy-focused web browser.
- **nautilus**: GNOME's file manager.
- **yazi**: Blazing fast terminal file manager written in Rust.
- **btop**: A monitor of system resources (CPU, Memory, etc.).

### Theming & Fonts
- **ttf-jetbrains-mono-nerd**: JetBrains Mono Nerd Font, used in Waybar and terminal.
- **noto-fonts**: Google Noto TTF fonts.
- **qt5-wayland**: Wayland platform plugin for Qt5.
- **qt5ct**: Qt5 Configuration Tool.
- **qt6ct**: Qt6 Configuration Tool.
- **python-pywall (AUR)**: Generate colorschemes from images.
- **gtk-engine-murrine (AUR)**: Murrine GTK2 engine (required for many GTK themes).
- **bibata-cursor-theme (AUR)**: Popular material-based cursor theme.

### Editors
- **neovim**: Hyperextensible Vim-based text editor (used for config editing).

### Qt Styling
- **kvantum**: SVG-based theme engine for Qt (provides `kvantummanager`).

### Networking
- **networkmanager**: Network management daemon (provides `nmcli`, `nmtui`).
- **nm-applet (AUR)**: NetworkManager system tray applet (provided by `network-manager-applet`).
