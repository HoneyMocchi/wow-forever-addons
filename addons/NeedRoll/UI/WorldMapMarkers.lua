-- Quest givers, library books and travel portals on the game's world map.
-- On a zone or city map the game's map (the M key, left to the game) shows
-- where to pick up the dungeon and raid quests the character can take,
-- where the library books they haven't found yet sit, and where WoW:
-- Forever's travel portals stand (Data/Portals.lua; either side's, as who
-- may take one isn't known). Each marker shows only on the zone map
-- its spot is on: none on the continent or world views, none on a dungeon's
-- floors. Only quests whose suggested level is within LEVEL_WINDOW of the
-- character's get one. The icons (ICONS below):
--   QuestNormal                 the game's "!": a dungeon quest you can pick
--                               up from this NPC now (no steps before it, or
--                               all of them done)
--   Quest-Campaign-Available    the "!" of a questline: this NPC gives the
--                               next step of a questline that leads to a
--                               dungeon quest, which needs those steps first
--   Campaign-QuestLog-LoreBook  a library book not handed in and not in the
--                               bags or bank
--   PortalPurple                a travel portal, named for where it goes
-- One marker per NPC holds every quest that sends the player there; it takes
-- the quest icon when any of them can be picked up now. Its tooltip names
-- the NPC and each quest; a click opens NeedRoll's window on the first quest
-- above the map (a book's: the Library tab), as the dungeon map's markers do.
-- A portal's click pins it on the game's map, as NeedRoll's map links do.
-- Right-clicks go through to the game's map. Settings' "Quest givers on the
-- world map", "Books on the world map" and "Portals on the world map" turn
-- each kind off.
--
-- NeedRoll's dice in the map's bottom right corner (the mode button) picks
-- what the markers show, saved account-wide (NeedRollDB.mapMarkers):
--   incomplete  what is still to do, as above (the default), and the portals
--   all         also, faded: quests done or in the quest log (on their own
--               giver), quests under their level, books handed in or held
--   off         no markers
--
-- As NeedRoll's own pin (UI/WorldMapOverlay.lua), the markers sit on a layer
-- of NeedRoll's laid over the game's canvas, and NeedRoll only reads the
-- game's map: hooks on its showing, its map ID and canvas size polled while
-- it shows. A map data provider would run NeedRoll's code inside the map's
-- own refresh and taint it, and the game would then block Shift-clicking its
-- pins into chat.
local _, ns = ...
local Theme = ns.Theme
local L = ns.L

local WorldMapMarkers = {}
ns.WorldMapMarkers = WorldMapMarkers

-- The game's atlases each kind of marker shows (Data/IconList.lua's
-- "Quests and Map"; every client has them), and the size each is fitted
-- into. Hovered, a marker grows by HOVER_GROW.
local ICONS = {
    quest = "QuestNormal",                 -- a dungeon quest to pick up here now
    chain = "Quest-Campaign-Available",    -- the next step of a questline leading to one
    book = "Campaign-QuestLog-LoreBook",   -- a library book not found yet
    portal = "PortalPurple",               -- a travel portal: purple, as it is either side's
}
local ICON_SIZES = { quest = 20, chain = 20, book = 22, portal = 22 }
local HOVER_GROW = 1.25
-- A marker for something done or out of reach (mode "all" only) is drawn
-- greyed out at this alpha.
local FADED_ALPHA = 0.5
-- Only dungeon and raid quests whose suggested level is at most this many
-- levels above or below the character's get markers: the rest are long
-- done or far off.
local LEVEL_WINDOW = 10
-- Over the game's canvas: over the dungeon map's layer (1 up), under the
-- zone button (45) and NeedRoll's own pin (50), under the game's pins (2000 on).
local MARKER_LEVELS_UP = 30
-- Quest log changes come in bursts (QUEST_LOG_UPDATE fires for every
-- objective), so the markers are worked out again at most this often, in
-- seconds, while the map shows.
local REBUILD_GAP = 0.5
-- The server flags a quest handed in, and a level gained shows in
-- UnitLevel, a moment after the event: the markers are worked out again
-- this many seconds later too.
local LATE_FLAG_DELAY = 1

-- The tabs whose quests get markers.
local QUEST_CATEGORIES = { "DUNGEON", "RAID" }

local PassRightClicks = ns.UI.PassRightClicks

local layer  -- the markers' layer on the game's map (.markerPool), made the first time the map shows
-- The markers to draw, by the game's map ID they show on (BuildMarkers),
-- worked out again once stale and the game's map shows.
local markerSet = { byMap = {}, isStale = true, builtAt = -math.huge }

-- What the markers show (see the top of the file), in the order a click on
-- the mode button goes through them.
local MODES = { "all", "incomplete", "off" }
local DEFAULT_MODE = "incomplete"

local function Mode()
    local mode = ns.db and ns.db.mapMarkers
    return tContains(MODES, mode) and mode or DEFAULT_MODE
end

-- Where each spot lies on the game's map: { mapID, x, y (0 to 1) }, or
-- false when its zone or place there isn't known. Kept per spot (the data's
-- spot tables stay for the session): finding it asks the game for the zone's
-- map and the spot's world position.
local placeOfSpot = {}
local function SpotPlace(spot)
    local place = placeOfSpot[spot]
    if place == nil then
        local info, x, y = ns.UI.ZoneSpot(spot)
        place = (info and x and y) and { mapID = info.mapID, x = x, y = y } or false
        placeOfSpot[spot] = place
    end
    return place or nil
end

local function IsLevelFor(minLevel)
    return not minLevel or ns.PlayerLevel() >= minLevel
end

-- Quests to take ------------------------------------------------------------

-- Whether `quest` is for the character: their side's and class's (a class
-- token as UnitClass's second return).
local function IsForCharacter(quest, side, classToken)
    if quest.side and quest.side ~= side then return false end
    return not quest.classes or Theme:ClassToken(quest.classes) == classToken
end

-- Whether `quest`'s suggested level (else its level) is within LEVEL_WINDOW
-- of the character's; a quest whose level isn't known always is.
local function IsNearPlayerLevel(quest)
    local level = quest.suggestedLevel or quest.level
    return not level or math.abs(level - ns.PlayerLevel()) <= LEVEL_WINDOW
end

-- Why the character can't take `quest` any more, as its faded marker's
-- tooltip says it: done, or in the quest log, under any version's ID. Nil
-- while they can.
local function TakenReason(quest)
    local AnyVersion = ns.UI.AnyQuestVersion
    if AnyVersion(quest, C_QuestLog.IsQuestFlaggedCompleted) then return L["Completed"] end
    if AnyVersion(quest, C_QuestLog.IsOnQuest) then return L["In log"] end
    return nil
end

-- Adds dungeon `instance`'s quests to QuestsToTake's `found` (byID: the
-- same entries by quest ID): a quest found under an earlier dungeon only
-- gains this one in its instances.
local function AddInstanceQuests(found, byID, instance, side, classToken, showsAll)
    for _, quest in ipairs(ns.Data:Quests(instance.id)) do
        local toTake = byID[quest.id]
        if toTake then
            table.insert(toTake.instances, instance)
        elseif IsForCharacter(quest, side, classToken) and IsNearPlayerLevel(quest) then
            toTake = { quest = quest, instances = { instance }, takenReason = TakenReason(quest) }
            byID[quest.id] = toTake
            if showsAll or not toTake.takenReason then table.insert(found, toTake) end
        end
    end
end

-- The dungeon and raid quests to mark, each once, in the order the tabs
-- list their dungeons: { quest (as its first dungeon lists it), instances
-- (every dungeon listing it), takenReason (TakenReason) }. The character's
-- side's and class's near their level, only for tabs that are on; those
-- done or in the quest log only when `showsAll`.
local function QuestsToTake(side, classToken, showsAll)
    local found, byID = {}, {}
    for _, category in ipairs(QUEST_CATEGORIES) do
        for _, instance in ipairs(ns.Modules:IsOn(category) and ns.Data:List(category) or {}) do
            AddInstanceQuests(found, byID, instance, side, classToken, showsAll)
        end
    end
    return found
end

-- The steps of `quest`'s questline before it, each a list of quest IDs (one,
-- or one per class or reward choice, or with `all` a step whose quests are
-- all needed: Data:FittingChain): Data/Chains.lua's chain for the
-- character's side and class, else the quest's own chain fields. Empty when
-- it is on no chain.
local function EarlierSteps(quest, side, classToken)
    local steps, at = ns.Data:Chain(quest.id, side, classToken)
    local earlier = {}
    if steps and at then
        for index = 1, at - 1 do earlier[index] = steps[index] end
        return earlier
    end
    for index, id in ipairs(quest.chain or { quest.chainStart }) do earlier[index] = { id } end
    return earlier
end

-- Whether the character is partway along the questline: one of its steps
-- is in the quest log, so they know where to go.
local function IsOnQuestline(earlier)
    for _, ids in ipairs(earlier) do
        for _, id in ipairs(ids) do
            if C_QuestLog.IsOnQuest(id) then return true end
        end
    end
    return false
end

-- Who hands the character chain step `ids`: of its quests to pick up
-- (Data.QuestsToPickUp), the first for their side and class (Data/Chains.lua),
-- and that quest's giver and level needed; one marker per step, so of a
-- step whose quests are all needed only its first member not done is
-- marked. For a first step Data/Chains.lua doesn't know, the quest's own
-- chainGiverNpc. Nil when the step starts from an item, its giver stands
-- inside a dungeon or isn't known.
local function StepGiver(quest, ids, side, classToken)
    local toPickUp = ns.Data.QuestsToPickUp(ids, C_QuestLog.IsQuestFlaggedCompleted)
    for _, id in ipairs(toPickUp) do
        local step = ns.Data.chainSteps[id]
        if step and ns.Data:StepFits(id, side, classToken) then
            if not step.giverNpc or step.giverInside then return nil end
            return step.giverNpc, id, step.minLevel
        end
    end
    if toPickUp[1] ~= quest.chainStart or quest.chainStartItem or quest.chainGiverInside then return nil end
    return quest.chainGiverNpc, quest.chainStart, nil
end

-- `pickup` while the character's level reaches `minLevel`. Under it: in
-- mode "all" the pickup faded, its tooltip saying the level it needs; else nil.
local function CheckLevel(pickup, minLevel, showsAll)
    if IsLevelFor(minLevel) then return pickup end
    if not showsAll then return nil end
    pickup.fadedBecause = L["Requires level %s"]:format(minLevel)
    return pickup
end

-- A quest done or in the quest log (mode "all"), as a faded pickup on its
-- own giver, with the icon of its type: a questline's "!" when steps come
-- before it. Nil when its giver stands inside a dungeon or isn't known.
local function TakenPickup(toTake, side, classToken)
    local quest = toTake.quest
    if not quest.giverNpc or quest.giverInside then return nil end
    local hasSteps = #EarlierSteps(quest, side, classToken) > 0
    return { kind = hasSteps and "chain" or "quest", toTake = toTake, npc = quest.giverNpc, questID = quest.id,
             fadedBecause = toTake.takenReason }
end

-- Where the character picks up `toTake` (QuestsToTake) next, as a pickup:
-- { kind, toTake, npc (the giver), questID (the quest that giver hands
-- out) }, and for a questline step (the step to pick up) and stepCount (the
-- dungeon quest's own step), numbered as the questline page numbers them
-- (Data:StepNumbers: lead-ins a player may skip have no number). Kind
-- "quest": the quest itself, with no steps before it or all of them done;
-- "chain": its questline's next step. In mode "all" (`showsAll`) a quest
-- done or in the quest log, or under the level it needs, comes back faded
-- (`fadedBecause`: why, for its tooltip). Nil when a step is in the quest
-- log already, or the quest or step starts from an item or inside a
-- dungeon; in mode "incomplete" also when the level is too low.
local function NextPickup(toTake, side, classToken, showsAll)
    if toTake.takenReason then return TakenPickup(toTake, side, classToken) end
    local quest = toTake.quest
    local earlier = EarlierSteps(quest, side, classToken)
    if IsOnQuestline(earlier) then return nil end
    local nextIndex = ns.Data:NextStepIndex(earlier, C_QuestLog.IsQuestFlaggedCompleted)
    if not nextIndex then
        if not quest.giverNpc or quest.giverInside then return nil end
        return CheckLevel({ kind = "quest", toTake = toTake, npc = quest.giverNpc, questID = quest.id },
            quest.minLevel, showsAll)
    end
    local npc, stepID, minLevel = StepGiver(quest, earlier[nextIndex], side, classToken)
    if not npc then return nil end
    local numbers, numberedCount = ns.Data:StepNumbers(earlier)
    return CheckLevel({ kind = "chain", toTake = toTake, npc = npc, questID = stepID, step = numbers[nextIndex],
                        stepCount = numberedCount + 1 }, minLevel or quest.minLevel, showsAll)
end

-- The marker set ---------------------------------------------------------------

local function AddToMap(byMap, marker)
    local markers = byMap[marker.place.mapID] or {}
    byMap[marker.place.mapID] = markers
    table.insert(markers, marker)
end

-- Puts `pickup` on its giver's marker, made when it is the first there: one
-- marker per spot.
local function AddPickup(byMap, markerAt, pickup)
    local spot = ns.Data:NpcSpot(pickup.npc, pickup.questID)
    local place = spot and SpotPlace(spot)
    if not place then return end
    local marker = markerAt[spot]
    if not marker then
        marker = { place = place, pickups = {} }
        markerAt[spot] = marker
        AddToMap(byMap, marker)
    end
    table.insert(marker.pickups, pickup)
end

-- A marker's quests in tooltip order, the first opened by a click: those
-- not faded first, then those to pick up now, then by level.
local function PickupOrder(a, b)
    local isFadedA, isFadedB = a.fadedBecause ~= nil, b.fadedBecause ~= nil
    if isFadedA ~= isFadedB then return isFadedB end
    if a.kind ~= b.kind then return a.kind == "quest" end
    local levelA, levelB = a.toTake.quest.level or 0, b.toTake.quest.level or 0
    if levelA ~= levelB then return levelA < levelB end
    return a.toTake.quest.id < b.toTake.quest.id
end

-- Sorts a giver's marker's quests, then takes its look from the first: drawn
-- faded only when every quest on it is, its icon "quest" when any of those
-- drawn is to pick up now.
local function FinishQuestMarker(marker)
    table.sort(marker.pickups, PickupOrder)
    local first = marker.pickups[1]
    marker.kind, marker.isFaded = first.kind, first.fadedBecause ~= nil
end

local function AddQuestGivers(byMap, showsAll)
    if not ns.Modules:IsOn("QUEST_GIVER_MARKERS") then return end
    local side = ns.PlayerFaction()
    local _, classToken = UnitClass("player")
    local markerAt = {}  -- spot -> its marker
    for _, toTake in ipairs(QuestsToTake(side, classToken, showsAll)) do
        local pickup = NextPickup(toTake, side, classToken, showsAll)
        if pickup then AddPickup(byMap, markerAt, pickup) end
    end
    for _, marker in pairs(markerAt) do FinishQuestMarker(marker) end
end

-- A marker on each of the book's spots; `fadedBecause`, a found book's
-- status ("Handed in"), draws them faded.
local function AddBookSpots(byMap, book, fadedBecause)
    for _, spot in ipairs(book.spots) do
        local place = SpotPlace(spot)
        if place then
            AddToMap(byMap, { kind = "book", place = place, book = book, isFaded = fadedBecause ~= nil,
                              fadedBecause = fadedBecause })
        end
    end
end

-- The books of the character's side they haven't found: not handed in, not
-- in the bags or bank. With `showsAll` the found ones too, faded.
local function AddBooks(byMap, showsAll)
    if not ns.Modules:IsOn("LIBRARY_BOOK_MARKERS") then return end
    local LibraryBooks = ns.LibraryBooks
    local side = ns.PlayerFaction()
    for _, book in ipairs(LibraryBooks.ForSide(side)) do
        local status = LibraryBooks.Status(book, side)
        if status == LibraryBooks.NOT_FOUND then
            AddBookSpots(byMap, book, nil)
        elseif showsAll then
            AddBookSpots(byMap, book, LibraryBooks.STATUS_TEXT[status])
        end
    end
end

-- A marker on each travel portal's spot, named for where it goes ("Portal
-- to Orgrimmar", the game's name for that map). Nothing to do or find, so
-- the same in modes "incomplete" and "all". A portal whose destination
-- the game's map doesn't know isn't marked.
local function AddPortals(byMap)
    if not ns.Modules:IsOn("PORTAL_MARKERS") then return end
    for _, portal in ipairs(ns.Data.portals) do
        local place = SpotPlace(portal.spot)
        local destination = C_Map.GetMapInfo(portal.destination)
        if place and destination and destination.name then
            AddToMap(byMap, { kind = "portal", place = place, portal = portal,
                              name = L["Portal to %s"]:format(destination.name) })
        end
    end
end

-- Whether Settings leave any kind of marker on (with the tabs they need).
-- With all of them off the mode button would do nothing, so it hides.
local function AnyKindSwitchedOn()
    local Modules = ns.Modules
    return Modules:IsOn("QUEST_GIVER_MARKERS") or Modules:IsOn("LIBRARY_BOOK_MARKERS")
        or Modules:IsOn("PORTAL_MARKERS")
end

-- Works out every marker anew for the mode picked: { kind, place, isFaded,
-- pickups (quests), book, or portal and name }, by the map ID they show
-- on. Portals and books go first, so a quest giver standing on one's spot
-- is drawn over it. The mode button shows or hides with the Settings
-- switches it follows.
local function BuildMarkers()
    local byMap = {}
    local mode = Mode()
    if mode ~= "off" then
        AddPortals(byMap)
        AddBooks(byMap, mode == "all")
        AddQuestGivers(byMap, mode == "all")
    end
    markerSet.byMap, markerSet.isStale, markerSet.builtAt = byMap, false, GetTime()
    if not layer then return end
    layer.placedMap = nil
    layer.modeButton:SetShown(AnyKindSwitchedOn())
end

-- Tooltips -----------------------------------------------------------------------

-- The names of every dungeon a quest is listed for: "Deadmines, Shadowfang Keep".
local function DungeonNames(toTake)
    local names = {}
    for _, instance in ipairs(toTake.instances) do table.insert(names, instance.name) end
    return table.concat(names, ", ")
end

local function LevelText(level)
    return level and L["Level %d"]:format(level) or nil
end

-- A questline step's name and level: Data/Chains.lua's, else the names the
-- quest data keeps of its chain's start.
local function StepNameAndLevel(pickup)
    local id, quest = pickup.questID, pickup.toTake.quest
    local step = ns.Data.chainSteps[id]
    local name = step and step.name or ns.Data.questNames[id]
        or (id == quest.chainStart and quest.chainStartName) or L["quest %s"]:format(id)
    return name, step and step.level
end

-- Whether `pickup` hands out the dungeon quest itself, not a questline
-- step before it (a taken quest's pickup may have a questline's icon).
local function IsQuestItself(pickup)
    return pickup.questID == pickup.toTake.quest.id
end

-- The name of the NPC a marker sends the player to, in the player's
-- language once the game has it (Core/Names.lua renames the data in place).
local function GiverName(pickup)
    local quest = pickup.toTake.quest
    if IsQuestItself(pickup) then return quest.giver end
    local step = ns.Data.chainSteps[pickup.questID]
    return step and step.giver or quest.chainGiver
end

-- Why a faded marker's quest or book is faded ("Completed"), in grey.
local function AddFadedLine(fadedBecause)
    if not fadedBecause then return end
    local quiet = Theme.tip.quiet
    GameTooltip:AddLine(fadedBecause, quiet[1], quiet[2], quiet[3], true)
end

-- A quest's lines: its name, level and dungeons; for a questline's step,
-- the step's name and level, then which step it is of the way to the
-- quest. Last, why it is faded, when it is.
local function AddPickupLines(pickup)
    local text, info = Theme.tip.text, Theme.tip.info
    local quest, toTake = pickup.toTake.quest, pickup.toTake
    if IsQuestItself(pickup) then
        GameTooltip:AddLine(Theme:JoinDots(quest.name, LevelText(quest.level)), text[1], text[2], text[3], true)
        GameTooltip:AddLine(DungeonNames(toTake), info[1], info[2], info[3], true)
    else
        local stepName, stepLevel = StepNameAndLevel(pickup)
        GameTooltip:AddLine(Theme:JoinDots(stepName, LevelText(stepLevel)), text[1], text[2], text[3], true)
        GameTooltip:AddLine(L["Questline step %d of %d, leads to %s (%s)"]:format(pickup.step, pickup.stepCount,
            quest.name, DungeonNames(toTake)), info[1], info[2], info[3], true)
    end
    AddFadedLine(pickup.fadedBecause)
end

local function ShowQuestTooltip(marker)
    local pickups = marker.data.pickups
    GameTooltip:SetText(GiverName(pickups[1]) or L["Quest giver"])
    for _, pickup in ipairs(pickups) do AddPickupLines(pickup) end
    local hint = Theme.tip.hint
    GameTooltip:AddLine(L["Click to open it in NeedRoll"], hint[1], hint[2], hint[3], true)
end

-- The book's name (the game's, once it has the item), where it sits and
-- how to get it.
local function ShowBookTooltip(marker)
    local book = marker.data.book
    GameTooltip:SetText(C_Item.GetItemNameByID(book.item) or book.name)
    local text, hint = Theme.tip.text, Theme.tip.hint
    local where = Theme:JoinDots(book.place, book.how)
    if where ~= "" then GameTooltip:AddLine(where, text[1], text[2], text[3], true) end
    AddFadedLine(marker.data.fadedBecause)
    GameTooltip:AddLine(L["Click to open the Library"], hint[1], hint[2], hint[3], true)
end

-- Where the portal goes, then what a click does: in combat, why it can't
-- pin it.
local function ShowPortalTooltip(marker)
    GameTooltip:SetText(marker.data.name)
    local hint = Theme.tip.hint
    local clickText = ns.UI.MapLinksInCombat() and ns.UI.NO_MAP_PINS_IN_COMBAT or L["Click to pin on your map"]
    GameTooltip:AddLine(clickText, hint[1], hint[2], hint[3], true)
end

local function ShowMarkerTooltip(marker)
    GameTooltip:SetOwner(marker, "ANCHOR_RIGHT")
    local kind = marker.data.kind
    if kind == "portal" then
        ShowPortalTooltip(marker)
    elseif kind == "book" then
        ShowBookTooltip(marker)
    else
        ShowQuestTooltip(marker)
    end
    GameTooltip:Show()
end

-- Markers --------------------------------------------------------------------------

-- Fits the marker's icon, grown while hovered.
local function FitIcon(marker, isHovered)
    local kind = marker.data.kind
    Theme:FitAtlas(marker.icon, ICONS[kind], ICON_SIZES[kind] * (isHovered and HOVER_GROW or 1))
end

-- Greys out a marker for something done or out of reach (mode "all").
local function FadeIcon(marker)
    local isFaded = marker.data.isFaded == true
    marker.icon:SetDesaturated(isFaded)
    marker.icon:SetAlpha(isFaded and FADED_ALPHA or 1)
end

-- The mouse on a marker: it grows and shows its tooltip. A portal's marker
-- is a map link (UI.HoverMapLink): out of combat a secure button laid over
-- it runs the game's /mappin on the portal, so the click never reaches
-- OnMarkerClick. Any other marker is no map link (a nil spot).
local function HoverMarker(marker)
    FitIcon(marker, true)
    ShowMarkerTooltip(marker)
    local portal = marker.data.portal
    ns.UI.HoverMapLink(marker, portal and portal.spot)
end

-- A click opens NeedRoll's window above the map, which stays open: on the
-- Library tab for a book, else on the first quest's page in its first
-- dungeon (UI:ShowFromWorldMap, as the dungeon map's markers). A portal's
-- click gets here only in combat, when the game's pin can't be placed:
-- NeedRoll's own pin marks it instead, saying why in chat (ns.UI.ShowOnMap).
-- NeedRoll's window stays shut for a portal.
local function OnMarkerClick(marker)
    local data = marker.data
    if data.portal then return ns.UI.ShowOnMap(data.portal.spot, data.name) end
    if data.book then return ns.UI:ShowLibraryFromWorldMap() end
    local toTake = data.pickups[1].toTake
    ns.UI:ShowFromWorldMap(toTake.instances[1], nil, toTake.quest)
end

local function CreateMarker(canvas)
    local marker = CreateFrame("Button", nil, canvas)
    marker:SetFrameLevel(canvas:GetFrameLevel() + 1)
    marker.icon = marker:CreateTexture(nil, "ARTWORK")
    marker.icon:SetPoint("CENTER")
    marker:RegisterForClicks("LeftButtonUp")
    PassRightClicks(marker)
    marker:SetScript("OnClick", OnMarkerClick)
    marker:SetScript("OnEnter", HoverMarker)
    marker:SetScript("OnLeave", function(self)
        FitIcon(self, false)
        GameTooltip:Hide()
        ns.UI.LeaveMapLink(self)
    end)
    return marker
end

-- The pool's `index`th marker, made when the pool is shorter.
local function PooledMarker(index)
    local pool = layer.markerPool
    pool[index] = pool[index] or CreateMarker(layer.canvas)
    return pool[index]
end

-- A marker under the mouse whose marker set changed: it stays grown and its
-- tooltip (and a portal's map link) follows, or the tooltip goes with it.
-- A hidden tooltip still names its last owner, so only a shown one says
-- the mouse is on that marker.
local function FollowHoveredMarker()
    local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
    if not (owner and owner.icon and owner:GetParent() == layer.canvas) then return end
    if not owner:IsShown() then return GameTooltip:Hide() end
    HoverMarker(owner)
end

-- Draws the markers of the game's map `mapID` on a canvas `width` by
-- `height` (the game's zoom), each at its own size.
local function Draw(mapID, width, height)
    local markers = markerSet.byMap[mapID] or {}
    for index, data in ipairs(markers) do
        local marker = PooledMarker(index)
        marker.data = data
        FitIcon(marker, false)
        FadeIcon(marker)
        marker:SetSize(marker.icon:GetSize())
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", layer.canvas, "TOPLEFT", data.place.x * width, -data.place.y * height)
        marker:Show()
    end
    for index = #markers + 1, #layer.markerPool do layer.markerPool[index]:Hide() end
    FollowHoveredMarker()
end

-- While the game's map shows: the markers are worked out again once stale
-- (at most every REBUILD_GAP), and drawn again when the map shown or the
-- canvas's size (its zoom) changed. Nothing while the canvas has no size.
local function FollowGameMap()
    if markerSet.isStale and GetTime() - markerSet.builtAt >= REBUILD_GAP then BuildMarkers() end
    local mapID = WorldMapFrame:GetMapID()
    local width, height = layer.canvas:GetSize()
    if mapID == layer.placedMap and width == layer.placedWidth and height == layer.placedHeight then return end
    if width <= 0 or height <= 0 then return end
    layer.placedMap, layer.placedWidth, layer.placedHeight = mapID, width, height
    Draw(mapID, width, height)
end

-- The mode button -----------------------------------------------------------------
-- NeedRoll's dice (the window title's icon, UI/MainFrame.lua's TITLE_ICON)
-- in the map area's bottom left corner: the zone button owns the bottom
-- right (UI/WorldMapOverlay.lua), the game keeps its own buttons in the top
-- corners. A click goes to the next mode (MODES); its look shows the mode:
-- in colour for "all", with a small quest "!" at its corner for
-- "incomplete", greyed out and dimmed for "off".
local MODE_BUTTON_ATLAS = "lootroll-toast-icon-need-up"
local MODE_BUTTON_SIZE = 26
local MODE_BUTTON_ICON_SIZE = 24      -- the dice fitted into it
local MODE_BUTTON_INSET = 10          -- from the map area's left and bottom edges, as the zone button's
local MODE_BUTTON_LEVELS_UP = MARKER_LEVELS_UP + 4  -- over the game's canvas: just over the markers (+ 33)
local MODE_BADGE_ATLAS, MODE_BADGE_SIZE = "QuestNormal", 12
local MODE_OFF_ALPHA = 0.5
local MODE_BUTTON_HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"  -- the minimap button's glow

-- What `mode` shows, as the button's tooltip says it.
local function ModeText(mode)
    if mode == "all" then return L["On: every quest giver and book, those done faded"] end
    if mode == "incomplete" then return L["On: only quests you haven't done and books you haven't found"] end
    return L["Off"]
end

local function NextMode(mode)
    for index, each in ipairs(MODES) do
        if each == mode then return MODES[index % #MODES + 1] end
    end
    return DEFAULT_MODE
end

local function ShowModeButtonTooltip(button)
    local text, info, hint = Theme.tip.text, Theme.tip.info, Theme.tip.hint
    local mode = Mode()
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")  -- towards the map, away from its left edge
    GameTooltip:SetText(L["NeedRoll map markers"])
    GameTooltip:AddLine(ModeText(mode), text[1], text[2], text[3], true)
    if mode ~= "off" then
        GameTooltip:AddLine(L["Dungeon and raid quests within %d levels of yours"]:format(LEVEL_WINDOW),
            info[1], info[2], info[3], true)
    end
    GameTooltip:AddLine(L["Click to change"], hint[1], hint[2], hint[3], true)
    GameTooltip:Show()
end

local function ShowModeLook(button)
    local mode = Mode()
    button.icon:SetDesaturated(mode == "off")
    button.icon:SetAlpha(mode == "off" and MODE_OFF_ALPHA or 1)
    button.badge:SetShown(mode == "incomplete")
end

-- Saves the next mode and draws the markers for it at once: the click is
-- the player's, so it doesn't wait for REBUILD_GAP.
local function CycleMode(button)
    ns.db.mapMarkers = NextMode(Mode())
    ShowModeLook(button)
    BuildMarkers()
    FollowGameMap()
    if GameTooltip:GetOwner() == button then ShowModeButtonTooltip(button) end
end

local function CreateModeButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(MODE_BUTTON_SIZE, MODE_BUTTON_SIZE)
    button:SetPoint("BOTTOMLEFT", MODE_BUTTON_INSET, MODE_BUTTON_INSET)
    button:SetFrameLevel(WorldMapFrame:GetCanvas():GetFrameLevel() + MODE_BUTTON_LEVELS_UP)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    Theme:FitAtlas(button.icon, MODE_BUTTON_ATLAS, MODE_BUTTON_ICON_SIZE)
    button.icon:SetPoint("CENTER")
    button.badge = button:CreateTexture(nil, "OVERLAY")
    Theme:FitAtlas(button.badge, MODE_BADGE_ATLAS, MODE_BADGE_SIZE)
    button.badge:SetPoint("BOTTOMRIGHT")
    button:SetHighlightTexture(MODE_BUTTON_HIGHLIGHT, "ADD")
    button:RegisterForClicks("LeftButtonUp")
    PassRightClicks(button)
    button:SetScript("OnClick", CycleMode)
    button:SetScript("OnEnter", ShowModeButtonTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    ShowModeLook(button)
    return button
end

-- Layer --------------------------------------------------------------------------

local function CreateLayer()
    local newLayer = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
    newLayer.clip = CreateFrame("Frame", nil, newLayer)
    newLayer.clip:SetClipsChildren(true)
    newLayer.canvas = CreateFrame("Frame", nil, newLayer.clip)
    ns.WorldMapOverlay.LayOnGameMap(newLayer, MARKER_LEVELS_UP)
    newLayer.modeButton = CreateModeButton(newLayer)
    newLayer.markerPool = {}
    newLayer:SetScript("OnUpdate", FollowGameMap)
    return newLayer
end

-- The game's map opening: markers stale while it was shut are worked out
-- at once, and drawn on the first frame.
local function OnWorldMapShow()
    layer = layer or CreateLayer()
    if markerSet.isStale then BuildMarkers() end
    layer.placedMap = nil
end

-- The markers are worked out again the next time the game's map shows, or
-- shortly while it shows: quests taken or handed in, books found, a level
-- gained, a new zone (the nearest givers picked again, UI/Lists.lua), a
-- switch in Settings (Core/Init.lua's Modules:Set).
local function Invalidate()
    markerSet.isStale = true
end
WorldMapMarkers.Invalidate = Invalidate

local function InvalidateNowAndLater()
    Invalidate()
    C_Timer.After(LATE_FLAG_DELAY, Invalidate)
end
for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "BAG_UPDATE_DELAYED",
    "ZONE_CHANGED_NEW_AREA", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED" }) do
    ns:On(event, Invalidate)
end
ns:On("QUEST_TURNED_IN", InvalidateNowAndLater)
ns:On("PLAYER_LEVEL_UP", InvalidateNowAndLater)

-- The game's map may load after NeedRoll (Blizzard_WorldMap), so the hook
-- goes on at login or when it loads. Hooking only watches: the map's own
-- scripts still run as the game's.
local worldMapHooked = false
local function HookWorldMap()
    if worldMapHooked or not WorldMapFrame then return end
    worldMapHooked = true
    WorldMapFrame:HookScript("OnShow", OnWorldMapShow)
    if WorldMapFrame:IsShown() then OnWorldMapShow() end
end
ns:On("PLAYER_LOGIN", HookWorldMap)
ns:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then HookWorldMap() end end)
