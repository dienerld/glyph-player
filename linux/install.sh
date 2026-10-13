#!/usr/bin/env sh
# Installs the latest Glyph Player into your home folder (no sudo). Because the
# folder is yours, the app can update itself later.
#
#   curl -fsSL https://raw.githubusercontent.com/dienerld/glyph-player/main/linux/install.sh | sh
set -eu

repo=dienerld/glyph-player
share="${XDG_DATA_HOME:-$HOME/.local/share}"
dest="$share/glyph-player"
bin="$HOME/.local/bin"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

url="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
  grep -o '"browser_download_url": *"[^"]*-linux-x64\.tar\.gz"' | cut -d'"' -f4)"
[ -n "$url" ] || { echo "no Linux release found for $repo" >&2; exit 1; }

echo "Downloading $url"
curl -fSL "$url" -o "$tmp/glyph.tar.gz"
mkdir "$tmp/x"
tar -xzf "$tmp/glyph.tar.gz" -C "$tmp/x" --strip-components=1
[ -x "$tmp/x/glyph_player" ] || { echo "unexpected archive layout" >&2; exit 1; }

rm -rf "$dest"
mkdir -p "$dest" "$bin"
cp -r "$tmp/x/." "$dest/"
rm -rf "$dest/linux" "$dest"/*.md # only needed for manual installs
"$tmp/x/linux/install_desktop.sh" "$dest"
ln -sf "$dest/glyph_player" "$bin/glyph_player"

echo "Installed to $dest (command: glyph_player)."
ldconfig -p 2>/dev/null | grep -q libmpv.so ||
  echo "Note: libmpv was not found; install mpv (Arch: pacman -S mpv, Debian: apt install libmpv2)."
