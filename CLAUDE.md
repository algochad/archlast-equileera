# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Archlast is a Luanti (Minetest) fork building a survival sandbox RPG. The engine is a C++ fork of Luanti 5.17.0 with custom `arch_engine.*` Lua APIs. Game content lives in `game/arch_base/`, a severed-history merge of Mineclonia (base) + VoxeLibre (donor) + shader preset as first-class mod.

## Build & Run Commands

```bash
scripts/bootstrap.sh          # Install system deps (pacman/dnf/apt auto-detect)
scripts/build-linux.sh        # Configure + build engine → bin/archlast
bin/archlast --version         # Verify fork identity
scripts/run-dev.sh             # Launch interactive GUI client
scripts/run-dev.sh --smoke     # Headless server smoke test (temp world, 10s run, log check)
scripts/run-dev.sh --dev       # Interactive GUI with gameid flag support
scripts/run-dev.sh --bench     # Smoke test + frame_time_ms benchmark output
```

Build outputs to `build/linux/`. The `bin/archlast` wrapper delegates to `engine/archlast-luanti/bin/luanti`. Non-devtest games require `LUANTI_GAME_PATH` (set automatically by `run-dev.sh` for non-devtest gameids).

No lint or unit test runner exists at the repo level. Engine tests are upstream Luanti's; game-level validation is the smoke test (`--smoke` checks log for `error|segfault|moderror|assertion`).

## Architecture

### Repository Layout

- `engine/archlast-luanti/` — Git submodule: Luanti C++ fork. Custom code lives in `src/archlast/` (camera, animation, input, player controller, Lua bindings). Pinned at commit in `dependencies/mods.lock`.
- `game/arch_base/` — Severed-history merged game. Mineclonia is the base; VoxeLibre mods were selectively adopted (18 kept, 10 removed for API divergence). See `game/arch_base/MERGE_NOTES.md` for full provenance.
- `game/arch_rpg/` — Future RPG layer (Phase 4+), currently holds `config/` only.
- `engine-patches/{camera,animation,input,gameplay-api}/` — Design docs and probe results for each `arch_engine.*` subsystem. Read these before implementing or modifying engine C++ code.
- `docs/plans/phase-*/` — Phase plans, task lists, acceptance criteria. Each phase has README.md, PLAN.md, TASKS.md, ACCEPTANCE.md.
- `dependencies/mods.lock` — Pins engine commit and all content sources (Mineclonia, VoxeLibre, shader preset) with SHA hashes.
- `scripts/` — Build automation. No Makefile; CMake configured by `build-linux.sh`.

### Engine Fork Conventions

All Archlast C++ additions go under `engine/archlast-luanti/src/archlast/`. This isolates custom code from upstream Luanti sources and minimizes merge conflicts on engine updates. Current files:

- `camera_manager.{h,cpp}` — Third-person camera (distance, collision, shoulder offset, smoothing, yaw/pitch, combat/target-lock hook)
- `animation_state_machine.{h,cpp}` — Animation state machine for entity/player animations
- `input_action_map.{h,cpp}` — Action-based input abstraction over IrrlichtMt (no SDL2 dependency). Wraps keyboard + gamepad into named actions/axes with edge detection and per-axis deadzone.
- `character_controller.{h,cpp}` — Player state machine (WALK/RUN/SPRINT/JUMP/FALL/SWIM/DODGE/KNOCKBACK). Composes into `PlayerSAO::step()`, does not inherit from UnitSAO.
- `modapi_archlast.{h,cpp}`, `modapi_archlast_client.cpp` — Registration entry points for `arch_engine.*` Lua APIs (server and client respectively)
- `lua_bindings_{camera,animation,input,player,entity,render}.cpp` — Register `arch_engine.*` namespaces in both client and server Lua environments.
- `CMakeLists.txt` — Build config for all archlast sources

Lua API surface: `arch_engine.camera.*`, `arch_engine.animation.*`, `arch_engine.input.*`, `arch_engine.player.*`, `arch_engine.entity.*`, `arch_engine.render.*`. Server-side calls return defaults/nil for hardware-only queries.

### Game Content Conventions

`game/arch_base/` follows Mineclonia mod organization (CORE, ITEMS, MAPGEN, PLAYER, ENTITIES, ENVIRONMENT, HUD, HELP, MISC, COMPAT). Mod load order is controlled by `game.conf` (`first_mod = mcl_init`, `last_mod = _mcl_autogroup`). When adding mods, place them in the appropriate category directory and add dependencies in `mod.conf`.

VoxeLibre donor mods that survived the merge are listed in `MERGE_NOTES.md` with their init SHAs. Removed mods failed due to Mineclonia API divergence — check that file before re-attempting any VL mod port.

The `arch_shader_preset` mod is a first-class game mod (not an engine patch). It ships in `game/arch_base/mods/arch_shader_preset/`.

### Submodule Management

Engine submodule remote configuration:
- `origin` → `https://github.com/algochad/archlast-luanti.git` (our fork)
- `upstream` → `https://github.com/luanti-org/luanti.git` (original Luanti)

When updating the engine pin, update the commit hash in `dependencies/mods.lock` and run `git -C engine/archlast-luanti fetch upstream && git -C engine/archlast-luanti checkout <sha>`.

## Commit Message Convention

Format: `type(scope): description` matching recent history (e.g., `feat(phase-02):`, `fix(game):`, `docs(plans):`, `chore(phase-02):`). End every commit with:

```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

End PR descriptions with: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

## Phased Development

Work is organized into numbered phases under `docs/plans/`. Each phase has acceptance criteria in `ACCEPTANCE.md` that must pass before moving to the next. Current phase: Phase 2 (Engine RPG Foundations). Check the relevant phase's TASKS.md for granular work items and PLAN.md for architectural decisions.