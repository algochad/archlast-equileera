# Phase 9 — Multiplayer + Hardening

Depends on: Phase 8 green.

## Goal

Server-authoritative multiplayer viable: sync, parties, trading, anti-cheat validation, packaging.

## Scope

- Authority audit: damage/inventory/equipment/quest/XP/skills/teleport/trade validated server-side; client = input/camera/UI only
- Parties + trading + multiplayer combat sync + persistent progression
- Packaging: `scripts/package.sh` → `ArchlastRPG/{bin,games,mods,assets}` self-contained; Linux + Windows (`build-windows.ps1`) first-class
- CI: build + `test.sh` + smoke per engine change; `verify-dependencies.sh` + `verify-licenses.sh` gates

## Non-goals

New classes/content; launcher/auto-updater.

## Tasks

1. Threat pass: list trusted vs untrusted fields; add server validation + tests (spoofed damage/XP/item cases).
2. Party + trade minimal (invite, shared quest credit, secure trade window).
3. `package.sh` + Windows build verified on clean machine/VM.
4. Full quality-bar run (spec §84) two-player: both progress, trade, dungeon, boss.

## Acceptance

- [ ] Spoofed client damage/XP/item grants rejected by server (negative tests pass)
- [ ] 2-client dungeon run completes with loot + quest credit for both
- [ ] Fresh Linux + Windows packages run without Luanti/mod setup
