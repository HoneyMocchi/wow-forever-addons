# Review: Readability pass, MapEdit group (`/nr devedit` editor and `/nr devexport`)

| | |
| --- | --- |
| Branch | `rp-mapedit` worktree, one group of `claude/addon-readability-pass-rg51s6`; base `c0e5c79` |
| Commit reviewed | `c0e5c79` plus uncommitted changes (`NeedRoll/UI/MapEdit.lua` modified, `tests/smoke/modules/UI-MapEdit.lua` new); round 2 on the implementer's uncommitted fixes (MapEdit.lua 1248 lines, test file 516) |
| Date | 2026-10-17 |
| Round | 2 |
| Verdict | **Ready** (0 blocking, 0 should fix, 0 open; R13 fixed after round 2, R12 left for the shared-helpers PR) |
| Needs | `/reload` (one Lua file changed, no `.toc` change). Everything changed is dev-only: `MapEdit.available` is set only inside `--@debug@`, so release zips are unaffected |

## What the change does

A readability rewrite of `NeedRoll/UI/MapEdit.lua`, the dev-only map editor
(`/nr devedit`: drag boss pins, swirls, level links, quest markers, patrols,
areas and outlines on the dungeon map, mark quests as starting inside) and
`/nr devexport` (Lua text Mike pastes into `Data/Maps.lua`, `Data/Outlines.lua`,
`Data/QuestStarts.lua` and `tools/outlines_master.lua`). For Mike nothing
changes on screen or in the export. One fix: a creature name that the game
hands back as a secret value (WoW: Forever) is no longer stored on a placed
unit pin or written into the export. The code gets there by:

- splitting `Spots`' merge into `MergePins` / `CopyNewPatrols`, `Click`'s
  removal into `RemoveSpot`, `Place`'s pin moves into `MovePin`;
- one `AddLoopPoints` for the three copies of the eight-point starter loop,
  `NextInList` for the two "next icon" loops, one `PaletteButton` for the four
  copies of the palette button, `DevWindow` for the two dev windows, tables
  (`TOOLS[].title`, `TOOL_HELP`, `MAP_CLICK_HINTS`) for the long `or` chains;
- the 140-line `MapEdit:Text()` split into one function per export section
  (`MapSpotLines`, `OutlineLines`, `ZoneQuestLines`, `QuestStartLines`) built
  on `JoinAsText` and `AddSection`;
- dropping the `MenuUtil`, `C_TooltipInfo`, `model.GetDisplayInfo`,
  `ns.Search.Forget` and `ns.FontDebug` existence fallbacks.

Lines (`wc -l` and my own count): 1258 -> 1257 total; code 1078 -> 1016,
comment lines 125 -> 159, blank 55 -> 82 (the hand-back's 1110 -> 1037 /
93 -> 138 counts differently; both show code down, comments up).

## Scope

- `NeedRoll/UI/MapEdit.lua`: the rewrite above; read in full, old (`git show HEAD:`) and new side by side.
- `tests/smoke/modules/UI-MapEdit.lua` (new, 487 lines): ten dev-only scenarios: golden export text, export window, `Spots` copy and merge, palette, placing every tool, right-clicks/patrols/marker links, dragging, quest marks and zone quests, unit lookup and language preview.
- Read for context, not changed: `NeedRoll/UI/FrameDebug.lua:319-654` (`ns.FontDebug`, inside `--@debug@`), `NeedRoll/UI/UI.xml`, `NeedRoll/UI/Search.lua:8,122`, `NeedRoll/Core/Names.lua:236-262`, `NeedRoll/Data/Data.lua:511-523`, `NeedRoll/Data/Maps.lua:613,631,711`, `tests/smoke/run.lua`, `tests/smoke/wow.lua`, `tests/smoke/scenarios.lua:1077-1165`, `.pkgmeta`, `.luarc.json`.
- No generated files touched.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` MapEdit.lua and the test file | passed |
| `luacheck --std lua51 -q --codes` W11 globals, before vs after | one name gained: `issecretvalue` (the new secret check). It is a real game global (`GlobalAPI.lua` forever, line 6874), not a local used before its declaration, so accepted. Names lost: none (counts of `C_TooltipInfo`, `CreateFrame`, `GameTooltip`, `MenuUtil`, `UIParent` dropped) |
| `luacheck --no-global -q` before vs after | before 19 warnings (8 long lines, unused/shadowed `self`, unused `inst`/`map`); after 1: `MapEdit.lua:1217:17 unused argument 'self'` in `MapEdit:Text()`, present before too and needed for the public `:` method. Test file: 0 |
| `tests/smoke/check.sh` | passed in all three modes (dev 183 files, packaged 178, dev + secret values), about 66 s |
| Module tests against the **old** MapEdit.lua (scratch copy of `HEAD` plus the new test file) | dev: all ten pass, so the golden text was pinned against the old code. Secret mode: only `unit lookup and language preview` fails at `UI-MapEdit.lua:471` ("the unit's name label is wrong"), which is the bug the change fixes |
| Mutation runs of the golden test (scratch copy) | four export changes pass unnoticed, see R2; removing `MoveMarkersOn`'s move passes the whole dev run, see R3 |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | passed (exit 0), wrote nothing |
| Scraper unit tests | not run: no scraper change |
| **Round 2:** `luac5.1 -p` both files | passed |
| **Round 2:** W11 globals vs `HEAD` | gained `issecretvalue` (as round 1) and `CopyTable` (R4; FrameXML forever `:1135`, stand-in `wow.lua:111`). Both real game globals, not locals used early. Lost none |
| **Round 2:** `luacheck --no-global` | 1 warning, the same unused `self` in `MapEdit:Text()` (`:1208`); test file 0 |
| **Round 2:** `tests/smoke/check.sh` | passed, all three modes (dev 183 files, packaged 178, secret) |
| **Round 2:** new tests on the old MapEdit.lua | dev: all ten pass (the extended golden text matches the old code too). Secret: only `unit lookup` fails (`:502`), the fixed bug |
| **Round 2:** restore after a failure | in that failing secret run on old code, a scratch scenario added after the module checked: edit mode off, palette hidden, `W.alt`/`W.shift` nil, no `ZZ_TEST` in `mapEdit`, `unit`/`tool` nil, no `ZZ_DATA` data outline. It passed |
| **Round 2:** mutations | patrol after npc, reverse outline level order, `; ` between shapes, `on` before `boss`, string sort of level keys: each fails the golden test. Removing `MoveMarkersOn`'s move fails the drag test. The unmutated file passes |
| **Round 2:** `locales.py --check`, `translations.py` | passed, exit 0; nothing written |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | blocking | WoW API (smoke tests) | `tests/smoke/modules/UI-MapEdit.lua` (every scenario; 155-158, 226-229, 298, 369-375, 390-393, 459) | Tests don't restore what they change when they fail, and some not even when they pass | fixed in round 2 (uncommitted) |
| R2 | should fix | WoW API (smoke tests) | `tests/smoke/modules/UI-MapEdit.lua:55-136` | Golden export misses combinations: four export changes pass it | fixed in round 2 (uncommitted) |
| R3 | should fix | WoW API (smoke tests) | `MapEdit.lua:302-309`, test `:403-419` | `MoveMarkersOn` (newly extracted) has no test | fixed in round 2 (uncommitted) |
| R4 | should fix | Redundant code | `MapEdit.lua:122-127` | `DeepCopy` duplicates the game's `CopyTable` | fixed in round 2 (uncommitted) |
| R5 | should fix | Readability | `MapEdit.lua:49,51,234,545,720,940,1084,1131,1186,1196` | Comments that restate the name or the line below; comment lines up 34 | fixed in round 2 (uncommitted); one header kept, see R5 |
| R6 | should fix | Readability | `MapEdit.lua:466-475, 509-510, 514-516` | `MovePin` silently creates `spots.pins[level]`, and `Place` depends on it | fixed in round 2 (uncommitted) |
| R7 | nit | Redundant code | `MapEdit.lua:1095-1105` | `SpotText` duplicates `SpotWithIconText` | fixed in round 2 (uncommitted) |
| R8 | nit | Readability | `MapEdit.lua:130` | Local `Round` shadows the game's global `Round` with a different meaning | fixed in round 2 (uncommitted) |
| R9 | nit | Readability | `MapEdit.lua:380, 416-417` | Two clever one-liners where plain `if`s read better | fixed in round 2 (uncommitted) |
| R10 | nit | Readability | `MapEdit.lua:114, 672, 726` | Tools per row `4` written three times; `PickTool` also unpicks | fixed in round 2 (uncommitted) |
| R11 | nit | Readability | `MapEdit.lua:22-24` | Header says zoneEdit and outlineEdit are keyed like questEdit; they aren't | fixed in round 2 (uncommitted) |
| R12 | nit | Redundant code | `MapEdit.lua:983-988` vs `Core/Names.lua:243-262`, core group's `ns.IsSecret` | Creature-name lookup and secret check duplicate Core/Names.lua | cross-module: left for integration |
| R13 | nit | Redundant code | `MapEdit.lua:505-506, 512-513` | The "make this level's pin list" pair is written twice in `Place` | fixed after round 2 (`LevelPins`) |

### R1 · Tests don't restore what they change when they fail, and some not even when they pass

- **Severity:** blocking
- **Area:** WoW API (smoke tests)
- **Where:** `tests/smoke/modules/UI-MapEdit.lua`: every scenario's `SetEditsAside` ... `PutEditsBack`; `:155-158`; `:226-229`; `:298`; `:369-375`; `:390-393`; `:405/416`; `:457-485`; `OpenDeadminesMap` `:33` with `CloseEditMode` only at the end
- **Status:** fixed in round 2 (uncommitted): every scenario goes through `Scenario` -> `Restoring(test, Snapshot(W, ns))` (`UI-MapEdit.lua:9-58`); the snapshot puts back the six edit tables, `on/tool/linking/unit/language`, `lastQuest` (scenarios work on a copy), `FontDebug.Text`, the COOKIE patrol, `model._display`, the two test data outlines, `W.alt`/`W.shift`, and hides the export window and palette. Checked by a failing run, see round 2 notes

**What's wrong.** Each scenario saves the edit tables, changes state, runs
`assert`s and only then puts things back on its last lines:

```lua
local kept = SetEditsAside(ns)
...
assert(...)          -- a failure here leaves everything below undone
PutEditsBack(ns, kept)
CloseEditMode(ns)
```

On a failure (or a Lua error in MapEdit) these stay changed for the rest of
the run:

- `ns.db.mapEdit/questEdit/zoneEdit/outlineEdit/fontEdit/iconEdit` keep the
  test's made-up `ZZ_TEST`/`AA_TEST` edits; the real ones are lost.
- dev edit mode stays on with the palette shown (`OpenDeadminesMap` turns it
  on, `CloseEditMode` only runs at the end), so later map clicks go to
  `MapEdit:Place`, drags move pins, and `Spots` writes fresh copies.
- `W.shift` (`:369-375`) and `W.alt` (`:390-393`) stay held: every later
  right-click is a shift- or alt-right-click.
- the shared data table `ns.Data:Map("DEADMINES")[2]` COOKIE pin keeps the
  test patrol if `Spots` errors between `:227` and `:229`.
- `ns.FontDebug.Text` stays stubbed if `MapEdit:Text()` errors at `:157`.

Even on success, never restored: `MapEdit.lastQuest` is replaced by a new
table (`:298`), `MapEdit.unit`, `MapEdit.model._display = 777` (`:466`),
`MapEdit.on` is forced to `false` (`:183, :203, :416`) rather than put back,
and the last scenario calls `MapEdit:Toggle(true)` (`:459`) without setting
the edits aside, so its redraw of the map on show can write a new
`mapEdit.DEADMINES` copy into the run's SavedVariables.

**Why it matters.** `run.lua` keeps going after a failure (`W.Call` per
scenario, `run.lua:156-165`) and every module file shares one Lua state. Files
sorted after `UI-MapEdit.lua` (`UI-Overview`, `UI-Search`, `UI-Settings`,
`UI-Welcome`, `UI-Wishlist`... from the other groups) would then fail for
reasons that have nothing to do with them, or pass while testing edit-mode
behaviour by accident. One real MapEdit bug turns into a page of misleading
failures.

**Evidence.** Lines read above. Seen happen: running the new tests against
the old MapEdit.lua in secret mode failed at `:471`, and that scenario's
`CloseEditMode(ns)` at `:485` never ran. `tests/smoke/run.lua:156-165`. Other
groups already use the fix below (`/home/claude/wt/mainframe/tests/smoke/modules/UI-MainFrame.lua:8-12`),
and `notes/cross-module.md` plans a shared `W.Restoring` at integration.

**Fix.** Wrap each scenario's body so the restore always runs, and restore
everything the file touches in one place:

```lua
local function Restoring(test, restore)
    local ok, err = xpcall(test, debug.traceback)
    restore()
    if not ok then error(err, 0) end
end

-- What every scenario here may change, put back afterwards.
local function Snapshot(W, ns)
    local MapEdit, kept = ns.MapEdit, SetEditsAside(ns)
    local fields = { "on", "tool", "linking", "unit", "language" }
    local saved = {}
    for _, key in ipairs(fields) do saved[key] = MapEdit[key] end
    local lastQuest, fontText = MapEdit.lastQuest, ns.FontDebug.Text
    return function()
        W.alt, W.shift = nil, nil
        ns.FontDebug.Text = fontText
        if MapEdit.on ~= saved.on then MapEdit:Toggle(saved.on) end
        for _, key in ipairs(fields) do MapEdit[key] = saved[key] end
        MapEdit.lastQuest = lastQuest
        PutEditsBack(ns, kept)
    end
end
```

and the COOKIE patrol removed in the restore too. Tests then assert
`MapEdit.lastQuest[inst.id] = 373` instead of replacing the table.

### R2 · Golden export misses combinations: four export changes pass it

- **Severity:** should fix
- **Area:** WoW API (smoke tests)
- **Where:** `tests/smoke/modules/UI-MapEdit.lua:55-136` (`KnownEdits`, `KNOWN_EXPORT`)
- **Status:** fixed in round 2 (uncommitted): `NPC_56` has a patrol and a name with a backslash, a marker has `boss` and `on`, `ZZ_TEST` outlines on levels 1, 2, 3 (empty) and 10 with two shapes on level 2, `ZZ_DATA` (same as data, left out) and `ZZ_DIFF` (one level changed, written whole). All four round-1 mutations now fail the golden test, as does a string sort of the level keys

**What's wrong.** The golden set covers each field on its own, but not
together, so the order and joining of fields isn't pinned. I changed the
export four ways in a scratch copy and the golden scenario still passed:

1. a pin with both a patrol and a unit NPC: writing `npc`/`name` before
   `patrol` (`PinLine`, `MapEdit.lua:1120-1127`). No pin in the set has both,
   yet unit pins get patrols in normal use (the patrol tool's tooltip:
   "click a boss or unit icon").
2. outline levels sorted the other way (`ShapeLines`, `:1165`): `ZZ_TEST` has
   only one non-empty level.
3. two shapes on one level joined with `"; "` instead of `", "` (`:1166`):
   every level has one shape.
4. a marker with both `boss` and `on` set writing `on = true` instead of the
   boss (`MarkerText`, `:1109`).

**Why it matters.** The export is pasted by hand into data files; the golden
test is the proof the pass kept it byte for byte. A later change that
reorders `patrol`/`npc` would produce text Mike pastes into `Data/Maps.lua`
that differs from the lines around it, and the test that exists to catch
exactly that would pass.

**Evidence.** Mutation runs:
`lua5.1 tests/smoke/run.lua --only "export text"` on each mutated copy printed
`ok   UI/MapEdit: export text for a known set of edits` four times.

**Fix.** Extend `KnownEdits`/`KNOWN_EXPORT`: a unit pin with a patrol (and a
name with a backslash so `%q` is pinned), `ZZ_TEST` outlines on levels 1 and
10 (pins numeric, not string, sort) with two shapes on one level, a second
DEADMINES outline level edited so "differs from the data" is pinned for an
instance that has data, and a marker with `boss` and `on` both set.

### R3 · `MoveMarkersOn` (newly extracted) has no test

- **Severity:** should fix
- **Area:** WoW API (smoke tests)
- **Where:** `NeedRoll/UI/MapEdit.lua:302-309, 334`; `tests/smoke/modules/UI-MapEdit.lua:403-419`
- **Status:** fixed in round 2 (uncommitted): the drag scenario drags a marker with one marker on it on the same level and one on another level (`UI-MapEdit.lua:428-453`); deleting the move in `MoveMarkersOn` now fails it

**What's wrong.** Dragging a marker carries the markers put on it
(`on = true`) to its new spot. This block was moved out of `OnDragStop` into
`MoveMarkersOn` in this change, but the drag scenario drags a handle without
`isMarker`, so the function never runs in any test.

**Why it matters.** A vendor marker with "!" markers on it is dragged; if the
move broke, the "!" markers stay behind at the old spot and the export writes
them there. Nothing would catch it.

**Evidence.** Deleting the line `marker[2], marker[3] = host[2], host[3]` in a
scratch copy: the full dev run printed `all passed`.

**Fix.** In the drag scenario, give the handle `isMarker = true`, put a
second marker `{ level, oldX, oldY, "quest", on = true }` in the shown map's
`spots.markers` (via `OpenDeadminesMap`), drag, and assert it moved to the
handle's new spot and that a marker on another level at the same x, y did not.

### R4 · `DeepCopy` duplicates the game's `CopyTable`

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/MapEdit.lua:122-127` and its 11 calls
- **Status:** fixed in round 2 (uncommitted): `DeepCopy` gone, 11 calls use `CopyTable`

**What's wrong.**

```lua
local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = DeepCopy(inner) end
    return copy
end
```

The game's FrameXML has `CopyTable(t)`, a deep copy of the same kind.

**Why it matters.** Mike's goal for the pass is less code; this is six lines
and a name a reader has to check, for something every WoW addon developer
already knows. It also kept the old `Copy`'s shape only under a new name.

**Evidence.** `CopyTable` is in `FrameXML.lua` (forever) line 1135. The smoke
stand-in already has it (`tests/smoke/wow.lua:111-115`, deep). Every call
passes a table: `DeepCopy(map.entrances or {})` and the like,
`ns.Data:Outlines(id)` and `ns.Data:ZoneQuests(id)` return `... or {}`
(`Data/Data.lua:511-523`), pins/markers/patrols are tables, so
`CopyTable(nil)` can't happen. Neither copies metatables, so the result is the
same (inferred from both bodies).

**Fix.** Delete `DeepCopy`, call `CopyTable(...)` at its call sites.

### R5 · Comments that restate the name or the line below; comment lines up 34

- **Severity:** should fix
- **Area:** Readability
- **Where:** `NeedRoll/UI/MapEdit.lua:49, 51, 234, 545, 720, 940, 1084, 1131, 1186, 1196`
- **Status:** fixed in round 2 (uncommitted): all but one removed or reworded (`:51` folded into a trailing comment on `raid`, `:940` reworded, `:1172` now "Only the outlines that differ from the data's"). `-- Every edited map, in Data/Maps.lua's RegisterMapSpots shape.` (now `:1124`) was kept; it repeats the section header in `Text()` but is harmless. Comment lines 159 -> 151

**What's wrong.** Code went down 62 lines but comment lines went up 34
(125 -> 159). Many new ones are good (`:129`, `:157-159`, `:368-370`,
`:407-408`, `:980-982`). These say what the name or the next line already
says (`docs/READABLE-CODE.md` §5 "no restating the line below"):

- `:234` `-- Patrol routes added to the data after the copy was made.` over `local function CopyNewPatrols(saved, map)`.
- `:720` `-- The palette's grid of tool buttons, four a row.` over `CreateToolButtons` (the 4 is in R10's constant).
- `:940` `-- Fills the button of the tool that is picked.` over `UpdatePalette` (and "fills" undersells that it also clears the rest).
- `:1084` `-- Each item of \`list\` as text, joined with commas.` over `JoinAsText(list, toText)`.
- `:1131`, `:1186`, `:1196` (`-- Zone-wide quests, in RegisterZoneQuests' shape.` over `ZoneQuestLines`): `MapEdit:Text()` passes each one the header that names its file (`:1220-1223`), so the same fact is written twice.
- `:545` `-- A quest marker's quest, picked from a menu of the dungeon's quests.` over `MapEdit:QuestMenu`.
- `:49`, `:51`: were trailing comments on their entries; now each takes its own line, and `:51` "A door that needs a key or lockpicking" repeats the entry's new `title = "Locked door"`.

**Why it matters.** Mike asked for leaner code and comments, and every
restating comment is one more line to keep true when the code changes.

**Evidence.** Diff of comment lines old vs new (34 net added); lines quoted.

**Fix.** Delete `:234, :720, :1084, :1131, :1186, :1196, :545, :51`; put the
UBRS example back as a trailing comment on the `raid` entry; reword `:940` to
`-- Shows which palette button's tool is picked (blue fill).` or drop it.
About ten lines.

### R6 · `MovePin` silently creates `spots.pins[level]`, and `Place` depends on it

- **Severity:** should fix
- **Area:** Readability
- **Where:** `NeedRoll/UI/MapEdit.lua:466-475`, used at `:509-510` and `:514-516`
- **Status:** fixed in round 2 (uncommitted): `MovePin(pins, key, x, y)` only searches and moves; `Place` makes the list. A new test places a boss on a level whose list is nil (`UI-MapEdit.lua:341-344`). The two-line list setup is now written twice, see R13

**What's wrong.**

```lua
-- Moves the pin with this key on the level to x, y; true when it was there.
local function MovePin(spots, level, key, x, y)
    spots.pins[level] = spots.pins[level] or {}
```

and then in `Place`:

```lua
if not MovePin(spots, level, key, x, y) then
    table.insert(spots.pins[level], { key, x, y, ... })
```

The insert only works because a function named "move" created the list.

**Why it matters.** `docs/READABLE-CODE.md` §9: a function must not do
something its name doesn't say. Someone who tidies `MovePin` (it reads like a
lookup) breaks placing a boss on a level with no pins yet, with
"bad argument #1 to 'insert'".

**Evidence.** Lines read. In practice `spots.pins[level]` exists for every
level (`Spots` makes it for `1..#map`, `:272-275`; `MergePins` too, `:229`),
so the guard is defensive (inferred).

**Fix.** Make the list in `Place` before either call
(`local pins = spots.pins[level] or {}; spots.pins[level] = pins`) and let
`MovePin(pins, key, x, y)` only search and move.

### R7 · `SpotText` duplicates `SpotWithIconText`

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/MapEdit.lua:1095-1105`
- **Status:** fixed in round 2 (uncommitted): one `SpotText` for locks, entrances and links; golden lock line unchanged

**What's wrong.** `SpotWithIconText` already leaves the icon out when
`spot[4]` is nil, which is exactly `SpotText`'s output. `SpotText` is used only
for locks.

**Why it matters.** Two formatters for one shape; five lines to cut.

**Evidence.** Locks are `{ level, x, y }` in the data (`Data/Maps.lua:613`
format comment, `:631`, `:711`), placed ones are `{ level, x, y }` (`:528`),
and nothing sets a lock's `[4]` (shift-right-click is only for links and
markers, `:439-444`). So the export stays byte-identical (inferred from those
lines; pin it with the golden lock).

**Fix.** One `SpotText(spot)` with the optional icon; locks use it.

### R8 · Local `Round` shadows the game's global `Round` with a different meaning

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/MapEdit.lua:130` and its calls
- **Status:** fixed in round 2 (uncommitted): `RoundCoord`; grep finds no bare `Round(` left, so no call falls through to the game's global

**What's wrong.** `local function Round(coord)` clamps to 0..1 and keeps three
decimals. The game has a global `Round(x)` that rounds to a whole number.

**Why it matters.** A WoW developer reading `Round(x + 0.06)` expects a whole
number; a search for `Round(` mixes the two. Same reason the old local
`UnitName` (which shadowed the game's) was rightly renamed `CreatureName`.

**Evidence.** `Round` in `GlobalAPI.lua` (forever) line 6899.

**Fix.** `RoundCoord` (or `MapCoord`).

### R9 · Two clever one-liners where plain `if`s read better

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/MapEdit.lua:380`, `:416-417`
- **Status:** fixed in round 2 (uncommitted): area toggle is a plain `if/else` (`:371-375`); `RemoveSpot` loops over the four lists, each `or {}`, so the loop table has no nil hole (`:411-414`)

**What's wrong.**

```lua
spot.area = not spot.area and AddLoopPoints({ area = true }, spot[2], spot[3], 0.05, 0.075) or nil
```

It is correct (the middle value is always a table), but it's the `a and b or c`
pattern the repo has been bitten by, used for a toggle. And

```lua
local _ = Remove(spots.links[level], spot) or Remove(spots.entrances, spot)
    or Remove(spots.locks, spot) or Remove(spots.markers, spot)
```

assigns to `_` only to run an `or` chain for its side effects.

**Why it matters.** `docs/READABLE-CODE.md`: "a clear 10 lines beat a clever 4".
A newcomer has to stop and prove both lines right.

**Evidence.** Lines read; the old code had the first as a plain `if/else`.

**Fix.** `if spot.area then spot.area = nil else spot.area = AddLoopPoints(...) end`.
For `RemoveSpot`, either a plain `if Remove(a) then return end` per list, or keep
the chain and say in its comment that it removes the spot from the first list
that holds it.

### R10 · Tools per row `4` written three times; `PickTool` also unpicks

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/MapEdit.lua:114, 726` (`4` three times); `:671-675`
- **Status:** fixed in round 2 (uncommitted): `TOOLS_PER_ROW = 4` used at `:113` and `:724-725`; `PickTool` renamed `ToggleTool`

**What's wrong.** Boss buttons got `BOSS_PER_ROW`, but tool buttons per row is
a bare `4` in `BOSS_TOP` (`:114`) and twice in `CreateToolButtons` (`:726`).
`PickTool(tool)` picks a tool or lets it go when it is already picked; the
name says only the first.

**Why it matters.** §7 searchable names (change the palette to five a row and
one of three places gets missed); §9 names that say what the function does.

**Fix.** `TOOLS_PER_ROW = 4` beside `TOOL_COLUMN`; rename `PickTool` to
`ToggleTool` (local, no callers outside the file).

### R11 · Header says zoneEdit and outlineEdit are keyed like questEdit; they aren't

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/MapEdit.lua:22-24`
- **Status:** fixed in round 2 (uncommitted): header now says zoneEdit is a list per instance and outlineEdit is keyed by level (`:21-25`)

**What's wrong.** "quest marks in NeedRollDB.questEdit[instance id][quest id]
(zoneEdit, outlineEdit the same way)". `zoneEdit[id]` is a list of
`{ quest id, icon }` (`:604-626`) and `outlineEdit[id]` is keyed by level
(`:584-593`).

**Why it matters.** §9: a newcomer reading SavedVariables would look for
quest IDs as keys in both.

**Fix.** "...; zone-wide quests in zoneEdit[instance id] (a list) and outlines
in outlineEdit[instance id][level]."

### R12 · Creature-name lookup and secret check duplicate Core/Names.lua

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/MapEdit.lua:983-988` vs `NeedRoll/Core/Names.lua:243-262` (`Text`, `TooltipLines`, `NpcName`); core group's `ns.IsSecret` (`notes/cross-module.md`, "from core")
- **Status:** cross-module: left for integration (MapEdit's own hand-back already lists the `NpcName` duplicate)

**What's wrong.** `CreatureName` builds the same
`unit:Creature-0-0-0-0-%d-0000000000` link, calls `C_TooltipInfo.GetHyperlink`
in a `pcall`, and treats a secret or empty first line as no name, as
`Names.lua`'s `NpcName` does. The new secret check is written as a bare
`issecretvalue(name)`; every other file writes
`(issecretvalue and issecretvalue(v))`, and the core group is adding
`ns.IsSecret` for all of them.

**Why it matters.** Two copies of the secret-name rule drift apart; this
group can't edit `Names.lua`, so it's for integration.

**Evidence.** Lines read; `notes/cross-module.md`. The bare call is correct for
Forever (`issecretvalue` in `GlobalAPI.lua` forever line 6874).

**Fix.** At integration, expose `NpcName` on `ns.Names` (or use `ns.IsSecret`)
and have `CreatureName` call it. The fix itself (no secret name stored) is
accepted, see Area notes.

### R13 · The "make this level's pin list" pair is written twice in `Place`

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/MapEdit.lua:505-506` and `:512-513`
- **Status:** fixed after round 2: one `LevelPins(spots, level)` helper

**What's wrong.** The R6 fix moved the list setup out of `MovePin`, but into
both branches that need it:

```lua
local pins = spots.pins[level] or {}
spots.pins[level] = pins
```

once under `tool == "unit"` and again under `boss`.

**Why it matters.** Small, but it's the copy-paste the pass is removing
elsewhere (§6, one way of doing each thing), two lines that can only
change together.

**Evidence.** Lines read.

**Fix.** Do it once before the branches (`local pins = spots.pins[level] or {}`
and `spots.pins[level] = pins` right after `local markerKind = ...`), then
both branches use `pins`. Making an empty list for a level that has none
doesn't change the export (empty levels are skipped, `MapSpotLines`) and
every level has one already (`Spots`, `:263-266`).

## Area notes

### Readability

Checked against `docs/READABLE-CODE.md` rule by rule. Sound:
names now say what things are (`DeepCopy` aside, R4): `ShownMap` for
`Current`, `PinLevels`, `MergeMarkers`'s `inData` for `now`, `CreatureName`
for a local `UnitName` that shadowed the game's function, `isHere` for `here`,
`MARKER_TITLES`, `LINK_ICONS`. The long functions are split along real seams:
`Palette` (old 205 lines) into `CreateToolButtons`, `CreateUnitPicker`,
`CreateQuestPortal`, `CreateLanguagePicker`; `Text` (old 140 lines, four
levels deep) into one function per section; `Place` is flat with guard
clauses. All lines within 120 characters (luacheck), 4-space indents, LF.
`local _, ns = ...` at the top. No `cond and nil or x`; one `a and b or nil`
(R9, correct). No `#t` on tables with holes: `MapSpotLines` uses `ipairs` over
`links`/`pins`, which are built for every level (`:272-275`, `:229`); the old
`for level = 1, #edits.links` would have errored on a hole instead. No string
patterns built from data. The 24-line file header is long but it's the file's
only user guide; it was corrected (Outlines.lua, zoneEdit/outlineEdit), apart
from R11.

Behaviour, compared function by function old vs new:

- `Spots`/`MergePins`/`CopyNewPatrols`/`MergeMarkers`: same results; `inData`
  is filled in the data loop rather than a second pass over the merged list,
  same set. Return paths the same (copy only in edit mode). SavedVariables
  keys unchanged (`entrances`, `locks`, `markers`, `links`, `pins`,
  `pinLevels`, `dataMarkers`, `removed`, `added`, `patrol`, `open`, `area`,
  `boss`, `on`, `npc`, `name`).
- `ToolKind(tool)` (`^%a+`) for the old `match("^patrol")`/`match("^zone:")`
  tests: same for every tool in `TOOLS` (`patrol-loop`, `patrol-line`,
  `zone:attack`, `zone:loot`); `TOOL_HELP[ToolKind]` falls back to
  `PLACE_HELP` for `door-*`, `up`, `down`, `entrance`, `raid`, `lock`, as the
  old `else` did. The map-click hints now run before the outline branch; the
  kinds don't overlap, so the order change is invisible.
- `NextInList` takes the first match where the old loop took the last; icon
  lists have no duplicates (`LINK_ICONS`, `ns.Data.markerOrder`).
- `RedrawQuestMarks(quest)` matches the old QuestClick refresh
  (`pane.quest == quest` and visible) and `RedrawQuestMarks()` the old Reset.
- Palette buttons: same sizes, colours, highlight, tooltips; texture creation
  order changed but each is in its own draw layer. No pixel change, so no
  `docs/STYLE-GUIDE.md` update is needed (it doesn't describe the palette).
- Export: same section order and blank lines (`AddSection`), same formats;
  golden test passes on old and new code (Checks), with the gaps in R2.

### WoW API

Removed fallbacks, checked against Ketho's `forever` lists:

| Name | Kind | In forever lists | Where looked |
| --- | --- | --- | --- |
| `MenuUtil.CreateContextMenu` | FrameXML function | yes | `FrameXML.lua:2552` |
| `C_TooltipInfo.GetHyperlink` | C_ function | yes | `GlobalAPI.lua:4199` |
| `PlayerModel:GetDisplayInfo` | widget method | yes | `WidgetAPI.lua:797-803` (PlayerModel) |
| `PlayerModel:SetCreature` | widget method | yes | `WidgetAPI.lua:813` |
| `issecretvalue` (newly called) | global function | yes | `GlobalAPI.lua:6874` |
| `ns.Search:Forget` | addon | n/a | `UI/Search.lua:8, 122`, not dev-gated, loaded by `UI.xml` before any call can run |
| `ns.FontDebug:Text`, `:Reset` | addon | n/a | `UI/FrameDebug.lua:319-654`, inside `--@debug@`; see below |
| `CopyTable` (suggested, R4) | FrameXML function | yes | `FrameXML.lua:1135` |
| `Round` (shadowed, R8) | global function | yes | `GlobalAPI.lua:6899` |

Unchanged calls the file still makes, spot-checked: `CreateFrame`,
`C_Timer.After`, `strtrim`, `IsAltKeyDown`, `IsShiftKeyDown`, `GetLocale`
(GlobalAPI yes); `SetUserPlaced`, `StartMoving`, `StopMovingOrSizing`,
`RegisterForDrag`, `GetEffectiveScale`, `SetHighlightTexture`,
`SetColorTexture`, `SetWordWrap`, `SetMultiLine`, `HighlightText`,
`SetScrollChild` (WidgetAPI yes); templates `BasicFrameTemplateWithInset`,
`InputBoxTemplate`, `UIPanelButtonTemplate`, `UIPanelScrollFrameTemplate`
(Templates.lua yes). `GameTooltip`, `UIParent`, `ChatFontNormal`: standard
global frames/font objects, accepted by inference. The kept
`if root.SetScrollMode then` guard is on a menu-description mixin method that
no list covers; keeping it is reasonable (inferred).

`ns.FontDebug` when MapEdit runs: it is defined inside `--@debug@` in
FrameDebug.lua, and `MapEdit.available` is set only inside `--@debug@`
(`:34-36`). Every entry point (`Toggle`, `Reset`, `Export`, the palette's
Export button) returns early unless `available`, and `Text()` is only
called from `Export` and the dev-only scenarios, so `ns.FontDebug` exists
whenever it's reached; the packager strips both blocks together. FrameDebug
loads after MapEdit (`UI.xml:9` vs `:21`), but both calls happen at run time,
not load time. The packaged smoke run passing confirms nothing reaches them.

Secret values: the fix is **accepted**. Before, `UnitName(npc)` returned
`line.leftText` after `line.leftText ~= ""`, a comparison on a value that is
secret for creature tooltips on Forever, and a secret that got through was
stored in `pin.name` (SavedVariables) and run through `("%q"):format` in the
export. Now `CreatureName` returns nil for a secret name before any compare,
the unit shows as "Unit 1234", and the old code's failure in secret mode
(Checks) shows the test catches it. `name == nil` on a possibly secret value is
the pattern the rest of the addon uses (`Core/Names.lua:245`).

No events, no new globals set (`NeedRollMapEdit`, `NeedRollMapExport` frame
names are unchanged from before), no secure frames or protected calls, no
`OnUpdate`, no player-facing `L[...]` text (dev-only English strings, as
before; locales check passes). No new game call needs a stand-in: everything
used is already in `tests/smoke/wow.lua` (`C_TooltipInfo` `:1577`, `MenuUtil`
`:1635`, `GetDisplayInfo` `:691`, `CopyTable` `:111`). The bug fix has a test
(`UI-MapEdit.lua:469-472`). Dev-only code: the whole editor is behind
`MapEdit.available`.

### Redundant code

Compared against: `T:*` in `UI/Theme.lua` (the palette uses `ns.Theme:FitAtlas`,
`ns.UI.MiniPin`/`SetMiniPin` already; the dev windows use the game's
`BasicFrameTemplateWithInset`, not the addon skin, on purpose, as before);
helpers on `ns` and in other files (`Core/Wishlist.lua:88` has its own local
`IndexOf`, a different signature; `Core/Names.lua` `NpcName`, R12); the game's
`CopyTable` (R4), `tIndexOf`/`tDeleteItem` (`GlobalAPI.lua:7046-7047`; not
suggested: `tIndexOf(nil)` errors where `IndexOf` takes a nil list, and
`tDeleteItem` returns a count, which is truthy at 0, so it can't feed the
`or` chain). Within the file the old copies are gone: three starter loops ->
`AddLoopPoints`, four palette-button bodies -> `PaletteButton`, two windows ->
`DevWindow` (`DevKit.Window` in the devtools group is the same dialog; listed
in `notes/cross-module.md`), the `Has`/`Remove`/"next icon" search loops ->
`IndexOf`/`NextInList`, the per-section "items as text, joined" loops ->
`CoordList`/`JoinAsText`, the per-section "sorted IDs" loops -> `SortedKeys`. Left: R4, R7. No dead code found: every local is used,
`luacheck --no-global` reports no unused variable.

### Security

Inputs: the player's own SavedVariables (`NeedRollDB.mapEdit/questEdit/zoneEdit/outlineEdit`)
and the game's tooltip text for a creature ID typed by the developer. No addon
messages, chat, `loadstring`/`RunScript`, network or other players' data.
Output: the export text, pasted by Mike into data files; it contains creature
names from the game, never character names or drop credits, so nothing here
can make a player's name public. String fields (`pin[1]`, `marker.boss`,
`spot[4]`) are written between quotes without escaping a `"` (only `pin[4]`'s
backslashes and `pin.name` via `%q`); they come from the developer's own
edits and the addon's data keys, so this is unchanged and harmless. The fix
stops a secret value from reaching SavedVariables and `string.format`.

## Round history

- 2026-10-17, `c0e5c79` + uncommitted, round 1: **Changes needed**. Opened R1-R12 (1 blocking, 5 should fix, 6 nits).
- 2026-10-17, `c0e5c79` + uncommitted (round 2 fixes), round 2: **Ready**. Closed R1-R11; R12 left for integration; opened R13 (nit). Lines: 1258 -> 1248 total; code 1078 -> 1017, comments 125 -> 151, blank 55 -> 80.
- 2026-10-17, after round 2: R13 (nit) fixed with a `LevelPins(spots, level)` helper used by both branches of `Place`; MapEdit smoke tests pass.
