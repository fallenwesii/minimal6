# minimal6

A minimal swayfx dotfiles.

## ✨ Features

- Dynamic wallpaper-based theming
- wallpaper switcher
- GTK3, GTK4, Qt5, Qt6 & Kvantum support
- Waybar integration
- Wofi launcher 
- Swaync notifications
- Terminal theming
- Consistent desktop styling
- System wide blur via a toggle
- Automatic theme reload
- Fast installation

## Screenshots

 ![minimal6](/screenshots/desktop.png)

## Setup

```bash
git clone  --depth 1 https://github.com/fallenwesii/minimal6.git
cd minimal6
chmod +x setup.sh && ./setup.sh
```

Installs packages (pacman + AUR), links configs, applies wallpaper and generates colors based on matugen .

## Uninstall

To undo the symlinks, scripts, and theme overrides set up by minimal6 (without uninstalling any applications):

```bash
./uninstall.sh
```

## Keybinds

 `Super + H`  to view all keybindings.   
