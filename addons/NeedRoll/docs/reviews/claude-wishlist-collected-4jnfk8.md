# Review: Wishlist greys out owned items and leaves them out of runs and Overview facts

| | |
| --- | --- |
| Branch | `claude/wishlist-collected-4jnfk8` into `dev` (PR not opened yet) |
| Commit reviewed | `32c7b40` plus uncommitted changes (the whole change is uncommitted; round 2 reviewed the updated working tree) |
| Date | 2026-10-18 |
| Round | 2 |
| Verdict | **Ready** (0 blocking, 0 should fix; R10 fixed, R11 left as is) |
| Needs | `/reload`: Lua and the English locale changed; no `.toc`, SavedVariables or new file |

## What the change does

Before, the Wishlist only marked an item the character has with a tick in the
Details table's Owned column. Everything else (runs, the four Overview stat
boxes, the subtitle) counted it as still wanted. After, an owned item (worn,
in the bags or the bank, `WL:Owned`) is greyed out: icon desaturated, icon
edge in `line`, every text on the row in `faint`. `WL:Runs` skips owned items,
so they leave the left column, Best run and the run chances. Overview's right
column ends with an "Owned (N)" group holding every owned item (drops too).
The Wished box reads "N items · N owned", the subtitle adds "N owned", and
`BAG_UPDATE_DELAYED` and `PLAYER_EQUIPMENT_CHANGED` redraw the whole pane
(before, only Details on bag updates). Round 2: ownership is worked out once
per redraw (`WL:OwnedItems`) and passed to `WL:Runs`, Overview and Details;
the Wished box reads "N to get · N owned" when anything is owned; the
subtitle's drop count is the whole list's again.

## Scope

- `NeedRoll/Core/Wishlist.lua`: new `WL:OwnedItems(list)` (set and count); the run-building loop body moves
  to a local `AddToRuns`; `WL:Runs(list, isOwned)` skips owned items (round 1 used `NO_SOURCES`).
- `NeedRoll/UI/Wishlist.lua`: new `OwnedText`, `ShowOwned` (round 1: `CountOwned`, `GreyOut`, both gone);
  right column split into `GroupItemEntry` / `AddGroup` with an Owned group; `OtherEntries` takes the owned
  set and reports `hasOwnedDrop` for `RunEntries`' note; `UpdateOverview` and Details `page:Update` /
  `TableRowData` take the owned set; facts and subtitle show owned; Details rows set their colours on every
  setup; `RedrawOwned` on bag and equipment events.
- `NeedRoll/Locales/enUS.lua`: adds `%d owned`, `%d to get`, `You own every dungeon and raid drop on this list.`;
  moves `Owned` (key unchanged).
- `docs/STYLE-GUIDE.md`: new Wishlist section (owned rows, Wished fact).
- `tests/smoke/modules/Core-Wishlist.lua`: `WL:Runs` leaves an owned item out.
- `tests/smoke/modules/UI-Wishlist.lua`: three scenarios (greyed rows and facts, including un-owning on
  `BAG_UPDATE_DELAYED` and re-owning on `PLAYER_EQUIPMENT_CHANGED` on Overview and Details; the owned-drops
  notes; an owned item still loading).
- No generated data touched.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 5 changed Lua files | round 1 and round 2: passed |
| `python3 tools/locales.py --check` | round 1 and round 2: passed (exit 0) |
| `python3 tools/translations.py` | round 1 and round 2: exit 0; the same 50 "not used by NeedRoll any more" lines, none for a key this change touches (pre-existing) |
| `luacheck --no-global -q` changed vs `origin/dev` | round 1 and round 2: no new warnings (Core/Wishlist 12 = 12, UI/Wishlist 0 = 0, Core-Wishlist test 3 = 3, UI-Wishlist test 0 = 0) |
| `tests/smoke/check.sh` | round 2: all passed (184 files loaded), the three new Wishlist scenarios included |
| scraper unittest | not run: no scraper change |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Readability | `UI/Wishlist.lua:1160-1161` | Subtitle mixes a total item count with a not-owned drop count | fixed in round 2 (uncommitted) |
| R2 | should fix | Redundant code | `UI/Wishlist.lua`, `Core/Wishlist.lua:368` | Ownership asked of the game 4-5 times per item per redraw; `CountOwned` runs twice | fixed in round 2 (uncommitted) |
| R3 | should fix | Readability | `UI/Wishlist.lua:753-756` | "Nothing on this list drops in a dungeon or raid." shows beside owned drops | fixed in round 2 (uncommitted) |
| R4 | should fix | WoW API | `UI/Wishlist.lua:1167-1171` | Worn item sold or destroyed from the paper doll fires no bag update | fixed in round 2 (uncommitted) |
| R5 | should fix | WoW API (tests) | `tests/smoke/modules/UI-Wishlist.lua` | Overview redraw on bag events and Overview un-greying not asserted | fixed in round 2 (uncommitted) |
| R6 | nit | Readability | `UI/Wishlist.lua:85-87` | `GreyOut` comment says the icon edge turns faint | fixed in round 2 (uncommitted) |
| R7 | nit | Readability | `Core/Wishlist.lua:368` | `and NO_SOURCES or` hides a skip | fixed in round 2 (uncommitted) |
| R8 | nit | Readability | `UI/Wishlist.lua:74, 782` | `owned` is a number, a list and a flag | fixed in round 2 (uncommitted) |
| R9 | nit | Readability | `UI/Wishlist.lua:818` | Wished box "2 items · 2 owned" reads like "2 of 2 owned" | fixed in round 2 (uncommitted) |
| R10 | nit | Readability | `UI/Wishlist.lua:78, 754, 762` vs `771, 799, 1000, 1062` | `isOwned` is a yes/no in three functions and an item set in four others | fixed (renamed the flag to `isOwnedRow` / `isOwnedGroup`) |
| R11 | nit | Redundant code | `UI/Wishlist.lua:1162-1166` | One equip from the bags redraws the pane twice; a gear-set swap once per slot | left as is: a second redraw of one pane on equip is cheap; merging needs a timer |

### R1 · Subtitle mixes a total item count with a not-owned drop count

- **Severity:** should fix
- **Area:** Readability (consistency, disinformation)
- **Where:** `NeedRoll/UI/Wishlist.lua:1160-1161`
- **Status:** fixed in round 2 (uncommitted): the subtitle calls `CountDrops(list.items)` again and the `leaveOutOwned` parameter is gone; the test now expects `4 items  ·  2 owned  ·  2 from dungeons and raids`, and `STYLE-GUIDE.md` says the drop count is the whole list's.

**What's wrong.**

```lua
self.subtitle:SetText(isEmpty and "" or Theme:JoinDots(list.note, ItemCountText(count),
    OwnedText(CountOwned(list.items)), L["%d from dungeons and raids"]:format(CountDrops(list.items, true))))
```

`count` is every item on the list, but `CountDrops(..., true)` leaves owned
items out. The two numbers sit side by side as if one were part of the other.

**Why it matters.** The smoke scenario shows it: a list of 2 drops, a crafted
item and a quest reward with one drop owned reads "4 items · 2 owned · 1 from
dungeons and raids", though 2 of the 4 drop. The subtitle shows on both pages;
on Details the same list's chip reads "Drop 2" right under it (chips count
owned items), so the header contradicts the filter bar. The task asked for
"total plus N owned" in the subtitle; leaving owned out was asked of the
Overview facts, which already do it.

**Evidence.** Lines read; `tests/smoke/modules/UI-Wishlist.lua:337` asserts
exactly `"4 items  ·  2 owned  ·  1 from dungeons and raids"`; `CreateChips`
`bar:Set` counts come from every row of the list.

**Fix.** Keep the subtitle describing the whole list: call `CountDrops(list.items)`
and drop the `leaveOutOwned` parameter (its only `true` caller is this line;
the Import preview at `:329` calls it without). Less code, and the Overview
facts stay the not-owned view. Update the test string to `2 from dungeons and raids`.

### R2 · Ownership asked of the game 4-5 times per item per redraw; `CountOwned` runs twice

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Wishlist.lua:66` (`CountDrops`), `:75` (`CountOwned`), `:784` (`OtherEntries`),
  `:810` (`UpdateOverview` calls `CountOwned` again), `:1161` (subtitle calls `CountOwned`), `:1026`
  (`TableRowData`); `NeedRoll/Core/Wishlist.lua:368` (`WL:Runs`)
- **Status:** fixed in round 2 (uncommitted): `WL:OwnedItems(list)` (`Core/Wishlist.lua:362`) runs once in `pane:Update` and its set and count go to the subtitle, `UpdateOverview`, `WL:Runs(list, isOwned)`, `OtherEntries` and Details `TableRowData`. `CountOwned` is gone. One pass of `WL:Owned` per item per redraw.

**What's wrong.** Each `WL:Owned` is two game calls (`C_Item.IsEquippedItem`,
`C_Item.GetItemCount(itemID, true)`). One `pane:Update` on Overview asks it of
every item in the subtitle's `CountOwned`, the subtitle's `CountDrops`,
`WL:Runs`, `UpdateOverview`'s own `CountOwned`, and `OtherEntries`: five
passes, two of them the identical `CountOwned(list.items)`.

**Why it matters.** The handler now runs the whole redraw on every
`BAG_UPDATE_DELAYED` while the tab is open (looting, vendoring, moving a stack),
so this cost repeats often. More to the point for a reader, "is it owned" is
decided in five places instead of once, so a later change to one (say, ignore
the bank) has to find all five.

**Evidence.** Lines read; grep `WL:Owned\|:Owned(` lists the call sites above.
Cost per call is inference; correctness is not affected today.

**Fix.** Work out ownership once per redraw and pass it down, for example a
`WL:OwnedItems(list)` returning `{ [itemID] = true }` (or an optional
`isOwned` set argument to `WL:Runs`), computed at the top of `pane:Update`, then
`ownedCount` from it for the subtitle and `UpdateOverview`, and the same set to
`OtherEntries`. At the least, compute `CountOwned` once in `pane:Update` and
hand it to `UpdateOverview`.

### R3 · "Nothing on this list drops in a dungeon or raid." shows beside owned drops

- **Severity:** should fix
- **Area:** Readability (empty state says something untrue)
- **Where:** `NeedRoll/UI/Wishlist.lua:753-756`, chosen by `ownedCount == #list.items` at `:811`
- **Status:** fixed in round 2 (uncommitted): `OtherEntries` reports `hasOwnedDrop`, and `RunEntries` shows `You own every dungeon and raid drop on this list.` when there are no runs and any owned item is a drop; scenario "Overview's notes say when the drops are owned" covers mixed, all-owned and owned-craft-only lists.

**What's wrong.**

```lua
text = isAllOwned and L["You own everything on this list."]
    or L["Nothing on this list drops in a dungeon or raid."] })
```

The note only switches when every item is owned. With some items owned and
the rest not drops, the runs list is empty for a different reason.

**Why it matters.** List: one owned Deadmines drop plus one quest reward not
owned. Left column: "Nothing on this list drops in a dungeon or raid." Right
column: "Quest rewards (1)", then "Owned (1)" with the drop's row reading
"Chest · Edwin VanCleef · The Deadmines". The note contradicts the row next to it.

**Evidence.** Traced `RunEntries` / `OtherEntries` by hand for that list; not
covered by a scenario.

**Fix.** Pick the note by why there are no runs: when any owned item is a
drop, say the drops are owned (for example `L["You own every dungeon and raid drop on this list."]`),
otherwise the existing text. `RunEntries` can take `hasOwnedDrop` instead of
`isAllOwned` (computed while counting owned items, see R2). Add a scenario for
the mixed list.

### R4 · Comment says bag updates cover worn gear; an equipped item removed from the paper doll fires none

- **Severity:** should fix
- **Area:** WoW API (event coverage; comment disinformation)
- **Where:** `NeedRoll/UI/Wishlist.lua:1167-1171`
- **Status:** fixed in round 2 (uncommitted): shared `RedrawOwned` registered for `BAG_UPDATE_DELAYED` and `PLAYER_EQUIPMENT_CHANGED` (`UI/Wishlist.lua:1162-1166`), comment reworded; the scenario fires `PLAYER_EQUIPMENT_CHANGED` and asserts the redraw.

**What's wrong.**

```lua
-- What's owned follows the bags. Putting gear on or taking it off moves it out of or into
-- the bags, so this fires for worn items too.
ns:On("BAG_UPDATE_DELAYED", function()
```

Equipping from or unequipping to the bags does change a bag. Selling a worn
item by dragging it from the character pane to a merchant, or destroying it
from the paper doll, changes no bag; only `PLAYER_EQUIPMENT_CHANGED` fires.

**Why it matters.** The player sells or deletes a worn wishlist piece with
NeedRoll open; it stays greyed and out of the runs until some unrelated bag
change. With greying now driving Best run and the facts, the stale state is
more visible than the old tick was.

**Evidence.** `PLAYER_EQUIPMENT_CHANGED` and `BAG_UPDATE_DELAYED` both in the
`forever` `Events.lua` (lines 1383, 520 of the downloaded file). The
no-bag-update case is game behaviour by inference (no bag slot changes).

**Fix.** Register the same redraw for `PLAYER_EQUIPMENT_CHANGED` (one shared
local function, two `ns:On` calls) and reword the comment to say why both:
bags and bank change through bag updates, worn gear through equipment changes.
Mirror the event in a smoke scenario (`W.Event("PLAYER_EQUIPMENT_CHANGED")`).

### R5 · The Overview redraw on `BAG_UPDATE_DELAYED` and Overview un-greying aren't asserted

- **Severity:** should fix
- **Area:** WoW API (tests for the fix)
- **Where:** `tests/smoke/modules/UI-Wishlist.lua:330-381`
- **Status:** fixed in round 2 (uncommitted): the first scenario now un-owns on `BAG_UPDATE_DELAYED` while Overview shows and asserts Wished, the runs, the right-column labels and every Overview row's icon, name and sub colour (`CheckOverviewRows`), then re-owns on `PLAYER_EQUIPMENT_CHANGED`; a new scenario covers an owned item whose name is still loading, before and after `ITEM_DATA_LOAD_RESULT`.

**What's wrong.** The behaviour this change adds to the bag handler is
redrawing Overview (it used to redraw Details only). The new scenario fires
`BAG_UPDATE_DELAYED` only after switching to Details (`:365`, `:375`), which
the old handler already covered (see "owned ticks follow the bags" at
`:320-328`). Nothing checks that Overview's facts, runs and right column move
when an item is gained or lost, or that a recycled Overview row (`row.sub`,
`row.right`, the border) goes back to its normal colours. The Loading path
(owned item whose name isn't cached) isn't covered either.

**Why it matters.** Reverting the handler to `pane.details:IsShown()` would
still pass every test, and so would dropping the `Theme:SetTextColor(row.sub,
Theme.color.muted)` reset at `:627` (it only bites when a row is reused).

**Evidence.** Read both new scenarios in full; the asserts on Overview run
once, before any event.

**Fix.** In the first scenario, before switching to Details: set
`isOwned = {}`, fire `BAG_UPDATE_DELAYED`, assert the Wished box reads
"4 items", the runs hold both drops, the right column has no "Owned" label,
and every shown Overview item row has `not row.icon:IsDesaturated()` and
`row.sub` back in `muted`. Optionally one assert with
`C_Item.GetItemNameByID` returning nil for an owned item, then the
`ITEM_DATA_LOAD_RESULT` path, checking the row ends desaturated.

### R6 · `GreyOut` comment says the icon edge turns faint

- **Severity:** nit
- **Area:** Readability (disinformation)
- **Where:** `NeedRoll/UI/Wishlist.lua:85-87`
- **Status:** fixed in round 2 (uncommitted): renamed `ShowOwned`, comment now "icon desaturated, edge in `line`, each of `texts` in `faint`" and says the caller resets text colours.

**What's wrong.** "its name, icon edge and `texts` turn faint" — the edge is
set to `Theme.color.line`, not `faint`, and the name is one of `texts` (the
function never touches `row.name` by itself). The function also un-desaturates
a row that isn't owned, which its name hides.

**Fix.** "An owned item stays listed but greys out: icon desaturated, edge in
`line`, each of `texts` in `faint`. Rows are reused, so the icon is set either
way and the caller resets text colours before this." Consider
`ShowOwned(row, isOwned, texts)` as the name.

### R7 · `and NO_SOURCES or` hides a skip behind iterating an empty table

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/Core/Wishlist.lua:368`
- **Status:** fixed in round 2 (uncommitted): `WL:Runs` reads `if not isOwned[entry.itemID] then AddToRuns(runByInstance, runs, entry) end`, with the run building in a local `AddToRuns`.

**What's wrong.** `local sources = self:Owned(entry.itemID) and NO_SOURCES or self:Sources(entry.itemID)`
makes "skip owned items" read like a choice of source list. It's correct (a
table is truthy, so not the `and nil or` trap), but a reader has to work out
that an empty loop is the skip.

**Fix.** If R2 adds an owned set, the loop can begin with
`if not isOwned[entry.itemID] then` around the existing body, or the item loop
can call a small `AddToRuns(entry)` that starts with a guard
`if self:Owned(entry.itemID) then return end`.

### R8 · `owned` is a number, a list and a flag in neighbouring functions

- **Severity:** nit
- **Area:** Readability (names)
- **Where:** `NeedRoll/UI/Wishlist.lua:74` (`local owned = 0`), `:782` (`owned = {}` list of entries),
  `data.owned` / `row.owned` (flag / tick texture)
- **Status:** fixed in round 2 (uncommitted): `CountOwned` is gone; the list is `ownedEntries`. (A related reuse of `isOwned` is R10.)

**Fix.** `ownedCount` in `CountOwned`, `ownedEntries` in `OtherEntries`.

### R9 · Wished box "2 items · 2 owned" reads like "2 of 2 owned"

- **Severity:** nit
- **Area:** Readability (player-facing wording)
- **Where:** `NeedRoll/UI/Wishlist.lua:818`
- **Status:** fixed in round 2 (uncommitted): Wished shows "N items" with nothing owned, else `L["%d to get"]` then "N owned" ("2 to get  ·  2 owned"); `STYLE-GUIDE.md` row updated.

**What's wrong.** The box shows items still to get, then owned; the subtitle
above shows the same "N items · N owned" shape with the total. With all owned it
reads "0 items · 2 owned". A player can't tell which count is the total.

**Fix.** Optional: a phrase that says what the first number is, such as
`L["%d to get"]`, or leave the Wished box at the list total and let Owned show
in the subtitle only. Mike's call; update `docs/STYLE-GUIDE.md:258` with it.

### R10 · `isOwned` is a yes/no in three functions and an item set in four others

- **Severity:** nit
- **Area:** Readability (names, mental mapping)
- **Where:** a boolean in `ShowOwned(row, isOwned, texts)` (`NeedRoll/UI/Wishlist.lua:78`),
  `GroupItemEntry(entry, isOwned)` (`:754`), `AddGroup(entries, label, groupItems, isOwned)` (`:762`); an
  `{ [itemID] = true }` set in `OtherEntries(items, isOwned)` (`:771`), `UpdateOverview` (`:799`),
  `TableRowData(entry, kind, isOwned)` (`:1000`), `page:Update(list, keep, isOwned)` (`:1062`) and
  `WL:Runs(list, isOwned)`
- **Status:** fixed: renamed to `isOwnedRow` and `isOwnedGroup`.

**What's wrong.** `OtherEntries` receives `isOwned` as a set and, a few lines
later, calls `AddGroup(..., true)` whose `isOwned` is a flag that is passed to
`GroupItemEntry` as a flag again. The set-named-`is` style itself is the
addon's (`isMember[`, `isListed[` elsewhere); the problem is one name meaning
two types in neighbouring functions of the same file.

**Why it matters.** A reader following `AddGroup(entries, L["Owned"], ownedEntries, true)`
into `GroupItemEntry` has to check whether `isOwned` is indexed or tested. No
bug today (inference: every call passes the right type, smoke passes).

**Fix.** Keep `isOwned` for the set and call the flag what it says:
`isOwnedGroup` in `AddGroup` / `GroupItemEntry`, `isItemOwned` in `ShowOwned`
(or the reverse: `ownedItemIDs` for the set).

### R11 · One equip from the bags redraws the pane twice; a gear-set swap once per slot

- **Severity:** nit
- **Area:** Redundant code (repeated work)
- **Where:** `NeedRoll/UI/Wishlist.lua:1162-1166`
- **Status:** left as is: the second redraw of one pane is cheap, and merging needs a timer.

**What's wrong.**

```lua
local function RedrawOwned()
    if pane:IsVisible() then pane:Update() end
end
ns:On("BAG_UPDATE_DELAYED", RedrawOwned)
ns:On("PLAYER_EQUIPMENT_CHANGED", RedrawOwned)
```

Equipping a piece from the bags fires both events, so the whole pane (owned
set, runs, sorting, both columns or the table, the menu) is rebuilt twice.
`PLAYER_EQUIPMENT_CHANGED` fires once per slot, so a gear-set addon swapping
ten slots rebuilds it about ten times in one frame.

**Why it matters.** Only while the Wishlist tab is open, and a redraw of a
typical list is cheap, so no player-visible hitch is expected (inference, not
measured). It is work done several times for one change of state.

**Evidence.** Lines read; per-slot firing of `PLAYER_EQUIPMENT_CHANGED`
(its payload is `equipmentSlot, hasCurrent`) is game behaviour by inference
from the event's arguments, as the scenario fires it with `5, true`.

**Fix.** Optional: coalesce into one redraw next frame, as `MainFrame.lua:1035`
does with `C_Timer.After(0, ...)`:

```lua
local isRedrawQueued = false
local function RedrawOwned()
    if isRedrawQueued or not pane:IsVisible() then return end
    isRedrawQueued = true
    C_Timer.After(0, function()
        isRedrawQueued = false
        if pane:IsVisible() then pane:Update() end
    end)
end
```

The smoke scenarios would then need the stand-in's timer run before their asserts.

## Area notes

### Readability

Round 2 re-read every changed function in full (`OwnedText`, `ShowOwned`,
`SetupOverviewRow`, `RunEntries`, `GroupItemEntry`, `AddGroup`,
`OtherEntries`, `UpdateOverview`, `SetupTableRow`, `CreateTableRow`,
`TableRowData`, Details `page:Update` and its header and chip callbacks,
`pane:Update`, `RedrawOwned`, `WL:OwnedItems`, `AddToRuns`, `WL:Runs`) against
`docs/READABLE-CODE.md`. Round 2 specifics: `OtherEntries` now files by
`WL:Kind(...) ~= "Drop"` instead of "not in a run"; for items not owned the
two are the same set (an item joins a run exactly when it has a Drop source),
so no item moves column. Every caller of Details `page:Update` passes the owned
set (`:1046`, `:1072`, `:1076`, `:1156`; grep found no other), so
`TableRowData` never indexes nil; the stored `page.isOwned` used by sort and
filter clicks is refreshed by every bag or equipment event while the tab is
open, and by MainFrame's `UI.wishlist:Update()` when the tab opens
(`MainFrame.lua:1813`). `AddToRuns` stays at three levels inside the
function. `isOwned or self:OwnedItems(list)` keeps only the set (the `or`
drops the second return), as intended. Round 1 notes: Sound: splitting the old nested group loop into
`GroupItemEntry` / `AddGroup` removes a 4-level block; booleans are named as
questions (`hasOwnedDrop`, `isOwned`); no line over 120 in the
changed lines (the only one, `Core/Wishlist.lua:231`, is old); 4-space
indents; no change narration. The file header comment was updated to describe
the Owned group. The right column now takes `BestSource` instead of
`Sources[1]`; for non-drops that is the same source, so other groups look the
same, and owned drops get their likeliest place. No Lua 5.1 traps: `OwnedText` returns `nil` only into `JoinDots`, which drops
it, and the Wished line's `ownedCount == 0 and ItemCountText(...) or ...` has a
non-empty string in the middle.

Recycled rows: Overview resets `row.name`/edge (`Theme:SetRowItem`),
`row.right` and now `row.sub` before `ShowOwned`; Details now
resets slot, where and chance per setup and source already was.
`row.icon:SetDesaturated(isOwned == true)` runs for every item row, so the icon
always resets. Non-item Overview rows hide the icon, so a stale desaturation
there is invisible and is reset when the row next shows an item. Loading
path: `Theme:SetRowItem` already paints a loading row `faint`/`line`, `ShowOwned`
then desaturates, and the redraw callback re-runs the whole setup when the
name arrives. Sound, and asserted since round 2 ("an owned item still loading
ends greyed out"). The `small` font's default colour is `muted`
(`Theme.lua:241, 261`), so the new explicit `muted` resets change no pixel
for rows that aren't owned.

### WoW API

| Call / event / method | In `forever` lists | Where looked |
| --- | --- | --- |
| `Texture:SetDesaturated` | yes | `WidgetAPI.lua` (TextureBase methods, line 262) |
| `Texture:IsDesaturated` (tests only) | yes | `WidgetAPI.lua` line 255; mirrored in `tests/smoke/wow.lua:434` |
| `BAG_UPDATE_DELAYED` (now redraws the pane) | yes | `Events.lua` line 520 |
| `PLAYER_EQUIPMENT_CHANGED` (registered in round 2) | yes | `Events.lua` line 1383; fired by the stand-in through the generic `W.Event` |
| `ITEM_DATA_LOAD_RESULT` (tests only, existing `ns.Items:Load` path) | yes (existing) | used by the existing "a name still loading" scenario |
| `C_Item.IsEquippedItem`, `C_Item.GetItemCount` (existing, via `WL:Owned`) | yes | `GlobalAPI.lua` lines 2566, 2511 |
| `C_Item.GetItemNameByID`, `C_Item.GetItemIconByID` (existing, via `Theme:SetRowItem`) | yes | `GlobalAPI.lua` lines 2535, 2521 |

Both handlers stay registered for the pane's life, as the old bag handler
did (not one-shot events), and do nothing while the tab is hidden. No new globals, no removed nil guards, no secret values involved (item IDs
and counts only), no protected frames or combat-sensitive calls, the change
adds no locals to `CreateOverview`'s upvalue count (different file). All new
player text is literal `L["..."]` and `locales.py --check` passes; the moved
`L["Owned"]` keeps its key. `docs/STYLE-GUIDE.md` has the new section with
values matching `Theme.lua:48, 53, 121, 126`. No dev-only code.

### Redundant code

Compared against `Theme:SetRowItem` (loading look), `Theme:SetTextColor`,
`Theme:JoinDots`, `Theme:Plural`, `Theme:QualityIcon`/`SetBorderColor`, and the
greying done elsewhere (`LootGrid.lua:1301` known-recipe tick,
`Lists.lua:1897` mini pins): no shared "grey out a row" helper exists, so
`ShowOwned` doesn't duplicate one. Round 2 removed `CountOwned` and the
`leaveOutOwned` parameter; `WL:OwnedItems` is the one place ownership of a list
is worked out, and `WL:Owned` the one place an item's is. Repeated redraws on
equipment swaps are R11. `AddGroup` and `GroupItemEntry` replace the
inline loop rather than copying it. The redundant ownership work is R2; the
`leaveOutOwned` parameter becomes dead if R1 is taken.

### Security

None: the change reads only the local character's bags and equipment and
renders the player's own list. No addon messages, chat, SavedVariables format
or shipped file touched.

## Round history

- Round 1, 2026-10-18, `32c7b40` + uncommitted: Changes needed. Opened R1-R9.
- Round 2, 2026-10-18, `32c7b40` + uncommitted (updated): Ready. Closed R1-R9; opened R10 and R11 (nits, optional).
- Round 2 follow-up, 2026-10-18: R10 fixed by renaming the flag (`isOwnedRow`, `isOwnedGroup`); R11 left as is (a double redraw on equip is cheap).
