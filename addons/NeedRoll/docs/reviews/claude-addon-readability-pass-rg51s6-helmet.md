# Review: Recipe band: worn Engineering products go by slot, not Fireworks

| | |
| --- | --- |
| Branch | `helmet-head` into `dev` (PR not opened yet) |
| Commit reviewed | `cc1f960` (no uncommitted changes); round 1 was `32db0df`, round 2 `92b133a` |
| Date | 2026-10-18 |
| Round | 3 |
| Verdict | **Ready** (0 blocking, 0 should fix, 0 nits) |
| Needs | `/reload`: only Lua bodies changed, no TOC or new file |

## What the change does

In a profession's recipe list, Engineering's chips were Explosives, Parts,
Devices, Fireworks, Head, Trinket, Weapons and Other. Before, any recipe
whose English name had "Rocket" or "Firework" in it went to Fireworks, so
the Goblin Rocket Helmet and both Rocket Boots sat under Fireworks. Now
that name rule only applies when the recipe's product can't be worn
(`ns.Wishlist:CanWear(itemID)`, a new name for the equip-slot check that
the wishlist's `CanStar` now calls); a worn product falls through to the
slot rules. Engineering gains a Feet chip (between Head and Trinket), so
the helmet lands under Head and the Goblin and Gnomish Rocket Boots under
Feet. The smoke tests give the Small Blue Rocket consumable item facts
(the stand-in's items are worn chest pieces by default) and assert the
helmet is Head and the Goblin Rocket Boots are Feet.

## Scope

- `NeedRoll/Core/Wishlist.lua`: `WL:CanStar`'s body becomes `WL:CanWear`
  ("has an equip slot"); `WL:CanStar` is a one-line wrapper that calls it.
- `NeedRoll/UI/RecipeBand.lua`: the `ENGINEERING` scheme gets a `FEET`
  group; its slot chips come from a new table,
  `ENGINEERING_GROUP_BY_SLOT_ORDER` (`:174-177`: 1 Head, 12 Feet,
  14 Trinket, 15-18 Weapons), read as `[order] or "OTHER"`; its `of` adds `isWorn` (from
  `CanWear`) and skips the Fireworks name match for worn products; its
  comment is rewritten.
- `tests/smoke/modules/UI-RecipeBand.lua`: the rocket, helmet and Goblin
  Rocket Boots get item facts (consumable / head / feet armor); the helmet
  is asserted Head (was Fireworks), the boots Feet;
  `W.itemFacts = W.itemFacts or {}` moves up.
- `tests/smoke/scenarios.lua`: "recipe list: Alchemy, First Aid,
  Engineering and Enchanting chips" makes the rocket a consumable around
  `Chips("ENGINEERING")`, and its closing loop now `Forget`s each
  profession's groups as well as resetting it.
- Generated data: none changed. `NeedRoll/Data/Professions/Engineering.lua`
  was read (not reviewed) to find every Rocket/Firework recipe.

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the four changed Lua files | round 3: passed (rounds 1 and 2: passed) |
| `luacheck --no-global -q`, new vs `origin/dev` | rounds 2 and 3 (same counts): `Wishlist.lua` 12 / 12; `RecipeBand.lua` 10 / 10 (the same `unused argument 'self'`); `UI-RecipeBand.lua` 2 / 2; `scenarios.lua` 70 / 71. No new warnings |
| `python3 tools/locales.py --check` | round 3: passed (exit 0); `L["Feet"]` is already in `enUS.lua:231` |
| `python3 tools/translations.py` | round 3: exit 0; lists keys the translation files have that NeedRoll no longer uses ("Level", "Press a key", "Quest chain"...). Pre-existing: this change touches no `L[...]` key and no locale file |
| `tests/smoke/check.sh` | round 3: all passed, 184 files loaded (rounds 1 and 2: all passed) |
| Scraper unit tests | not run: no scraper change |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | Readability | `NeedRoll/UI/RecipeBand.lua:213-230` | Goblin and Gnomish Rocket Boots move from Fireworks to Other, unsaid and untested | fixed in round 2 (`92b133a`) |
| R2 | should fix | Readability | `NeedRoll/UI/RecipeBand.lua:220` | `CanStar` is a wishlist rule standing in for "can be worn" | fixed in round 2 (`92b133a`) |
| R3 | nit | Redundant code | `tests/smoke/scenarios.lua:1717-1727` | The scenario leaves Engineering's groups cached from a faked fact | fixed in round 2 (`92b133a`) |
| R4 | nit | Readability | `NeedRoll/UI/RecipeBand.lua:230-235` | Engineering maps slot order to chip with an `if` chain of bare numbers; `SlotOf` uses a table | fixed in round 3 (`cc1f960`) |

### R1 · Goblin and Gnomish Rocket Boots move from Fireworks to Other, unsaid and untested

- **Severity:** should fix
- **Area:** Readability (comment that leaves the reader to guess; behaviour change not stated)
- **Where:** `NeedRoll/UI/RecipeBand.lua:213-217` (comment), `:220-221` (rule), `:228-232` (slot fallthrough)
- **Status:** fixed in round 2 (`92b133a`): the Feet chip route (Mike's decision, via the coordinator).
  `{ "FEET", L["Feet"] }` sits between Head and Trinket (`RecipeBand.lua:211`),
  `if order == 12 then return "FEET" end` (`:232`), the comment now says
  "the Goblin Rocket Helmet is Head, the Rocket Boots are Feet" and "head,
  feet and trinket by slot" (`:214-219`), and the module test asserts
  `GroupOf("ENGINEERING", "Goblin Rocket Boots") == "FEET"`. Gnomish Rocket
  Boots take the same path (feet, order 12); not asserted separately, which
  is fine since the rule is by slot, not by name.

**What's wrong.** The rule now reads "not a firework if worn, then by
slot", but the Engineering scheme only has slot chips for Head (order 1),
Trinket (14) and Weapons (15-18):

```lua
local _, order = ns.Wishlist:Slot({ itemID = itemID })
if order == 1 then return "HEAD" end
if order == 14 then return "TRINKET" end
if order and order >= 15 and order <= 18 then return "WEAPONS" end
return "OTHER"
```

The addon's Engineering data has three "Rocket"/"Firework" recipes that
make something worn:

| Recipe | Product | Data line | Before | After |
| --- | --- | --- | --- | --- |
| Goblin Rocket Helmet | 10588 (head) | `Engineering.lua:1454` | Fireworks | Head |
| Goblin Rocket Boots | 7189 (feet) | `Engineering.lua:356` | Fireworks | **Other** |
| Gnomish Rocket Boots | 10724 (feet) | `Engineering.lua:1063` | Fireworks | **Other** |

The boots fall to Other because feet are paper-doll order 12
(`EQUIP_SLOTS.INVTYPE_FEET = { L["Feet"], 12 }`, `Core/Wishlist.lua`) and
the scheme has no Feet group. The new comment names only the helmet ("unless
it makes something worn: the Goblin Rocket Helmet is Head") and still ends
with "then head and trinket by slot", so a reader can't tell that worn
rockets that aren't head or trinket go to Other. The commit message says
the same ("the helmet falls through to Head"). No test pins down where the
boots go.

**Why it matters.** An engineer who looked for Rocket Boots under
Fireworks (where they've been) now finds them only under All or Other,
next to the Parachute Cloak, Emergency Field Cloak and Gnomish Harm
Prevention Belt (`Engineering.lua:1095`, `:1047`, `:976`), which already
land there. That may be what Mike wants, but the change makes the move
without saying so, and he asked only about the helmet.

**Evidence.** `grep -n 'name = "[^"]*\(Rocket\|Firework\)' NeedRoll/Data/Professions/Engineering.lua`
lists 33 recipes; reading their products, only the three above are armor.
The boots' and helmet's slots are game knowledge (inferred, not checked
in game). Firework Launcher (21569) and Cluster Launcher (21570) are
placed, usable objects with no equip slot as far as I know (inferred), so
they stay under Fireworks. "Goblin Rocket Fuel Recipe" makes a recipe item
(10644), not worn, so it stays under Fireworks.

**Fix.** Ask Mike which he wants, then make the code and comment say it:

- Feet chip (fewer surprises for players): add `{ "FEET", L["Feet"] }`
  after `HEAD` in the scheme's `groups` (the key `L["Feet"]` already
  exists), and `if order == 12 then return "FEET" end` next to the Head
  line. The chip shows only when a recipe is in it, so nothing else
  changes. Comment: "...then head, feet and trinket by slot (the Rocket
  Boots are Feet)".
- Or keep Other, and say so in the comment: "unless it makes something
  worn, which goes by its slot like any other gear: the Goblin Rocket
  Helmet is Head, the Rocket Boots are Other".

Either way, add the boots to the module test next to the helmet:

```lua
local _, boots = Find("ENGINEERING", "Goblin Rocket Boots")
W.itemFacts[ns.UI.RecipeProduct(boots)] = { nil, Enum.ItemClass.Armor, nil, nil, 1, "INVTYPE_FEET" }
assert(GroupOf("ENGINEERING", "Goblin Rocket Boots") == "FEET", "the rocket boots aren't Feet")
```

### R2 · `CanStar` is a wishlist rule standing in for "can be worn"

- **Severity:** should fix
- **Area:** Readability (pillars 1, 6 and 9: names, consistency, disinformation)
- **Where:** `NeedRoll/UI/RecipeBand.lua:220`; the predicate is `NeedRoll/Core/Wishlist.lua:240-245` (`CanStar` at 241)
- **Status:** fixed in round 2 (`92b133a`): `WL:CanWear` (`Wishlist.lua:240-245`,
  "Whether an item has an equip slot (armor, weapons, bags, ammo...)") holds
  the check; `WL:CanStar` (`:247-248`, "Worn items get a star on their loot
  row") calls it, so the star button (`LootGrid.lua:1231`) and its smoke
  test (`Core-Wishlist.lua:119`) are unchanged. RecipeBand calls
  `CanWear` into a local `isWorn` (`RecipeBand.lua:222-223`), matching the
  comment's word "worn". The one-line `CanStar` body follows the file's and
  the addon's one-line-function habit (`Hex`, the Alchemy and First Aid
  `of` functions in `RecipeBand.lua`).

**What's wrong.**

```lua
local makesGear = itemID ~= nil and ns.Wishlist:CanStar(itemID)
```

Asked directly: is reusing `CanStar` for "wearable" honest? Its behaviour
is: today `CanStar` is exactly "has an equip slot":

```lua
-- Whether an item can be worn, so its loot row gets a star.
function WL:CanStar(itemID)
    local equipLoc = EquipLoc(itemID)
    return equipLoc ~= nil and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
        and equipLoc ~= "INVTYPE_NON_EQUIP"
end
```

Its name isn't. At the call site it reads "can this item be starred on the
wishlist", a UI rule of another module, and the reader of `RecipeBand.lua`
has to open `Core/Wishlist.lua` to learn that the star rule happens to be
"can be worn". The recipe band's grouping is now tied to the wishlist's
star policy: if Mike later decides shirts, tabards, bags or ammo get no
star (all of which pass `CanStar` today), or gives `CanStar` the module
check `LootGrid.lua:1231` does at its call site, Engineering's chips change
with it and nothing in `RecipeBand.lua` says why. The local name adds a
third word for the same idea: the comment says "worn", the local says
"gear", the function says "star"; and "gear" isn't quite right either, since
bags and quivers pass too.

**Why it matters.** It's the kind of name `docs/READABLE-CODE.md` pillar 9
warns about: it says something (the wishlist) the code doesn't mean here
(the item's equip slot). It doesn't break anything today.

**Evidence.** `grep -rn "CanStar" NeedRoll tests` gives two callers before
this change (`LootGrid.lua:1231`, the wishlist star button; the smoke
scenario at `scenarios.lua:255`) and this one. `RecipeBand.lua` already
leans on `ns.Wishlist:Slot` for paper-doll order (lines 67 and 228), so
asking `Core/Wishlist.lua` for item slot facts is consistent with the file;
the name is the problem, not the module. `Core/Wishlist.lua` loads before
`UI\UI.xml` (`NeedRoll.toc:21`), so `ns.Wishlist` exists when the band
builds its groups.

**Fix.** Give the slot fact its own name next to `WL:Slot` and have the
star rule use it:

```lua
-- Whether an item has an equip slot (armor, weapons, bags, ammo...).
function WL:CanWear(itemID)
    local equipLoc = EquipLoc(itemID)
    return equipLoc ~= nil and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
        and equipLoc ~= "INVTYPE_NON_EQUIP"
end

-- Worn items get a star on their loot row.
function WL:CanStar(itemID) return self:CanWear(itemID) end
```

and in the Engineering scheme, with one word for the idea:

```lua
local isWorn = itemID ~= nil and ns.Wishlist:CanWear(itemID)
if nameGroup[enc] == "FIREWORKS" and not isWorn then return "FIREWORKS" end
```

Don't re-test `equipLoc` from `ProductInfo` inline instead: that would be a
second copy of the `INVTYPE_NON_EQUIP` list (pillar 6).

### R3 · The scenario leaves Engineering's groups cached from a faked fact

- **Severity:** nit
- **Area:** Redundant code (test hygiene)
- **Where:** `tests/smoke/scenarios.lua:1717-1727`
- **Status:** fixed in round 2 (`92b133a`): the closing loop
  (`scenarios.lua:1747-1751`) calls `ns.RecipeBand:Forget(inst)` after
  `Reset`, with a comment saying why ("Engineering's groups were built from
  the made-up rocket"). The fact can still leak if an assert fails between
  setting and clearing it, but a failed scenario fails the run anyway, so
  that's not worth a `W.Restoring` here.

**What's wrong.** The scenario sets the rocket's facts, builds the chips
(`Chips` calls `RB:Forget` then `SelectInstance`, which caches
`groupsOf[engineering]`), then clears the fact with
`W.itemFacts[rocket] = nil`. The cache it built from the fake fact stays:
the scenario's last line (`ns.RecipeBand:Reset(inst)`) resets the chip and
toggles, not the groups. If an assert between the two lines fails, the
fact itself leaks too, since this scenario has no `W.Restoring` (the module
tests' `BandTest` does both: restores `W.itemFacts` and calls `RB:Forget`
on every profession).

**Why it matters.** A later scenario that opens Engineering without its
own `Forget` sees groups built from a consumable rocket while the stand-in
says chest armor. Harmless today (all other Engineering users call
`Forget` first: `scenarios.lua:1774`, `:1803`), but it's the order-dependent
state the module tests take care to avoid.

**Evidence.** Lines read: `scenarios.lua:1684-1693` (`Chips`), `:1717-1727`,
`:1747`; `RecipeBand.lua` `RB:Groups` / `RB:Forget` / `RB:Reset`.

**Fix.** Add `ns.RecipeBand:Forget(inst)` to the scenario's closing loop
(`for _, inst in ipairs({ alchemy, firstAid, engineering, enchanting }) do`),
or wrap the fact in `W.Restoring` the way `BandTest` does.

### R4 · Engineering maps slot order to chip with an `if` chain of bare numbers; `SlotOf` uses a table

- **Severity:** nit
- **Area:** Readability (pillars 6 and 7: one way of doing each thing, searchable names)
- **Where:** `NeedRoll/UI/RecipeBand.lua:230-235`; compare `:31-33` and `:67-68`
- **Status:** fixed in round 3 (`cc1f960`): `ENGINEERING_GROUP_BY_SLOT_ORDER`
  (`RecipeBand.lua:174-177`, with the suggested comment) next to the other
  scheme tables, and the `of` function ends
  `return ENGINEERING_GROUP_BY_SLOT_ORDER[order] or "OTHER"` (`:235`).
  Same results as the chain: every order the chain named maps the same,
  and anything else (including `Wishlist:Slot`'s 20 for "no slot") is
  Other. Smoke tests pass, including the Head and Feet assertions.

**What's wrong.** Round 2 grows this chain by one line:

```lua
local _, order = ns.Wishlist:Slot({ itemID = itemID })
if order == 1 then return "HEAD" end
if order == 12 then return "FEET" end
if order == 14 then return "TRINKET" end
if order and order >= 15 and order <= 18 then return "WEAPONS" end
return "OTHER"
```

The same file already does this job with a table: `SlotOf` reads
`GROUP_BY_SLOT_ORDER[order] or "OTHER"` (`:68`), where
`GROUP_BY_SLOT_ORDER` (`:31-33`) already maps `[1] = "HEAD"`,
`[12] = "FEET"` and `[15]`-`[18] = "WEAPONS"`. Engineering's chain repeats
those paper-doll numbers bare, and a reader has to know that 12 is feet
and 14 is trinket (the numbers are explained only in `Core/Wishlist.lua`'s
`EQUIP_SLOTS`). Round 1 missed this because the chain was older code; the
diff now touches it.

**Why it matters.** Nothing breaks. It's the "same job done two ways in
one file" the reviewer's rules flag, and each new Engineering slot chip
adds another bare number.

**Evidence.** Lines read: `RecipeBand.lua:31-33`, `:62-69`, `:221-236`.

**Fix.** A table next to the scheme, read the way `SlotOf` reads its own
(Engineering has no Shoulder, Back, Chest... chips, so it can't share
`GROUP_BY_SLOT_ORDER`, which also sends 14 to Other):

```lua
-- Engineering's worn products by paper-doll order (Wishlist:Slot); any
-- other slot is Other.
local ENGINEERING_GROUP_BY_SLOT_ORDER = { [1] = "HEAD", [12] = "FEET", [14] = "TRINKET",
    [15] = "WEAPONS", [16] = "WEAPONS", [17] = "WEAPONS", [18] = "WEAPONS" }
...
local _, order = ns.Wishlist:Slot({ itemID = itemID })
return ENGINEERING_GROUP_BY_SLOT_ORDER[order] or "OTHER"
```

`Wishlist:Slot` returns 20 for an item with no slot, which the table
doesn't have, so it still lands in Other.

## Area notes

### Readability

Round 3 re-read the whole diff against `origin/dev`: `WL:CanWear` /
`WL:CanStar`, the `ENGINEERING` scheme (groups, comment, `of`, the new
table) and both test files. The `of` function is now 13 lines at one level
of nesting, every slot number has a home in a named table, and the comment
still matches the code for every Rocket recipe. No line over 120
characters in `RecipeBand.lua`. Nothing left to ask for.

Round 2 re-read the whole `ENGINEERING` scheme (groups, comment, `of`),
`WL:CanWear`/`WL:CanStar` and both test hunks. The comment now matches the
code for every Rocket recipe (helmet Head, boots Feet, the rest Fireworks);
`isWorn`, the comment's "worn" and `CanWear` are one word for one idea.
New lines are under 120 characters (the longest changed line, the groups
row at `:211`, is 115). Only R4 is left.

Round 1: checked against every pillar of `docs/READABLE-CODE.md`. The changed
function (`SCHEMES.ENGINEERING.of`, 20 lines) still does one thing (picks a
recipe's group), stays at two levels of nesting, keeps 4-space indents and
LF endings, and new lines are under 120 characters (the longest, line 221,
is 90). The comment explains why (the helmet case) without narrating the
change; it is incomplete about worn non-head rockets (R1). The test
comments say why the rocket needs facts ("The stand-in's items are worn
chest pieces unless told otherwise"), which a newcomer needs. Naming: R2.
No Lua 5.1 traps: `itemID ~= nil and ...:CanStar(itemID)` is a plain
boolean, not an `and nil or` idiom; no `#` on holed tables; no patterns
built from data.

### WoW API

Round 3 adds nothing: a Lua table and a lookup. Round 2 adds no game call either: `WL:CanWear` makes the same
`C_Item.GetItemInfoInstant` call through `EquipLoc` that `CanStar` made.
The Feet chip uses the existing `L["Feet"]` key and the band's existing
chip code, so its look is unchanged and `docs/STYLE-GUIDE.md`, which
describes the chips' look but not which chips each profession has, needs
no update (`grep -n -i chip docs/STYLE-GUIDE.md`).

Round 1: the change adds no game call; it newly reaches `C_Item.GetItemInfoInstant`
through `CanStar` for Engineering's products (the band already called it
through `ProductInfo`). Checked against the local copy of Ketho's
`forever` lists (`.../scratchpad/ketho/`):

| Name | Kind | In `forever` lists | Where looked |
| --- | --- | --- | --- |
| `C_Item.GetItemInfoInstant` | function | yes | `GlobalAPI.lua:2523` |
| `Enum.ItemClass.Consumable` (test) | enum | yes | `LuaEnum.lua:4643` |
| `Enum.ItemClass.Armor` (test) | enum | yes | `LuaEnum.lua:4647` |
| `"INVTYPE_NON_EQUIP"`, `"INVTYPE_NON_EQUIP_IGNORE"`, `"INVTYPE_HEAD"`, `"INVTYPE_FEET"` | equip location strings `GetItemInfoInstant` returns | inferred (standard returns; the strings aren't listed as such) | already used in `Core/Wishlist.lua` |

`GetItemInfoInstant` reads client data and answers for uncached items, so
no async load is needed here. No events, frames, templates, atlases,
secret values, globals or protected frames involved; nothing runs in
combat. No player-facing text added. The smoke stand-in already mirrors
`GetItemInfoInstant` with `W.itemFacts` (`tests/smoke/wow.lua:1450-1456`);
the fix has a scenario and a module test. No UI layout change, so
`docs/STYLE-GUIDE.md` needs nothing (it has no chip-assignment rules). No
dev-only code.

### Redundant code

Compared against `ns.Wishlist:CanStar` and `ns.Wishlist:Slot`
(`Core/Wishlist.lua`), `ProductInfo` and `SlotOf` (`RecipeBand.lua`),
`ns.Items:Load/Quality/Collected` (`Core/Items.lua`) and `SlotText` in
`UI/LootGrid.lua:103`. Round 2: `WL:CanWear` replaces `CanStar`'s body rather than copying it, so
the `INVTYPE_NON_EQUIP` list still exists once
(`grep -rn INVTYPE_NON_EQUIP NeedRoll` outside data: `Wishlist.lua:243-244`
and a comment in `LootGrid.lua:106`). `CanStar` keeps its two callers.
The Engineering slot chain is R4, fixed in round 3 with a table read the
way `SlotOf` reads `GROUP_BY_SLOT_ORDER`; it can't reuse that table, which
has no Trinket and sends 14 to Other. Round 1: the change reuses the existing predicate rather than
writing a new one, which is right; only its name is the issue (R2). The
scenario's lookup loop for "Small Blue Rocket" matches the file's own
pattern (`scenarios.lua:1669`), as `scenarios.lua` has no `Find` helper.
`makesGear` is computed for every Engineering recipe though only Fireworks
ones read it; harmless, as `RB:Groups` caches once per profession. No dead
code, no debug prints, no new `OnUpdate`.

### Security

None, in either round: the change reads static recipe data and the client's item info. No
addon messages, chat, SavedVariables, player names, network, scraper,
tools or workflows touched.

## Round history

- 2026-10-18, `32db0df`, round 1: **Changes needed**. Opened R1, R2, R3.
- 2026-10-18, `92b133a`, round 2: **Changes needed** (1 nit). Closed R1 (Feet chip), R2 (`WL:CanWear`), R3 (`Forget` in the scenario). Opened R4.
- 2026-10-18, `cc1f960`, round 3: **Ready**. Closed R4 (slot table). No findings open.
