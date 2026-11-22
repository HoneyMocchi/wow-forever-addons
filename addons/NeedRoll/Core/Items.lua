-- Async item info. WoW: Forever removes the global GetItemInfo, so item
-- names, icons and quality come from C_Item and may not be cached yet.
local _, ns = ...

ns.Items = {}
local waiting = {} -- item ID -> callbacks to run once the game sends the item

-- Calls callback(itemID) once the item's data is loaded on the client.
function ns.Items:Load(itemID, callback)
    if C_Item.IsItemDataCachedByID(itemID) then
        callback(itemID)
        return
    end
    waiting[itemID] = waiting[itemID] or {}
    table.insert(waiting[itemID], callback)
    C_Item.RequestLoadItemDataByID(itemID)
end

ns:On("ITEM_DATA_LOAD_RESULT", function(itemID, success)
    local callbacks = waiting[itemID]
    if not callbacks then return end
    waiting[itemID] = nil
    if not success then return end
    for _, callback in ipairs(callbacks) do callback(itemID) end
end)

-- The item ID in an item link ("|Hitem:6948:..."), or nil without one.
function ns.Items:IDFromLink(link)
    if not link then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- An item's tooltip lines (the game's C_TooltipInfo data), or nil while it
-- isn't cached (lines would be missing).
function ns.Items.TooltipLines(itemID)
    if not C_Item.IsItemDataCachedByID(itemID) then return nil end
    local ok, info = pcall(C_TooltipInfo.GetItemByID, itemID)
    return ok and info and info.lines or {}
end

-- A modified click on an item, as anywhere in the game: Shift links it in
-- chat, Ctrl tries it on. `fallbackLink` stands in while the game hasn't
-- the item's own link yet.
function ns.Items:HandleModifiedClick(itemID, fallbackLink)
    local link = select(2, C_Item.GetItemInfo(itemID)) or fallbackLink
    if link then HandleModifiedItemClick(link) end
end

-- An item's quality. Forever's C_Item.GetItemQualityByID can return nil for
-- Common items even once their name is cached, so fall back to GetItemInfo's
-- quality, and treat a cached item with no quality at all as Common. Quest
-- items can also come back as Poor (grey) though they are Common, so a Poor
-- quest item counts as Common.
function ns.Items:Quality(itemID)
    local quality = C_Item.GetItemQualityByID(itemID) or select(3, C_Item.GetItemInfo(itemID))
        or Enum.ItemQuality.Common
    if quality == Enum.ItemQuality.Poor
        and select(6, C_Item.GetItemInfoInstant(itemID)) == Enum.ItemClass.Questitem then
        quality = Enum.ItemQuality.Common
    end
    return quality
end

-- Whether the character has collected an item's look in their transmog
-- collection, from this item or another with the same appearance: true or
-- false, or nil for items with no appearance (rings, potions). Cached per
-- item until the collection changes; asked only once the item's info has
-- loaded. Shared by the loot grid's ticks and the drop sources on item
-- tooltips (Core/Tooltip.lua).
local NO_LOOK = {} -- kept in place of nil, so items with no look are asked once
local collectedByItem = {}

function ns.Items:Collected(itemID)
    local known = collectedByItem[itemID]
    if known == NO_LOOK then return nil end
    if known ~= nil then return known end
    local _, sourceID = C_TransmogCollection.GetItemInfo(itemID)
    if not sourceID then
        collectedByItem[itemID] = NO_LOOK
        return nil
    end
    local info = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
    known = (info and (info.appearanceIsCollected or info.sourceIsCollected))
        or C_TransmogCollection.PlayerHasTransmog(itemID) or false
    collectedByItem[itemID] = known
    return known
end

-- A look collected or lost: asked again. Registered ahead of the loot
-- grid's own handler (UI loads after Core), which redraws its ticks.
local function ForgetCollected() wipe(collectedByItem) end
ns:On("TRANSMOG_COLLECTION_UPDATED", ForgetCollected)
ns:On("TRANSMOG_COLLECTION_SOURCE_ADDED", ForgetCollected)
ns:On("TRANSMOG_COLLECTION_SOURCE_REMOVED", ForgetCollected)
