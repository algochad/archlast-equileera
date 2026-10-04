# Phase 2 — Engine RPG Foundations

Depends on: Phase 1 green.

## Goal

Third-person camera + character controller + animation API usable from Lua. No RPG stats/combat yet.

## Scope

- `engine-patches/{camera,animation,input,gameplay-api}/` design notes
- C++ in `engine/archlast-luanti/`: `arch_engine.camera.*`, `arch_engine.animation.*`, `arch_engine.input.*`, `arch_engine.player.*` (minimal bindings per spec §10)
- Branches: `feature/camera`, `feature/animation`, `feature/input`, `feature/rpg-api` — one concern per branch, squash-merge to `main`
- Camera: distance, collision, shoulder offset, smoothing, yaw/pitch, combat/target-lock hook

## Non-goals

No stats/classes/skills (Phase 4). No rendering overhaul. No asset finalization.

## Tasks

1. Probe: can Lua `set_camera_mode` + existing API cover 80%? Document gaps in `engine-patches/camera/README.md`.
2. Implement camera collision + shoulder offset behind smallest API surface.
3. Expose animation state API; wire idle/walk/jump states.
4. Input abstraction: `is_action_pressed`, `get_axis` for gamepad-ready mapping.
5. `scripts/build-linux.sh` + `run-dev.sh --smoke --third-person` still green.

## Acceptance

- [ ] Third-person follow cam with collision (no terrain clip in smoke world)
- [ ] `arch_engine.camera.set_distance/set_shoulder_offset` callable from Lua console
- [ ] Animation state transitions idle→walk→jump observable in-game
- [ ] Engine tests + game smoke pass; perf: no >10% frame regression vs Phase 1 baseline
