# Phase 4 Acceptance — RPG Foundation Testable

All checks runnable in order from repo root. Phase 4 passes only if **all** green. Record failures in `docs/plans/phase-04-rpg-foundation/RESULTS.md`.

---

## A1. Unit tests pass via test runner

```bash
scripts/test.sh
echo $?
```

Pass: exit code 0. Output includes `[PASS]` for each of:

- `test_stats` — derived stat formulas at attr=1, 50, 99; edge cases
- `test_xp_curve` — XP(L) matches README §2.2 table L=2..20; cumulative sums; multi-level-up
- `test_class_restrictions` — Warrior defaults correct; unknown class returns nil
- `test_stacking` — stack_max respected; meta-incompatible stacks don't merge; rarity mult applied
- `test_equip_deltas` — equip/unequip produces exact stat deltas; requirements enforced
- `test_save_migration` — v1→v2 idempotent; round-trip identical; unknown fields preserved

Fail: any `[FAIL]` or non-zero exit → stop, fix, re-run.

---

## A2. Stat calculation unit detail

```bash
scripts/test.sh --filter test_stats
```

Verify output includes tests for:

- [ ] MHP at VIT=1, STR=1 → `floor(100 + 1*12 + 1*2)` = 114
- [ ] MHP at VIT=99, STR=99 → `floor(100 + 99*12 + 99*2)` = 1486
- [ ] PATK at STR=50, DEX=50, no weapon → `floor(50*2.5 + 50*0.5)` = 150
- [ ] CRIT% at DEX=99 → `min(50, 2.0 + 99*0.6)` = 50 (clamped)
- [ ] MSPD at DEX=99, no armor penalty → `1.0 + 99*0.008` = 1.792
- [ ] RFI at WIS=1, END=1 → `floor(1*0.4 + 1*0.2)` = 0
- [ ] Negative buff on ARM → result ≥ 0 (no negative armor)

All must show `[PASS]`.

---

## A3. XP curve unit detail

```bash
scripts/test.sh --filter test_xp_curve
```

Verify output includes tests for:

- [ ] `xp_for_next_level(2)` = 150
- [ ] `xp_for_next_level(10)` = 3036
- [ ] `xp_for_next_level(20)` = 7849
- [ ] Cumulative XP at level 5 = 1862
- [ ] Cumulative XP at level 20 = 64334
- [ ] add(200 XP) at level 1 → level 2, stat_pts=2, skill_pts=1
- [ ] add(10000 XP) at level 1 → correct multi-level result with summed points
- [ ] allocate_stat_point("STR") with unspent=0 → returns false

All must show `[PASS]`.

---

## A4. Equipment delta unit detail

```bash
scripts/test.sh --filter test_equip_deltas
```

Verify output includes tests for:

- [ ] Equip iron_sword → PATK += 8, ASPD += 0.05
- [ ] Unequip iron_sword → PATK/ASPD return to baseline
- [ ] Swap iron_sword → steel_sword → net PATK delta = +6 (14−8)
- [ ] Equip chainmail_chest with STR < 12 → fails, stats unchanged
- [ ] Equip warrior_ring_vigor with non-warrior class → fails
- [ ] Full Warrior starting set → all 16 derived stats match manual calc
- [ ] Block chance with wooden_shield → BLK% includes VIT*0.8 + 8

All must show `[PASS]`.

---

## A5. Stacking & item unit detail

```bash
scripts/test.sh --filter test_stacking
```

Verify output includes tests for:

- [ ] health_potion_minor stack to 20, not 21
- [ ] iron_sword (stack_max=1) never merges
- [ ] Same id, different meta → separate stacks
- [ ] get_stat_bonuses("chainmail_chest") → ARM=14, END=2, MSPD=−0.05 (rare mult applied)
- [ ] All 10 example items register without validation error
- [ ] can_equip with met requirements → true
- [ ] can_equip with unmet level → false + reason

All must show `[PASS]`.

---

## A6. In-game: equip sword raises Physical Attack

Procedure (manual or scripted headless):

1. Launch: `scripts/run-dev.sh --smoke`
2. Connect as Warrior player
3. Record baseline PATK: `/stats patk` or check HUD tooltip
4. Open equipment screen, equip Iron Sword to main_hand
5. Record new PATK
6. **Pass**: new_PATK = baseline + 8 exactly
7. Unequip Iron Sword
8. **Pass**: PATK returns to baseline value
9. Check log: `grep '\[ARCH-RPG:equip\]' /tmp/archlast-smoke.log` shows both equip and unequip entries

---

## A7. In-game: level-up increases Max HP

Procedure:

1. Player at level 1, record MHP
2. Grant XP: `/xp add 200` (triggers level 2)
3. Verify level = 2 via `/level` or HUD
4. Record new MHP
5. **Pass**: new_MHP > old_MHP; delta matches formula with updated attributes
6. Check log: `grep '\[ARCH-RPG:xp\] level_up' /tmp/archlast-smoke.log` shows `from=1 to=2 stat_pts=2 skill_pts=1`

---

## A8. Save/reload preserves RPG state

Procedure:

1. Reach level 3+, equip Steel Sword + Leather Chest, hold 5 Minor Health Potions
2. Force save: `/save` or wait for auto-save
3. Exit server cleanly (`/shutdown`)
4. Restart: `scripts/run-dev.sh --smoke`
5. Reconnect same player
6. Verify:
   - [ ] Level unchanged
   - [ ] XP unchanged
   - [ ] Equipped items match pre-save
   - [ ] Inventory contents match pre-save (counts, order)
   - [ ] Unspent stat/skill points preserved
7. Check log: no `[ARCH-RPG:save] migrated` warning (already v2); no Lua errors

**Pass**: all checkboxes confirmed. No data loss.

---

## A9. Log prefix verification

After running A6–A8 procedures:

```bash
LOG=/tmp/archlast-smoke.log
for prefix in stats xp class item inv equip save; do
  count=$(grep -c "\[ARCH-RPG:$prefix\]" "$LOG" 2>/dev/null || echo 0)
  echo "$prefix: $count"
done
grep -iE 'error|segfault|moderror|assertion' "$LOG" || echo CLEAN
```

**Pass**: every prefix count ≥ 1. Final grep outputs CLEAN.

---

## A10. Anti-pattern grep (no class literals)

```bash
grep -rn 'class ==' game/arch_rpg/mods/ --include='*.lua' | grep -v arch_rpg_classes || echo CLEAN
grep -rn '"warrior"' game/arch_rpg/mods/ --include='*.lua' | grep -v arch_rpg_classes/data || echo CLEAN
```

**Pass**: both output CLEAN. Zero hits outside allowed modules.

---

## A11. Document line counts

```bash
wc -l docs/plans/phase-04-rpg-foundation/{README,TASKS,ACCEPTANCE}.md
```

**Pass**:

- README.md ≥ 150 lines
- TASKS.md ≥ 100 lines
- ACCEPTANCE.md ≥ 60 lines

---

## A12. PLAN.md unmodified

```bash
git diff --quiet docs/plans/phase-04-rpg-foundation/PLAN.md && echo UNCHANGED || echo MODIFIED
```

**Pass**: UNCHANGED.

---

## Fail protocol

Any red check → **do not proceed to Phase 5**. Create/update `docs/plans/phase-04-rpg-foundation/RESULTS.md`:

```markdown
## Run <date> <commit-sha>

### Failed checks
- A<N>: <description>
  - Expected: ...
  - Actual: ...
  - Log excerpt: ...

### Root cause
...

### Fix applied
...
```

Re-run full acceptance after fix. All 12 checks must be green before Phase 5 starts.