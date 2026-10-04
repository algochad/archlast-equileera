# Phase 1 Tasks — Fork Prototype (ordered, speed-first)

Estimated: 30–90 min on warm machine. Do in order. Stop at first red.

## 1. Prereqs (5 min)

- [ ] `cmake >= 3.20`, `g++ >= 12`, IrrlichtMt deps present
- [ ] `git --version`, `cmake --version` recorded in log

```bash
scripts/bootstrap.sh
```

`bootstrap.sh` only installs system deps + prints versions. No clone/build.

## 2. Fork + embed (10 min)

- [ ] GitHub fork `archlast-luanti` exists (org or user)
- [ ] Submodule added at `engine/archlast-luanti`
- [ ] `upstream` → `https://github.com/luanti-org/luanti.git`
- [ ] `origin` → project fork URL
- [ ] Default branch name discovered, recorded

```bash
# if fork exists:
git submodule add <FORK_URL> engine/archlast-luanti
git -C engine/archlast-luanti remote add upstream https://github.com/luanti-org/luanti.git
git -C engine/archlast-luanti fetch upstream
git ls-remote --symref upstream HEAD  # record actual default branch

# if fork does NOT exist yet (do not block):
git submodule add https://github.com/luanti-org/luanti.git engine/archlast-luanti
# TODO: `git -C engine/archlast-luanti remote set-url origin <FORK_URL>` once created
```

## 3. Pin (2 min)

- [ ] `engine/archlast-luanti` checked out to known-good commit
- [ ] `dependencies/mods.lock` records luanti commit + branch
- [ ] `git submodule status` clean

Format (`dependencies/mods.lock` stub):

```text
[engine.archlast-luanti]
repo = <FORK_URL>
upstream = https://github.com/luanti-org/luanti.git
commit = <40-char sha>
upstream_branch = master  # or actual discovered name
```

## 4. Branches (3 min)

- [ ] `main` = prototype baseline
- [ ] `upstream-sync` exists, pushed
- [ ] No feature branches yet

```bash
git -C engine/archlast-luanti checkout -b upstream-sync
git -C engine/archlast-luanti checkout -b main upstream-sync
```

## 5. Minimal branding diff (5 min)

One commit only. Reject scope creep.

- [ ] Version string suffixed `-archlast` (e.g. `src/version.h` or CMake project version)
- [ ] Window title suffixed if trivial, else skip
- [ ] `git -C engine/archlast-luanti diff --stat` <= 5 files

Commit msg: `feat(engine): archlast fork identity (version suffix)`

## 6. Scripts (10 min)

- [ ] `scripts/bootstrap.sh` — dep install (apt/dnf/pacman detect), executable
- [ ] `scripts/build-linux.sh` — cmake configure + build to `build/linux/`, binary copied/linked to `bin/archlast`
- [ ] `scripts/run-dev.sh` — launches `bin/archlast` with `--gameid` stub or `--server --world` smoke flags
- [ ] All scripts `chmod +x`, no Ubuntu-only paths, no Windows logic yet

## 7. Build + smoke (remainder)

- [ ] `scripts/build-linux.sh` exits 0
- [ ] `bin/archlast --version` shows `-archlast` suffix
- [ ] `scripts/run-dev.sh --smoke` exits 0, see ACCEPTANCE.md

## Out of scope (defer, do not start)

Windows `.ps1`, packaging, engine C++ features, game/ mods, CI, texture evaluation.
