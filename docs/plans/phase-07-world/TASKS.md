# Phase 7 Tasks — World + Dungeon + Boss (ordered, MVP cap)

Estimated: 4–6 hours on warm machine with Phase 6 green. Do in order. Stop at first red.

## 1. Prereqs (5 min)

- [ ] Phase 6 acceptance checks all green
- [ ] `engine/archlast-luanti` builds and runs headless
- [ ] `game/arch_rpg/mods/arch_rpg_world/` and `arch_rpg_dungeons/` directories exist (stub or populated)
- [ ] Schematic tooling available (`mtsedit` or engine schematic export confirmed)

```bash
scripts/run-dev.sh --smoke  # must exit 0
ls game/arch_rpg/mods/arch_rpg_world/init.lua
ls game/arch_rpg/mods/arch_rpg_dungeons/init.lua
```

## 2. Biome weights + mapgen (45 min)

- [ ] `mapgen/biomes.lua` defines forest/plains/mountain/cave with weights per README table
- [ ] Noise layers seeded by `world_seed + chunk_hash`; deterministic across runs
- [ ] Blend zones (16 nodes) implemented between biomes
- [ ] Unit test `tests/world/test_biome_weights.lua` passes for seed `archlast-mvp-07`

```bash
# Generate 512x512 region with fixed seed, verify biome counts match weights ±5%
bin/archlast --server --world /tmp/phase7-biome-test --seed archlast-mvp-07 \
  --logfile /tmp/biome-gen.log &
sleep 20 && kill %1
grep -c "biome=forest" /tmp/biome-gen.log   # expect ~35% of samples
grep -c "biome=plains" /tmp/biome-gen.log   # expect ~30%
grep -c "biome=mountain" /tmp/biome-gen.log # expect ~20%
grep -c "biome=cave" /tmp/biome-gen.log     # expect ~15%
```

Time estimate: 30 min implementation + 15 min validation.

## 3. Structure placement + landmark discovery + quest markers (60 min)

- [ ] `mapgen/structures.lua` implements Poisson-disk sampling per structure table
- [ ] Min spacing enforced; max-per-region caps respected
- [ ] Failed placements logged `[ARCH-RPG:WORLD] structure_skip <type> <reason>`
- [ ] `landmarks/registry.lua` registers each spawned structure via `arch_rpg_landmarks.register()`
- [ ] Quest marker entities defined in `landmarks/markers.lua` for village, cave entry, shrine
- [ ] Test `tests/world/test_structure_placement.lua` validates spacing + counts

```bash
# Verify structure counts in generated world
bin/archlast --server --world /tmp/phase7-struct-test --seed archlast-mvp-07 \
  --logfile /tmp/struct-gen.log &
sleep 25 && kill %1
grep "structure_spawned" /tmp/struct-gen.log | sort | uniq -c
# Expect: village ≤2, ruin ≤3, cave_entry ≤4, shrine ≤1, tower ≤1, camp ≤3
grep "structure_skip" /tmp/struct-gen.log  # should be rare; investigate if >3
```

Time estimate: 40 min placement logic + 20 min landmark/quest integration.

## 4. Dungeon schematic + spawn/trigger/gating logic (90 min)

- [ ] `dungeons/goblin_cave/schematic.mts` authored with 7 rooms per README layout
- [ ] `dungeons/goblin_cave/spawns.lua` places mobs/traps/chests at schematic anchor points
- [ ] `dungeons/goblin_cave/triggers.lua` implements key→door gating (server-authoritative)
- [ ] Door node `arch_rpg_dungeons:goblin_cave_boss_door` validates key on right-click
- [ ] Key consumption atomic; no client-side bypass
- [ ] Entrance node + quest marker entity placed at dungeon origin
- [ ] Test `tests/world/test_dungeon_gating.lua` covers: key absent (reject), key present (open + consume), re-open (already open)

```bash
# Manual gating test (headless + admin commands)
bin/archlast --server --world /tmp/phase7-gate-test --seed archlast-mvp-07 &
sleep 15
# In-game/admin: teleport to goblin_cave entrance, attempt door without key → expect reject message
# Give key via admin: /give <player> arch_rpg_dungeons:goblin_cave_key
# Right-click door → expect open, key removed from inventory
# Right-click again → expect already-open state, no key consumed
kill %1
grep "door_opened\|door_rejected" /tmp/phase7-gate-test.log
```

Time estimate: 45 min schematic + spawns, 30 min trigger/gating, 15 min testing.

## 5. Boss AI phases + arena mechanics (90 min)

- [ ] `boss/goblin_king.lua` implements phase 1 and phase 2 stat tables per README
- [ ] Phase transition fires `boss_phase_changed` event with correct payload
- [ ] Phase 1 specials: AOE Slam (12s CD, telegraph), Summon Grunts (75%/55% HP thresholds)
- [ ] Phase 2 specials: Enrage buff, Fire Ring (replaces slam), Summon Shaman (30% HP), Weak Point (2× back damage during summon anim)
- [ ] Arena hazards: destructible pillars (200 HP), lava pools (4 dmg/s), LOS blocking
- [ ] Reset logic: player exits >10s → boss resets, grunts despawn, pillars respawn
- [ ] Test `tests/world/test_boss_phases.lua` validates phase transitions, special firing, reset

```bash
# Boss observation test (requires dev tools or admin godmode)
bin/archlast --server --world /tmp/phase7-boss-test --seed archlast-mvp-07 &
sleep 15
# Teleport to boss arena, aggro king
# Observe phase 1: slam telegraph, grunt summons at 75%/55%
# Damage to <50%: verify phase 2 transition log, enrage visual/SFX
# Observe fire ring, shaman summon at 30%, weak point window
# Exit arena >10s: verify reset log
kill %1
grep -E "boss_phase_changed|boss_special_used|boss_reset" /tmp/phase7-boss-test.log
# Expect: 2x phase_changed (1→2), multiple special_used, 1x reset
```

Time estimate: 50 min AI + specials, 25 min arena + reset, 15 min testing.

## 6. Unique loot + completion rewards (30 min)

- [ ] `loot.lua` registers `goblin_king_crown` with unique flag, stats per README
- [ ] Duplicate prevention: if player owns crown, drop gold 500 instead
- [ ] Completion chest spawns at arena center on boss death
- [ ] `dungeon_completed` event fired with full payload
- [ ] Player save updated: `world_progress.dungeons.goblin_cave` fields set
- [ ] Save migration `migrate_v6_to_v7` tested in `tests/save/test_migration_v7.lua`

```bash
# Loot + completion test
bin/archlast --server --world /tmp/phase7-loot-test --seed archlast-mvp-07 &
sleep 15
# Kill boss (admin /damage or godmode assist)
# Verify completion chest appears, contains crown
# Pick up crown → check inventory
# Kill boss again (respawn via admin) → verify gold drop, no second crown
# Save + reload → verify crown persists, dungeon_completed state preserved
kill %1
grep "dungeon_completed\|unique_loot_drop\|duplicate_prevented" /tmp/phase7-loot-test.log
```

Time estimate: 15 min loot registration, 15 min completion/save integration.

## 7. Full MVP smoke rehearsal (60 min)

- [ ] Fresh world created with seed `archlast-mvp-07`
- [ ] All 17 steps of MVP smoke chain (README §Full MVP Smoke Chain) executed in order
- [ ] Each step's pass criterion verified manually or via log grep
- [ ] No Lua/C++ errors, no missing events, no save corruption
- [ ] Performance: mapgen <30s for 512² region, no frame drops below 30 FPS during structure placement
- [ ] Log clean: no ERROR, segfault, ModError, or assertion failures

```bash
# Full end-to-end smoke (manual playthrough or scripted if available)
rm -rf /tmp/phase7-mvp-smoke
scripts/run-dev.sh --world /tmp/phase7-mvp-smoke --seed archlast-mvp-07 --logfile /tmp/mvp-smoke.log
# Execute steps 1-17 per README table; record pass/fail per step
# After completion:
grep -iE 'error|segfault|moderror|assertion' /tmp/mvp-smoke.log || echo CLEAN
stat /tmp/phase7-mvp-smoke  # verify save exists
# Reload test:
scripts/run-dev.sh --world /tmp/phase7-mvp-smoke --logfile /tmp/mvp-reload.log
# Verify crown in inventory, dungeon state preserved
grep "save_loaded\|world_progress" /tmp/mvp-reload.log
```

Time estimate: 30 min playthrough + 15 min perf/log checks + 15 min reload verification.

## Out of scope (defer, do not start)

- Additional dungeon themes or bosses
- Instancing or per-player dungeon copies
- Faction systems, dynamic world events
- Procedural dungeon generation
- Multiplayer boss sync beyond server events
- Windows/macOS build validation
- Texture/model/audio asset creation (use placeholders licensed CC-BY-SA 4.0 or original)