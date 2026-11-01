# ForeverThreat

A tiny threat indicator built for **WoW Forever**.

ForeverThreat does not create another combat meter window and does not use overhead enemy nameplates. Instead, it attaches a thin threat strip directly to the **enemy target frame** you already look at for health and power.

## Default behavior

- Attaches automatically to the stock target frame.
- No movable ForeverThreat window.
- Does not require overhead enemy nameplates to be enabled.
- Only appears in combat against a hostile target.
- Hidden while solo by default.
- Auto-hides whenever threat information is irrelevant.

### DPS / non-tank display

- **SAFE** below 80%
- **WATCH** at 80-89%
- **DANGER** at 90-99%
- **AGGRO** when you have pulled the target

Example: `WATCH • 87%`

### Tank display

When you are currently tanking the target, ForeverThreat watches the highest threat among the rest of the group:

- **HOLDING** while the group is comfortably behind you
- **WATCH** when another player reaches 85%+
- **LOSING** when another player reaches 95%+

## Commands

- `/fthreat test` - preview the target-frame strip; target anything first so the target frame is visible
- `/fthreat solo` - toggle display while solo
- `/fthreat show` - enable
- `/fthreat hide` - disable
- `/fthreat reset` - reset ForeverThreat settings

## Install

Copy the addon files into a `ForeverThreat` folder inside your WoW Forever AddOns folder and restart the game if this is the first installation.

The folder should contain:

- `ForeverThreat.toc`
- `ForeverThreat.lua`
- `README.md`

## Technical notes

ForeverThreat uses WoW's native `UnitDetailedThreatSituation` API. It does not parse the combat log and has no external addon dependency.

The strip anchors to the stock target frame's resource bars when available, with fallbacks for UI variants. Because it is parented to the target frame, it follows the target frame automatically if you move or scale that frame through the game UI.

Version: 0.2.0
