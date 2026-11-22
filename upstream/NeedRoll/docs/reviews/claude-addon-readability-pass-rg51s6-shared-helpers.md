# Review: Readability pass, shared helpers group (helpers moved into Theme, Core/Init, Items, Names, Data and DevKit; `tests/smoke/wow.lua` cleaned up)

| | |
| --- | --- |
| Branch | `shared-helpers` worktree (the last group of `claude/addon-readability-pass-rg51s6`), into the dev state after the Overview group merged (`a983bb6`). PR not opened yet |
| Commit reviewed | `a87d439` (round 3: `7ade5da..a87d439`; round 2 `5023a0b`, round 1 `08a3278`), no uncommitted changes |
| Date | 2026-10-18 |
| Round | 3 (last) |
| Verdict | **Ready**, with one nit for Mike to decide (0 blocking, 0 should fix, 1 nit open: R11; R1-R10 fixed) |
| Needs | `/reload` (Lua only: no file added to or removed from the `.toc` or `UI/UI.xml`, no SavedVariables key or format change) |

## What the change does

Nothing a player sees, clicks, saves or sends should change, and none of it does as far as
this review could find (see "Behaviour checks" under Area notes). Helpers that two or more
files each kept their own copy of now live in one place:

- `UI/Theme.lua`: the tooltip colours `T.tip`, a `popup` palette colour, `T:JoinDots`,
  `T:Plural`, `T.iconCrop`/`T:CropIcon`, `T.roundMask`/`T:MaskRound`, `T:ConfirmPill` (the
  ask-once "Clear list" pill), `T:CheckBox`, `T:QualityIcon`, `T:ShowItem` and
  `T:ScrollColumn` (from the Shopping List and Wishlist copies).
- `Core/Init.lua`: `ns.ParseGUID`, `ns.CharacterKey`, `ns.PlayerFaction`, the `CHAT_NAME`
  constant.
- `Core/Items.lua`: `ns.Items:IDFromLink`, `ns.Items:ModifiedClick`.
- `Core/Names.lua`: `Names:CreatureName` (from MapEdit).
- `Data/Data.lua`: `ns.Data:IsBoss`, `ns.Data:PlaceName`.
- `UI/DevKit.lua`: `GameWindow` (from MapEdit and LineDump).

Inline `function() GameTooltip:Hide() end` closures became the FrameXML `GameTooltip_Hide`,
inline `issecretvalue` checks became `ns.Plain`, and `ns.UI.ClassName` gained the
"PALADIN" → "Paladin" fallback Overview's copy had.

`tests/smoke/wow.lua` drops 27 old globals Forever lacks, gains the stand-ins individual
module files had been adding for themselves (`ITEM_CLASSES_ALLOWED`,
`Enum.ItemWeaponSubclass`, `Enum.ItemMiscellaneousSubclass`,
`C_TransmogCollection.GetAppearanceInfoBySource`, `C_Map.GetAreaInfo`,
`GetLootRollItemInfo`, `ChatFrameUtil.InsertLink`/`RemoveMessageEventFilter`), makes
`SetScript` drop earlier hooks as the game does, and adds shared `W.Printed`,
`W.Hover`/`W.Unhover` and `W.SetSkillLines`. The style guide and both agent files are
updated.

## Scope

Line counts (corrected in round 2, unchanged at `a87d439`): from `08a3278^` to `5023a0b`, `NeedRoll/` is down 155
lines net (663 added, 818 removed) and `UI/Theme.lua` is up 266 net (+276/−10). Round 1
measured `08a3278` alone: −173 overall, Theme +257. The implementer's first figures (−189,
Theme +195) were wrong; the PR text should use −155 and +266.

- `NeedRoll/UI/Theme.lua`: the new shared builders and colours above. Read every new
  function in full, plus `T:Pill`, `T:Rounded`, `T:SetTextColor`, `T:Row`, `T:Dialog`,
  `T:ScrollStart`/`WheelScroll`/`ScrollBar` for context.
- `NeedRoll/UI/Wishlist.lua`: drops `HINT_COLOR`, `JoinDots`, `CreateIcon`, `SetItem`,
  `CreateColumn`, `CreateCheck`, `CreateClearButton`; uses the Theme versions.
- `NeedRoll/UI/Shopping.lua`: drops `TIP_LABEL`, `CreateIcon`, `SetItem`, `ModifiedClick`,
  the column body, `CreateClearButton`, the check box body and `Plural`; `CreateColumn`
  and `CreateCheck` are now thin wrappers over `T:ScrollColumn` and `T:CheckBox`.
- `NeedRoll/UI/LootGrid.lua`: drops the `TIP_*` colours, `ICON_CROP`, `JoinDots`,
  `PlaceName`, `ROUND_MASK`, `Cell:SetBorderColor` and the cell's icon build; uses
  `T:QualityIcon`, `T:CropIcon`, `T:MaskRound`, `ns.Plain`, `ns.CharacterKey`;
  `ns.UI.ClassName` fallback.
- `NeedRoll/UI/Overview.lua`: `CIRCLE_MASK` → `T.roundMask`/`T:MaskRound`, `ns.Plain`,
  `ns.UI.ClassName`, `ns.PlayerFaction`.
- `NeedRoll/UI/Lists.lua`, `MainFrame.lua`, `MapEdit.lua`, `Search.lua`, `Settings.lua`,
  `Welcome.lua`, `MinimapButton.lua`, `RecipeBand.lua`, `DropTalk.lua`, `Fished.lua`,
  `FrameDebug.lua`, `LineDump.lua`: call sites moved to the shared helpers.
- `NeedRoll/UI/DevKit.lua`: `GameWindow`.
- `NeedRoll/Core/Init.lua`, `Items.lua`, `Names.lua`, `Data/Data.lua`: the new shared
  helpers.
- `NeedRoll/Core/Drops.lua`, `LootLog.lua`, `Shopping.lua`, `Tooltip.lua`, `NeedRoll/API.lua`:
  call sites moved to `ns.Plain`, `ns.ParseGUID`, `ns.Items:IDFromLink`, `ns.CharacterKey`,
  `ns.PlayerFaction`, `T.tip`.
- `tests/smoke/wow.lua`, `tests/smoke/README.md`, `tests/smoke/scenarios.lua`,
  `tests/smoke/modules/*` (8 files): stand-in cleanup and shared test helpers; one new
  scenario ("Core/Init: the shared GUID, character key and side helpers").
- `docs/STYLE-GUIDE.md`, `.claude/agents/implementer.md`, `.claude/agents/reviewer.md`.

No generated data under `NeedRoll/Data/` is touched (`Data/Data.lua` is hand-written).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 49 changed Lua files | passed |
| `python3 tools/locales.py --check` | passed (`enUS.lua` not in the diff, so key order is unchanged) |
| `python3 tools/translations.py` | ran, exit 0; 50 lines "not used by NeedRoll any more" (5 keys × 10 locales: `Thom Filch`, `Search loot, bosses, dungeons`, `Level`, `Press a key`, `Quest chain`). None of these keys is in this diff: pre-existing |
| `luacheck --no-global -q`, changed files vs `08a3278^` | 12 new warnings, all on `self`: 4 × `unused argument 'self'` (`ns.Items:IDFromLink`, `ns.Items:ModifiedClick`, `Names:CreatureName`, `ns.Data:IsBoss`), 2 × the same on `T:JoinDots`/`T:Plural`, 6 × `shadowing upvalue argument 'self'` (`function box:Set/IsOn` inside `T:CheckBox`, `function column:Refresh/SetData` inside `T:ScrollColumn`). Accepted, see Area notes. No new unused locals, no warnings in test files (counts identical) |
| `tests/smoke/check.sh` | passed: dev, packaged and secret runs all "all passed" (929 `ok` lines) |
| Scraper unit tests | not run: no scraper change |
| `CreateOverview` upvalues (`luac5.1 -l`) | 36 before, 36 after. Largest in any changed file: 50 (`Lists.lua`, `LootGrid.lua`), unchanged from base |
| Round 2: `luac5.1 -p` on the 21 Lua files changed in `a5077f8..5023a0b` | passed |
| Round 2: `locales.py --check` / `translations.py` | passed / exit 0, the same 50 pre-existing lines |
| Round 2: `luacheck --no-global -q` vs `a5077f8` | one warning fewer (`unused argument 'self'` in Theme: `T:JoinDots` now reads `self.DOTS`); nothing new |
| Round 2: `tests/smoke/check.sh` | passed: all three runs "all passed", 932 `ok` lines (929 + the new ClassName scenario × 3 runs) |
| Round 2: `CreateOverview` upvalues | 36 (unchanged); largest in any addon file still 50 |
| Round 3: `luac5.1 -p`, `locales.py --check`, `translations.py` | passed, passed, exit 0 (same 50 pre-existing lines) |
| Round 3: `luacheck --no-global -q` vs `7ade5da` | no change |
| Round 3: `tests/smoke/check.sh` | passed: 932 `ok` lines, all three runs "all passed" |
| Round 3: `CreateOverview` upvalues | 36 (unchanged) |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Readability | `UI/MainFrame.lua:295`, `UI/Overview.lua:98` | Tooltips are now hidden three ways | fixed in round 2 (`5023a0b`) |
| R2 | should fix | Readability | `Core/Drops.lua:93,1121`, `Core/LootLog.lua:47`, `Core/Init.lua:243` | Three `ParseGUID`s with three different results | fixed in round 2 (`5023a0b`) |
| R3 | should fix | Redundant code | `UI/MainFrame.lua:241-256`, `UI/Overview.lua:2756,3111`, `Core/LootLog.lua:586`, `UI/Fished.lua:27`, `UI/Search.lua:224` | `T:JoinDots` exists, but the dot join is still hand-written beside it | fixed in round 2 (`5023a0b`); remaining literals are R10 |
| R4 | nit | Readability | `UI/Theme.lua:165-175`, `docs/STYLE-GUIDE.md` | `T.tip.label` is used for far more than labels; `note` and "notes" disagree | fixed in rounds 2 and 3 (`5023a0b`, `a87d439`) |
| R5 | nit | Readability | `UI/Theme.lua:1368`, `Core/Items.lua:36` | `T:ShowItem` shares its name with `NeedRoll_ShowItem`; `ModifiedClick` isn't a verb | fixed in round 2 (`5023a0b`) |
| R6 | nit | Readability | `UI/Shopping.lua:329` | A bare `true` picks the label side | fixed in round 2 (`5023a0b`) |
| R7 | nit | WoW API | `tests/smoke/wow.lua:1091,1278` | `wow.lua` still defines `GetMinimapShape` and `REAGENTBANK_CONTAINER` | fixed in round 2 (`5023a0b`) |
| R8 | nit | WoW API | `UI/LootGrid.lua:1656-1659` | The new `ClassName` fallback has no scenario | fixed in round 2 (`5023a0b`) |
| R9 | nit | Readability | `UI/Theme.lua:1-2` | Theme's header no longer says what the file holds | fixed in round 2 (`5023a0b`) |
| R10 | should fix | Readability | `UI/MainFrame.lua:1915-1920`, `UI/LootGrid.lua:61,1422,2787`, `UI/Overview.lua:501`, `UI/RecipeBand.lua:818`, `Core/Wishlist.lua:557` | `T.DOTS` names the separator, but 9 literal copies of it remain | fixed in round 3 (`a87d439`) |
| R11 | nit | Readability | `UI/Lists.lua:829,1774`, `UI/Overview.lua:1405,1429,2902,3034,3159` | The separator is still written into 7 shipped format strings | open: for Mike to decide |

### R1 · Tooltips are now hidden three ways

- **Severity:** should fix
- **Area:** Readability (consistency)
- **Where:** `NeedRoll/UI/MainFrame.lua:295` (used at 338, 457, 507, 546, 1022),
  `NeedRoll/UI/Overview.lua:98` (18 references)
- **Status:** fixed in round 2 (`5023a0b`)

**What's wrong.** The change replaces every inline `function() GameTooltip:Hide() end` with the
game's `GameTooltip_Hide` (LootGrid, Wishlist, Shopping, Settings, MapEdit, MinimapButton).
Two files keep their own copy of exactly that function:

```lua
-- MainFrame.lua:295
local function HideTooltip() GameTooltip:Hide() end
-- Overview.lua:98
local function HideTooltip()
    GameTooltip:Hide()
end
```

So after this change the addon hides a tooltip with `GameTooltip_Hide`, with
`MainFrame`'s `HideTooltip`, and with Overview's `HideTooltip`.

**Why it matters.** `docs/READABLE-CODE.md` §6: "Do the same thing the same way everywhere …
Two copies of a helper become one." This group exists to remove such copies, and it is the
last one; a reader who sees `HideTooltip` in two files will look for what makes them differ
from `GameTooltip_Hide` (nothing does).

**Evidence.** `grep -rn "HideTooltip\|GameTooltip_Hide" NeedRoll` (counts per file:
LootGrid 7, MainFrame 6, Overview 18, Wishlist 3, Shopping 2, Settings 2, MapEdit 2,
MinimapButton 1). `GameTooltip_Hide` is in Ketho's `forever` `FrameXML.lua:1873`.

**Fix.** Delete both locals and pass `GameTooltip_Hide` at their call sites. In Overview this
also takes one upvalue off every function that used `HideTooltip`.

### R2 · Three `ParseGUID`s with three different results

- **Severity:** should fix
- **Area:** Readability (disinformation, avoid mental mapping)
- **Where:** `NeedRoll/Core/Init.lua:243` (`ns.ParseGUID`), `NeedRoll/Core/Drops.lua:93`
  (local, used at 741, 755, 856, 883, 1073) and `Drops.lua:1121` (calls `ns.ParseGUID`),
  `NeedRoll/Core/LootLog.lua:47` (local, used at 130)
- **Status:** fixed in round 2 (`5023a0b`)

**What's wrong.** Before this change each file's `ParseGUID` was the only one. Now there are
three functions of that name, each returning something different:

```lua
ns.ParseGUID(guid)        --> unitType, id, "<zoneUID>-<spawnUID>"   (Init.lua)
ParseGUID(guid)           --> npcID, kill  (creatures and vehicles only)  (Drops.lua:93)
ParseGUID(guid)           --> "npc"|"object"|"item", id               (LootLog.lua:47)
```

and Drops.lua uses both its own and the shared one:

```lua
-- Drops.lua:755
local npcID, kill = ParseGUID(guid)
-- Drops.lua:1121
local unitType, id = ns.ParseGUID(guid)
```

**Why it matters.** A reader in Drops.lua who has just read `ns.ParseGUID` in Init.lua will
take `local npcID, kill = ParseGUID(guid)` as a misuse (the first value of `ns.ParseGUID` is
the unit type) or, worse, copy the local's call shape onto `ns.ParseGUID` and get
`"Creature"` where an NPC ID belongs, which would be written into drop records. READABLE-CODE
§9: a name must not say something the code doesn't do.

**Evidence.** Lines read above; `grep -n "ParseGUID(" NeedRoll/Core/Drops.lua NeedRoll/Core/LootLog.lua`.

**Fix.** Rename the two wrappers after what they return, e.g. Drops'
`local function CreatureAndKill(guid)` and LootLog's `local function LootSourceOf(guid)`;
keep `ns.ParseGUID` as the one parser.

### R3 · `T:JoinDots` exists, but the dot join is still hand-written beside it

- **Severity:** should fix
- **Area:** Redundant code (consistency, searchable names)
- **Where:** `NeedRoll/UI/MainFrame.lua:241-256` (`RecipeSubtitle`),
  `NeedRoll/UI/Overview.lua:2756` and `3111`, `NeedRoll/Core/LootLog.lua:586`,
  `NeedRoll/UI/Fished.lua:27`, `NeedRoll/UI/Search.lua:224`; the separator `"  ·  "` appears
  as a literal about 25 times across `NeedRoll/`
- **Status:** fixed in round 2 (`5023a0b`) for every site listed below; the separator literals left elsewhere are R10

**What's wrong.** The change makes `T:JoinDots(...)` the shared way to join parts with the
dot separator and moves Wishlist and LootGrid to it. Other code that does the same job,
including files this change touches, still builds the list and joins it by hand:

```lua
-- MainFrame.lua:241-256, RecipeSubtitle
local parts = { inst.name }
...
if enc.learned then table.insert(parts, enc.learned) end
return table.concat(parts, "  ·  ")
-- Overview.lua:2756
return #parts > 0 and table.concat(parts, "  ·  ") or L["No level requirement"]
-- Fished.lua:27 (a copy of LootGrid's SlotText join)
if subType and slot and subType ~= slot then return subType .. "  ·  " .. slot end
```

The separator itself has no name, so "where do we draw the dot?" can't be grepped.

**Why it matters.** READABLE-CODE §6 and §7. The next change to the separator (spacing, a
different glyph for a locale) has to find ~25 literals, and the hand joins don't drop empty
parts the way `T:JoinDots` does, so a blank `enc.learned` or note gives a dangling dot on a
recipe subtitle where the loot grid would show none.

**Evidence.** `grep -rn '"  ·  "\|  ·  %s' NeedRoll --include=*.lua` (output in the review
session); `T:JoinDots` at `UI/Theme.lua:344-351`.

**Fix.** Name the separator once (`T.DOTS = "  ·  "`, used by `T:JoinDots` and `T:WithIds`)
and use `T:JoinDots` where the job is the same: `RecipeSubtitle`
(`return T:JoinDots(unpack(parts))` or build the call directly), Overview 2756/3111,
LootLog 586 (Core may call `ns.Theme` at run time, as `Core/Init.lua:438` and
`Core/Tooltip.lua:122` already do), Fished 27, Search 224. Leave the ones inside `L["..."]`
keys (`L["%s  ·  %s to buy"]`): changing a key breaks its translations.

### R4 · `T.tip.label` is used for far more than labels; `note` and "notes" disagree

- **Severity:** nit
- **Area:** Readability (disinformation)
- **Where:** `NeedRoll/UI/Theme.lua:165-175`; uses at `Core/Tooltip.lua:122-124,204`,
  `UI/MainFrame.lua:454,504`, `UI/Settings.lua:110-112`, `UI/Shopping.lua:88`,
  `UI/Wishlist.lua:645`; `docs/STYLE-GUIDE.md` "Tooltip colors"
- **Status:** fixed: renames and comment in round 2 (`5023a0b`), the last 5 white literals in round 3 (`a87d439`)

**What's wrong.** The comment calls `label` "labels beside a value", but it now colours the
boss and dungeon names in every item tooltip (`Core/Tooltip.lua`, where it was `TEXT`, "the
addon's text color"), the Back button's history entries, "On your list: %d", "Made with …",
"Chance at least one of these drops in a clear", and Settings' `AddTooltipNote` ("Light blue
tooltip lines: what else a choice affects"). Meanwhile `T.tip.note` is the 0.6 grey, so in
Settings a "note" is drawn with `label` and not with `note`. The style guide repeats the mix:
"labels beside a value and notes 0.76, 0.93, 1 … quiet notes 0.6 grey".
Also, `T.tip.text` (white) is used at 11 sites while 25 tooltip lines still pass a literal
`1, 1, 1`.

**Why it matters.** Someone adding a tooltip line picks a colour by its name; "label" and
"note" point them at the wrong one. READABLE-CODE §9. The colours themselves are right (see
Area notes).

**Fix.** Rename `label` for what it is, e.g. `T.tip.info` ("pale blue: places, labels and
side notes"), or keep the key and fix the comment and style guide to list what it colours;
call the grey one `quiet`. Either use `T.tip.text` for the white lines or drop it and keep
`1, 1, 1` everywhere; one way.

### R5 · `T:ShowItem` shares its name with `NeedRoll_ShowItem`; `ModifiedClick` isn't a verb

- **Severity:** nit
- **Area:** Readability (meaningful, searchable names)
- **Where:** `NeedRoll/UI/Theme.lua:1368`, `NeedRoll/API.lua:219`, `NeedRoll/Core/Items.lua:36`
- **Status:** fixed in round 2 (`5023a0b`): `T:SetRowItem`, `ns.Items:HandleModifiedClick`

**What's wrong.** `NeedRoll_ShowItem(item)` is the public API that opens an item's source
page; `T:ShowItem(row, itemID, redraw)` fills a list row's icon, name and border. A grep for
`ShowItem` lands on both. `ns.Items:ModifiedClick(itemID, fallbackLink)` names an event, not
what the function does (READABLE-CODE §1: functions are verbs).

**Fix.** e.g. `T:SetRowItem(row, itemID, redraw)` and `ns.Items:HandleModifiedClick(...)`
(mirroring the game's `HandleModifiedItemClick` it wraps).

### R6 · A bare `true` picks the label side

- **Severity:** nit
- **Area:** Readability (avoid mental mapping)
- **Where:** `NeedRoll/UI/Shopping.lua:329`
- **Status:** fixed in round 2 (`5023a0b`): `T:CheckBox(pane, label, set, "LEFT")`, parameter `labelSide`

**What's wrong.** `local box = T:CheckBox(pane, label, set, true)`: the reader has to open
Theme to learn that `true` means "label at the left".

**Fix.** `T:CheckBox(pane, label, set, true) -- label at the box's left`, or a named
constant/flag such as `local LABEL_LEFT = true`.

### R7 · `wow.lua` still defines `GetMinimapShape` and `REAGENTBANK_CONTAINER`

- **Severity:** nit
- **Area:** WoW API (smoke stand-in fidelity)
- **Where:** `tests/smoke/wow.lua:1278` (`function GetMinimapShape() return "ROUND" end`),
  `tests/smoke/wow.lua:1091` (`REAGENTBANK_CONTAINER = -3`)
- **Status:** fixed in round 2 (`5023a0b`)

**What's wrong.** The change's own new rule (`tests/smoke/README.md`, `reviewer.md`,
`implementer.md`): `wow.lua` defines nothing the game lacks, so a dropped guard fails in smoke
as it would in game. `GetMinimapShape` is not a game function (it isn't in Ketho's `forever`
`GlobalAPI.lua` or `FrameXML.lua`); minimap addons define it, and `UI/MinimapButton.lua:46`
guards it (`GetMinimapShape and GetMinimapShape() or "ROUND"`). With it defined, smoke never
runs the path a player without a minimap addon runs. `REAGENTBANK_CONTAINER` is used nowhere
in `NeedRoll/` (grep), so it is a dead stand-in.

**Fix.** Remove both; a scenario about square minimaps defines `GetMinimapShape` itself and
removes it after, as `W.SetSkillLines` does.

### R8 · The new `ClassName` fallback has no scenario

- **Severity:** nit
- **Area:** WoW API (smoke coverage)
- **Where:** `NeedRoll/UI/LootGrid.lua:1656-1659`
- **Status:** fixed in round 2 (`5023a0b`)

**What's wrong.** `ns.UI.ClassName` used to return the bare token ("PALADIN") when
`LOCALIZED_CLASS_NAMES_MALE` was missing; it now returns "Paladin", taken from Overview's copy.
In game the table exists (a FrameXML global; not in Ketho's lists, accepted by inference
because the code nil-guards it), so players see no change. But `wow.lua:1073` always defines
the table, so the fallback branch never runs in smoke, and `UI-LootGrid.lua:191` only tests the
table path.

**Why it matters.** If the fallback ever breaks (for example a nil token reaching
`token:sub`), nothing catches it before a client without the table does.

**Fix.** A short scenario: save `LOCALIZED_CLASS_NAMES_MALE`, set it to nil, assert
`ns.UI.ClassName("PALADIN") == "Paladin"`, restore.

### R9 · Theme's header no longer says what the file holds

- **Severity:** nit
- **Area:** Readability (comments)
- **Where:** `NeedRoll/UI/Theme.lua:1-2`
- **Status:** fixed in round 2 (`5023a0b`)

**What's wrong.** "Palette, fonts and small widget helpers shared by every UI module." The
file now also holds text helpers (`T:JoinDots`, `T:Plural`, `T:WithIds`), the tooltip colours
used by `Core/Tooltip.lua`, and list builders that are neither small nor skin-only:
`T:ScrollColumn` (a 70-line scrolled list) and `T:ShowItem`, which loads item data through
`ns.Items:Load`. Theme is at 1642 lines.

**Why it matters.** The header is what tells the next implementer whether a helper belongs
here; without a line on what does and doesn't, Theme drifts toward a junk drawer.

**Fix.** Say what the file holds and where its line is, e.g. "… skin-aware widgets, the
tooltip colours, the list rows and scrolled columns the panes share, and small text helpers
(dot joins, plurals). Helpers with no look of their own go on `ns` (Core/Init.lua) instead."

### R10 · `T.DOTS` names the separator, but 9 literal copies of it remain

- **Severity:** should fix
- **Area:** Readability (searchable names, consistency)
- **Where:** `NeedRoll/UI/MainFrame.lua:1915,1918,1920`, `NeedRoll/UI/LootGrid.lua:61,1422,2787`,
  `NeedRoll/UI/Overview.lua:501` (twice), `NeedRoll/UI/RecipeBand.lua:818`,
  `NeedRoll/Core/Wishlist.lua:557`
- **Status:** fixed in round 3 (`a87d439`)

**What's wrong.** Round 2 added `T.DOTS = "  ·  "` (`UI/Theme.lua:340`) and uses it in
`T:JoinDots` and `T:WithIds`, which was R3's fix. But `grep -rn '"  ·  "' NeedRoll` still finds
the bare string in 7 files outside Theme. The plainest case is the instance subtitle, which is
`T:JoinDots`'s exact job:

```lua
-- MainFrame.lua:1915-1920
local subtitle = inst.name .. "  ·  " .. inst.zone
...
return enc.note and (inst.name .. "  ·  " .. enc.note) or subtitle
...
return subtitle .. "  ·  " .. L["Level %d-%d"]:format(inst.levelRange[1], inst.levelRange[2])
```

The others glue two known non-empty parts (`LootGrid.lua:61` `npc .. "  ·  " .. KillCount`),
add a coloured tail (`LootGrid.lua:1422`), or join a list (`LootGrid.lua:2787`,
`Overview.lua:501`, `Core/Wishlist.lua:557`, `RecipeBand.lua:818`).

**Why it matters.** A named constant only helps if it's the one name: grepping `T.DOTS` (or
`JoinDots`) now finds Theme and the converted sites but not these nine, so a change to the
separator still misses them. READABLE-CODE §7. This is what R3 asked for, so with R3's sites
done it's the rest of the same work.

**Fix.** `T:JoinDots(inst.name, inst.zone)` and the like for MainFrame 1915-1920 (it keeps
the output byte for byte while zone, note and level are non-empty, which the data guarantees),
and `T.DOTS` / `ns.Theme.DOTS` in place of the literal in the concatenations and
`table.concat(..., T.DOTS)`. Leave the separators inside `L["..."]` keys and in dev-only
English format strings where it is part of the sentence (`IconBrowser`, `SoundTest`,
`DropTalk`), or switch those too if Mike prefers one rule with no exceptions.

### R11 · The separator is still written into 7 shipped format strings

- **Severity:** nit
- **Area:** Readability (searchable names)
- **Where:** `NeedRoll/UI/Lists.lua:829,1774`, `NeedRoll/UI/Overview.lua:1405,1429,2902,3034,3159`
- **Status:** open: for Mike to decide (found in round 3, the last round)

**What's wrong.** R10's grep was for the bare string `"  ·  "`, so it missed format strings that
contain the separator. Two of them do exactly what `T:JoinDots` does:

```lua
-- Lists.lua:1774
return note and ("%s  ·  %s"):format(level, note) or level      -- T:JoinDots(level, note)
-- Lists.lua:828-830
local levels = ... and ("  ·  %d-%d"):format(inst.levelRange[1], inst.levelRange[2]) or ""
row.sub:SetText(inst.zone .. levels)                            -- T:JoinDots(inst.zone, range text)
```

The other five put it into a fixed pattern: `Overview.lua:1405` ("  ·  2 levels"), `1429`
(zone and coordinates), `2902` (standing and costs), `3034` (start text and status) and `3159`
(name, side, status).

**Why it matters.** It's the same point as R3 and R10, on a smaller scale: grepping `T.DOTS` or
`JoinDots` still misses these seven. Nothing breaks, and every output is correct.

**Fix, if Mike wants it.** `T:JoinDots` at `Lists.lua:829` and `1774`, and `T.DOTS` concatenated
in place of the literal in the five Overview patterns. The `L["..."]` keys that contain the dot
(`L["Loot  ·  %d"]` and others) and the English text in the dev tools stay as they are: changing
a key breaks its translations. Mike could also decide that a separator inside a sentence-like
format string is fine as written. That's why this is a nit for him rather than a request.

## Area notes

### Readability

Checked every new or moved function against `docs/READABLE-CODE.md`. Sound:

- Each new helper has a comment that says why and does one job: `ns.ParseGUID` documents the
  GUID shape and the meaning of its third value; `ns.Items:ModifiedClick` says what Shift and
  Ctrl do; `Names:CreatureName` says why a secret counts as no name; `T:ConfirmPill` names
  `CONFIRM_SECONDS`; `T:CheckBox` names `CHECK_STROKES` with its field order.
- The three new Theme builders are no more complex than the copies; they are the copies.
  `T:ScrollColumn` is Shopping's version verbatim (names `fitCount`, `rowsUsed`, `slot`
  rather than Wishlist's `fitting`, `shown`, `i`) plus Wishlist's `keep` argument;
  `T:ConfirmPill` is the two `CreateClearButton`s with the label, confirm label and action as
  arguments; `T:ShowItem` is Wishlist's `SetItem`. `T:CheckBox` is the one that grew (52
  lines, two skins, two label sides) and still has one job.
- Formatting: no added line over 120 characters in Lua (the three over are Markdown table rows
  in `STYLE-GUIDE.md`), 4-space indents, LF, no tabs. Every file still starts with
  `local _, ns = ...` (Init with `addonName`).
- Lua 5.1 traps: `T:CheckBox`'s `native and 2 or 6` and `native and 1 or 0` have non-nil
  middles; `ns.Plain` returns 0 as 0, so `Tooltip.lua`'s `if width then` still places a
  zero-width line by its left edge; no `#t` on a table with holes; `IDFromLink`'s pattern is a
  constant.
- luacheck: the 12 new warnings are all on `self`. The `unused argument 'self'` ones come from
  defining module functions with `:` (`ns.Items:IDFromLink`, `ns.Data:IsBoss`, `T:JoinDots`),
  as every sibling in those modules is (`ns.Items:Load`, `ns.Data:BossCount`, base Theme has 33
  such). The `shadowing upvalue argument 'self'` ones are `function box:Set` /
  `function column:Refresh` inside a `T:` builder, the same pattern `T:Pill` and the other
  base builders use (Theme had 31 before). Making these few different would break
  consistency; accepted.

### WoW API

Behaviour checks (each call site compared with the code it replaced):

- **`T:CheckBox` uses `SetScript("OnClick")` where Wishlist used `HookScript`.** The only
  difference is on the native skin, where a script from `UICheckButtonTemplate` itself would
  now be replaced. Ketho's `forever` `Templates.lua:3764` shows the template only inherits
  `UICheckButtonArtTemplate` (art), and the addon already `SetScript`s `OnClick` on the same
  template without trouble (`LootGrid.lua:1972` "Items I can use", and Shopping's base code),
  so by inference there is no template click handler to lose; the check button still ticks
  itself in C before `OnClick`. No caller sets `OnClick` on a box afterwards (grep), and
  Shopping's later `SetScript("OnEnter"/"OnLeave")` don't touch `OnClick`. Modern skin: the
  old Wishlist ran `Set(not checked)` then the hooked `onClick(IsOn())`; the new single script
  does the same two steps. Shopping's old modern `Set` stored `on` uncoerced and its click
  called `set(not checked)` without ticking first; the Shopping refresh then called
  `box:Set(subtractBags)`, so the end state is identical. Hit rect, label gap (6/2), lift
  (0/1) and colours match both copies.
- **Shopping's columns now `Show()` a row before `setupRow`.** `SetupTreeRow` and
  `SetupTotalRow` read `row:GetWidth()`, `row.toggle:IsShown()` (the child's own flag) and
  `GameTooltip:IsOwned(row)`, none of which depends on the row's own shown state; rows have no
  `OnShow` script (`T:Row` sets only `OnEnter`/`OnLeave`). Showing first matters for
  `T:ShowItem`'s new `row:IsShown()` check on the item-load callback: the row is shown when the
  callback is armed. Shopping's old `SetItem` had no such check, so a name arriving for a row
  scrolled out of view used to redraw a hidden row; now it waits for the column to set the row
  up again (the column re-runs `setupRow` for any row that was hidden). Same pixels.
  `SetData(entries, true)` keeps Shopping's old "always keep the scroll offset".
- **`GameTooltip_Hide`** is in Ketho's `forever` `FrameXML.lua:1873`. Passing it as a script
  handler gives it `(self, motion)`, which it ignores (inferred from FrameXML, where it takes
  no arguments). The smoke stand-in defines it as `GameTooltip:Hide()`.
- **`ns.UI.ClassName` fallback**: callers pass class tokens from `CLASSES`, the filter or
  `UnitClass` (always strings; `LootGrid.lua:2049` nil-guards `filter.class`). With the
  global table present, as in game, the result is unchanged. See R8.
- **`T.tip` colours, every call site:** Wishlist `HINT_COLOR` 0.5/0.6/0.65 → `hint`, its
  0.76/0.93/1 and 0.35/0.77/0.52 → `label`/`good`; Shopping `TIP_LABEL` → `label`, 0.5/0.6/0.65
  → `hint`, `AddCountLine` keeps 1/1/1 on the right; LootGrid `TIP_TITLE/LABEL/HINT/NOTE/TEXT/
  GOOD` → the same keys with the same values (the reagent green 0.23/0.53/0.36 stays inline);
  Core/Tooltip `TEXT` → `label`, `MUTED` → `hint`; MainFrame 0.99/0.82/0.62 → `title`,
  0.76/0.93/1 ×2 → `label`, 0.6 grey → `note`; Settings 0.76/0.93/1 → `label`. Lines that
  passed a wrap flag unpack into `r, g, b` first, so the flag still lands in the 5th argument.
  `grep` finds no literal copy of these values left outside `T.tip`. All exact.
- **`T.color.popup`**: modern `Hex("0A2136")` equals modern `panel2`; native
  `Hex("000000", 0.92)` equals the old `{ 0, 0, 0, 0.92 }`. Used by `T:Dialog`, the Wishlist
  menu, the Welcome callout and notice, the four places the old expression was.
- **`T:QualityIcon` replacing `Cell:SetBorderColor`**: the cell copies `Cell`'s methods first,
  then `T:QualityIcon` sets `cell.SetBorderColor` to the native or modern function chosen when
  the cell is built, which is what the old per-cell `self.native` did (a skin swap parks old
  cells; they keep their look). `cell.native` is read nowhere else (grep). Layers, sublevels,
  inset (2/1), texture and crop are the old values.
- **Other moved logic:** `ns.Data:IsBoss` in MapEdit drops `not enc.overview`, which only the
  `OVERVIEW` encounter carries (`Data.lua:94,719`), already in `NOT_BOSSES`; Search's local
  `NOT_BOSSES` had the same three IDs. `Names:CreatureName` returns nil for a secret, nil or
  empty first line, as MapEdit's copy did. `ns.ParseGUID`'s pattern is Drops' (anchored, hex
  spawn); LootLog's old pattern was unanchored after the ID, so a malformed GUID the old one
  half-matched now gives nil; real Creature/GameObject/Vehicle GUIDs end in a hex spawn UID, so
  by inference no in-game GUID changes result. `IsUsableWindowPoint` with `ns.Plain` rejects
  the same secret or nil values. `NeedRoll_ShowItem`'s link parse is equivalent. Saved keys:
  `ns.CharacterKey()` builds the same "Name-Realm" string Shopping and the loot filter used.

New or newly called game names, checked in the local copy of Ketho's `forever` lists:

| Name | Kind | In `forever` lists | Where |
| --- | --- | --- | --- |
| `GameTooltip_Hide` | FrameXML function | yes | `FrameXML.lua:1873` |
| `HandleModifiedItemClick` | FrameXML function | yes | `FrameXML.lua:2203` |
| `C_Item.GetItemInfo`, `GetItemNameByID`, `GetItemIconByID` | API | yes | `GlobalAPI.lua` |
| `C_QuestLog.GetTitleForQuestID` | API | yes | `GlobalAPI.lua` |
| `C_TooltipInfo.GetHyperlink` | API | yes | `GlobalAPI.lua` |
| `UnitName`, `GetRealmName`, `UnitFactionGroup`, `issecretvalue`, `C_Timer.After` | API | yes | `GlobalAPI.lua` |
| `SetHitRectInsets`, `SetClipsChildren`, `CreateMaskTexture`, `AddMaskTexture`, `SetRotation`, `SetChecked`, `GetChecked`, `GetStringWidth`, `GetNumLines`, `SetMovable`, `RegisterForDrag`, `StartMoving`, `StopMovingOrSizing` | widget methods | yes | `WidgetAPI.lua` |
| `OnHide`, `OnHyperlinkLeave` scripts | widget scripts | yes | `WidgetAPI.lua:52,538` |
| `UICheckButtonTemplate`, `BasicFrameTemplateWithInset` | templates | yes | `Templates.lua` |
| `LOCALIZED_CLASS_NAMES_MALE` | global table | inferred (nil-guarded) | not in any list |
| smoke stand-ins added: `GetLootRollItemInfo`, `C_Map.GetAreaInfo`, `C_TransmogCollection.GetAppearanceInfoBySource`, `ChatFrameUtil.InsertLink`/`RemoveMessageEventFilter`/`AddMessageEventFilter` | API / FrameXML | yes | `GlobalAPI.lua:5558,2843,4519`; `FrameXML.lua:563,572,493` |
| `ITEM_CLASSES_ALLOWED`, `Enum.ItemWeaponSubclass`, `Enum.ItemMiscellaneousSubclass` | global string / enums | yes, values match | `enUS.lua:12674`; `LuaEnum.lua:5235,5001` |

`wow.lua` removals: every one of the 27 removed globals (`GetCoinTextureString`,
`ChatEdit_InsertLink`, `ChatEdit_GetActiveWindow`, `ChatFrame_RemoveChannel`,
`ChatFrame_AddMessageEventFilter`, `ChatFrame_RemoveMessageEventFilter`,
`IsQuestFlaggedCompleted`, `GetQuestLogIndexByID`, `QuestLog_OpenToQuest`,
`QuestLog_SetSelection`, `QuestLog_Update`, `GetNumFactions`, `GetFactionInfo`,
`GetFactionInfoByID`, `ExpandFactionHeader`, `CollapseFactionHeader`, `GetNumSkillLines`,
`GetSkillLineInfo`, `GetContainerItemID`, `UseContainerItem`, `GetItemCount`, `EasyMenu`,
`GetAddOnMetadata`, `GetItemInfo`, `GetItemQualityColor`, `GetItemIcon`, `GetMouseFocus`) has
zero exact matches as a bare global in `GlobalAPI.lua`, `FrameXML.lua` and `Mixins.lua`
(several exist only under `C_` namespaces). Addon references to them: only
`GetCoinTextureString` (`Overview.lua:518`, guarded `if GetCoinTextureString then`) and
`GetNumSkillLines`/`GetSkillLineInfo` (`LootGrid.lua:362`, guarded); `Drops.lua:1087` hooks
`C_Container.UseContainerItem`, not the global. No unguarded path relies on a removed global.
`SetScript` dropping hooks matches the game (inferred from warcraft.wiki.gg's `SetScript`
notes). The remaining `wow.lua` globals were checked the same way; see R7 for the two left.

Other points checked: no new globals in `NeedRoll/`; no taint (no secure frame, protected
call or combat-time change); no new player-facing text (`L["..."]` keys only moved, locales
check passes); `GameWindow` lives outside DevKit's `--@debug@` block and DevKit ships in
`UI.xml`, and the dev-only `LineDump.lua` that also calls it is ignored by `.pkgmeta`; load
order is fine because every cross-file call (`ns.DevKit.GameWindow` from MapEdit,
`ns.Theme.tip` from Core/Tooltip) runs at run time, not at file load. Style guide updated for
the popup fill, tooltip colours, tick box, ask-once pill, quality-edged icons and round masks;
the values were checked against the code (sizes 14/22, gaps 6/2, crop 8%, inset 1/2, popup
fills, 3 seconds).

Pre-existing, outside this change: Forever has no global `GetNumSkillLines`/`GetSkillLineInfo`
(only `C_SkillInfo.*`), so `ns.UI.SkillRank` (`LootGrid.lua:362`) always returns nil in game
and the Scarce-reagent rank colouring never shows. Worth its own task.

### Redundant code

Compared against: `^function T:` in `UI/Theme.lua` (`T:Pill`, `T:Row`, `T:Rounded`,
`T:Text`, `T:SetTextColor`, `T:QualityColor`, `T:Dialog`, `T:WithIds`, `T:FitAtlas`),
`ns:Print`, `ns.Plain`, `ns.Items:Load`/`Quality`, `ns.Data:BossCount`, `ns.SideName`,
`ns.DevKit.*`. Each new helper replaces two or more copies; no new helper duplicates an existing
one. Dead code removed with it: `Drops.lua` `ItemIDOf` and its local `Plain`, `MainFrame.lua`
`IsPlain` and `PlayerFaction`, `Lists.lua` `MaskRound`/`PlayerFaction`, `Search.lua`
`NOT_BOSSES`/`PlaceName`, `MapEdit.lua` `NOT_BOSSES`/`CreatureName`, the per-file mask paths,
the test files' `Printed`, `Hover`/`Unhover` and stand-in patches. luacheck shows no new unused
locals. Left: R1 (tooltip hiding), R3 (dot joins). Not raised as a finding: LootGrid's filter
check boxes (`LootGrid.lua:1924,1966`) and Welcome's credit box are hand-built
`UICheckButtonTemplate`s that `T:CheckBox`'s native half now matches, but they show the game's
box in the modern skin too, so moving them would change the modern look.

### Security

Untrusted inputs touched: chat item links (`LootLog.lua` `AddSighting`) and loot/quest links
and unit GUIDs from the game (Drops, LootLog). The parsing is the same as before:
`IDFromLink` is the old `item:(%d+)` match with a nil guard, `ns.ParseGUID` is Drops'
anchored pattern; GUIDs come from the game, not from addon messages. No addon-message format,
outbox, daily cap or "Share drops" path changed. No `loadstring`/`RunScript`/`setfenv`, no text
from other players newly shown, no names or credits added to shipped files. No scraper, tools
or workflow change.

## Round 2

Re-read every function `a5077f8..5023a0b` touched in full (23 files, +168/−139), and re-ran
every check (see Checks).

**R2, `ns.ParseGUID` and its callers.** `ns.ParseGUID` now matches
`^(%a+)%-%d+%-%d+%-%d+%-(%d+)%-(%d+)%-(.*)$` and returns the spawn key only when the spawn
part is `^%x+$`. Compared with the code before this change (`08a3278^`):
- Drops' `CreatureAndKill` returns nil when there is no spawn key, so it accepts exactly what
  the old anchored `...%-(%x+)$` pattern accepted. That includes an empty spawn part: `.*`
  matches "", `^%x+$` rejects it, and the old `%x+` needed one character. The callers
  (`DeadBoss`, `ENCOUNTER_END`, `ScanWorld`, `Scan`, `NoteQuestLoot`) are unchanged.
- `QuestWindowSource` rejects a GUID with no spawn key before looking at the type, which is the
  old `%-%x+$` check. A GameObject with a hex spawn still gives "o".
- LootLog's `LootSourceOf` ignores the spawn key, so it again accepts anything after
  `<ID>-`, as its old unanchored pattern did. Round 1 had narrowed that, and round 2 put it back.
  The leading fields are fixed by `%-`-delimited `%d+`, so the ID capture can't move. A GUID with
  extra dashes ("…-639-6-7") gives ID 639 in LootLog and nil in Drops, both as before.
  `Item-<realm>-0-<hex>` still fails the pattern and falls through to the `^Item%-` check.
- The new assert in `Core-Init.lua` covers a non-hex spawn ("…-639-not-hex" → ID 639, no spawn
  key).
`Drops.lua` no longer has a local function named after the shared one. Fixed.

**R3, byte-identical joins.** `T:JoinDots` drops nil and "" parts, and the old code didn't, so
each site was checked for empty parts:
- `MainFrame.lua` `RecipeSubtitle`: parts are `inst.name`, skill text, "Mineable at …", "New in
  Forever", `enc.note` and `enc.learned`. The scraper writes `learned` as
  `" · ".join(...) or None` (`scraper/needroll_scraper/merge.py:271`), so it is never "", and no
  `note = ""` or `learned = ""` appears in `NeedRoll/Data/` (grep). Identical.
- `Overview.lua` `LevelText` and `AddRewards`: every part is a formatted `L[...]` string or
  `Money(...)`, never "". The `#parts > 0 and … or …` fallback is unchanged. Identical.
- `Search.lua` `SourceLine`: `line` holds at least one source name and `place` differs from it.
  Identical.
- `Fished.lua` `SubLine` (dev only): identical for every nil/equal/different combination of
  `subType` and `slot`. The one difference is a `subType` of "", where the old code printed a
  leading dot; `GetItemInfoInstant` doesn't return "" for it (inferred).
- `LootLog.lua` `SourceText` (the dev `/nr loot` printout): `channel` always comes from
  `CHAT_CHANNELS` (non-empty). `source.where` comes from `Where()`, which can return
  `GetZoneText()` = "" while the zone is still loading. The old line then ended in a dangling
  "  ·  "; the new one doesn't. That is the only byte change, it only shows in a dev printout,
  and it is the fix `T:JoinDots` exists for. Accepted.
- `T:WithIds` went from `("%s  ·  %s%s|r"):format(...)` to concatenation with `self.DOTS`. The
  output is the same for the string and number `text` it gets.
- LootLog calls `ns.Theme:JoinDots` only inside `SourceText`, which runs from `/nr loot`, long
  after `UI/Theme.lua` has loaded. Nothing runs it at file load (it isn't referenced at file
  scope). `Core/Init.lua` reads `ns.Theme.tip.text` only in `NeedRoll_OnCompartmentEnter`, also
  at run time.

**R4, renames.** `T.tip.info` = 0.76, 0.93, 1 and `T.tip.quiet` = 0.6, 0.6, 0.6, the old
`label` and `note` values. Every renamed line was checked: `info` on 12 lines in LootGrid, 2 each in
Core/Tooltip (`colors.info` and `tip.info`), MainFrame, Shopping and Wishlist, and 1 in
Settings; `quiet` on 3 lines in LootGrid and 1 in MainFrame. No `tip.label` or `tip.note` is left (grep). Every literal white that became
`T.tip.text` keeps 1, 1, 1, and lines with a wrap flag unpack into `r, g, b` first. Still open:
five white tooltip lines were missed, each in a function where the line next to it was
converted, so one tooltip now mixes both forms:
`UI/MainFrame.lua:330,333` (the "!" search note, whose title uses `T.tip.title`),
`UI/FrameDebug.lua:467` (the "Size:" line under the converted "Font:" line),
`UI/MapEdit.lua:810` (second line of the language picker tooltip) and `UI/Overview.lua:1898`
(the last route-handle hint, after three converted ones). They're all continuation lines, which
a one-line grep for `, 1, 1, 1)` misses. Fix: `unpack(T.tip.text)`, or `r, g, b, true` where
the line wraps.

**R5 and R6, call sites.** `grep` finds no `T:ShowItem`, `Items:ModifiedClick` or `labelLeft`
left anywhere in `NeedRoll/`, `tests/`, `docs/` or `.claude/`. `T:SetRowItem` is called from
Shopping (2) and Wishlist (2), and `ns.Items:HandleModifiedClick` from Shopping (2), Wishlist,
LootGrid, Fished and DropTalk. Both keep their arguments. `T:CheckBox`'s fourth argument is
now `labelSide == "LEFT"`. Shopping passes `"LEFT"` and the two Wishlist boxes pass nothing
(label at the right, as before).

**R7, stand-ins.** With `GetMinimapShape` gone, smoke runs `MinimapButton.lua:47`'s
`GetMinimapShape and GetMinimapShape() or "ROUND"` with the global nil, as in a game with no
minimap addon. `UI-MinimapButton.lua:26-50` defines its own square shape for its scenario and
restores the saved value (nil) after. `REAGENTBANK_CONTAINER` is referenced nowhere. Neither
removal hides a missing guard.

**R8, scenario.** "UI/LootGrid: a class's name without the game's class names table" saves
`LOCALIZED_CLASS_NAMES_MALE`, sets it nil inside `W.Restoring`, and puts the table back in the
restore function, which runs whether or not the assert fails. It passes in all three runs. It
calls `ns.UI.ClassName` directly, so no cached choice list is built while the table is nil.

**R9.** The new header says what Theme holds and where the line is ("Helpers with no look of
their own go on `ns` …"). Fixed.

**New redundancy.** `local T = ns.Theme` was added to MapEdit, Search and MinimapButton. Each
file had none before, and all three load after `Theme.lua` in `UI/UI.xml`. Overview's
`HideTooltip` became `GameTooltip_Hide` for direct handlers and inline `GameTooltip:Hide()`
inside longer ones, which is the same pattern the rest of the addon uses. No new helper
duplicates an existing one. One new finding: R10 (the separator literals `T.DOTS` doesn't
reach yet).

Verdict: **Changes needed**. One should-fix (R10) and the rest of R4 (a nit). Both are mechanical.

## Round 3

Round 3 reviews `7ade5da..a87d439` (7 files, +17/−17). I re-read every changed function in full
and the whole group's remaining separator and tooltip-colour sites, and re-ran every check:
- `luac5.1 -p` passed on the 7 changed Lua files.
- `locales.py --check` passed. `translations.py` exits 0 with the same 50 pre-existing lines.
- `luacheck --no-global -q` against `7ade5da` shows no change.
- `tests/smoke/check.sh` passed: 932 `ok` lines, all three runs "all passed".
- `CreateOverview` is still at 36 upvalues.
- No added line is over 120 characters.
- Line counts are still −155 for `NeedRoll/` and +266 for Theme.

**R4: no literal white is left in any tooltip line.** The five lines are converted:
`MainFrame.lua:330,333` (one `r, g, b` from `T.tip.text` for both wrapped lines),
`FrameDebug.lua:467`, `MapEdit.lua:810` (reuses the tooltip's `r, g, b`) and `Overview.lua:1898`.
`grep -rnE "1, 1, 1" NeedRoll` now finds only `T.tip.text` itself, a highlight colour
(`Theme.lua:1323`), and texture colours and coords in the dev `LineDump.lua`. None of those is a
tooltip line. The other literal tooltip colours left (0.7 grey "Drag to move." in MinimapButton,
1/0.82/0 gold in Overview and MapEdit, the dev windows' own greys and blues) aren't `T.tip`
colours, and this group didn't set out to name them. Fixed.

**R10: each `T:JoinDots` and `T.DOTS` site, byte for byte against `7ade5da`.**
- `LootGrid.lua:61` `BossIds`: `npc .. "  ·  " .. KillCount(npc)` became
  `T:JoinDots(npc, KillCount(npc))`. `npc` is a non-nil NPC ID (guarded on the line above), and
  `Drops:KillCount` always returns a number, 0 included (`Drops.lua:1620-1628`). `JoinDots`
  keeps numbers and `table.concat` writes them as `..` did. Identical.
- `LootGrid.lua:1422` (rep bar), `2787` (Related Quests), `RecipeBand.lua:818`: the literal
  became `T.DOTS`. Identical.
- `MainFrame.lua` `LootSubtitle` (1915-1922): the old code built `inst.name .. "  ·  " .. inst.zone`
  up front, so any instance reaching it already had a zone. Every collection and instance file
  sets one, and no `zone = ""` or `note = ""` exists in `NeedRoll/Data` (grep). For a collection,
  `T:JoinDots(inst.name, enc.note or inst.zone)` gives the old `name · note` or `name · zone`.
  For the rest, `T:JoinDots(inst.name, inst.zone, levels)` gives `name · zone · Level a-b`, or
  `name · zone` without a range. A collection with a `levelRange` still returns from its own
  branch first, as before. Identical.
- `Overview.lua:501`, the quest chain rows: the old `("%d.  %s  ·  %s%s|r"):format(i, names,
  ColorCode(color), status)` is now `("%d.  %s"):format(i, T:JoinDots(names, ColorCode(color)
  .. status .. "|r"))`. Each step in `Data/Chains.lua` has at least one quest ID, so `names` is
  never "" and `status`/`color` are set. The status part always ends in `|r`, so it is never
  empty. The joined string is therefore the same bytes. A step with no IDs would leave
  `status` nil, and both versions raise an error on it (the format's `%s` and the `..` alike),
  so no case went from failing to quietly different.
- `Core/Wishlist.lua:557`, the sixtyupgrades import note: the old code added
  `"  ·  " .. table.concat(who, ", ")` whenever `who` had entries; the new
  `ns.Theme:JoinDots(L["Imported from sixtyupgrades"], table.concat(who, ", "))` drops the join
  when it is "". The cases:
  - `who` empty: both give the bare note.
  - Name and/or class present and non-empty: identical.
  - The pasted export has `name = ""` and no class, so `who = { "" }`: the old note was
    "Imported from sixtyupgrades  ·  " (dangling dot); the new one is the bare note. The same
    happens for an empty `gameClass` and no level.

  That last case is the one byte change. It only happens with a malformed pasted export and only
  affects lists imported from now on (already-saved notes aren't rewritten). It is what
  `JoinDots` is for, so I accept it. The `|` escaping of pasted text is unchanged: it runs before
  the join. `ns.Theme` is read only when an import is parsed, long after `UI/Theme.lua` has
  loaded, as the new comment says.

`grep '"  ·  "' NeedRoll` now finds only `T.DOTS` itself. What's left of the separator is inside
`L["..."]` keys (which must stay), dev-only English text, comments, `Data/Maps.lua`'s credit
line (data), and seven shipped format strings. Those seven are R11, a nit for Mike to decide.
Fixed.

**The whole group, once more.** Looking across all three rounds:
- Every helper this group moved has one home, one name and a comment.
- There is no second copy of any of them, and no leftover old name (`HideTooltip`,
  `ShowItem`, `ModifiedClick`, `tip.label`, `tip.note`, `labelLeft`, a local `ParseGUID`).
- `wow.lua` defines no global Forever lacks that the addon reads.
- Behaviour, look and saved data are the same as before the group. The only differences are
  the two dangling-dot cases above (dev `/nr loot` with an empty zone, and a malformed import)
  and Shopping rows no longer redrawing while hidden; all three are deliberate improvements.
- No security-relevant path changed: the import text is still `|`-escaped, and no message,
  outbox or name handling changed.

**Final verdict: Ready.** Nothing blocking or should-fix is left. R11 is a nit about
consistency, not behaviour, and goes to Mike: convert the seven format strings, or accept a
separator written into a fixed sentence pattern.

## Round history

- 2026-10-18, round 1, `08a3278`: **Changes needed** (0 blocking, 3 should fix, 6 nits).
  Opened R1-R9.
- 2026-10-18, round 2, `5023a0b`: **Changes needed** (0 blocking, 1 should fix, 1 nit open).
  Closed R1, R2, R3, R5, R6, R7, R8, R9; R4 still open (5 white literals); opened R10.
- 2026-10-18, round 3 (last), `a87d439`: **Ready** (0 blocking, 0 should fix, 1 nit for Mike).
  Closed R4 and R10; opened R11 (left for Mike to decide).

## Integration

Squashed onto `dev` at 845ea13 (after #608, the Quests list chain fix). `UI/Lists.lua` merged cleanly with #608's `ChainSpot` change. On the squashed tree: `tests/smoke/check.sh` all passed (dev, packaged, secret), `tools/locales.py --check` passed, `luac5.1 -p` clean on every changed Lua file. `NeedRoll/` diffstat against dev: 29 files, +680 −835.
