# Review: Readability pass, UI group "small" (Reputation, MinimapButton, Welcome, Search, Settings) with per-module smoke tests

| | |
| --- | --- |
| Branch | `rp-ui-small` (worktree of the addon readability pass, `claude/addon-readability-pass-rg51s6`) into `dev` (PR number not known yet) |
| Commit reviewed | `0ba13c9` (`rp-ui-small`'s one commit on `c0e5c79`: round 2's changes plus the code-line follow-up, amended together; the follow-up reviewed as `git diff 6867b5d 0ba13c9 -- NeedRoll`) |
| Date | 2026-10-17; follow-up 2026-10-18 |
| Round | 2, plus a reviewed follow-up that trims code lines (see Follow-up review) |
| Verdict | **Ready** (0 blocking, 0 should fix, 3 nits open: R15-R17). R1-R11 fixed, R12 accepted, R13 and R14 fixed |
| Needs | `/reload` (Lua files only; no TOC, Bindings.xml or SavedVariables layout change) |

## What the change does

**Round 2.** The implementer fixed R1-R11 (still uncommitted). Beyond the
fixes, two things moved into the shared stand-in client
`tests/smoke/wow.lua`: a `W.Restoring(test, restore)` helper every module
test now uses, and a faction list stand-in (`W.factions`, with
`C_Reputation.GetNumFactions`/`GetFactionDataByIndex` reading it and new
`ExpandFactionHeader`/`CollapseFactionHeader`). That edit is R12. Line counts
after round 2: Reputation 116, MinimapButton 178, Welcome 235, Search 438,
Settings 799 (total 1766, +123 on `HEAD`); tests 829 lines; `wow.lua` +37/-2.
The round 1 text below describes the change as first reviewed.

**Round 1.**

Nothing a player sees is meant to change. Five UI files are rewritten for
readability under `docs/READABLE-CODE.md`: one-letter and vague names get
spelled out (`known`/`missed` become `metFactions`/`missedFactions`, `f`
becomes `notice`, `btn` becomes `button`, `seq` becomes `order`), long
functions are split into named pieces (the Settings key binding row, the
Settings page's scrolling, title and refresh, the minimap button's logo and
ring, the welcome bubble's skin and placement, Search's boss matching), magic
numbers get named constants, and copies become one helper (a tooltip helper
and note colour in Settings, `ColumnRow` for every Settings row,
`AddLabelAndNote` for setting and module rows, `PopupFill` and `Paragraph` in
Welcome, `SearchForm` for how Search compares text, `EachSource` replacing
Search's second walk over the loot, shared sort comparators). Fallbacks for
game functions older clients had are removed: the old global faction calls in
Reputation, the hand-built key chord in Settings, and `EnableMouse` in place
of `EnableMouseMotion`. Two behaviour deviations are declared: Search's
mid-search redraw check now ignores apostrophes as the search itself does, and
item names are warmed in tab order instead of `pairs()` order. A third,
undeclared one is harmless (R-notes under Redundant code: the quest
de-duplication key's separator went from a NUL byte to a space). Each file
gets a smoke test module in `tests/smoke/modules/UI-*.lua`.

Line counts (before -> after): Reputation 125 -> 116, MinimapButton 167 ->
177, Welcome 208 -> 235, Search 423 -> 440, Settings 720 -> 802. Total
1643 -> 1770 (+127), plus 741 lines of tests.

## Scope

- `NeedRoll/UI/Reputation.lua`: drops the `Rep = C_Reputation or {}` shim and
  the old-global fallbacks; scan split into `RecordVisibleFactions`,
  `ExpandCollapsedHeaders`, `RecordHiddenFactions`; constants for the pass
  cap, own-scan window and redraw delay; redraw pulled into
  `RedrawFactionPage`.
- `NeedRoll/UI/MinimapButton.lua`: `w`/`h` become `radiusX`/`radiusY`, new
  `SQUARE_CORNER_INSET`; logo and ring built in `AddLogoAndRing`;
  `OnDragUpdate` becomes `FollowCursor`; drag scripts use the captured
  `button` instead of `self`.
- `NeedRoll/UI/Welcome.lua`: `PopupFill`, `SkinBubble`, `PlaceBubble`,
  `Paragraph` helpers; layout constants for the notice; fields renamed
  (`bubble.sub` -> `hint`, `bob` -> `bounce`, `noticeWaits` ->
  `waitingForCombatEnd`), all file-local (grep of `NeedRoll/` and `tests/`).
- `NeedRoll/UI/Search.lua`: `SearchForm` for every text comparison; `EachLoot`
  removed in favour of `EachSource`; warming split (`ListWarmItemIDs`,
  `StopWarmTicker`, `PrepareWarmList`); comparators named; `AddMatchingBosses`,
  `AttunementSteps`, `ResultKey` pulled out; `Reset` reuses `Forget`.
- `NeedRoll/UI/Settings.lua`: the Settings button, key binding row, option
  and module rows, Discord dialog and page split into named file-local
  functions; `ShowTooltip`/`AddTooltipNote`/`AddHoverBox`; `ColumnRow` and
  `AddLabelAndNote` shared; constants for atlas names, alphas and gaps;
  `Chord` and the `EnableMouse` fallback removed.
- `tests/smoke/modules/UI-Reputation.lua`, `UI-MinimapButton.lua`,
  `UI-Welcome.lua`, `UI-Search.lua`, `UI-Settings.lua`: new, 4 to 9
  scenarios each (round 2: 31 scenarios in all, every one that changes
  shared state wrapped in `W.Restoring`; new Search and Welcome scenarios
  for R1 and R2).
- Round 2: `tests/smoke/wow.lua`: `W.Restoring` (`:83-90`), `W.factions`
  and a `C_Reputation` that reads it (`:1553-1584`). Round 2 also renamed
  Search's `PrepareWarmList` to `EnsureWarmList`, folded `SizeButtonIcon`
  into `SetButtonIcon` and removed `AddHoverBox` in Settings.
- Generated data: none touched. `NeedRoll/Locales/`: not touched; the set of
  `L["..."]` keys in the five files is identical before and after (diff of
  `grep -o 'L\["[^"]*"\]'` on `git show HEAD:` vs the working tree: no
  difference).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 5 changed Lua files and 5 test modules | passed (all 10) |
| `luacheck --no-global -q` before (`git show HEAD:`) vs after | 34 warnings -> 13; no new kind. Left: 7 over-long lines holding long `L["..."]` strings (`Settings.lua:66,75,83,97,212,622`, `Welcome.lua:180,181`) and 5 "unused `self`" on `ns.Search:`/`Settings:` methods (`Search.lua:137,161,420`, `Settings.lua:193,782`) |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | exit 0; lists strings some locale files still carry that the addon no longer uses (e.g. zhTW "Thom Filch"); none of them is a key these files used, so not caused by this change |
| `tests/smoke/check.sh` | passed in all three modes (dev 183 files, packaged 178, dev + secret values 183): "all passed" x3, every `UI/...` module scenario `ok` |
| Scraper unit tests | not run: no scraper change |
| Line endings / indent | LF only (no `\r` in any touched file), 4-space indents |
| **Round 2** `luac5.1 -p` (5 addon files, 5 test modules, `wow.lua`) | passed (all 11) |
| **Round 2** `luacheck --no-global -q` | 13 warnings, the same 13 as round 1 (long `L[...]` lines, unused `self` on methods); `wow.lua` warning list identical to `HEAD`'s |
| **Round 2** `luacheck --std lua51 -q --codes`, W11x global names per file, `HEAD` vs now | no file gains a name. Gone: Reputation `GetNumFactions`, `GetFactionInfo`, `GetFactionInfoByID`, `ExpandFactionHeader`, `CollapseFactionHeader`; Settings `IsAltKeyDown`, `IsShiftKeyDown`. MinimapButton 6 = 6, Welcome 6 = 6, Search 4 = 4; `wow.lua` no new names. Test modules set only the globals they restore (`GetMinimapShape`, `C_Texture.GetAtlasInfo`, `C_Item.GetItemNameByID`, `HelpTip.Show/Hide`) |
| **Round 2** `python3 tools/locales.py --check` / `tools/translations.py` | passed / exit 0 |
| **Round 2** `tests/smoke/check.sh` | passed in all three modes (dev 183, packaged 178, secret 183 files); 31 `UI/...` scenarios `ok` per mode |
| **Round 2** mutation check (scratch copy, not the worktree) | Put back the old `OnNameLoaded` test (`name:lower():find(query, 1, true)`) and wired "Turn off" to `Answer(true)`: "UI/Search: a tab turned on asks for new names; one arriving mid-search redraws once" and "UI/Welcome: Turn off stops drop sharing..." both FAIL, so the new tests pin the behaviour they claim |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Security | `tests/smoke/modules/UI-Welcome.lua:59-86` | The consent notice's "Turn off" answer (stop all sending) has no test | fixed in round 2 (uncommitted) |
| R2 | should fix | WoW API | `tests/smoke/modules/UI-Search.lua` (whole file); `NeedRoll/UI/Search.lua:50-56, 85-145` | The two declared Search deviations (mid-search redraw, warm order) and the warm/reset path have no test | fixed in round 2 (uncommitted) |
| R3 | should fix | Readability | `UI-MinimapButton.lua:37-49`, `UI-Reputation.lua:110-120`, `UI-Search.lua:141-146`, `UI-Settings.lua:93-97, 102-126`, `UI-Welcome.lua:9, 35, 55` | Tests restore stand-in overrides and saved settings only when they pass | fixed in round 2 (uncommitted) |
| R4 | should fix | Redundant code | `NeedRoll/UI/Welcome.lua:151, 210` | `PILL_HEIGHT = 20` copies Theme's private constant | fixed in round 2 (uncommitted) |
| R5 | nit | Redundant code | `NeedRoll/UI/Search.lua:55, 186-188` | `SearchForm(query)` is recomputed for every name compared | fixed in round 2 (uncommitted; the per-keystroke path) |
| R6 | nit | Readability | `NeedRoll/UI/Search.lua:111-145` | `PrepareWarmList` returns "made just now", a hop the two callers don't need | fixed in round 2 (uncommitted) |
| R7 | nit | Readability | `NeedRoll/UI/Settings.lua:645` | `function dialog.Present()` is called as `:Present()`; Wishlist writes `function box:Present()` | fixed in round 2 (uncommitted) |
| R8 | nit | Redundant code | `NeedRoll/UI/Settings.lua:134-138` | `AddHoverBox` saves no lines and its comment describes lighting it doesn't do | fixed in round 2 (uncommitted) |
| R9 | nit | Redundant code | `NeedRoll/UI/Settings.lua:156, 197, 719` | The gear atlas is looked up again on every build and bar resize, twice in `CreateButton` | fixed in round 2 (uncommitted) |
| R10 | nit | Readability | `NeedRoll/UI/Welcome.lua:83-100` | `PlaceBubble` also skins, fills and sizes the bubble | fixed in round 2 (uncommitted) |
| R11 | nit | Readability | `NeedRoll/UI/Settings.lua:306-307`; `NeedRoll/UI/MinimapButton.lua:66` | Two comments that no longer sit on, or describe, what they're above | fixed in round 2 (uncommitted) |
| R12 | should fix | Redundant code | `tests/smoke/wow.lua:83-90, 1553-1584` | The group edits the shared stand-in client the brief reserves, while other groups work in parallel | accepted: the shared helper merges first, in this PR |
| R13 | nit | Readability | `tests/smoke/modules/UI-Search.lua:155-202` | The Search scenario adds an item to Molten Core's real loot table | fixed after round 2, not re-reviewed (nits only) |
| R14 | nit | Readability | `tests/smoke/wow.lua:1553, 1572-1574`; `tests/smoke/modules/UI-Reputation.lua:8-11` | `W.factions` is documented inside `C_Reputation`, not where it's declared, and reset to `{}` rather than its prior value | fixed after round 2, not re-reviewed (nits only) |
| R15 | nit | Readability | `NeedRoll/UI/MinimapButton.lua:55-56` | The square-corner clamp now packs the diagonal, the inset and both clamps into one line each | open (follow-up) |
| R16 | nit | Readability | `NeedRoll/UI/Settings.lua:399-455` | `KeyRow` builds the row, defines its refresh and wires its input and events, 57 lines | open (follow-up) |
| R17 | nit | Readability | `NeedRoll/UI/Welcome.lua:197-199` | A bare `14` beside the named `NOTICE_GAP` and `CHECKBOX_SIZE` in the notice's height sum | open (follow-up) |

### R1 · The consent notice's "Turn off" answer has no test

- **Severity:** should fix
- **Area:** Security
- **Where:** `tests/smoke/modules/UI-Welcome.lua:59-86`; code under test `NeedRoll/UI/Welcome.lua:200-207` (`Answer` and the two buttons), `:215-221` (already-off skip)
- **Status:** fixed in round 2 (uncommitted). New scenario "UI/Welcome: Turn off stops drop sharing; already off in Settings, nothing is asked" (`UI-Welcome.lua:109-129`) clicks `notice.off` and checks `dropChannel == false`, `ChannelOn()` false, consent saved and the credit answer kept; a second block checks the already-off skip. Correction to round 1: `tests/smoke/scenarios.lua:844-857` ("drop sharing notice shows once") already clicked Turn off and asserted sharing stopped, which this review missed by grepping only the module file; the new module test still adds the already-off path and the kept credit answer. A mutation run (Turn off wired to `Answer(true)`) fails both.

**What's wrong.** The notice test clicks only "Keep sharing":

```lua
notice.credit:SetChecked(false)
notice.keep:Click("LeftButton")
```

Nothing clicks `notice.off`, so `Answer(false)` (`ns.Drops:SetChannel(false)`)
is never exercised by the module tests, and the early return for a player who
already turned sharing off in Settings (`if ns.db.dropChannel == false then
ns.db.shownDroptalkConsent = true return end`) isn't either.

**Why it matters.** This notice is the player's consent to drop sharing. The
change rewrote `Answer` (`on` -> `keepSharing`, `f` -> `notice`) and its
callers; if "Turn off" ever wired to `Answer(true)` or failed to save, a
player who said no would keep sending addon messages on the
`NeedRollDropSharing` channel, which is the one thing the "Share drops: Off"
promise forbids. The brief asks for tests that prove the refactor kept
behaviour; the security-relevant half is the one left out.

**Evidence.** Read the test file in full; `grep -n "off:Click\|notice.off" tests/smoke/modules/UI-Welcome.lua`
finds nothing. `scenarios.lua` was not checked for a notice "Turn off" case
by this review beyond that grep; the module test is where the brief puts it.

**Fix.** Add a scenario (restoring state in a `pcall` as R3 asks):

```lua
-- Turn off: saved, sharing stopped, credit answer kept.
ns.db.shownDroptalkConsent, ns.db.dropChannel = nil, nil
Welcome.notice:Hide()
Welcome:ShowDropNotice()
Welcome.notice.off:Click("LeftButton")
assert(ns.db.shownDroptalkConsent == true and not ns.Drops:ChannelOn(), "Turn off didn't stop sharing")
-- Already off in Settings: never shown, marked answered.
ns.db.shownDroptalkConsent, ns.db.dropChannel = nil, false
Welcome.notice:Hide()
Welcome:ShowDropNotice()
assert(not Welcome.notice:IsShown() and ns.db.shownDroptalkConsent == true, "...")
```

### R2 · The declared Search deviations and the warm/reset path have no test

- **Severity:** should fix
- **Area:** WoW API (smoke scenario for a behaviour change; async item names)
- **Where:** `tests/smoke/modules/UI-Search.lua`; `NeedRoll/UI/Search.lua:50-56` (`OnNameLoaded`), `:85-145` (`StartWarm`, `WarmBatch`, `Warm`), `:166-178` (`Reset`)
- **Status:** fixed in round 2 (uncommitted). New scenario `UI-Search.lua:155-202`: a tab turned off and on (so `Reset` asks for names), a search for "akumai", then an uncached item named "Aku'mai's Late Fang" arriving through `ITEM_DATA_LOAD_RESULT`; asserts exactly one redraw and that the item is then found on Molten Core. With the old `OnNameLoaded` check put back (scratch copy) it fails. Warm order is not asserted, which is fine: the order isn't visible. The PR text should still call the redraw change a fix.

**What's wrong.** Two behaviour changes are declared for Search, and neither
has a scenario:

1. `OnNameLoaded` now compares `itemSearchKeys[itemID]` (apostrophes dropped)
   with `SearchForm(query)`; before, it compared `name:lower()` (apostrophes
   kept) with the raw query.
2. Warming now lists item IDs through `EachSource` (tab order) instead of
   `pairs(ns.Data.instances)`.

The six Search scenarios all call `ns.Search:Find` on names already loaded;
none drives `Items:Load` callbacks, `StartWarm`'s ticker, `Warm` or `Reset`.

On (1), the hand-back's framing "results unchanged" is only true of `Find`.
What the player sees does change: before, while searching "akumai" with the
window open, an item named "Aku'mai's ..." arriving from the item cache did
not queue a redraw (`"aku'mai's ...":find("akumai")` is nil), so it appeared
only when some other matching name arrived or the player typed again. Now it
appears within `REFRESH_DELAY`. That is a bug fix and acceptable, but it
should be called a fix in the PR text and pinned by a test.

On (2): verified by reading that the set of IDs warmed is unchanged, only the
order. `ns.Data:Register` puts every instance in both `instances[id]` and
`byCategory[category]` (`Data/Data.lua:91-100`); joined instances replace
their parts in `byCategory` and map every part ID to the merged one in
`instances` (`Data/Data.lua:711-724`), which the old `inst.id == id` filter
reproduced; Skinning is added through `Register` (`:421-427`); all six
categories in use are in `ns.Data.CATEGORIES` (`Data/Data.lua:86`; a count
of `category = "..."` in `NeedRoll/Data` finds only those six). Tab order is
deterministic where `pairs()` wasn't, so the order change is acceptable.

**Why it matters.** Item names are async in Forever (`C_Item.GetItemNameByID`
returns nil until the cache has the item). The redraw path is exactly the
part a refactor can break silently: an item never showing until the next
keystroke, or a redraw storm. Neither shows in a test that only searches
loaded names.

**Evidence.** Read `UI-Search.lua` in full; `grep -n "Warm\|Reset\|OnNameLoaded\|Advance" tests/smoke/modules/UI-Search.lua` finds nothing.

**Fix.** One scenario that, with the window shown and `ns.UI.state.search =
"akumai"` (or a stand-in item whose name has an apostrophe), makes the
stand-in item cache answer a load, counts `ns.UI.Refresh` calls across
`W.Advance(1)` (restored in `pcall`), and asserts one redraw. A second that
calls `ns.Search:Reset()` after turning a tab on and asserts the tab's items
become findable. Say "fix" for (1) in the PR description.

### R3 · Tests restore overrides only on the passing path

- **Severity:** should fix
- **Area:** Readability (test hygiene; Mike's "no stand-in overrides left behind")
- **Where:**
  - `tests/smoke/modules/UI-MinimapButton.lua:37-49`: `GetMinimapShape = function() return "SQUARE" end` ... `GetMinimapShape = Shape`, with three `assert`s in between
  - `tests/smoke/modules/UI-Reputation.lua:110-120`: `UI.Refresh` replaced, `W.Advance(1)` in between, restored after
  - `tests/smoke/modules/UI-Search.lua:141-146`: `ns.Modules:Set("RAID", false)` then a `ResultsOf` call before turning it back on
  - `tests/smoke/modules/UI-Settings.lua:93-97` (WISHLIST off/on with an `assert` in between), `:102-126` (PROFESSION and every other tab off, asserts in between)
  - `tests/smoke/modules/UI-Welcome.lua:9, 35, 55`: `UI:SetSkin("native")` at the end assumes the skin was native before, rather than restoring `ns.db.skin`
- **Status:** fixed in round 2 (uncommitted). Every scenario that changes a stand-in, method or setting now goes through `W.Restoring` (`wow.lua:83-90` (`W.Restoring` at `:86`): `xpcall`, then restore, then `assert`), via `InSkin`/`WithNoticeUnanswered` (Welcome), `KeepingModules` (Settings, restores each module's `Chosen` value, turning on first so the last-tab rule can't block), `WithFactionList` (Reputation). The skin is saved from `ns.db.skin` and put back.

**What's wrong.** These scenarios change a global game stand-in, a shared
method or a saved setting, then `assert`, then put it back. A failed
`assert` raises before the restore line runs. Other scenarios in the same
files (`UI-Reputation.lua:51-65`, `UI-MinimapButton.lua:114-129`,
`UI-Settings.lua:141-166, 235-245`, all three Reputation scenarios with a fake list) already use the `pcall` / restore /
`assert(ok, err)` shape; these don't, so the files do the same thing two ways.

**Why it matters.** With one failure, later scenarios in the same run see a
square minimap, a counting `UI.Refresh`, the Raids or Wishlist tab off, or
every tab but Dungeons off, and fail for reasons unrelated to their own
code. The run is already red, but the report then shows a cascade instead of
the one real failure, which is the failure mode Mike asked the tests to
avoid. The `SetSkin` case is quieter: it leaves the account's skin at
"native" even if a future scenario ordering ran this module with "modern"
set.

**Evidence.** Lines read as quoted; the default skin is `"native"`
(`Core/Init.lua:21`) so the `SetSkin` case passes today.

**Fix.** Wrap each body in the `pcall` shape the files already use, restore
first, then `assert(ok, err)`. For the skin, save `ns.db.skin` at the start
and `UI:SetSkin(saved)` at the end.

### R4 · `PILL_HEIGHT = 20` copies Theme's private constant

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Welcome.lua:151` (`local PILL_HEIGHT = 20   -- T:Pill's height`), used at `:210`
- **Status:** fixed in round 2 (uncommitted): the constant is gone and the height uses `notice.off:GetHeight()` (`Welcome.lua:210`).

**What's wrong.** Theme already owns this number (`NeedRoll/UI/Theme.lua:559`
`local PILL_HEIGHT = 20`, applied at `:569` `pill:SetHeight(PILL_HEIGHT)`).
Welcome now has a second constant of the same name and value, whose comment
says it mirrors the first.

**Why it matters.** The notice's height is computed by hand from its parts.
If Theme's pills grow (a text-size option, a new style), the notice keeps
reserving 20 and its two buttons overlap the "Credit my finds" line or spill
out of the frame. Before the change the 20 was an unnamed literal; naming it
made the coupling easier to see but not removed. `READABLE-CODE.md` section 6
asks for one source of each fact.

**Evidence.** `grep -n PILL_HEIGHT NeedRoll/UI/*.lua`: Theme.lua:559, 569;
Welcome.lua:151, 210.

**Fix.** Read it from the button that exists by then, and drop the constant:

```lua
local height = pad + notice.title:GetStringHeight() + NOTICE_GAP + notice.body:GetStringHeight() + NOTICE_GAP
    + math.max(CHECKBOX_SIZE, notice.creditText:GetStringHeight()) + BUTTON_GAP + notice.off:GetHeight() + pad
```

### R5 · `SearchForm(query)` recomputed for every name compared

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Search.lua:186-188` (`Matches`), `:55` (`OnNameLoaded`)
- **Status:** fixed in round 2 (uncommitted): `Find` computes `queryKey` once (`Search.lua:419`) and every `Find*`/`Matches` takes it. `OnNameLoaded` (`:55`) still forms the query per arriving name, only while a search is open; accepted.

**What's wrong.** `Matches(name, query)` returns
`SearchForm(name):find(SearchForm(query), 1, true) ~= nil`, so one keystroke
lowercases and strips the same query once per instance, boss and quest name
compared (`FindPlaces`, `AddMatchingBosses`, `FindQuests`). `FindItems`
already does it right (`local queryKey = SearchForm(query)` at `:299`).
`OnNameLoaded` does it per item name arriving.

**Why it matters.** Not a correctness issue and the cost is small (string
work per boss and quest on each keystroke), but the file now has two ways of
preparing the query, and the shorter one is available.

**Fix.** Turn the query into its search form once in `ns.Search:Find` and
pass that to every `Find*`; `Matches(name, queryKey)` becomes
`SearchForm(name):find(queryKey, 1, true) ~= nil`. The result key keeps
`query` as its first element, as now.

### R6 · `PrepareWarmList` returns "made just now"

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/Search.lua:111-145`
- **Status:** fixed in round 2 (uncommitted): `EnsureWarmList` (`Search.lua:111-113`) with the guard back in `StartWarm`.

**What's wrong.** A six-line helper with a comment exists to return a
boolean that only `StartWarm` reads (`if not PrepareWarmList() then return end`);
`Warm` ignores it. The reader has to look up what `false` means.

**Why it matters.** Mike's goal is less code where clarity doesn't suffer;
this adds lines and a mental hop over the old two one-liners.

**Fix.** Keep the guard in `StartWarm` and make the helper a plain "ensure":

```lua
local function EnsureWarmList()
    if not warmItemIDs then warmItemIDs, nextWarmIndex = ListWarmItemIDs(), 1 end
end
local function StartWarm()
    if warmItemIDs then return end
    EnsureWarmList()
    ...
```

### R7 · `dialog.Present` defined with a dot, called with a colon

- **Severity:** nit
- **Area:** Readability (code consistency)
- **Where:** `NeedRoll/UI/Settings.lua:645` (`function dialog.Present()`), called at `:730` (`page.discordDialog:Present()`)
- **Status:** fixed in round 2 (uncommitted): `function dialog:Present()` with `self` (`Settings.lua:641-645`).

**What's wrong.** The method ignores the `self` its caller passes. The other
two dialogs in the addon write it as a method (`NeedRoll/UI/Wishlist.lua:456,
501` `function box:Present()`).

**Why it matters.** Two spellings of the same dialog idiom; a reader seeing
`dialog.Present()` expects a plain function and finds it called as a method.

**Fix.** `function dialog:Present() self.copied:SetText("") self:Open() SelectInvite() end`, as Wishlist does.

### R8 · `AddHoverBox` saves no lines and over-describes itself

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Settings.lua:134-138`, callers `:382` (key box) and `:657` (Discord button)
- **Status:** fixed in round 2 (uncommitted): helper removed; both call sites draw the box inline, the key box with `-- Unlit until hovered or listening (RefreshKeyRow).` (`Settings.lua:376-378`).

**What's wrong.** The helper is two calls (`T:Rounded(...)`, `frame.bg:Hide()`)
plus a three-line comment and a function header, used twice: five lines to
save two. Its comment says the box is "lit with the hover colour only while
hovered (or while it needs to stand out)", but the lighting is done by the
callers (`RefreshKeyRow` shows `box.bg` while capturing; the Discord
`OnEnter`/`OnLeave` show and hide it).

**Why it matters.** Small, but it's the kind of growth this pass is meant to
avoid, and the comment claims behaviour the function doesn't have.

**Fix.** Either inline the two lines at both callers, or let the helper own
the hover too (`HookScript("OnEnter"/"OnLeave")` showing and hiding `bg`
unless capturing) so the comment becomes true. At minimum reword to "Draws
the box, unlit; the caller lights it."

### R9 · The gear atlas is looked up repeatedly

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Settings.lua:156` (inside `SizeButtonIcon`, which runs on every `SetBarHeight`), `:197` (`CreateButton`, before calling `SizeButtonIcon`, which checks again), `:719` (`AddTitle`)
- **Status:** fixed in round 2 (uncommitted): `SetButtonIcon` (`Settings.lua:146-155` (function at `:148`)) picks atlas or fallback itself, so `CreateButton` asks once. It still asks on each bar resize; accepted (cheap, and the fallback is re-applied only on clients without the atlas).

**What's wrong.** Whether the client has `EditCrossbars-up-c60` can't change
during a session, yet `CreateButton` asks twice in a row and every top-bar
resize asks again.

**Why it matters.** Cheap call, so not a performance issue; the point is one
fact asked for in three places, which the old code also did with a repeated
string. With `SETTINGS_ATLAS` named, a single cached answer is the shorter form.

**Fix.** A small memo, e.g. `local function HasSettingsAtlas() if hasSettingsAtlas == nil then hasSettingsAtlas = C_Texture.GetAtlasInfo(SETTINGS_ATLAS) ~= nil end return hasSettingsAtlas end`,
used by the three sites; or let `SizeButtonIcon` pick the fallback itself so
`CreateButton` calls it once.

### R10 · `PlaceBubble` does more than place

- **Severity:** nit
- **Area:** Readability (single responsibility, avoid disinformation)
- **Where:** `NeedRoll/UI/Welcome.lua:83-100`
- **Status:** fixed in round 2 (uncommitted): `PlaceBubble` (`Welcome.lua:86-97`) now only parents, levels and anchors; `ShowCallout` calls it, then `SkinBubble`, then sets the width. Text colours moved into `SkinBubble`'s once-per-style block; checked equivalent (the colours depend only on the style, and the text is set once in `CreateBubble` to a constant).

**What's wrong.** `PlaceBubble` reparents, sets strata and level, calls
`SkinBubble`, sets the text, colours both lines, sizes the width, then
anchors the bubble and arrow. Its name says only the last part.

**Why it matters.** `READABLE-CODE.md` section 9: a name must not hide what
the function also does. Someone looking for where the callout's text is set
won't look inside "Place".

**Fix.** Move `SkinBubble(bubble)`, the text and colour lines back into
`ShowCallout` (they are four lines), leaving `PlaceBubble` with parenting,
width and anchors; or rename it `PrepareBubble`.

### R11 · Two comments that no longer sit on, or describe, their code

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/Settings.lua:306-307`; `NeedRoll/UI/MinimapButton.lua:66`
- **Status:** fixed in round 2 (uncommitted): `GREYED_ALPHA` above the comment with its own (`Settings.lua:299-301`); `FollowCursor`'s comment now says it saves the angle and moves the button (`MinimapButton.lua:66-67`).

**What's wrong.** In Settings the new constant was put between the function's
comment and the function:

```lua
-- Greys a switch out (a choice that can't be changed right now) or not.
local GREYED_ALPHA = 0.35
local function EnableSwitch(switch, enabled)
```

so the comment reads as the constant's. In MinimapButton,
`-- While dragging: the angle from the minimap's centre to the cursor.`
describes a value; `FollowCursor` saves that angle to
`NeedRollDB.minimap.angle` and moves the button.

**Fix.** Put `GREYED_ALPHA` above the comment (with its own `-- a greyed-out
switch's alpha`), and say "While dragging: saves the angle from the
minimap's center to the cursor and moves the button there." (The file
spells it "center" at `:15`.)

### R12 · The shared stand-in client is edited by this group

- **Severity:** should fix (or "left as is" if the coordinator approved it)
- **Area:** Redundant code (and process)
- **Where:** `tests/smoke/wow.lua:83-90` (`W.Restoring`), `:1553-1584` (`W.factions`, `VisibleFactions`, the reworked `C_Reputation`)
- **Status:** accepted by the coordinator (W.Restoring and the faction stand-in ship in this first module PR)

**What's wrong.** The brief's hard constraints say: "don't edit
`tests/smoke/scenarios.lua`, `tests/smoke/wow.lua`, `NeedRoll/UI/Theme.lua`
or any file outside your group. If a test needs a stand-in game function
wow.lua lacks, define it inside your module test file". Round 2 adds a
general helper and a reworked `C_Reputation` there.

**Why it matters.** Other groups are writing module tests in parallel worktrees
against the same file. Each is likely to want the same thing (a
restore-on-failure wrapper); if two of them add one to `wow.lua`, the merge
gives either a conflict at the same spot after `W.Call` or two helpers doing
one job, against `READABLE-CODE.md` section 6. The `C_Reputation` rework also
changes what `GetNumFactions`/`GetFactionDataByIndex` return for every
scenario (empty `W.factions` gives the same 0/nil as before, so today's
scenarios are unaffected; verified by the green `check.sh`).

The code itself is sound: `W.Restoring` uses `xpcall(test, debug.traceback)`,
always runs `restore`, then re-raises with the traceback; the faction
stand-in mirrors the game's list (a collapsed header hides rows up to the
next header) and implements exactly the five `C_Reputation` calls
`Reputation.lua` uses, all of which are in Forever's `GlobalAPI.lua`. This is
the right home for both, which is why it's not blocking.

**Evidence.** `git diff HEAD -- tests/smoke/wow.lua` (+37/-2); brief
`/home/claude/wt/notes/BRIEF.md` "Hard constraints". luacheck on `wow.lua`:
same warnings as `HEAD`, no new global names.

**Fix.** Coordinator's call. Either approve it and merge this group's
`wow.lua` first, telling the other groups to use `W.Restoring` and
`W.factions` rather than adding their own; or move both back into the test
modules (a local `Restoring` in each file, the faction fake inside
`UI-Reputation.lua` as in round 1) and list them under Cross-module for the
shared pass.

### R13 · The Search scenario adds an item to Molten Core's real loot table

- **Severity:** nit
- **Area:** Readability (test hygiene)
- **Where:** `tests/smoke/modules/UI-Search.lua:158-168, 195`
- **Status:** fixed after round 2

**What's wrong.** To get an item with an uncached name into the search
index, the scenario does `table.insert(encounter.loot, { itemID = LATE_ITEM })`
on the last encounter of `ns.Data:Get("MOLTEN_CORE")`, and removes it with
`table.remove(encounter.loot)` in the restore step. Anything else that builds
a cache from loot tables while the entry is there (the loot grid's row
caches if Molten Core is drawn, `ns.Data:ListedDrops`, Search's own
`itemNames`/`warmItemIDs`) keeps it after the restore; `ns.Search:Reset()`
cleans Search's index, but not the others.

**Why it matters.** Today nothing draws Molten Core during the scenario and
`ListedDrops` was already built at login, so the run is clean (`check.sh`
green in all three modes). It's a trap for a later scenario or a future cache,
inferred from reading the caches, not observed.

**Fix.** Either a comment naming the caches the restore doesn't cover, or
use an item already in the data with `W.uncached[itemID] = true` and an
overridden name, so no shipped table is changed.

### R14 · `W.factions` documented in the wrong place and reset to `{}`

- **Severity:** nit
- **Area:** Readability
- **Where:** `tests/smoke/wow.lua:1553` (`W.factions = {}`, no comment), `:1572-1574` (its description, inside the `C_Reputation` table above `GetNumFactions`); `tests/smoke/modules/UI-Reputation.lua:8-11` (restores `W.factions = {}`)
- **Status:** fixed after round 2

**What's wrong.** A reader finding `W.factions = {}` sees no description;
the shape (`{ factionID =, name =, isHeader =, isCollapsed = }`) is
explained 20 lines further down inside another table. `WithFactionList`
restores the empty default rather than whatever `W.factions` held before.

**Why it matters.** Small. A test author looking for the stand-in's
reputation list greps `W.factions` and lands on the bare line; and if a
scenario ever sets factions for a whole run, `WithFactionList` would quietly
wipe them.

**Fix.** Move the comment onto the `W.factions = {}` line; in
`WithFactionList`, `local saved = W.factions` and restore `saved`.

## Follow-up review

2026-10-18, `0ba13c9`. The implementer cut code lines to meet Mike's rule of
2026-10-18 (a file may be longer if it reads more easily, but code lines
must shrink). The commit was amended, so the follow-up's own diff is
`git diff 6867b5d 0ba13c9 -- NeedRoll` (6867b5d holds round 2's files):
4 files, 124 insertions, 184 deletions. Every changed function was re-read
in full, not only the hunk.

### Checks (follow-up)

| Check | Result |
| --- | --- |
| `luac5.1 -p` on `MinimapButton.lua`, `Search.lua`, `Settings.lua`, `Welcome.lua` | passed (all 4) |
| `luacheck --std lua51 -q --codes`, W11x global names per file, `git show c0e5c79:` vs `0ba13c9` | no new name in any file. MinimapButton 6 = 6, Search 4 = 4, Welcome 6 = 6, Settings 16 -> 14 (gone: `IsAltKeyDown`, `IsShiftKeyDown`, as in round 2). Identical to round 2's (`6867b5d`) lists |
| `luacheck --no-global -q` warning counts, base / round 2 / now | MinimapButton 4 / 1 / 1, Search 9 / 4 / 4, Settings 21 / 9 / 9, Welcome 3 / 3 / 3: no new warning |
| `python3 tools/locales.py --check` / `tools/translations.py` | passed / exit 0 |
| `tests/smoke/check.sh` | all passed in all three modes (dev 183, packaged 178, dev with secret values 183 files loaded) |
| Lines over 120 characters (READABLE-CODE section 2), excluding `L["..."]` lines | none in the four files; the longest new line is `MinimapButton.lua:55-56` (about 112) |

### Each fold, judged

**Behaviour.** Every fold checked by hand against `6867b5d`; all identical:

- MinimapButton `Place`: `1 + (x < 0 and 1 or 0) + (y > 0 and 2 or 0)`
  gives the same quarter as the two `if`s; the diagonal expressions are the
  old `diagonalX`/`diagonalY` substituted in place; `self.button` replaces a
  one-use local. `AddLogoAndRing`: `iconX` was 0 in both branches, so
  `SetPoint("CENTER", dx, iconY + dy)` is the same point.
- Search `FindQuests`: `ns.Data:Attunement(inst.id) or {}` then the same
  three-side list; a raid without attunement still yields three empty lists.
- Settings `SetButtonIcon`: the size is now set before the atlas or file
  instead of after. `SetAtlas(atlas)` without `useAtlasSize` doesn't resize,
  so the result is the same 16 x 16 icon (the smoke scenario "no gear atlas:
  the first fallback icon the client has, 16 square" passes). `return
  icon:SetAtlas(atlas)` is the file's existing idiom (`return
  SetCapturing(row, false)` in `OnCapturedKey`).
- `ShowModuleTooltip`: `#dependents > 0` replaces `table.concat(...) ~= ""`;
  the same unless every dependent's label were an empty string, which no
  module has.
- `KeyRow`: `row.Refresh` is a closure over `box` and ignores `self`; every
  caller is `row:Refresh()` on this same row (`SetCapturing`,
  `OnCapturedKey`, `OnKeyBoxClick`, `OnLeave`, `OnEvent`), so the same box.
  The `OnEvent` closure is the old `OnKeyRowEvent` with `row.box` captured.
- `RefreshModuleRow`: `whyGreyed` is a localized string (always truthy) when
  `isMissingRequirement or isLastOn`, else `nil`, so `EnableSwitch`, the
  note text and the note colour all follow the old branches; the
  missing-requirement case still wins over last-on, as before. The trailing
  `or nil` is harmless (not the `cond and nil or x` trap).
- `ScrollPageTo`: `maxOffset` computed once instead of twice; the canvas and
  scroll heights don't change in between.
- `CreatePage`: `page.general, page.modules, page.offset = {}, {}, 0` and
  `PAD + 44` are the same values.
- Welcome: `CreateBubble`'s locals became fields directly (same frames, same
  fields). `ShowCallout` runs the old `PlaceBubble` body in the same place,
  still before `SkinBubble` (the comment keeps the reason: the skin's border
  takes the bubble's frame level). `Paragraph` now colours its text with
  `T.color.text`; its only two callers (`notice.body`, `notice.creditText`,
  `Welcome.lua:168, 178`) both set exactly that colour before, and
  `SetTextColor` doesn't depend on being called after `SetText`.
  `HideCallout` reads `self.helpTip` directly. `14` is the old `BUTTON_GAP`.

**Readability.** Lengths after the folds: `KeyRow` 57 lines, `CreateNotice`
51, `FindQuests` 33, `AddModuleRow` 30, `ShowCallout` 26, `RefreshModuleRow`
15; all within a screen. No fold adds nesting: `FindQuests`' raid loop is
three `for`s deep, the same depth `AttunementSteps` had across two functions,
with a one-line innermost body. Folds judged sound:

- `SetFallbackIcon`, `Dependents`, `AddLabelTooltip`, `AddModuleIcon`,
  `MaxScroll`, `AttunementSteps`: each had one caller, and the folded block
  carries a one-line comment where the function name used to say what it
  did. `RefreshModuleRow` reads better with `whyGreyed` than with the
  repeated `isMissingRequirement or isLastOn`.
- `GREYED_ALPHA` (0.35) and `TITLE_HEIGHT` (44): single-use, and each
  number sits under a comment that says what it is ("Greys a switch out",
  "under the title, its subtitle and the gap below them"), which section 1
  allows ("a named constant with the unit in the name or a comment").
- `PlaceBubble` folded back into `ShowCallout`: this reverses the round 1 R10
  fix, but R10's complaint was a name (`PlaceBubble`) that hid skinning and
  sizing. With the helper gone the disinformation is gone too: `ShowCallout`
  places, skins, sizes and shows the callout, which its name covers, in 26
  lines with the placement block commented. R10 stays closed.

Three nits, below. None blocks; Mike can take or leave them.

### R15 · The square-corner clamp packs four steps into one line

- **Severity:** nit
- **Area:** Readability (sections 1 and 3)
- **Where:** `NeedRoll/UI/MinimapButton.lua:55-56`
- **Status:** open

**What's wrong.** The fold removed `diagonalX`/`diagonalY` and wrote:

```lua
x = math.max(-radiusX, math.min(x * (math.sqrt(2 * radiusX * radiusX) - SQUARE_CORNER_INSET), radiusX))
```

Each line now computes the diagonal radius, takes the inset off, scales the
direction and clamps to the edge, five calls and operators deep.

**Why it matters.** It still fits in 120 characters and the comment above
explains the geometry, so it is followable; but a reader has to unpack the
parentheses to find which part is "the diagonal" the comment names. The
old named locals were the comment's vocabulary in code. Two code lines
saved.

**Evidence.** `git diff 6867b5d 0ba13c9 -- NeedRoll/UI/MinimapButton.lua`.

**Fix.** Optional: keep one named local per axis and only drop the old
separate clamp lines, or accept as is (the comment carries the meaning).

### R16 · `KeyRow` is back to building, refreshing and wiring in one function

- **Severity:** nit
- **Area:** Readability (section 3, single responsibility)
- **Where:** `NeedRoll/UI/Settings.lua:399-455` (closure `row.Refresh` at `:416-429`, `OnEvent` at `:448-452`)
- **Status:** open

**What's wrong.** `CreateKeyRowFrames`, `RefreshKeyRow` and `OnKeyRowEvent`
were folded into `KeyRow`, which now builds the label and box, defines how
the box shows the key (a 14-line closure with an `if`/`elseif` chain),
sets four scripts and registers events: 57 lines, just under section 3's
"about 60". Its own comment lists the jobs ("the label ... the box ... with
its clicks, keys and tooltip wired up").

**Why it matters.** Section 3's example ("a function that builds a row,
fills it and also decides...") is this shape. Someone looking for why the
box reads "Not set" now has to find a closure in the middle of a builder.
The stated reason for the closure, keeping the order of `L[...]` keys,
is weak: `tools/locales.py` writes keys in source order, so moving
`RefreshKeyRow` above `KeyRow` only reorders three lines in the generated
`Locales/enUS.lua` (rerun the tool); no key changes.

**Evidence.** Function lengths measured with awk over the file; `tools/locales.py:33-45`
(keys appended in the order found).

**Fix.** Optional: put `local function RefreshKeyRow(row)` back above
`KeyRow` (`local box = row.box` plus the body) and `row.Refresh =
RefreshKeyRow`, then run `python3 tools/locales.py`. Two code lines more;
the frame building can stay folded.

### R17 · A bare `14` beside named gaps in the notice's height

- **Severity:** nit
- **Area:** Readability (sections 1 and 6)
- **Where:** `NeedRoll/UI/Welcome.lua:197-199`
- **Status:** open

**What's wrong.** `BUTTON_GAP` was inlined:

```lua
-- Its parts stacked, with 14 between the tick box's line and the buttons.
local height = pad + ... + NOTICE_GAP + ...
    + math.max(CHECKBOX_SIZE, notice.creditText:GetStringHeight()) + 14 + notice.off:GetHeight() + pad
```

**Why it matters.** The same sum uses `NOTICE_GAP` and `CHECKBOX_SIZE` from
the constants block at `:137-140`, where `BUTTON_GAP` sat with its comment;
now one gap of the four is a number and needs a comment to say which one.
Doing the same thing two ways in one expression is what section 6 asks
against. The comment does name it, so section 1 is met.

**Evidence.** `git diff 6867b5d 0ba13c9 -- NeedRoll/UI/Welcome.lua`.

**Fix.** Optional: restore `local BUTTON_GAP = 14 -- between the tick box's
line and the buttons` and drop the new comment (net zero code lines), or
accept as is.

## Area notes

### Readability

**Round 2.** Re-read every changed function in full: Welcome
(`SkinBubble`, `PlaceBubble`, `ShowCallout`, `CreateNotice`), Search
(`EnsureWarmList`, `StartWarm`, `Warm`, `Matches`, every `Find*`, `Find`),
Settings (`SetButtonIcon`, `SetButtonBarHeight`, `CreateButton`,
`EnableSwitch`, `CreateKeyRowFrames`, `CreateDiscordDialog`,
`CreateDiscordButton`), MinimapButton (`FollowCursor`), and the five test
modules. Names and comments now match what the code does; no narration. Line
change from round 1: Search -2, Settings -3, MinimapButton +1 (the longer
comment), Welcome 0. The test helpers (`InSkin`, `WithNoticeUnanswered`,
`KeepingModules`, `WithFactionList`) are each used two or more times and
read clearly. Open: R13, R14.

**Round 1.**

Checked every hunk against `docs/READABLE-CODE.md` and the brief.

- Names: all one-letter and vague locals in the five files are gone (`d`-style
  names: `f`, `btn`, `w`, `h`, `k`, `seq`, `att`, `have`, `need`, `last`,
  `on`). Renamed fields and functions are file-local: grep of `NeedRoll/` and
  `tests/` for `bubble.sub`, `.bob`, `noticeWaits`, `row.Capture`, `.Capture(`
  finds no outside user. Kept public names: `ns.UI.Reputation`,
  `ns.UI.PlayerStanding`, `ns.MinimapButton.{button,Place,Build,SetHidden,Toggle}`,
  `NeedRollMinimapButton`, `NeedRollDropNotice`, `button.icon/.border/.background`,
  `Welcome.{bubble,notice,helpTip}`, `ns.Search.{Warm,Reset,Forget,Find}`,
  `Settings.{OPTIONS,CreateButton,CreatePage}`, `settingsButton:{Tint,SetBarHeight}`,
  `page.{keyRow,general,modules,discord,discordDialog,offset,Refresh}`
  (callers: `MainFrame.lua:795, 936-947, 1179, 1187, 1530`; `scenarios.lua:2222`).
- Guard clauses: `NameOf`, `OnNameLoaded`, `SourceRank`, `RefreshOptionRow`,
  `StopWarmTicker` now return early. No function in the five files nests past
  three levels.
- Function length: the old `KeyRow` (~95 lines of closures), the old
  `CreatePage` with an inline `Refresh` (~110), `BuildGeneral` (~60) and
  `ShowCallout` (~40) are all split; the longest function now is
  `CreateNotice` (~55 lines).
- Growth, file by file, judged against "less code unless it costs clarity":
  - Reputation, -9: earned; the removed shims were dead on Forever.
  - MinimapButton, +10: `AddLogoAndRing` (+4 for header and return) and
    comments; earned by making `Build` read as a list of steps.
  - Search, +17: about 6 are the reflowed file header (one line was 160
    characters), the rest are named comparators (used 2-3 times each, a net
    saving), `SOURCE_RANK_*` and the moved `itemIndex`/`itemResults` comments.
    R5 and R6 would take back about 8.
  - Welcome, +27: `PopupFill` (2 uses) and `Paragraph` (2 uses) are small
    net savings; `SkinBubble`/`PlaceBubble` cost about 6 lines for headers;
    the four layout constants cost 4 and one of them is R4. R10 would not cost
    lines.
  - Settings, +82: mostly function headers and comments for the key-row and
    page splits, which are earned (the old closures were the hardest code in
    the group to follow). Not earned: `AddHoverBox` (R8), and the split of
    `CreateKeyRowFrames` from `KeyRow`, which is ~15 lines that are only
    ever called together; merging them would save the header, comment and
    `return` (~6 lines). Not raised as a finding since the split reads fine.
- Comments: plain, say why, no narration found (`grep -n "now\|Now\|refactor\|moved"`
  over the diff's added lines: the hits are "now" in game text such as
  `L["%s was bound to %s. It now toggles NeedRoll."]`, unchanged). The two
  misplaced/understated comments are R11.
- Lua 5.1 traps: no `cond and nil or x`; `#` used only on arrays built with
  `table.insert`; no patterns built from data (all `find` calls use plain
  `1, true`).
- Formatting: LF, 4 spaces; the long lines left are long `L["..."]` keys,
  which can't be split without changing the key.

### WoW API

**Round 2.** No new game call in the addon files. `wow.lua` now stands in
`C_Reputation.ExpandFactionHeader` and `C_Reputation.CollapseFactionHeader`
(both in Forever's `GlobalAPI.lua:3704, 3706`), so the stand-in mirrors
every call `Reputation.lua` makes, as the reviewer rules ask. The old global
faction stand-ins (`wow.lua:1382-1386`) stay because `Core/Names.lua:190`
still guards `GetFactionInfoByID` (Cross-module). Async names: the new
Search scenario exercises the real path (`ns.Items:Load` callback after
`ITEM_DATA_LOAD_RESULT`), not a poll. Global names: the luacheck W11x
comparison shows no file reading or setting a new global (see Checks).

**Round 1.**

Every game call the change newly calls directly (where it used to sit behind
a fallback) or newly keeps, checked against Ketho's
`BlizzardInterfaceResources` `forever` branch (`GlobalAPI.lua`,
`FrameXML.lua`, `WidgetAPI.lua`, `Events.lua`, `AtlasInfo.lua`, downloaded
2026-10-17 and grepped):

| Name | Kind | In `forever` lists | Where looked |
| --- | --- | --- | --- |
| `C_Reputation.GetNumFactions` | function | yes | GlobalAPI.lua:3712 |
| `C_Reputation.GetFactionDataByIndex` | function | yes | GlobalAPI.lua:3708 |
| `C_Reputation.GetFactionDataByID` | function | yes | GlobalAPI.lua:3707 |
| `C_Reputation.ExpandFactionHeader` | function | yes | GlobalAPI.lua:3706 |
| `C_Reputation.CollapseFactionHeader` | function | yes | GlobalAPI.lua:3704 |
| `GetNumFactions`, `GetFactionInfo`, `GetFactionInfoByID`, `ExpandFactionHeader`, `CollapseFactionHeader` (removed fallbacks) | globals | no (0 hits each) | GlobalAPI.lua: confirms the fallbacks were dead code on Forever |
| `CreateKeyChordStringUsingMetaKeyState` (replaces `Chord`) | FrameXML function | yes | FrameXML.lua:1197 (not in GlobalAPI; it's Blizzard Lua, loaded before addons) |
| `EnableMouseMotion` (replaces the `EnableMouse` fallback) | widget method | yes | WidgetAPI.lua:72, under `ScriptRegion` (so every Frame has it) |
| `C_Texture.GetAtlasInfo` | function | yes | GlobalAPI.lua |
| `C_Item.GetItemNameByID` | function | yes | GlobalAPI.lua |
| `GetCursorPosition`, `UnitFactionGroup`, `InCombatLockdown`, `UnitAffectingCombat`, `IsControlKeyDown`, `GetBindingKey`, `SetBinding`, `GetBindingAction`, `GetBindingText`, `SaveBindings`, `GetCurrentBindingSet`, `C_Timer.After/NewTimer/NewTicker` | functions | yes (all) | GlobalAPI.lua |
| `CreateColor` | FrameXML function | yes | FrameXML.lua:1173 |
| `GetMinimapShape` | addon-provided global | not listed (expected: minimap addons define it) | the code guards it: `GetMinimapShape and GetMinimapShape() or "ROUND"` (`MinimapButton.lua:48`) |
| `HelpTip` | FrameXML table | not listed as a function table (inferred: standard FrameXML) | guarded: `if not (HelpTip and HelpTip.Show and HelpTip.Point)` (`Welcome.lua:104`), unchanged |
| `UPDATE_FACTION`, `UPDATE_BINDINGS`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `GLOBAL_MOUSE_DOWN`, `PLAYER_LOGIN` | events | yes (all) | Events.lua |
| `SetPropagateKeyboardInput`, `EnableKeyboard`, `SetFixedFrameStrata`, `SetFixedFrameLevel`, `SetHighlightTexture`, `SetMaxLines`, `SetDesaturated`, `SetGradient`, `HookScript`, `RegisterForDrag`, `SetVerticalScroll` | widget methods | yes (all) | WidgetAPI.lua |
| `EditCrossbars-up-c60`, `UI-HUD-Minimap-Frame-Cycle`, `common-icon-checkmark`, `Crosshair_EngineerSkin_96`, `glues-characterSelect-icon-notify-inProgress-hover`, `QuestLog-icon-setting`, `GM-icon-settings`, `EditRadials-up-c60`, `Spellbook-up-c60` | atlases | yes (all) | AtlasInfo.lua |

The three fallback removals the brief asked about are sound: every modern
call exists in Forever and none of the old globals do. Other points:

- Async data: item names are still asked through `ns.Items:Load` with a
  callback and only read through `C_Item.GetItemNameByID`; no polling loop.
  Warming still spreads over `WARM_SPREAD` seconds with one ticker that is
  cancelled at the end (`StopWarmTicker`).
- Events: the key row registers `GLOBAL_MOUSE_DOWN` only while listening and
  unregisters it after (`SetCapturing`, `Settings.lua:410-418`), unchanged.
  Welcome's combat wait registers `PLAYER_REGEN_ENABLED` through `ns:On` and
  never removes it (`Welcome.lua:222-226`); pre-existing, and `ns:On` has no
  `Off` (`Core/Init.lua:87-93`), so listed under Cross-module rather than as
  a finding.
- Taint and combat: `Bind` still refuses in combat (`BlockedByCombat`,
  `Settings.lua:350-354`, same message, same check), and listening still ends
  on `PLAYER_REGEN_DISABLED`. Nothing touches secure frames.
- Secret values: none of the five files reads tooltip names, quest titles
  from the client in a comparison, or enemy spell IDs. Quest names in
  `FindQuests` come from `ns.Data:Quests` (the addon's data, or names
  `Core/Names.lua` already vetted), unchanged; inferred from the call sites.
- Upvalue limit: `luac5.1 -p` passes; the largest function here is far under 60.
- Globals: no new globals (luacheck before/after shows no new global writes;
  the two named frames are pre-existing).
- Locales: no key added, removed or reworded (L-key set identical).
- `tests/smoke/wow.lua`: the brief forbids editing it; the Reputation test
  defines `C_Reputation.ExpandFactionHeader`/`CollapseFactionHeader` inside
  its own fake list (`UI-Reputation.lua:31-32`) and restores the table
  afterwards. The base stand-in lacks those two (`wow.lua:1544-1551`) and
  still carries the old globals (`wow.lua:1382-1386`); see Cross-module.
- `docs/STYLE-GUIDE.md`: not updated, and doesn't need to be: every size,
  alpha, colour, atlas and offset is the same value as before (checked
  hunk by hunk: button 20 high, icon 20/16, alphas 0.72/0.35/0.5, underline
  0.35, Discord 26x22 with 18 icon, notice 460 wide, gaps 10/14, checkbox 24,
  pill 20, bubble inset 12, minimap ring 32/53, logo 25/20, corner inset 10).

### Redundant code

**Round 2.** R4, R5, R8, R9 closed. One helper, `W.Restoring`, now replaces
five near-identical `pcall` blocks across the test modules. Open: R12 (where
that helper lives).

**Round 1.**

Compared against: `T:Pill`, `T:Text`, `T:SetTextColor`, `T:Rounded`,
`T:Dialog`, `T:Input`, `T:LabelToggle`, `T:ChipUnderline`, `T:ScrollBar`,
`T:ScrollView`, `T:WheelScroll`, `T:Row`, `T:FitAtlas` (all `function T:`
in `Theme.lua`), `ns.Items:Load`, `ns.Data:List/Bosses/Quests/Attunement`,
`ns:On`.

- Real de-duplication in the change: Search's two walks over the loot
  (`EachLoot` and `EachSource`) are now one; the two "by name then instance"
  sorts are one comparator; `Reset` reuses `Forget`; Settings' four tooltip
  blocks share `ShowTooltip`/`AddTooltipNote`; every Settings row is built
  by `ColumnRow`; setting and module rows share `AddLabelAndNote`; Welcome's
  two popups share `PopupFill`.
- `ScrollPageTo`/`MaxScroll` were not replaced with `T:WheelScroll` or
  `T:ScrollView`: those build their own frames or offsets in line units,
  where the Settings page scrolls a pixel canvas; keeping them is right.
- Behaviour check on de-duplicated code: `Matches` now tests
  `SearchForm(name)` against `SearchForm(query)` where it used to try the raw
  forms first, then the apostrophe-free ones; any raw match is still a match
  after removing apostrophes from both, so the result sets are the same.
  `FindQuests`' de-duplication key changed its separator from a NUL byte
  (`inst.id .. "\0" .. quest.name` at old line 368, invisible in a diff) to a
  space; instance IDs contain no spaces (grep of `id = "..."` in
  `NeedRoll/Data`: all `[A-Z0-9_:]`), so no two keys can newly collide.
  Undeclared but harmless, and more readable.
- Dead code removed: the `Rep` shim, four fallback functions, `Chord`, the
  `EnableMouse` branch, `warmed` (replaced by `warmedAll`), Search's unused
  `local name` in `OnNameLoaded`. None left behind (luacheck reports no
  unused locals).
- Open items: R4, R5, R8, R9.

### Security

**Round 2.** The consent notice's Turn off path and the already-off skip are
now tested in the module file, alongside `scenarios.lua:844-857`; a mutation
that wires Turn off to keep sharing fails both. No new untrusted input or
output.

**Round 1.**

Untrusted inputs touched: none. These files don't read addon messages or
chat. Outputs: the consent notice's answers write `ns.db.dropCredit`,
`ns.db.shownDroptalkConsent` and call `ns.Drops:SetChannel(keepSharing)`
exactly as before (`Welcome.lua:200-205`; `Answer(true)` from "Keep sharing",
`Answer(false)` from "Turn off", read at `:206-207`). No character names or
credits are written anywhere new. The key row's `Bind` prints the game's own
binding names (`BINDING_NAME_*`, `GetBindingText`), not player text. Only
gap: the "Turn off" path isn't tested (R1).

### Cross-module (outside this group; not fixable here)

- `NeedRoll/Core/Names.lua:190` calls `GetFactionInfoByID`, which isn't in
  Forever's `GlobalAPI.lua` (guarded, so it is always nil there); the
  `C_Reputation.GetFactionDataByID` this group now uses directly is the
  replacement.
- `tests/smoke/wow.lua:1382-1386` still defines `GetNumFactions`,
  `ExpandFactionHeader`, `CollapseFactionHeader` (no addon file in this group
  calls them now), and its `C_Reputation` (`:1544-1551`) lacks
  `ExpandFactionHeader`/`CollapseFactionHeader`, which `Reputation.lua:43,
  65` now call directly. Add them to the stand-in in the shared pass.
- The tooltip "note" colour `0.76, 0.93, 1`: Settings' `AddTooltipNote`
  (`Settings.lua:120-122`) is one more copy of a value written literally
  about 25 times (`MainFrame.lua:458, 499`; `LootGrid.lua:301-610`;
  `Wishlist.lua:145, 826`; `Shopping.lua:170-326`) and named once as `TEXT`
  in `Core/Tooltip.lua:19`. A `T.color` entry or a `T:TooltipNote` would serve all.
- `NOT_BOSSES = { OVERVIEW, TRASH, SHARED }` exists in both
  `Search.lua:181` and `Data/Data.lua:89` (the latter is hand-written, not
  generated).
- `ns:On` (`Core/Init.lua:87`) has no way to remove a handler, so one-shot
  waits like Welcome's `PLAYER_REGEN_ENABLED` stay registered for the session.

## Round history

- 2026-10-17, `c0e5c79` + uncommitted, round 1: **Changes needed**
  (0 blocking, 4 should fix, 7 nits). Opened R1-R11.
- 2026-10-17, `c0e5c79` + uncommitted, round 2: **Changes needed**
  (0 blocking, 1 should fix, 2 nits open). Closed R1-R11; opened R12-R14.
- 2026-10-17, after round 2: R12 accepted by the coordinator; R13 and R14 (nits) fixed by the implementer; no third round for nits alone.
- 2026-10-18, follow-up: code lines (not blank, not comment), `c0e5c79` -> now: MinimapButton 128 -> 128, Reputation 95 -> 82, Search 328 -> 326, Settings 616 -> 613, Welcome 171 -> 171 (1338 -> 1320). Single-use helpers folded into their callers, single-use locals and constants dropped; no behaviour change; `check.sh` (all three modes) and `locales.py --check` pass.
- 2026-10-18, `0ba13c9`, follow-up review (`git diff 6867b5d 0ba13c9 -- NeedRoll`): **Ready** (0 blocking, 0 should fix, 3 nits). Behaviour identical; luac, luacheck W11 vs `c0e5c79`, `locales.py --check` and `check.sh` (three modes) pass. Opened R15-R17 (nits); R10's fold-back accepted.
