-- Dev edit mode (/nr devedit), for fixing the data in the game.
--
-- Maps: drag the layout map's boss pins, entrance swirls and level links
-- into place, or place new ones from a palette (its boss buttons are the
-- bosses of the instance on show, its unit buttons the other creatures
-- Data/DevDungeons.lua lists for it; any creature can be placed by its unit
-- ID). Text and icon sizes are /nr fontdebug's (UI/FrameDebug.lua); /nr
-- devexport lists them with the rest.
-- Quests: pick the portal, then click a quest in the Quests list to mark it
-- as starting inside the dungeon; alt-right-click a quest to take its
-- portal off. Quest markers (an item to loot, a mob, a vendor, the turn-in,
-- an escort): place one, then right-click it to pick its quest. Click one,
-- then a boss pin, to put it on that boss's pin (boss = its key: it moves
-- with the pin), or another marker, to put it on that one's corner (on =
-- true: it sits at the same spot and moves with it); click it, then the
-- map, or drag it, to take it off. The area tool, then a marker: an area
-- around it (area = { x1, y1, ... }, a closed outline like a patrol loop,
-- its points dragged the same way) that lights up while the marker is
-- hovered, e.g. where its item drops. /nr devexport copies everything out
-- as Lua for Data/Maps.lua, Data/Outlines.lua and Data/QuestStarts.lua.
-- Drawing: a patrol tool, then a boss or unit pin (or the area tool, then a
-- marker), then a drag on the map draws its route (or area) under the
-- mouse; the outline tool's drag draws a new shape. What is picked shows on
-- the palette and by the cursor; right-click on the map or Escape lets go.
--
-- Map edits live in NeedRollDB.mapEdit[instance id], a copy of the map's
-- spots made the first time edit mode draws that map; quest marks in
-- NeedRollDB.questEdit[instance id][quest id]; zone-wide quests in
-- zoneEdit[instance id] (a list) and outlines in outlineEdit[instance
-- id][level]. All are drawn in place of the data until /nr devedit reset.
local _, ns = ...
local Theme = ns.Theme

-- lastQuest: per instance, the quest a new marker there starts with. Set
-- while editing: tool (the palette's pick), linking (a marker picked to put
-- on something), drawFor (the pin or marker a drag on the map draws the
-- route or area of) and stroke (that drag, while the button is held).
local MapEdit = { on = false, available = false, lastQuest = {} }
ns.MapEdit = MapEdit

-- Edit mode is for local checkouts only. The CurseForge packager turns the
-- debug block below into a comment, so released builds never offer it,
-- ignore any saved edits and draw the maps from the data.
--[==[@debug@
MapEdit.available = true
--@end-debug@]==]

-- The palette's tools: { name, atlas } or { name, texture path, texture =
-- true }, and the tooltip title (the name when there is none).
local TOOLS = {
    { "up", "poi-door-arrow-up" },
    { "down", "poi-door-arrow-down" },
    { "door", "poi-door" },
    { "door-up", "poi-door-up" },
    { "door-down", "poi-door-down" },
    { "door-left", "poi-door-left" },
    { "door-right", "poi-door-right" },
    { "entrance", "Dungeon", title = "Entrance" },
    { "raid", "Raid", title = "Raid entrance" },  -- inside a dungeon (Blackwing Lair in UBRS)
    { "lock", "Interface\\LFGFrame\\UI-LFG-ICON-LOCK", texture = true, title = "Locked door" },
    -- Patrol routes: pick one, then click a boss or unit icon.
    { "patrol-loop", "Interface\\Buttons\\UI-RefreshButton", texture = true, title = "Patrol: loop" },
    { "patrol-line", "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", texture = true,
        title = "Patrol: back and forth" },
    -- A quest marker's area: pick, then click a marker.
    { "area", "Interface\\Icons\\INV_Misc_Map_01", texture = true, title = "Marker area" },
    -- A map level's walkable-area outline: pick, then click the map for a
    -- new shape there; its points drag like a patrol's.
    { "outline", "Interface\\Icons\\INV_Misc_Map02", texture = true, title = "Walkable-area outline" },
    -- Zone-wide quests (kills or drops anywhere in the dungeon): pick, then
    -- click a quest in the Quests list.
    { "zone:attack", "Crosshair_Attack_96", title = "Zone-wide quest: kill" },
    { "zone:loot", "Crosshair_lootall_96", title = "Zone-wide quest: drop" },
}
-- Quest markers: "marker:" and their name in Data/Data.lua's markerIcons.
local MARKER_TITLES = { attack = "Kill", buy = "Buy", quest = "Quest", turnin = "Turn in",
    repair = "Repair", escort = "Escort" }
for _, kind in ipairs(ns.Data.markerOrder) do
    table.insert(TOOLS, { "marker:" .. kind, ns.Data.markerIcons[kind], title = MARKER_TITLES[kind] })
end
-- Shift-right-click on a level link steps through these icons.
local LINK_ICONS = { "up", "down", "door", "door-up", "door-down", "door-left", "door-right" }

-- The help lines under a tool's tooltip title, by its kind (ToolKind).
local PLACE_HELP = { "Pick, then click the map to place it" }
local TOOL_HELP = {
    outline = {
        "Pick, then click the map to add a shape to this level's",
        "walkable area (lit when a zone-wide quest is hovered),",
        "or drag on the map to draw one",
        "Drag its points; right-click one to add a point, alt-right-click",
        "to remove it, shift-right-click to remove the whole shape",
    },
    zone = {
        "Pick, then click a quest in the Quests list to make it",
        "zone-wide (on the map's corner badge); again to take it off",
    },
    area = {
        "Pick, then click a quest marker to give it an area",
        "(where its item drops); it lights up while the marker is hovered",
        "Then drag on the map to draw the area in its place",
        "Drag its points; right-click one to add a point, alt-right-click to remove",
    },
    patrol = {
        "Pick, then click a boss or unit icon to give it this route",
        "(click it again to take the route off)",
        "Then drag on the map to draw the route in its place",
    },
    marker = {
        "Quest marker: pick, then click the map to place it",
        "Right-click it on the map to pick its quest",
    },
}

-- What a click on the map with a tool that works on something else says.
local MAP_CLICK_HINTS = {
    patrol = "Patrol: click a boss or unit icon to give it the route.",
    area = "Area: click a quest marker to give it an area (or take its area off).",
    zone = "Zone-wide: click a quest in the Quests list (again to take it off).",
}

-- Palette sizes in pixels: tool buttons in rows of four, then boss buttons.
local TOOL_BUTTON, TOOL_COLUMN, TOOL_ROW, TOOLS_PER_ROW = 44, 52, 50, 4
local BOSS_BUTTON, BOSS_PER_ROW = 34, 6
local BOSS_TOP = 34 + math.ceil(#TOOLS / TOOLS_PER_ROW) * TOOL_ROW  -- the Bosses label, under the tools
local FOOTER_HEIGHT = 64  -- the picked line, then the Export and Done buttons
local UNIT_TRIES = 10  -- half-second looks while the client fetches a creature it hasn't seen
-- A drawn route keeps a point each time the mouse has moved this far (UI
-- units on the map, so zooming in draws finer), not one a frame.
local STROKE_SPACING = 24
local PICKED_GOLD = { 1, 0.82, 0, 1 }  -- the game's gold: the picked button's edge and the picked line
local CUE_OFFSET = 16                  -- the cue's corner, right of and below the cursor

-- A tool's family, the letters before any dash or colon ("patrol", "zone").
local function ToolKind(tool)
    return tool and tool:match("^%a+")
end

-- A map coordinate as Data/Maps.lua keeps it: 0 to 1, three decimals.
local function RoundCoord(coord)
    return math.floor(math.max(0, math.min(1, coord)) * 1000 + 0.5) / 1000
end

local function IndexOf(list, value)
    for i, item in ipairs(list or {}) do
        if item == value then return i end
    end
end

local function Remove(list, value)
    local index = IndexOf(list, value)
    if index then table.remove(list, index) return true end
end

-- The entry after `current` in `list`; the first after the last or when it isn't in it.
local function NextInList(list, current)
    return list[(IndexOf(list, current) or 0) % #list + 1]
end

local function SortedKeys(map)
    local keys = {}
    for key in pairs(map or {}) do table.insert(keys, key) end
    table.sort(keys)
    return keys
end

-- Adds eight points round x, y to `points` and returns it: a starter loop
-- to drag into shape. The map art is 1.5 times as wide as it is tall, so a
-- half-height 1.5 times the half-width looks round on screen.
local function AddLoopPoints(points, x, y, halfWidth, halfHeight)
    for i = 0, 7 do
        local angle = i / 8 * 2 * math.pi
        table.insert(points, RoundCoord(x + halfWidth * math.cos(angle)))
        table.insert(points, RoundCoord(y + halfHeight * math.sin(angle)))
    end
    return points
end

-- Which boss is pinned on which level in the data, to tell when that
-- changed after a copy was made.
local function PinLevels(map)
    local parts = {}
    for level = 1, #map do
        for _, pin in ipairs(map[level].pins or {}) do table.insert(parts, level .. ":" .. pin[1]) end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

-- A marker's identity across copies: its level, icon, quest and boss.
local function MarkerKey(marker)
    return table.concat({ marker[1] or "", marker[4] or "", marker[5] or "", marker.boss or "" }, ":")
end

-- Markers added to the data after the copy was made (Shadowfang Keep's
-- Darksoul drop area) join it; ones removed in edit mode stay removed.
-- `dataMarkers` holds the data's markers as of the last merge; a copy from
-- before it was kept counts its own markers as those.
local function MergeMarkers(saved, map)
    local known = saved.dataMarkers
    if not known then
        known = {}
        for _, marker in ipairs(saved.markers) do known[MarkerKey(marker)] = true end
    end
    local inData = {}
    for _, marker in ipairs(map.markers or {}) do
        local key = MarkerKey(marker)
        inData[key] = true
        if not known[key] then table.insert(saved.markers, CopyTable(marker)) end
    end
    saved.dataMarkers = inData
end

-- The copy's pins rebuilt from the data, keeping each boss's dragged spot
-- where it is still on the same level, the pins placed from the palette
-- (added) and leaving out the ones removed in edit mode.
local function MergePins(saved, map)
    local removed = saved.removed or {}
    local pins = {}
    for level = 1, #map do
        local savedPins = saved.pins[level] or {}
        local savedByKey = {}
        for _, pin in ipairs(savedPins) do savedByKey[pin[1]] = pin end
        local merged, inData = {}, {}
        for _, pin in ipairs(map[level].pins or {}) do
            if not removed[level .. ":" .. pin[1]] then
                local copy = CopyTable(pin)
                local dragged = savedByKey[pin[1]]
                if dragged then copy[2], copy[3] = dragged[2], dragged[3] end
                table.insert(merged, copy)
                inData[pin[1]] = true
            end
        end
        for _, pin in ipairs(savedPins) do
            -- A boss placed here that the data now pins too keeps the data's
            -- pin (at the spot it was placed).
            if pin.added and not inData[pin[1]] then table.insert(merged, pin) end
        end
        pins[level] = merged
    end
    saved.pins = pins
end

local function CopyNewPatrols(saved, map)
    for level = 1, #map do
        local dataPins = {}
        for _, pin in ipairs(map[level].pins or {}) do dataPins[pin[1]] = pin end
        for _, pin in ipairs(saved.pins[level] or {}) do
            local dataPin = dataPins[pin[1]]
            if not pin.patrol and dataPin and dataPin.patrol then pin.patrol = CopyTable(dataPin.patrol) end
        end
    end
end

-- The edited copy of a map's spots, or nil when it hasn't been edited (in
-- edit mode one is made from the data).
-- A copy made before the map's levels changed (Upper Blackrock Spire went
-- from seven to three) no longer fits it and is dropped; one made before
-- the data changed takes its new markers, pin levels and patrols.
function MapEdit:Spots(id, map)
    if not self.available then return nil end
    local saved = ns.db and ns.db.mapEdit and ns.db.mapEdit[id]
    if saved and #saved.links ~= #map then
        ns.db.mapEdit[id], saved = nil, nil
    end
    if saved then
        saved.locks = saved.locks or {}
        saved.markers = saved.markers or CopyTable(map.markers or {})
        MergeMarkers(saved, map)
        local pinLevels = PinLevels(map)
        if saved.pinLevels ~= pinLevels then
            MergePins(saved, map)
            saved.pinLevels = pinLevels
        end
        CopyNewPatrols(saved, map)
        return saved
    end
    if not self.on then return nil end
    saved = { entrances = CopyTable(map.entrances or {}), locks = CopyTable(map.locks or {}),
        markers = CopyTable(map.markers or {}), links = {}, pins = {}, pinLevels = PinLevels(map) }
    for level = 1, #map do
        saved.links[level] = CopyTable(map[level].links or {})
        saved.pins[level] = CopyTable(map[level].pins or {})
    end
    ns.db.mapEdit = ns.db.mapEdit or {}
    ns.db.mapEdit[id] = saved
    return saved
end

local function OverviewPane()
    return ns.UI and ns.UI.overview
end

local function Redraw()
    local pane = OverviewPane()
    if pane and pane:IsVisible() then pane:Refresh() end
end

-- The instance and level the map shows, with its edited spots.
local function ShownMap()
    local pane = OverviewPane()
    local instance = pane and pane.instance
    local map = instance and ns.Data:Map(instance.id)
    if not map or not pane.showMap then return end
    local level = math.min(#map, pane.levels[instance.id] or map.start or 1)
    return instance, map, level, MapEdit:Spots(instance.id, map)
end

-- The markers put on a marker (on = true, at its old spot on the level on
-- show) follow it to its new spot.
local function MoveMarkersOn(oldX, oldY, host)
    local _, _, level, spots = ShownMap()
    for _, marker in ipairs(spots and spots.markers or {}) do
        if marker.on and marker[1] == level and marker[2] == oldX and marker[3] == oldY then
            marker[2], marker[3] = host[2], host[3]
        end
    end
end

-- Lets a pin, swirl or link be dragged in edit mode; it writes its new
-- spot (frame.spot, x and y in fields 2 and 3) when dropped.
function MapEdit:Draggable(frame, canvas)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(handle)
        if not self.on or not handle.spot then return end
        GameTooltip:Hide()
        handle:StartMoving()
        handle.moving = true
    end)
    frame:SetScript("OnDragStop", function(handle)
        if not handle.moving then return end
        handle.moving = nil
        handle:StopMovingOrSizing()
        handle:SetUserPlaced(false)
        local x, y = handle:GetCenter()
        local scale = handle:GetEffectiveScale() / canvas:GetEffectiveScale()
        x, y = x * scale, y * scale
        local spot = handle.spot
        local oldX, oldY = spot[2], spot[3]
        spot[2] = RoundCoord((x - canvas:GetLeft()) / canvas:GetWidth())
        spot[3] = RoundCoord((canvas:GetTop() - y) / canvas:GetHeight())
        if handle.isMarker and not spot.on then MoveMarkersOn(oldX, oldY, spot) end
        spot.boss, spot.on = nil, nil  -- a marker dragged off what it was on
        if self.linking == spot then self:SetLinking(nil) end
        Redraw()
    end)
end

-- The marker picked to put on a pin or another marker (nil: none), shown
-- on the palette and by the cursor.
function MapEdit:SetLinking(marker)
    self.linking = marker
    self:UpdatePalette()
end

-- A patrol tool, then a boss or unit pin: a starter loop around it or line
-- through it (open = true: walked back and forth). A route of the other
-- kind switches to this one; one of this kind is taken off.
local function SetPatrol(pin, tool)
    local isLine = tool == "patrol-line" or nil
    local route = pin.patrol
    if route then
        if (route.open or nil) == isLine then
            pin.patrol = nil
        else
            route.open = isLine
        end
        return
    end
    route = { open = isLine }
    local x, y = pin[2], pin[3]
    if isLine then
        for step = -1, 1 do
            table.insert(route, RoundCoord(x + step * 0.06))
            table.insert(route, RoundCoord(y))
        end
    else
        AddLoopPoints(route, x, y, 0.04, 0.06)
    end
    pin.patrol = route
end

-- A left press on a quest marker picks it; then one on a boss pin puts it
-- on that boss. On the press, not the click: a click that wobbles the
-- mouse starts a drag and never arrives (a marker dragged is let go).
function MapEdit:Press(frame, button)
    if not self.on or button ~= "LeftButton" or not frame.spot then return end
    if ToolKind(self.tool) == "patrol" then return end
    local _, _, level, spots = ShownMap()
    if not spots then return end
    local spot, picked = frame.spot, self.linking
    if self.tool == "area" then
        -- The area tool on a marker: a starter area around it, or its own
        -- taken off; a drag on the map then draws its area.
        if not frame.isMarker then return end
        if spot.area then
            spot.area = nil
        else
            spot.area = AddLoopPoints({ area = true }, spot[2], spot[3], 0.05, 0.075)
        end
        self.drawFor = spot
        self:UpdatePalette()
        Redraw()
    elseif frame.isMarker and picked == spot then
        self:SetLinking(nil)
        ns:Print("Marker let go.")
    elseif frame.isMarker and picked then
        -- On another marker (a vendor, an escort...): at its spot, on = true,
        -- moving with it.
        picked.boss, picked.on = nil, true
        picked[1], picked[2], picked[3] = spot[1], spot[2], spot[3]
        self:SetLinking(nil)
        ns:Print("Marker put on that marker.")
        Redraw()
    elseif frame.isMarker then
        self:SetLinking(spot)
        ns:Print("Marker picked: click a boss pin or another marker to put it on, the map to take it off, "
            .. "or it again to let go.")
    elseif picked and IndexOf(spots.pins[level], spot) then
        -- On the boss's pin; its own spot follows the boss's for the export.
        picked.on = nil
        picked.boss, picked[1], picked[2], picked[3] = spot[1], level, spot[2], spot[3]
        self:SetLinking(nil)
        ns:Print(("Marker put on %s."):format(spot[1]))
        Redraw()
    end
end

-- Alt-right-click takes a spot off the map. A boss pin from the data is
-- noted as removed, so it stays out when the data's pins change.
local function RemoveSpot(spots, level, spot)
    if Remove(spots.pins[level], spot) then
        if spot.added then return end
        spots.removed = spots.removed or {}
        spots.removed[level .. ":" .. spot[1]] = true
        return
    end
    local lists = { spots.links[level] or {}, spots.entrances or {}, spots.locks or {}, spots.markers or {} }
    for _, list in ipairs(lists) do
        if Remove(list, spot) then return end
    end
end

-- With a patrol tool picked, a left click on a boss or unit pin gives it
-- that route, and a drag on the map then draws it. Right-click on a link:
-- next level it leads to; on a quest marker: pick its quest.
-- Shift-right-click on either: next icon.
-- Alt-right-click removes a link, marker, swirl, lock or boss pin.
function MapEdit:Click(frame, button)
    local spot = frame.spot
    if not spot then return end
    local instance, map, level, spots = ShownMap()
    if not spots then return end
    if button == "LeftButton" and ToolKind(self.tool) == "patrol" then
        if IndexOf(spots.pins[level], spot) then
            SetPatrol(spot, self.tool)
            self.drawFor = spot
            self:UpdatePalette()
            Redraw()
        end
        return
    end
    if button ~= "RightButton" then return end
    if IsAltKeyDown() then
        RemoveSpot(spots, level, spot)
    elseif frame.isMarker and IsShiftKeyDown() then
        spot[4] = NextInList(ns.Data.markerOrder, spot[4])
    elseif frame.isMarker then
        return self:QuestMenu(frame, instance)
    elseif frame.isLink and IsShiftKeyDown() then
        spot[4] = NextInList(LINK_ICONS, spot[4])
    elseif frame.isLink and #map > 1 then
        local target = spot[1] % #map + 1
        if target == level then target = target % #map + 1 end
        spot[1] = target
        ns:Print(("Link now leads to level %d."):format(target))
    end
    Redraw()
end

-- A boss's pin look for a new pin: its pin elsewhere in the data, its
-- portrait in Data/Bosses.lua, or its own display.
local function BossLook(instance, map, encounter)
    for level = 1, #map do
        for _, pin in ipairs(map[level].pins or {}) do
            if pin[1] == encounter.id and pin[4] then return pin[4] end
        end
    end
    local bosses = ns.Data:Bosses(instance, encounter)
    return bosses and bosses[1] and bosses[1][2] or encounter.display
end

-- Moves the pin with this key in `pins` to x, y; true when it was there.
-- The pin list for one level, made empty the first time a pin goes there.
local function LevelPins(spots, level)
    spots.pins[level] = spots.pins[level] or {}
    return spots.pins[level]
end

local function MovePin(pins, key, x, y)
    for _, pin in ipairs(pins) do
        if pin[1] == key then
            pin[2], pin[3] = x, y
            return true
        end
    end
end

-- A click on the map with a palette tool picked places that tool there.
-- Returns true when the click was the editor's (placed, or only a hint).
function MapEdit:Place(x, y)
    if not self.on then return end
    local instance, map, level, spots = ShownMap()
    if not spots then return end
    x, y = RoundCoord(x), RoundCoord(y)
    local tool = self.tool
    if self.linking then
        -- A picked marker, then the map: off its boss, here.
        local marker = self.linking
        marker.boss, marker.on, marker[1], marker[2], marker[3] = nil, nil, level, x, y
        self:SetLinking(nil)
        Redraw()
        return true
    end
    if not tool then return end
    local hint = MAP_CLICK_HINTS[ToolKind(tool)]
    if hint then
        ns:Print(hint)
        return true
    end
    local boss = tool:match("^boss:(.+)")
    local markerKind = tool:match("^marker:(.+)")
    if tool == "outline" then
        local outlines = self:Outlines(instance.id, true)
        outlines[level] = outlines[level] or {}
        table.insert(outlines[level], AddLoopPoints({}, x, y, 0.06, 0.09))
    elseif tool == "unit" then
        local unit = self.unit
        if not (unit and unit.display) then return end
        local key = "NPC_" .. unit.npc
        local pins = LevelPins(spots, level)
        if not MovePin(pins, key, x, y) then
            table.insert(pins, { key, x, y, unit.display, npc = unit.npc, name = unit.name, added = true })
        end
    elseif boss then
        -- A boss already on this level moves here; otherwise it's added.
        local pins = LevelPins(spots, level)
        if not MovePin(pins, boss, x, y) then
            local encounter = self.bossEncounters and self.bossEncounters[boss]
            table.insert(pins, { boss, x, y, encounter and BossLook(instance, map, encounter), added = true })
            if spots.removed then spots.removed[level .. ":" .. boss] = nil end
        end
    elseif markerKind then
        -- Takes the quest the last marker here was given; right-click it to
        -- pick another.
        table.insert(spots.markers, { level, x, y, markerKind, self.lastQuest[instance.id] })
    elseif tool == "entrance" then
        table.insert(spots.entrances, { level, x, y })
    elseif tool == "raid" then
        table.insert(spots.entrances, { level, x, y, "raid" })
    elseif tool == "lock" then
        table.insert(spots.locks, { level, x, y })
    else
        -- A level link. It leads to the next level (the one before from the
        -- last); right-click it to change that.
        local target = level < #map and level + 1 or math.max(1, level - 1)
        spots.links[level] = spots.links[level] or {}
        table.insert(spots.links[level], { target, x, y, tool })
    end
    Redraw()
    return true
end

-- Drawing with the mouse. A drag on the map with a patrol, area or outline
-- tool lays a route under the cursor, a point each STROKE_SPACING, in the
-- shape the data keeps: patrol = { open = true or nil, x1, y1, ... }, area
-- = { area = true, x1, y1, ... } and an outline shape { x1, y1, ... }. The
-- new route goes in place as the drag starts, so the map draws it as it
-- grows; a drag too short to make one puts back what was there.

-- The fewest points a drawn route keeps: a back-and-forth line needs its
-- two ends, a loop, area or outline three corners.
local function FewestPoints(route)
    return route.open and 2 or 3
end

-- Each drawing tool's new route: it puts an empty one in place and returns
-- it with a function that puts back what was there, or prints what to do
-- first and returns nil.
local function StartPatrolRoute(tool, _, level, spots)
    local pin = MapEdit.drawFor
    if not IndexOf(spots.pins[level], pin) then
        ns:Print("Patrol: click a boss or unit icon on this level first, then drag on the map to draw its route.")
        return
    end
    local before = pin.patrol
    pin.patrol = { open = tool == "patrol-line" or nil }
    return pin.patrol, function() pin.patrol = before end
end

local function StartArea(_, _, level, spots)
    local marker = MapEdit.drawFor
    if not (IndexOf(spots.markers, marker) and marker[1] == level) then
        ns:Print("Area: click a quest marker on this level first, then drag on the map to draw its area.")
        return
    end
    local before = marker.area
    marker.area = { area = true }
    return marker.area, function() marker.area = before end
end

local function StartOutline(_, instance, level)
    local outlines = MapEdit:Outlines(instance.id, true)
    outlines[level] = outlines[level] or {}
    local shapes, shape = outlines[level], {}
    table.insert(shapes, shape)
    return shape, function() Remove(shapes, shape) end
end

local START_ROUTE = { patrol = StartPatrolRoute, area = StartArea, outline = StartOutline }

-- Adds the cursor's spot to the stroke's route when it is at least
-- `spacing` (UI units on the map) from the last point; true when it did.
local function AddStrokePoint(stroke, spacing)
    local route, canvas = stroke.route, stroke.canvas
    local x, y = ns.UI.CursorOnCanvas(canvas)
    x, y = RoundCoord(x), RoundCoord(y)
    local count = #route
    if count > 0 then
        local across = (x - route[count - 1]) * canvas:GetWidth()
        local down = (y - route[count]) * canvas:GetHeight()
        local moved = math.sqrt(across * across + down * down)
        if moved < spacing then return false end
    end
    table.insert(route, x)
    table.insert(route, y)
    return true
end

-- Every frame while the button is held: a new point once the mouse has
-- moved far enough, and the map drawn again with it.
local function FollowStroke()
    local stroke = MapEdit.stroke
    if not stroke then return end
    if not stroke.canvas:IsVisible() then return MapEdit:CancelStroke() end
    if AddStrokePoint(stroke, STROKE_SPACING) then Redraw() end
end

-- The map's OnDragStart (UI/Overview.lua): with a drawing tool picked the
-- drag draws instead of moving the zoomed map. True when it was ours.
function MapEdit:StartStroke(canvas)
    local startRoute = self.on and START_ROUTE[ToolKind(self.tool)]
    if not startRoute then return false end
    local instance, _, level, spots = ShownMap()
    if not spots then return true end
    local route, putBack = startRoute(self.tool, instance, level, spots)
    if not route then return true end
    self.stroke = { canvas = canvas, route = route, putBack = putBack }
    AddStrokePoint(self.stroke, 0)
    self.palette.strokeDriver:Show()
    Redraw()
    return true
end

local function StopStroke()
    MapEdit.stroke = nil
    MapEdit.palette.strokeDriver:Hide()
    Redraw()
end

-- The drag's last spot: a point of its own, or, too near the last point
-- for that, the last point moved onto it, so the route ends where the drag did.
local function EndAtCursor(stroke)
    local route = stroke.route
    if AddStrokePoint(stroke, STROKE_SPACING / 2) or #route < 4 then return end
    local x, y = ns.UI.CursorOnCanvas(stroke.canvas)
    route[#route - 1], route[#route] = RoundCoord(x), RoundCoord(y)
end

-- The map's OnDragStop: the route ends where the drag did; one too short to
-- be a route puts back what was there.
function MapEdit:EndStroke()
    local stroke = self.stroke
    if not stroke then return end
    EndAtCursor(stroke)
    local pointCount = #stroke.route / 2
    if pointCount < FewestPoints(stroke.route) then
        ns:Print("Too short to draw: hold the button down and drag further.")
        return self:CancelStroke()
    end
    StopStroke()
    ns:Print(("Drawn with %d points."):format(pointCount))
end

function MapEdit:CancelStroke()
    local stroke = self.stroke
    if not stroke then return end
    stroke.putBack()
    StopStroke()
end

-- Nothing picked: no tool, marker or pin to draw for, and no drag.
function MapEdit:LetGo()
    self:CancelStroke()
    self.tool, self.linking, self.drawFor = nil, nil, nil
    self:UpdatePalette()
end

-- Right-click on the map or Escape: one step back. A drag being drawn is
-- dropped; otherwise whatever is picked is let go. True when there was
-- something to drop.
function MapEdit:Cancel()
    if self.stroke then
        self:CancelStroke()
        return true
    end
    if not (self.tool or self.linking) then return false end
    self:LetGo()
    return true
end

local function QuestLabel(quest)
    local side = quest.side and (" (" .. quest.side .. ")") or ""
    return ("%s%s  [%d]"):format(quest.name, side, quest.id)
end

function MapEdit:QuestMenu(frame, instance)
    local marker, quests = frame.spot, ns.Data:Quests(instance.id)
    local function SetQuest(id)
        marker[5] = id
        self.lastQuest[instance.id] = id
        local quest = ns.Data:DungeonQuest(instance.id, id)
        ns:Print(("Marker now points at %s."):format(quest and QuestLabel(quest) or "no quest"))
        Redraw()
    end
    MenuUtil.CreateContextMenu(frame, function(_, root)
        if root.SetScrollMode then root:SetScrollMode(480) end
        root:CreateTitle(#quests > 0 and "Points at" or "No quests known here")
        root:CreateRadio("No quest", function() return marker[5] == nil end, function() SetQuest(nil) end)
        for _, quest in ipairs(quests) do
            root:CreateRadio(QuestLabel(quest), function() return marker[5] == quest.id end,
                function() SetQuest(quest.id) end)
        end
    end)
end

-- A quest's mark (true: starts inside, false: doesn't), or nil when it
-- isn't marked. Marks show while dev edit is on or off, until reset.
function MapEdit:QuestMark(id, quest)
    if not self.available then return nil end
    local marks = ns.db and ns.db.questEdit and ns.db.questEdit[id]
    if marks then return marks[quest] end
end

-- What the data says without a mark: Data/QuestStarts.lua, else the scrape.
local function QuestInData(instance, quest)
    local kept = ns.Data:QuestStart(instance.id, quest.id)
    if kept ~= nil then return kept end
    return ns.UI.QuestStartsInsideData(quest, instance) and true or false
end

-- A dungeon's walkable-area outlines as edited (NeedRollDB.outlineEdit[id],
-- a copy of the data's made the first time edit mode draws its map, with
-- `create`), or nil.
function MapEdit:Outlines(id, create)
    if not self.available or not ns.db then return nil end
    local edits = ns.db.outlineEdit and ns.db.outlineEdit[id]
    if not edits and create then
        ns.db.outlineEdit = ns.db.outlineEdit or {}
        edits = CopyTable(ns.Data:Outlines(id))
        ns.db.outlineEdit[id] = edits
    end
    return edits
end

-- A dungeon's zone-wide quests as edited (NeedRollDB.zoneEdit[id], a copy
-- of the data's made at the first edit), or nil when not edited.
function MapEdit:ZoneQuests(id)
    if not self.available then return nil end
    return ns.db and ns.db.zoneEdit and ns.db.zoneEdit[id]
end

-- A zone tool picked, then a quest: zone-wide with that icon; again, or
-- with the same icon, it's taken off.
local function ZoneClick(instance, quest, kind)
    ns.db.zoneEdit = ns.db.zoneEdit or {}
    local list = ns.db.zoneEdit[instance.id]
    if not list then
        list = CopyTable(ns.Data:ZoneQuests(instance.id))
        ns.db.zoneEdit[instance.id] = list
    end
    local kindWord = kind == "attack" and "kill" or "drop"
    for i, entry in ipairs(list) do
        if entry[1] == quest.id then
            if entry[2] == kind then
                table.remove(list, i)
                ns:Print(("%s: no longer zone-wide."):format(quest.name))
            else
                entry[2] = kind
                ns:Print(("%s: zone-wide, now as a %s."):format(quest.name, kindWord))
            end
            return Redraw()
        end
    end
    table.insert(list, { quest.id, kind })
    ns:Print(("%s: zone-wide (%s)."):format(quest.name, kindWord))
    Redraw()
end

-- The boss list and an open quest page show quest marks: draws them again.
-- With `onlyQuest`, the quest page only when it is that quest's.
local function RedrawQuestMarks(onlyQuest)
    if ns.UI.encounters then ns.UI.encounters:Refresh() end
    local pane = OverviewPane()
    if not (pane and pane.quest and pane:IsVisible()) then return end
    if onlyQuest and pane.quest ~= onlyQuest then return end
    pane:ShowQuest(pane.instance, pane.quest)
end

-- A click on a quest in the Quests list: with a zone tool, zone-wide
-- (ZoneClick); with the quest portal, it starts inside; alt-right-click: it
-- doesn't. A mark that matches the data is dropped. True when it was ours.
function MapEdit:QuestClick(instance, quest, button)
    if not (self.on and instance and quest) then return false end
    local zoneKind = button == "LeftButton" and self.tool and self.tool:match("^zone:(.+)")
    if zoneKind then
        ZoneClick(instance, quest, zoneKind)
        return true
    end
    local inside
    if button == "LeftButton" and self.tool == "quest" then
        inside = true
    elseif button == "RightButton" and IsAltKeyDown() then
        inside = false
    else
        return false
    end
    ns.db.questEdit = ns.db.questEdit or {}
    local marks = ns.db.questEdit[instance.id] or {}
    ns.db.questEdit[instance.id] = marks
    if QuestInData(instance, quest) == inside then
        marks[quest.id] = nil
        if not next(marks) then ns.db.questEdit[instance.id] = nil end
    else
        marks[quest.id] = inside
    end
    ns:Print(("%s: %s."):format(quest.name, inside and "starts inside" or "doesn't start inside"))
    RedrawQuestMarks(quest)
    return true
end

-- Picks the tool, or lets it go when it is the one picked. A new tool
-- starts with no pin or marker to draw for.
local function ToggleTool(tool)
    MapEdit.tool = MapEdit.tool ~= tool and tool or nil
    MapEdit.drawFor = nil
    MapEdit:UpdatePalette()
end

-- A plain movable game window with a title, for the dev tools.
local function DevWindow(name, width, height, title)
    local f = ns.DevKit.GameWindow(name, width, height)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", 0, -5)
    f.title:SetText(title)
    return f
end

-- A square palette button for `tool`, which a click picks: filled blue
-- inside a gold edge while its tool is picked (ShowPicked), the game's
-- square highlight under the mouse.
local function PaletteButton(parent, size, tool)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0.24, 0.38, 0.5, 0)
    b.edges = Theme:Border(b, PICKED_GOLD)
    for _, edge in ipairs(b.edges) do edge:Hide() end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function(self) ToggleTool(self.tool) end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b.tool = tool
    return b
end

local function AddHelpLines(lines)
    for _, line in ipairs(lines) do GameTooltip:AddLine(line, unpack(Theme.tip.text)) end
end

local function ShowToolTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.title or button.tool)
    AddHelpLines(TOOL_HELP[ToolKind(button.tool)] or PLACE_HELP)
    GameTooltip:Show()
end

local function CreateToolButtons(f)
    f.tools = {}
    for i, tool in ipairs(TOOLS) do
        local b = PaletteButton(f, TOOL_BUTTON, tool[1])
        b.title = tool.title
        b:SetPoint("TOPLEFT", 14 + ((i - 1) % TOOLS_PER_ROW) * TOOL_COLUMN,
            -32 - math.floor((i - 1) / TOOLS_PER_ROW) * TOOL_ROW)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("CENTER")
        if tool.texture then
            b.icon:SetTexture(tool[2])
            b.icon:SetSize(26, 26)
        else
            ns.Theme:FitAtlas(b.icon, tool[2], 30)
        end
        b:SetScript("OnEnter", ShowToolTooltip)
        f.tools[i] = b
    end
end

-- A looked-up unit's name, or its unit ID when the game gave no name.
local function UnitTitle(unit)
    return unit.name or ("Unit " .. unit.npc)
end

-- Any creature by its unit (NPC) ID; "d" and a number takes a creature
-- display ID instead (LookUpUnit). Its portrait button picks it to place.
local function CreateUnitPicker(f)
    f.unitLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.unitLabel:SetText("Unit ID")
    f.unitBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.unitBox:SetSize(80, 20)
    f.unitBox:SetAutoFocus(false)
    f.unitBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        MapEdit:LookUpUnit(strtrim(self:GetText() or ""))
    end)
    f.unitBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.unitButton = PaletteButton(f, BOSS_BUTTON, "unit")
    f.unitButton.pin = ns.UI.MiniPin(f.unitButton, BOSS_BUTTON - 2)
    f.unitButton.pin:SetPoint("CENTER")
    f.unitButton.pin:Hide()
    f.unitButton:SetScript("OnClick", function()
        if MapEdit.unit and MapEdit.unit.display then ToggleTool("unit") end
    end)
    f.unitButton:SetScript("OnEnter", function(self)
        local unit = MapEdit.unit
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if unit and unit.display then
            GameTooltip:SetText(UnitTitle(unit))
            GameTooltip:AddLine(("Unit %s  ·  display %d"):format(unit.npc, unit.display), 1, 0.82, 0)
            AddHelpLines(PLACE_HELP)
        else
            GameTooltip:SetText("Type a unit ID and press Enter")
        end
        GameTooltip:Show()
    end)
    f.unitName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.unitName:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.unitName:SetJustifyH("LEFT")
    f.unitName:SetWordWrap(false)
end

-- The quest portal: the tool for "starts inside the dungeon".
local function CreateQuestPortal(f)
    f.questLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.questLabel:SetText("Quests")
    f.questButton = PaletteButton(f, TOOL_BUTTON, "quest")
    f.questButton.title = "Starts inside the dungeon"
    f.questButton.icon = f.questButton:CreateTexture(nil, "ARTWORK")
    f.questButton.icon:SetPoint("CENTER")
    ns.Theme:FitAtlas(f.questButton.icon, ns.UI.TabIcon("DUNGEON"), 30)
    f.questButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.title)
        AddHelpLines({ "Pick, then click a quest in the Quests list", "Alt-right-click a quest to take it off" })
        GameTooltip:Show()
    end)
    f.questHint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.questHint:SetPoint("LEFT", f.questButton, "RIGHT", 6, 0)
    f.questHint:SetPoint("RIGHT", -14, 0)
    f.questHint:SetJustifyH("LEFT")
    f.questHint:SetText("Pick, then click a quest:\nit starts inside.")
end

-- Language preview: another language's phrases in place of the client's.
local function CreateLanguagePicker(f)
    f.languageLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.languageLabel:SetText("Language preview")
    f.language = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.language:SetSize(120, 22)
    f.language:SetText(ns.loadedLanguage)
    f.language:SetScript("OnClick", function(self) MapEdit:LanguageMenu(self) end)
    f.language:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Language preview")
        local r, g, b = unpack(Theme.tip.text)
        GameTooltip:AddLine("Shows NeedRoll's phrases in another language to check how they fit.", r, g, b, true)
        GameTooltip:AddLine("Text set up at login (tabs, some labels) and names from the game stay as they are; "
            .. "/reload goes back.", r, g, b, true)
        GameTooltip:Show()
    end)
    f.language:SetScript("OnLeave", GameTooltip_Hide)
end

--[==[@debug@
-- A dev tick box with `label` beside it and `tip` in its tooltip;
-- `onClick(checked)` runs on a click.
local function DevCheckBox(f, label, tip, onClick)
    local box = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    box:SetSize(22, 22)
    box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.label:SetPoint("LEFT", box, "RIGHT", 2, 1)
    box.label:SetText(label)
    box:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label)
        local r, g, b = unpack(Theme.tip.text)
        GameTooltip:AddLine(tip, r, g, b, true)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", GameTooltip_Hide)
    return box
end

-- "Fake combat": while ticked, NeedRoll's map links act as in combat
-- (ns.UI.MapLinksInCombat in UI/MainFrame.lua), so a click on one draws
-- NeedRoll's own pin and prints its message out of combat too. Not saved:
-- a /reload unticks it, as it ends the language preview.
local function CreateFakeCombatBox(f)
    f.fakeCombat = DevCheckBox(f, "Fake combat",
        "Map pin links act as in combat: a click draws NeedRoll's own pin and says why.",
        function(checked) ns.UI.fakeCombat = checked or nil end)
    f.fakeCombat:SetChecked(ns.UI.fakeCombat == true)
end

local VIEW_AS_BOX_GAP = 84  -- from the Alliance box to the Horde box

-- "View as" Alliance / Horde: NeedRoll shows everything as for a character
-- of the ticked side (ns.UI.ViewAsFaction in UI/MainFrame.lua): quests,
-- crests, vendors and trainers, the instance lists. At most one is ticked;
-- neither means the character's own side. Not saved, like Fake combat.
local function CreateViewAsBoxes(f)
    f.viewAsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.viewAsLabel:SetText("View as")
    f.viewAs = {}
    local function Tick(side, checked)
        ns.UI:ViewAsFaction(checked and side or nil)
        for boxSide, box in pairs(f.viewAs) do box:SetChecked(ns.viewAsFaction == boxSide) end
    end
    for _, side in ipairs({ "Alliance", "Horde" }) do
        f.viewAs[side] = DevCheckBox(f, side, "NeedRoll shows everything as for a " .. side
            .. " character. Untick to go back to this character's side.",
            function(checked) Tick(side, checked) end)
        f.viewAs[side]:SetChecked(ns.viewAsFaction == side)
    end
    f.viewAs.Horde:SetPoint("LEFT", f.viewAs.Alliance, "LEFT", VIEW_AS_BOX_GAP, 0)
end
--@end-debug@]==]

-- Keeps the pick's cue by the cursor, seen only while the mouse is over
-- the map (it stays shown, at no alpha, so this keeps running).
local function FollowCursor(cue)
    local pane = OverviewPane()
    local view = pane and pane.mapView
    local overMap = view and view:IsVisible() and view.clip:IsMouseOver()
    cue:SetAlpha(overMap and 1 or 0)
    if not overMap then return end
    local x, y = GetCursorPosition()
    local scale = cue:GetEffectiveScale()
    cue:ClearAllPoints()
    cue:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + CUE_OFFSET, y / scale - CUE_OFFSET)
end

-- What is picked, by the cursor over the map: a line of text on a dark
-- strip, shown while something is picked (UpdatePalette).
local function CreatePickCue(f)
    local cue = CreateFrame("Frame", nil, f)
    cue:SetFrameStrata("TOOLTIP")
    cue:SetClampedToScreen(true)
    cue:SetHeight(20)
    Theme:Fill(cue, { 0, 0, 0, 0.75 })
    cue.text = cue:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cue.text:SetPoint("LEFT", 6, 0)
    cue:SetScript("OnUpdate", FollowCursor)
    cue:Hide()
    f.cue = cue
end

-- The palette's line over Export and Done: what is picked, or that nothing is.
local function CreatePickedLine(f)
    f.picked = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.picked:SetPoint("BOTTOMLEFT", 14, 42)
    f.picked:SetPoint("RIGHT", -14, 0)
    f.picked:SetJustifyH("LEFT")
    f.picked:SetWordWrap(false)
end

-- The palette window, beside the NeedRoll window. The boss buttons are
-- made as an instance's map shows (ShowBosses).
local function Palette()
    if MapEdit.palette then return MapEdit.palette end
    local f = DevWindow("NeedRollMapEdit", 232, 292, "Dev edit")
    f.CloseButton:SetScript("OnClick", function() MapEdit:Toggle(false) end)
    CreateToolButtons(f)

    f.bossLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.bossLabel:SetPoint("TOPLEFT", 14, -BOSS_TOP)
    f.bossLabel:SetPoint("RIGHT", -14, 0)
    f.bossLabel:SetJustifyH("LEFT")
    f.bosses = {}
    f.unitsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.unitsLabel:SetText("Units")
    f.units = {}

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("RIGHT", -14, 0)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetText("Drag anything on the map to move it.\n"
        .. "Pick a boss, click the map: add it\n(or move it there on this level).\n"
        .. "Pick a unit, click the map: add it.\n"
        .. "Unit ID: Enter, then pick its portrait.\n"
        .. "Right-click a link: level it leads to.\n"
        .. "Shift-right-click a link: its icon.\n"
        .. "Alt-right-click: remove (bosses too).\n"
        .. "Patrol: pick loop or line, click an icon,\n"
        .. "then drag on the map to draw its route;\n"
        .. "drag the gold dots; shift-right-click one:\nloop or line.\n"
        .. "Area: pick, click a marker, drag to draw.\n"
        .. "Quest portal: pick it, click a quest.\n"
        .. "Alt-right-click a quest: no portal.\n"
        .. "Quest marker: right-click it: its quest;\n"
        .. "shift-right-click: its icon.\n"
        .. "Right-click the map or Esc: let go.")

    f.export = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.export:SetSize(96, 22)
    f.export:SetPoint("BOTTOMLEFT", 14, 12)
    f.export:SetText("Export")
    f.export:SetScript("OnClick", function() MapEdit:Export() end)
    f.done = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.done:SetSize(96, 22)
    f.done:SetPoint("BOTTOMRIGHT", -14, 12)
    f.done:SetText("Done")
    f.done:SetScript("OnClick", function() MapEdit:Toggle(false) end)
    CreateUnitPicker(f)
    CreateQuestPortal(f)
    CreateLanguagePicker(f)
    --[==[@debug@
    CreateFakeCombatBox(f)
    CreateViewAsBoxes(f)
    --@end-debug@]==]
    CreatePickedLine(f)
    CreatePickCue(f)
    -- Shown while something is picked, so Escape lets go of it.
    f.escape = CreateFrame("Frame", nil, f)
    Theme:OnEscape(f.escape, function() MapEdit:Cancel() end)
    f.escape:Hide()
    -- Shown while a drag on the map draws (StartStroke).
    f.strokeDriver = CreateFrame("Frame", nil, f)
    f.strokeDriver:SetScript("OnUpdate", FollowStroke)
    f.strokeDriver:Hide()

    MapEdit.palette = f
    MapEdit:LayOutPalette(0, 0)
    return f
end

-- Puts `count` of `buttons` in rows of BOSS_PER_ROW starting `top` down the
-- palette; returns how far down the rows end.
local function LayOutButtonRows(buttons, count, top)
    local stride = BOSS_BUTTON + 2
    for i = 1, count do
        local b = buttons[i]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 14 + ((i - 1) % BOSS_PER_ROW) * stride,
            -top - math.floor((i - 1) / BOSS_PER_ROW) * stride)
    end
    return top + math.ceil(count / BOSS_PER_ROW) * stride
end

-- The boss buttons' rows, the unit buttons' rows (with their label, when
-- the instance has units listed), then the unit picker, quest portal,
-- language preview (and in local checkouts the dev tick boxes) and hint
-- under them, and the window's height to fit.
function MapEdit:LayOutPalette(bossCount, unitCount)
    local f = self.palette
    local y = LayOutButtonRows(f.bosses, bossCount, BOSS_TOP + 16) + 8
    f.unitsLabel:SetShown(unitCount > 0)
    if unitCount > 0 then
        f.unitsLabel:SetPoint("TOPLEFT", 14, -y)
        y = LayOutButtonRows(f.units, unitCount, y + 16) + 8
    end
    f.unitLabel:SetPoint("TOPLEFT", 14, -y)
    f.unitBox:SetPoint("TOPLEFT", 20, -y - 16)
    f.unitButton:SetPoint("LEFT", f.unitBox, "RIGHT", 10, 0)
    f.unitName:SetPoint("LEFT", f.unitButton, "RIGHT", 6, 0)
    y = y + 16 + BOSS_BUTTON + 10
    f.questLabel:SetPoint("TOPLEFT", 14, -y)
    f.questButton:SetPoint("TOPLEFT", 14, -y - 16)
    y = y + 16 + TOOL_BUTTON + 10
    f.languageLabel:SetPoint("TOPLEFT", 14, -y)
    f.language:SetPoint("TOPLEFT", 14, -y - 16)
    y = y + 16 + 22 + 10
    --[==[@debug@
    f.fakeCombat:SetPoint("TOPLEFT", 10, -y)
    y = y + 22 + 8
    f.viewAsLabel:SetPoint("TOPLEFT", 14, -y)
    f.viewAs.Alliance:SetPoint("TOPLEFT", 10, -y - 14)
    y = y + 14 + 22 + 8
    --@end-debug@]==]
    f.hint:SetPoint("TOPLEFT", 14, -y)
    f:SetHeight(y + math.ceil(f.hint:GetStringHeight()) + FOOTER_HEIGHT)
end

local function CreateBossButton(f)
    local b = PaletteButton(f, BOSS_BUTTON)
    b.pin = ns.UI.MiniPin(b, BOSS_BUTTON - 2)
    b.pin:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.name)
        GameTooltip:AddLine(self.isHere and "On this level: picking it moves it" or "Not on this level", 1, 0.82, 0)
        AddHelpLines(PLACE_HELP)
        GameTooltip:Show()
    end)
    return b
end

-- A button for one of Data/DevDungeons.lua's units (mapEditUnits): its
-- portrait (the default face until its model is looked up), and a click
-- picks it to place, as a typed unit ID would be (PickListedUnit).
local function CreateUnitButton(f)
    local b = CreateBossButton(f)
    b:SetScript("OnClick", function(self) MapEdit:PickListedUnit(self.listed) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.name)
        local display = self.listed.display
        GameTooltip:AddLine(display and ("Unit %d  ·  display %d"):format(self.listed.unit, display)
            or ("Unit %d  ·  model looked up when picked"):format(self.listed.unit), 1, 0.82, 0)
        GameTooltip:AddLine(self.isHere and "On this level: picking it moves it" or "Not on this level", 1, 0.82, 0)
        AddHelpLines(PLACE_HELP)
        GameTooltip:Show()
    end)
    return b
end

-- Fills the unit buttons with the instance's units that aren't one of its
-- bosses (`bossNpcs`); those pinned on the level on show (NPC_<id>, in
-- `pinnedHere`) are dimmed. Returns how many it shows.
local function ShowListedUnits(f, instance, pinnedHere, bossNpcs)
    local listedUnits = ns.Data.mapEditUnits and ns.Data.mapEditUnits[instance.id] or {}
    local count = 0
    for _, listed in ipairs(listedUnits) do
        if not bossNpcs[listed.unit] then
            count = count + 1
            f.units[count] = f.units[count] or CreateUnitButton(f)
            local b = f.units[count]
            b.listed, b.name, b.isHere = listed, listed.name, pinnedHere["NPC_" .. listed.unit] or false
            ns.UI.SetMiniPin(b.pin, { nil, 0, 0, listed.display })
            b.pin:SetAlpha(b.isHere and 0.4 or 1)
            b:Show()
        end
    end
    for i = count + 1, #f.units do f.units[i]:Hide() end
    return count
end

-- Picks one of the listed units to place, as Enter in the Unit ID box
-- would: its display straight away when known, else the model lookup
-- (LookUpUnit). A second click on the picked unit lets go of it.
function MapEdit:PickListedUnit(listed)
    if self.tool == "unit" and self.unit and self.unit.npc == listed.unit then return ToggleTool("unit") end
    -- A click on a unit picks it, whatever was picked before.
    self.tool, self.drawFor = nil, nil
    self:UpdatePalette()
    self.palette.unitBox:SetText(tostring(listed.unit))
    if not listed.display then
        self:LookUpUnit(tostring(listed.unit))
        -- The game may not give the creature's name (a secret one on WoW: Forever).
        self.unit.name = self.unit.name or listed.name
        return self:ShowUnit(self.unit)
    end
    self.unit = { npc = listed.unit, display = listed.display, name = listed.name }
    self:ShowUnit(self.unit)
end

-- Fills the palette with the bosses of the instance the map shows, and
-- its other units; the ones already pinned on the level on show are dimmed.
function MapEdit:ShowBosses(instance, map, level)
    local f = self.palette
    if not f then return end
    local spots = self:Spots(instance.id, map)
    local pinnedHere = {}
    for _, pin in ipairs(spots and spots.pins[level] or map[level].pins or {}) do pinnedHere[pin[1]] = true end
    local bosses, bossNpcs = {}, {}
    self.bossEncounters = {}
    for _, encounter in ipairs(instance.encounters) do
        if ns.Data:IsBoss(encounter) then
            table.insert(bosses, encounter)
            self.bossEncounters[encounter.id] = encounter
            if encounter.npc then bossNpcs[encounter.npc] = true end
        end
    end
    f.bossLabel:SetText("Bosses: " .. instance.name)
    local bossTools = {}
    for i, encounter in ipairs(bosses) do
        f.bosses[i] = f.bosses[i] or CreateBossButton(f)
        local b = f.bosses[i]
        b.tool, b.name, b.isHere = "boss:" .. encounter.id, encounter.name, pinnedHere[encounter.id] or false
        bossTools[b.tool] = true
        ns.UI.SetMiniPin(b.pin, { encounter, 0, 0, BossLook(instance, map, encounter) })
        b.pin:SetAlpha(b.isHere and 0.4 or 1)
        b:Show()
    end
    for i = #bosses + 1, #f.bosses do
        f.bosses[i]:Hide()
        f.bosses[i].tool = nil
    end
    -- A boss picked in another dungeon isn't one to place here.
    if ToolKind(self.tool) == "boss" and not bossTools[self.tool] then self.tool = nil end
    self:LayOutPalette(#bosses, ShowListedUnits(f, instance, pinnedHere, bossNpcs))
    self:UpdatePalette()
end

-- Every button on the palette that picks a tool.
local function PaletteButtons(f)
    local buttons = { f.unitButton, f.questButton }
    for _, b in ipairs(f.tools) do table.insert(buttons, b) end
    for _, b in ipairs(f.bosses) do table.insert(buttons, b) end
    return buttons
end

-- A palette button lit (blue fill, gold edge) while its tool is picked.
local function ShowPicked(button, isPicked)
    button.bg:SetAlpha(isPicked and 1 or 0)
    for _, edge in ipairs(button.edges) do edge:SetShown(isPicked) end
end

-- The pick's name, as its button's tooltip gives it.
local function PickTitle(f, tool)
    if tool == "unit" then return UnitTitle(MapEdit.unit) end
    for _, b in ipairs(PaletteButtons(f)) do
        if b.tool == tool then return b.title or b.name or tool end
    end
    return tool
end

-- The pin a patrol is drawn for (its boss's name, or a unit's), or the
-- marker an area is.
local function DrawForName(kind, spot)
    if kind == "area" then return (MARKER_TITLES[spot[4]] or spot[4]) .. " marker" end
    local encounter = MapEdit.bossEncounters and MapEdit.bossEncounters[spot[1]]
    return encounter and encounter.name or spot.name or spot[1]
end

-- What a pick's next click does, by its kind; "click the map" for the rest.
local NEXT_STEP = {
    patrol = "click a boss or unit icon", area = "click a quest marker", outline = "click or drag on the map",
    zone = "click a quest in the list", quest = "click a quest in the list",
}

-- One line on what is picked and what to do next, or nil with nothing picked.
function MapEdit:PickText()
    if self.linking then return Theme:JoinDots("Marker picked", "click a pin, a marker or the map") end
    local tool = self.tool
    if not tool then return nil end
    local kind, title = ToolKind(tool), PickTitle(self.palette, tool)
    if self.drawFor and (kind == "patrol" or kind == "area") then
        return Theme:JoinDots(("%s for %s"):format(title, DrawForName(kind, self.drawFor)), "drag on the map to draw")
    end
    return Theme:JoinDots(title, NEXT_STEP[kind] or "click the map")
end

-- Shows what is picked: its palette button lit (a blue fill inside a gold
-- edge), its line over Export and by the cursor over the map, and Escape
-- ready to let go. With nothing picked all of that clears.
function MapEdit:UpdatePalette()
    local f = self.palette
    if not f then return end
    for _, b in ipairs(PaletteButtons(f)) do ShowPicked(b, self.tool ~= nil and b.tool == self.tool) end
    local pickedUnit = self.tool == "unit" and self.unit and self.unit.npc
    for _, b in ipairs(f.units) do ShowPicked(b, b.listed ~= nil and b.listed.unit == pickedUnit) end
    local text = self:PickText()
    f.picked:SetText(text or "Nothing picked")
    Theme:SetTextColor(f.picked, text and PICKED_GOLD or Theme.tip.quiet)
    f.cue.text:SetText(text or "")
    f.cue:SetWidth(f.cue.text:GetStringWidth() + 12)
    f.cue:SetShown(text ~= nil)
    f.escape:SetShown(text ~= nil)
end

-- The language preview's menu: every language NeedRoll has phrases for
-- (ns.LANGUAGES; Locales/Locales.lua keeps them all in dev builds). Korean
-- and Chinese text draws on any client: NeedRoll's fonts have a member for
-- each alphabet (UI/Theme.lua, Font families).

function MapEdit:Preview(locale)
    if not ns.PreviewPhrases(locale) then return end
    self.language = locale
    self.palette.language:SetText(locale)
    ns.Search:Forget()
    ns.Tooltip:Forget()
    local ui = ns.UI
    if ui.frame and ui.frame:IsShown() then
        ui.instances:Refresh()
        ui.encounters:Refresh()
        ui:Refresh()
    end
end

function MapEdit:LanguageMenu(button)
    local current = self.language or ns.loadedLanguage
    MenuUtil.CreateContextMenu(button, function(_, root)
        for _, language in ipairs(ns.LANGUAGES) do
            local locale = language.code
            root:CreateRadio(locale, function() return locale == current end,
                function() MapEdit:Preview(locale) end)
        end
    end)
end

-- Shows `unit` in the palette's unit picker, while it is still the unit
-- picked: its portrait once its display is known, then picked to place,
-- unless another tool is already picked (a click on the portrait picks it
-- then).
function MapEdit:ShowUnit(unit)
    if self.unit ~= unit then return end
    local f = self.palette
    f.unitButton.pin:SetShown(unit.display ~= nil)
    f.unitName:SetText(unit.display and UnitTitle(unit) or "Looking up...")
    if not unit.display then return end
    ns.UI.SetMiniPin(f.unitButton.pin, { nil, 0, 0, unit.display })
    if self.tool == nil then self.tool = "unit" end
    self:UpdatePalette()
end

-- Shows the unit's portrait in the palette, ready to place. A unit ID's
-- display ID comes from a hidden creature model, which the client may need
-- a moment to fetch; "d1234" takes display ID 1234 as it is.
function MapEdit:LookUpUnit(text)
    local f = self.palette
    local display = tonumber(text:match("^[dD]%s*(%d+)$") or "")
    local npc = tonumber(text:match("^(%d+)$") or "")
    if not display and not npc then
        ns:Print("Unit ID: type a number (or d and a display ID).")
        return
    end
    -- The unit picked to place is let go: the new one is picked once found.
    if self.tool == "unit" then
        self.tool = nil
        self:UpdatePalette()
    end
    local unit = { npc = npc or ("d" .. display), display = display }
    self.unit = unit
    if display then
        unit.name = "Display " .. display
        return self:ShowUnit(unit)
    end
    unit.name = ns.Names:CreatureName(npc)
    if not self.model then
        self.model = CreateFrame("PlayerModel", nil, UIParent)
        self.model:SetSize(1, 1)
        self.model:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 10, -10)  -- off screen
    end
    local model, tries = self.model, 0
    model:SetCreature(npc)
    local function LookForDisplay()
        if self.unit ~= unit then return end
        tries = tries + 1
        local displayID = model:GetDisplayInfo()
        if displayID and displayID > 0 then
            unit.display = displayID
            unit.name = unit.name or ns.Names:CreatureName(npc)
            return self:ShowUnit(unit)
        end
        if tries == 3 then model:SetCreature(npc) end  -- asked again in case the first ask was lost
        if tries < UNIT_TRIES then
            C_Timer.After(0.5, LookForDisplay)
        else
            f.unitName:SetText("Not found")
            ns:Print(("No creature model for unit %d. Type d and its display ID to use that instead."):format(npc))
        end
    end
    self:ShowUnit(unit)
    LookForDisplay()
end

function MapEdit:Toggle(on)
    if not self.available then return end
    if on == nil then on = not self.on end
    self.on = on
    local f = Palette()
    self:LetGo()
    if on then
        f:ClearAllPoints()
        local main = ns.UI and ns.UI.frame
        if main and main:IsShown() then
            f:SetPoint("TOPLEFT", main, "TOPRIGHT", 8, 0)
        else
            f:SetPoint("CENTER")
        end
        f:Show()
        ns:Print("Dev edit on. Drag a dungeon map's pins, swirls and links, or mark quests; /nr devexport copies them.")
    else
        f:Hide()
        ns:Print("Dev edit off. Your edits stay in place; /nr devedit reset drops them.")
    end
    Redraw()
end

function MapEdit:Reset()
    if not self.available then return end
    if ns.db then
        ns.db.mapEdit, ns.db.questEdit, ns.db.zoneEdit, ns.db.outlineEdit = nil, nil, nil, nil
        ns.FontDebug:Reset()
    end
    -- A picked marker or pin to draw for was in the copies just dropped.
    self:LetGo()
    ns:Print("Dev edits dropped.")
    RedrawQuestMarks()
    Redraw()
end

local function Coord(value)
    return ("%.3f"):format(value)
end

local function JoinAsText(list, toText)
    local parts = {}
    for _, item in ipairs(list or {}) do table.insert(parts, toText(item)) end
    return table.concat(parts, ", ")
end

local function CoordList(points)
    return JoinAsText(points, Coord)
end

-- { level, x, y, "icon" }, the icon left out when there is none: a lock,
-- an entrance ("raid") or a level link (its icon; level is where it leads).
local function SpotText(spot)
    local icon = spot[4] and (', "' .. spot[4] .. '"') or ""
    return ("{ %d, %s, %s%s }"):format(spot[1], Coord(spot[2]), Coord(spot[3]), icon)
end

local function MarkerText(marker)
    local quest = marker[5] and tostring(marker[5]) or "nil"
    local onWhat = marker.boss and (', boss = "' .. marker.boss .. '"') or marker.on and ", on = true" or ""
    local area = marker.area and (", area = { %s }"):format(CoordList(marker.area)) or ""
    return ('{ %d, %s, %s, "%s", %s%s%s }'):format(marker[1], Coord(marker[2]), Coord(marker[3]),
        marker[4], quest, onWhat, area)
end

-- A boss or unit pin's line: its key, spot, look (a display ID or an icon
-- path), patrol route, and for a unit its NPC ID and name.
local function PinLine(pin)
    local look = type(pin[4]) == "string" and (', "' .. pin[4]:gsub("\\", "\\\\") .. '"')
        or pin[4] and (", " .. pin[4]) or ""
    local extra = ""
    if pin.patrol then
        extra = (", patrol = { %s%s }"):format(pin.patrol.open and "open = true, " or "", CoordList(pin.patrol))
    end
    if pin.npc then
        extra = extra .. (", npc = %s"):format(type(pin.npc) == "number" and pin.npc or ('"' .. pin.npc .. '"'))
        if pin.name then extra = extra .. (", name = %q"):format(pin.name) end
    end
    return ('            { "%s", %s, %s%s%s },'):format(pin[1], Coord(pin[2]), Coord(pin[3]), look, extra)
end

-- Every edited map, in Data/Maps.lua's RegisterMapSpots shape.
local function MapSpotLines(mapEdits)
    local lines = {}
    local function Add(line) table.insert(lines, line) end
    for _, id in ipairs(SortedKeys(mapEdits)) do
        local edits = mapEdits[id]
        Add(("%s = {"):format(id))
        Add(("    entrance = { %s },"):format(JoinAsText(edits.entrances, SpotText)))
        local locks = JoinAsText(edits.locks, SpotText)
        if locks ~= "" then Add(("    lock = { %s },"):format(locks)) end
        local markers = JoinAsText(edits.markers, MarkerText)
        if markers ~= "" then Add(("    marker = { %s },"):format(markers)) end
        Add("    links = {")
        for level, links in ipairs(edits.links) do
            if #links > 0 then Add(("        [%d] = { %s },"):format(level, JoinAsText(links, SpotText))) end
        end
        Add("    },")
        Add("    pins = {")
        for level, pins in ipairs(edits.pins) do
            if #pins > 0 then
                Add(("        [%d] = {"):format(level))
                for _, pin in ipairs(pins) do Add(PinLine(pin)) end
                Add("        },")
            end
        end
        Add("    },")
        Add("},")
    end
    return lines
end

-- One dungeon's outlines, a line per level that has shapes.
local function ShapeLines(levels)
    local lines = {}
    for _, level in ipairs(SortedKeys(levels)) do
        local shapes = JoinAsText(levels[level], function(shape) return ("{ %s }"):format(CoordList(shape)) end)
        if shapes ~= "" then table.insert(lines, ("    [%d] = { %s },"):format(level, shapes)) end
    end
    return lines
end

-- Only the outlines that differ from the data's.
local function OutlineLines(outlineEdits)
    local lines = {}
    for _, id in ipairs(SortedKeys(outlineEdits)) do
        local edited = ShapeLines(outlineEdits[id])
        if table.concat(edited, "\n") ~= table.concat(ShapeLines(ns.Data:Outlines(id)), "\n") then
            table.insert(lines, ("%s = {"):format(id))
            for _, line in ipairs(edited) do table.insert(lines, line) end
            table.insert(lines, "},")
        end
    end
    return lines
end

local function ZoneQuestLines(zoneEdits)
    local lines = {}
    local function EntryText(entry) return ('{ %d, "%s" }'):format(entry[1], entry[2]) end
    for _, id in ipairs(SortedKeys(zoneEdits)) do
        table.insert(lines, ("%s = { %s },"):format(id, JoinAsText(zoneEdits[id], EntryText)))
    end
    return lines
end

local function QuestStartLines(questEdits)
    local lines = {}
    for _, id in ipairs(SortedKeys(questEdits)) do
        local marks = questEdits[id]
        local function MarkText(quest) return ("[%d] = %s"):format(quest, tostring(marks[quest])) end
        table.insert(lines, ("%s = { %s },"):format(id, JoinAsText(SortedKeys(marks), MarkText)))
    end
    return lines
end

-- A header and its lines, after a blank line when something came before.
local function AddSection(out, header, lines)
    if #lines == 0 then return end
    if #out > 0 then table.insert(out, "") end
    table.insert(out, header)
    for _, line in ipairs(lines) do table.insert(out, line) end
end

-- Lua for every edit, a section per data file, written the way those files
-- write it so a paste reads like the lines around it.
function MapEdit:Text()
    local db = ns.db or {}
    local out = {}
    AddSection(out, "-- Data/Maps.lua (RegisterMapSpots)", MapSpotLines(db.mapEdit))
    AddSection(out, "-- Data/Outlines.lua (the outlines table)", OutlineLines(db.outlineEdit))
    AddSection(out, "-- Data/Maps.lua (RegisterZoneQuests)", ZoneQuestLines(db.zoneEdit))
    AddSection(out, "-- Data/QuestStarts.lua", QuestStartLines(db.questEdit))
    -- Text sizes tried in edit mode, as notes for the code.
    AddSection(out, "-- Text and icon sizes: name (font): size by its page -> edited size  =  that as a scale",
        ns.FontDebug:Text())
    if #out == 0 then
        return "-- Nothing edited yet: /nr devedit, then drag things on a map, mark quests, "
            .. "or /nr fontdebug and mouse-wheel over text or an icon."
    end
    return table.concat(out, "\n")
end

-- /nr devexport: a window with the Lua selected, ready for Ctrl+C.
function MapEdit:Export()
    if not self.available then return end
    local f = self.exportFrame
    if not f then
        f = DevWindow("NeedRollMapExport", 560, 440, "Dev export: Ctrl+C to copy")
        f:SetPoint("CENTER")
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -30)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        f.box = CreateFrame("EditBox", nil, scroll)
        f.box:SetMultiLine(true)
        f.box:SetAutoFocus(false)
        f.box:SetFontObject(ChatFontNormal)
        f.box:SetWidth(510)
        f.box:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(f.box)
        self.exportFrame = f
    end
    f.box:SetText(self:Text())
    f:Show()
    f.box:SetFocus()
    f.box:HighlightText()
end
