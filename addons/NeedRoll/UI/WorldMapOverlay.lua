-- NeedRoll's dungeon map laid over the game's world map. Inside a dungeon or
-- raid NeedRoll has a map for, the game's map (the M key, left to the game)
-- shows NeedRoll's level the player is on over its own, with the window's
-- boss pins, quest markers, entrances and locked doors. A click on a boss or
-- quest opens NeedRoll's window on it above the map. The game's map stays in
-- charge: its floor dropdown, or NeedRoll's floor chips at the top of the
-- map (which turn the game's map to a floor), picks the level shown, so the
-- layer draws no links to other levels. A right-click on the map always
-- turns NeedRoll's layer off until the map is closed and opened again, as
-- does any other map: the game's own right-click goes to the zone's map,
-- or does nothing on a map with no parent (the World map, where the game's
-- map opens in a dungeon it has no map for). A zone button in the map's
-- bottom left corner, named for the zone the dungeon's entrance is in
-- (Silverpine Forest for Shadowfang Keep), pins the entrance and takes the
-- game's map out there.
-- Map in dungeons = Game in Settings leaves the game's map alone.
--
-- NeedRoll only reads the game's map here: hooks on its showing and hiding,
-- its map ID polled while it shows, and right-clicks watched through the
-- GLOBAL_MOUSE_UP event. Changing it from addon code (or a
-- data provider, whose code runs inside the map's own refresh) would taint
-- it, and the game would then block Shift-clicking its pins into chat. The
-- zone button moves the map through the game's own /mappin, run by a secure
-- link (UI/MainFrame.lua), so the game's code moves it; the floor chips
-- through the game's C_Map.OpenWorldMap, out of combat only.
local _, ns = ...
local Theme = ns.Theme
local L = ns.L

local WorldMapOverlay = {}
ns.WorldMapOverlay = WorldMapOverlay

local layer             -- the map layer on the game's map, made the first time it shows
local followedMapID     -- the game's map ID the layer last followed
local droppedUntilReopen = false  -- right-click or another map turned the layer off
local openedOnMapID     -- the game's map ID as it opened: the player's map
-- What the layer shows, in the fields the window's pane has: the instance
-- (nil while off) and its level (levels[instance ID]).
local layerPane = { levels = {} }

-- Right-clicks on the layer's widgets go through to the game's map, as on
-- the game's own map pins (a right-click on a pin still goes to the zone's
-- map).
local PassRightClicks = ns.UI.PassRightClicks

-- Draws the level shown, sized to the game's canvas (its zoom). Nothing
-- while the canvas has no size yet.
local function Draw()
    local width, height = layer.canvas:GetSize()
    if width <= 0 or height <= 0 then return end
    layer.drawnWidth = width
    local instance = layerPane.instance
    local found = ns.UI.DrawMapLevel(layer, instance, layerPane.levels[instance.id], ns.UI.ArtScale(width, height))
    layer.clip:SetShown(found)
end
function layerPane:Refresh() Draw() end

-- `dropped`: the player left the instance's floors on the game's map, so
-- the layer stays off until the map opens again.
local function TurnOff(dropped)
    layerPane.instance, followedMapID = nil, nil
    droppedUntilReopen = dropped == true
    if layer then layer:Hide() end
end

-- While the layer shows: a new map on the game's map shows that level when
-- it is one of the instance's floors (the floor dropdown, the player taking
-- the stairs), else turns the layer off (right-click to the zone, another
-- map picked). The game eases each zoom over several frames: on each, only
-- the art is re-sized to follow it (pins and marks wait), and the whole
-- level is redrawn once the canvas's width holds, since a redraw on every
-- frame would rebuild every pin and marker each frame.
local function FollowGameMap()
    local mapID = WorldMapFrame:GetMapID()
    if mapID ~= followedMapID then
        followedMapID = mapID
        local instance, level = ns.UI.MapFloor(mapID, layerPane.instance)
        if instance ~= layerPane.instance then return TurnOff(true) end
        layerPane.levels[instance.id] = level
        return Draw()
    end
    local width, height = layer.canvas:GetSize()
    if width ~= layer.lastSeenWidth then
        layer.lastSeenWidth = width
        ns.UI.PlaceMapArt(layer, ns.UI.ArtScale(width, height))
    elseif width ~= layer.drawnWidth then
        Draw()
    end
end

-- Lays a layer (a frame with its .clip and .canvas) on the game's map,
-- `levelsUp` frame levels over the game's canvas: over the game's map art
-- and under its own pins (frame level 2000 on), cut off at the map's
-- visible area. Its canvas covers the game's canvas, so it pans and zooms
-- with it while staying at scale 1, which keeps pins their size. None of
-- the three takes the mouse: the wheel, drags and clicks on the empty map
-- are the game's.
local function LayOnGameMap(newLayer, levelsUp)
    local container, gameCanvas = WorldMapFrame.ScrollContainer, WorldMapFrame:GetCanvas()
    local level = gameCanvas:GetFrameLevel() + levelsUp
    newLayer:SetAllPoints(container)
    newLayer:SetFrameLevel(level)
    newLayer.clip:SetAllPoints(newLayer)
    newLayer.clip:SetFrameLevel(level + 1)
    newLayer.canvas:SetAllPoints(gameCanvas)
    newLayer.canvas:SetFrameLevel(level + 2)
end
WorldMapOverlay.LayOnGameMap = LayOnGameMap  -- the quest givers' and books' layer too (UI/WorldMapMarkers.lua)

-- The zone button: a pill naming the zone the shown dungeon's entrance is in
-- (Silverpine Forest for Shadowfang Keep), the way out of the dungeon on the
-- game's map. It is a map pin link like the window's Entrance row: out of
-- combat the secure link laid over it while hovered (UI/MainFrame.lua) runs
-- the game's /mappin on the entrance, so the game's own code moves its map
-- to that zone with the game's pin there, and the layer turns off as for any
-- other map. In combat the click reaches the pill itself, which draws
-- NeedRoll's own pin there instead (ns.UI.ShowOnMap). It sits in the map
-- area's bottom right corner: the map markers' dice owns the bottom left
-- (UI/WorldMapMarkers.lua), the game keeps its floor dropdown and map
-- buttons in the top corners.
local ZONE_BUTTON_INSET = 10      -- from the map area's right and bottom edges
local ZONE_BUTTON_LEVELS_UP = 45  -- over the game's canvas: over the layer's widgets, under NeedRoll's pin (50)

-- The shown dungeon's entrance (a spot in Data/Data.lua's shape), or nil
-- when it isn't known.
local function EntranceSpot()
    local instance = layerPane.instance
    return instance and ns.Data:Entrance(instance.id)
end

-- The game's name for the zone `spot` is in, in the player's language; nil
-- when the zone isn't found.
local function ZoneName(spot)
    local map = ns.UI.ZoneMap(spot.map)
    local info = map and C_Map.GetMapInfo(map)
    return info and info.name
end

-- The dungeon's name, then what a click does: in combat, why it can't pin.
local function ShowZoneButtonTooltip(button)
    local r, g, b = unpack(Theme.tip.text)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")  -- towards the map, away from its right edge
    GameTooltip:SetText(layerPane.instance.name)
    GameTooltip:AddLine(ns.UI.MapLinksInCombat() and ns.UI.NO_MAP_PINS_IN_COMBAT
        or L["Click to pin the entrance on your map"], r, g, b, true)
    GameTooltip:Show()
end

local function CreateZoneButton(parent)
    local button = Theme:NativePill(parent)
    button:SetPoint("BOTTOMRIGHT", -ZONE_BUTTON_INSET, ZONE_BUTTON_INSET)
    button:SetFrameLevel(WorldMapFrame:GetCanvas():GetFrameLevel() + ZONE_BUTTON_LEVELS_UP)
    PassRightClicks(button)
    button:HookScript("OnEnter", function(self)
        ShowZoneButtonTooltip(self)
        ns.UI.HoverMapLink(self, EntranceSpot())
    end)
    button:HookScript("OnLeave", function(self)
        GameTooltip:Hide()
        ns.UI.LeaveMapLink(self)
    end)
    button:SetScript("OnClick", function() ns.UI.ShowOnMap(EntranceSpot(), layerPane.instance.name) end)
    button:Hide()
    return button
end

-- Shows the zone button for the dungeon shown, labelled with its entrance's
-- zone; hidden when the entrance or its zone isn't known.
local function ShowZoneButton()
    local spot = EntranceSpot()
    local zoneName = spot and ZoneName(spot)
    layer.zoneButton:SetShown(zoneName ~= nil)
    if zoneName then layer.zoneButton:SetLabel(zoneName) end
end

-- The dungeon map's layer, just over the game's map art, with its zone
-- button.
local function CreateLayer()
    local newLayer = ns.UI.CreateMapLayer(WorldMapFrame.ScrollContainer, layerPane)
    LayOnGameMap(newLayer, 1)
    newLayer.zoneButton = CreateZoneButton(newLayer)
    newLayer.noLevelLinks = true
    newLayer.onNewWidget = PassRightClicks
    newLayer.openBoss = function(encounter) ns.UI:ShowFromWorldMap(layerPane.instance, encounter) end
    newLayer.openQuest = function(quest) ns.UI:ShowFromWorldMap(layerPane.instance, nil, quest) end
    newLayer:SetScript("OnUpdate", FollowGameMap)
    newLayer:Hide()
    return newLayer
end

-- The dungeon or raid the player is in and their level, when the layer may
-- show for it: its tab is on, Settings don't say Game and map edit mode
-- doesn't have the window's map. Else nil.
local function PlayerMapToShow()
    if ns.db.dungeonMap == "game" or ns.MapEdit.on then return nil end
    local instance, level = ns.UI.PlayerFloor()
    if not (instance and ns.Modules:IsOn(instance.category)) then return nil end
    return instance, level
end

local function ShowLayer(instance, level)
    layer = layer or CreateLayer()
    layerPane.instance = instance
    layerPane.levels[instance.id] = level
    followedMapID = WorldMapFrame:GetMapID()
    layer:Show()
    ShowZoneButton()
    Draw()
end

-- The game's map opening: it shows the player's map, so the layer shows the
-- player's floor (found by name too, for the drawings the game lacks).
local function OnWorldMapShow()
    droppedUntilReopen = false
    openedOnMapID = WorldMapFrame:GetMapID()
    local instance, level = PlayerMapToShow()
    if instance then ShowLayer(instance, level) else TurnOff() end
end

-- Map in dungeons or a tab switched while the game's map is open: the layer
-- shows or hides to match, on the floor the game's map shows. On the map it
-- opened on, a floor found by name (the drawings the game lacks) stays.
-- Nothing is drawn over any other map that isn't one of the instance's
-- floors, nor after the player left them until the map opens again.
function WorldMapOverlay:Recheck()
    if not ns.UI.GameMapOpen() then return TurnOff() end
    if droppedUntilReopen then return end
    local playerInstance, playerLevel = PlayerMapToShow()
    if not playerInstance then return TurnOff() end
    local mapID = WorldMapFrame:GetMapID()
    local instance, level = ns.UI.MapFloor(mapID, playerInstance)
    if not instance and mapID == openedOnMapID then instance, level = playerInstance, playerLevel end
    if instance ~= playerInstance then return TurnOff() end
    ShowLayer(instance, level)
end

-- The floor chips: whenever the game's map shows a dungeon or raid map the
-- game splits into floors (its map group), a row of the window's floor tabs
-- (text tab chips, UI/RecipeBand.lua) on a dark strip centred at the top of
-- the map area, one chip per floor in the game's order, the shown floor
-- gold. They show with either Map in dungeons setting. A chip is named like
-- NeedRoll's level on that floor (as the window's tabs), else with the
-- game's own floor name. A click turns the game's map to that floor through
-- the game's C_Map.OpenWorldMap, as the zone links on NeedRoll's pages do,
-- never through the map's own SetMapID (that would taint it); NeedRoll's map
-- layer follows like it follows the game's floor dropdown (FollowGameMap).
-- In combat NeedRoll never moves the game's map: the chip's tooltip says
-- why, and so does chat on a click.
local FLOOR_BAR_TOP = 8           -- from the map area's top edge
local FLOOR_BAR_PAD_X = 10        -- the strip's room left and right of the chips
local FLOOR_BAR_PAD_Y = 4         -- and above and below them
local FLOOR_BAR_SIDE_ROOM = 180   -- kept free at each side: the game's floor dropdown and map buttons
local FLOOR_BAR_FILL = { 0, 0, 0, 0.6 }          -- dark enough for the chips' words on the map art
local FLOOR_BAR_EDGE = { 1, 0.82, 0, 0.38 }      -- a faint gold outline

local floorBar  -- the chips' holder on the game's map (.strip, .chips), made as the map loads

-- The game's floors in the group the map `mapID` belongs to, when it is a
-- dungeon or raid map with more than one; else nil.
local function DungeonFloors(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    if not (info and info.mapType == Enum.UIMapType.Dungeon) then return nil end
    local group = C_Map.GetMapGroupID(mapID)
    local floors = group and C_Map.GetMapGroupMembersInfo(group)
    if not floors or #floors < 2 then return nil end
    return floors
end

-- A floor's chip label: NeedRoll's name for its level, else the game's
-- name for the floor, else "Level N".
local function FloorLabel(floor, index)
    local instance, level = ns.UI.MapFloor(floor.mapID, layerPane.instance)
    if instance then return ns.UI.LevelName(instance, level) end
    if floor.name and floor.name ~= "" then return floor.name end
    return L["Level %d"]:format(index)
end

-- Turns the game's map to the floor `mapID`; in combat, says why it can't.
local function ShowFloor(mapID)
    if mapID == WorldMapFrame:GetMapID() then return end
    if ns.UI.MapLinksInCombat() then return ns.UI.SayNoFloorChangeInCombat() end
    ns.UI:WithGameMap(C_Map.OpenWorldMap, mapID)
end

-- Out of combat a chip needs no words; in combat it says why it can't.
local function ShowFloorChipTooltip(chip)
    if not ns.UI.MapLinksInCombat() then return end
    local r, g, b = unpack(Theme.tip.text)
    GameTooltip:SetOwner(chip, "ANCHOR_BOTTOM")
    GameTooltip:SetText(ns.UI.NO_FLOOR_CHANGE_IN_COMBAT, r, g, b, true)
    GameTooltip:Show()
end

local function NewFloorChip(strip)
    local chip = ns.RecipeBand.Chip(strip)
    PassRightClicks(chip)
    chip:HookScript("OnEnter", ShowFloorChipTooltip)
    chip:HookScript("OnLeave", function() GameTooltip:Hide() end)
    chip:SetScript("OnClick", function(self) ShowFloor(self.mapID) end)
    return chip
end

-- Lays the chips for `floors` out on the strip, on balanced, centred lines
-- as wide as the map area leaves between its corners, and sizes the strip
-- around them.
local function DrawFloorChips(floors, shownMapID)
    local strip, chips, chipsWidth = floorBar.strip, {}, 0
    for i, floor in ipairs(floors) do
        local chip = floorBar.chips[i] or NewFloorChip(strip.chipArea)
        floorBar.chips[i] = chip
        chip.mapID = floor.mapID
        chip:SetLabel(Theme:Label(FloorLabel(floor, i)))
        chip:Show()
        chips[i] = chip
        chipsWidth = chipsWidth + chip:GetWidth()
    end
    for i = #floors + 1, #floorBar.chips do floorBar.chips[i]:Hide() end
    local room = WorldMapFrame.ScrollContainer:GetWidth() - FLOOR_BAR_SIDE_ROOM * 2
    local width = math.max(1, math.min(chipsWidth, room))
    ns.RecipeBand.PlaceLines(strip.chipArea, chips, width, 0)
    for _, chip in ipairs(chips) do chip:Paint(chip.mapID == shownMapID) end
    local _, _, _, _, lastChipY = chips[#chips]:GetPoint()
    strip.chipArea:SetSize(width, -lastChipY + chips[#chips]:GetHeight())
    strip:SetSize(width + FLOOR_BAR_PAD_X * 2, strip.chipArea:GetHeight() + FLOOR_BAR_PAD_Y * 2)
end

-- While the game's map shows: the strip shows and redraws for each new map
-- (a floor picked here, in the game's dropdown, or walked to) and each new
-- width of the map area (the game's map made larger or smaller).
local function FollowGameMapForFloors()
    local mapID = WorldMapFrame:GetMapID()
    local width = WorldMapFrame.ScrollContainer:GetWidth()
    if mapID == floorBar.shownMapID and width == floorBar.shownWidth then return end
    floorBar.shownMapID, floorBar.shownWidth = mapID, width
    local floors = DungeonFloors(mapID)
    floorBar.strip:SetShown(floors ~= nil)
    if floors then DrawFloorChips(floors, mapID) end
end

-- The holder is a point at the top of the map area that is shown whenever
-- the game's map is, to follow it; the strip under it shows only on a
-- dungeon's floors. Neither takes the mouse: drags on the map around the
-- chips are the game's.
local function CreateFloorBar()
    local container = WorldMapFrame.ScrollContainer
    local holder = CreateFrame("Frame", nil, container)
    holder:SetSize(1, 1)
    holder:SetPoint("TOP", container, "TOP", 0, -FLOOR_BAR_TOP)
    holder:SetFrameLevel(WorldMapFrame:GetCanvas():GetFrameLevel() + ZONE_BUTTON_LEVELS_UP)
    holder.chips = {}
    local strip = CreateFrame("Frame", nil, holder)
    strip:SetPoint("TOP")
    Theme:Rounded(strip, FLOOR_BAR_FILL, FLOOR_BAR_EDGE)
    strip.chipArea = CreateFrame("Frame", nil, strip)
    strip.chipArea:SetPoint("TOPLEFT", FLOOR_BAR_PAD_X, -FLOOR_BAR_PAD_Y)
    strip:Hide()
    holder.strip = strip
    holder:SetScript("OnUpdate", FollowGameMapForFloors)
    return holder
end

-- The game's map opening again draws the chips afresh, even on the floor
-- they last showed: their names may differ now (another dungeon's levels).
local function RedrawFloorChips()
    floorBar.shownMapID = nil
end

-- NeedRoll's own pin on the game's map, drawn where a link that pins a spot
-- was clicked in combat (ns.UI.ShowOnMap), when NeedRoll's links can't run
-- the game's /mappin (UI/MainFrame.lua). One at a time, the latest winning;
-- it isn't saved, so a reload clears it. Its layer is laid like the dungeon
-- map's and shows only while the game's map shows the pin's map. Out of
-- combat a click on it runs /mappin through the same secure link, and the
-- game's pin then takes its place; Shift-click posts where it is in chat.
local PIN_ATLAS = "Waypoint-MapPin-Untracked"  -- the game's own map pin, untracked (gold)
local PIN_SIZE = 32
local PIN_LEVELS_UP = 50  -- over the dungeon map's layer (its widgets reach about 42 up), under the game's pins
-- How far the game's pin may sit from NeedRoll's (as part of the map's
-- width or height) and still be on it: /mappin takes x and y to a tenth of
-- a percent, so it can land up to half that away.
local SAME_SPOT = 0.001

local pinLayer  -- the layer with NeedRoll's pin (.pin), made the first time one is drawn
local pinned    -- NeedRoll's pin as a spot: { map = uiMapID, x, y from 0 to 1, name }; nil when there is none

-- Where the pin sits on `shownMap` (x, y from 0 to 1): on its own map as
-- pinned, on a map above it (its continent, Azeroth) where its zone lies on
-- that map; nil on any other map. So a pin on another zone shows on the
-- zoomed-out views too.
local function PinSpotOn(shownMap)
    if shownMap == pinned.map then return pinned.x, pinned.y end
    local map, checked = pinned.map, {}
    while map and map ~= 0 and not checked[map] do
        checked[map] = true
        local info = C_Map.GetMapInfo(map)
        map = info and info.parentMapID
        if map == shownMap then
            local left, right, top, bottom = C_Map.GetMapRectOnMap(pinned.map, shownMap)
            if not left then return nil end
            return left + pinned.x * (right - left), top + pinned.y * (bottom - top)
        end
    end
end

-- Places the pin on the game's canvas, which grows and shrinks with the
-- game's zoom, and shows it only while the game's map shows its map or one
-- above it.
local function FollowGameMapForPin()
    local pin = pinLayer.pin
    local shownMap = WorldMapFrame:GetMapID()
    local width, height = pinLayer.canvas:GetSize()
    if shownMap == pinLayer.placedMap and width == pinLayer.placedWidth and height == pinLayer.placedHeight then
        return
    end
    pinLayer.placedMap, pinLayer.placedWidth, pinLayer.placedHeight = shownMap, width, height
    local x, y = PinSpotOn(shownMap)
    pin:SetShown(x ~= nil)
    if not x then return end
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", pinLayer.canvas, "TOPLEFT", x * width, -y * height)
end

-- Where the pin is, in words, into the chat box the player is typing in
-- (or a new one): "Name located at (x, y) in Zone".
local function PostPinLocation()
    local info = C_Map.GetMapInfo(pinned.map)
    local text = L["%s located at (%.1f, %.1f) in %s"]:format(pinned.name, pinned.x * 100, pinned.y * 100,
        info and info.name or "")
    ns.UI.TypeInChat(text)
end

local function OnPinModifiedClick()
    if IsShiftKeyDown() then PostPinLocation() end
end

-- The pin's name, then what a click does: in combat, why it can't.
local function ShowPinTooltip(pin)
    local r, g, b = unpack(Theme.tip.text)
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:SetText(pinned.name)
    GameTooltip:AddLine(ns.UI.MapLinksInCombat() and ns.UI.NO_MAP_PINS_IN_COMBAT or L["Click to pin on your map"],
        r, g, b, true)
    GameTooltip:AddLine(L["Shift-click to post its location in chat"], r, g, b, true)
    GameTooltip:Show()
end

-- The pin's button. Out of combat a plain click lands on the secure link
-- laid over it while hovered; a click that reaches the pin itself (in
-- combat) places nothing.
local function CreatePin(canvas)
    local pin = CreateFrame("Button", nil, canvas)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    pin:SetFrameLevel(canvas:GetFrameLevel() + 1)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetPoint("CENTER")
    Theme:FitAtlas(pin.icon, PIN_ATLAS, PIN_SIZE)
    pin:RegisterForClicks("LeftButtonUp")
    PassRightClicks(pin)
    pin:SetScript("OnClick", function()
        if IsShiftKeyDown() then return PostPinLocation() end
        if ns.UI.MapLinksInCombat() then ns.UI.SayNoMapPinsInCombat() end
    end)
    pin:SetScript("OnEnter", function(self)
        ShowPinTooltip(self)
        ns.UI.HoverMapLink(self, pinned, OnPinModifiedClick)
    end)
    pin:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        ns.UI.LeaveMapLink(self)
    end)
    return pin
end

local function CreatePinLayer()
    local newLayer = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    newLayer.clip = CreateFrame("Frame", nil, newLayer)
    newLayer.clip:SetClipsChildren(true)
    newLayer.canvas = CreateFrame("Frame", nil, newLayer.clip)
    LayOnGameMap(newLayer, PIN_LEVELS_UP)
    newLayer.pin = CreatePin(newLayer.canvas)
    newLayer:SetScript("OnUpdate", FollowGameMapForPin)
    newLayer:Hide()
    return newLayer
end

local function DrawPin()
    pinLayer = pinLayer or CreatePinLayer()
    pinLayer.placedMap = nil
    pinLayer:Show()
end

local function RemovePin()
    pinned = nil
    if not pinLayer then return end
    pinLayer:Hide()
    if GameTooltip:GetOwner() == pinLayer.pin then GameTooltip:Hide() end
    ns.UI.LeaveMapLink(pinLayer.pin)
end

-- Draws NeedRoll's pin at x, y (0 to 1) on the game's map `map`, named
-- `name`, in place of any earlier one. Before the game's map has loaded,
-- it is drawn once it does (HookWorldMap).
function WorldMapOverlay:ShowPin(map, x, y, name)
    pinned = { map = map, x = x, y = y, name = name }
    if WorldMapFrame then DrawPin() end
end

-- The game's pin placed on NeedRoll's (by /mappin through NeedRoll's pin,
-- or the player's own click there) takes its place.
ns:On("USER_WAYPOINT_UPDATED", function()
    local waypoint = pinned and C_Map.GetUserWaypoint()
    if not (waypoint and waypoint.uiMapID == pinned.map) then return end
    local position = waypoint.position
    if math.abs(position.x - pinned.x) <= SAME_SPOT and math.abs(position.y - pinned.y) <= SAME_SPOT then
        RemovePin()
    end
end)

-- A right-click released over the game's map area (not the quest log beside
-- it) turns the layer off, whatever the game does with it: on a map with no
-- parent the game's right-click does nothing, so the map ID never changes
-- and FollowGameMap alone would keep the layer up. Watched for the whole
-- screen, like the window's Back clicks (UI/MainFrame.lua), so the map's own
-- scripts stay untouched.
ns:On("GLOBAL_MOUSE_UP", function(button)
    if button ~= "RightButton" or not (layer and layer:IsVisible()) then return end
    if not WorldMapFrame.ScrollContainer:IsMouseOver() then return end
    TurnOff(true)
end)

-- The game's map may load after NeedRoll (Blizzard_WorldMap), so the hooks
-- go on at login or when it loads. Hooking only watches: the map's own
-- scripts still run as the game's.
local worldMapHooked = false
local function HookWorldMap()
    if worldMapHooked or not WorldMapFrame then return end
    worldMapHooked = true
    WorldMapFrame:HookScript("OnShow", OnWorldMapShow)
    WorldMapFrame:HookScript("OnHide", function() TurnOff() end)
    floorBar = CreateFloorBar()
    WorldMapFrame:HookScript("OnShow", RedrawFloorChips)
    if pinned then DrawPin() end
end
ns:On("PLAYER_LOGIN", HookWorldMap)
ns:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then HookWorldMap() end end)

-- Boss portraits draw once the game has made them.
ns:On("PORTRAITS_UPDATED", function()
    if layer and layer:IsVisible() then Draw() end
end)
