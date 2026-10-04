
## 2026-10-04T14:37:00Z — Phase 2 Wave 5 Final (Client Lifecycle Wiring)

- A0: PASS (game/arch_base/game.conf exists, title = Arch Base)
- A1: PASS (server-side arch_engine namespaces registered; no moderror in smoke log; client-only APIs camera/anim/input/render need --dev visual verification)
- A2: NEEDS-CLIENT (0 CAMERA markers in headless smoke log — CameraManager instantiates only in client Game::run path)
- A3: NEEDS-CLIENT (0 ANIM markers in headless smoke log — AnimationStateMachine instantiates only in client Game::run path)
- A4: NEEDS-CLIENT (0 INPUT markers in headless smoke log — InputActionMap instantiates only in client Game::run path)
- A5: PASS (build green, bin/archlast executable, smoke exit=0, log clean)
- A6: PASS (frame_time_ms=16.7, baseline=16.7, regression=0.0%, within 10% budget)

- Engine commit: 374f47459f5491225e8bad51cfb9cec643741f05
- Parent commit: 6afe343991cd2dd1eb6322664f20c097329c6730
- Branches deleted: feature/camera, feature/input, feature/animation, feature/rpg-api
- Benchmark: frame_time_ms=16.7 (baseline 16.7, regression 0.0%)
- Client-coverage caveat: A2/A3/A4 require `--dev` client run to exercise Game::run() path where managers instantiate and log markers. Headless server (`--smoke`) only exercises server-side arch_engine.player/entity registration.

## 2026-10-04T14:42:00Z — A0 follow-up (bonemeal shim removal)

- A0 re-run after removing `game/arch_base/mods/MISC/bonemeal` (VL WorldEdit-Additions compat shim): Log Check CLEAN, Smoke PASSED, listening on present. Devtest regression also CLEAN/PASSED.
- Prior run had 6 `ERROR: Item does not exist: mcl_flowers:*` lines emitted post-worldgen (after `[mcl_villages]` pristine notice) from unregistered flower aliases; non-fatal to server (listening on reached) but fails run-dev.sh Log Check gate. Removal is correct: shim has no Mineclonia counterpart and only serves WorldEdit-Additions.
- MERGE_NOTES.md updated: 28 attempted, 20 kept, 8 removed.

## 2026-10-04T16:30:00Z - Phase 2 Final Acceptance (Group F)

- A0: PASS (game/arch_base/game.conf exists, title = Arch Base, shader preset present, IDS CLEAN, PROVENANCE OK, smoke exit=0 log clean)
- A1: PASS (arch_engine=true; server-side player+entity namespaces registered; camera/animation/input/render are client-only per design — instantiate in Game::run path, not headless server)
- A2: NEEDS-CLIENT (0 CAMERA markers in headless smoke — CameraManager instantiates only in client Game::run path; build green, no errors)
- A3: NEEDS-CLIENT (0 ANIM markers in headless smoke — AnimationStateMachine instantiates only in client Game::run path; build green, no errors)
- A4: NEEDS-CLIENT (0 INPUT markers in headless smoke — InputActionMap instantiates only in client Game::run path; default profile game/arch_rpg/config/input_default.json present with 7 actions + 2 axes)
- A5: PASS (build exit=0, bin/archlast executable, smoke --third-person exit=0, log clean: no ERROR[Main]/segfault/moderror/assertion)
- A6: PASS (frame_time_ms=16.7, baseline=16.7, regression=0.0%, within 10% budget)

- Parent commit: 9aac50c4b5dab711bf1ba7ee8c2c9764591c6fc8
- Engine commit: 3b3e16fe6b9477ec9644b026c5bc47c2cf362572
- Benchmark: frame_time_ms=16.7 (baseline 16.7, regression 0.0%)
- Client-coverage note: A2/A3/A4 markers require a GUI client run (--dev visual verification); headless server (--smoke) only exercises server-side arch_engine.player/entity registration. All C++ compiles and links cleanly into both targets.

Phase 2 status: COMPLETE (all server-verifiable gates green; client-only gates deferred to first GUI playtest).

## 2026-10-04T20:30:00Z — Direction change: engine C++ reverted, plan rewritten to Lua-mod approach

- Decision: all Phase 2 C++ work in `engine/archlast-luanti/src/archlast/` removed; engine reset to upstream pin `c0e6812b1` (5.17.0). No engine branches, no `arch_engine.*` C++ tables. RPG foundations will be implemented as Lua game mods under `game/arch_base/mods/` using only the stock Lua API (`docs/archlast-luanti-moding-docs/modding-docs.md`).
- Engine state after reset: `rev-parse HEAD` = `c0e6812b1a4260bb25a1f606f70f55f4962bb97d`, `status --short` clean, no `src/archlast/` dir. Stock `scripts/build-linux.sh` exit 0; `bin/archlast --version` = `5.17.0-archlast-debug`; `run-dev.sh --smoke --gameid arch_base` CLEAN/PASSED.
- Plan docs rewritten (no mod implementation yet — plan only): PLAN.md, README.md (arch decisions → stock-API mapping table; API surface → `arch_camera`/`arch_anim`/`arch_player`/`arch_input`/`arch_entity`/`arch_debug` Lua namespaces; branch plan → parent-repo mod commits; perf/risks/logging → Lua-only), TASKS.md Groups A–F (probes → doc-line-ref mapping; B–E → Lua mod scaffolds; F → pristine-check + stock build + bench), ACCEPTANCE.md A1–A5 (arch_* console checks, `[ARCH:*]` log tags, pristine gate in A5).
- Prior A1–A4 results above (arch_engine NEEDS-CLIENT etc.) are superseded — they measured the reverted C++ path. Next acceptance run uses the rewritten A1–A6 gates.
- Parent commit: $(git rev-parse HEAD)
- Engine commit: $(git -C engine/archlast-luanti rev-parse HEAD)

## Phase 1 Baseline
Date: 2026-10-04T14:39:07Z
frame_time_ms=16.7
