# Entity Helpers — Implementation Notes for arch_engine.entity

## Environment Lookup by ID

All `arch_engine.entity.*` functions resolve entities via `ServerEnvironment::getActiveObject(u16 id)`, returning `ServerActiveObject*`. This is the same lookup used internally by `unit_sao.cpp:22` for attachment parent resolution and `clientiface.cpp:845` for known-by tracking.

Pattern:
```cpp
ServerActiveObject *obj = env->getActiveObject(id);
if (!obj) {
    // Return nil to Lua; log warningstream only on first miss per session
    return 0;
}
```

Null safety is mandatory. Entity IDs are recycled; stale references are expected. Never cache raw pointers across ticks without re-validation.

## Position / Rotation Passthrough

- `get_position(id)` → `obj->getBasePosition()` returns `v3f`. Push as Lua table `{x, y, z}`.
- `set_position(id, pos)` → `obj->setPos(v3f)`. Teleports immediately; no client-side interpolation. Use sparingly (respawn, admin commands). For movement, prefer velocity-based APIs.
- `get_rotation(id)` → `obj->getRotation()` returns `v3f` in Euler degrees. Push as Lua table `{x, y, z}`.

These are direct passthroughs with no transformation. Coordinate system matches Luanti convention: Y-up, right-hand.

## Attachment Slot Table

Static mapping from semantic slot names to bone names. Defined as a compile-time constant array in `lua_bindings_entity.cpp`:

| Slot | Bone Name | Fallback |
|---|---|---|
| `weapon` | `RightHand` | `RightArm` |
| `offhand` | `LeftHand` | `LeftArm` |
| `head` | `Head` | `Neck` |
| `chest` | `Torso` | `Spine2` |
| `legs` | `Hips` | `Spine` |
| `feet` | `RightFoot` | `RightLeg` |

`get_attachment_bone(id, slot)` looks up the slot string in this table, returns the bone name. If the model lacks the primary bone, the fallback is returned. If neither exists, returns nil.

`set_attachment(id, slot, item_id)` resolves the bone name, then calls the existing SAO attachment mechanism (`UnitSAO::setAttachment`) with the resolved bone. Item entity must already exist in the environment.

## Component Query Patterns

`has_component(id, component_name)` is a **stub** returning false for all inputs. Phase 4 will introduce an ECS layer; until then, this function exists solely to satisfy the `arch_engine.entity` API surface and allow mods to write forward-compatible code.

Future Phase 4 pattern (not implemented now):
```cpp
// Pseudocode for Phase 4
bool hasComponent(u16 id, const std::string &comp) {
    auto *ecs = getECS(); // Phase 4 singleton
    return ecs && ecs->hasComponent(id, comp);
}
```

Mods calling `has_component()` today will always receive false. Documentation should note this explicitly to prevent confusion.

## Caching Notes — No Per-Frame Allocation

Critical performance constraint: entity helper functions are called frequently (potentially multiple times per tick per entity). Implementation rules:

1. **No heap allocation in hot path.** `get_position` / `get_rotation` push Lua tables using `lua_createtable(L, 0, 3)` + three `lua_pushnumber` + `lua_setfield`. This uses Lua's internal allocator, not `new`/`malloc`. Acceptable.
2. **No string construction.** Slot-to-bone lookup uses a static `std::unordered_map<std::string_view, std::string_view>` initialized once at registration time. No runtime string copies.
3. **No environment iteration.** All lookups are O(1) hash map access via `getActiveObject(id)`. Never iterate the active object list.
4. **No logging per call.** `warningstream` on null entity is rate-limited (max once per 5 seconds per missing ID). Debug overlays are gated behind `set_debug_overlay` toggle.
5. **Attachment bone cache.** Bone name resolution for a given (entity_id, slot) pair may be cached in a per-entity sidecar if profiling shows repeated lookups. Default: no cache; add only if benchmarked.

The `arch_engine.entity` namespace is designed to be zero-overhead when unused and minimal-overhead when active. Any implementation that introduces per-frame allocations, string formatting, or environment scans violates this contract and must be revised before merge.