-- Search across every registered instance: dungeon and raid names, their
-- bosses, their quests (and raid attunement and item chain steps), the
-- player's side's Library books (Data/LibraryBooks.lua), and item names:
-- the items of the lists, and the items only a few vendors sell
-- (Data/VendorItems.lua), each of those with the vendors of the player's
-- side under "Sold by". Item names (books' too) come from the client's item
-- cache, so Warm() asks for them once and keeps each one as it arrives.
-- Search reads only that list, so a name the client later drops from its
-- cache stays searchable. The Library tab's own search box
-- (UI/LibraryBooks.lua) matches text the same way (ns.Search.SearchForm,
-- ns.Search.Matches).
local _, ns = ...
local L = ns.L
local Theme = ns.Theme

ns.Search = {}
local itemNames = {}      -- itemID -> name, as loaded
local itemSearchKeys = {} -- itemID -> its name in SearchForm, what a query is matched against

-- Text as searches compare it: lowercase, apostrophes dropped, so "akumai"
-- finds Aku'mai.
local function SearchForm(text)
    return (text:lower():gsub("'", ""))
end
ns.Search.SearchForm = SearchForm

local function NameOf(itemID)
    local name = itemNames[itemID]
    if name then return name end
    name = C_Item.GetItemNameByID(itemID)
    itemNames[itemID] = name
    if name then itemSearchKeys[itemID] = SearchForm(name) end
    return name
end

local function WindowShown()
    local frame = ns.UI.frame
    return frame and frame:IsShown()
end

-- Redraws the results once item names arrive. Names land in bursts, so one
-- redraw covers each burst; it changes nothing on screen unless the
-- results did. Nothing redraws while the window is closed: opening it
-- catches up.
local REFRESH_DELAY = 0.2 -- seconds
local refreshQueued = false
local function QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(REFRESH_DELAY, function()
        refreshQueued = false
        if ns.UI.state.search and WindowShown() then ns.UI:Refresh() end
    end)
end

-- A name that arrives mid-search only matters if it matches. Names still
-- arriving after the window closes are kept, but trigger nothing.
local function OnNameLoaded(itemID)
    NameOf(itemID)
    local query = ns.UI.state.search
    if not (query and WindowShown()) then return end
    local key = itemSearchKeys[itemID]
    if key and key:find(SearchForm(query), 1, true) then QueueRefresh() end
end

-- The instances of a tab that is on, or none.
local function ListIfOn(category)
    return ns.Modules:IsOn(category) and ns.Data:List(category) or {}
end

-- Every loot entry of the tabs that are on, in tab order, each instance's
-- encounters in their own order, so an item's first source is the first
-- boss to drop it. `fn` gets the entry, its encounter, its instance and
-- the entry's place in that order.
local function EachSource(fn)
    local order = 0
    for _, category in ipairs(ns.Data.CATEGORIES) do
        for _, instance in ipairs(ListIfOn(category)) do
            for _, encounter in ipairs(instance.encounters) do
                for _, entry in ipairs(encounter.loot) do
                    order = order + 1
                    fn(entry, encounter, instance, order)
                end
            end
        end
    end
end

-- Item names (eight thousand or so) are asked for a little at a time over
-- a minute, starting a few seconds after logging in (or a /reload), so
-- they're usually in before the window first opens without any one moment
-- taking the strain. Opening the window asks for whatever is left at once.
local WARM_DELAY = 5     -- seconds after logging in before the first batch
local WARM_SPREAD = 60   -- seconds the batches are spread over
local WARM_TICK = 0.5    -- seconds between batches
local warmItemIDs        -- every item ID to ask a name for, each once
local nextWarmIndex      -- the first of warmItemIDs not asked for yet
local warmTicker
local warmedAll = false  -- the window opened and asked for every name left

local function ListWarmItemIDs()
    local itemIDs, listed = {}, {}
    EachSource(function(entry)
        local itemID = entry.itemID
        if itemID and not listed[itemID] then
            listed[itemID] = true
            table.insert(itemIDs, itemID)
        end
    end)
    for itemID in pairs(ns.Data.vendorItems.items) do
        if not listed[itemID] then table.insert(itemIDs, itemID) end
    end
    if ns.Modules:IsOn("LIBRARY_BOOKS") then
        for _, book in ipairs(ns.Data.libraryBooks.books) do
            if not listed[book.item] then table.insert(itemIDs, book.item) end
        end
    end
    return itemIDs
end

local function StopWarmTicker()
    if not warmTicker then return end
    warmTicker:Cancel()
    warmTicker = nil
end

local function EnsureWarmList()
    if not warmItemIDs then warmItemIDs, nextWarmIndex = ListWarmItemIDs(), 1 end
end

-- Asks for the next `count` names; the last batch stops the ticker.
local function WarmBatch(count)
    for i = nextWarmIndex, math.min(nextWarmIndex + count - 1, #warmItemIDs) do
        ns.Items:Load(warmItemIDs[i], OnNameLoaded)
    end
    nextWarmIndex = nextWarmIndex + count
    if nextWarmIndex > #warmItemIDs then StopWarmTicker() end
end

-- Starts asking for names over WARM_SPREAD seconds.
local function StartWarm()
    if warmItemIDs then return end
    EnsureWarmList()
    local batchSize = math.ceil(#warmItemIDs / (WARM_SPREAD / WARM_TICK))
    if batchSize == 0 then return end
    warmTicker = C_Timer.NewTicker(WARM_TICK, function() WarmBatch(batchSize) end)
end

-- The window opened: ask for every name not asked for yet.
function ns.Search:Warm()
    if warmedAll then return end
    warmedAll = true
    EnsureWarmList()
    WarmBatch(#warmItemIDs)
end

ns:On("PLAYER_LOGIN", function()
    C_Timer.After(WARM_DELAY, StartWarm)
end)

-- Every item that can be searched for, each with all its sources: built
-- once, at the first search, since the loot lists never change. A search
-- then only looks at each item's name once, not at every list it is on.
-- { { itemID = N, sources = { ... } }, ... } in first-source order.
local itemIndex
-- Each item's result row, built the first time it matches and reused by
-- every later search, so the loot grid's per-row measurements (kept by
-- row) carry over from one search to the next. By side, in case it changes.
-- side -> item (an itemIndex entry) -> result
local itemResults = {}

-- Names arrived from the game client (Core/Names.lua): searches are indexed
-- again on the next keystroke.
function ns.Search:Forget()
    itemIndex = nil
    wipe(itemResults)
end

-- A tab was turned on or off in Settings: searches are indexed again, and
-- the names of a tab just turned on are asked for (all at once, as opening
-- the window does).
function ns.Search:Reset()
    self:Forget()
    if not warmItemIDs then return end
    StopWarmTicker()
    warmItemIDs = ListWarmItemIDs()
    nextWarmIndex = #warmItemIDs + 1
    for _, itemID in ipairs(warmItemIDs) do
        if not itemNames[itemID] then ns.Items:Load(itemID, OnNameLoaded) end
    end
end

local PLACES = { DUNGEON = true, RAID = true }
local MAX_NAMED = 3 -- sources named on an item's result line
local SOURCE_RANK_BOSS, SOURCE_RANK_POOL, SOURCE_RANK_LIST = 1, 2, 3

-- Whether `name` contains `queryKey`, a query already in SearchForm.
local function Matches(name, queryKey)
    return SearchForm(name):find(queryKey, 1, true) ~= nil
end
ns.Search.Matches = Matches

local function ForSide(instance, side)
    return not instance.faction or instance.faction == side
end

-- How a source ranks for an item: a dungeon or raid boss first, then its
-- trash and shared loot, then vendor lists, collections and recipes.
local function SourceRank(instance, encounter)
    if not PLACES[instance.category] then return SOURCE_RANK_LIST end
    return ns.Data:IsBoss(encounter) and SOURCE_RANK_BOSS or SOURCE_RANK_POOL
end

-- The item's sources as one line: "Garr, Gehennas, Shazzrah  ·  Molten Core"
-- when they share an instance, else "Boss (Instance), ...", naming the first
-- three and counting the rest.
local function SourceLine(sources)
    local sameInstance = true
    for _, source in ipairs(sources) do
        if source.inst ~= sources[1].inst then sameInstance = false end
    end
    local parts = {}
    for i = 1, math.min(#sources, MAX_NAMED) do
        local source = sources[i]
        parts[i] = sameInstance and source.name or ("%s (%s)"):format(source.name, ns.Data:PlaceName(source.inst))
    end
    local line = table.concat(parts, ", ")
    if #sources > MAX_NAMED then line = line .. " " .. L["+%d more"]:format(#sources - MAX_NAMED) end
    -- A list named after its place says it once ("Ahn'Qiraj Gates").
    local place = ns.Data:PlaceName(sources[1].inst)
    if sameInstance and line ~= place then line = Theme:JoinDots(line, place) end
    return line
end

-- Every listed item and its sources: { entry (the loot row), enc (its
-- encounter), inst (its instance), order, rank, name }. Results keep these
-- keys. Then the items only vendors sell that no list has, with no sources.
local function ItemIndex()
    if itemIndex then return itemIndex end
    itemIndex = {}
    local byItemID = {}
    EachSource(function(entry, encounter, instance, order)
        local itemID = entry.itemID
        if not itemID or entry.recipe then return end
        local item = byItemID[itemID]
        if not item then
            item = { itemID = itemID, sources = {} }
            byItemID[itemID] = item
            table.insert(itemIndex, item)
        end
        table.insert(item.sources, { entry = entry, enc = encounter, inst = instance, order = order,
            rank = SourceRank(instance, encounter), name = ns.Data:DropperName(instance, encounter, entry) })
    end)
    for itemID in pairs(ns.Data.vendorItems.items) do
        if not byItemID[itemID] then table.insert(itemIndex, { itemID = itemID, sources = {} }) end
    end
    return itemIndex
end

local function ByRankThenOrder(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.order < b.order
end

-- The vendors of side `side`, or of both sides, that Data/VendorItems.lua
-- says sell `itemID` (as recipe pages show only the player's side's
-- vendors); nil when none does.
local function SellersForSide(itemID, side)
    local sellers = {}
    for _, vendor in ipairs(ns.Data:VendorItemSellers(itemID)) do
        if not vendor.side or vendor.side == side then table.insert(sellers, vendor) end
    end
    return #sellers > 0 and sellers or nil
end

-- A listed item's result row: its sources the player's side can use, best
-- first. A list for one side only counts when the item has no source for
-- the player's side (or both).
local function ListedItemResult(item, side)
    local hasSourceForSide = false
    for _, source in ipairs(item.sources) do
        if ForSide(source.inst, side) then hasSourceForSide = true end
    end
    local sources = {}
    for _, source in ipairs(item.sources) do
        if not hasSourceForSide or ForSide(source.inst, side) then table.insert(sources, source) end
    end
    table.sort(sources, ByRankThenOrder)
    local first = sources[1]
    return {
        itemID = item.itemID,
        dropRate = first.entry.dropRate,
        cost = first.entry.cost,
        costItem = first.entry.costItem,
        costCount = first.entry.costCount,
        source = SourceLine(sources),
        sources = sources,
        inst = first.inst, -- where a click goes
        enc = first.enc,
        name = itemNames[item.itemID],
    }
end

-- An item's result row (a listed item's, see ListedItemResult), with the
-- vendors of the player's side that sell it as `buyFrom`: the loot grid
-- shows them under "Sold by", each pinning its spot on the map. Nil for an
-- item no list has that no vendor of the player's side sells.
local function ItemResult(item, side)
    local buyFrom = SellersForSide(item.itemID, side)
    if #item.sources == 0 and not buyFrom then return nil end
    local result = #item.sources > 0 and ListedItemResult(item, side)
        or { itemID = item.itemID, name = itemNames[item.itemID] }
    result.buyFrom = buyFrom
    return result
end

local function ByName(a, b)
    return a.name < b.name
end

local function ByNameThenItemID(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.itemID < b.itemID
end

local function ByNameThenInstance(a, b)
    if a.name ~= b.name then return a.name < b.name end
    return a.inst.name < b.inst.name
end

-- Items whose name matches: one result per item (see ItemResult). An
-- item with no result for the player's side is remembered as `false`.
local function FindItems(queryKey)
    local side = ns.PlayerFaction()
    itemResults[side] = itemResults[side] or {}
    local resultsForSide = itemResults[side]
    local results = {}
    for _, item in ipairs(ItemIndex()) do
        local itemID = item.itemID
        if not itemSearchKeys[itemID] then NameOf(itemID) end
        local key = itemSearchKeys[itemID]
        if key and key:find(queryKey, 1, true) then
            if resultsForSide[item] == nil then resultsForSide[item] = ItemResult(item, side) or false end
            if resultsForSide[item] then table.insert(results, resultsForSide[item]) end
        end
    end
    table.sort(results, ByNameThenItemID)
    return results
end

-- Dungeons and raids whose name matches.
local function FindPlaces(queryKey)
    local results = {}
    for category in pairs(PLACES) do
        for _, instance in ipairs(ListIfOn(category)) do
            if Matches(instance.name, queryKey) then
                table.insert(results, { kind = "place", inst = instance, name = instance.name })
            end
        end
    end
    table.sort(results, ByName)
    return results
end

-- The bosses of one encounter whose name matches, added to `results`: each
-- boss of a council or of the Ring of Law (`bossFold`: the `key` of its
-- section there, UI/MainFrame.lua's BossFolds), and the encounter itself
-- when its name matches but isn't one of theirs.
local function AddMatchingBosses(results, instance, encounter, queryKey)
    local bosses = ns.Data:Bosses(instance, encounter) or {}
    local encounterNameMatched = false
    for section, boss in ipairs(bosses) do
        if Matches(boss[1], queryKey) then
            encounterNameMatched = encounterNameMatched or boss[1] == encounter.name
            table.insert(results, { kind = "boss", look = boss, inst = instance, enc = encounter, name = boss[1],
                                    bossFold = #bosses > 1 and section or nil })
        end
    end
    if not encounterNameMatched and Matches(encounter.name, queryKey) then
        table.insert(results, { kind = "boss", look = bosses[1] or { encounter.name }, inst = instance,
                                enc = encounter, name = encounter.name })
    end
end

-- Dungeon and raid bosses whose name matches.
local function FindBosses(queryKey)
    local results = {}
    for category in pairs(PLACES) do
        for _, instance in ipairs(ListIfOn(category)) do
            for _, encounter in ipairs(instance.encounters) do
                if ns.Data:IsBoss(encounter) then AddMatchingBosses(results, instance, encounter, queryKey) end
            end
        end
    end
    table.sort(results, ByNameThenInstance)
    return results
end

-- Dungeon quests, raid attunement steps and item chain steps whose name
-- (the client's, once Core/Names.lua has it) matches; none while the Quests
-- module is off. A name a dungeon has more than once (a quest for each side, or an
-- attunement's repeated steps) is one result: the player's side's when
-- there is one.
local function FindQuests(queryKey)
    local results = {}
    if not ns.Modules:IsOn("QUESTS") then return results end
    local side = ns.PlayerFaction()
    local resultByName = {} -- "<instance ID> <quest name>" -> its result
    local function Consider(quest, instance, isAttunement)
        if not quest.name or not Matches(quest.name, queryKey) then return end
        local key = instance.id .. " " .. quest.name
        local isOurs = not quest.side or quest.side == side
        local earlier = resultByName[key]
        if earlier then
            if isOurs and not earlier.ours then earlier.quest, earlier.ours = quest, true end
            return
        end
        local result = { kind = "quest", quest = quest, inst = instance, name = quest.name,
                         attunement = isAttunement, ours = isOurs }
        resultByName[key] = result
        table.insert(results, result)
    end
    -- Each instance's quests and its item chains' steps (a dungeon's key);
    -- a raid's attunement steps too. Every side's.
    for _, category in ipairs({ "DUNGEON", "RAID" }) do
        for _, instance in ipairs(ListIfOn(category)) do
            for _, quest in ipairs(ns.Data:Quests(instance.id)) do Consider(quest, instance) end
            for _, quest in ipairs(ns.Data:ChainQuests(ns.Data:Attunement(instance.id) or {})) do
                Consider(quest, instance, true)
            end
            for _, chain in ipairs(ns.Data:ItemChains(instance.id)) do
                for _, quest in ipairs(ns.Data:ChainQuests(chain)) do Consider(quest, instance) end
            end
        end
    end
    table.sort(results, ByNameThenInstance)
    return results
end

-- Library books of the player's side whose name matches: the game's name
-- for the book once the client has it, else the data's English one. None
-- while the Library module is off. Each with where it stands for the
-- character (Core/LibraryBooks.lua), for its row's second line.
local function FindLibraryBooks(queryKey)
    local results = {}
    if not ns.Modules:IsOn("LIBRARY_BOOKS") then return results end
    local side = ns.PlayerFaction()
    for _, book in ipairs(ns.LibraryBooks.ForSide(side)) do
        local name = NameOf(book.item) or book.name
        if Matches(name, queryKey) then
            table.insert(results, { kind = "book", book = book, name = name,
                                    status = ns.LibraryBooks.Status(book, side) })
        end
    end
    table.sort(results, ByName)
    return results
end

-- What tells two results apart in Find's key. An item only vendors sell
-- has no instance. A book's row shows its name and where it stands, so a
-- change to either is a different list.
local function ResultKey(result)
    if result.book then return ("book%d:%s:%s"):format(result.book.item, result.status, result.name) end
    local what = result.quest and ("quest" .. result.quest.id) or result.itemID or result.name
    local instanceID = result.inst and result.inst.id or ""
    local encounterID = result.enc and result.enc.id or ""
    return ("%s:%s:%s:%s"):format(what, instanceID, encounterID, result.bossFold or "")
end

-- Returns the results for `query` (lowercase): matching dungeons and raids,
-- then bosses, then quests, then Library books, then items (one row per
-- item, naming up to three of the bosses that drop it, and the vendors that
-- sell it), each group under a label; how many there are; and a key naming
-- exactly that list, so a caller can tell when a redraw would show the same
-- thing.
function ns.Search:Find(query)
    local results, resultKeys, count = {}, { query }, 0
    local queryKey = SearchForm(query)
    local groups = {
        { L["Dungeons and Raids"], FindPlaces(queryKey) },
        { L["Bosses"], FindBosses(queryKey) },
        { L["Quests"], FindQuests(queryKey) },
        { L["Library Books"], FindLibraryBooks(queryKey) },
        { L["Items"], FindItems(queryKey) },
    }
    for _, group in ipairs(groups) do
        local label, found = group[1], group[2]
        if #found > 0 then
            table.insert(results, { header = ("%s (%d)"):format(label, #found) })
            for _, result in ipairs(found) do
                table.insert(results, result)
                count = count + 1
                table.insert(resultKeys, ResultKey(result))
            end
        end
    end
    return results, count, table.concat(resultKeys, ",")
end
