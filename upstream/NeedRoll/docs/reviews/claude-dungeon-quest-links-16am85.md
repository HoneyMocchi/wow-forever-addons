# Review: Link every NPC and item a dungeon quest's objective names to where it stands

| | |
| --- | --- |
| Branch | `claude/dungeon-quest-links-16am85` into `dev` (PR number not assigned yet) |
| Commit reviewed | `2f02662` (round 3: `963191f..2f02662`, plus the whole change against `origin/dev` re-read; no uncommitted changes) |
| Date | 2026-10-18 |
| Round | 3 (last; per CLAUDE.md, Mike decides what's left) |
| Verdict | **Clean** after three rounds and a follow-up commit: every finding is closed. R17 closed by the rebuild check; R18 fixed. |
| Needs | `/reload`: only Lua and data files that are already in the TOC changed. No new file, no TOC or SavedVariables change. |

## What the change does

Before, a dungeon quest's Objective line linked only the bosses of the open
dungeon. Now every name in the objective that the addon can place becomes a
link:

- the givers, the turn-in NPC and the other NPCs the text names show blue
  with the giver mark;
- the mobs to kill or loot from, and the dungeon's bosses, show red with the
  dropper mark;
- items show as item links.

Each NPC or mob link opens one of four places: the boss's pin on the dungeon
map, the NPC's spot on the world map (a user waypoint), another dungeon's
entrance, or this dungeon's own map through the new `needroll:dungeonmap`
link. A plain click on an item link (in the Objective, Started by or
Targets) now opens where the item comes from, and its tooltip ends "Click to
see where it comes from". A mob with no spot of its own in Started by or
Targets also gets a map link now (Giver's new fallback), and the chain-step
page's "Turn in" became a giver link.

How the code gets there: the scraper's new `Builder._named` finds NPC names
in the QuestieDB objective text and writes them to `Data/Quests.lua` as a
`named = { ... }` list. In the addon, `ObjectiveNames` collects every
linkable name with a link builder, `LinkObjective` splices them into the
text (longest name first, no overlaps), `PlaceTarget` picks the click
target, and `ItemPlace` maps an item to its first placeable source.

## Scope

- `NeedRoll/UI/Overview.lua`: new `PlaceTarget`, `StandsHere`, `FindWholeName`, `ObjectiveNames`, `ns.UI.LinkObjective` (replaces `LinkObjectiveBosses`) and `ItemPlace`. `Giver` gets a dungeon-map fallback for droppers. `OnPageLinkClick` handles `needroll:dungeonmap` and plain item clicks. `ShowPageLinkTooltip` adds the item hint and the `dungeonmap` hint, and its hint pattern becomes `^needroll:(%a+)`. Turn in goes through `Giver`.
- `NeedRoll/UI/MainFrame.lua`: new `UI:ShowInstanceMap`.
- `NeedRoll/Core/Names.lua`: `quest.named` NPC names are tracked for translation.
- `NeedRoll/Locales/enUS.lua`: two new phrases.
- `scraper/needroll_scraper/questie_quests.py`: `_npc_names`, `_named`, `_untitled_names`, `_names_in`. `_from_old` keeps `profession`.
- `scraper/needroll_scraper/quests.py`: `Quest.named`, written as `named = {...}`. `_mobs` includes it, so its spots get registered.
- `scraper/tests/test_questie_quests.py`: two `NamedNpcsTest` cases.
- `tests/smoke/modules/UI-Overview.lua`, `tests/smoke/scenarios.lua`: the existing boss-link test moved to `LinkObjective` with a plural case, plus a new scenario for item links, giver links, tooltips and `dungeonmap`.
- `docs/STYLE-GUIDE.md`: Objective and Targets entries.
- `NeedRoll/Data/Quests.lua` (generated): not reviewed for style. I diffed it against `origin/dev` with a script that strips `named = {...}` and `profession = {...}`. What is left is 15 new NPC spot rows (the named NPCs' world spots, e.g. `[1646] = { 1453, 57.7, 47.9 }` for Baros Alexston) and quest 1486 Deviate Hides, whose second dropper changed from Deviate Coiler to Deviate Crocolisk. Both are generator output, and I found no hand edits. I could not rerun the build to confirm it's reproducible: there is no QuestieDB cache on this machine, and I did not download QuestieDB.

### Round 2 (`963191f`)

- `NeedRoll/UI/Overview.lua`:
  - new `BossNamed` and `PlaceLink`;
  - `PlaceTarget` links an entrance only when `ns.Data.entrances` knows it;
  - the giver in the Objective links the entrance of `giverNear` or `giverInside`;
  - new `ItemSources`, used by `ItemPlace`;
  - Giver's fallback writes the `dungeonmap` link directly;
  - comment and name fixes.
- `scraper/needroll_scraper/questie_quests.py`:
  - `boss_homes` and `where_npc` (used by `mob` and `giver`);
  - `_named` blocks names inside the quest's items and skips titles after ", the ";
  - `_named` drops NPCs with no dungeon and no spot;
  - `_pick_npc` and `_name_at` split out.
- `scraper/tests/test_questie_quests.py`: tests moved above `__main__`, plus three new ones (names inside items, titles and unknown maps; a boss in its own wing; `profession` kept).
- `docs/STYLE-GUIDE.md`: Turn in documented, the Targets line rewrapped.
- `tests/smoke/modules/UI-Overview.lua`: one long line wrapped.
- `NeedRoll/Data/Quests.lua` (generated), word-diffed against `1287c1c`:
  - the dropped `named` entries R2 lists (Worg Pup and its Orgrimmar spot row, Scarlet Champion, Lord Valthalak ×8, General Drakkisath; Spire Spider on 4862, now inside its item's name);
  - SM bosses now carry their wing (`Herod`, `inside = "SM_ARMORY"`; Whitemane and Mograine, `"SM_CATHEDRAL"`);
  - the two dropper slots of some multi-wing items refilled with mobs of the page's own wing (1113 Hearts of Zeal: Herod → Scarlet Abbot; 5212 The Flesh Does Not Lie: Baron Rivendare / Baroness Anastari → Bile Spewer / Crypt Beast). That follows from the dropper sort preferring mobs in `d`.
  - I found no hand edits.

### Round 3 (`2f02662`)

- `NeedRoll/UI/Overview.lua`: new `GiverTarget` (boss, NPC spot, entrance), used for the giver, chain giver and turn-in in `ObjectiveNames`. `Giver`'s boss and NPC branches and `DropSpotLink` now build their links with `PlaceLink`.
- `scraper/needroll_scraper/questie_quests.py`: `LONGEST_NAME` goes to 8 and covers item names. The `where_npc` example is now General Drakkisath. `_name_at` also cuts "'s".
- `scraper/tests/test_questie_quests.py`: new `test_possessive_names_match`.
- `NeedRoll/Data/Quests.lua`: not touched by `2f02662`.

## Checks

| Check | Result |
| --- | --- |
| R3: `luac5.1 -p NeedRoll/UI/Overview.lua` | passed |
| R3: `luacheck` | **not run**: not installed |
| R3: `bash tests/smoke/check.sh` | passed (all three runs "all passed") |
| R3: `python3 tools/locales.py --check` | exit 0 |
| R3: `cd scraper && python3 -m unittest discover -s tests` | 163 tests OK |
| R3: added lines over 120 characters | none |

Earlier rounds' results, unchanged (round 2 first, then round 1):

| Check | Result |
| --- | --- |
| R2: `luac5.1 -p` (`Overview.lua`, `UI-Overview.lua`, `Data/Quests.lua`) | passed |
| R2: `luacheck` | **not run**: still not installed |
| R2: `bash tests/smoke/check.sh` | passed (both runs "all passed") |
| R2: `python3 tools/locales.py --check` / `tools/translations.py` | exit 0 / exit 0 |
| R2: `cd scraper && python3 -m unittest discover -s tests` | 162 tests OK (3 new) |
| R2: lines over 120 among added lines | none. `scraper/tests/test_questie_quests.py:72` (121) was there before the change. |
| `luac5.1 -p` on the 7 changed Lua files (with `Data/Quests.lua`) | passed |
| `luacheck --no-global -q`, new vs base | **not run**: luacheck is not installed here (no `luacheck`, no luarocks). I checked the new functions by hand for unused locals and shadowing and found none. |
| `bash tests/smoke/check.sh` | passed ("all passed"), including the new "every NPC and item an objective names is a map link" scenario |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | exit 0. It lists 5 stale keys per locale ("Thom Filch", "Level", "Press a key", ...). This change only adds keys, so those are older (inferred). |
| `cd scraper && python3 -m unittest discover -s tests` | 159 tests OK, both `NamedNpcsTest` cases included. No network: "Wowhead pages (retired, cache only)". |
| Ketho `forever` lists | `GlobalAPI.lua`, `WidgetAPI.lua` and `FrameXML.lua` downloaded from the `forever` branch and grepped (table under WoW API) |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R17 | should fix | Readability (disinformation) | `scraper/needroll_scraper/questie_quests.py:530-538`, `NeedRoll/Data/Quests.lua` (8989-8992) | The possessive cut may bring back Lord Valthalak on the next rebuild | closed |
| R18 | nit | Redundant code | `NeedRoll/UI/Overview.lua:644-660` | `GiverTarget` and `PlaceTarget` repeat the same boss and NPC lines | closed |
| R4 | should fix | Readability (consistency) | `NeedRoll/UI/Overview.lua:656-661`, `:836-838` | The same giver opens two different places on one page | fixed in round 3 (`2f02662`) |
| R7 | nit | Redundant code | `NeedRoll/UI/Overview.lua:689-692`, `:716` | Link format copied by hand | fixed in round 3 (`2f02662`) |
| R15 | nit | Readability (comments) | `scraper/needroll_scraper/questie_quests.py:41`, `:178-181` | `where_npc` example and `LONGEST_NAME` comment are off | fixed in round 3 (`2f02662`) |
| R16 | nit | Readability (consistency) | `scraper/needroll_scraper/questie_quests.py:530-538` | A possessive NPC name is no longer found | fixed in round 3 (`2f02662`) |
| R1 | should fix | WoW API (data placement) | `scraper/needroll_scraper/questie_quests.py:178-183`, `:233` | Bosses of another wing or spire open this wing's map | fixed in round 2 (`963191f`) |
| R2 | should fix | Readability (disinformation) | `scraper/needroll_scraper/questie_quests.py:460-487` | Unrelated NPCs whose name sits inside an item name or epithet get linked | fixed in round 2 (`963191f`) |
| R3 | should fix | Readability (disinformation) | `scraper/needroll_scraper/questie_quests.py:485-486` | An open-world NPC in an unmapped zone becomes "this dungeon's map" | fixed in round 2 (`963191f`) |
| R5 | should fix | WoW API (style guide rule) | `docs/STYLE-GUIDE.md:208-210` | Chain-step "Turn in" became a link; the style guide doesn't say so | fixed in round 2 (`963191f`) |
| R6 | nit | Readability (consistency) | `NeedRoll/UI/Overview.lua:882-891` | `ItemPlace` misses item sources that Started by shows | fixed in round 2 (`963191f`); giverSee left as is: left out on purpose |
| R8 | nit | Readability (comments) | `NeedRoll/UI/Overview.lua:2804-2805` | Map-opening comments disagree with the code | fixed in round 2 (`963191f`) |
| R9 | nit | Readability | `scraper/needroll_scraper/questie_quests.py:489-538` | Scraper plural rule differs from the addon's; dense one-liners in `_named` | fixed in round 2 (`963191f`) |
| R10 | nit | Readability (consistency) | `NeedRoll/UI/Overview.lua:648` | `needroll:inside:` link colored even with no known entrance | fixed in round 2 (`963191f`) |
| R11 | nit | Readability | `scraper/tests/test_questie_quests.py` | New test class sits after `if __name__ == "__main__"` | fixed in round 2 (`963191f`) |
| R12 | nit | Readability | `scraper/tests/test_questie_quests.py` (`KeptFromTheOldFileTest`) | `_from_old` profession fix has no test | fixed in round 2 (`963191f`) |
| R13 | nit | Readability (formatting) | `tests/smoke/modules/UI-Overview.lua:524`, `scraper/tests/test_questie_quests.py:99`, `docs/STYLE-GUIDE.md:201-204` | New lines over 120 characters | fixed in round 2 (`963191f`) |
| R14 | nit | Readability (names) | `NeedRoll/UI/Overview.lua:783`, `:856` | `done` and the `PLURALS` order say less than they could | fixed in round 2 (`963191f`) |

### R1 · Bosses of another wing or spire open this wing's map

- **Severity:** should fix
- **Area:** WoW API (data placement)
- **Where:** `NeedRoll/UI/Overview.lua:638-646` (`PlaceTarget`), `:686` (Giver fallback); root cause in `scraper/needroll_scraper/questie_quests.py:215-227` (`Builder.mob`) and `:157-171` (`where`)
- **Status:** fixed in round 2 (`963191f`)

**What's wrong.** The Scarlet Monastery wings share one QuestieDB zone, and
so do Lower and Upper Blackrock Spire. `where` therefore returns every
sibling for a mob in that zone. `mob` then answers "stands in `d`" for any
of them:

```python
if inside:
    return name, None, None if d.id in inside else self.home(inside, row, d)
```

So the data writes `{ name = "Herod" }` with no `inside` on the Library
wing's copy of quest 1048. The addon reads "no npc, no inside" as "somewhere
in this dungeon" (`StandsHere`), and `PlaceTarget` returns
`needroll:dungeonmap`:

```lua
if (inside == here or inHere) and here and ns.Data:Map(here) then return "needroll:dungeonmap" end
```

**Why it matters.** On SM Library's "Into The Scarlet Monastery" (1048, and
1053 for the Alliance), the Objective now links High Inquisitor Whitemane,
Scarlet Commander Mograine and Herod. Clicking any of them runs
`ShowQuestOnMap(1048)`, which opens the **Library** map lit at the quest's
only Library marker, Houndmaster Loksey (`Data/Maps.lua:694`). Herod is in
the Armory and the other two are in the Cathedral (`Data/Bosses.lua:96`,
`:101`; their markers are at `Data/Maps.lua:696`, `:698`). The player is
sent to the wrong wing. The same happens to Upper Spire mobs on Lower Spire
pages: "General Drakkisath" (5089) is written with no `inside`, and Lord
Valthalak is written `inside = "LBRS"` on the Dire Maul copies (8967-8969,
8990-8992); both are Upper Spire (Drakkisath is UBRS in
`Data/Attunements.lua:59`, `Data/RecipeSources.lua:1829`). On 5089 the
start item's longer name wins, so Drakkisath doesn't link there. On
8990-8992 "Lord Valthalak" links to the Lower Spire entrance.

Targets already did this for quests with a drop spot (`Places` →
`DropSpotLink`). This change adds it to the Objective, and to every
Started by and Targets dropper without one (Giver's new fallback at `:686`).

**Evidence.** The 1048 row in `Data/Quests.lua`:
`kills = { { name = "High Inquisitor Whitemane" }, { name = "Scarlet Commander Mograine" }, { name = "Herod" }, { name = "Houndmaster Loksey" } }`.
`self.zones` merges dungeons that share a map (`questie_quests.py:141-145`).
I read `PlaceTarget`, `OnPageLinkClick` (`:2792-2795`), `UI:ShowQuestOnMap`
(`MainFrame.lua:2116-2122`) and `QuestDropSpot` (`any` = true returns the
first marker for the quest). I did not run it in game; the click path is
from reading the code.

**Fix.** Place the mob in its own wing at build time. In `mob` (and
`thing`), when `inside` has more than one dungeon, prefer the one whose
`EncounterDef` lists the NPC ID, and return it as `inside` when it isn't
`d`:

```python
owner = next((x.id for x in self.dungeons if x.id in inside
              and any(npc in e.npcs for e in x.encounters)), None)
if owner and owner != d.id:
    return name, None, owner
```

The addon then links "Herod (in Scarlet Monastery: Armory)" to that wing's
entrance. Alternatively, `PlaceTarget` can look for an encounter of that
name in another instance before it falls back to `dungeonmap`. Add a smoke
assertion that Herod on the SM Library page of 1048 is not
`needroll:dungeonmap`.

**Round 2.** `where_npc` (`questie_quests.py:178-183`) narrows a boss's spawn set to the instances whose catalog encounters list it (`boss_homes`). `mob` and `giver` use it. The rebuilt data writes `{ name = "Herod", inside = "SM_ARMORY" }` and Whitemane/Mograine `inside = "SM_CATHEDRAL"` on the Library copies of 1048/1053. `PlaceTarget` now gives those the wing's entrance (`Data/Entrances.lua:25-26`), not the Library map. `test_a_boss_stands_in_its_own_wing` covers it. Closed.

### R2 · Unrelated NPCs whose name sits inside an item name or epithet get linked

- **Severity:** should fix
- **Area:** Readability (disinformation)
- **Where:** `scraper/needroll_scraper/questie_quests.py:448-472` (`_named`, the two-word rule)
- **Status:** fixed in round 2 (`963191f`)

**What's wrong.** Any NPC in QuestieDB whose name has two or more words is
taken when it shows up in the objective, whether or not the quest has
anything to do with it. Names that are only part of a longer item name or a
title get matched:

- **4729 Kibler's Exotic Pets**: "Bring back a Caged **Worg Pup** to Kibler"
  becomes `{ name = "Worg Pup", npc = 273003 }`, and the spot written for
  273003 is `{ 1454, 38.3, 28.1 }`, which is Orgrimmar. The text means the
  item Caged Worg Pup.
- **8989-8992**: "the recombined **Lord Valthalak**'s Amulet" links the NPC
  for the amulet (to the Lower Spire entrance, see R1).
- **1048 / 1053**: "Herod, the **Scarlet Champion**" links the separate
  Scarlet Champion trash mob as an NPC to talk to, next to the Herod link.

**Why it matters.** A Horde player clicks "Worg Pup" on a Lower Spire quest
and gets a user waypoint in Orgrimmar. The link says something the quest
doesn't mean, and it overwrites the player's own waypoint.

**Evidence.** I listed every `named` entry in `Data/Quests.lua` with its
objective (65 quests). Worg Pup and its spot are in `Data/Quests.lua:215`
and the quest 4729 row. That 1454 is Orgrimmar is my knowledge of uiMapIDs,
not looked up in the repo.

**Fix.** Tighten the rule for NPCs that aren't the quest's own:

- skip a match when the word right before it is capitalized and not at the
  start of a sentence (it is part of a longer proper name: "Caged Worg Pup");
- skip a match that ends in a possessive `'s` when it isn't one of the
  quest's own NPCs;
- skip one that directly follows ", the" (an epithet).

Then add a drop list in `scraper/quests/forever.json` for what the rules
still get wrong. Cover Worg Pup in `NamedNpcsTest`.

**Round 2.** The quest's item names (objective items, start items, `sourceItemId`) now take part in `_names_in`, so they claim their words before the NPC names inside them. A phrase right after ", the " is skipped. The rebuilt data drops Worg Pup (and its Orgrimmar spot), the Scarlet Champion and all eight Lord Valthalak entries. `test_names_in_items_titles_and_unknown_maps_are_left_out` covers it. Closed. (R15 is a leftover comment.)

### R3 · An open-world NPC in an unmapped zone becomes "this dungeon's map"

- **Severity:** should fix
- **Area:** Readability (disinformation)
- **Where:** `scraper/needroll_scraper/questie_quests.py:469-471`; read by `NeedRoll/UI/Overview.lua:648` (`StandsHere`)
- **Status:** fixed in round 2 (`963191f`)

**What's wrong.** `_named` drops an NPC only when QuestieDB has no spawn at
all:

```python
_, spot, inside = self.mob(npc, d)
if self.where(self.db.npcs[npc], d) is None and not spot:
    continue  # nowhere known to pin
```

For an NPC that spawns only in the open world, in a zone `ZONE_MAPS`
doesn't know (the module comment says Forever's new zones are left out),
`where` returns an empty set (not `None`), `mob` returns
`(name, self.spot(npc) = None, None)`, and the entry is written as
`{ name = "..." }`. `StandsHere` reads exactly that shape as "stands in this
dungeon", so a quest-giver in a Forever town links to the dungeon's map.
The `StandsHere` comment ("neither a map spot nor a dungeon stands in the
dungeon") then misleads.

**Why it matters.** Turn-in NPCs are usually out in the world, so this hits
`named` far more often than it hits kills. None of today's 65 quests trip it
(every unplaced `named` entry I listed really is inside a dungeon), but the
next Forever zone or QuestieDB update will. The player then gets the
dungeon map for a town NPC.

**Evidence.** Read `where` (`:157-171`, "an empty set when it spawns only in
the open world"), `mob` (`:215-227`) and `spot` (`:183-193`). Inferred, not
seen in current data.

**Fix.** Keep the entry only when it can be pinned or really stands in a
dungeon:

```python
where = self.where(self.db.npcs[npc], d)
if not spot and not where:
    continue  # open world with no known map, or no spawn: nowhere to pin
```

**Round 2.** `if not self.where_npc(npc, d) and not spot: continue` now drops an empty spawn set (open world, unknown map) as well as `None`. The test's Ghost Walker Kel, on zone 1000010, is dropped. Closed.

### R4 · The same giver opens two different places on one page

- **Severity:** should fix
- **Area:** Readability (consistency)
- **Where:** `NeedRoll/UI/Overview.lua:645` (`PlaceTarget`) vs `:678-681` (`Giver`)
- **Status:** fixed in round 3 (`2f02662`)

**What's wrong.** For a giver inside the open dungeon (`giverInside == here`),
`Giver` writes "Kernobee (inside)" as `EntranceLink`, which pins the
dungeon's entrance on the world map. `PlaceTarget`, used for the same name
in the Objective, returns `needroll:dungeonmap` for `inside == here`, which
opens the dungeon's own map. The tooltips differ as well ("Inside
Gnomeregan / Click to pin the entrance on your map" vs "Click to open the
map").

**Why it matters.** On 18 quests the giver stands inside the quest's own
dungeon and the objective names them: A Fine Mess (Kernobee), Willix the
Importer, Vorrel's Revenge, Scourge of the Downs (Belnistrasz), The Hidden
Chamber (Baelog), The Scepter of Celebras, and more. On each, the Started by
link and the Objective link to the same NPC go to different places, one on
the world map and one on the dungeon map.

**Evidence.** I scanned `Data/Quests.lua` for quests whose `giverInside` is
their own instance and whose objective contains the giver's name: 18 hits.

**Fix.** Pick one. Mike's item 6 says "if they exist in a dungeon they
should be linked to the dungeon", which favors the dungeon map. To do that,
give `Giver` the same `inside == here` branch (link `needroll:dungeonmap`,
keeping the "(inside)" text). Or let `PlaceTarget` return
`needroll:inside:` for `inside == here` the way `Giver` does. Update the
style guide's Started by line to match.

**Round 2.** The Objective now links `giverNear` or `giverInside` to the entrance when one is known (`Overview.lua:824-828`), which matches Started by for most givers inside. Two cases still differ, because `ObjectiveNames` tries the entrance **first**, while `Giver` tries boss, then NPC spot, then entrance:

- **A giver who is a boss of the dungeon.** On 1318 Unfinished Gordok Business (DM_NORTH, `giver = "Captain Kromcrush", giverInside = "DM_NORTH"`; `CAPTAIN_KROMCRUSH` in `Data/Bosses.lua:228`), Started by's "Captain Kromcrush" opens his pin on the Dire Maul North map (`BossNamed` → `needroll:boss:`). The same name in the Objective ("return it to Captain Kromcrush") pins the Dire Maul entrance on the world map. The comment "as Started by does" (`:824-825`) is therefore not true for him.
- **The chain giver.** `AddPlace(quest.chainGiver, PlaceTarget(..., quest.chainGiverInside, here))` (`:829`) still returns `needroll:dungeonmap` for `chainGiverInside == here`, while `Giver` writes the entrance. On 3525 Extinguishing the Idol (RFD), giver and chain giver are both Belnistrasz, so the Objective gets two entries of the same name and length with different targets. `table.sort` in Lua 5.1 isn't stable, so which one `linkedNames` keeps (entrance or dungeon map) depends on the sort, not on any rule.

Both cases come from a scan of `Data/Quests.lua` for quests whose giver or chain giver stands inside their own dungeon, is named in the objective, and is a boss there or has `chainGiverInside == here`.

**Round 2 fix.** Pick a giver's target in one place that both callers use, so they can't drift:

```lua
-- Where a giver's name goes: their boss pin here, their world spot, else
-- the entrance of the dungeon they stand in or by.
local function GiverTarget(name, npc, inside, here)
    local boss = BossNamed(here, npc, name)
    if boss then return "needroll:boss:" .. boss.id end
    if npc and ns.Data.npcs[npc] then return "needroll:npc:" .. npc end
    if inside and ns.Data.entrances[inside] then return "needroll:inside:" .. inside end
end
```

Use it in `Giver`'s link branches, and in `ObjectiveNames` for the giver (with `giverNear or giverInside`) and for the chain giver.

**Round 3.** `GiverTarget` (`Overview.lua:656-661`) tries boss, then NPC spot, then the entrance of the dungeon the giver stands in, the same order `Giver` uses, and `ObjectiveNames` uses it for the giver (with `giverNear or giverInside`), the chain giver and the turn-in (`:836-838`). On 1318 Captain Kromcrush now opens his boss pin in both places. On 3525 the giver and chain giver Belnistrasz get the same target (the Razorfen Downs entrance), so the unstable sort no longer matters. One difference is left, by design: `Giver` still writes an uncolored `EntranceLink` when the entrance is unknown, while `GiverTarget` leaves the name unlinked. Closed.

### R5 · Chain-step "Turn in" became a link; the style guide doesn't say so

- **Severity:** should fix
- **Area:** WoW API (CLAUDE.md style-guide rule)
- **Where:** `NeedRoll/UI/Overview.lua:3249`, `docs/STYLE-GUIDE.md:207`
- **Status:** fixed in round 2 (`963191f`)

**What's wrong.** `Field(L["Turn in"], quest.turnIn)` became
`Giver(quest.turnIn, quest.turnInNpc, nil, here, "giver")`. Only chain-step
pages have `turnIn` (`Chain.Step`, `:420`; no dungeon quest in
`Data/Quests.lua` has one). On those pages the line now starts with the
Alliance flight-point mark, and it is a blue link when the NPC has a spot
(e.g. Ghak Healtouch, 1470) or plain text with the mark when it doesn't.
`STYLE-GUIDE.md:207` still reads only "shows Turn in and Zone instead of
Rewards".

**Why it matters.** CLAUDE.md requires any UI change (icons, colors, links)
to update the style guide in the same PR.

**Evidence.** `grep -n "Turn in" docs/STYLE-GUIDE.md` shows only line 207;
`grep -c "turnIn = " NeedRoll/Data/Quests.lua` gives 0.

**Fix.** Extend item 5: "Turn in: the NPC as a giver link (blue, the
`TaxiNode_Continent_Alliance` mark), pinning them on the world map when
their spot is known."

**Round 2.** `STYLE-GUIDE.md:208-210` now reads "Turn in names the NPC like a giver: blue with the giver's mark, a link that pins them when their spot is known". Closed.

### R6 · `ItemPlace` misses item sources that Started by shows

- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** `NeedRoll/UI/Overview.lua:874-887`
- **Status:** fixed in round 2 (`963191f`); giverSee left as is: left out on purpose

**What's wrong.** `StartText` names droppers for three items that
`ItemPlace` doesn't know:

- the chain's start item (`chainStartItemId`, dropped by
  `quest.chainDroppers`, `:2933-2935`);
- a start item whose dropper is the giver mob
  (`or quest.giver and Giver(..., "dropper")`, `:2987-2988`);
- the giverSee item.

`ItemPlace` only maps `startsFromId` and `providedItemId` to
`quest.droppers`. The loop over `quest.loot` also keeps the **last**
match, while the comment says "the first place it comes from".

**Why it matters.** Some item links on the page take a plain click to their
source and show the hint, and others right beside them do nothing. The
style guide promises "a click shows where they come from".

**Fix.** Add the `chainStartItemId → chainDroppers` pair and the giver
fallback, and stop at the first `loot` match:

```lua
for _, loot in ipairs(quest.loot or {}) do
    if loot.item == itemID then sources = loot.from break end
end
```

**Round 2.** `ItemSources` (`:882-891`) returns the first `loot` match and maps `chainStartItemId` to `chainDroppers`. It still doesn't fall back to the giver mob as dropper, but no quest in `Data/Quests.lua` has a start item with no droppers and a giver (a `grep` count gives 0 for both `startsFromId` and `chainStartItemId`), so nothing is missed today. Closed.

### R7 · Link format and boss lookup copied; Giver's fallback hides what it can return

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Overview.lua:639`, `:686-687`, `:803`
- **Status:** fixed in round 3 (`2f02662`)

**What's wrong.**

- `("|H%s|h%s%s%s|r|h"):format(target, icon, color, name)` is new at both
  `:687` and `:803`, next to three near-copies in `Giver` and `DropSpotLink`.
- `BossHere(here, npc, name) or npc and BossHere(here, nil, name)` is
  copied from `Giver` into `PlaceTarget`.
- At `:686`, every earlier branch of `Giver` has already failed (no boss, no
  NPC spot, no known dungeon), so `PlaceTarget(..., true)` can only return
  `needroll:dungeonmap`. Calling it re-runs both boss lookups and makes the
  reader trace five branches to learn that.

**Fix.** Add one `local function MapLink(target, icon, color, text)` and use
it in `Giver`, `DropSpotLink` and `AddPlace`. Fold the by-name retry into
`BossHere`. At `:686` write the one case that can happen:

```lua
if here and ns.Data:Map(here) then
    return MapLink("needroll:dungeonmap", icon, Theme:ColorCode(color), name)
end
```

**Round 2.** `BossNamed` and `PlaceLink` are in, and the Giver fallback and `AddPlace` use `PlaceLink`. Two hand-written copies of the same format remain: `Giver`'s NPC branch, `("|Hneedroll:npc:%d|h%s%s%s|r|h"):format(npc, icon, Theme:ColorCode(color), name)` (`:681`), and `DropSpotLink` (`:705`). Both are `PlaceLink("needroll:npc:" .. npc, icon, color, name)` and `PlaceLink("needroll:dropspot:" .. questID, DROPPER_ICON, Theme.color.dropper, name)`.

**Round 3.** `Giver`'s boss branch (`icon .. PlaceLink("needroll:boss:" .. boss.id, "", color, name)`, which renders the same as before), its NPC branch and `DropSpotLink` all use `PlaceLink`. `grep -c '|h%s%s%s|r|h' Overview.lua` gives 1, `PlaceLink` itself. Closed.

### R8 · Map-opening comments disagree with the code

- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `NeedRoll/UI/Overview.lua:2790-2791`, `NeedRoll/UI/MainFrame.lua:2124-2126`
- **Status:** fixed in round 2 (`963191f`)

**What's wrong.** `OnPageLinkClick` says "else the map's first floor", but
`ShowInstanceMap` opens `map.start or 1`, the floor the map starts on (its
own comment says so, correctly). `ShowInstanceMap` says "Returns false when
the instance has no map", but it also returns false when there is no
Overview encounter.

**Fix.** Use "the floor its map opens on" in both, and "no map or no
Overview".

### R9 · Scraper plural rule differs from the addon's; dense one-liners in `_named`

- **Severity:** nit
- **Area:** Readability
- **Where:** `scraper/needroll_scraper/questie_quests.py:497`, `:463-468`
- **Status:** fixed in round 2 (`963191f`)

**What's wrong.**

- `_names_in` accepts `phrase[:-2]` whenever the phrase ends in "s". That
  lets a name match with any two letters cut off ("Vexus" matches an NPC
  "Vex"), while the addon's `FindWholeName` accepts only "s" or "es". The
  scraper can write names the addon never links.
- In `_named`,
  `npc = (ours or sorted(ids, key=lambda n: self.where(self.db.npcs[n], d) is None))[0]`
  packs a choice and a sort into one line, and `where` is computed twice for
  the same NPC.

**Fix.** Check the cut-off part explicitly:
`phrase[len(name):] in ("", "s", "es", "'s")`. Split the NPC pick into a
named helper, `_placeable_first(ids, d)`, and reuse the `where` result.

**Round 2.** `_name_at` tries only the phrase, its "es" cut and its "s" cut, matching `FindWholeName`. `_pick_npc` has a name and a docstring. Closed. (R16 is a side effect.)

### R10 · `needroll:inside:` link colored even with no known entrance

- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** `NeedRoll/UI/Overview.lua:642`
- **Status:** fixed in round 2 (`963191f`)

**What's wrong.** `PlaceTarget` emits `needroll:inside:<id>` when
`ns.Data:Get(inside)` exists. `EntranceLink` colors the text only when
`ns.Data.entrances[inside]` exists, because without an entrance the click
(`ShowOnMap(ns.Data:Entrance(inside))`) has nothing to pin. So an Objective
name for a dungeon with no entrance looks clickable and does nothing.
Inferred: I didn't find a current dungeon without an entrance.

**Fix.** Use `ns.Data.entrances[inside]` as the condition in `PlaceTarget`.

### R11 · New test class sits after `if __name__ == "__main__"`

- **Severity:** nit
- **Area:** Readability
- **Where:** `scraper/tests/test_questie_quests.py:83-87`
- **Status:** fixed in round 2 (`963191f`)

**What's wrong.** `NamedNpcsTest` is defined below `unittest.main()`, so
`python3 tests/test_questie_quests.py` runs the old tests and exits before
the new class exists. `discover` still finds it.

**Fix.** Move the class above the `__main__` guard.

### R12 · `_from_old` profession fix has no test

- **Severity:** nit
- **Area:** Readability
- **Where:** `scraper/needroll_scraper/questie_quests.py:534`
- **Status:** fixed in round 2 (`963191f`)

**What's wrong.** `q.profession = old.get("profession")` fixes a field the
QuestieDB build dropped (visible as restored `profession = {...}` in
`Data/Quests.lua`), but no test pins it, so it can be lost again silently.

**Fix.** Add a test that runs a quest with `profession` in the old data
through `build` and asserts it survives.

### R13 · New lines over 120 characters

- **Severity:** nit
- **Area:** Readability (formatting)
- **Where:** `tests/smoke/modules/UI-Overview.lua:524` (126), `scraper/tests/test_questie_quests.py:104` (122), `docs/STYLE-GUIDE.md:202` (the rewrapped Targets line)
- **Status:** fixed in round 2 (`963191f`)

**Fix.** Wrap them. `docs/READABLE-CODE.md` §2 caps new lines at 120.

### R14 · `done` and the `PLURALS` order say less than they could

- **Severity:** nit
- **Area:** Readability (names)
- **Where:** `NeedRoll/UI/Overview.lua:772`, `:845`
- **Status:** fixed in round 2 (`963191f`)

**What's wrong.** `done` in `LinkObjective` is the set of names already
placed; `linkedNames` says so. `PLURALS = { "es", "s", "" }` only works in
this order (longest ending first, the bare name last), and nothing says why.

**Fix.** Rename `done`, and add "longest ending first" to the `PLURALS`
comment.

### R15 · `where_npc` example and `LONGEST_NAME` comment are off

- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `scraper/needroll_scraper/questie_quests.py:178-181`, `:41`
- **Status:** fixed in round 3 (`2f02662`)

**What's wrong.**

- The `where_npc` docstring gives "Lord Valthalak in Upper Blackrock
  Spire" as an example of a boss placed by its catalog encounter. Lord
  Valthalak is not a catalog encounter (`grep -n Valthalak
  scraper/needroll_scraper/catalog.py` finds nothing). His entries were
  dropped because the amulet's item name now blocks his name (R2), not by
  `where_npc`.
- `LONGEST_NAME = 6  # words in the longest NPC name an objective is
  searched for` now also limits the item names `_names_in` searches. An
  item name of seven words or more doesn't claim its words, so an NPC name
  inside it can still match.

**Why it matters.** A reader trusting the docstring would expect
`boss_homes` to cover summoned bosses that aren't in the catalog, and it
doesn't.

**Fix.** Use a real catalog case as the example (Herod alone, or
Drakkisath, who is `GENERAL_DRAKKISATH` at `catalog.py:434`). Reword the
constant: "words in the longest NPC or item name an objective is searched
for". Raise it if a quest item runs longer.

**Round 3.** The docstring now cites General Drakkisath (`GENERAL_DRAKKISATH`, `catalog.py:434`), and the comment reads `LONGEST_NAME = 8  # words in the longest NPC or item name an objective is searched for`. Closed.

### R16 · A possessive NPC name is no longer found

- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** `scraper/needroll_scraper/questie_quests.py:530-538` (`_name_at`)
- **Status:** fixed in round 3 (`2f02662`)

**What's wrong.** `WORD = [\w'-]+` makes "Alexston's" one word, so the
phrase is "Baros Alexston's". Round 1's `phrase[:-2]` cut found "Baros
Alexston" there. `_name_at` now cuts only "es" or "s", which leaves
"Baros Alexston'", so a non-own NPC named only in the possessive ("Kill
Kurzen's men") is no longer recorded. The addon's `FindWholeName` would
still link "Baros Alexston" before the "'s" if the data had him. Today no
entry is lost: the rebuilt data's `named` lists changed only in the R2
removals (word-diffed).

**Why it matters.** The scraper and the addon disagree on what counts as a
whole name again (R9 was about the reverse case). If dropping possessives
is meant to keep "X's Amulet" from linking X, item names already do that
since R2.

**Fix.** Either add `"'s"` to the cuts in `_name_at`:

```python
for ending in ("'s", "es", "s"):
    if phrase.endswith(ending):
        forms.append(phrase[:-len(ending)])
```

or say in the docstring that possessives are skipped on purpose, and why.

**Round 3.** `_name_at` adds `phrase[:-2]` for "'s", and `test_possessive_names_match` covers "Baros Alexston's". Closed. See R17 for a data side effect.

### R17 · The possessive cut may bring back Lord Valthalak on the next rebuild

- **Severity:** should fix (a check, not a code change)
- **Area:** Readability (disinformation)
- **Where:** `scraper/needroll_scraper/questie_quests.py:530-538` (`_name_at`); the data it writes for 8989-8992 in `NeedRoll/Data/Quests.lua`
- **Status:** open

**What's wrong.** I need to correct my round 2 note on R2. On The Right
Piece of Lord Valthalak's Amulet (8989-8992), whose objective reads "with
the recombined **Lord Valthalak's** Amulet", "Lord Valthalak" most likely
dropped out in round 2 because `_name_at` stopped matching possessives. It
was probably not because an item name blocked it: those rows carry no item
field (`loot`, `startsFrom`, `providedItem`) in `Data/Quests.lua`, so I
can't see that "Lord Valthalak's Amulet" is in `_named`'s `items` set.
Round 3 matches possessives again, and `2f02662` didn't touch
`Data/Quests.lua`. If the amulet isn't one of QuestieDB's objective or
start items for those quests, the next build writes
`{ name = "Lord Valthalak", inside = "LBRS" }` back:

- Lord Valthalak isn't a catalog encounter, so `where_npc` doesn't narrow
  him to Upper Spire, and `home` picks LBRS alphabetically.
- The R1/R2 false link comes back: on the Dire Maul East copies it pins the
  Lower Spire entrance.
- The daily data job would ship it with no code change.

**Evidence.** The 8989/8990 rows grepped for item fields: none. Round 1's
data had `named = { { name = "Lord Valthalak" } }` on 8989, written by the
round 1 possessive-tolerant rule. I can't rerun the build: there is no
QuestieDB cache here. Whether it comes back is inferred.

**Fix.** Run `py -m needroll_scraper quests` at the pinned commit
`49e7dbca1f` and confirm `Data/Quests.lua` doesn't change. If it does,
treat a possessive that leads straight into a capitalized word ("Lord
Valthalak's Amulet") as part of a longer name and skip it unless the NPC
is the quest's own, and add that case to `NamedNpcsTest`.

### R18 · `GiverTarget` and `PlaceTarget` repeat the same boss and NPC lines

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Overview.lua:644-649`, `:656-661`
- **Status:** open

**What's wrong.** Both functions open with the same two lines
(`BossNamed` → `needroll:boss:`, then `ns.Data.npcs[npc]` →
`needroll:npc:`) and differ only in the fallback.

**Fix.** Let `PlaceTarget` start from the giver rule:

```lua
local function PlaceTarget(name, npc, inside, here, inHere)
    local target = GiverTarget(name, npc, inside ~= here and inside or nil, here)
    if target then return target end
    if (inside == here or inHere) and here and ns.Data:Map(here) then return "needroll:dungeonmap" end
end
```

Here `inside ~= here and inside or nil` is safe in Lua 5.1, because
`inside` is a string whenever that branch is taken.

## Area notes

### Readability

Round 3: I re-read `GiverTarget`, `PlaceLink`'s callers, `Giver`, `DropSpotLink`, `ObjectiveNames` and `_name_at`. The `Giver` boss branch produces the same string as before. The new comments match the code. Still open: R17, R18.

Round 2: I re-read `BossNamed`, `PlaceTarget`, `PlaceLink`, `Giver`,
`ObjectiveNames`, `LinkObjective`, `ItemSources`, `ItemPlace`,
`OnPageLinkClick`, `where_npc`, `_named`, `_pick_npc`, `_names_in` and
`_name_at` in full. Formatting is fine, and no new line goes over 120
characters. The `", the "` title check (`questie_quests.py:522`) is
anchored on the six characters right before the phrase, so it can't skip
a name anywhere else. Still open: R4, R15, R16.

I re-read `PlaceTarget`, `StandsHere`, `Giver`, `FindWholeName`,
`ObjectiveNames`, `LinkObjective`, `ItemPlace`, `OnPageLinkClick`,
`ShowPageLinkTooltip`, `UI:ShowInstanceMap` and the scraper's `_named`,
`_untitled_names` and `_names_in` in full. Indentation is 4 spaces with LF
endings, `local` is used throughout, and no new file needs the
`local _, ns = ...` header. No function nests deeper than three levels, and
`ObjectiveNames` (37 lines) and `LinkObjective` (30) are under a screen.

On the Lua 5.1 traps:

- no `cond and nil or x`;
- no `#` on a table with holes;
- names are searched with `text:find(name, from, true)` (plain), so a `-`
  or `.` in a name is safe;
- the `table.sort` comparator in `LinkObjective` is a consistent ordering.

Splicing into a span list instead of `gsub`-ing into text that already holds
links is sound, and it explains why the old `[%w|]` guard could go.
`MIN_LINKED_NAME` keeps the old `#name > 3` rule under a searchable name.
Findings: R2, R3, R4, R6, R8, R9, R11 to R14.

### WoW API

Round 3 adds no game call, event, widget method or global.

Round 2 adds no game call, event or widget method. The new
`ns.Data.entrances[...]` checks read the addon's own data. Nothing new
touches combat, taint, secret values or globals, and the round 2 lines
still compile under Lua 5.1.

The change adds no new game call. These are the calls on the changed paths:

| Name | Kind | In Ketho `forever` | Where checked |
| --- | --- | --- | --- |
| `GameTooltip:AddLine` | widget method | yes | `WidgetAPI.lua:1190` (GameTooltip methods) |
| `GameTooltip:SetOwner` | widget method | yes | `WidgetAPI.lua:1213` |
| `GameTooltip:SetHyperlink` | widget method | inferred (pre-existing call, not in the GameTooltip list; standard FrameXML tooltip method, mirrored in `tests/smoke/wow.lua:832`) | `WidgetAPI.lua` |
| `IsModifiedClick` | global function | yes | `GlobalAPI.lua:6096` |
| `C_Item.GetItemInfo` | C_ function | yes | `GlobalAPI.lua:2522` |
| `C_Item.IsItemDataCachedByID` | C_ function | yes | `GlobalAPI.lua:2578` |
| `C_Map.GetMapInfo` | C_ function | yes | `GlobalAPI.lua:2860` |
| `HandleModifiedItemClick` | FrameXML function | yes | `FrameXML.lua:2203` |
| `needroll:dungeonmap` | the addon's own hyperlink type | n/a (handled by the page's own `OnHyperlinkClick`) | `Overview.lua:2792` |

Other checks:

- Item data is still loaded with `ns.Items:Load(id, onLoad)` in `ItemLink`;
  nothing polls.
- No events are added.
- No secret values are involved: quest and NPC names come from
  `Data/Quests.lua`, not tooltips.
- No new globals.
- `CreateOverview` (at the 60-upvalue limit) doesn't reference any new
  function: I grepped `Overview.lua` from line 3371.
- The file's main chunk still compiles under 5.1's 200-local limit
  (`luac5.1 -p`).
- Taint: `ShowOnMap` still opens the world map only outside
  `InCombatLockdown()`. `OpenMapAt` touches only NeedRoll's own frames.
- Both new phrases are literal `L["..."]`, and `locales.py --check` passes.
- The smoke stand-in needed nothing new, and the new scenario covers the
  feature.
- No nil guard was removed.
- Style guide: updated for Objective and Targets, but not for the Turn-in
  link (R5).
- Findings: R1, R5.

### Redundant code

Round 2: `BossNamed` and `PlaceLink` replace the copies R7 named, except
the two left in R7. `ItemSources` and `_pick_npc` are single-use helpers
that make their callers readable, not duplicates. `boss_homes` is built
once in `Builder.__init__` and does not repeat what `self.zones` does.

I compared against `Giver`, `EntranceLink`, `DropSpotLink`, `Places`,
`Droppers`, `BossHere`, `ItemLink`, `ns.UI.QuestDropSpot`,
`UI:ShowQuestOnMap`, `UI:ShowBossOnMap` and `UI:OpenOverview`.
`ShowInstanceMap` is a third sibling of the two `Show*OnMap` openers in the
same shape; that's acceptable. Nothing per-frame was added, and
`ObjectiveNames` runs once per page refresh. I found no dead code or debug
prints. Finding: R7.

### Security

Round 3 touches no untrusted input or output.

Round 2 touches no untrusted input or output: scraper heuristics over
QuestieDB facts read at build time, and addon link building from shipped
data. No network, Wowhead or name-privacy change.

None of the change's inputs are untrusted. The linked names and the
objective text come from scraper-built `Data/Quests.lua`; the only runtime
text spliced in is the player's own name, class and race (`FillTokens`). No
addon messages, chat or SavedVariables from other players are read, and
nothing is sent.

Scraper:

- QuestieDB is read at build time, and the data carries only NPC names, IDs
  and spots (game facts, the same shape as the existing `kills`). No
  QuestieDB code or files are copied.
- No Wowhead request; the test run says "cache only".
- No `shell=True`, `eval` or paths built from downloaded data.
- No character names or credits are involved.

## Round history

- 2026-10-18 · `1287c1c` · Changes needed · opened R1 to R14 (5 should fix, 9 nits), none closed.
- 2026-10-18 · `963191f` · Changes needed · closed R1, R2, R3, R5, R6, R8 to R14; R4 and R7 partly fixed and still open; opened R15, R16 (nits).
- 2026-10-18 · `2f02662` · Changes needed (last round) · closed R4, R7, R15, R16; opened R17 (should fix: confirm by rebuild) and R18 (nit).
- 2026-10-18 · follow-up · Clean · R17 closed: `Data/Quests.lua` rebuilt at QuestieDB 49e7dbca1f after `2f02662` came out identical (no `named` Lord Valthalak; his only entry is the kill target QuestieDB gives 8968). R18 closed: `PlaceTarget` starts from `GiverTarget`.
