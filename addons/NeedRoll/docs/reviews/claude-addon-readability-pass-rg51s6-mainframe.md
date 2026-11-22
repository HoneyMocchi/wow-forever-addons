# Review: Readability pass, UI/MainFrame.lua group (plus its module smoke tests)

| | |
| --- | --- |
| Branch | `rp-mainframe` (worktree for the `claude/addon-readability-pass-rg51s6` group), into `dev` (PR not opened yet) |
| Commit reviewed | `c0e5c79` plus uncommitted changes (`NeedRoll/UI/MainFrame.lua` and `docs/STYLE-GUIDE.md` modified, `tests/smoke/modules/UI-MainFrame.lua` untracked); rounds 2 and 3 re-read the same worktree after the implementer's fixes |
| Date | 2026-10-18 |
| Round | 3 (final) |
| Verdict | **Ready** (0 blocking, 0 should fix, 0 open; R1–R20 fixed, R11 in part with a reason) |
| Needs | `/reload` (Lua only; no TOC, SavedVariables or binding changes) |

## What the change does

What players see stays the same. Inside `NeedRoll/UI/MainFrame.lua`,
`UI:Build` (about 210 lines) is split into `CreateMainWindow`,
`CreateHeader`, `CreateTopBar`, `CreateFooter`, `CreateLists`,
`CreateCrumbs` and `CreateContent`. `UI:Refresh` (about 180 lines) is split
into `RefreshStrip`, `ShowWholeBodyTab`, `ShowSearchResults`,
`ShowOverviewPage`, `ShowScarcePage`, `ShowRecipePage`, `LootSubtitle`,
`LabelBossTabs`, `ShowAbilitiesPage` and `ShowLootPage`. `UI:SelectCategory`
gains `LayoutLists` and `InstanceToOpen`. Code that was repeated now goes
through small helpers: `CountText`, `SetSearchKeys`, `SetTextQuietly`,
`HideTooltip`, `AddStroke`/`TintStrokes`, `PlaceBack`, `CreateWholeBodyHost`,
`BuildWholeBodyTab`, `IsWithin`, `OverviewOf`, `OpenMapAt`,
`StripButtonsWidth` and `OnListChange`. Two tables now name the tab sets the
code tested by hand: `INSTANCE_TABS` and `LOOT_FILTER_TABS`.

Fallbacks for old clients are removed: `GetMouseFocus`,
`SetMinResize`/`SetMaxResize`, and the guards on `C_Spell.DoesSpellExist`,
`ToggleWorldMap` and `SetMouseMotionEnabled`. So are the export
`ns.UI.GoodWindowPoint`, the methods `UI:BuildShopping`, `UI:BuildWishlist`
and `UI:CreateLink`, and three `ClearRecipeFilter()` calls. Cryptic locals
are renamed (`f`→`window`, `k`→`growth`, `here`→`lastFloorKey`,
`l,b,w,h,s`→`left,bottom,width,height,scale`, and others).

A new module test file adds 18 smoke tests. Each restores what it changes
through a `Restoring` helper. At integration that helper became the shared `W.Restoring`
from `tests/smoke/wow.lua` (#596).

Size: round 1 was 2458 → 2517 lines (code 1922 → 1925, comments 372 → 408,
blanks 164 → 184, counted with `grep '^\s*--'` / `'^\s*$'`). Round 2 is
2457 lines (code 1903, comments 389, blanks 165), one line under the base
and 19 code lines under it.

Round 2 also fixes two bugs that predate the pass, each with a test. Both
change behaviour on purpose: the modern window plays its open sound again
(R1), and the breadcrumb works after switching style and back (R2).
`docs/STYLE-GUIDE.md:43` names `IsUsableWindowPoint` (R9). The module test
file now holds 20 tests.

Round 3 is 2458 lines, the same as the base: code 1897 (base 1922),
comments 396 (base 372), blanks 165 (base 164). So the file has 25 fewer
code lines than the base, and the space went to comments for newcomers.

## Scope

- `NeedRoll/UI/MainFrame.lua`: every hunk of `git diff HEAD` (2401 diff
  lines) read. I also read the whole current file from line 96 to the end,
  around and between the hunks. Lines 1–95 were read in the header read.
- `tests/smoke/modules/UI-MainFrame.lua` (new, 548 lines): read in full.
- Read for context, not changed: `NeedRoll/UI/Theme.lua` (`T.size`,
  `T:LabelToggle`), `NeedRoll/UI/Settings.lua:120-160` (`SetBarHeight`),
  `NeedRoll/API.lua:128-135` (`Open`), `tests/smoke/wow.lua`
  (`SetScript`/`HookScript` stand-ins, `SearchBoxTemplate`,
  `GetMouseFoci`), `tests/smoke/run.lua` (how module tests load),
  `docs/STYLE-GUIDE.md`.
- Round 2: the whole round 1 → round 2 diff of `MainFrame.lua` (908 lines,
  rebuilt by applying the round-1 diff to the base) read hunk by hunk. Every
  function it touched was re-read in full: `SizeTopBar`, `AddNativeTitle`,
  `CreateMainWindow`, `CreateHeader`, `CreateTabBar`, `CreateTopBar`,
  `CreateFooter`, `UI:Build`, `ShowLootPage`, `UI:Refresh`,
  `UI:UpdateBossTabs`, `GoToResult`, the secure-link block. Also read: the
  test file in full again, `docs/STYLE-GUIDE.md` diff, `tools/locales.py`
  (R11's reason), `tests/smoke/wow.lua:841-856`, `:1563`.
- Round 3: the round 2 → round 3 diff of `MainFrame.lua` (194 lines) read
  in full, and every function it touched re-read: `AbilityEntries`,
  `LabelBossTabs`, `ShowAbilitiesPage`, `ShowLootPage`, `RefreshStrip`,
  `UI:FitStrip`, `UI:UpdateCrumbs`, `ShowWholeBodyTab`, `UI:UpdateLink`,
  `UI:GoBack`, `CreateFactionToggle`, `AddNativeTitle`. The test file has
  not changed since round 2.
- Generated data: none touched.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on both files | passed |
| `luacheck --no-global -q`, base vs new `MainFrame.lua` | 16 → 5 warnings. The 5 left are 2 long lines (341, 344, pre-existing in `CreateSearchNote`) and 3 unused `self` (727, 2364, 2395, pre-existing). None new. |
| `luacheck --no-global -q` on the new test file | 13 warnings, all `unused argument 'W'` (new file, see R14) |
| `luacheck --std lua51` W11x global names, base vs new | 30 → 29 names. Only `GetMouseFocus` is gone. No name added. |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | ran (exit 0). Its notes on unused zhTW keys are unrelated. |
| `tests/smoke/check.sh` | all three runs (dev, packaged, secret values) "all passed", including the 18 `UI/MainFrame:` tests |
| New tests against the **base** `MainFrame.lua` (copy in the scratchpad) | all passed in all three runs, so the tests show behaviour stayed the same |
| Probe test (scratchpad copy only, not committed) | confirmed R2: after a style switch and back, `UI.crumbs` sits in the other window, on both base and new code |
| **Round 2** `luac5.1 -p` on both files | passed |
| **Round 2** `luacheck --no-global -q`, `MainFrame.lua` and the test file | 5 warnings, all pre-existing: long lines at `:338`, `:341` (literal `L[...]` keys) and unused `self` at `:700`, `:2305`, `:2335`. Test file: 0 (the 13 from round 1 are gone). |
| **Round 2** `luacheck --std lua51` W11x, base vs new | 30 → 29. Only `GetMouseFocus` is gone. No name added. The test file reads `PlaySound` (overridden and restored), `SOUNDKIT`, `UIParent`, `WorldFrame`, `wipe`. |
| **Round 2** `python3 tools/locales.py --check` | passed (exit 0) |
| **Round 2** `python3 tools/translations.py` | ran (exit 0) |
| **Round 2** `tests/smoke/check.sh` | all three runs "all passed", 60 `UI/MainFrame:` lines (20 tests × 3 runs) |
| **Round 2** new test file against the **base** `MainFrame.lua` (scratchpad copy) | 2 failed, exactly the two bug tests: "opening and closing make the game's sounds in both styles" (`:466`, the R1 check) and "a style switch keeps the selection and the search text" (the R2 check). Every other test passed, so nothing else changed behaviour. |
| **Round 3** `luac5.1 -p` on both files | passed |
| **Round 3** `luacheck --no-global -q`, both files | 5 warnings in `MainFrame.lua`, all from before the pass (`:339`, `:342` literal `L[...]` lines; unused `self` at `:702`, `:2306`, `:2336`). Test file 0. |
| **Round 3** `luacheck --std lua51` W11x, base vs new | 30 → 29. Only `GetMouseFocus` is gone. No name added. |
| **Round 3** `python3 tools/locales.py --check` | passed (exit 0): the moved `L[...]` keys kept their order |
| **Round 3** `python3 tools/translations.py` | ran (exit 0) |
| **Round 3** `tests/smoke/check.sh` | all three runs "all passed" (60 `UI/MainFrame:` lines) |
| **Round 3** test file against the **base** `MainFrame.lua` | the same 2 fails as round 2 (the R1 and R2 bug tests), everything else passes |
| **Round 3** probe for `abilities.count` (scratchpad copy only) | Opened every dungeon boss with known abilities: 218 encounters, 2 of them with boss headings. Compared `abilities.count` with the old loop that counted entries with `.ability`, and with the status line and the Abilities pill text. 0 mismatches in all three runs. |
| Scraper unittests | not run (no scraper change) |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | WoW API | `MainFrame.lua:1113`, `:1115` (with `:901`) | `SetScript("OnShow")` erases the window's open-sound hook in the modern style | fixed in round 2 |
| R2 | should fix | Redundant code | `MainFrame.lua:1318-1323` | `crumbs` isn't parked by the style switch, so the breadcrumb goes to the hidden window | fixed in round 2 |
| R3 | should fix | Redundant code | `MainFrame.lua:896`, `:906`, `:912` | Three `OnHide` hooks on one window where one would do | fixed in round 2 |
| R4 | should fix | Redundant code | `MainFrame.lua:699-701`, `:938-941` | Native title placed twice, and two of its fields are never read | fixed in round 2 |
| R5 | should fix | Redundant code | `MainFrame.lua:280`, `:774-806`, `:170` | Dead guards left in while the same pass removed others | fixed in round 2 |
| R6 | should fix | Readability | `MainFrame.lua:1894-1925`, `:2043`, `:1993`, `:2006` | `RefreshStrip` also returns the boss's abilities, threaded through three functions | fixed in round 2 |
| R7 | should fix | Readability | `MainFrame.lua:704`, `:884`, `:957-979`, `:1081-1098` | `Build` helpers read hidden state; `CreateWindow` vs `CreateMainWindow` | fixed in round 2 |
| R8 | should fix | Readability | `MainFrame.lua:991`, `:998`, `:1296`, `:1306-1310`; `:1068`, `:1070`, `:1072`, `:1172`, `:2146-2156` | Footer and strip spacing are bare numbers that other code must match | fixed in round 2 |
| R9 | should fix | Readability | `docs/STYLE-GUIDE.md:43` | Style guide still points to `GoodPoint`, renamed to `IsUsableWindowPoint` | fixed in round 2 |
| R10 | should fix | Readability | whole file | The file grew by 59 lines; Mike's goal is less code | fixed in round 2 |
| R11 | nit | Readability | `MainFrame.lua:852`, `:1946`, `:1982` | Thin single-use wrappers that add lines | left as is in part (reason in R11) |
| R12 | nit | Readability | `:122`, `:127`, `:2244`, `:2127`, `:1469`, `:960`, `:746` | Short or misleading names still in touched code | fixed in round 2 |
| R13 | nit | Readability | `:2220-2227`, `:1623-1633` | `self.` and `UI.` mixed inside one method | fixed in round 2 |
| R14 | nit | Readability | `tests/smoke/modules/UI-MainFrame.lua` | Test file: 13 new luacheck warnings, `f`, and two paths not covered | fixed in round 2 |
| R15 | nit | Redundant code | `MainFrame.lua:1781-1790` | `GoToResult` repeats `GoToSource(result.inst)` in two branches | fixed in round 2 |
| R16 | nit | Readability | `MainFrame.lua:2424-2435` | The secure-link comment block is split across `links` and `GameMapLink` | fixed in round 2 |
| R17 | should fix | Readability | `MainFrame.lua:1937-1983` | `ShowLootPage` now draws two pages, nested four deep | fixed in round 3 |
| R18 | nit | Readability | `MainFrame.lua:2124`, `:1126`, `:1669` | Round 2 deleted comments that held facts the names don't | fixed in round 3 |
| R19 | nit | Redundant code | `MainFrame.lua:673-676` | `AddNativeTitle` keeps a fallback for a title bar Forever's template has | fixed in round 3 (comment) |
| R20 | nit | Readability | `MainFrame.lua:1419-1420` | The `-- Selection ---` banner now reads as `LayoutLists`' first comment line | fixed after round 3 (blank line back; file 2459, code 25 under base) |

### R1 · `SetScript("OnShow")` erases the window's open-sound hook in the modern style
- **Severity:** should fix (pre-existing; this pass moved the code but didn't cause it)
- **Area:** WoW API
- **Where:** `NeedRoll/UI/MainFrame.lua:1113` `window:SetScript("OnShow", Relink)` and `:1115` `window:SetScript("OnSizeChanged", Relink)`, after `:901` `window:HookScript("OnShow", ...)` in `CreateMainWindow`
- **Status:** fixed in round 2 (uncommitted): `window:HookScript("OnShow", Relink)` / `HookScript("OnSizeChanged", Relink)` (`:1086`, `:1088`), with a comment at `:875` and a test

**What's wrong.** `CreateMainWindow` hooks `OnShow` to play
`SOUNDKIT.IG_SPELLBOOK_OPEN`. Later in the same build, the modern style runs
`window:SetScript("OnShow", Relink)` on the same plain frame.

**Why it matters.** warcraft.wiki.gg (`API_ScriptRegion_HookScript`) says:
"If the script type doesn't have an existing handler, this will be
equivalent to SetScript", and "Any hooks applied will remain in place until
replaced or cleared with SetScript." The modern `NeedRollFrame` has no
`OnShow` handler, so the sound hook becomes the handler, and `SetScript`
then replaces it. In the game, the modern window opens without a sound. The
native style (the default, `Core/Init.lua:21`) never calls `SetScript` there,
so it plays the sound. The comment at `:897-900` promises a sound for both
styles.

**Evidence.** Read `:884-914` and `:1109-1116`. The base file has the same
order (`f:SetScript("OnShow", Relink)` at base `:1055`), so this predates the
pass. The smoke stand-in keeps hooks after `SetScript`
(`tests/smoke/wow.lua:510-524` stores `_scripts` and `_hooks` separately),
and the sound test runs only in the default native style. That is why
"opening and closing make the game's sounds" passes. That the game drops
the hook is my inference from the wiki text quoted above.

**Fix.** Use `window:HookScript("OnShow", Relink)` and
`window:HookScript("OnSizeChanged", Relink)`. Add a module test that switches
to modern and checks for the open sound. Under "Cross-module", say that
`wow.lua`'s `SetScript` should clear hooks the way the game does.

### R2 · `crumbs` isn't parked by the style switch, so the breadcrumb goes to the hidden window
- **Severity:** should fix (pre-existing)
- **Area:** Redundant code (state kept in two places that don't agree)
- **Where:** `NeedRoll/UI/MainFrame.lua:1318-1323` (`SKINNED`); `UI.crumbs` is set in `CreateContent` (`:1066`)
- **Status:** fixed in round 2 (uncommitted): `"crumbs"` added to `SKINNED` (`:1288`), with a test

**What's wrong.** `SetSkin` parks and restores every widget named in
`SKINNED`. `crumbs` is built per window, like `back` and `mapButton`, but it
isn't in the list.

**Why it matters.** A player opens the native window, switches to modern
(this builds the modern window and sets `UI.crumbs` to modern's), then
switches back to native. `UI.crumbs` still belongs to the parked modern
window. On a boss or quest page, `UI:UpdateCrumbs` fills and shows a
breadcrumb nobody can see, and anchors it to the native window's Back
across windows. The native window shows no "Shadowfang Keep > Baron
Silverlaine" until `/reload`.

**Evidence.** I added a probe test in a scratchpad copy of the tree. It
switches style and back, then walks `UI.crumbs`'s parents looking for
`UI.frame`. It printed `PROBE crumbs inside current window: false` on both
the base and the new file.

**Fix.** Add `"crumbs"` to `SKINNED`, and extend the module test "a style
switch keeps the selection and the search text" to check that
`ui.crumbs` is inside `ui.frame` after switching back.

### R3 · Three `OnHide` hooks on one window where one would do
- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/MainFrame.lua:896`, `:906-910`, `:912`
- **Status:** fixed in round 2 (uncommitted): one `OnHide` hook (`:883-890`)

**What's wrong.** `CreateMainWindow` hooks `OnHide` three separate times:
to cancel a pending search, to play the close sound, and to close Settings.
Each has its own comment.

**Why it matters.** It is more code than needed. A reader also has to
notice that the order of three separate hooks matters, and a fourth
`SetScript("OnHide")` anywhere would silently remove all three (see R1).

**Evidence.** Read `:884-914`.

**Fix.** Use one hook. It runs the same steps in the same order, and none
of them returns early past the others:

```lua
-- However the window closes (Escape, the X, /nr): search work stops with it,
-- Settings gives way to the tabs for next time, and the game's close sound
-- plays unless a style switch or Alt+Z hid it.
window:HookScript("OnHide", function(self)
    UI:CancelPendingSearch()
    if not UI.swapping and not self:IsShown() and UI.soundOpen then
        UI.soundOpen = false
        PlaySound(SOUNDKIT.UI_PROFESSIONS_WINDOW_CLOSE)
    end
    if UI.settingsOpen then UI:CloseSettings() end
end)
```

### R4 · Native title placed twice, and two of its fields are never read
- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/MainFrame.lua:699` and `:701` (`AddNativeTitle`), `:938-941` (`CreateHeader`)
- **Status:** fixed in round 2 (uncommitted): `AddNativeTitle` anchors once with `NATIVE_HEADER_HEIGHT` (`:669`, `:689`); the unread fields are gone

**What's wrong.** `AddNativeTitle` anchors the holder with
`holder:SetPoint("CENTER", templateTitle, "CENTER", 0, 0)`. Then
`CreateHeader` always runs `titleHolder:ClearAllPoints()` and re-anchors it
to `window, "TOP", 0, -header:GetHeight() / 2 - 1`. So the first anchor is
never used. `AddNativeTitle` also stores `window.titleIcon` and
`window.titleName`, which nothing reads.

**Why it matters.** Splitting the old `Build` put these two placements in
separate functions. A reader of `AddNativeTitle` now believes its comment
("centred where the template's title sat"), but the title is actually
placed in another function.

**Evidence.** `grep -rn "titleIcon\|titleName\|titleHolder" NeedRoll tests`
finds only `:701` and `:938-940` (the `Lists.lua` hits are a row's own
`titleIcon`).

**Fix.** Anchor the holder once. Either keep the `CreateHeader` anchor and
drop line 699, or pass the header height into `AddNativeTitle`. Store only
the field that is read (or none, if the anchor moves into `AddNativeTitle`),
and fix the comment to match.

### R5 · Dead guards left in while the same pass removed others
- **Severity:** should fix
- **Area:** Redundant code (and consistency)
- **Where:** `NeedRoll/UI/MainFrame.lua:280` `issecretvalue and issecretvalue(value)`; `:774` `if search.Instructions`; `:775` `if search.searchIcon`; `:788` `if icon then`; `:792` `if hint then`; `:806` `if settings.SetBarHeight then`; `:170` `Spell and Spell.CreateFromSpellID`
- **Status:** fixed in round 2 (uncommitted): all seven guards removed (`:169`, `:277`, `:734-772`)

**What's wrong.** The pass removed the `GetMouseFocus`, `SetMinResize`,
`DoesSpellExist`, `ToggleWorldMap` and `SetMouseMotionEnabled` fallbacks
because Forever has the new calls. It kept guards of the same kind:
- `issecretvalue` is in Ketho's `forever` GlobalAPI (line 6874).
- `search.Instructions` is used without a guard at `:372`
  (`box.Instructions:SetText(hintText)`) on every native build, so the guard
  at `:774` can never be false.
- `icon` and `hint` (`:787-797`) are the native template's
  `searchIcon`/`Instructions` or the modern box's own `icon`/`hint`, which
  `CreateSearchBox` always creates.
- `settings:SetBarHeight` is always defined (`Settings.lua:149`, inside
  `Settings:CreateButton`).

**Why it matters.** The same question gets two answers in one file, and a
reader can't tell which values may really be nil. The guards also cost
lines and two levels of nesting in `SizeTopBar`.

**Evidence.** Greps above; `wow.lua:853-856` (the stand-in's
`SearchBoxTemplate` makes `searchIcon` and `Instructions`). Two guards are
there for the stand-in, not the game: `wow.lua` has no `Spell` table and no
`Left`/`Middle`/`Right` edge textures, so `:170` and `:780` keep the smoke
tests running. *(Correction, round 2: this was wrong. `wow.lua:1563` defines
`Spell`, and `wow.lua:841`/`:851` give the input templates
`Left`/`Middle`/`Right`. My round-1 grep was cut off by `head`. Neither guard
was ever needed for the stand-in.)* That `Spell` and the edge art exist in Forever is inferred:
`SpellMixin` is in the `forever` Mixins list, and `Spell` itself is a
FrameXML table that no list includes.

**Fix.** Drop the guards at `:280` (`not issecretvalue(value)`), `:774`,
`:775`, `:788`, `:792` and `:806`, and unindent the blocks they wrapped. For
`:170` and `:780`, either define a `Spell` stand-in and the three edge
textures in the module test file (as the brief allows) and drop those
guards too, or keep them with a comment saying why, e.g.
`-- the smoke stand-in has no Spell`.

### R6 · `RefreshStrip` also returns the boss's abilities, threaded through three functions
- **Severity:** should fix
- **Area:** Readability (one job per function, avoid disinformation)
- **Where:** `NeedRoll/UI/MainFrame.lua:1894-1925` (`RefreshStrip`), `:2043`, `:2087`, `:1982` (`LabelBossTabs`), `:1993` (`ShowAbilitiesPage`, 6 parameters), `:2006` (`ShowLootPage`)
- **Status:** fixed in round 2 (uncommitted): `RefreshStrip`/`UpdateBossTabs` return nothing; `ShowLootPage` calls `AbilityEntries` itself. This opened R17.

**What's wrong.** `RefreshStrip` lays out the strip, but it also returns
`UI:UpdateBossTabs()`'s ability list. `UI:Refresh` holds that value, passes
it to `ShowLootPage`, and `ShowLootPage` passes it on to `LabelBossTabs` and
`ShowAbilitiesPage`. `ShowAbilitiesPage` ends up with six positional
parameters (`inst, enc, abilities, abilityCount, subtitle, bosses`).

**Why it matters.** The name says "refresh the strip". A newcomer reading
`local abilities = RefreshStrip()` has to open the function to learn where
the boss's abilities come from. The value is only needed on the loot path.

**Evidence.** `AbilityEntries(inst, enc, bosses)` caches on
`enc.abilities` (`:144`, `:163`). It returns nil on the Overview, quest and
search pages, which never reach `ShowLootPage`. `ShowLootPage` already
computes `bosses` (`:2010`).

**Fix.** Have `ShowLootPage` call `AbilityEntries(inst, enc, bosses)`
itself. The cache makes this free and the result is the same, since
`UpdateBossTabs` already cleared `state.bossTab` when it was nil. Then
`RefreshStrip` returns nothing, and `UI:Refresh` and `ShowLootPage` each
lose a parameter. Count the abilities in `ShowAbilitiesPage` (or have
`LabelBossTabs` only set the labels) to cut the six parameters down.

### R7 · `Build` helpers read hidden state; `CreateWindow` vs `CreateMainWindow`
- **Severity:** should fix
- **Area:** Readability (avoid mental mapping, consistency)
- **Where:** `NeedRoll/UI/MainFrame.lua:704` `CreateWindow`, `:884` `CreateMainWindow`, `:957-960` `CreateTopBar(header)` reading `UI.tabBar`, `:979-981` `CreateFooter()` reading `UI.frame`, `:1090-1098` tab bar still built inline in `UI:Build`
- **Status:** fixed in round 2 (uncommitted): `CreateTabBar(window, header)`, `CreateTopBar(header, tabBar)`, `CreateFooter(window)`; `CreateWindow` folded into `CreateMainWindow`

**What's wrong.**
- `CreateTopBar(header)` takes the header, but on native it builds on
  `UI.tabBar`, which `UI:Build` must have set first.
- `CreateFooter()` takes nothing and reads `UI.frame`.
- `CreateHeader(window)`, `CreateLists(body)` and `CreateContent(body)` get
  their parent as an argument.
- The tab bar, the one part of the window not given a helper, is still
  built inline between these calls.
- `CreateWindow` (the bare frame per style) and `CreateMainWindow` (that
  frame plus move, resize, Escape and sounds) differ by one word, so a
  reader has to open both.

**Why it matters.** `UI:Build` reads like a list of independent steps, but
moving `CreateTopBar` above the tab bar lines would break the native
window. Nothing at the call site shows that.

**Evidence.** Read `:957-1123`.

**Fix.** Pass what each helper uses: `CreateTopBar(header, tabBar)` and
`CreateFooter(window)`. Move the tab bar into a `CreateTabBar(window, header)`
next to the others. Fold `CreateWindow` into `CreateMainWindow`, or give it
a name that says what it is (e.g. `CreateStyledFrame`).

### R8 · Footer and strip spacing are bare numbers that other code must match
- **Severity:** should fix
- **Area:** Readability (searchable names)
- **Where:** footer: `:991` `S.pad + 10`, `:998` `-S.pad - 10`, `:1296` `-18`, `:1307-1310` (`S.pad + 10` twice, `18` twice). Strip's right end: `:1068`, `:1070`, `:1172`, `:2148` `-S.pad + 4`; `:1072`, `:2146` `-6`; `:2156` `+ 6`
- **Status:** fixed in round 2 (uncommitted): `STRIP_INSET`, `STRIP_BUTTON_GAP`, `FOOTER_INSET`, `FOOTER_GAP` used at every listed site

**What's wrong.** `FitFooter` only works if its `S.pad + 10` and `18` equal
the insets and gap set in `CreateFooter` and `UpdateVersionNote`. The new
comment at `:1306` explains this instead of naming the numbers.
`StripButtonsWidth` likewise relies on the `6` gap and `-S.pad + 4` inset
written in four other places. For the strip's left side the pass did add
`BACK_INSET` and `BACK_HINT_GAP`, but not for the right side or the footer.

**Why it matters.** If someone changes the footer inset in one place, the
hint hides too early or overlaps the status. Nothing errors and nothing
greps the numbers together. This is the "one function or constant instead
of the same number in four places" rule (`docs/READABLE-CODE.md` §7).

**Evidence.** Lines above.

**Fix.** Add `FOOTER_INSET = S.pad + 10` and `FOOTER_GAP = 18`, and
`STRIP_RIGHT_INSET = S.pad - 4` and `STRIP_BUTTON_GAP = 6`, next to
`BACK_INSET`. Use them at every site listed and drop the `:1306` comment.

### R9 · Style guide still points to `GoodPoint`, renamed to `IsUsableWindowPoint`
- **Severity:** should fix
- **Area:** Readability (avoid disinformation)
- **Where:** `docs/STYLE-GUIDE.md:43` ``(`GoodPoint` in `MainFrame.lua`)``
- **Status:** fixed in round 2 (uncommitted): `docs/STYLE-GUIDE.md:43` now names `IsUsableWindowPoint`. That file is outside the group's list (brief), so tell the coordinator in case another group also edits it

**What's wrong.** The rename leaves the style guide naming a function that
no longer exists.

**Why it matters.** CLAUDE.md says the style guide is "read from the code".
Someone checking the saved-position rule will grep for a name that isn't
there.

**Evidence.** `grep -rn GoodPoint` matches only `docs/STYLE-GUIDE.md:43`.

**Fix.** This group can't edit the style guide (brief: own files only).
List it under "Cross-module" in the hand-back, so the merge updates line 43
to `IsUsableWindowPoint`.

### R10 · The file grew by 59 lines; Mike's goal is less code
- **Severity:** should fix
- **Area:** Readability (Mike's "less code is the aim")
- **Where:** whole file: 2458 → 2517 lines (code +3, comments +36, blanks +20)
- **Status:** fixed in round 2 (uncommitted): 2457 lines (code 1922 → 1903, comments 372 → 389, blanks 164 → 165)

**What's wrong.** The splits made the long functions readable, but each
new helper brings a header comment, an `end` and a blank line. The cuts
were too small to pay for them.

**Why it matters.** The brief says "the group should end up shorter than it
started".

**Evidence.** Line counts in "What the change does".

**Fix.** These cuts are all inside this file and keep clarity:
- R3: one `OnHide` hook (about -5 lines).
- R4: one title placement, no dead fields (about -3).
- R5: dead guards gone and their blocks unindented (about -4 to -6).
- R6: no abilities threading (about -3).
- R11: inline the one-use wrappers (about -8).
- Trim header comments that restate the function name where the name
  already says it, for example `-- The width the strip's buttons take at its
  right end, with the gaps between them.` over `StripButtonsWidth`.

Together these should bring the file under 2458 lines.

### R11 · Thin single-use wrappers that add lines
- **Severity:** nit
- **Area:** Readability
- **Where:** `:852` `local function ApplyScale() UI:ApplyScale() end` (replaced two one-line closures, net +1 line); `:1946` `ShowOverviewPage` (3-line body, one caller); `:1982` `LabelBossTabs` (named for labelling but also returns the count, one caller)
- **Status:** fixed in part in round 2 (uncommitted): the `ApplyScale` wrapper is inlined and `LabelBossTabs` is gone. Left as is: `ShowOverviewPage`, for the implementer's locale-order reason (`tools/locales.py` writes enUS.lua in first-appearance order per file, and moving `L["1 quest"]` would change enUS.lua, which this group may not touch). Checked in `tools/locales.py` `build()`.

**Fix.** Use `function() UI:ApplyScale() end` inline twice, or keep the
wrapper if the file's `UpdateMapKey`/`Moved` style is preferred. Put
`ShowOverviewPage`'s three lines back in its `elseif`. Fold
`LabelBossTabs` into the abilities path (see R6).

### R12 · Short or misleading names still in touched code
- **Severity:** nit
- **Area:** Readability (meaningful names, avoid disinformation)
- **Where:**
  - `:122`, `:127`: `n` in `BossFolds` (a boss number). Use `bossNumber`.
  - `:2244`: `local tab = key == "abilities" and self.state.encounter or nil`.
    `tab` is an encounter, not a tab. Use `abilitiesEncounter`.
  - `:2127`: `local on`. Use `abilitiesOpen`.
  - `:1469`: `need`. Use `neededWidth`.
  - `:960`: `local close = not native and CreateCloseButton(header)` is false
    or a button. Create it in the modern branch.
  - `:746`: `window:SetSize(math.min(math.max(...), maxWidth), math.min(...))`
    replaced two named locals `w`/`h` with one nested call over two lines.
    `local width = ...` and `local height = ...` were clearer.
- **Status:** fixed in round 2 (uncommitted): `bossNumber`, `abilitiesEncounter`, `abilitiesOpen`, `neededWidth`, the close button made in the modern branch, and `width`/`height` locals in `PlaceWindow`

### R13 · `self.` and `UI.` mixed inside one method
- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** `:2220-2227` `UI:ShowBossOnMap` uses `self.state` and `UI.BossFloor`; `:2294` `UI.PlayerFloor` inside `UI:FollowPlayer`; `:1840` uses `self.QuestSide()`; `:1623-1633` `UI:SelectRecipe` uses both `state.search` and `self.state.instance`
- **Status:** fixed in round 2 (uncommitted): `self.BossFloor`, `self.QuestDropSpot`, `self.PlayerFloor` inside methods; `SelectRecipe` uses `state` throughout

**Fix.** Inside `UI:` methods use `self.` throughout (the pass switched
`ns.UI.X` to `UI.X`, which is right for the file-level local functions).
In `SelectRecipe` use the `state` local everywhere.

### R14 · Test file: 13 new luacheck warnings, `f`, and two paths not covered
- **Severity:** nit
- **Area:** Readability
- **Where:** `tests/smoke/modules/UI-MainFrame.lua`
- **Status:** fixed in round 2 (uncommitted): `fn = function(_, ns)` (test file luacheck clean), `window` instead of `f`, and new tests for modern sounds, the breadcrumb after a style switch and the Wishlist list change

**What's wrong.**
- 13 `unused argument 'W'` warnings (lines 44, 58, 122, 147, 236, 273, 314,
  341, 421, 437, 458, 488, 501).
- `local f = ui.frame` at `:86` is a one-letter name.
- Not covered: the Wishlist branch of `OnListChange`, and the sounds in the
  modern style (which would catch R1 once the stand-in clears hooks).
- Nothing tests R2's style-switch round trip for the breadcrumb.

**Fix.** Write `fn = function(_, ns)` where `W` is unused, or ask for the
module-test signature to be allowed in `.luacheckrc` at merge time. Rename
`f` to `window`. Add the two tests described in R1 and R2.

All tests restore what they override through `Restoring` (xpcall, restore,
re-raise). The one test without it, "tab icons and labels", overrides
nothing.

### R15 · `GoToResult` repeats `GoToSource(result.inst)` in two branches
- **Severity:** nit
- **Area:** Redundant code
- **Where:** `MainFrame.lua:1781-1790`
- **Status:** fixed in round 2 (uncommitted): `:1743-1750`

**What's wrong.** The `"place"` and `"quest"` branches both call
`self:GoToSource(result.inst)`. The quest branch then also selects the
quest.

**Fix.**
```lua
if result.kind == "place" or result.kind == "quest" then
    self:GoToSource(result.inst)
    if result.quest then self:SelectQuest(result.quest) end
else
    self:GoToSource(result.inst, result.enc, result.itemID, result.fold)
end
```
Only quest results carry `quest` (`NeedRoll/UI/Search.lua:316`, `:337`,
`:342`, `:375` build the four kinds), so the sketch keeps behaviour.

The two luacheck long-line warnings left (`:341`, `:344`) are not a
finding. Each of those lines is a literal `L["..."]` key, and wrapping the
key would break `tools/locales.py`'s literal-key scan.

### R16 · The secure-link comment block is split across `links` and `GameMapLink`
- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `MainFrame.lua:2424-2435`
- **Status:** fixed in round 2 (uncommitted): `local links` first with its entry shape (`:2364-2365`), then the whole explanation over `GameMapLink`

**What's wrong.** The paragraph that explains `GameMapLink`'s secure button
ends with a description of the `links` entries, then `local links = {}`,
then a one-line comment on `before`, then the function. The reader moves
from the function's purpose to a table and back.

**Fix.** Put `local links = {}` with its entry description first, then the
whole explanation (including `target`, `when` and `before`) directly over
`GameMapLink`.

### R17 · `ShowLootPage` now draws two pages, nested four deep
- **Severity:** should fix
- **Area:** Readability (one job per function, guard clauses)
- **Where:** `NeedRoll/UI/MainFrame.lua:1937-1983`
- **Status:** fixed in round 3 (uncommitted). `LabelBossTabs(itemCount, abilities)` (`:1932`) only sets the two labels; `ShowAbilitiesPage(inst, enc, abilities, subtitle, bosses)` (`:1938`) takes five parameters. `ShowLootPage` is down to two flat `if`s (`:1971-1975`). The count lives in `AbilityEntries` as `out.count` (`:161`, `:165`), with the boss headings left out. The probe in Checks found 0 mismatches across 218 encounters. The `L[...]` keys keep their order (`locales.py --check` passes). `out.count` is a hash field on the entry list. Its readers walk the list with `ipairs` (`LoadAbilities`, `UI.loot:ShowItems`; no `pairs(entries)` in `LootGrid.lua`), so they don't see it.

**What's wrong.** R6's fix folded `LabelBossTabs` and `ShowAbilitiesPage`
into `ShowLootPage`, which is now 47 lines with three jobs:
- it builds and draws the loot page;
- it counts abilities and labels the Loot / Abilities pills;
- it draws the abilities page and loads its spells, then returns early.

The abilities part is nested four deep: `if abilities` → `if
UI.state.bossTab == enc` → the `LoadAbilities` callback → its `if`. The
header comment has to say "or a dungeon boss's abilities page", which the
name `ShowLootPage` does not.

**Why it matters.** `docs/READABLE-CODE.md` §3 and §4: a function a
newcomer can't name in one verb, and three levels as the sign to pull a
piece out. A reader looking for the abilities page won't search for it in
`ShowLootPage`.

**Evidence.** Read `:1937-1983`.

**Fix.** Pull the abilities page back out, with fewer parameters than
round 1 had:
`ShowAbilitiesPage(inst, enc, abilities, subtitle, bosses)` counts its own
abilities (a 3-line loop, or a small `CountAbilities(abilities)` both
callers use). In `ShowLootPage`, keep only the two `SetLabel` calls and
`if abilities and UI.state.bossTab == enc then ShowAbilitiesPage(...)
return end`.

Keep the `L[...]` keys in the file order they have now ("Loot  ·  %d",
"Abilities  ·  %d", "1 ability", "%d abilities", "%d items"), so
`locales.py --check` still passes. Defining a helper that holds the two
`SetLabel` calls ahead of `ShowAbilitiesPage`, as round 1 did, keeps that
order.

### R18 · Round 2 deleted comments that held facts the names don't
- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `MainFrame.lua:2124` `OverviewOf`, `:1126` `CreateWholeBodyHost`, `:1669` `IsWithin`
- **Status:** fixed in round 3 (uncommitted): comments back on `OverviewOf` (`:2124`), `CreateWholeBodyHost` (`:1128`), `IsWithin` (`:1666`), each saying what the name doesn't

**What's wrong.** To get under the line count, round 2 removed header
comments. Most of them only restated the name (`ScarceTitle`,
`CreateCloseButton`, `StripButtonsWidth`), and those cuts are fine. Three
carried something the name does not:
- `OverviewOf`: an instance's Overview is its *first encounter*, flagged
  `overview`. That is a data-layout fact a newcomer can't guess, and the
  code `inst.encounters[1]` only shows it if you already know it.
- `CreateWholeBodyHost`: it also *hides* `page`, which its name doesn't say.
- `IsWithin(frame, ...)`: the frames are variadic, and it matches the frame
  itself as well as its parents.

**Fix.** Put back one short line on each, e.g.
`-- An instance's Overview is its first encounter (flagged overview); nil without one.`

### R19 · `AddNativeTitle` keeps a fallback for a title bar Forever's template has
- **Severity:** nit
- **Area:** Redundant code (consistency with R5)
- **Where:** `MainFrame.lua:673-676`: `window.TitleContainer and window.TitleContainer.TitleText or window.TitleText`, `if not templateTitle then return end`, `window.TitleContainer or window`
- **Status:** fixed in round 3 (uncommitted): a comment at `:675` says where `TitleContainer` comes from and what `TitleText` is for. Keeping the fallback is acceptable while it is only inferred dead.

**What's wrong.** R5 removed guards for things Forever always has. These
three lines guard against an older `ButtonFrameTemplate` without
`TitleContainer`.

**Evidence (inferred).** Ketho's `forever` Templates.lua:456 has
`ButtonFrameTemplate` inheriting `ButtonFrameBaseTemplate`, and
Templates.lua:455 has that inheriting `PortraitFrameBaseTemplate` with
`PortraitFrameMixin` (:2592). `TitleContainer` is a parentKey of that base
in current FrameXML, but parentKeys aren't in Ketho's lists. So this is
inference, which is why it is a nit.

**Fix.** If Mike can confirm in game (`/dump NeedRollNativeFrame.TitleContainer`),
use `window.TitleContainer.TitleText` and `window.TitleContainer` directly
and drop the nil guard. If not, leave a comment naming what the fallback
is for.

### R20 · The `-- Selection ---` banner now reads as `LayoutLists`' first comment line
- **Severity:** nit
- **Area:** Readability (consistent formatting)
- **Where:** `MainFrame.lua:1419-1420`
- **Status:** fixed after round 3 (the blank line is back)

**What's wrong.** Round 3 deleted the blank line after
`-- Selection ----...`, probably to land on 2458 lines. The other section
banners (`:1152` Settings page, `:1284` Style switching, `:1350` Connector)
either have their own description and then a blank line, or a blank line
before the first function's comment. Now the banner sits directly on
`LayoutLists`' comment and reads as part of it.

**Why it matters.** It is small, but formatting chosen to hit a line count
is the wrong trade (`docs/READABLE-CODE.md` §2). A reader skimming for
sections sees a banner that seems to describe one function.

**Fix.** Put the blank line back. The file then ends at 2459 lines, one
over the base: code is still 25 lines under, which is what Mike asked for.
Or give the banner a one-line description, as the other sections have.

## Area notes

### Readability

Checked every rule in `docs/READABLE-CODE.md` against each changed
function.

What is sound:
- The big splits (`Build`, `Refresh`, `SelectCategory`) each produce pieces
  whose names say what they show.
- `InstanceToOpen`'s comment carries the faction-counterpart rule that was
  inline before.
- `IsUsableWindowPoint` is split into one rule per line, and its NaN line
  has a comment.
- `INSTANCE_TABS` and `LOOT_FILTER_TABS` replace four hand-written
  category tests.
- The renamed locals (`growth`, `lastFloorKey`, `boundKeys`,
  `failedMapButtons`, `linkLayer`, `LayOverLink`, `lineWidth`,
  `PlaceSegment`) now say what they hold.
- No comments narrate the change.
- Formatting is right: 4-space indents, no tabs, no CR, `local _, ns = ...`
  kept, and the one wrapped `T:LabelToggle` line is within 120.
- Lua 5.1 traps: no `cond and nil or x`. `CountText` relies on `one` being
  a non-empty string, which every caller passes. `FollowPlayer` builds its
  pattern from `inst.id`, a number, so nothing needs escaping.

Findings R2–R16 cover what is left.

**Round 2.** I re-read every function round 2 touched against the same
rules. What is sound:
- The four new constants are named for what they measure and used
  everywhere the number appeared. `STRIP_INSET` replaced `BACK_INSET` for
  both ends of the strip, and its value is unchanged (`-STRIP_INSET` equals
  the old `-S.pad + 4`).
- `CreateMainWindow` now builds the frame for each style and sets it up,
  in 46 lines with one level of branching.
- The single `OnHide` handler runs the three old steps in their old order.
- `SizeTopBar` lost two levels of nesting. Its icon and hint sizes are the
  old values (`(native and 14 or 12) * growth * 0.8`, the small font grown
  less 4).
- `GoToResult`'s merged branch is the same, since only quest results carry
  `quest` (`UI/Search.lua:375`).
- The removed blank lines were the ones round 1 had added inside functions.
  Blanks are 165 against the base's 164.
- The new tests restore what they change. The Wishlist test puts back
  `UpdateStars` and un-stars its item. The sound test puts back
  `PlaySound` and the style.

R17–R19 cover what is left.

**Round 3.** What is sound:
- `LabelBossTabs` and `ShowAbilitiesPage` each do one thing their names
  say.
- `GoBack` uses a guard clause.
- The four comments are back where they carry facts.
- `CreateFactionToggle` inlines the faction list, which was its only use
  (`grep -rn FACTIONS NeedRoll`: no other hit).
- `UpdateLink` sets the three tab segments in one loop.

**Dropped `backHint:SetShown` in `RefreshStrip`** (the coordinator's
question). This is the same on every path:
- `RefreshStrip` is the only place Back's visibility changes. `UI.back`
  is shown or hidden only at `:1854`
  (`grep -rn "\.back:Show\|\.back:Hide\|\.back:SetShown" NeedRoll`).
- Between that line and `UI:FitStrip()` (`:1859`), only `back:SetLabel`,
  `UpdateAddButton`, `UpdateBossTabs` and `UpdateMapButton` run, and none
  of them reads `backHint`.
- `FitStrip` sets `backHint:SetShown(self.back:IsShown() and <fits>)` with
  no early return. That value never depended on the removed line: the old
  line set `back:IsShown()`, which `FitStrip` then overwrote at once.
- The first reader, `UI:UpdateCrumbs` (`:2114`), runs after `FitStrip`.
- The other caller of `FitStrip`, content `OnSizeChanged` (`:1057`), also
  sets it from scratch.
- `backHint` is a plain frame with no `OnShow`/`OnHide` scripts, so the old
  momentary show/hide had no side effect.

R20 is the only thing left.

### WoW API

Every call the change newly makes without a guard, or keeps after dropping
its fallback, was checked against Ketho's `forever` lists, downloaded on
2026-10-18 from BlizzardInterfaceResources (`forever` branch, `Resources/`).

| Name | Kind | In `forever` lists | Where |
| --- | --- | --- | --- |
| `GetMouseFoci` | global function | yes | GlobalAPI.lua:5611 |
| `GetMouseFocus` (removed) | global function | no, so removing it is right | GlobalAPI.lua (absent) |
| `C_Spell.DoesSpellExist` | C_ function | yes | GlobalAPI.lua:3925 |
| `ToggleWorldMap` | FrameXML function | yes | FrameXML.lua |
| `ShowUIPanel`, `ButtonFrameTemplate_HidePortrait` | FrameXML functions | yes | FrameXML.lua |
| `SetResizeBounds` | Frame method | yes | WidgetAPI.lua:644 (Frame) |
| `SetMinResize` / `SetMaxResize` (removed) | Frame methods | no, so removing them is right | WidgetAPI.lua (absent) |
| `SetMouseMotionEnabled` | ScriptRegion method | yes | WidgetAPI.lua:124 (ScriptRegion) |
| `SetPropagateKeyboardInput`, `SetRotation`, `SetColorTexture` | widget methods | yes | WidgetAPI.lua |
| `issecretvalue`, `UnitFactionGroup`, `InCombatLockdown`, `GetBindingKey`, `SetOverrideBindingClick`, `ClearOverrideBindings`, `hooksecurefunc` | global functions | yes | GlobalAPI.lua |
| `GLOBAL_MOUSE_UP` | event | yes | Events.lua |
| `SecureActionButtonTemplate`, `SearchBoxTemplate`, `ButtonFrameTemplate` | templates | yes | Templates.lua |
| `Spell:CreateFromSpellID` | mixin object | inferred (`SpellMixin` in Mixins.lua; `Spell` itself in no list) | Mixins.lua:2968 |
| `MinimapCluster.ZoneTextButton`, `MiniMapWorldMapButton`, `WorldMapMicroButton` | global frames | inferred; unchanged by the diff, looked up at run time with type checks | none of the lists |

**Round 2: guards removed, checked against Ketho's `forever` lists** (the
copy in the scratchpad's `ketho/` folder, not `wow.lua`):

| Guard removed | What it guarded | In `forever` lists | Evidence |
| --- | --- | --- | --- |
| `issecretvalue and` (`:277`) | global function | yes | GlobalAPI.lua:6874 |
| `Spell and Spell.CreateFromSpellID` (`:169`) | FrameXML object `Spell` | inferred: `SpellMixin` is in Mixins.lua:2968; the `Spell` table itself is in no list | Mixins.lua |
| `search.Instructions`, `search.searchIcon` (`SizeTopBar`) | `SearchBoxTemplate` parentKeys | inferred: Templates.lua:3032 `SearchBoxTemplate` inherits `InputBoxInstructionsTemplate`, whose `Instructions` the code already used unguarded at `:369`. ParentKeys aren't listed. | Templates.lua:3032, :1936 |
| `part and part.SetHeight` for `Left`/`Middle`/`Right` | edge textures | inferred: Templates.lua:1938 `InputBoxTemplate` inherits `InputBoxVisualTemplate`, which draws the three edge textures. `SetHeight` is a Region method (WidgetAPI.lua). | Templates.lua:1938 |
| `settings.SetBarHeight` | NeedRoll's own method | n/a; always defined (`Settings.lua:149`) | Settings.lua |
| `if icon`, `if hint` | the box's own fields | n/a; always made by `CreateSearchBox` / the template | MainFrame.lua:369-410 |

Round 2 added no new game call, event, template or atlas. Neither did
round 3. It removed no guards; R19 kept its fallback with a comment.
`HookScript("OnShow")` and `HookScript("OnSizeChanged")` are ScriptRegion
and Frame scripts (WidgetAPI.lua lists `HookScript`). The R1 fix follows
warcraft.wiki.gg `API_ScriptRegion_HookScript` ("Any hooks applied will
remain in place until replaced or cleared with SetScript"). No other
`SetScript` on the window remains (`grep -rn "window:SetScript\|UI.frame:SetScript" NeedRoll`:
no hit).

**Secure buttons and the map key:** the behaviour is the same.
- The only change on the secure link buttons is that
  `over:SetMouseMotionEnabled(false)` is no longer guarded. It runs at file
  load, as before, and the method exists in Forever.
- `PreClick`'s `InCombatLockdown()` return and `LayOverLink`'s combat
  checks are unchanged.
- `PLAYER_REGEN_DISABLED` still hides the buttons as combat starts.
- `UI:UpdateMapKey` still returns in combat before
  `ClearOverrideBindings`/`SetOverrideBindingClick`.
- The Settings page's `SetPropagateKeyboardInput` is still behind
  `InCombatLockdown()`. The handler now uses `host` instead of `self`,
  which is the same frame.
- The module test "the map key toggles the dungeon's map and waits out
  combat" passes on both base and new code.

**Events:** none newly registered. `UI_SCALE_CHANGED` and
`DISPLAY_SIZE_CHANGED` share one function now.

**Secret values:** `IsUsableWindowPoint` keeps the `issecretvalue` check
before any comparison. Smoke passes in the secret-values run.

**Globals:** W11x comparison shows no new global name. No function is near
60 upvalues (`luac5.1 -p` passes).

**Player text:** no `L[...]` key was added, renamed or reworded
(`locales.py --check` passes). No UI value changed, so no
`STYLE-GUIDE.md` update is due apart from the stale name in R9.

**Pre-existing, not changed:** R1, the `SetScript` after `HookScript`.

### Redundant code

Compared against:
- `T:Pill`, `T:Text`, `T:FitAtlas`, `T:PaneStrip`, `T:CreatePanel`,
  `T:LabelToggle`, `T:ScaledFont` and `T:LineWidth` in `Theme.lua`. The new
  helpers don't duplicate any of them.
- `AddStroke`/`TintStrokes` replace two copies of the stroke code.
- `SetSearchKeys` and `SetTextQuietly` replace two and four copies.
- `CreateWholeBodyHost` replaces three copies.
- `OverviewOf` and `OpenMapAt` replace the bodies shared by
  `ShowBossOnMap` and `ShowQuestOnMap`.
- `StripButtonsWidth` replaces two copies of the right-end width loop.

Removed names nothing else uses (`grep -rn` over the repo, excluding
reviews): `GoodWindowPoint` (no hit), `BuildShopping`/`BuildWishlist` (no
hit), `UI:CreateLink` (only the new local `CreateLink`). `GoodPoint` is
still named in `docs/STYLE-GUIDE.md:43` (R9). `ns.UI.smallGridScale` is
still set (`:95`, now via the `UI` alias) for `Overview.lua:3300` and
`:3477`.

**Recipe-filter clears:** the three dropped `ClearRecipeFilter()` calls
(`SelectRecipe`, `RestorePlace`, `GoToSource`) really were redundant. Each
caller sets `state.instance = nil` and then calls
`SelectInstance(instance, ...)` with a non-nil instance. `SelectInstance`'s
first line is `if instance ~= self.state.instance then
self:ClearRecipeFilter() end` (`:1581`), so the filter is still cleared at
the same point. `ClearRecipeFilter` now calls `ClearFocus` after `quiet` is
reset. Neither box's `OnEditFocusLost` (`:412`, and the template's) reads
`quiet` or runs the search, so nothing changes.

**`RememberPlace`'s dropped guard:** `RememberPlace` returns unless
`state.instance` is set. Only `SelectInstance` sets it, and only on a built
window, so `self.recipeFilter` is always there.

**`SetTextSize`'s dropped guard:** `ApplyScale` returns when `self.frame`
is nil.

Remaining redundancy is R3, R4, R5, R11.

### Security

None. The change touches no addon messages, chat, `CHAT_MSG_ADDON` or
drop sharing, and sends nothing. The only outside input is the saved
window position from SavedVariables, which is still checked by
`IsUsableWindowPoint` (same rules) and applied inside `pcall`. No
`loadstring`/`RunScript`. No names or credits involved.

## Round history

- 2026-10-18 · `c0e5c79` + uncommitted · **Changes needed** · opened R1–R16 (10 should fix, 6 nits), closed none.
- 2026-10-18 · `c0e5c79` + uncommitted (round 2) · **Changes needed** (0 blocking, 1 should fix, 2 nits) · closed R1–R10 and R12–R16; R11 fixed in part, `ShowOverviewPage` left as is for the locale-order reason; opened R17 (should fix), R18, R19 (nits). Corrected round 1's R5 evidence about `wow.lua`.
- 2026-10-18 · `c0e5c79` + uncommitted (round 3, final) · **Ready** (0 blocking, 0 should fix, 1 nit) · closed R17, R18, R19; opened R20 (nit, a deleted blank line under the Selection banner). `abilities.count` and the dropped `backHint:SetShown` checked: same behaviour.
