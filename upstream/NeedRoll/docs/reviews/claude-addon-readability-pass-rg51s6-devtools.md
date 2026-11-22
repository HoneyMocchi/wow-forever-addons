# Review: Readability pass, dev tools group (DevKit, SoundTest, IconBrowser, Fished, LineDump, DropTalk, FrameDebug, IconDebug)

| | |
| --- | --- |
| Branch | `rp-devtools` (group worktree of `claude/addon-readability-pass-rg51s6`) into `dev` (PR # not open yet) |
| Commit reviewed | `c0e5c79` plus uncommitted changes (round 2: 7 Lua files, `.pkgmeta` and `UI/UI.xml` modified; `NeedRoll/UI/DevKit.lua` and `tests/smoke/modules/UI-*.lua` untracked) |
| Date | 2026-10-17 |
| Round | 2 |
| Verdict | **Ready** after round 2 fixes (0 blocking, 0 should fix open; R9 deferred to a Drops follow-up, R11 left as traced) |
| Needs | Full client restart: round 2 adds a new file, `UI/DevKit.lua`, to `UI.xml`, and the client only picks up new files at startup. No SavedVariables change. |

## What the change does

Nothing a player sees is meant to change. The seven dev and debug windows
(`/nr icondebug`, `/nr framedebug`, `/nr fontdebug`, `/nr sounds`,
`/nr linedump`, `/nr loot fished`, `/nr droptalk`) are rewritten for
readability. The window pieces that `UI/IconDebug.lua` already lent to
FrameDebug and SoundTest as `ns.IconDebug.kit` become `ns.DevKit`. The kit
gains a painter (text recolored by the background switch, one per window),
`Hint`, `ClickCell`, a shared `Grid`, and `ListWindow`, a list window with a
status line, tabs, an empty note, a pool of rows and the item-loading
helper. Fished and DropTalk each had their own copy of that list window and
now use `ListWindow`. Long functions are split (DropTalk's `Rows`, FontDebug's
`Show`/`Nudge`/`Update`, IconDebug's `BuildContent`, IconBrowser's row
building), short names get full ones, and fallbacks for globals that Forever
has are removed. The Ring of Law pin preview in `/nr icondebug` now uses
`ns.UI.MiniPin`. Seven new smoke test files cover the windows.

Size (`wc -l`, then non-blank non-comment lines):

| File | Lines | Code lines |
| --- | --- | --- |
| SoundTest.lua | 165 -> 164 | 139 -> 134 |
| IconBrowser.lua | 225 -> 242 | 179 -> 188 |
| Fished.lua | 245 -> 156 | 206 -> 123 |
| LineDump.lua | 257 -> 260 | 224 -> 217 |
| DropTalk.lua | 433 -> 412 | 375 -> 335 |
| FrameDebug.lua | 654 -> 681 | 538 -> 542 |
| IconDebug.lua | 760 -> 908 | 626 -> 703 |
| **Total** | **2739 -> 2823** | **2287 -> 2242** |

Comment lines went 235 -> 336 and blank lines 217 -> 245. Code is down 45
lines. Total lines are up 84, all of it comments and blank lines.

**Round 2.**
- The kit moves out of `IconDebug.lua` into a new file, `NeedRoll/UI/DevKit.lua`, which UI.xml loads before IconDebug.lua and which ships.
- `ListWindow`, `List` and `LIST_ROW_H` sit in a `--@debug@` block at the end of DevKit.lua.
- `Fished.lua` moves into UI.xml's debug block and onto `.pkgmeta`'s ignore list.
- `ScrollArea` and `Grid` now take their width from the window or content frame instead of the icon window's 760 px.
- `CLASS_TCOORDS` is removed from IconDebug.lua, along with its fallbacks.
- LineDump's styles with one texture use a `paint` field instead of repeating `CreateTexture`.
- The tests restore their stand-ins and data through `Restoring`, and add `UI-DevKit.lua` plus tests for the sword pins and the class cells.

Round 2 sizes (`wc -l`, then code lines): DevKit 334/248, SoundTest 159/129, IconBrowser 234/182, Fished 147/123, LineDump 243/198, DropTalk 390/319, FrameDebug 666/534, IconDebug 556/442. **Total 2729 lines (was 2739 before the pass), 2175 code lines (was 2287, so 112 fewer)**, 333 comment lines.

## Scope

- `NeedRoll/UI/IconDebug.lua`: the "Window kit" section is exported as `ns.DevKit`, replacing `IconDebug.kit`. It adds the Painter, `Hint`, `ClickCell`, the shared `Grid`, and `List`/`ListWindow`. The icon page is split into `ProfessionSections`, `ClassSections`, `InsigniaRows`, `PortalSections`, `SideTabSections` and the cell helpers. `CLASSIC_CLASSES` and the `C_Spell` existence guard are removed, and the sword pins use `ns.UI.MiniPin`.
- `NeedRoll/UI/FrameDebug.lua`: uses the kit (`ClickCell`, `Grid`, painter, `Hint`, `ShowBackground`). `AddLevelBadge` and `HEADER_SAMPLES` are pulled out, and the `SetPortraitTextureFromCreatureDisplayID` fallback is removed. Inside `--@debug@`, FontDebug is split into `PlainText`, `AddTextLines`/`AddIconLines`, `NudgeText`/`NudgeIcon`, `Watch` and `CreateInspector`, with named constants and renames.
- `NeedRoll/UI/Fished.lua`: the window, pane, rows, scrolling and item loading are gone in favour of `ns.DevKit.ListWindow`. `RowClick` and `FillRow` are pulled out.
- `NeedRoll/UI/DropTalk.lua`: `Rows` is split into `LogRows`/`MessageRows`/`DropRows`/`WhoLine`/`NewQuestRows`/`SeenOn`/`SavedDropRows`, the summary into `SummaryText`, and the window moves onto `ListWindow`. Adds `When`/`WhenIfKnown`, `LISTED_SHORT` and `EMPTY_NOTES`, and removes the `GetClassInfo` guard.
- `NeedRoll/UI/IconBrowser.lua`: `CreateHeader`/`CreateIcon`/`FillHeader`/`FillIcon` are pulled out, lines become `{ category =, firstIcon = }`, and `Fill` is renamed `FillRow`. Renames: `list` to `categories`, `open` to `openSections`, `Split` to `SplitIcons`. The `BreakUpLargeNumbers` guard is removed.
- `NeedRoll/UI/LineDump.lua`: `Atlas`/`AtlasPart`/`AtlasStrip` become `AtlasStrip` plus the thin `Atlas` and `AtlasBand`. Adds named panel constants, `GIVER`/`STEPS`, and pulls `Build` out of `Toggle`. Removes the `C_Texture.GetAtlasInfo` existence guards.
- `NeedRoll/UI/SoundTest.lua`: uses `kit.Hint`, inlines `SoundID` into `PlayButton`, and adds named constants and loop names.
- `tests/smoke/modules/UI-{DropTalk,Fished,FrameDebug,IconBrowser,IconDebug,LineDump,SoundTest}.lua`: new tests, 16 scenarios.
- Generated data: none touched (`NeedRoll/Data/IconList.lua` is read, not changed).
- Round 2 additions:
  - `NeedRoll/UI/DevKit.lua` (new): the kit. The list window is dev-only.
  - `NeedRoll/UI/UI.xml`: `DevKit.lua` is added before `IconDebug.lua`, and `Fished.lua` moves into the second `<!--@debug@-->` block.
  - `.pkgmeta`: `NeedRoll/UI/Fished.lua` is added to `ignore`.
  - `tests/smoke/modules/UI-DevKit.lua` (new).
  - UI.xml and .pkgmeta are outside the group's file list in the brief. The coordinator asked for this as the R8 fix, but other groups' worktrees may edit UI.xml too, so merge it with care.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 7 Lua files and the 7 test files | passed |
| `luacheck --no-global -q`, before (HEAD copies) | 17 warnings in these files (long lines, shadowed `i`, unused `content`/`vertical`/`self`) |
| `luacheck --no-global -q`, after | 3 warnings: `FrameDebug.lua:565/579/658` unused `self` on `FontDebug:` methods (method signature, fine). No new ones. |
| Global writes (`luac -l` SETGLOBAL) | none in the addon files. `UI-SoundTest.lua` swaps the global `PlaySound` on purpose (see R1). |
| `tests/smoke/check.sh` | passed in all three modes (dev 183 files, packaged 178 files, dev + secret values), about 2 minutes |
| Packaged run covers the shipped code | yes: the `UI/FrameDebug` and `UI/IconDebug` scenarios not marked `dev` run against the packaged build and pass. Fished/DropTalk/SoundTest/LineDump/IconBrowser scenarios are dev-only. |
| `python3 tools/locales.py --check` | passed (rc 0). These files use no `L[...]`: dev-only English. |
| `python3 tools/translations.py` | ran (rc 0). It reports old unused keys in other locales, which predate this change. |
| Scraper unittest | not run (no scraper change) |
| **Round 2:** `luac5.1 -p` (8 addon files and 8 test files) | passed |
| **Round 2:** luacheck | 4 warnings: the 3 unused `self` in FrameDebug, plus `tests/smoke/modules/UI-DevKit.lua:24` line too long (121 > 120, see R12) |
| **Round 2:** SETGLOBAL | none in addon files |
| **Round 2:** `tests/smoke/check.sh` | passed in all three modes (dev 184 files, packaged 178, secret 184) |
| **Round 2:** packaged build reaches neither Fished nor ListWindow | yes. `UI/DevKit: the list window is left out of releases` (runs in packaged mode) asserts `ns.DevKit.ListWindow == nil` and `ns.FishedWindow == nil` and passes. The code paths are traced under Security. |
| **Round 2:** `python3 tools/locales.py --check` | passed |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R10 | should fix | WoW API | `NeedRoll/UI/IconDebug.lua:327-331` | `CLASS_ICON_TCOORDS` is now indexed without a nil guard (global table, not provable from Ketho's lists) | fixed after round 2 by the coordinator (`CLASS_ICON_TCOORDS or {}`), not re-reviewed |
| R1 | should fix | WoW API (smoke tests) | `tests/smoke/modules/*` | A failing assert leaves stubbed game calls and test data in place for every later scenario | fixed in round 2 (uncommitted) |
| R2 | should fix | Readability | `NeedRoll/UI/IconBrowser.lua` | `category` names both a category table and an index | fixed in round 2 |
| R3 | nit | Redundant code | `FrameDebug.lua:23`, `SoundTest.lua:81`, `IconDebug.lua:295` | `SCROLL_TOP = 66` is copied in two files and depends on `kit.Hint`'s hidden `-42` | fixed in round 2 |
| R4 | nit | Redundant code | `IconDebug.lua:544,632,676-680`, `IconBrowser.lua:88` | Dead code: unused `DevKit.WIDTH`, `professionIcons or {}`, `btn.missing = nil`, double tcoords fallback | fixed in round 2 (the tcoords part went too far: R10) |
| R5 | nit | Readability | `SoundTest.lua:86-97`, `IconBrowser.lua:120` | `kitID` next to `kit` (the DevKit); `self.cols` against `columns` | fixed in round 2 |
| R6 | nit | Readability | `DropTalk.lua:33,352`, `SoundTest.lua:80`, `FrameDebug.lua:295-296`, `Fished.lua:92` | One-use constants and comments that restate the line, against the brief | fixed in round 2 |
| R7 | nit | WoW API (smoke tests) | `tests/smoke/modules/UI-IconDebug.lua`, `UI-Fished.lua:36` | No test for the two changed drawing paths (MiniPin sword pins, classes with no fallback); one assert checks stand-in behaviour | fixed in round 2 |
| R8 | nit | Redundant code | `IconDebug.lua:14-16,435-545,308,427`, `Fished.lua:48,123-125` | The kit lives in a shipped page file and assumes the icon window's width; ListWindow ships but only dev code reaches it | fixed in round 2 |
| R9 | nit | Security | `DropTalk.lua:154-156,185-186,220-226,306` (decode in `Core/Drops.lua:286-297`) | Other players' text is shown without escaping `\|` codes (pre-existing, dev-only window) | left as is: deferred to a Core/Drops.lua follow-up |
| R11 | nit | WoW API (smoke tests) | `tests/smoke/modules/UI-DevKit.lua:64-68` | The packaged run never types `/nr loot fished`; release safety rests on a trace through the code | left as is: the release gate is `ns.LootLog.available`, set only inside a debug block (traced in round 2) |
| R12 | nit | Redundant code | `Restoring` in 7 files under `tests/smoke/modules/` | The same `Restoring` helper is copied into seven test files; one test line runs over 120 characters | fixed at integration: the copies become `W.Restoring` from wow.lua; the long line is split |

### R1 · A failing assert leaves stubbed game calls and test data in place for every later scenario

- **Severity:** should fix
- **Area:** WoW API (smoke tests)
- **Where:** `tests/smoke/modules/UI-IconDebug.lua:61-74` and `:115-123` (`C_Texture.GetAtlasInfo`), `UI-SoundTest.lua:28-38` (`PlaySound`), `UI-DropTalk.lua:52-89` and `:93-119` (`ns.db.dropTalk/drops/newQuests/dropOutbox`), `UI-Fished.lua:19-63` (`ns.db.fish.found/hidden`, `W.uncached`), `UI-FrameDebug.lua:55-63` (`ns.db.fontEdit/iconEdit`), `UI-IconBrowser.lua:46-59` (`GetAtlasInfo` across `browser:Fold(1)`)
- **Status:** fixed in round 2 (uncommitted). Every module test file runs the overriding part through `Restoring(test, restore)` (`xpcall`, then restore, then re-raise): IconDebug :76-90 and :145-149, SoundTest :36-47, DropTalk's `WithTestData` :43-52, Fished :28-80, FrameDebug :66-73, IconBrowser :54-65 and DevKit :49-58.

**What's wrong.** Each test swaps in a stub or fake data, asserts, and only
restores at the end:

```lua
C_Texture.GetAtlasInfo = function(atlas)
    if atlas == "Dungeon" then return realAtlasInfo(atlas) end
end
Preview("134400")
assert(FindText(frame, "Texture: 134400"), "a number isn't previewed as a file ID")
...
C_Texture.GetAtlasInfo = realAtlasInfo   -- line 74: never reached if an assert above fails
```

`run.lua:157-163` runs every scenario through `W.Call` and goes on to the
next one after a failure, so nothing undoes the swap.

**Why it matters.** If one of these asserts fails (the reason the tests
exist), every later scenario runs with `GetAtlasInfo` answering nil for
everything except "Dungeon", or with `PlaySound` stubbed, or with the
DropTalk test log as `ns.db.drops`. That gives a cascade of unrelated
failures. The first real failure gets buried, and Mike can't tell which
module broke. The brief asks that tests "restore what they override".

**Evidence.** I read the seven test files and `tests/smoke/run.lua:146-169`.
All seven pass today, so the cascade only shows when something fails
(inferred from the runner's control flow).

**Fix.** Restore in a way that survives an error. Either restore before
asserting: collect the values, put the real function back, then assert, as
`UI-IconBrowser.lua:59` almost does. Or wrap the body:

```lua
local function WithAtlasInfo(stub, body)
    local real = C_Texture.GetAtlasInfo
    C_Texture.GetAtlasInfo = stub
    local ok, err = pcall(body)
    C_Texture.GetAtlasInfo = real
    if not ok then error(err, 0) end
end
```

Use the same shape for `PlaySound` and for the `ns.db` swaps (`UseTestData`/`RestoreData` in DropTalk).

### R2 · `category` names both a category table and an index

- **Severity:** should fix
- **Area:** Readability
- **Where:** `NeedRoll/UI/IconBrowser.lua:74`, `:135-144`, `:172`, `:198-203`
- **Status:** fixed in round 2. The fields are `line.categoryIndex` and `header.categoryIndex` (`IconBrowser.lua:70,135,139,183,189,195`).

**What's wrong.** The change replaces `line[1]` with a named field, but the
name picked is the one already used for the category table:

```lua
lines[#lines + 1] = { category = categoryIndex }                    -- 140: an index
...
local category = self.categories[line.category]                     -- 198: a table, looked up by an index called category
FillHeader(row.header, category, line.category, ...)                 -- 203
header.category = categoryIndex                                     -- 172
header:SetScript("OnClick", function(self) IconBrowser:Fold(self.category) end) -- 74
```

**Why it matters.** READABLE-CODE.md §8/§9 (avoid mental mapping and
disinformation). In `FillRow`, `category` and `line.category` sit on the same
line and mean different things, so a reader has to remember that one is a
number. The rest of the file says `categoryIndex` for the number
(`Fold(categoryIndex)`, `FillHeader(..., categoryIndex, ...)`), so these
fields are the odd ones out.

**Evidence.** Lines quoted above. `Fold`'s parameter is already called `categoryIndex` (`:154`).

**Fix.** Call the fields `categoryIndex`: `{ categoryIndex = i, firstIcon = n }`,
`header.categoryIndex`, `self.categories[line.categoryIndex]`, and update the
comment at `:135-136`. Local names only; nothing outside the file reads them
(grep of `NeedRoll/` and `tests/`).

### R3 · `SCROLL_TOP = 66` is copied in two files and depends on `kit.Hint`'s hidden `-42`

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/FrameDebug.lua:23`, `NeedRoll/UI/SoundTest.lua:81`, `NeedRoll/UI/IconDebug.lua:295`
- **Status:** fixed in round 2. `DevKit.lua:16` defines `HINT_SCROLL_TOP = 66`, `Hint`'s comment points to it, and it is exported. FrameDebug and SoundTest use `kit.HINT_SCROLL_TOP`.

**What's wrong.** Both windows declare `local SCROLL_TOP = 66 -- the scroll
area's top, under the title and hint`. The 66 holds only because
`kit.Hint` puts the hint at `-42` (`IconDebug.lua:295`), a number neither
file can see.

**Why it matters.** READABLE-CODE.md §7 (a value used in more than one place
gets one name). If `Hint` moves, two files have to change in step, and
nothing points to them.

**Fix.** Keep it with the kit, for example
`local HINT_SCROLL_TOP = 66 -- under the title and kit.Hint's line`
exported in `ns.DevKit`, and drop the two local copies (2 lines fewer).

### R4 · Dead code: unused `DevKit.WIDTH`, `professionIcons or {}`, `btn.missing = nil`, double tcoords fallback

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/IconDebug.lua:544`, `:632`, `:205-214` with `:676-680`; `NeedRoll/UI/IconBrowser.lua:88`
- **Status:** fixed in round 2. `WIDTH` is no longer exported, and the `or {}` and `btn.missing = nil` are gone. The tcoords part was removed entirely rather than cut to one guard, which leaves an unguarded global table: see R10.

**What's wrong.**
- `ns.DevKit` exports `WIDTH`, but no file reads `kit.WIDTH` or
  `DevKit.WIDTH`. FrameDebug used it for its own `Grid`, which the kit now
  provides. (Grep of every `kit.` / `DevKit.` use: Backgrounds, ClickCell,
  FitAtlas, Grid, Hint, Hover, LIST_ROW_H, ListWindow, NewPainter, PAD,
  ScrollArea, ShowBackground, StyleSwitch, Window. No WIDTH.)
- `local icons = ns.UI.professionIcons or {}`: `UI/Lists.lua:454` sets
  `ns.UI.professionIcons` unconditionally, and Lists.lua loads before
  IconDebug.lua (UI.xml lines 6 and 17). The `or {}` can't fire.
- `btn.missing = nil` on a button that was just created assigns nothing (carried over from the old loop).
- `CLASS_ICON_TCOORDS or CLASS_TCOORDS`, then again
  `texCoords[class.token] or CLASS_TCOORDS[class.token]`: two fallbacks for a
  FrameXML table that every modern client has. Global tables aren't in
  Ketho's lists, so this is an inference, not proof.

**Why it matters.** The brief's aim is less code: cut dead fallbacks and
needless lines. Each line here makes a reader ask "when is this nil?" and the
answer is never.

**Fix.** Remove `WIDTH = WIDTH` from the export, the `or {}`, and the
`btn.missing = nil` line. For the tcoords: either check
`/dump CLASS_ICON_TCOORDS ~= nil` in game and drop `CLASS_TCOORDS` (11 lines)
and the inner `or`, or keep one fallback and say why in the comment.

### R5 · `kitID` next to `kit` (the DevKit); `self.cols` against `columns`

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/SoundTest.lua:14,86-97`; `NeedRoll/UI/IconBrowser.lua:120,124,143`
- **Status:** fixed in round 2 (`soundKitID`, `self.columns`; the test reads `browser.columns`).

**What's wrong.** In SoundTest, `kit` is `ns.DevKit` (line 14) and
`kitID` is the `SOUNDKIT` ID of a sound (line 86). Both names appear in
`PlayButton` (`kit.Hover(btn)` and `kitID and "" or ...`). In IconBrowser
the change renames the loop and argument to `column`/`columns`, but the
field it comes from stays `self.cols`.

**Why it matters.** READABLE-CODE.md §1/§6. `kitID` reads like "the kit's
ID", and the shortened name is inconsistent with its neighbours.

**Fix.** `local soundKitID = SOUNDKIT and SOUNDKIT[soundName]`. Rename
`self.cols` to `self.columns`, and update `tests/smoke/modules/UI-IconBrowser.lua:34`, which reads `browser.cols`.

### R6 · One-use constants and comments that restate the line, against the brief

- **Severity:** nit
- **Area:** Readability
- **Where:** `DropTalk.lua:33` (`TIME_FORMAT`, read only inside `When`, `:77`); `SoundTest.lua:80` (`BUTTON_GAP`, one use); `FrameDebug.lua:295-296` (`MIN_TEXT_SIZE`, `MIN_ICON_SCALE`, one use each); comments `DropTalk.lua:352` "Draws `entry` on `row`.", `Fished.lua:92` "Draws fished item `itemID` on `row`.", `IconDebug.lua:601` "A cell showing `texture` inside the side tab frame."
- **Status:** fixed in round 2. `TIME_FORMAT`, `BUTTON_GAP`, `MIN_TEXT_SIZE`, `MIN_ICON_SCALE`, `ICON_STEP` and `WATCH_INTERVAL` are inlined. The restating comments are dropped, or say something new (DropTalk's `FillRow` comment names `row.data`).

**What's wrong.** The brief says not to add a constant for a number used once
whose meaning is plain from its line, and to avoid comments that restate the
code. `TIME_FORMAT` is named twice, once as the constant and once as
`When()`. The quoted comments repeat the function's name and arguments.

**Why it matters.** It is small, but it is part of why total lines grew by 84
while code shrank. Comment lines went 235 -> 336. Most of the new comments
earn their place by documenting parameters, px conventions and game facts.
These few don't.

**Fix.** Inline `"%m/%d %H:%M"` into `When`, and `6` into the `SetPoint` (or
keep `BUTTON_GAP` if Mike prefers). Drop the three restating comments, or make
them say something the name doesn't (for example, which fields `FillRow`
expects on `entry`). The FontDebug minimums can stay if the implementer feels
`math.max(4, ...)` isn't plain. Record the reason in Round history.

### R7 · No test for the two changed drawing paths (MiniPin sword pins, classes with no fallback); one assert checks stand-in behaviour

- **Severity:** nit
- **Area:** WoW API (smoke tests)
- **Where:** `tests/smoke/modules/UI-IconDebug.lua` (whole file), `tests/smoke/modules/UI-Fished.lua:36`
- **Status:** fixed in round 2. Two new tests: `UI/IconDebug: crossed swords sit in a copy of a boss's map pin` (checks `pin.portrait`, a shown `pin.back`, and the `pinLook.ring` texture) and `UI/IconDebug: a class icon cell for each class the client has` (a `GetClassInfo` gap gives `GetNumClasses() - 1` classicon cells). `UI-Fished.lua` compares with `tostring`.

**What's wrong.** The two places where this change really changes how
something is built have no test: `SwordPinCells` (`IconDebug.lua:738-750`,
now `ns.UI.MiniPin`) and `ClassSections` with `Classes()` no longer falling
back to `CLASSIC_CLASSES` (`IconDebug.lua:217-224`). Separately,
`rows[2].id:GetText() == FISH_B` compares the font string to a number. In
the client `GetText()` returns the string `"900002"`, so this assert holds
only because the stand-in stores what it was given.

**Why it matters.** The tests are meant to prove that behaviour stayed the
same. The pin swap is the one change a reviewer can't confirm by reading the
diff line for line.

**Fix.** Add a case that finds the "Ability_DualWield" cell and asserts that
its `cell.art` child has `.portrait`, `.back` shown, and a ring texture of
`ns.UI.pinLook.ring`. Add one that counts the cells under "Class icons ·
atlas classicon-<class>" and checks the count equals `GetNumClasses()` with
a nil `GetClassInfo` slot skipped. Compare `tostring(FISH_B)` at
`UI-Fished.lua:36`.

### R8 · The kit lives in a shipped page file and assumes the icon window's width; ListWindow ships but only dev code reaches it

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/IconDebug.lua:14-16`, `:230-545` (kit), `:308` and `:427` (`WIDTH` hard-wired), `NeedRoll/UI/Fished.lua:48`, `:123-125`
- **Status:** fixed in round 2. New `NeedRoll/UI/DevKit.lua` (shipped part: lines 1-224; `--@debug@` list window: lines 226-334). UI.xml loads it before IconDebug.lua; Fished.lua moves into the debug block and onto `.pkgmeta`'s ignore list. `ScrollArea` sizes `content` from `f:GetWidth()` (`DevKit.lua:93`), `Grid` reads `content:GetWidth()` (`:212`), and IconBrowser gets `f:GetWidth()`/`f:GetHeight()` (`IconDebug.lua:539`). The values are unchanged for every current window (728 px wide, so 7 icon columns).

**What's wrong.**
1. About 315 lines of shared kit sit in the middle of `IconDebug.lua`, the
   file for one page, which is most of why it grew 760 -> 908. Fished.lua
   loads before IconDebug.lua (UI.xml lines 13 and 17), so it can't cache
   `local kit = ns.DevKit` like the other three users. It looks it up at run
   time (`:48`, `:125`) and needs a comment to explain why.
2. `Window(globalName, heading, width, height)` takes a size, but
   `ScrollArea` (`content:SetWidth(WIDTH - PAD * 2)`, `:308`) and `Grid`
   (`math.floor((WIDTH - PAD * 2) / cellWidth)`, `:427`) always use the icon
   window's 760. A narrower window built with the kit would get a scroll
   child wider than itself. None does today; FrameDebug and SoundTest use the
   default size.
3. Packaging: `Fished.lua` ships (not in `.pkgmeta` ignore, not in a UI.xml
   debug block), but `/nr loot fished` is reachable only when
   `ns.LootLog.available`, which is set inside LootLog's `--@debug@` block
   (`Core/LootLog.lua:35-36`, `Core/Init.lua:476`). So `ListWindow`/`List`
   (about 105 lines) ship in releases and no release code path reaches
   them. This is not a regression: Fished's own copy shipped unreachable
   before, and it was longer.

**Why it matters.** Is the IconDebug growth earned? Yes on balance:
`ListWindow` removes two near-identical list windows (about 150 lines in
Fished, about 140 in DropTalk), and code lines are down 45 across the group.
But the leanest form of this design is a `UI/DevKit.lua` loaded before
Fished.lua, with Fished.lua, DropTalk.lua and the list half of the kit
dev-only. That would take about 250 lines out of the release zip and remove
the load-order comment.

**Fix.** Within this group: give `ScrollArea` and `Grid` the window's width
(for example `f:GetWidth() - PAD * 2`), or say in their comments that they
are for full-width windows only. Cross-module, for Mike: move the kit to
`NeedRoll/UI/DevKit.lua` before `Fished.lua` in UI.xml, and put `Fished.lua`
(and the list half of the kit) in `.pkgmeta`'s ignore list plus a UI.xml
`<!--@debug@-->` block.

### R9 · Other players' text is shown without escaping `|` codes (pre-existing, dev-only window)

- **Severity:** nit
- **Area:** Security
- **Where:** `NeedRoll/UI/DropTalk.lua:154-156` (`drop.npcName`, `drop.instanceName`), `:185-186` and `:220-226` (quest `title`, `giverName`, `zone`), `:306` (raw `entry.text` in the tooltip); the values come from `Core/Drops.lua:286-297` (`DecodeKill`) and `DecodeQuest`
- **Status:** left as is: deferred to a `Core/Drops.lua` follow-up (the coordinator's call in round 2). The fix belongs in the decoder, which is outside this group, and the brief requires identical behaviour.

**What's wrong.** Names and titles decoded from other players' addon
messages go straight into `SetText` and `GameTooltip:AddLine`. Nothing in
`Core/Drops.lua` strips or doubles `|` (grep for `"|"`/`||`/escape found
nothing).

**Why it matters.** A crafted D2 or Q1 message with `|T...|t`, `|H...|h` or
`|c` in the NPC or quest name would draw a texture, a fake link or colours
in Mike's `/nr droptalk` window. The window is dev-only (`.pkgmeta` ignores
DropTalk.lua), so players aren't exposed through it. The same decoded fields
may reach shipped UI; that is outside this review's files and was not
checked.

**Evidence.** The lines quoted above. This change refactors these lines
(`MessageRows`, `DropRows`, `NewQuestRows`) but does not alter what they show.

**Fix.** Cross-module: in `Core/Drops.lua`'s decoders, reject or escape `|`
in free-text fields (`text:gsub("|", "||")`). Escaping at decode covers
every screen that shows them.

### R10 · `CLASS_ICON_TCOORDS` is now indexed without a nil guard

- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/UI/IconDebug.lua:327-331`
- **Status:** fixed after round 2 (`CLASS_ICON_TCOORDS or {}`)

**What's wrong.** Round 2 removed the local `CLASS_TCOORDS` table and both
fallbacks, and now indexes the global directly:

```lua
-- CLASS_ICON_TCOORDS is FrameXML's table of each class's square on these sheets.
...
local coords = CLASS_ICON_TCOORDS[class.token]
```

**Why it matters.** IconDebug.lua ships, and `/nr icondebug` works in
releases. If Forever's FrameXML doesn't define `CLASS_ICON_TCOORDS` at the
time the page is built, `IconDebug:Build` stops with "attempt to index
global 'CLASS_ICON_TCOORDS' (a nil value)", partway through `BuildContent`.
The window is then never finished, and every later `/nr icondebug` hits
`self.frame` set but half built. The shipped `Theme.lua:862` and `:907` still
treat the same global as possibly missing ("FrameXML's CLASS_ICON_TCOORDS,
for a client that lacks the global"), so the addon now says two different
things about one global.

**Evidence.**
- Global tables are in none of Ketho's `forever` lists (grepped GlobalAPI.lua, FrameXML.lua, WidgetAPI.lua, Templates.lua, Mixins.lua; no `CLASS_ICON_TCOORDS`). The rule for this review is to accept a global table only when the code nil-guards it.
- `tests/smoke/wow.lua:1038` defines it, which is why every smoke run passes.
- That modern FrameXML has it is likely (retail `Constants.lua`), but this is inference.

**Fix.** One guard keeps the "no coords" label meaningful and costs nothing:

```lua
local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class.token]
```

Or confirm in game (`/dump CLASS_ICON_TCOORDS ~= nil`), say so in the
comment, and drop the guard in `Theme.lua` in the same follow-up. Theme.lua
is outside this group, so that half is cross-module.

### R11 · The packaged run never types `/nr loot fished`; release safety rests on a trace through the code

- **Severity:** nit
- **Area:** WoW API (smoke tests)
- **Where:** `tests/smoke/modules/UI-DevKit.lua:64-68`; `/nr loot fished` is only typed in `tests/smoke/scenarios.lua:1076-1082` (`dev slash commands`, marked dev)
- **Status:** left as is (traced in round 2)

**What's wrong.** The release test checks that `ns.DevKit.ListWindow` and
`ns.FishedWindow` are absent, but nothing runs the command a player could
still type in a release.

**Why it matters.** The safety of `/nr loot fished` in a release depends on
`Core/Init.lua:476` (`cmd == "loot" and ns.LootLog.available`) staying in
step with `Core/LootLog.lua:34-36`. If someone moves `available = true` out of
the debug block, or drops the guard, `ns.FishedWindow:Toggle()` would hit a
nil global in a release, and no test would catch it. Today the trace shows it
is safe (see Security).

**Fix.** In the release test, add
`SlashCmdList.NEEDROLL("loot fished")` (and `"loot fish"`). The runner already
fails a scenario on any error. Assert that no `NeedRollFished` frame exists
afterwards.

### R12 · The same `Restoring` helper is copied into seven test files; one test line runs over 120 characters

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `tests/smoke/modules/UI-{DevKit,DropTalk,Fished,FrameDebug,IconBrowser,IconDebug,SoundTest}.lua` (each defines the same 5-line `Restoring`); `UI-DevKit.lua:24` (121 characters, luacheck)
- **Status:** fixed at integration: every copy is now the shared `W.Restoring` (merged in #596)

**What's wrong.** It is the same helper seven times (about 35 lines) and the
same comment seven times. `FindText` and `SameColor` are also copied between
the IconDebug, FrameDebug and DevKit tests.

**Why it matters.** READABLE-CODE.md §6 says two copies of a helper become
one. It also costs lines in a pass whose aim is fewer.

**Fix.** Cross-module follow-up: add `W.Restoring(test, restore)` and
`W.FindText(root, text)` to `tests/smoke/wow.lua` and delete the copies. For
now, wrap the long line at `UI-DevKit.lua:24`.

## Area notes

### Readability

I checked the rules in READABLE-CODE.md against every changed function.
- Names: the single-letter and short names are gone (`w`/`h`/`a`/`b`/`to`/`k`/`s`/`n`/`d`/`q`/`fs`/`obj`), and all the new names are full words. The only two leftovers are R2 and R5.
- Function size: DropTalk's 95-line `Rows`, FontDebug's 70-line `Update`, and IconDebug's 160-line `BuildContent` are each split into named pieces under about 40 lines.
- Guard clauses: used in `MessageRows`, `WhoLine`, `AddLevelBadge`, `RowClick` and `Preview`.
- Lua 5.1 traps: none. `kitID and "" or ...` is fine because `""` is truthy. `UnitLevel` is never nil, so `isPlayer and UnitLevel("player") or SAMPLE_LEVEL` holds. `#t` is only used on sequences. `AtlasFromScheme`'s `gsub` replacement strings are class tokens and fixed profession names, so a `%` can't occur.
- Comments: FrameDebug's "at full size" comment over code that scales to 0.8 is fixed to "at 0.8 scale". No change narration. The Painter comment explains why each window has its own painter.
- `Painter:Section` builds a heading as well as registering its colour. I accepted it, because a heading is the painter's main client.
- Formatting: 4-space indents, LF, lines ≤ 120 (luacheck reports no long lines after).

### WoW API

I checked the `forever` branch lists from Ketho's BlizzardInterfaceResources
(GlobalAPI.lua, WidgetAPI.lua, FrameXML.lua, Templates.lua), downloaded and
grepped on 2026-10-17.

| Call / object | In `forever` lists | Where looked / note |
| --- | --- | --- |
| `GetNumClasses` (fallback removed) | yes | GlobalAPI.lua:5637 |
| `GetClassInfo` (fallback and guard removed in IconDebug and DropTalk) | yes | GlobalAPI.lua:5341 |
| `C_Spell.GetSpellTexture` (existence guard removed) | yes | GlobalAPI.lua:3958 |
| `SetPortraitTextureFromCreatureDisplayID` (EJ default texture fallback removed) | yes | GlobalAPI.lua:6489 |
| `BreakUpLargeNumbers` (guard removed) | yes | GlobalAPI.lua:73 |
| `C_Texture.GetAtlasInfo` (guards removed in LineDump) | yes | GlobalAPI.lua |
| `SetPortraitTexture`, `UnitLevel`, `PlaySound`, `Ambiguate`, `IsModifiedClick`, `strtrim`, `tinsert`, `date`, `CreateFrame` | yes | GlobalAPI.lua |
| `C_Item.GetItemInfo`, `GetItemInfoInstant`, `GetItemIconByID`, `RequestLoadItemDataByID` | yes | GlobalAPI.lua |
| `HandleModifiedItemClick`, `CreateColor` | yes | FrameXML.lua |
| Templates `InsetFrameTemplate`, `BasicFrameTemplateWithInset`, `GameTooltipTemplate` | yes | Templates.lua |
| Widget methods `SetGradient`, `AddMaskTexture`, `CreateMaskTexture`, `SetHorizTile`, `SetVertTile`, `SetAtlas`, `GetAtlas`, `SetTexCoord`, `SetColorTexture`, `SetVertexColor`, `SetScrollChild`, `SetVerticalScroll`, `SetTextInsets`, `SetFontObject`, `SetToplevel`, `SetClampedToScreen` | yes | WidgetAPI.lua |
| `GameTooltip:SetItemByID` | inferred | not in WidgetAPI.lua (tooltip methods aren't listed there); unchanged call |
| `SOUNDKIT`, `CLASS_ICON_TCOORDS`, `UISpecialFrames` (global tables) | inferred | not in any list; all nil-guarded or standard FrameXML; unchanged use |

No new game calls, events, atlases or `Enum`s are introduced; the change only
removes guards. All three removed fallbacks named in the brief are in the
`forever` list. Smoke stand-ins: the tests define no new game functions;
`tests/smoke/wow.lua` already has every call used (all three modes pass).

- Async item data: `List:LoadItem` keeps the old pattern. `ns.Items:Load`, called once per item while a load is in flight, refreshes when the item arrives. There is no polling.
- `QuestLines`'s `C_Item.RequestLoadItemDataByID` runs on every refresh until the item is cached. This is unchanged.
- Events: only `ns:On("PLAYER_LOGIN")` in FontDebug, unchanged.
- Secret values: none touched.
- Combat/taint: no protected frames or secure templates.
- New globals: none (`luac -l` shows no SETGLOBAL). Frame global names are unchanged (`NeedRollFished`, `NeedRollDropTalk`, `NeedRollIconDebug`, `NeedRollFrameDebug`, `NeedRollSoundTest`, `NeedRollLineDump`, `NeedRollFontDebugTip/Wheel`).
- 60-upvalue limit: `luac5.1 -p` is clean.

Dev-only vs shipped:
- `.pkgmeta`, `UI.xml` and the TOC are untouched. The `--@debug@` blocks in IconDebug.lua (`:863-865`, `:884-901`) and FrameDebug.lua (`:282-681`) wrap the same code as before.
- `ns.DevKit` is defined outside any debug block in shipped IconDebug.lua. Shipped FrameDebug (window part) and shipped Fished use it. Dev-only SoundTest and DropTalk use it.
- No shipped code reads anything defined in a stripped block. The packaged smoke run loads 178 files and passes, including the non-dev FrameDebug and IconDebug scenarios.

The Ring of Law pin preview, compared layer by layer:
- Before, the cell drew `back` BACKGROUND -1, `portrait` BACKGROUND 0 and `ring` ARTWORK on a `pinLook.size` frame.
- `ns.UI.MiniPin` (`UI/Overview.lua:57-82`) draws `back` ARTWORK -1, `portrait` ARTWORK 0 and `ring` OVERLAY.
- The portrait is still `size * PIN_PORTRAIT / PIN_SIZE` = 29 px at 40 px, with the same TempPortraitAlphaMask, the same black disc and the same `EJ_TEXTURES` ring and `PIN_RING` coords.
- The order inside the pin frame is the same (back < portrait < ring). Nothing else draws in that frame, and the cell's hover wash belongs to the parent button, which always draws under a child frame.
- `ns.UI.SetPinIcon` is called the same way.
- It looks the same. That is inferred from the code; there is no screenshot or test (R7).

Style guide: nothing visible changes. Every size, colour and position is
carried over (checked: `LIST_TOP` 100, `LIST_ROW_H` 36, `LIST_INSET` 4,
`BAR_ROOM` 10, rows 1 px in, status at -44, empty note centered, LineDump
rows `ceil(14 / 5) = 3` as before). No `docs/STYLE-GUIDE.md` update is
needed, and that file doesn't mention these windows.

Round 2 readability:
- `LineDump`'s `paint` field: a style that is a single texture across the whole width gives `paint(tex, vertical)`, and `Parts` (`LineDump.lua:139-144`) wraps it as `{ { tex, 0, 1 } }`. Every style draws the same textures in the same layer as before (checked all 14).
- IconBrowser's `FillHeader` is folded back into `FillRow` (12 lines, one caller).
- `LineDump:Toggle` returns `self.frame:SetShown(...)` as a one-line guard.
- The comment at `IconBrowser.lua:130` writes `{ categoryIndex, firstIcon = ... }` for `{ categoryIndex = ..., firstIcon = ... }`. That is close enough, and not a finding.

### Redundant code

Compared against:
- `NeedRoll/UI/Theme.lua`'s 41 `T:` functions, in particular `T:FitAtlas` (it shows a missing atlas blank, while the kit's version shows a red square and reports it: different behaviour, so keeping both is justified) and `T:Dialog` (an in-pane modal, not a movable window, so it can't replace `kit.Window`).
- `T:Fill`, `T:LabelToggle`, `T:ScrollView`, `T:ScrollBar`, `T:WheelScroll`, `T:ScrollStart` and `T:GlideTo`, all of which ListWindow reuses rather than copying.
- `T:ClassToken` (it upper-cases a name, which is a different job from `ClassCase`).
- `ns.Items:Load` (reused by `List:LoadItem`).
- `CopyTable` (FrameXML, a deep copy; `DropTalk`'s three-line shallow `Copy` is fine).

`ListWindow` replaces two near-identical copies of window, pane, tabs, row
pool, wheel, scroll bar, `Fits`/`MaxOffset`/`Draw` and item loading. That is
the main saving.

Remaining duplication and dead code:
- R3: `SCROLL_TOP` copied in two files.
- R4: dead lines.
- R8: the kit's placement.
- `WhoLine` and `MessageRows` both compute `msg.text:sub(1, 3)`. This is trivial and left as is.
- No `OnUpdate` is added. FontDebug's watcher already existed and is throttled to `WATCH_INTERVAL`.
- No debug prints.

### Security

Untrusted input touched: the DropTalk window shows the drop-sharing log,
which holds other players' addon messages (`ns.db.dropTalk`) and the saved
drops and quests built from them.
- The change doesn't alter parsing. It calls the same `ns.Drops:DecodeDrops`/`DecodeQuest`, which use anchored patterns and reject an empty kill (`Core/Drops.lua:299-308` returns nil when `#drops == 0`). So `MessageRows` switching from `drops[1]` to `drops` as its test is equivalent.
- Nothing sends, nothing writes SavedVariables beyond what FontDebug already saved (`fontEdit`/`iconEdit`, same keys and shapes), and there is no `loadstring`/`RunScript`/`setfenv`.
- R9: escaping of `|` codes is missing (pre-existing).

Names in output:
- `SenderName` (Ambiguate) and `saved.by` appear only in the dev-only DropTalk window. DropTalk.lua is excluded from release zips by `.pkgmeta`.
- The test fixtures use made-up names (`Someone-Realm`, `Finder-Realm`, and others) under `tests/`, which `.pkgmeta` ignores. No real character names.
- `NeedRoll/Credits.txt` is not touched.

### Round 2 packaging and release-path trace

- **UI.xml:** `DevKit.lua` loads after `RecipeBand.lua` and before `IconDebug.lua`, outside any debug block. `Fished.lua` loads in the second `<!--@debug@-->` block with SoundTest, DropTalk and LineDump. Every user of `ns.DevKit` (IconDebug, FrameDebug, Fished, SoundTest, DropTalk) now loads after it and caches `local kit = ns.DevKit`.
- **.pkgmeta:** `NeedRoll/UI/Fished.lua` is ignored. `DevKit.lua` ships, as it must, because shipped IconDebug and FrameDebug use it.
- **What is left in a release:** `DevKit.lua` loses lines 226-334 (`List`, `ListWindow`, `LIST_ROW_H`). No shipped file reads `kit.ListWindow` or `kit.LIST_ROW_H`: grep finds only `Fished.lua:117` and `DropTalk.lua:367`, both dev-only files.
- **`/nr loot fished` in a release:**
  - `Core/Init.lua:476` checks `cmd == "loot" and ns.LootLog.available`. `ns.LootLog = { available = false }` is at `Core/LootLog.lua:34`, and `available = true` is at `:36`, inside the `--@debug@` block that runs to `:627`.
  - So in a release the whole `loot` branch, including `ns.FishedWindow:Toggle()` at `:486`, is skipped.
  - The only other reference, `if ns.FishedWindow then ns.FishedWindow:Refresh() end` at `LootLog.lua:442`, is inside the same debug block and guarded anyway.
- **The packaged test** asserts both `ns.DevKit.ListWindow` and `ns.FishedWindow` are nil, and passes. R11 asks for the command itself to be run too.
- **Merge note:** UI.xml and .pkgmeta are shared by every group. Merge this group's two-line UI.xml change and one-line .pkgmeta change by hand if another group touched them.

## Round history

- 2026-10-17 · `c0e5c79` + uncommitted · Changes needed · opened R1-R9 (2 should fix, 7 nits), closed none.
- 2026-10-17 · `c0e5c79` + uncommitted (round 2) · Changes needed · closed R1-R8 (fixed); R9 left as is (deferred to a Drops follow-up); opened R10 (should fix), R11 and R12 (nits).
- 2026-10-17, after round 2: R10 fixed with a nil guard, the 121-character test line split, R11 left as traced, R12 handled when merging (`W.Restoring`).
