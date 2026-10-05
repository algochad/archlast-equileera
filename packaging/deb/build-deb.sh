#!/usr/bin/env bash
# Archlast .deb builder — no dpkg-deb needed (uses ar + tar + xz).
# Reuses dist/stage from packaging/package-linux.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STAGE="$REPO_ROOT/dist/stage"

ENGINE_DIR="$REPO_ROOT/engine/archlast-luanti"
VER_MAJOR=$(grep -E '^set\(VERSION_MAJOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_MINOR=$(grep -E '^set\(VERSION_MINOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_PATCH=$(grep -E '^set\(VERSION_PATCH' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VERSION="${VER_MAJOR}.${VER_MINOR}.${VER_PATCH}-archlast"

if [ ! -x "$STAGE/usr/bin/luanti" ]; then
  echo "Stage missing — running package-linux.sh first"
  "$REPO_ROOT/packaging/package-linux.sh"
fi

DEBROOT="$REPO_ROOT/dist/deb-root"
rm -rf "$DEBROOT"
mkdir -p "$DEBROOT/DEBIAN" "$DEBROOT/usr"
cp -a "$STAGE/usr/." "$DEBROOT/usr/"

# Archlast conveniences: archlast symlinks + branded desktop
ln -sf luanti "$DEBROOT/usr/bin/archlast"
ln -sf luantiserver "$DEBROOT/usr/bin/archlast-server"
install -Dm644 "$REPO_ROOT/packaging/arch/archlast.desktop" \
  "$DEBROOT/usr/share/applications/archlast.desktop"
desktop-file-validate "$DEBROOT/usr/share/applications/archlast.desktop"

INSTALLED_SIZE=$(du -sk "$DEBROOT/usr" | cut -f1)

cat > "$DEBROOT/DEBIAN/control" <<CONTROL
Package: archlast
Version: ${VERSION}-1
Section: games
Priority: optional
Architecture: amd64
Maintainer: Archlast <https://github.com/algochad/archlast-equileera>
Description: Archlast survival sandbox RPG (Luanti fork + arch_base game)
 Archlast engine (luanti/luantiserver clients) bundled with the
 arch_base game. Survival sandbox RPG built on the Luanti 5.17 fork.
Depends: libc6, libstdc++6, libcurl4t64, libvorbis0a, libvorbisfile3, libsqlite3-0, libopenal1, libfreetype6, libluajit-5.1-2, libpq5, libspatialindex8 | libspatialindex-c8, libjsoncpp26 | libjsoncpp25, libgl1, libglu1-mesa, libjpeg62-turbo | libjpeg-turbo8, libxi6, libsdl2-2.0-0, libleveldb1d, libhiredis1.1.0, libncurses6, libzip5 | libzip4, libzstd1, zlib1g, libpng16-16, hicolor-icon-theme, desktop-file-utils, xdg-utils
Installed-Size: $INSTALLED_SIZE
CONTROL

mkdir -p "$REPO_ROOT/dist"
DEB="$REPO_ROOT/dist/archlast-${VERSION}-amd64.deb"
rm -f "$DEB"
CTRLSTAGE="$(mktemp -d)"
cp "$DEBROOT/DEBIAN/control" "$CTRLSTAGE/control"
tar --numeric-owner --owner=0 --group=0 -cJf "$REPO_ROOT/dist/control.tar.xz" -C "$CTRLSTAGE" control
rm -rf "$CTRLSTAGE"
tar --numeric-owner --owner=0 --group=0 -cJf "$REPO_ROOT/dist/data.tar.xz" -C "$DEBROOT" usr
echo "2.0" > "$REPO_ROOT/dist/debian-binary"
ar rcs "$DEB" "$REPO_ROOT/dist/debian-binary" "$REPO_ROOT/dist/control.tar.xz" "$REPO_ROOT/dist/data.tar.xz"
rm -f "$REPO_ROOT/dist/debian-binary" "$REPO_ROOT/dist/control.tar.xz" "$REPO_ROOT/dist/data.tar.xz"
ls -lh "$DEB"
echo "OK $DEB"
