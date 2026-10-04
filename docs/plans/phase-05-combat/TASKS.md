# Phase 5 Tasks — Combat MVP (ordered, test-driven)

Estimated: 4–6 hours on warm machine. Do in order. Stop at first red. All commands assume repo root cwd.

## 1. Lock mob framework + record (15 min)

- [ ] Evaluate Mobs Redo vs Mobkit vs Creatura per README decision matrix
- [ ] Select **Mobs Redo**; verify LGPLv2.1 license text present in upstream repo
- [ ] Pin exact commit hash; no `latest` or branch tracking
- [ ] Append entry to `dependencies/mods.lock`
- [ ] Commit lock update with message `deps(combat): pin mobs_redo <short-sha>`

```bash
# After choosing commit:
cat >> dependencies/mods.lock <<EOF

[mobs.mobs_redo]
repo = https://github.com/mt-mods/mobs_redo.git
commit = <40-char-sha>
license = LGPLv2.1
used_by = arch_rpg_mobs
notes = Locked for Phase 5; mixing frameworks forbidden.
EOF

git add dependencies/mods.lock
git commit -m "deps(combat): pin mobs_redo <short-sha>"
```

## 2. Combat module skeleton (30 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_combat/init.lua`
- [ ] Implement `arch_rpg_combat.damage(source, target, attack)` with full pipeline per README
- [ ] Emit `player_damage`, `mob_damage`, `player_killed`, `mob_killed` events via `arch_events`
- [ ] Add `[ARCH-RPG:COMBAT]` log prefix for every stage transition
- [ ] Server-only guard: reject calls from client context
- [ ] Write golden-vector unit tests in `tests/unit/combat/pipeline_spec.lua`

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_combat
touch game/arch_rpg/mods/arch_rpg_combat/init.lua
touch game/arch_rpg/mods/arch_rpg_combat/mod.conf
echo "name = arch_rpg_combat" > game/arch_rpg/mods/arch_rpg_combat/mod.conf
echo "depends = arch_rpg_core, arch_events" >> game/arch_rpg/mods/arch_rpg_combat/mod.conf

mkdir -p tests/unit/combat
touch tests/unit/combat/pipeline_spec.lua
```

Run unit stub to confirm harness works:

```bash
scripts/test-combat.sh --filter pipeline
```

## 3. Skills module + Power Strike (45 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_skills/init.lua`
- [ ] Implement `arch_rpg_skills.cast(player, skill_id, params?)` with validation
- [ ] Register Warrior `power_strike` definition per README schema
- [ ] Add skill tree stub `arch_rpg_skills.tree.warrior` with locked nodes
- [ ] Enforce cooldown/stamina/mana/requirement checks; return reason codes
- [ ] Emit `skill_cast` event on every attempt (success or fail)
- [ ] Unit tests: cast success, cooldown rejection, insufficient stamina, requirement unmet

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_skills
touch game/arch_rpg/mods/arch_rpg_skills/init.lua
touch game/arch_rpg/mods/arch_rpg_skills/mod.conf
echo "name = arch_rpg_skills" > game/arch_rpg/mods/arch_rpg_skills/mod.conf
echo "depends = arch_rpg_core, arch_rpg_player, arch_events" >> game/arch_rpg/mods/arch_rpg_skills/mod.conf

mkdir -p tests/unit/skills
touch tests/unit/skills/cast_spec.lua
```

```bash
scripts/test-combat.sh --filter skills
```

## 4. Mob definitions + spawners (60 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_mobs/init.lua` wrapping Mobs Redo API
- [ ] Define Wolf, Goblin, Skeleton per README stat table
- [ ] Implement AI state machine hooks: idle/wander/detect/chase/attack/flee/dead
- [ ] Add distance-throttle logic: skip idle/wander ticks beyond 30–40 m
- [ ] Create test biome spawner at `(0, 10, 0)` with 5 of each mob type
- [ ] Wire `mob_spawned` / `mob_killed` events through `arch_events`
- [ ] Validate spawn positions don't overlap; respect collision boxes
- [ ] Integration test: spawn → detect player → chase → attack → flee/dead cycle

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_mobs
touch game/arch_rpg/mods/arch_rpg_mobs/init.lua
touch game/arch_rpg/mods/arch_rpg_mobs/mod.conf
echo "name = arch_rpg_mobs" > game/arch_rpg/mods/arch_rpg_mobs/mod.conf
echo "depends = arch_rpg_core, arch_rpg_combat, mobs_redo, arch_events" >> game/arch_rpg/mods/arch_rpg_mobs/mod.conf

mkdir -p tests/integration/mobs
touch tests/integration/mobs/spawn_cycle_spec.lua
```

```bash
scripts/test-combat.sh --filter mobs
```

## 5. Loot module (30 min)

- [ ] Create `game/arch_rpg/mods/arch_rpg_loot/init.lua`
- [ ] Define loot tables for Wolf, Goblin, Skeleton per README weights
- [ ] Implement level-scaling formula for weight and quantity adjustment
- [ ] Deterministic seed from `(mob_instance_id, kill_timestamp)` for replay parity
- [ ] Expose `arch_rpg_loot.roll(mob_type, player_level, mob_level, seed) → items[]`
- [ ] Subscribe to `mob_killed` event; drop items at mob death position
- [ ] Unit tests: weight distribution χ² over 10k rolls, level scaling bounds, empty-roll case

```bash
mkdir -p game/arch_rpg/mods/arch_rpg_loot
touch game/arch_rpg/mods/arch_rpg_loot/init.lua
touch game/arch_rpg/mods/arch_rpg_loot/mod.conf
echo "name = arch_rpg_loot" > game/arch_rpg/mods/arch_rpg_loot/mod.conf
echo "depends = arch_rpg_core, arch_rpg_items, arch_events" >> game/arch_rpg/mods/arch_rpg_loot/mod.conf

mkdir -p tests/unit/loot
touch tests/unit/loot/roll_spec.lua
```

```bash
scripts/test-combat.sh --filter loot
```

## 6. Combat UI feedback (30 min)

- [ ] Add target frame: name, HP bar, armor icon (subscribe to `player_damage` for updates)
- [ ] Floating damage numbers: white normal, yellow crit, gray glancing (from event stages)
- [ ] Stamina/mana bars update on spend/regen events
- [ ] Skill cooldown overlay on hotbar (subscribe to `skill_cast`)
- [ ] UI NEVER calls gameplay APIs directly; event-only binding
- [ ] Manual smoke: swing sword, see number, block drains stamina, dodge shows i-frame flash

```bash
# UI lives in existing arch_rpg_ui mod; extend, don't create new
ls game/arch_rpg/mods/arch_rpg_ui/init.lua  # must exist from Phase 4
```

No unit tests for UI; acceptance is visual + event subscription check.

## 7. Unit test suite completion (30 min)

- [ ] Damage pipeline: 10 golden vectors covering hit/miss/crit/armor/elemental/status clamps
- [ ] Crit variance: 1000 rolls, crit rate within ±2% of configured chance
- [ ] Armor mitigation: 0/50/100/200 armor vs fixed base damage, verify curve
- [ ] Loot weights: χ² p > 0.05 for each mob table over 10k samples
- [ ] Skill requirements: level too low, wrong weapon, silenced, cooldown active
- [ ] All specs pass under `scripts/test-combat.sh`; exit 0

```bash
scripts/test-combat.sh
echo $?  # must be 0
```

## 8. AI performance profile (20 min)

- [ ] Spawn 50 mobs (mix of all 3 types) in test biome
- [ ] Run server at 60 Hz for 60 seconds with profiler enabled
- [ ] Record globalstep combat+AI time to `tests/profiles/combat_ai.csv`
- [ ] Verify max tick ≤ 3.5 ms; average ≤ 2.0 ms
- [ ] Document throttle effect: compare with distance throttle disabled
- [ ] If budget exceeded, tune detect/chase ranges or tick rates before proceeding

```bash
mkdir -p tests/profiles
scripts/run-dev.sh --profile --duration 60 --world tests/worlds/combat_perf
grep -E 'globalstep|combat|ai' /tmp/archlast-profile.log | tee tests/profiles/combat_ai.csv
awk -F',' '$2 > 3.5 {exit 1}' tests/profiles/combat_ai.csv  # fail if any tick exceeds budget
```

## Out of scope (defer, do not start)

Ranged weapons, magic spells, parry/combos, boss encounters, multiplayer reconciliation, client-side prediction hardening, additional mob types, skill tree expansion beyond stub, loot rarity tiers, dungeon integration (Phase 7), UI polish beyond feedback (Phase 6).

## Dependency direction reminder

```
core → player/stats → classes/skills → combat → items/equipment → quests/dialogue/NPCs → mobs/loot/dungeons → UI
```

Gameplay modules NEVER import UI. Violations caught by `scripts/lint-deps.sh`.

## Logging prefix enforcement

All new log lines MUST use `[ARCH-RPG:COMBAT]`, `[ARCH-RPG:SKILLS]`, `[ARCH-RPG:MOBS]`, or `[ARCH-RPG:LOOT]`. Engine-layer logs use `[ARCH-ENGINE:*]`. Grep for violations:

```bash
grep -rn '\[ARCH-RPG:' game/arch_rpg/mods/arch_rpg_{combat,skills,mobs,loot}/ | grep -vE '\[(ARCH-RPG:(COMBAT|SKILLS|MOBS|LOOT))\]' && echo VIOLATION || echo CLEAN
```