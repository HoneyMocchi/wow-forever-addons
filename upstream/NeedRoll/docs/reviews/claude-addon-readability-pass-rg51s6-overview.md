# Review: Readability pass, Overview group (`NeedRoll/UI/Overview.lua` and its module smoke tests)

| | |
| --- | --- |
| Branch | `rp-overview` worktree, the Overview group of `claude/addon-readability-pass-rg51s6` (PR not opened yet) |
| Commit reviewed | `c0e5c79` plus uncommitted changes (`NeedRoll/UI/Overview.lua`, new `tests/smoke/modules/UI-Overview.lua`), round 3 working tree |
| Date | 2026-10-18 |
| Round | 3 (last) |
| Verdict | **Ready** (0 blocking, 0 should fix, 0 nits open; R3 left as is for Mike's decision) |
| Needs | `/reload` (Lua only; no new files in the `.toc`, no SavedVariables change) |

## What the change does

Nothing a player should see changes. `ns.UI.CreateOverview` was one 2,295-line function at
Lua 5.1's 60-upvalue limit (59). Most of its widget building and drawing is now file-level
functions: map card, entrance row, title parts, chain arrows, stat boxes, map view and mouse,
boss pins, quest markers, level links and tabs, zone-wide quest overlay, route drawing and
editing, `DrawMap`, page-link click and tooltip, and the page line builders. That leaves
`CreateOverview` at 391 lines and 31 upvalues. Repeated code became one helper each
(`AnyVersion`, `ShowTooltip`/`HideTooltip`, `AddPortrait`/`SetPinFace`, `QuarterDisc`,
`OpenQuestPage`/`OpenBossPage`, `DropSpotLink`, `LoadTiles`/`PlaceTiles`, `CHAT_PREFIX`). The
fallbacks to the old quest log globals (`QuestLog_*`, `GetQuestLogIndexByID`, `QuestLogFrame`,
the global `IsQuestFlaggedCompleted`) are gone, along with the guards on calls Ketho's
`forever` lists include. The new module test file adds 10 scenarios.

## Scope

- `NeedRoll/UI/Overview.lua`. Round 1: 3571 → 3565 lines (code 2931 → 2884, comments
  501 → 509, blank lines 139 → 172). Round 2: 3560 lines (code 2860, comments 518, blank
  lines 182). Read in full in round 1. In round 2, every function the round 1 → round 2 diff
  touched was re-read in full (958 diff lines, from the round 1 file rebuilt out of the saved
  round 1 diff).
- `tests/smoke/modules/UI-Overview.lua`: new. 481 lines and 10 scenarios in round 1; 522
  lines and 11 scenarios in round 2 (adds `RestoringWindow` and the style-switch scenario),
  plus a stand-in for `C_Map.GetAreaInfo`. Read in full both rounds. At integration the local `Restoring`
  became the shared `W.Restoring` (#596), and `RestoringWindow` now starts each test with the
  map closed: the main window's map key test (#604) leaves it open, which broke two of these.
- Read for context, not changed: `NeedRoll/UI/MainFrame.lua` (skin swap 1291-1335,
  `WithGameMap` 2341, world map hooks 2326-2336), `NeedRoll/UI/Lists.lua` (map-floor callers
  1915-2000), `tests/smoke/run.lua`, `tests/smoke/wow.lua` stand-ins, `tools/locales.py`.
- Generated files: none touched (`NeedRoll/Data/`, `NeedRoll/Locales/` unchanged).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on both files | passed |
| `luacheck --std lua51 -q --codes` W11 (global names read or set), HEAD vs working tree | no new names. Gone: `GetQuestLogIndexByID`, `IsQuestFlaggedCompleted`, `QuestLogFrame`, `QuestLog_OpenToQuest`, `QuestLog_SetSelection`, `QuestLog_Update`, `ShowUIPanel` |
| `luacheck --no-global -q` | 43 warnings at HEAD, 1 now: `Overview.lua:1995` line too long (181 > 120). That line is an `L["..."]` literal and can't be wrapped without changing the key. The test file is clean |
| `tests/smoke/check.sh` | passed in all three modes (dev, packaged, secret), every `UI/Overview:` scenario `ok` |
| `python3 tools/locales.py --check` | passed |
| `python3 tools/translations.py` | ran clean (exit 0; its usual notes about stale zhTW keys, unrelated) |
| `L["..."]` keys | same 122 distinct keys before and after. First-appearance order inside Overview.lua moved for `Click to open this quest`, `Overview` and `Click to pin on your map`. `enUS.lua` is unaffected because `locales.py` writes each key under the first file (sorted path order) that uses it, and all three appear first in an earlier file. `--check` passing confirms it |
| Public names (all of `NeedRoll/`, `tests/`, `docs/API.md`) | only `ns.UI.DrawZoneQuests` left `ns` (now a local). Nothing else in the repo calls it. Every other `ns.UI.*` and `pane.*` name other files use is kept, including `pane.view` for `scenarios.lua:1130,1211,1223` |
| Probe of the map-floor bug (R1) | a throwaway scenario run through a copy of `run.lua` in the scratchpad (not in the repo). It printed `first skin true true` then `back true true false` (map visible, `pane.floor` set, `ns.UI.MapFloorShown()` false) |
| Scraper tests | not run (no scraper change) |

Round 3 checks (rerun on the round 3 working tree):

| Check | Result |
| --- | --- |
| `luac5.1 -p` on both files | passed |
| W11 vs HEAD | the same single new name as round 2 (`issecretvalue`, the R4 fix); nothing else |
| `luacheck --no-global -q` | 1 warning, the unwrappable `L[...]` line (now `Overview.lua:2059`); test file clean |
| `tests/smoke/check.sh` | passed in all three modes, 12 `UI/Overview:` scenarios `ok` in each |
| `python3 tools/locales.py --check`, `tools/translations.py` | passed / clean |
| `L["..."]` keys | same 122 distinct keys as base |
| Size | 3607 lines: code 2892 (base 2931), comments 526 (501), blank lines 189 (139). The growth is comments and blank lines around the split-out functions; I found no further cut that costs no clarity |
| Visible-region snapshot, base vs round 3 | The same probe as round 2: 766 page states and 692 hover states, both window styles. **Identical** apart from the badge quarter-disc `_texCoord` lines, plus the view's internal pool list `areaDots`, which no longer exists (the dots are drawn the same: same regions, rects and textures). The tooltip text of all 692 hovers is identical |
| R17 test without the fix | fails against a scratch copy with the `issecretvalue` line removed; passes now |

Round 2 checks (rerun on the round 2 working tree):

| Check | Result |
| --- | --- |
| `luac5.1 -p` on both files | passed |
| W11 vs HEAD | gains one name: `issecretvalue`, read on purpose by the R4 fix. It is a Forever game global (`GlobalAPI.lua:6874`), with the same nil-guard as `Core/Tooltip.lua:196` and four other files. It is not a local read before its declaration. Nothing else new |
| `luacheck --no-global -q` | 1 warning, the same unwrappable `L[...]` line (now `Overview.lua:2027`). The test file is clean |
| `tests/smoke/check.sh` | passed in all three modes, 11 `UI/Overview:` scenarios `ok` in each |
| `python3 tools/locales.py --check`, `tools/translations.py` | passed / clean |
| `L["..."]` keys | same 122 distinct keys as base |
| Visible-region snapshot, base vs round 2 | My own probe, run from the scratchpad through copies of `run.lua` (one loading a copy of the addon with base `Overview.lua`). It walked every visible region under `ui.overview` and recorded type, rect, texture, atlas, colour, alpha, text, font and layer. It covered both window styles and every dungeon and raid Overview, every map level and every dungeon quest page: 766 states. On every map level it also hovered each shown boss pin, quest marker and zone badge icon, recording the routes, areas and wash drawn plus the tooltip lines: 692 hover states, 12,730 route and area line regions. **Identical**, apart from 24 lines: `_texCoord` no longer set on the badge's two quarter-disc colour textures. The tooltip text of all 692 hovers is identical too |
| R1 test at base | fails at base (`UI-Overview.lua:368: after a style switch the map's floor isn't known while it shows`), passes now, both with `--only "style switch"` |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | WoW API (bug) | `Overview.lua:3264-3268` | Map-floor answers come from a parked window after a style switch | fixed in round 2 (uncommitted) |
| R2 | should fix | WoW API | `Overview.lua:437-440` | `QuestMapFrame_OpenToQuestDetails` guard removed on evidence that can't prove it | fixed in round 2 (uncommitted) |
| R3 | should fix | WoW API | `Overview.lua:505-513` | `Money` calls a global missing from Forever's lists; its fallback is the live path, not dead | left as is: Mike decides (behaviour change); comment corrected |
| R4 | should fix | WoW API (secret values) | `Overview.lua:363-368` | `Chain.Name` passes a possibly secret quest title into string building and measuring | fixed in round 2 (uncommitted); test added in round 3 (R17) |
| R5 | should fix | Readability | `Overview.lua:1672-1793` | `DrawRoutes`: 122 lines, 7 levels deep, four closures | fixed in round 2 (uncommitted) |
| R6 | should fix | Readability | `Overview.lua:1520-1584, 3298-3302` | Title-block spacing numbers repeated in four places with no names | fixed in round 2 (uncommitted) |
| R7 | should fix | Readability | `Overview.lua:999-1005, 1112, 1186-1233` | Zone badge geometry written as bare 22/6/28/8/10/2/5/12 | fixed in round 2 (uncommitted) |
| R8 | should fix | Tests | `UI-Overview.lua:225-480` | Five UI tests don't restore window state when they fail; quest side never restored | fixed in round 2 (uncommitted); gap closed in round 3 (R20) |
| R9 | should fix | Redundant code | `Overview.lua` (whole file) | File is only 6 lines shorter: list of cuts | fixed in round 2 (uncommitted) |
| R10 | nit | Readability | `Overview.lua:764, 1499, 1815-1880, 3140, 3329, 3449-3453, 3525` | Mental-mapping names: `k`/`n`, `fs`, `li`, `nxt`, `v` | fixed in round 2 (uncommitted) |
| R11 | nit | Readability (consistency) | `Overview.lua:91-102` and 10 call sites | `HideTooltip` exists but half the handlers still call `GameTooltip:Hide()` | fixed in round 2 (uncommitted) |
| R12 | nit | Redundant code | `Overview.lua:1335, 1979; 2325-2327, 2496-2498` | Tile creation and "show this level" each written twice | fixed in round 2 (uncommitted) |
| R13 | nit | Redundant code | `Overview.lua:3429-3432` | The level line is rebuilt on every scroll frame | fixed in round 2 (uncommitted) |
| R14 | nit | Readability | `Overview.lua:3419` vs `3308` | Overview starts drawing at bare `50`, while the scroll limit assumes `HEADER_HEIGHT` (64) | fixed in round 2 (uncommitted); comment nit in R21 |
| R15 | nit | Readability | `Overview.lua:531-556, 2788-2807` | `ZoneMap` nesting and bare map IDs; a comment repeated in `StartText` | fixed in round 2 (uncommitted) |
| R16 | should fix | Readability | `Overview.lua:1510-1617, 2204-2307` | `CreateTitleParts` (108 lines) and `NewQuestMarker` (104 lines) still do several jobs each | fixed in round 3 (uncommitted) |
| R17 | should fix | Tests | `UI-Overview.lua` | The R4 secret-title fix has no scenario | fixed in round 3 (uncommitted) |
| R18 | nit | Readability (formatting) | `Overview.lua:100, 176, 1285, 1827, 2375, 2931; 2627, 2664` | Functions folded onto one line to save lines; `return X and Y()` used as control flow | fixed in round 3 (uncommitted) |
| R19 | nit | Redundant code | `Overview.lua:1688-1730, 1155-1165` and the pool tails | Get-or-create still hand-written for lines; "hide the rest of the pool" written about ten times | fixed in round 3 (uncommitted) |
| R20 | nit | Tests | `UI-Overview.lua:68-93, 350-372` | Style-switch test: wrong precondition comment, an assert that could pass empty; `ui.places` not restored | fixed in round 3 (uncommitted) |
| R21 | nit | Readability | `Overview.lua:1619-1623, 3298-3300` | A derived "14px" written into a comment; a ragged comment block over `ClampCenter` | fixed in round 3 (uncommitted) |

### R1 · Map-floor answers come from a parked window after a style switch
- **Severity:** should fix (a bug from before this change; Mike's direction for this pass is to fix pre-existing bugs when found)
- **Area:** WoW API (bug)
- **Where:** `NeedRoll/UI/Overview.lua:3264-3268`; the cause is `NeedRoll/UI/MainFrame.lua:1319-1321`; callers are `NeedRoll/UI/Lists.lua:1920, 1983-1986, 1997-1998`
- **Status:** fixed in round 2 (uncommitted). `Overview.lua:1930-1939` defines the three functions once at file level and reads `ns.UI.overview`. While a style switch is half done `UI.overview` is nil, so they answer false. Verified: the new scenario (`UI-Overview.lua:350-372`) fails against base and passes now, both with `--only`. `Lists.lua`'s existence guards are now dead (cross-module)

**What's wrong.** `CreateOverview` defines the three functions the Encounters list asks,
closing over that call's `pane` and `view`:

```lua
function ns.UI.MapFloorShown() return pane.floor ~= nil and view:IsVisible() end
function ns.UI.MapFloorPin(enc) return ns.UI.MapFloorShown() and pane.floor[enc] or nil end
function ns.UI.OnMapFloor(enc) return ns.UI.MapFloorPin(enc) ~= nil end
```

`CreateOverview` runs once per window style. `UI:SetSkin` keeps each style's built widgets
and, when you switch back to one already built, only puts them back
(`for key, widget in pairs(saved) do self[key] = widget end`). It never rebinds these
functions. They keep answering for the last window built, which is now hidden.

**Why it matters.** Open the window in one style, switch to the other in Settings, switch
back, then open a dungeon's map. The Encounters list no longer lights the bosses pinned on
the shown floor and shows no mini pins: `MapFloorShown()` is false while the map is on
screen.

**Evidence.** Probe (see Checks): after `SetSkin(other)` then `SetSkin(first)`, with
`ShowFloor(1)`, `ui.overview.mapView:IsVisible()` was `true` and `ui.overview.floor` was set,
but `ns.UI.MapFloorShown()` returned `false`. The new test steps around this on purpose
(`UI-Overview.lua:292-294`: "pane.floor, not ns.UI.MapFloorShown").

**Fix.** Define the three once, at file level (after `SetFloor`), reading the window on
screen when called:

```lua
-- For the Encounters list: whether the window's map shows a floor, and the
-- pin { encounter, x, y, display ID or icon } of a boss on it, for its mini
-- pin. Read through ns.UI.overview: each window style builds its own pane,
-- and switching style back puts the earlier one on screen again.
function ns.UI.MapFloorShown()
    local pane = ns.UI.overview
    return pane ~= nil and pane.floor ~= nil and pane.mapView:IsVisible()
end
function ns.UI.MapFloorPin(enc) return ns.UI.MapFloorShown() and ns.UI.overview.floor[enc] or nil end
function ns.UI.OnMapFloor(enc) return ns.UI.MapFloorPin(enc) ~= nil end
```

Add a test that switches style and back with `Restoring` (restore the style in the restore
step), opens a map, and asserts `ns.UI.MapFloorShown()` and `ns.UI.MapFloorPin(enc)` for a
pinned boss. Replace the work-around comment at `UI-Overview.lua:292-294` with that assert.
Cross-module: the `ns.UI.MapFloorPin and ...` and `not ns.UI.OnMapFloor` guards in
`Lists.lua:1920, 1983, 1997` become dead once these exist from file load. List them for the
Lists group.

### R2 · `QuestMapFrame_OpenToQuestDetails` guard removed on evidence that can't prove it
- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/UI/Overview.lua:437-440` (`Chain.OpenInLog`)
- **Status:** fixed in round 2 (uncommitted). `Overview.lua:442-447`: `if not (QuestMapFrame_OpenToQuestDetails and C_QuestLog.IsOnQuest(id)) then return end`, with the load-on-demand reason in the comment

**What's wrong.** The old code opened the quest log only when the function existed
(`if QuestMapFrame_OpenToQuestDetails then ... elseif QuestLog_OpenToQuest ...`). The new
code calls it unguarded:

```lua
function Chain.OpenInLog(id)
    if not C_QuestLog.IsOnQuest(id) then return end
    ns.UI:WithGameMap(QuestMapFrame_OpenToQuestDetails, id)
end
```

Dropping the `QuestLog_*` branch is right: none of `QuestLog_OpenToQuest`,
`GetQuestLogIndexByID`, `QuestLogFrame`, `QuestLog_SetSelection` or `QuestLog_Update` is in
any `forever` list. But `QuestMapFrame_OpenToQuestDetails` being in Ketho's `FrameXML.lua`
only shows that some Blizzard addon defines it. That list also includes load-on-demand
addons' functions: `CalendarFrame_OnLoad` (Blizzard_Calendar) and
`AchievementFrame_ToggleAchievementFrame` (Blizzard_AchievementUI) are both in it. So it
doesn't prove the function is defined when the player clicks. The addon itself treats the
world map's addon as one that may load late (`MainFrame.lua:2329-2336`: `HookWorldMap` returns
when `WorldMapFrame` is nil at login and retries on `ADDON_LOADED` "Blizzard_WorldMap").

**Why it matters.** If the quest map's code isn't loaded yet in Forever (the world map not
opened since login), clicking a chain step you have in your log ("Click to open it in your
quest log", subtitle link at `Overview.lua:1591`, or `Chain.Open`) calls nil. The player gets a
Lua error where the old code did nothing. The smoke tests can't see it:
`tests/smoke/wow.lua:1341` always defines the function.

**Evidence.** `grep '"QuestMapFrame_OpenToQuestDetails"' FrameXML.lua` gives one hit (line
3365). `grep '"CalendarFrame_OnLoad"'` and `'"AchievementFrame_ToggleAchievementFrame"'`
also hit, so the list includes load-on-demand code. That the quest map is load-on-demand in
Forever is **inferred** from MainFrame's own handling; not confirmed in game.

**Fix.** Either keep a one-line guard with the reason:

```lua
-- The quest map lives in the world map's Blizzard addon, which may not be
-- loaded until the map is first opened.
if not QuestMapFrame_OpenToQuestDetails then return end
```

or have Mike `/dump QuestMapFrame_OpenToQuestDetails` right after login, before opening
the map. If it's defined, write that game fact in the comment above `Chain.OpenInLog` and
leave it unguarded.

### R3 · `Money` calls a global missing from Forever's lists; its fallback is the live path, not dead
- **Severity:** should fix (needs Mike's go-ahead: it changes what players see)
- **Area:** WoW API
- **Where:** `NeedRoll/UI/Overview.lua:505-513`; same pattern at `NeedRoll/UI/LootGrid.lua:480` (cross-module)
- **Status:** left as is: Mike decides (switching to `C_CurrencyInfo.GetCoinTextureString` changes what players see). The round 2 comment at `Overview.lua:513-515` now states the fact from Ketho's lists correctly

**What's wrong.**

```lua
local function Money(copper)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    ... L["%dg"], L["%ds"], L["%dc"] ...
```

The hand-back says the fallback is dead because "GetCoinTextureString exists in Forever".
Ketho's `forever` lists don't have the global. They only have
`C_CurrencyInfo.GetCoinTextureString` (and `C_CurrencyInfo.GetCoinText`; the FrameXML
`GetMoneyString` is also listed).

**Why it matters.** Going by the lists, a quest page's Rewards and an attunement step's
costs in Forever show the plain fallback "5g 3s" rather than coin icons. The smoke tests
take the other path, because `tests/smoke/wow.lua:1299` defines the old global. That makes
it look as if the icons work. Deleting the "dead" fallback as the hand-back suggests would
give players a Lua error on every quest with a money reward.

**Evidence.** `grep -o '"[A-Za-z_.]*GetCoinTextureString"'` over GlobalAPI.lua, FrameXML.lua
and the other lists gives only `"C_CurrencyInfo.GetCoinTextureString"`.

**Fix.** Mike decides: call `C_CurrencyInfo.GetCoinTextureString(copper)` and drop the
fallback and its three `L` keys (regenerate `enUS.lua` with `tools/locales.py`), together with
`LootGrid.lua:480`'s `ShortCost`. Or keep the text form on purpose and say so in a comment.
Either way, record in the hand-back that the global isn't in Forever.

### R4 · `Chain.Name` passes a possibly secret quest title into string building and measuring
- **Severity:** should fix
- **Area:** WoW API (secret values)
- **Where:** `NeedRoll/UI/Overview.lua:363-368`; used at 494, 1300, 2722, 3111 and in `Chain.Tooltip`
- **Status:** fixed in round 2 (uncommitted). `Overview.lua:364-374`: the scraped names first, in the same order as before (`page.name`, `questNames`, `step.name`). Then the game's title, dropped when `issecretvalue` says it's secret, then `quest <id>`. When the title isn't secret, the result is the same value as base for every input, so nothing shown changes. The snapshot and tooltip comparison (Checks) found no text difference. The fix has no scenario: R17

**What's wrong.** The diff touched this line (it removed the guards). Its last fallback is
the game's quest title, which Forever can return as a secret value:

```lua
return page and page.name or ns.Data.questNames[id] or step and step.name
    or C_QuestLog.GetTitleForQuestID(id) or L["quest %s"]:format(id)
```

The result is formatted into chain rows and the "Step N of a chain..." line. Those go
through `ns.UI.SizeMarkers` (`gsub`) and `TextHeight` (`GetStringHeight`, then `math.ceil`).

**Why it matters.** It only bites for a chain step missing from the scraped data
(`questNames`, `chainSteps`). Then operating on a secret string, or doing math on a height
measured from one, throws "attempt to perform an operation on a secret value" and the quest
page fails to draw. The `--secret` smoke run doesn't reach this fallback because the data
names every step it opens. `wow.lua:1536` does return the title as `MaybeSecret`.

**Evidence.** Lines read. The addon's existing guard pattern is
`issecretvalue ~= nil and issecretvalue(value)` (`Core/Tooltip.lua:194-196`,
`UI/MainFrame.lua:276-278`). That the title is secret at this call in Forever is per the
review brief's list of secret values; not tested in game.

**Fix.**

```lua
-- The game's own title can be secret in Forever (unusable in text we
-- build or measure); then it reads "quest <id>".
local title = C_QuestLog.GetTitleForQuestID(id)
if title ~= nil and issecretvalue and issecretvalue(title) then title = nil end
```

### R5 · `DrawRoutes`: 122 lines, 7 levels deep, four closures
- **Severity:** should fix
- **Area:** Readability
- **Where:** `NeedRoll/UI/Overview.lua:1672-1793`
- **Status:** fixed in round 2 (uncommitted). `DrawRoutes` is 13 lines and calls `RouteSegment`, `SoftSegment`, `Arrowhead`, `FillArea`, `DrawArea`, `DrawLoopArrows`, `DrawEndArrows` and `DrawRoute`, with the counters on `view` (`routeUsed`, `areaUsed`). No function in the file now nests deeper than 6 (`FloorsByArt`'s four plain loops). I checked the geometry by hand: the new last point's `PointXY(patrol, point - 1)` is the old `patrol[k * 2 - 3]` / `[k * 2 - 2]`, and the midpoint is still inserted y then x. The hover snapshot (12,730 route and area lines) is identical

**What's wrong.** `DrawRoutes` reuses two pools (route lines and soft area lines). It also
holds four inner functions (`SoftSegment`, `Segment`, `Arrowhead`, `FillArea`) and draws
three kinds of shape (filled areas, loops with arrows, back-and-forth lines with end
arrows). Its deepest line (1764-1765, the end arrowheads) is 7 indents in:
`for patrol → else → if open → if #path >= 2 → for tip`. `docs/READABLE-CODE.md` §3 and §4
ask for a split past about 60 lines and at three levels.

**Why it matters.** It's the hardest function in the file to follow. A newcomer changing
how arrows space out has to keep two counters (`used`, `soft`) and five closures in their
head.

**Evidence.** Depth and length measured over the file (only `DrawRoutes` reaches depth 7;
`FloorsByArt` reaches 6).

**Fix.** Put the counters on `view` (`view.routeUsed`, `view.areaUsed`) and make the
helpers file-level, each taking `view`: `RouteSegment`, `SoftSegment`, `Arrowhead`,
`FillArea`. Pull the two arrow loops into `DrawLoopArrows(view, path)` and
`DrawEndArrows(view, path)`, and the area branch into `DrawArea(view, path)`. The loop over
patrols then reads as three calls, and the hide-unused tail as one small `HideUnusedRoutes`.

### R6 · Title-block spacing numbers repeated in four places with no names
- **Severity:** should fix
- **Area:** Readability (searchable names)
- **Where:** `NeedRoll/UI/Overview.lua:1520-1521, 1547, 1551, 1561, 1565, 1579, 1584, 3299-3301`
- **Status:** fixed in round 2 (uncommitted). The `TITLE` table and `FontSize`. Values checked against base: 15/18 title top, 5 + 4 gaps (9 in the badge offset), 12 under the level line, 16/10 font fallbacks

**What's wrong.** One layout (title, 5px gap, subtitle, 4px gap, level line) is written as
bare numbers in four places that must agree:

```lua
pane.sub:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -5)                      -- 1579
pane.levelLine:SetPoint("TOPLEFT", pane.sub, "BOTTOMLEFT", 0, -4)                  -- 1584
local badgeScale = (titleSize + 5 + subSize + 4 + levelSize) / TITLE_BADGE         -- 1551
badge:SetPoint(..., -(9 + subSize + levelSize) / 2 / badgeScale)                   -- 1561  (9 = 5 + 4)
self.title:SetPoint("TOPLEFT", left, isInstance and -15 or -18)                    -- 1565
return math.ceil(18 + self.title:GetStringHeight() + 5 + (sub or 10) + 4 + (level or 10) + 12)  -- 3301
```

The font-size fallbacks `or 16` and `or 10` (1521, 1547, 3301) repeat too.

**Why it matters.** Change the subtitle gap in one place and the class badge goes
off-centre, or a quest page's first line overlaps the level line. Nothing links them, and a
grep for the gap finds nothing.

**Fix.** Name them next to `TITLE_BADGE`: `QUEST_TITLE_TOP = 18`,
`INSTANCE_TITLE_TOP = 15`, `SUB_GAP = 5`, `LEVEL_LINE_GAP = 4`, `QUEST_PAGE_GAP = 12`. Use
`SUB_GAP + LEVEL_LINE_GAP` for the 9, and one `FontSize(fontString, fallback)` helper for
`select(2, fs:GetFont()) or N`.

### R7 · Zone badge geometry written as bare 22/6/28/8/10/2/5/12
- **Severity:** should fix
- **Area:** Readability (searchable names)
- **Where:** `NeedRoll/UI/Overview.lua:999, 1003, 1005, 1112, 1186-1188, 1214-1233`
- **Status:** fixed in round 2 (uncommitted). The `BADGE` table. Width, height and icon offsets work out to the same numbers as base; the snapshot is identical

**What's wrong.** The badge's icon size (22), gap (6), step (28 = 22 + 6), padding
(8/10 sideways, 5 up and down), line width (2) and bottom-right corner radius (12) appear as
bare numbers in four functions. The comment at 1214-1215 is the only key to them:

```lua
icon:SetPoint("TOPLEFT", badge, "TOPLEFT", 2 + 8 + (i - 1) * 28, -(2 + 5))
local badgeWidth = 2 + 8 + #quests * 22 + (#quests - 1) * 6 + 10 + 2
local badgeHeight = 2 + 5 + 22 + 5 + 2
```

`12` alone is used seven times (999, 1003, 1005, 1186, 1187, 1188, 1233) for the same corner.

**Why it matters.** Resizing the icon means finding 22 in `ZoneQuestIcon`
(`SetSize(22, 22)`), `T:FitAtlas(..., 22)`, the step 28 and both size sums. Miss one and the
icons overrun the badge.

**Fix.** A small table like `ROUTE`:
`local BADGE = { ICON = 22, GLOW = 30, GAP = 6, PAD_LEFT = 8, PAD_RIGHT = 10, PAD_Y = 5, LINE = 2, CORNER = 12 }`.
Then work out width and height from it once.

### R8 · Five UI tests don't restore window state when they fail; quest side never restored
- **Severity:** should fix
- **Area:** Tests
- **Where:** `tests/smoke/modules/UI-Overview.lua:225-259, 261-325, 327-359, 361-429, 431-480`
- **Status:** fixed in round 2 (uncommitted). `RestoringWindow` (`UI-Overview.lua:68-93`) wraps all five UI tests. It restores Back's list, the page (`RestorePlace`), quest side, map levels and attunement side, and hides the window if it was hidden. It misses `ui.places`: R20

**What's wrong.** The brief asks every test to restore what it changes, even when it fails.
These five tests do several things outside `Restoring`. They open the window (`ui:Show()`),
switch tabs (`SwitchTab("DUNGEON")`/`("RAID")`) and select an instance or quest. They also
push Back entries (map card click, pin click, boss link) and pop them with `ui:GoBack()` only
on the success path, and set `pane.levels[inst.id]` (271-281). `ui:SetQuestSide("Alliance")`
(369) and `pane.attuneSide = side` (461) aren't restored even when the test passes.

**Why it matters.** If an assert fails halfway (for example at 256, "the map card didn't
open the map"), the map stays open with an extra Back entry. Every later scenario then starts
from that state and can fail for reasons unrelated to it, which hides the real failure. The
quest side forced to Alliance also changes which quests and attunement steps the next
scenarios see on a Horde stand-in character.

**Evidence.** Lines read. The runner (`run.lua:157-166`) runs scenarios back to back in one
Lua state with no reset between them.

**Fix.** Wrap each of these bodies in `Restoring`. Save
`ui.state.category, ui.state.instance, ui.state.quest, ui.state.questSide, #ui.history,
pane.levels[inst.id], pane.attuneSide`. Restore by trimming `ui.history` back to its length,
putting the saved values back and calling `ui:Refresh()`. Hide the window if it was hidden.
A shared `RestoringWindow(ns, fn)` beside `RecordingWaypoints` keeps it to one line per test.

### R9 · File is only 6 lines shorter: list of cuts
- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Overview.lua`
- **Status:** fixed in round 2 (uncommitted). Every listed cut was made: `Completed` inlined, `NewTiles`, `ShowLevel`, the mockup note, the duplicate `StartText` comment and `ZoneMap` guards. 3571 → 3560 lines; code 2931 → 2860 (−71). The rest went to comments the fixes needed (R2, R3, R4, R6, R7, R14) and to the split-out route functions. 12 of the saved lines come from folding functions onto one line: R18

**What's wrong.** The brief asks for clearly less code. Code lines fell by 47, but comments
rose by 8 and blank lines by 33, so the file is 3571 → 3565. The splits themselves earn
their keep: they took `CreateOverview` from 59 upvalues to 31 and from 2,295 lines to 391.
Most new names say what they do (`CreateMapCard`, `DrawQuestMarkers`, `OnPageLinkClick`).
What's left to cut:

1. `Completed` (180-182) is a one-line wrapper used twice: call
   `AnyVersion(quest, C_QuestLog.IsQuestFlaggedCompleted)` directly (−4).
2. One `NewTiles(parent)` next to `LoadTiles`/`PlaceTiles` for the two identical
   `for n = 1, 12` loops (1335, 1979), using `#TILE_ORDER` (R12, −2).
3. One `ShowLevel(view, level)` for the two copies in `LevelLink` and `LevelTab` (R12, −3).
4. Fold the stand-alone header comments at 1603-1608 and 1631-1634 into the comment of
   the first function under each (−2 blank lines, and no detached headers).
5. Cut the history note "From the zone-quests mockup (option D's badge and edge, option
   C's hover)" (934-935). It records how the design was picked, which a reader of the code
   doesn't need (−1).
6. The repeated comment "Looted from a chest or object in the dungeon; taking it offers
   the quest." (2789 and 2805): keep one (R15, −1).
7. `ZoneMap` as guard clauses (R15, −2).
8. `Money`'s 7-line fallback, if Mike takes R3's first option (−7, plus three `L` keys).
9. R13 moves one line rather than adding one; R1 replaces three lines with about seven.

Together that is about 20 lines, plus 7 with R3. The 33 new blank lines between top-level
functions are fine and match the rest of the addon. They don't need to go.

**Fix.** Apply the cuts above; re-measure with the same code/comment/blank count.

### R10 · Mental-mapping names: `k`/`n`, `fs`, `li`, `nxt`, `v`
- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/Overview.lua:1815-1846` and `1869-1880` (`k` point index, `n` point count, then `patrol[k * 2 - 1]`, `patrol[k * 2 - 3]`); `1499, 3140, 3329` (`fs`); `3449, 3453` (`li`); `3525` (`nxt`); `764` (`for i, v in ipairs(TILE_ORDER)`)
- **Status:** fixed in round 2 (uncommitted). `point`/`pointCount` with `PointXY`, `title`, `heading`, `text`, `lineIndex`, `prevID`/`nextID`, `position`/`tileNumber`

**What's wrong / why.** The route-editing handler is index arithmetic on a flat
`{ x1, y1, x2, y2, ... }` list. With `k` and `n` the reader has to work out that `k * 2 - 3`
is the previous point's x. `fs` is a font string, `li` a line index, `nxt` "next" dodging
the keyword, and `v` a tile number.

**Fix.** `point`/`pointCount` plus a two-line `PointXY(patrol, point)`; `title` or `text`
for `fs`; `lineIndex`; `nextID`; `tileNumber`.

### R11 · `HideTooltip` exists but half the handlers still call `GameTooltip:Hide()`
- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** helper at `NeedRoll/UI/Overview.lua:100-102`, used at 1302, 1474, 1600, 1860, 1998, 2150, 2317, 2685. Direct calls at 297, 1127, 1130, 2080, 2089, 2264, 2275, 2278, 2324
- **Status:** fixed in round 2 (uncommitted). Every hide goes through `HideTooltip` (grep finds `GameTooltip:Hide()` only inside it)

**Fix.** One way: use `HideTooltip()` everywhere the tooltip is hidden. Or drop the wrapper
and pass FrameXML's `GameTooltip_Hide` (in the `forever` FrameXML list, line 1873) as the
`OnLeave` handler; that needs a stand-in in the module test file until `wow.lua` gets one.

### R12 · Tile creation and "show this level" each written twice
- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Overview.lua:1335` and `1979-1981`; `2325-2327` and `2496-2498`
- **Status:** fixed in round 2 (uncommitted). `NewTiles` (`#TILE_ORDER`) and `ShowLevel`

**Fix.** `local function NewTiles(parent)` returning `#TILE_ORDER` textures, and
`local function ShowLevel(view, level)` doing
`view.pane.levels[view.pane.instance.id] = level; view.pane:Refresh()`.

### R13 · The level line is rebuilt on every scroll frame
- **Severity:** nit
- **Area:** Redundant code (per-frame work)
- **Where:** `NeedRoll/UI/Overview.lua:3429-3432`
- **Status:** fixed in round 2 (uncommitted). The level line's text is set inside `if not scrolling`

**What's wrong.** Before, `LevelText(quest)` ran with the page's lines, only on a full
rebuild. Now it runs on every `Refresh`, including each frame of a scroll glide
(`Refresh(true)`). The text is the same; the string building is wasted.

**Fix.** Set `self.levelLine:SetText(LevelText(quest))` inside the `if not scrolling` block
(3437-3441), and keep only `Show`/`Hide` above.

### R14 · Overview starts drawing at bare `50`, while the scroll limit assumes `HEADER_HEIGHT` (64)
- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/Overview.lua:3419` (`local y = quest and self:QuestTop() or 50`) vs `3308` (`local top = pane.quest and pane:QuestTop() or HEADER_HEIGHT`)
- **Status:** fixed in round 2 (uncommitted). `OVERVIEW_TOP`, plus a comment in `MaxOffset`; that comment has its own nit in R21 (from before this change; behaviour to keep)

**What's wrong / why.** Two numbers for where an Overview's first line starts. The scroll
limit thinks the page starts 14px lower than it draws, so the last line stops 14px short of
the bottom. A reader can't tell whether that is meant.

**Fix.** Name the 50 (`OVERVIEW_TOP = 50 -- the stat boxes start here, above the header's
full height`) and say in `MaxOffset` why it uses `HEADER_HEIGHT`. Or ask Mike whether they
should be the same.

### R15 · `ZoneMap` nesting and bare map IDs; a comment repeated in `StartText`
- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/Overview.lua:531-556`, `2789`, `2805`
- **Status:** fixed in round 2 (uncommitted). `ZoneMap` returns early; `WORLD_MAPS`, `LAST_MAP_ID`; one copy of the comment

**What's wrong / why.** `ZoneMap` wraps its whole lookup in `if zoneMaps[map] == nil then`
(four levels down to `Match`). `947, 946` (Azeroth and the Cosmic map) and `5000` (the last
map ID tried) are bare. `StartText` has the same comment line twice.

**Fix.** `if zoneMaps[map] ~= nil then return zoneMaps[map] or nil end` first;
`local WORLD_MAPS = { 947, 946 } -- Azeroth, then the Cosmic map` and
`local LAST_MAP_ID = 5000`; keep one copy of the comment.

### R16 · `CreateTitleParts` (108 lines) and `NewQuestMarker` (104 lines) still do several jobs each
- **Severity:** should fix
- **Area:** Readability
- **Where:** `NeedRoll/UI/Overview.lua:1510-1617` (`CreateTitleParts`, with `pane:PlaceInsideIcon` and `pane:PlaceTitle` inside it) and `2204-2307` (`NewQuestMarker`, with a 33-line `OnEnter` tooltip builder, two more methods and two click handlers)
- **Status:** fixed in round 3 (uncommitted). File-level functions now: `LastLineWidth` (word-wrap measure, `Overview.lua:1518`), `PlaceInsideIcon` (1540), `PlaceTitle` (1557; `pane.PlaceTitle = PlaceTitle` keeps `pane:PlaceTitle` working), `ShowMarkerTooltip` (2235). Nothing outside Overview.lua called the old `pane:PlaceInsideIcon` method (grep of `NeedRoll/` and `tests/`). `CreateTitleParts` is 37 lines and `NewQuestMarker` is 79 (frame, glow and its methods). The early return in `LastLineWidth` (`width <= 0 or x <= width`) gives the same result as base's `if width > 0 and x > width` block. Every hover tooltip line is identical in the snapshot

**What's wrong.** Round 1's area notes said round 2 would ask for this if R6's names didn't
shorten these functions. They didn't: 110 → 108 and 107 → 104 lines.

`CreateTitleParts` does five jobs:
- builds the badge and portal,
- defines a word-wrap simulation (`PlaceInsideIcon`, 5 indents deep at the `for word` loop),
- defines the whole title layout (`PlaceTitle`, 41 lines),
- builds the subtitle's link frame,
- wires its hyperlink handlers.

`NewQuestMarker` builds the frame and its glow, defines glow matching and decides the
tooltip for four kinds of marker.

**Why it matters.** `docs/READABLE-CODE.md` §3: past about 60 lines, look for the parts
with their own name. These two are now the longest functions in the file after
`CreateOverview` itself, and both bury layout logic inside a constructor. A reader looking
for "how is the title laid out" has to find a method defined three levels into a builder.

**Evidence.** Length and depth measured over the round 2 file (any top-level function over
60 lines or 6 indents): `CreateTitleParts` 108 lines / depth 5, `NewQuestMarker` 104 / 5,
`DrawQuestMarkers` 65 / 5, `CreateMapCard` 83 / 3, `CreateZoneOverlay` 75 / 3.

**Fix.** Make `PlaceInsideIcon(pane)` and `PlaceTitle(pane, isInstance, class, inside)`
file-level functions. Keep `pane.PlaceTitle` and `pane.PlaceInsideIcon` as fields pointing
at them, since `pane:PlaceTitle` is called from `ShowInstance`/`ShowQuest`. Put the
word-wrap loop in `LastLineWidth(title, width)`, returning `x, line`. Lift the marker's
tooltip into `ShowMarkerTooltip(mark)` beside `ShowZoneQuestTooltip`, which already follows
that pattern.

### R17 · The R4 secret-title fix has no scenario
- **Severity:** should fix
- **Area:** Tests
- **Where:** `tests/smoke/modules/UI-Overview.lua` (no scenario reaches `Chain.Name`'s game-title fallback)
- **Status:** fixed in round 3 (uncommitted). New scenario at `UI-Overview.lua:383-405`. It copies Deadmines quest 214 with `chain = { 999999 }`, stubs the title as `W.Secret("Hidden")` and asserts `quest 999999`. It then stubs a plain `"Hidden"` and asserts that name shows, restoring the stub through `RestoringWindow`. Verified: against a scratch copy of the addon with the `issecretvalue` line deleted it fails (`bad argument #3 to 'format' (string expected, got userdata)`), and it passes now

**What's wrong.** R4 is a bug fix, and the review standard is that a bug fix comes with a
scenario. The `--secret` run passes, but no scenario reaches the fallback: every chain step
the tests open is named by the scraped data, so `C_QuestLog.GetTitleForQuestID` is never
asked.

**Why it matters.** Nothing stops a later edit from dropping the `issecretvalue` line or
moving the game title ahead of the scraped name. The first sign would be a quest page
failing to draw for a player whose chain has a step missing from the data.

**Fix.** A scenario with `Restoring` that:
1. stubs `C_QuestLog.GetTitleForQuestID` to return `W.Secret("Hidden")`;
2. opens a quest page whose chain contains an ID not in `ns.Data.questNames` or
   `ns.Data.chainSteps` (a copy of a dungeon quest with `chain = { 999999 }`, its
   `chainAll` open);
3. asserts the page's lines include `quest 999999` and that nothing errored;
4. swaps the stub for a plain `"Hidden"` and asserts the name shows.

Restore the stub and the quest copy in the restore step.

### R18 · Functions folded onto one line to save lines; `return X and Y()` used as control flow
- **Severity:** nit
- **Area:** Readability (formatting)
- **Where:** `NeedRoll/UI/Overview.lua:100` (`HideTooltip`), `176` (`SetMiniPin`), `1285` (`PageWidth`), `1827` (`Round3`), `2375` (`MarkerQuest`), `2931` (`LineHeight`); `2627`, `2664`
- **Status:** fixed in round 3 (uncommitted). The six top-level functions are written out again. The remaining one-liners are small closures inside other functions, as at base. Both `return X and Y()` handlers are now plain statements

**What's wrong.** Round 2 folded six top-level functions that were three lines each onto
one line: `local function PageWidth(pane) return pane:GetWidth() - S.pad * 2 end`. The file
had 7 one-line functions at base (all small closures inside other functions) and has 18 now.
Elsewhere in the addon top-level functions are written out: `MainFrame.lua` has 6 one-liners
in a much larger file, `LootGrid.lua` 3. Two handlers also use `return` to do an action:
`if link:match(...) then return pane.quest and ns.UI:ShowQuestOnMap(pane.quest) end` and
`return GameTooltip:Show()`.

**Why it matters.** `docs/READABLE-CODE.md` §2 allows one statement per line except a
one-line guard. The brief says "a clear 10 lines beat a clever 4". The fold saves 12 of the
11 lines the file got shorter, so the "shorter than base" result rests on formatting, not
on less code. `return a and f()` reads as "returns a value" when nothing uses the value.

**Fix.** Write the six top-level functions out again, which is honest about the size. Keep
one-liners for small closures, as base did. Write the two handlers as
`if pane.quest then ns.UI:ShowQuestOnMap(pane.quest) end return` and
`GameTooltip:Show() return`.

### R19 · Get-or-create still hand-written for lines; "hide the rest of the pool" written about ten times
- **Severity:** nit
- **Area:** Redundant code (consistency)
- **Where:** `NeedRoll/UI/Overview.lua` `RouteSegment` (`view.routeLines[view.routeUsed] or view.canvas:CreateLine(...)`), `SoftSegment` (line and dot pair), `DrawZoneLines`' `Segment` (`zone.lines[used]`). The tail `for i = count + 1, #pool do pool[i]:Hide() end` appears in `DrawZoneQuests`, `DrawRoutes` (twice), `DrawRouteEdit`, `DrawPins`, `DrawMarks`, `DrawQuestMarkers`, `DrawSpots`, `DrawLevelTabs`, `DrawZoneLines` and `pane:Refresh`
- **Status:** fixed in round 3 (uncommitted). `HideFrom` (`Overview.lua:105`) covers every "hide the rest" tail except `DrawPins` (pins carry a glow) and the area lines (each carries `.dot`). The route, area and zone line pools go through `Pooled` (`NewRouteLine`, `NewAreaLine`, `NewZoneLine`). `view.areaDots` is gone: each area line keeps its dot as `line.dot`. The hover snapshot (12,730 line regions) is identical

**What's wrong.** `Pooled` is now the one way to get a pooled widget for 7 makers and
`Take`, but the three line pools still do it by hand. The matching "hide every widget past
the ones used" step is the same one-line loop in about ten places.

**Fix.** Use `Pooled` for the line pools too, with a small `NewRouteLine(canvas)` maker,
and add `local function HideFrom(pool, first) for i = first, #pool do pool[i]:Hide() end end`.
`DrawPins`' tail also hides each pin's glow, so it keeps its own loop.

### R20 · Style-switch test: wrong precondition comment, an assert that could pass empty; `ui.places` not restored
- **Severity:** nit
- **Area:** Tests
- **Where:** `tests/smoke/modules/UI-Overview.lua:354-356, 368-369`; `RestoringWindow` at `68-93`
- **Status:** fixed in round 3 (uncommitted). The comment now says the first style is built at login. There is an explicit `MapFloorPin(...) ~= nil` assert before the comparison. `RestoringWindow` copies `ui.places` per tab before the test and puts it back after `RestorePlace` (`UI-Overview.lua:79-95`)

**What's wrong.**
1. The comment says "Both styles' windows are built by now". The bug only needs the first
   style built, and it is built at login. The test fails at base even when run alone
   (`--only`, Checks), so the comment states a dependency the test doesn't have.
2. `assert(ns.UI.MapFloorPin(pin.encounter) == pane.floor[pin.encounter], ...)` would also
   pass if both were nil.
3. `RestoringWindow` restores the page through `UI:RestorePlace`. When the test left
   another tab, that calls `UI:RememberPlace()` (`MainFrame.lua:1646, 1508-1517`), which
   writes the test's raid or dungeon page into `ui.places[category]`, and nothing restores
   `ui.places`. A later scenario that switches tab lands on the page this test left.

**Fix.** Reword the comment to "The first style's window is built at login; switching away
and back puts it on screen again". Assert `ns.UI.MapFloorPin(pin.encounter) ~= nil` before
comparing. In `RestoringWindow`, copy `ui.places` (a shallow copy per category) before the
test and put it back after `RestorePlace`.

### R21 · A derived "14px" written into a comment; a ragged comment block over `ClampCenter`
- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `NeedRoll/UI/Overview.lua:3298-3300`, `1619-1623`
- **Status:** fixed in round 3 (uncommitted). `MaxOffset`'s comment now reads "HEADER_HEIGHT - OVERVIEW_TOP px short". The map-view block is rewrapped and stands apart from `ClampCenter`'s own one-line comment

**What's wrong.**
1. `MaxOffset`'s new comment says the last line "stops 14px short of the bottom". 14 is
   `HEADER_HEIGHT - OVERVIEW_TOP` worked out by hand; change either constant and the
   comment is wrong (§9, disinformation). "counts from HEADER_HEIGHT, under OVERVIEW_TOP
   where it draws" is also hard to parse.
2. The map view's description now sits on `ClampCenter` (a 4-line function). One of its
   lines runs to 98 characters while its neighbours wrap at about 75 ("marks on it (x and
   y ... Zoomed, the art's canvas grows inside a").

**Fix.** "An Overview draws from OVERVIEW_TOP but this counts from HEADER_HEIGHT, so its
last line stops HEADER_HEIGHT - OVERVIEW_TOP px short of the bottom." Rewrap the map-view
block to the file's width, and end it with a separate line for `ClampCenter` itself.

## Area notes

### Readability

Checked every rule in `docs/READABLE-CODE.md` against the whole file, not only the hunks.
Sound:

- **Splits.** The new file-level functions mostly earn their names; `CreateOverview` is
  readable as a list of widget constructors plus `Refresh`.
- **Comments.** They say why and name the game facts behind odd code: hidden strings that
  don't measure (3278), rotation only turning textures (2063), the server flagging a quest a
  moment after it's handed in (340-341, 3543), the `@debug@` Crystal Lake stand-in (837-843).
- **No narration.** A grep of the added comments for now/moved/refactor/instead finds none.
- **Lua 5.1 traps.** No `cond and nil or x` (grep). No data-built patterns: the
  `LinkObjectiveBosses` find is plain (`find(name, 1, true)`).
- **Format and indentation.** `local _, ns = ...` at the top, 4-space indents, LF.

Still too long: `QuestMarker` (107 lines), `CreateTitleParts` (110, mostly its two methods),
`pane:Refresh` (80) and `CreateMapCard` (84). Not raised as findings this round: each is one
widget's build plus its methods. Round 2 will ask for `PlaceTitle`/`PlaceInsideIcon` as
file-level functions if R6's names don't shorten them.

Round 2:
- **Re-read.** Every function the round 2 edits touched, in full.
- **New names.** `Pooled`, `NewTiles`, `FontSize`, `PointXY`, `ShowLevel`, the `New*`
  makers and the split route functions all name one job, with why-comments at the file's
  density.
- **No narration.** None in the added comments (grep for now/moved/refactor/instead).
- **`TITLE` and `BADGE`** follow the existing `ROUTE` table style.
- **Remaining issues:** R16, R18 and R21.

### WoW API

Round 2 adds one game name: `issecretvalue` (in `GlobalAPI.lua:6874`, nil-guarded as
elsewhere in the addon). It restores the `QuestMapFrame_OpenToQuestDetails` guard (R2) and
changes no other game call. `.luarc.json` lists only the addon's own globals, and the
change adds none.

Every guard or fallback the diff removed, checked against Ketho's `forever` lists fetched
raw from `Ketho/BlizzardInterfaceResources/forever/Resources/` today (not against
`wow.lua`):

| Name | Use | In `forever` lists | Where looked |
| --- | --- | --- | --- |
| `C_QuestLog.IsQuestFlaggedCompleted` | replaces the global fallback | yes | GlobalAPI.lua |
| global `IsQuestFlaggedCompleted` | removed | no (only the `C_` form) | GlobalAPI.lua, FrameXML.lua |
| `C_QuestLog.IsOnQuest` | guard removed; `GetLogIndexForQuestID` fallback removed | yes (both) | GlobalAPI.lua |
| `C_QuestLog.GetTitleForQuestID` | guard removed | yes (secret values: R4) | GlobalAPI.lua |
| `QuestMapFrame_OpenToQuestDetails` | guard removed | yes, but the list includes load-on-demand code (R2) | FrameXML.lua:3365 |
| `QuestLog_OpenToQuest`, `GetQuestLogIndexByID`, `QuestLogFrame`, `QuestLog_SetSelection`, `QuestLog_Update` | removed | no | all lists |
| `ShowUIPanel` | no longer used here | yes | FrameXML.lua |
| `C_Map.GetMapPosFromWorldPos` | guard removed | yes | GlobalAPI.lua |
| `CreateVector2D` | guard removed | yes (SharedXML, loaded at start: inferred) | FrameXML.lua:1257 |
| `C_Map.SetUserWaypoint`, `C_Map.CanSetUserWaypointOnMap` | guard removed | yes | GlobalAPI.lua |
| `UiMapPoint.CreateFromCoordinates` | guard removed | not in any list (a global table); accepted as standard: inferred | GlobalAPI, FrameXML, Mixins |
| `C_SuperTrack.SetSuperTrackedUserWaypoint` | guard removed | yes | GlobalAPI.lua |
| `OpenWorldMap` | guard removed | yes | GlobalAPI.lua and FrameXML.lua |
| `C_Map.GetMapInfo`, `C_Map.GetBestMapForUnit`, `C_Map.GetMapArtLayerTextures` | guards removed | yes | GlobalAPI.lua |
| `C_QuestLog.GetQuestObjectives` | guard removed | yes | GlobalAPI.lua |
| `C_Map.GetAreaInfo` | guard removed | yes | GlobalAPI.lua |
| `GetCoinTextureString` (unchanged, still guarded) | Money | no; only `C_CurrencyInfo.GetCoinTextureString` (R3) | all lists |

The change adds no new game calls: a diff of every `Name(`, `:Method(` and `C_*.*` token
before and after shows only the addon's own new function names. The calls it keeps were
re-checked:

- **Events.** `QUEST_LOG_UPDATE`, `QUEST_TURNED_IN`, `QUEST_ACCEPTED`, `QUEST_REMOVED`,
  `PORTRAITS_UPDATED` and `PLAYER_LEVEL_UP` are all in Events.lua.
- **Widget methods.** `SetPropagateMouseClicks`, `GetUnboundedStringWidth`,
  `SetClipsChildren`, `CreateMaskTexture`, `AddMaskTexture`, `SetGradient`, `CreateLine`,
  `SetStartPoint`, `SetThickness` and `SetHyperlinksEnabled` are all in WidgetAPI.lua.
- **Template.** `UIPanelButtonTemplate` is in Templates.lua.
- **Atlases.** `wowlabs-spectatecycling-arrowleft`, `FullMap-up-c60`, `Targeting-down-c60`,
  `ArtifactsFX-Whirls-Purple`, `Crosshair_lootall_96`, `QuestLog-up-c60`,
  `TaxiNode_Continent_Alliance` and `poi-door-arrow-up` are all in AtlasInfo.lua.
- **FrameXML helpers.** `PixelUtil.GetPixelToUIUnitFactor`, `CreateColor` and
  `HandleModifiedItemClick` are in FrameXML.lua.
- **Global tables.** `LOCALIZED_CLASS_NAMES_MALE` (nil-guarded, 410) is accepted by
  inference.

Other checks:

- **Globals and upvalues.** No new globals (W11). `CreateOverview` is well under the
  60-upvalue limit now (31).
- **Taint and combat.** Nothing touches secure frames. `ShowOnMap` keeps
  `InCombatLockdown()` before opening the map (574).
- **Events.** None registered or unregistered differently.
- **Test stand-in.** `C_Map.GetAreaInfo` is defined at the top of
  `tests/smoke/modules/UI-Overview.lua` because `wow.lua` lacks it. Module files are loaded
  after login and before the first scenario (`run.lua:146-155`), so its comment is
  accurate. It should move into `wow.lua` at merge.
- **Style guide.** Not needed. The only visual difference the implementer's snapshot found
  is texcoords no longer set on plain colour textures: `SetTexCoord` on a
  `SetColorTexture` texture has no visible effect.

### Redundant code

Compared against:

- **Theme.lua's `T:` helpers.** No `T:` tooltip, disc or tile helper exists; `T:Rounded`
  and `T:RoundedOn` are for frames, not mask discs. So `ShowTooltip`, `QuarterDisc` and
  `PlaceTiles` don't duplicate Theme.
- **Other files' local `ShowTooltip`s.** `UI/LootGrid.lua:324/455` and
  `UI/MinimapButton.lua:70` have their own, item-specific ones. They aren't the same job.
- **`ns.Items:Load`.** Used for async item data; `ItemLink` waits for it rather than
  polling.
- **`ns:On`.** Used for every event.

Round 2 added a file-local `Pooled`. No `T:` or `ns` pool helper exists to use instead:
`Theme.lua` has no pool function, and `Pooled` is the only one in `NeedRoll/` by grep. It
replaces 7 get-or-create makers plus `Take`'s; the line pools left over are R19.

Within the file: R9, R11, R12, R13. Merged duplicates verified: the old `Completed`/`InLog`
loops now go through `AnyVersion`, the two portrait builders through `AddPortrait`, and the
three Back-then-select blocks through `OpenQuestPage`/`OpenBossPage`. The one direct
`ns.UI:SelectQuest` left (2279, a quest marker's click) pushes no Back entry, as before;
keeping it is right for "behaviour identical". Mike may want to know a marker click is the
only quest opening without Back.

Dead code removed and checked unused across `NeedRoll/`:

- `view.dragging` (only ever set),
- `LINE_HEIGHT.items` (every items line carries its own height),
- the first `ENTRANCE_ICON = 24`, which every use shadowed with 28 (base lines 33 and 111;
  all uses after 111).

Cross-module, for the other groups (not this group's to fix):

- `CHAT_PREFIX` (`Overview.lua:79`, gold `|cffFCD29F`) vs `ns:Print` (`Core/Init.lua:222`,
  blue): two chat prefixes. Merging changes the colour, so Mike's call.
- Class name in `Chain.Step` (`Overview.lua:410-411`) vs `ns.UI.ClassName`
  (`UI/LootGrid.lua:1681`).
- `Money` (`Overview.lua:505`) vs `ShortCost` and its `GetCoinTextureString` guard
  (`UI/LootGrid.lua:480`). See R3.
- `Lists.lua:1920, 1983, 1997` existence guards on the map-floor functions, dead after R1.
- `UI:WithGameMap` (`MainFrame.lua:2341-2343`) is now only `open(...)`, a pass-through
  wrapper.
- Five copies of the secret-value test: `Core/Tooltip.lua:194`, `UI/MainFrame.lua:276`,
  `Core/Drops.lua:91`, `Core/LootLog.lua:52`, `Core/Names.lua:245`. One `ns.IsSecret` would
  serve R4 too.
- `pane.view` stays only for `tests/smoke/scenarios.lua:1130,1211,1223`. Those could read
  `pane.mapView` when `scenarios.lua` is next edited.

### Security

None of the inputs this change touches are untrusted: no addon messages, no chat from
others, no SavedVariables from others. The hyperlink handlers parse only links this file
writes, with anchored patterns (`^needroll:npc:(%-?%d+)`, `^needroll:inside:(.+)`,
`^needroll:quest:([^:]+):([^:]+):(%d+)`). Printed text (`CHAT_PREFIX` lines) is the addon's
own map and instance names. No player names involved.

## Round history

- 2026-10-18, round 1, `c0e5c79` plus uncommitted changes: **Changes needed**. Opened
  R1-R15 (9 should fix, 6 nits); none closed.
- 2026-10-18, round 2, `c0e5c79` plus uncommitted round 2 changes: **Changes needed**.
  - Closed: R1, R2, R4-R15.
  - R3 left as is for Mike.
  - Opened: R16-R17 (should fix) and R18-R21 (nits).
  - The look is identical to base apart from the badge quarter-disc texcoords: 766 states
    and 692 hover states compared.
- 2026-10-18, round 3 (last), `c0e5c79` plus uncommitted round 3 changes: **Ready**.
  - Closed: R16-R21.
  - No new findings.
  - R3 left as is for Mike: whether `Money` should call `C_CurrencyInfo.GetCoinTextureString`, which changes what players see.
  - The look is identical to base apart from the badge quarter-disc texcoords.
