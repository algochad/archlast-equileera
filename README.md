# Archlast

Luanti fork for [project description TBD].

## Quick Start

```bash
scripts/bootstrap.sh   # Install system dependencies
scripts/build-linux.sh # Configure + build
bin/archlast --version # Verify fork identity
scripts/run-dev.sh --smoke # Headless server smoke test
```

## Structure

- `engine/archlast-luanti/` — Luanti fork (git submodule)
- `scripts/` — Build and dev automation
- `dependencies/mods.lock` — Pinned engine commit
- `docs/plans/` — Phase plans and acceptance criteria
