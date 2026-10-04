# Phase 7 Acceptance — World + Dungeon + Boss Testable

All checks runnable in order. Phase 7 passes only if all green. This completes MVP.

## A1. Biome generation determinism

```bash
rm -rf /tmp/phase7-a1 && mkdir -p /tmp/phase7-a1
bin/archlast --server --world /tmp/phase7-a1 --seed archlast-mvp-07 --logfile /tmp/a1.log &
PID=$!; sleep 20; kill $PID; wait $PID 2>/dev/null
grep -c "biome=forest" /tmp/a1.log    # expect ≥30% of biome samples
grep -c "biome=plains" /tmp/a1.log    # expect ≥25%
grep -c "biome=mountain" /tmp/a1.log  # expect ≥15%
grep -c "biome=cave" /tmp/a1.log      # expect ≥10%
```

Pass: all four biomes present; weight distribution within ±5% of README table. Re-run with same seed produces identical counts.

## A2. Structure placement + landmark discovery

```bash
rm -rf /tmp/phase7-a2 && mkdir -p /tmp/phase7-a2
bin/archlast --server --world /tmp/phase7-a2 --seed archlast-mvp-07 --logfile /tmp/a2.log &
PID=$!; sleep 25; kill $PID; wait $PID 2>/dev/null
grep "structure_spawned" /tmp/a2.log | awk '{print $NF}' | sort | uniq -c
grep "landmark_registered" /tmp/a2.log | wc -l
grep "quest_marker_placed" /tmp/a2.log | wc -l
```

Pass: structure counts within README max-per-region caps; landmark count ≥ structure count (all structures registered); quest markers placed for village, cave entry, shrine.

## A3. Dungeon discoverable via marker

```bash
# Requires running server from A2 or fresh start
# Admin/teleport to origin, interact with cave entrance marker
# Expected: quest "Clear the Goblin Cave" added, minimap icon visible
grep "quest_added.*goblin_cave" /tmp/a2.log
grep "minimap_icon.*goblin_cave" /tmp/a2.log
```

Pass: both log lines present; quest journal shows active dungeon quest.

## A4. Key→door gating test

```bash
rm -rf /tmp/phase7-a4 && mkdir -p /tmp/phase7-a4
bin/archlast --server --world /tmp/phase7-a4 --seed archlast-mvp-07 --logfile /tmp/a4.log &
PID=$!; sleep 15
# Test 1: attempt door without key → expect rejection
# (via admin command or in-game interaction; log captures result)
# Test 2: give key, open door → expect success + key consumed
# Test 3: re-interact opened door → expect no-op
kill $PID; wait $PID 2>/dev/null
grep "door_rejected.*key_missing" /tmp/a4.log
grep "door_opened.*goblin_cave" /tmp/a4.log
grep "key_consumed.*goblin_cave_key" /tmp/a4.log
```

Pass: all three log lines present in order; no duplicate key consumption; door state persisted.

## A5. Boss phase + specials observation checklist

```bash
rm -rf /tmp/phase7-a5 && mkdir -p /tmp/phase7-a5
bin/archlast --server --world /tmp/phase7-a5 --seed archlast-mvp-07 --logfile /tmp/a5.log &
PID=$!; sleep 15
# Aggro boss, observe through phase transitions (admin assist if needed)
kill $PID; wait $PID 2>/dev/null
echo "=== Phase transitions ==="
grep "boss_phase_changed" /tmp/a5.log
echo "=== Specials used ==="
grep "boss_special_used" /tmp/a5.log | awk '{print $NF}' | sort | uniq -c
echo "=== Reset (if tested) ==="
grep "boss_reset" /tmp/a5.log
```

Pass checklist:
- [ ] ≥2 `boss_phase_changed` events (phase 1→2 at ~50% HP)
- [ ] Phase 1 specials observed: `aoe_slam`, `summon_grunts`
- [ ] Phase 2 specials observed: `fire_ring`, `summon_shaman` (at ~30% HP)
- [ ] Enrage buff logged on phase 2 transition
- [ ] Reset triggers if player exits arena >10s (optional test)

## A6. Unique loot + dungeon_completed event

```bash
# Continue from A5 or fresh boss kill
grep "dungeon_completed" /tmp/a5.log
grep "unique_loot_drop.*goblin_king_crown" /tmp/a5.log
# Reload test:
bin/archlast --server --world /tmp/phase7-a5 --logfile /tmp/a5-reload.log &
PID=$!; sleep 10; kill $PID; wait $PID 2>/dev/null
grep "save_loaded" /tmp/a5-reload.log
grep "world_progress.*goblin_cave.*completed=true" /tmp/a5-reload.log
```

Pass: `dungeon_completed` payload includes dungeon_id, player, timestamp, loot list; crown in inventory post-pickup; save reload preserves completed state and crown.

## A7. Full MVP end-to-end smoke chain

Execute all 17 steps from README §Full MVP Smoke Chain on a **fresh** world. Record pass/fail per step.

```bash
rm -rf /tmp/phase7-mvp && mkdir -p /tmp/phase7-mvp
scripts/run-dev.sh --world /tmp/phase7-mvp --seed archlast-mvp-07 --logfile /tmp/mvp-full.log
# Manual or scripted execution of steps 1-17; annotate results below
```

Per-step pass criteria (must ALL pass):

| Step | Pass Criterion | Verified? |
|------|-----------------------------------------------------------------|-----------|
| 1 | Character created, class selected | [ ] |
| 2 | Biome transition logged, no mapgen stall | [ ] |
| 3 | Damage dealt to dummy mob, combat log entry | [ ] |
| 4 | XP gained, level-up threshold reachable | [ ] |
| 5 | Level up applied, skill point awarded | [ ] |
| 6 | Basic item looted, added to inventory | [ ] |
| 7 | Item equipped, stats recalculated | [ ] |
| 8 | Quest accepted from NPC, journal updated | [ ] |
| 9 | Dialogue completed, dungeon hint received | [ ] |
| 10 | Dungeon entrance discovered, landmark registered | [ ] |
| 11 | Key found, objective updated | [ ] |
| 12 | Boss door opened, key consumed | [ ] |
| 13 | Boss phase 1→2 transition observed, specials fired | [ ] |
| 14 | Boss killed, `dungeon_completed` fired | [ ] |
| 15 | Unique loot collected, achievement unlocked | [ ] |
| 16 | Save written, version 7, no errors | [ ] |
| 17 | Reload successful, state preserved, crown retained | [ ] |

Pass: all 17 checkboxes marked; no Lua/C++ errors in `/tmp/mvp-full.log`.

## A8. Performance check

```bash
# Mapgen timing (from A1/A2 logs)
grep -E "mapgen_complete|chunk_generated" /tmp/a1.log | tail -1
# Expect: 512x512 region generated in <30s on reference hardware
# Frame rate during structure placement (requires GUI or profiling hook)
grep "fps_min" /tmp/mvp-full.log  # expect ≥30
```

Pass: mapgen duration <30s; no sustained FPS drops below 30 during structure-heavy generation.

## A9. Log cleanliness

```bash
grep -iE 'error|segfault|moderror|assertion|fatal' /tmp/mvp-full.log || echo CLEAN
grep -iE 'error|segfault|moderror|assertion|fatal' /tmp/a5-reload.log || echo CLEAN
```

Pass: CLEAN output for both logs. Known-benign warnings must be documented with justification.

## Fail → do not proceed

Any red = fix Phase 7 before declaring MVP complete. Record failure + commit hash in `docs/plans/phase-07-world/RESULTS.md` (create on run). MVP is not shipped until all A1–A9 pass on a single fresh world.