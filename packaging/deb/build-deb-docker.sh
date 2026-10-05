#!/usr/bin/env bash
# Build Archlast .deb the correct way: compile inside Debian so library ABIs
# match (e.g. libjsoncpp.so.26, libcurl4). Requires docker.
# Output: dist/archlast-<ver>-amd64.deb
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENGINE_DIR="$REPO_ROOT/engine/archlast-luanti"
VER_MAJOR=$(grep -E '^set\(VERSION_MAJOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_MINOR=$(grep -E '^set\(VERSION_MINOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_PATCH=$(grep -E '^set\(VERSION_PATCH' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VERSION="${VER_MAJOR}.${VER_MINOR}.${VER_PATCH}-archlast"

echo "=== Building archlast-builder image ==="
docker build -q -f "$REPO_ROOT/packaging/deb/Dockerfile.build" \
  -t archlast-builder:trixie "$REPO_ROOT/packaging/deb"

echo "=== Compiling engine + staging inside Debian ==="
rm -rf "$REPO_ROOT/dist/deb-stage"
mkdir -p "$REPO_ROOT/dist/deb-stage"
docker run --rm \
  -v "$REPO_ROOT:/src:ro" \
  -v "$REPO_ROOT/dist/deb-stage:/out" \
  archlast-builder:trixie bash -c '
    set -euo pipefail
    cp -a /src /work && cd /work
    git config --global --add safe.directory /work 2>/dev/null || true
    cmake -B /work/build/debian -S /work/engine/archlast-luanti -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DRUN_IN_PLACE=FALSE \
      -DBUILD_CLIENT=TRUE \
      -DBUILD_SERVER=TRUE \
      -DBUILD_UNITTESTS=FALSE \
      -DBUILD_BENCHMARKS=FALSE \
      -DVERSION_EXTRA=archlast \
      -DENABLE_GETTEXT=TRUE \
      -DENABLE_LEVELDB=TRUE \
      -DENABLE_REDIS=TRUE \
      -DENABLE_SPATIAL=TRUE \
      -DENABLE_POSTGRESQL=TRUE
    for flag in USE_LEVELDB USE_REDIS USE_SPATIAL USE_POSTGRESQL; do
      grep -q "#define $flag 1" /work/build/debian/src/cmake_config.h \
        || { echo "ERROR: $flag disabled"; exit 1; }
    done
    cmake --build /work/build/debian --parallel "$(nproc)"
    DESTDIR=/out/stage cmake --install /work/build/debian
    mkdir -p /out/stage/usr/share/luanti/games
    cp -r /work/game/arch_base /out/stage/usr/share/luanti/games/arch_base
    ln -sf luanti /out/stage/usr/bin/archlast
    ln -sf luantiserver /out/stage/usr/bin/archlast-server
    install -Dm644 /work/packaging/arch/archlast.desktop \
      /out/stage/usr/share/applications/archlast.desktop
    install -Dm644 /work/engine/archlast-luanti/misc/luanti.svg \
      /out/stage/usr/share/icons/hicolor/scalable/apps/archlast.svg
    install -Dm644 /work/engine/archlast-luanti/misc/luanti-xorg-icon-128.png \
      /out/stage/usr/share/icons/hicolor/128x128/apps/archlast.png
  '

echo "=== Assembling .deb ==="
STAGE="$REPO_ROOT/dist/deb-stage/stage"
DEBROOT="$REPO_ROOT/dist/deb-root"
rm -rf "$DEBROOT"
mkdir -p "$DEBROOT/DEBIAN" "$DEBROOT/usr"
cp -a "$STAGE/usr/." "$DEBROOT/usr/"
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
