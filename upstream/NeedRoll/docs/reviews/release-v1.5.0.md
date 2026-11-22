# Review: v1.5.0 release (everything merged into dev since v1.4.0)

| | |
| --- | --- |
| Branch | `019e179e..b7d53798` (release review: `origin/dev` since the dev commit v1.4.0 shipped, `git merge-base v1.4.1 origin/dev`); round 2 fixes on `claude/project-thread-nbs7zf` (`b7d53798..HEAD`) |
| Commit reviewed | round 1 `b7d5379`; round 2 `923b548` (`823f177`, `554eea4`, `923b548`; only this Review Doc uncommitted) |
| Date | 2026-11-10 |
| Round | 2 |
| Verdict | **Ready** (0 blocking, 0 should fix, 2 nits open: R2 left for Mike, R7 new in round 2) |
| Needs | Players: a full restart. `UI/QuestChainNotes.lua` is a new file, loaded through `UI/UI.xml`. Earlier reviews treat new files the same way: the client only picks them up at startup (inferred; `docs/reviews/claude-addon-readability-pass-rg51s6-devtools.md`). The `.toc` is unchanged. New saved keys (`sectionMemory`, `sections`) need no migration. With the setting unset, the default is "This character", and each section starts as it always did. |

## What the change does

**Dungeon quest chains in the game's quest windows (PR #846).** A quest that
is one of a dungeon's or raid's quests, or a step on a chain that leads into
one, now says so in the game's own UI. Quest tooltips (chat links and any
tooltip the game's tooltip data processor builds for a quest) and the
tooltips of the world map's quest log rows get a line per dungeon:
"Shadowfang Keep quest chain", after the tab's icon. The quest log's details
show the same note in the bar with the game's Back button, plus an "Open in
NeedRoll" pill. The pill opens NeedRoll on that quest's page, or on a chain
step's light page. The lines follow Settings' "Drop sources on tooltips".
Behind it are a new index, `ns.Data:DungeonsOfQuest` (hand-written, in
`Data/Data.lua`), and two helpers that `Core/Tooltip.lua` now exports.
`NeedRoll_ShowQuest(questID)` also opens chain steps (`API.lua`,
`docs/API.md`).

**Remember sections (PR #848).** A new Settings row, "Remember sections"
(This character / All characters / Off), keeps sections open or shut after
a reload or logout. That covers the loot pane's sections, the middle
column's groups (Encounters, Quests, wings, questlines, colour sets, the
Classes tab's sections and folds) and a raid's Attunement heading.
`ns.SectionMemory` in `Core/Init.lua` holds one table per area
(`loot`, `list`, `classes`, `attunement`) in the set the setting picks. Empty
tables are dropped at `PLAYER_LOGOUT`. Loot sections are now keyed by a
fixed word (`WEAPONS`) instead of their translated name.

**Dev-only pull (PR #843, #844, #847).** On a PROBERS character in a local
checkout, `Core/DropPull.lua` whispers a probe every 10 s (was 120 s). It
runs outside the outbox's minute and its daily count, with no daily limit
of its own, and asks each player again after an hour (was six). A player
whose whisper bounced waits 30 min, and the next round re-reads the member
list. `Drops.SendGapLeft`/`Drops.TakeSendTurn` are gone, and the outbox
again only times itself. Released builds send exactly as before.

**Smaller changes.** Four more PROBERS keys (PR #852, hashes only).
Uldaman's The Lost Dwarves move out of Trash Drops into their own encounter
(scraper catalog, PR #845). The scraper puts a new trainer-seen spell's
ranks in order by rank number, then level (PR #851). There are also two
watcher data imports (PR #842, #849) and translations (PR #850).

## Scope

- `NeedRoll/API.lua`: `OpenQuestPage` (replaces two copies of GoToSource + SelectQuest), `ShowOnFirstDungeon`, `NeedRoll_ShowQuest` by ID tries the player's side's dungeons and chain steps first.
- `NeedRoll/Core/DropPull.lua` (dev-only; `.pkgmeta` ignores it, `.toc` debug block): `PULL_GAP` 10, `ASK_GAP` 1 h, `DAILY_MAX` and `Drops.TakeSendTurn` removed, `BOUNCE_WAIT` + `bouncedAt`, the list re-read after a bounce, status line without a limit, comments.
- `NeedRoll/Core/Drops.lua`: `Drops.SendGapLeft` and the dev `Drops.TakeSendTurn` removed. `SendNext` no longer waits on the pull, and `Queue` works out the gap itself. Probe comments and four new `PROBERS` keys.
- `NeedRoll/Core/Init.lua`: `ns.SectionMemory` (modes, sets, areas, mode-change handlers, empty tables dropped at logout); comments on saved keys.
- `NeedRoll/Core/Names.lua`: the "The Lost Dwarves" label.
- `NeedRoll/Core/Tooltip.lua`: `Tooltip.AddNamed` and `Tooltip.CanAddLines` exported for quest tooltips; `OnItemTooltip` uses `CanAddLines`.
- `NeedRoll/Data/Data.lua`: `ns.Data:DungeonsOfQuest` with `AddDungeon`, `ChainQuestIDs`, `IsForSide`, `BuildDungeonsOfQuest` (hand-written, reviewed in full).
- `NeedRoll/UI/QuestChainNotes.lua` (new) and `NeedRoll/UI/UI.xml` (loads it after `WorldMapOverlay.lua`).
- `NeedRoll/UI/Lists.lua`: `GROUP_START` metatable, `TakeGroups`, the mode-change handler, `memoryArea` for section lists.
- `NeedRoll/UI/LootGrid.lua`: `SECTIONS` with keys; `shutSections` from the "loot" area; toggles by key.
- `NeedRoll/UI/Overview.lua`: `attuneOpen` from the "attunement" area.
- `NeedRoll/UI/Classes.lua`: `memoryArea = "classes"`.
- `NeedRoll/UI/Settings.lua`: the Remember sections row (`SECTION_MEMORY_NAMES`, `SECTION_MEMORY_CHOICES`, `SECTION_MEMORY_BY_NAME`).
- `NeedRoll/UI/DropTalk.lua` (dev-only): "Whisper bounced" rows.
- `NeedRoll/Locales/enUS.lua`: 6 new strings (`The Lost Dwarves`, `%s quest chain`, `Open in NeedRoll`, `This character`, `All characters`, the Remember sections label, note and tip); `Off` moves up. `koKR`, `ruRU`, `zhCN`: `Accessories` (Translations bot).
- `docs/API.md`, `docs/STYLE-GUIDE.md`: chain steps for `NeedRoll_ShowQuest`; the quest tooltip lines, quest log note and pill, Remember sections row and section memory. Values checked against the code: `BACK_GAP` 8, `BOX_RIGHT_INSET` 13, `BOX_TOP` −5, `BOX_BELOW_BACK` 6, `PILL_HEIGHT` 20, pill padding 24, `GameFontNormalSmall` in `Theme.tip.info`, row order Collection ticks → Remember sections → Share drops.
- `scraper/needroll_scraper/catalog.py` (THE_LOST_DWARVES, NPCs 6906–6908), `scraper/needroll_scraper/classspells.py` (sort key), `scraper/tests/test_classspells.py`.
- `tests/smoke/wow.lua` (quest tooltip via `SetHyperlink`, `QuestMapFrame` stand-in, `QuestMapLogTitleButton_OnEnter`, `Enum.TooltipDataType.Quest = 23`) and modules `API`, `Core-DropPull`, `Core-Init`, `UI-Classes`, `UI-DropTalk`, `UI-Lists`, `UI-LootGrid`, `UI-Overview`, `UI-QuestChainNotes` (new), `UI-Settings`.
- Skipped, as generated: `NeedRoll/Data/Abilities.lua`, `Bosses.lua`, `ClassSpells.lua`, `Dungeons/*.lua`, `KnownDrops.lua`, `KnownQuests.lua`, `Quests.lua`. `needroll_scraper build --check` says "No data files changed", so none was edited by hand.
- Inputs, checked only for what they hold: `scraper/abilities/observed.json`, `scraper/classes/seen.json`, `scraper/drops/credits.json`, `items.json`, `observed.json`, `scraper/professions/trainer_checks.json`, `scraper/quests/logged.json`, `reported.json`. Credits stay in `scraper/drops/credits.json`; `.pkgmeta` ignores `scraper`.
- Not in scope: `CHANGELOG.md`, `CHANGELOG-DETAILED.md`, v1.4.1's data (on `main` only).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 29 changed Lua files (generated data skipped) | passed |
| `luacheck --no-global -q` | **not run**: luacheck isn't installed here (no `luacheck`, no `luarocks`). Instead, every `local` the diff adds was grepped for a second use, and all have one |
| `tests/smoke/check.sh` (dev, packaged, secret values, in combat) | passed: "all passed" in all four runs (217 / 209 / 217 / 217 files loaded; 651 / 570 / 651 / 651 scenarios ok) |
| `python3 tools/locales.py --check` | passed (exit 0, no output) |
| `python3 tools/translations.py` | passed (exit 0, no output) |
| `cd scraper && python3 -m unittest discover -s tests` | passed (351 tests) |
| `python3 -m needroll_scraper build --check` (extra: hand edits to generated data) | passed: "No data files changed" |
| Lua 5.1 limits (extra; `luac5.1 -l -l`, most upvalues in one function and the peak of main-chunk locals active at once, now / at `019e179e`) | `Core/Drops.lua` 189 / 189 locals, 16 upvalues. `UI/Overview.lua` **195 / 195** locals (unchanged, but 5 from the limit), `CreateOverview` 34 / 34 upvalues. `UI/Lists.lua` `CreateEncounterList` 43 / 42 upvalues, 112 locals. `UI/LootGrid.lua` `CreateLootGrid` 40 / 40, 179 locals. `Data/Data.lua` 62 / 57 locals. `Core/Init.lua` 31 / 25. `UI/Settings.lua` 67 / 64. `UI/QuestChainNotes.lua` 20 locals, 8 upvalues. None near 60 upvalues; nothing grew toward 200 except by a few locals in files far from it |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Readability (player-facing text) | `NeedRoll/UI/Settings.lua:95-100`, `:5` | "Drop sources on tooltips" now also hides quest chain lines, but says only item tooltips | fixed in round 2 (`823f177`) |
| R2 | nit | Security (sending limits) | `NeedRoll/Core/DropPull.lua:39-44`, `:84-91` | The dev pull has no cap of its own any more | left for Mike |
| R3 | nit | Readability | `NeedRoll/Core/DropPull.lua:44`, `:231`; `NeedRoll/Core/Drops.lua:965`, `:2494` | Two `BOUNCE_WAIT`s mean different things in the same code path | fixed in round 2 (`554eea4`) |
| R4 | nit | Readability | `tests/smoke/modules/Core-DropPull.lua:9`, `:186`; `NeedRoll/Core/Drops.lua:16` | Comments still say the minute between messages covers pulls | fixed in round 2 (`554eea4`) |
| R5 | nit | Readability (consistency) | `NeedRoll/UI/QuestChainNotes.lua:137`; `NeedRoll/UI/Theme.lua:581`; `NeedRoll/UI/MainFrame.lua:2543` | The quest log pill's style depends on whether NeedRoll's window was opened first | fixed in round 2 (`923b548`) |
| R6 | nit | Readability | `NeedRoll/UI/QuestChainNotes.lua:40`, `:126-160` | `details` (NeedRoll's box) next to `detailsFrame` (the game's frame) | fixed in round 2 (`923b548`) |
| R7 | nit | Readability (consistency) | `NeedRoll/UI/Theme.lua:1078-1084` | `Theme:NativePill` switches the whole Theme to Native and back, where `Theme:SearchBox` takes a named skin | open (round 2) |

### R1 · "Drop sources on tooltips" now also hides quest chain lines, but says only item tooltips
- **Severity:** should fix
- **Area:** Readability (player-facing text that misleads; READABLE-CODE §9)
- **Where:** `NeedRoll/UI/Settings.lua:95-100` (the row), `:5` (the file's header comment); `NeedRoll/Core/Tooltip.lua:190` (`Tooltip.CanAddLines`)
- **Status:** fixed in round 2 (`823f177`)

**What's wrong.** The quest chain lines are switched off with the item
source lines (`Tooltip.CanAddLines` checks `Tooltip:IsOn()`, i.e.
`ns.db.tooltipSources ~= false`). The setting a player sees still describes
only items:

```lua
label = L["Drop sources on tooltips"],
...
about = L["Item tooltips show which boss drops them"],
tip = L["Item tooltips anywhere in the game (bags, inspect, chat links, loot) name the dungeon or raid boss that drops the item."],
```

The developer-facing comments were updated (`Core/Init.lua` defaults and the
`Core/Tooltip.lua` header). The Settings header (`:5`, "drop sources on item
tooltips") and the text players read were not.

**Why it matters.** A player who turned the setting off to clean up item
tooltips never sees the new quest chain lines, and nothing tells them why.
A player who wants the quest lines gone has no way to know which switch
does it: they would look for a quest setting and find none. Settings is
the only place this is explained.

**Evidence.** `git diff 019e179e b7d53798 -- NeedRoll/UI/Settings.lua` shows only the
Remember sections row added. `Settings.lua:95-100` is quoted above.
`QuestChainNotes.lua:68` calls `ns.Tooltip.CanAddLines`. The STYLE-GUIDE's
quest tooltip row says "None ... with Settings' Drop sources on tooltips
off".

**Fix.** Give the row's note and tip new strings that name both, for
example `about = L["Item and quest tooltips name their dungeon or raid"]`
and a tip that adds "Quest tooltips and the quest log name the dungeon
whose quest chain the quest is on." These are new `L` keys, so the old ones
drop out through the Translations bot as usual. Update `Settings.lua:5`
and the STYLE-GUIDE's Settings rows to match. Renaming the label
("Dungeon lines on tooltips") is optional. If it changes, it is a new key
too.

### R2 · The dev pull has no cap of its own any more
- **Severity:** nit
- **Area:** Security (sending limits), dev-only
- **Where:** `NeedRoll/Core/DropPull.lua:39-44` (constants), `:84-91` (`CanPullNow`), `:216-232` (`Ask`)
- **Status:** left as is: the pace is Mike's decision of 2026-11-09, recorded in the file's header; left for Mike to decide on a safety cap

**What's wrong.** v1.4.0's R3 put the pull on the outbox's minute and gave
it a daily limit of 60. This range takes both back on purpose (PR #843):
`PULL_GAP = 10`, `DAILY_MAX` removed, `Drops.SendGapLeft`/`TakeSendTurn`
removed, and `ASK_GAP` cut from 6 h to 1 h (PR #847). The reviewer
checklist's rule ("sending respects ... the one-message-a-minute outbox and
daily cap") no longer holds for the pull. The header comment says so
openly.

**Why it matters.** What bounds the pull now is how it picks players.
`Ask` stamps `askedAt` before anything else, and a bounce holds the player
off for `BOUNCE_WAIT`. So each member gets at most one probe an hour, plus
one after a bounce, with at most one probe per 10-second tick. That is up
to 360 whispers an hour and 8,640 a day on a large channel, from one of
Mike's characters, to players it doesn't know. The game's addon-message
throttle allows far more (inferred from the v1.4.0 review's figures), so
nothing breaks. What is unknown is whether the servers react to that
many addon whispers to strangers. NRDT is already refused on live, and the
reason for that isn't known. If something misfires, there is no backstop
left: for example a member list that keeps returning players whose bounce
line isn't recognised. The status line (`PulledToday`) still counts but
stops nothing. Every answering copy also spends up to 25 of its own
outbox messages per probe, now as often as hourly. Those answers are small
in practice, because a probe asks only "since the last pull that reached
you".

**Evidence.** `DropPull.lua:38-55`, `:84-91`, `:181-201` and `:216-232`.
`grep -n "SendGapLeft\|TakeSendTurn\|DAILY_MAX" NeedRoll/Core/DropPull.lua`
finds only the header's prose. Smoke scenario "a probe a tick on the pull's
own clock; the outbox keeps its minute; no daily limit".

**Fix.** Keep Mike's pace, but add a high safety cap that only a fault
would reach, so a fault stops itself. For example
`DAILY_SAFETY_MAX = 2000 -- pulls a day; only a fault gets near it`, checked in
`CanPullNow` against `PulledToday()`, with the status line showing it. Or
leave it as is and record the exception in the reviewer's checklist, so the
next review doesn't reopen it.

### R3 · Two `BOUNCE_WAIT`s mean different things in the same code path
- **Severity:** nit
- **Area:** Readability (READABLE-CODE §7 searchable names, §8 mental mapping)
- **Where:** `NeedRoll/Core/DropPull.lua:44` (`DropPull.BOUNCE_WAIT = 30 * 60`) and `:231` (`Drops.WHISPER_BOUNCE_WAIT`); `NeedRoll/Core/Drops.lua:965` (`Whispers.BOUNCE_WAIT = 60`), `:2494`
- **Status:** fixed in round 2 (`554eea4`)

**What's wrong.** `Whispers.BOUNCE_WAIT` (exported as
`Drops.WHISPER_BOUNCE_WAIT`) is how long after a whisper the game's "No
player named ..." line counts as about it: 60 s. PR #844 adds
`DropPull.BOUNCE_WAIT`, how long a bounced player waits before being asked
again: 30 min. Both appear in `DropPull.lua`, eight lines apart in `Ask` and
`OnBounce`.

**Why it matters.** A search for `BOUNCE_WAIT` finds both. A reader of
`Ask` (`C_Timer.After(Drops.WHISPER_BOUNCE_WAIT, ...)`) can easily take the
30-minute constant in the same file's table for the one used here, or the
other way round.

**Fix.** Name the new one for what it does:
`RETRY_AFTER_BOUNCE = 30 * 60 -- seconds before a player whose pull bounced is asked again`,
and use that name in `Candidates` and the `OnBounce` comment.

### R4 · Comments still say the minute between messages covers pulls
- **Severity:** nit
- **Area:** Readability (a comment that is now wrong; READABLE-CODE §5, §9)
- **Where:** `tests/smoke/modules/Core-DropPull.lua:9`, `:186`; `NeedRoll/Core/Drops.lua:16`
- **Status:** fixed in round 2 (`554eea4`)

**What's wrong.**

- `Core-DropPull.lua:9`:
  `local SEND_GAP = 60 -- Core/Drops.lua: seconds between drop sharing messages, pulls included`.
  Since PR #843, pulls are exactly what this gap leaves out, and the
  scenario at `:179` tests that.
- `Core-DropPull.lua:186` narrates history: "past the 60 a day the pull once
  kept to".
- `Drops.lua:16`, the file's header: "Messages leave at most one a minute
  and at most DAILY_MAX a day". That is true of the outbox and of released
  builds, but in a local checkout a PROBERS character now also whispers
  every 10 s. The exception is written down only further down, under
  Catch-up probes (`:2128-2130`).

**Why it matters.** The next change to the pull or the outbox starts from
these lines. The test's constant says the opposite of what its scenario
checks.

**Fix.** `:9`: "seconds between the outbox's messages (the dev pull keeps
its own clock)". `:186`: "past 60 pulls today". `Drops.lua:16`: add
"(released builds; a dev build's pull whispers on its own clock, see
Catch-up probes)".

### R5 · The quest log pill's style depends on whether NeedRoll's window was opened first
- **Severity:** nit
- **Area:** Readability (consistency: the same widget looks two ways)
- **Where:** `NeedRoll/UI/QuestChainNotes.lua:137` (`Theme:Pill(box)`), `:136` (`Theme:SetTextColor`); `NeedRoll/UI/Theme.lua:581` (`Theme:SetSkin("native")` at load); `NeedRoll/UI/MainFrame.lua:2543` (the player's style is set only when the window is first built)
- **Status:** fixed in round 2 (`923b548`): the pill is always Native (`Theme:NativePill`); see R7

**What's wrong.** `Theme:Pill` draws with the Theme's current skin
(`self.color`, `self.font.body`, `self.corners`). Until NeedRoll's window is
built in a session, that skin is `native`, not the player's (`ns.db.skin`).
The note's box is built the first time a chain quest shows in the quest log
(`details = details or CreateDetailsNote(...)`) and never repainted.

**Why it matters.** A player using the Modern, Dark or ElvUI style who
opens the quest log before NeedRoll gets a Native pill: gold edge and Native
font for the whole session. If they open NeedRoll first, the same pill is
Modern (rounded, Modern font), or square under ElvUI. A `/reload` can flip
it. Changing style in Settings never reaches it. The STYLE-GUIDE row
doesn't say which style it should be. The zone button on the world map
(`WorldMapOverlay.lua:145`) was already built the same way.

**Evidence.** `Theme.lua:549-558` and `:581`; `MainFrame.lua:2542-2547`.
`grep -rn "db.skin"` finds no other place that applies the saved skin. Not
seen in game; this follows from the code.

**Fix.** Pick one on purpose. Either always use the Native look in the
game's own windows, which arguably fits the quest log best: build the
pill while the Theme is on `native` and say so in the STYLE-GUIDE. Or apply
the saved skin before building (`if not ns.UI.frame then
Theme:SetSkin(ns.db.skin) end`, which is what `UI:Show` does first anyway).
Either way, write the choice in the STYLE-GUIDE's "Quest log note and pill"
row.

### R6 · `details` (NeedRoll's box) next to `detailsFrame` (the game's frame)
- **Severity:** nit
- **Area:** Readability (READABLE-CODE §1, §8)
- **Where:** `NeedRoll/UI/QuestChainNotes.lua:40`, `:113`, `:123`, `:126-160`
- **Status:** fixed in round 2 (`923b548`)

**What's wrong.** The file-level `details` is NeedRoll's own box (the
note and the pill). `CreateDetailsNote(detailsFrame)` takes the game's
`QuestMapFrame.DetailsFrame`, and the comments call that "the quest log's
details". So `details.questID` and `QuestMapFrame.DetailsFrame` read as the
same thing, but they aren't. The smoke test already calls the box
`NoteBox`.

**Fix.** Rename the local `detailsNote` (or `noteBox`), matching
`CreateDetailsNote`/`ShowDetailsNote`.

## Round 2

I reviewed `git diff b7d53798 HEAD` on `claude/project-thread-nbs7zf`:
`823f177` (R1), `554eea4` (R3, R4) and `923b548` (R5, R6). I read every
function those commits touched in full: `Theme:NativePill` and the
`Theme:Pill`, `CornerFill`, `CornerOutline`, `SymbolStrokes`,
`Theme:Text` and `Theme:SetTextColor` it calls; `CreateZoneButton`; the
whole of `QuestChainNotes.lua`; `Candidates`, `Ask` and `OnBounce`; and the
Settings row.

### Round 1 findings

| ID | Round 2 status | How it was checked |
| --- | --- | --- |
| R1 | fixed | The note is now "Bosses on item tooltips, quest chains on quest tooltips". The tip adds "Quest tooltips (chat links, the quest log) name the dungeon or raid whose quest chain the quest is on." Both are new `L` keys, the English list is regenerated, and `Settings.lua:5` is reworded. The STYLE-GUIDE has a new Settings row. A new scenario checks that the note fits on one line at the smallest window width, at both text sizes. `translations.py` lists the two old keys as no longer used in the translation files; the Translations bot removes them, as usual. |
| R2 | left for Mike | Unchanged; Mike's 2026-11-09 decision. |
| R3 | fixed | `DropPull.RETRY_AFTER_BOUNCE` everywhere (constant, `Candidates`, `OnBounce`'s comment). `grep -n BOUNCE_WAIT NeedRoll/Core/DropPull.lua` now finds only `Drops.WHISPER_BOUNCE_WAIT`, and `Ask` has a new comment saying what that wait is for. |
| R4 | fixed | The test's `SEND_GAP` comment says the dev pull keeps its own clock. The narration at `:186` is gone. `Drops.lua:19-20` says the one-a-minute rule holds for released builds and points to Catch-up probes. |
| R5 | fixed | `Theme:NativePill` builds the quest log pill, and the world map's zone button too, in the Native style whatever the window uses, so neither depends on what was opened first. The STYLE-GUIDE has a Native pill row and both widget rows were updated; the Native palette values in it (`pillEdge` FFD100 at 55%, `pillFill` FFD100 at 22%, rounded) match `Theme.lua:146-147` and `SKINS.native`. A new scenario checks that, with the window on Dark, the pill gets the Native body font, the Theme is back on Dark afterwards, and a later switch to Modern doesn't reach the pill. |
| R6 | fixed | `detailsNote` in all six places. |

### Is `Theme:NativePill`'s temporary switch safe?

```lua
function Theme:NativePill(parent, symbol)
    local skinInUse = self.name
    self:SetSkin("native")
    local pill = self:Pill(parent, symbol)
    self:SetSkin(skinInUse)
    return pill
end
```

- **Nothing else reads the Theme in between.** WoW runs addon Lua on one
  thread. `Theme:Pill` makes a plain `Button` (no template, so no `OnLoad`)
  and fires no script while it runs, so no other NeedRoll code can run
  between the two `SetSkin` calls. The only exception would be another addon
  hooking `CreateFrame`, which wouldn't read NeedRoll's Theme.
- **The pill reads the Theme only while it is built.** It reads
  `self.color`, `self.font.body` and `self.corners`:
  - `Paint` uses the `colors` local captured at build.
  - `CornerFill` and `CornerOutline` choose their texture at build.
  - `Theme:SetTextColor` keeps no state.

  So the pill stays Native after the switch back (`Theme.lua:1039-1071`,
  `:870-917`, `:1506`).
- **The switch back is exact.** `SetSkin` only sets `name`, `native`,
  `corners`, `color` and `font` from the skin tables. Nothing else assigns
  those fields (grepped). `self.name` is already the shown skin, so
  `ShownSkin` maps it to itself. It also nests correctly if called from
  inside another build.
- **If `Theme:Pill` raised an error**, nothing would switch back. The Theme
  would stay Native for the rest of the session, and anything NeedRoll's
  window built after that (a tab or the Settings page opened for the first
  time) would come out Native, in Native colors, beside panes in the
  player's style. `Theme:Pill` doesn't fail on a valid parent, and both
  callers pass one: the quest log's `BackFrame`, checked in `HookQuestLog`,
  and the world map's overlay. So this is a fragility, not a bug. See R7.

### New findings

### R7 · `Theme:NativePill` switches the whole Theme to Native and back, where `Theme:SearchBox` takes a named skin
- **Severity:** nit
- **Area:** Readability (READABLE-CODE §6: one way of doing each thing)
- **Where:** `NeedRoll/UI/Theme.lua:1078-1084` (`Theme:NativePill`); compare `NeedRoll/UI/Theme.lua:1646-1661` (`Theme:SearchBox(..., skin)`)
- **Status:** open (round 2)

**What's wrong.** Theme.lua now has two ways to build a widget in a skin
other than the window's:
- `Theme:SearchBox` takes a `skin` argument and reads that skin's tables
  (`self:Palette(skin)`, `self:Fonts(skin)`), leaving the Theme alone.
- `Theme:NativePill` changes the shared Theme state and puts it back.

The switch is safe as written (above), but it isn't error-safe. It also
makes every reader of `Theme.name`/`Theme.color` depend on no one calling
it at the wrong moment.

**Why it matters.** If a later change to `Theme:Pill` can raise an error,
the restore line never runs and the rest of the session's NeedRoll panes
draw Native. Someone adding a third such widget has two patterns to copy.

**Fix.** Build the pill from a view of the Native skin, so the shared Theme
never changes:

```lua
function Theme:NativePill(parent, symbol)
    local nativeTheme = setmetatable({ name = "native", native = true, corners = SKINS.native.corners,
        color = self:Palette("native"), font = self:Fonts("native") }, { __index = self })
    return Theme.Pill(nativeTheme, parent, symbol)
end
```

`Theme:Pill`, `CornerFill`, `CornerOutline` and `Theme:Text` read only
those fields plus `media` and methods, which `__index` supplies. This also
answers v1.4.0's R11 (a search box with a named skin takes the window's
corners), if `SearchBox` adopts it. Alternatively, keep the switch and
wrap the build in `pcall` so the switch back always runs, then re-raise
the error.

### Round 2 checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 9 changed Lua files | passed |
| `tests/smoke/check.sh` (dev, packaged, secret values, in combat) | passed: exit 0, "all passed" in all four runs (217 / 209 / 217 / 217 files loaded; 653 / 572 / 653 / 653 scenarios ok, the two new ones included) |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | passed (exit 0); lists the two replaced English phrases as no longer used in the translation files, for the Translations bot |
| `luacheck` | not run (not installed), as in round 1 |
| Lua 5.1 limits (extra) | `Theme.lua` main chunk 90 locals, most upvalues 8; `WorldMapOverlay.lua` 43 / 9; `QuestChainNotes.lua` 20 / 8. `NativePill` is a `Theme` method, so it adds no local |
| Player names (extra) | none in the round 2 diff (grepped) |

## Area notes

### Readability

I read every changed function in full against READABLE-CODE.md:
`QuestChainNotes.lua` (whole file), `ns.SectionMemory` and its helpers,
`DungeonsOfQuest` and its four helpers, `ShowOnFirstDungeon` and
`OpenQuestPage`, `Tooltip.CanAddLines`, `TakeGroups` and the mode-change
handlers, `TakeSections`, `Sectioned`, `ToggleSection`, the Settings row,
and the whole of `DropPull.lua`.

Names are in game terms (`ChainText`, `ChainLine`, `ShowDetailsNote`,
`IsForSide`, `ChainQuestIDs`, `GROUP_START`, `sectionKey`, `bouncedAt`,
`isBouncedRecently`), except R3 and R6. Layout numbers are named constants
with a comment saying where they come from (`BACK_GAP` ... `BOX_BELOW_BACK`).
No function nests more than three levels. `BuildDungeonsOfQuest`'s two passes
are explained ("Each instance's own quests first"). Comments explain game
facts: hooksecurefunc running after the game's code, the quest log loading
before or after NeedRoll, SavedVariables written only on reload or logout,
translated text never used as a saved key, a logged-off player lingering in
the member list. "Now" appears only as "at this moment"
(`QuestChainNotes.lua:146`). The one piece of narration is in a test (R4).
Every file has `local _, ns = ...`; the new lines are within 120 characters
except one `L["..."]` tip, as other tips already are.

Lua 5.1 traps were looked for and not found:
- `cond and nil or x` doesn't occur. The new `and ... or` uses are all
  safe: `#dungeons > 1 and L[...]:format(...) or nil`, `not x or nil`, and
  `lastSentAt and GetTime() - lastSentAt or SEND_GAP`, where the middle
  value is never false.
- No `#` on a table with holes.
- One string pattern built from data: `quest:(%d+)` on a link. It is a
  fixed pattern.

`setmetatable(saved, GROUP_START)` on a SavedVariables table is safe: the
game saves no metatables, and `pairs(open)` in `OpenWing` only looks for
`WING:` keys, which have no default. Saved keys are stable: wings are
`Live`/`Undead` (`Data.lua:1376`, not translated), loot sections use fixed
words, and folds and questlines use data keys.

### WoW API

| Call / event / method / template / Enum | In Ketho's `forever` lists | Where checked |
| --- | --- | --- |
| `hooksecurefunc`, `issecretvalue`, `tContains`, `UnitFactionGroup`, `CreateFrame`, `time`, `date`, `setmetatable` | yes | GlobalAPI.lua |
| `QuestMapFrame_ShowQuestDetails` (hooked), `QuestMapLogTitleButton_OnEnter` (sends the callback below) | yes | FrameXML.lua |
| `Enum.TooltipDataType.Quest` (= 23, as `wow.lua` has it) | yes | LuaEnum.lua |
| `GameFontNormalSmall` | yes (Font, inherits `SystemFont_Shadow_Small`) | Templates.lua |
| `SetOwner`, `GetOwner`, `SetText`, `AddLine`, `Show`, `Hide`, `IsShown`, `IsForbidden`, `ClearLines`, `CreateFontString`, `SetPoint`, `SetJustifyH`, `SetWordWrap`, `GetStringWidth`, `SetScript`, `HookScript`, `Raise`, `GetChildren` | yes | WidgetAPI.lua |
| `TooltipDataProcessor.AddTooltipPostCall` | inferred (a FrameXML table, in none of the lists; nil-guarded the same way as `Core/Tooltip.lua:286`) | grep of all lists |
| `EventRegistry:RegisterCallback("QuestMapLogTitleButton.OnEnter", ...)` | inferred (table and callback name not listed; nil-guarded; the event's sender `QuestMapLogTitleButton_OnEnter` is in FrameXML.lua) | grep of all lists |
| `QuestMapFrame`, `.DetailsFrame`, `.BackFrame`, `.BackButton` | inferred (frames, not listed); every level is nil-checked before hooking (`QuestChainNotes.lua:167-169`) | — |
| `GameTooltip`, `ItemRefTooltip` (fallback branch only) | inferred (standard global frames) | — |

- **Combat.** No new call from the four blocked-for-every-frame list.
  `tests/smoke/scenarios.lua` (`CHECKED_COMBAT_CALLS`) is unchanged, and the
  `--combat` run passed. The note and pill are plain frames under the game's
  quest log bar. The click calls `NeedRoll_ShowQuest`, which shows only
  NeedRoll's own window (`UI:Show`, the same path as `/nr`). It never opens,
  hides or switches the game's map, as the root CLAUDE.md requires. The
  `UI-QuestChainNotes` scenario clicks it in combat. The hooks are post-hooks
  (`hooksecurefunc`, `EventRegistry`), so the game's code runs unchanged.
  The box has no `layoutIndex`, so a layout frame would skip it
  (inferred).
- **Not verified in game (inference):**
  - Forever's `QuestMapLogTitleButton_OnEnter` is assumed to build its
    tooltip line by line (as `wow.lua` models it), not through quest tooltip
    data. If it used the data path, a row's tooltip would get the chain
    lines twice.
  - `ns.UI.frame:Raise()` brings the window in front of the map. The window
    is HIGH strata, the map MEDIUM (STYLE-GUIDE secure button row). A
    maximized map on a higher strata hasn't been checked.
- **Secret values.** `QuestChainNotes.Dungeons` refuses a secret or
  non-number quest ID (`:46`). The `SetHyperlink` fallback checks
  `issecretvalue(link)`. No quest title is read. The `--secret` run passed.
- **Async data.** None needed: quest IDs and NeedRoll's own data only.
- **Events.** `HookQuestLog` stays registered on `ADDON_LOADED` and
  `PLAYER_LOGIN` after it has hooked; it returns at once. `ns:On` has no
  way to unregister, so this matches the rest of the addon. The world map
  hooks (`MainFrame.lua:2907`, `WorldMapOverlay.lua:407`) filter by addon
  name, though; this one doesn't need to, because its first call at load
  usually succeeds (`wow.lua` models `QuestMapFrame` as loaded before
  addons).
- **No new globals.** `ns.QuestChainNotes` and `ns.SectionMemory` are on
  `ns`. `NeedRoll_ShowQuest` already existed.
- **Lua limits.** See Checks. `Overview.lua`'s main chunk is at 195 of 200
  locals, unchanged in this range, and the next new top-level local there
  should be weighed. `CreateOverview` has 34 upvalues, not 60. The `ns.`
  lookups added there use the existing `ns` upvalue.
- **Smoke mirrors.** The new game calls and frames are mirrored in
  `wow.lua`, which defines nothing Forever lacks (all of it is in the lists
  or standard FrameXML). Each feature has scenarios: quest tooltip lines,
  the quest log row, the note and pill (other quests, tabs off, Quests off,
  own window, setting off, in combat), section memory per area and mode,
  the bounce wait and the pull's clock.
- **Text.** Player-facing text is literal `L["..."]` and the English list is
  in sync. DropPull and DropTalk strings are dev-only and English, as
  before.
- **Dev-only code.** `Core/DropPull.lua` is in `.pkgmeta` and a `.toc` debug
  block; `UI/DropTalk.lua` is in `.pkgmeta`. The packaged run (209 files)
  passed.
- **STYLE-GUIDE.** Updated in the same release, with values matching the
  code (see Scope). Two gaps: it doesn't say the tooltip setting also covers
  quest lines in the Settings rows (R1), and it doesn't say which style the
  pill has (R5).

### Redundant code

The new code reuses existing helpers instead of copying them:

- The pill is `Theme:Pill`, the note's text `Theme:JoinDots` and
  `Theme:SetTextColor`.
- Quest tooltip lines use `Tooltip.AddNamed` and `Tooltip.SourceIcon`, now
  exported rather than copied.
- `Tooltip.CanAddLines` merges the item tooltip's three separate guards
  into one, shared with quest tooltips.
- `DungeonsOfQuest` builds on `Data:ChainsWith`, `Data:FittingChain` and
  `Data:Quests`.
- `ShowOnFirstDungeon` uses `ns.UI.QuestChain.Page`/`.Step`.
- `OpenQuestPage` replaces two copies of GoToSource + SelectQuest in
  `API.lua`.

The Remember sections row follows the existing `SKIN_BY_NAME` pattern for
choices shown by name. `TableIn` has no twin in the addon (grepped). One
cached index per side replaces per-tooltip searches. No dead code: every
new local has a second use. The removed `Drops.SendGapLeft`/`TakeSendTurn`
have no callers left (grepped; only `CHANGELOG-DETAILED.md`'s v1.4.0
history names them). No stray prints outside `@debug@`. No findings in
this area.

### Security

Untrusted inputs and outputs this release touches:

- **Whispered addon messages** (`Whispers.Read`, unchanged). Answers are
  taken only from players the pull asked, within `ANSWER_WINDOW`, through
  the same anchored decoders.
- **Sending limits.** Released builds are unchanged: the outbox sends one a
  minute and `DAILY_MAX` (500) a day. `SendNext` now sets `lastSentAt`
  alone, and `Queue` waits out the rest of the minute. "Share drops" Off
  still stops the pull (`DropPull.IsOn` checks `Drops:ChannelOn()`). The
  dev pull's pace is R2.
- **Session tables.** `Whispers.sentAt` gains one name per whisper and is
  never trimmed, now up to 360 an hour. It is memory only and ends with the
  session; at that size, not a finding.
- **Saved tables.** `NeedRollDB.dropPull.askedAt` now grows with every
  member asked within `SINCE_MAX`, not 60 a day. It is pruned by
  `ForgetOldPulls`, kept by hash, and lives only in Mike's own
  SavedVariables.
- **Names.**
  - The four new `PROBERS` entries are 16-hex-digit `ProberKey` hashes.
    No name is in the code, the commit message ("Add four of Mike's
    characters to PROBERS") or the tests (the test character is "Made
    Name").
  - Known and unchanged since v1.4.0: the keys ship in every release, and
    anyone holding a candidate name (from the channel's member list, say)
    can hash it and see whether it is Mike's character. Inferred from
    `Drops:ProberKey`, which is plain FNV-1a.
  - `ns.SectionMemory` saves sets under `ns.CharacterKey()`
    ("Name-Realm") in the player's own SavedVariables. Shopping, Poisons
    and LootGrid already do the same. If Mike's SavedVariables are copied
    to the `data/watcher` branch whole, that copy holds his character names
    as before; it stays private.
  - Generated data in this range carries no finder or credit
    (grepped the diff). `credits.json` stays under `scraper/`, which
    `.pkgmeta` ignores. No credits file is in `NeedRoll/`.
- **Quest tooltips and the quest log.** These read only quest IDs and
  NeedRoll's own data. No text from other players is shown.
- **Scraper.**
  - `classspells.py` only changes a sort key. `seen.json` entries without a
    level are filtered out before it runs (`LEVEL_NOT_GIVEN`), so
    `item[1]["level"]` can't raise.
  - `catalog.py` adds static NPC IDs.
  - No new request to Wowhead; the test run's "Wowhead pages (retired,
    cache only)" line reads the cache only. QuestieDB is still read at
    build time (`KnownDrops.lua`'s source line names a commit).
  - No `shell=True`, `eval` or `pickle` added.
- **Workflows.** None changed.
- No `loadstring`, `RunScript` or `setfenv` anywhere in the diff.

## Round history

- Round 1, 2026-11-10, `b7d5379`: **Changes needed** (0 blocking, 1 should fix, 5 nits). Opened R1–R6.
- Round 2, 2026-11-10, `923b548`: **Ready** (0 blocking, 0 should fix, 2 nits open). Closed R1 and R3–R6; R2 left for Mike; opened R7.
