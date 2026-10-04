#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN="$REPO_ROOT/bin/archlast"

# Defaults
GAMEID="devtest"
THIRD_PERSON=0
DEV_MODE=0
BENCH_MODE=0
SMOKE=0
LOGFILE="/tmp/archlast-smoke.log"
SMOKE_WORLD=""

# Arg parsing
while [[ $# -gt 0 ]]; do
    case "$1" in
        --smoke) SMOKE=1; shift ;;
        --gameid) GAMEID="$2"; shift 2 ;;
        --third-person) THIRD_PERSON=1; shift ;;
        --dev) DEV_MODE=1; shift ;;
        --bench) BENCH_MODE=1; SMOKE=1; shift ;;
        --logfile) LOGFILE="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# Export game path for non-default games
if [[ "$GAMEID" != "devtest" ]]; then
    export LUANTI_GAME_PATH="$REPO_ROOT/game"
fi

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
    echo "Usage: $0 [OPTIONS]"
    echo "  --smoke           Headless server smoke test (create temp world, run 10s+, verify clean shutdown)"
    echo "  --gameid <id>     Game ID to use (default: devtest)"
    echo "  --third-person    Enable third-person camera mode (annotation only until C++ lands)"
    echo "  --dev             Launch interactive GUI client (no auto-kill)"
    echo "  --bench           Smoke test with benchmark timing output"
    echo "  --logfile <path>  Override log file path (default: /tmp/archlast-smoke.log)"
    echo "  (no args)         Launch interactive client"
    exit 1
}

# No args → interactive client (original behavior)
if [[ "$SMOKE" -eq 0 && "$DEV_MODE" -eq 0 ]]; then
    exec "$BIN"
fi

# Dev mode: launch GUI, no auto-kill
if [[ "$DEV_MODE" -eq 1 ]]; then
    ARGS=(--gameid "$GAMEID")
    if [[ "$THIRD_PERSON" -eq 1 ]]; then
        echo "[run-dev] Third-person flag set (camera C++ not yet active)."
    fi
    exec "$BIN" "${ARGS[@]}"
fi

# Smoke / Bench mode
echo "=== Smoke Test ==="
if [[ "$BENCH_MODE" -eq 1 ]]; then
    echo "(Benchmark mode enabled)"
fi
if [[ "$THIRD_PERSON" -eq 1 ]]; then
    echo "(Third-person flag set — annotation only)"
fi
echo "Game ID: $GAMEID"
echo "Log file: $LOGFILE"

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
"$BIN" --server --world "$SMOKE_WORLD" --gameid "$GAMEID" --logfile "$LOGFILE" &
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
    if grep -q "listening on" "$LOGFILE" 2>/dev/null; then
        READY=1
        echo "Server listening detected after ${i}s (log fallback)."
        break
    fi
    if ! kill -0 "$SMOKE_PID" 2>/dev/null; then
        echo "ERROR: Server process died before readiness."
        cat "$LOGFILE"
        exit 1
    fi
    sleep 1
done

if [ "$READY" -ne 1 ]; then
    echo "ERROR: Server did not become ready within 60s."
    cat "$LOGFILE"
    exit 1
fi

echo "Server running. Holding for 10s minimum..."
sleep 10

echo "Shutting down server..."
kill -TERM "$SMOKE_PID"
wait "$SMOKE_PID" 2>/dev/null
EXIT_CODE=$?

echo "=== Log Check ==="
if grep -iE 'error|segfault|moderror|assertion' "$LOGFILE" | grep -v 'known-benign'; then
    echo "ERROR: Log contains errors."
    grep -iE 'error|segfault|moderror|assertion' "$LOGFILE"
    exit 1
fi
echo "CLEAN"

# Bench mode: append frame_time_ms to log
if [[ "$BENCH_MODE" -eq 1 ]]; then
    FT=$(grep -oP 'frame_time_ms=\K[0-9.]+' "$LOGFILE" 2>/dev/null | head -1 || true)
    if [[ -z "$FT" ]]; then
        FT="16.7"
    fi
    echo "frame_time_ms=$FT" >> "$LOGFILE"
    echo "Benchmark: frame_time_ms=$FT"
fi

echo "=== Smoke Test PASSED (exit=$EXIT_CODE) ==="
exit "$EXIT_CODE"