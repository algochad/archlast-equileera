# Phase 9 Acceptance — Multiplayer + Hardening Testable

All checks runnable in order. Phase 9 passes only if all green. Evidence required for each.

## A1. Authority audit completeness

```bash
test -f docs/plans/phase-09-multiplayer/AUDIT.md && echo AUDIT_EXISTS
grep -c "NT-" docs/plans/phase-09-multiplayer/README.md
grep -rn "validate.lua" game/arch_rpg/mods/core/net/ | wc -l
```

Pass: AUDIT.md exists (may be temp), README has ≥10 NT-* entries, validate.lua present in core net module.

## A2. Negative-test suite green

```bash
scripts/test.sh --suite multiplayer-negative
echo "EXIT=$?"
grep -c "PASS" /tmp/archlast-test-results.xml
```

Pass: exit 0, all NT-* tests pass (count matches README table), no SKIP or FAIL entries. XML report generated.

## A3. Spoofed damage rejection

```bash
scripts/test.sh --suite multiplayer-negative --filter NT-DAMAGE-SPOOF
grep "\[ARCH-RPG:ANTI-CHEAT\].*damage" /tmp/archlast-test.log | tail -1
```

Pass: test exits 0, log shows rejection with expected vs received values, no HP change on target entity.

## A4. Spoofed XP rejection

```bash
scripts/test.sh --suite multiplayer-negative --filter NT-XP-SPOOF
grep "\[ARCH-RPG:ANTI-CHEAT\].*xp" /tmp/archlast-test.log | tail -1
```

Pass: test exits 0, log shows XP spoof rejected, player level unchanged.

## A5. Spoofed item grant rejection

```bash
scripts/test.sh --suite multiplayer-negative --filter NT-ITEM-SPOOF
grep "\[ARCH-RPG:ANTI-CHEAT\].*item" /tmp/archlast-test.log | tail -1
```

Pass: test exits 0, log shows unauthorized add_item rejected, inventory unchanged.

## A6. Trade anti-dupe verification

```bash
scripts/test.sh --suite multiplayer-negative --filter NT-TRADE-DUPE
grep "\[ARCH-RPG:TRADE\].*ABORT\|ROLLBACK" /tmp/archlast-test.log | tail -3
```

Pass: test exits 0, log shows trade abort/rollback on mismatch or timeout, no duplicate items in either inventory.

## A7. Party shared quest credit

```bash
scripts/test.sh --suite integration --filter party-quest-credit
grep "\[ARCH-RPG:PARTY\].*quest_credit" /tmp/archlast-test.log | wc -l
```

Pass: test exits 0, both party members receive quest credit log entry, count == 2.

## A8. Two-client dungeon rehearsal

```bash
test -f docs/plans/phase-09-multiplayer/REHEARSAL.md && echo REHEARSAL_EXISTS
grep -c "both_progress\|trade_atomic\|loot_credited\|quest_shared" docs/plans/phase-09-multiplayer/REHEARSAL.md
```

Pass: REHEARSAL.md exists with ≥4 evidence entries covering progression, trade, loot, quest credit. Manual run completed.

## A9. Sync bandwidth within budget

```bash
grep "SYNC_BW_AVG" /tmp/archlast-sync.log | awk '{if ($2 > 50) exit 1}'
echo "BW_CHECK=$?"
```

Pass: average sync bandwidth ≤ 50 KB/s per client with 8 nearby entities. Profiler log exists.

## A10. Linux package builds + size check

```bash
scripts/package.sh
ls -lh dist/ArchlastRPG-*-linux-x86_64.tar.gz | awk '{print $5}'
SIZE=$(stat -c%s dist/ArchlastRPG-*-linux-x86_64.tar.gz)
test "$SIZE" -lt 524288000 && echo SIZE_OK || echo SIZE_FAIL
```

Pass: package.sh exits 0, tarball exists, size < 500 MB.

## A11. Linux fresh-package boot

```bash
sudo -u nobody tar xzf dist/ArchlastRPG-*-linux-x86_64.tar.gz -C /tmp/fresh-linux/
sudo -u nobody /tmp/fresh-linux/ArchlastRPG/bin/archlast --server --world /tmp/fresh-world --logfile /tmp/fresh-linux.log --shutdown-timeout 10
grep -iE 'error|moderror|segfault' /tmp/fresh-linux.log || echo CLEAN
```

Pass: server starts, runs ≥10s, shuts down cleanly, log has no errors. No Luanti install required.

## A12. Windows package builds

```powershell
.\scripts\build-windows.ps1
Test-Path dist\ArchlastRPG-*-win64.zip
(Get-Item dist\ArchlastRPG-*-win64.zip).Length -lt 524288000
```

Pass: build-windows.ps1 exits 0, zip exists, size < 500 MB.

## A13. Windows fresh-package boot

```powershell
Expand-Archive dist\ArchlastRPG-*-win64.zip -DestinationPath $env:TEMP\fresh-win -Force
& "$env:TEMP\fresh-win\ArchlastRPG\bin\archlast.exe" --server --world "$env:TEMP\fresh-world" --logfile "$env:TEMP\fresh-win.log" --shutdown-timeout 10
Select-String -Pattern 'error|moderror' -Path "$env:TEMP\fresh-win.log" -CaseSensitive:$false
```

Pass: server starts, runs ≥10s, shuts down cleanly, log has no errors. No Luanti/mod setup prompted.

## A14. CI pipeline fully green

```bash
gh run list --workflow=ci.yml --limit=1 --json status,conclusion
# Or check local CI runner output
grep -E "stage.*(PASS|FAIL)" /tmp/ci-summary.log | grep -v PASS || echo ALL_GREEN
```

Pass: latest CI run conclusion == success, all 9 stages passed. Package artifact uploaded.

## A15. License compliance verified

```bash
scripts/verify-licenses.sh
echo "LICENSE_EXIT=$?"
grep -c "VIOLATION\|MISSING" /tmp/license-report.txt || echo COMPLIANT
```

Pass: verify-licenses.sh exits 0, no violations or missing attributions in report.

## A16. Final quality-bar evidence

```bash
grep -E "spec_84|two_player|fps_min" docs/plans/phase-09-multiplayer/REHEARSAL.md | wc -l
test -f /tmp/quality-bar-evidence.tar.gz && echo EVIDENCE_PACKED
```

Pass: REHEARSAL.md references spec §84 criteria, evidence archive exists with logs/screenshots/hashes.

## Fail → do not proceed

Any red = fix before declaring Phase 9 complete. Record failure + commit hash + evidence in `docs/plans/phase-09-multiplayer/RESULTS.md` (create on run). Do NOT skip negative tests or fresh-package checks.

## Cleanup after acceptance

- Delete `AUDIT.md` and `REHEARSAL.md` (temporary working docs).
- Keep `RESULTS.md` as permanent phase record.
- Remove any debug/profiler flags left in configs.