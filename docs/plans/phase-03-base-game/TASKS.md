# Phase 3 Tasks — Base Game (ordered, speed-first)

Estimated: 2–4 hours on warm machine. Do in order. Stop at first red.
All paths relative to repo root. Commands assume POSIX shell.

## 1. Prereqs check (5 min)

- [ ] Phase 2 exit criteria green (`docs/plans/phase-02-camera-controller/RESULTS.md` exists)
- [ ] `bin/archlast --version` prints `-archlast` suffix
- [ ] `scripts/run-dev.sh --smoke` exits 0 with clean log
- [ ] Submodule pointer matches `dependencies/mods.lock`

```bash
test -f docs/plans/phase-02-camera-controller/RESULTS.md && echo "Phase 2 OK"
bin/archlast --version | grep -q archlast && echo "Fork OK"
scripts/run-dev.sh --smoke && echo "Smoke OK"
git submodule status engine/archlast-luanti
```

## 2. Scaffold game identity (10 min)

- [ ] `game/arch_rpg/game.conf` created with `name = Archlast RPG`, `description`, `supported_protocols`
- [ ] `game/arch_rpg/game.mt` created with `gameid = arch_rpg`, empty `disallowed_mods`
- [ ] `game/arch_rpg/settingtypes.txt` created with `world.seed_override` (int), `debug.spawn_trace` (bool)
- [ ] `game/arch_rpg/LICENSE.txt` placeholder noting code vs asset license split

```bash
mkdir -p game/arch_rpg
cat > game/arch_rpg/game.conf <<'EOF'
name = Archlast RPG
description = Base game bootstrap for Archlast RPG
supported_protocols = 40
EOF

cat > game/arch_rpg/game.mt <<'EOF'
gameid = arch_rpg
disallowed_mods =
EOF

cat > game/arch_rpg/settingtypes.txt <<'EOF'
# Seed override (0 = use default)
world.seed_override (Seed Override) int 0 0 2147483647

# Log spawn algorithm traces
debug.spawn_trace (Spawn Trace Debug) bool false
EOF

touch game/arch_rpg/LICENSE.txt
```

## 3. Scaffold mod directories + mod.conf (10 min)

- [ ] `mods/arch_rpg_core/mod.conf`: `name = arch_rpg_core`, `depends =`
- [ ] `mods/arch_rpg_world/mod.conf`: `name = arch_rpg_world`, `depends = arch_rpg_core`
- [ ] `mods/arch_rpg_player/mod.conf`: `name = arch_rpg_player`, `depends = arch_rpg_core`
- [ ] Empty `init.lua` in each mod (loads submodules in order)
- [ ] Asset stub dirs: `textures/`, `models/`, `sounds/` with `LICENSE.txt` each

```bash
for mod in arch_rpg_core arch_rpg_world arch_rpg_player; do
  mkdir -p "game/arch_rpg/mods/$mod"
  touch "game/arch_rpg/mods/$mod/init.lua"
done

cat > game/arch_rpg/mods/arch_rpg_core/mod.conf <<'EOF'
name = arch_rpg_core
depends =
EOF

cat > game/arch_rpg/mods/arch_rpg_world/mod.conf <<'EOF'
name = arch_rpg_world
depends = arch_rpg_core
EOF

cat > game/arch_rpg/mods/arch_rpg_player/mod.conf <<'EOF'
name = arch_rpg_player
depends = arch_rpg_core
EOF

for dir in textures models sounds; do
  mkdir -p "game/arch_rpg/$dir"
  echo "Assets TBD. Code under project license." > "game/arch_rpg/$dir/LICENSE.txt"
done
```

## 4. Core module: logger (10 min)

- [ ] `mods/arch_rpg_core/logger.lua`: `arch_rpg.log.info|warn|error(module, fmt, ...)`
- [ ] All output prefixed `[ARCH-RPG:<module>]`
- [ ] No raw `print()` or untagged `minetest.log` in core mods

```lua
-- mods/arch_rpg_core/logger.lua
arch_rpg = arch_rpg or {}
arch_rpg.log = {}

local function log(level, module, fmt, ...)
    local msg = string.format(fmt, ...)
    minetest.log(level, string.format("[ARCH-RPG:%s] %s", module, msg))
end

function arch_rpg.log.info(module, fmt, ...) log("action", module, fmt, ...) end
function arch_rpg.log.warn(module, fmt, ...) log("warning", module, fmt, ...) end
function arch_rpg.log.error(module, fmt, ...) log("error", module, fmt, ...) end
```

## 5. Core module: events bus (15 min)

- [ ] `mods/arch_rpg_core/events.lua`: `on(name, fn)`, `emit(name, ...)`, `once(name, fn)`
- [ ] Handlers run synchronously in registration order
- [ ] Returns unsubscribe function from `on`/`once`
- [ ] Reserved namespaces documented in `api.md`

```lua
-- mods/arch_rpg_core/events.lua
arch_rpg.events = {}
local handlers = {}

function arch_rpg.events.on(name, fn)
    handlers[name] = handlers[name] or {}
    table.insert(handlers[name], fn)
    return function()
        for i, h in ipairs(handlers[name]) do
            if h == fn then table.remove(handlers[name], i); break end
        end
    end
end

function arch_rpg.events.emit(name, ...)
    for _, fn in ipairs(handlers[name] or {}) do fn(...) end
end

function arch_rpg.events.once(name, fn)
    local unsub
    unsub = arch_rpg.events.on(name, function(...)
        unsub(); fn(...)
    end)
    return unsub
end
```

## 6. Core module: registry (15 min)

- [ ] `mods/arch_rpg_core/registry.lua`: `register_node(name, def)`, `get_nodes_by_category(cat)`, `freeze()`
- [ ] Wraps `minetest.register_node`; stores `_arch` metadata
- [ ] `freeze()` prevents post-init registration; logs error on attempt

```lua
-- mods/arch_rpg_core/registry.lua
arch_rpg.registry = {}
local nodes = {}
local frozen = false

function arch_rpg.registry.register_node(name, def)
    if frozen then
        arch_rpg.log.error("registry", "Attempted late registration: %s", name)
        return
    end
    minetest.register_node(name, def)
    nodes[name] = def
end

function arch_rpg.registry.get_nodes_by_category(cat)
    local result = {}
    for name, def in pairs(nodes) do
        if def._arch and def._arch.category == cat then
            table.insert(result, name)
        end
    end
    return result
end

function arch_rpg.registry.freeze()
    frozen = true
    arch_rpg.log.info("registry", "Registry frozen. %d nodes registered.", #nodes)
    arch_rpg.events.emit("registry:nodes_loaded", { count = #nodes })
end
```

## 7. Core module: config (10 min)

- [ ] `mods/arch_rpg_core/config.lua`: `get(key)`, `set_runtime(key, val)`
- [ ] Reads `settingtypes.txt` defaults + per-world `arch_rpg.conf` overrides
- [ ] Runtime-only settings not persisted

```lua
-- mods/arch_rpg_core/config.lua
arch_rpg.config = {}
local runtime = {}

function arch_rpg.config.get(key)
    if runtime[key] ~= nil then return runtime[key] end
    return minetest.settings:get("arch_rpg." .. key)
end

function arch_rpg.config.set_runtime(key, val)
    runtime[key] = val
end
```

## 8. Core module: save system (20 min)

- [ ] `mods/arch_rpg_core/save.lua`: `load_meta()`, `write_meta(data)`, `register_migration(from, to, fn)`
- [ ] Writes `worlds/<name>/arch_rpg_meta.json` with `save_version = 1`
- [ ] Migration stub table; logs warning if version > current
- [ ] Emits `world:loaded` / `world:saved` events

```lua
-- mods/arch_rpg_core/save.lua
arch_rpg.save = {}
local migrations = {}
local CURRENT_VERSION = 1

function arch_rpg.save.load_meta()
    local path = minetest.get_worldpath() .. "/arch_rpg_meta.json"
    local f = io.open(path, "r")
    if not f then return { save_version = CURRENT_VERSION } end
    local data = minetest.parse_json(f:read("*a"))
    f:close()
    if data.save_version > CURRENT_VERSION then
        arch_rpg.log.error("save", "Save version %d > current %d", data.save_version, CURRENT_VERSION)
        return nil
    end
    arch_rpg.events.emit("world:loaded", data)
    return data
end

function arch_rpg.save.write_meta(data)
    data.save_version = CURRENT_VERSION
    data.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local path = minetest.get_worldpath() .. "/arch_rpg_meta.json"
    local f = io.open(path, "w")
    f:write(minetest.write_json(data))
    f:close()
    arch_rpg.events.emit("world:saved", data)
end

function arch_rpg.save.register_migration(from, to, fn)
    migrations[from] = migrations[from] or {}
    migrations[from][to] = fn
end
```

## 9. Core init.lua wiring (5 min)

- [ ] Loads modules in order: logger → events → config → registry → save
- [ ] Exposes `arch_rpg` global table
- [ ] Calls `registry.freeze()` after all mods loaded (use `minetest.after(0, ...)`)

```lua
-- mods/arch_rpg_core/init.lua
arch_rpg = {}
dofile(minetest.get_modpath("arch_rpg_core") .. "/logger.lua")
dofile(minetest.get_modpath("arch_rpg_core") .. "/events.lua")
dofile(minetest.get_modpath("arch_rpg_core") .. "/config.lua")
dofile(minetest.get_modpath("arch_rpg_core") .. "/registry.lua")
dofile(minetest.get_modpath("arch_rpg_core") .. "/save.lua")

minetest.after(0, function()
    arch_rpg.registry.freeze()
    arch_rpg.log.info("core", "arch_rpg_core initialized")
end)
```

## 10. World mod: nodes (20 min)

- [ ] `mods/arch_rpg_world/nodes.lua`: registers ~10 nodes per README table
- [ ] All use `arch_rpg_world:` prefix, correct drawtypes/groups
- [ ] Placeholder textures referenced (`arch_rpg_<node>.png`)

```bash
# Verify node count after implementation
grep -c 'arch_rpg.registry.register_node' game/arch_rpg/mods/arch_rpg_world/nodes.lua
# Expected: 10
```

## 11. World mod: biome + mapgen (15 min)

- [ ] `mods/arch_rpg_world/biome.lua`: single temperate forest biome per README spec
- [ ] `mods/arch_rpg_world/mapgen.lua`: deterministic seed override, surface spawn hook
- [ ] Seed priority: config override > game.conf default > `os.time()` fallback

```lua
-- mods/arch_rpg_world/mapgen.lua (seed snippet)
local seed = tonumber(arch_rpg.config.get("world.seed_override"))
if not seed or seed == 0 then
    seed = tonumber(minetest.settings:get("arch_rpg.default_seed")) or os.time()
    arch_rpg.log.warn("world", "Using fallback seed: %d", seed)
end
minetest.set_mapgen_setting("seed", tostring(seed), true)
```

## 12. Player mod: spawn + third-person (20 min)

- [ ] `mods/arch_rpg_player/spawn.lua`: surface detection algorithm per README
- [ ] Sets third-person camera via `set_attribute` + eye offset
- [ ] Emits `player:spawned` event
- [ ] Fallback position `(0, 10, 0)` with warning if scan fails

## 13. Player mod: persist (10 min)

- [ ] `mods/arch_rpg_player/persist.lua`: hooks `minetest.register_on_shutdown` + player save
- [ ] Stores position in player meta or world meta
- [ ] Restores on join; emits `player:position_saved`

## 14. Scripts update (10 min)

- [ ] `scripts/run-dev.sh`: defaults `--gameid arch_rpg`, passes `--world` arg
- [ ] `scripts/test.sh`: new file with `phase3-world-smoke` subcommand
- [ ] Both `chmod +x`, no Windows logic

```bash
# Update run-dev.sh gameid default
sed -i 's/--gameid [a-z_]*/--gameid arch_rpg/' scripts/run-dev.sh

# Create test.sh skeleton
cat > scripts/test.sh <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  phase3-world-smoke) exec tests/phase3-world-smoke.sh ;;
  *) echo "Usage: $0 {phase3-world-smoke}"; exit 1 ;;
esac
SCRIPT
chmod +x scripts/test.sh
```

## 15. Smoke test script (15 min)

- [ ] `tests/phase3-world-smoke.sh`: creates temp world, launches server, verifies spawn + save
- [ ] Checks `arch_rpg_meta.json` exists with `save_version: 1`
- [ ] Grep log for ModError; exits non-zero on failure

```bash
# After implementation, verify test exists and is executable
test -x tests/phase3-world-smoke.sh && echo "Test script OK"
```

## 16. Placeholder asset generation (10 min)

- [ ] Generate solid-color PNGs for all referenced textures
- [ ] Script or inline; must be reproducible
- [ ] No missing-texture warnings in smoke log

## Out of scope (defer, do not start)

Classes, stats, combat, quests, NPCs, mobs, loot, dungeons, UI HUD, multiplayer auth, Windows packaging, CI, real assets, engine C++ changes.