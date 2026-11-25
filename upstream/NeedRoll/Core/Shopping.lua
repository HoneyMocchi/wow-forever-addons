-- Shopping lists: crafted items the player wants, each broken down into its
-- materials, and items bought as they are. A material that is crafted
-- itself can be opened, so its own materials are bought instead of it
-- (Copper Tube becomes Copper Bar and Weak Flux). The lists are named and
-- shared by every character on the account, one of them current
-- (Core/SavedLists.lua), saved in NeedRollDB.shopping:
--     { current = "Shopping list",
--       lists = { { name = "Shopping list", items = {
--           { itemID = 4362, count = 1, profession = "ENGINEERING", recipe = "S3925",
--             open = { ["1"] = true, ["1.1"] = true } },
--           { itemID = 13466, count = 8, open = {} } } } } }
-- `count` is how many of the item are wanted; `open` holds the materials
-- opened into their own materials, by their place in the tree ("1.1" is the
-- first material of the first material). An entry with no profession and no
-- recipe NeedRoll knows (an Auctionator import of a herb) is bought as it is.
local _, ns = ...
local L = ns.L

local Shop = {}
ns.Shopping = Shop

-- The first list's name, in the player's language when it's made.
Shop.DEFAULT = L["Shopping list"]

-- Before there were named lists, NeedRollDB.shopping was the one list's
-- entries themselves: they become the first list, so nobody loses theirs.
local function MoveOldEntries(store)
    local entries = {}
    for i = 1, #store do entries[i] = store[i] end
    for i = #entries, 1, -1 do store[i] = nil end
    table.insert(store.lists, 1, { name = ns.SavedLists.FreeName(store.lists, Shop.DEFAULT), items = entries })
end

-- NeedRollDB.shopping, its old single list moved into its lists.
local function Store()
    local store = ns.db.shopping
    store.lists = store.lists or {}
    if store[1] ~= nil then MoveOldEntries(store) end
    return store
end

local function CopyEntry(entry)
    local open = {}
    for path, isOpen in pairs(entry.open or {}) do open[path] = isOpen end
    return { itemID = entry.itemID, count = entry.count, profession = entry.profession, recipe = entry.recipe,
        open = open }
end

-- Lists, Current, Select, Clear, CleanName, FreeName, AddList, SavePreset,
-- Rename, Delete, Replace, OnChange and NotifyChange (Core/SavedLists.lua).
ns.SavedLists.AddTo(Shop, { Store = Store, defaultName = Shop.DEFAULT, fallbackName = Shop.DEFAULT,
    CopyItem = CopyEntry })

-- The current list's entries in the order added (an empty table before the saved settings load).
function Shop:Entries()
    if not ns.db then return {} end
    return self:Current().items
end

-- How many one craft of `encounter` makes.
local function PerCraft(encounter)
    local made = encounter.loot and encounter.loot[1]
    return made and not made.recipe and made.count or 1
end

-- True when `encounter` is a recipe whose materials can be listed.
local function HasMaterials(encounter)
    return encounter ~= nil and encounter.reagents ~= nil and #encounter.reagents > 0
end

-- The profession and recipe an entry was added from, or the usual recipe for its item.
local function RecipeOf(entry)
    local instance = entry.profession and ns.Data:Get(entry.profession)
    if instance then
        for _, encounter in ipairs(instance.encounters) do
            if encounter.id == entry.recipe then return instance, encounter end
        end
    end
    return ns.Data:RecipeFor(entry.itemID)
end

-- Whether a recipe can go on the list: it makes an item and needs materials.
function Shop:CanAdd(encounter)
    local made = encounter and encounter.spellID and encounter.loot[1]
    return made ~= nil and not made.recipe and HasMaterials(encounter)
end

function Shop:Find(itemID)
    for i, entry in ipairs(self:Entries()) do
        if entry.itemID == itemID then return i, entry end
    end
end

-- Adds one craft's worth of what `encounter` (in profession `instance`) makes, or one
-- more craft's worth if it is already listed. Returns the new count.
function Shop:Add(instance, encounter)
    if not self:CanAdd(encounter) then return end
    local itemID = encounter.loot[1].itemID
    local _, entry = self:Find(itemID)
    if entry then
        entry.count = entry.count + PerCraft(encounter)
    else
        entry = { itemID = itemID, count = PerCraft(encounter), profession = instance.id,
            recipe = encounter.id, open = {} }
        table.insert(self:Entries(), entry)
    end
    self:NotifyChange()
    return entry.count
end

-- Changes an entry's count by whole crafts (`steps` may be negative); it
-- never drops below one craft.
function Shop:ChangeCrafts(index, steps)
    local entry = self:Entries()[index]
    if not entry then return end
    local _, encounter = RecipeOf(entry)
    local perCraft = encounter and PerCraft(encounter) or 1
    entry.count = math.max(perCraft, entry.count + steps * perCraft)
    self:NotifyChange()
end

function Shop:Remove(index)
    table.remove(self:Entries(), index)
    self:NotifyChange()
end

-- Whether what is already in the bags is used first: crafted items lower the
-- crafts, materials come off To buy (BuildTree).
function Shop:SubtractBags()
    return ns.db and ns.db.shoppingBags or false
end

function Shop:SetSubtractBags(on)
    ns.db.shoppingBags = on and true or false
    self:NotifyChange()
end

-- Bank ---------------------------------------------------------------------
-- What each character keeps in the bank, saved from their last bank visit
-- (NeedRollDB.bank[ns.CharacterKey()] = { [itemID] = count }), so "In bank"
-- still shows away from the bank. The bank only changes while it is open,
-- and it is scanned again on every change then.
local isBankOpen = false

-- The containers scanned as the bank, each once: Classic's numbering (BANK_CONTAINER, then
-- bank bags after the carried ones) and the CharacterBankTab_ Enum.BagIndex names. Forever's
-- Enum.BagIndex calls -1 Keyring and 5 ReagentBag (CarriedBags scans that too), so which of
-- these hold the bank on Forever is not yet checked in game.
local function BankBags()
    local bags, isListed = {}, {}
    local function Add(bag)
        if bag and not isListed[bag] then isListed[bag] = true; table.insert(bags, bag) end
    end
    Add(BANK_CONTAINER or -1)
    local first = (NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do Add(bag) end
    for name, bag in pairs(Enum.BagIndex) do
        if name:find("^CharacterBankTab") or name:find("^BankBag") then Add(bag) end
    end
    return bags
end

-- Counts every item in the given containers into ns.db[store][character].
local function Scan(store, bags)
    if not ns.db then return end
    local counts = {}
    for _, bag in ipairs(bags) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
            end
        end
    end
    ns.db[store] = ns.db[store] or {}
    ns.db[store][ns.CharacterKey()] = counts
end

local function ScanBank() Scan("bank", BankBags()) end

-- How many of itemID this character has in the bank. The game's own count
-- wins when it knows the bank; otherwise the last visit's count is used.
function Shop:BankCount(itemID)
    -- GetItemCount with includeBank counts bags and bank; without, bags only.
    local liveCount = (C_Item.GetItemCount(itemID, true) or 0) - (C_Item.GetItemCount(itemID) or 0)
    local saved = ns.db and ns.db.bank and ns.db.bank[ns.CharacterKey()]
    if isBankOpen or not saved then return math.max(0, liveCount) end
    return math.max(liveCount, saved[itemID] or 0)
end

ns:On("BANKFRAME_OPENED", function()
    isBankOpen = true
    ScanBank()
end)
ns:On("BANKFRAME_CLOSED", function() isBankOpen = false end)
ns:On("PLAYERBANKSLOTS_CHANGED", function() if isBankOpen then ScanBank() end end)
ns:On("BAG_UPDATE_DELAYED", function() if isBankOpen then ScanBank() end end)

-- Alts ---------------------------------------------------------------------
-- Every character's bags are saved too (NeedRollDB.bags, like the bank),
-- with their server and faction (NeedRollDB.characters), so the Shopping
-- List can count what the alts hold. Only alts on the same server and
-- faction count, since only they can mail it over. An alt shows up once it
-- has logged in with this version, and its bank once it has visited it.
local function CarriedBags()
    local bags = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do table.insert(bags, bag) end
    table.insert(bags, Enum.BagIndex.ReagentBag)
    return bags
end

-- This character's realm name as the game gave it: now, or, since WoW:
-- Forever's build 71037 left GetRealmName() empty, to a character on its
-- server before (NeedRollDB.realmOfServer, Core/Init.lua); nil when the game
-- never did. Never the realm of a record moved from an old "Name-<realm>"
-- key: which server that key was saved on can be a guess.
local function MyRealmName()
    local realm = ns.Plain(GetRealmName())
    if realm and realm ~= "" then return realm end
    local realmOfServer = ns.db and ns.db.realmOfServer
    return realmOfServer and realmOfServer[ns.PlayerServerID()]
end

-- Saves who this character is, and their money, in NeedRollDB.characters:
-- name, realm (MyRealmName), server (the server ID in its GUID,
-- ns.PlayerServerID), faction, class, money. The record is updated field by
-- field, so a bag scan and a money change each keep what the other saved.
local function SaveCharacter()
    if not ns.db then return end
    ns.db.characters = ns.db.characters or {}
    local key = ns.CharacterKey()
    local record = ns.db.characters[key] or {}
    ns.db.characters[key] = record
    record.name, record.realm, record.server = ns.Plain(UnitName("player")), MyRealmName(), ns.PlayerServerID()
    record.faction, record.class = UnitFactionGroup("player"), select(2, UnitClass("player"))
    record.money = GetMoney()
end

local function ScanBags()
    if not ns.db then return end
    SaveCharacter()
    Scan("bags", CarriedBags())
end

ns:On("BAG_UPDATE_DELAYED", ScanBags)
ns:On("PLAYER_LOGOUT", ScanBags)
ns:On("PLAYER_ENTERING_WORLD", SaveCharacter)
ns:On("PLAYER_MONEY", SaveCharacter)

-- Whether the saved character `char` is on this character's server (`me`:
-- its server ID and realm name). Records saved since GUID keys say by the
-- server ID; an older one (the alt hasn't logged in since) only by a realm
-- name both have.
local function IsOnMyServer(char, me)
    if char.server and me.server then return char.server == me.server end
    return char.realm ~= nil and char.realm ~= "" and char.realm == me.realm
end

-- What this character's alts hold of itemID, bags and bank together: the
-- total, and { name, count, class } per alt that has any, most first.
function Shop:AltCounts(itemID)
    local total, list = 0, {}
    local characters = ns.db and ns.db.characters
    if not characters then return total, list end
    local myKey, faction = ns.CharacterKey(), UnitFactionGroup("player")
    local me = { server = ns.PlayerServerID(), realm = MyRealmName() }
    for key, char in pairs(characters) do
        local bags, bank = ns.db.bags and ns.db.bags[key], ns.db.bank and ns.db.bank[key]
        local count = (bags and bags[itemID] or 0) + (bank and bank[itemID] or 0)
        local canMail = key ~= myKey and char.faction == faction and IsOnMyServer(char, me)
        if canMail and count > 0 then
            total = total + count
            table.insert(list, { name = char.name, count = count, class = char.class })
        end
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    return total, list
end

-- Whether what the alts hold is used first too, as the bags are.
function Shop:SubtractAlts()
    return ns.db and ns.db.shoppingAlts or false
end

function Shop:SetSubtractAlts(on)
    ns.db.shoppingAlts = on and true or false
    self:NotifyChange()
end

-- Gold ---------------------------------------------------------------------
-- Each character's money is saved in their record (SaveCharacter above), so
-- the Shopping List can show the gold on all of them together.

-- The money on every character NeedRoll has saved, whatever their realm or
-- faction: the total in copper, and { name, realm, class, money } per
-- character, richest first (realm nil or "" when no realm name was ever
-- saved for it). This character's money is the live amount; the
-- others' is what they had at their last save (SavedVariables are written
-- only on /reload, logout or exit). Characters saved before NeedRoll kept
-- money are left out until they log in again.
function Shop:MoneyOnAllCharacters()
    local total = GetMoney()
    local myKey = ns.CharacterKey()
    local list = { { name = ns.Plain(UnitName("player")) or "?", realm = MyRealmName(),
        class = select(2, UnitClass("player")), money = total } }
    for key, char in pairs(ns.db and ns.db.characters or {}) do
        if key ~= myKey and char.money then
            total = total + char.money
            table.insert(list, { name = char.name, realm = char.realm, class = char.class, money = char.money })
        end
    end
    -- Equal money falls back to the name, so the order doesn't change from one look to the next.
    table.sort(list, function(a, b)
        if a.money ~= b.money then return a.money > b.money end
        return a.name < b.name
    end)
    return total, list
end

-- Opens a material into its own materials, or closes it again (`path`: "1.2").
function Shop:Toggle(index, path)
    local entry = self:Entries()[index]
    if not entry then return end
    entry.open = entry.open or {}
    entry.open[path] = not entry.open[path] or nil
    self:NotifyChange()
end

-- What the ticked subtract boxes count as already had, handed out over the
-- whole list in tree order so nothing is counted twice: two entries that
-- need Plaguebloom share the bags' Plaguebloom, and the first in the tree
-- gets them first. Returns Take(itemID, wanted), which hands out up to
-- `wanted` and returns how many came from the bags and how many from the
-- alts (the bags first), or nil when neither box is ticked.
local function HoldingsPool()
    local subtractBags, subtractAlts = Shop:SubtractBags(), Shop:SubtractAlts()
    if not (subtractBags or subtractAlts) then return nil end
    local bagsLeft, altsLeft = {}, {}
    return function(itemID, wanted)
        if not bagsLeft[itemID] then
            bagsLeft[itemID] = subtractBags and C_Item.GetItemCount(itemID) or 0
            altsLeft[itemID] = subtractAlts and (Shop:AltCounts(itemID)) or 0
        end
        local fromBags = math.min(wanted, bagsLeft[itemID])
        local fromAlts = math.min(wanted - fromBags, altsLeft[itemID])
        bagsLeft[itemID] = bagsLeft[itemID] - fromBags
        altsLeft[itemID] = altsLeft[itemID] - fromAlts
        return fromBags, fromAlts
    end
end

-- What the bags, the bank and the alts hold of each item to buy, shown
-- whether or not a subtract box is ticked.
local function CountHoldings(totals)
    for _, total in ipairs(totals) do
        total.bags = C_Item.GetItemCount(total.itemID) or 0
        total.bank = Shop:BankCount(total.itemID)
        total.alts = (Shop:AltCounts(total.itemID))
    end
end

-- The current list as tree rows, in display order, and the totals to buy.
-- Each row: { index, depth, itemID, need, path, craft = { instance, encounter } when
-- it can be opened, open, last (last of its siblings),
-- rails = { [level] = true where that level's line runs on below the row } }.
-- With a subtract box ticked, every row also has fromBags and fromAlts: how
-- many of `need` are already had (HoldingsPool). An open row, which is
-- crafted, has toCraft (need less what is had) and crafts, and its
-- materials are worked out from those, so a crafted item already in the
-- bags is crafted fewer times.
-- Totals: { { itemID, need, left, toBuy, bags, bank, alts } }, in the order they
-- first appear: `need` is what the closed rows need, `left` what the
-- holdings don't cover (nil with no box ticked), `toBuy` whichever applies,
-- and bags, bank and alts what is held (CountHoldings). Only the rows left
-- closed are bought.
function Shop:BuildTree()
    local rows, totals, totalByItem = {}, {}, {}
    local Take = HoldingsPool()

    local function Buy(itemID, need, left)
        local total = totalByItem[itemID]
        if not total then
            total = { itemID = itemID, need = 0, left = Take and 0 or nil }
            totalByItem[itemID] = total
            table.insert(totals, total)
        end
        total.need = total.need + need
        if Take then total.left = total.left + left end
    end

    -- One entry's tree, a row at a time. `branch`: the entry, its index and the items crafted
    -- above this row, which stay closed (recipes that make each other would open forever).
    local function AddRow(branch, itemID, need, depth, path, instance, encounter, rails)
        local isCraftable = HasMaterials(encounter) and not branch.crafting[itemID]
        local row = {
            index = branch.index, depth = depth, itemID = itemID, need = need, path = path,
            craft = isCraftable and { instance, encounter } or nil, rails = rails,
        }
        -- What was added is crafted when it has a recipe, else bought as it is; materials
        -- are crafted only when opened.
        local opened = branch.entry.open and branch.entry.open[path]
        row.open = isCraftable and (depth == 0 or opened) or false
        table.insert(rows, row)
        if Take then row.fromBags, row.fromAlts = Take(itemID, need) end
        local stillNeeded = need - (row.fromBags or 0) - (row.fromAlts or 0)
        if not row.open then
            Buy(itemID, need, stillNeeded)
            return row
        end
        row.toCraft = stillNeeded
        row.crafts = math.ceil(stillNeeded / PerCraft(encounter))
        branch.crafting[itemID] = true
        local lastIndex = #encounter.reagents
        for i, reagent in ipairs(encounter.reagents) do
            local childRails = {}
            for level, runsOn in pairs(rails) do childRails[level] = runsOn end
            childRails[depth + 1] = i < lastIndex or nil
            local childPath = path == "" and tostring(i) or (path .. "." .. i)
            local childInstance, childEncounter = ns.Data:RecipeFor(reagent.itemID)
            local child = AddRow(branch, reagent.itemID, reagent.count * row.crafts, depth + 1, childPath,
                childInstance, childEncounter, childRails)
            child.last = i == lastIndex
        end
        branch.crafting[itemID] = nil
        return row
    end

    for index, entry in ipairs(self:Entries()) do
        local instance, encounter = RecipeOf(entry)
        AddRow({ index = index, entry = entry, crafting = {} }, entry.itemID, entry.count, 0, "",
            instance, encounter, {})
    end
    for _, total in ipairs(totals) do total.toBuy = total.left or total.need end
    CountHoldings(totals)
    return rows, totals
end

-- Auctionator shopping lists ------------------------------------------------
-- Import and Export read and write the shopping-list text of the Auctionator
-- addon, so a list goes straight into and out of the auction house: one
-- list per line, its name, then each item after a "^":
--     Elixirs^"Mountain Silversage";;;;;;;;;;;#;;16^"Plaguebloom";;;;;;;;;;;#;;8
-- Each item is an auction house search: a plain name ("Plaguebloom"), or 14
-- fields split by ";": the name (in quotes for an exact match), category,
-- item level min and max, level min and max, crafted level min and max,
-- price min and max, quality, tier ("#" for none), expansion and quantity.
-- NeedRoll writes the name and the quantity, with the other fields empty as
-- Auctionator writes them, and reads back only those two: the rest narrow a
-- search and mean nothing on a shopping list.
-- Auctionator finds items by name, in the client's language, so the names
-- come from the game, and an import looks each one up among the items
-- NeedRoll's professions make and use.
local SEARCH_FIELDS = 14
local TIER_FIELD, NO_TIER = 12, "#"
local QUANTITY_FIELD = 14
local MAX_IMPORT_COUNT = 10000 -- more of one item than any list needs; a bigger number is cut to it

-- Text as it can sit in a line: "^" parts the items and a line break the lists.
local function LineSafe(text)
    return (text:gsub("[%^\r\n]", " "))
end

-- One item as Auctionator writes it: the exact name in quotes, the quantity last.
local function SearchTerm(name, quantity)
    local fields = {}
    for i = 1, SEARCH_FIELDS do fields[i] = "" end
    fields[1] = ('"%s"'):format(LineSafe(name))
    fields[TIER_FIELD] = NO_TIER
    fields[QUANTITY_FIELD] = tostring(quantity)
    return table.concat(fields, ";")
end

-- What an export lists: "materials" is the To buy column (after the
-- subtract boxes, leaving out what needs no buying), "items" the list's own
-- entries. { { itemID, quantity } }.
local function ExportedItems(what)
    local items = {}
    if what == "items" then
        for _, entry in ipairs(Shop:Entries()) do
            table.insert(items, { itemID = entry.itemID, quantity = entry.count })
        end
        return items
    end
    local _, totals = Shop:BuildTree()
    for _, total in ipairs(totals) do
        if total.toBuy > 0 then table.insert(items, { itemID = total.itemID, quantity = total.toBuy }) end
    end
    return items
end

-- The current list as one line of Auctionator text (`what`: "materials" or
-- "items", see ExportedItems). An item the client hasn't loaded has no name
-- yet: then it returns nil and those items' IDs, to load and try again.
function Shop:ExportAuctionator(what)
    local terms, unnamed = { LineSafe(self:Current().name) }, {}
    for _, item in ipairs(ExportedItems(what)) do
        local name = C_Item.GetItemNameByID(item.itemID)
        if name then
            table.insert(terms, SearchTerm(name, item.quantity))
        else
            table.insert(unnamed, item.itemID)
        end
    end
    if #unnamed > 0 then return nil, unnamed end
    return table.concat(terms, "^")
end

-- Names to item IDs ---------------------------------------------------------
-- Built the first time an import asks, from the game's names for every item
-- a profession makes or uses, in the client's language. A name the client
-- hasn't loaded is asked for; the import waits for the answers
-- (Shop:AwaitItemNames).
local itemIDByName      -- lowercased name -> item ID
local awaitedNames = {} -- item ID -> true while the game hasn't answered for its name
local awaitedCount = 0
local onNamesArrived = {} -- callbacks for when the last awaited name has come

-- A name as the index keys it: trimmed, lowercase (for English and the other
-- Latin-letter languages; other letters are matched as written).
local function NameKey(name)
    return strtrim(name):lower()
end

-- Every item a profession makes, then every material, each once: an item
-- of one name that is made gets matched before one that isn't.
local function ProfessionItems()
    local itemIDs, isListed = {}, {}
    local function Add(itemID)
        if itemID and not isListed[itemID] then
            isListed[itemID] = true
            table.insert(itemIDs, itemID)
        end
    end
    local professions = ns.Data:List("PROFESSION")
    for _, instance in ipairs(professions) do
        for _, encounter in ipairs(instance.encounters) do
            if Shop:CanAdd(encounter) then Add(encounter.loot[1].itemID) end
        end
    end
    for _, instance in ipairs(professions) do
        for _, encounter in ipairs(instance.encounters) do
            for _, reagent in ipairs(encounter.reagents or {}) do Add(reagent.itemID) end
        end
    end
    return itemIDs
end

-- Adds an item's name to the index. False while the client hasn't the name.
local function IndexName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if not name then return false end
    local key = NameKey(name)
    itemIDByName[key] = itemIDByName[key] or itemID
    return true
end

local function BuildNameIndex()
    itemIDByName = {}
    for _, itemID in ipairs(ProfessionItems()) do
        if not IndexName(itemID) then
            awaitedNames[itemID] = true
            awaitedCount = awaitedCount + 1
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
end

-- ns.Items:Load calls back only when a load succeeds; an item the server
-- doesn't have answers with a failure, which still ends the wait for it.
ns:On("ITEM_DATA_LOAD_RESULT", function(itemID, success)
    if not awaitedNames[itemID] then return end
    awaitedNames[itemID] = nil
    awaitedCount = awaitedCount - 1
    if success then IndexName(itemID) end
    if awaitedCount > 0 then return end
    local callbacks = onNamesArrived
    onNamesArrived = {}
    for _, callback in ipairs(callbacks) do callback() end
end)

-- Whether names an import is matched against are still on their way; if
-- they are, `callback` runs once the last has come.
function Shop:AwaitItemNames(callback)
    if not itemIDByName then BuildNameIndex() end
    if awaitedCount == 0 then return false end
    table.insert(onNamesArrived, callback)
    return true
end

-- An entry for an imported item: crafted from its recipe when NeedRoll has
-- one, else bought as it is.
local function ImportedEntry(itemID, count)
    local instance, encounter = ns.Data:RecipeFor(itemID)
    if not Shop:CanAdd(encounter) then return { itemID = itemID, count = count, open = {} } end
    return { itemID = itemID, count = count, profession = instance.id, recipe = encounter.id, open = {} }
end

-- One item's name and quantity (1 when it has none: Auctionator writes 0 or
-- nothing for that). Quotes around the name only ask for an exact match.
local function ReadSearchTerm(term)
    local fields = {}
    for field in (term .. ";"):gmatch("([^;]*);") do table.insert(fields, field) end
    local name = strtrim(fields[1] or ""):gsub('^"(.*)"$', "%1")
    local quantity = ns.HeardNumber(strtrim(fields[QUANTITY_FIELD] or "")) or 0
    return name, math.min(math.max(quantity, 1), MAX_IMPORT_COUNT)
end

-- One line: { name, items = entries, skipped = { names not found } }, or nil
-- for a line that isn't a list (no "^").
local function ReadList(line)
    local listName, terms = line:match("^([^%^]*)%^(.*)$")
    if not listName then return nil end
    local list = { name = Shop:CleanName(listName) or L["Imported"], items = {}, skipped = {} }
    local entryByItem = {}
    for term in (terms .. "^"):gmatch("([^%^]*)%^") do
        local itemName, quantity = ReadSearchTerm(term)
        local itemID = itemName ~= "" and itemIDByName[NameKey(itemName)]
        if itemID and entryByItem[itemID] then
            entryByItem[itemID].count = entryByItem[itemID].count + quantity
        elseif itemID then
            entryByItem[itemID] = ImportedEntry(itemID, quantity)
            table.insert(list.items, entryByItem[itemID])
        elseif itemName ~= "" then
            table.insert(list.skipped, itemName)
        end
    end
    return list
end

-- Reads pasted Auctionator text, any number of lines, blank ones skipped.
-- Returns { { name, items, skipped } } with a list for each line, or nil and
-- why not.
function Shop:ParseAuctionator(text)
    if not itemIDByName then BuildNameIndex() end
    local lists = {}
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        local list = ReadList(strtrim(line))
        if list then table.insert(lists, list) end
    end
    if #lists == 0 then
        return nil, L["Paste an Auctionator shopping list: its name, then each item after a ^."]
    end
    return lists
end

-- Imports parsed lists (Shop:ParseAuctionator) that found any items: the
-- first replaces the current list's items, or with `isReplacing` false
-- becomes a new list named `firstName`; every other is a new list. The
-- first is current afterwards. Returns how many items came in.
function Shop:ImportLists(lists, isReplacing, firstName)
    local shownName, itemCount = nil, 0
    for _, list in ipairs(lists) do
        if #list.items > 0 then
            itemCount = itemCount + #list.items
            if not shownName and isReplacing then
                self:Replace(list.items)
                shownName = self:Current().name
            else
                local name = self:AddList(not shownName and firstName or list.name, list.items)
                shownName = shownName or name
            end
        end
    end
    if shownName then self:Select(shownName) end
    return itemCount
end
