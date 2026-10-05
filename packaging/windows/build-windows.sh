#!/usr/bin/env bash
# Archlast Windows release staging + NSIS installer.
# Prerequisites: MSVC or MinGW toolchain, CMake ≥3.20, vcpkg, NSIS (makensis).
# Output: dist/stage-win/ tree and dist/archlast-<ver>-win64.exe
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE_DIR="$REPO_ROOT/engine/archlast-luanti"
GAME_DIR="$REPO_ROOT/game/arch_base"
BUILD_DIR="${BUILD_DIR:-$REPO_ROOT/build/windows}"
STAGE="${STAGE_DIR:-$REPO_ROOT/dist/stage-win}"
VCPKG_ROOT="${VCPKG_ROOT:-}"
NSIS="${NSIS:-makensis}"

# --- Version extraction (same as Linux scripts) ---
VER_MAJOR=$(grep -E '^set\(VERSION_MAJOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_MINOR=$(grep -E '^set\(VERSION_MINOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_PATCH=$(grep -E '^set\(VERSION_PATCH' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VERSION="${VER_MAJOR}.${VER_MINOR}.${VER_PATCH}-archlast"

echo "=== Archlast $VERSION (Windows Release) ==="

# --- Validate prerequisites ---
if ! command -v cmake &>/dev/null; then
  echo "ERROR: cmake not found. Install CMake ≥3.20."
  exit 1
fi

# Detect compiler toolchain
if [ -n "${CC:-}" ] || [ -n "${CXX:-}" ]; then
  echo "Using user-specified compiler: CC=${CC:-unset} CXX=${CXX:-unset}"
  GENERATOR="${CMAKE_GENERATOR:-Ninja}"
elif command -v cl &>/dev/null 2>&1 || [ -n "${MSYSTEM:-}" ]; then
  # MSVC detected via cl.exe or MSYS2/MINGW shell
  if [ "${MSYSTEM:-}" = "MINGW64" ] || [ "${MSYSTEM:-}" = "UCRT64" ] || [ "${MSYSTEM:-}" = "CLANG64" ]; then
    GENERATOR="${CMAKE_GENERATOR:-Ninja}"
    echo "Detected MSYS2 ${MSYSTEM} environment"
  else
    GENERATOR="${CMAKE_GENERATOR:-Visual Studio 17 2022}"
    echo "Detected MSVC environment"
  fi
else
  GENERATOR="${CMAKE_GENERATOR:-Ninja}"
  echo "No specific compiler detected — using generator: $GENERATOR"
  echo "Set CC/CXX or run from a Developer Command Prompt if this fails."
fi

# --- vcpkg toolchain ---
VCPKG_TOOLCHAIN=""
if [ -n "$VCPKG_ROOT" ] && [ -f "$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" ]; then
  VCPKG_TOOLCHAIN="-DCMAKE_TOOLCHAIN_FILE=$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"
  echo "Using vcpkg toolchain: $VCPKG_ROOT"
elif [ -f "$ENGINE_DIR/vcpkg.json" ]; then
  echo "WARNING: VCPKG_ROOT not set but vcpkg.json exists in engine."
  echo "  Set VCPKG_ROOT=/path/to/vcpkg or pass -DCMAKE_TOOLCHAIN_FILE=..."
  echo "  Continuing without vcpkg — build will fail if deps are missing."
fi

# --- Configure ---
echo "=== Configuring ($GENERATOR) ==="
cmake -B "$BUILD_DIR" -S "$ENGINE_DIR" -G "$GENERATOR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DRUN_IN_PLACE=TRUE \
  -DBUILD_CLIENT=TRUE \
  -DBUILD_SERVER=TRUE \
  -DBUILD_UNITTESTS=FALSE \
  -DBUILD_BENCHMARKS=FALSE \
  -DVERSION_EXTRA=archlast \
  -DENABLE_GETTEXT=TRUE \
  -DENABLE_LEVELDB=TRUE \
  -DENABLE_REDIS=TRUE \
  -DENABLE_SPATIAL=TRUE \
  -DENABLE_POSTGRESQL=TRUE \
  ${VCPKG_TOOLCHAIN}

# Assert backends enabled (same guard as Linux)
if [ -f "$BUILD_DIR/src/cmake_config.h" ]; then
  for flag in USE_LEVELDB USE_REDIS USE_SPATIAL USE_POSTGRESQL; do
    grep -q "#define $flag 1" "$BUILD_DIR/src/cmake_config.h" \
      || { echo "ERROR: $flag disabled — missing backend lib."; exit 1; }
  done
  echo "Backends OK: leveldb redis spatial postgresql"
else
  echo "WARNING: cmake_config.h not found — skipping backend assertion."
  echo "  This is expected on first configure; re-run after build if needed."
fi

# --- Build ---
echo "=== Building ==="
if [[ "$GENERATOR" == *"Visual Studio"* ]]; then
  cmake --build "$BUILD_DIR" --config Release --parallel
else
  cmake --build "$BUILD_DIR" --parallel
fi

# --- Stage ---
echo "=== Staging to $STAGE ==="
rm -rf "$STAGE"
mkdir -p "$STAGE"

# RUN_IN_PLACE=TRUE installs a portable layout: bin/, builtin/, client/, textures/, etc.
DESTDIR="$STAGE" cmake --install "$BUILD_DIR" --config Release 2>/dev/null \
  || cmake --install "$BUILD_DIR" 2>/dev/null \
  || { echo "ERROR: cmake --install failed"; exit 1; }

# --- Bundle arch_base game ---
echo "=== Bundling arch_base game ==="
GAMES_DIR="$STAGE/games"
mkdir -p "$GAMES_DIR"
rm -rf "$GAMES_DIR/arch_base"
cp -r "$GAME_DIR" "$GAMES_DIR/arch_base"

# --- Branding ---
echo "=== Archlast branding ==="
if [ -f "$ENGINE_DIR/misc/luanti-icon.ico" ]; then
  cp "$ENGINE_DIR/misc/luanti-icon.ico" "$STAGE/archlast.ico"
fi

# --- Collect runtime DLLs ---
echo "=== Collecting runtime DLLs ==="
DLL_COUNT=0
BIN_DIR="$STAGE/bin"

# Find all .exe files to scan
mapfile -t EXES < <(find "$BIN_DIR" -name '*.exe' 2>/dev/null || true)

if [ ${#EXES[@]} -gt 0 ] && command -v ldd &>/dev/null; then
  # ldd works under MSYS2/MINGW; for pure MSVC use dumpbin or dependency walker
  for exe in "${EXES[@]}"; do
    while IFS= read -r dll; do
      dll_name="$(basename "$dll")"
      # Skip system DLLs
      case "${dll_name,,}" in
        kernel32.dll|ntdll.dll|user32.dll|gdi32.dll|shell32.dll|ole32.dll|\
        advapi32.dll|ws2_32.dll|msvcrt.dll|comdlg32.dll|winmm.dll|imm32.dll|\
        oleaut32.dll|rpcrt4.dll|secur32.dll|crypt32.dll|iphlpapi.dll|\
        shlwapi.dll|version.dll|setupapi.dll|uxtheme.dll|dwmapi.dll|\
        psapi.dll|dbghelp.dll|bcrypt.dll|ncrypt.dll|mswsock.dll|\
        winhttp.dll|dhcpcsvc.dll|dnsapi.dll|wldap32.dll|normaliz.dll)
          continue ;;
      esac
      if [ -f "$dll" ] && [ ! -f "$BIN_DIR/$dll_name" ]; then
        cp -n "$dll" "$BIN_DIR/" 2>/dev/null && ((DLL_COUNT++)) || true
      fi
    done < <(ldd "$exe" 2>/dev/null | grep -oP '/\S+\.dll' | sort -u || true)
  done
elif [ ${#EXES[@]} -gt 0 ] && command -v dumpbin &>/dev/null; then
  echo "Using dumpbin for DLL collection (MSVC)"
  VCPKG_BIN="${VCPKG_ROOT}/installed/x64-windows/bin"
  if [ -d "$VCPKG_BIN" ]; then
    cp -n "$VCPKG_BIN"/*.dll "$BIN_DIR/" 2>/dev/null && DLL_COUNT=$(ls "$VCPKG_BIN"/*.dll 2>/dev/null | wc -l) || true
  fi
else
  echo "NOTE: No DLL scanner available (ldd/dumpbin)."
  echo "  If using vcpkg, copy DLLs manually from \$VCPKG_ROOT/installed/x64-windows/bin/"
fi
echo "Bundled $DLL_COUNT runtime DLLs"

# --- Generate NSIS meta.nsh ---
echo "=== Generating NSIS config ==="
PROJECT_NAME="archlast"
PROJECT_NAME_CAPITALIZED="Archlast"
DEVELOPMENT_BUILD01=0

cat > "$STAGE/meta.nsh" <<NSH
!define PROJECT_NAME "$PROJECT_NAME"
!define PROJECT_NAME_C "$PROJECT_NAME_CAPITALIZED"
!define VERSION_STRING "$VERSION"
!define DEVELOPMENT_BUILD $DEVELOPMENT_BUILD01
!define INPATH "."
!define ICONPATH "./archlast.ico"
NSH

# Copy NSIS launcher template
if [ -f "$ENGINE_DIR/misc/sfx-launcher.nsi" ]; then
  cp "$ENGINE_DIR/misc/sfx-launcher.nsi" "$STAGE/sfx-launcher.nsi"
else
  echo "WARNING: sfx-launcher.nsi not found in engine misc/"
fi

# --- Build NSIS installer ---
mkdir -p "$REPO_ROOT/dist"
INSTALLER="$REPO_ROOT/dist/archlast-${VERSION}-win64.exe"

if command -v "$NSIS" &>/dev/null; then
  echo "=== Building NSIS installer ==="
  pushd "$STAGE" > /dev/null
  "$NSIS" /V2 sfx-launcher.nsi 2>&1 | tail -5
  popd > /dev/null

  # NSIS outputs relative to the .nsi file location
  GENERATED="$STAGE/../${PROJECT_NAME}-${VERSION}.exe"
  if [ -f "$GENERATED" ]; then
    mv "$GENERATED" "$INSTALLER"
  elif [ -f "$STAGE/${PROJECT_NAME}-${VERSION}.exe" ]; then
    mv "$STAGE/${PROJECT_NAME}-${VERSION}.exe" "$INSTALLER"
  else
    echo "WARNING: NSIS ran but output exe not found at expected paths."
    echo "  Check $STAGE/ for the generated installer."
  fi
else
  echo "NOTE: makensis not found — shipping staged directory as ZIP instead."
  echo "  Install NSIS (https://nsis.sourceforge.io/) and re-run for .exe installer."
  cd "$REPO_ROOT/dist"
  if command -v zip &>/dev/null; then
    zip -r "archlast-${VERSION}-win64.zip" stage-win/ -x '*.nsi' '*.nsh'
    ls -lh "archlast-${VERSION}-win64.zip"
  elif command -v tar &>/dev/null; then
    tar --zstd -cf "archlast-${VERSION}-win64.tar.zst" -C "$REPO_ROOT/dist" stage-win
    ls -lh "archlast-${VERSION}-win64.tar.zst"
  else
    echo "ERROR: No archive tool (zip/tar) available."
    exit 1
  fi
fi

echo ""
echo "=== Summary ==="
echo "Stage:     $STAGE"
if [ -f "$INSTALLER" ]; then
  echo "Installer: $INSTALLER"
  ls -lh "$INSTALLER"
else
  echo "Installer: (not built — see notes above)"
fi
echo "Version:   $VERSION"
echo "OK $VERSION"