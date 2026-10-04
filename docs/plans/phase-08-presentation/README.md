# Phase 8 — Presentation (Stylized-Realistic Pass)

Depends on: Phase 7 (MVP) green. Do NOT start before MVP acceptance passes.

## Goal

Deliver a cohesive stylized-realistic presentation pass over the existing MVP without introducing new gameplay mechanics, systems, or engine render rewrites. Outcome: shipping-quality textures, models, animations, UI, map, weather, audio, and lighting that read as one art direction, with all assets license-cleared and performance within 10% of Phase 7 baseline.

## Non-goals

- New combat, quest, class, skill, item, or progression mechanics.
- Engine renderer rewrite or new shader pipelines without profile evidence.
- Multiplayer party/trade UI (deferred to post-launch).
- Minimap (deferred; world map only in this phase).
- Custom model formats or proprietary toolchains.
- Windows/macOS packaging or installer work.
- Narrative content expansion beyond placeholder journal/dialogue text needed for UI validation.

## Exit criteria (must all pass)

1. No dev/debug UI visible in default `scripts/run-dev.sh` launch.
2. `scripts/verify-licenses.sh` exits 0 with zero unverified assets.
3. 60s roam + 30s combat perf log shows ≤10% regression vs Phase 7 baseline on FPS, frame-p95, and server tick ms.
4. Every UI screen in §UI Screen Inventory renders correctly with live data bindings.
5. All audio triggers in §Audio Map fire via events, not direct calls.
6. Texture pack locked and overrides documented in `game/arch_rpg/textures/OVERRIDES.md`.
7. Atmosphere stack decided (ONE) and wired through Climate API or Regional Weather exclusively.
8. Screenshot procedure in ACCEPTANCE.md produces reference images for all screens.

## Layout after this phase

```text
game/arch_rpg/textures/           # project-owned overrides + OVERRIDES.md
game/arch_rpg/models/             # player, warrior armor/weapons, mobs, boss
game/arch_rpg/animations/         # anim states per spec §13
game/arch_rpg/sounds/             # categorized audio assets
game/arch_rpg/music/              # ambient + battle tracks
dependencies/licenses/            # per-asset license records + verify-licenses.sh
dependencies/mods.lock            # updated with texture/model/audio pack pins
mods/arch_rpg_ui/                 # full UI mod (event-driven)
mods/arch_rpg_atmosphere/         # weather/particles/footprints wrapper
mods/arch_rpg_audio/              # event-driven audio dispatcher
scripts/profile-perf.sh           # before/after perf capture
scripts/verify-licenses.sh        # license completeness check
docs/plans/phase-08-presentation/ # this plan
```

## Texture Evaluation Matrix

Evaluate IN THIS ORDER. Stop at first pack that satisfies look + perf + license. Record decision in `game/arch_rpg/textures/OVERRIDES.md`.

| Rank | Pack             | Look (stylized-realistic fit) | Perf (VRAM / draw calls) | License (code + art)        | Size (disk) | Notes                                      |
|------|------------------|-------------------------------|--------------------------|-----------------------------|-------------|--------------------------------------------|
| 1    | HDX128           | High detail, PBR-ready        | Heavy (4–6 GB VRAM)      | CC-BY-SA 4.0 + MIT code     | ~2.8 GB     | Best look; may fail low-end perf gate      |
| 2    | HDX64            | Balanced detail               | Moderate (2–3 GB VRAM)   | CC-BY-SA 4.0 + MIT code     | ~1.4 GB     | Likely sweet spot                          |
| 3    | PixelPerfection  | Clean pixel-art realism       | Light (<1.5 GB VRAM)     | CC-BY-SA 3.0 + LGPL code    | ~600 MB     | Fallback if HDX64 fails perf               |
| 4    | Soothing32       | Soft low-res stylized         | Minimal (<800 MB VRAM)   | CC0 + MIT                   | ~250 MB     | Last resort; may clash with realistic goal |

### Override strategy

- Base pack lives in `dependencies/mods.lock` as pinned submodule/archive.
- Project overrides go in `game/arch_rpg/textures/<category>/<name>.png`.
- Override naming mirrors base pack path exactly; engine load order guarantees override wins.
- Every override MUST have corresponding entry in `game/arch_rpg/textures/OVERRIDES.md` listing: base file replaced, reason, author, license.
- Overrides MUST NOT exceed 15% of total texture count; if exceeded, reconsider base pack choice.

## Model & Attachment Plan

### Scope

| Asset              | Count | Skeleton/Bones                     | Attach Points                  | Anim States (spec §13)                          |
|--------------------|-------|------------------------------------|--------------------------------|-------------------------------------------------|
| Player base        | 1     | Humanoid (Hips→Spine→Head, Arms/Legs) | `LeftHand`, `RightHand`, `Head`, `Back`, `Feet` | idle, walk, run, jump, fall, swim, attack, block, interact, emote |
| Warrior armor set  | 1     | Same skeleton, weighted mesh       | `Helmet`, `Chest`, `Legs`, `Boots`, `Gloves`, `Shoulders` | Inherits player states; no extra anims          |
| Warrior weapons    | 3     | Sword/Axe/Mace (bone: `WeaponRoot`) | `RightHand` (primary), `Back` (sheathed) | swing_light, swing_heavy, sheathe, unsheathe    |
| Mob (generic)      | 3     | Quadruped/Humanoid variants        | `Mouth`, `LeftClaw`, `RightClaw` | idle, patrol, chase, attack, stagger, death     |
| Boss               | 1     | Extended humanoid + tail/wings     | All player points + `Tail`, `WingL`, `WingR` | All player states + roar, special_1, special_2, phase_transition |

### Attachment rules

- All attach points defined as bones in `.b3d`/`.gltf` export; NEVER hardcoded offsets.
- Armor meshes use same skeleton as player base; weight painting only.
- Weapon attach uses `RightHand` bone transform; sheathed uses `Back` with visibility toggle.
- Boss-specific bones ignored by non-boss code; graceful fallback if missing.
- Animation state machine lives in Lua (`mods/arch_rpg_anim/init.lua`); C++ only exposes bone query API.

## UI Screen Inventory

All UI is event-driven: gameplay modules emit events (`arch_rpg:player_stat_changed`, `arch_rpg:inventory_updated`, etc.); UI mod subscribes. Gameplay NEVER calls UI directly.

### Core screens (Phase 8 scope)

| Screen       | Data Sources (events)                            | Key Elements                                    | Dev-UI Replaced? |
|--------------|--------------------------------------------------|-------------------------------------------------|------------------|
| HUD          | `player_stat_changed`, `target_changed`          | Health/stamina/mana bars, XP ring, level badge, class icon, target frame | Yes: debug stat overlay |
| Hotbar       | `hotbar_slot_changed`, `item_cooldown_tick`      | 10 slots, keybind labels, cooldown sweep        | Yes: numbered debug bar |
| Inventory    | `inventory_updated`, `item_tooltip_request`      | Grid, drag-drop, sort, search, category tabs    | Yes: raw list dump |
| Equipment    | `equipment_changed`, `stat_recalc`               | Paper-doll slots, stat delta preview            | Yes: text-only equip log |
| Stats        | `stat_recalc`, `buff_list_changed`               | Attribute values, derived stats, active buffs   | Yes: console `/stats` |
| Skills       | `skill_unlocked`, `cooldown_tick`                | Skill tree, tooltips, cooldown overlays         | Yes: debug skill dump |
| Quest Tracker| `quest_progress`, `objective_completed`          | Active quests, objectives, waypoint markers     | Yes: raw quest table |
| Journal      | `journal_entry_added`, `lore_discovered`         | Chronological entries, filters, bookmarks       | Yes: print-to-chat |
| Dialogue     | `dialogue_started`, `dialogue_choice_made`       | NPC portrait, text box, choice buttons          | Yes: chat-based test |
| World Map    | `map_discovered`, `waypoint_set`, `poi_revealed` | Full map, fog-of-war, markers, waypoints        | Yes: coordinate spam |
| Settings     | N/A (local config)                               | Video/audio/controls/keybinds/UI scale          | Yes: engine debug menu |

### Deferred screens (post-Phase 8)

- Minimap (requires streaming tile cache).
- Party UI (requires multiplayer session layer).
- Trade UI (requires secure transaction protocol).

### Dev-UI removal list

Remove or hide behind `--dev-mode` flag:
- Debug stat overlay (`F3` panel).
- Raw entity inspector (`/inspect`).
- Chat-command-only quest/item dumps.
- Unstyled Lua console output for gameplay data.
- Wireframe/bbox debug toggles in default keybinds.

## Map & Exploration

- World map: pre-rendered or procedural tile map loaded from `game/arch_rpg/maps/world.map`.
- Player position: real-time marker, smooth interpolation.
- Discovered areas: fog-of-war lifted on visit; persisted in save.
- Quest markers: from active quest objectives; auto-update on progress.
- Dungeon entrances: POI type `dungeon`; icon + tooltip.
- NPC locations: POI type `npc`; shown only after meeting/discovery.
- Landmarks: POI type `landmark`; always visible once discovered.
- Waypoints: player-set; max 5; persist across sessions; color-coded.
- Fast travel: disabled in Phase 8 (mechanic deferral); map is navigation aid only.

## Atmosphere Stack Decision

**MANDATORY: Choose ONE stack. Do NOT combine.**

| Option                | Components Integrated                          | Pros                              | Cons                              | Decision Criteria              |
|-----------------------|------------------------------------------------|-----------------------------------|-----------------------------------|--------------------------------|
| Climate API           | Rain/snow/fog/storm/clouds/wind/lighting       | Unified API, single source of truth | Less granular control             | If unified control suffices    |
| Regional Weather      | Per-biome weather + Footprints + More Particles + Waterfalls + Moon Phases | Richer detail, modular            | Multiple mods to maintain         | If biome-specific FX required  |

### Selection process

1. Profile both stacks on MVP build (FPS, memory, draw calls).
2. Evaluate art-direction fit with texture pack chosen above.
3. Check license compatibility for ALL sub-mods in each stack.
4. Pick ONE; document rationale in `mods/arch_rpg_atmosphere/STACK_DECISION.md`.
5. Wire exclusively through chosen stack's API; no hybrid calls.

### Atmosphere components (whichever stack wins)

- Rain/snow: intensity tied to weather state; footprint decals spawned client-side.
- Fog: distance + height fog; density from weather state.
- Storm: lightning flashes (light entity spawn), wind particle direction.
- Particles: dust, pollen, ember; rate-limited to 200 active max.
- Clouds: volumetric or billboard; LOD by distance.
- Wind: affects particles + foliage sway (shader uniform).
- Lighting: sun/moon angle from time-of-day; color temp from weather.
- Waterfalls: particle emitter + sound trigger; only in designated nodes.
- Moon phases: texture swap on moon entity; affects night light level.

## Audio Map

All audio triggered via events. Audio mod subscribes; gameplay emits.

| Category   | Triggers (events)                                | Assets Needed | License Check |
|------------|--------------------------------------------------|---------------|---------------|
| Footstep   | `player_step`, `mob_step`                        | 4 surfaces × 3 speeds = 12 clips | ✅ Required |
| Weapon     | `weapon_swing`, `weapon_hit`, `weapon_block`     | 3 weapons × 3 actions = 9 clips  | ✅ Required |
| Combat     | `damage_taken`, `damage_dealt`, `critical_hit`   | 6 clips       | ✅ Required |
| Magic      | `spell_cast`, `spell_impact`, `buff_applied`     | 8 clips       | ✅ Required |
| Enemy      | `enemy_alert`, `enemy_attack`, `enemy_death`     | 3 mobs × 3 = 9 clips | ✅ Required |
| NPC        | `npc_greet`, `npc_farewell`, `npc_quest_offer`   | 6 clips       | ✅ Required |
| Water      | `water_enter`, `water_exit`, `water_splash`      | 3 clips       | ✅ Required |
| Wind       | `weather_wind_start`, `weather_wind_stop`        | Loop + fade   | ✅ Required |
| Rain       | `weather_rain_start`, `weather_rain_intensity`   | Loop + layers | ✅ Required |
| UI         | `ui_open`, `ui_close`, `ui_click`, `ui_error`    | 4 clips       | ✅ Required |
| Quest      | `quest_accepted`, `quest_completed`, `objective_updated` | 3 clips | ✅ Required |
| Levelup    | `player_level_up`                                | Fanfare clip  | ✅ Required |
| Loot       | `item_pickup`, `item_drop`, `chest_open`         | 3 clips       | ✅ Required |
| Boss       | `boss_spawn`, `boss_phase_change`, `boss_death`  | 3 clips       | ✅ Required |
| Ambient    | Time-of-day + biome                              | 6 loops       | ✅ Required |
| Music      | `zone_entered`, `combat_started`, `combat_ended` | 4 tracks      | ✅ Required |

### License verification workflow

1. Every asset added → create `dependencies/licenses/<asset_path>.license.json`.
2. Schema: `{ "file": "...", "author": "...", "license": "...", "source_url": "...", "verified_by": "...", "verified_date": "YYYY-MM-DD" }`.
3. `scripts/verify-licenses.sh` scans all asset dirs, compares against license DB, fails on missing/expired.
4. CI runs `verify-licenses.sh` on every PR touching assets.
5. No asset ships without verified license record.

## Lighting, Shadow, Fog & Water Performance Notes

- Shadows: cascaded shadow maps, 2 cascades max; disable on distant objects >64 nodes.
- Fog: exponential²; computed in fragment shader, no extra pass.
- Water: planar reflection only for player-near water tiles (>32 nodes: simple refraction tint).
- Light entities: max 8 dynamic lights visible; others culled by distance/importance.
- Particle cap: 200 active system-wide; weather particles use GPU instancing if available.
- Profile targets: FPS ≥55 @ 1080p mid-settings; frame-p95 ≤25ms; server tick ≤45ms.
- Regression budget: ≤10% vs Phase 7 baseline on all three metrics.

## Risks

| Risk                              | Likelihood | Impact | Mitigation                                              |
|-----------------------------------|------------|--------|---------------------------------------------------------|
| Texture pack license incompatible | Medium     | High   | Evaluate license BEFORE locking; have fallback pack ready |
| Atmosphere stack perf regression  | High       | Medium | Profile both stacks early; pick lighter if within 5%    |
| Model rigging breaks animations   | Medium     | High   | Validate attach points in isolated test scene before integration |
| Audio event misses trigger        | Medium     | Low    | Comprehensive trigger checklist + automated log scan    |
| Dev-UI remnants leak to release   | Low        | High   | Grep-based CI check + manual QA pass                    |
| License audit incomplete          | Medium     | Critical | Block ship until `verify-licenses.sh` green             |
| Perf regression exceeds budget    | High       | High   | Weekly perf snapshots; fix regressions before new assets |

## Logging prefixes

- `[ARCH-RPG:UI]` — UI mod events, screen loads, data binding errors.
- `[ARCH-RPG:AUDIO]` — Audio trigger fires, missing assets, license warnings.
- `[ARCH-RPG:ATMOSPHERE]` — Weather state changes, particle counts, stack decisions.
- `[ARCH-RPG:PRESENTATION]` — Texture/model load, override application, perf samples.
- `[ARCH-ENGINE:RENDER]` — Only if engine-level render change approved (rare).

## Module dependency direction

core → player/stats → classes/skills → combat → items/equipment → quests/dialogue/NPCs → mobs/loot/dungeons → UI/atmosphere/audio/presentation.

Gameplay modules NEVER import UI/atmosphere/audio modules. Communication via events only.