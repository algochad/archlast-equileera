# Phase 6 Acceptance — RPG Content Testable

All checks runnable in order. Phase 6 passes only if all green.
Logging prefix `[ARCH-RPG:*]` required throughout.

## A1. Unit tests pass

```bash
lua tests/test_quest_objectives.lua && echo QUEST_OK
lua tests/test_dialogue_conditions.lua && echo DIALOGUE_OK
lua tests/test_crafting_recipes.lua && echo CRAFT_OK
lua tests/test_merchant_math.lua && echo MERCHANT_OK
```

Pass: all four print OK suffix, exit 0. Any failure = stop, fix before proceeding.

## A2. Quest lifecycle (accept → track → kill → turn-in → reward)

In dev server session (GUI or headless with dev commands):

```bash
# 1. Talk to Brom, choose "I'll handle it" → quest starts
# 2. Verify tracker shows 4 objectives
# 3. Kill 5 goblins (dev spawn: /spawnmob mob_goblin 5)
# 4. Collect 3 goblin ears (dev give: /giveme item_goblin_ear 3)
# 5. Return to Brom, choose "I've cleared them out" → turn-in
# 6. Verify rewards granted
```

Automated log check after session:

```bash
grep '\[ARCH-RPG:QUEST\] START goblin_trouble' /tmp/archlast-smoke.log && echo START_OK
grep '\[ARCH-RPG:QUEST\] OBJECTIVE_UPDATE goblin_trouble' /tmp/archlast-smoke.log | wc -l | grep -q '[1-9]' && echo TRACK_OK
grep '\[ARCH-RPG:QUEST\] COMPLETE goblin_trouble' /tmp/archlast-smoke.log && echo COMPLETE_OK
```

Pass: START_OK, TRACK_OK, COMPLETE_OK all printed. Journal shows completed quest.

## A3. Dialogue branches on state + persists across reload

```bash
# Session 1: talk to Brom, accept quest, disconnect
# Session 2: reconnect, talk to Brom again
# Expected: "Still working on it?" node (not intro node)
# Complete quest, talk again → "If you need supplies" node
```

Log check:

```bash
grep '\[ARCH-RPG:DIALOGUE\] NODE brom_progress' /tmp/archlast-smoke.log && echo BRANCH_OK
grep '\[ARCH-RPG:DIALOGUE\] NODE brom_thanks' /tmp/archlast-smoke.log && echo POST_QUEST_OK
```

Save check:

```bash
# After reload, inspect player save v3 dialogue table
grep -A5 '"npc_brom"' /path/to/player_save.json | grep 'visited_nodes' && echo PERSIST_OK
```

Pass: BRANCH_OK, POST_QUEST_OK, PERSIST_OK. Dialogue state survives reload.

## A4. Craft sword at workbench

```bash
# Ensure materials: /giveme item_iron_ingot 3 && /giveme item_leather_strip 1
# Interact workbench, select recipe_iron_sword, craft
# Verify item_iron_sword in inventory, materials consumed
```

Log check:

```bash
grep '\[ARCH-RPG:CRAFT\] SUCCESS recipe_iron_sword' /tmp/archlast-smoke.log && echo CRAFT_OK
grep '\[ARCH-RPG:CRAFT\] FAIL' /tmp/archlast-smoke.log && echo UNEXPECTED_FAIL || echo NO_FAIL
```

Pass: CRAFT_OK printed, NO_FAIL printed. Inventory correct.

## A5. Merchant buy/sell adjusts gold

```bash
# Record gold before: note value G0
# Buy item_iron_sword from Brom (price P) → gold should be G0 - P
# Sell item_leather_strip to Brom (sell_ratio 0.5) → gold increases by floor(price * 0.5)
# Record gold after: G1
```

Log check:

```bash
grep '\[ARCH-RPG:ECON\] BUY' /tmp/archlast-smoke.log && echo BUY_LOG_OK
grep '\[ARCH-RPG:ECON\] SELL' /tmp/archlast-smoke.log && echo SELL_LOG_OK
```

Gold arithmetic verified manually or via test_merchant_math.lua. Pass: BUY_LOG_OK, SELL_LOG_OK, gold values match expected.

## A6. Save v3 migration idempotent

```bash
# Create dummy v2 save without quests/dialogue/reputation/economy keys
lua scripts/migrate_save_v2_to_v3.lua /tmp/test_save_v2.json /tmp/test_save_v3a.json
lua scripts/migrate_save_v2_to_v3.lua /tmp/test_save_v3a.json /tmp/test_save_v3b.json
diff /tmp/test_save_v3a.json /tmp/test_save_v3b.json && echo IDEMPOTENT_OK
```

Pass: IDEMPOTENT_OK. New keys present with correct defaults.

## A7. Log hygiene

```bash
grep -iE 'error|segfault|moderror|assertion' /tmp/archlast-smoke.log | grep -v 'known-benign' || echo CLEAN
grep '\[ARCH-RPG:' /tmp/archlast-smoke.log | cut -d']' -f1 | sort -u
```

Pass: CLEAN printed. All `[ARCH-RPG:*]` prefixes are from allowed set: QUEST, DIALOGUE, CRAFT, ECON, NPC. No bare log lines from Phase 6 modules.

## A8. Module dependency direction

```bash
# Gameplay mods must not import UI modules directly
grep -rn "require.*ui" game/arch_rpg/mods/arch_rpg_quests/ game/arch_rpg/mods/arch_rpg_dialogue/ game/arch_rpg/mods/arch_rpg_crafting/ game/arch_rpg/mods/arch_rpg_merchant/ && echo DEPENDENCY_VIOLATION || echo DEPS_OK
```

Pass: DEPS_OK. Communication is event-only.

## Fail → do not proceed

Any red = fix Phase 6 before Phase 7. Record failure + commit hash in `docs/plans/phase-06-rpg-content/RESULTS.md` (create on run).