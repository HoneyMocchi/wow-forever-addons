# Review: NeedRoll v1.3.0 (everything since v1.2.0)

| | |
| --- | --- |
| Branch | `v1.2.0..origin/dev` (PRs #819 to #822, plus the daily data commits merged from `main`), then in round 2 the fixes on `claude/project-thread-yxw2rj`, into `dev` before the v1.3.0 changelog PR |
| Commit reviewed | Round 1: `473a4bc` (`origin/dev`). Round 2: `e939f1b` (fixes `0859468`, then a merge of `dev` that adds only Translations PR #823). The round 2 diff `473a4bc..0859468` was read in full, and every function it touches was read again with its callers. No uncommitted changes besides this doc. |
| Date | 2026-11-08 |
| Round | 2 (the last) |
| Verdict | **Changes needed** at round 2 (0 blocking, 1 should fix open, 3 nits open), now Mike's call (`CLAUDE.md`: at most two rounds). Round 1's R1-R7 are all fixed in `0859468`. New in round 2: R8 (should fix), R9-R11 (nits). |
| Needs | `/reload` is enough: no file is added to `NeedRoll.toc` or `UI/UI.xml`, only existing Lua files change. The new saved keys (`dropNoticeRound`, and `dropListen` in dev builds) need no default. |

## What the change does

**Drop sharing back on (#821).** `Drops.isSharingEnabled` is `true` again (`Core/Drops.lua:95`), so every copy joins the hidden realm channel NRDT 15 seconds after login, sends its finds through the outbox again, and Settings shows Share drops and Credit my finds again. `tests/smoke/run.lua` no longer has to switch sharing on before logging in.

- **Chat number.** On WoW: Forever's live realms the game rejoined NRDT as /1, ahead of General. A new `ChatNumber` part (`Core/Drops.lua:618-676`) moves NRDT behind every other joined channel with `C_ChatInfo.SwapChatChannelsByChannelIndex`: one swap with each channel numbered after it, in turn. It runs after NeedRoll's own join, at login, in `KeepJoined` (every 10 minutes and after loading screens), and 2 seconds after the first `CHANNEL_UI_UPDATE` of a burst. It moves at most 5 times a session. It doesn't touch `ChatTypeInfo` (chat colours).
- **Notice round 2.** `UI/Welcome.lua` gains `DROP_NOTICE_ROUND = 2` and `StartDropNoticeRound`. An account whose saved `dropNoticeRound` is lower gets the first-login drop sharing notice once more. That includes accounts that answered on v1.0.x and never logged in while sharing was off. A saved Off stays Off until they answer.
- **Texts.** The Share drops tip and the notice's second paragraph now say Off stops the drop, quest and trainer messages, and that the version check still tells the guild and group which version runs. Two `L[...]` keys changed (`Locales/enUS.lua:1251, 1371`). The header comments of `Core/Drops.lua` say the same.

**Listen mode (#820, dev only).** `/nr droptalk listen` (`Core/Init.lua:772`, `Core/Drops.lua:2467-2518`, inside `--@debug@`) lets a local checkout join NRDT while sharing is switched off for everyone. It logs every NeedRoll message heard there as `listen` in the drop talk log, and keeps and answers none of them. Released code only gains two small locals, `IsListening` and `WantsChannel` (`:580-587`). `IsListening` is always false there, because `Drops.IsListening` lives in the stripped block. With sharing on, as in this release, the command only says it isn't needed.

**Round 2 fixes (`0859468`).** Drop sharing now waits for the player's answer. `Drops:ChannelOn()` needs `NeedRollDB.dropChannel == true`, which only Keep sharing or Settings' Share drops On save. nil means not answered: nothing is queued or sent, the realm channel isn't joined, and an outbox left from earlier sessions waits, retried every `RETRY` (120 s). A new notice round turns a saved `true` back into nil and keeps a `false`. The per-login reset while switched off is gone; the Switch comment says to bump `DROP_NOTICE_ROUND`. The version check ignores `CHANNEL` messages. Two phrases are reworded ("sends its finds at most one a minute", "in NeedRoll's credits list"). The R4-R7 comment, name, `Listen` table and smoke changes are also in. `tests/smoke/run.lua` says yes with `ns.Drops:SetChannel(true)` after logging in.

**Data.** Combat log watcher imports (#819, #822) and the daily data commits: `scraper/**/*.json`, `scraper/compare/page.html` and `state.json`, regenerated into `NeedRoll/Data/*`.

## Scope

All 37 changed files were listed. Every hunk in hand-written code was read with the code around it, and every new or changed function was read in full.

Addon, hand-written:
- `NeedRoll/Core/Drops.lua`: the Switch flipped and its comment; `ChannelOn`'s comment; `IsListening`, `WantsChannel` (new); `IsOurChannelEvent`; the new Chat number part (`ChatNumber.NumbersAfter`, `ChatNumber.MoveChannelLast`); `LeaveUnusedChannels`, `JoinChannel`, `KeepJoined`; the `CHANNEL_UI_UPDATE` handler (new); `CHAT_MSG_ADDON`'s listen branch; the `PLAYER_LOGIN` join; the drop talk log's `listen` status; in the dev block, `LISTEN_REPORT_WAIT`, `Drops.IsListening`, `PrintListenReport`, `Drops:ToggleListening` and their login line. Read around them: `SendNext`, `Queue`, `Destination`, `WhenJoined`, `RefusesWhileSwitchedOff`, `PrintChannelMembers`, `Drops.Log`, so the "nothing is sent" claims could be checked.
- `NeedRoll/Core/Init.lua`: the saved-key comments (`dropNoticeRound`), `commands.droptalk` (dev block). Read around them for R1: `AddonMessages`, the whole Version check, and its `CHAT_MSG_ADDON` handler.
- `NeedRoll/UI/Welcome.lua`: the notice's header comment, `DROP_NOTICE_ROUND`, `StartDropNoticeRound` (new), the login handler, the notice text. Read: `CreateDropNotice`, `ShowDropNotice`.
- `NeedRoll/UI/Settings.lua`: the Share drops tip. Read: the Credit my finds row.
- `NeedRoll/UI/DropTalk.lua` (dev window, ignored by `.pkgmeta`): the `listen` status.
- `NeedRoll/Locales/enUS.lua`: two phrases reworded, none added.

Smoke: `tests/smoke/modules/Core-Drops.lua` (3 new scenarios: two chat number, one listen mode), `UI-Welcome.lua` (one new scenario, the round restored by `WithNoticeUnanswered`), `run.lua` (override removed), `wow.lua` (`C_ChatInfo.SwapChatChannelsByChannelIndex` stand-in), `README.md`.

Docs: `docs/STYLE-GUIDE.md` (the Hidden settings row drops "off since November 2026").

Round 2 (`473a4bc..e939f1b`, 23 files, of which 10 locale files come from Translations PR #823 and the review doc itself). Every function the fixes touch was read again in full at `e939f1b`, with every caller of `ChannelOn`, `SetChannel`, `SendNext`, `Queue`, `JoinChannel` and `LeaveUnusedChannels`, and every writer of `dropChannel` (grep: `Drops:SetChannel` and `StartDropNoticeRound` only):
- `NeedRoll/Core/Drops.lua`: the header and Switch comments, `ChannelOn`, `IsListening` (now over `Drops.IsListenModeOn`), the Chat number comment, `MoveChannelLast` (`realmNumber`), `SetChannel`'s comment, `SendNext`'s unanswered wait, `Drops.ForgetChatNumberMoves` (dev block), the `Listen` table.
- `NeedRoll/Core/Init.lua`: the `dropChannel`/`shownDroptalkConsent` comments, the version check's `CHAT_MSG_ADDON` handler.
- `NeedRoll/UI/Welcome.lua`: header comment, `StartDropNoticeRound`, the notice text. `NeedRoll/UI/Settings.lua`: the credit tip. `NeedRoll/Locales/enUS.lua`: two phrases.
- Smoke: `Core-Drops.lua` (two scenarios: the cap and a refused swap), `Core-Init.lua` (versions on the realm channel), `UI-Welcome.lua` (two scenarios rewritten, two new, `SharingSentSince`, `WithMessageWaiting`, `IsWaiting`), `run.lua`, `README.md`. `docs/READABLE-CODE.md` §5.
- `NeedRoll/Locales/*.lua` other than enUS: Translations PR #823, a bot PR; checked only with the locale tools.

Generated, not reviewed for style: `NeedRoll/Data/{Abilities,Chains,ClassQuests,ClassSpells,HunterPets,KnownDrops,KnownQuests,Poisons,ProfessionGuide,Quests,RecipeTrainers,WarlockPets}.lua` and `Data/Dungeons/{BlackfathomDeeps,Stockade,TheDrownedCity}.lua`. No scraper, tool or workflow code changed (no `.py`, `.ps1` or `.yml` in the diff), so there was no generator to review. The JSON inputs and `scraper/compare/page.html` were only checked for privacy (Security).

## Checks

Round 1 results on `473a4bc`. Round 2 results on `e939f1b` are in the rows marked (round 2).

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 10 changed Lua files | Passed. Lua 5.1 (apt) and luacheck 1.2.0 (luarocks) were installed in this container for the review. |
| `luacheck --no-global -q`, base `v1.2.0` vs now | Same counts in every changed file: `Drops.lua` 25, `Init.lua` 9, `Settings.lua` 8, `Welcome.lua` 3, `enUS.lua` 53, `DropTalk.lua` 0, smoke files unchanged. The warning texts match too, apart from two long-line warnings whose lengths changed. Those are the two reworded `L["..."]` keys (`Settings.lua:91`, 376 characters; `Welcome.lua:204`, 303), literal keys as earlier reviews accepted. No other new line over 120. |
| Globals | `luacheck` without `--no-global`: "setting non-standard global" counts unchanged (`Init.lua` 8, the rest 0). The new code reads only `C_ChatInfo`, `GetChannelList`, `GetChannelName`, `JoinTemporaryChannel`, `LeaveChannelByName`, `C_Timer` |
| Lua 5.1 limits (`luac5.1 -l -l`) | `Core/Drops.lua`'s main chunk holds **199 live locals** at its end in a dev build (194 at `v1.2.0`; the limit is 200), 167 packaged (R6). Most upvalues in the file: 16. `Welcome.lua` main chunk: 29 locals. |
| Formatting | LF, ASCII, no tabs in changed lines |
| `python3 tools/locales.py --check` | Passed |
| `python3 tools/translations.py` | Exit 0. In each of the 10 other languages it reports the old versions of the two reworded phrases as "not used by NeedRoll any more", so those players see the new English text until the Translations PR. Known process, not a finding. |
| `tests/smoke/check.sh` (all four: dev, packaged, secret, combat) | Passed, "all passed" in each run (2362 `ok` lines over the four runs). The new scenarios pass in every mode (the listen one is `dev = true`, so it doesn't run packaged). |
| Probe scenario (scratch copy of the repo, not committed) | `--packaged`, as release `v1.3.0`: one `V:99.0.0` heard on `CHANNEL` NRDT sets `NeedRollDB.newestVersion = "99.0.0"`, and 14 `V:0.1.0` messages from 14 senders on NRDT send 14 whispers at once (R1) |
| `cd scraper && python3 -m unittest discover -s tests` | Passed, 350 tests (no scraper code changed) |
| Ketho's `forever` lists | `GlobalAPI.lua`, `Events.lua`, `WidgetAPI.lua`, `FrameXML.lua` downloaded from the `forever` branch to the scratchpad and grepped (table under WoW API). Blizzard's own `forever` sources (Gethe/wow-ui-source, `forever` branch) were also read: `Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua` for the swap's restrictions, `Blizzard_ChatFrame/Mainline/ChatConfigFrame.lua` for how the game's settings swap channels |
| (round 2) `luac5.1 -p` on the 19 Lua files changed since `473a4bc` | Passed |
| (round 2) `luacheck --no-global -q`, `473a4bc` vs `e939f1b` | Same warnings in every hand-written and smoke file, and no new globals. Only long-line lengths moved: the two reworded `L[...]` keys (`Settings.lua:106`, 133; `Welcome.lua:201`, 293) and the translated lines in the locale files. No other changed line over 120. |
| (round 2) Lua 5.1 limits | `Core/Drops.lua` main chunk: 198 live locals in a dev build (199 in round 1), 167 packaged |
| (round 2) `python3 tools/locales.py --check` | Passed |
| (round 2) `python3 tools/translations.py` | Exit 0. #823 translated round 1's two reworded phrases. Round 2's two rewordings show as "not used by NeedRoll any more" in all 10 languages, waiting for the next Translations PR, as expected. |
| (round 2) `tests/smoke/check.sh` (all four) | Passed, "all passed" in each run (2380 `ok` lines). The five new scenarios pass in every mode they run in (the two chat number ones are `dev = true`). |
| (round 2) Probe scenario (scratch copy, not committed) | `--packaged`: a character the game rejoined to NRDT at /1 (as it does from the last session), with the round 2 reset turning its `true` into nil, is still in NRDT at /1, ahead of General at /2, after 700 seconds. Answered Turn off and rejoined again: same (R8). |
| Privacy | No name from `scraper/drops/credits.json` (11 names) appears in any added line outside `scraper/drops/`, nor in any file under `NeedRoll/`, `docs/`, `tests/` or `.github/`. Partial-word hits were all quest text. No `Name-Realm` pattern in added data besides the smoke test's `Name-Testrealm`. `.pkgmeta` unchanged; `NeedRoll/Credits.txt` absent. |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Security | `Core/Init.lua:665-669` (`:622-637`, `:652-657`) | The version check believes `V:` messages heard on the realm channel: one stranger's message sets a fake update for every copy on the realm, for good, and many can burn the shared throttle | fixed in round 1 (`0859468`) |
| R2 | should fix | Security | `UI/Welcome.lua:203, 205`; `UI/Settings.lua:106`; `Core/Drops.lua:569-571, 946-955, 1015-1016` | The consent notice and Settings tips shown again in this release promise more than the code does: "fully opt-in", "at most one a minute", "the credits file that ships with NeedRoll" | fixed in round 1 (`0859468`) |
| R3 | nit | Redundant code | `UI/Welcome.lua:326-334`; `Core/Drops.lua:93-94` | Two ways to ask everyone again; the Switch comment says flipping it back re-asks everyone, which this release needed a round for | fixed in round 1 (`0859468`) |
| R4 | nit | Readability | `Core/Drops.lua:627-630`; smoke `Core-Drops.lua:809-816` | "The others keep their order and move up one": a channel after a free number moves further (/6 to /3), so a player's own channel numbers change | fixed in round 1 (`0859468`): comment; behaviour left as is |
| R5 | nit | Readability | `Core/Drops.lua:580-582, 2480-2482, 668` | `IsListening` names two functions; `Drops.IsListening()` is the one dot-call among `Drops:` methods; `number` in `MoveChannelLast` | fixed in round 1 (`0859468`) |
| R6 | nit | WoW API (Lua 5.1 limits) | `Core/Drops.lua` main chunk (`:580`, `:584`, `:640`, `:2478`, `:2486`) | `Core/Drops.lua` is at 199 of Lua 5.1's 200 locals in a dev build | fixed in round 1 (`0859468`): 198 now |
| R7 | nit | WoW API (smoke coverage) | `Core/Drops.lua:640-676`; `tests/smoke/modules/Core-Drops.lua:802-847` | No scenario for the 5-moves cap or a failed swap, and the cap's count leaks across scenarios | fixed in round 1 (`0859468`) |
| R8 | should fix | Security | `Core/Drops.lua:747-755` (`LeaveUnusedChannels`), `:18-21` | (round 2) A character still in NRDT from its last session isn't taken out while unanswered or Off: it stays in the channel, at /1 ahead of General | fixed after round 2 (`71c8a3f`, Mike chose "Fix all four") |
| R9 | nit | Readability | `UI/Welcome.lua:202, 213, 216` | (round 2) The notice still talks as if sharing were already on ("Keeping it on", "Keep sharing", "Turn off"), though nothing is shared until it is answered | fixed after round 2 (`71c8a3f`, Mike chose "Fix all four") |
| R10 | nit | Readability | `UI/Settings.lua:88`; `UI/Welcome.lua:239-240`; `Core/Drops.lua:809-817` | (round 2) Share drops turned On in Settings counts as a yes, but the notice still asks again at the next login | fixed after round 2 (`71c8a3f`, Mike chose "Fix all four") |
| R11 | nit | WoW API (smoke coverage) | `tests/smoke/modules/UI-Welcome.lua:296-302` | (round 2) No scenario checks that a Keep sharing given in round 2 is still on after the next login | fixed after round 2 (`71c8a3f`, Mike chose "Fix all four") |

### R1 · The version check believes `V:` messages heard on the realm channel: one stranger's message sets a fake update for every copy on the realm, for good, and many can burn the shared throttle
- **Severity:** should fix
- **Area:** Security (untrusted addon messages)
- **Where:** `NeedRoll/Core/Init.lua:665-669` (the version check's `CHAT_MSG_ADDON` handler); `:622-637` (`Version:Heard`); `:652-657` (the saved note is cleared only by an update to that version or later)
- **Status:** fixed in round 1 (`0859468`). The handler takes `chatType` and returns for `"CHANNEL"` (`Core/Init.lua:670-671`), with a comment saying why. New scenario "versions heard on the realm channel change nothing and get no answer" (`Core-Init.lua:291`): no `newestVersion`, no update line, no whisper. Round 1's note: the code predates this range: the handler has read every chat type since the version check came in, and NRDT exists since v1.0.2. But v1.1.0 and v1.2.0 never joined the realm channel (`isSharingEnabled = false`), and this release puts every copy back in it. So the release makes it live again.

**What's wrong.** The version check's handler drops the chat type (the third argument) and reads any `V:` message on NeedRoll's prefix:

```lua
ns:On("CHAT_MSG_ADDON", function(prefix, text, _, sender)
    if prefix ~= PREFIX or not sender then return end
    if Ambiguate(sender, "none") == UnitName("player") then return end
    Version:Heard(text, sender)
end)
```

Copies only ever send their version to the guild, the group, or as a whisper (`Version:Broadcast`, `:598-607`; `Version:Heard`'s reply, `:636`). A `V:` on the realm channel therefore never comes from a real copy. Yet `Heard` acts on it:
1. A newer version is saved (`ns.db.newestVersion = theirs`, `:630`) and announced: "v99.0.0 is available (you are running v1.3.0). Update through CurseForge." It also shows in the window's footer note (`UI/MainFrame.lua:1460`). The login check at `:654-657` clears the saved version only once the player runs that version or later, so a made-up `99.0.0` stays for good.
2. An older version gets a whisper back, once per sender per session (`self.answered[sender]`), sent at once through `AddonMessages:Send`, not through the one-a-minute outbox.

**Why it matters.** With sharing back on, every copy on the realm sits in NRDT, and anyone can join that channel and send on the `NeedRoll` prefix. One `V:99.0.0` from one character makes every NeedRoll player on the realm see a fake "update available" line, and a footer note that never goes away. A dozen characters sending `V:0.1.0` make every copy whisper a dozen times in the same second. The game lets a prefix send 10 messages, refilled one a second (`Init.lua:444-448`). Past that it answers "throttled", and after `THROTTLE_STOP` (3) throttled answers `AddonMessages` stops all of NeedRoll's messages until a `/reload` (`:519-523`). Drop sharing then goes quiet for the session on every copy that heard them. The texts can't inject chat codes (`ParseVersion` takes only `%d+.%d+.%d+`), so this is spoofing and a denial of service, not a link or name leak.

**Evidence.** Lines read. Probe scenario (Checks), packaged, as release `v1.3.0`: `CHAT_MSG_ADDON("NeedRoll", "V:99.0.0", "CHANNEL", "Griefer-Testrealm", ..., "NRDT")` leaves `newestVersion` at `99.0.0`. Fourteen `V:0.1.0` from fourteen senders on `CHANNEL` add 14 whispers to `W.sent` at once. The stand-in doesn't throttle. The game's throttling is inferred from the comment at `Init.lua:444-448`, which earlier releases saw in game.

**Fix.** Make the version check ignore the realm channel and any other custom channel. It speaks only on the guild, group and whisper, so it should listen only there:

```lua
-- Copies tell only their guild and group (and whisper older copies), so a
-- version heard on a custom channel (the realm channel included) is never
-- one of theirs: anyone can send there.
ns:On("CHAT_MSG_ADDON", function(prefix, text, chatType, sender)
    if prefix ~= PREFIX or not sender or chatType == "CHANNEL" then return end
    ...
```

Add a smoke scenario: a newer and an older version heard on `CHANNEL` change nothing and send nothing. Mike may also want to keep a newer version heard only by whisper from stranger to stranger out of `newestVersion`, but that is one target at a time, not the realm.

### R2 · The consent notice and Settings tips shown again in this release promise more than the code does: "fully opt-in", "at most one a minute", "the credits file that ships with NeedRoll"
- **Severity:** should fix
- **Area:** Security (player consent; player-facing text that says what the code doesn't do, `docs/READABLE-CODE.md` §9)
- **Where:** `NeedRoll/UI/Welcome.lua:203` ("sends at most one a minute"), `:205` ("It's fully opt-in"); `NeedRoll/UI/Settings.lua:106` (Credit my finds tip); the behaviour in `Core/Drops.lua:569-571` (`ChannelOn`), `:946-955` (`SendNext`), `:1015-1016` (`Queue`), `:752-754` (`JoinChannel`), `:448-450` (`CreditOn`); `Core/Init.lua:585-607` (version sends)
- **Status:** fixed in round 1 (`0859468`), the behaviour side. `ChannelOn` needs `dropChannel == true` (`Core/Drops.lua:574`). `SendNext` keeps the outbox while unanswered (`:961`). `StartDropNoticeRound` turns a saved yes back into nil once a round (`UI/Welcome.lua:326-331`), so "fully opt-in" is now true. "sends its finds at most one a minute" and "in NeedRoll's credits list" reword the other two. Checked in round 2: only Keep sharing and Settings On write `true`. The unanswered outbox can't grow (`Queue` returns while `ChannelOn` is false), nothing counts toward `DAILY_MAX` until a message really leaves, and the 120-second wait stops once Turn off wipes the outbox. Settings shows Off for nil (asserted). Saved data from v1.2.0 migrates as intended: `true` → nil and asked, `false` kept and asked, nil asked. Two new scenarios cover a v1.0.x Keep and a new account. Left open by the fix: R8 (the channel itself), R9 (the notice's wording). Round 1's note: the three texts predate this range, but this release shows them to every account again: round 2 of the notice, and the Settings rows no longer hidden.

**What's wrong.**
1. **"It's fully opt-in."** Sharing is on before the player answers. `ChannelOn` is `dropChannel ~= false`, and a new account's `dropChannel` is nil. Nothing in `Core/Drops.lua` reads `shownDroptalkConsent` (grep: its only uses are in `UI/Welcome.lua` and the comment in `Core/Init.lua`). So the channel is joined 15 seconds after login, and the outbox and probe answers run, while the notice is still waiting. The notice can wait a long time: it shows at 8 seconds only out of combat, has no close button, and the player can leave it open. Credit my finds is on until unticked too (`CreditOn`: nil means credited). Round 2 makes this more visible. Every account that answered Keep sharing on v1.0.x is asked again, yet its sharing, and the outbox left from before v1.1.0, runs from login on. The new Welcome scenario covers only an account that answered Turn off.
2. **"Sends at most one a minute."** That holds for the drop outbox (`SEND_GAP`). The version check sends on its own gap, per chat or player (`VERSION_GAP` per key, `Init.lua:535`, `:590`). A login in a guild and a group sends two at once, and joining a group of older copies whispers each of them. The reworded second paragraph now says the version check is separate, which makes the first paragraph's promise read as covering it.
3. **"In the credits file that ships with NeedRoll."** Credited names go only into `scraper/drops/credits.json` in the private repo (`scraper/needroll_scraper/observed.py:272`). `.pkgmeta` keeps `NeedRoll/Credits.txt` out of every zip, and root `CLAUDE.md` says names never reach anything public. The tip promises publication that doesn't happen.

**Why it matters.** This is the text a player reads to decide whether their character's finds, and their name, leave their game. Telling them it's opt-in while it is already on is the one thing a consent notice must not get wrong. The other two are smaller, but they too say more than the code does.

**Evidence.** Lines read and grepped as cited. No smoke scenario checks that nothing is sent before an answer for an account whose `dropChannel` is nil. The one at `UI-Welcome.lua:244-273` sets `dropChannel = false`.

**Fix.** Mike decides which side moves:
- **Make the code match "opt-in":** `ChannelOn` also asks `ns.db.shownDroptalkConsent == true`, so nothing joins or sends until Keep sharing is pressed. One line, plus a scenario for an account that answered Keep on v1.0.x: nothing leaves before it answers again. That also stops the old outbox until then.
- **Or make the words match the code:** "It's on unless you turn it off, here or any time in NeedRoll's Settings."

Either way, change "sends at most one a minute" to "sends its finds at most one a minute", and the credits tip to "On credits your character name, with what you shared, in NeedRoll's credits. Off stores your finds anonymously." Changed keys cost one more retranslation, and the Translations PR is redoing these phrases anyway (Checks).

### R3 · Two ways to ask everyone again; the Switch comment says flipping it back re-asks everyone, which this release needed a round for
- **Severity:** nit
- **Area:** Redundant code (`docs/READABLE-CODE.md` §6, one way of doing each thing), Readability (§9)
- **Where:** `NeedRoll/UI/Welcome.lua:326-334` (`StartDropNoticeRound`); `NeedRoll/Core/Drops.lua:93-94` (Switch comment); `UI/Welcome.lua:140-144` (header comment)
- **Status:** fixed in round 1 (`0859468`). The per-login reset is gone, the Switch comment says to bump `DROP_NOTICE_ROUND` (`Core/Drops.lua:94-95`), the Welcome header says the same, and the switched-off scenario now checks that logins leave the answers alone.

**What's wrong.** Asking every account again is now done two ways. One: every login while sharing is switched off marks the notice unanswered (`:333`, kept from v1.1.0). Two: the new round number marks it unanswered once per round (`:329-332`). This release shows the first one isn't enough on its own: accounts that didn't log in while sharing was off kept their old answer. That is why round 2 exists. The Switch comment still says the first way does it: "Setting it back to true brings it all back, and everyone gets the consent notice on their next login." `StartDropNoticeRound`'s name also covers only one of its two jobs.

**Why it matters.** The next time sharing is switched off and back on, whoever does it reads the Switch comment, flips the flag, and doesn't bump `DROP_NOTICE_ROUND`. Accounts that didn't log in during the off spell are then never asked, which is the very gap this release had to close.

**Fix.** Keep one way, the round. While sharing is off the notice isn't shown anyway (`ShowDropNotice`, `:242`), so the per-login reset adds nothing once the rule is "turning sharing back on bumps the round". Drop `:333` and its scenario's per-login assert, rename the function `StartNewNoticeRound` (or keep the name, which now fits), and reword the Switch comment: "Setting it back to true brings it all back; bump DROP_NOTICE_ROUND in UI/Welcome.lua with it, so every account is asked again." If Mike would rather keep both, at least fix the Switch comment and say in it that the round is needed.

### R4 · "The others keep their order and move up one": a channel after a free number moves further (/6 to /3), so a player's own channel numbers change
- **Severity:** nit
- **Area:** Readability (a comment that says less than the code does)
- **Where:** `NeedRoll/Core/Drops.lua:627-630` (the Chat number comment); smoke `tests/smoke/modules/Core-Drops.lua:809-816`
- **Status:** fixed in round 1 (`0859468`): the comment now gives the `/6` to `/3` example (`Core/Drops.lua:633-636`), and the smoke assert message matches. Behaviour left as is (Mike's call).

**What's wrong.** `MoveChannelLast` swaps the realm channel with every joined channel numbered after it, so it ends on the highest joined number. A channel past a free number then drops by more than one. The smoke scenario says so on purpose: `{ NRDT = 1, General = 2, Trade = 3, Guildies = 6 }` becomes General /1, Trade /2, Guildies **/3**, NRDT /6. The comment's "the others keep their order and move up one" reads as one number each. Its example has no free number, and "Numbers no channel has stay free" doesn't say a channel's number can jump across them.

**Why it matters.** A player's own channel, typed as `/6` for months, becomes `/3` the first time NeedRoll moves the realm channel, and `/6` is now the hidden NRDT. Typing `/6 hello` then talks into the hidden channel. That can be the right trade (General and Trade back on /1 and /2, as players expect), but the comment should let a reader see it without running the scenario.

**Fix.** Reword: "...so the others keep their order, each taking the next number down that a channel had: '1. NRDT, 2. General, 3. Trade, 6. Guildies' becomes '1. General, 2. Trade, 3. Guildies, 6. NRDT'." If Mike would rather keep players' own numbers, the move could stop at the first free number after the channels right behind it (`/1` → `/4` in that example). Guildies would then keep `/6`, but NRDT would no longer be last.

### R5 · `IsListening` names two functions; `Drops.IsListening()` is the one dot-call among `Drops:` methods; `number` in `MoveChannelLast`
- **Severity:** nit
- **Area:** Readability (§1 meaningful names, §6 consistency, §7 searchable names)
- **Where:** `NeedRoll/Core/Drops.lua:580-582` (local `IsListening`), `:2480-2482` (`Drops.IsListening`), `:668` (`local number = fromNumber`)
- **Status:** fixed in round 1 (`0859468`). The dev hook is `Drops.IsListenModeOn` (`:2500`), with a comment on why it is a dot function. The local `IsListening` is the only `IsListening`. `realmNumber`.

**What's wrong.**
- The local `IsListening()` (released code) wraps `Drops.IsListening()` (dev block), and both are called. `grep IsListening` finds two functions with one name and different jobs. One is "is listen mode on, if this build has it", the other "is listen mode on". The comment over the local has to explain which is which.
- The other channel and sharing checks on `Drops` are colon methods (`Drops:ChannelOn()`, `Drops:ChannelID()`, `Drops:ToggleListening()`). `Drops.IsListening` is a dot function, picked so it can be tested for nil. That works, but it reads as a slip next to its neighbours.
- In `MoveChannelLast`, `number` is the realm channel's number as it moves. Beside `fromNumber`, `laterNumber` and `laterNumbers`, a bare `number` is the one name that doesn't say whose number it is.

**Fix.** Name the dev block's hook for what it is, e.g. `Drops.devListenMode` (a function the dev block sets, nil in releases), and keep the local `IsListening` as the only `IsListening`. Rename `number` to `realmNumber`.

### R6 · `Core/Drops.lua` is at 199 of Lua 5.1's 200 locals in a dev build
- **Severity:** nit
- **Area:** WoW API (Lua 5.1 limits)
- **Where:** `NeedRoll/Core/Drops.lua` main chunk; added in this range: `IsListening` `:580`, `WantsChannel` `:584`, `ChatNumber` `:640`, `LISTEN_REPORT_WAIT` `:2478`, `PrintListenReport` `:2486`
- **Status:** fixed in round 1 (`0859468`): the two listen locals are one `Listen` table (`:2492`), so 198 of 200, and `READABLE-CODE.md` §5 names the limit. The dev block wasn't moved to its own file, so there is still little room. Worth doing the next time `Core/Drops.lua` grows.

**What's wrong.** Lua 5.1 refuses to load a function with more than 200 active locals ("too many local variables"). The main chunk of `Core/Drops.lua` holds 199 at its end in a dev build: 194 at `v1.2.0`, and this range adds 5. Packaged builds hold 167, since the `--@debug@` block holds 32. The Chat number comment knows the file is "close to" the limit (`:637-638`) and puts `ChatNumber`'s state in one table for that reason. The listen block still adds two plain locals.

**Why it matters.** The next PR that adds one file-level `local` to `Core/Drops.lua`, even a constant, breaks the dev build: the file doesn't load and drop sharing is gone in Mike's own client. The smoke dev run would fail at once, so it won't reach players, but it will stop whoever is working there.

**Evidence.** `luac5.1 -l -l` on the file, counting main-chunk locals live at each instruction: peak 199 at the end (`v1.2.0`: 194). The same on a copy with the `--@debug@` block cut out: 167.

**Fix.** Make room before it is needed. Put `LISTEN_REPORT_WAIT` and `PrintListenReport` on a `Listen` table in the dev block, as `ChatNumber` does. Better, move the dev block's 32 locals into a file of its own that `.pkgmeta` ignores, as `UI/DropTalk.lua` is. Also add the count to `docs/READABLE-CODE.md` §5's examples of game limits worth naming, next to the 60-upvalue one.

### R7 · No scenario for the 5-moves cap or a failed swap, and the cap's count leaks across scenarios
- **Severity:** nit
- **Area:** WoW API (smoke coverage for a new feature)
- **Where:** `NeedRoll/Core/Drops.lua:640-676` (`ChatNumber.MOVES_MAX`, `moves`, the `pcall` and "(a swap failed)"); `tests/smoke/modules/Core-Drops.lua:802-847`
- **Status:** fixed in round 1 (`0859468`). Scenarios "another addon moving its channel last wins after five moves" (`Core-Drops.lua:849`) and "a swap the game refuses stops the move where it got to" (`:875`). Both reset the count with `Drops.ForgetChatNumberMoves` (dev block, `Core/Drops.lua:2136`) before and after.

**What's wrong.** The two new chat number scenarios cover a move, a channel already last, and a channel joined later. Nothing covers the cap that stops two addons trading the last number forever (`MOVES_MAX = 5`), or a swap the game refuses (the `pcall` break and the "(a swap failed)" log line). `ChatNumber.moves` is file-local, never reset, and counts across the whole smoke run. The first scenario spends two of the five. A later scenario that expects a move after three more would fail for a reason no line of it shows.

**Fix.** Add one scenario: a stand-in "other addon" that moves its channel last on every `CHANNEL_UI_UPDATE` (swap back in `W.channelSwaps`' hook). The realm channel moves 5 times and then stays put. Add a second where `SwapChatChannelsByChannelIndex` errors on the second swap: the log says "(a swap failed)" and the channels stop where they were. Give the scenarios a way to reset `moves`: `Drops.ResetChatNumberMoves` in the dev block, or read `moves` before and compare.

### R8 · (round 2) A character still in NRDT from its last session isn't taken out while unanswered or Off: it stays in the channel, at /1 ahead of General
- **Severity:** should fix
- **Area:** Security (consent: in the channel before saying yes), WoW API (the chat number problem this release fixes comes back)
- **Where:** `NeedRoll/Core/Drops.lua:747-755` (`LeaveUnusedChannels`), `:757-759` (`JoinChannel`'s guard), `:18-21` (header comment: "not answered yet: no channel"), `:669` (`MoveChannelLast` needs `WantsChannel`)
- **Status:** fixed after round 2 (`71c8a3f`): `LeaveUnusedChannels` leaves NRDT whenever `not WantsChannel()`; `SetChannel(true)` moves it last at once. New scenario.

**What's wrong.** `LeaveUnusedChannels` leaves NRDT only while sharing is switched off for everyone:

```lua
if not Drops.isSharingEnabled and not IsListening() and Drops:ChannelID() then
    pcall(LeaveChannelByName, CHANNEL)
end
```

Before round 2's fix this didn't matter for unanswered accounts, because nil counted as on. Now nil is off, and nothing takes such a character out of a channel the game put it in. The game rejoins a character to last session's custom channels at login: the Chat number comment says so, and it is why NRDT came back as /1. The two places that leave NRDT are Settings' or the notice's Off (`SetChannel(false)`) and the everyone-off switch. `MoveChannelLast` also returns while `WantsChannel()` is false, so the channel isn't moved either.

**Why it matters.** Who it hits in this release: any character last played while sharing was on, before v1.1.0 (v1.1.0 and v1.2.0 left NRDT at each login, but only on the characters that logged in then). Round 2 turns that account's yes into nil. At login the game puts the character back in NRDT, often as /1, and it stays there, unanswered, for as long as the notice waits. Other players see the character in the channel's roster, and the player's General is /2. If they answer Keep sharing, `SetChannel(true)` → `JoinChannel` returns at once, since the character is already in the channel, so the 5-second move doesn't run either. The move then waits for the next `CHANNEL_UI_UPDATE`, loading screen or 10-minute tick. With Off, a character played on another day with NRDT from before stays in it (the Off part predates this range: dropChannel is account-wide, channel membership is per character). No addon message is sent in either case, so "nothing is shared" still holds for messages, but the header comment's "no channel" doesn't.

**Evidence.** Probe scenario (Checks, round 2), packaged. `W.channels = { NRDT = 1, General = 2, Trade = 3 }`, saved `dropChannel = true` from before rounds, then a login and 700 seconds: `dropChannel=nil NRDT=1 General=2`. After Turn off, the character rejoined at login again: `NRDT=1 General=2`. The two new Welcome scenarios start with `LeaveChannelByName("NRDT")` in `WithNoticeUnanswered`, so they can't see it. The game's rejoin is inferred from the Chat number comment and the v1.1.0 Switch comment ("left at login if the player is still in it"), not checked here.

**Fix.** Leave whenever NeedRoll doesn't want the channel, not only when everyone is switched off:

```lua
-- ...and the realm channel too while NeedRoll doesn't want it (sharing off
-- or not answered yet, and not listening): the game rejoins last session's
-- channels at login, and that would leave the player in it, often as /1.
if not WantsChannel() and Drops:ChannelID() then pcall(LeaveChannelByName, CHANNEL) end
```

`JoinChannel` already calls it before its guard, so the 15-second login call leaves the channel. A loading screen with sharing unanswered doesn't reach it (`KeepJoined` returns on `WantsChannel`), but the login call is enough, since the game only rejoins at login. Add a scenario: unanswered, and Off, with NRDT at /1 at login. After 20 seconds it's gone, and Keep sharing joins it fresh, last.

### R9 · (round 2) The notice still talks as if sharing were already on ("Keeping it on", "Keep sharing", "Turn off"), though nothing is shared until it is answered
- **Severity:** nit
- **Area:** Readability (player-facing text, §9)
- **Where:** `NeedRoll/UI/Welcome.lua:202` ("Keeping it on helps..."), `:216` (`L["Keep sharing"]`), `:213` (`L["Turn off"]`)
- **Status:** fixed after round 2 (`71c8a3f`), Mike chose to reword: "Turning it on helps…", buttons "Share drops" / "Don't share".

**What's wrong.** Since round 2's fix nothing is shared before the answer, yet the notice reads as if it already is. The second paragraph starts "Keeping it on helps map out WoW: Forever", and the buttons are Keep sharing and Turn off. A player who reads it on a new account is told sharing is on, and that they can keep it or stop it. In fact it's off until they press Keep sharing.

**Why it matters.** The error points the safe way (a player thinks something runs that doesn't), so nothing leaks. But the notice now says "fully opt-in" and "keep it on" in the same breath. It is also why a player who leaves it open might think they're already helping.

**Fix.** "Turning it on helps map out WoW: Forever, ... Leaving it off stops the drop, quest and trainer messages, ..." and the buttons "Share drops" / "Don't share" (both exist as phrases or near ones). Three keys to retranslate. If Mike prefers the old words, leave it.

### R10 · (round 2) Share drops turned On in Settings counts as a yes, but the notice still asks again at the next login
- **Severity:** nit
- **Area:** Readability (one answer, two places that keep it)
- **Where:** `NeedRoll/UI/Settings.lua:88` (`pick` → `SetChannel`); `NeedRoll/Core/Drops.lua:809-817` (`SetChannel`); `NeedRoll/UI/Welcome.lua:239-240` (`ShowDropNotice` reads only `shownDroptalkConsent`)
- **Status:** fixed after round 2 (`71c8a3f`): one `Welcome:AnswerDropSharing` saves every answer (notice buttons and Settings) and sets `shownDroptalkConsent`. New scenario.

**What's wrong.** The new comments call Settings' Share drops On a yes for this round (`Core/Drops.lua:567-572`, `Core/Init.lua:84-88`, `UI/Welcome.lua:129-131`), and `ChannelOn` treats it as one. But `shownDroptalkConsent` stays false, so the notice shows again at every login until it is answered there too. Turn off on that later notice then undoes the Settings choice. Settings' Off before answering is the same.

**Why it matters.** A player who found Share drops in Settings and turned it on (it reads Off for an unanswered account, so that is a natural thing to do) is asked again on the next login, as if NeedRoll forgot. Small, but it is the one way of answering the comments describe that doesn't close the question.

**Fix.** Let any answer close the round: in `Drops:SetChannel`, or in Settings' `pick`, also set `ns.db.shownDroptalkConsent = true` (and hide the notice if it is up). Or say in the comments that only the notice closes the round.

### R11 · (round 2) No scenario checks that a Keep sharing given in round 2 is still on after the next login
- **Severity:** nit
- **Area:** WoW API (smoke coverage)
- **Where:** `tests/smoke/modules/UI-Welcome.lua:296-302`
- **Status:** fixed after round 2 (`71c8a3f`): assert added after the re-login.

**What's wrong.** The scenario "an answer from before this round of asking is asked once more" presses Keep sharing, logs in again and checks that the notice stays hidden and the round is unchanged. It doesn't check `dropChannel == true` and `ChannelOn()` after that login. The code is right (`StartDropNoticeRound` returns at once when the saved round is current, `UI/Welcome.lua:327`), but nothing would catch a later change that resets a yes on every login. Since round 2's fix, that bug would silently turn sharing off for everyone.

**Fix.** After the second `PLAYER_LOGIN` there, add `assert(ns.db.dropChannel == true and ns.Drops:ChannelOn(), "a Keep sharing from this round didn't last the next login")`.

## Area notes

### Readability

Checked against every rule in `docs/READABLE-CODE.md`:
- **Formatting:** 4-space indents, LF, ASCII, `local` everywhere, no new line over 120 besides the two reworded `L[...]` keys.
- **Names and constants:** the new constants carry their unit (`CHECK_WAIT -- seconds`, `LISTEN_REPORT_WAIT = 6 -- seconds after joining`, `DROP_NOTICE_ROUND`). `isCheckWaiting` reads as a question. The exceptions are R5.
- **Functions** are short and do one thing: `NumbersAfter`, `MoveChannelLast`, `WantsChannel`, `PrintListenReport`, `ToggleListening`. Guards come first. Nothing nests past two levels. `JoinChannel`'s timer turned its guard into an `if Drops.Log then ... end` block so the move can follow. That is the right shape, since the move must run in release builds where `Drops.Log` is nil.
- **Comments** explain the game facts: the game rejoining custom channels ahead of General, why `ChatTypeInfo` is left alone (taint), why the cap exists, why `ChatNumber` is a table (Lua's local limit). The Switch comment's history ("off from v1.1.0 ... on again since they deliver them (Mike, 2026-11-08)") is the file's usual dated note, not change narration. Wrong or incomplete: R3 (Switch comment), R4 (move up one).
- **Lua 5.1 traps:** `number ~= laterNumbers[#laterNumbers] and " (a swap failed)" or ""` has a truthy middle. `#` is used only on arrays built with `numbers[#numbers + 1]`, and `{ GetChannelList() }` has no nils (number, name, boolean triples). No pattern is built from data. `tonumber(ns.db.dropNoticeRound) or 0` is safe on any saved value.
- **Welcome round:** `WithNoticeUnanswered` now restores `dropNoticeRound`, so the other Welcome scenarios don't leak a round into each other.

Round 2 re-read:
- The fixes follow the rules: `ChannelOn`'s comment says what each saved value means, `SendNext`'s new guard says why it waits, `StartDropNoticeRound` is now a guard clause and one job. The new smoke helpers have names that say what they count (`SharingSentSince`, `WithMessageWaiting`, `IsWaiting`).
- `SharingSentSince` exists in both `UI-Welcome.lua:60-66` and (by the same name, a different shape) `Core-Drops.lua`. Smoke helpers stay file-local in this suite, so not a finding.
- New: R9, R10.

### WoW API

| Call, event, method | In `forever` lists | Where looked |
| --- | --- | --- |
| `C_ChatInfo.SwapChatChannelsByChannelIndex` (new) | yes | GlobalAPI.lua:832. Blizzard's `forever` `ChatInfoDocumentation.lua:579-588`: no `HasRestrictions` (so no combat block), `SecretArguments = "AllowedWhenUntainted"`. NeedRoll's arguments are plain numbers from `GetChannelName`/`GetChannelList`. |
| `CHANNEL_UI_UPDATE` (new) | yes | Events.lua:297 |
| `GetChannelList`, `GetChannelName` | yes | GlobalAPI.lua:5337, :5338 (both already used) |
| `JoinTemporaryChannel`, `LeaveChannelByName` (newly called from `/nr droptalk listen`, dev) | yes | GlobalAPI.lua:6193, :6203 |
| `SetSelectedDisplayChannel` (via `PrintChannelMembers`, now also from the listen report, dev) | yes | GlobalAPI.lua:6508 |
| `C_Timer.After`, `C_Timer.NewTicker` | yes | GlobalAPI.lua:4174, :4175 |
| `CHAT_MSG_ADDON` | yes | Events.lua:301 |
| `ChatTypeInfo` (deliberately not written) | inferred | A global FrameXML table, not in the lists. Blizzard's `ChatConfigChannelSettings_SwapChannelsByIndex` (`forever` `ChatConfigFrame.lua:2270-2279`) swaps its two entries before calling the swap, as the comment says. |

Also checked:
- **Combat:** the swap has no restriction in Blizzard's own `forever` docs, so it needs no `W.BlockIfInCombat` and no `CHECKED_COMBAT_CALLS` entry. Neither changed. The `--combat` run passes, the move scenarios included. No secure frame, map call or one of the four blocked `SetPropagate*`/`SetPassThroughButtons` calls was added (diff grepped).
- **Taint:** NeedRoll leaves `ChatTypeInfo` alone and only calls the C function, so no Blizzard table or frame gets tainted. The `CHANNEL_UI_UPDATE` that follows is handled by Blizzard's own frames in their own clean call.
- **Is the swap applied at once?** Inferred yes. Blizzard's settings call `ChatConfigChannelSettings_UpdateCheckboxes()`, which re-reads `GetChannelList()`, straight after the swap (`ChatConfigFrame.lua:2277-2278`). They wouldn't if the list changed only later. So the chain of swaps and the re-check 2 seconds after `CHANNEL_UI_UPDATE` don't double-move. Not checked in game.
- **Channel colours:** not swapping `ChatTypeInfo` is the better choice for the case the feature exists for. The game's rejoin put NRDT on /1 and General on /2, which already gave General /2's colour. Moving NRDT last gives General back /1 and its colour. Only a channel that NRDT passes later (one joined after it) takes NRDT's old number's colour, as the comment warns. Swapping colours as Blizzard does would break the main case, so the comment's choice stands.
- **Reload and logout:** `ChatNumber.moves` and `isCheckWaiting` reset with each `/reload` (a "session" in the comment's sense). Nothing is saved, so logout leaves nothing behind. Whether the game keeps the moved order for the next login wasn't checked in game. If it doesn't, each login moves again, within the cap.
- **Not checked in game:** whether moving channels prints "Changed Channel" lines for General and Trade in the chat windows. NeedRoll's chat filter hides only NRDT's lines (`IsHiddenChatLine`). Worth a look the first time Mike logs in on v1.3.0.
- **Event handlers:** `CHANNEL_UI_UPDATE` is used, debounced, and ignored until the first join (`keepJoined`). No one-shot event was added.
- **Secret values:** none touched. `IsOurChannel` already runs names through `ns.Plain`. Channel numbers are compared directly, as `IsChannelDisabled` already does. Not marked secret in the docs (inferred).
- **Other:** no new globals. Both reworded phrases are literal `L[...]` keys, and `locales.py --check` passes. The new game call is mirrored in `tests/smoke/wow.lua:2013-2026`, and the stand-in defines nothing Forever lacks. No nil guard removed. The listen code is inside `--@debug@` (`Core/Drops.lua:2110-2860`; `Core/Init.lua:738-823` for the command). The released `IsListening` reads `Drops.IsListening ~= nil` first, so released builds never listen. `docs/STYLE-GUIDE.md`'s Hidden settings row was updated with the switch.

Round 2: no new game call. R1's fix reads `CHAT_MSG_ADDON`'s third argument, the chat type, which `Core/Drops.lua`'s own handler already reads as `channel` and compares with `"CHANNEL"`. The new scenarios use only existing stand-ins. The `--combat` run passes. New: R8 (WoW API side: the chat number problem returns for a character the game rejoins), R11.

### Redundant code

Compared against what the file already has:
- `IsChannelDisabled` and `ChannelListIndex` both walk `GetChannelList()`'s triples, and so does `NumbersAfter`. They read different fields for different answers, so one walk each is fine.
- `JoinChannel`, `KeepJoined`, `LeaveUnusedChannels` are reused by listen mode, not copied. `WantsChannel` replaces `ChannelOn` only where the question is "should NeedRoll be in the channel", and every send path still asks `ChannelOn` or the switch.
- `RefusesWhileSwitchedOff`, `WhenJoined`, `PrintChannelMembers`, `Drops.Log`: reused.
- `MoveChannelLast` is called from five places: login, after a join, `KeepJoined`, `CHANNEL_UI_UPDATE`, and through `KeepJoined` on loading screens. `CHANNEL_UI_UPDATE` would cover most of them if Forever fires it on every rejoin, but that isn't checked in game, the call is cheap, and it returns at once when NRDT is already last. Not a finding.

Findings: R3 (two ways to re-ask). R6 is about room, not repetition.

Round 2: R3's fix leaves one way to re-ask. `SendNext`'s nil wait and `Queue`'s `ChannelOn` guard are two checks for one state, but at different steps (one holds what is already queued, one adds nothing new), so both are needed.

### Security

Untrusted inputs and outputs this range touches:
- **The realm channel comes back for everyone.** Drop, quest, trainer, probe and roll call messages heard there go through the existing checks in `Core/Drops.lua`, which this range doesn't change. The version check doesn't check where a message came from (R1).
- **Listen mode really sends nothing.** Every send path asks the switch or `ChannelOn`, and listening changes neither: `Queue` (`:1016`), `SendNext` (`:951`, `:954`), probe answers (`:1948`), roll call answers (`:1987`), the dev commands (`RefusesWhileSwitchedOff`, `WhenJoined`). `CHAT_MSG_ADDON` returns for every realm channel message while listening, before any parsing that could answer. Version messages can't leave a dev build: `Version:Mine()` is nil for a checkout. The smoke scenario checks that no message is sent or queued through a login and a `/reload` with listen on. What listening logs is capped by `LOG_MAX` (2000), and the drop talk window shows message text through `ns.Literal`.
- **Throttling.** No new sender. The drop outbox still sends one message a minute (`SEND_GAP`) and `DAILY_MAX` a day. An outbox left from before v1.1.0 resumes at that pace. The chat number swaps are not addon messages. The version check sends outside the outbox (R1, R2).
- **Consent:** R2. Round 2: fixed for messages. No account sends anything this round without Keep sharing or Settings' On: the only writers of `dropChannel = true` are `SetChannel(true)` from those two, and every send path (`Queue`, `SendNext`, probe and roll call answers) needs `ChannelOn`. The dev-only `/nr users` and ping/probe are commands Mike types himself. Channel membership isn't covered (R8).
- **Privacy:** the watcher imports add 2 names to `scraper/drops/credits.json` and change counts for others; that file stays in the private repo. No credited name appears anywhere else in the diff or under `NeedRoll/`, `docs/`, `tests/`, `.github/` (Checks). `.pkgmeta` still keeps `scraper`, `tools`, `tests`, `UI/DropTalk.lua` and `NeedRoll/Credits.txt` out of the zip. This doc names no player.
- **Scraper:** no code changed, so no new Wowhead request, secret or workflow. `scraper/compare/page.html` only changes its embedded data line; its `esc` helper is unchanged.

## Round history

- Round 1, 2026-11-08, `473a4bc`: **Changes needed** (0 blocking, 2 should fix, 5 nits). Opened R1-R7.
- Round 2, 2026-11-08, `e939f1b` (fixes `0859468`): **Changes needed** (0 blocking, 1 should fix open, 3 nits open). Closed R1-R7. Opened R8 (should fix), R9-R11 (nits). Last round: Mike decides what's left.

## After round 2

Mike chose "Fix all four" (2026-11-08 19:53Z). R8-R11 fixed in `71c8a3f` by the implementer, with no third review round (`CLAUDE.md`: at most two). Checks on `71c8a3f`: `luac5.1 -p`, `luacheck` (same counts as dev), `tools/locales.py --check`, `tools/translations.py`, `tests/smoke/check.sh` all four runs (2388 ok lines). Each new scenario fails with its fix undone. Phrases changed: "Keeping it on helps…" → "Turning it on helps…", "Keep sharing" → "Share drops" (existing key), "Turn off" → "Don't share" (new).
