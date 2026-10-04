# Phase 1 — Fork + Engine Prototype (FIRST, actionable now)

Speed-first: get a buildable, runnable `engine/archlast-luanti` fork with pinned upstream, minimal scripts, and a smoke test. No gameplay yet.

## Goal

`engine/archlast-luanti/` exists, builds on Linux x86_64, runs `--version` + loads a world. Remotes `origin` (fork) + `upstream` (luanti-org/luanti) configured. Commit pinned and recorded.

## Non-goals

No C++ gameplay changes. No camera/controller work (Phase 2). No game mods yet (Phase 3+). No Windows packaging (defer to end of Phase 1 if time, else Phase 1.5).

## Exit criteria (must all pass)

1. `ls engine/archlast-luanti/CMakeLists.txt` succeeds.
2. `git -C engine/archlast-luanti remote -v` shows `origin` + `upstream`.
3. `scripts/build-linux.sh` completes on clean checkout.
4. `bin/archlast --version` prints fork version string.
5. `scripts/run-dev.sh --smoke` launches server, connects headless or GUI, creates world, exits 0, no Lua/C++ crash in log.

## Layout after this phase

```text
engine/archlast-luanti/   # fork checkout (NOT empty)
scripts/{bootstrap,build-linux,run-dev}.sh
docs/plans/phase-01-*/    # this plan
dependencies/mods.lock    # stub with luanti pin
README.md                 # stub: what Archlast is + build instructions
.gitmodules or docs note  # records how fork is embedded
```

## Speed decisions (locked)

- Embed method: **git submodule** at `engine/archlast-luanti` pointing at project fork. Rationale: keeps upstream history, cheap sync, no 300MB squash into monorepo. Alternative (monorepo subtree) rejected for now — slows clone, complicates `upstream-sync` merges.
- If GitHub fork doesn't exist yet: clone `https://github.com/luanti-org/luanti.git` directly, document `origin` swap as follow-up task. Do NOT block prototype on GitHub UI.
- Pin: one commit hash in `dependencies/mods.lock` + submodule pointer. No `latest`.
- Build: native CMake, system deps via `bootstrap.sh` (apt/dnf/pacman detect). No vcpkg in Phase 1.
- Branding: single `#define ARCHLAST_FORK 1` + version suffix only. No other C++ diff.
