# Phase 8 — Presentation

Depends on: MVP (Phase 7) green. Do NOT start before MVP.

## Goal

Stylized-realistic pass: cohesive textures/models/animations/UI/audio/map.

## Scope

- `mods/arch_rpg_ui` full: health/stamina/mana/XP/level/target/hotbar/equipment/stats/quest tracker/journal/dialogue/map/settings
- Texture lock: evaluate HDX128 → HDX64 → PixelPerfection → Soothing32 IN ORDER, pick one base, record license; project-owned overrides in `game/arch_rpg/textures/`
- Models/animations: player + Warrior armor/weapon attachments + 3 mobs + boss; animation states per spec §13
- Atmosphere: rain/fog/particles/footprints/waterfalls via Climate API / Regional Weather eval (one stack)
- Audio: footsteps/combat/UI/level-up/boss/ambient; all licenses verified in `dependencies/licenses/`

## Non-goals

New systems/mechanics. No engine render rewrite without profile data.

## Tasks

1. Texture candidate matrix (look/perf/license) → lock one.
2. UI cutover: replace debug/dev UI; game-feel pass on camera-relative movement.
3. Audio + particle + weather wiring via events (combat/level-up/quest), not direct calls.
4. Perf gate: chunk/entity/particle profile before/after; fix regressions.

## Acceptance

- [ ] No dev/debug UI visible in default build
- [ ] All shipped assets have verified licenses recorded
- [ ] 60s roam + combat perf log shows no Phase-7 regression >10%
