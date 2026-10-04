# Gameplay API Probe — arch_engine.player / entity / render

## Probes Run

| Probe | Command | Source |
|---|---|---|
| Player velocity | `player:get_velocity()` | `l_object.cpp:1252` (ObjectRef), `l_localplayer.cpp:40` (LuaLocalPlayer) |
| Physics override | `player:get_physics_override()` | `l_object.cpp:1922`, `l_localplayer.cpp:141` |
| PlayerSAO interface | Inspected `src/server/player_sao.h:57-123` | Direct read |
| Existing stubs | Read `character_controller.h`, `lua_bindings_player.cpp`, `lua_bindings_entity.cpp`, `lua_bindings_render.cpp` | Direct read |

## Results Observed

- **`get_velocity()`**: Available on both client (`LuaLocalPlayer`) and server (`ObjectRef`). Returns `v3f`. Server-side reads from `ServerActiveObject::getVelocity()`. No state classification — raw vector only.
- **`get_physics_override()`**: Returns table `{speed, jump, gravity, sneak, sneak_glitch, new_move}`. Pure multiplier-based physics tuning. No state machine, no knockback, no dodge impulse.
- **PlayerSAO** (`src/server/player_sao.h:57`): Inherits `UnitSAO`. Exposes `step()`, `setBasePosition()`, `punch()`, HP/breath, inventory. No sprint/dodge/swim state tracking. Movement is physics-driven via `physics_override` multipliers only.
- **Existing stubs**: `CharacterController` header defines `ControllerState` enum (WALK/RUN/SPRINT/JUMP/FALL/SWIM/DODGE/KNOCKBACK) and method signatures but implementation is empty no-op. All three binding files (`lua_bindings_player.cpp`, `lua_bindings_entity.cpp`, `lua_bindings_render.cpp`) contain only empty `RegisterArch*` functions.

## Gaps

1. **No sprint/dodge/knockback/swim states**: `physics_override` provides speed multipliers but no discrete state enum. Cannot distinguish sprint from run at the API level. No dodge impulse mechanism. No knockback interrupt that overrides player input. No swim depth threshold for automatic state transition.
2. **No server-authoritative reconciliation**: Client predicts movement, server corrects via position updates. No API to query reconciliation state or apply server-authoritative state corrections. `arch_engine.player` must provide a reconciliation hook for future use.
3. **No grounded detection API**: `get_physics_override()` has no `on_ground` field. Grounded state is computed internally in collision code but never exposed to Lua. Required for animation state transitions (land/jump/fall).
4. **No entity component query**: No `has_component()` or attachment bone registry. Entity helpers are raw position/rotation getters with no semantic layer.
5. **No render debug overlay**: No API to toggle camera rays, state labels, bone positions, or input axis visualization during development.

## C++ Approach

### CharacterController (arch_engine.player)

New `CharacterController` class in `src/archlast/character_controller.{h,cpp}`. Uses composition — instantiated per-player inside `PlayerSAO::step()`, NOT inheriting from `UnitSAO`. State enum drives movement speed selection and animation triggers. Knockback applies as a timed interrupt that overrides normal state transitions until expired. Swim depth threshold auto-transitions to SWIM state when water depth exceeds configurable value.

### Entity Helpers (arch_engine.entity)

Thin wrappers over `ServerEnvironment` lookups. `getPosition(id)` / `setPosition(id, pos)` delegate to `ServerEnvironment::getActiveObject(id)`. `hasComponent()` returns false for now (component system is Phase 4). `getAttachmentBone()` / `setAttachment()` use a per-model bone slot registry (initially hardcoded defaults, later data-driven).

### Render Debug (arch_engine.render)

Client-only. `set_debug_overlay(name, enable)` toggles named overlays drawn via IrrlichtMt `IVideoDriver::draw2DText` / `draw3DLine`. `get_fps()` and `get_frame_time_ms()` read from existing client stats.

## C++ Signatures

### CharacterController (`src/archlast/character_controller.h`)

```cpp
enum class ControllerState {
    WALK, RUN, SPRINT, JUMP, FALL, SWIM, DODGE, KNOCKBACK
};

class CharacterController {
public:
    void setState(ControllerState state);
    ControllerState getState() const;
    std::string getStateName() const;
    void setMoveSpeed(ControllerState state, float speed);
    void applyKnockback(const v3f &direction, float force, float duration);
    bool isGrounded() const;
    v3f getVelocity() const;
    void setSwimDepth(float threshold);
    void update(float dtime, const v3f &velocity, bool on_ground, float water_depth);
};
```

### Entity Helpers (registered in `lua_bindings_entity.cpp`)

```cpp
// Wrapped as arch_engine.entity.*
v3f getPosition(u16 id);
void setPosition(u16 id, const v3f &pos);
v3f getRotation(u16 id);
bool hasComponent(u16 id, const std::string &component);
std::string getAttachmentBone(u16 id, const std::string &slot);
void setAttachment(u16 id, const std::string &slot, u16 item_id);
```

### Render Debug (registered in `lua_bindings_render.cpp`)

```cpp
// Wrapped as arch_engine.render.*
void setDebugOverlay(const std::string &name, bool enable);
float getFps();
float getFrameTimeMs();
```

## Lua Binding Signatures

### `arch_engine.player`

| Function | Args | Returns | Notes |
|---|---|---|---|
| `set_state(state_name)` | string | nil | "walk"/"run"/"sprint"/"jump"/"fall"/"swim"/"dodge"/"knockback" |
| `get_state()` | none | string | Current state name |
| `set_move_speed(state_name, speed)` | string, number | nil | Per-state speed override |
| `apply_knockback(dir, force, duration)` | {x,y,z}, number, number | nil | Interrupts current state |
| `is_grounded()` | none | boolean | True if on solid ground |
| `get_velocity()` | none | {x,y,z} | Current velocity vector |
| `set_swim_depth(threshold)` | number | nil | Water depth for auto-swim |

### `arch_engine.entity`

| Function | Args | Returns | Notes |
|---|---|---|---|
| `get_position(id)` | number | {x,y,z} | World position |
| `set_position(id, pos)` | number, {x,y,z} | nil | Teleport |
| `get_rotation(id)` | number | {x,y,z} | Euler rotation |
| `has_component(id, name)` | number, string | boolean | Always false in Phase 2 |
| `get_attachment_bone(id, slot)` | number, string | string\|nil | Bone name for slot |
| `set_attachment(id, slot, item_id)` | number, string, number | nil | Attach item to bone |

### `arch_engine.render`

| Function | Args | Returns | Notes |
|---|---|---|---|
| `set_debug_overlay(name, enable)` | string, boolean | nil | "camera_rays"/"state_labels"/"bone_positions"/"input_axes" |
| `get_fps()` | none | number | Current FPS |
| `get_frame_time_ms()` | none | number | Current frame time in ms |

## Upstream Conflict Risk

**LOW.** All implementation lives in new files under `src/archlast/`. `CharacterController` composes into `PlayerSAO::step()` via a member pointer — no inheritance change, no virtual override. Entity helpers call existing `ServerEnvironment` public API only. Render debug uses public `IVideoDriver` drawing methods. No modifications to `src/client/camera.cpp`, `src/client/content_cao.cpp`, or core physics code. The only integration point is `PlayerSAO::step()` where `CharacterController::update()` is called after physics — this is additive, not replacing existing logic.