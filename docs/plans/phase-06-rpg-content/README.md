# Phase 6 — RPG Content (MVP slice)

Depends on: Phase 5 green (combat + stats + items operational).

## Goal

Deliver one complete vertical slice of RPG content: **1 NPC** (dual-role quest-giver + merchant), **1 fully playable quest** with multi-stage objectives, a **branching dialogue tree** gated by player state, a **crafting station** with 3 recipes backed by gathering stubs, and a **merchant buy/sell/repair loop** anchored to gold as the central currency. All systems are data-driven, server-authoritative, event-coupled (gameplay → UI via events only), and covered by save-format v3 additions for quest/dialogue/reputation persistence.

## Non-goals

- Full quest chains or branching narrative arcs beyond the single worked quest.
- Faction/reputation system beyond the `rep` field stub used in conditions.
- Economy balancing, dynamic pricing, or supply/demand simulation.
- NPC schedules/pathfinding beyond a static position + role table stub.
- Additional crafting stations beyond `workbench`; forge/anvil/alchemy/cooking/enchanting are schema-defined but not implemented this phase.
- Gathering node placement or world-gen integration; gathering is drop-table stubs on mob kill / loot chest only.
- UI polish, animations, voiceover, localization.
- Multiplayer replication of dialogue/crafting state beyond what Phase 9 already guarantees.

## Risks

| Risk | Mitigation |
|---|---|
| Quest objective completion races with mob respawn | Server-authoritative objective counters; client never increments. |
| Dialogue condition evaluator diverges between client/server | Evaluator is pure Lua, shared module; server result authoritative, client mirrors. |
| Crafting consumes items but fails to grant output on disconnect | Craft transaction atomic: deduct+grant in single server callback, logged. |
| Merchant gold desync after reload | Gold stored in player save v3; merchant transactions emit `[ARCH-RPG:ECON]` log lines for audit. |
| Save migration breaks existing worlds | Save v3 adds new tables with defaults; migration script idempotent, tested in ACCEPTANCE A6. |
| Scope creep into quest chains | Single quest ID `goblin_trouble` only; registry supports more but none shipped. |

## Layout after this phase

```text
game/arch_rpg/mods/
├── arch_rpg_quests/        # quest registry, start/complete API, tracker events
├── arch_rpg_dialogue/      # dialogue engine, condition evaluator, UI events
├── arch_rpg_npcs/          # NPC entity definition, roles table
├── arch_rpg_crafting/      # stations, recipes, gathering drop stubs
└── arch_rpg_merchant/      # buy/sell/repair, gold centrality
tests/
├── test_quest_objectives.lua
├── test_dialogue_conditions.lua
├── test_crafting_recipes.lua
└── test_merchant_math.lua
docs/plans/phase-06-rpg-content/
├── PLAN.md                 # original sketch (untouched)
├── README.md               # this file
├── TASKS.md                # ordered implementation checklist
└── ACCEPTANCE.md           # runnable pass/fail commands
```

## Quest schema

Quests are data-driven Lua tables registered at mod load. Every field below is REQUIRED unless marked OPTIONAL.

```lua
{
  id          = "goblin_trouble",            -- unique string identifier
  name        = "Goblin Trouble",            -- display name
  description = "Clear the goblin camp...",  -- journal text
  objectives  = {                            -- ordered list; all must complete
    { type = "talk",   target = "npc_brom",  count = 1 },
    { type = "kill",   target = "mob_goblin", count = 5 },
    { type = "collect", target = "item_goblin_ear", count = 3 },
    { type = "deliver", target = "npc_brom", item = "item_goblin_ear", count = 3 },
  },
  prereqs     = { quests = {}, level_min = 1, rep_min = {} },  -- gate start
  rewards     = {
    xp        = 250,
    gold      = 75,
    items     = { { id = "item_iron_sword", qty = 1 } },
    rep       = { brom = 10 },               -- OPTIONAL reputation delta
    dialogue  = "brom_post_quest",           -- OPTIONAL unlock dialogue node
    completion = "quest_complete_fanfare",   -- OPTIONAL sfx/event
    failure    = nil,                        -- OPTIONAL failure event
  },
  repeatable  = false,                       -- OPTIONAL, default false
  hidden      = false,                       -- OPTIONAL, hide from journal until started
}
```

Objective types: `kill`, `collect`, `deliver`, `talk`, `explore`, `escort`, `craft`, `survive`, `boss`, `dungeon`, `interact`. Each type has a validator in `arch_rpg_quests/objectives.lua`; unknown type = registration error at load.

### Worked quest: Goblin Trouble

```lua
-- game/arch_rpg/mods/arch_rpg_quests/data/goblin_trouble.lua
return {
  id          = "goblin_trouble",
  name        = "Goblin Trouble",
  description = "Brom says goblins have overrun the eastern ridge. Speak with him, thin their numbers, and bring back proof.",
  objectives  = {
    { type = "talk",    target = "npc_brom",     count = 1 },
    { type = "kill",    target = "mob_goblin",   count = 5 },
    { type = "collect", target = "item_goblin_ear", count = 3 },
    { type = "deliver", target = "npc_brom",     item = "item_goblin_ear", count = 3 },
  },
  prereqs     = { quests = {}, level_min = 2, rep_min = {} },
  rewards     = {
    xp        = 250,
    gold      = 75,
    items     = { { id = "item_iron_sword", qty = 1 } },
    rep       = { brom = 10 },
    dialogue  = "brom_thanks",
    completion = "quest_complete_fanfare",
  },
  repeatable  = false,
  hidden      = false,
}
```

Lifecycle: accept via dialogue → tracker shows 4 stages → kill 5 goblins (server counts) → loot 3 ears → return to Brom → deliver triggers turn-in → rewards granted atomically → journal marks complete → `brom_thanks` dialogue unlocked.

## Dialogue tree schema

Dialogue is a directed graph of nodes. Each node has speaker text and zero or more choices. Choices may be gated by conditions and may mutate state.

```lua
{
  id      = "brom_intro",
  speaker = "Brom",
  text    = "The goblins won't stop raiding our supplies.",
  choices = {
    {
      label      = "I'll handle it.",
      next_node  = "brom_briefing",
      conditions = { { type = "quest", op = "not_started", quest = "goblin_trouble" } },
      effects    = { { type = "start_quest", quest = "goblin_trouble" } },
    },
    {
      label      = "Already dealt with them.",
      next_node  = "brom_turn_in",
      conditions = { { type = "quest", op = "objectives_met", quest = "goblin_trouble" } },
      effects    = { { type = "complete_quest", quest = "goblin_trouble" } },
    },
    {
      label      = "Not interested.",
      next_node  = "brom_dismiss",
      conditions = {},
      effects    = {},
    },
  },
}
```

Condition types: `quest` (ops: `not_started`, `active`, `objectives_met`, `completed`, `failed`), `rep` (`>=`, `<`, `==` against faction key), `class` (`is`, `not`), `level` (`>=`, `<`), `item` (`has`, `missing`, `count >= N`), `skill` (`has`, `level >= N`). Evaluator is a pure function `dialogue.eval_condition(cond, player_state) -> bool`; server runs it, client mirrors for UI gating.

Effects: `start_quest`, `complete_quest`, `fail_quest`, `set_rep`, `give_item`, `take_item`, `set_flag`, `unlock_node`. All effects are server-executed; client receives state update events.

### Worked 6-node dialogue tree: Brom intro → briefing → progress → turn-in → thanks → dismiss

```lua
-- game/arch_rpg/mods/arch_rpg_dialogue/data/brom_tree.lua
return {
  {
    id = "brom_intro", speaker = "Brom",
    text = "The goblins won't stop raiding our supplies.",
    choices = {
      { label = "I'll handle it.", next_node = "brom_briefing",
        conditions = { { type = "quest", op = "not_started", quest = "goblin_trouble" } },
        effects = { { type = "start_quest", quest = "goblin_trouble" } } },
      { label = "I've cleared them out.", next_node = "brom_turn_in",
        conditions = { { type = "quest", op = "objectives_met", quest = "goblin_trouble" } },
        effects = { { type = "complete_quest", quest = "goblin_trouble" } } },
      { label = "Not my problem.", next_node = "brom_dismiss", conditions = {}, effects = {} },
    },
  },
  {
    id = "brom_briefing", speaker = "Brom",
    text = "Kill five of the brutes and bring me three ears as proof. I'll make it worth your while.",
    choices = {
      { label = "Consider it done.", next_node = "brom_progress", conditions = {}, effects = {} },
    },
  },
  {
    id = "brom_progress", speaker = "Brom",
    text = "Still working on it? The eastern ridge is where they nest.",
    choices = {
      { label = "On my way.", next_node = nil, conditions = { { type = "quest", op = "active", quest = "goblin_trouble" } }, effects = {} },
      { label = "I have the ears.", next_node = "brom_turn_in",
        conditions = { { type = "quest", op = "objectives_met", quest = "goblin_trouble" } },
        effects = { { type = "complete_quest", quest = "goblin_trouble" } } },
    },
  },
  {
    id = "brom_turn_in", speaker = "Brom",
    text = "Those ears will do. Here's your reward.",
    choices = {
      { label = "Pleasure doing business.", next_node = "brom_thanks", conditions = {}, effects = {} },
    },
  },
  {
    id = "brom_thanks", speaker = "Brom",
    text = "If you need supplies, I keep a stock. Just ask.",
    choices = {
      { label = "Show me your wares.", next_node = nil, conditions = {},
        effects = { { type = "open_merchant", npc = "npc_brom" } } },
      { label = "Maybe later.", next_node = nil, conditions = {}, effects = {} },
    },
  },
  {
    id = "brom_dismiss", speaker = "Brom",
    text = "Suit yourself. Don't come crying when they burn the mill.",
    choices = {},
  },
}
```

## Condition evaluator design

`arch_rpg_dialogue.conditions` exposes `eval(cond, ctx)` where `ctx` is a read-only snapshot of `{ quest_state, rep, class, level, inventory, skills, flags }`. Evaluator is deterministic, side-effect-free, and unit-testable without a running server. Unknown condition type returns `false` + logs `[ARCH-RPG:DIALOGUE] WARN unknown condition type <t>` rather than crashing. Client-side evaluator uses identical code path; server result is authoritative if mismatch detected.

## NPC definition

One NPC entity serves dual roles for MVP. Roles are a table so future phases can split without schema change.

```lua
-- game/arch_rpg/mods/arch_rpg_npcs/data/npc_brom.lua
return {
  id       = "npc_brom",
  name     = "Brom",
  model    = "models/npcs/brom.b3d",
  position = { x = 120, y = 8, z = -45 },
  roles    = {
    { type = "quest_giver", dialogue_tree = "brom_intro" },
    { type = "merchant",    inventory_id = "merchant_brom_stock" },
  },
  schedule = {                           -- STUB: static for Phase 6
    default = { position = { x = 120, y = 8, z = -45 }, active_hours = "06-22" },
  },
}
```

Roles table allows adding `guard`, `trainer`, `faction_rep` later. Schedule stub defines the interface; actual pathfinding/scheduling deferred.

## Crafting schema

Crafting is station-scoped. Each recipe declares required station, materials, output, and optional level gate.

```lua
{
  id          = "recipe_iron_sword",
  station     = "workbench",             -- workbench|forge|anvil|alchemy|cooking|enchanting
  level_req   = 0,                       -- OPTIONAL crafting level
  materials   = {
    { item = "item_iron_ingot", qty = 3 },
    { item = "item_leather_strip", qty = 1 },
  },
  output      = { item = "item_iron_sword", qty = 1 },
  craft_time  = 2.0,                     -- seconds, server-enforced
}
```

Stations defined this phase: `workbench` only. Others are enum-valid but unimplemented; attempting to craft at missing station returns error event `[ARCH-RPG:CRAFT] ERR station <s> not available`.

### Three worked recipes

```lua
-- game/arch_rpg/mods/arch_rpg_crafting/data/recipes.lua
return {
  {
    id = "recipe_iron_sword", station = "workbench", level_req = 0,
    materials = { { item = "item_iron_ingot", qty = 3 }, { item = "item_leather_strip", qty = 1 } },
    output = { item = "item_iron_sword", qty = 1 }, craft_time = 2.0,
  },
  {
    id = "recipe_leather_vest", station = "workbench", level_req = 0,
    materials = { { item = "item_leather_hide", qty = 4 }, { item = "item_thread", qty = 2 } },
    output = { item = "item_leather_vest", qty = 1 }, craft_time = 3.0,
  },
  {
    id = "recipe_minor_health_potion", station = "workbench", level_req = 0,
    materials = { { item = "item_red_herb", qty = 2 }, { item = "item_water_flask", qty = 1 } },
    output = { item = "item_minor_health_potion", qty = 1 }, craft_time = 1.5,
  },
}
```

### Gathering stub

Gathering is not world-node based this phase. Materials enter inventory via:
- Mob drops: `mob_goblin` → `item_goblin_ear` (quest), `item_leather_strip` (common).
- Loot chests: `item_iron_ingot`, `item_leather_hide`, `item_red_herb`, `item_thread`, `item_water_flask`.
- Future phases add mining/wood/herbal/hunt/fish nodes; schema reserves `gathering_type` field on material defs.

## Merchant buy/sell/repair + gold centrality

Merchant transactions are server-authoritative. Gold lives in player save v3 `economy.gold`; all mutations go through `arch_rpg_merchant.transact()` which emits `[ARCH-RPG:ECON]` log lines.

- **Buy**: player pays `price * qty`; merchant stock decrements. Insufficient gold → transaction rejected, no partial.
- **Sell**: player receives `floor(price * sell_ratio * qty)`; merchant stock increments. `sell_ratio` default 0.5, per-item override allowed.
- **Repair**: cost = `base_repair_cost * (1 - current_durability / max_durability)`. Durability restored to max. No repair if already max.
- **Gold centrality**: no barter, no alternate currencies. All prices expressed in gold integers.

Merchant inventory defined in `arch_rpg_merchant/data/merchant_brom_stock.lua`; restock timer deferred.

## Journal / tracker UI via events

Gameplay modules NEVER call UI directly. Quest tracker updates are emitted as events:

- `[ARCH-RPG:QUEST] START <id>`
- `[ARCH-RPG:QUEST] OBJECTIVE_UPDATE <id> <obj_index> <current> <target>`
- `[ARCH-RPG:QUEST] COMPLETE <id>`
- `[ARCH-RPG:QUEST] FAIL <id>`

UI mod subscribes to these events and renders journal. Dialogue UI similarly driven by `[ARCH-RPG:DIALOGUE] OPEN/NODE/CHOICE/CLOSE` events. This decoupling is mandatory; direct UI calls from gameplay mods fail lint.

## Save format v3 additions

Save v3 adds three top-level keys to player data:

```lua
quests   = {                              -- keyed by quest id
  goblin_trouble = {
    status = "active",                    -- not_started|active|completed|failed
    objectives = { 1, 5, 3, 0 },         -- current counts per objective index
    started_at = 1728000000,              -- unix timestamp
    completed_at = nil,
  },
},
dialogue = {                              -- keyed by npc id
  npc_brom = {
    visited_nodes = { "brom_intro", "brom_briefing" },
    flags = {},
  },
},
reputation = {                            -- keyed by faction/npc key
  brom = 10,
},
economy = {
  gold = 342,
},
```

Migration from v2: new keys default to empty tables / zero gold. Migration script in `scripts/migrate_save_v2_to_v3.lua`, idempotent, tested in ACCEPTANCE A6.

## Logging prefixes

All Phase 6 modules use structured prefixes for grep-friendly logs:

- `[ARCH-RPG:QUEST]` — quest lifecycle, objective updates
- `[ARCH-RPG:DIALOGUE]` — dialogue open/close, condition eval warnings
- `[ARCH-RPG:CRAFT]` — craft attempts, successes, failures
- `[ARCH-RPG:ECON]` — merchant transactions, gold changes
- `[ARCH-RPG:NPC]` — NPC interaction, role dispatch

## Module dependency direction

```
core → player/stats → classes/skills → combat → items/equipment → quests/dialogue/NPCs → mobs/loot/dungeons → UI
```

Gameplay modules (quests, dialogue, crafting, merchant) NEVER import UI modules. Communication is event-only. Violations caught by lint rule `no-gameplay-ui-import`.