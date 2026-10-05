#!/usr/bin/env bash
# Archlast Linux release staging: Release build + DESTDIR install + arch_base game.
# Output: dist/stage/ tree and dist/archlast-<ver>-linux-x86_64.tar.zst
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENGINE_DIR="$REPO_ROOT/engine/archlast-luanti"
GAME_DIR="$REPO_ROOT/game/arch_base"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build/release}"
STAGE="${STAGE_DIR:-$REPO_ROOT/dist/stage}"

VER_MAJOR=$(grep -E '^set\(VERSION_MAJOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_MINOR=$(grep -E '^set\(VERSION_MINOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_PATCH=$(grep -E '^set\(VERSION_PATCH' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VERSION="${VER_MAJOR}.${VER_MINOR}.${VER_PATCH}-archlast"

echo "=== Archlast $VERSION (Release, system paths) ==="
# All backends explicit. Upstream CMake only warns when a lib is absent, so
# assert USE_* below — a silently neutered engine must never ship.
# Extra dep prefix (e.g. source-built leveldb/hiredis/spatialindex): pass
# CMAKE_PREFIX_PATH=/path/to/prefix in the environment.
cmake -B "$BUILD_DIR" -S "$ENGINE_DIR" -G Ninja \
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
  grep -q "#define $flag 1" "$BUILD_DIR/src/cmake_config.h" \
    || { echo "ERROR: $flag disabled — missing backend lib. Install it and retry."; exit 1; }
done
echo "Backends OK: leveldb redis spatial postgresql"

echo "=== Building ==="
cmake --build "$BUILD_DIR" --parallel "$(( $(nproc) + 1 ))"

echo "=== DESTDIR install to $STAGE ==="
rm -rf "$STAGE"
mkdir -p "$STAGE"
DESTDIR="$STAGE" cmake --install "$BUILD_DIR"

echo "=== Bundling arch_base game ==="
mkdir -p "$STAGE/usr/share/luanti/games"
rm -rf "$STAGE/usr/share/luanti/games/arch_base"
cp -r "$GAME_DIR" "$STAGE/usr/share/luanti/games/arch_base"
echo "=== Archlast branding: icons ==="
install -Dm644 "$ENGINE_DIR/misc/luanti.svg" \
  "$STAGE/usr/share/icons/hicolor/scalable/apps/archlast.svg"
install -Dm644 "$ENGINE_DIR/misc/luanti-xorg-icon-128.png" \
  "$STAGE/usr/share/icons/hicolor/128x128/apps/archlast.png"
install -Dm644 "$ENGINE_DIR/misc/luanti-icon-24x24.png" \
  "$STAGE/usr/share/icons/hicolor/24x24/apps/archlast.png"

echo "=== Tarball ==="
mkdir -p "$REPO_ROOT/dist"
TARBALL="$REPO_ROOT/dist/archlast-${VERSION}-linux-x86_64.tar.zst"
tar --zstd -cf "$TARBALL" -C "$STAGE" usr
ls -lh "$TARBALL"
echo "STAGE=$STAGE"
echo "OK $VERSION"
