# Review: Read heard drop and quest numbers strictly, show heard text as typed

| | |
| --- | --- |
| Branch | `drops-validate` into `origin/dev` (PR # once it exists) |
| Commit reviewed | `54ec34c` (round 3, final; earlier rounds `6c3fb55`, `48e123f`; no uncommitted code changes) |
| Date | 2026-10-18 |
| Round | 3 (final) |
| Verdict | **Ready** (0 blocking, 0 should fix; R11 fixed by the integrator after round 3; R13 open for Mike, R7 and R12 not worth it) |
| Needs | `/reload`: only existing Lua files change (no TOC, XML or new files), so a reload picks them up |

## What the change does

Other players' copies of NeedRoll send D1/D2 (boss kill), Q1 (new quest) and
R1 (catch-up probe) addon messages. Before this change every number field was
read with bare `tonumber`, which in Lua 5.1 also accepts `"nan"`, `"inf"`,
`"0x1f"`, `"-5"`, `"1.5"` and `"1e3"` (checked here: `lua5.1 -e
'print(tonumber("nan"), tonumber("inf"), tonumber("0x1f"))'` prints `nan inf
31`). A made-up message could therefore save an instance keyed `inf`, a count
of `inf` or a negative NPC ID into `NeedRollDB`, values that SavedVariables
can't write back as plain numbers (inferred: a non-finite number written into
the saved file can stop the whole `NeedRollDB` from loading). Now every heard
number goes through a new `HeardNumber` (`NeedRoll/Core/Drops.lua:299`): digits
only, at most 2^31-1, else nil, which the decoders already treat as "missing"
(the message is dropped, or the optional quest field takes its default). Quest
reward lists go through `HeardRewards`, and the probe time through
`Drops.ProbeSince`, which `UI/DropTalk.lua` also uses.

Free text from other players (boss, instance, quest, giver and zone names,
and the raw message) is now shown through a new `ns.Literal`
(`NeedRoll/Core/Init.lua:242`), which doubles every `|` so it can't start a
color, texture, line break or hyperlink. It is applied where the dev-only
drop talk window (`/nr droptalk`) hands row text to a FontString or the
tooltip, and in `/nr droptalk list`'s chat print. The wishlist import's own
`gsub("|", "||")` now calls `ns.Literal`. Players see no difference; the
heard-text surfaces are all in dev-only code (`UI/DropTalk.lua` is in
`.pkgmeta`'s ignore list; `Drops:Print` is inside `--@debug@`).

## Scope

- `NeedRoll/Core/Drops.lua`: `HEARD_NUMBER_MAX`, `HeardNumber`, `HeardRewards`, `Drops.ProbeSince`; `DecodeKill`, `Decode`, `DecodeQuest` and `Answer` read numbers through them; `PrintBoss` and `Drops:Print` escape boss and place names.
- `NeedRoll/Core/Init.lua`: new `ns.Literal`.
- `NeedRoll/Core/Wishlist.lua`: `ParseExport` uses `ns.Literal` for the pasted character name and class.
- `NeedRoll/UI/DropTalk.lua`: `MessageRows` reads the probe time through `ns.Drops.ProbeSince`; `RowEnter` and `FillRow` escape title, sub, tooltip lines and raw text.
- `tests/smoke/modules/Core-Drops.lua`: two scenarios (bad number fields rejected or defaulted; well-formed D1, D2 and Q1 decode as before).
- `tests/smoke/modules/UI-DropTalk.lua`: one scenario (heard names with `|` show as typed in rows and tooltip).
- No generated files under `NeedRoll/Data/` changed.

Read in full, beyond the hunks: the whole of `Core/Drops.lua` (decode, save,
answer, debug block), `UI/DropTalk.lua`, `ParseExport` and `WL:CleanName` in
`Core/Wishlist.lua`, the helpers at the top of `Core-Drops.lua`, and
`scraper/needroll_scraper/observed.py`'s `merge_drops` (where saved heard names
go next).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the six changed Lua files | passed |
| `luacheck --no-global -q`, changed vs `origin/dev` | same warnings: Drops.lua 20/20, Init.lua 9/9, Wishlist.lua 12/12, DropTalk.lua and both test modules 0/0; warning texts identical once line numbers are stripped (`diff` of the sorted lists shows only the file path line) |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | exit 0; prints 50 "not used by NeedRoll any more" lines for `zhTW.lua` etc. The change adds or removes no `L["..."]`, so these predate it (inferred from the diff) |
| `tests/smoke/check.sh` | passed: dev, packaged and secret runs all print "all passed"; the three new scenarios pass in dev and secret, the non-dev one in packaged too |
| `git diff --check`, line length, CRLF | clean; no added line over 120 characters |
| Scraper unit tests | not run: the change touches no scraper code |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Security | `Core/Drops.lua:1024-1028`, `:194-208`, `:983-985` | Heard IDs are well formed but not range-checked, so one sender can grow saved tables without bound | fixed in round 2 (`48e123f`); local checkouts uncapped: accepted |
| R2 | should fix | WoW API (tests) | `tests/smoke/modules/Core-Drops.lua:110-139` | The 2^31-1 cap and the chat print escaping are never exercised by a scenario | fixed in round 2 (`48e123f`) |
| R3 | nit | Redundant code | `Core/Drops.lua:300` | `#field > 10` is an unnamed number that duplicates the cap | fixed in round 2 (`48e123f`) |
| R4 | nit | Readability | `Core/Drops.lua:292-293` | The constant's comment says coordinates are 0 to 1000; nothing enforces it | fixed in round 2 (`48e123f`) |
| R5 | nit | Readability | `Core/Drops.lua:1368-1371` | `Drops.ProbeSince` is a release-build public dot function; the file's pattern is a local plus a `Drops:` wrapper in the debug block | fixed in round 2 (`48e123f`) |
| R6 | nit | Readability | `Core/Drops.lua:1011` | `HeardRewards`' comment is a double negative | fixed in round 2 (`48e123f`) |
| R7 | nit | Security | `UI/DropTalk.lua:99-103` | Quests saved before the fix may hold an oversized reward ID (implementer's question) | not worth it (left as is: dev-only, worst case a nameless reward line) |
| R8 | should fix | Security | `Core/Drops.lua:207-222`, `:247` | The boss cap evicts the player's own finds first, so a flood of made-up bosses wipes them | fixed in round 3 (`54ec34c`) |
| R9 | nit | Security | `Core/Drops.lua:209-222` | Saved data already over 1000 bosses is never trimmed back to the cap | fixed in round 3 (`54ec34c`) |
| R10 | nit | WoW API (tests) | `tests/smoke/modules/Core-Drops.lua:152-169` | The boss-cap scenario doesn't reach Save's re-read of an instance that lost its last boss | fixed in round 3 (`54ec34c`) |
| R11 | nit | Redundant code | `Core/Drops.lua:222-243` | The full heard-boss scan runs on every new-boss save, even far below the cap | fixed after round 3: the bosses are counted first and the list is built only at the cap |
| R12 | nit | Readability | `Core/Drops.lua:249`, `:1472-1479` | A heard drop the cap turns away is logged as "already saved" | not worth it |
| R13 | nit | Security | `Core/Drops.lua:270` | `KILLS_MAX` still lets heard kills push the player's own kills out of one boss | open for Mike (pre-existing, follow-up) |

### R1 · Heard IDs are well formed but not range-checked, so one sender can grow saved tables without bound

- **Severity:** should fix (pre-existing; fine as a follow-up PR if Mike prefers)
- **Area:** Security
- **Where:** `NeedRoll/Core/Drops.lua:1025` (class), `:1026` (x, y), `:983-985` (`saved.classes`), `:194-208` (`Save` making instance and boss entries), `:320-321` and `:343-344` (instance, npc)
- **Status:** fixed in round 2 (`48e123f`): `HeardNumber(field, max)` with `COORDINATE_MAX`, class 0 above `GetNumClasses()`, `BOSSES_MAX` = 1000 via `MakeRoomForBoss`. Local checkouts (`Drops.keepAll`) skip the caps, as `KILLS_MAX` and `QUESTS_MAX` do: accepted (coordinator, round 2). The eviction choice is R8

**What's wrong.** `HeardNumber` makes every field a plain integer from 0 to
2147483647, but the decoders then use those integers as table keys with no
range of their own:

```lua
class = HeardNumber(fields[5]) or 0, ...
...
if report.class > 0 and not saved.classes[report.class] then
    saved.classes[report.class] = true
    isNew = true
```

and in `Save`:

```lua
local instance = ns.db.drops[drop.instance]
if not instance then
    instance = { bosses = {} }
    ns.db.drops[drop.instance] = instance
...
local boss = instance.bosses[drop.npc]
if not boss then
    boss = { kills = {} }
```

`KILLS_MAX` (50) caps kills per boss and `QUESTS_MAX` (500) caps quests, but
nothing caps how many instances or bosses `ns.db.drops` holds, or how many
class keys one saved quest holds. x and y are documented as tenths of a
percent (0 to 1000, `Where` at `:1192-1205`) but accepted up to 2^31-1.

**Why it matters.** One player on the realm channel (which every copy joins)
can send `Q1:<quest>:1:a:<n>:n:...` for n = 1, 2, 3, ... and every copy saves
a new `classes[n]` for that quest, or send D2 kills of a real Uncommon item
(so `Wanted` passes) under instance IDs 2, 3, 4, ... and NPC IDs of their
choice, each a new instance and boss entry. The server's addon message
throttle slows this but doesn't stop it; over a session the SavedVariables
file grows by megabytes, which lengthens every `/reload` and logout save for
everyone listening, and on local checkouts (`Drops.keepAll`) not even the
kill and quest caps apply. The bad entries are then ingested by the scraper
(`observed.py` `merge_drops` takes any digit NPC key). A coordinate of
2147483647 shows as "(214748364.7, ...)" in the drop talk window.

**Evidence.** Lines quoted above; no other cap on `ns.db.drops` or
`saved.classes` (grep for `DropOldest`: only `boss.kills`, `newQuests`,
`questLoot`). `GetNumClasses` is in Ketho's `forever` `GlobalAPI.lua` (line
5637 of the downloaded list) and `UI/IconDebug.lua:192` already uses it. The
growth rate under the server throttle is inferred, not measured.

**Fix.** Give each heard ID a sane range at decode time, and bound the
heard-only tables:

```lua
-- In DecodeQuest, after building report:
if report.class > GetNumClasses() then report.class = 0 end
if report.x > COORDINATE_MAX or report.y > COORDINATE_MAX then report.x, report.y = 0, 0 end
```

with `local COORDINATE_MAX = 1000 -- tenths of a percent, see Where`. For
`ns.db.drops`, cap the number of bosses heard from others (for example a
`HEARD_BOSSES_MAX` across all instances, dropping the boss whose newest kill
is oldest, like `DropOldest`), or keep heard kills for unknown instances only
when the instance ID is one the game could name. Add a scenario that hears
many classes for one quest and many instances, and checks the counts stay
bounded.

### R2 · The 2^31-1 cap and the chat print escaping are never exercised by a scenario

- **Severity:** should fix
- **Area:** WoW API (smoke scenarios for a bug fix)
- **Where:** `tests/smoke/modules/Core-Drops.lua:110-139`; no scenario for `Drops:Print` (`Core/Drops.lua:1771-1790`)
- **Status:** fixed in round 2 (`48e123f`)

**What's wrong.** Every over-the-cap value in the new scenario is
`"99999999999"`, 11 digits, which `HeardNumber`'s `#field > 10` rejects before
the cap is looked at, so this line never runs in any test:

```lua
if number > HEARD_NUMBER_MAX then return nil end
```

Nor does any scenario accept the boundary value 2147483647. And
`PrintBoss`/`Drops:Print`, two of the four places the change escapes, have no
scenario: if a later edit drops the `ns.Literal` there, nothing fails.

**Why it matters.** The cap is the part of the fix that keeps a 10-digit ID
such as `4294967296` out; if R3's redundant length check is removed (or the
cap typed wrong), the tests stay green. The print escaping protects the
`/nr droptalk list` chat output from a heard boss name like
`Boss|Hitem:19019|h[Thunderfury]|h`, which would otherwise print as a
clickable fake link.

**Evidence.** Scenario source read; `lua5.1` run of the function without the
length check: `HeardNumber("2147483648")` gives nil, `"2147483647"` gives
2147483647, so only a 10-digit value reaches the cap.

**Fix.** Add `"2147483648"` to `notWhole`, assert a kill with instance
`2147483647` is saved, and add a dev scenario that saves a kill named
`"Boss|cffff0000Red|r"`, runs `ns.Drops:Print()` and checks the printed lines
(the smoke stand-in keeps them in `W.printed`; `W.Printed(text)` at
`tests/smoke/wow.lua:162` finds one) carry `"Boss||cffff0000Red||r"`.

### R3 · `#field > 10` is an unnamed number that duplicates the cap

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/Core/Drops.lua:300`
- **Status:** fixed in round 2 (`48e123f`)

**What's wrong.**

```lua
if type(field) ~= "string" or #field > 10 or not field:match("^%d+$") then return nil end
```

`10` is the digit count of `HEARD_NUMBER_MAX`, written as a bare number
(`docs/READABLE-CODE.md` 1 and 7). It adds nothing: a longer digit string
gives a number above the cap (400 nines give `inf`, which the cap rejects),
and a message is at most 255 bytes, so there is no long-string cost to save.

**Why it matters.** A reader has to work out where 10 comes from, and the
two limits can drift apart if one is edited.

**Evidence.** `lua5.1` run of the function without the length check (see R2):
same answers for every value in the scenario.

**Fix.** Drop `#field > 10 or`. (Leading zeros such as `"000000000005"` are
then read as 5; no copy sends them, and 5 is the right reading.)

### R4 · The constant's comment says coordinates are 0 to 1000; nothing enforces it

- **Severity:** nit
- **Area:** Readability (disinformation)
- **Where:** `NeedRoll/Core/Drops.lua:292-293`
- **Status:** fixed in round 2 (`48e123f`)

**What's wrong.**

```lua
-- The game's IDs, counts and builds fit a 32-bit signed integer. Map
-- coordinates travel as whole tenths of a percent (0 to 1000, see Where).
local HEARD_NUMBER_MAX = 2147483647
```

Next to the cap, the second sentence reads as if heard coordinates are held to
0 to 1000. They are held to 2147483647 like everything else
(`x = HeardNumber(fields[9]) or 0`).

**Why it matters.** `docs/READABLE-CODE.md` 9: a reader trusting the comment
won't add the range check R1 asks for.

**Fix.** Either add the `COORDINATE_MAX` check from R1 and point the comment
at it, or reword: "Map coordinates (tenths of a percent, see Where) are whole
numbers too, so they go through HeardNumber."

### R5 · `Drops.ProbeSince` is a release-build public dot function

- **Severity:** nit
- **Area:** Readability (consistency)
- **Where:** `NeedRoll/Core/Drops.lua:1368-1371`, callers `:1375` and `UI/DropTalk.lua:165`
- **Status:** fixed in round 2 (`48e123f`)

**What's wrong.** The other decoders that `UI/DropTalk.lua` reads are local
functions with a `Drops:` method wrapper inside the `--@debug@` block:

```lua
function Drops:DecodeQuest(text)
    return DecodeQuest(text)
end
```

`ProbeSince` is instead a public `Drops.ProbeSince` (dot, not colon) defined in
shipped code, so release builds expose it and the call style differs
(`ns.Drops.ProbeSince(msg.text)` next to `ns.Drops:DecodeQuest(msg.text)` in
the same function, `MessageRows`).

**Why it matters.** `docs/READABLE-CODE.md` 6: one way of doing each thing. A
reader of `MessageRows` sees two call styles for the same kind of helper.

**Fix.** `local function ProbeSince(text)` beside `Answer`, used by `Answer`,
and in the debug block `function Drops:ProbeSince(text) return
ProbeSince(text) end`; `DropTalk` then calls `ns.Drops:ProbeSince(msg.text)`
and the scenario `ns.Drops:ProbeSince(...)` (mark it `dev = true`, or keep the
probe assertion in a dev scenario).

### R6 · `HeardRewards`' comment is a double negative

- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/Core/Drops.lua:1011`
- **Status:** fixed in round 2 (`48e123f`)

**What's wrong.**

```lua
-- A heard quest's rewards ("1,2/3,4"), or "-" (none seen) unless every item ID is a HeardNumber.
```

"Rewards, or '-' unless every ID is good" makes the reader untangle which
case gives which.

**Fix.** "A heard quest's rewards ("1,2/3,4"), or "-" (none seen) when the
field is missing or any item ID isn't a HeardNumber."

### R7 · Quests saved before the fix may hold an oversized reward ID

- **Severity:** nit
- **Area:** Security
- **Where:** `NeedRoll/UI/DropTalk.lua:99-103` (`QuestLines`), also `Core/Drops.lua:1050` (`RewardHash`)
- **Status:** left as is: the implementer's reason is that this is dev-only and the old digits-only check bounds the damage to a nameless reward line (round 2)

**What's wrong.** The implementer asked about this. `QuestLines` reads reward
IDs from saved quests with `tonumber`, and a quest heard before this fix could
have saved a rewards string like `"99999999999999999999"`: the old check was
only `^[%d,/]+$`, so digits but any length.

**Why it matters.** Very little. The old pattern already kept everything but
long digit runs out, so the worst a saved value can be is a huge number
handed to `C_Item.GetItemInfo` and `C_Item.RequestLoadItemDataByID`, which
(inferred; not testable outside the game) returns no item, so the line reads
"item 1e+20". `RewardHash` only does math on it. Both are in dev-only paths
(`QuestLines` is in `UI/DropTalk.lua`, which releases leave out; `Listed`
only compares hashes). `/nr droptalk clear` empties `newQuests`.

**Evidence.** `Core/Drops.lua` history in the diff (old line `rewards and
rewards:match("^[%d,/]+$") and rewards or "-"`); `.pkgmeta` ignores
`NeedRoll/UI/DropTalk.lua`.

**Fix.** None needed. If wanted, skip IDs above 2147483647 in `QuestLines`'
loop (`if itemID <= 2147483647 then ... end`), or clean `saved.rewards`
through `HeardRewards` once in `Drops:QuestRows`.

### R8 · The boss cap evicts the player's own finds first, so a flood of made-up bosses wipes them

- **Severity:** should fix
- **Area:** Security
- **Where:** `NeedRoll/Core/Drops.lua:207-222` (`MakeRoomForBoss`), `:247` (`at = time()`)
- **Status:** fixed in round 3 (`54ec34c`): `HeardOnly(boss)`; only heard-only bosses are evicted; `Save` turns a heard boss away when every saved boss is the player's own

**What's wrong.** `MakeRoomForBoss` evicts the boss whose newest kill is
oldest, judged by `kill.at`. But `at` is the time *this* copy saved the kill,
not anything the sender says:

```lua
kill = { at = time(), difficulty = drop.difficulty, build = drop.build, by = drop.by, items = {},
```

so every boss a flooder sends is, by construction, the newest one saved, and
the bosses that go first are the ones the player has had longest: their own
finds (`kill.by == nil`) and real heard drops from earlier sessions.

**Why it matters.** In a released build, one player sends about 1000 D2
messages on the realm channel, each a real Uncommon item under a new made-up
instance or NPC ID (the server throttle slows this to minutes, not a stop).
Every copy listening then evicts every boss it held before, one per message,
own finds included. Those own finds are what the copy answers Mike's
catch-up probes with (`AddKillAnswers` sends only kills with no `by`,
`:1377-1389`), so the realm's real data stops reaching the scraper, and the
cap the fix added is what does the wiping. Before the cap, a flooder could do
this only per boss (`KILLS_MAX`, 50 kills), and had to know which bosses to
target.

**Evidence.** Read `Save` (`:226-270`) and `MakeRoomForBoss`; the scenario
"heard kills keep at most 1000 bosses" shows the same thing on a small scale:
the boss heard first is the one dropped, whatever it holds. That a released
copy's own finds matter only through probe answers is from reading every
reader of `ns.db.drops` (`AddKillAnswers`, `SavedKill`, `KillCount`,
`SavedRows`, `Print`); `KillCount` and the rest are dev-only.

**Fix.** Never evict a boss that holds a kill the player looted; choose only
among bosses whose kills are all heard (every kill has `by`). Sketch:

```lua
-- Whether every saved kill of the boss was heard from another player.
local function HeardOnly(boss)
    for _, kill in pairs(boss.kills) do
        if not kill.by then return false end
    end
    return true
end
```

and in `MakeRoomForBoss` count every boss but pick the stalest only among
`HeardOnly` ones (if there are none, the player's own bosses alone are over
1000, which a flood can't cause: save anyway). Add a scenario: an own kill
first, then 1000 heard bosses; the own boss is still there.

### R9 · Saved data already over 1000 bosses is never trimmed back to the cap

- **Severity:** nit
- **Area:** Security
- **Where:** `NeedRoll/Core/Drops.lua:209-222`
- **Status:** fixed in round 3 (`54ec34c`): the same pass removes `count - BOSSES_MAX + 1` heard bosses

**What's wrong.** `MakeRoomForBoss` removes one boss per new boss:

```lua
if count < BOSSES_MAX then return end
local instance = ns.db.drops[stalestInstance]
instance.bosses[stalestNPC] = nil
```

A SavedVariables file from an older release (or one that was flooded before
this fix) with, say, 3000 bosses stays at 3000 forever: it stops growing,
but never shrinks to `BOSSES_MAX`, and every new boss pays the scan over all
3000.

**Why it matters.** Bounded, so no new harm, but the comment above
`BOSSES_MAX` ("Bosses kept across all instances") reads as a hard limit, and
the copies most likely to be over it are the ones a flood already hit.

**Fix.** Either loop until `count < BOSSES_MAX` (collect the bosses, sort
once by newest kill, remove from the front), or trim once at
`PLAYER_LOGIN`. Or reword the comment: "at most BOSSES_MAX new bosses are
added; data saved above it stays as it is".

### R10 · The boss-cap scenario doesn't reach Save's re-read of an instance that lost its last boss

- **Severity:** nit
- **Area:** WoW API (tests)
- **Where:** `tests/smoke/modules/Core-Drops.lua:152-169`; code at `NeedRoll/Core/Drops.lua:228-231`
- **Status:** fixed in round 3 (`54ec34c`): new scenario "the boss cap removes only heard bosses (released builds)" covers both instance cases

**What's wrong.** Each boss in the scenario has its own instance (20000 to
21000), and the evicted one (20000) is never the instance of the boss being
saved. So this line, which keeps `Save` from writing into an instance table
that `MakeRoomForBoss` just removed from `ns.db.drops`, never runs with a
changed answer:

```lua
instance = ns.db.drops[drop.instance] -- gone when its only boss was the one removed
```

Nor does the case where the evicted boss shares an instance with others (the
instance must stay).

**Why it matters.** Dropping the re-read would make `Save` add the new boss to
an orphaned table: the kill would be lost from SavedVariables with no error,
and no scenario would notice.

**Fix.** Add to the scenario: fill to the cap with the stalest boss alone in
instance A, then hear a new boss in instance A; assert `ns.db.drops[A]` holds
the new boss. And one with two bosses in instance B, the stalest evicted;
assert B is still there with the other.

## Round 2

Reviewed `48e123f` (`c9ed6c5..48e123f`: `Core/Drops.lua`, `UI/DropTalk.lua`,
`tests/smoke/modules/Core-Drops.lua`), and re-read in full every function the
branch touches (`HeardNumber`, `HeardRewards`, `DecodeKill`, `Decode`,
`DecodeQuest`, `Save`, `MakeRoomForBoss`, `NewestKillAt`, `ProbeSince` and its
wrapper, `Answer`, `PrintBoss`, `Drops:Print`, `RowEnter`, `FillRow`).

**Checks, round 2.**

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the three changed files | passed |
| `luacheck --no-global -q` vs `origin/dev` | Drops.lua 21 vs 20: the one new warning is `unused argument 'self'` on the `Drops:ProbeSince` wrapper (`:1716`), the same as the `Drops:DecodeQuest` wrapper beside it (`:1711`) and 19 other methods; it follows from R5's fix, accepted. DropTalk.lua and the test module 0 |
| `python3 tools/locales.py --check` | passed |
| `tests/smoke/check.sh` | passed, all three runs ("all passed" x3, 974 ok lines). The boss-cap scenario runs its capped branch in the packaged run and its `keepAll` branch in dev and secret |
| `git diff --check`, line length | clean, nothing over 120 |

**Round-1 findings re-checked.**

- R1: `HeardNumber(field, max)` (`:335-340`) with `COORDINATE_MAX = 1000` (`:1058`) on x and y; class above `GetNumClasses()` becomes 0 (`:1073`). `GetNumClasses` is in Ketho's `forever` `GlobalAPI.lua` and mirrored in `tests/smoke/wow.lua:1261`. Class IDs can have gaps below the count, which is harmless: a gap ID is still a small bounded key. `BOSSES_MAX = 1000` against 287 bosses in `Data/Bosses.lua` (counted by loading it in `lua5.1`), so the comment's "well above" holds. Fixed, with the eviction choice opened as R8. Local checkouts skipping the caps: accepted.
- R2: `"2147483648"` added to `notWhole`; instance 2147483647 accepted; boss-cap scenario; `/nr droptalk list` escaping checked through `W.Printed`. Fixed.
- R3: length check gone. Fixed.
- R4: coordinate sentence moved to `COORDINATE_MAX`, which now enforces it. Fixed.
- R5: `local function ProbeSince` plus `function Drops:ProbeSince` in the debug block; DropTalk calls `ns.Drops:ProbeSince`; the probe assertion moved into a `dev = true` scenario. Fixed.
- R6: comment reworded. Fixed.
- R7: left as is, with the implementer's reason.

**The eviction logic, as asked.**

- *Correctness.* `Save` calls `MakeRoomForBoss` only for a boss not yet saved and only outside `keepAll`. The scan counts every boss and finds the one with the oldest newest kill (`math.huge` start, so a boss with no kills, at 0, goes first). It returns early under the cap. Otherwise it removes that boss, and its instance when that was the last boss. `Save` then re-reads `ns.db.drops[drop.instance]`, so a new boss in the instance just emptied gets a fresh table instead of an orphaned one. The boss being saved can't be the evicted one, since it doesn't exist yet. When the count is at or over the cap, a boss to remove always exists. The logic is right, but what it chooses to evict is not: R8. Its untested path is R10.
- *Cost on each save.* Only a save that adds a new boss pays. A save into a boss already saved (every item after the first in a D2 kill, every repeat report) skips the scan. A new boss costs one pass over every boss and every kill: at most 1000 x `KILLS_MAX` (50) = 50 000 steps. Timed in stock `lua5.1` here: 5.2 ms per scan at that worst case (the game's Lua should be similar; inferred). That is acceptable for an event that happens once per new boss. A flood is throttled by the server, so it gets a few ms a second at most. No finding. If it ever matters, keeping `boss.lastAt` up to date in `Save` drops the inner loop (a new key, so older saved data still loads).
- *Saved data from older versions.* Older files have the same shape (`instance.bosses[npc].kills[key].at`), and `NewestKillAt` guards a missing `at` with `or 0`, so they load and evict cleanly. Kills saved without `at` count as oldest and go first, which is reasonable. A file already over the cap stays at its size and never trims: R9.

**New in round 2:** R8 (should fix), R9 (nit), R10 (nit). Readability of the
new code is sound: names say what they hold (`stalestInstance`,
`NewestKillAt`, `MakeRoomForBoss`), the comments say why (the cap's reason, the
re-read's reason), and no nesting goes past three levels. `MakeRoomForBoss`
does one job: make room. No new game call besides `GetNumClasses`, and no new
untrusted text reaches the screen.

### R11 · The full heard-boss scan runs on every new-boss save, even far below the cap

- **Severity:** nit
- **Area:** Redundant code (work repeated per save)
- **Where:** `NeedRoll/Core/Drops.lua:222-243` (`MakeRoomForBoss`), called from `Save` at `:249`
- **Status:** fixed after round 3 by the integrator, as sketched below; smoke tests pass in all three modes

**What's wrong.** The implementer asked whether to gate this. `MakeRoomForBoss`
builds `heardBosses` before it knows whether anything must go. That means
running `HeardOnly` and `NewestKillAt` over every kill, plus one new table
per heard boss, and only afterwards checking:

```lua
if count < BOSSES_MAX then return true end
```

Under the cap, which is where every player's file normally sits, all of that
is thrown away.

**Why it matters.** It costs time and garbage on every new boss for everyone.
Timed in stock `lua5.1` with 999 heard bosses: 0.84 ms with one kill each and
8.1 ms with 50 kills each (`KILLS_MAX`), against 0.11 ms to count the bosses
alone. The game's Lua is assumed to be similar (inferred). Each pass also
leaves up to 999 small tables for the garbage collector. It's not a hitch a
player would notice once per new boss, but a flood of new bosses pays it on
every message.

**Fix.** Count first, and build the list only when at or over the cap:

```lua
local function MakeRoomForBoss()
    local count = 0
    for _, instance in pairs(ns.db.drops) do
        for _ in pairs(instance.bosses) do count = count + 1 end
    end
    if count < BOSSES_MAX then return true end
    local heardBosses = {}
    for instanceID, instance in pairs(ns.db.drops) do
        for npcID, boss in pairs(instance.bosses) do
            if HeardOnly(boss) then
                heardBosses[#heardBosses + 1] = { instance = instanceID, npc = npcID, newest = NewestKillAt(boss) }
            end
        end
    end
    -- sort, remove and return as now
end
```

Behaviour is the same. The existing scenarios cover both branches (under the
cap in the first boss-cap scenario, over it in the second).

### R12 · A heard drop the cap turns away is logged as "already saved"

- **Severity:** nit
- **Area:** Readability (disinformation in the dev log)
- **Where:** `NeedRoll/Core/Drops.lua:249`; `TakeKill` `:1472-1479`, `TakeOldDrop` `:1493`
- **Status:** not worth it (round 3)

**What's wrong.** When every saved boss is the player's own, `Save` returns
`false` for a heard boss, which is the same answer as "already saved". So
`TakeKill` and `TakeOldDrop` log the message as `known`, and the dev drop talk
window shows "already saved" for a drop that was not saved.

**Why it's not worth it.** It needs 1000 bosses that the player looted
personally, which no released player is near. It shows only in the dev-only
log, and no saved data or sent message is wrong. A distinct status would mean
a new return value through `Save` and both callers for a case that won't
happen.

### R13 · `KILLS_MAX` still lets heard kills push the player's own kills out of one boss

- **Severity:** nit
- **Area:** Security
- **Where:** `NeedRoll/Core/Drops.lua:270` (`DropOldest(boss.kills, KILLS_MAX)`)
- **Status:** open for Mike (round 3): pre-existing, not changed by this branch; a follow-up if wanted

**What's wrong.** R8's protection covers whole bosses. Within one boss,
`DropOldest` still removes the kill with the oldest `at`, whoever looted it.
The same flood trick works on a single boss: about 50 made-up kills of a boss
the player has looted push the player's own kills of that boss out.

**Why it matters.** It is narrower than R8 was, since the flooder has to name
the boss, and it predates this branch. But those own kills are again what
probe answers send.

**Fix.** Give `DropOldest` a filter, or pass `HeardOnly`-style logic, so that
only kills with `by` are dropped first (`if entry.by and (entry.at or 0) <
oldestAt`), and fall back to any kill only when all are the player's own.

## Round 3 (final)

Reviewed `54ec34c` (`026ab18..54ec34c`: `Core/Drops.lua`,
`tests/smoke/modules/Core-Drops.lua`), and re-read `NewestKillAt`,
`HeardOnly`, `MakeRoomForBoss`, `Save` and every caller of `Save` in full.

**Checks, round 3.**

| Check | Result |
| --- | --- |
| `luac5.1 -p` on both changed files | passed |
| `luacheck --no-global -q` | Drops.lua 21 warnings, the same as round 2 (no new ones); test module 0 |
| `python3 tools/locales.py --check` | passed |
| `tests/smoke/check.sh` | passed: "all passed" x3, 977 ok lines. The new scenario is a real test only in the packaged run (it returns early under `keepAll`), and passes there |
| `git diff --check`, line length | clean, nothing over 120 |

**Round-2 findings re-checked.**

- R8: fixed. `HeardOnly` (`:209-215`) treats a boss as removable only when every kill has `by`. Own finds (`by == nil`) are never removed. When nothing heard can go, `MakeRoomForBoss` returns false and `Save` turns away a heard drop (`drop.by` set). An own drop is still saved, so the player's own file can pass 1000, which a flood can't cause. A mixed boss (own and heard kills) is protected, which is right.
- R9: fixed. It removes `math.min(count - BOSSES_MAX + 1, #heardBosses)` bosses, stalest first, and returns `count - removed < BOSSES_MAX`. Worked through: at exactly 1000, one goes; an over-full 1005 loses 6 and lands on 999 with room; all-own loses 0 and returns false. When two stale bosses share an instance, the instance is removed only once it is empty, and each boss is listed once, so the loop never indexes an instance it already removed. The sort comparator is strict (`<`), which is valid for `table.sort`.
- R10: fixed. The new scenario covers the own boss surviving 1000 heard, all-own turning a heard boss away, trimming 1005 back to 1000, the stalest boss alone in the new boss's instance (fresh instance entry, kill kept), and the stalest boss sharing an instance (instance kept).

**Every save path, as asked.**

| Caller | `by` | Result at the cap |
| --- | --- | --- |
| `Record` (`:766`): own loot in dungeons and raids (`Scan`), the open world (`ScanWorld`), guessed drops (`Guess`) | nil | always saved; a heard boss is removed if one exists, else the file goes past 1000 |
| `TakeKill` (`:1472`), D2 | sender or `ANON` | saved after removing a heard boss; turned away when none is removable (logged `known`, R12) |
| `TakeOldDrop` (`:1493`), D1 | `ANON` | same as `TakeKill` |
| `SaveWhenLoaded` (`:1456`), a heard item that loads later | as heard | same; the `false` is ignored, as before |
| A save into a boss already saved (later items of a D2 kill, repeats) | any | skips `MakeRoomForBoss` entirely |
| Local checkouts (`Drops.keepAll`) | any | no cap (accepted in round 2) |

**Gating the scan (the implementer's question).** Yes, gate it: R11. Counting
bosses alone costs about a tenth of a millisecond. The full heard-boss pass
costs 0.8 to 8 ms plus up to 999 garbage tables, and today it runs on every
new-boss save even though under the cap it is never used. The change is
behaviour-neutral and the current scenarios already cover both sides. It is a
nit, so it doesn't hold the verdict, but it is the one item I'd still do
before merging.

**Final classification of everything not fixed.**

- R7: not worth it (left as is, implementer's reason).
- R11: fixed after round 3 (counted first, list built only at the cap).
- R12: not worth it.
- R13: open for Mike; pre-existing, a follow-up PR if wanted.
- Local checkouts skipping the caps (R1): accepted.

Nothing blocking or should-fix remains, so the verdict is **Ready**.

## Area notes

### Readability

Checked every changed function against `docs/READABLE-CODE.md`. Names are
game terms (`HeardNumber`, `HeardRewards`, `ProbeSince`, `ns.Literal`,
`HEARD_NUMBER_MAX`); no one-letter names outside the allowed aliases (`i`,
`r, g, b`, `W`). Formatting is 4-space, LF, no line over 120 characters,
`local` everywhere, `local _, ns = ...` unchanged. No function grew past one
job or three levels of nesting. Comments say why (`HeardNumber` names the
`tonumber` inputs it shuts out; `ns.Literal` says what a doubled `|` stops);
the DropTalk comment above `RowEnter` accurately names the two places that
hand row text to the game (`row.right` and `row.status` carry only the
addon's own text: `When`, `STATUS`, `LISTED_SHORT`). The Wishlist comment
"Pasted text is shown as typed (ns.Literal)." is short but still says why.
Lua 5.1 traps: no `cond and nil or x`; the `gsub` calls whose second return
would leak are wrapped in parentheses (`ns.Literal`, `RowEnter` line 295) or
sit before the last argument (test `Hear(W, ...:gsub(...), "GUILD")`, where
Lua keeps only the first value); `ns.Literal`'s pattern `"|"` is not a magic
character. Findings: R3, R4, R5, R6.

### WoW API

The change adds no new game call, event, widget method, template, atlas or
`Enum`; it changes the arguments of calls the file already made. Checked
against Ketho's `forever` lists in the scratchpad copy:

| API | Use in the change | In `forever` lists | Where looked |
| --- | --- | --- | --- |
| `GameTooltip:SetText` | `RowEnter`, escaped title | yes | `WidgetAPI.lua` GameTooltip methods |
| `GameTooltip:AddLine` | `RowEnter`, escaped sub, lines, raw text | yes | `WidgetAPI.lua` GameTooltip methods |
| `GameTooltip:NumLines` | new UI scenario | yes | `WidgetAPI.lua` GameTooltip methods |
| `FontString:SetText` | `FillRow`, escaped name and sub | yes | `WidgetAPI.lua` |
| `CHAT_MSG_ADDON` | unchanged handler, now strict decode | yes | `Events.lua` |
| `GetNumClasses` | suggested in R1 only | yes | `GlobalAPI.lua` |
| `GameTooltip:SetItemByID` | unchanged line in `RowEnter` | inferred (FrameXML tooltip data mixin; not in `WidgetAPI.lua`) | `WidgetAPI.lua`, `Mixins.lua`, `FrameXML.lua` |
| `print` | `PrintBoss`, `Drops:Print` | inferred (Lua base library) | n/a |

No removed nil guards, no new globals (`.luarc.json` untouched; luacheck shows
no new global warnings), no upvalue-limit risk (no closures added to
`CreateOverview`), nothing secure or protected touched. Heard text is
`ns.Plain`ed at the top of the `CHAT_MSG_ADDON` handler (`:1444`), so no secret
value reaches the new code. No player-facing strings were added (all new text
is dev-only English, as the rest of `DropTalk.lua`), so `L[...]` doesn't apply.
`tests/smoke/wow.lua` needs nothing new. No UI layout, size, font or color
changed, so `docs/STYLE-GUIDE.md` doesn't need an update. Dev-only code stays
dev-only: `Drops:Print` is inside `--@debug@`, `DropTalk.lua` is in `.pkgmeta`'s
ignore list, and the dev-only scenarios are marked `dev = true` (the first
Core-Drops scenario isn't, and passes in the packaged run). Finding: R2.

### Redundant code

Compared `ns.Literal` against every pipe-escaping site in the addon
(`grep -rn '"||"\|gsub("|"'`): the only other one was the Wishlist import,
which the change folds into `ns.Literal`. `WL:CleanName`
(`Core/Wishlist.lua:129`) also neutralises `|`, but by replacing it with a
space together with `:` and newlines, because list names go into share
strings; that is a different job and rightly stays. `HeardNumber` sits beside
the existing decode helpers (`SplitMessage`, `NilIfEmpty`, `IsKillKey`) and has
no older twin; `HeardRewards` replaces the old inline pattern. No `Theme:`
helper applies (no new widgets). No dead code added. The `or ""` on
`entry.sub` in `RowEnter` and `FillRow` can't trigger (every row builder sets
`sub`) but is a harmless guard. Finding: R3.

### Security

Untrusted inputs touched: every D1, D2, Q1 and R1 field heard on
`CHAT_MSG_ADDON` (realm channel, guild, group), and pasted wishlist exports.

Number fields, field by field:

- D2 (`DecodeKill`): instance, difficulty, encounter, npc, build, each item ID and count: `HeardNumber`. type: `TYPE_NAMES`. kill: `IsKillKey` (`^%d+%-%x+$`). credit, partial, guessed: compared to fixed letters.
- D1 (`Decode`): instance, difficulty, encounter, npc, item, count, build: `HeardNumber`; the rest as D2.
- Q1 (`DecodeQuest`): quest, level, class, giverID, map, x, y, instance, build, dropper: `HeardNumber`; rewards: `HeardRewards`; side and giver: fixed letters.
- R1 (`Answer`): since: `HeardNumber`; then clamped by `SINCE_MAX`, and only probers are answered (game-set sender), at most once per `ANSWER_GAP`.
- `NoteFormat`'s `tonumber(number)` (`:535`) reads a `%d+` capture and only compares it to `FORMATS`; a huge value just counts as newer, which still needs `NEWER_SENDERS` (3) different senders. Sound as is.

All number fields are covered. What is still open is range, not format: R1.

Heard text reaching the screen, place by place:

- `UI/DropTalk.lua` `FillRow`: `row.name` and `row.sub` escaped; `row.right` and `row.status` carry only the addon's own text.
- `RowEnter`: title, sub, each of `lines`, raw message escaped; `LISTED[...]` is the addon's own text; `SetItemByID` takes a heard number, capped.
- `SummaryText` and the window status line: counts only.
- `Drops:Print`/`PrintBoss` chat print: place and boss names escaped; item text comes from the game's links; `boss.encounter` and counts are numbers.
- Release builds: no heard text reaches any FontString, tooltip or print. `UI/LootGrid.lua:60-61` shows only `Drops:KillCount`, a number; the `instance.name` uses in `MainFrame.lua`, `Overview.lua` and `LootGrid.lua` read NeedRoll's own data, not `ns.db.drops`.
- Heard names don't reach any hyperlink; item links are built by the game from IDs.

Sender names (the implementer's second question): left as they are, and that
is sound. The sender is set by the game server, not by the message (the file
says so at `:1257-1259`), and character and realm names can't contain `|`
(inferred from the game's naming rules). In the drop talk window they sit
inside `sub` and are escaped anyway; the one raw use is `PrintBoss`' "from
%s" list (`:1766-1767`), which is game-set text.

Outputs: no change to what is sent, the outbox, the daily cap or the "Share
drops" switch. Credits and names: nothing new is written anywhere public.
Two related things I noticed outside the diff, both pre-existing and not
findings for this change: probe answers re-send `boss.name` and
`instance.name` as saved, which can be text first heard from another player
(`KillMessages`, `:1329-1331`), so a probe answer can carry it on; and the
scraper's `merge_drops` keeps the first heard `name`/`instanceName` per NPC in
`scraper/drops/observed.json`. Neither ships heard text in the release zip as
far as I followed it, but any future code that emits those names into
`NeedRoll/Data/` should escape them the same way.

## Round history

- 2026-10-18, `6c3fb55`, round 1: **Changes needed**. Opened R1 to R7; none closed.
- 2026-10-18, `48e123f`, round 2: **Changes needed** (0 blocking, 1 should fix, 2 nits). Closed R1 to R6 (R1's local-checkout exemption accepted); R7 left as is; opened R8, R9, R10.
- 2026-10-18, `54ec34c`, round 3 (final): **Ready** (0 blocking, 0 should fix). Closed R8, R9, R10; opened R11 (open for Mike, recommended), R12 (not worth it), R13 (open for Mike, pre-existing).

## Integration

Applied onto `origin/dev` at `be91951` (which now carries #616-#618, including
the Wishlist "owned items" change) on `claude/addon-readability-pass-rg51s6`.
The patch applied cleanly; the Wishlist import still escapes through
`ns.Literal`. On the result: `tests/smoke/check.sh` all passed in dev, packaged
and secret-values modes, `luac5.1 -p` passes on every changed Lua file, and
`python3 tools/locales.py --check` exits 0.
