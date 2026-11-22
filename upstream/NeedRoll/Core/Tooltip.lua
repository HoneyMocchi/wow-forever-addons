-- Where an item drops, on every item tooltip in the game (bags, inspect, chat links, loot):
-- "Arugal - Shadowfang Keep" under the item's own lines, for items on a dungeon or raid boss's or
-- trash list, each after the world map's dungeon or raid entrance icon (the tabs' icons). While
-- Settings shows the collection ticks, the first line ends with the loot grid's tick for items
-- with a look: in color once the look is collected, greyed out until then. Under them, each
-- dungeon quest with the item as a reward (to pick or always given) that the player's side can
-- take: "Hidden Enemies - Ragefire Chasm" after the maps' quest marker.
-- Settings can turn the lines off (ns.db.tooltipSources = false), and with them the dungeon
-- quest chain lines on quest tooltips (UI/QuestChainNotes.lua).
local _, ns = ...
local L = ns.L

local Tooltip = {}
ns.Tooltip = Tooltip

local MAX_NAMED = 3 -- sources named before "+N more"
local PLACES = { "DUNGEON", "RAID" }
local LOOT_POOLS = { TRASH = true, SHARED = true } -- encounters that are a place's shared loot, not one boss's
-- Each source line starts with how the item is got: its tab's icon
-- (UI.TabIcon: the world map's dungeon or raid entrance, PvP's swords, and
-- so on), or the maps' quest marker (ns.Data.markerIcons.quest) for a quest.
-- Drawn in an 18px box.
local ICON_SIZE = 18
local QUEST_ATLAS = "Crosshair_Quest_96"
-- The entrance portals have empty space around them, so each is cut down to
-- its middle (CROP of each edge left out): the portal shows bigger while the
-- line grows no taller than the uncut atlas would make it.
local CROPPED = { DUNGEON = true, RAID = true }
local CROP = 0.15
local sourceIcons = {} -- tab key or "QUEST" -> its icon's markup, made once

-- `atlas` cut down by CROP as |T markup, which takes the file's size and
-- the cut in its pixels. Nil when the client doesn't say where it lies.
local function CroppedMarkup(atlas)
    local info = C_Texture.GetAtlasInfo(atlas)
    local u = info and (info.rightTexCoord - info.leftTexCoord) -- the atlas's share of the file, across and down
    local v = info and (info.bottomTexCoord - info.topTexCoord)
    if not (info and info.file and u > 0 and v > 0) then return nil end
    local fileWidth, fileHeight = info.width / u, info.height / v
    local function Pixels(coord, size) return math.floor(coord * size + 0.5) end
    local left, right = info.leftTexCoord + u * CROP, info.rightTexCoord - u * CROP
    local top, bottom = info.topTexCoord + v * CROP, info.bottomTexCoord - v * CROP
    return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(info.file, ICON_SIZE, ICON_SIZE,
        Pixels(1, fileWidth), Pixels(1, fileHeight), Pixels(left, fileWidth), Pixels(right, fileWidth),
        Pixels(top, fileHeight), Pixels(bottom, fileHeight))
end

-- `atlas` as |A markup fitted inside the 18px box, keeping its shape.
local function FittedMarkup(atlas)
    local info = C_Texture.GetAtlasInfo(atlas)
    local width, height = ICON_SIZE, ICON_SIZE
    if info and info.width > 0 and info.height > 0 then
        local scale = ICON_SIZE / math.max(info.width, info.height)
        width, height = math.floor(info.width * scale + 0.5), math.floor(info.height * scale + 0.5)
    end
    return ("|A:%s:%d:%d|a"):format(atlas, height, width)
end

-- The icon for a source on the tab `key` (DUNGEON, PVP, PROFESSION...), or
-- for a quest ("QUEST"), as inline markup plus a space; "" for a tab with
-- no icon. Also before the Wishlist's source lines (UI/Wishlist.lua).
function Tooltip.SourceIcon(key)
    local icon = sourceIcons[key]
    if icon then return icon end
    local atlas = key == "QUEST" and QUEST_ATLAS or ns.UI.TabIcon(key)
    if not atlas then return "" end
    icon = (CROPPED[key] and CroppedMarkup(atlas) or FittedMarkup(atlas)) .. " "
    sourceIcons[key] = icon
    return icon
end
local TICK_ATLAS = "common-icon-checkmark" -- the loot grid's tick (UI/LootGrid.lua)
local TICK_SCALE = 1.2 -- against the line's font size, as in the loot grid

-- Built at the first item tooltip (the loot lists never change once loaded): item ID ->
-- { { category, text, isPool } } for drops in tab and boss order, and item ID ->
-- { { category, text, side } } for the dungeon quests rewarding it.
local dropSources, questSources
-- item ID -> the tooltip lines last made for it, for the tabs on and side in `madeFor`.
local madeLines, madeFor = {}, nil

-- One line per item and boss (or loot pool) of `instance`, however often it is listed there.
local function AddDropSources(category, instance)
    local isAdded = {}
    for _, encounter in ipairs(instance.encounters) do
        local isPool = LOOT_POOLS[encounter.id] == true
        for _, entry in ipairs(encounter.loot) do
            local itemID = entry.itemID
            local who = isPool and encounter.id or ns.Data:DropperName(instance, encounter, entry)
            if itemID and not isAdded[itemID .. who] then
                isAdded[itemID .. who] = true
                local text = encounter.id == "TRASH" and L["Trash - %s"]:format(instance.name)
                    or L["%s - %s"]:format(isPool and encounter.name or who, instance.name)
                dropSources[itemID] = dropSources[itemID] or {}
                table.insert(dropSources[itemID], { category = category, text = Tooltip.SourceIcon(category) .. text,
                    isPool = isPool })
            end
        end
    end
end

-- One line per quest of `instance` rewarding the item (to pick or always given), and side.
local function AddQuestSources(category, instance)
    for _, quest in ipairs(ns.Data:Quests(instance.id)) do
        local text = Tooltip.SourceIcon("QUEST") .. L["%s - %s"]:format(quest.name, instance.name)
        for _, field in ipairs({ "rewards", "choice" }) do
            for _, itemID in ipairs(quest[field] or {}) do
                local list = questSources[itemID] or {}
                questSources[itemID] = list
                local isListed = false
                for _, source in ipairs(list) do
                    if source.text == text and source.side == quest.side then isListed = true end
                end
                if not isListed then table.insert(list, { category = category, text = text, side = quest.side }) end
            end
        end
    end
end

local function BuildSources()
    dropSources, questSources = {}, {}
    for _, category in ipairs(PLACES) do
        for _, instance in ipairs(ns.Data:List(category)) do
            AddDropSources(category, instance)
            AddQuestSources(category, instance)
        end
    end
end

-- The first three of `shown` onto `lines` as { text, color }, then a muted
-- "+N more" line. Quest tooltips' chain lines too (UI/QuestChainNotes.lua).
function Tooltip.AddNamed(lines, shown)
    local colors = ns.Theme.tip
    for i = 1, math.min(#shown, MAX_NAMED) do table.insert(lines, { shown[i], colors.info }) end
    if #shown > MAX_NAMED then table.insert(lines, { L["+%d more"]:format(#shown - MAX_NAMED), colors.hint }) end
end

-- The item's lines for the tabs that are on, as { text, color }: bosses
-- first, then trash and shared loot, then the quests the player's side can
-- take, the first three of the drops and of the quests named and the rest
-- counted. Nil for an item NeedRoll doesn't list.
local function LinesFor(itemID)
    if not dropSources then BuildSources() end
    local drops, quests = dropSources[itemID], questSources[itemID]
    if not drops and not quests then return nil end
    local side = ns.PlayerFaction()
    local madeForNow = tostring(ns.Modules:IsOn("DUNGEON")) .. tostring(ns.Modules:IsOn("RAID")) .. side
    if madeForNow ~= madeFor then madeLines, madeFor = {}, madeForNow end
    local lines = madeLines[itemID]
    if lines then return lines end
    local shown = {}
    for _, wantPools in ipairs({ false, true }) do
        for _, source in ipairs(drops or {}) do
            if source.isPool == wantPools and ns.Modules:IsOn(source.category) then table.insert(shown, source.text) end
        end
    end
    lines = {}
    Tooltip.AddNamed(lines, shown)
    shown = {}
    for _, source in ipairs(quests or {}) do
        local isOurs = not source.side or source.side == side
        if isOurs and ns.Modules:IsOn(source.category) then table.insert(shown, source.text) end
    end
    Tooltip.AddNamed(lines, shown)
    madeLines[itemID] = lines
    return lines
end

-- Whether `frame` is one of NeedRoll's main windows (one per window style).
local function IsOwnWindow(frame)
    local Theme = ns.Theme
    for _, skin in ipairs(Theme.skins) do
        if frame == _G[Theme:WindowName(skin)] then return true end
    end
    return false
end

-- NeedRoll's own window already shows where its items are from.
local function IsInOwnWindow(frame)
    for _ = 1, 30 do
        if not frame or frame == UIParent then return false end
        if IsOwnWindow(frame) then return true end
        frame = frame.GetParent and frame:GetParent()
    end
    return false
end

-- Whether NeedRoll adds its lines to `tooltip`: Settings has them on, and
-- it is neither forbidden to addons (the game's protected tooltips) nor in
-- NeedRoll's own window. Quest tooltips ask too (UI/QuestChainNotes.lua).
function Tooltip.CanAddLines(tooltip)
    if not ns.db or not Tooltip:IsOn() then return false end
    if tooltip.IsForbidden and tooltip:IsForbidden() then return false end
    return not (tooltip.GetOwner and IsInOwnWindow(tooltip:GetOwner()))
end

-- The tick is a texture of its own over the end of the line, so it can be
-- greyed out (inline texture markup can't be). The line ends with the same
-- atlas inline, drawn black, which holds its room and sits under it; the
-- tooltip's ticks hide when it is cleared.
local function NextTick(tooltip)
    local ticks = tooltip.needRollTicks
    if not ticks then
        ticks = { n = 0 } -- n: how many are in use on the tooltip now
        tooltip.needRollTicks = ticks
        tooltip:HookScript("OnTooltipCleared", function(self)
            for _, tick in ipairs(self.needRollTicks) do tick:Hide() end
            self.needRollTicks.n = 0
        end)
    end
    ticks.n = ticks.n + 1
    local tick = ticks[ticks.n]
    if not tick then
        tick = tooltip:CreateTexture(nil, "OVERLAY")
        tick:SetAtlas(TICK_ATLAS)
        ticks[ticks.n] = tick
    end
    return tick
end

-- `text` as a line ending with the tick, greyed out unless `known`. A
-- tooltip showing another player's gear (inspect) can keep its text's size
-- secret; its line ends with the tick as inline markup instead, tinted grey
-- (not truly greyed out) unless `known`.
local function AddTickedLine(tooltip, text, known)
    local name = tooltip:GetName()
    local nextLine = name and _G[name .. "TextLeft" .. (tooltip:NumLines() + 1)]
    local font = nextLine or GameTooltipText
    local r, g, b = unpack(ns.Theme.tip.info)
    local fontSize = ns.Plain(font and select(2, font:GetFont()))
    local size = math.floor((fontSize or 12) * TICK_SCALE + 0.5)
    if tooltip.HasSecretValues and tooltip:HasSecretValues() then
        local tint = known and "" or ":0:0:140:140:140"
        tooltip:AddLine(("%s |A:%s:%d:%d%s|a"):format(text, TICK_ATLAS, size, size, tint), r, g, b)
        return
    end
    local room = ("|A:%s:%d:%d:0:0:0:0:0|a"):format(TICK_ATLAS, size, size)
    tooltip:AddLine(("%s %s"):format(text, room), r, g, b)
    local line = name and _G[name .. "TextLeft" .. tooltip:NumLines()]
    if not line then return end
    local tick = NextTick(tooltip)
    tick:SetSize(size, size)
    tick:ClearAllPoints()
    -- The line's width can be secret too: then the tick goes by its right edge.
    local width = ns.Plain(line:GetStringWidth())
    if width then
        tick:SetPoint("LEFT", line, "LEFT", width - size, 0)
    else
        tick:SetPoint("RIGHT", line, "RIGHT")
    end
    tick:SetDesaturated(not known)
    tick:Show()
end

local function OnItemTooltip(tooltip, itemID)
    if type(itemID) ~= "number" or issecretvalue(itemID) or not Tooltip.CanAddLines(tooltip) then return end
    local lines = LinesFor(itemID)
    if not lines or #lines == 0 then return end
    local known
    if ns.db.collectionTicks ~= false then known = ns.Items:Collected(itemID) end
    for i, line in ipairs(lines) do
        local text, color = line[1], line[2]
        if i == 1 and known ~= nil and tooltip.HookScript then
            AddTickedLine(tooltip, text, known)
        else
            tooltip:AddLine(text, color[1], color[2], color[3])
        end
    end
end

-- Names arrived from the game client (Core/Names.lua): built again at the next tooltip.
function Tooltip:Forget()
    dropSources, questSources = nil, nil
    madeLines, madeFor = {}, nil
end

function Tooltip:SetOn(on)
    if on then ns.db.tooltipSources = nil else ns.db.tooltipSources = false end
end

function Tooltip:IsOn()
    return ns.db.tooltipSources ~= false
end

-- Every tooltip showing an item (Blizzard's tooltip data processor), or
-- the older OnTooltipSetItem script on the game's item tooltips.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        OnItemTooltip(tooltip, data and data.id)
    end)
else
    local function OnSetItem(tooltip)
        local _, link = tooltip:GetItem()
        OnItemTooltip(tooltip, ns.Items:IDFromLink(link))
    end
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        if tooltip then tooltip:HookScript("OnTooltipSetItem", OnSetItem) end
    end
end
