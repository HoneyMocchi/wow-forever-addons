# Review: v1.7.0 release (everything merged into dev since v1.6.0)

| | |
| --- | --- |
| Branch | `v1.6.0..origin/dev` (`81c9e3e3..09ec5966`, PRs #880–#893), reviewed on `claude/project-thread-wfiq24` (round 1: = `origin/dev`; round 2: plus the seven fix commits `09ec5966..ad43fd19`) |
| Commit reviewed | Round 1: `09ec5966`. Round 2: `ad43fd19` (only this Review Doc uncommitted) |
| Date | 2026-11-11 |
| Round | 2 (final: at most two rounds, then Mike decides what's left) |
| Verdict | **Changes needed** (0 blocking, 0 should fix, 2 nits). Nothing blocks the release: R1, R2, R3, R5, R7 and R8 are fixed (R8's zhTW part was already right in NeedRoll-Locales); R4 is Mike's decision; R6 is partly fixed; R9 (new) is a header wording nit |
| Needs | Players: a `/reload`. No file is added to or removed from the `.toc` or `Data/Data.xml` (neither changes in the range), so nothing needs a full restart (inferred, as in earlier reviews). The remembered folds are new keys inside the existing `NeedRollDB.sections` sets (`"bosses"`, `"trainers"`, `"instances"`, `"spells"`, `"hunterPets"`, `"warlockPets"`, `"professions"`, `"library"`). The loot area keeps its old meaning (`true` = shut), so players' saved loot sections still load. Dev builds also save `NeedRollDB.questOffers` (chain clues). |

## What the change does

**Professions list, filter and Have materials (PR #881, #882, #883).** The
Professions tab now lists the professions the character knows first. Its
primary professions come first, then Cooking, First Aid and Fishing, then
the rest; each block keeps the data's order. The order is redrawn only when
`SKILL_LINES_CHANGED` moves a profession from one block to another.
"Filter recipes" now also matches material names, which the game sends by
item ID in the client's language. It also tries the last word made singular
("copper bars" finds Copper Bar). When a material's name arrives late, the
filter runs again. The recipe band gets a fifth tick box, "Have materials",
with three steps: off, then materials in bags and bank (a greyed tick), then
bags only (a full tick). With it on, bag and bank changes narrow the list
again.

**Remember every fold (PR #884).** Every open/shut state now lasts as
Settings' "Remember sections" says, where before it was per page or per
session:
- the loot pane's boss folds (by NPC ID);
- the "N more trainers" lists;
- Classic Raids;
- spell and pet ability ranks;
- each profession's Overview folds;
- the Library folds.

`ns.SectionMemory.IsOpen` and `Toggle` are new. Search results carry
`bossFold` instead of `fold`, which fixes an error found in the locale
sweep.

**Every client's language (PR #885, #887).**
- On a Russian client, or with NeedRoll's text in Russian, the separator
  dot draws as "∙" (`ns.DOT`, `ns.WithDots`), since `FRIZQT___CYR.TTF` has
  no "·".
- The map pin macro uses the client's own `/mappin` name (`SLASH_MAPPIN1`).
- `ns.GameTextPatterns` reads the game's own lines in every client's
  grammar, including Korean particles and Russian plurals. It serves the
  bounced-whisper line and the set bonus lines.
- `OtherClassOnly` splits the "Classes:" line on the client's own list
  separators.
- New Locale tests run the whole smoke suite as each of the 11 clients. They
  use the game's strings and a font coverage table committed under
  `tests/smoke/locales/`, written by `tools/locale_strings.py` and
  `tools/font_coverage.py`, and a CI workflow runs them.

**Loot pages: a Professions section (PR #888, #893).** Recipe items get
their own section between Accessories and Consumables, grouped by the
profession they teach (`Enum.ItemClass.Recipe`, sorted by subclass). It
starts shut.

**Whispered probe answers (PR #889).** A probe whispered by a PROBERS
character now gets up to 400 answers (was 25), 30 s apart. Any other
message still waits 60 s after the one before. `OUTBOX_MAX` goes from 300
to 500.

**Dungeon recipe bands (PR #890).** Forever's new dungeon recipes drop from
every dungeon boss in a level band. `scraper/professions/recipe_bands.json`
holds the five bands, and `recipebands.py` places them. 2256 loot lines were
written by hand into 23 `Data/Dungeons/*.lua` files, and
`test_recipe_bands.py` checks them against the placements. The 33
vendor-only recipes lose their drops in `RecipeSources.lua`.

**Chain clues (PR #891).** Dev builds note two clues in the quest log:
- the next quest the game offers by itself right after a hand-in;
- quests newly offered at an NPC since the character's last visit, with the
  hand-ins in between as candidates.

`ingest` folds them into `logged.json`. `chainlinks.py` turns them into
links that `chains` uses where neither forever.json nor QuestieDB has a
step.

**A Lost Memento (PR #892).** The quest's necklace drops from a Legashi
Satyr in Azshara. forever.json's `droppers` may now name an NPC ID, which
pins the mob where forever.json places it.

**Watcher imports (PR #880, #886).** Data from the combat log watcher.

## Scope

- `NeedRoll/Core/Drops.lua`:
  - `Whispers` (`GAP`, `wasLastSent`, `notFoundPatterns`) and
    `WaitBeforeSending`;
  - `SendNext`, `Queue`, `Probe` and `Answer`;
  - `GUIDSource` (split out of `QuestWindowSource`);
  - the whole `ChainClues` block and the quest log event handlers;
  - `QuestLogPrint`.

  All read in full.
- `NeedRoll/Core/DropPull.lua`: one comment.
- `NeedRoll/Core/Init.lua`: the `SectionMemory` comment, `SectionMemory.IsOpen` and `Toggle`, `ParticleForms`, `ns.GameTextPatterns`.
- `NeedRoll/Core/Names.lua`: `PART_SEPARATOR` via `ns.DOT`, `SplitParts` through `ns.WithDots`. `Core/Wishlist.lua`: one separator.
- `NeedRoll/Locales/Locales.lua`: `ns.DOT`, `ns.WithDots`, `ns.L`'s metatable, `SetPhrase`, `ns.Phrases`, `PreviewPhrases`. `Locales/enUS.lua`: 7 new phrases (Have materials ×6, Legashi Satyr). `Locales/NpcNames/Forever.lua`: one NPC. `Locales/zhTW.lua`: one character changed by hand (R8).
- `NeedRoll/UI/Lists.lua`:
  - `KNOWN_PROFESSION_BLOCK`, `ProfessionBlock`, `KnownProfessionsFirst`
    and `SameOrder`;
  - `CreateInstanceList`'s Classic Raids memory, `SetData`, the
    `SKILL_LINES_CHANGED` handler and `OnModeChange`;
  - the material filter: `MaterialName`, `FilterForms`, `AnyFormMatches`,
    `MaterialMatches`, `UsesExactly`, `IncludedIn`, `RecipeMatches` and
    `FilterAgainOnceNamesArrive`.

  All read in full.
- `NeedRoll/UI/LootGrid.lua`:
  - `SECTIONS` with `PROFESSIONS`/`startsShut`, `SECTION_INDEX`,
    `SectionStartsShut`, `IsSectionShut`, `SetSectionShut` and `LootKey`;
  - `CLASS_SEPARATORS`, `ClassNamesOn` and `OtherClassOnly`;
  - `FoldMemoryKey`, `IsFoldOpen`, `ToggleFold`, `ToggleTrainers`,
    `ToggleSection`, `JumpToFold` and the go-to path;
  - `AddTrainerLines`.
- `NeedRoll/UI/RecipeBand.lua`: `MATERIALS_*`, `NEXT_MATERIALS_STEP`, `MaterialsTooltipText`, the `MATERIALS` toggle, `IsOnInShownBand`, `NarrowForMaterials`, `OnHoldingsChanged` with its three events, `HeldCount`, `HasMaterials`, `Keeps`; the name-group comment.
- `NeedRoll/UI/ProfessionOverview.lua`: `FoldKeys`, `SetFoldState`, `AddFoldHeading`, `ZoneEntry`, `AddRankRows`, `AddSpecRows`, the Quests and Camping headings, `OpenAtFirst`, `ToggleFold`, `ShowProfession`, `OnModeChange`.
- `NeedRoll/UI/ClassOverview.lua`, `ClassSpells.lua`, `HunterPets.lua`, `WarlockPets.lua`, `LibraryBooks.lua`: their open/shut state moves to `ns.SectionMemory` (`KeepOpenRanks(page, area)`, `RanksKey`, `AreRanksOpen`, `AreAllTrainersShown`).
- `NeedRoll/UI/MainFrame.lua`: `ShowRecipeMatches` split out of `SetRecipeFilter`; the `/mappin` macro uses `SLASH_MAPPIN1`; the `BossFolds` comment; `GoToResult` passes `bossFold`.
- `NeedRoll/UI/Search.lua` (`fold` → `bossFold`), `TierSets.lua` (`ns.GameTextPatterns`, `MatchFirst`), `Theme.lua` (`Theme.DOTS` via `ns.DOT`), `Overview.lua` (four dots through `Theme.DOTS`), `DevKit.lua`, `FrameDebug.lua`, `IconDebug.lua` (dots).
- Hand-kept data: `NeedRoll/Data/Maps.lua`, `DevDungeons.lua` (one credit line each); `scraper/professions/recipe_bands.json`; `scraper/quests/forever.json` (A Lost Memento).
- Scraper: `needroll_scraper/recipebands.py`, `chainlinks.py` (new), `chains.py`, `knownquests.py`, `questie_quests.py`, `__main__.py`; tests `test_recipe_bands.py`, `test_chainlinks.py`, `test_chains.py`, `test_knownquests.py`, `test_questie_quests.py`; `scraper/README.md`.
- Tools and CI: `tools/locale_strings.py`, `tools/font_coverage.py`, `tools/lua_source.py` (new); `.github/workflows/locale-tests.yml` (new), `lua-check.yml`.
- Tests: `tests/smoke/wow.lua`, `run.lua`, `check.sh`, `locale.lua` (new), `scenarios.lua`, `README.md` and 17 modules. `tests/smoke/locales/*.lua` are written by the tools; I checked them only for what they hold (every value a plain string literal) and for no player names.
- Docs: `docs/STYLE-GUIDE.md`, `docs/LOCALIZATION.md`, `CLAUDE.md`, `.claude/agents/implementer.md` and `reviewer.md` (read, not reviewed as code).
- Generated data, skipped for style:
  - `NeedRoll/Data/Dungeons/*.lua`, `KnownDrops.lua`, `KnownQuests.lua`,
    `Quests.lua`, `ClassQuests.lua`, `ClassSpells.lua`, `Abilities.lua` and
    `RecipeSources.lua`.
  - The 23 dungeon files PR #890 edited by hand are R3. I checked them
    through `test_recipe_bands.py` and `build --check`, not line by line.
- Inputs, checked only for what they hold (names, sources): `scraper/drops/*.json`, `scraper/quests/logged.json`, `reported.json`, `scraper/classes/seen.json`, `scraper/abilities/observed.json`.
- Not in scope: `CHANGELOG.md`, `CHANGELOG-DETAILED.md` (the changelog PR updates them).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 59 changed hand-written Lua files and every changed file under `NeedRoll/Data/` | passed (Lua 5.1.5 installed for this review) |
| `luacheck --no-global -q` now vs `v1.6.0` (luacheck 1.2.0), warnings compared without line numbers | no new warnings in any changed file. The 13 new files (`tests/smoke/locale.lua`, `tests/smoke/locales/*.lua`, `run.lua`'s neighbours) have none |
| `tests/smoke/check.sh` (dev, packaged, secret values, in combat) | passed: exit 0, "all passed" in all four (221 / 212 / 221 / 221 files loaded; 698 / 610 / 698 / 698 scenarios ok) |
| `tests/smoke/check.sh --locale all` | passed: exit 0, "all passed" for all 11 clients. enUS 702 scenarios ok; each of the other ten 576 ok, with 126 skipped as "they expect English text" (`tests/smoke/locale.lua`'s `SKIPPED`) |
| `python3 tools/locales.py --check` | passed (exit 0, no output) |
| `python3 tools/translations.py` | passed (exit 0, no output) |
| `python3 tools/locale_strings.py --check` | passed (exit 0) |
| `python3 tools/font_coverage.py --check` | passed (exit 0) |
| `cd scraper && python3 -m unittest discover -s tests` | passed (377 tests) |
| `python3 -m needroll_scraper build --check --category DUNGEON` (extra, scratch cache) | passed (exit 0): every dungeon is "kept as it is" since Wowhead retired, so the hand-written band lines survive a build. That is also why R3's headers mislead |
| Lua 5.1 limits (extra; `luac5.1 -l -l`, most main-chunk locals active at once / most upvalues in one function, now vs `v1.6.0`) | `Core/Drops.lua` 192 / 189 locals in dev builds, 8 from the 200 limit (`ChainClues` puts its constants in one table for that reason). `LootGrid.lua` 185 / 179. `Overview.lua` 195 / 195 (unchanged). `Lists.lua` 127 / 113, `CreateEncounterList` 44 / 43 upvalues. `RecipeBand.lua` 121 / 111. `ProfessionOverview.lua` 163 / 161. None over a limit; Drops.lua and LootGrid.lua are the ones to watch |
| Boss fold keys (extra) | all 6 multi-boss encounters in `Data/Bosses.lua` give every boss an NPC ID (field 5), so `FoldMemoryKey` never indexes with nil (a script loading `Bosses.lua`) |
| Locale strings files (extra) | every value under `strings = {` in the 11 committed `tests/smoke/locales/<code>.lua` files is a single plain string literal (regex over each line; 0 others). R2 is about the tool's next run, not these files |
| Player names (extra) | none: the 287 names in `scraper/drops/credits.json` and the `by` fields of the watcher files appear in no file under `NeedRoll/`, `docs/`, `.github/`, `new-instances/`, `README.md` or the changelogs (`grep -w -F -f`). `questOffers` keys characters by name, but only in a dev build's own SavedVariables, and the scraper reads only `questLog` |
| ChainClues probes (extra, in a scratch copy of the repo, not committed) | showed R1: two added scenarios printed wrong candidates (see R1, Evidence) |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Readability (§9; chain data shipped in `Chains.lua`) | `NeedRoll/Core/Drops.lua:3345-3361` | A lone quest window makes an old snapshot whole again at a new time and level, so chain clues name the wrong hand-ins | fixed in round 2 (`339f53c4`) |
| R2 | should fix | Security | `tools/locale_strings.py:44`, `:120-127`, `:166-178`, `:197`; run by `tests/smoke/locale.lua:189` | Downloaded game strings are copied into Lua files the tests run, without checking they are plain string literals | fixed in round 2 (`6b7fc1fd`) |
| R3 | should fix | Readability (§9; generated-data rule) | 23 `NeedRoll/Data/Dungeons/*.lua` headers; `scraper/needroll_scraper/recipebands.py:4-5` | 2256 lines hand-written into files whose headers say "Generated ... do not edit by hand" | fixed in round 2 (`1f9f6765`, the header option); see R9 |
| R4 | nit | Security (sending budget) | `NeedRoll/Core/Drops.lua:2168`, `:1062`, `:2292-2300`, `:2209` | One whispered probe can spend 400 of a copy's 500 daily messages and put its own finds 3 h 20 min back | left as is: Mike's decision (whispered answers stay 400; `DAILY_MAX` 500 to 1500, `90980b41`) |
| R5 | nit | Security (workflow) | `.github/workflows/locale-tests.yml` | The new workflow sets no `permissions:` | fixed in round 2 (`b9f2fda0`) |
| R6 | nit | Redundant code | `NeedRoll/UI/Lists.lua:2497-2513`; `NeedRoll/UI/RecipeBand.lua:418-430` | Two more hand-rolled "once per burst" timers, and one comment says it waits for the burst to settle | partly fixed in round 2 (`a2d4052f`: the comment); the shared helper not done, no reason given |
| R7 | nit | Readability (§6) | `NeedRoll/UI/LootGrid.lua:148-171`; `NeedRoll/Core/Init.lua:229-242` | Two ways of remembering an open/shut state | fixed in round 2 (`ad43fd19`, the comment option) |
| R8 | nit | Readability (§5, §9) | `NeedRoll/UI/Lists.lua:1896-1901`; `NeedRoll/UI/MainFrame.lua:3049`; `NeedRoll/UI/ClassSpells.lua:539`; `NeedRoll/Locales/zhTW.lua:452` | Small slips: a comment, a guard, a missing comment, a hand edit to a translation file | fixed in round 2 (`a2d4052f`); the zhTW character was already "魘" in NeedRoll-Locales main (checked after round 2) |

### R1 · A lone quest window makes an old snapshot whole again at a new time and level, so chain clues name the wrong hand-ins
- **Severity:** should fix (dev-only code, but its output becomes `Data/Chains.lua`, which ships; nothing is ingested yet, so nothing wrong has shipped)
- **Area:** Readability (§9: the comments say one thing, the code does another), with a data-correctness effect
- **Where:** `NeedRoll/Core/Drops.lua:3345-3361` (`ChainClues.NoteOffers`), with `:3312-3324` (`HandInsSince`) and `:3327-3336` (`NoteNewcomer`)
- **Status:** fixed in round 2 (`339f53c4`)

**What's wrong.**

```lua
    if last and not isWhole then
        for questID in pairs(last.quests) do offered[questID] = true end
        isWhole = last.isWhole
    end
    mine.npcs[sourceKey] = { at = time(), level = level, quests = offered, isWhole = isWhole or nil }
```

A lone quest window (QUEST_DETAIL) adds its one quest to the NPC's last
snapshot. That part is right. But it also stamps the snapshot with the
current time and level, and keeps it marked whole. The comment above the
function promises two things:
- "a snapshot from another level tells nothing";
- a lone window "only adds its quest".

The code breaks both:
- **The level.** A snapshot taken whole at level 20 becomes "whole at
  level 21" once a lone window opens at 21. The quests that level 21
  opened by itself were never seen in it.
- **The time.** `at` moves to the lone window's time. Later,
  `HandInsSince(mine, questID, last.at)` only counts hand-ins after that
  moment. A hand-in between the real whole view and the lone window drops
  out of the candidates.

**Why it matters.** The common case is the follow-up offer, which this
same PR is built to catch. The player hands in quest X at an NPC, often
dinging from its XP, and the game opens the next quest's window by itself.
That window is exactly the lone window that rewrites the snapshot. When the
player next opens the NPC's gossip:
- A quest the new level opened is put down to X alone. `chainlinks._narrowed`
  takes "one observation with one candidate" as a link, so "X before C"
  enters `logged.json`, and `chains` writes it into `Data/Chains.lua` for a
  Forever quest that neither forever.json nor QuestieDB has a step for.
  Players would then see a wrong "do X first" step.
- A quest that another hand-in Y (elsewhere, before X) opened is likewise
  put down to X alone, instead of {X, Y}.

**Evidence.** Two scenarios added to `tests/smoke/modules/Core-Drops.lua`
in a scratch copy (dev run, `--only`), using the module's own `ShowOffers`,
`HandIn`, `OfferQuest` and `UnlockCandidates`:
1. Gossip shows {995963} at level L. The player levels up, hands in 995960
   at that NPC, and the game offers 995962 (lone window). Then gossip at
   L+1 shows {995963, 995962, 995964}. Printed: `candidates for the
   level-unlocked quest: 995960`. Expected: no observation, since the level
   changed.
2. Same level throughout. Gossip shows {995963}, 995961 is handed in
   elsewhere, then 995960 here with the game offering 995962. Gossip then
   shows {995963, 995962, 995964}. Printed: `candidates for 995964:
   995960`. Expected `995960,995961`; 995961 was lost when the lone window
   moved `at`.

The committed scenario "a quest newly offered after hand-ins names them as
what opened it" never opens a lone window between two gossip views, so it
can't see this. `grep -c unlockedAfter scraper/quests/logged.json` is 0:
no clue has been ingested yet.

**Fix.** A lone window adds its quest but changes neither when nor at which
level the whole list was last seen. From another level it can't keep the
snapshot whole:

```lua
    local at = time()
    if last and not isWhole then
        for questID in pairs(last.quests) do offered[questID] = true end
        -- One quest seen doesn't make the rest of the list newer: keep when
        -- and at which level the whole list was seen. From another level the
        -- list is no longer known whole.
        isWhole = last.isWhole and last.level == level
        if isWhole then at = last.at end
    end
    mine.npcs[sourceKey] = { at = at, level = level, quests = offered, isWhole = isWhole or nil }
```

Add both probe cases above as asserts to the committed scenario.

### R2 · Downloaded game strings are copied into Lua files the tests run, without checking they are plain string literals
- **Severity:** should fix
- **Area:** Security (scraper, tools and workflows: downloaded text must not become code)
- **Where:** `tools/locale_strings.py:44` (`LINE`), `:120-127` (`read_strings`), `:166-178` (`_slash_lines`), `:197` (`write`); the files are run by `tests/smoke/locale.lua:189` (`loadfile(...)`), locally and in `.github/workflows/locale-tests.yml` on every PR and push
- **Status:** fixed in round 2 (`6b7fc1fd`)

**What's wrong.** The tool downloads Ketho's `GlobalStrings/<code>.lua` and
keeps each value as the raw text after `=`:

```python
LINE = re.compile(r'^(?:([A-Za-z_][A-Za-z0-9_]*)|_G\["([^"]+)"\]) = (".*");\s*$')
...
            strings[match.group(1) or match.group(2)] = match.group(3)
...
        out += [f"        {_key(key)} = {strings[key]},\n" for key in sorted(keys) if key in strings]
```

`(".*")` is greedy. It accepts any text that starts and ends with a quote,
including an expression made of several literals and calls. That text is
written as-is into `tests/smoke/locales/<code>.lua`. The Locale tests then
`loadfile` and run it, locally on Mike's machine and in CI. `_slash_lines`
does the same with every `SLASH_*` value without a space in it.

**Why it matters.** A changed upstream line such as
`ERR_CHAT_PLAYER_NOT_FOUND_S = "x" .. os.execute("...") .. "y";` would run
as code on the next `py tools/locale_strings.py` and test run, and later
in CI. The upstream file could change through a compromised account or a
bad commit. The source is a trusted third party and the output is
committed, so a reviewer could catch it. But the files are about 8000 lines
of strings, and one line hides easily. The reviewer rules forbid exactly
this class of thing: `eval` on downloaded data, `Invoke-Expression` on
downloaded text.

**Evidence.**

```
$ python3 -c 'import locale_strings as ls; print(ls.read_strings(
    "ERR_CHAT_PLAYER_NOT_FOUND_S = \"x\" .. os.execute(\"echo pwned\") .. \"y\";"))'
{'ERR_CHAT_PLAYER_NOT_FOUND_S': '"x" .. os.execute("echo pwned") .. "y"'}
```

The keys are safe: only names the code reads (`NAME` is
`[A-Z][A-Z0-9_]*`) are written. The 11 committed files are clean today:
every value is one plain literal (see Checks).

**Fix.** Accept only one plain literal, and write it back re-quoted from its
decoded text:

```python
LITERAL = r'"(?:[^"\\\n]|\\.)*"'
LINE = re.compile(r'^(?:([A-Za-z_]\w*)|_G\["([A-Za-z_]\w*)"\]) = (' + LITERAL + r');\s*$')

def lua_quote(text):
    """`text` as one Lua string literal: `"`, `\\` and control bytes as \\ddd escapes."""
    return '"' + "".join("\\%d" % ord(c) if c in '"\\' or ord(c) < 32 else c for c in text) + '"'
```

Store `lua_quote(lua_source.decode(match.group(3)))` in `read_strings`.
`lua_source.decode` already exists. `write` then only ever emits a single
literal, and `_slash_lines` can quote each command with `lua_quote` instead
of slicing `c[1:-1]`. A line that doesn't match is skipped, as now.

### R3 · 2256 lines hand-written into files whose headers say "Generated ... do not edit by hand"
- **Severity:** should fix
- **Area:** Readability (§9 no misleading comments; the reviewer rule "flag hand edits to a generated file")
- **Where:** the headers of the 23 `NeedRoll/Data/Dungeons/*.lua` files commit `d087ca3c` edits, for example `Uldaman.lua:1-3`; `scraper/needroll_scraper/recipebands.py:4-5`; `scraper/README.md` ("Dungeon recipe bands"); `scraper/professions/recipe_bands.json` (`about`)
- **Status:** fixed in round 2 (`1f9f6765`, the header option); see R9

**What's wrong.** PR #890's commit says the band recipes' lines were
"written by hand in emit.py's line format", and `recipebands.py` says so
too: "Builds keep Data/Dungeons as Wowhead gave it, so the lines these
placements call for are written into it by hand". The files still open
with:

```lua
-- Uldaman. Generated by the NeedRoll scraper; do not edit by hand.
-- Corrections go in scraper/overrides/ULDAMAN.json, then rerun:
--   py -m needroll_scraper build
```

That header now names a path that doesn't work. A `build` keeps every
dungeon file as it is ("DUNGEON: kept as it is; its WoW: Forever data came
from Wowhead, which is retired"), so an override there changes nothing.

**Why it matters.**
- A newcomer, or Mike in a year, reads "do not edit by hand" and looks for
  the generator that writes the band lines. There is none: the rule lives
  in `recipebands.py`, but nothing writes its result.
- When a band changes, someone has to hand-edit up to 23 files again, in
  `emit.py`'s exact format.
- `build --rebuild-without-wowhead` would drop all 2256 lines, since no
  Classic-DB source has them. `test_recipe_bands.py` would catch that
  afterwards; nothing prevents it.

**Evidence.** `git show --stat d087ca3c` (23 dungeon files);
`recipebands.py:1-6`; `test_recipe_bands.py:1-4`. The `build --check
--category DUNGEON` output is in Checks. The test passes, so the hand-written
lines match the rule today.

**Fix.** The placements already exist. `test_recipe_bands.py` computes the
expected (item, boss) set per encounter from `recipebands.placements`. Turn
that into a command, `py -m needroll_scraper recipebands`, that writes the
lines through `emit` (and reruns `knowndrops`), so "generated" is true again
and the test checks the generator's output. If that is more than this
release wants, at least change the header `emit.py` writes for the
Wowhead-era dungeon files to say what is true: "Kept as it is by build since
Wowhead retired; ingest adds drops; the recipe band lines are written by hand
(scraper/README.md, Dungeon recipe bands), and tests/test_recipe_bands.py
checks them".

### R4 · One whispered probe can spend 400 of a copy's 500 daily messages and put its own finds 3 h 20 min back
- **Severity:** nit (a design trade-off for Mike to confirm; nothing floods a channel)
- **Area:** Security (sending: the pace and daily cap are respected, but the budget moves)
- **Where:** `NeedRoll/Core/Drops.lua:2168` (`WHISPER_ANSWER_MAX = 400`), `:1062` (`DAILY_MAX = 500`), `:2292-2300` (`Answer`), `:1304-1320` (`Queue` appends behind what waits), `:2201-2212` (`ProberKey` leaves the realm out)
- **Status:** left as is: Mike's decision (whispered answers stay 400; `DAILY_MAX` 500 to 1500, `90980b41`)

**What's wrong.** A whispered probe now queues up to 400 answers, sent
30 s apart, which takes 200 minutes. Each one counts towards `DAILY_MAX`
(`CountTowardsDailyMax` counts every message). Finds the player makes
meanwhile queue behind them. With `ANSWER_GAP` at 15 minutes, a second
probe queues up to `OUTBOX_MAX - #outbox` more.

**Why it matters.**
- A copy holding many unshared finds can spend 80% of its day answering one
  probe. Its own new kills then reach the realm channel, guild and
  Battle.net friends hours late. Past the cap they don't go out until the
  next day.
- PROBERS keys leave the realm out, so "a namesake on another realm can
  probe there too" (`ProberKey`'s comment). The same holds for anyone who
  takes a planned launch name first. Before this release such a namesake
  could take 25 messages per probe; now it can take 400.

Whispered answers are taken out of the outbox at logout, so this lasts one
session at most.

**Evidence.** Read `Drops.lua:1112-1122`, `:1216-1273`, `:2283-2301`. The
scenario "a whispered probe gets at most 400 answers, a realm channel
probe 25" confirms the count.

**Fix.** Mike's call. Options:
- give whispered answers their own daily share, for example at most half of
  `DAILY_MAX`, so the player's own finds always have room;
- or queue a new own find ahead of waiting whispered answers (they're
  marked `relay = "answer"`), as trainer messages already queue behind
  everything.

### R5 · The new workflow sets no `permissions:`
- **Severity:** nit
- **Area:** Security (workflows: least-privilege `permissions:`)
- **Where:** `.github/workflows/locale-tests.yml`
- **Status:** fixed in round 2 (`b9f2fda0`)

**What's wrong.** The workflow only checks out the repo and runs
`tests/smoke/check.sh --locale <code>`, but it doesn't set `permissions:`,
so its `GITHUB_TOKEN` gets the repository's default. On `push` to dev or
main that default may include write access.

**Why it matters.** The job runs Lua files the tools write from downloaded
text (R2). If anything in it misbehaves, a read-only token limits the
damage. `scraper-tests.yml` already sets `contents: read`.
`smoke-tests.yml` and `lua-check.yml` lack it too; that predates this
release.

**Evidence.** `grep -L permissions .github/workflows/*.yml` lists
`locale-tests.yml`, `lua-check.yml` and `smoke-tests.yml`;
`scraper-tests.yml:18-19` has `permissions: contents: read`.

**Fix.** Add at the top level:

```yaml
permissions:
  contents: read
```

The same two lines would suit `lua-check.yml` and `smoke-tests.yml`.

### R6 · Two more hand-rolled "once per burst" timers, and one comment says it waits for the burst to settle
- **Severity:** nit
- **Area:** Redundant code (and §9 for the comment)
- **Where:** `NeedRoll/UI/Lists.lua:2497-2513` (`FilterAgainOnceNamesArrive`); `NeedRoll/UI/RecipeBand.lua:418-430` (`isMaterialsNarrowDue`, `NarrowForMaterials`, `OnHoldingsChanged`); existing copies: `NeedRoll/UI/HunterPets.lua:925-934` (`PetPageKit.AddRefreshSoon`), `NeedRoll/UI/Classes.lua:774-782` (`tab:RefreshSoon`), `NeedRoll/UI/Search.lua:38-47` (`QueueRefresh`), `NeedRoll/UI/Reputation.lua:106-115`
- **Status:** partly fixed in round 2 (`a2d4052f`: the comment); the shared helper not done, no reason given

**What's wrong.** Each of the six is the same five lines: a flag, a
`C_Timer.After(delay, ...)` that clears it, and a re-check that the pane
still shows. This release adds two of them. The Lists one's comment reads:

> Material names the game sends after the filter ran ... arrive in bursts:
> once one settles, the filter runs again

The code is a throttle, not a settle. It runs 0.2 s after the *first* name
of a burst, and names arriving later schedule another run.

**Why it matters.** Six copies of one idea drift; one already reads as if
it waits for quiet. A newcomer looking for "how does NeedRoll coalesce
redraws" finds six answers.

**Fix.** One helper on `ns` (for example in `Core/Init.lua`):

```lua
-- Returns a function that runs `fn` once, `delay` seconds (0: next frame)
-- after its first call; calls in between are folded into that one run.
function ns.OncePerBurst(delay, fn)
    local isDue = false
    return function()
        if isDue then return end
        isDue = true
        C_Timer.After(delay, function() isDue = false; fn() end)
    end
end
```

Use it for the two new ones now. The four older ones can move when they're
next touched. Reword the Lists comment: "the filter runs again 0.2 s after
the first of them, once for the lot".

### R7 · Two ways of remembering an open/shut state
- **Severity:** nit
- **Area:** Readability (§6 one way of doing each thing)
- **Where:** `NeedRoll/UI/LootGrid.lua:148-171` (`SectionStartsShut`, `IsSectionShut`, `SetSectionShut`); `NeedRoll/Core/Init.lua:229-242` (`SectionMemory.IsOpen`, `SectionMemory.Toggle`)
- **Status:** fixed in round 2 (`ad43fd19`, the comment option)

**What's wrong.** PR #884 gives `ns.SectionMemory` one pair of helpers.
`IsOpen(states, key, isOpenAtFirst)` and `Toggle` store `true` or `false`
once clicked ("so a section that starts open stays shut once shut"), and
the boss folds, trainers, ranks, profession folds and Library use them. The
loot sections in the same file (PR #893) use their own pair. That pair
stores the opposite polarity (`true` = shut, which the saved loot area must
keep) and, unlike `Toggle`, clears the key back to `nil` when the state
matches how the section starts.

**Why it matters.** Two rules decide what a remembered fold means. Suppose
Mike later changes whether a section starts open:
- a loot section the player put back to its start follows the new default;
- a profession rank or Library fold the player clicked twice keeps
  `false`.

Both are reasonable; having both, with nothing saying why, is the
inconsistency.

**Fix.** Pick one storage rule and keep it in `SectionMemory`, for example
`SectionMemory.Set(states, key, value, valueAtFirst)`, which stores `nil`
when `value == valueAtFirst`. `Toggle` and `SetSectionShut` (with its shut
polarity) then both call it. Or keep both, with a line at
`SetSectionShut` saying why loot sections differ.

### R8 · Small slips: a comment, a guard, a missing comment, a hand edit to a translation file
- **Severity:** nit
- **Area:** Readability (§5, §9)
- **Where:** `NeedRoll/UI/Lists.lua:1896-1901`; `NeedRoll/UI/MainFrame.lua:3049`; `NeedRoll/UI/ClassSpells.lua:539`; `NeedRoll/Locales/zhTW.lua:452`
- **Status:** fixed in round 2 (`a2d4052f`); the zhTW character was already "魘" in NeedRoll-Locales main (checked after round 2)

**What's wrong.**
- **`FilterForms`' comment** says "English plurals only: on other clients
  a plural matches as typed". But the code tries the s-stripped form on
  every client: a French "épées" also looks for "épée", a German "Erzes"
  for "Erze". Say "the rules are English ones; on other clients they may
  add a form, and the filter as typed still counts".
- **`local command = SLASH_MAPPIN1 or "/mappin"`** guards a global every
  client has. It's at `GlobalStrings/enUS.lua:19915` in Ketho's `forever`
  branch, and in all 11 `tests/smoke/locales/*.lua` files: `/marcar`,
  `/координаты`, `/測位`. `LootGrid.lua` reads `LIST_DELIMITER` the same
  way without a guard. That's the v1.6.0 review's R7 again (a guard a
  reader goes looking for a reason behind). Use `SLASH_MAPPIN1` directly.
- **`ClassSpells.AreRanksOpen`** is the one new `ClassSpells` function
  without a comment. Its neighbours `RanksKey` and `KeepOpenRanks` have
  one. Something like "-- Whether `spell`'s ranks show on `page`".
- **`Locales/zhTW.lua:452`** is changed by hand ("魇" to "魘"), but the
  file's header says "edit it there [NeedRoll-Locales], not here". The
  next Translations sync brings the old character back unless
  NeedRoll-Locales is fixed. `docs/LOCALIZATION.md` notes the follow-up;
  it just needs doing before that sync.

**Why it matters.** Each is small, but each makes a reader stop: a
comment that doesn't match the code, a guard with no reason, a function
with no comment, a fix that will be undone.

**Fix.** As above.

## Area notes

### Readability

I read every changed function in full against READABLE-CODE.md. The
biggest are:
- the whole `ChainClues` block, `Whispers`/`WaitBeforeSending`/`SendNext`/`Queue`;
- `ns.GameTextPatterns` and `ParticleForms`;
- the material filter chain in `Lists.lua`;
- `KnownProfessionsFirst`;
- the Have materials path in `RecipeBand.lua`;
- the `SectionMemory` call sites in eight UI files;
- `ClassNamesOn`/`OtherClassOnly`;
- `Locales.lua`'s dot swap.

Sound:
- **Names** are in game terms and searchable: `KNOWN_PROFESSION_BLOCK`,
  `HeldCount`, `HasMaterials`, `FoldMemoryKey`, `RanksKey`, `FoldKeys.Zone`,
  `CHANNEL_ANSWER_MAX`/`WHISPER_ANSWER_MAX`, `SECTION_INDEX` (which replaces
  the bare section numbers `1`-`5` in `LootKey`, a readability gain),
  `NAME_BURST_SECONDS`, `HISTORY_KEPT`.
- **Functions** do one thing. `SetRecipeFilter` was split into
  `ShowRecipeMatches`. The old in-closure `RecipeMatches` became five
  small file-level functions, and `GUIDSource` came out of
  `QuestWindowSource`.
- **Nesting.** No new function nests past three levels.
- **Comments** give the game reason:
  - `FRIZQT___CYR.TTF` lacking "·", and the Chinese fonts lacking "∙";
  - `ADDON_LOADED` coming before `PLAYER_LOGIN` (why the name groups are
    safe);
  - SavedVariables written only on `/reload`, logout or exit (why
    `ForgetAfterGap` exists);
  - the 200-locals limit (why `ChainClues` is one table);
  - secret quest titles (why everything is keyed by ID).
- **No narration** in comments ("now" appears only as "at this moment").
- **Files.** Every addon file keeps `local _, ns = ...`; 4-space indents,
  LF throughout.

Lua 5.1 traps, looked for and not found:
- **`a and b or c`.** Every new use has a middle value that is never nil
  or false:
  - `outbox[1] and WaitBeforeSending(outbox[1]) or SEND_GAP` (a number);
  - `(Whispers.wasLastSent and entry.to == "WHISPER") and Whispers.GAP or SEND_GAP`;
  - `whisperTo and Probe.WHISPER_ANSWER_MAX or ...`;
  - `#included > 0 and included or nil`;
  - `isOpen and #trainers or math.min(...)`.
- **`#` on holes.** `CLASS_SEPARATORS = { ",", LIST_DELIMITER,
  PLAYER_LIST_DELIMITER }` would have a hole if a client lacked
  `LIST_DELIMITER`. Every client has both, per the 11 locale files and
  Ketho's enUS (lines 13781, 16533).
- **Patterns built from data.**
  - `ns.GameTextPatterns` escapes every magic character before it adds
    captures.
  - `ClassNamesOn` escapes the separator with `%p`.
  - `ns.WithDots` and `PART_SEPARATOR` use "·"/"∙", whose UTF-8 bytes
    hold no magic characters.
  - The player's filter goes through `WordsMatch` (plain `find`) and fixed
    patterns in `FilterForms`.
- **A `false` table key** (`NEXT_MATERIALS_STEP[false]`) is valid, as for
  Learnable.

Also noted, not findings:
- The locale sweep's dot fix reached `DevKit`, `FrameDebug`, `IconDebug`
  and `DevDungeons`. These still type "·" in English labels: `DropTalk.lua`,
  `MapEdit.lua:949` and `:1239-1240`, `IconBrowser.lua:63-64`, and
  `Overview.lua:2592`'s devedit tooltip. All of them are dev-only (two are
  in `.pkgmeta`'s ignore list, the others show only with `/nr devedit` or
  in debug windows). Worth the same `ns.WithDots` when next touched.
- `UI/Search.lua`'s `fold` → `bossFold` rename fixes a real error, found by
  the Locale tests. `LOCALIZATION.md`'s table records it.

### WoW API

| Call / event / method / string / enum | In Ketho's `forever` lists | Where checked |
| --- | --- | --- |
| `C_GossipInfo.GetAvailableQuests` (new; fields `questID`, `isTrivial`, `frequency`, `repeatable`) | yes | GlobalAPI.lua:2006; fields per Ketho's `GossipQuestUIInfo` annotation (inferred) |
| `GetNumAvailableQuests`, `GetAvailableQuestInfo` (new; `isTrivial, frequency, isRepeatable, isLegendary, questID`) | yes | GlobalAPI.lua:5635, 5296; return order per warcraft.wiki.gg |
| `QuestIsFromAreaTrigger`, `QuestIsDaily`, `QuestIsWeekly` (new) | yes | GlobalAPI.lua:6322, 6320, 6323 |
| `C_QuestLog.IsQuestTrivial`, `C_QuestLog.IsRepeatableQuest`, `C_QuestLog.GetAllCompletedQuestIDs` (new) | yes | GlobalAPI.lua:3606, 3607, 3544 |
| `C_QuestLog.IsOnQuest`, `UnitGUID`, `UnitLevel`, `UnitName`, `time`, `GetTime`, `wipe` (new callers) | yes | GlobalAPI.lua:3593, 6689, 6772, 6773, 7083, 5921, 7090 |
| `C_Item.GetItemCount` (new caller; `includeBank` via `Shop:BankCount`) | yes | GlobalAPI.lua:2514 |
| `C_Item.GetItemNameByID`, `IsItemDataCachedByID`, `RequestLoadItemDataByID` (newly asked for materials, through `ns.Items:Load`) | yes | GlobalAPI.lua:2538, 2581, 2597 |
| `C_SkillInfo.GetSkillLineInfoByID` (via `ns.UI.SkillRank`, newly asked by the list order) | yes | GlobalAPI.lua:3818 |
| `GetLocale` (new caller, `Locales.lua`) | yes | GlobalAPI.lua:5560 |
| `tContains` (new callers, `Lists.lua`) | yes | GlobalAPI.lua:7055 |
| Events `GOSSIP_SHOW`, `QUEST_GREETING`, `QUEST_REMOVED`, `PLAYER_LOGOUT` (new handlers in Drops.lua) | yes | Events.lua:862, 1590, 1577, 1822 |
| Events `SKILL_LINES_CHANGED` (Lists.lua), `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`, `PLAYERBANKSLOTS_CHANGED` (RecipeBand.lua) | yes | Events.lua:1699, 520, 167, 169 |
| `SLASH_MAPPIN1`, `LIST_DELIMITER`, `PLAYER_LIST_DELIMITER` (new) | yes | GlobalStrings/enUS.lua:19915, 13781, 16533; all 11 clients in `tests/smoke/locales/` |
| `ERR_CHAT_PLAYER_NOT_FOUND_S`, `ITEM_SET_BONUS`, `ITEM_SET_BONUS_GRAY`, `ITEM_CLASSES_ALLOWED` (now read through `ns.GameTextPatterns` / `ClassNamesOn`) | yes | GlobalStrings/enUS.lua:7986, 13029, 13030, 12682 |
| `Enum.ItemClass.Recipe` (new) | yes (9) | LuaEnum.lua:4663 |
| `Enum.ItemRecipeSubclass` (new in `wow.lua` and the scenario; the addon sorts by the raw subclass number) | yes | LuaEnum.lua:5126-5139 |

- **Combat.** No call the game blocks in combat is added, and
  `CHECKED_COMBAT_CALLS` (`tests/smoke/scenarios.lua:2781`) is unchanged in
  the range. The `/mappin` macro change sits inside a `PreClick` that
  already returns on `InCombatLockdown()` (`MainFrame.lua:3039`). The new
  redraws (`SKILL_LINES_CHANGED`'s `pane:Rebuild`, the material filter's
  timer, `NarrowForMaterials`, the `OnModeChange` refreshes) move no
  secure frame. The `--combat` run passed.
- **Secret values.** Every game value the chain clues read goes through
  `Plain` (GUIDs, levels, quest IDs, the trivial/frequency/repeatable
  flags), and nothing keys or compares a quest title: the offers are kept
  by quest ID. `ClassNamesOn` reads tooltip text already gated by
  `ns.Items.TooltipLines`, as before. The `--secret` run passed.
- **Async data.** Material names: `C_Item.GetItemNameByID` first. When it
  is nil, `ns.Items:Load` asks once per item (`materialNamesAsked`), waits
  for `ITEM_DATA_LOAD_RESULT`, and re-runs the filter coalesced. Not
  polled. A scenario covers a late name (`UI-Lists.lua:694-706`).
- **Events.** All new handlers go through `ns:On`, which can't unregister,
  as everywhere in the addon. Each returns at once unless its pane shows
  (`IsOnInShownBand`, `IsProfessionList`) or `ns.db` exists. None is
  one-shot.
- **Every client's language.**
  - Nothing new matches English against game text: the three game lines go
    through `ns.GameTextPatterns`, and the class line through the client's
    own separators.
  - Separators go through `ns.DOT`/`Theme.DOTS`.
  - No new texture by file ID.
  - The `--locale all` run passed, with font and macro checks for each
    client.
  - The material filter's singular forms are English-only by design (R8
    for the comment).
  - On ten clients 126 scenarios are skipped as English-only. That is
    documented in `tests/smoke/locale.lua`, and those clients still run
    576 each.
- **Lua limits.** See Checks. Nothing over a limit; `Core/Drops.lua` is at
  192 of 200 main-chunk locals in dev builds.
- **No new globals.** `ns.DOT`, `ns.WithDots`, `ns.GameTextPatterns`,
  `Drops.ChainClues` and `RB.MATERIALS_*` all live on `ns`. luacheck with
  global checks shows no new global write in the changed addon files.
- **Smoke mirrors.** `wow.lua` adds every new call: `C_GossipInfo`,
  `GetNumAvailableQuests`, `GetAvailableQuestInfo`, `QuestIs*`, the three
  `C_QuestLog` calls, `C_Item.GetItemCount` with bag and bank counts,
  `LIST_DELIMITER`/`PLAYER_LIST_DELIMITER` and `Enum.ItemRecipeSubclass`.
  It defines nothing Forever lacks (each checked above).

  Scenarios exist for:
  - the profession order and `SKILL_LINES_CHANGED`;
  - material matches, plurals and a late name;
  - Have materials' steps and bag/bank events;
  - every remembered fold;
  - the Russian dot and `/координаты`;
  - `GameTextPatterns` (Korean, Russian);
  - the Professions loot section;
  - the whisper pace and caps;
  - both chain clues (R1's gaps excepted);
  - A Lost Memento.
- **No nil guard removed.** One needless guard added (`SLASH_MAPPIN1 or`,
  R8).
- **Text.** All new player-facing text is literal `L["..."]` (7 phrases).
  The English list is in sync (`locales.py --check`).
  `QuestLogPrint`'s new line is dev-only English inside `--@debug@`
  (`Drops.lua:2507-3554`).
- **Dev-only code.** `ChainClues` and its handlers sit inside that
  `--@debug@` block, so released builds keep no `questOffers`. The packaged
  run passed (610 scenarios).
- **STYLE-GUIDE.** Updated in the same release, with values matching the
  code:
  - the Professions list order and its rule (`KNOWN_PROFESSION_BLOCK`,
    `SKILL_LINES_CHANGED`);
  - the toggles row with Have materials;
  - the loot sections with Professions, which starts shut;
  - the fold row's "Starts shut; then stays";
  - Remembered sections listing every area;
  - the Quests and Camping rows;
  - the separator dot (`ns.DOT`, U+2219 on Russian).

### Redundant code

Compared against:
- **Section memory.** The new `ns.SectionMemory.IsOpen`/`Toggle` replace
  per-page copies:
  - `LibraryBooks.lua`'s own `IsFoldOpen` is deleted;
  - `ProfessionOverview`'s `StartsShut`/`shutSections`/`openRanks` give way
    to `openFolds`;
  - `ClassOverview`'s `page.allTrainers` and LootGrid's `trainersOpen` and
    per-list `pane.open` go.

  A real reduction. The one pair left beside them is R7.
- **Game text patterns.** `TierSets.lua`'s private `TooltipPattern` and
  `Drops.lua`'s private escape are replaced by `ns.GameTextPatterns`, one
  home.
- **Dots.** Four `("%s  ·  %s"):format` sites in `Overview.lua` and one in
  `Lists.lua` now use `Theme.DOTS`. The `"  " .. ns.DOT .. "  "` spelled out
  in `Data/Maps.lua` and `DevDungeons.lua` is acceptable: data files load
  before `Theme.lua`.
- **Recipe filter.** `RecipeProduct` (existing) is reused by `IncludedIn`,
  `ns.UI.WordsMatch` by `AnyFormMatches`, `ns.Items:Load` by
  `MaterialName`, and `ns.UI.SkillRank` by the list order.
- **Have materials.** It reuses `ns.Shopping:BankCount` (the bank's live or
  saved counts) instead of scanning the bank again, and the stepped-box
  machinery (`nextStep`, `tooltip`, `stepLabels`) from v1.6.0.
- **Timers.** Six copies of the same coalescing timer, two of them new (R6).
- **Scraper.**
  - `_by_hand` became `Builder.by_hand` (one function, now able to pin by
    NPC ID).
  - `chains.build` reuses `_hand_kept_row` for learned rows.
  - `knownquests.merge_logged` folds the clues in the one merge.
- **Dead code: none.** `StartsShut`, `OpenByDefault`, `TooltipPattern`,
  `trainersOpen`, the old in-closure `RecipeMatches` and `MISC` are gone
  with no callers left (grepped). `ClassSpells.ToggleRanks` still has three
  callers. No debug print outside `--@debug@`.
- **Per frame.** No new `OnUpdate`. The per-keystroke material lookup is
  cached (`materialNames`). The bag events coalesce to one narrow per
  frame.

### Security

Untrusted inputs and outputs this release touches:
- **Addon messages.** No new message kind, field or parse; `CHAT_MSG_ADDON`
  handling is unchanged.
  - The whispered answer path still answers only a PROBERS character
    (`IsProber`), at most once per `ANSWER_GAP`, through the outbox's pace
    and `DAILY_MAX`. Its size is R4.
  - `Whispers.BouncedName` reads the game's own `CHAT_MSG_SYSTEM` line, not
    another player's text. The name it captures is only compared with the
    player's own recent whisper targets (`IsRecent`).
  - Whisper targets don't reach SavedVariables: they are taken out at
    logout (scenario "whispered answers are taken out of the outbox as the
    game saves it").
- **No `loadstring`, `RunScript` or `setfenv`** in the addon diff. The only
  new code execution of outside text is R2, in the test tools.
- **Text from other players shown in the UI:** none new.
- **Names.**
  - `NeedRollDB.questOffers` keys a dev build's characters by "Name-Realm".
    It stays in the player's own SavedVariables; `ingest` reads only
    `questLog` (`savedvars.load(...).get("NeedRollDB")` then `questLog`,
    `newQuests`, `drops`), and the scraper has no `questOffers` reader
    (grepped).
  - No credited or reporting name is in any public-bound file (see
    Checks).
  - The new NPC names (Legashi Satyr) are game NPCs.
- **Third-party data.**
  - QuestieDB is still read at build time only; `chains` adds no QuestieDB
    file.
  - `recipe_bands.json` cites "Mike's saved Wowhead item pages", read from
    disk. No code path requests Wowhead: no `http` in the scraper diff, and
    `build --check` reports Wowhead "retired".
  - `tools/locale_strings.py` downloads Ketho's GlobalStrings from GitHub
    (R2), and `font_coverage.py` reads fonts from a local folder and never
    commits them.
- **Scraper and tools safety.**
  - No `shell=True`, `eval` or `pickle`.
  - `chainlinks.py` converts IDs with `int()` after `isdigit()` and skips
    booleans and non-dicts.
  - No path comes from data.
- **Workflows.**
  - `locale-tests.yml` runs on `pull_request` (not `pull_request_target`)
    and interpolates only its own static matrix (`${{ matrix.locale }}`),
    no `github.event.*` text.
  - It sets no `permissions:` (R5).
  - `lua-check.yml` only widens its paths and adds two `--check` steps.
  - No secret is read or logged.

## Round 2

Seven commits on `09ec5966`:

| Commit | For | What it does |
| --- | --- | --- |
| `339f53c4` | R1 | `ChainClues.NoteOffers` keeps the snapshot's time and level; adds a scenario |
| `90980b41` | R4 | `DAILY_MAX` 500 to 1500 (Mike's call) |
| `6b7fc1fd` | R2 | `locale_strings.py` accepts only plain literals and quotes them again |
| `1f9f6765` | R3 | `emit.DUNGEON_HEADER`; 26 Classic dungeon files' header lines re-rendered |
| `b9f2fda0` | R5 | `permissions: contents: read` |
| `a2d4052f` | R6, R8 | comments; `SLASH_MAPPIN1` without a fallback |
| `ad43fd19` | R7 | a comment |

I re-read every function these commits touch in full, not only the changed
lines:
- `NoteOffers` with its doc comment, `HandInsSince` and `NoteNewcomer`;
- `read_strings`, `lua_quote`, `_slash_lines` and `write`;
- `emit._header` and `render`;
- `FilterForms`, `FilterAgainOnceNamesArrive`, `SetSectionShut`,
  `ClassSpells.AreRanksOpen` and the map pin `PreClick`.

### Round 2 checks (on `ad43fd19`)

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the Lua files the commits change (Drops.lua, four UI files, 26 dungeon files, two smoke files) | passed |
| `luacheck --no-global -q`, each changed file at `ad43fd19` vs `09ec5966`, warnings compared without line numbers | no new warnings |
| `tests/smoke/check.sh` (dev, packaged, secret values, in combat) | passed: exit 0, "all passed" in all four (699 / 610 / 699 / 699 scenarios ok, one more in each dev run). The new "the game's own offer after a hand-in keeps when and at which level its NPC's list was seen" runs in the three dev runs |
| `tests/smoke/check.sh --locale all` | passed: exit 0 for all 11 clients (enUS 703, the other ten 577 each; the new scenario runs on every client) |
| R1 scenario against the old code (extra, scratch copy with `09ec5966`'s `Drops.lua`) | fails as it should: "a quest a new level opened was put down to a hand-in" |
| `python3 tools/locales.py --check`, `tools/translations.py`, `tools/locale_strings.py --check`, `tools/font_coverage.py --check` | all passed (exit 0) |
| `python3 tools/locale_strings.py --from <dir>` (extra, scratch copy; the 11 GlobalStrings files fetched again from Ketho's `forever` branch) | "647 strings kept for 11 locales". The rewritten `tests/smoke/locales/*.lua` are byte for byte the committed ones, so the new decode-and-quote path changes no value |
| `locale_strings` crafted lines (extra) | `X = "x" .. os.execute(...) .. "y";` is now skipped (`{}`). `OK_Y = "say \"hi\" \\ there";` is kept as `say "hi" \ there`. A `lua_quote` of quotes, a backslash, `\1`, `\127` and a newline reads back in Lua 5.1 unchanged |
| `cd scraper && python3 -m unittest discover -s tests` | passed (378 tests, one more: the dungeon header test) |
| `build --check --category DUNGEON` (extra) | passed (exit 0), every dungeon "kept as it is" |
| `emit` round trip (extra): `emit.render(observed.read_instance(file)) == file` for every `Data/Dungeons/*.lua` | 35 of 35 identical, so `ingest` keeps the new headers and the band lines. `git diff 09ec5966..HEAD -- NeedRoll/Data/Dungeons` changes only `--` header lines |

### Status of each finding

- **R1 · fixed in round 2 (`339f53c4`).**
  - `NoteOffers` (`Drops.lua:3355-3365`) now merges a lone window into the
    snapshot and keeps the whole list's `at` only while it is still whole
    at the same level (`isWhole = last.isWhole and last.level == level`).
    From another level, the snapshot stops counting as whole.
  - The comment gives the reason. The function's doc comment above
    ("a snapshot from another level tells nothing") is now true of the code.
  - The new scenario covers both of round 1's probe cases with asserts: a
    level-up then the game's own offer gives no observation, and at the
    same level both hand-ins stay candidates (`"995974,995975"`). It fails
    on the old code (see Round 2 checks).
  - One side effect, noted rather than a finding. `DropOldest` evicts by
    `at`, which now means "when the whole list was last seen". An NPC
    visited only through the game's own offers can look old and be the
    first of the 400 dropped. The cost is one snapshot taken again at the
    next gossip.
- **R2 · fixed in round 2 (`6b7fc1fd`).**
  - `LINE` now takes an identifier, ` = `, exactly one plain literal
    (`"(?:[^"\\\n]|\\.)*"`) and `;`. `_G["..."]` keys must be identifiers
    too.
  - `read_strings` stores the decoded text (`lua_source.decode`), and
    `write` and `_slash_lines` write it back through `lua_quote`. That
    escapes `"`, `\`, `\n`, `\r`, `\t`, other control characters and DEL
    as `\ddd`, so what the Locale tests `loadfile` can only be strings.
  - Slash commands are now chosen by `re.fullmatch(r"/\S+", text)` on the
    decoded text.
  - `_key`'s `["..."]` form is gone, since every key is an identifier.
    Kept keys are upper-case GlobalStrings names, so a lower-case Lua
    keyword can't be one.
  - The regenerated files match the committed ones exactly.
- **R3 · fixed in round 2 (`1f9f6765`), the header option.**
  - `emit.DUNGEON_HEADER` and `_header` give Classic dungeon files a header
    that says what is true: a build leaves the file as it is, `ingest` adds
    drops, and the band lines are kept by hand, with where the rule lives
    and which test checks them.
  - `recipebands.py`'s docstring and `scraper/README.md` give the steps to
    change a band.
  - `test_newinstances.py` asserts the new header has no override path
    and still counts as generated (`release.is_generated`).
  - No command writes the band lines yet. That was the fuller option and
    stays Mike's call. The header no longer misleads about it.
  - The wording reaches eight files it doesn't fit, and the other frozen
    categories keep the old claim: R9.
- **R4 · left as is: Mike's decision.**
  - Whispered answers stay at 400, and `DAILY_MAX` goes from 500 to 1500
    (`90980b41`, `Drops.lua:1062`; the "daily message cap" scenario
    follows). One probe's answer is now at most 27% of the day, not 80%.
  - Two side effects for Mike:
    - The player's own new finds still queue behind a waiting whispered
      answer for up to about 3 h 20 min.
    - At one message a minute a copy can't reach 1440 non-whisper messages
      in a day, so the cap now binds mainly when whispers are sent.
  - The header comment ("at most one a minute ... and at most DAILY_MAX a
    day", `Drops.lua:16-18`) still holds. The changelog PR should list
    "DAILY_MAX 500 to 1500" in `CHANGELOG-DETAILED.md`.
- **R5 · fixed in round 2 (`b9f2fda0`).** `locale-tests.yml` has top-level `permissions: contents: read`, with a comment saying why. `lua-check.yml` and `smoke-tests.yml` still lack it; that predates this release and was only suggested.
- **R6 · partly fixed (`a2d4052f`): the comment.**
  - The comment at `Lists.lua:2499-2503` now says the filter runs
    `NAME_BURST_SECONDS` after the first name of a burst, and that a later
    name starts the wait again. That matches the code.
  - The shared helper isn't done: `FilterAgainOnceNamesArrive` and
    `OnHoldingsChanged` are still two more of the six hand-rolled
    coalescing timers.
  - The commit gives no reason. It stays a nit for Mike.
- **R7 · fixed in round 2 (`ad43fd19`), the comment option.** `SetSectionShut` (`LootGrid.lua:163-168`) now says why it differs from `ns.SectionMemory.Toggle`: the saved "loot" area always meant "shut", and a section put back to its start is forgotten, so it follows `startsShut` if that changes. The comment matches the code and the saved format, so a reader no longer has to guess why there are two rules.
- **R8 · three of four fixed (`a2d4052f`).**
  - `FilterForms`' comment now says the rules are English but apply on
    every client. Its example ("épées" also tries "épée") is right: "ées"
    has no `[sxz]` before "es", so the plain `s$` rule applies.
  - The map pin macro reads `SLASH_MAPPIN1` directly (`MainFrame.lua:3049`);
    it is in all 11 clients' strings.
  - `ClassSpells.AreRanksOpen` has its comment.
  - The `zhTW.lua:452` character: NeedRoll-Locales main already has "魘"
    (no "魇" left there), so the Translations sync keeps the fix. Checked by
    the release thread after round 2.

### New findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R9 | nit | Readability (§9) | `scraper/needroll_scraper/emit.py:33-50` (`DUNGEON_HEADER`, `_header`); 8 dungeon files' headers; the 43 raid, PvP, faction and profession files' headers; `scraper/tests/test_newinstances.py` (`test_other_instances_keep_the_build_header`) | The new dungeon header names band lines eight dungeons don't have, and the other frozen categories still send corrections to overrides | open |

### R9 · The new dungeon header names band lines eight dungeons don't have, and the other frozen categories still send corrections to overrides
- **Severity:** nit
- **Area:** Readability (§9 no misleading comments; follows R3)
- **Where:** `scraper/needroll_scraper/emit.py:33-50`; the headers of `DireMaulEast.lua`, `DireMaulNorth.lua`, `DireMaulWest.lua`, `LowerBlackrockSpire.lua`, `UpperBlackrockSpire.lua`, `Scholomance.lua`, `StratholmeLive.lua`, `StratholmeUndead.lua`; the 7 `Data/Raids`, 10 `Data/PvP`, 15 `Data/Factions` and 11 `Data/Professions` files; `scraper/tests/test_newinstances.py`
- **Status:** open

**What's wrong.**
- `DUNGEON_HEADER` goes on every Classic dungeon: "its dungeon recipe band
  lines are kept by hand". The bands end at level 55, and these eight files
  list none of `recipe_bands.json`'s recipes (0 band lines each, counted
  against every band's groups and `onlyFrom`).
- R3's header problem is still there for the other categories `build`
  freezes. `FROZEN = ("DUNGEON", "RAID", "PVP", "FACTION", "PROFESSION")`
  (`__main__.py:65`), and `build` drops frozen categories before building
  (`:88-92`). Their 43 files still say "Corrections go in
  scraper/overrides/<ID>.json, then rerun: py -m needroll_scraper build",
  and a build won't apply such a correction. The renamed test even asserts
  that wording for Molten Core. (The 27 Collections files aren't frozen, so
  their header is true.)

**Why it matters.**
- Someone opening Scholomance.lua looks for band lines that aren't there.
- Someone fixing a raid drop edits an override that changes nothing until
  a `--rebuild-without-wowhead`, which drops the raid's Forever data. That
  is the R3 trap, in four more categories. It predates this release, but
  the new header split makes the difference visible, and the new test
  pins it in.

**Evidence.** A script counting band recipe IDs per dungeon file (8 files
with 0). `grep -l "Corrections go in scraper/overrides" -r NeedRoll/Data`:
Collections 27, Factions 15, Professions 11, PvP 10, Raids 7. `__main__.py`
lines quoted above.

**Fix.**
- Word the band clause so it fits every dungeon: "its lines for WoW:
  Forever's dungeon recipe bands, where it has them, are kept by hand".
- Give the other frozen categories the same "a build leaves it as it is
  since Wowhead retired; `ingest` adds the drops players saw" header
  without the band clause, chosen by `inst.category in FROZEN`. Keep
  `HEADER`'s override line for Collections.
- Point the test at a Collections file instead of Molten Core.

### Area notes, round 2

- **Readability.**
  - The new comments explain the reason in plain words: why the snapshot
    keeps its time, why loot sections keep "shut", why the strings are
    quoted again.
  - None narrates the change.
  - No new function nests past three levels.
  - `seenAt` and `lua_quote` say what they are.
  - New: R9.
- **WoW API.**
  - No new game call, event, widget method, template, atlas or `Enum`.
  - One nil guard removed (`SLASH_MAPPIN1 or "/mappin"`). I checked it
    against Ketho's `forever` `GlobalStrings/enUS.lua:19915` and all 11
    clients' strings, not against `wow.lua`.
  - `CHECKED_COMBAT_CALLS` is unchanged, and the `PreClick` still returns
    on `InCombatLockdown()` first. The `--combat` and `--locale all` runs
    passed.
- **Redundant code.** `_key` is gone with nothing left to quote. The two new coalescing timers remain (R6).
- **Security.**
  - R2's injection path is closed and R5's token is read-only.
  - The cap change (R4) raises how many messages a copy may send in a day
    but not its pace: still 60 s between messages, 30 s between whispers.
  - No new untrusted input or output, and no player name touched.

## Round history

- Round 1, 2026-11-11, `09ec5966`: **Changes needed** (0 blocking, 3 should fix, 5 nits). Opened R1–R8.
- Round 2, 2026-11-11, `ad43fd19`: **Changes needed** (0 blocking, 0 should fix, 2 nits open: R6, R9). Closed R1, R2, R3, R5, R7. R4 left as is by Mike's decision (`DAILY_MAX` 1500, whispered answers stay 400). R6 partly fixed (the comment; the shared timer helper not done). R8 fixed (NeedRoll-Locales already had the zhTW character). Opened R9 (nit). Final round: Mike decides on R6 and R9; none blocks the release.
