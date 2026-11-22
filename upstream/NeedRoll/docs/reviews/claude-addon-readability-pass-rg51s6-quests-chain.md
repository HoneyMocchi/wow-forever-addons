# Review: Quests list chain trees follow Data/Chains.lua

| | |
| --- | --- |
| Branch | `quests-chain` into `origin/dev` (PR not opened yet) |
| Commit reviewed | `a274df6` (no uncommitted changes) |
| Date | 2026-10-18 |
| Round | 2 |
| Verdict | **Ready** (0 blocking, 0 should fix, 0 nits open; R1-R3 fixed in round 2) |
| Needs | `/reload` (one Lua file changed; no `.toc`, XML or SavedVariables change) |

## What the change does

In a dungeon's Quests group, quests of one chain are drawn as a tree: the
chain's first quest here as a normal row, its later steps under it, each with
a numbered step circle. Before the change the tree read only each quest's own
chain fields (`chainStart`, `chainStep` in `Data/Quests.lua`, which come from
CMaNGOS Classic-DB). The quest page (Overview) instead reads whole chains from
`Data/Chains.lua` (QuestieDB) through `ns.Data:Chain`. The change makes
`ChainSpot` (`NeedRoll/UI/Lists.lua:1128-1138`) ask `ns.Data:Chain` first, for
the list's side and the player's class, and fall back to the quest's own
fields; `ChainTrees` and `ns.UI.DungeonQuests` pass the side through. Since
round 2, a quest that falls back to its own fields while its `chainStart` has
a Chains.lua chain that leaves it out (a branch off that chain) stands alone
instead of being drawn as one of that chain's numbered steps. A new smoke
scenario checks Blackfathom Deeps on both sides.

What a player sees change (checked for every dungeon, both sides, all nine
classes, by dumping `ns.UI.DungeonQuests` before and after; only Blackfathom
Deeps differs):

| Side | `origin/dev` | `d37daa6` (round 1) | `a274df6` (round 2) |
| --- | --- | --- | --- |
| Alliance | `971 1198 1275 1200 1654 1199` | `971 1198 1200:2. 1275 1654 1199` | `971 1198 1200:2. 1275 1654 1199` |
| Horde | `6562 6563:2. 6565 1198 6561 6921 6922` | `6562 6563:2 6565:3. 1198 6561 6921 6922` | `6563 6562 6565:3. 1198 6561 6921 6922` |

(`id:step` is a row under a tree with its step circle; `.` marks the last
row of a tree.) The Alliance move is the one asked for. Round 1's Horde move
was R1; in round 2, Allegiance to the Old Gods (6565) sits under Trouble in
the Deeps (6562) as step 3, as on its quest page, and The Essence of Aku'Mai
(6563) stands alone at its place in data order. Its own page still says
"Step 2 of a chain that starts with [Trouble in the Deeps]".

## Scope

- `NeedRoll/UI/Lists.lua`: `ChainSpot(quest, side)` asks `ns.Data:Chain`
  first, and keeps a branch off a Chains.lua chain out of its tree; `ChainTrees(list, side)` passes the side; `ns.UI.DungeonQuests`
  calls `ChainTrees(list, faction)`. Read in full: `OtherClass`, `ChainSpot`,
  `ChainTrees`, `DungeonQuests`, `QuestCount`, `ShowChainStep` (the only
  reader of `chainStep`).
- `tests/smoke/modules/UI-Lists.lua`: new scenario "quest chain trees
  follow Data/Chains.lua, else the quest's chain fields" (round 2: passes the
  side to `DungeonQuests` directly, asserts 6562 -> 6565 step 3 and 6563
  standing alone).
- Read for context, not changed: `ns.Data:Chain` and `StepFits`
  (`NeedRoll/Data/Data.lua:286-325`), `Chain.Of`, `ChainStep`, `ChainText`
  (`NeedRoll/UI/Overview.lua`), `UI:SetQuestSide` (`NeedRoll/UI/MainFrame.lua:1809`),
  the chain generator `scraper/needroll_scraper/chains.py`.
- Generated data: no file under `NeedRoll/Data/` is changed. The BFD rows of
  `Data/Chains.lua` (line 22, `{ side = "Horde", 6562, 6564, 6565 }`; line 23,
  `{ side = "Alliance", 1198, 1200 }`) and `Data/Quests.lua:497-502` were read
  as inputs only.

## Checks

Round 2 (`a274df6`):

| Check | Result |
| --- | --- |
| `luac5.1 -p` on both changed files | passed |
| `luacheck --no-global -q`, changed files | 0 warnings / 0 errors on both (same as `origin/dev`) |
| `python3 tools/locales.py --check` | passed (exit 0; no strings added) |
| `python3 tools/translations.py` | exit 0; same unused-string list as `origin/dev` |
| `tests/smoke/check.sh` | all passed in all three runs (dev 184 files, packaged 178, dev with secret values) |
| New scenario against `origin/dev`'s `Lists.lua` | fails as it should: `UI-Lists.lua:314: Blackfathom Villainy isn't step 2 under In Search of Thaelrid` |
| New scenario against round 1's `Lists.lua` (`d37daa6`) | fails as it should: `UI-Lists.lua:320: Allegiance to the Old Gods isn't step 3 under Trouble in the Deeps` |
| Chain-tree dump, every dungeon, both sides, all nine classes, `origin/dev` vs `a274df6` | only Blackfathom Deeps differs (table above) |
| Scraper unit tests | not run: no scraper change |

Round 1 (`d37daa6`):

| Check | Result |
| --- | --- |
| `luac5.1 -p` on both changed files | passed |
| `luacheck --no-global -q`, changed files vs `origin/dev` copies | 0 warnings / 0 errors on both, before and after: no new warnings |
| `python3 tools/locales.py --check` | passed (exit 0; the change adds no strings) |
| `python3 tools/translations.py` | ran, exit 0; lists strings the locale files no longer use ("Level", "Press a key", "Quest chain", ...), the same as on `origin/dev` since the change adds or drops no `L[...]` |
| `tests/smoke/check.sh` | all passed in all three runs (dev 184 files, packaged 178, dev with secret values) |
| New scenario against `origin/dev`'s `Lists.lua` | fails as it should: `UI-Lists.lua:317: Blackfathom Villainy isn't step 2 under In Search of Thaelrid` |
| Scraper unit tests | not run: no scraper change |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | blocking | Readability (fidelity) | `NeedRoll/UI/Lists.lua:1132-1137`, `tests/smoke/modules/UI-Lists.lua:319-322` | Horde BFD tree puts Allegiance to the Old Gods after The Essence of Aku'Mai, mixing two chains | fixed in round 2 (`a274df6`) |
| R2 | nit | Redundant code | `tests/smoke/modules/UI-Lists.lua:299-327` | Test flips the window's side switch where `DungeonQuests` takes the side | fixed in round 2 (`a274df6`) |
| R3 | nit | Readability | `tests/smoke/modules/UI-Lists.lua:303-313` | `Tree` helper's comment leaves out `count` and the `.` mark | fixed in round 2 (`a274df6`) |

### R1 · Horde BFD tree puts Allegiance to the Old Gods after The Essence of Aku'Mai, mixing two chains

- **Severity:** blocking
- **Area:** Readability (fidelity: a list that tells the player something false)
- **Where:** `NeedRoll/UI/Lists.lua:1132-1137` (`ChainSpot`), and the
  scenario that asserts the result, `tests/smoke/modules/UI-Lists.lua:319-322`
- **Status:** fixed in round 2 (`a274df6`)

**What's wrong.** `ChainSpot` now gets steps from two numbering schemes and
`ChainTrees` sorts them into one tree whenever the key (the first quest)
matches:

```lua
local steps, step = ns.Data:Chain(quest.id, side, class)
if steps then return steps[1][1], step end
if quest.chainStart then return quest.chainStart, quest.chainStep or 2 end
```

In Horde BFD the three quests land on key 6562 from different chains:

- 6562 Trouble in the Deeps: `Data/Chains.lua` chain `6562, 6564, 6565`, step 1.
- 6565 Allegiance to the Old Gods: same Chains.lua chain, step 3.
- 6563 The Essence of Aku'Mai: on no Chains.lua chain (QuestieDB doesn't
  link it), so its own fields: `chainStart = 6562, chainStep = 2`
  (`Data/Quests.lua:497`, from CMaNGOS).

The tree becomes Trouble in the Deeps, then ② The Essence of Aku'Mai, then
③ Allegiance to the Old Gods. The two step numbers are each true in their
own chain, but they are not one sequence: 6563 and 6565 are two branches off
6562. Step 2 of 6565's chain is 6564, the Damp Note quest, which isn't a
dungeon quest and so has no row.

**Why it matters.** Yes, this misleads a player. A tree with circles 1, 2, 3
reads as "do these in this order", and the empty step-2 slot in 6565's chain
is filled by 6563. A Horde player is told that Allegiance to the Old Gods
comes after collecting 20 Sapphires of Aku'Mai, which it doesn't; what it
does need is the Damp Note that drops from Blackfathom Tide Priestesses in
the entrance tunnel (`scraper/quests/forever.json` "details" for 6564). The
list then contradicts the quest page it was meant to match: 6565's page
(`Chain.Of` -> `ns.Data:Chain`) shows Trouble in the Deeps -> Allegiance to
the Old Gods (Damp Note) -> Allegiance to the Old Gods, with no Essence of
Aku'Mai. On `origin/dev` the list made no false claim here: 6565 stood
alone. The ask's purpose ("the tree matches the quest page's chain", as
`ChainSpot`'s new comment says) is broken by this case, and the new test
locks it in as intended ("Trouble in the Deeps' chain isn't 6562, 6563 then
6565").

Gaps in the circles are already normal in the list (on `origin/dev`:
`4241 4322:12`, `4341 4362:6`, `4081 4082:2 4121:4 4132:5`), so a tree with
step 3 and no step 2 reads correctly to players; a wrong quest in the gap
does not.

**Evidence.** Dump of `ns.UI.DungeonQuests` for every instance, side and
class on `origin/dev` vs `d37daa6` (table above; only BFD changes).
`Data/Chains.lua:22`, `Data/Quests.lua:497-499`. The data disagreement is
between sources: `chains.py` builds Chains.lua from QuestieDB's
`preQuestSingle`/`preQuestGroup` (6564 needs 6562; 6563 has no link, so its
one-step chain is dropped by `if len(steps) < 2`), while 6563's
`chainStart` comes from Classic-DB. Which one matches the live game for 6563
is not settled here (inferred; no in-game check).

**Fix.** Smallest honest fix: a quest that falls back to its own fields does
not join a tree whose first quest has a Chains.lua chain on this side that
leaves it out; it stands alone instead. That is one condition in
`ChainSpot`:

```lua
local function ChainSpot(quest, side)
    local _, class = UnitClass("player")
    local steps, step = ns.Data:Chain(quest.id, side, class)
    if steps then return steps[1][1], step end
    -- Its start is on a Data/Chains.lua chain without it: a branch off that
    -- chain, which a tree of numbered steps would draw as one of its steps.
    if quest.chainStart and not ns.Data:Chain(quest.chainStart, side, class) then
        return quest.chainStart, quest.chainStep or 2
    end
    return quest.id, 1
end
```

Tried in a scratch copy against every dungeon, both sides, Warrior,
Paladin and Warlock: only BFD changes, Alliance as asked
(`971 1198 1200:2. 1275 1654 1199`), Horde
`6563 6562 6565:3. 1198 6561 6921 6922`: 6565 sits under Trouble in the
Deeps as step 3, matching its page; 6563 stands alone at its place in data
order. 6563's own page still says "Step 2 of a chain that starts with
[Trouble in the Deeps]", so nothing is lost, only not drawn as a tree. Update
the `ChainSpot` comment to name the rule, and change the scenario's Horde
assertion to `Tree(list, 6562, 2) == "6562:1 6565:3."` plus a check that
6563 has no `chainStep`.

The other way (keep `origin/dev`'s 6562 -> 6563 tree and leave 6565
standalone, i.e. prefer the quest's own fields when it has any) is also
honest but goes against the ask, since 6565's list row would then disagree
with its page.

### R2 · Test flips the window's side switch where `DungeonQuests` takes the side

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `tests/smoke/modules/UI-Lists.lua:299-327`
- **Status:** fixed in round 2 (`a274df6`)

**What's wrong.** The scenario opens the window, saves `ui.state.questSide`,
calls `ui:SetQuestSide("Alliance")` / `("Horde")` inside `W.Restoring` and
restores both afterwards, only so that `ns.UI.DungeonQuests(bfd)` picks the
side. `ns.UI.DungeonQuests(instance, faction, professions)` already takes the
side (`Lists.lua:1183`), and `UI:SetQuestSide` (`MainFrame.lua:1809-1814`)
also rebuilds and refreshes the window, work the test doesn't look at.

**Why it matters.** Eleven lines of setup and teardown a reader has to
follow, and a test of a pure data function that depends on the window's
state. Less code is the goal (`docs/READABLE-CODE.md`, top).

**Evidence.** Lines read; `DungeonQuests` caches per `instance.id .. ":" .. faction`,
so passing the side gives the same entries the switch would.

**Fix.**

```lua
local bfd = ns.Data:Get("BLACKFATHOM")
assert(Tree(ns.UI.DungeonQuests(bfd, "Alliance"), 1198, 2) == "1198:1 1200:2.", ...)
assert(Tree(ns.UI.DungeonQuests(bfd, "Horde"), 6562, 2) == "6562:1 6565:3.", ...)  -- after R1
```

and drop `OpenWindow`, `side` and the `W.Restoring` wrapper (the `W`
parameter becomes `_`).

### R3 · `Tree` helper's comment leaves out `count` and the `.` mark

- **Severity:** nit
- **Area:** Readability
- **Where:** `tests/smoke/modules/UI-Lists.lua:303-313`
- **Status:** fixed in round 2 (`a274df6`)

**What's wrong.**

```lua
-- The quest IDs of `list` from `first` on, with their steps, as "id:step".
local function Tree(list, first, count)
```

The comment doesn't say that `count` rows are read, and the strings the
assertions compare (`"1198:1 1200:2."`) carry a trailing `.` the comment
never explains; a reader has to work out from
`(entry.chainLast and "." or "")` that it marks the tree's last row.

**Why it matters.** `docs/READABLE-CODE.md` section 5: a newcomer should
read the assertion strings without decoding the helper.

**Fix.** `-- The \`count\` quests of \`list\` from \`first\` on, as "id:step",
step 1 for a row with no step circle and "." after a tree's last row.`

## Round 2 verification

- **R1.** `ChainSpot` (`Lists.lua:1132-1143`) now reads
  `if quest.chainStart and not ns.Data:Chain(quest.chainStart, side, class) then`
  before using the quest's own fields, with a comment saying why (a branch
  would be drawn as one of the chain's numbered steps). The condition only
  runs when the quest is on no Chains.lua chain itself, so any chain its start
  is on necessarily leaves it out: the comment is accurate. The dump shows
  Horde BFD as `6563 6562 6565:3.` and nothing else changed. The scenario
  asserts both halves (`"6562:1 6565:3."` and `"6563:1"`) and fails against
  round 1's code.
- **R2.** The scenario takes `(_, ns)`, calls `ns.UI.DungeonQuests(bfd, "Alliance")`
  / `(bfd, "Horde")`, and no longer opens the window or flips the switch.
- **R3.** The helper's comment now reads "The `count` quests of `list` from
  `first` on, as "id:step", step 1 for a row with no step circle and "."
  after a tree's last row."

Re-read in full for round 2: `ChainSpot`, `ChainTrees`, `DungeonQuests`,
`QuestCount`, `ShowChainStep`, the whole scenario. New lines all under 120
characters. Nothing new to ask for. Left as notes, not findings: the
`faction`/`side` naming split between `DungeonQuests` and `ChainTrees`
(see Readability notes), and Deadmines' `214 166:7.` tree, where two
Chains.lua chains sharing their first six steps (`Data/Chains.lua`, the two
`65, 132, ... 155` rows ending in 214 and 166) end at the same step 7 and are
drawn as a tree. That is identical on `origin/dev` (from the quests' own
fields), so this change neither causes nor worsens it; a same-step pair
reads as alternatives, as elsewhere in the list (`3906 3981:2 3907:2 7201:2`).

## Area notes

### Readability

Checked against every section of `docs/READABLE-CODE.md`. Names are the
game's (`quest`, `side`, `steps`, `step`, `class`); no one-letter names
outside the allowed ones (`W`, `i`). `ChainSpot` stays one job (where a
quest sits in its chain) with guard-style early returns and one level of
nesting; `ChainTrees` is unchanged apart from passing `side`. Comments say
why (match the quest page) and don't narrate the change; `ChainSpot`'s
comment will need the R1 rule. 4-space indents, LF, lines under 120. No Lua
5.1 traps: the `and/or` forms used (`quest.chainStep or 2`,
`entry.chainLast and "." or ""`) have non-nil/false middle values.
Consistency: `ChainSpot` asks for the chain exactly as `Chain.Of` does
(`Overview.lua:398-399`: `UnitClass("player")`, then
`ns.Data:Chain(quest.id, side, class)`). One small inconsistency left as a
note, not a finding: `DungeonQuests` names the value `faction` and passes it
as `side`; the rest of this code (`QuestSide`, `HasSideQuests`,
`ns.Data:Chain`) says `side`. Renaming `DungeonQuests`' parameter would be
a separate tidy-up. The player-class lookup now runs once per quest in
`ChainSpot` and again in `OtherClass`; the result is cached per dungeon and
side in `questLists`, so the cost is nil in practice.

### WoW API

| Call | Kind | In Ketho `forever` lists | Where looked |
| --- | --- | --- | --- |
| `UnitClass` | global function | yes | `GlobalAPI.lua:6660` (local copy of the `forever` branch) |

No new events, widget methods, templates, atlases or `Enum`s. `UnitClass`
is already mirrored in the smoke stand-in (`tests/smoke/wow.lua:1209`), and
the change has its scenario. No async data (chain data is static Lua), no
secret values touched (quest IDs from the addon's own data, no tooltip or
quest-log text), no new globals (`luacheck` clean), no frame or combat
work. `ChainSpot` adds no upvalues beyond `ns`. No UI change in sizes,
fonts, colors or layout, so `docs/STYLE-GUIDE.md` needs no edit (its
"Quests list" paragraph, line 139, stays true). No player-facing text added.

### Redundant code

Compared against `ns.Data:Chain` (used, not duplicated), `Chain.Of` in
`Overview.lua` (same call pattern; its fallback builds a full step list the
list doesn't need, so sharing it would not shrink anything), `T:ClassToken`
(not needed: `UnitClass`'s second return is already the token
`ns.Data:Chain` wants), and the `questLists` cache (the trees are still
built once per dungeon and side). No dead code, no debug prints. R2 covers
the test's extra setup.

### Security

None: the change reads only the addon's own generated data and
`UnitClass("player")`. No addon messages, chat, SavedVariables, names or
credits are read or written.

## Round history

- 2026-10-18, `d37daa6`, round 1: **Changes needed**; opened R1 (blocking),
  R2 (nit), R3 (nit).
- 2026-10-18, `a274df6`, round 2: **Ready**; closed R1, R2, R3; no new
  findings.
