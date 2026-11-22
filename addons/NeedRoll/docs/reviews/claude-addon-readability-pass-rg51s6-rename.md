# Review: Rename the inst, enc, T and S aliases to instance, encounter, Theme and Size

| | |
| --- | --- |
| Branch | `final-rename` into `dev` (PR # once it exists), part of the `claude/addon-readability-pass-rg51s6` series |
| Commit reviewed | `4a78cb9` (round 3: `6315f97`, `4a78cb9`; round 2 was `e5ea2ae`, round 1 `023bc25`; no uncommitted changes) |
| Date | 2026-10-18 |
| Round | 3 (final) |
| Verdict | **Ready** (0 blocking, 0 should fix, 0 left; R1-R12 fixed, R12 by the integrator after round 3) |
| Needs | `/reload` to load the changed Lua. Nothing the game sees changes (the bytecode is identical, see Checks), so no restart is needed |

## What the change does

Nothing changes for a player: no frame, text, saved key or addon message is
different. For Mike and anyone reading the code, the four short local aliases
the UI files used are now whole words. `T` (the `ns.Theme` table) is `Theme`,
`S` (`Theme.size`) is `Size`, `inst` (an instance from `Data/Data.lua`) is
`instance`, and `enc` (one of its encounters) is `encounter` (Mike first
picked `guide` and `entry`, then switched on 2026-10-18; rounds 2 and 3 apply
that). A list or pane row's data is `entry`. `C`, `F` and `UI` stay
as they were, and so do table keys and data fields, following Mike's decision
of 2026-10-17. `5ef7527` wraps the 23 lines the longer names pushed past 120
characters. `023bc25` renames the helpers in the agent guides. `Theme.lua`'s
alias legend, `docs/READABLE-CODE.md` §6 and §8 and `docs/STYLE-GUIDE.md`
follow the new names.

## Scope

- `NeedRoll/API.lua`, `Core/Drops.lua`, `Core/LootLog.lua`, `Core/Names.lua`,
  `Core/Shopping.lua`, `Core/Tooltip.lua`, `Core/Wishlist.lua`: `inst`/`enc`
  locals and parameters are now `instance`/`encounter` (rows and list items
  stay `entry`).
- `NeedRoll/Data/Data.lua`: the same rename. This is the registry Lua, written
  by hand, not a scraper output (its header says data files "call
  ns.Data:Register"), so it is reviewed. No generated data file is touched.
- `NeedRoll/UI/*.lua` (24 files: DevKit, DropTalk, Fished, FrameDebug,
  IconBrowser, IconDebug, LineDump, Lists, LootGrid, MainFrame, MapEdit,
  MinimapButton, Overview, RecipeBand, Reputation, Search, Settings, Shopping,
  SoundTest, Theme, Welcome, Wishlist): `T`→`Theme`, `S`→`Size`,
  `inst`→`instance`, `enc`→`encounter`, plus the same names in comments. Theme.lua's
  legend is rewritten.
- `tests/smoke/modules/*.lua` (17 files) and `tests/smoke/scenarios.lua`: the
  same rename. `scenarios.lua`'s `local S = {}` is the scenario list, not
  `Theme.size`, and is rightly left alone.
- `docs/READABLE-CODE.md`: §6 now names `Theme:Pill`/`Theme:Row`. §8 lists
  `C`, `F`, `UI` as the short aliases and `Theme`, `Size`, `instance`,
  `encounter` as whole-word ones, with `entry` for one item of a list.
- `docs/STYLE-GUIDE.md`: `T.`/`T:`/`S.` references now read `Theme.`/`Theme:`/`Size.`.
- `.claude/agents/implementer.md`, `.claude/agents/reviewer.md`: the helper
  names (`Theme:Pill`, `^function Theme:` ...).
- Skipped: nothing generated is in the diff.

## Checks

| Check | Result |
| --- | --- |
| `ad61a5d` gives byte-identical `luac5.1 -s` | **Passed, 49 of 49** changed Lua files. I compiled each file at `ad61a5d^` and at `ad61a5d` with `luac5.1 -s` and ran `cmp`. Stripped bytecode keeps every constant (all strings, so every `L["..."]` key, SavedVariables key, devexport text and addon message, and every field and global name), every opcode and every register. So no key or string was renamed, and no reference now binds to a different variable (a shadowing slip would change register numbers) |
| `5ef7527` gives equal `luac -l -l` listings | **Passed, 11 of 11** files. I ran `luac5.1 -l -l -p` before and after, with `[line]` numbers, `<file:line,line>` headers and addresses taken out. A second, plainer `luac -l` comparison agrees. Stripped `-s` bytes do differ, as expected: Lua 5.1 keeps `linedefined` in stripped headers |
| `023bc25` | Markdown only (`.claude/agents/*.md`), no Lua |
| `luac5.1 -p` on changed Lua | Passed (all 49 files) |
| `luacheck --no-global -q`, HEAD against `origin/dev` | **No new warnings.** I compared the warning messages with line numbers taken out, per file. `tests/smoke/scenarios.lua` goes from 70 to 67 (three "line is too long" warnings gone). The other files have equal counts. The repo has no `.luacheckrc`, so the default shadowing checks (W421/W431) were on |
| `python3 tools/locales.py --check` | Passed (exit 0, no output) |
| `python3 tools/translations.py` | Exit 0. It lists 50 "not used by NeedRoll any more" lines for `zhTW.lua` and others. Those are the same as on `dev`: no `L` key changed (shown by the bytecode check) |
| `tests/smoke/check.sh` | **All passed** in all three runs: dev (184 files), packaged (178), and dev with secret values |
| Scraper unittest | Not run: no scraper file changed |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Readability | `UI/MainFrame.lua:1890-1906`, `Core/Shopping.lua:257-264`, `UI/LootGrid.lua:295-323`, `UI/Lists.lua:1203`, `API.lua:46`, many more | `entry` now means two different things, often in one function | fixed in round 2 (`3bf4fe1`); what is left is in R7 and R10 |
| R2 | should fix | Readability | `UI/Theme.lua:17-18`, `docs/READABLE-CODE.md:117`, `UI/Search.lua:63-66`, `Core/Shopping.lua:255-256` | The legend, READABLE-CODE and old comments say `entry` is an encounter where it isn't | fixed in round 2 (`3bf4fe1`, `e5ea2ae`); what is left is in R10 |
| R3 | nit | Readability | `UI/MainFrame.lua:1905`, `tests/smoke/modules/UI-Shopping.lua:198` | `lootEntry` and `treeEntry` name pane rows that include headings, folds and spacers | fixed in round 2 (`e5ea2ae`) |
| R4 | nit | Readability | `API.lua:131-141` | `entryName` also takes NPC, spell, item and faction IDs | fixed in round 2 (`e5ea2ae`); the new name is followed up in R9 |
| R5 | nit | Readability | `Core/Shopping.lua:279`, `Core/LootLog.lua:255-282`, `Core/Wishlist.lua:299`, `Data/Data.lua:740`, `UI/Lists.lua:554,978,1496,1511`, `tests/smoke/scenarios.lua:2390`, `tests/smoke/modules/UI-Search.lua:90` | Half-renamed compounds (`childInst`, `instID`, `byInst`, `encName` ...) and `instance` locals beside `guide`/`entry` | compounds fixed in round 2 (`e5ea2ae`); the `instance` question is now R8; leftovers in R11 |
| R6 | nit | Readability | `UI/Search.lua:242`, `Core/Wishlist.lua:281`, `tests/smoke/modules/UI-Search.lua:27` | Kept keys are now filled from differently named locals: `{ entry = lootEntry, enc = entry, inst = guide }` | fixed in round 2 (`e5ea2ae`) |
| R7 | should fix | Readability | `UI/Lists.lua` encounter list (`:551-554`, `:1219`, `:1342`, `:1367`, `:1426`, `:1538`, `:1925-2060`, `:2093-2125`, `:2308-2309`, `:2359-2368`), `UI/RecipeBand.lua:338-342`, `:711`, `tests/smoke/scenarios.lua:1575-1790`, `tests/smoke/modules/UI-RecipeBand.lua:47-48`, `:278` | List rows that may be headers, set rows, quests or markers are called `encounter` | fixed in round 3 (`6315f97`, `4a78cb9`) |
| R8 | should fix (Mike decides) | Readability | 80 `instance` locals and parameters (`UI/Lists.lua` 31, `UI/RecipeBand.lua` 15, `UI/Overview.lua` 14, `Data/Data.lua` 8, `UI/MainFrame.lua` 5, ...), 10 `local guide = state.instance`-style lines | The same object is a `guide` in 318 places and an `instance` in 80, and its keys say `instance` | fixed in round 3 (`4a78cb9`): Mike chose `instance` |
| R9 | nit | Readability | `API.lua:136-146` | `encounterWhat` doesn't read as a name | fixed in round 3 (`6315f97`) |
| R10 | nit | Readability | `API.lua:45-47`, `UI/Theme.lua:18`, `docs/READABLE-CODE.md:117-118` | `IsNamed`'s `entry` and the two definitions of `entry` | fixed in round 3 (`6315f97`) |
| R11 | nit | Readability | `tests/smoke/modules/UI-Shopping.lua:195-197`, `tests/smoke/scenarios.lua:2389`, `:2411`, `tests/smoke/modules/API.lua:11` | Test-only leftovers: `enc2`, `Enc(...)` helpers, `e` | fixed in round 3 (`6315f97`) |
| R12 | nit | Readability | `Core/Wishlist.lua:365-372` | `runByInst` was missed by the compound renames | fixed after round 3 (integration commit; bytecode identical) |

### R1 · `entry` now means two different things, often in one function

- **Severity:** should fix
- **Area:** Readability (READABLE-CODE §8 Avoid mental mapping, §9 Avoid disinformation, §6 Consistency)
- **Where:** for example `NeedRoll/UI/MainFrame.lua:174`, `:1890-1906`;
  `NeedRoll/Core/Shopping.lua:257-264`; `NeedRoll/UI/LootGrid.lua:295`
  against `:304-323`; `NeedRoll/UI/Lists.lua:1139-1150`, `:1203`, `:1426`;
  `NeedRoll/API.lua:46`; `NeedRoll/Core/Wishlist.lua:37`, `:90`, `:251`;
  `NeedRoll/Core/Drops.lua:186`, `:549`, `:575`; `NeedRoll/UI/Wishlist.lua:62`, `:729-750`
- **Status:** fixed in round 2 (`3bf4fe1`)

**What's wrong.** Before this change, `entry` was the addon's usual word for
"one row's data in a list or loot pane". Theme's list framework passes it
(`opts.setupRow(row, entry)`, `pane.entries`, `pane:EntryHeight(entry)`),
and Core uses it for a shopping list item, a wishlist item and a Drops outbox
record. The rename adds a second meaning, "an encounter of a guide". Only
the `entry` locals that would have been *shadowed* were renamed. Every other
row-sense `entry` and `entries` keeps its name, so most files now use one
name for both. In some functions both meanings sit side by side:

```lua
-- UI/MainFrame.lua:1890  (entry = the encounter, entries = loot pane rows)
local function ShowLootPage(guide, entry, highlight)
    ...
    local entries = BossFolds(entry, bosses)
    ...
    entries = filtered and UI.FilterLoot(entry.sections) or entry.sections
```

```lua
-- Core/Shopping.lua:257  (entry = the recipe, branch.entry = the shopping list item)
local function AddRow(branch, itemID, need, depth, path, guide, entry, rails)
    local isCraftable = HasMaterials(entry) and not branch.crafting[itemID]
    ...
    local opened = branch.entry.open and branch.entry.open[path]
```

```lua
-- UI/LootGrid.lua:295 and :318, ten lines apart
local function SourcePath(guide, entry)          -- entry: an encounter
local function ShowPlaceTooltip(entry)           -- entry: a search result row
    if entry.enc and entry.enc.name ~= entry.name then
```

```lua
-- UI/MainFrame.lua:143 and :174, thirty lines apart
local function AbilityEntries(guide, entry, bosses)    -- an encounter
local function LoadAbilities(entries, done)
    for _, entry in ipairs(entries) do                 -- an ability row
        local spell = entry.ability and Spell:CreateFromSpellID(entry.ability)
```

In `UI/Lists.lua` the same name holds quests (`:1203`,
`for _, entry in ipairs(ns.UI.DungeonQuests(...))`), quest rows (`:1426`
`SetupQuestRow(row, entry, ...)`), instance list rows and encounters
(`:1496`). In `API.lua:46`, `IsNamed(key, entry, name)` is called with a
guide, an encounter, a boss and a quest. Function names add to it:
`AbilityEntries(guide, entry, ...)`, `RecipeEntries(entry)` and
`ScarceEntries(guide, entry)` read as "the entries of an entry", but they
return pane rows built *from* an encounter.

**Why it matters.** READABLE-CODE §8 lists `entry` as a name that means "one
of a guide's encounters" and nothing else. A newcomer who learns that from
the legend opens `Core/Shopping.lua`, `Core/Wishlist.lua` or `UI/Wishlist.lua`
and finds `entry.itemID`, `entry.count` and `entry.slot` on things that are
not encounters. They can't tell `entry.loot` (an encounter's loot) from
`entry.header` (a pane row's heading) without tracing each value back to
where it came from. This is the mental mapping this pass set out to remove.
Before the change, `enc` and `entry` were at least two different names.
Behaviour isn't affected (see Checks). Only readability is.

**Evidence.** I read the functions quoted above at `023bc25`. I grepped
every `entry` declaration in each file that had both an `entry` and an `enc`
on `origin/dev`: 16 addon files and 11 test files (API, Drops, LootLog,
Names, Shopping, Tooltip, Wishlist, Data, Lists, LootGrid, MainFrame,
MapEdit, Overview, Search, Theme, Wishlist UI). On `dev`, `UI/LootGrid.lua`
had 206 lines with `entry` (rows) and 15 with `enc`. All of them now say
`entry`.

**Fix.** This needs Mike's call, since he picked `entry`. Two options:

1. *Recommended:* make the encounter alias `encounter`. It is a whole word, it
   is already the addon's name for this (`UI.state.encounter`,
   `UI:SelectEncounter(encounter)`, `UI:SelectRecipe(instance, encounter)`,
   `UI:GoToSource(instance, encounter, ...)` in `MainFrame.lua:1484-1720`),
   and nothing else uses it. The same token-aware renamer can run
   `entry`→`encounter` only where the `entry` came from `enc` (the
   `ad61a5d` diff lists those lines), and the `luac -s` proof applies again.
   `entry` then keeps its old meaning, a pane row's data.
2. Keep `entry` for encounters and rename every row-sense `entry`/`entries`
   (`row`/`rows` for pane rows, `item` for wishlist and shopping items,
   `record` for Drops). This touches far more lines than option 1.

### R2 · The legend, READABLE-CODE and old comments say `entry` is an encounter where it isn't

- **Severity:** should fix
- **Area:** Readability (§5 "A comment that is wrong is worse than none", §9)
- **Where:** `NeedRoll/UI/Theme.lua:9` and `:17-18`; `docs/READABLE-CODE.md:114-117`;
  `NeedRoll/UI/Search.lua:63-66`; `NeedRoll/Core/Shopping.lua:255-256`;
  `NeedRoll/Core/Shopping.lua:83` ("Changes an entry's count")
- **Status:** fixed in round 2 (`3bf4fe1`, `e5ea2ae`)

**What's wrong.** The legend reads

```lua
-- Aliases used across the UI files:
...
--   entry  one of a guide's encounters: a boss, a loot pool, a rank or a
--          recipe
```

and READABLE-CODE §8 says "`guide` (an instance) and `entry` (one of its
encounters)". As R1 shows, that holds for perhaps a third of the `entry`
names in the code. Comments written for the old row meaning now sit right
beside code where `entry` is the encounter:

```lua
-- UI/Search.lua:63
-- Every loot entry of the tabs that are on, ... `fn` gets the entry, its encounter, its instance and
-- the entry's place in that order.
...
            for _, entry in ipairs(guide.encounters) do
                for _, lootEntry in ipairs(entry.loot) do
                    fn(lootEntry, entry, guide, order)
```

Here "the entry" in the comment is `lootEntry`, and "its encounter" is the
local named `entry`. In `Core/Shopping.lua:255`, the comment above `AddRow`
says "One entry's tree ... `branch`: the entry", meaning the shopping list
item, while `AddRow`'s own `entry` parameter is the recipe. The legend also
says the aliases are "used across the UI files", but `guide` and `entry` are
used just as much in `Core/`, `API.lua`, `Data/Data.lua` and `tests/`.

**Why it matters.** A newcomer reads the legend first, as Theme.lua's header
invites, and then misreads every row-sense `entry`. The Search.lua comment
names the wrong variable for the one argument it explains.

**Evidence.** I read `Theme.lua:1-18`, `READABLE-CODE.md:108-121`,
`Search.lua:60-80` and `Shopping.lua:250-290` at `023bc25`.

**Fix.** Whatever is decided for R1, the docs must match the code. If R1
option 1 is taken, the legend says `encounter` and the comments are correct
again. If `entry` stays as it is, the legend should read
"`entry` one of a guide's encounters (in list and loot panes, `entry` is
still a row's data)". The two comments then need rewording: Search.lua
"`fn` gets the loot entry (`lootEntry`), its encounter, its guide and its
place in that order", and Shopping.lua "`branch`: the shopping list entry
(`branch.entry`), its index ...". Change "UI files" to "the addon's files".

### R3 · `lootEntry` and `treeEntry` name pane rows that include headings, folds and spacers

- **Severity:** nit
- **Area:** Readability (§9)
- **Where:** `NeedRoll/UI/MainFrame.lua:1905-1906`; `tests/smoke/modules/UI-Shopping.lua:198-202`
- **Status:** fixed in round 2 (`e5ea2ae`)

**What's wrong.** Most `lootEntry` names are exact: they loop over
`entry.loot` (API.lua:91, Search.lua:73, Tooltip.lua, LootLog.lua,
Core/Wishlist.lua:277, MainFrame.lua:121/192). One doesn't:

```lua
-- UI/MainFrame.lua:1905
for _, lootEntry in ipairs(entries) do
    if not (lootEntry.header or lootEntry.fold) then itemCount = itemCount + 1 end
end
```

`entries` here is loot pane rows (sections, headings, boss folds and items),
and the line itself checks for the rows that aren't loot. In the same way,
`treeEntry` in `UI-Shopping.lua:198` walks `pane.tree.entries`, which
contains spacer rows (`treeEntry.spacer`, height 8). `Shop:BuildTree`'s own
comment calls these "tree rows".

**Why it matters.** The name says "a loot item", and the next line shows it
often isn't one. The caller flagged this, and I confirm it.

**Evidence.** I read `MainFrame.lua:1890-1915` and `UI-Shopping.lua:195-205`.

**Fix.** `for _, row in ipairs(entries) do if not (row.header or row.fold) ...`
and `for _, treeRow in ipairs(pane.tree.entries)`.

### R4 · `entryName` also takes NPC, spell, item and faction IDs

- **Severity:** nit
- **Area:** Readability (§9)
- **Where:** `NeedRoll/API.lua:131-141`
- **Status:** fixed in round 2 (`e5ea2ae`); renamed again in round 3 (R9)

**What's wrong.** `ShowIn(categories, what, entryName)` passes `entryName`
through `FromText`, which turns `"36"` into `36`, and then to `Encounter`,
which matches numbers against `entry.npc`, `entry.spellID`, a faction
standing, or an item a recipe makes (`API.lua:104-110`). The file's own
header says "the game's numbers (an instance map ID, an NPC, spell, item,
quest or faction ID) work too". The comment calls it "`entryName` given but
not found there".

**Why it matters.** Someone reading `ShowIn` would think only names work,
and might add a `type(entryName) == "string"` guard that breaks
`NeedRoll_ShowLoot(nil, 639)` (an NPC ID) for other addons.

**Evidence.** I read `API.lua:1-30` and `:100-145`.

**Fix.** Name it the way the first parameter is named: `what` names the
instance, so `which` (or `entryWhat`) names the encounter, "a name or game
ID". The comment changes to match.

### R5 · Half-renamed compounds and `instance` locals beside `guide`/`entry`

- **Severity:** nit
- **Area:** Readability (§6 Consistency)
- **Where:** `NeedRoll/Core/Shopping.lua:279-281`; `NeedRoll/Core/LootLog.lua:255-282`;
  `NeedRoll/Core/Wishlist.lua:299-301`; `NeedRoll/Data/Data.lua:740`;
  `tests/smoke/scenarios.lua:2390-2395`; `tests/smoke/modules/UI-Search.lua:90-96`;
  `NeedRoll/UI/Lists.lua:554`, `:978`, `:1496`, `:1511`; `NeedRoll/UI/RecipeBand.lua:334`
- **Status:** fixed in round 2 (`e5ea2ae`); `instance` settled in R8, `runByInst` in R12

**What's wrong.** Names built on the old aliases kept the abbreviation:

```lua
-- Core/Shopping.lua:279, feeding AddRow's (…, guide, entry, …) parameters
local childInst, childEnc = ns.Data:RecipeFor(reagent.itemID)
local child = AddRow(branch, reagent.itemID, reagent.count * row.crafts, depth + 1, childPath,
    childInst, childEnc, childRails)
```

There are also `instID` and `byInst` (`LootLog.lua:255-282`,
`local guide = ns.Data:Get(instID)`), `instID` (`Core/Wishlist.lua:299`),
`encID` (`Data.lua:740`), `encName` (`scenarios.lua:2390`, beside
`guide.name, entry.name`) and `sameInst` (`UI-Search.lua:90`). Separately,
many functions name the same object `instance` while their loops say
`entry`: `RecipeIconFor(entry, instance)` (Lists.lua:554),
`for _, entry in ipairs(instance.encounters)` (Lists.lua:978, 1496, 1511),
`RB:Narrow(list, instance)`, and the `UI:SelectRecipe(instance, encounter)`
family. One object now goes by `guide`, `instance` and the key `inst`, and
another by `entry`, `encounter` and the key `enc`.

**Why it matters.** `childInst, childEnc` passed straight into `guide, entry`
parameters is the pattern the rename was meant to end. The mix also makes
`grep -w guide` miss half the places a guide is handled.

**Evidence.** `grep -rnoE '\b(enc|inst)[A-Z][A-Za-z]*\b|\b[a-z]+(Enc|Inst)\b'`
over `NeedRoll/` and `tests/` found 7 `instID`, 8 `byInst`, 2 `childInst`,
2 `childEnc`, 2 `encID`, 2 `encName` and 3 `sameInst`.
`grep -nE '\binstance\b'` found locals and parameters in Lists.lua (92
lines), MainFrame.lua (78), Overview.lua (78) and RecipeBand.lua (47).

**Fix.** Rename the compounds in the same mechanical way: `childGuide,
childEntry`, `guideID`, `byGuide`, `entryID`, `sameGuide`, and in scenarios
`entryOldName` (or `oldEntryName`). Keep data keys such as `.inst` and `.enc`
as they are. Whether `instance`/`encounter` locals and parameters should
become `guide`/`entry` too is Mike's call, since his decision covered the
aliases only. Ask him once R1 is settled, because R1 option 1 would make
`encounter` the alias and remove half of this.

### R6 · Kept keys are now filled from differently named locals

- **Severity:** nit
- **Area:** Readability (§8)
- **Where:** `NeedRoll/UI/Search.lua:242`; `NeedRoll/Core/Wishlist.lua:281`;
  `tests/smoke/modules/UI-Search.lua:27`
- **Status:** fixed in round 2 (`e5ea2ae`)

**What's wrong.** Mike kept the table keys, which is correct (search results
and wishlist sources are read as `src.inst` and `src.enc` in LootGrid,
Wishlist UI and MainFrame). The tables are now built like this:

```lua
-- UI/Search.lua:242
table.insert(item.sources, { entry = lootEntry, enc = entry, inst = guide, order = order, ...
```

Here the key `entry` holds the loot row, and the key `enc` holds the local
named `entry`. Later, `LootGrid.lua:320` reads `entry.enc.name`, where
`entry` is the search result. In the reverse case, `LootGrid.lua:1161` does
`local guide = entry.inst`.

**Why it matters.** Every reader has to work out three renamings (key
`entry` = `lootEntry`, key `enc` = local `entry`, key `inst` = `guide`)
at the one spot where all three appear together.

**Evidence.** I read the three lines above and the readers in
`LootGrid.lua:304-323`, `:1150-1190` and `UI/Wishlist.lua:85-120`.

**Fix.** Add one line above each source table where it is built (the keys
stay as they are, for the code that reads them): `-- A source: inst = its
guide, enc = its encounter (entry), entry = the loot row; the short keys are
read across LootGrid, Wishlist and MainFrame.`, or the same in fewer words.
If R1 option 1 is taken, `enc = encounter` reads cleanly on its own.

### R7 · List rows that may be headers, set rows, quests or markers are called `encounter`

- **Severity:** should fix
- **Area:** Readability (§9 Avoid disinformation, §6 Consistency)
- **Where:** `NeedRoll/UI/Lists.lua`, the encounter list: `RecipeIconFor`
  (`:551-554`), `IsSetRow` (`:1219`), `ShowChainStep` (`:1342`), `ShowArrows`
  (`:1367`), `SetupQuestRow` (`:1426`), `HeaderLike` (`:1538`), `SetupRow`,
  `AfterRow` and the `rowInset`/`isSelected`/`onClick`/`onRightClick` callbacks
  (`:1925-2060`), `Adder`/`AddRows` (`:2093-2125`), the `topRow` loops
  (`:2308-2309`), `pane:FirstRecipe` (`:2359-2368`); `NeedRoll/UI/RecipeBand.lua:338-342`,
  `:711`; `tests/smoke/scenarios.lua:1575-1790` (the `list.entries` loops);
  `tests/smoke/modules/UI-RecipeBand.lua:47-48`, `:278`
- **Status:** fixed in round 3 (`6315f97`, `4a78cb9`)

**What's wrong.** `3bf4fe1` turned every former `enc` into `encounter`. On
`dev`, `enc` had also been used for any row of the encounter list. That list
holds section headers, wing headers, colour-set rows, quest rows and the
"other classes" marker line as well as encounters. Under a short alias that
was easy to miss. Under the whole word, and with the legend now giving `entry`
to "one row's data in a list or loot pane", the code contradicts itself:

```lua
-- UI/Lists.lua:2004, inside AfterRow(row, encounter)
local isEncounter = not HeaderLike(encounter) and not encounter.wingHeader
    and not encounter.quest and not encounter.marker
```

```lua
-- UI/Lists.lua:1219
local function IsSetRow(encounter)
    return rawget(encounter, "setRow") ~= nil
end
```

```lua
-- tests/smoke/scenarios.lua:1641
for _, encounter in ipairs(list.entries) do
    local recipe = rawget(encounter, "setRow") and encounter.members[1] or encounter
```

`SetupQuestRow(row, encounter, ...)` reads only `encounter.quest`.
`RecipeIconFor(encounter, instance)` begins by turning away
`encounter.header`, `.wingHeader`, `.marker` and `.quest`. In the same pane,
next to these, sibling helpers that take the same rows kept the row word:
`InSection(entry, active)` (`:1569`), `LitByMapFloor(entry)` (`:1978`, called
from `AfterRow` with that function's `encounter`), `GroupKeyFor(entry)`,
`pane:ScrollTo(entry)`, `pane:SetOf(entry)` and `pane:IsListed(entry)`
(`:2321-2373`).

**Why it matters.** A reader takes the variable name at its word.
`isEncounter = ... encounter ...` asks "is the encounter an encounter?", and
the answer is often no. A newcomer can't tell from `encounter.quest` whether
quests hang off encounters in the data (they don't). The same row value is
`entry` in one helper and `encounter` in the next, so following it through
`AfterRow` → `LitByMapFloor` changes its name halfway.

**Evidence.** On `dev` these were `enc` (for example
`git show origin/dev:NeedRoll/UI/Lists.lua` line 1219 reads
`local function IsSetRow(enc)`), so the renamer was faithful to the token. The
problem is the meaning. A grep for `encounter.(header|quest|marker|wingHeader|members|key)`
and `rawget(encounter` gives 43 hits in `UI/Lists.lua`, 2 in `UI/RecipeBand.lua`,
12 in `tests/smoke/scenarios.lua` and 2 in `UI-RecipeBand.lua`.

**Fix.** Name the list's row `entry`, the word the legend gives to list rows,
wherever the value can be anything the list holds: the CreateList callbacks
and every helper they pass a row to, `Adder`/`AddRows`, `FirstRecipe`,
`RB:Narrow`'s and `RB:Fold`'s `list` loops, and the tests' `list.entries`
loops. Keep `encounter` where only encounters arrive: loops over
`guide.encounters`, `SetupEncounterRow(row, encounter)`, `BossLevel`,
`SelectedPin`, `RecipeProduct` and `ns.UI.state.encounter`. `isEncounter`
then reads correctly: `local isEncounter = not HeaderLike(entry) and not entry.wingHeader ...`.
`SetupQuestRow` can take the quest itself (`SetupQuestRow(row, quest, class, inside)`,
since `SetupRow` already has `quest`). That last one is a small code change,
not a rename, so the bytecode proof won't apply to it. Re-run the smoke tests
for that line.

### R8 · The same object is a `guide` in 318 places and an `instance` in 80, and its keys say `instance`

- **Severity:** should fix (Mike decides which way)
- **Area:** Readability (§6 Consistency, §7 Searchable names)
- **Where:** `instance` locals and parameters: `UI/Lists.lua` (31 declarations,
  e.g. `:554`, `:978`, `:1496`, `:1511`, `:2174`), `UI/RecipeBand.lua` (15, e.g.
  `RB:Narrow(list, instance)` `:330`), `UI/Overview.lua` (14), `Data/Data.lua`
  (8, e.g. `ns.Data:Bosses(instance, encounter)` `:603`), `UI/MainFrame.lua` (5:
  `UI:SelectInstance`, `SelectRecipe`, `GoToSource`), `API.lua` (3 public
  parameters), `UI/MapEdit.lua` (3). `guide` read from an `instance` key:
  `UI/MainFrame.lua:1187`, `:1705`, `:1740`, `:1940`, `:2022`, `:2048`, `:2105`,
  `:2117`, `UI/Overview.lua:3148`, `:3268`
- **Status:** fixed in round 3 (`4a78cb9`): Mike chose `instance` on the card

**What's wrong.** Yes, this is a real inconsistency, not a matter of taste.
`guide` and `instance` name the same thing, a `Data/Data.lua` instance table,
in the same role, and both often appear in one file and sometimes one call
chain:

```lua
-- UI/MainFrame.lua:1940
local guide, encounter = state.instance, state.encounter
-- Data/Data.lua:603, called as ns.Data:Bosses(guide, encounter) everywhere else
function ns.Data:Bosses(instance, encounter)
-- UI/Lists.lua:1496
for _, encounter in ipairs(instance.encounters) do
```

Every key and module name says instance: `UI.state.instance`,
`pane.instance`, `ns.Data.instances`, `ns.Data.instanceMapIDs`,
`UI:SelectInstance`, `Theme.size.instanceList`, `INSTANCE_TABS`. The public
API parameters in `docs/API.md` (`NeedRoll_ShowLoot(instance, boss)`) say
instance too. Mike's decision covered the aliases only, which is why
`instance` was left alone. With the aliases done, the split is easy to see:
`grep -w guide` finds 318 declarations, `grep -w instance` 80 more of the same
thing.

**Why it matters.** §6 says one way of doing each thing. A newcomer meets
`guide` in one function and `instance` in the next, and must work out that
they are the same table. `local guide = state.instance` puts that mapping
into the code ten times. A grep for one name misses the other.

**Evidence.** Declaration counts from
`grep -rnE '(local [^=]*|function[^(]*\([^)]*|for [^=]*)\binstance\b'` and the
same for `guide` over `NeedRoll/` and `tests/`. I read the lines listed.

**Fix.** Two consistent options, for Mike:

1. *`instance` everywhere* (my recommendation). Rename the 318 `guide`
   locals to `instance` with the same token-aware renamer and bytecode proof.
   This is the reasoning that settled R1: `encounter` was picked because
   `UI.state.encounter` and `UI:SelectEncounter` already use it, and by the
   same rule `UI.state.instance` and `UI:SelectInstance` pick `instance`. It is
   also the word players and the game API use ("instance", `IsInInstance`,
   `GetInstanceInfo`), while `guide` could be read as NeedRoll itself, a
   dungeon guide (inferred: the TOC and README don't use the word).
2. *`guide` everywhere*. Rename the 80 `instance` locals and parameters to
   `guide`. The keys (`state.instance`, `pane.instance`) and public API
   parameter names stay. The legend then needs a line saying a guide is
   stored under `instance` keys.

Either way the legend's `guide` line and READABLE-CODE §8 follow.

### R9 · `encounterWhat` doesn't read as a name

- **Severity:** nit
- **Area:** Readability (§1 Meaningful names)
- **Where:** `NeedRoll/API.lua:136-146`
- **Status:** fixed in round 3 (`6315f97`)

**What's wrong.** `e5ea2ae` renamed `entryName` to `encounterWhat`, by
analogy with `ShowIn`'s `what`. The analogy holds, but `what` works only as a
lone word ("what to open"). With a noun in front it reads as a phrase,
"encounter what?", and says neither what kind of value it holds nor what it
is for. The new comment has to explain it ("a name or game ID, like `what`").
That is the job a name should do.

**Why it matters.** It's small. But `ShowIn` is the one entry point every
`NeedRoll_Show*` call goes through, so a reader from another addon looks here
first.

**Evidence.** I read `API.lua:130-150` and the callers at `:156`, `:246-262`
(`boss`, `recipe`, `standing`, `rank`, `section`).

**Fix.** Name it after what it holds: `encounterNameOrID`, which is the
comment's own wording, or `encounterQuery`. The test that passes `"639"` as
text fits "query" too. `ShowIn(categories, what, encounterNameOrID)` reads
plainly, and the comment can drop "(a name or game ID, like `what`)".
Renaming `what` to `placeNameOrID` to match would also help, but `what` is
older than this change and is used by `Instances`, `MatchRank` and
`Encounter`, so leave it for a later pass.

### R10 · `IsNamed`'s `entry` and the two definitions of `entry`

- **Severity:** nit
- **Area:** Readability (§9)
- **Where:** `NeedRoll/API.lua:45-47`; `NeedRoll/UI/Theme.lua:18`;
  `docs/READABLE-CODE.md:117-118`
- **Status:** fixed in round 3 (`6315f97`)

**What's wrong.** `IsNamed(key, entry, name)` is called with a guide
(`:57`), an encounter (`:104`), a boss (`:116`) and a quest (`:189`). Its
comment says "names `entry`". Neither definition of `entry` covers that.
The two definitions also differ: Theme.lua says "one row's data in a list
or loot pane, or an item on a list", while READABLE-CODE says only "a row's
data in a list or loot pane". Other `entry` names that fit neither: the Drops
outbox record (`Core/Drops.lua:575`), the name-lookup queue item
(`Core/Names.lua:472`, `:493`), and the `SIDE_TABS` loop in
`UI/IconDebug.lua:413`. Each is clear where it sits.

**Why it matters.** The legend is now where a reader checks what `entry`
means, and for `IsNamed` it gives the wrong answer (a pane row). The two
documents should agree word for word.

**Evidence.** I read `API.lua:40-60`, `:100-120`, `:185-192`, `Theme.lua:9-18`
and `READABLE-CODE.md:110-121`.

**Fix.** Rename `IsNamed`'s parameter to say what it is:
`IsNamed(key, named, name)`, with the comment "Whether name key `key` names
`named` (a guide, encounter, boss or quest), by its English name or `name`".
Then use one definition in both documents, for example "`entry`: one item of
a list: a row's data in a list or loot pane, a shopping or wishlist item, an
outbox record".

### R11 · Test-only leftovers: `enc2`, `Enc(...)` helpers, `e`

- **Severity:** nit
- **Area:** Readability (§8)
- **Where:** `tests/smoke/modules/UI-Shopping.lua:195-197`; `tests/smoke/scenarios.lua:2389`, `:2411`;
  `tests/smoke/modules/API.lua:11`
- **Status:** fixed in round 3 (`6315f97`)

**What's wrong.** `local prof2, enc2 = AnotherRecipe(ns, encounter)` keeps the
old abbreviation on a line the rename touched. `scenarios.lua:2389` finds the
encounter with `for _, e in ipairs(guide.encounters)`, and `e` for
"encounter" is the very example §8 opens with. `local function Enc(id)`
(`scenarios.lua:2411`) and `local function Enc(ns, id)`
(`tests/smoke/modules/API.lua:11`, from `dev`) are "is the open encounter
`id`" checks named with the old short form.

**Why it matters.** It doesn't matter much on its own, since these are only
tests. But the pass's goal is that `grep -w enc` and one-letter encounter
names come up empty.

**Evidence.** `grep -rnoE '\b(enc|inst)[A-Z0-9_]\w*\b'` over `tests/` and a
read of the lines listed.

**Fix.** `local otherProfession, otherRecipe = AnotherRecipe(ns, encounter)`,
`for _, candidate in ipairs(guide.encounters) do if candidate.id == "VANCLEEF" then encounter = candidate end end`,
and `local function IsOpenOn(id)` (or `AtEncounter`) for both helpers.

### R12 · `runByInst` was missed by the compound renames

- **Severity:** nit
- **Area:** Readability (§6 Consistency)
- **Where:** `NeedRoll/Core/Wishlist.lua:365`, `:369`, `:372`
- **Status:** fixed after round 3: renamed to `runByInstance` by the integrator; `luac5.1 -s` output byte-identical

**What's wrong.** `WL:Runs` groups wishlist drops by instance in
`local runByInst, runs = {}, {}`. Round 2 renamed every other compound built
on the old aliases (`byInst` → `byInstance`, `instID` → `instanceID`,
`sameInst` → `sameInstance`), but this one survived. It is keyed by
`source.inst`, a kept data key, which may be why the renamer skipped it.

**Why it matters.** It barely does: the function is short and its comment
explains the run table. It is the one `inst` compound left among the locals.

**Evidence.** `grep -rnoE '\b(inst|enc)[A-Z0-9_]\w*|\b\w+(Inst|Enc)\b'` over
`NeedRoll/` and `tests/` at `4a78cb9` returns only these three lines. It is
the same on `origin/dev` (3 hits), so it isn't new.

**Fix.** `local runByInstance, runs = {}, {}` (three lines).

## Round 2

Reviewed `18343f3..e5ea2ae`. `49aa670` merges `origin/dev` (#613, #614:
`5c9bf60` "Dev edit: drawn routes drop a point half as often"). `3bf4fe1`
makes the encounter alias `encounter`, as Mike chose on the card. `e5ea2ae`
carries the fixes for R2-R6 and the line wraps.

### What changed since round 1

- Every local and parameter that was `enc` on `dev` is now `encounter`.
  `lootEntry` and `listEntry` are back to `entry`, `allDropsEntry` is
  `allDropsEncounter`, and `entryName` is `encounterWhat`.
- Compounds: `childGuide`/`childEncounter`, `guideID`, `byGuide`,
  `encounterID`, `sameGuide`, and `guideName`/`encounterName` in the API
  scenario. The rows in `ShowLootPage` are `row`, and the test's tree rows
  are `treeRow`.
- New comments over the Wishlist sources (`Core/Wishlist.lua:257-261`) and
  the search item index (`UI/Search.lua:229-230`) say what the kept `inst`,
  `enc` and `entry` keys hold. The `EachSource` comment says "guide".
- The Theme.lua legend (`:9-18`) lists `Theme`, `Size`, `C`/`F`, `UI`,
  `guide`, `encounter` and `entry`, and says "across the addon's files".
  READABLE-CODE §8 names `encounter` and `entry`. STYLE-GUIDE.md and the
  agent guides have not changed since round 1, and they are still correct.
- The merge: the only hunk with changes from both sides,
  `tests/smoke/modules/UI-MapEdit.lua:645-657`, keeps dev's new
  `CheckDrawn(area, 7, 11)` and `CheckDrawn(..., 5, 9)` limits and the
  branch's `guide.id`. The rest of `5c9bf60` came in cleanly, and none of
  its lines use an old alias.

### Round 2 checks

| Check | Result |
| --- | --- |
| `3bf4fe1` gives byte-identical `luac5.1 -s` | **Passed, 30 of 30** changed Lua files (`49aa670` against `3bf4fe1`, `cmp` on `luac5.1 -s` output) |
| `e5ea2ae` gives equal listings | **Passed, 15 of 15.** I compared `luac5.1 -l -p` output with `[line]` numbers, `<file:line,line>` headers and addresses taken out. 5 files are also byte-identical with `-s`. The other 10 differ only in `linedefined`, because of the wraps. I used `-l` rather than round 1's `-l -l` here: `-l -l` prints local and upvalue names, which this commit changes on purpose |
| Whole branch: `origin/dev` against `e5ea2ae` | **Passed, 49 of 49.** Same `luac -l` comparison, with the upvalue-name comments on `GETUPVAL`/`SETUPVAL` also taken out. Every instruction and every constant (all strings, so `L["..."]` keys, SavedVariables keys, addon message formats, devexport text, field and global names) is the same as on `dev`, merge included |
| `luac5.1 -p` | Passed (49 files) |
| `luacheck --no-global -q` against `origin/dev` | **No new warnings** (messages compared with line numbers taken out). `scenarios.lua` loses the same three "line is too long" warnings as in round 1. No added Lua line is over 120 characters |
| `python3 tools/locales.py --check` | Passed (exit 0) |
| `python3 tools/translations.py` | Exit 0, the same 50 "not used any more" lines as on `dev` |
| `tests/smoke/check.sh` | **All passed** in all three runs: dev (184 files), packaged (178), and dev with secret values. 962 `ok` lines in total |
| Scraper unittest | Not run: no scraper change |

### Is any encounter still called `entry`, or any row or item called `encounter`?

- **No encounter is called `entry`.** I went through every `entry`
  declaration in `NeedRoll/` and `tests/` (about 170). Each one is a loot row
  (`for _, entry in ipairs(encounter.loot)`), a pane or list row
  (`pane.entries`, `cell.entry`, quest rows from `DungeonQuests`), a shopping
  or wishlist item, a Drops outbox record, a name-queue item, or a test row.
  The one that is none of these is `IsNamed`'s generic `entry` (R10).
  `allDropsEncounter` is right: `ns.UI.AllDrops` builds a made-up encounter
  (`{ id = "ALL_DROPS", loot = {} }`) that the loot pane opens like any
  other.
- **Rows did become `encounter`**, in the encounter list and the recipe list
  (R7). These were `enc` on `dev`, so the renamer was faithful to the token,
  but the whole word now states something the code often contradicts.
  Everywhere else (MainFrame, Core, Data, API, Search, LootGrid, MapEdit,
  Overview) all 233 `encounter` declarations are real encounters.

### The new names

- `encounter` is right. It is the word `UI.state.encounter`,
  `UI:SelectEncounter` and the `encounters` data key already use, and now
  nothing else is called that.
- `entry` is now consistent with what it meant on `dev`, apart from R7's
  rows and R10.
- `encounterWhat`: odd, as you say. R9 suggests `encounterNameOrID`.
- `childGuide`/`childEncounter`, `guideID`, `byGuide`, `sameGuide` and
  `encounterID` are good. They follow `guide`, so if R8 goes the
  `instance` way they change with it.
- `row` (MainFrame:1905) and `treeRow` are right.

### `instance` next to `guide`

This is a real inconsistency, and Mike should decide it (R8). Both names
hold the same `Data/Data.lua` table in the same role. Every key, module
function and public API parameter says `instance`, and the same reasoning
that chose `encounter` points to `instance`.

### Docs against code

The Theme.lua legend and READABLE-CODE §8 now match the code for `Theme`,
`Size`, `C`, `F`, `UI`, `guide` and `encounter`. For `entry` they disagree
with each other ("or an item on a list" is in Theme.lua only) and both miss
`IsNamed` (R10). Once R7 is done, "a row's data in a list pane" will also be
true of the encounter list. STYLE-GUIDE.md has no alias left that doesn't
exist, and its Theme helpers are all still defined (I re-checked the 35
`function Theme:` names).

## Round 3

Reviewed `14b477a..4a78cb9`. `6315f97` fixes R7, R9, R10 and R11, and
`4a78cb9` fixes R8 (`guide` → `instance`; Mike chose `instance` on the card).
This is the last round, so every item has a final status above: fixed, open
for Mike, or not worth doing (below).

### Round 3 checks

| Check | Result |
| --- | --- |
| `6315f97` | 8 Lua files: **4 byte-identical** (`luac5.1 -s`), **4 listing-equal** (`luac -l` with line numbers, headers, addresses and upvalue names taken out), 0 different |
| `4a78cb9` | 33 Lua files: **29 byte-identical**, **4 listing-equal**, 0 different |
| Whole branch, `origin/dev` against `4a78cb9` | 50 Lua files (`tests/smoke/modules/API.lua` has joined, through R11): **32 byte-identical, 18 listing-equal, 0 different**. This matches the implementer's figures. No instruction or constant changed anywhere: every `L["..."]` key, SavedVariables key, addon message, devexport string, field and global is as on `dev` |
| `luac5.1 -p` | Passed (50 files) |
| `luacheck --no-global -q` against `origin/dev` | **No new warnings.** `UI/Theme.lua`'s existing "shadowing upvalue argument 'self' on line N" warnings name lines 2 further down, because the legend is two lines longer. The text and count are the same. `scenarios.lua` loses six "line is too long" warnings. No added Lua line is over 120 characters |
| `python3 tools/locales.py --check` | Passed (exit 0) |
| `python3 tools/translations.py` | Exit 0, the same 50 lines as on `dev` |
| `tests/smoke/check.sh` | **All passed** in all three runs: dev (184 files), packaged (178), and dev with secret values. 962 `ok` lines |
| Scraper unittest | Not run: no scraper change |

### What I checked in the fixes

- **R7.** No `encounter` local or parameter is read for `.header`,
  `.quest`, `.marker`, `.wingHeader`, `.members` or `rawget(..., "setRow")`
  any more. The one remaining hit, `IsSetRow(encounter)` in
  `SetupEncounterRow` (`Lists.lua:1908`), is covered under "Not worth doing".
  `local isEncounter = not HeaderLike(entry) and not entry.wingHeader ...`
  (`:2004`) now reads correctly. `SelectedPin(entry)` and `BossLevel(entry)`
  are right as `entry`: `AfterRow` and `Note` pass them any row, and both
  begin by turning away headers, wing rows, quests and markers.
  `SetupQuestRow(row, entry, ...)` was only renamed, which keeps the bytecode
  proof. `entry.quest` reads fine there, so the restructure suggested in R7
  isn't needed. The instance list's CreateList callbacks also take headers
  and the level marker, and now say `entry` too, which is consistent.
- **R8.** No `guide` is left in Lua outside three atlas names in
  `Data/IconList.lua` (data). Theme.lua's legend (`:9-21`) and READABLE-CODE
  §8 (`:112-120`) define `instance`, `encounter` and `entry` in the same
  words, and both point at `ns.Data.instances`/`UI.state.instance`. I grepped
  the changed comments for wording the rename could garble ("an instance
  instance", "a instance", "an an"): none.
- **`place` in `NeedRoll_ShowMap`** (`API.lua:167-176`). The public
  `instance` parameter is the caller's name or ID (documented in
  `docs/API.md` as `NeedRoll_ShowLoot(instance, boss)` and so on), so the
  matched table needs another name, and `place` fits the file's `PLACES`
  list. `MatchRank` (`:62`) also has a local `place`, the name of the whole
  place a wing belongs to ("Scarlet Monastery"). They are separate functions
  and both mean "a place", so I left it under "Not worth doing".
- **R9.** `ShowIn(categories, what, encounterNameOrID)`, and its comment no
  longer has to explain the name.
- **R10.** `IsNamed(key, named, name)` with "(an instance, encounter, boss or
  quest)". The two definitions of `entry` now agree.
- **R11.** `otherProfession`/`otherRecipe`, `IsOpenOn(...)` in both test
  files, and `candidate` for the old `e`.

### Not worth doing (final)

- `SetupEncounterRow(row, encounter)` also receives a colour set's row
  (`IsSetRow(encounter)` at `Lists.lua:1908`). A set row stands in for its
  first recipe and reads that recipe's fields through its metatable (see
  the comment over `IsSetRow`, `:1216-1218`), so `encounter` is
  close enough. The function's own comment says so ("a colour set's row the
  sections' arrow").
- `place` in `NeedRoll_ShowMap` against `place` in `MatchRank` (above).
- `what` in `ShowIn`/`Instances`/`MatchRank`/`Encounter`. It is a vague
  name, but older than this change and outside Mike's decision.
- `scenarios.lua`'s `local S = {}` and the `function(e)` finders in
  `tests/smoke/modules/UI-Lists.lua` (`:98-363`). Both are from `dev`,
  test-only, and on lines this change doesn't touch.

### Left for Mike

- Nothing. R12 was fixed after round 3 (see R12).

## Area notes

### Readability

I read the whole `ad61a5d` diff for renames that change meaning. Every
`inst`→`guide` I sampled (API, Shopping, LootGrid, MainFrame, Search, Lists,
Data) names an instance, and every `T`→`Theme`/`S`→`Size` is mechanical. No
`T.`, `T:`, `S.` or `local T`/`S`/`inst`/`enc` is left as a local in
`NeedRoll/` or `tests/`. The only `T[`/`T.` matches are `|T` texture escapes
inside patterns (`FrameDebug.lua:351`, `tests/smoke/wow.lua:181`,
`UI-LootGrid.lua:323`). The remaining `inst`/`enc` words are all field
accesses or constructor keys (`result.inst`, `src.enc`, `{ inst = guide }`),
as Mike decided. `scenarios.lua`'s `S` (the scenario list) is untouched and
was never `Theme.size`, but it is still a one-letter name that §8 doesn't
list. That is older than this change and out of its scope. The files that
declare `local Size` use `Size.` everywhere. The four `Theme.size.` matches
in `MainFrame.lua` (80, 81, 639, 651) are in comments that name the field.
The comments that name helpers now say `Theme:FitAtlas`, `Theme:CardBackdrop`
and so on. Formatting: no added Lua line is longer than 120 characters. The
wraps in `5ef7527` indent their continuations 4 spaces, as the files already
do, with no tabs. The agent guides' rewrapped Markdown runs past 80 columns,
but `implementer.md` already had lines up to 258, so nothing is flagged.

### WoW API

The change adds and drops no game call, event, widget method, template,
atlas or `Enum`. The stripped bytecode of all 49 changed Lua files is
identical, so the set of globals read (`GETGLOBAL` constants) and of methods
called is the same as on `dev`. No new global appears (nothing to add to
`.luarc.json`). No function's upvalue count changes, because upvalue slots
are positional and the bytecode matches, so `CreateOverview` stays as close
to the 60-upvalue limit as it was. No `InCombatLockdown`, secret-value or
taint path changes.

| Game API added or newly called | In Ketho's `forever` lists | Where looked |
| --- | --- | --- |
| none | n/a | bytecode comparison (Checks) |

`tests/smoke/wow.lua` is unchanged. A rename needs no new smoke scenario, and
`check.sh` passes in all three runs.

### Redundant code

The rename adds no helper, widget, cache or `OnUpdate`. Every helper the
updated docs name (`Theme:Pill`, `Row`, `Label`, `Text`, `ScaledFont`,
`ScrollView`, `Dialog`, `SetTextColor`, `QualityColor`, `CardBackdrop`,
`CheckBox`, `ScrollColumn`, `JoinDots`, `ConfirmPill`, `SearchBox`,
`LabelToggle`, `Arrow`, `InsigniaSize`, `ClassBadge`, `QualityIcon`,
`MaskRound`, `Border`, `ChipUnderline`, `FitAtlas`, `Insignia`, `WithIds`,
`CreatePanel`, `Palette`, `Fonts`, `OnEscape`, `LineWidth`, `SetSkin`,
`Rounded`, `ColorCode`, `Opaque`) and fields (`Theme.tip`, `iconCrop`,
`roundMask`, `textScale`, `DOTS`, `scaledFrom`, `showIds`) exist in
`UI/Theme.lua` as `function Theme:`/`Theme.`. That file has 52
`^function Theme:` lines, so the guides' `grep '^function Theme:'` works. No
dead code is added. The `luacheck` messages are unchanged.

### Security

None. The change touches no addon message, chat, SavedVariables format,
`Credits.txt`, `.pkgmeta`, scraper, tool or workflow. The Drops.lua edits are
local renames only, and Drops.lua's bytecode, including every pattern and
length constant used on `CHAT_MSG_ADDON` input, is byte-identical. No player
name appears in the diff.

### Docs against code

`docs/STYLE-GUIDE.md` has no `T.`/`T:`/`S.` left. Every `Theme.size.*`,
`Theme.color.*`, `Theme:*` it now names exists (checked above), and the
values it gives were not touched. `READABLE-CODE.md` §6 is correct. §8 is
not correct for `entry` (R2). `Theme.lua`'s legend has the same problem (R2).
The agent guides match the code.

## Round history

- 2026-10-18 · `023bc25` · Round 1 · Changes needed (0 blocking, 2 should fix, 4 nits) · opened R1-R6
- 2026-10-18 · `e5ea2ae` · Round 2 · Changes needed (0 blocking, 2 should fix, 4 nits) · closed R1-R6 (`3bf4fe1`, `e5ea2ae`); opened R7-R11
- 2026-10-18 · `4a78cb9` · Round 3 (final) · Ready (1 nit left for Mike) · closed R7-R11 (`6315f97`, `4a78cb9`); opened R12 (left for Mike)

## Integration

Applied onto `origin/dev` at `49e8372` (dev had not moved since the branch's
last merge) on `claude/addon-readability-pass-rg51s6`. The patch applied
cleanly. On the result: `tests/smoke/check.sh` all passed in dev, packaged and
secret-values modes, and `python3 tools/locales.py --check` exits 0.
