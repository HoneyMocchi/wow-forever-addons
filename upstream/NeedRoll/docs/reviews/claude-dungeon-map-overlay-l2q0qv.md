# Review: NeedRoll's dungeon map laid over the game's world map (M stays the game's)

| | |
| --- | --- |
| Branch | `claude/dungeon-map-overlay-l2q0qv` into `dev` (PR not opened yet) |
| Commit reviewed | `32c7b40` plus uncommitted changes (round 3: 12 modified files, 2 new untracked files besides this doc) |
| Date | 2026-10-18 |
| Round | 3 (last) |
| Verdict | **Ready** (0 blocking, 0 should fix, 0 nits open). Left for Mike: R4 (kept on purpose, to be declared in the PR) and R9 (world map strata, to check in game) |
| Needs | Full game restart: the change adds a new file (`NeedRoll/UI/WorldMapOverlay.lua`, listed in `UI/UI.xml`), and the client only picks up new files at startup. Later edits to existing files only need `/reload`. |

## What the change does

Before: inside a dungeon or raid that NeedRoll has a map for, NeedRoll took over the M key with an
override binding (`SetOverrideBindingClick` on a hidden `NeedRollMapKey` button), so M opened
NeedRoll's window on its own dungeon map and the game's world map never opened. Players couldn't
share quests, read the quest log or reach the zone map from inside the dungeon.

After: M is left to the game. When the game's world map opens inside such an instance, a new
module (`UI/WorldMapOverlay.lua`) lays NeedRoll's drawing of the player's floor over the game's map
art: art tiles, boss pins, quest markers, entrances, locks, links to other levels and the zone-wide
quest badge. The layer is parented to `WorldMapFrame.ScrollContainer` and its canvas is anchored to
the game's canvas, so it pans and zooms with the game's map. Clicking a boss or quest opens
NeedRoll's window on that page above the map. Back from there is "world map", which only closes
the window. Right-clicks go through NeedRoll's widgets to the game's map
(`SetPassThroughButtons("RightButton")`), so the game's own `NavigateToParentMap` takes the player
to the zone map. Any map that isn't one of the instance's floors turns the overlay off until the map
is closed and opened again. The drawing code is shared with the window's map: `CreateMapView` is
split into `ns.UI.CreateMapLayer` (frames and pools) plus the window's own extras, and the body of
`DrawMap` moved into `ns.UI.DrawMapLevel`. Boss and quest clicks now go through `view.openBoss` and
`view.openQuest`, which each map sets for itself.

## Scope

- `NeedRoll/UI/WorldMapOverlay.lua` (new): the overlay. Hooks `OnShow`/`OnHide` on the world map,
  polls `WorldMapFrame:GetMapID()` in `OnUpdate`, draws via `ns.UI.DrawMapLevel`, sets right-click
  pass-through out of combat.
- `NeedRoll/UI/Overview.lua`: `IsPlayerInside`/`PickFloor` moved out of `PlayerFloor` (they were
  closures inside it); new `ns.UI.MapFloor`, `ns.UI.CreateMapLayer`, `ns.UI.ArtScale`,
  `ns.UI.DrawMapLevel`; boss pin, quest marker and zone quest icon clicks go through
  `view.openBoss`/`view.openQuest`; the "Open the world map" pill's tooltip text changed.
- `NeedRoll/UI/MainFrame.lua`: the map key binding (`MapKeyInstance`, `MapKey`, `UpdateMapKey`,
  the zone-event registrations, the world map hooks) is removed; new `UI:ShowFromWorldMap`;
  `UI:OpenWorldMap` does nothing more once the map is already open.
- `NeedRoll/Core/Init.lua`: the `dungeonMap` default's comment; `Modules:Set` calls
  `WorldMapOverlay:Recheck` in place of `UpdateMapKey`.
- `NeedRoll/UI/Settings.lua`: Map in dungeons calls `Recheck`; new `about` string; header comment.
- `NeedRoll/UI/UI.xml`: loads `WorldMapOverlay.lua` after `MapEdit.lua`.
- `NeedRoll/Locales/enUS.lua`: two changed strings, `L["the map"]` moved to its first use.
- `README.md`, `docs/STYLE-GUIDE.md`: the setting's wording; a new row for the overlay.
- `tests/smoke/wow.lua`: `SetPassThroughButtons` (errors in combat), a world map with a canvas and
  scroll container sized like the game's, per-map art files for Shadowfang Keep, `OpenWorldMap`
  shows and then sets the map (the game's order).
- `tests/smoke/modules/UI-WorldMapOverlay.lua` (new): five cases (floor shown, boss click, quest
  click, floor following and dropping out, Game setting and tab off, combat pass-through).
- `tests/smoke/modules/UI-MainFrame.lua`, `tests/smoke/scenarios.lua`: the map key tests rewritten
  for "M stays the game's", plus a boss clicked on the overlay.

No generated files under `NeedRoll/Data/` changed. Non-English locale files are untouched (the
Translations bot owns them).

## Checks

| Check | Result |
| --- | --- |
| `luac5.1 -p` on the 10 changed or new Lua files | passed |
| `python3 tools/locales.py --check` | passed (exit 0) |
| `python3 tools/translations.py` | exit 0. Lists 70 "not used by NeedRoll any more" lines, including the two replaced strings (`In dungeons the map key opens NeedRoll's map...`, `Which map M opens inside a dungeon`). That is expected for a string change, and the Translations bot removes them. |
| `luacheck --no-global -q` (changed files and base) | **not run**: luacheck isn't installed and `luarocks` isn't available on this machine. Stand-in: `luac5.1 -l` listings show no `SETGLOBAL` added in `Overview.lua` or `MainFrame.lua`. `WorldMapOverlay.lua` only reads `WorldMapFrame`, `InCombatLockdown`, `ipairs` and `setmetatable` as globals. Upvalue counts per function in `Overview.lua` are unchanged (largest 36, base 36). |
| `bash tests/smoke/check.sh` | passed: dev (185 files), packaged (179) and dev with secret values, "all passed" each; 977 ok lines, including the 5 new `UI/WorldMapOverlay` cases |
| Round 2: `luac5.1 -p`, `locales.py --check`, `translations.py` | passed (exit 0 each); `WorldMapOverlay.lua` still sets no globals (`luac5.1 -l`) |
| Round 2: `bash tests/smoke/check.sh` | passed: dev (185 files), packaged (179) and secret values, "all passed" each. New assertions: a level-2 recheck, a tab switched after right-click, the zoom settle redraw, no level links on the overlay, and Back after a quest-marker click on the window's map |
| Round 2: luacheck | not run (still not installed) |
| Round 3: `luac5.1 -p`, `locales.py --check`, `translations.py` | passed (exit 0 each); `WorldMapOverlay.lua` sets no globals |
| Round 3: `bash tests/smoke/check.sh` | passed: dev (185 files), packaged (179) and secret values, "all passed" each, 980 ok lines (one new case, "a floor NeedRoll draws itself stays through a recheck", run in each of the 3 passes; the pill tooltip on Game is checked inside the existing Game case) |
| Round 3: luacheck | not run (still not installed) |
| Scraper unittest | not run: no scraper change |
| Line endings / tabs | LF, no tabs in the new files. New lines over 120 characters: only the tooltip line that carries the long `L[...]` key (`Overview.lua:2093`). It can't get shorter without changing the string. |

## Findings

| ID | Severity | Area | Location | Title | Status |
| --- | --- | --- | --- | --- | --- |
| R1 | should fix | WoW API (behaviour) | `UI/WorldMapOverlay.lua:112-122`, `Core/Init.lua:213`, `UI/Settings.lua:56` | `Recheck` draws the player's floor over whatever map the game shows, including the zone map after right-click | fixed (round 2) |
| R2 | should fix | WoW API (behaviour) | `UI/Overview.lua:2395-2423`, `UI/WorldMapOverlay.lua:55,66-76` | Level links on the overlay move NeedRoll's level away from the game's floor, and it can get stuck there | fixed (round 2) |
| R3 | should fix | Redundant code | `UI/WorldMapOverlay.lua:33-54,75` | Full redraw and a recursive child walk on every frame of the game's zoom animation | fixed (round 2) |
| R4 | should fix | Readability (behaviour) | `UI/Overview.lua:2374,2100` | Quest markers on the window's own map now push a Back step: an undeclared behaviour change | left as is |
| R5 | nit | Redundant code | `UI/MainFrame.lua:2217-2227`, `UI/MainFrame.lua:2192-2194` | "Back = world map" history built in two places; `GoToSource`'s history work thrown away | fixed (round 2) |
| R6 | nit | Readability | `UI/Overview.lua:848-866,906` | `IsPlayerInside` now calls `GetInstanceInfo()` on every call | fixed (round 2) |
| R7 | nit | Redundant code | `UI/WorldMapOverlay.lua:106` | `ns.Data:Map(instance.id)` check can't fail | fixed (round 2) |
| R8 | nit | Readability | `UI/WorldMapOverlay.lua:20-24,83-98` | One object called `view`, "layer" and `CreateLayer`; a non-frame called `pane` | fixed (round 2) |
| R9 | nit | WoW API | `UI/MainFrame.lua:2219`, `UI/MainFrame.lua:813` | Window above the map relies on the world map's strata being HIGH or lower (unverified for Forever) | left as is |
| R10 | nit | Readability | `UI/Overview.lua:2661` | "Open the world map" pill still hidden on Map in dungeons = Game, though that setting no longer changes what M does | fixed (round 2) |
| R11 | nit | Readability | `UI/WorldMapOverlay.lua:113`, `UI/MainFrame.lua:2211` | "Is the game's map open" written twice | fixed (round 2) |
| R12 | should fix | Readability (visual behaviour) | `UI/WorldMapOverlay.lua:83-85` | While the game's zoom eases, NeedRoll's art and pins stay at the old size over the game's art at the new size | fixed (round 3) |
| R13 | nit | Readability (disinformation) | `UI/Overview.lua:2679`, `2104-2110` | The pill now shows on Map in dungeons = Game, where its tooltip describes an overlay that isn't there | fixed (round 3) |
| R14 | nit | WoW API (behaviour) | `UI/WorldMapOverlay.lua:143-151` vs `133-137` | `Recheck` hides the layer for the drawings the game lacks (Media/Maps), which `OnWorldMapShow` showed | fixed (round 3) |

### R1 · `Recheck` draws the player's floor over whatever map the game shows, including the zone map after right-click

- **Severity:** should fix
- **Area:** WoW API (behaviour against the ask)
- **Where:** `NeedRoll/UI/WorldMapOverlay.lua:112-122`; callers `NeedRoll/Core/Init.lua:213` (`Modules:Set`), `NeedRoll/UI/Settings.lua:56` (Map in dungeons pick)
- **Status:** fixed in round 2 (uncommitted): `droppedUntilReopen` set by `TurnOff(true)` from `FollowGameMap`, cleared in `OnWorldMapShow`; `Recheck` takes the floor from `ns.UI.MapFloor(WorldMapFrame:GetMapID(), playerInstance)`; smoke case covers a tab switched after right-click and a recheck on floor 2

**What's wrong.** `Recheck` always uses the player's floor and makes the overlay follow the map the
game shows now, whatever that map is:

```lua
function WorldMapOverlay:Recheck()
    if not (WorldMapFrame and WorldMapFrame:IsShown()) then return TurnOff() end
    local instance, level = PlayerMapToShow()       -- the player's floor
    if not instance then return TurnOff() end
    view = view or CreateLayer()
    pane.instance = instance
    pane.levels[instance.id] = level
    followedMapID = WorldMapFrame:GetMapID()        -- whatever the game shows now
    view:Show()
    Draw()
end
```

That's correct when it runs from the map's `OnShow`, because the game has just set the map to the
player's map. But it also runs from `Modules:Set` (any tab switched) and from the Map in dungeons
pick, both of which can happen while the map is open: after a boss click, NeedRoll's window sits
above the open map with its Settings button. At that point the game's map may be on the zone map
(the player right-clicked) or on another floor (the floor dropdown). Nothing remembers that the
player dropped the overlay.

**Why it matters.** Example: the player right-clicks to Silverpine Forest, then opens NeedRoll and
turns off the Wishlist tab. `Modules:Set` → `Recheck` → NeedRoll's Shadowfang Keep floor is drawn
over the Silverpine map, scaled to its canvas. The zone map is covered and `followedMapID` is now
the zone's ID, so the overlay stays until the map changes or closes. The same happens with a
different floor: the game's player arrow, party dots and the floor dropdown show floor 2 while
NeedRoll's art shows floor 1. This breaks the ask: right-click "effectively closes NeedRoll's
interaction from that point".

**Evidence.** I read `WorldMapOverlay.lua:100-122`, `Init.lua:200-214` and `Settings.lua:50-58`.
The smoke case "Map in dungeons = Game" (`UI-WorldMapOverlay.lua:152-170`) only calls `Recheck` while
the map is on the player's floor, so it doesn't cover this.

**Fix.** Remember that the player dropped the overlay until the next `OnShow`. When the map is
already open, take the floor from the map the game shows rather than from the player:

```lua
local droppedUntilReopen = false   -- right-click or another map turned it off

local function TurnOff(dropped)
    pane.instance, followedMapID = nil, nil
    droppedUntilReopen = dropped or false
    if view then view:Hide() end
end
-- FollowGameMap: `if instance ~= pane.instance then return TurnOff(true) end`

function WorldMapOverlay:Recheck()
    if droppedUntilReopen or not (WorldMapFrame and WorldMapFrame:IsShown()) then return TurnOff(droppedUntilReopen) end
    local playerInstance = PlayerMapToShow()
    if not playerInstance then return TurnOff() end
    local instance, level = ns.UI.MapFloor(WorldMapFrame:GetMapID(), playerInstance)
    -- (keep the PlayerFloor result only on OnShow, for the Media/Maps drawings the game lacks)
    ...
end
-- OnShow hook: droppedUntilReopen = false, then Recheck.
```

Add a smoke case: right-click to `ZONE_MAP`, then `ns.Modules:Set("WISHLIST", false)`, and assert
`not LayerShows()`.

### R2 · Level links on the overlay move NeedRoll's level away from the game's floor, and it can get stuck there

- **Severity:** should fix
- **Area:** WoW API (behaviour)
- **Where:** `NeedRoll/UI/Overview.lua:2395-2398` (`ShowLevel`), `2402-2423` (`NewLevelLink`), `2565-2580` (links drawn by `DrawSpots`); `NeedRoll/UI/WorldMapOverlay.lua:55` (`pane:Refresh`), `66-76` (`FollowGameMap`)
- **Status:** fixed in round 2 (uncommitted): `view.noLevelLinks` set in `CreateLayer`, read by `DrawSpots`; header, STYLE-GUIDE row and smoke case updated

**What's wrong.** The overlay shares `DrawSpots`, so it draws NeedRoll's green level arrows. A click
runs `ShowLevel`, which sets `pane.levels[...]` and redraws NeedRoll's art at the other level. The
game's map stays on its floor, because NeedRoll can't call `SetMapID` without tainting it. The file
header says the opposite: "The game's map stays in charge: its floor dropdown picks the level shown"
(`WorldMapOverlay.lua:5-6`). `FollowGameMap` only resyncs when `GetMapID()` changes:

```lua
local mapID = WorldMapFrame:GetMapID()
if mapID ~= followedMapID then ... end
```

**Why it matters.** Example: the player is on floor 2 and clicks NeedRoll's arrow to floor 1. NeedRoll
now shows floor 1's art, but the game's player arrow, party dots, quest POIs and its own map-link
pins (frame level 2000, above NeedRoll's art) are floor 2's, so they sit on the wrong drawing. Next
the player picks floor 2 in the game's dropdown: that's the map ID already followed, so
`FollowGameMap` does nothing, and the overlay stays stuck on floor 1 while the dropdown says floor 2.
The smoke case `UI-WorldMapOverlay.lua:130-137` asserts that this desync happens ("a level link
changed the level").

**Evidence.** I read the code above. The game draws its own floor links:
`Blizzard_WorldMap.lua:229` adds `MapLinkDataProviderMixin`, whose pins navigate the game's map
properly (`Blizzard_SharedMapDataProviders/MapLinkDataProvider.lua`). Pins sit at frame level 2000
and up (`MapCanvas_PinFrameLevelsManager.lua:3`). Whether Forever's dungeon floors carry map links is
inferred, not checked in game.

**Fix.** Don't let the overlay change level by itself. Either skip the links on the overlay (a flag
on the view that `DrawSpots` reads, for example `view.noLevelLinks = true` set in `CreateLayer`, and
`local links = (shown and not view.noLevelLinks) and ... or {}`), or keep them as markers only: no
click, with a tooltip naming the level and pointing to the floor dropdown. Update the header comment,
the STYLE-GUIDE row ("level links (22)") and the smoke case to match.

### R3 · Full redraw and a recursive child walk on every frame of the game's zoom animation

- **Severity:** should fix
- **Area:** Redundant code (work repeated per frame)
- **Where:** `NeedRoll/UI/WorldMapOverlay.lua:75` (`if view.canvas:GetWidth() ~= view.drawnWidth then Draw() end`), `46-54` (`Draw`), `33-42` (`PassRightClicks`)
- **Status:** fixed in round 2 (uncommitted): new widgets go through `MapWidget` → `view.onNewWidget` (pass-through set once per widget, combat ones queued in `waitingForRightClicks`); redraw waits until the canvas width holds for a frame (new side effect: R12)

**What's wrong.** The game's map doesn't zoom in one step. Each frame its `OnUpdate` moves the
canvas scale toward the target with `FrameDeltaLerp` until it is within 0.0001
(`Blizzard_MapCanvas/MapCanvas_ScrollContainerMixin.lua:324-364`, `self.Child:SetScale(self.currentScale)`).
The canvas width the overlay reads therefore changes on every frame of a zoom (and of `ResetZoom`
on open), and each change runs `Draw`. Each `Draw` does a full `ns.UI.DrawMapLevel`:

- `PlaceTiles` and `LoadTiles`;
- `BossPins` builds new tables, and `DrawPins` builds `view.pinAt`, `view.patrols` and the `at`/`count` tables;
- `DrawSpots` runs `DrawQuestMarkers`, `DrawZoneQuests` (`DrawZoneLines` re-anchors every line) and `DrawRouteEdit`;
- then `PassRightClicks(view)` walks every descendant frame, building a `{ frame:GetChildren() }`
  table at each level of the tree.

The window's own map redraws once per mouse-wheel step. The overlay redraws tens of times per wheel
step.

**Why it matters.** Each wheel tick on the world map inside a dungeon produces a burst of table
garbage and texture and anchor work. That's measurable on a busy floor (Blackrock Depths, Scholomance:
dozens of markers, routes and area lines) and shows as hitching while zooming. `docs/READABLE-CODE.md`
and the reviewer brief ask for per-frame work to have a reason. Polling the map ID has one; a full
redraw per frame doesn't.

**Evidence.** I read the Blizzard source cited above and the call chain in `Overview.lua:2635-2644`,
`2200-2232` and `2523-2581`. No profiling was done, so the size of the cost is inferred.

**Fix.**
1. Walk for pass-through only when frames were added. For example, have `Pooled` (or
   `CreateMapLayer`) call an optional `view.onNewFrame(frame)` hook, and set it in `CreateLayer` to
   `PassRightClicks`. Keep the `PLAYER_REGEN_ENABLED` sweep for frames made in combat.
2. On a zoom, don't rebuild the level. Either wait until the width has held for a frame
   (`if width == view.lastSeenWidth and width ~= view.drawnWidth then Draw() end`, then store
   `lastSeenWidth`), or add a cheap "re-place" path to `Overview.lua` that only re-runs
   `PlaceTiles` and the `PlaceOnArt` calls for frames already shown.

### R4 · Quest markers on the window's own map now push a Back step: an undeclared behaviour change

- **Severity:** should fix
- **Area:** Readability ("Behaviour stays the same" for the window's map)
- **Where:** `NeedRoll/UI/Overview.lua:2374` (marker click), `NeedRoll/UI/Overview.lua:2100` (`view.openQuest = OpenQuestPage`)
- **Status:** left as is: kept deliberately (matches boss pins and the zone badge), pinned by a smoke assertion in `UI-Overview.lua` and to be declared in the PR description

**What's wrong.** Before, a quest marker click on the window's map was:

```lua
elseif self.quest then
    GameTooltip:Hide()
    ns.UI:SelectQuest(self.quest)
```

Now it is `view.openQuest(self.quest)`, and for the window's map `view.openQuest = OpenQuestPage`,
which first runs `ns.UI:PushBack(ns.UI:Place())` (`Overview.lua:447-450`). The zone-quest badge icon
already used `OpenQuestPage`; merging both into one callback quietly moved quest markers onto the
badge's behaviour.

**Why it matters.** In the window, clicking a quest marker on the dungeon map now adds a Back step
"<dungeon name>" in front of whatever Back led to before (for example "world map" right after
entering). Back now takes one more click to reach the world map. It may well be the better
behaviour, and it matches the boss pins, but the change summary doesn't mention it and no smoke case
pins it.

**Evidence.** `git diff origin/dev -- NeedRoll/UI/Overview.lua` hunk at `NewQuestMarker`
(`-ns.UI:SelectQuest(self.quest)` / `+view.openQuest(self.quest)`); `OpenQuestPage` at
`Overview.lua:447`. A grep of `tests/smoke` for a marker click with a history assertion finds none
on the window's map.

**Fix.** Choose one and make it explicit. Either keep the old behaviour, giving the window two
callbacks (`view.openQuest = OpenQuestPage` for the badge and
`view.openMarkerQuest = function(quest) ns.UI:SelectQuest(quest) end` for markers), or keep the new
one. If you keep the new one, say so in the PR description for Mike and add a smoke assertion that
Back after a marker click returns to the map.

### R5 · "Back = world map" history built in two places; `GoToSource`'s history work thrown away

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/MainFrame.lua:2217-2227` (`ShowFromWorldMap`), `NeedRoll/UI/MainFrame.lua:2192-2194` (`FollowPlayer`)
- **Status:** fixed in round 2 (uncommitted): `UI:StartHistoryAtWorldMap()` used by `FollowPlayer` and `ShowFromWorldMap`

**What's wrong.** `ShowFromWorldMap` calls `GoToSource`, which runs `ClearHistory()` and
`PushBack(from)` (`MainFrame.lua:1668-1670`). It then throws that away with `wipe(self.history)` and
inserts `{ label = L["world map"], worldMap = true }`. `FollowPlayer` builds the same entry after
`self:ClearHistory()`. So the same job is written two ways (`wipe` here, `ClearHistory` there), and
the world-map entry is a literal in two places.

**Why it matters.** If the world-map Back step ever changes (its label, an extra field), one copy
will be missed. A reader also has to work out that `GoToSource`'s history push is dead work here.

**Evidence.** The lines quoted; `UI:ClearHistory` at `MainFrame.lua:1645-1651`.

**Fix.** Add one helper and use it in both places:

```lua
-- Back from here leads to the game's world map and no further.
function UI:StartHistoryAtWorldMap()
    wipe(self.history)
    table.insert(self.history, { label = L["world map"], worldMap = true })
end
```

### R6 · `IsPlayerInside` now calls `GetInstanceInfo()` on every call

- **Severity:** nit
- **Area:** Readability / performance
- **Where:** `NeedRoll/UI/Overview.lua:848-856`, used at `860-866` and `906`
- **Status:** fixed in round 2 (uncommitted): `PlayerWhereabouts()` read once per `PickFloor` / fallback loop and passed to `IsPlayerInside`

**What's wrong.** As a closure inside `PlayerFloor`, the old `Named` read `GetInstanceInfo()` and
lowercased the name once per `PlayerFloor` call. The hoisted `IsPlayerInside` repeats
`GetInstanceInfo()`, `(here or ""):lower()` and `instance.name:lower()` on every call. `PickFloor`
calls it up to twice per floor, and the fallback loop calls it for every dungeon and raid in the data.

**Why it matters.** It's small, but `PlayerFloor` runs on every window `DrawMap` (`Overview.lua:2661`,
so every wheel zoom step) and on each zone event, and the fallback path makes over 100 C calls for
one answer.

**Fix.** Read the instance once and pass it in, for example
`local function IsPlayerInside(instance, where)` with `where = { name = ..., mapID = ... }` built
once in `PlayerFloor` and `MapFloor`.

### R7 · `ns.Data:Map(instance.id)` check can't fail

- **Severity:** nit
- **Area:** Redundant code
- **Where:** `NeedRoll/UI/WorldMapOverlay.lua:106`
- **Status:** fixed in round 2 (uncommitted)

**What's wrong.**
`if not (instance and ns.Modules:IsOn(instance.category) and ns.Data:Map(instance.id)) then`.
`ns.UI.PlayerFloor` only returns instances found through `FloorsByArt` (built from the layout maps)
or through the fallback loop's `if map and IsPlayerInside(candidate)`. The debug stand-in returns
the Deadmines, which has a map. The comment repeats the condition ("and that has a map").

**Fix.** Drop the `ns.Data:Map` clause and that part of the comment.

### R8 · One object called `view`, "layer" and `CreateLayer`; a non-frame called `pane`

- **Severity:** nit
- **Area:** Readability (avoid mental mapping)
- **Where:** `NeedRoll/UI/WorldMapOverlay.lua:20` (`local view -- the map layer`), `83-98` (`CreateLayer` returns `layer`), `24` (`local pane = { levels = {} }`)
- **Status:** fixed in round 2 (uncommitted): `layer`, `newLayer`, `layerPane`

**What's wrong.** The overlay frame is `view` in the module, `layer` inside `CreateLayer`, and "the
layer" in every comment. `pane` is a plain table standing in for the window's pane, with no frame
behind it.

**Fix.** Use one name, for example `local layer` throughout, since the comments and tests already
say "layer". Call the table something like `shown` or `layerPane`, with its comment kept.

### R9 · Window above the map relies on the world map's strata being HIGH or lower (unverified for Forever)

- **Severity:** nit
- **Area:** WoW API
- **Where:** `NeedRoll/UI/MainFrame.lua:2219` (`self.frame:Raise()`); window strata `MainFrame.lua:813` (`SetFrameStrata("HIGH")`)
- **Status:** left as is: Mike to check the world map's strata in game

**What's wrong.** `ShowFromWorldMap` relies on the window drawing above the open world map.
`Raise()` only orders frames within one strata. The world map takes its strata from a game rule each
time it opens (`Blizzard_WorldMap.lua:388-391`,
`C_GameRules.GetGameRuleAsFrameStrata(Enum.GameRule.WorldMapFrameStrata)`), and its `BorderFrame`
is `HIGH` (`Blizzard_WorldMap.xml:85`).

**Why it matters.** If Forever's rule puts the map at `FULLSCREEN` or `DIALOG`, a boss click
"opens" NeedRoll underneath the map, and the player sees nothing happen.

**Evidence.** The value of Forever's game rule is not in the sources available here, so this is
inferred. The smoke stand-in has no strata order.

**Fix.** Check in game (`/dump WorldMapFrame:GetFrameStrata()` inside a dungeon). If it is above
`HIGH`, lift the window's strata while the map is open (it's NeedRoll's own frame, so no taint) and
put it back on the map's `OnHide`.

### R10 · "Open the world map" pill still hidden on Map in dungeons = Game

- **Severity:** nit
- **Area:** Readability (leftover logic)
- **Where:** `NeedRoll/UI/Overview.lua:2661`
- **Status:** fixed in round 2 (uncommitted): the `dungeonMap` clause dropped (follow-up: R13)

**What's wrong.**
`local worldMap = ns.db.dungeonMap ~= "game" and ns.UI.PlayerFloor(instance) == instance`. The
setting used to decide what M opened, which is why the pill was the way out when M opened
NeedRoll's map. Now M is the game's under both settings, so the pill's dependence on the setting
has no stated reason left. The new pill comment ("the way back to the game's map from here") doesn't
explain why Game hides it.

**Fix.** Either drop the `dungeonMap` clause, or add a comment with the reason, for example "on Game
the world map has no NeedRoll layer, so the pill's tooltip wouldn't fit".

### R11 · "Is the game's map open" written twice

- **Severity:** nit
- **Area:** Readability (one way of doing each thing)
- **Where:** `NeedRoll/UI/WorldMapOverlay.lua:113` (`WorldMapFrame and WorldMapFrame:IsShown()`), `NeedRoll/UI/MainFrame.lua:2211` (`local function GameMapOpen()`)
- **Status:** fixed in round 2 (uncommitted): `UI.GameMapOpen()` in `MainFrame.lua`, used by the overlay

**Fix.** Expose one, for example `ns.UI.GameMapOpen`, defined once and used by both files.

### R12 · While the game's zoom eases, NeedRoll's art and pins stay at the old size over the game's art at the new size

- **Severity:** should fix
- **Area:** Readability (visual behaviour introduced by the R3 fix)
- **Where:** `NeedRoll/UI/WorldMapOverlay.lua:83-85`
- **Status:** fixed in round 3 (uncommitted): `ns.UI.PlaceMapArt` re-sizes the art on every frame the canvas width changes; pins and markers wait for the full redraw once the width holds (deliberate, documented in the code comment and STYLE-GUIDE)

**What's wrong.** The R3 fix waits for the canvas width to hold for one frame before redrawing:

```lua
local width = layer.canvas:GetWidth()
if width ~= layer.drawnWidth and width == layer.lastSeenWidth then Draw() end
layer.lastSeenWidth = width
```

The layer's canvas is anchored to the game's canvas, so its rectangle follows the zoom on every
frame. Its contents don't: `PlaceTiles` gives the tiles fixed pixel sizes (`TILE * scale`), and
`PlaceOnArt` puts pins and markers at fixed offsets from the canvas's top left. The game eases each
zoom over several frames (`FrameDeltaLerp` until within 0.0001,
`MapCanvas_ScrollContainerMixin.lua:353-364`). For that time:
- **Zooming in:** NeedRoll's art covers only the top-left part of a canvas that has grown, and the
  game's own art (the same image at the new scale) shows beside it.
- **Zooming out:** NeedRoll's art is too large and is cut off at the canvas edge.
- **Pins and markers:** they sit on the old positions.

Everything snaps into place one frame after the ease ends. Round 1 redrew on every frame, so the
art tracked the zoom (at a cost); round 2 trades that for a visible double image on every wheel tick.

**Why it matters.** Every mouse-wheel zoom on the world map inside a dungeon shows a misaligned,
doubled floor drawing for the length of the ease (inferred to be a few tenths of a second), then a
jump. That's the first thing a player sees when they try the new map.

**Evidence.** Inferred from the code: `PlaceTiles(view.tiles, TILE * scale, view.canvas, 0, 0)` in
`ns.UI.DrawMapLevel` (`Overview.lua:2655`) and the anchors in `CreateLayer`
(`WorldMapOverlay.lua:101`). The smoke stand-in has no eased zoom, and its test sets the size in one
step (`UI-WorldMapOverlay.lua:134-139`).

**Fix.** Keep the art tracking cheaply and leave the full rebuild for when the zoom settles. Expose
a light re-place from `Overview.lua`, for example
`function ns.UI.PlaceMapArt(view, scale) PlaceTiles(view.tiles, TILE * scale, view.canvas, 0, 0) end`.
It allocates nothing and touches 12 textures. Call it on every frame the width changes, then run
the full `Draw` once the width holds. Pins and markers lagging for a few frames is acceptable. If
it isn't, hide `layer.canvas`'s pin frames while the width is changing.

### R13 · The pill now shows on Map in dungeons = Game, where its tooltip describes an overlay that isn't there

- **Severity:** nit
- **Area:** Readability (disinformation)
- **Where:** `NeedRoll/UI/Overview.lua:2678` (`local worldMap = ns.UI.PlayerFloor(instance) == instance`), tooltip at `2104-2110`
- **Status:** fixed in round 3 (uncommitted): the tooltip stops after its title on Map in dungeons = Game (`Overview.lua:2109-2110`); STYLE-GUIDE row and a smoke case updated

**What's wrong.** With R10's fix, "Open the world map" shows under the window's map whatever the
setting. Its tooltip always says: "In dungeons the game's map shows NeedRoll's map over it: click a
boss or quest to open it here, right-click for the zone. Map in dungeons in Settings ... turns that
off." On Game, that describes something the player turned off.

**Fix.** Add the second tooltip line only when `ns.db.dungeonMap ~= "game"`. The pill also becomes
visible on Game, which is a small UI change, so a line in `docs/STYLE-GUIDE.md` would cover it.

### R14 · `Recheck` hides the layer for the drawings the game lacks (Media/Maps), which `OnWorldMapShow` showed

- **Severity:** nit
- **Area:** WoW API (behaviour)
- **Where:** `NeedRoll/UI/WorldMapOverlay.lua:143-151` (`Recheck`), compared with `133-137` (`OnWorldMapShow`)
- **Status:** fixed in round 3 (uncommitted): `Recheck` keeps the floor found by name while the game's map is still `openedOnMapID` (the map it opened on), with the reason in the comment; new smoke case "a floor NeedRoll draws itself stays through a recheck"

**What's wrong.** `OnWorldMapShow` uses `ns.UI.PlayerFloor()`, which also finds floors by name "for
the drawings the game lacks" (its comment). `Recheck` only accepts what
`ns.UI.MapFloor(WorldMapFrame:GetMapID(), playerInstance)` finds through shared art files, and turns
the layer off otherwise. In an instance whose NeedRoll drawing comes from `Media/Maps`, the layer
shows when the map opens, then disappears as soon as any tab is switched or Map in dungeons is
picked again with the map open.

**Fix.** In `Recheck`, keep the `PlayerFloor` result when the game's map is still the one the layer
was opened on, for example
`if not instance and WorldMapFrame:GetMapID() == followedMapID then instance, level = playerInstance, layerPane.levels[playerInstance.id] end`.
Alternatively, record in `OnWorldMapShow` that the layer was placed by name and leave it alone in
`Recheck`.

## Area notes

### Readability

I checked each changed function against `docs/READABLE-CODE.md`. Names use game terms throughout
(`PlayerMapToShow`, `FollowGameMap`, `followedMapID`, `IsPlayerInside`, `PickFloor`, `candidate`
replacing the shadowed `instance` in the fallback loop). No one-letter names outside the allowed
aliases. Guard clauses are used, and nesting stays at three levels or fewer. Comments explain the
reason (taint from changing the map, `SetPassThroughButtons` blocked in combat, the map loading
after NeedRoll), with no change narration. The comments on removed code were updated in
`MainFrame.lua`, `Init.lua`, `Settings.lua`, the README and the test headers. A grep for "map key",
`UpdateMapKey`, `NeedRollMapKey` and `TOGGLEWORLDMAP` finds only accurate leftovers (test
stand-ins and assertions that NeedRoll doesn't take M). Every addon file starts with
`local _, ns = ...`. Indentation is 4 spaces with LF endings. No Lua 5.1 traps: no
`cond and nil or x`, no `#` on holed tables, and the only string pattern in the diff is the
existing `GameMapButton` path split. The reordering in `DrawMap` (pins and spots now drawn before
`SetFloor`, `MapEdit:ShowBosses` and `OpenFloorsWing`) is safe: none of those three writes anything
`DrawSpots` or `DrawPins` reads (`MapEdit.lua:1146-1171`, `Overview.lua:1950-1963`).

### WoW API

Taint. These were the main concern, and I checked each design decision:
- **Hooks.** The overlay only uses `HookScript` on `WorldMapFrame` (`OnShow`/`OnHide`), which runs
  after the game's handler and leaves it secure.
- **Map reads.** `WorldMapFrame:GetMapID()` and `GetCanvas()` are read-only mixin methods
  (`Blizzard_MapCanvas.lua:77-82`, `758-760`). `GetMapID` falls back to
  `MapUtil.GetDisplayableMapForPlayer()` without writing `self.mapID`.
- **No map-changing paths.** No overlay widget calls `SetMapID`, `OpenWorldMap`, `ShowUIPanel` or
  `ShowOnMap`. Entrances and locks are tooltip-only (`NewMapMark`); bosses and quests go to
  `ShowFromWorldMap`; level links and zone icons stay inside NeedRoll.
- **Frames on the game's map.** The layer is a child of `ScrollContainer`. The game's map code
  never walks that frame's children (no `GetChildren` in `Blizzard_MapCanvas/*.lua`). NeedRoll's
  frames are anchored to the game's canvas, not the other way round, so nothing of the game's
  depends on an addon frame.
- **Clicks.** Opening the window from a click doesn't touch the map, and `UI:OpenWorldMap` now
  returns early when the map is open.
- **Existing taint path, unchanged.** Window links that pin an NPC (`ShowOnMap`, `Overview.lua:582`)
  still call `OpenWorldMap(map)` through `WithGameMap`. With the map now usually open under the
  window, that is a `SetMapID` from addon code on an open map. This path isn't new and is the known,
  documented `WithGameMap` exception, so it isn't a finding here.
- **`EventRegistry` as an option.** Blizzard fires `EventRegistry:TriggerEvent("MapCanvas.MapSet", mapID)`
  (`MapCanvas_ScrollContainerMixin.lua:460`), and `CallbackRegistry` dispatches through
  `secureexecuterange`. That would be a taint-safe event in place of polling the map ID; polling is
  fine too.

Frame levels. The game's art draws in `MapCanvasDetailLayerTemplate` frames with
`useParentLevel="true"` (`Blizzard_MapCanvas.xml:7`), so at the canvas's level. NeedRoll's art sits
on its canvas at +3, which puts it above the game's art. The game's pins start at 2000
(`MapCanvas_PinFrameLevelsManager.lua:3`), so they stay above NeedRoll's highest frame (the zone
badge at about +42). Inferred: if Forever has the Encounter Journal provider
(`Blizzard_WorldMap.lua:239-241`) or map-link pins on dungeon floors, those draw on top of
NeedRoll's art too, possibly duplicating boss pins or arrows.

Zoom and pan. The game zooms by `self.Child:SetScale` (`MapCanvas_ScrollContainerMixin.lua:364`). An
unscaled frame anchored with `SetAllPoints` to the scaled canvas gets the canvas's on-screen size,
which is what `ArtScale` reads. That matches the design, with the cost noted in R3.

`SetPassThroughButtons`. It's listed in Ketho's `forever` WidgetAPI. The game calls it on its own
pins with no combat guard (`MapCanvas_DataProviderBase.lua:288-300`), but that code runs secure.
Whether it is blocked for addon code in combat couldn't be confirmed (warcraft.wiki.gg and Ketho's
annotations were unreachable from this machine), so the `InCombatLockdown()` guard is a safe choice.
The smoke stand-in's error-in-combat behaviour matches that assumption.

| API | Kind | In Ketho's `forever` lists | Where checked |
| --- | --- | --- | --- |
| `C_Map.GetMapArtLayerTextures` | function | yes | `GlobalAPI.lua` |
| `GetInstanceInfo`, `IsInInstance`, `InCombatLockdown`, `C_Map.GetBestMapForUnit` | function | yes | `GlobalAPI.lua` |
| `PLAYER_LOGIN`, `ADDON_LOADED`, `PLAYER_REGEN_ENABLED`, `PORTRAITS_UPDATED` | event | yes | `Events.lua` |
| `Frame:HookScript`, `IsMouseEnabled`, `SetPassThroughButtons`, `GetChildren`, `SetClipsChildren`, `SetFrameLevel`, `GetFrameLevel`, `SetAllPoints`, `Raise` | widget method | yes | `/tmp/claude-0/WidgetAPI.lua` |
| `WorldMapFrame:GetMapID`, `WorldMapFrame:GetCanvas`, `WorldMapFrame.ScrollContainer` | FrameXML mixin / parentKey | inferred (not in the lists; standard FrameXML) | `Blizzard_MapCanvas.lua:77,758`, `Blizzard_WorldMap.xml:10` |
| `WorldMapFrame` | global frame | inferred (already used before this change, nil-guarded) | `Blizzard_WorldMap.xml:68` |

Removed calls: `SetOverrideBindingClick`, `ClearOverrideBindings`, `GetBindingKey("TOGGLEWORLDMAP")`
and `ToggleWorldMap` are no longer used by the map code. No nil guards on game APIs were removed.
No new globals (bytecode check above). `CreateOverview` gains no upvalues. Player-facing text goes
through literal `L["..."]`, and `locales.py --check` passes. The new calls are mirrored in
`tests/smoke/wow.lua`, the feature has smoke cases, and `docs/STYLE-GUIDE.md` has a row for the
overlay whose sizes match `Overview.lua:33-74` (`PIN_SIZE, PIN_PORTRAIT = 40, 29`, `MARKER_ICON = 22`,
`LINK_ICON = 22`, `LOCK_ICON = 20`, `ENTRANCE_ICON = 28`, `ART_W, ART_H = 1002, 668`). No dev-only
code was added outside `--@debug@`. Dev note: the existing debug stand-in in `PlayerFloor`
(Crystal Lake) will now draw the Deadmines over the Elwynn map in a dev checkout; that's dev only
and expected.

### Redundant code

Compared against `ns.UI.PlayerFloor`, `OpenQuestPage`/`OpenBossPage`, `UI:GoToSource`,
`UI:ClearHistory`, `UI:FollowPlayer`, `GameMapOpen` and the window's own `CreateMapView`/`DrawMap`.
The split into `CreateMapLayer` and `DrawMapLevel` removes what would otherwise have been a second
copy of the map drawing. `MapFloor` reuses `FloorsByArt` rather than scanning again. The world map
hooks moved, they weren't copied: `MainFrame.lua`'s `HookWorldMap` is gone. Leftovers: R3
(per-frame work), R5 (history built twice), R7 (dead check), R11 (map-open test twice). No unused
locals or debug prints were found in the diff.

### Security

None. The change touches no addon messages, chat, SavedVariables written by others, drop sharing,
credits, scraper, workflows or network code. It adds no `loadstring`/`RunScript`. The only text it
shows comes from NeedRoll's own data and `L[...]`.

### Round 2 notes

I re-read every changed function in full: `WorldMapOverlay.lua` whole, `MapWidget`,
`PlayerWhereabouts`/`IsPlayerInside`/`PickFloor`/`MapFloor`/`PlayerFloor`, `CreateMapLayer`,
`CreateMapView`, `DrawSpots`, `DrawMapLevel`, `DrawMap`, `UI.GameMapOpen`,
`UI:StartHistoryAtWorldMap`, `UI:ShowFromWorldMap`, `UI:OpenWorldMap` and `GameMapLink`.

- **`MapWidget` / `onNewWidget`.** Every map frame that takes the mouse now comes through it:
  boss pins, entrance and lock marks, quest markers, level links and zone-badge icons. The only
  other mouse frames on a map are the route handles (`Overview.lua:1883`), which exist only in map
  edit mode, and the overlay never shows in that mode. On the window's map `onNewWidget` is nil, so
  `MapWidget` behaves exactly like `Pooled`. The combat queue swaps in a fresh table before draining,
  so a widget queued again because combat is still on isn't lost. It holds pooled widgets, which
  live for the session anyway, so it can't grow beyond the pool sizes.
- **`droppedUntilReopen`.** Set only by `FollowGameMap` leaving the floors, cleared by
  `OnWorldMapShow`. The `OnHide` hook's `TurnOff()` also clears it, which is harmless.
  `Recheck` returns before touching anything while it is set. Right-click, then a tab switch, keeps
  the layer off (smoke-tested).
- **Zoom settle.** Correct, and it ends the per-frame rebuild, but it causes R12.
- **`UI.GameMapOpen`.** One definition, used by `OpenWorldMap`, `GameMapLink` and the overlay.
- **`StartHistoryAtWorldMap`.** One copy of the world-map Back step. `FollowPlayer` still calls
  `ClearHistory()` first (the history is wiped twice), which is harmless because `ClearHistory` also
  resets the search state.
- **Taint.** Nothing new touches the game's map: still only `HookScript`, `GetMapID` and
  `GetCanvas`, and frames of NeedRoll's own.

### Round 3 notes

I re-read `WorldMapOverlay.lua` in full, plus `ns.UI.PlaceMapArt`, `ns.UI.DrawMapLevel`, the pill's
`OnEnter` in `CreateMapView` and the new smoke cases.

- **R12.** `FollowGameMap` now re-places the art (12 tile textures, no tables) on each frame the
  canvas width changes, and runs the full `Draw` on the first frame the width holds. Edge cases
  checked:
  - Before the canvas has a size, `ArtScale(0, 0)` is 0, so the tiles are sized 0 for a frame. Harmless.
  - A width left over from an earlier opening is harmless, since `ShowLayer` draws as the layer shows.
  - A map change still takes the first branch and redraws in full.
- **R13.** The early `return GameTooltip:Show()` keeps the title line only. Nothing else in that
  handler is skipped.
- **R14.** The fallback only applies when shared art finds nothing and the game's map is still the
  map it opened on, which is the player's map. Any other map still turns the layer off, and a drop
  (`droppedUntilReopen`) still wins. Comparing against `openedOnMapID` rather than `followedMapID`
  is correct: `followedMapID` would also match a floor the player picked that NeedRoll can't place.
- **Taint.** Unchanged: the game's map is only read (`GetMapID`, `GetCanvas`, `GetSize` on
  NeedRoll's own canvas). The new code adds no globals, events or game calls.

Nothing new found. Two items are left for Mike:
- **R4:** quest markers on the window's map now add a Back step, kept on purpose. It needs a line in
  the PR description.
- **R9:** check `/dump WorldMapFrame:GetFrameStrata()` inside a dungeon. If the strata is above
  `HIGH`, a boss click opens the window under the map.

## Round history

- 2026-10-18, round 1, `32c7b40` + uncommitted: **Changes needed**. Opened R1 to R11 (4 should fix, 7 nits).
- 2026-10-18, round 2, `32c7b40` + uncommitted: **Changes needed**. Closed R1, R2, R3, R5, R6, R7, R8, R10, R11. R4 and R9 left as is (reasons above). Opened R12 (should fix), R13 and R14 (nits).
- 2026-10-18, round 3, `32c7b40` + uncommitted: **Ready**. Closed R12, R13, R14. No new findings. R4 and R9 left for Mike.
