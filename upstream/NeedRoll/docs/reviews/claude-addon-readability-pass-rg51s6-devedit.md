# Review: /nr devedit, show the pick and draw patrols, areas and outlines with the mouse

| | |
| --- | --- |
| Branch | `devedit-tools` into `ae013b0` (the shared-helpers group, open as PR #609, not merged). PR not opened yet |
| Commit reviewed | `bc7ef01` (round 3: `e3282cc..bc7ef01`, then the whole group `ae013b0..bc7ef01` again; round 2 `c26c178`, round 1 `8aa637b`), no uncommitted changes |
| Date | 2026-10-18 |
| Round | 3 (last) |
| Verdict | **Ready**, with one nit for Mike to decide (0 blocking, 0 should fix, 1 nit open: R10; R1-R9 fixed) |
| Needs | `/reload` (Lua only: no file added to or removed from the `.toc`, no SavedVariables key or format change) |

## What the change does

Mike asked (2026-10-17) for `/nr devedit` to show what is selected, to show when it is let
go, and to draw patrol lines and drop zones with the mouse. Before, the only sign of a pick
was a faint blue fill on its palette button, and a right-click on the map placed the tool.
After:

- The picked palette button gets a 1px gold edge over its blue fill (`T:Border`, which now
  returns its four edges so they can be shown and hidden).
- A line above Export and Done names the pick and its next step ("Entrance  ·  click the
  map", "Patrol: loop for Cookie  ·  drag on the map to draw"), or "Nothing picked" in grey.
- The same text follows the cursor on a dark strip while the mouse is over the map.
- A second click on the picked button, Escape, a right-click on the map, or turning dev
  edit off lets go of the pick. A right-click on the map no longer places anything.
- Drawing: a patrol tool and a clicked pin, the area tool and a clicked marker, or the
  outline tool, then a left drag on the map lays a route under the cursor, one point each
  12 UI units of mouse movement, rounded to three decimals. A drag too short to be a route,
  Escape, or right-click mid-drag puts back what was there. While a drawing tool is picked
  the zoomed map no longer pans on drag.

Code: `ns.UI.CursorOnCanvas` (Overview) replaces the inline cursor maths in the map's click
handler and is used by the drawing code; `T:OnEscape` (Theme) replaces three copies of the
"Escape closes, other keys reach the game" handler in Settings, the Wishlist list menu and
`T:Dialog`, and drives the palette's Escape. The devexport text and the saved-copy shapes are
unchanged.

## Scope

- `NeedRoll/UI/MapEdit.lua`: the picked line and cursor cue (`CreatePickedLine`,
  `CreatePickCue`, `FollowCursor`, `PickText`, `PickTitle`, `DrawForName`, `NEXT_STEP`,
  `ShowPicked`, `PaletteButtons`, a rewritten `UpdatePalette`), `SetLinking`, `LetGo`,
  `Cancel`, the stroke code (`START_ROUTE`, `StartPatrolRoute`, `StartArea`, `StartOutline`,
  `AddStrokePoint`, `FollowStroke`, `StartStroke`, `EndAtCursor`, `EndStroke`, `CancelStroke`,
  `StopStroke`, `FewestPoints`), `drawFor` set in `Press` and `Click`, help text and palette
  height constants. Read in full.
- `NeedRoll/UI/Overview.lua`: `ns.UI.CursorOnCanvas`; `AddMapMouse`'s `OnDragStart`,
  `OnDragStop` and `OnMouseUp` call into MapEdit. Read `AddMapMouse` and its callers.
- `NeedRoll/UI/Theme.lua`: `T:Border` returns its edges; new `T:OnEscape`; `T:Dialog` uses it.
- `NeedRoll/UI/MainFrame.lua`: the Settings host's Escape handler becomes `T:OnEscape`.
- `NeedRoll/UI/Wishlist.lua`: the list menu's Escape handler becomes `T:OnEscape`.
- `tests/smoke/wow.lua`: `GetCursorPosition` reads `W.cursorX`/`W.cursorY`.
- `tests/smoke/modules/UI-MapEdit.lua`: two scenarios (showing and letting go of a pick;
  drawing a patrol, area and outline and exporting them); `drawFor` and `stroke` added to the
  fields each scenario restores.
- `docs/STYLE-GUIDE.md`: a "Dev edit palette" table.

No generated data under `NeedRoll/Data/` is touched. This Review Doc is left out of the review.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 7 changed Lua files | passed |
| `python3 tools/locales.py --check` | passed (exit 0); no `L["..."]` key added or removed |
| `python3 tools/translations.py` | ran, exit 0; it lists 50 "not used by NeedRoll any more" phrases in the translation files, none touched by this change (no locale or `L[]` change in the diff) |
| `luacheck --no-global -q`, base (`ae013b0`) vs head | same counts, no new warnings: MainFrame 5/5, MapEdit 1/1, Overview 1/1, Theme 71/71, Wishlist 0/0, UI-MapEdit 0/0, wow.lua 101/101 |
| `tests/smoke/check.sh` | passed in all three runs (dev, packaged, secret values), "all passed" each; both new MapEdit scenarios pass in the dev and secret runs, and the packaged run (where edit mode is off) passes too |
| Upvalue counts (`luac5.1 -l`) | `ns.UI.CreateOverview` 36 before and after (limit 60); highest in MapEdit 11 (`Palette`), Theme 7, MainFrame 11, Wishlist 16, all unchanged or +1 |
| Scraper unit tests | not run: no scraper change |
| Round 2: `luac5.1 -p` on the 4 changed Lua files | passed |
| Round 2: `python3 tools/locales.py --check`, `tools/translations.py` | passed (exit 0); translations lists the same 50 unused phrases, none from this change |
| Round 2: `luacheck`, `9596288` vs `c26c178` | no new warnings: MapEdit 1/1, Theme 71/71, UI-MapEdit 0/0, wow.lua 101/101 |
| Round 2: `tests/smoke/check.sh` | passed in all three runs (dev, packaged, secret values), including the three new scenarios |
| Round 2: mutation runs (on a throw-away `git archive` copy, not the worktree) | pan scenario: making the zoomed map never pan (`... or true then return end`) fails "with dev edit off a drag didn't move the zoomed map", so it does test panning. R1 scenario: making the `OnHide` hook do nothing fails "a picked tool keeps keys from the game". Combat guard: removing `if not InCombatLockdown()` from the key handler still gives **all passed** (R7) |
| Round 2: upvalues | `ns.UI.CreateOverview` 36 (Overview unchanged this round) |
| Round 3: `luac5.1 -p` on the 5 changed Lua files | passed |
| Round 3: `python3 tools/locales.py --check`, `tools/translations.py` | passed (exit 0); the same 50 unused phrases, none from this change |
| Round 3: `luacheck`, `e3282cc` vs `bc7ef01` | no new warnings: MapEdit 1/1, Theme 71/71, UI-MapEdit 0/0, wow.lua 101/101; the new `UI-Theme.lua` 0 |
| Round 3: `tests/smoke/check.sh` | passed in all three runs (dev, packaged, secret values), including the two new `UI/Theme` scenarios and the reworked MapEdit one |
| Round 3: mutation runs | all four changes to the combat rule caught (see Round 3 re-check) |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | WoW API | `UI/Theme.lua:958-968`, `UI/MapEdit.lua:1086-1088, 1232` | After Escape hides a `T:OnEscape` frame its key passing stays off; shown again in combat it swallows every key | fixed: round 2 (`c26c178`) for an Escape that hides the frame, round 3 (`bc7ef01`) for the rest (R6, R8) |
| R2 | should fix | Readability | `UI/MapEdit.lua:1185-1191, 1267-1285, 1342-1351` | The picked line and cue can name a pick that is no longer the one in use | fixed in round 2 (`c26c178`) |
| R3 | nit | Readability | `UI/MapEdit.lua:125, 1123` | `HINT_HEIGHT = 245` is a hand count of the help text's lines | fixed in round 2 (`c26c178`) |
| R4 | nit | Redundant code | `UI/MapEdit.lua:943, 1186, 1280` | The unit's display name is built the same way in three places | fixed in round 2 (`c26c178`) |
| R5 | nit | WoW API (tests) | `tests/smoke/modules/UI-MapEdit.lua:591, 608` | No scenario pins the map's pan with dev edit off; one assertion can't fail; a tool by index | fixed in round 2 (`c26c178`) |
| R6 | should fix | WoW API | `UI/Theme.lua:963-966`, `UI/MapEdit.lua:1086-1088` | An Escape that doesn't hide the frame (cancelling a drag) still leaves it keeping keys in combat | fixed in round 3 (`bc7ef01`) |
| R7 | should fix | WoW API (tests) | `tests/smoke/wow.lua:186-188` | The `SetPropagateKeyboardInput` stand-in accepts calls in combat, so no scenario can catch a dropped combat guard | fixed in round 3 (`bc7ef01`) |
| R8 | should fix | WoW API | `UI/Theme.lua:958-962` | A `T:OnEscape` frame built in combat starts at the game's default and keeps every key while shown | fixed in round 3 (`bc7ef01`) |
| R9 | nit | Readability | `UI/MapEdit.lua:1278-1300` | A unit lookup that finishes late takes over whatever tool was picked meanwhile | fixed in round 3 (`bc7ef01`) |
| R10 | nit | Readability | `UI/MapEdit.lua:1299-1301` | The found-unit comment says "while the game looked", but a tool picked before the lookup also stops the pick || fixed at integration (comment now says "another tool is already picked") |

### R1 · After Escape hides a `T:OnEscape` frame its key passing stays off; shown again in combat it swallows every key

- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/UI/Theme.lua:958-968` (`T:OnEscape`); its new caller
  `NeedRoll/UI/MapEdit.lua:1086-1088` (`f.escape`), shown and hidden by `UpdatePalette`
  (`MapEdit.lua:1232`); the same holds for the three moved callers (`MainFrame.lua:1160`,
  `Wishlist.lua:481`, `Theme.lua:992`)
- **Status:** fixed in round 2 (`c26c178`): the frame's key passing is switched back on a frame after any hide, out of combat only, and the set-up call is skipped in combat. What that leaves is R6 (an Escape that doesn't hide) and R8 (a frame built in combat).

**What's wrong.** The handler turns key passing off for Escape and back on for any other key:

```lua
frame:SetScript("OnKeyDown", function(_, key)
    if not InCombatLockdown() then frame:SetPropagateKeyboardInput(key ~= "ESCAPE") end
    if key == "ESCAPE" then onEscape() end
end)
```

Key passing is a property of the frame and it outlives a hide. Every caller's `onEscape`
hides the frame (the menu, the dialog's shade, and now the palette's `f.escape`, which
`UpdatePalette` hides as soon as nothing is picked), so after the Escape that closed it the
frame sits hidden with passing off. Out of combat that heals on the next key, because the
handler turns it back on before the key is used. In combat it can't: the guard skips the
call, and the frame keeps eating every key.

**Why it matters.** Dev edit: pick a tool, press Escape to let go (`f.escape` hidden, passing
off), pick the next tool (`f.escape` shown again), pull a mob. Every key, 1-0, movement,
bindings, goes to `f.escape` and never reaches the game until Escape is pressed. Players hit
the same with the Wishlist list menu or a `T:Dialog` closed by Escape and reopened in combat.
For the three moved callers this was already the case before the change (the code moved
letter for letter, so their behaviour is exactly as before, which is what was asked), but the
palette is the caller where it happens most: its frame is hidden by every Escape. With the
handler now in one place, one fix covers all four.

A smaller point in the same function: the set-up call `frame:SetPropagateKeyboardInput(true)`
is not combat-guarded. The palette is built on the first `/nr devedit`, which can be typed in
combat, so that call can now run in combat where the handler itself guards it.

**Evidence.** Lines read above. `SetPropagateKeyboardInput`, `EnableKeyboard` and
`InCombatLockdown` are in the `forever` lists (`WidgetAPI.lua`, `GlobalAPI.lua`). That the
property persists across hide and that it can't be set in combat is inferred from the game's
documented behaviour (warcraft.wiki.gg, and the code's own guard); the smoke stand-in makes
`SetPropagateKeyboardInput` a no-op (`tests/smoke/wow.lua:188`), so no scenario can show it.

**Fix.** Put passing back on whenever the frame hides (the hide that follows Escape runs out
of combat, inside the same key press), and guard the set-up call:

```lua
function T:OnEscape(frame, onEscape)
    frame:EnableKeyboard(true)
    if not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
    frame:SetScript("OnKeyDown", function(_, key)
        if not InCombatLockdown() then frame:SetPropagateKeyboardInput(key ~= "ESCAPE") end
        if key == "ESCAPE" then onEscape() end
    end)
    -- Hidden by its Escape, it would keep the game's keys when it shows again in combat.
    frame:HookScript("OnHide", function()
        if not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
    end)
end
```

Settings' host may not hide on `CloseSettings` (it calls `self:Refresh()`), so check it there
too. If Mike wants the three moved callers left exactly as they were, the hook can be added
for `f.escape` alone, but the bug is the same in all four.

### R2 · The picked line and cue can name a pick that is no longer the one in use

- **Severity:** should fix
- **Area:** Readability (disinformation, in the UI this change exists to make trustworthy)
- **Where:** `NeedRoll/UI/MapEdit.lua:1267-1285` (`LookUpUnit`), `1185-1191` (`PickTitle`),
  `1342-1351` (`Reset`), `1142-1167` (`ShowBosses`)
- **Status:** fixed in round 2 (`c26c178`): `LookUpUnit` lets go of a picked unit when a new lookup starts, `Reset` calls `LetGo`, and `ShowBosses` lets go of a boss tool that isn't one of this dungeon's bosses (and clears hidden boss buttons' tools). A scenario covers all three. R9 is a related case this didn't touch.

**What's wrong.** The line and the cue are only redrawn by `UpdatePalette`, and three paths
change what a click would do without calling it or letting go:

1. **A new unit lookup while "unit" is picked.** `LookUpUnit` sets `self.unit = unit` at once,
   but its `ShowUnit` returns before `UpdatePalette` while the display ID is still unknown:
   ```lua
   if not unit.display then return end
   ...
   self.tool = "unit"
   self:UpdatePalette()
   ```
   The line keeps saying "Defias Overseer  ·  click the map" while a map click now does
   nothing (`Place` returns at `if not (unit and unit.display) then return end`, silently). If
   the lookup ends in "Not found", the line names the old unit for good.
2. **`/nr devedit reset`.** `Reset` drops `NeedRollDB.mapEdit` and the rest but keeps
   `tool`, `linking` and `drawFor`, which point into the dropped copy. The line still says
   "Patrol: loop for Cookie  ·  drag on the map to draw"; the drag then prints "click a boss or
   unit icon on this level first", the opposite of what the line said.
3. **A boss tool after moving to another dungeon.** `ShowBosses` rebuilds the boss buttons
   but keeps `tool = "boss:<old id>"`; `PickTitle` finds no button with that tool and falls
   back to the raw key, so the line reads "boss:1234  ·  click the map", and a click places a
   boss from the last dungeon on this map (the placing was already so before; the line is new).

**Why it matters.** Mike's complaint was not being able to see what is selected. A line that
names the wrong thing, or promises a step that won't work, is worse than no line: he places
or draws expecting one result and gets nothing, with no message.

**Evidence.** Lines read above; `PickText` (`MapEdit.lua:1208-1217`) reads `self.unit`,
`self.drawFor` and the boss buttons only when `UpdatePalette` runs. Traced by reading, not by
a scenario.

**Fix.** Let go, or redraw, wherever the pick's target changes:

- `LookUpUnit`: when a new lookup starts, `if self.tool == "unit" then self:LetGo() end` (or
  call `self:UpdatePalette()` before `if not unit.display then return end`, and have
  `PickText` say "Looking up..." for a unit without a display).
- `Reset`: `self:LetGo()` before redrawing.
- `ShowBosses`: when `self.tool` is a `boss:` tool no button now carries, `self.tool = nil`
  before its `UpdatePalette`.

A scenario for the first two (start a lookup with "unit" picked; reset with a patrol pin
picked) would keep them fixed.

### R3 · `HINT_HEIGHT = 245` is a hand count of the help text's lines

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/MapEdit.lua:125`, used at `1123`; the text at `1050-1066`
- **Status:** fixed in round 2 (`c26c178`): the height comes from `f.hint:GetStringHeight()`, and `HINT_HEIGHT` is gone.

**What's wrong.** `local HINT_HEIGHT = 245   -- the help text's 17 lines` hard-codes 14.4 UI
units a line times a line count someone counted by hand. The text does have 17 lines now
(counted), and 245 / 17 matches the old 202 / 14, so the palette fits today. The implementer
asked about this value.

**Why it matters.** The next help line added (this change added three) leaves the constant
and its comment wrong, and the last lines run into the picked line, which sits a fixed 42 up
from the bottom.

**Evidence.** `f.hint` is anchored `TOPLEFT` and `RIGHT` only (`1050-1051`, `1122`), so the
font string's height is the text's own.

**Fix.** Size from the text: `f:SetHeight(y + math.ceil(f.hint:GetStringHeight()) + FOOTER_HEIGHT)`
(`GetStringHeight` is a FontString method in `forever` `WidgetAPI.lua`; the width is fixed by
the two anchors before `LayOutBosses` runs) and drop `HINT_HEIGHT`. If the hand count stays,
keep it but say in the comment how it was measured.

### R4 · The unit's display name is built the same way in three places

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/MapEdit.lua:943` (unit button tooltip), `1186` (`PickTitle`, new),
  `1280` (`ShowUnit`)
- **Status:** fixed in round 2 (`c26c178`): `UnitTitle(unit)` is used in all three places.

**What's wrong.** `unit.name or ("Unit " .. unit.npc)` appears three times; this change added
the third. `PickTitle` says it gives "the pick's name, as its button's tooltip gives it", and
for every other button it reads `b.title`, but for the unit it rebuilds the string.

**Why it matters.** Changing how a nameless unit is shown means finding all three; miss one
and the line, the tooltip and the palette label disagree.

**Fix.** One `local function UnitTitle(unit) return unit.name or ("Unit " .. unit.npc) end`
used by all three, or set `f.unitButton.title` in `ShowUnit` so `PickTitle`'s loop finds it
like any other button and its `tool == "unit"` branch goes.

### R5 · No scenario pins the map's pan with dev edit off; one assertion can't fail; a tool by index

- **Severity:** nit
- **Area:** WoW API (smoke coverage)
- **Where:** `tests/smoke/modules/UI-MapEdit.lua:591, 608`; `NeedRoll/UI/Overview.lua:1996-2012`
- **Status:** fixed in round 2 (`c26c178`): a new scenario pans the zoomed map with edit off, with a placing tool and with a drawing tool; the dead assertion's comment is gone; `ToolButton(palette, tool)` finds buttons by tool.

**What's wrong.** The change edits the map's `OnDragStart`/`OnDragStop` that every player
uses (`if ns.MapEdit:StartStroke(self) or view.zoom <= 1 then return end`). By reading, it
is unchanged with edit mode off: `StartStroke` returns `false` at
`self.on and START_ROUTE[...]`, and `EndStroke` returns at `if not stroke`. No scenario
drags the zoomed map, with edit off or with a non-drawing tool, so a later change to
`StartStroke` could stop players panning without a test failing (`UI-Overview.lua:284-330`
covers zoom by wheel only). In the drawing scenario, "draws nothing (and doesn't move the
map)" at line 608 runs at zoom 1, where the map never pans, so its second half can't fail.
Line 591 picks `palette.tools[11]` and relies on "patrol-loop" being the eleventh tool.

**Fix.** Add a few lines to a scenario: zoom in with the wheel, `DragOnMap` with edit off,
assert `view.cx` or `view.cy` moved; turn edit on with the entrance tool picked, assert it
still pans; with `patrol-line` picked, assert it doesn't. Find the patrol button by
`b.tool == "patrol-loop"`, as the scenario already does for "entrance".

### R6 · An Escape that doesn't hide the frame (cancelling a drag) still leaves it keeping keys in combat

- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/UI/Theme.lua:963-966` (the key handler) and `968-977` (the `OnHide` hook);
  the caller it bites, `NeedRoll/UI/MapEdit.lua:1086-1088` (`f.escape`, its `onEscape` being
  `MapEdit:Cancel`)
- **Status:** fixed in round 3 (`bc7ef01`): the `OnHide` hook and timer are gone. As combat starts (`PLAYER_REGEN_DISABLED`), every Escape frame, shown or hidden, is set to pass all keys, so a frame still holding keys after an Escape that didn't hide it (the mid-drag cancel) can't keep them in combat. A scenario drives exactly that path.

**What's wrong.** Round 2 switches key passing back on only when the frame hides. But an
Escape turns it off whether or not the frame then hides:

```lua
if not InCombatLockdown() then frame:SetPropagateKeyboardInput(key ~= "ESCAPE") end
if key == "ESCAPE" then onEscape() end
```

`MapEdit:Cancel` with a drag in progress only drops the drag (`CancelStroke`) and keeps the
tool picked, so `UpdatePalette` (via `Redraw` → `ShowBosses`) keeps `f.escape` shown. No hide
means no `OnHide`, so the frame stays shown with key passing off.

**Why it matters.** Drawing a patrol in a dungeon, press Escape to drop a bad stroke, and a
patrol pulls before any other key is pressed. Every key from then on goes to `f.escape`
instead of the game (out of combat the next key would switch it back, in combat it can't)
until Escape lets go of the tool. It is R1's bug through the one path R1's fix doesn't cover.
The three player-facing callers all hide on Escape, so only the palette has it.

**Evidence.** Traced by reading: `MapEdit.lua` `Cancel` returns after `CancelStroke` when
`self.stroke` is set, `StopStroke` only hides `strokeDriver`, and `UpdatePalette` shows
`f.escape` while `PickText` is non-nil (the tool is still picked). The smoke stand-in can't
show it, because nothing there routes keys by the setting (R7).

**Fix.** Switch it back a frame after every Escape, not only after a hide. That covers both
cases and replaces the hook:

```lua
frame:SetScript("OnKeyDown", function(_, key)
    if not InCombatLockdown() then frame:SetPropagateKeyboardInput(key ~= "ESCAPE") end
    if key ~= "ESCAPE" then return end
    onEscape()
    -- The game reads the setting once this handler returns, so it goes back on a frame
    -- later; left off, a frame shown in combat would keep every key from the game.
    C_Timer.After(0, function()
        if not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
    end)
end)
```

A scenario: start a stroke, Escape, `W.Advance`, and assert `escape:IsShown()` and
`escape:GetPropagateKeyboardInput()`.

### R7 · The `SetPropagateKeyboardInput` stand-in accepts calls in combat, so no scenario can catch a dropped combat guard

- **Severity:** should fix
- **Area:** WoW API (smoke stand-in)
- **Where:** `tests/smoke/wow.lua:186-188`
- **Status:** fixed in round 3 (`bc7ef01`): the stand-in errors in combat like `ClearOverrideBindings`, and `EnableKeyboard`/`IsKeyboardEnabled` are now tracked. A throw-away copy with the key handler's guard removed now fails two scenarios.

**What's wrong.** The new stand-in stores whatever it is given, at any time:

```lua
function Widget:SetPropagateKeyboardInput(propagate) self._propagateKeys = propagate end
```

In the game the call is refused for addon code in combat, which is why `T:OnEscape` guards all
three calls with `InCombatLockdown()`. The stand-in already models calls like this by raising
an error in combat (`ClearOverrideBindings` and `SetOverrideBindingClick` at
`wow.lua:1304-1308`, secure-frame calls at `250` and `651`). This one doesn't.

**Why it matters.** The combat half of R1's new scenario ("in combat too") only proves the
value read back is `true`. With the guard removed from the key handler, the code calls
`SetPropagateKeyboardInput` in combat, which the game blocks, and every scenario still
passes. The default (`false` for a new frame) matches the game.

**Evidence.** Mutation run on a throw-away copy: removing `if not InCombatLockdown() then`
from the handler gives "all passed" across the suite. The combat restriction is inferred from
warcraft.wiki.gg and the addon's own guards. `GetPropagateKeyboardInput` and
`SetPropagateKeyboardInput` are both in `forever` `WidgetAPI.lua`.

**Fix.** Follow the file's pattern:

```lua
function Widget:SetPropagateKeyboardInput(propagate)
    if W.combat then error("SetPropagateKeyboardInput in combat", 2) end
    self._propagateKeys = propagate
end
```

Then the "in combat too" scenario fails if any of the three guards goes.

### R8 · A `T:OnEscape` frame built in combat starts at the game's default and keeps every key while shown

- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/UI/Theme.lua:958-962` (the set-up and the header comment); callers built
  on first use: the Settings host (`MainFrame.lua:1150-1161`, built by `ShowSettingsPage` the
  first time Settings opens), the Wishlist list menu, `T:Dialog`, and the dev palette
- **Status:** fixed in round 3 (`bc7ef01`): a frame given `T:OnEscape` in combat is queued and takes no keys (keyboard not enabled) until `PLAYER_REGEN_ENABLED`, when it is set up. The header comment now points to the combat rule. Two `UI-Theme` scenarios cover both halves.

**What's wrong.** Round 2 skips the set-up call in combat:

```lua
frame:EnableKeyboard(true)
if not InCombatLockdown() then frame:SetPropagateKeyboardInput(true) end
```

That removes the blocked call, but a new frame doesn't pass keys on by default. So a frame
built in combat takes keyboard input and keeps every key it gets, and its handler can't switch
that in combat either. The header comment ("In combat ... Escape reaches the game too") is
then wrong for that frame: nothing reaches the game.

**Why it matters.** A player opens NeedRoll's Settings for the first time in a session while
in combat. `BuildSettingsPage` runs then, and while the page is open the player can't move,
cast or use any binding until they press Escape. The same happens with the Wishlist menu or a
dialog opened for the first time in combat. Before round 2 the set-up call ran in combat and
was blocked, with the same result plus a blocked-action report, so this was already so before
the change. But R1's fix is meant to cover combat, and this is the other way in.

**Evidence.** Lines read above. The default is inferred from the game's behaviour (it's why
every caller called `SetPropagateKeyboardInput(true)` at set-up) and matches the stand-in's
`or false`. `BuildSettingsPage` is called from `ShowSettingsPage` only when Settings opens
(`MainFrame.lua:1165-1168`).

**Fix.** In combat, don't take the keyboard until combat ends:

```lua
local function ListenForEscape()
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
end
if InCombatLockdown() then
    ns:On("PLAYER_REGEN_ENABLED", function()
        if not frame:IsKeyboardEnabled() then ListenForEscape() end
    end)
else
    ListenForEscape()
end
```

(Escape won't close a frame built in combat until that combat ends, which is far better than
eating keys.) If `EnableKeyboard` turns out to be restricted in combat as well, this sketch
already keeps it out of combat. Update the header comment to say so. A scenario: build the
palette or open a `T:Dialog` with `W.combat = true` and assert it doesn't take keys
(`IsKeyboardEnabled`, once the stand-in tracks it) until `PLAYER_REGEN_ENABLED`.

### R9 · A unit lookup that finishes late takes over whatever tool was picked meanwhile

- **Severity:** nit
- **Area:** Readability (what the palette says versus what a click does)
- **Where:** `NeedRoll/UI/MapEdit.lua:1278-1300` (`LookUpUnit`, its `ShowUnit` setting
  `self.tool = "unit"`)
- **Status:** fixed in round 3 (`bc7ef01`): the found unit is picked only when no tool is picked (`if self.tool == nil`), with a scenario. See R10 for the comment.

**What's wrong.** A creature lookup can take up to five seconds (`UNIT_TRIES` half-second
looks). When it finds the display, `ShowUnit` sets `self.tool = "unit"` whatever is picked
then. Round 2's let-go runs only at the start of the lookup. If Mike types a unit ID and then
picks the patrol tool and clicks a pin, the lookup finishing swaps the pick to the unit. The
picked line follows (it calls `UpdatePalette`), but the pin he was about to draw for is
dropped without his doing anything. This was already so before the change (the line now at
least shows it).

**Fix.** Pick the found unit only if nothing else was picked since:
`if self.tool == nil then self.tool = "unit" end` before `UpdatePalette`. The portrait still
shows, and a click on it picks it.

### R10 · The found-unit comment says "while the game looked", but a tool picked before the lookup also stops the pick

- **Severity:** nit
- **Area:** Readability (a comment that says less than the code does)
- **Where:** `NeedRoll/UI/MapEdit.lua:1299-1301`
- **Status:** open (for Mike: either reading is fine; only the comment needs to match)

**What's wrong.**

```lua
-- Found it: picked to place, unless another tool was picked while
-- the game looked (a click on the portrait picks it then).
if self.tool == nil then self.tool = "unit" end
```

`LookUpUnit` lets go only of a picked *unit* at the start. If Entrance (or any other tool) was
picked *before* Enter was pressed, `self.tool` is still set when the unit is found, so the unit
isn't picked. That includes `d1234` display lookups, which find their unit at once. Before
round 3, pressing Enter always picked the unit.

**Why it matters.** It's a small workflow change the comment doesn't mention. Mike types an ID
with Entrance still picked, presses Enter, and the portrait appears unpicked. The palette's
help already says "Unit ID: Enter, then pick its portrait." (`MapEdit.lua:1060`), so the
documented steps still work, and the picked line shows the truth.

**Fix.** Either say so in the comment ("unless a tool is picked, before or during the
lookup"), or keep the old Enter-picks behaviour for anything picked before the lookup: note
`local toolAtLookup = self.tool` at the start, after the unit let-go, and pick when
`self.tool == toolAtLookup`.

## Round 2 re-check

Every function changed in round 2 was re-read in full: `T:OnEscape`, `LookUpUnit`,
`ShowBosses`, `Reset`, `LayOutBosses`, `UnitTitle`, `PickTitle`, the stand-in and the three
new scenarios. So were round 1's functions they touch (`Cancel`, `LetGo`, `UpdatePalette`,
`StopStroke`).

**R1, the delayed reset.**

- *Can it call `SetPropagateKeyboardInput` in combat?* No. The timer's callback checks
  `InCombatLockdown()` when it runs, not when the hide happened, so a hide just before combat
  starts is skipped, not blocked. The key handler and the set-up call are guarded too. Nothing
  else in the change calls it.
- *Can a skipped reset leave the frame stuck?* Yes, three ways:
  - The frame hides out of combat and combat starts before the next frame. The window is one
    frame; the frame is then hidden, so it only bites if it is shown again in combat before
    any key out of combat. Unlikely, inferred, accepted.
  - The frame doesn't hide at all after its Escape. This is the palette's Escape mid-drag:
    **R6**.
  - The frame was built in combat, so set-up never ran: **R8**.
- *Is one frame the right delay?* Yes. The handler turns passing off for this Escape, then
  `onEscape` hides the frame and `OnHide` runs in the same call. Switching it on right there
  would let the Escape that closed the menu also reach the game (open the game menu or shut
  the window). `C_Timer.After(0)` runs on the next frame, after the game has dealt with the
  key. Inferred from how the game reads the setting; the stand-in can't show key routing.
- *Can it race with the frame showing again?* Not in a harmful way. If the frame is hidden and
  shown again in the same frame, the timer later sets passing to `true` while it shows.
  `true` is the state the handler expects between keys, and it sets the value again on every
  key. Several hides make several timers that all set the same value. A timer firing after
  combat starts does nothing and the frame keeps its value. No timer can set `false`.
- *Is the stand-in true to the game?* Partly. The read-back and the `false` default match.
  It doesn't refuse the call in combat as the game does, which the file models for other
  restricted calls: **R7**. It also doesn't route keys by the setting (no stand-in does), so
  every "keys reach the game" assertion reads the flag, not the effect.
- The header comment, `T:OnEscape`'s set-up, and `HookScript`/`C_Timer.After` were checked
  against `forever` (`WidgetAPI.lua`: `HookScript`, `GetPropagateKeyboardInput`;
  `GlobalAPI.lua`: `C_Timer.After`).
- Settings' host does hide when Settings closes (`CreateHost` hooks the page's
  `Show`/`Hide`/`SetShown` and shows the host only while a page shows, `MainFrame.lua:561-590`),
  so its Escape reaches the new `OnHide` hook. The Wishlist menu and `T:Dialog` hide in their
  `onEscape`.

**R2, the new let-go paths.**

- `LookUpUnit` lets go only when `self.tool == "unit"`, and only after the input has parsed.
  A typo keeps the pick. A picked marker or another tool is left alone.
- `Reset` calls `LetGo` always. That also drops a placing tool (say, Entrance) that points
  into no copy. Harmless, and the comment gives the reason for the call. `Reset` returns
  before it in packaged builds, and `LetGo` is safe without a palette.
- `ShowBosses` lets go only of a `boss:` tool that none of this dungeon's boss buttons carries.
  The button list is per dungeon, not per level, so changing levels keeps the pick, and the
  pick is always among them while the dungeon stays. Hidden buttons now have `tool = nil`, so
  `PickTitle` and `ShowPicked` can't match a stale one.
- Not covered: a lookup finishing after another tool was picked (**R9**, pre-existing).

**R3, `GetStringHeight` before the font has loaded.**

- `GameFontHighlightSmall` is one of the game's own font objects (`forever` `Templates.lua`),
  ready from login, so the height is there synchronously. Only fonts an addon loads from a
  file can come late.
- At the first `LayOutBosses` (from `Palette()`) the window has no anchor yet (`Toggle`
  places it after), so the string's width may not be resolved. The help text breaks every
  line itself with `\n`, so the height is the 17 lines either way.
- `LayOutBosses` runs again from `ShowBosses` on every map refresh, by which time the window is
  placed. Inferred; the stand-in's `GetStringHeight` counts `\n` lines times the font size.

**R4.** `UnitTitle` is used at all three places; nothing else builds the name.

**R5, does the pan scenario test panning?** Yes.

- It zooms with the wheel (asserting `view.zoom > 1`), then drags with `DragOnMap`, which
  fires `OnDragStart` and advances frames so the canvas's own `OnUpdate` pans. It asserts
  `view.cx` changed with edit off and with Entrance picked, and that it didn't with
  `patrol-line` picked.
- A mutation that stops the pan (keeping `StartStroke`) fails it at "with dev edit off a drag
  didn't move the zoomed map".
- One limit: with `patrol-line` and no pin clicked, `StartStroke` returns at "click a boss or
  unit icon first". The no-pan case runs through that print branch, not a real stroke. The
  drawing scenario covers a real stroke.

## Round 3 re-check (last)

Re-read in full: `T:OnEscape` with `ListenForEscape`, `escapeFrames` and the two event handlers
(`Theme.lua:958-997`); `LookUpUnit`; the stand-in; the changed and new scenarios. Then the
whole group (`ae013b0..bc7ef01`) once more: every function round 1 listed under Scope.

**The combat rule, checked hard.**

- **Event registration.**
  - Both handlers go through `ns:On` (`Core/Init.lua:90-99`). It registers each event once on
    the addon's one event frame and appends the handler. `Core\Init.lua` loads from the `.toc`
    before `UI/UI.xml` loads `Theme.lua`, so `ns:On` exists when `Theme.lua` runs.
  - Only the two events used are registered. Both fire once per combat and loop over a list
    of about six frames. They stay registered for the session, which suits events that recur.
  - `MainFrame.lua:2422` already relies on the same "`PLAYER_REGEN_DISABLED` is the last moment
    before lockdown" rule (inferred from warcraft.wiki.gg's `InCombatLockdown` and
    `PLAYER_REGEN_DISABLED` pages).
  - If lockdown were somehow already on, the handler's `if InCombatLockdown() then return end`
    skips rather than making a blocked call.
  - `PLAYER_REGEN_ENABLED` fires after lockdown ends, so `ListenForEscape` there is allowed.
  - One shared-dispatcher caveat, which predates this change: an earlier handler of the same
    event that errors stops the rest. Theme's handlers are registered first (`Theme.lua` loads
    before `MainFrame.lua`), so they run first.
- **Frames garbage-collected or reused.**
  - WoW never frees a frame made with `CreateFrame`, so the strong references in `escapeFrames`
    keep nothing alive that wasn't already.
  - Every caller builds its frame once: the Settings host (`BuildSettingsPage` returns if
    built), the Wishlist menu and its three `T:Dialog`s (built once per pane,
    `Wishlist.lua:1087-1090`), the Discord dialog (once per Settings page), and the palette's
    `f.escape` (once). So the list is bounded, about six frames.
  - Calling `T:OnEscape` twice on one frame would list it twice. Harmless (same call twice) and
    no caller does it.
  - A future caller that makes a frame per open would grow the list for the session. Worth
    remembering, not a finding.
- **Frames built in combat.**
  - The frame gets its `OnKeyDown` but no keyboard, so it takes no keys and every key reaches
    the game (inferred: a new frame's keyboard is off by default, and the stand-in models that).
  - Escape won't close that Settings page, menu or dialog until combat ends; the game's own
    Escape handling still runs. That beats eating keys, as R8 asked.
  - On `PLAYER_REGEN_ENABLED` it is set up exactly as an out-of-combat frame. `/reload` in
    combat takes the same path.
- **Every remaining stuck path is closed.**
  - *Escape that hides the frame:* passing stays off while it is hidden, and it can only be
    shown again out of combat (the next key fixes it) or in combat after
    `PLAYER_REGEN_DISABLED` reset it.
  - *Escape that doesn't hide it (R6):* the same, reset as combat starts.
  - *Built in combat (R8):* no keyboard until combat ends.
  - The one-frame window from round 2 is gone along with the timer.
- **Out-of-combat behaviour for Settings, the Wishlist menu and `T:Dialog` is unchanged.**
  - Set-up is still `EnableKeyboard(true)` and `SetPropagateKeyboardInput(true)` (now after
    `SetScript`, which changes nothing), and the key handler is letter for letter the
    original.
  - Round 2's `OnHide` hook is gone, so nothing runs on their hides any more.
  - The only new effect is the reset to "pass all keys" when combat starts, which can only turn
    passing on.
  - In combat, Escape reaches the game as the original comment said, now reliably.
  - The existing Escape scenarios (`UI-MainFrame.lua:402`, `UI-Wishlist.lua:533-535`) pass.
  - The Settings key-binding box (`Settings.lua:366`), the only other `SetPropagateKeyboardInput`
    caller, is behind `BlockedByCombat()` (`Settings.lua:395`), so the stricter stand-in doesn't
    trip it, and its combat scenario passes.
- **The stand-in.** `SetPropagateKeyboardInput` now errors in combat, like the file's other
  restricted calls. `EnableKeyboard`/`IsKeyboardEnabled` read back, off by default. Neither
  routes keys between frames, so the scenarios check the flags, not the routing (said in round
  2, still true).
- **Mutation runs** on throw-away `git archive` copies, each caught:

  | Change | Failing scenario |
  | --- | --- |
  | No reset at `PLAYER_REGEN_DISABLED` | the MapEdit and Theme combat scenarios |
  | Key handler without its combat guard | the same two |
  | No combat queue (set up at once in combat) | "made in combat takes no keys" |
  | No set-up at `PLAYER_REGEN_ENABLED` | the same |

**API check.** `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED` are in `forever` `Events.lua`; `EnableKeyboard`, `IsKeyboardEnabled`, `SetPropagateKeyboardInput` and `GetPropagateKeyboardInput` in `WidgetAPI.lua`. `HookScript` and `C_Timer.After` are no longer used here.

**R9.** The scenario starts a lookup, picks Entrance before the model answers, and checks that
Entrance stays picked. The code matches; the comment is R10.

**Whole group, once more.**

- Nothing else changed since round 2. Round 1's notes hold:
  - the devexport and saved-copy formats are unchanged;
  - `--@debug@` and `Toggle`'s `available` check keep the palette out of releases, and the
    Overview hooks do nothing there;
  - the map's clicks and pans with edit off are unchanged, and a scenario now pins the pan;
  - `CreateOverview` still has 36 upvalues;
  - `STYLE-GUIDE.md` still matches the code (round 3 changed nothing visual).
- The new `Theme.lua` block adds two file-level locals and two event handlers, nothing global
  (luacheck counts unchanged).
- The new `UI-Theme.lua` test module passes luacheck clean.

## Area notes

### Readability

Checked every rule in `docs/READABLE-CODE.md` against each changed function, read in full.

- Names: `StartStroke`, `EndStroke`, `CancelStroke`, `LetGo`, `SetLinking`, `PickText`,
  `DrawForName`, `CursorOnCanvas`, `drawFor`, `stroke`, `putBack`, `pointCount` say what they
  are in the editor's terms. Constants are named with units in the comment (`STROKE_SPACING`,
  `CUE_OFFSET`, `PICKED_GOLD`, `FOOTER_HEIGHT`). `b` for a button follows the file's own use
  (`CreateToolButtons`, `ShowBosses`) and the table names it (`ipairs(f.tools)`).
- One job each: the stroke code is split into start, follow, end-at-cursor, end, cancel and
  stop; `UpdatePalette` does one thing (show the pick) through `ShowPicked` and `PickText`.
  `Palette()` is now 60 lines (`1038-1097`); moving the `f.escape` and `f.strokeDriver`
  set-up into the `CreatePickCue`-style helpers would keep it under a screen (not raised).
- Nesting stays at three levels or under; guard clauses throughout.
- Comments say why (`STROKE_SPACING`: "not one a frame"; `FollowCursor`: "stays shown, at no
  alpha, so this keeps running"; `T:OnEscape`: the combat rule). The file header and the
  `MapEdit` table comment list the new fields. No narration.
- Consistency: `T:JoinDots`, `T:SetTextColor`, `T:Fill`, `T:Border`, `ns.UI.CursorOnCanvas`
  are used rather than new copies; the three route shapes match `SetPatrol`, the area tool's
  `AddLoopPoints({ area = true }, ...)` and the outline tool's `AddLoopPoints({}, ...)`.
- Format: 4-space indents, LF, no tabs, all new Lua lines under 120 characters (the only
  longer added lines are Markdown table rows in `STYLE-GUIDE.md`). `local _, ns = ...` heads
  each file. No Lua 5.1 traps: `open = tool == "patrol-line" or nil` is the intended
  true-or-nil, `#route` is on arrays built with `table.insert` only, no patterns built from
  data.
- On the implementer's questions: click-then-drag is the better choice (the line names the pin
  the drag is for, so there's no guessing which pin is nearest); the drag starting a few
  pixels after the press puts the first point about 0.005 off the press on a 600-wide map,
  under one rounding step at zoom 2 and invisible in practice; `T:OnEscape` is justified by
  being the fourth copy (READABLE-CODE section 6); outline drawing is small and reuses the
  same stroke path, and "drop zones" in Mike's ask are the area tool, which is covered.

### WoW API

Everything the change adds or newly calls, checked in Ketho's `forever` lists
(`/tmp/claude-0/-home-claude/6531c47f-20fd-549b-aa37-eb1515ce9b9c/scratchpad/ketho/`):

| API | Kind | In `forever` | Where looked |
| --- | --- | --- | --- |
| `GetCursorPosition` | global function | yes | `GlobalAPI.lua` |
| `InCombatLockdown` | global function | yes | `GlobalAPI.lua` |
| `CreateFrame` | global function | yes | `GlobalAPI.lua` |
| `GetEffectiveScale`, `GetLeft`, `GetTop`, `GetWidth`, `GetHeight` | region methods | yes | `WidgetAPI.lua` |
| `SetFrameStrata`, `SetClampedToScreen`, `SetHeight`, `SetWidth`, `SetAlpha`, `ClearAllPoints`, `SetPoint` | frame/region methods | yes | `WidgetAPI.lua` |
| `IsVisible`, `IsMouseOver`, `IsShown`, `SetShown`, `Show`, `Hide`, `SetScript` (`OnUpdate`, `OnKeyDown`) | frame methods | yes | `WidgetAPI.lua` |
| `EnableKeyboard`, `SetPropagateKeyboardInput` | frame methods | yes | `WidgetAPI.lua` |
| `CreateFontString`, `CreateTexture`, `SetColorTexture`, `SetHighlightTexture` | frame/texture methods | yes | `WidgetAPI.lua` |
| `GetStringWidth`, `SetJustifyH`, `SetWordWrap`, `SetText`, `SetTextColor` | FontString methods | yes | `WidgetAPI.lua` |
| `GameFontNormalSmall`, `GameFontHighlightSmall` | font objects | yes | `Templates.lua` |
| `GameTooltip`, `GameTooltip_Hide` | FrameXML | yes | `Templates.lua`, `FrameXML.lua` |
| `PixelUtil` (via `T:Edge`) | FrameXML | yes | `FrameXML.lua` |
| `UIParent` | global frame | inferred (standard FrameXML global, in none of the lists) | — |
| `BasicFrameTemplateWithInset` (palette, unchanged) | template | yes | `Templates.lua` |

- No events are registered by the change; the two `OnUpdate`s run only while something is
  picked (`f.cue`) or a drag draws (`f.strokeDriver`), each hidden otherwise, and both have a
  reason in a comment.
- Secret values: the only outside text the cue and line show is `unit.name`, which comes
  from `ns.Names:CreatureName`, which returns nil for a secret (`Core/Names.lua:262-266`);
  `DrawForName` uses data names. `GetStringWidth` measures the addon's own text, not an
  inspect font. The secret-values smoke run passes.
- No new globals (`luacheck` counts unchanged); no secure frames or protected functions; R1
  covers the one combat-restricted call.
- No player-facing text: everything new is in the dev-only palette, so no `L[]`.
- `GetCursorPosition` is mirrored in `tests/smoke/wow.lua` (now driven by `W.cursorX`/`Y`,
  reset by the MapEdit `Snapshot`); the two new scenarios cover the feature (R5 for the gap).
- Dev-only paths stay out of releases: `MapEdit.available = true` sits in the
  `--@debug@`/`--@end-debug@` block (`MapEdit.lua:43-45`), which the packager comments out;
  `Toggle` returns at `if not self.available` so `Palette()` (and with it the cue, the
  Escape frame and the stroke driver) is never built in a release. The Overview hooks are
  inert there: `StartStroke` returns `false` (`self.on` is false), `EndStroke` returns at
  `if not stroke`, `Cancel` is reached only past `if button == "RightButton" and not
  ns.MapEdit.on then return end`, and `UpdatePalette` returns with no palette. The packaged
  smoke run passes. `MapEdit.lua` itself ships, as before.
- Map clicks and pans with edit off: `CursorOnCanvas` is the old inline maths moved
  unchanged (same canvas, same scale), the shift-click print uses its result, and the
  right-click-is-Back return comes before `Cancel`, so all are as before (by reading; see R5).
- `T:OnEscape` swap: the three handlers moved letter for letter (`self` in the old closures
  is the same frame the new closure names), so Settings, the Wishlist menu and `T:Dialog`
  behave exactly as before, including propagation and combat; the existing Escape scenarios
  (`UI-MainFrame.lua:402`, `UI-Wishlist.lua:533-535`) pass. R1 is a fault they all had.
- Upvalues: `ns.UI.CreateOverview` stays at 36 (`luac5.1 -l`, base and head); the change adds
  no upvalue to it (`CursorOnCanvas` is a field on `ns.UI`).
- `docs/STYLE-GUIDE.md` has the palette's values, checked against the code: 232 wide, 8 right
  of the window (`Toggle`), buttons 44/52/50 and 34/36, fill `3D6180` (0.24, 0.38, 0.5),
  gold `FFD100` (`PICKED_GOLD`), grey `999999` (`T.tip.quiet` 0.6), picked line at 14 and 42,
  cue 20 high, text 6 in, strip 12 wider, 16 offset, `TOOLTIP` strata, black at 75%.

### Redundant code

Compared against `T:Border`/`T:Edge`, `T:Fill`, `T:JoinDots`, `T:SetTextColor`, the
`^function T:` list in `Theme.lua`, `DevKit.GameWindow`, `MapEdit`'s own `RoundCoord`,
`IndexOf`, `Remove`, `AddLoopPoints`, `SetPatrol`, `Redraw`, `ShownMap`, and Overview's
map maths. The new code uses them. `T:OnEscape` removes three copies; `CursorOnCanvas`
removes the click handler's copy (the wheel and pan handlers compute against `clip` and a
start point, so they rightly stay their own). `T:Border`'s new return is used by
`PaletteButton`; its two other callers ignore it. No dead code: every new local and function
is called; `FewestPoints` is used once but names the rule. Per-frame work: `FollowStroke`
redraws only when a point was added; `FollowCursor` is a handful of calls a frame while a
pick exists. R4 is the one repeat left.

### Security

None of the change touches untrusted input or output: no addon messages, chat, network,
`loadstring`, or other players' data. The drawn routes go only into the local
`NeedRollDB.mapEdit` and `outlineEdit` copies and the `/nr devexport` text, in the same
shapes as before (patrol `{ open = true or nil, x1, y1, ... }`, area `{ area = true, ... }`,
outline `{ x1, y1, ... }`; every point through `RoundCoord`, so 0 to 1 at three decimals, and
the export's `%.3f` writes them back exactly, which the drawing scenario asserts against the
export text). The one name shown is a creature's, never a player's. No release path changes
(`.pkgmeta` untouched; the code is behind `--@debug@`).

## Round history

- 2026-10-18, `8aa637b`, round 1: **Changes needed**. Opened R1-R5 (2 should fix, 3 nits).
- 2026-10-18, `c26c178`, round 2: **Changes needed**. Closed R1-R5 (R1 for an Escape that hides the frame). Opened R6, R7 and R8 (should fix) and R9 (nit).
- 2026-10-18, `bc7ef01`, round 3 (last): **Ready**, one nit for Mike. Closed R6-R9. Opened R10 (nit).

## Integration

R10 (the found-unit comment) was reworded at integration. This group and the icon search (#610) both added to `UI/Theme.lua` and both created `tests/smoke/modules/UI-Theme.lua`; the two were merged by keeping both Theme blocks and joining the test files into one. Applied onto `dev` after #610 merged. On the result: `tests/smoke/check.sh` all passed (dev, packaged, secret), `tools/locales.py --check` passed, `luac5.1 -p` clean on every changed Lua file.
