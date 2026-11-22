# Review: v1.6.0 release (everything merged into dev since v1.5.0)

| | |
| --- | --- |
| Branch | `v1.5.0..origin/dev` (`6ac99a6..660ed6a`, PRs #860–#871), reviewed on `claude/project-thread-shl5wi` (round 1: = `origin/dev`; round 2: `origin/dev` plus the fixes commit `d94e3fd`) |
| Commit reviewed | Round 1: `660ed6a` (working tree clean). Round 2: `d94e3fd` (only this Review Doc uncommitted) |
| Date | 2026-11-11 |
| Round | 2 (final: at most two rounds, then Mike decides what's left) |
| Verdict | **Changes needed** (0 blocking, 0 should fix, 2 nits). Nothing blocks the release: R1–R4 and R6–R8 are fixed, R5 is left to Mike on purpose, and R9 (new, a one-line comment) was fixed after round 2 |
| Needs | Players: a full restart. Three new data files are loaded through `Data/Data.xml` (`Dungeons/AlcazPrison.lua`, `Dungeons/BlackmawHold.lua`, `Dungeons/ShapersTerrace.lua`), and the client only picks up new files at startup (inferred, as in earlier reviews). The `.toc` changes only a comment. No saved keys are added or renamed: the recipe list's toggles live in a session table (`RecipeBand.lua:313`), so the old `CANLEARN` key has nothing to migrate. |

## What the change does

**Recipe list: "From trainer" and a three-step "Learnable" (PR #861, #862).**
On the Professions tab, the band's "Can learn" tick box is replaced by two
boxes. "From trainer" keeps the recipes whose learned line ("Trainer ·
Recipe") names a trainer. "Learnable" has three steps, one per click: off,
a greyed tick (every recipe the character doesn't know, whatever its skill),
a full tick (only those its skill reaches now), then off again. Its tooltip
says which step it is on and what the next click does. The count line says
"Learnable" or "Learnable now". "Known" means `C_SpellBook.IsSpellKnown`,
now asked through `RB:IsKnown`. A `NEW_RECIPE_LEARNED` handler takes a
recipe off the list once it is learned. On the Classes tab, the Poisons
section's "Can learn" chip now sets Learnable's second step, so known
poisons drop out under it too. `Theme:CheckBox` gains `box:SetMarkMuted`
for the greyed tick.

**Shareable quests (PR #867, #868).** Each dungeon quest in
`Data/Quests.lua` can now carry `shareable = true/false`, or leave it out
when no source knows. The scraper takes it from forever.json's new
`"shareable"` map first, then QuestieDB's `questFlags` bit 8 (the extractor
now exports `questFlags`). A Classic quest QuestieDB has with no flags
counts as not shareable; a Forever quest with no flags stays unknown. In the
addon, `ns.Data:QuestShareable` prefers the game's own answer
(`C_QuestLog.IsPushableQuest`) while the quest is in the log. The answer is
cached and cleared with the quest statuses. A shareable quest's row in the
Quests list gets a people icon (`socialqueuing-icon-group`), and its quest
page's level line ends with "Shareable" or "Not shareable". The portal icon
and the new icon share `ns.UI.HintIcon`.

**New dungeons and their data (PR #864, #865, #866, #869).** Alcaz Prison
(5 bosses), Shaper's Terrace (9) and Blackmaw Hold (10, three rares) now
ship with bosses, portraits and loot, in hand-kept data files. Their
quests come from forever.json, since QuestieDB lacks most of them. Before
this release, `DevDungeons.lua` registered Alcaz Prison and Shaper's
Terrace as empty dev-only dungeons; it no longer registers dungeons. It
now holds only the four unshipped maps, with the boss pins, entrances,
door links and quest markers Mike placed in game. It also holds
`ns.Data.mapEditUnits`, the non-boss creatures that `/nr devedit`'s new
Units row places with a click. On the scraper side:
- Chains kept by hand in forever.json's `"required"` now become questlines
  (`chains.hand_kept_rows`, `npc_names`).
- A quest QuestieDB lacks can start from an item (`startItem`, `droppers`).
- A chain step QuestieDB lacks gets a light page.
- A giver whose forever.json note places them out in the world is no
  longer put inside the dungeon (`unplaced_inside`).

**DungeonJournal facts (PR #868, #869).** Dungeon quest data was matched to
the DungeonJournal addon's lists. That added quests, required steps, wings,
minimum levels and Blackmaw Hold, all as facts in forever.json and
`new-instances/`, with none of its files. The README credits it.

**Library books (PR #870).** Each book's first spot and the order of the
books now follow Mike's `/way` list. The two Blackrock Mountain books sit
on Burning Steppes (map 1428), so the zone keyed by name, its door pin and
the "Inside %s: click to pin its way in" tooltip line are gone. The
commit leaves one question for Mike: Goaz Scrolls stays in Wetlands
because the list's #1429 (Elwynn) looks like a typo.

**Watcher imports (PR #860, #863, #871).** Data from the combat log watcher.

## Scope

- `NeedRoll/UI/RecipeBand.lua`: `TOGGLES` as keyed specs, `LEARNABLE_ANY`/`LEARNABLE_NOW` and `NEXT_LEARNABLE_STEP`, `RB:IsKnown`, the `NEW_RECIPE_LEARNED` handler, `IsTaughtByTrainer`, `IsLearnable`, `Keeps`, `SetToggle`, `LearnableTooltipText`, `ShowLearnableTooltip`, `ShowStep`, `ToggleBox`, `ShowToggles`, `RB:Paint`'s toggles and count line (read in full).
- `NeedRoll/UI/Theme.lua`: `Theme:CheckBox` gains `SetMarkMuted` (native: desaturated checked texture; flat skins: muted tick, no accent fill).
- `NeedRoll/UI/Poisons.lua`: the `LEARNABLE` chip and `PickChip`; the Known box asks `RB:IsKnown`.
- `NeedRoll/Data/Data.lua`: `QuestLogShareable`, `FreshShareable`, `shareableCache`, `ns.Data:QuestShareable`, `ForgetQuestShareable` (hand-written); the Library comment.
- `NeedRoll/UI/Overview.lua`: `ns.UI.HintIcon` (from `InsideIcon`), `InsideIcon` on top of it, `ForgetQuestStatus` clears the shareable cache, `LevelText` adds Shareable / Not shareable.
- `NeedRoll/UI/Lists.lua`: `SHARE` constants, `ShowQuestIcons` and `SetupQuestRow` take `shareable`, both callers pass it.
- `NeedRoll/UI/MapEdit.lua` (dev tool): Units row (`unitsLabel`, `units`, `LayOutButtonRows`, `CreateUnitButton`, `ShowListedUnits`, `MapEdit:PickListedUnit`), `MapEdit:ShowUnit` (was a closure in `LookUpUnit`), `UpdatePalette` lights the picked unit.
- `NeedRoll/UI/LibraryBooks.lua`: the name-keyed zone, `ZoneName` wrapper, door pin and its tooltip line removed.
- `NeedRoll/Data/DevDungeons.lua` (hand-written, dev-only): no more empty dungeons; pins, spots and `mapEditUnits` for four dev maps.
- `NeedRoll/Data/LibraryBooks.lua`, `NeedRoll/Data/Maps.lua` (hand-written): spots and order; the zone-wide quest of The Drowned City. Read for what they hold.
- `NeedRoll/Core/Drops.lua`: two comments only (the example unlisted dungeon is now The Barrow Deeps).
- `NeedRoll/Data/Data.xml`: loads the three new dungeon files. `NeedRoll/NeedRoll.toc`, `.pkgmeta`: comments only.
- `NeedRoll/Locales/enUS.lua`: 9 new UI strings (Shareable ×3, From trainer, Learnable, Learnable now, three Learnable tips), 25 boss names, Library place strings reordered, "Inside %s: click to pin its way in" and eight Library place pairs dropped. `Locales/NpcNames/Forever.lua`: 25 NPC IDs.
- `scraper/needroll_scraper/chains.py`, `questie_quests.py`, `quests.py`, `compare.py`, `sources/questie.py`, `sources/questie_extract.lua`; `scraper/tests/test_chains.py`, `test_questie_quests.py`, `test_pipeline.py`.
- `tests/smoke/wow.lua` (`C_QuestLog.IsPushableQuest`), `tests/smoke/scenarios.lua` and modules `Core-Drops`, `Data-DevDungeons`, `UI-DungeonQuestlines`, `UI-LibraryBooks`, `UI-Lists`, `UI-MapEdit`, `UI-Overview`, `UI-Poisons`, `UI-RecipeBand`.
- `docs/STYLE-GUIDE.md`, `docs/LOCALIZATION.md`, `README.md`, `scraper/README.md`, `new-instances/AlcazPrison.txt`, `BlackmawHold.txt`, `ShapersTerrace.txt`.
- Skipped, as generated or partly generated: `NeedRoll/Data/Chains.lua`, `ClassQuests.lua`, `ClassSpells.lua`, `Attunements.lua`, `Entrances.lua`, `KnownDrops.lua`, `KnownQuests.lua`, `Quests.lua`, `Dungeons/*.lua` (the three new ones are hand-kept with `ingest` adding drops; checked only for their headers and sources).
- Inputs, checked only for what they hold (names, sources): `scraper/quests/forever.json`, `logged.json`, `reported.json`, `scraper/classes/seen.json`, `scraper/drops/*.json`, `scraper/abilities/observed.json`, `scraper/professions/trainer_checks.json`, `scraper/compare/verdicts.txt`.
- Not in scope: `CHANGELOG.md`, `CHANGELOG-DETAILED.md` (the changelog PR updates them).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 25 changed hand-written Lua files, and on every changed file under `NeedRoll/Data/` | passed (Lua 5.1.5 installed for this review) |
| `luacheck --no-global -q` now vs `v1.5.0` (luacheck 1.1.2), warnings compared without line numbers | 7 new warnings, none a bug. `RecipeBand.lua:1214`, `:1217` (two `L["..."]` tips, 124 and 121 chars, as tips already are) and `:1350` (121, code; R8). `RecipeBand.lua:359` unused `self` (`RB:IsKnown`; the file has 14 more like it). `Theme.lua:1137`, `:1161` shadowing `self` (`box:SetMarkMuted`, as `box:Set` already does). `scenarios.lua:1723` 132 chars (R8) |
| `tests/smoke/check.sh` (dev, packaged, secret values, in combat) | passed: exit 0, "all passed" in all four runs (221 / 212 / 221 / 221 files loaded; 663 / 579 / 663 / 663 scenarios ok) |
| `python3 tools/locales.py --check` | passed (exit 0, no output) |
| `python3 tools/translations.py` | passed (exit 0). It lists 7 phrases per translation file as no longer used ("Cavern of Mists", "Thelsamar", "Inside %s: click to pin its way in", and four more Library strings) for the Translations bot, as usual |
| `cd scraper && python3 -m unittest discover -s tests` | passed (358 tests) |
| `python3 -m needroll_scraper build --check` (extra: hand edits to generated loot data) | passed: "No data files changed". It only rebuilds the loot catalogs. **Not run:** a rebuild of `Quests.lua`/`Chains.lua`, which needs QuestieDB at the pinned commit (not cached here), so this review doesn't confirm that those two files match their generator |
| Lua 5.1 limits (extra; `luac5.1 -l -l`, most main-chunk locals active at once, and most upvalues in one function, now / at `v1.5.0`) | `Overview.lua` 194 / 194 locals (unchanged, 6 from the 200 limit), `CreateOverview` 34 / 34 upvalues. `Lists.lua` 112 / 111, `CreateEncounterList` 43 / 43. `RecipeBand.lua` 110 / 101. `MapEdit.lua` 95 / 92. `Data.lua` 60 / 58. `Theme.lua` 89 / 89. None near a limit |
| Player names (extra) | none: the 229 names in `credits.json` and the 147 `by` names the range adds to the watcher files appear nowhere in `NeedRoll/`, `README.md`, `docs/` or `new-instances/` (grepped) |
| MapEdit probe (extra, in a scratch copy of the repo, not committed) | showed R2: after the click, `MapEdit.tool` is nil, but the picked line still reads "Entrance  ·  click the map" with Escape shown |

### Round 2 checks (on `d94e3fd`)

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 13 Lua files `d94e3fd` changes (8 addon, 5 smoke) | passed |
| `luacheck --no-global -q`, each changed file at `d94e3fd` vs `660ed6a` (warning counts) | no new warnings. `RecipeBand.lua` 19 → 18 (the 121-char count-line warning is gone; the two long `L["..."]` tips remain, now at `:48` and `:51` after the move). `scenarios.lua` 66 → 65 (the 132-char line is gone). `Names.lua` 4, `Data.lua` 17, `DevDungeons.lua` 1, `enUS.lua` 55, `MainFrame.lua` 5, `MapEdit.lua` 2, `Poisons.lua` 1, and the four smoke modules, unchanged |
| `tests/smoke/check.sh` (all four runs: dev, packaged, secret values, in combat) | passed: exit 0, "all passed" in each (221 / 212 / 221 / 221 files loaded; 665 / 581 / 665 / 665 scenarios ok, two more each than round 1). The new "Core/Names: a learned line's trainer word counts in either language" and "UI/RecipeBand: a recipe learned at the trainer leaves Learnable's list" run in all four; "UI/MapEdit: devedit lists a new dungeon's other units to place" with its R2 asserts runs in the three dev runs |
| `python3 tools/locales.py --check` | passed (exit 0, no output) |
| `python3 tools/translations.py` (extra) | passed (exit 0). "Can learn" now joins the phrases each translation file lists as no longer used, as R6 expected |
| `cd scraper && python3 -m unittest discover -s tests` | not run again: `d94e3fd` changes no scraper file |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | WoW API (smoke coverage) | `NeedRoll/UI/RecipeBand.lua:363-369` | The `NEW_RECIPE_LEARNED` handler has no scenario | fixed in round 2 (`d94e3fd`) |
| R2 | nit | Readability (dev tool behaviour) | `NeedRoll/UI/MapEdit.lua:1272-1285` | Picking a listed unit with no display leaves the old pick lit | fixed in round 2 (`d94e3fd`) |
| R3 | nit | Readability (§6, §9) | `NeedRoll/UI/RecipeBand.lua:44-51`, `:1222-1256` | The "stepped box" looks general but always shows Learnable's tooltip | fixed in round 2 (`d94e3fd`); see R9 |
| R4 | nit | Redundant code | `NeedRoll/UI/RecipeBand.lua:394-403`; `NeedRoll/UI/MainFrame.lua:278-287` | Two copies of "does the learned line name a trainer", answering differently | fixed in round 2 (`d94e3fd`) |
| R5 | nit | Readability (player text) | `NeedRoll/UI/Lists.lua:1469`; `NeedRoll/Locales/enUS.lua` | The share icon says "you can share it" on quests the player doesn't have | left as is: the wording is Mike's call, so it goes to him |
| R6 | nit | Readability (§6 consistency) | `NeedRoll/UI/Poisons.lua:30`; `NeedRoll/UI/RecipeBand.lua:50` | One filter, two names: "Can learn" (Poisons) and "Learnable now" (Professions) | fixed in round 2 (`d94e3fd`) |
| R7 | nit | Redundant code | `NeedRoll/Data/Data.lua:174-190` | An unneeded nil guard on `C_QuestLog.IsPushableQuest`, and `QuestXP`'s alt-ID loop copied | guard fixed in round 2 (`d94e3fd`); shared loop left as is: "no shorter" |
| R8 | nit | Readability (§2 formatting, §9 naming) | `NeedRoll/UI/RecipeBand.lua:1350`; `tests/smoke/scenarios.lua:1723`; `NeedRoll/Data/DevDungeons.lua:99-103`; `NeedRoll/UI/MapEdit.lua:1185` | Small formatting and naming slips | fixed in round 2 (`d94e3fd`) |
| R9 | nit | Readability (§9 no misleading comments) | `NeedRoll/UI/RecipeBand.lua:56-58`, `:1223-1230`, `:1248` | A stepped toggle without `tooltip` errors on hover, and the spec comment doesn't say it's required | fixed after round 2 (the `TOGGLES` comment now says a stepped box must give `tooltip(step)`) |

### R1 · The `NEW_RECIPE_LEARNED` handler has no scenario
- **Severity:** should fix
- **Area:** WoW API (a new game event without a smoke scenario)
- **Where:** `NeedRoll/UI/RecipeBand.lua:363-369`; `tests/smoke/modules/UI-RecipeBand.lua`, `tests/smoke/scenarios.lua` (no scenario)
- **Status:** fixed in round 2 (`d94e3fd`)

**What's wrong.** PR #861 adds a new event handler:

```lua
-- A recipe learned while Learnable is on leaves the list there and then.
ns:On("NEW_RECIPE_LEARNED", function()
    local pane = ns.UI.encounters
    if not (pane and pane.band and pane.band:IsShown()) then return end
    if not RB:State(pane.instance).toggles.LEARNABLE then return end
    ns.UI:RecipeNarrowed(true)
end)
```

No smoke scenario fires it. The scenarios cover the Learnable steps by
setting `W.knownSpells` before narrowing, and never learn a recipe while
the list is shown.

**Why it matters.** This is the only code that changes the list while a
player stands at a trainer, the moment the feature is for. Nothing tests
these cases:
- With Learnable on, the learned recipe leaves the list.
- The selection stays on it: `keepSelection = true`, so the page doesn't
  jump away from the recipe just bought.
- With the band hidden or Learnable off, nothing happens.

A later change to `RecipeNarrowed`'s argument, or to the guards, would
break this silently. The reviewer checklist asks for a scenario for each
new feature.

**Evidence.** `grep -rn NEW_RECIPE_LEARNED tests/ NeedRoll` finds only
`RecipeBand.lua:364`. The event is in Ketho's `forever` `Events.lua`
(line 1883).

**Fix.** Add a scenario to `UI-RecipeBand.lua` (or next to "recipe list:
slot chips, toggles and colour sets" in `scenarios.lua`):
1. Open a profession with the band shown and Learnable on
   (`RB.LEARNABLE_ANY`), with a recipe selected.
2. Add its spell to `W.knownSpells`, then
   `W.Event("NEW_RECIPE_LEARNED", spellID)`.
3. Assert the recipe's row is gone and `ui.state.encounter` is unchanged.
4. Fire it again with Learnable off and assert the list didn't re-narrow,
   for example by spying on `list.SetData`.

**Round 2.** Fixed. `tests/smoke/modules/UI-RecipeBand.lua` adds "UI/RecipeBand: a recipe learned at the trainer leaves Learnable's list". It turns Learnable to its first step, selects a listed recipe with a spell (`ui:SelectRecipe`), marks it known in `W.knownSpells` and fires `W.Event("NEW_RECIPE_LEARNED", spellID)`. It then asserts that the recipe is off the list (`not list:IsListed(bought)`) and that the page stayed on it (`ui.state.encounter == bought`). With Learnable turned off again, it spies on `list.SetData` and asserts a second event doesn't narrow. The spy does see a narrowing: `UI:RecipeNarrowed` calls `list:SetData` first (`MainFrame.lua:1797-1799`), and `list:SetData` finds the replaced field on the pane. The band-hidden guard isn't exercised, which the round-1 fix didn't ask for. The scenario passed in all four runs.

### R2 · Picking a listed unit with no display leaves the old pick lit
- **Severity:** nit (dev tool only; players never see `/nr devedit`)
- **Area:** Readability (the palette shows a pick that isn't the tool; §9)
- **Where:** `NeedRoll/UI/MapEdit.lua:1272-1285` (`MapEdit:PickListedUnit`), `:1425-1434` (`MapEdit:ShowUnit`)
- **Status:** fixed in round 2 (`d94e3fd`)

**What's wrong.**

```lua
    -- A click on a unit picks it, whatever was picked before.
    self.tool, self.drawFor = nil, nil
    self.palette.unitBox:SetText(tostring(listed.unit))
    if not listed.display then
        self:LookUpUnit(tostring(listed.unit))
```

The tool is cleared without `self:UpdatePalette()`. `LookUpUnit` calls
`UpdatePalette` only when the old tool was `"unit"`. `ShowUnit` returns
before `UpdatePalette` while the display is unknown. So the button picked
before (Entrance, a boss, a patrol), the picked line, the cursor cue and
Escape all keep showing the old pick:
- for up to 5 s while the model is fetched (`UNIT_TRIES = 10` half-second
  looks);
- for good, if the lookup ends in "Not found".

A click on the map meanwhile does nothing, since `self.tool` is nil. The
path where the display is known is fine, because `ShowUnit` then sets
`tool = "unit"` and repaints.

**Why it matters.** The comment says the click picks the unit "whatever was
picked before". What Mike sees is the old tool still lit, with a map that
ignores his clicks. Of the six Alcaz Prison units, three (Strashaz Soldier,
Strashaz Enchantress, Perfumed Note) have no display. So do all of
Krol'dok's and The Drowned City's, so this is the common case.

**Evidence.** A probe in a scratch copy set `MapEdit.tool = "entrance"`
and clicked the Strashaz Soldier's button. It printed
`after click: nil  Entrance  ·  click the map  true` (tool, picked line,
Escape shown). The committed scenario ("devedit lists a new dungeon's other
units") clicks the soldier right after letting go of Mason Connery, with
nothing picked, so it can't see this.

**Fix.** Repaint once the old pick is let go:

```lua
    self.tool, self.drawFor = nil, nil
    self:UpdatePalette()
```

Then add one assert to the scenario: pick a tool first, click
`shown[4]`, and assert `palette.picked:GetText() == "Nothing picked"`
until the model arrives.

**Round 2.** Fixed as suggested. `MapEdit:PickListedUnit` calls `self:UpdatePalette()` right after `self.tool, self.drawFor = nil, nil` (`MapEdit.lua:1275-1276`). `UpdatePalette` (`:1378-1391`) then shows "Nothing picked", clears the cue and hides Escape. When the display is known, `ShowUnit` repaints again once it sets `tool = "unit"`, which is harmless. The MapEdit scenario now picks Entrance first, clicks the Strashaz Soldier, and asserts `palette.picked:GetText() == "Nothing picked" and not palette.escape:IsShown()` while the model is looked up. It passed in the three dev runs (MapEdit doesn't ship).

### R3 · The "stepped box" looks general but always shows Learnable's tooltip
- **Severity:** nit
- **Area:** Readability (§6 one way of doing each thing, §9 no misleading names)
- **Where:** `NeedRoll/UI/RecipeBand.lua:44-51` (`TOGGLES` comment and spec), `:1222-1228` (`ShowLearnableTooltip`), `:1230-1237` (`ShowStep`), `:1239-1256` (`ToggleBox`)
- **Status:** fixed in round 2 (`d94e3fd`); the fix leaves the small gap in R9

**What's wrong.** Several pieces describe steps as a general property of
any toggle:
- The spec comment: "A box with `nextStep` has steps instead of on and
  off; `stepLabels` names each step on the count line".
- `ShowStep`: "Shows a stepped box's `step`".
- `ToggleBox`: "a stepped one moves to its next step on a click and names
  its step in a tooltip".

But the tooltip is hard-wired:

```lua
    if GameTooltip:IsOwned(box) then ShowLearnableTooltip(box) end
...
    box:SetScript("OnEnter", ShowLearnableTooltip)
```

`ShowLearnableTooltip` always titles the tooltip `L["Learnable"]` and
reads `LearnableTooltipText`, whose three strings are about recipes you
haven't learned.

**Why it matters.** The next stepped toggle (say, a three-step Hide grey) is
one spec line away. Whoever adds it gets Learnable's title and text on the
new box, with nothing to warn them: the names and comments promise a
general mechanism. That is half-generic code. It's neither plainly
Learnable's nor truly general.

**Fix.** Pick one:
- Make it general. Put the tooltip in the spec,
  `{ key = "LEARNABLE", ..., tooltip = LearnableTooltipText }`. Keep it on
  the box (`box.tooltip = spec.tooltip`), and have one `ShowStepTooltip(box)`
  use `box.label:GetText()` as the title and `box.tooltip(box.step)` as the
  text.
- Or name it for what it is: `ShowLearnableStep`, `LearnableBox`, and say
  in the `TOGGLES` comment that Learnable is the one box with steps.

**Round 2.** Fixed the general way. `LearnableTooltipText` moves above `TOGGLES` (`RecipeBand.lua:45-54`), and the spec carries `tooltip = LearnableTooltipText` (`:62`). `ToggleBox` copies it to `box.tooltip` (`:1248`). The renamed `ShowStepTooltip` (`:1223-1230`) titles the tooltip with `box.label:GetText()`, which `Theme:CheckBox` sets to the spec's label (`Theme.lua:1171-1172`), so it still reads "Learnable". Its text comes from `box.tooltip(box.step)`. The spec comment now names `tooltip(step)`. Nothing else in the addon reads a `tooltip` field on a tick box (grepped `\.tooltip\b`; `LootGrid.lua`'s `Starters.tooltip` is an unrelated table), so the new field clashes with nothing. The scenario now also asserts the tooltip's title and step text. One small gap is left: R9.

### R4 · Two copies of "does the learned line name a trainer", answering differently
- **Severity:** nit
- **Area:** Redundant code (and §6 consistency)
- **Where:** `NeedRoll/UI/RecipeBand.lua:394-403` (`IsTaughtByTrainer`); `NeedRoll/UI/MainFrame.lua:278-287` (`LearnedText`); also `NeedRoll/Core/TrainerCheck.lua:99` (dev-only, `find("Trainer", 1, true)`)
- **Status:** fixed in round 2 (`d94e3fd`)

**What's wrong.** Both functions split `encounter.learned` with
`ns.Names.SplitParts` and look for the trainer word:

```lua
-- RecipeBand.lua
        if part == L["Trainer"] or part == "Trainer" then return true end
-- MainFrame.lua
        if part ~= L["Trainer"] then table.insert(kept, part) end
```

The new one also accepts the English word. Its comment explains why:
"Core/Names.lua puts the line in the player's language a second after
login, so the English word counts too". The recipe page's copy doesn't
accept it.

**Why it matters.** The same question gets two answers in the first second
after login on a non-English client. The recipe page's subtitle would
keep "Trainer" next to the trainers' own box, while From trainer counts
the recipe as taught. The next fix to one copy (a renamed source word, a
third language case) will miss the other.

**Fix.** Give the test one home, for example on `ns.Names` next to
`SplitParts`:

```lua
-- Whether `part` of a learned line is the trainer word, in the player's
-- language or, until Core/Names.lua has translated the line, in English.
function Names.IsTrainerPart(part)
    return part == L["Trainer"] or part == "Trainer"
end
```

Use it in both `IsTaughtByTrainer` and `LearnedText`.

**Round 2.** Fixed. `Names.IsTrainerPart(part)` lives in `Core/Names.lua:184-189`, next to `SplitParts`/`JoinParts` and in their dot style. Its comment carries the reason (the line is put in the player's language a second after login). `IsTaughtByTrainer` (`RecipeBand.lua:409-415`) and `LearnedText` (`MainFrame.lua:284`) both call it, and the English-word sentence left `IsTaughtByTrainer`'s comment. The behaviour change the implementer flagged is the intended one. On a non-English client, in the first second after login, the recipe page's subtitle now also drops the untranslated "Trainer" while the trainers' box names them, so both places give one answer. A new scenario ("Core/Names: a learned line's trainer word counts in either language") sets `L["Trainer"]` to "Lehrer" and checks both words and a non-trainer part. The existing recipe page scenarios (`UI-MainFrame.lua:762-792`) still pass. `Core/TrainerCheck.lua:99` keeps its own `find("Trainer", 1, true)`. That's acceptable: it is dev-only (inside `@debug@`) and does a substring test on the English data, a different job.

### R5 · The share icon says "you can share it" on quests the player doesn't have
- **Severity:** nit
- **Area:** Readability (player-facing text that misleads)
- **Where:** `NeedRoll/UI/Lists.lua:1469`; `NeedRoll/Locales/enUS.lua` (`L["Shareable: you can share it with your party"]`); `docs/STYLE-GUIDE.md` Share icon row
- **Status:** left as is: the implementer didn't change the wording on purpose; it goes to Mike

**What's wrong.** The icon shows on every quest whose data says
`shareable = true`, most of them quests the player hasn't picked up. Its
tooltip reads "Shareable: you can share it with your party".

**Why it matters.** A player who doesn't have the quest can't share it.
Only someone who has it can share it with them. The text reads as if
this character can share it now. On a dungeon's Quests list, the useful
fact is the other way round: a party member who has it can hand it to
you.

**Fix.** Use a new key that says what the mark means whoever holds the
quest, for example `L["Shareable: whoever has it can share it with their party"]`,
and update the STYLE-GUIDE row. The old key drops out of the translation
files through the Translations bot, as usual.

**Round 2.** Not changed, on purpose: the implementer leaves the wording to Mike. The tooltip still reads "Shareable: you can share it with your party" (`enUS.lua`). The finding stands as a nit for Mike to decide; it doesn't block the release.

### R6 · One filter, two names: "Can learn" (Poisons) and "Learnable now" (Professions)
- **Severity:** nit
- **Area:** Readability (§6 consistency, player-facing)
- **Where:** `NeedRoll/UI/Poisons.lua:30` (`{ key = "LEARNABLE", label = L["Can learn"] }`), `:76-77`; `NeedRoll/UI/RecipeBand.lua:50` (`[LEARNABLE_NOW] = L["Learnable now"]`)
- **Status:** fixed in round 2 (`d94e3fd`)

**What's wrong.** The Poisons chip now sets exactly
`toggles.LEARNABLE = RB.LEARNABLE_NOW`, the step the Professions band calls
"Learnable now". The chip is still labelled "Can learn". The Professions
box that used to be "Can learn" is gone.

**Why it matters.** A rogue with a profession meets the same filter under
two names on two tabs, and "Can learn" no longer appears anywhere else.
The meaning also changed under the old name: it now leaves known
poisons out, which the old "Can learn" didn't.

**Fix.** Label the chip `L["Learnable now"]` (an existing key, so no new
translation), and update the STYLE-GUIDE's Poisons row ("All, Skill-ups
and Learnable now"). `L["Can learn"]` then has no users, and
`tools/locales.py` drops it.

**Round 2.** Fixed. The chip reads `L["Learnable now"]` (`Poisons.lua:30`). In `enUS.lua` the key moves to the `UI/Poisons.lua` block, where `tools/locales.py` first finds it, and `L["Can learn"]` is gone. `locales.py --check` passes, and `translations.py` lists "Can learn" as unused in each translation file for the Translations bot. The STYLE-GUIDE's Poisons row reads "All, Skill-ups and Learnable now". `UI-Poisons.lua` asserts the chip's text. No "Can learn" is left in the addon, the English list, the smoke tests or the STYLE-GUIDE (grepped).

### R7 · An unneeded nil guard on `C_QuestLog.IsPushableQuest`, and `QuestXP`'s alt-ID loop copied
- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/Data/Data.lua:174-177` (`QuestLogShareable`), `:182-190` (`FreshShareable`); compare `:163-169` (`ns.Data:QuestXP`)
- **Status:** the guard is fixed in round 2 (`d94e3fd`); the shared alt-ID walk is left as is (implementer: "no shorter")

**What's wrong.**

```lua
    if type(C_QuestLog.IsPushableQuest) ~= "function" or not C_QuestLog.IsOnQuest(questID) then return nil end
```

`C_QuestLog.IsPushableQuest` is in Ketho's `forever` `GlobalAPI.lua`
(line 3594), next to `C_QuestLog.IsOnQuest` (3593). The line calls
`IsOnQuest` unguarded. `FreshShareable` then repeats the walk over
`quest.id` and `quest.alt` that `QuestXP`, three functions up, already does
("the game's answer under any of the quest's IDs, else the data's").

**Why it matters.** The guard says Forever might lack the call, which the
lists say it doesn't, so a reader goes looking for a client that does. Two
copies of the same alt-ID walk in one file will drift.

**Fix.** Drop the `type(...)` test. Optionally, share the walk:

```lua
-- The first answer `lookup` gives for the quest's ID or another version's
-- (quest.alt), or nil when none does.
local function FirstLiveAnswer(quest, lookup)
    local answer = lookup(quest.id)
    for _, altID in ipairs(quest.alt or {}) do
        if answer ~= nil then return answer end
        answer = lookup(altID)
    end
    return answer
end
```

Use it in `QuestXP` (`FirstLiveAnswer(quest, QuestLogXP) or quest.xp`) and
`FreshShareable`. A `false` answer must stop the walk, which is why the
test is `~= nil`.

**Round 2.** The guard is gone: `if not C_QuestLog.IsOnQuest(questID) then return nil end` (`Data.lua:175`). That is sound, since the call is in Forever's `GlobalAPI.lua` (line 3594) and `wow.lua` mirrors it. The shared alt-ID walk isn't done. The implementer's reason is "no shorter", and that holds. `QuestXP` folds with `or` (a 0 XP answer is truthy in Lua), `FreshShareable` must stop on `false`, and a helper taking a lookup function would add as many lines as it saves. Accepted.

### R8 · Small formatting and naming slips
- **Severity:** nit
- **Area:** Readability (§2 formatting, §9 naming)
- **Where:** `NeedRoll/UI/RecipeBand.lua:1350`; `tests/smoke/scenarios.lua:1723`; `NeedRoll/Data/DevDungeons.lua:99-103`; `NeedRoll/UI/MapEdit.lua:1185`
- **Status:** fixed in round 2 (`d94e3fd`)

**What's wrong.**
- `RecipeBand.lua:1350` (121 chars) and `scenarios.lua:1723` (132) are new
  code lines over the 120 limit (luacheck).
- `DevDungeons.lua:100-103`: `links = {` and its `[1] =`/`[2] =` lines sit
  at the same indent, and the closing `} },` is outdented below both,
  unlike the rest of `UNFINISHED_SPOTS`.
- `MapEdit:LayOutBosses(bossCount, unitCount)` now also lays out the unit
  rows, the Units label, the unit picker, quest portal, previews and hint,
  and sets the window's height. The name says bosses.

**Fix.** Wrap the two lines. For example
`local label = spec.stepLabels and spec.stepLabels[value] or spec.label`,
then `text = text .. Theme.DOTS .. label`. Indent the `links` entries one
level in. Rename `LayOutBosses` to `LayOutPalette` (three callers, all in
`MapEdit.lua`).

**Round 2.** Fixed. The count line is wrapped with a named `label` local (`RecipeBand.lua:1352-1355`). The `scenarios.lua` assert is wrapped. luacheck no longer reports either line (see Round 2 checks). `DevDungeons.lua:100-102` indents the `links` entries one level in and closes with `} } } },`, the way the other `UNFINISHED_SPOTS` entries close. `MapEdit:LayOutBosses` is now `LayOutPalette` at the definition and both callers (`:1164`, `:1322`), and its comment already describes the whole palette. Only older Review Docs still mention `LayOutBosses`, as history.


### R9 · A stepped toggle without `tooltip` errors on hover, and the spec comment doesn't say it's required
- **Severity:** nit
- **Area:** Readability (§9 no misleading comments; the R3 fix)
- **Where:** `NeedRoll/UI/RecipeBand.lua:56-58` (`TOGGLES` comment), `:1223-1230` (`ShowStepTooltip`), `:1248` (`ToggleBox`)
- **Status:** fixed after round 2: the `TOGGLES` comment now says a stepped box must give `tooltip(step)`

**What's wrong.** The R3 fix makes the stepped box general, and its spec comment
lists `tooltip` like the optional `stepLabels`:

```lua
-- The tick boxes, in order. A box with `nextStep` has steps instead of on
-- and off; `stepLabels` names each step on the count line, and
-- `tooltip(step)` gives the box's tooltip text at each step.
```

But every stepped box gets `ShowStepTooltip` as its `OnEnter`, and that
calls the field unguarded:

```lua
    GameTooltip:AddLine(box.tooltip(box.step), r, g, b, true)
```

`stepLabels`, by contrast, really is optional: `RB:Paint` falls back to
`spec.label` without it.

**Why it matters.** This is the case R3 was about: the next stepped toggle.
If its spec has `nextStep` but no `tooltip`, it works until the player
moves the mouse over the box. Then the game shows a Lua error
("attempt to call field 'tooltip' (a nil value)") and the tooltip stays
half-built. Nothing in the comment warns the person adding it.

**Evidence.** Read `RecipeBand.lua:56-63`, `:1223-1251`. Only the
Learnable spec has `nextStep` today, and it has `tooltip`, so nothing breaks
in this release (all four smoke runs pass, and the scenario hovers the box).
The error is inferred from the code: Lua 5.1 raises it for a call on nil.

**Fix.** One comment line is enough. Say a stepped box must have it, for example
"A box with `nextStep` has steps instead of on and off, and must give
`tooltip(step)`, its tooltip text at each step; `stepLabels` names each
step on the count line." A guard (`if box.tooltip then ... end`) would
hide the mistake instead of naming the rule, so a comment is better here.

## Area notes

### Readability

I read these functions in full against READABLE-CODE.md:
- `RecipeBand.lua`'s whole toggle path (spec table through count line).
- `Theme:CheckBox`.
- `Poisons.PickChip` and `ListedRecipes`.
- The shareable chain in `Data.lua`.
- `ns.UI.HintIcon`/`InsideIcon`, `LevelText`, `ShowQuestIcons` and
  `SetupQuestRow` with both callers.
- `MapEdit`'s Units row: `LayOutButtonRows`, `LayOutBosses`,
  `CreateUnitButton`, `ShowListedUnits`, `PickListedUnit`, `ShowUnit`,
  `LookUpUnit`, `ShowBosses`, `UpdatePalette`.
- `LibraryBooks.lua`'s `ZoneOf`, `SpotLink`, `ShowSpotTooltip`, `SubText`.
- The whole of `DevDungeons.lua`.

Sound:
- **Names** are in game terms: `IsTaughtByTrainer`, `IsLearnable`,
  `LEARNABLE_NOW`, `QuestShareable`, `pinnedHere`, `bossNpcs`,
  `listedUnits`, `UNFINISHED_PINS`. `b` and `f` in `MapEdit.lua` follow
  that file's own use, accepted in an earlier review
  (`claude-addon-readability-pass-rg51s6-devedit.md:656`).
- **Comments** give the game reason:
  - Names.lua translating the learned line a second after login.
  - The shareable cache "wrapped in a table so an unknown (nil) one is
    kept too", because the Quests list asks on every frame of a group
    sliding open.
  - The scraper leaving NPC IDs off anything inside a dungeon, hence
    `mapEditUnits`.
  - A secret creature name on Forever.
- **No narration.** "Now" appears only in the sense of "at this moment"
  ("only those your skill allows now").
- **Nesting.** No function nests more than three levels.
- **Files.** Every addon file keeps `local _, ns = ...`; 4-space indents
  and LF throughout.

Lua 5.1 traps, looked for and not found:
- **`a and b or c`.** Every new use has a middle value that is never false
  or nil when the test holds:
  - `shareable and row.shareIcon:GetWidth() + SHARE.GAP or 0`
  - `self.markMuted and Theme.color.muted or Theme.color.text`
  - `spec.stepLabels and spec.stepLabels[value] or spec.label` (falls back
    to the label, as meant)
  - `pinnedHere[...] or false`
  - `ns.Data.mapEditUnits and ns.Data.mapEditUnits[instance.id] or {}`
- **`#` on holes.** `#f.units` and `#(map[level].pins or {})` are filled
  without holes.
- **Patterns.** No new string pattern is built from data.
- **`false` as a table key** (`NEXT_LEARNABLE_STEP[false]`) is valid Lua.
  `ShowStep` maps nil to false before indexing.

**Round 2 (`d94e3fd`).** I re-read in full every function the fixes touch:
- `LearnableTooltipText`, the `TOGGLES` spec and comment, `IsTaughtByTrainer`,
  `ShowStepTooltip`, `ShowStep`, `ToggleBox`, and `RB:Paint`'s count line.
- `Names.IsTrainerPart` with `SplitParts`/`JoinParts`, and `LearnedText`.
- `MapEdit:PickListedUnit`, `UpdatePalette` and `LayOutPalette`.
- `QuestLogShareable`/`FreshShareable`, and `DevDungeons.lua`'s `UNFINISHED_SPOTS`.
- The four smoke scenarios added or extended.

Sound:
- Names say what they do (`IsTrainerPart`, `ShowStepTooltip`,
  `LayOutPalette`, `label`).
- No comment narrates the change.
- The moved `LearnableTooltipText` keeps its comment.
- No nesting over three levels.
- 4-space indents, LF.

New: R9, the `tooltip` field's comment.

### WoW API

| Call / event / method / template / atlas | In Ketho's `forever` lists | Where checked |
| --- | --- | --- |
| `C_QuestLog.IsPushableQuest(questID)` (new) | yes | GlobalAPI.lua:3594; signature `isPushable = C_QuestLog.IsPushableQuest(questID)` per warcraft.wiki.gg |
| `C_QuestLog.IsOnQuest` (new caller in Data.lua) | yes | GlobalAPI.lua:3593 |
| `C_SpellBook.IsSpellKnown` (now via `RB:IsKnown`, newly asked of profession recipes) | yes | GlobalAPI.lua:4041 |
| `NEW_RECIPE_LEARNED` (new) | yes | Events.lua:1883 |
| `CheckButton:GetCheckedTexture` (new) | yes | WidgetAPI.lua:715 (under CheckButton) |
| `Texture:SetDesaturated`, `Texture:SetColorTexture` (new callers) | yes | WidgetAPI.lua:262, 261 (TextureBase) |
| `GameTooltip:IsOwned`, `SetOwner`, `AddLine`, `SetText`, `Show` | yes | WidgetAPI.lua:1204 and the GameTooltip block |
| `GameTooltip_Hide` | yes | FrameXML.lua:1870 |
| `wipe` | yes | GlobalAPI.lua:7090 |
| `socialqueuing-icon-group` atlas (new) | yes (29 × 26) | AtlasInfo.lua:7579 |
| `UICheckButtonTemplate` (existing, newly desaturated) | yes | Templates.lua:3772 |
| `PlayerModel:SetCreature`, `GetDisplayInfo` (existing lookup, newly reached from unit buttons) | yes | WidgetAPI.lua:813, 803 |
| `GameFontNormalSmall` (Units label) | yes | Templates.lua (as in v1.5.0's review) |

- **Combat.** None of the four calls blocked for every frame is added, and
  `CHECKED_COMBAT_CALLS` in `scenarios.lua` is unchanged in the range. The
  share icon passes clicks with `ns.UI.ClicksReachBeneath` (the "avoid"
  way), as the portal did. Nothing opens or switches the game's map. The
  Library links still go through `ns.UI.HoverMapLink`/`ShowOnMap`, with
  the in-combat fallback. The `--combat` run passed.
- **Secret values.** `IsPushableQuest` returns a boolean flag, not a
  title, so the code tests it without `issecretvalue` (inferred; quest
  titles are what Forever makes secret). The unit lookup's name comes
  through `Names:CreatureName`, which returns nil for a secret name
  (`Core/Names.lua:280-284`), and the scenario asserts a plain name. The
  `--secret` run passed.
- **Async data.** None new. A unit's model display is waited for with the
  existing bounded `C_Timer.After(0.5)` lookup (10 tries), not a tight
  loop.
- **Events.** `NEW_RECIPE_LEARNED` stays registered through `ns:On`, which
  has no way to unregister, as everywhere else. It returns at once unless
  a recipe list with Learnable on is shown. Not tested (R1).
- **Not verified in game (inference).** Whether `C_SpellBook.IsSpellKnown`
  answers true for a learned *tradeskill* recipe spell on Forever. The
  Poisons Known box used it before this range, and Mike designed
  Learnable around it (commit `8a5dbbe`), but no scenario can show it.
  If it answered false, Learnable would list every recipe, known ones
  included, at both steps.
- **No new globals.** `ns.UI.HintIcon`, `ns.Data.shareableCache`,
  `ns.Data.mapEditUnits` and `RB.LEARNABLE_*` all live on `ns`.
- **Lua limits.** See Checks: nothing near 60 upvalues or 200 main-chunk
  locals. `Overview.lua` is unchanged at 194.
- **Smoke mirrors.** `C_QuestLog.IsPushableQuest` is mirrored in
  `wow.lua:2386-2387` (`W.pushableQuests`). `GetCheckedTexture` and
  `SetDesaturated` were already there (`wow.lua:740`, `:499`).
  `wow.lua` defines nothing Forever lacks. Scenarios exist for: the share
  icon and level line (data and in-log answers), From trainer, Learnable's
  steps and tooltip, the Poisons chip, the Units row, the dev maps' pins
  and spots, the new dungeons' bosses and chains, and the Library tooltip.
  Missing: `NEW_RECIPE_LEARNED` (R1).
- **No nil guard removed.** The range adds one guard that isn't needed
  (R7).
- **Text.** All new player-facing text is literal `L["..."]`, and the
  English list is in sync. MapEdit's new strings ("Units", "Unit %d ·
  display %d", "On this level: picking it moves it") are English, like the
  rest of the dev-only palette.
- **Dev-only code.** `DevDungeons.lua` stays inside `#@debug@` in the
  `.toc` and is ignored by `.pkgmeta`, and so are `Media/Maps/Dev`'s
  tiles. `Data/Maps.lua`'s `santiagoMaps` is in `--@debug@`. The packaged
  run asserts that `mapEditUnits`, `santiagoMaps` and the four dev maps
  don't ship and that the three new dungeons do.
- **STYLE-GUIDE.** Updated in the same release, with values matching the
  code:
  - tick box half step: muted tick, no accent fill, accent outline;
    native desaturated (`Theme.lua:1137`, `:1153-1157`);
  - toggles row;
  - share icon: 20, 4 left of the portal or insignia (`SHARE`,
    `Lists.lua:1073`, `:1475`);
  - class badge order;
  - Quests list order and rule;
  - quest page level line;
  - Units row: label 14 in and 8 under the boss rows, buttons 16 under
    it, picker 8 after them, 40% dim (`MapEdit.lua:1185-1192`, `:1261`);
  - Poisons row;
  - Library book row and links.

  The only gaps are the wordings in R5 and R6.

**Round 2 (`d94e3fd`).**
- **No new game call, event, widget method, template, atlas or `Enum`.**
  `GameTooltip:SetOwner`/`AddLine`/`Show` and `FontString:GetText` (on
  `box.label`) were already used here and are in `WidgetAPI.lua`.
- **One nil guard removed** (`type(C_QuestLog.IsPushableQuest)`). It was
  checked against Forever's `GlobalAPI.lua:3594`, not against `wow.lua`.
- **Combat.** None of the four calls the game blocks in combat appears, and
  `CHECKED_COMBAT_CALLS` is unchanged. The `--combat` run passed.
- **Secret values.** `IsTrainerPart` compares a learned-line part, which is
  NeedRoll's own data, translated through `L`; it's not a secret value. The
  `--secret` run passed.
- **Smoke coverage.** `NEW_RECIPE_LEARNED` now has its scenario (R1).
- **Text and docs.**
  - Player-facing text: one label swapped to an existing key (R6);
    `locales.py --check` passes.
  - STYLE-GUIDE: the Poisons row updated. The R3 tooltip shows the same
    title and text as before, so no other row changes.

### Redundant code

Compared against:
- **Theme helpers.** `Theme:CheckBox` is extended, not copied.
  `Theme:FitAtlas` and `ns.UI.ClicksReachBeneath` are reused.
- **Overview.** `ns.UI.InsideIcon` now wraps the new `ns.UI.HintIcon`, so
  the portal and share icons are one widget, not two copies.
  `ns.UI.ForgetQuestStatus` clears the shareable cache with the other
  quest caches on the same four events, instead of a second event list.
- **Recipe band.** `ns.UI:RecipeNarrowed` and `RB:State` are reused.
  `RB:IsKnown` gives "known" one name for the band and the Poisons box.
  It is a one-line pass-through, kept so the call has one place to
  change (sound).
- **MapEdit.**
  - `LayOutButtonRows` takes the old boss-row loop and is shared by the
    boss and unit rows.
  - `MapEdit:ShowUnit` moves out of `LookUpUnit`'s closure so
    `PickListedUnit` can reuse it.
  - `CreateUnitButton` builds on `CreateBossButton`.
- **Library.** The wrapper `ZoneName` and the door branch are deleted, and
  `PetPageKit.ZoneName` is used directly.
- **Scraper.**
  - `start_droppers` and `_by_hand` replace three and two copies.
  - `_giver_notes` is shared by the QuestieDB path and the hand-kept path.
  - `FOREVER_QUESTS` moves to `quests.py` and is imported by `compare.py`,
    so it has one home instead of two.

Findings: R4 (the trainer word test in two places) and R7 (the alt-ID
walk copied, a needless guard).
- **Dead code: none.** `ZoneOf`'s `door` field and the removed tooltip
  line have no users left. `L["Inside %s..."]` is out of `enUS.lua`
  (translations.py lists it for removal).
- **Per frame.** No new `OnUpdate`, timer or debug print outside
  `@debug@`. The per-row `QuestShareable` call is cached until the log
  changes.

**Round 2 (`d94e3fd`).**
- `Names.IsTrainerPart` is now the one home of the trainer-word test (R4).
- The Learnable tooltip has one shower, `ShowStepTooltip` (R3).
- The R7 alt-ID walk stays as two loops, for the implementer's reason.
- **Dead code: none.** `ShowLearnableTooltip` is gone with no callers left
  (grepped). `L["Can learn"]` has no users and is out of `enUS.lua`.
  `LayOutBosses` has no callers in code.

### Security

Untrusted inputs and outputs this release touches:
- **Addon messages and chat.** None. `Core/Drops.lua` changes only two
  comments. No new `CHAT_MSG_ADDON` handling, sending, `PROBERS` keys,
  limits or replies.
- **No `loadstring`, `RunScript` or `setfenv`** anywhere in the diff.
- **Text from other players shown in the UI.** None. The new text is
  NeedRoll's own data, the game's own quest flag and NPC names from the
  data.
- **Names.**
  - Drop credits stay in `scraper/drops/credits.json`. `.pkgmeta` ignores
    `scraper`, and no credited name is in `NeedRoll/` (grepped; see
    Checks). The watcher imports' `by` fields stay in `scraper/` too.
  - The names the range adds to public-bound files are not players:
    - NPCs: Mason Connery, Commander Folkar, Zarla Ober and others.
    - Map artists, credited as before: Santiago Reyes, plus Nysha and
      PallBadguy for the sketches on the Alcaz map. That credit is in the
      dev-only file and is unchanged in this range.
    - The DungeonJournal addon's author, in `README.md`'s credits.
- **Third-party data.**
  - QuestieDB is still read at build time (`questFlags` is one more
    extracted field, `EXTRACT_VERSION` 5).
  - The DungeonJournal addon's facts are written by hand into
    forever.json and `new-instances/`. No file of either is in the repo
    (`git ls-files` shows only NeedRoll's own `questie*` scraper modules).
  - `DevDungeons.lua`, `AlcazPrison.lua` and the forever.json notes cite
    "Mike's saved Wowhead pages". They were read from disk, never fetched.
    No code path requests Wowhead: no `http`, `urlopen` or `requests` in
    the scraper diff, and `build --check` reads the retired cache only.
- **Scraper safety.** No `shell=True`, `eval` or `pickle` added. The new
  inputs (`npcNames`, `shareable`, `startItem`, `droppers`, `named`) are
  repo files Mike keeps, converted with `int()` and read as plain JSON. No
  path comes from data.
- **Workflows and tools.** None changed.
- **Data accuracy (not security, noted for Mike).** Two judgements in the
  data:
  - A Classic quest QuestieDB has with no `questFlags` is written
    `shareable = false`. The docstring bases that on the DungeonJournal
    list marking every such quest not shareable (`questie_quests.py`
    `shareable`). If it's wrong for one, its page says "Not shareable"
    until the player has it in their log, where the game's answer wins.
  - Goaz Scrolls' spot is pending Mike's confirmation (commit `94a6773`).

**Round 2 (`d94e3fd`).** Untrusted inputs or outputs touched: none.
- The fixes change only UI text, a dev-tool repaint, a shared string test
  and smoke scenarios.
- No messages, sending, SavedVariables or player names.
- The new smoke scenario uses the word "Lehrer" and NPC/spell IDs only.

## Round history

- Round 1, 2026-11-11, `660ed6a`: **Changes needed** (0 blocking, 1 should fix, 7 nits). Opened R1–R8.
- Round 2, 2026-11-11, `d94e3fd`: **Changes needed** (0 blocking, 0 should fix, 2 nits). Closed R1, R2, R3, R4, R6, R8, and R7 (the guard; the shared walk left as is). R5 left as is for Mike. Opened R9 (nit). Final round: Mike decides on R5 and R9; neither blocks the release.
- Addendum, 2026-11-11, `22a5e48` (PR #873, merged after round 2): **Changes needed** (0 blocking, 2 should fix, 4 nits). Opened R10–R15. See "Addendum: PR #873" below.
- Addendum round 2 (final), 2026-11-11, `45c7fe4` (the fixes commit on `e1e7955`): **Changes needed** (0 blocking, 1 should fix, 2 nits). Closed R10, R12, R13, R14, R15, and R11's code half (the login warning). R11's in-game check of `LoadSavedVariablesFirst` stays with Mike. Opened R16 (should fix: the R10 fix also translates the place names that stand in for game names, so on an English client with a language picked the Forever dungeons without a map ID take the picked language's name and NeedRoll stops recognising them when the player is inside), R17 (nit) and R18 (nit). Final round: Mike decides on R16–R18 and the in-game check.

## Addendum: PR #873

PR #873 ("Fonts as font families; a Language choice in Settings") merged
into dev after the two rounds above had closed, so this addendum reviews it
on its own. Findings continue from R10. R1–R9 and the verdict above are
unchanged.

| | |
| --- | --- |
| Branch | `660ed6a..22a5e48` (PR #873, `claude/project-thread-kwekos` into dev: commits `4aac2a9` "Fonts as font families; a Language choice in Settings" and `b595e24` "Ship the Classic dungeon map art in Media/Maps/Classic"), reviewed on `claude/project-thread-shl5wi` (= `origin/dev` `5406a14`) |
| Commit reviewed | Round 1: `22a5e48` (working tree clean apart from this Review Doc). Round 2: `45c7fe4`, "v1.6.0 review fixes for #873" on `origin/dev` `e1e7955` (only this Review Doc uncommitted) |
| Date | 2026-11-11 |
| Round | Addendum round 2 (final: Mike decides what's left) |
| Verdict | **Changes needed** (0 blocking, 1 should fix, 2 nits). Round 1's: (0 blocking, 2 should fix, 4 nits). Nothing blocks the release; see "Addendum verdict" |
| Needs | Players: a **full restart**. The `.toc` gains `## LoadSavedVariablesFirst: 1`, and 828 new texture files arrive under `Media/Maps/Classic`. The client reads `.toc` files and the addon folder's file list at startup (inferred, as in earlier reviews). A new Language pick then needs a `/reload`, and Settings offers one. Saved data: one new key, `NeedRollDB.language` (nil means "Game language"). No key is renamed. Round 2's fixes change only Lua files already in the `.toc` and add no saved key, so on top of PR #873 they need only a `/reload` (the release as a whole still needs the restart above). |

### What the change does

**A Language setting.** Settings, General gets a first row, "Language". A
box opens a menu: "Game language", a rule, then the 11 languages NeedRoll
has text in, each named in its own language (`ns.LANGUAGES`,
`Locales/Locales.lua:20-32`). A pick is saved in `NeedRollDB.language`, and
a dialog offers "Reload now" (`ReloadUI`) or "Later". `/nr language
<code|game>` does the same from chat. NeedRoll looks up about 560 phrases
while its files load. The `.toc`'s new `## LoadSavedVariablesFirst: 1`
therefore has the game load `NeedRollDB` before the files, so
`ns.Language()` can read the pick then. `ns.Phrases` fills `ns.L` for that
language instead of `GetLocale()`'s. The translation notice
(`UI/Welcome.lua`) follows the pick, so someone reading NeedRoll in English
isn't asked to help translate. Game names (NPCs, quests, zones) still follow
the client.

**Fonts as font families.** Every NeedRoll font is now built with
`CreateFontFamily`: one member per alphabet, as the game's own `Fonts.xml`
does. A character the client's font lacks then comes from another member.
The "·" NeedRoll writes between facts is missing from the Russian client's
`FRIZQT___CYR.TTF`, and the roman member now draws it. A picked Cyrillic,
Hangul or Chinese language also draws on any client. `Theme:ScaledFont`
rebuilds a family from a stored "recipe" (`fontRecipes`), where it used to
copy a font object.

**Classic map art shipped.** The ruRU, esMX and itIT clients don't have the
Wrath-era `interface/worldmap` tiles, so NeedRoll's maps of the Classic
dungeons and raids drew as solid green there. PR #873 copies the 828 enUS
tiles (69 levels × 12) into `NeedRoll/Media/Maps/Classic/<map>/`, keeping
their names. Each level in `Data/Maps.lua` now names the shipped path first
and keeps the game's file ID after it. `ns.UI.MapFloor` still matches the
game's own map to a level by that ID (`FloorsByArt` walks every set,
`UI/Overview.lua:1137-1152`).

### Scope

- `NeedRoll/NeedRoll.toc`: adds `## LoadSavedVariablesFirst: 1`.
- `NeedRoll/Locales/Locales.lua`: `ns.LANGUAGES`, `ns.LanguageCode`, `ns.Language`; `ns.Phrases` keys on `ns.Language()`.
- `NeedRoll/Locales/enUS.lua`: 8 new phrases, and the Settings button's tooltip phrase reworded (a new key, see Checks).
- `NeedRoll/Core/Init.lua`: `/nr language`.
- `NeedRoll/UI/Settings.lua`: the Language row, its menu and reload dialog. The box shared with the key binding row moves into `BoxRow`/`FitBox`, and the label tooltip into `AddLabelTooltip`.
- `NeedRoll/UI/Theme.lua`: font families (`ALPHABET_FILES`, `CLIENT_ALPHABETS`, `FontMembers`, `fontRecipes`, `FamilyFont`, `UsableFace`), `MakeFont` reworked, `Theme:ScaledFont` builds from recipes.
- `NeedRoll/UI/Welcome.lua`: `IsEnglishClient` becomes `IsTextInEnglish` (`ns.Language`).
- `NeedRoll/UI/MapEdit.lua` (dev tool): the language preview uses `ns.LANGUAGES` and `ns.Language()`.
- `NeedRoll/Data/Maps.lua` (hand-kept, its header says so, so reviewed as code): every Classic level gets its shipped tile path first; long lines wrapped.
- `NeedRoll/Media/Maps/CREDITS.txt`, `README.md`, `docs/LOCALIZATION.md`, `docs/STYLE-GUIDE.md`: credits, licence note, the language and font docs, the Language row, the font members table, map art.
- `NeedRoll/Media/Maps/Classic/**` (828 `.blp`): binaries not read. Checked: the header magic (`BLP2`), the names and that each is referenced (below), the size, and the packaging.
- Smoke: `wow.lua` (`CreateFontFamily`, `ReloadUI`), `run.lua` (sets `NeedRollDB` before the files when the `.toc` has the line), new `Locales-Locales.lua` and `Data-Maps.lua`, more scenarios in `Core-Init`, `UI-Settings`, `UI-Theme`, `UI-Welcome`. `Data-DevDungeons`, `UI-Overview` and `UI-WorldMapOverlay` were adjusted, and the tile-file check moved to `Data-Maps`.

### Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 8 changed addon Lua files and the 11 changed smoke files | passed |
| `luacheck --no-global -q`, each changed file at `22a5e48` vs `660ed6a`, warnings compared without line numbers | 1 new warning: `Settings.lua:603` is 161 chars (the Language tooltip's `L["..."]`). `Settings.lua:252` (the Settings button's tip) grew from 207 to 217 chars. Both are in R14. `Data/Maps.lua` went from 37 to 26 (lines wrapped). `Theme.lua` 75, `Init.lua` 9, `Welcome.lua` 3, `MapEdit.lua` 1, `Locales.lua` 0, `wow.lua` 99, `run.lua` 1: unchanged |
| `tests/smoke/check.sh` (all four runs: dev, packaged, secret values, in combat) | passed: exit 0, "all passed" in each (221 / 212 / 221 / 221 files loaded; 674 / 590 / 674 / 674 scenarios ok, 9 more each than round 2) |
| `python3 tools/locales.py --check` | passed (exit 0, no output) |
| `python3 tools/translations.py` (extra) | passed (exit 0). The old Settings tooltip ("Window style, UI scale, …") is now listed as unused in all 10 translation files, because its key changed to "Language, window style, …". Translated clients show the new tip, and the 7 other new phrases, in English until the Translations bot runs. That is expected for a reworded phrase |
| Lua 5.1 limits (extra, `luac5.1 -l -l`) | `Settings.lua` main-chunk locals 77 → 89, most upvalues in one function 10 → 11. `Theme.lua` 90 → 96, 8 → 8. `Locales.lua` 4 → 4. None near 200 / 60 |
| Map tiles (extra) | each of the 69 `CLASSIC .. "<map>\\<file>"` paths in `Data/Maps.lua` has all 12 tiles on disk, with the same case. All 828 files are referenced (none orphaned). `.pkgmeta` doesn't ignore `Media/Maps/Classic`, so they ship; the packaged smoke run's `Data/Maps` scenario checks that too. Size: 36 MB on disk; zipped, 24.8 MB. A zip of the shipped addon without them is 12.8 MB, so the release download roughly triples, to about 38 MB |
| Combat calls (extra) | the diff adds none of the four blocked calls and no `CHECKED_COMBAT_CALLS` spot. `ReloadUI` runs only from the "Reload now" click |
| `cd scraper && python3 -m unittest discover -s tests` | not run: PR #873 changes no scraper file |

Round 2, on `45c7fe4` (the files `git diff --name-only e1e7955 45c7fe4` lists):

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 7 changed addon Lua files (`Core/Init.lua`, `Core/Names.lua`, `Locales/Locales.lua`, `Locales/enUS.lua`, `UI/MapEdit.lua`, `UI/Settings.lua`, `UI/Theme.lua`) and the 4 changed smoke modules | passed |
| `luacheck --no-global -q`, each changed file at `45c7fe4` vs `e1e7955`, warnings compared without line numbers | no new warning. `Settings.lua`: the 217-char line is gone (the Settings tip's phrase now on its own line, 165 chars); the Language tooltip's phrase line stays at 161 (`:610`). Both are single `L["..."]` keys, which can't be split. Counts otherwise equal: `Init.lua` 9, `Names.lua` 3, `Locales.lua` 0, `enUS.lua` 55, `MapEdit.lua` 1, `Settings.lua` 10, `Theme.lua` 75, smoke modules 4 / 2 / 0 / 0 |
| `tests/smoke/check.sh` (all four runs: dev, packaged, secret values, in combat) | passed: exit 0, "all passed" in each (221 / 212 / 221 / 221 files loaded; 676 / 592 / 676 / 676 scenarios ok, 2 more each than round 1: the login warning and the English client with Deutsch picked) |
| `python3 tools/locales.py --check` | passed (exit 0, no output) |
| `python3 tools/translations.py` (extra) | passed (exit 0). It lists "Can learn" as unused in all 10 translation files; that phrase was already unused at `e1e7955` (`git grep` finds no `L["Can learn` outside the locale files at either commit), so it isn't from this change. The new login phrase shows in English on translated text until the Translations bot runs |
| Behaviour of `Core/Names.lua` before and after (extra) | a scratch Lua script loads `Names.lua` at `e1e7955` and at `45c7fe4` with stub game calls and runs PLAYER_LOGIN over three made-up instances (Hall of Thanes with no map ID, Blackrock Depths with map ID 230, a faction in zone "Blackrock Depths"), German phrases loaded. On a `deDE` client both versions write the same names. On an `enUS` client: `e1e7955` leaves all three English; `45c7fe4` gives "Die Halle der Thanen", "Blackrock Depths", zone "Schwarzfelstiefen" (R16) |
| `cd scraper && python3 -m unittest discover -s tests` | not run: no scraper file changed |

### Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R10 | should fix | Readability (§9) / behaviour | `NeedRoll/Core/Names.lua:24-25`, `:558-571`; `NeedRoll/UI/Settings.lua:603`; `docs/LOCALIZATION.md:26-31` | On an English client, a picked language leaves the data's fixed labels in English, though the setting says NeedRoll's notes change | fixed in round 2 (`45c7fe4`); the fix opened R16 |
| R11 | should fix | WoW API | `NeedRoll/NeedRoll.toc:9`; `NeedRoll/Locales/Locales.lua:45-50`; `docs/LOCALIZATION.md:17-21` | The feature rests on `LoadSavedVariablesFirst` in Forever, which nobody has checked in game, and fails silently if it's ignored | code half fixed in round 2 (`45c7fe4`: the login warning); the in-game check is left to Mike before tagging |
| R12 | nit | Redundant code | `NeedRoll/UI/Settings.lua:616` | The Language box hides a tooltip it never shows | fixed in round 2 (`45c7fe4`) |
| R13 | nit | Readability (§9) / behaviour | `NeedRoll/UI/Settings.lua:570-577` | "Reload now" is offered when the reload would change nothing | fixed in round 2 (`45c7fe4`); `/nr language` left behind, see R17 |
| R14 | nit | Readability (§1, §2, §8, §9) | `NeedRoll/UI/Theme.lua:488`, `:508`; `NeedRoll/Locales/Locales.lua:12`, `:35`; `NeedRoll/UI/Settings.lua:252`, `:603`; `docs/LOCALIZATION.md:17` | Names and lines: a "font" that is an alphabet's file, `f`, a "LanguageCode" that checks, two long lines, a count that will drift | fixed in round 2 (`45c7fe4`); two `L["..."]` lines over 120 left as is: a phrase key can't be split |
| R15 | nit | Readability (docs) | `README.md:70-93`; `NeedRoll/UI/MapEdit.lua:1395` | README's Settings list has no Language or `/nr language`, and a dev comment about missing fonts is out of date | fixed in round 2 (`45c7fe4`) |
| R16 | should fix | Readability (§9) / behaviour | `NeedRoll/Core/Names.lua:64-77`, `:238-258`; `NeedRoll/Data/Data.lua:1029-1034`; `README.md:72-73`; `docs/LOCALIZATION.md:31-34` | On an English client with a language picked, place names that stand in for the game's (the Forever dungeons without a map ID, a few zones) switch language, and NeedRoll stops recognising those dungeons from inside | fixed after round 2 (`13dab89`) |
| R17 | nit | Readability (§6, §9) | `NeedRoll/Core/Init.lua:856-870` | `/nr language` still promises a switch "after a /reload" when nothing would change, unlike Settings since R13 | fixed after round 2 (`13dab89`) |
| R18 | nit | Readability (§9) | `NeedRoll/Locales/Locales.lua:48-50`; `NeedRoll/UI/Welcome.lua:271-275`; `NeedRoll/UI/MapEdit.lua:990`, `:1413` | `ns.Language()` is still described as "the language NeedRoll's own text is in", which is now `ns.loadedLanguage`, and three callers read it with that meaning | fixed after round 2 (`13dab89`) |

#### R10 · On an English client, a picked language leaves the data's fixed labels in English
- **Severity:** should fix
- **Area:** Readability (§9, a tooltip and a doc saying what the code doesn't do), with a player-visible effect
- **Where:** `NeedRoll/Core/Names.lua:24-25`, `:558-571`; `NeedRoll/UI/Settings.lua:603`; `docs/LOCALIZATION.md:26-31`, `:61-63`
- **Status:** fixed in round 2 (`45c7fe4`), option (a). The fix also swept in place names that stand in for the game's: see R16

**What's wrong.** NeedRoll's own phrases in the data are translated in
`Core/Names.lua`, through `L`, by `Index()` at login. These include recipe
sources ("Trainer · Recipe", "Rank 2", "Cloth"), collection labels ("World
drops", "Item sets", "Holiday"), attunement notes and wing suffixes (": Graveyard").
`Index()` runs only when the *client* isn't English:

```lua
local LOCALE = GetLocale()
local isOtherLanguage = LOCALE ~= "enUS" and LOCALE ~= "enGB"
...
ns:On("PLAYER_LOGIN", function()
    ...
    if not isOtherLanguage then return end
```

PR #873 leaves this as it was. The new Language row's tooltip
(`Settings.lua:603`) promises "NeedRoll's own text (labels, buttons, notes,
tooltips) changes", and `LOCALIZATION.md:26` says "Only NeedRoll's own phrases
switch".

**Why it matters.** Take an English client with Deutsch picked. Buttons,
headings and tooltips switch to German. The labels in the lists and pages
stay English: a recipe's learned line reads "Trainer · Recipe", collection
groups read "World drops" and "Item sets", and the Onyxia attunement note is
English. `L` has German for all of these
(`PARTS`/`LABELS`/`NOTES`/`WINGS`, `Names.lua:30-158`). The player sees a
half-translated addon, which is exactly what the setting says won't happen.
The reverse case is fine: on a German client with English picked, `Index()`
runs, `L` is English, and only the game's own names stay German, as the
tooltip says.

**Evidence.** `Names.lua:24-25`, `:558-571` read in full. Every caller of
`Parts`, `LABELS`, `NOTES` and `WINGS` is inside `Index()`
(`Names.lua:223`, `:230`, `:236`, `:391-392`, `:403-420`). No UI file
translates `instance.name` or `encounter.note` itself
(`grep -rn 'L\[instance\.name\]\|L\[encounter\.note\]' NeedRoll/UI NeedRoll/Core`
finds nothing). `LOCALIZATION.md:63` says "English clients skip all of
this". No smoke scenario picks a language and then looks at a data label:
`Locales-Locales.lua` checks `L["Raids"]` only.

**Fix.** Either option works.
- (a) Split the two jobs `Index()` does. The cheap part translates the
  fixed labels and asks the server for nothing, so run it whenever
  `ns.Language() ~= "enUS"`. The part that asks the game for names stays
  behind the client check:

  ```lua
  local isOtherClientLanguage = LOCALE ~= "enUS" and LOCALE ~= "enGB"  -- game names to ask for
  ns:On("PLAYER_LOGIN", function()
      if ns.Language() ~= "enUS" then TranslateFixedLabels() end   -- L phrases only
      if not isOtherClientLanguage then return end
      ...                                                          -- server-filled names, as now
  ```

  Add a scenario: on an `enUS` client with `deDE` picked, a recipe's
  `learned` line reads "Lehrer · Rezept".
- (b) Keep the behaviour, and say so. The tooltip, and `LOCALIZATION.md`'s
  "Only NeedRoll's own phrases switch", would then name the data labels
  that stay in the client's language on English clients.

(a) matches what the setting promises. It's the better fix if Mike wants the
pick to be real on English clients.

**Round 2.** Fixed with option (a), in `Core/Names.lua` (read in full at
`45c7fe4`):
- PLAYER_LOGIN (`:615-628`) now returns early only for English text on an
  English client (`not isOtherClientLanguage and ns.loadedLanguage ==
  "enUS"`). Otherwise `Index()` runs a second after login. The fetch from the
  server (`LoadKeptNames`, `FetchGameNames`) still runs only on a client in
  another language.
- The game's own names are kept on an English client by two gates:
  `GameName(lookup, id)` (`:231-234`) returns nil there, for zones, factions,
  recipe spells and standings, and `TrackName` (`:276`) notes nothing. So no
  NPC or quest name is ever written over, and `cache` (nil on an English
  client) is never touched: only `FillOrQueueNames`, `KeepName` and
  `KeepQuest` read it, and `FetchGameNames` alone calls them.
- A wing is the label around `ZoneText(mapID)`, on an English client too
  (`:241-244`), so "Scarlet Monastery: Friedhof" with Deutsch picked. That
  mixes two languages, as noted, and mirrors a German client with English
  picked ("Scharlachrotes Kloster: Graveyard"). It is the rule the tooltip
  states.
- `Index()` ends with `namesChanged = true` (`:486`), so `Redraw()` makes
  search and tooltips forget what they built from the English data.
- The scenario asked for is there ("an English client with Deutsch picked
  translates only NeedRoll's labels", `Core-Names.lua`). It checks the learned
  line "Lehrer · Rang 2", an encounter label, a collection group, an object
  giver, a wing, and that names, zones, standings, bosses, sets, quests and
  BRD stay English, with nothing asked or saved. It also checks that English
  text on an `enGB` client rewrites nothing.

Non-English clients are unchanged: on a client in another language
`GameName` and `TrackName` behave as the old calls did. The only reordering
is in `InstanceName`: a wing whose `ZoneText` is nil now returns nil where
the old code went on to `factionID` and `LABELS`. No wing has either (no
`SM_*`, `DM_*`, `STRAT_*`, `LBRS`, `UBRS` name is a `LABELS` key), so the
result is the same. The German scenarios pass unchanged, and the scratch
comparison in Checks gives the same names on `deDE` at both commits.
`LOCALIZATION.md:31-35` and `:69-78` and the file's header are updated.

What the fix also did is R16: `LABELS` holds NeedRoll's own labels and, in
the same table, stand-ins for place names the game has no lookup for. Both
now follow the picked language on an English client.

#### R11 · The feature rests on `LoadSavedVariablesFirst` in Forever, which nobody has checked in game, and fails silently if it's ignored
- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/NeedRoll.toc:9`; `NeedRoll/Locales/Locales.lua:45-50`; `NeedRoll/Core/Init.lua:146-155`; `docs/LOCALIZATION.md:17-21`
- **Status:** fix 2 (a failure is no longer silent) fixed in round 2 (`45c7fe4`). Fix 1 (check in game on Forever) is left to Mike before tagging: no code can settle it, and `LOCALIZATION.md:21-22` still says "still to be checked in game"

**What's wrong.** The whole Language setting depends on the game loading
`NeedRollDB` before NeedRoll's files:

```lua
function ns.Language()
    local picked = type(NeedRollDB) == "table" and ns.LanguageCode(NeedRollDB.language)
    if picked then return picked end
    ...
```

PR #873's own doc says this isn't confirmed: "modern clients honour it;
whether WoW: Forever does is still to be checked in game"
(`LOCALIZATION.md:20`). If Forever ignores the directive, `NeedRollDB` is nil
while the files load, and `ns.Language()` falls back to the client's language
on every load. The Settings box still reads the saved pick ("Deutsch"),
because it reads `ns.db.language` after ADDON_LOADED. Nothing tells the
player.

**Why it matters.** The player picks Deutsch and presses "Reload now".
Every reload brings back English text, and Settings still says Deutsch. The
feature fails silently: there's no error to report, so the player is left
with a setting that seems broken. The smoke run can't catch this, because
`run.lua:105-107` sets `NeedRollDB` early whenever the `.toc` has the line.
It shows only what NeedRoll does when the game honours the directive, not
whether Forever does.

**Evidence.**
- `LoadSavedVariablesFirst` is a `.toc` directive, so none of Ketho's
  `forever` lists has it (grepped `GlobalAPI.lua`, `FrameXML.lua`: no match).
- warcraft.wiki.gg's TOC format page: "Set to 1 if SavedVariables file(s)
  should be loaded before all script files for this addon". It was added in
  11.1.5 (Modern). The page says Forever 1.60.1 "includes Modern changes up
  to 12.1.5". So support is **inferred**, not confirmed.
- `Init.lua:146-155` read: the ADDON_LOADED handler is the only writer of
  `NeedRollDB` (`NeedRollDB = NeedRollDB or {}`), and no file-scope code
  overwrites it (`grep -rn "NeedRollDB\s*=" NeedRoll`: only `Init.lua:148`).
  So the directive is safe to have even where it is honoured.
- The other load-time assumption is that every client has the font
  members' files. It is **inferred** sound: the game's own `Fonts.xml` on
  wow-ui-source's `forever` branch
  (`Interface/AddOns/Blizzard_Fonts_Shared/Shared/Fonts.xml`) builds 58
  families from the same five files on every client (`FRIZQT__.TTF` roman,
  `FRIZQT___CYR.TTF` russian, `2002.TTF` korean, `ARKai_T.ttf`,
  `blei00d.TTF`). The map art in this PR shows that some locales lack some
  files, so the ruRU "·" fix should be seen once on a ruRU client.

**Fix.**
1. Before tagging v1.6.0, check in game on Forever. On an English client,
   `/nr language dede`, `/reload`, and confirm the window is German. If you
   can, also check a ruRU client's "·" in a facts line. Then replace
   `LOCALIZATION.md:20`'s "still to be checked" with the result.
2. Make a silent failure visible. Record the language the files loaded in,
   and compare it once SavedVariables are in:

   ```lua
   -- Locales/Locales.lua, file scope (after ns.Language is defined)
   ns.loadedLanguage = ns.Language()

   -- Core/Init.lua, ADDON_LOADED, after ns.db = NeedRollDB
   local picked = ns.LanguageCode(ns.db.language)
   if picked and picked ~= ns.loadedLanguage then
       -- The game loaded NeedRoll's files before its saved settings
       -- (LoadSavedVariablesFirst not honoured), so the pick can't apply.
       ns:Print(L["NeedRoll couldn't switch its language on this client."])
   end
   ```

   `ns.loadedLanguage` is also what R13 needs.

**Round 2.** Fix 2 is in, as sketched:
- `Locales.lua:60`: `ns.loadedLanguage = ns.Language()`, at file scope.
  `Locales.lua` loads before every language file, so the value is fixed
  before any `ns.Phrases(locale)` call. `ns.Phrases` (`:88`, `:91`) now
  compares with `ns.loadedLanguage` instead of calling `ns.Language()` again.
  Within one load that is the same answer, and it can no longer change halfway.
- `Init.lua:758-766`: a PLAYER_LOGIN handler prints
  `L["NeedRoll couldn't switch to the language picked in Settings on this client."]`
  once, when `ns.KnownLanguage(ns.db.language)` is set and differs from
  `ns.loadedLanguage`. `ns.db` is set at ADDON_LOADED, before PLAYER_LOGIN.
  PLAYER_LOGIN fires once per load, and the pick can only change after it,
  so the line can't show for a pick made this session. A pick equal to the
  client's language loads the same text either way, and correctly prints
  nothing.
- The new scenario ("a picked language that didn't load says so at login")
  covers Deutsch saved with English loaded (printed) and English or nothing
  saved (not printed).
- `LOCALIZATION.md:23-26` names the message.

Fix 1 can't be done from code. Until someone runs `/nr language dede` and
`/reload` on a Forever client, whether Forever honours
`LoadSavedVariablesFirst` is still inferred. If it doesn't, players now get
a chat line instead of a setting that looks broken, which is the part this
review could ask for.

#### R12 · The Language box hides a tooltip it never shows
- **Severity:** nit
- **Area:** Redundant code (dead line)
- **Where:** `NeedRoll/UI/Settings.lua:616`
- **Status:** fixed in round 2 (`45c7fe4`): the line is deleted, and the box's `OnClick` (`Settings.lua:622-625`) only toggles the menu and refreshes

**What's wrong.**

```lua
box:SetScript("OnClick", function()
    GameTooltip:Hide()
    row.menu:SetShown(not row.menu:IsShown())
    row:Refresh()
end)
box:SetScript("OnEnter", function() box.bg:Show() end)
```

The box's `OnEnter` shows no tooltip. Only the row's *label* has one
(`AddLabelTooltip`), and that hides on its own `OnLeave` before the pointer
can reach the box. The `GameTooltip:Hide()` was carried over from the key
binding box, whose `OnEnter` does show a tooltip (`Settings.lua:510-514`).

**Why it matters.** It doesn't break anything. It makes a reader look for a
tooltip that isn't there, and it hides any other addon's tooltip that
happens to be up.

**Evidence.** `Settings.lua:600-630` read in full.

**Fix.** Delete the line. Or give the box the label's tooltip, which would
then make the line needed.

#### R13 · "Reload now" is offered when the reload would change nothing
- **Severity:** nit
- **Area:** Readability (§9, the dialog's words) / behaviour
- **Where:** `NeedRoll/UI/Settings.lua:570-577`; `tests/smoke/modules/UI-Settings.lua` ("going back to Game language didn't offer the reload")
- **Status:** fixed in round 2 (`45c7fe4`). `/nr language` still says "after a /reload" in the same cases: R17

**What's wrong.** `PickLanguage` compares the new pick with the *saved* pick,
not with the language the text is actually in:

```lua
if code == PickedLanguage() then return end
ns.db.language = code
...
page.reloadDialog:Open()
```

Two cases open a dialog saying "NeedRoll switches to the new language after
the interface reloads" when nothing would switch:
- On a German client, picking "Deutsch": nil becomes "deDE", and the text is
  German either way.
- Picking Deutsch, pressing Later, then picking Game language again before
  reloading.

**Why it matters.** It's a small thing. A player who follows the dialog
reloads for nothing.

**Evidence.** `Settings.lua:540-577` read. The smoke scenario asserts the
second case on purpose ("going back to Game language didn't offer the
reload").

**Fix.** Use the language the files loaded in (`ns.loadedLanguage`, from
R11's sketch):

```lua
local wouldShow = ns.LanguageCode(code) or ns.ClientLanguage()   -- client: GetLocale with enGB as enUS
if wouldShow ~= ns.loadedLanguage then page.reloadDialog:Open() end
```

Split the client half of `ns.Language()` into `ns.ClientLanguage()` so both
use it, and update the scenario's last assertion.

**Round 2.** `PickLanguage` (`Settings.lua:569-584`) now returns before the
dialog when `(code or ns.ClientLanguage()) == ns.loadedLanguage`. It also
closes a dialog still up from an earlier pick (`Theme:Dialog`'s `box:Close()`,
`Theme.lua:1780`). Both cases above now open no dialog: Deutsch on a German
client, and Game language picked again before reloading. A pick that would
change the text still opens it, including when the game ignored
`LoadSavedVariablesFirst`: `ns.loadedLanguage` is then the client's, so any
other pick offers a reload, as it should. The `or` has a non-nil right side,
so it isn't the `cond and nil or x` trap. `ns.ClientLanguage()` is split out
as suggested (`Locales.lua:43-47`). The scenario now checks: Game language
again (no dialog), English on an English client (no dialog), Deutsch (dialog).
The Language row in `docs/STYLE-GUIDE.md` says when the dialog opens and
when it closes.

#### R14 · Names and lines: a "font" that is an alphabet's file, `f`, a "LanguageCode" that checks, two long lines, a count that will drift
- **Severity:** nit
- **Area:** Readability (§1 names, §2 line length, §8 mental mapping, §9)
- **Where:** `NeedRoll/UI/Theme.lua:488`, `:508`; `NeedRoll/Locales/Locales.lua:12`, `:35`; `NeedRoll/UI/Settings.lua:252`, `:603`; `docs/LOCALIZATION.md:17`
- **Status:** fixed in round 2 (`45c7fe4`), but two lines are left as is. The implementer's reason: the two `L["..."]` phrase lines (`Settings.lua:253`, 165 chars; `:610`, 161) stay over 120 because a phrase key can't be split across lines without changing the key the translations use

**What's wrong.**
- `Theme.lua:488`: `for _, font in ipairs(ALPHABET_FILES)`. In this file
  `font` means a Font object (`Theme.font`, `ScaledFont(font, …)`), but this
  value is an `{ alphabet, file }` entry. Call it `alphabetFile` (or
  `member`).
- `Theme.lua:508`: `local f = CreateFontFamily(...)` in the new
  `FamilyFont`. `f` isn't one of the short names §8 allows. Use `font` or
  `family`. `MakeFont` and `ScaledFont` already used `f`, but this function
  is new.
- `Locales.lua:35`: `ns.LanguageCode(code)` returns `code` itself or nil, so
  the name reads like a conversion. It is a check: `ns.KnownLanguage(code)`
  says what it does.
- `Settings.lua:603` is a new 161-char line. `:252`, which the PR touched,
  grew from 207 to 217 chars. §2 asks new and touched lines to stay within
  120: put the phrase on its own line as an argument, as
  `ShowTooltip(box, …)` does at `:510-513`.
- `Locales.lua:12` and `LOCALIZATION.md:17` say "About 560 phrases". That
  count goes stale with the next release. "Hundreds of phrases" says the
  same thing and stays true.

**Why it matters.** Each one makes a newcomer stop and check: is this a font
or a file entry, does this convert or validate. A number in a comment
becomes wrong without anyone touching it.

**Evidence.** The lines read. The luacheck comparison in Checks.

**Fix.** As listed. None changes behaviour or a saved key.

**Round 2.**
- `Theme.lua:488-496`: the loop reads `alphabetFile` into `alphabet, file`.
- `Theme.lua:508-513`: `FamilyFont` names its font `family`.
- `Locales.lua:34-41`: `ns.KnownLanguage`, with a comment saying it checks.
  `grep -rn "LanguageCode"` over `NeedRoll`, `tests`, `docs` (reviews aside)
  and `README.md` finds nothing left.
- `Settings.lua:252-253`: the Settings tip's phrase is on its own line. The
  217-char line is now a 165-char line holding only the `L["..."]`. The
  Language tooltip (`:609-610`) was already written that way.
- `Locales.lua:12` and `LOCALIZATION.md:18`: "Hundreds of".

The leftover length is the key itself, and luacheck shows no new warning.
The reason holds: splitting `L["..."]` with `..` would stop
`tools/locales.py` from reading it as a literal key. Accepted.

#### R15 · README's Settings list has no Language or `/nr language`, and a dev comment about missing fonts is out of date
- **Severity:** nit
- **Area:** Readability (docs and comments)
- **Where:** `README.md:70-93`; `NeedRoll/UI/MapEdit.lua:1395`
- **Status:** fixed in round 2 (`45c7fe4`)

**What's wrong.**
- README's Settings section lists Window style (`/nr style`), Text size
  (`/nr text`), Minimap button (`/nr minimap`), Map in dungeons and Modules.
  The new first row, Language, and `/nr language` aren't there, although
  PR #873 edits README for the maps.
- `MapEdit.lua:1395`: "Korean and Chinese need their fonts, which other
  clients may lack". Since this PR, NeedRoll's fonts are families with
  Korean and Chinese members, so the language preview draws those scripts on
  any client that has the game's font files. Every client does, by
  inference (R11's evidence). `LOCALIZATION.md`'s wording was updated; this
  comment wasn't.

**Why it matters.** README is how players and Mike find commands. A stale
comment misleads whoever next works on the preview.

**Fix.** Add a "**Language**: Game language or one of 11, after a reload.
Also `/nr language`." bullet to README's list. Reword or drop the MapEdit
comment.

**Round 2.** `README.md:68-75` now lists Language first, with `/nr language`,
its arguments and the reload. The intro reads "applies without a `/reload`,
Language aside". `MapEdit.lua:1393-1396` now says Korean and Chinese draw on
any client because NeedRoll's fonts have a member for each alphabet. Both
fixed. README's "names from the game (items, places, …) stay in the game's
language" is what R16 is about.

#### R16 · On an English client with a language picked, place names that stand in for the game's switch language, and NeedRoll stops recognising those dungeons from inside
- **Severity:** should fix
- **Area:** Readability (§9: the setting's tooltip, README and `LOCALIZATION.md` say places stay in the game's language) / behaviour
- **Where:** `NeedRoll/Core/Names.lua:64-77` (`LABELS`' places), `:238-252` (`InstanceName`), `:254-258` (`ZoneName`); `NeedRoll/Data/Data.lua:1029-1034` (`IsPlayerInside`); its callers `NeedRoll/Core/Drops.lua:258-281`, `NeedRoll/UI/Overview.lua:1199-1216`; `README.md:72-73`; `docs/LOCALIZATION.md:31-34`; `NeedRoll/UI/Settings.lua:610`
- **Status:** fixed after round 2 (`13dab89`): the place stand-ins moved to a `PLACES` table behind the `GameName` check, so they stay English on English clients; new smoke scenario (Hall of Thanes stays English and `IsPlayerInside` still finds it). Verified by the release thread with the smoke runs, not by a third review round.

**What's wrong.** `LABELS` (`Names.lua:64-127`) holds two kinds of entry.
Most are NeedRoll's own labels ("World drops", "Tier Sets", "Trash Drops").
Some stand in for **place names the game has but NeedRoll can't look up**:
the zones "Blackrock Mountain", "Mount Hyjal", "Dalaran", "Yojamba Isle",
"Blackrock Depths", and the block the file itself labels "WoW: Forever
instances still without a map ID in Data/Maps.lua (a map ID wins)": "Hall of
Thanes", "Ruins of Lordaeron", "Hyjal Summit", "Alcaz Prison" and the rest.
On a client in another language that is how those places get translated at
all. Since `45c7fe4` they also run on an English client with another
language picked. `InstanceName` protects an instance that has a map ID:

```lua
-- The game names an instance it has a map for, so on an English client
-- the data's name stays, even where a label has the same words.
if mapID and not isOtherClientLanguage then return nil end
...
return LABELS[instance.name]
```

An instance *without* a map ID falls through to `LABELS[instance.name]`, and
`ZoneName` returns `LABELS[zone]` with no client check at all.

**Why it matters.** Take an English client with Deutsch picked, after the
reload:
- The Dungeons list shows "Die Halle der Thanen" and "Ruinen von
  Lordaeron", and the Raids list shows "Hyjalgipfel", among dungeons and
  raids that are all English ("The Deadmines", "Blackrock Depths"). The quest
  right under them still says "Enter the Hall of Thanes beneath Old
  Ironforge", because quest text is the game's. The Thorium Brotherhood's
  zone line reads "Schwarzfelstiefen", while the Blackrock Depths entry stays
  English. The Language tooltip (`Settings.lua:610`), README (`:72-73`) and
  `LOCALIZATION.md:31-34` all say places stay in the game's language.
- Worse, NeedRoll stops knowing when the player is in those dungeons. An
  instance without a map ID is found **by name**: `IsPlayerInside`
  (`Data.lua:1029-1034`) compares `instance.name:lower()` with
  `GetInstanceInfo()`'s name. The game says "Hall of Thanes", and the data
  now says "Die Halle der Thanen", so no match. Two things follow inside Hall
  of Thanes, Ruins of Lordaeron, Alcaz Prison and the other new dungeons:
  - The in-dungeon map's name fallback (`Overview.lua:1199-1216`) can't find
    the instance. These maps are NeedRoll's own art (`SR ..` paths), so
    `MapFloor`'s match by the game's art file ID can't find them either.
  - `Drops.lua`'s `IsListedInstance` (`:258-268`) returns false, so
    `InUnlistedInstance()` is true for a dungeon NeedRoll lists. Drop
    tracking then treats rare and elite trash as boss candidates
    (`IsBossCandidate`, `:322-327`, used at `:1425`, `:1581`, `:1594`) and
    records their loot as boss drops. With Share drops on, these drops are
    also shared.

  Before `45c7fe4` an English client never rewrote `instance.name`, so all
  of this worked there whatever language was picked. (On a client in another
  language, matching by name already fails. `Data/Maps.lua:878-879` says so:
  "they go by their English name, which only works on English clients".
  That's unchanged.)

**Evidence.**
- `Names.lua:238-258` and `:615-628` read in full. `Data/Maps.lua:880-890`:
  `HALL_OF_THANES`, `RUINS_OF_LORDAERON` and `HYJAL_SUMMIT` have no entry in
  `RegisterInstanceMapIDs`.
- `deDE.lua` has "Die Halle der Thanen", "Ruinen von Lordaeron",
  "Hyjalgipfel", "Schwarzfelstiefen" and "Der Schwarzfels" for those keys
  (grepped).
- A scratch script (see Checks) loaded `Names.lua` on an `enUS` client with
  German loaded. At `45c7fe4` it wrote "Die Halle der Thanen" and the zone
  "Schwarzfelstiefen", and kept "Blackrock Depths" for the instance with map
  ID 230. At `e1e7955` it left all three English.
- The new smoke scenario's data has no instance without a map ID and no zone
  that is a `LABELS` key, so it doesn't catch this.
- The effect on `IsPlayerInside` and the drop tracking is read from the
  code, not run in game (inferred).

**Fix.** Keep the place stand-ins apart from NeedRoll's own labels, and let
them through only where the game's names are asked for, on a client in
another language:

```lua
-- Places the game names but has no lookup for (no map ID yet): its name
-- in the client's language, so only translated on a client in another one.
local PLACES = {
    ["Blackrock Mountain"] = L["Blackrock Mountain"], ["Mount Hyjal"] = L["Mount Hyjal"],
    ["Dalaran"] = L["Dalaran"], ["Yojamba Isle"] = L["Yojamba Isle"],
    ["Blackrock Depths"] = L["Blackrock Depths"],
    ["Hall of Thanes"] = L["Hall of Thanes"], ...   -- the "without a map ID" block
}

local function PlaceName(name)
    return PLACES[name]
end

-- InstanceName, after the factionID line:
if PLACES[instance.name] then return GameName(PlaceName, instance.name) end
return LABELS[instance.name]
-- ZoneName, likewise:
if PLACES[zone] then return GameName(PlaceName, zone) end
```

Keep the `if mapID and not isOtherClientLanguage` line. Without it, an
English client would take `GetRealZoneText`'s English name over the data's,
and the two needn't be written alike. Add the case to the
English-client scenario: a dungeon with no map ID named "Hall of Thanes",
and a zone "Blackrock Depths", both stay English with Deutsch picked. On a
client in another language with English picked, these places still show the
English label (that was so before this round, and only the game could do
better). If that is accepted, `LOCALIZATION.md` should say so in a line.

#### R17 · `/nr language` still promises a switch after a reload when nothing would change
- **Severity:** nit
- **Area:** Readability (§6 one way of doing each thing, §9 a message saying what won't happen)
- **Where:** `NeedRoll/Core/Init.lua:856-870` (`commands.language`)
- **Status:** fixed after round 2 (`13dab89`): `/nr language` says "NeedRoll's text is already in %s." when nothing would change.

**What's wrong.** R13's fix taught Settings' `PickLanguage` when a reload
changes nothing: `(code or ns.ClientLanguage()) == ns.loadedLanguage`. The
slash command does the same job and doesn't check:

```lua
if arg == "game" then
    ns.db.language = nil
    ns:Print(L["NeedRoll's text follows the game's language after a /reload."])
    ...
        ns:Print(L["NeedRoll's text switches to %s after a /reload."]:format(language.name))
```

**Why it matters.** On an English client, `/nr language enus` prints
"NeedRoll's text switches to English after a /reload." The text is English
already. Settings says nothing in the same case. It's harmless, but the same
pick is answered two ways.

**Evidence.** `Init.lua:853-877` read; `Settings.lua:569-584` read.

**Fix.** Put the test in one place, for example
`ns.LanguageNeedsReload(code)` in `Locales.lua` returning
`(ns.KnownLanguage(code) or ns.ClientLanguage()) ~= ns.loadedLanguage`. Use it in
`PickLanguage`, and in `commands.language` to print a short "already in
%s" line (a new phrase) instead of the reload one.

#### R18 · `ns.Language()` is still described as the language the text is in, which is now `ns.loadedLanguage`
- **Severity:** nit
- **Area:** Readability (§9 disinformation)
- **Where:** `NeedRoll/Locales/Locales.lua:48-50`; `NeedRoll/UI/Welcome.lua:271-275`; `NeedRoll/UI/MapEdit.lua:990`, `:1413`
- **Status:** fixed after round 2 (`13dab89`): the comment is corrected and the three callers read `ns.loadedLanguage`.

**What's wrong.** Round 2 added `ns.loadedLanguage`, "the language this
session's phrases loaded in". `ns.Language()` reads `NeedRollDB.language`
live, so after a pick it returns the pick, and it returns the pick when the
game ignored `LoadSavedVariablesFirst`. `LOCALIZATION.md:14-16` now calls it
"the language picked (else the client's)". Its own comment still says:

```lua
-- The language NeedRoll's own text is in: the one picked in Settings
-- (NeedRollDB.language, read before ns.db exists), else the client's.
```

Three callers use it to mean the text's language:
- `Welcome.lua:271-275` `IsTextInEnglish` ("Whether NeedRoll's own text is
  in English").
- `MapEdit.lua:990` and `:1413`, which mark the current language in the dev
  preview.

**Why it matters.** Mostly the reader: there are now two "which language"
values, and the comment points at the wrong one. One player-visible edge:
on a German client with English picked, where the game ignored the
directive (R11's case), the text is German but `IsTextInEnglish()` is true.
The "Help translate NeedRoll" notice is then skipped for someone reading
German. That's harmless, and inferred from the code.

**Fix.** Reword the comment to "The language picked in Settings
(NeedRollDB.language, read before ns.db exists), else the client's: what
the text loads in at the next reload". Have `IsTextInEnglish` and MapEdit
read `ns.loadedLanguage`. `ns.Language()` then has no caller in the addon
outside `Locales.lua`, only in the smoke tests (`Locales-Locales.lua`), so
keeping it on `ns` for them is fine.

### Area notes

#### Readability

Read in full: `commands.language` (`Init.lua:843-862`); `Locales.lua:1-100`;
`Settings.lua:343-375` (`AddLabelTooltip`, `BoxRow`, `FitBox`), `:485-630`
(`KeyRow`, the Language section), `:660-692` (`AddOptionRow`, `BuildGeneral`),
`:886-895`; `Theme.lua:430-665` (skins, font families, `MakeFont`,
`BuildFonts`, `LoadSkin`, `ScaledFont`); `Welcome.lua:258-300`; the
`Data/Maps.lua` header and table; `MapEdit.lua:985-1000`, `:1389-1420`.

Sound:
- The key binding row and the Language row now share `BoxRow`/`FitBox`, and
  `AddOptionRow` and the Language row share `AddLabelTooltip`. That is one
  way of doing each thing (§6).
- `PickLanguage`, `CreateLanguageMenu` and `CreateReloadDialog` each do one
  job, with no nesting past two levels.
- The new comments say why: the 560 lookups at load, the green
  missing-texture tiles, the Russian font's missing "·".
- 4-space indents, LF endings, `local _, ns = ...` in every changed addon
  file.
- No Lua 5.1 traps. `type(NeedRollDB) == "table" and ns.LanguageCode(...)`
  is false or nil before the `if`, and `client == "enGB" and "enUS" or
  client` has a non-nil middle term.
- The language names in `ns.LANGUAGES` are endonyms on purpose, not `L`.
  Every new player-facing phrase is a literal `L["..."]` in `enUS.lua`
  (`locales.py --check` passed).
- `docs/STYLE-GUIDE.md` is updated for the Language row, the font members
  and the map art. Spot-checked against code: `ROW = 30`
  (`Settings.lua:22`), box height 20 (`:364`), `LANGUAGE_MENU_WIDTH = 200`,
  dialog 360 × 140, menu 4 under the box (`:583`), hint in `small`
  (`Theme.lua:1754`).

Round 2, read in full at `45c7fe4`: `Core/Names.lua` (all of it, 628
lines), `Locales.lua:1-100`, `Init.lua:740-770` and `:853-877`,
`Settings.lua:540-640`, `Theme.lua:480-515`, `Welcome.lua:262-330`,
`MapEdit.lua:985-995` and `:1390-1420`, and the four changed smoke modules.

Sound:
- `GameName`, `StandingName`, `LoadKeptNames` and `FetchGameNames` each do
  one job, with a comment that says why. The PLAYER_LOGIN handler is now
  three guard lines and a timer, where it was a 20-line block.
- `isOtherClientLanguage` says what it is, with a one-line why. Its five
  uses read plainly.
- The new comments explain rather than narrate. No "now" or "updated" in
  code comments.
- No Lua 5.1 traps: `base and wing:format(base)` and `code or
  ns.ClientLanguage()` have non-nil middle or right terms. There's no `#t` on
  holes and no pattern built from data.
- 4-space indents and LF endings (`git diff --check e1e7955 45c7fe4` clean
  for code). `local _, ns = ...` is unchanged in each file.
- `STYLE-GUIDE.md`'s Language row describes the R13 behaviour. It's the
  only UI change; the dialog's sizes are unchanged.

Not sound: R16 (a doc promise the code breaks for place labels), R17 (one
check done in one of its two places) and R18 (a comment that now names the
other value). In `InstanceName`, two `local base` in sibling scopes
(`:242`, `:248`) is legal and reads fine; not flagged.

#### WoW API

| Call / event / directive the change adds or newly calls | In Ketho's `forever` lists | Where looked |
| --- | --- | --- |
| `CreateFontFamily(name, members)` | yes | `GlobalAPI.lua:5148`. Signature from Ketho's `FontDocumentation.lua`: `members` is `CreateFontFamilyMemberInfo[]` (`alphabet`, `file`, `height`, `flags`). The alphabet strings NeedRoll uses ("roman", "russian", "korean", "simplifiedchinese", "traditionalchinese") are exactly Ketho's `FontAlphabet` alias (`UIType.lua:25-30`). The wiki lists it for Forever 1.60.1, with the predicate "AllowedWhenUntainted", about secret arguments; NeedRoll passes none (inferred harmless) |
| `CreateFont` (now also for the ElvUI face probe) | yes | `GlobalAPI.lua:5147` |
| `GetLocale` | yes | `GlobalAPI.lua:5560` |
| `ReloadUI` | yes (FrameXML wrapper of `C_UI.Reload`, `GlobalAPI.lua:4720`) | `FrameXML.lua:3571`. The wiki marks `C_UI.Reload` restricted with `#hwevent`. NeedRoll calls it only from the "Reload now" button's click, which is a hardware event. Not combat-blocked (the wiki states no combat restriction) |
| `GameTooltip_Hide` | yes | `FrameXML.lua:1870` |
| Font methods `SetTextColor`, `SetShadowColor`, `SetShadowOffset`, `GetFont`, `SetFont` | yes | `WidgetAPI.lua` (`FontInstance`, inherited by `Font`) |
| Frame/region methods `EnableMouseMotion`, `HookScript`, `SetAllPoints`, `SetShown`, `IsMouseOver`, `RegisterForClicks`, `GetStringWidth` | yes | `WidgetAPI.lua` (one match each) |
| `GLOBAL_MOUSE_DOWN` (through `Theme:Menu`, not new) | yes | `Events.lua:1811` |
| `## LoadSavedVariablesFirst: 1` (`.toc` directive) | not in any list (it isn't an API) | warcraft.wiki.gg TOC format: added 11.1.5; Forever 1.60.1 includes Modern changes up to 12.1.5, so **inferred** supported. See R11 |
| Addon textures by path (`Interface\AddOns\NeedRoll\Media\Maps\Classic\...\*.blp`) | inferred (standard `Texture:SetTexture` with a path) | the files are `BLP2` (header read) |

Also checked:
- No removed globals are used.
- No new Lua globals are assigned. The game makes font names global, as
  before: `NeedRollFont*`, `NeedRollScaledFont*`, and the new
  `NeedRollFontProbe<skin>`, made only for a skin with a `fontFace`
  (ElvUI).
- No secret values are touched.
- No protected frames, no combat-blocked calls. `--combat` passed.
- `wow.lua` mirrors `CreateFontFamily`, erroring on a duplicate name as a
  strict stand-in, and `ReloadUI`. Both exist in Forever, so the stand-in
  defines no old global.
- Each new feature has scenarios: Language row, `/nr language`, ns.Language,
  locale loading in released and dev builds, the translation notice, the
  font members on ruRU and for ElvUI, ScaledFont families, every map tile
  on disk and in the zip.
- No dev-only code outside `--@debug@`.
- Locale override approach: Forever has no API to change an addon's locale.
  NeedRoll chooses which of its own phrase files fills `ns.L`
  (`ns.Phrases`), which is plain Lua and needs nothing beyond
  `GetLocale` and the `.toc` directive.

Round 2: `45c7fe4` adds no game function, event, widget method, template,
atlas or `Enum`. It calls only these, all used by NeedRoll already:

| Call / event | In Ketho's `forever` lists | Where looked |
| --- | --- | --- |
| `GetLocale` (`Locales.lua:45`, `ns.ClientLanguage`) | yes | `GlobalAPI.lua:5560` (round 1) |
| `PLAYER_LOGIN` (a second handler in `Init.lua`) | yes | `Events.lua` (an event NeedRoll already registers) |
| `GetRealZoneText`, `C_Map.GetMapInfo`, `C_Reputation.GetFactionDataByID`, `C_Spell.GetSpellName` (`Names.lua`, unchanged calls, now behind `GameName` or the wing case) | yes, already used | not newly called, so not re-grepped |
| `C_Timer.After`, `C_Timer.NewTicker` (moved into `FetchGameNames`) | yes, already used | as above |
| `FACTION_STANDING_LABEL1-8` (global strings, moved into `StandingName`) | inferred, as before | unchanged |

Also checked:
- **Combat.** The English-client path adds no ticker and no ask of the
  server. `Index()` is a table walk one second after login, as on other
  clients. No blocked call is added. `--combat` passed.
- **Events.** The new PLAYER_LOGIN handler fires once per load, as the
  existing ones do (`ns:On`).
- **Smoke stand-in.** No new game call, so `wow.lua` needs nothing.
- **Async data.** On an English client `FillOrQueueNames` (`ns.Items:Load`
  for item names) doesn't run, so nothing waits on item data there.
- **Text.** The one new player-facing string is a literal `L["..."]` in
  `enUS.lua:44`; `locales.py --check` passed.
- **Dev-only code.** `namesTest` stays inside `--@debug@`
  (`Names.lua:616-619`).

#### Redundant code

Compared against:
- `Theme:Menu`, `Theme:Dialog` (with `AddHint`, `Buttons`, `cancel:SetLabel`)
  and `Theme:Text`, which the Language row uses rather than copying.
- The Settings file's own `ColumnRow`, `ShowTooltip` and
  `Theme:Rounded`.
- `ns.LANGUAGES`, which replaces MapEdit's private `LANGUAGES` list.

The PR removes duplication:
- `BoxRow`/`FitBox` and `AddLabelTooltip` replace copied blocks.
- The tile-file check moved from `Data-DevDungeons` to `Data-Maps` rather
  than being copied.

Not flagged:
- Gnomeregan 1's and the four Scarlet Monastery levels' 12-ID tables now
  feed only `MapFloor`, which reads tile 1 (`Overview.lua:1144`), unless the
  shipped tiles go missing. They are kept: writing just the first ID as a
  number would claim the rest are numbered in order, which they aren't.
- Shipping the art for every client (about 25 MB zipped, the zip about 3×)
  when three locales lack it: the game draws a missing file ID as green
  without saying it failed. That's inferred from the PR's description of
  the bug, because `LoadTiles` (`Overview.lua:1089-1098`) falls back only
  when `SetTexture` returns false. So NeedRoll can't tell which clients need
  the copies. The size is Mike's call, noted here so it isn't a surprise on
  CurseForge.

R12 is the one dead line.

Round 2:
- R12's line is gone.
- `FetchGameNames` and `LoadKeptNames` are the old login block split, not
  copies of it.
- `GameName` replaces five client checks with one.
- `ns.ClientLanguage()` is now shared by `ns.Language()` and
  `PickLanguage`.
- The test `(code or ns.ClientLanguage()) == ns.loadedLanguage` is written
  once, but `/nr language` doesn't use it (R17).
- No new helper duplicates one in `Theme.lua`.
- No dead code: `GameName`, `StandingName`, `LoadKeptNames` and
  `FetchGameNames` each have callers (grepped). `cache` stays nil on an
  English client and nothing there reads it.

#### Security

Untrusted inputs or outputs touched:
- None from other players: no addon messages, chat, sending, or credits.
- `/nr language <arg>`: the player's own typing, lower-cased by the
  dispatcher (`Init.lua:971`) and matched against the fixed `ns.LANGUAGES`
  list. Anything else only prints the list.
- `NeedRollDB.language` is read at file load through `ns.LanguageCode`,
  which accepts only a code in `ns.LANGUAGES`. A hand-edited value can't
  pick a file or a string.
- The smoke modules' `loadstring`/`loadfile` load repo files only.
- No player names appear in the change: the BLP names are Blizzard's map
  names, and the `CREDITS.txt` names were already there.

Outside the four areas, for Mike: the Classic tiles are Blizzard's art
redistributed in the release zip. `CREDITS.txt` and README say it isn't
under the GPL. Whether CurseForge's rules are fine with shipping it is
Mike's call.

Round 2: no untrusted input or output.
- The login line is a fixed phrase.
- `ns.db.language` passes through `ns.KnownLanguage` before any use.
- An English client neither asks the server for names nor writes
  `NeedRollDB.names`.
- No sending, chat or credits. No player names in the change.
- R16's drop-tracking effect is about data quality (trash recorded as boss
  drops), not about trust. Such drops reach the drop pipeline only through
  the existing Share drops path and its limits.

### Addendum verdict

**Changes needed** (0 blocking, 2 should fix, 4 nits). Nothing breaks: all
four smoke runs pass, every map tile is present and shipped, and every game
call is in Ketho's `forever` lists. Before tagging v1.6.0:
- Settle R11 in game, so the Language setting is known to work in Forever.
- Settle R10, so the setting does what its tooltip says on English clients,
  or the tooltip is narrowed to match.

R12–R15 are small and can ride along or wait.

**Round 2 (final): Changes needed** (0 blocking, 1 should fix, 2 nits).
`45c7fe4` fixes R10, R12, R13, R14 and R15. It fixes R11's code half: a pick
that didn't load now says so at login. All four smoke runs pass, with
scenarios for each fix. Non-English clients behave as before (read, and
compared by script). Left, for Mike to decide:
- **R16 (should fix):** the R10 fix also translates the place names that
  stand in for the game's. An English client with a language picked then
  shows the Forever dungeons without a map ID, and a few zones, in the
  picked language. Worse, it no longer recognises those dungeons when the
  player is inside: no map by name, and trash drops counted as boss drops.
  The fix is a separate `PLACES` table behind the existing `GameName` gate.
  It is small, and better done before tagging, since English clients are
  most players.
- **R11's in-game check:** `/nr language dede` and `/reload` on a Forever
  client, then update `LOCALIZATION.md:21-22`.
- **R17, R18 (nits):** `/nr language`'s reload message, and
  `ns.Language()`'s comment and its three callers. They can ride along or
  wait.
