# Phase 2 Acceptance — Engine RPG Foundations Testable

All checks runnable in order. Phase 2 passes only if all green.

## A0. Content bootstrap (reference game + shader mod)

Vendored ContentDB content is in place and boots headless.

```bash
# Placement
test -f engine/archlast-luanti/games/mineclone2/game.conf && echo "GAME PLACED"
grep -q "title = VoxeLibre" engine/archlast-luanti/games/mineclone2/game.conf && echo "GAME ID OK"
test -f engine/archlast-luanti/games/mineclone2/mods/voxelibre_shader_preset_port/mod.conf && echo "SHADER MOD PLACED"
grep -q "load_mod_" engine/archlast-luanti/games/mineclone2/game.conf 2>/dev/null && echo "WARN: unexpected load_mod" || echo "NO STALE LOAD_MOD"

# Provenance recorded
grep -q "content.mineclone2" dependencies/mods.lock && echo "PROVENANCE OK" || echo "FAIL: provenance missing"

# Headless boot on reference game via run-dev.sh (Group 0 wires --gameid; 60s loop covers first-time mapgen)
scripts/run-dev.sh --smoke --gameid mineclone2
test $? -eq 0 && echo "VL SMOKE EXIT OK" || echo "FAIL: vl smoke exit"
grep -iE 'moderror|could not be found|assertion failed|segfault' /tmp/archlast-smoke.log && echo "FAIL: content errors" || echo "A0 PASS: Content bootstrap green"
```

Pass: game + mod placed, provenance in lock file, `run-dev.sh --smoke --gameid mineclone2` exits 0, no `ModError`/`could not be found` in `/tmp/archlast-smoke.log`.

## A1. Lua API surface callable from console

Launch dev instance and verify every `arch_engine.*` namespace loads without error.

```bash
scripts/run-dev.sh --dev --logfile /tmp/archlast-a1.log &
DEV_PID=$!
sleep 8

# In Lua console (paste one line at a time):
# = arch_engine.camera.set_distance(5.0)
# = arch_engine.camera.get_distance()
# = arch_engine.camera.set_shoulder_offset({x=0.8, y=0.3, z=0})
# = arch_engine.camera.get_shoulder_offset()
# = arch_engine.camera.set_smoothing(0.15)
# = arch_engine.camera.enable_collision(true)
# = arch_engine.animation.list_states()
# = arch_engine.animation.register_state("test_state", {animation="idle", loop=true})
# = arch_engine.input.is_action_pressed("move_forward")
# = arch_engine.input.get_axis("move_x")
# = arch_engine.input.get_actions()
# = arch_engine.player.get_controller_state()
# = arch_engine.player.is_grounded()
# = arch_engine.entity.get_position(1)
# = arch_engine.render.get_fps()
# = arch_engine.render.set_debug_overlay("state_labels", true)

# After testing, kill dev server
kill $DEV_PID 2>/dev/null
wait $DEV_PID 2>/dev/null

# Verify no Lua errors in log
grep -iE 'moderror|lua error|attempt to index|arch_engine.*nil' /tmp/archlast-a1.log && echo "FAIL: Lua errors found" || echo "A1 PASS: All arch_engine.* namespaces callable"
```

Pass: no Lua errors referencing `arch_engine`, all console calls return values.

## A2. Camera collision test procedure

Verify third-person camera does not clip terrain in smoke world.

```bash
scripts/run-dev.sh --smoke --third-person --logfile /tmp/archlast-a2.log
echo "Exit code: $?"

# Check camera manager initialized
grep '\[ARCH-ENGINE:CAMERA\].*initialized\|\[ARCH-ENGINE:CAMERA\].*collision enabled' /tmp/archlast-a2.log && echo "Camera init OK" || echo "WARN: No camera init message"

# Check for camera clipping errors or warnings
grep -i '\[ARCH-ENGINE:CAMERA\].*clip\|\[ARCH-ENGINE:CAMERA\].*fail\|\[ARCH-ENGINE:CAMERA\].*error' /tmp/archlast-a2.log && echo "FAIL: Camera issues detected" || echo "A2 PASS: No camera collision failures"

# Manual verification (if GUI available):
# scripts/run-dev.sh --dev --third-person
# Walk player into wall → camera should pull closer
# Walk through narrow corridor → camera should not clip geometry
# Look up/down → pitch should clamp at ±80°
```

Pass: exit code 0, no camera error/warning lines in log.

## A3. Animation transition observation

Verify state machine transitions are observable via debug overlay or log.

```bash
scripts/run-dev.sh --smoke --third-person --logfile /tmp/archlast-a3.log

# Check built-in states registered
STATE_COUNT=$(grep -c '\[ARCH-ENGINE:ANIM\].*registered state' /tmp/archlast-a3.log)
echo "Registered states: $STATE_COUNT"
test "$STATE_COUNT" -ge 13 && echo "State count OK" || echo "FAIL: Expected ≥13 states, got $STATE_COUNT"

# Check transitions occurred during smoke test
grep '\[ARCH-ENGINE:ANIM\].*transition' /tmp/archlast-a3.log | head -10

# Check for animation errors
grep -i '\[ARCH-ENGINE:ANIM\].*error\|\[ARCH-ENGINE:ANIM\].*fail\|\[ARCH-ENGINE:ANIM\].*missing' /tmp/archlast-a3.log && echo "FAIL: Animation errors found" || echo "A3 PASS: Animation FSM operational"

# Manual verification (GUI):
# Enable debug overlay: = arch_engine.render.set_debug_overlay("state_labels", true)
# Walk, run, jump, fall → observe state label changes on player model
# Expected sequence: idle → walk → run → jump → fall → land → idle
```

Pass: ≥13 states registered, no animation errors in log.

## A4. Input mapping test

Verify keyboard and gamepad action mapping works.

```bash
scripts/run-dev.sh --smoke --third-person --logfile /tmp/archlast-a4.log

# Check input profile loaded
grep '\[ARCH-ENGINE:INPUT\].*loaded profile.*input_default.json' /tmp/archlast-a4.log && echo "Profile loaded OK" || echo "FAIL: Default profile not loaded"

# Check actions registered
ACTION_COUNT=$(grep -c '\[ARCH-ENGINE:INPUT\].*bound action' /tmp/archlast-a4.log)
echo "Bound actions: $ACTION_COUNT"
test "$ACTION_COUNT" -ge 7 && echo "Action count OK" || echo "FAIL: Expected ≥7 actions, got $ACTION_COUNT"

# Check for input errors
grep -i '\[ARCH-ENGINE:INPUT\].*error\|\[ARCH-ENGINE:INPUT\].*fail' /tmp/archlast-a4.log && echo "FAIL: Input errors found" || echo "A4 PASS: Input system operational"

# Manual verification (GUI):
# Press W → character moves forward
# Press Shift → character sprints
# Connect gamepad, push left stick → character moves
# In Lua console: = arch_engine.input.is_action_pressed("move_forward") while holding W → true
# = arch_engine.input.get_axis("move_y") while pushing stick → non-zero value
```

Pass: profile loaded, ≥7 actions bound, no input errors.

## A5. Build + smoke green

Full build and smoke test must pass with third-person mode active.

```bash
# Clean build
scripts/build-linux.sh
BUILD_EXIT=$?
echo "Build exit code: $BUILD_EXIT"
test "$BUILD_EXIT" -eq 0 && echo "Build OK" || echo "FAIL: Build failed"

# Verify binary exists and is executable
test -x bin/archlast && echo "Binary OK" || echo "FAIL: bin/archlast missing or not executable"

# Smoke test with third-person
scripts/run-dev.sh --smoke --third-person
SMOKE_EXIT=$?
echo "Smoke exit code: $SMOKE_EXIT"
test "$SMOKE_EXIT" -eq 0 && echo "Smoke OK" || echo "FAIL: Smoke test failed"

# Full log check
grep -iE 'error\[main\]|segfault|moderror|assertion failed|core dump' /tmp/archlast-smoke.log && echo "FAIL: Critical errors in smoke log" || echo "A5 PASS: Build + smoke green"
```

Pass: build exit 0, smoke exit 0, no critical errors in log.

## A6. Performance regression check

Frame time must not regress >10% vs Phase 1 baseline.

```bash
# Ensure Phase 1 baseline exists (captured at Phase 2 start per TASKS.md)
test -f /tmp/phase1-baseline.txt && echo "Baseline exists" || echo "FAIL: Run TASKS.md prerequisites first"

# Run Phase 2 benchmark
scripts/run-dev.sh --smoke --bench > /tmp/phase2-bench.txt 2>&1

# Extract frame times
BASELINE_FT=$(grep 'frame_time_ms' /tmp/phase1-baseline.txt | awk '{print $NF}' | head -1)
CURRENT_FT=$(grep 'frame_time_ms' /tmp/phase2-bench.txt | awk '{print $NF}' | head -1)

echo "Phase 1 baseline: ${BASELINE_FT}ms"
echo "Phase 2 current:  ${CURRENT_FT}ms"

# Calculate regression
python3 -c "
import sys
try:
    baseline = float('${BASELINE_FT}')
    current = float('${CURRENT_FT}')
    regression = (current - baseline) / baseline * 100
    print(f'Regression: {regression:.1f}%')
    if regression <= 10.0:
        print('A6 PASS: Within 10% budget')
    else:
        print(f'FAIL: Regression {regression:.1f}% exceeds 10% budget')
        sys.exit(1)
except ValueError as e:
    print(f'FAIL: Could not parse frame times: {e}')
    sys.exit(1)
"
```

Pass: prints `A6 PASS: Within 10% budget`.

## Fail → do not proceed

Any red check = fix before declaring Phase 2 complete. Record failures in `docs/plans/phase-02-engine-rpg-foundations/RESULTS.md`:

```bash
cat >> docs/plans/phase-02-engine-rpg-foundations/RESULTS.md << EOF
## $(date -u +%Y-%m-%dT%H:%M:%SZ)

- A0: <PASS|FAIL> — <notes>
- A1: <PASS|FAIL> — <notes>
- A2: <PASS|FAIL> — <notes>
- A3: <PASS|FAIL> — <notes>
- A4: <PASS|FAIL> — <notes>
- A5: <PASS|FAIL> — <notes>
- A6: <PASS|FAIL> — <notes>
- Commit: $(git rev-parse HEAD)
- Engine commit: $(git -C engine/archlast-luanti rev-parse HEAD)
EOF
```

All seven checks green → Phase 2 complete. Proceed to Phase 3.