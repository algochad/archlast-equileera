# Phase 9 Tasks — Multiplayer + Hardening (ordered, test-first)

Estimated: 3–5 days for one engineer. Do in order. Stop at first red. All commands assume repo root.

## 1. Authority audit + server validation scaffolding (4 h)

- [ ] Enumerate every CSM→server packet in `game/arch_rpg/mods/core/net/`
- [ ] Map each packet field to authority table in README.md; flag any client-trusted numerics
- [ ] Create `game/arch_rpg/mods/core/net/validate.lua` with per-packet schema + rejection hooks
- [ ] Add `[ARCH-RPG:ANTI-CHEAT]` logging stub for all rejections
- [ ] Document audit results in `docs/plans/phase-09-multiplayer/AUDIT.md` (temporary, delete after tests land)

```bash
grep -rn "register_on_receive" game/arch_rpg/mods/core/net/ | tee /tmp/csm-packets.txt
wc -l /tmp/csm-packets.txt  # expect < 50; if more, split by domain
```

## 2. Negative-test harness (6 h)

- [ ] Create `tests/multiplayer/negative/` with one Lua test file per spoof case from README table
- [ ] Each test: spawn headless server + mock client, send spoofed packet, assert rejection log line + no state change
- [ ] Wire into `scripts/test.sh` under `multiplayer-negative` suite
- [ ] All NT-* IDs from README must have corresponding test; no orphan IDs

```bash
mkdir -p tests/multiplayer/negative
cat > tests/multiplayer/negative/init.lua <<'EOF'
-- Auto-discover NT-* tests
local dir = core.get_modpath("arch_rpg_tests") .. "/multiplayer/negative/"
for _, f in ipairs(core.get_dir_list(dir)) do
    if f:match("^nt_.*%.lua$") then dofile(dir .. f) end
end
EOF
scripts/test.sh --suite multiplayer-negative
echo $?  # must be 0
```

## 3. Server-side validation implementation (8 h)

- [ ] Implement damage recomputation in `combat/validation.lua`; reject delta > 5% tolerance
- [ ] Implement XP award server-side in `player/progression.lua`; ignore client `xp_gained`
- [ ] Implement inventory mutation guard in `items/inventory.lua`; all adds go through validated path
- [ ] Implement equip check in `items/equipment.lua`; verify ownership + level/class/bind
- [ ] Implement quest-complete check in `quests/state.lua`; verify all objectives met
- [ ] Implement teleport validation in `world/movement.lua`; rubber-band on violation
- [ ] Run negative tests after each sub-task; commit only when green

```bash
# After each validation module:
scripts/test.sh --suite multiplayer-negative --filter NT-DAMAGE-SPOOF
scripts/test.sh --suite multiplayer-negative --filter NT-XP-SPOOF
# ...one per field
```

## 4. Party minimal (4 h)

- [ ] Implement `/party invite|accept|decline|disband` in `game/arch_rpg/mods/party/`
- [ ] Server stores party state; no client-to-client messages
- [ ] Shared quest credit: hook kill/loot/objective events to check party membership
- [ ] XP split formula implemented server-side in `player/progression.lua`
- [ ] Max party size 4 enforced server-side

```bash
# Manual smoke after impl:
scripts/run-dev.sh --server &
sleep 3
# Connect two clients, /party invite, kill mob, verify both get XP in log
kill %1
```

## 5. Trade minimal + anti-dupe (6 h)

- [ ] Implement trade session lifecycle in `game/arch_rpg/mods/trade/`
- [ ] Secure window: range check + server-created session ID
- [ ] Immutable offer snapshot on submit; hash stored
- [ ] Confirm handshake: both confirms + hash match within 30s
- [ ] Atomic swap in single DB transaction or coroutine lock
- [ ] Anti-dupe: cancel invalidates session; no re-offer without new session
- [ ] NT-TRADE-DUPE test passes

```bash
scripts/test.sh --suite multiplayer-negative --filter NT-TRADE-DUPE
grep "\[ARCH-RPG:TRADE\]" /tmp/archlast-test.log | tail -20
```

## 6. Sync tuning + activation ranges (4 h)

- [ ] Configure replication rates per README sync table in `engine/archlast-luanti/src/network/` or mod override
- [ ] Set activation ranges: player global, NPC 48-node, combat events 64-node
- [ ] Implement LOD compression for positions beyond 32 nodes
- [ ] Bandwidth profiling: target < 50 KB/s per client with 8 entities
- [ ] Log `[ARCH-ENGINE:SYNC]` diagnostics enabled in debug builds

```bash
scripts/run-dev.sh --server --profiler-sync &
sleep 30
grep "SYNC_BW" /tmp/archlast-sync.log | awk '{sum+=$2} END {print sum/NR " KB/s avg"}'
kill %1
```

## 7. Two-client dungeon rehearsal (4 h)

- [ ] Launch server + two headless/GUI clients on separate ports or machines
- [ ] Both enter same dungeon instance
- [ ] Complete boss fight; verify both receive loot + quest credit in logs
- [ ] Execute trade mid-dungeon; verify atomic swap
- [ ] No desync after 30 min: compare position/state hashes
- [ ] Record rehearsal results in `docs/plans/phase-09-multiplayer/REHEARSAL.md` (temporary)

```bash
scripts/run-dev.sh --server --world /tmp/dungeon-test &
sleep 5
bin/archlast --address 127.0.0.1 --port 30000 --name player1 &
bin/archlast --address 127.0.0.1 --port 30000 --name player2 &
wait  # manual verification; kill all after
```

## 8. Package script — Linux (3 h)

- [ ] Write `scripts/package.sh`: bootstrap → build → fetch-deps → verify-licenses → assemble `ArchlastRPG/` → tar.gz
- [ ] No internet during package assembly; deps pre-fetched
- [ ] Output: `dist/ArchlastRPG-<version>-linux-x86_64.tar.gz`
- [ ] Size check: < 500 MB
- [ ] Manifest verification: all expected dirs/files present

```bash
scripts/package.sh
ls -lh dist/ArchlastRPG-*-linux-x86_64.tar.gz
tar tzf dist/ArchlastRPG-*-linux-x86_64.tar.gz | grep -E "^ArchlastRPG/(bin|games|mods|textures|assets)/" | wc -l
```

## 9. Windows build script (4 h)

- [ ] Write `scripts/build-windows.ps1`: MSVC + CMake preset → fetch-deps → verify-licenses → assemble → zip
- [ ] Include `bin/check-vcredist.ps1` in package
- [ ] Test on clean Windows VM or container (no prior Luanti)
- [ ] Output: `dist\ArchlastRPG-<version>-win64.zip`
- [ ] Same manifest as Linux package

```powershell
.\scripts\build-windows.ps1
Get-ChildItem dist\ArchlastRPG-*-win64.zip | Select-Object Length
Expand-Archive dist\ArchlastRPG-*-win64.zip -DestinationPath $env:TEMP\archlast-win-test
Test-Path "$env:TEMP\archlast-win-test\ArchlastRPG\bin\archlast.exe"
```

## 10. Fresh-package boot verification (2 h)

- [ ] Extract Linux tarball on clean user account (no `~/.minetest`, no dev env)
- [ ] Run `./ArchlastRPG/bin/archlast --server --world /tmp/fresh-test`; exit 0
- [ ] Extract Windows zip on clean Windows VM; run `archlast.exe`; window opens, no crash
- [ ] Verify no Luanti/mod setup prompts; all assets bundled

```bash
# Linux fresh boot
sudo -u nobody tar xzf dist/ArchlastRPG-*-linux-x86_64.tar.gz -C /tmp/
sudo -u nobody /tmp/ArchlastRPG/bin/archlast --server --world /tmp/fresh-world --logfile /tmp/fresh.log
grep -iE 'error|moderror' /tmp/fresh.log || echo CLEAN
```

## 11. CI pipeline wiring (4 h)

- [ ] Add stages to `.github/workflows/ci.yml` (or equivalent): bootstrap → build → fetch → verify-commits → verify-licenses → build-game → test → smoke → package
- [ ] Windows matrix job mirrors Linux stages using `build-windows.ps1`
- [ ] Each stage fails fast on non-zero exit
- [ ] Artifacts: package tarball/zip uploaded on success
- [ ] Required status checks configured in repo settings

```bash
# Validate CI config syntax locally if possible
actionlint .github/workflows/ci.yml || yamllint .github/workflows/ci.yml
```

## 12. Final quality-bar run (spec §84) (4 h)

- [ ] Two-player dungeon run per README quality-bar table
- [ ] All criteria verified + evidence captured (logs, screenshots, hashes)
- [ ] Performance ≥ 30 FPS both clients on min-spec hardware
- [ ] Full negative-test suite green
- [ ] Fresh package boots on both platforms confirmed again post-CI

```bash
scripts/test.sh --suite multiplayer-negative
echo "Negative tests: $?"
# Manual QA run follows; record in REHEARSAL.md
```

## Out of scope (defer, do not start)

Launcher, auto-updater, voice chat, cross-version play, client-side prediction/reconciliation, kernel anti-cheat, new content, mod browser, account system.

## Logging reminders

- Use `[ARCH-RPG:AUTH]`, `[ARCH-RPG:ANTI-CHEAT]`, `[ARCH-RPG:TRADE]`, `[ARCH-RPG:PARTY]`, `[ARCH-ENGINE:SYNC]`, `[ARCH-BUILD:*]` prefixes consistently.
- All timestamps UTC ISO-8601.
- Never log PII or raw passwords/secrets.