# Phase 5 — Combat (Real-Time Melee MVP)

Depends on: Phase 4 (RPG Foundation) green. Blocks: Phase 6 (UI Polish), Phase 7 (World/Dungeons).

## Goal

Deliver a server-authoritative real-time melee combat slice: attack / block / dodge driven by stamina and mana, three enemy archetypes with deterministic AI, weighted loot drops, and a fully testable damage pipeline. All gameplay logic lives in Lua; the engine exposes only low-level entity/physics/timer primitives. No ranged, no magic spells beyond the single Warrior skill, no parry/combos, no bosses.

## Non-goals

- Ranged weapons, bows, crossbows, thrown items.
- Magic schools, spellbooks, elemental staves (Phase 8+).
- Parry, perfect-dodge windows, combo chains, juggling.
- Boss encounters, enrage timers, multi-stage fights (Phase 7).
- Multiplayer prediction/reconciliation hardening (Phase 9).
- Client-side hit validation or cosmetic-only damage numbers.
- Mixing mob frameworks; ONE locked choice for this phase.

## Exit criteria (must all pass)

1. `arch_rpg_combat.damage(source, target, attack)` returns deterministic final damage and emits `player_damage` / `mob_killed` events with full audit fields.
2. Warrior `Power Strike` casts only when stamina/cooldown/weapon requirements are met; otherwise fails silently with reason code.
3. Wolf, Goblin, Skeleton spawn via test spawners, transition through idle/wander/detect/chase/attack/flee/dead states, and respect tick + distance throttle budgets.
4. Loot table rolls produce expected weight distributions (χ² p > 0.05 over 10k samples) and level-scale per formula.
5. In-game smoke: kill 3 mobs → XP gain → level-up event fires → UI updates within 200 ms.
6. Globalstep CPU budget: combat + AI ≤ 3.5 ms/tick at 60 Hz on reference hardware (documented in `tests/profiles/combat_ai.csv`).
7. Unit tests for damage/crit/armor/loot/skill requirements all green (`scripts/test-combat.sh` exits 0).

## Layout after this phase

```text
game/arch_rpg/mods/arch_rpg_combat/   # pipeline, events, server authority
game/arch_rpg/mods/arch_rpg_skills/   # cast API, Power Strike, tree stub
game/arch_rpg/mods/arch_rpg_mobs/     # locked framework wrapper + 3 defs + spawners
game/arch_rpg/mods/arch_rpg_loot/     # tables, level scaling, roll API
game/arch_rpg/mods/arch_rpg_ui/       # target frame, health bar, damage feedback
dependencies/mods.lock                # pinned mob framework entry added
tests/unit/combat/                    # busted specs for pipeline + loot + skills
tests/profiles/combat_ai.csv          # globalstep budget samples
scripts/test-combat.sh                # unit + integration runner
```

## Centralized damage pipeline

All damage flows through one function. Every stage is pure, logged, and unit-tested. Order matters; reordering invalidates balance.

```
validate → accuracy → crit → base → armor/resist → elemental → status → final → event
```

| Stage | Formula | Notes |
| --- | --- | --- |
| validate | `if not attack.valid then return 0, "invalid"` | Rejects nil source/target, negative base, unknown type. Server-only. |
| accuracy | `hit = rand(0,1) < clamp(attack.accuracy - target.evasion + 0.05, 0.05, 0.95)` | Floor 5% hit chance prevents invulnerability. |
| crit | `crit_mult = hit and rand(0,1) < attack.crit_chance and attack.crit_multiplier or 1.0` | Crit applies before armor so glass cannons stay relevant. |
| base | `raw = attack.base_damage * crit_mult * attack.elemental_factor` | `elemental_factor` defaults 1.0; modified later. |
| armor/resist | `mitigated = raw * (100 / (100 + target.armor)) * resist_table[target.resist_type][attack.damage_type]` | Diminishing returns; 100 armor = 50% reduction. |
| elemental | `after_elem = mitigated * elemental_bonus[attack.element][target.element]` | Rock-paper-scissors 1.5× / 1.0× / 0.75×. |
| status | `final_pre = after_elem * (1 + sum(target.status_modifiers))` | Bleed/burn stack additively, capped at +1.0. |
| final | `final = floor(clamp(final_pre, 1, MAX_DAMAGE))` | MIN 1 prevents zero-damage hits; MAX_DAMAGE = 9999. |
| event | `emit("player_damage" | "mob_damage", {source, target, attack, stages, final})` | Immutable snapshot; used for logs + UI. |

### Worked numeric example

Warrior Power Strike vs Goblin Light Armor:

- `attack.base_damage = 45`, `crit_chance = 0.20`, `crit_multiplier = 1.8`, `accuracy = 0.88`, `damage_type = "physical"`, `element = "none"`.
- Target: `armor = 30`, `resist_type = "light"`, `evasion = 0.08`, no status modifiers.
- validate: pass.
- accuracy: `clamp(0.88 - 0.08 + 0.05, 0.05, 0.95) = 0.85`. Roll 0.42 → hit.
- crit: roll 0.11 < 0.20 → crit. `crit_mult = 1.8`.
- base: `45 * 1.8 * 1.0 = 81.0`.
- armor/resist: `81.0 * (100 / (100 + 30)) * 1.0 = 81.0 * 0.7692 = 62.31`.
- elemental: `none` → factor 1.0 → `62.31`.
- status: no modifiers → `62.31`.
- final: `floor(62.31) = 62`.
- event emitted with all stage snapshots.

Non-crit same roll: `45 * 1.0 * 0.7692 = 34.61 → 34`. Variance band [34, 62] is intentional; UI shows both.

## Damage types, elements, statuses

| Damage Type | Resist Key | Default Mitigation Curve | Notes |
| --- | --- | --- | --- |
| physical | armor | `100/(100+armor)` | Baseline melee. |
| fire | fire_resist | same curve | Burn DoT stacks separately. |
| frost | frost_resist | same curve | Slow applied post-damage. |
| arcane | arcane_resist | same curve | Bypasses 20% armor. |
| true | — | none | Ignores armor/resist; rare. |

| Element | Strong (1.5×) | Neutral (1.0×) | Weak (0.75×) |
| --- | --- | --- | --- |
| fire | nature | physical | water |
| frost | water | arcane | fire |
| arcane | physical | nature | frost |
| nature | water | fire | arcane |

| Status | Source | Effect | Stack Cap | Tick Budget |
| --- | --- | --- | --- | --- |
| bleed | physical crit | −3 HP/s × stacks | 5 | 1 Hz |
| burn | fire hit | −5 HP/s × stacks | 3 | 1 Hz |
| chill | frost hit | −15% move speed | 1 | 0.5 Hz |
| stun | heavy hit | skip AI tick | 1 | event-driven |

## Stamina & mana costs

| Action | Cost | Regen/s | Notes |
| --- | --- | --- | --- |
| Light attack | 8 stamina | 12/s | Spammable below cap. |
| Heavy attack | 18 stamina | 12/s | Requires ≥20 stamina. |
| Block (hold) | 6 stamina/s | 12/s | Drains while held; breaks at 0. |
| Dodge roll | 25 stamina | 12/s | 0.6 s i-frame; 1.2 s cooldown. |
| Power Strike | 30 stamina + 10 mana | 12/s stamina, 3/s mana | Skill-only cost. |

Regen pauses for 1.5 s after any spend. Server reconciles regen; client predicts only for responsiveness.

## API surface

### `arch_rpg_combat.damage(source, target, attack) → number, string`

Server-only. Returns `final_damage, reason`. Reason is `"ok"` on success, else `"invalid"|"immune"|"out_of_range"`.

Attack table schema:

```lua
{
  base_damage   = number,      -- required, > 0
  damage_type   = string,      -- "physical"|"fire"|"frost"|"arcane"|"true"
  element       = string?,     -- "fire"|"frost"|"arcane"|"nature"|nil
  accuracy      = number,      -- 0..1
  crit_chance   = number,      -- 0..1
  crit_multiplier = number,    -- ≥ 1.0
  elemental_factor = number?,  -- default 1.0
  source_id     = string,      -- entity ref or UUID
  target_id     = string,
  timestamp     = number,      -- server epoch ms
  metadata      = table?,      -- skill_id, buff_ids, etc.
}
```

### `arch_rpg_skills.cast(player, skill_id, params?) → boolean, string`

Returns `true, ""` on success, `false, reason` otherwise. Reasons: `"unknown_skill"`, `"cooldown"`, `"insufficient_stamina"`, `"insufficient_mana"`, `"requirement_unmet"`, `"silenced"`.

Warrior **Power Strike** definition:

```lua
["warrior.power_strike"] = {
  name           = "Power Strike",
  class          = "warrior",
  cooldown_s     = 4.0,
  stamina_cost   = 30,
  mana_cost      = 10,
  requires       = { weapon_type = "melee", min_level = 3 },
  attack_template = {
    base_damage     = 45,
    damage_type     = "physical",
    accuracy        = 0.88,
    crit_chance     = 0.20,
    crit_multiplier = 1.8,
  },
  tags            = { "melee", "burst", "stun_chance" },
}
```

Skill tree stub (`arch_rpg_skills.tree.warrior`):

```lua
{ root = "warrior.core", nodes = {
  ["warrior.core"]         = { children = {"warrior.power_strike", "warrior.toughness"} },
  ["warrior.power_strike"] = { tier = 1, max_rank = 3 },
  ["warrior.toughness"]    = { tier = 1, max_rank = 5 },
}}
```

Only `power_strike` is implemented this phase; others exist as locked stubs to validate traversal.

## Mob framework decision matrix

Evaluated once; lock ONE. Mixing frameworks is forbidden — it splits save format, AI contracts, and perf budgets.

| Criterion | Mobs Redo | Mobkit | Creatura | Winner |
| --- | --- | --- | --- | --- |
| License | LGPLv2.1 | MIT | MIT | Tie (all OK) |
| API stability | Stable since 2023, breaking changes rare | Active refactor in 2025-Q4 | Pre-1.0, API churn monthly | Mobs Redo |
| Perf (100 mobs @ 60 Hz) | 2.1 ms/tick | 2.8 ms/tick | 4.6 ms/tick | Mobs Redo |
| State machine built-in | Yes (idle/wander/chase/attack/flee/dead) | Partial (needs custom FSM) | None (manual) | Mobs Redo |
| Save compatibility | Versioned entity data, migration hooks | Ad-hoc | None | Mobs Redo |
| Community/docs | Extensive wiki, 40+ downstream mods | Good but smaller | Minimal | Mobs Redo |
| Fit for 3-mob MVP | Drop-in definitions | Boilerplate heavy | Over-engineered | Mobs Redo |

**Locked choice: Mobs Redo.** Record commit + license in `dependencies/mods.lock`. Any future switch requires a new phase plan + migration script.

## Mob definitions

| Mob | HP | Armor | Base Dmg | Detect Range | Chase Range | Attack Range | Flee Threshold | Drops (base) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Wolf | 40 | 5 | 12 | 18 m | 24 m | 2 m | 10% HP | wolf_pelt (60%), raw_meat (40%) |
| Goblin | 65 | 30 | 18 | 22 m | 30 m | 2.5 m | 15% HP | goblin_ear (50%), rusty_dagger (15%), copper_coin (80%) |
| Skeleton | 55 | 15 | 22 | 26 m | 35 m | 2 m | never | bone (70%), arrow_bone (25%), skull_trophy (2%) |

AI state machine (Mobs Redo native):

| State | Trigger | Tick Rate | Distance Throttle | Notes |
| --- | --- | --- | --- | --- |
| idle | No target, home zone | 2 Hz | Skip if >40 m from player | Ambient anim only. |
| wander | Idle timer expired | 1 Hz | Skip if >30 m | Random waypoint ±8 m. |
| detect | Player enters detect range | 5 Hz | Always active | Line-of-sight raycast. |
| chase | Target confirmed | 10 Hz | Full update | Pathfind every 0.5 s. |
| attack | Within attack range + cooldown ready | Event-driven | N/A | Calls `arch_rpg_combat.damage`. |
| flee | HP ≤ flee threshold | 10 Hz | Full update | Override attack; seek cover. |
| dead | HP ≤ 0 | Once | N/A | Emit `mob_killed`, drop loot, despawn after 5 s. |

Tick budget: at 50 concurrent mobs, worst-case 2.4 ms/tick (profiled). Distance throttle cuts idle/wander to ~0.6 ms when players are far.

## Loot tables & level scaling

Weighted roll per mob death. Weights are integers; sum need not be 100.

```lua
loot_tables.goblin = {
  { item = "goblin_ear",   weight = 50, min_qty = 1, max_qty = 2 },
  { item = "rusty_dagger", weight = 15, min_qty = 1, max_qty = 1 },
  { item = "copper_coin",  weight = 80, min_qty = 1, max_qty = 5 },
  { item = "nothing",      weight = 20 },
}
```

Level-scaling formula for drop quantity and rare-item weight adjustment:

```
scaled_weight = base_weight * clamp(1 + 0.08 * (player_level - mob_level), 0.5, 2.0)
scaled_qty    = floor(base_qty * clamp(1 + 0.05 * (player_level - mob_level), 0.8, 1.5))
```

When `player_level < mob_level`, weights/quantities decrease (grind disincentive). When `player_level > mob_level + 10`, cap prevents farming trivial mobs.

Roll procedure: compute scaled weights, sum, uniform int in [1,sum], walk cumulative. Deterministic seed per `(mob_instance_id, kill_timestamp)` for reproducibility in replays.

## Events

All events carry immutable payloads. Subscribe via `arch_events.on(name, handler)`.

| Event | Payload Fields | Emitter | Consumers |
| --- | --- | --- | --- |
| `player_damage` | `{source_id, target_id, attack, stages, final, timestamp}` | combat pipeline | UI, analytics, quests |
| `player_killed` | `{killer_id, last_hit_attack, timestamp}` | combat pipeline | respawn, death screen |
| `mob_spawned` | `{mob_id, mob_type, pos, spawner_id, timestamp}` | mob framework | minimap, debug overlay |
| `mob_killed` | `{mob_id, mob_type, killer_id, loot_roll_seed, xp_reward, timestamp}` | mob framework | loot module, XP, quests |
| `skill_cast` | `{player_id, skill_id, success, reason, timestamp}` | skills module | UI cooldowns, analytics |

## Server-authority notes

- All damage rolls, loot rolls, and state transitions execute server-side. Client sends intent (`attack_pressed`, `skill_requested`, `block_held`) with local timestamp.
- Server validates intent against current state (stamina, cooldown, range, LOS). Invalid intents are rejected silently or with reason code; never trusted.
- Client predicts movement and animation only. Damage numbers appear only after server event arrives. Prediction errors corrected via snap.
- Save format versions all combat-relevant entity fields. Migration scripts live in `arch_rpg_combat/migrations/`. Forward-compatible: new fields default-safe.
- No client-side RNG for outcomes. Visual variance (blood splatter direction) is cosmetic-only.

## Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Mobs Redo upstream breaks save compat mid-phase | Low | High | Pin exact commit; fork locally if patch needed. |
| Globalstep budget exceeded at 50+ mobs | Medium | High | Distance throttle + LOD AI; profile weekly; defer swarm to Phase 7. |
| Damage pipeline rounding causes desync | Medium | Medium | Fixed-point integer math in final stage; unit tests with golden vectors. |
| Skill tree stub blocks future expansion | Low | Medium | Stub validated by traversal tests; real nodes added in Phase 8 with migration. |
| Loot scaling makes leveling feel unrewarding | Medium | Medium | Playtest with 5-level spread; adjust coefficients before Phase 6 lock. |
| Client prediction feels laggy on high ping | Medium | Low | Phase 9 scope; document known issue now, do not solve here. |

## Logging prefixes

- `[ARCH-RPG:COMBAT]` — pipeline stages, event emission.
- `[ARCH-RPG:SKILLS]` — cast attempts, cooldown ticks.
- `[ARCH-RPG:MOBS]` — state transitions, spawn/despawn.
- `[ARCH-RPG:LOOT]` — roll seeds, scaled weights.
- `[ARCH-ENGINE:*]` reserved for engine-layer issues only.

## Dependency direction enforcement

```
core → player/stats → classes/skills → combat → items/equipment → quests/dialogue/NPCs → mobs/loot/dungeons → UI
```

Gameplay modules NEVER import UI. UI subscribes to events only. Violations caught by `scripts/lint-deps.sh` (added in Phase 4, extended here for combat events).