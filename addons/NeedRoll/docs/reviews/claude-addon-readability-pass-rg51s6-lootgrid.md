# Review: Readability pass, LootGrid group (`NeedRoll/UI/LootGrid.lua` and its module smoke tests)

| | |
| --- | --- |
| Branch | `rp-lootgrid` (LootGrid group of `claude/addon-readability-pass-rg51s6`), into `claude/addon-readability-pass-rg51s6` (PR not opened yet) |
| Commit reviewed | `c0e5c79` plus uncommitted changes (`NeedRoll/UI/LootGrid.lua` modified, `tests/smoke/modules/UI-LootGrid.lua` new) |
| Date | 2026-10-18 (rounds 1-3) |
| Round | 3 (last) |
| Verdict | **Ready** (0 blocking, 0 should fix, 0 nits open; R1-R10 and R12-R16 fixed, R11 left as is; +42 lines over the base for Mike to accept) |
| Needs | `/reload` (Lua files only; no TOC, no new files the client loads) |

## What the change does

Nothing a player sees should change: the loot grid, item cells, boss
portraits, folds, filter bar, Related Quests, spoiler and standing bar are
meant to look and behave exactly as before. The code was rearranged. The
512-line `CreateCell` (old lines 849-1360) became a short constructor plus a
`Cell` method table copied onto each cell (`SetEntry`, `Fill`, `Prepare`,
`SetItem`, `ShowTick`, `SetGather`...). `pane:Refresh` (160 lines) was split
into `CellPicker`, `DrawHeaderLine`, `DrawSectionToggle` and `DrawBoxes`. The
Related Quests line, the spoiler and the filter bar left
`ns.UI.CreateLootGrid` as `CreateRelatedQuests`, `CreateSpoiler` and
`CreateFilterBar`. The two filter lists now share `CreateCheckCard` and
`AddFilterTooltip`, and the widget pools share `FromPool`. Some duplicates
became helpers (`ItemTooltipLines`, `SplitWords`, `PlaceName`,
`BossLevelText`, `CellTextBottom`, `SetSpellLook`). Guards for "does this game
function exist" were removed. Magic item-class numbers became
`Enum.ItemClass.*`, and short names were spelled out. The unused
`ns.UI.lootClasses` was dropped. A new module test file adds 13 scenarios.

The file went from 2892 to 2934 lines (+42): code lines fell from 2385 to
2370 (-15), comment lines rose from 360 to 395 (+35) and blank lines from 147
to 169 (+22). The pass's aim is for each group to end shorter.

### Round 2

The implementer addressed R1-R11:
- `SkillRank`'s guard is back.
- The vendor price uses `ShortCost`, and shift-click uses `ChatFrameUtil.InsertLink`.
- Tooltip colors got names, with `AddTipPair`, `AddHintedLines` and `DropChanceText` as helpers.
- `SetBorderColor` is a `Cell` method.
- `Fill` was merged into `SetEntry`; `CopyOfDrop`, `DrawSectionToggle` and `NewSectionLabel` were inlined.
- Short names were renamed.
- The tests got a `saved` table and full restores, plus three new checks (Forever-style vendor price, no skill-line calls, shift-click link).

The only player-visible difference from the base is the R3 fix: shift-click on a spell row now links it instead of erroring (inferred for the game). The vendor-price tooltip text is what the game already showed before.

The file is now 2940 lines (+48 over the base's 2892, +6 over round 1). Code lines are 2372 (base 2385, -13), comment lines 400 (+40), blank lines 168 (+21). The test file is 615 lines, with 14 scenarios.

### Round 3

The implementer addressed R12-R16:
- `SkillRank`'s comment was corrected.
- `TIP_WHITE` became `TIP_TEXT` and covers every white tooltip line.
- The wrapped tooltip lines unpack their named color into `r, g, b`.
- `AddHintedLines` and `DropChanceText` were inlined again.
- The two test leftovers were fixed.

Nothing a player sees changed in round 3. I expanded every `TIP_*` back to its numbers and compared the counts with the base: each color triple and the icon crop appear in the same tooltip calls as before. The only differences are the round-1 merges of the star tooltip's two branches and of `SetSpell`/`SetAbility`'s shared look, which halved those copies. The file is 2934 lines (+42 over the base): code is 2368 (-17), comments 400 (+40), blank lines 166 (+19).

## Scope

- `NeedRoll/UI/LootGrid.lua`: the refactor above (diff: 1047 insertions,
  1005 deletions; 737/695 ignoring whitespace).
- `tests/smoke/modules/UI-LootGrid.lua` (new, 532 lines): 13 module
  scenarios, a local `Restoring` helper, and a global
  `ITEM_CLASSES_ALLOWED` stand-in. At integration the local helper became
  `RestoringTest`, a scenario wrapper built on the shared `W.Restoring`
  from `tests/smoke/wow.lua` (#596).
- Read for context, not changed: `tests/smoke/wow.lua` (stand-ins),
  `NeedRoll/UI/RecipeBand.lua:298-305` (calls `ns.UI.SkillRank`),
  `NeedRoll/UI/Overview.lua:504-510` (its own `GetCoinTextureString`
  fallback), `NeedRoll/Core/Init.lua:196-211` (`Modules:Set` writes
  SavedVariables), `/home/claude/wt/notes/BRIEF.md`, the implementer's
  hand-back.
- No generated files (`NeedRoll/Data/`) and no locale files touched.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on both files | passed (rounds 1-3) |
| `python3 tools/locales.py --check` | passed (exit 0), rounds 1-3; `translations.py` exit 0 in round 3 too |
| `python3 tools/translations.py` | ran, exit 0; only reports pre-existing unused zhTW keys (`Level`, `Press a key`, `Quest chain`), none from this file |
| `luacheck --no-global -q` | base (`git show HEAD:NeedRoll/UI/LootGrid.lua`): 19 warnings. Rounds 1-3: 0 warnings in both files |
| `luacheck --std lua51 --codes` W11 global names, base vs now | Round 3: same list as round 2. Round 2: one name added, `ChatFrameUtil`. It is the R3 fix replacing `ChatEdit_InsertLink`, a real game global in the `forever` list (`FrameXML.lua:563`), not a local read before its declaration. Six fewer: `C_TransmogCollection`, `ChatEdit_InsertLink`, `GameFontNormalLarge`, `GetCoinTextureString`, `GetQuestDifficultyColor`, `NumberFontNormalLarge` |
| `tests/smoke/check.sh` | Round 1: passed, 283 `ok`. Round 2: passed, 286 `ok`. Round 3: passed, "all passed" in all three modes, 286 `ok`, exit 0 |
| New tests fail on the code they guard against | Round 2: I ran `lua5.1 tests/smoke/run.lua` in scratch copies of the worktree. With the round-1 `LootGrid.lua`: 2 failed, the item-cell test (`LootGrid.lua:498: attempt to call global 'GetCoinTextureString'`) and the no-skill-line test (`LootGrid.lua:369: attempt to call global 'GetNumSkillLines'`). With the base `LootGrid.lua`: 1 failed (`UI-LootGrid.lua:334: shift-click didn't link the enchant`, R3). With the round-2 file: all pass |
| `cd scraper && python3 -m unittest` | not run: no scraper change |
| Tooltip colors and icon crop (round 3) | each `TIP_*` and `ICON_CROP` expanded back to its numbers and counted against the base: the same triples in the same calls (`TIP_TITLE` 0.99/0.82/0.62, `TIP_LABEL` 0.76/0.93/1, `TIP_HINT` 0.5/0.6/0.65, `TIP_NOTE` 0.6/0.6/0.6, `TIP_TEXT` 1/1/1, `TIP_GOOD` 0.35/0.77/0.52, reagent total 0.23/0.53/0.36) |
| L key first-appearance order | same 111 keys in the same order, rounds 1-3 |
| `ns.db.*` keys, `needroll:*` link kinds | identical sets, old vs new (rounds 1-3) |
| Public `ns.UI.*` / `pane:*` names | only `ns.UI.lootClasses` removed; grep of the repo (`NeedRoll/`, `tests/`, `docs/`) finds no reader |
| Upvalues (Lua 5.1 limit 60) | `ns.UI.CreateLootGrid`: 47 before, 50 in rounds 1-3 (`luac5.1 -l`). Under the limit |
| Line length / LF / tabs | no line over 120 (rounds 1-3), no CR, no tab indents |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | blocking | WoW API | `LootGrid.lua:368-373` | `SkillRank` calls `GetNumSkillLines`/`GetSkillLineInfo`, which Forever doesn't have; guard removed | fixed (round 2) |
| R2 | blocking | WoW API | `LootGrid.lua:498` | Vendor price tooltip calls global `GetCoinTextureString`, which Forever doesn't have; fallback removed | fixed (round 2) |
| R3 | should fix | WoW API | `LootGrid.lua:944` | Shift-click on a spell row calls `ChatEdit_InsertLink`, not in the `forever` lists (pre-existing) | fixed (round 2) |
| R4 | should fix | Readability (tests) | `tests/smoke/modules/UI-LootGrid.lua` (several) | Tests change state their restore doesn't put back; two tests aren't wrapped; R1/R2 paths untested | fixed (round 2) |
| R5 | should fix | Redundant code | `LootGrid.lua` (see list) | File grew by 42 lines: splits that don't earn a name and cuts that bring it down | fixed (round 2); see R16 |
| R6 | should fix | Readability | `LootGrid.lua` (28 places) | Tooltip colors, the icon crop and the drop-chance format are bare repeated numbers | fixed (rounds 2-3) |
| R7 | nit | Readability | `LootGrid.lua:1044`, `1214-1310` | `SetEntry` / `Fill` / `Prepare`: one job under three names, and a comment credits the wrong one | fixed (round 2) |
| R8 | nit | Readability | `LootGrid.lua:996-1020`, `1379-1390`, `2368`, `2624`, `200` | Cryptic short names left: `fs`, `h`, `k` | fixed (round 2) |
| R9 | nit | Readability | `LootGrid.lua:894-900`, `933-949` | Cell methods written two ways (`Cell` table vs closures in `CreateCell`) | fixed (round 2) |
| R10 | nit | Readability | `LootGrid.lua:1804` | `ipairs(not enc.overview and enc.loot or {})` hides a skip inside an expression | fixed (round 2) |
| R11 | nit | Readability | `tests/smoke/modules/UI-LootGrid.lua:7` | Global `ITEM_CLASSES_ALLOWED` stand-in set for the whole run | left as is |
| R12 | should fix | Readability | `LootGrid.lua:390` | `SkillRank`'s comment says Forever has no skill-line API; it has `C_SkillInfo` | fixed (round 3) |
| R13 | should fix | Readability | `LootGrid.lua:51-52, 352, 547, 552, 807, 811, 1533, 1995` | R6 half done: `TIP_WHITE` exists but `1, 1, 1` is still written out 6 times; `TIP_LABEL[1], TIP_LABEL[2], TIP_LABEL[3]` spelled out | fixed (round 3) |
| R14 | nit | Readability | `LootGrid.lua:65, 71` | New helper comments: one restates the parameters, one says "most of this pane" for a 2-use helper | fixed (round 3) |
| R15 | nit | Readability (tests) | `UI-LootGrid.lua:335, 506` | A restore repeated in the test body; `pane.open` replaced while `shutSections` is refilled in place | fixed (round 3) |
| R16 | should fix | Redundant code | `LootGrid.lua:71-80`, file total | The +48 lines: code is down 13, but two new helpers cost more lines than they save | fixed (round 3); +42 left for Mike |

### R1 · `SkillRank` calls skill-line globals Forever doesn't have

- **Severity:** blocking
- **Area:** WoW API
- **Where:** `NeedRoll/UI/LootGrid.lua:368-373`. Callers: `LootGrid.lua:414` (`GatherTexts`), `LootGrid.lua:458` (`ShowGatherTooltip`), `NeedRoll/UI/RecipeBand.lua:302` (`RB:Rank`)
- **Status:** fixed in round 2 (uncommitted, on `c0e5c79`): the guard is back (`LootGrid.lua:392`). New test "with no skill-line calls (Forever)" fails on the round-1 code with `attempt to call global 'GetNumSkillLines'` and passes now. The comment over it is wrong, see R12

**What's wrong.** The base had:

```lua
local function SkillRank(name)
    if not (GetNumSkillLines and GetSkillLineInfo) then return nil end
```

The change removed that guard, on the grounds that it was a dead fallback:

```lua
local function SkillRank(name)
    for i = 1, GetNumSkillLines() do
        local skillName, header, _, rank = GetSkillLineInfo(i)
```

**Why it matters.** Ketho's `forever` lists have neither global. Forever has
them only as `C_SkillInfo.GetNumSkillLines` and `C_SkillInfo.GetSkillLineInfo`.
So in game the guard was live and `SkillRank` returned nil. Without it, the
first call raises "attempt to call global 'GetNumSkillLines' (a nil value)".
That breaks three places:
- every Scarce reagent source cell (`Cell:SetGather` → `GatherTexts` → `SkillRank`), so the Scarce reagent page fails to draw;
- hovering a source (`ShowGatherTooltip`);
- the Recipes list's rank lookup (`RecipeBand.lua:302`, whose `ns.UI.SkillRank and ...` guard only checks that the function exists).

The smoke run can't see this because `tests/smoke/wow.lua:1388-1392` defines
both globals.

**Evidence.** A grep of `GlobalAPI.lua` and `FrameXML.lua` from
`Ketho/BlizzardInterfaceResources@forever` finds no `"GetNumSkillLines"` and
no `"GetSkillLineInfo"`. `GlobalAPI.lua:3812` has `"C_SkillInfo.GetNumSkillLines"`
and `:3814` has `"C_SkillInfo.GetSkillLineInfo"`. The runtime error is
inferred from the lists; it can't be run here.

**Fix.** This pass keeps behaviour identical, so put the guard back:

```lua
local function SkillRank(name)
    if not GetNumSkillLines then return nil end -- not in Forever (C_SkillInfo has it); see the follow-up note
```

As a follow-up for Mike, not this pass: switching to `C_SkillInfo.*` would
make the skill colors and recipe ranks actually work in game, which is a
visible change. Check the return shape in Ketho's annotations first (a C_
version may return a table rather than the four values). Then add a stand-in
for it in the test, and remove the `wow.lua` globals when the groups merge.

### R2 · Vendor price tooltip calls a global Forever doesn't have

- **Severity:** blocking
- **Area:** WoW API
- **Where:** `NeedRoll/UI/LootGrid.lua:498` (`ShowTooltip`)
- **Status:** fixed in round 2 (uncommitted, on `c0e5c79`): `AddTipPair(L["Vendor price"], ShortCost(entry.cost), ...)` (`:521`). The item-cell test now hovers a priced item with the global nil'd; on the round-1 code it fails (`LootGrid.lua:498: attempt to call global 'GetCoinTextureString'`)

**What's wrong.** The base had
`local price = GetCoinTextureString and GetCoinTextureString(entry.cost) or ShortCost(entry.cost)`.
The change calls it directly:

```lua
GameTooltip:AddDoubleLine(L["Vendor price"], GetCoinTextureString(entry.cost), 0.76, 0.93, 1, 1, 1, 1)
```

**Why it matters.** Forever has `C_CurrencyInfo.GetCoinTextureString`, not
the global. In game the old line always took the `ShortCost` branch. Now,
hovering any item with a vendor price (PvP and faction vendor lists, recipe
items with `cost`) raises "attempt to call global 'GetCoinTextureString'".
The tooltip is left half-built, with no `:Show()` after the added lines, and
the compare tooltip never runs. Smoke passes only because
`tests/smoke/wow.lua:1299` defines the global. `Overview.lua:505` still
guards the same call, which confirms it isn't there in game.

**Evidence.** `GlobalAPI.lua` and `FrameXML.lua` (`forever`) have no
`"GetCoinTextureString"`. `GlobalAPI.lua:1377` has
`"C_CurrencyInfo.GetCoinTextureString"`. The runtime error is inferred.

**Fix.** Write what the game showed before, which is also less code:

```lua
GameTooltip:AddDoubleLine(L["Vendor price"], ShortCost(entry.cost), 0.76, 0.93, 1, 1, 1, 1)
```

Using `C_CurrencyInfo.GetCoinTextureString` would change the tooltip's
look, so leave it for Mike. Add a test that hovers a priced item (see R4).

### R3 · Shift-click on a spell row calls `ChatEdit_InsertLink`, absent from the `forever` lists

- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/UI/LootGrid.lua:944` (the cell's `OnClick` in `CreateCell`, which this change edited)
- **Status:** fixed in round 2 (uncommitted, on `c0e5c79`): `ChatFrameUtil.InsertLink(link)` (`:958`), which is `FrameXML.lua:563` in the `forever` list. The new shift-click assert fails against the base file (`UI-LootGrid.lua:334: shift-click didn't link the enchant`) and passes now

**What's wrong.** `if link and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(link) end`.
This is older code, but it sits in a function this change rewrote, and the
pass's brief is to use the `C_` and Forever names Ketho lists.

**Why it matters.** Shift-clicking an enchant or a boss ability to link it
in chat would raise "attempt to call global 'ChatEdit_InsertLink'" (inferred).

**Evidence.** No `"ChatEdit_InsertLink"` in `GlobalAPI.lua` or `FrameXML.lua`
(`forever`). `FrameXML.lua` has `"ChatFrameUtil.InsertLink"`.
`NeedRoll/Core/Drops.lua:415` already uses the `ChatFrameUtil` form for
another chat call. `wow.lua:1304` defines the global, so smoke can't catch it.

**Fix.** `if link and IsModifiedClick("CHATLINK") then ChatFrameUtil.InsertLink(link) end`.
Give `ChatFrameUtil.InsertLink` a stand-in in the module test, or in
`wow.lua` at merge. If Mike would rather keep fixes out of the readability
pass, note it for a follow-up PR instead.

### R4 · Tests change state their restore doesn't put back; two aren't wrapped; R1/R2 paths untested

- **Severity:** should fix
- **Area:** Readability (tests)
- **Where:** `tests/smoke/modules/UI-LootGrid.lua`
- **Status:** fixed in round 2 (uncommitted, on `c0e5c79`): every test is wrapped and gets a `saved` table. The filter, `pane.shutSections`/`pane.open`, the QUESTS module, the swapped globals and the created frames are all put back in the restore. Two small leftovers are R15

**What's wrong.** The brief requires every test to restore what it
overrides, even when it fails. The hand-back says all 13 are wrapped in
`Restoring`. In the file:
- Lines 222-237 (All drops) and 239-259 (fonts) are plain `fn = function`, not wrapped. The fonts test leaves a shown cell on `UIParent` if an assert fails before line 258.
- Lines 496-504: `ns.Modules:Set("QUESTS", true)` happens in the test body, and `ns.Modules:Set("QUESTS", wasQuests)` runs only if every assert before it passes. `Modules:Set` writes `ns.db.modules` (`Core/Init.lua:196-207`), so a failure leaves a SavedVariables setting changed for every later test.
- Lines 401-403: `pane:ToggleSection(L["Weapons"])` shuts and reopens a section in the body. A failed assert at 402 leaves Weapons shut in `pane.shutSections` for the rest of the run. Lines 399-408 set `pane.open[...]`, and the restore (428-431) only refreshes.
- Lines 258, 312, 344, 374 hide their cell or portrait in the body, not in the restore.
- Lines 214-220 and 482-487 reset `filter.class`, `filter.usable` and `filter.types` to empty instead of putting back what was there. That holds only while the smoke character starts with no filter.
- Nothing hovers a priced item (R2), and the skill-rank test (321-322) relies on the `wow.lua` globals that Forever lacks (R1). The tests prove the code matches the stand-in, not the game.

**Why it matters.** One failing assert would cascade into unrelated
failures in the module tests that run after this file. The merged
`W.Restoring` exists to stop exactly that.

**Evidence.** Lines quoted above. `Core/Init.lua:196-207` is where
`Modules:Set` writes SavedVariables.

**Fix.**
- Wrap tests 4 and 5 in `Restoring`.
- Save `wasQuests`, the filter's previous `class`/`usable`/`types`, and `pane.shutSections`/`pane.open` (shallow copies) before the body, and restore them in the restore function.
- Hide created cells in the restore.
- Add a case that hovers `{ itemID = id, cost = 1550000 }` with `GetCoinTextureString` set to nil inside the test (restored after), so the in-game path is what's tested.
- Add a case for `SkillRank` with the skill globals nil'd the same way.

### R5 · The file grew by 42 lines: splits that don't earn a name, and concrete cuts

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/LootGrid.lua` (lines below)
- **Status:** fixed in round 2 (uncommitted, on `c0e5c79`): cuts 1-4, 6 and 8 done. Cut 5 (inline `SetSpell`) skipped on purpose: it would move `L["Enchant"]`'s first appearance behind the search-cell keys, which changes the locale order. I checked, and the reason holds. Cut 7 done as `AddHintedLines`. Whether the +48 is earned: see R16

**What's wrong.** The +42 lines come from structure, not code: there are 23
more functions (127 to 150), and each costs a signature, an `end`, a blank
line and usually a header comment. Comment lines grew by 35, mostly that
per-function header. Code lines fell by 15.

Most of the splits earn their lines:
- `CreateCell` went from 512 lines to about 75;
- `pane:Refresh` from 160 to about 85;
- `CreateRelatedQuests`, `CreateSpoiler` and `CreateFilterBar` each take a self-contained 30-90 line block out of `ns.UI.CreateLootGrid`;
- `CreateCheckCard`, `AddFilterTooltip`, `FromPool`, `ShowHintAtCursor`, `SetSpellLook`, `BossLevelText` and `ItemTooltipLines` each replace two or more copies.

These do not earn their lines:

1. `CopyOfDrop` (`:1787-1794`, 9 lines with comment and blank) is called once (`:1808`) and replaces 3 inline lines. Inline it again: `drop = {}; for key, value in pairs(item) do drop[key] = value end; drop.boss, drop.from = nil, {}` on three lines. About -5.
2. `DrawSectionToggle` (`:2435-2450`) is called once, from inside `DrawHeaderLine`'s loop, and has to thread `drawn` through. Put its body back under `if line.shuts then` in `DrawHeaderLine`. That's two levels of nesting in a small function. About -5.
3. `NewSectionLabel` (`:2391-2393`) is a 3-line wrapper around `T:Text(canvas, pane.fonts.label)`. Pass it inline: `FromPool(pane.sections, drawn.sections, function() return T:Text(canvas, pane.fonts.label) end)`. About -4.
4. `Cell:Fill` (`:1287-1310`) is called only by `Cell:SetEntry` (`:1214`). Since its branches no longer `return`, its body can be the top of `SetEntry`. About -4 (see R7).
5. `Cell:SetSpell` (`:1037-1041`) is two lines and called once (`Fill`). Inline it as `self:SetSpellLook(entry.spellID); self.sub:SetText(L["Enchant"])` in that branch. About -5, optional.
6. `OpenSpoilerText` (`:2851-2869`): the quest and boss branches wrap to two lines each only because `T:ColorCode(T.color.quest)` and `T:ColorCode(T.color.link)` are computed inline. Hoist them into locals next to `text`, as `SetRelatedQuests` already does with `questColor` (`:2824`). About -2.
7. The heading / detail / hint tooltip is written out by hand in `ShowStarTooltip` (`:568-570`), the go button (`:614-616`) and `AddFilterTooltip` (`:1981-1983`). One local `AddHintedLines(heading, detail, hint)`, written together with R6's color names, removes about 4 more lines.
8. `-- A one-line hint at the mouse, for links and click areas.` (`:1855`) restates `ShowHintAtCursor`'s name. Drop it. -1.

Items 1-8 come to roughly -30. That puts the file about 12 lines over its
starting length. Getting clearly under 2892 would mean merging back splits
that do earn their names (the `Create*` blocks and `CellPicker`), which costs
clarity. My judgement is to take the cuts above and accept a near-even
count. The listed cuts are the ones that don't cost anything.

**Why it matters.** Mike set "less code" as the aim of the pass. A
one-caller helper with its own comment makes the reader jump for no gain.

**Evidence.** `wc -l`, plus counts of blank, comment and code lines in both
versions. `grep -c` for each helper's name: definition plus one use for
`CopyOfDrop`, `DrawSectionToggle`, `SetSpell`, `Fill`.

**Fix.** Make the cuts listed.

### R6 · Tooltip colors, the icon crop and the drop-chance format are bare repeated numbers

- **Severity:** should fix
- **Area:** Readability (searchable names)
- **Where:** `NeedRoll/UI/LootGrid.lua`: `0.76, 0.93, 1` ×12, `0.5, 0.6, 0.65` ×7, `0.99, 0.82, 0.62` ×6, `0.6, 0.6, 0.6` ×3; `SetTexCoord(0.08, 0.92, 0.08, 0.92)` ×4 (`:892, 1029, 1114, 1333`); `("%.0f%%"):format(entry.dropRate * 100)` ×2 (`:493, 1337`)
- **Status:** fixed: names and most literals in round 2, the rest (R13) in round 3

**What's wrong.** Every tooltip in the file writes its title (peach),
label (light blue) and hint (grey-blue) colors as literals. The same goes
for the icon trim and the whole-percent drop chance.

**Why it matters.** READABLE-CODE §7 says anything used in more than one
place gets a name you can grep for. To recolor the hint lines, you'd have to
know the triple and hunt for 7 copies, and a typo in one would go unnoticed.

**Evidence.** `grep -c` on the file. The other UI files use the same
triples (`grep -rl` finds 1-4 more files each), so a shared `T.color`
entry is the cross-module follow-up.

**Fix.** Near the top of the file:

```lua
-- The loot grid's tooltip colors: titles, labels beside a value, and hints.
local TIP_TITLE, TIP_LABEL, TIP_HINT = { 0.99, 0.82, 0.62 }, { 0.76, 0.93, 1 }, { 0.5, 0.6, 0.65 }
local ICON_CROP = { 0.08, 0.92, 0.08, 0.92 } -- trims Blizzard's baked-in icon border
```

Then use `GameTooltip:AddLine(text, unpack(TIP_HINT))` and
`self.icon:SetTexCoord(unpack(ICON_CROP))`. Add a
`DropChanceText(dropRate)` for the two drop-chance formats. Add the shared
version under "Cross-module".

### R7 · `SetEntry` / `Fill` / `Prepare`: one job under three names, and a comment credits the wrong one

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/LootGrid.lua:1044-1045`, `1214-1310` (`SetEntry` 1214, `Prepare` 1248, `Fill` 1287)
- **Status:** fixed in round 2 (uncommitted, on `c0e5c79`): `Fill` merged into `SetEntry`; the comment now names `Prepare` (`:1067-1068`)

**What's wrong.** `SetAbility`'s comment says "Cells are reused, so Fill
puts an item's icon and name back". The code that does this is `Prepare`
(`if self.abilityLayout then ... self:PlaceIcon() end`). `Fill` has no
comment, and its only caller is `SetEntry`.

**Why it matters.** A reader following the comment lands in `Fill` and has
to read on to find the reset (pillar 9, a comment that misleads).

**Fix.** Fold `Fill` into `SetEntry` (R5 item 4) and change the comment to
"so Prepare puts an item's icon and name back".

### R8 · Cryptic short names left

- **Severity:** nit
- **Area:** Readability
- **Where:** `fs` in `Cell:PlaceTick` (`:996-1020`) and `TwoLineWidth` (`:1379-1390`), 20 uses; `h` in `MaxOffset` (`:2368`) and `OffsetFor` (`:2624`); `k` in the `Sectioned` sort (`:200`)
- **Status:** fixed in round 2 (uncommitted, on `c0e5c79`): `nameText`, `lineHeight`, `keyIndex`

**What's wrong.** `fs` is "font string" abbreviated, and `h` is a line's
height. Neither is in READABLE-CODE §8's allowed aliases.

**Fix.** Rename `fs` to `nameText`, `h` to `lineHeight` and `k` to
`keyIndex`.

### R9 · Cell methods written two ways

- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** `NeedRoll/UI/LootGrid.lua:894-900` (`function cell:SetBorderColor` inside `CreateCell`)
- **Status:** fixed in round 2 (uncommitted, on `c0e5c79`): `Cell:SetBorderColor` reads `self.native`, set at build (`:905`). Same behaviour as the closure, which captured `native` at build too; `MainFrame.lua:11/1271` confirms a skin swap parks windows rather than rebuilding them

**What's wrong.** Every other cell method moved to the `Cell` table, but
`SetBorderColor` stays a per-cell closure over the local `native`.

**Fix.** Write it as `function Cell:SetBorderColor(r, g, b, a)` and test
`T.native`, the way the rest of the file does. No line cost.

### R10 · A skip hidden inside an `ipairs` expression

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/LootGrid.lua:1804`
- **Status:** fixed in round 2 (uncommitted, on `c0e5c79`): `local drops = not enc.overview and enc.loot or {} -- the Overview page has no drops of its own`

**What's wrong.** `for _, item in ipairs(not enc.overview and enc.loot or {}) do`
replaced `if not enc.overview then for ... end end`. It saves one level of
nesting, but the reader has to decode that the Overview page is skipped.

**Fix.** Either keep the expression and add `-- the Overview page has no drops of its own`,
or name it: `local drops = not enc.overview and enc.loot or {}`.

### R11 · Global `ITEM_CLASSES_ALLOWED` stand-in lives for the whole run

- **Severity:** nit
- **Area:** Readability (tests)
- **Where:** `tests/smoke/modules/UI-LootGrid.lua:7`
- **Status:** left as is: the brief allows a stand-in global in a module test; per the implementer it moves to `wow.lua` at merge (still at `UI-LootGrid.lua:7`)

**What's wrong.** It is defined at file load and never removed. The brief
allows this, and its comment says it moves to `wow.lua` at merge.

**Fix.** Make sure the merge does move it (list it under "Cross-module" for
the merger), so it doesn't live on in a module file.

### R12 · `SkillRank`'s new comment says Forever has no skill-line API

- **Severity:** should fix
- **Area:** Readability (avoid disinformation)
- **Where:** `NeedRoll/UI/LootGrid.lua:389-392`
- **Status:** fixed in round 3 (uncommitted, on `c0e5c79`): the comment now reads "This reads the old skill-line globals; Forever has them only as C_SkillInfo.*, so in game the rank is nil for now." (`LootGrid.lua:379-380`)

**What's wrong.**

```lua
-- The character's rank in a skill ("Mining"), or nil when they don't have it.
-- Forever has no skill-line API, so there it is always nil.
local function SkillRank(name)
    if not (GetNumSkillLines and GetSkillLineInfo) then return nil end
```

Forever does have one: `C_SkillInfo.GetNumSkillLines` and
`C_SkillInfo.GetSkillLineInfo` (`GlobalAPI.lua:3812/3814`). What it lacks are
the two old globals.

**Why it matters.** A reader takes the comment at its word and concludes the
skill colors (Scarce reagents) and recipe ranks (`RecipeBand.lua:302`) can
never work in game. In fact they are one namespace switch away. READABLE-CODE
§5 and §9: a wrong comment is worse than none.

**Evidence.** The comment quoted above, plus the grep of the `forever` list.

**Fix.** Say what's true:
`-- Forever has these only as C_SkillInfo.*, so in game this is nil until it
uses them (a visible change, left for Mike).` Also put the C_SkillInfo
switch on the hand-back's list for Mike.

### R13 · R6 half done: white still written out, and one color spelled field by field

- **Severity:** should fix
- **Area:** Readability (code consistency, searchable names)
- **Where:** `NeedRoll/UI/LootGrid.lua:52` (`TIP_WHITE = { 1, 1, 1 }`); literal `1, 1, 1` at `:352`, `:552`, `:807`, `:811`, `:1533`, `:1995`; `:547`
- **Status:** fixed in round 3 (uncommitted, on `c0e5c79`): `TIP_WHITE` renamed `TIP_TEXT`, and all six `1, 1, 1` lines use it (`:341`, `:542`, `:800`, `:804`, `:1526`, `:1988-1989`). The wrapped lines use `local r, g, b = unpack(...)` (`:536`, `:1988`). The one-off reagent green stays a literal on its only line (`:542`)

**What's wrong.** `TIP_WHITE` exists and `AddTipPair` uses it for values,
yet six tooltip lines still pass `1, 1, 1`. For example:
- `GameTooltip:AddLine(entry.enc.name, 1, 1, 1)` (`:352`)
- `GameTooltip:AddLine(levelText, 1, 1, 1)` (`:1533`)
- `if about then GameTooltip:AddLine(about, 1, 1, 1, true) end` (`:1995`)

`ShowRecipeTooltip` writes `TIP_LABEL[1], TIP_LABEL[2], TIP_LABEL[3], true`
(`:547`), because `unpack` only expands in the last argument. The name
`TIP_WHITE` says what color it is, not what it's for, unlike the other five
names.

**Why it matters.** Same job, two ways, in one file (READABLE-CODE §6). A
grep for `TIP_WHITE` misses half the white lines.

**Evidence.** `grep -n "GameTooltip:Add.*, 1, 1, 1"` returns five of them; the sixth is the left color on the wrapped `AddDoubleLine` at `:551-552`.

**Fix.**
- Rename `TIP_WHITE` to `TIP_TEXT` (body text and values).
- Use `unpack(TIP_TEXT)` where the color is the last argument.
- Where a wrap flag follows, write `local r, g, b = unpack(TIP_LABEL)` first and pass `r, g, b, true`, as `AddTipPair` already does.

The one-off reagent-total green (`0.23, 0.53, 0.36`, `:552`) appears once,
so it can stay.

### R14 · New helper comments: one restates, one overstates

- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `NeedRoll/UI/LootGrid.lua:65`, `:71`
- **Status:** fixed in round 3 (uncommitted, on `c0e5c79`): `AddTipPair`'s comment says why it exists (`:66`); `AddHintedLines` is gone

**What's wrong.**
- `-- A tooltip line in two colors: `left` in leftColor, `right` in rightColor.` repeats the signature.
- `-- The tooltip shape most of this pane uses: a title, a detail under it and a hint.` says "most", but `AddHintedLines` has two callers (`:591`, `:636`). `ShowPlaceTooltip`, `ShowRecipeTooltip` and `AddFilterTooltip` all have other shapes.

**Fix.** Make the first comment say why the helper exists:
`-- AddDoubleLine with named colors (unpack only spreads the last argument).`
Make the second say who uses it: `-- The star's and the go button's tooltip: ...`.
Or drop the helper (R16).

### R15 · Test leftovers: a restore repeated in the body, two ways of putting tables back

- **Severity:** nit
- **Area:** Readability (tests)
- **Where:** `tests/smoke/modules/UI-LootGrid.lua:335`, `:503-506`
- **Status:** fixed in round 3 (uncommitted, on `c0e5c79`): the in-body restore is gone; `pane.open` is refilled in place like `shutSections` (`UI-LootGrid.lua:505-506`)

**What's wrong.**
- Line 335 puts `IsModifiedClick` and `ChatFrameUtil.InsertLink` back in the test body, and the restore (`:357-359`) does it again.
- The fold test's restore refills `pane.shutSections` in place (`wipe` plus copy), but replaces `pane.open` with the saved copy (`pane.open = saved.open`). Both work today, since everything reads `pane.open` through the pane, but they are two ways of doing one job.

**Fix.** Delete line 335; the stand-ins are harmless for the rest of the
test. Restore `pane.open` the same way as `shutSections`, or replace both.

### R16 · The +48 lines: code is down, but two new helpers cost more than they save

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/LootGrid.lua:71-80`; the file as a whole
- **Status:** fixed in round 3 (uncommitted, on `c0e5c79`): `AddHintedLines` and `DropChanceText` inlined again. File: 2934 lines (base 2892, +42); code 2368 (base 2385, -17), comments 400 (+40), blank 166 (+19). Remaining growth: left for Mike to accept, as the coordinator asked. I found no further cut that costs nothing (see Round 3 notes)

**What's wrong.** Where the lines went, round 1 to round 2 (`diff` of the
two versions):
- -16 from the cuts (CopyOfDrop -5, DrawSectionToggle -3, NewSectionLabel -4, Fill merge -3, comment -1);
- +3 for R9 (a method with its comment, `cell.native` and a comment);
- +2 for R1's guard and comment;
- about +17 for R6.

R6's constants (4 lines) and `AddTipPair` (6 lines, 6 callers, each made
shorter or kept on one line) earn their place. Two helpers don't:
- `AddHintedLines` (`:71-76`, 7 lines with comment and blank) has 2 callers and saves 4 lines: net +3.
- `DropChanceText` (`:78-81`, 5 lines) has 2 callers and saves nothing; `("%.0f%%"):format(rate * 100)` was already clear on its line. The brief: "don't add a constant for a number used once whose meaning is plain from its line" applies in spirit to a one-line wrapper.

Overall, the file is 48 lines over the base. All of it is comments (+40)
and blank lines (+21); code is 13 lines shorter. The comment growth is the
header on each function split out in round 1. I judged those splits worth
it (`CreateCell` 512 → ~75 lines, `pane:Refresh` 160 → ~85). The brief's
goal that the group ends shorter is not met, though.

**Why it matters.** Mike made "less code" the aim of the pass. Every line
of growth that isn't buying clarity works against it.

**Evidence.** `wc -l` and counts of blank, comment and code lines for base,
round 1 and round 2. `grep -n` for each helper's callers.

**Fix.**
- Inline `DropChanceText` back at its two uses (-5).
- Either inline `AddHintedLines` (-3), or keep it and fold the filter tooltip's and the place tooltip's hint lines into the same shape.
- Shorten R14's two comments.

That brings the file to about 2930, still about 38 over. Getting under
2892 would mean dropping header comments on the split-out `Cell` methods
(not recommended) or merging back splits that earn their names (not
recommended). Unless Mike accepts the remaining growth, say so in the hand-back.

## Area notes

### Readability

I checked each changed function against all nine pillars of
`docs/READABLE-CODE.md`.

- Names: `AddFoldItems`, `foldItems`, `isGenericArmor`, `castMs`/`castText`/`rangeText`, `AmountRange`, `SourceDropRate`, `RoundedBarTexture`, `KeySet`, `entryNeed`, `packed` and `secondHeading` all now say what they are. `ShowPlaceTooltip` lost its unused `cell` parameter.
- Guard clauses: `Cell:ShowTick` and `Deduped`'s `if name ... elseif entry.itemID` are flatter than before. `Lines()`'s new `AddHeader`/`AddItem` keep the old branch order exactly. I traced all eight old branches against the new three; header-while-shut and item-while-folded both still drop out. The old `line.box.next` became `box.next` read before the reassignment, which is the same table.
- Comments: they explain why (the Deepgrave Trousers line count, secret line counts, "English commas in every language"). I found no change narration. The only restating one is listed in R5 item 8, and the only wrong one is R7.
- Formatting: 4 spaces, LF, `local _, ns = ...` at line 19, no line over 120.
- Lua 5.1 traps: none added. The `x and nil or y` shape doesn't appear. `#` is used only on arrays built with consecutive indices.
- Look unchanged:
  - `-ShutHeight() / 2` equals the old `-(10 + ToCanvas(size) / 2)` exactly (`ShutHeight` is `20 + ToCanvas(size)`, and halving is exact in floating point).
  - `CellTextBottom(fonts, 0)` / `(fonts, 7)` keeps the old addition order.
  - `CreateCheckCard` keeps both lists' widths (200 and 160), heights and anchors.
  - The spoiler's link tooltip still calls `SetOwner` before `SetHyperlink`.
  - The implementer's 194 MB before/after region snapshot is their claim; I did not re-run it.

### WoW API

Every name the change starts calling without a guard, checked against
`Ketho/BlizzardInterfaceResources@forever` (downloaded and grepped):

| Name | Kind | In `forever` lists | Where |
| --- | --- | --- | --- |
| `GetNumSkillLines`, `GetSkillLineInfo` | global function | **no** (only `C_SkillInfo.*`) | GlobalAPI.lua:3812/3814 → R1. Round 2: guarded again (`:392`) |
| `GetCoinTextureString` | global function | **no** (only `C_CurrencyInfo.GetCoinTextureString`) | GlobalAPI.lua:1377 → R2. Round 2: no longer called |
| `ChatEdit_InsertLink` (unchanged call) | FrameXML function | **no** (`ChatFrameUtil.InsertLink` is) | FrameXML.lua → R3. Round 2: no longer called |
| `ChatFrameUtil.InsertLink` (round 2) | FrameXML function | yes | FrameXML.lua:563; `wow.lua` has no stand-in for it, so the module test defines one for its duration |
| `C_TooltipInfo.GetItemByID` | C_ function | yes | GlobalAPI.lua |
| `C_Item.IsItemDataCachedByID` | C_ function | yes | GlobalAPI.lua |
| `C_Spell.IsSpellPassive`, `C_Spell.GetSpellDescription` | C_ function | yes | GlobalAPI.lua |
| `issecretvalue` | global function | yes | GlobalAPI.lua |
| `SetPortraitTextureFromCreatureDisplayID`, `GetRealmName` | global function | yes | GlobalAPI.lua |
| `GameTooltip_ShowCompareItem`, `GetCreatureDifficultyColor` | FrameXML function | yes | FrameXML.lua. Its return is always a color table (inferred), so dropping the gold fallback is safe |
| `WhiteLargeNumberFont` | font object | yes | Templates.lua |
| `Region:SetPropagateMouseClicks`, `FontString:GetNumLines` | widget method | yes | WidgetAPI.lua |
| `TRANSMOG_COLLECTION_UPDATED`, `_SOURCE_ADDED`, `_SOURCE_REMOVED` | event | yes | Events.lua:1920-1922 (registered unconditionally now; correct) |
| `Enum.ItemClass.Consumable/Weapon/Armor/Questitem` | Enum | yes: 0, 2, 4, 12, the values the literals had | LuaEnum.lua:4642-4655 |
| `ITEM_STARTS_QUEST`, `ITEM_CLASSES_ALLOWED`, `ITEM_MIN_LEVEL` | global string | yes | GlobalStrings/enUS.lua:13041, 12674, 12738 |
| `LOCALIZED_CLASS_NAMES_MALE/FEMALE`, `RAID_CLASS_COLORS`, `FACTION_BAR_COLORS` | global table | not listed (by design); nil-guarded (male via `ns.UI.ClassName`) | inferred |
| `ns.UI.ShowOnMap`, `ns.UI.ProfessionIcon` (guards removed) | addon | defined unconditionally at load (`Overview.lua:578`, `Lists.lua:464`), called only at run time | read |

- No new globals: W11 lists show none added. No taint: no secure frames or protected calls touched.
- Events: the three transmog events are permanent listeners, so nothing needs unregistering.
- Secret values: `PlaceTick` keeps the `issecretvalue(lines)` guard before comparing the line count.
- Upvalues: `ns.UI.CreateLootGrid` is at 50 of 60 (was 47). Watch it in later rounds.
- `L[...]`: unchanged keys and order. The dead `L["Requires Level %d"]` fallback beside `ITEM_MIN_LEVEL` stays because removing the key would touch `enUS.lua`; left as is per the brief.
- `docs/STYLE-GUIDE.md`: no update needed, since no size, color or layout changed.

### Redundant code

Round 3: no further cut that costs no clarity. Of the +42 lines, the remaining candidates all have a cost:
- Header comments on the split-out `Cell` methods and `Create*` blocks: each explains a game fact or a layout reason.
- Merging back `CellPicker` or `Prepare`: each would put a 60+ line function back.
- `SplitWords`/`CellTextBottom`: each removes a real duplicate.

I leave the growth for Mike, as agreed.

Round 2: `AddTipPair` (6 callers) and the `TIP_*` / `ICON_CROP` names earn their place. `AddHintedLines` and `DropChanceText` don't yet (R16). Nothing in `Theme.lua` (`function T:` list) covers tooltip line colors, so a file-local helper is right for now; a shared `T.color` tooltip palette stays on the Cross-module list.

Compared against:
- the `function T:` list in `Theme.lua` (`T:Pill`, `T:Row`, `T:Text`, `T:Rounded`, `T:CardBackdrop`, `T:Fill`, `T:ScrollStart`...);
- `ns.Items` (`Load`, `Quality`, `Collected`);
- `ns.UI.ClassName`;
- `BreakUpLargeNumbers` (`Thousands` kept on purpose: the game uses "." in German, and the comment says so);
- `CopyTable` (a deep copy, so not a fit for `CopyOfDrop`; see R5 for inlining it instead).

`FromPool`, `CreateCheckCard`, `AddFilterTooltip`, `ShowHintAtCursor`,
`ItemTooltipLines`, `PlaceName`, `BossLevelText`, `SplitWords` and
`SetSpellLook` each remove real duplicates. Dead code removed:
`ns.UI.lootClasses` (no reader anywhere), `LevelColor`, `PORTRAIT_MASK`
(now `ROUND_MASK`), `ITEM_CLASS`, `Fonts()`, and the `missing` list in
`LootSections`. I found no unused locals (luacheck 0) and no debug prints.

`GatherRate` and `SourceDropRate` look alike but round differently ("2%"
vs "2.0%"), so merging them would change text. Leave them.

The implementer's "Cross-module" list (`CreateRule`, the `SetBorderColor`
copies, `TempPortraitAlphaMask` in nine files, `RoundedBarTexture` vs
`SlicedTexture`, the profession ring) checks out where I spot-read it. Add
R6's tooltip colors and icon crop to it.

Outside this pass, for Mike: the implementer's "empty section headings kept
by `FilterLoot`" is a real behaviour question.

### Security

None. The change touches no addon messages, chat, SavedVariables written by
other players, or sending. The only saved data it reads or writes is
`ns.db.lootFilter[<name>-<realm>]` (unchanged key) and `ns.db.collectionTicks`.
Spoiler and Related Quests text comes from shipped data, not from other
players. The test file adds no names or credits.

## Round history

- 2026-10-18 · `c0e5c79` + uncommitted · Changes needed · opened R1-R11 (2 blocking, 4 should fix, 5 nits), closed none.
- 2026-10-18 · `c0e5c79` + uncommitted (round 2) · Changes needed · closed R1-R10 (R6 partly; rest in R13), R11 left as is; opened R12-R16 (3 should fix, 2 nits).
- 2026-10-18 · `c0e5c79` + uncommitted (round 3, last) · Ready · closed R12-R16 and the rest of R6; none opened. The +42 lines over the base are left for Mike to accept.
