# Review: NeedRoll v0.15.0 (everything since v0.14.2)

| | |
| --- | --- |
| Branch | `v0.14.2..origin/dev` (release review, reviewed from `claude/project-thread-nzjf0l` = `origin/dev`) |
| Commit reviewed | Round 1: `ab57042`. Round 2: the fixes `b9812b4..82b1391` (worktree `/home/claude/nr-ingest`, no uncommitted code changes) |
| Date | 2026-10-19 |
| Round | 2 |
| Verdict | **Ready** (0 blocking, 0 should fix, 3 nits left open with the implementer's reasons) |
| Needs | Full client restart, not just `/reload`: the TOC gains `Core\Talents.lua` and seven `Data\*.lua` files (ClassQuests, HunterPets, WarlockPets, ClassSpells, Poisons, MageScrolls, RecipeTrainers), and the game reads new TOC entries only at startup. |

## What the change does

v0.15.0 adds a **Classes** tab. It has a class list, an Overview page, a talent planner (saved plans, Import and Export as `NRT2:` share strings, and plans linked in chat that open as clickable `[NR Talents: …]` links), trainer Abilities pages, class Quests, Class Sets with collected counts, and pages for one class each: rogue Poisons, hunter Pets (families, beasts, pet trainers), warlock demons and mage Comprehension scrolls.

Inside a dungeon, NeedRoll's dungeon map now draws over the game's own world map (`UI/WorldMapOverlay.lua`) instead of M opening NeedRoll. Map pin links now place the game's own pin by running `/mappin` through secure macro buttons laid over NeedRoll's links (`UI/MainFrame.lua`). Before, NeedRoll set the waypoint from its own code, and the game then blocked Shift-clicking that pin into chat.

Drop sharing reads numbers in heard messages strictly (`ns.HeardNumber`), caps heard bosses at 1000, and shows other players' text with `|` escaped. The release also carries the readability pass (renames, split functions), Professions filters, the watcher's `data/watcher` push and the "Watcher data" workflow, which imports the pushed SavedVariables and combat-log data into a PR. On the scraper side there are new class data builders (class spells, class quests, hunter and warlock pets, poisons, recipe trainers).

## Scope

161 changed files outside `NeedRoll/Data/` and `docs/reviews/`. They were reviewed by priority: addon Lua first, then workflows and tools, with a lighter pass on scraper Python and tests.

Addon, read in full or around every hunk:
- `NeedRoll/Core/Talents.lua` (new): reads talent trees from the game, plans, saved plans, NRT1/NRT2 share strings, chat lines.
- `NeedRoll/UI/TalentLinks.lua` (new): chat filter turning `[NR Talents: x] NRT2:…` into links, and the `SetItemRef` click handler.
- `NeedRoll/UI/TalentPlanner.lua` (new): planner page, Import/Export/Link dialogs.
- `NeedRoll/UI/Classes.lua` (new): the tab, its sections and page switching.
- `NeedRoll/UI/WorldMapOverlay.lua` (new): NeedRoll's layer and pin over the game's world map.
- `NeedRoll/UI/MainFrame.lua`: secure map links (`NewSecureLink`, `GameMapLink`, `mapPinLink`), window drag from content panes, Classes host.
- `NeedRoll/Core/Drops.lua`: strict `HeardNumber`, `BOSSES_MAX` eviction, version tag; read lines 1-700 in full.
- `NeedRoll/Core/Init.lua`: `ns.Literal`, `ns.HeardNumber`, `ns.Base36`, `ns.CleanName` moved here.
- `NeedRoll/UI/DropTalk.lua`: heard text shown through `ns.Literal`.
- `NeedRoll/UI/ClassSpells.lua`, `ClassOverview.lua`, `HunterPets.lua`, `WarlockPets.lua`, `Poisons.lua`, `MageScrolls.lua`, `TierSets.lua` (new): sampled for names, nesting, secret values, game calls and constants.
- `NeedRoll/UI/DevKit.lua` (new, shipped; its list window is `--@debug@`), `UI/UI.xml`, `NeedRoll.toc`, `.pkgmeta`.
- `NeedRoll/UI/Theme.lua`, `Overview.lua`, `LootGrid.lua`, `Lists.lua`, `Settings.lua`, `Wishlist.lua`, `Core/Wishlist.lua` and the other readability-pass files. These were checked with luacheck, the upvalue count and pattern/trap greps. Their hunks from PR #612 already have their own Review Docs (`docs/reviews/claude-addon-readability-pass-rg51s6-*.md`), so they were not re-read line by line.

Workflows, tools, scraper:
- `.github/workflows/watcher-data.yml` (new), `scraper-tests.yml` (new), `daily-data.yml` (adds the trainers build).
- `tools/combatlog/Watch-WoW.ps1` (push to and restore from `data/watcher`), `Setup-CombatLogWatcher.ps1`, `README.md`.
- `scraper/needroll_scraper/sources/{cmangos,questie,questie_extract.lua,wowhead}.py` diffs; new `classquests.py`, `classspells.py`, `hunterpets.py`, `poisons.py`, `recipetrainers.py`, `warlockpets.py` checked for network access, `subprocess`, `pickle`, `eval` and paths.
- `tests/smoke/wow.lua`: the globals it adds were checked against Ketho's lists.

Skipped: `NeedRoll/Data/**`, `NeedRoll/Locales/NpcNames/*` and the locale tables (generated; `tools/locales.py --check` covers `enUS.lua`), `scraper/classes/*.json` (hand-kept facts), `.claude/**` (agent prompts) and `docs/reviews/*` (earlier Review Docs).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 96 changed/added Lua files | passed |
| `python3 tools/locales.py --check` | passed |
| `python3 tools/translations.py` | passed (exit 0). It lists 70 translations NeedRoll no longer uses (old English keys whose translations remain, report only). |
| `luacheck --no-global -q`, head against `v0.14.2` | Most files have fewer warnings. More: `Core/Items.lua` 3→5, `Core/Names.lua` 2→3, `UI/Theme.lua` 64→74, `UI/WorldMapOverlay.lua` (new) 3. All but one are `unused argument 'self'` on `:` methods or `self` shadowed in closures. The exception is `Theme.lua:436: unused argument 'width'` (R4). |
| luacheck with globals | No new globals. The writes are the existing `NeedRollDB`, `SLASH_NEEDROLL*`, `BINDING_*`, compartment and `NeedRoll_Show*` API functions, the same set as at `v0.14.2`. |
| Upvalue count (`luac5.1 -l`) | Nothing over 60. `CreateLootGrid` is at 53 (R3). `CreateOverview` fell from 59 to 35. |
| `tests/smoke/check.sh` (dev, packaged, secret) | passed: "all passed" in all three runs |
| `cd scraper && python3 -m unittest discover -s tests` | passed: 236 tests OK |

Lua 5.1 and luacheck 1.2.0 were installed for this review (apt `lua5.1`, `luarocks install luacheck`).

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Readability | `Core/Init.lua:281-288`, `Core/Talents.lua:439, 529`, `Core/Wishlist.lua:19` | `ns.CleanName` cuts names by bytes, inside UTF-8 letters, and calls the limit "letters" | fixed (`eb33f1f`, `99235d0`) |
| R2 | should fix | Redundant code | `UI/MainFrame.lua:2446-2456, 2612-2615, 2632-2636` | Secure-link `OnUpdate` runs every frame all session and walks game-button paths before checking visibility | fixed (`4aad825`) |
| R3 | should fix | WoW API | `UI/LootGrid.lua:2369-3229` | `CreateLootGrid` is 860 lines with 53 of Lua 5.1's 60 upvalues | fixed (`d146edd`) |
| R4 | should fix | Readability | `UI/Theme.lua:435-439` | `Theme:LineWidth`'s `width` argument is ignored, but its comment says to pass it | fixed (`01a501d`) |
| R5 | should fix | Readability | `UI/Classes.lua:215-224, 323-326, 644-659, 664-709` | Each kind of Classes page is handled in five separate places | fixed (`2d9e542`) |
| R6 | should fix | Redundant code | `UI/WarlockPets.lua:127-131`, `UI/ClassOverview.lua:58-60` and 13 inline reads | Two `PlayerLevel` helpers, one guarded against secret values and one not | fixed (`eb33f1f`) |
| R7 | nit | Readability | `Core/Talents.lua:715`, `UI/TalentLinks.lua:23` | Two patterns for one share string (`NRT[12]` and `NRT%d`) | fixed (`eb33f1f`) |
| R8 | nit | Readability | `UI/DevKit.lua:48-150, 309`, `UI/MapEdit.lua:558-885`, `UI/Overview.lua:1397, 1888, 1905-1907, 1971, 1986-2012` | One-letter names: `f` for windows, `a`/`b` for route points, `n`, `k`, `t` | left open: renames across DevKit, MapEdit and Overview, not trivial right before a release |
| R9 | nit | Redundant code | `UI/Overview.lua:1907` | `CatmullRom` closure created for every step of every route segment | fixed (`f984904`) |
| R10 | nit | Redundant code | `UI/ClassSpells.lua:205-209, 245-253`, `UI/Classes.lua:198-199, 713-717` | Every talent click re-checks the whole spellbook for the Abilities figure | left open: needs a cache cleared on `SPELLS_CHANGED`, a behaviour change best done after the release |
| R11 | nit | Readability | `.claude/agents/implementer.md:43-44`, `.claude/agents/reviewer.md:101-102` | The agent prompts still say `CreateOverview` is at the upvalue limit | left open: the fix edits `.claude/agents/*` (agent configuration), which the implementer does not change on another agent's request; Mike to apply |

### R1 · `ns.CleanName` cuts names by bytes, inside UTF-8 letters, and calls the limit "letters"
- **Severity:** should fix
- **Area:** Readability (avoid disinformation, one way of doing each thing). It is also what other players' copies show.
- **Where:** `NeedRoll/Core/Init.lua:281-288`; callers `Core/Talents.lua:472, 517, 560, 699, 721` and `Core/Wishlist.lua:149-150`; the same cut at `Core/Talents.lua:529` (`FreePlanName`); constants `Core/Talents.lua:439` (`MAX_PLAN_NAME = 40 -- letters a plan's name keeps`) and `Core/Wishlist.lua:19` (`MAX_NAME = 40 -- letters a list name keeps`)
- **Status:** fixed (`eb33f1f`, `99235d0`)

**What's wrong.**
```lua
-- ... at most `maxLetters` long. Nil when nothing is left.
function ns.CleanName(name, maxLetters)
    name = strtrim((tostring(name or ""):gsub("[:|\n\r]", " "):gsub("%s+", " ")))
    if name == "" then return nil end
    return name:sub(1, maxLetters)
end
```
`string.sub` counts bytes. A Cyrillic letter is 2 bytes and a Hangul or Han character is 3. The name says "letters", the constants say "letters", and the code cuts at 40 bytes, which can fall in the middle of a character. `FreePlanName` does the same: `name:sub(1, MAX_PLAN_NAME - #suffix)`. The addon already has the right helper. `Short` in `Core/Drops.lua:1038-1043` cuts "never inside a UTF-8 character":
```lua
if #text > size then text = text:sub(1, size):gsub("[\192-\255][\128-\191]*$", "") end
```

**Why it matters.** New in this release, `CleanName` also handles names that come from other players. `Talents.LinkName`, used by the chat filter in `UI/TalentLinks.lua:37-42`, builds the gold `[NR Talents: <name>]` link every NeedRoll player sees from the name in a chat line. Suppose a koKR player links a plan named with 14 Hangul syllables (42 bytes). Every reader's link text ends in a stray lead byte, and that plan is saved with the broken name when clicked. The same happens when a Russian name has an odd number of ASCII characters in front. Wishlist names and the player's own plan names on non-Latin clients break the same way. The comment and constant names also tell the next developer the cap is in letters, which is wrong.

**Evidence.** Run under lua5.1 with the function body copied out: 14 × `"\234\176\128"` (42 bytes) comes back as 40 bytes ending in bytes `128, 234`, a dangling lead byte. `"A"` plus 20 × `"\208\144"` (41 bytes) comes back ending in a lone `208`. No smoke scenario covers names outside ASCII (grep of `tests/smoke/modules/Core-Talents.lua`, `Core-Init.lua`).

**Fix.** Use one UTF-8-safe cutter and name the unit truthfully. For example, move `Short`'s cut into `Core/Init.lua` and use it in both places:
```lua
-- `text` cut to at most `maxBytes` bytes, never inside a UTF-8 character.
function ns.CutToBytes(text, maxBytes)
    if #text <= maxBytes then return text end
    return (text:sub(1, maxBytes):gsub("[\192-\255][\128-\191]*$", ""))
end

function ns.CleanName(name, maxBytes)
    ...
    return ns.CutToBytes(name, maxBytes)
end
```
Then make `Drops.lua`'s `Short` call `ns.CutToBytes`, have `FreePlanName` use it, and rename the constants' comments to "bytes", or count letters with `strlenutf8` if the cap really should be 40 letters. Add a smoke case with a Hangul or Cyrillic plan name in a chat line.

### R2 · Secure-link `OnUpdate` runs every frame all session and walks game-button paths before checking visibility
- **Severity:** should fix
- **Area:** Redundant code (work repeated per frame)
- **Where:** `NeedRoll/UI/MainFrame.lua:2612-2615` (`linkLayer`), `2632-2636` (`GameMapLink`'s target), `2446-2456` (`GameMapButton`), `2595-2611` (`LayOverLink`)
- **Status:** fixed (`4aad825`)

**What's wrong.**
```lua
local linkLayer = CreateFrame("Frame", nil, UIParent)
linkLayer:SetScript("OnUpdate", function()
    for _, link in ipairs(links) do LayOverLink(link) end
end)
```
`linkLayer` is a shown child of `UIParent`, so this runs every frame from login to logout, also while NeedRoll's window and the world map are closed. For both `GameMapLink`s, `LayOverLink` calls the target, which runs `when()` and then `GameMapButton()` before anything checks that the frame is visible:
```lua
local frame = target()
if frame and when() and GameMapButton() then return frame end
```
`GameMapButton` walks `"MinimapCluster.ZoneTextButton"` with `path:gmatch("[^.]+")`, and each call creates a new iterator closure. Once the Overview pane exists, its `mapView.worldMap` frame exists for good, even when hidden. So from the first time the window opens, every frame of the session allocates at least two closures and walks `_G` twice, only to reach `if not (frame and frame:IsVisible())` and hide nothing.

**Why it matters.** This is steady garbage and CPU in raids and combat, the worst time, for a feature that only matters while the mouse is over a NeedRoll link or the world map. The addon's rule is that a new `OnUpdate` needs a reason. This one has a reason for while a link can be hovered, but not for the whole session.

**Evidence.** Lines quoted above. `UI.overview.mapView.worldMap` is created once and only hidden (inferred from the target expression and `CreateOverview`). No smoke check counts per-frame work.

**Fix.** Check visibility first, resolve the game's map button once, and run the layer only while something can carry a link:
```lua
local over = NewSecureLink(function()
    local frame = target()
    if not (frame and frame:IsVisible() and when()) then return nil end
    return GameMapButton() and frame or nil
end).over
```
Then show `linkLayer` only while `UI.frame` or `WorldMapFrame` is shown (hook their `OnShow`/`OnHide`, as `WorldMapOverlay` already hooks the map) and hide it otherwise. The `PLAYER_REGEN_DISABLED` handler still puts the buttons away. Cache the resolved button per path in `GameMapButton` (`failedMapButtons` already holds the misses).

### R3 · `CreateLootGrid` is 860 lines with 53 of Lua 5.1's 60 upvalues
- **Severity:** should fix
- **Area:** WoW API (Lua 5.1 limit) and Readability (single responsibility)
- **Where:** `NeedRoll/UI/LootGrid.lua:2369-3229`
- **Status:** fixed (`d146edd`). Upvalues are down from 53 to 39 by grouping the box and portrait-header sizes into the `BOX` and `PORTRAIT_HEADER` tables. The function is still about 860 lines; splitting it stays desirable but is no longer urgent.

**What's wrong.** `luac5.1 -l` reports `function <NeedRoll/UI/LootGrid.lua:2369,3229>` with 53 upvalues, up from 47 at `v0.14.2` (`LootGrid.lua:1842,2892`). This release grew it by six with the Professions filters, skill range and "Taught by" trainers. The function is 860 lines. `CreateOverview`, which the agent prompts call the one at the limit, went from 59 to 35 in the readability pass, so `CreateLootGrid` is now the function closest to the limit.

**Why it matters.** At 61, `LootGrid.lua` fails to compile ("function at line 2369 has more than 60 upvalues"). The file then doesn't load and the loot pane is gone for every player. The next feature on the loot pane has seven upvalues of room. Commit `270ab4d` ("Overview: group the map card sizes so the file compiles again") shows this has already happened once in this release cycle.

**Evidence.** `luac5.1 -o /dev/null -l` on head and on `v0.14.2`, upvalue count per function, as above. `Lists.lua:1581-2394` is the next highest at 48.

**Fix.** Split it the way `CreateOverview` was split: move its sections (filter bar, card building, profession rows, recipe trainers) into file-level functions that take `pane`, and group related constants into tables (`CARD.*`, as `Overview.lua` did) so each counts as one upvalue. Update the agent prompts (R11).

### R4 · `Theme:LineWidth`'s `width` argument is ignored, but its comment says to pass it
- **Severity:** should fix
- **Area:** Readability (avoid disinformation)
- **Where:** `NeedRoll/UI/Theme.lua:435-439`
- **Status:** fixed (`01a501d`)

**What's wrong.**
```lua
-- Pass `width` to snap a width other than the accent line's.
function Theme:LineWidth(region, width)
    local unit = PixelUtil.GetPixelToUIUnitFactor() / region:GetEffectiveScale()
    return math.ceil(self.lineWidth / unit - 0.01) * unit, unit
end
```
`width` is never read: it always snaps `self.lineWidth`. luacheck reports `Theme.lua:436:34: unused argument 'width'`. The `v0.14.2` version had the same bug, and its one caller that passed a width (`T:LineWidth(self, SCROLL_WIDTH)`) silently got 2. This release renamed the line (`T` → `Theme`), so the line is in scope.

**Why it matters.** The next developer who follows the comment and passes a width gets the accent line's width back, and a scroll bar or outline comes out the wrong size with no error.

**Evidence.** Lines quoted. `grep -rn "LineWidth(" NeedRoll` shows no current caller passing a second argument.

**Fix.** Delete the `width` parameter and the comment line. If a second width is ever needed, write `return math.ceil((width or self.lineWidth) / unit - 0.01) * unit, unit` and keep the comment.

### R5 · Each kind of Classes page is handled in five separate places
- **Severity:** should fix
- **Area:** Readability (single responsibility, searchable names, consistency)
- **Where:** `NeedRoll/UI/Classes.lua:215-224` (`PageFigure`), `323-326` (`HasOwnPage`), `644-659` (`RefreshSoon`), `664-709` (`tab:Update`, including the planner's `SetShown` at 681-682)
- **Status:** fixed (`2d9e542`)

**What's wrong.** Every right-pane page kind (spell tab, quest, set, recipe, pet, demon, scrolls, planner) is listed by hand in each of these:
```lua
return (page.spellTab or page.set or page.quest or page.recipe or page.petPage or page.demonPage
    or page.scrollPage) ~= nil
...
self.planner:SetShown(not isOverview and set == nil and quest == nil and spellTab == nil and recipe == nil
    and not petPage and not demonPage and not isScrollPage)
...
if self.petPage:IsShown() then self.petPage:Refresh() end
if self.demonPage:IsShown() then self.demonPage:Refresh() end
```
`tab:Update` alone is 45 lines. It reads the page, works out eight booleans, shows and hides eight panes, and then dispatches through an eight-branch `if`/`elseif`.

**Why it matters.** Pets, demons and scrolls arrived in three separate commits in this release, and each had to touch all five places. A page kind missing from one of them shows two panes at once or never refreshes. Nothing fails loudly, and the smoke tests only catch the cases they were written for.

**Evidence.** The lines above. `git log v0.14.2..origin/dev -- NeedRoll/UI/Classes.lua` shows `ccabb2c` (Pets), `648b3e2` (demons) and `0bf265b` (Comprehension) each touching `HasOwnPage`, `Update` and `RefreshSoon`.

**Fix.** Make one table describe the page kinds, and loop over it:
```lua
-- Each kind of page the right pane shows: the field its row carries, the
-- tab's pane for it, and how that pane shows the row.
local PAGE_KINDS = {
    { field = "spellTab", pane = "spellPage", show = function(pane, page, classID) pane:ShowTab(classID, page.spellTab) end },
    { field = "petPage", pane = "petPage", show = function(pane, page) pane:ShowPage(page) end },
    ...
}
```
`HasOwnPage`, `Update` and `RefreshSoon` then loop over `PAGE_KINDS`, and the planner shows when no kind matched. Recipes and unlisted quests, which aren't rows of the section, stay as the two special cases they are.

### R6 · Two `PlayerLevel` helpers, one guarded against secret values and one not
- **Severity:** should fix
- **Area:** Redundant code (duplicate helper), consistency
- **Where:** `NeedRoll/UI/WarlockPets.lua:127-131`, `NeedRoll/UI/ClassOverview.lua:58-60`; inline reads at `UI/HunterPets.lua:439, 880`, `UI/ClassSpells.lua:158, 911`, `UI/MageScrolls.lua:226` and others (15 `UnitLevel("player")` calls in the addon)
- **Status:** fixed (`eb33f1f`)

**What's wrong.**
```lua
-- WarlockPets.lua
-- Your level, as the grimoires ask for it. Read through ns.Plain in case
-- the game hands it back secret.
local function PlayerLevel()
    return ns.Plain(UnitLevel("player")) or 1
end

-- ClassOverview.lua
local function PlayerLevel()
    return UnitLevel("player") or 1
end
```
These are two helpers with the same name doing the same job differently. One file says the value might be secret. The other file, and the inline `UnitLevel("player") or 1` reads in HunterPets, ClassSpells and MageScrolls, compare the level (`ranks[index][RANK_LEVEL] <= level`) with no guard.

**Why it matters.** Either the player's level can be secret, and then the unguarded comparisons raise "attempt to compare a secret value" on the Classes tab, or it can't, and the `ns.Plain` comment misleads. As written, a reader can't tell which. The `or 1` fallback is also dead if `UnitLevel("player")` never returns nil. Whether Forever ever makes the player's own level secret is inferred unknown: Ketho's lists don't say which returns are secret.

**Evidence.** Lines quoted, and `grep -rn 'UnitLevel("player")' NeedRoll` shows 15 uses.

**Fix.** Add one `ns.PlayerLevel()` in `Core/Init.lua`, using `ns.Plain` if there is any doubt, with a comment saying why. Use it everywhere and delete both local copies.

### R7 · Two patterns for one share string (`NRT[12]` and `NRT%d`)
- **Severity:** nit
- **Area:** Readability (searchable names, one way)
- **Where:** `NeedRoll/Core/Talents.lua:651` and `715` (`NRT[12]:%d+:...`), `NeedRoll/UI/TalentLinks.lua:23` (`NRT%d:%d+:[%w%.]*`)
- **Status:** fixed (`eb33f1f`)

**What's wrong.** The chat filter accepts `NRT1`/`NRT2`, while the click handler's `LINK_DATA_PATTERN` accepts any `NRT<digit>`. There are three hand-written patterns for the same token.

**Why it matters.** When NRT3 comes, the parser and chat filter need editing, but the link pattern silently accepts it, so a change has to be found in three places in two files. Nothing breaks today.

**Fix.** Define `Talents.SHARE_STRING_PATTERN = "NRT[12]:%d+:[%w%.]*"` once next to `SHARE_PREFIX`, and build `CHAT_LINE_PATTERN`, `ParseShare`'s match and `LINK_DATA_PATTERN` from it.

### R8 · One-letter names: `f` for windows, `a`/`b` for route points, `n`, `k`, `t`
- **Severity:** nit
- **Area:** Readability (avoid mental mapping)
- **Where:** `NeedRoll/UI/DevKit.lua:48, 81, 94-150, 309` (`local f = CreateFrame(...)`, `Hint(f, text)`, `ScrollArea(f, ...)`, `Backgrounds(f, ...)`, `StyleSwitch(f, ...)`); `NeedRoll/UI/MapEdit.lua:558-885` (`f`, `b` for palette buttons); `NeedRoll/UI/Overview.lua:1888` (`n` points), `1397, 1971` (`k`), `1905` (`t`), `1986-2012` (`for i, a in ipairs(path) do local b = ...`)
- **Status:** left open: renames across DevKit, MapEdit and Overview, not trivial right before a release

**What's wrong.** `docs/READABLE-CODE.md` §8 allows `i`, `x`/`y`/`w`/`h`, `r`/`g`/`b`/`a` and the Theme aliases. `f` (window), `a`/`b` (two route points, where `a`/`b` are reserved for alpha and blue), `n` (point count) and `k` (fan line index) aren't on that list. DevKit is new in this release. The route code moved in it.

**Fix.** Use `window` for `f`, `button` for `b`, `point`/`nextPoint` for `a`/`b`, `pointCount` for `n` and `line` for `k`. `t` inside the Catmull-Rom maths can stay as `t` if a comment names it ("t: 0 to 1 along the segment").

### R9 · `CatmullRom` closure created for every step of every route segment
- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Overview.lua:1903-1911`
- **Status:** fixed (`f984904`)

**What's wrong.** `local function CatmullRom(a, b, c, d)` is defined inside `for step = 0, ROUTE.STEPS - 1`, so each redraw creates `points × ROUTE.STEPS` closures just to capture `t`, `t2` and `t3`.

**Fix.** Move it to file level as `local function CatmullRom(p0, p1, p2, p3, t, t2, t3)` and call it with the step's values.

### R10 · Every talent click re-checks the whole spellbook for the Abilities figure
- **Severity:** nit
- **Area:** Redundant code (work that belongs in a cache)
- **Where:** `NeedRoll/UI/ClassSpells.lua:205-209` (`KnownRank`), `245-253` (`CountText`); `NeedRoll/UI/Classes.lua:198-199`, `713-717` (`Talents:OnChange` → `UpdateSections`)
- **Status:** left open: needs a cache cleared on `SPELLS_CHANGED`, a behaviour change best done after the release

**What's wrong.** A planned point fires `Talents:OnChange`, and `tab:UpdateSections` then rebuilds the sections column. Its Abilities header calls `ClassSpells.CountText`, which runs `C_SpellBook.IsSpellKnown` on every rank of every class spell, from the top rank down. That's several hundred game calls per click, and none of the answers can change from a planned talent.

**Why it matters.** Clicking quickly through a 51-point plan repeats this work 51 times. The cost is inferred, not measured.

**Fix.** Cache `KnownRank` per spell and clear the cache on `SPELLS_CHANGED`, which `Classes.lua:723-726` already listens to. Or skip `UpdateSections` for a planner-only change and update just the Talents header figure.

### R11 · The agent prompts still say `CreateOverview` is at the upvalue limit
- **Severity:** nit
- **Area:** Readability (a comment that is now wrong)
- **Where:** `.claude/agents/implementer.md:43-44` ("`CreateOverview` is already at the limit"), `.claude/agents/reviewer.md:101-102` ("`CreateOverview` is at it")
- **Status:** left open: the fix edits `.claude/agents/*` (agent configuration), which the implementer does not change on another agent's request; Mike to apply

**What's wrong.** `CreateOverview` is at 35 upvalues now. The function to watch is `CreateLootGrid` at 53 (R3).

**Fix.** Name `CreateLootGrid` (and its count) in both prompts, or say "check `luac5.1 -l` for the highest".

## Round 2

Reviewed 2026-10-19: commits `b9812b4..82b1391` in `/home/claude/nr-ingest` (branch `claude/project-thread-nzjf0l`). Every changed function was re-read in full.

### Checks, round 2

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 21 changed Lua files | passed |
| `python3 tools/locales.py --check` | passed |
| `python3 tools/translations.py` | passed (exit 0; same 70 unused translations reported) |
| `luacheck --no-global -q`, each changed file at `82b1391` against `b9812b4` | no new warnings. `Theme.lua` is one fewer (74→73: the unused `width` is gone); every other file is unchanged. |
| luacheck with globals | no new globals. No leftover `BOX_*`, `ROW_*`, `SINGLE_*` or `PlayerLevel` references that would read as nil globals. |
| Upvalues (`luac5.1 -l`) | `CreateLootGrid` (now `LootGrid.lua:2375-3238`) is down to 39. Nothing in the addon is above 48. |
| `tests/smoke/check.sh` | passed, "all passed" in all three runs: 1370 `ok` lines, up from 1358, for 4 new scenarios × 3 modes |
| `cd scraper && python3 -m unittest discover -s tests` | passed |

### Each fix

- **R1, fixed (`eb33f1f`, `99235d0`).** The new `ns.CutToBytes(text, maxBytes)` (`Core/Init.lua`) differs from the round-1 snippet. Instead of cutting and then stripping a trailing lead byte plus continuation bytes, it looks at the first byte to be dropped (`text:byte(cut + 1)`). While that byte is a continuation byte (128-191), it steps the cut back one.
  - **Traced cases:** `"A"` plus Cyrillic, cut at 2, gives `"A"`. Fourteen Hangul syllables (42 bytes) cut at 40 give 13 syllables (39 bytes). A cut that already lands on a boundary keeps everything. 4-byte characters work the same way. The loop stops at 0, so even invalid input (a long run of continuation bytes) ends in `""`, never an error.
  - **Better than the snippet.** `gsub("[\192-\255][\128-\191]*$", "")` also removes a complete multi-byte letter that happens to end exactly at the cut. The old `Short` in `Drops.lua` therefore sent one letter fewer than it had room for in Q1 messages. The new helper keeps that letter. The message format and its byte limit are unchanged, since the result is still at most `size` bytes.
  - **Callers.** `Short` now calls the helper, as do `ns.CleanName` (parameter renamed to `maxBytes`) and `FreePlanName`. The constants' comments now say "bytes (fewer letters outside English)".
  - **Smoke tests.** A scenario covers Hangul and Cyrillic names through `LinkName`, `CleanName`, a chat line, `SaveShared` and a "(1)" copy.
- **R2, fixed (`4aad825`).** `linkLayer` starts hidden and is shown only while one of its hosts shows: NeedRoll's window (`UI.HostSecureLinks(window)` in `UI:Build`) or `WorldMapFrame`, hooked at `PLAYER_LOGIN` or when `Blizzard_WorldMap` loads.
  - **Every map link is covered.** Every `HoverMapLink` caller sits inside one of those two hosts: Overview, LootGrid, ClassOverview, HunterPets and WarlockPets rows inside the window; the zone button and pin on the world map. `HoverMapLink` and `LeaveMapLink` still lay the button at once, whatever the layer's state.
  - **Buttons over hidden frames.** When the last host hides, `UpdateLinkLayer` runs one more pass, which hides any button over a frame that just hid. `over:Hide()` there is still guarded by `not InCombatLockdown()`, and in combat the buttons are already on `UIParent` (the `PLAYER_REGEN_DISABLED` handler is unchanged).
  - **No taint path.** `linkLayer` holds no protected child, so `SetShown` on it is safe in combat. `HookScript` on `WorldMapFrame` only watches, as `WorldMapOverlay` already does. `tContains` is in Ketho's forever GlobalAPI.
  - **Visibility first.** `GameMapLink`'s target now checks `frame:IsVisible()` and `when()` before `GameMapButton()`.
  - **Smoke tests.** A scenario confirms no link passes while both hosts are closed.
- **R3, fixed (`d146edd`).** Done by grouping constants rather than splitting the function: 53 → 39 upvalues (see Checks). The renamed references were all converted (luacheck, grep). The `columnMiddle` local removes a repeated expression without changing what is drawn: it is the same formula as the old inline `Size.pad + col * ROW_CELL + ROW_CELL / 2`.
- **R4, fixed (`01a501d`).** `Theme:LineWidth(region)` drops the argument and the misleading comment. The one caller that passed a width (`Theme:ScrollBar`) now says it gets the accent line's width, which is what it always got, so nothing on screen changes.
- **R5, fixed (`2d9e542`).** `PAGE_KINDS` (field, pane, `Show`, `Refresh`, `Figure`) now drives `PageFigure`, `HasOwnPage`, `RefreshSoon` and `tab:Update`. The new `PickedPage` handles unlisted quests and recipes left off by the chip filter. Checked against the old code:
  - Each row carries exactly one kind field: `HunterPets.lua:164`, `WarlockPets.lua:91`, `MageScrolls.lua:55`, `Poisons.lua:125`, and the quest, spell-tab and set rows. So the change from the old `PageFigure` order (recipe first) to the `PAGE_KINDS` order (spell tab first) can't change any figure.
  - A listed poison row's `page.recipe` is the same encounter `Poisons.RecipeOf` returned before.
  - `Update` shows exactly one pane, and the planner only when no kind matched.
  - The `Refresh` set matches the old list: no refresh for the quest page, `UpdateStrip` for the set page.
  - A new smoke scenario opens every row of four classes and asserts exactly the expected pane shows.
- **R6, fixed (`eb33f1f`).** A single `ns.PlayerLevel()` (`ns.Plain(UnitLevel("player")) or 1`) replaces both local helpers and the inline reads in ClassSpells, HunterPets, MageScrolls, Lists, Overview, FrameDebug and `Talents:Budget`. The three reads left in `Drops.lua` (1905, 1963, 1992) stay `Plain(UnitLevel("player"))` with no fallback. That is right: they record what was seen in a report, and a missing level there should stay missing rather than become 1. A scenario covers the secret case.
- **R7, fixed (`eb33f1f`).** `Talents.SHARE_STRING_PATTERN` (`READ_PREFIXES = "NRT[12]"`) builds `CHAT_LINE_PATTERN`, `ParseShare`'s match and `TalentLinks`' `LINK_DATA_PATTERN`. The link pattern now accepts only NRT1/NRT2. These links are only ever made by this client's own chat filter, so nothing that worked before is rejected.
- **R8, left open.** The implementer's reason: renames across DevKit, MapEdit and Overview are not trivial right before a release. Accepted for a nit.
- **R9, fixed (`f984904`).** `CatmullRom(p0, p1, p2, p3, t, t2, t3)` is now at file level with a comment naming `t`. The maths is unchanged term for term.
- **R10, left open.** The implementer's reason: it needs a cache cleared on `SPELLS_CHANGED`, a behaviour change best done after the release. Accepted for a nit.
- **R11, left open.** The implementer's reason: the fix edits `.claude/agents/*`, which the implementer does not change on another agent's request; Mike to apply. Accepted. With R3's fix, the right text is "`CreateLootGrid` (39) and `Lists.lua`'s list builder (48) are the largest; check `luac5.1 -l`".

### New findings, round 2

None. Every function the fixes touched was re-read in full: `ns.CutToBytes`, `ns.CleanName`, `ns.PlayerLevel`, `Short`, `FreePlanName`, `ParseShare`, `LayOverLinks`/`UpdateLinkLayer`/`HostSecureLinks`, `GameMapLink`, `Theme:LineWidth`/`ScrollBar`, `PAGE_KINDS`/`PageKindOf`/`PickedPage`/`PageFigure`/`tab:Update`/`tab:RefreshSoon`, `RoutePath`/`CatmullRom`, and `CreateLootGrid`'s box and portrait-header code. Nothing new to ask for: no blocking or should-fix issues, and no new nits.

## Area notes

### Readability

Checked against every rule in `docs/READABLE-CODE.md` across the new files:
- **Names, constants, comments, formatting.** The new Classes files use game-term names and named constants: a scan for bare multi-digit literals in calls found one, in `Core/Talents.lua` (`GetSpecializationInfoForClassID(classID, 1)`, a spec index). Comments explain the reason and the game fact behind odd code. Examples: `UI/TalentLinks.lua:6-13` on how Forever routes `addon:` links; `UI/MainFrame.lua:2548-2559` on why the secure button is a child of the frame it covers; `UI/WorldMapOverlay.lua:16-22` on why the game's map is only read. Indentation is 4 spaces, every new file starts with `local _, ns = ...`, and luac/luacheck are clean apart from `self` noise.
- **Function length.** A function-length and nesting scan found the long ones are the `Create*` constructors holding method closures, the addon's usual pattern. `CreateClassesTab` (240 lines) is long mainly because of the page dispatch in R5.
- **Lua 5.1 traps.** No `cond and nil or x` anywhere (grep). No `#t` over holes in the new code read. Patterns built from data are escaped: `TierSets.lua:36-40` escapes `ITEM_SET_BONUS*` before use. `RecipeBand.lua:84` and `MainFrame.lua:2371` build patterns from data-file words and numeric instance IDs (no magic characters in them; inferred from the data).
- **Already reviewed.** The readability-pass hunks (#612) were reviewed in their own docs and not re-read line by line.

### WoW API

Every game function, event, `Enum`, template, atlas and FrameXML global this release adds was compared with Ketho's `forever` lists, downloaded 2026-10-19 (GlobalAPI, Events, WidgetAPI, LuaEnum, FrameXML, Templates, AtlasInfo, GlobalStrings/enUS). The comparison was the set used at head minus the set at `v0.14.2`, over `NeedRoll/**/*.lua` without Data and Locales.

| Added call / name | In `forever` lists | Where looked |
| --- | --- | --- |
| `C_ClassColor.GetClassColor` | yes | GlobalAPI |
| `C_ClassTalents.GetActiveConfigID`, `.GetTraitTreeForSpec`, `.InitializeViewLoadout` | yes | GlobalAPI |
| `C_Traits.GetConfigInfo`, `.GetDefinitionInfo`, `.GetEntryInfo`, `.GetGroupDisplayInfoByTreeID`, `.GetNodeInfo`, `.GetTreeNodes` | yes | GlobalAPI |
| `C_CreatureInfo.GetCreatureFamilyInfo`, `.GetRaceInfo` | yes | GlobalAPI |
| `C_Map.GetUserWaypoint`, `.GetWorldPosFromMapPos` | yes | GlobalAPI |
| `C_Reputation.CollapseFactionHeader`, `.ExpandFactionHeader`, `.GetFactionDataByIndex`, `.GetNumFactions` | yes | GlobalAPI |
| `C_SkillInfo.GetSkillLineInfoByID`, `C_SpellBook.IsSpellKnown` | yes | GlobalAPI |
| `C_TransmogCollection.GetAppearanceInfoBySource`, `.GetItemInfo`, `.PlayerHasTransmog` | yes | GlobalAPI |
| `C_SuperTrack.SetSuperTrackedUserWaypoint` | yes | GlobalAPI |
| `GetSpecializationInfoForClassID`, `UnitExists`, `GetClassInfo`, `GetNumClasses`, `IsModifiedClick`, `IsModifierKeyDown`, `GetCursorPosition`, `canaccessvalue` | yes | GlobalAPI |
| `CopyTable`, `GameTooltip_Hide`, `GetCreatureDifficultyColor`, `ShowUIPanel`, `SetItemRef`, `OpenMapToUserWaypoint` | yes | FrameXML |
| `ChatFrameUtil.AddMessageEventFilter`, `.InsertLink`, `.OpenChat` | yes | FrameXML |
| `LinkUtil.RegisterLinkHandler` (what fires `EventRegistry`'s `"SetItemRef"` for `addon:` links) | yes, as a function. That it triggers `"SetItemRef"` is inferred from retail FrameXML. | FrameXML |
| `EventRegistry:RegisterCallback`, `WorldMapFrame:GetCanvas`, `WorldMapFrame:GetMapID` | inferred: `CallbackRegistryMixin` / `MapCanvasMixin` methods, standard FrameXML, not listed | n/a |
| Widget methods `SetPassThroughButtons`, `SetDesaturation`, `SetNumeric`, `Raise` | yes | WidgetAPI |
| Template `SecureActionButtonTemplate` | yes | Templates |
| `/mappin` (macro text) | yes: `SLASH_MAPPIN1 = "/mappin"` | GlobalStrings/enUS |
| Events `ACTIVE_COMBAT_CONFIG_CHANGED`, `TRAIT_CONFIG_UPDATED`, `SPELLS_CHANGED`, `PET_BAR_UPDATE`, `UNIT_PET`, `PLAYER_EQUIPMENT_CHANGED`, `TOOLTIP_DATA_UPDATE`, `USER_WAYPOINT_UPDATED`, `CHAT_MSG_SAY`, `_YELL`, `_PARTY`, `_PARTY_LEADER`, `_RAID`, `_RAID_LEADER`, `_RAID_WARNING`, `_GUILD`, `_OFFICER`, `_WHISPER`, `_WHISPER_INFORM`, `_INSTANCE_CHAT`, `_INSTANCE_CHAT_LEADER` | yes | Events |
| `Enum.ItemBind.OnAcquire`, `Enum.ItemClass.{Consumable,Miscellaneous,Questitem,Recipe,Weapon}`, `Enum.ItemMiscellaneousSubclass.CompanionPet`, `Enum.ItemQuality.{Epic,Poor,Uncommon}`, `Enum.ItemWeaponSubclass.Wand`, `Enum.SpellBookSpellBank.Pet` | yes | LuaEnum |
| `Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID` | yes (`-3`) | LuaEnum |
| Atlases `Campaign-QuestLog-LoreBook`, `Poisons`, `StableMaster`, `Talents-up-c60`, `Waypoint-MapPin-Untracked`, `talent-background-<class>` (all nine) | yes | AtlasInfo |
| Global strings `ITEM_SET_BONUS`, `ITEM_SET_BONUS_GRAY`, `ITEM_CLASSES_ALLOWED` | yes | GlobalStrings/enUS |

Other WoW API checks:
- **Taint and combat (secure links, `MainFrame.lua:2486-2757`).** The secure buttons are created at load. They are parented over NeedRoll's frames only out of combat (`LayOverLink`), and all go back onto `UIParent`, hidden, in `PLAYER_REGEN_DISABLED`, the last moment before lockdown. Their attributes change only in `PreClick` after an `InCombatLockdown()` guard. `SetPassThroughButtons`, which is blocked in combat, waits for `PLAYER_REGEN_ENABLED`. The mouse wheel is never forwarded to the game's map (`WheelTarget` stops at `UI.frame`). `WorldMapOverlay` only hooks `OnShow`/`OnHide`, polls `GetMapID`, and watches `GLOBAL_MOUSE_UP`. It doesn't change the game's map or use a data provider. No problems found. Whether the click-the-zone-text-button path opens the map on every Forever client is untested here; `failedMapButtons` falls back to the next button.
- **Secret values.** `TalentLinks` checks `canaccessvalue(message)` before reading a chat line. `TierSets` reads tooltip lines through `ns.Plain`, and `HunterPets` reads the pet's level the same way. For the player's level, see R6.
- **Events.** Talent events are registered once in `Core/Talents.lua:382-384`. The Classes refresh events go through `RefreshSoon` (once per frame, and only while visible). No one-shot events were added.
- **Globals and limits.** No new globals (luacheck). Nothing over 60 upvalues (R3 for the closest).
- **Text and packaging.** Player-facing text goes through literal `L["..."]` (grep for English sentences outside `L[]` in the new files found none), and `locales.py --check` passes. Dev-only code is in `--@debug@` blocks (`MainFrame.lua:2463-2484`, `DevKit.lua:243-351`) or `.pkgmeta`-ignored files (`Fished.lua` moved to both).
- **Smoke tests and style guide.** `tests/smoke/wow.lua` mirrors every new call. It defines no global that Forever lacks: `OpenWorldMap`, `OpenMapToUserWaypoint`, `SLASH_MAPPIN1` and `GetLootRollItemInfo` are all in the lists, and the `C_*` stand-ins sit in their namespaces. `docs/STYLE-GUIDE.md` has a Classes tab section with values from the code.

### Redundant code

Compared against `Theme:Pill`, `Theme:Menu`, `Theme:NameDialog` and `Theme:Dialog` (with `AddHint`), `Theme:Input`, `Theme:ClassBadge`, `Theme:FitAtlas`, `Theme:JoinDots`, `ns.UI.CreateList`, `ns.UI.CreateSectionList`, `ns.Plain`, `ns.HeardNumber`, `ns.Base36`, `ns.CleanName`, `ns.Literal` and Drops' `Short`.
- **Shared helpers done well.** The Wishlist's menu and name dialog became `Theme:Menu` and `Theme:NameDialog`, which the talent planner reuses. `HeardNumber`, `Base36` and the name cleaner moved to `Core/Init.lua` and are shared by Drops, Wishlist and Talents.
- **What remains.** The duplicate `PlayerLevel` (R6), the UTF-8 cut that `Short` already does right (R1), the five-place page dispatch (R5) and per-frame or per-click work (R2, R9, R10).
- **Considered and kept.** `UI:WithGameMap(open, ...)` (`MainFrame.lua:2427-2429`) is a pass-through kept on purpose as a grep marker for every place NeedRoll opens the game's map, so it is not a finding.
- **Dead code.** No unused locals beyond `self` on methods (luacheck), and no debug prints outside `@debug@`.

### Security

Untrusted inputs this release touches:
- **Drop sharing (`CHAT_MSG_ADDON`, `NeedRollDropSharing`).** Every number in a heard D1/D2/Q1 message goes through `ns.HeardNumber`: plain digits, at most 2^31-1, so no `nan`/`inf`/hex/negatives. Kill keys must match `^%d+%-%x+$`. Heard bosses are capped at `BOSSES_MAX` = 1000, evicting only bosses heard from others, oldest first (`Drops.lua:198-245`), and kills per boss at `KILLS_MAX` = 50. Heard text is shown through `ns.Literal` in `/nr droptalk` (which is not shipped). Sending still respects "Share drops" (`Queue` and `SendNext` return or wipe when off), `SEND_GAP` = 60 s and `DAILY_MAX` = 100. No `loadstring`, `RunScript` or `setfenv` anywhere in the addon (grep).
- **Talent plans from chat and paste (`TalentLinks.lua`, `Core/Talents.lua:576-743`).** Pasted text is capped at 1000 characters. Prefix and class come from an anchored-enough match and are range-checked (`IsPlannedClass`). NRT2 digits must be `^%d*$` and no longer than the tree. NRT1 codes are `^[%da-z%.]*$` with each node ID through `HeardNumber(…, nil, 36)` and duplicates rejected. Ranks are then fitted to the real tree (`KnownRanks`, `LegalRanks`). Names lose `|`, `:`, newlines and, for links, `[` and `]`, so a chat line can't fake a link, color or texture. A plan is saved only on the player's click. One display issue remains with these names (R1).
- **Character names and credits.** `Watch-WoW.ps1` now pushes every account's SavedVariables, which hold other players' names, to the `data/watcher` branch of this private repo. `.github/workflows/watcher-data.yml` runs the trusted `dev` code on those files (checkout `ref: dev`; the data branch is only extracted with `git archive`, never run). SavedVariables are parsed by the Python tokenizer in `scraper/needroll_scraper/savedvars.py`, never by Lua. The copies land in `scraper/cache/`, which `.gitignore` excludes, so `add-paths: NeedRoll scraper` can't commit them. The import PR can carry the ingest report and `scraper/drops/`, both of which `CLAUDE.md` allows in this private repo. `NeedRoll/Credits.txt` and `observed.py`'s `SHIPPED_CREDITS` are unchanged. Nothing new reaches `.pkgmeta`'s zip.
- **Workflows.** No `pull_request_target`. No `${{ github.event.* }}` in `run:`: only `server_url`, `repository` and `run_id`, and `$watcher` comes from the environment. `scraper-tests.yml` has `contents: read`. `watcher-data.yml` asks for `contents`, `pull-requests` and `statuses: write`, which it needs to open the PR and post the smoke status. No secrets are in code.
- **Scraper and tools.** No request reaches Wowhead's servers: `wowhead._fetch` reads the cache only and raises `Retired` otherwise, and the new builders read hand-kept JSON and Classic-DB/QuestieDB at build time (grep for `urlopen`/`requests`/`http` in the new modules found none). `subprocess` calls use argument lists. The `pickle` in `cmangos.py` reads the scraper's own parsed cache, not downloaded data (unchanged except `CACHE_VERSION`). `Watch-WoW.ps1` runs git with argument arrays and no `Invoke-Expression`.

## Round history

- 2026-10-19, `ab57042`, round 1: **Changes needed** (0 blocking, 6 should fix, 5 nits). Opened R1-R11.
- 2026-10-19, `82b1391` (fixes `b9812b4..82b1391`), round 2: **Ready** (0 blocking, 0 should fix, 3 nits left open). Closed R1-R7 and R9. R8, R10 and R11 left open with the implementer's reasons. No new findings.
