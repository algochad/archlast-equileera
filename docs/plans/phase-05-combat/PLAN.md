# Phase 5 — Combat (MVP slice)

Depends on: Phase 4 green.

## Goal

Real-time melee: attack/block/dodge + stamina/mana + 3 enemy types + loot drop.

## Scope

- `mods/{arch_rpg_combat,arch_rpg_skills,arch_rpg_mobs,arch_rpg_loot}`
- Central pipeline: validate → accuracy → crit → base → armor/resist → elemental → status → final → event (spec §24)
- Skills: Warrior `Power Strike` only (cooldown + stamina cost); tree stub
- Mobs: 3 types (e.g. Wolf/Goblin/Skeleton) via ONE framework choice (Mobs Redo vs Mobkit vs Creatura — evaluate once, lock); states idle/wander/chase/attack/dead
- Loot tables weighted, level-scaled stub

## Non-goals

Ranged/magic, parry/combos, bosses (Phase 7), multiplayer validation hardening (Phase 9).

## Tasks

1. Lock mob framework; document choice + license in `dependencies/mods.lock`.
2. Implement `arch_rpg_combat.damage(source,target,attack)` + events (`player_damage,mob_killed`).
3. Enemy spawners in test biome + aggro ranges + distance-based AI throttling.
4. Unit tests: damage, crit, armor mitigation, loot weighting. Smoke: kill → XP → loot → level-up.

## Acceptance

- [ ] Melee swing hits, damage numbers vary on crit, armor reduces damage (unit + in-game)
- [ ] Kill 3 mobs → XP gain → level-up event fires → UI updates
- [ ] No globalstep hot loops; entity update profiled, tick budget documented
