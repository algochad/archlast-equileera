# Phase 4 — RPG Foundation

Builds on Phase 3 (green). Delivers the first playable RPG loop: attributes → derived stats → XP/levels → one class (Warrior) → items → inventory → equipment. All data-driven, server-authoritative, save-versioned. No combat damage yet (Phase 5), no quests/dialogue/NPCs (Phase 6).

## Goal

A player can:

1. See six base attributes and sixteen derived stats update correctly when leveling or equipping gear.
2. Earn XP, level from 1→20 along a deterministic curve, and receive stat/skill-point allocations per level.
3. Play as Warrior (starting attributes + starting equipment defined in data, not code branches).
4. Pick up, stack, sort, equip, and unequip items; see stats change immediately and persist across save/reload.
5. Use a minimal HUD (health/mana/stamina bars, XP/level, hotbar, equipment paper-doll, stat tooltip).

## Entry criteria

- Phase 3 acceptance checks all green.
- `engine/archlast-luanti` builds and runs smoke test.
- `game/arch_rpg/mods/` directory exists with at least one loadable mod.
- Save format versioning infrastructure present (`arch_rpg_save` or equivalent).

## Non-goals

- Mage/Rogue/Cleric classes, skill trees, active abilities (Phase 5+).
- Combat damage formulas, hit/miss resolution, status effects (Phase 5).
- Quests, dialogue, NPC AI, vendors, economy balancing (Phase 6+).
- Multiplayer reconciliation beyond server-authoritative single-player save.
- Unified Inventory adoption decision deferred until evaluation rubric below is executed.

## Exit criteria (must all pass)

1. `scripts/test.sh` exits 0; all unit tests for stats, XP, equip deltas, stacking, class restrictions pass.
2. In-game: equip Iron Sword → Physical Attack rises by exactly the sword's stat delta; unequip → returns to baseline.
3. In-game: gain enough XP to reach level 2 → Max HP increases by formula; save/reload preserves level, XP, inventory, equipment.
4. Log contains `[ARCH-RPG:stats]`, `[ARCH-RPG:xp]`, `[ARCH-RPG:class]`, `[ARCH-RPG:item]`, `[ARCH-RPG:inv]` prefixes for all relevant operations; no `ERROR[Main]` or Lua `ModError`.
5. Save migration v1→v2 test passes (see §Save migration).

---

## §1 Attributes & Derived Stats

### 1.1 Six base attributes

| Attribute | Symbol | Starting (Warrior) | Cap (base) | Notes |
|-----------|--------|--------------------|------------|-------|
| Strength | STR | 8 | 99 | Governs physical attack, carry weight |
| Dexterity | DEX | 5 | 99 | Attack speed, crit chance, dodge |
| Vitality | VIT | 7 | 99 | Max HP, HP regen, block effectiveness |
| Intelligence | INT | 3 | 99 | Magic power, mana pool |
| Wisdom | WIS | 4 | 99 | Mana regen, magic resist, XP bonus (stub) |
| Endurance | END | 6 | 99 | Stamina pool, stamina regen, armor fatigue |

Base attributes are stored as integers ≥1. Equipment/buffs add signed modifiers; effective attribute = `base + sum(modifiers)`, clamped to [1, cap].

### 1.2 Sixteen derived stats

All derived stats are **computed** from effective attributes + equipment bonuses via centralized formulas in `arch_rpg_stats`. Never cached across ticks unless invalidated by `arch_rpg_stats.invalidate(player)`.

| # | Derived Stat | Symbol | Formula | Unit | Notes |
|---|--------------|--------|---------|------|-------|
| 1 | Max Health | MHP | `floor(100 + VIT * 12 + STR * 2)` | hp | Base 100 at VIT=0 |
| 2 | Max Mana | MMP | `floor(50 + INT * 10 + WIS * 3)` | mp | Warriors start low |
| 3 | Max Stamina | MST | `floor(80 + END * 10 + VIT * 2)` | sp | Sprint/block cost pool |
| 4 | HP Regen | HPR | `max(0.1, 0.5 + VIT * 0.15)` | hp/s | Tick every 1s |
| 5 | Mana Regen | MPR | `max(0.1, 0.3 + WIS * 0.2 + INT * 0.05)` | mp/s | |
| 6 | Stamina Regen | SPR | `max(0.5, 1.0 + END * 0.25)` | sp/s | Faster out of combat |
| 7 | Physical Attack | PATK | `floor(STR * 2.5 + DEX * 0.5) + weapon_atk` | dmg | Weapon bonus added separately |
| 8 | Magic Power | MPWR | `floor(INT * 2.8 + WIS * 0.7)` | dmg | Phase 5 uses this |
| 9 | Armor | ARM | `sum(equipment.armor) + floor(END * 0.3)` | flat | Diminishing returns applied in Phase 5 |
| 10 | Fire Resist | RFI | `floor(WIS * 0.4 + END * 0.2) + equip.rfi` | % | Clamp [0, 75] |
| 11 | Ice Resist | RIC | `floor(WIS * 0.4 + INT * 0.2) + equip.ric` | % | Clamp [0, 75] |
| 12 | Lightning Resist | RLN | `floor(WIS * 0.3 + DEX * 0.3) + equip.rln` | % | Clamp [0, 75] |
| 13 | Crit Chance | CRIT% | `min(50, 2.0 + DEX * 0.6 + equip.crit%)` | % | Base 2% |
| 14 | Crit Damage | CRIT× | `1.5 + STR * 0.01 + equip.crit_dmg` | mult | Base 1.5× |
| 15 | Move Speed | MSPD | `1.0 + DEX * 0.008 - armor_penalty` | mult | Base 1.0 = walk; clamp [0.5, 2.0] |
| 16 | Attack Speed | ASPD | `1.0 + DEX * 0.012 + equip.aspd` | mult | Base 1.0 = 1 atk/s; clamp [0.5, 3.0] |
| — | Block Chance | BLK% | `min(40, VIT * 0.8 + shield.block%)` | % | Requires shield equipped |
| — | Dodge Chance | DODGE% | `min(30, DEX * 0.5 + equip.dodge%)` | % | Reduced by armor weight |

> **Note:** Block and Dodge are listed separately from the numbered 16 because they are conditional (require equipment/state) but still computed via the same centralized API. They count toward the "16 derived" total when conditions are met.

### 1.3 Centralized API

```lua
-- game/arch_rpg/mods/arch_rpg_stats/init.lua
arch_rpg_stats = {}

-- Get current effective value (recomputes if dirty)
arch_rpg_stats.get(player, stat_name) -> number

-- Modify base attribute or apply/remove buff modifier
arch_rpg_stats.modify(player, { attr = "STR", delta = 2, source = "level_up" })
arch_rpg_stats.modify(player, { buff_id = "iron_skin", stats = { ARM = 5 }, duration = 30 })

-- Force recomputation next get()
arch_rpg_stats.invalidate(player)

-- Register derived stat formula (for extensibility/testing)
arch_rpg_stats.register_derived(name, fn)
```

All gameplay code MUST call `arch_rpg_stats.get`; NEVER compute derived stats inline. This ensures single-source-of-truth and testability.

---

## §2 XP / Level Curve

### 2.1 Formula

XP required to reach level L from level L−1:

$$
XP(L) = \left\lfloor 100 \cdot L^{1.8} + 50 \cdot L \right\rfloor
$$

Cumulative XP to reach level L:

$$
XP_{cum}(L) = \sum_{i=2}^{L} XP(i)
$$

Level 1 requires 0 cumulative XP. Max level in Phase 4: 20.

### 2.2 Levels 1–20 table

| Level | XP to Next | Cumulative XP | Stat Points | Skill Points | Notes |
|-------|-----------|---------------|-------------|--------------|-------|
| 1 | 150 | 0 | 0 | 0 | Starting level |
| 2 | 332 | 150 | 2 | 1 | First allocation |
| 3 | 558 | 482 | 2 | 1 | |
| 4 | 822 | 1,040 | 2 | 1 | |
| 5 | 1,120 | 1,862 | 3 | 1 | Milestone: +1 extra stat pt |
| 6 | 1,449 | 2,982 | 2 | 1 | |
| 7 | 1,807 | 4,431 | 2 | 1 | |
| 8 | 2,192 | 6,238 | 2 | 1 | |
| 9 | 2,602 | 8,430 | 2 | 1 | |
| 10 | 3,036 | 11,032 | 3 | 2 | Milestone: +1 skill pt |
| 11 | 3,493 | 14,068 | 2 | 1 | |
| 12 | 3,971 | 17,561 | 2 | 1 | |
| 13 | 4,469 | 21,532 | 2 | 1 | |
| 14 | 4,987 | 26,001 | 2 | 1 | |
| 15 | 5,524 | 30,988 | 3 | 2 | Milestone |
| 16 | 6,079 | 36,512 | 2 | 1 | |
| 17 | 6,652 | 42,591 | 2 | 1 | |
| 18 | 7,242 | 49,243 | 2 | 1 | |
| 19 | 7,849 | 56,485 | 2 | 1 | |
| 20 | — | 64,334 | 3 | 2 | Phase 4 cap |

### 2.3 Allocation rules

- **Stat points**: added to any base attribute via `arch_rpg_stats.modify`. Unspent points persisted in save.
- **Skill points**: stub only in Phase 4. Stored as `player.skills.points`; consumed by Phase 5 skill tree. No skill definitions yet.
- On level-up: log `[ARCH-RPG:xp] level_up player=<name> from=<old> to=<new> stat_pts=<n> skill_pts=<n>`.

### 2.4 API

```lua
arch_rpg_xp = {}
arch_rpg_xp.add(player, amount, source)      -- adds XP, triggers level-up(s)
arch_rpg_xp.get_level(player) -> int
arch_rpg_xp.get_xp(player) -> int            -- current cumulative
arch_rpg_xp.xp_for_next_level(level) -> int  -- pure function, no player arg
arch_rpg_xp.allocate_stat_point(player, attr) -> bool
```

---

## §3 Class Registry

### 3.1 Design principles

- **No `if class == "warrior"` anywhere.** All class-specific data lives in registry entries.
- Classes are **data definitions**, not code branches. Adding Mage in Phase 5 = new table entry, zero existing code changes.
- Server-authoritative: class choice locked after character creation (Phase 4: only Warrior available).

### 3.2 API

```lua
arch_rpg_classes = {}

-- Register a class definition (called at mod load)
arch_rpg_classes.register(class_id, def)

-- Retrieve definition (read-only copy)
arch_rpg_classes.get(class_id) -> table | nil

-- Assign class to player (character creation only)
arch_rpg_classes.set(player, class_id) -> bool

-- Get player's current class id
arch_rpg_classes.get_player_class(player) -> string
```

### 3.3 Warrior definition

```lua
arch_rpg_classes.register("warrior", {
    name = "Warrior",
    description = "Melee specialist. High vitality and strength.",
    starting_attributes = { STR = 8, DEX = 5, VIT = 7, INT = 3, WIS = 4, END = 6 },
    starting_equipment = {
        main_hand = "arch_rpg_items:iron_sword",
        off_hand = "arch_rpg_items:wooden_shield",
        chest = "arch_rpg_items:leather_chest",
        legs = "arch_rpg_items:leather_legs",
        feet = "arch_rpg_items:leather_boots",
    },
    starting_inventory = {
        { id = "arch_rpg_items:health_potion_minor", count = 3 },
    },
    stat_growth = { STR = 2, VIT = 2, END = 1, DEX = 1, INT = 0, WIS = 0 }, -- per 5 levels, stub
    allowed_slots = { "main_hand", "off_hand", "head", "chest", "legs", "feet", "ring_l", "ring_r", "amulet", "back" },
})
```

### 3.4 Anti-pattern enforcement

Code review MUST flag any occurrence of `class ==`, `class_id ==`, or string literal class names outside `arch_rpg_classes` module. Use `arch_rpg_classes.get(id).allowed_slots` etc. instead.

---

## §4 Item Schema & Registry

### 4.1 Item schema

Every item is a Lua table registered via `arch_rpg_items.register`. Fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | ✓ | Namespaced: `arch_rpg_items:<name>` |
| name | string | ✓ | Display name |
| description | string | ✓ | Tooltip text |
| icon | string | ✓ | Texture path relative to mod |
| stack_max | int | ✓ | 1 for equipment, 1–99 for consumables/materials |
| weight | float | ✓ | Carry weight in kg |
| rarity | enum | ✓ | common/uncommon/rare/epic/unique |
| value | int | ✓ | Sell price in copper (economy stub) |
| requirements | table | ✗ | `{ level = N, class = "warrior", attr = { STR = 10 } }` |
| stats | table | ✗ | Flat stat bonuses when equipped: `{ PATK = 8, ARM = 3 }` |
| effects | table | ✗ | On-equip/on-use effect IDs (Phase 5+) |
| slot | enum | ✗ | Equipment slot (nil = non-equippable) |
| durability | int | ✗ | Max durability; nil = indestructible |
| meta | table | ✗ | Mod-specific extension data |

### 4.2 Rarity tiers

| Tier | Color (UI) | Stat Mult | Affix Slots | Value Mult | Drop Weight (stub) |
|------|-----------|-----------|-------------|------------|-------------------|
| Common | #AAAAAA | 1.0× | 0 | 1.0× | 60% |
| Uncommon | #44CC44 | 1.15× | 1 | 2.5× | 25% |
| Rare | #4488FF | 1.35× | 2 | 8× | 10% |
| Epic | #CC44CC | 1.6× | 3 | 25× | 4% |
| Unique | #FFAA00 | 2.0× | special | 100× | 1% |

Affix system is **stubbed** in Phase 4: affix slots reserved, no generation logic. Items with affixes loaded from data files only.

### 4.3 Example items (10)

| ID | Name | Slot | Rarity | Stats | Stack | Weight | Value | Req |
|----|------|------|--------|-------|-------|--------|-------|-----|
| `iron_sword` | Iron Sword | main_hand | common | PATK +8, ASPD +0.05 | 1 | 3.0 | 50 | — |
| `steel_sword` | Steel Sword | main_hand | uncommon | PATK +14, CRIT% +2 | 1 | 3.5 | 180 | LVL 5 |
| `wooden_shield` | Wooden Shield | off_hand | common | ARM +3, BLK% +8 | 1 | 4.0 | 40 | — |
| `iron_kite_shield` | Iron Kite Shield | off_hand | uncommon | ARM +8, BLK% +14, VIT +1 | 1 | 6.0 | 220 | LVL 7 |
| `leather_chest` | Leather Chestpiece | chest | common | ARM +5, END +1 | 1 | 5.0 | 60 | — |
| `chainmail_chest` | Chainmail Chest | chest | rare | ARM +14, END +2, MSPD −0.05 | 1 | 12.0 | 450 | LVL 10, STR 12 |
| `leather_legs` | Leather Leggings | legs | common | ARM +3 | 1 | 4.0 | 45 | — |
| `leather_boots` | Leather Boots | feet | common | ARM +2, MSPD +0.03 | 1 | 3.0 | 40 | — |
| `health_potion_minor` | Minor Health Potion | — | common | restores 50 HP | 20 | 0.2 | 15 | — |
| `warrior_ring_vigor` | Ring of Vigor | ring_l | rare | VIT +3, HPR +0.3 | 1 | 0.1 | 350 | LVL 8, class warrior |

### 4.4 API

```lua
arch_rpg_items = {}
arch_rpg_items.register(id, def)
arch_rpg_items.get(id) -> table | nil
arch_rpg_items.list(filter?) -> table[]       -- filter: { slot, rarity, req_class }
arch_rpg_items.can_equip(player, item_id) -> bool, reason?
arch_rpg_items.get_stat_bonuses(item_id) -> table  -- resolved with rarity mult
```

Item data files live in `game/arch_rpg/mods/arch_rpg_items/data/*.lua`, loaded at init. Each file returns a table of `{ id = ..., ... }` entries.

---

## §5 Equipment Slots

Ten slots, matching Warrior `allowed_slots`:

| Slot | Enum Key | Typical Items | Notes |
|------|----------|---------------|-------|
| Main Hand | main_hand | Swords, axes, maces | Primary PATK source |
| Off Hand | off_hand | Shields, off-hand weapons | Block chance source |
| Head | head | Helmets, hoods | |
| Chest | chest | Armor, robes | Highest armor slot |
| Legs | legs | Greaves, pants | |
| Feet | feet | Boots, shoes | Move speed mods |
| Left Ring | ring_l | Rings | |
| Right Ring | ring_r | Rings | Independent from ring_l |
| Amulet | amulet | Necklaces, talismans | |
| Back | back | Cloaks, capes | Resist/move speed mods |

Equip/unequip flow:

1. Validate slot + requirements via `arch_rpg_items.can_equip`.
2. Remove old item → subtract its stat bonuses via `arch_rpg_stats.modify(delta=-)`.
3. Add new item → add stat bonuses via `arch_rpg_stats.modify(delta=+)`.
4. Update inventory (remove from inv, place old item back if swap).
5. Log `[ARCH-RPG:equip] player=<name> slot=<slot> item=<id> action=equip|unequip`.
6. Invalidate stats cache.

---

## §6 Inventory Design

### 6.1 Core model

Server-authoritative. Player inventory = ordered list of stacks:

```lua
{ id = "arch_rpg_items:iron_sword", count = 1, meta = {} }
```

- **Stacking**: same `id` + compatible `meta` → merge up to `stack_max`.
- **Hotbar**: first 10 slots of inventory array; UI binds to indices 1–10.
- **Containers**: separate inventory arrays keyed by container entity ID; same stack/sort logic.
- **Sort**: stable sort by `{ slot_order, rarity_desc, name_asc }`; triggered manually or on close.
- **Tooltip**: client renders from item def + runtime stat deltas; server sends full item data on hover request.

### 6.2 Unified Inventory evaluation rubric

Before implementing custom UI, evaluate [Unified Inventory](https://github.com/minetest-mods/unified_inventory) against these criteria. Score each 0–3; adopt if total ≥ 18 AND no blocker.

| Criterion | Weight | Description |
|-----------|--------|-------------|
| API compatibility | 3 | Exposes `get_inventory(player)`, `set_slot`, callbacks we can hook |
| Hotbar integration | 2 | Supports our 10-slot hotbar binding without fork |
| Equipment paper-doll | 2 | Renders 10-slot grid; customizable slot positions |
| Tooltip extensibility | 2 | Allows custom stat delta display |
| Sort/filter hooks | 2 | We can inject our sort order |
| Maintenance status | 2 | Active maintainer, MT 5.x compat, license OK |
| License compatibility | 3 | MIT/LGPL/CC-BY acceptable; no GPL-v3-only assets |
| Performance | 2 | Handles 200+ stacks without frame drop |
| Dependency footprint | 1 | ≤3 transitive deps |
| Customization without fork | 2 | Theming/config vs code patches |

**Decision deadline**: end of Task 5 (inventory implementation). If score < 18 or any criterion = 0, implement own minimal UI. Document decision in `TASKS.md` completion notes.

### 6.3 API

```lua
arch_rpg_inventory = {}
arch_rpg_inventory.add(player, item_id, count, meta?) -> bool, remaining
arch_rpg_inventory.remove(player, item_id, count, meta?) -> bool
arch_rpg_inventory.get_stacks(player) -> table[]
arch_rpg_inventory.sort(player, mode?)
arch_rpg_inventory.move_to_hotbar(player, stack_index, hotbar_slot)
arch_rpg_inventory.transfer(player, container_id, from_idx, to_idx, count)
```

---

## §7 Save Format & Migration

### 7.1 Save v2 schema

Phase 4 introduces save version 2. Structure:

```json
{
  "version": 2,
  "player": {
    "class": "warrior",
    "level": 5,
    "xp": 2982,
    "attributes": { "STR": 10, "DEX": 6, "VIT": 9, "INT": 3, "WIS": 4, "END": 7 },
    "stat_points_unspent": 2,
    "skill_points_unspent": 1,
    "equipment": {
      "main_hand": { "id": "arch_rpg_items:iron_sword", "durability": 100 },
      "chest": { "id": "arch_rpg_items:leather_chest", "durability": 80 }
    },
    "inventory": [
      { "id": "arch_rpg_items:health_potion_minor", "count": 2 },
      { "id": "arch_rpg_items:steel_sword", "count": 1, "meta": {} }
    ],
    "hotbar_indices": [1, 2, 0, 0, 0, 0, 0, 0, 0, 0]
  }
}
```

### 7.2 Migration v1 → v2

v1 saves (Phase 3) have no RPG data. Migration:

1. Detect missing `"version"` or `version < 2`.
2. Initialize default Warrior attributes, level 1, empty inventory/equipment.
3. Set `version = 2`.
4. Log `[ARCH-RPG:save] migrated player=<name> from=v1 to=v2`.

Migration MUST be idempotent. Test: load v1 save → verify v2 defaults → re-save → reload → identical.

### 7.3 Future-proofing

- Version field always present.
- Unknown fields preserved on load (forward compat).
- Missing fields filled with defaults + logged warning.

---

## §8 Economy Stub

Phase 4 defines `value` on every item (copper pieces) but implements **no vendors, trading, or currency items**. Purpose:

- Establish value scale for future vendor pricing.
- Enable loot-table weighting by value in Phase 6.
- Prevent retroactive rebalancing of 50+ items later.

Currency item (`arch_rpg_items:copper_coin`) registered but unobtainable. Wallet stored in save as `player.currency = 0`. No spend/earn paths yet.

---

## §9 Logging Conventions

All Phase 4 logs use prefixed format for grep-ability:

| Prefix | Module | Example |
|--------|--------|---------|
| `[ARCH-RPG:stats]` | arch_rpg_stats | `[ARCH-RPG:stats] recalc player=alice MHP=244 PATK=28` |
| `[ARCH-RPG:xp]` | arch_rpg_xp | `[ARCH-RPG:xp] gain player=alice amount=120 source=mob_kill` |
| `[ARCH-RPG:class]` | arch_rpg_classes | `[ARCH-RPG:class] assign player=alice class=warrior` |
| `[ARCH-RPG:item]` | arch_rpg_items | `[ARCH-RPG:item] register id=arch_rpg_items:iron_sword` |
| `[ARCH-RPG:inv]` | arch_rpg_inventory | `[ARCH-RPG:inv] add player=alice item=health_potion_minor count=3` |
| `[ARCH-RPG:equip]` | arch_rpg_equipment | `[ARCH-RPG:equip] player=alice slot=main_hand item=iron_sword action=equip` |
| `[ARCH-RPG:save]` | arch_rpg_save | `[ARCH-RPG:save] migrated player=alice from=v1 to=v2` |

NEVER log raw tables; serialize key fields only. NEVER log passwords/secrets (none expected, but enforce).

---

## §10 Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Derived stat formula bug causes negative HP | Game-breaking | Unit tests for every formula edge case (attr=1, attr=99, zero equip) |
| Equip/unequip stat delta mismatch | Persistent wrong stats | Delta verified in unit test; log every modify call |
| Unified Inventory incompatible | Delay | Evaluation rubric scored before implementation; fallback own UI scoped to 3 days |
| Save migration corrupts data | Loss | Idempotent migration + v1 backup before write |
| Item ID typo silently fails | Invisible bug | `arch_rpg_items.get` returns nil → assert in dev mode |
| Class branch creep | Tech debt | Code review checklist includes "no class string literals" |

---

## §11 Layout after this phase

```text
game/arch_rpg/mods/
├── arch_rpg_stats/
│   ├── init.lua              # API + formula engine
│   └── formulas.lua          # derived stat functions
├── arch_rpg_xp/
│   └── init.lua              # XP/level curve + allocation
├── arch_rpg_classes/
│   ├── init.lua              # registry API
│   └── data/warrior.lua      # Warrior definition
├── arch_rpg_items/
│   ├── init.lua              # registry + schema validation
│   └── data/
│       ├── weapons.lua
│       ├── armor.lua
│       ├── consumables.lua
│       └── accessories.lua
├── arch_rpg_inventory/
│   └── init.lua              # stack/hotbar/sort/transfer
├── arch_rpg_equipment/
│   └── init.lua              # equip/unequip + stat application
├── arch_rpg_ui/
│   └── init.lua              # minimal HUD (formspec or HUD elements)
└── arch_rpg_save/
    └── init.lua              # v2 schema + migration

tests/
├── test_stats.lua
├── test_xp_curve.lua
├── test_equip_deltas.lua
├── test_stacking.lua
├── test_class_restrictions.lua
└── test_save_migration.lua

scripts/
└── test.sh                   # runs all tests above
```