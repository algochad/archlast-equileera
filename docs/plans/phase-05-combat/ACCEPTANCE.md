# Phase 5 Acceptance — Combat MVP Testable

All checks runnable in order from repo root. Phase 5 passes only if every section is green. Stop at first red; fix before proceeding.

## A1. Unit tests pass

```bash
scripts/test-combat.sh
echo $?
```

Pass: exit 0. Expected spec count ≥ 28 covering:

- Damage pipeline golden vectors (10 cases: hit/miss/crit/armor/elemental/status/clamp/min/max).
- Crit variance: 1000 rolls, observed crit rate within ±2% of configured `crit_chance`.
- Armor mitigation curve: base 100 damage vs armor 0/50/100/200 → 100/67/50/33 final (±1 rounding).
- Loot weight distribution: χ² p > 0.05 for Wolf/Goblin/Skeleton tables over 10k samples each.
- Level-scaling bounds: player_level = mob_level ± 10 produces weights/qty within [0.5×, 2.0×] / [0.8×, 1.5×].
- Skill cast success: Power Strike with valid stamina/mana/cooldown/weapon returns `true, ""`.
- Skill rejection: cooldown active → `"cooldown"`; stamina < 30 → `"insufficient_stamina"`; level < 3 → `"requirement_unmet"`; silenced → `"silenced"`.
- Event emission: every successful/failing cast emits `skill_cast`; every damage call emits `player_damage` or `mob_damage`.

## A2. In-game kill → XP → loot → level-up smoke

Launch dev server with test biome spawner active:

```bash
scripts/run-dev.sh --world tests/worlds/combat_smoke --logfile /tmp/archlast-combat-smoke.log
```

In-game procedure (manual or headless bot):

1. Equip melee weapon, confirm stamina ≥ 30, mana ≥ 10.
2. Kill one Wolf → observe floating white/yellow number, HP bar updates, `mob_killed` event in log.
3. Kill one Goblin → loot drop appears at corpse position within 0.5 s.
4. Kill one Skeleton → XP gain triggers level-up if threshold met; UI level indicator updates within 200 ms.
5. Verify inventory contains expected drops (wolf_pelt/raw_meat, goblin_ear/rusty_dagger/copper_coin, bone/arrow_bone).

Pass: all five steps complete without Lua error, no missing events in log, UI responds within latency budget.

## A3. Armor mitigation + crit variance verification

Dedicated validation run against known inputs:

```bash
scripts/test-combat.sh --filter armor_curve
scripts/test-combat.sh --filter crit_variance
```

Armor curve pass criteria (base 100 physical, no elemental/status):

| Armor | Expected Final | Tolerance |
| --- | --- | --- |
| 0 | 100 | ±0 |
| 50 | 67 | ±1 |
| 100 | 50 | ±0 |
| 200 | 33 | ±1 |

Crit variance pass criteria: 1000 Power Strikes vs dummy target, crit count ∈ [180, 220] (configured 20%). Log shows `[ARCH-RPG:COMBAT] crit=true/false` per hit; grep count matches.

```bash
grep -c 'crit=true' /tmp/archlast-combat-smoke.log
grep -c 'crit=false' /tmp/archlast-combat-smoke.log
```

Pass: sum = 1000, true count in [180, 220].

## A4. Globalstep CPU budget check

Profiled run with 50 concurrent mobs:

```bash
scripts/run-dev.sh --profile --duration 60 --world tests/worlds/combat_perf --logfile /tmp/archlast-profile.log
awk -F',' '$2 > 3.5 {print "BUDGET EXCEEDED:", $0; exit 1}' tests/profiles/combat_ai.csv
echo $?
```

Pass: exit 0, max tick ≤ 3.5 ms, average ≤ 2.0 ms. CSV format: `timestamp_ms,globalstep_combat_ai_ms,mob_count,throttle_active`.

If budget exceeded, tune detect/chase ranges or tick rates per README AI state table; re-profile before re-running acceptance.

## A5. Log prefix + dependency direction check

```bash
# Logging prefix compliance
grep -rn '\[ARCH-RPG:' game/arch_rpg/mods/arch_rpg_{combat,skills,mobs,loot}/ \
  | grep -vE '\[(ARCH-RPG:(COMBAT|SKILLS|MOBS|LOOT))\]' && echo PREFIX_VIOLATION || echo PREFIX_CLEAN

# Dependency direction: gameplay must not import UI
grep -rn 'arch_rpg_ui' game/arch_rpg/mods/arch_rpg_{combat,skills,mobs,loot}/ && echo DEP_VIOLATION || echo DEP_CLEAN
```

Pass: both outputs end with `_CLEAN`. Any violation = fail; fix imports/log lines before re-run.

## A6. Mob framework lock verification

```bash
grep -A5 'mobs.mobs_redo' dependencies/mods.lock
```

Pass: entry exists with 40-char commit hash, license = LGPLv2.1, used_by = arch_rpg_mobs. No other mob framework entries present:

```bash
grep -cE '^\[mobs\.' dependencies/mods.lock
```

Pass: count = 1. Additional entries = mixing violation = fail.

## A7. Server-authority enforcement spot-check

Manual or scripted test: send crafted client packet with `base_damage = 9999` directly to combat API bypassing skill cast.

```bash
# Headless test harness (tests/integration/combat/authority_spec.lua)
scripts/test-combat.sh --filter authority
```

Pass: server rejects with reason `"invalid"` or clamps to MAX_DAMAGE (9999); no unvalidated damage applied. Client-side value never trusted.

## Fail → do not proceed

Any red = fix Phase 5 before Phase 6. Record failure details + commit hash in `docs/plans/phase-05-combat/RESULTS.md` (create on first run). Include:

- Failed section ID (A1–A7).
- Command output excerpt.
- Suspected root cause.
- Fix applied + re-test result.

## Re-run policy

After any code change affecting combat/skills/mobs/loot:

1. Re-run A1 (unit tests) first — fast feedback.
2. If A1 green, re-run A4 (perf) — regression catch.
3. Full acceptance (A1–A7) required before marking phase complete or merging to main.

## Evidence retention

Keep last passing run artifacts:

- `tests/profiles/combat_ai.csv` (overwrite each profile run).
- `/tmp/archlast-combat-smoke.log` and `/tmp/archlast-profile.log` (retain until next phase starts).
- Unit test XML/JSON report if harness supports it (optional but recommended).

These artifacts are referenced by Phase 6 UI polish and Phase 7 dungeon integration to validate no regressions.