# Phase 6 — RPG Content (MVP slice)

Depends on: Phase 5 green.

## Goal

1 NPC + 1 quest + dialogue tree + crafting stub + merchant buy/sell.

## Scope

- `mods/{arch_rpg_quests,arch_rpg_dialogue,arch_rpg_npcs,arch_rpg_crafting}`
- Quest: data-driven def (objectives/rewards/prereqs); types used: kill + talk + collect
- Dialogue: branching tree with class/level/item conditions; quest start/turn-in hooks
- NPC role: quest-giver + merchant (one entity, two roles acceptable for MVP)
- Crafting: workbench + 3 recipes (weapon/armor/consumable); gathering stub (wood/ore drops)

## Non-goals

Full quest chains, factions/reputation, economy balancing.

## Tasks

1. Quest registry + `start/complete` API + tracker/journal UI.
2. Dialogue UI + condition evaluator + state persistence.
3. Merchant inventory + gold centrality (`arch_rpg` economy module stub).
4. Tests: quest objective completion, dialogue conditions, recipe craft.

## Acceptance

- [ ] Accept quest → kill N → turn in → reward + XP, tracker updates live
- [ ] Dialogue branches on quest state; choices persist across reload
- [ ] Craft sword at workbench from loot drops; merchant buy/sell adjusts gold
