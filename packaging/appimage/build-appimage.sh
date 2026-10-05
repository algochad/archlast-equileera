#!/usr/bin/env bash
# Archlast AppImage: bundles Release stage + runtime .so deps into AppDir,
# ships arch-runtime to generate a .AppImage with appimagetool OR a portable
# fallback tarball when appimagetool/squashfs is unavailable.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE_DIR="$REPO_ROOT/engine/archlast-luanti"
STAGE="$REPO_ROOT/dist/stage"
APPDIR="$REPO_ROOT/dist/AppDir"

VER_MAJOR=$(grep -E '^set\(VERSION_MAJOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_MINOR=$(grep -E '^set\(VERSION_MINOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_PATCH=$(grep -E '^set\(VERSION_PATCH' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VERSION="${VER_MAJOR}.${VER_MINOR}.${VER_PATCH}-archlast"

if [ ! -x "$STAGE/usr/bin/luanti" ]; then
  echo "Stage missing — running package-linux.sh first"
  "$REPO_ROOT/packaging/package-linux.sh"
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr" "$APPDIR/usr/lib"
cp -a "$STAGE/usr/." "$APPDIR/usr/"

# Branding: archlast.desktop + icon at AppDir root
sed 's|^Exec=.*|Exec=archlast --gameid arch_base|' \
  "$REPO_ROOT/packaging/arch/archlast.desktop" > "$APPDIR/archlast.desktop"
cp "$ENGINE_DIR/misc/luanti.svg" "$APPDIR/archlast.svg"
cp "$ENGINE_DIR/misc/luanti-xorg-icon-128.png" "$APPDIR/archlast.png"

# Bundle non-baseline runtime libs (ldd closure minus libc/libm/libX11-class + GL/vendor).
# EXTRA_LIB_DIRS (colon-separated) supplies non-system dep prefixes such as a
# source-built leveldb/hiredis/spatialindex staging dir.
EXCLUDE='^/(lib|lib64|usr/lib).*/(libc\.|libm\.|libpthread|libdl\.|librt\.|libresolv|libnss_|libX11|libxcb\.|libXau\.|libXdmcp\.|libGLdispatch|libGLX\.|libOpenGL\.|libEGL\.|libdrm\.|libgbm\.|libxkbcommon)'
export LD_LIBRARY_PATH="${EXTRA_LIB_DIRS:-}${EXTRA_LIB_DIRS:+:}${LD_LIBRARY_PATH:-}"
mapfile -t LIBS < <(ldd "$APPDIR/usr/bin/luanti" "$APPDIR/usr/bin/luantiserver" 2>/dev/null \
  | grep -oP '/\S+\.so[^ ]*' | sort -u | grep -vP "$EXCLUDE" || true)
for lib in "${LIBS[@]}"; do
  [ -f "$lib" ] && cp -Ln "$lib" "$APPDIR/usr/lib/" 2>/dev/null || true
done
# Anything still unresolved (e.g. deps found only via EXTRA_LIB_DIRS at build
# time): copy by SONAME from the extra dirs so the bundle is self-contained.
mapfile -t MISSING < <(ldd "$APPDIR/usr/bin/luanti" "$APPDIR/usr/bin/luantiserver" 2>/dev/null \
  | grep "not found" | grep -oP '^\s*\S+' | xargs -n1 basename 2>/dev/null | sort -u || true)
IFS=':' read -ra EXTRADIRS <<< "${EXTRA_LIB_DIRS:-}"
for soname in "${MISSING[@]}"; do
  for d in "${EXTRADIRS[@]}"; do
    if [ -f "$d/$soname" ]; then cp -Ln "$d/$soname" "$APPDIR/usr/lib/"; break; fi
  done
done

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
export LUANTI_GAME_PATH="$HERE/usr/share/luanti/games"
case "$(basename "$0")" in
  archlast-server|luantiserver) exec "$HERE/usr/bin/luantiserver" "$@" ;;
  *) exec "$HERE/usr/bin/luanti" "$@" ;;
esac
APPRUN
chmod +x "$APPDIR/AppRun"
ln -sf AppRun "$APPDIR/archlast-server"

echo "Bundled $(ls "$APPDIR/usr/lib" | wc -l) shared libs, $(du -sh "$APPDIR" | cut -f1) total"

mkdir -p "$REPO_ROOT/dist"
if command -v appimagetool &>/dev/null || [ -x "$REPO_ROOT/dist/appimagetool" ]; then
  TOOL="${APPIMAGETOOL:-$REPO_ROOT/dist/appimagetool}"
  if [ ! -x "$TOOL" ]; then
    echo "Downloading appimagetool..."
    curl -sSL -o "$TOOL" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x "$TOOL"
  fi
  ARCH=x86_64 "$TOOL" "$APPDIR" "$REPO_ROOT/dist/archlast-${VERSION}-x86_64.AppImage"
  ls -lh "$REPO_ROOT/dist/"*.AppImage
else
  echo "NOTE: appimagetool/squashfs absent — shipping portable AppDir tarball instead"
  tar --zstd -cf "$REPO_ROOT/dist/archlast-${VERSION}-x86_64-appdir.tar.zst" -C "$REPO_ROOT/dist" AppDir
  ls -lh "$REPO_ROOT/dist/archlast-${VERSION}-x86_64-appdir.tar.zst"
  echo "Install appimagetool later and rerun to get a .AppImage"
fi
echo "OK $VERSION"
