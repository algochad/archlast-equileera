#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$REPO_ROOT/bin/archlast"
LOG="/tmp/archlast-smoke.log"
SMOKE_WORLD=""

cleanup() {
    if [ -n "${SMOKE_PID:-}" ] && kill -0 "$SMOKE_PID" 2>/dev/null; then
        kill -TERM "$SMOKE_PID" 2>/dev/null || true
        wait "$SMOKE_PID" 2>/dev/null || true
    fi
    if [ -n "$SMOKE_WORLD" ] && [ -d "$SMOKE_WORLD" ]; then
        rm -rf "$SMOKE_WORLD"
    fi
}
trap cleanup EXIT

usage() {
    echo "Usage: $0 [--smoke]"
    echo "  --smoke  Headless server smoke test (create temp world, run 10s+, verify clean shutdown)"
    echo "  (no args) Launch interactive client"
    exit 1
}

if [ $# -eq 0 ]; then
    exec "$BIN"
fi

if [ "$1" != "--smoke" ]; then
    usage
fi

echo "=== Smoke Test ==="
SMOKE_WORLD="$(mktemp -d /tmp/archlast-smoke-XXXXXX)"
echo "Temp world: $SMOKE_WORLD"

# Symlink helper_mod for reliable startup detection (upstream pattern)
HELPER_MOD="$REPO_ROOT/engine/archlast-luanti/util/helper_mod"
if [ -d "$HELPER_MOD" ]; then
    mkdir -p "$SMOKE_WORLD/worldmods"
    ln -sf "$HELPER_MOD" "$SMOKE_WORLD/worldmods/helper_mod"
    echo "Helper mod linked for startup marker detection."
fi

echo "Starting headless server..."
"$BIN" --server --world "$SMOKE_WORLD" --gameid devtest --logfile "$LOG" &
SMOKE_PID=$!

echo "Waiting for server readiness (pid=$SMOKE_PID)..."
READY=0
MARKER_FILE="$SMOKE_WORLD/startup"
for i in $(seq 1 60); do
    if [ -f "$MARKER_FILE" ]; then
        READY=1
        echo "Startup marker detected after ${i}s."
        break
    fi
    if grep -q "listening on" "$LOG" 2>/dev/null; then
        READY=1
        echo "Server listening detected after ${i}s (log fallback)."
        break
    fi
    if ! kill -0 "$SMOKE_PID" 2>/dev/null; then
        echo "ERROR: Server process died before readiness."
        cat "$LOG"
        exit 1
    fi
    sleep 1
done

if [ "$READY" -ne 1 ]; then
    echo "ERROR: Server did not become ready within 60s."
    cat "$LOG"
    exit 1
fi

echo "Server running. Holding for 10s minimum..."
sleep 10

echo "Shutting down server..."
kill -TERM "$SMOKE_PID"
wait "$SMOKE_PID" 2>/dev/null
EXIT_CODE=$?

echo "=== Log Check ==="
if grep -iE 'error|segfault|moderror|assertion' "$LOG" | grep -v 'known-benign'; then
    echo "ERROR: Log contains errors."
    grep -iE 'error|segfault|moderror|assertion' "$LOG"
    exit 1
fi
echo "CLEAN"

echo "=== Smoke Test PASSED (exit=$EXIT_CODE) ==="
exit "$EXIT_CODE"
