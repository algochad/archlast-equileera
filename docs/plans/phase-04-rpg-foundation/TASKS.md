# Phase 4 Tasks — RPG Foundation (ordered, test-driven)

Estimated total: 18–26 hours across 8 task groups. Do in order. Each group has its own acceptance gate; do not proceed if red.

All paths relative to repo root. All Lua modules live under `game/arch_rpg/mods/`. All tests under `tests/`. All scripts under `scripts/`.

---

## 1. Stats module + centralized formulas (3–4h)

### Target
`game/arch_rpg/mods/arch_rpg_stats/init.lua` + `formulas.lua`. Single source of truth for all 16 derived stats + block/dodge. No inline calculations anywhere else.

### Steps

- [ ] Create mod directory structure: `arch_rpg_stats/{init.lua, formulas.lua, mod.conf}`
- [ ] Implement `arch_rpg_stats.register_derived(name, fn)` in `init.lua`; register all 16 + block/dodge from `formulas.lua`
- [ ] Implement `arch_rpg_stats.get(player, stat_name)` with dirty-flag recomputation
- [ ] Implement `arch_rpg_stats.modify(player, {attr=..., delta=..., source=...})` for base attributes
- [ ] Implement `arch_rpg_stats.modify(player, {buff_id=..., stats={...}, duration=...})` for temporary modifiers
- [ ] Implement `arch_rpg_stats.invalidate(player)` to mark dirty
- [ ] Add attribute clamping [1, 99] and derived stat clamping per README §1.2 table
- [ ] Log `[ARCH-RPG:stats] recalc player=<name> <stat>=<value>` on every recomputation
- [ ] Write `tests/test_stats.lua`: one test per derived formula at attr=1, attr=50, attr=99; edge cases (zero equip, max equip, negative buff)
- [ ] Run `scripts/test.sh --filter test_stats` → all pass

### Commands

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_stats
# edit files via editor
chmod +x scripts/test.sh  # if not already
scripts/test.sh --filter test_stats
```

### Acceptance gate
All 18+ unit tests pass. No derived stat computed outside `arch_rpg_stats` module (grep verification).

---

## 2. XP / level module (2–3h)

### Target
`game/arch_rpg/mods/arch_rpg_xp/init.lua`. Deterministic curve from README §2. Level-up triggers stat/skill point allocation.

### Steps

- [ ] Create `arch_rpg_xp/{init.lua, mod.conf}`
- [ ] Implement pure function `arch_rpg_xp.xp_for_next_level(level)` using formula `floor(100 * L^1.8 + 50 * L)`
- [ ] Implement cumulative XP lookup (precompute table 1–20 at load, cache)
- [ ] Implement `arch_rpg_xp.add(player, amount, source)`: add XP, loop level-ups, allocate points, log each
- [ ] Implement `arch_rpg_xp.get_level(player)`, `arch_rpg_xp.get_xp(player)`
- [ ] Implement `arch_rpg_xp.allocate_stat_point(player, attr)` → calls `arch_rpg_stats.modify`
- [ ] Stub `player.skills.points` storage (no consumption yet)
- [ ] Log `[ARCH-RPG:xp] gain player=<name> amount=<n> source=<src>` and `[ARCH-RPG:xp] level_up ...`
- [ ] Write `tests/test_xp_curve.lua`: verify XP(L) for L=2..20 matches README table; verify cumulative sums; verify multi-level-up in single add(); verify stat point allocation count
- [ ] Run `scripts/test.sh --filter test_xp_curve` → all pass

### Commands

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_xp
scripts/test.sh --filter test_xp_curve
```

### Acceptance gate
XP curve matches README §2.2 table exactly. Multi-level-up works. Stat points allocated correctly.

---

## 3. Class registry + Warrior definition (1.5–2h)

### Target
`game/arch_rpg/mods/arch_rpg_classes/{init.lua, data/warrior.lua}`. Data-only class system. Zero `if class ==` branches.

### Steps

- [ ] Create `arch_rpg_classes/{init.lua, mod.conf, data/}`
- [ ] Implement `arch_rpg_classes.register(id, def)` with schema validation (required fields: name, starting_attributes, starting_equipment, allowed_slots)
- [ ] Implement `arch_rpg_classes.get(id)` returning read-only copy
- [ ] Implement `arch_rpg_classes.set(player, id)` → assigns class, applies starting attrs via `arch_rpg_stats.modify`, gives starting equipment/inventory via `arch_rpg_inventory.add` / `arch_rpg_equipment.equip`
- [ ] Implement `arch_rpg_classes.get_player_class(player)`
- [ ] Write `data/warrior.lua` per README §3.3 spec
- [ ] Load warrior.lua in init.lua via `dofile`
- [ ] Log `[ARCH-RPG:class] register id=<id>` and `[ARCH-RPG:class] assign player=<name> class=<id>`
- [ ] Write `tests/test_class_restrictions.lua`: verify Warrior starting attrs match spec; verify `get("warrior")` returns expected table; verify `set()` applies attrs; verify unknown class returns nil
- [ ] Grep entire `game/arch_rpg/mods/` for `class ==`, `class_id ==`, `"warrior"` outside arch_rpg_classes → must be zero hits
- [ ] Run `scripts/test.sh --filter test_class_restrictions` → all pass

### Commands

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_classes/data
grep -rn 'class ==' game/arch_rpg/mods/ || echo CLEAN
scripts/test.sh --filter test_class_restrictions
```

### Acceptance gate
No class string literals outside registry module. Warrior defaults correct. Tests pass.

---

## 4. Item registry + data files (3–4h)

### Target
`game/arch_rpg/mods/arch_rpg_items/{init.lua, data/*.lua}`. Schema-validated item definitions. 10 example items from README §4.3.

### Steps

- [ ] Create `arch_rpg_items/{init.lua, mod.conf, data/}`
- [ ] Define item schema validator (required: id, name, description, icon, stack_max, weight, rarity, value; optional: requirements, stats, effects, slot, durability, meta)
- [ ] Implement `arch_rpg_items.register(id, def)` with validation; reject duplicates
- [ ] Implement `arch_rpg_items.get(id)`, `arch_rpg_items.list(filter?)`
- [ ] Implement `arch_rpg_items.can_equip(player, item_id)` checking slot, level, class, attribute requirements
- [ ] Implement `arch_rpg_items.get_stat_bonuses(item_id)` applying rarity multiplier from README §4.2
- [ ] Write data files: `weapons.lua` (iron_sword, steel_sword), `armor.lua` (leather_chest, chainmail_chest, leather_legs, leather_boots), `shields.lua` (wooden_shield, iron_kite_shield), `consumables.lua` (health_potion_minor), `accessories.lua` (warrior_ring_vigor)
- [ ] Load all data files in init.lua
- [ ] Log `[ARCH-RPG:item] register id=<id>` per item
- [ ] Write `tests/test_stacking.lua`: verify stack_max respected; verify meta-incompatible stacks don't merge; verify get_stat_bonuses applies rarity mult correctly
- [ ] Run `scripts/test.sh --filter test_stacking` → all pass

### Commands

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_items/data
scripts/test.sh --filter test_stacking
```

### Acceptance gate
All 10 items registered without error. Stack logic correct. Rarity multipliers applied. Tests pass.

---

## 5. Inventory + equipment equip/unequip stat application (4–5h)

### Target
`arch_rpg_inventory/init.lua` + `arch_rpg_equipment/init.lua`. Server-authoritative stacks, hotbar, equip/unequip with stat deltas. Unified Inventory evaluation completed.

### Steps

- [ ] Create `arch_rpg_inventory/{init.lua, mod.conf}`
- [ ] Implement inventory data model: ordered list of `{id, count, meta}` stacks per player
- [ ] Implement `add()`, `remove()`, `get_stacks()`, `sort()`, `move_to_hotbar()`, `transfer()`
- [ ] Implement stacking logic: same id + compatible meta → merge up to stack_max
- [ ] Implement hotbar as indices 1–10 of inventory array
- [ ] Create `arch_rpg_equipment/{init.lua, mod.conf}`
- [ ] Implement `equip(player, slot, item_id)`: validate via `can_equip`, remove old item stats, add new item stats, update inventory, log
- [ ] Implement `unequip(player, slot)`: reverse of equip, return item to inventory
- [ ] Implement `get_equipped(player, slot?)`
- [ ] Every equip/unequip MUST call `arch_rpg_stats.modify` with exact delta and `arch_rpg_stats.invalidate`
- [ ] Log `[ARCH-RPG:inv]` and `[ARCH-RPG:equip]` per README §9
- [ ] **Unified Inventory evaluation**: score rubric from README §6.2; document result in `game/arch_rpg/mods/arch_rpg_inventory/EVALUATION.md` (adopt or own UI decision)
- [ ] Write `tests/test_equip_deltas.lua`: equip iron_sword → PATK increases by 8; unequip → returns to baseline; equip chainmail_chest with insufficient STR → fails; swap weapons → delta correct
- [ ] Run `scripts/test.sh --filter test_equip_deltas` → all pass

### Commands

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_inventory
mkdir -p game/arch_rpg/mods/arch_rpg_equipment
scripts/test.sh --filter test_equip_deltas
```

### Acceptance gate
Equip/unequip produces exact stat deltas per item defs. Requirements enforced. Evaluation documented. Tests pass.

---

## 6. Minimal UI (2–3h)

### Target
`game/arch_rpg/mods/arch_rpg_ui/init.lua`. HUD showing health/mana/stamina bars, XP bar + level, hotbar slots 1–10, equipment paper-doll (10 slots), stat tooltip on hover.

### Steps

- [ ] Create `arch_rpg_ui/{init.lua, mod.conf, formspecs/}`
- [ ] Implement HUD elements via engine HUD API (health/mana/stamina bars, XP bar, level text)
- [ ] Implement hotbar rendering bound to inventory indices 1–10
- [ ] Implement equipment formspec with 10 slot positions matching README §5
- [ ] Implement stat tooltip: on item hover, show name, rarity color, stat bonuses, requirements
- [ ] Subscribe to `arch_rpg_stats.invalidate` events to refresh HUD
- [ ] Subscribe to inventory/equipment change callbacks to refresh UI
- [ ] Test in-game manually (no automated UI tests in Phase 4)
- [ ] Log `[ARCH-RPG:ui]` for errors only (avoid spam)

### Commands

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_ui/formspecs
# Manual in-game testing per ACCEPTANCE.md §A3
```

### Acceptance gate
HUD visible and updates on stat change. Equipment screen shows all 10 slots. Tooltip displays correct stats. No Lua errors in log.

---

## 7. Save migration v1→v2 (1.5–2h)

### Target
`game/arch_rpg/mods/arch_rpg_save/init.lua`. Versioned save format per README §7. Idempotent v1→v2 migration.

### Steps

- [ ] Create `arch_rpg_save/{init.lua, mod.conf}`
- [ ] Implement save/load hooks registering with engine save API
- [ ] Implement v2 schema serialization per README §7.1
- [ ] Implement migration function: detect version < 2 → initialize Warrior defaults → set version=2 → log
- [ ] Ensure unknown fields preserved on load
- [ ] Ensure missing fields filled with defaults + warning log
- [ ] Write `tests/test_save_migration.lua`: create mock v1 save → migrate → verify v2 structure → re-save → reload → identical; verify idempotency (migrate twice = same result)
- [ ] Run `scripts/test.sh --filter test_save_migration` → all pass

### Commands

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_save
scripts/test.sh --filter test_save_migration
```

### Acceptance gate
Migration idempotent. V2 save round-trips correctly. Tests pass.

---

## 8. Integration test script + final verification (1–2h)

### Target
`scripts/test.sh` runs all unit tests. All acceptance criteria from ACCEPTANCE.md verifiable.

### Steps

- [ ] Ensure `scripts/test.sh` discovers and runs all `tests/test_*.lua` files
- [ ] Support `--filter <name>` to run subset
- [ ] Exit 0 only if all tests pass; exit 1 otherwise with summary
- [ ] Verify grep checks from ACCEPTANCE.md §A5 pass (logging prefixes present, no class literals)
- [ ] Document any Unified Inventory decision in completion notes below
- [ ] Final review: README.md ≥150 lines, TASKS.md ≥100 lines, ACCEPTANCE.md ≥60 lines

### Commands

```bash
scripts/test.sh
echo $?
wc -l docs/plans/phase-04-rpg-foundation/{README,TASKS,ACCEPTANCE}.md
```

### Acceptance gate
`scripts/test.sh` exits 0. Line counts meet minimums. PLAN.md unmodified.

---

## Completion notes (fill after execution)

- Unified Inventory evaluation score: ___/21 → Decision: ADOPT / OWN UI
- Total time spent: ___h
- Any deviations from plan: ___
- Follow-up items for Phase 5: ___

---

## Out of scope (defer, do not start)

- Mage/Rogue/Cleric class definitions
- Skill tree implementation (only stub storage)
- Combat damage resolution
- Quest/dialogue/NPC systems
- Vendor/trading/currency earning
- Affix generation logic
- Multiplayer sync beyond server-authoritative save
- Advanced UI features (drag-drop, search, categories)