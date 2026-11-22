# Review: Readability pass, Shopping List and recipe band (UI/Shopping.lua, UI/RecipeBand.lua)

| | |
| --- | --- |
| Branch | `rp-shopping-recipes` (group worktree of `claude/addon-readability-pass-rg51s6`) into `dev` (PR # once it exists) |
| Commit reviewed | `c0e5c79` plus uncommitted changes (`git diff HEAD`, untracked `tests/smoke/modules/UI-Shopping.lua`, `tests/smoke/modules/UI-RecipeBand.lua`) |
| Date | 2026-10-18 |
| Round | 2 |
| Verdict | **Ready** after round 2 fixes (0 blocking, 0 should fix; R13 is a behaviour question left for Mike) |
| Needs | `/reload`: only existing addon Lua files change (no `.toc`, no new addon files, no SavedVariables keys) |

## What the change does

Nothing a player should see changes. The Shopping List tab (the crafting
tree and the "To buy" column) and the recipe band over a profession's recipe
list (slot chips, Skill-ups / Can learn / Hide grey toggles, folded colour
sets, rank lines and gear sets) are rewritten for readability: cryptic names
are spelled out (`b` to `chip`, `f` to `isPill`, `top` to `isAddedItem`,
`n`/`k`/`w` loop names in `Balance` and `PlaceLines`), long functions are
split (`ShowTreeTooltip` used directly instead of through `row.showTooltip`,
`CountHoldings` out of `pane:Update`, `SharedEnds`/`SharedAnywhere` out of
`Title`, `ShowChips`/`ShowToggles` out of `RB:Layout`), the band's
ADDON_LOADED word matching becomes one `GROUP_BY_NAME` table per profession,
and dead fallbacks go (`C_Item.GetItemSubClassInfo`/`GetItemSubClassInfo`
wrapper, the `C_Item.GetItemInfoInstant`, `GetLocale`, `ns.UI.RecipeProduct`,
`ns.UI.SkillRank` and `RAID_CLASS_COLORS` guards, the unused `RB.memberOf`,
`chip:Underline`/`chip:NoUnderline`, `chip.number`). Two smoke test files are
added. Lines after round 2: Shopping.lua 656 to 651, RecipeBand.lua 818 to
818 (group 1474 to 1469). Round 1 was 649 + 824 = 1473.

## Scope

- `NeedRoll/UI/Shopping.lua`: tooltip moved up and called directly;
  `TIP_LABEL`, `AddCountLine`, `NO_CLASS_COLOR`, `CountHoldings` added;
  `ItemName` and `Line` wrappers folded in; `SetItem` no longer returns a
  value (no caller used it); `CreateCheck` builds its label once for both
  looks; renames in `DrawLines`, `SetupTreeRow`, `SetupTotalRow`,
  `CreateColumn`; `pane:Update` shows/hides its parts in a loop.
- `NeedRoll/UI/RecipeBand.lua`: `ProductInfo` (was `ItemInfo`, now also
  returns the equip slot), `HasWord`, `GroupByWords`, `GROUP_BY_NAME`,
  `MarkRankLines` (was `RankLines`), `ENCHANTING_ITEM_GROUPS`,
  `SharedEnds`, `SharedAnywhere`, `RGBA`, `IsPill`, `ShowChips`,
  `ShowToggles`; `all = true/false` scheme flag became `noAllChip`; the rule
  gradient is set once in `RB:Build`; `RB:Paint` takes its total from
  `Counts(instance).ALL`; `RB.memberOf` removed.
- `tests/smoke/modules/UI-Shopping.lua` (new, 11 scenarios, 336 lines) and
  `tests/smoke/modules/UI-RecipeBand.lua` (new, 9 scenarios, one dev-only,
  368 lines). Since round 2 each file has `Restoring` and a wrapper
  (`ShoppingTest`, `BandTest`) that saves and puts back everything its
  scenarios change. At integration the local `Restoring` copies became the shared
  `W.Restoring` from `tests/smoke/wow.lua` (#596).
- Round 2 code changes: `row.itemButtons` built once; `RAID_CLASS_COLORS`
  guard back; `fitCount`, `RowForSet`, `membersInList`; row height set in
  `pane:Update` again; `Enum.ItemClass` (local `ItemClass`) and
  `Enum.ItemWeaponSubclass.Wand` in place of numbers; comments trimmed;
  `RGBA(GOLD, 0.38)`; the `OnSizeChanged` hook uses `pane`; `Balance` lost
  its `count == 0` early return.
- Generated data: none touched. `NeedRoll/Locales/`: none touched.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` (both addon files, both test files) | passed (round 2) |
| `luacheck --std lua51 -q --codes` W11x global names, base vs new | Shopping.lua: same list. RecipeBand.lua: loses `GetItemSubClassInfo`, gains `tContains` (round 1) and `Enum` (round 2, from R6). Both are real Forever globals; see R11 |
| `luacheck --no-global -q`, base vs new | Round 2: Shopping.lua 2 warnings (both old: unused `self` :113, the 214-char tooltip `L[...]` line :576). RecipeBand.lua 10, all unused `self` on `RB:` methods; :446 `RB:Fold` is the one new since base (R11, accepted). Test files: 0 warnings (were 14) |
| `tests/smoke/check.sh` | round 2: passed, all three modes (dev, packaged, secret); all new scenarios `ok` |
| New tests against the base code (scratch copy with `HEAD`'s two files) | round 2: all 20 pass, so they pin the old behaviour |
| Restore on failure (scratch copy, `error("injected")` right after the `GetItemCount` stand-in, after `W.locale = "deDE"` and after `/nr chipstyle`, then a check scenario) | the 3 injected scenarios fail; the check scenario passes: `GetItemCount`, locale `enUS`, chip style `C`, `shoppingBags` off; `W.itemFacts` has 92 entries, the same as a run without the module files |
| `python3 tools/locales.py --check` | passed |
| `python3 tools/translations.py` | ran, exit 0 |
| Grouping old vs new (my own harness, see Area notes) | round 1 and round 2: identical, 9,912 recipe lines and 484 folded set rows, enUS and deDE, 4 item-info variants |
| Scraper unit tests | not run: no scraper change |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | blocking | WoW API (smoke tests) | `tests/smoke/modules/UI-Shopping.lua`, `UI-RecipeBand.lua` (whole files) | No `Restoring`; overrides are put back only when a test passes, and `W.itemFacts` never | fixed in round 2 (uncommitted) |
| R2 | should fix | WoW API (smoke tests) | `UI-RecipeBand.lua:86-103`, `UI-Shopping.lua:208-267` | The rewritten branches aren't pinned by any test | fixed in round 2 (uncommitted) |
| R3 | should fix | WoW API | `Shopping.lua:315` | `RAID_CLASS_COLORS` lost its nil guard | fixed in round 2 (uncommitted) |
| R4 | should fix | Readability | `Shopping.lua:533-551` | `CountHoldings` also sets row heights, and "how many are left" is ambiguous | fixed in round 2 (uncommitted) |
| R5 | should fix | Readability | `RecipeBand.lua:210-212` | Engineering's comment gives the wrong order and doesn't parse | fixed in round 2 (uncommitted); wording follow-up in R12 |
| R6 | should fix | Readability | `RecipeBand.lua:62, 185, 204-206, 215-218` | Item class numbers repeated with no name (`Enum.ItemClass` exists) | fixed after round 2: a named `TradeGoods` subclass table and `TradeGoodsName`, used by the group names and the checks |
| R7 | nit | Readability | `RecipeBand.lua:155, 162-165, 357, 379, 390-395` | Comments to trim: Title repeats its helpers, a "same way" with no referent, a long wrap | fixed in round 2 (uncommitted) |
| R8 | nit | Readability | `RecipeBand.lua:199, 259, 343, 453, 604`; `Shopping.lua:377` | Names: `SetRow`, `inList`, `lastFit`, `list` for the pane, `noAllChip` | fixed in round 2 (uncommitted); `noAllChip` left as is: it saves three lines, which the finding allowed |
| R9 | nit | Redundant code | `Shopping.lua:273` | A new table per tree row per redraw | fixed in round 2 (uncommitted) |
| R10 | nit | Readability | `RecipeBand.lua:504` | Chip's edge still spells out GOLD by hand | fixed in round 2 (uncommitted) |
| R11 | nit | WoW API / checks | `RecipeBand.lua:384, 446`; test files | `tContains` joins the global-name list; new unused-`self` warning; test-file warnings | test warnings fixed in round 2; `tContains`, `Enum` and `RB:Fold`'s `self` left as is: real Forever globals, and the colon call is what `UI/Lists.lua:2279` uses. Name them in the hand-back |
| R12 | nit | Readability | `RecipeBand.lua:50, 209-211, 356, 378`; `UI-RecipeBand.lua:157` | Round-2 comments wrap at 82-93 columns, the Engineering one ends in a fragment and repeats a reason nobody checked; the test writes 19 for the wand | fixed after round 2: Engineering comment rewritten as suggested, the test uses `Enum.ItemWeaponSubclass.Wand`; the three long comment lines were kept as they are (within 120 columns) so the group stays at its starting length |
| R13 | nit | Readability (smoke tests) | `tests/smoke/modules/UI-RecipeBand.lua:150-152` | The test pins "Goblin Rocket Helmet" under Fireworks as if that were wanted | left for Mike: the behaviour is unchanged from the base code |

### R1 · No `Restoring`; overrides are put back only when a test passes, and `W.itemFacts` never

- **Severity:** blocking
- **Area:** WoW API (smoke tests)
- **Where:** `tests/smoke/modules/UI-Shopping.lua:183-205, 214-231, 273-280, 292`; `tests/smoke/modules/UI-RecipeBand.lua:37-55, 114-133, 183-185, 199-236, 246-276, 285-298`
- **Status:** fixed in round 2 (uncommitted). Both files now have `Restoring` and a wrapper (`ShoppingTest`, `BandTest`) that saves the list, subtract settings, `ns.db.characters`/`bags`, `W.uncached`, the two `C_Item` stand-ins, `W.itemFacts` (a copy), `W.skillLines`, `W.locale`, `RB.style` and `ns.UI.RecipeProduct`, and puts them back. The chips test frame is hidden in its own `Restoring`. I checked this by forcing errors (see Checks).

**What's wrong.** The brief requires each module test file to start with
`local function Restoring(test, restore)` (xpcall the test with a traceback,
run `restore`, re-raise) and every test to restore what it overrides even
when it fails. Neither file has it (`grep -n Restoring` finds nothing).
Every restore line sits after the asserts:

```lua
local GetItemCount = C_Item.GetItemCount
C_Item.GetItemCount = function() return 999 end
...                                  -- 8 asserts
C_Item.GetItemCount = GetItemCount   -- UI-Shopping.lua:204, skipped if any assert fails
```

The same holds for `C_Item.GetItemNameByID` and `W.uncached` (:273-280),
`ns.db.characters`, `ns.db.bags`, `ns.db.shoppingAlts`, `W.mouseFocus`
(:214-231), `ns.db.shoppingBags` (:193-203), the saved list itself (only the
last test clears it), `W.locale = "deDE"` (UI-RecipeBand.lua:183-185),
`RB.style` flipped by `/nr chipstyle` (:285-296), `W.skillLines` (set to
`nil` at the end, not back to what it was), and the 200x100 test frame
(:246, hidden only at :276). `TailoringItems` (:37-55) writes made-up item
facts into `W.itemFacts` for every Tailoring product and nothing ever takes
them out, pass or fail.

**Why it matters.** Module files run in name order after `scenarios.lua`,
and other groups' files (`UI-Wishlist.lua` and the rest) will run after
these once merged. One failing assert here then leaves `GetItemCount`
answering 999, the client in German, or chips as pills for every later test,
so one real failure shows up as a cascade of unrelated ones, and the item
facts leak into later tests even on a clean run.

**Evidence.** Read both files in full; `grep -n "Restoring"` on both: no
match. BRIEF.md, "Smoke tests per module".

**Fix.** Add the helper at the top of each file and wrap each test that
overrides something:

```lua
local function Restoring(test, restore)
    local ok, err = xpcall(test, debug.traceback)
    restore()
    if not ok then error(err, 0) end
end
...
fn = function(W, ns)
    local GetItemCount = C_Item.GetItemCount
    Restoring(function()
        C_Item.GetItemCount = function() return 999 end
        ...
    end, function()
        C_Item.GetItemCount = GetItemCount
        ns.db.shoppingBags = false
        ns.Shopping:Clear()
    end)
end
```

`TailoringItems` should remember the item IDs it adds (or the old values)
and the test's restore should remove them, then `RB:Forget(inst)`.

### R2 · The rewritten branches aren't pinned by any test

- **Severity:** should fix
- **Area:** WoW API (smoke tests)
- **Where:** `tests/smoke/modules/UI-RecipeBand.lua:86-103` ("Alchemy, Enchanting and First Aid group by name"); `tests/smoke/modules/UI-Shopping.lua:208-267`
- **Status:** fixed in round 2 (uncommitted). New asserts cover Utility, Alchemy oils, Engineering fireworks and bombs, a made wand, Rods with and without an item, rank lines read from the data, and tooltip colours (`On alts` label, class colour, grey for an alt with no class).

**What's wrong.** The tests were written first and pass against both old and
new code (checked), but they skip most of what this change rewrote:

- `GROUP_BY_NAME.ENGINEERING` (Fireworks before Explosives) and the
  Engineering scheme: no Engineering assertion at all, though the test name
  lists the other three professions.
- `HasWord(name, "Oil")`, the one place word boundaries matter: no Oils
  assertion for Alchemy or Enchanting, and none that a name merely
  containing the letters is not an oil.
- First Aid's fall-through to Utility (old code stored `"UTILITY"` in the
  name table, new code returns `nil` and lets `of` default): untested.
- `ENCHANTING_ITEM_GROUPS`: an enchant (no item) whose name says Rod/Oil/Idol
  must land in Other; untested.
- `MarkRankLines` on the real data (`pairs` now replaces the ordered walk):
  the rank-line test builds `rankLine` by hand, so it never runs.
- Shopping's tooltip colours, the lines that changed (`TIP_LABEL`,
  `AddCountLine`, the class colour and the new `NO_CLASS_COLOR`): the
  tooltip test checks only the text.

**Why it matters.** The brief's "write the tests first" step is the proof
the behaviour stayed the same; for these branches the only proof right now
is my one-off harness. A later edit to `GROUP_BY_NAME` or `AddCountLine`
could regroup a profession's recipes or recolour the tooltip with every
test green.

**Evidence.** Read the scenarios (UI-RecipeBand.lua:86-103,
UI-Shopping.lua:249-267). My harness (Area notes) found old and new
identical, so this is about locking that in, not about a current bug.

**Fix.** Add a few asserts: `GroupOf("ENGINEERING", <a Rocket/Firework
recipe>) == "FIREWORKS"` and a bomb `== "EXPLOSIVES"` (with the product's
`W.itemFacts` cleared, so the name path decides); an Alchemy oil `== "OILS"`;
a First Aid recipe that isn't a bandage or potion `== "UTILITY"`; that
`ns.Data:Get("ALCHEMY")`'s "Minor Healing Potion" has `rank == "Minor"` and
a `rankLine` of 6; in the alts tooltip, the left colour of the `On alts`
line is 0.76, 0.93, 1 and an alt with `class = nil` (or an unknown token)
reads 0.8, 0.8, 0.8 (`GameTooltipTextLeft<n>:GetTextColor()`).

### R3 · `RAID_CLASS_COLORS` lost its nil guard

- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/UI/Shopping.lua:315`
- **Status:** fixed in round 2 (uncommitted): `local color = alt.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[alt.class] or NO_CLASS_COLOR`.

**What's wrong.**

```lua
-- before
local color = alt.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[alt.class]
-- after
local color = alt.class and RAID_CLASS_COLORS[alt.class] or NO_CLASS_COLOR
```

**Why it matters.** The brief allows cutting fallbacks for names Ketho's
`forever` lists show Forever doesn't have. `RAID_CLASS_COLORS` is a global
table, which none of the lists cover, so the lists can't say the guard is
dead; the reviewer rules accept such tables only when nil-guarded. If the
table were ever missing or replaced at login (a UI-replacement addon, a
client build), hovering any "To buy" row with alts would throw "attempt to
index global 'RAID_CLASS_COLORS'" and the tooltip would never finish. The
rest of the addon keeps the guard (`NeedRoll/UI/LootGrid.lua:2037`:
`local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]`), so this is
also an inconsistency.

**Evidence.** `grep RAID_CLASS_COLORS` in GlobalAPI.lua and FrameXML.lua
(`forever`): 0 hits each. In-game presence is by inference (standard
FrameXML table); the stand-in defines it (`tests/smoke/wow.lua:1054`).

**Fix.** Keep the new `NO_CLASS_COLOR` and the shorter line, with the guard
back:

```lua
local color = alt.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[alt.class] or NO_CLASS_COLOR
```

### R4 · `CountHoldings` also sets row heights, and "how many are left" is ambiguous

- **Severity:** should fix
- **Area:** Readability (single responsibility, disinformation)
- **Where:** `NeedRoll/UI/Shopping.lua:533-551` (the `total.height = TOTAL_ROW` at :542)
- **Status:** fixed in round 2 (uncommitted). `pane:Update` sets the height again (Shopping.lua:636), and the comment now says it "Returns how many materials (rows) still need buying".

**What's wrong.** The comment and name say the function counts what the
bags, bank and alts hold, but it also sets `total.height = TOTAL_ROW`, a
layout value that has nothing to do with holdings (the base code set it in
its own line in `pane:Update`). The comment ends "Returns how many are
left", which reads as a quantity of items; the function returns how many
*materials* (rows) still need buying, which is what the subtitle's "%d
materials to buy" shows.

**Why it matters.** A reader looking for where "To buy" rows get their
34px height won't look in a function called `CountHoldings`; someone
reusing it for a count of items gets a row count.

**Evidence.** Lines read; the base `pane:Update` had
`for _, t in ipairs(totals) do t.height = TOTAL_ROW end` separately.

**Fix.** Zero lines added either way: rename to say both jobs
(`FillTotals`, "Fills in each To buy row: its height, what the bags, bank
and alts hold, and with a subtract box ticked what is left to buy. Returns
how many materials still need buying."), or move the height line next to
the tree rows' `row.height = ...` in `pane:Update`.

### R5 · Engineering's comment gives the wrong order and doesn't parse

- **Severity:** should fix
- **Area:** Readability (comments, disinformation)
- **Where:** `NeedRoll/UI/RecipeBand.lua:210-212`
- **Status:** fixed in round 2 (uncommitted). The order is right now; R12 covers the wording.

**What's wrong.**

```lua
-- The client's Trade Goods subclasses first (7/2 explosives, 7/1
-- parts, 7/3 devices); Forever's own bombs it may not know by their
-- names; fireworks by name; then the slot, guns and ammo with Weapons.
of = function(enc)
    local itemID, classID, subclassID = ProductInfo(enc)
    if nameGroup[enc] == "FIREWORKS" then return "FIREWORKS" end   -- checked FIRST
    if classID == 7 and subclassID == 2 then return "EXPLOSIVES" end
```

The code checks Fireworks by name before the subclasses; the comment says
subclasses first and fireworks third. "Forever's own bombs it may not know
by their names" needs a second read to mean "then, by name, the bombs
Forever added that the client has no subclass for".

**Why it matters.** The order is the point of the comment: a firework the
client files under a Trade Goods subclass shows under Fireworks, not
Explosives/Parts. Old text, but the function was touched and READABLE-CODE
§5 says a wrong comment is fixed with the code.

**Fix.** "Fireworks by name first (the client files some under Trade
Goods); then the client's Trade Goods subclasses (7/2 explosives, 7/1
parts, 7/3 devices); then, by name, Forever's own bombs the client has no
subclass for; then head and trinket by slot, and guns and ammo with
Weapons." Same line count.

### R6 · Item class numbers repeated with no name

- **Severity:** should fix
- **Area:** Readability (searchable names, consistency)
- **Where:** `NeedRoll/UI/RecipeBand.lua:62` (`classID == 7`), `:186` (`classID == 2 and subclassID == 19`), `:216-218` (`classID == 7` ×3), `:220` (`classID == 6`)
- **Status:** fixed after round 2 (`TradeGoods.Parts/Explosives/Devices` with `ItemClass.Tradegoods`).

**What's wrong.** Trade Goods (7) appears five times, Weapon/Wand (2/19)
and Projectile (6) once each, as bare numbers with the meaning in a
comment.

**Why it matters.** READABLE-CODE §7: anything used in more than one place
gets a name you can grep. `grep Tradegoods` finds nothing today. The addon
already uses the game's names elsewhere
(`NeedRoll/UI/LootGrid.lua:109`: `classID == Enum.ItemClass.Armor`).

**Evidence.** Forever's `LuaEnum.lua`: `ItemClass` at :4642 with
`Projectile = 6` (:4649), `Tradegoods = 7` (:4650); `ItemWeaponSubclass`
at :5235 with `Wand = 19` (:5255). No enum exists for the Trade Goods
subclasses 1/2/3 (grep for Explosives/Parts in LuaEnum.lua: none), so those
stay numbers with the comment.

**Fix.** `Enum.ItemClass.Tradegoods`, `Enum.ItemClass.Weapon`,
`Enum.ItemClass.Projectile`, `Enum.ItemWeaponSubclass.Wand`; a
`local TRADE_GOODS = Enum.ItemClass.Tradegoods` if the lines get long. The
stand-in has `Enum.ItemClass` (`tests/smoke/wow.lua:1082`) but no
`ItemWeaponSubclass`; per the brief, define
`Enum.ItemWeaponSubclass = Enum.ItemWeaponSubclass or { Wand = 19 }` at the
top of `UI-RecipeBand.lua` (module files are executed before any scenario
runs, `tests/smoke/run.lua:150-153`) and list it in the hand-back for
wow.lua.

### R7 · Comments to trim

- **Severity:** nit
- **Area:** Readability (comments, less code)
- **Where:** `NeedRoll/UI/RecipeBand.lua:155`, `:162-165`, `:357`, `:379`, `:390-395`
- **Status:** fixed in round 2 (uncommitted). `Title`'s comment is down to two lines, the :155 comment is gone and the SCHEMES block is rewrapped. RecipeBand.lua is back to 818 lines.

**What's wrong.** RecipeBand.lua grew by 6 lines and all of it is comments
(109 to 121 comment lines; code went 669 to 658), against Mike's "reduce".
Places to win them back:

- `Title`'s comment (:390-395, six lines) describes what `SharedEnds` and
  `SharedAnywhere` do, and each helper has its own line saying the same
  (:357, :379). Keep the examples ("Boots" for Flame/Pearly Boots,
  "Skyforged") once, on the helpers, and leave `Title` with what only it
  does: "A set row's title, kept with the names it was made from (the names
  change once the game's own arrive); German compounds share no words, so
  they fall back to the first name."
- :155 `-- Enchanting's ranks fold the same way (Enchant Bracer - Agility ×6).`
  sits over a loop that marks both Alchemy and Enchanting, and "the same
  way" refers to nothing in this handler. Say "Alchemy's and Enchanting's
  rank lines (Minor ... Major Healing Potion, Enchant Bracer - Agility ×6)"
  or drop it; `MarkRankLines` already has the explanation.
- :162-165: the edited line runs to 88 columns while the rest of the block
  wraps at about 76; rewrap.

### R8 · Names

- **Severity:** nit
- **Area:** Readability (names, mental mapping)
- **Where:** `RecipeBand.lua:343, 453, 604, 199/259`; `Shopping.lua:377`
- **Status:** fixed in round 2 (uncommitted): `RowForSet`, `membersInList`, `fitCount`, and the hook uses `pane`. `noAllChip` left as is: it saves three lines, which the finding allowed.

- `SetRow(set, ...)` (:343) reads as the verb "set the row"; it returns the
  set's row, made once. `RowForSet` says so (local, free to rename).
- `inList` (:453) is a count per set (`inList[set] >= 2`) but reads as a
  yes/no; `membersInList`.
- `lastFit` (Shopping.lua:377) is a count of entries that fit, not the last
  one; `fitCount`.
- The `OnSizeChanged` hook names its pane `list` (:604) while every other
  line in the file calls it `pane`; `function(_, width) ... pane:SetData(pane.instance)`
  avoids the second name.
- `noAllChip` (:199) makes :259 a double negative,
  `elseif not (scheme and scheme.noAllChip)`. It saved three lines over
  `all = true`, so keeping it is fine; if kept, the comment at :163 is
  enough.

### R9 · A new table per tree row per redraw

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Shopping.lua:273`
- **Status:** fixed in round 2 (uncommitted): `row.itemButtons` is built in `CreateTreeRow` (Shopping.lua:200).

**What's wrong.** `for _, button in ipairs({ row.remove, row.plus, row.minus }) do ... end`
builds a three-entry table every time `SetupTreeRow` runs, which is every
row on every redraw and scroll step. The base code had three `SetShown`
lines and no table.

**Fix.** In `CreateTreeRow`, `row.itemButtons = { row.remove, row.plus, row.minus }`,
then `for _, button in ipairs(row.itemButtons) do button:SetShown(isAddedItem) end`.
(The table in `pane:Update` runs once per list change; fine as is.)

### R10 · Chip's edge still spells out GOLD by hand

- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** `NeedRoll/UI/RecipeBand.lua:504`
- **Status:** fixed in round 2 (uncommitted): `{ RGBA(GOLD, 0.38) }`.

`chip.fill, chip.edge = T:RoundedOn(chip, { 0, 0, 0, 0.35 }, { 1, 0.82, 0, 0.38 })`
is the one gold left as numbers after the change moved every other one in
`Chip` to `RGBA(GOLD, ...)` (the dot two lines below, the paint calls).
`{ RGBA(GOLD, 0.38) }` matches; `GOLD` and `RGBA` are declared above `Chip`
(:491-495).

### R11 · `tContains` joins the global-name list; new unused-`self` warning; test-file warnings

- **Severity:** nit
- **Area:** WoW API / checks
- **Where:** `RecipeBand.lua:384`, `:451`; `tests/smoke/modules/UI-RecipeBand.lua:77, :257` and the `fn = function(W, ns)` lines that don't use `W`
- **Status:** test-file warnings fixed in round 2 (0 left). `tContains`, the new `Enum` name and `RB:Fold`'s unused `self` (now :446) left as is. The first two are real Forever globals (GlobalAPI.lua:7045; `Enum` is the game's enum table, LuaEnum.lua). `RB:Fold` keeps its colon because `UI/Lists.lua:2279` calls it that way. The hand-back should name all three.

- The brief's W11 check says no file's global-name list may gain a name;
  RecipeBand's gains `tContains`. The aim of that check (catching a local
  read before it's declared) isn't hit: `tContains` is a Forever global
  (`GlobalAPI.lua:7045`) and the stand-in has it (`wow.lua:109`). State it
  in the hand-back so the merge reviewer doesn't take it for a bug.
- `RB:Fold` no longer uses `self` (it fed `self.memberOf`), so luacheck
  reports a new "unused argument self" at :451. The callers use the colon
  (`NeedRoll/UI/Lists.lua:2279`), and eight other `RB:` methods carry the
  same warning, so leaving it is defensible; say so.
- Test files: two lines over 120 and twelve unused `W` arguments; name the
  argument `_` where unused and wrap the two lines.

### R12 · Round-2 comments: long wraps, a fragment and a reason nobody checked; a bare 19 in the test

- **Severity:** nit
- **Area:** Readability (comments, consistency)
- **Where:** `NeedRoll/UI/RecipeBand.lua:50, 209-211, 356, 378`; `tests/smoke/modules/UI-RecipeBand.lua:157`
- **Status:** fixed after round 2, except the three long comment lines, kept to hold the group at its starting length.

**What's wrong.**

- The file wraps its comments at about 76 columns, but the round-2 comments
  run to 82-93 (:50 is 88, :209-211 are 82-84, :356 is 93, :378 is 90).
  They're within the 120-column limit, so this is only about the file
  looking consistent.
- :211 ends "head and trinket by slot, guns and ammo." without saying where
  guns and ammo go ("with Weapons", as the base comment had).
- :209 gives a reason, "(the client files some under Trade Goods)". That
  wording came from my round-1 suggested fix and I never checked it against
  item data. The checkable reason is in the code and the test: names come
  first, so anything with "Rocket" or "Firework" in its name goes to
  Fireworks, whatever the item is (see R13).
- The test writes `19` for the wand subclass (:157) one line after
  defining `Enum.ItemWeaponSubclass`.

**Fix.** Rewrap the four comments at about 76 columns. Write the
Engineering comment as something like: "Fireworks by name first (any
'Rocket' or 'Firework' recipe, whatever it makes), then the Trade Goods
subclasses (2 explosives, 1 parts, 3 devices), then Forever's own bombs by
name (no subclass), then head and trinket by slot; guns and ammo go to
Weapons." In the test, use `Enum.ItemWeaponSubclass.Wand`.

### R13 · The test pins "Goblin Rocket Helmet" under Fireworks as if that were wanted

- **Severity:** nit
- **Area:** Readability (smoke tests)
- **Where:** `tests/smoke/modules/UI-RecipeBand.lua:150-152`
- **Status:** left for Mike (behaviour unchanged from the base code).

**What's wrong.** `-- Fireworks by name before the bombs; a rocket helmet is a firework.`
followed by
`assert(GroupOf("ENGINEERING", "Goblin Rocket Helmet") == "FIREWORKS", ...)`.
The helmet is worn on the head, and Engineering has a Head chip. It sits
under Fireworks only because the name check runs before the slot check.

**Why it matters.** The behaviour is unchanged from the base code; my dump
shows the same group in both. But the test and its comment now present it
as something the band promises. A future fix that moves the helmet to Head
would look like a regression, and a reader would think it was chosen.

**Fix.** Ask Mike whether the helmet belongs under Head. If yes, fix it in
its own change. If it stays, say so plainly in the test comment ("Rocket
in a name wins over the slot, so the Goblin Rocket Helmet sits under
Fireworks") rather than "a rocket helmet is a firework".

## Area notes

### Readability

Checked every changed function in full against READABLE-CODE.md §1-9.
Sound: the spelled-out names (`chip`, `isPill`, `isAddedItem`,
`keepClearRight`, `iconBottom`, `rowsUsed`/`slot`, `lineCount`/`narrowest`/`widest`
in `Balance`, `wordLists`, `namesKey`); the splits each earn their names
(`ShowTreeTooltip` called directly removes the `row.showTooltip`
indirection; `ShowChips`/`ShowToggles` bring `RB:Layout` from about 70 to
about 30 lines; `SharedEnds`/`SharedAnywhere` replace an inline triple loop
with `tContains`); guard clauses replace nesting in `SetRow`, `SetLabel` and
the Enchanting scheme. `RGBA(color, alpha)` reads better than four indexed
arguments. The `Keeps` comment (enc.skill is { orange, yellow, green, grey })
is a good why-comment. 4-space indents, LF, no tabs, `local _, ns = ...` at
the top of both files. Lua 5.1 traps: `hasItems and <formatted string> or ""`
is safe (the middle is never nil/false); `GROUP_BY_NAME.ENCHANTING`'s
`... and "OILS" or nil` keeps `nil` rather than `false`, as before; `HasWord`
builds a pattern from `word`, but every caller passes the literal `"Oil"`,
so nothing from data reaches it.

### WoW API

Every name the change adds or now calls without a guard, checked against
Ketho's BlizzardInterfaceResources `forever` branch (downloaded today):

| Name | In `forever` lists | Where |
| --- | --- | --- |
| `C_Item.GetItemSubClassInfo` (now called directly at file load) | yes | GlobalAPI.lua:2546 |
| `GetItemSubClassInfo` (global, removed) | no, so removing the fallback is right | GlobalAPI.lua, FrameXML.lua: 0 hits |
| `C_Item.GetItemInfoInstant` (guard removed; 4th return `itemEquipLoc` now used) | yes | GlobalAPI.lua:2523 |
| `C_Item.GetItemNameByID` (wrapper removed) | yes | GlobalAPI.lua:2535 |
| `GetLocale` (guard removed) | yes | GlobalAPI.lua:5554 |
| `tContains` (new) | yes | GlobalAPI.lua:7045 |
| `wipe` | yes | GlobalAPI.lua:7080 |
| `CreateColor` (moved to `RB:Build`) | yes | FrameXML.lua:1173 |
| Texture `SetGradient` (moved, runs once) | yes | WidgetAPI.lua:264 |
| GameTooltip `AddDoubleLine`, `IsOwned`, `SetOwner` | yes | WidgetAPI.lua:1188, 1204, 1213 |
| GameTooltip `SetItemByID` (unchanged call, moved) | inferred: tooltip data mixin method, not in WidgetAPI's GameTooltip list | WidgetAPI.lua grep: no hit |
| `RAID_CLASS_COLORS` (guard removed) | not listable; accepted only with a guard | see R3 |
| `Enum.ItemClass.Tradegoods/Weapon/Projectile`, `Enum.ItemWeaponSubclass.Wand` (used since round 2) | yes | LuaEnum.lua:4642-4650, 5235-5255; the stand-in lacks `ItemWeaponSubclass`, which `UI-RecipeBand.lua` defines at its top (it runs before any scenario, `tests/smoke/run.lua:150-153`) |

Removing the guards on `ns.UI.RecipeProduct` (`UI/Lists.lua:524`) and
`ns.UI.SkillRank` (`UI/LootGrid.lua:359`) is safe: both are set
unconditionally at file load (not in `@debug@`) and only read at run time.
Removed public fields (`RB.memberOf`, `chip:Underline`, `chip:NoUnderline`,
`chip.number`, `row.showTooltip`): grep of the whole repo finds no other
user; `UI/Overview.lua:2591-2662` uses `RB.Chip`/`RB.PlaceLines` only
through `SetLabel`, `Paint` and `SetScript`, which are unchanged. No new
events, no frames touched in combat, no secure frames, no new globals set,
no upvalue-limit risk (`luac5.1 -p` clean). No `L[...]` key renamed or added.
UI unchanged, so `docs/STYLE-GUIDE.md` needs no update.

**Pixel identity**, by reading every visual line: tree geometry (`IconX`,
`LineX`, `ToggleX`, 6/24/20/14/5/8), name offset `x + size + 8`, keep-clear
72/10, check label offsets (-2, 1 native / -6, 0 modern, now one line),
chip sizes (`C_PAD * 2 + 1`, `F_PAD * 2`), chip colours (every `RGBA` call
expands to the same numbers), the dot texture path and 1, 0.82, 0, 0.5
tint, the rule's two gradients (same colours, set once at build instead of
every layout; the textures persist). The tests assert many of these
(UI-Shopping.lua:97-110, UI-RecipeBand.lua:214-230, 288-289).

**Grouping, old vs new.** I copied the worktree twice to a scratch folder
(one with `HEAD`'s RecipeBand.lua and Shopping.lua), added a dump scenario
that, after login and every other scenario, writes for every profession in
`ns.Data:List("PROFESSION")` (12 professions) each recipe's group from
`RB:Groups`, `enc.rank`, `enc.protection`, the size of `enc.rankLine`, the
chip keys, and every folded set row's key, `RB:Name` and `RB:Note`. It does
this four times: with the stand-in's item info; with `ns.UI.RecipeProduct`
returning nothing (every recipe goes the name path, as enchants do); with a
plain made item (class 0, no slot); and with a one-hand weapon (class 2,
`INVTYPE_WEAPON`). I ran both trees with `GetLocale()` returning `enUS` and
`deDE`. Old and new dumps are byte-identical in both locales (10,444 lines
each: 9,912 recipe lines, 484 set rows, 48 chip-key lines). So the
implementer's claim holds for the stand-in data; the one assumption is that
in-game `GetItemInfoInstant` answers fall into those four shapes, and the
`of` functions treat any other answer the same way old and new (read
line by line). The deDE runs also fail 28 unrelated scenarios that assert
English text; that's expected of the suite under deDE and is not caused by
this change.

Round 2, re-read in full: `ProductInfo`, `SlotOf`, the name-group helpers,
`GROUP_BY_NAME`, `MarkRankLines`, the ADDON_LOADED handler, all four
`SCHEMES`, `RowForSet`, `SharedEnds`, `SharedAnywhere`, `Title`, `RB:Fold`,
`Chip`, `RB:Build`, `Balance`, `PlaceLines`, `ShowChips`, `ShowToggles`,
`RB:Layout`, `RB:Paint`, and in Shopping.lua `CreateTreeRow`,
`SetupTreeRow`, `ShowTotalTooltip`, `CreateColumn`, `CountHoldings` and
`pane:Update`. `Balance` no longer returns early when there are no widths.
For an empty list it now returns `{ 1 }` instead of `{}`, but its only
caller, `PlaceLines`, already returns before calling it when there are no
chips, so nothing can reach that case; accepted. The test wrappers are read
in full too. They save before the test and restore after it, the restore
runs on failure (checked by forcing errors), and `W.itemFacts` goes back to
a copy of the old table. If it was `nil` before, it comes back as an empty
table; `wow.lua:1435-1451` treats the two the same.

### Redundant code

Compared against `NeedRoll/UI/Theme.lua`'s helpers (`T:Opaque`,
`T:SetTextColor`, `T:ChipUnderline`, `T:RoundedOn`, `T:Row`,
`T:ScrollStart`, `T:ScaledFont`, `T:LineWidth`) and `ns.Items:Load`:
`RGBA` has no Theme equivalent (`T:SetTextColor` takes a full colour, not a
colour plus alpha), `AddCountLine` and `CountHoldings` are new names for
code that was inline, not copies. Dead code removed: `ItemName`, `Line`,
`SubClass`, `RB.memberOf`, `Underline`/`NoUnderline`, `chip.number`,
`SetItem`'s unused return, the `order` list in `MarkRankLines`, the
double SharedEnds/SharedAnywhere work in `Title`. `RB:Paint`'s total now
comes from `Counts(instance).ALL`, which also counts each group; that's a
little extra work per paint (one pass over the profession's recipes, on a
click, with groups cached) for 3 fewer lines; fine.

Cross-module (not for this PR, per the brief): `CreateIcon`, `SetItem`,
`ModifiedClick`, `CreateColumn`, `CreateCheck`, `Plural` with
`UI/Wishlist.lua`; the tooltip label colour 0.76, 0.93, 1 (`TIP_LABEL`) is
also written by hand at `UI/MainFrame.lua:458, 499` and
`UI/LootGrid.lua:301, 314, 333, 445-446`, and the hint grey 0.5, 0.6, 0.65 at
`UI/LootGrid.lua:297, 303, 317` and `Shopping.lua:99`, so both belong on
`T.color` later.

### Security

Untrusted input touched: none. The change doesn't touch addon messages,
chat, drop sharing or `NeedRoll/Credits.txt`. The alt names shown in the
"To buy" tooltip come from the player's own SavedVariables
(`ns.db.characters`), unchanged by this diff. The test files use the
made-up character "Alt"; no real character names appear. No `loadstring`,
`RunScript` or `setfenv` in addon code; no scraper, tool or workflow
change.

## Round history

- 2026-10-17, round 1, `c0e5c79` + uncommitted: Changes needed. Opened R1
  (blocking), R2-R6 (should fix), R7-R11 (nits).
- 2026-10-18, round 2, `c0e5c79` + uncommitted: Changes needed (0 blocking,
  1 should fix, 2 nits open). Closed R1-R5, R7-R10. R11 left as is (accepted).
  R6 still open (three `GetItemSubClassInfo(7, n)` calls). Opened R12, R13.
  Grouping dump rerun: identical. Restores checked by forcing failures.
