-- Wishlists: items the player wants, starred on any loot list or imported
-- from sixtyupgrades.com, in named lists shared by every character on the
-- account (NeedRollDB is account-wide). One list is current: stars add to
-- it and the Wishlist tab shows it. Saved in NeedRollDB.wishlist:
--     { current = "Starred items", view = "overview" | "details",
--       lists = { { name = "Starred items", note = "Imported from sixtyupgrades  ·  Flow, Warrior 60",
--                   items = { { itemID = 12640, slot = "HEAD" }, ... } } } }
-- `slot` is the gear slot an import named (it tells Main Hand from Off
-- Hand); starred items have none and go by the item's own slot.
local _, ns = ...
local L = ns.L

local WL = {}
ns.Wishlist = WL

-- The first list's name, in the player's language when it's made. Lists are
-- found by their saved name, so ones made in English keep working.
WL.DEFAULT = L["Starred items"]
local SHARE_PREFIX = "NR1" -- starts a share string; a new format would get a new prefix

-- Drops entries with no item, once per session: older builds let the star
-- show on dungeon and raid search results, which saved { itemID = nil }.
local isPruned = false

local function Prune(lists)
    for _, list in ipairs(lists) do
        for i = #list.items, 1, -1 do
            local entry = list.items[i]
            if type(entry) ~= "table" or type(entry.itemID) ~= "number" then table.remove(list.items, i) end
        end
    end
    isPruned = true
end

-- NeedRollDB.wishlist, pruned.
local function Store()
    local store = ns.db.wishlist
    if not isPruned then Prune(store.lists) end
    return store
end

-- Lists, Current, Select, Clear, CleanName, FreeName, AddList, SavePreset,
-- Rename, Delete, Replace, OnChange and NotifyChange (Core/SavedLists.lua).
ns.SavedLists.AddTo(WL, {
    Store = Store,
    defaultName = WL.DEFAULT,
    fallbackName = "Wishlist",
    CopyItem = function(entry) return { itemID = entry.itemID, slot = entry.slot } end,
})

-- "overview" or "details": which page the tab shows.
function WL:View()
    return Store().view == "details" and "details" or "overview"
end

function WL:SetView(view)
    Store().view = view
    self:NotifyChange()
end

local function IndexOf(list, itemID)
    for i, entry in ipairs(list.items) do
        if entry.itemID == itemID then return i end
    end
end

function WL:Has(itemID)
    return IndexOf(self:Current(), itemID) ~= nil
end

-- Stars an item on the current list, or takes it off. Returns whether it
-- is on the list now.
function WL:Toggle(itemID)
    if not itemID then return false end
    local list = self:Current()
    local index = IndexOf(list, itemID)
    if index then
        table.remove(list.items, index)
    else
        table.insert(list.items, { itemID = itemID })
    end
    self:NotifyChange()
    return index == nil
end

-- Stars every item of `itemIDs` (a whole set), or takes them all off when
-- every one is on the list already. Returns whether they are on it now.
function WL:ToggleAll(itemIDs)
    local list = self:Current()
    local isAllOn = true
    for _, itemID in ipairs(itemIDs) do
        if not IndexOf(list, itemID) then isAllOn = false end
    end
    for _, itemID in ipairs(itemIDs) do
        local index = IndexOf(list, itemID)
        if isAllOn then
            table.remove(list.items, index)
        elseif not index then
            table.insert(list.items, { itemID = itemID })
        end
    end
    self:NotifyChange()
    return not isAllOn
end

function WL:Remove(itemID)
    local list = self:Current()
    local index = IndexOf(list, itemID)
    if not index then return end
    table.remove(list.items, index)
    self:NotifyChange()
end

-- Puts a removed entry back on the current list at `index` (an unstar
-- undone on the Wishlist tab), keeping the slot an import gave it.
function WL:Restore(entry, index)
    local list = self:Current()
    if IndexOf(list, entry.itemID) then return end
    table.insert(list.items, math.min(index, #list.items + 1), entry)
    self:NotifyChange()
end

-- Slots ---------------------------------------------------------------

-- The cloak slot's name is the game's own, so translators don't confuse it
-- with the Back button's "Back".
local BACK = INVTYPE_CLOAK or "Back"
-- sixtyupgrades' slot names, in paper-doll order.
local IMPORT_SLOTS = {
    HEAD = { L["Head"], 1 }, NECK = { L["Neck"], 2 }, SHOULDERS = { L["Shoulder"], 3 }, BACK = { BACK, 4 },
    CHEST = { L["Chest"], 5 }, SHIRT = { L["Shirt"], 6 }, TABARD = { L["Tabard"], 7 }, WRISTS = { L["Wrist"], 8 },
    HANDS = { L["Hands"], 9 }, WAIST = { L["Waist"], 10 }, LEGS = { L["Legs"], 11 }, FEET = { L["Feet"], 12 },
    FINGER_1 = { L["Finger"], 13 }, FINGER_2 = { L["Finger"], 13 }, TRINKET_1 = { L["Trinket"], 14 },
    TRINKET_2 = { L["Trinket"], 14 }, MAIN_HAND = { L["Main Hand"], 16 }, OFF_HAND = { L["Off Hand"], 17 },
    RANGED = { L["Ranged"], 18 },
}
-- The game's equip locations, in the same order.
local EQUIP_SLOTS = {
    INVTYPE_HEAD = { L["Head"], 1 }, INVTYPE_NECK = { L["Neck"], 2 }, INVTYPE_SHOULDER = { L["Shoulder"], 3 },
    INVTYPE_CLOAK = { BACK, 4 }, INVTYPE_CHEST = { L["Chest"], 5 }, INVTYPE_ROBE = { L["Chest"], 5 },
    INVTYPE_BODY = { L["Shirt"], 6 }, INVTYPE_TABARD = { L["Tabard"], 7 }, INVTYPE_WRIST = { L["Wrist"], 8 },
    INVTYPE_HAND = { L["Hands"], 9 }, INVTYPE_WAIST = { L["Waist"], 10 }, INVTYPE_LEGS = { L["Legs"], 11 },
    INVTYPE_FEET = { L["Feet"], 12 }, INVTYPE_FINGER = { L["Finger"], 13 }, INVTYPE_TRINKET = { L["Trinket"], 14 },
    INVTYPE_2HWEAPON = { L["Two-Hand"], 15 }, INVTYPE_WEAPON = { L["One-Hand"], 16 },
    INVTYPE_WEAPONMAINHAND = { L["Main Hand"], 16 }, INVTYPE_WEAPONOFFHAND = { L["Off Hand"], 17 },
    INVTYPE_SHIELD = { L["Off Hand"], 17 }, INVTYPE_HOLDABLE = { L["Off Hand"], 17 },
    INVTYPE_RANGED = { L["Ranged"], 18 }, INVTYPE_RANGEDRIGHT = { L["Ranged"], 18 }, INVTYPE_THROWN = { L["Ranged"], 18 },
    INVTYPE_RELIC = { L["Relic"], 18 }, INVTYPE_BAG = { L["Bag"], 19 }, INVTYPE_QUIVER = { L["Bag"], 19 },
}
local SHIRT_TABARD = { SHIRT = true, TABARD = true, INVTYPE_BODY = true, INVTYPE_TABARD = true }

local function EquipLoc(itemID)
    return (select(4, C_Item.GetItemInfoInstant(itemID)))
end

-- Whether an item has an equip slot (armor, weapons, bags, ammo...).
function WL:CanWear(itemID)
    local equipLoc = EquipLoc(itemID)
    return equipLoc ~= nil and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
        and equipLoc ~= "INVTYPE_NON_EQUIP"
end

-- Worn items get a star on their loot row.
function WL:CanStar(itemID) return self:CanWear(itemID) end

-- An entry's slot name and its place in paper-doll order.
function WL:Slot(entry)
    local slot = IMPORT_SLOTS[entry.slot or ""] or EQUIP_SLOTS[EquipLoc(entry.itemID) or ""]
    if slot then return slot[1], slot[2] end
    return L["Other"], 20 -- after every slot above
end

-- Sources ---------------------------------------------------------------
-- Where each item comes from, from NeedRoll's own lists: { kind, inst (the
-- instance), enc (the encounter), name (the boss, rank, recipe or quest), rate,
-- quest }. kind is "Drop" (dungeon and raid bosses and trash), "PvP",
-- "Faction", "Collection", "Crafted" or "Quest". Built once, when first asked.
local sourcesByItem

local function AddSource(itemID, source)
    sourcesByItem[itemID] = sourcesByItem[itemID] or {}
    table.insert(sourcesByItem[itemID], source)
end

local LOOT_KINDS = { DUNGEON = "Drop", RAID = "Drop", PVP = "PvP", FACTION = "Faction", COLLECTION = "Collection" }

local function BuildSources()
    sourcesByItem = {}
    for category, kind in pairs(LOOT_KINDS) do
        for _, instance in ipairs(ns.Data:List(category)) do
            for _, encounter in ipairs(instance.encounters) do
                local bosses = kind == "Drop" and ns.Data:Bosses(instance, encounter)
                for _, entry in ipairs(encounter.loot) do
                    -- The Ring of Law's loot is under the fighter who drops it.
                    local boss = entry.boss and bosses and bosses[entry.boss]
                    if entry.itemID and not entry.recipe then
                        AddSource(entry.itemID, { kind = kind, inst = instance, enc = encounter,
                            name = boss and boss[1] or encounter.name,
                            rate = ns.SHOW_DROP_RATES and entry.dropRate or nil })
                    end
                end
            end
        end
    end
    for _, instance in ipairs(ns.Data:List("PROFESSION")) do
        for _, encounter in ipairs(instance.encounters) do
            local made = encounter.spellID and encounter.loot[1]
            if made and made.itemID and not made.recipe then
                AddSource(made.itemID, { kind = "Crafted", inst = instance, enc = encounter, name = encounter.name })
            end
        end
    end
    -- Dungeon and raid quest rewards. Quests listed under a wing's or half's
    -- own ID that the data merged into another instance are left out.
    for instanceID, quests in pairs(ns.Data.quests) do
        local instance = ns.Data:Get(instanceID)
        if instance and instance.id == instanceID then
            for _, quest in ipairs(quests) do
                for _, field in ipairs({ "choice", "rewards" }) do
                    for _, itemID in ipairs(quest[field] or {}) do
                        AddSource(itemID, { kind = "Quest", inst = instance, quest = quest, name = quest.name })
                    end
                end
            end
        end
    end
end

local NO_SOURCES = {}

function WL:Sources(itemID)
    if not sourcesByItem then BuildSources() end
    return sourcesByItem[itemID] or NO_SOURCES
end

-- The kind an item is filed under: "Drop" when any dungeon or raid drops
-- it, else its first source's kind, else "Unknown".
function WL:Kind(itemID)
    local sources = self:Sources(itemID)
    for _, source in ipairs(sources) do
        if source.kind == "Drop" then return "Drop" end
    end
    return sources[1] and sources[1].kind or "Unknown"
end

-- The chance an item drops in one clear of `instance`: any of its bosses there
-- dropping it. Nil when no rate is known.
function WL:ClearChance(itemID, instance)
    local missAll, isKnown = 1, false
    for _, source in ipairs(self:Sources(itemID)) do
        if source.kind == "Drop" and source.inst == instance and source.rate then
            missAll = missAll * (1 - source.rate)
            isKnown = true
        end
    end
    return isKnown and (1 - missAll) or nil
end

-- Its best chance in one clear of any dungeon or raid.
function WL:BestChance(itemID)
    local best
    for _, source in ipairs(self:Sources(itemID)) do
        if source.kind == "Drop" then
            local chance = self:ClearChance(itemID, source.inst)
            if chance and (not best or chance > best) then best = chance end
        end
    end
    return best
end

-- An item's best source: the dungeon or raid it likeliest drops in (its
-- likeliest boss there), else its first source; nil when NeedRoll has none.
function WL:BestSource(itemID)
    local best, bestChance
    for _, source in ipairs(self:Sources(itemID)) do
        if source.kind == "Drop" then
            local chance = self:ClearChance(itemID, source.inst) or 0
            if not best or chance > bestChance
                or (chance == bestChance and source.inst == best.inst and (source.rate or 0) > (best.rate or 0)) then
                best, bestChance = source, chance
            end
        end
    end
    return best or self:Sources(itemID)[1]
end

-- Whether this character has it: worn, in the bags or in the bank.
function WL:Owned(itemID)
    if C_Item.IsEquippedItem(itemID) then return true end
    return (C_Item.GetItemCount(itemID, true) or 0) > 0
end

-- The items on `list` this character owns, as { [itemID] = true }, and how many.
function WL:OwnedItems(list)
    local isOwned, ownedCount = {}, 0
    for _, entry in ipairs(list.items) do
        if self:Owned(entry.itemID) then
            isOwned[entry.itemID] = true
            ownedCount = ownedCount + 1
        end
    end
    return isOwned, ownedCount
end

-- Puts an entry into the run of each dungeon or raid that drops it, starting a run where needed.
local function AddToRuns(runByInstance, runs, entry)
    for _, source in ipairs(WL:Sources(entry.itemID)) do
        if source.kind == "Drop" then
            local run = runByInstance[source.inst]
            if not run then
                run = { inst = source.inst, items = {}, byItem = {} }
                runByInstance[source.inst] = run
                table.insert(runs, run)
            end
            local item = run.byItem[entry.itemID]
            if not item then
                item = { entry = entry, srcs = {}, chance = WL:ClearChance(entry.itemID, source.inst) }
                run.byItem[entry.itemID] = item
                table.insert(run.items, item)
            end
            table.insert(item.srcs, source)
        end
    end
end

-- The current list's (or `list`'s) dungeon and raid drops grouped into runs, best first
-- (likeliest, then more items, then by name): { { inst, items = { { entry, srcs (its sources
-- there), chance } }, chance } }, a run's chance being that any of its items drops in a clear.
-- Items this character owns are left out: there's no need to run for them. `isOwned` is
-- WL:OwnedItems' set, for a caller that already has it.
function WL:Runs(list, isOwned)
    list = list or self:Current()
    isOwned = isOwned or self:OwnedItems(list)
    local runByInstance, runs = {}, {}
    for _, entry in ipairs(list.items) do
        if not isOwned[entry.itemID] then AddToRuns(runByInstance, runs, entry) end
    end
    for _, run in ipairs(runs) do
        local missAll, isKnown = 1, false
        for _, item in ipairs(run.items) do
            if item.chance then
                missAll = missAll * (1 - item.chance)
                isKnown = true
            end
        end
        run.chance = isKnown and (1 - missAll) or nil
    end
    table.sort(runs, function(a, b)
        if (a.chance or -1) ~= (b.chance or -1) then return (a.chance or -1) > (b.chance or -1) end
        if #a.items ~= #b.items then return #a.items > #b.items end
        return a.inst.name < b.inst.name
    end)
    return runs
end

-- Import and export ----------------------------------------------------

local JSON_LITERALS = { { "true", true }, { "false", false }, { "null", nil } }
local JSON_ESCAPES = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }

-- A small JSON reader: enough for a sixtyupgrades export. Returns the
-- value, or nil when the text isn't JSON. Letters past ASCII written as
-- \u escapes come back as "?" (names are only shown, never matched).
local function ParseJSON(text)
    local pos = 1
    local ReadValue
    local function Fail() error("json", 0) end
    local function SkipSpace() pos = text:find("[^%s]", pos) or #text + 1 end
    local function Char() return text:sub(pos, pos) end
    local function ReadString()
        pos = pos + 1 -- the opening quote
        local parts = {}
        while true do
            local char = Char()
            if char == "" then Fail() end
            if char == '"' then
                pos = pos + 1
                return table.concat(parts)
            elseif char ~= "\\" then
                parts[#parts + 1] = char
                pos = pos + 1
            elseif text:sub(pos + 1, pos + 1) == "u" then
                local code = tonumber(text:sub(pos + 2, pos + 5), 16) or 63
                parts[#parts + 1] = code < 128 and string.char(code) or "?"
                pos = pos + 6
            else
                local escaped = text:sub(pos + 1, pos + 1)
                parts[#parts + 1] = JSON_ESCAPES[escaped] or escaped
                pos = pos + 2
            end
        end
    end
    -- An object's or array's items up to `closer`, comma-separated, each read by ReadItem().
    local function ReadItems(closer, ReadItem)
        pos = pos + 1 -- the opening bracket
        SkipSpace()
        if Char() == closer then
            pos = pos + 1
            return
        end
        while true do
            ReadItem()
            SkipSpace()
            local separator = Char()
            pos = pos + 1
            if separator == closer then return end
            if separator ~= "," then Fail() end
        end
    end
    local function ReadObject()
        local object = {}
        ReadItems("}", function()
            SkipSpace()
            if Char() ~= '"' then Fail() end
            local key = ReadString()
            SkipSpace()
            if Char() ~= ":" then Fail() end
            pos = pos + 1
            object[key] = ReadValue()
        end)
        return object
    end
    local function ReadArray()
        local array = {}
        ReadItems("]", function() array[#array + 1] = ReadValue() end)
        return array
    end
    function ReadValue()
        SkipSpace()
        local char = Char()
        if char == "{" then return ReadObject() end
        if char == "[" then return ReadArray() end
        if char == '"' then return ReadString() end
        for _, literal in ipairs(JSON_LITERALS) do
            local word = literal[1]
            if text:sub(pos, pos + #word - 1) == word then
                pos = pos + #word
                return literal[2]
            end
        end
        local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
        if not number or number == "" then Fail() end
        pos = pos + #number
        return tonumber(number)
    end
    local ok, value = pcall(ReadValue)
    if ok then return value end
end

local function Capitalized(word)
    word = tostring(word or "")
    return word:sub(1, 1):upper() .. word:sub(2):lower()
end

-- A list shared from NeedRoll; `name` is already cleaned (nil when the string had none).
local function ParseShareString(name, codes)
    local items, isListed = {}, {}
    for code in codes:gmatch("[%w]+") do
        local itemID = tonumber(code, 36)
        if itemID and itemID > 0 and not isListed[itemID] then
            isListed[itemID] = true
            table.insert(items, { itemID = itemID })
        end
    end
    if #items == 0 then return nil, L["That share string has no items in it."] end
    return { name = name or L["Shared list"], note = L["Shared from NeedRoll"], items = items, shared = true }
end

-- A sixtyupgrades.com export: JSON with the gear in `items`, for `character`.
local function ParseExport(text)
    local start = text:find("{", 1, true)
    if not start then return nil, L["Paste a sixtyupgrades.com export or a NeedRoll share string."] end
    local data = ParseJSON(text:sub(start))
    if type(data) ~= "table" or type(data.items) ~= "table" then
        return nil, L["That doesn't look like a sixtyupgrades.com export."]
    end
    local items, isListed = {}, {}
    for _, item in ipairs(data.items) do
        local itemID = type(item) == "table" and tonumber(item.id)
        if itemID and itemID > 0 and not isListed[itemID] then
            isListed[itemID] = true
            table.insert(items, { itemID = itemID, slot = type(item.slot) == "string" and item.slot or nil })
        end
    end
    if #items == 0 then return nil, L["That export has no gear in it."] end
    local char = type(data.character) == "table" and data.character or {}
    local who = {} -- the character's name, "Warrior 60"
    -- Pasted text is shown as typed (ns.Literal).
    if type(char.name) == "string" then who[#who + 1] = ns.Literal(char.name) end
    local class = char.gameClass and ns.Literal(Capitalized(char.gameClass))
    local level = tonumber(char.level) -- pasted text: a level that isn't a number is left out
    if class and level then
        who[#who + 1] = ("%s %s"):format(class, level)
    elseif class then
        who[#who + 1] = class
    end
    -- ns.Theme is read here, at import time: Core files load before the UI's Theme.lua.
    local note = ns.Theme:JoinDots(L["Imported from sixtyupgrades"], table.concat(who, ", "))
    local setName = type(data.name) == "string" and data.name or L["Imported"]
    if type(char.name) == "string" then setName = setName .. " " .. ns.DOT .. " " .. char.name end
    return { name = WL:CleanName(setName) or L["Imported"], note = note, items = items, character = who }
end

-- What pasted text holds: a list shared from NeedRoll ("NR1:Name:ids in base 36, joined
-- by dots", anywhere in the text, so a whole chat line can be pasted), or a sixtyupgrades export.
-- Returns { name, note, items = { { itemID, slot } } }, or nil and why not.
function WL:Parse(text)
    text = tostring(text or "")
    local name, codes = text:match(SHARE_PREFIX .. ":([^:]*):([%w%.]+)")
    if codes then return ParseShareString(self:CleanName(name), codes) end
    return ParseExport(text)
end

-- Whether an entry is a shirt or tabard, which an import can leave out.
function WL:IsShirtOrTabard(entry)
    return SHIRT_TABARD[entry.slot or ""] or SHIRT_TABARD[EquipLoc(entry.itemID) or ""] or false
end

-- The current list as a share string; `withCosmetic` false leaves out
-- shirts and tabards.
function WL:Export(withCosmetic)
    local list = self:Current()
    local codes = {}
    for _, entry in ipairs(list.items) do
        if withCosmetic ~= false or not self:IsShirtOrTabard(entry) then
            table.insert(codes, ns.Base36(entry.itemID))
        end
    end
    return ("%s:%s:%s"):format(SHARE_PREFIX, list.name, table.concat(codes, "."))
end
