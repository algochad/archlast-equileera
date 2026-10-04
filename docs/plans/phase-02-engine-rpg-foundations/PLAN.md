# Phase 2 — Engine RPG Foundations (Lua-mod approach, no engine C++ changes)

Depends on: Phase 1 green.

## Goal

Plan (no code) the `game/arch_base/` mechanics core — severed-history merge of Mineclonia (base) + VoxeLibre (donor) + shader preset as first-class mod — then deliver third-person camera + character controller + animation API **as Lua game mods** using only the stock Luanti Lua API. No engine C++ changes. The engine submodule stays pinned at upstream `c0e6812b1` (5.17.0); all Phase 2 C++ work previously landed in `src/archlast/` has been reverted.

## Scope

- Base-game execution: fork sources table (Mineclonia `main`@`85029767` base / VoxeLibre `master`@`2373982f` donor / shader `master`@`cf0cf619`), merge direction, `game/arch_base/` layout, `LUANTI_GAME_PATH` discovery, provenance format, donor-evaluation + smoke procedure (TASKS.md Group 0, executed in this phase)
- New Lua game mod(s) under `game/arch_base/mods/` (name TBD, e.g. `arch_rpg_core` or `arch_engine_lua`) implementing:
  - Camera: `set_eye_offset` third-person offsets, `set_camera({mode=...})` lock, `core.raycast`/`core.line_of_sight` collision pull-in, `hud_add` debug readout
  - Animation: `set_animation`/`play_animation` state machine in Lua driven by `core.register_globalstep` + `get_player_control`, bone posing via `set_bone_override`, crossfade via `frame_blend`
  - Input: action/axis abstraction over `get_player_control` (+ `movement_x`/`movement_y` for joystick axes), JSON profiles via mod storage / world files
  - Player: locomotion states via `get_velocity` + `get_physics_override`/`set_physics_override`, knockback via `add_velocity`, swim/ground detection from node queries
  - Entity/render debug: thin wrappers over existing `ServerEnvironment` queries + `hud_add` state labels, `core.get_us_time` frame timing
- Design notes live in `engine-patches/{camera,animation,input,gameplay-api}/README.md` (probe results + Lua mapping + limits). "engine-patches" is now a historical directory name — no C++ is patched.
- `scripts/build-linux.sh` + `run-dev.sh --smoke --third-person` still green (engine builds stock upstream).

## Non-goals

No stats/classes/skills (Phase 4). No rendering overhaul. No asset finalization. No `upstream` remotes on game content ever. **No engine C++ changes of any kind** — if a requirement cannot be met with the Lua API in `docs/archlast-luanti-moding-docs/modding-docs.md`, record it as a deferred gap instead of patching the engine.

## Tasks

0. Base-game plan first: record fork SHAs + merge rules + layout + `LUANTI_GAME_PATH` wiring + provenance + smoke procedure (see TASKS.md Group 0). No cloning, no `game/arch_base/` code.
1. Probe: map each requirement to stock Lua API (`set_eye_offset`, `set_camera`, `core.raycast`, `set_bone_override`, `set_animation`/`play_animation`, `get_player_control`, `set_physics_override`, `hud_add`). Document exact function names + doc line refs in `engine-patches/*/README.md`.
2. Implement camera collision + shoulder offset **in Lua** (raycast pull-in behind smallest `arch_*` Lua API surface).
3. Expose animation state API **in Lua**; wire idle/walk/jump states via `set_animation` frame ranges + `frame_blend`.
4. Input abstraction **in Lua**: `is_action_pressed`, `get_axis` over `get_player_control` (+ `movement_x`/`movement_y` for sticks).
5. `scripts/build-linux.sh` + `run-dev.sh --smoke --third-person` still green.

## Acceptance

- [ ] Base-game plan decision-complete: Group 0 names exact SHAs, merge base/donor, `game/arch_base/` layout, `LUANTI_GAME_PATH` lever, provenance format, A0 smoke procedure — implementable with zero open choices
- [ ] Third-person follow cam with collision (no terrain clip in smoke world) implemented **in Lua, stock engine**
- [ ] `arch_*` Lua camera API (`set_distance`/`set_shoulder_offset` equivalent) callable from Lua console
- [ ] Animation state transitions idle→walk→jump observable in-game
- [ ] Engine builds stock upstream + game smoke pass; perf: no >10% frame regression vs Phase 1 baseline
- [ ] Engine submodule pointer == `dependencies/mods.lock` pin `c0e6812b1`; `git -C engine/archlast-luanti status` clean; no `src/archlast/` directory exists
