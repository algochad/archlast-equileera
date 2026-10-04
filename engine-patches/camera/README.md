# Camera System Probe — Phase 2 Wave 1

## 1. Probe Commands & Methodology

Probe conducted via static analysis of upstream Luanti 5.17.0 sources (commit `c0e6812b`). No runtime execution required for gap identification; existing `core.camera` API surface fully documented in source.

### Files inspected
- `engine/archlast-luanti/src/script/lua_api/l_camera.cpp` — LuaCamera binding methods
- `engine/archlast-luanti/src/client/camera.h` — Camera class interface
- `engine/archlast-luanti/src/client/camera.cpp` — Camera update logic (view bobbing, FOV transitions, mode switching)

### Existing `core.camera` methods (from `l_camera.cpp:194`)
```
set_camera_mode(mode)
get_camera_mode()
get_fov()
get_pos()
get_offset()
get_look_dir()
get_look_horizontal()
get_look_vertical()
get_aspect_ratio()
```

### Grep verification
```bash
grep -n "luaL_Reg.*methods" engine/archlast-luanti/src/script/lua_api/l_camera.cpp
# Result: line 194, 9 methods registered

grep -rn "collision\|raycast\|shoulder\|distance\|smoothing\|target_lock\|yaw_limit\|pitch_limit\|zoom_range" \
  engine/archlast-luanti/src/script/lua_api/l_camera.cpp
# Result: zero matches — none of these concepts exist in current Lua camera API

grep -rn "m_camera_mode\|setCameraMode\|getCameraNode" engine/archlast-luanti/src/client/camera.h
# Result: lines 165-174 — mode set/get + scene node access confirmed
```

## 2. Results Observed

The upstream `Camera` class (`camera.h:60-265`) manages:
- **Scene nodes**: `m_playernode`, `m_headnode`, `m_cameranode` (IrrlichtMt `ICameraSceneNode`)
- **View bobbing**: `m_view_bobbing_anim`, `m_view_bobbing_speed`, `m_view_bobbing_state`
- **FOV transitions**: server-sent FOV with smooth interpolation (`m_fov_transition_active`, `m_curr_fov_degrees`, `m_target_fov_degrees`)
- **Camera modes**: first-person / third-person / third-person-front via `CameraMode` enum
- **Wielded tool rendering**: digging animation, item mesh swap, arm inertia
- **Nametags**: add/remove/draw overlay system
- **Frustum culling**: plane-based culler lambda

The `LuaCamera` binding exposes only read-only queries plus mode switching. All third-person camera parameters (distance, offset, collision) are hardcoded inside `Camera::update()` with no external control.

## 3. Gap List

| # | Gap | Impact | Upstream Status |
|---|-----|--------|-----------------|
| 1 | **No distance control** | Cannot adjust third-person camera distance at runtime | Hardcoded in `Camera::update()`, no setter |
| 2 | **No shoulder offset** | Cannot position camera over right/left shoulder for TPS aiming | Not implemented; camera always centered behind player |
| 3 | **No smoothing** | Camera snaps instantly to new position; no cinematic lag | Only FOV has smooth transition; position does not |
| 4 | **No collision raycast** | Camera clips through walls/terrain in third-person | No raycast from eye to desired camera pos exists |
| 5 | **No target-lock** | Cannot auto-orient camera toward an entity | No entity tracking in Camera class |
| 6 | **No yaw/pitch clamping** | Cannot restrict vertical look range or horizontal rotation bounds | Full unrestricted rotation; no min/max angle params |
| 7 | **No zoom range** | Cannot define near/far zoom limits for scroll-wheel or action-based zoom | No zoom concept beyond fixed third-person distance |

All 7 gaps confirmed by source inspection. Zero overlap with existing `core.camera` API.

## 4. Chosen C++ Approach

New `CameraManager` class in `src/archlast/`, wrapping the existing IrrlichtMt `Camera` object. **Does NOT modify `src/client/camera.cpp` or `src/client/camera.h`.** Operates as a post-process layer: after `Camera::update()` computes the default position, `CameraManager::update()` overrides the camera node position with its own smoothed, collision-checked result.

### Integration point
- Instantiated during client init after `Camera` construction
- `CameraManager::update(dtime)` called each frame in the client game loop, AFTER `Camera::update()`
- Position override via `m_camera->getCameraNode()->setPosition(final_pos)`
- Collision raycast uses `ClientEnvironment` raycast API (same infrastructure as digging/node selection)

### Lifecycle
```
Client init → new CameraManager(camera) → SetCameraManager(ptr)
Each frame: Camera::update() → CameraManager::update(dtime) → setPosition()
Client shutdown → delete CameraManager
```

## 5. C++ Class Signatures

```cpp
// src/archlast/camera_manager.h
#pragma once
#include <irr_v3d.h>

class Camera; // forward decl from src/client/camera.h

class CameraManager {
public:
    CameraManager(Camera *camera);
    ~CameraManager() = default;

    void setDistance(float distance);           // clamp [1.0, 20.0]
    float getDistance() const;

    void setShoulderOffset(const v3f &offset);  // e.g. (0.8, 0.3, 0.0) for right shoulder
    v3f getShoulderOffset() const;

    void setSmoothing(float factor);            // clamp [0.01, 1.0]; 0 = instant, 1 = never reaches target
    float getSmoothing() const;

    void setYawLimits(float min_deg, float max_deg);
    void setPitchLimits(float min_deg, float max_deg);
    void setZoomRange(float near_dist, float far_dist);

    void enableCollision(bool enable);
    bool isCollisionEnabled() const;

    void setTargetLock(u16 entity_id);          // 0 = unlock
    u16 getTargetLock() const;

    bool getRayHit(v3f &pos, v3f &normal, u16 &entity_id) const;
    void forceUpdate();                         // skip smoothing this frame
    void update(float dtime);                   // called every frame after Camera::update()

private:
    Camera *m_camera = nullptr;
    float m_distance = 5.0f;
    v3f m_shoulder_offset = v3f(0.8f, 0.3f, 0.0f);
    float m_smoothing = 0.15f;
    float m_yaw_min = -180.0f, m_yaw_max = 180.0f;
    float m_pitch_min = -80.0f, m_pitch_max = 80.0f;
    float m_zoom_near = 2.0f, m_zoom_far = 12.0f;
    bool m_collision_enabled = true;
    u16 m_target_lock_id = 0;
    bool m_force_update = false;

    // Smoothed state
    v3f m_smoothed_offset;
    float m_smoothed_distance = 5.0f;

    // Raycast result cache
    bool m_ray_hit = false;
    v3f m_ray_pos, m_ray_normal;
    u16 m_ray_entity = 0;

    void performCollisionRaycast();
    void applySmoothing(float dtime);
    void clampAngles();
};
```

### Key implementation notes
- `performCollisionRaycast()`: casts ray from player eye position through desired camera position. If hit, pulls camera to hit point minus small epsilon offset. Uses `ClientEnvironment::getMap()` raycast infrastructure.
- `applySmoothing()`: exponential interpolation `m_smoothed_distance = lerp(m_smoothed_distance, m_distance, m_smoothing * dtime * 60.0f)`. Same for offset vector.
- `clampAngles()`: enforces pitch/yaw limits before computing final camera orientation.
- Target lock: when active, computes yaw toward locked entity's world position each frame, overriding manual yaw input.

## 6. Lua Binding Signatures (`arch_engine.camera`)

Registered as subtable of `arch_engine` global in `ModApiArchLast::InitializeClient()`.

```lua
-- arch_engine.camera namespace (client-only; nil on dedicated server)

arch_engine.camera.set_distance(distance)          -- float, clamped [1.0, 20.0]
arch_engine.camera.get_distance() -> float

arch_engine.camera.set_shoulder_offset(x, y, z)   -- v3f components
arch_engine.camera.get_shoulder_offset() -> {x, y, z}

arch_engine.camera.set_smoothing(factor)           -- float, clamped [0.01, 1.0]
arch_engine.camera.get_smoothing() -> float

arch_engine.camera.set_yaw_limits(min_deg, max_deg)
arch_engine.camera.set_pitch_limits(min_deg, max_deg)
arch_engine.camera.set_zoom_range(near_dist, far_dist)

arch_engine.camera.enable_collision(enable)         -- bool
arch_engine.camera.is_collision_enabled() -> bool

arch_engine.camera.set_target_lock(entity_id)       -- u16, 0 = unlock
arch_engine.camera.get_target_lock() -> u16

arch_engine.camera.get_ray_hit() -> {pos={x,y,z}, normal={x,y,z}, entity_id=N} | nil
arch_engine.camera.force_update()                   -- skip smoothing this frame
```

### Binding implementation pattern
Static global `CameraManager *g_camera_manager` set during client init. Each Lua function checks for null pointer and returns sensible defaults (distance=5.0, offset={0,0,0}, etc.) if manager not initialized. Functions registered via `luaL_Reg camera_methods[]` table in `lua_bindings_camera.cpp`, attached to `arch_engine.camera` subtable in `modapi_archlast.cpp`.

## 7. Upstream Conflict Risk

**LOW.**

- All new code lives in `src/archlast/` directory (already wired into CMake).
- Zero modifications to `src/client/camera.cpp`, `src/client/camera.h`, or any existing Luanti source file.
- `CameraManager` operates purely through the public `Camera::getCameraNode()` accessor and `ICameraSceneNode::setPosition()`.
- No changes to `LuaCamera` class or `core.camera` namespace — `arch_engine.camera` is entirely separate.
- Collision raycast reuses existing `ClientEnvironment` infrastructure; no new physics or map query code.
- Server-side: `arch_engine.camera` functions return nil/defaults when called on dedicated server (matches `core.camera` pattern).

### Merge safety
- Branch `feature/camera` touches only: `camera_manager.h`, `camera_manager.cpp`, `lua_bindings_camera.cpp` (all in `src/archlast/`).
- Shared files (`modapi_archlast.cpp`, `scripting_client.cpp`, `CMakeLists.txt`) already contain forward declarations and wiring from Phase 2 Step 2; no additional edits needed on this branch.
- Safe to merge independently of `feature/input` and `feature/animation` branches.