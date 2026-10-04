# Phase 2 Acceptance — Engine RPG Foundations Testable

All checks runnable in order. Phase 2 passes only if all green.

## A0. Base game `arch_base` (executed in this phase)

Merged severed-history game is in place and boots headless. This gate is verified as part of Phase 2 acceptance.

```bash
# Placement
test -f game/arch_base/game.conf && grep -q "title = Arch Base" game/arch_base/game.conf && echo "GAME OK"
test -f game/arch_base/mods/arch_shader_preset/mod.conf && grep -q "name = arch_shader_preset" game/arch_base/mods/arch_shader_preset/mod.conf && echo "SHADER OK"

# Identity purge: no upstream ids survive in config
grep -ri "voxelibre_shader_preset_port\|mineclone2" game/arch_base --include="*.conf" -l && echo "FAIL: stale ids" || echo "IDS CLEAN"

# Provenance recorded
grep -q "content.arch_base.mineclonia" dependencies/mods.lock && grep -q "content.arch_base.voxelibre" dependencies/mods.lock && grep -q "content.arch_base.shader_preset" dependencies/mods.lock && echo "PROVENANCE OK" || echo "FAIL: provenance missing"

# Headless boot on merged game (60s loop covers first-time mapgen)
scripts/run-dev.sh --smoke --gameid arch_base
test $? -eq 0 && echo "SMOKE EXIT OK" || echo "FAIL: smoke exit"
grep -iE 'moderror|could not be found|assertion failed|segfault' /tmp/archlast-smoke.log && echo "FAIL: content errors" || echo "A0 PASS: Base game green"
```

Pass: `game/arch_base/` placed with `Arch Base` title + `arch_shader_preset` mod, no stale upstream ids, provenance SHAs in lock file, smoke exits 0 with `listening on` and clean log.

## A1. Lua API surface callable from console

Launch dev instance and verify every `arch_*` Lua-mod namespace loads without error (stock engine, no `arch_engine.*` C++ tables).

```bash
scripts/run-dev.sh --dev --logfile /tmp/archlast-a1.log &
DEV_PID=$!
sleep 8

# In Lua console (paste one line at a time — mod names per implementation):
# = arch_camera.set_shoulder({x=8, y=4, z=-1})
# = arch_camera.get_offset(singleplayer)
# = arch_camera.lock_mode(singleplayer, "third")
# = arch_camera.enable_collision(true)
# = arch_anim.list_states()
# = arch_anim.set_state(singleplayer, "walk")
# = arch_anim.get_state(singleplayer)
# = arch_input.is_pressed(singleplayer, "move_forward")
# = arch_input.get_axis(singleplayer, "move_x")
# = arch_input.list_actions()
# = arch_player.get_state(singleplayer)
# = arch_player.get_velocity(singleplayer)
# = arch_entity.get_position(singleplayer)
# = arch_debug.frame_ms()

# After testing, kill dev server
kill $DEV_PID 2>/dev/null
wait $DEV_PID 2>/dev/null

# Verify no Lua errors in log
grep -iE 'moderror|lua error|attempt to index|arch_.*nil' /tmp/archlast-a1.log && echo "FAIL: Lua errors found" || echo "A1 PASS: All arch_* namespaces callable"
```

Pass: no Lua errors referencing `arch_*`, all console calls return values.

## A2. Camera collision test procedure

Verify Lua-mod third-person camera does not clip terrain in smoke world (stock engine).

```bash
scripts/run-dev.sh --smoke --third-person --logfile /tmp/archlast-a2.log
echo "Exit code: $?"

# Check Lua camera mod initialized
grep '\[ARCH:CAMERA\].*init\|\[ARCH:CAMERA\].*collision enabled' /tmp/archlast-a2.log && echo "Camera init OK" || echo "WARN: No camera init message"

# Check for camera errors or warnings
grep -i '\[ARCH:CAMERA\].*fail\|\[ARCH:CAMERA\].*error' /tmp/archlast-a2.log && echo "FAIL: Camera issues detected" || echo "A2 PASS: No camera collision failures"

# Manual verification (if GUI available):
# scripts/run-dev.sh --dev --third-person
# Walk player into wall → camera should pull closer (raycast pull-in)
# Walk through narrow corridor → camera should not clip geometry
```

Pass: exit code 0, no camera error/warning lines in log.

## A3. Animation transition observation

Verify Lua state-machine transitions are observable via HUD label or log.

```bash
scripts/run-dev.sh --smoke --third-person --logfile /tmp/archlast-a3.log

# Check built-in states registered (Lua mod logs each registration)
STATE_COUNT=$(grep -c '\[ARCH:ANIM\].*registered state' /tmp/archlast-a3.log)
echo "Registered states: $STATE_COUNT"
test "$STATE_COUNT" -ge 13 && echo "State count OK" || echo "FAIL: Expected ≥13 states, got $STATE_COUNT"

# Check transitions occurred during smoke test
grep '\[ARCH:ANIM\].*transition' /tmp/archlast-a3.log | head -10

# Check for animation errors
grep -i '\[ARCH:ANIM\].*error\|\[ARCH:ANIM\].*fail\|\[ARCH:ANIM\].*missing' /tmp/archlast-a3.log && echo "FAIL: Animation errors found" || echo "A3 PASS: Animation FSM operational"

# Manual verification (GUI):
# Walk, run, jump, fall → observe HUD state label changes
# Expected sequence: idle → walk → run → jump → fall → land → idle
```

Pass: ≥13 states registered, no animation errors in log.

## A4. Input mapping test

Verify Lua action map over `get_player_control` works (keyboard + stick axes via `movement_x/y`).

```bash
scripts/run-dev.sh --smoke --third-person --logfile /tmp/archlast-a4.log

# Check Lua input mod loaded its default action table
grep '\[ARCH:INPUT\].*actions registered' /tmp/archlast-a4.log && echo "Actions registered OK" || echo "FAIL: Default actions not registered"

# Check action count
ACTION_COUNT=$(grep -c '\[ARCH:INPUT\].*action' /tmp/archlast-a4.log)
echo "Input log lines: $ACTION_COUNT"
test "$ACTION_COUNT" -ge 1 && echo "Action log OK" || echo "FAIL: No input log lines"

# Check for input errors
grep -i '\[ARCH:INPUT\].*error\|\[ARCH:INPUT\].*fail' /tmp/archlast-a4.log && echo "FAIL: Input errors found" || echo "A4 PASS: Input system operational"

# Manual verification (GUI):
# Press W → character moves forward
# Press Aux1 → character sprints
# Push left stick → movement_x/movement_y non-zero; character moves
# In Lua console: = arch_input.is_pressed(singleplayer, "move_forward") while holding W → true
# = arch_input.get_axis(singleplayer, "move_y") while pushing stick → non-zero value
```

Pass: default actions registered, no input errors.

## A5. Build + smoke green

Stock upstream build and Lua-mod smoke test must pass with third-person mode active. No engine diff allowed.

```bash
# Engine pristine check (must pass before build)
git -C engine/archlast-luanti rev-parse HEAD  # expect c0e6812b1a4260bb25a1f606f70f55f4962bb97d
git -C engine/archlast-luanti status --short  # expect empty
test ! -d engine/archlast-luanti/src/archlast && echo "NO ARCHLAST DIR" || echo "FAIL: stale C++ dir"

# Stock build
scripts/build-linux.sh
BUILD_EXIT=$?
echo "Build exit code: $BUILD_EXIT"
test "$BUILD_EXIT" -eq 0 && echo "Build OK" || echo "FAIL: Build failed"

# Verify binary exists and is executable
test -x bin/archlast && echo "Binary OK" || echo "FAIL: bin/archlast missing or not executable"

# Smoke test with third-person (Lua mods active)
scripts/run-dev.sh --smoke --third-person
SMOKE_EXIT=$?
echo "Smoke exit code: $SMOKE_EXIT"
test "$SMOKE_EXIT" -eq 0 && echo "Smoke OK" || echo "FAIL: Smoke test failed"

# Full log check
grep -iE 'error\[main\]|segfault|moderror|assertion failed|core dump' /tmp/archlast-smoke.log && echo "FAIL: Critical errors in smoke log" || echo "A5 PASS: Stock build + Lua-mod smoke green"
```

Pass: engine pristine, build exit 0, smoke exit 0, no critical errors in log.

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