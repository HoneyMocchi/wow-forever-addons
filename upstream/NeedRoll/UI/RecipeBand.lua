-- A profession's recipe list, narrowed and compacted (Mike's picks C and D,
-- 2026-10-16), and its filters:
-- * The filter sidebar, the Professions tab's first pane (Mike's layout G,
--   2026-11-18): under the profession's Overview row, the chips (All, Head
--   ... Feet, Weapons, Bag, Cloth, Other; only the ones the profession has,
--   one at a time) as a two-column list with each one's recipe count, then
--   the Skill-ups / From trainer / Learnable / Hide grey / Have materials
--   tick boxes (while the character has the profession), then, for
--   Cooking, a Buff box whose menu picks a buff the food gives (Mike,
--   2026-11-13), then the required skill range (two number boxes, Mike's
--   pick A, 2026-10-18). The count of recipes listed sits beside the
--   recipe list's Filter recipes box.
-- * WoW: Forever's series (Flame/Pearly/... or Acolyte's/Crusader's/...
--   pieces, Data.lua's GroupColourSets) folded into one row with a dot per
--   variant to pick which variant's pieces it opens to; named gear sets and
--   rank lines folded too.
-- * The text tab chips other pages share (RB.Chip, RB.PlaceLines).
-- The list (UI/Lists.lua) calls Narrow, Fold and Layout; everything else
-- lives here.
local _, ns = ...
local Theme = ns.Theme
local L = ns.L

local RB = {}
ns.RecipeBand = RB

-- Slot groups in chip order. A product's paper-doll order (Wishlist:Slot)
-- picks its group; 15-18 (weapons, ranged, shields, off-hands, relics) are
-- Weapons, and neck, finger, trinket and tabard are Other.
local GROUPS = {
    { "ALL", L["All"] }, { "HEAD", L["Head"] }, { "SHOULDER", L["Shoulder"] },
    { "BACK", INVTYPE_CLOAK or "Back" }, { "CHEST", L["Chest"] }, { "SHIRT", L["Shirt"] },
    { "WRIST", L["Wrist"] }, { "HANDS", L["Hands"] }, { "WAIST", L["Waist"] }, { "LEGS", L["Legs"] },
    { "FEET", L["Feet"] }, { "WEAPONS", L["Weapons"] }, { "BAG", L["Bag"] }, { "CLOTH", L["Cloth"] },
    { "OTHER", L["Other"] },
}
local LABEL = {}
for _, group in ipairs(GROUPS) do LABEL[group[1]] = group[2] end
local GROUP_BY_SLOT_ORDER = { [1] = "HEAD", [3] = "SHOULDER", [4] = "BACK", [5] = "CHEST", [6] = "SHIRT",
    [8] = "WRIST", [9] = "HANDS", [10] = "WAIST", [11] = "LEGS", [12] = "FEET", [15] = "WEAPONS",
    [16] = "WEAPONS", [17] = "WEAPONS", [18] = "WEAPONS", [19] = "BAG" }
-- "Learnable" has three steps, a click moving to the next (Mike,
-- 2026-11-10): off, then every recipe the character hasn't learned yet
-- whatever its skill (a greyed tick), then only those its skill allows now
-- (a full tick).
local LEARNABLE_ANY, LEARNABLE_NOW = "any", "now"
RB.LEARNABLE_ANY, RB.LEARNABLE_NOW = LEARNABLE_ANY, LEARNABLE_NOW
local NEXT_LEARNABLE_STEP = { [false] = LEARNABLE_ANY, [LEARNABLE_ANY] = LEARNABLE_NOW, [LEARNABLE_NOW] = false }

-- Learnable's tooltip: the step it is at and what the next click does.
local function LearnableTooltipText(step)
    if step == LEARNABLE_ANY then
        return L["Listing the recipes you haven't learned, at any skill. Click again for only those your skill allows now."]
    end
    if step == LEARNABLE_NOW then
        return L["Listing the recipes you haven't learned that your skill allows now. Click to list every recipe again."]
    end
    return L["Click to list the recipes you haven't learned, and again for only those your skill allows now."]
end

-- "Have materials" has three steps the same way (Mike, 2026-11-11): off,
-- then the recipes the character holds every material for in the bags and
-- the bank together (a greyed tick), then only those it carries in the bags
-- (a full tick).
local MATERIALS_BANK, MATERIALS_BAGS = "bank", "bags"
RB.MATERIALS_BANK, RB.MATERIALS_BAGS = MATERIALS_BANK, MATERIALS_BAGS
local NEXT_MATERIALS_STEP = { [false] = MATERIALS_BANK, [MATERIALS_BANK] = MATERIALS_BAGS, [MATERIALS_BAGS] = false }

-- Have materials' tooltip: the step it is at and what the next click does.
local function MaterialsTooltipText(step)
    if step == MATERIALS_BANK then
        return L["Listing the recipes you have the materials for in your bags and bank. Click again for bags only."]
    end
    if step == MATERIALS_BAGS then
        return L["Listing the recipes you have the materials for in your bags. Click to list every recipe again."]
    end
    return L["Click to list the recipes you have the materials for in your bags and bank, and again for bags only."]
end

-- The tick boxes, in order. A box with `nextStep` has steps instead of on
-- and off, and must also give `tooltip(step)`, its tooltip text at each
-- step (hovering calls it).
local TOGGLES = {
    { key = "SKILLUP", label = L["Skill-ups"] },
    { key = "TRAINER", label = L["From trainer"] },
    { key = "LEARNABLE", label = L["Learnable"], nextStep = NEXT_LEARNABLE_STEP, tooltip = LearnableTooltipText },
    { key = "HIDEGREY", label = L["Hide grey"] },
    { key = "MATERIALS", label = L["Have materials"], nextStep = NEXT_MATERIALS_STEP, tooltip = MaterialsTooltipText },
}

-- The buffs foods give (Data/FoodBuffs.lua), in the order the Buff menu
-- lists them: Mike's order (2026-11-13), then the two regenerations. Each
-- is named with the game's own word for it, so it reads in the player's
-- language and the recipe filter finds it as the player would type it
-- ("Ausdauer" on a German client). The word is read when asked, not kept,
-- so the smoke tests can stand in another client's.
local BUFFS = {
    { key = "STAMINA", label = function() return SPELL_STAT3_NAME end },
    { key = "SPIRIT", label = function() return SPELL_STAT5_NAME end },
    { key = "HEALING", label = function() return STAT_SPELLHEALING end },
    { key = "SPELL_DAMAGE", label = function() return STAT_SPELLDAMAGE end },
    { key = "AGILITY", label = function() return SPELL_STAT2_NAME end },
    { key = "STRENGTH", label = function() return SPELL_STAT1_NAME end },
    { key = "INTELLECT", label = function() return SPELL_STAT4_NAME end },
    { key = "ATTACK_POWER", label = function() return STAT_ATTACK_POWER end },
    { key = "MOVEMENT_SPEED", label = function() return STAT_MOVEMENT_SPEED end },
    { key = "MANA_REGEN", label = function() return MANA_REGEN end },
    { key = "HEALTH_REGEN", label = function() return ITEM_MOD_HEALTH_REGENERATION_SHORT end },
}
local BUFF_BY_KEY = {}
for _, buff in ipairs(BUFFS) do BUFF_BY_KEY[buff.key] = buff end
local NO_BUFFS = {}

-- The colour sets' swatches, by the set word Data.lua kept (encounter.tint).
local function Hex(s) return { tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16) } end
local SWATCH = {
    Flame = Hex("E5622E"), Pearly = Hex("E8E2D0"), Pristine = Hex("9FD3F0"), Shadow = Hex("8A5FC2"),
    Shining = Hex("F2CF4A"), Silky = Hex("E58FB8"), Azure = Hex("3F8BE0"), Cloudy = Hex("C9D3DC"),
    Black = Hex("3A3A3A"), Fiery = Hex("E5622E"), Frothing = Hex("7FD0C8"), Gilded = Hex("D9A441"),
    Golden = Hex("F2CF4A"), Radiant = Hex("FFF3B0"), Netherflame = Hex("E5622E"), Netherfroth = Hex("7FD0C8"),
    Nethergeld = Hex("D9A441"), Netherlight = Hex("FFF3B0"), Netherpearl = Hex("E8E2D0"), Nethershine = Hex("F2CF4A"),
}
local DOT = Theme.roundMask  -- a round mask, drawn as a dot
local ItemClass = Enum.ItemClass
local TradeGoods = { Parts = 1, Explosives = 2, Devices = 3 } -- subclass IDs of what engineers make
-- The game's own name for a trade goods subclass, in the player's language.
-- Some carry a tag such as "Explosives (OBSOLETE)", so a trailing
-- "(...)" is cut off.
local function TradeGoodsName(subclassID)
    local name = C_Item.GetItemSubClassInfo(ItemClass.Tradegoods, subclassID)
    if not name then return nil end
    return (name:gsub("%s*%b()%s*$", ""))
end

-- Groups -----------------------------------------------------------------

-- The item a recipe makes and its class, subclass and equip slot (none for an enchant).
local function ProductInfo(encounter)
    local itemID = ns.UI.RecipeProduct(encounter)
    if not itemID then return nil end
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return itemID, classID, subclassID, equipLoc
end

-- A recipe's slot group, from the item it makes.
local function SlotOf(encounter, instance)
    local itemID, classID = ProductInfo(encounter)
    if classID == nil then return "OTHER" end
    if classID == ItemClass.Tradegoods and instance.id == "TAILORING" then return "CLOTH" end
    local _, order = ns.Wishlist:Slot({ itemID = itemID })
    return GROUP_BY_SLOT_ORDER[order] or "OTHER"
end

-- Groups read off the recipes' English names at load, for the professions
-- whose chips aren't slots. It has to be then: Core/Names.lua swaps in the
-- names in the player's own language (and its saved copy of them) at
-- PLAYER_LOGIN at the earliest, and the game always sends NeedRoll's own
-- ADDON_LOADED before PLAYER_LOGIN. The rank lines below are marked then too.
local nameGroup = setmetatable({}, { __mode = "k" })
-- `name` has `word` as a whole word: "Oil" is in "Wizard Oil", not "Oily".
local function HasWord(name, word)
    return (" " .. name .. " "):find("[^%a]" .. word .. "[^%a]") ~= nil
end
-- The first group in `rules` ({ group, { words } } in order) with a word
-- found anywhere in `name`.
local function GroupByWords(name, rules)
    for _, rule in ipairs(rules) do
        for _, word in ipairs(rule[2]) do
            if name:find(word, 1, true) then return rule[1] end
        end
    end
end
-- Alchemy's, first match wins.
local function AlchemyGroup(name)
    if name:match("^Transmute:") then return "TRANSMUTES" end
    if name:match("^Flask of") then return "FLASKS" end
    if name:find("Elixir", 1, true) then return "ELIXIRS" end
    if HasWord(name, "Oil") then return "OILS" end
    if name:find("Potion", 1, true) or name:find("Draught", 1, true) then return "POTIONS" end
    return "OTHER"
end
-- Enchanting's enchant slots, from "Enchant <slot> - ..." (the data has a
-- doubled space in two of them).
local ENCHANT_SLOTS = { Bracer = "BRACER", Chest = "CHEST", Cloak = "CLOAK", Gloves = "GLOVES", Boots = "BOOTS",
    Necklace = "NECKLACE", Shield = "SHIELD", Weapon = "WEAPON1H", ["2H Weapon"] = "WEAPON2H",
    ["Off-Hand"] = "OFFHAND" }
local function EnchantSlot(name)
    name = name:gsub("%s+", " ")
    if name:match("^Formula: Imbue Chest") then return "CHEST" end
    if name == "Conductive Shield Coating" then return "SHIELD" end
    local slot = name:match("^Enchant (.-) %- ")
    return slot and ENCHANT_SLOTS[slot]
end
local ENCHANTING_WORDS = { { "IDOL", { "Idol", "Totem", "Libram" } }, { "RODS", { "Rod" } } }
local FIRST_AID_WORDS = { { "BANDAGES", { "Bandage" } }, { "POTIONS", { "Potion" } } }
local ENGINEERING_WORDS = { { "FIREWORKS", { "Rocket", "Firework" } },
    { "EXPLOSIVES", { "Bomb", "Grenade", "Dynamite", "Charge", "Mortar", "Megabomb" } } }
local GROUP_BY_NAME = {
    ENCHANTING = function(name)
        return EnchantSlot(name) or GroupByWords(name, ENCHANTING_WORDS) or HasWord(name, "Oil") and "OILS" or nil
    end,
    ALCHEMY = AlchemyGroup,
    FIRST_AID = function(name) return GroupByWords(name, FIRST_AID_WORDS) end,
    ENGINEERING = function(name) return GroupByWords(name, ENGINEERING_WORDS) end,
}

-- Rank lines (Minor ... Major Healing Potion): recipes whose names match
-- without their rank word share encounter.rankLine (in skill order, the data's),
-- and encounter.rank is that word ("Base" without one). Every "... Protection
-- Potion" is one line, encounter.protection.
local RANK_WORDS = { Weak = true, Minor = true, Lesser = true, Strong = true, Great = true, Greater = true,
    Mighty = true, Superior = true, Major = true }
local function WithoutRank(name)
    local words, rank = {}, nil
    for word in name:gmatch("%S+") do
        if RANK_WORDS[word] and not rank then rank = word else table.insert(words, word) end
    end
    return table.concat(words, " "), rank
end
local function MarkRankLines(instance)
    local lines = {}
    for _, encounter in ipairs(instance.encounters) do
        local name = (encounter.name or ""):gsub("%s+", " ")
        local lineKey, rank = WithoutRank(name)
        local protection = name:match("Protection Potion$") ~= nil
        if protection then lineKey = "PROTECTION" end
        lines[lineKey] = lines[lineKey] or {}
        table.insert(lines[lineKey], encounter)
        encounter.rank, encounter.protection = rank or "Base", protection or nil
    end
    for _, members in pairs(lines) do
        if #members >= 2 then
            for _, encounter in ipairs(members) do encounter.rankLine = members end
        end
    end
end

ns:On("ADDON_LOADED", function(loaded)
    if loaded ~= ns.name then return end
    for professionID, GroupOf in pairs(GROUP_BY_NAME) do
        local instance = ns.Data:Get(professionID)
        for _, encounter in ipairs(instance and instance.encounters or {}) do
            nameGroup[encounter] = GroupOf(encounter.name or "")
        end
    end
    for _, professionID in ipairs({ "ENCHANTING", "ALCHEMY" }) do
        local instance = ns.Data:Get(professionID)
        if instance then MarkRankLines(instance) end
    end
end)

-- The chips of the professions whose recipes aren't worn gear (Mike,
-- 2026-10-16): their own groups in their own order (an All chip first
-- unless `noAllChip`), and how a recipe finds its group. Every other
-- profession has the slot chips (GROUPS).
local WEAPON_LOCS = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_HOLDABLE = true }
-- Enchanting groups only a made item can be in: an enchant (no item) whose
-- name has "Rod" or "Oil" in it is Other.
local ENCHANTING_ITEM_GROUPS = { RODS = true, OILS = true, IDOL = true }
-- Engineering's worn products by paper-doll order (Wishlist:Slot); any
-- other slot is Other.
local ENGINEERING_GROUP_BY_SLOT_ORDER = { [1] = "HEAD", [12] = "FEET", [14] = "TRINKET",
    [15] = "WEAPONS", [16] = "WEAPONS", [17] = "WEAPONS", [18] = "WEAPONS" }
local SCHEMES = {
    ENCHANTING = {
        groups = { { "CHEST", L["Chest"] }, { "CLOAK", L["Cloak"] }, { "BRACER", L["Bracer"] },
            { "GLOVES", L["Gloves"] }, { "BOOTS", L["Boots"] }, { "NECKLACE", L["Necklace"] },
            { "SHIELD", L["Shield"] }, { "WEAPON1H", L["1H Weapon"] }, { "WEAPON2H", L["2H Weapon"] },
            { "OFFHAND", L["Off-Hand"] }, { "WANDS", L["Wands"] }, { "RODS", L["Rods"] }, { "OILS", L["Oils"] },
            { "IDOL", L["Class Idol"] }, { "WEAPONS", L["Weapons"] }, { "OTHER", L["Other"] } },
        -- An item made: a wand, a relic, a rod, an oil, a weapon or held
        -- item; an enchant: its slot from its name.
        of = function(encounter)
            local itemID, classID, subclassID, equipLoc = ProductInfo(encounter)
            local byName = nameGroup[encounter]
            if not itemID then
                return (byName and not ENCHANTING_ITEM_GROUPS[byName]) and byName or "OTHER"
            end
            if classID == ItemClass.Weapon and subclassID == Enum.ItemWeaponSubclass.Wand then return "WANDS" end
            if equipLoc == "INVTYPE_RELIC" then return "IDOL" end
            if ENCHANTING_ITEM_GROUPS[byName] then return byName end
            if WEAPON_LOCS[equipLoc] then return "WEAPONS" end
            return "OTHER"
        end,
    },
    ALCHEMY = {
        groups = { { "POTIONS", L["Potions"] }, { "ELIXIRS", L["Elixirs"] }, { "FLASKS", L["Flasks"] },
            { "TRANSMUTES", L["Transmutes"] }, { "OILS", L["Oils"] }, { "OTHER", L["Other"] } },
        of = function(encounter) return nameGroup[encounter] or "OTHER" end,
    },
    FIRST_AID = {
        noAllChip = true,
        groups = { { "POTIONS", L["Potions"] }, { "BANDAGES", L["Bandages"] }, { "UTILITY", L["Utility"] } },
        of = function(encounter) return nameGroup[encounter] or "UTILITY" end,
    },
    ENGINEERING = {
        groups = { -- the first three as the game names those Trade Goods subclasses
            { "EXPLOSIVES", TradeGoodsName(TradeGoods.Explosives) or L["Explosives"] },
            { "PARTS", TradeGoodsName(TradeGoods.Parts) or L["Parts"] },
            { "DEVICES", TradeGoodsName(TradeGoods.Devices) or L["Devices"] }, { "FIREWORKS", L["Fireworks"] },
            { "HEAD", L["Head"] }, { "FEET", L["Feet"] }, { "TRINKET", L["Trinket"] }, { "WEAPONS", L["Weapons"] },
            { "OTHER", L["Other"] },
        },
        -- Fireworks by name first (a "Rocket" or "Firework" recipe, unless it
        -- makes something worn, which goes by its slot like any other gear:
        -- the Goblin Rocket Helmet is Head, the Rocket Boots are Feet), then
        -- the Trade Goods subclasses, then Forever's own bombs by name (they
        -- have no subclass), then head, feet and trinket by slot; guns and
        -- ammo go to Weapons.
        of = function(encounter)
            local itemID, classID, subclassID = ProductInfo(encounter)
            local isWorn = itemID ~= nil and ns.Wishlist:CanWear(itemID)
            if nameGroup[encounter] == "FIREWORKS" and not isWorn then return "FIREWORKS" end
            if classID == ItemClass.Tradegoods and subclassID == TradeGoods.Explosives then return "EXPLOSIVES" end
            if classID == ItemClass.Tradegoods and subclassID == TradeGoods.Parts then return "PARTS" end
            if classID == ItemClass.Tradegoods and subclassID == TradeGoods.Devices then return "DEVICES" end
            if nameGroup[encounter] == "EXPLOSIVES" then return "EXPLOSIVES" end
            if classID == ItemClass.Projectile then return "WEAPONS" end
            if classID == nil then return "OTHER" end
            local _, order = ns.Wishlist:Slot({ itemID = itemID })
            return ENGINEERING_GROUP_BY_SLOT_ORDER[order] or "OTHER"
        end,
    },
}
for _, scheme in pairs(SCHEMES) do
    for _, group in ipairs(scheme.groups) do LABEL[group[1]] = group[2] end
end

-- The buffs eating what `encounter` makes gives, as BUFFS keys
-- (Data/FoodBuffs.lua), or nil for a recipe that makes no such food.
local function RecipeBuffs(encounter)
    local itemID = ns.UI.RecipeProduct(encounter)
    return itemID and ns.Data:FoodBuffs(itemID)
end

-- Buff `key`'s name in the player's language (the game's own word).
local function BuffLabel(key)
    local buff = BUFF_BY_KEY[key]
    return buff and buff.label()
end

-- For the recipe filter's buff search (UI/Lists.lua).
RB.Buffs, RB.BuffLabel = RecipeBuffs, BuffLabel

-- The buffs a profession's recipes give, in BUFFS order, and how many
-- recipes give each: the Buff menu's rows.
local function BuffsOf(instance)
    local counts = {}
    for _, encounter in ipairs(instance.encounters) do
        for _, key in ipairs(not encounter.scarce and RecipeBuffs(encounter) or NO_BUFFS) do
            counts[key] = (counts[key] or 0) + 1
        end
    end
    local keys = {}
    for _, buff in ipairs(BUFFS) do
        if counts[buff.key] then table.insert(keys, buff.key) end
    end
    return keys, counts
end

-- Each profession's recipes by group, the groups it has, in chip order,
-- whether any recipe has a skill level (the range line shows only then)
-- and the buffs its foods give (the Buff box shows only with some): { of =
-- { [encounter] = key }, keys = { "ALL", ... }, hasSkills, buffKeys = {
-- "STAMINA", ... }, buffCounts = { [buff key] = recipes } }. Built once.
local groupsOf = setmetatable({}, { __mode = "k" })
local ranks = {}
function RB:Groups(instance)
    if groupsOf[instance] then return groupsOf[instance] end
    local scheme = SCHEMES[instance.id]
    local GroupOf = scheme and scheme.of or SlotOf
    local of, present, hasSkills = {}, {}, false
    for _, encounter in ipairs(instance.encounters) do
        if not encounter.scarce then
            of[encounter] = GroupOf(encounter, instance)
            present[of[encounter]] = true
            hasSkills = hasSkills or encounter.skill ~= nil
        end
    end
    local keys, notOther = {}, 0
    for _, group in ipairs(scheme and scheme.groups or GROUPS) do
        if present[group[1]] then
            table.insert(keys, group[1])
            if group[1] ~= "OTHER" then notOther = notOther + 1 end
        end
    end
    -- The chip line only shows with 2 or more groups besides Other.
    if notOther < 2 then
        keys = {}
    elseif not (scheme and scheme.noAllChip) then
        table.insert(keys, 1, "ALL")
    end
    local buffKeys, buffCounts = BuffsOf(instance)
    groupsOf[instance] = { of = of, keys = keys, hasSkills = hasSkills, buffKeys = buffKeys, buffCounts = buffCounts }
    return groupsOf[instance]
end

-- Builds a profession's groups and rank again (item info arriving late;
-- the smoke tests' made-up items).
function RB:Forget(instance)
    groupsOf[instance] = nil
    ranks[instance] = nil
end

-- Per profession, for the session: the picked chip (slot, nil: All), the
-- toggles on, the picked buff (buff, a BUFFS key; nil: any) and the
-- required skill range (minSkill, maxSkill; nil: no bound).
local states = {}
function RB:State(instance)
    states[instance.id] = states[instance.id] or { toggles = {} }
    return states[instance.id]
end

local function HasRange(state)
    return state.minSkill ~= nil or state.maxSkill ~= nil
end

-- The range's bounds, lowest first (either can be nil). Bounds typed the
-- wrong way round, 200 to 100, read as 100 to 200; the boxes keep what was
-- typed.
local function Bounds(state)
    local low, high = state.minSkill, state.maxSkill
    if low and high and low > high then return high, low end
    return low, high
end

-- Whether anything narrows the list.
function RB:Narrowing(instance)
    local state = instance and states[instance.id]
    return state ~= nil
        and (state.slot ~= nil or next(state.toggles) ~= nil or state.buff ~= nil or HasRange(state))
end

-- Back to All with the toggles off, any buff and no skill range (a jump to a recipe they hide).
function RB:Reset(instance)
    states[instance.id] = { toggles = {} }
end

-- The character's rank in the profession, or nil without it. Cached until
-- the skill lines change.
function RB:Rank(instance)
    if ranks[instance] == nil then ranks[instance] = ns.UI.SkillRank(instance) or false end
    return ranks[instance] or nil
end
ns:On("SKILL_LINES_CHANGED", function()
    wipe(ranks)
    local pane = ns.UI.encounters
    if not (pane and pane.band and pane.band:IsShown()) then return end
    RB:Paint(pane)
    pane:Refresh() -- the rows' skill colours
end)

-- Whether the character knows recipe spell `spellID` (the Poisons
-- section's Known box asks too).
function RB:IsKnown(spellID)
    return C_SpellBook.IsSpellKnown(spellID)
end

-- Whether the recipe list's band is on show with toggle `key` on (at any step).
local function IsOnInShownBand(key)
    local pane = ns.UI.encounters
    if not (pane and pane.band and pane.band:IsShown()) then return false end
    return RB:State(pane.instance).toggles[key] ~= nil
end

-- A recipe learned while Learnable is on leaves the list there and then.
ns:On("NEW_RECIPE_LEARNED", function()
    if not IsOnInShownBand("LEARNABLE") then return end
    ns.UI:RecipeNarrowed(true)
end)

-- Bags and the bank change what the character holds, so with Have
-- materials on the list narrows again. A burst of changes (looting, a bank
-- visit) narrows it once, on the next frame; Core/Shopping.lua has saved
-- the bank's counts by then. The page stays on the recipe being read even
-- when crafting it used up its materials.
local isMaterialsNarrowDue = false
local function NarrowForMaterials()
    isMaterialsNarrowDue = false
    if not IsOnInShownBand("MATERIALS") then return end
    ns.UI:RecipeNarrowed(true)
end
local function OnHoldingsChanged()
    if isMaterialsNarrowDue or not IsOnInShownBand("MATERIALS") then return end
    isMaterialsNarrowDue = true
    C_Timer.After(0, NarrowForMaterials)
end
ns:On("BAG_UPDATE_DELAYED", OnHoldingsChanged)
ns:On("BANKFRAME_OPENED", OnHoldingsChanged)
ns:On("PLAYERBANKSLOTS_CHANGED", OnHoldingsChanged)

-- The colour of `encounter`'s skill number for the character, as the game
-- colours a recipe: red while it can't be learned yet, then orange, yellow,
-- green and grey. Nil without the profession (or a class's recipe skill,
-- the rogue's Poisons) or the recipe's four levels.
function RB:SkillColor(encounter, instance)
    local rank = instance and self:Rank(instance)
    local skill = encounter.skill
    if not (rank and skill and skill[4]) then return nil end
    return ns.UI.SkillLevelColor(rank, skill)
end

-- Narrowing ----------------------------------------------------------------

-- Whether the skill `encounter` needs (skill[1]) is inside the range. A
-- recipe without a skill level is left out while a bound is set.
local function InRange(encounter, state)
    if not HasRange(state) then return true end
    local required = encounter.skill and encounter.skill[1]
    if not required then return false end
    local low, high = Bounds(state)
    return required >= (low or required) and required <= (high or required)
end

-- Whether the character can still learn `encounter` at Learnable's `step`:
-- a recipe spell it doesn't know, and at LEARNABLE_NOW one its `rank`
-- reaches (a recipe with no skill level counts as reached).
local function IsLearnable(encounter, step, rank)
    if not encounter.spellID or RB:IsKnown(encounter.spellID) then return false end
    if step ~= LEARNABLE_NOW then return true end
    local learnedAt = encounter.skill and encounter.skill[1]
    return not learnedAt or rank >= learnedAt
end

-- How many of `itemID` the character holds at Have materials' `step`: the
-- bags alone, or the bags and the character's bank. Shop:BankCount takes
-- the game's bank count, or the last bank visit's saved count when that is
-- more: whether the game knows the bank's contents before the bank is
-- opened in a session isn't checked on Forever yet, and a character that
-- never opened it with NeedRoll has no saved count. The account bank isn't
-- counted (C_Item.GetItemCount's includeAccountBank), as the Shopping List
-- doesn't count it either.
local function HeldCount(itemID, step)
    local inBags = C_Item.GetItemCount(itemID) or 0
    if step == MATERIALS_BAGS then return inBags end
    return inBags + ns.Shopping:BankCount(itemID)
end

-- Whether the character holds every material `encounter` needs, at least
-- its count of each, at Have materials' `step`. A recipe with no materials
-- in the data is left out.
local function HasMaterials(encounter, step)
    local reagents = encounter.reagents
    if not (reagents and #reagents > 0) then return false end
    for _, reagent in ipairs(reagents) do
        if HeldCount(reagent.itemID, step) < reagent.count then return false end
    end
    return true
end

-- Whether eating what `encounter` makes gives buff `key`.
local function GivesBuff(encounter, key)
    return tContains(RecipeBuffs(encounter) or NO_BUFFS, key)
end

-- encounter.skill is { orange, yellow, green, grey }: the ranks where the recipe
-- can be learned and where it stops giving skill-ups. The toggles count only
-- with the character's `rank`; the buff and the range always do.
local function Keeps(encounter, state, rank)
    if not InRange(encounter, state) then return false end
    if state.buff and not GivesBuff(encounter, state.buff) then return false end
    if not rank then return true end
    local toggles = state.toggles
    local skill = encounter.skill
    local full = skill and skill[4] ~= nil
    if toggles.SKILLUP and not (full and skill[1] <= rank and rank < skill[4]) then return false end
    if toggles.TRAINER and not ns.Names.IsLearnedFromTrainer(encounter.learned) then return false end
    if toggles.LEARNABLE and not IsLearnable(encounter, toggles.LEARNABLE, rank) then return false end
    if toggles.HIDEGREY and full and rank >= skill[4] then return false end
    if toggles.MATERIALS and not HasMaterials(encounter, toggles.MATERIALS) then return false end
    return true
end

-- `list` (recipes: a profession's, or a class's own with its skill line)
-- less what the chip, toggles, buff and skill range leave out; `list`
-- itself when nothing narrows it.
function RB:Narrow(list, instance)
    if not (list and instance and (instance.category == "PROFESSION" or instance.skillLine)) then return list end
    local state = self:State(instance)
    local rank = self:Rank(instance)
    local togglesApply = rank ~= nil and next(state.toggles) ~= nil
    if not state.slot and not togglesApply and not state.buff and not HasRange(state) then return list end
    local of = self:Groups(instance).of
    local out = {}
    for _, entry in ipairs(list) do
        if entry.header or ((not state.slot or of[entry] == state.slot) and Keeps(entry, state, rank)) then
            table.insert(out, entry)
        end
    end
    return out
end

-- Folding --------------------------------------------------------------------

-- A role series' variants take these colours in their order (Acolyte's
-- gold, Crusader's blue ...); colour words have their own (SWATCH).
local ROLE_COLOURS = { Hex("F2CF4A"), Hex("3F8BE0"), Hex("5FB85F"), Hex("D9534F"), Hex("8A5FC2"),
    Hex("E8E2D0"), Hex("E5622E") }
local NO_COLOUR = { 160, 160, 160 }

-- The set rows, one per series (Data.lua's encounter.series), named gear set
-- (encounter.family) or rank line (encounter.rankLine): they read through to
-- their first member on show, so they draw as that recipe (its icon, skill),
-- with the set's own name, note and key. row.kind says which it is.
local setRows = setmetatable({}, { __mode = "k" })
local KEY_PREFIX = { series = "SET:S:", family = "SET:F:", ranks = "SET:" }
local function RowForSet(set, kind)
    local row = setRows[set]
    if row then return row end
    row = setmetatable({ setRow = true, kind = kind, shared = set, members = {}, all = {} }, {
        __index = function(t, k)
            local first = rawget(t, "members")[1]
            return first and first[k]
        end,
    })
    -- The old field names, which the list's tests read.
    row.family, row.ranks = kind == "family" or nil, kind == "ranks" or nil
    row.key = KEY_PREFIX[kind] .. set[1].id
    setRows[set] = row
    return row
end

-- Whether `entry` is a set row (its other fields read through to a recipe).
local function IsSetRow(entry) return rawget(entry, "setRow") ~= nil end

-- The colour of variant `word` in a series row.
local function VariantColour(row, word)
    if SWATCH[word or ""] then return SWATCH[word] end
    local words = rawget(row, "shared").words or {}
    for i, variant in ipairs(words) do
        if variant == word then return ROLE_COLOURS[(i - 1) % #ROLE_COLOURS + 1] end
    end
    return NO_COLOUR
end

-- Fills a series row's members from `recipes`, the ones of the series on
-- the list. How it shows depends on what is left:
-- * "pick": several variants, some with more than one piece: the members
--   are the picked variant's pieces (row.chosen, else its first variant).
-- * "colours": one piece in each variant (a slot chip on): every recipe,
--   with a dot of each colour, as a colour set.
-- * "pieces": one variant left (a filter on): its pieces, as a gear set.
local function SettleSeries(row, recipes)
    local all = rawget(row, "all")
    if recipes ~= all then
        wipe(all)
        for _, recipe in ipairs(recipes) do table.insert(all, recipe) end
    end
    local count, variants = {}, {}
    for _, recipe in ipairs(all) do count[recipe.tint] = (count[recipe.tint] or 0) + 1 end
    for _, word in ipairs(rawget(row, "shared").words or {}) do
        if count[word] then table.insert(variants, word) end
    end
    local onePieceEach = true
    for _, word in ipairs(variants) do onePieceEach = onePieceEach and count[word] == 1 end
    local mode = #variants <= 1 and "pieces" or onePieceEach and "colours" or "pick"
    rawset(row, "mode", mode)
    rawset(row, "variants", variants)
    wipe(row.members)
    if mode ~= "pick" then
        for _, recipe in ipairs(all) do table.insert(row.members, recipe) end
        return
    end
    if not count[rawget(row, "chosen") or ""] then rawset(row, "chosen", variants[1]) end
    for _, recipe in ipairs(all) do
        if recipe.tint == row.chosen then table.insert(row.members, recipe) end
    end
end

-- Whether set row `row` offers a variant to pick, and its variants in order.
function RB:Picks(row)
    if rawget(row, "mode") ~= "pick" then return nil end
    return rawget(row, "variants")
end

-- Picks variant `word` on series row `row`: its members become that variant's pieces.
function RB:Choose(row, word)
    rawset(row, "chosen", word)
    SettleSeries(row, rawget(row, "all"))
end

-- The name of variant `word` on `row`, from the names the client shows:
-- the words of its first recipe's name that no other variant's recipes use
-- ("Guard" for Guard's Chain Belt, "Azure" for Azure Skyforged Chain Belt),
-- an English "'s" dropped. A name with no such words (German compounds)
-- comes back whole.
local function VariantName(row, word)
    local first
    local othersUse = {}
    for _, recipe in ipairs(rawget(row, "all")) do
        if recipe.tint == word then
            first = first or recipe.name
        else
            for nameWord in recipe.name:gmatch("%S+") do othersUse[nameWord] = true end
        end
    end
    if not first then return nil end
    local own = {}
    for nameWord in first:gmatch("%S+") do
        if not othersUse[nameWord] then table.insert(own, nameWord) end
    end
    if #own == 0 then return first end
    return (table.concat(own, " "):gsub("'s$", ""))
end

-- The colour and name of variant `word` on `row`, for the picker's dots.
function RB:Variant(row, word)
    return VariantColour(row, word), VariantName(row, word)
end

-- Whether `encounter` is folded under set row `row`, picked or not.
function RB:Holds(row, encounter)
    return tContains(rawget(row, "kind") == "series" and rawget(row, "all") or row.members, encounter)
end

-- The words every name shares at its start and its end ("Boots" for Flame/Pearly/... Boots).
local function SharedEnds(wordLists)
    local first = wordLists[1]
    local head = #first
    for i = 2, #wordLists do
        local words, same = wordLists[i], 0
        while same < head and same < #words and words[same + 1] == first[same + 1] do same = same + 1 end
        head = same
    end
    local tail = #first - head
    for i = 2, #wordLists do
        local words, same = wordLists[i], 0
        local room = math.min(tail, #words - head)
        while same < room and words[#words - same] == first[#first - same] do same = same + 1 end
        tail = same
    end
    local shared = {}
    for i = 1, head do table.insert(shared, first[i]) end
    for i = #first - tail + 1, #first do table.insert(shared, first[i]) end
    return shared
end

-- The first name's words that every other name has somewhere ("Skyforged" in a gear set).
local function SharedAnywhere(wordLists)
    local shared = {}
    for _, word in ipairs(wordLists[1]) do
        local everywhere = true
        for i = 2, #wordLists do everywhere = everywhere and tContains(wordLists[i], word) end
        if everywhere then table.insert(shared, word) end
    end
    return shared
end

-- Whether a set row lists one piece in each variant ("Boots": Flame ...
-- Silky Boots), so its title is the words the names share at their ends.
local function IsColourSet(row)
    return rawget(row, "mode") == "colours" or rawget(row, "kind") == "ranks"
end

-- A set row's title, kept with the names it was made from (they change once
-- the game's own arrive, or another variant is picked). German compounds
-- share no words: the first name.
local function Title(row)
    if rawget(row, "kind") == "ranks" and row.members[1].protection then return L["Protection Potions"] end
    local names = {}
    for i, encounter in ipairs(row.members) do names[i] = encounter.name end
    local namesKey = table.concat(names, "\n")
    if rawget(row, "titleKey") == namesKey then return rawget(row, "title") end
    local wordLists = {}
    for i, name in ipairs(names) do
        wordLists[i] = {}
        for word in name:gmatch("%S+") do table.insert(wordLists[i], word) end
    end
    local shared
    if IsColourSet(row) then
        shared = SharedEnds(wordLists)
    else
        shared = SharedAnywhere(wordLists)
        if #shared == 0 and rawget(row, "kind") == "family" then shared = { row.familyName } end
    end
    local title = #shared > 0 and table.concat(shared, " ") or names[1]
    rawset(row, "titleKey", namesKey)
    rawset(row, "title", title)
    return title
end

-- The set row's name with its count, "Boots ×6" (the count muted).
function RB:Name(row)
    return ("%s  %s×%d|r"):format(Title(row), Theme:ColorCode(Theme:Opaque(Theme.color.muted, Theme.color.panel2)),
        #row.members)
end

-- Its note line: a colour set's, a dot of each member's colour, then "6
-- variants"; a gear set's or a picked variant's, "8 pieces" (the list draws
-- the picker's dots before it); a rank line's, "Minor to Major · 6 ranks".
function RB:Note(row)
    local members = row.members
    if rawget(row, "kind") == "ranks" then
        if members[1].protection then return L["%d variants"]:format(#members) end
        -- The rank words are English: other clients get the count alone.
        local locale = GetLocale()
        if locale ~= "enUS" and locale ~= "enGB" then return L["%d ranks"]:format(#members) end
        local first, last = members[1].rank, members[#members].rank
        return L["%s to %s · %d ranks"]:format(first == "Base" and L["Base"] or first,
            last == "Base" and L["Base"] or last, #members)
    end
    if rawget(row, "mode") ~= "colours" then return L["%d pieces"]:format(#members) end
    local dots = {}
    for _, encounter in ipairs(members) do
        local color = VariantColour(row, encounter.tint)
        table.insert(dots, ("|T%s:7:7:0:0:64:64:0:64:0:64:%d:%d:%d|t"):format(DOT, color[1], color[2], color[3]))
    end
    return table.concat(dots, " ") .. "  " .. L["%d variants"]:format(#members)
end

-- The set `entry` folds under and its kind: a series first (Skyforged is a
-- gear set too), then a named gear set, then a rank line.
local function SetOf(entry)
    if entry.series then return entry.series, "series" end
    if entry.family then return entry.family, "family" end
    if entry.rankLine then return entry.rankLine, "ranks" end
end

-- `list` with each set that has 2 or more members in it folded into one set
-- row, where its first member was, and each series' row settled
-- (SettleSeries). A list with no sets comes back as it is.
function RB:Fold(list)
    if not list then return list end
    local membersInList, hasSet = {}, false
    for _, entry in ipairs(list) do
        local set = SetOf(entry)
        if set then
            membersInList[set] = (membersInList[set] or 0) + 1
            hasSet = hasSet or membersInList[set] >= 2
        end
    end
    if not hasSet then return list end
    local out, placed = {}, {}
    for _, entry in ipairs(list) do
        local set, kind = SetOf(entry)
        if set and membersInList[set] >= 2 then
            local row = RowForSet(set, kind)
            if not placed[set] then
                placed[set] = true
                wipe(row.members)
                table.insert(out, row)
            end
            table.insert(row.members, entry)
        else
            table.insert(out, entry)
        end
    end
    for _, row in ipairs(out) do
        if IsSetRow(row) and rawget(row, "kind") == "series" then SettleSeries(row, row.members) end
    end
    return out
end


-- Chips and the variant picker -----------------------------------------------------

local LINE_GAP = 6                     -- between lines of text tab chips, and under the last
local CHIP_PAD, CHIP_HEIGHT = 5, 15    -- a text tab's room each side of its word; its height
local CHIP_WORD_SCALE = 1.05           -- a chip's word, text tab or sidebar row: `small` at this size
local CREAM = { 0.902, 0.863, 0.784 }  -- #E6DCC8
local GOLD = { 1, 0.82, 0 }            -- #FFD100

local function RGBA(color, alpha) return color[1], color[2], color[3], alpha end

-- The variant picker: a series row's dots, one per variant, before its
-- note. Each dot is a button: a ring (gold on the picked variant, cream on
-- hover, faint otherwise) around the variant's colour; hovering names the
-- variant, a click picks it.
local PICK_DOT, PICK_FILL, PICK_GAP = 13, 9, 4  -- ring, colour inside it, between dots
local PICK_NOTE_GAP = 6                          -- after the last dot, before "8 pieces"

local function PaintPickDot(dot)
    local ring = dot.picked and GOLD or CREAM
    dot.ring:SetVertexColor(RGBA(ring, dot.picked and 1 or dot.hover and 0.9 or 0.35))
    dot.fill:SetAlpha((dot.picked or dot.hover) and 1 or 0.7)
end

local function PickDot(picker)
    local dot = CreateFrame("Button", nil, picker)
    dot:SetSize(PICK_DOT, PICK_DOT)
    dot.ring = dot:CreateTexture(nil, "ARTWORK", nil, 1)
    dot.ring:SetTexture(DOT)
    dot.ring:SetAllPoints()
    dot.gap = dot:CreateTexture(nil, "ARTWORK", nil, 2)
    dot.gap:SetTexture(DOT)
    dot.gap:SetSize(PICK_DOT - 2, PICK_DOT - 2)
    dot.gap:SetPoint("CENTER")
    dot.gap:SetVertexColor(0, 0, 0, 0.85)
    dot.fill = dot:CreateTexture(nil, "ARTWORK", nil, 3)
    dot.fill:SetTexture(DOT)
    dot.fill:SetSize(PICK_FILL, PICK_FILL)
    dot.fill:SetPoint("CENTER")
    dot:SetScript("OnEnter", function(self)
        self.hover = true
        PaintPickDot(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.label or "", unpack(Theme.tip.hint))
        GameTooltip:Show()
    end)
    dot:SetScript("OnLeave", function(self)
        self.hover = nil
        PaintPickDot(self)
        GameTooltip:Hide()
    end)
    dot:SetScript("OnClick", function(self) picker.onPick(picker:GetParent().entry, self.word) end)
    return dot
end

-- Shows the picker on list row `listRow` for set row `row`, under its title,
-- with the row's note moved after it; hides it for any other row.
-- onPick(row, word) runs when a dot is clicked.
function RB:ShowPicker(listRow, row, onPick)
    local variants = self:Picks(row)
    local picker = listRow.variantPicker
    if not variants then
        if picker then picker:Hide() end
        return
    end
    if not picker then
        picker = CreateFrame("Frame", nil, listRow)
        picker.dots = {}
        listRow.variantPicker = picker
    end
    picker.onPick = onPick
    for i, word in ipairs(variants) do
        local dot = picker.dots[i] or PickDot(picker)
        picker.dots[i] = dot
        local colour
        colour, dot.label = self:Variant(row, word)
        dot.word, dot.picked = word, word == row.chosen
        dot.fill:SetVertexColor(colour[1] / 255, colour[2] / 255, colour[3] / 255)
        dot:ClearAllPoints()
        dot:SetPoint("LEFT", (i - 1) * (PICK_DOT + PICK_GAP), 0)
        PaintPickDot(dot)
        dot:Show()
    end
    for i = #variants + 1, #picker.dots do picker.dots[i]:Hide() end
    picker:SetSize(#variants * (PICK_DOT + PICK_GAP) - PICK_GAP, PICK_DOT)
    picker:ClearAllPoints()
    picker:SetPoint("TOPLEFT", listRow.title, "BOTTOMLEFT", 0, -2)
    picker:Show()
    listRow.note:ClearAllPoints()
    listRow.note:SetPoint("LEFT", picker, "RIGHT", PICK_NOTE_GAP, 0)
end

-- A text tab chip (Mike's pick C, 2026-10-16): the word alone, a gold dot
-- before it when it follows another on its line, the picked one gold and
-- underlined. The dungeon map's floor tabs, the Poisons page's chips and
-- the floor chips on the game's map are these, on PlaceLines' lines.
local function Chip(parent)
    local chip = CreateFrame("Button", nil, parent)
    chip.text = Theme:Text(chip, Theme:ScaledFont(Theme.font.small, CHIP_WORD_SCALE))
    chip.text:SetPoint("CENTER", 0.5, 0.5)
    -- The underline: as wide as the word, solid across its middle and
    -- fading out to the word's ends (Theme:ChipUnderline).
    chip.lines = Theme:ChipUnderline(chip, chip.text)
    chip.dot = chip:CreateTexture(nil, "ARTWORK")
    chip.dot:SetTexture(DOT)
    chip.dot:SetSize(3, 3)
    -- A little left of the gap's middle: the space after it looks the
    -- smaller of the two otherwise.
    chip.dot:SetPoint("CENTER", chip, "LEFT", -1.5, 0)
    chip.dot:SetVertexColor(RGBA(GOLD, 0.5))
    chip:SetScript("OnEnter", function(self) self.hover = true; self:Paint(self.on) end)
    chip:SetScript("OnLeave", function(self) self.hover = nil; self:Paint(self.on) end)

    function chip:SetLabel(text)
        self.label = text
        self.text:SetText(text)
        self:SetSize(math.ceil(self.text:GetStringWidth()) + CHIP_PAD * 2 + 1, CHIP_HEIGHT)
    end

    -- The picked chip gold over its underline, one under the mouse cream
    -- over a faint one, the rest faint cream.
    function chip:Paint(on)
        self.on = on
        self.dot:SetShown(not self.first)
        if on then
            self.text:SetTextColor(RGBA(GOLD, 1))
            self.lines:Set(GOLD, 1, 1)
        elseif self.hover then
            self.text:SetTextColor(RGBA(CREAM, 1))
            self.lines:Set(CREAM, 0.35, 1)
        else
            self.text:SetTextColor(RGBA(CREAM, 0.72))
            self.lines:Hide()
        end
    end
    return chip
end

-- `widths` split into the fewest lines no wider than `max` (`gap` between
-- neighbours), then the split of that many lines whose widest line is
-- narrowest, so the lines come out about even. Returns the index each
-- line starts at.
local function Balance(widths, max, gap)
    local count = #widths
    local function Span(from, to)
        local width = 0
        for i = from, to do width = width + widths[i] end
        return width + gap * (to - from)
    end
    local lineCount, x = 1, -gap
    for i = 1, count do
        if x + gap + widths[i] > max and x > 0 then
            lineCount, x = lineCount + 1, widths[i]
        else
            x = x + gap + widths[i]
        end
    end
    -- best[lines][i]: the narrowest widest line putting chips i..count on that many lines.
    local best, cut = {}, {}
    for lines = 1, lineCount do best[lines], cut[lines] = {}, {} end
    for i = 1, count do best[1][i] = Span(i, count) end
    for lines = 2, lineCount do
        for i = 1, count do
            local narrowest, at = math.huge, nil
            for last = i, count - lines + 1 do
                local widest = math.max(Span(i, last), best[lines - 1][last + 1] or math.huge)
                if widest < narrowest then narrowest, at = widest, last end
            end
            best[lines][i], cut[lines][i] = narrowest, at
        end
    end
    local starts, i = {}, 1
    for lines = lineCount, 1, -1 do
        table.insert(starts, i)
        if lines > 1 then i = cut[lines][i] + 1 end
    end
    return starts
end

-- Places `chips` on centred lines from `y` down, `gap` apart (none unless
-- given); returns the y below them.
local function PlaceLines(band, chips, width, y, gap)
    if #chips == 0 then return y end
    gap = gap or 0
    local widths = {}
    for i, chip in ipairs(chips) do widths[i] = chip:GetWidth() end
    local starts = Balance(widths, width, gap)
    local height = chips[1]:GetHeight()
    for line, first in ipairs(starts) do
        local last = (starts[line + 1] or #chips + 1) - 1
        local lineWidth = 0
        for i = first, last do lineWidth = lineWidth + widths[i] end
        lineWidth = lineWidth + gap * (last - first)
        local x = math.floor((width - lineWidth) / 2 + 0.5)
        for i = first, last do
            local chip = chips[i]
            chip.first = i == first
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", band, "TOPLEFT", x, -y)
            x = x + widths[i] + gap
        end
        y = y + height + (line < #starts and LINE_GAP - 2 or 0)
    end
    return y + LINE_GAP
end

-- For the dungeon map's floor tabs (UI/Overview.lua), the Poisons page and
-- the floor chips on the game's map: text tab chips on balanced, centred lines.
RB.Chip, RB.PlaceLines = Chip, PlaceLines

-- The filter sidebar -------------------------------------------------------------

-- The Professions tab's first pane (Mike's layout G, 2026-11-18): the
-- profession's Overview row at its top (UI/Lists.lua's OverviewRow), then
-- the band of filters, each section under a divider and a gold heading: the
-- chips as a two-column list with each one's recipe count, the tick boxes
-- one to a line, Cooking's Buff box and the required skill range. The
-- sidebar scrolls when they don't fit (Large text, Enchanting's sixteen
-- chips). The count of recipes listed sits in the recipe list's strip, at
-- the right of its Filter recipes box (UI/MainFrame.lua).
local SIDEBAR_WIDTH = 236
local SIDEBAR_PAD = 10        -- the band in from the pane's sides, and the room under it
local SECTION_GAP = 8         -- above and below a section's divider
local HEADING_GAP = 4         -- under a section's heading
local TEXT_INSET = 6          -- headings, chips' words, tick boxes and the boxes in from the band's left
local CHIP_ROW_HEIGHT = 20    -- a chip in the two-column list
local CHIP_ROW_GAP = 1        -- between the list's lines
local CHIP_COLUMN_GAP = 6     -- between its two columns
local CHIP_COUNT_GAP = 4      -- the least room between a chip's word and its count
local PICKED_FILL_ALPHA = 0.14  -- the picked chip's fill: `heading` at this alpha
local TOGGLE_ROW_HEIGHT = 20  -- a tick box's line at the least (the native box is 22 high)
local COUNT_INSET = 12        -- the recipe count in from the recipe list's right edge
local COUNT_SLACK = 4         -- the count's room past the profession's whole count, for wider digits
RB.SIDEBAR_WIDTH = SIDEBAR_WIDTH
-- The Overview row, down from the top of the sidebar's canvas (UI/Lists.lua).
RB.SIDEBAR_TOP = 6

-- The required skill range: WoW: Forever's skills go up to 300.
local MIN_SKILL, MAX_SKILL = 1, 300
local RANGE_BOX_WIDTH, RANGE_BOX_HEIGHT = 36, 18
local RANGE_GAP = 8       -- between the range line's boxes, words and reset arrow
local RANGE_LINE_GAP = 6  -- between its lines, when a long translation wraps it
local RESET_SIZE = 14     -- the reset arrow, square
local RESET_TEXTURE = "Interface\\Buttons\\UI-RefreshButton"
-- The Buff box: as tall as the range boxes, its text 8 in from its left,
-- the chevron 6 in from its right with 16 kept for it, 80 wide at the least.
local BUFF_BOX_HEIGHT = RANGE_BOX_HEIGHT
local BUFF_BOX_MIN_WIDTH, BUFF_TEXT_INSET, BUFF_ARROW_INSET, BUFF_ARROW_ROOM = 80, 8, 6, 16
local BUFF_MENU_WIDTH = 200
local BUFF_MENU_GAP = 4  -- between the box and its menu

-- A section's heading: `text` in `small`, in `heading` gold.
local function NewHeading(band, text)
    local heading = Theme:Text(band, Theme.font.small)
    Theme:SetTextColor(heading, Theme.color.heading)
    if text then heading:SetText(text) end
    return heading
end

-- Starts a section `y` down the band: its divider (Theme:Divider) across
-- the band, then `heading` under that (nil: no heading). Returns the y the
-- section's first line goes at.
local function StartSection(band, heading, y)
    band.dividersUsed = band.dividersUsed + 1
    local divider = band.dividers[band.dividersUsed] or Theme:Divider(band)
    band.dividers[band.dividersUsed] = divider
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", band, "TOPLEFT", 0, -(y + SECTION_GAP))
    divider:SetPoint("RIGHT", band, "RIGHT")
    divider:Show()
    y = y + SECTION_GAP * 2 + divider:GetHeight()
    if not heading then return y end
    heading:ClearAllPoints()
    heading:SetPoint("TOPLEFT", band, "TOPLEFT", TEXT_INSET, -y)
    heading:Show()
    return y + Theme:LineHeight(heading) + HEADING_GAP
end

-- The required skill range ---------------------------------------------------

-- A range box shows its bound, unless the player is typing in it.
local function ShowBound(box, state)
    if box:HasFocus() then return end
    local value = state[box.field]
    box:SetText(value and tostring(value) or "")
end

-- The bound typed into a box (state.minSkill or state.maxSkill), kept
-- within MIN_SKILL and MAX_SKILL; an empty box is no bound.
local function SetBound(pane, field, text)
    local value = tonumber(text)
    if value then value = math.min(math.max(value, MIN_SKILL), MAX_SKILL) end
    local state = RB:State(pane.instance)
    if state[field] == value then return end
    state[field] = value
    ns.UI:RecipeNarrowed(true)
end

-- Takes the focus from both range boxes without the "done typing" step of
-- FinishTyping, for callers that narrow or swap the list themselves.
local function ReleaseBoxes(range)
    for _, box in ipairs(range.boxes) do
        box.typed = nil
        box:ClearFocus()
    end
end

local function ClearRange(pane)
    local state = RB:State(pane.instance)
    state.minSkill, state.maxSkill = nil, nil
    ReleaseBoxes(pane.band.range)
    ns.UI:RecipeNarrowed()
end

-- The player left a box they typed in. While typing, the page stays on the
-- recipe they were reading even when a half-typed bound ("1" on the way to
-- "150") leaves it off the list; now that the bound is final, a recipe
-- still off the list gives way to the first one listed.
local function FinishTyping(box, pane)
    if not box.typed then return end
    box.typed = nil
    local ui = ns.UI
    if ui.state.instance ~= pane.instance or ui.encounters:IsListed(ui.state.encounter) then return end
    ui:RecipeNarrowed()
end

-- A number box for one bound. The list narrows as the player types; the
-- band is laid out again then, but ShowBound leaves the box being typed in
-- alone, so it keeps its focus and cursor.
local function RangeBox(band, pane, field)
    local box = Theme:Input(band, RANGE_BOX_WIDTH)
    box:SetHeight(RANGE_BOX_HEIGHT)
    box:SetFontObject(Theme.font.small)
    box:SetJustifyH("CENTER")
    box:SetNumeric(true)
    box:SetMaxLetters(3)
    box.field = field
    box:SetScript("OnTextChanged", function(self, userInput)
        if not (userInput and self:HasFocus()) then return end
        self.typed = true
        SetBound(pane, field, self:GetText())
    end)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    -- A bound typed past the limits ("0", "999") shows as the one kept once
    -- the box is left. Hooked: the native box's template has its own.
    box:HookScript("OnEditFocusLost", function(self)
        ShowBound(self, RB:State(pane.instance))
        FinishTyping(self, pane)
    end)
    return box
end

local function ShowResetTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:AddLine(L["Clear the skill range"], unpack(Theme.tip.hint))
    GameTooltip:Show()
end

-- The words of the range line before, between and after its two boxes,
-- from one phrase with a %s for each box ("%s to %s"; Russian "От %s до %s"),
-- so a translation can place its words around the boxes as its language
-- needs. A phrase without two %s is all put before the boxes.
local function RangeWords()
    local phrase = L["%s to %s"]
    local before, between, after = phrase:match("^(.-)%%s(.-)%%s(.*)$")
    if not before then return phrase, "", "" end
    return before, between, after
end

-- `words` without the spaces round them, or nil for no words.
local function Trimmed(words)
    words = words:match("^%s*(.-)%s*$")
    if words == "" then return nil end
    return words
end

-- A muted word part of the range line, or nil for no words there.
local function RangeWord(band, words)
    words = Trimmed(words)
    if not words then return nil end
    local text = Theme:Text(band, Theme.font.small)
    text:SetText(words)
    Theme:SetTextColor(text, Theme.color.muted)
    return text
end

-- The range section: the heading "Required skill", then a line of the
-- boxes with the phrase's words around them and the reset arrow,
-- "[ 100 ] to [ 150 ] ↺". The line's parts, left to right, in `parts`; the
-- two boxes in `boxes`; its word parts in `words`.
local function BuildRange(band, pane)
    local range = { words = {}, parts = {} }
    range.heading = NewHeading(band, L["Required skill"])
    range.boxes = { RangeBox(band, pane, "minSkill"), RangeBox(band, pane, "maxSkill") }
    range.reset = CreateFrame("Button", nil, band)
    range.reset:SetSize(RESET_SIZE, RESET_SIZE)
    range.reset:SetNormalTexture(RESET_TEXTURE)
    range.reset:SetHighlightTexture(RESET_TEXTURE, "ADD")
    range.reset:SetScript("OnClick", function() ClearRange(pane) end)
    range.reset:SetScript("OnEnter", ShowResetTooltip)
    range.reset:SetScript("OnLeave", GameTooltip_Hide)
    local function AddWords(words)
        local text = RangeWord(band, words)
        if not text then return end
        table.insert(range.words, text)
        table.insert(range.parts, text)
    end
    local before, between, after = RangeWords()
    AddWords(before)
    table.insert(range.parts, range.boxes[1])
    AddWords(between)
    table.insert(range.parts, range.boxes[2])
    AddWords(after)
    table.insert(range.parts, range.reset)
    return range
end

local function PartWidth(part)
    return part.GetStringWidth and math.ceil(part:GetStringWidth()) or part:GetWidth()
end

-- Places `parts` (words and boxes) left to right, RANGE_GAP apart, on lines
-- `height` tall from `y` down the band. A part that would run past `width`
-- starts the next line, so a long translation wraps inside the sidebar.
-- Returns the y under the last line.
local function PlaceFlowing(band, parts, width, y, height)
    local x = TEXT_INSET
    for _, part in ipairs(parts) do
        local partWidth = PartWidth(part)
        if x > TEXT_INSET and x + partWidth > width then
            x, y = TEXT_INSET, y + height + RANGE_LINE_GAP
        end
        part:ClearAllPoints()
        part:SetPoint("LEFT", band, "TOPLEFT", x, -(y + height / 2))
        x = x + partWidth + RANGE_GAP
    end
    return y + height
end

-- Lays the range section out `y` down the band, for a profession whose
-- recipes have skill levels; returns the y under it. Its reset arrow keeps
-- its room while hidden, so nothing moves when it shows.
local function ShowRange(band, instance, width, y)
    local range = band.range
    local hasSkills = RB:Groups(instance).hasSkills
    for _, part in ipairs(range.parts) do part:SetShown(hasSkills) end
    range.heading:SetShown(hasSkills)
    if not hasSkills then return y end
    if range.instance ~= instance then
        -- Another profession: a box still being typed in lets go, so it
        -- shows this profession's bound.
        ReleaseBoxes(range)
        range.instance = instance
    end
    y = StartSection(band, range.heading, y)
    return PlaceFlowing(band, range.parts, width, y, RANGE_BOX_HEIGHT)
end

-- The buff picked ----------------------------------------------------------

-- Picks buff `key` (nil: any buff) and closes the menu.
local function PickBuff(pane, key)
    pane.band.buff.menu:Hide()
    local state = RB:State(pane.instance)
    if state.buff == key then return end
    state.buff = key
    ns.UI:RecipeNarrowed()
end

-- The Buff box shows the buff picked, in `heading`, or "Any buff" in
-- `muted`; it is lit while hovered or while its menu is open.
local function ShowPickedBuff(picker, state)
    local box = picker.box
    box.text:SetText(state.buff and BuffLabel(state.buff) or L["Any buff"])
    Theme:SetTextColor(box.text, state.buff and Theme.color.heading or Theme.color.muted)
    box.bg:SetShown(picker.menu:IsShown() or box:IsMouseOver())
end

-- "Any buff", a rule, then each buff the profession's foods give with its
-- recipe count, the one picked in `heading`. It hangs from `menuParent`,
-- the sidebar itself, so the sidebar's scroll frame doesn't cut it off.
local function CreateBuffMenu(menuParent, pane, box)
    local menu = Theme:Menu(menuParent, BUFF_MENU_WIDTH)
    menu:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -BUFF_MENU_GAP)
    menu.anchor = box
    function menu:Fill()
        self:Begin()
        local picked = RB:State(pane.instance).buff
        local groups = RB:Groups(pane.instance)
        local function AddBuff(label, key)
            local color = key == picked and Theme.color.heading or Theme.color.text
            return self:AddRow(label, color, function() PickBuff(pane, key) end)
        end
        AddBuff(L["Any buff"], nil)
        self:AddRule()
        for _, key in ipairs(groups.buffKeys) do
            local row = AddBuff(BuffLabel(key), key)
            row.count:SetText(groups.buffCounts[key])
            Theme:SetTextColor(row.count, Theme.color.muted)
        end
        self:Finish()
    end
    return menu
end

-- The Buff section: its heading, then a rounded box showing the buff picked
-- with a down chevron, as Settings' Language box; a click opens the buff
-- menu under it.
local function BuildBuffPicker(band, pane, menuParent)
    local picker = { heading = NewHeading(band, L["Buff"]) }
    local box = CreateFrame("Button", nil, band)
    box:SetHeight(BUFF_BOX_HEIGHT)
    Theme:Rounded(box, Theme.color.hover, Theme.native and Theme.color.line or Theme.color.edge)
    box.bg:Hide()
    box.text = Theme:Text(box, Theme.font.small)
    box.text:SetPoint("LEFT", BUFF_TEXT_INSET, 0)
    box.text:SetPoint("RIGHT", -BUFF_ARROW_ROOM, 0)
    box.text:SetJustifyH("LEFT")
    box.arrow = Theme:SortMark(box)
    box.arrow:SetPoint("RIGHT", -BUFF_ARROW_INSET, 0)
    box.arrow:SetDescending(true)
    picker.box = box
    picker.menu = CreateBuffMenu(menuParent, pane, box)
    local function ShowState() ShowPickedBuff(picker, RB:State(pane.instance)) end
    box:SetScript("OnClick", function()
        picker.menu:SetShown(not picker.menu:IsShown())
        ShowState()
    end)
    box:SetScript("OnEnter", function() box.bg:Show() end)
    box:SetScript("OnLeave", ShowState)
    picker.menu:HookScript("OnHide", ShowState)
    -- A menu left open would show again with the band.
    band:HookScript("OnHide", function() picker.menu:Hide() end)
    return picker
end

-- Sizes the Buff box for its widest choice ("Any buff" or any of the
-- profession's buffs), so picking another moves nothing; never past the
-- band's `width`.
local function FitBuffBox(picker, buffKeys, width)
    local text = picker.box.text
    text:SetText(L["Any buff"])
    local widest = math.ceil(text:GetUnboundedStringWidth())
    for _, key in ipairs(buffKeys) do
        text:SetText(BuffLabel(key))
        widest = math.max(widest, math.ceil(text:GetUnboundedStringWidth()))
    end
    local fitted = math.max(BUFF_BOX_MIN_WIDTH, widest + BUFF_TEXT_INSET + BUFF_ARROW_ROOM)
    picker.box:SetWidth(math.min(fitted, width - TEXT_INSET))
end

-- Lays the Buff section out `y` down the band, for a profession whose foods
-- give buffs; returns the y under it. Another profession closes the menu.
local function ShowBuffPicker(band, instance, width, y)
    local picker = band.buff
    if picker.instance ~= instance then
        picker.menu:Hide()
        picker.instance = instance
    end
    local buffKeys = RB:Groups(instance).buffKeys
    local hasBuffs = #buffKeys > 0
    picker.heading:SetShown(hasBuffs)
    picker.box:SetShown(hasBuffs)
    if not hasBuffs then return y end
    FitBuffBox(picker, buffKeys, width)
    y = StartSection(band, picker.heading, y)
    picker.box:ClearAllPoints()
    picker.box:SetPoint("TOPLEFT", band, "TOPLEFT", TEXT_INSET, -y)
    return y + BUFF_BOX_HEIGHT
end

-- The chips ----------------------------------------------------------------

local function PickChip(pane, key)
    local state = RB:State(pane.instance)
    state.slot = (key ~= "ALL" and state.slot ~= key) and key or nil
    ns.UI:RecipeNarrowed()
end

-- Sets toggle `key` to `value` (true or a step; false or nil: off).
local function SetToggle(pane, key, value)
    local state = RB:State(pane.instance)
    state.toggles[key] = value or nil
    ns.UI:RecipeNarrowed()
end

-- Each group's recipe count: under the toggles, buff, skill range (`state`)
-- and text filter (`base`, the list before the chip narrows it), or of all
-- its recipes.
local function Counts(instance, base, state, rank)
    local of = RB:Groups(instance).of
    local counts = { ALL = 0 }
    for _, entry in ipairs(base or instance.encounters) do
        if not entry.header and not entry.scarce and (not state or Keeps(entry, state, rank)) then
            counts.ALL = counts.ALL + 1
            local key = of[entry]
            if key then counts[key] = (counts[key] or 0) + 1 end
        end
    end
    return counts
end

-- How many recipes `instance` has, its Scarce reagents left out: the
-- profession bar's tooltips (UI/ProfessionBar.lua) and the count beside
-- Filter recipes.
local function RecipeCount(instance)
    local count = 0
    for _, entry in ipairs(instance.encounters) do
        if not entry.header and not entry.scarce then count = count + 1 end
    end
    return count
end
RB.RecipeCount = RecipeCount

-- A chip in the list: the picked one's word gold on a faint gold fill, one
-- under the mouse on the hover fill, the rest plain.
local function PaintChipRow(chip)
    local colors = Theme.color
    Theme:SetTextColor(chip.text, chip.picked and colors.heading or colors.text)
    if chip.picked then
        chip.bg:SetVertexColor(RGBA(colors.heading, PICKED_FILL_ALPHA))
    else
        chip.bg:SetVertexColor(unpack(colors.hover))
    end
    chip.bg:SetShown((chip.picked or chip.hover) and true or false)
end

-- One of the sidebar's chips: its word at the left (cut short when it
-- doesn't fit) and its recipe count, `muted`, at the right. A click picks it.
local function ChipRow(band, pane)
    local chip = CreateFrame("Button", nil, band)
    chip:SetHeight(CHIP_ROW_HEIGHT)
    Theme:Rounded(chip, Theme.color.hover)
    chip.bg:Hide()
    chip.count = Theme:Text(chip, Theme.font.small)
    chip.count:SetPoint("RIGHT", -TEXT_INSET, 0)
    chip.count:SetJustifyH("RIGHT")
    Theme:SetTextColor(chip.count, Theme.color.muted)
    chip.text = Theme:Text(chip, Theme:ScaledFont(Theme.font.small, CHIP_WORD_SCALE))
    chip.text:SetPoint("LEFT", TEXT_INSET, 0)
    chip.text:SetPoint("RIGHT", chip.count, "LEFT", -CHIP_COUNT_GAP, 0)
    chip.text:SetJustifyH("LEFT")
    chip:SetScript("OnEnter", function(self) self.hover = true; PaintChipRow(self) end)
    chip:SetScript("OnLeave", function(self) self.hover = nil; PaintChipRow(self) end)
    chip:SetScript("OnClick", function(self) PickChip(pane, self.key) end)
    return chip
end

-- The chips' heading: "Slot" over slot chips, "Type" over the groups of the
-- professions whose recipes aren't worn gear (SCHEMES).
local function ChipsHeading(instance)
    return SCHEMES[instance.id] and L["Type"] or L["Slot"]
end

-- Lays the profession's chips out `y` down the band under their heading,
-- two to a line in chip order; returns the y under them (`y` itself for a
-- profession with no chips). Every count is as wide as the profession's
-- whole count, so each word keeps its room whatever narrows the list.
local function ShowChips(band, pane, instance, width, y)
    local keys = RB:Groups(instance).keys
    for i = #keys + 1, #band.chips do band.chips[i]:Hide() end
    band.chipsHeading:SetShown(#keys > 0)
    if #keys == 0 then return y end
    band.chipsHeading:SetText(ChipsHeading(instance))
    y = StartSection(band, band.chipsHeading, y)
    local columnWidth = math.floor((width - CHIP_COLUMN_GAP) / 2)
    for i, key in ipairs(keys) do
        local chip = band.chips[i] or ChipRow(band, pane)
        band.chips[i] = chip
        chip.key, chip.label = key, LABEL[key]
        chip.text:SetText(chip.label)
        local column, line = (i - 1) % 2, math.floor((i - 1) / 2)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", band, "TOPLEFT", column * (columnWidth + CHIP_COLUMN_GAP),
            -(y + line * (CHIP_ROW_HEIGHT + CHIP_ROW_GAP)))
        chip:SetWidth(columnWidth)
        chip:Show()
    end
    local measure = band.chips[1].count
    measure:SetText(RecipeCount(instance))
    local countWidth = math.ceil(measure:GetUnboundedStringWidth())
    for i = 1, #keys do band.chips[i].count:SetWidth(countWidth) end
    local lines = math.ceil(#keys / 2)
    return y + lines * CHIP_ROW_HEIGHT + (lines - 1) * CHIP_ROW_GAP
end

-- The tick boxes -------------------------------------------------------------

-- A stepped box's tooltip: its label, then its spec's text for the step it is at.
local function ShowStepTooltip(box)
    GameTooltip:SetOwner(box, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine(box.label:GetText())
    local r, g, b = unpack(Theme.tip.text)
    GameTooltip:AddLine(box.tooltip(box.step), r, g, b, true)
    GameTooltip:Show()
end

-- Shows a stepped box's `step` (false: off): ticked from the first step on,
-- the tick greyed at every step before the last.
local function ShowStep(box, step)
    box.step = step or false
    box:Set(box.step ~= false)
    box:SetMarkMuted(box.step ~= false and box.nextStep[box.step] ~= false)
    if GameTooltip:IsOwned(box) then ShowStepTooltip(box) end
end

-- A tick box for toggle `spec`; a stepped one moves to its next step on a
-- click and names its step in a tooltip.
local function ToggleBox(holder, pane, spec)
    if not spec.nextStep then
        return Theme:CheckBox(holder, spec.label, function(on) SetToggle(pane, spec.key, on) end)
    end
    local box = Theme:CheckBox(holder, spec.label)
    box.nextStep, box.tooltip = spec.nextStep, spec.tooltip
    box:SetScript("OnClick", function(self)
        ShowStep(self, self.nextStep[self.step])
        SetToggle(pane, spec.key, self.step)
    end)
    box:SetScript("OnEnter", ShowStepTooltip)
    box:SetScript("OnLeave", GameTooltip_Hide)
    ShowStep(box, false)
    return box
end

-- Lays the toggles out `y` down the band, one tick box to a line under
-- their "Show" heading, while the character has the profession; returns
-- the y under them. Each box sits on a holder as wide as the box and its
-- label.
local function ShowToggles(band, pane, hasProfession, y)
    band.togglesHeading:SetShown(hasProfession)
    if hasProfession then y = StartSection(band, band.togglesHeading, y) end
    for i, spec in ipairs(TOGGLES) do
        local holder = band.toggles[i]
        if not holder then
            holder = CreateFrame("Frame", nil, band)
            holder.key = spec.key
            holder.box = ToggleBox(holder, pane, spec)
            holder.box:SetPoint("LEFT")
            band.toggles[i] = holder
        end
        -- Sized on every layout: the text size can change meanwhile.
        local height = math.max(holder.box:GetHeight(), TOGGLE_ROW_HEIGHT)
        holder:SetSize(math.ceil(holder.box:FullWidth()), height)
        holder:SetShown(hasProfession)
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", band, "TOPLEFT", TEXT_INSET, -y)
        if hasProfession then y = y + height end
    end
    return y
end

-- The sidebar ------------------------------------------------------------------

-- Makes the filter sidebar on `parent` for recipe list `pane`: a list pane
-- SIDEBAR_WIDTH wide that scrolls as the Settings page does
-- (ns.Settings.AddScrolling), the band of filters on its canvas, and the
-- recipe count in the list's strip. The caller places and shows it.
function RB:CreateSidebar(parent, pane)
    local sidebar = Theme:CreatePanel(parent, "list")
    sidebar:SetWidth(SIDEBAR_WIDTH)
    sidebar.offset = 0
    sidebar.canvas = ns.Settings.AddScrolling(sidebar)
    sidebar.canvas:SetWidth(SIDEBAR_WIDTH)
    sidebar:Hide()
    local band = CreateFrame("Frame", nil, sidebar.canvas)
    band.chips, band.toggles, band.dividers, band.dividersUsed = {}, {}, {}, 0
    band.chipsHeading = NewHeading(band)
    band.togglesHeading = NewHeading(band, L["Show"])
    band.buff = BuildBuffPicker(band, pane, sidebar)
    band.range = BuildRange(band, pane)
    band.count = Theme:Text(pane, Theme.font.small)
    band.count:SetPoint("RIGHT", pane, "TOPRIGHT", -COUNT_INSET, -Theme.size.paneLabel / 2)
    band.count:SetJustifyH("RIGHT")
    band.count:Hide()
    band:Hide()
    pane.band, pane.sidebar = band, sidebar
    return sidebar
end

-- Makes the sidebar's canvas `height` tall: it scrolls back to the top for
-- another profession and keeps its place for the same one.
local function FitSidebar(sidebar, height, instance)
    sidebar.canvas:SetHeight(height)
    if sidebar.instance ~= instance then sidebar.offset = 0 end
    sidebar.instance = instance
    ns.Settings.ScrollPageTo(sidebar, sidebar.offset)
end

-- Shows the recipe count in the list's strip, as wide as the profession's
-- whole count (and COUNT_SLACK), so the Filter recipes box at its left
-- keeps its width while the list narrows.
local function ShowCount(band, instance)
    local count = band.count
    count:SetText(L["%d recipes"]:format(RecipeCount(instance)))
    count:SetWidth(math.ceil(count:GetUnboundedStringWidth()) + COUNT_SLACK)
    count:Show()
end

-- Lays the filters out for `instance` on the sidebar, `top` down its
-- canvas (under the Overview row), and fits the canvas to them. The same
-- profession is always as tall, whatever is picked, ticked or typed.
-- Returns the band's height (0 when hidden: a list that isn't a
-- profession's, or one with no recipes).
function RB:Layout(pane, instance, top)
    local band = pane.band
    if not (instance and instance.category == "PROFESSION") then
        band:Hide()
        band.count:Hide()
        FitSidebar(pane.sidebar, top + SIDEBAR_PAD, instance)
        return 0
    end
    local width = SIDEBAR_WIDTH - SIDEBAR_PAD * 2
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", band:GetParent(), "TOPLEFT", SIDEBAR_PAD, -top)
    band:SetWidth(width)
    band.dividersUsed = 0
    local y = ShowChips(band, pane, instance, width, 0)
    y = ShowToggles(band, pane, self:Rank(instance) ~= nil, y)
    y = ShowBuffPicker(band, instance, width, y)
    y = ShowRange(band, instance, width, y)
    for i = band.dividersUsed + 1, #band.dividers do band.dividers[i]:Hide() end
    band:SetHeight(math.max(y, 1))
    band:Show()
    ShowCount(band, instance)
    FitSidebar(pane.sidebar, top + y + SIDEBAR_PAD, instance)
    self:Paint(pane)
    return y
end

-- Ticks the toggles on, shows the range's bounds and the buff picked,
-- lights the picked chip, and writes each chip's count (under the toggles,
-- buff, range and text filter: the picked chip's is the count listed) and
-- the count of recipes listed.
function RB:Paint(pane)
    local band, instance = pane.band, pane.instance
    if not (band and instance and instance.category == "PROFESSION") then return end
    local state = self:State(instance)
    local counts = Counts(instance, pane.recipeBase, state, self:Rank(instance))
    for _, chip in ipairs(band.chips) do
        if chip:IsShown() then
            chip.picked = (state.slot or "ALL") == chip.key
            chip.count:SetText(counts[chip.key] or 0)
            PaintChipRow(chip)
        end
    end
    for _, holder in ipairs(band.toggles) do
        local value = state.toggles[holder.key]
        if holder.box.nextStep then ShowStep(holder.box, value) else holder.box:Set(value == true) end
    end
    ShowPickedBuff(band.buff, state)
    local range = band.range
    for _, box in ipairs(range.boxes) do ShowBound(box, state) end
    range.reset:SetShown(range.boxes[1]:IsShown() and HasRange(state))
    band.count:SetText(L["%d recipes"]:format(pane.narrowedCount or RecipeCount(instance)))
    Theme:SetTextColor(band.count, Theme.color.muted)
end
