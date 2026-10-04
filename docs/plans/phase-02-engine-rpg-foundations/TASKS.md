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
## Task Group 0: Base Game `arch_base` — Merge Execution

Outcome: merged severed-history game at `game/arch_base/`, wired into `scripts/run-dev.sh`, provenance recorded in `dependencies/mods.lock`. Engine Groups A+ proceed against `devtest` independently.

### 0.1. Fork sources (locked, verified 2026-10-04)

- [ ] Record in `dependencies/mods.lock` at execution time (format below — do NOT write it now; no game code exists yet)

```text
[content.arch_base.mineclonia]
role = merge-base
url = https://codeberg.org/mineclonia/mineclonia.git
branch = main
sha = 85029767688df9c3ca95c9cff3b082c0a83f6704
license = GPLv3

[content.arch_base.voxelibre]
role = donor
url = https://git.minetest.land/VoxeLibre/VoxeLibre.git
branch = master
sha = 2373982f19f9b5d89cd2e3146ad7749876319e15
license = GPLv3

[content.arch_base.shader_preset]
role = first-class-mod
url = https://codeberg.org/TheUnknownHack3r/voxelibre_shader_preset_port.git
branch = master
sha = cf0cf6198ddd20b239ac9dbdb39e6facdd09e7b9
license = MIT
```

Source facts grounding the choice: Mineclonia HEAD `85029767` (2026-10-04, 222 mods, `first_mod = mcl_init` / `last_mod = _mcl_autogroup`, `min_minetest_version = 5.10`, `mods/COMPAT/` shims present); VoxeLibre HEAD `2373982f` (`version=0.93.0-SNAPSHOT`, 221 mods, no first/last lines); shader repo 4 files, game-agnostic `set_lighting` hook. ContentDB zips are fallback only: `6b12075e71.zip` (VoxeLibre 0.92.3, sha256 `51ea9242…b279d`), `9e68da81b8.zip` (shader, sha256 `bba1b104…c735f74`).

### 0.2. Severed-history fork procedure (execution phase)

- [ ] For each source: `git clone --depth 1 --branch <branch> <url> stage/<name>`, then `rm -rf stage/<name>/.git` — history severed at clone time
- [ ] Copy result into the merge workspace; NEVER `git remote add upstream`, NEVER pull later — one-way snapshot
- [ ] Order: stage Mineclonia → stage VoxeLibre → stage shader → merge per §0.3 → place at `game/arch_base/`

```bash
# Execution-phase commands (do NOT run now):
rm -rf /tmp/archstage && mkdir -p /tmp/archstage && cd /tmp/archstage
git clone --depth 1 --branch main https://codeberg.org/mineclonia/mineclonia.git base
git clone --depth 1 --branch master https://git.minetest.land/VoxeLibre/VoxeLibre.git donor_vl
git clone --depth 1 --branch master https://codeberg.org/TheUnknownHack3r/voxelibre_shader_preset_port.git donor_shader
git -C base rev-parse HEAD   # expect 85029767688df9c3ca95c9cff3b082c0a83f6704
git -C donor_vl rev-parse HEAD  # expect 2373982f19f9b5d89cd2e3146ad7749876319e15
git -C donor_shader rev-parse HEAD  # expect cf0cf6198ddd20b239ac9dbdb39e6facdd09e7b9
rm -rf base/.git donor_vl/.git donor_shader/.git
```

Pass: three SHAs match §0.1. Fail: stop — do NOT merge from drifted HEADs; re-pin the spec first.
### 0.3. Merge rules (locked)

- [ ] Start from Mineclonia tree verbatim (`game.conf` title → `Arch Base`, keep `first_mod`/`last_mod`, keep `min_minetest_version = 5.10`)
- [ ] Shared-name mods (173, measured by `mod.conf` dirname comparison): keep Mineclonia version by default; take VoxeLibre variant ONLY if its `init.lua` is strictly newer functionality with no Mineclonia-equivalent — record each taken donor in a `MERGE_NOTES.md` table `(mod, reason, vl-file-sha)`
- [ ] VoxeLibre-only mods (~48): adopt ONLY if no Mineclonia equivalent exists (name OR `description` match counts as equivalent); adopted mods move to the matching Mineclonia category dir (`CORE`/`PLAYER`/`MISC`/…), keeping their `mcl_`/`vl_` names
- [ ] Mineclonia-only mods (~49, incl. all of `mods/COMPAT/`): keep unconditionally — never delete a `COMPAT/` shim
- [ ] Modpack `modpack.conf` files: keep Mineclonia's (rewrite `description` to `Arch Base`)
- [ ] `menu/`, `settingtypes.txt`, `minetest.conf`: Mineclonia versions; append VoxeLibre-only settings keys if missing (dedupe by key)
- [ ] Shader mod: copy 4 files to `mods/arch_shader_preset/`; rewrite `mod.conf` to `name = arch_shader_preset`, `title = Arch Shader Preset`, add `depends = []`; keep `init.lua`, `README.md`, `LICENSE` byte-identical
- [ ] No `voxelibre_*` / `mineclone2` identifiers survive in dir names, `mod.conf` names, or `game.conf` (grep-verify in §0.5)
- [ ] Final layout:

```text
game/arch_base/
├── game.conf            # title = Arch Base, first_mod = mcl_init, last_mod = _mcl_autogroup
├── minetest.conf        # Mineclonia's + deduped VoxeLibre keys
├── settingtypes.txt     # Mineclonia's + deduped VoxeLibre keys
├── LICENSE.txt        # GPLv3 full text + MIT appendix for arch_shader_preset
├── MERGE_NOTES.md       # per-mod donor table + SHA pins
├── menu/                # Mineclonia's
└── mods/
    ├── COMPAT/          # kept whole
    ├── CORE/ PLAYER/ …  # merged categories
    └── arch_shader_preset/  # mod.conf, init.lua, README.md, LICENSE
```
### 0.4. Discovery wiring (execution phase)

- [ ] Game lives OUTSIDE the engine submodule, so export `LUANTI_GAME_PATH="$REPO_ROOT/game"` in `scripts/run-dev.sh` (and any smoke path) before launching `bin/archlast` — engine `getSubgamePathEnv` (`src/content/subgames.cpp:52-76`) picks it up, no engine change, no submodule symlink
- [ ] `run-dev.sh` also gains `--gameid <id>` (default `devtest`, preserves current behavior) and `--third-person` (warns until Group B lands); server line becomes `--gameid "$GAMEID"`
- [ ] No-arg path: `exec "$BIN"` stays; add `exec "$BIN" --gameid "$GAMEID"` when a non-default gameid is given without `--smoke`
- [ ] `dependencies/mods.lock` gains the `[content.arch_base.*]` block from §0.1 at execution time; `game/arch_base/LICENSE.txt` + `MERGE_NOTES.md` written during merge

Files touched at execution: `scripts/run-dev.sh` (tracked), `game/arch_base/**` (new, tracked in parent repo), `dependencies/mods.lock` (tracked).

### 0.5. Acceptance procedure A0 (execution phase)

- [ ] Placement: `game/arch_base/game.conf` exists, `title = Arch Base`, `mods/arch_shader_preset/mod.conf` exists with `name = arch_shader_preset`
- [ ] Identity purge: `grep -ri "voxelibre_shader_preset_port\|mineclone2" game/arch_base --include="*.conf" -l` returns nothing
- [ ] Provenance: `dependencies/mods.lock` contains `[content.arch_base.mineclonia]`, `[content.arch_base.voxelibre]`, `[content.arch_base.shader_preset]` with SHAs from §0.1
- [ ] Smoke: `scripts/run-dev.sh --smoke --gameid arch_base` exits 0 (60s readiness loop covers first-time mapgen); `/tmp/archlast-smoke.log` has `listening on`, no `ModError`/`could not be found`/`assertion failed`/`segfault`
- [ ] Regression: `scripts/run-dev.sh --smoke` (devtest default) still exits 0 — check log immediately after each run (single `$LOG` overwritten per run)

```bash
# Execution-phase verification (do NOT run now):
test -f game/arch_base/game.conf && grep -q "title = Arch Base" game/arch_base/game.conf && echo "GAME OK"
test -f game/arch_base/mods/arch_shader_preset/mod.conf && echo "SHADER OK"
grep -ri "voxelibre_shader_preset_port\|mineclone2" game/arch_base --include="*.conf" -l && echo "FAIL: stale ids" || echo "IDS CLEAN"
scripts/run-dev.sh --smoke --gameid arch_base
grep -iE 'moderror|could not be found|assertion failed|segfault' /tmp/archlast-smoke.log && echo "FAIL" || echo "A0 PASS"
```

Time estimate: spec is done (this plan); execution ~60–90 min later (clones ~310 MB, merge review dominates).

---


## Task Group A: Lua Capability Probe + Stock-API Mapping (30 min)

### A1. Camera API probe

- [ ] Update `engine-patches/camera/README.md` (notes only, no code)
- [ ] Document stock camera Lua API with modding-docs refs: `set_eye_offset` (L9679, clamp `[-10,-10,-5]`..`[10,15,5]`), `get_eye_offset` (L9688), `set_camera({mode})`/`get_camera()` (L9689-9698), `core.raycast` (L7249/L9835-9881), `core.line_of_sight` (L7243)
- [ ] Record limits vs old C++ plan: fixed F5 camera distance (offset magnitude + Lua lerp only), no engine smoothing/collision/target-lock — pull-in via per-tick raycast
- [ ] Lua approach: per-player offsets + `poll()` raycast head→desired camera pos, shrink on hit

```bash
mkdir -p engine-patches/camera
# Verify doc refs exist:
grep -n "set_eye_offset\|core.raycast\|line_of_sight" docs/archlast-luanti-moding-docs/modding-docs.md | head
```

Files touched: `engine-patches/camera/README.md` (notes only; no engine code)

### A2. Animation API probe

- [ ] Update `engine-patches/animation/README.md` (notes only, no code)
- [ ] Document stock animation Lua API: `set_animation(frame_range, frame_speed, frame_blend, frame_loop)` (L9161), `set_animation_frame_speed` (L9180), glTF `play_animation`/`update_animation`/`stop_animation` tracks (L9194-9224, 5.17+), `set_bone_override` radians + interpolation (L9078-9098; deprecated `set_bone_position` degrees L9064)
- [ ] Record limits: single-track `.b3d` via `set_animation`; frame ranges are model-specific (e.g. Mineclonia `stand` 0-79 in `mcl_armor/player.lua`)
- [ ] Lua approach: state machine maps game states → frame ranges with `frame_blend` crossfade; bone posing via absolute overrides

Files touched: `engine-patches/animation/README.md` (notes only; no engine code)

### A3. Input API probe

- [ ] Update `engine-patches/input/README.md` (notes only, no code)
- [ ] Document stock input Lua API: `get_player_control()` keys `up/down/left/right/jump/aux1/sneak/dig/place/LMB/RMB/zoom` + `movement_x`/`movement_y` incl. joystick (L9350-9368)
- [ ] Record limits: no raw keycodes, no gamepad-button enumeration — actions map to control fields; `movement_x/y` cover sticks
- [ ] Lua approach: action/axis tables + per-tick edge cache; profiles via `get_mod_storage` (L8129) or `get_worldpath` (L6150)

Files touched: `engine-patches/input/README.md` (notes only; no engine code)

### A4. Player controller probe

- [ ] Update `engine-patches/gameplay-api/README.md` (notes only, no code)
- [ ] Document stock movement Lua API: `get_velocity`/`add_velocity` (L8993-9006; players need `direct_velocity_on_players`), `set_physics_override`/`get_physics_override` incl. `speed*`/`jump`/`gravity`/`liquid_*`/`acceleration_*` (L9383-9431), `get_pos`/`set_pos`, `get_rotation` (L8983-8992/L9240)
- [ ] Record limits: states are derived (no engine state enum); knockback = `add_velocity`; swim/ground from node + velocity checks
- [ ] Lua approach: `core.register_globalstep` (L6607) FSM deriving walk/run/sprint/jump/fall/swim/dodge/knockback

Files touched: `engine-patches/gameplay-api/README.md` (notes only; no engine code)

### A5. Mapping review

- [ ] Each `engine-patches/*/README.md` has: probe result + modding-docs line refs, limits vs old C++ plan, Lua approach + Lua signatures, deferred gaps (never engine patches)
- [ ] Cross-reference: every `arch_*` Lua function maps to a stock API above

```bash
for dir in camera animation input gameplay-api; do
  echo "=== $dir ==="
  grep -c "modding-docs" engine-patches/$dir/README.md
  grep -c "arch_" engine-patches/$dir/README.md
done
```

Pass: each directory references modding-docs and names its `arch_*` Lua surface.

---

## Task Group B: Camera Lua Mod (90 min)

Parent-repo Lua game mod. No engine branches, no `src/archlast/`, no `arch_engine.*` C++ tables.

### B1. Mod scaffold

- [ ] Create `game/arch_base/mods/arch_camera/` (or chosen name): `mod.conf` (`name = arch_camera`, no engine dep), `init.lua`
- [ ] Public surface per README.md §Lua API surface: `arch_camera.set_offset/get_offset/set_shoulder/lock_mode/enable_collision/poll`

### B2. Offset + mode lock

- [ ] `set_offset` wraps `player:set_eye_offset(first, third_back, third_front)`; respect engine clamp `[-10,-10,-5]`..`[10,15,5]`
- [ ] `lock_mode` wraps `player:set_camera({mode="third"})`; `nil` resets (≥5.16)
- [ ] Log misuse via `core.log` `[ARCH:CAMERA]`

### B3. Collision pull-in

- [ ] `poll(player, dtime)` each tick: `core.raycast(head_pos, desired_cam_pos, false, false)`; on hit shrink third-person offset toward head; centered fallback after 3 consecutive hits
- [ ] Skip raycast when player stationary; single short ray per player per tick max

### B4. Collision test (smoke + manual)

- [ ] `scripts/run-dev.sh --smoke --third-person` exits 0, log clean
- [ ] Manual (GUI): walk into wall → view pulls in; narrow corridor → no sustained clip
- [ ] Check log: `grep '\[ARCH:CAMERA\]' /tmp/archlast-smoke.log | tail -20`

### B5. Mod commit

- [ ] Single logical commit, parent repo only

```bash
git add game/arch_base/mods/arch_camera
git commit -m "feat(game): third-person camera Lua mod with raycast pull-in (phase-2)"
```

Files touched: `game/arch_base/mods/arch_camera/**` (new, parent repo). Engine: none.

Time estimate: 90 min total for Group B.

---

## Task Group C: Input Lua Mod (60 min)

Parent-repo Lua game mod. No engine changes.

### C1. Mod scaffold

- [ ] Create `game/arch_base/mods/arch_input/` (or chosen name): `mod.conf`, `init.lua`
- [ ] Public surface per README.md §Lua API surface: `arch_input.is_pressed/just_pressed/just_released/get_axis/list_actions`

### C2. Action/axis map

- [ ] Actions map to `get_player_control()` field sets (e.g. `jump={jump}`, `forward={up}`, `sprint={aux1}`); axes read `movement_x`/`movement_y` ([-1,1], sticks included)
- [ ] Per-player previous-tick cache for just_pressed/just_released edges
- [ ] Deadzone param on `get_axis`

### C3. Profiles

- [ ] Persist via `core.get_mod_storage()` (load time) or `core.get_worldpath()` files — NOT a `game/arch_rpg/config/*.json` engine path
- [ ] Ship a Lua default table (7 actions: move_forward/back/left/right, jump, sprint, dodge)

### C4. Mod commit

```bash
git add game/arch_base/mods/arch_input
git commit -m "feat(game): input action map Lua mod over get_player_control (phase-2)"
```

Files touched: `game/arch_base/mods/arch_input/**` (new, parent repo). Engine: none.

Time estimate: 60 min total for Group C.

---

## Task Group D: Animation Lua Mod (90 min)

Parent-repo Lua game mod. No engine changes, no `feature/*` branches.

### D1. Mod scaffold

- [ ] Create `game/arch_base/mods/arch_anim/` (or chosen name): `mod.conf`, `init.lua`
- [ ] Public surface per README.md §Lua API surface: `arch_anim.register_state/set_state/get_state/set_speed/pose_bone/on_transition/list_states`

### D2. Lua state machine

- [ ] States map to model frame ranges (e.g. Mineclonia `stand` 0-79) with `frame_blend` crossfade via `player:set_animation(range, speed, blend, loop)`; speed-only changes via `set_animation_frame_speed`
- [ ] Drive from `get_player_control()` + velocity: idle/walk/run/sprint/jump/fall/land/attack/block/dodge/hit/death/cast
- [ ] Bone posing via `player:set_bone_override(bone, {rotation={vec=radians, absolute=true, interpolation=0.1}})`; validate bone names per model, warn don't crash
- [ ] Log transitions via `core.log` `[ARCH:ANIM]`

### D3. Mod commit

```bash
git add game/arch_base/mods/arch_anim
git commit -m "feat(game): animation state machine Lua mod (phase-2)"
```

Files touched: `game/arch_base/mods/arch_anim/**` (new, parent repo). Engine: none.

Time estimate: 90 min total for Group D.

---

## Task Group E: Player Lua Mod + Debug + Integration (60 min)

Parent-repo Lua game mod(s). No engine changes.

### E1. Mod scaffold

- [ ] Create `game/arch_base/mods/arch_player/` (locomotion) and fold entity/debug helpers into it or a small `arch_debug` mod
- [ ] Public surface per README.md §Lua API surface: `arch_player.get_state/set_move_speed/apply_knockback/is_grounded/get_velocity`, `arch_entity.get_position/get_rotation`, `arch_debug.set_state_label/frame_ms`

### E2. Derived locomotion states

- [ ] Derive walk/run/sprint/jump/fall/swim/dodge/knockback in `core.register_globalstep` from control + `get_velocity` + node checks; speed states via `set_physics_override({speed=...})`; knockback via `add_velocity`
- [ ] HUD state labels via `hud_add`/`hud_change`; frame timing via `core.get_us_time` deltas

### E3. Integration smoke test

- [ ] `scripts/run-dev.sh --smoke --third-person` launches with camera+animation+input+player mods active
- [ ] No Lua errors; debug label updates

```bash
scripts/run-dev.sh --smoke --third-person
echo "Exit code: $?"
grep -iE 'error|segfault|moderror' /tmp/archlast-smoke.log || echo "LOG CLEAN"
```

### E4. Mod commit

```bash
git add game/arch_base/mods/arch_player game/arch_base/mods/arch_debug
git commit -m "feat(game): player locomotion + debug Lua mods (phase-2)"
```

Files touched: `game/arch_base/mods/arch_player/**`, `game/arch_base/mods/arch_debug/**` (new, parent repo). Engine: none.

Time estimate: 60 min total for Group E.

---

## Task Group F: Verification — Stock Engine + Mods (30 min)

No merges (no engine branches exist). Verify the engine is pristine and the Lua mods pass.

### F1. Engine pristine check

```bash
git -C engine/archlast-luanti rev-parse HEAD  # expect c0e6812b1a4260bb25a1f606f70f55f4962bb97d
git -C engine/archlast-luanti status --short  # expect empty
test ! -d engine/archlast-luanti/src/archlast && echo "NO ARCHLAST DIR"
git -C engine/archlast-luanti branch -a | grep feature/ && echo "WARN: dangling branches" || echo "No feature branches"
```

### F2. Stock build + smoke

```bash
scripts/build-linux.sh  # stock upstream build
scripts/run-dev.sh --smoke --third-person
grep -iE 'error|segfault|moderror' /tmp/archlast-smoke.log || echo "LOG CLEAN"
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