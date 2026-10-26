# Theme Fix Guide

If colors don't match after changing wallpaper, run through these fixes. 
`wallpaper-switcher ` + `matugen` generates the palette, but some apps need you to select the theme once.

### **GTK3 / GTK4 / Libadwaita apps**
Ex: Nautilus, GNOME apps, gsimplecal, Sublime
1. **GTK theme**: `adw-gtk3-dark`
2. **Color scheme**: `prefer-dark`
3. **Icon theme**: `FairyWren_adwaita_Dark`

`setup.sh` sets all of these automatically via gsettings. To re-apply by hand:
```bash
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface icon-theme 'FairyWren_adwaita_Dark'
```
Matugen will auto-update the colors in these themes when wallpaper changes.

> Do **not** use `nwg-look` (or similar GTK settings tools) with this setup.
> Their "export GTK4 symlinks" feature replaces the theme's own files with
> links to the system theme, which silently kills the matugen color chain.

### **Flatpak apps**
Not all flatpaks can be themed the same way — it depends on their toolkit:

| Kind | Examples | How it gets the wallpaper colors |
|---|---|---|
| GTK3 / plain GTK4 | VideoDownloader, Mimic, Frog, Blanket | **The 3 grants alone** (`~/.themes`, `~/.icons`, `~/.config/gtk-4.0`). They respect `gtk-theme-name`, find the theme in `~/.themes` and load its `colors.css` out of the box. |
| Libadwaita | Apostrophe, Flatseal, ExtensionManager | Hardcode Adwaita and **ignore `gtk-theme-name` entirely**. They need per-app wiring: `~/.var/app/<app>/config/gtk-4.0` → `~/.themes/adw-gtk3-dark/gtk-4.0` |
| Electron / Qt | Jan, Drift | **Not GTK at all** — impossible to theme via GTK. (Native Qt apps can still follow Kvantum/qt6ct; Electron apps only follow basic light/dark.) |

Run this to apply the grants and automatically wire whatever needs wiring:
```bash
./flatpak-theming.sh            # safe + idempotent, never overwrites anything
./flatpak-theming.sh --probe    # launches each flatpak briefly with a CSS
                                # canary to show which ones really read the
                                # theme (windows will flash on screen)
./flatpak-theming.sh --unwire   # remove the per-app symlinks again
```
Re-run it after installing new flatpaks. Relaunch an app to see updated colors.

### **Qt / KDE apps** 
Examples: Kvantum apps, Dolphin
1. Open `kvantum`
2. Select theme: `Matugen`
3. In `qt5ct` / `qt6ct` set **Style** to `kvantum`

### **VS Code / VSCodium**
1. Install the [Matugen Theme](https://marketplace.visualstudio.com/items?itemName=haikalllp.matugen-theme) extension
   - VS Code Marketplace or [Open VSX](https://open-vsx.org/) for VSCodium
2. `Ctrl+Shift+P` -> `Color Theme` -> select `Matugen`
3. Settings -> search `matugen` -> enable `Matugen Theme: Auto Update`  
   This will apply new colors automatically when you change wallpaper

### **Other apps**
Any app that supports theming: look for a `matugen` theme option in its settings. 
Once set, matugen will recolor it on every wallpaper change.

---
**TLDR**: Pick the `matugen` / `adw-gtk3` theme once per toolkit. After that it's automatic.
