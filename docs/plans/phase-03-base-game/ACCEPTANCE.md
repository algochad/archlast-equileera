# Phase 3 Acceptance — Base Game Testable

All checks runnable in order from repo root. Phase 3 passes only if all green.
Commands assume POSIX shell; no Windows paths.

## A1. Directory structure

```bash
test -f game/arch_rpg/game.conf && echo "game.conf OK"
test -f game/arch_rpg/game.mt && echo "game.mt OK"
test -d game/arch_rpg/mods/arch_rpg_core && echo "core mod OK"
test -d game/arch_rpg/mods/arch_rpg_world && echo "world mod OK"
test -d game/arch_rpg/mods/arch_rpg_player && echo "player mod OK"
test -d game/arch_rpg/textures && echo "textures dir OK"
test -d game/arch_rpg/models && echo "models dir OK"
test -d game/arch_rpg/sounds && echo "sounds dir OK"
```

Pass: all eight checks print OK. Missing file/dir = fail.

## A2. Game identity in menu

```bash
grep -q '^name = Archlast RPG$' game/arch_rpg/game.conf && echo "Name OK"
grep -q '^gameid = arch_rpg$' game/arch_rpg/game.mt && echo "GameID OK"
```

Pass: both lines match exactly. Game must appear as "Archlast RPG" in Luanti main menu, not "Luanti + mods" or "arch_rpg".

## A3. Core module APIs present

```bash
grep -q 'function arch_rpg.events.on' game/arch_rpg/mods/arch_rpg_core/events.lua && echo "events.on OK"
grep -q 'function arch_rpg.events.emit' game/arch_rpg/mods/arch_rpg_core/events.lua && echo "events.emit OK"
grep -q 'function arch_rpg.registry.register_node' game/arch_rpg/mods/arch_rpg_core/registry.lua && echo "registry OK"
grep -q 'function arch_rpg.log.info' game/arch_rpg/mods/arch_rpg_core/logger.lua && echo "logger OK"
grep -q 'function arch_rpg.save.load_meta' game/arch_rpg/mods/arch_rpg_core/save.lua && echo "save OK"
grep -q 'CURRENT_VERSION = 1' game/arch_rpg/mods/arch_rpg_core/save.lua && echo "save_version OK"
```

Pass: all six API signatures found. Missing function = fail.

## A4. Node registration count

```bash
count=$(grep -c 'arch_rpg.registry.register_node' game/arch_rpg/mods/arch_rpg_world/nodes.lua)
[ "$count" -ge 9 ] && echo "Nodes OK ($count registered)" || echo "FAIL: only $count nodes"
```

Pass: ≥9 nodes registered (target ~10). Fewer = fail.

## A5. Biome + mapgen override

```bash
grep -q 'arch_rpg_temperate_forest' game/arch_rpg/mods/arch_rpg_world/biome.lua && echo "Biome OK"
grep -q 'set_mapgen_setting.*seed' game/arch_rpg/mods/arch_rpg_world/mapgen.lua && echo "Seed override OK"
```

Pass: biome name matches, seed override call present.

## A6. Player spawn + third-person default

```bash
grep -q 'register_on_newplayer' game/arch_rpg/mods/arch_rpg_player/spawn.lua && echo "Spawn hook OK"
grep -q 'player:spawned' game/arch_rpg/mods/arch_rpg_player/spawn.lua && echo "Spawn event OK"
grep -qE '(camera_mode|set_eye_offset)' game/arch_rpg/mods/arch_rpg_player/spawn.lua && echo "Third-person OK"
```

Pass: newplayer hook registered, event emitted, camera configured.

## A7. Save/load persistence

```bash
grep -q 'register_on_shutdown' game/arch_rpg/mods/arch_rpg_player/persist.lua && echo "Save hook OK"
grep -q 'player:position_saved' game/arch_rpg/mods/arch_rpg_player/persist.lua && echo "Persist event OK"
```

Pass: shutdown hook and position event present.

## A8. Scripts executable + gameid cutover

```bash
test -x scripts/run-dev.sh && echo "run-dev.sh executable OK"
test -x scripts/test.sh && echo "test.sh executable OK"
grep -q '\-\-gameid arch_rpg' scripts/run-dev.sh && echo "GameID default OK"
```

Pass: both scripts executable, run-dev.sh defaults to arch_rpg.

## A9. World create smoke test

```bash
scripts/test.sh phase3-world-smoke
echo "Exit code: $?"
```

`tests/phase3-world-smoke.sh` must:
1. Create temp world directory under `/tmp/archlast-phase3-test-XXXX`.
2. Launch `bin/archlast --server --gameid arch_rpg --world <tmp> --logfile /tmp/archlast-phase3.log`.
3. Wait for `ServerMap:` or `active block modifiers` line (≤30s timeout).
4. Verify `arch_rpg_meta.json` exists in world dir with `"save_version": 1`.
5. Shut down server cleanly.
6. Exit 0 on success, non-zero on any failure.

Pass: exit code 0. Non-zero = fail; inspect log.

## A10. Log cleanliness

```bash
grep -iE 'moderror|error\[main\]|segfault|assertion' /tmp/archlast-phase3.log || echo "LOG CLEAN"
```

Pass: prints LOG CLEAN. Any match = fail; investigate before proceeding.

## A11. Save version in metadata

```bash
python3 -c "
import json, sys
with open('/tmp/archlast-phase3-test-'*'/arch_rpg_meta.json') as f:
    d = json.load(f)
assert d.get('save_version') == 1, f'save_version={d.get(\"save_version\")}'
print('Save version OK')
" 2>/dev/null || grep -q '"save_version": 1' /tmp/archlast-phase3-test-*/arch_rpg_meta.json && echo "Save version OK"
```

Pass: save_version is exactly 1. Wrong version or missing key = fail.

## Fail → do not proceed

Any red check = fix Phase 3 before Phase 4. Record failure details + commit hash in `docs/plans/phase-03-base-game/RESULTS.md` (create on first run). Do NOT start Phase 4 tasks until all A1–A11 pass.

## Re-run after fixes

After fixing failures, re-run ALL checks A1–A11 from top. Partial re-runs mask regressions.