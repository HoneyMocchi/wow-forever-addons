# Review: Readability pass, group Lists (`NeedRoll/UI/Lists.lua`)

| | |
| --- | --- |
| Branch | `rp-lists` (worktree of the addon-wide readability pass) into `claude/addon-readability-pass-rg51s6` (PR not opened yet) |
| Commit reviewed | `c0e5c79` plus uncommitted changes (`NeedRoll/UI/Lists.lua` and `docs/STYLE-GUIDE.md` modified, `tests/smoke/modules/UI-Lists.lua` new) |
| Date | 2026-10-18 |
| Round | 2 |
| Verdict | **Ready** after round 2 fixes (0 blocking, 0 should fix, 0 nits open) |
| Needs | `/reload` (one Lua file changed; no `.toc`, XML or SavedVariables change) |

## What the change does

Nothing a player sees changes: the instance list (left column) and the
encounter list (middle column) draw, slide, scroll and click as before. The
code under them is reorganised. `CreateList`'s 120-line `Refresh` is split
into `ClaimRows` (row pooling) and `DrawRow` (filling one row); the title
wrap logic gets `WrapBesideSuffix`; the two copies of the "slide a group open
or shut" animation (instance list and encounter list) become one
`StartSlide`/`StopSlide` pair; the encounter list's 330-line `setupRow` /
`afterRow` closures become named functions (`SetupRow`, `SetupHeaderRow`,
`SetupQuestRow`, `SetupEncounterRow`, `ShowCrests`, `ShowQuestIcons`,
`AfterRow`, `PaintHeader` ...); its `Entries()` builder is split into
`Adder`, `AddIfOpen`, `AddRows`, `AddWings`, `ShowsHeader`; three copies of
the round-mask code become `MaskRound`; the one-group `INSTANCE_GROUPS`
loop becomes a single `CLASSIC_RAIDS` table; guards for functions Forever
always has (`C_Spell`, `SetPropagateMouseClicks`, `SetSnapToPixelGrid`) and
for addon functions that always exist by draw time are dropped; a no-op
`ns.Data:Chain` call and the dead `PlaceTitleIcon` are removed. The file goes
from 2428 to 2410 lines. A new module test file adds 11 smoke tests. Round 2
also reduces the instance list's Classic Raids code to one flag
(`classicOpen`) and a member set (`isMember`), so its `ToggleGroup()` takes
no argument, and moves the row helpers that need no list state to file
scope.

## Scope

- `NeedRoll/UI/Lists.lua`: the refactor above (round 2: 1112 insertions,
  1130 deletions against `HEAD`). Every changed function was read in
  full, plus the unchanged code around it.
- `tests/smoke/modules/UI-Lists.lua` (new, 405 lines): 11 tests for both
  lists, with the `Restoring` helper from the brief (at integration, the
  shared `W.Restoring` from `tests/smoke/wow.lua`, #596).
- `docs/STYLE-GUIDE.md`: line 119 only (R3).
- Read for context, not changed: `NeedRoll/UI/UI.xml`, `NeedRoll/NeedRoll.toc`,
  `.pkgmeta`, `NeedRoll/UI/MainFrame.lua:975-1005`,
  `NeedRoll/UI/Overview.lua:2600-2640`, `NeedRoll/Data/Data.lua:88-100,303-327`,
  `NeedRoll/UI/RecipeBand.lua:17`, `docs/STYLE-GUIDE.md`.
- No generated files under `NeedRoll/Data/` touched.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` (both files) | round 1 and round 2: passed |
| `luacheck --no-global -q` | base (`git show HEAD:`) 15 warnings (7 long lines, 4 unused args, 2 shadowing, `at` never set); round 1 and round 2: **0** in both files |
| `luacheck --std lua51` W11x global names | round 2: identical set to `git show HEAD:`: `C_Item C_Spell C_Timer CreateColor CreateFrame GameTooltip GetTime IsShiftKeyDown UnitClass UnitFactionGroup UnitLevel wipe` (no local used before its declaration) |
| Upvalues (`luac5.1 -l -l`) | `CreateEncounterList` base 49, round 1 55, round 2 **50** of 60; every other function 23 or fewer |
| `python3 tools/locales.py --check` | round 2: passed (exit 0) |
| `python3 tools/translations.py` | round 2: passed (exit 0) |
| `tests/smoke/check.sh` | round 2: passed in all three modes (dev, `--packaged`, `--secret`), 11 `UI/Lists` tests ok in each (33 in all), `all passed` three times |
| Module tests against the base code | round 1: the 11 tests passed on `HEAD`'s `Lists.lua`. Round 2: they call the instance list's `ToggleGroup()` with no argument, which `HEAD` can't take, so they no longer run against `HEAD`; the snapshot below is the before/after proof instead. No caller outside `Lists.lua` uses the instance list's `ToggleGroup` (`grep -rn ToggleGroup NeedRoll/ tests/smoke/scenarios.lua`: only `encounters:ToggleGroup("QUESTS")` at `scenarios.lua:1466`, the other list). |
| Snapshot (`scratchpad/lists/snapshot.lua`, rerun by the reviewer) | dumps every visible region of both lists across every tab and instance, mid-slide, toggled, wings, quest/boss picked, scrolled, Horde side, levels 10/45/60, six professions with six filters each. HEAD vs round 1 and HEAD vs round 2: **byte-identical** in dev, `--packaged` and `--secret` (353 593 bytes each). The snapshot calls `ToggleGroup(entry.group)`, which round 2 ignores, so it drives both versions the same way. |
| Scraper unittest | not run: no scraper change |
| Line endings / tabs / >120 chars | LF only, no tabs, no line over 120 |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R11 | should fix | Readability | `NeedRoll/UI/Lists.lua:1344, 1369, 1929` vs `:1820, 1841, 1860` | `header` is a yes/no in some new helpers and the header entry in their neighbours | fixed after round 2 |
| R12 | nit | Readability | `NeedRoll/UI/Lists.lua:1059, 1856` | The crest nudge is described as conditional but always applies | fixed after round 2 |
| R13 | nit | Readability | `NeedRoll/UI/Lists.lua:67, 696, 1383, 1405` | Comments point at `afterRow` and two are wrapped unevenly | fixed after round 2 |
| R14 | nit | Readability (tests) | `tests/smoke/modules/UI-Lists.lua:213-259, 302-325` | Two tests leave groups and wings open for the tests after them | fixed after round 2 |
| R1 | should fix | Readability (tests) | `tests/smoke/modules/UI-Lists.lua:159-184, 363-384` | Two tests undo their changes in the test body, not in `restore` | fixed in round 2 (uncommitted) |
| R2 | should fix | WoW API (Lua limit) | `NeedRoll/UI/Lists.lua:1331` | `CreateEncounterList` climbed from 49 to 55 of Lua 5.1's 60 upvalues | fixed in round 2 (uncommitted) |
| R3 | should fix | Readability | `docs/STYLE-GUIDE.md:119` | Style guide still points at the removed `TREE` constant | fixed in round 2 (uncommitted) |
| R4 | should fix | Redundant code | `NeedRoll/UI/Lists.lua:1398-1406` | `Kids("WING:..")` builds a new closure on every call, per row drawn | fixed in round 2 (uncommitted) |
| R5 | should fix | Redundant code | `NeedRoll/UI/Lists.lua` (several) | Only 8 lines came out; concrete cuts left in this file | fixed in round 2 (uncommitted) |
| R6 | nit | Readability | `NeedRoll/UI/Lists.lua:1971` | Local `OnMapFloor` shares its name with `ns.UI.OnMapFloor` but means more | fixed in round 2 (uncommitted) |
| R7 | nit | Readability | `NeedRoll/UI/Lists.lua:65-66, 133` | `opts.entryHeight` is now required; the doc reads as if it were optional | fixed in round 2 (uncommitted) |
| R8 | nit | Readability | `NeedRoll/UI/Lists.lua:36-41, 571-574, 1336, 1624` | Four comments misplaced, appended or stale | fixed in round 2 (uncommitted) |
| R9 | nit | Readability (tests) | `tests/smoke/modules/UI-Lists.lua:16` | Test helper `IndexOf` has a different contract from the addon's `IndexOf` | fixed in round 2 (uncommitted) |
| R10 | nit | Readability | `NeedRoll/UI/Lists.lua:1312, 1860-1862` | Crest slot placed with a gap that can't apply; quest row silently relies on it | fixed in round 2 (uncommitted) |

### R1 · Two tests undo their changes in the test body, not in `restore`
- **Severity:** should fix
- **Area:** Readability (tests; the brief's Restoring rule)
- **Where:** `tests/smoke/modules/UI-Lists.lua:159-184` ("the selected row, compact rows, label icon"), `:363-384` ("profession and recipe icons")
- **Status:** fixed in round 2 (uncommitted). `restore` now runs `list:SetCompact(false)` and `list:SetLabelIcon(nil)` before switching tabs (`UI-Lists.lua:180-186`); the recipe icon is an outer local hidden in `restore` (`:368, 386`).

**What's wrong.** The brief requires every test to restore what it changes
"even when it fails". In the compact-rows test the undo is inside the test
function:

```lua
list:SetCompact(true)
assert(list.rowHeight == math.floor(ns.Theme.size.row * 1.15 + 0.5), "compact rows aren't 1.15x a row")
list:SetCompact(false)
...
list:SetLabelIcon("Dungeon", 26)
```

and the `restore` only switches tabs (`ui:SwitchTab("RAID"); ui:SwitchTab("DUNGEON")`).
In the icons test, `local icon = ns.UI.RecipeIcon(UIParent, 24)` is hidden by
`icon:Hide()` on the test's last line.

**Why it matters.** If the assert on line 171 fails, the instance list stays
compact (`rowHeight` 30 instead of 44) for every test that runs after it, so
one failure shows up as a cascade of unrelated failures and hides the real
one. Whether `SwitchTab` resets the label icon is not something the test
checks; it is the reason the rule exists. The stray recipe icon on
`UIParent` is harmless but is the same pattern.

**Evidence.** Lines read. Inferred: `SwitchTab` does not call `SetCompact`
for the Dungeons tab (only the profession list is compact), so the restore as
written would not undo it.

**Fix.** Move the undo into `restore`:

```lua
end, function()
    list:SetCompact(false)
    list:SetLabelIcon(nil)
    ui:SwitchTab("RAID")
    ui:SwitchTab("DUNGEON")
end)
```

and in the icons test keep `icon` in an outer local and `if icon then icon:Hide() end`
in `restore`.

### R2 · `CreateEncounterList` climbed from 49 to 55 of Lua 5.1's 60 upvalues
- **Severity:** should fix
- **Area:** WoW API (Lua 5.1 limit)
- **Where:** `NeedRoll/UI/Lists.lua:1331` (`function ns.UI.CreateEncounterList(parent)`)
- **Status:** fixed in round 2 (uncommitted). `ShowRankIcon`, `ShowChainStep`, `ShowRecipeIcon`, `ShowArrows`, `NewHeaderDisc`, `NewShutCard`, `SetupQuestRow` and `PaintHeader` moved to file scope (`Lists.lua:1325-1455`); `CreateEncounterList` is at 50 upvalues (`luac5.1 -l -l`), and a comment above it (`:1457-1460`) says why helpers live outside.

**What's wrong.** Moving helpers to file scope made `CreateEncounterList`
read more file-level locals. New upvalues: `CLASS_RING`, `INSTANCE_HEADERS`,
`IndexOf`, `IsSetRow`, `LevelText`, `MaskRound`, `NewChainStep`,
`PlaceChainStep`, `SET_MEMBER_INDENT`, `ShowQuestIcons`, `StartSlide`,
`StopSlide`; gone: `GROUPS`, `INSIDE_ICON`, `QUEST_CREST`, `ROUND_MASK`,
`SLIDE`, `Smooth`.

**Why it matters.** Lua 5.1 refuses to load a function with more than 60
upvalues, and in the game that means the whole file fails to load and the
window never opens. `CreateOverview` already sits at the limit and carries
comments warning about it (`Overview.lua:116, 350, 3237`); this function now
has five to spare and nothing tells the next person. A future feature that
adds a couple of constants and a helper will hit it.

**Evidence.** `luac5.1 -l -l` upvalue lists for the function: base 49
(`git show HEAD:`, function at line 1225), change 55 (line 1331); diff of the
two name lists as above.

**Fix.** Win back headroom inside this file, then say so in a comment above
the function like Overview does. Cheap ones: move `ShowChainStep` next to
`NewChainStep`/`PlaceChainStep` at file scope (it only needs `row`, `enc`,
`header`; two upvalues become one); move `NewHeaderDisc` to file scope (takes
`DISC`, `DISC_RING`, `MaskRound` out); fold `StopSlide` into a
`pane:StopSlide()` method set by `StartSlide`'s file (or call it through the
pane) so the list reads one name less. Aim for 50 or under.

### R3 · Style guide still points at the removed `TREE` constant
- **Severity:** should fix
- **Area:** Readability (disinformation)
- **Where:** `docs/STYLE-GUIDE.md:119`
- **Status:** fixed in round 2 (uncommitted). `docs/STYLE-GUIDE.md:119` now names `CHAIN_CIRCLE`, `CHAIN_GAP`; it is the file's only change (`git diff HEAD -- docs/STYLE-GUIDE.md`).

**What's wrong.** The chain-step row of the style guide ends with
`` `TREE` in `Lists.lua` ``. The change renamed `TREE = { CIRCLE = 28, GAP = 6 }`
to `CHAIN_CIRCLE` and `CHAIN_GAP` (`Lists.lua:1009-1010`). The values are
unchanged, so only the pointer is wrong.

**Why it matters.** The style guide is where Mike and the agents look up
which constant to change; grepping `TREE` now finds nothing.

**Evidence.** `grep -n "Lists.lua" docs/STYLE-GUIDE.md`; lines 111 and 115
still match the code (`LABEL_ICON`, the crest sizes).

**Fix.** Change the cell to `` `CHAIN_CIRCLE`, `CHAIN_GAP` in `Lists.lua` ``. The
brief limits this group to its own files, so either list it under
"Cross-module" for the merge step or let the coordinator allow the one-line
doc edit; it must land in the same PR.

### R4 · `Kids("WING:..")` builds a new closure on every call, per row drawn
- **Severity:** should fix
- **Area:** Redundant code (repeated per-row work)
- **Where:** `NeedRoll/UI/Lists.lua:1398-1406`
- **Status:** fixed in round 2 (uncommitted). `BuildWingHeaders` stores each wing's encounters on its row as `wingEncounters` (`Lists.lua:1497-1501`); `Kids` finds the row by key (`:1532-1536`), and `LitByMapFloor` and `AddWings` read `wingEncounters` directly. No closure per call.

**What's wrong.**

```lua
return Kept(instance, key, function()
    local list = {}
    for _, enc in ipairs(instance.encounters) do
        if enc.wing == wing then table.insert(list, enc) end
    end
    return list
end)
```

The function passed to `Kept` is created on every call, even when the list is
already kept. `Kids` runs for each wing row on every redraw: `AfterRow` ->
`OnMapFloor(entry)` -> `Kids(entry.key)` for a wing header, `SetupHeaderRow`,
`AddWings`, `ToggleGroup`. While a group slides, `Refresh` runs every frame.
The base code (`wingRows[instance][wing]`) allocated nothing once cached.

**Why it matters.** Garbage per frame during slides in Stratholme, Dire Maul
and Scarlet Monastery, where the addon otherwise takes care to cache. It is
also the one `Kept` call whose builder ignores the `instance` it is given,
which makes `Kept`'s contract harder to read.

**Evidence.** Lines read; call sites from `grep -n "Kids(" NeedRoll/UI/Lists.lua`.

**Fix.** Build each wing's encounters once in `BuildWingHeaders` and keep
them on the wing's row, which also deletes the third `Kept` key:

```lua
local function BuildWingHeaders(instance)
    local list = {}
    for _, wing in ipairs(instance.wings) do
        local header = { wingHeader = true, key = "WING:" .. wing, name = wing, encounters = {} }
        for _, enc in ipairs(instance.encounters) do
            if enc.wing == wing then table.insert(header.encounters, enc) end
        end
        table.insert(list, header)
    end
    return list
end
```

and look the wing up by key in `Kids` (or pass the wing row instead of its
key where the caller has it, as `AddWings` and `OnMapFloor` do).

### R5 · Only 8 lines came out; concrete cuts left in this file
- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Lists.lua:575-584, 697-698, 893, 930-934` (Classic Raids), `:2110` (`DrawnHeight`), `:1398-1406` (R4), `:1312` (R10)
- **Status:** fixed in round 2 (uncommitted). Classic Raids is a flag and a set (`classicOpen`, `isMember`, `IsClassicRaid`, `CLASSIC_HEADER`); `DrawnHeight` is gone; the dead crest gap is gone. 2420 -> 2410 lines (18 under `HEAD`). The two inline `function(enc) return pane:EntryHeight(enc) end` at `:2159, 2171` repeat what `DrawnHeight` named; either way is fine.

**What's wrong.** Mike's goal for the pass is less code without loss. The
splits are good and the shared slide is a real cut, but the file is only 8
lines shorter, and some generality that serves one case is still there:

- The instance list still treats Classic Raids as one of many groups:
  `CLASSIC_RAIDS.key`, `CLASSIC_RAIDS.header.group`, `open[group.key]`,
  `groupOf[member] = CLASSIC_RAIDS`, `ToggleGroup(group)`. There is exactly
  one group and the code already assumes it (`local sliding = pane.anim ~= nil`,
  line 893). A `local classicOpen = false` and a `isClassicMember[inst]` set
  (or `GroupOf(inst) ~= nil`) remove the key, the back-reference and the
  `open` table. `ToggleGroup`'s argument is only used by this file and the
  module test (`grep -rn "instances:ToggleGroup" NeedRoll/` finds nothing
  outside Lists.lua).
- `local function DrawnHeight(enc) return pane:EntryHeight(enc) end` exists
  only to be passed to `Adder`; `Adder(list, function(enc) return pane:EntryHeight(enc) end)`
  at its two call sites, or `Adder(list, pane.EntryHeight, pane)`, reads the
  same with one name fewer.
- R4 removes the inline wing builder (about 6 lines).

**Why it matters.** The brief says "the group should end up shorter than it
started" and asks the reviewer to push; 8 lines out of 2428 after a
1000-line rewrite is mostly reshuffling.

**Evidence.** `wc -l`: 2428 -> 2420. Lines read.

**Fix.** Take the cuts above (and R10's), keeping the snapshot identical. The
cross-file duplicates (`MaskRound`, `PlayerFaction`) belong to the later PR
as agreed; they are listed under Redundant code below.

### R6 · Local `OnMapFloor` shares its name with `ns.UI.OnMapFloor` but means more
- **Severity:** nit
- **Area:** Readability (searchable names, disinformation)
- **Where:** `NeedRoll/UI/Lists.lua:1971-1980`, used at `:2008`
- **Status:** fixed in round 2 (uncommitted). Renamed `LitByMapFloor` (`Lists.lua:1980`).

**What's wrong.** The new local `OnMapFloor(entry)` is true for a boss on the
map's floor (what `ns.UI.OnMapFloor` returns) **and** for a wing row holding
one, and false for headers. It calls `ns.UI.OnMapFloor` inside. Before the
change it was `OnFloor`, a distinct name.

**Why it matters.** Grepping `OnMapFloor` now finds two functions with
different answers for a wing row; a reader of `AfterRow` will assume the
Overview's meaning.

**Fix.** Name it for what it decides, e.g. `LitByMapFloor(entry)` or
`HasBossOnMapFloor(entry)`.

### R7 · `opts.entryHeight` is now required; the doc reads as if it were optional
- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/Lists.lua:65-66` (doc), `:133` (use)
- **Status:** fixed in round 2 (uncommitted). The doc says "(required; it returns nil for rowHeight)" (`Lists.lua:67`); its wrapping is R13.

**What's wrong.** `pane:EntryHeight` now calls `opts.entryHeight(entry)`
without a check (the base had `opts.entryHeight and opts.entryHeight(entry) or pane.rowHeight`).
The doc block lists it as `` `opts.entryHeight(entry)` (nil for rowHeight) ``
in the same sentence as options that are optional.

**Why it matters.** Both current callers pass it (`grep -n "entryHeight" NeedRoll/`),
so nothing breaks today; a third list made from this doc without it errors on
its first draw ("attempt to call field 'entryHeight' (a nil value)").

**Fix.** "`opts.entryHeight(entry)` (required; return nil for `rowHeight`)".

### R8 · Four comments misplaced, appended or stale
- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `NeedRoll/UI/Lists.lua:36-41`, `:571-574`, `:1336`, `:1624`
- **Status:** fixed in round 2 (uncommitted). The slide paragraph sits above `StartSlide` with a one-line `StopSlide` comment; the Classic Raids comment lost the wing aside; `groupOf` says "the key of the group it is listed under"; BossLevel says "The second value says whether the boss is a rare."

**What's wrong.**
- `:36-40`: the paragraph describing how a slide works (`pane:Rebuild()`
  totals the heights, the strip grows...) sits above `StopSlide`, a
  three-line function that does none of that; it describes `StartSlide`.
- `:571-574`: the Classic Raids comment ends with "(Dungeon wings, such as
  Scarlet Monastery's, are rows of their own.)", which is about the dungeon
  list, not this table. Two chained colons ("into "Classic Raids", a group at
  the end of the raid list: a header row that...") make the sentence hard to
  parse.
- `:1336`: `local groupOf = {}  -- entry -> its group's key, in a dungeon`;
  it also holds profession groups (`RECIPES`, `SCARCE`, `INCLUDED`) and
  colour sets (`SET:..`), as `InColourSet` on line 1349 shows.
- `:1624`: "-- Also whether the boss is a rare." added as a separate line
  after the BossLevel paragraph reads like narration.

**Fix.** Move the slide paragraph above `StartSlide` (one line on
`StopSlide` is enough); drop the wing parenthetical and split the sentence;
"entry -> the key of the group it is listed under"; fold the rare clause
into the first sentence ("...nil for rows that aren't bosses; and whether
the boss is a rare").

### R9 · Test helper `IndexOf` has a different contract from the addon's `IndexOf`
- **Severity:** nit
- **Area:** Readability (tests)
- **Where:** `tests/smoke/modules/UI-Lists.lua:16-20`
- **Status:** fixed in round 2 (uncommitted). Renamed `FindEntry(entries, matches)`.

**What's wrong.** The test's `IndexOf(entries, test)` takes a predicate and
returns index and entry; `Lists.lua:27` `IndexOf(list, value)` compares by
equality and returns the index. Same name, different meaning, in the two
files a reader opens side by side.

**Fix.** Rename the test helper `FindEntry(entries, matches)`.

### R10 · Crest slot placed with a gap that can't apply; quest row silently relies on it
- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/Lists.lua:1312`, `:1860-1862`
- **Status:** fixed in round 2 (uncommitted). `ShowCrests` places the slot at the right edge directly and sets `row.iconEdge` (`Lists.lua:1302-1305`); `ShowQuestIcons`' comment says a quest row's `iconEdge` is never nil.

**What's wrong.** `ShowQuestIcons` sets `row.iconEdge = nil` and then calls
`ShowCrests`, which ends with `PlaceLeftOfIcons(row, row.crestStack, 4)`.
With no edge yet, the `4` is never used. `SetupQuestRow` then anchors
`row.right` to `row.iconEdge` with no fallback, which is only safe because
`ShowCrests` always places the crest slot for a quest; nothing says so.

**Why it matters.** A reader tries to work out what the 4 px gap is for, and
someone who later hides crests for a quest gets "SetPoint: invalid
relativeTo" from `SetupQuestRow`.

**Fix.** Pass `0`, or place the slot directly with
`row.crestStack:SetPoint("RIGHT", row, "RIGHT", -S.pad, 0)` and set
`row.iconEdge = row.crestStack`. Add a few words in `ShowQuestIcons`' comment:
"a quest row always has the crest slot, so iconEdge is never nil after this".

### R11 · `header` is a yes/no in some new helpers and the header entry in their neighbours
- **Severity:** should fix
- **Area:** Readability (meaningful names, avoid mental mapping)
- **Where:** yes/no: `NeedRoll/UI/Lists.lua:1344` `ShowChainStep(row, enc, header)`, `:1369` `ShowArrows(row, enc, header)`, `:1929` `local header = HeaderLike(enc)` in `SetupRow`. Entry: `:1820` `ShowSideToggle(row, header)`, `:1841` `ShowQuestCount(row, header, sides)`, `:1860` `SetupHeaderRow(row, header)`.
- **Status:** fixed after round 2 (`isHeader`)

**What's wrong.** Splitting `setupRow` turned one local into six function
parameters, and the name `header` now means two things. In `SetupRow`,
`ShowChainStep` and `ShowArrows`, `header` is the result of `HeaderLike(enc)`,
a yes/no (`enc.header or (pane.grouped and enc.overview)`). In
`SetupHeaderRow`, `ShowSideToggle` and `ShowQuestCount`, `header` is the
header **entry**, a table read as `header.key`, `header.badge`, `header.atlas`.
`SetupRow` passes both in the same block:

```lua
ShowArrows(row, enc, header)   -- header: true/false
...
if header then
    SetupHeaderRow(row, enc)   -- header (inside): the entry
```

**Why it matters.** `docs/READABLE-CODE.md` §1 says booleans read as a
yes/no question and §8 says the reader shouldn't have to remember which
meaning a name has. A reader moving from `ShowArrows` to `ShowSideToggle`
sees `header` in both and has to check whether `header.key` can work.
Before the split this was one local in one closure, so the two meanings
never met; the change made it a signature, on file-level helpers other code
can now call.

**Evidence.** Lines read; `grep -n "header)" NeedRoll/UI/Lists.lua`.

**Fix.** Rename the yes/no to `isHeader` in `SetupRow`, `ShowChainStep` and
`ShowArrows` (`local isHeader = HeaderLike(enc)`); keep `header` for the
entry. Six lines, no behaviour change.

### R12 · The crest nudge is described as conditional but always applies
- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `NeedRoll/UI/Lists.lua:1059`, `:1856`
- **Status:** fixed after round 2

**What's wrong.** `QUEST_CREST_NUDGE = 6 -- how much nearer the arrow they sit when no count is beside it`
and, in `ShowQuestCount`, "-- With no count on the right, the crests move up
to the arrow." Quest headers never have a count on the right: `SetupRow`
clears `row.right` for every row and `ShowQuestCount` writes the count under
the title, so the nudge always applies. I missed this in round 1; the base
had an `empty and QUEST_CREST_NUDGE or 0` test that was already always true.

**Fix.** "-- The count is under the title, so the crests sit nearer the
arrow." and `-- how much nearer the arrow the crests sit (the count is under the title)`.

### R13 · Comments point at `afterRow` and two are wrapped unevenly
- **Severity:** nit
- **Area:** Readability (comments, formatting)
- **Where:** `NeedRoll/UI/Lists.lua:1383`, `:1405`, `:67`, `:696`
- **Status:** fixed after round 2

**What's wrong.** `NewHeaderDisc` ("afterRow rings it in gold") and
`NewShutCard` ("afterRow shows it") now sit at file level, far from the
list's options; the work is done by `PaintHeader`, a few lines below them.
`:67` and `:696` were edited in place and run to 98 and 88 characters
inside paragraphs wrapped at about 76.

**Fix.** Say `PaintHeader` in both comments; rewrap the two paragraphs.

### R14 · Two tests leave groups and wings open for the tests after them
- **Severity:** nit
- **Area:** Readability (tests)
- **Where:** `tests/smoke/modules/UI-Lists.lua:213-259` ("a dungeon's Overview, Quests and Encounters"), `:302-325` ("Stratholme's wings")
- **Status:** fixed after round 2 (restore selects Deadmines after `ClearHistory()`)

**What's wrong.** Both open groups (`ToggleGroup("QUESTS")`, `OpenWing`) and
`restore` only calls `ui:ClearHistory()`. The encounter list keeps open
groups until the instance changes, so Scholomance stays with Quests open and
Stratholme with a wing open. Later tests use `SelectFresh`, which avoids it,
so nothing fails today. These are UI state, not stand-in functions or saved
settings, so the brief's rule doesn't strictly require it.

**Fix.** In `restore`, select another instance (or call `SelectFresh`) so
the groups reset.

## Area notes

### Readability

Checked every changed function against `docs/READABLE-CODE.md`. Sound:
- Names: `k` -> `parts`, `At` -> `PlaceAt`, `Clear` -> `Transparent` (it never
  cleared anything), `two` -> `twoDigits`, `members`/`done` -> `chainOf`/`placed`,
  `marker` -> `levelLine`, `top` -> `rowCount`, `GroupOpen(key)` -> `open[key]`,
  `GROUPS` -> `INSTANCE_HEADERS` (built as header rows directly, no
  `Headers()` copy). `try` -> `longer`, `fs` -> `fontString`. No one-letter
  names outside the allowed aliases except loop indexes.
- Constants: `NOTE_ROW`, `GROUP_ROW`, `MARKER_ROW`, `SLIDE_SECONDS`,
  `LABEL_Y`, `CLASS_RING`, `STACKED_CREST`, `SET_MEMBER_INDENT`,
  `QUESTION_ICON` all now named and commented; `GROUP_HEADER` and `GROUP_ROW`
  (both 40) are one constant.
- Single responsibility: `setupRow` (was ~230 lines) is now `SetupRow`
  (50 lines) dispatching to `SetupHeaderRow`, `SetupQuestRow`,
  `SetupEncounterRow` and the `Show*` helpers; `Refresh` lost the row-pool
  and row-fill blocks. Nesting: the deepest new body is three levels
  (`ShowCrests`).
- Fixed a wrong comment (`STANDING_REACTION`: "4 = Neutral", it was
  "5 = Friendly ... ") and removed an orphan half-sentence ("Dungeons split
  the middle column into...").
- Lua 5.1 traps: no `cond and nil or x`; `local steps, at = a and f()`, the
  trap that made the chain call a no-op, is gone; no `#t` on holey tables
  (`list[i + 1]` past the end is nil, as before); no data-built patterns
  (`key:match("^SET:")`, `("^WING:(.+)")` use constant patterns).
- Formatting: 4 spaces, LF, no line over 120 (the base had 7).

Findings: R1, R3, R6, R7, R8, R9, R10. Round 2: R11, R12, R13, R14.

Round 2 re-read of every changed function, and behaviour checks on the new
edits (the snapshot is byte-identical in all three modes as well):
- Instance list: `IsClassicRaid(inst)` is `GroupOf`'s test with a yes/no
  result; `ScrollTo` still skips headers and markers (they have no
  `category`); `lastMember` is `not isMember[list[i + 1]]`, as before with one
  group. `ShowProfessionIcon` now runs for marker and header rows too, which
  hides a leftover profession icon the same way the removed
  `if row.profIcon then row.profIcon:Hide() end` lines did (a marker or header
  has no `category`, so no icon).
- Encounter list: `row.right:SetText("")` moved to one place in `SetupRow`,
  before the per-kind setup. Every branch that set it to `""` before still
  ends with `""`; Included In's count and a recipe's skill are written after
  it. `PaintHeader(row, isActive)` takes the yes/no its caller works out.
- File-level helpers: `ShowRankIcon(row, enc, instance)` and
  `ShowRecipeIcon(row, enc, instance)` take the instance instead of reading
  `pane`, `SetupQuestRow` relies on `ShowQuestIcons` having run (now said in
  its comment). Names other than R11 read well.
- Further cuts: none worth another round. The remaining length is the split
  functions' comments, which `docs/READABLE-CODE.md` §5 asks for.

Behaviour, checked by reading and by the snapshot (byte-identical in three
modes):
- `ChainSpot`: the removed call was `local steps, at = ns.Data.Chain and ns.Data:Chain(quest.id, faction, class)`.
  An `and` expression yields one value, so `at` was always nil and
  `if steps and at` never ran; `ns.Data:Chain` (`Data.lua:303-327`) only
  reads tables. Removing it, and the then-unused `faction` argument of
  `ChainSpot`/`ChainTrees`, changes nothing. Note for Mike, not this PR: the
  list's chain trees therefore use only each quest's own `chainStart`/`chainStep`
  fields and never `Data/Chains.lua`, unlike the Overview
  (`Overview.lua:387` calls it correctly). Making the list use it would change
  what players see.
- Instance `Entries()`: the "Level N" line is still placed before the first
  ungrouped dungeon whose minimum level is above yours; the Classic Raids
  header still goes last with members in sorted order; bands skip members and
  the marker as before.
- Encounter `Entries()`: the base computed a kid's height in the grouped list
  with its own formula (`marker and MARKER_ROW or tall and CHILD_NOTE_ROW or CHILD_ROW`);
  the change uses `RowHeight`, the list's own `entryHeight`. They differ only
  for a kid that is `topRow` (impossible: Included In excludes the matches,
  `RecipeMatches` line 2088) or `HeaderLike` (no data entry has `header`;
  `overview` is added only to dungeons and raids, `Data.lua:93`, and is never a
  kid). The slide totals summed by `AddIfOpen`/`AddRows` include nested open
  wings and sets as the base's shared `total` did.
- `ScrollTo`, `MaxOffset`, the right-click branch in `NewRow`, `onClick`'s
  Shift guard for colour sets, `ShowQuestCount`'s crest nudge (the base's
  `empty` was always true since every branch set `row.right` to ""), and
  `GroupKeyFor` match the base case for case.

### WoW API

No new game function, event, template or atlas. Guards removed on calls that
Forever has, checked in Ketho's `forever` lists (downloaded
2026-10-17 to the scratchpad and grepped):

| Call | Where | In `forever` lists | Looked in |
| --- | --- | --- | --- |
| `C_Spell.GetSpellTexture` | `Lists.lua:498, 542` | yes | `GlobalAPI.lua:3958` |
| `SetPropagateMouseClicks` (Frame) | `Lists.lua:523` | yes (ScriptRegion) | `WidgetAPI.lua:129` |
| `SetSnapToPixelGrid` (Texture) | `Lists.lua:624` | yes (TextureBase) | `WidgetAPI.lua:273` |
| `SetTexelSnappingBias` (Texture) | `Lists.lua:625` | yes (TextureBase) | `WidgetAPI.lua:276` |
| `CreateMaskTexture`, `AddMaskTexture` (moved into `MaskRound`) | `Lists.lua:21, 24` | yes | `WidgetAPI.lua:554, 287` |
| `UnitFactionGroup` (now via `PlayerFaction`) | `Lists.lua:1114` | yes | `GlobalAPI.lua:6677` |

The stand-in client has all of them (`tests/smoke/wow.lua:171-172, 1558`).

Addon guards removed, and why each is safe in dev and packaged builds:

| Removed guard | Defined at | Why it exists before any row draws |
| --- | --- | --- |
| `ns.Data.Chain` | `Data/Data.lua:303` | call removed altogether (see Readability) |
| `ns.RecipeBand` | `UI/RecipeBand.lua:17`, file scope | `UI.xml` loads `RecipeBand.lua` after `Lists.lua`, but `Lists.lua` reads it only inside functions (`NarrowRecipes`, `LayOutTop`, `Note`) that run after login. Not in `.pkgmeta` ignore, not inside `@debug@`. |
| `ns.UI.MapFloorPin`, `ns.UI.OnMapFloor`, `ns.UI.MapFloorShown` | `UI/Overview.lua:2628-2638`, directly in `CreateOverview`'s body | `MainFrame.lua` builds the encounter list (line 988) and then the Overview (line 1002) in the same synchronous build, with nothing between that sets data or draws rows; the list has no entries until a tab is picked. `Overview.lua` ships in both builds. |
| `ns.UI.overview` | `MainFrame.lua:1002` (`self` is `ns.UI`) | only read in the row's `OnEnter`/`OnLeave` hooks, i.e. on hover after the window is built |

All three smoke modes, including `--packaged` (which drops the `@debug@`
files), pass, and the snapshot is identical in each. Events: unchanged
(`PLAYER_LEVEL_UP`, `QUEST_TURNED_IN`, `QUEST_ACCEPTED`, `QUEST_REMOVED`, all
persistent). No secure frames, no combat-sensitive calls, no new globals
(W11 list identical). Upvalues: R2. No player-facing text added or changed;
`L["..."]` keys untouched.

### Redundant code

Compared against: `T:RoundedOn`, `T:Rounded`, `T:Arrow`, `T:FitAtlas`,
`T:Insignia`, `T:InsigniaSize`, `T:ClassBadge`, `T:ScrollView`, `T:Row`,
`T:Text`, `T:SetTextColor`, `T:ColorCode`, `T:ScaledFont`, `T:LineWidth`
(`grep -n "^function T:" NeedRoll/UI/Theme.lua`): the change uses them and
adds no duplicate. There is no round-mask helper in Theme (Theme only has a
local `ROUND_MASK`, line 860), so `MaskRound` is new and justified here.

Removed in this change: the second slide animation, three mask blocks,
`RoundTexture`, `Headers()` copying, `PlaceTitleIcon` and `titleIcon`
(nothing sets `row.titleIcon` in either list; `MainFrame.lua:691`'s
`f.titleIcon` is unrelated), the `crests` fallback loop in the quest branch
(the crest slot is always shown for a quest), `GroupOpen`, `FitFrom` +
`MaxOffset` duplicate loops (now `CountFitting`), public
`ns.UI.ChainBranch`/`PlaceChainBranch` (no caller outside the file:
`grep -rn "ChainBranch" NeedRoll/ tests/`).

Findings: R4, R5.

Cross-module (for the later PR, not this one):
- `MaskRound` (`Lists.lua:20`) vs the same three lines at `Overview.lua:70`,
  `Overview.lua:2018`, `IconDebug.lua:473`; the mask path is also a local in
  `LootGrid.lua:428, 1459`, `Theme.lua:860`, `FrameDebug.lua:23`,
  `LineDump.lua:12`, `RecipeBand.lua:45`. Candidate `T:MaskRound`.
- `PlayerFaction` (`Lists.lua:1113`) vs `Core/Tooltip.lua:116` and
  `Overview.lua:3162`.
- Same dead guards in other groups: `Overview.lua:278` and
  `LootGrid.lua:953` (`SetPropagateMouseClicks`), `IconDebug.lua:392`
  (`C_Spell and C_Spell.GetSpellTexture`), `Overview.lua:387`
  (`if ns.Data.Chain`).
- `docs/STYLE-GUIDE.md:119` (R3).

### Security

None: the change touches no addon messages, chat, SavedVariables, `Credits.txt`,
packaging or workflows. No text from other players is shown by these lists.

## Round history

- 2026-10-18, `c0e5c79` + uncommitted, round 1: **Changes needed**; opened
  R1-R10 (5 should fix, 5 nits), none closed.
- 2026-10-18, `c0e5c79` + uncommitted (round 2 edits), round 2: **Changes
  needed**; closed R1-R10, opened R11 (should fix) and R12-R14 (nits).
