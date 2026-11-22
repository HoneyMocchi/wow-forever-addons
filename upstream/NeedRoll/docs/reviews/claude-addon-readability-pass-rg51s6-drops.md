# Review: Readability pass, Core/Drops.lua (drop and quest sharing over addon messages)

| | |
| --- | --- |
| Branch | `rp-drops` (group worktree of `claude/addon-readability-pass-rg51s6`) into `dev` (PR not opened yet) |
| Commit reviewed | `c0e5c79` plus uncommitted changes (`NeedRoll/Core/Drops.lua` modified, `tests/smoke/modules/Core-Drops.lua` new), round 2 working tree |
| Date | 2026-10-17 |
| Round | 2 |
| Verdict | **Ready** (0 blocking; R2 accepted by Mike (longer file, fewer code lines), R3 goes to a follow-up security PR; no nits open) |
| Needs | `/reload` is enough: one existing Lua file changed, no TOC, SavedVariables or XML change. The new test file isn't shipped (`.pkgmeta` ignores `tests`). |

## What the change does

Nothing a player should see is meant to change. `Core/Drops.lua` (saving the
player's boss drops and new quests, sending them as `D2`/`Q1` addon messages
to the guild and the `NeedRollDropSharing` channel, reading other players'
messages, answering Mike's probes, and the dev-only `/nr droptalk` and quest
log tools) is renamed and reorganised: short locals get full names
(`f` -> `fields`, `q` -> `report`, `encounter` -> `currentEncounter`,
`stopped` -> `stoppedThisSession`), repeated blocks become helpers
(`SplitMessage`, `DropOldest`, `AddToCorpse`, `SlotItemID`, `ItemIDOf`,
`Destination`, `Refusal`, `TallyBossItems`, `QuestWindowSource`,
`OpenQuestID`, `AcceptedQuestID`, `QuestLogInfo`, `SaveWhenLoaded`), long
functions are split (`Answer` into `KillMessages`/`AddKillAnswers`/
`AddQuestAnswers`; `Take` into `TakeKill`/`TakeOldDrop`/`TakeQuestReport`,
picked through a `TAKE` table; `Drops:Print` into `PrintBoss`), the quest
giver moves from an array (`giver[1]..giver[6]`) to a keyed table, and
`Drops:Decode` (unused) is removed. Round 2 swaps hand-numbered item values for
the game's `Enum` names (which also fixes R1) and drops existence guards on
calls Forever has. It also exposes `PROBERS` as `Drops.probers` inside
`--@debug@` so a test can add a made-up prober. A new module test file adds
16 smoke scenarios.

## Scope

- `NeedRoll/Core/Drops.lua`: the refactor above. Round 2: 1909 -> 1942 lines
  (code 1384 -> 1380, comments 381 -> 399, blank 144 -> 163). The shipped
  part (before `--@debug@`, now at line 1471) went from 1427 to 1470 lines
  (code 1017 -> 1028); the dev-only part went from 481 to 471.
  (Round 1 was 2035 lines.)
- `tests/smoke/modules/Core-Drops.lua` (new, 491 lines): 13 scenarios plus
  3 dev-only, run after `scenarios.lua`. At load it also defines
  `Enum.ItemMiscellaneousSubclass` if the stand-in lacks it.
- Generated data: none touched. `NeedRoll/Data/Bosses.lua` was read only to
  confirm the `{ name, display, level, rank, NPC ID }` comment on
  `KnownBosses` (it matches `Bosses.lua:7-8`).

## Checks

Round 2 (round 1 results are in Round history and in each finding):

| Check | Result |
| --- | --- |
| `luac5.1 -p NeedRoll/Core/Drops.lua tests/smoke/modules/Core-Drops.lua` | Passed |
| `luacheck --no-global -q` before (`git show HEAD:`) / after | 32 warnings before; after: 20 across both files, all `W212 unused argument self` on `Drops:` methods. No new warning |
| `luacheck --std lua51` global reads | No undefined global that Ketho's `forever` lists lack. Every global read was checked by name (WoW API notes); `BIND_ON_PICKUP` is gone |
| `python3 tools/locales.py --check` | Passed (exit 0) |
| `python3 tools/translations.py` | Ran, exit 0 |
| `tests/smoke/check.sh` | All passed in all three runs: dev (183 files), packaged (178), dev with secret values (183). The 16 `Core/Drops:` scenarios pass: 16 in dev and secret, and the 13 non-dev ones in packaged (45 `ok` lines) |
| R1 probe (roll not flagged BoP, item binds on pickup) | Now a committed module scenario ("an item with no corpse after a boss kill is a guessed drop if BoP"); passes in all three runs |
| `cd scraper && python3 -m unittest discover -s tests` | Not run: no scraper change |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | blocking | WoW API / Readability | `Drops.lua:829`, `:851`, `:885` (round 1) | `BIND_ON_PICKUP` is read before its `local` exists, so `Guess` compares against a nil global and guessed drops are lost | fixed in round 2 (uncommitted) |
| R2 | should fix | Redundant code | `Drops.lua` whole file | The file grew by 126 lines (all in shipped code); the pass is meant to shrink it | partly fixed in round 2 (+33 lines, code -4); rest left for Mike |
| R3 | should fix | Security | decoders `DecodeKill`, `Decode`, `DecodeQuest` | Numeric fields accept `nan`, `inf`, `-5`, `0x1F`, `1e5`: a stranger's message raises a Lua error, and IDs are unbounded (pre-existing) | left as is: follow-up PR |
| R4 | should fix | Security | `tests/smoke/modules/Core-Drops.lua` (round 1 `:288-299`) | The test spells out which character name the first `PROBERS` key belongs to | fixed in round 2 (uncommitted) |
| R5 | should fix | Readability | `DropOldest`, `Refusal` comments | Two new comments say something the code doesn't do | fixed in round 2 (uncommitted) |
| R6 | should fix | Redundant code / WoW API | see section | Dead fallbacks for globals Forever doesn't have, and hand-numbered enums Forever lists | fixed in round 2 (uncommitted) |
| R7 | should fix | Readability | see section | Comments that restate the function name or the line below | fixed in round 2 (uncommitted) |
| R8 | should fix | Readability (tests) | `tests/smoke/modules/Core-Drops.lua` | Rewritten paths have no test (the one that would have caught R1 among them); two clean-up gaps | fixed in round 2 (uncommitted), except the third-throttle test: left as is (reason in section) |
| R9 | nit | Readability | `RewardHash` | One-use constants in `RewardHash`, while `Hash` keeps the literal | fixed in round 2 (uncommitted) |
| R10 | nit | Redundant code | `RewardIDs`, `RewardItems` | Two item-link parses don't use the new `ItemIDOf` | fixed in round 2 (uncommitted) |
| R11 | nit | Redundant code | `AddToCorpse` | `AddToCorpse` parses a GUID its callers just parsed | fixed in round 2 (uncommitted) |
| R12 | nit | Readability (tests) | `tests/smoke/modules/Core-Drops.lua:385` | The guessed-drop test's clean-up can raise its own error and hide why the test failed | fixed after round 2 (nil check in the clean-up) |

### R1 · `BIND_ON_PICKUP` is read before its `local` exists, so guessed drops are lost

- **Severity:** blocking
- **Area:** WoW API / Readability
- **Where:** `NeedRoll/Core/Drops.lua:829` (use), `:851` (declaration), `:885` (second use, fine)
- **Status:** fixed in round 2 (uncommitted). `Guess` now reads `Plain(bind) == Enum.ItemBind.OnAcquire` (`Drops.lua:790`), `Wanted` the same (`:839`); the local is gone and `luacheck --std lua51` reports no `BIND_ON_PICKUP`. The probe is now a module scenario covering a roll with `bop = false` (BoP item: guessed), a Bind on Equip roll (not guessed) and area loot with no readable corpse (guessed); it passes in all three runs

**What's wrong.** The pass replaced the literal `1` with a named constant, but
declared the constant 22 lines below the first function that uses it:

```lua
-- Drops.lua:822-829
local function Guess(itemID, count, isBindOnPickup)
    ...
        local bind = select(14, C_Item.GetItemInfo(itemID))
        if not (isBindOnPickup or Plain(bind) == BIND_ON_PICKUP) then return end
-- Drops.lua:851
local BIND_ON_PICKUP = 1 -- Enum.ItemBind
```

In Lua a `local` is only visible to code written after it, so inside `Guess`
the name `BIND_ON_PICKUP` is the global of that name. WoW: Forever has no such
global (only `ITEM_BIND_ON_PICKUP = "Binds when picked up"`), so the test
reads `Plain(bind) == nil`. The old code compared with `1`.

**Why it matters.** `Guess` records "probably dropped by the boss just killed"
items when the game won't say whose corpse they came from. It is called from
`START_LOOT_ROLL` with the roll's own BoP flag (`:839`) and from `Scan` for
area loot whose source can't be read, with no flag at all (`:960`). With the
flag missing or false, a Bind on Pickup item (bind `1`) now fails the check
and is dropped: no saved guess, no `D2 ... g` message. The reverse also
happens: an item whose binding comes back secret (`Plain` turns it into nil)
now passes the check and is recorded as a guessed BoP drop. A player sees
nothing; the shared data quietly loses the guessed drops it exists to
collect. If any other addon ever leaks a global `BIND_ON_PICKUP`, the
behaviour changes again.

**Evidence.**
- `luacheck --std lua51 NeedRoll/Core/Drops.lua`: `829:50: (W113) accessing
  undefined variable 'BIND_ON_PICKUP'`; the same run on `HEAD`'s file has no
  such read. The brief's `luacheck --no-global` run cannot see it.
- Ketho `forever` `GlobalStrings/enUS.lua`: `grep BIND_ON_PICKUP` finds only
  line 12660 `ITEM_BIND_ON_PICKUP`; `GlobalAPI.lua`, `FrameXML.lua`,
  `LuaEnum.lua` have no global `BIND_ON_PICKUP`.
- Probe scenario in a scratch copy of the worktree: kill a boss, then
  `START_LOOT_ROLL` for item 299124 with `GetLootRollItemInfo` returning
  `bop = false` (the stand-in's `C_Item.GetItemInfo` gives bind `1`). New file:
  `FAIL ... no guessed drop for a BoP item whose roll said not BoP`. `HEAD`'s
  file: `ok`. The existing scenario `loot roll after a boss: guessed drop`
  (`scenarios.lua:946`) passes `bop = true`, so it never reaches the broken
  comparison.

**Fix.** Use the game's enum and drop the hand-made constant (both uses):

```lua
if not (isBindOnPickup or Plain(bind) == Enum.ItemBind.OnAcquire) then return end
...
return class == QUEST_CLASS or class == RECIPE_CLASS or bind == Enum.ItemBind.OnAcquire
```

`Enum.ItemBind.OnAcquire = 1` is in Ketho's `forever` `LuaEnum.lua:4630-4632`
and in the stand-in (`tests/smoke/wow.lua:1085`). Moving the constants block
above `Guess` would also work. Add the probe above as a module scenario (see
R8) so this can't come back.

### R2 · The file grew by 126 lines; the pass is meant to shrink it

- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/Core/Drops.lua` (whole file)
- **Status:** partly fixed in round 2: 1942 lines against 1909 at `HEAD` (round 1: 2035). Code is 4 lines shorter (1380 vs 1384); the +33 are blank lines between the new helpers (+19) and comments (+18), including the three message-format lines wrapped to stay within 120 columns. I found no restating comment left to cut (R7), and cutting the blank lines would go against the file's style. The rest is left for Mike, as the brief allows

**What's wrong.** Mike's brief: "Less code is the aim: the group should end
up shorter than it started." The file went from 1909 to 2035 lines: +31 code,
+73 comment, +22 blank. 126 comment lines were added and 54 removed. All of
the growth is in the shipped part (1427 -> 1552 lines before `--@debug@`).

**Why it matters.** This is the goal Mike set for the whole pass; a group that
grows works against it. Some helpers pay for themselves (`SplitMessage` folds
three copies, `DropOldest` three, `TallyBossItems` two, `QuestWindowSource`
two, `Refusal` replaces two near-identical loops). Others add a function
header, a comment and a blank line for one call site, and many comments say
what the function name already says (R7).

**Evidence.** `wc -l` and an `awk` count of blank, comment and code lines on
`git show HEAD:NeedRoll/Core/Drops.lua` and the working file; added comment
lines counted from `git diff HEAD -U0`.

**Fix.** Cut, in this order, then report the count:
1. Restating comments listed in R7 (about 15 lines).
2. Dead fallbacks and hand-numbered enums in R6 (about 8 lines).
3. One-use constants in R9 (2 lines).
4. Fold `SavedBoss` (`:209-226`) back into `Save`: it has one caller and no
   name anyone greps for (about 4 lines). The same goes for the `Take`
   dispatcher (`:1503-1507`) if `CHAT_MSG_ADDON` calls `TakeKill`/
   `TakeOldDrop`/`TakeQuestReport` directly.
5. Blank lines added between one-line helpers.

If the file still comes out longer than 1909, say in the hand-back which
added lines stay and why (Mike decides, as the brief allows). Keep the
comments that explain a game fact (the chat filter's argument order,
the GROUP outbox entries from older versions, the D2/Q1 format wrap).

### R3 · Numeric fields accept `nan`, `inf`, negatives and hex; a stranger's message raises a Lua error (pre-existing)

- **Severity:** should fix (in a follow-up PR, not this one)
- **Area:** Security
- **Where:** `DecodeKill` `Drops.lua:331-336`, `Decode` `:354-358`,
  `DecodeQuest` `:1061-1078`; the save paths `SavedBoss` `:210-226`,
  `SaveQuest` `:1009-1037`
- **Status:** left as is: follow-up PR (coordinator, round 2). Re-checked in round 2: the decoders are unchanged from round 1 and from `HEAD` (same `tonumber` on the same fields), so this change neither causes nor worsens it

**What's wrong.** Every numeric field of a heard message goes through a bare
`tonumber(fields[n])`. Only the item list (`^(%d+)%.(%d+)(g?)$`) and the kill
key (`^%d+%-%x+$`) are anchored. Lua 5.1's `tonumber` uses C `strtod`, so
`"nan"`, `"inf"`, `"-5"`, `"0x1F"`, `"1e5"` and `" 7"` all become numbers.
The checks after it (`kill.instance > 1`, `kill.npc` truthy) let `inf` and
`nan` through, and nothing limits the size of an ID.

**Why it matters.** Anyone on the realm channel or in the guild can send:
- `D2:d:9900:1:0:nan:1-AA01:60000:5187.1` -> `SavedBoss` does
  `inst.bosses[nan] = boss` -> **`table index is NaN`** inside the
  `CHAT_MSG_ADDON` handler. `ns:On` handlers run without `pcall`
  (`Core/Init.lua:95-97`), so every such message is a Lua error on every
  NeedRoll copy that hears it (an error popup with script errors on, or
  BugSack noise), and later handlers for that event are skipped.
- `D2:d:inf:...` -> saved as `ns.db.drops[inf]`. How the client writes an
  infinite key into `NeedRollDB` on logout is not documented; if it writes
  something that won't parse back, the whole SavedVariables file fails to
  load (inferred, not tested in game).
- Every distinct instance and NPC ID makes a new saved entry; only kills
  per boss (50), quests (500) and the outbox (300) are capped, so a flood
  of made-up IDs grows `NeedRollDB.drops` without bound.

This is not caused by this change: the old decoders are the same, field for
field (compared line by line: `SplitMessage` returns the same first 3, 4 or 5
captures the old patterns did, and every validity check is unchanged). The
change is no looser.

**Evidence.** `lua5.1 -e 'print(tonumber("nan"), tonumber("inf"),
tonumber("-5"), tonumber("0x1F"), tonumber("1e5"), tonumber(" 7"))'` prints
`nan inf -5 31 100000 7`. Probe in a scratch copy: the `nan` message fails
with `NeedRoll/Core/Drops.lua:207: table index is NaN` (traceback through
`Save` -> `Take`), on the old file and the new one. The `inf` message is
saved (`ns.db.drops[math.huge] ~= nil`). That WoW's Lua `tonumber` takes
`nan`/`inf` the same way is inferred from it being Lua 5.1 over the C
runtime's `strtod`.

**Does a length or range check belong in this PR?** No. The brief allows
"unchanged or stricter", but this PR's promise is "behaviour identical", and
a stricter decoder changes which messages from older copies are accepted. It
needs its own scenarios and its own review round, and keeping it apart keeps
this diff a pure refactor. Do it as the next PR, soon, since a stranger can
trigger the error today. The implementer's note that huge all-digit fields
aren't rejected is right, but `nan`/`inf` matter more than size: a 250-digit
field becomes `1e+250`, which is finite and harmless as a key.

**Fix (follow-up).** One helper used for every numeric field in all three
decoders:

```lua
-- A message field that must be a plain whole number: digits only, at most
-- 10 of them (IDs and builds fit), else nil.
local function WholeNumber(field)
    if not field or #field > 10 or not field:match("^%d+$") then return nil end
    return tonumber(field)
end
```

Then `instance = WholeNumber(fields[3])` and so on, keeping the `> 1` and
`> 0` checks. Add module scenarios for `nan`, `inf`, `-5`, `0x1F`, `1e5` and
an 11-digit ID in each numeric position. Capping distinct heard instances
and bosses is a separate question for Mike.

### R4 · The test spells out which character name the first `PROBERS` key belongs to

- **Severity:** should fix
- **Area:** Security
- **Where:** `tests/smoke/modules/Core-Drops.lua:288-289`, `:298-299`
- **Status:** fixed in round 2 (uncommitted). The hashing is pinned with a made-up name (`ProberKey("Made Name") == "049742bbc3b3d863"`, test `:301-306`). The "listed character" scenario adds that key to `Drops.probers` and removes it afterwards (`:310-336`, `dev = true`). `Drops.probers = PROBERS` is at `Drops.lua:1481`, inside the `--@debug@` block (`:1471`-`:1942`), so release zips don't have it (the packager comments the block out; `tests/smoke/run.lua:54` strips it in the packaged run, and the packaged run passes without the dev scenario). The example names in `Drops.lua` comments are now "Ann"/"Ann Smith". `scenarios.lua:1078` still says `droptalk key Flow Burn` (another group's file; under Cross-module)

**What's wrong.**

```lua
local key = ns.Drops:ProberKey("Flow Burn")
assert(key == "41dfb5a8e3d17196", "a prober key changed, so PROBERS no longer matches: " .. key)
```

`41dfb5a8e3d17196` is the first entry of `PROBERS` (`Drops.lua:1328-1334`,
"Mike's characters"). `Drops.lua:1315-1316` says PROBERS "holds keys
(Drops:ProberKey) rather than names, so the characters aren't spelled out
here". The test writes down the name for that key.

**Why it matters.** Root `CLAUDE.md`: character names stay in the private
repo and must be checked before anything goes public. `tests/` doesn't ship
in the zip, but a public copy of the addon repo would carry it. The test makes
it explicit that "Flow Burn" is one of the characters whose probes every copy
answers. That is mitigated (not removed): "Flow Burn" already appears in a
shipped comment (`Drops.lua:1294`) and in `scenarios.lua:1078`, so the link
could already be found by hashing it. Whether "Flow Burn" is a real character
of Mike's is not known to me (inferred from it being the first key and the
stand-in player being "Flow").

**Evidence.** Lines quoted above; `grep -rn "Flow Burn"` over the repo.

**Fix.** Check the hashing with a made-up name and its expected key (pin the
algorithm, not a real prober), and keep the "listed character's probe is
answered" scenario only if Mike confirms "Flow Burn" is fine to name.
Otherwise the scenario needs a test-only way in (for example a dev-only
`Drops.extraProbers` read inside `--@debug@`), which is Mike's call.

### R5 · Two new comments say something the code doesn't do

- **Severity:** should fix
- **Area:** Readability (READABLE-CODE.md rule 9)
- **Where:** `Drops.lua:198-199`, `:530-534`
- **Status:** fixed in round 2 (uncommitted): `DropOldest` now says "callers save one entry, or one loot window, at a time"; `Refusal` now says "or nil otherwise: sent, or turned down for a reason waiting won't fix (no guild, bad channel), which drops it like a sent one"

**What's wrong.**
1. `DropOldest`: "Saving adds one entry at a time, so one removal keeps it at
   `max`." `NoteQuestLoot` (`:1131-1145`) adds one entry per looted quest
   item, several per loot window, then calls `DropOldest(kept,
   QUEST_LOOT_MAX)` once. Releases with `keepAll` off also never trim what a
   dev build saved past the cap.
2. `Refusal`: "or nil when it was sent". It also returns nil for answers that
   weren't sent and won't be retried: `InvalidChannel` (7), `NotInGuild`
   (10), `GeneralError` (9), `NotInGroup` (5) and the rest of
   `Enum.SendAddonMessageResult`. `SendNext` then treats them as sent
   (`lastSentAt`, `heard[...] = true`). That is the old behaviour and should
   stay; the comment shouldn't claim otherwise.

**Why it matters.** The next reader trusts the comment: (1) suggests the
tables can never be over the cap; (2) suggests failed sends are retried.

**Evidence.** Lines read; `Enum.SendAddonMessageResult` in Ketho `forever`
`LuaEnum.lua:7231-7245`.

**Fix.** (1) "Removes the oldest entry (by `at`) when `entries` holds more
than `max`; callers save one entry, or one loot window, at a time." (2) "...
or nil otherwise: sent, or turned down for a reason waiting won't fix (no
guild, bad channel), which drops it like a sent one."

### R6 · Dead fallbacks for globals Forever doesn't have, and hand-numbered enums

- **Severity:** should fix
- **Area:** Redundant code / WoW API
- **Where:** `Drops.lua:68`, `:94`, `:464-470`, `:846-851`, `:881`, `:909`, `:1152-1157`, `:1248`
- **Status:** fixed in round 2 (uncommitted). Each guard that was removed was checked against Ketho's `forever` lists; all are present (table under WoW API notes). `NUM_CHAT_WINDOWS or 10` stays: the constant is in none of the lists, so the guard is reasonable. `Text(fn)` (`:1834`, dev-only) still writes `fn and`, which is harmless

**What's wrong.** The brief asks to cut "dead fallbacks (old globals Forever
doesn't have, per Ketho's lists)". These were moved or touched by the pass but
kept:

| Line | Code | Ketho `forever` |
| --- | --- | --- |
| 464-465 | `(ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter` / `if addFilter then` | `FrameXML.lua:493` has `ChatFrameUtil.AddMessageEventFilter`; no `ChatFrame_AddMessageEventFilter` |
| 1153, 1157 | `or (GetContainerItemID and GetContainerItemID(bag, slot))`, `if UseContainerItem then hooksecurefunc("UseContainerItem", NoteUse) end` | `GlobalAPI.lua` has only `C_Container.GetContainerItemID` (1221) and `C_Container.UseContainerItem` (1254) |
| 68 | `Enum.LootSlotType and Enum.LootSlotType.Item or 1` | `LuaEnum.lua:5548` `LootSlotType.Item = 1` |
| 94 | `issecretvalue and issecretvalue(value)` | `issecretvalue` is in `GlobalAPI.lua` |
| 909, 1248 | `C_Map and C_Map.GetBestMapForUnit and Plain(...)` (same expression twice) | `C_Map.GetBestMapForUnit` is in `GlobalAPI.lua` |
| 881 | `if class == nil and C_Item.GetItemInfoInstant then` | `C_Item.GetItemInfoInstant` is in `GlobalAPI.lua` |
| 846-851 | `EPIC = 4`, `UNCOMMON, QUEST_CLASS, RECIPE_CLASS = 2, 12, 9`, `MISC_CLASS = 15`, `BIND_ON_PICKUP = 1` | `Enum.ItemQuality.Epic/Uncommon` (`LuaEnum.lua:5093`), `Enum.ItemClass.Questitem/Recipe/Miscellaneous` (`:4642`), `Enum.ItemBind.OnAcquire` (`:4630`) |

**Why it matters.** Each guard tells the reader the call might be missing,
which is false on Forever, and each adds code to read. Hand numbers make the
reader trust a comment instead of a name Ketho's extension autocompletes
(READABLE-CODE.md rule 2), and R1 shows how a hand-made constant can go wrong.

**Evidence.** Greps of Ketho's `forever` `GlobalAPI.lua`, `FrameXML.lua`,
`LuaEnum.lua` (downloaded 2026-10-17). The smoke stand-in has every one of the
`Enum` tables used here (`tests/smoke/wow.lua:1081-1086`) except
`ItemMiscellaneousSubclass`, so keep `PET_SUBCLASS = 2` or add the enum in the
module test file.

**Fix.** Call `ChatFrameUtil.AddMessageEventFilter` straight in the loop;
keep only the `C_Container` lookup and hook; use the `Enum` names and delete
the constants; drop the `and` guards on calls Forever lists. If you want the
map lookup in one place, a `PlayerMapID()` helper serves `ScanWorld` and
`Where`. Note any guard kept on purpose for the smoke stand-in.

### R7 · Comments that restate the function name or the line below

- **Severity:** should fix
- **Area:** Readability (rule 5: "no restating the line below")
- **Where:** `Drops.lua:118`, `:209`, `:350`, `:396`, `:722`, `:774`, `:905`, `:1178`, `:1230`, `:1766`, `:1824`
- **Status:** fixed in round 2 (uncommitted): the listed comments are gone; the remaining ones explain a game fact or a format

**What's wrong.** These add a line and tell the reader nothing the name and
the one-line body don't:

- `:118` "The item ID in an item link, or nil." over `ItemIDOf(link)`
- `:350` "A D1 message's one drop, or nil when any part can't be read." over `Decode`
- `:396` "Whether a chat channel event is about the realm channel while sharing is on." over a one-line `IsOurChannelEvent`
- `:722` "Queues a kill's new items for the realm channel, then the guild." over `SendKill`, whose body is those two `Queue` lines
- `:774` "The NPC ID of the known boss with this name." over `BossNamed`
- `:905` "Saves and sends the open world Epics in the loot window." over `ScanWorld`
- `:1178` "The open quest window's ID, or nil." over `OpenQuestID`
- `:1230` "The quest log's entry for a quest the player has, or nil." over `QuestLogInfo`
- `:1766` "Who reported a kill, as the drop lists show it." over `ReporterName`
- `:1824` "A map's entries as { id, entry, name = nameOf(id, entry) }, by name." over `SortedByName`

**Why it matters.** Mike asked for fewer lines and no "Claude code"
comments; a header on every helper is that pattern.

**Evidence.** Lines read; list of all 126 added comment lines from
`git diff HEAD -U0`.

**Fix.** Delete them. Keep the comments that carry a fact the code can't show:
`SplitMessage`'s "Messages come from other players, so every reader checks
each field", `IsKillKey`'s key format, `IsOurChannel`'s numbered channel
name, `HideChannel`, the chat filter's argument order, the outbox's GROUP
history, `Refusal` (once fixed, R5), `SendAnswerText`'s 0/9 mapping.

### R8 · Rewritten paths have no test; two clean-up gaps

- **Severity:** should fix
- **Area:** Readability (tests; brief: "write the tests against the code BEFORE you change it")
- **Where:** `tests/smoke/modules/Core-Drops.lua`
- **Status:** fixed in round 2 (uncommitted), apart from item 4. Added: the guessed-drop scenario (item 1), the quest started from a looted item and from a bag item (item 2), and the quest log's `accept`/`turnin` with and without an NPC (item 3, `dev = true`). The big-kill test now restores `SendAddonMessage`, `dropCredit`, `dropSent` and `secretMode` through `pcall`. The probe test checks that a second probe within the gap adds nothing to the outbox. Item 4 (third throttle stops sending) is left as is. Implementer's reason: `stoppedThisSession` can't be undone in a run, so every later scenario would be blocked; scenarios.lua covers one throttle

**What's wrong.** The 13 scenarios assert real behaviour (saved counts, caps,
message sizes, the one-a-minute gap, Share drops off, probe gating) and pass in
all three runs. But several paths this change rewrote have no test in either
file, which is how R1 got through:

1. `Guess` without the roll's BoP flag: from `START_LOOT_ROLL` with
   `bop = false`, and from `Scan`'s area loot with an unreadable source
   (`unsure`, `:960`). Both fail today (R1).
2. `QuestGiver`'s item path (`giver.kind = "i"`, `id`, `dropper`), whose shape
   moved from an array to a keyed table: a quest started from a looted quest
   item (`LOOT_READY` with `isQuestItem`/`questID`, then `QUEST_DETAIL` with
   no `questnpc`) or from a bag item (`C_Container.UseContainerItem` within
   3 seconds). The stand-in's `GetLootSlotInfo` always returns
   `isQuestItem = false` (`wow.lua:1370`), so override it in the test and
   restore it.
3. `QUEST_COMPLETE`'s `turnin` (dev quest log), rewritten onto
   `QuestWindowSource`: assert `turnin.npc`, `npcID`, `npcName`, and `"-"`/`0`
   with no quest NPC.
4. `Refusal`: the third throttle stopping sending for the session
   (`THROTTLE_STOP`). `scenarios.lua:783` covers one throttle only.

Clean-up:
- "a big kill fits..." (`:194-241`) ends with `ns.db.dropSent = nil` instead
  of putting back the value it found, and if `W.Advance(900, 5)` raises, the
  `C_ChatInfo.SendAddonMessage` wrapper stays in place for every later test.
  Restore in one place with `pcall` around the body.
- "a listed character's probe is answered once" (`:295-307`) never checks
  that the second probe was ignored: both probes' answers would be deduped by
  `heard` and the `<= 25` bound would still pass. Hear a second probe after
  the first answers have drained and assert nothing more is queued or sent.

**Why it matters.** The brief makes these tests the proof that behaviour
stayed the same. A rewritten path with no test isn't proven.

**Evidence.** `grep` of `scenarios.lua` for `turnin`, `questLoot`,
`UseContainerItem`, `THROTTLE`; the R1 probe.

**Fix.** Add the four scenarios (the R1 probe is ready to copy, see R1) and
the two clean-ups.

### R9 · One-use constants in `RewardHash`, while `Hash` keeps the literal

- **Severity:** nit
- **Area:** Readability
- **Where:** `Drops.lua:1086-1095`, `:1350`
- **Status:** fixed in round 2 (uncommitted): literals are back, with the `mixed`/`salt` locals

**What's wrong.** `HASH_MULTIPLIER`, `TWO_TO_32`, `TWO_TO_20`, `TWO_TO_12`
are each used once, and the comment above (`:1082-1084`) already spells the
formula with the numbers ("top 12 bits of (item * 2654435761 + salt) mod
2^32"). Thirty lines later, `Hash` still writes `% 4294967296`.

**Why it matters.** The brief: "don't add a constant for a number used once
whose meaning is plain from its line." The reader now has to map names back
to the numbers in the comment, and the two hashes read differently.

**Fix.** Keep the literals (with the `mixed`/`salt` locals, which help), or
use the constant in both functions. The first is shorter.

### R10 · Two item-link parses don't use the new `ItemIDOf`

- **Severity:** nit
- **Area:** Redundant code (rule 6, one way of doing each thing)
- **Where:** `Drops.lua:1165-1166` (`RewardIDs`), `:1911-1912` (`RewardItems`, dev)
- **Status:** fixed in round 2 (uncommitted): both use `ItemIDOf(Plain(GetQuestItemLink(kind, i)))`; `table.concat` writes the numeric IDs the same as the old strings

**What's wrong.** `local id = link and link:match("item:(%d+)")` and
`link and tonumber(link:match("item:(%d+)"))` remain next to the new
`ItemIDOf`. `RewardIDs` keeps the ID as a string; `table.concat` writes a
number the same way, so switching doesn't change the Q1 `rewards` text.

**Fix.** `local itemID = ItemIDOf(Plain(GetQuestItemLink(kind, i)))` in both.

### R11 · `AddToCorpse` parses a GUID its callers just parsed

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `Drops.lua:896-903`, `:919`, `:946-949`
- **Status:** fixed in round 2 (uncommitted): `AddToCorpse(found, guid, npcID, kill, itemID, count, encounterID)`; both callers pass what they parsed

**What's wrong.** `ScanWorld` calls `if ParseGUID(guid) then AddToCorpse(...)`,
`Scan` calls `local npcID = ParseGUID(guid)`, and `AddToCorpse` parses the
same GUID again to get `npcID, kill`. That is a second string match per loot
source per slot.

**Fix.** Pass `npcID, kill` in: `AddToCorpse(found, guid, npcID, kill,
itemID, count, encounterID)`, or let `AddToCorpse` parse it and return early
when it isn't a creature, so `ScanWorld` doesn't need its own `if`.

### R12 · The guessed-drop test's clean-up can raise its own error and hide why the test failed

- **Severity:** nit
- **Area:** Readability (tests)
- **Where:** `tests/smoke/modules/Core-Drops.lua:385`
- **Status:** fixed after round 2: the clean-up checks for nil before restoring

**What's wrong.**

```lua
if ns.db.drops[33] then ns.db.drops[33].bosses[npcID].kills["5678-0000ABCE31"] = nil end
```

This runs after the `pcall`, before `assert(ok, err)`. Instance 33 can already
hold other bosses from earlier scenarios. If this test fails before the boss
was saved (the R1 regression would do that), `bosses[npcID]` is nil, and
indexing it raises "attempt to index a nil value". The report then shows that
error instead of the assertion message saying what went wrong.

**Why it matters.** Test output only: the scenario still fails, but the
message points at the clean-up instead of the bug.

**Evidence.** Line read. `Guessed()` in the same test (`:351-355`) already
guards each step.

**Fix.**

```lua
local boss = ns.db.drops[33] and ns.db.drops[33].bosses[npcID]
if boss then boss.kills["5678-0000ABCE31"] = nil end
```

## Area notes

### Readability

Checked every renamed local against READABLE-CODE.md. The new names read in
the game's terms and are sound: `fields`/`report`/`savedCount`/`itemsKey`/
`waitingKills`/`currentEncounter`/`lockedDownSince`/`lastSentAt`/
`stoppedThisSession`, and `HEARD_LIST` for the old `CLASS`. Guard clauses
replace nesting in `KnownBosses`, `QuestWindowSource`, `QuestGiver`,
`Destination`. `Answer` was 60 lines at seven levels of nesting; the split
into `KillMessages`/`AddKillAnswers`/`AddQuestAnswers` earns its names.
Format comment lines over 120 characters were wrapped; no line is over 120
now (`awk 'length > 120'`). 4-space indents, LF, no tabs. `local _, ns = ...`
unchanged. No `cond and nil or x`; the `and`/`or` returns checked
(`Destination`'s `return channelID and "CHANNEL", channelID`,
`NoteQuestLoot`'s `false` item ID) behave as before. Round 2: no line over
120, no tabs, LF. Comments read as plain explanations; the example names are
now made up. Findings: R1, R5, R7, R8, R9 (all fixed), R12.

### WoW API

Round 2 removed many existence guards. In game, a removed guard on a call
Forever lacks would be a load or runtime error that the stand-in might not
show. So every game global, `C_` function, FrameXML name and `Enum` member the
round 2 file reads was checked by name against Ketho's `forever` lists
(downloaded 2026-10-17): `GlobalAPI.lua` for functions (exact `"Name",` or
`"C_X.Name"` entries), `FrameXML.lua`, `LuaEnum.lua` for `Enum` members and
values. The global list came from `luacheck --std lua51` (W113), and the
`C_`/`Enum` members from a grep of the file.

| Name (where the guard was removed or the call changed) | Kind | In `forever` | Where looked / note |
| --- | --- | --- | --- |
| `ChatFrameUtil.AddMessageEventFilter` (`:446`, file load, unguarded) | FrameXML | yes | `FrameXML.lua:493`. `ChatFrame_AddMessageEventFilter` is not listed, so dropping it is right. FrameXML loads before addons |
| `JoinTemporaryChannel` (`:403`) | function | yes | `GlobalAPI.lua`. Called through `pcall`. The removed `JoinPermanentChannel` fallback is also listed but was never needed |
| `LeaveChannelByName` (`:400`, `:434`), `RemoveChatWindowChannel` (`:392`) | function | yes | `GlobalAPI.lua`; both through `pcall` |
| `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted`, `C_ChatInfo.InChatMessagingLockdown` (`IsLockedDown`, `OutboxStatus`) | function | yes | `GlobalAPI.lua:786`, `:808`; `pcall(C_ChatInfo[name])`, so even a missing one would only read as "not locked" |
| `C_Map.GetBestMapForUnit` (`ScanWorld`, `Where`), `C_Map.GetPlayerMapPosition` | function | yes | `GlobalAPI.lua`; the position call stays inside `pcall` |
| `GetQuestID`, `GetNumQuestRewards`, `GetNumQuestChoices`, `GetRewardMoney`, `GetRewardXP` | function | yes | `GlobalAPI.lua` (`GetQuestID` at 5754) |
| `C_QuestLog.GetLogIndexForQuestID`, `GetInfo`, `GetTitleForQuestID`, `GetQuestTagInfo`, `GetQuestObjectives` | function | yes | `GlobalAPI.lua` (`GetInfo` at 3546). `GetQuestTagInfo` stays in `pcall` |
| `C_Item.GetItemSpell`, `C_Item.GetItemInfoInstant`, `C_Item.GetItemNameByID` | function | yes | `GlobalAPI.lua` |
| `C_Container.GetContainerItemID`, `hooksecurefunc(C_Container, "UseContainerItem", ...)` (`:1099`, file load) | function | yes | `GlobalAPI.lua:1221`, `:1254`. The global `GetContainerItemID`/`UseContainerItem` aren't listed |
| `GetNormalizedRealmName`, `issecretvalue` | function | yes | `GlobalAPI.lua` |
| `LE_PARTY_CATEGORY_INSTANCE` | constant | yes | `LuaEnum.lua:10188` |
| `NUM_CHAT_WINDOWS` | constant | not in the lists (inferred FrameXML constant) | still guarded `or 10` |
| `Enum.SendAddonMessageResult` (`or {}` removed) | enum | yes | `LuaEnum.lua:7231`. `AddonMessageThrottle`/`ChannelThrottle`/`AddOnMessageLockdown` still match `find` |
| `Enum.LootSlotType.Item` | enum | yes, 1 | `LuaEnum.lua:5548` |
| `Enum.ItemBind.OnAcquire` | enum | yes, 1 | `LuaEnum.lua:4630` |
| `Enum.ItemQuality.Uncommon`, `.Epic` | enum | yes, 2 and 4 | `LuaEnum.lua:5093` |
| `Enum.ItemClass.Questitem`, `.Recipe`, `.Miscellaneous` | enum | yes, 12, 9, 15 | `LuaEnum.lua:4642` |
| `Enum.ItemMiscellaneousSubclass.CompanionPet` | enum | yes, 2 | `LuaEnum.lua:5001`. The stand-in lacks this table, so the module test file defines it at load (`Core-Drops.lua:11`). Allowed by the brief; listed under Cross-module for `wow.lua` |

Every value matches the number it replaced, so behaviour is the same. All the
other global reads luacheck reports (`GetLoot*`, `GetInstanceInfo`,
`Unit*`, `IsIn*`, `GetChannelName`, `Ambiguate`, `GetServerTime`,
`GetBuildInfo`, `C_Timer.*`, `C_ChatInfo.SendAddonMessage`,
`C_ChatInfo.RegisterAddonMessagePrefix`, `wipe`, `date`, `time`) are in
`GlobalAPI.lua` and weren't guarded before either. Calls run at file load
(`ChatFrameUtil.AddMessageEventFilter`, `hooksecurefunc` on `C_Container`,
`GetBuildInfo`) are all listed. Nothing removed was a call Forever lacks.

Events registered are unchanged (`ENCOUNTER_START/END`,
`INSTANCE_ENCOUNTER_ENGAGE_UNIT`, `START_LOOT_ROLL`, `LOOT_OPENED`,
`LOOT_READY`, `QUEST_DETAIL`, `QUEST_ACCEPTED`, `QUEST_COMPLETE`,
`CHAT_MSG_ADDON`, `CHAT_MSG_CHANNEL_NOTICE`, `PLAYER_ENTERING_WORLD`,
`PLAYER_LOGIN`). Secret values: every helper passes game values through
`Plain` before comparing, indexing or concatenating; the secret-values smoke
run passes. Async item data is unchanged (`ns.Items:Load` in `Guess` and
`SaveWhenLoaded`). No new globals: `Drops.probers` is a field on the module
table. Upvalues: `luac5.1 -p` passes. No secure frames touched; the
`hooksecurefunc` on `C_Container.UseContainerItem` is taint-safe. The one
behaviour difference: if a lockdown check were missing, the dev-only
`/nr droptalk outbox` line would print a `pcall` error instead of "not in
this client". Both checks are listed, so it can't happen on Forever. No `L[...]`
change (locales check passes). No UI change, so `docs/STYLE-GUIDE.md` isn't
affected. No new game call, so nothing to mirror in `tests/smoke/wow.lua`.

### Redundant code

Compared against: `ns.Items:Load`, `ns.Items:Quality` (used, not
duplicated); `ns.Data:KnownDrop`/`KnownQuest`/`QuestPrint` (used); the
existing caches `knownBosses`, `bossByName`, `versionTag`. `BossNamed` no
longer reaches into `knownBosses` through the `KnownBoss(0)` trick, which is
better. Helpers that fold real duplicates: `SplitMessage` (3), `DropOldest`
(3: `Prune`, `PruneQuests`, the inline loop in `NoteQuestLoot`),
`SendResultName` (the `TryLater`/`Throttled`/`ResultName` loops),
`TallyBossItems` + `ReporterName` (`SavedRows` and `Print`),
`QuestWindowSource`, `OpenQuestID`, `AcceptedQuestID`, `QuestLogInfo`,
`SaveWhenLoaded`, `SendAnswerText`, `SlotItemID`, `AddToCorpse`. `Drops:Decode`
removed: verified unused. `grep` over `NeedRoll/`, `tests/` and `docs/` finds
no `Drops:Decode(`/`Drops.Decode` (only `DecodeDrops`/`DecodeQuest`, kept),
and every `ns.Drops` member used anywhere still exists (re-checked in round 2).
The `SavedBoss` split was folded back into `Save`, and the `Take`
dispatcher became the `TAKE` table. Findings: R2 (partly fixed), R6, R10, R11
(fixed).

Cross-module (not this group's to fix): `Plain` is defined three times with
the same body or near it, at `Core/Drops.lua:93`, `Core/LootLog.lua:51` and
`UI/MainFrame.lua:276` (the last returns a boolean), plus the same guard at
`Core/Names.lua:245`. The item-link parse `tonumber(link:match("item:(%d+)"))`
is repeated at `Core/LootLog.lua:105`, `:203` and `API.lua:213`. A shared
`ns.Plain`/`ns.ItemIDOf` would serve all of them. Stand-in:
`Enum.ItemMiscellaneousSubclass` belongs in `tests/smoke/wow.lua` (now
defined in `tests/smoke/modules/Core-Drops.lua:11`). Names:
`tests/smoke/scenarios.lua:1078` still runs `droptalk key Flow Burn` (R4).

### Security

Untrusted inputs touched: `CHAT_MSG_ADDON` text and sender (guild, party/raid,
`NeedRollDropSharing` channel), through `SplitMessage`, `DecodeKill`, `Decode`,
`DecodeQuest`, `TakeKill`/`TakeOldDrop`/`TakeQuestReport`, `Answer`. Compared
old and new decoders line by line: the same anchored item and kill-key
patterns, the same field counts (`#fields < 9`, `< 10`, `< 12`), the same
range checks (`instance > 1`, `count > 0`, `quest > 0`, side and giver sets),
the same `rewards` whitelist `^[%d,/]+$`. Nothing is looser; nothing is
stricter. The pre-existing gap is R3. Outputs: byte-for-byte message formats
unchanged (`EncodeKill` untouched, `EncodeQuest` only renamed; the big-kill
and quest-name scenarios assert sizes ≤ 250 and the field layout).
SavedVariables keys unchanged (`drops`, `newQuests`, `questLoot`,
`dropOutbox`, `dropSent`, `dropNewer`, `questLog`, and per-entry `at`, `by`,
`items`, `guessed`, `partial`, `rewards`, `sides`, `classes`, `accept`,
`turnin`). The keyed `giver` table lives only in the session tables `givers`
and `details`, never saved. Pacing unchanged: `SEND_GAP` 60 s, `Queue`'s
`math.max(wait, 1.5)` start, `DAILY_MAX` 100 a day, `THROTTLE_PAUSE`/
`THROTTLE_STOP`, `LOCKDOWN_MAX`/`RETRY`, outbox cap 300. The "Share drops"
Off switch: `Queue` still returns when off, `SendNext` still wipes the
outbox when off, and the two removed `Drops:ChannelOn()` re-checks in
`SendNext` were after that early return, so they could never be false there.
The test "Share drops off..." asserts it. Probes are answered only for
`PROBERS` keys, at most 25, once per 15 minutes, on the channel only
(unchanged). No `loadstring`/`RunScript`/`setfenv`. Heard names
(`npcName`, `instanceName`) are shown unescaped only in the dev-only
`/nr droptalk` window and list (`UI/DropTalk.lua:150`, `Drops:Print`),
which `.pkgmeta` keeps out of releases; pre-existing, not changed here.
Names: R4, fixed. Round 2 adds `Drops.probers = PROBERS` (`Drops.lua:1481`),
a writable reference to the probe allow-list. It sits inside `--@debug@`
(`:1471` to `:1942`), so the release packager comments it out and released
copies have no way to add probers. Only local checkouts, which Mike controls,
have it. Round 2 re-check of the decoders: unchanged from round 1 and `HEAD`.
The `TAKE` table only dispatches on the three kinds that were accepted
before; anything else is still ignored, same as the old `kind ~= ...` test.
`AddQuestAnswers` now sets defaults first and copies only the saved fields
that aren't nil, which gives the same report as the old copy-then-`or`.
No change to `Credits.txt` or `.pkgmeta`.

## Round history

- 2026-10-17, `c0e5c79` + uncommitted, round 1: **Changes needed**. Opened
  R1 to R11 (1 blocking, 7 should fix, 3 nits). None closed.
- 2026-10-17, `c0e5c79` + uncommitted (round 2 working tree), round 2:
  **Ready**. Closed R1, R4, R5, R6, R7, R9, R10, R11, and R8 apart from the
  third-throttle test (left as is with the implementer's reason). R2 partly
  fixed (1942 lines, code -4) and left for Mike. R3 moved to a follow-up PR.
  Opened R12 (nit).
- 2026-10-17, after round 2: R12 (nit) fixed with a nil check in the clean-up; R2 goes to Mike in the PR description; R3 becomes its own PR.
