# Phase 1 Acceptance — Fork Prototype Testable

All checks runnable in order. Phase 1 passes only if all green.

## A1. Repo structure

```bash
test -f engine/archlast-luanti/CMakeLists.txt && echo OK
git -C engine/archlast-luanti remote -v
git submodule status engine/archlast-luanti
grep -A4 engine.archlast-luanti dependencies/mods.lock
```

Pass: CMakeLists exists, `origin` + `upstream` present, submodule clean, lock has 40-char commit.

## A2. Build

```bash
scripts/bootstrap.sh
scripts/build-linux.sh
ls -lh bin/archlast
bin/archlast --version
```

Pass: build exits 0, `bin/archlast` executable, `--version` contains `archlast`.

## A3. Smoke run (headless server)

```bash
scripts/run-dev.sh --smoke
echo $?
```

`run-dev.sh --smoke` must: create temp world if missing, start `bin/archlast --server --world <tmp> --logfile /tmp/archlast-smoke.log`, run ≥10s or until `ServerMap: ...` / `active block modifiers` line, shut down cleanly, exit 0.

Pass: exit 0, log has no `ERROR[Main]`, no segfault, no Lua `ModError`.

## A4. Log check

```bash
grep -iE 'error|segfault|moderror|assertion' /tmp/archlast-smoke.log || echo CLEAN
```

Pass: CLEAN or only known-benign warnings listed in log with justification.

## A5. Sync dry-run

```bash
git -C engine/archlast-luanti fetch upstream
git -C engine/archlast-luanti log --oneline -3
git -C engine/archlast-luanti status -sb
```

Pass: fetch succeeds, branches `main` + `upstream-sync` exist, working tree clean.

## Fail → do not proceed

Any red = fix Phase 1 before Phase 2. Record failure + commit hash in `docs/plans/phase-01-fork-engine-prototype/RESULTS.md` (create on run).
