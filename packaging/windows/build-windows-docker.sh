#!/usr/bin/env bash
# Build Archlast Windows .exe inside Docker using MinGW-w64 + vcpkg cross-compile.
# Output: dist/archlast-<ver>-win64.exe (NSIS installer) + dist/archlast-<ver>-win64-portable.zip
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE_DIR="$REPO_ROOT/engine/archlast-luanti"

# Version extraction from engine CMakeLists.txt
VER_MAJOR=$(grep -E '^set\(VERSION_MAJOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_MINOR=$(grep -E '^set\(VERSION_MINOR' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VER_PATCH=$(grep -E '^set\(VERSION_PATCH' "$ENGINE_DIR/CMakeLists.txt" | grep -oP '\d+')
VERSION="${VER_MAJOR}.${VER_MINOR}.${VER_PATCH}-archlast"

echo "=== Building archlast-win-builder image ==="
docker build -q -f "$REPO_ROOT/packaging/windows/Dockerfile.build" \
	-t archlast-win-builder:latest "$REPO_ROOT/packaging/windows"

echo "=== Cross-compiling engine + staging inside container ==="
rm -rf "$REPO_ROOT/dist/win-stage"
mkdir -p "$REPO_ROOT/dist/win-stage"

# Mount repo read-write so vcpkg can write its installed/ tree alongside sources.
# The actual build logic lives in build-inside-docker.sh to avoid heredoc quoting issues.
docker run --rm \
	-v "$REPO_ROOT:/src" \
	-v "$REPO_ROOT/dist/win-stage:/out" \
	archlast-win-builder:latest \
	bash /src/packaging/windows/build-inside-docker.sh "$VERSION"

echo "=== Building NSIS installer ==="
STAGE="$REPO_ROOT/dist/win-stage/stage"

docker run --rm \
	-v "$STAGE:/nsis" \
	-v "$REPO_ROOT/dist:/dist" \
	archlast-win-builder:latest bash -c '
		cd /nsis
		makensis /V2 sfx-launcher.nsi 2>&1 | tail -5
		EXE=$(ls /nsis/archlast-*.exe 2>/dev/null | head -1)
		if [ -n "$EXE" ]; then
			mv "$EXE" "/dist/archlast-'"$VERSION"'-win64.exe"
		else
			echo "WARNING: NSIS output not found"
		fi
	'

echo "=== Creating portable ZIP ==="
ZIP_FILE="$REPO_ROOT/dist/archlast-${VERSION}-win64-portable.zip"
rm -f "$ZIP_FILE"
(cd "$STAGE" && zip -r "$ZIP_FILE" . -x "*.nsi" "*.nsh")
ls -lh "$ZIP_FILE"

echo ""
echo "=== Summary ==="
echo "Version: $VERSION"
if [ -f "$REPO_ROOT/dist/archlast-${VERSION}-win64.exe" ]; then
	echo "Installer: $REPO_ROOT/dist/archlast-${VERSION}-win64.exe"
	ls -lh "$REPO_ROOT/dist/archlast-${VERSION}-win64.exe"
else
	echo "Installer: NOT BUILT (check NSIS output above)"
fi
echo "Portable ZIP: $ZIP_FILE"
echo "OK $VERSION"