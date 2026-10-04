# Phase 7 — World + Dungeon + Boss (MVP Cap)

Depends on: Phase 6 green. This phase completes the MVP; no further gameplay phases are required for a playable vertical slice.

## Goal

Deliver a deterministic multi-biome world with discoverable structures, one fully gated dungeon (Goblin Cave), and one phased boss (Goblin King) that awards unique loot and fires `dungeon_completed`. The MVP smoke chain (spec §63) must pass end-to-end on a fresh world generated from a fixed seed.

## Non-goals

- Other 7 dungeon themes (desert tomb, ice citadel, sunken temple, etc.) — deferred to post-MVP content packs.
- Instancing or per-player dungeon copies — single shared world state only.
- Faction reputation systems, dynamic world events, seasonal biomes.
- Procedural dungeon layout generation — hand-authored schematic only for MVP.
- Boss difficulty scaling beyond the two defined phases.
- Multiplayer synchronization of boss phase transitions beyond server-authoritative event broadcast.

## Exit criteria (must all pass)

1. Fresh world from seed `archlast-mvp-07` generates at least 4 biomes (forest, plains, mountain, cave) with weights matching the biome table below.
2. At least one village, one ruin, and one shrine spawn in expected biomes and appear on the landmark discovery UI.
3. Goblin Cave entrance is discoverable via quest marker or landmark interaction within 500 nodes of world origin.
4. Key→door gating blocks boss arena access until `goblin_cave_key` is in player inventory; door opens on use and consumes/removes key per design.
5. Goblin King transitions through ≥2 phases, uses AOE + summon + enrage mechanics, and fires `boss_phase_changed` with correct payload on each transition.
6. Killing Goblin King drops `goblin_king_crown` (unique loot entry) and fires `dungeon_completed` with dungeon id `goblin_cave`.
7. Full MVP smoke chain (see §Full MVP Smoke Chain) passes without Lua/C++ errors, save corruption, or missing events.
8. Mapgen for a 512×512 chunk region completes in <30s on reference hardware (Ryzen 5 5600X or equivalent); no frame drops below 30 FPS during structure placement.

## Layout after this phase

```text
game/arch_rpg/mods/arch_rpg_world/
├── mapgen/
│   ├── biomes.lua              # biome definitions + weight table
│   ├── structures.lua          # structure placement rules
│   └── decorations.lua         # surface props, trees, ores
├── landmarks/
│   ├── registry.lua            # landmark discovery API
│   └── markers.lua             # quest/marker entity defs
└── init.lua

game/arch_rpg/mods/arch_rpg_dungeons/
├── dungeons/
│   └── goblin_cave/
│       ├── manifest.lua        # metadata, objectives, rewards
│       ├── schematic.mts       # Minetest schematic file (5-7 rooms)
│       ├── spawns.lua          # mob/trap/chest placement
│       ├── triggers.lua        # key/door/boss activation
│       └── boss/
│           ├── goblin_king.lua # AI phases + specials
│           └── arena.lua       # arena hazards, pillars, LOS
├── api.lua                     # register/start/complete/public events
├── loot.lua                    # unique loot table entries
└── init.lua

tests/world/
├── test_biome_weights.lua
├── test_structure_placement.lua
├── test_dungeon_gating.lua
├── test_boss_phases.lua
└── test_mvp_smoke.lua
```

## Biome table (deterministic, seed-driven)

| Biome     | Weight | Elevation Range | Humidity Range | Temp Range | Seed Determinism                          | Notes                                  |
|-----------|--------|-----------------|----------------|------------|-------------------------------------------|----------------------------------------|
| Forest    | 35     | 0–40            | 40–80          | 20–60      | Perlin noise layer 0, scale 256           | Default starting biome near origin     |
| Plains    | 30     | 0–20            | 20–50          | 30–70      | Perlin noise layer 1, scale 512           | Open terrain, village-preferred        |
| Mountain  | 20     | 40–120          | 10–40          | 0–30       | Perlin noise layer 2, scale 128 + ridge   | Cave entrances, tower sites            |
| Cave      | 15     | -64–-10         | 50–90          | 10–40      | 3D Perlin layer 3, scale 64, threshold 0.6| Underground only, dungeon-preferred    |

Weights are relative; actual selection uses weighted cumulative distribution seeded by `world_seed + chunk_hash`. Identical seeds produce identical biome maps across runs. Biome transitions use 16-node blend zones to avoid hard edges.

## Structure placement table

| Structure   | Preferred Biome(s)      | Min Spacing (nodes) | Max Per Region (512²) | Placement Rules                                                                 | Landmark Discovery         | Quest Marker? |
|-------------|-------------------------|---------------------|-----------------------|---------------------------------------------------------------------------------|----------------------------|---------------|
| Village     | Plains, Forest          | 800                 | 2                     | Flat area ≥32×32, elevation 0–20, road-connectable                              | Yes — "Settlement" type    | Yes (main hub)|
| Ruin        | Forest, Mountain        | 600                 | 3                     | Partial burial allowed, adjacent to path or river                               | Yes — "Ancient Site" type  | Optional      |
| Cave Entry  | Mountain, Cave          | 400                 | 4                     | Slope ≥30°, exposed stone face, connects to underground biome                   | Yes — "Cave Mouth" type    | Yes (dungeon) |
| Shrine      | Forest, Plains          | 1000                | 1                     | Elevated or clearing, 8-node radius clear of mobs                               | Yes — "Sacred Site" type   | Yes (blessing)|
| Tower       | Mountain                | 1200                | 1                     | Peak or ridge, foundation on solid stone, LOS to valley                         | Yes — "Watchtower" type    | No            |
| Camp        | Plains, Forest edge     | 500                 | 3                     | Near water or road, 16×16 flat, fire-safe zone                                  | No (ambient only)          | No            |

Placement uses Poisson-disk sampling seeded per region to guarantee spacing. Structures that fail validation after 3 retries are skipped (logged `[ARCH-RPG:WORLD] structure_skip`). Landmark discovery registers each spawned structure with `arch_rpg_landmarks.register()`; UI reads from this registry, never scans map directly.

## Dungeon design: Goblin Cave

### Entrance & discovery

- Located in Cave biome beneath Mountain surface entry, or standalone Cave biome pocket within 500 nodes of origin.
- Entrance marked by carved stone archway node (`arch_rpg_dungeons:goblin_cave_entrance`) + quest marker entity.
- Interaction with marker adds "Clear the Goblin Cave" quest to player journal and reveals minimap icon.

### Layout (5–7 rooms, schematic format)

Schematic stored as `goblin_cave/schematic.mts` (Minetest Schematic Format v3). Rooms:

1. **Entry Hall** (12×10×6): tutorial chest (basic potion), 2 goblin scouts, tripwire trap.
2. **Guard Barracks** (10×8×5): 4 goblin warriors, weapon rack loot, alarm bell (summons room 3 if triggered).
3. **Trap Corridor** (16×4×4): pressure plates → spike pits, dart dispensers, safe path requires observation.
4. **Storage Chamber** (8×8×5): locked chest (`goblin_cave_key` inside), 2 goblin archers, flammable barrels.
5. **Shaman Den** (10×10×6): miniboss goblin shaman (heals others), altar lore note, unlocks boss door hint.
6. **Boss Antechamber** (8×6×5): final save point (bedroll node), buff shrine, door requiring `goblin_cave_key`.
7. **Boss Arena** (20×20×10): Goblin King encounter, destructible pillars, hazard zones, exit portal.

Room count is fixed at 7 for MVP; schematic is hand-authored, not procedurally assembled. Schematic license: original work by project artists, CC-BY-SA 4.0; no third-party assets embedded.

### Mobs, traps, loot, objectives

| Element             | Count / Spec                                                | Trigger / Condition                     | Reward / Effect                        |
|---------------------|-------------------------------------------------------------|-----------------------------------------|----------------------------------------|
| Goblin Scout        | 2 (Entry Hall)                                              | Always active                           | XP 15, copper coin                     |
| Goblin Warrior      | 4 (Barracks)                                                | Alarm bell summons from idle            | XP 25, iron scrap                      |
| Spike Trap          | 3 (Corridor)                                                | Pressure plate, 5s cooldown             | 8 damage, bleed 3s                     |
| Dart Dispenser      | 2 (Corridor)                                                | Light beam break, 8s cooldown           | 5 poison damage, slow 2s               |
| Goblin Archer       | 2 (Storage)                                                 | Ranged aggro on entry                   | XP 20, bone arrow                      |
| Goblin Shaman       | 1 (Shaman Den)                                              | Heals allies ≤50% HP, channel 3s        | XP 50, mana herb, lore note            |
| `goblin_cave_key`   | 1 (Storage locked chest)                                    | Chest unlock (lockpick or warrior drop) | Opens Boss Antechamber door            |
| Boss Door           | 1 (Antechamber → Arena)                                     | Right-click with key in inventory       | Consumes key, opens permanently        |
| Completion Chest    | 1 (Arena, post-boss)                                        | `dungeon_completed` fired               | Gold 200, rare gem, achievement        |

Objectives tracked via `arch_rpg_quests`: "Enter Goblin Cave", "Find the Key", "Defeat the Goblin King". All update on corresponding events.

### Key→door gating

- Door node: `arch_rpg_dungeons:goblin_cave_boss_door`. On right-click, checks `inv:contains_item("main", "arch_rpg_dungeons:goblin_cave_key")`.
- If key present: removes 1 key, swaps node to open variant, plays sound, logs `[ARCH-RPG:DUNGEON] door_opened goblin_cave`.
- If key absent: shows HUD message "Requires Goblin Cave Key", no state change.
- Server-authoritative: client prediction disabled; door state synced via `core.set_node` + network update. No client-side bypass possible.

### Completion event

On Goblin King death:
1. Spawn completion chest at arena center.
2. Fire `dungeon_completed` with payload `{dungeon_id="goblin_cave", player=<name>, timestamp=<os.time>, loot={"goblin_king_crown"}}`.
3. Update player save: `world_progress.dungeons.goblin_cave = {completed=true, completed_at=<ts>, boss_killed=true}`.
4. Unlock post-dungeon quest "Return to Village Elder".

## Boss design: Goblin King

### Stats per phase

| Stat              | Phase 1 (HP 100%–50%) | Phase 2 (HP <50%)     | Notes                                |
|-------------------|------------------------|------------------------|--------------------------------------|
| HP                | 800                    | 800 (no heal)          | Total 800; phase 2 starts at 400 HP  |
| Melee Damage      | 18                     | 24 (+33%)              | Enrage modifier applied              |
| Attack Speed      | 1.8s                   | 1.2s                   | Faster swings in phase 2             |
| Move Speed        | 2.5 nodes/s            | 3.5 nodes/s            | Aggressive repositioning             |
| Armor             | 12                     | 8 (-33%)               | Weak point exposed in phase 2        |
| Regen             | 0                      | 2 HP/s                 | Only during summon downtime          |
| Status Immunity   | None                   | Stun, Knockback        | Prevents cheese in phase 2           |

### Phase mechanics & specials

**Phase 1 (100% → 50% HP):**
- **AOE Slam**: every 12s, 5-node radius, 15 damage + 2s stun. Telegraphed by ground rune 1.5s before impact. Safe zone: behind pillars.
- **Summon Grunts**: at 75% and 55% HP, spawns 2 goblin warriors at arena edges. Grunts despawn after 30s or on boss phase change.
- **Weak Point**: none. Standard armor applies.
- **Pattern**: melee ×3 → slam → pause 2s → repeat. Predictable for learning.

**Phase 2 (<50% HP):**
- **Enrage**: damage/speed buffs applied immediately on transition. Visual: red particle aura, growl SFX.
- **AOE Fire Ring**: replaces slam. Expanding ring from boss, 6-node max radius, 10 fire damage + burn 4s. Safe zone: center pillar cluster.
- **Summon Shaman**: once at 30% HP. Shaman heals boss 5 HP/s for 10s unless killed. Priority target.
- **Weak Point Exposed**: back hitbox takes 2× damage during summon animation (3s window). Rewards positioning.
- **Pattern**: melee ×2 → fire ring → summon (if threshold) → melee ×4 → repeat. Less predictable, rewards adaptation.

### Arena mechanics

- **Destructible Pillars**: 4 pillars, 200 HP each. Blocking LOS prevents ranged specials; destroying pillar removes cover but creates rubble (slow zone).
- **Hazard Zones**: 2 lava pools (fixed positions), 4 damage/s. Respawn after 60s if drained by pillar destruction.
- **LOS Checks**: boss specials require line-of-sight to target. Pillars block; rubble does not.
- **Reset**: if player exits arena for >10s, boss resets to phase 1 start HP, grunts despawn, pillars respawn. Logged `[ARCH-RPG:BOSS] reset goblin_king`.

### Events

- `boss_phase_changed`: fired on every phase transition. Payload: `{boss_id="goblin_king", phase=<1|2>, hp_percent=<int>, timestamp=<os.time>}`. Listeners: UI (phase indicator), audio (SFX swap), analytics.
- `boss_special_used`: fired on each special. Payload: `{boss_id, special_name, targets=[...], timestamp}`. Used for combat log.
- Server-authoritative: all phase logic runs server-side. Client receives events for rendering only. No client-side HP or phase state.

## Unique loot entry

| Item ID                  | Name               | Type       | Rarity | Source              | Stats / Effect                              | Stack | Tradeable |
|--------------------------|--------------------|------------|--------|---------------------|---------------------------------------------|-------|-----------|
| `arch_rpg_dungeons:goblin_king_crown` | Goblin King's Crown | Head Armor | Unique | Goblin King (phase 2 kill) | DEF +8, +10% XP gain, "King Slayer" title | 1     | No        |

Registered in `arch_rpg_items` with `unique=true` flag. Duplicate drops prevented: if player already owns crown, boss drops gold 500 instead. Loot table entry: `{item="arch_rpg_dungeons:goblin_king_crown", chance=1.0, condition="boss_kill", unique_check=true}`.

## Dungeon module API (`arch_rpg_dungeons`)

```lua
-- Register a new dungeon definition. Called at mod load time.
-- @param def table: {id, name, entrance_node, schematic_path, objectives, rewards, boss_id}
-- @return boolean success
arch_rpg_dungeons.register(def)

-- Start a dungeon run for a player. Sets active dungeon state, enables triggers.
-- @param player ObjectRef
-- @param dungeon_id string
-- @return boolean success, string? error_reason
arch_rpg_dungeons.start(player, dungeon_id)

-- Complete a dungeon run. Fires dungeon_completed, updates save, grants rewards.
-- @param player ObjectRef
-- @param dungeon_id string
-- @param result table: {boss_killed=bool, time_seconds=int, deaths=int}
-- @return boolean success
arch_rpg_dungeons.complete(player, dungeon_id, result)

-- Public read-only query
-- @return table|nil dungeon_def
arch_rpg_dungeons.get(dungeon_id)

-- Event listeners (register once at mod init)
core.register_on_event("dungeon_completed", function(payload) ... end)
core.register_on_event("boss_phase_changed", function(payload) ... end)
```

All API functions are server-authoritative. Client mods MAY listen to events but MUST NOT call `start`/`complete` directly. Validation: `start` checks player not already in dungeon; `complete` checks dungeon was started and boss is dead.

## World-progression save additions

Player save schema extended under `world_progress`:

```lua
world_progress = {
    dungeons = {
        goblin_cave = {
            completed = false,        -- bool
            completed_at = nil,       -- os.time or nil
            boss_killed = false,      -- bool
            best_time_seconds = nil,  -- int or nil
            attempts = 0              -- int
        }
    },
    landmarks_discovered = {},        -- set of landmark ids
    structures_visited = {}           -- set of structure instance ids
}
```

Save migration: Phase 7 adds `migrate_v6_to_v7(save)` in `arch_rpg_save`. Existing saves without `world_progress` get default empty table. Version bumped to 7 in `save.version`. Migration tested in `tests/save/test_migration_v7.lua`.

## Full MVP smoke chain (spec §63 mapping)

| Step | Action                                      | Spec §63 Ref | Pass Criterion                                                  | Module / Event                     |
|------|---------------------------------------------|--------------|-----------------------------------------------------------------|------------------------------------|
| 1    | Create character                            | §63.1        | Character created, class selected                               | `arch_rpg_chars`                   |
| 2    | Move to first biome                         | §63.2        | Biome transition logged, no mapgen stall                        | `arch_rpg_world`                   |
| 3    | Attack dummy mob                            | §63.3        | Damage dealt, combat log entry                                  | `arch_rpg_combat`                  |
| 4    | Kill mob, gain XP                           | §63.4        | XP added, level-up available at threshold                       | `arch_rpg_stats`                   |
| 5    | Level up                                    | §63.5        | Stats increased, skill point awarded                            | `arch_rpg_classes`                 |
| 6    | Loot basic item                             | §63.6        | Item added to inventory                                         | `arch_rpg_items`                   |
| 7    | Equip item                                  | §63.7        | Equipment slot updated, stats recalculated                      | `arch_rpg_equipment`               |
| 8    | Accept quest from NPC                       | §63.8        | Quest active in journal                                         | `arch_rpg_quests`                  |
| 9    | Talk to NPC, receive dungeon hint           | §63.9        | Dialogue completes, marker appears                              | `arch_rpg_dialogue`                |
| 10   | Discover dungeon entrance                   | §63.10       | Landmark registered, quest updated                              | `arch_rpg_landmarks`               |
| 11   | Enter dungeon, find key                     | §63.11       | Key in inventory, objective updated                             | `arch_rpg_dungeons`                |
| 12   | Unlock boss door                            | §63.12       | Door opens, key consumed                                        | `arch_rpg_dungeons`                |
| 13   | Fight boss, observe phase 1 → 2 transition  | §63.13       | `boss_phase_changed` fired twice, specials observed             | `arch_rpg_dungeons.boss`           |
| 14   | Kill boss                                   | §63.14       | `dungeon_completed` fired, unique loot dropped                  | `arch_rpg_dungeons`                |
| 15   | Collect unique loot                         | §63.15       | Crown in inventory, achievement unlocked                        | `arch_rpg_items`, `arch_rpg_achievements` |
| 16   | Save game                                   | §63.16       | Save file written, version 7, no errors                         | `arch_rpg_save`                    |
| 17   | Reload save                                 | §63.17       | World loads, dungeon state preserved, crown retained            | `arch_rpg_save`                    |

All steps must execute in order on a single fresh world. Any failure invalidates MVP.

## Risks & mitigations

| Risk                              | Likelihood | Impact | Mitigation                                                                 |
|-----------------------------------|------------|--------|----------------------------------------------------------------------------|
| Mapgen perf exceeds 30s budget    | Medium     | High   | Profile early; reduce decoration density; cache noise layers; LOD culling  |
| Schematic licensing conflict      | Low        | High   | Audit all assets pre-commit; maintain asset manifest with license per file |
| Boss phase desync in multiplayer  | Medium     | Medium | Server-authoritative only; client renders events, never computes state     |
| Key duplication exploit           | Low        | Medium | Server validates key consumption atomically; no client-side inventory edit |
| Save migration breaks old worlds  | Low        | High   | Migration unit tests; backup prompt on first load; rollback path documented|
| Structure overlap violates spacing| Medium     | Low    | Poisson-disk guarantees; validation retry + skip logging                   |

## Logging prefixes

- `[ARCH-RPG:WORLD]` — biome gen, structure placement, landmark registration
- `[ARCH-RPG:DUNGEON]` — dungeon start/complete, door/key, trigger activation
- `[ARCH-RPG:BOSS]` — phase changes, specials, reset, death
- `[ARCH-RPG:SAVE]` — save/write/load/migration events

All logs include timestamp, player name (if applicable), and relevant IDs. Debug-level logs disabled in release builds.