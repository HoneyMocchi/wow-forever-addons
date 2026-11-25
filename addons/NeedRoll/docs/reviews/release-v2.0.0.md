# Review: v2.0.0 release (everything merged into dev since v1.9.0)

| | |
| --- | --- |
| Branch | `v1.9.0..origin/dev` (`ab72bbeb..0d0cd2f7`, PRs #985–#1010, 84 commits), plus the fixes `0d0cd2f7..9e906619` on `claude/project-thread-sg5l6z` (not pushed) into `dev` |
| Commit reviewed | Round 1: `0d0cd2f7`. Round 2: `9e906619` (`eed9d7df` Hotfixes.lua, then nine fix commits). Round 3 (migration only): `852279fb` (`135e4edf`, `f1030bac`, `e4f9f400`, `852279fb` on `9e906619`; this doc is the only uncommitted file) |
| Date | 2026-11-23 |
| Round | 3 (migration only: an extra focused pass the coordinator promised Mike, on `9e906619..852279fb`) |
| Verdict | **Ready, with the post-round-3 fixes not re-reviewed** (round 3 said Changes needed: 0 blocking, R17 should fix, R18 R19 nits; R17 and R19 fixed and R18 accepted after it, see Round history; R4, R10, R11 left as is). |
| Needs | Players: a **full game restart**. The release adds files the game reads only at start-up: `Core/Runs.lua` (in the `.toc`), `Data/Factions/AzerothCommerceAuthority.lua` and `Data/Factions/DurotarSupplyAndLogistics.lua` (in `Data/Data.xml`), and 72 new `Media/Maps` tiles (inferred, as in earlier reviews). The round 2 fixes alone need only `/reload`. SavedVariables: every per-character table changes key from `"<first name>-<realm>"` / `"<first name>-"` to the player GUID at each character's first login (`ns.MoveSavedDataToGUIDKey`, `Core/Init.lua:859-877`), and a realm-named key at a later login once its server's realm is known; the new `NeedRollDB.movedToGUIDKey` records which characters are done, the new `NeedRollDB.realmOfServer` maps a server ID to its realm name for the whole account; records gain `server`. The round 3 commits alone need only `/reload`. |

## What the change does

Players see: **PvP lists folded by class** (Honor Ranks, the battlegrounds and the Forever PvP factions put their gear under a fold per class, the player's own class and "All classes" open), with WoW: Forever's honor prices and Premier gear (price in Honor and marks, `costCurrency`); two new **factions** (Azeroth Commerce Authority, Durotar Supply and Logistics) priced in Merchant's Favor, and every Factions list splits its recipes into **one section per profession**; **quest status "Ready to turn in"** on quest rows, questline folds, cards (a new status tag) and the dungeon questline's Next step ("Turn in [quest] to [NPC]"); the **Dungeons list sorted by level**; the **world map floor chips** browse every level of NeedRoll's own map, the ones the game has no floor for too (Blackmaw Hold's five new levels); the **profession bar's ring** is 36 with a 28 icon; the **minimap button** leaves a button another addon reskinned alone; Mote of Unstable Magic is out of every loot list (scraper). Local checkouts only: the **run tracker** (`Core/Runs.lua` records each dungeon and raid run: bosses, drops, everyone's rolls; a "This run" section, roll grid and run history; a line under the minimap or a dock on the Objectives pane; kill and first-run cards; `/nr runs ...`), the **level-up window** (`/nr levelup`), `/nr devcommands`. Tooling: the watcher PR body is written by the new `watcher-pr` command; the `pvppages` command reads saved Wowhead honor vendor pages.

## Scope

Addon, shipped (each changed function read in full):

- `NeedRoll/NeedRoll.toc`: `Core\Runs.lua` added outside the `#@debug@` block (see the dev-only check under Area notes and R4).
- `NeedRoll/UI/UI.xml`: `LevelUp`, `RunPage`, `RunHistory`, `RunTracker`, `RunDemo` inside `<!--@debug@-->`.
- `.pkgmeta`: those five files ignored.
- `NeedRoll/Core/Init.lua`: run tracker defaults (debug block), `ns.ReadGameText`, `ns.GUIDCopy`, the `devCommandHelp` table, `/nr runs`, `/nr levelup`, `/nr devcommands` (debug block), a SectionMemory comment line.
- `NeedRoll/Core/Names.lua`: `Premier`, `Honor and marks` labels; `Names.IsRareNote`.
- `NeedRoll/Core/Runs.lua` (new, 1240 lines): the run recorder; lines 70–1240 in a `--@debug@` block.
- `NeedRoll/Data/Data.lua` (hand-written): `costCurrency`/`classes`/`forProfession` documented; `ns.Data:IsRareSpawn`.
- `NeedRoll/Data/Maps.lua` (hand-written): Blackmaw Hold's six levels.
- `NeedRoll/Data/Dungeons/TheDrownedCity.lua` (kept by hand): Tidebound Dagger added.
- `NeedRoll/UI/LootGrid.lua`: `TokenCosts`/`PriceText`/`TooltipPrice` (currency prices), `SectionKeys`/`ProfessionSection` (per-profession sections), class folds (`ItemClasses`, `ClassFolds`, `row:ShowClass`, `FoldMemory`, `OpenFold`, `OpenFoldOf`).
- `NeedRoll/UI/MainFrame.lua`: `LootFolds`, `UI.IsUsablePoint` (renamed), `UI.CreateBackedHost`, `UI:UseSavedSkin`, run page hooks guarded by `ns.RunPage`, unique item count.
- `NeedRoll/UI/Lists.lua`: `DungeonOrder`/`ORDER_BY_CATEGORY`, This run row hooks, `QUEST_WATCH_UPDATE`.
- `NeedRoll/UI/Overview.lua`: `IsReadyForTurnIn`, "Ready" status, `IsInLogStatus`, five floor names.
- `NeedRoll/UI/Questlines.lua`: `FirstInLog`, status tag (`FillTag`, `SetStatusTag`), `CardZoneText` without "Accepted".
- `NeedRoll/UI/DungeonQuestlines.lua`: `NextStepText`, `DistanceText` status, `QUEST_WATCH_UPDATE`.
- `NeedRoll/UI/WorldMapOverlay.lua`: level chips (`LevelChips`, `ChipFloors`, `MovesGameMap`, `IsShownFloor`, `PaintFloorChips`, `ShowFloor`), `drawnFor`.
- `NeedRoll/UI/Theme.lua`: `Theme:CloseButton` (taken out of `AddClearButton`).
- `NeedRoll/UI/DevKit.lua`: `StyledCard`, `FadeInCard`, `CardsBySkin` (debug block).
- `NeedRoll/UI/Settings.lua`: two run tracker rows hidden in a release (`IsRunTrackerLeftOut`).
- `NeedRoll/UI/ProfessionBar.lua`: ring 36, icon 28, top 14.
- `NeedRoll/UI/MinimapButton.lua`: `Restyle` guard.
- `NeedRoll/UI/ClassSpells.lua`: `RankRef` gains `level`, `spell`; `Load` returns its wait count.
- `NeedRoll/UI/Search.lua`, `NeedRoll/UI/TierSets.lua`: currency fields passed on; `ClassFoldKey` exported.
- `NeedRoll/Locales/enUS.lua`: 18 new strings, two moved.

Addon, local checkouts only (read for API, combat, secrets, privacy and readability; less line-by-line than shipped code): `NeedRoll/UI/RunTracker.lua` (read in full), `NeedRoll/UI/LevelUp.lua` (in full), `NeedRoll/UI/RunPage.lua`, `NeedRoll/UI/RunHistory.lua`, `NeedRoll/UI/RunDemo.lua` (entry points, tooltips, history hooks, demo data).

Tests: `tests/smoke/wow.lua` (new stand-ins), `tests/smoke/scenarios.lua` (Dungeons order), `tests/smoke/modules/*` (new Core-Runs, UI-RunTracker, UI-RunPage, UI-LevelUp; PvP folds, per-profession sections, Merchant's Favor, floor chips, Ready to turn in, minimap reskin), `tests/smoke/locales/*` (new references).

Scraper, tools and workflows: `scraper/needroll_scraper/pvppages.py` (new), `watcherpr.py` (new), `__main__.py`, `observed.py` (`UNIVERSAL_DROPS`, `drop_universal`), `forever_factions.py`, `knowndrops.py`, `emit.py`, `model.py`, `abilities.py`, `sources/cmangos.py`, `sources/questie.py`, their tests, `.github/workflows/watcher-data.yml`. Docs: `docs/STYLE-GUIDE.md`, `README.md`, `docs/NEW-COMPUTER.md`, `scraper/README.md`.

Round 3 (`9e906619..852279fb`, migration only, every changed function read in full):

- `NeedRoll/Core/Init.lua:650-877`: per-table merge rules (`TakeNewest`, `FillIn`, `JoinLists`, `JoinRuns`, `JoinChainClues`, a `Merge` per `PER_CHARACTER_TABLES` row), `MoveTableEntries` (guard clause), `RealmOfOldKey`, `IsRealmName`, `RealmNamedKeyOfMine`, `NoteRealmOfServer`, `OldKeysOfMine` and `MoveSavedDataToGUIDKey` reworked; `SavedRealmOf` removed.
- `NeedRoll/Core/Shopping.lua:212-224`: `MyRealmName` reads `NeedRollDB.realmOfServer` for this server before the record's realm.
- `NeedRoll/Data/Hotfixes.lua:49`: one entry reworded (R16).
- `docs/STYLE-GUIDE.md:989`: gold tooltip wording ("no realm name known").
- `tests/smoke/modules/Core-Init.lua`: `MOVED_TABLES` (adds `realmOfServer`), a merge scenario (old settings survive empty shells, runs and clue histories joined), a two-Flows-of-one-class scenario (each takes its realm's key once known, gold counted once); `Core-Shopping.lua`, `UI-Shopping.lua`: reset `realmOfServer`.

Skipped: generated data under `NeedRoll/Data/` (Abilities, Chains, ClassQuests, ClassSpells, CompanionSources, Data.xml, Dungeons/* scraper parts, the two new Factions files, Known*, PvP/*, Quests, VendorItems) and the scraper's JSON inputs (`scraper/**/*.json`, watcher imports), as asked; `NeedRoll/Media/` tiles, as asked. `NeedRoll/Data/DevDungeons.lua` is dev-only and hand-kept; its 6-line change was not reviewed.

## Checks

Lua 5.1 and luacheck weren't installed; installed `lua5.1` 5.1.5 and `luacheck` 1.2.0 for this review.

| Check | Result |
| --- | --- |
| `luac5.1 -p` on every changed Lua file (addon and tests) | passed |
| `luacheck --no-global -q`, changed vs `v1.9.0` | no new warnings in changed files. New files: `Core/Runs.lua` 4 (unused `self` at `:1008`, `:1024`, `:1085`, `:1226`, see R7); `LevelUp`, `RunDemo`, `RunHistory`, `RunPage`, `RunTracker` 0 |
| `luacheck` global writes (W111/W112/W121/W122) on the changed UI and Core files | 1, pre-existing (`Overview.lua:1555` `GameTooltip.needRollRule`, in v1.9.0 too); no new global |
| `tests/smoke/check.sh` (dev, packaged, secret values, in combat) | all passed (dev 250 files, packaged 236 files) |
| `tests/smoke/check.sh --locale all` | all 11 passed (126 English-text scenarios skipped on the 10 non-English clients, as designed) |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | passed (exit 0, no file changed) |
| `python3 tools/locale_strings.py --check` | passed (exit 0) |
| `python3 tools/font_coverage.py --check` | passed (exit 0) |
| `cd scraper && python3 -m unittest discover -s tests` | 580 tests OK |
| Ketho `forever` lists | `GlobalAPI`, `Events`, `WidgetAPI`, `LuaEnum`, `FrameXML`, `Templates`, `AtlasInfo`, `GlobalStrings/enUS` downloaded and grepped; see the WoW API table |
| **Round 2** (`9e906619`): `luac5.1 -p` on every Lua file changed in `eed9d7df..HEAD` | passed |
| Round 2: `luacheck --no-global -q`, each changed file vs `eed9d7df` | no new warnings; `Core/Runs.lua` 4 → 0 (R7) |
| Round 2: `tests/smoke/check.sh` | all four passed (dev 250, packaged 236, secret values, in combat) |
| Round 2: `tests/smoke/check.sh --locale all` | all 11 passed |
| Round 2: `locales.py --check`, `translations.py`, `locale_strings.py --check`, `font_coverage.py --check` | all exit 0, no file changed |
| Round 2: scraper unit tests | not rerun: round 2 changes no scraper file (580 OK in round 1) |
| Round 2: migration probe (R13, R14) | a throwaway smoke scenario run on a scratch copy of `HEAD`, not in the repo: the pre-71037 loot filter (`class`, `usable`) and remembered sections came out `nil` after `ns.MoveSavedDataToGUIDKey()`; with two realm-named paladin "Flow" records the gold list kept 4 rows and the total was live + 4000 (both stale records still added) |
| Round 2: `Data/Hotfixes.lua` wording | compared 9 of the 28 entries with Blizzard's post (fetched 2026-11-23): all in our own words but one (R16) |
| **Round 3** (`852279fb`): `luac5.1 -p` on `Core/Init.lua`, `Core/Shopping.lua`, `Data/Hotfixes.lua`, `tests/smoke/modules/Core-Init.lua`, `Core-Shopping.lua`, `UI-Shopping.lua` | passed |
| Round 3: `luacheck --no-global -q`, each of those vs `9e906619` | no new warnings (Init 11 → 11, Shopping 8 → 8, Hotfixes 274 → 274, Core-Init test 4 → 4, Core-Shopping test 1 → 1, UI-Shopping test 0 → 0) |
| Round 3: `tests/smoke/check.sh` | exit 0, all four modes passed (dev, packaged, secret values, in combat) |
| Round 3: `tests/smoke/check.sh --locale all` | exit 0, all 11 passed |
| Round 3: `locales.py --check`, `translations.py`, `locale_strings.py --check`, `font_coverage.py --check` | all exit 0, no file changed |
| Round 3: scraper unit tests | not run: no scraper file changed |
| Round 3: migration probe (R17, R18) | three throwaway scenarios on a scratch copy of `HEAD`, not in the repo (results under R17 and R18): a new same-class Flow took another server's `"Flow-Realm A"` and set `realmOfServer[2] = "Realm A"`; Bob on server 2 then left `"Bob-Realm B"` unclaimed; two servers both mapped to `"Realm A"`; a loot filter class cleared since build 71037 came back as `"PALADIN"` |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R17 | should fix | WoW API | `Core/Init.lua:786-802, 836-838, 870`; `Core/Shopping.lua:216-224` | A realm-named key claimed only because it was the one left sets the realm of the claimer's whole server: one wrong guess moves another character's data and blocks every other character on that server | fixed after round 3 (`e38e46f0`), not re-reviewed |
| R18 | nit | WoW API | `Core/Init.lua:704-712, 749-751` | `FillIn` can't tell a setting cleared since build 71037 from one never set: a cleared class filter, unticked loot type or re-ticked Known box comes back | accepted; comment added after round 3 (`9cd22864`) |
| R19 | nit | Readability | `Core/Init.lua:736-741` | `older.history = nil` in `JoinChainClues` is load-bearing and unexplained | fixed after round 3 (`d2805951`), not re-reviewed |
| R13 | **blocking** | WoW API | `Core/Init.lua:720-770` (`OldKeysOfMine`, `MoveEntries`) | The move to GUID keys keeps the newest entry whole and deletes the older: pre-71037 loot filter, remembered sections (and dev run history) lost for good | fixed in round 3 (`135e4edf`) |
| R14 | should fix | WoW API | `Core/Init.lua:715-741, 779`; `Core/Shopping.lua:299-318` | Two realm-named records of one first name are never claimed or removed: gold still counted twice, and the comments say they wait for their characters | fixed in round 3 (`852279fb`), option (a) |
| R1 | should fix | WoW API | `Core/Init.lua:652` (and its callers) | `ns.CharacterKey()` is "Flow-" since build 71037: per-character data orphaned, gold counted twice | fixed in round 2 (`9e906619`); its migration's R13, R14 fixed in round 3, R17 fixed and R18 accepted after it |
| R2 | should fix | Readability | `Core/Init.lua:591-597`, `Core/Runs.lua:84-86` | `ns.GUIDCopy`'s comment says the zoneUID tells runs apart; since 71037 it doesn't | fixed in round 2 (`92aa32f9`, `c92c53ef`) |
| R3 | should fix | Redundant code | `Core/Init.lua:498-523, 591-602`, `Data/Data.lua:1680-1691`, `Core/Names.lua:240-248` | Shipped helpers only dev-only code calls | fixed in round 2 (`c92c53ef`) |
| R4 | nit | Readability | `NeedRoll.toc:34-35`, `Core/Runs.lua:68-71`, `UI/Settings.lua:39-43` | `Core/Runs.lua` ships as 1170 lines of comment behind an `available` flag; every other dev module is left out | left as is (no reason given in the hand-off) |
| R5 | should fix | Redundant code | `UI/Lists.lua:3128-3146`, `UI/DungeonQuestlines.lua:469-479` | `QUEST_WATCH_UPDATE` refreshes the whole list once per objective tick | fixed in round 2 (`7481f5a5`) |
| R6 | nit | Redundant code | `UI/Overview.lua:229`, `UI/RunTracker.lua:271-274` | Nil guards on calls Ketho's `forever` lists have | fixed in round 2 (`44953502`) |
| R7 | nit | Readability | `Core/Runs.lua:1008-1096, 156-158`, `UI/RunPage.lua:198` | Two ways to write a self-less method in one file; PlayerName wrapped three times | fixed in round 2 (`4bc2703b`) |
| R8 | nit | Readability | `UI/RunTracker.lua:932, 794-796`, `UI/LootGrid.lua:393-395`, `Core/Init.lua:203-217` | Formatting slips and an incomplete area list | fixed in round 2 (`c90b518a`) |
| R9 | nit | Readability | `UI/ProfessionBar.lua:18-19`, `UI/RunTracker.lua:2, 160-161` | Comments narrate the design history | fixed in round 2 (`a555aa78`) |
| R10 | nit | Security | `tools/combatlog/Watch-WoW.ps1:127-136`, `Core/Runs.lua:10-13` | The watcher pushes every run's group names and rolls to `data/watcher`, which nothing reads | left as is: for Mike to decide later |
| R11 | nit | Readability | `Locales/enUS.lua:798-801`, `UI/LevelUp.lua:194-198, 287` vs `UI/RunPage.lua:16-18` | Two dev-only features, two rules for their words | left as is: for Mike to decide later |
| R12 | nit | Readability | `UI/RunTracker.lua:940-941` | `DockStatusText()` redraws the tracker | fixed in round 2 (`22afae4d`) |
| R15 | nit | Readability | `Core/Init.lua:760` | `ipairs(entries and oldKeys or {})` hides a guard clause | fixed in round 3 (`f1030bac`) |
| R16 | nit | Readability | `Data/Hotfixes.lua:49` | One hotfix entry is Blizzard's sentence minus "now" | fixed in round 3 (`e4f9f400`) |

### R17 · A realm-named key claimed only because it was the one left sets the realm of the claimer's whole server

- **Severity:** should fix
- **Area:** WoW API (SavedVariables migration for build 71037's empty `GetRealmName()`)
- **Where:** `NeedRoll/Core/Init.lua:786-802` (`RealmNamedKeyOfMine`: the first-move "exactly one left" branch, and `return nil` when a known realm matches no key), `:836-838` (`NoteRealmOfServer` overwrites, with no check that another server already has that realm), `:870` (every claimed key's realm noted for this server); `NeedRoll/Core/Shopping.lua:216-224` (`MyRealmName` shows and saves the noted realm)
- **Status:** open (round 3)

**What's wrong.** At a character's first move, with no realm known for its server, `RealmNamedKeyOfMine` takes a `"Name-<realm>"` key when it is the only candidate left:

```lua
if not isFirstMove then return nil end
...
if #possible == 1 then return possible[1] end
```

"The only one left" only means no other character of that first name, class and side wrote a key before build 71037. It doesn't mean this character wrote it. A character made since 71037 (or one that first ran NeedRoll since) has no realm-named key of its own. So when another server has a character of the same first name, class and side, the new one takes that character's key. Then `MoveSavedDataToGUIDKey` turns the guess into an account-wide fact:

```lua
for _, key in ipairs(oldKeys) do NoteRealmOfServer(serverID, RealmOfOldKey(key, name)) end
```

From then on, three things go wrong:
- `RealmNamedKeyOfMine` looks only for that realm on this server, and returns `nil` when no key matches (`if myRealm then ... return nil end`). Every other character on the server misses its own key.
- It does take the other server's key of any same-named character of matching class and side.
- `NoteRealmOfServer` never checks whether another server already has that realm, so two servers can end up mapped to one realm.

**Why it matters.** One wrong guess spreads to the whole server, and none of it can be undone:
- The new character takes the other character's data: its bank counts, loot filter, remembered sections, dev runs and chain-clue history (`questOffers`). When the real owner logs in later, its key is gone.
- Every other character on the wrongly-named server keeps its `"Name-<real realm>"` key unclaimed. Its gold is counted twice on the Shopping List: the stale record plus the live GUID record, which is R14's double count again. Its bank counts stay with the stale key, and its pre-71037 settings never come back.
- `MyRealmName` returns the wrong realm on that server, so `SaveCharacter` writes it into every record there (`record.realm`). The gold tooltip shows "Name-<wrong realm>". `IsOnMyServer` matches older records by realm name, so it counts alts on the other server as mailable and its own server's older alts as not.
- It all lasts until `GetRealmName()` names a realm again (`NoteRealmOfServer` at `:865` then overwrites the entry). Data already moved to the wrong GUID stays there.

It needs, on one account: a first name used on two servers by characters of the same class and side, one of them with no realm-named key, and that one logging in with v2.0.0 before any character on the other server. That is rare, but the same holds when the old key belongs to a deleted character. When it does happen, what goes wrong is exactly what this round was asked to rule out: another character's data claimed, and a server's characters losing theirs.

**Evidence.** A throwaway scenario on a scratch copy of `852279fb` (not in the repo):
- Setup: `characters = { ["Flow-Realm A"] = paladin, Alliance, 1000 gold; ["Bob-Realm B"] = mage, Alliance, 50 }`, `bank = { ["Flow-Realm A"] = { [2840] = 7 } }`, `realmOfServer` and `movedToGUIDKey` empty, `GetRealmName()` empty.
- A paladin Flow on server 2 logs in (`Player-2-0000000C`). `characters` becomes `Bob-Realm B=50, Player-2-0000000C=1000`, the bank moves to `Player-2-0000000C`, and `realmOfServer` = `2=Realm A`.
- Bob, a mage on server 2 (`Player-2-0000000D`), logs in: `Bob-Realm B` is not taken.
- The real Flow, on server 1 (`Player-1-0000000A`), logs in: nothing is left for it.
- Bob logs in again, now with `W.player.realm = "Realm B"`: only then is `Bob-Realm B` taken and `realmOfServer` = `2=Realm B`.
- A second scenario: an Ann rogue on server 3 takes the only `"Ann-Realm A"`, then a character on server 1 sees `GetRealmName()` = "Realm A". `realmOfServer` = `1=Realm A, 3=Realm A`.

The repo's scenario "two Flows of one class and side each take their own realm's key once it is known" relies on this same inference (the Alt on server 1 teaches "Realm A" by being the only `"Alt-"` key). The inference is right there only because the fixture's Alt really is on Realm A.

**Fix.** Keep what the game says apart from what NeedRoll guessed, and never let a guess block or steal:
- Note a realm for a server as **seen** only from `GetRealmName()`, or from a `FallbackKey()` that carries a real realm name. Seen realms decide claims at any login, as now.
- Note a realm as **guessed** when a key was taken only for being the one left. A guess must not overwrite a seen realm or a realm another server already has (one realm, one server). It may set keys aside for other servers (`isOtherServersRealm`), but it must not make `RealmNamedKeyOfMine` return `nil` for a key that is the only one left for that character. It must not reach `MyRealmName` either: show no realm rather than a guessed one.
- When a seen realm disagrees with a guess, drop the guess (and say in the comment that what the guess moved stays moved).
- Narrower alternative, if Mike prefers: at the first move, take a lone realm-named key only when its `characters` record exists and matches class and side (positive evidence, not "nothing says otherwise"), and still never note a realm that another server already has.

Add the probe above as a scenario: a new same-class Flow on server 2, then Bob on server 2. Assert that Bob gets `"Bob-Realm B"`, or at least that `realmOfServer[2]` isn't "Realm A" and server 2's gold counts Bob once.

### R18 · `FillIn` can't tell a setting cleared since build 71037 from one never set

- **Severity:** nit
- **Area:** WoW API (SavedVariables migration)
- **Where:** `NeedRoll/Core/Init.lua:704-712` (`FillIn` and its comment), `:749-751` (sections, `lootFilter`, `hideKnownPoisons` use it)
- **Status:** open (round 3)

**What's wrong.** `FillIn` copies every key the older entry has and the current entry lacks. Three of the settings it merges save "off" as a missing key:
- `UI/LootGrid.lua:2911`: `filter.class = token ~= filter.class and token or nil`. Every class is `nil`.
- `UI/LootGrid.lua:2881`: `ns.UI.LootFilter().types[self.key] = self:GetChecked() and true or nil`. An unticked type is `nil`.
- `UI/Poisons.lua:95`: `ns.db.hideKnownPoisons[ns.CharacterKey()] = not on or nil`. The ticked Known box (the default) is `nil`.

So a player who cleared one of these since build 71037 (under `"Name-"`) gets the pre-71037 value back. The same goes for a realm-named key claimed at a later login (R14's option (a)): weeks of use under the GUID key, and an old ticked type or class filter can still come back. "Items I can use" is safe, because its off step is `false` (`NEXT_USABLE_STEP`), not `nil`. The comment's "the states set before build 71037 and not touched since stay" is true, but it doesn't say that states cleared since come back too.

**Why it matters.** Once, after the update, a loot pane may filter to a class or armor type the player had turned off, or the poison list may hide known recipes again. It is visible and one click to undo, hence a nit.

**Evidence.** Probe on a scratch copy: `lootFilter = { ["Flow-"] = { types = {} }, ["Flow-Realm A"] = { class = "PALADIN", types = { cloth = true } } }`, `hideKnownPoisons = { ["Flow-Realm A"] = true }`. After the move: `class=PALADIN cloth=true hideKnown=true`. The code lines above were read at `852279fb`.

**Fix.** Pick one:
- Fill in only at the first move, from keys older than `"Name-"`. At a later-login claim, keep the GUID entry whole (`TakeNewest`), since the player has been choosing under it.
- Or for `lootFilter`, treat a `"Name-"` entry that is still the untouched shell (`{ types = {} }`, no `class`, no `usable`) as empty, and otherwise keep it whole.

Either way, say in `FillIn`'s comment that a setting cleared since can come back.

### R19 · `older.history = nil` in `JoinChainClues` is load-bearing and unexplained

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/Core/Init.lua:736-741`
- **Status:** open (round 3)

**What's wrong.**

```lua
current.history = JoinLists(current.history, older.history, "at", "quest")
older.history = nil
return FillIn(current, older)
```

The middle line reads like tidying up. Without it, `FillIn` would walk `older.history` index by index into the joined list:
- it would fill missing fields such as `done` from unrelated entries;
- it would append the older entries a second time past the end of the list.

The function also changes its `older` argument, which no other merge rule does.

**Why it matters.** A later reader who "cleans up" the line, or reuses `FillIn` on a table holding a list, silently corrupts chain-clue histories, and the scraper reads those for quest unlocks (`Core/Drops.lua:3603-3606`). READABLE-CODE: comments say why.

**Fix.** Add a comment: `-- FillIn would merge the two lists entry by entry: the joined list replaces older's.` Or build the result without touching `older`: `local joined = JoinLists(...); FillIn(current, older); current.history = joined`.

### R13 · The move to GUID keys keeps the newest entry whole and deletes the older

- **Severity:** blocking
- **Area:** WoW API (SavedVariables migration for build 71037's empty `GetRealmName()`, R1's fix)
- **Where:** `NeedRoll/Core/Init.lua:720-741` (`OldKeysOfMine`: `"Name-"` first, then `"Name-<realm>"`), `:757-770` (`MoveEntries`)
- **Status:** fixed in round 3 (`135e4edf`). Each table now merges its own way (`PER_CHARACTER_TABLES`, `Core/Init.lua:745-754`): `TakeNewest` for the record, bags and bank, `FillIn` for sections, the loot filter and the Known box, joined lists for runs and chain-clue histories. The new scenario "settings saved before build 71037 survive the empty ones NeedRoll wrote since" asserts the case this finding described, and my round 3 probe agrees. What is left is R18 (cleared settings come back).

**What's wrong.**

```lua
for _, oldKey in ipairs(entries and oldKeys or {}) do
    if IsEmpty(entries[newKey]) and not IsEmpty(entries[oldKey]) then entries[newKey] = entries[oldKey] end
    entries[oldKey] = nil
end
```

For every table, the first old key with any entry wins whole, and every other old key's entry is deleted. `"Name-"` (saved since 2026-11-21) comes before `"Name-<realm>"` (everything before it). `IsEmpty` counts only `nil` or `{}` as empty. NeedRoll creates entries on first use, though:
- `UI/LootGrid.lua:2460`: `ns.db.lootFilter[key] = ns.db.lootFilter[key] or { types = {} }`, on every loot pane draw.
- `Core/Init.lua:253-259`: `CurrentSectionSet`/`Area` create `sections.characters[key][area] = {}` on any page.

So any character that opened NeedRoll since build 71037 has a `"Name-"` shell that beats its real pre-71037 data.

**Why it matters.** At the first login with v2.0.0, a player's loot filter (class, "Items I can use", types) and every remembered open/shut section from before 2026-11-21 are deleted, and the move is marked done (`movedToGUIDKey`), so no later version can bring them back. Players already saw these settings "reset" after 71037. The migration is the one chance to restore them, and it erases them instead. The same rule drops older lists that should be joined: in dev builds, Mike's run history (`runs`) and chain-clue history (`questOffers`) saved before 71037 are deleted whenever any run or clue was saved since. Mike held v2.0.0 for this fix, and a migration can't be retried once shipped, so this blocks.

**Evidence.** A throwaway scenario on a scratch copy of `HEAD`:
- Setup: `lootFilter = { ["Flow-Old Realm"] = { class = "PALADIN", usable = 2, types = { CLOTH = true } }, ["Flow-"] = { types = {} } }`, and sections with real states under `"Flow-Old Realm"` and `{ loot = {} }` under `"Flow-"`.
- After `ns.MoveSavedDataToGUIDKey()`: `lootFilter[guid].class == nil`, `.usable == nil`, `sections.characters[guid].loot.WEAPONS == nil`, `.list == nil`.
- The old key was gone too.

The repo's own scenario ("a character's data saved under its old Name-Realm keys moves to its GUID once", `tests/smoke/modules/Core-Init.lua`) puts the loot filter and sections only under `"Flow-"`, so it can't see this.

**Fix.** Merge, don't pick, for tables a player builds up. Oldest first, newer over it:

```lua
-- Lays `newer` over `older` key by key, tables within tables too: what was changed since
-- build 71037 wins, what was set before it and not touched since stays.
local function Overlay(older, newer)
    for key, value in pairs(newer) do
        if type(value) == "table" and type(older[key]) == "table" then
            Overlay(older[key], value)
        else
            older[key] = value
        end
    end
    return older
end
```

- **`sections.characters`, `lootFilter`, `hideKnownPoisons`:** build the GUID entry as `Overlay(Overlay({}, realmNamed), nameDash)`, then lay anything already under the GUID key over that.
- **`runs`:** append the lists, oldest first (sort by `startedAt`), and keep the last `RUNS_KEPT`.
- **`questOffers`:** overlay `npcs` and concatenate `history`.
- **`characters`, `bags`, `bank`:** newest wins, as now. `SaveCharacter` and the bag scan rewrite them at once; the bank is newest when it exists.

Add a scenario with real data under `"Flow-<realm>"` and a `{ types = {} }` / `{ loot = {} }` shell under `"Flow-"`, asserting the old filter and sections survive. Until merged, the scenario's comment "this paladin 'Flow' saved under 'Flow-<realm>' before the build and 'Flow-' since" describes data that this bug would lose.

### R14 · Two realm-named records of one first name are never claimed or removed

- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/Core/Init.lua:715-741` (`OldKeysOfMine`, and its comment "both are left for their characters"), `:772-779` (`moved[guid] = true` either way), the `MoveSavedDataToGUIDKey` comment "Old keys of characters that haven't logged in since stay until they do"; `NeedRoll/Core/Shopping.lua:299-318` (`MoneyOnAllCharacters`)
- **Status:** fixed in round 3 (`852279fb`), option (a). `NeedRollDB.realmOfServer` maps a server ID to the realm name it was seen to go by (from `GetRealmName()` or a claimed key); `RealmNamedKeyOfMine` (`Core/Init.lua:786-802`) then picks the key of that realm at any login. With two candidates and no known realm, both still wait, and the `MoveSavedDataToGUIDKey` comment (`:852-858`) now says so ("its gold still counted"). The scenario "two Flows of one class and side each take their own realm's key once it is known" asserts the gold total (3 rows, live + 1005). Left by design: an account whose only characters on those two servers are the two Flows keeps the double count until `GetRealmName()` names a realm again. The realm learning has its own problem, R17.

**What's wrong.** With two pre-71037 keys `"Flow-Realm A"` and `"Flow-Realm B"` of the same class and side, `OldKeysOfMine` takes neither (`if #realmNamed == 1`). It still sets `moved[guid] = true`, so on later logins `isFirstMove` is false and they are never looked at again. When the second Flow logs in, the same rule leaves them again. The comments say the records wait "for their characters"; no code path ever gives them to anyone.

**Why it matters.** `MoneyOnAllCharacters` adds every non-current record, so both stale records stay in the gold total next to the two GUID records, for good. This is the double count R1 set out to end, on exactly the accounts that have it: two characters of one first name.

**Evidence.** The same throwaway scenario: records `"Flow-Realm A"` (1000) and `"Flow-Realm B"` (2000), both paladins logged in once (GUIDs `Player-1-…C`, `Player-2-…D`), the first saved again at 1000. `MoneyOnAllCharacters` returned 4 rows and live + 4000, where the right answer is 2 rows and live + 1000. The repo's "two characters of one first name" scenario asserts the records are left, but not what the gold shows.

**Fix.** Mike should pick one of these:
- (a) Tell the two apart once the realm of a server is known. After an unambiguous move, a record has both `server` and `realm`, so a later ambiguous login on that server can match `"Flow-<that realm>"`. That means re-checking on later logins (keep `moved[guid]` false while ambiguous keys remain).
- (b) Leave the old records out of the gold total and alt counts once a GUID record of the same first name, class and side exists, and say so.
- (c) Drop them, accepting the lost bank counts.

Whichever is chosen, fix the two comments so they say what happens, and extend the scenario to assert the gold total.

### R15 · `ipairs(entries and oldKeys or {})` hides a guard clause

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/Core/Init.lua:760`
- **Status:** fixed in round 3 (`f1030bac`): `MoveTableEntries` (`Core/Init.lua:843-850`) opens with `if not entries then return end`.

**What's wrong.** `for _, oldKey in ipairs(entries and oldKeys or {}) do` loops over nothing when the table doesn't exist. Readers have to work out the `and/or` (§4: guard clauses over tricks).

**Fix.** `local entries = SavedTable(path)` then `if entries then for _, oldKey in ipairs(oldKeys) do ... end end` (or a helper `MoveEntry(entries, oldKeys, newKey)` with `if not entries then return end`). This is moot if R13 rewrites `MoveEntries`.

### R16 · One hotfix entry is Blizzard's sentence minus "now"

- **Severity:** nit
- **Area:** Readability (root `CLAUDE.md`, Blizzard hotfixes: "in our own words, never Blizzard's text")
- **Where:** `NeedRoll/Data/Hotfixes.lua:49` (`eed9d7df`)
- **Status:** fixed in round 3 (`e4f9f400`): "Mote of Unstable Magic binds when picked up." (`Data/Hotfixes.lua:49`), our own words.

**What's wrong.** Ours: "Motes of Unstable Magic are soulbound." Blizzard's post (2026-11-19): "Motes of Unstable Magic are now soulbound." The other entries compared are reworded: Blade Flurry, Demonic Aegis, dungeon resets, Stormshroud Armor, Group finder, Seed Hybridizer (both), Cultivation (both).

**Fix.** Reword, e.g. "Mote of Unstable Magic binds to whoever picks it up."

### R1 · `ns.CharacterKey()` is "Flow-" since build 71037: per-character data orphaned, gold counted twice

- **Severity:** should fix (not blocking, see "Should it block?")
- **Area:** WoW API
- **Where:** `NeedRoll/Core/Init.lua:652-654`; callers `Core/Init.lua:248-254` (SectionMemory), `Core/Shopping.lua:176, 186, 218-222, 243-247, 279-283`, `UI/LootGrid.lua:2457-2461` (loot filter), `UI/Poisons.lua:89, 95`, `Core/Drops.lua:3630-3634` (chain clues, dev builds), `Core/Runs.lua:130-134` (dev only)
- **Status:** fixed in round 2 (`9e906619`): `ns.CharacterKey()` is the player GUID (`Core/Init.lua:667-671`), records carry `server` and `AltCounts` compares it (`Core/Shopping.lua:252-259`), the gold tooltip names a realm only where one was saved. Its one-time migration has two problems of its own, R13 (blocking) and R14

**What's wrong.**

```lua
function ns.CharacterKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end
```

Since build 71037 `GetRealmName()` returns `""` (reported by Mike; not checkable here), so every key is `"<first name>-"`. On WoW: Forever `UnitName` also returns only the first name ("Flow", with "State" as its second value, per `Core/Runs.lua:145-147`), so the key is now the first name alone. `Shopping.lua:221` saves `record.realm = GetRealmName()`, `""` too.

**Why it matters.** None of this code changed in v2.0.0: it broke for every NeedRoll version on 2026-11-21, and v2.0.0 doesn't make it worse. What players see:

- **Gold on the Shopping List counts each character twice.** `Shop:MoneyOnAllCharacters` (`Shopping.lua:277-295`) lists every `NeedRollDB.characters` key but `myKey`. A character that logged in before and after 71037 has two records, `"Flow-<realm>"` (money frozen at its last pre-71037 save) and `"Flow-"` (live), so the total adds a stale copy and the list shows the character twice.
- **Alts count wrongly.** `Shop:AltCounts` (`:243-247`) compares `char.realm == realm`: every record saved since 71037 has realm `""`, so alts on other realms (who can't mail) now count, and records from before 71037 stop counting until that alt logs in.
- **Per-character settings reset once and then collide.** Remembered sections (default "This character" mode, `Init.lua:253`), the loot filter (`LootGrid.lua:2460`), "hide known poisons" (`Poisons.lua:95`) and the bank counts (`Shopping.lua:176, 186`) start empty under `"Flow-"`, and two characters on the account with the same first name, on any realms, now share them. In dev builds the chain clue snapshots (`Drops.lua:3633`) of such characters mix, which can make false "newly available" quest links for the scraper.
- New in v2.0.0 and keyed the same way: the PvP class fold memory (`"lootClasses"`, `LootGrid.lua:2992`) and, dev only, `NeedRollDB.runs` (`Runs.lua:131`). Any later migration has to move `"Flow-"` data too.

**Should it block?** No. It isn't a regression from this range, raises no error or taint, and every NeedRoll version on the market already shows it. Releasing v2.0.0 doesn't change the data players have. It should go in a v2.0.x patch soon, because each week under `"Flow-"` adds data a migration must carry. The key format is a decision for Mike.

**Evidence.** Read `Init.lua:652-654`, `Shopping.lua:160-296`, `Drops.lua:3625-3640`, `LootGrid.lua:2450-2465`, `Poisons.lua:85-96`; `git log v1.9.0..origin/dev` shows no change to `CharacterKey` or `Shopping.lua`. `GetRealmName` and `GetNormalizedRealmName` are in Ketho's `forever` GlobalAPI (they exist; what they return on 71037 is Mike's observation).

**Fix.** Key characters by something the client still gives, and migrate once:

```lua
-- The player's GUID ("Player-<server>-<id>") is unique per character and doesn't change with
-- the realm name, which WoW: Forever's build 71037 left empty.
function ns.CharacterKey()
    local guid = ns.Plain(UnitGUID("player"))
    if guid then return guid end
    local name, realm = ns.Plain(UnitName("player")), ns.Plain(GetRealmName())
    return (name or "?") .. "-" .. ((realm and realm ~= "") and realm or "?")
end
```

At login, move each per-character table found under `"<first name>-<realm>"` or `"<first name>-"` to the new key (`sections.characters`, `bags`, `bank`, `characters`, `lootFilter`, `hideKnownPoisons`, `questOffers`, `runs`) when the new key has nothing yet, and drop the old record from `NeedRollDB.characters` so it isn't counted twice. Save `record.server` from the GUID and compare that in `AltCounts` in place of `realm`. If two old keys could be the same character (one name before and after 71037), prefer the newest record. Add smoke scenarios for an empty realm (`GetRealmName` returning `""` in `wow.lua`): gold counted once, alts on another server not counted, the migration run once.

### R2 · `ns.GUIDCopy`'s comment says the zoneUID tells runs apart; since 71037 it doesn't

- **Severity:** should fix
- **Area:** Readability
- **Where:** `NeedRoll/Core/Init.lua:591-597`; `NeedRoll/Core/Runs.lua:84-86`
- **Status:** fixed in round 2 (`92aa32f9`; the comment moved with the function in `c92c53ef`, `Core/Runs.lua:89-94`)

**What's wrong.** `Init.lua:594-596`: "Every run of a dungeon gets a zoneUID, but WoW: Forever hands the same small numbers out again to later runs, so only the server and the zoneUID together tell two runs apart (Core/Runs.lua)." `Runs.lua:84-85`: "GUID types made in the dungeon's own copy, whose zoneUID names it." Runs.lua's own header (`:48-54`) says the opposite: "Since build 71037 (2026-11-21) each creature's GUID has a server and zoneUID of its own, so they name no copy at all ... the GUIDs then decide nothing".

**Why it matters.** `docs/READABLE-CODE.md` §5 and §9: a wrong comment is worse than none. `Init.lua` is the shared helpers file a newcomer reads first, and it ships. Anyone reaching for `ns.GUIDCopy` to tell copies apart would build on a fact the game no longer gives.

**Evidence.** Lines quoted above, read side by side.

**Fix.** Say what the function returns and what the numbers mean now, e.g. "The type, server, map and zoneUID a creature, object or cast GUID carries. Up to build 70959 the server and zoneUID named the copy of a dungeon; since 71037 each creature has its own, so they no longer tell copies apart (Core/Runs.lua keeps them only to watch for that changing)." Fix `Runs.lua:84-85` the same way. If R3 moves `GUIDCopy` into `Runs.lua`, fix it there.

### R3 · Shipped helpers only dev-only code calls

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `Core/Init.lua:498-523` (`gameTextReaders`, `ns.ReadGameText`), `Core/Init.lua:591-602` (`ns.GUIDCopy`), `Data/Data.lua:1680-1691` (`RARE_RANKS`, `ns.Data:IsRareSpawn`), `Core/Names.lua:240-248` (`Names.IsRareNote`)
- **Status:** fixed in round 2 (`c92c53ef`): `GUIDCopy` is now local to `Runs.lua`'s debug block, `ReadGameText` and `IsRareSpawn` (with `IsRareNote` made local in `Data.lua`) sit in `--@debug@` blocks, the `ReadGameText` scenario is marked `dev = true`, and the `Init.lua` header no longer lists them

**What's wrong.** These ship in every release, but their only callers are dev-only:

```
NeedRoll/Core/Runs.lua:560   ns.GUIDCopy(guid)            (inside --@debug@)
NeedRoll/Core/Runs.lua:596   ns.GUIDCopy(castGUID)        (inside --@debug@)
NeedRoll/Core/Runs.lua:626   ns.ReadGameText(text, format)
NeedRoll/Core/Runs.lua:893   ns.ReadGameText(marked, line.format)
NeedRoll/Core/Runs.lua:226, UI/RunPage.lua:333, UI/RunDemo.lua:42   ns.Data:IsRareSpawn(...)
NeedRoll/Data/Data.lua:1688  ns.Names.IsRareNote(...)     (only from IsRareSpawn)
```

`Init.lua:3` also advertises `ns.GUIDCopy` and `ns.ReadGameText` as "small helpers every file shares".

**Why it matters.** In a release, about 60 lines are loaded and never called, and the header says otherwise. Mike's rule: less code unless it costs behaviour.

**Evidence.** `grep -rn "ReadGameText\|GUIDCopy\|IsRareSpawn\|IsRareNote" NeedRoll` (output above). The callers sit in `Runs.lua:70-1240` (`--@debug@`) and in the three `.pkgmeta`-ignored UI files.

**Fix.** Either wrap them in `--@debug@` where they are (and drop them from the `Init.lua:3` list), or move `GUIDCopy` and `ReadGameText` into `Runs.lua`'s debug block. `IsRareSpawn` with `IsRareNote` can sit in a `--@debug@` block in `Data.lua` / `Names.lua` until the run pages ship. Keep `ReadGameText` shared only if a shipped caller is planned. If you keep them on purpose, say in the comment that a release has no caller yet.

### R4 · `Core/Runs.lua` ships as 1170 lines of comment behind an `available` flag

- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** `NeedRoll/NeedRoll.toc:34-35`, `NeedRoll/Core/Runs.lua:68-71, 1240`, `NeedRoll/UI/Settings.lua:39-43`
- **Status:** left as is (no reason given in the round 2 hand-off)

**What's wrong.** It works (see the dev-only check under Area notes), but differently from every other dev module. `DropPull.lua`, `TrainerCheck.lua` and the five run and level-up UI files are left out of the build (`#@debug@` in the `.toc`/XML and `.pkgmeta`), and shipped code tests `ns.X and ...`. `Runs.lua` ships, its body becomes a `--[===[ ... ]===]` comment, and `Settings.lua:42` asks `ns.Runs.available`. That flag is the only shipped use of `ns.Runs`.

**Why it matters.** Two ways to say "dev only" (§6). The zip carries about 60 KB of commented-out code, parsed at every login.

**Evidence.** `grep -rn "ns\.Runs" NeedRoll` outside the dev files: only `Settings.lua:40-42`. The packaged smoke run loads 236 files with `Runs.lua` in it and passes.

**Fix.** Put `Core\Runs.lua` inside the `.toc`'s `#@debug@` block (with the DropPull one), add it to `.pkgmeta`'s ignore list, and make `IsRunTrackerLeftOut` return `ns.RunTracker == nil`. Then drop the `available` field and the header sentence about it (`Runs.lua:6-8`). The packaged smoke run then checks that nothing shipped reaches `ns.Runs`.

### R5 · `QUEST_WATCH_UPDATE` refreshes the whole list once per objective tick

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Lists.lua:3128-3146`, `NeedRoll/UI/DungeonQuestlines.lua:469-479`
- **Status:** fixed in round 2 (`7481f5a5`): both `Recheck`s queue one timer per burst (`isRecheckQueued`)

**What's wrong.** Both `Recheck`s schedule a new `C_Timer.After` on every event, with no pending flag:

```lua
local function Recheck()
    C_Timer.After(1, function()
        ns.UI.ForgetQuestStatus()
        if not pane:IsVisible() then ... elseif pane.grouped then pane:Refresh() end
    end)
end
...
ns:On("QUEST_WATCH_UPDATE", Recheck)
```

Before this release they listened only to hand-ins, accepts and removals. `QUEST_WATCH_UPDATE` fires on every objective step (each quest mob killed, each item looted).

**Why it matters.** With NeedRoll open on a dungeon's page while the group kills quest mobs, every kill rebuilds the encounter list and the questline page a second later, and wipes the quest status cache that `Overview.lua:244-247` keeps because "a status ... takes dozens of quest log calls". Ten kills in a pull mean ten full redraws. The addon handles the same bursts elsewhere: `WorldMapMarkers.lua:69-72` ("QUEST_LOG_UPDATE fires for every objective ... at most this often") and `Runs.lua:98-118` (`Changed`).

**Evidence.** Lines read. The `QUEST_WATCH_UPDATE` event is in Ketho's `forever` Events list.

**Fix.** Coalesce, as `Runs.lua`'s `Changed` does:

```lua
local isRecheckQueued = false
local function Recheck()
    if isRecheckQueued then return end
    isRecheckQueued = true
    C_Timer.After(1, function()
        isRecheckQueued = false
        ...
    end)
end
```

`ForgetQuestStatus` already runs on `QUEST_LOG_UPDATE` (`Overview.lua:382-384`), so the timer's own call is the late re-read the comment explains, and one per burst is enough.

### R6 · Nil guards on calls Ketho's `forever` lists have

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Overview.lua:229`; `NeedRoll/UI/RunTracker.lua:271-274` (dev only)
- **Status:** fixed in round 2 (`44953502`)

**What's wrong.** `if not (C_QuestLog.ReadyForTurnIn and C_QuestLog.IsOnQuest(questID)) then return false end`: `C_QuestLog.ReadyForTurnIn` is in the `forever` GlobalAPI list. `TextWidth` tests `fontString.GetUnboundedStringWidth`, which is in WidgetAPI's FontString methods.

**Why it matters.** A guard suggests the call might be missing on some client, so a reader looks for a fallback that doesn't exist. It's a small amount of extra code.

**Evidence.** `grep '"C_QuestLog.ReadyForTurnIn"' GlobalAPI.lua` and `grep '"GetUnboundedStringWidth"' WidgetAPI.lua` (forever): both found.

**Fix.** `if not C_QuestLog.IsOnQuest(questID) then return false end`, and call `fontString:GetUnboundedStringWidth()` directly.

### R7 · Two ways to write a self-less method in one file; PlayerName wrapped three times

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/Core/Runs.lua:1008, 1019, 1024, 1029, 1034, 1039, 1045, 1051, 1056, 1065, 1071, 1085, 1226` and `:156-158`; `NeedRoll/UI/RunPage.lua:198`
- **Status:** fixed in round 2 (`4bc2703b`): all `Runs` methods are written `Runs.X()  -- called as Runs:X()`, luacheck 4 → 0, one `Runs:PlayerName()` for the pages

**What's wrong.** `function Runs:Current()`, `Runs:List()`, `Runs:StartNew()` and `Runs:PrintList()` never use `self` (luacheck: 4 "unused argument self"). Their neighbours are written `function Runs.IsDemo()  -- called as Runs:IsDemo()`, the `Theme.lua` way. `PlayerName` is `UnitNameOf("player")` (`Runs.lua:156`), wrapped as `Runs.PlayerName` (`:1019`), and wrapped again as `RunPage.PlayerName` (`RunPage.lua:198`).

**Why it matters.** §6: one way per thing. Readers stop at each style switch, and luacheck's 4 warnings hide new ones.

**Fix.** Write the four as the others (`function Runs.Current()  -- called as Runs:Current()`, using `Runs` for the inner `self:Current()` in `PrintCurrent`). Drop the local `PlayerName` for `UnitNameOf("player")` and let the pages call `Runs:PlayerName()`.

### R8 · Formatting slips and an incomplete area list

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/RunTracker.lua:932`, `:794-796`; `NeedRoll/UI/LootGrid.lua:393-395`; `NeedRoll/Core/Init.lua:203-217`
- **Status:** fixed in round 2 (`c90b518a`)

**What's wrong.**
- `RunTracker.lua:932`: `return true` is indented 20 spaces inside a 12-space block (`cat -A` above).
- `RunTracker.lua:794-796`: "and sizes the header to fit / -- both lines." is broken mid-sentence onto a short line.
- `LootGrid.lua:393-395`: "-- A price paid in a currency (costCurrency, costCurrencyCount: Honor, / -- Merchant's Favor) / -- and in another item ..." is broken the same way.
- `Init.lua:203-217` lists every SectionMemory area "each mapping a stable key ... to that section's state". The new `"lootClasses"` area (`LootGrid.lua:2992`, PvP class folds by `"CLASS:<token>"`) isn't in it.

**Fix.** Re-indent `RunTracker.lua:932` to 12 spaces, reflow the two comments, and add `--   "lootClasses": the loot pane's PvP class folds, by "CLASS:<token>" ("CLASS:ALL" for All classes);` to the list.

### R9 · Comments narrate the design history

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/ProfessionBar.lua:18-19`; `NeedRoll/UI/RunTracker.lua:2, 10, 160-161` (dev only)
- **Status:** fixed in round 2 (`a555aa78`)

**What's wrong.** "It filled 28 of a 30 ring and spilled past it (Mike, 2026-11-23)." "Mike picked mockups B and C, 2026-11-23". "the d-pad art sits small in its frame (Mike: 14, then 1.5 and 1.75 times)".

**Why it matters.** §5: no narration of the change. The reason for the value stays. How it got there belongs in the PR.

**Fix.** Keep the why ("the ring art's band takes the outer part of its frame, so the icon is 28 of its 36"; "the d-pad art sits small in its frame, so the button is 37 to show it at the size of the others") and drop the history.

### R10 · The watcher pushes every run's group names and rolls to `data/watcher`, which nothing reads

- **Severity:** nit
- **Area:** Security (privacy)
- **Where:** `tools/combatlog/Watch-WoW.ps1:127-136`; `NeedRoll/Core/Runs.lua:10-13`; `scraper/needroll_scraper/__main__.py:650-651`
- **Status:** left as is: for Mike to decide later

**What's wrong.** In a dev build, `NeedRollDB.runs` keeps the name and class of everyone grouped with Mike's characters and every roll they made. The watcher copies the whole `NeedRoll.lua` SavedVariables to `scraper/cache/savedvars/` and pushes it to `data/watcher`. The ingest never reads `runs`, as the new comment at `__main__.py:650-651` says.

**Why it matters.** It's allowed: `data/watcher` stays in this private repo, and the workflow comment says so (`watcher-data.yml:36-40`). But other players' names and loot behaviour now sit in git history for no use. Root `CLAUDE.md` asks that names never reach anything public, and data never collected can't leak.

**Fix.** Optional. Have `Copy-SavedVariables` drop the `["runs"]` table before pushing (or have the watcher skip SavedVariables lines under it), or record Mike's acceptance here.

### R11 · Two dev-only features, two rules for their words

- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** `NeedRoll/Locales/enUS.lua:798-801`; `NeedRoll/UI/LevelUp.lua:194, 198, 287`; vs `NeedRoll/UI/RunPage.lua:16-18`, `NeedRoll/UI/RunTracker.lua:32`, `NeedRoll/UI/Settings.lua:101-118`
- **Status:** left as is: for Mike to decide later

**What's wrong.** The run pages keep English in `TEXT` "so translators aren't asked for phrases no release shows". The level-up window, also local checkouts only, puts three new phrases in the English list ("Earlier levels (%d)", "Nothing new to train", "Skills to train"), and the locale references now carry them to translators.

**Fix.** Pick one rule for dev-only words and say it once in `docs/READABLE-CODE.md` or `implementer.md`. Either move the three into a `TEXT` table in `LevelUp.lua`, or accept translating ahead because it is about to ship.

### R12 · `DockStatusText()` redraws the tracker

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/RunTracker.lua:940-941` (dev only)
- **Status:** fixed in round 2 (`22afae4d`): `/nr runs dock` refreshes first; the other callers (`SetDockSide`, `SetDockOff`, `RunDemo.Command`) already did

**What's wrong.** `function RunTracker.DockStatusText() RunTracker.Refresh() ...`: a function named for the text it returns also redraws the dock and the line (§9).

**Fix.** Call `RunTracker.Refresh()` in `/nr runs dock`'s handler (`Init.lua:1113-1114`) and in `RunDemo.Command`, and keep `DockStatusText` read-only, or name it `RefreshAndDescribeDock`.

## Area notes

### Readability

Checked every changed shipped function against `docs/READABLE-CODE.md`. Names are in game terms throughout (`TokenCosts`, `ProfessionSection`, `ClassFolds`, `FoldMemory`, `NextStepText`, `FirstInLog`, `LevelChips`, `MovesGameMap`). A grep for one-letter or cryptic locals in the 5,628 added Lua lines found none outside the allowed aliases. Fixed numbers are named (`CLASS_FOLD`, `PROFESSION_SECTION_PREFIX`, `CARD`, `BADGE.ICON_SIZE`). Guard clauses are used and nesting stays at three levels or fewer. 4-space indents, LF and no line over 120 in added code (checked with awk), apart from R8. `local _, ns = ...` heads every new file. Lua 5.1 traps: no `cond and nil or x`. `Sectioned`'s sort never compares a string key with a number, because every Professions item becomes a named key when `byProfession` is on. `ns.ReadGameText` escapes through `ns.GameTextPatterns`. The run pages' `#` uses are on dense arrays. Comments explain the game facts behind the code (secret values, upvalue-free helpers, packager behaviour). Exceptions are R2 (wrong), R8 (incomplete) and R9 (history). `Theme:CloseButton` takes over the clear button's strokes, so the cross exists once. `UI.CreateBackedHost` is shared by Settings and the run history.

### WoW API

Every call, event, method, template, atlas, Enum and global string the range adds or newly calls, against Ketho's `forever` lists (downloaded 2026-11-23):

| Name | Kind | In `forever` lists | Where looked |
| --- | --- | --- | --- |
| `C_CurrencyInfo.GetCurrencyInfo` | function | yes | GlobalAPI |
| `C_Item.GetItemSubClassInfo`, `C_Item.GetItemNameByID`, `C_Item.RequestLoadItemDataByID`, `C_Item.IsItemDataCachedByID`, `C_Item.GetItemIconByID` | function | yes | GlobalAPI |
| `C_QuestLog.ReadyForTurnIn`, `C_QuestLog.IsOnQuest` | function | yes | GlobalAPI |
| `C_PartyInfo.GetLootMethod`, `C_ClassColor.GetClassColor`, `C_Spell.GetSpellTexture`, `C_Texture.GetAtlasInfo`, `C_Map.OpenWorldMap`, `C_Timer.After` | function | yes | GlobalAPI |
| `GetInstanceInfo`, `GetNumSavedInstances`, `GetSavedInstanceInfo`, `RequestRaidInfo`, `IsInRaid`, `UnitName`, `UnitClass`, `UnitGUID`, `UnitExists`, `UnitIsGhost`, `BreakUpLargeNumbers`, `tContains`, `wipe`, `issecretvalue`, `hooksecurefunc`, `date`, `time` | function | yes | GlobalAPI |
| `GetNumLootItems`, `GetLootSlotType`, `GetLootSlotLink`, `GetLootSlotInfo`, `GetLootSourceInfo`, `GetLootRollItemLink`, `GetLootRollItemInfo` | function | yes | GlobalAPI |
| `ButtonFrameTemplate_HidePortrait`, `GameTooltip_Hide`, `GameTime_GetFormattedTime` | FrameXML function | yes | FrameXML |
| `QUEST_WATCH_UPDATE`, `CHAT_MSG_LOOT`, `CHAT_MSG_SYSTEM`, `ENCOUNTER_START`, `ENCOUNTER_END`, `INSTANCE_ENCOUNTER_ENGAGE_UNIT`, `GROUP_ROSTER_UPDATE`, `LOOT_READY`, `LOOT_OPENED`, `LOOT_CLOSED`, `START_LOOT_ROLL`, `NAME_PLATE_UNIT_ADDED`, `PARTY_KILL`, `PLAYER_ENTERING_WORLD`, `PLAYER_LEAVING_WORLD`, `PLAYER_TARGET_CHANGED`, `UPDATE_MOUSEOVER_UNIT`, `UNIT_SPELLCAST_START`, `UNIT_SPELLCAST_SUCCEEDED`, `UPDATE_INSTANCE_INFO`, `PLAYER_LEVEL_UP`, `UI_SCALE_CHANGED`, `ADDON_LOADED` | event | yes | Events |
| Widget methods in added code (`CreateAnimationGroup`, `SetToFinalAlpha`, `SetFromAlpha`, `SetToAlpha`, `IsOwned`, `GetUnboundedStringWidth`, `SetNormalAtlas`, `SetPushedAtlas`, `SetHighlightAtlas`, `GetEffectiveAlpha`, `StartMoving`, `StopMovingOrSizing`, `IsMouseOver`, `SetClampedToScreen`, `RegisterForDrag`, `SetDesaturated`, `SetMaxLines`, `HookScript` and the rest) | method | yes (scripted check: no method in added lines missing but the two below) | WidgetAPI |
| `GameTooltip:SetHyperlink`, `GameTooltip:SetItemByID` | method | inferred: not in WidgetAPI's `GameTooltip`; FrameXML tooltip data mixin methods, used in 12 shipped spots already | WidgetAPI, existing code |
| `ButtonFrameTemplate` | template | yes | Templates |
| `ObjectiveTrackerHeaderFont`, `ObjectiveTrackerLineFont` | font object | yes | Templates (looked up through `_G` with fallbacks) |
| `UI-QuestTracker-Secondary-Objective-Header`, `UI-QuestTrackerButton-Secondary-Collapse(-Pressed)`, `...-Expand(-Pressed)`, `UI-QuestTrackerButton-Yellow-Highlight`, `UI-QuestTracker-Tracker-Check`, `uitools-icon-external-window`, `uitools-icon-collapse-window`, `Gamepad-Xbox1-DOnlyLeft-Normal`, `Gamepad-Xbox1-DOnlyUp-Flat-Normal`, `gamepad-actionbar-circleslot-dropshadow`, `common-icon-checkmark` | atlas | yes (and each is checked with `HasAtlas` before use) | AtlasInfo |
| `Enum.ItemClass.Recipe`, `Enum.ItemRecipeSubclass.*`, `Enum.ItemQuality.Uncommon/Common`, `Enum.LootMethod.Masterlooter`, `Enum.LootSlotType.Item` | Enum | yes | LuaEnum |
| `INSTANCE_RESET_SUCCESS`, `INSTANCE_RESET_FAILED`, `INSTANCE_RESET_FAILED_ZONING`, every `LOOT_ROLL_*` and `LOOT_ITEM_*` in `Runs.lua:828-857`, `UNKNOWNOBJECT` | global string | yes | GlobalStrings/enUS |
| `ObjectiveTrackerFrame`, `EditModeManagerFrame`, `Minimap`, `GameTooltip`, `UIParent` | global frame | inferred (frames are in no list). `ObjectiveTrackerFrame` and `EditModeManagerFrame` are nil-guarded (`RunTracker.lua:671, 1029`); `Minimap`, `GameTooltip`, `UIParent` always exist | — |

- **Removed globals:** none used. Items go through `C_Item.*`.
- **Async data:** the Merchant's Favor and mark names ask `C_Item.RequestLoadItemDataByID` and show on the next hover (`LootGrid.lua:413-416`). `OnLootLine` waits with `ns.Items:Load` (`ITEM_DATA_LOAD_RESULT`). `LevelUp:Show` waits for spell names through `ClassSpells.Load`. Nothing polls.
- **Secret values:** every value `Runs.lua` reads from the game goes through `Plain` or `issecretvalue` before use (`:123-126, 150, 254-257, 396-399, 471, 555, 592, 623, 667, 684-688, 760-773, 793-809, 978`). Shipped code adds no new secret-capable read.
- **Combat:** the only map call in the range, `ShowFloor` (`WorldMapOverlay.lua:351-360`), refuses in combat with a message (`MapLinksInCombat`/`SayNoFloorChangeInCombat`). A level-only chip draws NeedRoll's own layer, which is allowed. No new `SetPropagate*`/`SetPassThroughButtons` call (grep of the added lines). `CHECKED_COMBAT_CALLS` is unchanged. The `--combat` smoke run passes. The run tracker (dev) only reads the Objectives pane and post-hooks it (`HookScript`, `hooksecurefunc` on `SetCollapsed`), anchors its own frames to it, and moves only its own frames, which is allowed in combat.
- **Locales:** the new shown text goes through literal `L["..."]` in shipped files. The two English Settings rows (`Settings.lua:104, 112`) are hidden in a release. Floor names are NeedRoll's own (Maps.lua), translated through `FLOORS`. Item subclass names come from the game (`GetItemSubClassInfo`). The run code reads game lines only with the client's own globals through `ns.ReadGameText` (no English matched). `--locale all`, `locale_strings`, `font_coverage` and `locales --check` all pass.
- **Smoke stand-ins:** each new call has a `wow.lua` stand-in (`ReadyForTurnIn`, `GetCurrencyInfo`, `GetItemSubClassInfo`, `GetLootMethod`, the loot and saved-instance calls, `ObjectiveTrackerFrame`, `EditModeManagerFrame`). `wow.lua` defines no global missing from Forever: the new ones are all in Ketho's lists or are frames or namespaces. Each feature has a scenario: PvP class folds, per-profession sections, Merchant's Favor prices, floor chips, Ready to turn in (`W.readyQuests`), the reskinned minimap button, Dungeons by level, and the dev features in Core-Runs, UI-RunTracker, UI-RunPage and UI-LevelUp.
- **Upvalues:** `CreateOverview` is untouched. `CreateLootGrid` swaps `FoldMemoryKey` for `FoldMemory` (no net upvalue). Every file compiles and loads under Lua 5.1.
- **STYLE-GUIDE.md:** updated in the same range for every UI change: Close cross, profession ring 36/28/14, PvP class folds, quest status tag and "Ready to turn in", floor chips, run tracker (local checkouts only), level-up window. Values were read from the code and matched where sampled (`ProfessionBar` row at `STYLE-GUIDE.md:349`).
- **Realm key:** R1.

**Dev-only check (the caller's point 1).** In a packaged build:
- **`Core/Runs.lua`**: `Runs.lua:70` `--@debug@` to `:1240` `--@end-debug@` encloses everything but `ns.Runs = { available = false }`. The BigWigs packager turns the block into a comment, so no event is registered, nothing is recorded, and `available` stays false. No `]===]` in the file could end that comment early (grep: 0).
- **The five UI files**: `LevelUp`, `RunPage`, `RunHistory`, `RunTracker` and `RunDemo` are both `.pkgmeta`-ignored and inside UI.xml's `<!--@debug@-->`.
- **`Core/Init.lua`**: the `runs`, `runProgressLine`, `runKillCards` and `runIntroShown` defaults (`:72-88`) and `/nr runs`, `/nr levelup`, `/nr devcommands` (`:1062-1208`) sit in debug blocks, so those words toggle the window like plain `/nr`.
- **`UI/DevKit.lua`**: the cards sit in its debug block.
- **Shipped references**: MainFrame (`:1231-1232, 1874, 2042, 2418`) and Lists (`:2545, 2592, 2877`) test `ns.RunPage` first (`header.runPage` exists only from `RunPage.ListEntry`). `UI.contentPages` gets a trailing nil. Settings hides its two rows with `isHidden`.
- **The packaged smoke run** loads 236 files and passes.

No dangling reference. The only shipped leftovers are dead code (R3), the comment block and its flag (R4), and three translator strings (R11).

### Redundant code

Compared against `Theme:Pill`, `Theme:Row`, `Theme:Label`, `Theme:Rounded`, `Theme:ClassBadge`, `Theme:JoinDots`, `Theme:ColorCode`, `Theme:SetTextColor`, `Theme:FitAtlas`, `Theme:MaskRound`, `ns.UI.MiniPin`, `ns.SectionMemory`, `ns.Items:Load`/`Quality`, `ns.UI.IsUsablePoint`, `ns.ReadGameText`/`GameTextPatterns`, `TierSets.ClassFoldKey`, `ns.UI.SetClassColor`, `ns.UI.ClassName`, `ns.Money`. The range removes two copies: `Theme:CloseButton` replaces the clear button's own strokes, and `FillTag` serves both card tags. The class folds reuse `TierSets`' key format and `Theme:ClassBadge`, and the cards reuse `Theme:Pill`. No new `OnUpdate` without a reason: `DevKit.CountDown` runs only while a card shows, and `CheckLineHover` only while the line can dock, every 0.1 s. Findings: R3 (shipped dead code), R5 (per-event redraws), R6 (needless guards), R7 (wrappers).

### Security

- **Addon untrusted input:** no shipped file that reads addon messages or other players' chat changed (`Core/Drops.lua`, `Core/DropPull.lua` untouched). The dev-only recorder reads `CHAT_MSG_LOOT`/`START_LOOT_ROLL`, which the game writes. A player name from a loot line is refused if it holds `|` or the link mark (`Runs.lua:872-874`). Item links are matched with anchored patterns, and nothing from them is run or sent. Roster names come from `UnitName`. Nothing in the range sends anything: no `SendAddonMessage`, no outbox change, no `loadstring`/`RunScript`/`setfenv`.
- **Names:** none of the 535 names in `scraper/drops/credits.json` appears anywhere under `NeedRoll/` (scripted check). The demo's names (`RunDemo.lua:31-33`) are made up and match no credited player. Run records (dev only) stay in SavedVariables and the private `data/watcher` branch; the ingest never reads them (`__main__.py:650-651`). See R10.
- **Scraper:** `pvppages.py` reads only pages Mike saved by hand (CLI paths); nothing requests Wowhead (`__main__.py` keeps `args.wowhead = False`, and the test run's "Wowhead pages (retired, cache only)" line confirms it). `watcherpr.py` runs `git` through `release._git` with list arguments, uses no `shell=True`, `eval` or `pickle`, and never reads the `by` field (who shared a kill). `emit.py` writes `classes`/`forProfession` through `_lua_string`, and `forever_factions.py` refuses an unknown `for_profession`.
- **Workflow:** `watcher-data.yml` passes the run URL through `env:` (`RUN_URL`); no `${{ github.event.* }}` in `run:`; permissions unchanged (`contents`, `pull-requests`, `statuses` write, as the job needs to push and open the PR); no `pull_request_target`.

### Round 2 notes (`eed9d7df..9e906619`)

Every function the fixes touched was re-read in full.

The character key and its move (`Core/Init.lua:644-790`, `Core/Shopping.lua:209-318`, `UI/Shopping.lua:396-430`), against the points the coordinator raised:

- **Secret GUID:** `ns.CharacterKey()` reads `ns.Plain(UnitGUID("player"))`. It keeps the last readable GUID for the session (the player can't change), and falls back to `"<first name>-<realm or ?>"`. `MoveSavedDataToGUIDKey` returns early without a plain GUID, name, class and side. Nothing compares or concatenates a secret value. `UnitGUID` is in the `forever` GlobalAPI.
- **Timing:** the move runs at NeedRoll's `ADDON_LOADED`. That handler is registered after the one that sets `ns.db` (`Init.lua:182-190`); `ns:On` runs handlers in registration order. It runs again at `PLAYER_LOGIN`, registered in `Init.lua` before every other file's `PLAYER_LOGIN` handler. Only bag events can write per-character data before `PLAYER_LOGIN` (`ScanBags`), and those tables are rewritten whole on the next scan anyway. Whether `UnitGUID("player")` answers at `ADDON_LOADED` on a fresh login is unknown (inferred: the `PLAYER_LOGIN` pass covers it either way). Data saved under the fallback key before the GUID was read moves at every login.
- **Wrong character claiming data:** a key whose `characters` record names another class or side is left alone, and so is a realm-named key with a rival. `"Name-"` is shared since build 71037 by every character of that first name. The first such character of matching class and side to log in takes it, including another one's last bank scan (fixed at its next bank visit). That is inherent in what 71037 left behind, and acceptable. The deletions are not: R13 (older data lost), R14 (ambiguous records never resolved).
- **AltCounts:** `IsOnMyServer` compares `server` when both records have it, else a realm name both saved. A pre-71037 alt counts until it logs in; a post-71037 alt with `realm = ""` and no server doesn't count until it logs in. Both are correct as far as the saved data allows.
- **MoneyOnAllCharacters:** correct once the old keys are gone. It still double counts in R14's case and for alts that haven't logged in since (both `"Alt-"` and `"Alt-<realm>"` records); the latter resolves at that alt's next login. The gold tooltip shows a realm only where a name was saved (`KnownRealm`), and `STYLE-GUIDE.md` was updated for it.
- **Readability:** the helpers are named for what they do (`FallbackKey`, `SavedTable`, `IsOldKeyOf`, `IsOtherCharacter`, `OldKeysOfMine`, `SavedRealmOf`, `MoveEntries`, `IsOnMyServer`, `MyRealmName`, `KnownRealm`). `PER_CHARACTER_TABLES` lists each table with its owner. The comments explain the game fact (71037's empty realm). Exceptions are R14's two wrong comments and R15.
- **Smoke stand-in:** `wow.lua`'s `UnitGUID("player")` answers `W.player.guid`. The new scenarios cover the move, one run only, before-GUID data, two Flows on different servers, alts by server and the tooltip, but not R13's or R14's cases.

Other round 2 commits: R2, R3, R5–R9 and R12 are fixed as described in their statuses; no new problem found in them. The `@debug@` wrapping in `Init.lua:498-527` and `Data.lua:1680-1704` is self-contained: the packaged smoke run loads and passes, and `L` is a file local in `Data.lua:115`. `Data/Hotfixes.lua` (`eed9d7df`): 28 entries, terse and reworded; R16 is the one near-copy found.

### Round 3 notes (`9e906619..852279fb`, migration only)

The coordinator's scope: data loss, wrong-character claims and readability in the move to GUID keys, and the four commits. Every function in `Core/Init.lua:650-877` and `MyRealmName` was re-read in full, not only the changed lines.

- **Data loss (R13):** fixed. The merge order is right. `OldKeysOfMine` lists `FallbackKey()` (this session), then `"Name-"` (since 71037), then `"Name-<realm>"` (before it). `MoveTableEntries` folds them into the GUID entry in that order, so the GUID entry wins, then the newest. `TakeNewest` for the record, bags and bank is right, because `SaveCharacter` and the bag scan rewrite them at once. `JoinLists` keeps every run and hand-in once (keyed by `startedAt:mapID` and `at:quest`) and sorts oldest first, as `Runs.lua:338-339` and `Drops.lua:3653-3655` append and trim. A list over `RUNS_KEPT` (100) or `HISTORY_KEPT` (300) is trimmed at the next run or hand-in. `completedCount` and `forgotUntil` keep the newest key's value, which is right because both are snapshots, not counters. The remaining loss-like case is R18 (cleared settings come back).
- **Wrong-character claims:** `IsOtherCharacter` still sets aside keys whose record names another class or side. Shared `"Name-"` is still taken by the first same-class, same-side character to log in, as accepted in round 2. New in this range: a realm-named key is taken on evidence of uniqueness alone, and that guess now teaches the whole account a server's realm (R17). A seen realm (`GetRealmName()`) is noted before the claim (`:865`) and overwrites a guess, so the game's answer always wins once it returns.
- **Secret values and timing:** unchanged from round 2. `GetRealmName()` and the GUID go through `ns.Plain`, and the move returns early without a plain GUID, name, class and side. `RealmOfOldKey` works only on saved keys (plain strings).
- **R14 option (a):** the comments (`:779-785`, `:852-858`) say what the code does, including that a key nobody can place stays and its gold still counts. `moved[guid]` is still set at the first login. Later logins re-check only `FallbackKey()` and a realm-named key, never `"Name-"` again, so a later login can't take a `"Name-"` written by another character since.
- **Readability:** names fit (`TakeNewest`, `FillIn`, `JoinRuns`, `JoinChainClues`, `RealmOfOldKey`, `IsRealmName`, `RealmNamedKeyOfMine`, `NoteRealmOfServer`, `MoveTableEntries`). `PER_CHARACTER_TABLES` gives each table its merge rule and owner. Nesting stays at three levels or fewer, the indents are 4 spaces and no added line is over 120. `RealmNamedKeyOfMine` does two jobs (look up a known realm; guess at a first move), but at 17 lines with a comment for each it reads. Exceptions: R19, and R18's comment.
- **WoW API:** no new game function, event or widget call. The range calls `GetRealmName`, `UnitGUID`, `UnitName`, `UnitClass` and `UnitFactionGroup`, all checked against the `forever` GlobalAPI in rounds 1 and 2. No combat-blocked call, no shown text (no new `L[...]`), no new global (`realmOfServer` lives in `NeedRollDB`).
- **Redundant code:** `SavedRealmOf` is gone. `TableIn` (`Init.lua:238`) is reused for `realmOfServer` and `movedToGUIDKey`, and `JoinRuns`/`JoinChainClues` share `JoinLists`. Nothing duplicates an existing helper.
- **Security:** none of the inputs are untrusted. All of it is the player's own SavedVariables and the game's answers about the player, and nothing is sent. No name moved into a public place: `realmOfServer` holds realm names only, in the player's SavedVariables. `MIKES_REALM` in the test is a realm name, not a character name.
- **Tests:** the two new scenarios cover R13's case (old settings under empty shells, joined runs and clues) and R14's (two same-class Flows resolved through a third character, gold counted once). Neither covers a wrong guess (R17) or a cleared setting (R18).
- **Hotfixes (R16):** the reworded entry is in our own words. No other entry changed.

## Round history

- Round 1, 2026-11-23, `0d0cd2f7`: **Changes needed** (0 blocking, 4 should fix, 8 nits). Opened R1–R12. R1 (realm key) isn't a regression from this range and shouldn't block v2.0.0; it needs Mike's call on the key format and a migration in a v2.0.x patch.
- Round 2, 2026-11-23, `9e906619` (on `eed9d7df`): **Changes needed** (1 blocking, 1 should fix, 5 nits). Mike held v2.0.0 for R1, which was fixed in round 2 with GUID keys and a one-time migration. Closed R1, R2, R3, R5, R6, R7, R8, R9, R12. Left as is: R4 (no reason given), R10 and R11 (for Mike later). Opened R13 (blocking: the migration deletes pre-71037 settings in favour of newer shells, and once run it can't be redone), R14 (should fix: ambiguous realm-named records stay and keep the gold double count), R15 and R16 (nits). This was the last round under `/release-review`, so what's left goes to Mike.
- Round 3 (migration only), 2026-11-23, `852279fb` (on `9e906619`): **Changes needed** (0 blocking, 1 should fix, 2 nits open). This was an extra focused pass on `Core/Init.lua`'s move to GUID keys and the four fix commits, promised to Mike by the coordinator. Closed: R13 (`135e4edf`), R14 (`852279fb`, option (a)), R15 (`f1030bac`), R16 (`e4f9f400`). Opened:
  - R17 (should fix): a key claimed only because it was the one left records its realm for the claimer's whole server. One wrong guess moves another character's data, leaves every other character there unclaimed (gold counted twice) and shows the wrong realm.
  - R18 (nit): `FillIn` brings back settings cleared since 71037.
  - R19 (nit): an unexplained load-bearing line in `JoinChainClues`.

  R4, R10 and R11 stay as is.
- After round 3, 2026-11-23, `9cd22864`: fixes by the implementer, checked by the coordinator with the full local checks (all four smoke modes, `--locale all`, locale, font and hotfix checks), not re-reviewed. R17 (`e38e46f0`): `realmOfServer` is learned only from `GetRealmName()`, never from a claimed key, and Shopping shows only a game-reported realm; a new scenario covers the wrong-guess case. R19 (`d2805951`): `JoinChainClues` no longer changes `older`. R18 accepted as a limitation, with a comment (`9cd22864`). Left: R4, R10, R11 (for Mike later). Known limits: a guessed claim can still move a same-name, same-class, same-side character's data from another server; with `GetRealmName()` empty, realm names mostly go unshown.
