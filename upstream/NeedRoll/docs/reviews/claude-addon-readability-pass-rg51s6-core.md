# Review: Readability pass, Core group (Init, Items, Names, Shopping, Wishlist, LootLog, Tooltip, API)

| | |
| --- | --- |
| Branch | worktree branch `rp-core` (part of `claude/addon-readability-pass-rg51s6`) into `dev` (PR number not known yet) |
| Commit reviewed | `c0e5c79` plus uncommitted changes to 8 addon files and 8 new files in `tests/smoke/modules/` (rounds 2 and 3: the implementer's uncommitted fixes on the same base) |
| Date | 2026-10-18 (round 1: 2026-10-17; rounds 2 and 3: 2026-10-18) |
| Round | 3 (final) |
| Verdict | **Ready** (0 blocking, 0 should fix, 0 nits open; R1-R16 fixed) |
| Needs | `/reload`: Lua files only, no new addon files, no `.toc` or SavedVariables declaration change |

## What the change does

**Round 3 (final).** R13-R16 are fixed, and the group is still 3206
lines (code 2411, comments 516, blank 279, against 3229 / 2469 / 495 /
265 at `HEAD`).
- `ParseExport` doubles `|` in the class after capitalising it
  (`Wishlist.lua:546`), so `|C...`/`|N` can't come back as working
  lower-case codes.
- `LootLog.available` is gone (`LootLog.lua:34`).
- `Modules:Set` names `isOnByDefault` (`Init.lua:202`).
- `Core-Init.lua:406-426` tests the dev-tool and droptalk fallbacks.

At the coordinator's request, every guard or fallback the group removed
was checked again against Ketho's `forever` lists, not against
`tests/smoke/wow.lua` (see "Round 3: removed guards" below).

**Round 2.** The implementer addressed R1-R12. Code is now *shorter* than
`HEAD` (2469 -> 2411 code lines; 3229 -> 3206 total). Helpers that round 1
split out and that added little were folded back (`CroppedAtlasMarkup`,
`IsShowable`, `GameNumber`, `ChanceOfAny`, `GroupIntoRuns`, `IsBetterRun`,
`HeldBy`). Single-use constants went back inline with their comments.
`ns.IsSecret` is gone: callers use `issecretvalue` and `ns.Plain`. The
checkout-only `/nr` commands moved into the `--@debug@` block and
`CHECKOUT_ONLY` was deleted. The dev tools' nil fallbacks are back.
`Enum.ItemQuality`, `Enum.ItemClass` and `Enum.LootSlotType` replace local
numbers. The leftover `C_TransmogCollection` and `Enum.BagIndex` guards are
gone. `ParseExport` accepts only a numeric level and doubles `|` in the
character name. Every test override now goes through a `Restoring`
(xpcall + restore) helper. Two table-driven tests check that every `/nr`
word reaches its module. The text below describes the round 1 version.

**Round 1.**
A readability pass over the Core group, meant to leave what players see,
what is saved and what is sent unchanged. Locals and parameters get names
in the game's terms (`pending` -> `waiting`, `refs` -> `holders`,
`seen` -> `countedLoot`, `Key` -> `NameKey`...). Long functions are split
(`API.lua`'s matching into `MatchRank`, `NamesEncounter`, `QuestIn`,
`FirstShowable`; `Names.lua`'s `Tick` into a `LOOKUPS` table and `Ask`;
`Wishlist.lua`'s `BuildSources`, `Runs`, `ParseJSON` and `Parse`;
`LootLog.lua`'s `Scan` and `ScanIDs`; `Tooltip.lua`'s `Build`). `/nr`
becomes a `commands` table instead of an if-chain. Three copies of the
secret-value check become `ns.IsSecret` and `ns.Plain` in `Core/Init.lua`.
Existence guards on `C_*` calls and the fallbacks for `GetFactionInfoByID`,
`GetCVarBool` and `SetCVar` are dropped. `API.lua`'s standing table moves
to `ns.Names.STANDINGS`. Each file gets a smoke test module in
`tests/smoke/modules/` (62 tests).

## Scope

Round 2 (the current working tree; round 1's table follows):

| File | Lines HEAD -> now (code/comment/blank) | What changed since round 1 |
| --- | --- | --- |
| `NeedRoll/Core/Init.lua` | 566 -> 550 (394/132/40 -> 377/124/49) | `ns.IsSecret` removed; `CHECKOUT_ONLY` removed and the checkout-only commands moved into `--@debug@` (`:452-523`); dev-tool fallbacks back; `IsNewerFeature`, the version constants and `local CVAR` back inline; `StartCombatLogging` -> `CombatLoggingStatus`; `Modules:Set` shortened to `if on == not self.byKey[key].off` |
| `NeedRoll/Core/Items.lua` | 77 -> 72 (53/16/8 -> 49/16/7) | `Enum.ItemQuality` and `Enum.ItemClass.Questitem`; `C_TransmogCollection` guards and the wrapper `if` removed; stale "clients without the collection" comment fixed |
| `NeedRoll/Core/Names.lua` | 545 -> 536 (432/66/47 -> 413/75/48) | `LOOKUPS` maps kind -> lookup function and `Ask` sorts quests from the rest; timing constants inline; `FillOrQueueNames`; `place[1][place[2]]` back |
| `NeedRoll/Core/Shopping.lua` | 301 -> 297 (220/47/34 -> 212/52/33) | `HeldBy` folded back into `AltCounts`; `Enum.BagIndex` guards dropped; `BankBags` comment rewritten (R12) |
| `NeedRoll/Core/Wishlist.lua` | 574 -> 586 (467/57/50 -> 467/66/53) | `BuildSources`, `Runs` and the chance loops kept whole (renames only); JSON reader split kept; `ParseExport` level and name hardening (R8) |
| `NeedRoll/Core/LootLog.lua` | 627 -> 629 (490/90/47 -> 486/95/48) | constants inline; `Enum.*` used; `AddSighting` comment moved; the `AddLootSlot`/`ScanLootWindow` and `AddCandidates`/`NearbyCandidates` splits kept |
| `NeedRoll/Core/Tooltip.lua` | 280 -> 277 (219/42/19 -> 218/40/19) | `CroppedAtlasMarkup` and `Side` folded back; the depth constant inline; `issecretvalue` and `ns.Plain` |
| `NeedRoll/API.lua` | 259 -> 259 (194/45/20 -> 189/48/22) | `GameNumber`, `PlaceNames`, `NamesEncounter` and `IsShowable` folded into `MatchRank`, `Encounter` and `FirstShowable`; `instanceMapIDs` guard dropped (set at `Data/Data.lua:468`, which loads first) |
| `tests/smoke/modules/*.lua` (8 new files) | 0 -> 1789 | `Restoring` helper in each file; `/nr` dispatch tests; R8 cases |

Totals for the 8 addon files: **3229 -> 3206 lines; code 2469 -> 2411,
comments 495 -> 516, blank 265 -> 279.** Round 1 gave the `HEAD` total as
3209, which was a sum error: its own counts add up to 2469 + 495 + 265 =
3229.

Round 1:

| File | Lines before -> after (code / comment / blank) | What changed |
| --- | --- | --- |
| `NeedRoll/Core/Init.lua` | 566 -> 614 (394/132/40 -> 387/163/64) | Renames; `Modules:Set` rewritten around `onByDefault`; `ns.IsSecret`/`ns.Plain` added; `CombatLogging` -> `StartCombatLogging` with the `C_CVar` fallbacks dropped; version constants and `IsNewerFeature`; `/nr` as a `commands` table plus `CHECKOUT_ONLY` |
| `NeedRoll/Core/Items.lua` | 77 -> 77 (53/16/8 both) | Renames; `POOR`/`COMMON` constants; `GetItemInfoInstant` guard dropped |
| `NeedRoll/Core/Names.lua` | 545 -> 563 (432/66/47 -> 427/86/50) | Renames; `IndexEncounters` -> `IndexEncounter`; `Apply*` -> `KeepName`/`KeepQuest`; `Tick` split into `LOOKUPS` + `Ask`; queue entries keyed (`kind`, `id`, `tries`, `askAt`); `C_Map`, `C_Reputation`, `C_Spell`, `C_TooltipInfo` guards and the `GetFactionInfoByID` fallback dropped; timing constants |
| `NeedRoll/Core/Shopping.lua` | 301 -> 317 (220/47/34 -> 222/60/35) | `List()` folded into `Shop:Entries()`; `Shop:Clear` moved; `HeldBy` split from `AltCounts`; `Walk` -> `AddRow` with a `branch` table; `C_Container` guard dropped |
| `NeedRoll/Core/Wishlist.lua` | 574 -> 631 (467/57/50 -> 484/82/65) | Renames; `BuildSources` split in three; `ChanceOfAny`, `GroupIntoRuns`, `IsBetterRun`; JSON reader split into `ReadString`/`ReadItems`/`ReadObject`/`ReadArray`; `Parse` split into `ParseShareString`/`ParseExport`; guards on `GetItemInfoInstant`/`IsEquippedItem` dropped |
| `NeedRoll/Core/LootLog.lua` | 627 -> 656 (490/90/47 -> 499/109/48) | Local `LootLog` alias; own `Plain` replaced by `ns.Plain`; `Scan` split; `ScanIDs` split; `FishedIDs`/`FishStatus` wrappers made the methods; constants; `GetLootRollItemLink` and `Enum.LootSlotType` guards dropped |
| `NeedRoll/Core/Tooltip.lua` | 280 -> 294 (219/42/19 -> 225/48/21) | `CroppedAtlasMarkup` split out; `Build` split into `AddDropSources`/`AddQuestSources`; source entries keyed instead of positional; own `Secret` replaced by `ns.IsSecret`/`ns.Plain`; `C_Texture` guard dropped |
| `NeedRoll/API.lua` | 259 -> 284 (194/45/20 -> 202/56/26) | Renames; seven helpers split out; `STANDINGS` now read from `ns.Names`; `GetRealZoneText` and `UnitFactionGroup` guards dropped |
| `tests/smoke/modules/*.lua` (8 new files) | 0 -> 1614 | One test module per file in the group |

Totals for the 8 addon files: 3209 -> 3436 lines; code 2469 -> 2499,
comments 495 -> 620, blank 265 -> 337 (counted with an awk pass over
`git show HEAD:<file>` and the working copy). No generated files under
`NeedRoll/Data/` or `NeedRoll/Locales/` are touched.

## Checks

Round 3:

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 8 addon files and 8 test modules | passed |
| `luacheck --no-global -q` | 42 warnings (56 at `HEAD`), none new: `unused argument 'self'` and seven lines that were already over 120 at `HEAD` |
| `python3 tools/locales.py --check` | passed |
| `python3 tools/translations.py` | ran (rc 0), wrote nothing |
| `tests/smoke/check.sh` | passed in all three modes (dev 183 files, packaged 178, dev with secret values); 65 module tests `ok` in dev, 54 in packaged |
| `cd scraper && python3 -m unittest` | not run: no scraper changes |

Round 2:

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 8 addon files and 8 test modules | passed |
| `luacheck --no-global -q` before (HEAD copies) and after | 56 warnings before, 42 after, none new. Left: `unused argument 'self'`, and seven long lines that were already long at `HEAD`. Most are `L["..."]` literals (`Init.lua:127`, `:131`, `:137`, `:140`, `Names.lua:133`). `Names.lua:119` and `Wishlist.lua:231` are table rows that round 1 split and round 2 joined again; splitting them is safe (not a finding) |
| `python3 tools/locales.py --check` | passed |
| `python3 tools/translations.py` | ran (rc 0), wrote nothing |
| `tests/smoke/check.sh` | passed in all three modes (dev 183 files, packaged 178, dev with secret values); 64 module tests `ok` in dev, 54 in packaged (the dev-only ones are skipped there) |
| `cd scraper && python3 -m unittest` | not run: no scraper changes |

Round 1:

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 8 addon files and 8 test modules | passed |
| `luacheck --no-global -q` before (HEAD copies) and after | 56 warnings before, 41 after, none new. Left: `unused argument 'self'` on methods, and long lines that are single `L["..."]` literals (`Init.lua:131`, `:135`, `Names.lua:134`), which can't be split without breaking `tools/locales.py` |
| `python3 tools/locales.py --check` | passed |
| `python3 tools/translations.py` | ran (rc 0), wrote nothing; the `L["..."]` keys removed and added by the diff are the same set |
| `tests/smoke/check.sh` | passed in all three modes (dev 183 files, packaged 178 files, dev with secret values); all 62 module tests report `ok` |
| `cd scraper && python3 -m unittest` | not run: no scraper changes |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R13 | should fix | Security | `Wishlist.lua:546-552` | The export's class still goes into the note unescaped: `\|c` colors and `\|n` survive `Capitalized` | fixed in round 3 (uncommitted) |
| R14 | nit | Redundant code | `LootLog.lua:34,37` | `LootLog.available` is now read by nothing | fixed in round 3 (uncommitted) |
| R15 | nit | Readability | `Init.lua:202` | `if on == not self.byKey[key].off` leans on operator precedence | fixed in round 3 (uncommitted) |
| R16 | nit | Readability (tests) | `tests/smoke/modules/Core-Init.lua` | The fallback branches R11 restored have no test | fixed in round 3 (uncommitted) |
| R1 | blocking | Redundant code | all 8 files | The group grew by 227 lines (code +30); the brief requires it to end shorter | fixed in round 2 (uncommitted) |
| R2 | should fix | Redundant code | `Init.lua` `/nr` table | `CHECKOUT_ONLY` repeats what the `--@debug@` block already decides | fixed in round 2 (uncommitted) |
| R3 | should fix | WoW API | `Items.lua`, `Shopping.lua`, `Core-Items.lua` | Guards left on calls that are in Forever's lists | fixed in round 2 (uncommitted) |
| R4 | should fix | Redundant code | `Init.lua` | `ns.IsSecret` is a wrapper that only calls `issecretvalue` | fixed in round 2 (uncommitted) |
| R5 | should fix | Readability (tests) | six module test files | Tests don't put globals and saved state back when they fail | fixed in round 2 (uncommitted) |
| R6 | should fix | Readability (tests) | `Core-Init.lua` | No test that each `/nr` command reaches its module; the packaged list misses two | fixed in round 2 (uncommitted) |
| R7 | should fix | Readability | several | Constants for numbers used once, and two different `LOGIN_DELAY`s | fixed in round 2 (uncommitted) |
| R8 | should fix (pre-existing) | Security | `Wishlist.lua` `ParseExport` | A non-text `level` throws; the character name goes unescaped into the note | fixed in round 2 (uncommitted); the class still has the same gap: R13 |
| R9 | nit | WoW API | `Items.lua`, `LootLog.lua` | Local numbers where Forever has `Enum.ItemQuality` and `Enum.ItemClass` | fixed in round 2 (uncommitted) |
| R10 | nit | Readability | `LootLog.lua`, `Names.lua`, `Init.lua` | A misplaced comment and two names that say less than the function does | fixed in round 2 (uncommitted) |
| R11 | nit | WoW API | `Init.lua` dev commands | Dev commands lost their nil guards | fixed in round 2 (uncommitted) |
| R12 | nit (pre-existing) | Readability | `Shopping.lua:121-124` | `BankBags` comment vs Forever's `Enum.BagIndex` | fixed in round 2 (uncommitted) as a comment; the in-game check is still to do |

### R1 · The group grew by 227 lines (code +30); the brief requires it to end shorter

- **Severity:** blocking
- **Area:** Redundant code
- **Where:** all 8 addon files (table in Scope)
- **Status:** fixed in round 2 (uncommitted): code 2469 -> 2411 and total 3229 -> 3206, both below `HEAD`. The splits that added little were folded back (Scope table)

**What's wrong.** `notes/BRIEF.md` lists under *Hard constraints*: "Less code
is the aim: the group should end up shorter than it started." The group
went from 3209 to 3436 lines. Code lines went up by 30 (2469 -> 2499),
comments by 125 and blank lines by 72. Only `Items.lua` stayed the same
length, and every other file grew: `Wishlist.lua` +57, `Init.lua` +48,
`LootLog.lua` +29, `API.lua` +25.

**Why it matters.** Mike asked for less code unless cutting costs fidelity,
security or function. The growth comes from things the brief rules out
(R7: constants for numbers used once), from redundancy the pass added
(R2, R4), from dead guards it kept (R3), and from splits that add a
function plus a doc comment around a few lines.

**Evidence.** Line counts in Scope. The brief text quoted above.

**Fix.** Aim for code below 2469 lines and a total below 3209. The cuts
below keep every behaviour and every comment that explains a game fact:

- R2 (about 7 lines), R3 (about 6), R4 (about 5), R7 (about 15), R9 (about 3).
- `Names.lua:301-307` and `:423-426`: undo the unpacking into `holder, field`
  locals. `place[1][place[2]] = text` was clear with the comment on
  `holders` (4 lines).
- `API.lua`: `GameNumber` (`:65-67`) repeats the `instanceMapIDs` lookup
  that `PlaceNames` (`:54-62`) does. Fold the two together, or have
  `MatchRank` read the map ID once. `IsShowable` has one caller and can go
  inline in `FirstShowable` (about 6 lines).
- `Wishlist.lua`: `IsBetterRun` has one caller and was a 5-line inline sort
  before. `ChanceOfAny` builds a throwaway table for each call of
  `ClearChance`, which `BestChance` calls once per drop source. Pass the
  rates as you go or keep the old two-line `miss` product, which allocated
  nothing.
- Comments that repeat the name below them, for example `Wishlist.lua`
  `-- The list named `name` and its index, or nil.` over `FindList`, `-- Where
  `itemID` is on `list`, or nil.` over `IndexOf`, and `Shopping.lua` `-- The
  index and entry of `itemID` on the list, or nil.` over `Shop:Find`. READABLE-CODE §5
  says no restating. Keep the ones that name a game fact.
- Blank lines: the `/nr` commands (`Init.lua:444-580`) put a blank line
  and a 1-4 line comment around each one-line command. A short comment
  above each group (window, dev tools) would read just as well.

### R2 · `CHECKOUT_ONLY` repeats what the `--@debug@` block already decides

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/Core/Init.lua:497-554` (the four commands and the table), `:583-592` (dispatcher)
- **Status:** fixed in round 2 (uncommitted): `CHECKOUT_ONLY` is gone; `devedit`, `devexport`, `loot`, `droptalk` and `questlog` sit in the `--@debug@` block (`Init.lua:452-523`); the dispatcher (`:525-529`) is `if run then run(arg, rest) else ns:Toggle() end`. The dev test checks every word, and the packaged test checks that each one toggles the window in a release

**What's wrong.** `commands.devedit`, `devexport`, `loot` and `droptalk`
are defined outside the `--@debug@` block, and a separate table gates them:

```lua
local CHECKOUT_ONLY = { devedit = "MapEdit", devexport = "MapEdit", loot = "LootLog", droptalk = "Drops" }
...
local neededModule = CHECKOUT_ONLY[cmd]
local isAvailable = not neededModule or ns[neededModule].available
if run and isAvailable then
```

Each module sets `available = true` only inside its own `--@debug@` block
(`UI/MapEdit.lua:33-35`, `Core/Drops.lua:1428-1435`, `Core/LootLog.lua:36-37`).
`available` is therefore true exactly when the packager has left debug
blocks in, which is exactly when `Init.lua`'s own `--@debug@` block exists.

**Why it matters.** It is two ways of saying "checkout only" in one file,
and it costs a table, its 3-line comment and two lines of dispatcher.

**Evidence.** `grep -n "available" NeedRoll/UI/MapEdit.lua NeedRoll/Core/Drops.lua NeedRoll/Core/LootLog.lua`.
The dev and packaged smoke runs already exercise both cases.

**Fix.** Move the four commands into the existing `--@debug@` block,
delete `CHECKOUT_ONLY`, and the dispatcher becomes:

```lua
local run = commands[cmd]
if run then run(arg, rest) else ns:Toggle() end
```

Update the comment above the debug block to say releases treat these as
plain /nr.

### R3 · Guards left on calls that are in Forever's lists

- **Severity:** should fix
- **Area:** WoW API (and Redundant code)
- **Where:** `NeedRoll/Core/Items.lua:56-65` and `:72-77`; `NeedRoll/Core/Shopping.lua:137`, `:190`; the comment at `Items.lua:43-48`; `tests/smoke/modules/Core-Items.lua:91-95`
- **Status:** fixed in round 2 (uncommitted): `Items.lua` calls `C_TransmogCollection.*` directly with no wrapper `if`, and its comment is fixed; `Shopping.lua` drops the `Enum and` guards; the fallback test is gone. The stand-in lacks `GetAppearanceInfoBySource`, which is in Forever's GlobalAPI, so `Core-Items.lua:5-9` defines it. Its proper home is `tests/smoke/wow.lua` (cross-module)

**What's wrong.** The pass dropped guards on `C_Item`, `C_Map`,
`C_Reputation`, `C_Spell`, `C_TooltipInfo`, `C_Texture`, `C_CVar` and
others because Ketho's `forever` lists have them. In the same files it
kept the same kind of guard on calls that are just as present:

```lua
if transmog and transmog.GetItemInfo then _, sourceID = transmog.GetItemInfo(itemID) end
local info = transmog.GetAppearanceInfoBySource and transmog.GetAppearanceInfoBySource(sourceID)
    or (transmog.PlayerHasTransmog and transmog.PlayerHasTransmog(itemID)) or false
if C_TransmogCollection then ... end
if Enum and Enum.BagIndex then          -- Shopping.lua:137
if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag then   -- :190
```

The comment above `Items:Collected` still promises nil "on clients
without the collection", and the Items test checks the
`PlayerHasTransmog` fallback by setting `GetAppearanceInfoBySource = nil`.
Forever never takes that path.

**Why it matters.** "One way of doing each thing" (READABLE-CODE §6): a
reader can't tell why these guards stay when the others went, and the test
pins dead code in place.

**Evidence.** `GlobalAPI.lua` (forever) lists `C_TransmogCollection.GetItemInfo`,
`.GetAppearanceInfoBySource` and `.PlayerHasTransmog` (84
`C_TransmogCollection.` entries). `LuaEnum.lua` has `BagIndex` with
`ReagentBag = 5` and `CharacterBankTab_1..9`.

**Fix.** Call `C_TransmogCollection.*` directly. Drop the `if
C_TransmogCollection` wrapper around the three `ns:On` lines and the `Enum
and` guards. Fix the comment, and remove the fallback part of the Items
test. If `GetAppearanceInfoBySource` can return nil for a source (inferred
possible), keep `info and ... or PlayerHasTransmog(...)`; only the
existence checks go. `BANK_CONTAINER`, `NUM_BAG_SLOTS` and
`NUM_BANKBAGSLOTS` are FrameXML constants that aren't in any list, so
their `or` defaults can stay (see R12).

### R4 · `ns.IsSecret` is a wrapper that only calls `issecretvalue`

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/Core/Init.lua:241-244`; callers `Names.lua:262`, `Tooltip.lua:238,248`
- **Status:** fixed in round 2 (uncommitted): `ns.IsSecret` removed; `Names.lua` and `Tooltip.lua` call `issecretvalue`; `ns.Plain` stays (`Init.lua:225-232`) with the comment block

**What's wrong.**

```lua
function ns.IsSecret(value)
    return issecretvalue(value)
end
```

The brief asks to cut "needless wrappers". `issecretvalue` is the name
Ketho's annotations and Blizzard's code use, so it is the searchable one.
`ns.Plain` earns its place, since it turns a check into a value.

**Why it matters.** One more name for the same thing, and 4 lines.

**Evidence.** `issecretvalue` is in forever `GlobalAPI.lua`. It is called on
values that may be nil (`ns.Plain(nil)`, `Names.lua:262` with no first
line). The old copies checked `v == nil` first. As a C type test it takes
any argument, including an explicit nil (inferred; the stand-in accepts
nil and all three smoke modes pass).

**Fix.** Call `issecretvalue(...)` at the three call sites and have
`ns.Plain` call it. Keep the "Secret values" comment block, which is good.
Cross-module copies are listed under Redundant code below.

### R5 · Tests don't put globals and saved state back when they fail

- **Severity:** should fix
- **Area:** Readability (tests)
- **Where:**
  - `tests/smoke/modules/Core-Init.lua:214-219`: `C_ChatInfo.InChatMessagingLockdown` replaced, with an assert at 218 before the restore at 219
  - `Core-Init.lua:233-247`: `IsInGroup` replaced, asserts at 242-243 before the restore at 247
  - `Core-Init.lua:81-105`, `:110-124`, `:130-141`: modules changed, restored only at the end
  - `Core-Items.lua:69-97`: four `C_TransmogCollection` functions replaced, with eight asserts in between
  - `Core-LootLog.lua:84-90`: `GetLootRollItemLink`/`GetLootRollItemInfo` (an error in `W.Event` skips the restore); `:149-159` `C_Item.GetItemInfo`, asserts at 156-157 before the restore at 159
  - `Core-Wishlist.lua:200-206`: `C_Item.GetItemCount`/`IsEquippedItem`, asserts between override and restore
  - `Core-Tooltip.lua:74-76` (`ns.db.collectionTicks`), `:79-82` (`W.secretMode`), `:105-108` (`W.player.faction`)
  - `Core-Names.lua:191-194` (`W.secretMode`)
- **Status:** fixed in round 2 (uncommitted): every file has `Restoring(test, restore)` (xpcall, restore, rethrow). Each override listed above now goes through it or through `WithEmptyLog`, `WithValue` or `WithFacts`. `WithEmptyLog` also puts back the item facts, target and combat flags

**What's wrong.** The caller asked that tests "restore what they override
(also when they fail)". The files already have the right helper shape
(`AsRelease`, `WithEmptyLog`, `WithEmptyList`, `WithFacts`, `WithBags`:
`pcall`, restore, rethrow), but these spots override outside one.

**Why it matters.** A failing assert in one test leaves, for example,
`C_TransmogCollection.GetItemInfo` returning a fake source. Every later
tooltip-tick and loot-grid test then fails too, so one real failure shows
up as a dozen and the log points at the wrong file.

**Evidence.** Lines read as listed.

**Fix.** Wrap each override in the file's `With...` pattern. A small
generic helper per file keeps it short:

```lua
local function WithOverride(tbl, key, value, fn)
    local was = tbl[key]
    tbl[key] = value
    local ok, err = pcall(fn)
    tbl[key] = was
    if not ok then error(err, 0) end
end
```

The six near-identical `With...` helpers across the module files could
become one `W.With` in `tests/smoke/wow.lua`. That file belongs to another
group, so it is listed under cross-module.

### R6 · No test that each `/nr` command reaches its module; the packaged list misses two

- **Severity:** should fix
- **Area:** Readability (tests)
- **Where:** `tests/smoke/modules/Core-Init.lua:296-318`; compare `NeedRoll/Core/Init.lua:445-581`
- **Status:** fixed in round 2 (uncommitted): `Core-Init.lua:378-406`. `CheckCommands` swaps each target method for a recorder, restored even on failure, and checks the arguments: `loot all` -> `true`, `droptalk key Someone` -> `"someone"`, `droptalk probe` -> `nil`. The packaged list now covers every dev word (`:368-374`)

**What's wrong.** The if-chain became a table with aliases
(`skin`, `size`, `font`, `insigniadebug`). The module tests assert `style`,
`skin`, `text`, `size`, `font`, `reset`, `chipstyle`, `loot ...`, the
toggle fallback and seven dev commands in the packaged run. They never
check that `minimap`, `welcome`, `icondebug`, `insigniadebug`,
`framedebug`, `devedit [reset]`, `devexport`, `droptalk
clear|ping|probe|key|outbox|list`, `questlog [clear]`, `sounds`,
`fontdebug [reset]` or `linedump` call the right thing.
`scenarios.lua:1068-1082` runs most of them, but only checks that
nothing errors. The packaged list (`Core-Init.lua:312`) leaves out
`fontdebug` and `linedump`, which are dev-only as well.

**Why it matters.** Mike asked for `/nr` to stay identical, with dev-only
commands still plain `/nr` in releases. With a table, a wrong mapping such
as `commands.welcome = commands.minimap` errors nowhere and passes every
current test.

**Evidence.** `grep -n 'SlashCmdList.NEEDROLL' tests/smoke/modules/*.lua tests/smoke/scenarios.lua`.

**Fix.** Add one table-driven test. For each command line, swap the target
method for a recorder (inside a `pcall` + restore), run
`SlashCmdList.NEEDROLL(line)` and assert the recorder got the expected
arguments. Mark the dev rows `dev = true`. Add `fontdebug`, `linedump`,
`devedit reset`, `loot all` and `droptalk list` to the packaged loop at
`:312`.

### R7 · Constants for numbers used once, and two different `LOGIN_DELAY`s

- **Severity:** should fix
- **Area:** Readability
- **Where:** `Init.lua:258` (`local CVAR`), `:280-282` (`SEND_INTERVAL`, `LOCKDOWN_RETRY`, `LOGIN_DELAY`); `Names.lua:432-437` (`TICK`, `REDRAW_EVERY`, `REDRAWS`, `LOGIN_DELAY`); `LootLog.lua:187` (`BOSS_RECENT_SECONDS`), `:266-268` (`SCAN_BATCH`, `SCAN_GAP`, `SCAN_GIVE_UP`), `:398-399` (`FISH_COMBAT_WAIT`, `FISH_LOGIN_WAIT`); `Tooltip.lua:63` (`OWNER_DEPTH`); `Wishlist.lua:241` (`OTHER_SLOT_ORDER`)
- **Status:** fixed in round 2 (uncommitted): every listed constant is inline again, with its comment on the line. `ASKS_PER_TICK`, `TRIES`, `RETRY` and the `FISH_*` tunables stay, which is right

**What's wrong.** The brief says: "don't add a constant for a number used
once whose meaning is plain from its line." Each of these is used once.
Most replaced an inline number that already had a comment (`C_Timer.After(30,
...) -- Boss fights ... try again later`, `-- Items the server never
answers for: stop waiting after a while.` before `C_Timer.After(10, Done)`).
`Init.lua` `LOGIN_DELAY = 10` and `Names.lua` `LOGIN_DELAY = 1` are two
different values under one name. Grepping `LOGIN_DELAY` finds both, which
is the opposite of a searchable name (READABLE-CODE §7).

**Why it matters.** About 15 extra lines (R1). A reader also has to jump
to a definition to read a one-time delay.

**Evidence.** `grep -n` of each name in its file shows one use.

**Fix.** Put each number back inline with its comment on the line. Keep a
constant only where a number is shared or tuned with others: `SPAN`,
`FIRST_NEW` and the `FISH_*` sweep tunables that were there before, and
`SEND_INTERVAL` if you like, since "once a minute" is in its doc comment.
`ASKS_PER_TICK` and `TRIES`/`RETRY` were there before and can stay.

### R8 · A pasted export with a non-text `level` throws; the character name goes unescaped into the note

- **Severity:** should fix (pre-existing, not introduced by this change)
- **Area:** Security
- **Where:** `NeedRoll/Core/Wishlist.lua:588-596` (`ParseExport`)
- **Status:** fixed in round 2 (uncommitted) for the level and the name: `tonumber(char.level)` (`Wishlist.lua:547`) and `char.name:gsub("|", "||")` (`:545`). Tests cover `true`, `{}`, `"high"` and `"60"`, and a name full of `|H` and `|T` codes. The class is still unescaped: R13

**What's wrong.**

```lua
local char = type(data.character) == "table" and data.character or {}
if type(char.name) == "string" then who[#who + 1] = char.name end
local class = char.gameClass and Capitalized(char.gameClass)
if class and char.level then
    who[#who + 1] = ("%s %s"):format(class, char.level)
```

`char.level` comes straight from pasted JSON. `string.format("%s")` in Lua
5.1 throws on a boolean or table. `char.name` is joined into `note`, which
is saved to SavedVariables and shown in the Wishlist import box. Unlike
the list name, it doesn't go through `CleanName`, which strips `|` and `:`.

**Why it matters.** Pasting `{"items":[{"id":5}],"character":{"gameClass":"mage","level":true}}`
(or `"level":{}`) raises a Lua error from the import button. A shared
"export" whose character name holds `|T...|t` or `|H...|h` codes draws a
texture or a fake link in the note line. The caller asked that parsing of
pasted text end "unchanged or stricter". It is unchanged, and
`ParseExport` now has its own function, so this is the cheap moment to
make it stricter.

**Evidence.** `lua5.1 -e 'print(pcall(string.format, "%s %s", "Mage", true))'`
-> `false bad argument #3 ... (string expected, got boolean)`. The code was
the same at `HEAD`.

**Fix.** Accept `level` only as a number (`tonumber(char.level)`), and
run `char.name` through `WL:CleanName` (or at least `gsub("|", "||")`)
before it joins `who`. Add both cases to the sixtyupgrades test. If Mike
wants this pass to stay strictly behaviour-identical, leave the status
open and do it in a follow-up.

### R9 · Local numbers where Forever has `Enum.ItemQuality` and `Enum.ItemClass`

- **Severity:** nit
- **Area:** WoW API
- **Where:** `Items.lua:32-33` (`ITEM_CLASS_QUEST = 12`, `POOR, COMMON = 0, 1`, the latter new in this change); `LootLog.lua:39-40` (`ITEM_CLASS_RECIPE = 9`, `MIN_QUALITY = 2 -- Uncommon`)
- **Status:** fixed in round 2 (uncommitted): `Enum.ItemQuality.Poor/Common/Uncommon`, `Enum.ItemClass.Questitem/Recipe` and `Enum.LootSlotType.Item`, all in forever `LuaEnum.lua`

**What's wrong.** READABLE-CODE §2 asks for game values written the way
Ketho's annotations write them. Forever's `LuaEnum.lua` has
`ItemQuality.Poor = 0`, `.Common = 1`, `.Uncommon = 2`,
`ItemClass.Recipe = 9` and `.Questitem = 12`. `UI/LootGrid.lua:109` already
uses `Enum.ItemClass`.

**Fix.** `Enum.ItemQuality.Poor`/`.Common`/`.Uncommon`,
`Enum.ItemClass.Questitem`/`.Recipe`, and delete the four local constant
lines.

### R10 · A misplaced comment and two names that say less than the function does

- **Severity:** nit
- **Area:** Readability
- **Where:** `LootLog.lua:199-205`; `Names.lua:457`; `Init.lua:256-258`
- **Status:** fixed in round 2 (uncommitted): the `AddSighting` comment sits on the function; the functions are now `FillOrQueueNames` and `CombatLoggingStatus`; the cvar name is inline

**What's wrong.**
- `LootLog.lua:201-202`: the comment `-- kind: "roll", "group" ... or "link"
  (in chat, on `channel`).` documents `AddSighting`'s parameters, but it sits
  above `local linkedThisSession = {}`. Move it, with the two lines above
  it, directly over `local function AddSighting`.
- `FillKnownNames` also queues every unknown name and starts the
  `ns.Items:Load` of every item name. `FillOrQueueNames` would say so.
- `StartCombatLogging` also turns on Advanced Combat Logging and returns
  the status text for the login line. Name it after what the caller uses
  (`CombatLoggingStatus`) or say in the comment that it returns the text.
  `local CVAR` names only the kind of thing; `ADVANCED_LOG_CVAR` or the
  inline string (3 uses) would read better.

### R11 · Dev commands lost their nil guards

- **Severity:** nit
- **Area:** WoW API
- **Where:** `Init.lua:533-551` (`droptalk`), `:563-579` (`sounds`, `fontdebug`, `chipstyle`, `linedump`)
- **Status:** fixed in round 2 (uncommitted): `sounds`, `fontdebug`, `chipstyle` and `linedump` fall back to `ns:Toggle()`, and `droptalk` to `ns.Drops:Print()`, as at `HEAD`. Those fallbacks have no test: R16

**What's wrong.** At `HEAD`: `cmd == "sounds" and ns.SoundTest`,
`cmd == "fontdebug" and ns.FontDebug`, `cmd == "chipstyle" and
ns.RecipeBand`, `cmd == "linedump" and ns.LineDump`, and `droptalk`'s
`elseif arg == "list" or not ns.DropTalkWindow then ns.Drops:Print()`.
When the module was missing these fell back to toggling the window, or to
printing the drops. Now they index nil.

**Why it matters.** Only in a local checkout where one of those files
failed to load: the command then raises a second error instead of falling
back. Those files are in `UI/UI.xml` and always ship in a checkout, so in
practice nothing changes. It is still a behaviour difference in a pass
that promises none, so it should be a stated choice.

**Fix.** Either accept it and say so (fine by me, and shorter), or keep
the `droptalk` window fallback, the only one that printed something
useful instead of toggling.

### R12 · `BankBags` comment vs Forever's `Enum.BagIndex`

- **Severity:** nit (pre-existing code, new comment)
- **Area:** Readability
- **Where:** `Shopping.lua:124-140`
- **Status:** fixed in round 2 (uncommitted) as a comment: `Shopping.lua:121-124` now says that Forever's enum names -1 and 5 Keyring and ReagentBag, and that which IDs hold the bank hasn't been checked in game. The `/dump` check in game is still to do; behaviour is unchanged

**What's wrong.** The new comment says the list is "the bank itself and
its bag slots, plus the tabs of a tabbed character bank". In Forever's
`LuaEnum.lua`, `BagIndex.Keyring = -1`, `ReagentBag = 5` and
`CharacterBankTab_1..9 = 6..14`. So `BANK_CONTAINER or -1` is the keyring
if the constant is missing, and `NUM_BAG_SLOTS + 1` (5) is the reagent
bag, not a bank bag. Whether Forever's FrameXML defines `BANK_CONTAINER`
and `NUM_BANKBAGSLOTS` isn't in any list, so this is inferred.

**Why it matters.** If the inference holds, the reagent bag's contents are
saved as "In bank" and the comment states something the code doesn't do
(READABLE-CODE §9).

**Fix.** Check in game with `/dump BANK_CONTAINER, NUM_BAG_SLOTS,
NUM_BANKBAGSLOTS` at the bank. Then either correct the bag list or reword
the comment to what is known. A behaviour fix belongs in its own change.

### R13 · The export's class still goes into the note unescaped

- **Severity:** should fix
- **Area:** Security
- **Where:** `NeedRoll/Core/Wishlist.lua:546-552`
- **Status:** fixed in round 3 (uncommitted): `local class = char.gameClass and Capitalized(char.gameClass):gsub("|", "||")` (`Wishlist.lua:546`; inside `and`, only gsub's first result is kept). The comment above it now covers colors and line breaks. Tests: `"|CFFFF0000MAGE"` -> `||cffff0000mage`, `"WAR|NRIOR"` -> `War||nrior 60` (`Core-Wishlist.lua:265-269`). The unused `character = who` field stays; harmless

**What's wrong.** R8's fix doubles `|` in the character name, but not in
the class:

```lua
local class = char.gameClass and Capitalized(char.gameClass)
...
    who[#who + 1] = ("%s %s"):format(class, level)
elseif class then
    who[#who + 1] = class
```

`Capitalized` lowercases everything after the first letter. That breaks
`|H` and `|T`, which need capitals, but `|c` colors, `|r` and `|n` (new
line) work in lower case.

**Why it matters.** Someone can share an export with
`"gameClass": "x|cffff0000Officer approved|r"`. Pasting it shows fake
colored text in the import box's note line, and the note is saved with
the list. This is the input path R8 was about, and the fix there looks
complete when it isn't.

**Evidence.** In `lua5.1`, `Capitalized("x|cffff0000Fake|r|Hitem:1|h[Link]|h")`
returns `X|cffff0000fake|r|hitem:1|h[link]|h`: the color code is intact.
The test in `tests/smoke/modules/Core-Wishlist.lua` covers the name only.

**Fix.** Escape once, where the note is built, and drop the per-name gsub:

```lua
if #who > 0 then note = note .. "  ·  " .. (table.concat(who, ", "):gsub("|", "||")) end
```

Add a class with `|c` to the test. The returned `character = who` field is
read by nothing in NeedRoll (`grep -rn "\.character\b" NeedRoll` finds
only `data.character`), only by the tests. Drop it together with those
asserts, so there's no question which form it holds.

### R14 · `LootLog.available` is now read by nothing

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/Core/LootLog.lua:34`, `:37`
- **Status:** fixed in round 3 (uncommitted): `local LootLog = {}`; no `available` left (`grep -rn "LootLog.available" NeedRoll tests` finds nothing)

**What's wrong.** The file has `local LootLog = { available = false }` and,
in the debug block, `LootLog.available = true`. The only reader was
`CHECKOUT_ONLY` in `Init.lua`, which R2 removed. `MapEdit.available` and
`Drops.available` still have readers (`UI/Lists.lua:2054`,
`UI/LootGrid.lua:62`).

**Evidence.** `grep -rn "\.available" NeedRoll --include=*.lua`: the only
`LootLog` match is the line that sets it.

**Fix.** `local LootLog = {}`, and delete line 37 (2 lines). The file
header's "treats /nr loot as plain /nr" stays true.

### R15 · `if on == not self.byKey[key].off` leans on operator precedence

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/Core/Init.lua:202`
- **Status:** fixed in round 3 (uncommitted): `local isOnByDefault = not self.byKey[key].off` / `if on == isOnByDefault then` (`Init.lua:202-203`)

**What's wrong.** The code is correct: `not` binds tighter than `==`, so it
reads `on == (not off)`. All four cases were traced again. But a reader
has to know Lua's precedence table to see that it isn't
`not (on == off)`. READABLE-CODE says "a clear 10 lines beat a clever
4". Round 1's `local onByDefault = not self.byKey[key].off` cost one line
and needed no thought.

**Fix.** Bring back the named local, or add parentheses:
`if on == (not self.byKey[key].off) then`.

### R16 · The fallback branches R11 restored have no test

- **Severity:** nit
- **Area:** Readability (tests)
- **Where:** `tests/smoke/modules/Core-Init.lua:386-406`; code at `Init.lua:493` and `:505-522`
- **Status:** fixed in round 3 (uncommitted): `Core-Init.lua:406-426`, dev only. Each of `sounds`, `fontdebug`, `chipstyle` and `linedump`, with its tool set to nil inside `Restoring`, must toggle the window. `droptalk` with `ns.DropTalkWindow` set to nil must call `Drops:Print`, checked with `RecordedCall`

**What's wrong.** `CheckCommands` checks each word when its tool is
loaded. Nothing checks that `/nr sounds` (or `fontdebug`, `chipstyle`,
`linedump`) toggles the window when the tool is nil. Nothing checks that
`/nr droptalk` prints the drops when `ns.DropTalkWindow` is nil. These
are the branches round 1 found missing.

**Fix.** In the dev test, set `ns.SoundTest = nil` (and the others) inside
`Restoring` and assert the window toggled. Set `ns.DropTalkWindow = nil`
and assert `Drops:Print` was called, using `RecordedCall`.

### Round 3: removed guards, checked against Ketho's lists

The LootGrid review found guards removed for functions Forever doesn't
have, which the smoke tests hid because `tests/smoke/wow.lua` defines the
old globals. So for round 3, every guard or fallback this group removed
(taken from the `-` lines of `git diff HEAD`) was checked against freshly
downloaded `forever` copies of `GlobalAPI.lua`, `FrameXML.lua` and
`LuaEnum.lua`. `wow.lua` was not consulted. Every function below is in
`GlobalAPI.lua`:

- `issecretvalue`, `LoggingCombat`
- `C_CVar.GetCVarBool`, `C_CVar.SetCVar`
- `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted`, `C_ChatInfo.InChatMessagingLockdown`
- `C_Item.IsEquippedItem`, `C_Item.GetItemInfoInstant`, `C_Item.GetItemInfo`, `C_Item.GetItemQualityByID`
- `C_Map.GetMapInfo`, `C_Reputation.GetFactionDataByID`, `C_Spell.GetSpellName`
- `C_Texture.GetAtlasInfo`, `C_TooltipInfo.GetHyperlink`, `C_Container.GetContainerNumSlots`
- `C_TransmogCollection.GetItemInfo`, `.GetAppearanceInfoBySource`, `.PlayerHasTransmog`
- `GetLootRollItemLink`, `GetRealZoneText`, `UnitFactionGroup`

The enums are in `LuaEnum.lua`: `Enum.LootSlotType.Item = 1`,
`Enum.BagIndex.ReagentBag = 5`, `Enum.ItemQuality.Poor = 0`/`Common = 1`,
`Enum.ItemClass.Questitem = 12`/`Recipe = 9`.

The one removed fallback whose function is absent from both lists is
`GetFactionInfoByID`. It was only ever called when the
`C_Reputation.GetFactionDataByID` path returned nothing, and that
function is in the list, so the removal is right.

`ns.Data.instanceMapIDs` is addon data (`Data/Data.lua:468`).

A rough sweep of every global call in the 8 files, as capitalised
`Name(` or `C_X.Name(`, minus the addon's own function names, found
nothing missing from `GlobalAPI.lua`/`FrameXML.lua`. The only hit was
`ReadItem`, a local parameter.

The two cases the coordinator named:
- **`Items:Quality`** didn't lose its fallback.
  `C_Item.GetItemQualityByID(itemID) or select(3, C_Item.GetItemInfo(itemID)) or Enum.ItemQuality.Common`
  (`Items.lua:33-34`): the last `or` is the old `or 1`, written as the
  enum (`Common = 1`), so the result is never nil and callers still always
  get a number.
- **`C_TransmogCollection.GetItemInfo`** is in forever `GlobalAPI.lua`, as
  are `GetAppearanceInfoBySource` and `PlayerHasTransmog`. Nothing in
  `Items.lua` touches `C_TransmogCollection` at load time any more: the
  file only registers the three `TRANSMOG_COLLECTION_*` events, which are
  in `Events.lua`. So there is no load-time error. `GetItemInfo` returning
  nil for an item with no look was already handled (`NO_LOOK`).

The stand-in's gap runs the other way: `wow.lua` *lacks*
`GetAppearanceInfoBySource`, which Forever has. `Core-Items.lua:5-9`
fills it in (cross-module note).

## Area notes

### Readability

Checked names, function splits, guard clauses, comments and formatting
against `docs/READABLE-CODE.md` and the brief. Sound: renames are
consistently in game terms (`countedLoot`, `lootWindowCount`, `holders`,
`namesWithoutID`, `dropSources`, `madeLines`), and booleans read as
questions (`isBankOpen`, `isPruned`, `isScanning`). No single-letter
locals are left, apart from `u`/`v` in `CroppedAtlasMarkup`, which are
the usual names for texture coordinates and carry a comment. The `Tick`
rewrite in `Names.lua` is clearer and was traced to the same behaviour:
secret kinds end an entry at once, waiting entries go back in the queue
without counting a try, `SetName`'s `false` ("in no set") ends an entry
without saving. `Modules:Set` was traced for all four cases (on or off by
default x on or off). Every caller passes a boolean (`UI/Settings.lua:504`),
so the `on == nil` difference can't happen. Indentation 4 spaces, LF, no
lines over 120 apart from single `L[...]` literals. No change narration in
comments. Findings: R1, R7, R10, R12. Tests: R5, R6.

### WoW API

Every call whose guard or fallback was dropped, plus every new call,
checked against Ketho's BlizzardInterfaceResources `forever` branch
(downloaded `GlobalAPI.lua`, `FrameXML.lua`, `LuaEnum.lua`, `Events.lua`,
`WidgetAPI.lua`; grepped for the quoted name). The brief asked to check
both lists for Lua-defined functions: `GetCVarBool` and `SetCVar` are in
`FrameXML.lua` only (Blizzard's Lua), and the code now uses the C API
`C_CVar.GetCVarBool`/`C_CVar.SetCVar`, which `GlobalAPI.lua` has.
`GetFactionInfoByID` is in neither list, so its fallback was dead and
removing it is right. No dropped guard is a load-time error: every name
below is in Forever, and `tests/smoke/wow.lua` mirrors each one (lines
1086, 1226-1230, 1381, 1421-1422, 1457, 1502, 1545, 1577).

| Name | Kind | Forever list | Where looked |
| --- | --- | --- | --- |
| `issecretvalue` | global function | yes | GlobalAPI.lua |
| `LoggingCombat` | global function | yes | GlobalAPI.lua |
| `C_CVar.GetCVarBool`, `C_CVar.SetCVar` | C API | yes | GlobalAPI.lua (`GetCVarBool`/`SetCVar` globals: FrameXML.lua only, no longer used) |
| `GetFactionInfoByID` | global function | **no** (neither list): fallback correctly removed | GlobalAPI.lua, FrameXML.lua |
| `C_Reputation.GetFactionDataByID` | C API | yes | GlobalAPI.lua |
| `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted`, `C_ChatInfo.InChatMessagingLockdown` | C API | yes | GlobalAPI.lua |
| `C_Map.GetMapInfo`, `C_Map.GetBestMapForUnit` | C API | yes | GlobalAPI.lua |
| `C_Spell.GetSpellName` | C API | yes | GlobalAPI.lua |
| `C_TooltipInfo.GetHyperlink` | C API | yes | GlobalAPI.lua |
| `GetRealZoneText`, `UnitFactionGroup` | global function | yes | GlobalAPI.lua |
| `C_Item.GetItemInfoInstant`, `C_Item.IsEquippedItem`, `C_Item.GetItemQualityByID`, `C_Item.IsItemDataCachedByID`, `C_Item.GetItemNameByID`, `C_Item.GetItemCount`, `C_Item.RequestLoadItemDataByID` | C API | yes | GlobalAPI.lua |
| `C_Texture.GetAtlasInfo` | C API | yes | GlobalAPI.lua |
| `GetLootRollItemLink`, `GetLootSourceInfo`, `GetLootSlotType`, `GetLootSlotLink`, `GetLootSlotInfo`, `GetNumLootItems` | global function | yes | GlobalAPI.lua |
| `C_Container.GetContainerNumSlots` | C API | yes | GlobalAPI.lua |
| `C_TransmogCollection.GetItemInfo`, `.GetAppearanceInfoBySource`, `.PlayerHasTransmog` | C API | yes (guards still in place, R3) | GlobalAPI.lua |
| `strtrim`, `InCombatLockdown`, `UnitAffectingCombat` | global function | yes | GlobalAPI.lua |
| `Enum.LootSlotType.Item` | Enum | yes (`Item = 1`) | LuaEnum.lua |
| `Enum.BagIndex` (`ReagentBag`, `CharacterBankTab_*`) | Enum | yes | LuaEnum.lua |
| `Enum.TooltipDataType` | Enum | yes | LuaEnum.lua |
| `ITEM_DATA_LOAD_RESULT`, `LOOT_READY`, `LOOT_OPENED`, `LOOT_CLOSED`, `ENCOUNTER_END`, `START_LOOT_ROLL`, `CHAT_MSG_LOOT`, `CHAT_MSG_INSTANCE_CHAT_LEADER`, `BANKFRAME_OPENED`, `BANKFRAME_CLOSED`, `PLAYERBANKSLOTS_CHANGED`, `BAG_UPDATE_DELAYED`, `TRANSMOG_COLLECTION_*` (3), `GROUP_ROSTER_UPDATE`, `CHAT_MSG_ADDON` | events (unchanged) | yes | Events.lua |
| `HasSecretValues`, `IsForbidden`, `GetStringWidth`, `SetDesaturated` | widget methods | yes | WidgetAPI.lua |
| `TooltipDataProcessor.AddTooltipPostCall` | FrameXML table | inferred (global tables aren't listed); guard kept, unchanged | FrameXML.lua (no entry) |
| `BANK_CONTAINER`, `NUM_BAG_SLOTS`, `NUM_BANKBAGSLOTS`, `GameTooltipText`, `BACK` | FrameXML globals | inferred, `or` defaults kept, unchanged | none of the lists |

Round 2 additions to the table above: `Enum.ItemQuality.Poor/Common/Uncommon`
(`LuaEnum.lua:5093-5096`), and `Enum.ItemClass.Recipe` (= 9) and
`.Questitem` (= 12) (`LuaEnum.lua:4652`, `:4655`): yes. The
`C_TransmogCollection.*` and `Enum.BagIndex` uses are now unguarded, and
all are in the lists. `ns.Data.instanceMapIDs`, no longer guarded in
`API.lua`, is set at `Data/Data.lua:468`, which loads first. The stand-in
`tests/smoke/wow.lua` lacks `C_TransmogCollection.GetAppearanceInfoBySource`.
`Core-Items.lua:5-9` adds it when the module loads, before any scenario
runs (`run.lua` loads every module file before it runs the scenario list).
The brief allows that, and it is listed as cross-module.

Secret values (round 2: `ns.IsSecret` is gone; callers use `issecretvalue`
directly and `ns.Plain` stays). `ns.Plain` and `issecretvalue` behave like
the three copies they replace (`LootLog` `Plain`, `Tooltip` `Secret`, the checks in `Names`
`Text`/`TooltipLines`). Each returned nil or false for nil and for secrets
and passed other values through. The only difference is that
`issecretvalue` is now also called with nil, where the old code
short-circuited first. That is inferred safe (a C type test on any
argument) and is covered by the `--secret` smoke run. No new globals. No
function near the 60-upvalue limit (`luac5.1 -p` passes; the largest new
closure, `ParseJSON`, uses under 10). No protected frames and no combat
changes. `Names` still skips its ticks during `InCombatLockdown()`.
Player-facing strings: the set of `L["..."]` keys is unchanged. Dev-only
code stays inside `--@debug@` (`LootLog.lua:36` to end, `Init.lua:252-270`,
`:556-581`). `docs/STYLE-GUIDE.md` isn't needed: no UI size, color or
layout changes (`CroppedAtlasMarkup` produces the same markup as before).
Findings: R3, R9, R11.

### Redundant code

Compared against `ns.Items:Load` (still the one loader; `ScanIDs` now
passes `Checked` straight to it), `ns.Tooltip:Forget`,
`ns.Wishlist:Sources` (shared by `API.lua`'s `FirstShowable`), and the
`T:` helpers (none duplicated; Core files don't draw UI). Good cuts: the
three secret-value copies into one, the `LootLog` `FishedIDs`/`FishStatus`
local+wrapper pairs into methods, Shopping's `List()` into `Entries()`,
`API.lua`'s `STANDINGS` copy into `ns.Names.STANDINGS`, and the two run
and clear chance loops in Wishlist into one. Findings: R1, R2, R4, R7.

Cross-module (other groups' files; not for this group to fix):
- `tests/smoke/wow.lua`: add `C_TransmogCollection.GetAppearanceInfoBySource`
  (in Forever's GlobalAPI) and drop the stand-in at
  `tests/smoke/modules/Core-Items.lua:5-9`.
- `tests/smoke/modules/*.lua`: `Restoring` was copied into all 8 files;
  fixed at integration, they now use `W.Restoring` from `wow.lua` (#596), with
  `W` passed into the file-level helpers. `Printed` is still in 2 files.
- `NeedRoll/Core/Drops.lua:90-93`: `local function Plain(v)` is the same as
  `ns.Plain` (`Init.lua:247`).
- `NeedRoll/UI/MainFrame.lua:276-277`: `Plain(v)` returns a boolean, "not
  nil and not secret". Use `ns.Plain(v) ~= nil`, or rename it, since the
  same name with a different meaning misleads.
- `NeedRoll/UI/LootGrid.lua:987`: `issecretvalue and issecretvalue(lines)`
  is a guard Forever doesn't need (`issecretvalue` is in GlobalAPI).
- `tests/smoke/wow.lua`: a shared `W.With(tbl, key, value, fn)` would
  replace the six per-file `With...` helpers (R5) and the two copies of
  `Printed` (`Core-Init.lua:23`, `Core-LootLog.lua:30`).

### Security

Untrusted inputs this change touches:
- **Round 2:** `ParseExport` now drops a non-numeric level and escapes the
  name (R8). The class is still unescaped (R13). The share-string parser
  and `ParseJSON` are unchanged since round 1 (re-read in full).
- **Wishlist share strings** (`WL:Parse` -> `ParseShareString`): same
  pattern `SHARE_PREFIX .. ":([^:]*):([%w%.]+)"`, same `tonumber(code, 36)`
  with `> 0` and de-duplication, and the name still goes through
  `CleanName` (strips `:|\n\r`, 40 letters). Unchanged. There was no upper
  bound on item IDs before and there still isn't (pre-existing, harmless:
  unknown IDs only fail to load).
- **sixtyupgrades JSON** (`ParseJSON`): the split reader was traced against
  the old one: the same grammar, the same failures (trailing comma,
  missing colon, unterminated string), `\u` above ASCII still becomes "?",
  and everything still runs inside one `pcall`, so deep nesting still ends
  in a caught error. The smoke test covers escapes, exponents, `null`,
  nested objects, trailing commas and empty input. Pre-existing gap: R8.
- **Addon messages** (`Version:Heard`): `^V:(.+)$` plus `ParseVersion`'s
  anchored `^v?(%d+)%.(%d+)%.(%d+)$` are unchanged. Replies are still once
  per sender per session and at most once a minute per target.
- **Chat and loot text** (`LootLog`, dev only): still passed through
  `Plain` before use, links matched with `item:(%d+)`.
- **SavedVariables:** keys and formats unchanged (`modules`, `names`
  `{ locale, npc, quest, set }`, `bank`/`bags`/`characters`, `wishlist`,
  `lootLog`, `lootScan`, `fish`, `newestVersion`). Queue entries in
  `Names.lua` changed shape but live only in memory.
- No names or credits reach `NeedRoll/Credits.txt` or a release; no
  `loadstring`/`RunScript`.

## Round history

- 2026-10-17, round 1, `c0e5c79` + uncommitted: **Changes needed**. Opened R1-R12 (1 blocking, 7 should fix, 4 nits).
- 2026-10-18, round 2, `c0e5c79` + uncommitted fixes: **Changes needed** (0 blocking, 1 should fix, 3 nits). Closed R1-R12; opened R13 (should fix) and R14-R16 (nits).
- 2026-10-18, round 3 (final), `c0e5c79` + uncommitted fixes: **Ready** (0 open). Closed R13-R16; re-checked every removed guard against Ketho's `forever` lists, and none is missing in Forever.
