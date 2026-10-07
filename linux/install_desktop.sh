#!/usr/bin/env bash
# Installs the app icon and a launcher for the current user (no sudo) so the
# shell shows "Glyph Player" with its icon. Wayland desktops take the icon from
# this .desktop entry (the window icon alone is not enough there).
#
# Usage: linux/install_desktop.sh [path/to/bundle]
#   default bundle: build/linux/x64/release/bundle
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$(realpath "${1:-$root/build/linux/x64/release/bundle}")"
[ -x "$bundle/glyph_player" ] || { echo "no glyph_player binary in $bundle (run: flutter build linux)" >&2; exit 1; }

share="${XDG_DATA_HOME:-$HOME/.local/share}"
for dir in "$root"/linux/icons/hicolor/*/apps; do
  size="$(basename "$(dirname "$dir")")"
  mkdir -p "$share/icons/hicolor/$size/apps"
  cp "$dir/dev.glyph.glyph_player.png" "$share/icons/hicolor/$size/apps/"
done

mkdir -p "$share/applications"
sed "s|^Exec=.*|Exec=$bundle/glyph_player|" "$root/linux/dev.glyph.glyph_player.desktop" \
  > "$share/applications/dev.glyph.glyph_player.desktop"

command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$share/icons/hicolor" || true
command -v update-desktop-database >/dev/null && update-desktop-database -q "$share/applications" || true
echo "installed: $share/applications/dev.glyph.glyph_player.desktop"
