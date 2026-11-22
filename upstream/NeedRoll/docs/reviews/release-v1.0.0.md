# Review: NeedRoll v1.0.0 (everything since v0.16.2)

| | |
| --- | --- |
| Branch | `v0.16.2..origin/dev` (PRs #758, #759, #760, #761 and #762), plus the round 1 fixes on `claude/project-thread-m8mlfr` (`b917b7a..fcf2ec6`), into `dev` |
| Commit reviewed | Round 1: `b917b7a`. Round 2: `fcf2ec6` (fixes `1d1bec1`, `f7c4859`, `e55b67f`, `a5ff1eb`, `fcf2ec6`); the whole `v0.16.2..fcf2ec6` range re-read. No uncommitted changes besides this doc. |
| Date | 2026-11-04 |
| Round | 2 |
| Verdict | **Changes needed** at round 2 (0 blocking, 1 should fix, 2 nits); after the two-round limit R11 and R12 were fixed (`a65b3b8`, `a004ca2`) and R10 is handled by option (b), without a third review round |
| Needs | Full client restart, not just `/reload`: the TOC gains `Core\Trainers.lua` and `Data\Camping.lua`, and the game reads new TOC entries only at startup. |

## What the change does

**Camping (#758, #759).** The Professions tab gains a Camping list, the last of the profession lists. It has no recipes, only an Overview page. That page lists every camp feature (Basic Campfire Kit, Lodestone, Rock Garden...) under the rank its skill falls in, Apprentice to Artisan. Features of the character's own professions come first and are lit. Each section opens and shuts from its heading. Each profession's own Overview now starts with a Camping section showing the features it builds, lowest skill first. Each row shows:
- the item (a link with its tooltip) and what it does at the character's level;
- a feature placed over another adds that one's effect too;
- where the recipe comes from: trainers, or the blueprint (an item link) and the bosses that drop it (links that open their loot);
- at the right, the skill, a link that opens the recipe in its own profession's list.

The facts come from the hand-written `Data/Camping.lua`, and the effects are `L["..."]` phrases. The Quests section's fold became a general `page.shutSections`, so any heading can open and shut its section.

**Install paths (#760).** The docs and the combat log watcher's defaults point at `_forever_` instead of `_classic_beta_`.

**Roll call (#761).** A dev build on a PROBERS character can type `/nr users`. It sends `U1:<random>` to the hidden realm channel. Every copy that hears it from a PROBERS character answers once through the outbox with `U1:<random>:<version>`, at most once every 30 minutes. The dev build counts answers once per player (hashed keys, session only) and keeps only counts and versions in `NeedRollDB.rollCalls`. `/nr users history` prints them. Asking ships only in dev builds (`--@debug@`). Answering ships in every build.

**Class trainers (#762).**
- `scraper/classes/changes.json` applies Blizzard's November 2 class notes by hand: Righteous Fury moves to level 10 with no price, and four paladin blessings are left out.
- The new `Core/Trainers.lua` reads the player's own class trainer on `TRAINER_SHOW` / `TRAINER_UPDATE`. It turns the window's filters on for the read and puts them back after. Ranks whose level or cost differ from `Data/ClassSpells.lua`, or that it doesn't list, are saved in `NeedRollDB.trainerSpells`.
- Those ranks are shared as `T1` messages on the realm channel (at most three a day, behind drops and quests). Copies that hear one save its ranks too, marked `heard = true` since round 2.
- `ns.Data:ClassSpells` now hands out a live copy, with the player's own trainer reads over the shipped levels and costs (round 1: every saved rank, heard ones too). The Abilities page shows them at once.
- The scraper's `ingest` folds `trainerSpells` into `scraper/classes/seen.json`, and `trainers` builds that into `Data/ClassSpells.lua`. Since round 2 only the watcher accounts' own reads apply; heard ranks are listed in the report. The Watcher data workflow runs `trainers` when `seen.json` changed.

**Round 2 fixes.** Heard `T1` builds newer than the client's and costs over 1000 gold are refused, and saved ranks with a newer build are forgotten at login. Heard ranks no longer show in game, and a live rank 1 that a trainer teaches drops `first`. The scraper caps build and cost, applies only reads and reports every level or cost change. The roll call comment and Share drops' text say what is sent. `tools/translations.py` reads "% " as plain text, so the Camping "+8% to all stats" phrases pass. The nits are fixed too.

## Scope

31 changed files. Every hunk was read with the code around it, and the new files in full.

Addon:
- `NeedRoll/Core/Trainers.lua` (new, 328 lines, read in full): trainer read, saved ranks, live copies, sharing, heard ranks.
- `NeedRoll/Core/Drops.lua`: `T1` encode/decode, `TRAINER_LIMITS`, the outbox's trainer ordering and daily count, `FORMATS.T`, `SenderVersion` for `T1`, and the roll call: `AnswerRollCall` (shipped), plus `CountRollCallAnswer`, `RollCall`, `SendRollCall`, `PrintRollCalls` and the `Drops.Heard` branch (all inside `--@debug@`, lines 1864-2444).
- `NeedRoll/Core/Init.lua`: `trainerSpells = {}` default, and `/nr users` (inside the `--@debug@` block 616-692).
- `NeedRoll/Core/Names.lua`: the "Camping" label.
- `NeedRoll/Data/Data.lua`: `RegisterCamping` / `CampFeatures`, `ClassSpells` through `Trainers.Live`, and the new `ShippedClassSpells`.
- `NeedRoll/Data/Camping.lua` (new, hand-written per #758, read in full as code).
- `NeedRoll/UI/ProfessionOverview.lua`: Camping section and page, fold headings, drop links, `ShowToggle`.
- `NeedRoll/UI/Lists.lua`: the Camping icon.
- `NeedRoll/UI/ClassSpells.lua`: a comment.
- `NeedRoll/UI/DropTalk.lua`: `T1` rows in the dev window.
- `NeedRoll/NeedRoll.toc`: two new files.
- `NeedRoll/Locales/enUS.lua`: 37 new phrases.

Generated: `NeedRoll/Data/ClassSpells.lua` was not reviewed for style. Its diff (Righteous Fury, four blessings and the source line) was checked against `changes.json` and the generator.

Scraper, workflows, tools and docs:
- `scraper/needroll_scraper/classspells.py` (changes, seen, merge, apply, reports), `__main__.py`, `scraper/classes/changes.json`, `seen.json`, `scraper/README.md` and `scraper/tests/test_classspells.py`.
- `.github/workflows/watcher-data.yml`: download cache, the `trainers` step, and players' files kept out of the cache.
- `tools/combatlog/*` and `docs/NEW-COMPUTER.md` (#760). `git grep classic_beta` on `origin/dev` finds nothing left.
- `docs/STYLE-GUIDE.md`: the Camping rows and page.

Tests: `tests/smoke/wow.lua` (trainer stand-in, `Enum.TrainerType`, `C_TooltipInfo.GetTrainerService`), plus `Core-Trainers.lua` (new), `Core-Drops.lua`, `UI-Classes.lua`, `UI-ClassOverview.lua` and `UI-ProfessionOverview.lua`.

Round 2 (`b917b7a..fcf2ec6`, 18 files), re-read in full with every function the range changed:
- `Core/Trainers.lua` (`SaveRead`, `OwnRead`, `ApplySaved`, `Refresh`, `SaveHeardRank`, `SaveHeard`, `ForgetMadeUpBuilds`, login), `Core/Drops.lua` (`TRAINER_LIMITS`, `DecodeTrainerRank`, `DecodeTrainerRanks`, the roll call comment, `rollCallAnsweredAt`), and `Data/Data.lua`, `UI/ClassSpells.lua`, `UI/ProfessionOverview.lua`, `UI/Settings.lua`, `UI/Welcome.lua`, `Locales/enUS.lua`.
- `scraper/needroll_scraper/classspells.py` (`NumberedRank`, `COST_MAX`, `BUILD_MAX`, `_seen_entry`, `_report_priority`, `_merge_seen_entry`, `_add_seen_ranks`, `_own_reads`, `_level_and_cost`, `_set_seen_rank`, `_apply_seen`, `_report_heard`, `build`), `seen.json`, `scraper/README.md`, the tests, `watcher-data.yml`, `tools/combatlog/README.md`.
- `tools/translations.py` (`FORMAT`).
- Smoke: `Core-Trainers.lua` (two new scenarios), `UI-Classes.lua`, `UI-ProfessionOverview.lua`.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the changed Lua files | Round 1 (18 files): passed. Round 2 (20 files, adding `UI/Settings.lua` and `UI/Welcome.lua`): passed |
| `luacheck --no-global -q`, base `v0.16.2` vs now | Round 1: no new warnings except `Core/Drops.lua` 21 → 24 (three more `unused argument 'self'` on the new `Drops:` methods, the file's existing pattern) and `UI-ProfessionOverview.lua` 0 → 1 (R8). Round 2: `UI-ProfessionOverview.lua` back to 0 (R8 fixed). `UI/Settings.lua` 8 → 8 and `UI/Welcome.lua` 3 → 3: their long lines are the literal `L["..."]` keys, already over 120 before. Every other file is as in round 1, and `Core/Trainers.lua` still has 0. |
| `python3 tools/locales.py --check` | Round 1 and round 2: passed |
| `python3 tools/translations.py` | Round 1: passed, nothing to report. Round 2: exit 0, but it lists 20 entries "not used by NeedRoll any more": all 10 languages' translations of the two renamed sentences (R10) |
| `tests/smoke/check.sh` (all four: dev, packaged, secret, combat) | Round 1: passed (558 scenarios in the dev run). Round 2: passed, "all passed" in each run (560 in the dev run) |
| `cd scraper && python3 -m unittest discover -s tests` | Round 1: passed, 327 tests. Round 2: passed, 332 tests |
| Ketho's `forever` lists | GlobalAPI, Events, WidgetAPI, LuaEnum, FrameXML, Templates, AtlasInfo and GlobalStrings/enUS downloaded to `/tmp/claude-0/ketho/` and grepped (table under WoW API) |
| Names in public places | The names in `scraper/drops/credits.json` and `observed.json` (`by`) were grepped across the whole diff, and across `NeedRoll/`, `tests/`, `docs/`, `.github/` and `tools/` on `origin/dev`: none found |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | blocking | Security | `Core/Trainers.lua:261-289, 190-199`, `Core/Drops.lua:1525-1544` | One heard `T1` message changes the Abilities page for every copy on the realm, and its made-up build locks corrections out | fixed in round 2 (`f7c4859`) |
| R2 | should fix | Security | `scraper/needroll_scraper/classspells.py` (`_seen_entry`, `_merge_seen_entry`, `_apply_seen`), `watcher-data.yml` | Ranks heard from any player reach `seen.json` and the shipped `Data/ClassSpells.lua` on one report, with the highest build winning | fixed in round 2 (`e55b67f`) |
| R3 | nit | Security | `Core/Drops.lua:1732-1744`, `UI/Settings.lua:83` | The roll call comment says answers carry "no name", and Share drops' tip doesn't say what else it now sends | fixed in round 2 (`a5ff1eb`) |
| R4 | nit | WoW API | `Core/Trainers.lua:189-199` | A live rank 1 given a level keeps `first = "talent"/"quest"`, which the scraper clears | fixed in round 2 (`f7c4859`) |
| R5 | nit | Readability | `Data/Data.lua:889-895` | A badly wrapped comment over `RegisterCamping` | fixed in round 2 (`fcf2ec6`) |
| R6 | nit | Redundant code | `UI/ProfessionOverview.lua:598-604, 963, 1048, 1087` | `AddFoldHeading` returns the heading, and no caller uses it | fixed in round 2 (`fcf2ec6`) |
| R7 | nit | Readability | `Core/Drops.lua:1747` vs `1659` | Two ways to say "never answered": `rollCallAnsweredAt = -ROLL_CALL_GAP` and `answeredAt = 0` | fixed in round 2 (`fcf2ec6`) |
| R8 | nit | Readability | `tests/smoke/modules/UI-ProfessionOverview.lua:828` | A new 123-character line (new luacheck warning) | fixed in round 2 (`fcf2ec6`) |
| R9 | nit | Readability | `scraper/needroll_scraper/classspells.py` (`_add_seen_ranks`, `_merge_seen_entry`) | Positional tuples with an unnamed 0/1 tiebreak and `n`; a comparison wrapped mid-tuple | fixed in round 2 (`e55b67f`) |
| R10 | should fix | WoW API | `Locales/enUS.lua:1120, 1241`, `UI/Settings.lua:83`, `UI/Welcome.lua:189` | (round 2) Rewording two sentences drops every translation of the drop sharing consent notice and Share drops' tip | handled by (b): drafts in all 10 languages, Translations PR before the tag |
| R11 | nit | Security | `Locales/enUS.lua:1241`, `UI/Welcome.lua:189` | (round 2) The consent notice doesn't mention the version answers the tip and `a5ff1eb`'s message name | fixed after round 2 (`a65b3b8`) |
| R12 | nit | Redundant code | `Core/Trainers.lua:161-172` | (round 2) A read that agrees with a heard rank sends it to the channel again | fixed after round 2 (`a004ca2`) |

### R1 · One heard `T1` message changes the Abilities page for every copy on the realm, and its made-up build locks corrections out
- **Severity:** blocking
- **Area:** Security (untrusted input)
- **Where:**
  - `NeedRoll/Core/Drops.lua:1525-1544` (`DecodeTrainerRanks`: build and cost checked only as digits ≤ 2^31-1)
  - `NeedRoll/Core/Trainers.lua:261-273` (`SaveHeardRank`), `279-289` (`SaveHeard` → `Refresh`)
  - `NeedRoll/Core/Trainers.lua:189-199` (`ApplySaved` puts every saved rank, heard or read, over the shipped one)
- **Status:** fixed in round 2 (`f7c4859`). Fix (a) as proposed: `DecodeTrainerRanks` reads the build as `HeardNumber(fields[3], clientBuild)` (`Drops.lua:1531-1537`, `clientBuild` is the file local from line 809), and `TRAINER_LIMITS.cost = 10000000` caps the cost. For (b) the implementer took option 1. Heard ranks are saved with `heard = true` (`SaveHeardRank`). `ApplySaved` overlays only `OwnRead(...)` ranks, and `SaveHeard` no longer refreshes the live copy. A heard rank never replaces the player's read (`if OwnRead(kept) then return false end`), the player's read replaces a heard rank whatever its build (`SaveRead`), and `ForgetMadeUpBuilds` drops saved ranks newer than the client's at login. New smoke scenario `Core/Trainers: heard ranks don't change the live data; a made-up build or price is refused` covers each case, and `UI-Classes.lua:2381` checks that a heard rank 4 doesn't show. All four smoke runs pass. One leftover is R12.

**What's wrong.** Any player can join `NeedRollDropSharing` and send addon messages on it. A `T1` message is accepted when its class token is one NeedRoll ships, and each field is plain digits, with level ≤ 100. The build, cost and NPC may be any number up to 2147483647. Every rank that differs from the shipped data is saved in `NeedRollDB.trainerSpells` and marked shared. `Trainers.Refresh` then puts it on the live copy that `ns.Data:ClassSpells` hands the Abilities page and the class Overview.

Three parts of the code make this persistent:

```lua
-- Trainers.lua:268, SaveHeardRank
if kept and (kept.build or 0) > heard.build then return false end
```
A rank heard with build 2147483647 refuses every later heard correction, because honest copies send the real build.

```lua
-- Trainers.lua:157-159, SaveRead
if MatchesShipped(classToken, service.spellID, service.level, service.cost) then
    saved[service.spellID] = nil
```
Only the player's own trainer read clears a saved rank, and only for their own class. A heard rank that matches the shipped data is skipped (`SaveHeard`, line 282) and doesn't clear one. Copies whose read matches the shipped data send nothing at all. So for a spell where Forever and NeedRoll agree, no copy will ever send the true value.

**Why it matters.** This is the first data heard from other players that changes what every player sees in the normal UI. Heard drops show only in the dev `/nr droptalk` window. Suppose a griefer sends one message: `T1:MAGE:2147483647:0:10151.60.999999999,...\t\tv1.0.0`. Within seconds, every NeedRoll copy on the realm channel saves it. For a mage, that Fireball rank then shows "Level 60 · 99999g" on the Abilities page and the class Overview's costs. For every class but the player's own, that stays until they delete their SavedVariables. Nothing the honest copies send can replace it.

The drop sharing design already guards against this kind of attack in one place: `NEWER_SENDERS = 3`, "so one player sending made-up messages can't silence everyone" (`Drops.lua:662-667`). Trainer ranks have no equivalent. This is the 1.0 launch, the release with the most players on the channel.

**Evidence.**
- I read `DecodeTrainerRanks`, `HeardNumber` (`Init.lua:278-284`, max `HEARD_NUMBER_MAX = 2147483647`), `SaveHeardRank`, `SaveHeard`, `ApplySaved` and `SaveRead`.
- `tests/smoke/modules/UI-Classes.lua:2381` ("a level and cost read at a trainer show in place of the shipped ones") shows the live copy reaching the page.
- `Core-Trainers.lua:233-296` covers malformed messages, but not a well-formed hostile one.
- Heard drops showing only in the dev window: `grep ns.db.drops NeedRoll/UI` finds only `UI/DropTalk.lua`.

**Fix.** Two parts.
- **(a) Required, a few lines in `Drops.DecodeTrainerRanks`.** Refuse a heard build newer than the client's own. Every copy on a realm runs the same build, so a newer one is a lie, or a patch this client doesn't have yet. Also give cost a ceiling in `TRAINER_LIMITS`, as level has.
  ```lua
  local TRAINER_LIMITS = { daily = 3, level = 100, name = 30,
      cost = 10000000 }  -- copper (1000g), far over any trainer's price
  ...
  cost = HeardNumber(cost, TRAINER_LIMITS.cost)
  ...
  if not (isKnownClass and decoded.build and decoded.build <= clientBuild and decoded.npc) then return nil end
  ```
- **(b) Mike's call:** stop one sender from changing what everyone sees. Options, simplest first:
  1. Mark heard ranks `heard = true`, and have `ApplySaved` overlay only the player's own reads. Heard ranks still reach Mike's ingest, and players get them with the next data release. Your own class's trainer is the one you visit, so most of the in-game benefit stays.
  2. Overlay a heard rank only once two different senders have sent the same level and cost. Keep a count, with this session's senders as hashed keys (`Drops:ProberKey`) as the roll call does, and no names saved.

  With either option, add a smoke scenario: a well-formed `T1` from one sender with a huge build doesn't change `LiveRank`.

### R2 · Ranks heard from any player reach `seen.json` and the shipped `Data/ClassSpells.lua` on one report, with the highest build winning
- **Severity:** should fix
- **Area:** Security (untrusted input into shipped data)
- **Where:**
  - `scraper/needroll_scraper/classspells.py`: `_seen_entry` (`build`, `cost` and `npc` unbounded), `_merge_seen_entry` (newest `(build, at)` wins), `_apply_seen` (one entry sets a listed rank, or adds a spell by name)
  - `.github/workflows/watcher-data.yml` (`trainers` step)
- **Status:** fixed in round 2 (`e55b67f`). `_seen_entry` refuses a build over `BUILD_MAX = 999_999` and a cost over `COST_MAX = 10_000_000`, and keeps `heard`. `_report_priority` keeps a read over a heard report, then the newer build and time, and never takes a heard name into a read. `build` applies only `_own_reads`. `_report_heard` lists heard ranks by ID, level and cost (not their sender-written name, and `_report_new_trainers` takes NPCs from reads only). `_set_seen_rank` reports every level or cost change. Mike chose a constant `BUILD_MAX` over the highest ingested build. That's enough now that heard reports never apply: a made-up build up to 999999 can only reorder heard entries, which are only listed. Tests: `test_heard_ranks_are_listed_not_applied`, `test_every_change_to_a_listed_rank_is_reported`, `test_a_read_wins_over_a_heard_report_and_keeps_its_own_name`, `test_a_made_up_build_or_price_is_refused`. 332 scraper tests pass.

**What's wrong.** `trainerSpells` in a SavedVariables file mixes the player's own reads with ranks heard from anyone on the channel. Nothing tells the two apart: heard ones are only `shared = true`, and so are sent ones. `merge_seen` folds all of them into `seen.json`, keeping the entry with the highest `(build, at)`. `_apply_seen` then:
- sets a listed rank's level and cost from it, with no line in the report (only added ranks and new spells are reported);
- adds a spell NeedRoll doesn't list, under whatever English name the message gave, or adds ranks to a listed spell of that name;
- reports, with its ID, every NPC "seen teaching the class".

**Why it matters.** The R1 message also lands in Mike's SavedVariables. The watcher uploads them, and the next Watcher data PR rewrites `Data/ClassSpells.lua` with it. In the PR body the level or cost changes show only as "Changed: ClassSpells.lua". A build of 2147483647 also means no later true report, not even from Mike's own trainer reads, can replace it in `seen.json`. The drop ingest guards against single reports: an unknown item joins a boss list only "once seen on two kills" (`observed.py` docstring). Trainer data has no such rule.

**Evidence.** Read the `classspells.py` diff and `merge_seen`. `test_the_newest_build_and_time_wins_keeping_the_name` confirms the newest-wins rule. The `watcher-data.yml` step runs `trainers` whenever `seen.json` changed.

**Fix.**
- Carry the R1 `heard = true` mark into `seen.json`.
- In `_seen_entry`, cap `build` (at the highest build of the files being ingested, or a constant updated with the client) and `cost`.
- Have `_apply_seen` apply only entries read by the watcher's own accounts (no `heard`). List heard-only entries in the report for Mike to confirm by hand, or apply them only once two reports agree.
- Report every level and cost change to a listed rank, not only additions, so the PR body shows what changed.

### R10 · (round 2) Rewording two sentences drops every translation of the drop sharing consent notice and Share drops' tip
- **Severity:** should fix
- **Area:** WoW API (player-facing text through `L["..."]`)
- **Where:** `NeedRoll/Locales/enUS.lua:1120` (Share drops' tip, `UI/Settings.lua:83`) and `1241` (the first-login notice "NeedRoll DropTalk System Consent", `UI/Welcome.lua:189`), changed in `a5ff1eb`
- **Status:** handled by (b) after round 2: the release thread drafted both new sentences in all 10 languages in NeedRoll-Locales, and v1.0.0 is tagged only after the Translations PR brings them into dev and main. Mike can still pick (a).

**What's wrong.** `a5ff1eb` widened the two sentences R3 asked about by editing their English text, which is also their `L["..."]` key. Every language file (deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW) still has translations under the old keys. `python3 tools/translations.py` now lists all 20 as "not used by NeedRoll any more", and the new keys have no translation in any language. R3 itself had warned that "the new `L["..."]` key then needs translating", but it didn't say this cost.

**Why it matters.** The notice is the drop sharing consent shown at first login. At the 1.0 launch, every German, French, Spanish, Russian, Korean or Chinese player would read it, and the Settings tip, in English. Before this, both were in their own language. Translations only come back through translators' pull requests to the public NeedRoll-Locales repo and the daily Translations PR (`.github/workflows/translations.yml`), so nothing guarantees they land before the tag. `docs/READABLE-CODE.md` ("Behaviour stays the same") lists `L["..."]` keys among what must not change, because renaming one breaks every translation of it.

**Evidence.** `translations.py` output (Checks). `git diff b917b7a fcf2ec6 -- NeedRoll/Locales/enUS.lua NeedRoll/UI/Settings.lua NeedRoll/UI/Welcome.lua`.

**Fix.** One of these (Mike's call):
- (a) Put the old sentences back as they were, so their translations stay, and add the new facts as a short sentence of their own after each. For the notice, something like `L["It also shares new quests and what class trainers teach, and answers which NeedRoll version you run."]`; for the tip, the same idea. Only the new sentence then shows in English until it's translated.
- (b) Keep the new sentences, and tag v1.0.0 only after the Translations PR has brought them in for every language.

### R3 · The roll call comment says answers carry "no name", and Share drops' tip doesn't say what else it now sends
- **Severity:** nit
- **Area:** Security (what players are told); Readability (avoid disinformation)
- **Where:** `NeedRoll/Core/Drops.lua:1732-1744`, `NeedRoll/UI/Settings.lua:83` (`tip`), `Locales/enUS.lua:1241` (first-login notice)
- **Status:** fixed in round 2 (`a5ff1eb`). The comment now says the text carries no name, but the game shows every listener the sender's character. The Share drops tip names drops, new quests, what class trainers teach and the NeedRoll version. The notice's rewording is R10 and R11.

**What's wrong.** The comment reads "Every copy that hears it answers with its version alone, no name: U1:<random>:<version>". The message text has no name, but the game delivers every addon message with the sender's character name. Anyone listening on the channel sees which characters answered, including players who chose "Credit my finds: Off". Mike's dev build hashes the name and keeps it for the session only. Any other listener's addon can keep it.

Also, Share drops' tip still says NeedRoll tells other players "which items bosses drop". This release adds two more things it sends: class trainer ranks (`T1`) and roll call answers. Each answer tells the channel "this character runs NeedRoll vX".

**Why it matters.** A newcomer reading the comment would think the answer is anonymous on the channel. Players aren't told that Share drops now also answers presence checks. The channel's roster already shows who is in it (inferred: `/chatlist` on a custom channel), so this exposes little that is new. Still, the code and the text should say so.

**Fix.**
- Reword the comment: "answers with its version (the text carries no name; the game shows every listener the sender's character, as for any message on the channel)".
- Consider widening the Settings tip and the notice to "which items bosses drop, new quests and what class trainers teach". The new `L["..."]` key then needs translating.

### R4 · A live rank 1 given a level keeps `first = "talent"/"quest"`, which the scraper clears
- **Severity:** nit
- **Area:** WoW API (game data shown consistently)
- **Where:** `NeedRoll/Core/Trainers.lua:189-199` (`ApplySaved`), compared with `classspells.py` `_apply_seen` (`if index == 0: spell.first = None`) and `_add_seen_ranks`
- **Status:** fixed in round 2 (`f7c4859`). `ApplySaved` sets `spell.first = shippedSpell.first`, then `nil` when the player's read gives rank 1 a level, so a refresh without the read puts the shipped `first` back. The smoke scenario `a rank 1 from a quest that the trainer teaches is a trainer's on the live data` (Redemption) checks both ways.

**What's wrong.** The scraper treats a rank 1 "from a quest or talent" that a trainer was seen teaching as trained, and drops `first` (`test_a_rank_1_from_a_talent_seen_at_a_trainer_is_trained`). The live copy sets `rank[2]` and `rank[3]` on that rank but keeps `spell.first`. `UI/ClassSpells.lua:374` then shows another class's spell as "Rank 1 from a talent · Levels 24 to 60". `Progress` (line 237) treats rank 1 as trainable.

**Fix.** In `ApplySaved`, set `spell.first = nil` when the first rank gets a saved level, and back to the shipped `first` otherwise. `CopySpells` already copies the field.

### R5 · A badly wrapped comment over `RegisterCamping`
- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/Data/Data.lua:889-895`
- **Status:** fixed in round 2 (`fcf2ec6`). The paragraph is rewrapped.

**What's wrong.**
```lua
-- Camp features (Data/Camping.lua): { features = { { item, allianceItem,
-- name, profession, skill, effect, scale, adds, blueprint, blueprintName },
-- ... } } (the file's comments give each
-- field). They become the Camping list, ...
```
Line 891 stops at 41 characters and puts "field)." on the next line. v0.16.0's R4 was the same kind of slip.

**Fix.** Rewrap the paragraph to the file's usual width.

### R6 · `AddFoldHeading` returns the heading, and no caller uses it
- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/ProfessionOverview.lua:598-604` (`return heading, heading.isOpen`). All three callers (963, 1048, 1087) write `local _, isOpen = AddFoldHeading(...)`.
- **Status:** fixed in round 2 (`fcf2ec6`). `AddFoldHeading` returns `heading.isOpen`, its comment says so, and the three callers read `if not AddFoldHeading(...) then return end`. The longest of them (`AddCampRankRows`) is under 120 characters.

**Fix.** Return `isOpen` alone, and call it as `if not AddFoldHeading(...) then return end`. Change the comment ("Returns whether the section is open") to match.

### R7 · Two ways to say "never answered": `rollCallAnsweredAt = -ROLL_CALL_GAP` and `answeredAt = 0`
- **Severity:** nit
- **Area:** Readability (one way of doing each thing)
- **Where:** `NeedRoll/Core/Drops.lua:1747` (`local rollCallAnsweredAt = -ROLL_CALL_GAP`) and `1659` (`local answeredAt = 0`, the probe's)
- **Status:** fixed in round 2 (`fcf2ec6`). `local rollCallAnsweredAt = 0`.

**What's wrong.** Both hold the `time()` of the last answer, and both only need to be far enough in the past. `time()` is seconds since 1970, so `0` already is. A reader comparing the two looks for a reason the roll call needs the negative start, and there is none.

**Fix.** `local rollCallAnsweredAt = 0`, as the probe's.

### R8 · A new 123-character line
- **Severity:** nit
- **Area:** Readability (formatting)
- **Where:** `tests/smoke/modules/UI-ProfessionOverview.lua:828`
- **Status:** fixed in round 2 (`fcf2ec6`). The message is on its own line, and luacheck is back to 0 for the file.

**What's wrong.** `assert(gardenSub:find("Relic Guardian, ", 1, true), "the Rock Garden's bluepr...` is 123 characters. luacheck reports a warning the base didn't have ("line is too long (123 > 120)"), and `docs/READABLE-CODE.md` §2 caps new lines at 120.

**Fix.** Put the message on its own line.

### R9 · Positional tuples with an unnamed 0/1 tiebreak and `n`; a comparison wrapped mid-tuple
- **Severity:** nit
- **Area:** Readability (scraper)
- **Where:** `scraper/needroll_scraper/classspells.py`, `_add_seen_ranks` and `_merge_seen_entry`
- **Status:** fixed in round 2 (`e55b67f`). `NumberedRank` (`number`, `order`, `is_seen`, `rank`) with `SEEN_FIRST, LISTED_AFTER = 0, 1` replaces the tuples, and `_report_priority` replaces the wrapped comparison.

**What's wrong.**
```python
numbered = [(seen.get(rank.spell, {}).get("rank", index + 1), 1, rank.spell in seen, rank) ...]
...
if any(n == number and is_seen for n, _, is_seen, _ in numbered):
...
numbered.append((number, 0, True, _seen_rank(spell_id, entry)))
spell.ranks = [rank for *_, rank in sorted(numbered, key=lambda item: (item[0], item[1]))]
```
The second field (1 for a listed rank, 0 for a seen one) is what puts a seen rank in front of a listed rank with the same number. Nothing names it, and the reader has to work that out from the docstring. In `_merge_seen_entry`, the `(build, at)` comparison is split across two lines in the middle of a tuple.

**Fix.**
- Name the tiebreak, for example `SEEN_FIRST, LISTED_AFTER = 0, 1`, or use a small `NamedTuple("Numbered", "number order is_seen rank")`, and spell out `n` as `listed_number`.
- Add `def _report_age(entry): return entry.get("build", 0), entry.get("at", 0)` and write `newer, older = (new, old) if _report_age(new) >= _report_age(old) else (old, new)`.

### R11 · (round 2) The consent notice doesn't mention the version answers the tip and `a5ff1eb`'s message name
- **Severity:** nit
- **Area:** Security (what players are told)
- **Where:** `NeedRoll/Locales/enUS.lua:1241`, `NeedRoll/UI/Welcome.lua:189`
- **Status:** fixed after round 2 (`a65b3b8`): the notice now reads "shares the boss drops, new quests and class trainer spells you see, and its own version, with other NeedRoll players". Not re-reviewed (two-round limit).

**What's wrong.** `a5ff1eb`'s message says "the Share drops tip and the drop sharing notice now name what this release sends too: new quests, class trainer spells and the NeedRoll version". The tip does name all of them. The notice says only "shares the boss drops, new quests and class trainer spells you see". It leaves out that the copy answers roll calls with its version, under the player's character name (R3).

**Why it matters.** The notice is the consent prompt, the one place every player reads before deciding. It should list what the tip lists. This is minor, since the version is all a roll call answer gives away.

**Fix.** Name the version answer in the notice too. With R10's (a), that's the new sentence suggested there.

### R12 · (round 2) A read that agrees with a heard rank sends it to the channel again
- **Severity:** nit
- **Area:** Redundant code (messages sent for nothing); Readability (a comment the code no longer does)
- **Where:** `NeedRoll/Core/Trainers.lua:161-172` (`SaveRead`, line 168: `if kept and not kept.heard and kept.level == service.level and kept.cost == service.cost then return false end`), compared with the file's own line 25 (`shared = true (sent, or heard from another copy: not sent again)`) and `Core/Drops.lua:1467-1468` ("doesn't send them again")
- **Status:** fixed after round 2 (`a004ca2`) as the Fix below sketches: `SaveRead` keeps the heard rank's `shared` when the numbers agree and returns false, and the smoke step asserts nothing new is queued or sent (it fails with the old `SaveRead`). Not re-reviewed (two-round limit).

**What's wrong.** Suppose a copy has heard a rank from another player, then reads the same level and cost at its own trainer. Round 2 has `SaveRead` replace the heard entry with a fresh read, built without `shared`. `SaveRead` returns true, `ReadTrainer` calls `Trainers.Share()`, and `UnsentGroups` puts the rank in a new `T1` message. So a rank heard on the channel is sent to it again. That's against both comments, and the round 1 behaviour (`return false` for the same numbers). The smoke step "A read with a heard rank's numbers makes it the player's own" (`Core-Trainers.lua`) checks the live data but not the outbox.

**Why it matters.** The second message helps nobody. Every copy that hears it already has the rank (`SaveHeardRank` only marks it shared), and the watcher's copy keeps it `heard`, so the scraper only lists it again. It spends one of the copy's three trainer messages a day (`TRAINER_LIMITS.daily`), which could have carried a rank no one has sent.

**Fix.** Keep the heard rank's `shared` when the player's read agrees with it:
```lua
local kept = saved[service.spellID]
local isSame = kept and kept.level == service.level and kept.cost == service.cost
if isSame and not kept.heard then return false end
saved[service.spellID] = { ..., shared = isSame and kept.shared or nil }
```
Then assert in the smoke step that nothing new is queued. `ReadTrainer` refreshes the live copy after every read anyway, and `Trainers.Share` then finds nothing unsent.

## Area notes

### Readability

All changed Lua was checked against `docs/READABLE-CODE.md`:
- `Core/Trainers.lua` starts `local _, ns = ...`, uses 4-space indents and LF endings, and is split into sections (reading, live copies, sharing, heard ranks).
- Each function does one named thing. The longest, `ReadTrainer`, is 18 lines.
- Comments give the game reason: filters hide services from the API, `TRAINER_UPDATE` fires on the read's own filter changes, English names only because the scraper files spells by English name, the 60-upvalue limit isn't touched.
- Constants carry units (`NAME_MAX = 40 -- bytes`, `ROLL_CALL_GAP = 30 * 60 -- seconds`, `ROLL_CALL_WAIT = 180 -- seconds`).
- `ProfessionOverview.lua`'s camp code reads the same way (`ScaledNumber`, `CampEffectText`, `CampItem`, `CampRecipeLink`, `DropLinks`, `CampSourceText`, `CampEntry`, `CampsByRank`).
- `Data/Camping.lua` documents every field.
- No `cond and nil or x`, no patterns built from data, no `#t` over holes, no `k, v` loops over non-maps, and no comments narrating the change.
- Highest upvalue counts (`luac5.1 -l`): `ProfessionOverview.lua` 14, `Drops.lua` 18, `Trainers.lua` 11. Nothing is near 60.
- No new line over 120 characters in the addon. The only one in the release is R8, in a test, fixed in round 2. Round 2's two long lines in `UI/Settings.lua:83` and `UI/Welcome.lua:189` are literal `L["..."]` keys, which can't be split, as before.
- Round 2 code reads as well as round 1's. `OwnRead`, `ForgetMadeUpBuilds`, `_report_priority`, `_own_reads`, `_set_seen_rank`, `_report_heard` and `NumberedRank` each do one named thing, and their comments give the reason (anyone can send a `T1`, a heard name is another player's text). The top comments of `Trainers.lua`, `ClassSpells.lua`, `Data.lua`, `classspells.py`, the README, `seen.json`'s source and `watcher-data.yml` now say that only the player's own reads show, and only the watcher accounts' reads apply. That matches the code, except R12's "not sent again". `_seen_entry` checks the build twice: `_whole(..., 0, BUILD_MAX)` as a guard, then `_whole(saved.get("build"))` for the value. That's harmless, so it isn't a finding.

Smoke coverage:
- `Core-Trainers.lua` (new, 7 scenarios since round 2): read and filters put back, non-class trainers skipped, `T1` round trip and bad messages, outbox order and three a day, Share drops off. Round 2 adds two: heard ranks leave the live data alone (a made-up build or price is refused, a read beats a heard rank, `ForgetMadeUpBuilds` at login), and a quest rank 1 that the trainer teaches is trained on the live data.
- `Core-Drops.lua`: roll call answered once and only to PROBERS on the channel, counts each answerer once, keeps no names.
- `UI-Classes.lua`: the player's read level and cost on the page, a heard one not (round 2).
- `UI-ClassOverview.lua`: Righteous Fury and the blessings.
- `UI-ProfessionOverview.lua` (4 scenarios): camp data integrity, a profession's Camping section, the Camping page's order, sections opening and shutting.

`docs/STYLE-GUIDE.md` covers the Camping section and page and the new link kinds. The `T1` rows in the dev-only drop talk window aren't in the style guide, and no other dev-window row is either. `CLAUDE.md`'s combat rules: none of the four blocked calls were added, `CHECKED_COMBAT_CALLS` is unchanged, and the `--combat` run passes.

**Carried over from v0.16.0** (not renumbered here; they keep their v0.16.0 IDs, Mike's call):
- **v0.16.0 R11** is still present on dev. `NoteLootSources` (`Core/Drops.lua:1014-1018`) still calls `NoteCreature(Plain(sources[i]))` with no classification, and `IsBossCandidate` still accepts `seen.classification == nil` (`Core/Drops.lua:272`). A creature met only in the loot window can still pass as a boss in an unlisted instance.
- **v0.16.0 R15** is still present on dev. `tests/smoke/check.sh --quick` is still `modes=("" "--combat")`, and `.github/workflows/smoke-tests.yml` still uses `--quick` for PRs into dev. The secret-values run still happens only on main and bot PRs.

Findings: R5, R7, R8, R9 and R3's comment (all fixed in round 2).

### WoW API

Every game function, event, widget method and `Enum` the release adds or newly calls:

| Name | In Ketho's `forever` lists | Where looked |
| --- | --- | --- |
| `IsTradeskillTrainer` | yes | GlobalAPI.lua:6160 |
| `C_Trainer.GetTrainerType` | yes | GlobalAPI.lua:4447 |
| `Enum.TrainerType.General` (`General = 0, TalentsObsolete = 1, Tradeskills = 2, Pet = 3`) | yes | LuaEnum.lua:7892-7897; `wow.lua` mirrors it exactly |
| `GetNumTrainerServices` | yes | GlobalAPI.lua:5696 |
| `GetTrainerServiceInfo` | yes | GlobalAPI.lua:5940 |
| `GetTrainerServiceLevelReq` | yes | GlobalAPI.lua:5942 |
| `GetTrainerServiceCost` | yes | GlobalAPI.lua:5937 |
| `GetTrainerSelectionIndex` | yes | GlobalAPI.lua:5935 |
| `SelectTrainerService` | yes | GlobalAPI.lua:6409 |
| `GetTrainerServiceTypeFilter` / `SetTrainerServiceTypeFilter` | yes | GlobalAPI.lua:5947, 6518 |
| `C_TooltipInfo.GetTrainerService` (its `id` field as the spell ID) | yes (the `id` field: inferred, standard `TooltipData`) | GlobalAPI.lua:4251 |
| `UnitGUID("npc")`, `UnitClass`, `GetLocale`, `GetBuildInfo` | yes | GlobalAPI.lua:6689, 6670, 5560, 5322 |
| `GetNormalizedRealmName`, `UnitFactionGroup` | yes | GlobalAPI.lua:5628, 6687 |
| `C_ChatInfo.SendAddonMessage` (already used) | yes | GlobalAPI.lua:828 |
| `C_Spell.GetSpellTexture` (Camping icon, spell 818, with `Spell_Fire_Fire` fallback; already used) | yes | GlobalAPI.lua |
| `C_Item.GetItemNameByID`, `C_Timer.After` (already used) | yes | GlobalAPI.lua |
| `TRAINER_SHOW`, `TRAINER_UPDATE`, `TRAINER_CLOSED` | yes | Events.lua:1904-1908 |
| `Region:SetShown`, `:ClearAllPoints`, `:GetParent`, `:SetPoint`; `GameTooltip:SetText` / `:AddLine` | yes | WidgetAPI.lua |

Other checks:
- **Secret values.** Every value read from the trainer API goes through `ns.Plain`, and is type-checked before use (`ReadService`, `IsClassTrainer`, `TrainerNpcID`, `ReadTrainer`). The `--secret` run passes.
- **Events.** The three trainer events are all used. `TRAINER_CLOSED` ends the visit. A visit reads at most `READS_PER_VISIT = 3` times, and re-entry from its own filter changes is stopped by `visit.reading`.
- **Taint and combat.** None of the trainer functions are protected. Inferred: changing the filters from addon code could taint the Blizzard trainer frame's variables during its `TRAINER_UPDATE` handler, but training (`BuyTrainerService`) isn't protected, so no blocked-action popup follows. The comment saying the player sees nothing change, because filters and selection are put back before the next draw, is also inferred; only the stand-in confirms it (`Core-Trainers.lua:174`).
- **Globals and dev code.** No new globals. Roll call asking and `/nr users` are inside `--@debug@`. `AnswerRollCall` ships on purpose, and the packaged run passes.
- **Text.** All player-facing text uses literal `L["..."]`: 37 new keys, and `locales.py --check` passes. The roll call's chat lines are dev-only and unlocalised, like the rest of `/nr droptalk`. Round 2 rewords two existing keys (R10).
- **Round 2: `tools/translations.py`.** `FORMAT` no longer takes a space as a flag, so `"+8% to all stats"`, `"Rested XP up to 5% of a level"` and `"+2% critical strike chance"` aren't read as `% t` / `% o` / `% c` specifiers. A grep of `enUS.lua` finds no real `% d`-style specifier that the change could now miss. The three phrases have a bare `%`, which is safe only because `CampEffectText` calls `:format` only on features with `scale`, and none of the three has one.
- **Round 2: heard builds.** `HeardNumber(fields[3], clientBuild)` uses the `clientBuild` file local (`Drops.lua:809`), defined before `DecodeTrainerRanks` (line 1531). When `GetBuildInfo` gives no number, `HeardNumber` falls back to its usual 2^31 cap, and `ForgetMadeUpBuilds` returns at once.
- **Compatibility.** Older copies ignore `T1` and `U1`: v0.16.2's `FORMATS` has no `T` or `U`, so neither counts as a newer format, and the `T` / `U` letters aren't in `TAKE`. This copy adds `T = 1` to `FORMATS`. `U` isn't there, so a later `U2` won't mark copies outdated, which is fine for a presence check.

Findings: R4 (fixed in round 2) and R10 (R1 is filed under Security).

### Redundant code

Compared against:
- `PetPageKit.AddHeading`, `Theme:JoinDots`, `Theme:Plural`, `Theme:Arrow`
- `ns.Wishlist:Sources` and `ns.UI.OpenItemSource` (blueprint drops reuse the Wishlist's)
- `ns.Data:RecipeFor`, `ns.Data:Get`, `ns.UI.SkillRanks`, `ns.Items:Load`
- `ns.CutToBytes`, `ns.HeardNumber`, `ns.ParseGUID`
- in `Drops.lua`: `SplitMessage`, `Short`, `Queue`, the outbox, `ANSWER_WAIT`, `IsProber` / `Drops:ProberKey`, `WhenJoined`, `Refusal` / `SendAnswerText`

The release reuses each of them rather than copying:
- The Quests fold became the general `shutSections`.
- The camp rows reuse `SetupQuest`.
- The roll call reuses the probe's wait, keys and join helper.
- `Trainers.lua`'s `CountKeys` has no shared equivalent; the addon writes the loop inline elsewhere (`Drops.lua:324, 677`).

No unused locals or functions were found (luacheck, plus a grep of each new `local function`). No `print` outside `@debug@`, and no new `OnUpdate`.

Findings: R6 (fixed in round 2) and R12.

### Security

Untrusted input touched:
- **`T1` trainer ranks heard on the channel or guild.** Decoded with anchored patterns, level ≤ 100, known class tokens only, names ≤ 30 bytes with no control characters or `|`, at most `SPELLS_MAX = 600` heard ranks per class (9 classes). The build and cost bounds and the single-sender trust were R1 and R2. Since round 2, builds are ≤ the client's and costs ≤ 1000 gold, and heard ranks change nothing a player sees. Only the watcher's report lists them, by ID and numbers, never by the name another player wrote.
- Round 2, inferred: ranks a dev copy heard between #762's merge and `f7c4859` were saved without `heard`, so `ApplySaved` and the ingest would treat them as reads. Only dev copies (Mike's) sent `T1` in that window, since no release has `Core/Trainers.lua`, so those ranks are Mike's own characters' reads. No clean-up is needed.
- Round 2: heard ranks never expire. Once a class's 600 slots are full, `SaveHeardRank` takes no new heard rank. A griefer can fill them, but now that only blocks more heard ranks from Mike's report, and the player's own reads still save (`SaveRead` has no cap). Not a finding.
- **`U1` roll calls and answers.** Calls are answered only from a PROBERS character (the game sets the sender), only on the realm channel, and with a call ID of ≤ 10 digits. Answers are counted only in dev builds, only for the open call's ID, and once per sender key. Versions match `^v[%w%.%-]+$` (no `|`) and are cut to 24 bytes.
- **`NeedRollDB.trainerSpells` read by the ingest.** `_seen_entry` checks types and level, and `_seen_name` strips control characters and `|`.

Output and rate:
- A roll call answer is one message per copy per 30 minutes (`ROLL_CALL_GAP`, session-local). It goes through the outbox (one a minute, `DAILY_MAX = 100`), after a 5-60 s random wait.
- `T1` messages go behind every drop and quest message: at most three waiting and three sent a day (`TRAINER_LIMITS.daily`), and none while outdated.
- Share drops Off stops all of it:
  - channel messages are dropped before parsing (`Drops.lua:1819`);
  - `Queue` and `QueueTrainerMessage` queue nothing;
  - `SendNext` empties the outbox.

Escaping: no text from others is shown. The `T1` row in the dev window shows only the count, class token and NPC number. The roll call prints only version strings that can't hold `|`.

Names:
- `trainerSpells`, `seen.json` and `rollCalls` hold no names. `rollCalls.where` is the asking character's own realm and faction.
- Answerers are kept as hashed keys for the session only, and answers aren't written to the drop talk log (the scenario checks both).
- `watcher-data.yml` removes `scraper/cache/savedvars` and `scraper/cache/combatlog` before the download cache is saved (`if: always()`, a step before the post-job save).
- No credited name appears outside `scraper/`.

Scraper and workflow:
- No request to Wowhead. `Data/Camping.lua` cites Mike's saved pages, and `trainers` reads the Classic-DB dump and QuestieDB from the cache.
- No `subprocess`, `shell=True`, `eval` or `pickle` in the diff. `seen.json` and `changes.json` are read with `json`, and paths are fixed constants.
- The new workflow step interpolates no `${{ github.event.* }}`, `permissions:` is unchanged, and there's no `pull_request_target`.

Findings: R1, R2, R3 (all fixed in round 2) and R11.

## Round history

- 2026-11-04, round 1, `b917b7a`: **Changes needed** (1 blocking, 1 should fix, 7 nits). Opened R1–R9. Noted v0.16.0's R11 and R15 as still present (Mike's call, carried over).
- 2026-11-04, round 2, `fcf2ec6` (fixes `1d1bec1`, `f7c4859`, `e55b67f`, `a5ff1eb`, `fcf2ec6`; the whole `v0.16.2..fcf2ec6` range re-read): **Changes needed** (0 blocking, 1 should fix, 2 nits open).
  - Fixed: R1 `f7c4859`, R2 `e55b67f`, R3 `a5ff1eb`, R4 `f7c4859`, R5–R8 `fcf2ec6`, R9 `e55b67f`.
  - Opened R10 (the reworded consent notice and tip lose every translation), R11 (the notice leaves out the version answer) and R12 (a read that agrees with a heard rank is sent again).
  - v0.16.0's R11 and R15 are still present (carried over).
- 2026-11-04, after round 2 (release thread, no third round per `/release-review`): R12 fixed `a004ca2`, R11 fixed `a65b3b8`, R10 handled by option (b). All four smoke runs, `locales.py --check` and luacheck on the changed files pass.
