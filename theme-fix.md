# Theme Fix Guide

If colors don't match after changing wallpaper, run through these fixes. 
`wallpaper-switcher or minimal6(quick-settings)` + `matugen` generates the palette, but some apps need you to select the theme once.

### **GTK3 / GTK4 / Libadwaita apps**
Ex: Nautilus, GNOME apps
1. Open `nwg-look`
2. **GTK3 Theme**: `adw-gtk3`
3. **GTK4 Theme**: `adw-gtk3`
4. **Icon Theme**: pick whatever you set in m6

Matugen will auto-update the colors in these themes when wallpaper changes.

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
   This will apply new colors automatically when you change wallpaper with m6

### **Other apps**
Any app that supports theming: look for a `matugen` theme option in its settings. 
Once set, matugen will recolor it on every wallpaper change.

---
**TLDR**: Pick the `matugen` / `adw-gtk3` theme once per toolkit. After that it's automatic.
