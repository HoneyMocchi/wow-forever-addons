-- Loot recorder: notes every recipe and every Uncommon-or-better item the
-- player loots, with what dropped it and where, so drops NeedRoll doesn't
-- list yet can be found and added to the data. Kept in NeedRollDB.lootLog:
--     [itemID] = { link = "|cff...", quality = 2, sources = {
--         ["npc:1234"] = { kind = "npc", id = 1234, name = "Rhahk'Zor",
--                          where = "The Deadmines", mapID = 1415,
--                          count = 3, first = <time()>, last = <time()> },
--     } }
-- kind is "npc" (a creature or vehicle), "object" (a chest, node or other
-- game object), "item" (a bag or box opened from the bags) or "unknown"
-- (the game didn't say; its key carries the place instead of an ID).
-- Items NeedRoll doesn't list are also noted when they are only seen:
-- "roll" (a group loot roll), "group" (a loot message about someone else)
-- and "link" (an item link in chat, with channel = the chat type). Rolls
-- and loot messages carry boss = the boss killed there in the last few
-- minutes, when there was one.
-- /nr loot lists the items NeedRoll has no list for, /nr loot all lists
-- everything recorded, /nr loot clear empties the log. /nr loot scan looks
-- for unlisted items numbered next to each dungeon's and raid's own items
-- (new items of one place are numbered together) and keeps them in
-- NeedRollDB.lootScan = { [itemID] = { inst = "BLACKFATHOM", near = 273843 } };
-- /nr loot leads prints them again.
-- /nr loot fish sweeps a whole range of item IDs (by default 241000, past
-- Season of Discovery's items, to 500000) for items NeedRoll
-- doesn't list, slowly enough to stay far from any server limit, and saves
-- its place so it carries on after logging back in. What it finds is kept
-- in NeedRollDB.fish.found = { [itemID] = { link = "|cff...", quality = 3 } }
-- and listed by /nr loot (the first few) and /nr loot fished (all).
-- All of it is for local checkouts only: the CurseForge packager turns the
-- debug block below into a comment, so a released build records nothing,
-- sweeps nothing and treats /nr loot as plain /nr.
local _, ns = ...

local LootLog = {}
ns.LootLog = LootLog
--[==[@debug@

-- Unit names and GUIDs can be secret in some instances (see ns.Plain).
local Plain = ns.Plain

-- Loot counted this session, by source GUID and item: reopening a corpse doesn't count twice.
local countedLoot = {}
local lootWindowCount = 0 -- loot windows opened, so loot with no source GUID counts once per window

-- The kind and ID of what a GUID names: a creature or vehicle ("npc"), a game object
-- ("object"), or a bag item opened (Item-<realm>-0-<hex>: "item", no ID).
local function LootSourceOf(guid)
    local unitType, id = ns.ParseGUID(guid)
    if unitType == "Creature" or unitType == "Vehicle" then return "npc", id end
    if unitType == "GameObject" then return "object", id end
    if type(guid) == "string" and guid:match("^Item%-") then return "item", nil end
    return nil
end

-- The name of the unit with this GUID, when it is the target or under the
-- mouse (a corpse being looted usually is one of them).
local function NameOf(guid)
    for _, unit in ipairs({ "target", "mouseover" }) do
        local ok, same = pcall(function() return Plain(UnitGUID(unit)) == guid end)
        if ok and same then return Plain(UnitName(unit)) end
    end
end

-- The instance's name inside one, else "Zone - Subzone".
local function Where()
    local name, instanceType = GetInstanceInfo()
    if instanceType and instanceType ~= "none" and name then return name end
    local zone, subZone = GetZoneText(), GetSubZoneText()
    if subZone and subZone ~= "" and subZone ~= zone then return zone .. " - " .. subZone end
    return zone
end

-- Whether NeedRoll lists the item anywhere (any tab).
local listedItems -- item ID -> true, built at the first ask
local function IsListed(itemID)
    if not listedItems then
        listedItems = {}
        for _, category in ipairs(ns.Data.CATEGORIES) do
            for _, instance in ipairs(ns.Data:List(category)) do
                for _, encounter in ipairs(instance.encounters) do
                    for _, entry in ipairs(encounter.loot or {}) do
                        if entry.itemID then listedItems[entry.itemID] = true end
                    end
                end
            end
        end
    end
    return listedItems[itemID] == true
end

-- `link`'s item ID when it is worth noting (a recipe, or Uncommon or better), else nil.
local function WantedItemID(link, quality)
    local itemID, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
    itemID = itemID or ns.Items:IDFromLink(link)
    if not itemID then return nil end
    if classID == Enum.ItemClass.Recipe or (quality or 0) >= Enum.ItemQuality.Uncommon then return itemID end
end

-- When each item was last noted (GetTime()): for two minutes, a sighting of the same drop
-- (its loot message, its roll) isn't counted again under another source.
local notedAt = {}

-- Adds one drop to the log under source `key`: `newSource` (kind, id, ...) starts the
-- source the first time; `changes` are written over it every time.
local function AddDrop(itemID, link, quality, key, newSource, changes)
    local log = ns.db.lootLog
    local item = log[itemID]
    if not item then
        item = { sources = {} }
        log[itemID] = item
    end
    item.link, item.quality = link or item.link, quality or item.quality
    local now = time()
    local source = item.sources[key]
    if not source then
        source = newSource
        source.count, source.first = 0, now
        item.sources[key] = source
    end
    source.count = source.count + 1
    source.last = now
    source.where = Where() or source.where
    source.mapID = C_Map.GetBestMapForUnit("player") or source.mapID
    for field, value in pairs(changes or {}) do source[field] = value end
    notedAt[itemID] = GetTime()
end

-- A drop the player looted, from what `guid` names (nil: the game didn't say).
local function AddLooted(itemID, link, quality, guid)
    local kind, id = LootSourceOf(guid)
    local key
    if kind == "npc" or kind == "object" then
        key = kind .. ":" .. id
    elseif kind == "item" then
        key = "item"
    else
        kind, key = "unknown", "unknown:" .. (Where() or "?")
    end
    AddDrop(itemID, link, quality, key, { kind = kind, id = id }, { name = guid and NameOf(guid) })
end

-- One loot window slot's item, once for each corpse or chest it came from.
local function AddLootSlot(slot)
    local link = GetLootSlotType(slot) == Enum.LootSlotType.Item and GetLootSlotLink(slot)
    if not link then return end
    local quality = select(5, GetLootSlotInfo(slot))
    local itemID = WantedItemID(link, quality)
    if not itemID then return end
    -- Area loot pools several corpses in one slot: GetLootSourceInfo gives guid1, count1, guid2, ...
    local sources = { GetLootSourceInfo(slot) }
    if #sources == 0 then sources = { false } end
    for i = 1, #sources, 2 do
        local guid = Plain(sources[i]) or nil
        local lootKey = (guid or ("window" .. lootWindowCount .. ":" .. slot)) .. ":" .. itemID
        if not countedLoot[lootKey] then
            countedLoot[lootKey] = true
            AddLooted(itemID, link, quality, guid)
        end
    end
end

local function ScanLootWindow()
    if not ns.db then return end
    for slot = 1, GetNumLootItems() do AddLootSlot(slot) end
end

-- LOOT_READY comes first and also fires with auto loot on; LOOT_OPENED is
-- a fallback. countedLoot keeps the second pass from counting again.
ns:On("LOOT_READY", ScanLootWindow)
ns:On("LOOT_OPENED", ScanLootWindow)
ns:On("LOOT_CLOSED", function() lootWindowCount = lootWindowCount + 1 end)

-- The boss killed here in the last few minutes, for rolls and loot
-- messages (which don't say what dropped the item).
local lastBoss
ns:On("ENCOUNTER_END", function(_, name, _, _, success)
    name = Plain(name)
    if success == 1 and name then lastBoss = { name = name, at = GetTime(), where = Where() } end
end)

local function RecentBoss()
    if lastBoss and GetTime() - lastBoss.at < 300 and lastBoss.where == Where() then return lastBoss.name end
end

local linkedThisSession = {} -- item IDs already noted from chat links

-- An item NeedRoll doesn't list, seen but not looted by the player: noted once its quality
-- has loaded, if a recipe or Uncommon or better. kind: "roll", "group" (someone else's
-- loot) or "link" (in chat, on `channel`).
local function AddSighting(link, kind, channel)
    link = Plain(link)
    if type(link) ~= "string" then return end
    local itemID = ns.Items:IDFromLink(link)
    if not itemID or IsListed(itemID) then return end
    if kind == "link" then
        if linkedThisSession[itemID] then return end
        linkedThisSession[itemID] = true
    elseif notedAt[itemID] and GetTime() - notedAt[itemID] < 120 then
        return
    end
    local boss = kind ~= "link" and RecentBoss() or nil
    ns.Items:Load(itemID, function()
        local quality = ns.Items:Quality(itemID)
        local itemLink = select(2, C_Item.GetItemInfo(itemID))
        if not (itemLink and WantedItemID(itemLink, quality)) then return end
        local where = kind == "link" and "" or (Where() or "?")
        local key = kind .. ":" .. (channel or where) .. ":" .. (boss or "")
        AddDrop(itemID, itemLink, quality, key, { kind = kind, channel = channel, boss = boss })
    end)
end

local function ItemLinks(text)
    local links = {}
    for link in text:gmatch("|Hitem:[^|]+|h") do table.insert(links, link) end
    return links
end

ns:On("START_LOOT_ROLL", function(rollID)
    local link = GetLootRollItemLink(rollID)
    if link then AddSighting(link, "roll") end
end)

-- Someone else's loot (the player's own loot comes from the loot window).
ns:On("CHAT_MSG_LOOT", function(text, ...)
    text = Plain(text)
    local guid = Plain((select(11, ...)))
    if type(text) ~= "string" or not guid or guid == UnitGUID("player") then return end
    for _, link in ipairs(ItemLinks(text)) do AddSighting(link, "group") end
end)

-- Item links in chat: the CHAT_MSG_ event's chat type -> the channel name saved with them.
local CHAT_CHANNELS = {
    SAY = "Say", YELL = "Yell", PARTY = "Party", PARTY_LEADER = "Party", RAID = "Raid", RAID_LEADER = "Raid",
    INSTANCE_CHAT = "Instance", INSTANCE_CHAT_LEADER = "Instance", GUILD = "Guild", OFFICER = "Guild",
    WHISPER = "Whisper", CHANNEL = "Channel",
}
for chatType, channel in pairs(CHAT_CHANNELS) do
    ns:On("CHAT_MSG_" .. chatType, function(text)
        text = Plain(text)
        if type(text) ~= "string" then return end
        for _, link in ipairs(ItemLinks(text)) do AddSighting(link, "link", channel) end
    end)
end

-- /nr loot scan: unlisted items numbered next to each dungeon's and raid's
-- own new items. Checking whether an ID exists is local and quick; only the
-- IDs that do are asked of the server, a few at a time.
local SPAN = 40          -- IDs checked on each side of a known one
local FIRST_NEW = 100000 -- Classic items are all far below this
local isScanning = false
local scanRun = 0 -- which scan a timer belongs to

-- The leads found so far that NeedRoll still doesn't list, by instance ID, and their count.
local function Leads()
    local byInstance, count = {}, 0
    for itemID, lead in pairs(ns.db.lootScan) do
        if not IsListed(itemID) then
            byInstance[lead.inst] = byInstance[lead.inst] or {}
            table.insert(byInstance[lead.inst], itemID)
            count = count + 1
        end
    end
    return byInstance, count
end

function LootLog:PrintLeads()
    local byInstance, count = Leads()
    if count == 0 then
        ns:Print("No unlisted items found next to NeedRoll's dungeon and raid items." ..
            (next(ns.db.lootScan) and "" or " /nr loot scan looks for them."))
        return
    end
    ns:Print(count .. " unlisted items numbered next to a place's own items (likely, not certain, to drop there):")
    local places = {}
    for instanceID in pairs(byInstance) do
        local instance = ns.Data:Get(instanceID)
        table.insert(places, { id = instanceID, name = instance and instance.name or instanceID })
    end
    table.sort(places, function(a, b) return a.name < b.name end)
    for _, place in ipairs(places) do
        print("  |cffFCD29F" .. place.name .. "|r")
        local ids = byInstance[place.id]
        table.sort(ids)
        for _, itemID in ipairs(ids) do
            local link = select(2, C_Item.GetItemInfo(itemID)) or ("item " .. itemID)
            print("      " .. link .. "  |cff808080" .. itemID .. "|r")
        end
    end
end

-- Notes the unlisted IDs within SPAN of `listedID` (an item of `instance`) that it is the
-- nearest listed item to: nearest[candidateID] = { inst, near = listedID, distance }.
local function AddCandidates(nearest, instance, listedID)
    for candidateID = listedID - SPAN, listedID + SPAN do
        local distance = math.abs(candidateID - listedID)
        local isCloser = not nearest[candidateID] or distance < nearest[candidateID].distance
        if isCloser and not IsListed(candidateID) then
            nearest[candidateID] = { inst = instance.id, near = listedID, distance = distance }
        end
    end
end

-- Every candidate ID next to a dungeon's or raid's own new items.
local function NearbyCandidates()
    local nearest = {}
    for _, category in ipairs({ "DUNGEON", "RAID" }) do
        for _, instance in ipairs(ns.Data:List(category)) do
            for _, encounter in ipairs(instance.encounters) do
                for _, entry in ipairs(encounter.loot or {}) do
                    local listedID = entry.itemID
                    if listedID and listedID >= FIRST_NEW then AddCandidates(nearest, instance, listedID) end
                end
            end
        end
    end
    return nearest
end

function LootLog:ScanIDs()
    if isScanning then
        ns:Print("Already scanning.")
        return
    end
    local nearest = NearbyCandidates()
    local ids = {}
    for candidateID in pairs(nearest) do
        if C_Item.GetItemInfoInstant(candidateID) then table.insert(ids, candidateID) end
    end
    table.sort(ids)
    if #ids == 0 then
        ns:Print("No unlisted item IDs exist next to NeedRoll's dungeon and raid items.")
        return
    end
    ns:Print("Checking " .. #ids .. " unlisted item IDs next to dungeon and raid items...")
    isScanning = true
    scanRun = scanRun + 1
    local run, nextIndex, waitingFor = scanRun, 1, 0
    local function Done()
        if not isScanning or run ~= scanRun then return end
        isScanning = false
        LootLog:PrintLeads()
    end
    local function Checked(itemID)
        waitingFor = waitingFor - 1
        local quality = ns.Items:Quality(itemID)
        local link = select(2, C_Item.GetItemInfo(itemID))
        if link and WantedItemID(link, quality) then
            ns.db.lootScan[itemID] = { inst = nearest[itemID].inst, near = nearest[itemID].near }
        end
        if nextIndex > #ids and waitingFor == 0 then Done() end
    end
    local function AskBatch()
        for _ = 1, 20 do
            local itemID = ids[nextIndex]
            if not itemID then break end
            nextIndex = nextIndex + 1
            waitingFor = waitingFor + 1
            ns.Items:Load(itemID, Checked)
        end
        if nextIndex <= #ids then
            C_Timer.After(0.2, AskBatch)
        else
            -- Items the server never answers for: stop waiting after a while.
            C_Timer.After(10, Done)
        end
    end
    AskBatch()
end

-- /nr loot fish: a slow sweep of a whole range of item IDs. Whether an ID
-- exists is checked on the client (no server traffic), many per tick; only
-- an existing ID NeedRoll doesn't list is asked of the server, at most one
-- per FISH_GAP seconds, and never in combat. fish.next is the next ID to
-- look at, saved with the rest of NeedRollDB, so the sweep picks up there.
local FISH_CHECKS = 250 -- client-side checks per tick
local FISH_TICK = 0.1   -- seconds between ticks
local FISH_GAP = 1      -- seconds between server requests
local FISHED_SHOWN = 15 -- fished items /nr loot shows before pointing at /nr loot fished
local fishRun = 0       -- which sweep a timer belongs to (0: none started this session)

-- Items the sweep throws back: Season of Discovery's runes and spell notes, which the
-- client knows but Forever doesn't drop.
local THROW_BACK = { "^Rune of ", "^Spell Notes: " }

local function IsThrownBack(link)
    local name = link and link:match("%[(.-)%]")
    if not name then return false end
    for _, pattern in ipairs(THROW_BACK) do
        if name:find(pattern) then return true end
    end
    return false
end

-- The fished items NeedRoll doesn't list, sorted, for the fished window (UI/Fished.lua):
-- the ones shown, or with `hidden`, the ones moved to its Hidden tab.
function LootLog:FishedIDs(hidden)
    local fish = ns.db.fish
    local ids = {}
    for itemID, item in pairs(fish.found) do
        if IsThrownBack(item.link) then
            fish.found[itemID] = nil -- caught before runes were thrown back
        elseif not IsListed(itemID) and (fish.hidden[itemID] == true) == (hidden == true) then
            table.insert(ids, itemID)
        end
    end
    table.sort(ids)
    return ids
end

function LootLog:SetFishedHidden(itemID, hidden)
    ns.db.fish.hidden[itemID] = hidden or nil
end

-- The sweep's progress. NeedRollDB is saved for the whole account, so this
-- is the same on every character, and any of them carries the sweep on.
function LootLog:FishStatus()
    local fish = ns.db.fish
    local rangeSize = fish.to - fish.from + 1
    local done = math.min(math.max(fish.next - fish.from, 0), rangeSize)
    local percent = math.floor(done * 100 / rangeSize)
    local state = fish.running and "running" or (fish.next > fish.to and "finished" or "paused")
    -- fish.next is the next ID to look at; the one being looked at (or
    -- waited on from the server) is the one before it.
    local current = math.max(math.min(fish.next - 1, fish.to), fish.from)
    local hint = state == "paused" and " /nr loot fish resumes it." or ""
    return ("Item ID fishing: on item ID |cffFCD29F%d|r of %d-%d (%d%%), %s, %d unlisted items found.%s"):format(
        current, fish.from, fish.to, percent, state, #self:FishedIDs(), hint)
end

-- Whether a sweep was ever started (so /nr loot has progress to show).
local function HasFished()
    local fish = ns.db.fish
    return fish.running or fish.next > fish.from
end

local FishStep

-- Runs sweep `run`'s next step after `delay` seconds, unless a newer sweep or a pause took over.
local function FishLater(run, delay)
    C_Timer.After(delay, function()
        if run == fishRun then FishStep(run) end
    end)
end

-- Keeps a fished item if it's worth noting and NeedRoll doesn't list it.
local function KeepFished(itemID)
    local quality = ns.Items:Quality(itemID)
    local link = select(2, C_Item.GetItemInfo(itemID))
    if link and WantedItemID(link, quality) and not IsListed(itemID) and not IsThrownBack(link) then
        ns.db.fish.found[itemID] = { link = link, quality = quality }
        if ns.FishedWindow then ns.FishedWindow:Refresh() end
    end
end

function FishStep(run)
    local fish = ns.db.fish
    if not fish.running then return end
    if InCombatLockdown() or UnitAffectingCombat("player") then
        FishLater(run, 5) -- look again for the end of combat
        return
    end
    for _ = 1, FISH_CHECKS do
        local itemID = fish.next
        if itemID > fish.to then
            fish.running = false
            ns:Print(LootLog:FishStatus() .. " /nr loot fished shows them.")
            return
        end
        fish.next = itemID + 1
        if not IsListed(itemID) and C_Item.GetItemInfoInstant(itemID) then
            if not C_Item.IsItemDataCachedByID(itemID) then
                -- One server request, then a pause before the next.
                ns.Items:Load(itemID, KeepFished)
                FishLater(run, FISH_GAP)
                return
            end
            KeepFished(itemID)
        end
    end
    FishLater(run, FISH_TICK)
end

local function FishStart(isQuiet)
    local fish = ns.db.fish
    if fish.next > fish.to then
        ns:Print(LootLog:FishStatus() .. " /nr loot fish reset starts it over.")
        return
    end
    fish.running = true
    fishRun = fishRun + 1
    if not isQuiet then ns:Print("Item ID fishing started at " .. fish.next .. ". /nr loot fish pause pauses it.") end
    FishStep(fishRun)
end

local function FishPause()
    ns.db.fish.running = false
    fishRun = fishRun + 1
    ns:Print("Item ID fishing paused at " .. ns.db.fish.next .. ". /nr loot fish resumes it.")
end

-- /nr loot fish [pause | status | reset | <from> <to>]: no argument starts
-- or resumes the sweep (or, while it runs, shows where it is); pause pauses
-- it; reset starts it over and forgets what it found; two numbers set a new
-- range and start over.
function LootLog:Fish(args)
    local fish = ns.db.fish
    local from, to = args:match("^(%d+)%s+(%d+)$")
    if args == "status" or (args == "" and fish.running) then
        ns:Print(self:FishStatus())
    elseif args == "pause" or args == "stop" then
        if fish.running then FishPause() else ns:Print(self:FishStatus()) end
    elseif args == "reset" or from then
        if from then
            from, to = tonumber(from), tonumber(to)
            if to < from then from, to = to, from end
            fish.from, fish.to = from, to
        end
        fish.next = fish.from
        wipe(fish.found)
        FishStart()
    elseif args == "" then
        FishStart()
    else
        ns:Print("/nr loot fish starts it; /nr loot fish pause, status, reset, or <from> <to>.")
    end
end

function LootLog:PrintFished(limit)
    local ids = self:FishedIDs()
    if #ids == 0 then
        if not limit and HasFished() then ns:Print(self:FishStatus()) end
        return
    end
    ns:Print(#ids .. " unlisted items fished from item IDs (where they drop isn't known):")
    for i, itemID in ipairs(ids) do
        if limit and i > limit then
            print("  ... and " .. (#ids - limit) .. " more: /nr loot fished shows them all.")
            break
        end
        local link = select(2, C_Item.GetItemInfo(itemID)) or ns.db.fish.found[itemID].link
        print("  " .. link .. "  |cff808080" .. itemID .. "|r")
    end
end

-- Old saved sweeps move on to today's range; a running one carries on after login.
ns:On("PLAYER_LOGIN", function()
    -- Sweeps begun on the old default range (from 200000) skip ahead to
    -- 241000: the IDs before it are Season of Discovery's.
    local fish = ns.db.fish
    if not fish.skippedSoD then
        fish.skippedSoD = true
        if fish.from == 200000 and fish.to == 300000 then
            fish.from = 241000
            fish.next = math.max(fish.next, 241000)
        end
    end
    -- Sweeps on an old default end (300000, then 400000) run on to 500000;
    -- a finished one shows as paused and /nr loot fish carries it on.
    if not fish.extendedTo500k then
        fish.extendedTo500k = true
        if fish.to == 300000 or fish.to == 400000 then fish.to = 500000 end
    end
    if not fish.running then return end
    C_Timer.After(15, function() -- once the login rush is over
        if ns.db.fish.running and fishRun == 0 then
            ns:Print("Item ID fishing carries on at " .. ns.db.fish.next .. ".")
            FishStart(true)
        end
    end)
end)

-- What a sighting's kind says when nothing named the source.
local SIGHTING_SOURCES = { roll = "Group roll", group = "Looted by someone else" }

-- One source of a recorded item, as /nr loot prints it.
local function SourceText(source)
    if source.kind == "link" then
        return ns.Theme:JoinDots("Linked in chat", source.channel or "?") .. "  (" .. source.count .. "x)"
    end
    local who = source.name or SIGHTING_SOURCES[source.kind] or (source.kind == "item" and "a container")
        or (source.kind == "unknown" and "unknown source") or (source.kind == "object" and "an object") or "an NPC"
    local parts = { who }
    if source.boss then table.insert(parts, "after " .. source.boss) end
    if source.id then table.insert(parts, (source.kind == "object" and "object " or "NPC ") .. source.id) end
    if source.where then table.insert(parts, source.where) end
    return ns.Theme:JoinDots(unpack(parts)) .. "  (" .. source.count .. "x)"
end

-- Prints the log: only items NeedRoll doesn't list, or all of them.
function LootLog:Print(all)
    if HasFished() then ns:Print(self:FishStatus()) end
    local log = ns.db.lootLog
    local ids, total = {}, 0
    for itemID in pairs(log) do
        total = total + 1
        if all or not IsListed(itemID) then table.insert(ids, itemID) end
    end
    table.sort(ids)
    if #ids == 0 then
        if total == 0 then
            ns:Print("No drops recorded yet. Recipes and Uncommon or better loot are noted as you loot them.")
            if next(ns.db.lootScan) then ns:Print("/nr loot leads lists unlisted items found by /nr loot scan.") end
        else
            ns:Print("No new drops: all " .. total .. " recorded items are already in NeedRoll."
                .. " /nr loot all lists them.")
        end
    else
        ns:Print(all and (total .. " recorded items:") or (#ids .. " recorded items NeedRoll doesn't list yet:"))
        for _, itemID in ipairs(ids) do
            local item = log[itemID]
            local tag = (all and not IsListed(itemID)) and "  |cff3b875bnew|r" or ""
            print("  " .. (item.link or ("item " .. itemID)) .. "  |cff808080" .. itemID .. "|r" .. tag)
            for _, source in pairs(item.sources) do print("      " .. SourceText(source)) end
        end
    end
    self:PrintFished(FISHED_SHOWN)
end

function LootLog:Clear()
    wipe(ns.db.lootLog)
    wipe(ns.db.lootScan)
    wipe(countedLoot)
    wipe(notedAt)
    wipe(linkedThisSession)
    ns:Print("Loot log and scan results cleared.")
end
--@end-debug@]==]
