# Phase 4 — RPG Foundation

Depends on: Phase 3 green.

## Goal

Stats + XP/levels + 1 class (Warrior) + inventory/equipment/items playable.

## Scope

- `mods/{arch_rpg_stats,arch_rpg_classes,arch_rpg_items,arch_rpg_inventory,arch_rpg_equipment}`
- Stat registry: 6 attributes + derived (per spec §21); single `arch_rpg_stats.get/modify` API
- Class registry; Warrior only; no `if class == "warrior"` scatter
- Items data-driven (`id/name/rarity/stats/slot`), rarity tiers Common→Unique drop weights stubbed
- Inventory: stacks/hotbar/equipment slots per spec §25–26; Unified Inventory evaluated, not depended on

## Non-goals

Other 3 classes, skills, combat damage (Phase 5), quests (Phase 6).

## Tasks

1. Stats module + formulas centralized + unit tests (level curve, derived calc).
2. Warrior def + starting attrs/equipment.
3. Item defs: sword/shield/armor pieces/consumable; equip/unequip applies stats.
4. UI: health/XP/level/hotbar/equipment minimal.

## Acceptance

- [ ] `tests/` unit: stat calc, XP curve, equip modifies derived stats — all pass via `scripts/test.sh`
- [ ] In-game: equip sword → Physical Attack rises; level-up increases Max Health
- [ ] Save/reload preserves level/XP/inventory/equipment
