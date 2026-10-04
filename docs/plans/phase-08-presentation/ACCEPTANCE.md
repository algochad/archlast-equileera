# Phase 8 Acceptance — Presentation Pass Testable

All checks runnable in order. Phase 8 passes only if ALL green. Fail → fix before ship.

## A1. No dev/debug UI in default build

```bash
scripts/run-dev.sh --default-launch
# Manually verify: no F3 panel, no /inspect output, no wireframe, no raw stat dumps
# Automated check:
grep -rE '(debug_overlay|raw_dump|wireframe_toggle|bbox_debug|F3_panel)' mods/arch_rpg_ui/ && echo "FAIL: dev UI remnants found" || echo "PASS: clean"
```

Pass: zero matches for known dev-UI patterns; manual visual confirmation on launch.

## A2. License completeness

```bash
scripts/verify-licenses.sh
echo "Exit code: $?"
```

Pass: exit code 0, zero unverified assets reported. Script scans `game/arch_rpg/textures/`, `models/`, `sounds/`, `music/` and cross-references `dependencies/licenses/`.

## A3. Performance regression (60s roam + 30s combat)

```bash
# Capture baseline if not already done (Phase 7 artifact)
test -f perf/baseline.json || scripts/profile-perf.sh --baseline

# Capture current
scripts/profile-perf.sh --roam-combat --duration-roam 60 --duration-combat 30 --output perf/current.json

# Compare
scripts/profile-perf.sh --compare perf/baseline.json perf/current.json
```

Pass: output shows ≤10% regression on FPS, frame-p95-ms, and server-tick-ms. Any metric >10% = FAIL; fix and re-run.

## A4. Per-screen UI checklist

Run each test; visually confirm elements render with live data.

```bash
screens=(hud hotbar inventory equipment stats skills tracker journal dialogue map settings)
for s in "${screens[@]}"; do
  echo "--- Testing $s ---"
  scripts/run-dev.sh --ui-test "$s" --timeout 30
  read -p "Screen $s OK? (y/n): " ok
  test "$ok" = "y" || { echo "FAIL: $s"; exit 1; }
done
echo "ALL SCREENS PASS"
```

Pass: all 11 screens confirmed. Each screen must show:
- HUD: health/stamina/mana bars update on damage/regen; XP ring fills; target frame populates
- Hotbar: slots reflect inventory; cooldown sweeps animate
- Inventory: grid populated; drag-drop works; search filters
- Equipment: paper-doll shows equipped items; stat delta previews
- Stats: attributes match character sheet; buffs listed
- Skills: tree renders; unlocked skills highlighted; cooldowns overlay
- Tracker: active quests listed; objectives update on progress
- Journal: entries appear chronologically; filters work
- Dialogue: NPC portrait loads; choices clickable; text advances
- Map: world rendered; player marker moves; waypoints visible
- Settings: changes persist across restart

## A5. Audio trigger checklist

```bash
scripts/run-dev.sh --audio-test --log /tmp/audio-triggers.log
# Expected triggers (must all appear in log with [ARCH-RPG:AUDIO] prefix):
required_triggers=(
  "player_step" "weapon_swing" "weapon_hit" "damage_taken"
  "spell_cast" "enemy_alert" "npc_greet" "water_enter"
  "weather_rain_start" "ui_open" "quest_accepted" "player_level_up"
  "item_pickup" "boss_spawn" "zone_entered"
)
missing=0
for t in "${required_triggers[@]}"; do
  grep -q "\[ARCH-RPG:AUDIO\].*$t" /tmp/audio-triggers.log || { echo "MISSING: $t"; missing=$((missing+1)); }
done
test $missing -eq 0 && echo "AUDIO TRIGGERS PASS" || echo "FAIL: $missing triggers missing"
```

Pass: all 15 representative triggers logged. Missing = investigate event emission or subscription.

## A6. Texture override sanity

```bash
test -f game/arch_rpg/textures/OVERRIDES.md || { echo "FAIL: OVERRIDES.md missing"; exit 1; }
override_count=$(grep -c '^|' game/arch_rpg/textures/OVERRIDES.md | head -1)
total_textures=$(find game/arch_rpg/textures -name '*.png' | wc -l)
threshold=$((total_textures * 15 / 100))
test "$override_count" -le "$threshold" && echo "OVERRIDE RATIO PASS ($override_count/$total_textures)" || echo "FAIL: overrides exceed 15%"
```

Pass: override count ≤15% of total texture count.

## A7. Atmosphere stack decision documented

```bash
test -f mods/arch_rpg_atmosphere/STACK_DECISION.md || { echo "FAIL: stack decision missing"; exit 1; }
grep -qE '(Climate API|Regional Weather)' mods/arch_rpg_atmosphere/STACK_DECISION.md || { echo "FAIL: no stack chosen"; exit 1; }
echo "ATMOSPHERE DECISION PASS"
```

Pass: decision file exists and names exactly one chosen stack.

## A8. Screenshot procedure (reference images)

Manual procedure; produce reference screenshots for QA archive.

1. Launch: `scripts/run-dev.sh --default-launch`
2. Set resolution 1920×1080, mid settings.
3. Capture each UI screen (A4 list) via system screenshot tool.
4. Capture atmosphere states: clear/rain/snow/storm/fog (cycle via dev command `/weather <state>` if available, else wait).
5. Capture map with waypoints, fog-of-war boundary, POI markers.
6. Save to `docs/screenshots/phase-08/` with naming `<screen_or_state>_YYYY-MM-DD.png`.
7. Verify all files present:

```bash
expected=(hud hotbar inventory equipment stats skills tracker journal dialogue map settings
          weather_clear weather_rain weather_snow weather_storm weather_fog
          map_waypoints map_fog_boundary map_poi)
missing=0
for f in "${expected[@]}"; do
  ls docs/screenshots/phase-08/${f}_*.png >/dev/null 2>&1 || { echo "MISSING: $f"; missing=$((missing+1)); }
done
test $missing -eq 0 && echo "SCREENSHOTS PASS" || echo "FAIL: $missing screenshots missing"
```

Pass: all expected screenshots captured and dated.

## A9. Model attachment validation

```bash
attachments=(player warrior_armor warrior_weapons mob_01 mob_02 mob_03 boss)
for a in "${attachments[@]}"; do
  scripts/run-dev.sh --model-test "$a" --timeout 20
  echo "$a: check attach points visually"
done
```

Pass: all models load; attach points functional; no missing-bone errors in log.

## Fail protocol

Any red check = STOP. Fix root cause. Re-run failed check + all subsequent checks. Do NOT ship with known failures.

Record results in `docs/plans/phase-08-presentation/RESULTS.md`:
- Date, commit hash, tester name.
- Each check: PASS/FAIL + notes.
- Perf numbers: baseline vs current (FPS, p95, tick).
- Screenshot manifest.
- License audit summary.

## Logging verification

```bash
grep -c '\[ARCH-RPG:UI\]' /tmp/archlast-dev.log
grep -c '\[ARCH-RPG:AUDIO\]' /tmp/archlast-dev.log
grep -c '\[ARCH-RPG:ATMOSPHERE\]' /tmp/archlast-dev.log
grep -c '\[ARCH-RPG:PRESENTATION\]' /tmp/archlast-dev.log
```

Pass: all four prefixes present in dev log during test session. Absent prefix = module not emitting; investigate.