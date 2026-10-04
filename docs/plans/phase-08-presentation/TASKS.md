# Phase 8 Tasks — Presentation Pass (ordered, testable)

Estimated total: 4–6 weeks for one developer. Do in order. Stop at first red acceptance check.

## 1. Texture evaluation & lock (3 days)

- [ ] Install/load HDX128 in dev build; capture FPS/frame-p95/VRAM via `scripts/profile-perf.sh --texture-test hdx128`
- [ ] Repeat for HDX64, PixelPerfection, Soothing32 IN ORDER
- [ ] Fill texture matrix in README.md §Texture Evaluation Matrix with measured data
- [ ] Select base pack per decision criteria; record rationale
- [ ] Pin selected pack commit/archive in `dependencies/mods.lock` under `[textures.base]`
- [ ] Create `game/arch_rpg/textures/OVERRIDES.md` stub with override naming convention

```bash
scripts/profile-perf.sh --texture-test hdx128
scripts/profile-perf.sh --texture-test hdx64
scripts/profile-perf.sh --texture-test pixel_perfection
scripts/profile-perf.sh --texture-test soothing32
# Edit dependencies/mods.lock manually after decision
mkdir -p game/arch_rpg/textures
touch game/arch_rpg/textures/OVERRIDES.md
```

## 2. Texture overrides (2 days)

- [ ] Identify assets needing project-specific look (armor, weapons, key environment tiles)
- [ ] Create override PNGs in `game/arch_rpg/textures/<category>/<name>.png` mirroring base path
- [ ] Document each override in `OVERRIDES.md`: base file, reason, author, license
- [ ] Verify override count ≤15% of total textures; if exceeded, revisit base pack choice
- [ ] Run `scripts/verify-licenses.sh` to confirm all overrides have license records

```bash
# After creating overrides:
scripts/verify-licenses.sh
wc -l game/arch_rpg/textures/OVERRIDES.md  # sanity check
```

## 3. Player model & skeleton (3 days)

- [ ] Export player base mesh with humanoid skeleton (Hips→Spine→Head, Arms/Legs)
- [ ] Define attach point bones: `LeftHand`, `RightHand`, `Head`, `Back`, `Feet`
- [ ] Validate skeleton in isolated test scene (`scripts/run-dev.sh --model-test player`)
- [ ] Export animation states per spec §13: idle, walk, run, jump, fall, swim, attack, block, interact, emote
- [ ] Place assets in `game/arch_rpg/models/player/` and `game/arch_rpg/animations/player/`
- [ ] Create license records in `dependencies/licenses/game/arch_rpg/models/player/*.license.json`

```bash
scripts/run-dev.sh --model-test player
find game/arch_rpg/models/player -name '*.b3d' -o -name '*.gltf' | xargs -I{} scripts/verify-license-single.sh {}
```

## 4. Warrior armor & weapon attachments (3 days)

- [ ] Model Warrior armor set weighted to player skeleton (no extra bones)
- [ ] Define armor attach points: `Helmet`, `Chest`, `Legs`, `Boots`, `Gloves`, `Shoulders`
- [ ] Model 3 weapons (sword/axe/mace) with `WeaponRoot` bone
- [ ] Test attach/detach in test scene; verify sheathed/unsheathed visibility toggle
- [ ] Export weapon anims: swing_light, swing_heavy, sheathe, unsheathe
- [ ] License records for all armor/weapon assets

```bash
scripts/run-dev.sh --model-test warrior_armor
scripts/run-dev.sh --model-test warrior_weapons
```

## 5. Mob & boss models (4 days)

- [ ] Model 3 generic mobs with appropriate skeletons (quadruped/humanoid variants)
- [ ] Define mob attach points: `Mouth`, `LeftClaw`, `RightClaw`
- [ ] Export mob anims: idle, patrol, chase, attack, stagger, death
- [ ] Model boss with extended skeleton (+ tail/wings bones)
- [ ] Export boss anims: all player states + roar, special_1, special_2, phase_transition
- [ ] Validate boss-specific bones gracefully ignored by non-boss code
- [ ] License records for all mob/boss assets

```bash
scripts/run-dev.sh --model-test mob_01
scripts/run-dev.sh --model-test mob_02
scripts/run-dev.sh --model-test mob_03
scripts/run-dev.sh --model-test boss
```

## 6. UI cutover — HUD & hotbar (2 days)

- [ ] Implement `mods/arch_rpg_ui/hud.lua` subscribing to `player_stat_changed`, `target_changed`
- [ ] Implement `mods/arch_rpg_ui/hotbar.lua` subscribing to `hotbar_slot_changed`, `item_cooldown_tick`
- [ ] Remove debug stat overlay from default keybinds; gate behind `--dev-mode`
- [ ] Remove numbered debug hotbar; replace with styled hotbar
- [ ] Test live data binding in dev session

```bash
scripts/run-dev.sh --ui-test hud
scripts/run-dev.sh --ui-test hotbar
grep -r "debug.*stat.*overlay" mods/arch_rpg_ui/ && echo FAIL || echo OK
```

## 7. UI cutover — inventory & equipment (3 days)

- [ ] Implement inventory grid with drag-drop, sort, search, category tabs
- [ ] Subscribe to `inventory_updated`, `item_tooltip_request`
- [ ] Implement equipment paper-doll with stat delta preview
- [ ] Subscribe to `equipment_changed`, `stat_recalc`
- [ ] Remove raw list dump and text-only equip log from default build

```bash
scripts/run-dev.sh --ui-test inventory
scripts/run-dev.sh --ui-test equipment
```

## 8. UI cutover — stats, skills, tracker, journal (3 days)

- [ ] Stats screen: attribute values, derived stats, active buffs; subscribe to `stat_recalc`, `buff_list_changed`
- [ ] Skills screen: skill tree, tooltips, cooldown overlays; subscribe to `skill_unlocked`, `cooldown_tick`
- [ ] Quest tracker: active quests, objectives, waypoint markers; subscribe to `quest_progress`, `objective_completed`
- [ ] Journal: chronological entries, filters, bookmarks; subscribe to `journal_entry_added`, `lore_discovered`
- [ ] Remove `/stats` console command, debug skill dump, raw quest table, print-to-chat journal from default build

```bash
scripts/run-dev.sh --ui-test stats
scripts/run-dev.sh --ui-test skills
scripts/run-dev.sh --ui-test tracker
scripts/run-dev.sh --ui-test journal
```

## 9. UI cutover — dialogue, map, settings (3 days)

- [ ] Dialogue: NPC portrait, text box, choice buttons; subscribe to `dialogue_started`, `dialogue_choice_made`
- [ ] World map: full map, fog-of-war, markers, waypoints; subscribe to `map_discovered`, `waypoint_set`, `poi_revealed`
- [ ] Settings: video/audio/controls/keybinds/UI scale; local config only
- [ ] Remove chat-based dialogue test, coordinate spam, engine debug menu from default build
- [ ] Final dev-UI sweep: grep for known debug patterns

```bash
scripts/run-dev.sh --ui-test dialogue
scripts/run-dev.sh --ui-test map
scripts/run-dev.sh --ui-test settings
grep -rE '(F3|/inspect|wireframe|bbox_debug)' mods/arch_rpg_ui/ && echo FAIL || echo CLEAN
```

## 10. Map & waypoints integration (2 days)

- [ ] Generate/load world map tile data into `game/arch_rpg/maps/world.map`
- [ ] Wire player position marker with smooth interpolation
- [ ] Implement fog-of-war persistence in save format
- [ ] Wire quest/dungeon/NPC/landmark POI rendering from event subscriptions
- [ ] Implement player-set waypoints (max 5, color-coded, persistent)
- [ ] Verify fast travel disabled (no mechanic yet)

```bash
scripts/run-dev.sh --map-test
ls -lh game/arch_rpg/maps/world.map
```

## 11. Atmosphere stack evaluation & selection (2 days)

- [ ] Profile Climate API stack: FPS/memory/draw calls via `scripts/profile-perf.sh --atmosphere climate`
- [ ] Profile Regional Weather stack: same metrics via `scripts/profile-perf.sh --atmosphere regional`
- [ ] Evaluate art-direction fit with locked texture pack
- [ ] Verify licenses for ALL sub-mods in both stacks
- [ ] Pick ONE; write rationale to `mods/arch_rpg_atmosphere/STACK_DECISION.md`
- [ ] Remove unchosen stack from dependencies

```bash
scripts/profile-perf.sh --atmosphere climate
scripts/profile-perf.sh --atmosphere regional
# Manual decision + documentation
```

## 12. Weather & particles wiring (3 days)

- [ ] Wire rain/snow intensity to weather state; footprint decals client-side
- [ ] Configure distance + height fog from weather state
- [ ] Implement storm lightning (light entity spawn) + wind particle direction
- [ ] Rate-limit particles to 200 active max; GPU instancing if available
- [ ] Wire cloud LOD, wind foliage sway uniform, waterfall emitters + sound triggers
- [ ] Moon phase texture swap on moon entity
- [ ] All logging prefixed `[ARCH-RPG:ATMOSPHERE]`

```bash
scripts/run-dev.sh --weather-test
grep -c '\[ARCH-RPG:ATMOSPHERE\]' /tmp/archlast-dev.log  # sanity: logs present
```

## 13. Audio event wiring (3 days)

- [ ] Implement `mods/arch_rpg_audio/init.lua` event dispatcher
- [ ] Subscribe to ALL events in README.md §Audio Map table
- [ ] Load/place all audio assets in `game/arch_rpg/sounds/` and `game/arch_rpg/music/`
- [ ] Create license records for every audio file in `dependencies/licenses/`
- [ ] Test each trigger category in dev session; log missing assets as warnings
- [ ] All logging prefixed `[ARCH-RPG:AUDIO]`

```bash
scripts/run-dev.sh --audio-test
find game/arch_rpg/sounds game/arch_rpg/music -type f | wc -l
scripts/verify-licenses.sh  # must pass
```

## 14. Performance profiling & regression fixes (3 days)

- [ ] Capture Phase 7 baseline: `scripts/profile-perf.sh --baseline`
- [ ] Capture Phase 8 current: `scripts/profile-perf.sh --current`
- [ ] Compare FPS, frame-p95, server tick ms; identify regressions >10%
- [ ] Fix top 3 regressions (particle cap, shadow cascade, light culling, water LOD)
- [ ] Re-profile until ≤10% regression on all three metrics
- [ ] Document final perf numbers in `docs/plans/phase-08-presentation/PERF_RESULTS.md`

```bash
scripts/profile-perf.sh --baseline
scripts/profile-perf.sh --current
scripts/profile-perf.sh --compare  # outputs regression report
# Iterate fixes until green
```

## 15. License audit & final verification (1 day)

- [ ] Run `scripts/verify-licenses.sh`; must exit 0
- [ ] Spot-check 10 random assets for correct license JSON schema
- [ ] Verify no unlicensed assets in `game/arch_rpg/` tree
- [ ] Commit all license records
- [ ] Tag phase-complete commit

```bash
scripts/verify-licenses.sh
find game/arch_rpg -type f \( -name '*.png' -o -name '*.b3d' -o -name '*.ogg' \) | shuf -n 10 | xargs -I{} cat dependencies/licenses/{}.license.json
git add dependencies/licenses/
git commit -m "chore(phase8): complete license audit"
```

## Out of scope (defer, do not start)

- Minimap implementation.
- Party/trade UI.
- New gameplay mechanics or systems.
- Engine renderer rewrite without profile evidence.
- Windows/macOS packaging.
- Narrative content expansion beyond UI validation placeholders.