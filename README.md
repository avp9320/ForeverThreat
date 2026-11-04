# ForeverThreat

A tiny threat indicator built for **WoW Forever**.

ForeverThreat does not create another combat meter window and does not use overhead enemy nameplates. Instead, it attaches a compact threat badge directly to the **enemy target frame** you already look at for health and power.

## Default behavior

- Attaches automatically to the stock target frame.
- No movable ForeverThreat window.
- Does not require overhead enemy nameplates to be enabled.
- Only appears in combat against a hostile target.
- Hidden while solo by default.
- Auto-hides whenever threat information is irrelevant.

### DPS / non-tank display

- Compact `THR 87%` readout (your relative threat)
- Green below 80%, yellow from 80%, orange from 90%
- Red `AGGRO` if you pull threat

The color indicator replaces the old full-width bar and long warning label.

### Tank display

Shows `OTH 87%` for the highest other group member's relative threat, with yellow at 85% and red at 95%. When other players have no measurable threat, shows `TANKING`.

## Commands

- `/fthreat test` - preview the target-frame badge; target anything first so the target frame is visible
- `/fthreat solo` - toggle display while solo
- `/fthreat show` - enable
- `/fthreat hide` - disable
- `/fthreat reset` - reset ForeverThreat settings

## Install

### WoWUp

GitHub releases include a WoW Forever package named `ForeverThreat-vX.Y.Z-forever.zip`, which allows WoWUp to install the addon from this repository.

### Manual

Copy the addon files into a `ForeverThreat` folder inside your WoW Forever AddOns folder and restart the game if this is the first installation.

The folder should contain:

- `ForeverThreat.toc`
- `ForeverThreat.lua`
- `README.md`

## Technical notes

ForeverThreat uses WoW's native `UnitDetailedThreatSituation` API. It does not parse the combat log and has no external addon dependency.

The badge anchors to the right end of the stock target frame's resource bars when available, with fallbacks for UI variants. Because it is parented to the target frame, it follows the target frame automatically if you move or scale that frame through the game UI.

The repository includes a GitHub Actions release workflow that builds the `-forever.zip` release asset WoWUp expects whenever a release package is generated.

Version: 0.2.3
