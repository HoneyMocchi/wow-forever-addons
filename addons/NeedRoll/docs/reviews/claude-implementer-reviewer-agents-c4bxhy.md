# Review: Implementer and reviewer agents for Claude Code (Review Doc follow-up)

| | |
| --- | --- |
| Branch | `claude/implementer-reviewer-agents-c4bxhy` into `dev` (round 1: PR #592, now merged; round 2: follow-up PR, number not known yet) |
| Commit reviewed | `7c210a3` (no uncommitted changes besides this doc) |
| Date | 2026-10-17 |
| Round | 2 |
| Verdict | **Ready** (0 blocking, 0 should fix, 2 nits) |
| Needs | Neither `/reload` nor a restart: no addon file changes. Claude Code picks up the changed agents and `/build` command in a new session (or after `/agents`). |

## What the change does

**Round 2 (follow-up PR).** #592 merged after round 1 and the branch was
rebased on `origin/dev`. The PR now holds two commits: `acb8c4f` (the
reviewer writes a Review Doc under `docs/reviews/` for every PR, the
implementer leaves it alone and commits it with the change, `/build`
reports its path and links it from the PR, `CLAUDE.md` makes it a rule, and
`docs/reviews/README.md` explains the folder) and `7c210a3` (fixes for the
round 1 findings below). The round 1 text that follows describes the whole
tooling as it was first reviewed.

**Round 1 (PR #592).**

Adds Claude Code tooling only. A new **implementer** agent
(`.claude/agents/implementer.md`) builds a change the repo's way and runs the
repo's checks; a new **reviewer** agent (`.claude/agents/reviewer.md`)
reviews a diff for readability, WoW: Forever API use (against Ketho's
`forever` resource lists), redundant code and security, and writes a Review
Doc under `docs/reviews/`. A `/build <task>` command
(`.claude/commands/build.md`) loops the two, capped at three review rounds.
The root `CLAUDE.md` gains a rule that code changes go through the loop and
that Claude's PRs carry their Review Doc; `docs/reviews/README.md` explains
the folder; `.gitignore` ignores `.claude/settings.local.json`. Nothing a
player sees changes.

Since these are prompt files, the review checks them as instructions: every
path, function, command and URL they name was checked against the repo or
fetched; contradictions between the files, and anything in them that would
make an agent do the wrong thing, are findings.

## Scope

Round 2 (`git diff origin/dev...HEAD`, 5 files):

- `.claude/agents/reviewer.md`: Review Doc section and report format
  (`acb8c4f`); R1, R2, R3, R4, R6 paths, R7 scope line (`7c210a3`).
- `.claude/agents/implementer.md`: "don't edit the Review Doc, commit it
  with the change" (`acb8c4f`); R2, R5, R6 paths (`7c210a3`).
- `.claude/commands/build.md`: report the Review Doc path, commit and link
  it in the PR.
- `CLAUDE.md`: Review Doc rule; three-round cap (R7).
- `docs/reviews/README.md` (new): what the folder holds.

This doc itself is left out, as the reviewer prompt now says.

Round 1 (PR #592):

- `.claude/agents/implementer.md` (new, 93 lines): the implementer's rules,
  checks and hand-back format.
- `.claude/agents/reviewer.md` (new, 233 lines): the four review areas, the
  checks, the Review Doc layout and the report format.
- `.claude/commands/build.md` (new, 23 lines): the `/build` loop.
- `CLAUDE.md` (+7): the agent loop and Review Doc rule.
- `docs/reviews/README.md` (new, 8 lines): what the folder holds.
- `.gitignore` (+3): ignores `.claude/settings.local.json`.

No generated files in the diff.

## Checks

Round 2: `python3 tools/locales.py --check` passed (exit 0);
`python3 tools/translations.py` passed (exit 0). Lua 5.1 is still not
installed (`which lua5.1 luac5.1` finds nothing), and no Lua, addon or
scraper files changed, so luac, smoke and scraper tests didn't run. New
paths in the fix were checked: `NeedRoll/Data/Abilities.lua` exists
(generated boss abilities, one spell ID each);
`SHIPPED_CREDITS` is at `scraper/needroll_scraper/observed.py:145`;
`scraper/quests/blacklist.txt` exists.

Round 1:

| Check | Result |
| --- | --- |
| `luac5.1 -p` on changed Lua files | Not run: no Lua files changed; Lua 5.1 isn't installed here either (`sudo apt-get install -y -q lua5.1` failed: "Couldn't find any package by glob 'lua5.1'") |
| `python3 tools/locales.py --check` | Passed (exit 0) |
| `python3 tools/translations.py` | Passed (exit 0; only "not used by NeedRoll any more" notices, e.g. `zhTW.lua: ... Level`, which the script reports without failing) |
| `tests/smoke/check.sh` | Not run: no addon changes, and it needs `lua5.1` |
| `cd scraper && python3 -m unittest discover -s tests` | Not run: no scraper changes |
| Paths, commands and URLs named in the agent files | See Area notes. All exist except `NeedRoll/Credits.txt` (written by the scraper only when someone opted in; see R1). All 8 Ketho `forever` raw URLs return 200; the `vscode-wow-api` `Annotations/` folder exists (a raw file under it returns 200); `warcraft.wiki.gg` couldn't be reached from this session (proxy refused), so not verified |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Security | `.claude/agents/reviewer.md:117-120` | Reviewer treats the shipped `NeedRoll/Credits.txt` as a name leak | fixed in round 2 (`7c210a3`) |
| R2 | should fix | Readability | `.claude/agents/reviewer.md:36`, `.claude/agents/implementer.md:40` | Wrong file header convention: repo uses `local _, ns = ...` | fixed in round 2 (`7c210a3`) |
| R3 | should fix | Readability | `.claude/agents/reviewer.md:9-12` | "You never edit files" contradicts writing the Review Doc | fixed in round 2 (`7c210a3`) |
| R4 | nit | WoW API | `.claude/agents/reviewer.md:65-70` | Mixin methods like `Item:ContinueOnItemLoad` aren't in the `forever` lists | fixed in round 2 (`7c210a3`) |
| R5 | nit | Readability | `.claude/agents/implementer.md:49` | "There is no combat log in the client" is inaccurate | fixed in round 2 (`7c210a3`) |
| R6 | nit | Redundant code | `.claude/agents/implementer.md:16,24,37`, `.claude/agents/reviewer.md:78,92` | Shared rules duplicated across both agents, already drifting in paths and helper lists | paths fixed in round 2 (`7c210a3`); duplication left as is: each agent runs standalone without the other's file in context |
| R7 | nit | Readability | `.claude/agents/reviewer.md:14-28,149`, `CLAUDE.md:14`, `.claude/commands/build.md:14` | Review Doc in its own scope; "until clean" vs three-round cap | fixed in round 2 (`7c210a3`) |
| R8 | nit | Readability | `.claude/agents/reviewer.md:22` | Skipping all of `docs/reviews/` also skips its `README.md` | fixed after round 2 (nit, no new round) |
| R9 | nit | Readability | `.claude/agents/implementer.md:38-42`, `.claude/agents/reviewer.md:69-71`, `CLAUDE.md:14-16` | Fix commit left ragged line wrapping | fixed after round 2 (nit, no new round) |

### R1 · Reviewer treats the shipped `NeedRoll/Credits.txt` as a name leak
- **Severity:** should fix
- **Area:** Security
- **Where:** `.claude/agents/reviewer.md:117-120`
- **Status:** fixed in round 2 (`7c210a3`). `reviewer.md` now says the one exception is `NeedRoll/Credits.txt`, written on purpose (`SHIPPED_CREDITS` in `scraper/needroll_scraper/observed.py`) with only players who chose "Credit my finds", and to flag a change that puts anyone else in it. The `CREDIT_SINCE` cut-off isn't named; acceptable, since "only players who chose" covers it.

**What's wrong.** The reviewer's Security list says:

> Character names and drop credits never reach anything public: release
> zips (`.pkgmeta`), `NeedRoll/Credits.txt`, or a public repo

But `NeedRoll/Credits.txt` is a file the addon *ships* on purpose, and it
holds names. The scraper writes it: `scraper/needroll_scraper/observed.py:145`
`SHIPPED_CREDITS = Path("Credits.txt")  # in the addon folder, shipped in releases`,
written by `write_credits` (`observed.py:194`), called from
`__main__.py:389-390` with `ROOT / "NeedRoll" / observed.SHIPPED_CREDITS`.
It names only players who ticked "Credit my finds" on kills saved from
`CREDIT_SINCE` (`observed.py:150`) on, and is left out while nobody opted in
(commit `bf5da87` removed the old one for exactly that reason; see
`NeedRoll/Core/Drops.lua:238-243`).

**Why it matters.** The rule as written is wrong both ways. On a PR where the
ingest writes `Credits.txt` with an opted-in name (the intended feature), the
reviewer would raise a name-leak finding against correct behaviour, and the
implementer may "fix" it by stripping credits players asked for. Meanwhile the
real rule (only opted-in names, only from `CREDIT_SINCE`, never names from
`observed.json`/SavedVariables in anything that ships) isn't stated, so a
change that, for example, moves `CREDIT_SINCE` back or writes non-opted-in
names into `Credits.txt` doesn't match any check.

**Evidence.** Lines read above; `ls NeedRoll/Credits.txt` fails today
(no opt-ins yet), `git log --all -- NeedRoll/Credits.txt` shows `bf5da87`
deleting it.

**Fix.** Replace the bullet with something like:

```markdown
- Character names and drop credits stay in this private repo (root
  `CLAUDE.md`). The one exception is `NeedRoll/Credits.txt`, which ships in
  releases: the scraper writes it (`observed.write_credits`) with only the
  players who ticked "Credit my finds" on kills since `CREDIT_SINCE`. Flag
  any change that puts other names in it, in any other shipped file
  (`.pkgmeta` decides what ships), or in a public copy of the repo.
```

### R2 · Wrong file header convention: repo uses `local _, ns = ...`
- **Severity:** should fix
- **Area:** Readability
- **Where:** `.claude/agents/reviewer.md:36`, `.claude/agents/implementer.md:40`
- **Status:** fixed in round 2 (`7c210a3`). Both files now say `local _, ns = ...`, with `Core/Init.lua` as the one file naming the first value, matching the grep (181 vs 1).

**What's wrong.** Both agents state the repo style is
`local addonName, ns = ...` at the top of every addon file
(reviewer: "`local addonName, ns = ...` at the top of every addon file";
implementer: "Every file starts `local addonName, ns = ...`").

**Why it matters.** The repo's actual convention is `local _, ns = ...`.
The implementer will write an unused `addonName` local into every new file,
and the reviewer, told this is the rule, will flag every correct file a
change touches (or wave through the wrong one). Either way the agents push
the code away from what's there.

**Evidence.** `grep -rhn -m1 '= \.\.\.$' NeedRoll --include=*.lua | sort | uniq -c`:
181 files `local _, ns = ...`, 1 file `local addonName, ns = ...`
(`NeedRoll/Core/Init.lua`, which uses `addonName` in `ADDON_LOADED` at
`Init.lua:99`). Examples: `NeedRoll/UI/MainFrame.lua:3`,
`NeedRoll/UI/Overview.lua:17`, `NeedRoll/UI/Lists.lua:3`.

**Fix.** In both files: "`local _, ns = ...` near the top of every addon
file (name the first value `addonName` only when the file uses it, as
`Core/Init.lua` does)."

### R3 · "You never edit files" contradicts writing the Review Doc
- **Severity:** should fix
- **Area:** Readability
- **Where:** `.claude/agents/reviewer.md:9-12`
- **Status:** fixed in round 2 (`7c210a3`). Now: "You never change code, commit or push. The only file you write is the change's Review Doc". No contradiction, typo gone.

**What's wrong.**

> ...builds its data. You never edit files,
> You never change code, commit or push. The only file you write is the
> change's Review Doc

The first clause forbids editing files outright, then the next sentence
allows writing one, and later rounds must *update* that doc (the agent is
granted `Edit` for it). There's also a stray comma and capital "You" mid
sentence, which reads like a leftover from an edit.

**Why it matters.** Contradictory absolute rules are where an agent picks
the wrong one: a cautious run refuses to write or update the Review Doc
(so `/build` ends with no doc for the PR, against the new `CLAUDE.md` rule);
the frontmatter description also says "Never edits code" while granting
`Write, Edit`, so the prose is the only guard and it should be exact.

**Evidence.** Lines read; frontmatter `tools: Read, Grep, Glob, Bash, WebFetch, Write, Edit` (line 4).

**Fix.** "You never change code or any file other than the change's Review
Doc, and you never commit or push. The only file you write or edit is the
Review Doc (see "Review Doc" below); Bash is for ..."

### R4 · Mixin methods like `Item:ContinueOnItemLoad` aren't in the `forever` lists
- **Severity:** nit
- **Area:** WoW API
- **Where:** `.claude/agents/reviewer.md:65-70` (and the Area notes table instruction)
- **Status:** fixed in round 2 (`7c210a3`). `reviewer.md:69-71`: mixin methods (`Item:Create...`, `Item:ContinueOnItemLoad`) and global tables aren't listed; accept them when standard FrameXML and say so as inferred.

**What's wrong.** The reviewer is told "Every game function, event, widget
method, template, atlas and `Enum` the diff uses is in the `forever` lists"
and, in the next bullet, recommends `Item:ContinueOnItemLoad`. That method
(and `Item:CreateFromItemID`, other `*Mixin` methods) appears in none of
the lists: `FrameXML.lua` lists global functions only.

**Why it matters.** A reviewer following the rule literally marks the
recommended async pattern "no" in its API table, or raises a false finding
the implementer then "fixes" by polling, the thing the doc wants to avoid.

**Evidence.** Downloaded `forever` `FrameXML.lua`, `GlobalAPI.lua`:
`grep -i 'ContinueOnItemLoad\|ItemMixin\|"Item"'` finds nothing
(only `EventUtil.ContinueOnAddOnLoaded` and similar).
`ITEM_DATA_LOAD_RESULT` and `GET_ITEM_INFO_RECEIVED` are in `Events.lua`.
The addon already uses the mixin in the smoke stand-in
(`tests/smoke/wow.lua:1477`).

**Fix.** Extend the global-tables sentence: "Global tables
(`RAID_CLASS_COLORS`, ...) and mixin objects (`Item`, `Spell`, their
`:Continue...` methods) are in none of the lists; accept them when the code
nil-guards them or the addon already uses them, and say the check was by
inference."

### R5 · "There is no combat log in the client" is inaccurate
- **Severity:** nit
- **Area:** Readability
- **Where:** `.claude/agents/implementer.md:49`
- **Status:** fixed in round 2 (`7c210a3`). Now: "Enemy spell IDs in combat events are secret, so boss abilities can't be read live (they come from `Data/Abilities.lua`)". Accurate: `NeedRoll/Data/Abilities.lua` exists and its header says it holds generated boss abilities, one spell ID each; matches `Core/Init.lua:102-103`.

**What's wrong.** The implementer is told "There is no combat log in the
client." The `forever` lists have `COMBAT_LOG_EVENT_UNFILTERED` (Events.lua
line 473) and a `C_CombatLog` namespace including
`C_CombatLog.IsCombatLogRestricted`; the repo's own wording is narrower:
"enemy spells can't be read in game; tools/combatlog collects them from
combat logs instead" (`NeedRoll/Core/Init.lua:102-103`), and
`tools/combatlog/README.md` says `/combatlog` still writes log files.

**Why it matters.** A flat "no combat log" can steer the implementer away
from an event that exists, or make it doubt `tools/combatlog` exists.
Stating the real limit is just as short.

**Evidence.** Lines read; grep of downloaded `forever` `Events.lua`/`GlobalAPI.lua`.

**Fix.** "Enemy spell IDs can't be read in game (they're secret);
`tools/combatlog` gets them from `/combatlog` files instead."

### R6 · Shared rules duplicated across both agents, already drifting
- **Severity:** nit
- **Area:** Redundant code
- **Where:** `.claude/agents/implementer.md:16,24,37`, `.claude/agents/reviewer.md:78,92`
- **Status:** paths fixed in round 2 (`7c210a3`): `NeedRoll/UI/Overview.lua`, `NeedRoll/UI/Theme.lua` and `scraper/quests/blacklist.txt` in both agents. Duplication left as is: each agent runs standalone without the other's file in context (implementer's reason). Accepted.

**What's wrong.** The Ketho URL list, the 60-upvalue note, secret values,
the locale rule, the Wowhead/QuestieDB rule, the names rule and the whole
checks list are written out twice. Some duplication is fine (each subagent
starts with only its own prompt and `CLAUDE.md`), but the copies already
differ:

- Paths: implementer says `NeedRoll/UI/Theme.lua` but `UI/Overview.lua`;
  reviewer says `UI/Theme.lua` and `UI/Overview.lua`. The files are
  `NeedRoll/UI/Theme.lua` and `NeedRoll/UI/Overview.lua`.
- `blacklist.txt` (implementer:24) is ambiguous: there are two,
  `scraper/quests/blacklist.txt` and `scraper/professions/blacklist.txt`.
- The `T:` helper lists differ (implementer names `T:Text`,
  `T:QualityColor`, `T:CardBackdrop`; reviewer doesn't). All named helpers
  exist (`grep '^function T:' NeedRoll/UI/Theme.lua`), so this is only
  drift, but both tell the agent to grep anyway.

**Why it matters.** The next rule change will land in one file and not the
other, and the two agents will disagree in review. Short relative paths
make agents glob for the file first.

**Evidence.** Lines read; `find . -name blacklist.txt`; Theme.lua grep.

**Fix.** Use full repo paths everywhere (`NeedRoll/UI/...`,
`scraper/quests/blacklist.txt`). Optionally keep one copy of the shared
rules and checks (e.g. a `docs/` page both agents are told to read) and
leave each agent only its role-specific instructions.

### R7 · Review Doc in its own scope; "until clean" vs three-round cap
- **Severity:** nit
- **Area:** Readability
- **Where:** `.claude/agents/reviewer.md:14-28,149`; `CLAUDE.md:14`; `.claude/commands/build.md:14`
- **Status:** fixed in round 2 (`7c210a3`). (a) `reviewer.md:22`: "Leave the Review Doc itself (`docs/reviews/`) out of the review." (see R8 for its wording). (b) `CLAUDE.md:14-15`: "(at most three rounds, then Mike decides what's left)", matching `build.md`.

**What's wrong.** (a) From round 2 on, `git diff origin/dev...HEAD` plus
uncommitted changes includes the reviewer's own `docs/reviews/<branch>.md`;
nothing tells it to leave that file out of Scope and findings. (b)
`CLAUDE.md` says the loop runs "until the review is clean", `build.md` stops
after three rounds and hands what's open to Mike.

**Why it matters.** (a) Small risk of the reviewer reviewing its own doc or
listing it as part of the change. (b) Two statements of the same rule that
don't match; `build.md` is the one that runs.

**Evidence.** Lines read.

**Fix.** (a) In "What to review": "Leave `docs/reviews/` out of the
review; it is your own output." (b) In `CLAUDE.md`: "looping until the
review is clean (at most three rounds; `/build <task>` runs the loop)."

### R8 · Skipping all of `docs/reviews/` also skips its `README.md`
- **Severity:** nit
- **Area:** Readability
- **Where:** `.claude/agents/reviewer.md:22`
- **Status:** fixed after round 2 (nit; reworded to "this change's own Review Doc (`docs/reviews/<branch>.md`)")

**What's wrong.** The R7 fix reads "Leave the Review Doc itself
(`docs/reviews/`) out of the review." The parenthesis names the whole
folder, which also holds `docs/reviews/README.md` (added in this PR) and
other PRs' Review Docs.

**Why it matters.** A change to the README, or a hand edit to another PR's
Review Doc, would go unreviewed. Small, since those files rarely change.

**Evidence.** `reviewer.md:22`; `docs/reviews/README.md` is in this diff.

**Fix.** "Leave this change's own Review Doc (`docs/reviews/<branch>.md`)
out of the review."

### R9 · Fix commit left ragged line wrapping
- **Severity:** nit
- **Area:** Readability
- **Where:** `.claude/agents/implementer.md:38-42`, `.claude/agents/reviewer.md:69-71`, `CLAUDE.md:14-16`
- **Status:** fixed after round 2 (nit; paragraphs rewrapped)

**What's wrong.** The edited lines weren't rewrapped: `implementer.md:38` is
81 characters and line 41 ends after "anything the"; `reviewer.md:71` is 89
characters ("when they are standard FrameXML and say so as inferred. Removed
globals (`GetItemInfo`,"); `CLAUDE.md:14-16` wraps at 80 then breaks after
"runs the". The rest of these files wrap at about 78.

**Why it matters.** Cosmetic only; the Markdown renders the same, but it
adds noise to the next diff that rewraps them.

**Evidence.** `awk 'length>80'` over the files (frontmatter and URL lines
excluded); lines read.

**Fix.** Rewrap those paragraphs to the files' ~78-column width.

## Area notes

Round 2: re-read the five changed files whole. The Review Doc section and
report format are clear; the implementer, `build.md` and `CLAUDE.md` agree
on who writes, edits and commits the doc. No new game calls (WoW API table
below unchanged). No new tool grants beyond round 1's `Write, Edit` for
the reviewer, now matched by the prose. No names or secrets added; the
Credits.txt rule now matches the scraper (R1). Redundancy between the
agents is accepted per R6.

### Readability

Read all six files whole. Frontmatter is valid for Claude Code
(`name`, `description`, `tools`, `model: inherit` on agents;
`description`, `argument-hint` and `$ARGUMENTS` on the command). The
reviewer's Review Doc layout is complete and unambiguous apart from R7;
the report format is short and points at the doc. `build.md` steps are
clear and the round cap prevents endless loops. Wording is plain and
consistent with `CLAUDE.md`'s voice. Factual claims checked and correct:
Interface 16001 (`NeedRoll.toc:1`), `ketho.wow-api` in
`.vscode/extensions.json`, `.luarc.json` key `diagnostics.globals`,
`CreateOverview` at the upvalue limit (`NeedRoll/UI/Overview.lua:3237`
comment), `--@debug@` blocks in use (`Overview.lua:794`), `.pkgmeta`
`ignore:` list, channel `NeedRollDropSharing` (`Core/Drops.lua:337`),
one-a-minute outbox (`SEND_GAP = 60`, `Drops.lua:60`) and daily cap
(`DAILY_MAX = 100`, `Drops.lua:469`), "Share drops" off sends nothing
(`Drops.lua:340`), `ns:On` / `ns:Print` (`Core/Init.lua:87,222`),
`ns.Items` (`Core/Items.lua:5`), `ns.LootLog` (`Core/LootLog.lua:34`),
`issecretvalue` guards (7 uses), secret tooltip widths
(`Core/Tooltip.lua:222`), `new-instances/*.txt` at the repo root,
`scraper/quests/forever.json`, `docs/LOCALIZATION.md`,
`docs/STYLE-GUIDE.md`.

### WoW API

No Lua changed, so no new calls. The names the agent prompts tell agents
to use or expect were checked against the downloaded `forever` lists:

| Name | In `forever` lists | Where looked |
| --- | --- | --- |
| `C_Item.GetItemInfo` | yes | `GlobalAPI.lua:2522` |
| `C_AddOns.GetAddOnMetadata` | yes | `GlobalAPI.lua:205` |
| `C_ChatInfo.*` | yes (45 entries) | `GlobalAPI.lua` |
| `GetItemInfo`, `GetAddOnMetadata`, `GetSpellInfo` (globals) | no, as the prompts say | `GlobalAPI.lua` |
| `issecretvalue` | yes | `GlobalAPI.lua` |
| `InCombatLockdown` | yes | `GlobalAPI.lua` |
| `ITEM_DATA_LOAD_RESULT`, `GET_ITEM_INFO_RECEIVED`, `CHAT_MSG_ADDON` | yes | `Events.lua` |
| `Item:ContinueOnItemLoad` | no (mixin; see R4) | `FrameXML.lua`, `GlobalAPI.lua` |
| `ITEM_CLASSES_ALLOWED` | yes | `GlobalStrings/enUS.lua` |
| `COMBAT_LOG_EVENT_UNFILTERED` | yes (see R5) | `Events.lua:473` |

URLs: `GlobalAPI.lua`, `Events.lua`, `WidgetAPI.lua`, `LuaEnum.lua`,
`FrameXML.lua`, `Templates.lua`, `AtlasInfo.lua`, `GlobalStrings/enUS.lua`
under `Ketho/BlizzardInterfaceResources/forever/Resources/` all return 200.
`github.com/Ketho/vscode-wow-api` pages return 403 through this session's
proxy, but `raw.githubusercontent.com/Ketho/vscode-wow-api/master/Annotations/...`
returns 200, so the folder exists. `warcraft.wiki.gg` was unreachable here
(not verified).

### Redundant code

Compared the two agents against each other and against `CLAUDE.md`
(see R6, R7). The `CLAUDE.md` bullet only points at the agents and adds the
Review Doc rule, so it doesn't restate their contents. The checks list in
both agents matches what CI runs (`.github/workflows/lua-check.yml`:
`luac5.1 -p`, `tools/locales.py --check`, `tools/translations.py`;
`smoke-tests.yml`: `tests/smoke/check.sh`; `loot-data-check.yml`:
`python -m unittest discover -s tests` in `scraper/`). `tools/locales.py`
does take `--check` (`locales.py:50`); `tests/smoke/check.sh` exists, is
executable and needs `lua5.1`. Helpers named exist: `T:Pill`, `T:Row`,
`T:Label`, `T:Text`, `T:ScaledFont`, `T:ScrollView`, `T:Dialog`,
`T:SetTextColor`, `T:QualityColor`, `T:CardBackdrop` in
`NeedRoll/UI/Theme.lua`.

### Security

Untrusted inputs touched: none at runtime (no addon or scraper code).
For the tooling itself:

- Tool grants: the reviewer gets `Write, Edit` for its doc and `Bash`; the
  only guard against code edits is the prose (hence R3). The implementer's
  `Bash, WebFetch, Write, Edit` fit its job. Both are told not to commit or
  push unless asked. `WebFetch` is pointed only at Ketho and the wiki.
- Secrets: none in the files; `.claude/settings.local.json` (personal
  permissions, can hold tokens in env settings) is now ignored.
- Names: the diff names only Mike, as `CLAUDE.md` already does. Review
  Docs are committed in this private repo; the `CLAUDE.md` rule to check
  public copies for names covers them too, as long as reviewers don't
  quote character names from SavedVariables or `scraper/drops/` in a doc
  (inferred risk, not a finding). R1 corrects the one wrong statement about
  where names may appear. `.claude/` is a dot folder, which the BigWigs
  packager leaves out of release zips by default (inferred, not tested);
  `docs/reviews/` is packaged the same way as the existing `docs/` folder.

## Round history

- 2026-10-17, `aa1f139`, round 1: **Changes needed**. Opened R1-R7
  (3 should fix, 4 nits); none closed. This round covered the whole tooling
  in PR #592 (agents, `/build`, `CLAUDE.md`, `.gitignore`), which has since
  merged, plus the Review Doc commit now in the follow-up PR.
- 2026-10-17, `7c210a3`, round 2 (follow-up PR, after rebase on
  `origin/dev`): **Ready**. Closed R1, R2, R3, R4, R5, R7 (fixed in
  `7c210a3`); R6 paths fixed, duplication left as is with the implementer's
  reason. Opened R8, R9 (nits).
- 2026-10-17, after round 2: the implementer fixed nits R8 and R9 with no
  new review round.
