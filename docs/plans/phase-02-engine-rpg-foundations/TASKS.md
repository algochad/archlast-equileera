# Phase 2 Tasks — Engine RPG Foundations (ordered)

Estimated: 4–8 hours on warm machine. Do in order. Stop at first red.
Every task has exact commands; no implicit steps.

## Prerequisites (5 min)

- [ ] Phase 1 `ACCEPTANCE.md` A1–A5 all green
- [ ] Working tree clean in repo root and `engine/archlast-luanti`
- [ ] Baseline frame time captured

```bash
# Verify Phase 1 acceptance
bash docs/plans/phase-01-fork-engine-prototype/ACCEPTANCE.md  # or run checks manually per that file
git status --short
git -C engine/archlast-luanti status --short

# Capture Phase 1 baseline for perf comparison
scripts/run-dev.sh --smoke --bench > /tmp/phase1-baseline.txt
cat /tmp/phase1-baseline.txt | grep -E 'frame_time_ms|fps'
```

Pass: no output from `git status`, baseline file contains numeric frame time.

---
## Task Group 0: Content Bootstrap — VoxeLibre + Shader Mod (30 min)

Do this before any engine work: gives the fork a playable default game and a shader preset.
Source zips are user-supplied ContentDB downloads — never fetched at build time.

### 0.1. Verify zips

- [ ] Both zips exist; sha256 matches recorded values
- [ ] Confirm package identity from contents (`mineclone2/game.conf` → VoxeLibre 0.92.3; `voxelibre_shader_preset_port/mod.conf` → name match)

```bash
sha256sum /home/algochad/Downloads/9e68da81b8.zip /home/algochad/Downloads/6b12075e71.zip
# Expected:
# bba1b1040a38114ead311f2834d6260add210b4fec845afc44da524840735f74  9e68da81b8.zip (shader mod, 2.0 KB)
# 51ea9242aabb1f29575abbfb599c79bcde9435616ea097c0582e11ac1b2b279d  6b12075e71.zip (VoxeLibre 0.92.3, 81 MB)
unzip -l /home/algochad/Downloads/6b12075e71.zip | head -5   # mineclone2/game.conf visible
unzip -l /home/algochad/Downloads/9e68da81b8.zip             # voxelibre_shader_preset_port/{mod.conf,init.lua}
```

Pass: hashes match. Fail: stop, re-download from ContentDB (`Wuzzy/mineclone2` 0.92.3, `QBSteve/voxelibre_shader_preset_port`).

### 0.2. Vendor game into fork

- [ ] Unzip `6b12075e71.zip` so `engine/archlast-luanti/games/mineclone2/game.conf` exists (title `VoxeLibre`)
- [ ] Directory name stays `mineclone2` — engine `normalizeGameId` maps dir name → gameid, no rename
- [ ] Confirm fork-commit exclusion: upstream `.gitignore` already has `/games/*` with only `!/games/devtest/` un-ignored, so `games/mineclone2` is ignored by default — verify, do not add new ignore rules unless verification fails

```bash
REPO_ROOT="$(pwd)"  # must be repo root
cd /tmp && rm -rf vlstage && mkdir vlstage && cd vlstage
unzip -o -q /home/algochad/Downloads/6b12075e71.zip
test -f mineclone2/game.conf && grep -q "title = VoxeLibre" mineclone2/game.conf && echo "GAME OK"
mkdir -p "$REPO_ROOT/engine/archlast-luanti/games"
cp -r mineclone2 "$REPO_ROOT/engine/archlast-luanti/games/mineclone2"
test -f "$REPO_ROOT/engine/archlast-luanti/games/mineclone2/game.conf" && echo "PLACED OK"
git -C "$REPO_ROOT/engine/archlast-luanti" check-ignore -v games/mineclone2/game.conf && echo "EXCLUDED FROM FORK COMMITS OK"
# Fallback only if the above prints nothing (i.e. not ignored):
# echo "games/mineclone2" >> "$REPO_ROOT/.git/modules/engine/archlast-luanti/info/exclude"
# (submodule `.git` is a gitfile; its real git dir lives under parent `.git/modules/`)
git -C "$REPO_ROOT/engine/archlast-luanti" status --short && echo "SUBMODULE CLEAN CHECK DONE"
```

Pass: `check-ignore` prints the matching `.gitignore` rule. Parent `git status --short` shows no `engine/archlast-luanti` modification (untracked-but-ignored content inside a submodule does not dirty the parent pointer).

Files touched: `engine/archlast-luanti/games/mineclone2/**` (untracked, ignored — never committed to fork or parent).
### 0.3. Vendor shader mod into game mods

- [ ] Unzip `9e68da81b8.zip`; copy `voxelibre_shader_preset_port/` into `engine/archlast-luanti/games/mineclone2/mods/`
- [ ] Why here, not repo-root `mods/` or `~/.luanti/mods`: game-bundled mods auto-load via `addGameMods`; addon paths need per-world `load_mod_<name>` opt-in
- [ ] Mod is game-agnostic (`init.lua` only calls `player:set_lighting` on join) — no edits needed

```bash
REPO_ROOT="$(pwd)"  # must be repo root
cd /tmp && rm -rf shstage && mkdir shstage && cd shstage
unzip -o -q /home/algochad/Downloads/9e68da81b8.zip
test -f voxelibre_shader_preset_port/mod.conf && echo "MOD OK"
cp -r voxelibre_shader_preset_port "$REPO_ROOT/engine/archlast-luanti/games/mineclone2/mods/"
test -f "$REPO_ROOT/engine/archlast-luanti/games/mineclone2/mods/voxelibre_shader_preset_port/init.lua" && echo "MOD PLACED OK"
```

Files touched: `engine/archlast-luanti/games/mineclone2/mods/voxelibre_shader_preset_port/**` (untracked, covered by parent ignore).
### 0.4. Record provenance

- [ ] Append ContentDB provenance to `dependencies/mods.lock` (package, version, sha256, licenses)

```bash
cat >> dependencies/mods.lock << 'EOF'

[content.mineclone2]
package = Wuzzy/mineclone2
version = 0.92.3
zip_sha256 = 51ea9242aabb1f29575abbfb599c79bcde9435616ea097c0582e11ac1b2b279d
license = GPLv3
path = engine/archlast-luanti/games/mineclone2

[content.voxelibre_shader_preset_port]
package = QBSteve/voxelibre_shader_preset_port
zip_sha256 = bba1b1040a38114ead311f2834d6260add210b4fec845afc44da524840735f74
license = MIT
path = engine/archlast-luanti/games/mineclone2/mods/voxelibre_shader_preset_port
EOF
```

Files touched: `dependencies/mods.lock` (tracked, committed).

### 0.5. Wire `--gameid` / `--third-person` into `run-dev.sh`, then smoke reference game

- [ ] Extend `scripts/run-dev.sh` arg parsing: `--gameid <id>` (default `devtest` — preserves current behavior), `--third-person` (warn until Group B lands, then standard smoke)
- [ ] No-arg path stays `exec "$BIN"`; add `exec "$BIN" --gameid "$GAMEID"` when a non-default gameid is given without `--smoke`
- [ ] Server launch line becomes `--gameid "$GAMEID"` instead of hardcoded `devtest`
- [ ] Smoke both games; readiness loop (already 60s) covers first-time VoxeLibre mapgen

```bash
# After editing scripts/run-dev.sh:
bash -n scripts/run-dev.sh && echo "SYNTAX OK"
scripts/run-dev.sh --smoke                     # regression: devtest still green
scripts/run-dev.sh --smoke --gameid mineclone2 # reference game smoke
# VL log check (same $LOG=/tmp/archlast-smoke.log; check right after each run — second run overwrites):
grep -iE 'moderror|could not be found|assertion failed|segfault' /tmp/archlast-smoke.log && echo "FAIL: content errors" || echo "VL LOG CLEAN"
```

Pass: devtest smoke unchanged, mineclone2 smoke reaches `listening on`, both logs clean.

Files touched: `scripts/run-dev.sh` (tracked, committed with Phase 2 work).

Time estimate: 30 min total for Group 0.

---


## Task Group A: Lua Capability Probe + Gap Documentation (30 min)

### A1. Camera API probe

- [ ] Create `engine-patches/camera/README.md`
- [ ] Document existing Luanti camera Lua API (`set_camera_mode`, `get_camera_pos`, etc.)
- [ ] Test each in Lua console against Phase 2 requirements
- [ ] List gaps: collision raycast, shoulder offset, smoothing, target-lock

```bash
mkdir -p engine-patches/camera
# Launch dev instance for interactive Lua probing
scripts/run-dev.sh --dev
# In Lua console:
#   /lua local ok = pcall(function() core.camera.set_mode(1) end); print("set_mode:", ok)
#   /lua print(core.camera.get_pos())
#   /lua print(core.camera.get_look_dir())
# Record results, then exit
echo "Camera probe complete" >> engine-patches/camera/README.md
```

Files touched: `engine-patches/camera/README.md`

### A2. Animation API probe

- [ ] Create `engine-patches/animation/README.md`
- [ ] Document existing `GenericCAO` animation Lua API
- [ ] Test single-animation playback, speed control, bone access
- [ ] List gaps: state machine, crossfade blending, tag-driven transitions, attachment points

```bash
mkdir -p engine-patches/animation
scripts/run-dev.sh --dev
# In Lua console:
#   /lua local ent = core.get_player_by_name("singleplayer")
#   /lua ent:set_animation({x=0,y=80}, 30, 0, true)
#   /lua print(ent:get_bone_position("Head"))
echo "Animation probe complete" >> engine-patches/animation/README.md
```

Files touched: `engine-patches/animation/README.md`

### A3. Input API probe

- [ ] Create `engine-patches/input/README.md`
- [ ] Document existing key binding system
- [ ] Test action abstraction feasibility with current API
- [ ] List gaps: action mapping, axis support, gamepad, profiles

```bash
mkdir -p engine-patches/input
scripts/run-dev.sh --dev
# In Lua console:
#   /lua print(core.settings:get("keymap_forward"))
#   /lua print(type(core.get_key_press))
echo "Input probe complete" >> engine-patches/input/README.md
```

Files touched: `engine-patches/input/README.md`

### A4. Player controller probe

- [ ] Create `engine-patches/gameplay-api/README.md`
- [ ] Document existing `PlayerSAO` movement/state API
- [ ] List gaps: sprint/dodge/knockback/swim states, server-authoritative reconciliation

```bash
mkdir -p engine-patches/gameplay-api
scripts/run-dev.sh --dev
# In Lua console:
#   /lua local p = core.get_player_by_name("singleplayer")
#   /lua print(p:get_velocity())
#   /lua print(p:get_physics_override())
echo "Player probe complete" >> engine-patches/gameplay-api/README.md
```

Files touched: `engine-patches/gameplay-api/README.md`

### A5. Gap summary review

- [ ] Each `engine-patches/*/README.md` has: probe result, gap list, chosen approach, C++ signatures, Lua signatures, conflict risk
- [ ] Cross-reference gaps against README.md API surface — every exposed function addresses a documented gap

```bash
for dir in camera animation input gameplay-api; do
  echo "=== $dir ==="
  grep -c "gap\|Gap\|GAP" engine-patches/$dir/README.md
  grep -c "arch_engine" engine-patches/$dir/README.md
done
```

Pass: each directory has ≥1 gap mention and ≥1 `arch_engine` reference.

---

## Task Group B: Camera System (90 min)

Branch: `feature/camera`

### B1. Branch setup

- [ ] Create feature branch from `main`

```bash
git -C engine/archlast-luanti checkout main
git -C engine/archlast-luanti pull origin main
git -C engine/archlast-luanti checkout -b feature/camera
```

### B2. CameraManager C++ implementation

- [ ] `src/archlast/camera_manager.h` — class declaration with collision, offset, smoothing
- [ ] `src/archlast/camera_manager.cpp` — raycast-based collision, lerp smoothing, yaw/pitch clamping
- [ ] Shoulder offset applied before collision ray origin
- [ ] Target-lock hook: when entity_id set, yaw tracks entity position

```bash
# Files to create/edit (exact paths):
touch engine/archlast-luanti/src/archlast/camera_manager.h
touch engine/archlast-luanti/src/archlast/camera_manager.cpp
# Implement per engine-patches/camera/README.md signatures
# Build incrementally:
scripts/build-linux.sh 2>&1 | tail -20
```

Files touched: `engine/archlast-luanti/src/archlast/camera_manager.{h,cpp}`

### B3. Camera Lua bindings

- [ ] Register `arch_engine.camera` table in Lua mod API
- [ ] Bind all functions from README.md API surface
- [ ] Validate argument types, clamp ranges, log misuse via `[ARCH-ENGINE:CAMERA]`

```bash
# Binding registration typically in src/archlast/lua_bindings.cpp or similar
grep -rn "arch_engine" engine/archlast-luanti/src/archlast/ || echo "No bindings yet"
scripts/build-linux.sh 2>&1 | tail -20
```

Files touched: `engine/archlast-luanti/src/archlast/lua_bindings_camera.cpp` (or equivalent)

### B4. Camera collision test world

- [ ] Create minimal test world with walls, ceiling, tight corridor
- [ ] Verify no terrain clipping at default distance=5, offset={0.8,0.3,0}
- [ ] Verify fallback to centered camera after 3 consecutive ray hits

```bash
scripts/run-dev.sh --dev --world test_camera
# Manual test: walk into wall, verify camera pulls in
# Walk through narrow corridor, verify no clip
# Check log:
grep '\[ARCH-ENGINE:CAMERA\]' /tmp/archlast-dev.log | tail -20
```

### B5. Camera branch commit + squash prep

- [ ] All camera changes in single logical commit
- [ ] Commit message: `feat(engine): third-person camera with collision and shoulder offset (phase-2)`
- [ ] No unrelated files changed

```bash
git -C engine/archlast-luanti add src/archlast/camera_manager.* src/archlast/lua_bindings_camera.*
git -C engine/archlast-luanti diff --cached --stat
git -C engine/archlast-luanti commit -m "feat(engine): third-person camera with collision and shoulder offset (phase-2)"
```

Time estimate: 90 min total for Group B.

---

## Task Group C: Input Abstraction (60 min)

Branch: `feature/input` (from `main`, parallel-safe with camera)

### C1. Branch setup

```bash
git -C engine/archlast-luanti checkout main
git -C engine/archlast-luanti checkout -b feature/input
```

### C2. InputActionMap C++ implementation

- [ ] `src/archlast/input_action_map.h/cpp` — action→keys/buttons mapping, axis with deadzone
- [ ] Load/save JSON profiles
- [ ] SDL2 gamepad DB integration for Linux

```bash
touch engine/archlast-luanti/src/archlast/input_action_map.h
touch engine/archlast-luanti/src/archlast/input_action_map.cpp
scripts/build-linux.sh 2>&1 | tail -20
```

Files touched: `engine/archlast-luanti/src/archlast/input_action_map.{h,cpp}`

### C3. Input Lua bindings

- [ ] Register `arch_engine.input` table
- [ ] Bind `is_action_pressed`, `is_action_just_pressed`, `is_action_just_released`, `get_axis`, `bind_action`, `bind_axis`, `load_profile`, `save_profile`, `get_actions`
- [ ] Default profile at `game/arch_rpg/config/input_default.json`

```bash
mkdir -p game/arch_rpg/config
# Create default profile JSON
cat > game/arch_rpg/config/input_default.json << 'EOF'
{
  "actions": {
    "move_forward": {"keys": ["KEY_KEY_W"], "gamepad": []},
    "move_back": {"keys": ["KEY_KEY_S"], "gamepad": []},
    "move_left": {"keys": ["KEY_KEY_A"], "gamepad": []},
    "move_right": {"keys": ["KEY_KEY_D"], "gamepad": []},
    "jump": {"keys": ["KEY_SPACE"], "gamepad": ["a"]},
    "sprint": {"keys": ["KEY_LSHIFT"], "gamepad": ["leftstick"]},
    "dodge": {"keys": ["KEY_LCONTROL"], "gamepad": ["b"]}
  },
  "axes": {
    "move_x": {"positive": "move_right", "negative": "move_left", "gamepad_axis": "left_stick_x"},
    "move_y": {"positive": "move_forward", "negative": "move_back", "gamepad_axis": "left_stick_y"}
  }
}
EOF
scripts/build-linux.sh 2>&1 | tail -20
```

Files touched: `engine/archlast-luanti/src/archlast/lua_bindings_input.cpp`, `game/arch_rpg/config/input_default.json`

### C4. Input branch commit

```bash
git -C engine/archlast-luanti add src/archlast/input_action_map.* src/archlast/lua_bindings_input.*
git -C engine/archlast-luanti add ../../game/arch_rpg/config/input_default.json
git -C engine/archlast-luanti commit -m "feat(engine): input action map with gamepad support (phase-2)"
```

Time estimate: 60 min total for Group C.

---

## Task Group D: Animation State Machine (90 min)

Branch: `feature/animation` (from `main` after `feature/camera` merged)

### D1. Merge camera first

```bash
git -C engine/archlast-luanti checkout main
git -C engine/archlast-luanti merge --squash feature/camera
git -C engine/archlast-luanti commit -m "feat(engine): third-person camera with collision and shoulder offset (phase-2)"
git -C engine/archlast-luanti checkout -b feature/animation
```

### D2. AnimationStateMachine C++ implementation

- [ ] `src/archlast/animation_state_machine.h/cpp` — state registry, tag-driven transitions, crossfade blending
- [ ] Built-in states: idle, walk, run, sprint, jump, fall, land, attack, block, dodge, hit, death, cast
- [ ] Dual-animation playback for crossfade (≤2 concurrent per entity)
- [ ] Transition callback dispatch to Lua

```bash
touch engine/archlast-luanti/src/archlast/animation_state_machine.h
touch engine/archlast-luanti/src/archlast/animation_state_machine.cpp
scripts/build-linux.sh 2>&1 | tail -20
```

Files touched: `engine/archlast-luanti/src/archlast/animation_state_machine.{h,cpp}`

### D3. Model attachment point system

- [ ] Bone registry: configurable slot→bone mapping per model
- [ ] Slots: weapon, offhand, head, chest, legs, feet
- [ ] Validation: warn on missing bone, don't crash

```bash
# Attachment config loaded from model metadata or Lua registration
# Implementation in animation_state_machine.cpp or separate attachment_manager.cpp
scripts/build-linux.sh 2>&1 | tail -20
```

Files touched: `engine/archlast-luanti/src/archlast/attachment_manager.{h,cpp}` (if separate)

### D4. Animation Lua bindings

- [ ] Register `arch_engine.animation` table
- [ ] Bind `register_state`, `set_state`, `get_state`, `set_speed_multiplier`, `trigger_event`, `on_transition`, `list_states`
- [ ] Log transitions via `[ARCH-ENGINE:ANIM]`

```bash
scripts/build-linux.sh 2>&1 | tail -20
```

Files touched: `engine/archlast-luanti/src/archlast/lua_bindings_animation.cpp`

### D5. Animation branch commit

```bash
git -C engine/archlast-luanti add src/archlast/animation_state_machine.* src/archlast/attachment_manager.* src/archlast/lua_bindings_animation.*
git -C engine/archlast-luanti commit -m "feat(engine): animation state machine with attachment points (phase-2)"
```

Time estimate: 90 min total for Group D.

---

## Task Group E: Player Controller + Entity Helpers + Integration (60 min)

Branch: `feature/rpg-api` (from `main` after camera+animation+input merged)

### E1. Merge prior branches

```bash
git -C engine/archlast-luanti checkout main
git -C engine/archlast-luanti merge --squash feature/animation
git -C engine/archlast-luanti commit -m "feat(engine): animation state machine with attachment points (phase-2)"
git -C engine/archlast-luanti merge --squash feature/input
git -C engine/archlast-luanti commit -m "feat(engine): input action map with gamepad support (phase-2)"
git -C engine/archlast-luanti checkout -b feature/rpg-api
```

### E2. CharacterController C++ implementation

- [ ] `src/archlast/character_controller.h/cpp` — state enum (walk/run/sprint/jump/fall/swim/dodge/knockback)
- [ ] Server-authoritative state with client prediction
- [ ] Knockback: direction + force + duration, interrupts current state
- [ ] Swim depth threshold, grounded detection

```bash
touch engine/archlast-luanti/src/archlast/character_controller.h
touch engine/archlast-luanti/src/archlast/character_controller.cpp
scripts/build-linux.sh 2>&1 | tail -20
```

Files touched: `engine/archlast-luanti/src/archlast/character_controller.{h,cpp}`

### E3. Entity helpers + render debug Lua bindings

- [ ] `arch_engine.entity.*` bindings
- [ ] `arch_engine.render.*` bindings with debug overlay toggles
- [ ] `arch_engine.player.*` bindings wrapping CharacterController

```bash
scripts/build-linux.sh 2>&1 | tail -20
```

Files touched: `engine/archlast-luanti/src/archlast/lua_bindings_entity.cpp`, `lua_bindings_render.cpp`, `lua_bindings_player.cpp`

### E4. Integration smoke test

- [ ] `scripts/run-dev.sh --smoke --third-person` launches with camera+animation+input active
- [ ] No Lua errors, no C++ crashes
- [ ] Debug overlay shows state labels

```bash
scripts/run-dev.sh --smoke --third-person
echo "Exit code: $?"
grep -iE 'error|segfault|moderror' /tmp/archlast-smoke.log || echo "LOG CLEAN"
```

### E5. RPG-API branch commit

```bash
git -C engine/archlast-luanti add src/archlast/character_controller.* src/archlast/lua_bindings_entity.* src/archlast/lua_bindings_render.* src/archlast/lua_bindings_player.*
git -C engine/archlast-luanti commit -m "feat(engine): player controller, entity helpers, render debug (phase-2)"
```

Time estimate: 60 min total for Group E.

---

## Task Group F: Final Merge + Performance Verification (30 min)

### F1. Squash-merge rpg-api to main

```bash
git -C engine/archlast-luanti checkout main
git -C engine/archlast-luanti merge --squash feature/rpg-api
git -C engine/archlast-luanti commit -m "feat(engine): player controller, entity helpers, render debug (phase-2)"
```

### F2. Delete feature branches

```bash
git -C engine/archlast-luanti branch -d feature/camera feature/animation feature/input feature/rpg-api
git -C engine/archlast-luanti branch -a | grep feature/ && echo "WARN: dangling branches" || echo "All feature branches cleaned"
```

### F3. Performance benchmark

- [ ] Run benchmark, compare to Phase 1 baseline
- [ ] Regression ≤10%

```bash
scripts/run-dev.sh --smoke --bench > /tmp/phase2-result.txt
# Compare:
paste /tmp/phase1-baseline.txt /tmp/phase2-result.txt | grep -E 'frame_time_ms|fps'
# Manual check: if phase2 frame_time <= phase1_frame_time * 1.10 → PASS
```

### F4. Full acceptance run

```bash
# Run all ACCEPTANCE.md checks
bash -x docs/plans/phase-02-engine-rpg-foundations/ACCEPTANCE.md 2>&1 | tee /tmp/phase2-acceptance.log
```

Time estimate: 30 min total for Group F.

---

## Out of scope (defer, do not start)

- RPG stats, classes, skills, combat math (Phase 4).
- Item/equipment system (Phase 5+).
- Multiplayer animation sync beyond server-authoritative state.
- Windows/macOS-specific fixes.
- Final art assets or animation authoring.
- CI pipeline integration (separate infrastructure task).