# Phase 2 — Engine RPG Foundations (Lua-mod approach, no engine C++ changes)

Base-game mechanics core (`game/arch_base/`, planned here from Mineclonia + VoxeLibre + shader preset) plus **Lua-mod** third-person camera, character controller, animation state machine, and input abstraction built only on the stock Luanti Lua API. The engine submodule stays pinned at upstream `c0e6812b1` (5.17.0) with zero C++ diff; previous `src/archlast/` work has been reverted. Later phases consume the Lua `arch_*` game-mod APIs.

## Goal

Two tracks, in order:

1. **Base game `arch_base`** (mechanics core, executed in this phase): fork Mineclonia + VoxeLibre + shader-preset sources with severed history into `game/arch_base/`, merge to a single Mineclonia-based tree, ship the shader preset as a first-class game mod. This becomes the mechanics system every later phase builds on.
2. **RPG foundations as Lua game mods**: usable-from-Lua third-person player experience — camera offsets via `set_eye_offset` with `core.raycast` collision pull-in; locomotion states via `get_player_control` + `get_velocity` + `set_physics_override`; animation states via `set_animation`/`play_animation` + `set_bone_override`; action-mapped input over `get_player_control` (+ `movement_x`/`movement_y` sticks). All gameplay code lives in `game/arch_base/mods/`; engine internals remain untouched upstream code.

No implementation of the base-game merge in this phase — Group 0 below plans it decision-complete; execution happens later.

## Non-goals

- RPG stats, attributes, classes, skills, spells (Phase 4).
- Base-game merge execution (planned in Group 0, implemented later — no `game/arch_base/` code in this phase).
- Combat damage calculation, hit registration, status effects (Phase 4).
- Item/equipment system, inventory UI (Phase 5+).
- Rendering pipeline overhaul, shader authoring, post-processing.
- Final art assets, animations, sounds (placeholder only).
- Multiplayer synchronization of animation/camera state (server-authoritative movement only).
- Windows/macOS build fixes beyond what Phase 1 already supports.

## Entry criteria

All must be green before starting any Phase 2 task:

1. Phase 1 `ACCEPTANCE.md` A1–A5 pass.
2. `scripts/build-linux.sh` exits 0 on clean checkout.
3. `scripts/run-dev.sh --smoke` exits 0, log clean per Phase 1 A4.
4. `engine/archlast-luanti` submodule pointer matches `dependencies/mods.lock`.
5. No uncommitted changes in `engine/archlast-luanti` or repo root.

If any entry criterion fails, stop and fix Phase 1 first.

## Architecture decisions (Lua-only; stock API mapping)

Each feature gets an explicit **Lua probe → Lua implementation** decision recorded in its `engine-patches/<feature>/README.md` (directory name is historical — no C++ is patched). Reference: `docs/archlast-luanti-moding-docs/modding-docs.md`.

| Feature | Stock Lua API (doc refs) | Lua approach |
|---|---|---|
| Camera offsets | `set_eye_offset(first, third_back, third_front)` (L9679), `get_eye_offset` (L9688) | Per-player offsets; shoulder feel via small X/Y third-person values within clamp `[-10,-10,-5]`..`[10,15,5]` |
| Camera mode lock | `set_camera({mode})` / `get_camera()` (L9689-9698); modes `any`/`first`/`third`/`third_front` | Lock or force third-person per gameplay state; `nil` (≥5.16) resets to defaults |
| Camera collision | `core.raycast(pos1, pos2, objects, liquids)` / `Raycast(...)` (L7249, L9835-9881), `core.line_of_sight` (L7243) | Each tick raycast head→desired camera pos; pull `set_eye_offset` in on hit (fallback: centered offset after consecutive hits) |
| Locomotion states | `get_player_control()` incl. `movement_x`/`movement_y` (L9350-9368), `get_velocity`/`add_velocity` (L8993-9006, needs `direct_velocity_on_players` 5.4+), `set_physics_override`/`get_physics_override` (L9383-9431) | Lua FSM in `core.register_globalstep` (L6607): sprint=dodge via speed multipliers, knockback via `add_velocity`, swim/ground from node + velocity checks |
| Animation states | old `set_animation(frame_range, frame_speed, frame_blend, frame_loop)` + `set_animation_frame_speed` (L9159-9183); new `play_animation`/`update_animation`/`stop_animation`/`get_animations` tracks (L9185-9225, 5.17+); bones `set_bone_override`/`get_bone_override(s)` in radians (L9078-9098, deprecated `set_bone_position` degrees L9064-9077) | Lua state machine maps game states → frame ranges (e.g. Mineclonia `stand` 0-79) with `frame_blend` crossfade; bone posing via absolute overrides with `interpolation` seconds |
| Input action map | `get_player_control()` keys `up/down/left/right/jump/aux1/sneak/dig/place/LMB/RMB/zoom` + `movement_x/y` incl. joystick (L9350-9368) | Lua action/axis tables over control fields; `movement_x/y` cover sticks; profiles persisted via mod storage (`get_mod_storage`, L8129) or world files (`get_worldpath`, L6150) |
| Entity queries | `get_pos`/`set_pos`, `get_rotation`/`set_rotation`, `get_look_dir` (L8983-8992, L9240-9296) | Thin Lua wrappers; no component system in Phase 2 (`has_component` returns false / deferred) |
| Render/debug + timing | `hud_add`/`hud_change`/`hud_remove` (L9432-9438), `core.add_particle(s)` (L7984-8006), `core.get_us_time` (L4683), `core.log` (L6490), join/leave callbacks (L6682-6688) | HUD state labels, particle markers, us-time frame timing; `core.log` with `[ARCH-*]` tags |

**Rule**: stock Lua API only. If a requirement cannot be met with the API above, record it as a deferred gap in the feature README — never patch the engine.

## Lua API surface (game mods, `arch_*` namespace)

All functions live in game Lua mods under `game/arch_base/mods/` (mod name TBD). Tables passed by reference; vectors use `{x,y,z}` tables. Defaults shown after `=`. The old `arch_engine.*` C++ namespace is retired — same capability, pure Lua.

### `arch_camera` (Lua; `set_eye_offset` + raycast)

```lua
arch_camera.set_offset(player, first, third_back, third_front)  -- thin wrapper over player:set_eye_offset
arch_camera.get_offset(player) -> first, third_back, third_front -- via player:get_eye_offset
arch_camera.set_shoulder(offset: {x,y,z} = {x=8, y=4, z=-1})     -- stored preset, applied as third_back
arch_camera.lock_mode(player, mode)                             -- player:set_camera({mode="third"}) / nil reset
arch_camera.enable_collision(enable: boolean = true)            -- raycast pull-in on/off
arch_camera.poll(player, dtime)                                 -- per-tick: core.raycast head→desired, shrink offset on hit
```

Limits (engine-enforced): third-person offsets clamped to `[-10,-10,-5]`..`[10,15,5]`; engine F5 camera distance is fixed — "distance/zoom/smoothing" are approximated by offset magnitude + per-tick lerp in Lua. No terrain clip: pull-in on first ray hit; centered fallback after consecutive hits.

### `arch_anim` (Lua; `set_animation` FSM + `set_bone_override`)

```lua
arch_anim.register_state(name: string, config: {
    range: {x=start_frame, y=end_frame},  -- model frames, e.g. Mineclonia stand 0-79
    loop: boolean = true,
    speed: number = 30,                   -- frame_speed
    blend: number = 0.15,                 -- frame_blend seconds crossfade
})
arch_anim.set_state(player, state_name: string)                 -- player:set_animation(range, speed, blend, loop)
arch_anim.get_state(player) -> string
arch_anim.set_speed(player, mult: number)                       -- player:set_animation_frame_speed
arch_anim.pose_bone(player, bone, rot_rad_vec)                  -- player:set_bone_override({rotation={vec, absolute=true, interpolation=0.1}})
arch_anim.on_transition(callback: function(player, from, to))
arch_anim.list_states() -> string[]
```

Built-in states driven from `get_player_control` + velocity: `idle`, `walk`, `run`, `sprint`, `jump`, `fall`, `land`, `attack`, `block`, `dodge`, `hit`, `death`, `cast`. (glTF `play_animation` tracks available on 5.17+ clients; `.b3d`/`.x` use single track via `set_animation`.)

### `arch_player` (Lua; control + velocity + physics overrides)

```lua
arch_player.get_state(player) -> string                          -- walk|run|sprint|jump|fall|swim|dodge|knockback (derived)
arch_player.set_move_speed(player, state: string, mult: number)  -- player:set_physics_override({speed=...})
arch_player.apply_knockback(player, direction: {x,y,z}, force: number)  -- player:add_velocity
arch_player.is_grounded(player) -> boolean                       -- node-below + velocity check
arch_player.get_velocity(player) -> {x,y,z}
```

### `arch_input` (Lua; `get_player_control` action/axis map)

```lua
arch_input.is_pressed(player, action: string) -> boolean        -- action = control-field set, e.g. jump={jump}, forward={up}
arch_input.just_pressed(player, action: string) -> boolean      -- edge vs previous tick cache
arch_input.just_released(player, action: string) -> boolean
arch_input.get_axis(player, axis: string) -> number              -- [-1.0, 1.0]; move_x/y read movement_x/movement_y (sticks included)
arch_input.list_actions() -> string[]
```

Profiles persisted via `core.get_mod_storage()` or `core.get_worldpath()` files (no `game/arch_rpg/config/input_default.json` engine path).

### `arch_entity` / `arch_debug` (Lua; wrappers + HUD)

```lua
arch_entity.get_position(obj) -> {x,y,z}                        -- obj:get_pos
arch_entity.get_rotation(obj) -> {x,y,z}                        -- obj:get_rotation (radians, Z-X-Y order)
arch_debug.set_state_label(player, text)                        -- player:hud_add/hud_change text element
arch_debug.frame_ms() -> number                                 -- core.get_us_time deltas
```

Overlays: state labels via HUD text, camera-ray markers via particles; frame timing via `get_us_time`. No C++ debug draw.

## Mod plan (no engine branches)

No engine branches. Work lands as Lua game mods in the parent repo (one commit per mod, `feat(game): ... (phase-2)`). Suggested split (implementer decides final mod names):

| Order | Mod (under `game/arch_base/mods/`) | Scope | Depends on |
|---|---|---|---|
| 1 | `arch_camera` | Eye offsets, mode lock, raycast collision pull-in, smoothing lerp | nothing (uses stock API) |
| 2 | `arch_input` | Action/axis map over `get_player_control`, profiles via mod storage | nothing |
| 3 | `arch_anim` | Lua animation FSM, frame ranges, bone posing | `arch_input` (reads control state) |
| 4 | `arch_player` + debug | Derived locomotion states, physics multipliers, knockback, HUD labels | `arch_input` + `arch_anim` |

No squash-merges, no engine `main` — parent repo commits only.

## Design-notes layout

Each notes directory contains probe results + Lua mapping only — no code, no C++ sketches. Lua implementation lives in `game/arch_base/mods/`.

```text
engine-patches/                  # historical name; no C++ is patched
├── camera/
│   ├── README.md          # Lua probe results, stock-API mapping, limits
│   └── collision-notes.md # Raycast strategy (core.raycast vs line_of_sight), terrain vs entity filtering
├── animation/
│   ├── README.md          # Lua FSM design, state taxonomy, frame ranges + blend
│   └── bone-registry.md   # Bone names per model (e.g. Arm_Left_Pitch_Control), override conventions
├── input/
│   ├── README.md          # Action map schema over get_player_control fields
│   └── profiles.md        # Mod-storage / world-file persistence format
└── gameplay-api/
    ├── README.md          # Derived locomotion-state diagram, knockback contract
    └── entity-helpers.md  # Wrapper patterns, deferred-component notes
```

Each `README.md` MUST contain: (1) Lua capability probe result with modding-docs line refs, (2) limits vs old C++ plan, (3) chosen Lua approach with rationale, (4) Lua module/function signatures, (5) deferred gaps (never engine patches).

## Performance budget

- Frame time regression vs Phase 1 baseline: **≤10%** measured by `scripts/run-dev.sh --smoke --bench`.
- Camera raycast: one short ray per player per tick (`core.raycast` early-out on terrain); skip when standing still.
- Animation FSM: table lookups only per globalstep; `set_animation` only on state change (no per-frame re-set).
- Input: reads already-polled `get_player_control()` table; cache edge states per player.
- Memory: no new per-frame allocations in hot paths; reuse vector tables.

Baseline captured at Phase 2 start:

```bash
scripts/run-dev.sh --smoke --bench > /tmp/phase1-baseline.txt
```

Every mod commit re-runs benchmark; revert if regression exceeds budget.

## Risks and mitigations (Lua-only)

| Risk | Impact | Mitigation |
|---|---|---|
| Engine F5 camera distance fixed; no true zoom | Can't replicate C++ `set_distance` 1:1 | Approximate with offset magnitude + Lua lerp; document as known limit |
| `get_player_control` lacks raw keycodes/gamepad buttons | No arbitrary rebinding | Map actions to control fields; `movement_x/y` cover sticks; document rebinding gap |
| Per-tick Lua raycast cost | Frame cost on busy servers | One short ray per player per tick max; `line_of_sight` fast path when entities irrelevant |
| Lua GC pressure from per-frame vector tables | Frame stutters | Reuse cached vector tables in `poll()` hot paths |
| Shoulder offset clips in tight corridors | Bad UX | Raycast includes offset origin; fallback to centered offset on repeated hits |
| State machine races with lag corrections | Visual desync | Server-authoritative derived state; forced `set_animation` without blend on teleport/respawn |
| Upstream Lua API drift | Mod breaks on engine update | Pin engine commit `c0e6812b1`; modding-docs line refs re-verified at implementation time |

## Logging conventions

All Phase 2 Lua log lines use prefixed tags for grep-ability (via `core.log`):

- `[ARCH:CAMERA]` — offset/mode/collision messages
- `[ARCH:ANIM]` — state transitions, errors
- `[ARCH:INPUT]` — profile load, bind failures
- `[ARCH:PLAYER]` — derived state changes
- `[ARCH-RPG:*]` — reserved for Phase 3+ gameplay mods (NOT used in this phase)

Log level: `action` for state changes, `warning` for fallbacks/recoveries, `error` for API misuse. Never log per-frame data.

## Base game `arch_base` (mechanics core — executed in this phase)

The product's mechanics system is a merged single game hosted in this repo. Three upstream sources, all severed-history forks (no `upstream` remote, no future pulls — one-way snapshot; `dependencies/mods.lock` records exact SHAs for provenance):

| # | Source | Branch / SHA (verified 2026-10-04) | Role in merge | License |
|---|---|---|---|---|
| 1 | [`mineclonia/mineclonia`](https://codeberg.org/mineclonia/mineclonia.git) | `main` @ `85029767` (HEAD, 2026-10-04) | **Merge base.** 222 mods, `title = Mineclonia`, declares `first_mod = mcl_init` / `last_mod = _mcl_autogroup`, `min_minetest_version = 5.10`. Freshest tree, ships `mods/COMPAT/` shims (`mcl_vl_entities_purge`, `*_compat`) already solving part of the VL-compat problem. | GPLv3 |
| 2 | [`VoxeLibre/VoxeLibre`](https://git.minetest.land/VoxeLibre/VoxeLibre.git) | `master` @ `2373982f` (HEAD; `version=0.93.0-SNAPSHOT`) | **Donor.** 221 mods, `title = VoxeLibre`, no first/last mod lines. 173 mod names shared with Mineclonia, ~48 VoxeLibre-only mods evaluated as donors, ~49 Mineclonia-only mods kept. | GPLv3 |
| 3 | [`TheUnknownHack3r/voxelibre_shader_preset_port`](https://codeberg.org/TheUnknownHack3r/voxelibre_shader_preset_port.git) | `master` @ `cf0cf619` | **First-class game mod.** 4 files (`mod.conf`, `init.lua`, `README.md`, `LICENSE`); game-agnostic `player:set_lighting` on join. Ships as `mods/arch_shader_preset/` in the merged tree (renamed: no `voxelibre_*` names in `arch_base`). | MIT |

User-supplied ContentDB zips (`6b12075e71.zip` = VoxeLibre 0.92.3 release, sha256 `51ea9242…b279d`; `9e68da81b8.zip` = shader port, sha256 `bba1b104…c735f74`) are superseded by direct git clones above — zips stay as fallback only if a source host is unreachable.

### Hosting (locked)

Merged tree lives at **`game/arch_base/` in the parent repo** (`archlast-equileera`), tracked in git. NOT inside `engine/archlast-luanti/games/` — the engine submodule stays pristine (C++ fork commits only); GPL game content keeps a clean license boundary in the parent tree, matching the Phase 3 `game/arch_rpg/` layout. Directory name = gameid `arch_base` (engine `normalizeGameId` maps dir name → gameid; `game.conf` title = `Arch Base`).

Because the game is outside the engine submodule, discovery needs one explicit lever: `LUANTI_GAME_PATH` env (engine `getSubgamePathEnv`, `src/content/subgames.cpp:52-76`) or the `--gameid arch_base` + games-dir equivalent. Group 0 picks `LUANTI_GAME_PATH=$REPO_ROOT/game` exported in `scripts/run-dev.sh` and smoke paths — no engine source change, no symlink into the submodule.

### Merge direction (locked)

Mineclonia-base, VoxeLibre-donor. Rationale: Mineclonia HEAD is days-fresh, declares load order (`first_mod`/`last_mod`), and its `COMPAT/` layer already absorbs VoxeLibre differences; reversing the direction would re-derive that work. Shared-name mods (173): keep Mineclonia version unless the VoxeLibre variant is strictly newer — decided per-mod at merge time by the donor-evaluation table in Group 0. VoxeLibre-only mods (~48): adopt only if no Mineclonia equivalent exists; Mineclonia-only mods (~49, incl. all of `COMPAT/`): keep unconditionally.

The merge is Lua/config only — no C++ changes, no engine API dependency. Phase 2 Lua-mod work (`arch_*` game mods) proceeds against `devtest` on the stock engine build; the merged game is smoke-tested with stock engine behavior.

### Shader preset as first-class mod

Cloned to `game/arch_base/mods/arch_shader_preset/` (contents identical to upstream except `mod.conf` name/title + `depends = []`). Game-agnostic: registers a single `core.register_on_joinplayer` lighting hook, no dependency on VoxeLibre/Mineclonia mod names, so it survives the merge untouched. Enabled by default in the merged `game.conf` load (game-bundled mods auto-load via `addGameMods`; no `load_mod_*` needed).

### Licensing

Merged tree is overwhelmingly GPLv3 (both games) with one MIT mod. `game/arch_base/LICENSE.txt` = GPLv3 full text + MIT attribution appendix for `arch_shader_preset` (keep upstream `LICENSE` file inside the mod dir verbatim). Provenance (all three SHAs + zip hashes as fallback record) goes in `dependencies/mods.lock` under `[content.arch_base.*]`. No re-licensing, no upstreaming; severed history means no `upstream` remotes ever configured on this tree.

### Play commands after merge (execution phase)

```bash
LUANTI_GAME_PATH=game bin/archlast --gameid arch_base        # main menu: Arch Base worlds
scripts/run-dev.sh --smoke --gameid arch_base                # headless server smoke on merged game
```


## Exit criteria

All must pass for Phase 2 completion:

1. Third-person camera with Lua raycast pull-in works in smoke world (no terrain clip), stock engine.
2. `arch_camera.set_shoulder` / offset getters callable from Lua console without error.
3. Animation state transitions `idle→walk→jump→fall→land` observable in-game via HUD label.
4. Input action `move_forward` derived from `get_player_control` (+ `movement_x/y` sticks) in same session.
5. `scripts/build-linux.sh` (stock upstream build) + `scripts/run-dev.sh --smoke --third-person` exit 0.
6. Frame time regression ≤10% vs Phase 1 baseline.
7. No engine branches, no engine commits; `engine/archlast-luanti` at pin `c0e6812b1`, clean, no `src/archlast/`.
8. Every `engine-patches/*/README.md` contains probe + stock-API mapping + Lua signatures + deferred gaps.
9. Base-game plan complete (no code): Group 0 specifies severed-history fork + merge + `LUANTI_GAME_PATH` wiring + provenance for `game/arch_base/`; `scripts/run-dev.sh --smoke --gameid arch_base` acceptance written for the execution phase.