# Review: v1.9.0 release (everything merged into dev since v1.8.2)

| | |
| --- | --- |
| Branch | `v1.8.2..origin/dev` (`08e08497..b462bc40`, PRs #964–#979), plus the round 2 fixes `b462bc40..883f5605` on `claude/project-thread-zhqsnp` into `dev` |
| Commit reviewed | Round 1: `b462bc40`. Round 2: `883f5605` (nine fix commits on `b462bc40`; this doc is the only uncommitted file) |
| Date | 2026-11-19 |
| Round | 2 (last) |
| Verdict | **Ready** (0 blocking, 0 should fix, 2 nits open: R4 and R8 left for later by decision; R11 and R12 fixed after round 2) |
| Needs | Players: a **full game restart** (the round 2 fixes alone would need only `/reload`: no new file is loaded; `LICENSE.txt` isn't read by the game). The `.toc` gains the four embedded libraries (`Libs\LibStub`, `CallbackHandler-1.0`, `LibDataBroker-1.1`, `LibDBIcon-1.0`), `UI/UI.xml` gains `ProfessionBar.lua`, and `Media/Maps` gains twelve `BlackmawHold_*.tga` tiles; the game reads a new file list (and new files on disk) only at start-up (inferred, as in earlier reviews). SavedVariables: `NeedRollDB.minimap.angle` becomes `minimap.minimapPos` at the first login (`MoveMinimapAngle`, `Core/Init.lua:145`); the new module key `QUEST_LOG_BUTTON` is on unless switched off. |

## What the change does

Players see five things. The **Professions tab** is laid out anew (Mike's layout G): a bar of profession badges across the top (icon, name, skill, learned ones first), a filter sidebar on the left (the profession's Overview row, the slot chips as a two-column list with counts, the tick boxes, Cooking's Buff box and the skill range, scrolling when they don't fit), the recipe list (315 wide) with the Filter recipes box and a "26 recipes" count in its strip, and the recipe page. The old text-tab / counted-pill chip band and `/nr chipstyle` are gone; the text-tab chip stays for the map floor tabs and the Poisons page. The **minimap button** is now a LibDBIcon-1.0 button (four libraries embedded under `NeedRoll/Libs/`), restyled to keep NeedRoll's bronze-ring look, so minimap collectors manage it; the saved angle moves to LibDBIcon's `minimapPos`. **Library books** are searchable: the main search has a "Library Books" group whose result opens the Library tab on the book (with a Back pill), and the Library tab has its own search box. On the **world map**, NeedRoll's dice moves to the bottom left and the zone button to the bottom right. **Settings** gets "Open in NeedRoll in the quest log", which hides the quest log note and pill at once. Data: Blackmaw Hold's loot from Mike's saved zone page (the rare Mopes added) and Santiago Reyes's Blackmaw Hold map, Secrets of the Dreamers' spot, The Last Element Horde only, professions pruned to Mike's saved skill pages, three watcher imports. Tooling: the Smoke tests workflow runs only for release PRs into `main`, the dev-only Drop talk window gets one search box over every tab, and the scraper no longer adds a guessed drop that another encounter of the instance already lists.

## Scope

Addon (read in full around each hunk):

- `NeedRoll/NeedRoll.toc`: the four libraries before the locales.
- `NeedRoll/Libs/*` (third party, not ours to rewrite): checked only how they are embedded and called (load order, licences, combat safety), see R2 and R4. `Libs/README.md` (ours): versions and licences.
- `NeedRoll/Core/Init.lua`: `minimap` defaults as LibDBIcon's `minimapPos`, `MoveMinimapAngle` (`:145`), the `QUEST_LOG_BUTTON` module, `Modules:Set` refreshing the quest log note, `/nr chipstyle` removed.
- `NeedRoll/UI/MinimapButton.lua`: rewritten on LibDataBroker / LibDBIcon; `Restyle`, `NudgeLogoWhilePressed`.
- `NeedRoll/UI/ProfessionBar.lua` (new): the profession bar.
- `NeedRoll/UI/RecipeBand.lua`: the chip band replaced by the filter sidebar (`RB:CreateSidebar`, `ShowChips`, `ChipRow`, `ShowToggles`, `ShowBuffPicker`, `ShowRange`, `PlaceFlowing`, `RB:Layout`, `RB:Paint`); text-tab chips kept as `RB.Chip` / `RB.PlaceLines`.
- `NeedRoll/UI/Lists.lua`: `KnownProfessionsFirst` exported with the learned count; the Overview row moved onto the sidebar; `LayOutTop` simplified.
- `NeedRoll/UI/MainFrame.lua`: profession bar, sidebar and recipe filter placement (`PlaceSecondPane`, `RECIPE_FILTER`), the connector split into `PlaceSegment` / `PlaceElbow` / `PlaceTab` with no elbow on Professions, the Library's Back (`UI:ShowLibraryBook`, `UI:UpdateLibraryBack`, right-click back on the Library pane), `GoToResult` for books.
- `NeedRoll/UI/LibraryBooks.lua`: search box, `FoldStates` / `searchFolds`, `IsBookShown`, `MatchesQuery`, `ScrollToBook`, `page:ShowBook`, `page:FollowBack`.
- `NeedRoll/UI/Search.lua`: `FindLibraryBooks`, book items warmed, `SearchForm` / `Matches` exported.
- `NeedRoll/UI/LootGrid.lua`: `ResultPath`, `Cell:SetBook`, search rows for books.
- `NeedRoll/UI/QuestChainNotes.lua`: `QuestChainNotes.Refresh` honours the new switch.
- `NeedRoll/UI/Theme.lua`: `LabelToggle` gains `bar:Relabel` (`SetToggleWord`).
- `NeedRoll/UI/WorldMapMarkers.lua`, `WorldMapOverlay.lua`: the two map buttons swap corners and tooltip sides.
- `NeedRoll/UI/Overview.lua`, `Poisons.lua`, `Settings.lua`: `RB.Chip` without a style, the Blackmaw Hold floor name, comments.
- `NeedRoll/UI/DropTalk.lua` (dev only, `.pkgmeta` ignores it): one search box over every tab.
- `NeedRoll/UI/UI.xml`, `.luarc.json` (`LibStub`), `Locales/enUS.lua`, `Locales/NpcNames/Forever.lua` (Mopes).
- Hand-written data: `Data/LibraryBooks.lua` (one spot), `Data/Maps.lua` (Blackmaw Hold map, entrance, one pin), `Data/Dungeons/BlackmawHold.lua` (kept by hand per its header: loot from Mike's saved page, Mopes), `Media/Maps/CREDITS.txt`, the twelve tiles.

Scraper, tests, tools, docs:

- `scraper/needroll_scraper/observed.py` (`_listed_elsewhere`, `:464`) and its test; `scraper/professions/blacklist.txt`, `scraper/quests/blacklist.txt`, `forever.json`, `new-instances/BlackmawHold.txt` (inputs).
- `tests/smoke/*`: `wow.lua` (`W.OnlyDropOf`, `securecallfunction`, `SetToFinalAlpha`), `scenarios.lua`, `locale.lua`, `check.sh`, `README.md`, and the module scenarios for ProfessionBar, RecipeBand, MinimapButton, LibraryBooks, MainFrame, QuestChainNotes, DropTalk, Core-Init and others.
- `.github/workflows/smoke-tests.yml`, `CLAUDE.md`, `.claude/agents/implementer.md`, `README.md`, `scraper/README.md`, `tools/locale_strings.py`, `docs/STYLE-GUIDE.md`.

Skipped as generated (built by `scraper/needroll_scraper`): `Data/Abilities.lua`, `Chains.lua`, `ClassQuests.lua`, `ClassSpells.lua`, `KnownDrops.lua`, `KnownQuests.lua`, `KnownVendorRecipes.lua`, `Quests.lua`, `RecipeSources.lua`, `RecipeTrainers.lua`, `VendorItems.lua`, `Data/Professions/*.lua`, every other `Data/Dungeons/*.lua`, and the watcher's JSON under `scraper/` (bot PRs #967/#969/#975). No hand edit to a generated file was found: the profession prune went through `scraper/professions/blacklist.txt` (#972) and The Last Element through `scraper/quests/blacklist.txt` (#966). `NeedRoll/Data/Hotfixes.lua` did not change in the round 1 range.

Round 2 (`b462bc40..883f5605`, nine commits), each changed function re-read in full:

- `NeedRoll/UI/RecipeBand.lua` (`fbc982b0`, `8a2acc48`): `RangeWords` reads `L["%s to %s"]`; `BuildRange` takes its heading from `L["Required skill"]` and puts any words before the first box on the line; `ShowRange` shows the heading unconditionally; `CHIP_WORD_SCALE`.
- `NeedRoll/Locales/enUS.lua` (`fbc982b0`): `L["Required skill %s to %s"]` replaced by `L["Required skill"]`.
- `NeedRoll/Libs/LibDBIcon-1.0/LICENSE.txt` (new) and `Libs/README.md` (`95292a87`).
- `.github/workflows/smoke-tests.yml`, `lua-check.yml` (`53975b53`): top-level `permissions: contents: read`.
- `NeedRoll/UI/LootGrid.lua` (`dadd6c4c`, `8a2acc48`): `ns.UI.HasSkillLine`; `QUESTION_ICON`.
- `NeedRoll/UI/ProfessionBar.lua` (`dadd6c4c`, `e7405699`, `8a2acc48`): `badge.isNotLearned`, the tooltip's `elseif`, `needsLayout` with an `OnShow` hook, `BADGE.ICON_INSET`, `BADGE.UNDERLINE_MARGIN`, `NO_PROFESSIONS`.
- `NeedRoll/UI/LibraryBooks.lua` (`4be20a31`): `page:TakeQuery` split out of `page:SetQuery`; `page:ShowBook` empties the box quietly and refreshes once.
- `NeedRoll/UI/Theme.lua`, `UI/MainFrame.lua` (`4be20a31`): MainFrame's local `SetTextQuietly` became `Theme:SetSearchTextQuietly`, its four callers moved.
- `NeedRoll/Data/Hotfixes.lua` (`883f5605`): `checked = "2026-11-19"` only (hand-kept file, not generated).
- `docs/STYLE-GUIDE.md`: the Required skill, badge, tooltip, click and chip rows follow the fixes.
- Tests: `UI-RecipeBand.lua` (a new scenario that runs on every client, the wrap scenario finding the word between the boxes by position), `UI-ProfessionBar.lua` (hidden-bar catch-up, Camping), `UI-LibraryBooks.lua` (one draw on ShowBook), `Core-Tooltip.lua` (wrapped line).

## Checks

### Round 2 (`883f5605`)

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 12 Lua files the fix commits change | passed |
| `luacheck --no-global -q`, each changed file against its `b462bc40` version | no new warnings: LibraryBooks 1/1, LootGrid 1/1, MainFrame 5/5, ProfessionBar 1/1, RecipeBand 18/18, Theme 77/77, MinimapButton 2/2, test modules equal; Core-Tooltip 2 to 1 |
| Line length, tabs, CRLF on the added lines | none over 120, no tabs, LF only |
| `tests/smoke/check.sh` (dev, packaged, secret values, combat) | passed, all four runs ("all passed"; 242 / 233 files loaded) |
| `--combat` run | passed (part of the run above) |
| `tests/smoke/check.sh --locale all` | passed on all ten translated clients (126 English-only scenarios skipped each, as before). The new "the range heading is its own phrase" scenario and the "long range phrase wraps" scenario both run and pass on ruRU (checked by name), as do the four ProfessionBar scenarios |
| `python3 tools/locales.py --check` | passed |
| `python3 tools/translations.py` | passed (exit 0); now 7 phrases per language no longer used, the six from round 1 plus `Required skill %s to %s` |
| `python3 tools/locale_strings.py --check` | passed |
| `python3 tools/font_coverage.py --check` | passed |
| `python3 tools/hotfixes.py --check` | passed ("all fine (323 entries, days: 8)") |
| `python3 tools/hotfixes.py --fetch` (compare with Blizzard's post, no `--write`) | not run: the forum is blocked from this environment ("agent proxy: no rule or network setting allows this host"). `883f5605`'s "checked 2026-11-19, nothing new" is taken as the implementer's word |
| `cd scraper && python3 -m unittest discover -s tests` | passed, 538 tests (no scraper change in round 2; run anyway) |

### Round 1 (`b462bc40`)

| Check | Result |
| --- | --- |
| `luac5.1 -p` on every changed Lua file (addon, libraries, tests) | passed (Lua 5.1.5 installed for this review) |
| `luacheck --no-global -q`, changed files against their `v1.8.2` versions | 2 new warnings, both small (R10): `UI/MinimapButton.lua:118` unused argument `self`; `UI/Theme.lua` one more `self` shadowing in `LabelToggle` (`bar:Relabel`, `:2207`). Every other changed file: same count or fewer. The libraries' own warnings (60) aren't ours |
| `luacheck --only 111 112` (globals set) on the changed addon files | no new globals; only the long-standing `NeedRollDB`, `SLASH_*`, `BINDING_*`, `NeedRoll_OnCompartment*` |
| `tests/smoke/check.sh` (dev, packaged, secret values, combat) | passed, all four runs ("all passed"; 242 / 233 files loaded) |
| `--combat` run | passed (part of the run above) |
| `tests/smoke/check.sh --locale all` | passed, all 11 client languages |
| `python3 tools/locales.py --check` | passed |
| `python3 tools/translations.py` | passed (exit 0); reports 6 phrases per language no longer used (`Materials in bags and bank`, `Materials in bags`, `Skill %d+`, `Skill up to %d`, `%s · %s`, `%s · %d of %d recipes`), as expected after the chip band went |
| `python3 tools/locale_strings.py --check` | passed |
| `python3 tools/font_coverage.py --check` | passed |
| `python3 tools/hotfixes.py --check` | passed (323 entries) |
| `cd scraper && python3 -m unittest discover -s tests` | passed, 538 tests ("Wowhead pages (retired, cache only)": no request made) |

## Round 2: the fixes

Every fix commit was read in full, and every function it touched re-read whole (not only the changed lines), with its callers. Each round 1 finding against the new code:

**R1 holds as fixed, and the implementer's choices are right.**
- *Heading.* `BuildRange` (`RecipeBand.lua:1245-1265`) now makes the heading from `L["Required skill"]`, the way the other sections' headings ("Slot", "Show", "Buff") are made, so no client can show a preposition in it. `range.heading` is always made, so `ShowRange`'s `if range.heading then` guard went with it (`:1301`): right, not a lost guard.
- *Line.* `RangeWords` (`:1217-1222`) splits `L["%s to %s"]`, and `BuildRange` now puts the words before the first box on the line (`AddWords(before)`), so ruRU reads "От [ ] до [ ]", frFR "De [ ] à [ ]", koKR "[ ]부터 [ ]까지", zhCN "[ ]至[ ]", deDE "[ ] bis [ ]" (`grep '^L\["%s to %s"\]' NeedRoll/Locales/*.lua`: all ten languages have it). Every one of the ten splits into words round two boxes; none leaves a dangling word.
- *Reusing `L["%s to %s"]`.* Right. Questlines uses it for "first quest to last quest" (`Questlines.lua:488-493`), a from-to range at the start of a line, the same grammar as the skill range; reusing it gives the line a translation on every client today, where a new phrase would have shown English on ten. The cost is that a translator who reworks the phrase for quest names changes the range too; for a plain "from X to Y" that is what both want. `enUS.lua` lists it under `-- UI/Questlines.lua` only; `locales.py --check` accepts that, so it is the tool's layout, not a finding.
- *No old-split fallback.* Right. A fallback would have split `L["Required skill %s to %s"]` for the heading on languages without the new phrase, which is exactly the bug on six of them, and it would be code kept only until the next Locales PR (`docs/READABLE-CODE.md`: less code). One correction to the implementer's note: it isn't only German, Korean and Chinese. No translation has `L["Required skill"]` yet (`grep '^L\["Required skill"\]' NeedRoll/Locales/*.lua` finds only `enUS.lua:1338`), so all ten show the English heading until translated. It is one of 13 v1.9.0 phrases missing in every language (`comm` of the key lists, frFR/deDE/ruRU: 13 each, among them "Search books", "Show", "Type", "Skill %d/%d", "Open in NeedRoll in the quest log"). Translating them in the Locales PR before the tag is the normal release step, not a code finding.
- *Test.* The new scenario "the range heading is its own phrase, the line's words sit round the boxes" (`UI-RecipeBand.lua:907`) is not in `locale.lua`'s skip list and passes on all ten clients, so the bug round 1 found can no longer hide behind `EXPECTS_ENGLISH`. Its `gsub("%s+", "")` strips whitespace (the Lua class), not the literal `%s`, so it compares "%sto%s" with "%sto%s": right. The wrap scenario now finds the word between the boxes by position instead of `range.words[1]`, which was the word *before* the boxes on ruRU.
- *Style guide.* The Required skill row (`docs/STYLE-GUIDE.md:373`) describes the two phrases. New nit R12 on its Russian example.

**R2 holds as fixed.** `NeedRoll/Libs/LibDBIcon-1.0/LICENSE.txt` is byte-identical to `CallbackHandler-1.0/LICENSE.txt` (`diff`: no output), which is the Ace3 text the CurseForge licence page gives. `.pkgmeta` ignores nothing under `NeedRoll/Libs`, so it ships in the zip. The README row names the file.

**R3 holds as fixed.** Both `smoke-tests.yml` and `lua-check.yml` have a top-level `permissions: contents: read` with a comment saying why. Every workflow in `.github/workflows/` now has an explicit `permissions:` block (grep).

**R5 holds as fixed.** `ns.UI.HasSkillLine` (`LootGrid.lua:472-476`) is true for a list with a `SKILL_LINE_IDS` entry or a `skillLine` (the rogue's Poisons), false for Camping. The tooltip shows "Not learned" only `elseif HasSkillLine` (`ProfessionBar.lua:50`), and the name is muted only for `badge.isNotLearned` (`:64`, `:143`). `isNotLearned` is the right name now: Camping is neither learned nor not learned, so the old `isLearned` couldn't express it. Camping still sorts after the divider (`Lists.lua:619-633`, block 3) but in `text`, which the style guide's Name row now says. New scenario lines check both colour and tooltip. New nit R11 on the duplicated lookup.

**R6 holds as fixed.** `page:ShowBook` (`LibraryBooks.lua:1148-1159`) clears the box with `Theme:SetSearchTextQuietly` and takes the empty query through the new `page:TakeQuery`, so `Refresh` runs once. `TakeQuery` returns whether the query changed and `SetQuery` refreshes only then, the same behaviour as before for typing. The one `Refresh` still sees `scrollToLevel` set when a search was emptied, so it scrolls to the level first and `ScrollToBook` then overrides the offset: one redraw, two `SetData` calls on the column, and the order no longer matters. The new scenario counts draws (exactly 1). Moving the helper to Theme is right: `Theme.SetSearchTextQuietly(_, box, text)` follows the file's existing pattern for a method that needs no `self` (`Theme.WindowName`, `Theme.IsSkinAvailable`, `Theme.lua:638`, `:643`), both search box kinds honour `box.quiet` (`Theme.lua:1791`, `:1849`), the `Theme:SearchBox` comment points to it, and no copy is left in `NeedRoll/` (`grep '\.quiet = '`). Three smoke tests still set `ui.search.quiet` by hand (`UI-MainFrame.lua:663-665`, `:683-685`; `UI-Theme.lua:159-161`, which tests the flag itself); test code, older than this range, so noted only.

**R7 holds as fixed, and the OnShow hook is the better choice.** The `SKILL_LINES_CHANGED` handler (`ProfessionBar.lua:235-243`) lays the bar out only while `bar:IsVisible()`, else sets `needsLayout`; `bar:HookScript("OnShow", ...)` (`:225-227`) catches up, and `SetData` clears the flag (`:211`). Keeping it inside `ProfessionBar.lua` means the bar needs nothing from `UI:Refresh`, which round 1 suggested but which would have tied the flag to MainFrame. It works because the game fires `OnShow` on a shown child when an ancestor shows (the window opening) as well as on `SetShown(true)` (the tab switch, `MainFrame.lua:2404`); inferred from the game's documented behaviour. The smoke stand-in doesn't propagate `OnShow`, so the scenario fires it by hand (its comment says so): the test proves the catch-up, not the propagation. On a tab switch `SetData` runs first (`MainFrame.lua:1779`), clearing the flag, so the bar isn't laid out twice. `HookScript`, `IsVisible` and `SKILL_LINES_CHANGED` are in the `forever` lists (WidgetAPI.lua, Events.lua).

**R9 holds as fixed.** `QUESTION_ICON` (`LootGrid.lua:26`, both uses), `CHIP_WORD_SCALE` (`RecipeBand.lua:860`, both chips), `BADGE.ICON_INSET`, `BADGE.UNDERLINE_MARGIN`, `NO_PROFESSIONS` with comments; the style guide names them. The question mark is still named per file elsewhere (`Lists.lua:526`, `LibraryBooks.lua:53` as `QUESTION_ICON`, `HunterPets.lua:50` `UNKNOWN_ICON`, `DropTalk.lua:34` `BLANK_ICON`, `Fished.lua:95` bare): older than this range and outside the finding, so a later cleanup (one `Theme.QUESTION_ICON`), not a round 2 finding.

**R10 holds as fixed** for the test line (`Core-Tooltip.lua:143-144`, now two lines). The two warnings stay as the fix proposed (see its status).

**R4, R8** were not touched and stay open by decision.

**Hotfixes.** `883f5605` sets `checked = "2026-11-19"` and nothing else; `hotfixes.py --check` passes. This review could not re-read the forum (Checks), so whether the post has new entries rests on the implementer's check.

**Did the fixes bring anything new?** Two nits (R11, R12). No new game call, global, event registration, combat-blocked call, locale-dependent text match, or untrusted input. `luacheck` counts are unchanged, all four smoke runs and the ten Locale runs pass.

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | WoW API (every client's language) | `NeedRoll/UI/RecipeBand.lua:1217-1222`, `:1245-1265` | The Required skill heading keeps the "from" word in six languages | fixed in round 2 (`fbc982b0`) |
| R2 | should fix | Security (what release zips ship) | `NeedRoll/Libs/LibDBIcon-1.0/LICENSE.txt`, `NeedRoll/Libs/README.md:13` | LibDBIcon-1.0 ships without its Ace3-style BSD licence text | fixed in round 2 (`95292a87`) |
| R3 | should fix | Security (workflows) | `.github/workflows/smoke-tests.yml:24-27`, `lua-check.yml:13-15` | The rewritten Smoke tests workflow runs PR code with the default token permissions | fixed in round 2 (`53975b53`) |
| R4 | nit | Redundant code / WoW API | `NeedRoll/UI/MinimapButton.lua:63-99` | Restyle reaches into LibDBIcon's textures where LibDBIcon has public setters | open: left for later by decision |
| R5 | nit | Readability (§9) | `NeedRoll/UI/ProfessionBar.lua:42-56`, `:143`; `UI/LootGrid.lua:472-476` | Camping's badge says "Not learned", a skill no character learns | fixed in round 2 (`dadd6c4c`) |
| R6 | nit | Redundant code | `NeedRoll/UI/LibraryBooks.lua:1124-1159`; `UI/Theme.lua:1859-1864` | Opening a book from search can redraw the Library twice | fixed in round 2 (`4be20a31`) |
| R7 | nit | Redundant code | `NeedRoll/UI/ProfessionBar.lua:210-214`, `:225-227`, `:231-243` | Every skill change re-lays the whole profession bar, even while it is hidden | fixed in round 2 (`e7405699`) |
| R8 | nit | Readability (§6) / Redundant code | `NeedRoll/UI/RecipeBand.lua:1616`, `:1640` (round 2 lines); `UI/Settings.lua:811-840` | The sidebar borrows the Settings page's private scroller | open: left for later by decision |
| R9 | nit | Readability (§7) | `NeedRoll/UI/LootGrid.lua:26`; `UI/RecipeBand.lua:860`; `UI/ProfessionBar.lua:17`, `:22-23`, `:38` | Repeated or unexplained numbers in the new code | fixed in round 2 (`8a2acc48`) |
| R10 | nit | Readability (§2) | `NeedRoll/UI/MinimapButton.lua:118`; `UI/Theme.lua:2214`; `tests/smoke/modules/Core-Tooltip.lua:143-144` | Two new luacheck warnings and a 127-character test line | fixed in round 2 (`f53f577c`, the test line); the two warnings left as is: see the finding |
| R11 | nit | Redundant code | `NeedRoll/UI/LootGrid.lua:466`, `:475` | `HasSkillLine` repeats `SkillRanks`' skill line lookup | fixed after round 2 (`ddc04ee2`) |
| R12 | nit | Readability (§9) | `NeedRoll/UI/RecipeBand.lua:1214`; `tests/smoke/modules/UI-RecipeBand.lua:905`; `docs/STYLE-GUIDE.md:373` | The range comments quote Russian as "от %s до %s"; the phrase now used is "От %s до %s" | fixed after round 2 (`384fdc18`) |

### R1 · The Required skill heading keeps the "from" word in six languages

- **Severity:** should fix
- **Area:** WoW API (every client's language, root `CLAUDE.md`)
- **Where:** `NeedRoll/UI/RecipeBand.lua:1246-1252` (`BuildRange`), `:1216-1221` (`RangeWords`); `docs/STYLE-GUIDE.md` "Required skill" row
- **Status:** fixed in round 2 (`fbc982b0`). The heading is `L["Required skill"]` and the line is the existing `L["%s to %s"]`; no fallback to the old split. See "Round 2: the fixes"

**What's wrong.** The sidebar's range section takes its heading from one phrase split at its two `%s`:

```lua
local before, between, after = RangeWords()
before = Trimmed(before)
range.heading = before and NewHeading(band, before)
```

That works for English ("Required skill" / "[ ] to [ ]"), German ("Benötigte Fertigkeit" / "[ ] bis [ ]") and Korean, but in six of the ten translations the words before the first box end with the preposition that belongs to that box:

| Client | Translation | Heading shown | Line under it |
| --- | --- | --- | --- |
| ruRU | `Требуемый навык: от %s до %s` | "Требуемый навык: от" | "[ ] до [ ]" |
| frFR | `Compétence requise de %s à %s` | "Compétence requise de" | "[ ] à [ ]" |
| esES, esMX | `Habilidad requerida de %s a %s` | "Habilidad requerida de" | "[ ] a [ ]" |
| ptBR | `Perícia necessária de %s a %s` | "Perícia necessária de" | "[ ] a [ ]" |
| itIT | `Abilità richiesta da %s a %s` | "Abilità richiesta da" | "[ ] a [ ]" |

**Why it matters.** Before #973 the phrase was one line, "Compétence requise de [100] à [150]", which reads right. Now a French, Spanish, Portuguese, Italian or Russian player sees a gold section heading ending in a dangling "de" / "от" over the boxes. It is cosmetic, but it's on every profession with skill levels, on six clients.

**Evidence.** `grep '^L\["Required skill %s to %s"\]' NeedRoll/Locales/*.lua` (table above); code read at `:1216-1252`. The scenario that checks the sidebar order is skipped on non-English clients (`tests/smoke/locale.lua`, "the sidebar holds the Overview, then the chips, tick boxes and range, and scrolls" = `EXPECTS_ENGLISH`), so the Locale tests can't see it.

**Fix.** Give the heading its own phrase and the line its own: `L["Required skill"]` for the heading and `L["%s to %s"]` (split as now, words between and after the boxes) for the line, so a translator writes "от %s до %s" on the line. Until a language has the new line phrase, fall back to today's split. Update the style guide row.

### R2 · LibDBIcon-1.0 ships without its licence text

- **Severity:** should fix
- **Area:** Security (what release zips ship)
- **Where:** `NeedRoll/Libs/LibDBIcon-1.0/` (only `LibDBIcon-1.0.lua`); `NeedRoll/Libs/README.md:13`
- **Status:** fixed in round 2 (`95292a87`)

**What's wrong.** `Libs/README.md` says LibDBIcon-1.0 is "Ace3 Style BSD" and "no licence file ships with it". That licence's first condition is "Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer", and `.pkgmeta` ships `NeedRoll/Libs` in every CurseForge zip.

**Why it matters.** Each release redistributes LibDBIcon's source without the notice its licence requires. CallbackHandler-1.0, under the same Ace3 text, does ship `LICENSE.txt`; LibStub is public domain (its header says so); LibDataBroker has no licence to ship.

**Evidence.** `ls NeedRoll/Libs/LibDBIcon-1.0/` lists only the `.lua`. The project's licence page (curseforge.com/wow/addons/libdbicon-1-0/license, linked from the README's own URL) gives the text: "Copyright (c) 2007, Ace3 Development Team ... Redistributions of source code must retain the above copyright notice, ...". It matches `NeedRoll/Libs/CallbackHandler-1.0/LICENSE.txt`.

**Fix.** Add `NeedRoll/Libs/LibDBIcon-1.0/LICENSE.txt` with that text (a copy of CallbackHandler's file, which is the same Ace3 licence, works) and change the README row to "Ace3's BSD-style licence, `LibDBIcon-1.0/LICENSE.txt`".

### R3 · The Smoke tests workflow runs PR code with the default token permissions

- **Severity:** should fix
- **Area:** Security (GitHub Actions)
- **Where:** `.github/workflows/smoke-tests.yml:20-25`
- **Status:** fixed in round 2 (`53975b53`), in both workflows

**What's wrong.** #965 rewrote the workflow's trigger and job, but it still has no `permissions:` block. Its job checks out the pull request and runs `tests/smoke/check.sh`, which is code from the PR branch.

**Why it matters.** Without `permissions:`, `GITHUB_TOKEN` gets the repository's default, which can be read and write. A pull request from a branch in the repository (every PR here) then runs its own scripts with a token that can push or edit issues. The job only needs to read the checkout. The gap was already there before, but the rewrite was the chance to close it, and the checklist asks for least privilege.

**Evidence.** The whole file read: no `permissions:` key; the trigger is `pull_request` plus `workflow_dispatch`, with no `pull_request_target`, and nothing from `github.event.*` reaches `run:`. Both are fine. `lua-check.yml` has the same gap (inferred: not changed in this range).

**Fix.**

```yaml
permissions:
  contents: read
```

at the top level (and the same in `lua-check.yml` while there).

### R4 · Restyle reaches into LibDBIcon's textures where LibDBIcon has public setters

- **Severity:** nit
- **Area:** Redundant code / WoW API (embedded library use)
- **Where:** `NeedRoll/UI/MinimapButton.lua:63-70` (`NudgeLogoWhilePressed`), `:77-99` (`MinimapButton:Restyle`)
- **Status:** open: deliberately left for later (implementer's note, round 2). After two rounds Mike decides (root `CLAUDE.md`). Not a release risk with the v57 the zip ships; the risk is a newer copy from another addon (inferred, as in round 1)

**What's wrong.** `Restyle` sets `button.border`, `button.background` and `button.icon` directly and replaces `button.icon.UpdateCoord`. LibDBIcon v57 has public calls for most of this: `LibDBIcon:SetButtonBorder(name, texture, size, point, x, y)`, `SetButtonBackground(...)`, `RemoveButtonBackground(name)`, `SetButtonIcon(name, texture, size, point, x, y)` (`Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua:509-598`).

**Why it matters.** LibStub loads the highest LibDBIcon any addon ships. If another addon brings a later version that renames those fields, `Restyle` fails at `PLAYER_LOGIN` ("attempt to index a nil value") and the button keeps LibDBIcon's look. Inferred: the fields have been stable for years. The public calls also tell skinning addons what NeedRoll changed. The override of `UpdateCoord` and the bronze ring's `SetAtlas` have no public call and need to stay.

**Evidence.** Library source read at the lines above; `createButton` (`:251-300`) shows the fields and `icon.UpdateCoord = updateCoord`.

**Fix.** Use `SetButtonBorder(LAUNCHER_NAME, GOLD_RING, GOLD.ringSize, "TOPLEFT")`, `SetButtonBackground(LAUNCHER_NAME, DARK_DISC, GOLD.discSize, "CENTER")` and `RemoveButtonBackground(LAUNCHER_NAME)` for the gold and bronze looks. Keep `SetAtlas` for the bronze ring and the `UpdateCoord` override. Guard `Restyle` with `if not (button and button.icon and button.border) then return end`.

### R5 · Camping's badge says "Not learned"

- **Severity:** nit
- **Area:** Readability (§9, disinformation in what the player reads)
- **Where:** `NeedRoll/UI/ProfessionBar.lua:44-49` (`ShowBadgeTooltip`), `:58-60` (`PaintBadge`)
- **Status:** fixed in round 2 (`dadd6c4c`)

**What's wrong.** Every badge without a skill rank gets "Not learned" in its tooltip and a muted name. Camping has no skill line (`UI/LootGrid.lua:454-457` lists none), and `UI/Lists.lua:619-622` says "Camping isn't a skill the character learns".

**Why it matters.** Every character sees Camping as "Not learned" and greyed out, which suggests a trainer they can't find.

**Evidence.** `SkillRanks` (`UI/LootGrid.lua:464-468`) returns nil for a profession with no `SKILL_LINE_IDS` entry and no `skillLine`.

**Fix.** Leave out the line, and the muted look, for a list with no skill line, e.g. `local hasSkill = ns.UI.HasSkillLine(profession)` exported next to `SkillRanks`, and in the tooltip `elseif hasSkill then ... L["Not learned"]`.

### R6 · Opening a book from search can redraw the Library twice

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/LibraryBooks.lua:1141-1149` (`page:ShowBook`)
- **Status:** fixed in round 2 (`4be20a31`)

**What's wrong.** `ShowBook` starts with `self.searchBox:SetText("")`. When the box held text, that fires `onChange` → `page:SetQuery("")`, which runs `self:Refresh()` (`TakeStock`, the reward bar, every row). `ShowBook` then runs `self:Refresh()` again before `ScrollToBook`.

**Why it matters.** Two full redraws for one click. That's harmless today, but the first one also sets and uses up `scrollToLevel`, so whether `ShowBook` works depends on the order of the two refreshes.

**Evidence.** `page:SetQuery` at `:1128-1137`; `Theme:SearchBox` ("Text set while box.quiet is true doesn't call onChange", `UI/Theme.lua:1823`).

**Fix.** Clear the box quietly and reset the query by hand, then refresh once:

```lua
self.searchBox.quiet = true
self.searchBox:SetText("")
self.searchBox.quiet = false
self.query, self.queryText = nil, ""
wipe(self.searchFolds)
```

(MainFrame's `SetTextQuietly` does the first three lines; export it or move it to Theme.)

### R7 · Every skill change re-lays the whole profession bar, even while it is hidden

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/ProfessionBar.lua:225-228`
- **Status:** fixed in round 2 (`e7405699`), with an OnShow hook rather than `UI:Refresh`

**What's wrong.** On `SKILL_LINES_CHANGED` the handler calls `bar:SetData(bar.given)`, which sorts the professions and runs `Layout`: up to 13 badges, each with `FitName` (font object changes and string measuring). It does this whether or not the Professions tab is showing.

**Why it matters.** `SKILL_LINES_CHANGED` fires for weapon and defense skill-ups too, which come every few swings in combat on a low-level character. Each one re-lays a bar nobody is looking at. That's cheap, but it's work per event that belongs in a "dirty" flag (the addon caches everywhere).

**Evidence.** Handler read; `UI/Lists.lua:1141` handles the same event for the hidden profession list, and also only re-sorts when it has a list.

**Fix.** `if not bar:IsVisible() then bar.needsLayout = true return end`, and in `UI:Refresh` (where `professionBar:Paint()` runs) lay out first when `needsLayout` is set.

### R8 · The sidebar borrows the Settings page's private scroller

- **Severity:** nit
- **Area:** Readability (§6, one way of doing each thing) / Redundant code
- **Where:** `NeedRoll/UI/RecipeBand.lua:1617`, `:1641`; `NeedRoll/UI/Settings.lua:811-840`
- **Status:** open: deliberately left for later (implementer's note, round 2). After two rounds Mike decides (root `CLAUDE.md`). No player-visible effect

**What's wrong.** `RB:CreateSidebar` scrolls through `ns.Settings.AddScrolling` and `ns.Settings.ScrollPageTo`, helpers that live in the Settings page file (its comment now lists three users: Settings, Game hotfixes and the Professions sidebar). The scrolling helpers everything else uses live in Theme (`Theme:ScrollView`, `Theme:ScrollBar`, `Theme:ScrollColumn`).

**Why it matters.** A reader looking for "how does a pane scroll" finds three helpers in Theme and a fourth in Settings.lua that a recipe file reaches into. The recipe file also depends on a page file's internals (`page.offset`, `page.scroll`, `page.canvas`).

**Evidence.** Grep of `AddScrolling|ScrollPageTo` across `NeedRoll/UI`: Settings.lua and RecipeBand.lua only.

**Fix.** Move both into Theme as `Theme:ScrollPage(page)` / `Theme:ScrollPageTo(page, offset)` (same code), and call them from Settings and RecipeBand.

### R9 · Repeated or unexplained numbers in the new code

- **Severity:** nit
- **Area:** Readability (§7, searchable names)
- **Where:** `NeedRoll/UI/LootGrid.lua:446`, `:1746-1747`; `NeedRoll/UI/RecipeBand.lua:952`, `:1494`; `NeedRoll/UI/ProfessionBar.lua:36`, `:78`, `:147`
- **Status:** fixed in round 2 (`8a2acc48`)

**What's wrong.**
- `Cell:SetBook` writes the question-mark icon as `134400` with a comment, the second bare `134400` in LootGrid.lua (`:446`). LibraryBooks.lua names it `QUESTION_ICON` and DropTalk.lua `BLANK_ICON`.
- The chips' word scale `1.05` is written in both `Chip` (`:952`) and the new `ChipRow` (`:1494`). The style guide calls them the same size.
- ProfessionBar: `local NONE = {}` (`:36`) has no comment saying it is the bar's empty profession list. `BADGE.ICON - 2` (`:78`, the icon inside the ring) and `width - 8` (`:147`, "never wider than the badge less 8") are bare numbers, though the `BADGE` table names everything else.

**Why it matters.** A later change to one copy misses the other, and a grep for the name finds nothing.

**Fix.** A `QUESTION_ICON = 134400` local in LootGrid.lua used at both spots; `CHIP_WORD_SCALE = 1.05` in RecipeBand.lua; `BADGE.ICON_INSET = 1` and `BADGE.UNDERLINE_MARGIN = 4` (each side), and `local NO_PROFESSIONS = {} -- the bar's list before SetData`.

### R10 · Two new luacheck warnings and a 127-character test line

- **Severity:** nit
- **Area:** Readability (§2)
- **Where:** `NeedRoll/UI/MinimapButton.lua:118`; `NeedRoll/UI/Theme.lua:2207`; `tests/smoke/modules/Core-Tooltip.lua:143`
- **Status:** fixed in round 2 (`f53f577c`) for the test line. The two warnings left as is, as the fix proposed: `SetHidden` stays a method because its callers use `:` (`MinimapButton.lua:129`), and `bar:Relabel` matches `LabelToggle`'s other `bar:` methods

**What's wrong.** `MinimapButton:SetHidden(hide)` no longer uses `self` (luacheck 212). `bar:Relabel` adds one more shadowing of `LabelToggle`'s `self` (luacheck 432), like the `bar:` methods already there. Core-Tooltip.lua:143 is 127 characters, over the 120 limit for changed lines.

**Why it matters.** Only noise in the luacheck run the implementer is told to keep clean, and a long line.

**Evidence.** luacheck against the `v1.8.2` versions (Checks table); `awk` length check over the added lines.

**Fix.** `SetHidden` can stay a method (callers use `:`), so leave it as is, noting the reason. `Relabel` matches its neighbours, so leave it too. Wrap the test line.

### R11 · `HasSkillLine` repeats `SkillRanks`' skill line lookup

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/LootGrid.lua:466` (`SkillRanks`), `:475` (`ns.UI.HasSkillLine`)
- **Status:** open (new in round 2)

**What's wrong.** The R5 fix wrote the "which skill line is this list" rule a second time:

```lua
local skillLineID = SKILL_LINE_IDS[profession.id] or profession.skillLine   -- SkillRanks, :466
return (SKILL_LINE_IDS[profession.id] or profession.skillLine) ~= nil       -- HasSkillLine, :475
```

**Why it matters.** The two must agree: a badge is muted only when `HasSkillLine` says the list has a skill line and `SkillRanks` finds no rank on it. If a later list gets its skill line some other way (a new field, a hand-built list like Skinning's) and only one of the two lines is updated, a learned profession shows as "Not learned", or an unlearned one stops being muted. `docs/READABLE-CODE.md` §6: one way of doing each thing.

**Evidence.** Lines read; both are in the same file, eight lines apart.

**Fix.** One local both use:

```lua
-- The skill line a profession list (or the rogue's Poisons) is learned
-- as, or nil for one no character learns (Camping).
local function SkillLineID(profession)
    return SKILL_LINE_IDS[profession.id] or profession.skillLine
end
```

then `local skillLineID = SkillLineID(profession)` in `SkillRanks` and `return SkillLineID(profession) ~= nil` in `HasSkillLine`.

### R12 · The range comments quote Russian as "от %s до %s"

- **Severity:** nit
- **Area:** Readability (§9, comments that mislead)
- **Where:** `NeedRoll/UI/RecipeBand.lua:1214`; `tests/smoke/modules/UI-RecipeBand.lua:905`; `docs/STYLE-GUIDE.md:373` ("от [ ] до [ ]")
- **Status:** open (new in round 2)

**What's wrong.** All three quote the Russian line phrase in lower case, "от %s до %s", which was the tail of the old `L["Required skill %s to %s"]` translation. The phrase the code now reads is `L["%s to %s"] = "От %s до %s"` (`Locales/ruRU.lua:1259`), capitalised because it starts a line.

**Why it matters.** Small, but it is the example a translator or the next reader checks the code against; a grep for the quoted text finds only the dropped phrase.

**Evidence.** `grep -n 'от' NeedRoll/UI/RecipeBand.lua docs/STYLE-GUIDE.md tests/smoke/modules/UI-RecipeBand.lua`; `grep '^L\["%s to %s"\]' NeedRoll/Locales/ruRU.lua`.

**Fix.** Write "От %s до %s" (and "От [ ] до [ ]" in the style guide), or use a language-neutral example such as French "De %s à %s".

## Area notes

### Readability

Checked every changed function in the files under Scope against `docs/READABLE-CODE.md`. The new files and functions follow it closely. `ProfessionBar.lua` names its layout values in one `BADGE` table and splits its jobs (`ShowBadgeTooltip`, `PaintBadge`, `CreateBadge`, `FitName`, `ShowBadge`, `PlaceDivider`). `RecipeBand.lua` turned the band into small per-section functions (`StartSection`, `ShowChips`, `ShowToggles`, `ShowBuffPicker`, `ShowRange`, `PlaceFlowing`). `MainFrame.lua`'s 60-line `UpdateLink` is now `PlaceSegment` / `PlaceElbow` / `PlaceTab`. `LibraryBooks.lua` named its fold keys (`BracketFoldKey`, `ZoneFoldKey`, `FoldKeyOf`) and its show rules (`IsBookShown`, `MatchesQuery`, `FoldStates`). Comments explain the why (LibDBIcon calling `UpdateCoord` on press and drag, the Buff menu hanging from the sidebar so the scroll frame doesn't clip it, `searchFolds` keeping a search from changing remembered folds). No narration ("now", "updated") in the code comments, and none were left stale: `chipstyle`, `RB.style`, counted pills and `NeedRollMinimapButton` are gone from every `.lua` and `.md` outside the changelogs and old reviews. Guard clauses are used throughout and no new function nests past three levels. `local _, ns = ...` heads `ProfessionBar.lua`. LF endings and no tabs in our files (the libraries keep their own tabs). All text searches use plain `find(query, 1, true)` (`Search.lua`, `LibraryBooks.lua`, `DropTalk.lua`), so typed `%`, `-`, `.`, `[` can't act as patterns. No `cond and nil or x` and no `#` over holes in the new code. `scraper/needroll_scraper/observed.py` `_listed_elsewhere` is small, documented in the module docstring and tested.

Round 2: every function the fix commits touched re-read whole (`RangeWords`, `Trimmed`, `RangeWord`, `BuildRange`, `ShowRange`, `ShowBadgeTooltip`, `PaintBadge`, `CreateBadge`, `ShowBadge`, `CreateProfessionBar` and its `SetData` / `Layout` / `Paint` / hooks, the `SKILL_LINES_CHANGED` handler, `SkillRanks`, `HasSkillLine`, `page:TakeQuery` / `SetQuery` / `ShowBook` / `Refresh`, `ScrollToBook`, `Theme:SearchBox`, `Theme.SetSearchTextQuietly`, and the four MainFrame callers). Names fit: `TakeQuery` says it only takes the query and its comment says the caller refreshes; `isNotLearned` is a yes/no question; `NO_PROFESSIONS`, `QUESTION_ICON`, `CHIP_WORD_SCALE`, `ICON_INSET`, `UNDERLINE_MARGIN` each have a comment. The `SKILL_LINES_CHANGED` handler went from one line to a guard clause and an if/else, two levels. Comments say why (the event fires on weapon skill-ups in combat; the box is emptied quietly so the page draws once) without narrating the change. `PaintBadge`'s `isOpen and heading or isNotLearned and muted or text` has no `and nil or` trap (no branch value can be nil or false). No line over 120, no tabs, LF only. New findings: R11 (the lookup written twice), R12 (a quoted example that no longer matches).

### WoW API

Every game call, event, widget method and atlas the range adds or newly calls in NeedRoll's own code, checked against Ketho's BlizzardInterfaceResources `forever` branch (`GlobalAPI.lua`, `Events.lua`, `WidgetAPI.lua`, `AtlasInfo.lua`, `FrameXML.lua`, downloaded 2026-11-19 and grepped):

| Used | Kind | In `forever` lists | Where looked |
| --- | --- | --- | --- |
| `C_Item.GetItemIconByID` (Cell:SetBook) | function | yes | GlobalAPI.lua |
| `C_Item.GetItemNameByID`, `C_Item.GetItemInfo` (search, Drop talk) | function | yes | GlobalAPI.lua |
| `C_Texture.GetAtlasInfo` (Restyle) | function | yes | GlobalAPI.lua |
| `C_SkillInfo.GetSkillLineInfoByID` (badges, via SkillRanks) | function | yes | GlobalAPI.lua |
| `C_Spell.GetSpellTexture` (badge icons, via ProfessionIcon) | function | yes | GlobalAPI.lua |
| `GetCursorPosition`, `securecallfunction` (LibDBIcon, CallbackHandler; mirrored in `wow.lua`) | function | yes | GlobalAPI.lua |
| `GetMinimapShape` (LibDBIcon, guarded `GetMinimapShape and GetMinimapShape()`) | function | no (an addon-defined global, nil-guarded) | GlobalAPI.lua |
| `QuestMapFrame_ShowQuestDetails` (hooked, already) | FrameXML function | yes | FrameXML.lua |
| `GameTooltip_Hide` | FrameXML function | yes | FrameXML.lua |
| `SKILL_LINES_CHANGED` (profession bar) | event | yes | Events.lua |
| `GLOBAL_MOUSE_UP` (Library right-click Back, existing frame) | event | yes | Events.lua |
| `PLAYER_LOGIN`, `ADDON_LOADED` | event | yes | Events.lua |
| `GetUnboundedStringWidth`, `SetDesaturated`, `SetVertexColor`, `SetAtlas`, `SetTexCoord`, `SetFixedFrameLevel`, `LockHighlight`, `SetHighlightTexture`, `GetEffectiveScale`, `RegisterForClicks`, `CreateAnimationGroup`, `SetToFinalAlpha` | widget methods | yes | WidgetAPI.lua |
| `Mode-Selection-Ring-c60` (badge ring) | atlas | yes | AtlasInfo.lua |
| `questlog-questtypeicon-dungeon` (new Settings row) | atlas | yes | AtlasInfo.lua |
| `UI-HUD-Minimap-Frame-Cycle` (bronze ring) | atlas | yes | AtlasInfo.lua |
| `QuestNormal`, `lootroll-toast-icon-need-up` (map buttons, unchanged) | atlas | yes | AtlasInfo.lua |
| `ANCHOR_BOTTOM`, `ANCHOR_LEFT`, `ANCHOR_RIGHT` | tooltip anchors | inferred (standard `GameTooltip:SetOwner` anchors, used before) | — |
| `LibStub`, LibDataBroker `NewDataObject`, LibDBIcon `Register` / `IsRegistered` / `GetMinimapButton` / `Show` / `Hide` | embedded library | inferred (library source read, v57) | `NeedRoll/Libs` |

Round 2 adds no game function, event or atlas. It newly calls, in NeedRoll's own code (Ketho's `forever` `WidgetAPI.lua` and `Events.lua` downloaded again 2026-11-19 and grepped):

| Used (round 2) | Kind | In `forever` lists | Where looked |
| --- | --- | --- | --- |
| `bar:HookScript("OnShow", ...)` (profession bar catch-up) | widget method | yes (`HookScript`) | WidgetAPI.lua |
| `OnShow` firing on a child when its window shows | script behaviour | inferred (the game's documented `OnShow`; the stand-in doesn't propagate it, so the scenario fires it by hand) | — |
| `bar:IsVisible()` (`SKILL_LINES_CHANGED` handler) | widget method | yes | WidgetAPI.lua |
| `EditBox:SetText`, `ClearFocus` (`Theme:SetSearchTextQuietly`, `ShowBook`) | widget methods | yes | WidgetAPI.lua |
| `SKILL_LINES_CHANGED` (unchanged registration) | event | yes | Events.lua |

Round 2 other checks: no new globals (`Theme.SetSearchTextQuietly` is a field on `ns.Theme`); no new event registration (the handler only does less work); nothing combat-blocked (the four calls appear in no added line, `CHECKED_COMBAT_CALLS` unchanged, the `--combat` run passed), and the hidden bar now skips work in combat rather than adding any; every client's language: R1's line now reads right on all ten translations and a scenario checks it on each, the heading needs its translation like the other 12 new phrases; `wow.lua` needed nothing new (no new game call); the style guide follows every UI change of round 2.

Other checks:
- **Async data:** book icons fall back to the question mark until the item loads. Book names go through `Search.lua`'s warm list (`ns.Items:Load`, `OnNameLoaded`), and the Library search falls back to the data's English name. Drop talk asks for missing items with `list:LoadItem`. No polling loops.
- **Events:** the profession bar registers only `SKILL_LINES_CHANGED` (through `ns:On`). Nothing one-shot was added.
- **Secret values:** no new comparisons on tooltip names, quest titles or widths. `QuestChainNotes.Dungeons` keeps its `issecretvalue` guard and `Refresh` passes it the plain quest ID the hook received.
- **Globals and limits:** no new globals in NeedRoll's code (luacheck 111/112). `.luarc.json` gains only `LibStub`, which the libraries define. The libraries create `LibDBIconTooltip` and `LibDBIcon10_NeedRoll`, standard for LibDBIcon. `luac5.1 -p` passes, so no function went over 60 upvalues: `Overview.lua` `CreateOverview` gained none (only `FLOORS` and `NewLevelTab` changed), and `Lists.lua` `LayOutTop` dropped a parameter.
- **Combat:** the four calls blocked for every frame appear nowhere in the added lines, and `CHECKED_COMBAT_CALLS` did not change. The LibDBIcon button is a plain `Button` on `Minimap`, made at `PLAYER_LOGIN`, so show/hide and drag are allowed in combat. The profession bar, sidebar, Library Back and map buttons are plain frames. The `--combat` smoke run passed. No secure frame or protected function is touched.
- **Every client's language:** see R1. No English matched against game text. The new text goes through literal `L["..."]` and `locales.py --check` passes. New textures are NeedRoll's own `Media/Maps/BlackmawHold_*.tga`; the minimap ring's `MiniMap-TrackingBorder` and `UI-Minimap-Background` paths were used before and are what LibDBIcon itself loads by file ID. Separators: the new code joins with `Theme:JoinDots`. `font_coverage --check` and the 11 Locale runs pass.
- **Smoke stand-in:** `wow.lua` gains `securecallfunction` and `SetToFinalAlpha` (both in the `forever` lists) and no old global. New scenarios cover the profession bar (4), the sidebar and the Professions layout, the minimap button (3) and the angle move, Library search (2), the quest log switch and the Drop talk search.
- **Removed guards:** the only one is `GetMinimapShape and GetMinimapShape()`, which went with the old placement code (LibDBIcon keeps the guard).
- **Dev-only code:** `DropTalk.lua` stays in `.pkgmeta`'s ignore list and UI.xml's debug block. `/nr chipstyle` was removed rather than left.
- **Style guide:** updated in the range for the Professions tab (bar, sidebar, filter, count), the minimap button, both world map buttons and their tooltips, the Library strip's search box and Back, Library book search results, the Label toggle's `Relabel`, the text tab chips and the new Settings row. Values match the code where spot-checked (236, 315, 30 ring, 6/2/3/2/4, 12/8 filter insets, 160 search box).
- **Library embedding:** the `.toc` loads LibStub, CallbackHandler-1.0, LibDataBroker-1.1, then LibDBIcon-1.0, before any NeedRoll file, which is the order each one's `LibStub` checks need. `tools/locale_strings.py` skips `Libs/`. Licences: R2.

### Redundant code

Compared against `Theme:SearchBox` (used by both new search boxes, not re-made), `Theme:LabelToggle` (Drop talk's tabs, extended with `Relabel` rather than copied), `Theme:CheckBox`, `Theme:Divider`, `Theme:Rounded`, `Theme:Menu`, `Theme:CreatePanel`, `Theme:CropIcon` / `MaskRound`, `Theme:LineHeight`, `Theme:ScaledFont`, `Theme:JoinDots`, `Theme:ScrollView` / `ScrollBar` / `ScrollColumn` (R8), `ns.SectionMemory` (the Library's search folds reuse its `IsOpen` / `Toggle`), `ns.Search.SearchForm` / `Matches` (exported so the Library tab matches text the same way as the main search, not a second matcher), `ns.UI.SkillRanks` and `ns.UI.ProfessionIcon` (reused by the bar), `KnownProfessionsFirst` (exported, not re-sorted), `CreateBackButton` (reused for the Library's Back), `ns.Literal` (Drop talk). The chip band's 330 removed lines (the counted pill style and its count-line text) went entirely, with their locale strings. Smaller items: R4, R6, R7, R9.

Round 2: `Theme:SetSearchTextQuietly` is now the one helper for setting a search box's text without its search (no copy left in `NeedRoll/`; three older smoke tests still set `quiet` by hand). `ns.UI.HasSkillLine` was checked against `SkillRanks` (R11), `QUESTION_ICON` against the other files' copies (noted under R9 in "Round 2: the fixes"), and the reused `L["%s to %s"]` against `Questlines.lua`'s use. `page:TakeQuery` is shared by `SetQuery` and `ShowBook`, not copied.

### Security

- **Untrusted input:** the Drop talk search reads logged addon messages and shows the no-match note through `ns.Literal`; its matching is plain `find`. The window is dev-only. No change to `Core/Drops.lua`, the `NRDT` channel, sending, the outbox or "Share drops".
- **Player text:** the Library's "No book matches" note shows the player's own typed text, not other players' (and the game's edit box doubles a typed `|`; inferred).
- **Names and credits:** nothing copies `scraper/drops/credits.json` or a character name into `NeedRoll/`. The only names added to the addon folder are the libraries' authors and Santiago Reyes's credit, which `CREDITS.txt` already carried with his permission. `credits.json` changed in the private repo only (watcher imports).
- **Wowhead and QuestieDB:** no request in any code path. Blackmaw Hold's and the professions' facts come from Mike's saved pages ("never fetched"), and the scraper tests ran cache-only.
- **Workflows:** R3. No secrets, no `pull_request_target`, no `${{ github.event.* }}` in `run:`.
- **Python:** `observed.py`'s change builds report text only. No `shell=True`, `eval`, `pickle` or paths from downloaded data.
- **Release contents:** R2.
- **Round 2:** touches no untrusted input or output. The workflow change (R3) only narrows the token; `LICENSE.txt` adds no name beyond the Ace3 Development Team. No Wowhead or QuestieDB request; the only network attempt was this review's own `hotfixes.py --fetch` to Blizzard's forum, which the environment blocked.

### Other root `CLAUDE.md` rules

- **Blizzard hotfixes, every release:** `NeedRoll/Data/Hotfixes.lua` was last updated by `3a38372c` (Blizzard's 2026-11-17 hotfixes, checked 2026-11-18), which is already in `v1.8.2`. The release still owes its own `tools/hotfixes.py` check before the changelog PR. Not a finding: nothing in the range is wrong, but no check for v1.9.0 has run yet. Round 2: `883f5605` records the check (`checked = "2026-11-19"`, no new entries); `--check` passes, the forum itself couldn't be reached from here.
- **Translations before the tag:** 13 phrases new in v1.9.0, `Required skill` among them, have no translation in any language; the Locales PR the implementer mentions should land before the tag.
- **Smoke tests in CI only for releases:** the workflow, `CLAUDE.md`, `tests/smoke/README.md`, `check.sh` and the implementer agent agree. `watcher-data.yml` (`:188-198`), `daily-data.yml` and `translations.yml` still run `check.sh` and post the status, as the comments say.
- **Changelogs:** the changelog PR comes after this review; nothing to check in the range.

## Round history

- 2026-11-19, round 1, `b462bc40`: **Changes needed** (0 blocking, 3 should fix, 7 nits). Opened R1–R10.
- 2026-11-19, round 2 (last), `883f5605`: **Ready** (0 blocking, 0 should fix, 4 nits open). Closed R1, R2, R3, R5, R6, R7, R9, R10 (fix commits `fbc982b0`, `95292a87`, `53975b53`, `dadd6c4c`, `4be20a31`, `e7405699`, `8a2acc48`, `f53f577c`). R4 and R8 open, left for later by decision. Opened R11, R12 (nits).
- 2026-11-19, after round 2: R11 fixed (`ddc04ee2`, a `SkillLineID` helper both functions call) and R12 fixed (`384fdc18`, comments, test comment and style guide quote "От %s до %s"). `tests/smoke/check.sh` passed again. No third round (two-round limit); both were nits with no behaviour change.
