# v1.0 acceptance checklist

This is a release gate, not a claim of implementation. README claims and static code inspection do not substitute for live-client evidence. Check a box only after its behavior is verified; record test date/client and evidence in this file.

- [ ] Live-test stock target-frame anchoring and relevant unit events
- [ ] Verify DPS threat percent and aggro, tank highest-other threat logic (2026-11-05 code fix: threat ownership no longer implies tank role; auto uses assigned group role, manual override available; **not live-tested**)
- [ ] Verify solo/group, target switching, combat transitions and protected API behavior
- [ ] Ensure overhead nameplates are not required
- [ ] Verify release packaging and persistence

## Evidence

- Code review: 2026-11-05 inspected threat-role classification and corrected DPS aggro misclassification in `ForeverThreat.lua`; no live evidence yet
- Automated/static tests: pending (connector-only code inspection; no Lua runtime executed)
- Live WoW: Forever client verification: pending
- Release ZIP and WoWUp installation: pending

## Status

Pre-1.0. Features described in README may be implemented but are not accepted as verified here until tested. Avoid declaring v1.0 solely on version metadata.

## Phase 1 implementation — tank aggro loss (2026-11-05)

- [x] Tank display now distinguishes confirmed lost target ownership from healthy tanking: `ForeverThreat.lua` `RenderTankMode` receives the player's `isTanking` and status from `UnitDetailedThreatSituation` and shows red `LOST AGGRO` when the API definitively reports non-tanking status below 2 (commit `84c0c2d`). No guessed threat data is introduced; DPS display and saved settings remain unchanged.
- [ ] Verify with assigned tank and `/fthreat role tank`: tank owns target, another player takes aggro, target regained, API reports unknown status, and group roster changes. Code inspected only; no Lua harness or live client evidence.
