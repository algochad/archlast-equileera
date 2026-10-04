# Phase 2 — Engine RPG Foundations

Depends on: Phase 1 green.

## Goal

Plan (no code) the `game/arch_base/` mechanics core — severed-history merge of Mineclonia (base) + VoxeLibre (donor) + shader preset as first-class mod — then deliver third-person camera + character controller + animation API usable from Lua. No RPG stats/combat yet.

## Scope

- Base-game execution: fork sources table (Mineclonia `main`@`85029767` base / VoxeLibre `master`@`2373982f` donor / shader `master`@`cf0cf619`), merge direction, `game/arch_base/` layout, `LUANTI_GAME_PATH` discovery, provenance format, donor-evaluation + smoke procedure (TASKS.md Group 0, executed in this phase)
- `engine-patches/{camera,animation,input,gameplay-api}/` design notes
- C++ in `engine/archlast-luanti/`: `arch_engine.camera.*`, `arch_engine.animation.*`, `arch_engine.input.*`, `arch_engine.player.*` (minimal bindings per spec §10)
- Branches: `feature/camera`, `feature/animation`, `feature/input`, `feature/rpg-api` — one concern per branch, squash-merge to `main`
- Camera: distance, collision, shoulder offset, smoothing, yaw/pitch, combat/target-lock hook

## Non-goals

No stats/classes/skills (Phase 4). No rendering overhaul. No asset finalization. No `upstream` remotes on game content ever.

## Tasks

0. Base-game plan first: record fork SHAs + merge rules + layout + `LUANTI_GAME_PATH` wiring + provenance + smoke procedure (see TASKS.md Group 0). No cloning, no `game/arch_base/` code.
1. Probe: can Lua `set_camera_mode` + existing API cover 80%? Document gaps in `engine-patches/camera/README.md`.
2. Implement camera collision + shoulder offset behind smallest API surface.
3. Expose animation state API; wire idle/walk/jump states.
4. Input abstraction: `is_action_pressed`, `get_axis` for gamepad-ready mapping.
5. `scripts/build-linux.sh` + `run-dev.sh --smoke --third-person` still green.

## Acceptance

- [ ] Base-game plan decision-complete: Group 0 names exact SHAs, merge base/donor, `game/arch_base/` layout, `LUANTI_GAME_PATH` lever, provenance format, A0 smoke procedure — implementable with zero open choices
- [ ] Third-person follow cam with collision (no terrain clip in smoke world)
- [ ] `arch_engine.camera.set_distance/set_shoulder_offset` callable from Lua console
- [ ] Animation state transitions idle→walk→jump observable in-game
- [ ] Engine tests + game smoke pass; perf: no >10% frame regression vs Phase 1 baseline
