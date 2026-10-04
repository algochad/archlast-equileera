# Phase 2 — Engine RPG Foundations

Third-person camera, character controller, animation state machine, and input abstraction exposed to Lua. No stats, classes, skills, or combat logic yet. This phase establishes the **engine-side** primitives that Phase 3 (base game) and Phase 4 (RPG foundation) consume exclusively through `arch_engine.*` Lua APIs.

## Goal

Deliver a usable-from-Lua third-person player experience: camera follows the local player with collision avoidance and shoulder offset; character controller supports locomotion states; animation state machine drives skeletal transitions; input is action-mapped and gamepad-ready. All gameplay code interacts through stable Lua bindings; C++ internals remain opaque.

## Non-goals

- RPG stats, attributes, classes, skills, spells (Phase 4).
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