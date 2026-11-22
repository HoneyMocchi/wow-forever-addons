-- Calls for other addons (documented in docs/API.md). Each is a global
-- function that opens NeedRoll on a page and returns true, or does nothing
-- and returns false when it can't (an unknown name, a tab turned off in
-- Settings). Nothing is printed: another addon's button must never spam
-- the player's chat.
--
-- Names are matched in English or in the player's language, ignoring case,
-- spaces, punctuation and a leading "The"; the data's own IDs ("DEADMINES",
-- "VANCLEEF") and the game's numbers (an instance map ID, an NPC, spell,
-- item, quest or faction ID) work too.
local _, ns = ...

local PLACES = { "DUNGEON", "RAID" }

-- "The Deadmines" -> "deadmines", "Rhahk'Zor" -> "rhahkzor": the form names
-- are compared in. Letters past ASCII (other languages) are kept as they are.
local function NameKey(text)
    if type(text) ~= "string" then return nil end
    text = text:lower():gsub("^%s*the%s+", ""):gsub("[%s%p]", "")
    return text ~= "" and text or nil
end

-- "36" -> 36: a number passed as text. Empty text is nothing.
local function FromText(what)
    if what == "" then return nil end
    return type(what) == "string" and tonumber(what) or what
end

-- The English names, kept before ns.Names renames the data in the player's
-- language at login. This file loads after every data file.
local englishNames = {} -- instance, encounter, boss entry or quest -> its English name
for _, category in ipairs(ns.Data.CATEGORIES) do
    for _, instance in ipairs(ns.Data:List(category)) do
        englishNames[instance] = instance.name
        for _, encounter in ipairs(instance.encounters) do
            englishNames[encounter] = encounter.name
            for _, boss in ipairs(ns.Data:Bosses(instance, encounter) or {}) do englishNames[boss] = boss[1] end
        end
    end
end
for _, quests in pairs(ns.Data.quests) do
    for _, quest in ipairs(quests) do englishNames[quest] = quest.name end
end

-- Whether name key `key` names `named` (an instance, encounter, boss or quest), by
-- its English name or `name` (the one it has now).
local function IsNamed(key, named, name)
    return key ~= nil and (key == NameKey(englishNames[named]) or key == NameKey(name))
end

-- How well `what` (name key `key`) names `instance`: 1 its own name or ID (or `what` nil: all of
-- them), 2 its game number (map ID, or a faction list's faction ID) or the place it is part of.
local function MatchRank(instance, what, key)
    if what == nil then return 1 end
    local mapID = ns.Data.instanceMapIDs[instance.id]
    if what == (mapID or instance.factionID) then return 2 end
    if not key then return nil end
    if key == NameKey(instance.id) or IsNamed(key, instance, instance.name) then return 1 end
    -- The whole place a wing or half is part of ("Scarlet Monastery", "Blackrock Spire"), in
    -- English and as the game names it (what GetInstanceInfo returns inside).
    local english = englishNames[instance] or instance.name
    local place = english:match("^(.-):") or english:match("^Lower (.+)$") or english:match("^Upper (.+)$")
    if key == NameKey(place) or key == NameKey(mapID and GetRealZoneText(mapID)) then return 2 end
end

-- The instances of `categories` that `what` names, best match first: its
-- own name or ID ahead of the place it is a wing of, the player's side
-- ahead of the other's. `what` nil: all of them.
local function Instances(categories, what)
    local found = {}
    local key = NameKey(what)
    local side = ns.PlayerFaction()
    for _, category in ipairs(categories) do
        for _, instance in ipairs(ns.Data:List(category)) do
            local rank = MatchRank(instance, what, key)
            if rank then
                if instance.faction and instance.faction ~= side then rank = rank + 2 end
                found[#found + 1] = { inst = instance, rank = rank, order = #found }
            end
        end
    end
    table.sort(found, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.order < b.order
    end)
    for i, match in ipairs(found) do found[i] = match.inst end
    return found
end

-- Whether a profession's recipe makes or is taught by item `itemID`.
local function MakesOrTeaches(encounter, itemID)
    for _, entry in ipairs(encounter.loot or {}) do
        if entry.itemID == itemID then return true end
    end
    return false
end

-- The encounter in `instance` that `what` names (a boss, recipe, standing or
-- section), and the boss's section in it when its bosses each drop their
-- own loot (the Ring of Law).
local function Encounter(instance, what)
    local key = NameKey(what)
    for _, encounter in ipairs(instance.encounters) do
        if not encounter.overview then
            if key and (key == NameKey(encounter.id) or IsNamed(key, encounter, encounter.name)) then
                return encounter
            end
            if type(what) == "number" then
                if what == encounter.npc or what == encounter.spellID
                    or what == ns.Names.STANDINGS[englishNames[encounter]] then
                    return encounter
                end
                if instance.category == "PROFESSION" and MakesOrTeaches(encounter, what) then return encounter end
            end
            local bosses = ns.Data:Bosses(instance, encounter) or {}
            for index, boss in ipairs(bosses) do
                if what == boss[5] or IsNamed(key, boss, boss[1]) then
                    return encounter, #bosses > 1 and index or nil
                end
            end
        end
    end
end

-- Whether the window is there to be pointed at a page (UI loaded).
local function CanShow()
    return ns.UI ~= nil and ns.UI.GoToSource ~= nil
end

-- Shows the window (built the first time), ready to be pointed at a page.
local function Open()
    local ui = ns.UI
    if not (ui.frame and ui.frame:IsShown()) then ui:Show() end
    return ui
end

-- Opens an instance of `categories` on the encounter `encounterNameOrID`
-- names, or on its first page without one. Not found there: the next
-- instance `what` names, else false.
local function ShowIn(categories, what, encounterNameOrID)
    if not CanShow() then return false end
    what, encounterNameOrID = FromText(what), FromText(encounterNameOrID)
    if what == nil and encounterNameOrID == nil then return false end
    for _, instance in ipairs(Instances(categories, what)) do
        local encounter, bossSection
        if encounterNameOrID ~= nil then encounter, bossSection = Encounter(instance, encounterNameOrID) end
        if (encounterNameOrID == nil or encounter) and ns.Modules:IsOn(instance.category) then
            Open():GoToSource(instance, encounter, nil, bossSection)
            return true
        end
    end
    return false
end

-- A dungeon's or raid's loot: `instance` and, optionally, `boss` (without
-- one, the instance's Overview). With a boss, `instance` may be nil.
function NeedRoll_ShowLoot(instance, boss)
    return ShowIn(PLACES, instance, boss)
end

-- A dungeon's or raid's layout map: on the floor `boss` is pinned on, his
-- pin lit, or without a boss on the floor last shown (the first at first).
function NeedRoll_ShowMap(instance, boss)
    if not CanShow() then return false end
    instance, boss = FromText(instance), FromText(boss)
    if instance == nil and boss == nil then return false end
    for _, place in ipairs(Instances(PLACES, instance)) do
        local encounter = boss ~= nil and Encounter(place, boss)
        local bossFloor = encounter and ns.UI.BossFloor(place, encounter)
        if ns.Data:Map(place.id) and (boss == nil or bossFloor) and ns.Modules:IsOn(place.category) then
            local ui = Open()
            ui:GoToSource(place)
            if encounter then
                ui:ShowBossOnMap(encounter)
            else
                ui.overview:ShowFloor(ui.overview.levels[place.id] or 1)
            end
            return true
        end
    end
    return false
end

-- The dungeon or raid quest `quest` names in `instance` (by ID or name), or nil.
local function QuestIn(instance, quest, key)
    local found = type(quest) == "number" and ns.Data:DungeonQuest(instance.id, quest)
    if found then return found end
    if not key then return nil end
    for _, candidate in ipairs(ns.Data:Quests(instance.id)) do
        if IsNamed(key, candidate, candidate.name) then return candidate end
    end
end

-- Opens `instance` on quest page `page` (one of its quests, or a chain step's light page).
local function OpenQuestPage(instance, page)
    local ui = Open()
    ui:GoToSource(instance)
    ui:SelectQuest(page)
end

-- Quest `questID` on the first dungeon or raid it is part of for the
-- player's side (ns.QuestChainNotes.Dungeons, the one it is a quest of
-- first): that quest's page, or for a step of a chain leading into one of
-- its quests, the step's light page, which shows the chain's rows, else the
-- quest the chain leads to. False when it is part of none.
local function ShowOnFirstDungeon(questID)
    local entry = ns.QuestChainNotes.Dungeons(questID)[1]
    if not entry then return false end
    local chain = ns.UI.QuestChain
    OpenQuestPage(entry.instance, chain.Page(entry.instance, questID) or chain.Step(questID) or entry.quest)
    return true
end

-- A dungeon quest's page, by its quest ID or name; by ID, also a step of a
-- quest chain leading into a dungeon quest. The quest log's Open in
-- NeedRoll button (UI/QuestChainNotes.lua) opens its quests with this.
function NeedRoll_ShowQuest(quest)
    if not CanShow() or not ns.Modules:IsOn("QUESTS") then return false end
    quest = FromText(quest)
    if quest == nil then return false end
    if type(quest) == "number" and ShowOnFirstDungeon(quest) then return true end
    -- By name, or a quest only the other side can take.
    local key = NameKey(quest)
    for _, instance in ipairs(Instances(PLACES)) do
        local found = ns.Modules:IsOn(instance.category) and QuestIn(instance, quest, key)
        if found then
            OpenQuestPage(instance, found)
            return true
        end
    end
    return false
end

-- The first item source (ns.Wishlist:Sources) on a tab in use: a drop when `wantDrop`, else not.
local function FirstShowable(sources, wantDrop)
    for _, source in ipairs(sources) do
        if (source.kind == "Drop") == wantDrop and ns.Modules:IsOn(source.inst.category)
            and (source.kind ~= "Quest" or ns.Modules:IsOn("QUESTS")) then
            return source
        end
    end
end

-- An item where NeedRoll lists it: the first boss that drops it, else the
-- first vendor list, collection, recipe or quest reward with it, the item
-- highlighted. `item`: an item ID or a link.
function NeedRoll_ShowItem(item)
    if not CanShow() then return false end
    local itemID = type(item) == "string" and (ns.Items:IDFromLink(item) or tonumber(item)) or item
    if type(itemID) ~= "number" then return false end
    local sources = ns.Wishlist:Sources(itemID)
    local source = FirstShowable(sources, true) or FirstShowable(sources, false)
    if not source then return false end
    local ui = Open()
    if source.kind == "Crafted" then
        ui:ClearHistory()
        ui:SelectRecipe(source.inst, source.enc)
    elseif source.kind == "Quest" then
        OpenQuestPage(source.inst, source.quest)
    else
        ui:GoToSource(source.inst, source.enc, itemID)
    end
    return true
end

-- A profession, on `recipe` if given: its name, spell ID, or the ID of the
-- item it makes or of the recipe item that teaches it.
function NeedRoll_ShowProfession(profession, recipe)
    return ShowIn({ "PROFESSION" }, profession, recipe)
end

-- A faction's rewards, on `standing` if given ("Revered", or 4-8 as the
-- game numbers standings). `faction`: its name or faction ID.
function NeedRoll_ShowFaction(faction, standing)
    return ShowIn({ "FACTION" }, faction, standing)
end

-- A battleground's rewards, the player's side first, on `rank` if given.
function NeedRoll_ShowPvP(battleground, rank)
    return ShowIn({ "PVP" }, battleground, rank)
end

-- A Collections list (Mounts, Tier Sets, a world event), on `section` if given.
function NeedRoll_ShowCollection(collection, section)
    return ShowIn({ "COLLECTION" }, collection, section)
end
