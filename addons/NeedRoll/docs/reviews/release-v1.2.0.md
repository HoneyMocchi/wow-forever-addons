# Review: NeedRoll v1.2.0 (everything since v1.1.0)

| | |
| --- | --- |
| Branch | `v1.1.0..origin/dev` (PRs #807 to #812), then in round 2 the fixes on `claude/project-thread-2f9i1c`, into `dev` before the v1.2.0 changelog PR |
| Commit reviewed | Round 1: `31a2902` (`origin/dev`). Round 2: `ab63c01` (fixes `449f4d6`; `ab63c01` adds this doc). The whole range `v1.1.0..ab63c01` was read again. No uncommitted changes besides this doc. |
| Date | 2026-11-08 |
| Round | 2 (the last) |
| Verdict | **Ready** at round 2 (0 blocking, 0 should fix open, 2 nits open). Round 1 had 3 should fix and 9 nits: R1-R10 and R12 fixed, R11 left open for Mike. New in round 2: R13 (nit). |
| Needs | Full client restart, not just `/reload`: `Core/LibraryBooks.lua` and `Data/LibraryBooks.lua` are new files in `NeedRoll.toc`, and `UI/LibraryBooks.lua` is new in `UI/UI.xml`. The game only finds new files on disk at startup. |

## What the change does

**Library Books (#807, #810, #812).** A new **Library** tab sits right after Collections. It is its own module, so it can be turned off in Settings' Modules. The tab fills the window's body with one page, laid out like the Professions Overview (the pet pages' heading and rows, `ns.UI.PetPageKit`). The page lists the 40 library books of WoW: Forever: 38 for the Alliance and 39 for the Horde. Each book is handed in, one quest each, to the side's librarian (Garion Wendell in Stormwind, Owen Thadd in Undercity), and 10, 20 and 25 books unlock three reward quests.

- The strip holds the chips "All books" and "Still to find", the "Group by zone" box (remembered account-wide in `NeedRollDB.libraryByZone`), "Level N" and the side's crest.
- Under the heading: a reward bar (green for books handed in, yellow for books held, a notch at each reward), then the three reward quests as links.
- The list folds by level bracket by default, or by zone. Each book is an item link with where it sits, a map-pin link to its spot, and a status: Handed in, In bags, In bank (from the last bank visit, `ns.Shopping:BankCount`) or Not found.
- A book is "Handed in" once its hand-in quest is done (`C_QuestLog.IsQuestFlaggedCompleted`). For books whose quest the data doesn't know for a side, `Core/LibraryBooks.lua` learns it: a book that leaves the bags within 5 seconds of a quest turn-in is saved as handed in with that quest, account-wide by side (`NeedRollDB.libraryBookQuests`). Dev builds print what they learn.
- #807 put the page under Collections. #810 moved it to its own tab. #812 drew the fold's "2 ready" tag as a `Theme:Pill`.

**Window padlock (#808, #812).** A padlock left of the window's X, in both styles, drawn from strokes like the modern X. Locked (`NeedRollDB.window.locked`), a press on the header or the window's background no longer moves the window (`MakeDragHandle`); the resize grip still works. #812 raised it to the X's frame level, because the native title bar art drew over it.

**Data.** #809: combat log watcher data (`scraper/drops/*.json`, `scraper/quests/logged.json` and `reported.json`, `scraper/abilities/observed.json`, `scraper/classes/seen.json`, `scraper/professions/trainer_checks.json`), regenerated into `Data/Dungeons/*`, `KnownDrops.lua`, `KnownQuests.lua`, `ClassSpells.lua`, `ForeverAbilities.lua` and `Quests.lua`. #811: the Rebel Camp chain (203, 204, 205, 207) and "An Acquaintance in Southshore" (95786) come before two Alliance Drowned City quests (95787, 95788), seeded in `scraper/quests/forever.json`.

## Scope

All 34 changed files were listed. Every hunk was read with the code around it, and every new or changed function was read in full.

Addon, hand-written:
- `NeedRoll/Core/LibraryBooks.lua` (new, 170 lines): book statuses (`QuestOf`, `Status`, `IsHeld`, `ForSide`, `IsRewardDone`) and the hand-in quest learning (`CountCarried`, `IsKnownQuest`, `BookHandedIn`, `TryLearn`, `SavedSide`, the `QUEST_TURNED_IN` and `BAG_UPDATE_DELAYED` handlers).
- `NeedRoll/Data/LibraryBooks.lua` (new, 212 lines). **Hand-written, not generated.** Its header says so (`:4`), nothing in `scraper/` or `tools/` writes it (grep for `LibraryBooks` / `libraryBooks` in `*.py` and `*.ps1`: no hits), and it has no generated header. Reviewed in full as hand code (R10).
- `NeedRoll/UI/LibraryBooks.lua` (new, 977 lines): the whole page.
- `NeedRoll/UI/MainFrame.lua`: `WHOLE_BODY`, `WHOLE_BODY_ICONS`, `MakeDragHandle` (lock check), `LOCK`, `DrawLock`, `ShowLockTooltip`, `CreateLockButton` (new), `CreateTopBar`, `BuildWholeBodyTab`, `ShowSettingsPage`, `SKINNED`, `UI:Place`, `ShowWholeBodyTab`, `UI:Refresh`.
- `NeedRoll/Core/Init.lua`: `defaults.window.locked`, `defaults.libraryBookQuests`, the `libraryByZone` comment, the `LIBRARY_BOOKS` module.
- `NeedRoll/Core/Names.lua`: the librarians join the NPC names put in the player's language.
- `NeedRoll/Data/Data.lua`: `ns.Data:RegisterLibraryBooks` (new).
- `NeedRoll/NeedRoll.toc`, `NeedRoll/UI/UI.xml`: the three new files.
- `NeedRoll/Locales/enUS.lua`: 102 new phrases (108 added lines; 6 existing phrases moved next to the new ones, none reworded).

Generated, not reviewed for style: `Data/ClassSpells.lua`, `Data/Dungeons/{Deadmines,Gnomeregan,RazorfenKraul,WailingCaverns}.lua`, `Data/ForeverAbilities.lua`, `Data/KnownDrops.lua`, `Data/KnownQuests.lua`, `Data/Quests.lua`. No scraper code changed in the range (no `.py` file in the diff), so there was no generator to review. Only data inputs changed. `Data/Dungeons/KroldokStronghold.lua` is the hand-kept file from v1.1.0 (`scraper/README.md`: "builds now skip these instances"). #809's watcher import moved two loot lines in it, putting each boss's 100% drop first. Same entries, so no finding, but the watcher import does write into a file the README calls hand-kept.

Scraper data inputs: `scraper/quests/forever.json` (#811's `required`, `names`, `npc`/`turnInNpc`, `xp`, `money`), `scraper/drops/credits.json`, `items.json`, `observed.json`, the other JSON files listed above. JSON data is skipped for style. `credits.json` was checked for privacy (Security).

Smoke: `tests/smoke/modules/UI-LibraryBooks.lua` (new, 10 scenarios), `UI-MainFrame.lua` (TabIcon assert and the padlock scenario), `UI-DungeonQuestlines.lua` and `scenarios.lua` (the new tab in their tab lists).

Docs: `docs/STYLE-GUIDE.md` (Tab strip order, "Close and lock", the new "Library tab" section).

Round 2 (`31a2902..ab63c01`, 13 files). Every function in the range was read again in full, as it stands at `ab63c01`, not only the lines the fixes touched:
- `NeedRoll/Core/LibraryBooks.lua`: the learning is rewritten (`BooksGone`, `ReportNothingLearned`, `LearnFrom`, `TakeBooksGoneJustBefore`, `AwaitBagChange`, `OnQuestTurnedIn`, `OnBagChange`, `TrackWindow`), and the statuses use `ns.IsQuestDone`.
- `NeedRoll/UI/HunterPets.lua`: the new shared `PetPageKit` helpers (`:800-937`).
- `NeedRoll/UI/ProfessionOverview.lua`: uses them; `FillLinkTooltip` and `OnLinkClick(page, data)` keep only its own link kinds. The page behaves the same: the tooltip frame, the pin-first click and the item-link click are the same steps as before, in the same order.
- `NeedRoll/UI/LibraryBooks.lua`: the fixes for R1 and R4-R8.
- `NeedRoll/UI/Theme.lua`: the faction toggle uses `ns.OtherSide`.
- `NeedRoll/Locales/Locales.lua`: `ns.OtherSide`. `NeedRoll/Core/Init.lua`: `ns.IsQuestDone`.
- `NeedRoll/UI/MainFrame.lua`: `WHOLE_BODY`, `ShowSettingsPage`, `UI:Refresh`, `ShowLockTooltip`.
- `NeedRoll/Data/LibraryBooks.lua`: field order, header, Blackrock Mountain's `name`.
- `NeedRoll/Locales/enUS.lua`: `%s and %s` and `item %d` moved to the HunterPets section; one phrase changed (R7).
- `docs/STYLE-GUIDE.md`; `tests/smoke/modules/UI-LibraryBooks.lua` (`LearningTest`, and three new scenarios).

## Checks

Round 2 results, on `ab63c01`, over the whole range `v1.1.0..ab63c01`. Round 1 got the same results on `31a2902`, except where a row says otherwise.

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 26 changed Lua files | Passed. Lua 5.1 and luacheck 1.2.0 were installed in this container for the review. |
| `luacheck --no-global -q`, base `v1.1.0` vs now | The three new addon files, `UI-LibraryBooks.lua`, `HunterPets.lua`, `ProfessionOverview.lua`, `Locales.lua`: 0 warnings. `Core/Init.lua` 8 → 9: line 171 is too long (142), the new module's `detail = L["..."]`, a literal `L` key, as earlier reviews accepted. `Locales/enUS.lua` 52 → 53: a long phrase line; the locale files keep one phrase per line, however long. Every other changed file has the same count as at `v1.1.0`. No new line over 120 in hand-written code besides `Init.lua:171`. |
| Globals | `luacheck` without `--no-global`: no "setting non-standard global" in any changed addon file (`Init.lua` 8 before and after). The new code reads only `C_Item`, `C_Map`, `C_QuestLog`, `C_Timer`, `CreateFrame`, `GameTooltip`, `GetTime`, `IsModifiedClick`, `UnitFactionGroup`, `wipe` |
| Lua 5.1 limits (`luac5.1 -l -l`) | Main-chunk locals: `UI/LibraryBooks.lua` 112, `UI/HunterPets.lua` 105 → 110, `UI/ProfessionOverview.lua` 164 → 161, `UI/MainFrame.lua` 148 → 152, `Core/LibraryBooks.lua` 22. Most upvalues: 26 (`CreateLibraryPage`), 25 (`HunterPets.lua:941`), 21 (`CreateProfessionOverview`). All far from the 200 / 60 limits |
| Formatting | LF, UTF-8, no tabs in the new files |
| `python3 tools/locales.py --check` | Passed |
| `python3 tools/translations.py` | Exit 0, nothing reported |
| Translations | Each of the 10 other languages lacks the same 102 English phrases from this range. Among them is round 2's changed phrase `L["Inside %s: click to pin its way in"]` (it was "Inside Blackrock Mountain: ..." in round 1, also untranslated). None of the 10 has a phrase English no longer uses. Known: they are being drafted separately for the Translations PR. Not a finding. |
| `tests/smoke/check.sh` (all four: dev, packaged, secret, combat) | Passed, "all passed" in each run (2347 scenario lines over the four runs; 2335 in round 1, with the three new Library scenarios) |
| Probe scenarios (scratch copies of the repo, not committed) | Round 1: confirmed R1 and R9. Round 2: on `ab63c01`, a Horde character carrying a book of unknown quest who turns in four ordinary quests gets four "nothing learned" lines in a dev build (R13) |
| `cd scraper && python3 -m unittest discover -s tests` | Passed, 350 tests (no scraper code changed) |
| Ketho's `forever` lists | `GlobalAPI.lua`, `Events.lua`, `WidgetAPI.lua`, `AtlasInfo.lua`, `LuaEnum.lua`, `FrameXML.lua` downloaded from the `forever` branch to the scratchpad and grepped (table under WoW API); round 2's new events `MAIL_SHOW`, `MAIL_CLOSED`, `MERCHANT_SHOW`, `MERCHANT_CLOSED` are all there |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Readability | `UI/LibraryBooks.lua:493-513, 524-532`; `docs/STYLE-GUIDE.md:636` | Group by zone with every book handed in under Still to find shows "0 zones, lowest level first", never "Every book is handed in." | fixed in round 1 (`449f4d6`) |
| R2 | should fix | WoW API | `Core/LibraryBooks.lua:27-30, 134-170` | Learning a hand-in quest takes any book leaving the bags within 5 s of any turn-in, saves it for good, and relies on an event order not checked in game | fixed in round 1 (`449f4d6`) |
| R3 | should fix | Redundant code | `UI/LibraryBooks.lua:97-121, 127-131, 143-151, 157-159, 235-288, 877-880, 960-968`; `Core/LibraryBooks.lua:50-52`; `UI/LibraryBooks.lua:519` | About a dozen helpers copied from the Professions Overview (text, links, tooltips, clicks, RefreshSoon) | fixed in round 1 (`449f4d6`) |
| R4 | nit | Readability | `UI/LibraryBooks.lua:135-138, 300, 311-325, 346-360, 389-414, 739-757, 777-827` | `reward`, `zone` and `group` each mean two things on the page; `PlayerBracket` takes any level | fixed in round 1 (`449f4d6`) |
| R5 | nit | Redundant code | `UI/LibraryBooks.lua:135-138, 175-188, 310-325` | `BracketIndex` repeats `PlayerBracket`'s loop; `ZoneOf` builds a new table each call, twice per spot link | fixed in round 1 (`449f4d6`) |
| R6 | nit | Redundant code | `UI/LibraryBooks.lua:898` | Every size change redraws the whole page, though only the bar depends on the width | fixed in round 1 (`449f4d6`) |
| R7 | nit | Readability | `UI/LibraryBooks.lua:82-83, 206-208`; `Data/LibraryBooks.lua:42, 85` | Blackrock Mountain is spelled out in three places, a generic `door` tooltip names it, and the comment over `ZONE_LABELS` doesn't parse | fixed in round 1 (`449f4d6`) |
| R8 | nit | Readability | `UI/LibraryBooks.lua:530` | `table.insert(rows, OtherSideNote(stock, side))` appends a value that is often nil | fixed in round 1 (`449f4d6`) |
| R9 | nit | Readability | `docs/STYLE-GUIDE.md:629`; `UI/LibraryBooks.lua:832-833` | The style guide puts the Horde librarian in Orgrimmar (the page says Undercity); the subtitle comment says 37 Alliance books (38) | fixed in round 1 (`449f4d6`) |
| R10 | nit | Readability | `Data/LibraryBooks.lua:6-7, 167-182` | The hand-written data switches field order mid-list, and one header sentence is hard to parse | fixed in round 1 (`449f4d6`) |
| R11 | nit | Readability | `Core/LibraryBooks.lua:43-47, 55-60`; `UI/LibraryBooks.lua:90-93` | A book whose quest the data doesn't know can never read "Handed in": handed in before v1.2.0, it says "Not found" for good | open: Mike's call (left as is in round 2) |
| R12 | nit | Redundant code | `UI/MainFrame.lua:1385, 2281-2292, 432` | The fourth whole-body tab is added by hand to two more lists beside `WHOLE_BODY`; `library` (a yes/no) sits next to `self.library` (the page) | fixed in round 1 (`449f4d6`) |
| R13 | nit | Readability | `Core/LibraryBooks.lua:138-146, 152-153, 188, 201, 225` | (round 2) Dev builds print a line on every quest turned in while a book of unknown quest is carried | open |

### R1 · Group by zone with every book handed in under Still to find shows "0 zones, lowest level first", never "Every book is handed in."
- **Severity:** should fix
- **Area:** Readability (the empty-list check says something the code doesn't do)
- **Where:** `NeedRoll/UI/LibraryBooks.lua:493-513` (`ZoneRows`), `:524-532` (`ListRows`); `docs/STYLE-GUIDE.md:636` (Footer row)
- **Status:** fixed in round 1 (`449f4d6`). `ZoneRows` adds the zones line only while a zone shows (`UI/LibraryBooks.lua:430-434`), so `ListRows`' empty check works in both views. New scenario "with every book handed in, Still to find says so, by level and by zone". The style guide's List and Footer rows say so.

**What's wrong.** `ListRows` shows the "every book is in" line only when the view built no rows:

```lua
local rows = page.byZone and ZoneRows(page, stock, librarian) or BracketRows(page, stock)
...
if #rows == 0 then
    table.insert(rows, { kind = NOTE, height = NOTE_ROW, text = L["Every book is handed in."] })
end
```

`BracketRows` returns no rows when Still to find hides every bracket. `ZoneRows`, though, always inserts its "%d zones, lowest level first" note (`:506-507`), even when `#folds` is 0. So in the zone view `#rows` is never 0.

**Why it matters.** A player who has handed in every book picks Still to find with Group by zone ticked and sees "0 zones, lowest level first" over an empty list, with no "Every book is handed in.". The style guide's Footer row (`STYLE-GUIDE.md:636`) promises that line in both views.

**Evidence.** A probe scenario (scratch copy, Checks) marked every Alliance book's quest done, learned a quest for The Liminal and the Arcane, picked `TO_FIND` and printed the rows. Zone view: `NOTE "0 zones, lowest level first"`, `NOTE "2 Horde-only books hidden"`. By level: `NOTE "Every book is handed in."`, then the same footer. No smoke scenario covers the zone view's empty state (`UI-LibraryBooks.lua:275-301` checks only brackets).

**Fix.** Add the zones note only when there are folds, so the existing check works for both views:

```lua
if #folds > 0 then
    table.insert(rows, { kind = NOTE, height = NOTE_ROW,
        text = Theme:Plural(#folds, L["%d zone, lowest level first"], L["%d zones, lowest level first"]) })
end
```

Add the zone view to the Still to find scenario.

### R2 · Learning a hand-in quest takes any book leaving the bags within 5 s of any turn-in, saves it for good, and relies on an event order not checked in game
- **Severity:** should fix
- **Area:** WoW API (event handling)
- **Where:** `NeedRoll/Core/LibraryBooks.lua:27-30` (`TURN_IN_WAIT`), `:134-150` (`TryLearn`), `:158-170` (the two handlers)
- **Status:** fixed in round 1 (`449f4d6`). The learning is rewritten (`Core/LibraryBooks.lua:77-243`). A turn-in takes only the bag change just before it (within `SAME_MOMENT`, 0.5 s) or the first one after it (within `TURN_IN_WAIT`, 1 s), and each bag change answers one turn-in. Nothing is learned while the bank, mail or a merchant is open (`TrackWindow`: `BANKFRAME_OPENED`/`CLOSED`, `MAIL_SHOW`/`CLOSED`, `MERCHANT_SHOW`/`CLOSED`), when two turn-ins wait on one change, or when several books leave at once; dev builds say why. Two new scenarios cover the bag change coming first, and a book banked or thrown away two seconds after an unrelated turn-in. Every doubtful case now learns nothing rather than the wrong thing. Still to do: check the real event order in game once. The dev print now shows it when a hand-in learns nothing. That print fires on every ordinary turn-in, though (R13).

**What's wrong.** `QUEST_TURNED_IN` for any quest that isn't a known book or reward quest opens a 5-second window (`untilTime = GetTime() + TURN_IN_WAIT`). The window stays open across bag updates until some carried book's count drops (`TryLearn` returns without clearing `pendingTurnIn` when `BookHandedIn` finds none). The first single book to leave the bags in that window is saved as handed in with that quest:

```lua
local item = BookHandedIn(turnIn)
if not item then return end
pendingTurnIn = nil
ns.db.libraryBookQuests[turnIn.side][item] = turnIn.questID
```

Two problems come from that:

1. **Wrong books learned.** Picture a Horde character carrying Undead Potatoes (no Horde quest known yet). They turn in an ordinary quest, then within 5 seconds put the book in the bank, mail it, sell it or destroy it. Or they turn in two quests back to back, and the second turn-in replaces `pendingTurnIn` before the first one's bag change arrives. The book is then saved, account-wide for the side, as handed in with the wrong quest. That quest was just completed, so this character's page reads "Handed in" for a book they still hold or never handed in. Every other character of the side who has done that quest reads the same. Nothing in the addon clears a learned entry; it only stops mattering once `Data/LibraryBooks.lua` gets the real ID (`QuestOf` reads the data first).
2. **Order of events assumed.** The comment (`:27-29`) says the bag change "can arrive a little after QUEST_TURNED_IN". The code works only in that order: `carriedBefore = carried` is the snapshot from the last `BAG_UPDATE_DELAYED`. If the game sends the item removal's `BAG_UPDATE_DELAYED` before `QUEST_TURNED_IN`, the snapshot no longer holds the book and nothing is ever learned, with no message, even in a dev build. The smoke stand-in fires the events in the assumed order (`UI-LibraryBooks.lua:333-336`), so it can't tell. Neither the commit nor the PR says the order was checked in game.

**Why it matters.** Learned quests are saved data that outlive the session and spread to every character of the side. A wrong entry shows a false "Handed in", moves the reward bar, and stays until a data release fixes that book. A silent failure leaves the 9 Horde gaps and 1 Alliance gap unlearned, and Mike never gets the print he is waiting for.

**Evidence.** Lines read. `IsKnownQuest` (`:111-121`) filters only quests already known to the data. The learning scenario (`UI-LibraryBooks.lua:324-366`) covers "no book leaves" only with `W.Advance(6)` past the window, and doesn't cover a book leaving another way inside it. The event order in the real client is inferred to be unverified.

**Fix.** Narrow the window to the turn-in's own bag change, and accept either order:

- Keep the bag snapshot from before the last bag change too (`carriedBeforeLastChange`, with its time). On `QUEST_TURNED_IN`, if a bag change came in the same moment (within a fraction of a second), compare against the earlier snapshot.
- Close the window on the first `BAG_UPDATE_DELAYED` after the turn-in, whether or not a book left, instead of waiting up to 5 s. Or, if Mike has seen the change come a few updates late, cut `TURN_IN_WAIT` to about 1 s.
- Don't learn while the bank, mail or a merchant is open (`BANKFRAME_OPENED` is already tracked in `Core/Shopping.lua`).
- In a dev build, print when a turn-in with an unknown-quest book carried learned nothing, so a wrong order shows up.

Add scenarios for "bag change before the turn-in" and "book banked two seconds after an unrelated turn-in".

### R3 · About a dozen helpers copied from the Professions Overview (text, links, tooltips, clicks, RefreshSoon)
- **Severity:** should fix
- **Area:** Redundant code (`docs/READABLE-CODE.md` §6: "Two copies of a helper become one")
- **Where:** `NeedRoll/UI/LibraryBooks.lua:97-103` (`Colored`, `Muted`), `:113-116` (`JoinAnd`), `:127-131` (`ZoneName`), `:143-151` (`ItemName`), `:157-159` (`Link`), `:235-251` (`ShowLinkTooltip`'s frame), `:257-268` (`OnLinkEnter`, `OnLinkLeave`), `:274-288` (`OnLinkClick`'s head), `:877-880` (the page's hyperlink scripts), `:960-968` (`RefreshSoon`); `NeedRoll/Core/LibraryBooks.lua:50-52` (`IsQuestDone`); `UI/LibraryBooks.lua:519` (other side, inline)
- **Status:** fixed in round 1 (`449f4d6`). The shared parts are in `PetPageKit` (`UI/HunterPets.lua:800-937`: `Colored`, `Muted`, `JoinAnd`, `RowText`, `ZoneName`, `ItemName` with a fallback, `Link`, `WireLinks`, `AddRefreshSoon`). Each page now gives only `page.fillLinkTooltip` and `page.onLinkClick`. Also added: `ns.IsQuestDone` (`Core/Init.lua:405`) and `ns.OtherSide` (`Locales/Locales.lua:66`); the second replaces Theme's own copy. Theme's copy returned "Horde" for anything but "Horde" and the new one returns "Alliance" for anything but "Alliance": the same for both sides. `toggle.side` is always one of them (`Theme:FactionToggle` sets it from `ns.PlayerFaction()`), so the faction toggle behaves the same. A grep finds no copy left in either page.

**What's wrong.** These are copied line for line from `NeedRoll/UI/ProfessionOverview.lua`: `Colored`/`Muted` `:114-120`, `Link` `:134-136`, `IsQuestDone` `:147-149`, `JoinAnd` `:152-155`, `ItemName` `:168-176`, `ZoneName` `:178-181`, `ShowLinkTooltip` `:393-399`, `OnLinkEnter`/`OnLinkLeave` `:431-442`, `OnLinkClick` `:466-475`, the page's hyperlink scripts `:1357-1359`, `RefreshSoon` `:1460-1468`. Some differ by a word: `ItemName` takes the fallback name as an argument, and `ZoneName` reads a string key first. `OnLinkEnter`'s comment is the same paragraph, word for word. `UI/LibraryBooks.lua:519` writes `side == "Alliance" and "Horde" or "Alliance"`, which `ProfessionOverview.lua:138` (`OtherSide`) and `Theme.lua:1742` already have as functions.

**Why it matters.** Both pages are built on `PetPageKit`, which exists so the pet pages share their parts. With two copies, a fix to how links are hovered or clicked (combat handling, the secure /mappin button, tooltips) has to be made twice. The next page built this way will make a third copy. A reader can't tell whether the small differences are on purpose.

**Evidence.** `grep -rln "local function OnLinkEnter"` (and the same for each helper): only these two files. Compared side by side.

**Fix.** Move the shared parts into `PetPageKit`, which both pages already load, as one PR that touches both pages:

```lua
-- UI/HunterPets.lua (PetPageKit), or a small UI/PageLinks.lua
PetPageKit.Colored, PetPageKit.Muted, PetPageKit.Link, PetPageKit.JoinAnd = ...
function PetPageKit.ItemName(page, itemID, fallback) ... end   -- the fallback as an argument
-- Wires a page's hyperlink handling: tooltip by kind, the secure /mappin button
-- over spot links, a click that pins in combat or calls onClick(page, data).
function PetPageKit.WireLinks(page, frame, showTooltipByKind, onClick) ... end
function PetPageKit.RefreshSoon(page) ... end  -- returns the coalescing redraw
```

`IsQuestDone` can be `ns.IsQuestDone` in `Core/Init.lua` next to `ns.PlayerFaction`, and the other side `ns.OtherSide` beside `ns.SideName`. If Mike would rather not touch the Professions Overview in this release, this can wait for the next one; it changes no behaviour.

### R4 · `reward`, `zone` and `group` each mean two things on the page; `PlayerBracket` takes any level
- **Severity:** nit
- **Area:** Readability (§1 meaningful names, §9 disinformation)
- **Where:** `NeedRoll/UI/LibraryBooks.lua:739-757` (`CreateRewardParts`), `:777-827` (`page.reward`), `:135-138` (`ZoneOf`), `:300` (`entry.zone`), `:311-317`, `:346-360`, `:389-414` (`SubText`), `:320-325` (`PlayerBracket`)
- **Status:** fixed in round 1 (`449f4d6`). `page.rewardBar` / `bar` with the loop variable `reward` (`UI/LibraryBooks.lua:655-673`). `entry.map` (`:227`) and `BracketIndex(map)`: `zone` now only means `ZoneOf`'s record, and `group.key` is the map. `spotsByMap` / `spotsOnMap` / `mapLinks` in `SubText` (`:312-338`). `BracketOfLevel`.

**What's wrong.**
- `page.reward` holds the bar's textures and texts. In `CreateRewardParts` the local is `reward` and the loop variable for a reward quest is `entry`. Everywhere else `reward` is a reward quest (`RewardLink(page, reward)`, `RewardQuestText(page, reward, ...)`), and `PlaceRewardBar` re-aliases `page.reward` as `parts` to make room for that `reward`.
- `zone` is a map ID in `TakeStock` (`zone = book.spots[1].map`), `BracketIndex(zone)` and `group.key`. It is the level record `{ low, high, continent, ... }` in `ZoneOf`'s result and `group.zone`. So `ZoneOf(group.key)` turns a "zone" into a "zone".
- In `SubText`, `group` is the spots one map holds; two functions away a `group` is a fold's books (`GroupBy`).
- `PlayerBracket(level)` finds the bracket of any level; only its caller passes the player's.

**Why it matters.** A newcomer reading `PlaceRewardBar` or `ZoneGroups` has to keep track of which `reward` or `zone` is meant on each line. That is the mental mapping `docs/READABLE-CODE.md` §8 asks to avoid.

**Fix.** `page.rewardBar` / local `bar` (with the loop variable `reward`); `entry.map`, `BracketIndex(map)` and `group.map` for map IDs, keeping `zone` for `ZoneOf`'s record; `spotsOnMap` and `mapLinks` in `SubText`; `BracketOfLevel(level)`.

### R5 · `BracketIndex` repeats `PlayerBracket`'s loop; `ZoneOf` builds a new table each call, twice per spot link
- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/LibraryBooks.lua:310-325`, `:135-138`, `:175-188`
- **Status:** fixed in round 1 (`449f4d6`). `BracketIndex(map)` is `BracketOfLevel(ZoneOf(map).low)` (`UI/LibraryBooks.lua:237-248`), and `SpotLink` reads the door once (`:145-152`). `ZoneOf` still builds a small table per call, now once per link, which is fine.

**What's wrong.** `BracketIndex(zone)` and `PlayerBracket(level)` are the same loop over `BRACKETS`; the first only looks the level up first. `ZoneOf` allocates a fresh table on every call. `SpotLink` calls it twice for the same spot: once through `PinnedSpot` and once for `isDoor`. With 40 books, more spots, and a full redraw on every refresh (see R6), that's a few hundred throwaway tables per draw.

**Fix.**

```lua
local function BracketOfLevel(level) ... end                      -- the one loop
local function BracketIndex(map) return BracketOfLevel(ZoneOf(map).low) end
```

In `SpotLink`, read `local door = ZoneOf(spot.map).door` once and pass it on. `ZoneOf` can also read the data record's fields directly where only one is needed.

### R6 · Every size change redraws the whole page, though only the bar depends on the width
- **Severity:** nit
- **Area:** Redundant code (work repeated per frame)
- **Where:** `NeedRoll/UI/LibraryBooks.lua:898`
- **Status:** fixed in round 1 (`449f4d6`). A size change re-places the bar and refills it from the last `self.stock` (`UI/LibraryBooks.lua:812-818`, `:862`). The rows re-lay themselves as the column's view resizes (`Theme:ScrollColumn`'s view `OnSizeChanged` redraws them). The style guide's Links row says resizing redraws only the bar.

**What's wrong.** `page:HookScript("OnSizeChanged", function(self) if self:IsVisible() then self:Refresh() end end)`. While the player drags the resize grip, this runs every frame. Each run re-checks every book's quest, bags (`C_Item.GetItemCount`) and bank (`BankCount` calls `GetItemCount` twice more), rebuilds every row entry and link, and redraws the list. The list already re-lays itself out when its view resizes (`Theme:ScrollColumn`'s `view` `OnSizeChanged`). Only the reward bar's width and notches depend on the page's width (`PlaceRewardBar`, `DrawRewards`). No other `PetPageKit` page hooks `OnSizeChanged`.

**Fix.** Keep the last `stock` on the page in `Refresh`, and on a size change re-place and refill only the bar: `self:PlaceColumn(); DrawRewards(self, self.stock)`. Or send the size change through `RefreshSoon`, so a burst of changes in one frame costs one redraw.

### R7 · Blackrock Mountain is spelled out in three places, a generic `door` tooltip names it, and the comment over `ZONE_LABELS` doesn't parse
- **Severity:** nit
- **Area:** Readability (§7 searchable names, §5 comments)
- **Where:** `NeedRoll/UI/LibraryBooks.lua:82-83` (`ZONE_LABELS`), `:206-208` (`ShowSpotTooltip`); `NeedRoll/Data/LibraryBooks.lua:42, 85`
- **Status:** fixed in round 1 (`449f4d6`). The zone record carries its name (`Data/LibraryBooks.lua:86`, `name = L["Blackrock Mountain"]`, in the header's schema `:25-30`). `ZoneName` reads it (`UI/LibraryBooks.lua:112-117`), `ZONE_LABELS` is gone, and the tooltip is `L["Inside %s: click to pin its way in"]` (`:171`). The phrase isn't translated yet (Checks).

**What's wrong.** The data keys the zone by the string `"Blackrock Mountain"` (`BLACKROCK_MOUNTAIN`, `Data/LibraryBooks.lua:42`). The UI repeats the literal as the key of `ZONE_LABELS`. A spot whose zone has a `door` gets the tooltip `L["Inside Blackrock Mountain: click to pin its way in"]`, so the generic `door` mechanism only reads right for that one zone. The comment "Zones the game has no map of NeedRoll's for (Data/LibraryBooks.lua keys them by name)" doesn't parse.

**Fix.** Put the name in the data, with the zone it describes: `[BLACKROCK_MOUNTAIN] = { 50, 58, EASTERN_KINGDOMS, door = "BRD", name = L["Blackrock Mountain"] }`. `ZoneName` then reads `ZoneOf(map).name`, and the tooltip is `L["Inside %s: click to pin its way in"]:format(ZoneName(spot.map))`. The other languages don't have the phrase yet (Checks), so changing the key now costs no translation. Reword the comment: "Zones with no map of their own in the game, keyed by name in Data/LibraryBooks.lua".

### R8 · `table.insert(rows, OtherSideNote(stock, side))` appends a value that is often nil
- **Severity:** nit
- **Area:** Readability (Lua 5.1 trap)
- **Where:** `NeedRoll/UI/LibraryBooks.lua:530`
- **Status:** fixed in round 1 (`449f4d6`). `UI/LibraryBooks.lua:457-458`.

**What's wrong.** `OtherSideNote` returns nil when the other side has no side-only books. `table.insert(rows, nil)` happens to do nothing in Lua 5.1, but the line reads as "always add the footer row". Whether it is safe depends on a corner of `table.insert`.

**Fix.** `local footer = OtherSideNote(stock, side)` / `if footer then table.insert(rows, footer) end`.

### R9 · The style guide puts the Horde librarian in Orgrimmar (the page says Undercity); the subtitle comment says 37 Alliance books (38)
- **Severity:** nit
- **Area:** Readability (docs and comments that are wrong)
- **Where:** `docs/STYLE-GUIDE.md:629` (Heading row); `NeedRoll/UI/LibraryBooks.lua:832-833`
- **Status:** fixed in round 1 (`449f4d6`). `docs/STYLE-GUIDE.md:629` now reads "Undercity, Magic Quarter"; the comment at `UI/LibraryBooks.lua:748-749` says 38.

**What's wrong.** The style guide writes the Horde heading line as "Owen Thadd, Orgrimmar, Magic Quarter, 39". Owen Thadd's spot is `[211022] = { 1458, 73.4, 33 }` (`Data/ClassQuests.lua:441`). Map 1458 is Undercity, which is also where the Magic Quarter is. `SubtitleText` writes `ZoneName(spot.map)`, so in game the line reads "Undercity, Magic Quarter". The comment over `SubtitleText` gives "37 books for the Alliance"; the Alliance has 38 (smoke `UI-LibraryBooks.lua:114`).

**Evidence.** Probe output (Checks): "Hand them in to Owen Thadd · Map 1458, Magic Quarter · 39 books for the Horde".

**Fix.** "Undercity, Magic Quarter" in the style guide; "38 books" in the comment.

### R10 · The hand-written data switches field order mid-list, and one header sentence is hard to parse
- **Severity:** nit
- **Area:** Readability (§2 consistent formatting, §5 comments)
- **Where:** `NeedRoll/Data/LibraryBooks.lua:167-182`, `:6-7`
- **Status:** fixed in round 1 (`449f4d6`). Every book is now `item, quest`/`questBySide`, `name`, ... (`Data/LibraryBooks.lua:168-210`), and the header sentence is reworded (`:6-11`). No line over 120.

**What's wrong.** Books 1 to 24 are written `{ item, quest, name, side, spots, place, how }`, as the header's schema lists them. From Sanguine Sorcery (`:167`) on, they switch to `{ item, name, quest, spots }`. The header's "the guide's summary table lists Nar'thalas Almanac in four zones, copy errors (Darkshore is right)" takes two reads.

**Fix.** Write every entry in the header's order, `item, quest (or questBySide), name, side, spots, place, how`. Reword the sentence: "the guide's summary table lists Nar'thalas Almanac in four zones; three are copy errors, and Darkshore is right."

### R11 · A book whose quest the data doesn't know can never read "Handed in": handed in before v1.2.0, it says "Not found" for good
- **Severity:** nit
- **Area:** Readability (player-facing text that says more than the code knows)
- **Where:** `NeedRoll/Core/LibraryBooks.lua:43-47` (`QuestOf`), `:55-60` (`Status`); `NeedRoll/UI/LibraryBooks.lua:90-93` (`STATUS_TEXT`)
- **Status:** open: Mike's call (the gaps are known and documented in `Data/LibraryBooks.lua:13-16`). Unchanged in round 2. The code is now at `Core/LibraryBooks.lua:39-43` (`QuestOf`), `:46-51` (`Status`) and `UI/LibraryBooks.lua:89-92` (`STATUS_TEXT`).

**What's wrong.** `Status` can only answer HANDED_IN when `QuestOf` returns a quest. The quest is unknown for The Liminal and the Arcane (both sides) and for the eight books of the 84395-84402 series (Horde). For those books a character who handed one in before installing v1.2.0, or on a copy that missed the turn-in (R2), sees "Not found", for good. The chip counts, the fold figures and the reward bar count them as still to find.

**Why it matters.** A Horde player at 30 books sees a bar short of 25 and eight books "Not found" that they handed in long ago. "Not found" says NeedRoll checked; it couldn't.

**Fix.** Mike decides. Options: a fifth status for a book with no quest known for the side and not held ("Can't tell yet", in `faint`); or a floor from the reward quests done (Friend of the Library done means at least 10 handed in), shown on the bar.

### R12 · The fourth whole-body tab is added by hand to two more lists beside `WHOLE_BODY`; `library` (a yes/no) sits next to `self.library` (the page)
- **Severity:** nit
- **Area:** Redundant code (§6, §7), Readability (§1 booleans)
- **Where:** `NeedRoll/UI/MainFrame.lua:1385` (`ShowSettingsPage`'s list), `:2281-2292` (`UI:Refresh`), `:432` (`ShowLockTooltip`)
- **Status:** fixed in round 1 (`449f4d6`). `WHOLE_BODY` maps each tab to its pane's key on `UI` (`UI/MainFrame.lua:30-34`), and both lists are now loops over it: `ShowSettingsPage` `:1386-1389`, `UI:Refresh` `:2283-2290`. `isLocked` at `:433`. The values are strings, so the other `WHOLE_BODY[...]` checks (`:1683`, `:1845`, `:1877`, `:2136`) still read as true.

**What's wrong.** `WHOLE_BODY` (`:33`) is the list of tabs that fill the body. Adding Library still needed two more hand-written lists: the pane keys `{ "library", "shopping", "wishlist", "classes", "link" }` in `ShowSettingsPage`, and four lines of `local library = state.category == "LIBRARY_BOOKS" and not state.search` / `if self.library then self.library:SetShown(library) end` in `UI:Refresh`. In the second, `library` is a yes/no right beside `self.library`, the page. The pattern was there before, and this range adds to it. In `ShowLockTooltip`, `local locked` would read better as `isLocked` (the saved key `locked` stays).

**Fix.** One table names each whole-body tab's pane: `WHOLE_BODY = { LIBRARY_BOOKS = "library", SHOPPING = "shopping", WISHLIST = "wishlist", CLASSES = "classes" }`. Its `WHOLE_BODY[x]` checks keep working. `UI:Refresh` and `ShowSettingsPage` then loop over it:

```lua
local wholeBody = not state.search and WHOLE_BODY[state.category]
for _, paneKey in pairs(WHOLE_BODY) do
    if self[paneKey] then self[paneKey]:SetShown(paneKey == wholeBody) end
end
if wholeBody then ShowWholeBodyTab(state.category) return end
```

### R13 · (round 2) Dev builds print a line on every quest turned in while a book of unknown quest is carried
- **Severity:** nit
- **Area:** Readability (a dev message that buries the one it exists for)
- **Where:** `NeedRoll/Core/LibraryBooks.lua:138-146` (`ReportNothingLearned`), its callers `:152-153` (`LearnFrom`, "no book left the bags with it"), `:188` (`AwaitBagChange`, "no bag change came with it"), `:201` and `:225` (a window open)
- **Status:** open

**What's wrong.** `OnQuestTurnedIn` waits for a bag change after **any** quest that isn't a known book or reward quest, as long as some book of unknown quest is in the bags (`:207`, `if next(carried) then AwaitBagChange(turnIn) end`). When no book leaves, which is every ordinary quest, `LearnFrom` or the timer calls `ReportNothingLearned`. The same happens at a vendor quest giver with the merchant window open (`:201`). In a dev build that prints "Library: quest N was turned in carrying books of unknown quest, but no book left the bags with it: nothing learned." on every one of those turn-ins.

**Why it matters.** The print is there so Mike sees when a real hand-in learned nothing (`:138-140`: "so Mike can tell if the events came in an order the learning doesn't expect"). The Liminal and the Arcane has no quest for either side, and a Horde character carries up to eight more such books. Carrying any of them for a while, through ordinary questing, means a chat line per quest turned in. The one line that matters, a librarian hand-in that learned nothing, is lost among them. Packaged builds print nothing, so players are not affected.

**Evidence.** A probe scenario in a scratch copy (Checks): a Horde character carrying The Liminal and the Arcane turns in four ordinary quests (50001-50004) and gets four lines. Three end "no book left the bags with it", the last "no bag change came with it".

**Fix.** Report only when a library hand-in was likely and nothing was learned. Options:
- Print "no book left" only when the bag change took some other item too. Or print once per session.
- Better: on a turn-in with nothing learned, report only if a carried book of unknown quest leaves the bags in the next few seconds. That is exactly the "events came in an order the learning doesn't expect" case.

Keep the "another quest was turned in before its bag change" and "more than one book left" prints as they are; those only come up near a real hand-in.

## Area notes

### Readability

Checked against every rule in `docs/READABLE-CODE.md`:
- **Formatting:** 4-space indents, LF, `local _, ns = ...` at the top of each new file, `local` everywhere, no line over 120 in new code.
- **Names:** constants carry their unit or a comment (`TURN_IN_WAIT -- seconds`, the layout constants at `UI/LibraryBooks.lua:33-71`, `LOCK`). Status and kind strings are named constants (`LibraryBooks.HANDED_IN`, `FOLD`/`BOOK`/`HAND_IN`/`NOTE`, `ALL_BOOKS`/`TO_FIND`). Booleans mostly read as questions (`isOpen`, `isLit`, `isAtLevel`, `isRefreshPending`). The exceptions are R4 and R12.
- **Functions** are small and each has one job, with guard clauses. `CreateLibraryPage` is about 110 lines, but mostly named methods, the same shape as `CreateProfessionOverview` (`ProfessionOverview.lua:1347-1475`). No nesting past three levels.
- **Comments** explain the game facts behind the code: the bank only known while open, quest completion per character, why the column hangs by measured offsets (`Theme:LineHeight`, protected anchors), `UnitLevel` lagging `PLAYER_LEVEL_UP`, why the padlock is raised to the X's level. The wrong ones are R7 and R9.
- **Lua 5.1 traps:** `a and b or c` uses (`:177`, `:390`, `:408`, `:453`, `DrawLock`'s `locked and 0 or LOCK.lift`) all have a truthy middle value; `0` is truthy in Lua. `#` is used only on arrays without holes. No string pattern is built from data. R8 is the one doubtful `table.insert`.
- **`UI:Place`:** reading `self.tabLabels[category]` for whole-body tabs gives the same labels as the removed literals (`UI.tabLabels` is built from the `ns.Modules.list` labels, `MainFrame.lua:36-37`; `Init.lua:176-178`).
- **`Data/LibraryBooks.lua`:** the header documents every field. Facts that came from Mike's saved pages say so (never fetched). Coordinates are percentages, made 0-1 by `Spot`. The two librarians' spots exist (`Data/ClassQuests.lua:441-442`), and the `BRD` door exists (`Data/Entrances.lua:34`). Zephras Isle's map 2521 is the one `forever.json` already uses. Not verified: the 20- and 25-book rewards share the English name "Greater Friend of the Library" (`:52-53`). The game's own quest name replaces it through `Core/Names.lua`, but worth a look from Mike.

Round 2 re-read:
- **`Core/LibraryBooks.lua`'s rewrite** reads well. Each function has one job and its name says it (`TakeBooksGoneJustBefore`, `AwaitBagChange`, `LearnFrom`). The block comment over it (`:81-89`) explains to a newcomer why either event order must work, and why every doubt learns nothing. The constants carry their unit.
- **The `PetPageKit` helpers** say what each page must give them (`page.links`, `page.itemsAsked`, `page.fillLinkTooltip`, `page.onLinkClick`, `HunterPets.lua:851-855`). Both pages give all four.
- **One small leftover:** the Library page names a `RefreshSoon` wrapper (`UI/LibraryBooks.lua:882`), where the Professions Overview writes the same closure inline (`ProfessionOverview.lua:1376`). It is too small to be a finding.
- **R13** is round 2's one new finding.

### WoW API

| Call, event, method, atlas | In `forever` lists | Where looked |
| --- | --- | --- |
| `C_QuestLog.IsQuestFlaggedCompleted` | yes | GlobalAPI.lua:3599 |
| `C_Item.GetItemCount` (with `includeBank`, via `BankCount`) | yes | GlobalAPI.lua:2514 |
| `C_Item.GetItemNameByID` | yes | GlobalAPI.lua:2538 |
| `C_Item.GetItemIconByID` | yes | GlobalAPI.lua:2524 |
| `C_Map.GetMapInfo` | yes | GlobalAPI.lua:2863 |
| `C_Timer.After` | yes | GlobalAPI.lua:4174 |
| `UnitFactionGroup`, `GetTime`, `IsModifiedClick`, `CreateFrame`, `UnitLevel` (via `ns.PlayerLevel`), `wipe` | yes | GlobalAPI.lua (`wipe` :7090, `GetTime` :5921) |
| `GameTooltip_Hide` | yes (FrameXML) | FrameXML.lua:1870 |
| `QUEST_TURNED_IN`, `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`, `BANKFRAME_CLOSED`, `PLAYERBANKSLOTS_CHANGED`, `PLAYER_LEVEL_UP` | yes | Events.lua (e.g. :169, :1578) |
| (round 2) `MAIL_SHOW`, `MAIL_CLOSED`, `MERCHANT_SHOW`, `MERCHANT_CLOSED` (`Core/LibraryBooks.lua:241-243`) | yes | Events.lua |
| (round 2) `C_Timer.After` in `Core/LibraryBooks.lua:185` (a turn-in's wait) | yes | GlobalAPI.lua:4174 |
| `SetHyperlinksEnabled`, `OnHyperlinkEnter` / `Leave` / `Click` | yes | WidgetAPI.lua:636, :536-538 |
| `SetDesaturated`, `SetAtlas`, `SetColorTexture`, `SetFrameLevel`, `GetFrameLevel`, `StartMoving`, `HookScript`, `SetWordWrap`, `SetJustifyH`, `EnableMouse`, `IsVisible`, `IsMouseOver` | yes | WidgetAPI.lua |
| `GameTooltip:SetOwner`, `AddLine`, `IsOwned` | yes | WidgetAPI.lua `GameTooltip` (:1179 on) |
| `GameTooltip:SetHyperlink` | inferred | Not in WidgetAPI's `GameTooltip` methods. It is the standard FrameXML tooltip data mixin method, used the same way since before v1.1.0 (`LootGrid.lua`, `Overview.lua`, `ProfessionOverview.lua`) |
| Atlas `common-icon-checkmark` | yes | AtlasInfo.lua:3669, :21775 |
| Atlas `Campaign-QuestLog-LoreBook` (Library's Settings icon) | yes | AtlasInfo.lua:20544 |
| Texture `Interface\Icons\INV_Misc_Book_09`, file ID 134400 (question mark) | inferred | Icon paths and file IDs aren't in the lists; both are base Classic icons |

Also checked:
- **Item data:** names are asked for once per item (`ns.Items:Load`), and the page redraws when they arrive. No polling.
- **Events:** each handler uses its event. None is one-shot. The UI handlers return at once while the page is hidden.
- **Secret values:** none touched. Quest and NPC names come from data, or from `Core/Names.lua`, which already guards them. Levels go through `ns.Plain`.
- **Combat:** no call the game blocks in combat was added (the diff was grepped for the four `SetPropagate*`/`SetPassThroughButtons` calls, `SetAttribute`, map-opening calls). `CHECKED_COMBAT_CALLS` is unchanged. Map links go through `ns.UI.HoverMapLink` / `ShowOnMap`, which draw NeedRoll's own pin in combat; smoke "a spot link in combat draws NeedRoll's own pin" covers it, and the `--combat` run passed. The padlock only flips a saved flag. `StartMoving` on the window is the same path as before.
- **Other:** no new globals. Every `L[...]` is a literal key. The new calls are mirrored in the smoke stand-in (all four runs pass, with item and quest calls stubbed by `LibraryTest`). No nil guard was removed. The one dev-only print is inside `--@debug@` (`Core/LibraryBooks.lua:146-149`). `STYLE-GUIDE.md` was updated in the same range for both the padlock and the Library tab (inaccuracies: R1's Footer row, R9).
- **Open (R2):** the event order the learning assumes.

Round 2 (R2's rewrite):
- **Order:** either event order is handled.
- **Book tracking:** each bag change counts the books once (`OnBagChange` recounts only after learning, because a learned book is no longer of unknown quest).
- **Timer:** the one-shot `C_Timer.After` checks that its turn-in is still the one waiting before it acts.
- **Windows:** the open-window table lives only for the session, so it starts empty after a `/reload` or relog.
- **Not tracked:** trade and the auction house aren't among the windows. Inferred harmless: library books leave the bags only by hand-in, vendor, bank, mail or destroying, if they are soulbound as other quest-collection books are. That wasn't checked.

### Redundant code

Compared against the `Theme:` helpers (`Pill`, `CheckBox`, `RoundedOn`, `Arrow`, `JoinDots`, `Plural`, `Text`, `SetTextColor`, `ColorCode`, `Opaque`, `LineHeight`, `CropIcon`, `Insignia`, `FitAtlas`, `ScrollColumn`). The page uses each where one exists. `Theme:Plural` can't do `OtherSideNote`'s two-value format, so the hand-written choice there is right. Also compared against:
- `PetPageKit` (`CreatePage`, `CreateListRow`), used;
- `ns.UI.HoverMapLink` / `LeaveMapLink` / `ShowOnMap` / `PinHint` / `SourceZone` / `QuestSource` / `OpenItemSource`, all used, not copied;
- `ns.Items:Load` / `HandleModifiedClick` and `ns.Shopping:BankCount`, used;
- `ns.SideName` and `ns.PlayerFaction`, used;
- the stroke helpers `AddStroke` / `TintStrokes`, reused by the padlock.

The copies are R3. R5, R6 and R12 are smaller. No dead code, unused locals or stray prints were found (luacheck clean on the new files).

Round 2: R3's move leaves one copy of every helper the two pages shared (grep for each name: only `PetPageKit`). `Classes.lua` keeps its own `isRefreshPending` from before this range; `PetPageKit.AddRefreshSoon` could take it over in a later release (outside this range, so not a finding). The Questlines page's own "A and B" joins (`UI/Questlines.lua:422, 453`) also predate this range.

### Security

- **Untrusted input:** none. The range adds no addon message, chat or other-player input. Learned quest IDs are written from the player's own game events into their own SavedVariables.
- **Links:** built from numbers and from item names the game gives, or the data's own names, so no outside text reaches a `|H` link.
- **Privacy:** #809 adds 5 names to `scraper/drops/credits.json`, which stays in the private repo. None of the 11 names in `credits.json` appears anywhere under `NeedRoll/` (grep, every name). `.pkgmeta` still keeps `scraper`, `tools`, `tests` and `NeedRoll/Credits.txt` out of the zip.
- **Scraper:** no Wowhead request. `Data/LibraryBooks.lua` says its facts came from Mike's saved copy of a guide page, "never fetched". No scraper, tool or workflow code changed.

## Round history

- Round 1, 2026-11-08, `31a2902`: **Changes needed** (0 blocking, 3 should fix, 9 nits). Opened R1-R12.
- Round 2, 2026-11-08, `ab63c01` (fixes `449f4d6`): **Ready** (0 blocking, 0 should fix open, 2 nits open). Closed R1-R10 and R12. R11 left open for Mike. Opened R13 (nit).
