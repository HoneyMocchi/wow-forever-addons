# Review: NeedRoll v1.1.0 (everything since v1.0.3)

| | |
| --- | --- |
| Branch | `v1.0.3..origin/dev` (PRs #786 to #799), then in round 2 the fixes on `claude/project-thread-9jkjm3` (`9332659`) and PRs #800, #801 and #802 merged in (`f1b7899`), into `dev` before the v1.1.0 changelog PR |
| Commit reviewed | Round 1: `a1e9a6d`. Round 2: `f1b7899` (`git diff a1e9a6d f1b7899`: fixes `9332659`, #800 `650679e`, #801 `779240a`, #802 `5e4818a`). No uncommitted changes besides this doc. |
| Date | 2026-11-07 |
| Round | 2 (the last) |
| Verdict | **Ready** at round 2 (0 blocking, 0 should fix open, 1 nit open). Round 1 had 3 should fix and 7 nits: R1, R3 and R5-R10 fixed or resolved, R2 left as is by Mike until drop sharing is switched back on, R4 deferred. New in round 2: R11 (nit). |
| Needs | Full client restart, not just `/reload`: `Data/Dungeons/KroldokStronghold.lua` is a new file (listed in `Data/Data.xml`), and the game only finds new files on disk at startup. |

## What the change does

**Drop sharing switched off (#796, #797).** WoW: Forever's live realms deliver no addon messages on custom chat channels, and joining one took chat number /1 from General. So `Drops.isSharingEnabled = false` (`Core/Drops.lua:94`) turns sharing off for everyone. All the sharing code stays, to be switched back on. While it is off:
- nothing is queued or sent, and what an earlier session left in the outbox waits there;
- the realm channel isn't joined, and is left at login;
- the first-login consent notice isn't shown, and each login marks it unanswered, so everyone is asked again once sharing is back;
- Settings hides Share drops and Credit my finds (`isHidden`), and the rows below close up;
- the dev commands that send say sharing is off.

Before that, #796 moved the throttle and lockdown handling out of `Core/Drops.lua` into `ns.AddonMessages` (`Core/Init.lua:423-505`). The drop outbox, the dev commands and the version check now all send through `AddonMessages:Send`. They share one count of "throttled" answers, and one lockdown wait capped at two minutes. The version check now retries at most once per chat after a lockdown or throttle. Before, it re-armed a 30-second timer on every call.

**New content.**
- **Krol'dok Stronghold** (#794, #798, #799): a new dungeon with six bosses (NPC IDs, portraits, loot from an observed run) and six Horde/Alliance quests. QuestieDB doesn't have those quests yet, so they are built from `forever.json` details alone (`questie_quests.Builder._hand_kept`).
- **The Drowned City** (#793): eight quests.
- Drop sharing's guessing of bosses in instances NeedRoll doesn't list now also runs in a listed instance where some boss lacks an NPC ID (`KnowsEveryBoss`).

**Quest pages.**
- Lonebrow's Journal reads "looted from Henrig Lonebrow's Journal" and pins the journal (#790).
- Seeking Caitlin is an optional lead-in: it shows "Optional" in the chain list, and its card on the dungeon questline page is faded and not counted (#791, `optionalLeadIns` in `forever.json`, `optional` in `Data/Chains.lua`).
- Mortality Wanes reads "Loot [Treshala's Pendant] from any humanoid (~1% chance)" (#792).
- Two Southshore breadcrumbs lead to Image of Archmage Modera's Dalaran quests (#789).

**Lyn the Ignored's spoiler (#795).** It now says the Tome of Dalaran is looted in Shadowfang Keep, next to Archmage Arugal. The dungeon is a link that pins its entrance, and Arugal is a link that opens Shadowfang Keep's map on him.

**Fix (#788).** The dungeon questline page is hidden on every other tab, on the Settings page and across a style switch. `UI.contentPages` is now the one list of content pages.

**Docs (#786).** `CHANGELOG.md` is now written in broad strokes for players. `CHANGELOG-DETAILED.md` (new, ignored by `.pkgmeta`) lists every change by PR. The rule is also in `CLAUDE.md`.

## Scope

All 49 changed files were listed. Every hunk was read with the code around it, and every function the range changed was read in full.

Addon:
- `NeedRoll/Core/Init.lua`: `AddonMessages` (new: `IsLockedDown`, `WaitsOnLockdown`, `ResultName`, `Refusal`, `Send`), `VERSION_GAP`, `Version:RetryLater` (new), `Version:Send`, the `shownDroptalkConsent` default comment.
- `NeedRoll/Core/Drops.lua`: the Switch block and `isSharingEnabled`, `KnowsEveryBoss` / `IsListedInstance`, `ChannelOn`, `LeaveUnusedChannels` / `JoinChannel`, `IsHiddenChatLine`, `SendNext`, `Queue`, `AnswerRollCall`, `ResultName`, `RefusesDevSend` / `RefusesWhileSwitchedOff`, the dev `Ping` / `Probe` / `RollCall` / `SendRollCall` / `OutboxStatus` (all inside `--@debug@`, 2003-2699).
- `NeedRoll/UI/Settings.lua`: `IsSharingSwitchedOff`, `isHidden`, `BuildGeneral`.
- `NeedRoll/UI/Welcome.lua`: `ShowDropNotice`, the tick box's start state, the login reset.
- `NeedRoll/UI/MainFrame.lua`: `UI.contentPages`, `UI:HideListTabPanes`, `ShowSettingsPage`, `ShowWholeBodyTab`, `SKINNED`, `BACK_CLICKS`.
- `NeedRoll/UI/Overview.lua`: `Chain.Lines` (Optional), `Droppers` (second return), `LootSources` (new), `ItemSources`, `ChainText`, `StartText`, `LootLine`.
- `NeedRoll/UI/LootGrid.lua`: `ShowBossInOtherInstance` (new), `CreateSpoiler`'s hyperlink handlers, `OpenSpoilerText`.
- `NeedRoll/UI/DungeonQuestlines.lua`: `OptionalLeadIns` (new), `MergedSteps`.
- `NeedRoll/Data/Data.lua` (hand-written code): `optionalLeadIns`, `RegisterChains`, `IsOptionalLeadIn`, `bossSpoilers` (Lyn's links).
- `NeedRoll/Data/Maps.lua` (hand-kept zone quests): Razorfen Kraul's Mortality Wanes badge.
- `NeedRoll/Locales/enUS.lua`, `Locales/NpcNames/Forever.lua`: 12 new phrases, one reworded (R3), two moved.

Generated, not reviewed for style: `Data/Chains.lua`, `Data/Quests.lua`, `Data/KnownQuests.lua`, `Data/KnownDrops.lua`, `Data/ClassSpells.lua` (source line only) and `Data/Entrances.lua`. Their generators were reviewed instead. The header of `Chains.lua` and the `KROLDOK_STRONGHOLD` entrance (with its corrected spelling) match `chains.py`'s `HEADER` and `quests.py`'s `FOREVER_ENTRANCES`. They couldn't be rebuilt here: there is no QuestieDB or Classic-DB cache in `scraper/cache`. `Data/Dungeons/KroldokStronghold.lua` carries the generated header but was written by hand (`scraper/README.md:516-520`). It was read in full as hand-written data (R8).

Scraper and data inputs:
- `scraper/needroll_scraper/chains.py` (`optional_lead_ins`, `Chains.before`, `render`, `build`), `questie_quests.py` (`world_holders`, `_hand_kept`, the rewards fallback, `_start`, `_chain`, `_targets`' hand-kept kills and `anyHumanoid`, the seeds QuestieDB lacks), `quests.py` (`any_humanoid`, `_loot`, `FOREVER_ENTRANCES`).
- `scraper/quests/forever.json` (the Drowned City and Krol'dok seeds and details, `optionalLeadIns`, `anyHumanoid`), `logged.json`, `scraper/classes/seen.json`, `scraper/professions/trainer_checks.json`, `scraper/drops/items.json` (watcher data, #787), `new-instances/KroldokStronghold.txt`, `scraper/README.md`.
- Tests: `test_chains.py`, `test_pipeline.py`, `test_questie_quests.py`.

Smoke: `wow.lua` (three `Enum.SendAddonMessageResult` values), `run.lua` (switches sharing on for the run), `scenarios.lua`, `README.md`, and modules `Core-Drops`, `Core-Init`, `UI-DungeonQuestlines`, `UI-Overview`, `UI-Settings`, `UI-Welcome`.

Docs: `CHANGELOG.md`, `CHANGELOG-DETAILED.md`, `CLAUDE.md`, `.pkgmeta`, `docs/STYLE-GUIDE.md`, `docs/LOCALIZATION.md`.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 21 changed hand-written Lua files | Passed. Lua 5.1 and luacheck 1.1.2 were installed in this container for the review. |
| `luacheck --no-global -q`, base `v1.0.3` vs now | New warnings: `Data/Data.lua:99` line too long (132), and `:997` (130, the literal `L["..."]` key of Lyn's spoiler); `tests/smoke/modules/UI-Overview.lua:720` and `:730` too long (121); `tests/smoke/scenarios.lua:2342` "variable 'text' was previously defined on line 2310". `Core/Init.lua` 9 → 8 (one fewer `unused argument 'self'`). Every other file has the same warnings as before (R7). |
| Globals | `luacheck` without `--no-global`, base vs now: no new "setting non-standard global" in any changed addon file |
| Lua 5.1 limits (`luac5.1 -l -l`, locals active at once and upvalues per function) | `UI/Overview.lua` main chunk: **195 of 200** locals (194 at v1.0.3). `Core/Drops.lua` main chunk: 194 (198 at v1.0.3; #796 moved helpers out). `UI/LootGrid.lua` 169, `UI/MainFrame.lua` 135. Most upvalues in one function: 39 (`CreateLootGrid`), 34 (`Overview.lua:3737`, `CreateOverview`); limit 60 (R4) |
| `python3 tools/locales.py --check` | Passed |
| `python3 tools/translations.py` | Exit 0, but lists 10 entries "not used by NeedRoll any more": every language's translation of Lyn the Ignored's old spoiler sentence (R3) |
| `tests/smoke/check.sh` (all four: dev, packaged, secret, combat) | Passed, "all passed" in each run (2291 scenario lines over the four runs, about 573 each) |
| `cd scraper && python3 -m unittest discover -s tests` | Passed, 348 tests |
| Ketho's `forever` lists | `GlobalAPI.lua`, `LuaEnum.lua`, `WidgetAPI.lua` and `Events.lua` downloaded from the `forever` branch to the scratchpad and grepped (table under WoW API) |
| Names in public places | The names in `scraper/drops/credits.json` and the `by` fields of `scraper/drops/observed.json` were grepped across every added line of the range: none found. `CHANGELOG-DETAILED.md` is in `.pkgmeta`'s ignore list; `CHANGELOG.md` (posted to CurseForge) names no player |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | WoW API | `UI/LootGrid.lua:2381-2403` | The spoiler's Shadowfang Keep link uses the in-combat fallback all the time: out of combat a click does nothing the player can see | fixed in round 2 (`9332659`) |
| R2 | should fix | Security | `Core/Init.lua:565-576`, `UI/Settings.lua:91`, `UI/Welcome.lua:195` | Share drops Off and the notice's Turn off promise NeedRoll sends nothing, but the version check keeps sending | left as is by Mike (2026-11-07): rewording due when sharing is switched back on |
| R3 | should fix | WoW API | `Data/Data.lua:997`, `Locales/enUS.lua:371` | Rewording Lyn the Ignored's spoiler drops its translation in all 10 languages | resolved in round 2 (Translations PR #802) |
| R4 | nit | WoW API | `UI/Overview.lua` (main chunk), `Core/Drops.lua` (main chunk) | `Overview.lua` has 5 top-level locals left before Lua 5.1's 200 limit, `Drops.lua` 6 | deferred (structural) |
| R5 | nit | Redundant code | `UI/LootGrid.lua:2403, 3353-3355` | The spoiler resolves and builds dungeon links by hand, without the nil guard `SourceSpot` already has | fixed in round 2 (`9332659`) |
| R6 | nit | Readability | `UI/Overview.lua:3239-3248, 3258-3268, 3316-3323, 3329-3332`, `:550` | "looted from" or "dropped by" is chosen two different ways in four places; `optional` holds a label | fixed in round 2 (`9332659`) |
| R7 | nit | Readability | `Data/Data.lua:99`, `tests/smoke/modules/UI-Overview.lua:720, 730`, `tests/smoke/scenarios.lua:2310, 2342` | New luacheck warnings: three long lines and a redefined `text` | fixed in round 2 (`9332659`) |
| R8 | nit | Readability | `Data/Dungeons/KroldokStronghold.lua:1-4` | A hand-written data file whose header says it is generated and names an override file that doesn't exist | fixed in round 2 (`9332659`, in the generator) |
| R9 | nit | Readability | `UI/MainFrame.lua:1888-1890`, `Data/Data.lua:588-590` | Two comments no longer cover what uses them: `ShowInDungeon`'s callers and a chain step's fields | fixed in round 2 (`9332659`) |
| R10 | nit | Readability | `docs/STYLE-GUIDE.md:405` | The style guide doesn't describe the new "from any humanoid (~1% chance)" loot line | fixed in round 2 (`9332659`) |
| R11 | nit | Readability | `UI/LootGrid.lua:3299-3353` (`LayoutBosses`), `:3472-3488` (`DrawSpoiler`) | (round 2) The spoiler now hangs by a measured offset that only `DrawSpoiler` updates, and `LayoutBosses` moves the title without it | open |

### R1 · The spoiler's Shadowfang Keep link uses the in-combat fallback all the time: out of combat a click does nothing the player can see
- **Severity:** should fix
- **Area:** WoW API (map links the addon's way; combat-protected calls)
- **Where:** `NeedRoll/UI/LootGrid.lua:2381-2392` (`OnHyperlinkEnter` / `OnHyperlinkLeave`), `:2401-2403` (`OnHyperlinkClick`)
- **Status:** fixed in round 2 (`9332659`). The dungeon link's hover now calls `ns.UI.HoverMapLink(self, SourceSpot({ inside = inside }), nil, ShowPinHint)` and its leave `ns.UI.LeaveMapLink` (`LootGrid.lua:2411-2432`), so a click out of combat runs the game's `/mappin`; the click handler is left for the in-combat fallback, through `SourceSpot`. The secure button can't sit in a frame hanging from a FontString, so the spoiler now hangs from the loot pane by a measured offset (`pane:SubtitleBottom()`, `DrawSpoiler`, `LootGrid.lua:3260-3264, 3472-3483`), which R11 follows up. The hover keeps the plain "Click to pin the entrance on your map" hint rather than `ns.UI.PinHint` (fine). The "a boss's spoiler" scenario now clicks the link as a player does: out of combat the game's waypoint is set on Shadowfang Keep's entrance map and not by the addon, and in combat NeedRoll's own pin and both chat lines appear. All four smoke runs pass.

**What's wrong.** #795 adds a `needroll:inside:SHADOWFANG` link to Lyn the Ignored's spoiler. Its hover shows only a hint, and its click calls `ns.UI.ShowOnMap` straight away:

```lua
elseif link:match("^needroll:inside:") then
    ShowHintAtCursor(self, L["Click to pin the entrance on your map"])
...
local inside = link:match("^needroll:inside:(.+)")
if inside then return ns.UI.ShowOnMap(ns.Data:Entrance(inside), ns.Data:Get(inside).name) end
```

The addon pins map links in two steps, and `ShowOnMap` is only the second. Its own comment (`UI/Overview.lua:686-694`) says: "A click on a link that pins a spot, when it reaches NeedRoll's own code: in combat … Out of combat that button lies over the link while the mouse is on it, runs the game's /mappin and the click never gets here (see UI.HoverMapLink)". Every other map link calls `ns.UI.HoverMapLink(frame, spot, …)` on hover and `ns.UI.LeaveMapLink` on leave. That includes the quest page's `needroll:inside:` links (`Overview.lua:3189`), the loot pane's sources (`LootGrid.lua:1161`), the Professions Overview and the world map pill. The spoiler does neither.

**Why it matters.** Say a player out of combat opens Lyn the Ignored's spoiler and clicks "Shadowfang Keep". `ShowOnMap` draws only NeedRoll's own pin in the overlay (`WorldMapOverlay:ShowPin` stores it, and draws it once `WorldMapFrame` exists). Then it returns at `if not ns.UI.MapLinksInCombat() then return end`, before any message. Nothing else happens:
- the game's user waypoint isn't set, so there's no arrow on the minimap or the screen;
- the map doesn't open;
- the chat prints nothing.

The click looks broken, while the hint promised a pin. In combat it behaves as designed: it draws the own pin and prints the "can't pin in combat" line. So the combat rule in `CLAUDE.md` holds, but out of combat the player only ever gets the fallback. The hover hint also differs from the other entrance links, which say "Click to pin on your map (Silverpine Forest [x, y])" (`ns.UI.PinHint`).

**Evidence.**
- Read `CreateSpoiler` (`LootGrid.lua:2362-2416`), `ShowOnMap` (`Overview.lua:686-706`), `WorldMapOverlay:ShowPin` (`WorldMapOverlay.lua:367-370`), `UI.HoverMapLink` / `LeaveMapLink` (`MainFrame.lua:2956-2978`), and the quest page's line handlers (`Overview.lua:3184-3196`).
- `grep -n HoverMapLink NeedRoll/UI/LootGrid.lua` finds only line 1161, the item source rows.
- The smoke scenario "a boss's spoiler" (`scenarios.lua:2314-2315`) fires the click but asserts nothing about the pin.

**Fix.** Wire the dungeon link like the quest page's:

```lua
spoiler:SetScript("OnHyperlinkEnter", function(self, link)
    local inside = link:match("^needroll:inside:(.+)")
    if inside then
        local spot = SourceSpot({ inside = inside })
        ShowHintAtCursor(self, ns.UI.PinHint(spot))
        ns.UI.HoverMapLink(self, spot, nil, function() ShowHintAtCursor(self, ns.UI.PinHint(spot)) end)
    elseif ...
end)
spoiler:SetScript("OnHyperlinkLeave", function(self)
    GameTooltip:Hide()
    ns.UI.LeaveMapLink(self)
end)
-- OnHyperlinkClick keeps ShowOnMap(SourceSpot({ inside = inside })) for the in-combat click.
```

Extend the scenario: hovering the link lays the secure button over it (`hoveredMapLink` set, as `UI-Overview`'s pin scenarios check), and leaving takes it away.

### R2 · Share drops Off and the notice's Turn off promise NeedRoll sends nothing, but the version check keeps sending
- **Severity:** should fix
- **Area:** Security (what players are told is sent)
- **Where:** `NeedRoll/Core/Init.lua:565-576` (`Version:Send`), `:578-588` (`Broadcast`), `:602-620` (`Heard`); the promises in `UI/Settings.lua:91` (`L[...]` at `Locales/enUS.lua:1140`) and `UI/Welcome.lua:195` (`enUS.lua:1262`)
- **Status:** left as is by Mike (2026-11-07): the version check keeps sending, and the Share drops tip and the consent notice are reworded when drop sharing is switched back on (`Drops.isSharingEnabled`). While it is off the setting is hidden and the notice isn't shown. Players who chose Off before v1.1.0 still send `V:` messages until then.

**What's wrong.** Share drops' tip lists what NeedRoll sends: "which items bosses drop, new quests, what class trainers teach and which NeedRoll version you run". Then it says: "Off stops NeedRoll sending anything to other players". The consent notice also lists "its own version", and says "Turning it off stops NeedRoll sending anything". But nothing on the version check's path reads `NeedRollDB.dropChannel`:

```lua
function Version:Send(chatType, target)
    local mine = self:Mine()
    local key = target or chatType
    if not mine or self.retrying[key] then return end
    ...
    local _, refusal = AddonMessages:Send("V:" .. mine, chatType, target)
```

`grep -n "dropChannel\|ChannelOn" NeedRoll/Core/Init.lua` finds only the defaults comment. So a player who chose Off still sends three kinds of message:
- `V:<version>` to their guild at every login;
- the same to each group they join;
- a whisper back to any older copy that sends them one.

The Switch comment in `Drops.lua` says "the version check (Core/Init.lua) still runs" while sharing is switched off. That suits the global switch. It doesn't suit a player's own Off.

**Why it matters.** This is the consent the addon asks for at first login. A player who pressed Turn off, or switched Share drops off, was told nothing leaves. Their character still tells the guild, the group and strangers which NeedRoll version it runs. It sends little, and nothing of their finds, but it is exactly what the text names. While sharing is switched off in v1.1.0, the setting is hidden, but every player who chose Off before keeps sending. The notice comes back with the same promise once sharing is switched on.

**Evidence.**
- Read `Version:Send`, `Broadcast`, `Heard` and the two PLAYER_LOGIN handlers (`Init.lua:545-645`), and `Drops:SetChannel` (`Drops.lua:704-712`).
- `git show v1.0.3:NeedRoll/Core/Init.lua | grep dropChannel` gives the same result.
- No smoke scenario checks the version check with `dropChannel = false` (`grep -rn dropChannel tests/smoke/modules/Core-Init.lua`: none).

**Fix.** One of these (Mike's call):
- (a) Keep the promise. In `Version:Send`, add `if ns.db and ns.db.dropChannel == false then return end`, reading the player's choice and not `Drops:ChannelOn()`, so the version check still runs while sharing is switched off for everyone. Add a Core-Init scenario: with `dropChannel = false`, Broadcast and an older copy's `V:` send nothing.
- (b) Keep the behaviour and reword both texts ("Off stops sharing finds; NeedRoll still tells your guild and group which version you run"). That costs their translations, as in v1.0.0's R10.

### R3 · Rewording Lyn the Ignored's spoiler drops its translation in all 10 languages
- **Severity:** should fix
- **Area:** WoW API (player-facing text through `L["..."]`)
- **Where:** `NeedRoll/Data/Data.lua:997`, `NeedRoll/Locales/enUS.lua:371`
- **Status:** resolved in round 2. NeedRoll-Locales #26 and #27 drafted every new phrase, and Translations PR #802 (`5e4818a`) brought them in. Every language now has the new sentence under its new key ("Es wird in %s erbeutet, direkt neben %s" in deDE), and `tools/translations.py` reports nothing (no orphaned or missing phrase).

**What's wrong.** #795 replaced the phrase `L["Use the %s at the summoning circle in the Dalaran Sewers."]` with `L["Use the %s at the summoning circle in the Dalaran Sewers. It's looted from %s, right next to %s."]`. The English text is also the key, so every language file's translation of the old sentence no longer matches anything. `tools/translations.py` lists all 10 (deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW) as "not used by NeedRoll any more", and the new key has no translation yet.

**Why it matters.** At v1.1.0 every non-English player reads Lyn's whole spoiler in English, though its first sentence was translated before. `docs/READABLE-CODE.md` ("Behaviour stays the same") lists `L["..."]` keys among what must not change, because renaming one breaks every translation of it.

**Evidence.** `translations.py` output (Checks); `git diff v1.0.3 origin/dev -- NeedRoll/Locales/enUS.lua NeedRoll/Data/Data.lua`.

**Fix.** One of these (Mike's call):
- (a) Keep the old sentence and add the new part as its own phrase. Only the new part is then English until it is translated:
  ```lua
  LYN_THE_IGNORED = { L["Use the %s at the summoning circle in the Dalaran Sewers."] .. " "
      .. L["It's looted from %s, right next to %s."],
      links = { ... } },
  ```
  The `%s` are filled from `links` in order, so the joined text works as one.
- (b) Keep it, and tag v1.1.0 only after a Translations PR has brought the new sentence in for every language, as v1.0.0's R10 was handled.

### R4 · `Overview.lua` has 5 top-level locals left before Lua 5.1's 200 limit, `Drops.lua` 6
- **Severity:** nit
- **Area:** WoW API (Lua 5.1 limits)
- **Where:** `NeedRoll/UI/Overview.lua` main chunk (195 active locals; `LootSources`, line 1044, is this range's one new top-level local); `NeedRoll/Core/Drops.lua` main chunk (194)
- **Status:** deferred (structural), for the next feature in these files. Round 2: `Overview.lua` is still at 195, and `UI/LootGrid.lua` rose from 169 to 179 (#800), with 21 left.

**What's wrong.** Lua 5.1 allows at most 200 locals active at once in one function, and a file's top level counts as one function. `luac5.1 -l -l` gives:
- `Overview.lua`: 195 at once (194 at v1.0.3), so 5 left;
- `Drops.lua`: 194 (198 before #796 moved the throttle helpers to `Core/Init.lua`), so 6 left.

Upvalues are not close: the most any function has is 39 (`CreateLootGrid`) and 34 (`CreateOverview`, `Overview.lua:3737`), against the limit of 60. The reviewer brief's line that `CreateOverview` "is at" the upvalue limit is out of date.

**Why it matters.** It can't reach players broken: one local over the limit fails `luac -p` and every smoke run at once ("too many local variables"). But a feature or fix that adds a few helpers to either file will hit it, and then has to reshuffle code under a deadline. R6's tidy-up must not add a top-level local either.

**Evidence.** A script over `luac5.1 -l -l`'s locals table (start and end pc per local) counting the most alive at once, run on both versions (Checks).

**Fix.** Nothing to change for v1.1.0. Before the next feature lands in these files, group a family of top-level helpers into a table, as `Chain` and `PageLink` already are in `Overview.lua`. The droppers and places helpers (`Places`, `Droppers`, `LootSources`, `ItemSources`, `LootLine`) are one candidate. `Drops.lua`'s channel helpers are another. New helpers go on such a table, not as new top-level locals. Consider a smoke or CI guard that fails when a main chunk passes 190.

### R5 · The spoiler resolves and builds dungeon links by hand, without the nil guard `SourceSpot` already has
- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/LootGrid.lua:2403` (click), `:3353-3355` (`OpenSpoilerText`)
- **Status:** fixed in round 2 (`9332659`). The click uses `SourceSpot({ inside = inside })`. `OpenSpoilerText` gains `DungeonLink`, which writes plain text when the dungeon or its entrance is unknown. `ShowBossInOtherInstance` returns on a nil instance. No data scenario was added; the guards cover it.

**What's wrong.** The same file already turns an `inside` into an entrance spot and a name, nil-guarded (`LootGrid.lua:700-706`):

```lua
local function SourceSpot(src)
    ...
    local dungeon = ns.Data:Get(src.inside)
    return ns.Data:Entrance(src.inside), dungeon and dungeon.name
end
```

The new click handler repeats it unguarded: `ns.UI.ShowOnMap(ns.Data:Entrance(inside), ns.Data:Get(inside).name)`. `OpenSpoilerText` does the same with `ns.Data:Get(link.inside)` then `dungeon.name`. So does `ShowBossInOtherInstance(ns.Data:Get(otherID), boss)`, which indexes `instance.encounters`. `Overview.lua` also has `EntranceLink(inside, text, color)`, which colours the link only when the entrance is known.

**Why it matters.** The links come from NeedRoll's own `bossSpoilers` data, not from other players, so this is robustness, not security. But a typo in a spoiler's `inside` or `instance` (or an instance later renamed) becomes a Lua error. It would fire when the spoiler opens or is clicked, not when the data loads, and no data check covers spoiler links (`grep -rn bossSpoilers tests/`: none).

**Fix.** Use `SourceSpot({ inside = inside })` in the click (R1's fix does). In `OpenSpoilerText` and before `ShowBossInOtherInstance`, skip or plain-text a link whose instance `ns.Data:Get` doesn't know. Or add a smoke scenario that walks every `bossSpoilers` entry and checks that each `inside`, `instance` and `boss` exists.

### R6 · "looted from" or "dropped by" is chosen two different ways in four places; `optional` holds a label
- **Severity:** nit
- **Area:** Readability (one way of doing each thing; names)
- **Where:** `NeedRoll/UI/Overview.lua:3239-3248` and `3258-3268` (`ChainText`), `3316-3323` and `3329-3332` (`StartText`), `550` (`Chain.Lines`)
- **Status:** fixed in round 2 (`9332659`). All four places use the one-line `phrase` pick after a guard (`Overview.lua:3244-3246, 3260-3262, 3319-3321, 3329-3331`), and `optional` became `optionalLabel`. No new top-level local (`Overview.lua` still at 195).

**What's wrong.** #790 adds the "looted from" wording in four places. Three use an `if droppers and fromObjects … elseif droppers …` chain. One uses a one-line pick:

```lua
local phrase = fromObjects and L["Starts from %s, looted from %s"] or L["Starts from %s, dropped by %s"]
```

`StartText`'s `startsFrom` branch mixes the two: an early `return` for "looted from", then `droppers and … or …` for the rest. The "Droppers, else the giver as dropper" fallback is also written twice (`ChainText:3258-3261`, `StartText:3317-3320`).

In `Chain.Lines`, `local optional = … and L["Optional"] or nil` is a label string, but `optional` reads like a yes/no (`docs/READABLE-CODE.md` §1).

**Why it matters.** A reader meets the same choice four times in three shapes and has to check each one to see they agree.

**Fix.** Use the one-line `phrase` form in all four, for example in `ChainText`:

```lua
local droppers, fromObjects = Droppers(step.droppers, here)
if not droppers then return L["%s from %s"]:format(start, item) end
local phrase = fromObjects and L["%s from %s looted from %s"] or L["%s from %s dropped by %s"]
return phrase:format(start, item, droppers)
```

Don't add a new top-level helper for this (R4). Rename `optional` to `optionalLabel`.

### R7 · New luacheck warnings: three long lines and a redefined `text`
- **Severity:** nit
- **Area:** Readability (formatting)
- **Where:** `NeedRoll/Data/Data.lua:99` (132 characters), `tests/smoke/modules/UI-Overview.lua:720` and `:730` (121), `tests/smoke/scenarios.lua:2310` / `:2342`
- **Status:** fixed in round 2 (`9332659`). `Data.lua:99` is wrapped. The two smoke asserts are wrapped. The first `text` is `lynText`. luacheck shows none of these warnings now; `Data.lua:997` (the `L[...]` key) stays as accepted.

**What's wrong.** `docs/READABLE-CODE.md` §2 keeps new lines to 120 characters. `Data.lua:99` grew past it when `optionalLeadIns = {}` was added to the `ns.Data` constructor. Wrap it after `chainSteps = {},`. The two smoke lines are one character over. In "a boss's spoiler", #795's `local text = spoiler.text:GetText()` (2310) is declared again further down (2342). Give the first one its own name (`lynText`) or reuse the variable. `Data.lua:997` is also new and over the limit, but it is a literal `L["..."]` key, which earlier reviews accepted (and R3 may change it).

**Evidence.** luacheck base vs now (Checks).

### R8 · A hand-written data file whose header says it is generated and names an override file that doesn't exist
- **Severity:** nit
- **Area:** Readability (avoid disinformation)
- **Where:** `NeedRoll/Data/Dungeons/KroldokStronghold.lua:1-4`
- **Status:** fixed in round 2 (`9332659`), in the generator. `emit.py` writes `NEW_IN_FOREVER_HEADER` for every instance whose source starts with "New in WoW: Forever" (`__main__.py:129` builds that source from `emit.NEW_IN_FOREVER`), so the seven new-in-Forever files (Krol'dok, The Drowned City, Hall of Thanes, City of Dalaran, Ruins of Lordaeron, Excavation Site, Hyjal Summit) now say their bosses and loot are kept by hand and `build` skips them. The header still has "Generated by the NeedRoll scraper" in its first four lines, which `release.is_generated` looks for, and says why. `ingest` really does rewrite these files (`observed.apply` then `emit.render`, `__main__.py:504-506`). The new `test_newinstances.HeaderTest` checks both headers.

**What's wrong.** The file starts:

```lua
-- Krol'dok Stronghold. Generated by the NeedRoll scraper; do not edit by hand.
-- Corrections go in scraper/overrides/KROLDOK_STRONGHOLD.json, then rerun:
--   py -m needroll_scraper build
```

Its bosses' NPC IDs, portraits and loot (#798, #799) were written by hand, as `scraper/README.md:516-520` says ("written into its files by hand"). `build` skips every new-in-Forever instance and keeps its file (`__main__.py:71-74`). And `scraper/overrides/` holds only `COMPANIONS.json`. The other Forever instances (The Drowned City, Hall of Thanes…) carry the same header from the retired Wowhead lookup, so this follows a pattern. But Krol'dok's file is new in this range, and it is the first one fully kept by hand.

**Why it matters.** The next person to correct a Krol'dok drop will look for the override file, create it, and run `build`. That changes nothing, because the build skips the instance. Or they'll hesitate to make the hand edit that is actually the way to do it.

**Fix.** Make the header say what is true: "Krol'dok Stronghold. Kept by hand: `py -m needroll_scraper build` leaves this file as it is (see scraper/README.md, new instances). Source: …". Consider the same wording for the other new-instance files.

### R9 · Two comments no longer cover what uses them: `ShowInDungeon`'s callers and a chain step's fields
- **Severity:** nit
- **Area:** Readability (comments that are now wrong)
- **Where:** `NeedRoll/UI/MainFrame.lua:1888-1890`, `NeedRoll/Data/Data.lua:588-590`
- **Status:** fixed in round 2 (`9332659`). `ShowInDungeon` names its three kinds of caller. The chain step shape now lists every field `chains.py`'s `ORDER` writes, in the same order (checked against `chains.py:221-223`).

**What's wrong.**
- `UI:ShowInDungeon` says it runs "for a link on the Classes tab's quest page. One Back returns to that page". It is now also called from the Dungeons tab's spoiler (`LootGrid.lua:2353`, #795), and already was from the Professions Overview (`ProfessionOverview.lua:448`).
- `RegisterChainSteps`' shape comment lists `{ name, level, minLevel, side, classes, giver, giverNpc, startItem, startItemId, turnIn, turnInNpc, zone, objective }`. `ChainText` now reads `step.droppers` (#790), which the comment doesn't name. Nor does it name `turnInInside`, `kills`, `loot` and `named`, which `chains.py:223` writes.

**Fix.** "…for a link on another page (a quest page, a spoiler, a profession's Overview). One Back returns to that page." Add `droppers` (and the other written fields) to the step shape.

### R10 · The style guide doesn't describe the new "from any humanoid (~1% chance)" loot line
- **Severity:** nit
- **Area:** Readability (docs kept in step, `CLAUDE.md` style guide rule)
- **Where:** `docs/STYLE-GUIDE.md:405` ("Kill targets and droppers")
- **Status:** fixed in round 2 (`9332659`). The Kill targets and droppers row describes the line, the rounding and the link (`needroll:dropspot:`, which is what the smoke scenario clicks).

**What's wrong.** #790 and #791 updated the style guide's droppers row and chain lines. #792's new quest-page form, "Loot [Treshala's Pendant] from any humanoid (~1% chance)" (`LootLine`, `Overview.lua:3351-3356`, "any humanoid" a link that opens the dungeon's map), isn't in it.

**Fix.** Add to the row: "an item every humanoid in the dungeon drops: 'Loot [item] from any humanoid (~1% chance)', the chance from `anyHumanoidChance` rounded to a whole percent, 'any humanoid' a dropper link to the dungeon's map".

### R11 · (round 2) The spoiler now hangs by a measured offset that only `DrawSpoiler` updates, and `LayoutBosses` moves the title without it
- **Severity:** nit
- **Area:** Readability (layout that keeps itself right)
- **Where:** `NeedRoll/UI/LootGrid.lua:3472-3488` (`DrawSpoiler`), `:3299-3353` (`LayoutBosses`), `:3538-3542` (the pane's `OnSizeChanged`)
- **Status:** open (latent: none of the three spoilers is on a council's page)

**What's wrong.** R1's fix moved the spoiler off its anchor, under Related Quests or the subtitle, onto a fixed offset from the pane:

```lua
local top = self:SubtitleBottom() + (related:IsShown() and 6 + related:GetHeight() or 0) + 4
spoiler:ClearAllPoints()
spoiler:SetPoint("TOPLEFT", self.titleX or Size.pad + 4, -top)
```

The anchor used to follow the title and subtitle by itself. The offset follows them only when `DrawSpoiler` runs, and that happens in `SetSpoiler` (each `UI:Refresh` of a boss page) and when the spoiler is clicked. `LayoutBosses` sets `titleX, titleY` and calls `UpdateTop`, which moves the grid, but not the spoiler. On a council's page (`#self.bosses > 1`), a window resize runs `LayoutBosses` from `OnSizeChanged`, and the portraits rewrap. That can move the title, and the spoiler would then stay where it was, over the subtitle or Related Quests, until the next refresh. The fallback `Size.pad + 4` also repeats the title's starting x (`LootGrid.lua:2671`) as a bare number.

**Why it matters.** It can't happen today: the spoilers are Lyn the Ignored's, Viktor the Vile's and Kirtonos the Herald's, all single bosses. The title and subtitle don't wrap (`Theme:Text` sets `SetWordWrap(false)`), so a resize doesn't change their heights. But the next spoiler on a council page would overlap its header after a resize, and nothing in the code says the offset has to be redrawn.

**Evidence.** Read `DrawSpoiler`, `SubtitleBottom`, `UpdateTop`, `LayoutBosses`, `SetRelatedQuests`, `SetSpoiler` and `OnSizeChanged`. Checked the `bossSpoilers` keys in `Data/Data.lua`, and `Theme:Text` (`Theme.lua:1124`).

**Fix.** Have `LayoutBosses` end with `if self.spoiler:IsShown() then self:DrawSpoiler() else self:UpdateTop() end` (`DrawSpoiler` already calls `UpdateTop`). Or move the spoiler's `SetPoint` into `UpdateTop`, the one function that already lays out everything under the title. Name the title's starting x once (`TITLE_X = Size.pad + 4`) and use it in both places.

## Round 2

Reviewed `git diff a1e9a6d f1b7899` (31 files): the round 1 fixes (`9332659`) and the three PRs merged into the release since round 1. Every changed function was re-read in full, along with every function it calls or is called from.

### What the new PRs do

- **#800, "Items I can use" in three steps** (Mike asked for it in v1.1.0). The check box now cycles through three steps: off (empty), grey (a grey X: items the character's class can't use stay listed, the whole cell at 0.4 alpha with its icon desaturated), and hide (a red X: those items are left out, as the old tick did), then off again. `ns.UI.FilterLoot` returns the filtered copy with a `greyed` set, and the grid calls `Cell:SetGreyed` on every item cell it draws. The saved value `NeedRollDB.lootFilter[character].usable` becomes `"grey"`, `"hide"` or nil. `ns.UI.LootFilter` turns an old saved `true` into `"hide"`, so a player who had it ticked sees no change. An older copy reading `"grey"` or `"hide"` treats it as ticked (truthy), so going back a version is harmless. Three new tooltip phrases name the step and what the next click does.
- **#801, Past Due** (quest 96800) is listed only under Scarlet Monastery: Library. `forever.json`'s `wings` gains `"96800": ["SM_LIBRARY"]`, and `Data/Quests.lua` loses the Graveyard, Armory and Cathedral copies. That is the generator's `wings` rule (`questie_quests.py`, `d.id in self.ref["wings"].get(...)`). The Library keeps its one entry (`Quests.lua:623`).
- **#802, Translations**: the round 1 phrases, the Krol'dok names and #800's three tooltips in all 10 languages. Machine drafts of the new Forever NPC names follow the file's existing practice (Granny Finespindle as "Oma Feinspindel").

### Scope, round 2

- `NeedRoll/UI/LootGrid.lua`: `Cell:SetGreyed` and `GREYED_ITEM_ALPHA`, `USABLE_GREY` / `USABLE_HIDE` / `NEXT_USABLE_STEP`, `ns.UI.LootFilter` (migration), `UsableBy` / `Shows` (split), `ns.UI.FilterLoot`, `UsableTooltipText`, `ShowUsableTooltip`, `CreateUsableBox`, `CreateFilterBar` and `ShowFilters`, `pane:Refresh` (the `greyed` set), `ShowBossInOtherInstance`, `CreateSpoiler`, `SubtitleBottom`, `UpdateTop`, `LayoutBosses`, `OpenSpoilerText` (`DungeonLink`), `DrawSpoiler`.
- `NeedRoll/UI/Overview.lua` (`Chain.Lines`, `ChainText`, `StartText`), `NeedRoll/UI/MainFrame.lua` (`ShowInDungeon`'s comment), `NeedRoll/Data/Data.lua` (constructor wrap, chain step comment).
- `NeedRoll/Locales/enUS.lua` (three new phrases, reordered by `locales.py`) and the ten language files (#802).
- `scraper/needroll_scraper/emit.py`, `__main__.py`, `scraper/tests/test_newinstances.py`, `scraper/quests/forever.json`.
- Generated: `Data/Quests.lua` (#801, checked against the `wings` rule) and the seven new-in-Forever instance files (header lines only, checked against `NEW_IN_FOREVER_HEADER`).
- `docs/STYLE-GUIDE.md` (Loot filters row, map pin links, the link's frame row, the any humanoid line), and the smoke tests `UI-LootGrid.lua`, `UI-Overview.lua` and `scenarios.lua`.

### Checks, round 2

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the changed Lua files (with `KroldokStronghold.lua` and `Quests.lua`) | Passed |
| `luacheck --no-global -q`, `a1e9a6d` vs now | No new warnings in addon or test code. Fixed: `Data.lua:99`, `UI-Overview.lua:720/730`, `scenarios.lua` "text previously defined" and an unused `W`. The locale files' long lines move with their new phrases (generated, one phrase per line, allowed) |
| Lua 5.1 limits | Most locals active at once in a main chunk: `Overview.lua` 195 (unchanged), `Drops.lua` 194, `LootGrid.lua` 179 (was 169). Upvalues: `CreateLootGrid` 40 (was 39), `CreateOverview` 34. All under 200 and 60 |
| `python3 tools/locales.py --check` | Passed |
| `python3 tools/translations.py` | Passed, nothing reported (the 10 orphans from R3 are gone) |
| `tests/smoke/check.sh` (all four runs) | Passed, "all passed" in each |
| `cd scraper && python3 -m unittest discover -s tests` | Passed, 350 tests (348 in round 1, plus `HeaderTest`'s two) |
| Ketho's `forever` lists | Grepped again for #800's widget calls (table below) |

### Area notes, round 2

**Readability.** #800 is easy to follow. The steps are named constants, the cycle is a table (`NEXT_USABLE_STEP`), and `FilterLoot`'s comment says what each step does with the data. `Shows` is split so `UsableBy` answers one question for both the hide and grey sets. The migration of an old `true` sits in `LootFilter`, with a comment on why. `UsableTooltipText` and `ShowUsableTooltip` each do one job. Three small points, below nit level:
- `ns.UI.USABLE_GREY` / `USABLE_HIDE` are exported only for the smoke tests, without saying so.
- `CreateUsableBox` keeps the old `22` box size as a bare number (as before).
- `DungeonLink` falls back to the instance key (`"SHADOWFANG"`) as visible text when NeedRoll doesn't know the dungeon. Only a data typo can reach that, and R5 asked for a fallback.

R1's fix comments explain the game limit behind the new anchoring. R11 is the follow-up.

**WoW API.**

| Call, method or event round 2 adds or newly calls | In Ketho's `forever` lists | Where looked |
| --- | --- | --- |
| `CheckButton:GetCheckedTexture`, `:SetChecked` | yes | WidgetAPI.lua |
| `Texture:SetColorTexture`, `:SetDesaturated` (TextureBase) | yes | WidgetAPI.lua:261-262 |
| `Region:SetRotation`, `:SetVertexColor`, `:SetAlpha` (textures and the cell) | yes | WidgetAPI.lua:148-149 (Region) |
| `GameTooltip:IsOwned`, `:SetOwner`, `:AddLine` | yes (IsOwned listed; the others standard) | WidgetAPI.lua |
| `ns.UI.HoverMapLink` / `LeaveMapLink` on the spoiler (secure `/mappin` button) | NeedRoll's own; the button and its combat handling are unchanged | `MainFrame.lua:2956-2979` |
| `math.rad`, `unpack` | Lua 5.1 standard library | inferred |

- Combat-protected calls: round 2 adds none. The spoiler now holds the shared secure map link button out of combat, as every other map link's frame does. That button is hidden and moved to `UIParent` at `PLAYER_REGEN_DISABLED` (existing). `CHECKED_COMBAT_CALLS` is unchanged, and the `--combat` run passes. The new scenario clicks the link both out of and in combat.
- Every #800 phrase goes through literal `L["..."]` and is translated (#802). No new events, globals or `OnUpdate`. `wow.lua` already mirrors `SetRotation`, `IsOwned` and `SetDesaturated`.
- SavedVariables: `lootFilter.usable` changes from a boolean to a string, migrated on read and harmless to older copies (above). No other key changes.
- `docs/STYLE-GUIDE.md` was updated with the box, the X (two 12 × 2 strokes at ±45°, `Theme.tip.quiet` 0.6 grey and `color.incomplete`), the 0.4 alpha and desaturated icon, the migration, and the spoiler's frame. The values match the code (`USABLE_X_LENGTH`, `USABLE_X_THICKNESS`, `GREYED_ITEM_ALPHA`, `Theme.lua:191`).

**Redundant code.**
- `Cell:SetGreyed` is the only alpha or desaturation on a cell's icon (`grep SetDesaturated|SetAlpha( UI/LootGrid.lua`). It runs for every item cell drawn, so a reused cell can't keep a stale grey.
- `CreateUsableBox` builds on the game's `UICheckButtonTemplate`, as the old box did. There's no existing three-state control in `Theme` to reuse (`grep "^function Theme:"`).
- Nothing duplicated or dead in the fixes.

**Security.** Round 2 touches no addon message, chat or other player's input. #802's translations are data strings with the same `%s` counts as English (`translations.py`'s format check). No names were added (the `credits.json` / `observed.json` grep over round 2's added lines finds none).

## Area notes

### Readability

- `AddonMessages` (`Init.lua:423-505`) is a clear, single home for throttling and lockdowns. The header comment explains the game fact (10 messages, refilled one a second, per prefix) and why the lockdown wait is capped. The constants carry their units. Methods that use state use `:`, and pure lookups use `.`, consistently.
- `Version:Send` / `RetryLater`: guard clauses, one retry per chat, the reasons in the comment. The Switch block in `Drops.lua:71-94` lists every effect of the switch and where each lives.
- `SendNext` keeps its order: global switch, then lockdown, then the player's Off (wipe), with a comment per step.
- `KnowsEveryBoss`, `LeaveUnusedChannels`, `IsSharingSwitchedOff`, `HideListTabPanes`, `UI.contentPages`, `LootSources`, `ShowBossInOtherInstance`, `OptionalLeadIns`: names say what they do, and each does one job. `OptionalLeadIns` nests three loops (chain → step → quest ID), which is the data's shape. A step named `step` rather than `ids` would read a little better.
- The Welcome change (`ShowDropNotice` no longer marks a player who turned sharing off as answered, and the tick box starts as their saved Credit my finds) is intended. It is explained in the comment above `NOTICE_DELAY` and covered by the updated "drop sharing notice shows once" scenario.
- Scraper: `_hand_kept`, `world_holders`, `optional_lead_ins` and `_loot` have docstrings that say where the data comes from and why. `forever.json`'s `_about` documents `anyHumanoid`, `kills` and the hand-built seeds. One docstring line in `chains.py:10` is wrapped longer than its neighbours (89 characters, under the limit).
- Lua 5.1 traps: no `cond and nil or x` in the added lines (grep). `Theme:JoinDots` walks `select("#", ...)`, so `Chain.Lines`' nil `optional` in the middle is safe. The `needroll:boss:([^:]+):?(.*)` pattern is anchored, and no boss ID or pin key in `bossSpoilers` contains a colon.

### WoW API

| Call, event or enum the range adds or newly calls | In Ketho's `forever` lists | Where looked |
| --- | --- | --- |
| `C_ChatInfo.SendAddonMessage` (now only in `AddonMessages:Send`) | yes | GlobalAPI.lua:828 |
| `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted`, `C_ChatInfo.InChatMessagingLockdown` (the version check now calls them through `pcall`, as the outbox did) | yes | GlobalAPI.lua:789, 811 |
| `C_ChatInfo.RegisterAddonMessagePrefix` | yes | GlobalAPI.lua:824 |
| `Enum.SendAddonMessageResult.NotInGuild`, `AddOnMessageLockdown`, `TargetOffline` (added to `wow.lua`) | yes, values 10, 11, 12 match | LuaEnum.lua:7254-7268 |
| `LeaveChannelByName`, `GetChannelName`, `JoinTemporaryChannel` (`LeaveUnusedChannels`) | yes | GlobalAPI.lua:6203, 5338, 6193 |
| `C_Timer.After` (`Version:RetryLater`) | yes | GlobalAPI.lua:4174 |
| `InCombatLockdown`, `UnitAffectingCombat`, `IsInGuild`, `IsInGroup`, `IsInRaid`, `Ambiguate`, `UnitName` (unchanged callers) | yes | GlobalAPI.lua |
| `CheckButton:SetChecked` (`ShowDropNotice`) | yes | WidgetAPI.lua |
| Events `CHAT_MSG_ADDON`, `CHAT_MSG_CHANNEL_NOTICE` (and the other channel events), `GROUP_ROSTER_UPDATE`, `PLAYER_REGEN_ENABLED` | yes | Events.lua:301, 320, 1404, 2012 |
| `unpack` (`BACK_CLICKS`) | Lua 5.1 standard library | inferred |

- Combat-protected calls: the range adds none. `CHECKED_COMBAT_CALLS` (`tests/smoke/scenarios.lua`) is unchanged, and the `--combat` run passes. The new map link paths do the right thing in combat. `ShowOnMap` draws NeedRoll's own pin and prints the message. `ShowInDungeon` / `ShowBossOnMap` open NeedRoll's own map, never the game's. Hiding content pages and Settings rows touches no secure frame. Out of combat, the spoiler's dungeon link skips the secure `/mappin` button (R1).
- Async data: no new item or spell info requests. The spoiler's item link goes through the existing `ItemLink`.
- Events: no new registrations. The new PLAYER_LOGIN handler in `Welcome.lua` only writes a SavedVariable.
- Secret values: none newly touched. `IsHiddenChatLine` now calls `IsOurChannel` directly, which goes through `Plain` (the secret-value guard), as `IsOurChannelEvent` did.
- Globals: none new (luacheck base vs now). Dev-only sends (`Ping`, `Probe`, `RollCall`, `RefusesDevSend`, `RefusesWhileSwitchedOff`) are inside the `--@debug@` block (`Drops.lua:2003-2699`).
- Player-facing text: every new phrase goes through a literal `L["..."]`, and `locales.py --check` passes. R3 covers the reworded key. The dev-only prints in English match the rest of the dev commands.
- Smoke mirror: `wow.lua` gains the three enum values. New scenarios cover every PR with code. #796: lockdown cap, throttle wait, one retry per chat. #797: Settings rows hidden, notice not shown and reset, channel left, nothing queued or answered, dev commands refuse. Also #788's questline page, the optional lead-in, looted-from, any humanoid, and the spoiler's links. `run.lua` switches sharing on so the sharing scenarios keep testing it, and the switched-off scenarios turn it off themselves.
- Lua 5.1 limits: see R4.

### Redundant code

- Compared against `Theme:JoinDots`, `Theme:Pill`, `ns.UI.ShowOnMap`, `ns.UI.HoverMapLink`, `SourceSpot` (LootGrid), `EntranceLink` / `PageLink.PlaceSpot` (Overview), `UI:ShowInDungeon`, `ns.Data:IsBoss` and the existing `Drops` refusal paths. R5 (dungeon link resolved by hand) and R6 (one choice written in two shapes) are the only duplicates found.
- #796 removed the copies: `IsLockedDown`, `SendResultName`, `Refusal`, `LOCKDOWN_CHECKS` and the throttle counters now live once, in `AddonMessages`. `Version:Restricted` is gone, and its unguarded calls with it.
- `SendNext`'s `isSharingEnabled` check overlaps `Queue`'s `ChannelOn`, but the two do different jobs: one keeps the old outbox, the other refuses new entries. Both are commented.
- The dormant sharing code behind `isSharingEnabled` is kept on purpose (Mike) and not flagged.
- No new `OnUpdate`. No per-frame work. No unused locals (luacheck).

### Security

Untrusted inputs and outputs the range touches:
- **Addon messages heard** (`CHAT_MSG_ADDON`): parsing is unchanged. `AnswerRollCall` now also needs `Drops:ChannelOn()`, so with sharing switched off a prober's `U1` gets no answer and doesn't move `rollCallAnsweredAt`. Probes were already gated (`Drops.lua:1849`). Realm channel messages are read only while `ChannelOn` (`:1956`). Guild and group finds are still kept while switched off, through the existing length-checked, anchored decoders.
- **Addon messages sent**: every send now goes through `AddonMessages:Send` (grep: the only `C_ChatInfo.SendAddonMessage` is `Init.lua:498`). It shares one throttle count, so three throttled answers from any sender stop all of NeedRoll's messages for the session. That includes version whispers, which before #796 used the same prefix budget but weren't counted. Residual, older than this range: `Version:Heard` answers any older copy's `V:`, from any chat type, once per sender per session. Many distinct senders in a short burst could therefore use up the prefix's budget. The once-per-sender memory bounds it, and while sharing is switched off the only cost is the session stop.
- **Share drops Off**: honoured by every drop, quest, trainer, probe and roll call path (`Queue`, `SendNext` wipe, `AnswerRollCall`), but not by the version check (R2).
- **SavedVariables**: `dropOutbox` is still capped by `OUTBOX_MAX` and isn't touched while switched off. The login reset writes only `shownDroptalkConsent`.
- **Text shown from others**: nothing new is shown in the UI or chat.
- **Names**: none in added lines (Checks). `CHANGELOG-DETAILED.md` says "No player names here" and is ignored by `.pkgmeta`. `scraper/classes/seen.json`, `trainer_checks.json` and `quests/logged.json` stay under `scraper/`, which `.pkgmeta` ignores.
- **Scraper**: no network calls added (QuestieDB read at build time, as before), no `shell=True`, `eval` or `pickle`. `json.loads` on the repo's own `forever.json`, with `int()` on its keys. No workflow or `tools/` changes in the range.

## Round history

- 2026-11-07, round 1, `a1e9a6d`: Changes needed (0 blocking, 3 should fix, 7 nits). Opened R1-R10.
- 2026-11-07, round 2 (last), `f1b7899` (fixes `9332659`, plus #800, #801, #802): Ready (0 blocking, 0 should fix open, 1 nit open). Fixed: R1, R5, R6, R7, R8, R9, R10. Resolved: R3 (Translations PR #802). Left as is by Mike: R2. Deferred: R4. Opened: R11.
