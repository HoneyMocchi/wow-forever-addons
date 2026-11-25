-- Data names in the player's language. The data files are written in
-- English; on any other client the game is asked for each name by its ID
-- and the data is updated in place, so every list, page and search shows
-- the game's own names:
--     dungeons, raids, battlegrounds  GetRealZoneText(instance map ID)
--     zones                           C_Map.GetMapInfo(uiMapID)
--     factions                        the reputation's name by faction ID
--     currencies                      C_CurrencyInfo.GetCurrencyInfo(currency ID)
--     recipes                         C_Spell.GetSpellName(spell ID)
--     bosses, quest givers, droppers  a creature link's tooltip
--     quests                          a quest link's tooltip (title, objective)
--     items named in quests           C_Item, once loaded
-- The game only has NPCs and quests once the server has sent them: the
-- first ask comes back empty and starts the fetch, so they are asked for in
-- the background after login, a few a second, and kept in NeedRollDB.names
-- so later sessions have them at once. Anything the game doesn't give
-- stays English.
-- Fixed labels in the data (wing names, recipe sources, collection groups,
-- attunement notes) go through ns.L, so they follow NeedRoll's language
-- (Settings, Language) rather than the client's. An English client keeps the
-- game's names exactly as the data writes them, places NeedRoll translates
-- itself included (PLACES); with another language picked there, only the
-- fixed labels change.
local _, ns = ...
local L = ns.L

local Names = {}
ns.Names = Names

local LOCALE = GetLocale()
-- Only a client in another language has names of its own to ask the game for.
local isOtherClientLanguage = LOCALE ~= "enUS" and LOCALE ~= "enGB"
-- NeedRoll's text loaded in English (ns.L), so its labels need no rewriting.
local isTextInEnglish = ns.loadedLanguage == "enUS"

-- Fixed labels --------------------------------------------------------------

-- Wings and halves of one instance: the game names the instance, these the part.
local WINGS = {
    SM_GRAVEYARD = L["%s: Graveyard"], SM_LIBRARY = L["%s: Library"],
    SM_ARMORY = L["%s: Armory"], SM_CATHEDRAL = L["%s: Cathedral"],
    DM_EAST = L["%s: East"], DM_WEST = L["%s: West"], DM_NORTH = L["%s: North"],
    STRAT_LIVE = L["%s: Live"], STRAT_UNDEAD = L["%s: Undead"],
    LBRS = L["Lower %s"], UBRS = L["Upper %s"],
}

-- Battlegrounds' instance map IDs.
local BATTLEGROUNDS = { ["Alterac Valley"] = 30, ["Warsong Gulch"] = 489, ["Arathi Basin"] = 529 }

-- Zones by their uiMapID.
local ZONE_MAPS = {
    ["Alterac Mountains"] = 1416, ["Ashenvale"] = 1440, ["Azshara"] = 1447, ["Badlands"] = 1418,
    ["Burning Steppes"] = 1428, ["Desolace"] = 1443, ["Dun Morogh"] = 1426, ["Dustwallow Marsh"] = 1445,
    ["Eastern Plaguelands"] = 1423, ["Felwood"] = 1448, ["Feralas"] = 1444, ["Ironforge"] = 1455,
    ["Mulgore"] = 1412, ["Orgrimmar"] = 1454, ["Silithus"] = 1451, ["Silverpine Forest"] = 1421,
    ["Stormwind City"] = 1453, ["Stranglethorn Vale"] = 1434, ["Swamp of Sorrows"] = 1435,
    ["Tanaris"] = 1446, ["The Barrens"] = 1413, ["Tirisfal Glades"] = 1420,
    ["Western Plaguelands"] = 1422, ["Westfall"] = 1436, ["Wetlands"] = 1437, ["Winterspring"] = 1452,
}

-- PvP vendors stand under a reputation's name.
local FACTION_ZONES = {
    ["Frostwolf Clan"] = 729, ["Stormpike Guard"] = 730, ["Silverwing Sentinels"] = 890,
    ["Warsong Outriders"] = 889, ["League of Arathor"] = 509, ["The Defilers"] = 510,
}

-- Places the game has names for but NeedRoll can't ask it about. These
-- phrases stand in for the game's names, so like the game's they change only
-- on a client in another language: on an English client the data's English
-- names stay whatever language NeedRoll's text is in. That also keeps the
-- dungeons without a map ID recognisable from inside, by the name the game
-- gives (ns.Data:IsPlayerInside).
local PLACES = {
    ["Blackrock Mountain"] = L["Blackrock Mountain"], ["Mount Hyjal"] = L["Mount Hyjal"],
    ["Dalaran"] = L["Dalaran"], ["Yojamba Isle"] = L["Yojamba Isle"],
    ["Blackrock Depths"] = L["Blackrock Depths"],
    -- WoW: Forever instances still without a map ID in Data/Maps.lua (a map ID wins)
    ["Hall of Thanes"] = L["Hall of Thanes"], ["Ruins of Lordaeron"] = L["Ruins of Lordaeron"],
    ["Excavation Site: Wetlands"] = L["Excavation Site: Wetlands"], ["City of Dalaran"] = L["City of Dalaran"],
    ["The Drowned City"] = L["The Drowned City"], ["Krol'dok Stronghold"] = L["Krol'dok Stronghold"],
    ["Alcaz Prison"] = L["Alcaz Prison"], ["Blackmaw Hold"] = L["Blackmaw Hold"],
    ["Shaper's Terrace"] = L["Shaper's Terrace"], ["The Barrow Deeps"] = L["The Barrow Deeps"],
    ["Hyjal Summit"] = L["Hyjal Summit"],
}

-- NeedRoll's own labels for kinds and groups the game has no name for. They
-- follow NeedRoll's language, on an English client too.
local LABELS = {
    ["Primary profession"] = L["Primary profession"], ["Secondary profession"] = L["Secondary profession"],
    ["Holiday"] = L["Holiday"], ["World event"] = L["World event"], ["Collection"] = L["Collection"],
    ["Item sets"] = L["Item sets"], ["World drops"] = L["World drops"],
    -- Professions
    ["Alchemy"] = L["Alchemy"], ["Blacksmithing"] = L["Blacksmithing"], ["Cooking"] = L["Cooking"],
    ["Enchanting"] = L["Enchanting"], ["Engineering"] = L["Engineering"], ["First Aid"] = L["First Aid"],
    ["Fishing"] = L["Fishing"], ["Herbalism"] = L["Herbalism"], ["Leatherworking"] = L["Leatherworking"],
    ["Mining"] = L["Mining"], ["Skinning"] = L["Skinning"], ["Tailoring"] = L["Tailoring"],
    ["Camping"] = L["Camping"],
    -- Collections
    ["Abyssal Council"] = L["Abyssal Council"], ["Ahn'Qiraj Gates"] = L["Ahn'Qiraj Gates"],
    ["Ahn'Qiraj Sets"] = L["Ahn'Qiraj Sets"], ["Children's Week"] = L["Children's Week"],
    ["Companions"] = L["Companions"], ["Darkmoon Faire"] = L["Darkmoon Faire"],
    ["Dungeon Sets"] = L["Dungeon Sets"], ["Elemental Invasions"] = L["Elemental Invasions"],
    ["Feast of Winter Veil"] = L["Feast of Winter Veil"], ["Fishing Extravaganza"] = L["Fishing Extravaganza"],
    ["Gurubashi Arena"] = L["Gurubashi Arena"], ["Hallow's End"] = L["Hallow's End"],
    ["Harvest Festival"] = L["Harvest Festival"], ["Legendaries"] = L["Legendaries"],
    ["Love is in the Air"] = L["Love is in the Air"], ["Lunar Festival"] = L["Lunar Festival"],
    ["Midsummer Fire Festival"] = L["Midsummer Fire Festival"], ["Mounts"] = L["Mounts"],
    ["Noblegarden"] = L["Noblegarden"], ["Other Sets"] = L["Other Sets"],
    ["Scourge Invasion"] = L["Scourge Invasion"], ["Tabards"] = L["Tabards"], ["Tier Sets"] = L["Tier Sets"],
    ["World Epics"] = L["World Epics"], ["Zul'Gurub Sets"] = L["Zul'Gurub Sets"],
    -- The Tarnished Undermine Real's list: its vendor's sections
    ["Trinkets"] = L["Trinkets"], ["Cloaks"] = L["Cloaks"], ["Rings"] = L["Rings"], ["Belts"] = L["Belts"],
    ["Idols, Librams and Totems"] = L["Idols, Librams and Totems"],
    -- PvP
    ["Honor Ranks"] = L["Honor Ranks"], ["Any rank"] = L["Any rank"], ["Any standing"] = L["Any standing"],
    ["New in Forever"] = L["New in Forever"], ["Premier"] = L["Premier"],
    ["Private"] = L["Private"], ["Corporal"] = L["Corporal"], ["Sergeant"] = L["Sergeant"],
    ["Master Sergeant"] = L["Master Sergeant"], ["Sergeant Major"] = L["Sergeant Major"],
    ["Knight"] = L["Knight"], ["Knight-Lieutenant"] = L["Knight-Lieutenant"],
    ["Knight-Captain"] = L["Knight-Captain"], ["Knight-Champion"] = L["Knight-Champion"],
    ["Lieutenant Commander"] = L["Lieutenant Commander"], ["Commander"] = L["Commander"],
    ["Marshal"] = L["Marshal"], ["Field Marshal"] = L["Field Marshal"], ["Grand Marshal"] = L["Grand Marshal"],
    ["Scout"] = L["Scout"], ["Grunt"] = L["Grunt"], ["Senior Sergeant"] = L["Senior Sergeant"],
    ["First Sergeant"] = L["First Sergeant"], ["Stone Guard"] = L["Stone Guard"],
    ["Blood Guard"] = L["Blood Guard"], ["Legionnaire"] = L["Legionnaire"], ["Centurion"] = L["Centurion"],
    ["Champion"] = L["Champion"], ["Lieutenant General"] = L["Lieutenant General"],
    ["General"] = L["General"], ["Warlord"] = L["Warlord"], ["High Warlord"] = L["High Warlord"],
    -- Collection groups
    ["Crafting"] = L["Crafting"], ["Drops"] = L["Drops"], ["Equip"] = L["Equip"], ["Masks"] = L["Masks"],
    ["One-Handed Weapons"] = L["One-Handed Weapons"], ["Two-Handed Weapons"] = L["Two-Handed Weapons"],
    ["Ranged Weapons & Shield"] = L["Ranged Weapons & Shield"],
    ["Trinket & Finger & Neck"] = L["Trinket & Finger & Neck"], ["Wands"] = L["Wands"],
    ["Plans"] = L["Plans"], ["PvP"] = L["PvP"], ["Quest"] = L["Quest"], ["Quest Item"] = L["Quest Item"],
    ["Rare Fish"] = L["Rare Fish"], ["Rare Fish Rewards"] = L["Rare Fish Rewards"],
    ["Reputation"] = L["Reputation"], ["Special"] = L["Special"], ["Ticket Rewards"] = L["Ticket Rewards"],
    ["Vendor"] = L["Vendor"], ["World Events"] = L["World Events"], ["Faction Mounts"] = L["Faction Mounts"],
    ["First Prize"] = L["First Prize"], ["Darkmoon Cards"] = L["Darkmoon Cards"],
    ["Midsummer Festival"] = L["Midsummer Festival"], ["Winter Veil"] = L["Winter Veil"],
    ["Ahn'Qiraj"] = L["Ahn'Qiraj"],
    -- Encounters that aren't one boss
    ["Trash Drops"] = L["Trash Drops"], ["Gordok Tribute"] = L["Gordok Tribute"], ["Ring of Law"] = L["Ring of Law"],
    ["The Seven"] = L["The Seven"], ["The Four Horsemen"] = L["The Four Horsemen"], ["Twin Emperors"] = L["Twin Emperors"],
    ["The Lost Dwarves"] = L["The Lost Dwarves"], ["Jarien and Sothos"] = L["Jarien and Sothos"],
}

-- Quest givers that are objects: the game has no lookup for their names.
local OBJECTS = {
    ["Broken Trap"] = L["Broken Trap"], ["KILL ON SIGHT"] = L["KILL ON SIGHT"], ["WANTED"] = L["WANTED"],
    ["Remains of a Paladin"] = L["Remains of a Paladin"], ["Talvash's Scrying Bowl"] = L["Talvash's Scrying Bowl"],
    ["The Discs of Norgannon"] = L["The Discs of Norgannon"], ["The Sparklematic 5200"] = L["The Sparklematic 5200"],
}

-- Raid attunement and item chain notes (Data/Attunements.lua,
-- Data/ItemChains.lua). An {item:ID:Name} or {quest:ID:Name} keeps its ID
-- and a {boss:INSTANCE:ENCOUNTER} its IDs; the names shown are the game's
-- and the boss list's.
local NOTES = {
    ["Optional. Without it you reach the Core through Blackrock Depths; with it, Lothos Riftwaker teleports you in."] =
        L["Optional. Without it you reach the Core through Blackrock Depths; with it, Lothos Riftwaker teleports you in."],
    ["Finishing the chain gives you the {item:16309:Drakefire Amulet}, which opens Onyxia's Lair."] =
        L["Finishing the chain gives you the {item:16309:Drakefire Amulet}, which opens Onyxia's Lair."],
    ["Needed to enter Blackwing Lair."] = L["Needed to enter Blackwing Lair."],
    ["Needs Honored with the Argent Dawn. The higher your standing, the less it costs."] =
        L["Needs Honored with the Argent Dawn. The higher your standing, the less it costs."],
    ["{boss:SM_LIBRARY:ARCANIST_DOAN} drops the {item:7146:The Scarlet Key}. It unlocks the doors to the Armory and the Cathedral, and a gate inside Stratholme. One key in the group is enough."] =
        L["{boss:SM_LIBRARY:ARCANIST_DOAN} drops the {item:7146:The Scarlet Key}. It unlocks the doors to the Armory and the Cathedral, and a gate inside Stratholme. One key in the group is enough."],
    ["Alliance players get the {item:277507:Dalaran Sewer Key} from {quest:92458:Heart of Disruption}, Horde players from {quest:92434:Blood in the Streets}. One key in the group is enough to get in."] =
        L["Alliance players get the {item:277507:Dalaran Sewer Key} from {quest:92458:Heart of Disruption}, Horde players from {quest:92434:Blood in the Streets}. One key in the group is enough to get in."],
    ["Summons {boss:CITY_OF_DALARAN:LYN_THE_IGNORED}, an optional boss here. Defeat {boss:SHADOWFANG:ARCHMAGE_ARUGAL} and pick up the {item:276561:Black Tome} lying near him, then use it at the Ambermill Leyline Focus in Silverpine Forest to make the {item:275989:Tome of Dalaran}. One tome is enough for the group."] =
        L["Summons {boss:CITY_OF_DALARAN:LYN_THE_IGNORED}, an optional boss here. Defeat {boss:SHADOWFANG:ARCHMAGE_ARUGAL} and pick up the {item:276561:Black Tome} lying near him, then use it at the Ambermill Leyline Focus in Silverpine Forest to make the {item:275989:Tome of Dalaran}. One tome is enough for the group."],
    ["The second quest gives the {item:11000:Shadowforge Key}, which unlocks the Shadowforge gate inside Blackrock Depths. One key in the group is enough."] =
        L["The second quest gives the {item:11000:Shadowforge Key}, which unlocks the Shadowforge gate inside Blackrock Depths. One key in the group is enough."],
    ["The last quest gives the {item:13704:Skeleton Key}, which unlocks the door of Scholomance. One key in the group is enough."] =
        L["The last quest gives the {item:13704:Skeleton Key}, which unlocks the door of Scholomance. One key in the group is enough."],
    ["Not needed to enter the Core. Duke Hydraxis's quests earn you the {item:17333:Aqual Quintessence}, which puts out the runes by the Core's bosses; once every rune is out, Majordomo Executus appears. Agent of Hydraxis needs Honored with the Hydraxian Waterlords."] =
        L["Not needed to enter the Core. Duke Hydraxis's quests earn you the {item:17333:Aqual Quintessence}, which puts out the runes by the Core's bosses; once every rune is out, Majordomo Executus appears. Agent of Hydraxis needs Honored with the Hydraxian Waterlords."],
    ["Not needed to enter. Once one player on the realm finishes this chain, the gates of Ahn'Qiraj open for everyone. From Anachronos on, its quests need at least Neutral with the Brood of Nozdormu. The red, green and blue shards can be won side by side."] =
        L["Not needed to enter. Once one player on the realm finishes this chain, the gates of Ahn'Qiraj open for everyone. From Anachronos on, its quests need at least Neutral with the Brood of Nozdormu. The red, green and blue shards can be won side by side."],
}

-- Reputation standings, numbered as the game's FACTION_STANDING_LABEL1-8 (API.lua reads them too).
local STANDINGS = { Neutral = 4, Friendly = 5, Honored = 6, Revered = 7, Exalted = 8 }
Names.STANDINGS = STANDINGS

-- The parts of a recipe's "learned" line and of encounter notes.
local PARTS = {
    ["Recipe"] = L["Recipe"], ["Trainer"] = L["Trainer"], ["Vendor"] = L["Vendor"], ["Drop"] = L["Drop"],
    ["Quest"] = L["Quest"], ["Starting recipe"] = L["Starting recipe"],
    ["Rare"] = L["Rare"], ["Zone-wide"] = L["Zone-wide"], ["Requirement unknown"] = L["Requirement unknown"],
    ["Tribute run chest"] = L["Tribute run chest"], ["Honor and marks"] = L["Honor and marks"],
    ["Armorsmith"] = L["Armorsmith"], ["Weaponsmith"] = L["Weaponsmith"], ["Axesmith"] = L["Axesmith"],
    ["Hammersmith"] = L["Hammersmith"], ["Swordsmith"] = L["Swordsmith"],
    ["Dragonscale"] = L["Dragonscale"], ["Elemental"] = L["Elemental"], ["Tribal"] = L["Tribal"],
    ["Gnomish"] = L["Gnomish"], ["Goblin"] = L["Goblin"],
    ["Cloth"] = L["Cloth"], ["Leather"] = L["Leather"], ["Mail"] = L["Mail"], ["Plate"] = L["Plate"],
    ["Misc"] = L["Misc"],
}

local function Part(text)
    local rank = text:match("^Rank (%d+)$")
    if rank then return L["Rank %d"]:format(tonumber(rank)) end
    local class = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[text:upper()]
    return PARTS[text] or class or text
end

-- A recipe's learned line and an encounter's note join their parts with
-- this ("Trainer · Recipe"; ns.DOT, "∙" where Russian text shows).
local PART_SEPARATOR = " " .. ns.DOT .. " "

-- "Trainer · Recipe" -> { "Trainer", "Recipe" }, as the data writes it or
-- as joined again here. The recipe page splits the translated line the same
-- way (UI/MainFrame.lua).
function Names.SplitParts(text)
    local parts = {}
    for part in (ns.WithDots(text) .. PART_SEPARATOR):gmatch("(.-)" .. PART_SEPARATOR) do parts[#parts + 1] = part end
    return parts
end

function Names.JoinParts(parts)
    return table.concat(parts, PART_SEPARATOR)
end

-- Whether `part` of a recipe's learned line is the trainer word. Parts()
-- puts the line in the player's language a second after login, so until
-- then the English word counts too.
function Names.IsTrainerPart(part)
    return part == L["Trainer"] or part == "Trainer"
end

-- Whether a recipe's learned line ("Trainer · Recipe", in the player's
-- language once Parts() has put it there) says a trainer teaches it.
function Names.IsLearnedFromTrainer(learned)
    if not learned then return false end
    for _, part in ipairs(Names.SplitParts(learned)) do
        if Names.IsTrainerPart(part) then return true end
    end
    return false
end

-- "Vendor · Recipe" -> each part in the player's language.
local function Parts(text)
    local translated = {}
    for i, part in ipairs(Names.SplitParts(text)) do translated[i] = Part(part) end
    return Names.JoinParts(translated)
end

-- Lookups that answer at once ------------------------------------------------

local function ZoneText(mapID)
    local ok, name = pcall(GetRealZoneText, mapID)
    return ok and name and name ~= "" and name or nil
end

local function MapName(uiMapID)
    local info = C_Map.GetMapInfo(uiMapID)
    return info and info.name ~= "" and info.name or nil
end

local function FactionName(factionID)
    local data = C_Reputation.GetFactionDataByID(factionID)
    return data and data.name ~= "" and data.name or nil
end

local function CurrencyName(currencyID)
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    return info and info.name ~= "" and info.name or nil
end

local function SpellName(spellID)
    local name = C_Spell.GetSpellName(spellID)
    return name ~= "" and name or nil
end

local function StandingName(standing)
    return _G["FACTION_STANDING_LABEL" .. STANDINGS[standing]]
end

local function PlaceName(place)
    return PLACES[place]
end

-- `lookup(id)`, the game's name for something, on a client in another
-- language. Nil on an English client: the data's own English names stay.
local function GameName(lookup, id)
    if not isOtherClientLanguage then return nil end
    return lookup(id)
end

-- A name the data writes in words of its own: a place standing in for the
-- game's name (PLACES), else one of NeedRoll's labels.
local function FixedName(name)
    if PLACES[name] then return GameName(PlaceName, name) end
    return LABELS[name]
end

-- A wing ("%s: Graveyard") is NeedRoll's label around the game's name for
-- the instance, so it is put together on an English client too.
local function InstanceName(instance)
    local mapID = ns.Data.instanceMapIDs[instance.id] or BATTLEGROUNDS[instance.name]
    local wing = WINGS[instance.id]
    if mapID and wing then
        local base = ZoneText(mapID)
        return base and wing:format(base)
    end
    -- The game names an instance it has a map for, so an English client
    -- keeps the data's English name (the game's needn't be spelled alike).
    if mapID and not isOtherClientLanguage then return nil end
    local base = mapID and ZoneText(mapID)
    if base then return base end
    if instance.factionID then return GameName(FactionName, instance.factionID) end
    if instance.currencyID then return GameName(CurrencyName, instance.currencyID) end
    return FixedName(instance.name)
end

local function ZoneName(zone)
    if ZONE_MAPS[zone] then return GameName(MapName, ZONE_MAPS[zone]) end
    if FACTION_ZONES[zone] then return GameName(FactionName, FACTION_ZONES[zone]) end
    return FixedName(zone)
end

local function EncounterName(encounter)
    if encounter.spellID then return GameName(SpellName, encounter.spellID) end
    if STANDINGS[encounter.name] then return GameName(StandingName, encounter.name) end
    return FixedName(encounter.name)
end

-- Lookups the server fills in -------------------------------------------------
local cache -- NeedRollDB.names: { locale, npc = { [id] = name }, quest = { [id] = { title, objective } }, set }
local holders = { npc = {}, quest = {}, objective = {}, item = {}, set = {} } -- kind -> id -> { { table, field }, ... }
local npcByName = {} -- English name -> NPC ID, for names written without one
local namesWithoutID = {} -- { table, field } of NPC names written without an ID

-- Notes that holder[field] is the name of `kind` `id`, to be written over
-- once the game gives it. Skipped when there is no ID or no name there, and
-- on an English client, which keeps the data's names.
local function TrackName(kind, id, holder, field)
    if not isOtherClientLanguage then return end
    if type(id) ~= "number" or id <= 0 or type(holder[field]) ~= "string" then return end
    if kind == "npc" then npcByName[holder[field]] = id end
    local list = holders[kind][id]
    if not list then
        list = {}
        holders[kind][id] = list
    end
    list[#list + 1] = { holder, field }
end

-- Creature names and quest titles come back secret on WoW: Forever (see
-- ns.Plain): a kind of lookup that does is given up for the session.
local secretKinds = {} -- kind -> true once its tooltips came back secret
local SECRET_TEXT = {} -- returned in place of tooltip lines when the text is secret

local function LineText(line)
    local text = ns.Plain(line and line.leftText)
    return text ~= "" and text or nil
end

-- A link's tooltip lines, SECRET_TEXT, or nil while the game doesn't have it yet.
local function TooltipLines(link)
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    local lines = ok and data and data.lines
    local first = lines and lines[1] and lines[1].leftText
    if issecretvalue(first) then return SECRET_TEXT end
    if LineText(lines and lines[1]) then return lines end
end

-- A creature's name, or nil while the game doesn't have it (asking starts the fetch).
local function NpcName(npcID)
    local lines = TooltipLines(("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID))
    if lines == SECRET_TEXT then return SECRET_TEXT end
    return lines and LineText(lines[1])
end

-- A creature's name from the game's tooltip data, or nil while the game doesn't have it or
-- keeps it secret (a secret can't be kept or written into /nr devexport). For UI/MapEdit.lua.
function Names:CreatureName(npcID)
    local name = NpcName(npcID)
    if name == SECRET_TEXT then return nil end
    return name
end

-- A quest's title and objective (the first text under the title), or nil.
local function QuestText(questID)
    local lines = TooltipLines("quest:" .. questID)
    if lines == SECRET_TEXT then return SECRET_TEXT end
    if not lines then return end
    for i = 2, #lines do
        local text = LineText(lines[i])
        if text then return LineText(lines[1]), text end
    end
    return LineText(lines[1])
end

-- The name of the item set an item belongs to: its tooltip's "Name (0/8)" line.
local function SetName(itemID)
    local lines = TooltipLines("item:" .. itemID)
    if lines == SECRET_TEXT then return SECRET_TEXT end
    if not lines then return end
    for i = 2, #lines do
        local text = LineText(lines[i])
        local name = text and text:match("^(.-) %(%d+/%d+%)$")
        if name and name ~= "" then return name end
    end
    return false -- loaded, but in no set
end

local namesChanged -- a name changed since the window last redrew

-- Writes `text` into every place that holds the name of `kind` `id`.
local function FillName(kind, id, text)
    if not text then return end
    for _, place in ipairs(holders[kind][id] or {}) do place[1][place[2]] = text end
    namesChanged = true
end

-- Fills in an answer from the game and keeps it for the next session.
local function KeepName(kind, id, name)
    cache[kind][id] = name
    FillName(kind, id, name)
end

local function KeepQuest(questID, title, objective)
    cache.quest[questID] = { title, objective }
    FillName("quest", questID, title)
    FillName("objective", questID, objective)
end

-- Finding every name ------------------------------------------------------------

-- A quest's name fields and the ID field that names the same thing.
local NPC_FIELDS = { giver = "giverNpc", chainGiver = "chainGiverNpc", turnIn = "turnInNpc" }
local ITEM_FIELDS = { startsFrom = "startsFromId", providedItem = "providedItemId",
    chainStartItem = "chainStartItemId" }

local function IndexQuest(quest)
    TrackName("quest", quest.id, quest, "name")
    TrackName("objective", quest.id, quest, "objective")
    TrackName("quest", quest.chainStart, quest, "chainStartName")
    for nameField, idField in pairs(NPC_FIELDS) do
        if quest[idField] and quest[idField] > 0 then
            TrackName("npc", quest[idField], quest, nameField)
        elseif OBJECTS[quest[nameField]] then
            quest[nameField] = OBJECTS[quest[nameField]]
        elseif quest[nameField] then
            -- A giver inside an instance is often a boss listed elsewhere.
            namesWithoutID[#namesWithoutID + 1] = { quest, nameField }
        end
    end
    for nameField, idField in pairs(ITEM_FIELDS) do TrackName("item", quest[idField], quest, nameField) end
    -- givers and chainGivers: a quest each side takes from its own NPCs, named by the nearest (UI/Lists.lua).
    for _, list in ipairs({ quest.droppers or {}, quest.chainDroppers or {}, quest.kills or {}, quest.named or {},
                            quest.givers or {}, quest.chainGivers or {} }) do
        for _, npc in ipairs(list) do TrackName("npc", npc.npc, npc, "name") end
    end
    for _, loot in ipairs(quest.loot or {}) do
        for _, from in ipairs(loot.from or {}) do
            -- An object named for the item it holds (the Core Fragment) keeps the item's name.
            if from.npc then
                TrackName("npc", from.npc, from, "name")
            elseif from.name == loot.name then
                TrackName("item", loot.item, from, "name")
            end
        end
        TrackName("item", loot.item, loot, "name")
    end
    for _, sided in pairs(quest.bySide or {}) do IndexQuest(sided) end
end

local function IndexEncounter(instance, encounter)
    local name = EncounterName(encounter)
    if name then encounter.name = name end
    -- Herbs, fish and other things gathered or made are listed by item ("I2447").
    local itemID = type(encounter.id) == "string" and tonumber(encounter.id:match("^I(%d+)$"))
    if itemID then TrackName("item", itemID, encounter, "name") end
    -- The Collections tabs of item sets ("Tier Sets"): each set's name from its first item.
    if instance.category == "COLLECTION" and instance.name:find("Sets$") and not name and not itemID
        and encounter.loot and encounter.loot[1] then
        TrackName("set", encounter.loot[1].itemID, encounter, "name")
    end
    if encounter.note then encounter.note = Parts(encounter.note) end
    if encounter.learned then encounter.learned = Parts(encounter.learned) end
    local bosses = ns.Data.bosses[instance.id] and ns.Data.bosses[instance.id][encounter.id]
    if bosses then
        for _, boss in ipairs(bosses) do TrackName("npc", boss[5], boss, 1) end
        -- A boss's own encounter: named like it.
        if #bosses == 1 and bosses[1][1] == encounter.name then TrackName("npc", bosses[1][5], encounter, "name") end
    elseif encounter.npc then
        TrackName("npc", encounter.npc, encounter, "name")
    end
end

-- Walks all the data: writes in NeedRoll's labels and the names the game
-- answers at once, and notes where each name the server fills in goes.
local function Index()
    for _, category in ipairs(ns.Data.CATEGORIES) do
        for _, instance in ipairs(ns.Data:List(category)) do
            if instance.zone then instance.zone = ZoneName(instance.zone) or instance.zone end
            for _, encounter in ipairs(instance.encounters) do
                if not encounter.overview then IndexEncounter(instance, encounter) end
            end
            -- Last: the encounters above compare the boss with the English name.
            instance.name = InstanceName(instance) or instance.name
        end
    end
    for _, quests in pairs(ns.Data.quests) do
        for _, quest in ipairs(quests) do IndexQuest(quest) end
    end
    -- Attunements and item chains keep their steps by side: both, Alliance, Horde.
    for _, attunement in pairs(ns.Data.attunements) do
        attunement.note = attunement.note and NOTES[attunement.note] or attunement.note
        for _, quest in ipairs(ns.Data:ChainQuests(attunement)) do IndexQuest(quest) end
    end
    for _, chains in pairs(ns.Data.itemChains) do
        for _, chain in ipairs(chains) do
            chain.note = chain.note and NOTES[chain.note] or chain.note
            for _, quest in ipairs(ns.Data:ChainQuests(chain)) do IndexQuest(quest) end
        end
    end
    for questID in pairs(ns.Data.questNames) do TrackName("quest", questID, ns.Data.questNames, questID) end
    -- Whole chains' steps (Data/Chains.lua).
    for questID, step in pairs(ns.Data.chainSteps) do
        TrackName("quest", questID, step, "name")
        TrackName("objective", questID, step, "objective")
        TrackName("npc", step.giverNpc, step, "giver")
        for _, giver in ipairs(step.givers or {}) do TrackName("npc", giver.npc, giver, "name") end
        TrackName("npc", step.turnInNpc, step, "turnIn")
        TrackName("item", step.startItemId, step, "startItem")
    end
    -- Recipe pages: the mobs that drop a recipe, the vendors that sell it and
    -- the trainers who teach it.
    for _, sources in pairs(ns.Data.recipeSources) do
        for _, list in ipairs({ sources.drops or {}, sources.vendors or {} }) do
            for _, npc in ipairs(list) do TrackName("npc", npc.npc, npc, "name") end
        end
    end
    for npc, trainer in pairs(ns.Data.recipeTrainers.trainers) do TrackName("npc", npc, trainer, "name") end
    -- Class recipe pages (the rogue's poisons): who sells their materials and
    -- who gives the quests a recipe comes with.
    for npc, vendor in pairs(ns.Data.reagentVendors.vendors) do TrackName("npc", npc, vendor, "name") end
    -- Search's "Sold by" lines (Data/VendorItems.lua).
    for npc, vendor in pairs(ns.Data.vendorItems.vendors) do TrackName("npc", npc, vendor, "name") end
    for _, instance in pairs(ns.Data.classRecipes) do
        for _, quest in ipairs(instance.quests or {}) do TrackName("npc", quest.giverNpc, quest, "giver") end
    end
    for _, place in ipairs(namesWithoutID) do TrackName("npc", npcByName[place[1][place[2]]], place[1], place[2]) end
    -- The Library Books page's librarians (Data/LibraryBooks.lua).
    for _, librarian in pairs(ns.Data.libraryBooks and ns.Data.libraryBooks.librarians or {}) do
        TrackName("npc", librarian.npc, librarian, "name")
    end
    -- Search and tooltips may hold the names as they were before.
    namesChanged = true
end

-- The background fetch ------------------------------------------------------------

local ASKS_PER_TICK = 4 -- asks every quarter second
local TRIES = 4 -- asks before giving up on an ID until the next session
local RETRY = 2 -- seconds between asks for one ID
-- Entries { kind = "npc" | "quest" | "set", id, tries, askAt }, asked in order from queuePos.
local queue, queuePos = {}, 1

-- The game's lookup for each kind of name.
local LOOKUPS = { npc = NpcName, set = SetName, quest = QuestText }

local function Enqueue(kind, id)
    queue[#queue + 1] = { kind = kind, id = id, tries = 0 }
end

-- Fills in every name already known and queues the rest to be asked of the game. NPC names
-- and quest text come from Locales/NpcNames and Locales/QuestNames first: the game keeps
-- them secret on WoW: Forever. Item names come from C_Item, once loaded.
local function FillOrQueueNames()
    local npcNames, npcPhrases, questTexts = ns.NpcNames or {}, ns.NpcPhrases or {}, ns.QuestTexts or {}
    for npcID in pairs(holders.npc) do
        local name = npcNames[npcID] or npcPhrases[npcID]
        if name then
            FillName("npc", npcID, name)
        elseif cache.npc[npcID] then
            KeepName("npc", npcID, cache.npc[npcID])
        else
            Enqueue("npc", npcID)
        end
    end
    local questIDs = {}
    for questID in pairs(holders.quest) do questIDs[questID] = true end
    for questID in pairs(holders.objective) do questIDs[questID] = true end
    for questID in pairs(questIDs) do
        local translated, kept = questTexts[questID], cache.quest[questID]
        if translated then
            FillName("quest", questID, translated[1])
            FillName("objective", questID, translated[2])
        elseif kept then
            KeepQuest(questID, kept[1], kept[2])
        else
            Enqueue("quest", questID)
        end
    end
    for itemID in pairs(holders.set) do
        if cache.set[itemID] then KeepName("set", itemID, cache.set[itemID]) else Enqueue("set", itemID) end
    end
    for itemID in pairs(holders.item) do
        ns.Items:Load(itemID, function() FillName("item", itemID, C_Item.GetItemNameByID(itemID)) end)
    end
end

-- Asks the game once for an entry's name. Returns whether that ID is done with: answered
-- (a set lookup can answer "in no set"), or its kind came back secret (the English name stays).
local function Ask(entry)
    local kind = entry.kind
    if secretKinds[kind] then return true end
    local answer, objective = LOOKUPS[kind](entry.id)
    if answer == SECRET_TEXT then
        secretKinds[kind] = true
        return true
    end
    if answer and kind == "quest" then
        KeepQuest(entry.id, answer, objective)
    elseif answer then
        KeepName(kind, entry.id, answer)
    end
    return answer ~= nil
end

-- Asks for the next few queued names. Returns true once the queue is done.
local function Tick()
    if InCombatLockdown() then return end
    local now = GetTime()
    for _ = 1, ASKS_PER_TICK do
        local entry = queue[queuePos]
        if not entry then return true end
        queuePos = queuePos + 1
        if entry.askAt and entry.askAt > now and not secretKinds[entry.kind] then
            -- Asked moments ago: give the server time to answer.
            queue[#queue + 1] = entry
        else
            local isDone = Ask(entry)
            entry.tries, entry.askAt = entry.tries + 1, now + RETRY
            -- Not there yet: the ask started the fetch; ask again a little later.
            if not isDone and entry.tries < TRIES then queue[#queue + 1] = entry end
        end
    end
end

-- Redraws what is on screen once names have landed (lists and pages that
-- aren't showing pick them up when they are drawn next).
local function Redraw()
    if not namesChanged then return end
    namesChanged = false
    if ns.Search and ns.Search.Forget then ns.Search:Forget() end
    ns.Tooltip:Forget()
    local ui = ns.UI
    if ui and ui.frame and ui.frame:IsShown() and ui.Refresh then ui:Refresh() end
end

-- The names kept from the last session in this client's language
-- (NeedRollDB.names); another language's are thrown away.
local function LoadKeptNames()
    if type(ns.db.names) ~= "table" or ns.db.names.locale ~= LOCALE then
        ns.db.names = { locale = LOCALE, npc = {}, quest = {} }
    end
    ns.db.names.set = ns.db.names.set or {}
    cache = ns.db.names
end

-- Fills in the names already known, then asks the game for the rest in the
-- background, redrawing as they arrive.
local function FetchGameNames()
    FillOrQueueNames()
    Redraw()
    local ticker
    ticker = C_Timer.NewTicker(0.25, function()
        if Tick() then
            ticker:Cancel()
            Redraw()
        end
    end)
    C_Timer.NewTicker(2, Redraw, 60) -- every 2 seconds for two minutes, while names arrive
end

ns:On("PLAYER_LOGIN", function()
    --[==[@debug@
    -- Testing on an English client: /run NeedRollDB.namesTest = true, then /reload.
    if ns.db.namesTest then isOtherClientLanguage = true end
    --@end-debug@]==]
    -- English text on an English client: the data already reads as it should.
    if not isOtherClientLanguage and isTextInEnglish then return end
    if isOtherClientLanguage then LoadKeptNames() end
    -- After the data's own login work (each quest's side is chosen then).
    C_Timer.After(1, function()
        Index()
        if isOtherClientLanguage then FetchGameNames() else Redraw() end
    end)
end)
