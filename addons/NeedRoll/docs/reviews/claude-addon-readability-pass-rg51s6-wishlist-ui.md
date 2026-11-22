# Review: Readability pass, Wishlist tab (`NeedRoll/UI/Wishlist.lua`) and its module smoke tests

| | |
| --- | --- |
| Branch | `rp-wishlist-ui` worktree, base `c0e5c79`; it merges into the readability-pass branch `claude/addon-readability-pass-rg51s6` (inferred from the doc name; PR # once it exists) |
| Commit reviewed | `c0e5c79` plus uncommitted changes (`NeedRoll/UI/Wishlist.lua` modified, `tests/smoke/modules/UI-Wishlist.lua` new) |
| Date | 2026-10-18 |
| Round | 3 (last) |
| Verdict | **Ready** (0 blocking, 0 should fix, 1 nit open, optional; R3 item 2 left as is for Mike) |
| Needs | `/reload` is enough: one Lua file changed, no new files in the `.toc`, no SavedVariables change |

## What the change does

Nothing a player sees changes: the Wishlist tab draws the same widgets in the same places, with the same text,
in both window styles. The change is a readability pass over `NeedRoll/UI/Wishlist.lua`.

- **Names.** Cryptic locals get full names (`Pct` to `ChanceText`, `GoTo` to `OpenSource`, `c`/`n`/`w`/`x`/`y`/`out`
  spelled out). Repeated values get names (`HINT_COLOR`, `MAX_BOSS_NAMES`, `COLUMN_GAP`, `ITEM_INDENT`,
  `WIDE_DIALOG`, `MAX_LIST_NAME`).
- **Duplicates folded.** The two "Shift-click links, plain click opens the source" handlers become `ClickItem`. The
  repeated dialog hint, drop count, page frame and title+text tooltip become `AddDialogHint`, `CountDrops`,
  `CreatePage` and `AddTooltip`.
- **Long functions split.** The Import paste box becomes `CreatePasteBox`. Overview's columns become `RunEntries`,
  `OtherEntries` and `UpdateOverview`, which replace `page:Update`. A Details row's data becomes `TableRowData`.
- **Other changes.**
  - `KIND_ORDER` is built from `KINDS`.
  - The Overview stat boxes are a map (`facts.wished`...) instead of `facts[1..4]`.
  - The list menu's action table is built once per menu instead of on every `Fill`.
  - The `pcall` around `RegisterEvent("GLOBAL_MOUSE_DOWN")` is gone.

In round 2 the file went from 1387 to 1324 lines; round 3 put back five why-comments, mostly at line ends, and ends at 1325 lines (base 1326). A new module test file holds 19 smoke tests. Each
runs through a `Test` wrapper built on `Restoring`. At integration the local `Restoring` copy became the shared
`W.Restoring` from `tests/smoke/wow.lua` (#596).

## Scope

- `NeedRoll/UI/Wishlist.lua`: the readability pass described above. 1326 lines before, 1325 after (round 1: 1387, round 2: 1324).
- `tests/smoke/modules/UI-Wishlist.lua` (new, 577 lines): 19 scenarios covering:
  - Overview, Details sort and filter, the star, owned ticks, loading names, the empty list and Clear list
  - the list menu, Save preset, Export and Import
  - hiding the tab
  - round 2 adds: modified click, menu click-away and Escape, the paste box
- Generated data under `NeedRoll/Data/`: untouched.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on both files | passed (round 3) |
| `luacheck --std lua51 -q --codes` W11x global names, base vs new | identical (`C_Item`, `C_Timer`, `CreateFrame`, `GameTooltip`, `HandleModifiedItemClick`, `InCombatLockdown`, `IsModifierKeyDown`, `strtrim`) |
| `luacheck --no-global -q`, base | 6 warnings (5 lines over 120, unused `self` in `SetDescending`) |
| `luacheck --no-global -q`, new (both files) | 0 warnings |
| `python3 tools/locales.py --check` | passed. The set of `L["..."]` keys is identical to base, and `enUS.lua` needs no change |
| `python3 tools/translations.py` | ran clean, no file changed |
| `tests/smoke/check.sh` | round 3: all three runs passed (dev 183 files, packaged 178, dev with secret values); 57 = 19 × 3 `UI/Wishlist:` oks |
| Widget snapshot (`ZZ-snapshot.lua`, rerun by the reviewer in a scratch copy, modern and native skins, every state listed in round 1) | round 3 dev and packaged dumps are **byte-identical** to base (also identical in round 2) |
| Failure test (reviewer): an `error()` injected into three tests of a scratch copy | Round 3: everything came back after the injected failures (current list `Starred items`, view `overview`, 1 list, tab `DUNGEON` as set before the tests; menu, Import, name and Export dialogs closed; menu has no registered events). In round 2 the open menu, the Import dialog and the tab did not come back (R11) |
| Scraper unit tests | not run: no scraper change |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | blocking | WoW API (smoke tests) | test file | Tests don't restore what they override when they fail | fixed in round 2 (uncommitted) |
| R2 | should fix | Readability | `Wishlist.lua` | The file grew by 61 lines | fixed in round 2 (uncommitted): 1324 lines |
| R3 | should fix | Redundant code | `Wishlist.lua` | Copy-pasted blocks within the file | fixed in round 2 (uncommitted), except item 2. Left as is: a shared helper would move `L["Leave out shirt and tabard"]` ahead of the Import hint and reorder `enUS.lua` |
| R4 | should fix | WoW API (smoke tests) | test file | No tests for modified click, menu click-away and Escape, paste box | fixed in round 2 (uncommitted) |
| R5 | nit | Readability | `Wishlist.lua:980` (r1) | `select(2, WL:Slot(a))` mental mapping | fixed in round 2 (`SlotOrder`, 923) |
| R6 | nit | Readability | `Wishlist.lua:210` (r1) | `CreateColumn(pane, ...)` given a page | fixed in round 2 (`parent`) |
| R7 | nit | Readability | `Wishlist.lua` (r1) | Repeated numbers with no name | fixed in round 2 (`MAX_LIST_NAME`, `WIDE_DIALOG`, `ITEM_INDENT` at 21) |
| R8 | nit | Readability | `Wishlist.lua:576` (r1) | `ACTIONS` in capitals | fixed in round 2 (`actions`) |
| R9 | nit | Redundant code | test file | `SampleItems` rescans data; item `1` unnamed | fixed in round 2 (cached; `UNKNOWN_ITEM_ID`) |
| R10 | should fix | Readability | `Wishlist.lua:284, 384, 637-638, 678, 1107` | Cutting comments took good why-comments with the restating ones | fixed in round 3 (uncommitted) |
| R11 | should fix | WoW API (smoke tests) | test file `97-122` | A failed test leaves the list menu or a dialog open, and the tab switched | fixed in round 3 (uncommitted) |
| R12 | nit | Readability | `Wishlist.lua:531` | The list menu's section header lost the divider style the other sections use | fixed in round 3 (uncommitted) |
| R13 | nit | Readability | `Wishlist.lua:971-973` | Plural text done two ways; a conditional `format` nested inside another `format` | fixed in round 3 (uncommitted) |
| R14 | nit | WoW API (smoke tests) | test file `528` | `find("item:" .. id)` also matches a longer item ID | fixed in round 3 (uncommitted) |
| R15 | nit (optional) | Readability | `Wishlist.lua:546` | `CreateMenu`'s end-of-line comment calls the row "New list"; it reads "New empty list..." | fixed after round 3 |

### R10 · Cutting comments took good why-comments with the restating ones

- **Severity:** should fix
- **Area:** Readability
- **Where:** `Wishlist.lua:283-284`, `384-385`, `674-678`, `1106`, `637` (round-2 lines)
- **Status:** fixed in round 3 (uncommitted). All five are back, four as end-of-line comments: 284 `-- stroke length, angle, x, y`, 384 `-- an edit box takes clicks only on its text; the rest of the box focuses it too`, 678 `-- room for the chevron`, 1107 `-- onPick(kind), nil for All`, and 637-638 the combat note in full. The file stays under base (1325 vs 1326)

**What's wrong.** To meet R2, the comment count went from 109 to 60 lines, one more than base's 59. So nearly every
comment added in round 1 went, including several that explained code a newcomer cannot read on its own. Round 1
asked to cut only the restating ones.

- 674-678: `self:SetWidth(self:GetWidth() + 14)` inside an override of `pill:SetLabel`. Why 14, and why override
  at all? It makes room for the chevron. That comment ("Wider than its label, to fit the chevron") is gone.
- 283-284: `for i, spec in ipairs({ { 4, -45, -2, -1 }, { 7, 45, 1, 0.5 } })`. The four numbers are length, angle,
  x and y of the tick's two strokes, and nothing says so now (§8, mental mapping).
- 384-385: `frame:EnableMouse(true)` and `frame:SetScript("OnMouseDown", function() edit:SetFocus() end)`. Why a
  click on the frame focuses the edit box: a multi-line EditBox only takes clicks on its lines of text, so a click
  in the empty part of the box would do nothing.
- 1106: `bar:Set(counts, total, activeKind, onPick)`. The fact that `onPick(nil)` means "All" (the first chip has
  `kind = nil`) is no longer written anywhere.
- 637: `-- Escape closes it and stops there; other keys pass on (a change the game blocks in combat).` The
  shortened comment no longer says what happens in combat: `SetPropagateKeyboardInput` is protected, so the
  setting stays as it was and Escape also reaches the game. "A change the game blocks" leaves the reader guessing.

**Why it matters.** `docs/READABLE-CODE.md` §5 and the brief: "Keep the comments that are good... say why and name
the game fact behind odd code." Without these comments, the next reader sees a magic `+ 14`, a table of four
unexplained numbers, and a mouse handler that seems redundant. That last one is the kind of line someone deletes
as dead code.

**Evidence.** The listed lines in the round-2 file. Comment-line counts: `grep -cE '^\s*--'` gives 59 (base), 109
(round 1), 60 (round 2).

**Fix.** Put them back as end-of-line comments, which cost no lines and keep the file under 1326:

```lua
self:SetWidth(self:GetWidth() + 14) -- room for the chevron
for i, spec in ipairs({ { 4, -45, -2, -1 }, { 7, 45, 1, 0.5 } }) do -- stroke length, angle, x, y
frame:EnableMouse(true) -- an edit box takes clicks only on its text; the rest of the box focuses it too
function bar:Set(counts, total, activeKind, onPick) -- onPick(kind), nil for All
-- Escape closes it and goes no further; other keys reach the game. In combat the game
-- won't let this change, so Escape reaches the game too.
```

### R11 · A failed test leaves the list menu or a dialog open, and the tab switched

- **Severity:** should fix
- **Area:** WoW API (smoke tests)
- **Where:** `tests/smoke/modules/UI-Wishlist.lua:96-119` (`Test`). It shows in "the list menu closes on a click
  elsewhere or Escape" (530-549) and "Import's paste box..." (551-570, `pane.importDialog:Close()` only on its last
  line), and in any test that opens the name dialog
- **Status:** fixed in round 3 (uncommitted). `Test` (97-122) remembers `ns.UI.state.category`. Its restore runs the pane's own `OnHide` script, which hides the menu and closes the three dialogs, and switches back to the tab if it changed. The reviewer's failure run confirms it: with errors injected into three tests, the probe after them saw the tab back on `DUNGEON` and the menu and every dialog closed

**What's wrong.** The `Test` wrapper's `restore` puts back:

- the stand-in overrides
- the Smoke lists
- the current list
- the view
- Details' sort and filter

It does not close what the test opened (the list menu, the name, Import and Export dialogs), and it leaves the
tab it switched to. Tests that open these close them only on their last line, which a failed assert never reaches.

**Why it matters.** I injected an `error()` into the menu test in a scratch copy. Afterwards the menu was still
shown, still registered for `GLOBAL_MOUSE_DOWN`, and `ns.UI.state.category` was `WISHLIST`. The same with the
paste-box test left the Import dialog's shade shown. Module files run one after another in a single Lua state, and
once the groups are merged other files' tests run after this one. They would start with a Wishlist dialog over the
window or the menu catching their clicks, and fail for reasons that aren't theirs. This is the part of the brief's
restore rule ("restores what it overrides... even when it fails") still missing after R1.

**Evidence.** In the reviewer's failure run (scratch copy, `--only "UI/Wishlist"`), the probe printed:

```
STATE menu=true keyprop=nil tab=WISHLIST
STATE ... import=true ... tab=WISHLIST
```

The first line comes after the injected menu-test failure, the second after the paste-box failure. Before the
tests the tab was `nil` in that run.

**Fix.** In `Test`, remember the tab and close the pane's popups in `restore`:

```lua
local tab = ns.UI.state.category
...
Restoring(function() body(W, ns, Override) end, function()
    ...
    local pane = ns.UI.wishlist
    pane.menu:Hide()
    pane.nameDialog:Close()
    pane.importDialog:Close()
    pane.exportDialog:Close()
    if tab and tab ~= ns.UI.state.category then ns.UI:SwitchTab(tab) end
end)
```

The pane's own `OnHide` does the four closes, so `pane:GetScript("OnHide")(pane)` is a one-line alternative.

### R12 · The list menu's section header lost the divider style the other sections use

- **Severity:** nit
- **Area:** Readability
- **Where:** `Wishlist.lua:531-532`
- **Status:** fixed in round 3: `-- List menu -----...` (531), with the description moved to `CreateMenu`'s line (546; see R15)

**What's wrong.** `-- List menu: every saved list (the current one gold), then New empty list, Rename and Delete.`
is followed by a blank line, so it reads as a section header. The other sections are written
`-- Strip pills -----` (685), `-- Overview -----` (752), `-- Details -----` (978) and `-- The pane -----` (1249).

**Fix.** Use `-- List menu -------...` with the description under it, or attach the description to `CreateMenu`
and drop the blank line (§6, consistency).

### R13 · Plural text done two ways; a conditional `format` nested inside another `format`

- **Severity:** nit
- **Area:** Readability
- **Where:** `Wishlist.lua:58-60` and `971`
- **Status:** fixed in round 3: `local placesText = (#runs == 1 and L["%d place"] or L["%d places"]):format(#runs)` (971), then one `format` (972-973)

**What's wrong.** Item counts go through `ItemCountText`. The place count is spelled inline, nested inside another
`format`:

```lua
L["%s in %s"]:format(ItemCountText(dropCount), (#runs == 1 and L["%d place"] or L["%d places"]):format(#runs))
```

**Why it matters.** It's one line doing three things: two plural choices and two formats. That's the hardest line
in `UpdateOverview` to read, and it picks a plural a different way from the rest of the file (§6). Round 1 had
this as `Plural(#runs, ...)`.

**Fix.** Either keep a two-line `Plural(count, one, many)` and build `ItemCountText` on it, or name the piece:
`local placesText = (#runs == 1 and L["%d place"] or L["%d places"]):format(#runs)`. Both keep the `L` literals.

### R14 · `find("item:" .. id)` also matches a longer item ID

- **Severity:** nit
- **Area:** WoW API (smoke tests)
- **Where:** `tests/smoke/modules/UI-Wishlist.lua:523`
- **Status:** fixed in round 3: `find("item:" .. items.drop1 .. ":", 1, true)` (528)

**What's wrong.** `linked[1]:find("item:" .. items.drop1, 1, true)` is also true for a link to item `drop1 * 10 + n`.

**Fix.** `find("item:" .. items.drop1 .. ":", 1, true)`. Item link strings put a `:` after the ID.

### R15 · `CreateMenu`'s end-of-line comment calls the row "New list"

- **Severity:** nit (optional; doesn't block the merge)
- **Area:** Readability
- **Where:** `Wishlist.lua:546`
- **Status:** fixed after round 3 (the comment now says "New empty list")

**What's wrong.** `local function CreateMenu(pane, anchor) -- every saved list (the current one gold), New list,
Rename, Delete`. The row's label is `L["New empty list..."]` (559), and "New list" is the label of the Import
dialog's mode toggle (424) and the title of the dialog this row opens (561).

**Why it matters.** A reader who greps for the row by the comment's words finds the Import toggle first (§9: a
comment must not say something the code doesn't). It's a small slip, from moving the round-2 header text onto this
line.

**Fix.** `-- every saved list (the current one gold), then New empty list, Rename and Delete`.

---

The round-1 findings follow, with what round 2 did about each.

### R1 · Tests don't restore what they override when they fail; no `Restoring`

- **Severity:** blocking
- **Area:** WoW API (smoke tests)
- **Where:** `tests/smoke/modules/UI-Wishlist.lua` (round 1: whole file; 64, 69-78, 252, 293-296, 303-309)
- **Status:** fixed in round 2 (uncommitted)

**What was wrong.** The file had no `Restoring`. Stand-in overrides (`C_Item.GetItemCount`,
`C_Item.GetItemNameByID`, `C_Item.IsItemDataCachedByID`), the saved `view`, Smoke lists, the current list and
Details' sort were put back only if every assert passed. `W.Call` (`tests/smoke/wow.lua:73-81`) catches a failure
and carries on, so one failure would break every later test that touched the same state.

**Round 2.** `Restoring` sits at the top (7-11), as the brief specifies. Every scenario goes through `Test`
(96-119). `Test` snapshots the current list, the view and Details' `sortKey`/`sortDesc`/`filter`, and offers
`Override(table, key, value)`, which undoes itself in reverse order. `restore` runs `CleanUp`, re-selects the list
and puts back the view. The reviewer's failure run confirmed the current list, view, lists and `C_Item` all come
back. What's still missing is in R11.

### R2 · The file grew by 61 lines; the pass should leave it shorter

- **Severity:** should fix
- **Area:** Readability
- **Where:** `NeedRoll/UI/Wishlist.lua`
- **Status:** fixed in round 2 (uncommitted)

**What was wrong.** 1326 lines became 1387: +8 code, +50 comment lines.

**Round 2.** 1324 lines: 1202 code (base 1193), 60 comment (base 59), 62 blank (base 74). The code lines still grow
by 9. That's the wrapping of the five lines over 120 characters plus the new helpers' signatures; the blank lines
pay for it. The cut went too deep into the comments, though: R10.

### R3 · Copy-pasted blocks within the file

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** round 1 `Wishlist.lua:334-335/414-416/512-514; 440-441/533-534; 458-462/1370-1373;
  888-890/1230-1232; 703-709/751-756`
- **Status:** fixed in round 2 (uncommitted), except item 2. Left as is (implementer's reason): a shared helper
  would move `L["Leave out shirt and tabard"]` ahead of the Import hint and reorder the generated `enUS.lua`, which
  this group may not edit.

**Round 2.**

- Item 1, the dialog hint: `AddDialogHint` (328-332).
- Item 3, counting drops: `CountDrops` (62-68), used at 456 and 1313.
- Item 4, the page frame: `CreatePage` (754-759).
- Item 5, the tooltip: `AddTooltip` (312-320), used at 679 and 720.
- Item 2, the tick box: still at 432-433 and 519-520.

The snapshot stayed byte-identical.

**Reviewer's note on item 2.** The reason holds for a helper that contains the literal: `tools/locales.py` lists
keys in first-seen order per file. A helper that takes the label from the caller would keep the literals where
they are and fold only the anchor line, for example `AddCosmeticCheck(box, L["Leave out shirt and tabard"],
onClick)`. That saves one line per dialog. Not worth reopening; Mike can decide.

### R4 · Code the diff changed has no test: modified click, menu click-away and Escape, paste box

- **Severity:** should fix
- **Area:** WoW API (smoke tests)
- **Where:** `Wishlist.lua` `ClickItem`, menu `GLOBAL_MOUSE_DOWN` and keyboard, `CreatePasteBox`; test file
- **Status:** fixed in round 2 (uncommitted)

**Round 2.** Three scenarios were added:

- **516-528:** Overview and Details rows with `IsModifierKeyDown` true call `HandleModifiedItemClick` with the item
  and stay on the Wishlist.
- **530-549:** `GLOBAL_MOUSE_DOWN` over the menu keeps it open and elsewhere closes it. Another key leaves
  propagation on; Escape hides the menu and turns propagation off.
- **551-570:** the placeholder hides on focus and shows when an empty box loses it; cursor-follow scroll goes down
  and up; the wheel steps 20.

All three pass in every mode.

### R5 · `select(2, WL:Slot(a))`

- **Severity:** nit
- **Area:** Readability
- **Status:** fixed in round 2: `local function SlotOrder(entry) return select(2, WL:Slot(entry)) end` (923),
  used in the comparator (943).

### R6 · `CreateColumn(pane, ...)` is always given a page

- **Severity:** nit
- **Area:** Readability
- **Status:** fixed in round 2: `CreateColumn(parent, createRow, setupRow)` (209).

### R7 · Repeated numbers with no name

- **Severity:** nit
- **Area:** Readability
- **Status:** fixed in round 2:
  - `WIDE_DIALOG = 520` (27)
  - `MAX_LIST_NAME = 40` (28), with a comment tying it to Core's cut
  - `ITEM_INDENT` beside `ICON` (21), used at 786 and 1013

### R8 · `ACTIONS` in capitals

- **Severity:** nit
- **Area:** Readability
- **Status:** fixed in round 2: `local actions` (558).

### R9 · `SampleItems` rescans all data; item `1` unnamed

- **Severity:** nit
- **Area:** Redundant code
- **Status:** fixed in round 2: cached in `sample` (25-27, 67); `UNKNOWN_ITEM_ID = 1` (14).

## Area notes

### Readability

I re-read every function in the round-2 file in full, not only the lines fixed since round 1.

- **Sound:**
  - The renames: `ChanceText`, `OpenSource`, `ClickItem`, `redrawStamp`, `cursorTop`/`viewTop`, `factWidth`,
    `colWidth`, `slotOrder`, `otherPlaces`, `isEmpty`, `isItem`.
  - `KIND_ORDER` built from `KINDS`.
  - The named `facts` (nothing outside the file reads Wishlist's `facts`).
  - `SetupOverviewRow` sets its points once.
  - The new helpers are small and named for what they do: `AddTooltip`, `AddDialogHint`, `CountDrops`,
    `CreatePage`, `SlotOrder`.
  - Formatting: lines at most 120 characters, 4-space indents, LF, UTF-8, no tabs.
- **Lua 5.1 traps:** `ns.SHOW_DROP_RATES and row.chance or nil` (1061) is safe because `row.chance` is never nil.
  `(count == 1 and L[...] or L[...])` is safe because `L` never returns nil for a key. No `#t` on holey tables, and
  no patterns are built from data.
- **Round 3:** the re-added end-of-line comments say why and fit the 120-column limit. `placesText` is worked out
  even when `dropCount` is 0; that's harmless, one string per redraw.
- **Function length:** `CreateMenu` (546-646, 101 lines) and `CreateImportDialog` (408-494, 87 lines) are still
  over a screen. Splitting them would add lines against R2, so not asked.
- **`AddTooltip(frame, anchor, x, y, title, text)`:** six positional parameters, two of them nil for the list
  button. Acceptable for a local helper with two callers.

### WoW API

There's no new game call in round 2 either. `AddTooltip` makes the same `SetOwner`/`AddLine`/`Show` calls as the
code it replaces; for the list button, `SetOwner(self, "ANCHOR_BOTTOMRIGHT", nil, nil)` behaves like the
two-argument call (snapshot identical). Checked against Ketho's `forever` lists, downloaded to the scratchpad:

| Name | Kind | In `forever` lists | Where |
| --- | --- | --- | --- |
| `GLOBAL_MOUSE_DOWN` | event | yes | `Events.lua:1808`; dropping the `pcall` removes a dead fallback |
| `RegisterEvent`, `UnregisterAllEvents`, `SetPropagateKeyboardInput`, `IsMouseOver` | widget methods | yes | `WidgetAPI.lua:612, 654, 642, 107` |
| `SetScrollChild`, `SetVerticalScroll`, `GetVerticalScroll`, `SetMultiLine`, `SetMaxLetters`, `HighlightText` | widget methods | yes | `WidgetAPI.lua:1335, 1336, 1332, 1108, 1107, 1083` |
| `AddLine`, `AddDoubleLine`, `IsOwned` (GameTooltip) | widget methods | yes | `WidgetAPI.lua:1188, 1204` |
| `C_Item.GetItemInfo`, `C_Item.GetItemNameByID`, `C_Item.GetItemIconByID`, `C_Timer.After`, `IsModifierKeyDown`, `InCombatLockdown`, `strtrim`, `CreateFrame` | global API | yes | `GlobalAPI.lua:2522, 2535, 2521, 4171, 6097, 6014, 7043, 5145` |
| `HandleModifiedItemClick` | FrameXML function | yes | `FrameXML.lua:2203` |
| `common-icon-checkmark` | atlas (unchanged) | yes | `AtlasInfo.lua:3673` |
| `UICheckButtonTemplate` | template (unchanged) | yes | `Templates.lua:3764` |

- **Async item data:** stays on `ns.Items:Load`.
- **Events:** the menu registers `GLOBAL_MOUSE_DOWN` only while shown and unregisters it on hide.
- **Combat:** `SetPropagateKeyboardInput` stays behind `InCombatLockdown()`.
- **Secret values:** none touched.
- **Globals and upvalues:** no new globals; the 60-upvalue limit isn't reached.
- **Strings:** `L` keys are unchanged.
- **Other:** no dev-only code. The UI is pixel-identical, so `docs/STYLE-GUIDE.md` needs no change.
- **Smoke stand-in:** the tests override `IsModifierKeyDown`, `HandleModifiedItemClick` and stand-in internals
  (`_height`, `_children`, `_multi`) only through `Override`, or read them. Nothing is added to `wow.lua`.

### Redundant code

- **Compared against:**
  - `T:Pill`, `T:Row`, `T:Text`, `T:Input`, `T:Dialog`, `T:LabelToggle`, `T:Star`, `T:ScrollBar`,
    `T:WheelScroll`, `T:ScrollStart`, `T:ScrollView`, `T:Rounded`, `T:Fill`, `T:Edge`, `T:Arrow`,
    `T:SetTextColor`, `ns.Items:Load`.
  - `T:Edge` (`Theme.lua:360-374`) is not flagged for the 1-px rules: it snaps with `PixelUtil` and has no 4-px
    insets, so it would change pixels.
  - `T:Arrow` (`Theme.lua:1051-1110`) is not flagged for `CreateSortMark`: different stroke length, color and
    spread.
- **Inside the file:** only the shirt/tabard tick box pair is left (R3, item 2, left as is). The `Plural` helper is
  gone and `ItemCountText` inlines its body, which leaves the place count spelled inline (R13).
- **Dead code:** none (luacheck clean, no debug prints).
- **Cross-module** (for the merge PR):
  - Tooltip light blue `0.76, 0.93, 1`: `Wishlist.lua:162, 833` and `LootGrid.lua:301, 314, 333, 445, 476, 504`.
  - `HINT_COLOR` (`Wishlist.lua:30`) is local here.
  - The test file's `Restoring` (7-11) becomes `W.Restoring`, and its `Hover` (163-166) duplicates
    `scenarios.lua:25`.
  - `AddTooltip` (title + white wrapped line) may have twins in other UI files.
  - The Shopping duplicates the brief already lists.

### Security

- **Untrusted input:** pasted Import text. The UI path into `WL:Parse` is unchanged (same `strtrim` guard, same
  `WL:Parse(text)`, same `WL:CleanName(...) or parsed.name`), and the snapshot's import states are byte-identical.
  No `loadstring`/`RunScript`.
- **SavedVariables:** keys unchanged.
- **No addon messages or chat** in this file.
- **Pre-existing, outside this group's files (not a finding here):** `WL:Parse` (`Core/Wishlist.lua:540-556`) puts
  the JSON's `character.name`, `gameClass` and `level` into `note` without stripping `|`. The note shows in the
  Import preview and the tab's subtitle, so a pasted export can carry `|T`/`|H` codes there. For the Core/Wishlist
  group.

## Round history

- 2026-10-17, `c0e5c79` + uncommitted, round 1: **Changes needed**. Opened R1-R9 (1 blocking, 3 should fix,
  5 nits).
- 2026-10-17, `c0e5c79` + uncommitted, round 2: **Changes needed**.
  - Closed R1, R2, R4, R5, R6, R7, R8 and R9.
  - R3 fixed except item 2, left as is with the implementer's reason.
  - Opened R10 and R11 (should fix) and R12, R13 and R14 (nits).
- 2026-10-18, `c0e5c79` + uncommitted, round 3 (last): **Ready**.
  - Closed R10, R11, R12, R13 and R14.
  - Opened R15 (an optional nit).
  - Left for Mike: R3 item 2 (the shirt/tabard tick box, left as is with the implementer's reason). R15 was fixed after the round.
  - Nothing blocking.
- 2026-10-18, follow-up (implementer): `Wishlist.lua` code lines (non-blank, non-comment) cut from 1203 to 1190
  (base 1193); comments 60 (base 59), blanks 62 (base 74), 1312 lines in all (base 1326). Cut: the
  `rows[i] or create` pattern in `CreateColumn` and `CreateChips` (as the menu does it), the one-line
  `if isItem` anchor in `SetupOverviewRow`, the `width` alias of `WIDE_DIALOG` in Import and Export, and the
  Export pill's callback on one line. Widget snapshot byte-identical to `daf636e` (dev and packaged); all checks pass.
