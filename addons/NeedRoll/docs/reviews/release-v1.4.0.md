# Review: v1.4.0 release (everything since v1.3.0)

| | |
| --- | --- |
| Branch | `v1.3.0..origin/dev` (release review); round 2 fixes on `claude/project-thread-uz4qel` (`origin/dev..HEAD`) |
| Commit reviewed | round 1 `68f5ec0`; round 2 `6c57352` (no uncommitted changes) |
| Date | 2026-11-09 |
| Round | 2 |
| Verdict | **Ready** (0 blocking, 0 should fix, 3 nits open: R7, R11 and R13 left for Mike; R14 fixed after round 2) |
| Needs | Players: `/reload` is enough. The release `.toc` lists the same files as v1.3.0, because the packager strips the `#@debug@` block that holds `Core\DropPull.lua` (inferred from `.pkgmeta` and the `.toc`). Local checkouts: a full restart, because `Core\DropPull.lua` is a new file in the `.toc` and the game reads file lists only at startup. |

## What the change does

**Realm channel (PR #831, #834).** WoW: Forever's live servers let NeedRoll join
its realm channel, NRDT, but refuse every addon message sent there with the
channel notice `NOT_ALLOWED_IN_CHANNEL`. NeedRoll now reads that notice. It
marks the channel silent at once, saves the time in
`NeedRollDB.channelRefusedAt`, and for the next 24 hours starts every login
with the channel silent, so drops go straight to the group or guild. The
first login after that tests the channel again. NeedRoll stays in the channel
the whole time, because its member list is how Mike finds the players who
share.

**Whispered probes (PR #834).** A released copy now answers a probe that a
PROBERS character (Mike) whispers to it, and the answers go back by whisper
through the outbox. Whisper entries never reach the saved outbox: they are
taken out at `PLAYER_LOGOUT`. The game's "No player named ... is currently
playing" line about a player NeedRoll whispered is hidden. A new dev-only
file, `Core/DropPull.lua`, lets a PROBERS character read NRDT's member list
every 2 minutes. It skips members on realms of the other ruleset (PvE or PvP,
read from GUIDs and realm names), whispers one of the others a probe, and
takes the D2 and Q1 answers whispered back within 30 minutes.

**Battle.net friends (PR #836).** The player's own finds (D2 kills and Q1
quests) also go to up to 5 Battle.net friends who are playing WoW: Forever in
the same region, through `C_BattleNet.SendGameData`. Each friend's copy is
its own outbox entry, which leaves on its own one-a-minute turn. Finds that
friends send arrive as `BN_CHAT_MSG_ADDON` and are saved like finds heard in
the guild.

**Window styles (PR #835).** Two new window styles join Native and Modern:
**Dark**, Modern's layout in neutral greys, and **ElvUI**, with square
corners, ElvUI's colors and ElvUI's font. The ElvUI style reads those from
the player's own ElvUI at run time and is offered only while ElvUI is
loaded. A table, `SKINS` in `UI/Theme.lua`, now says what makes each style
(corners, font face and flags, name prefix, whether it can be shown). Each
style gets its own window (`Theme:WindowName`). Settings and `/nr style`
list only the styles that can be shown.

**Data (PR #828, #829).** A hand-kept quest (The Coldbringer's Eye) and the
combat log watcher's import.

## Scope

- `NeedRoll/Core/DropPull.lua` (new, dev-only: listed in `.pkgmeta` ignore and in a `.toc` debug block): reads the member list, picks players by ruleset, whispers probes, takes their answers, and adds `/nr droptalk pull`.
- `NeedRoll/Core/Drops.lua`: ChannelRefusal (refusal notice, 24h wait, test message re-sent elsewhere), Whispers (whisper outbox entries, bounce line, probe answers by whisper, `Whispers.Read`), BattleNet (friend list, slot entries, `BattleNet.Read`), `Destination`/`SendNext`/`Queue` for WHISPER and BNET, `ChannelListIndex`/`ChannelMemberCount` made `Drops.` functions, and dev hooks.
- `NeedRoll/Core/Init.lua`: `AddonMessages:Send` sends BNET through `C_BattleNet.SendGameData`; `/nr style` cycles through the styles that can be shown (`NextSkin`); `/nr droptalk pull`; a comment for the new saved key `channelRefusedAt`.
- `NeedRoll/Core/Tooltip.lua`: recognises the main window of every style (`IsOwnWindow`).
- `NeedRoll/Locales/enUS.lua`: `Styles: %s.` replaces `Styles: modern, native.`; Native and Modern move to the Theme section; Dark and ElvUI are added.
- `NeedRoll/NeedRoll.toc`: `Core\DropPull.lua` in a debug block.
- `NeedRoll/UI/Theme.lua`: the Dark palette, reading ElvUI (`ElvUIEngine`, `ReadElvUIMedia`, `ElvUIPalette`, `ElvUIFontFlags`), `SKINS`, square corners (`CornerFill`, `SquareOutline`, `CornerOutline`, square card slices), `ShapeIcon`, the `input`/`inputEdge`/`divider` colors, `WindowName`, `IsSkinAvailable`, `AvailableSkins`, and `fontKeys`.
- `NeedRoll/UI/MainFrame.lua`: window names come from `Theme:WindowName`; `UI:SetSkin` refuses a style that can't be shown; comments.
- `NeedRoll/UI/Settings.lua`: the Window style choices come from a function (`SkinChoices`, `SKIN_BY_NAME`, `Settings.Choices`).
- `NeedRoll/UI/Lists.lua`: profession and page icons use `Theme:ShapeIcon`.
- `NeedRoll/UI/Wishlist.lua`: the paste box uses `input`/`inputEdge`.
- `NeedRoll/UI/DropTalk.lua` (dev-only): log labels for WHISPER, BNET, pull and bounced.
- `NeedRoll/UI/FrameDebug.lua` (dev): font keys come from `Theme.fontKeys`.
- `NeedRoll/UI/TalentPlanner.lua`, `NeedRoll/UI/Welcome.lua`: comments only.
- `README.md`, `docs/STYLE-GUIDE.md`: the new styles. The STYLE-GUIDE values match `UI/Theme.lua` (checked palette hexes, alphas, fonts and corners).
- `.pkgmeta`: ignores `NeedRoll/Core/DropPull.lua`.
- `tests/smoke/wow.lua`, `tests/smoke/scenarios.lua` and `tests/smoke/modules/*` (Core-DropPull new; Core-Drops, Core-Init, UI-DropTalk, UI-MainFrame, UI-Settings, UI-Theme): stand-ins for `C_BattleNet`, the channel roster, `ERR_CHAT_PLAYER_NOT_FOUND_S`, `BNET_CLIENT_WOW`, `WOW_PROJECT_ID` and a stand-in ElvUI, plus scenarios for each feature.
- Skipped, as generated: `NeedRoll/Data/Dungeons/Deadmines.lua`, `KroldokStronghold.lua`, `Data/KnownDrops.lua`, `Data/KnownQuests.lua` and `Data/Quests.lua`. `needroll_scraper build --check` shows no data file would change, so none was edited by hand.
- Inputs, checked only for what they hold, not for style: `scraper/quests/forever.json` (a hand-kept quest), plus the watcher imports `scraper/quests/logged.json`, `reported.json`, `scraper/drops/observed.json`, `items.json`, `credits.json`, `scraper/abilities/observed.json` and `scraper/professions/trainer_checks.json`. Credits stay in `scraper/drops/credits.json`, which `.pkgmeta` keeps out of the zip.
- Not in scope: `CHANGELOG.md`, `CHANGELOG-DETAILED.md`.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 23 changed Lua files (Data skipped) | passed |
| `luacheck --no-global -q`, new compared with `v1.3.0` | no new warnings. Warning texts compared with line numbers removed: Drops, Init, Settings, MainFrame, scenarios and wow.lua match; Theme.lua has one long line fewer; DropPull.lua and Core-DropPull.lua are clean |
| `tests/smoke/check.sh` (dev, packaged, secret values, in combat) | passed: "all passed" in all four runs (216 / 208 / 216 / 216 files loaded) |
| `python3 tools/locales.py --check` | passed |
| `python3 tools/translations.py` | passed (exit 0). It reports `Styles: modern, native.` as no longer used in all 10 translation files; the Translations bot PR removes those |
| `cd scraper && python3 -m unittest discover -s tests` | passed (350 tests) |
| `python3 -m needroll_scraper build --check` (extra: hand edits to generated data) | passed: "No data files changed" |
| Lua 5.1 limits (extra; `luac5.1 -l -l`, peak of locals active at once in the main chunk) | Drops.lua **199 of 200** (v1.3.0: 198), see R4. Theme.lua 89. Most upvalues in any function: 16 in Drops.lua, 8 in Theme.lua, 5 in DropPull.lua (limit 60) |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Security | `NeedRoll/Core/Drops.lua:2376` | Battle.net messages are read without a length cap | fixed in round 2 (`6c57352`) |
| R2 | should fix | Security | `NeedRoll/Core/Drops.lua:2381` | One Battle.net friend can count as several newer-format senders | fixed in round 2 (`6c57352`) |
| R3 | should fix | Security | `NeedRoll/Core/DropPull.lua:208` | Pull whispers skip the outbox's one-a-minute gap and DAILY_MAX | fixed in round 2 (`6c57352`) |
| R4 | should fix | WoW API | `NeedRoll/Core/Drops.lua` (main chunk; `:742`) | Drops.lua is at 199 of Lua 5.1's 200 locals | fixed in round 2 (`6c57352`) |
| R5 | should fix | Readability | `NeedRoll/Core/Drops.lua:1155` | "No friend gets the same find twice" isn't true when the friend list changes | fixed in round 2 (`6c57352`): comment corrected |
| R6 | should fix | Redundant code | `NeedRoll/UI/Theme.lua:130` | The Dark palette copies about 25 of Modern's values as literals | fixed in round 2 (`7a2281f`) |
| R7 | nit | Readability | `NeedRoll/Core/Drops.lua:742` | `ChannelRefusal` holds state that isn't about refusal | left for Mike |
| R8 | nit | Readability | `NeedRoll/Core/DropPull.lua:48`, `:53` | `lastRead.members` is a count; `Saved()` is a noun | fixed in round 2 (`6c57352`) |
| R9 | nit | Redundant code | `NeedRoll/Core/DropPull.lua:92` | The "strip the realm" pattern now appears three times | fixed in round 2 (`6c57352`) |
| R10 | nit | WoW API | `NeedRoll/Core/Drops.lua:1129` | `WOW_PROJECT_ID` is nil-guarded but `BNET_CLIENT_WOW` isn't | fixed in round 2 (`6c57352`) |
| R11 | nit | Readability | `NeedRoll/UI/Theme.lua:1652` | A search box with a named skin takes the window's corners | left for Mike |
| R12 | nit | Readability | `NeedRoll/Core/DropPull.lua:40` | ANSWER_WINDOW is shorter than a full whispered answer takes | fixed in round 2 (`6c57352`) |
| R13 | nit | Readability | `NeedRoll/Core/DropPull.lua:296` | `TakesWhisperFrom` reads like a question but now also extends the window | open (round 2) |
| R14 | nit | Readability | `tests/smoke/modules/Core-Drops.lua:616`, `:649`, `:673`, `:801` | Test comments still name the old constants | fixed (after round 2, comments only) |

### R1 · Battle.net messages are read without a length cap
- **Severity:** should fix
- **Area:** Security
- **Where:** `NeedRoll/Core/Drops.lua:2376-2387` (`BattleNet.Read`)
- **Status:** fixed in round 2 (`6c57352`)

**What's wrong.** `BattleNet.Read` checks only the prefix and the type, then
hands the text to the same readers as channel and guild messages:

```lua
function BattleNet.Read(prefix, text, _, senderID)
    text, senderID = Plain(text), Plain(senderID)
    if prefix ~= PREFIX or not ns.db or type(text) ~= "string" or not senderID then return end
    ...
    local id, status = TAKE[kind](text, sender)
```

On the other paths, the game caps every addon message at 255 bytes, and
those readers were written for that size. `C_BattleNet.SendGameData` carries
much more: about 4 KB, 4078 bytes per warcraft.wiki.gg (inferred; the wiki
couldn't be fetched from here).

**Why it matters.** Any Battle.net friend's game, or a friend running a
modified copy, can send a D2 with hundreds of items in `fields[9]`. Every
item becomes a saved drop, and every item not cached yet starts an
`ns.Items:Load`. Unbounded `npcName`, `instanceName`, `title`, `giverName`
and `zone` strings are also stored in SavedVariables (`Save`,
`SaveQuest`). Released builds cap bosses, kills and quests (`BOSSES_MAX`,
`KILLS_MAX`, `QUESTS_MAX`), so the damage is bounded, but a single message
can still be 16 times what any other path allows.

**Evidence.** `DecodeKill` (`Drops.lua:513`) and `DecodeQuest` (`:1719`) put
no limit on field lengths or item counts. `MESSAGE_MAX = 250` (`:110`) is
used only when encoding.

**Fix.** Turn away long texts before reading, the same limit every copy
sends with:

```lua
if prefix ~= PREFIX or not ns.db or type(text) ~= "string" or #text > MESSAGE_MAX or not senderID then return end
```

`Whispers.Read` doesn't need this, as the game caps whispers at 255.

### R2 · One Battle.net friend can count as several newer-format senders
- **Severity:** should fix
- **Area:** Security
- **Where:** `NeedRoll/Core/Drops.lua:2379-2381`
- **Status:** fixed in round 2 (`6c57352`)

**What's wrong.** `Drops:NoteFormat(text, "BNET", "Battle.net " .. senderID)`
counts each Battle.net sender by its `gameAccountID`. "Outdated" stops all
of this copy's sending once `NEWER_SENDERS` (3) different senders have sent a
newer format, and it stays stopped across sessions until the addon's
version changes (`Drops.lua:1057-1090`). That design rests on this rule:
"one player sending made-up messages can't silence everyone".

**Why it matters.** A `gameAccountID` is a temporary ID for a friend's
game session, and it changes when they log in again (inferred from
warcraft.wiki.gg's description of `BNGetGameAccountInfo`; not checked in
game). One friend who sends `D9:...` three times, logging out and back in
between, counts as three senders. The player's copy then stops sharing to
the group, guild, channel and friends until NeedRoll updates. The saved
`dropNewer.senders` table also gains a new key on every such login.

**Evidence.** Lines quoted above. `Outdated()` counts the keys of
`newer.senders`.

**Fix.** Count every Battle.net friend together as one sender
(`Drops:NoteFormat(text, "BNET", "Battle.net")`), so friends alone can never
silence a copy. Or leave Battle.net messages out of the newer-format check:
a friend on a newer release is also heard in the guild or the group.

### R3 · Pull whispers skip the outbox's one-a-minute gap and DAILY_MAX
- **Severity:** should fix
- **Area:** Security (sending limits)
- **Where:** `NeedRoll/Core/DropPull.lua:208-224` (`Ask`), `:80-87` (`CanPullNow`)
- **Status:** fixed in round 2 (`6c57352`)

**What's wrong.** `Ask` calls `AddonMessages:Send(text, "WHISPER",
member.name)` directly. The outbox's `SEND_GAP` (60 s since `lastSentAt`)
doesn't apply, and the send doesn't count towards the outbox's `DAILY_MAX`
(100). `CanPullNow` checks lockdown, combat and the pull's own `DAILY_MAX`
(60), but not when the outbox last sent.

**Why it matters.** The rule is one addon message a minute in all, from
every path (reviewer checklist; the root of `Core/Drops.lua`). A PROBERS
character that is also sharing its own finds can send an outbox message and
a pull within the same second. Over an hour that is up to 90 messages, not
60, and up to 160 a day, not 100. It is dev-only and limited to Mike's
characters, so this won't trip the game's throttle (10 at once, refilled
one a second). But the stated limit doesn't hold, and it's the kind of
pattern the servers may already be reacting to on NRDT.

**Evidence.** `grep -n "lastSentAt\|CountTowardsDailyMax" NeedRoll/Core/DropPull.lua`
finds nothing. `lastSentAt` is a file local in `Drops.lua:1055`.

**Fix.** Give the pull the outbox's gap. Export
`Drops.SecondsSinceSend()` (`lastSentAt and GetTime() - lastSentAt`), have
`CanPullNow` return false while it is under `SEND_GAP`, and stamp the time
after a pull with `Drops.NoteSent()`, which sets `lastSentAt` and calls
`CountTowardsDailyMax()`. Then the outbox also waits a minute after a pull.

### R4 · Drops.lua is at 199 of Lua 5.1's 200 locals
- **Severity:** should fix
- **Area:** WoW API (Lua 5.1 limits)
- **Where:** `NeedRoll/Core/Drops.lua`, the main chunk (comment at `:738-741`)
- **Status:** fixed in round 2 (`6c57352`)

**What's wrong.** The file's main chunk peaks at 199 locals active at once in
a local checkout (v1.3.0: 198). The release adds `ChannelRefusal`,
`Whispers` and `BattleNet` and turns two local functions into `Drops.`
functions. The ChannelRefusal comment already notes the file is "close to
Lua 5.1's limit of 200 locals", and three tables now group state only to
save locals (see R7).

**Why it matters.** The next new local in the file makes Lua refuse to load
it ("main function has more than 200 local variables"). All of drop sharing
would then be missing, and every file that uses `ns.Drops` would error. CI
(`luac`, smoke) would catch it before a release, so players aren't at risk.
But every future change to Drops.lua will run into it, and the workaround
pushes unrelated state into tables whose names don't fit it.

**Evidence.** `luac5.1 -l -l` lists the main chunk's locals with the range
where each is active. The most active at once: 199 now, 198 at v1.3.0. The
dev-only block (`--@debug@` at `:2453` to `:3232`) holds 29 of those
top-level locals (`LOG_MAX`, `myPings`, `WhenJoined`, the roll-call ones,
`Listen`, the quest-log helpers ...).

**Fix.** Move the dev-only block into its own file that `.pkgmeta` ignores
and the `.toc` lists in a debug block, as `Core/DropPull.lua` already does.
It reaches what it needs through `Drops.` exports. That frees about 29
locals. If that's too much for this release, fold the block's constants
into the tables it already uses (`RollCall = { WAIT = 180, MAX = 100, ... }`).

### R5 · "No friend gets the same find twice" isn't true when the friend list changes
- **Severity:** should fix
- **Area:** Readability (a comment that misleads), with a behaviour effect
- **Where:** `NeedRoll/Core/Drops.lua:1155-1160` (`BattleNet.Recipient`), header comment `:1114-1120`
- **Status:** fixed in round 2 (`6c57352`): the comment now says a change in who is online can repeat or skip a friend

**What's wrong.**

```lua
-- The game account a "BNET" entry goes to now, or nil when fewer friends
-- play now than its slot (so no friend gets the same find twice).
function BattleNet.Recipient(entry)
    local friends = BattleNet.OnlineFriends()
    if entry.friendSlot > #friends then return nil end
    return friends[(entry.friendTurn + entry.friendSlot - 1) % #friends + 1]
end
```

The slot becomes an index into the friend list as it is when each entry
is sent, a minute or more apart. If a friend logs in or out of Forever
between two entries of the same find, the indexes shift.

**Why it matters.** Say friends [B, C] are online and a find queues slots 1
and 2. Slot 1 goes to B. Then A logs in and the list becomes [A, B, C], so
slot 2 goes to index 2, which is B again. B gets the find twice and C never
gets it. If B logs out instead, the list becomes [C], so slot 2 is past the
end and is dropped, and C never gets it. Each duplicate also spends one of
the day's 100 messages.

**Evidence.** Code above. `BNGetNumFriends` order follows online status
(inferred from the game's friends list; not in Ketho's docs).

**Fix.** Track whom each find reached instead of a fixed slot. Keep a
table for this session, `BattleNet.sentTo[id] = { [gameAccountID] = true }`,
and send each BNET entry to the first online Forever friend not in it. The
entry then needs no `friendSlot`/`friendTurn`. After a `/reload` the table
is empty, so a duplicate is possible then, which is acceptable. If the
slots stay, change the comment to say a change in who is online can repeat
or skip a friend.

### R6 · The Dark palette copies about 25 of Modern's values as literals
- **Severity:** should fix
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/Theme.lua:130-187` (`palettes.dark`), compared with `ElvUIPalette` (`:375-438`)
- **Status:** fixed in round 2 (`7a2281f`)

**What's wrong.** The Dark comment says it keeps "the same gold headings,
green accent and quest, link and level colors" as Modern, and it does so by
repeating Modern's hex literals: `heading`, `accent`, `rate`, `note`,
`complete`, `incomplete`, `accepted`, `available`, `link`, `dropper`,
`quest`, `rule`, `divider`, `common`, the four level colors, `stripLine`,
`sectionEdge`, `scrollThumbHover`, `flowDone`, `discRing`, `pillEdge`,
`selectedText`, `wingLine`, `wingFade` and the card fills. Next to it,
`ElvUIPalette` refers to Modern's values instead (`complete =
modern.complete`).

**Why it matters.** The same job is done two ways in one file. A later
change to Modern's quest yellow or level colors won't reach Dark unless
someone notices the copy, and the two styles drift apart even though the
comment says they match.

**Evidence.** Diff of `Theme.lua:130-187`, and `:375-438`.

**Fix.** Build Dark from Modern plus what differs, using the FrameXML
`CopyTable` (in Ketho's `forever` FrameXML list, and already used in
`UI/MapEdit.lua`):

```lua
local function Overlay(base, changes)
    local palette = CopyTable(base)
    for key, color in pairs(changes) do palette[key] = color end
    return palette
end
palettes.dark = Overlay(palettes.modern, { bg = Hex("121212"), panel = Hex("1A1A1A"), ... })
```

Only the greys and off-whites then remain in Dark's table.

### R7 · `ChannelRefusal` holds state that isn't about refusal
- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/Core/Drops.lua:742-748`
- **Status:** left as is: left for Mike to decide

**What's wrong.** `ChannelRefusal.isPasswordAsked` is about a password
request and `testEntry` belongs to the echo test. Both live in the
refusal's table only to save a local (R4). A reader looking for the
password logic won't think to look under "refusal".

**Fix.** Rename the table to what it holds (`ChannelCheck`: echo test,
refusal and password), or move `isPasswordAsked` once R4 frees room.

### R8 · `lastRead.members` is a count; `Saved()` is a noun
- **Severity:** nit
- **Area:** Readability
- **Where:** `NeedRoll/Core/DropPull.lua:48`, `:261`, `:310`; `:53`
- **Status:** fixed in round 2 (`6c57352`)

**What's wrong.** `DropPull.lastRead = { at = ..., members = #members, ... }`
gives a number the same name as the `members` list a few lines above.
`PrintStatus` then names a string `members` as well. `Saved()` is a
function named like a value (READABLE-CODE §1: functions are verbs).

**Fix.** Use `memberCount` and `sameRulesetCount`, and rename the function
`SavedPulls()` or `PullData()`.

### R9 · The "strip the realm" pattern now appears three times
- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/Core/DropPull.lua:92`, `NeedRoll/Core/Drops.lua:2172`, `:2538`
- **Status:** fixed in round 2 (`6c57352`)

**What's wrong.** `name:match("^(.*)%-[^%-]*$") or name` is written out in
three places. The addon also uses `Ambiguate(sender, "none")` elsewhere.

**Fix.** Use one helper (`Drops.WithoutRealm(name)`) or
`Ambiguate(name, "short")`, which is in Ketho's `forever` GlobalAPI and
already used in `Drops:IsMe`.

### R10 · `WOW_PROJECT_ID` is nil-guarded but `BNET_CLIENT_WOW` isn't
- **Severity:** nit
- **Area:** WoW API
- **Where:** `NeedRoll/Core/Drops.lua:1129-1133`
- **Status:** fixed in round 2 (`6c57352`)

**What's wrong.** Both are FrameXML constants that Ketho's lists don't
include (inferred to exist in Forever). The check guards one and not the
other:
`Plain(info.clientProgram) == BNET_CLIENT_WOW and WOW_PROJECT_ID ~= nil and ...`.
If `BNET_CLIENT_WOW` were nil, a friend whose `clientProgram` is nil would
pass that test.

**Fix.** Guard both (`BNET_CLIENT_WOW ~= nil and ...`), or explain in a
comment why one needs it and the other doesn't.

### R11 · A search box with a named skin takes the window's corners
- **Severity:** nit
- **Area:** Readability (the doc comment says it takes the named skin)
- **Where:** `NeedRoll/UI/Theme.lua:1652-1661`
- **Status:** left as is: left for Mike to decide

**What's wrong.** `Theme:SearchBox(..., skin)` takes the colors and fonts of
`skin`, but `self:Rounded(box, ...)` draws with `self.corners`, the
window's corners. The `/nr icondebug` "All icons" box asks for "modern",
yet it comes out square while the window uses the ElvUI style. The
STYLE-GUIDE says that box is "always modern".

**Fix.** Look up the named skin's corners (`SKINS[skin].corners`) and pass
them to `CornerFill`/`CornerOutline`, or let `Theme:Rounded` take a
corners argument.

### R12 · ANSWER_WINDOW is shorter than a full whispered answer takes
- **Severity:** nit
- **Area:** Readability (a constant's comment that doesn't hold), dev-only
- **Where:** `NeedRoll/Core/DropPull.lua:40`, compared with `NeedRoll/Core/Drops.lua:2137-2139`
- **Status:** fixed in round 2 (`6c57352`)

**What's wrong.** A pulled player answers after up to 60 s
(`ANSWER_WAIT`), then sends up to 25 messages (`ANSWER_MAX`) one a minute,
behind whatever their outbox already holds. That can take more than 26
minutes. `ANSWER_WINDOW = 30 * 60` closes only a few minutes after that.

**Why it matters.** A player with a few of their own finds still queued
loses the last answers. Mike's pull then misses exactly the oldest finds
it asked for.

**Fix.** Refresh `DropPull.pulledAt[key]` with each answer taken, so the
window runs from the last answer, or derive the window as
`ANSWER_MAX * 60 + 60 + margin`, with a comment.

## Round 2

Reviewed `git diff origin/dev..HEAD` on `claude/project-thread-uz4qel`:
`7a2281f` (R6) and `6c57352` (R1–R5, R8–R10, R12). I re-read every
function those commits touched, in full.

### Round 1 findings

| ID | Round 2 status | How it was checked |
| --- | --- | --- |
| R1 | fixed | `BattleNet.Read` now returns early on `#text > MESSAGE_MAX`, before `NoteFormat` and the readers. New scenario: a long friend message isn't read, while one of the usual length is. |
| R2 | fixed | Every Battle.net friend is one sender, `"Battle.net"`, and the comment says why. New scenario: friends sending a newer format count as one sender. |
| R3 | fixed | `CanPullNow` refuses while `Drops.SendGapLeft() > 0`. `Ask` first calls `Drops.TakeSendTurn()`, which counts towards `DAILY_MAX` and stamps `lastSentAt`, so the outbox then waits its minute too. New scenario: pulls and outbox messages are at least 60 s apart, and pulls count towards the day. A refused send still uses its turn; that is the cautious choice and is fine. |
| R4 | fixed | Constants and state are grouped into `Probe` and `RollCall` tables (no move to a separate file). Measured with `luac5.1 -l -l`: peak active main-chunk locals **189** in a local checkout and **163** packaged (the `--@debug@` block stripped with awk), as the implementer said. Most upvalues in one function is still 16. Every old name (`PROBE_VERSION`, `ANSWER_GAP`, `ROLL_CALL_*`, `openRollCall`, `answeredAt`) is gone from the addon code, but test comments still use some (R14). |
| R5 | fixed (comment) | The comment now says one friend can get a find twice and another none. The behaviour stays as it is, which the round 1 fix allowed. |
| R6 | fixed | `palettes.dark = PaletteWith(palettes.modern, {...})` using FrameXML `CopyTable`. I loaded both versions' palette tables in Lua 5.1 and compared every key and channel of modern, dark and native: **0 differences**, so Dark is pixel for pixel the same. A new scenario checks this too. |
| R7 | left for Mike | — |
| R8 | fixed | `SavedPulls()`, `memberCount`, `sameRulesetCount` and `membersRead`. |
| R9 | fixed | One helper, `Drops.WithoutRealm`, used in `IsProber`, `Drops.Heard` and `PlayerKey`. `IsProber` now hashes the unchanged name a second time when it has no hyphen. The result is the same and costs nothing. |
| R10 | fixed | `BNET_CLIENT_WOW ~= nil` guard added. |
| R11 | left for Mike | — |
| R12 | fixed | Each answer taken restarts the window (`TakesWhisperFrom` refreshes `pulledAt`), and the comments explain it. See R13 on the name. |

### The change to `SendNext` (in released code)

`SendNext` now returns `Drops.SendGapLeft()` when that is above 0, and
`Queue` uses the same helper in place of its inline sum. The claim checked:
- **Only `SendNext` sets `lastSentAt` in released builds.** True. The only
  assignments are `Drops.lua:1253` (`SendNext`) and `:2505`
  (`Drops.TakeSendTurn`), and the second is inside the `--@debug@` block
  (`:2480` to `:3269`).
- **Players see no change.** After a send, `SendNext` returns `SEND_GAP`
  and `Pump` waits that long, so on the next call the gap is already 0.
  `GetTime()` is per frame and a timer fires on the first frame past its
  time. The other ways in (`Queue`, which already waited out the same gap;
  `SendTestElsewhere`, which waits `SEND_GAP`; the 20 s start after login,
  with `lastSentAt` still nil) all arrive with the gap spent.
- **It can't stall the outbox.** The check comes after the empty-outbox and
  stop checks. It returns at most `SEND_GAP` (60 s), never nil, so `Pump`
  always schedules another try. `SendGapLeft` is `math.max(0, ...)`, so a
  clock oddity can't make it negative.
- **One effect on dev builds.** While the outbox sends every minute, the
  pull's 2-minute tick always lands inside a gap, so pulls wait until the
  outbox is idle. The outbox's own finds go first, which is the intended
  priority, so this is not a finding.

### `W.OnOneDay` (tests/smoke/wow.lua:99-109)

`W.OnOneDay` replaces the global `date`, but only for the day string
(`"%Y-%m-%d"` with no time), and puts it back through `W.Restoring`, even
when the test fails. No addon file keeps its own local copy of `date`
(grepped), so the stand-in reaches `CountTowardsDailyMax`, `PulledToday` and
DropPull's `day`. It is used by two scenarios (the pull's limits; friends'
copies). It is sound.

### New findings

### R13 · `TakesWhisperFrom` reads like a question but now also extends the window
- **Severity:** nit
- **Area:** Readability (READABLE-CODE §9)
- **Where:** `NeedRoll/Core/DropPull.lua:296-302`; called at `NeedRoll/Core/Drops.lua:2380`
- **Status:** open

**What's wrong.** The R12 fix gave a yes/no check a side effect:

```lua
function DropPull.TakesWhisperFrom(sender)
    ...
    if not (pulledAt and GetTime() - pulledAt < DropPull.ANSWER_WINDOW) then return false end
    DropPull.pulledAt[key] = GetTime()
    return true
end
```

`Whispers.Read` calls it before it checks the message kind, so any
NeedRoll whisper from that player keeps the window open, including one it
then ignores or can't read. The comment says this, but the name doesn't.

**Fix.** Rename it to say it acts (`DropPull.AcceptAnswerFrom`), or keep
the question pure and add `DropPull.NoteAnswer(sender)`. `Whispers.Read`
would call that only once a D2 or Q1 was read. Dev-only.

### R14 · Test comments still name the old constants
- **Severity:** nit
- **Area:** Readability (searchable names)
- **Where:** `tests/smoke/modules/Core-Drops.lua:616` (`ANSWER_GAP`), `:649` and `:801` (`ROLL_CALL_GAP`), `:673` (`ANSWER_GAP`)
- **Status:** open

**What's wrong.** R4 renamed these to `Probe.ANSWER_GAP` and `RollCall.GAP`,
so a search for the new names misses these tests.

**Fix.** Write the new names in those four comments.

### Round 2 checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 7 changed Lua files | passed |
| `luacheck --no-global -q`, compared with `origin/dev` (texts with line numbers removed) | no new warnings in any of the 7 files |
| `tests/smoke/check.sh` (dev, packaged, secret values, in combat) | passed: "all passed" in all four runs (216 / 208 / 216 / 216 files loaded) |
| `python3 tools/locales.py --check` | passed |
| Dark palette equality (extra; both versions' palette tables loaded in Lua 5.1) | 0 differences across modern, dark and native |
| Lua 5.1 limits (extra) | Drops.lua 189 dev / 163 packaged of 200; Theme.lua 90; most upvalues 16 |

## Area notes

### Readability

Checked every changed function against READABLE-CODE.md. Names are in
game terms (`ChannelRefusal`, `Whispers.BouncedName`,
`BattleNet.ForeverAccount`, `ShownSkin`, `CornerOutline`), and the constants
carry their units (`RETRY_AFTER`, `BOUNCE_WAIT`, `PULL_GAP`, `ASK_GAP`).
Functions are short and use guard clauses; none nests more than three
levels. Comments explain the game facts behind odd code: the
`NOT_ALLOWED_IN_CHANNEL` notice, rulesets read from realm names, GUID realm
IDs, the saved outbox never holding a prober's name, ElvUI filling in its
media after login. No change is narrated ("now" appears only as "at this
moment"). Every `local _, ns = ...` header is in place. One Lua 5.1 trap was
looked for and not found: no `cond and nil or x`. The bounce pattern built
from `ERR_CHAT_PLAYER_NOT_FOUND_S` escapes every magic character
(`Drops.lua:1011-1013`). ChannelRefusal, Whispers and BattleNet each have
functions in several places in the file (because each needs locals defined
later, such as `Pump` and `Queue`). Each place names its section, so that is
acceptable while R4 stands. The STYLE-GUIDE was updated in the same release,
with values matching the code.

### WoW API

| Call / event / method | In Ketho's `forever` lists | Where checked |
| --- | --- | --- |
| `C_BattleNet.SendGameData` (returns `Enum.SendAddonMessageResult` per Ketho's annotations) | yes | GlobalAPI.lua; vscode-wow-api BattleNetDocumentation.lua |
| `C_BattleNet.GetFriendNumGameAccounts`, `GetFriendGameAccountInfo`, `GetGameAccountInfoByID` | yes | GlobalAPI.lua |
| `BNGetNumFriends`, `BNFeaturesEnabledAndConnected` | yes | GlobalAPI.lua |
| `GetNormalizedRealmName`, `GetPlayerInfoByGUID`, `UnitGUID` | yes | GlobalAPI.lua |
| `C_ChatInfo.GetChannelRosterInfo`, `GetNumDisplayChannels`, `GetChannelDisplayInfo`, `SetSelectedDisplayChannel` | yes | GlobalAPI.lua |
| `InCombatLockdown`, `IsInInstance`, `C_Timer.NewTicker`, `C_Timer.After` | yes | GlobalAPI.lua |
| `C_AddOns.IsAddOnLoaded`, `CreateFont` | yes | GlobalAPI.lua |
| `CreateColor`, `CopyTable` (suggested in R6) | yes | FrameXML.lua |
| `BN_CHAT_MSG_ADDON`, `CHAT_MSG_SYSTEM`, `CHAT_MSG_CHANNEL_NOTICE`, `CHAT_MSG_CHANNEL_NOTICE_USER`, `PLAYER_LOGOUT`, `CHANNEL_PASSWORD_REQUEST` | yes | Events.lua |
| `SetColorTexture`, `SetVertexColor`, `GetFont`, `SetFont`, `SetShadowColor`, `SetShadowOffset`, `SetFrameLevel`, `GetFrameLevel`, `SetGradient`, `SetTexCoord` | yes | WidgetAPI.lua |
| `ERR_CHAT_PLAYER_NOT_FOUND_S` ("No player named '%s' is currently playing.") | yes | GlobalStrings/enUS.lua |
| `BNET_CLIENT_WOW`, `WOW_PROJECT_ID` | inferred (FrameXML constants, not in the lists; see R10) | grep of all five lists |
| `ChannelFrame` (Blizzard_Channels, load-on-demand) | inferred; nil-guarded (`DropPull.lua:82`) | FrameXML.lua lists only `ToggleChannelFrame` |
| `_G.ElvUI` and its engine's `media` / `db.general` | third-party; every field is type-checked (`ElvUIEngine`, `ElvUIColor`, `ReadElvUIMedia`) | `Theme.lua:327-361` |

- **Combat.** No call from the four blocked-for-every-frame list was added.
  `SetSelectedDisplayChannel` isn't restricted per Ketho's docs, and
  `DropPull` refuses to run in combat, in an instance, or while the Chat
  Channels window is open. The style windows are plain frames built through
  the existing path. The `--combat` smoke run passed.
- Secret values: every new read of a unit, roster, Battle.net or event value
  goes through `Plain` (roster name and GUID, realm name, friend info
  fields, `characterName`, BN text and sender, notice type, system message).
- The new game calls are mirrored in `tests/smoke/wow.lua`, which defines no
  global Forever lacks (`WOW_PROJECT_ID`'s value is marked as made up). Each
  feature has scenarios (channel refusal, whispered probe and bounce, the pull
  and its rulesets, friends' copies and their turns, the four styles with a
  stand-in ElvUI).
- Dev-only code: `Core/DropPull.lua` is in `.pkgmeta` and a `.toc` debug
  block, and the Drops exports it uses sit inside `--@debug@`. The packaged
  smoke run loads 208 files and passed.
- Player-facing text is literal `L["..."]`, and the English list is in sync.
- ElvUI: nothing of ElvUI's is copied. No files, textures or fonts were
  added (`git diff --name-status` shows no media). `ELVUI_DEFAULTS` holds only
  default color numbers and a font-style name. The font is ElvUI's own file,
  loaded from the player's install by its path at run time, with
  `STANDARD_TEXT_FONT` used if it fails (`MakeFont`). Its colors are read once,
  when the style is first used: the window is built lazily
  (`MainFrame.lua:2543`), after ElvUI has started.

### Redundant code

Compared against `Theme:Border` (reused by `SquareOutline`),
`Theme:MaskRound` (wrapped by `ShapeIcon`), `SlicedTexture`, `Theme:Rounded`
and `Theme:RoundedOn` (extended, not duplicated), `AddonMessages:Send`
(extended for BNET rather than a second sender), `Queue`/`Destination`
(WHISPER and BNET added to the one outbox rather than a second outbox),
`ns.Literal` (the DropTalk log escapes `|` codes), `ns.HeardNumber`, and
`Ambiguate` (R9). `Tooltip.lua`'s `IsOwnWindow` replaces the hard-coded
name list with `Theme.skins`. `FrameDebug`'s font names now come from
`Theme.fontKeys` instead of stripping name prefixes. No dead code or stray
prints were found outside `@debug@`. Findings: R6, R9.

### Security

Untrusted inputs this release touches:

- **Whispered addon messages** (`Whispers.Read`). A released copy acts only
  on `R1` from a sender `IsProber` accepts. The answer is limited by
  `ANSWER_GAP` (15 min, shared with the channel) and `ANSWER_MAX` (25),
  and it goes through the outbox (one a minute, `DAILY_MAX`). D2 and Q1
  answers are taken only in a dev build, only from players it pulled within
  `ANSWER_WINDOW`, and through the same anchored decoders. The prober's name
  never reaches SavedVariables, because whisper entries are removed at
  `PLAYER_LOGOUT`. Known and pre-existing: PROBERS keys leave out the realm,
  so a namesake of Mike's character on another realm of the same ruleset can
  make a copy whisper it finds. The data is the same as what copies used to
  answer on the open channel.
- **Battle.net game data** (`BattleNet.Read`). Only D2 and Q1 are read;
  nothing is answered or passed on. Findings: R1 (length) and R2 (newer
  format counted per session ID). The friend's `characterName` (read from
  the game, not the message) is saved as the finder only when the message
  carries the credit flag. That is the same rule as for the guild.
- **System and channel notices.** The bounce line is matched with the
  localized global string, anchored, and acted on only for a name NeedRoll
  whispered within 60 s. `NOT_ALLOWED_IN_CHANNEL` counts only for NRDT
  (`IsOurChannelEvent`). Anything heard on NRDT clears the saved refusal,
  which can happen only if the channel really carries messages. A clock set
  back can't keep the refusal fresh (`age >= 0`).
- **ElvUI's tables** come from another addon. Every field is type-checked,
  and no string from them is run or shown.
- **Sending limits.** "Share drops" Off stops everything: BNET and WHISPER
  entries go through `Queue`/`SendNext`, which check `ChannelOn` and wipe the
  outbox, and the pull checks `ChannelOn`. One a minute holds across
  channel, guild, group, whisper and BNET entries, because each BNET copy
  takes its own turn (`8b91297`), except for the dev pull (R3).
- **Names.** Pull state is saved by `ProberKey` hash
  (`NeedRollDB.dropPull.askedAt`), never by name. BNET entries name no friend
  (a slot only). The dev log (`dropTalk`) keeps names only in local
  checkouts. Nothing was found that copies credits into the addon folder.
- No `loadstring`, `RunScript` or `setfenv` anywhere in the diff. No
  workflow or Python code changed (only JSON inputs).

## Round history

- Round 1, 2026-11-09, `68f5ec0`: **Changes needed** (0 blocking, 6 should fix, 6 nits). Opened R1–R12.
- Round 2, 2026-11-09, `6c57352`: **Ready** (0 blocking, 0 should fix, 4 nits open). Closed R1–R6, R8–R10 and R12; R7 and R11 left for Mike; opened R13 and R14.
