
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
