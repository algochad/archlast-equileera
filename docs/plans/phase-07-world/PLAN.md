# Phase 7 — World + Dungeon + Boss (MVP cap)

Depends on: Phase 6 green. MVP complete at end of this phase.

## Goal

Multi-biome regions + structures + 1 dungeon + 1 boss with phases + unique loot.

## Scope

- `mods/{arch_rpg_world(expanded),arch_rpg_dungeons}`
- Biomes: forest/plains expansion + 1 each mountain/cave; villages/ruins/landmarks stub spawners
- Dungeon: Goblin Cave — entrance, layout (schematic), mobs, locked door/key, boss arena
- Boss: Goblin King — ≥2 phases, AOE/summon, unique loot table entry

## Non-goals

Full 8 dungeon themes, instancing, factions.

## Tasks

1. Deterministic mapgen: biome weights + structure placement tables.
2. Dungeon schematic + spawn/trigger logic + completion event.
3. Boss AI phases + `boss_phase_changed` event + arena mechanics.
4. Smoke: enter → clear → boss → loot unique → exit → save/reload.

## Acceptance

- [ ] Dungeon discoverable via landmark/quest marker; key/door gating works
- [ ] Boss uses specials per phase; kill grants unique item + `dungeon_completed` fires
- [ ] Full MVP smoke (spec §63) passes end-to-end on fresh world
