# Plans Index

Speed priority: **Phase 1 first**. Later phases sketch boundaries so Phase 1 decisions don't block them.

| Phase | Dir | Goal | Entry criteria |
|---|---|---|---|
| 1 | `phase-01-fork-engine-prototype/` | Buildable/runnable Luanti fork + smoke | Empty repo — start NOW |
| 2 | `phase-02-engine-rpg-foundations/` | Third-person camera/controller/animation API | Phase 1 acceptance green |
| 3 | `phase-03-base-game/` | `arch_rpg` boots, 1 biome, save/load v1 | Phase 2 green |
| 4 | `phase-04-rpg-foundation/` | Stats/XP/Warrior/items/inventory | Phase 3 green |
| 5 | `phase-05-combat/` | Melee + 3 mobs + loot | Phase 4 green |
| 6 | `phase-06-rpg-content/` | 1 NPC + 1 quest + dialogue + crafting | Phase 5 green |
| 7 | `phase-07-world/` | Dungeon + boss → MVP complete | Phase 6 green |
| 8 | `phase-08-presentation/` | Textures/models/UI/audio | MVP green |
| 9 | `phase-09-multiplayer/` | Server authority + packaging | Phase 8 green |

## Phase 1 artifacts (full detail)

- `phase-01-fork-engine-prototype/README.md` — goal, exit criteria, layout, speed decisions
- `phase-01-fork-engine-prototype/TASKS.md` — ordered 30–90 min checklist
- `phase-01-fork-engine-prototype/ACCEPTANCE.md` — runnable pass/fail commands

## Phases 2–9 artifacts (one `PLAN.md` each)

Goal/scope/non-goals/tasks/acceptance. Expand to README+TASKS+ACCEPTANCE only when phase becomes active.

## Rules (all phases)

Spec §§82–83 apply: smallest correct slice, Lua-first, clean engine API before internals, test against real game, pin + verify licenses, never claim green without log evidence.
