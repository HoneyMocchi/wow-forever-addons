-- Vendor reads: when the player opens any merchant window, every item it
-- sells is read (item ID, price and whether it is in limited supply), with
-- where the vendor stands, and handed to each item filter that wants some
-- of them (see Item filters). Two kinds of stock have a filter each:
--   * recipes: every item that teaches a profession (recipes, patterns,
--     plans, schematics, formulas, manuals and fishing books);
--   * rare stock: any other item only a few vendors sell (rare as in hard
--     to find, not the Rare quality), the limited supply, faction and
--     special stock Search names a vendor for. Everyday stock (flour,
--     thread, vials, food, drink, arrows, reagents sold everywhere) is in
--     Data/VendorItems.lua's common stock and grey junk is skipped.
--
-- NeedRoll's vendor data comes from Classic's database and what Wowhead
-- once listed, and WoW: Forever added vendors and moved stock no source
-- has. So an item a window offers is saved when NeedRoll doesn't know that
-- vendor sells it: a recipe no profession list has, or one that
-- Data/KnownVendorRecipes.lua doesn't list for that vendor; rare stock that
-- Data/VendorItems.lua doesn't list for that vendor. What no copy has sent
-- yet goes to other copies through drop sharing (V1 messages for recipes,
-- S1 for rare stock, see Vendor messages in Core/Drops.lua), the way new
-- quests and trainer ranks do. A copy hearing one saves the items marked
-- heard: anyone can send such a message, so heard reads are never shown and
-- never sent again, and the scraper's `ingest` only lists them for Mike to
-- check, while it builds his own reads into the data. Once the data lists
-- an item for that vendor, a read of its window forgets the saved one.
--
-- None of this calls anything the game blocks in combat: the merchant,
-- item and map calls aren't restricted, and messages wait out the game's
-- addon message lockdowns in the outbox (ns.AddonMessages).
--
-- Saved with no player names (heard ones too), recipes in
-- NeedRollDB.vendorRecipes and rare stock in NeedRollDB.vendorItems, both
-- laid out the same:
--     [npcID] = { name = "Kendor Kabonka" (English clients only: the scraper files vendors by their
--             English names), map = <uiMapID>, x = <tenths of a percent>, y, instance = <instance ID,
--             0 outside dungeons and raids>, build = <the game build>, at = <time()>,
--         sides = { a = true, h = true } (the sides it was read on),
--         heard = true (heard from another copy, not read here),
--         items = { [itemID] = { price = <copper>, limited = true (limited supply),
--             shared = true (sent, or heard from another copy: not sent again) } } }
local _, ns = ...

local Vendors = {}
ns.Vendors = Vendors

local Plain = ns.Plain

-- The read at MERCHANT_SHOW, and one more at MERCHANT_UPDATE when the game
-- hadn't sent the whole list yet (an item without its ID).
local READS_PER_VISIT = 2
local NAME_MAX = 40       -- bytes of a vendor's name saved
local VENDORS_MAX = 500   -- vendors saved of each kind; past it a heard one isn't saved, and a read drops the oldest
local ITEMS_MAX = 200     -- items saved per vendor (a vendor sells far fewer)
-- Heard reads are kept only so the player's own read of the same items
-- isn't sent again, and anyone in the guild or group can send them, so
-- far fewer are kept: past these a heard vendor, or a heard item, isn't
-- saved.
local HEARD_VENDORS_MAX = 100 -- heard vendors saved of each kind
local HEARD_ITEMS_MAX = 40    -- items saved per heard vendor
Vendors.HEARD_VENDORS_MAX, Vendors.HEARD_ITEMS_MAX = HEARD_VENDORS_MAX, HEARD_ITEMS_MAX -- for the smoke tests
-- The game's limited-supply count for an item it has no limit on.
local UNLIMITED = -1
-- Recipe items (the game's item class 9) of these subclasses teach a
-- profession, Leatherworking (1) to Fishing (9); subclass 0, Book, teaches
-- none.
local RECIPE_CLASS = Enum.ItemClass.Recipe
local FIRST_PROFESSION_SUBCLASS = Enum.ItemRecipeSubclass.Leatherworking
local LAST_PROFESSION_SUBCLASS = Enum.ItemRecipeSubclass.Fishing

local clientBuild = tonumber((select(2, GetBuildInfo()))) -- the game build, saved with each read

-- Item filters -----------------------------------------------------------------
-- Each kind of item NeedRoll wants from vendors is a filter: { Wants =
-- function(item) (whether it wants that read item), Take = function(vendor,
-- items) (what it does with the ones it wants, which may be none) }. A read
-- hands every filter the vendor (see OpenVendor; isWhole is false when the
-- game never sent the whole list) and the items it wants.
local filters = {}

function Vendors.AddFilter(filter)
    filters[#filters + 1] = filter
end

-- Reading ------------------------------------------------------------------------

-- The merchant window's filter ("All", the player's class or specs, "Bind
-- on Equip") hides items from the list the game hands addons too, so a read
-- shows them all and then puts the filter back as the player had it, before
-- the game draws the window again. The game has no "All" filter to switch to
-- when LE_LOOT_FILTER_ALL is missing, so the list is read as it is.
local function WithEveryItemShown(read)
    local shownFilter, everyItem = Plain(GetMerchantFilter()), LE_LOOT_FILTER_ALL
    local isFiltered = shownFilter ~= nil and everyItem ~= nil and shownFilter ~= everyItem
    if isFiltered then SetMerchantFilter(everyItem) end
    local ok, items, isWhole = pcall(read)
    if isFiltered then SetMerchantFilter(shownFilter) end
    if not ok then error(items, 0) end
    return items, isWhole
end

-- One item of the open merchant window as { item = <item ID>, price =
-- <copper>, limited = true for limited supply }; nil while the game hasn't
-- sent it.
local function ReadMerchantItem(index)
    local itemID, info = Plain(GetMerchantItemID(index)), C_MerchantFrame.GetItemInfo(index)
    if type(itemID) ~= "number" or not info then return nil end
    local price, available = Plain(info.price), Plain(info.numAvailable)
    return { item = itemID, price = type(price) == "number" and price or 0,
        limited = type(available) == "number" and available ~= UNLIMITED or nil }
end

-- Every item the open merchant window sells, and whether the game had sent
-- the whole list (none missing, and not empty).
local function ReadMerchantItems()
    local items, count = {}, Plain(GetMerchantNumItems()) or 0
    for index = 1, count do items[#items + 1] = ReadMerchantItem(index) end
    return items, count > 0 and #items == count
end

-- The open vendor as a read names it: { npc, name (English clients only),
-- side, map, x, y, instance, build }.
local function OpenVendor(npcID)
    local name = Plain(UnitName("npc"))
    local isEnglish = GetLocale():match("^en") ~= nil
    local map, x, y, instance = ns.Drops.Where()
    return { npc = npcID, name = isEnglish and type(name) == "string" and ns.CutToBytes(name, NAME_MAX) or nil,
        side = ns.Drops.SideLetter(), map = map, x = x, y = y, instance = instance, build = clientBuild }
end

local visit -- while a merchant window is open: { reads = <tries>, done = true once read, reading = true during one }

-- Reads the open merchant window once the game has sent its list, and
-- hands it to every filter.
local function ReadVendor()
    if not (ns.db and visit) or visit.done or visit.reading or visit.reads >= READS_PER_VISIT then return end
    local npcID = ns.NpcIDOf("npc")
    if npcID == 0 then
        visit.done = true
        return
    end
    visit.reads, visit.reading = visit.reads + 1, true
    local ok, items, isWhole = pcall(WithEveryItemShown, ReadMerchantItems)
    visit.reading = false
    if not ok then error(items, 0) end
    -- MERCHANT_UPDATE tries again; the last try takes what it got.
    if not isWhole and visit.reads < READS_PER_VISIT then return end
    visit.done = true
    local vendor = OpenVendor(npcID)
    vendor.isWhole = isWhole
    for _, filter in ipairs(filters) do
        local wanted = {}
        for _, item in ipairs(items) do
            if filter.Wants(item) then wanted[#wanted + 1] = item end
        end
        filter.Take(vendor, wanted)
    end
end

ns:On("MERCHANT_SHOW", function()
    visit = { reads = 0 }
    ReadVendor()
end)
ns:On("MERCHANT_UPDATE", ReadVendor)
ns:On("MERCHANT_CLOSED", function() visit = nil end)

-- Kinds of stock ---------------------------------------------------------------------

-- Whether item `itemID` teaches a profession, as the player's game says.
function Vendors.IsRecipeItem(itemID)
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    classID, subclassID = Plain(classID), Plain(subclassID)
    return classID == RECIPE_CLASS and type(subclassID) == "number"
        and subclassID >= FIRST_PROFESSION_SUBCLASS and subclassID <= LAST_PROFESSION_SUBCLASS
end

-- Whether item `itemID` is rare stock (see the top of this file): an item
-- the game has (a heard message can name any number), no recipe, not
-- everyday stock and not grey junk. An item whose quality the game hasn't
-- sent yet counts as Common (ns.Items:Quality).
function Vendors.IsRareStock(itemID)
    return Plain(C_Item.DoesItemExistByID(itemID)) == true and not Vendors.IsRecipeItem(itemID)
        and not ns.Data:IsCommonStock(itemID) and ns.Items:Quality(itemID) ~= Enum.ItemQuality.Poor
end

-- Each kind of stock is saved in its own table, NeedRollDB[savedKey], and
-- sent as its own message, `version` (see Vendor messages in
-- Core/Drops.lua). IsWanted(itemID) says whether an item, read or heard, is
-- of that kind on this client; IsKnown(npcID, itemID) whether NeedRoll's
-- data knows the vendor sells it. Both kinds share the vendor lane's
-- messages of a day (see Lanes in Core/Drops.lua), and recipes, first in
-- KINDS, are queued first.
local RECIPES = {
    savedKey = "vendorRecipes",
    version = "V1",
    IsWanted = Vendors.IsRecipeItem,
    -- A profession list has the item, and the vendor is listed selling it.
    IsKnown = function(npcID, itemID)
        return ns.Data:ProfessionItems()[itemID] == true and ns.Data:KnownVendorRecipe(npcID, itemID)
    end,
}
local RARE_STOCK = {
    savedKey = "vendorItems",
    version = "S1",
    IsWanted = Vendors.IsRareStock,
    IsKnown = function(npcID, itemID) return ns.Data:KnownVendorItem(npcID, itemID) end,
}
local KINDS = { RECIPES, RARE_STOCK }
local KIND_OF_VERSION = { [RECIPES.version] = RECIPES, [RARE_STOCK.version] = RARE_STOCK }

-- Saving a read ----------------------------------------------------------------------

-- The items of `items` NeedRoll doesn't know vendor `npcID` sells, of
-- stock `kind`, in item ID order, at most ITEMS_MAX.
local function UnknownItems(kind, npcID, items)
    local unknown = {}
    for _, item in ipairs(items) do
        if not kind.IsKnown(npcID, item.item) then unknown[#unknown + 1] = item end
    end
    table.sort(unknown, function(a, b) return a.item < b.item end)
    for index = #unknown, ITEMS_MAX + 1, -1 do unknown[index] = nil end
    return unknown
end

-- Makes room for one more saved vendor: drops the heard vendor read
-- longest ago, or with none heard, the vendor read longest ago.
local function DropOldestVendor(saved)
    local oldestID, oldest
    for npcID, vendor in pairs(saved) do
        local isOlder = not oldest or (vendor.heard and not oldest.heard)
            or (vendor.heard == oldest.heard and (vendor.at or 0) < (oldest.at or 0))
        if isOlder then oldestID, oldest = npcID, vendor end
    end
    if oldestID then saved[oldestID] = nil end
end

-- The sides a vendor was read on, with `side` added (n adds none).
local function WithSide(sides, side)
    if side == "a" or side == "h" then sides[side] = true end
    return sides
end

-- Saves what the player's own read of a vendor found of stock `kind` that
-- NeedRoll doesn't know, in place of anything of that kind saved for that
-- vendor before (heard reads too): an item the data has caught up with is
-- forgotten, and a vendor left with none goes. True when an item was saved
-- that other copies haven't heard yet. An item already sent, or heard,
-- keeps its shared mark.
local function SaveRead(kind, vendor, items)
    local saved = ns.db[kind.savedKey]
    local kept = saved[vendor.npc]
    local unknown = UnknownItems(kind, vendor.npc, items)
    if #unknown == 0 then
        saved[vendor.npc] = nil
        return false
    end
    if not kept and ns.CountKeys(saved) >= VENDORS_MAX then DropOldestVendor(saved) end
    local keptItems = kept and kept.items or {}
    local ownRead = kept and not kept.heard and kept or {}
    local savedItems, hasUnsent = {}, false
    for _, item in ipairs(unknown) do
        local isShared = keptItems[item.item] ~= nil and keptItems[item.item].shared or nil
        savedItems[item.item] = { price = item.price, limited = item.limited, shared = isShared }
        hasUnsent = hasUnsent or not isShared
    end
    saved[vendor.npc] = { name = vendor.name or ownRead.name, map = vendor.map, x = vendor.x, y = vendor.y,
        instance = vendor.instance, build = vendor.build, at = time(),
        sides = WithSide(ownRead.sides or {}, vendor.side), items = savedItems }
    return hasUnsent
end

-- Sharing --------------------------------------------------------------------------

-- A saved vendor as a vendor message names it: its side is the one it was
-- read on, or n when read on both.
local function MessageVendor(npcID, vendor)
    local sides = vendor.sides or {}
    local side = (sides.a and not sides.h) and "a" or (sides.h and not sides.a) and "h" or "n"
    return { npc = npcID, side = side, map = vendor.map or 0, x = vendor.x or 0, y = vendor.y or 0,
        instance = vendor.instance or 0, build = vendor.build, name = vendor.name }
end

-- A saved vendor's items of stock `kind` NeedRoll still doesn't know, in
-- item ID order, as { item, price, limited, saved = <the saved item> };
-- only the unsent ones when `onlyUnsent`.
local function SavedUnknownItems(kind, npcID, vendor, onlyUnsent)
    local unknown = {}
    for itemID, item in pairs(vendor.items) do
        if not (onlyUnsent and item.shared) and not kind.IsKnown(npcID, itemID) then
            unknown[#unknown + 1] = { item = itemID, price = item.price or 0, limited = item.limited, saved = item }
        end
    end
    table.sort(unknown, function(a, b) return a.item < b.item end)
    return unknown
end

-- The NPC IDs of the vendors in `saved` the player read themselves, lowest first.
local function OwnVendorIDs(saved)
    local npcIDs = {}
    for npcID, vendor in pairs(saved) do
        if not vendor.heard then npcIDs[#npcIDs + 1] = npcID end
    end
    table.sort(npcIDs)
    return npcIDs
end

-- The messages of every vendor of stock `kind` the player read since
-- time() `since`: { { vendor = <saved vendor>, text, items }, ... }, the
-- items each carries as SavedUnknownItems gives them, only the unsent ones
-- when `onlyUnsent`.
local function OwnMessages(kind, since, onlyUnsent)
    local messages = {}
    local saved = ns.db[kind.savedKey]
    for _, npcID in ipairs(OwnVendorIDs(saved)) do
        local vendor = saved[npcID]
        local items = (vendor.at or 0) >= since and SavedUnknownItems(kind, npcID, vendor, onlyUnsent) or {}
        local encoded = ns.Drops.EncodeVendorMessages(kind.version, MessageVendor(npcID, vendor), items)
        for _, message in ipairs(encoded) do
            message.vendor = vendor
            messages[#messages + 1] = message
        end
    end
    return messages
end

-- Queues the items this copy read that no copy has sent yet, recipes
-- first, marking each one queued shared. What doesn't fit today's vendor
-- messages waits for the next read or login.
function Vendors.Share()
    if not ns.db then return end
    for _, kind in ipairs(KINDS) do
        for _, message in ipairs(OwnMessages(kind, 0, true)) do
            if not ns.Drops.QueueLaneMessage("vendor", message.text) then return end
            for _, item in ipairs(message.items) do item.saved.shared = true end
        end
    end
end

-- The vendors the player read since time() `since`, as vendor messages of
-- the items NeedRoll still doesn't know they sell, sent or not: { { at, id,
-- text }, ... }, for a catch-up probe's answer (see Catch-up probes in
-- Core/Drops.lua).
function Vendors.Answers(since)
    local answers = {}
    if not ns.db then return answers end
    for _, kind in ipairs(KINDS) do
        for _, message in ipairs(OwnMessages(kind, since, false)) do
            answers[#answers + 1] = { at = message.vendor.at, id = message.text:match("^[^\t]*"), text = message.text }
        end
    end
    return answers
end

-- Heard reads ------------------------------------------------------------------------

-- How many of the vendors in `saved` were heard from other copies.
local function CountHeardVendors(saved)
    local count = 0
    for _, vendor in pairs(saved) do
        if vendor.heard then count = count + 1 end
    end
    return count
end

-- The saved vendor a heard read goes into: a heard vendor saved before, or
-- a new one; nil when VENDORS_MAX vendors, or HEARD_VENDORS_MAX heard ones,
-- are saved already.
local function HeardVendor(saved, heard)
    local kept = saved[heard.npc]
    if kept then return kept end
    if ns.CountKeys(saved) >= VENDORS_MAX or CountHeardVendors(saved) >= HEARD_VENDORS_MAX then return nil end
    kept = { name = heard.name, map = heard.map, x = heard.x, y = heard.y, instance = heard.instance,
        build = heard.build, at = time(), sides = {}, items = {}, heard = true }
    saved[heard.npc] = kept
    return kept
end

-- Adds a heard read's items to a saved vendor, marked shared, at most
-- HEARD_ITEMS_MAX to a heard vendor; true when any was new. The player's
-- own read of a vendor saw its whole window, so a heard read only marks
-- the items it has shared.
local function AddHeardItems(kept, items)
    local isNew = false
    for _, item in ipairs(items) do
        local keptItem = kept.items[item.item]
        if keptItem then
            isNew = isNew or not keptItem.shared
            keptItem.shared = true
        elseif kept.heard and ns.CountKeys(kept.items) < HEARD_ITEMS_MAX then
            kept.items[item.item] = { price = item.price, limited = item.limited, shared = true }
            isNew = true
        end
    end
    return isNew
end

-- Saves the items a vendor message from another copy carried (decoded by
-- Drops.DecodeVendorMessage) without the sender's name, marked heard (see
-- the top of this file) and shared, so this copy doesn't send them again.
-- Only items this client's game says are of the message's kind count: a
-- recipe for a V1 message, rare stock for an S1 one. What came of it: "new"
-- when it changed anything saved, "listed" when NeedRoll's data knows the
-- vendor sells every one, "skipped" when none was of its kind, else "known".
function Vendors.SaveHeard(heard)
    local kind = KIND_OF_VERSION[heard.version]
    local wanted = {}
    for _, item in ipairs(heard.items) do
        if kind.IsWanted(item.item) then wanted[#wanted + 1] = item end
    end
    if #wanted == 0 then return "skipped" end
    local unknown = UnknownItems(kind, heard.npc, wanted)
    if #unknown == 0 then return "listed" end
    local kept = HeardVendor(ns.db[kind.savedKey], heard)
    if not kept then return "known" end
    local isNewSide = false
    if kept.heard then
        isNewSide = (heard.side == "a" or heard.side == "h") and not kept.sides[heard.side]
        kept.sides = WithSide(kept.sides, heard.side)
        kept.name = kept.name or heard.name
    end
    local isNew = AddHeardItems(kept, unknown)
    return (isNew or isNewSide) and "new" or "known"
end

--[==[@debug@
-- Dev builds only: the recipes Data/KnownVendorRecipes.lua says a vendor
-- sells that its whole window didn't show, in NeedRollDB.vendorMissing:
-- [npcID] = { at = <time()>, build, items = { itemID, ... } }, gone again
-- once a read shows them all. Saved for Mike to check, never shared: the
-- window may leave out what the other side, or a reputation, can buy.
local function NoteMissing(vendor, recipes)
    if not vendor.isWhole then return end
    local shown = {}
    for _, recipe in ipairs(recipes) do shown[recipe.item] = true end
    local missing = {}
    for _, itemID in ipairs(ns.Data:KnownVendorRecipeIDs(vendor.npc)) do
        if not shown[itemID] then missing[#missing + 1] = itemID end
    end
    ns.db.vendorMissing[vendor.npc] = #missing > 0 and { at = time(), build = vendor.build, items = missing } or nil
end
--@end-debug@]==]

-- The recipe filter and the rare stock filter: each saves what the read
-- found of its kind that NeedRoll doesn't know, and shares it.
Vendors.AddFilter({
    Wants = function(item) return RECIPES.IsWanted(item.item) end,
    Take = function(vendor, recipes)
        --[==[@debug@
        NoteMissing(vendor, recipes)
        --@end-debug@]==]
        if SaveRead(RECIPES, vendor, recipes) then Vendors.Share() end
    end,
})
Vendors.AddFilter({
    Wants = function(item) return RARE_STOCK.IsWanted(item.item) end,
    Take = function(vendor, items)
        if SaveRead(RARE_STOCK, vendor, items) then Vendors.Share() end
    end,
})

ns:On("PLAYER_LOGIN", function()
    -- A while after login, as the rest of drop sharing starts (Core/Drops.lua
    -- picks up what the last session left unsent 20 seconds in).
    C_Timer.After(30, Vendors.Share)
end)
