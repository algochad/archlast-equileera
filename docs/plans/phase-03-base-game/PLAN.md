# Phase 3 — Base Game

Depends on: Phase 2 green.

## Goal

`game/arch_rpg/` boots on fork: one biome, basic terrain/blocks, spawn player, save/load v1.

## Scope

- `game/arch_rpg/{game.conf,game.mt,mods/arch_rpg_core,mods/arch_rpg_world,mods/arch_rpg_player}`
- `arch_rpg_core`: events, registries, logging `[ARCH-RPG:*]`, save_version=1 + migration stub
- One biome + nodes/liquids, deterministic seed, spawn point
- `scripts/run-dev.sh` launches `bin/archlast --gameid arch_rpg --world` by default

## Non-goals

No classes/stats/combat/quests (Phases 4–6). Placeholder textures only.

## Tasks

1. Scaffold `game.conf`, `game.mt` (`gameid = arch_rpg`), core + world + player mods.
2. Register ~10 nodes (stone/dirt/grass/wood/leaves/water/sand) + mapgen biome override.
3. Player spawn + third-person default + save/load persist position.
4. `tests/` smoke: world create → join → move → save → reload position matches.

## Acceptance

- [ ] Game appears in menu as Archlast RPG (not "Luanti + mods")
- [ ] New world generates, player spawns on surface, moves in third-person
- [ ] Save/reload preserves position; `save_version` in save file
- [ ] No `ModError` in log
