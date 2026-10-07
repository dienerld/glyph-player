#!/usr/bin/env bash
# Builds a .deb that installs system-wide: the bundle in /opt/glyph-player, a
# glyph_player launcher in /usr/bin, and the menu entry and icons in /usr/share.
#
# Usage: tool/package_deb.sh <version> [path/to/bundle]
#   default bundle: build/linux/x64/release/bundle (run `flutter build linux` first)
# Output: build/glyph-player_<version>_amd64.deb
set -euo pipefail

version="${1:?usage: package_deb.sh <version> [bundle]}"
root="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$(realpath "${2:-$root/build/linux/x64/release/bundle}")"
[ -x "$bundle/glyph_player" ] || { echo "no glyph_player binary in $bundle (run: flutter build linux)" >&2; exit 1; }

id="dev.glyph.glyph_player"
pkg="$root/build/deb/glyph-player"
rm -rf "$root/build/deb"
install -d "$pkg/DEBIAN" "$pkg/opt/glyph-player" "$pkg/usr/bin" "$pkg/usr/share/applications" "$pkg/usr/share/icons"

cp -r "$bundle/." "$pkg/opt/glyph-player/"
ln -s /opt/glyph-player/glyph_player "$pkg/usr/bin/glyph_player"
cp -r "$root/linux/icons/hicolor" "$pkg/usr/share/icons/"
install -m 644 "$root/linux/$id.desktop" "$pkg/usr/share/applications/$id.desktop"

cat > "$pkg/DEBIAN/control" <<CONTROL
Package: glyph-player
Version: $version
Section: video
Priority: optional
Architecture: amd64
Depends: libgtk-3-0 | libgtk-3-0t64, libmpv2 | libmpv1, libsecret-1-0
Installed-Size: $(du -sk "$pkg/opt" | cut -f1)
Maintainer: Glyph <noreply@glyph.dev>
Description: IPTV player for your own M3U playlist
 Watch live TV, movies and series from your own M3U_plus playlist.
CONTROL

find "$pkg" -type d -exec chmod 755 {} +
out="$root/build/glyph-player_${version}_amd64.deb"
dpkg-deb --root-owner-group --build "$pkg" "$out"
echo "built: $out"
