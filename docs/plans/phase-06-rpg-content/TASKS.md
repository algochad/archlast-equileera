# Phase 6 Tasks — RPG Content (ordered, testable)

Estimated: 4–6 hours on warm machine. Do in order. Stop at first red.
All paths relative to repo root. Logging prefix `[ARCH-RPG:*]` mandatory.

## 1. Quest registry + start/complete API (45 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_quests/init.lua` with mod registration
- [ ] Implement `quests.register(def)` validating schema (id, name, objectives[], rewards{})
- [ ] Implement `quests.start(player, quest_id)` checking prereqs, emitting `[ARCH-RPG:QUEST] START`
- [ ] Implement `quests.update_objective(player, quest_id, obj_index, delta)` server-authoritative
- [ ] Implement `quests.complete(player, quest_id)` granting rewards atomically, emitting `[ARCH-RPG:QUEST] COMPLETE`
- [ ] Implement `quests.fail(player, quest_id, reason)` emitting `[ARCH-RPG:QUEST] FAIL`
- [ ] Add `goblin_trouble.lua` data file per README worked example
- [ ] Register quest in `init.lua` via `dofile`

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_quests/data
touch game/arch_rpg/mods/arch_rpg_quests/init.lua
touch game/arch_rpg/mods/arch_rpg_quests/data/goblin_trouble.lua
```

## 2. Quest tracker / journal UI via events (30 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_quests/tracker.lua` subscribing to QUEST events
- [ ] Emit `[ARCH-RPG:QUEST] OBJECTIVE_UPDATE <id> <idx> <cur> <target>` on every update
- [ ] Tracker state is read-only projection; NEVER mutates quest data
- [ ] Verify no direct UI calls from gameplay modules (lint: `no-gameplay-ui-import`)

```bash
touch game/arch_rpg/mods/arch_rpg_quests/tracker.lua
grep -rn "ui\." game/arch_rpg/mods/arch_rpg_quests/ && echo FAIL || echo PASS
```

## 3. Dialogue engine + condition evaluator (60 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_dialogue/init.lua`
- [ ] Implement `dialogue.load_tree(tree_id)` returning node map
- [ ] Implement `dialogue.eval_condition(cond, ctx)` pure function for all condition types
- [ ] Implement `dialogue.open(player, npc_id, tree_id)` emitting `[ARCH-RPG:DIALOGUE] OPEN`
- [ ] Implement `dialogue.choose(player, node_id, choice_index)` evaluating conditions server-side, applying effects, emitting `[ARCH-RPG:DIALOGUE] NODE`
- [ ] Unknown condition type returns false + logs WARN, never crashes
- [ ] Add `brom_tree.lua` per README 6-node worked example

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_dialogue/data
touch game/arch_rpg/mods/arch_rpg_dialogue/init.lua
touch game/arch_rpg/mods/arch_rpg_dialogue/data/brom_tree.lua
```

## 4. Dialogue UI + persistence (30 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_dialogue/ui.lua` subscribing to DIALOGUE events
- [ ] Persist visited nodes + flags in player save v3 `dialogue` table
- [ ] On load, restore dialogue state; missing keys default to empty
- [ ] Client condition eval mirrors server; mismatch logs WARN, server wins

```bash
touch game/arch_rpg/mods/arch_rpg_dialogue/ui.lua
```

## 5. NPC entity + roles table (30 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_npcs/init.lua`
- [ ] Define `npc_brom.lua` per README (quest_giver + merchant dual role)
- [ ] Implement `npcs.interact(player, npc_id)` dispatching to role handlers
- [ ] Schedule stub present but not functional; log `[ARCH-RPG:NPC] schedule stub` on access
- [ ] Position static; no pathfinding this phase

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_npcs/data
touch game/arch_rpg/mods/arch_rpg_npcs/init.lua
touch game/arch_rpg/mods/arch_rpg_npcs/data/npc_brom.lua
```

## 6. Crafting stations + recipes (45 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_crafting/init.lua`
- [ ] Implement `crafting.craft(player, recipe_id)` validating station proximity, materials, level
- [ ] Atomic transaction: deduct materials + grant output in single callback
- [ ] Emit `[ARCH-RPG:CRAFT] SUCCESS` or `[ARCH-RPG:CRAFT] FAIL <reason>`
- [ ] Add `recipes.lua` with 3 worked recipes per README
- [ ] Gathering stub: mob drops + loot chest tables only; no world nodes

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_crafting/data
touch game/arch_rpg/mods/arch_rpg_crafting/init.lua
touch game/arch_rpg/mods/arch_rpg_crafting/data/recipes.lua
```

## 7. Merchant + gold centrality (45 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_merchant/init.lua`
- [ ] Implement `merchant.buy(player, npc_id, item_id, qty)` checking gold, stock
- [ ] Implement `merchant.sell(player, npc_id, item_id, qty)` applying sell_ratio
- [ ] Implement `merchant.repair(player, npc_id, item_id)` durability math per README
- [ ] All transactions emit `[ARCH-RPG:ECON]` with before/after gold
- [ ] Gold stored in player save v3 `economy.gold`; no barter, no alt currency
- [ ] Add `merchant_brom_stock.lua` with initial inventory

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_merchant/data
touch game/arch_rpg/mods/arch_rpg_merchant/init.lua
touch game/arch_rpg/mods/arch_rpg_merchant/data/merchant_brom_stock.lua
```

## 8. Save format v3 migration (20 min)

- [ ] Create `scripts/migrate_save_v2_to_v3.lua`
- [ ] Add `quests`, `dialogue`, `reputation`, `economy` keys with defaults
- [ ] Idempotent: running twice produces same result
- [ ] Tested in ACCEPTANCE A6

```bash
touch scripts/migrate_save_v2_to_v3.lua
chmod +x scripts/migrate_save_v2_to_v3.lua
```

## 9. Unit tests (60 min)

- [ ] `tests/test_quest_objectives.lua`: start, update, complete, fail, prereq gate
- [ ] `tests/test_dialogue_conditions.lua`: all condition types, unknown type returns false
- [ ] `tests/test_crafting_recipes.lua`: valid craft, missing material, wrong station, level gate
- [ ] `tests/test_merchant_math.lua`: buy/sell/repair gold arithmetic, insufficient gold, sell ratio

```bash
mkdir -p tests
touch tests/test_quest_objectives.lua
touch tests/test_dialogue_conditions.lua
touch tests/test_crafting_recipes.lua
touch tests/test_merchant_math.lua
```

Run all unit tests:

```bash
lua tests/test_quest_objectives.lua
lua tests/test_dialogue_conditions.lua
lua tests/test_crafting_recipes.lua
lua tests/test_merchant_math.lua
```

## 10. Integration smoke (30 min)

- [ ] Launch dev server via `scripts/run-dev.sh`
- [ ] Accept goblin_trouble via Brom dialogue
- [ ] Kill 5 goblins, collect 3 ears (dev spawn commands if needed)
- [ ] Turn in, verify rewards + XP + gold + journal update
- [ ] Craft iron sword at workbench
- [ ] Buy/sell with Brom, verify gold changes
- [ ] Reload world, verify quest/dialogue/gold persisted
- [ ] Check logs for `[ARCH-RPG:*]` prefixes, no ERROR/WARN unexpected

```bash
scripts/run-dev.sh --smoke
grep -E '\[ARCH-RPG:' /tmp/archlast-smoke.log | head -20
grep -iE 'error|warn' /tmp/archlast-smoke.log | grep -v 'known-benign' || echo CLEAN
```

## Out of scope (defer, do not start)

Quest chains, faction reputation beyond stub, economy balancing, NPC schedules/pathfinding, additional crafting stations, gathering world nodes, UI polish, multiplayer replication beyond Phase 9 baseline.