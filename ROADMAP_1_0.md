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
