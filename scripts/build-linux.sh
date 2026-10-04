#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENGINE_DIR="$REPO_ROOT/engine/archlast-luanti"
BUILD_DIR="$REPO_ROOT/build/linux"
BIN_DIR="$REPO_ROOT/bin"

if [ ! -f "$ENGINE_DIR/CMakeLists.txt" ]; then
    echo "ERROR: $ENGINE_DIR/CMakeLists.txt not found. Run bootstrap and check submodule."
    exit 1
fi

echo "=== Configuring ==="
cmake -B "$BUILD_DIR" -S "$ENGINE_DIR" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DRUN_IN_PLACE=TRUE \
    -DBUILD_SERVER=TRUE \
    -DVERSION_EXTRA=archlast \
    -DENABLE_LTO=FALSE \
    -DENABLE_GETTEXT=TRUE

echo "=== Building ==="
cmake --build "$BUILD_DIR" --parallel "$(($(nproc)+1))"

echo "=== Creating bin/archlast wrapper ==="
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/archlast" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../engine/archlast-luanti/bin/luanti" "$@"
WRAPPER
chmod +x "$BIN_DIR/archlast"

echo "=== Build complete ==="
ls -lh "$BIN_DIR/archlast"
"$BIN_DIR/archlast" --version
