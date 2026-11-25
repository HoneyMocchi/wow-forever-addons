-- Loot pane: encounter header and a two-column grid of item cells with
-- quality-colored icons, slot/type, drop rate, vendor price or count and the
-- standard item tooltip. Entries can also be section labels ({ header = "...",
-- header2 = "..." over the second column }, a line of their own), spells
-- ({ spellID = N }, for enchants, which make no item) and boss abilities
-- ({ ability = spell ID }: the spell's icon, name, cast time and range, with
-- its description boxed under them). A label with `box = true` puts its
-- section in a stat box like the Overview's (recipe pages, loot sections),
-- one column wide when its items fit in one (or each label of a header2 pair
-- gets a box over its column) unless the label is `full`. A fold
-- ({ fold = true, key = N, boss = { name, display, level, rank, NPC ID },
-- count = items }) heads one boss's items in an encounter whose bosses drop
-- their own loot (the Ring of Law): the boss's portrait, name and item count
-- over a rule, folding its items away; every fold starts shut, then stays as
-- the player left it (Settings' "Remember sections"). A Scarce reagent's sources
-- are { gather = { name, skill, rate, samples }, profession = its list }:
-- the icon of what the node yields (else the profession's), the node or
-- mob, the skill it needs and how often the reagent comes from it, out of
-- how many gathers. `{ gap = N }` is N of empty space.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L

local COLUMNS = 2
local QUESTION_ICON = 134400  -- the question mark, for an item whose icon the game hasn't sent yet
local HEADER_HEIGHT = 64
local REP_HEIGHT = 18 -- the Factions standing bar under the subtitle
local REP_WIDTH = 220
local GAP = 6
local SECTION_HEIGHT = 22
-- A boxed loot section's sizes, in one table so the pane's builder holds them as one upvalue.
local BOX = {
    HEAD = 36,   -- a boxed section's label: 10 above, 16pt, room under
    LABEL = 18,  -- its label, in from the box's left edge
    INSET = 12,  -- cells inside a box, so icons line up with its label
    BOTTOM = 10, -- box edge under its last cell
    GAP = 12,    -- between one box and the next
    CLIP = 1,    -- a box cut off by the view's top: its top edge this far inside
    MIN = 10,    -- the shortest box drawn: its two rounded corners
    ARROW = 24,  -- a loot section's fold arrow, on screen (bigger than the list's 21)
}
local SOURCE_ROW = 19 -- a line under a recipe item: "Drops from", a mob, a vendor
local SOURCE_CREST = 17 -- a one-side vendor's faction crest
local SOURCE_TOP = 2  -- room between the item and its first source line
local TRAINERS_SHOWN = 3 -- a recipe's nearest trainers listed before "N more trainers"
local TRAINERS_TOP = 4   -- a trainers-only cell's first line, down from its top (level with an item's name)
local TRAINERS_ARROW = 10 -- the "N more trainers" arrow, on its longer side
local COUNT_SCALE = 1.25 -- a recipe product's or material's "x1", against a drop chance (Mike)
-- A boss ability is a card in the recipe boxes' style (Theme:CardBackdrop):
-- icon, name and cast line at the top, then its description lined up with
-- the icon. The cell grows to hold the text, so its hover highlight covers
-- the whole card.
local ABILITY_PAD = 8      -- card edge to icon and text block; block edge to its text
local ABILITY_BOX_TOP = 52 -- where the description starts, from the card's top
local FOLD_ROW = 42   -- a fold's clickable row
local FOLD_HEIGHT = 48 -- the row and the space under it
local FOLD_SCALE = 0.4 -- its boss portrait, against the header's
-- A PvP class fold's class badge: as big as the Collections tab's class
-- folds' (UI/Lists.lua), its centre this far from the row's left, where a
-- boss fold's portrait ring is.
local CLASS_FOLD = { BADGE = 26, BADGE_X = 14 }

-- AddDoubleLine with named colors (unpack only spreads the last argument).
local function AddTipPair(left, right, leftColor, rightColor)
    local r, g, b = unpack(leftColor)
    GameTooltip:AddDoubleLine(left, right, r, g, b, unpack(rightColor))
end

-- A boss's NPC ID for Theme:WithIds, followed on local checkouts by how many of
-- its kills drop sharing saved (Core/Drops.lua): "644  ·  12".
local function BossIds(npc)
    if not (npc and ns.Drops.available) then return npc end
    return Theme:JoinDots(npc, ns.Drops:KillCount(npc))
end

-- Items that begin a quest: every dungeon quest's starting item (with the
-- quest's side, "Alliance", "Horde" or true), plus any item whose tooltip
-- says "This Item Begins a Quest" once it is cached.
local Starters = { tooltip = {} }

function Starters:Side(itemID)
    if not self.data then
        self.data = {}
        for _, quests in pairs(ns.Data.quests) do
            for _, quest in ipairs(quests) do
                if quest.startsFromId then self.data[quest.startsFromId] = quest.side or true end
            end
        end
        for questItemID, quest in pairs(ns.Data.questItems) do
            local side = self.data[questItemID]
            if side == nil or side == true then self.data[questItemID] = quest.side or true end
        end
    end
    return self.data[itemID]
end

function Starters:Known(itemID)
    if self:Side(itemID) then return true end
    local seen = self.tooltip[itemID]
    if seen ~= nil then return seen end
    local lines = ns.Items.TooltipLines(itemID)
    if not lines then return false end -- asked again once it is cached
    seen = false
    for _, line in ipairs(lines) do
        if line.leftText == ITEM_STARTS_QUEST then seen = true end
    end
    self.tooltip[itemID] = seen
    return seen
end

-- Type and slot ("Cloth  ·  Back", "Mace  ·  Two-Hand", "Finger", "Quest",
-- "Begins Quest"), from instant (uncached) info.
local function SlotText(itemID)
    if Starters:Known(itemID) then return L["Begins Quest"] end
    local _, itemType, subType, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    -- Non-equippable items have a slot token whose name is "" (INVTYPE_NON_EQUIP_IGNORE).
    local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
    if slot == "" then slot = nil end
    local isGenericArmor = classID == Enum.ItemClass.Armor and subClassID == Enum.ItemArmorSubclass.Generic
    if slot and subType and not isGenericArmor then
        return Theme:JoinDots(subType, slot)
    end
    return slot or subType or itemType or ""
end

-- A loot list in sections: Quest Items, Weapons (one-hand, two-hand,
-- ranged, then shields and off-hands; swords, daggers, axes, maces, staves,
-- and bows, crossbows, guns, wands), Armor (cloth, leather, mail, plate,
-- cloaks; head to wrist within each), Accessories (necks, rings, relics,
-- trinkets), Professions (every recipe item: plans, patterns, formulas,
-- schematics, manuals, books; grouped by the profession they teach), then
-- Consumables and last Miscellaneous. Item class and slot are instant info,
-- so nothing waits on the item cache. Ties keep the scraped order. Each
-- section has its name as shown and the key its open or shut state is
-- remembered by (ns.SectionMemory's "loot" area; never the name, which
-- changes with the client's language). `startsShut`: shut until the player
-- opens it (a boss's recipes interest only its profession's crafters).
-- A Factions list, whose quartermaster may sell hundreds of recipes, splits
-- Professions into one section per profession instead (ProfessionSection).
local SECTIONS = {
    { key = "QUEST_ITEMS", name = L["Quest Items"] },
    { key = "WEAPONS", name = L["Weapons"] },
    { key = "ARMOR", name = L["Armor"] },
    { key = "ACCESSORIES", name = L["Accessories"] },
    { key = "PROFESSIONS", name = L["Professions"], startsShut = true },
    { key = "CONSUMABLES", name = L["Consumables"] },
    { key = "MISCELLANEOUS", name = L["Miscellaneous"] },
}
-- Each section's place in SECTIONS by its key (SECTION_INDEX.ARMOR is 3),
-- so the sort below names sections instead of counting them.
local SECTION_INDEX = {}
for index, section in ipairs(SECTIONS) do SECTION_INDEX[section.key] = index end

-- A Factions list's section for one profession is keyed by its recipe
-- subclass ("PROFESSION_8", Enchanting), never its name, which changes with
-- the client's language.
local PROFESSION_SECTION_PREFIX = "PROFESSION_"

-- Whether loot section `sectionKey` is shut until the player opens it. Each
-- profession's own section starts shut, as Professions does.
local function SectionStartsShut(sectionKey)
    if sectionKey:find(PROFESSION_SECTION_PREFIX, 1, true) == 1 then return true end
    local section = SECTIONS[SECTION_INDEX[sectionKey]]
    return section ~= nil and section.startsShut == true
end

-- Whether loot section `sectionKey` is shut. `shutSections` (the "loot"
-- area) holds true (shut) or false (open) only where the player left a
-- section unlike how it starts; nil means as it starts.
local function IsSectionShut(shutSections, sectionKey)
    local shut = shutSections[sectionKey]
    if type(shut) == "boolean" then return shut end
    return SectionStartsShut(sectionKey)
end

-- Opens or shuts loot section `sectionKey` in `shutSections`, keeping only a
-- difference from how it starts. Unlike ns.SectionMemory.Toggle it keeps
-- "shut", not "open": the "loot" area held true for a shut section before
-- any section started shut, and players' saved states keep that meaning. A
-- section put back to how it starts is forgotten, so it follows its
-- startsShut in SECTIONS if that changes.
local function SetSectionShut(shutSections, sectionKey, shut)
    if shut == SectionStartsShut(sectionKey) then
        shutSections[sectionKey] = nil
    else
        shutSections[sectionKey] = shut
    end
end

local WEAPON_GROUP = {
    INVTYPE_WEAPON = 1, INVTYPE_WEAPONMAINHAND = 1, INVTYPE_WEAPONOFFHAND = 1,
    INVTYPE_2HWEAPON = 2,
    INVTYPE_RANGED = 3, INVTYPE_RANGEDRIGHT = 3, INVTYPE_THROWN = 3,
    INVTYPE_SHIELD = 4, INVTYPE_HOLDABLE = 4,
}
-- Weapon subclasses: swords, daggers, axes, maces, staves, then fist
-- weapons and polearms; bows, crossbows, guns, wands, thrown.
local WEAPON_ORDER = { [7] = 1, [8] = 1, [15] = 2, [0] = 3, [1] = 3, [4] = 4, [5] = 4, [10] = 5,
    [13] = 6, [6] = 7, [2] = 1, [18] = 2, [3] = 3, [19] = 4, [16] = 5 }
local ARMOR_SLOT = { INVTYPE_HEAD = 1, INVTYPE_SHOULDER = 2, INVTYPE_CHEST = 3, INVTYPE_ROBE = 3,
    INVTYPE_LEGS = 4, INVTYPE_HAND = 5, INVTYPE_FEET = 6, INVTYPE_WAIST = 7, INVTYPE_WRIST = 8 }
local ACCESSORY = { INVTYPE_NECK = 1, INVTYPE_FINGER = 2, INVTYPE_RELIC = 3, INVTYPE_TRINKET = 4 }

-- Section and sort keys for one item: { section, group, order, slot }.
local function LootKey(itemID)
    if Starters:Known(itemID) then return SECTION_INDEX.QUEST_ITEMS, 0, 0, 0 end
    local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if classID == Enum.ItemClass.Questitem then return SECTION_INDEX.QUEST_ITEMS, 1, 0, 0 end
    if ACCESSORY[equipLoc] then return SECTION_INDEX.ACCESSORIES, ACCESSORY[equipLoc], 0, 0 end
    if WEAPON_GROUP[equipLoc] then
        local order = classID == Enum.ItemClass.Weapon and WEAPON_ORDER[subClassID] or 9
        return SECTION_INDEX.WEAPONS, WEAPON_GROUP[equipLoc], order, 0
    end
    if equipLoc == "INVTYPE_CLOAK" then return SECTION_INDEX.ARMOR, 5, 0, 0 end
    if classID == Enum.ItemClass.Armor and subClassID >= 1 and subClassID <= 4 and ARMOR_SLOT[equipLoc] then
        return SECTION_INDEX.ARMOR, subClassID, ARMOR_SLOT[equipLoc], 0
    end
    -- A recipe's subclass is the profession it teaches (Enum.ItemRecipeSubclass:
    -- Leatherworking, Tailoring, Engineering, Blacksmithing...), so one
    -- profession's recipes sit together.
    if classID == Enum.ItemClass.Recipe then return SECTION_INDEX.PROFESSIONS, subClassID, 0, 0 end
    if classID == Enum.ItemClass.Consumable then return SECTION_INDEX.CONSUMABLES, 0, 0, 0 end
    return SECTION_INDEX.MISCELLANEOUS, 0, 0, 0
end

-- One row per item name: copies with the same name (Head of Onyxia is one
-- item for each side) keep the copy whose quest is the player's side, else
-- the first. Returns the items and whether some names weren't cached yet
-- (those items stay in, as do spells and other entries with no item).
local function Deduped(items)
    local side = ns.PlayerFaction()
    local keep, waiting = {}, false
    for _, entry in ipairs(items) do
        local name = entry.itemID and C_Item.GetItemNameByID(entry.itemID)
        if name then
            local kept = keep[name]
            if not kept or (Starters:Side(kept.itemID) ~= side and Starters:Side(entry.itemID) == side) then
                keep[name] = entry
            end
        elseif entry.itemID then
            waiting = true
        end
    end
    local out = {}
    for _, entry in ipairs(items) do
        local name = entry.itemID and C_Item.GetItemNameByID(entry.itemID)
        if not name or keep[name] == entry then table.insert(out, entry) end
    end
    return out, waiting
end

-- The recipe subclass (the profession, Enum.ItemRecipeSubclass) an entry
-- keyed `key` by LootKey belongs with: a recipe's own, or the profession a
-- reward that teaches nothing names (forProfession, a "<Profession>
-- Certification"). Nil for an entry that is no profession's.
local function ProfessionSubclass(entry, key)
    if entry.forProfession then return Enum.ItemRecipeSubclass[entry.forProfession] end
    if key[1] == SECTION_INDEX.PROFESSIONS then return key[2] end
    return nil
end

-- One profession's section on a Factions list: its key and the game's own
-- name for its recipes' subclass ("Enchanting", in the client's language).
local function ProfessionSection(subClassID)
    local name = C_Item.GetItemSubClassInfo(Enum.ItemClass.Recipe, subClassID)
    return { key = PROFESSION_SECTION_PREFIX .. subClassID, name = name or L["Professions"] }
end

-- Every item's sort key { section, group, order, place in the list } and the
-- section it is listed under. `byProfession`: each profession's items go in a
-- section of their own, sorted by its name and kept in the list's order
-- within it (a faction's are lowest skill first).
local function SectionKeys(items, byProfession)
    local keyed = {}
    for i, entry in ipairs(items) do
        local key = entry.itemID and { LootKey(entry.itemID) } or { SECTION_INDEX.MISCELLANEOUS, 0, 0, 0 }
        key[4] = i
        local section = SECTIONS[key[1]]
        local subClassID = byProfession and ProfessionSubclass(entry, key)
        if subClassID then
            section = ProfessionSection(subClassID)
            -- The subclass keeps two professions apart should the game name them alike.
            key[1], key[2], key[3] = SECTION_INDEX.PROFESSIONS, section.name, subClassID
        end
        keyed[i] = { entry = entry, key = key, section = section }
    end
    return keyed
end

local function Sectioned(items, byProfession)
    local keyed = SectionKeys(items, byProfession)
    table.sort(keyed, function(a, b)
        for keyIndex = 1, 4 do
            if a.key[keyIndex] ~= b.key[keyIndex] then return a.key[keyIndex] < b.key[keyIndex] end
        end
        return false
    end)
    local out, sectionKey = {}, nil
    for _, item in ipairs(keyed) do
        if item.section.key ~= sectionKey then
            sectionKey = item.section.key
            table.insert(out, { header = item.section.name, sectionKey = sectionKey,
                box = true, full = true, shuts = true })
        end
        table.insert(out, item.entry)
    end
    return out
end

-- An encounter's entries with each boss's items (each fold's, when it has
-- folds) put in sections, one row per item name. Some names may not be
-- cached yet: then those items are loaded, the list is redone in place once
-- they stop arriving, and onChange() is called (one redraw per burst, not one
-- per item).
-- `keepAll` (vendor lists) keeps same-named items: each level of a
-- multi-level item is listed. `byProfession` (Factions lists) gives each
-- profession a section of its own in place of one Professions section.
function ns.UI.LootSections(entries, onChange, out, keepAll, byProfession)
    out = out or {}
    for i = #out, 1, -1 do out[i] = nil end
    -- `foldItems`: the entries since the last fold (or the start).
    local foldItems, waiting, fold = {}, false, nil
    local function AddFoldItems()
        local items, namesMissing = foldItems, false
        if not keepAll then items, namesMissing = Deduped(foldItems) end
        waiting = waiting or namesMissing
        if fold then fold.count = #items end
        for _, entry in ipairs(Sectioned(items, byProfession)) do table.insert(out, entry) end
        foldItems = {}
    end
    for _, entry in ipairs(entries) do
        if entry.fold then
            AddFoldItems()
            fold = entry
            table.insert(out, entry)
        else
            table.insert(foldItems, entry)
        end
    end
    AddFoldItems()
    if waiting and onChange then
        -- Items arrive in a burst; redo the list once it settles. An item
        -- that never loads (not in this client) can't hold the others up.
        local queued = false
        local function Loaded()
            if queued then return end
            queued = true
            C_Timer.After(0.2, function()
                queued = false
                ns.UI.LootSections(entries, nil, out, keepAll, byProfession)
                onChange()
            end)
        end
        for _, entry in ipairs(entries) do
            if entry.itemID and not C_Item.GetItemNameByID(entry.itemID) then ns.Items:Load(entry.itemID, Loaded) end
        end
    end
    return out
end

-- The tick after an item's name: a texture of its own, so it can be
-- greyed out properly, sized against the name's font.
local TICK_SCALE = 1.2
local TICK_GAP = 3

-- A text's words, split at spaces the way the game wraps a name.
local function SplitWords(text)
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    return words
end

-- "Requires Level 24", or nil for items anyone can use. Needs cached info.
local function LevelText(itemID)
    local minLevel = select(5, C_Item.GetItemInfo(itemID))
    if minLevel and minLevel > 1 then
        return ITEM_MIN_LEVEL and ITEM_MIN_LEVEL:format(minLevel) or L["Requires Level %d"]:format(minLevel)
    end
end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"

-- Compact price for the cell ("155g"; "45s" under a gold).
local function ShortCost(copper)
    if copper >= 10000 then
        return BreakUpLargeNumbers(math.floor(copper / 10000)) .. GOLD_ICON
    end
    return math.floor(copper / 100) .. SILVER_ICON
end

-- A price paid in a currency (costCurrency, costCurrencyCount: Honor,
-- Merchant's Favor) and in another item (costItem, costCount: a
-- reputation's tokens, a battleground's marks), as a list of parts, the
-- currency's first: each the count and the game's icon for what it is paid
-- in ("9,000" and Honor's icon, "15" and a mark's). Numbers and the game's
-- own icons read the same in every locale. `withNames`: each part followed
-- by the game's name for it, once the client has it (an item's is asked for
-- here, so the next hover shows it). Empty for a price in gold or none.
local function TokenCosts(entry, withNames)
    local parts = {}
    local function Add(count, icon, name)
        local part = BreakUpLargeNumbers(count) .. (icon and ("|T" .. icon .. ":0:0:2:0|t") or "")
        table.insert(parts, withNames and name and (part .. " " .. name) or part)
    end
    if entry.costCurrency then
        local currency = C_CurrencyInfo.GetCurrencyInfo(entry.costCurrency)
        local name = currency and currency.name ~= "" and currency.name or nil
        Add(entry.costCurrencyCount, currency and currency.iconFileID, name)
    end
    if entry.costItem then
        local name = withNames and C_Item.GetItemNameByID(entry.costItem)
        if withNames and not name then C_Item.RequestLoadItemDataByID(entry.costItem) end
        Add(entry.costCount, C_Item.GetItemIconByID(entry.costItem), name)
    end
    return parts
end

-- The cell's price ("9,000" and Honor's icon, then "15" and a mark's; else
-- gold), or nil for an item nobody sells.
local function PriceText(entry)
    local parts = TokenCosts(entry, false)
    if parts[1] then return table.concat(parts, " ") end
    return entry.cost and ShortCost(entry.cost)
end

-- The tooltip's price: the cell's, with the names of the currency and the
-- item it is paid in ("9,000 Honor  ·  15 Warsong Gulch Mark of Honor").
local function TooltipPrice(entry)
    local parts = TokenCosts(entry, true)
    if parts[1] then return Theme:JoinDots(unpack(parts)) end
    return PriceText(entry)
end

-- Where a search result leads, as a breadcrumb: tab, list, encounter (none
-- for a dungeon found by search).
local function SourcePath(instance, encounter)
    local tab = ns.UI.tabLabels[instance.category]
    return (tab and (tab .. "  >  ") or "") .. ns.Data:PlaceName(instance)
        .. (encounter and ("  >  " .. encounter.name) or "")
end

-- Where a boss, dungeon, quest or Library book found by search leads: a
-- book's tab and the zone it is listed in ("Library  >  Westfall"), else
-- SourcePath (a dungeon's without an encounter).
local function ResultPath(entry)
    if entry.book then
        return ns.UI.tabLabels.LIBRARY_BOOKS .. "  >  " .. ns.UI.PetPageKit.ZoneName(entry.book.spots[1].map)
    end
    return SourcePath(entry.inst, entry.kind ~= "place" and entry.enc or nil)
end

-- A search result's sources under its tooltip: up to five, then how many
-- more, and where a click goes.
local MAX_TOOLTIP_SOURCES = 5

local function AddSearchLines(entry)
    local sources = entry.sources
    GameTooltip:AddLine(" ")
    for i, src in ipairs(sources) do
        if i > MAX_TOOLTIP_SOURCES then
            GameTooltip:AddLine(L["and %d more"]:format(#sources - MAX_TOOLTIP_SOURCES), unpack(Theme.tip.hint))
            break
        end
        AddTipPair(src.name, ns.Data:PlaceName(src.inst), Theme.tip.title, Theme.tip.info)
    end
    GameTooltip:AddLine(L["Click to open %s"]:format(sources[1].name), unpack(Theme.tip.hint))
end

-- A boss, dungeon, quest or Library book found by search: its name, where
-- it is, and the click.
local function ShowPlaceTooltip(entry)
    GameTooltip:AddLine(entry.name, unpack(Theme.tip.title))
    if entry.enc and entry.enc.name ~= entry.name then
        GameTooltip:AddLine(entry.enc.name, unpack(Theme.tip.text))
    end
    GameTooltip:AddLine(ResultPath(entry), unpack(Theme.tip.info))
    local click = entry.kind == "place" and L["Click to open its overview"]
        or entry.kind == "quest" and L["Click to open this quest"]
        or entry.kind == "book" and L["Click to open it in the Library"] or L["Click to open its loot"]
    GameTooltip:AddLine(click, unpack(Theme.tip.hint))
    GameTooltip:Show()
end

-- A quest item's turn-in rewards under its tooltip (Head of Onyxia: the
-- three rings and necks to choose from), each with its icon and quality
-- color. Rewards not cached yet show the tooltip again once they load.
local ShowTooltip -- a cell's tooltip, below
local function AddTurnIn(cell, itemID)
    local quest = ns.Data.questItems[itemID]
    if not quest then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Turn in: %s"]:format(quest.name), unpack(Theme.tip.title))
    local function ShowAgain()
        if GameTooltip:IsOwned(cell) and cell.entry and cell.entry.itemID == itemID then ShowTooltip(cell) end
    end
    local lists = {
        { items = quest.choice, heading = L["Choose one of:"] },
        { items = quest.rewards, heading = L["You will receive:"] },
    }
    for _, list in ipairs(lists) do
        if list.items then GameTooltip:AddLine(list.heading, unpack(Theme.tip.info)) end
        for _, rewardID in ipairs(list.items or {}) do
            local name = C_Item.GetItemNameByID(rewardID)
            if not name and not C_Item.IsItemDataCachedByID(rewardID) then ns.Items:Load(rewardID, ShowAgain) end
            local r, g, b = Theme:QualityColor(ns.Items:Quality(rewardID))
            local icon = C_Item.GetItemIconByID(rewardID)
            GameTooltip:AddLine(("|T%s:16:16:0:0|t %s"):format(icon or QUESTION_ICON, name or L["Loading..."]), r, g, b)
        end
    end
end

-- Each profession list's skill line ID, which is the same in every language.
-- They match catalog.py's PROFESSIONS skill_line (a scraper test checks);
-- SKINNING is the list Data/Data.lua builds by hand, so it is only here.
local SKILL_LINE_IDS = {
    ALCHEMY = 171, BLACKSMITHING = 164, COOKING = 185, ENCHANTING = 333, ENGINEERING = 202, FIRST_AID = 129,
    FISHING = 356, HERBALISM = 182, LEATHERWORKING = 165, MINING = 186, SKINNING = 393, TAILORING = 197,
}

-- A profession list's skill line ID, or nil for a list with none (Camping).
local function SkillLineID(profession)
    return SKILL_LINE_IDS[profession.id] or profession.skillLine
end

-- The character's rank in a profession list (or a class's own recipes,
-- which name their skill line: the rogue's Poisons) and the most it can
-- reach before the next rank is learned, or nil when they haven't learned
-- it. GetSkillLineInfoByID's table is nilable, and a skill line can list at
-- rank 0: either way the character hasn't learned the profession.
local function SkillRanks(profession)
    local skillLineID = SkillLineID(profession)
    local skillLine = skillLineID and C_SkillInfo.GetSkillLineInfoByID(skillLineID)
    if skillLine and skillLine.rank > 0 then return skillLine.rank, skillLine.maxRank end
end
ns.UI.SkillRanks = SkillRanks  -- the Professions Overview's heading and boxes, the profession bar

-- Whether a character learns `profession` as a skill at all: false for the
-- Camping list, which has no skill line, so it is never "Not learned".
function ns.UI.HasSkillLine(profession)
    return SkillLineID(profession) ~= nil
end

-- The character's rank in a profession list, or nil (SkillRanks).
local function SkillRank(profession)
    return (SkillRanks(profession))
end
ns.UI.SkillRank = SkillRank  -- the recipe list's toggles (UI/RecipeBand.lua)

-- The game's difficulty colour for the character's `rank` against
-- `levels` = { learnable at, yellow from, green from, grey from }: red
-- below the first, then orange, yellow, green and grey.
local LEVEL_COLORS = { "levelImpossible", "levelHard", "levelFair", "levelEasy" }
local function SkillLevelColor(rank, levels)
    for i, colorName in ipairs(LEVEL_COLORS) do
        if rank < levels[i] then return Theme.color[colorName] end
    end
    return Theme.color.levelTrivial
end
ns.UI.SkillLevelColor = SkillLevelColor  -- the recipe list's skill numbers (UI/RecipeBand.lua)

-- A gathering source's skill colored as the game colors a node: red while
-- out of reach, then orange, yellow, green and grey from the node's own
-- `levels` ({ skill, yellow from, green from, grey from }, the Professions
-- Overview's nodes) or, for a caller that only knows the skill (a Scarce
-- reagent's source), the usual steps: 25, 50 and 100 past it. Plain text
-- when the character hasn't the profession.
local function GatherColor(skill, rank, levels)
    if not (skill and rank) then return Theme.color.text end
    return SkillLevelColor(rank, levels or { skill, skill + 25, skill + 50, skill + 100 })
end
ns.UI.GatherColor = GatherColor  -- the Professions Overview's nodes (UI/ProfessionOverview.lua)

-- "2.1%", "0.11%", "0.004%": two figures, so rare sources tell apart.
local function GatherRate(rate)
    local pct = rate * 100
    if pct >= 10 then return ("%.0f%%"):format(pct) end
    if pct >= 1 then return (("%.1f"):format(pct):gsub("%.0$", "")) .. "%" end
    if pct >= 0.01 then return ("%.2f%%"):format(pct) end
    return ("%.3f%%"):format(pct)
end

-- 12345 -> "12,345", with English commas in every language.
local function Thousands(n)
    local text = tostring(n)
    while true do
        local added
        text, added = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
        if added == 0 then return text end
    end
end

-- A Scarce reagent source's texts: its name, "Requires Mining 65" (colored
-- against your skill), the chance and "N samples".
local function GatherTexts(entry)
    local src, prof = entry.gather, entry.profession
    local requirement = ""
    if src.skill then
        local color = Theme:ColorCode(GatherColor(src.skill, SkillRank(prof)))
        requirement = L["Requires %s %s"]:format(prof.name, ("%s%d|r"):format(color, src.skill))
    end
    local samples = src.samples
        and (src.samples == 1 and L["1 sample"] or L["%s samples"]:format(Thousands(src.samples))) or ""
    return src.name, requirement, src.rate and GatherRate(src.rate) or "", samples
end

-- What a gathering node yields, for its icon: node name = item ID. Herb
-- nodes are named after their herb.
local NODE_ITEMS = {
    ["Copper Vein"] = 2770, ["Tin Vein"] = 2771, ["Silver Vein"] = 2775, ["Iron Deposit"] = 2772,
    ["Gold Vein"] = 2776, ["Mithril Deposit"] = 3858, ["Truesilver Deposit"] = 7911,
    ["Small Thorium Vein"] = 10620, ["Rich Thorium Vein"] = 10620, ["Hakkari Thorium Vein"] = 10620,
    ["Dark Iron Deposit"] = 11370, ["Incendicite Mineral Vein"] = 3340, ["Lesser Bloodstone Deposit"] = 4278,
    ["Indurium Mineral Vein"] = 5833, ["Small Obsidian Chunk"] = 22202, ["Large Obsidian Chunk"] = 22203,
    ["Ooze Covered Silver Vein"] = 2775, ["Ooze Covered Gold Vein"] = 2776,
    ["Ooze Covered Mithril Deposit"] = 3858, ["Ooze Covered Truesilver Deposit"] = 7911,
    ["Ooze Covered Thorium Vein"] = 10620, ["Ooze Covered Rich Thorium Vein"] = 10620,
    -- Mike's picks for nodes with no ore of their own.
    ["Chunk of Amber"] = 275842, ["Large Chunk of Amber"] = 275842, -- Fossilized Insect
    Peacebloom = 2447, Silverleaf = 765, Earthroot = 2449, Mageroyal = 785, Briarthorn = 2450,
    Stranglekelp = 3820, Bruiseweed = 2453, ["Wild Steelbloom"] = 3355, ["Grave Moss"] = 3369,
    Kingsblood = 3356, Liferoot = 3357, Fadeleaf = 3818, Goldthorn = 3821, ["Khadgar's Whisker"] = 3358,
    Wintersbite = 3819, Firebloom = 4625, ["Purple Lotus"] = 8831, ["Arthas' Tears"] = 8836,
    Sungrass = 8838, Blindweed = 8839, ["Ghost Mushroom"] = 8845, Gromsblood = 8846,
    ["Golden Sansam"] = 13464, Dreamfoil = 13463, ["Mountain Silversage"] = 13465,
    Plaguebloom = 13466, Icecap = 13467, ["Black Lotus"] = 13468,
}

-- A gathering source's icon, round in the headers' disc ring.
local NODE_RING = "Mode-Selection-Ring-c60"
local NODE_ICON = 34
local NODE_RING_SIZE = 42
-- A cell's text: inset from its left, the gap before the chance or price,
-- and the room on the right (more beside a search result's go button).
local TEXT_LEFT, TEXT_GAP, TEXT_RIGHT, GO_ROOM = 54, 8, 10, 40

local function ShowGatherTooltip(entry)
    local src, prof = entry.gather, entry.profession
    GameTooltip:SetText(src.name)
    if src.skill then
        local r, g, b = unpack(GatherColor(src.skill, SkillRank(prof)))
        GameTooltip:AddLine(L["Requires %s (%d)"]:format(prof.name, src.skill), r, g, b)
    end
    if src.rate then
        GameTooltip:AddLine(" ")
        AddTipPair(L["Chance per gather"], GatherRate(src.rate), Theme.tip.info, Theme.tip.text)
        AddTipPair(L["Gathers sampled"], Thousands(src.samples), Theme.tip.info, Theme.tip.text)
        if src.rate > 0 then
            local oneIn = Thousands(math.floor(1 / src.rate + 0.5))
            AddTipPair(L["About"], L["1 in %s"]:format(oneIn), Theme.tip.info, Theme.tip.text)
        end
    end
    GameTooltip:Show()
end

function ShowTooltip(cell)
    local entry = cell.entry
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT", 4, 0)
    if entry.gather then
        ShowGatherTooltip(entry)
        return
    end
    if entry.kind then
        ShowPlaceTooltip(entry)
        return
    end
    if entry.spellID or entry.ability then
        GameTooltip:SetSpellByID(entry.spellID or entry.ability)
        GameTooltip:Show()
        return
    end
    GameTooltip:SetItemByID(entry.itemID)
    AddTurnIn(cell, entry.itemID)
    if entry.dropRate and ns.SHOW_DROP_RATES then
        GameTooltip:AddLine(" ")
        AddTipPair(L["Drop chance"], ("%.0f%%"):format(entry.dropRate * 100), Theme.tip.info, Theme.tip.good)
    end
    local price = TooltipPrice(entry)
    if price then
        GameTooltip:AddLine(" ")
        AddTipPair(L["Vendor price"], price, Theme.tip.info, Theme.tip.text)
    end
    if entry.sources and cell.searchRow then AddSearchLines(entry) end
    GameTooltip:Show()
    if IsModifiedClick("COMPAREITEMS") then GameTooltip_ShowCompareItem(GameTooltip) end
end

local function ItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if not name then C_Item.RequestLoadItemDataByID(itemID) end
    return name or L["Item %d"]:format(itemID)
end

-- Tooltip for a material's jump arrow: the recipe that makes it and its
-- materials, each with the total needed for this recipe's count.
local function ShowRecipeTooltip(arrow)
    local material = arrow:GetParent().entry
    local instance, encounter = material.craft[1], material.craft[2]
    GameTooltip:SetOwner(arrow, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:AddLine(encounter.name, unpack(Theme.tip.title))
    local skill = encounter.skill and ("  %d"):format(encounter.skill[1]) or ""
    GameTooltip:AddLine(instance.name .. skill, unpack(Theme.tip.info))
    local per = encounter.loot[1].count or 1
    local crafts = math.ceil((material.count or 1) / per)
    if per > 1 then
        local r, g, b = unpack(Theme.tip.info)
        GameTooltip:AddLine(L["Makes %d each, %d crafts for %d"]:format(per, crafts, material.count or 1),
            r, g, b, true)
    end
    GameTooltip:AddLine(" ")
    for _, reagent in ipairs(encounter.reagents or {}) do
        local reagentText = ("%dx %s"):format(reagent.count, ItemName(reagent.itemID))
        AddTipPair(reagentText, L["%dx total"]:format(reagent.count * crafts), Theme.tip.text, { 0.23, 0.53, 0.36 })
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Click to open this recipe"], unpack(Theme.tip.hint))
    GameTooltip:Show()
end

-- "Go to" arrow pointing up and right, a shaft and a two-stroke head drawn
-- on `frame` at `scale` (1 fits a 15px badge). Returns a function that
-- recolors it.
local function DrawGoArrow(frame, scale, color)
    local strokes = {}
    for i, spec in ipairs({ { 8, 45, 0, 0 }, { 4, 0, 1.5, 3 }, { 4, 90, 3, 1.5 } }) do
        local line = frame:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 1)
        line:SetSize(spec[1] * scale, 1.5)
        line:SetPoint("CENTER", spec[3] * scale, spec[4] * scale)
        line:SetRotation(math.rad(spec[2]))
        strokes[i] = line
    end
    local function Tint(c)
        for _, line in ipairs(strokes) do line:SetVertexColor(unpack(c)) end
    end
    Tint(color)
    return Tint
end

-- The wishlist star at a gear item's right edge (left of the chance or
-- price): a click puts the item on the current wishlist or takes it off.
local STAR_SIZE, STAR_ROOM = 16, 22

local function ShowStarTooltip(star)
    GameTooltip:SetOwner(star, "ANCHOR_RIGHT", 4, 0)
    local heading, hint
    if star.on then
        heading, hint = L["On your wishlist"], L["Click to take it off"]
    else
        heading, hint = L["Add to wishlist"], L["Starred items show on the Wishlist tab"]
    end
    GameTooltip:AddLine(heading, unpack(Theme.tip.title))
    GameTooltip:AddLine(ns.Wishlist:Current().name, unpack(Theme.tip.info))
    GameTooltip:AddLine(hint, unpack(Theme.tip.hint))
    GameTooltip:Show()
end

local function CreateStar(cell)
    local star = Theme:Star(cell, STAR_SIZE)
    star:SetPoint("RIGHT", -10, 0)
    star:SetScript("OnEnter", function(self)
        self:Paint()
        if not cell.isSelected then cell.hover:Show() end -- still over the row
        ShowStarTooltip(self)
    end)
    star:SetScript("OnLeave", function(self)
        self:Paint()
        cell.hover:Hide()
        GameTooltip:Hide()
    end)
    star:SetScript("OnClick", function(self)
        self:SetOn(ns.Wishlist:Toggle(cell.entry.itemID))
        ShowStarTooltip(self)
    end)
    cell:HookScript("OnEnter", function() star:SetLit(true) end)
    cell:HookScript("OnLeave", function() star:SetLit(false) end)
    star:Hide()
    return star
end

-- Button at the right end of a search result: hover names the page it
-- leads to, click opens it (an item highlighted on its first source's page).
-- The whole row does the same; the button shows that it can.
local function CreateGoButton(cell)
    local btn = CreateFrame("Button", nil, cell)
    btn:SetSize(22, 22)
    btn:SetPoint("RIGHT", -8, 0)
    btn:SetFrameLevel(cell:GetFrameLevel() + 2)
    -- A quiet outline at rest that fills on hover, so it reads as a button.
    Theme:Rounded(btn, Theme.color.hover, Theme.native and Theme.color.line or Theme.color.edge)
    btn.bg:Hide()
    local Tint = DrawGoArrow(btn, 1.25, Theme.color.muted)
    btn:SetScript("OnEnter", function(self)
        self.bg:Show()
        Tint(Theme.color.heading)
        local entry = cell.entry
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
        GameTooltip:AddLine(L["Go to source"], unpack(Theme.tip.title))
        GameTooltip:AddLine(ResultPath(entry), unpack(Theme.tip.info))
        GameTooltip:AddLine(L["Click to open this page"], unpack(Theme.tip.hint))
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self.bg:Hide()
        Tint(Theme.color.muted)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function()
        GameTooltip:Hide()
        ns.UI:GoToResult(cell.entry)
    end)
    btn:Hide()
    return btn
end

-- Small badge on a material's icon corner, shown when the material is
-- itself crafted: hover for its recipe, click to go there.
local function CreateJumpArrow(cell)
    local arrow = CreateFrame("Button", nil, cell)
    arrow:SetSize(15, 15)
    arrow:SetPoint("TOPLEFT", cell.iconBorder, "TOPLEFT", -5, 5)
    arrow:SetFrameLevel(cell:GetFrameLevel() + 2)
    Theme:Fill(arrow, Theme.color.bg)
    Theme:Border(arrow, Theme.color.accent)
    local Tint = DrawGoArrow(arrow, 1, Theme.color.accent)
    arrow:SetScript("OnEnter", function(self)
        Tint(Theme.color.heading)
        ShowRecipeTooltip(self)
    end)
    arrow:SetScript("OnLeave", function()
        Tint(Theme.color.accent)
        GameTooltip:Hide()
    end)
    arrow:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        local craft = self:GetParent().entry.craft
        ns.UI:SelectRecipe(craft[1], craft[2])
    end)
    arrow:Hide()
    return arrow
end

-- A recipe source's drop rate, "1.5%", "0.07%": enough to tell rare drops apart.
local function SourceDropRate(rate)
    local pct = rate * 100
    if pct >= 10 then return ("%.0f%%"):format(pct) end
    if pct >= 0.1 then return ("%.1f%%"):format(pct) end
    return ("%.2f%%"):format(pct)
end

-- Where a source stands: the dungeon it is in, else its map's zone.
local function SourceZone(src)
    local dungeon = src.inside and ns.Data:Get(src.inside)
    if dungeon then return dungeon.name end
    local spot = src.spot or src.npc and ns.Data.npcs[src.npc]
    local map = spot and spot.map or src.zone -- zone: a mob with no map spot (Data/RecipeDrops.lua)
    if type(map) == "number" then
        local info = C_Map.GetMapInfo(map)
        return info and info.name
    end
    return spot and spot.map
end
ns.UI.SourceZone = SourceZone  -- the Classes tab's Overview names its trainers' zones too

-- The spot a source's line pins: the NPC, or the door of the dungeon it is
-- in. Then the name NeedRoll's own pin there shows: the NPC's or the dungeon's.
local function SourceSpot(src)
    if src.spot then return src.spot, src.name end
    if src.npc then return ns.Data.npcs[src.npc], src.name end
    if not src.inside then return nil end
    local dungeon = ns.Data:Get(src.inside)
    return ns.Data:Entrance(src.inside), dungeon and dungeon.name
end

-- Trainers ---------------------------------------------------------------------

-- Each recipe's trainers this character can learn from: their side's and
-- those who serve both (Data/RecipeTrainers.lua). Built once per recipe and
-- side (dev builds can view NeedRoll as the other side: ns.PlayerFaction).
local trainersOf = {} -- side -> spell ID -> trainers
local function RecipeTrainers(spellID)
    local mine = ns.PlayerFaction()
    trainersOf[mine] = trainersOf[mine] or {}
    local sideTrainers = trainersOf[mine]
    if sideTrainers[spellID] then return sideTrainers[spellID] end
    local data = ns.Data.recipeTrainers
    local mayLearnFrom = {}
    for _, npc in ipairs(data.recipes[spellID] or {}) do
        local trainer = data.trainers[npc]
        if trainer and (not trainer.side or trainer.side == mine) then table.insert(mayLearnFrom, trainer) end
    end
    sideTrainers[spellID] = mayLearnFrom
    return mayLearnFrom
end
ns.UI.RecipeTrainers = RecipeTrainers  -- the recipe page's Learned from box (UI/MainFrame.lua)

-- Where `position` (0 to 1 across the map) on map `map` is in the world:
-- the continent and world x and y, as the trainers' spots have them. Nil
-- wherever the map can't say; the call can fail and the values come back
-- secret in places (ns.Plain).
local function WorldPosition(map, position)
    if not (map and position) then return nil end
    local Plain = ns.Plain
    local ok, continent, x, y = pcall(function()
        local continentID, world = C_Map.GetWorldPosFromMapPos(map, position)
        if not world then return nil end
        return continentID, world:GetXY()
    end)
    if not ok then return nil end
    continent, x, y = Plain(continent), Plain(x), Plain(y)
    if not (continent and x and y) then return nil end
    return continent, x, y
end

-- A map spot (ns.Data.npcs' shape: map, x, y from 0 to 1) with its place in
-- the world, as NearestFirst sorts by: as it is when the data gives that
-- place, else worked out from the map; nil without a spot or where the map
-- can't say. A hunter's beasts (UI/HunterPets.lua) and the class quests'
-- givers (UI/Lists.lua) sort by it.
local function SpotInWorld(spot)
    if not spot then return nil end
    if spot.continent then return spot end
    if not (spot.x and spot.y) then return nil end
    local continent, worldX, worldY = WorldPosition(spot.map, CreateVector2D(spot.x, spot.y))
    if not continent then return nil end
    return { continent = continent, worldX = worldX, worldY = worldY }
end
ns.UI.SpotInWorld = SpotInWorld

-- Where the player stands in the world (WorldPosition); nil in a dungeon.
local function PlayerWorldPosition()
    local map = ns.Plain(C_Map.GetBestMapForUnit("player"))
    if not map then return nil end
    local ok, position = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not ok then return nil end
    return WorldPosition(map, position)
end

-- A trainer's map spot (Data/RecipeTrainers.lua, Data/HunterPets.lua ...)
-- with its place in the world. The trainers new in WoW: Forever have only a
-- map spot in the data, so theirs is worked out from the map (SpotInWorld);
-- without that they would all sort after every trainer on the continent.
local function TrainerSpot(trainer)
    local spot = ns.Data.npcs[trainer.npc]
    return SpotInWorld(spot) or spot
end

-- `trainers` nearest first: those on the player's continent by distance,
-- then the rest with a map spot, then those without one. Ties, and every
-- trainer while the player's position is unknown, keep the data's order
-- (grouped by map). `SpotOf` gives each one's spot, with its continent and
-- world x and y (default: a trainer's, TrainerSpot), so other lists, a
-- family's beasts, sort the same way.
local NEAR, ELSEWHERE, NO_SPOT = 1, 2, 3
local function NearestFirst(trainers, SpotOf)
    SpotOf = SpotOf or TrainerSpot
    local continent, x, y = PlayerWorldPosition()
    local candidates = {}
    for i, trainer in ipairs(trainers) do
        local spot = SpotOf(trainer)
        local candidate = { trainer = trainer, group = spot and ELSEWHERE or NO_SPOT, distance = 0, index = i }
        if spot and continent and spot.continent == continent then
            candidate.group, candidate.distance = NEAR, (spot.worldX - x) ^ 2 + (spot.worldY - y) ^ 2
        end
        candidates[i] = candidate
    end
    table.sort(candidates, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.index < b.index
    end)
    local ordered = {}
    for i, candidate in ipairs(candidates) do ordered[i] = candidate.trainer end
    return ordered
end
ns.UI.NearestFirst = NearestFirst  -- the Classes tab's Overview lists class trainers nearest first, Pets beasts

-- Each recipe's trainers nearest first, worked out when its page is shown
-- (the player moves between pages) and kept while it shows. The recipes
-- whose whole list is open ("N more trainers") are kept as Settings'
-- "Remember sections" says (ns.SectionMemory's "trainers" area, by the
-- recipe's spell ID).
local trainerOrder = {}

-- A recipe's "Taught by" lines, added to `lines`: the heading, the nearest
-- TRAINERS_SHOWN trainers (all of them while open), then "N more trainers"
-- or "Show fewer".
local function AddTrainerLines(lines, spellID)
    local trainers = RecipeTrainers(spellID)
    if #trainers == 0 then return end
    trainerOrder[spellID] = trainerOrder[spellID] or NearestFirst(trainers)
    local ordered = trainerOrder[spellID]
    local isOpen = ns.SectionMemory.IsOpen(ns.SectionMemory.Area("trainers"), spellID)
    table.insert(lines, { heading = L["Taught by"] })
    local listed = isOpen and #ordered or math.min(#ordered, TRAINERS_SHOWN)
    for i = 1, listed do
        table.insert(lines, { src = ordered[i], side = ordered[i].side, withZone = true })
    end
    if #ordered <= TRAINERS_SHOWN then return end
    local more = Theme:Plural(#ordered - TRAINERS_SHOWN, L["%d more trainer"], L["%d more trainers"])
    table.insert(lines, { opensTrainersOf = spellID, isOpen = isOpen, text = isOpen and L["Show fewer"] or more })
end

-- An entry that is a recipe's trainers alone ({ taughtBy = spell ID }, no
-- item): the recipe page's Learned from box for a recipe no item teaches.
local function IsTrainersOnly(entry)
    return entry.taughtBy ~= nil and entry.itemID == nil
end

-- The vendors this character can buy from (their side's, or anyone's)
-- under "Sold by", added to `lines`; nothing when none is. With `withZone`
-- (a search result, which has no page around it) each names its zone.
local function AddSoldByLines(lines, vendors, withZone)
    local mine = ns.PlayerFaction()
    local shown = {}
    for _, vendor in ipairs(vendors or {}) do
        if not vendor.side or vendor.side == mine then
            table.insert(shown, { src = vendor, side = vendor.side, withZone = withZone })
        end
    end
    if #shown == 0 then return end
    table.insert(lines, { heading = L["Sold by"] })
    for _, line in ipairs(shown) do table.insert(lines, line) end
end

-- A recipe item's drops and vendors (Data/RecipeSources.lua), added to `lines`.
local function AddRecipeSources(lines, entry)
    local sources = ns.Data.recipeSources[entry.itemID]
    if not sources then return end
    if sources.drops then
        local heading = L["Drops from"]
        if type(sources.world) == "table" then
            heading = L["World drop  ·  mobs level %d-%d"]:format(sources.world[1], sources.world[2])
        elseif sources.world then
            heading = L["World drop"]
        end
        table.insert(lines, { heading = heading })
        for _, drop in ipairs(sources.drops) do table.insert(lines, { src = drop, drop = true }) end
    end
    AddSoldByLines(lines, sources.vendors)
end

-- Each reagent's vendors this character can buy from (Data/Poisons.lua): their
-- side's and those who serve both, nearest first. Put in order when a page
-- is shown, as trainers are (ShowItems), and kept while it shows.
local vendorOrder = {}
local function NearestVendors(itemID)
    if vendorOrder[itemID] then return vendorOrder[itemID] end
    local data = ns.Data.reagentVendors
    local mine = ns.PlayerFaction()
    local canBuyFrom = {}
    for _, npc in ipairs(data.items[itemID] or {}) do
        local vendor = data.vendors[npc]
        if vendor and (not vendor.side or vendor.side == mine) then table.insert(canBuyFrom, vendor) end
    end
    vendorOrder[itemID] = NearestFirst(canBuyFrom)
    return vendorOrder[itemID]
end

-- A reagent's nearest vendor (entry.soldBy: the class recipe pages'
-- materials), added to `lines` under "Nearest vendor", with their zone.
local function AddVendorLines(lines, itemID)
    local nearest = NearestVendors(itemID)[1]
    if not nearest then return end
    table.insert(lines, { heading = L["Nearest vendor"] })
    table.insert(lines, { src = nearest, side = nearest.side, withZone = true })
end

-- The page NeedRoll lists `itemID` on (one of ns.Wishlist:Sources) that
-- `Matches` picks, or nil.
local function ListedSource(itemID, Matches)
    for _, source in ipairs(ns.Wishlist:Sources(itemID)) do
        if Matches(source) then return source end
    end
end

-- The page NeedRoll has for quest `questID`, as a source to open
-- (ns.UI.OpenItemSource): a dungeon's or raid's quest with that ID, else a
-- class's; nil when NeedRoll lists it nowhere.
local function QuestSource(questID)
    for _, category in ipairs({ "DUNGEON", "RAID" }) do
        for _, instance in ipairs(ns.Data:List(category)) do
            local quest = ns.Data:DungeonQuest(instance.id, questID)
            if quest then return { kind = "Quest", inst = instance, quest = quest, name = quest.name } end
        end
    end
    for classToken in pairs(ns.Data.classQuests) do
        local quest = ns.Data:ClassQuest(classToken, questID)
        if quest then return { kind = "Quest", classToken = classToken, quest = quest, name = quest.name } end
    end
end
ns.UI.QuestSource = QuestSource  -- the Professions Overview's quests (UI/ProfessionOverview.lua)

-- The quests a recipe comes with (entry.quests: the rogue's first Instant
-- Poison comes with the Poisons skill, which a quest gives), a pet or a
-- searched item is the reward of, or a dungeon or raid loot row's item is
-- asked for by, those of the player's side: the quest's name, then who
-- gives it, pinned on the map. A quest NeedRoll has a page for opens it
-- from its name.
local function AddQuestLines(lines, quests)
    local mine = ns.PlayerFaction()
    for _, quest in ipairs(quests) do
        if not quest.side or quest.side == mine then
            local page = QuestSource(quest.id)
            local name = ns.Data.questNames[quest.id] or quest.name or page and page.name
                or L["quest %s"]:format(quest.id)
            table.insert(lines, { heading = L["Quest: %s"]:format(name), opens = page })
            if quest.giverNpc then
                table.insert(lines, { src = { name = quest.giver, npc = quest.giverNpc }, side = quest.side,
                    withZone = true })
            end
        end
    end
end

-- A pet's drops: each mob pins its spot (or its dungeon's entrance), but a
-- boss whose loot NeedRoll lists the pet in opens that loot instead.
local function AddPetDropLines(lines, itemID, drops)
    if not drops then return end
    table.insert(lines, { heading = L["Drops from"] })
    for _, drop in ipairs(drops) do
        local bossLoot = drop.inside and ListedSource(itemID, function(source)
            return source.kind == "Drop" and source.inst.id == drop.inside and source.name == drop.name
        end)
        table.insert(lines, { src = drop, drop = true, opens = bossLoot })
    end
end

-- What a pet comes out of: items (their icon and name; the first
-- CONTAINERS_SHOWN, then "+N more" naming the rest) and objects.
local CONTAINERS_SHOWN = 3
local function AddFoundInLines(lines, containers, objects)
    if not (containers or objects) then return end
    table.insert(lines, { heading = L["Found in"] })
    containers = containers or {}
    for i = 1, math.min(#containers, CONTAINERS_SHOWN) do
        table.insert(lines, { itemID = containers[i].itemID, name = containers[i].name })
    end
    if #containers > CONTAINERS_SHOWN then
        local rest = {}
        for i = CONTAINERS_SHOWN + 1, #containers do table.insert(rest, containers[i].name) end
        table.insert(lines, { more = rest, text = L["+%d more"]:format(#rest) })
    end
    for _, object in ipairs(objects or {}) do table.insert(lines, { src = object, withZone = true }) end
end

-- A companion pet's sources (entry.petSources, Data/CompanionSources.lua),
-- added to `lines`: its recipe when it is crafted, the mobs that drop it,
-- the vendors this character can buy from, its quests of this character's
-- side and what it comes out of.
local function AddPetSources(lines, entry)
    local itemID, sources = entry.itemID, entry.petSources
    local recipe = ListedSource(itemID, function(source) return source.kind == "Crafted" end)
    if recipe then table.insert(lines, { heading = L["Crafted: %s"]:format(recipe.inst.name), opens = recipe }) end
    AddPetDropLines(lines, itemID, sources.drops)
    AddSoldByLines(lines, sources.vendors)
    if sources.quests then AddQuestLines(lines, sources.quests) end
    AddFoundInLines(lines, sources.containers, sources.objects)
end

-- Where a recipe item or a companion pet (entry.petSources) comes from,
-- who teaches its recipe (entry.taughtBy, the recipe's spell ID) or which
-- quest it comes with (entry.quests; a search result's: the quests
-- rewarding its item), the quests a dungeon or raid loot row's item is for
-- while the Quests tab is on, where to buy a material (entry.soldBy) or a
-- search result's item (entry.buyFrom, the vendors of the player's side,
-- see UI/Search.lua), as the lines shown under it: a heading, then each
-- mob or vendor ({ src, side }), name only: where they stand shows in the
-- tooltip, which keeps the box short. Trainers, quest givers and the
-- nearest vendor show their zone too.
local function SourceLines(entry)
    local lines = {}
    if entry.recipe then AddRecipeSources(lines, entry) end
    if entry.petSources then AddPetSources(lines, entry) end
    if entry.taughtBy then AddTrainerLines(lines, entry.taughtBy) end
    if entry.quests then AddQuestLines(lines, entry.quests) end
    local askedForBy = ns.Modules:IsOn("QUESTS") and ns.Data:QuestsAskingFor(entry)
    if askedForBy then AddQuestLines(lines, askedForBy) end
    if entry.soldBy then AddVendorLines(lines, entry.itemID) end
    if entry.buyFrom then AddSoldByLines(lines, entry.buyFrom, true) end
    if #lines == 0 then return nil end
    return lines
end

-- Height a recipe item's source lines add under its cell (a cell `rowHeight`
-- tall). Drops and vendors never change, so their height is worked out once
-- per entry; trainer lines open and shut, so theirs is counted each time. A
-- trainers-only cell's lines start at its top: only what runs past the
-- cell counts.
local sourcesHeights = setmetatable({}, { __mode = "k" })
local function SourcesHeight(entry, rowHeight)
    if entry.taughtBy then
        local lines = SourceLines(entry)
        local height = lines and #lines * SOURCE_ROW or 0
        if IsTrainersOnly(entry) then return math.max(0, TRAINERS_TOP + height - rowHeight) end
        return height > 0 and SOURCE_TOP + height or 0
    end
    if sourcesHeights[entry] then return sourcesHeights[entry] end
    local lines = SourceLines(entry)
    local height = lines and SOURCE_TOP + #lines * SOURCE_ROW or 0
    sourcesHeights[entry] = height
    return height
end

-- One line under a recipe item or a pet: a heading, or a mob, vendor or
-- trainer whose name pins them on the map (vendors and trainers of one side
-- show its crest first, those anyone can use the quest giver icon; mobs that
-- drop the recipe show the Horde flight point and its red, like the mobs
-- that drop a quest's starting item), or the gold "N more trainers" that
-- opens a recipe's whole trainer list. A heading or mob that `opens` a
-- NeedRoll page (a pet's quest or recipe, a boss's loot) is a link to it;
-- an item a pet comes out of shows its icon and tooltip. Every icon is
-- drawn at SOURCE_CREST.
local DROPPER_ATLAS = "TaxiNode_Continent_Horde"  -- the Overview's DROPPER_ICON atlas
local ANYONE_ATLAS = "TaxiNode_Continent_Alliance"  -- a vendor both sides can buy from (the quest giver icon)
-- What a line that opens a NeedRoll page says it does, by the page's kind.
local OPENS_HINTS = { Drop = L["Click to open its loot"], Quest = L["Click to open this quest"],
                      Crafted = L["Click to open this recipe"] }

-- A line that opens a page is in its kind's colour: a quest's in the quest
-- colour, a boss's in the droppers' red, a recipe as a link.
local function OpensColor(source)
    if source.kind == "Quest" then return Theme.color.quest end
    if source.kind == "Drop" then return Theme.color.dropper end
    return Theme.color.link
end

local function CreateSourceLine(cell)
    local line = CreateFrame("Button", nil, cell)
    line:SetHeight(SOURCE_ROW)
    line.crest = line:CreateTexture(nil, "ARTWORK")
    line.crest:SetPoint("LEFT", 0, 0)
    line.text = Theme:Text(line, Theme.font.source)
    line.text:SetJustifyH("LEFT")
    line.text:SetPoint("RIGHT")

    function line:Set(info)
        self.info = info
        self.spot = nil
        if self.arrow then self.arrow:Hide() end
        local src = info.src
        local icon = info.side and Theme:Insignia(info.side) or info.drop and DROPPER_ATLAS
            or src and ANYONE_ATLAS
        self.crest:SetShown(icon ~= nil or info.itemID ~= nil)
        self.text:ClearAllPoints()
        self.text:SetPoint("RIGHT")
        if icon then
            Theme:FitAtlas(self.crest, icon, SOURCE_CREST)
            self.text:SetPoint("LEFT", self.crest, "RIGHT", 4, 0)
        elseif info.itemID then
            self.text:SetPoint("LEFT", self.crest, "RIGHT", 4, 0)
        else
            self.text:SetPoint("LEFT", 0, 0)  -- a heading
        end
        if info.opensTrainersOf then
            self:ShowToggle(info)
            return
        end
        if info.itemID then
            self:ShowItem(info)
            return
        end
        if not src then
            -- A heading, or "+N more" (its tooltip names the rest).
            self.text:SetText(info.heading or info.text)
            Theme:SetTextColor(self.text, info.opens and OpensColor(info.opens) or Theme.color.muted)
            self:EnableMouse(info.opens ~= nil or info.more ~= nil)
            return
        end
        -- A boss's loot opens in NeedRoll; anything else pins its spot.
        if not info.opens then self.spot, self.spotName = SourceSpot(src) end
        self:EnableMouse(self.spot ~= nil or info.opens ~= nil)
        local color = info.drop and Theme.color.dropper or self.spot and Theme.color.link
        local name = color and (Theme:ColorCode(color) .. src.name .. "|r") or src.name
        -- A trainer's or vendor's zone follows the name: it says which of the nearest is where.
        local zone = info.withZone and SourceZone(src)
        if zone then name = Theme:JoinDots(name, Theme:ColorCode(Theme:Opaque(Theme.color.muted)) .. zone .. "|r") end
        self.text:SetText(name)
        Theme:SetTextColor(self.text, Theme.color.text)
    end

    -- "N more trainers" with the section arrow pointing right after it, or
    -- "Show fewer" with it pointing down, in gold: a click opens or shuts the
    -- recipe's whole trainer list.
    function line:ShowToggle(info)
        self.text:SetText(info.text)
        Theme:SetTextColor(self.text, Theme.color.heading)
        if not self.arrow then self.arrow = Theme:Arrow(self, true, TRAINERS_ARROW) end
        self.arrow:SetOpen(info.isOpen)
        self.arrow:ClearAllPoints()
        self.arrow:SetPoint("LEFT", self.text, "LEFT", math.ceil(self.text:GetStringWidth()) + 4, 0)
        self.arrow:Show()
        self:EnableMouse(true)
    end

    -- An item a pet comes out of: its icon, then its name as a link.
    function line:ShowItem(info)
        self.crest:SetTexture(C_Item.GetItemIconByID(info.itemID))
        self.crest:SetTexCoord(0, 1, 0, 1)  -- an atlas this line showed before leaves its own
        self.crest:SetSize(SOURCE_CREST, SOURCE_CREST)
        self.text:SetText(C_Item.GetItemNameByID(info.itemID) or info.name)
        Theme:SetTextColor(self.text, Theme.color.link)
        self:EnableMouse(true)
    end

    -- An item line's tooltip: the item's own, then where a click goes.
    local function ShowItemTooltip(self)
        local itemID = self.info.itemID
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
        GameTooltip:SetItemByID(itemID)
        if ns.Wishlist:BestSource(itemID) then
            GameTooltip:AddLine(L["Click to open its source"], unpack(Theme.tip.hint))
        end
        GameTooltip:Show()
    end

    -- A heading that opens a page: its name, then what a click does. "+N
    -- more": the names it stands for.
    local function ShowHeadingTooltip(self)
        local info = self.info
        if not (info.opens or info.more) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
        if info.more then
            for _, name in ipairs(info.more) do GameTooltip:AddLine(name, unpack(Theme.tip.info)) end
        else
            local opens = info.opens
            GameTooltip:SetText(opens.name)
            -- Where the page is: its dungeon, or the class whose quest it is.
            local place = opens.classToken and ns.UI.ClassName(opens.classToken) or ns.Data:PlaceName(opens.inst)
            GameTooltip:AddLine(place, unpack(Theme.tip.info))
            GameTooltip:AddLine(OPENS_HINTS[opens.kind] or L["Click to open this page"], unpack(Theme.tip.hint))
        end
        GameTooltip:Show()
    end

    line:SetScript("OnEnter", function(self)
        if self.info.itemID then return ShowItemTooltip(self) end
        ns.UI.HoverMapLink(self, self.spot)
        -- The name, then where they stand (and the drop rate): the line
        -- itself shows the name only. "N more trainers" says nothing more.
        local src = self.info.src
        if not src then return ShowHeadingTooltip(self) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
        GameTooltip:SetText(src.name)
        local rate = src.rate and ns.SHOW_DROP_RATES and SourceDropRate(src.rate)
        if not src.npc and src.inside then
            local dungeon = ns.Data:Get(src.inside)
            GameTooltip:AddLine(dungeon and L["Inside %s"]:format(dungeon.name) or L["Inside the dungeon"])
            if rate then GameTooltip:AddLine(rate) end
            local hint = self.info.opens and OPENS_HINTS.Drop or L["Click to pin the entrance on your map"]
            GameTooltip:AddLine(hint, unpack(Theme.tip.text))
        else
            local where = Theme:JoinDots(SourceZone(src), rate)
            if where ~= "" then GameTooltip:AddLine(where) end
            -- A vendor of Data/VendorItems.lua that restocks the item over time.
            if src.limited then GameTooltip:AddLine(L["Limited supply"], unpack(Theme.tip.info)) end
            if self.spot then GameTooltip:AddLine(ns.UI.PinHint(self.spot), unpack(Theme.tip.text)) end
        end
        GameTooltip:Show()
    end)
    line:SetScript("OnLeave", function(self)
        ns.UI.LeaveMapLink(self)
        GameTooltip:Hide()
    end)
    line:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        local info = self.info
        if info.opensTrainersOf then
            cell.pane:ToggleTrainers(info.opensTrainersOf)
        elseif info.itemID and IsModifierKeyDown() then
            ns.Items:HandleModifiedClick(info.itemID)  -- links it or tries it on, as anywhere in the game
        elseif info.itemID then
            ns.UI.OpenItemSource(ns.Wishlist:BestSource(info.itemID), info.itemID)
        elseif info.opens then
            ns.UI.OpenItemSource(info.opens, cell.entry.itemID)
        elseif self.spot then
            ns.UI.ShowOnMap(self.spot, self.spotName)
        end
    end)
    return line
end

-- A search result's boss portrait, scaled so its ring roughly fills the
-- icon's square, and the portrait's center in its own (unscaled) frame:
-- the 58px portrait inside the box CreateBossPortrait builds (its 80px ring
-- reaches 11px past it).
local SEARCH_PORTRAIT = 0.5
local QUEST_ATLAS = "Exclamation-up-c60" -- a quest result's icon, as the Quests list's
local PORTRAIT_CENTER_X, PORTRAIT_CENTER_Y = 11 + 29, 11 + 29
local RANK_NAMES -- the boss portrait's, below

-- A boss ability's second line: "3 sec cast  ·  30 yd range", "Instant",
-- "Passive", from the client's spell data.
local function AbilityMeta(spellID)
    if C_Spell.IsSpellPassive(spellID) then return L["Passive"] end
    local info = C_Spell.GetSpellInfo(spellID)
    if not info then return "" end
    local castMs = info.castTime or 0
    local seconds = ("%.1f"):format(castMs / 1000):gsub("%.0$", "")
    local castText = castMs > 0 and L["%s sec cast"]:format(seconds) or L["Instant"]
    local range = info.maxRange or 0
    local rangeText = range > 5 and L["%d yd range"]:format(range) or range > 0 and L["Melee range"] or nil
    return Theme:JoinDots(castText, rangeText)
end

-- "280 to 319", or "9" when every amount seen was the same.
local function AmountRange(amounts)
    return amounts[1] == amounts[2] and tostring(amounts[1]) or L["%d to %d"]:format(amounts[1], amounts[2])
end

-- A boss ability's description as the client words it ("" while its spell
-- data loads), then what combat logs saw it do (entry.observed, see
-- ns.Data:Observed), one line per kind: "Observed values: 280 to 319".
local function AbilityText(entry)
    local text = C_Spell.GetSpellDescription(entry.ability) or ""
    local seen = entry.observed
    if not seen then return text end
    local lines = {}
    if seen.hit then table.insert(lines, L["Observed values: %s"]:format(AmountRange(seen.hit))) end
    if seen.tick then table.insert(lines, L["Observed values: %s per tick"]:format(AmountRange(seen.tick))) end
    if seen.heal then table.insert(lines, L["Observed healing: %s"]:format(AmountRange(seen.heal))) end
    if not lines[1] then return text end
    local observed = table.concat(lines, "\n")
    return text == "" and observed or (text .. "\n\n" .. observed)
end

-- An item's source under its name (entry.from, one of ns.Wishlist:Sources;
-- the Classes tab's set pieces): a boss in the droppers' red, a quest in its
-- colour, anything else as a link. A button over the name alone takes the
-- click, which opens it as the Wishlist's rows do.
local SOURCE_LINK_COLORS = { Drop = "dropper", Quest = "quest" }
local SOURCE_LINK_HINTS = { Drop = L["Click to open its loot"], Quest = L["Click to open this quest"],
                            Crafted = L["Click to open this recipe"] }

local function SourceLinkText(source)
    if not source then return nil end
    return Theme:ColorCode(Theme.color[SOURCE_LINK_COLORS[source.kind] or "link"]) .. source.name .. "|r"
end

local function CreateSourceLink(cell)
    local link = CreateFrame("Button", nil, cell)
    link:SetFrameLevel(cell:GetFrameLevel() + 2)
    link:SetScript("OnEnter", function(self)
        if not cell.isSelected then cell.hover:Show() end -- still over the row
        local source = cell.entry.from
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
        GameTooltip:AddLine(source.name, unpack(Theme.tip.title))
        GameTooltip:AddLine(ns.Data:PlaceName(source.inst), unpack(Theme.tip.info))
        GameTooltip:AddLine(SOURCE_LINK_HINTS[source.kind] or L["Click to open this page"], unpack(Theme.tip.hint))
        GameTooltip:Show()
    end)
    link:SetScript("OnLeave", function()
        cell.hover:Hide()
        GameTooltip:Hide()
    end)
    link:SetScript("OnClick", function() ns.UI.OpenItemSource(cell.entry.from, cell.entry.itemID) end)
    link:Hide()
    return link
end

-- An item cell's methods, written once here and copied onto each cell.
local Cell = {}

-- The tick after an item's name: in color once its look is collected,
-- greyed out until then; hovering it says which.
local function CreateTick(cell)
    local tick = CreateFrame("Frame", nil, cell)
    tick.tex = tick:CreateTexture(nil, "OVERLAY")
    tick.tex:SetAllPoints()
    tick.tex:SetAtlas("common-icon-checkmark")
    tick:Hide()
    tick:EnableMouse(true)
    ns.UI.ClicksReachBeneath(tick)
    tick:SetScript("OnEnter", function(self)
        if not cell.isSelected then cell.hover:Show() end -- still over the row
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR") -- at the mouse, not beside the row
        if self.known then
            GameTooltip:SetText(L["Appearance collected"], unpack(Theme.tip.good))
        else
            GameTooltip:SetText(L["Appearance not collected"], unpack(Theme.tip.quiet))
        end
        GameTooltip:Show()
    end)
    tick:SetScript("OnLeave", function()
        cell.hover:Hide()
        GameTooltip:Hide()
    end)
    return tick
end

local function CreateCell(parent)
    local cell = Theme:Row(parent, Size.itemRow) -- selected only when a search result led here
    for name, method in pairs(Cell) do cell[name] = method end

    -- Its quality border keeps the style it was made in: a style swap parks
    -- the old window's cells, not rebuilds them.
    Theme:QualityIcon(cell)
    cell.iconBorder:SetSize(38, 38)
    cell.iconBorder:SetPoint("LEFT", 6, 0)

    -- The fonts it draws with (a pane drawn smaller swaps them, see SetZoom).
    cell.fonts = Theme.font
    cell.rate = Theme:Text(cell, Theme.font.small)
    cell.rate:SetPoint("RIGHT", -10, 0)
    Theme:SetTextColor(cell.rate, Theme.color.rate)

    -- Name, then "Cloth  ·  Back", then the level requirement, each line
    -- stopping short of the chance or price.
    cell.name = Theme:Text(cell, Theme.font.body)
    cell.name:SetPoint("TOPLEFT", cell, "TOPLEFT", 54, -7)
    cell.sub = Theme:Text(cell, Theme.font.small)
    cell.sub:SetPoint("TOPLEFT", cell.name, "BOTTOMLEFT", 0, -3)
    cell.sub2 = Theme:Text(cell, Theme.font.small)
    cell.sub2:SetPoint("TOPLEFT", cell.sub, "BOTTOMLEFT", 0, -2)
    for _, text in ipairs({ cell.name, cell.sub, cell.sub2 }) do
        text:SetPoint("RIGHT", cell.rate, "LEFT", -8, 0)
        text:SetJustifyH("LEFT")
    end

    cell.textLeft = TEXT_LEFT
    cell.jump = CreateJumpArrow(cell)
    cell.go = CreateGoButton(cell)
    cell.star = CreateStar(cell)
    cell.starRoom = 0
    cell.sourceLines = {}

    cell:RegisterForClicks("LeftButtonUp")
    cell:HookScript("OnEnter", ShowTooltip)
    cell:HookScript("OnLeave", GameTooltip_Hide)
    cell.tick = CreateTick(cell)
    cell.tickRoom = 0
    cell:SetScript("OnClick", function(self)
        -- A search result opens its source; shift-click still links an item.
        if self.searchRow and not (self.entry.itemID and IsModifiedClick()) then
            GameTooltip:Hide()
            ns.UI:GoToResult(self.entry)
            return
        end
        if self.entry.gather then return end
        local spell = self.entry.spellID or self.entry.ability
        if spell then
            local link = C_Spell.GetSpellLink(spell)
            if link and IsModifiedClick("CHATLINK") then ChatFrameUtil.InsertLink(link) end
            return
        end
        ns.Items:HandleModifiedClick(self.entry.itemID)
    end)
    return cell
end

-- In the loot grid the icon runs from the name's top to the third line's
-- bottom (see ApplyFonts), with the text beside it.
function Cell:PlaceIcon()
    self.iconBorder:ClearAllPoints()
    if self.iconSize then
        self.iconBorder:SetSize(self.iconSize, self.iconSize)
        self.iconBorder:SetPoint("TOPLEFT", 6, -7)
    else
        self.iconBorder:SetSize(38, 38)
        self.iconBorder:SetPoint("LEFT", 6, 0)
    end
    self.name:SetPoint("TOPLEFT", self, "TOPLEFT", self.textLeft, -7)
end

function Cell:SetIconSize(size)
    self.iconSize = size
    self.textLeft = 6 + size + 10
    if not self.abilityLayout then self:PlaceIcon() end
end

-- A recipe item's sources, on lines under the cell (the grid leaves room);
-- a trainers-only cell's from its top.
function Cell:ShowSources(entry)
    local lines = SourceLines(entry) or {}
    local anchor, top = "BOTTOMLEFT", SOURCE_TOP
    if IsTrainersOnly(entry) then anchor, top = "TOPLEFT", TRAINERS_TOP end
    for i, info in ipairs(lines) do
        local line = self.sourceLines[i]
        if not line then
            line = CreateSourceLine(self)
            self.sourceLines[i] = line
        end
        -- Flush with the item's icon, not its name, so long mob and zone
        -- lines keep their room in a narrow window.
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", self, anchor, 6, -top - (i - 1) * SOURCE_ROW)
        line:SetPoint("RIGHT", self, "RIGHT", -8, 0)
        line:Set(info)
        line:Show()
    end
    for i = #lines + 1, #self.sourceLines do self.sourceLines[i]:Hide() end
end

-- Puts the tick just after the name's last word, on whichever line that
-- ends up (the name wraps the way the game does, word by word).
function Cell:PlaceTick()
    local nameText = self.name
    local text = nameText:GetText() or ""
    local full = nameText:GetUnboundedStringWidth()
    local width = nameText:GetWidth()
    if width <= 0 then width = full end
    local x, line = math.min(full, width), 0
    local words = SplitWords(text)
    -- The game's own line count where it gives one: a name a hair wider
    -- than the box by measure can still draw on one line (Deepgrave
    -- Trousers), and its tick then belongs after it, not on the line under
    -- it. The count can be a secret value, which can't be compared.
    local lines = ns.Plain(nameText:GetNumLines())
    if self.nameWraps and full > width and #words > 1 and (lines == nil or lines > 1) then
        local first = 1
        for i = 2, #words - 1 do
            nameText:SetText(table.concat(words, " ", 1, i))
            if nameText:GetUnboundedStringWidth() > width then break end
            first = i
        end
        nameText:SetText(table.concat(words, " ", first + 1))
        x, line = math.min(nameText:GetUnboundedStringWidth(), width), 1
        nameText:SetText(text)
    end
    local _, size = nameText:GetFont()
    size = size or 12
    self.tick:ClearAllPoints()
    self.tick:SetPoint("LEFT", nameText, "TOPLEFT", x + TICK_GAP, -line * (size + nameText:GetSpacing()) - size / 2)
end

-- A spell in place of an item: its icon in a plain border, and its name.
function Cell:SetSpellLook(spellID)
    self.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
    Theme:CropIcon(self.icon)
    self:SetBorderColor(unpack(Theme.color.line))
    self.name:SetText(C_Spell.GetSpellName(spellID) or "")
    Theme:SetTextColor(self.name, Theme.color.text)
    self.sub2:SetText("")
    self.rate:SetText("")
end

-- A recipe taught only by trainers: the cell shows nothing of its own (its
-- trainer lines start at its top, see ShowSources) and takes no hover or
-- click. Prepare gives a reused cell its icon and mouse back.
function Cell:SetTrainersOnly()
    self.icon:Hide()
    self.iconBorder:Hide()
    for _, text in ipairs({ self.name, self.sub, self.sub2, self.rate }) do text:SetText("") end
    self:EnableMouse(false)
end

-- An enchant: the spell's icon and name, in place of an item.
function Cell:SetSpell(entry)
    self:SetSpellLook(entry.spellID)
    self.sub:SetText(L["Enchant"])
end

-- A boss ability's card (see ABILITY_PAD): the icon moves up to the card's
-- corner and the description sits under it. Cells are reused, so Prepare
-- puts an item's icon and name back.
function Cell:SetAbility(entry)
    local spellID = entry.ability
    self:SetSpellLook(spellID)
    self.sub:SetText(AbilityMeta(spellID))
    self.iconBorder:ClearAllPoints()
    self.iconBorder:SetSize(38, 38)
    self.iconBorder:SetPoint("TOPLEFT", ABILITY_PAD, -ABILITY_PAD)
    self.name:SetPoint("TOPLEFT", self, "TOPLEFT", 54, -12)
    self.abilityLayout = true
    -- The card backdrop sits just under the cell, so the cell's hover fill
    -- draws over it. It is the cell's sibling, so it hides with it.
    if not self.card then
        local card = CreateFrame("Frame", nil, self:GetParent())
        card:SetAllPoints(self)
        card:SetFrameLevel(math.max(0, self:GetFrameLevel() - 1))
        Theme:CardBackdrop(card, self:GetParent())
        self.card = card
        self:HookScript("OnHide", function(hidden) hidden.card:Hide() end)
    end
    self.card:Show()
    self.card:FitCard()
    if not self.descBox then
        local box = CreateFrame("Frame", nil, self)
        box:SetPoint("TOPLEFT", ABILITY_PAD, -ABILITY_BOX_TOP)
        box:SetPoint("BOTTOMRIGHT", -ABILITY_PAD, ABILITY_PAD)
        box.text = Theme:Text(box, self.fonts.body)
        box.text:SetPoint("TOPLEFT", ABILITY_PAD, -ABILITY_PAD)
        box.text:SetPoint("RIGHT", -ABILITY_PAD, 0)
        box.text:SetJustifyH("LEFT")
        box.text:SetJustifyV("TOP")
        box.text:SetWordWrap(true)
        Theme:SetTextColor(box.text, Theme.color.text)
        self.descBox = box
    end
    -- Numbers (damage, durations, percents) in the heading color, so the
    -- values stand out when skimming.
    local gold = Theme:ColorCode(Theme.color.heading)
    local text = AbilityText(entry)
    self.descBox.text:SetText((text:gsub("%d[%d,%.]*%%?", function(number)
        -- A sentence's full stop stays outside the color.
        local stop = number:match("%.$") or ""
        return gold .. number:sub(1, #number - #stop) .. "|r" .. stop
    end)))
    self.descBox:SetShown(text ~= "")
    if GameTooltip:IsOwned(self) then ShowTooltip(self) end
end

-- A Scarce reagent's source: the icon of what it yields, the node or mob,
-- "Requires Mining 65" (colored against your skill), with the chance at the
-- right and how many gathers were sampled under it.
function Cell:SetGather(entry)
    local src, prof = entry.gather, entry.profession
    local yields = NODE_ITEMS[src.name]
    -- Round, in the gold ring the section headers' icons wear.
    if not self.nodeIcon then
        self.nodeIcon = self:CreateTexture(nil, "OVERLAY")
        self.nodeIcon:SetSize(NODE_ICON, NODE_ICON)
        self.nodeIcon:SetPoint("CENTER", self.iconBorder)
        Theme:MaskRound(self, self.nodeIcon)
        self.nodeRing = self:CreateTexture(nil, "OVERLAY", nil, 2)
        self.nodeRing:SetPoint("CENTER", self.iconBorder)
        Theme:FitAtlas(self.nodeRing, NODE_RING, NODE_RING_SIZE)
        self.nodeRing:SetDesaturated(true)
    end
    self.nodeIcon:SetTexture(yields and C_Item.GetItemIconByID(yields) or ns.UI.ProfessionIcon(prof.id))
    Theme:CropIcon(self.nodeIcon)
    self.nodeRing:SetVertexColor(unpack(Theme.color.discRing))
    self.nodeIcon:Show()
    self.nodeRing:Show()
    self.icon:Hide()
    self.iconBorder:Hide()
    local name, req, rate, samples = GatherTexts(entry)
    self.name:SetText(name)
    Theme:SetTextColor(self.name, Theme.color.text)
    self.sub:SetText(req)
    -- Too narrow for the chance at the right: it goes on a third line.
    if self.stacked then
        self.sub2:SetText(Theme:JoinDots(rate ~= "" and (Theme:ColorCode(Theme.color.text) .. rate .. "|r") or nil,
            samples ~= "" and samples or nil))
        self.rate:SetText("")
        if self.samples then self.samples:Hide() end
        if GameTooltip:IsOwned(self) then ShowTooltip(self) end
        return
    end
    self.sub2:SetText("")
    self.rate:SetFontObject(self.fonts.body)
    self.rate:SetText(rate)
    Theme:SetTextColor(self.rate, Theme.color.text)
    -- The samples sit under the chance, the pair centered on the row.
    if not self.samples then
        self.samples = Theme:Text(self, self.fonts.small)
        self.samples:SetPoint("TOPRIGHT", self.rate, "BOTTOMRIGHT", 0, -2)
        self.samples:SetJustifyH("RIGHT")
    end
    self.samples:SetText(samples)
    Theme:SetTextColor(self.samples, Theme.color.muted)
    self.samples:Show()
    if samples ~= "" and rate ~= "" then
        self.rate:ClearAllPoints()
        self.rate:SetPoint("RIGHT", -10, 7)
    end
    if GameTooltip:IsOwned(self) then ShowTooltip(self) end
end

-- "Level 54 Elite", "Level ??" (a skull), or nil when the level isn't known.
-- boss = { name, display ID, level (-1 for ??), rank }.
local function BossLevelText(boss)
    local level = boss[3] == -1 and "??" or boss[3]
    if not level then return nil end
    local rank = RANK_NAMES[boss[4]]
    return rank and L["Level %s %s"]:format(level, rank) or L["Level %s"]:format(level)
end

-- A boss found by search: its portrait in the boss pins' ring where the
-- icon goes, built the first time one shows.
function Cell:SetBoss(entry)
    if not self.portrait then
        self.portrait = ns.UI.CreateBossPortrait(self)
        self.portrait:SetScale(SEARCH_PORTRAIT)
        self.portrait.hit:EnableMouse(false) -- the row's tooltip says more
        self.portrait:SetPoint("TOPLEFT", self.iconBorder, "CENTER", -PORTRAIT_CENTER_X, PORTRAIT_CENTER_Y)
    end
    self.portrait:SetBoss(entry.look)
    self.icon:Hide()
    self.iconBorder:Hide()
    self.sub:SetText(BossLevelText(entry.look) or L["Boss"])
    local where = entry.inst.name
    if entry.enc.name ~= entry.name then where = Theme:JoinDots(entry.enc.name, where) end
    self.sub2:SetText(where)
end

-- A dungeon or raid found by search: the world map's entrance swirl, its
-- kind and zone, then its levels and boss count.
function Cell:SetPlace(entry)
    local instance = entry.inst
    local isRaid = instance.category == "RAID"
    self.icon:SetTexCoord(0, 1, 0, 1)
    self.icon:SetAtlas(isRaid and "Raid" or "Dungeon")
    self.iconBorder:Hide()
    self.sub:SetText(Theme:JoinDots(isRaid and L["Raid"] or L["Dungeon"], instance.zone))
    local range = instance.levelRange
    local bosses = ns.Data:BossCount(instance)
    self.sub2:SetText(Theme:JoinDots(range and L["Level %d-%d"]:format(range[1], range[2]),
        bosses == 1 and L["1 boss"] or bosses > 0 and L["%d bosses"]:format(bosses) or nil))
end

-- A quest found by search: the Quests list's "!" where the icon goes
-- (fitted to the icon's height, its own shape), "Quest" or "Attunement" and
-- its level, then where it is (and for which side).
function Cell:SetQuest(entry)
    local quest = entry.quest
    if not self.questIcon then self.questIcon = self:CreateTexture(nil, "ARTWORK") end
    Theme:FitAtlas(self.questIcon, QUEST_ATLAS, self.icon:GetHeight())
    self.questIcon:ClearAllPoints()
    self.questIcon:SetPoint("CENTER", self.icon, "CENTER")
    self.questIcon:Show()
    self.icon:Hide()
    self.iconBorder:Hide()
    self.sub:SetText(Theme:JoinDots(entry.attunement and L["Attunement"] or L["Quest"],
        quest.level and L["Level %d"]:format(quest.level)))
    self.sub2:SetText(Theme:JoinDots(entry.inst.name, quest.side and ns.SideName(quest.side)))
end

-- A Library book found by search: its icon, its border in its quality
-- color as an item's, "Library book" and where it stands for the character
-- (Core/LibraryBooks.lua's words), then its zone and the place it sits.
function Cell:SetBook(entry)
    local book = entry.book
    self.icon:SetTexture(C_Item.GetItemIconByID(book.item) or QUESTION_ICON)
    Theme:CropIcon(self.icon) -- a dungeon's swirl may have used it
    local r, g, b = Theme:QualityColor(ns.Items:Quality(book.item))
    self:SetBorderColor(r, g, b, 0.9)
    self.sub:SetText(Theme:JoinDots(L["Library book"], ns.LibraryBooks.STATUS_TEXT[entry.status]))
    self.sub2:SetText(Theme:JoinDots(ns.UI.PetPageKit.ZoneName(book.spots[1].map), book.place))
end

-- Fills the cell; on a pane too narrow for the chance or price at the right
-- (`stacked`), that moves to the end of the last text line.
function Cell:SetEntry(entry, showSource)
    self:Prepare(entry, showSource)
    if entry.gather then
        self:SetGather(entry)
    elseif entry.ability then
        self:SetAbility(entry)
    elseif entry.kind then
        -- A boss, dungeon, quest or Library book found by search: its name in
        -- the heading color over what it is.
        self.name:SetText(entry.name)
        Theme:SetTextColor(self.name, Theme.color.heading)
        self.rate:SetText("")
        if entry.kind == "boss" then
            self:SetBoss(entry)
        elseif entry.kind == "quest" then
            self:SetQuest(entry)
        elseif entry.kind == "book" then
            self:SetBook(entry)
        else
            self:SetPlace(entry)
        end
        if GameTooltip:IsOwned(self) then ShowTooltip(self) end
    elseif IsTrainersOnly(entry) then
        self:SetTrainersOnly()
    elseif entry.spellID then
        self:SetSpell(entry)
    else
        self:SetItem(entry, showSource)
    end
    local rate = self.stacked and self.rate:GetText()
    if rate and rate ~= "" then
        local r, g, b = self.rate:GetTextColor()
        local code = ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
        local last = (self.sub2:GetText() or "") ~= "" and self.sub2 or self.sub
        last:SetText(Theme:JoinDots(last:GetText(), code .. rate .. "|r"))
        self.rate:SetText("")
    end
    -- A long name (a Pattern:, Recipe: or Schematic: and the like) wraps
    -- onto a second line when the cell has a third line free.
    self.nameWraps = not self.abilityLayout and (self.sub2:GetText() or "") == ""
    self.name:SetWordWrap(self.nameWraps)
    self.name:SetMaxLines(self.nameWraps and 2 or 1)
    if self.tick:IsShown() then self:PlaceTick() end
end

-- Shows the star on a gear item (not a search result, recipe page product
-- or ability), lit when it is on the current wishlist. None while the
-- Wishlist module is off. Returns whether it shows.
function Cell:UpdateStar()
    local entry = self.entry
    local itemID = not (self.searchRow or entry.gather or entry.ability or entry.kind or entry.spellID
        or entry.count) and entry.itemID
    local shown = itemID and ns.Modules:IsOn("WISHLIST") and ns.Wishlist:CanStar(itemID) or false
    self.star:SetShown(shown)
    self.starRoom = shown and STAR_ROOM or 0
    if shown then self.star:SetOn(ns.Wishlist:Has(itemID)) end
    return shown
end

-- Greys the cell out (an item "Items I can use" greys: see FilterLoot), or
-- shows it as usual: faded, its icon in grey.
local GREYED_ITEM_ALPHA = 0.4
function Cell:SetGreyed(greyed)
    self:SetAlpha(greyed and GREYED_ITEM_ALPHA or 1)
    self.icon:SetDesaturated(greyed)
end

-- Puts a reused cell back to a plain item row for `entry`: nothing left
-- from its last entry, the chance or price at the right.
function Cell:Prepare(entry, showSource)
    self.entry = entry
    self.tick:Hide()
    self.tickRoom = 0
    self.name:SetPoint("RIGHT", self.rate, "LEFT", -8, 0)
    self.searchRow = showSource and (entry.inst ~= nil or entry.book ~= nil)
    self.jump:SetShown(entry.craft ~= nil)
    -- Search results make room on the right for their go-to button.
    local hasGoTo = self.searchRow
    self.go:SetShown(hasGoTo)
    -- Gear on a loot list gets the wishlist star at its right. Always asked,
    -- so a reused row never keeps a star from its last item.
    local starred = self:UpdateStar()
    self.rate:ClearAllPoints()
    if hasGoTo then
        self.rate:SetPoint("RIGHT", self.go, "LEFT", -6, 0)
    elseif starred then
        self.rate:SetPoint("RIGHT", self.star, "LEFT", -6, 0)
    else
        self.rate:SetPoint("RIGHT", -10, 0)
    end
    if self.portrait then self.portrait:Hide() end
    if self.sourceLink then self.sourceLink:Hide() end
    if self.questIcon then self.questIcon:Hide() end
    if self.descBox then self.descBox:Hide() end
    if self.card then self.card:Hide() end
    if self.abilityLayout then
        self.abilityLayout = nil
        self:PlaceIcon()
    end
    self.icon:Show()
    self.iconBorder:Show()
    self:EnableMouse(true)
    if self.nodeIcon then
        self.nodeIcon:Hide()
        self.nodeRing:Hide()
    end
    if self.samples then self.samples:Hide() end
    self.rate:SetFontObject(self.fonts.rate or self.fonts.small)
end

-- The button over the second grey line while it names the item's source
-- (entry.from), as wide as the name shows.
function Cell:ShowSourceLink(source)
    if not source then return end
    self.sourceLink = self.sourceLink or CreateSourceLink(self)
    local textWidth, lineWidth = self.sub2:GetUnboundedStringWidth(), self.sub2:GetWidth()
    self.sourceLink:ClearAllPoints()
    self.sourceLink:SetPoint("TOPLEFT", self.sub2)
    self.sourceLink:SetSize(lineWidth > 0 and math.min(textWidth, lineWidth) or textWidth,
        self.sub2:GetStringHeight())
    self.sourceLink:Show()
end

-- A tick after the name of an item with a look to collect, with room kept
-- for it, unless Settings hides the ticks.
function Cell:ShowTick(itemID)
    if ns.db.collectionTicks == false then return end
    local known = ns.Items:Collected(itemID)
    if known == nil then return end
    local _, size = self.name:GetFont()
    size = math.floor((size or 12) * TICK_SCALE + 0.5)
    self.tickRoom = size + TICK_GAP
    self.name:SetPoint("RIGHT", self.rate, "LEFT", -8 - self.tickRoom, 0)
    self.tick:SetSize(size, size)
    self.tick.known = known
    self.tick.tex:SetDesaturated(not known)
    self.tick:Show()
end

function Cell:SetItem(entry, showSource)
    local itemID = entry.itemID
    self.icon:SetTexture(C_Item.GetItemIconByID(itemID))
    Theme:CropIcon(self.icon) -- a dungeon's swirl may have used it
    -- Drops show their chance (when ns.SHOW_DROP_RATES); vendor rewards show
    -- their price, in gold, a currency or another item; recipe products and materials
    -- show how many.
    if entry.dropRate then
        self.rate:SetText(ns.SHOW_DROP_RATES and ("%.0f%%"):format(entry.dropRate * 100) or "")
        Theme:SetTextColor(self.rate, Theme.color.rate)
    elseif entry.count then
        -- Prepare puts the chance's font back on the next entry.
        self.rate:SetFontObject(Theme:ScaledFont(self.fonts.rate or self.fonts.small, COUNT_SCALE))
        self.rate:SetText(L["x%s"]:format(entry.count))
        Theme:SetTextColor(self.rate, Theme.color.text)
    else
        self.rate:SetText(PriceText(entry) or "")
        Theme:SetTextColor(self.rate, Theme.color.muted)
    end
    -- Search results and set pieces show where the item comes from in place
    -- of the level line, and the level after the type instead.
    local slotText = SlotText(itemID)
    local sourceText = showSource and entry.source or SourceLinkText(entry.from)
    self.sub:SetText(slotText)
    self.sub2:SetText(sourceText or "")
    self:ShowSourceLink(entry.from)

    local name = C_Item.GetItemNameByID(itemID)
    if not name then
        self.name:SetText(L["Loading..."])
        self.name:SetTextColor(unpack(Theme.color.faint))
        self:SetBorderColor(unpack(Theme.color.line))
        ns.Items:Load(itemID, function()
            if self.entry == entry then self:SetEntry(entry, showSource) end
        end)
        return
    end
    local r, g, b = Theme:QualityColor(ns.Items:Quality(itemID))
    self:ShowTick(itemID)
    self.name:SetText(name)
    self.name:SetTextColor(r, g, b, 1) -- full alpha: "Loading..." left it faint
    self:SetBorderColor(r, g, b, 0.9)
    local level = LevelText(itemID)
    if level and (showSource or entry.from) then
        self.sub:SetText(Theme:JoinDots(slotText, level))
    elseif level then
        self.sub2:SetText(level)
    end
    if GameTooltip:IsOwned(self) then ShowTooltip(self) end
end

-- How wide a text has to be to fit on two lines: the widest of its two
-- lines, broken between the words that make them most even.
local function TwoLineWidth(nameText)
    local text = nameText:GetText() or ""
    local best = nameText:GetUnboundedStringWidth()
    local words = SplitWords(text)
    for i = 1, #words - 1 do
        nameText:SetText(table.concat(words, " ", 1, i))
        local first = nameText:GetUnboundedStringWidth()
        nameText:SetText(table.concat(words, " ", i + 1))
        best = math.min(best, math.max(first, nameText:GetUnboundedStringWidth()) + 1) -- a pixel spare for rounding
    end
    nameText:SetText(text)
    return best
end

-- The Overview's quest rewards use the same cell, scaled down.
ns.UI.CreateItemCell = CreateCell

-- Standing bar for the Factions tab: progress through the current standing
-- with its name and numbers beside it ("Friendly  ·  2,267 / 6,000"). A flat
-- accent fill on a faint track (modern), or a soft pill in the standing's
-- own color from the Reputation window, toned down, on a dark see-through
-- track (native, Theme.nativeBar).

-- A standing as the standing bar writes it: its name, then its progress
-- through the standing in muted ("Friendly  ·  2,267 / 6,000"), none once
-- full.
local function StandingText(reaction, value, max)
    local name = ns.UI.StandingWord(reaction)
    if not max or max <= 0 then return name end
    local muted = Theme:ColorCode(Theme:Opaque(Theme.color.muted, Theme.color.panel2))
    return name .. muted .. Theme.DOTS .. BreakUpLargeNumbers(value) .. " / " .. BreakUpLargeNumbers(max) .. "|r"
end

local function CreateRepBar(pane)
    local colors = Theme.color
    local native = Theme.native
    local height = native and 8 or 6
    local rep = CreateFrame("Frame", nil, pane)
    rep:SetSize(REP_WIDTH, height)
    rep:SetPoint("TOPLEFT", pane.subtitle, "BOTTOMLEFT", 0, native and -8 or -9)
    rep:Hide()

    local fill
    if native then
        local track = Theme:RoundedBarTexture(rep, "BACKGROUND", height / 2)
        track:SetVertexColor(unpack(Theme.nativeBar.track))
        track:SetAllPoints()
        fill = Theme:RoundedBarTexture(rep, "ARTWORK", height / 2)
    else
        Theme:Fill(rep, colors.line)
        fill = rep:CreateTexture(nil, "ARTWORK")
        fill:SetColorTexture(1, 1, 1, 1)
    end
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")

    rep.text = Theme:Text(rep, Theme.font.small)
    rep.text:SetPoint("LEFT", rep, "RIGHT", 10, 0)

    function rep:SetStanding(reaction, value, max)
        local filled = ns.UI.StandingProgress(value, max)
        -- A pill needs at least its own height to keep both round ends.
        local width = REP_WIDTH * filled
        if native and width > 0 then width = math.max(width, height) end
        fill:SetWidth(math.max(width, 0.01))
        fill:SetShown(width > 0)
        local color = native and ns.UI.StandingColor(reaction)
        if color then
            fill:SetVertexColor(color[1], color[2], color[3], Theme.nativeBar.fillAlpha)
        else
            fill:SetVertexColor(colors.accent[1], colors.accent[2], colors.accent[3], 1)
        end
        self.text:SetText(StandingText(reaction, value, max))
        Theme:SetTextColor(self.text, colors.text)
    end

    return rep
end

-- Boss portrait: the boss's model in the round ring the layout maps' boss
-- pins use (the Adventure Guide's pin ring, ns.UI.pinLook), with its level
-- in the target frame's small circle at the bottom right, a skull for "??".
-- Built in the target frame's units (a 58px portrait, the circle where the
-- target frame puts it) and scaled to fit. The box is the ring plus the
-- circle's overhang.
local PORTRAIT = 58
local RING = PORTRAIT * 40 / 29  -- the pin's 40px ring around its 29px portrait
local PBOX_LEFT, PBOX_RIGHT, PBOX_TOP, PBOX_BOTTOM = (RING - PORTRAIT) / 2, 13, (RING - PORTRAIT) / 2, 16
local PBOX_W, PBOX_H = PBOX_LEFT + PORTRAIT + PBOX_RIGHT, PBOX_TOP + PORTRAIT + PBOX_BOTTOM
RANK_NAMES = { elite = L["Elite"], worldboss = L["Boss"], rareelite = L["Rare Elite"], rare = L["Rare"] }

local function CreateBossPortrait(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(PBOX_W, PBOX_H)
    local portraitHolder = CreateFrame("Frame", nil, frame)
    portraitHolder:SetSize(PORTRAIT, PORTRAIT)
    portraitHolder:SetPoint("TOPLEFT", PBOX_LEFT, -PBOX_TOP)

    frame.portrait = portraitHolder:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.portrait:SetAllPoints()
    local mask = portraitHolder:CreateMaskTexture()
    mask:SetTexture(Theme.roundMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetPoint("TOPLEFT", 0, -1)
    mask:SetPoint("BOTTOMRIGHT", -1, 0)
    frame.portrait:AddMaskTexture(mask)

    -- Overview.lua (loaded after this file) sets pinLook; portraits are only built later.
    local look = ns.UI.pinLook
    frame.ring = portraitHolder:CreateTexture(nil, "ARTWORK")
    frame.ring:SetTexture(look.ring)
    frame.ring:SetTexCoord(unpack(look.coords))
    frame.ring:SetSize(RING, RING)
    frame.ring:SetPoint("CENTER")
    frame.circle = portraitHolder:CreateTexture(nil, "OVERLAY", nil, 1)
    frame.circle:SetAtlas("UI-HUD-UnitFrame-SmallCircle", true)
    frame.circle:SetPoint("BOTTOMRIGHT", portraitHolder, "BOTTOMRIGHT", 13, -16)
    frame.level = portraitHolder:CreateFontString(nil, "OVERLAY", nil)
    frame.level:SetFontObject(WhiteLargeNumberFont)
    frame.level:SetDrawLayer("OVERLAY", 2)
    frame.level:SetPoint("CENTER", frame.circle, "CENTER", 0, -0.5)
    frame.skull = portraitHolder:CreateTexture(nil, "OVERLAY", nil, 2)
    frame.skull:SetAtlas("UI-HUD-UnitFrame-Target-HighLevelTarget_Icon", true)
    frame.skull:SetPoint("CENTER", frame.circle, "CENTER")

    portraitHolder:EnableMouse(true)
    frame.hit = portraitHolder -- takes the portrait's mouse: its tooltip, and clicks where the pane wants them
    portraitHolder:SetScript("OnEnter", function(self)
        local boss = frame.boss
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(boss[1])
        local levelText = BossLevelText(boss) or RANK_NAMES[boss[4]]
        if levelText then GameTooltip:AddLine(levelText, unpack(Theme.tip.text)) end
        if Theme.showIds and boss[5] then
            GameTooltip:AddLine(L["NPC ID %s"]:format(boss[5]), unpack(Theme.tip.quiet))
        end
        if frame.hint then GameTooltip:AddLine(frame.hint, unpack(Theme.tip.quiet)) end
        GameTooltip:Show()
    end)
    portraitHolder:SetScript("OnLeave", GameTooltip_Hide)

    -- boss = { name, creature display ID, level (-1 for ??, nil unknown), rank, NPC ID }
    function frame:SetBoss(boss)
        self.boss = boss
        if boss[2] and boss[2] > 0 then
            SetPortraitTextureFromCreatureDisplayID(self.portrait, boss[2])
        else
            self.portrait:SetTexture("Interface\\EncounterJournal\\UI-EJ-BOSS-Default")
        end
        local level = boss[3]
        self.circle:SetShown(level ~= nil)
        self.skull:SetShown(level == -1)
        self.level:SetShown(level ~= nil and level ~= -1)
        if level and level ~= -1 then
            local color = GetCreatureDifficultyColor(level)
            self.level:SetText(level)
            self.level:SetTextColor(color.r, color.g, color.b)
        end
        self:Show()
    end

    return frame
end

-- /nr framedebug shows these next to the game's own frames.
ns.UI.CreateBossPortrait = CreateBossPortrait

-- Header layout with portraits: one boss sits left of the name; a council
-- shows a row of smaller portraits, each over its name, under the subtitle.
-- One table, so the pane's builder holds them as one upvalue.
local PORTRAIT_HEADER = {
    SINGLE_SCALE = 0.875,  -- 1.25x the first version's 0.7 (Mike)
    ROW_SCALE = 0.75,      -- 1.5x the first version's 0.5 (Mike)
    ROW_CELL = 84,         -- one council boss's column, portrait and name
    ROW_NAME = 13,         -- the name line under a council portrait
    ROW_GAP = 4,           -- between wrapped rows
    SINGLE_TOP = 6,        -- the single portrait's box from the pane's top
    SINGLE_TITLE_Y = 23,   -- the name's top beside it, centering name and subtitle on the portrait
    ROW_Y = 64,            -- the council row's top, under the subtitle
}
local TITLE_Y = 18          -- the name's top without a portrait

-- A rule fading in over its first tenth and out over its last, like the
-- Overview's section rules.
local function CreateRule(parent)
    local rule = CreateFrame("Frame", nil, parent)
    local function Part() return rule:CreateTexture(nil, "ARTWORK") end
    rule.fadeIn, rule.solid, rule.fadeOut = Part(), Part(), Part()
    rule.fadeIn:SetPoint("TOPLEFT")
    rule.fadeIn:SetPoint("BOTTOMLEFT")
    rule.fadeOut:SetPoint("TOPRIGHT")
    rule.fadeOut:SetPoint("BOTTOMRIGHT")
    rule.solid:SetPoint("TOPLEFT", rule.fadeIn, "TOPRIGHT")
    rule.solid:SetPoint("BOTTOMRIGHT", rule.fadeOut, "BOTTOMLEFT")
    function rule:SetColor(c)
        local solid, clear = CreateColor(c[1], c[2], c[3], c[4] or 1), CreateColor(c[1], c[2], c[3], 0)
        for _, tex in ipairs({ self.fadeIn, self.solid, self.fadeOut }) do tex:SetColorTexture(1, 1, 1, 1) end
        self.solid:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        self.fadeIn:SetGradient("HORIZONTAL", clear, solid)
        self.fadeOut:SetGradient("HORIZONTAL", solid, clear)
    end
    rule:SetScript("OnSizeChanged", function(self, w)
        self.fadeIn:SetWidth(w * 0.1)
        self.fadeOut:SetWidth(w * 0.1)
    end)
    return rule
end

-- A fold's row: the boss's portrait, its name, "Level 54 Elite  ·  4 items",
-- the open/shut arrow at the right and a rule along the bottom. A PvP class
-- fold has the class's badge in the portrait's place, the class's name in
-- its colour and "4 items" under it; "All classes" has no badge and a gold name.
local function CreateFold(parent)
    local row = Theme:Row(parent, FOLD_ROW)
    row.portrait = CreateBossPortrait(row)
    row.portrait:SetScale(FOLD_SCALE)
    -- The row takes the clicks; the portrait's tooltip would only repeat the row.
    row.portrait.hit:EnableMouse(false)
    row.portrait:SetPoint("LEFT", -2 / FOLD_SCALE, 0)
    local textX = PBOX_W * FOLD_SCALE + 6
    row.name = Theme:Text(row, Theme.font.section)
    row.name:SetPoint("TOPLEFT", textX, -6)
    row.sub = Theme:Text(row, Theme.font.small)
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.arrow = Theme:Arrow(row)
    row.arrow:SetPoint("RIGHT", -8, 0)
    row.rule = CreateRule(row)
    row.rule:SetPoint("BOTTOMLEFT")
    row.rule:SetPoint("BOTTOMRIGHT")
    row.rule:SetHeight(1)

    function row:ShowBoss(boss, items)
        if self.badge then self.badge:Hide() end
        self.portrait:Show()
        self.portrait:SetBoss(boss)
        self.name:SetText(Theme:WithIds(boss[1], BossIds(boss[5])))
        Theme:SetTextColor(self.name, Theme.color.heading)
        self.sub:SetText(Theme:JoinDots(BossLevelText(boss), items))
    end

    -- `token`: the class's ("MAGE"), or nil for "All classes".
    function row:ShowClass(token, items)
        self.portrait:Hide()
        if not self.badge then
            self.badge = Theme:ClassBadge(self, CLASS_FOLD.BADGE)
            self.badge:SetPoint("CENTER", self, "LEFT", CLASS_FOLD.BADGE_X, 0)
        end
        self.badge:SetClass(token) -- hidden for no class
        self.name:SetText(token and ns.UI.ClassName(token) or L["All classes"])
        Theme:SetTextColor(self.name, Theme.color.heading)
        ns.UI.SetClassColor(self.name, token)
        self.sub:SetText(items)
    end

    function row:Set(fold, open)
        self.fold = fold
        local items = fold.count == 1 and L["1 item"] or L["%d items"]:format(fold.count)
        if fold.classFold then
            self:ShowClass(fold.token, items)
        else
            self:ShowBoss(fold.boss, items)
        end
        self.arrow:SetOpen(open)
        self.rule:SetColor(Theme.color.rule)
        self.rule:SetHeight((select(2, Theme:LineWidth(self.rule)))) -- one screen pixel
    end

    return row
end

-- Where a cell's text ends with `fonts` when its name starts `top` down:
-- the name and two grey lines, 3 and 2 apart.
local function CellTextBottom(fonts, top)
    local _, nameSize = fonts.body:GetFont()
    local _, noteSize = fonts.small:GetFont()
    return top + nameSize + 3 + noteSize + 2 + noteSize
end

-- Gives a cell the fonts it draws with (Theme.font, or a smaller grid's set).
local function ApplyFonts(cell, fonts)
    cell.fonts = fonts
    cell.name:SetFontObject(fonts.body)
    cell.sub:SetFontObject(fonts.small)
    cell.sub2:SetFontObject(fonts.small)
    cell.rate:SetFontObject(fonts.rate or fonts.small)
    -- The icon is as tall as the text beside it.
    cell:SetIconSize(math.floor(CellTextBottom(fonts, 0) + 0.5))
    if cell.samples then cell.samples:SetFontObject(fonts.small) end
    if cell.descBox then cell.descBox.text:SetFontObject(fonts.body) end
end
ns.UI.ApplyCellFonts = ApplyFonts

-- Loot filters on boss pages and All drops: "Items I can use" (the
-- player's class's armor and weapon types, including ones learned later;
-- level hides nothing) and a pick of types to show (armor kinds, each
-- weapon type with shields, jewelry and trinkets). Quest items always
-- show. Saved per character in NeedRollDB.lootFilter.
-- "Items I can use" has three steps, a click moving to the next (Mike,
-- 2026-11-07): off, then grey out what the class can't use, then hide it.
local USABLE_GREY, USABLE_HIDE = "grey", "hide"
local NEXT_USABLE_STEP = { [false] = USABLE_GREY, [USABLE_GREY] = USABLE_HIDE, [USABLE_HIDE] = false }
ns.UI.USABLE_GREY, ns.UI.USABLE_HIDE = USABLE_GREY, USABLE_HIDE
local LOOT_TYPES = {
    { "cloth", L["Cloth"] }, { "leather", L["Leather"] }, { "mail", L["Mail"] }, { "plate", L["Plate"] },
    { "shield", L["Shields"] },
    { "axe1", L["One-Handed Axes"] }, { "axe2", L["Two-Handed Axes"] },
    { "mace1", L["One-Handed Maces"] }, { "mace2", L["Two-Handed Maces"] },
    { "sword1", L["One-Handed Swords"] }, { "sword2", L["Two-Handed Swords"] },
    { "dagger", L["Daggers"] }, { "fist", L["Fist Weapons"] }, { "polearm", L["Polearms"] },
    { "staff", L["Staves"] }, { "bow", L["Bows"] }, { "gun", L["Guns"] },
    { "crossbow", L["Crossbows"] }, { "thrown", L["Thrown"] }, { "wand", L["Wands"] },
    { "jewelry", L["Jewelry and Trinkets"] },
}
ns.UI.lootTypes = LOOT_TYPES
-- Weapon subclasses (item class 2) by the keys above.
local WEAPONS = { [0] = "axe1", [1] = "axe2", [2] = "bow", [3] = "gun", [4] = "mace1", [5] = "mace2",
    [6] = "polearm", [7] = "sword1", [8] = "sword2", [10] = "staff", [13] = "fist", [15] = "dagger",
    [16] = "thrown", [18] = "crossbow", [19] = "wand" }
local ARMOR = { [1] = "cloth", [2] = "leather", [3] = "mail", [4] = "plate", [6] = "shield" }
local JEWELRY = { INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true }
-- "a b c" -> { a = true, b = true, c = true }
local function KeySet(list)
    local set = {}
    for key in list:gmatch("%S+") do set[key] = true end
    return set
end
-- What each class can ever use (Classic proficiencies, those learned later included).
local CAN_USE = {
    WARRIOR = KeySet("cloth leather mail plate shield axe1 axe2 mace1 mace2 sword1 sword2 dagger fist polearm"
        .. " staff bow gun crossbow thrown"),
    PALADIN = KeySet("cloth leather mail plate shield axe1 axe2 mace1 mace2 sword1 sword2 polearm"),
    HUNTER = KeySet("cloth leather mail axe1 axe2 sword1 sword2 dagger fist polearm staff bow gun crossbow"
        .. " thrown"),
    ROGUE = KeySet("cloth leather mace1 sword1 dagger fist bow gun crossbow thrown"),
    PRIEST = KeySet("cloth mace1 dagger staff wand"),
    SHAMAN = KeySet("cloth leather mail shield axe1 axe2 mace1 mace2 dagger fist staff"),
    MAGE = KeySet("cloth sword1 dagger staff wand"),
    WARLOCK = KeySet("cloth sword1 dagger staff wand"),
    DRUID = KeySet("cloth leather mace1 mace2 dagger fist staff"),
}
-- The Class filter's list, in the game's order.
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- A class's name in the player's language ("Paladin" for "PALADIN" where
-- the game has no list of them).
function ns.UI.ClassName(token)
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token] or token:sub(1, 1) .. token:sub(2):lower()
end

-- Colours `fontString` in class `token`'s colour, as the game colours the
-- class; left as it is for a token the game has no colour for.
function ns.UI.SetClassColor(fontString, token)
    local color = token and C_ClassColor.GetClassColor(token)
    if color then fontString:SetTextColor(color.r, color.g, color.b) end
end

-- An item's type key (above), "quest" for a quest item, or nil when it's
-- none of them (cloaks, held-in-off-hand, bags, recipes...: shown always).
function ns.UI.LootType(itemID)
    if not itemID then return nil end
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    if classID == Enum.ItemClass.Questitem then return "quest" end
    if classID == Enum.ItemClass.Weapon then return WEAPONS[subclassID] end
    if classID == Enum.ItemClass.Armor then
        if JEWELRY[equipLoc] then return "jewelry" end
        if equipLoc == "INVTYPE_CLOAK" then return nil end
        return ARMOR[subclassID]
    end
end

-- Who wears each armor type, in the game's class order: the classes a
-- piece goes under in a PvP list's class folds (fewer than CAN_USE, which
-- lets a warrior wear cloth).
local WEARERS = {
    cloth = { "PRIEST", "MAGE", "WARLOCK" }, leather = { "ROGUE", "DRUID" }, mail = { "HUNTER", "SHAMAN" },
    plate = { "WARRIOR", "PALADIN" }, shield = { "WARRIOR", "PALADIN", "SHAMAN" },
}
-- The classes a loot entry is for, in the game's class order: the data's
-- `classes` ("ROGUE DRUID"), else armor's wearers (WEARERS) or the classes
-- that can use a weapon (CAN_USE); nil for anything else (cloaks, jewelry,
-- off-hand tomes, tabards, consumables, mounts). Instant item info, so it
-- is known before the item loads.
function ns.UI.ItemClasses(entry)
    local tokens = {}
    if entry.classes then
        for token in entry.classes:gmatch("%S+") do
            if CAN_USE[token] then table.insert(tokens, token) end
        end
        return tokens[1] and tokens or nil
    end
    local kind = ns.UI.LootType(entry.itemID)
    if not kind then return nil end
    if WEARERS[kind] then return WEARERS[kind] end
    for _, token in ipairs(CLASSES) do
        if CAN_USE[token][kind] then table.insert(tokens, token) end
    end
    return tokens[1] and tokens or nil
end

-- A PvP list's loot under a fold per class: { fold = true, classFold =
-- true, key = "CLASS:MAGE", token = "MAGE" } heading what that class can
-- use (an item several classes can use sits under each), in the game's
-- class order, then an "All classes" fold (no token) holding the rest.
-- nil when no item is for a class: the page lists its loot without folds.
function ns.UI.ClassFolds(loot)
    local itemsOf, forEveryone, hasClassItems = {}, {}, false
    for _, entry in ipairs(loot) do
        local classes = entry.itemID and ns.UI.ItemClasses(entry)
        for _, token in ipairs(classes or {}) do
            itemsOf[token] = itemsOf[token] or {}
            table.insert(itemsOf[token], entry)
            hasClassItems = true
        end
        if not classes then table.insert(forEveryone, entry) end
    end
    if not hasClassItems then return nil end
    local out = {}
    local function AddFold(fold, items)
        table.insert(out, fold)
        for _, entry in ipairs(items) do table.insert(out, entry) end
    end
    for _, token in ipairs(CLASSES) do
        if itemsOf[token] then
            AddFold({ fold = true, classFold = true, key = ns.UI.TierSets.ClassFoldKey(token), token = token },
                itemsOf[token])
        end
    end
    -- "All classes" is keyed like a class ("CLASS:MAGE"), its key its own.
    if forEveryone[1] then AddFold({ fold = true, classFold = true, key = "CLASS:ALL" }, forEveryone) end
    return out
end

-- The character's filter settings: { usable = USABLE_GREY, USABLE_HIDE or
-- nil (off), class = class token or nil (every class), types = { key = true } }
-- (no types picked: every type).
function ns.UI.LootFilter()
    if not ns.db then return { types = {} } end
    ns.db.lootFilter = ns.db.lootFilter or {}
    local key = ns.CharacterKey()
    ns.db.lootFilter[key] = ns.db.lootFilter[key] or { types = {} }
    local filter = ns.db.lootFilter[key]
    -- Saved before the grey step (v1.1.0), when "Items I can use" was a
    -- tick that hid them.
    if filter.usable == true then filter.usable = USABLE_HIDE end
    return filter
end

-- Whether an item's "Classes:" tooltip line (tier sets and other class
-- items) leaves out the class `token`; false when it has none or isn't
-- cached yet. The line is read once per item.
local classLines = {}

-- The separators the game puts between the class names on that line: a
-- comma on most clients, "、" (LIST_DELIMITER) on Chinese (simplified) and
-- "，" on Chinese (traditional) ones.
local CLASS_SEPARATORS = { ",", LIST_DELIMITER, PLAYER_LIST_DELIMITER }

-- The class names on a "Classes:" line, without the separators and spaces.
local function ClassNamesOn(classes)
    for _, separator in ipairs(CLASS_SEPARATORS) do
        local mark = separator:match("^%s*(.-)%s*$")
        if mark ~= "" then classes = classes:gsub((mark:gsub("%p", "%%%0")), ",") end
    end
    local names = {}
    for name in classes:gmatch("[^,]+") do table.insert(names, name:match("^%s*(.-)%s*$")) end
    return names
end

local function OtherClassOnly(itemID, token)
    if classLines[itemID] == nil then
        local lines = ns.Items.TooltipLines(itemID)
        if not lines then return false end
        local prefix = ITEM_CLASSES_ALLOWED:match("^(.-)%%s")
        classLines[itemID] = false
        for _, line in ipairs(lines) do
            local text = line.leftText
            if prefix and text and text:sub(1, #prefix) == prefix then
                classLines[itemID] = ClassNamesOn(text:sub(#prefix + 1))
            end
        end
    end
    local classes = classLines[itemID]
    if not classes then return false end
    local male = ns.UI.ClassName(token)
    local female = LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[token] or male
    for _, allowed in ipairs(classes) do
        if allowed == male or allowed == female then return false end
    end
    return true
end

-- Whether every class in `classes` (tokens) can use a loot entry of type
-- `kind` (ns.UI.LootType): armor and weapons a class can never use and
-- other classes' items are out; the character's level doesn't count.
local function UsableBy(entry, kind, classes)
    if kind == "quest" then return true end
    for _, token in ipairs(classes) do
        if OtherClassOnly(entry.itemID, token) then return false end
        if kind and kind ~= "jewelry" and not CAN_USE[token][kind] then return false end
    end
    return true
end

-- Whether a loot entry of type `kind` shows under the ticked `types` and
-- the classes whose unusable items are hidden (`hiddenFor`).
local function Shows(entry, kind, types, hiddenFor)
    -- Types ticked: those types alone (Mike, 2026-10-16), quest items,
    -- off-hands, cloaks and the rest left out too.
    if next(types) and not (kind and types[kind]) then return false end
    return UsableBy(entry, kind, hiddenFor)
end

-- `entries` (a loot page's, with section headers and boss folds) with what
-- the filters hide left out, and the headers and folds left empty.
-- "Items I can use" (the character's class) and the Class filter (the
-- picked class) hide what that class can't use; at its grey step, "Items I
-- can use" keeps those items, listed in the copy's `greyed` set instead.
function ns.UI.FilterLoot(entries)
    local filter = ns.UI.LootFilter()
    local _, class = UnitClass("player")
    local hiddenFor = {}
    if filter.usable == USABLE_HIDE and CAN_USE[class] then table.insert(hiddenFor, class) end
    if filter.class and CAN_USE[filter.class] and filter.class ~= hiddenFor[1] then
        table.insert(hiddenFor, filter.class)
    end
    local greyedFor = filter.usable == USABLE_GREY and CAN_USE[class] and { class } or nil
    if #hiddenFor == 0 and not greyedFor and not next(filter.types) then return entries end
    local out, pending = { greyed = {} }, {}
    for _, entry in ipairs(entries) do
        local kind = entry.itemID and ns.UI.LootType(entry.itemID)
        if entry.header or entry.fold or entry.gap then
            -- A heading waits for an item under it.
            if entry.fold then pending = {} end
            table.insert(pending, entry)
        elseif not entry.itemID or Shows(entry, kind, filter.types, hiddenFor) then
            for _, heading in ipairs(pending) do table.insert(out, heading) end
            pending = {}
            table.insert(out, entry)
            if greyedFor and entry.itemID and not UsableBy(entry, kind, greyedFor) then out.greyed[entry] = true end
        end
    end
    return out
end

-- A dungeon's or raid's "All drops": every item its bosses and trash drop,
-- each once, with where it comes from. Built once per instance.
local allDrops = {}
function ns.UI.AllDrops(instance)
    if allDrops[instance] then return allDrops[instance] end
    local allDropsEncounter = { id = "ALL_DROPS", name = L["All drops"], allDrops = true, loot = {} }
    local byItem, bossesOf = {}, {}
    for _, encounter in ipairs(instance.encounters) do
        local drops = not encounter.overview and encounter.loot or {} -- the Overview page has no drops of its own
        for _, item in ipairs(drops) do
            if item.itemID then
                local drop = byItem[item.itemID]
                if not drop then
                    -- Its first drop, copied without the boss. Its bosses are
                    -- kept aside: an entry's `from` is a source to link (see
                    -- SourceLinkText), not a list of names.
                    drop = {}
                    for key, value in pairs(item) do drop[key] = value end
                    drop.boss = nil
                    byItem[item.itemID] = drop
                    bossesOf[drop] = {}
                    table.insert(allDropsEncounter.loot, drop)
                end
                local bosses = bossesOf[drop]
                if bosses[#bosses] ~= encounter.name then table.insert(bosses, encounter.name) end
            end
        end
    end
    for _, drop in ipairs(allDropsEncounter.loot) do drop.source = table.concat(bossesOf[drop], ", ") end
    allDrops[instance] = allDropsEncounter
    return allDropsEncounter
end

-- The loot grid's fonts drawn at `zoom` (its canvas scaled by that): its
-- text keeps sizes of its own against the full-size grid: headings at full
-- size, names a touch bigger (16pt in the grid's units at 80%), drop chances
-- at 90%, and the grey lines under the names 12.5% smaller than the names
-- (Mike's font debug sizes). Made once per skin and zoom; quest rewards use
-- them too, to look like boss drops.
local gridFonts = {}
function ns.UI.LootGridFonts(zoom)
    if zoom == 1 then return Theme.font end
    local HEADING_SIZE, NAME_SIZE, NOTE_OF_NAME, RATE_SIZE = 1, 16 * 0.8 / 12, 0.875, 0.9
    gridFonts[Theme.font] = gridFonts[Theme.font] or {}
    if gridFonts[Theme.font][zoom] then return gridFonts[Theme.font][zoom] end
    local baseFonts = Theme.font
    local _, bodySize = baseFonts.body:GetFont()
    local _, smallSize = baseFonts.small:GetFont()
    local noteSize = NAME_SIZE * NOTE_OF_NAME * bodySize / smallSize
    local fonts = {
        body = Theme:ScaledFont(baseFonts.body, NAME_SIZE / zoom),
        small = Theme:ScaledFont(baseFonts.small, noteSize / zoom),
        rate = Theme:ScaledFont(baseFonts.small, RATE_SIZE / zoom), -- a drop chance, price or count
        label = Theme:ScaledFont(baseFonts.label, HEADING_SIZE / zoom),
        factLabel = Theme:ScaledFont(baseFonts.factLabel, HEADING_SIZE / zoom),
        section = Theme:ScaledFont(baseFonts.section, HEADING_SIZE / zoom),
    }
    gridFonts[Theme.font][zoom] = fonts
    return fonts
end

-- A loot grid row's height with `fonts`: the cell's text, 7 above and 6
-- below.
function ns.UI.LootRowHeight(fonts)
    return math.max(Size.itemRow, math.ceil(CellTextBottom(fonts, 7) + 6))
end

local function ShowHintAtCursor(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:SetText(text)
    GameTooltip:Show()
end

-- The `index`th widget of `pool`, built by `create` the first time.
local function FromPool(pool, index, create)
    local widget = pool[index]
    if not widget then
        widget = create()
        pool[index] = widget
    end
    return widget
end

-- A boss's quests (pane:SetRelatedQuests), under the subtitle: links that
-- open each one.
local function CreateRelatedQuests(pane)
    local related = CreateFrame("Frame", nil, pane)
    related:SetPoint("TOPLEFT", pane.subtitle, "BOTTOMLEFT", 0, -6)
    related:SetPoint("RIGHT", -Size.pad, 0)
    related:SetHeight(16)
    related.text = Theme:Text(related, Theme.font.small)
    related.text:SetPoint("LEFT")
    related.text:SetPoint("RIGHT")
    related.text:SetJustifyH("LEFT")
    related:SetHyperlinksEnabled(true)
    related:SetScript("OnHyperlinkClick", function(self, link)
        local i = tonumber(link:match("^needroll:related:(%d+)"))
        local quest = i and self.quests and self.quests[i]
        if not quest then return end
        GameTooltip:Hide()
        ns.UI:PushBack(ns.UI:Place())
        ns.UI:SelectQuest(quest)
    end)
    related:SetScript("OnHyperlinkEnter", function(self) ShowHintAtCursor(self, L["Click to open this quest"]) end)
    related:SetScript("OnHyperlinkLeave", GameTooltip_Hide)
    related:Hide()
    return related
end

-- Boss `bossID` of `instance` (not the one open), from a spoiler's link:
-- that instance opens on its tab, the boss lit on its map (its page when
-- unpinned). One Back returns to the spoiler's page. Nil `instance` (a
-- link naming one NeedRoll doesn't list): nothing happens.
local function ShowBossInOtherInstance(instance, bossID)
    if not instance then return end
    for _, encounter in ipairs(instance.encounters) do
        if encounter.id == bossID then
            return ns.UI:ShowInDungeon(instance, function()
                if ns.UI:ShowBossOnMap(encounter) == false then ns.UI:SelectEncounter(encounter) end
            end)
        end
    end
end

-- A boss's secret (pane:SetSpoiler): "How to summon (spoiler)" under the
-- subtitle (and its quests), shown in full only once clicked.
local function CreateSpoiler(pane)
    local spoiler = CreateFrame("Frame", nil, pane)
    spoiler:SetPoint("RIGHT", -Size.pad, 0)
    spoiler.text = Theme:Text(spoiler, Theme.font.small)
    spoiler.text:SetPoint("TOPLEFT")
    spoiler.text:SetPoint("RIGHT")
    spoiler.text:SetJustifyH("LEFT")
    spoiler.text:SetWordWrap(true)
    spoiler:EnableMouse(true)
    spoiler:SetHyperlinksEnabled(true)
    spoiler:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end  -- right-click is Back
        self.open = not self.open
        pane:DrawSpoiler()
    end)
    spoiler:SetScript("OnEnter", function(self)
        if not self.open then ShowHintAtCursor(self, L["Click to show it"]) end
    end)
    spoiler:SetScript("OnLeave", GameTooltip_Hide)
    spoiler:SetScript("OnHyperlinkEnter", function(self, link)
        local inside = link:match("^needroll:inside:(.+)")
        if inside then
            -- Out of combat a click on it then runs the game's /mappin, as
            -- every map link does (UI.HoverMapLink in UI/MainFrame.lua).
            local function ShowPinHint() ShowHintAtCursor(self, L["Click to pin the entrance on your map"]) end
            ShowPinHint()
            ns.UI.HoverMapLink(self, SourceSpot({ inside = inside }), nil, ShowPinHint)
        elseif link:match("^needroll:boss:") then
            ShowHintAtCursor(self, L["Click to see this boss on the map"])
        elseif link:match("^needroll:quest:") then
            ShowHintAtCursor(self, L["Click to open this quest"])
        else
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end
    end)
    spoiler:SetScript("OnHyperlinkLeave", function(self)
        GameTooltip:Hide()
        ns.UI.LeaveMapLink(self)
    end)
    spoiler:SetScript("OnHyperlinkClick", function(_, link, text, button)
        -- A boss or creature in the secret: shown on the instance's map, or
        -- on the map of the other instance the link names.
        local boss, otherID = link:match("^needroll:boss:([^:]+):?(.*)")
        if boss and otherID ~= "" then return ShowBossInOtherInstance(ns.Data:Get(otherID), boss) end
        if boss then return ns.UI:ShowBossOnMap({ id = boss }) end
        -- A dungeon, clicked in combat (out of combat the game's /mappin
        -- took the click): NeedRoll's own pin on its entrance.
        local inside = link:match("^needroll:inside:(.+)")
        if inside then return ns.UI.ShowOnMap(SourceSpot({ inside = inside })) end
        -- A quest: its page.
        local id = tonumber(link:match("^needroll:quest:(%d+)") or "")
        local instance = ns.UI.state.instance
        local quest = id and instance and ns.Data:DungeonQuest(instance.id, id)
        if quest then
            ns.UI:PushBack(ns.UI:Place())
            return ns.UI:SelectQuest(quest)
        end
        if not id then SetItemRef(link, text, button) end
    end)
    spoiler:Hide()
    return spoiler
end

-- A filter button's list: a solid rounded card of check buttons under it,
-- outlined like the pills (dark-filled in the native skin, whose panes are
-- see-through), and a pill that clears it. `choices`: { key, label } pairs.
local function CreateCheckCard(bar, button, width, choices, clearLabel)
    local card = CreateFrame("Frame", nil, bar)
    card:SetFrameStrata("DIALOG")
    card:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -4)
    card:SetSize(width, 12 + #choices * 20 + 32)
    Theme:Rounded(card, Theme.native and { 0.09, 0.075, 0.06, 1 } or Theme:Opaque(Theme.color.panel2, Theme.color.bg),
        Theme.color.pillEdge)
    card:EnableMouse(true)
    card:Hide()
    card.checks = {}
    for i, choice in ipairs(choices) do
        local check = CreateFrame("CheckButton", nil, card, "UICheckButtonTemplate")
        check:SetSize(20, 20)
        check:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 20)
        check.key = choice[1]
        check.label = Theme:Text(check, Theme.font.small)
        check.label:SetPoint("LEFT", check, "RIGHT", 2, 1)
        check.label:SetText(choice[2])
        card.checks[i] = check
    end
    card.clear = Theme:Pill(card)
    card.clear:SetLabel(clearLabel)
    card.clear:SetPoint("BOTTOM", 0, 8)
    return card
end

-- A filter button's tooltip: its name, what it does, and how to clear it.
local function AddFilterTooltip(button, title, about, clearHint)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine(title)
        local r, g, b = unpack(Theme.tip.text)
        if about then GameTooltip:AddLine(about, r, g, b, true) end
        GameTooltip:AddLine(clearHint, unpack(Theme.tip.hint))
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", GameTooltip_Hide)
end

-- The "Items I can use" box: the game's check box with an X drawn in it,
-- grey at the grey step and red at the hide step, empty when off. A click
-- moves to the next step and calls `onStep(step)`; box:SetStep(step) shows
-- a step without a call.
local USABLE_X_LENGTH, USABLE_X_THICKNESS = 12, 2
local function UsableTooltipText(step)
    if step == USABLE_GREY then return L["Greying out items your class can't use. Click to hide them."] end
    if step == USABLE_HIDE then return L["Hiding items your class can't use. Click to show them again."] end
    return L["Click to grey out items your class can't use, and again to hide them."]
end

local function ShowUsableTooltip(box)
    GameTooltip:SetOwner(box, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine(L["Items I can use"])
    local r, g, b = unpack(Theme.tip.text)
    GameTooltip:AddLine(UsableTooltipText(box.step), r, g, b, true)
    GameTooltip:Show()
end

local function CreateUsableBox(parent, onStep)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(22, 22)
    -- The game's tick never shows: the X below marks the step.
    box:GetCheckedTexture():SetAlpha(0)
    box.strokes = {}
    for i, angle in ipairs({ 45, -45 }) do
        local stroke = box:CreateTexture(nil, "OVERLAY")
        stroke:SetColorTexture(1, 1, 1, 1)
        stroke:SetSize(USABLE_X_LENGTH, USABLE_X_THICKNESS)
        stroke:SetPoint("CENTER")
        stroke:SetRotation(math.rad(angle))
        box.strokes[i] = stroke
    end
    box.label = Theme:Text(box, Theme.font.small)
    box.label:SetPoint("LEFT", box, "RIGHT", 2, 1)
    box.label:SetText(L["Items I can use"])

    function box:SetStep(step)
        self.step = step or false
        self:SetChecked(self.step ~= false)
        -- Grey (the tooltips' quiet grey), or red (a "Clear list" pill's
        -- about-to-clear red) to hide.
        local color = self.step == USABLE_HIDE and Theme.color.incomplete or Theme.tip.quiet
        for _, stroke in ipairs(self.strokes) do
            stroke:SetVertexColor(color[1], color[2], color[3], 1)
            stroke:SetShown(self.step ~= false)
        end
        if GameTooltip:IsOwned(self) then ShowUsableTooltip(self) end
    end
    box:SetScript("OnClick", function(self)
        self:SetStep(NEXT_USABLE_STEP[self.step])
        onStep(self.step or nil)
    end)
    box:SetScript("OnEnter", ShowUsableTooltip)
    box:SetScript("OnLeave", GameTooltip_Hide)
    box:SetStep(false)
    return box
end

-- A boss page's loot filters, at the header's right (pane:ShowFilters):
-- "Items I can use", a Class button opening a list to pick one from (Mike),
-- and a Types button opening a list to tick. The buttons are NeedRoll's own
-- gold-outlined pills (as Back), not the game's red ones.
local function CreateFilterBar(pane)
    local bar = CreateFrame("Frame", nil, pane)
    bar:SetSize(300, 24)
    bar:SetPoint("TOPRIGHT", -Size.pad, -12)
    bar.types = Theme:Pill(bar)
    bar.types:SetLabel(L["Types"])
    bar.types:SetPoint("RIGHT")
    bar.class = Theme:Pill(bar)
    bar.class:SetLabel(L["Class"])
    bar.class:SetPoint("RIGHT", bar.types, "LEFT", -6, 0)
    bar.usable = CreateUsableBox(bar, function(step)
        ns.UI.LootFilter().usable = step
        ns.UI:Refresh()
    end)
    bar.usable:SetPoint("RIGHT", bar.class, "LEFT", -6 - 100, 0)

    -- The types list: tick any number of them.
    local list = CreateCheckCard(bar, bar.types, 200, ns.UI.lootTypes, L["Show all"])
    for _, check in ipairs(list.checks) do
        check:SetScript("OnClick", function(self)
            ns.UI.LootFilter().types[self.key] = self:GetChecked() and true or nil
            ns.UI:Refresh()
        end)
    end
    local function ClearTypes()
        wipe(ns.UI.LootFilter().types)
        for _, check in ipairs(list.checks) do check:SetChecked(false) end
        ns.UI:Refresh()
    end
    list.clear:SetScript("OnClick", ClearTypes)
    bar.list = list
    -- Right-click clears every ticked type, as Show all does (Mike), and
    -- isn't the pane's right-click Back.
    bar.types:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bar.types.keepsRightClick = true
    bar.types:SetScript("OnClick", function(_, button)
        if button == "RightButton" then return ClearTypes() end
        list:SetShown(not list:IsShown())
    end)
    AddFilterTooltip(bar.types, L["Types"], nil, L["Right-click to clear filters"])
    bar.types:HookScript("OnClick", function() bar.classList:Hide() end)

    -- The class list: one class at a time (picking the picked one again,
    -- All classes or a right-click on the button clears it), each in its
    -- class color.
    local classChoices = {}
    for i, token in ipairs(CLASSES) do classChoices[i] = { token, ns.UI.ClassName(token) } end
    local classList = CreateCheckCard(bar, bar.class, 160, classChoices, L["All classes"])
    local function PickClass(token)
        local filter = ns.UI.LootFilter()
        filter.class = token ~= filter.class and token or nil
        classList:Hide()
        ns.UI:Refresh()
    end
    for _, check in ipairs(classList.checks) do
        local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[check.key]
        if color then check.label:SetTextColor(color.r, color.g, color.b) end
        check:SetScript("OnClick", function(self) PickClass(self.key) end)
    end
    classList.clear:SetScript("OnClick", function() PickClass(nil) end)
    bar.classList = classList
    bar.class:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bar.class.keepsRightClick = true
    bar.class:SetScript("OnClick", function(_, button)
        if button == "RightButton" then return PickClass(nil) end
        list:Hide()
        classList:SetShown(not classList:IsShown())
    end)
    AddFilterTooltip(bar.class, L["Class"], L["Shows only what one class can use"], L["Right-click to clear filters"])
    bar:Hide()

    -- Shows the filters as this character saved them, or hides them.
    function pane:ShowFilters(on)
        local filter = ns.UI.LootFilter()
        bar:SetShown(on)
        if not on then
            list:Hide()
            classList:Hide()
            return
        end
        bar.usable:SetStep(filter.usable)
        local picked = 0
        for _, check in ipairs(list.checks) do
            check:SetChecked(filter.types[check.key] or false)
            if filter.types[check.key] then picked = picked + 1 end
        end
        bar.types:SetLabel(picked > 0 and L["Types (%d)"]:format(picked) or L["Types"])
        for _, check in ipairs(classList.checks) do check:SetChecked(filter.class == check.key) end
        bar.class:SetLabel(filter.class and ns.UI.ClassName(filter.class) or L["Class"])
        -- The title stops short of the filters.
        self.title:SetPoint("RIGHT", bar, "LEFT", -8, 0)
    end
    return bar
end

-- Where a fold's open or shut state is remembered, by what key, and
-- whether it is open before the player opens or shuts it: the arguments of
-- ns.SectionMemory.IsOpen and Toggle.
-- A boss fold: in pane.open by its boss's NPC ID (Data/Bosses.lua's fifth
-- field), not its place in the encounter (`key`, what portraits and search
-- results open it by); it starts shut.
-- A PvP class fold: in pane.openClasses by its key ("CLASS:MAGE"), the same
-- on every PvP page, so a class opened on one page is open on all; the
-- player's own class and "All classes" start open.
local function FoldMemory(pane, fold)
    if not fold.classFold then return pane.open, fold.boss[5], false end
    local isOpenAtFirst = fold.token == nil or fold.key == ns.UI.TierSets.PlayerFoldKey()
    return pane.openClasses, fold.key, isOpenAtFirst
end

-- Whether fold `fold` shows its items on `pane`.
local function IsFoldOpen(pane, fold)
    return ns.SectionMemory.IsOpen(FoldMemory(pane, fold))
end

function ns.UI.CreateLootGrid(parent)
    local pane = Theme:CreatePanel(parent, "loot")
    pane.cells = {}
    pane.sections = {}
    pane.folds = {}
    pane.boxLabels = {}
    pane.toggles = {}
    pane.boxes = {}
    -- Loot sections shut or opened (section key -> true or false, read
    -- through IsSectionShut), and boss folds and PvP class folds opened or
    -- shut (see FoldMemory), kept as Settings' "Remember sections" says
    -- (ns.SectionMemory's "loot", "bosses" and "lootClasses" areas).
    local function TakeMemory()
        pane.shutSections = ns.SectionMemory.Area("loot")
        pane.open = ns.SectionMemory.Area("bosses")
        pane.openClasses = ns.SectionMemory.Area("lootClasses")
    end
    TakeMemory()
    ns.SectionMemory.OnModeChange(function()
        TakeMemory()
        if pane:IsVisible() then pane:Refresh() end
    end)
    pane.entries = {}

    pane.title = Theme:Text(pane, Theme.font.heading)
    pane.title:SetPoint("TOPLEFT", Size.pad + 4, -TITLE_Y)
    pane.title:SetJustifyH("LEFT")
    pane.subtitle = Theme:Text(pane, Theme.font.small)
    pane.subtitle:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -6)
    pane.top = HEADER_HEIGHT
    pane.header = HEADER_HEIGHT
    pane.rep = CreateRepBar(pane)
    pane.related = CreateRelatedQuests(pane)
    pane.spoiler = CreateSpoiler(pane)
    pane.filterBar = CreateFilterBar(pane)
    pane.portraits = {}
    pane.portraitNames = {}
    -- The grid is drawn on a canvas clipped below the header, so lines
    -- gliding past the edges are cut off there.
    local canvas = Theme:ScrollView(pane, pane.top, Size.scrollBottom)
    -- The grid can be drawn smaller (pane:SetZoom): the canvas is scaled, so
    -- the pane's sizes and margins are turned into its units.
    local zoom = 1
    local function ToCanvas(x) return x / zoom end
    -- Its text, though, keeps sizes of its own (ns.UI.LootGridFonts).
    pane.fonts = Theme.font

    local function CellWidth()
        return (ToCanvas(pane:GetWidth() - Size.pad * 2) - GAP * (COLUMNS - 1)) / COLUMNS
    end
    -- A cell alone on its line spans the columns.
    local function FullWidth()
        return ToCanvas(pane:GetWidth() - Size.pad * 2)
    end

    -- Height an ability's description adds to its card, its text
    -- wrapped to the width SetAbility gives it.
    local measure = Theme:Text(pane, Theme.font.body)
    measure:SetWordWrap(true)
    measure:Hide()
    -- Measured once per entry, width and font; a resize or a skin change
    -- measures again.
    local abilityHeights = setmetatable({}, { __mode = "k" })
    local function AbilityHeight(entry, wide)
        local text = AbilityText(entry)
        if text == "" then return 0 end
        local width = (wide and FullWidth() or CellWidth()) - ABILITY_PAD * 4
        local known = abilityHeights[entry]
        if known and known.width == width and known.font == pane.fonts.body and known.text == text then
            return known.height
        end
        measure:SetFontObject(pane.fonts.body)
        measure:SetWidth(width)
        measure:SetText(text)
        local box = math.ceil(measure:GetStringHeight()) + ABILITY_PAD * 2
        local height = math.max(0, ABILITY_BOX_TOP + box + ABILITY_PAD - Size.itemRow)
        abilityHeights[entry] = { width = width, font = pane.fonts.body, text = text, height = height }
        return height
    end

    -- How the entries fit the pane, so no name or line is cut off: nil
    -- when they fit two to a line, "wide" for one to a line across the
    -- pane, "stacked" for one to a line with the chance or price moved to
    -- the cell's last text line. Each entry's width is measured once, on a
    -- hidden cell filled like the ones on show; resizing only compares.
    local probe = CreateCell(pane)
    probe:Hide()
    local needs
    local function ForgetNeeds()
        needs = { [true] = setmetatable({}, { __mode = "k" }), [false] = setmetatable({}, { __mode = "k" }) }
    end
    ForgetNeeds()
    local fitNeed
    -- An item still loading is measured once it has loaded: the grid is
    -- laid out again then (once for the items arriving in a frame).
    local waiting, relayout = {}, false -- item ID -> true while it loads
    local function Loaded(itemID)
        waiting[itemID] = nil
        fitNeed = nil
        if relayout then return end
        relayout = true
        C_Timer.After(0, function()
            relayout = false
            if pane:IsVisible() and pane.entries then pane:Refresh() end
        end)
    end
    -- A look collected or lost: the ticks are drawn again, and names with
    -- a tick measured again (once for a burst of changes).
    local transmogPending = false
    local function TransmogChanged()
        if transmogPending then return end
        transmogPending = true
        C_Timer.After(0.5, function()
            transmogPending = false
            pane:Remeasure()
            if pane:IsVisible() and pane.entries then pane:Refresh() end
        end)
    end
    ns:On("TRANSMOG_COLLECTION_UPDATED", TransmogChanged)
    ns:On("TRANSMOG_COLLECTION_SOURCE_ADDED", TransmogChanged)
    ns:On("TRANSMOG_COLLECTION_SOURCE_REMOVED", TransmogChanged)
    -- How wide a cell must be to show `entry` uncut (0 while it loads).
    local function Need(entry, showSource)
        local cache = needs[showSource == true]
        if cache[entry] then return cache[entry] end
        if entry.itemID and waiting[entry.itemID] then return 0 end -- still loading
        probe.stacked = nil
        probe:SetEntry(entry, showSource)
        if probe.name:GetText() == L["Loading..."] then
            waiting[entry.itemID] = true
            ns.Items:Load(entry.itemID, Loaded)
            return 0
        end
        local nameWidth = (probe.nameWraps and TwoLineWidth(probe.name) or probe.name:GetUnboundedStringWidth())
            + probe.tickRoom
        local textWidth = math.max(nameWidth, probe.sub:GetUnboundedStringWidth(),
            probe.sub2:GetUnboundedStringWidth())
        local rightWidth = probe.rate:GetUnboundedStringWidth()
        if probe.samples and probe.samples:IsShown() then
            rightWidth = math.max(rightWidth, probe.samples:GetUnboundedStringWidth())
        end
        local need = probe.textLeft + textWidth + (rightWidth > 0 and TEXT_GAP + rightWidth or 0)
            + (probe.searchRow and GO_ROOM or TEXT_RIGHT) + probe.starRoom
        cache[entry] = need
        return need
    end
    local function Mode(need)
        if need <= CellWidth() - BOX.INSET * 2 then return nil end
        return need <= FullWidth() - BOX.INSET * 2 and "wide" or "stacked"
    end
    -- While a page's items are still loading, it keeps the last page's
    -- layout if that was narrower, so it isn't first drawn two to a line
    -- and then redrawn one to a line as the names arrive.
    local RANK = { wide = 1, stacked = 2 }
    -- Only until the window is resized: an item that never loads would
    -- otherwise hold the page narrow for good.
    local fitFor, fitSkin, lastFit, openWidth
    local function Fit()
        if fitFor == pane.entries and fitSkin == pane.fonts and fitNeed then
            lastFit = Mode(fitNeed)
            return lastFit
        end
        local need, loading = 0, false
        for _, entry in ipairs(pane.entries) do
            if not (entry.header or entry.gap or entry.fold or entry.ability) then
                local entryNeed = Need(entry, pane.showSource)
                loading = loading or entryNeed == 0
                need = math.max(need, entryNeed)
            end
        end
        -- Items still loading are measured on the next redraw.
        if fitFor ~= pane.entries then openWidth = pane:GetWidth() end
        fitFor, fitSkin, fitNeed = pane.entries, pane.fonts, not loading and need or nil
        local mode = Mode(need)
        if loading and pane:GetWidth() == openWidth and (RANK[lastFit] or 0) > (RANK[mode] or 0) then
            mode = lastFit
        end
        lastFit = mode
        return mode
    end

    -- Entries packed into lines: a section label takes a line of its own
    -- and starts the next items on a fresh line. Lines of a boxed section
    -- share its `box` ({ columns = how many its items fill }), and its last
    -- line is marked `last`.
    local function Lines()
        -- `line`: the item line being filled; `box`: its boxed section;
        -- `shut`: in a shut fold; `folded`: in a shut loot section.
        local lines, line, box, shut, folded = {}, nil, nil, false, false
        local fit = Fit()
        local wide = fit ~= nil

        local function AddHeader(entry)
            line, folded = nil, false
            if entry.shuts then
                -- A loot section, shut by its arrow: its label alone.
                folded = IsSectionShut(pane.shutSections, entry.sectionKey)
                box = { columns = COLUMNS }
                table.insert(lines, { header = entry.header, sectionKey = entry.sectionKey, box = box, shuts = true,
                    closed = folded })
            elseif wide then
                -- One to a line: a pair's second heading starts a box of
                -- its own after the first item.
                box = entry.box and { columns = COLUMNS, next = entry.header2 } or nil
                table.insert(lines, { header = entry.header, box = box })
            else
                local columns = (entry.header2 or entry.full) and COLUMNS or 1
                box = entry.box and { columns = columns, pair = entry.header2 ~= nil } or nil
                table.insert(lines, { header = entry.header, header2 = entry.header2, box = box })
            end
        end

        local function AddItem(entry)
            -- One to a line, a pair's second heading comes after its first item.
            if box and box.next and box.items then
                local secondHeading = box.next
                box = { columns = COLUMNS }
                table.insert(lines, { header = secondHeading, box = box })
                line = nil
            end
            if box then box.items = true end
            if not line or #line == (wide and 1 or COLUMNS) then
                line = { box = box, extra = 0, wide = wide or nil, stacked = fit == "stacked" or nil }
                table.insert(lines, line)
            end
            table.insert(line, entry)
            if entry.ability then
                line.extra = math.max(line.extra, AbilityHeight(entry, wide))
            elseif not pane.showSource or entry.buyFrom or entry.quests then
                -- A page that names each item's source on its own line
                -- (search, a dungeon's All drops) shows no source lines
                -- under its items, except a search result's vendors and
                -- the quests rewarding its item.
                line.extra = math.max(line.extra, SourcesHeight(entry, pane.rowHeight or Size.itemRow))
            end
            if box then box.columns = math.max(box.columns, wide and COLUMNS or #line) end
        end

        for _, entry in ipairs(pane.entries) do
            if entry.gap then
                if not shut then table.insert(lines, { gap = entry.gap }) end
                line, box, folded = nil, nil, false
            elseif entry.fold then
                -- A shut fold's items take no lines.
                table.insert(lines, { fold = entry })
                line, box, shut, folded = nil, nil, not IsFoldOpen(pane, entry), false
            elseif entry.header and not shut then
                AddHeader(entry)
            elseif not (shut or folded) then
                AddItem(entry)
            end
        end
        for i, packed in ipairs(lines) do
            local nextLine = lines[i + 1]
            packed.last = packed.box ~= nil and (not nextLine or nextLine.box ~= packed.box)
        end
        return lines
    end

    -- A shut loot section's box: its label with 10 above and below.
    local function ShutHeight()
        local _, size = Theme.font.factLabel:GetFont()
        return 20 + ToCanvas(size)
    end

    local function LineHeight(line)
        if line.gap then return line.gap end
        if line.fold then return FOLD_HEIGHT end
        if line.header then
            if not line.box then return SECTION_HEIGHT end
            return (line.closed and ShutHeight() or BOX.HEAD) + (line.last and BOX.GAP or 0)
        end
        if line.last then return (pane.rowHeight or Size.itemRow) + line.extra + BOX.BOTTOM + BOX.GAP end
        return (pane.rowHeight or Size.itemRow) + line.extra + GAP
    end

    -- Space after a line that the pane needn't fit: the gap under an item
    -- line, or under a whole box.
    local function Trailing(line)
        if line.gap then return line.gap end
        if line.fold then return FOLD_HEIGHT - FOLD_ROW end
        if line.header then return line.last and BOX.GAP or 0 end
        return line.last and BOX.GAP or GAP
    end

    -- The scroll limit: the first line from which the rest all fit.
    -- `lines` when they are already packed, else they are packed here.
    local function MaxOffset(lines)
        lines = lines or Lines()
        local room, need = ToCanvas(pane:GetHeight() - pane.top - Size.pad), 0
        for i = #lines, 1, -1 do
            local lineHeight = LineHeight(lines[i])
            if i == #lines then lineHeight = lineHeight - Trailing(lines[i]) end
            if need + lineHeight > room then return i end
            need = need + lineHeight
        end
        return 0
    end

    local function NewCell()
        local cell = CreateCell(canvas)
        cell.pane = pane -- for its "N more trainers" line
        -- Above the stat box backdrops, with its buttons above it.
        cell:SetFrameLevel(canvas:GetFrameLevel() + 2)
        for _, button in ipairs({ cell.jump, cell.go, cell.star }) do button:SetFrameLevel(cell:GetFrameLevel() + 2) end
        ApplyFonts(cell, pane.fonts)
        table.insert(pane.cells, cell)
        return cell
    end

    -- Each full redraw gets a new stamp. A cell drawn under the current one
    -- is up to date, so while the grid only scrolls it just moves.
    local stamp = 0

    -- What the grid draws besides cells, each kind pooled on the pane.
    local function NewFoldRow()
        local row = CreateFold(canvas)
        row:SetFrameLevel(canvas:GetFrameLevel() + 2)
        row.name:SetFontObject(pane.fonts.section)
        row.sub:SetFontObject(pane.fonts.small)
        row:SetScript("OnClick", function(self) pane:ToggleFold(self.fold) end)
        return row
    end

    -- Boxed sections' labels, in the Overview stat box font. They sit on a
    -- layer above the boxes, whose fill would otherwise dim them.
    local function NewBoxLabel()
        if not pane.labelLayer then
            pane.labelLayer = CreateFrame("Frame", nil, canvas)
            pane.labelLayer:SetAllPoints(canvas)
            pane.labelLayer:SetFrameLevel(canvas:GetFrameLevel() + 2)
        end
        return Theme:Text(pane.labelLayer, pane.fonts.factLabel)
    end

    -- The click area over a loot section's label, with its fold arrow at
    -- the box's right end.
    local function NewSectionToggle()
        local btn = CreateFrame("Button", nil, canvas)
        btn:SetFrameLevel(canvas:GetFrameLevel() + 2)
        btn.arrow = Theme:Arrow(btn, true)
        btn:SetScript("OnClick", function(self) pane:ToggleSection(self.sectionKey) end)
        btn:SetScript("OnEnter", function(self) Theme:SetTextColor(self.label, Theme.color.text) end)
        btn:SetScript("OnLeave", function(self) Theme:SetTextColor(self.label, Theme.color.heading) end)
        return btn
    end

    -- A boxed section's card backdrop, under the cells (NewCell raises them).
    local function NewBox()
        local box = CreateFrame("Frame", nil, canvas)
        box:SetFrameLevel(canvas:GetFrameLevel() + 1)
        Theme:CardBackdrop(box, canvas)
        return box
    end

    -- A section label line at `y` (two labels over a header2 pair), and a
    -- loot section's toggle over it. `drawn` counts what the redraw has used
    -- of each pool.
    local function DrawHeaderLine(line, y, cellWidth, drawn)
        local pad = ToCanvas(Size.pad)
        for col, text in ipairs({ line.header, line.header2 }) do
            local label
            if line.box then
                drawn.boxLabels = drawn.boxLabels + 1
                label = FromPool(pane.boxLabels, drawn.boxLabels, NewBoxLabel)
                label:SetText(text)
                label:ClearAllPoints()
                label:SetPoint("TOPLEFT", pad + BOX.LABEL + (col - 1) * (cellWidth + GAP), -y - 10)
            else
                drawn.sections = drawn.sections + 1
                label = FromPool(pane.sections, drawn.sections,
                    function() return Theme:Text(canvas, pane.fonts.label) end)
                label:SetText(Theme:Label(text))
                label:ClearAllPoints()
                label:SetPoint("TOPLEFT", pad + 2 + (col - 1) * (cellWidth + GAP), -y - 4)
            end
            Theme:SetTextColor(label, Theme.color.heading)
            label:Show()
            if line.shuts then
                drawn.toggles = drawn.toggles + 1
                local btn = FromPool(pane.toggles, drawn.toggles, NewSectionToggle)
                btn.sectionKey, btn.label = line.sectionKey, label
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", pad, -y)
                -- Open, it stops at the first line of items.
                btn:SetSize(FullWidth(), line.closed and ShutHeight() or BOX.HEAD)
                btn.arrow:Resize(ToCanvas(BOX.ARROW))
                btn.arrow:ClearAllPoints()
                btn.arrow:SetPoint("RIGHT", btn, "TOPRIGHT", -BOX.INSET, -ShutHeight() / 2) -- level with the label
                btn.arrow:SetOpen(not line.closed)
                btn:Show()
            end
        end
    end

    -- The boxes of the sections on screen. A header2 pair gets a box over
    -- each column; others span the columns their items fill. A box almost
    -- scrolled away (too short for its two rounded corners) isn't drawn.
    local function DrawBoxes(shown, cellWidth, drawn)
        local pad = ToCanvas(Size.pad)
        for _, box in ipairs(shown) do
            local spans = box.pair and { { 0, 1 }, { 1, 1 } } or { { 0, box.columns } }
            if box.bottom - box.top < BOX.MIN then spans = {} end
            for _, span in ipairs(spans) do
                drawn.boxes = drawn.boxes + 1
                local frame = FromPool(pane.boxes, drawn.boxes, NewBox)
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", pad + span[1] * (cellWidth + GAP), -box.top)
                frame:SetSize(span[2] * cellWidth + (span[2] - 1) * GAP, box.bottom - box.top)
                frame:Show()
                frame:FitCard()
            end
        end
    end

    -- Hands out cells for a redraw from line `first`: an item still near the
    -- top keeps its cell, the others are free for items coming into view.
    -- Returns CellFor(entry) and the set of cells it gave out.
    local function CellPicker(lines, first)
        local held, taken, free = {}, {}, {}
        for _, cell in ipairs(pane.cells) do
            if cell:IsShown() and cell.entry then held[cell.entry] = cell end
        end
        for lineIndex = first, math.min(#lines, first + #pane.cells) do
            local line = lines[lineIndex]
            if not (line.fold or line.header) then
                for _, entry in ipairs(line) do
                    if held[entry] then taken[held[entry]] = true end
                end
            end
        end
        for _, cell in ipairs(pane.cells) do
            if not taken[cell] then table.insert(free, cell) end
        end
        local used = {}
        local function CellFor(entry)
            local cell = held[entry]
            if cell and not used[cell] then
                used[cell] = true
                return cell
            end
            cell = table.remove(free) or NewCell()
            used[cell] = true
            cell.stamp = nil
            return cell
        end
        return CellFor, used
    end

    -- Items fill row by row so the strongest drops sit on the top line.
    -- `scrolling` (true) when only the scroll position changed: the lines
    -- are as last packed, and an item still on screen keeps its cell as
    -- drawn, so a glide sets up only the items coming into view.
    function pane:Refresh(scrolling)
        scrolling = scrolling == true and self.lines ~= nil
        if not scrolling then
            stamp = stamp + 1
            self.lines = Lines()
            self.maxOffset = MaxOffset(self.lines)
        end
        local cellWidth = CellWidth()
        local bottom = ToCanvas(self:GetHeight())
        local pad = ToCanvas(Size.pad)
        local lines = self.lines
        -- Mid-glide the first line sits partly above the top edge.
        local first, lift = Theme:ScrollStart(self.offset, function(i)
            return lines[i] and LineHeight(lines[i]) or 0
        end)
        local CellFor, usedCells = CellPicker(lines, first)
        local greyed = self.entries and self.entries.greyed -- items "Items I can use" greys out
        local drawn = { sections = 0, boxLabels = 0, folds = 0, toggles = 0, boxes = 0 }
        local y = ToCanvas(self.top) - lift
        local shown = {} -- boxed sections on screen, in order, with their top and bottom
        for lineIndex = first, #lines do
            local line = lines[lineIndex]
            -- A line cut off by the bottom edge still shows the part that fits.
            if y >= bottom then break end
            local box = line.box
            if box then
                if shown[#shown] ~= box then
                    -- A box running on from above the view keeps its top
                    -- edge just inside the view's top, so the gold line stays
                    -- put while the lines scroll under it instead of coming
                    -- and going with each line.
                    box.top = math.max(y, ToCanvas(self.top) + BOX.CLIP)
                    table.insert(shown, box)
                end
                box.bottom = y + LineHeight(line) - (line.last and BOX.GAP or 0)
            end
            if line.fold then
                drawn.folds = drawn.folds + 1
                local row = FromPool(self.folds, drawn.folds, NewFoldRow)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", pad, -y)
                row:SetWidth(FullWidth())
                row:Set(line.fold, IsFoldOpen(self, line.fold))
                row:Show()
            elseif line.header then
                DrawHeaderLine(line, y, cellWidth, drawn)
            else
                local inset = box and BOX.INSET or 0
                for col, entry in ipairs(line) do
                    local cell = CellFor(entry)
                    cell:ClearAllPoints()
                    cell:SetPoint("TOPLEFT", pad + (col - 1) * (cellWidth + GAP) + inset, -y)
                    cell:SetWidth((line.wide and FullWidth() or cellWidth) - inset * 2)
                    cell.stacked = line.stacked
                    -- An ability's card grows to hold its description box;
                    -- the cards on a line share its height.
                    cell:SetHeight((pane.rowHeight or Size.itemRow) + (entry.ability and line.extra or 0))
                    if not (scrolling and cell.stamp == stamp) then
                        cell.stamp = stamp
                        cell:SetEntry(entry, self.showSource)
                        cell:ShowSources((not self.showSource or entry.buyFrom or entry.quests) and entry or {})
                        -- The item a search result led here stands out.
                        cell:SetSelected(self.highlight ~= nil and entry.itemID == self.highlight)
                        cell:SetGreyed(greyed ~= nil and greyed[entry] == true)
                    end
                    cell:Show()
                end
            end
            y = y + LineHeight(line)
        end
        DrawBoxes(shown, cellWidth, drawn)
        for _, cell in ipairs(self.cells) do
            if not usedCells[cell] then
                cell:Hide()
                cell.entry = nil
            end
        end
        for i = drawn.sections + 1, #self.sections do self.sections[i]:Hide() end
        for i = drawn.folds + 1, #self.folds do self.folds[i]:Hide() end
        for i = drawn.boxLabels + 1, #self.boxLabels do self.boxLabels[i]:Hide() end
        for i = drawn.boxes + 1, #self.boxes do self.boxes[i]:Hide() end
        for i = drawn.toggles + 1, #self.toggles do self.toggles[i]:Hide() end
        local max = self.maxOffset
        self.scrollBar:Update(self.offset, max, #lines - max)
    end

    -- The scroll offset that brings `itemID` into view: none when it is on
    -- the first screen, else from its line (or the section label above it).
    local function OffsetFor(itemID)
        local lines = Lines()
        local room, y = ToCanvas(pane:GetHeight() - pane.top - Size.pad), 0
        for lineIndex, line in ipairs(lines) do
            local lineHeight = LineHeight(line)
            for _, entry in ipairs(line.header and {} or line) do
                if entry.itemID == itemID then
                    if y + lineHeight - Trailing(line) <= room then return 0 end
                    local start = lineIndex - 1
                    if start > 0 and (lines[start].header or lines[start].fold) then start = start - 1 end
                    return math.min(MaxOffset(lines), start)
                end
            end
            y = y + lineHeight
        end
        return 0
    end

    -- Opens fold `fold` (a header portrait's click, a search's go-to).
    function pane:OpenFold(fold)
        local states, key = FoldMemory(self, fold)
        states[key] = true
    end

    -- Opens or shuts fold `fold`, keeping the scroll inside the new length.
    function pane:ToggleFold(fold)
        ns.SectionMemory.Toggle(FoldMemory(self, fold))
        self.offset = math.min(self.offset or 0, MaxOffset())
        self:Refresh()
    end

    -- Opens or shuts a recipe's whole trainer list ("N more trainers"),
    -- keeping the scroll inside the new length.
    function pane:ToggleTrainers(spellID)
        ns.SectionMemory.Toggle(ns.SectionMemory.Area("trainers"), spellID)
        self.offset = math.min(self.offset or 0, MaxOffset())
        self:Refresh()
    end

    -- Opens or shuts a loot section by its key ("WEAPONS"), here and for every boss.
    function pane:ToggleSection(sectionKey)
        SetSectionShut(self.shutSections, sectionKey, not IsSectionShut(self.shutSections, sectionKey))
        self.offset = math.min(self.offset or 0, MaxOffset())
        self:Refresh()
    end

    -- Opens a fold and scrolls it to the top (a header portrait's click).
    function pane:JumpToFold(key)
        for lineIndex, line in ipairs(Lines()) do
            if line.fold and line.fold.key == key then
                self:OpenFold(line.fold)
                self.lines = nil  -- the fold's items need lines before the glide draws them
                local target = math.min(MaxOffset(), lineIndex - 1)
                if target == self.offset then self:Refresh() else Theme:GlideTo(self, target) end
                return
            end
        end
    end

    -- Opens the fold an item sits in, so a search's go-to can show it,
    -- and the loot section it sits in. An item under several PvP class
    -- folds opens the player's own class's, else the first.
    local function OpenFoldOf(itemID)
        local ownClassFold = ns.UI.TierSets.PlayerFoldKey()
        local fold, section, foundFold, foundSection, found
        for _, entry in ipairs(pane.entries) do
            if entry.fold then
                fold, section = entry, nil
            elseif entry.header then
                section = entry.shuts and entry.sectionKey or nil
            elseif entry.itemID == itemID and (not found or (fold and fold.key == ownClassFold)) then
                foundFold, foundSection, found = fold, section, true
            end
        end
        if foundFold then pane:OpenFold(foundFold) end
        if foundSection then SetSectionShut(pane.shutSections, foundSection, false) end
    end

    -- Shows the standing bar ({ reaction, value, max }) or hides it (nil),
    -- moving the grid down to make room.
    function pane:SetReputation(rep)
        if rep then self.rep:SetStanding(unpack(rep)) end
        self.rep:SetShown(rep ~= nil)
        self:UpdateTop()
    end

    -- How far down from the pane's top the subtitle ends: the title's place
    -- (LayoutBosses) and the two texts' heights.
    function pane:SubtitleBottom()
        return (self.titleY or TITLE_Y) + self.title:GetStringHeight() + 6 + self.subtitle:GetStringHeight()
    end

    -- Where the grid starts: under the header, its portraits and the standing bar.
    function pane:UpdateTop()
        local top = self.header + (self.rep:IsShown() and REP_HEIGHT or 0)
        if self.related:IsShown() or self.spoiler:IsShown() then
            -- Under the subtitle, below the header's portrait when that's lower.
            local bottom = self:SubtitleBottom() + 6 + 8
            if self.related:IsShown() then bottom = bottom + 16 + 4 end
            if self.spoiler:IsShown() then bottom = bottom + self.spoiler:GetHeight() + 4 end
            top = math.max(top, math.ceil(bottom))
        end
        if top ~= self.top then
            self.top = top
            self.scrollBar:SetPoint("TOPRIGHT", -4, -top)
            canvas:SetTop(top)
        end
    end

    -- The header's `i`th boss portrait and the name under it (a council's).
    local function Portrait(i)
        if not pane.portraits[i] then
            pane.portraits[i] = CreateBossPortrait(pane)
            local name = Theme:Text(pane, Theme.font.small)
            name:SetJustifyH("CENTER")
            name:SetWordWrap(false)
            name:SetWidth(PORTRAIT_HEADER.ROW_CELL - 4)
            pane.portraitNames[i] = name
        end
        return pane.portraits[i], pane.portraitNames[i]
    end

    -- Lays out the header for `bosses` ({ name, display, level, rank } each,
    -- or nil): a single boss's portrait left of the name, or a council's in
    -- rows under the subtitle, wrapping to the pane's width.
    function pane:LayoutBosses()
        local bosses = self.bosses
        local count = bosses and #bosses or 0
        for i = count + 1, #self.portraits do
            self.portraits[i]:Hide()
            self.portraitNames[i]:Hide()
        end
        local x, y = Size.pad + 4, TITLE_Y
        if count == 1 then
            local portrait, name = Portrait(1)
            portrait:SetBoss(bosses[1])
            portrait:SetScale(PORTRAIT_HEADER.SINGLE_SCALE)
            portrait.hint = nil
            portrait.hit:SetScript("OnMouseUp", nil)
            portrait:ClearAllPoints()
            -- A scaled frame's offsets are in its own units.
            portrait:SetPoint("TOPLEFT", (Size.pad - 2) / PORTRAIT_HEADER.SINGLE_SCALE,
                -PORTRAIT_HEADER.SINGLE_TOP / PORTRAIT_HEADER.SINGLE_SCALE)
            name:Hide()
            x, y = Size.pad - 2 + PBOX_W * PORTRAIT_HEADER.SINGLE_SCALE + 8, PORTRAIT_HEADER.SINGLE_TITLE_Y
            self.header = math.max(HEADER_HEIGHT,
                math.ceil(PORTRAIT_HEADER.SINGLE_TOP * 2 + PBOX_H * PORTRAIT_HEADER.SINGLE_SCALE))
        elseif count > 1 then
            local perRow = math.max(1, math.floor((self:GetWidth() - Size.pad * 2) / PORTRAIT_HEADER.ROW_CELL))
            local boxH = PBOX_H * PORTRAIT_HEADER.ROW_SCALE
            local rowH = boxH + PORTRAIT_HEADER.ROW_NAME
            for i, boss in ipairs(bosses) do
                local portrait, name = Portrait(i)
                portrait:SetBoss(boss)
                portrait:SetScale(PORTRAIT_HEADER.ROW_SCALE)
                portrait.hint = self.hasFolds and L["Click to show its loot"] or nil
                portrait.hit:SetScript("OnMouseUp", self.hasFolds and function(_, button)
                    if button == "LeftButton" then self:JumpToFold(i) end -- right-click is Back
                end or nil)
                local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
                -- The portrait itself (not its ring's box) centered in the column.
                local columnMiddle = Size.pad + col * PORTRAIT_HEADER.ROW_CELL + PORTRAIT_HEADER.ROW_CELL / 2
                local left = columnMiddle - (PBOX_LEFT + PORTRAIT / 2) * PORTRAIT_HEADER.ROW_SCALE
                local top = PORTRAIT_HEADER.ROW_Y + row * (rowH + PORTRAIT_HEADER.ROW_GAP)
                portrait:ClearAllPoints()
                portrait:SetPoint("TOPLEFT", left / PORTRAIT_HEADER.ROW_SCALE, -top / PORTRAIT_HEADER.ROW_SCALE)
                name:ClearAllPoints()
                name:SetPoint("TOP", self, "TOPLEFT", columnMiddle, -(top + boxH - 2))
                name:SetText(boss[1])
                name:Show()
            end
            local rows = math.ceil(count / perRow)
            self.header = math.ceil(PORTRAIT_HEADER.ROW_Y + rows * rowH + (rows - 1) * PORTRAIT_HEADER.ROW_GAP + 6)
        else
            self.header = HEADER_HEIGHT
        end
        self.title:SetPoint("TOPLEFT", x, -y)
        self.titleX, self.titleY = x, y
        self:UpdateTop()
    end

    -- How far down the pane its lines reach, scrolled to the top: for a
    -- page that puts something under them (the Classes tab's set bonuses).
    function pane:ContentHeight()
        local lines = self.lines or Lines()
        local height = 0
        for i, line in ipairs(lines) do
            height = height + LineHeight(line) - (i == #lines and Trailing(line) or 0)
        end
        return self.top + height * zoom
    end

    -- The wishlist changed: stars on show follow it.
    function pane:UpdateStars()
        for _, cell in ipairs(self.cells) do
            if cell:IsShown() and cell.star:IsShown() then
                cell.star:SetOn(ns.Wishlist:Has(cell.entry.itemID))
            end
        end
    end

    -- Every entry measured and drawn again from the next redraw (looks
    -- collected, or the window scaled: text measured at one scale can be a
    -- pixel off at another).
    function pane:Remeasure()
        ForgetNeeds()
        -- Loot rows' quest lines come and go with the Quests tab.
        wipe(sourcesHeights)
        fitNeed = nil
        for _, cell in ipairs(self.cells) do cell.stamp = nil end
    end

    -- Draws the grid at `scale` (1 = full size) from the next ShowItems.
    function pane:SetZoom(scale)
        if scale == zoom then return end
        zoom = scale
        canvas:SetScale(scale)
        local fonts = ns.UI.LootGridFonts(zoom)
        self.fonts = fonts
        -- A row tall enough for the name and two grey lines, 7 above and 6 below.
        self.rowHeight = ns.UI.LootRowHeight(fonts)
        ForgetNeeds()
        ApplyFonts(probe, fonts)
        for _, cell in ipairs(self.cells) do
            ApplyFonts(cell, fonts)
            cell.stamp = nil -- drawn again with the new fonts
        end
        for _, label in ipairs(self.sections) do label:SetFontObject(fonts.label) end
        for _, label in ipairs(self.boxLabels) do label:SetFontObject(fonts.factLabel) end
        for _, row in ipairs(self.folds) do
            row.name:SetFontObject(fonts.section)
            row.sub:SetFontObject(fonts.small)
        end
    end

    -- Quests whose map markers are on this boss: "Related Quests: [A]  ·  [B]"
    -- under the subtitle, or nothing (nil or none).
    function pane:SetRelatedQuests(quests)
        local show = quests ~= nil and #quests > 0 and ns.Modules:IsOn("QUESTS")
        if show then
            local links = {}
            local questColor = Theme:ColorCode(Theme.color.quest)
            for i, quest in ipairs(quests) do
                table.insert(links, ("|Hneedroll:related:%d|h%s[%s]|r|h"):format(i, questColor, quest.name))
            end
            self.related.quests = quests
            self.related.text:SetText(("%s%s:|r  %s"):format(Theme:ColorCode(Theme.color.heading), L["Related Quests"],
                table.concat(links, Theme.DOTS)))
        end
        if show ~= self.related:IsShown() then
            self.related:SetShown(show)
            self:UpdateTop()
            self:Refresh()
        end
    end

    -- A boss's secret ({ text, item, itemName }, Data.lua's bossSpoilers) or
    -- nil. Shut each time another boss's is set.
    function pane:SetSpoiler(data)
        local spoiler = self.spoiler
        if data ~= spoiler.data then spoiler.open = false end
        spoiler.data = data
        spoiler:SetShown(data ~= nil)
        self:DrawSpoiler()
    end

    -- An open spoiler's text: the secret with its links (items, quests,
    -- bosses on the map, dungeon entrances on the world map) filled in.
    local function OpenSpoilerText(data)
        local text, questColor = Theme:ColorCode(Theme.color.text), Theme:ColorCode(Theme.color.quest)
        local linkColor = Theme:ColorCode(Theme.color.link)
        local function ItemLink(id, name)
            return ("|cff1eff00|Hitem:%d::::::::|h[%s]|h|r%s"):format(id, C_Item.GetItemNameByID(id) or name, text)
        end
        -- A dungeon, its entrance pinned by a click; plain text when NeedRoll
        -- doesn't know the dungeon or where its entrance is.
        local function DungeonLink(inside)
            local entrance, dungeonName = SourceSpot({ inside = inside })
            if not (entrance and dungeonName) then return dungeonName or inside end
            return ("|Hneedroll:inside:%s|h%s%s|h%s"):format(inside, linkColor, dungeonName, text)
        end
        local links = {}
        if data.item then links[1] = ItemLink(data.item, data.itemName) end
        for i, link in ipairs(data.links or {}) do
            if link.item then
                links[i] = ItemLink(link.item, link.name)
            elseif link.quest then
                links[i] = ("|Hneedroll:quest:%d|h%s[%s]|h%s"):format(link.quest, questColor, link.name, text)
            elseif link.inside then
                links[i] = DungeonLink(link.inside)
            else
                -- A boss of another instance: "needroll:boss:ARCHMAGE_ARUGAL:SHADOWFANG".
                local target = link.instance and link.boss .. ":" .. link.instance or link.boss
                links[i] = ("|Hneedroll:boss:%s|h%s%s|h%s"):format(target, linkColor, link.name, text)
            end
        end
        return ("%s%s:|r  %s%s|r"):format(Theme:ColorCode(Theme.color.heading), L["How to summon"], text,
            data[1]:format(unpack(links)))
    end

    function pane:DrawSpoiler()
        local spoiler = self.spoiler
        if spoiler:IsShown() then
            -- 4 under the subtitle, or 4 under the boss's quests (6 under the
            -- subtitle). Hung from the pane by that measured offset, not from the text
            -- above: its dungeon link's secure button (UI.HoverMapLink) can't
            -- hang from a text through any chain (Theme:LineHeight).
            local related = self.related
            local top = self:SubtitleBottom() + (related:IsShown() and 6 + related:GetHeight() or 0) + 4
            spoiler:ClearAllPoints()
            spoiler:SetPoint("TOPLEFT", self.titleX or Size.pad + 4, -top)
            spoiler:SetPoint("RIGHT", -Size.pad, 0)
            local shutText = ("%s%s|r"):format(Theme:ColorCode(Theme.color.muted), L["How to summon (spoiler)"])
            spoiler.text:SetText(spoiler.open and OpenSpoilerText(spoiler.data) or shutText)
            spoiler:SetHeight(math.max(14, spoiler.text:GetStringHeight()))
        end
        self:UpdateTop()
        self:Refresh()
    end

    -- Shows a list. `highlight`: an item ID to mark and scroll to. `keep`:
    -- stay scrolled where the list was (the same search, redrawn as names
    -- load). `rep`: the standing bar's { reaction, value, max }, on Factions
    -- pages. `bosses`: the encounter's boss portraits (ns.Data:Bosses).
    function pane:ShowItems(title, subtitle, entries, showSource, highlight, keep, rep, bosses)
        -- A single boss's NPC ID after its name (local checkouts only).
        local npc = bosses and #bosses == 1 and bosses[1][5]
        self.title:SetText(Theme:WithIds(title or "", BossIds(npc or nil)))
        self.title:SetPoint("RIGHT", -Size.pad, 0)
        self.subtitle:SetText(subtitle or "")
        -- A new list's trainers are put in order from where the player now stands.
        if entries ~= self.entries then
            wipe(trainerOrder)
            wipe(vendorOrder)
        end
        self.hasFolds = entries[1] ~= nil and entries[1].fold == true
        self.bosses = bosses
        self.related:Hide()  -- a boss page sets its quests again after
        self.spoiler:Hide()  -- and its secret
        self:ShowFilters(false)  -- and its loot filters
        self:LayoutBosses()
        self:SetReputation(rep)
        self.entries = entries
        if highlight then OpenFoldOf(highlight) end
        self.showSource = showSource
        self.highlight = highlight
        if highlight then
            self.offset = OffsetFor(highlight)
        elseif keep then
            self.offset = math.min(self.offset or 0, MaxOffset())
        else
            self.offset = 0
        end
        self:Refresh()
    end

    -- The limit as of the last full redraw (each one packs the lines anyway),
    -- so a wheel notch doesn't pack them all again.
    Theme:WheelScroll(pane, function() return pane.maxOffset or MaxOffset() end,
        function(scrolling) pane:Refresh(scrolling) end)
    pane.scrollBar = Theme:ScrollBar(pane, pane.top, Size.pad, function(offset)
        pane.offset = offset
        pane:Refresh(true)
    end)
    pane:SetScript("OnSizeChanged", function(self)
        -- A council's portraits rewrap to the new width.
        if self.bosses and #self.bosses > 1 then self:LayoutBosses() end
        self:Refresh()
    end)
    return pane
end
