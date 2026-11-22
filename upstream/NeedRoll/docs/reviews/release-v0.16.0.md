# Review: NeedRoll v0.16.0 (everything since v0.15.2), and PR #739

| | |
| --- | --- |
| Branch | `v0.15.2..origin/dev`, where `origin/dev` = `2bd1026` includes PR #739 (tests and CI) and the Translations PR #742 (locale files only), plus the round 1 fixes `2bd1026..bdfbab8` on `claude/project-thread-d4v8ds`. |
| Commit reviewed | Round 1: `b8e87d9` (no uncommitted changes); PR #739 at its head `f6e4313`, as merged in `c786123` (`git diff b8e87d9 c786123`). Round 2: `bdfbab8`, the 11 fix commits `b7c7cbe..bdfbab8` on top of `2bd1026` (no uncommitted changes besides this doc). |
| Date | 2026-10-22 |
| Round | 2 |
| Verdict | **Ready** (0 blocking, 0 should fix, 0 open; 11 fixed, 4 nits left as is with reasons: R7, R10, R11, R15) |
| Needs | Full client restart, not just `/reload`: the TOC gains `Data\ProfessionGuide.lua`, and the game reads new TOC entries only at startup. The three new UI files come in through `UI/UI.xml`, which a `/reload` would read. |

## What the change does

v0.16.0 adds **questlines**. On the Classes tab, a class's multi-step chains picked by hand (`classQuestFolds` in `scraper/quests/forever.json`: Defensive Stance, the warlock's demons, the shaman's totems, Quel'Serrar, Benediction and the rest) sit under fold rows in the Quests section. Each row shows progress and where the player stands, and opens a questline page drawn as a flowchart. Cards are joined by pixel-snapped lines. Branches sit in columns under a bus, alternatives are joined by dashed gold lines, the player's race comes first, and optional lead-ins are faded. A trail with ‹ › and right-click steps back through the cards followed. On the Dungeons tab, a dungeon's quests that sit on a chain (`Data/Chains.lua`) fold under a questline row of their own and open the same page (`UI/DungeonQuestlines.lua`).

The **Professions Overview** is new (`UI/ProfessionOverview.lua`, data `Data/ProfessionGuide.lua` from the new `scraper/needroll_scraper/professionguide.py`). It shows where to mine, gather or skin by skill band, with safe or contested zones on PvP realms (`ns.IsPvPRealm`). It also covers where and how each rank is learned, specialization chains and other profession quests. NPCs are map-pin links, zones open the game's map (refused in combat), and NPCs standing inside a dungeon open NeedRoll's own map on their spot.

Smaller changes:
- The Wishlist's stars unstar items with undo until you leave the page.
- Tooltip and Wishlist source lines start with the tab's icon.
- Right-clicking the minimap button opens Settings.
- Non-English clients get a first-login translation notice (`Theme:LinkBox` is shared with the Discord dialog).
- The window keeps the art it showed loaded, so nothing flashes white on open.
- The world map and quest log stay shut in combat, with a chat message.
- Drop sharing learns bosses in dungeons NeedRoll has no data for (boss candidates: a lone elite, rare or world boss seen once this run).
- `Overview.lua` groups constants to free main-chunk locals.

Scraper and CI changes:
- The ingest skips kills from the end-of-beta event (`PAUSED` windows).
- `NeedRoll/Credits.txt` is no longer written. Credits stay in `scraper/drops/credits.json`, and `.pkgmeta` ignores any leftover `Credits.txt`.
- The Watcher data workflow runs hourly instead of on push.
- The daily data job builds the profession guide.

**PR #739** makes the smoke stand-in faster:
- `wow.lua` caches whether a frame holds a secure one, checks that only in combat, and runs OnUpdate only on frames that set one.
- `check.sh --quick` does the dev and combat runs only.
- CI uses `--quick` on PRs into and pushes to dev, and all four runs on main.

## Scope

67 changed files outside `NeedRoll/Data/` (about 10,300 added lines), plus `NeedRoll/Data/Data.lua`, which is hand-written and reviewed like any other Lua file. They were reviewed by priority: the new addon files and Core first, then the touched UI files, then the scraper Python, workflows and tests.

Addon, read in full:
- `NeedRoll/UI/Questlines.lua` (new, 1619 lines): the questline model (stages, branches, version steps, optional quests, progress), the Classes tab's fold rows and trail, and the shared flowchart page (cards, lines, joints, corners, fringes).
- `NeedRoll/UI/DungeonQuestlines.lua` (new): a dungeon's chains merged into a fold, its rows and its page.
- `NeedRoll/UI/ProfessionOverview.lua` (new, 1285 lines): the page, its rows, links, tooltips and strip parts.
- `NeedRoll/Data/Data.lua`: `RegisterClassQuestFolds` and helpers, `ChainsWith` / `FittingChain` split out of `Chain`, `RegisterSkinning`, `RegisterProfessionGuide`, `PlayerWhereabouts` / `IsPlayerInside` (moved from Overview, now through `ns.Plain`), `DropperName` (one copy instead of two), `ClassQuestFold`.
- `NeedRoll/Core/Drops.lua`: boss candidates in unlisted instances (`NoteCreature`, `NoteUnit`, `IsBossCandidate`, `NoteLootSources`) and the guess onto the looted candidate.
- `NeedRoll/Core/Init.lua` (`ns.DISCORD_URL`, `ns.IsPvPRealm`, `shownTranslationNotice`), `Core/Tooltip.lua` (`Tooltip.SourceIcon`, `CroppedMarkup`, `FittedMarkup`), `Core/Wishlist.lua` (`WL:Restore`).

Addon, every hunk read with the code around it:
- `UI/Lists.lua`: dungeon questline fold rows in the encounter list, the profession Overview row, and the section list's fold, note, "or" and branch rows.
- `UI/MainFrame.lua`: the content host's two new pages, `state.questline` through places, history, refresh and crumbs, `OpenWorldMap` / `OpenZoneMap` refusing in combat, `ShowSpotOnMap`, and `UI.IsWithin` made shared.
- `UI/Wishlist.lua`: the visit, unstar and restore.
- `UI/Welcome.lua`: `NoticePanel`, `WaitForCombatEnd` and the translation notice.
- `UI/Theme.lua`: `KeepLoadedUnder`, `LinkBox`, the flow colours, and the `ScrollColumn` resize hook.
- `UI/Classes.lua`, `UI/Overview.lua`, `UI/LootGrid.lua`, `UI/HunterPets.lua`, `UI/ClassOverview.lua`, `UI/Poisons.lua`, `UI/Search.lua`, `UI/Settings.lua`, `UI/MinimapButton.lua`, `UI/UI.xml`, `NeedRoll.toc` and `.pkgmeta`.

Scraper, workflows and tests:
- `scraper/needroll_scraper/professionguide.py` (new) and the `classquests.py`, `observed.py`, `__main__.py`, `quests.py` and `questie_quests.py` diffs were read for network access, `subprocess`, `eval` / `pickle`, paths and readability.
- The hand files `scraper/professions/*.json`, `scraper/quests/forever.json` and `blacklist.txt` got a format glance.
- The data-only JSON (`scraper/drops/credits.json`, `items.json`, `observed.json`, `scraper/quests/reported.json`) got a privacy and security glance only.
- `.github/workflows/watcher-data.yml` and `daily-data.yml`, and `.claude/agents/*.md` (prompt text, read for accuracy, not reviewed as code).
- `tests/smoke/wow.lua` was read in full. The new modules (`UI-ProfessionOverview.lua`, `UI-DungeonQuestlines.lua`) and the scenario diffs were sampled for coverage.
- `docs/STYLE-GUIDE.md` was checked against the UI changes. `scraper/README.md` and `tools/combatlog/README.md` were read.

PR #739: `.github/workflows/smoke-tests.yml`, `tests/smoke/check.sh`, `tests/smoke/wow.lua`, `tests/smoke/README.md`, read in full.

Skipped:
- `NeedRoll/Data/Chains.lua`, `ClassQuests.lua`, `KnownDrops.lua`, `KnownQuests.lua` and `ProfessionGuide.lua` are generated by the scraper, which was reviewed instead. None shows a hand edit: each keeps its "Generated by" header and source line.
- The `NeedRoll/Locales/enUS.lua` keys are covered by `tools/locales.py --check`.
- `docs/reviews/*`.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 44 changed Lua files (38 outside `Data/`, the 6 `Data/` files too) | passed |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | passed (exit 0, no output) |
| `luacheck --no-global -q`, head `b8e87d9` against `v0.15.2` | Same count or fewer in 30 files. More: `Data/Data.lua` 12→14, `UI/Theme.lua` 73→74, `UI/Welcome.lua` 2→3, `Locales/enUS.lua` 50→52 (generated, one phrase per line), `tests/smoke/scenarios.lua` 64→66, `modules/UI-Classes.lua` 1→2, `modules/UI-Wishlist.lua` 0→1. The new warnings: `unused argument 'self'` on `:` methods (`Data:PlayerWhereabouts`, `Theme:LinkBox`); `unused argument 'W'` in scenarios; one line too long in each test module (121, 122 characters); `Welcome.lua:276` (an `L["..."]` literal of 247 characters, which can't be split); and `Data.lua:211` (also an `L["..."]` key, 140 characters; round 1 wrongly tied it to R4). The new files (`Questlines.lua`, `ProfessionOverview.lua`, `DungeonQuestlines.lua`) have none. |
| luacheck with globals (`--std lua51`) | No new global writes. The only ones are `Core/Init.lua`'s existing `NeedRollDB`, `SLASH_*`, `BINDING_*` and compartment functions. The new named frame `NeedRollTranslationNotice` follows `NeedRollDropNotice`'s practice. |
| Upvalue count (`luac5.1 -l -l`) | Nothing over 60. `CreateEncounterList` (`UI/Lists.lua:1737-2597`) rose from 48 to 53 (R1). Nothing else is at 45 or more. |
| Main-chunk locals (limit 200) | `UI/Overview.lua` about 192 (the release grouped its constants to get here), `Core/Drops.lua` about 174 (+10 this release), `UI/LootGrid.lua` about 170, `UI/Questlines.lua` 155, `UI/ProfessionOverview.lua` 148. All load. |
| `tests/smoke/check.sh` at `b8e87d9` (dev, packaged, secret, combat) | passed: "all passed" in all four runs (541, 489, 541, 541 scenarios), 1 min 28 s |
| `tests/smoke/check.sh` at #739 (`c786123`), all four and `--quick` | passed: all four in 43 s, `--quick` (dev and combat) in 42 s on this 4+ core machine. Each mode runs exactly the same scenarios as before #739 (541 / 489 / 541 / 541). |
| `cd scraper && python3 -m unittest discover -s tests` | passed: 272 tests OK. It printed "Wowhead pages (retired, cache only): 1 read, 1 not cached": cache only, no request. |
| `bash -n tests/smoke/check.sh` (#739) | passed. `shellcheck` isn't installed, so it didn't run. |
| **Round 2**, at `bdfbab8` (the fixes on top of `2bd1026`) | |
| `luac5.1 -p` on the files the fixes touch | passed |
| Upvalue count (`luac5.1 -l -l`) | `CreateEncounterList` (`UI/Lists.lua:1754-2614`) holds 42 (R1). No other function in the touched files is at 40 or more. |
| luacheck `--std lua51` on the touched Lua | no undefined names: nothing renamed was left behind (R1, R2, R8). |
| `luacheck --no-global -q`, `bdfbab8` against `2bd1026` | Same count or fewer in every touched file: `Data/Data.lua` 14→14 (the one long line left is the `L["..."]` key at 211, see R4), `Core/Drops.lua` 21→21, `UI/Welcome.lua` 3→3; `UI/Lists.lua`, `UI/Questlines.lua`, `UI/DungeonQuestlines.lua`, `UI/ProfessionOverview.lua` 0→0; `tests/smoke/wow.lua` 100→99 (R13). |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | passed (exit 0). The Translations PR #742 in `2bd1026` is locale files only (10 locales). This check also makes sure every translation keeps its format specifiers in order. |
| `tests/smoke/check.sh` (dev, packaged, secret, combat) | passed: "all passed" in all four runs, 44 s |
| `tests/smoke/check.sh --quick --verbose` | passed: two runs (dev and combat). The no-argument form passed above (R14). |
| `cd scraper && python3 -m unittest discover -s tests` | passed: 272 tests OK, cache only, no request. |

Lua 5.1.5 and luacheck 1.2.0 were already installed. Ketho's `forever` lists (GlobalAPI, Events, WidgetAPI, LuaEnum, FrameXML, Templates, AtlasInfo, GlobalStrings/enUS) were downloaded to the scratchpad and grepped.

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | WoW API | `UI/Lists.lua:1733-2597` | `CreateEncounterList` grew to 53 of Lua 5.1's 60 upvalues (from 48) | fixed in round 2 (`b7c7cbe`) |
| R2 | nit | Readability | `Data/Data.lua:547-584`, `UI/DungeonQuestlines.lua:46-47, 72-73` | New code names a chain's number `c` | fixed in round 2 (`445bb1b`) |
| R3 | nit | Readability | `UI/DungeonQuestlines.lua:31-38` | `ChainStartOf`'s comment lists three returns; it returns two | fixed in round 2 (`f9533e0`) |
| R4 | nit | Readability | `Data/Data.lua:209-218` | A badly wrapped line in `CLASS_QUEST_BRANCH_NAMES`'s comment (round 1 mixed it up with the 140-character `L["..."]` line 211) | fixed in round 2 (`addaa76`) |
| R5 | nit | Readability | `UI/Welcome.lua:216-218, 293-295` | The notices' 14 px button gap is a bare number, now in two places | fixed in round 2 (`355bca1`) |
| R6 | nit | Readability | `UI/ProfessionOverview.lua:351, 739` | What a quest asks for reads "12 Giant Egg" in a row but "12 x Giant Egg" in its tooltip | fixed in round 2 (`488731d`) |
| R7 | nit | Redundant code | `UI/Questlines.lua:410-418, 437-447, 1576` | The questline page queues another full redraw for each refresh made before spell or item names arrive | left as is: a perf trade-off, not worth code now |
| R8 | nit | Redundant code | `UI/Questlines.lua:36`, `UI/Lists.lua:1049` | Two constants for one look: `DIM_ALPHA` and `DIMMED_ROW`, both 0.4 for "an alternative not taken" | fixed in round 2 (`38b987b`) |
| R9 | nit | Redundant code | `Core/Drops.lua:216-223` | `InUnlistedInstance` reads `GetInstanceInfo` twice and builds a table on every nameplate, target and mouseover inside any dungeon | fixed in round 2 (`6389091`) |
| R10 | nit | Redundant code | `UI/Theme.lua:505-548` | Everything the window showed at each close stays loaded for the session (`Theme.kept` never shrinks) | left as is: a perf trade-off, not worth code now |
| R11 | nit | WoW API | `Core/Drops.lua:1000-1006, 263-268` | A creature known only from the loot window passes as a boss candidate, since its classification is never read | left as is: Mike's call, deferred after v0.16.0 |
| R12 | nit | Readability | `scraper/needroll_scraper/professionguide.py:85-86` | `RANK_CAPS` is unused, and its comment says the next rank comes 50 below the cap (it's 25) | fixed in round 2 (`714bf6f`) |
| R13 | nit | Redundant code | `tests/smoke/wow.lua:184, 236` (#739) | (#739) `named` is now written but never read | fixed in round 2 (`fecb7f1`) |
| R14 | nit | Readability | `tests/smoke/check.sh:23` (#739) | (#739) `"${runArgs[@]}"` under `set -u` fails on bash older than 4.4 when no argument is given | fixed in round 2 (`bdfbab8`) |
| R15 | nit | WoW API | `.github/workflows/smoke-tests.yml`, `tests/smoke/check.sh` (#739) | (#739) PRs into dev no longer run the secret-values smoke run | left as is: Mike's call, deferred after v0.16.0 |

### R1 · `CreateEncounterList` grew to 53 of Lua 5.1's 60 upvalues (from 48)
- **Severity:** should fix
- **Area:** WoW API (Lua 5.1 limits)
- **Where:** `NeedRoll/UI/Lists.lua:1733-1736` (the comment that warns about it), `1737-2597` (the function), at `b8e87d9`
- **Status:** fixed in round 2 (`b7c7cbe`). `CreateEncounterList` (now `Lists.lua:1754-2614`) holds 42 upvalues: `luac5.1 -l -l -p` gives `function <NeedRoll/UI/Lists.lua:1754,2614> ... 42 upvalues`. The row sizes and indents became `ROW`, `INDENT` and `SIDE_TOGGLE`, and the Overview row's and fold rows' helpers became `OverviewRow` and `Folds`. The warning comment above it lists those tables and gives the new count. `docs/STYLE-GUIDE.md` was updated to the new names. Nothing else in the file is at 40 or more.

**What's wrong.** The encounter list's constructor is one 860-line closure. Its nested functions read file-level names, so each of those names is an upvalue of `CreateEncounterList`. At `v0.15.2` it held 48. This release adds `QuestlineRow`, `FOLD_INDENT`, `ShowFoldRow`, `PaintOverviewRow`, `FoldedRows`, `FoldRowHolding` and `ShowOverviewRow`, with no file-level name dropped in exchange. That brings it to 53:

```
function <NeedRoll/UI/Lists.lua:1737,2597> ... 1 param, 50 slots, 53 upvalues, 46 locals
```

The file already warns about this at line 1733: "CreateEncounterList's closures share its locals, and with the file-level names it reads that comes close to Lua 5.1's limit of 60 upvalues per function (past it the file won't load)."

**Why it matters.** At 61 upvalues, `Lists.lua` doesn't compile. The game then loads NeedRoll without its lists, and every tab fails with Lua errors. Each feature on a list (dungeon questlines took 5 here) uses up the margin. The next one is likely to add another fold kind or row type, and would hit the limit with no warning until `luac` fails. The same pattern got the same finding last release (`CreateLootGrid`, R3 of the v0.15.0 review).

**Evidence.** `luac5.1 -l -l -p` at `v0.15.2` and at `b8e87d9` (48 vs 53). Upvalue names from the listing: `INSTANCE_HEADERS ns NO_ROWS QuestlineRow ALL_DROPS_ICON TRASH_ICON L Theme LevelColor LevelText IsSetRow MARKER_ROW RecipeIconFor NOTE_ROW GROUP_ROW CHILD_NOTE_ROW CHILD_ROW SideToggleOf SIDE_TOGGLE_GAP SIDE_TOGGLE_NUDGE NewHeaderDisc NewShutCard Size DISC DISC_ICON OVERVIEW_ATLAS FLOOR_PIN CARD_INSET FOLD_INDENT CHILD_INDENT SET_MEMBER_INDENT ShowRankIcon ShowRecipeIcon ShowQuestIcons ShowArrows ShowFoldRow MarkerLine SetupQuestRow PaintHeader CreateList UpdateSectionCard PaintOverviewRow FoldedRows StartSlide FoldRowHolding LIST_TOP ShowOverviewRow ReachedGroup HasScarce INCLUDED_HEADERS PROFESSION_HEADERS StopSlide IndexOf`.

**Fix.** Win back a real margin (about 10) in the way `Overview.lua` did this release:

1. Group the row sizes the closure reads into one table, for example `local ROW = { GROUP = 28, CHILD = .., CHILD_NOTE = 36, NOTE = .., MARKER = .. }` and `local INDENT = { CHILD = 8, FOLD = 22, SET_MEMBER = 18 }`. That alone turns about eight upvalues into two.
2. Optionally, gather the dungeon-questline helpers (`QuestlineRow`, `FoldRowHolding`, `FoldedRows`, `ShowFoldRow`) and the profession Overview row's (`ShowOverviewRow`, `PaintOverviewRow`) into small file-level tables such as `local QuestlineRows = {}` and `local OverviewRow = {}`. They are read as one upvalue each.
3. Keep the comment at 1733 and give it the new count.

Behaviour stays the same pixel for pixel. The smoke runs and `luac -l -l` confirm the fix.

### R2 · New code names a chain's number `c`
- **Severity:** nit
- **Area:** Readability (meaningful names, avoid mental mapping)
- **Where:** `NeedRoll/Data/Data.lua:549` (`for _, c in ipairs(self.chainsOf[questID] ...)`), `560-571` (`function ns.Data:FittingChain(c, side, class, keptID)`), `578`; `NeedRoll/UI/DungeonQuestlines.lua:46-47, 72-73`
- **Status:** fixed in round 2 (`445bb1b`). It is now `chainIndex` in `RegisterChains`, `ChainsWith`, `FittingChain`, `Chain` and both `DungeonQuestlines.lua` loops, and `stepClass` in `StepFits`. A rename only: luacheck `--std lua51` finds no leftover `c`.

**What's wrong.** `c` is a chain's number in `ns.Data.chains`. `docs/READABLE-CODE.md` §8 keeps one-letter names only for `i`, `x`/`y`/`w`/`h` and `r`/`g`/`b`/`a`. The old `Data:Chain` used `c` too, but this release splits it into public functions (`ChainsWith`, `FittingChain`) whose parameter is now what other files read.

**Why it matters.** `FittingChain(c, side, class, keptID)` is called from another file (`DungeonQuestlines.lua:73`), and `c` doesn't say whether it is a chain, a class or a count.

**Fix.** Rename it to `chainIndex` (or `chainNumber`) in these functions and their loops. This is a rename only.

### R3 · `ChainStartOf`'s comment lists three returns; it returns two
- **Severity:** nit
- **Area:** Readability (avoid disinformation)
- **Where:** `NeedRoll/UI/DungeonQuestlines.lua:31-38`
- **Status:** fixed in round 2 (`f9533e0`). The comment now says the first quest's ID keys its questline, and lists two returns.

**What's wrong.**
```lua
-- Where `quest` is on a chain, on side `side`: the first quest of the
-- longest chain it is on (Data:Chain, as the quest page's chain), the key
-- of its questline, and the quest's step on it. Nil when ...
local function ChainStartOf(quest, side)
    ...
    return steps[1][1], at
```
It returns the first quest ID and the step. The "key of its questline" is that same ID (`BuildFold` uses `tostring(firstID)`), but the list reads as three values.

**Fix.** Write the comment as "the first quest of the longest chain it is on (Data:Chain, as the quest page's chain), which keys its questline, and the quest's step on it", or similar.

### R4 · A badly wrapped line in `CLASS_QUEST_BRANCH_NAMES`'s comment
- **Severity:** nit
- **Area:** Readability (consistent formatting)
- **Where:** `NeedRoll/Data/Data.lua:209-218`
- **Status:** fixed in round 2 (`addaa76`). The comment is re-wrapped like the lines around it.

**What's wrong.** One line of the comment, "-- it binds or whose orb it makes (Orb of Orahil), or the Skyborn's path (Forever's race, whose race ID QuestieDB", ran to 113 characters while the lines around it wrap near 80. `docs/READABLE-CODE.md` §2 asks for consistent formatting.

**Correction (round 2).** Round 1 placed this at line 211 and gave it as 140 characters and the line luacheck reports. That was wrong. The line luacheck reports, `Data.lua:211` at 140 characters, is the `L["Before the quest: ..."]` key, a locale literal that can't be split without changing the translation key, so it stays like `Welcome.lua:276`. The comment line was 113 characters, under the 120 cap, but out of step with its neighbours. The finding stands as that formatting nit.

**Fix.** Re-wrap the comment to match the lines around it.

### R5 · The notices' 14 px button gap is a bare number, now in two places
- **Severity:** nit
- **Area:** Readability (searchable names)
- **Where:** `NeedRoll/UI/Welcome.lua:216-218` and `293-295`
- **Status:** fixed in round 2 (`355bca1`). `local NOTICE_BUTTON_GAP = 14 -- between a notice's last part and its buttons` is used by both notices, and `docs/STYLE-GUIDE.md` names it.

**What's wrong.** Both notices compute their height with `... + 14 + notice.off:GetHeight() ...` and `... + 14 + notice.done:GetHeight() ...`, and a comment explains the 14 each time. The translation notice copied the drop notice's bare number. `docs/STYLE-GUIDE.md` names it ("the pills at the bottom right, 14 under the last part").

**Fix.** Add `local NOTICE_BUTTON_GAP = 14 -- between a notice's last part and its buttons` next to `NOTICE_GAP` and use it in both places.

### R6 · What a quest asks for reads "12 Giant Egg" in a row but "12 x Giant Egg" in its tooltip
- **Severity:** nit
- **Area:** Readability (one way of doing each thing)
- **Where:** `NeedRoll/UI/ProfessionOverview.lua:739` (`("%d %s"):format(need[2], ItemName(...))`) and `351` (`L["%d x %s"]:format(need[2], ItemName(...))`)
- **Status:** fixed in round 2 (`488731d`). `QuestSourceText` uses `L["%d x %s"]` too. The key already existed, so the locales are unchanged and `locales.py --check` passes.

**What's wrong.** The same fact, a quest's item count and name, is written two ways on one page. Only one of them goes through `L`, so translators can reorder or reword it in the tooltip but not in the row.

**Fix.** Use `L["%d x %s"]` in `QuestSourceText` too (the row then reads "From Dirge Quikcleave: 12 x Giant Egg, 10 x Zesty Clam Meat"). Or use one new `L["%d %s"]` key in both places and drop the other, and update the style guide's example to match.

### R7 · The questline page queues another full redraw for each refresh made before spell or item names arrive
- **Severity:** nit
- **Area:** Redundant code (repeated work)
- **Where:** `NeedRoll/UI/Questlines.lua:410-418` (`SpellNames` → `ClassSpells.Load(spellIDs, onLoaded)`), `437-447` (`RewardNames` → `ns.Items:Load(itemID, onLoaded)`), `1576` (`Purpose(line, function() if self:IsVisible() then self:Refresh() end end)`)
- **Status:** left as is: a perf trade-off, not worth code now. The redraws are brief, happen only while a name is uncached, and are correct.

**What's wrong.** Each `page:Refresh()` passes a new `onLoaded`. While a name is still uncached, `ClassSpells.Load` adds another `ContinueOnSpellLoad` callback, and `ns.Items:Load` another waiting callback, on every refresh. The page refreshes on resize (`OnSizeChanged`), on quest log changes and on each dungeon questline recheck. When the names arrive, every queued callback calls `page:Refresh()` directly. That is N full redraws in one frame: segments, joints, every card, line and fringe. The Classes section list (`RefreshSoon`) and the Professions Overview (`itemsAsked` plus `RefreshSoon`) already avoid this.

**Why it matters.** On a first login with an uncached teaching spell, dragging the window's size while the page shows queues dozens of redraws. It's brief, but avoidable.

**Fix.** Give the page one debounced callback, as `ProfessionOverview.lua:1270-1279` does. Also ask for each spell or item only once per page, for example a `page.namesAsked[id]` set or by passing `onLoaded` only on the first draw of a fold:

```lua
local isRedrawPending = false
local function RedrawSoon()
    if isRedrawPending then return end
    isRedrawPending = true
    C_Timer.After(0, function()
        isRedrawPending = false
        if page:IsVisible() then page:Refresh() end
    end)
end
```

### R8 · Two constants for one look: `DIM_ALPHA` and `DIMMED_ROW`, both 0.4 for "an alternative not taken"
- **Severity:** nit
- **Area:** Redundant code (one name per thing)
- **Where:** `NeedRoll/UI/Questlines.lua:36` (`DIM_ALPHA = 0.4 -- a branch not taken, once another is done`), `NeedRoll/UI/Lists.lua:1049` (`DIMMED_ROW = 0.4 -- a questline's alternative not taken, once another is done`)
- **Status:** fixed in round 2 (`38b987b`). `Questlines.DIM_ALPHA` is exported, and `Lists.lua` reads `ns.UI.Questlines.DIM_ALPHA` when it sets up the row (at run time, after `Questlines.lua` has loaded). `DIMMED_ROW` is gone.

**What's wrong.** The fold's part row (Lists) and the page's cards and pills (Questlines) dim the same thing by the same amount through two names. Change one and the fold and the page disagree.

**Fix.** Keep one, for example `Questlines.DIM_ALPHA`, exported next to `Questlines.FigureText`, and read it in `Lists.lua`. Or move it to `Theme`.

### R9 · `InUnlistedInstance` reads `GetInstanceInfo` twice and builds a table on every nameplate, target and mouseover inside any dungeon
- **Severity:** nit
- **Area:** Redundant code (work repeated per event)
- **Where:** `NeedRoll/Core/Drops.lua:216-223`; called from `NoteUnit` (`NAME_PLATE_UNIT_ADDED`, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `INSTANCE_ENCOUNTER_ENGAGE_UNIT`) and `IsBossCandidate`
- **Status:** fixed in round 2 (`6389091`). The function checks the cache with `CurrentInstance`'s ID, and calls `PlayerWhereabouts` only on a miss, as suggested. The `Core-Drops` unlisted-instance scenarios pass in all four smoke runs.

**What's wrong.**
```lua
local function InUnlistedInstance()
    if not CurrentInstance() then return false end      -- GetInstanceInfo, once
    local where = ns.Data:PlayerWhereabouts()            -- GetInstanceInfo again, a new table, :lower()
    if unlistedCheck.mapID ~= where.mapID then ... end
```
`CurrentInstance()` already returns the instance ID (`GetInstanceInfo`'s eighth return, the same as `where.mapID`). In any dungeon, listed or not, each mouseover and nameplate pays for a second `GetInstanceInfo`, a table and a string lowercase before the cache is consulted.

**Fix.** Check the cache with the ID `CurrentInstance` returns, and build `PlayerWhereabouts` only on a miss:
```lua
local function InUnlistedInstance()
    local _, instanceID = CurrentInstance()
    if not instanceID then return false end
    if unlistedCheck.mapID ~= instanceID then
        unlistedCheck = { mapID = instanceID, isUnlisted = not IsListedInstance(ns.Data:PlayerWhereabouts()) }
    end
    return unlistedCheck.isUnlisted
end
```

### R10 · Everything the window showed at each close stays loaded for the session (`Theme.kept` never shrinks)
- **Severity:** nit
- **Area:** Redundant code (caches)
- **Where:** `NeedRoll/UI/Theme.lua:505-548` (`KeepLoaded`, `DrawnImage`, `KeepLoadedUnder`), called from `MainFrame.lua:938` on every hide
- **Status:** left as is: a perf trade-off, not worth code now. The set is bounded by what a player views and the files are small.

**What's wrong.** Each close walks the whole window tree and adds every shown texture's file to `kept`. The window can be showing a layout map's 12 tiles (game file IDs), item icons, profession icons or a NeedRoll map `.tga`. Nothing is ever removed, so over a session the set holds every file that was on screen at any close, each pinned in texture memory by a 1 px texture on UIParent. The fix targeted the window's own chrome (the c60 rings, the native parchment), which a fixed list already covers (`PRELOAD_ATLASES`, `Theme.media`).

**Why it matters.** It's bounded by what a player views, and the files are small, so this isn't urgent. Still, a long session browsing many dungeon maps keeps every map's tiles loaded when only the chrome needed it.

**Fix.** Skip what the flash didn't involve, for example item and map art that comes by file ID. Or cap `kept` by count. Or keep only atlases and NeedRoll's own `Interface\AddOns\NeedRoll\` paths. At minimum, say in the comment that the set only grows.

### R11 · A creature known only from the loot window passes as a boss candidate, since its classification is never read
- **Severity:** nit
- **Area:** WoW API (game behaviour; drop data quality)
- **Where:** `NeedRoll/Core/Drops.lua:1000-1006` (`NoteLootSources` → `NoteCreature(Plain(sources[i]))` with no classification), `263-268` (`return seen.classification == nil or BOSS_CLASSIFICATIONS[...]`)
- **Status:** left as is: Mike's call, deferred after v0.16.0.

**What's wrong.** In an unlisted instance, `IsBossCandidate` accepts a creature whose classification is nil ("its kind couldn't be read"). The loot window path never has a unit token, so every creature first met in the loot window has a nil classification. Examples: a pack mob a group member pulled and killed while the player never targeted it, or one killed with enemy nameplates off. If only one of its kind has been looted so far, it passes as a boss. Its drops are then saved and shared on the realm channel as a boss kill.

**Why it matters.** In Krol'dok Stronghold, trash that a player never moused over can be shared as bosses. The scraper keeps these under the creature's NPC ID in `observed.json`, so Mike has to tell them apart by hand at ingest. The top comment covers "its kind couldn't be read", but not that this is the usual case for loot-only creatures rather than a rare one.

**Fix.** Either:
- (a) mark creatures first seen in the loot window (`seen.fromLoot = true`) and require a read classification for candidacy (a boss is almost always targeted or nameplated before it dies); or
- (b) keep the behaviour, and say in the New instances comment that a creature met only in the loot window counts as unread and so can pass.

Option (a) changes what is shared, so it's Mike's call.

### R12 · `RANK_CAPS` is unused, and its comment says the next rank comes 50 below the cap (it's 25)
- **Severity:** nit
- **Area:** Readability (avoid disinformation; dead code)
- **Where:** `scraper/needroll_scraper/professionguide.py:85-86`
- **Status:** fixed in round 2 (`714bf6f`). The constant and its comment are deleted. The scraper tests pass (272).

**What's wrong.**
```python
# The skill a rank lets you reach; the next rank is trained from 50 below it.
RANK_CAPS = (75, 150, 225, 300)
```
Nothing in the module reads `RANK_CAPS` (`grep -n RANK_CAPS` finds only this line). The comment is also wrong: Journeyman is trained at 50, 25 below Apprentice's 75. The addon has it right (`UI/ProfessionOverview.lua:62-63`, `NEXT_RANK_EARLY = 25 -- (Journeyman at 50)`).

**Fix.** Delete the constant and its comment.

### R13 · (#739) `named` is now written but never read
- **Severity:** nit
- **Area:** Redundant code (dead code)
- **Where:** `tests/smoke/wow.lua:184` (`local named = {}`), `236` (`named[name] = w`) at `c786123`
- **Status:** fixed in round 2 (`fecb7f1`). Both lines are gone, and `wow.lua`'s luacheck count drops from 100 to 99.

**What's wrong.** #739 removes `W.AllFrames()`, which was the only reader of `named`. luacheck reports the new warning "variable 'named' is mutated but never accessed".

**Fix.** Delete both lines. `_G[name] = w` on the line above keeps named frames reachable.

### R14 · (#739) `"${runArgs[@]}"` under `set -u` fails on bash older than 4.4 when no argument is given
- **Severity:** nit
- **Area:** Readability (a script that works everywhere it's documented to run)
- **Where:** `tests/smoke/check.sh:23` at `c786123`
- **Status:** fixed in round 2 (`bdfbab8`). The line is `${runArgs[@]+"${runArgs[@]}"}`, with a comment that says why. `bash -n` passes, and so do the plain `check.sh` and `check.sh --quick --verbose`.

**What's wrong.** The script runs with `set -u`, and on bash 4.3 and older, `"${runArgs[@]}"` with an empty array is an "unbound variable" error. The plain `tests/smoke/check.sh` (no `--quick`, no `--verbose`) then fails at once. GitHub's runners and Git for Windows ship bash 5, so CI and Mike's machine are fine. macOS's `/bin/bash` is 3.2.

**Fix.** Use `${runArgs[@]+"${runArgs[@]}"}` on that line, which expands to nothing for an empty array on any bash.

### R15 · (#739) PRs into dev no longer run the secret-values smoke run
- **Severity:** nit
- **Area:** WoW API (secret values)
- **Where:** `.github/workflows/smoke-tests.yml` (`QUICK`), `tests/smoke/check.sh` (`--quick` = dev and combat) at `c786123`
- **Status:** left as is: Mike's call, deferred after v0.16.0.

**What's wrong.** `--quick` keeps the dev and combat runs and drops `--packaged` and `--secret`. Combat and secret values are WoW: Forever's two hazards that the smoke stand-in can catch and players can't work around. A missing `issecretvalue` / `ns.Plain` guard now merges into dev green, and shows up only at the release PR into main, or in the daily data and Translations runs (full runs, but on main and on bot branches).

**Why it matters.** It's caught before players get it, but at release time, in the PR with the most else going on, and far from the change that caused it.

**Evidence.** Locally, all four runs took 43 s and `--quick` took 42 s, since the runs go in parallel on enough cores. The time saved comes from the runner's core count (two vCPUs on private repos), so a third run costs about half a run more there, not a whole one.

**Fix.** Consider `modes=("" "--secret" "--combat")` for `--quick`, dropping only `--packaged`, whose dev-only differences are the rarest source of breakage. That is Mike's trade-off to make.

## Area notes

### Readability

All new and changed Lua was checked against `docs/READABLE-CODE.md`. Every addon file starts `local _, ns = ...`, and new code uses 4-space indents and LF line endings.

The new modules read well. `Questlines.lua` is split into sections (the model, the fold rows, the trail, the page, the lines, the layout), each function does one named thing, and comments give the game reason (secret values, the 60-upvalue limit, a quest handed in shows a moment later). `ProfessionOverview.lua` does the same (text, links, tooltips, list rows by section, the drawn rows, the page). Constants carry their units and meaning (`CARD_GAP = 14 -- between cards one under the other (the arrow's room)`).

Long functions are constructors whose body is methods (`Questlines.AddTrail` 90 lines, `CreateProfessionOverview` 113), the addon's usual pattern. The one long closure that matters is R1.

No `cond and nil or x`, no patterns built from data (the one data-driven `find` uses `plain = true`), no `#t` over a table with holes, and no `k, v` loops over non-maps. Comments don't narrate the change. `Data.lua`'s moved helpers dropped the Overview copies, and `DropperName` is now one function instead of two.

Findings: R2, R3, R4, R5, R6, R12, R14.

### WoW API

Every game call, event, widget method, enum and atlas the release newly uses is in Ketho's `forever` lists:

| Name | Kind | In `forever` lists | Where looked |
| --- | --- | --- | --- |
| `C_Map.OpenWorldMap` | function | yes | GlobalAPI.lua |
| `C_Map.GetMapLevels` | function | yes | GlobalAPI.lua |
| `C_PvP.IsWarModeFeatureEnabled`, `C_PvP.IsWarModeDesired` | function | yes (nil-guarded anyway) | GlobalAPI.lua |
| `C_GameRules.IsGameRuleActive` | function | yes (nil-guarded) | GlobalAPI.lua |
| `Enum.GameRule.PvPRuleset` (213) | enum | yes, value 213 matches `wow.lua` | LuaEnum.lua |
| `ShowUIPanel` | FrameXML function | yes | FrameXML.lua |
| `C_SpellBook.IsSpellKnown`, `C_Spell.GetSpellName`, `C_CreatureInfo.GetRaceInfo`, `UnitRace`, `UnitClass`, `GetClassInfo`, `C_Item.GetItemNameByID`, `C_Item.GetItemIconByID`, `C_Item.IsItemDataCachedByID`, `C_QuestLog.IsQuestFlaggedCompleted`, `C_Texture.GetAtlasInfo`, `UnitClassification`, `UnitIsDead`, `GetLootSourceInfo`, `GetNumLootItems`, `GetMouseFoci`, `IsModifiedClick`, `GetLocale` | function (newly called in the touched code) | yes | GlobalAPI.lua |
| `NAME_PLATE_UNIT_ADDED`, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `INSTANCE_ENCOUNTER_ENGAGE_UNIT`, `WAR_MODE_STATUS_UPDATE`, `SKILL_LINES_CHANGED`, `SPELLS_CHANGED`, `PLAYER_LEVEL_UP`, `GLOBAL_MOUSE_UP`, `QUEST_TURNED_IN`, `QUEST_ACCEPTED`, `QUEST_REMOVED`, `QUEST_LOG_UPDATE`, `PLAYER_REGEN_ENABLED` | event | yes | Events.lua |
| `Texture:GetTextureFileID`, `GetTextureFilePath`, `SetRotation`, `SetTexCoord`; `FontString:GetUnboundedStringWidth`; `Frame:SetHyperlinksEnabled`; `Button:IsEnabled` / `SetEnabled`; `ScrollFrame:SetScrollChild` / `SetVerticalScroll` | widget method | yes | WidgetAPI.lua |
| `WorldMapFrame:SetMapID` / `GetMapID` | mixin method (MapCanvasMixin) | inferred (standard FrameXML; a fallback only after `C_Map.OpenWorldMap`) | n/a |
| `Spell:CreateFromSpellID` / `ContinueOnSpellLoad` | mixin | inferred (standard FrameXML, existing helper `ClassSpells.Load`) | n/a |
| `common-icon-checkmark`, `Exclamation-up-c60`, `Crosshair_Quest_96`, `Mode-Selection-Ring-c60`, `icons_64x64_poison` (also guarded by `GetAtlasInfo`), `collections-background-tile` | atlas | yes | AtlasInfo.lua |

Combat handling:
- **Opening the map.** `UI:OpenWorldMap`, `UI:OpenZoneMap`, `Chain.OpenInLog` and `UI:GoBack` to the world map all refuse in combat with `ns.UI.SayNoMapInCombat` ("Refuse or fall back and tell the player"), as the root `CLAUDE.md` asks. `GoBack` keeps the step so Back still works after the fight.
- **Smoke stand-in.** `wow.lua` now blocks `ShowUIPanel(WorldMapFrame)`, `C_Map.OpenWorldMap` and `QuestMapFrame_OpenToQuestDetails` in combat, so the `--combat` run catches a regression. `CHECKED_COMBAT_CALLS` is unchanged.
- **Secure frames.** No new secure frame or protected call. The Professions Overview's pin links use the existing `ns.UI.HoverMapLink`, whose secure button goes back to UIParent in combat. The `--combat` run passes.

Async data:
- Item names go through `ns.Items:Load` (`ITEM_DATA_LOAD_RESULT`) and spell names through `ContinueOnSpellLoad`. Neither is polled. R7 is about debouncing, not correctness.

Secret values:
- New reads of unit and instance data go through `ns.Plain`: `UnitGUID`, `UnitClassification`, `GetLootSourceInfo`, and `GetInstanceInfo` in `Data:PlayerWhereabouts`, which before the move read it raw in `Overview.lua`.
- No secret text is measured. `GetUnboundedStringWidth` only measures NeedRoll's own labels.

Locales, globals and the 60-upvalue limit:
- Player-facing text uses literal `L["..."]`, and `locales.py --check` passes.
- No new globals.
- R1 is the only function near 60 upvalues.

Smoke coverage:
- New scenario modules for the Professions Overview (18 scenarios) and dungeon questlines (5).
- New scenarios in `UI-Classes` (questline folds, page, trail), `Core-Drops` (unlisted instances), `UI-Welcome` (translation notice, combat waits), `UI-Wishlist` (unstar), `UI-MinimapButton`, `Core-Init` (`IsPvPRealm`), `UI-Theme` (`KeepLoadedUnder`) and `Core-Tooltip` (source icons).

`wow.lua` adds only names Forever has (`UnitIsDead`, `UnitClassification`, `C_GameRules`, `C_PvP`, `C_Map.GetMapLevels` / `OpenWorldMap`, `Enum.GameRule`). No dev-only code ships outside `--@debug@` (`MapLinksInCombat`'s fake-combat flag is inside one). `docs/STYLE-GUIDE.md` covers every UI change: questline rows and page, Professions Overview, star column, first-login notices, link box, minimap tooltip and the spot pin.

Findings: R1, R11, R15.

### Redundant code

Compared against:
- `Theme:Pill`, `Theme:Row`, `Theme:Text`, `Theme:Arrow`, `Theme:Star`, `Theme:Rounded`, `Theme:ScrollBar`, `Theme:ScrollColumn`, `Theme:Input`, `Theme:FactionToggle`, `Theme:JoinDots`, `Theme:Plural`, `Theme:LineWidth`
- `ns.Items:Load`, `ClassSpells.Load` / `ToggleRanks` / `PlaceOpenArrow`
- `PetPageKit.*`, `ns.UI.NearestFirst`, `ns.UI.PickNearestQuests`, `ns.UI.QuestStatus`, `ns.UI.HoverMapLink`, `ns.UI.ShowOnMap`, `ns.UI.SourceZone`

The release removes more duplication than it adds:
- `DropperName` (two copies to one, in `Data`), `PlayerWhereabouts` / `IsPlayerInside` (moved to `Data` and shared with Drops), `StripLayer` (now shared), `UI.IsWithin` (shared with the Classes trail).
- `CreateBadgeHeading` replaces HunterPets' copy of the class Overview's heading.
- `Theme:LinkBox` replaces Settings' inline box and serves the translation notice.
- `CreateRowStar` serves both Wishlist pages.
- `ns.UI.SkillRanks` / `GatherColor` / `QuestSource` are exported from LootGrid instead of copied.
- The new pages reuse `PetPageKit` and `ClassSpells` instead of their own rows.

No unused locals or functions were found in the touched files (a grep of every `local function` name). No `print` outside `@debug@`. No new `OnUpdate`.

Findings: R7, R8, R9, R10, R13.

### Security

Untrusted input touched: drop sharing. The release changes which kills are recorded and shared: boss candidates in unlisted instances (R11). It doesn't change how heard messages are parsed or sent. `SEEN_NPCS_MAX = 500` bounds the new per-run table, and it resets on a new zoneUID. The outbox, the one-a-minute rate and the "Share drops" setting are untouched.

Text shown from others: none new. The Professions Overview's and questline page's `|H` links carry only IDs and names from NeedRoll's generated data.

Names and credits:
- `NeedRoll/Credits.txt` is no longer written, and `.pkgmeta` now ignores it.
- The ingest writes credits only to `scraper/drops/credits.json`.
- The two credited names in this range (`credits.json`, `observed.json` `by`) are in `scraper/` only. A `git grep` of `NeedRoll/`, `tests/`, `docs/`, `.github/` and `tools/` finds neither.
- The translation notice links to the public `NeedRoll-locales` repo, and nothing here copies names there.

Scraper, workflows and tests:
- No requests to Wowhead. The new hand data cites Mike's saved pages, and the tests read the cache only.
- No `subprocess`, `shell=True`, `eval`, `pickle` or path building from downloaded data in `professionguide.py` or the `classquests.py` / `observed.py` diffs. Generated Lua strings go through `_lua_string`.
- `watcher-data.yml` reads the branch SHA via `gh api` with `github.token`, passes it through step outputs (a hex SHA from the API, not user text), keeps `permissions:` as before and uses `actions/cache` keyed by SHA.
- `smoke-tests.yml` (#739) passes its `QUICK` expression through `env:`, not into `run:`.
- No `pull_request_target`.

Findings: none.

## Round history

- 2026-10-22, round 1, `b8e87d9` (plus #739 at `c786123`): **Changes needed** (0 blocking, 1 should fix, 14 nits). Opened R1–R15 (R13–R15 for #739).
- 2026-10-22, round 2, `bdfbab8` (fixes `b7c7cbe..bdfbab8` on `2bd1026`, which includes #739 and #742): **Ready** (0 blocking, 0 should fix, 0 open).
  - Fixed: R1 `b7c7cbe`, R2 `445bb1b`, R3 `f9533e0`, R4 `addaa76`, R5 `355bca1`, R6 `488731d`, R8 `38b987b`, R9 `6389091`, R12 `714bf6f`, R13 `fecb7f1`, R14 `bdfbab8`.
  - Left as is: R7 and R10 (perf trade-offs, not worth code now), and R11 and R15 (Mike's call, deferred after v0.16.0).
  - R4's round 1 evidence was corrected.
  - Every changed function was re-read in full, and nothing new was found.
