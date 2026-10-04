# Phase 2 — Engine RPG Foundations

Base-game mechanics core (`game/arch_base/`, planned here from Mineclonia + VoxeLibre + shader preset) plus engine-side third-person camera, character controller, animation state machine, and input abstraction exposed to Lua. This phase establishes the **engine-side** primitives that Phase 3 and Phase 4 consume exclusively through `arch_engine.*` Lua APIs.

## Goal

Two tracks, in order:

1. **Base game `arch_base`** (mechanics core, plan-only in this phase): fork Mineclonia + VoxeLibre + shader-preset sources with severed history into `game/arch_base/`, merge to a single Mineclonia-based tree, ship the shader preset as a first-class game mod. This becomes the mechanics system every later phase builds on.
2. **Engine RPG foundations**: usable-from-Lua third-person player experience — camera follows the local player with collision avoidance and shoulder offset; character controller supports locomotion states; animation state machine drives skeletal transitions; input is action-mapped and gamepad-ready. All gameplay code interacts through stable Lua bindings; C++ internals remain opaque.

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

## Architecture decisions

Per spec §9, each feature gets an explicit **Lua probe → C++ API → internals** decision recorded in its `engine-patches/<feature>/README.md`:

| Feature | Decision rationale | Binding layer |
|---|---|---|
| Camera distance/offset/smoothing | Luanti's built-in `set_camera_mode` lacks collision raycast + shoulder offset; probe documents gap | New C++ `CameraManager` wrapper → Lua `arch_engine.camera.*` |
| Camera yaw/pitch limits | Existing API exposes raw angles but no clamping or target-lock hook | Extend wrapper above |
| Character controller states | Luanti `PlayerSAO` has walk/jump but no sprint/dodge/knockback/swim state enum | New C++ `CharacterController` component → Lua `arch_engine.player.*` |
| Animation state machine | Luanti `GenericCAO` plays single animations; no layered FSM or transition blending | New C++ `AnimationStateMachine` → Lua `arch_engine.animation.*` |
| Model attachment points | Bone names are asset-specific; need registry + validation | Lua-configurable table read by C++ attachment system |
| Input action mapping | Luanti key binding is keycode-only, no axis/gamepad/action concept | New C++ `InputActionMap` → Lua `arch_engine.input.*` |
| Entity component queries | Gameplay needs `get_entity_by_id`, `has_component`, etc. | Thin Lua wrappers over existing `ServerEnvironment` |
| Render debug overlays | Camera rays, state labels needed during dev only | Conditional C++ debug draw, Lua toggle |

**Rule**: if Lua can achieve ≥80% of the requirement with existing APIs, document the gap and defer C++ work. If not, implement the minimal C++ surface and expose it. Never expose internal IrrlichtMt or Luanti class pointers to Lua.

## Lua API surface

All functions live under `arch_engine.*`. Tables are passed by reference; vectors use `{x,y,z}` tables. Defaults shown after `=`.

### `arch_engine.camera`

```lua
arch_engine.camera.set_distance(distance: number = 5.0)          -- clamp [1.0, 20.0]
arch_engine.camera.get_distance() -> number
arch_engine.camera.set_shoulder_offset(offset: {x,y,z} = {0.8, 0.3, 0})
arch_engine.camera.get_shoulder_offset() -> {x,y,z}
arch_engine.camera.set_smoothing(factor: number = 0.15)          -- lerp alpha per frame, [0.01, 1.0]
arch_engine.camera.set_yaw_limits(min: number = -180, max: number = 180)
arch_engine.camera.set_pitch_limits(min: number = -80, max: number = 80)
arch_engine.camera.set_zoom_range(near: number = 2.0, far: number = 12.0)
arch_engine.camera.enable_collision(enable: boolean = true)
arch_engine.camera.set_target_lock(entity_id: number | nil)      -- nil = unlock
arch_engine.camera.get_ray_hit() -> {pos: {x,y,z}, normal: {x,y,z}, entity: number?} | nil
arch_engine.camera.force_update()                                -- skip smoothing this frame
```

### `arch_engine.animation`

```lua
arch_engine.animation.register_state(name: string, config: {
    animation: string,           -- animation name from model
    loop: boolean = true,
    speed: number = 1.0,
    blend_time: number = 0.15,   -- seconds to crossfade from previous state
    priority: number = 0,        -- higher overrides lower
    tags: string[] = {},         -- e.g. {"locomotion", "grounded"}
})
arch_engine.animation.set_state(entity_id: number, state_name: string)
arch_engine.animation.get_state(entity_id: number) -> string
arch_engine.animation.set_speed_multiplier(entity_id: number, mult: number = 1.0)
arch_engine.animation.trigger_event(entity_id: number, event_name: string)
arch_engine.animation.on_transition(callback: function(entity_id, from, to))
arch_engine.animation.list_states() -> string[]
```

Built-in states registered at engine init: `idle`, `walk`, `run`, `sprint`, `jump`, `fall`, `land`, `attack`, `block`, `dodge`, `hit`, `death`, `cast`. Transitions are tag-driven: `grounded→airborne` triggers jump/fall; `locomotion→idle` on zero input.

### `arch_engine.player`

```lua
arch_engine.player.set_controller_state(state: string)           -- walk|run|sprint|jump|fall|swim|dodge|knockback
arch_engine.player.get_controller_state() -> string
arch_engine.player.set_move_speed(state: string, speed: number)
arch_engine.player.apply_knockback(direction: {x,y,z}, force: number, duration: number)
arch_engine.player.is_grounded() -> boolean
arch_engine.player.get_velocity() -> {x,y,z}
arch_engine.player.set_swim_depth(threshold: number = 0.6)       -- fraction of node height
```

### `arch_engine.input`

```lua
arch_engine.input.bind_action(action: string, keys: string[], gamepad_buttons: string[] = {})
arch_engine.input.bind_axis(axis: string, positive: string, negative: string, gamepad_axis: string = "")
arch_engine.input.is_action_pressed(action: string) -> boolean
arch_engine.input.is_action_just_pressed(action: string) -> boolean
arch_engine.input.is_action_just_released(action: string) -> boolean
arch_engine.input.get_axis(axis: string) -> number                -- [-1.0, 1.0], deadzone applied
arch_engine.input.get_actions() -> string[]
arch_engine.input.load_profile(path: string) -> boolean
arch_engine.input.save_profile(path: string) -> boolean
```

Default profile loaded from `game/arch_rpg/config/input_default.json`. Gamepad axes: `left_stick_x`, `left_stick_y`, `right_stick_x`, `right_stick_y`, `l2`, `r2`.

### `arch_engine.entity`

```lua
arch_engine.entity.get_position(id: number) -> {x,y,z}
arch_engine.entity.set_position(id: number, pos: {x,y,z})
arch_engine.entity.get_rotation(id: number) -> {x,y,z}
arch_engine.entity.has_component(id: number, component: string) -> boolean
arch_engine.entity.get_attachment_bone(id: number, slot: string) -> string | nil
arch_engine.entity.set_attachment(id: number, slot: string, item_id: string)
```

Slots: `weapon`, `offhand`, `head`, `chest`, `legs`, `feet`.

### `arch_engine.render`

```lua
arch_engine.render.set_debug_overlay(name: string, enable: boolean)
arch_engine.render.get_fps() -> number
arch_engine.render.get_frame_time_ms() -> number
```

Overlays: `camera_rays`, `state_labels`, `bone_positions`, `input_axes`.

## Branch plan

One concern per branch, squash-merge to `main` in order. Each branch rebases on `main` before merge.

| Order | Branch | Scope | Depends on |
|---|---|---|---|
| 1 | `feature/camera` | Camera manager C++, Lua bindings, collision, shoulder offset, smoothing | Phase 1 main |
| 2 | `feature/input` | Input action map C++, Lua bindings, default profile, gamepad support | Phase 1 main |
| 3 | `feature/animation` | Animation FSM C++, Lua bindings, built-in states, attachment points | `feature/camera` merged |
| 4 | `feature/rpg-api` | Player controller states, entity helpers, render debug, integration smoke test | `feature/camera` + `feature/animation` + `feature/input` merged |

Merge command pattern:

```bash
git checkout main
git merge --squash feature/<name>
git commit -m "feat(engine): <scope> (<phase-2>)"
```

No fast-forward merges; every Phase 2 feature is one squashed commit on `main`.

## Engine patches layout

Each patch directory contains design notes only — no code. Code lives in `engine/archlast-luanti/src/archlast/`.

```text
engine-patches/
├── camera/
│   ├── README.md          # Lua probe results, gap analysis, C++ class sketch
│   └── collision-notes.md # Raycast strategy, terrain vs entity filtering
├── animation/
│   ├── README.md          # FSM design, state/tag taxonomy, blend rules
│   └── bone-registry.md   # Attachment point naming convention per model
├── input/
│   ├── README.md          # Action map schema, gamepad mapping table
│   └── profiles.md        # Default + rebind persistence format
└── gameplay-api/
    ├── README.md          # Player controller state diagram, knockback contract
    └── entity-helpers.md  # Component query patterns, caching notes
```

Each `README.md` MUST contain: (1) Lua capability probe result, (2) gap list, (3) chosen approach with rationale, (4) C++ class/method signatures, (5) Lua binding signatures, (6) upstream conflict risk assessment.

## Performance budget

- Frame time regression vs Phase 1 baseline: **≤10%** measured by `scripts/bench-frame-time.sh` (to be created in this phase).
- Camera raycast: ≤0.5ms per frame (single ray, early-out on terrain).
- Animation FSM update: ≤0.2ms for 64 entities.
- Input polling: ≤0.05ms per frame.
- Memory: no new per-frame allocations in hot paths; object pools for raycast results and animation events.

Baseline captured at Phase 2 start:

```bash
scripts/run-dev.sh --smoke --bench > /tmp/phase1-baseline.txt
```

Every merge to `main` re-runs benchmark; CI blocks if regression exceeds budget.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| IrrlichtMt camera internals change upstream | Camera collision breaks, rework needed | Wrap behind `CameraManager` interface; isolate Irrlicht calls to one `.cpp`; pin upstream commit tightly |
| Upstream merge conflicts on `genericobject.cpp` / `camera.cpp` | Rebase pain, delayed sync | Keep C++ diffs minimal and in `src/archlast/` namespace; avoid modifying Luanti core files when possible; document every touched file in patch README |
| Animation blending quality insufficient with linear lerp | Visual popping | Implement crossfade with dual-animation playback; budget allows 2 concurrent anims per entity |
| Gamepad input varies across Linux drivers | Inconsistent axis mapping | Use SDL2 gamepad DB; ship `gamecontrollerdb.txt`; allow user override via profile |
| Lua GC pressure from per-frame vector table creation | Frame stutters | Reuse cached vector tables; provide `*_into(out_table)` variants for hot callers |
| Shoulder offset causes clipping in tight corridors | Bad UX | Collision raycast includes offset origin; fallback to centered camera on repeated hits |
| State machine transitions race with network corrections | Visual desync | Server-authoritative state; client predicts, reconciles on correction; FSM accepts forced state set without blend |

## Logging conventions

All Phase 2 log lines use prefixed tags for grep-ability:

- `[ARCH-ENGINE:CAMERA]` — camera manager messages
- `[ARCH-ENGINE:ANIM]` — animation FSM transitions, errors
- `[ARCH-ENGINE:INPUT]` — action map load, bind failures
- `[ARCH-ENGINE:PLAYER]` — controller state changes
- `[ARCH-RPG:*]` — reserved for Phase 3+ gameplay mods (NOT used in this phase)

Log level: `infostream` for state changes, `warningstream` for fallbacks/recoveries, `errorstream` for API misuse and assertion failures. Never log per-frame data.

## Base game `arch_base` (mechanics core — plan-only this phase)

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

The merge is Lua/config only — no C++ changes, no engine API dependency. Phase 2 engine work (`arch_engine.*`) proceeds against `devtest`; the merged game is smoke-tested with stock engine behavior.

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

1. Third-person follow camera with collision works in smoke world (no terrain clip).
2. `arch_engine.camera.set_distance` / `set_shoulder_offset` callable from Lua console without error.
3. Animation state transitions `idle→walk→jump→fall→land` observable in-game via debug overlay.
4. Input action `move_forward` responds to both keyboard and gamepad in same session.
5. `scripts/build-linux.sh` + `scripts/run-dev.sh --smoke --third-person` exit 0.
6. Frame time regression ≤10% vs Phase 1 baseline.
7. All four feature branches squash-merged to `main`; no dangling branches.
8. Every `engine-patches/*/README.md` contains probe + gap + decision + signatures.
9. Base-game plan complete (no code): Group 0 specifies severed-history fork + merge + `LUANTI_GAME_PATH` wiring + provenance for `game/arch_base/`; `scripts/run-dev.sh --smoke --gameid arch_base` acceptance written for the execution phase.