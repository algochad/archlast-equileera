# Animation System Probe — Phase 2 Wave 1

## 1. Probes Executed

| Probe | Command | Target |
|---|---|---|
| Basic animation | `player:set_animation({x=0,y=80}, 30, 0, true)` | ObjectRef::l_set_animation (l_object.cpp:412) |
| Bone query | `player:get_bone_position("Head")` | ObjectRef::l_get_bone_position (l_object.cpp:781) |
| Frame speed | `player:set_animation_frame_speed(15)` | ObjectRef::l_set_animation_frame_speed (l_object.cpp:596) |
| Animation readback | `player:get_animation()` | ObjectRef::l_get_animation |

## 2. Results Observed

- **set_animation**: Works. Accepts `{x=from, y=to}` frame range, speed (fps), blend time, loop flag. Internally defers to `GenericCAO::applyTrackAnimation` via `deferred_set_animation_cmds` queue (content_cao.cpp:844, 1572). Scene node must exist before application; otherwise deferred.
- **get_bone_position**: Deprecated wrapper around `get_bone_override`. Returns position/rotation/scale override for a named bone. Server-side only (ServerActiveObject). No client-side bone query exists in current API.
- **Frame range model**: Animations are defined by numeric frame ranges on a single timeline. No named states, no tags, no transition rules. Mod authors must manually track which frame range corresponds to "walk" vs "run" etc.
- **Blend parameter**: `frame_blend` is passed through but only controls IrrlichtMt's internal crossfade duration between two consecutive `set_animation` calls. No dual-track blending; calling set_animation replaces the previous animation after blend completes.
- **No state persistence**: Engine does not remember what "state" an entity is in. Each set_animation call is independent. State machines must be implemented entirely in Lua.
- **GenericCAO** (src/client/content_cao.h:78): Owns `m_animated_meshnode`, `m_meshnode_animation`, and `deferred_set_animation_cmds`. All animation playback goes through this class. No hooks for external state management.

## 3. Gaps Identified

1. **No state machine**: No concept of named animation states (idle, walk, run, etc.). Mods must implement state tracking in Lua with manual frame-range bookkeeping. Error-prone at scale.
2. **No crossfade blending**: Only single-track playback with basic blend-to-next. Cannot blend two animations simultaneously (e.g., upper-body attack while lower-body runs). Dual-animation crossfade requires engine support.
3. **No tag-driven transitions**: No way to define transition rules based on tags (e.g., "grounded" → can enter walk/run/sprint; "airborne" → can enter jump/fall). Transitions are unconditional or mod-managed.
4. **No attachment point registry**: No standardized slot system for attaching items/weapons to entity bones. Each mod invents its own bone-name conventions. No `getAttachmentBone(entity_id, slot)` API.
5. **No transition callbacks**: No event fired when an animation state changes or completes. Mods cannot react to "land" finishing to trigger impact effects without polling.
6. **No per-entity speed multiplier**: Speed is set globally per animation call. Cannot have one entity walk at 1.5× while another walks at 0.8× without separate animation definitions.
7. **Client-only bone queries missing**: `get_bone_position` is server-side only. Client-side code (camera shoulder offset, IK targets) cannot query bone transforms.

## 4. C++ Approach

New `AnimationStateMachine` class in `src/archlast/`, independent of GenericCAO internals. Per-entity state tracking with dual-animation crossfade support.

### Architecture

```
AnimationStateMachine (singleton, client-side)
├── m_states: map<string, AnimationConfig>     # registered state definitions
├── m_entities: map<u16, EntityState>          # per-entity runtime state
└── update(dtime)                              # called each frame from client loop
    ├── decrement blend timers
    ├── compute interpolation factors
    └── push params to GenericCAO via existing set_animation API
```

Integration point: After `AnimationStateMachine::update()` computes current animation params for an entity, call `GenericCAO::setAnimation()` (or equivalent) with the blended result. This uses the existing deferred animation pipeline — no modification to GenericCAO internals required.

### Built-in States (13)

| State | Loop | Tags | Notes |
|---|---|---|---|
| idle | yes | locomotion, grounded | Default state |
| walk | yes | locomotion, grounded | |
| run | yes | locomotion, grounded | |
| sprint | yes | locomotion, grounded | |
| jump | no | airborne | Triggered on ground→air |
| fall | no | airborne | Triggered on air + downward velocity |
| land | no | grounded | Triggered on air→ground |
| attack | no | combat | Upper-body layer candidate |
| block | yes | combat | |
| dodge | no | locomotion | Interrupt priority high |
| hit | no | reactive | Knockback interrupt |
| death | no | terminal | No exit transitions |
| cast | no | magic | Upper-body layer candidate |

## 5. C++ Signatures

```cpp
// src/archlast/animation_state_machine.h

struct AnimationConfig {
    std::string animation_name;
    bool loop = true;
    float speed = 1.0f;
    float blend_time = 0.15f;
    int priority = 0;
    std::vector<std::string> tags;
};

struct EntityState {
    std::string current_state;
    std::string previous_state;
    float blend_remaining = 0.0f;
    float speed_multiplier = 1.0f;
};

class AnimationStateMachine {
public:
    void registerState(const std::string &name, const AnimationConfig &config);
    void setState(u16 entity_id, const std::string &state_name);
    std::string getState(u16 entity_id) const;
    void setSpeedMultiplier(u16 entity_id, float mult);
    void triggerEvent(u16 entity_id, const std::string &event_name);
    void setTransitionCallback(
        std::function<void(u16, const std::string &, const std::string &)> cb);
    std::vector<std::string> listStates() const;
    void update(float dtime);

    // Called by rendering/integration layer
    bool getAnimationParams(u16 entity_id,
        std::string &anim_name, float &speed, bool &loop) const;

private:
    std::unordered_map<std::string, AnimationConfig> m_states;
    std::unordered_map<u16, EntityState> m_entities;
    std::function<void(u16, const std::string &, const std::string &)> m_transition_cb;

    void registerBuiltInStates();
};
```

## 6. Lua API Signatures (`arch_engine.animation`)

```lua
-- Register a custom animation state (extends built-in set)
arch_engine.animation.register_state(name, {
    animation = string,      -- animation name / frame range identifier
    loop = boolean,          -- default true
    speed = number,          -- playback speed multiplier, default 1.0
    blend_time = number,     -- crossfade duration in seconds, default 0.15
    priority = integer,      -- higher overrides lower, default 0
    tags = {string, ...}     -- e.g. {"locomotion", "grounded"}
})

-- Set entity animation state (triggers crossfade from current)
arch_engine.animation.set_state(entity_id, state_name)

-- Query current state name
local state = arch_engine.animation.get_state(entity_id)

-- Adjust playback speed for specific entity
arch_engine.animation.set_speed_multiplier(entity_id, multiplier)

-- Fire named event (triggers transition rules / callbacks)
arch_engine.animation.trigger_event(entity_id, event_name)

-- List all registered state names
local states = arch_engine.animation.list_states()
-- Returns: {"idle", "walk", "run", "sprint", "jump", "fall", "land",
--           "attack", "block", "dodge", "hit", "death", "cast", ...}
```

## 7. Conflict Risk Assessment

**Risk: LOW**

- All new files live in `src/archlast/` (animation_state_machine.{h,cpp}, lua_bindings_animation.cpp).
- GenericCAO (src/client/content_cao.h/cpp) is NOT modified. Integration uses existing public `set_animation` / deferred command pipeline.
- No changes to `src/script/lua_api/l_object.cpp` — the new API lives under `arch_engine.animation`, not `core.*`.
- No changes to shared wiring files (modapi_archlast.cpp already has forward declaration for `RegisterArchAnimation`).
- Server-side: `arch_engine.animation` returns sensible defaults (nil/error) since animation is client-authoritative. Matches Luanti pattern for `core.camera`.

### Upstream Merge Safety

The AnimationStateMachine is fully additive. Future Luanti upstream changes to GenericCAO's internal animation handling would only affect integration if we were modifying GenericCAO directly. Since we consume its public API, upstream merges should be conflict-free. The only risk is if upstream removes or renames `deferred_set_animation_cmds` or `applyTrackAnimation` — monitor during rebase cycles.