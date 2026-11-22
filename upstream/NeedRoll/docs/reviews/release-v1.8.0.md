# Review: v1.8.0 release (everything merged into dev since v1.7.0)

| | |
| --- | --- |
| Branch | `v1.7.0..origin/dev` (round 1: `7aefdbc8..b87f8b2e`, PRs #896–#928; round 2 adds `b87f8b2e..9715226b`, PRs #929–#933, and the fixes `9715226b..ef8b95db`), on `claude/project-thread-ociyz4` into `dev` |
| Commit reviewed | Round 1 `b87f8b2e`; round 2 `ef8b95db` (no uncommitted changes) |
| Date | 2026-11-16 |
| Round | 2 (the last; Mike decides what's left) |
| Verdict | **Changes needed** (0 blocking, 3 should fix, 4 nits open: R8–R14; R1–R4, R6, R7 fixed, R5 left as Mike's decision) |
| Needs | Players: a **full game restart**. The `.toc` gains `Core\TrainerShare.lua`, `Core\Vendors.lua`, `Data\FoodBuffs.lua`, `Data\ItemChains.lua`, `Data\KnownVendorRecipes.lua` and `Data\VendorItems.lua`, `UI/UI.xml` gains `WorldMapMarkers.lua` and `Data/Data.xml` two lines; the game reads a new file list only at start-up (inferred, as in earlier reviews). New SavedVariables keys: `mapMarkers`, `trainerServices`, `vendorRecipes`, `vendorItems`, `dropPush`; dev builds also `vendorMissing` and `dropPull.answered` / `heard` / `selfNames`. `channelRefusedAt` is cleared at every login. Round 2 (#929–#933) adds no file to the `.toc` or the XML lists; it adds `dropSharers` (players heard sharing, Share drops on only), `senders` on heard trainer ranks, services and quests, and `tag` on saved quests, all created when first written. |

## What the change does

**Drop sharing without the realm channel (PR #900, #903, #907).** The
realm channel is now `NRDropTalk`, joined only for its member list: nothing
is ever sent there, and the old NRDT is left at login. All the channel
check code (echo test, refusal, listen mode, `/nr droptalk ping` and
`probe`) is gone. A find goes to the group, or the guild outside one, and
the guild (`GROUP_OR_GUILD`), plus Battle.net friends. A copy now answers a
PROBERS character's whispered probe with its own finds **and** the kills,
quests and trainer reports it heard from its guild, group and friends
(heard kills lose their finder's name and credit flag). Answering a probe
starts a **push**: for three days each new find of the player's own is
also whispered to that character (`NeedRollDB.dropPush`), until a whisper
bounces. The dev-only pull (`Core/DropPull.lua`) asks past sharers by name
when the channel gives no member list.

**Vendor sharing (PR #905, #909).** `Core/Vendors.lua` reads every merchant
window (filter switched to All and back), saves the recipes (V1) and rare
stock (S1) NeedRoll doesn't know that vendor sells, and shares them in a
"vendor" lane, ten a day. Heard V1/S1 messages are saved marked heard,
never shown. Search lists items only a few vendors sell, with "Sold by".

**Trainer sharing (PR #906, #910, #916, #918, #919, #922).** Class trainer
ranks travel as A1 (with the reader's standing and race; reputation
discounts aren't changes). `Core/TrainerShare.lua` reads profession, pet
and poison trainers and shares differences as P1. Both go to friends and
into probe answers.

**World map (PR #902, #904, #921, #925).** Quest givers of dungeon and raid
quests within 10 levels, and unfound library books, get markers on the
game's zone maps, with a NeedRoll dice button cycling all / incomplete /
off. Dungeon maps get a strip of floor chips that turn the game's map
(`C_Map.OpenWorldMap`, refused in combat with a chat line). A map pin link
keeps NeedRoll's window open.

**Quests and lists (PR #908, #911, #913, #915, #917, #924, #927).** Attune
sync: "all of" chain steps, breadcrumbs, item chains (dungeon keys, Aqual
Quintessence) on Overview pages. Questline pages are redrawn with numbered
steps, group boxes, a purple "goal" and a Next step guide. Cooking gets a
Buff box and the recipe filter finds buffs by the game's own words. Each
Factions row shows the character's standing and a bar. Magram and Gelkis
reputations were added (#901); their grouping (#923) was reverted (#928).

**Scraper (all of the above, plus #912, #896, #914, #920, #926).** New
`foodbuffs`, `itemchains`, `knownvendors`, `vendoritems`, `npcspots`,
`trainerservices`; `ingest` folds the new SavedVariables tables into
`vendors_seen.json` and `trainer_services.json` and lists heard ones in the
Watcher data pull request.

## Scope

- `NeedRoll/Core/Drops.lua`: whole diff read (header, `CARRIES_VERSION`, `PackFields`, `EncodeKill`, the realm channel and joining, the outbox and `GROUP_OR_GUILD`, Whispers, **Push after a pull**, Lanes and `NextSendable`, `SendNext`, `Queue`, `BattleNet.Queue`, `QueueOwnFind`, trainer A1/P1 encode/decode, `QueueLaneMessage`, vendor V1/S1 encode/decode, Catch-up probes with relayed answers, roll call to the guild only, `Whispers.Read`, `BattleNet.Read`, `CHAT_MSG_ADDON`, the removed listen/ping/probe commands).
- `NeedRoll/Core/Vendors.lua` (new): read in full.
- `NeedRoll/Core/TrainerShare.lua` (new): read in full.
- `NeedRoll/Core/Trainers.lua`: Races, Reputation discounts, `SaveRead`, `RankGroups`, `Share`, `AddAnswers`, `Answers`, `SaveHeardRank`, `SaveHeard`; the debug block opened for TrainerShare.
- `NeedRoll/Core/DropPull.lua` (dev only, `.pkgmeta` ignores it): whole diff (This character, Past sharers, `Candidates`, `PastSharerCandidates`, `Ask`, `AskOne`).
- `NeedRoll/Core/TrainerCheck.lua` (dev only): moved onto TrainerShare's read; skimmed.
- `NeedRoll/Core/Init.lua`: new defaults, two Modules entries, `ns.NpcIDOf`, `AddonMessages.Refusal` without "channel", slash command parts. `Core/Names.lua`: item chain NOTES, `Names.IsLearnedFromTrainer`, vendor names indexed. `Core/LibraryBooks.lua`: `STATUS_TEXT` moved here.
- `NeedRoll/UI/WorldMapMarkers.lua` (new): read in full.
- `NeedRoll/UI/WorldMapOverlay.lua`: floor chips (`DungeonFloors`, `FloorLabel`, `ShowFloor`, `DrawFloorChips`, `FollowGameMapForFloors`, `CreateFloorBar`), `LayOnGameMap` exported.
- `NeedRoll/UI/MainFrame.lua`: `ShowLibraryFromWorldMap`, the map pin link's PostClick.
- `NeedRoll/UI/Questlines.lua`: the stage builders (`PlaceVersionSteps`, `PickGroup`, `PickNearestVersions`, `AddAllOfGroups`, `BuildStage`), `StepNumbers`, the page constants, pools, cards, `PaintCard`; the drawing rewrite (route, groups, goal, guide) read for style, not line by line.
- `NeedRoll/UI/DungeonQuestlines.lua`: `FoldSteps` with all-of steps, the guide (`NextStepIDs`, `ObjectivesText`, `PlaceWords`, `NextStep`, `Goals`, `CurrentNumber`, `DistanceText`, `LeadsToText`, `GoalNote`).
- `NeedRoll/UI/Overview.lua`: Chain helpers (`Mark`, `MarkedLink`, `IsPickOne`, `ShownID`, `StepText`, `IsGoal`, `StartText`), chain rows, floor-change combat message, the whole `Attunement` table (item chains), `CreateOverview`'s fold widgets.
- `NeedRoll/UI/Lists.lua`: Factions standing (`STANDING`, `NewStandingBar`, `FillStandingBar`, `WriteStanding`, `ShowFactionStanding`), `Folds.GoalNote`/`ShowGoal`, `BuffMatches`, `RecipeMatches`.
- `NeedRoll/UI/RecipeBand.lua`: `BUFFS`, `BuffLabel`, the Buff box and menu, `PlaceCentred`, `IsLearnedFromTrainer` use.
- `NeedRoll/UI/Reputation.lua`, `LootGrid.lua` (item costs, `StandingText`, `buyFrom`), `Search.lua` (vendor-only items, item chains), `Theme.lua` (goal colours, `RoundedBarTexture`, `nativeBar`, `DashedOutline`, `Glow`, portal mark, `SortMark`), `Wishlist.lua` (uses `Theme:SortMark`), `LibraryBooks.lua`, `Settings.lua` and `Welcome.lua` (consent text), `DropTalk.lua` (dev only).
- `NeedRoll/Data/Data.lua` (hand-written registry): read in full diff (`StepRuns`, `FittingRuns`, `ChainStepProgress`, `StepNumbers`, `NextStepIndex`, `QuestsToPickUp`, item chains, `StepQuests`, `ChainQuests`, `PairedVendor`, vendor items, food buffs).
- `NeedRoll/Locales/enUS.lua`: 95 lines; checked by the tools, not read line by line.
- Scraper: `knownvendors.py`, `vendoritems.py`, `trainerservices.py` read for input validation and report output; `foodbuffs.py`, `itemchains.py`, `npcspots.py` read for sources and file IO; `__main__.py`'s ingest and vendor build; `sources/wowhead.py`'s retired fetch path. Other changed modules skimmed.
- Workflows: `daily-data.yml` (two build steps), `watcher-data.yml` (npcspots, report assembly).
- Tests: `tests/smoke/wow.lua` (merchant, guild roster, map groups, `UnitReaction`, no channel sends), `scenarios.lua`, and the modules for Vendors, TrainerShare, Trainers, Drops, DropPull, WorldMapMarkers, WorldMapOverlay; `tests/smoke/locales/*.lua` checked by the tools.
- Generated data, skipped for style: `NeedRoll/Data/Dungeons/*.lua`, `Factions/*.lua`, `Attunements.lua`, `Chains.lua`, `ClassQuests.lua`, `ClassSpells.lua`, `CompanionSources.lua`, `FoodBuffs.lua`, `ItemChains.lua`, `KnownDrops.lua`, `KnownQuests.lua`, `KnownVendorRecipes.lua`, `ProfessionGuide.lua`, `Quests.lua`, `RecipeDrops.lua`, `RecipeSources.lua`, `VendorItems.lua`, `Abilities.lua`. Every commit touching them also touched its generator, or was a Watcher data workflow commit (`83441cfd`); the commits touching only `Data/Data.lua` edit the hand-written registry. No hand edit to a generated file found.
- Scraper JSON inputs (`scraper/**/*.json`): checked only for player names (see Checks).
- Not in scope: `CHANGELOG.md`, `CHANGELOG-DETAILED.md` (the changelog PR updates them).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 61 changed hand-written Lua files and every changed file under `NeedRoll/Data/` | passed (Lua 5.1.5 installed for this review) |
| `luacheck --no-global -q` now vs `v1.7.0` (luacheck 1.2.0), warnings compared without line numbers | New warnings: `Overview.lua:4049,4059,4060` shadowing upvalue `parent` (R7); `Lists.lua:2124` line too long, a comment (R7); `tests/smoke/modules/UI-WorldMapOverlay.lua:509` unused `L` (R7). The other new long lines are `L["..."]` phrases (`Init.lua:303,307`, `Names.lua:155-174` NOTES, `Overview.lua:794`, `enUS.lua`), kept one phrase per line as the locale files are |
| `tests/smoke/check.sh` (dev, packaged, secret values, in combat) | passed: exit 0, "all passed" in all four (230 / 221 / 230 / 230 files loaded; 757 / 662 / 757 / 757 scenarios ok) |
| `tests/smoke/check.sh --locale all` | passed: exit 0, "all passed" for all 11 clients (230 files each). enUS 761 scenarios ok; each of the other ten 635 ok, with 126 skipped as "they expect English text" (`tests/smoke/locale.lua`'s `SKIPPED`, the same 126 as v1.7.0) |
| `python3 tools/locales.py --check` | passed (exit 0, no output) |
| `python3 tools/translations.py` | passed (exit 0). It notes five zhTW phrases "not used by NeedRoll any more": the old consent, Settings and Welcome texts this range rewrote, and "Do one of these" / "In this dungeon" |
| `python3 tools/locale_strings.py --check` | passed (exit 0) |
| `python3 tools/font_coverage.py --check` | passed (exit 0) |
| `cd scraper && python3 -m unittest discover -s tests` | passed (457 tests) |
| Lua 5.1 limits (extra; `luac5.1 -l -l`, locals declared in the main chunk, an upper bound on those active at once / most upvalues in one function, now vs `v1.7.0`) | `Overview.lua` 199 / 200, most upvalues 34 (unchanged). `Drops.lua` 197 / 197, 16 upvalues. `LootGrid.lua` 192 / 190. `Questlines.lua` 157 / 155. `RecipeBand.lua` 162 / 136. `Lists.lua` 138 / 127, `CreateEncounterList` 44 upvalues (unchanged). None over a limit; Overview.lua and Drops.lua stay the ones to watch |
| WoW API names (extra) | every new `C_` call, global function, event, widget method, `Enum`, atlas and global string grepped in Ketho's `forever` lists: all present (table under Area notes) |
| New globals (extra; `luacheck --std lua51`, "setting global", now vs `v1.7.0`) | none |
| Combat-blocked calls (extra) | `CHECKED_COMBAT_CALLS` unchanged; every new frame that passes right-clicks uses `ns.UI.PassRightClicks` (markers, mode button, floor chips); the combat run passes |
| Player names (extra) | none: 380 names from `scraper/drops/credits.json` appear in no file under `NeedRoll/`, `docs/`, `.github/`, `README.md` or the changelogs (`grep -w -F -f`). `.pkgmeta` still ignores `Core/DropPull.lua` and `UI/DropTalk.lua`, the only addon files that keep names |
| Wowhead and QuestieDB (extra) | no request path: `sources/wowhead._fetch` reads the cache or raises `Retired`; `knownvendors.wowhead_sellers` catches it. No QuestieDB or Attune file added to the repo (`git diff --name-status --diff-filter=A`) |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Security | `NeedRoll/Core/Vendors.lua:52-53`, `:356-410`; `scraper/needroll_scraper/knownvendors.py:261-313`; `vendoritems.py:214-232`; `.github/workflows/watcher-data.yml:128-131` | Heard vendor reads: up to 200,000 saved items per player, and every heard one ever is printed, unescaped and uncapped, into each Watcher pull request | fixed in round 2 (`414d43bc`, `08496276`) |
| R2 | should fix | Readability (§9; what reaches PROBERS characters) | `NeedRoll/Core/Drops.lua:899-903`, `:1289-1292`; code at `:2136` | The push comments say only D2, Q1, A1 and P1 are whispered to the prober; V1 and S1 vendor messages are pushed too | fixed in round 2 (`a696d774`) |
| R3 | nit | Readability (§6, §9) | `NeedRoll/Core/Drops.lua:1035`, `:839-843`, `:1181`; `tests/smoke/modules/Core-Vendors.lua:141,179` | New vendor messages are queued for "CHANNEL", a destination nothing is sent to | fixed in round 2 (`a696d774`) |
| R4 | nit | Redundant code | `NeedRoll/Core/Vendors.lua:65-69`; `Core/DropPull.lua:332-336`; `Core/Trainers.lua:285-289,559`; `Core/Trainers.lua:393-415` and `Core/TrainerShare.lua:389-411` | Two more copies of key counting, and two copies of the report grouping | fixed in round 2 (`e017f060`, `414d43bc`) |
| R5 | nit | Security (consent) | `NeedRoll/UI/Welcome.lua:136-145`; `Locales/enUS.lua:1344,1469-1470` | Sharing grew (vendor stock, trainer services, relayed guild finds, three-day pushes) without a new round of asking | left as is: Mike's decision of 2026-11-16, recorded by `DROP_NOTICE_ROUND` (`bb8d620c`) |
| R6 | nit | Security (robustness) | `NeedRoll/Core/Drops.lua:922-928` | A push saved with a time ahead of the clock lasts past three days | fixed in round 2 (`a696d774`) |
| R7 | nit | Readability | `Lists.lua:2124`; `Overview.lua:4049-4061`; `MainFrame.lua:2675-2678`; `Drops.lua:1295`; `WorldMapMarkers.lua:142-159`; `tests/smoke/modules/UI-WorldMapOverlay.lua:509` | Small slips: a long comment, a shadowed `parent`, a stub comment line, `false` for "no lane", four nested loops, an unused local | fixed in round 2 (`bb8d620c`, `a696d774`) |
| R8 | should fix | Security (untrusted input reaching shipped data) | `NeedRoll/Core/Drops.lua:2197`, `:2258`, `:2801-2818`, `:2850`; `Core/Trainers.lua:478`; `Core/TrainerShare.lua:431`; `scraper/needroll_scraper/senders.py:84-95`; `classspells.py:935-950`; `questdifferences.py:177-204` | Relayed probe answers make one made-up report count as "two players agree", which the scraper applies to class trainer ranks and quest pages | open |
| R9 | should fix | Security (untrusted input) | `NeedRoll/Core/Drops.lua:1748`; `scraper/needroll_scraper/senders.py:75-81`; `questdifferences.py:210` | A heard quest's build isn't capped, so one made-up build stops every two-player quest confirmation | open |
| R10 | should fix | Security (text from other players in a pull request) | `scraper/needroll_scraper/questdrafts.py:193-215`; `trainerservices.py:202-205` | Heard quest titles and trainer service names still reach the Watcher pull request as Markdown, and the drafts list has no cap | open |
| R11 | nit | Security (privacy) | `NeedRoll/Core/Drops.lua:2478-2490`, `:2615-2690`, `:467-472`; `scraper/needroll_scraper/senders.py:1-13`, `classspells.py:99,259`, `trainerservices.py:18,55` | Referrals and sender keys identify players who chose "Credit my finds" Off; every copy keeps keys only Mike's dev builds use; "one-way" overstates a 32-bit hash of a name | open: Mike's decision |
| R12 | nit | Security (consent) / every client's language | `NeedRoll/UI/Welcome.lua:206-208`; `UI/Settings.lua:129-130`; `Locales/*.lua` | The consent notice and Share drops tip are in English on the other ten clients until the Translations PR lands | open |
| R13 | nit | Redundant code | `scraper/needroll_scraper/senders.py:26-31`, `trainerchecks.py:58`, `knownvendors.py:183` | Three copies of the SavedVariables whole-number helper, and the shared one lives in senders.py | open |
| R14 | nit | Readability | `NeedRoll/Core/Drops.lua:2098-2100`, `:2225-2227`; `Core/Trainers.lua:386-394`; `tests/smoke/modules/UI-MapEdit.lua:43-45`; `UI-Overview.lua:767`; `Core-Vendors.lua:244-266` | Small slips from the fixes: stale "nil when not known" encoder comments, MapEdit's half undo of a preview, a weakened chance check, hand-counted keys in a test | open |

### R1 · Heard vendor reads: up to 200,000 saved items per player, and every heard one ever is printed, unescaped and uncapped, into each Watcher pull request
- **Severity:** should fix
- **Area:** Security (untrusted input growing SavedVariables, and reaching a pull request body)
- **Where:**
  - Addon: `NeedRoll/Core/Vendors.lua:52-53` (`VENDORS_MAX = 500`, `ITEMS_MAX = 200`), `:356-364` (`HeardVendor`), `:369-382` (`AddHeardItems`), `:391-410` (`SaveHeard`). Reached from `Drops.TakeVendorMessage` (`Core/Drops.lua:2303`), which reads V1/S1 from the guild, the group, Battle.net friends and (dev) whispers.
  - Scraper: `scraper/needroll_scraper/knownvendors.py:261-287` (`merge_seen` keeps every vendor ever folded in), `:289-313` (`vendor_text`, `report`); `vendoritems.py:214-232` (`report`).
  - Workflow: `.github/workflows/watcher-data.yml:128-131` (`cat "$RUNNER_TEMP/ingest.md" >> body.md`, no cap).
- **Status:** fixed in round 2 (`414d43bc`, `08496276`; see Round 2)

**What's wrong.** Anyone in the player's guild or group, or a Battle.net
friend, can send V1 and S1 messages. A heard one is kept per kind for up to
500 vendors with up to 200 items each:

```lua
local VENDORS_MAX = 500   -- vendors saved of each kind; past it a heard one isn't saved, and a read drops the oldest
local ITEMS_MAX = 200     -- items saved per vendor (a vendor sells far fewer)
...
    elseif kept.heard and CountKeys(kept.items) < ITEMS_MAX then
        kept.items[item.item] = { price = item.price, limited = item.limited, shared = true }
```

That is 2 × 500 × 200 = 200,000 item entries in every player's
SavedVariables. On an ordinary player's copy a heard read is never shown
and never sent again; it is kept only so the player's own read of the same
items isn't sent twice. The trainer files cap heard reports at 600 in all
(`SERVICES_MAX`, `SPELLS_MAX` per class).

On Mike's own accounts the heard reads go further. `ingest` folds them into
`scraper/professions/vendors_seen.json` and never drops one
(`merge_seen`). The vendor reports then walk that whole file on every run
and print one line per heard vendor:

```python
            heard.append(f"- Heard: {who}: " + ", ".join(
                item_text(item, item_names) + (" limited" if items[item].get("limited") else "") for item in unknown))
```

`who` is `vendor_text`, which carries the vendor name another player
wrote. `_clean_name` strips control characters and `|` but nothing that
GitHub Markdown reads: `@name`, `[text](url)` and `![img](url)` all pass.
The workflow appends the whole ingest report to the pull request body.

**Why it matters.**
- *SavedVariables.* One player in a guild can fill every guildmate's saved
  file with up to 200,000 entries, roughly 10 MB at ~50 bytes each
  (inference). At about 17 items per 250-byte message that takes about
  12,000 messages, a few hours at the game's addon throttle (inference).
  Logins and `/reload`s get slower, and the data does nothing for those
  players.
- *Pull requests.* Heard vendors pile up in `vendors_seen.json` from run to
  run, so even honest heard reads make each Watcher pull request longer.
  `peter-evans/create-pull-request@v7` cuts a body over 65,536 characters
  (inference from the action's documented behaviour). The "Trainer
  services" section and the "Class spells" section come after the vendor
  lines, so they are the parts that get cut.
- *Markdown.* A made-up vendor name such as `@someone` or
  `[Recipe](https://…)` shows as a mention (GitHub notifies that user) or a
  link in Mike's pull request.

**Evidence.**
- Read `Vendors.lua:52-53, 356-410`, `knownvendors.py:189-313`,
  `vendoritems.py:214-232` and `watcher-data.yml:117-160`.
- `Drops.DecodeVendorMessage` (`Drops.lua:2280-2300`) bounds each field and
  rejects `|` in names. `Vendors.SaveHeard` keeps only real recipes (V1) or
  existing non-junk items (S1). Both checks hold, but neither bounds how
  many vendors are saved.
- No smoke scenario fills the heard tables. The sizes and the action's
  truncation are inference.

**Fix.**
1. Give heard reads their own small caps, separate from the player's own:

   ```lua
   local HEARD_VENDORS_MAX = 100 -- heard vendors kept per kind; they're only there so own reads aren't sent twice
   local HEARD_ITEMS_MAX = 40    -- items kept per heard vendor
   ```

   Use them in `HeardVendor` (count only `heard` vendors) and
   `AddHeardItems`.
2. In the scraper, list only the heard vendors added or updated by this
   ingest (`merge_seen` already knows which), cap the Vendors section as
   the workflow caps Class spells (`head -c 30000`), and print the vendor
   name in backticks or escape `@`, `[`, `]`, `(`, `)`, `!`.

### R2 · The push comments say only D2, Q1, A1 and P1 are whispered to the prober; V1 and S1 vendor messages are pushed too
- **Severity:** should fix
- **Area:** Readability (§9: comments say something the code doesn't do), about what reaches Mike's PROBERS characters
- **Where:** `NeedRoll/Core/Drops.lua:899-903` (Push after a pull), `:1289-1292` (`Push.Queue`); the code at `:2120-2137` (`Drops.QueueLaneMessage`)
- **Status:** fixed in round 2 (`a696d774`)

**What's wrong.** The Push section lists what a push carries:

```lua
-- probes) remembers that character for Push.DAYS days. Meanwhile each new
-- find of the player's own (a D2 kill, a Q1 quest, an A1 or P1 trainer message)
-- is also whispered to them
...
-- Queues one of the player's own finds (D2, Q1, A1 or P1) for the PROBERS
-- character a push goes to, if any (see Push after a pull). A trainer
-- message's push isn't marked as one: the group's copy of it already counts
-- towards the trainer lane's daily messages (see Lanes).
```

But `Drops.QueueLaneMessage` pushes every lane message, and
`Vendors.Share` queues V1 and S1 through it (`Vendors.lua:331`):

```lua
    Queue(text, LANES[lane].to, id, nil, lane)
    if LANES[lane].toFriends then BattleNet.Queue(text, id, lane) end
    Push.Queue(text, id)
```

`Core/DropPull.lua`'s header says pushes carry V1 and S1 too, so the two
files disagree.

**Why it matters.** The Push section is where a reader checks what a
release copy whispers to Mike's characters unprompted (Mike's rule of
2026-11-12). Someone reading it before changing the push, or checking it
against the consent text (R5), gets the wrong list. They also don't learn
that a vendor visit's pushes go ahead of the vendor lane and outside its
ten a day: push entries have no lane, so `Queue` puts them in front of
lane entries.

**Evidence.** Read `Drops.lua:895-928`, `:1286-1305`, `:2120-2137` and
`Vendors.lua:327-335`. `DropPull.lua:17-21` lists "D2, Q1, T1, A1, P1, V1
and S1 answers and pushes".

**Fix.** If vendor pushes are intended (they are the player's own finds),
make both comments say so:
- "(a D2 kill, a Q1 quest, an A1 or P1 trainer message, a V1 or S1 vendor
  message)";
- "A lane message's push isn't in its lane: the group's copy already
  counts towards the lane's daily messages."

If they aren't intended, push only in `QueueOwnFind` and for
`lane == "trainer"`.

### R3 · New vendor messages are queued for "CHANNEL", a destination nothing is sent to
- **Severity:** nit
- **Area:** Readability (§6: one way of doing each thing; §9)
- **Where:** `NeedRoll/Core/Drops.lua:1035` (`vendor = { daily = 10, to = "CHANNEL", toFriends = true }`), `:839-843` (the outbox comment), `:1181` (`Destination`); `tests/smoke/modules/Core-Vendors.lua:141,179` assert it
- **Status:** fixed in round 2 (`a696d774`)

**What's wrong.** This release stops sending on the realm channel. Every
new message goes out as `GROUP_OR_GUILD`, the trainer lane included. The
vendor lane, also new in this release, is queued for `"CHANNEL"`, and
`Destination` turns that into `GROUP_OR_GUILD` every time:

```lua
    if to == "GROUP_OR_GUILD" or to == "CHANNEL" then to = GroupOrGuild() end
```

The outbox comment says CHANNEL "goes as GROUP_OR_GUILD while that lasts:
V1 and S1 messages are queued for it". That reads as if the channel might
carry them again some day. The code has no such switch, and the header
promises "Nothing is ever sent on NeedRoll's hidden realm channel".

**Why it matters.** A reader sees `to = "CHANNEL"` for a new kind of
message and has to work through `Destination` to learn it never reaches a
channel. A later change to `Destination` that sends CHANNEL to the channel
again would break the "nothing on the channel" promise for vendor messages
only.

**Evidence.** Read `Drops.lua:832-845`, `:1019-1036`, `:1175-1188`. The
two smoke asserts above check `to == "CHANNEL"`.

**Fix.** `vendor = { daily = 10, to = "GROUP_OR_GUILD", toFriends = true }`.
Change the comment to "CHANNEL: only in outboxes saved by releases before
NRDropTalk; sent as GROUP_OR_GUILD", and update the two asserts. Behaviour
doesn't change: both values go through the same branch.

### R4 · Two more copies of key counting, and two copies of the report grouping
- **Severity:** nit
- **Area:** Redundant code
- **Where:**
  - key counting: `NeedRoll/Core/Vendors.lua:65-69` (`CountKeys`, new), `Core/DropPull.lua:332-336` (`CountPlayers`, new), `Core/Trainers.lua:285-289` (`CountKeys`, exported at `:559` as `Trainers.CountKeys` for TrainerShare); `UI/DropTalk.lua:297` is an older copy;
  - grouping: `Core/Trainers.lua:393-415` (`RankGroups`) and `Core/TrainerShare.lua:389-411` (`ServiceGroups`).
- **Status:** fixed in round 2 (`e017f060`, `414d43bc`)

**What's wrong.** The same four-line "count a table's keys" helper now
exists three times in Core, one of them exported from Trainers.lua for
another file to borrow. `RankGroups` and `ServiceGroups` differ only in
which fields make the group key and what a rank row carries. Both build
`key`, fill `groups`/`order`, sort `order`, then sort each group's ranks by
spell.

**Why it matters.** Not a bug: a reader meets the same code twice, and a fix
to one copy (say the sort order) may miss the other.

**Evidence.** Read the lines above; `grep -rn "for _ in pairs(" NeedRoll`.

**Fix.**
- One `ns.CountKeys(map)` in `Core/Init.lua` beside the other shared helpers
  (`ns.HeardNumber`, `ns.NpcIDOf`).
- One `Drops.GroupReports(saved, IsWanted, KeyOf, RankOf)` (or in
  Trainers.lua, since TrainerShare already leans on it) returning the sorted
  groups.

Keep both message formats as they are.

### R5 · Sharing grew (vendor stock, trainer services, relayed guild finds, three-day pushes) without a new round of asking
- **Severity:** nit
- **Area:** Security (what a player agreed to share)
- **Where:** `NeedRoll/UI/Welcome.lua:136-145` (`DROP_NOTICE_ROUND = 2`); the texts at `Locales/enUS.lua:1344` (Settings tip) and `:1469-1470` (notice)
- **Status:** left as is: Mike's decision of 2026-11-16, recorded in the comment by `DROP_NOTICE_ROUND` (`bb8d620c`): the reworded notice and tip, with a line about referrals, stay in round 2

**What's wrong.** Round 2 players said yes to sharing "the boss drops, new
quests and class trainer spells you see". This release also sends:
- what vendors sell;
- what profession, pet and poison trainers teach;
- the player's race and standing with each trainer;
- in a probe's answer, finds heard from their guild, group and friends (no
  names);
- for three days after a probe, each new find of their own by whisper to
  the prober, which saves that character's name in their SavedVariables.

The notice and the Settings tip were rewritten for vendors and trainers.
The round wasn't bumped, so a yes from v1.7.0 carries over. The header
comment says the round goes up "when drop sharing changes enough to ask
again".

**Why it matters.** None of it is personal. Heard finds lose names and
credit flags, and the push target is Mike's own character, whose name the
player's client already sees as the whisperer. But whispers unprompted by
the player's own action are new: v1.7.0's rule (2026-11-09) was "no copy
ever whispers unprompted". Whether that is "enough to ask again" is a
policy call.

**Evidence.** `git log -S DROP_NOTICE_ROUND v1.7.0..origin/dev` finds no
change. Read `Welcome.lua:130-145` and the old and new texts in the
`Settings.lua` and `Welcome.lua` diffs.

**Fix.** Either bump `DROP_NOTICE_ROUND` to 3 and add a line to the round
comment ("round 3: vendor and trainer sharing, relayed finds and pushes,
v1.8.0"), or leave it and note Mike's call in that comment.

### R6 · A push saved with a time ahead of the clock lasts past three days
- **Severity:** nit
- **Area:** Security (robustness of a saved limit)
- **Where:** `NeedRoll/Core/Drops.lua:922-928` (`Push.Target`)
- **Status:** fixed in round 2 (`a696d774`)

**What's wrong.**

```lua
    if time() - push.since >= Push.DAYS * 24 * 3600 then return nil end
```

A `since` later than `time()` (the computer's clock was set back after the
probe) gives a negative age, so the push holds until the clock passes
`since` plus three days. The channel refusal this release removed guarded
against exactly that ("A saved time ahead of the clock … doesn't count, so
a wrong clock can't keep the channel shut for longer than a day").

**Why it matters.** A clock set back a week keeps whispering the player's
finds to the prober for ten days, and keeps the character's name in their
saved file as long. That is past the three days Mike set.

**Evidence.** Read `Drops.lua:922-934`; the removed `ChannelRefusal.IsFresh` in the diff.

**Fix.**

```lua
    local age = time() - push.since
    if age < 0 or age >= Push.DAYS * 24 * 3600 then return nil end
```

### R7 · Small slips: a long comment, a shadowed `parent`, a stub comment line, `false` for "no lane", four nested loops, an unused local
- **Severity:** nit
- **Area:** Readability
- **Where / what / fix:**
  - `NeedRoll/UI/Lists.lua:2124`: the `RecipeMatches` comment line is 130
    characters (new luacheck warning; the rule is 120 for new lines).
    Rewrap it.
  - `NeedRoll/UI/Overview.lua:4049, 4059, 4060`: `pane.newFoldWidget`'s
    `function(parent)` shadows `CreateOverview(parent)` (three new
    luacheck warnings). A reader can't tell which `parent` the heading is
    made on. Call it `holder` (it is the pool's holder frame).
  - `NeedRoll/UI/MainFrame.lua:2675-2678`: removing "as after a map pin
    link" left "so the window closes once it shows. In" on a short line,
    with "combat NeedRoll never…" on the next. Rewrap.
  - `NeedRoll/Core/Drops.lua:1295`: `Push.Queue` passes `false` as the
    lane (`Queue(text, "WHISPER", id, "push", false, target)`), so the
    entry is saved with `lane = false`. `Answer` passes `nil` for the same
    "no lane" (`:2533`), and the Lanes comment says "nil for one in none".
    Pass `nil`.
  - `NeedRoll/UI/WorldMapMarkers.lua:142-159`: `QuestsToTake` nests
    for category, for instance, for quest, if, four levels (the rule is
    three). Pull out `AddInstanceQuests(found, byID, instance, side,
    classToken, showsAll)`.
  - `tests/smoke/modules/UI-WorldMapOverlay.lua:509`: unused local `L`
    (new luacheck warning).
- **Status:** fixed in round 2 (`bb8d620c`, `a696d774`)

**Why it matters.** None changes behaviour. Each is a line a newcomer
stumbles on, or a new luacheck warning in the release.

**Evidence.** luacheck now vs `v1.7.0` (Checks); `git blame` puts each line
in this range (`f4188b9c`, `28c46e66`, `42ded873`, `6661c39e`, `c8c54794`).

## Area notes

### Readability

Checked every changed function listed under Scope against
`docs/READABLE-CODE.md`:
- Names are in the game's terms: `TrainerStanding`, `PlayerRaceID`,
  `ListedRank`, `PaysShippedCost`, `IsDiscountedCost`, `HeardVendor`,
  `QuestsToTake`, `NextPickup`, `StepGiver`, `FollowGameMapForFloors`.
- Every new number has a named constant with its unit: `READ_DELAY`,
  `SERVICES_MAX`, `VENDOR_LIMITS`, `LEVEL_WINDOW`, `REBUILD_GAP`,
  `FLOOR_BAR_*`, `STANDING`, `GOAL`, `ROUTE`.
- Comments explain the game fact behind odd code: secret quest objective
  text, `UnitReaction`'s 1–8, reputation discounts, data providers tainting
  the map, `SetMapID` taint, the 200-locals limit for `Drops.TRAINER_*` as
  fields.

This range removes duplication. These are now one helper each:
- `IsTaughtByTrainer` became `Names.IsLearnedFromTrainer`;
- Wishlist's `CreateSortMark` became `Theme:SortMark`;
- `RoundedBarTexture` moved to `Theme`;
- the library status words moved to `LibraryBooks.STATUS_TEXT`;
- `PackFields` serves kills and vendor messages;
- `Trainers.AddAnswers` serves A1 and P1.

New functions stay under a screen. The only one over 60 lines that grew is
`CreateInstanceList` (309 to 318 lines, already the longest). No new
`cond and nil or x`. Patterns built from data are fixed strings, and the
`gsub` replacements are functions, so `%` in a name is safe.

`table.concat(names, ", ")` in new shown text (`WorldMapMarkers.lua:369`,
`Overview.lua:491`) follows the addon's existing practice for lists; the
dot separator goes through `Theme.DOTS` / `Theme:JoinDots` everywhere.

Findings: R2, R3, R7.

### WoW API

Every game call, event, widget method, template, atlas, `Enum` and global
string the range adds or newly calls, checked in Ketho's
BlizzardInterfaceResources `forever` branch (downloaded 2026-11-16):

| Name | Kind | In `forever` lists | Where looked |
| --- | --- | --- | --- |
| `C_MerchantFrame.GetItemInfo` | function | yes | GlobalAPI.lua |
| `GetMerchantFilter`, `SetMerchantFilter`, `GetMerchantItemID`, `GetMerchantNumItems` | functions | yes | GlobalAPI.lua |
| `LE_LOOT_FILTER_ALL` | constant | yes (nil-guarded anyway) | LuaEnum.lua |
| `C_Item.DoesItemExistByID`, `C_Item.GetItemIconByID`, `C_Item.RequestLoadItemDataByID`, `C_Item.GetItemNameByID`, `C_Item.GetItemInfoInstant`, `C_Item.GetItemQualityByID` | functions | yes | GlobalAPI.lua |
| `C_Map.GetMapGroupID`, `C_Map.GetMapGroupMembersInfo`, `C_Map.GetMapInfo`, `C_Map.OpenWorldMap` | functions | yes | GlobalAPI.lua |
| `C_QuestLog.GetQuestObjectives`, `C_QuestLog.IsOnQuest`, `C_QuestLog.IsQuestFlaggedCompleted` | functions | yes | GlobalAPI.lua |
| `UnitReaction`, `UnitRace`, `UnitName`, `UnitGUID`, `GetLocale`, `GetBuildInfo` | functions | yes | GlobalAPI.lua |
| `GetTrainerServiceSkillReq` (now outside `@debug@`), `IsTradeskillTrainer`, `C_Trainer.GetTrainerType` | functions | yes | GlobalAPI.lua |
| `GetNumGuildMembers`, `GetGuildRosterInfo`, `C_GuildInfo.GuildRoster`, `C_CreatureInfo.GetRaceInfo` (dev files only) | functions | yes | GlobalAPI.lua |
| `tContains`, `BreakUpLargeNumbers`, `GameTooltip_Hide`, `PixelUtil.SetSize` | FrameXML helpers | yes | GlobalAPI.lua / FrameXML.lua |
| `MERCHANT_SHOW`, `MERCHANT_UPDATE`, `MERCHANT_CLOSED`, `TRAINER_SHOW`, `TRAINER_CLOSED`, `QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `QUEST_REMOVED`, `QUEST_TURNED_IN`, `PLAYER_LEVEL_UP`, `BAG_UPDATE_DELAYED`, `ZONE_CHANGED_NEW_AREA`, `BANKFRAME_OPENED`, `BANKFRAME_CLOSED`, `PLAYERBANKSLOTS_CHANGED`, `ADDON_LOADED`, `GUILD_ROSTER_UPDATE` | events | yes | Events.lua |
| `SetTextureSliceMargins`, `SetTextureSliceMode`, `SetClipsChildren`, `SetDesaturated`, `SetHighlightTexture`, `SetRotation`, `HookScript`, `RegisterForClicks`, `GetStringWidth` | widget methods | yes | WidgetAPI.lua |
| `Enum.ItemClass.Recipe`, `Enum.ItemRecipeSubclass.Leatherworking` / `.Fishing`, `Enum.ItemQuality.Poor`, `Enum.UIMapType.Dungeon`, `Enum.TrainerType.Pet`, `Enum.UITextureSliceMode.Stretched` | Enums | yes | LuaEnum.lua |
| `QuestNormal`, `Quest-Campaign-Available`, `Campaign-QuestLog-LoreBook`, `lootroll-toast-icon-need-up`, `PortalPurple`, `checkbox-minimal`, `common-icon-checkmark`, `Mode-Selection-Ring-c60` | atlases | yes | AtlasInfo.lua |
| `FACTION_STANDING_LABEL1`–`8`, `SPELL_STAT1_NAME`–`SPELL_STAT5_NAME`, `STAT_SPELLHEALING`, `STAT_SPELLDAMAGE`, `STAT_ATTACK_POWER`, `STAT_MOVEMENT_SPEED`, `MANA_REGEN`, `ITEM_MOD_HEALTH_REGENERATION_SHORT` | global strings | yes | GlobalStrings/enUS.lua |
| `FACTION_BAR_COLORS` | global table | inferred: in no list; `ns.UI.StandingColor` nil-guards it | none |
| `Interface\Minimap\UI-Minimap-ZoomButton-Highlight` | texture path | inferred: standard minimap art, by path, not a file ID | none |
| `MerchantFrame`, `WorldMapFrame`, `WorldMapFrame.ScrollContainer`, `GameTooltip` | FrameXML frames | inferred: standard; `WorldMapFrame` is nil-guarded and hooked after `Blizzard_WorldMap` loads | none |

Also checked:
- **Removed globals.** None used. The one `GetItemInfo` call is
  `C_TransmogCollection.GetItemInfo`, the rest are `C_Item.*`.
- **Async data.** `LootGrid`'s `TooltipPrice` asks
  `C_Item.RequestLoadItemDataByID` once and shows the name on the next
  hover. The merchant read tries again on `MERCHANT_UPDATE`, at most
  `READS_PER_VISIT`. The trainer read tries again after `READ_DELAY`, at
  most `READ_TRIES`. Nothing polls in a tight loop.
- **OnUpdate scripts.** The two new ones (`WorldMapMarkers`'s layer and the
  floor bar) run only while the game's map shows (children of its
  `ScrollContainer`). Each compares the map ID and size and returns at once
  when nothing changed. The file headers give the reason: reading the map
  without a data provider, which would taint it.
- **Secret values.**
  - `UnitName("npc")`, `UnitReaction`, `UnitRace`, `UnitGUID`, the
    merchant fields and quest objective text all go through `ns.Plain`.
  - Objectives that come back secret are left out (`ObjectivesText`).
  - The smoke secret-values run passes.
- **Taint and combat.**
  - Markers, the mode button and the floor chips use `PassRightClicks`,
    which waits for PLAYER_REGEN_ENABLED.
  - Floor chips refuse in combat with a tooltip and a chat line
    (`ShowFloor`, `ns.UI.SayNoFloorChangeInCombat`) and turn the map only
    through `C_Map.OpenWorldMap`, never `SetMapID`.
  - `SetMerchantFilter` isn't restricted (inferred: no restriction in the
    API docs; the filter is put back inside a `pcall` path).
  - `CHECKED_COMBAT_CALLS` is unchanged, and the combat run passes.
- **Every client's language.**
  - Standing words, buff names and floor names come from the game's
    globals or its map data.
  - The trainer list key comes from spell IDs, never the skill name.
  - Vendor and spell names are kept only on English clients, for the
    scraper (`GetLocale():match("^en")`), and never matched against game
    text.
  - The only texture in a line of text is an item's own icon from
    `C_Item.GetItemIconByID`.
  - `tests/smoke/locales/*.lua` gained the 11 new global strings for every
    client.
- **Smoke stand-in.** `tests/smoke/wow.lua` mirrors every new call: the
  merchant, `C_MerchantFrame`, map groups and types, `UnitReaction`, the
  guild roster, `GetQuestObjectives`, `GetItemIconByID`. It defines no
  global Forever lacks, and it now fails any scenario that sends on a
  custom channel (`W.NoteChannelSend`).
- **Style guide.** `docs/STYLE-GUIDE.md` covers the markers and mode
  button, floor chips, Factions standing rows, Buff box, goal colours,
  dashed outlines and Next step box.

No WoW API finding.

### Redundant code

Compared against:
- `Theme:Pill`, `Theme:Rounded`, `Theme:Menu`, `Theme:Text`,
  `Theme:FitAtlas`, `Theme:JoinDots`, `Theme:Plural`;
- `ns.RecipeBand.Chip` / `PlaceLines` (reused for floor chips);
- `ns.UI.PassRightClicks`, `ns.UI.MapLinksInCombat`, `ns.UI:WithGameMap`;
- `ns.HeardNumber`, `ns.CutToBytes`, `ns.Plain`, `ns.ParseGUID` (now
  wrapped once as `ns.NpcIDOf`);
- `ns.Items:Quality`, `ns.SectionMemory.Area`, `Drops.Where`.

The new code uses them rather than copying, and removes four old copies
(see Readability).

Left over: the key-counting and report-grouping copies (R4). No dead code
found: the realm-channel check, listen mode, ping and probe commands are
removed whole, with their `wow.lua` stand-ins and scenarios.
`ns.Data:KnownVendorRecipeIDs` and `NoteMissing` are inside `--@debug@`.

### Security

Untrusted inputs this range touches:
- **New heard kinds.** V1/S1 vendor, P1 trainer services and A1 trainer
  ranks, from the guild, group, Battle.net friends and (dev) whispers.
  - Every field is decoded with anchored patterns and `ns.HeardNumber`
    bounds: build ≤ client build, price ≤ 10,000 g, cost ≤ 1,000 g,
    coordinates ≤ 1000, standing ≤ 8, race ≤ 100, skill ≤ 1000.
  - Names are capped and refused with `%c` or `|`.
  - A vendor item must really be a recipe (V1) or an existing non-junk
    item (S1) on this client.
  - Heard reports are never shown and never sent again.
  - Trainer heard tables are capped at 600. The vendor caps are far larger
    (R1).
- **Whispers.** Only a PROBERS character's probe is answered, and a copy
  answers at most once every 15 minutes, with at most 400 messages, 30 s
  apart, through the outbox and its `DAILY_MAX` of 1500. Pushes are outbox
  entries too, and only go to a character in PROBERS that asked within
  three days. The first bounce ends them (R6 for the clock).
- **Relayed finds.** Heard kills relayed in an answer drop the finder's name
  and the `c` flag (`isRelayed`). Quests and trainer reports never carry a
  name. Finds a dev build took by whisper are kept out of answers
  (`viaWhisper`). A heard kill's boss and instance names are passed on as
  they were heard; they were never sanitized on the way in, but the only
  new reader is Mike's dev build.
- **Sending.**
  - "Share drops" off stops everything new: vendor, trainer, push and
    answer queuing all go through `Queue` / `QueueLaneMessage`, which
    check `ChannelOn`.
  - Nothing is sent on a custom channel; `wow.lua` now fails any scenario
    that does.
  - Lanes keep vendor and trainer messages at ten a day each, behind drops
    and quests.
- **Names.**
  - `NeedRollDB.dropPush.to` keeps a PROBERS character's name in players'
    saved files for up to three days (Mike's decision, 2026-11-12,
    documented in the code); it is dropped at logout once the push ends.
  - `dropPull.answered` / `heard` / `selfNames` keep other players' names,
    in a dev-only file that `.pkgmeta` ignores, in Mike's SavedVariables
    only.
  - The scraper's `vendors_seen.json` and `trainer_services.json` keep no
    player names (only NPC and spell names).
  - No credited name reaches a shipped or public file (Checks).
- **Scraper and workflows.**
  - No Wowhead request: the fetch path is cache-only and raises `Retired`.
  - QuestieDB and the Attune facts are read at build time; no file of
    either is committed.
  - New SavedVariables tables are validated in Python (`_whole`,
    `_clean_name`, `_entry`).
  - No `shell=True`, `eval` or `pickle`.
  - The two workflow edits add `python -m needroll_scraper` steps with no
    `${{ github.event.* }}` text and keep their `permissions:`.
  - The ingest report puts heard, made-up text into the Watcher pull
    request (R1).
- **Consent.** The round of asking stays at 2 (R5).

## Fixes

On `claude/project-thread-ociyz4`, after `origin/dev` `9715226b` (#929–#933 merged since round 1):

- **R1** (`414d43bc`, `08496276`): `Core/Vendors.lua` keeps heard reads to their own caps,
  `HEARD_VENDORS_MAX = 100` heard vendors of each kind and `HEARD_ITEMS_MAX = 40` items per heard
  vendor; the player's own reads keep 500 / 200 and don't count towards them (new smoke scenario
  "heard reads keep to their own small caps"). The ingest report lists heard reads only of the
  vendors that ingest added or changed (`knownvendors.changed_vendors`, `lists_heard`; the
  `knownvendors` command alone still lists every one), the Vendors section stops at 30,000
  characters in Python (`knownvendors.REPORT_MAX`, whole lines and a "N more lines left out" line,
  so `watcher-data.yml` is unchanged), and `vendor_text` puts the vendor name in a code span, a
  backtick in it turned into `'`. Scraper tests added.
- **R2** (`a696d774`): the Push section and `Push.Queue` now name V1 and S1 and say a lane
  message's push isn't in its lane. Behaviour unchanged.
- **R3** (`a696d774`): the vendor lane is queued for `GROUP_OR_GUILD`; the outbox comment says
  CHANNEL is only in outboxes saved before NRDropTalk and goes as GROUP_OR_GUILD; the two
  `Core-Vendors.lua` asserts updated.
- **R4** (`e017f060`, `414d43bc`): one `ns.CountKeys` in `Core/Init.lua` replaces the copies in
  Vendors, Trainers (`Trainers.CountKeys` gone), DropPull and DropTalk. `Trainers.GroupReports`
  (with `ReportGroup`) groups A1 ranks and P1 services; `RankGroups` and `ServiceGroups` only
  name their fields and rows. Message formats unchanged.
- **R5** (`bb8d620c`): `DROP_NOTICE_ROUND` stays 2; the comment by it records Mike's decision of
  2026-11-16 (reworded notice and Settings tip, a line about referrals, no new round).
- **R6** (`a696d774`): `Push.Target` ends a push whose probe time is ahead of the clock; smoke
  check added to the push scenario.
- **R7** (`bb8d620c`, `a696d774`): `RecipeMatches` comment and `UI:OpenZoneMap` comment rewrapped;
  the fold widgets' `parent` is `holder`; `QuestsToTake`'s inner loop is `AddInstanceQuests`;
  the unused `L` in `UI-WorldMapOverlay.lua` is gone; `Push.Queue` passes `nil` for no lane.

Also on the branch, not from this review: `d5f7b0db` and `e6641a00` make two smoke scenarios
pass with v1.8.0's drafted translations. MapEdit's scenario left English phrases in `ns.L`
after its language preview, so on other clients every later scenario looked up English; its
cleanup now restores them, and the 19 scenarios that ran translated for the first time compare
with `ns.L`, `ns.Money` and phrase words instead of English text.

## Round 2

Round 2 reviews two things on `claude/project-thread-ociyz4` at `ef8b95db`: the fixes for
R1–R7 and the two locale test fixes (`9715226b..ef8b95db`, 8 commits), and the five PRs merged
into `dev` after round 1 (`b87f8b2e..9715226b`). Every changed function was read in full, not
only the lines fixed.

**Verdict: Changes needed** (0 blocking, 3 should fix, 4 nits). R1–R4, R6 and R7 are fixed and
the fixes add nothing that breaks; R5 stays as Mike decided. The three should-fix findings are
all in the new "two players agree" and quest-draft paths of #929–#932, where reports anyone can
send reach shipped data or Mike's pull requests. This is the last round: Mike decides what is
left.

### What the five PRs do

- **#929, apply heard trainer ranks once two players agree (`c5563e95`).** A copy hearing an
  A1/T1 rank or a P1 service now saves, per heard report, each sender's key
  (`Drops.SenderKey`, the first 8 hex digits of the FNV-1a prober key of the name without its
  realm) with what that sender reported, at most `Drops.SENDERS_MAX` = 8. `ingest` folds the
  keys into `scraper/classes/seen.json` and `scraper/professions/trainer_services.json`;
  `trainers` applies a heard change to a listed class rank to `Data/ClassSpells.lua` once two
  keys on the current build agree and none disagrees. Services stay report-only.
- **#930, apply quest differences confirmed in game (`c43fe5ee`).** Heard Q1 quests keep sender
  keys too (one shared `Drops.NoteSender`). `ingest` compares each reported quest with its page
  and writes a level or reward difference that Mike's quest log or two agreeing keys confirm
  into `forever.json`'s `confirmedInGame`, which the quest builds put on the pages.
- **#931, library book quests and loot scan leads (`23b4898d`).** `ingest` adds hand-in quests
  Mike's characters learned to the hand-kept `Data/LibraryBooks.lua` (numbers only, one book's
  line at a time), and lists a dev build's `/nr loot scan` leads in the report (capped at 200).
- **#932, Q1 tag field and quest drafts (`9a22f0dc`).** A Q1 gains a trailing `tag` field
  (`C_QuestLog.GetQuestTagInfo`'s `tagID`, or `Enum.QuestTag.Group` for an elite quest with no
  number); v1.7.0 copies stop reading at `xp`, so no new format number. `ingest` drafts reported
  quests NeedRoll doesn't know that are tagged Dungeon or Raid (or Group inside an instance)
  into `forever.json`'s `draftedInGame` and lists them in the report.
- **#933, referrals (`63ce800a`).** With Share drops on, a copy keeps the names of up to 50
  players it heard send finds in its guild or group for 7 days (`NeedRollDB.dropSharers`),
  and after answering a PROBERS character's probe whispers it one `N1:` message with up to 20 of
  them. Mike's dev pull adds them to its players heard sharing and asks them. `N` joins
  `FORMATS` as a new letter (no number bumped). The consent notice and the Share drops tip gain
  a sentence saying so.

### Scope (round 2)

- Fixes: every hunk of `9715226b..ef8b95db` except the Review Doc: `Core/Init.lua`
  (`ns.CountKeys`), `Core/Vendors.lua` (heard caps), `Core/Trainers.lua` (`ReportGroup`,
  `Trainers.GroupReports`, `RankGroups`), `Core/TrainerShare.lua` (`ServiceGroups`,
  `ServiceRank`), `Core/Drops.lua` (outbox, Push and lanes comments, `Push.Target`,
  `Push.Queue`), `Core/DropPull.lua`, `UI/DropTalk.lua`, `UI/Lists.lua`, `UI/MainFrame.lua`,
  `UI/Overview.lua`, `UI/Welcome.lua`, `UI/WorldMapMarkers.lua`; scraper `knownvendors.py`,
  `vendoritems.py`, `__main__.py` and their tests; smoke modules `Core-Drops`, `Core-Vendors`,
  `UI-MapEdit` and the 19 scenarios in `UI-DungeonQuestlines`, `UI-MinimapButton`,
  `UI-Overview`, `UI-ProfessionOverview`, `UI-RecipeBand`, `UI-Shopping`, `UI-Wishlist`,
  `UI-WorldMapOverlay`.
- PRs #929–#933: the whole diff of `Core/Drops.lua` (`Drops.SenderKey`, `Drops.NoteSender`,
  `TakeQuestReport`, `TakeTrainerRanks`/`Services`, `QuestTagInfo`/`QuestTagID`, `SaveQuest`,
  `EncodeQuest`, `DecodeQuest`, Referrals: `Probe.NoteSharer`, `ForgetOldSharers`,
  `ReferralText`, `QueueReferral`, `Answer`, `Whispers.Read`, `CHAT_MSG_ADDON`,
  `Drops.DecodeReferral`), `Core/Trainers.lua` and `Core/TrainerShare.lua` (senders),
  `Core/DropPull.lua` (`NoteReferred`, `OnReferral`), `UI/DropTalk.lua`, `UI/Settings.lua`,
  `UI/Welcome.lua`, `Locales/enUS.lua` (one line); scraper `senders.py`, `classspells.py`,
  `trainerservices.py`, `questdifferences.py`, `questdrafts.py`, `librarybooks.py`,
  `lootleads.py`, `knownquests.py`, `questie_quests.py`, `quests.py`, `questxp.py`,
  `classquests.py`, `__main__.py`; `.github/workflows/watcher-data.yml` (comments only);
  `tests/smoke/wow.lua`, `scenarios.lua` and the smoke modules for Drops, DropPull, Trainers and
  TrainerShare; the scraper tests skimmed.
- Skipped: generated data under `NeedRoll/Data/` and the scraper's JSON data, as asked. The
  commits touching them also touched their generator, or are the hand-kept
  `Data/LibraryBooks.lua` that #931's `ingest` now edits on purpose (numbers in one book's
  line).

### Checks (round 2)

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 30 hand-written Lua files changed in `b87f8b2e..ef8b95db` | passed |
| `luacheck --no-global -q`, now vs `b87f8b2e` and vs `9715226b`, warnings compared without line numbers | Gone: the three shadowed `parent`, the long `Lists.lua` comment and the unused `L` (R7). New vs `b87f8b2e`: `Settings.lua` two long lines and `Welcome.lua` one, all `L["..."]` phrases kept on one line (accepted as in round 1). The three `UI-Overview.lua` "overwritten before use" warnings only moved line numbers. Nothing new vs `9715226b` |
| `tests/smoke/check.sh` (dev, packaged, secret values, in combat) | passed: exit 0, "all passed" in all four (230 / 221 / 230 / 230 files; 769 / 671 / 769 / 769 scenarios ok) |
| `tests/smoke/check.sh --locale all` | passed: exit 0, "all passed" for all 11 clients; enUS 773 ok, each of the other ten 647 ok with the same 126 skipped |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | passed (exit 0); the same five "not used by NeedRoll any more" notes per language as round 1. The new referral sentence and round 1's reworded consent texts have no translation yet (R12) |
| `python3 tools/locale_strings.py --check` | passed (exit 0) |
| `python3 tools/font_coverage.py --check` | passed (exit 0) |
| `cd scraper && python3 -m unittest discover -s tests` | passed (517 tests) |
| Lua 5.1 limits (extra; `luac5.1 -l -l`, main chunk locals, most upvalues in one function, `b87f8b2e` vs now) | `Drops.lua` 197 / 197, 16 upvalues (unchanged: the new values hang off `Drops` and `Probe`). `Overview.lua` 199 / 199, 34. `Trainers.lua` 44 / 45, `Vendors.lua` 36 / 38, `TrainerShare.lua` 42 / 44, `WorldMapMarkers.lua` 86 / 87. None near a limit but Drops and Overview, which didn't grow |
| New globals (extra; `luacheck --std lua51`, "setting global") | none new (only `NeedRollDB`, the slash and binding globals and the compartment functions, as before) |
| Player names (extra) | none: the 380 names in `scraper/drops/credits.json` (`grep -w -F -f`) appear in no file the range changed outside `scraper/drops/`, nor anywhere under `NeedRoll/`, `docs/`, `.github/`, `README.md` or the changelogs. `.pkgmeta` still ignores `scraper`, `Core/DropPull.lua` and `UI/DropTalk.lua` |
| WoW API names (extra) | `C_QuestLog.GetQuestTagInfo` (GlobalAPI.lua), `Enum.QuestTag.Group` / `.Raid` / `.Dungeon` = 1 / 62 / 81 (LuaEnum.lua), `PLAYER_LOGOUT` (Events.lua): all in Ketho's `forever` lists, downloaded 2026-11-16 |
| Forged quest build (extra; `python3 -I` against `senders.py`) | `current_build` of one real entry (build 64000, two agreeing senders) gives 64000 and agreement `(30, 2)`; adding one entry with build 2147483647 gives that build and `(None, 0)` (R9) |

### Round 1 findings re-checked

- **R1, fixed.** `Core/Vendors.lua:55-60` adds `HEARD_VENDORS_MAX = 100` and
  `HEARD_ITEMS_MAX = 40`. `HeardVendor` refuses a new heard vendor past either cap
  (`:367-376`), and `AddHeardItems` adds to a heard vendor only below 40 items (`:388`). The
  player's own reads keep 500 / 200, and `DropOldestVendor` still drops a heard vendor first,
  so heard ones never push out own ones. The new smoke scenario fills 101 heard vendors and 60
  heard items and checks both caps and the own read. In the scraper, `changed_vendors` lists
  only vendors this ingest added or changed, `report_section` stops at `REPORT_MAX = 30000`
  characters on a whole line, and `vendor_text` puts the name in a code span with backticks
  turned into `'`. GitHub renders nothing inside a code span, so `@name` and links stay plain
  (tested in `test_report_keeps_a_made_up_vendor_name_plain_text`). The same problem in two
  other report sections is R10.
- **R2, fixed.** Both comments (`Drops.lua:901-909`, `:1300-1303`) now name V1 and S1 and say a
  lane message's push waits in front of the lanes and outside their daily count, which is
  what `Queue` does (`:1274`: an entry without a lane goes before lane entries).
- **R3, fixed.** `LANES.vendor.to = "GROUP_OR_GUILD"` (`:1044`); the outbox comment says CHANNEL
  is only in outboxes saved before NRDropTalk. `Destination` still maps old CHANNEL entries.
- **R4, fixed.** `ns.CountKeys` (`Init.lua:537-542`) replaces the copies in Vendors, Trainers,
  DropPull and DropTalk. `Trainers.GroupReports` with `ReportGroup` builds both A1 and P1
  groups. The messages are byte for byte the same: the encoders already wrote `or 0` for a
  missing standing or race, and the group keys are the same fields joined in the same order.
  The comments left behind are R14.
- **R5, left as is.** The comment by `DROP_NOTICE_ROUND` (`Welcome.lua:141-148`) records
  Mike's decision of 2026-11-16 to keep round 2, referrals included. Not checked further: it
  is Mike's call.
- **R6, fixed.** `Push.Target` (`Drops.lua:928-937`) returns nil for a negative age; the push
  scenario checks a probe time a day ahead.
- **R7, fixed.** Every item: the comments are rewrapped, `holder` replaces the shadowing
  `parent`, `AddInstanceQuests` takes the inner loop (the deepest nesting in `QuestsToTake` is
  now two), `Push.Queue` passes `nil`, and the unused `L` is gone. luacheck agrees.
- **The two locale test fixes.** MapEdit's cleanup puts the loaded language's phrases back
  through `ns.PreviewPhrases` when a scenario previewed another (a dev-only scenario;
  `PreviewPhrases` writes `phrases[key] or key` for every English key, the same values the
  load wrote). The 19 scenarios now compare with `ns.L[...]`, `ns.Money` and the words around
  `%s`; they pass on all 11 clients and still fail on a wrong text. Two of them check less than
  before, and MapEdit undoes only part of a preview (R14).

### R8 · Relayed probe answers make one made-up report count as "two players agree", which the scraper applies to class trainer ranks and quest pages
- **Severity:** should fix
- **Area:** Security (untrusted input reaching shipped data)
- **Where:**
  - Addon: `NeedRoll/Core/Drops.lua:2850` (`Whispers.Read` takes a pulled answer with the
    whisperer as `sender`), `:2197` and `:2258` (`decoded.senderKey = Drops.SenderKey(sender)`),
    `:2801-2818` (`TakeQuestReport` notes the whisperer as a quest's sender);
    `Core/Trainers.lua:478` and `Core/TrainerShare.lua:431` (answers include heard reports,
    `isHeard` true); `:2572-2590` (`AddQuestAnswers` relays heard quests).
  - Scraper: `scraper/needroll_scraper/senders.py:84-95` (`sender_agreement`),
    `classspells.py:935-950` (`_agreed_heard`, `_apply_agreed` into `Data/ClassSpells.lua`),
    `questdifferences.py:177-204` (`find_difference` writes `confirmedInGame`).
- **Status:** open

**What's wrong.** The rule #929 and #930 rest on is "one player's heard report may be made up,
two players saying the same rarely is" (`Drops.lua:2492-2495`). Agreement is counted by the
key of the player Mike's copy *heard the report from*. But a copy answering Mike's probe
relays the trainer ranks, services and quests it *heard* from its guild and group, with no
finder's name or mark (`Trainers.Answers` loops `isHeard` over `{ false, true }`;
`AddQuestAnswers` sends every answerable quest, `isHeard = saved.by ~= nil`, and the message
text is the same either way). Mike's pull takes each answer through `Whispers.Read`, so the
report is keyed to the copy that relayed it:

```lua
    local id, status = TAKE[kind](text, sender, true)   -- sender: the player who answered the probe
...
    decoded.viaWhisper, decoded.senderKey = isWhispered, Drops.SenderKey(sender)
```

The scraper's comment knows one direction of this ("one player relaying two finders counts
once") but not the other: two copies relaying one finder count twice. Nothing in the scraper
reads `viaWhisper` (`grep -rn viaWhisper scraper/` finds nothing).

**Why it matters.** One player in a guild sends one made-up A1 (say, a class rank's level and
price) or a Q1 for a listed quest with a different level or rewards. Two guildmates' copies
save it. Mike's pull asks both, since it asks players heard sharing, and since #933 the
referrals name exactly such players. Both relay the report, Mike's copy saves it with two
different sender keys, and the next Watcher run writes it into `Data/ClassSpells.lua` or
`forever.json`'s `confirmedInGame` with the line "heard alike from 2 players' copies on build
…, applied (2 senders agree)". The forger's own copy answering the pull is enough for the
second key, too. Once merged, every player sees the wrong level or price on the trainer page,
or the wrong reward on the quest page. The only safeguard left is Mike reading each applied
line, and that line tells him two players agreed.

**Evidence.** Read the lines above and `DropPull.lua`'s Answers and Referrals. Inference: the
pull asks the relaying copies (it asks players heard sharing and referred players, within
`ASK_GAP`); no smoke scenario or scraper test covers a relayed report.

**Fix.** Count only first-hand senders towards agreement until relays can be told apart:
- `Drops.NoteSender` gets `isWhispered` and saves it on the sender record
  (`{ build, ..., viaWhisper = true }`); `senders.parse_senders` keeps the flag;
  `sender_agreement` counts only records without it (whispered ones can still show in the
  report as "also heard in probe answers").
- Later, if Mike wants pulled answers to count: mark relayed reports in the answer (a trailing
  field older copies ignore, as the Q1 `tag` was added), and save no sender key for a relayed
  report on Mike's copy.

### R9 · A heard quest's build isn't capped, so one made-up build stops every two-player quest confirmation
- **Severity:** should fix
- **Area:** Security (untrusted input)
- **Where:** `NeedRoll/Core/Drops.lua:1748` (`build = HeardNumber(fields[12])` in
  `DecodeQuest`); `scraper/needroll_scraper/senders.py:75-81` (`current_build`);
  `questdifferences.py:210`
- **Status:** open

**What's wrong.** Trainer and vendor decoders refuse a build newer than the client's
(`HeardNumber(fields[3], clientBuild)`, `Drops.lua:2162`, `:2243`, `:2337`). `DecodeQuest`
doesn't, so a heard Q1 is saved with any build up to 2,147,483,647. `TakeQuestReport` knows
such a build is made up and keeps it out of the senders (`:2808-2812`), but `SaveQuest` still
saves it on the quest, `merge_reported` copies it into `reported.json`, and `current_build`
takes the newest build of every entry, unchecked:

```python
    builds = [entry.get("build", 0) for entry in entries]
    builds += [said["build"] for entry in entries for said in (entry.get("senders") or {}).values()]
    return max(builds, default=0)
```

Its docstring says "a copy refuses a heard build newer than its own", which is true for
trainer messages but not for Q1.

**Why it matters.** One Q1 with build 2147483647, for any quest ID NeedRoll doesn't know (those
are always saved), makes that the "current build" for every later ingest: `reported.json`
never drops an entry. `find_difference` then keeps only senders on that build, which is none,
so no quest difference is confirmed by players again, silently. The same Q1 is relayed in probe
answers (`AddQuestAnswers` copies `build`), so it reaches Mike's copy from any guild.

**Evidence.** The `python3 -I` run in Checks: one forged entry turns agreement `(30, 2)` into
`(None, 0)`. Read `DecodeQuest`, `TakeQuestReport`, `knownquests.merge_reported:235-281`.

**Fix.**
- Addon: `build = HeardNumber(fields[12], clientBuild)` in `DecodeQuest`, as the other kinds
  do (a newer build then reads as unknown).
- Scraper: `current_build` takes only builds that pass `whole(build, 0, BUILD_MAX)`, and for
  quests better only the senders' builds and Mike's quest log, which the addon has checked.
  Correct the docstring.

### R10 · Heard quest titles and trainer service names still reach the Watcher pull request as Markdown, and the drafts list has no cap
- **Severity:** should fix
- **Area:** Security (text from other players in a pull request)
- **Where:** `scraper/needroll_scraper/questdrafts.py:193-200` (`report_line`), `:203-215`
  (`report_section`, no cap); `trainerservices.py:202-205` (`_line`, `title =
  entry.get("name")`)
- **Status:** open

**What's wrong.** R1's fix put heard vendor names in a code span. Two other report sections
print text another player's copy sent, as it came:

```python
    name = entry.get("name") or (f"\"{entry['heardTitle']}\" as heard" if entry.get("heardTitle") else "no name")
```

`heardTitle` is a Q1's title field, which `DecodeQuest` takes as is (only tabs end it;
`NilIfEmpty`), and `knownquests.merge_reported` copies into `reported.json` unchanged.
`trainerservices._line` prints a heard P1 service's `name` (`_name` strips control characters
and `|`, nothing Markdown reads). The service section was in round 1's range (`fca82136`) and
round 1 missed it.

`questdrafts.report_section` lists every draft, with no cap like the other sections
(`lootleads` 200 lines, `questdifferences` 300, `trainerservices` 300, Vendors 30,000
characters). A draft needs only a Q1 for a quest ID NeedRoll doesn't know with tag 81, and
`reported.json` keeps every quest ever reported.

**Why it matters.** A made-up quest title such as `@someone` or `[Patch notes](https://…)`
shows in Mike's pull request as a mention (GitHub notifies that user) or a link. One player
sending Q1s for made-up quest IDs, tagged Dungeon, adds a draft line per ID to every later
Watcher pull request, and to `forever.json`'s `draftedInGame`, until each is blacklisted; past
65,536 characters the action cuts the body, losing the sections after it (inference, as in
R1).

**Evidence.** Read the lines above, `knownquests.py:235-281`, `Drops.lua:1740-1757`.
`test_questdrafts.py:72` shows a `heardTitle` reaching a draft.

**Fix.**
- One helper for report text from players, say `report_text(name)` in one module (backticks
  to `'`, wrapped in a code span), used by `vendor_text`, `questdrafts.report_line` and
  `trainerservices._line`.
- Cap the drafts section as `lootleads` does (`REPORT_MAX` lines and "... and N more").
- Worth considering: draft only quests Mike's characters took (`by` nil) or that two
  first-hand senders reported, so one player can't fill `draftedInGame`.

### R11 · Referrals and sender keys identify players who chose "Credit my finds" Off; every copy keeps keys only Mike's dev builds use; "one-way" overstates a 32-bit hash of a name
- **Severity:** nit
- **Area:** Security (privacy)
- **Where:** `NeedRoll/Core/Drops.lua:467-472` (Credit: "finds are stored anonymously unless
  credit was asked for"), `:2478-2490` (`Drops.SenderKey`, "one-way"), `:2615-2690`
  (Referrals); `scraper/needroll_scraper/senders.py:1-13`, `classspells.py:99,259`,
  `trainerservices.py:18,55` (the same words in docs and in the `SOURCE` text of committed JSON)
- **Status:** open: Mike's decision

**What's wrong.**
- *Referrals.* `Probe.NoteSharer` saves the name of every player heard sending a find in the
  guild or group, credit flag or not, and the N1 whispers up to 20 of them to Mike's
  character, whose pull saves and whispers them. A player who chose Credit Off ("Off stores
  your finds anonymously") is named to Mike as someone who shares finds. The new consent line
  tells the *listener* their copy names others; it doesn't tell the *sharer* their name goes
  to Mike.
- *Sender keys.* `Drops.SenderKey` is the first 32 bits of an FNV-1a hash of the lowercased
  name. Character names are short, so anyone with a list of candidate names (a guild roster,
  `/who`) gets each key's name back by hashing them. The comments and the JSON `SOURCE` texts
  call it "one-way … never the name". The keys are the same for one player in every report, so
  they link that player's quests and trainer reports together.
- *Kept everywhere.* Every release copy saves keys on heard ranks, services and quests, but only
  Mike's SavedVariables are ingested (his watcher accounts run dev builds: `ingest` reads
  `questLog`, a dev-only table, by inference), and answers never carry keys. On every other
  player's computer the keys are never used.

**Why it matters.** Nothing here is public: `.pkgmeta` ignores `scraper/`, and the repo is
private. But the Credit section's promise is anonymity, the keys are pseudonyms, and the JSON
files that hold them (`seen.json`, `trainer_services.json`, `reported.json`) would leak them
from any public copy that CLAUDE.md's name check treats as name-free.

**Evidence.** Read the lines above and `Drops:ProberKey` (`:2467-2470`). The reversal by
guessing is inference from the hash size and input.

**Fix.** Mike's call. Options:
- skip a sharer in `Probe.NoteSharer` whose D2 came without the credit flag, or say in the
  Credit my finds tip that guildmates' copies may name a sharer to Mike;
- save sender keys only in dev builds (a `Drops.keepsSenderKeys` set in a `--@debug@` block),
  since only those are ingested;
- call the key "a short hash of the name, which can be matched by guessing names", and add the
  three JSON files to CLAUDE.md's list of what a public copy must not carry.

### R12 · The consent notice and Share drops tip are in English on the other ten clients until the Translations PR lands
- **Severity:** nit
- **Area:** Security (consent) / every client's language
- **Where:** `NeedRoll/UI/Welcome.lua:206-208`; `UI/Settings.lua:129-130`; `Locales/*.lua`
- **Status:** open

**What's wrong.** The referral sentence (#933) and round 1's reworded notice, tip and "Turning
it on…" texts have no entry in any of the ten translated locale files (`grep -c` finds 0 in
each), so the notice that asks for consent is now mixed or wholly English on deDE, esES, esMX,
frFR, itIT, koKR, ptBR, ruRU, zhCN and zhTW. The two sentences are joined with `" "`, which
reads oddly in Chinese, where sentences aren't parted by spaces.

**Why it matters.** The player is asked to say yes to sharing in a language they may not read.
Round 1's texts were already untranslated; #933 adds the sentence about naming players to Mike.

**Evidence.** `python3 tools/translations.py` and `grep -c` on `Locales/*.lua`.

**Fix.** Land the Translations PR for these phrases before tagging v1.8.0. Optionally make the
referral sentence part of the tip and notice phrases, so translators can place it.

### R13 · Three copies of the SavedVariables whole-number helper, and the shared one lives in senders.py
- **Severity:** nit
- **Area:** Redundant code
- **Where:** `scraper/needroll_scraper/senders.py:26-31` (`whole`), `trainerchecks.py:58`
  (`_whole`, also borrowed by `trainerservices.py` as `_whole = trainerchecks._whole`),
  `knownvendors.py:183` (`_whole`)
- **Status:** open

**What's wrong.** #930 moved `classspells._whole` to `senders.whole`, and #931 and #932 import
it from there into `librarybooks.py`, `lootleads.py` and `questdrafts.py`, which have nothing to
do with senders. Two older copies with other defaults stay.

**Why it matters.** A reader looking for "how a SavedVariables number is checked" finds three,
with different default upper bounds (`None`, `ID_MAX`, `math.inf`); a fix to one misses the
others.

**Fix.** One `whole` in a small module for SavedVariables values (or `savedvars.py`, which
already reads them), imported everywhere; drop the two `_whole` copies.

### R14 · Small slips from the fixes: stale "nil when not known" encoder comments, MapEdit's half undo of a preview, a weakened chance check, hand-counted keys in a test
- **Severity:** nit
- **Area:** Readability
- **Where / what / fix:**
  - `NeedRoll/Core/Drops.lua:2098-2100` and `:2225-2227`: `EncodeTrainerRanks` says a group's
    "build, npc, standing, race (each nil when not known)", `EncodeTrainerServices` "standing
    (nil when not known)". Since R4's `ReportGroup` (`Trainers.lua:388-395`) they are 0, and
    the encoders' `or 0` never fires. Say "0 when not known" (and drop the `or 0`, or keep it
    for other callers and say so).
  - `NeedRoll/Core/Trainers.lua:388-395`: `ReportGroup` builds a new group table for every
    report, then throws it away when the key exists. Return the key alone, and build the group
    only for a new key.
  - `tests/smoke/modules/UI-MapEdit.lua:43-45`: the cleanup calls `ns.PreviewPhrases`, but a
    preview also forgets the Search and Tooltip caches, redraws the window and sets the
    palette's label (`MapEdit:Preview`, `UI/MapEdit.lua:1398-1410`). Undo it the same way:
    `MapEdit:Preview(saved.language or ns.loadedLanguage)` before the fields are put back, so
    nothing built in English during the preview outlives the scenario.
  - `tests/smoke/modules/UI-Overview.lua:767`: `target:find("1%", 1, true)` passes on "11%" or
    "10%" as well. Build the expected chance text the way the line does and look for it.
  - `tests/smoke/modules/Core-Vendors.lua:246-264`: the new scenario counts keys by hand;
    `ns.CountKeys(ns.db.vendorItems[FIRST_HEARD].items)` says it in one call.
  - Not from this release, for whoever touches them next: inline key counts remain at
    `Drops.lua:397`, `:1086`, `HunterPets.lua:152` and the dev-only `Drops.lua:3278`, `:3408`,
    `TrainerCheck.lua:104`.
- **Status:** open

**Why it matters.** None changes behaviour; each is a comment that misleads or a test that
checks less than its message says.

### Area notes (round 2)

#### Readability

- The fixes read well: `ns.CountKeys`, `Trainers.GroupReports` with the field lists
  (`RANK_GROUP_FIELDS`, `SERVICE_GROUP_FIELDS`) as named constants, `HEARD_VENDORS_MAX` /
  `HEARD_ITEMS_MAX` with the reason in a comment, `AddInstanceQuests`. R14 lists what they left.
- #929–#933 keep the file's density of why-comments: Referrals, Senders, the Q1 `tag` field
  (why a trailing field and not Q2), `QuestTagID` (why the number and not the name), and the
  200-locals reason for `Drops.QuestTagInfo`, `Drops.SENDERS_MAX` and the `Probe` fields.
  Names are in game terms (`NoteSharer`, `ReferralText`, `HeardAboveZero`, `NoteReferred`).
- No `cond and nil or x`; patterns built from data use the constant `"N1"` only.
- Two comments say more than the code does: "one-way" (R11) and `current_build`'s "a copy
  refuses a heard build newer than its own" (R9).

#### WoW API

| Name | Kind | In `forever` lists | Where looked |
| --- | --- | --- | --- |
| `C_QuestLog.GetQuestTagInfo` (now also for the Q1 tag; `pcall`-guarded, fields through `ns.Plain`) | function | yes | GlobalAPI.lua |
| `Enum.QuestTag.Group`, `.Raid`, `.Dungeon` (1, 62, 81) | Enum | yes | LuaEnum.lua |
| `PLAYER_LOGOUT` (a third handler in Drops.lua, for `dropSharers`) | event | yes | Events.lua |

- `tests/smoke/wow.lua` mirrors `GetQuestTagInfo` (from `W.quest.tagInfo`) and fills
  `Enum.QuestTag` with the same four numbers as Forever's list.
- Secret values: `sender` and `text` go through `ns.Plain` before `NoteSharer`; `tagInfo.tagID`
  and `isElite` through `Plain`.
- Combat: nothing new touches frames or protected calls; `CHECKED_COMBAT_CALLS` is unchanged
  and the combat run passes.
- Every client's language: the quest tag is sent as the game's number, never its name; sender
  keys come from the name as the game gives it, the same on every client. The consent texts'
  translations are R12.
- Async: none new.

#### Redundant code

Compared against `ns.CountKeys` (now used by Vendors, Trainers, TrainerShare, DropPull and
DropTalk), `Trainers.GroupReports`, `DropOldest` (reused by `ForgetOldSharers`),
`Drops.WithoutRealm`, `Drops:ProberKey` (reused by `SenderKey`), `Queue` (reused by
`QueueReferral`), and in the scraper `knownvendors.item_text` (reused by `lootleads`),
`questdifferences.write_section` (reused by `questdrafts`), `senders.merge_senders` /
`sender_agreement` (one copy for trainers, services and quests). `Trainers.NoteSender` became
a thin wrapper over the one `Drops.NoteSender`. Leftovers: R13, and the test count in R14.

#### Security

Untrusted inputs and outputs round 2 touches:
- **Heard A1, P1 and Q1** now carry weight: two keys agreeing change shipped data (R8), and a
  Q1's build steers the scraper (R9). Fields are otherwise bounded as in round 1, and
  `NoteSender` keeps at most 8 senders per report, current build only.
- **N1 referrals.** Sent only by whisper to a PROBERS character, one per answered probe, after
  the answer, through the outbox (its pace, the 30 s whisper gap, `DAILY_MAX`); never to the
  guild, group or friends. A copy keeps at most 50 names for 7 days, only while Share drops is
  on, and forgets them when it is switched off and at logout when off. Never the player, a
  PROBERS character, a Battle.net friend or a whisperer. The dev pull's `DecodeReferral`
  (inside `--@debug@`) takes at most 20 names of at most 64 bytes, no control characters or
  `|`, each once; its log keeps counts, not names. v1.7.0 copies ignore the unknown letter `N`.
  Privacy: R11.
- **Pull request text.** Vendor names are now in code spans (R1); quest-draft titles and
  service names are not (R10). Library book and loot lead lines carry only numbers and the
  data's own names.
- **Scraper and workflows.** No Wowhead request, no `shell=True`, `eval` or `pickle`; paths are
  fixed under the repo. `watcher-data.yml` changed only in comments. `Data/LibraryBooks.lua` is
  edited by line with numbers only.
- **Names.** None reaches a shipped or public file (Checks). Referred names live in players'
  saved files (7 days) and Mike's dev SavedVariables, which stay in this private repo.
- **Consent.** Round 2 stays, by Mike's decision (R5); the new sentence is untranslated (R12).

## Round 2 fixes

On `claude/project-thread-ociyz4`, after `0ebc68ac`:

- **R8** (`0575ec21`): `Drops.NoteSender` saves `viaWhisper = true` on a sender's record when a
  dev build's pull took the report by whisper (`TakeQuestReport`, `Trainers.SaveHeard`,
  `TrainerShare.SaveHeard` pass it), and a whispered report doesn't replace what that player sent
  themselves on the same build. In the scraper, `parse_senders` keeps the flag, `merge_senders`
  keeps a first-hand record over a whispered one on the same build, and `sender_agreement` counts
  only first-hand senders, so class ranks, services and quest differences need two players heard
  first-hand. No message format changed and no FORMATS number moved; answers carry no "relayed"
  mark yet (left for later, as the finding suggests, if Mike wants pulled answers to count).
  Smoke checks in the Drops and Trainers sender scenarios, scraper tests in `test_classspells.py`
  and `test_questdifferences.py`.
- **R9** (`0575ec21`): `DecodeQuest` reads the build as `HeardNumber(fields[12], clientBuild)`, so
  a newer one reads as unknown; `TakeQuestReport` relies on that. `current_build` takes only
  builds up to `BUILD_MAX`, its docstring corrected, and `find_differences` takes the build from
  the senders and Mike's quest log only (a quest's own build in `reported.json` may be a made-up
  one saved before this fix). Smoke check and scraper tests added; the `python3 -I` case from
  round 2's Checks now gives the real build.
- **R10** (`2a4ac8f7`): one `savedvars.report_text` (code span, backtick to `'`, control
  characters to spaces) for vendor names, heard quest titles in the drafts section and trainer
  service names. The drafts section lists at most `questdrafts.REPORT_MAX = 200` drafts, then
  "... and N more". Drafting only first-hand or Mike's quests ("worth considering") is not done.
- **R11** (`0575ec21`): only the wording, as asked: comments, `scraper/README.md` and the JSON
  `SOURCE` texts call the key a short hash of the name that guessing names could match back, not
  "one-way". The behaviour options are Mike's call; nothing else changed.
- **R12**: not fixed here; it needs the Translations PR before v1.8.0 is tagged.
- **R13** (`2a4ac8f7`): one `whole` in `savedvars.py`, imported everywhere; the copies in
  `senders.py`, `trainerchecks.py` and `knownvendors.py` are gone (each caller passes the upper
  bound its copy defaulted to). Infinity and NaN now read as no number instead of raising.
- **R14** (`ee7c71c6`): the A1 and P1 encoder comments say 0 when not known (the `or 0` kept for
  other callers, said so); `ReportGroupKey` and `NewReportGroup` replace `ReportGroup`, a group
  built only for a new key; MapEdit's cleanup calls `MapEdit:Preview`; the chance check looks for
  the phrase's words around "1%"; the Vendors scenario uses `ns.CountKeys`, as do `Drops.lua`'s two
  inline counts. The other inline counts (`HunterPets.lua`, `TrainerCheck.lua`, dev-only Drops
  lines) are left for whoever touches them next.

No `L["..."]` phrase added or changed.

## Round history

- 2026-11-16 · `b87f8b2e` · Round 1 · Changes needed (0 blocking, 2 should fix, 5 nits) · opened R1–R7.
- 2026-11-16 · `ef8b95db` · Round 2 (last) · Changes needed (0 blocking, 3 should fix, 4 nits) · closed R1–R4, R6, R7 (fixed); R5 left as is (Mike's decision); opened R8–R14.
