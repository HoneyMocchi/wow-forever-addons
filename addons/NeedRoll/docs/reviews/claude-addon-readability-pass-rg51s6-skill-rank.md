# Review: Read profession ranks by skill line ID with C_SkillInfo (`ns.UI.SkillRank`)

| | |
| --- | --- |
| Branch | `skill-rank` into `origin/dev` (PR not opened yet) |
| Commit reviewed | `fd599b1` (round 3: `85b479b..fd599b1`, plus the whole group `origin/dev..fd599b1` re-read; round 2 `a7fb791`, round 1 `16d5877`), no uncommitted changes |
| Date | 2026-10-18 |
| Round | 3 (last) |
| Verdict | **Changes needed**, left for Mike after the last round (0 blocking, 1 should fix open: R9; R1-R8 fixed). The code is ready; R9 is CI wiring. The in-game checks are under "For Mike in game" |
| Needs | `/reload` (Lua only: no file added to or removed from the `.toc`, no SavedVariables change) |

## What the change does

Before: `ns.UI.SkillRank(name)` (`NeedRoll/UI/LootGrid.lua`) looked the character's rank
up with the old globals `GetNumSkillLines`/`GetSkillLineInfo`. WoW: Forever doesn't have
them, so behind its nil guard it always returned nil. In game, a Scarce reagent's
"Requires Mining 125" was never coloured against the character's skill, and the recipe
list's rank toggles (`RB:Rank`, `UI/RecipeBand.lua:303`) never showed.

After: `SkillRank` passes `GetProfessions()` (up to five spellbook tab indexes) to a new
helper, `RankAmongProfessions`. The helper calls `GetProfessionInfo(tab)` on each tab and
returns the `skillLevel` of the one whose name equals `name`. The smoke stand-in
`W.SetSkillLines` became `W.SetProfessions`, which drives stand-in `GetProfessions` and
`GetProfessionInfo`. Two scenarios are new or renamed: the four rank colours with a
profession after an empty slot, and "without the profession". The other callers'
`W.SetSkillLines` calls were renamed.

In an English client the colours and toggles now work. In German (Mike's client) and
every other non-English client they still never work (R1), and First Aid gets no rank in
any language (R2).

Round 2 (`cffb27e`, `a7fb791`): `SkillRank` now takes the profession list. It looks up
`SKILL_LINE_IDS[list.id]` (a new table in `LootGrid.lua`, the same numbers as the scraper's
`catalog.py` `PROFESSIONS`) and reads `C_SkillInfo.GetSkillLineInfoByID(id).rank`. No
table, or a rank of 0 or less, counts as not learned. The three callers pass the list, not
its name. The smoke stand-in is a single `C_SkillInfo.GetSkillLineInfoByID` returning the
documented `SkillLineAttributes` table, with `W.SetProfessions` taking
`{ skillLineID, name, rank }`. The scenarios now use German names ("Bergbau", "Angeln",
"Erste Hilfe"), a rank of 0, and First Aid. `implementer.md` dropped the stale example.
German and First Aid now get ranks. Skinning, the twelfth list, still gets none (R5).

Round 3 (`fd599b1`): `SKILL_LINE_IDS` has `SKINNING = 393`, with a comment saying why
Skinning is only there. A new scraper unit test (`scraper/tests/test_professions.py`,
`SkillLineIDsTest`) parses the Lua table and compares it with `catalog.py`'s `PROFESSIONS`
plus Skinning. `SkillRank`'s comment states the reason for its two not-learned cases. The
toggles test no longer sets `W.locale`. A new smoke scenario colours a real Skinning Scarce
source. After this round a skinner sees "Requires Skinning 50" coloured too: every
profession list now gets a rank, in every language.

#### For Mike in game

These can't be checked outside the game. Run them on the German client:

1. On a character **without** Mining: `/dump C_SkillInfo.GetSkillLineInfoByID(186)`.
   Expected: `nil`, or a table with `rank = 0`. Both count as not learned. If it shows a
   rank above 0, `SkillRank` would colour and toggle for a profession the character lacks.
2. On a miner: `/dump C_SkillInfo.GetSkillLineInfoByID(186)`. Expected: a table whose
   `rank` is the Mining skill shown in the profession book, and whose `name` is "Bergbau".
3. On a skinner: `/dump C_SkillInfo.GetSkillLineInfoByID(393)`. Expected: a table with
   the Skinning rank. 393 is the only ID not cross-checked against the scraper's catalog.
4. On a character with First Aid: `/dump C_SkillInfo.GetSkillLineInfoByID(129)`. Expected:
   the First Aid rank. Then open the First Aid recipe list: the Skill-ups / Can learn /
   Hide grey toggles show.
5. On a miner, open Mining → Scarce Reagents → any reagent. Each source's skill number in
   "Requires Mining 125" is coloured against your rank, red to grey. The profession word
   stays English, which is outside this PR (see Area notes).
6. Gain a skill point with the recipe list open. The toggles and colours follow without a
   `/reload`, through `SKILL_LINES_CHANGED`.

## Scope

- `NeedRoll/UI/LootGrid.lua`: `SkillRank` rewritten on `GetProfessions`/`GetProfessionInfo`,
  new local `RankAmongProfessions`.
- `tests/smoke/wow.lua`: `W.SetSkillLines` and its conditional globals removed. Added
  `W.professions`, `W.SetProfessions`, and always-defined `GetProfessions` and
  `GetProfessionInfo` stand-ins.
- `tests/smoke/modules/UI-LootGrid.lua`: the existing Scarce-source test uses
  `W.SetProfessions`. The "no skill-line calls (Forever)" test became "a source's skill
  takes the color of the character's rank past it" (four colours, empty first slot) plus
  "without the profession, a source draws with no rank".
- `tests/smoke/modules/UI-RecipeBand.lua`: `BandTest` saves and restores `W.professions`.
  The toggles and Tailoring tests call `W.SetProfessions`.
- `tests/smoke/scenarios.lua`: four `W.SetSkillLines` calls renamed.
- `tests/smoke/README.md`: dropped the `W.SetSkillLines` example.
- Also read, not changed: `NeedRoll/UI/RecipeBand.lua:240-312` (rank cache,
  `SKILL_LINES_CHANGED`), `NeedRoll/UI/MainFrame.lua:231` (where `entry.profession` comes
  from), `NeedRoll/Core/Names.lua:58-80` (profession labels),
  `NeedRoll/Locales/deDE.lua`, `.claude/agents/implementer.md:90-100`.
- Generated files: none changed. Read `NeedRoll/Data/Professions/*.lua` headers only, for
  how profession lists are named.

Round 2 (`8b4894d..a7fb791`):

- `NeedRoll/UI/LootGrid.lua:358-373`: `RankAmongProfessions` removed. New
  `SKILL_LINE_IDS`, and `SkillRank(profession)` on `C_SkillInfo.GetSkillLineInfoByID`.
  `GatherTexts` (`:413`) and `ShowGatherTooltip` (`:455`) pass `prof`.
- `NeedRoll/UI/RecipeBand.lua:304`: `RB:Rank` passes `instance`.
- `tests/smoke/wow.lua:1408-1428`: `GetProfessions`/`GetProfessionInfo` stand-ins replaced
  by `C_SkillInfo = { GetSkillLineInfoByID = ... }`. `W.SetProfessions` entries are
  `{ skillLineID, name, rank }`.
- `tests/smoke/modules/UI-LootGrid.lua`: entries carry `id = "MINING"`. The colour test
  uses German names and a Herbalism rank of 0.
- `tests/smoke/modules/UI-RecipeBand.lua:178-183`: the toggles test uses a made-up
  `FIRST_AID` list, `W.locale = "deDE"` and `{ 129, "Erste Hilfe", 100 }`.
- `tests/smoke/scenarios.lua:1548`: Tailoring gets its ID 197.
- `.claude/agents/implementer.md:98`: example dropped.
- Also read for round 2: `NeedRoll/Data/Data.lua:396-446` (Scarce registration and the
  hand-built `SKINNING` list), `NeedRoll/Data/ScarceReagents.lua`, `NeedRoll/UI/MainFrame.lua:226-233`
  (`ScarceEntries`), `NeedRoll/UI/RecipeBand.lua:100-120, 200-215, 240-335, 430-440`
  (schemes, caches, `Narrow`, `GetLocale` use), `scraper/needroll_scraper/catalog.py:971-999`
  (`ProfessionDef.skill_line`, `PROFESSIONS`), `scraper/needroll_scraper/emit.py:43-75`
  (`render`).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the five changed Lua files | passed |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | ran, exit 0 (reports pre-existing "not used by NeedRoll any more" keys, none from this change) |
| `luacheck --no-global -q`, changed vs `origin/dev` | no new warnings: `LootGrid.lua` 0/0, `wow.lua` 101/101, `UI-LootGrid.lua` 1/1, `UI-RecipeBand.lua` 2/2, `scenarios.lua` 70/70 |
| `tests/smoke/check.sh` | passed: dev, packaged and secret-values runs all print "all passed" (938 `ok` lines) |
| New scenarios against the base `LootGrid.lua` | in a scratch copy with `origin/dev`'s `LootGrid.lua`, two fail: `UI-LootGrid.lua:368: skill ranks` and `scenarios.lua:1571: no toggles for a tailor`. The tests do guard the bug |
| German-name probe | in a scratch copy of `16d5877`, the "rank past it" test given `{ "Bergbau", 140 }`/`{ "Angeln", 1 }` (what a German client returns) fails at `UI-LootGrid.lua:402: a rank past an empty slot` (R1) |
| Scraper unit tests | not run: no scraper change |
| **Round 2** (`a7fb791`) | |
| `luac5.1 -p` on the six changed Lua files (adds `RecipeBand.lua`) | passed |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | ran, exit 0 |
| `luacheck --no-global -q`, changed vs `origin/dev` | no new warnings: `LootGrid.lua` 0/0, `RecipeBand.lua` 10/10, `wow.lua` 101/101, `UI-LootGrid.lua` 1/1, `UI-RecipeBand.lua` 2/2, `scenarios.lua` 70/70 |
| `tests/smoke/check.sh` | passed: dev, packaged and secret-values runs all "all passed" (938 `ok` lines) |
| New scenarios against round 1's `LootGrid.lua`/`RecipeBand.lua` | not meaningful: with the `GetProfessions` stand-in gone, round 1's code errors on `attempt to call global 'GetProfessions'` in every page scenario. Round 1's German probe already showed the name match fails |
| Skinning probe (R5) | in a scratch copy of `a7fb791`, `W.SetProfessions({ { 393, "Kürschnerei", 150 } })` then `ns.UI.SkillRank(ns.Data:Get("SKINNING")) == 150` fails (`UI-LootGrid.lua:429: PROBE: no Skinning rank`) |
| Scraper unit tests | not run: no scraper change in round 2 |
| **Round 3** (`fd599b1`) | |
| `luac5.1 -p` on the six changed Lua files | passed |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | ran, exit 0 |
| `luacheck --no-global -q`, changed vs `origin/dev` | no new warnings: `LootGrid.lua` 0/0, `RecipeBand.lua` 10/10, `wow.lua` 101/101, `UI-LootGrid.lua` 1/1, `UI-RecipeBand.lua` 2/2, `scenarios.lua` 70/70 |
| `tests/smoke/check.sh` | passed: dev, packaged and secret-values runs all "all passed" (941 `ok` lines, 3 more than round 2: the Skinning scenario in each run) |
| `cd scraper && python3 -m unittest discover -s tests` | passed: `Ran 157 tests ... OK`. `SkillLineIDsTest` alone: `Ran 1 test ... OK` |
| `SkillLineIDsTest` against broken tables (scratch copies of `fd599b1`) | fails each time, with `AssertionError` and a dict diff: `MINING = 187`; `SKINNING` removed; `["MINING"] = 186` (bracket form, not parsed so missing); a `-- OLD = 1` comment inside the table (parsed as an extra key). No case passes silently |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | blocking | WoW API | `NeedRoll/UI/LootGrid.lua:358-375` | Ranks are matched on the English list name, so no rank is found in German or any other non-English client | fixed in round 2 (`cffb27e`) |
| R2 | should fix | WoW API | `NeedRoll/UI/LootGrid.lua:372-374` | `GetProfessions` has no First Aid slot in Forever, so First Aid never gets a rank | fixed in round 2 (`cffb27e`) |
| R3 | should fix | Readability | `.claude/agents/implementer.md:98` | Implementer guide still points to the removed `W.SetSkillLines` | fixed in round 2 (`a7fb791`) |
| R4 | nit | WoW API | `tests/smoke/wow.lua:1423-1428` | `GetProfessionInfo` stand-in lists ten returns and gives `skillLine` 0; Forever returns eleven and a real ID | fixed in round 2 (`cffb27e`) |
| R5 | should fix | WoW API | `NeedRoll/UI/LootGrid.lua:360-363` | `SKILL_LINE_IDS` has no `SKINNING`, so Skinning's Scarce sources never get a rank colour | fixed in round 3 (`fd599b1`) |
| R6 | should fix | Redundant code | `NeedRoll/UI/LootGrid.lua:358-363`, `scraper/needroll_scraper/catalog.py:986-999` | The skill line IDs are kept twice, by hand, with nothing tying the copies together | fixed in round 3 (`fd599b1`), the alternative route: a test ties the copies (but see R9) |
| R7 | nit | Readability | `NeedRoll/UI/LootGrid.lua:365-367` | `SkillRank`'s comment says what "isn't known yet" instead of why the code checks both cases | fixed in round 3 (`fd599b1`) |
| R8 | nit | Readability | `tests/smoke/modules/UI-RecipeBand.lua:178-182` | `W.locale = "deDE"` in the toggles test has no effect on what it checks | fixed in round 3 (`fd599b1`) |
| R9 | should fix | Redundant code (the check that keeps the two ID copies in step) | `scraper/tests/test_professions.py:334-345`, `.github/workflows/` | The new ID check runs in no pull-request workflow, only in the daily data update on `main` | open: Mike decides |

Findings R5-R8 are new in round 2, R9 in round 3. Earlier findings are kept as written,
with their status updated.

### R1 · Ranks are matched on the English list name, so no rank is found in German or any other non-English client

- **Severity:** blocking
- **Area:** WoW API
- **Where:** `NeedRoll/UI/LootGrid.lua:358-375`. Callers: `LootGrid.lua:415` and `:457`
  (`SkillRank(prof.name)`) and `UI/RecipeBand.lua:304` (`ns.UI.SkillRank(instance.name)`)
- **Status:** fixed in round 2 (`cffb27e`). `SkillRank(profession)` looks up
  `SKILL_LINE_IDS[profession.id]` and `C_SkillInfo.GetSkillLineInfoByID`, with no name
  comparison left. All three callers pass the list: `LootGrid.lua:413` and `:455` pass
  `prof` (= `entry.profession`, the list from `MainFrame.lua:231`), and `RecipeBand.lua:304`
  passes `instance` (guarded to `category == "PROFESSION"` in `Narrow`, `:329`). The
  scenarios now give German names (`UI-LootGrid.lua:402`, `UI-RecipeBand.lua:182`), and they
  pass. The display-only `prof.name` in "Requires Mining 125" is unchanged (Area notes)

**What's wrong.** The match compares the game's profession name with the addon's list name:

```lua
local professionName, _, skillLevel = GetProfessionInfo(tabIndex)
if professionName == name then return skillLevel end
```

`name` is always the list's `name` field, and every list sets it in English, in generated
data: `NeedRoll/Data/Professions/Mining.lua` registers `id = "MINING", name = "Mining"`, and
so on. The addon translates these names only for display, through its own `L[]` table
(`Core/Names.lua:74-76`: `["Mining"] = L["Mining"]`, with `deDE.lua:88`
`L["Mining"] = "Bergbau"`). `GetProfessionInfo` returns the client's localized name, which
is "Bergbau" in a German client. "Bergbau" never equals "Mining", so `SkillRank` returns nil.

**Why it matters.** Mike plays on a German client. On it, this PR changes nothing: the
Scarce-reagent "Requires Mining 125" stays uncoloured, and the recipe list's rank toggles
stay hidden for every profession. That is the same as before the fix. Players in French,
Spanish, Russian, Korean, Chinese and other locales see the same. Even matching on
`L[name]` would only work while each community translation happens to spell the name
exactly as Blizzard does. The game's name isn't the addon's to guarantee. The comment
`-- The character's rank in a profession ("Mining")` also suggests that any name works.

**Evidence.**
- Read: `MainFrame.lua:231` builds `{ gather = src, profession = inst }`, so `prof` is the
  list table. `RecipeBand.lua:304` passes `instance.name`.
- `grep '    id = "' NeedRoll/Data/Professions/*.lua`: every list has an English upper-case
  `id` and an English `name`.
- Probe: the new test given German names fails (see Checks, "German-name probe").
- Forever's own profession book reads the skill line ID from the same call:
  `Gethe/wow-ui-source@forever`,
  `Interface/AddOns/Blizzard_ProfessionsBook/Blizzard_ProfessionsBook.lua:125`:
  `local name, texture, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier, specializationIndex, specializationOffset, skillLineName = GetProfessionInfo(index);`.
- Neither the data nor the scraper carries a skill line ID today:
  `grep -rln "skillLine\|skillID" NeedRoll scraper/needroll_scraper tools` finds nothing
  outside this change. *Correction in round 2:* this grep missed the scraper's snake_case
  field. `scraper/needroll_scraper/catalog.py:975` has `skill_line: int` on
  `ProfessionDef`, with the IDs at `:986-999`, used for Wowhead skill pages
  (`merge.py:246`). The generated Lua doesn't carry them. See R6.

**Fix.** Match on the skill line ID, not the name. The IDs are fixed game IDs, so a small
named table keyed by list `id` is enough. If Mike prefers, the scraper could write them into
each list instead. Both callers have the list table, so pass that:

```lua
-- Each profession list's skill line ID, the same in every language.
local SKILL_LINE_IDS = {
    ALCHEMY = 171, BLACKSMITHING = 164, COOKING = 185, ENCHANTING = 333,
    ENGINEERING = 202, FIRST_AID = 129, FISHING = 356, HERBALISM = 182,
    LEATHERWORKING = 165, MINING = 186, SKINNING = 393, TAILORING = 197,
}

-- The character's rank in a profession list, or nil when they haven't learned it.
local function SkillRank(profession)
    local skillLineID = SKILL_LINE_IDS[profession.id]
    local skillLine = skillLineID and C_SkillInfo.GetSkillLineInfoByID(skillLineID)
    return skillLine and skillLine.rank
end
```

This uses `C_SkillInfo` (see R2 for why), and the name loop and `RankAmongProfessions` go
away. If Mike decides to stay on `GetProfessions`, compare `GetProfessionInfo`'s 7th
return (`skillLine`) with `SKILL_LINE_IDS[profession.id]` instead of the name. Callers
become `SkillRank(prof)` and `ns.UI.SkillRank(instance)`. The smoke stand-in must return
real IDs (R4). Add a scenario that sets `W.locale = "deDE"` with German names from the
stand-in and asserts the rank is still found.

The skill line IDs above are from memory of the game's SkillLine table, not from a file I
checked. (Round 2: the eleven that `catalog.py` has match; it has no Skinning, see R5.) Confirm them in game with
`/dump C_SkillInfo.GetSkillLineInfoByID(186)` (or `/dump select(7, GetProfessionInfo(prof1))`).

### R2 · `GetProfessions` has no First Aid slot in Forever, so First Aid never gets a rank

- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/UI/LootGrid.lua:372-374`. Also the stand-in's slot comment,
  `tests/smoke/wow.lua:1408-1411`
- **Status:** fixed in round 2 (`cffb27e`). `FIRST_AID = 129` in `SKILL_LINE_IDS`, read
  through `C_SkillInfo`. Both possible not-learned answers (nil, or `rank` 0) count as not
  learned, and the rank-0 case has a test (`UI-LootGrid.lua:405`). The toggles test runs on a
  `FIRST_AID` list (`UI-RecipeBand.lua:179`). The in-game `/dump` check is still Mike's to
  do; see R7

**What's wrong.** `GetProfessions()` returns five slots: prof1, prof2, archaeology,
fishing, cooking. Retail dropped First Aid from it in 8.0.1, and Forever's client keeps the
five-slot shape. The addon has a First Aid recipe list (`Data/Professions/FirstAid.lua`,
`id = "FIRST_AID"`, with Forever-only recipes such as `S1230117` "First Aid Kit"), and
Forever characters learn First Aid. `RankAmongProfessions` can never see it.

**Why it matters.** On the First Aid recipe list, `RB:Rank(inst)` is always nil, so the
rank toggles (Hide grey, skill-ups) never show, in English too. The fix's purpose ("the
recipe list's rank toggles") holds for 10 of the 11 lists.

**Evidence.**
- `Gethe/wow-ui-source@forever`, `Blizzard_ProfessionsBook.lua:52`:
  `local prof1, prof2, arch, fish, cook = GetProfessions();`. Forever's own profession book
  has no First Aid slot. Whether First Aid really never appears in Forever's
  `GetProfessions` is inferred from this, not tested in game.
- Ketho `forever` `GlobalAPI.lua:3812` `"C_SkillInfo.GetNumSkillLines"`, `:3814`
  `"C_SkillInfo.GetSkillLineInfo"`, `:3815` `"C_SkillInfo.GetSkillLineInfoByID"`. Global
  `GetNumSkillLines`/`GetSkillLineInfo` are not in the list.
- Return shape, from `Gethe/wow-ui-source@forever`,
  `Blizzard_APIDocumentationGenerated/SkillInfoDocumentation.lua`: the call returns one
  value, not several. `GetSkillLineInfo(index)` and `GetSkillLineInfoByID(ID)` each
  return a single `skillLineAttributes` table (`SkillLineAttributes`, `Nilable = true`)
  with fields `skillID`, `name`, `isHeader`, `isCollapsed`, `rank`, `tempPoints`,
  `modifier`, `maxRank`, `isAbandonable`, ..., `parentSkillLineID`,
  `skillLineCategoryID`, `description`. Neither has `SecretArguments` restrictions that
  apply to an untainted addon (`AllowedWhenUntainted`). The same file on the `live` and
  `classic_era` branches defines no functions, only the event. This is a Forever addition.
- Ketho's `forever` `FrameXML.lua` has no skill frame (`grep -i "skillframe\|SkillUI"`:
  nothing). Blizzard's UI doesn't call these functions, so how they behave for a skill the
  character hasn't learned is not shown anywhere I could read.

**Fix / recommendation.** `C_SkillInfo` is the more complete route. It covers First Aid,
and it covers both gathering and crafting professions in one call keyed by ID, which also
fixes R1. Use `C_SkillInfo.GetSkillLineInfoByID(skillLineID)` as sketched in R1. It needs
no loop, and collapsed headers can't hide a line, which they can for the index-based
`GetNumSkillLines`/`GetSkillLineInfo` pair (classic skill-frame behaviour, inferred).
Before committing, Mike should check one case in game: on a character without Mining,
`/dump C_SkillInfo.GetSkillLineInfoByID(186)` should print nil. If it returns a table with
`rank = 0` instead, treat it as not learned (`if skillLine and skillLine.rank > 0`). If it
returns nothing useful at all, fall back to looping `C_SkillInfo.GetNumSkillLines()` /
`GetSkillLineInfo(i)` and matching `info.skillID` on non-header lines. Either way, put
`C_SkillInfo` stand-ins in `wow.lua` in place of the `GetProfessions` pair, and add a
scenario on the First Aid list.

### R3 · Implementer guide still points to the removed `W.SetSkillLines`

- **Severity:** should fix
- **Area:** Readability (consistency of the repo's own docs)
- **Where:** `.claude/agents/implementer.md:98`
- **Status:** fixed in round 2 (`a7fb791`): the line now ends "puts them in itself.".
  `grep -rn SetSkillLines` outside `docs/reviews/` finds nothing

**What's wrong.** The guide tells the implementer that a scenario about guarded code
"puts them in itself (as `W.SetSkillLines` does)." This PR removes `W.SetSkillLines`, and
`tests/smoke/README.md` already dropped the same example. The sentence now points to
code that no longer exists.

**Why it matters.** The next implementer agent follows `implementer.md` literally. It will
look for `W.SetSkillLines` to copy, find nothing, and may write the old-global stand-in
back into `wow.lua`.

**Evidence.** `grep -rn SetSkillLines` outside `docs/reviews/` finds only
`.claude/agents/implementer.md:98`.

**Fix.** Drop the parenthetical, as `tests/smoke/README.md` did:
"...a scenario about the code behind such a guard puts them in itself and takes them out
after." Commit it in this PR.

### R4 · `GetProfessionInfo` stand-in lists ten returns and gives `skillLine` 0; Forever returns eleven and a real ID

- **Severity:** nit (becomes needed with R1's fix if `GetProfessions` stays)
- **Area:** WoW API
- **Where:** `tests/smoke/wow.lua:1423-1428`
- **Status:** fixed in round 2 (`cffb27e`): both stand-ins removed. The new
  `C_SkillInfo.GetSkillLineInfoByID` (`wow.lua:1416-1428`) returns a table with all 16
  documented `SkillLineAttributes` fields (`skillID`, `name`, `isHeader`, `isCollapsed`,
  `rank`, `tempPoints`, `modifier`, `maxRank`, `isAbandonable`, `stepCost`, `rankCost`,
  `minLevel`, `costType`, `parentSkillLineID`, `skillLineCategoryID`, `description`). The
  types match: numbers, bools, strings. It returns nil for a skill not in the list, which is
  one of the two behaviours the code allows for

**What's wrong.**

```lua
-- name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset,
-- skillLine, skillModifier, specializationIndex, specializationOffset
function GetProfessionInfo(tabIndex)
    ...
    return profession[1], 134400, profession[2], 300, 2, 0, 0, 0, -1, 0
```

Forever's caller reads an 11th value, `skillLineName`
(`Blizzard_ProfessionsBook.lua:125`, quoted in R1). Every profession gets `skillLine` 0.

**Why it matters.** The stand-in is meant to return what the game returns
(`implementer.md`: "returning what the game returns"). With `skillLine` always 0, an
ID-based match can't be tested at all. With R2's fix the pair goes away, and so does this
finding.

**Evidence.** Lines read. Forever source as quoted.

**Fix.** If `GetProfessions` stays, take a skill line ID in `W.SetProfessions`'
`{ name, rank, skillLineID }` entries, return it as the 7th value, add `skillLineName` as
the 11th, and list eleven names in the comment. If R2's route is taken, remove both
stand-ins and add `C_SkillInfo.GetSkillLineInfoByID` returning `{ skillID, name, rank, ... }`.

### R5 · `SKILL_LINE_IDS` has no `SKINNING`, so Skinning's Scarce sources never get a rank colour

- **Severity:** should fix
- **Area:** WoW API
- **Where:** `NeedRoll/UI/LootGrid.lua:360-363`. The list itself is built at
  `NeedRoll/Data/Data.lua:406-407`
- **Status:** fixed in round 3 (`fd599b1`). `SKINNING = 393` is in the table (`LootGrid.lua:363`),
  and the comment over it says why only there (`:359-360`). The new scenario "Skinning's
  Scarce sources are colored against the character's skill" (`UI-LootGrid.lua:425-443`) uses
  the real `ns.Data:Get("SKINNING")` and its first Scarce source (Pristine Leather from
  Daggerfang, skill 50, after `RegisterScarce`'s lowest-first sort). It gives rank
  skill + 30 under the German name "Kürschnerei" and expects `levelFair`. The scenario
  reads generated `ScarceReagents.lua`, so it would fail, with its own message ("no Skinning
  list with a Scarce source"), if the data ever dropped Skinning. That file's builder
  (`scarce --wowhead`) is retired, so this is unlikely (inferred). 393 still needs the
  in-game `/dump` (For Mike in game, 3)

**What's wrong.** The table has eleven entries, and Skinning isn't one of them:

```lua
local SKILL_LINE_IDS = {
    ALCHEMY = 171, BLACKSMITHING = 164, COOKING = 185, ENCHANTING = 333, ENGINEERING = 202, FIRST_AID = 129,
    FISHING = 356, HERBALISM = 182, LEATHERWORKING = 165, MINING = 186, TAILORING = 197,
}
```

Skinning has no generated list, so `catalog.py`'s `PROFESSIONS` doesn't list it either. The
addon builds one itself. `Data.lua:406` defines
`local SKINNING = { id = "SKINNING", name = "Skinning", category = "PROFESSION", ... }`, and
`RegisterScarce` (`:420-428`) registers it when a Scarce reagent names `SKINNING`. Two do
(`ScarceReagents.lua:29` Pristine Hide, `:32` Pristine Leather). Their sources carry skills:
Maddened Rotclaw 125, Daggerfang 50, Lakota'mani 110, Thunderstomp 120. `ScarceEntries`
(`MainFrame.lua:228-232`) passes that `SKINNING` list as `entry.profession`, so
`SkillRank` gets `id = "SKINNING"`, finds no ID and returns nil.

**Why it matters.** A skinner opening Skinning → Scarce Reagents → Pristine Leather sees
"Requires Skinning 110" in plain text for every mob. Mining and Herbalism sources on the
same kind of page are coloured red/orange/yellow/green/grey. This is the same symptom the
PR fixes, on the one gathering list it leaves out. Skinning is a Scarce-only list, so the
colour is the only thing a rank does there.

**Evidence.** Lines read as quoted. Probe: with `{ 393, "Kürschnerei", 150 }` set,
`ns.UI.SkillRank(ns.Data:Get("SKINNING"))` is nil (see Checks). The round-1 sketch had
`SKINNING = 393`. 393 is Skinning's skill line ID from memory of the game's SkillLine table
(Wowhead `skill=393`), not checked against a file. Confirm with
`/dump C_SkillInfo.GetSkillLineInfoByID(393)` on a skinner.

**Fix.** Add `SKINNING = 393`, wherever the IDs end up (R6). If the IDs move onto the lists,
put `skillLine = 393` on the hand-built `SKINNING` table in `Data.lua:406`. Add a scenario:
a Skinning Scarce source coloured against a `{ 393, ..., rank }` profession, through
`ns.Data:Get("SKINNING")` after `RegisterScarce`.

### R6 · The skill line IDs are kept twice, by hand, with nothing tying the copies together

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/LootGrid.lua:358-363` and `scraper/needroll_scraper/catalog.py:986-999`
- **Status:** fixed in round 3 (`fd599b1`), by the acceptable route below, not the
  preferred one: the addon keeps its table, and `SkillLineIDsTest`
  (`scraper/tests/test_professions.py:334-345`) checks it equals `catalog.py`'s IDs plus
  `SKINNING: 393`. The parse is sound (R9's section and Checks). That leaves when the test
  runs: R9

**What's wrong.** The scraper already knows each list's skill line (`ProfessionDef.skill_line`,
`catalog.py:975`, used for Wowhead's skill pages at `merge.py:246`). The addon now has a
second, hand-typed copy keyed by the same list IDs. The only link between them is a
comment: `-- (the scraper's catalog.py PROFESSIONS has the same numbers)`. Nothing checks
that. The generated files say "do not edit by hand"
(`Data/Professions/Mining.lua:1`), and the generator writes every other per-list fact
(`id`, `name`, `category`, `zone`, `factionID`, `levelRange`; `emit.py:43-56`). The skill
line is a per-list fact that skipped it. R5 shows the drift already: the two copies cover
the same eleven lists, so neither noticed the twelfth.

**Why it matters.** Today the numbers agree (eleven of eleven checked), and game IDs don't
change, so nothing breaks now. The risk is the next list. Say a profession is added to
`catalog.py` (Forever's new professions, or Skinning given recipes). The scraper builds its
list, and the addon gives it no rank until someone remembers `LootGrid.lua`. Nothing fails:
no test, no warning, just plain text and no toggles. `docs/READABLE-CODE.md` asks for one
way of doing each thing. Two sources for the same ID is two ways.

**Evidence.** `catalog.py:986-999` read. The values compare equal to
`LootGrid.lua:360-363`, one by one. `grep -rn "skill_line" scraper/needroll_scraper`: catalog
and merge only, nothing in `emit.py`.

**Fix.** Preferred: the generator writes the ID, and the addon reads it from the list.

- `scraper/needroll_scraper`: carry `skill_line` onto the `Instance` for profession lists,
  and in `emit.render` add `if inst.skill_line: lines.append(f"    skillLine = {inst.skill_line},")`.
  Regenerate the eleven `Data/Professions/*.lua` with `build`, not by hand.
- `NeedRoll/Data/Data.lua:406`: `skillLine = 393` on the hand-built `SKINNING` (R5).
- `LootGrid.lua`: delete `SKILL_LINE_IDS`. `SkillRank` reads `profession.skillLine`:

```lua
-- The character's rank in a profession list, or nil when they haven't
-- learned it. The list's skill line ID is the same in every language.
local function SkillRank(profession)
    local skillLine = profession.skillLine and C_SkillInfo.GetSkillLineInfoByID(profession.skillLine)
    if skillLine and skillLine.rank > 0 then return skillLine.rank end
end
```

- Document `skillLine` in `Data.lua`'s list-shape comment and add a scraper unit test that
  every `ProfessionDef` emits it.

Acceptable if Mike would rather not regenerate data in this PR: keep the addon table, add
`SKINNING` (R5), and add a scraper unit test that reads `LootGrid.lua`'s `SKILL_LINE_IDS`
with an anchored pattern and compares it with `PROFESSIONS`. Then a new profession fails a
test instead of failing silently in game.

### R7 · `SkillRank`'s comment says what "isn't known yet" instead of why the code checks both cases

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/UI/LootGrid.lua:365-367`
- **Status:** fixed in round 3 (`fd599b1`): the comment is now the suggested one, stating
  the reason (`LootGrid.lua:366-368`)

**What's wrong.**

```lua
-- The character's rank in a profession list, or nil when they haven't
-- learned it. What the game returns for a skill not learned isn't known yet,
-- so no skill line and a rank of 0 both count as not learned.
```

"Isn't known yet" describes the state of the investigation, not the code. It goes stale
once Mike runs the `/dump`. A newcomer also can't tell whether the `rank > 0` test is
there for a real case or as a placeholder to delete.

**Why it matters.** `docs/READABLE-CODE.md`: comments say why, and they don't narrate the
change. A comment that's true only until someone checks will become misleading.

**Fix.** State the reason, which holds either way:

```lua
-- GetSkillLineInfoByID's table is nilable, and a skill line can list at
-- rank 0: either way the character hasn't learned the profession.
```

Or, after Mike's in-game check, keep only the case the game really has and say which it
is.

### R8 · `W.locale = "deDE"` in the toggles test has no effect on what it checks

- **Severity:** nit
- **Area:** Readability
- **Where:** `tests/smoke/modules/UI-RecipeBand.lua:178-182`
- **Status:** fixed in round 3 (`fd599b1`): the line is gone. The German stand-in name
  carries the case, as in `UI-LootGrid.lua`

**What's wrong.**

```lua
-- First Aid in a German client: found by its skill line, not its name.
local inst = Profession("FIRST_AID", "First Aid", { header, grey, skillUp, tooHigh, noSkill })
local list = inst.encounters
W.locale = "deDE"
W.SetProfessions({ { 129, "Erste Hilfe", 100 } })
```

`W.locale` only changes what `GetLocale()` returns from then on (`wow.lua:1207`).
`SkillRank` and the `C_SkillInfo` stand-in never call it, and `L` was loaded at login. The
only code in `RecipeBand.lua` that calls `GetLocale()` is `RB:Note` (`:438`, rank-line
notes), which this test doesn't reach. What makes the test "German" is the name
`"Erste Hilfe"` in the stand-in, and that is enough. `BandTest` restores `W.locale`, so
nothing leaks.

**Why it matters.** A reader takes the line as part of what's tested. If someone later
removes the name, or makes `SkillRank` ignore the name entirely (as it already does), the
line still suggests the test covers German clients.

**Fix.** Remove `W.locale = "deDE"`. The German stand-in name and the comment carry the
case. In `UI-LootGrid.lua:401-402`, the German-name colour test does the same without
setting a locale, so this also makes the two tests consistent.

### R9 · The new ID check runs in no pull-request workflow, only in the daily data update on `main`

- **Severity:** should fix
- **Area:** Redundant code (the check that keeps R6's two copies in step)
- **Where:** `scraper/tests/test_professions.py:334-345`. The workflows: `.github/workflows/daily-data.yml:100`,
  `loot-data-check.yml:76`, `smoke-tests.yml`, `lua-check.yml`
- **Status:** open: Mike decides (last round)

**What's wrong.** The test itself is robust:
- It finds the table by an anchored `local SKILL_LINE_IDS = \{(.*?)\}`. The table has no
  nested braces, so the non-greedy match ends at its own `}`.
- It reads `NAME = number` pairs and compares the whole dict with `assertEqual`, so any
  parse miss or extra entry fails instead of passing.
- It finds `LootGrid.lua` from `__file__` (`parents[2]`), not the working directory.
- It needs nothing beyond the standard library and the scraper package, the same as the
  other 156 tests.

The gap is when it runs. `python -m unittest discover -s tests` runs in only two workflows:
- `daily-data.yml:100` ("Test the scraper"): on the 09:00 UTC schedule, checking out
  `ref: main` (`:70`).
- `loot-data-check.yml:76`: called only from the hand-run `loot-*.yml` workflows.

The workflows that run on pull requests are `smoke-tests.yml` (`tests/smoke/check.sh` only)
and `lua-check.yml` (`luac5.1`, `locales.py`, `translations.py`). Neither runs the scraper's
unit tests.

**Why it matters.** Say a later PR adds a profession to `catalog.py`, or edits one ID in
`SKILL_LINE_IDS`, and the other copy isn't touched. The PR's checks are all green and it
merges into `dev`. Nothing fails until Mike merges `dev` into `main`. Then the next daily
run stops at "Test the scraper", before "Build every category". That day's data commit,
QuestieDB comparison and release don't happen, and the error points at an addon file the
data run doesn't own. Meanwhile, in game, the new profession quietly gets no rank. The
check that replaced R6's preferred fix is meant to catch exactly that, and it catches it
late and in the wrong place.

**Evidence.** Read all of `smoke-tests.yml`, `lua-check.yml` (`on.pull_request.paths:
["NeedRoll/**.lua", "tools/locales.py", "tools/translations.py"]`), `daily-data.yml` and
`loot-data-check.yml`. `grep -rln unittest .github/workflows`: only `daily-data.yml` and
`loot-data-check.yml`. That no PR ever runs scraper tests is read from these files. Branch
protection settings themselves weren't checked.

**Fix.** Run the scraper tests on pull requests that touch either copy. For example, a
`scraper-tests.yml`:

```yaml
name: Scraper tests
on:
  pull_request:
    paths: ["scraper/**", "NeedRoll/UI/LootGrid.lua"]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: scraper
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Install Lua 5.1
        run: sudo apt-get update -q && sudo apt-get install -y -q lua5.1
      - name: Test the scraper
        run: python -m unittest discover -s tests
```

The sketch uses `pull_request`, not `pull_request_target`, with `contents: read` and no
`github.event` text in `run:`. If Mike doesn't want a required check here, don't add it to
branch protection: a path-filtered required check blocks PRs that skip it (the reason
`smoke-tests.yml` has no filter). Keep it advisory. Or, smaller still, add a "Scraper tests"
job to `lua-check.yml` with its paths widened to `scraper/**`.

## Area notes

### Readability

- `RankAmongProfessions` and `SkillRank` are short and use game terms (`tabIndex`,
  `professionName`, `skillLevel`). Each has a why-comment at the file's usual density. The
  vararg walk (`select("#", ...)`) is correct for `GetProfessions`' nil holes, where `{...}`
  with `#` would be the Lua 5.1 trap. With R1/R2's fix the helper disappears, which is less
  code.
- The `SkillRank` comment's example `("Mining")` misleads in a localized client (R1).
- Smoke changes are a consistent rename. `BandTest` saves `W.professions` and restores it
  through `W.SetProfessions` (`UI-RecipeBand.lua:16-19`). `W.professions` now defaults to
  `{}`, so the save/restore can't hit nil. The new colour test is table-driven with named
  colours (`color.levelHard`...), not repeated blocks.
- `tests/smoke/README.md:36-39` still reads as a sentence after dropping the example.
  `implementer.md` is the one place left behind (R3).
- 4-space indents, LF, `local` for all new functions. No `cond and nil or x`, and no
  patterns built from data.
- Not in the diff, so not a finding: `GatherTexts` (`LootGrid.lua:415-416`) and
  `ShowGatherTooltip` (`:458`) display `prof.name` raw ("Requires Mining 125"), not
  through `ns.Names`. A German player sees "Mining" in that line. Worth a look when R1 is
  fixed, since the same lines change.
- Round 2: re-read `SkillRank`, `GatherTexts`, `ShowGatherTooltip`, `RB:Rank`, `RB:Narrow`
  and every changed test in full. `SkillRank` is three lines with a guard and no nesting,
  and its names are game terms (`skillLineID`, `skillLine`, `rank`). `SKILL_LINE_IDS` is a
  named, searchable constant. The stand-in's `local id, name, rank = unpack(profession)` reads
  clearly, and `unpack` is the Lua 5.1 global. `"Requires %s %s"` still shows `prof.name`
  raw (above), and round 2 didn't change that. New: R7 (comment), R8 (test line).
- Round 2, the made-up `FIRST_AID` list in the toggles test shares `states["FIRST_AID"]`
  and the `FIRST_AID` grouping scheme (`RecipeBand.lua:118, 205`) with the real list.
  `BandTest` resets the real list's state afterwards (`UI-RecipeBand.lua:20-24`), so
  nothing leaks, and the test's asserts don't depend on chips. This is sound, but it is a
  coupling to keep in mind if the First Aid scheme changes.
- Round 3, whole group re-read (`origin/dev..fd599b1`): `SkillRank`, `SKILL_LINE_IDS`, the
  two `LootGrid` callers, `RB:Rank`, the stand-in and all eight changed scenarios.
  - `SkillRank` is three lines with a guard. Its comment now gives the reason, and the
    table's comment says where the numbers are checked and why Skinning is only there.
  - The Skinning scenario follows the colour tests' shape (`RestoringTest`, `Made`,
    `HideMade`). It reads its source from real data rather than repeating literal numbers.
  - The scraper test's names (`loot_grid`, `addon_ids`, `catalog_ids`) say what they hold,
    and its docstring explains the Skinning exception.
  - Nothing new to ask for in the code.

### WoW API

| Call / event | Kind | In Ketho `forever` lists | Where looked |
| --- | --- | --- | --- |
| `GetProfessions` | global function | yes | `GlobalAPI.lua:5741` |
| `GetProfessionInfo` | global function | yes | `GlobalAPI.lua:5740`. Return shape from `Gethe/wow-ui-source@forever` `Blizzard_ProfessionsBook.lua:125` |
| `SKILL_LINES_CHANGED` (already registered, `RecipeBand.lua:307`) | event | yes | `Events.lua:1696` |
| `GetNumSkillLines`, `GetSkillLineInfo` (removed calls) | global function | **no** | only `C_SkillInfo.*` at `GlobalAPI.lua:3812/3814` |
| `C_SkillInfo.GetSkillLineInfoByID` (round 2: now called, `LootGrid.lua:370`) | `C_` function | yes | `GlobalAPI.lua:3815`. Shape from Forever `SkillInfoDocumentation.lua`: one nilable `SkillLineAttributes` table, `rank` non-nilable number. `SecretArguments = "AllowedWhenUntainted"` concerns the argument, and an addon's own call is untainted |

- The removed nil guard is right to go: the new calls are in the `forever` list, checked
  against Ketho and not against `wow.lua`. `wow.lua` no longer defines the old globals in
  any path.
- Secret values: `GetProfessionInfo` on the player's own spellbook isn't secret, and the
  name comparison is on the player's own data (inferred: no `SecretReturns` noted in any
  Forever source I read).
- No new events, no frames, no combat-sensitive or protected calls, no globals. No UI
  change, so `docs/STYLE-GUIDE.md` doesn't apply.
- Cache: `RB:Rank` caches per list until `SKILL_LINES_CHANGED`. That event exists and
  covers skill-ups, so the new source of ranks fits the existing cache.
- Round 2: `GetProfessions`/`GetProfessionInfo` are no longer called. `C_SkillInfo` isn't
  nil-guarded, which is right: it is in the `forever` list. `skillLine.rank > 0` is safe,
  since `rank` is documented `Nilable = false`. The stand-in defines only
  `GetSkillLineInfoByID`, which Forever has, so `wow.lua` still defines nothing Forever
  lacks. Nothing in `wow.lua` assigned `C_SkillInfo` before (`grep`), so the table
  assignment overwrites nothing. Secret values: the result is the player's own skill data
  and is used only in a number comparison. No `SecretReturns` in the Forever doc
  (inferred safe). Still to confirm in game (R5, R7): `/dump C_SkillInfo.GetSkillLineInfoByID(186)`
  on a character without Mining, and `(393)` on a skinner.
- Round 3: no new game calls. `SKINNING = 393` goes through the same
  `C_SkillInfo.GetSkillLineInfoByID`. The in-game checks are listed under "For Mike in
  game".

### Redundant code

- Compared against `ns.Names` (`Core/Names.lua`), which localizes list names for display
  only and holds no skill line IDs. `ns.Data:Get`, the rank cache in `RecipeBand.lua:246`,
  and `T:ColorCode` are already used as before. No helper is duplicated.
- No dead code left: `W.SetSkillLines` and `W.skillLines` are gone from the tests.
  `grep` finds them only in older Review Docs and `implementer.md` (R3).
- Round 2: the addon's `SKILL_LINE_IDS` duplicates `catalog.py`'s `ProfessionDef.skill_line`
  (R6). Compared against `emit.render` (`emit.py:43-56`), which already writes every other
  per-list fact, and against `ns.Names`/`ns.Data`, which have no skill line lookup. No
  other duplicate. `RankAmongProfessions` and both old stand-ins are gone, with no
  leftovers (`grep -rn "GetProfession" --exclude-dir=.git`: only Review Docs).
- Round 3: the duplicate stays, by the alternative route R6 allowed, and the scraper test
  keeps it honest. The test's `"SKINNING": 393` is a third spelling of one number. That is
  acceptable as the test's expected value, but it means 393 is checked only against itself
  (hence the in-game check). The open part is when the test runs (R9).

### Security

None. The change touches no addon messages, chat, SavedVariables, names or credits, and no
scraper, workflow or tool code. Round 2: still none. The only non-code file touched is
`.claude/agents/implementer.md`, a one-line doc edit. R6's preferred fix would touch the
scraper's emitter, but only to write a constant from `catalog.py`, with no network or
downloaded input.
Round 3: the scraper test reads a repo file at a fixed path, with no downloads, no
`eval`, no `shell=True`. R9's suggested workflow uses `pull_request` (not
`pull_request_target`), `permissions: contents: read`, and no `github.event` text in `run:`.

## Round history

- 2026-10-18, `16d5877`, round 1: **Changes needed**. Opened R1 (blocking), R2, R3 (should
  fix), R4 (nit).
- 2026-10-18, `a7fb791`, round 2: **Changes needed** (0 blocking, 2 should fix, 2 nits).
  Closed R1, R2, R4 (`cffb27e`) and R3 (`a7fb791`). Opened R5, R6 (should fix), R7, R8
  (nit). Corrected round 1's claim that the scraper carries no skill line IDs (R1
  evidence).
- 2026-10-18, `fd599b1`, round 3 (last): **Changes needed**, left for Mike (0 blocking,
  1 should fix). Closed R5, R6 (by the test route), R7, R8 (`fd599b1`). Opened R9 (the ID
  check isn't run on pull requests). Added the in-game `/dump` checks.

## Integration

Applied onto `dev` after #611 merged. On the result: `tests/smoke/check.sh` all passed (dev, packaged, secret), `tools/locales.py --check` passed, scraper unit tests OK, `luac5.1 -p` clean on every changed Lua file. R9 (no pull-request workflow runs the scraper tests) is put to Mike in the PR.
