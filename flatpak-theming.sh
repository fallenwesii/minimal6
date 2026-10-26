#!/usr/bin/env bash
# flatpak-theming.sh — keep Flatpak apps in sync with the matugen GTK theme.
#
# What this does:
#   1. Grants all user flatpaks access to ~/.themes, ~/.icons and
#      ~/.config/gtk-4.0 (the same 3 grants setup.sh applies).
#   2. Checks every installed flatpak and wires the ones that need it:
#      apps that ignore gtk-theme-name (libadwaita apps) never load the
#      theme from ~/.themes, so their sandbox config dir
#      (~/.var/app/<app>/config/gtk-4.0) is symlinked straight to the
#      matugen-enabled theme instead.
#
# Why some apps need rewiring and others don't:
#   - GTK3 / plain GTK4 flatpaks (VideoDownloader, Mimic, ...) respect
#     gtk-theme-name, find the theme in the granted ~/.themes and load
#     its colors.css on their own.     -> grants are enough
#   - libadwaita flatpaks (Apostrophe, Flatseal, ExtensionManager, ...)
#     hardcode Adwaita and ignore gtk-theme-name entirely.
#     -> need the per-app symlink this script creates
#   - Electron (Jan) and Qt (Drift) flatpaks are not GTK at all and
#     can never be themed this way. They are skipped/ignored.
#
# Safety: existing files are NEVER overwritten. Only empty gtk-4.0 dirs
# (or dirs that don't exist yet) are replaced with the symlink. Re-run
# any time — it is idempotent. Run after installing new flatpaks.
#
# Usage:
#   ./flatpak-theming.sh            grant + wire (safe, no app launches)
#   ./flatpak-theming.sh --probe    additionally launch each flatpak for a
#                                   few seconds with a CSS canary to report
#                                   which ones actually read the theme
#                                   (windows will flash on screen!)
#   ./flatpak-theming.sh --unwire   remove the per-app symlinks again
#   ./flatpak-theming.sh --help     show this help

THEME4="$HOME/.themes/adw-gtk3-dark/gtk-4.0"
PROBE=0
UNWIRE=0

for arg in "$@"; do
  case "$arg" in
    --probe) PROBE=1 ;;
    --unwire) UNWIRE=1 ;;
    -h|--help)
      sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $arg (see --help)"; exit 1 ;;
  esac
done

command -v flatpak >/dev/null || { echo "flatpak not installed."; exit 1; }

# ---------- 1. Unwire mode ----------
if [ "$UNWIRE" = 1 ]; then
  removed=0
  for cfg in "$HOME"/.var/app/*/config/gtk-4.0; do
    [ -L "$cfg" ] || continue
    if [ "$(readlink "$cfg")" = "$THEME4" ]; then
      rm "$cfg" && mkdir -p "$cfg" && removed=$((removed + 1))
    fi
  done
  echo "Removed $removed per-app theme symlink(s)."
  exit 0
fi

# ---------- 2. The 3 grants ----------
echo "Applying flatpak grants (~/.themes, ~/.icons, ~/.config/gtk-4.0)..."
flatpak override --user --filesystem="$HOME/.themes"     2>/dev/null
flatpak override --user --filesystem="$HOME/.icons"      2>/dev/null
flatpak override --user --filesystem="$HOME/.config/gtk-4.0" 2>/dev/null
echo "  done."

[ -d "$THEME4" ] || { echo "Theme not found: $THEME4 — run setup.sh first."; exit 1; }

# ---------- 3. Wire apps that need it ----------
wired=0; already=0; skipped_kde=0; custom=0; skipped_elsewhere=0

if [ "$PROBE" = 1 ]; then
  # Canary: an invalid last line. If an app loads the theme css, GTK
  # prints 'Theme parser' warnings to stderr while it starts.
  echo "CANARY_PROBE_$(date +%s) {{{ invalid" >> "$THEME4/gtk.css"
  trap 'sed -i "/^CANARY_PROBE_/d" "$THEME4/gtk.css"; echo; echo "Canary removed."' EXIT
  echo "PROBE mode: each app is launched for ~8 seconds; expect flashing windows."
fi

while read -r app; do
  [ -n "$app" ] || continue

  # Qt flatpaks (KDE runtime) can never be GTK-themed — skip them.
  if flatpak info --show-metadata "$app" 2>/dev/null | grep -q '^runtime=org\.kde\.Platform'; then
    skipped_kde=$((skipped_kde + 1))
    continue
  fi

  cfg="$HOME/.var/app/$app/config/gtk-4.0"

  if [ "$PROBE" = 1 ]; then
    out=$(timeout -s KILL 8 flatpak run "$app" 2>&1 || true)
    if echo "$out" | grep -q 'Theme parser'; then
      echo "  [probe] $app: loads theme from ~/.themes (no wiring needed)"
    else
      echo "  [probe] $app: does NOT read the theme css -> needs wiring"
    fi
  fi

  if [ -L "$cfg" ]; then
    if [ "$(readlink "$cfg")" = "$THEME4" ]; then
      already=$((already + 1))
    else
      echo "  ! $app: gtk-4.0 is a symlink elsewhere — left alone."
      skipped_elsewhere=$((skipped_elsewhere + 1))
    fi
  elif [ -d "$cfg" ]; then
    if [ -z "$(ls -A "$cfg")" ]; then
      rmdir "$cfg" && ln -s "$THEME4" "$cfg" && wired=$((wired + 1))
      echo "  + wired: $app"
    else
      echo "  ? $app: gtk-4.0 contains custom files — left alone."
      custom=$((custom + 1))
    fi
  else
    # App never ran yet: create the config dir and wire it up front.
    mkdir -p "$(dirname "$cfg")" && ln -s "$THEME4" "$cfg" && wired=$((wired + 1))
    echo "  + wired (pre-emptive): $app"
  fi
done < <(flatpak list --app --columns=application 2>/dev/null)

echo
echo "Summary: $wired wired, $already already wired, $custom left alone (custom files), $skipped_elsewhere left alone (other symlink), $skipped_kde skipped (Qt/KDE)."
echo "Re-run this after installing new flatpaks. GTK apps pick up new colors on their next launch."
