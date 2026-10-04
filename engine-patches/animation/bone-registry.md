# Bone Slot Registry — `arch_engine.animation` Attachment Convention

## Purpose

Defines the standardized slot-to-bone-name mapping used by `arch_engine.entity.set_attachment` and `arch_engine.entity.get_attachment_bone`. This convention allows equipment, cosmetics, and weapon systems to attach items to character models without hardcoding per-model bone names in Lua game logic.

## Slot Definitions

| Slot | Default Bone Name | Description | Typical Attachments |
|------|-------------------|-------------|---------------------|
| `weapon` | `"RightHand"` | Primary weapon hand | Swords, staffs, bows, shields (if no offhand) |
| `offhand` | `"LeftHand"` | Secondary hand | Shields, daggers, torches, spell foci |
| `head` | `"Head"` | Head/crown position | Helmets, hats, masks, circlets |
| `chest` | `"Chest"` | Torso center | Armor plates, cloaks, backpacks, amulets |
| `legs` | `"Hips"` | Hip/waist anchor | Belts, pouches, leg armor skirts, quivers |
| `feet` | `"RightFoot"` | Foot reference point | Boot effects, footstep emitters, ankle accessories |

### Model Override Convention

Models may override default bone names via a JSON metadata file at `<model_path>/bone_slots.json`:

```json
{
  "weapon": "R_Hand",
  "offhand": "L_Hand",
  "head": "Head_Top",
  "chest": "Spine2",
  "legs": "Hips",
  "feet": "R_Foot"
}
```

When present, the FSM's attachment system reads this file at model load time and uses the overridden names. Missing slots fall back to the defaults above.

## Validation Behavior

**Missing bone handling:** When `set_attachment(entity_id, slot, item)` is called and the resolved bone name does not exist on the target entity's mesh:

1. Log a warning via `warningstream`: `[ARCH-ENGINE:ANIM] attachment slot=<slot> bone=<name> not found on entity=<id>, skipping`
2. **Do NOT crash or assert.** The attachment is silently skipped for that entity.
3. The slot remains registered as "pending" — if the entity's mesh is later swapped to one containing the bone, the attachment activates automatically on next update.
4. `get_attachment_bone(entity_id, slot)` still returns the configured bone name regardless of whether it currently exists on the mesh. This allows Lua code to inspect intended attachments even when inactive.

**Invalid slot handling:** If an unrecognized slot name is passed to `set_attachment` or `get_attachment_bone`:

1. Log a warning: `[ARCH-ENGINE:ANIM] unknown attachment slot=<slot> on entity=<id>`
2. Return `nil` / no-op. Do not crash.

## Integration with `arch_engine.animation`

The bone registry is consumed by the animation subsystem in two ways:

1. **Attachment rendering**: When `arch_engine.entity.set_attachment(id, slot, item)` is called, the FSM resolves the slot to a bone name via this registry, then delegates to GenericCAO's existing attachment system (`m_attachment_bone`, `m_attachment_parent_id`). The FSM adds the slot abstraction layer; GenericCAO handles the actual scene graph parenting.

2. **Animation-aware attachments**: During state transitions, the FSM checks whether attached items need repositioning. For example, a weapon attached to `weapon` slot may need offset adjustment between `idle` and `attack` states. The bone registry provides the stable slot identifier that persists across state changes, while the underlying bone name may vary per model.

## Future Extensions

- **Per-entity slot overrides**: Allow individual entities to remap slots at runtime (e.g., left-handed characters swap `weapon`↔`offhand`).
- **Bone existence cache**: Pre-scan mesh bones at load time to avoid repeated lookups during attachment operations.
- **Slot groups**: Define composite slots like `both_hands` that resolve to multiple bones for two-handed weapons.
- **IK target slots**: Extend registry to include IK chain targets (`ik_weapon_target`, `ik_look_target`) for procedural animation blending.