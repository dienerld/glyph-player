#!/usr/bin/env bash
# Regenerates the Linux PNGs and the Windows .ico from assets/icon/*.svg.
# Needs rsvg-convert and ImageMagick. Small sizes use the simplified gem.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

for s in 16 24 32 48; do
  rsvg-convert -w $s -h $s "$root/assets/icon/glyph_icon_small.svg" -o "$tmp/$s.png"
done
for s in 64 128 256 512; do
  rsvg-convert -w $s -h $s "$root/assets/icon/glyph_icon.svg" -o "$tmp/$s.png"
done
for s in 16 24 32 48 64 128 256 512; do
  d="$root/linux/icons/hicolor/${s}x${s}/apps"; mkdir -p "$d"
  cp "$tmp/$s.png" "$d/dev.glyph.glyph_player.png"
done
magick "$tmp/16.png" "$tmp/24.png" "$tmp/32.png" "$tmp/48.png" "$tmp/64.png" \
  "$tmp/128.png" "$tmp/256.png" "$root/windows/runner/resources/app_icon.ico"
echo "icons regenerated"
