# Review: `/nr icondebug` "All icons" search by atlas name; the search box moves to `T:SearchBox` with a modern clear cross

| | |
| --- | --- |
| Branch | `icon-search` worktree, stacked on the shared-helpers group (`ae013b0`, open as PR #609, not merged). PR not opened yet |
| Commit reviewed | `b3cd337` (round 3: `281389f..b3cd337`; round 2 `6ba92f9`; round 1 `b3f10da`; whole group `ae013b0..b3cd337`), no uncommitted changes |
| Date | 2026-10-18 |
| Round | 3 (last) |
| Verdict | **Ready**, with one nit for Mike to decide (0 blocking, 0 should fix, 1 nit open: R10; R1-R9 fixed, R6's generator sentence left as is) |
| Needs | `/reload` (Lua only: no file added to or removed from the `.toc` or `UI/UI.xml`, no SavedVariables key or format change; the new `tests/smoke/modules/UI-Theme.lua` isn't loaded by the game) |

## What the change does

Mike asked (2026-10-17) for "a proper search to /nr icondebug". In a local checkout, the
"All icons" view of `/nr icondebug` now has a search box in a 32 px strip over the list.
Typing filters the ~10,000 atlases of `Data/IconList.lua` by a case-insensitive substring
of their name: only sections with a match are listed, each opens onto its matches, a
section header counts its matches, and a count beside the box reads "N of 10,368 atlases
match" ("10,368 atlases" when empty). Folding a section during a search lasts until the
next keystroke. Escape or the clear button empties the box and brings back the fold state
the sections had before the search, scrolled to the top. Lowercased names are made once
per section, the first time it is opened or searched. The Curated view isn't filtered.

To get there, MainFrame's private `CreateSearchBox`/`CreateNativeSearchBox`/`SetSearchKeys`
moved into `UI/Theme.lua` as `T:SearchBox(parent, hintText, width, onChange, onFocus)`.
The modern box gained a 14 px clear cross (drawn with the `close` strokes `T:Pill` uses,
now shared as the local `SymbolStrokes`), and its right text inset went from 8 to 22
(`T.SEARCH_TEXT_RIGHT`). Players on the modern skin see the cross in the top bar search
and in "Filter recipes"; everything else about those two boxes should be unchanged
(checked under "Behaviour checks" below; round 1 found one exception, R2, fixed in round 2). Since round 2 the "All icons" box is always modern, like the rest of the debug window, through a new optional `skin` argument on `T:SearchBox`.

## Scope

- `NeedRoll/UI/IconBrowser.lua` (dev-only, `.pkgmeta`-ignored): search strip constants,
  `MatchingIcons`, lowercased names in `SplitIcons`, `BuildSearch`, `SetQuery`,
  `ShowCount`, `IsOpen`, `ShownCount`, `ShownIcon`; `Build`, `Layout`, `Fold`, `Fits`,
  `FillRow`, `Repaint` adapted. Read in full (318 lines).
- `NeedRoll/UI/IconDebug.lua`: header comment only (ships in releases; the change is a
  comment).
- `NeedRoll/UI/MainFrame.lua`: drops `SetSearchKeys`, `CreateNativeSearchBox`,
  `CreateSearchBox`; the top bar and recipe filter call `T:SearchBox`; `UI:SizeTopBar` uses
  `T.SEARCH_TEXT_RIGHT`. Read `SizeTopBar`, `CreateTopBar`, `CreateLists` and every use of
  `UI.search`/`UI.recipeFilter`/`SetTextQuietly`.
- `NeedRoll/UI/Theme.lua`: `SymbolStrokes` (out of `T:Pill`), `SetSearchKeys`,
  `NativeSearchBox`, `AddClearButton`, `T:SearchBox`, `T.SEARCH_TEXT_RIGHT`; header
  comment. Read with `T:Pill`, `T:Input`, `T:GlideTo`, `T:WheelScroll`, `T:ScrollView`,
  `T:ScrollBar` for context.
- `docs/STYLE-GUIDE.md`: top bar search insets; new "Search box" widget row.
- `tests/smoke/modules/UI-IconBrowser.lua`: new scenario "the search filters atlases by
  name, counts them and clears" (dev only).
- `tests/smoke/modules/UI-Theme.lua` (new): "the search box reports its text and clears",
  both skins.
- `tests/smoke/wow.lua`: `SearchBoxTemplate`'s `clearButton` now empties and leaves the box,
  as the game's `SearchBoxTemplateClearButton_OnClick` does.

No generated data is touched. `Data/IconList.lua` and `tools/make_icon_list.py` are
unchanged (R6 mentions a now-stale comment the generator writes).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 7 changed Lua files | passed |
| `python3 tools/locales.py --check` | passed (exit 0; `enUS.lua` untouched, no new `L[...]`) |
| `python3 tools/translations.py` | exit 0; the same 50 pre-existing "not used by NeedRoll any more" lines as PR #609 (5 keys × 10 locales), none from this diff |
| `luacheck --no-global -q`, changed files vs `ae013b0` | no new warnings: Theme has 38 `shadowing upvalue argument 'self'` before and after (line numbers shifted only); IconBrowser, IconDebug, MainFrame, UI-IconBrowser, wow.lua unchanged; new UI-Theme.lua clean |
| `tests/smoke/check.sh` | passed: dev, packaged and secret runs all "all passed" (937 `ok` lines). The new IconBrowser scenario runs in the dev and secret runs, the Theme scenario in all three |
| Upvalues (`luac5.1 -l`) | largest in Theme 7, MainFrame 11, IconBrowser 8; `CreateOverview` untouched |
| Line length / CRLF | no new line over 120; no CR in the changed files |
| Scraper unit tests | not run: no scraper change |
| Probe (scratch copy, not committed) | first list line's row is anchored at `y = -4` while the clip window starts at 36: see R1 |
| Timing on the full list (`lua5.1`, desktop) | splitting all 16 sections (10,368 atlases) 9 ms once; each search 0.8-1.2 ms ("a": 9,393 matches); Lua memory after splitting all ≈ 2 MB |
| Round 2: `luac5.1 -p`, 5 Lua files changed in `f732420..6ba92f9` | passed |
| Round 2: `locales.py --check` / `translations.py` | passed / exit 0, the same 50 pre-existing lines |
| Round 2: `luacheck --no-global -q` vs `f732420` | no change in any changed file (IconBrowser 0, IconDebug 0, MainFrame 5, Theme 71, UI-IconBrowser 0 lines of output, before and after) |
| Round 2: `tests/smoke/check.sh` | passed: all three runs "all passed", 937 `ok` lines |
| Round 2: mutation probes (scratch copy of `6ba92f9`, not committed) | putting `INSET` back in `Draw` fails the scenario at `UI-IconBrowser.lua:136`; removing the R7 early return fails it ("a trailing space redid the search"); a row at `y = -30` (still 6 px clipped) passes, see R9 |
| Round 2: new lines over 120 / CRLF | none |
| Round 3: `luac5.1 -p`, 4 Lua files changed in `281389f..b3cd337` | passed |
| Round 3: `locales.py --check` / `translations.py` | passed / exit 0, the same 50 pre-existing lines |
| Round 3: `luacheck --no-global -q` vs `281389f` | no change (IconBrowser 0, MainFrame 5, Theme 71, UI-IconBrowser 0) |
| Round 3: `tests/smoke/check.sh` | passed: all three runs "all passed", 937 `ok` lines |
| Round 3: mutation probes (scratch copy of `b3cd337`) | rows at `y = -4` (`INSET`), `-30` and `-40` each fail the scenario with "the first line starts N px down, but the list starts 36 px down"; the shipped `LIST_TOP` passes |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | blocking | WoW API (frame layout) | `UI/IconBrowser.lua:300` | Rows are still drawn from `INSET`, so the first line hides under the search strip | fixed in round 2 (`6ba92f9`) |
| R2 | should fix | Readability (behaviour stays the same) | `UI/MainFrame.lua:705`, `docs/STYLE-GUIDE.md:38` | The top bar hint lost 14 px of room for a cross it never shares the box with | fixed in round 2 (`6ba92f9`) |
| R3 | nit | Readability (consistency) | `UI/IconBrowser.lua:126` | The "All icons" search box follows the addon skin; the rest of the debug window is always modern | fixed in round 2 (`6ba92f9`) |
| R4 | nit | Redundant code | `UI/Theme.lua:965-968`, `1002-1005` | The clear cross repeats the Escape handler's body | fixed in round 2 (`6ba92f9`) |
| R5 | nit | Readability (searchable names) | `UI/Theme.lua:985-991`, `1049`; `UI/MainFrame.lua:704-707`; `UI/IconBrowser.lua:25` | One inset, two names; the clear-button comment sits over the constants; bare `20`s and an uncommented `SEARCH_W` | fixed in round 2 (`6ba92f9`) |
| R6 | nit | Readability (comments) | `UI/IconBrowser.lua:5,177`; `docs/STYLE-GUIDE.md:101`; `UI/IconDebug.lua:9-10`; `tools/make_icon_list.py:128` | Comments now say things the code doesn't | fixed in round 2 (`6ba92f9`), except the optional `make_icon_list.py` sentence: left as is (changing the generator alone would put it out of step with the generated header) |
| R7 | nit | Readability (behaviour) | `UI/IconBrowser.lua:158-175` | A keystroke that leaves the query unchanged still refolds and jumps to the top | fixed in round 2 (`6ba92f9`) |
| R8 | nit | Readability (comments) | `UI/MainFrame.lua:674-682`, `UI/Theme.lua:1015`, `UI/IconBrowser.lua:9` | The round 2 fixes moved two comments away from, or off, what they describe | fixed in round 3 (`b3cd337`) |
| R9 | nit | WoW API (smoke coverage) | `tests/smoke/modules/UI-IconBrowser.lua:134-137` | The new placement assertion lets a still-clipped row pass, and its message states the good case | fixed in round 3 (`b3cd337`) |
| R10 | nit | Readability (comments) | `tests/smoke/modules/UI-IconBrowser.lua:39` | `TopOffset`'s comment reads as the parent's anchor | fixed at integration (comment reworded) |

### R1 · Rows are still drawn from `INSET`, so the first line hides under the search strip

- **Severity:** blocking
- **Area:** WoW API (frame layout and clipping)
- **Where:** `NeedRoll/UI/IconBrowser.lua:300` (with `:143`, `:24`)
- **Status:** fixed in round 2 (`6ba92f9`)

**What's wrong.** The clip window moved down to make room for the search strip, but the
rows didn't:

```lua
local LIST_TOP = SEARCH_ROOM + INSET                     -- 36
self.canvas = T:ScrollView(pane, LIST_TOP, INSET)        -- clip window from 36 px down
...
local y = -(INSET + i * ROW_H - shift)                   -- Draw: rows from 4 px down
row:SetPoint("TOPLEFT", 1, y)
```

`T:ScrollView` (`Theme.lua:1571-1588`) clips at `top` but lays the canvas "exactly over
the pane. What's drawn on the canvas keeps the pane's coordinates". Every other user adds
the window's top to its rows: `Lists.lua:160` anchors at `-pane.listTop - y`, and
`DevKit.lua:279` uses the same `LIST_INSET` it clips at. Before this change IconBrowser
clipped at `INSET` and drew at `INSET`, so it matched; now it clips at 36 and draws at 4.

**Why it matters.** At scroll offset 0 the first line spans 4-60 px under the pane top and
only 36-60 is inside the window: 32 of its 56 px are cut off. The first section header's
title and count are centred at 32 px, right on the clip edge, so they are cut in half; while
searching, the first line is the header of the first matching section, so the section a
search opens first is the one you can't read. Scrolling by one line skips past it, so it is
never fully visible. At the bottom, `Fits()` and `MaxOffset()` count lines for a window that
starts at 36, so the last line ends 32 px above the window's bottom edge, leaving an empty
band. (The on-screen look is inferred from the anchors; it wasn't seen in the client.)

**Evidence.** Read `IconBrowser.lua:143,291-309` and `Theme.lua:1571-1588`. Probe run in a
scratch copy of `b3f10da` (`tests/smoke/run.lua --only`), opening "All icons" and reading the
first shown row's anchor: `PROBE first line row y: -4  clip top (LIST_TOP): 36`. The smoke
scenarios pass because none checks where a row sits.

**Fix.** Draw from the window's top:

```lua
local y = -(LIST_TOP + i * ROW_H - shift)
```

and add an assertion to the IconBrowser scenario that line 1's row is anchored at
`-LIST_TOP` (e.g. `select(5, RowFor(browser, 1):GetPoint(1)) == -36`, or expose the
constant on `IconBrowser`), so the strip and the rows can't drift apart again.

### R2 · The top bar hint lost 14 px of room for a cross it never shares the box with

- **Severity:** should fix
- **Area:** Readability ("Behaviour stays the same": only the cross was meant to change)
- **Where:** `NeedRoll/UI/MainFrame.lua:705`; `docs/STYLE-GUIDE.md:38`
- **Status:** fixed in round 2 (`6ba92f9`)

**What's wrong.** `UI:SizeTopBar` anchors the hint's right end with the same inset as the
typed text:

```lua
hint:SetPoint("RIGHT", search, "RIGHT", -(native and 20 or T.SEARCH_TEXT_RIGHT), 0)  -- was -8 (modern)
```

The cross is shown only while the box holds text (`editBox.clearButton:SetShown(editBox:GetText() ~= "")`,
`Theme.lua:1038`) and the hint only while it is empty and unfocused (`Theme.lua:1037`), so
the two never show together (the one exception is a box holding only spaces). The typed
text needs the 22 px inset; the hint doesn't.

**Why it matters.** The hint is a one-line font string (`T:Text` sets `SetWordWrap(false)`)
pinned at both ends, so anything wider than its room ends in "...". Mike tuned the top bar
so "the hint fits on one line" (`MainFrame.lua:680-681`), and its translations run up to
the ruRU "Поиск добычи, боссов, подземелий, заданий" and esES/itIT/ptBR at 40-44 characters.
With 14 px less room a long translation that fitted may now be cut off, a visible change
on the modern skin beyond the cross. Whether any locale actually truncates at the default
size wasn't measured (inferred; the client's font widths aren't available here).

**Evidence.** `git diff ae013b0..b3f10da -- NeedRoll/UI/MainFrame.lua` (lines 704-707);
`Theme.lua:1035-1046`; `grep '"Search loot, bosses, dungeons, quests"' NeedRoll/Locales/*`.

**Fix.** Keep the hint's old right inset and give only the typed text the cross's room:

```lua
search:SetTextInsets(left, native and 20 or T.SEARCH_TEXT_RIGHT, 0, 0)
hint:SetPoint("RIGHT", search, "RIGHT", native and -20 or -8, 0)
```

and say in `docs/STYLE-GUIDE.md:38` that the typed text stops 22 short (modern) and the hint
8, and fix the `SEARCH_TEXT_RIGHT` comment (`Theme.lua:989`, "the typed text's and hint's
room"), which then describes the typed text only.

### R3 · The "All icons" search box follows the addon skin; the rest of the debug window is always modern

- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** `NeedRoll/UI/IconBrowser.lua:126`
- **Status:** fixed in round 2 (`6ba92f9`)

**What's wrong.** The debug windows are built in the modern look whatever the addon's
skin: `IconDebug.lua:21-22` and `DevKit.lua:11-13` use `T:Palette("modern")` and
`T:Fonts("modern")`, and the preview box 40 px above the list is a hand-built modern
rounded box (`IconDebug.lua:459-469`). `T:SearchBox` picks by `T.native`, the player's
skin, and `T:SetSkin("native")` is the default (`Theme.lua:285`). So on the default skin
the "All icons" search is the game's gold-framed `SearchBoxTemplate` under a modern preview
box; on the modern skin it's the rounded box.

**Why it matters.** Dev tool only, but the window then has two different text box looks a
few pixels apart, and the background switch (modern/native) doesn't touch either.

**Evidence.** Lines quoted above.

**Fix.** Either build the browser's box modern regardless (e.g. an optional `skin`
argument on `T:SearchBox`, or `T:SetSkin("modern")` around the call and back), or keep it
and note in the style guide row that the icon browser's box follows the addon skin.

### R4 · The clear cross repeats the Escape handler's body

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Theme.lua:965-968` and `1002-1005`
- **Status:** fixed in round 2 (`6ba92f9`)

**What's wrong.** "Clearing works like Escape" (`Theme.lua:987`) is done by copying it:

```lua
box:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
end)
...
clear:SetScript("OnClick", function()
    box:SetText("")
    box:ClearFocus()
end)
```

**Why it matters.** `docs/READABLE-CODE.md` §6/§7: one way of doing each thing. If what
Escape does ever changes (say, it also restores something), the cross silently stops
"working like Escape".

**Evidence.** Lines quoted.

**Fix.** One local, used by both:

```lua
-- Empties a search box and leaves it, as Escape and the clear cross do.
local function ClearSearch(box)
    box:SetText("")
    box:ClearFocus()
end
box:SetScript("OnEscapePressed", ClearSearch)
clear:SetScript("OnClick", function() ClearSearch(box) end)
```

### R5 · One inset, two names; the clear-button comment sits over the constants; bare `20`s and an uncommented `SEARCH_W`

- **Severity:** nit
- **Area:** Readability (searchable names, consistency)
- **Where:** `NeedRoll/UI/Theme.lua:985-991`, `1049`; `NeedRoll/UI/MainFrame.lua:704-707`;
  `NeedRoll/UI/IconBrowser.lua:25`
- **Status:** fixed in round 2 (`6ba92f9`)

**What's wrong.**
- The inset is a local `SEARCH_TEXT_RIGHT` and, after the function, a second name
  `T.SEARCH_TEXT_RIGHT = SEARCH_TEXT_RIGHT` with its own comment. Theme's other shared
  values (`T.DOTS`, `T.lineWidth`, `T.iconCrop`, `T.roundMask`) are one `T.` field defined
  above their first use.
- The comment describing `AddClearButton` (`:985-987`) is separated from the function by
  the two constants, so it reads as a comment on `SEARCH_CLEAR_SIZE`.
- In the two `SizeTopBar` lines this change rewrote, the native inset is still a bare `20`
  twice, beside the modern one that now has a name.
- `SEARCH_W = 260` is the only constant in IconBrowser's block without a comment saying
  what it measures.

**Why it matters.** §7 searchable names and §5 comments: a reader grepping for the
native inset, or reading the clear-button comment, has to work out what goes with what.

**Fix.** Define `T.SEARCH_TEXT_RIGHT = 22` once (with its comment) and use it inside
`T:SearchBox` too; put the clear-button comment directly over `AddClearButton`; name the
native inset (e.g. a local `NATIVE_SEARCH_RIGHT = 20 -- the template's clear button`) or
note it once; and comment `SEARCH_W` ("the search box's width").

### R6 · Comments now say things the code doesn't

- **Severity:** nit
- **Area:** Readability (comments, disinformation)
- **Where:** `NeedRoll/UI/IconBrowser.lua:5`, `:177`; `docs/STYLE-GUIDE.md:101`;
  `NeedRoll/UI/IconDebug.lua:9-10`; `tools/make_icon_list.py:128`
- **Status:** fixed in round 2 (`6ba92f9`), except the optional `tools/make_icon_list.py:128` sentence: left as is, "changing it would put the generated header out of step" (implementer)

**What's wrong.**
- `IconBrowser.lua:5`: "a section's list is split up the first time it opens". The
  first search now splits every section (`MatchingIcons` calls `SplitIcons`), which
  `SplitIcons`' own comment (`:33-35`) does say. The same stale sentence is written into
  `Data/IconList.lua`'s header by `tools/make_icon_list.py:128` ("split up when its section
  opens").
- `IconBrowser.lua:177` and the style guide row give "10,408 atlases" as the example.
  The list in the repo has 10,368 (sum of `count`, and 10,368 lines parsed; measured).
  A made-up exact figure reads as fact; use the real one or "N of M atlases match".
- `IconBrowser.lua:7-8`: "keeps only the atlases whose name holds what is typed (any
  case), in open sections" reads as if only already-open sections are searched; the code
  searches all of them and opens the ones with a match.
- `IconDebug.lua:9-10` was edited without reflowing: line 10 is "(UI/IconBrowser.lua). A".

**Why it matters.** §5 and §9: a comment that is wrong is worse than none.

**Fix.** E.g. line 5: "a section's list is split up the first time it is opened or
searched"; line 7: "keeps only the atlases whose name holds what is typed (any case),
opens every section with one, and counts them"; drop or correct the 10,408; reflow the
IconDebug header. The generator's sentence is optional (it only affects a generated
comment).

### R7 · A keystroke that leaves the query unchanged still refolds and jumps to the top

- **Severity:** nit
- **Area:** Readability (behaviour)
- **Where:** `NeedRoll/UI/IconBrowser.lua:158-175`
- **Status:** fixed in round 2 (`6ba92f9`)

**What's wrong.** `T:SearchBox` hands `onChange` the trimmed text on every
`OnTextChanged`, so typing a space after "ring" calls `SetQuery("ring")` again.
`SetQuery` always resets `foldedMatches`, rescans, and `T:GlideTo(self.pane, 0, true)`.

**Why it matters.** Fold a section mid-search, scroll down, type a trailing space (or
backspace one): the folded section reopens and the list jumps to the top though the
results didn't change. The scan itself is cheap (~1 ms), so it's the jump that shows.

**Fix.** Return early when the query is the one already shown, after the first build:

```lua
local query = text:lower()
if query == "" then query = nil end
if self.lines and query == self.query then return end
self.query = query
```

### R8 · The round 2 fixes moved two comments away from, or off, what they describe

- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `NeedRoll/UI/MainFrame.lua:674-682`; `NeedRoll/UI/Theme.lua:1015`;
  `NeedRoll/UI/IconBrowser.lua:5-10`
- **Status:** fixed in round 3 (`b3cd337`)

**What's wrong.**
- The R5 fix put `NATIVE_SEARCH_RIGHT` and `MODERN_HINT_RIGHT` (with their own comment)
  between `UI:SizeTopBar`'s doc comment and the function:

  ```lua
  -- The search box, its "!" and Settings, `height` tall (80% of the row they
  -- sit in, Mike), their text and icons grown to match.
  -- The search's room on the right: the native template's for its clear
  -- button, ...
  local NATIVE_SEARCH_RIGHT = 20
  local MODERN_HINT_RIGHT = 8

  function UI:SizeTopBar(height)
  ```

  The two comments now run together as one block over the constants, and the
  function has none of its own. This is the same separation R5 asked to undo in Theme.
- `T:SearchBox`'s comment says "It takes the window's skin unless `skin` names one, as the
  debug windows do to stay modern". The default is `self.name`, the addon's skin, and the
  debug window is itself a window whose look is modern, so "the window's skin" points at
  the wrong one in the very case the argument exists for.
- The R6 rewrite of IconBrowser's header wasn't reflowed: line 9 is "-- them. Hovering
  an icon shows its atlas name" (46 characters) between 70-75 character lines, the same
  kind of leftover R6 fixed in IconDebug.

**Why it matters.** `docs/READABLE-CODE.md` §5/§9: a reader takes the comment over a
function as describing it; here it describes the constants, and "window's skin" names the
skin the debug window doesn't use.

**Fix.** Put the constants (and their comment) above the `SizeTopBar` doc comment, with a
blank line between; say "the addon's skin (T.name)" in `T:SearchBox`'s comment; reflow
IconBrowser's header lines 5-11.

### R9 · The new placement assertion lets a still-clipped row pass, and its message states the good case

- **Severity:** nit
- **Area:** WoW API (frame layout; smoke coverage asked for in R1)
- **Where:** `tests/smoke/modules/UI-IconBrowser.lua:134-137`
- **Status:** fixed in round 3 (`b3cd337`)

**What's wrong.**

```lua
local searchBottom = -select(5, box:GetPoint(1)) + box:GetHeight()
assert(-select(5, RowFor(browser, 1):GetPoint(1)) >= searchBottom,
    "the first line is drawn under the search box")
```

The bound is the search box's bottom edge (4 + 24 = 28 px), but what hides a row is the
clip window, which starts at `LIST_TOP` = 36. Any row placed between 28 and 36 passes
and is still cut off at the top. The message is the failure text the run prints, and it
states the correct state ("drawn under the search box"); the other asserts in the file
state what went wrong ("a header didn't fold its matches").

**Why it matters.** The assertion exists so the strip and the rows can't drift apart
again (R1). As written it catches the round 1 bug (row at 4) but not a smaller drift, and
a failure would read like a pass.

**Evidence.** Mutation probe on a scratch copy of `6ba92f9`: `local y = -(30 + i * ROW_H -
shift)` in `Draw` leaves the scenario at "ok"; `-(INSET + ...)` fails it with
"tests/smoke/modules/UI-IconBrowser.lua:136: the first line is drawn under the search box".

**Fix.** Check the exact start of the list, e.g. expose the constant
(`IconBrowser.LIST_TOP = LIST_TOP`) or rebuild it from the search strip, and word the
message as the failure:

```lua
assert(select(5, RowFor(browser, 1):GetPoint(1)) == -IconBrowser.LIST_TOP,
    "the first line doesn't start where the list's clip window does (it hides behind the search strip)")
```

### R10 · `TopOffset`'s comment reads as the parent's anchor

- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `tests/smoke/modules/UI-IconBrowser.lua:39-45`
- **Status:** open: for Mike to decide (found in the last round)

**What's wrong.** The R9 helper says

```lua
-- How far down its parent `frame`'s TOPLEFT anchor sits, in px.
local function TopOffset(frame)
```

"its parent `frame`'s" reads as the parent's anchor. The function returns how far
`frame`'s own TOPLEFT point sits below the frame it's anchored to (for the row, the
canvas; for the clip window, the pane; both are the parents here).

**Why it matters.** Test code only; a reader has to check the body to see whose anchor
it is. `docs/READABLE-CODE.md` §9.

**Fix.** "How far `frame`'s TOPLEFT point sits below the top of the frame it is
anchored to, in px."

## Round 2

Re-read every function the change touches in full at `6ba92f9` (IconBrowser whole file;
Theme `SymbolStrokes` to `T:SearchBox`; MainFrame `SizeTopBar`, `CreateTopBar`,
`CreateLists`), not only the fixed lines.

- **R1, fixed.** `Draw` now places rows at `-(LIST_TOP + i * ROW_H - shift)`
  (`IconBrowser.lua:306`), matching the clip window from `T:ScrollView(pane, LIST_TOP,
  INSET)`, the scroll bar's `LIST_TOP`, and `Fits()`/`MaxOffset()` (both from
  `listHeight = height - LIST_TOP - INSET`), so line 1 starts exactly at the window's top
  and the last line at max offset ends at its bottom. The new assertion fails on the
  round 1 code (mutation probe) but is looser than it should be: R9.
- **R2, fixed.** Typed text keeps `T.SEARCH_TEXT_RIGHT` (22, needed for the cross); the
  modern hint is back to 8 (`MODERN_HINT_RIGHT`), native 20 for both, as before the change.
  The style guide says so (`STYLE-GUIDE.md:38-39`).
- **R3, fixed, and the main window's boxes are unchanged in both skins.**
  `T:SearchBox(..., skin)` does `skin = skin or self.name`, then
  `self:Palette(skin)`/`self:Fonts(skin)`. `T:SetSkin` (`Theme.lua:276-283`) sets
  `self.name`, `self.native = name == "native"`, `self.color = palettes[name]` and
  `self.font = fonts[name]` (built once and cached), and nothing else in the addon assigns
  `T.font` or `T.color` (grep). `T:Palette(name)` returns `palettes[name]` and
  `T:Fonts(name)` returns the same cached `fonts[name]`. So with no `skin` given,
  `skin == "native"` is exactly the old `self.native`, and `colors`/`skinFonts` are the
  same tables as the old `self.color`/`self.font`: same template, font objects,
  fill, magnifier tint, hint font and cross colours. `T:Rounded` and `SlicedTexture` take
  no skin-specific values (`self.media` only). The top bar and recipe filter calls don't
  pass `skin`. The icon browser passes `"modern"`, matching `IconDebug.lua:21-22`
  (`T:Palette("modern")`, `T:Fonts("modern")`), so its hint font is the same `small` as the
  window's `F.small` used for the match count. The cross now takes the palette as an
  argument instead of reading `T.color` (right for a forced skin). Smoke: the MainFrame
  search/style-switch scenarios and the two-skin Theme scenario pass.
- **R4, fixed.** `ClearSearch(box)` serves both `OnEscapePressed` and the cross.
- **R5, fixed.** `T.SEARCH_TEXT_RIGHT` defined once above its users; the clear-button
  comment sits on `AddClearButton`; native 20 is `NATIVE_SEARCH_RIGHT`; `SEARCH_W` and
  `LIST_TOP` are commented. (The new constants' placement in MainFrame is R8.)
- **R6, fixed** except the generator sentence, left as is for the implementer's reason
  (the generated `Data/IconList.lua` header and its generator would disagree until the
  next regeneration). The examples now read "N of M atlases match". New reflow leftover
  in the header: R8.
- **R7, fixed.** `if self.lines and query == self.query then return end`
  (`IconBrowser.lua:165`). `self.lines` is nil until the first `Layout`, so `Build`'s
  `SetQuery("")` still builds the list; after that, text that trims and lowercases to the
  shown query ("ring " after "ring", "RING", or spaces in an empty box) keeps folds and
  scroll. A real change (including clearing to "") still runs. The scenario covers the
  trailing space, and removing the line fails it (mutation probe).
- **New this round:** R8 and R9, both nits. No new API calls (`T:Palette`/`T:Fonts` are
  the addon's own), no new globals, `--@debug@` blocks and `.pkgmeta` untouched.

## Round 3

Reviewed `281389f..b3cd337`, then re-read the whole group (`ae013b0..b3cd337`): every
changed function in IconBrowser, `SymbolStrokes` through `T:SearchBox` in Theme, and
MainFrame's `SizeTopBar`, `CreateTopBar` and `CreateLists`, plus both new scenarios.

- **R8, fixed.** The `NATIVE_SEARCH_RIGHT`/`MODERN_HINT_RIGHT` block now sits above
  `UI:SizeTopBar`'s own comment, which is back on the function (`MainFrame.lua:674-682`);
  `T:SearchBox` says "the addon's skin" (`Theme.lua:1015`); IconBrowser's header is
  reflowed (lines 5-11).
- **R9, fixed.** The scenario reads the clip window's top (`browser.canvas:GetParent()`,
  the view `T:ScrollView` makes, anchored at `-LIST_TOP`) and requires line 1's row to
  start exactly there, and the window to be below the search box's height. The message
  now states the failure with both numbers. Mutation probes: rows at 4, 30 and 40 px all
  fail; only `LIST_TOP` passes. `GetNumPoints`, used by the new `TopOffset` helper, is in
  the stand-in (`wow.lua:386`) and in Ketho's `WidgetAPI.lua` (not that the tests need it).
- **Whole group once more.** Behaviour of the top bar search and Filter recipes matches
  the pre-change code in both skins apart from the cross and the typed text's 22 px right
  inset (round 2 notes still hold: same template, palettes, fonts, insets, keys, `quiet`).
  The icon search is right on the full list (round 1 timings), the list's rows, scroll bar
  and line counts agree on `LIST_TOP`, and the debug blocks and `.pkgmeta` are untouched.
  No new API, globals, `OnUpdate` or untrusted input. The only thing left is R10, a
  one-line test comment, found in the last round and left for Mike.

## Area notes

### Readability

Checked every changed function in IconBrowser, Theme and MainFrame against
`docs/READABLE-CODE.md`. Names are in the view's terms (`matchCount`, `foldedMatches`,
`ShownCount`, `ShownIcon`, `searchNames`, `atlasTotal`); no one-letter names outside the
allowed aliases (`i` in short loops). `SetQuery` does one job (apply a query and redraw);
`IsOpen`/`ShownCount`/`ShownIcon` keep the "searching or not" branch out of `Layout` and
`FillRow`, and nothing nests more than three levels. Renaming the modern box's script
arguments from `self` to `editBox` keeps `self` (T) from being shadowed inside
`T:SearchBox`. 4-space indents, LF, `local _, ns = ...` kept. No Lua 5.1 traps:
`query ~= "" and query or nil` is safe (the middle value is never nil when chosen);
`#` is only taken on arrays built with `#t + 1`; the search uses `find(query, 1, true)`
(plain), so typed `%`, `-`, `.`, `[` can't break or inject a pattern. Player text: the
new strings ("Search atlas names", "atlases match") are plain English in a dev-only file
that already prints plain English ("Click to print its name."), as the other dev windows
do; `locales.py --check` passes.

**Behaviour checks (MainFrame search and recipe filter).** Compared the removed MainFrame
code with `NativeSearchBox`/`T:SearchBox` line by line: same template, sizes (20 native,
24 modern), insets on the left (26), magnifier (12, 9 in, `muted`), hint position and
font, Escape/Enter keys, `quiet` handling, trimmed `onChange`, `onFocus` hook, and focus
handling for the hint. The differences are the cross (intended), the right text inset
8 → 22 for typed text (needed for the cross) and the hint's right anchor in `SizeTopBar`
(R2, not needed). `SetTextQuietly` still sets `box.quiet`, which `T:SearchBox` honours, and
quiet sets still update the cross. `recipeFilter:SetText(enc.name)` (`MainFrame.lua:1705`)
now shows the cross, which is right. Smoke scenarios "UI/MainFrame: search waits for a
pause in typing and can be set aside" and "a style switch keeps the selection and the
search text" pass; the style switch rebuilds the frame, so the cross's captured
`T.color` is always the current skin's.

### WoW API

Checked against Ketho's `forever` lists in the scratchpad (`GlobalAPI.lua`,
`WidgetAPI.lua`, `Templates.lua`, `AtlasInfo.lua`, `FrameXML.lua`), not `wow.lua`. Most
calls moved from MainFrame or `T:Pill` unchanged; listed all the same.

| API | Kind | In `forever` lists | Where |
| --- | --- | --- | --- |
| `CreateFrame` ("EditBox", "Button") | global | yes | `GlobalAPI.lua:5145` |
| `strtrim` | global | yes | `GlobalAPI.lua:7043` |
| `BreakUpLargeNumbers` | global | yes | `GlobalAPI.lua:73` |
| `C_Texture.GetAtlasInfo` | C_ (existing call) | yes | `GlobalAPI.lua:4165` |
| `EditBox:SetTextInsets`, `SetAutoFocus`, `HasFocus`, `ClearFocus` | widget | yes | `WidgetAPI.lua:1117,1098,1081,1060` |
| `SetFontObject`, `GetText`, `SetText` | widget | yes | `WidgetAPI.lua:166,1077,1116` |
| `ScriptObject:SetScript`, `HookScript` | widget | yes | `WidgetAPI.lua:45,44` |
| `Texture:SetColorTexture`, `SetVertexColor`, `SetAtlas`, `SetRotation` | widget | yes | `WidgetAPI.lua:261,149,258,148` |
| `Region:SetShown`, `GetHeight` | widget | yes | `WidgetAPI.lua:133,81` |
| `Frame:SetClipsChildren` (via `T:ScrollView`) | widget | yes | `WidgetAPI.lua:625` |
| `SearchBoxTemplate` | template | yes | `Templates.lua:3032` |
| `common-search-magnifyingglass` | atlas | yes | `AtlasInfo.lua:3732` |
| `SearchBoxTemplateClearButton_OnClick` (what `wow.lua`'s stand-in mirrors) | FrameXML | yes | `FrameXML.lua:3691` |
| `OnEscapePressed`, `OnEnterPressed`, `OnTextChanged`, `OnEditFocusGained/Lost`, `OnClick`, `OnEnter`, `OnLeave` | script handlers | inferred (standard EditBox/Button handlers; not in the lists) | |

No events registered, no `OnUpdate` added (the glide is the existing `T:GlideTo`), no async
data, no secret values (atlas names come from the addon's own data file; typed text is the
player's own). No globals added (`luacheck` clean); no secure frames or protected calls,
so no combat concern. The `wow.lua` change mirrors the game's clear button (it empties and
leaves the box; the real one also plays a sound, which the stand-in needn't). New
behaviour has scenarios in both skins. The one layout bug found is R1.

**Debug guards and packaging.** `.pkgmeta` still ignores `NeedRoll/Data/IconList.lua`
and `NeedRoll/UI/IconBrowser.lua`; `UI/UI.xml:18-20` still loads IconBrowser inside
`<!--@debug@-->`; the `.toc` still loads IconList inside `#@debug@`; `IconDebug.lua`'s
browser wiring is still inside `--@debug@` (`:535-552`), and none of those files are in
this diff except IconDebug's header comment. `T:SearchBox`, `SymbolStrokes` and
`AddClearButton` ship (Theme is not dev-only) and are used by shipped MainFrame, so they
belong outside the debug block; nothing in Theme references the browser. The packaged smoke
run passes with the browser stripped.

### Redundant code

Compared against `T:Input` (the plain one-line box: no hint, no search keys, so not a
substitute), `T:Pill`'s strokes (now shared through `SymbolStrokes`, the right call), the
IconDebug preview box (hand-built, different behaviour), `T:Text`, `T:SetTextColor`,
`T:ScrollView`/`ScrollBar`/`WheelScroll`/`GlideTo`, and `DevKit.ListWindow` (no search).
Moving the search box out of MainFrame removes a would-be second copy. Leftover: R4.
No dead code: every new local and method is called (`MatchingIcons` by `SetQuery`,
`ShownIcon` by `FillRow` and the test, `BuildSearch` by `Build`). `ShowCount` and `Repaint`
both colour the count, which is needed (one on change, one on the background switch).

**Performance on the full list.** Measured with `lua5.1` on `Data/IconList.lua` (16
sections, 10,368 atlases): the first search splits every section once (≈ 9 ms, then
cached in `category.names`/`searchNames`); each keystroke after that is one plain `find`
per atlas, 0.8-1.2 ms including "a" (9,393 matches). `Layout` makes one table per line
(≈ 9,393 / columns for the widest query), and only the pooled rows in view are filled.
Keeping the lowercased copy doubles the name strings (Lua memory ≈ 2 MB after splitting
everything), acceptable for a dev-only view and not loaded in releases. `category.count`
equals the parsed line count in every section (checked), so `Layout` looping to
`ShownCount` instead of `#category.names` changes nothing, and no section has
`count == 0`, so no header that showed before is hidden at rest. No per-frame work added.

### Security

Untrusted inputs or outputs: none. The search text is typed by the player and only
compared with plain `find`; nothing is sent, saved or printed from it. Atlas names
printed on click come from the addon's own (dev-only) data file. No change to drop
sharing, SavedVariables, `Credits.txt`, `.pkgmeta`'s ignore list or any workflow; no
names or credits involved.

## Round history

- 2026-10-18, round 1, `b3f10da`: **Changes needed**. Opened R1 (blocking), R2 (should fix),
  R3-R7 (nits).
- 2026-10-18, round 2, `6ba92f9`: **Changes needed** (nits only). Closed R1-R5 and R7; R6 closed except the generator sentence (left as is). Opened R8, R9 (nits).
- 2026-10-18, round 3 (last), `b3cd337`: **Ready**, one nit for Mike. Closed R8, R9. Opened R10 (nit, for Mike to decide).

## Integration

R10 (the `TopOffset` test comment) was reworded at integration. Applied onto `dev` after #609 (shared helpers) merged. On the result: `tests/smoke/check.sh` all passed (dev, packaged, secret), `tools/locales.py --check` passed, `luac5.1 -p` clean on every changed Lua file.
