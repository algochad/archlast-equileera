#!/usr/bin/env bash
# Runs INSIDE the Docker container to cross-compile Archlast for Windows.
# Called by build-windows-docker.sh — do not run directly on host.
set -euo pipefail

VERSION="$1"
TRIPLET="x64-mingw-static"

echo "--- Copying source to writable workspace ---"
mkdir -p /work
cp -a /src/. /work/
cd /work
git config --global --add safe.directory /work 2>/dev/null || true
git config --global --add safe.directory /work/engine/archlast-luanti 2>/dev/null || true

echo "--- Installing vcpkg dependencies ($TRIPLET) ---"
cd /tmp
/opt/vcpkg/vcpkg install \
    --triplet "$TRIPLET" \
    --overlay-triplets=/opt/vcpkg/triplets/community \
    zlib zstd openssl "curl[ssl]" openal-soft libvorbis libogg \
    libjpeg-turbo sqlite3 freetype gmp jsoncpp \
    gettext sdl2 leveldb libspatialindex libpq libzip

echo "--- Building LuaJIT manually (vcpkg port broken for MinGW cross) ---"
LUAJIT_SRC="/tmp/luajit-src"
rm -rf "$LUAJIT_SRC"
mkdir -p "$LUAJIT_SRC"
curl -sSL -o /tmp/luajit.tar.gz \
    "https://github.com/LuaJIT/LuaJIT/archive/c6ffc141a8762b41703f9287d63d93622a13dd8f.tar.gz"
tar xzf /tmp/luajit.tar.gz -C "$LUAJIT_SRC" --strip-components=1
# Use the root Makefile with CROSS= prefix — this builds host tools (minilua, buildvm)
# natively first, then cross-compiles the target library automatically.
make -C "$LUAJIT_SRC" \
    HOST_CC=gcc \
    CROSS=x86_64-w64-mingw32- \
    TARGET_SYS=Windows \
    BUILDMODE=static \
    XCFLAGS="-DLUAJIT_NO_UNWIND" \
    amalg 2>&1 | tail -10
# Install into vcpkg prefix so CMake finds it
LUAJIT_PREFIX="/opt/vcpkg/installed/x64-mingw-static"
mkdir -p "$LUAJIT_PREFIX/lib" "$LUAJIT_PREFIX/include/luajit"
cp "$LUAJIT_SRC/src/libluajit.a" "$LUAJIT_PREFIX/lib/"
cp "$LUAJIT_SRC/src"/lua.h "$LUAJIT_PREFIX/include/luajit/"
cp "$LUAJIT_SRC/src"/lauxlib.h "$LUAJIT_PREFIX/include/luajit/"
cp "$LUAJIT_SRC/src/luaconf.h" "$LUAJIT_PREFIX/include/luajit/"
cp "$LUAJIT_SRC/src/lualib.h" "$LUAJIT_PREFIX/include/luajit/"
cp "$LUAJIT_SRC/src/luajit.h" "$LUAJIT_PREFIX/include/luajit/"
cp "$LUAJIT_SRC/src/lua.hpp" "$LUAJIT_PREFIX/include/luajit/" 2>/dev/null || true
echo "LuaJIT installed to $LUAJIT_PREFIX"

echo "--- Configuring CMake with vcpkg toolchain ---"
cmake -B /work/build/windows -S /work/engine/archlast-luanti -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=/opt/vcpkg/scripts/buildsystems/vcpkg.cmake \
    -DVCPKG_TARGET_TRIPLET="$TRIPLET" \
    -DVCPKG_MANIFEST_MODE=OFF \
    -DRUN_IN_PLACE=TRUE \
    -DBUILD_CLIENT=TRUE \
    -DBUILD_SERVER=TRUE \
    -DBUILD_UNITTESTS=FALSE \
    -DBUILD_BENCHMARKS=FALSE \
    -DVERSION_EXTRA=archlast \
    -DENABLE_GETTEXT=TRUE \
    -DENABLE_LEVELDB=TRUE \
    -DENABLE_REDIS=FALSE \
    -DENABLE_SPATIAL=TRUE \
    -DENABLE_POSTGRESQL=TRUE

# Assert backends enabled (Redis disabled — hiredis fails to cross-compile with MinGW)
for flag in USE_LEVELDB USE_SPATIAL USE_POSTGRESQL; do
    grep -q "#define $flag 1" /work/build/windows/src/cmake_config.h \
        || { echo "ERROR: $flag disabled"; exit 1; }
done
echo "Backends OK: leveldb spatial postgresql (redis disabled)"

echo "--- Building ---"
cmake --build /work/build/windows --parallel "$(nproc)"

echo "--- Staging ---"
DESTDIR=/out/stage cmake --install /work/build/windows

# Bundle arch_base game
mkdir -p /out/stage/games
cp -r /work/game/arch_base /out/stage/games/arch_base

# Branding
install -Dm644 /work/engine/archlast-luanti/misc/luanti-icon.ico \
    /out/stage/archlast.ico

# Copy NSIS launcher template
cp /work/engine/archlast-luanti/misc/sfx-launcher.nsi /out/stage/sfx-launcher.nsi

# Generate meta.nsh for NSIS
cat > /out/stage/meta.nsh <<EOF
!define PROJECT_NAME "archlast"
!define PROJECT_NAME_C "Archlast"
!define VERSION_STRING "$VERSION"
!define DEVELOPMENT_BUILD 0
!define INPATH "."
!define ICONPATH "./archlast.ico"
EOF

echo "--- Collecting runtime DLLs from vcpkg ---"
VCPKG_BIN="/opt/vcpkg/installed/$TRIPLET/bin"
if [ -d "$VCPKG_BIN" ]; then
    cp -n "$VCPKG_BIN"/*.dll /out/stage/bin/ 2>/dev/null || true
    echo "Copied $(ls "$VCPKG_BIN"/*.dll 2>/dev/null | wc -l) DLLs from vcpkg"
fi

echo "--- Build complete inside container ---"