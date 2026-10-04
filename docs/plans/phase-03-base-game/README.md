# Phase 3 — Base Game (actionable after Phase 2 green)

Speed-first gameplay bootstrap: stand up `game/arch_rpg/` as a standalone Luanti game identity with one biome, basic terrain nodes, player spawn, and save/load v1. No RPG systems yet — this phase proves the fork can host an original game with its own mod stack, asset layout, and persistent world format.

## Goal

`game/arch_rpg/` boots via `bin/archlast --gameid arch_rpg`, generates a deterministic single-biome world, spawns the player on the surface in third-person view, and persists position across save/reload with `save_version = 1`. The game appears in the main menu as **Archlast RPG** (not "Luanti + mods"). Core infrastructure (events bus, registries, logging, save migration stub) is in place for Phases 4–6 to build on without refactoring.

## Non-goals

- No classes, stats, combat, quests, dialogue, NPCs, mobs, loot, dungeons, or UI HUD (Phases 4–7).
- No placeholder texture/model/sound authoring beyond empty stub directories and license placeholders.
- No multiplayer gameplay logic; server-authoritative ownership model documented but not enforced beyond default Luanti behavior.
- No mapgen tuning beyond deterministic seed + single biome override.
- No Windows/macOS packaging or CI integration.
- No engine C++ changes; pure Lua + config.

## Entry criteria (must all pass before starting)

1. Phase 2 exit criteria green (`docs/plans/phase-02-camera-controller/RESULTS.md` exists, all checks pass).
2. `bin/archlast --version` prints `-archlast` suffix.
3. `scripts/run-dev.sh --smoke` exits 0 with clean log.
4. `engine/archlast-luanti` submodule pointer matches `dependencies/mods.lock`.

## Exit criteria (must all pass to complete Phase 3)

1. Game appears in Luanti main menu as **Archlast RPG**.
2. Fresh world generates with deterministic seed; player spawns on surface within 8 chunks of origin.
3. Default camera is third-person; movement works (WASD + jump).
4. Save/reload preserves player position; `save_version = 1` present in save metadata.
5. `grep -iE 'moderror|error\[main\]|segfault' /tmp/archlast-phase3.log` returns CLEAN.
6. `scripts/test.sh phase3-world-smoke` exits 0.

## Layout after this phase

```text
game/arch_rpg/
├── game.conf                 # name, description, supported protocols
├── game.mt                   # gameid = arch_rpg, disallowed_mods, load_order
├── settingtypes.txt          # exposed settings (seed override, debug)
├── mods/
│   ├── arch_rpg_core/
│   │   ├── mod.conf          # name, depends = []
│   │   ├── init.lua          # entrypoint: loads modules in order
│   │   ├── events.lua        # event bus API
│   │   ├── registry.lua      # node/item/entity registries
│   │   ├── config.lua        # runtime config loader
│   │   ├── logger.lua        # [ARCH-RPG:*] prefixed logging
│   │   ├── save.lua          # save_version=1 + migration stub
│   │   └── api.md            # public API reference for downstream mods
│   ├── arch_rpg_world/
│   │   ├── mod.conf          # depends = arch_rpg_core
│   │   ├── init.lua          # registers nodes + biome + mapgen override
│   │   ├── nodes.lua         # ~10 node definitions
│   │   ├── biome.lua         # single temperate forest biome
│   │   └── mapgen.lua        # deterministic seed + surface spawn hook
│   └── arch_rpg_player/
│       ├── mod.conf          # depends = arch_rpg_core
│       ├── init.lua          # spawn logic + third-person default
│       ├── spawn.lua         # surface detection + safe placement
│       └── persist.lua       # position save/load hooks
├── textures/                 # placeholder .png stubs + LICENSE.txt
├── models/                   # placeholder .b3d/.obj stubs + LICENSE.txt
├── sounds/                   # placeholder .ogg stubs + LICENSE.txt
└── LICENSE.txt               # game-level license (code + assets separated)

scripts/
├── run-dev.sh                # updated: defaults to --gameid arch_rpg
└── test.sh                   # new: phase3-world-smoke subcommand

tests/
└── phase3-world-smoke.sh     # automated world create → join → move → save → reload
```

## `arch_rpg_core` responsibilities

### Events bus (`events.lua`)

Central pub/sub for decoupled module communication. All event names are namespaced strings. Gameplay modules NEVER call UI directly; emit events instead.

```lua
-- Register handler; returns unsubscribe function
local unsub = arch_rpg.events.on("player:spawned", function(player, pos)
    -- handler body
end)

-- Emit event synchronously; handlers run in registration order
arch_rpg.events.emit("player:spawned", player, pos)

-- One-shot listener
arch_rpg.events.once("world:loaded", function(meta)
    -- runs once then auto-unsubscribes
end)
```

Reserved event namespaces (Phase 3 uses only `player:*` and `world:*`; others reserved):

| Event | Payload | Emitter | Phase |
|---|---|---|---|
| `world:loaded` | `{ save_version, seed, timestamp }` | `save.lua` | 3 |
| `world:saved` | `{ save_version, timestamp }` | `save.lua` | 3 |
| `player:spawned` | `PlayerRef, vector` | `arch_rpg_player/spawn.lua` | 3 |
| `player:position_saved` | `PlayerRef, vector` | `arch_rpg_player/persist.lua` | 3 |
| `registry:nodes_loaded` | `{ count }` | `registry.lua` | 3 |
| `stats:changed` | `PlayerRef, stat_name, old, new` | (Phase 4) | 4 |
| `combat:damage_dealt` | `src, dst, amount, type` | (Phase 5) | 5 |

### Registries (`registry.lua`)

Thin wrappers around `minetest.register_*` that record metadata for tooling and migration.

```lua
-- Register node with arch_rpg metadata; forwards all args to minetest
arch_rpg.registry.register_node("arch_rpg_world:stone", {
    description = "Stone",
    drawtype = "normal",
    tiles = {"arch_rpg_stone.png"},
    groups = {cracky = 3, stone = 1},
    _arch = { category = "terrain", since = "0.1.0" },
})

-- Query registered nodes by category
local terrain = arch_rpg.registry.get_nodes_by_category("terrain")

-- Freeze registry after init; prevents late registration bugs
arch_rpg.registry.freeze()
```

### Config (`config.lua`)

Loads `settingtypes.txt` defaults + per-world overrides from `worlds/<name>/arch_rpg.conf`.

```lua
local cfg = arch_rpg.config.get("world.seed_override")  -- returns number|nil
arch_rpg.config.set_runtime("debug.spawn_trace", true)   -- session-only
```

### Logger (`logger.lua`)

All core/mod logs prefixed for grep-ability. Never use raw `print()` or untagged `minetest.log`.

```lua
arch_rpg.log.info("core", "Events bus initialized")
-- Output: 2026-10-04 12:00:00 INFO[ARCH-RPG:core]: Events bus initialized

arch_rpg.log.warn("world", "Biome fallback used at %s", minetest.pos_to_string(pos))
arch_rpg.log.error("save", "Migration failed: %s", err)
```

Modules: `core`, `world`, `player`, `save`, `registry`, `events`. Downstream mods use own tag (e.g., `[ARCH-RPG:classes]`).

### Save system (`save.lua`)

Versioned saves with forward-compatible migration stub. Save metadata stored in `worlds/<name>/arch_rpg_meta.json`.

```lua
-- Called on world load; returns migrated metadata or nil on fatal error
local meta = arch_rpg.save.load_meta()
-- meta = { save_version = 1, seed = 12345, timestamp = "2026-10-04T12:00:00Z" }

-- Called on world save; bumps timestamp, keeps version
arch_rpg.save.write_meta({ seed = 12345 })

-- Migration stub: add handlers as versions increment
arch_rpg.save.register_migration(1, 2, function(old_meta)
    -- transform old_meta → new_meta
    return new_meta
end)
```

`save_version = 1` schema:

```json
{
  "save_version": 1,
  "seed": 12345,
  "timestamp": "2026-10-04T12:00:00Z",
  "gameid": "arch_rpg",
  "engine_version": "5.x.y-archlast"
}
```

## Node & biome design

### Nodes (~10, Phase 3 scope)

All nodes use `arch_rpg_world:` prefix. Drawtypes and groups chosen for mapgen compatibility and future crafting.

| Node | Drawtype | Groups | Notes |
|---|---|---|---|
| `arch_rpg_world:stone` | `normal` | `{cracky=3, stone=1}` | Base terrain |
| `arch_rpg_world:dirt` | `normal` | `{crumbly=3, soil=1}` | Subsurface |
| `arch_rpg_world:grass` | `normal` | `{crumbly=3, soil=1, grass=1}` | Surface cap; `_soil` variant for farming later |
| `arch_rpg_world:sand` | `normal` | `{crumbly=3, sand=1}` | Beach/riverbank |
| `arch_rpg_world:wood` | `normal` | `{choppy=3, wood=1}` | Logs |
| `arch_rpg_world:leaves` | `allfaces_optional` | `{snappy=3, leaves=1}` | Tree canopy; decay group reserved |
| `arch_rpg_world:water_source` | `liquid` | `{water=1, liquid=1}` | Rivers/lakes |
| `arch_rpg_world:water_flowing` | `flowingliquid` | `{water=1, liquid=1}` | Flow variant |
| `arch_rpg_world:bedrock` | `normal` | `{unbreakable=1}` | World floor; y=-64 |
| `arch_rpg_world:air` | `airlike` | `{not_in_creative_inventory=1}` | Implicit; registered for completeness |

Textures: `textures/arch_rpg_<node>.png` placeholder (solid color + label). Models/sounds: empty stubs.

### Biome: Temperate Forest (single)

```lua
minetest.register_biome({
    name = "arch_rpg_temperate_forest",
    node_top = "arch_rpg_world:grass",
    node_filler = "arch_rpg_world:dirt",
    node_stone = "arch_rpg_world:stone",
    node_water_top = "arch_rpg_world:water_source",
    node_water_filler = "arch_rpg_world:water_source",
    y_min = -62,
    y_max = 31000,
    heat_point = 50,
    humidity_point = 50,
    vertical_blend = 2,
})
```

Mapgen override in `mapgen.lua`: force single biome regardless of noise params. Deterministic seed via `minetest.set_mapgen_setting("seed", tostring(seed), true)` called in `on_new_init`. Seed source priority: `world.arch_rpg.seed_override` > `game.conf default_seed` > `os.time()` fallback (logged as warning).

### Spawn algorithm

Implemented in `arch_rpg_player/spawn.lua`:

1. On `minetest.register_on_newplayer`, compute spawn column at `(0, *, 0)`.
2. Scan y from 64 downward for first non-air, non-liquid node with `groups.soil` or `groups.stone`.
3. Place player at `y + 1` if solid, else continue scan. Fallback: `(0, 10, 0)` with warning log.
4. Emit `player:spawned` event with final position.
5. Set third-person camera: `player:set_attribute("camera_mode", "third")` + `minetest.camera:set_eye_offset(player, {x=0,y=2,z=-6}, {x=0,y=2,z=-6})`.

## Multiplayer ownership notes

Server-authoritative by default (Luanti standard). Phase 3 documents intent only:

- Player position: server owns; client interpolation is engine responsibility.
- World state (nodes, entities): server-only mutation. Client requests via `minetest.register_on_placenode` etc. are validated server-side.
- Save/load: server process only. Clients receive serialized state on connect.
- Events bus: server-side only in Phase 3. Client-side events deferred to Phase 6 (UI).

No custom auth, permissions, or anti-cheat in Phase 3. Document future hooks in `arch_rpg_core/api.md`.

## Risks & mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Mapgen produces unplayable terrain (cliffs, floating islands) | Blocks smoke test | Single biome + flat-ish noise defaults; manual seed validation in test script |
| Save version mismatch breaks worlds | Data loss | Migration stub + version check on load; refuse load if version > current with clear error |
| Third-person camera clips into terrain | Poor UX | Eye offset tuned in `spawn.lua`; defer collision fix to Phase 2 follow-up if needed |
| Mod load order breaks registry freeze | Silent failures | `mod.conf` explicit depends; `init.lua` loads modules sequentially; freeze called last |
| Placeholder assets cause missing-texture spam | Log noise | Solid-color PNGs generated by `scripts/generate-placeholders.sh` (Phase 3 task) |
| Fork upstream merge conflicts touch game-facing APIs | Rework | Pin commit; document affected APIs in `api.md`; rebase before Phase 4 start |

## Decisions (locked)

- **Game ID**: `arch_rpg`. Not `archlast` (reserved for project root), not `arch_rpg_game` (redundant).
- **Mod split**: Three mods minimum (`core`, `world`, `player`). Prevents monolith; matches dependency direction (core → world/player).
- **Save format**: JSON metadata + Luanti native world files. Not SQLite (overkill for v1), not custom binary (migration pain).
- **Logging prefix**: `[ARCH-RPG:*]`. Matches `[ARCH-ENGINE:*]` convention from Phase 1.
- **Event bus**: Synchronous, in-process. Async/eventual consistency deferred until multiplayer stress requires it.
- **Asset licenses**: Separate `LICENSE.txt` per asset directory. Code under project license; assets TBD but tracked from day one.