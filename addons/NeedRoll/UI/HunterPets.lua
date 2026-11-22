-- The Classes tab's Pets section, the hunter's alone: Pet trainer, then each
-- family a hunter can tame (Data/HunterPets.lua: beasts and trainers from
-- Classic-DB and QuestieDB, WoW: Forever's pet abilities and their ranks),
-- and the right pane's page for one of them.
-- A family's page names its abilities and diet and lists its beasts nearest
-- you first, those near your level unless a chip says otherwise, each a link
-- that pins it on the map. Near your level lists one beast per set of ranks
-- taught plus every rare one, five at most; All lists the rest. Then the
-- family's own abilities and those any pet learns, rank by pet level.
-- The Pet trainer page lists the any-pet abilities and your side's pet
-- trainers, each pinned on the map like the class trainers on the Overview.
-- Only IDs, levels, counts, costs and NPC names ship: the game names each
-- family and gives its icon (C_CreatureInfo.GetCreatureFamilyInfo), and
-- names and describes each ability by its spell ID. A diet has no game call
-- outside your own pet's, so its foods are words of our own.
-- A rank a pet trainer sells shows its cost. One no trainer sells (every
-- family ability's, Cower's) is learned the Beast Training way: tame a beast
-- that knows the rank, use it in combat until the chat line says your
-- hunter learned it, then teach it to any pet whose family can learn it.
-- Which beasts teach which rank comes from Petopia (the data's `teaches`):
-- a rank's line names a family to tame for it, or says no source is known
-- yet, and each beast's row lists the ranks it teaches. A pet has at most
-- four abilities active at once.
-- With your hunter's pet out, an ability's line says the rank it knows and
-- the next one at its level (ClassSpells.Progress on the pet's spellbook).
-- A click on an ability opens a row per rank under it (ClassSpells' rank rows).
-- The warlock's demon pages are built from the same parts (PetPageKit, for
-- UI/WarlockPets.lua).
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L
local Talents = ns.Talents
local ClassSpells = ns.UI.ClassSpells

local HunterPets = {}
ns.UI.HunterPets = HunterPets
-- What the warlock's demon pages share with these: the page's frame and
-- heading, its rows' parts and sizes, a family's name and icon, and the
-- ability helpers. The Professions Overview and the Library Books page are
-- built on the same frame and rows, and share its text, link and redraw
-- helpers (at the end of this file).
local PetPageKit = {}
ns.UI.PetPageKit = PetPageKit

local HUNTER = "HUNTER"
local PAGE_KEY_PREFIX = "PETS:"
local TRAINER_PAGE_KEY = PAGE_KEY_PREFIX .. "TRAINER"
local TRAINER_ATLAS = "StableMaster"  -- the Pets section's icon, on the Pet trainer page
local UNKNOWN_ICON = 134400           -- the question mark, for a family the game doesn't name
local NEAR_LEVELS = 4                 -- a beast this many levels from yours, or closer, is near your level
local MAX_ACTIVE_ABILITIES = 4        -- the most abilities a pet has active at once
local NEAR_SHOWN = 5                  -- the most beasts Near my level lists; All lists every one

local STRIP_INSET = Size.pad - 4  -- the chips and the level line, from the strip's ends (as Back's)
local CHIP_GAP = 6                -- between two chips
local HEADING_LEFT = 16           -- the rows, in from the left (as the heading, ns.UI.CreateBadgeHeading)
local ROWS_GAP = 10               -- between the line under the heading and the first row
local HEADING_ROW = 30            -- a heading's row
local LINE_ROW = 22               -- an ability's, trainer's or note's row
local BEAST_ROW = 36              -- a beast's row: its name, and under it the ranks it teaches
local BEAST_NAME_LIFT = 7         -- a beast's name, up from the row's middle, to make room for that line
local TEACHES_GAP = 2             -- between a beast's name and the ranks it teaches
local HEADING_NOTE_GAP = 8        -- between a heading and the note after it
local RIGHT_INSET = 16            -- a row's right column, in from the row's right
local MAP_COLUMN = 84             -- a beast's "28 on map", at the right
local ZONE_COLUMN = 130           -- its zone, left of that
local LEVEL_COLUMN = 64           -- its levels, left of that
local COLUMN_GAP = 8              -- between those columns
local TEXT_ROOM = 12              -- the least room between a row's name and what's right of it
local RANK_INDENT = 16            -- an opened ability's rank rows, in from its name

-- Ability ranks: { spellID, pet level, copper } (Data/HunterPets.lua), as
-- ClassSpells reads a class spell's.
local RANK_SPELL, RANK_LEVEL, RANK_COST = 1, 2, 3

-- Classic-DB's creature ranks the beast list tags.
local RANK_TAGS = { [1] = L["elite"], [2] = L["rare elite"], [4] = L["rare"] }
local RARE_RANKS = { [2] = true, [4] = true }

-- The diet's food keys, as the game's pet diet tooltip words them.
local FOOD_NAMES = {
    MEAT = L["Meat"], FISH = L["Fish"], BREAD = L["Bread"], CHEESE = L["Cheese"], FRUIT = L["Fruit"],
    FUNGUS = L["Fungus"],
}

-- A family page's chips, in order: the beasts near your level, all of
-- them, the rare ones.
local FILTER_NEAR, FILTER_ALL, FILTER_RARE = "NEAR", "ALL", "RARE"
local CHIP_FILTERS = { FILTER_NEAR, FILTER_ALL, FILTER_RARE }
local CHIP_LABELS = { [FILTER_NEAR] = L["Near my level"], [FILTER_ALL] = L["All"], [FILTER_RARE] = L["Rare"] }

-- The list's rows, by `kind`; RANK is one rank of an opened ability.
local HEADING, BEAST, ABILITY, RANK, TRAINER, NOTE = "HEADING", "BEAST", "ABILITY", "RANK", "TRAINER", "NOTE"

-- The data --------------------------------------------------------------------------

local function Data()
    return ns.Data.hunterPets
end

local function IsPlayerHunter()
    local classID = Talents.PlayerClassID()
    return classID ~= nil and select(2, GetClassInfo(classID)) == HUNTER
end

-- Whether class `classID` has the Pets section: the hunter, while the data loaded.
function HunterPets.Has(classID)
    return select(2, GetClassInfo(classID)) == HUNTER and Data() ~= nil
end

-- A family's name and icon, as the game has them; a stand-in for one it
-- doesn't. The warlock's demons are creature families too.
local function FamilyInfo(familyID)
    local info = C_CreatureInfo.GetCreatureFamilyInfo(familyID)
    if not info then return L["Family %d"]:format(familyID), UNKNOWN_ICON end
    return info.name, info.iconFile or UNKNOWN_ICON
end
PetPageKit.FamilyInfo = FamilyInfo

-- The data looked up three ways, worked out once: each family's beasts in
-- the data's order (by level; a family's page lists them nearest first,
-- page:NearestBeasts), the beasts teaching each rank by its spell ID, and
-- each rank's ability and number by its spell ID.
local lookup
local function Lookup()
    if lookup then return lookup end
    lookup = { beastsOf = {}, teachersOf = {}, rankOf = {} }
    for _, beast in ipairs(Data().beasts) do
        lookup.beastsOf[beast.family] = lookup.beastsOf[beast.family] or {}
        table.insert(lookup.beastsOf[beast.family], beast)
        for _, spellID in ipairs(beast.teaches or {}) do
            lookup.teachersOf[spellID] = lookup.teachersOf[spellID] or {}
            table.insert(lookup.teachersOf[spellID], beast)
        end
    end
    for _, ability in ipairs(Data().abilities) do
        for index, rank in ipairs(ability.ranks) do
            lookup.rankOf[rank[RANK_SPELL]] = { ability = ability, index = index }
        end
    end
    return lookup
end

local function BeastsOf(familyID)
    return Lookup().beastsOf[familyID] or {}
end

-- The section header's figure: how many families a hunter can tame.
function HunterPets.HeaderFigure()
    local count = 0
    for _ in pairs(Data() and Data().families or {}) do count = count + 1 end
    return tostring(count)
end

-- Each page's entry in the sections column, by its key, kept so its row
-- stays the same row as the list redraws.
local pagesByKey = {}

local function PageFor(key, fields)
    local page = pagesByKey[key] or { key = key, petPage = true }
    for field, value in pairs(fields) do page[field] = value end
    pagesByKey[key] = page
    return page
end

-- Pet trainer, then the families by name; none for a class but the hunter.
function HunterPets.Pages(classID)
    if not HunterPets.Has(classID) then return {} end
    local families = {}
    for familyID in pairs(Data().families) do
        local name, icon = FamilyInfo(familyID)
        table.insert(families, PageFor(PAGE_KEY_PREFIX .. familyID, { familyID = familyID, name = name, icon = icon }))
    end
    table.sort(families, function(a, b) return a.name < b.name end)
    table.insert(families, 1, PageFor(TRAINER_PAGE_KEY, { name = L["Pet trainer"] }))
    return families
end

-- A family's row shows how many of its beasts there are to tame.
function HunterPets.PageFigure(page)
    if not page.familyID then return nil end
    return tostring(#BeastsOf(page.familyID))
end

-- Beasts ----------------------------------------------------------------------------

local function IsNear(beast, level)
    return beast.levels[2] >= level - NEAR_LEVELS and beast.levels[1] <= level + NEAR_LEVELS
end

local function IsRare(beast)
    return RARE_RANKS[beast.rank] == true
end

-- The beasts of `beasts` the chip `filter` keeps.
local function Filtered(beasts, filter, level)
    if filter == FILTER_ALL then return beasts end
    local kept = {}
    for _, beast in ipairs(beasts) do
        local isKept = (filter == FILTER_NEAR and IsNear(beast, level)) or (filter == FILTER_RARE and IsRare(beast))
        if isKept then table.insert(kept, beast) end
    end
    return kept
end

-- "Lv 35-36", or "Lv 42" for one level.
local function LevelsText(beast)
    local lowest, highest = beast.levels[1], beast.levels[2]
    if lowest == highest then return L["Lv %d"]:format(lowest) end
    return L["Lv %d-%d"]:format(lowest, highest)
end

-- The spot a beast's link pins: in the zone the player is in when it
-- spawns there, else where most of it spawns. The map ID can come back
-- secret in places, so it goes through ns.Plain.
local function PinnedSpot(beast)
    local playerMap = ns.Plain(C_Map.GetBestMapForUnit("player"))
    for _, spot in ipairs(beast.spots) do
        if spot.map == playerMap then return spot end
    end
    return beast.spots[1]
end

-- The pinned spot with its place in the world, as UI.NearestFirst sorts
-- by; nil where the map can't say.
local function BeastWorldSpot(beast)
    return ns.UI.SpotInWorld(PinnedSpot(beast))
end

-- The ability lines ------------------------------------------------------------------

-- Your hunter's pet's level, or nil without a hunter's pet out. Read
-- through ns.Plain in case the game hands it back secret.
local function PetLevel()
    if not (IsPlayerHunter() and UnitExists("pet")) then return nil end
    return ns.Plain(UnitLevel("pet"))
end

-- "Pet levels 1 to 60", or "Pet level 20" for an ability whose ranks all come at one.
local function PetLevelsText(ability)
    local first, last = ability.ranks[1][RANK_LEVEL], ability.ranks[#ability.ranks][RANK_LEVEL]
    if first == last then return L["Pet level %d"]:format(first) end
    return L["Pet levels %d to %d"]:format(first, last)
end

-- Whether pet trainers sell `ability` (Growl, the resistances...); its
-- ranks are otherwise learned by taming.
local function IsTrainerSold(ability)
    return ability.trainer == true
end

-- The highest rank of an ability whose level is `level` or under; nil when
-- even rank 1 needs more.
local function HighestRankAt(ability, level)
    local highest
    for index, rank in ipairs(ability.ranks) do
        if rank[RANK_LEVEL] <= level then highest = index end
    end
    return highest
end

-- The lowest-level beast of `teachers` of family `familyID` (nil: of any
-- family); nil when none is.
local function LowestTeacher(teachers, familyID)
    local lowest
    for _, beast in ipairs(teachers) do
        local isOfFamily = familyID == nil or beast.family == familyID
        if isOfFamily and (not lowest or beast.levels[1] < lowest.levels[1]) then lowest = beast end
    end
    return lowest
end

-- The beast whose family and level a rank's taming line names: the
-- lowest-level one of the page's family `familyID` that teaches it, else
-- the lowest-level one of any family (the hunter learns the rank from it,
-- then teaches it to any pet whose family can learn it); nil when no beast
-- we list teaches it.
local function TeacherToName(ability, index, familyID)
    local teachers = Lookup().teachersOf[ability.ranks[index][RANK_SPELL]] or {}
    return (familyID and LowestTeacher(teachers, familyID)) or LowestTeacher(teachers)
end

-- How a rank no trainer sells is learned: "Tame a Bear of level 24+ and
-- use rank 2 until you learn it" (the tamed beast knows it; using it in
-- combat until the chat line says your hunter learned it lets Beast
-- Training teach it to other pets), the family the game's name for it;
-- "No known source yet" when no beast we list teaches it. Also whether a
-- source is known. A rank's own row names the rank already, so it says it
-- shorter (RankTamingText).
local function TamingText(ability, index, familyID)
    local teacher = TeacherToName(ability, index, familyID)
    if not teacher then return L["No known source yet"], false end
    return L["Tame a %s of level %d+ and use rank %d until you learn it"]:format((FamilyInfo(teacher.family)),
        teacher.levels[1], index), true
end

-- What ranks `first` to `last` of an ability cost at a pet trainer, as
-- money text; nil when a trainer doesn't sell one of them (a rank new in
-- WoW: Forever, or one a beast teaches), rather than a guess.
local function RanksCostText(ability, first, last)
    local total = 0
    for i = first, last do
        local cost = ability.ranks[i][RANK_COST]
        if not cost then return nil end
        total = total + cost
    end
    return ns.Money(total)
end
PetPageKit.RanksCostText = RanksCostText

-- An ability's line with no pet out: its ranks, the pet levels they come
-- at and what all of them cost; or, for one no trainer sells, the beast to
-- tame for the highest rank at your level (rank 1 below it), as a pet is
-- never above your level.
local function NoPetStatus(ability, familyID, playerLevel)
    local ranksText = Theme:Plural(#ability.ranks, L["%d rank"], L["%d ranks"])
    if not IsTrainerSold(ability) then
        local index = HighestRankAt(ability, playerLevel) or 1
        return Theme:JoinDots(ranksText, (TamingText(ability, index, familyID))), Theme.color.muted
    end
    return Theme:JoinDots(ranksText, PetLevelsText(ability), RanksCostText(ability, 1, #ability.ranks)),
        Theme.color.muted
end

-- An ability's line at the right, and its color: with your pet out, the
-- rank it knows and what to train (or tame) now or next; else NoPetStatus.
-- A rank to tame for now shows green only when a beast is known to teach it.
local function AbilityStatus(entry)
    local ability, petLevel = entry.ability, entry.petLevel
    if not petLevel then return NoPetStatus(ability, entry.familyID, entry.playerLevel) end
    local progress = ClassSpells.Progress(ability, petLevel, Enum.SpellBookSpellBank.Pet)
    local knownText = progress.known == 0 and L["Not trained"]
        or L["Rank %d of %d"]:format(progress.known, #ability.ranks)
    if progress.trainFirst then
        if not IsTrainerSold(ability) then
            local tamingText, isKnown = TamingText(ability, progress.trainLast, entry.familyID)
            return Theme:JoinDots(knownText, tamingText), isKnown and Theme.color.complete or Theme.color.muted
        end
        local which = progress.trainFirst == progress.trainLast and L["Train now: rank %d"]:format(progress.trainLast)
            or L["Train now: ranks %d to %d"]:format(progress.trainFirst, progress.trainLast)
        return Theme:JoinDots(knownText, which, RanksCostText(ability, progress.trainFirst, progress.trainLast)),
            Theme.color.complete
    end
    if progress.nextRank then
        if not IsTrainerSold(ability) then
            return Theme:JoinDots(knownText, (TamingText(ability, progress.nextRank, entry.familyID))),
                Theme.color.muted
        end
        local rank = ability.ranks[progress.nextRank]
        return Theme:JoinDots(knownText, L["Rank %d at pet level %d"]:format(progress.nextRank, rank[RANK_LEVEL]),
            RanksCostText(ability, progress.nextRank, progress.nextRank)), Theme.color.muted
    end
    return L["All ranks trained"], Theme.color.muted
end

-- The rank of `ability` its tooltip and link show: with `level` (your pet
-- out; a warlock's level with the demon out), the next one to train, else
-- the last.
local function ShownRank(ability, level)
    local progress = level and ClassSpells.Progress(ability, level, Enum.SpellBookSpellBank.Pet)
    local index = progress and (progress.trainLast or progress.nextRank) or #ability.ranks
    return ability.ranks[index][RANK_SPELL]
end
PetPageKit.ShownRank = ShownRank

-- The abilities every pet learns (Growl, Great Stamina, the resistances...).
local function AllPetAbilities()
    local abilities = {}
    for _, ability in ipairs(Data().abilities) do
        if ability.allPets then table.insert(abilities, ability) end
    end
    return abilities
end

-- Family `familyID`'s own abilities, in the data's order (the families
-- name each by its rank 1 spell ID).
local function FamilyAbilities(familyID)
    local byFirstRank = {}
    for _, ability in ipairs(Data().abilities) do byFirstRank[ability.ranks[1][RANK_SPELL]] = ability end
    local abilities = {}
    for _, spellID in ipairs(Data().families[familyID].abilities) do
        table.insert(abilities, byFirstRank[spellID])
    end
    return abilities
end

-- TamingText on rank `index`'s own row: "Tame a Wolf of level 24+, use it
-- until learned".
local function RankTamingText(ability, index, familyID)
    local teacher = TeacherToName(ability, index, familyID)
    if not teacher then return L["No known source yet"] end
    return L["Tame a %s of level %d+, use it until learned"]:format((FamilyInfo(teacher.family)), teacher.levels[1])
end

-- What rank `index`'s row says at its cost column: for a rank trainers sell
-- its cost ("Pet trainer" when Classic-DB's trainers name none), else how
-- it's tamed.
local function RankSourceText(ability, index, familyID)
    if not IsTrainerSold(ability) then return RankTamingText(ability, index, familyID) end
    local cost = ability.ranks[index][RANK_COST]
    return cost and ns.Money(cost) or L["Pet trainer"]
end

-- Ability `entry`'s rank rows while they show on `page`: each rank's pet
-- level, its cost or the beast to tame for it, and with your pet out where
-- it stands for your pet; nil for another row or a shut ability.
local function RankRowsOf(entry, page)
    if entry.kind ~= ABILITY or not ClassSpells.AreRanksOpen(page, entry.ability) then return nil end
    entry.isOpen = true
    local ability, rows = entry.ability, {}
    local progress = entry.petLevel and ClassSpells.Progress(ability, entry.petLevel, Enum.SpellBookSpellBank.Pet)
    for index, rank in ipairs(ability.ranks) do
        local costText = RankSourceText(ability, index, entry.familyID)
        local rankEntry = ClassSpells.RankEntry(ability, index, progress or nil,
            L["Pet level %d"]:format(rank[RANK_LEVEL]), costText)
        rankEntry.kind = RANK
        table.insert(rows, rankEntry)
    end
    return rows
end

-- The rows ---------------------------------------------------------------------------

-- A section's heading row with its note. Every heading but the page's first
-- has the gold divider over it, between it and the section above.
local function AddHeading(rows, text, note)
    table.insert(rows, { kind = HEADING, height = HEADING_ROW, text = text, note = note, hasDivider = #rows > 0 })
end
PetPageKit.AddHeading = AddHeading

-- A heading with its note, then a row per ability; the ranks no trainer
-- sells name a beast of family `familyID` to tame where one teaches them
-- (nil, or none does: the lowest-level beast that does, of any family).
local function AddAbilityRows(rows, heading, note, abilities, familyID)
    local petLevel, playerLevel = PetLevel(), ns.PlayerLevel()
    AddHeading(rows, heading, note)
    for _, ability in ipairs(abilities) do
        table.insert(rows, { kind = ABILITY, height = LINE_ROW, ability = ability, familyID = familyID,
            petLevel = petLevel, playerLevel = playerLevel })
    end
end

local function AddAllPetRows(rows)
    AddAbilityRows(rows, L["Any pet"], L["costs from the pet trainers"], AllPetAbilities())
end

-- "Teaches Bite 3, Cower 2" (ClassSpells.RankName, the name alone for rank
-- 1), from the ranks Petopia says the beast teaches. Petopia names every
-- beast that teaches a rank, so one it never names teaches nothing (most
-- beasts don't), and the row says so rather than leaving a blank line.
-- RankName names each rank by its ability's rank 1, the spell LoadNames asks
-- the game for.
local function TeachesText(beast)
    local taught = {}
    for _, spellID in ipairs(beast.teaches or {}) do
        local rank = Lookup().rankOf[spellID]
        table.insert(taught, ClassSpells.RankName({ spellID = rank.ability.ranks[1][RANK_SPELL], rank = rank.index }))
    end
    if #taught == 0 then return L["Teaches nothing"] end
    return L["Teaches %s"]:format(table.concat(taught, ", "))
end

-- The same for beasts that teach the same ranks: their spell IDs, not
-- TeachesText, whose names read "" until the game sends them.
local function TaughtRanksKey(beast)
    return table.concat(beast.teaches or {}, ",")
end

-- Near my level's beasts, from the near ones nearest first: of those that
-- teach the same ranks only the nearest, but every rare one (worth the trip
-- whatever it teaches), at most NEAR_SHOWN; and whether any were left out.
local function OnePerRanks(beasts)
    local listed, seenRanks, hasMore = {}, {}, false
    for _, beast in ipairs(beasts) do
        local ranksKey = not IsRare(beast) and TaughtRanksKey(beast)
        if ranksKey and seenRanks[ranksKey] then
            hasMore = true
        elseif #listed == NEAR_SHOWN then
            return listed, true
        else
            if ranksKey then seenRanks[ranksKey] = true end
            table.insert(listed, beast)
        end
    end
    return listed, hasMore
end

-- The beasts the chip `filter` lists from `beasts` (nearest first), and
-- whether All has more to show.
local function ListedBeasts(beasts, filter, level)
    local kept = Filtered(beasts, filter, level)
    if filter ~= FILTER_NEAR then return kept, false end
    return OnePerRanks(kept)
end

-- "Your pet trainers  Alliance", then your side's, nearest first; on a
-- character who isn't a hunter, a line saying why there are none.
local function AddTrainerRows(rows)
    if not IsPlayerHunter() then
        table.insert(rows, { kind = NOTE, height = LINE_ROW, text = L["Your pet trainers show on a hunter."] })
        return
    end
    local trainers = ns.UI.NearestFirst(ns.UI.YourSideTrainers(Data().trainers))
    if #trainers == 0 then return end
    AddHeading(rows, L["Your pet trainers"], ns.SideName(ns.PlayerFaction()))
    for _, trainer in ipairs(trainers) do
        table.insert(rows, { kind = TRAINER, height = LINE_ROW, trainer = trainer })
    end
end

-- "Tame one", the beasts the chip lists (or a line saying there are none;
-- `hasMore`: a line pointing to All for the rest), then the family's own
-- abilities and those every pet learns.
local function FamilyRows(familyID, filter, beasts, hasMore)
    local rows = {}
    AddHeading(rows, L["Tame one"], L["each teaches the ranks under its name"])
    for _, beast in ipairs(beasts) do table.insert(rows, { kind = BEAST, height = BEAST_ROW, beast = beast }) end
    if hasMore then
        table.insert(rows, { kind = NOTE, height = LINE_ROW,
            text = L["Select %s to see more"]:format(CHIP_LABELS[FILTER_ALL]) })
    end
    if #beasts == 0 then
        local why = filter == FILTER_RARE and L["None of these are rare."] or L["None near your level."]
        table.insert(rows, { kind = NOTE, height = LINE_ROW, text = why })
    end
    local note = Theme:JoinDots(L["learned by taming"], L["a pet has %d active at most"]:format(MAX_ACTIVE_ABILITIES))
    AddAbilityRows(rows, L["Family abilities"], note, FamilyAbilities(familyID), familyID)
    AddAllPetRows(rows)
    return rows
end

local function TrainerPageRows()
    local rows = {}
    AddAllPetRows(rows)
    AddTrainerRows(rows)
    return rows
end

-- A beast's name, then its rank's tag ("rare") in `heading`, small.
local function BeastName(beast, fontString)
    local tag = RANK_TAGS[beast.rank]
    if not tag then return beast.name end
    local _, size = fontString:GetFont()
    local tagSize = math.floor((size or 12) * 0.8 + 0.5)
    return ("%s  %s%s|r"):format(beast.name, Theme:ColorCode(Theme.color.heading),
        ns.UI.SizeMarkers(tag, tagSize))
end

local function ShowBeastTooltip(row)
    local beast = row.data.beast
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:SetText(beast.name)
    GameTooltip:AddLine(Theme:JoinDots(LevelsText(beast), RANK_TAGS[beast.rank]), 1, 1, 1)
    for _, spot in ipairs(beast.spots) do
        GameTooltip:AddDoubleLine(ns.UI.SourceZone({ spot = spot }) or "", L["%d on map"]:format(spot.spawns),
            1, 1, 1, unpack(Theme.tip.text))
    end
    GameTooltip:AddLine(TeachesText(beast), 1, 1, 1, true)
    GameTooltip:AddLine(L["Click to pin on your map"], unpack(Theme.tip.text))
    GameTooltip:Show()
end

local function ShowAbilityTooltip(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:SetSpellByID(ShownRank(row.data.ability, row.data.petLevel))
    GameTooltip:Show()
end

-- A beast's or trainer's row is a link that pins them (UI.HoverMapLink);
-- an ability's row shows its tooltip.
local function OnRowEnter(row)
    local entry = row.data
    local kind = entry and entry.kind
    if kind == BEAST then
        ns.UI.HoverMapLink(row, PinnedSpot(entry.beast))
        ShowBeastTooltip(row)
    elseif kind == TRAINER then
        ns.UI.HoverMapLink(row, ns.Data.npcs[entry.trainer.npc])
        ns.UI.ShowTrainerTooltip(row)
    elseif kind == ABILITY then
        ShowAbilityTooltip(row)
    elseif kind == RANK then
        ClassSpells.ShowRankTooltip(row)
    end
end

local function OnRowLeave(row)
    ns.UI.LeaveMapLink(row)
    GameTooltip:Hide()
end

-- Shift-click on an ability links the spell its tooltip shows in chat, on
-- a rank that rank's; a plain click on an ability opens or shuts its ranks.
local function OnAbilityClick(entry, page)
    if IsModifiedClick("CHATLINK") then
        ClassSpells.LinkInChat(entry.kind == RANK and entry.spellID or ShownRank(entry.ability, entry.petLevel))
        return
    end
    if entry.kind == RANK then return end
    GameTooltip:Hide()
    ClassSpells.ToggleRanks(page, entry.ability)
end

-- A click in combat on a beast or trainer reaches here (out of combat the
-- map pin link's secure button takes it, UI/MainFrame.lua); an ability's
-- or rank's goes to OnAbilityClick.
local function OnRowClick(row, page)
    local entry = row.data
    if entry.kind == ABILITY or entry.kind == RANK then return OnAbilityClick(entry, page) end
    GameTooltip:Hide()
    if entry.kind == BEAST then
        ns.UI.ShowOnMap(PinnedSpot(entry.beast), entry.beast.name)
    elseif entry.kind == TRAINER then
        ns.UI.ShowOnMap(ns.Data.npcs[entry.trainer.npc], entry.trainer.name)
    end
end

-- A row of a pet page's list: its text, a heading's note after it and the
-- divider over it (AddHeading), one column at the right, an ability's open
-- arrow after its name, and a rank's texts (ClassSpells.CreateRankParts).
local function CreateListRow(column)
    local row = Theme:Row(column, LINE_ROW)
    row.divider = Theme:Divider(row)
    row.divider:SetPoint("TOPLEFT", HEADING_LEFT, 0)
    row.divider:SetPoint("TOPRIGHT", -RIGHT_INSET, 0)
    row.text = Theme:Text(row, Theme.font.body)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.note = Theme:Text(row, Theme.font.small)
    row.note:SetPoint("LEFT", row.text, "RIGHT", HEADING_NOTE_GAP, 0)
    Theme:SetTextColor(row.note, Theme.color.muted)
    row.right = Theme:Text(row, Theme.font.body)
    row.right:SetPoint("RIGHT", -RIGHT_INSET, 0)
    row.right:SetJustifyH("RIGHT")
    ClassSpells.CreateOpenArrow(row)
    ClassSpells.CreateRankParts(row, HEADING_LEFT + RANK_INDENT)
    row:RegisterForClicks("LeftButtonUp")
    return row
end
PetPageKit.CreateListRow = CreateListRow
PetPageKit.LINE_ROW = LINE_ROW

-- A row of the list, with a beast's ranks it teaches under its name, and
-- at the right its levels, zone and spawns on the map (another row's one
-- column is CreateListRow's).
local function CreateRow(column, page)
    local row = CreateListRow(column)
    row.teaches = Theme:Text(row, Theme.font.small)
    row.teaches:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -TEACHES_GAP)
    row.teaches:SetPoint("RIGHT", row.text, "RIGHT")
    row.teaches:SetJustifyH("LEFT")
    row.teaches:SetWordWrap(false)
    Theme:SetTextColor(row.teaches, Theme.color.muted)
    row.zone = Theme:Text(row, Theme.font.body)
    row.zone:SetPoint("RIGHT", -(RIGHT_INSET + MAP_COLUMN + COLUMN_GAP), 0)
    row.zone:SetWidth(ZONE_COLUMN)
    row.zone:SetJustifyH("LEFT")
    row.zone:SetWordWrap(false)
    Theme:SetTextColor(row.zone, Theme.color.muted)
    row.levels = Theme:Text(row, Theme.font.body)
    row.levels:SetPoint("RIGHT", row.zone, "LEFT", -COLUMN_GAP, 0)
    row.levels:SetWidth(LEVEL_COLUMN)
    row.levels:SetJustifyH("LEFT")
    Theme:SetTextColor(row.levels, Theme.color.muted)
    row:HookScript("OnEnter", OnRowEnter)
    row:HookScript("OnLeave", OnRowLeave)
    row:SetScript("OnClick", function(self) OnRowClick(self, page) end)
    return row
end

-- The text's font and color, how far it sits up from the row's middle (a
-- beast's name, over the ranks it teaches), and what its right edge stops
-- at: the levels column on a beast's row, the right column on another's,
-- or nothing on a heading (its note follows right after its words).
local function PlaceRowText(row, font, color, rightOf, lift)
    row.text:SetFontObject(font)
    Theme:SetTextColor(row.text, color)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", HEADING_LEFT, lift or 0)
    if rightOf then row.text:SetPoint("RIGHT", rightOf, "LEFT", -TEXT_ROOM, 0) end
end
PetPageKit.PlaceRowText = PlaceRowText

local function SetupRow(row, entry)
    local kind = entry.kind
    local isBeast = kind == BEAST
    row.note:SetText(kind == HEADING and entry.note or "")
    row.divider:SetShown(entry.hasDivider == true)
    row.teaches:SetText(isBeast and TeachesText(entry.beast) or "")
    row.levels:SetText(isBeast and LevelsText(entry.beast) or "")
    row.zone:SetText(isBeast and ns.UI.SourceZone({ spot = PinnedSpot(entry.beast) }) or "")
    row.right:SetFontObject(isBeast and Theme.font.body or Theme.font.small)
    row.right:SetText("")
    Theme:SetTextColor(row.right, Theme.color.muted)
    row:EnableMouse(kind ~= HEADING and kind ~= NOTE)
    ClassSpells.ShowRankParts(row, kind == RANK and entry or nil)
    ClassSpells.PlaceOpenArrow(row, row.text, nil)
    if kind == HEADING then
        PlaceRowText(row, Theme.font.section, Theme.color.heading)
        row.text:SetText(entry.text)
    elseif isBeast then
        PlaceRowText(row, Theme.font.body, Theme.color.text, row.levels, BEAST_NAME_LIFT)
        row.text:SetText(BeastName(entry.beast, row.text))
        row.right:SetText(L["%d on map"]:format(PinnedSpot(entry.beast).spawns))
        Theme:SetTextColor(row.right, Theme.color.link)
    elseif kind == ABILITY then
        local status, color = AbilityStatus(entry)
        row.right:SetText(status)
        Theme:SetTextColor(row.right, color)
        PlaceRowText(row, Theme.font.body, Theme.color.text, row.right)
        row.text:SetText(C_Spell.GetSpellName(entry.ability.ranks[1][RANK_SPELL]) or "")
        ClassSpells.PlaceOpenArrow(row, row.text, entry.isOpen == true)
    elseif kind == RANK then
        PlaceRowText(row, Theme.font.small, Theme.color.text, row.right)
        row.text:SetText("")
    elseif kind == TRAINER then
        row.right:SetText(ns.UI.SourceZone(entry.trainer) or "")
        PlaceRowText(row, Theme.font.body, Theme.color.text, row.right)
        row.text:SetText(ns.UI.TrainerText(entry.trainer, row.text))
    else
        PlaceRowText(row, Theme.font.small, Theme.color.muted, row.right)
        row.text:SetText(entry.text)
    end
    if GameTooltip:IsOwned(row) then OnRowEnter(row) end
end

-- The page ---------------------------------------------------------------------------

-- A family's line under the heading: "Abilities: Bite, Dash, Furious Howl
-- ·  Diet: Meat  ·  65 beasts to tame". The ability names read "" until the
-- game has sent them (ClassSpells.Load).
local function FamilySubtitle(familyID)
    local family = Data().families[familyID]
    local abilityNames, foods = {}, {}
    for _, spellID in ipairs(family.abilities) do table.insert(abilityNames, C_Spell.GetSpellName(spellID) or "") end
    for _, food in ipairs(family.diet) do table.insert(foods, FOOD_NAMES[food] or food) end
    local count = #BeastsOf(familyID)
    return Theme:JoinDots(L["Abilities: %s"]:format(table.concat(abilityNames, ", ")),
        L["Diet: %s"]:format(table.concat(foods, ", ")), Theme:Plural(count, L["%d beast to tame"],
        L["%d beasts to tame"]))
end

local function TrainerSubtitle()
    local abilityCount = #AllPetAbilities()
    return Theme:JoinDots(Theme:Plural(abilityCount, L["%d ability"], L["%d abilities"]),
        L["any pet learns them at a pet trainer"])
end

-- The chips (family pages): Near my level, All and Rare with their counts,
-- the picked one filled (as the Abilities pages' chips). The level line
-- ("Level 38  ·  Pet level 36") sits at the strip's right.
local function CreateStripParts(page)
    page.chips = {}
    for i, filter in ipairs(CHIP_FILTERS) do
        local chip = Theme:Pill(page)
        chip.filter = filter
        chip:SetScript("OnClick", function(self)
            ns.UI.state.petFilter = self.filter
            page:Refresh()
        end)
        page.chips[i] = chip
    end
    page.levelLine = Theme:Text(page, Theme.font.body)
    Theme:SetTextColor(page.levelLine, Theme.color.muted)
end

-- A pet page's frame: the heading, and under it the list of rows
-- `createRow(column, page)` makes and `setupRow` fills. A page with
-- abilities keeps those whose ranks are open itself (ClassSpells.KeepOpenRanks).
function PetPageKit.CreatePage(parent, createRow, setupRow)
    local page = CreateFrame("Frame", nil, parent)
    -- The heading: the family's icon (the stable master's mark on Pet trainer;
    -- a demon's on the warlock's pages) in the class badges' bronze ring, its
    -- name, and the line under it, as on the class Overview.
    ns.UI.CreateBadgeHeading(page)
    page.column = Theme:ScrollColumn(page, function(column) return createRow(column, page) end, setupRow)

    -- The badge's icon (a texture file, or with `isAtlas` an atlas), the
    -- title and the line under it, then the rows placed under that line.
    function page:SetHeading(title, subtitle, icon, isAtlas)
        self.badge:SetIcon(icon, isAtlas)
        self.title:SetText(title)
        self.subtitle:SetText(subtitle)
        self:PlaceColumn()
    end

    -- The rows under the line below the heading, hung from the page itself:
    -- beast and trainer rows hold map links' secure buttons (Theme:LineHeight).
    function page:PlaceColumn()
        local top = ns.UI.BadgeHeadingBottom(self) + ROWS_GAP
        self.column:ClearAllPoints()
        self.column:SetPoint("TOPLEFT", 0, -top)
        self.column:SetPoint("BOTTOMRIGHT")
    end
    return page
end

-- What the guide pages share -------------------------------------------------------
-- The Professions Overview (UI/ProfessionOverview.lua) and the Library Books
-- page (UI/LibraryBooks.lua): their text helpers, links and redraws.

-- `text` in `color` (made opaque).
function PetPageKit.Colored(text, color)
    return Theme:ColorCode(Theme:Opaque(color)) .. text .. "|r"
end

function PetPageKit.Muted(text)
    return PetPageKit.Colored(text, Theme.color.muted)
end

-- "A, B and C": `texts` joined as the locale says "and".
function PetPageKit.JoinAnd(texts)
    if #texts < 2 then return texts[1] or "" end
    return L["%s and %s"]:format(table.concat(texts, ", ", 1, #texts - 1), texts[#texts])
end

-- A text of `row` in `font`, justified left on one line, in `color` when given.
function PetPageKit.RowText(row, font, color)
    local text = Theme:Text(row, font)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    if color then Theme:SetTextColor(text, color) end
    return text
end

-- The game's name of zone `map` (a uiMapID), else its number.
function PetPageKit.ZoneName(map)
    local info = C_Map.GetMapInfo(map)
    return info and info.name or tostring(map)
end

-- An item's name as the game gives it, else `fallback` (the page's data's),
-- else "item 1234". An item the client hasn't loaded yet (on a first login)
-- is asked for, once per item; the page redraws when it arrives
-- (page.onItemLoaded).
function PetPageKit.ItemName(page, itemID, fallback)
    local name = C_Item.GetItemNameByID(itemID)
    if name then return name end
    if not page.itemsAsked[itemID] then
        page.itemsAsked[itemID] = true
        ns.Items:Load(itemID, page.onItemLoaded)
    end
    return fallback or L["item %d"]:format(itemID)
end

-- Links: a page writes each of its own as needroll:<target>, pointing at
-- page.links[target] = { kind, spot (a link that pins), name, ... }, set as
-- its text is written. page.fillLinkTooltip(page, data) writes a link's
-- tooltip by its kind; page.onLinkClick(page, data), on a page whose links
-- don't all pin, opens what a click on one that doesn't pin names.

-- A needroll: link to `target` ("npc:1234"), in `color` (the link color unless given).
function PetPageKit.Link(target, text, color)
    return ("|Hneedroll:%s|h%s%s|r|h"):format(target, Theme:ColorCode(color or Theme.color.link), text)
end

-- What `link` points at on `page`; nil for an item link or one not written on it.
local function LinkData(page, link)
    return page.links[link:match("^needroll:(.+)") or ""]
end

-- A link's tooltip at the cursor: an item's is the game's own.
local function ShowLinkTooltip(page, owner, link)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    if link:match("^item:") then
        GameTooltip:SetHyperlink(link)
        return
    end
    local data = LinkData(page, link)
    if not data then return GameTooltip:Hide() end
    page.fillLinkTooltip(page, data)
    GameTooltip:Show()
end

-- The mouse came onto a link in `owner`'s text (a row, or the page's lines
-- under the heading): its tooltip, and a link that pins a spot gets the
-- secure /mappin button over it (UI.HoverMapLink). A row keeps the link,
-- so its click knows the link took it (the pages' OnRowClick).
local function OnLinkEnter(page, owner, link)
    owner.overLink = link
    ShowLinkTooltip(page, owner, link)
    local data = LinkData(page, link)
    ns.UI.HoverMapLink(owner, data and data.spot, nil, function() ShowLinkTooltip(page, owner, link) end)
end

local function OnLinkLeave(owner)
    owner.overLink = nil
    GameTooltip:Hide()
    ns.UI.LeaveMapLink(owner)
end

-- A click that reaches NeedRoll's own code: a pin link in combat (out of
-- combat the secure button takes it) draws NeedRoll's own pin; a modified
-- click on an item links it in chat; any other link is the page's
-- (page.onLinkClick, where it has one).
local function OnLinkClick(page, link)
    local itemID = tonumber(link:match("^item:(%d+)") or "")
    if itemID then
        if IsModifiedClick() then ns.Items:HandleModifiedClick(itemID) end
        return
    end
    local data = LinkData(page, link)
    if not data then return end
    GameTooltip:Hide()
    if data.spot then
        ns.UI.ShowOnMap(data.spot, data.name)
        return
    end
    if page.onLinkClick then page.onLinkClick(page, data) end
end

-- Lets the links in `frame`'s text (`page` itself, or one of its rows) show
-- their tooltips and take clicks, as above.
function PetPageKit.WireLinks(frame, page)
    frame:SetHyperlinksEnabled(true)
    frame:SetScript("OnHyperlinkEnter", function(self, link) OnLinkEnter(page, self, link) end)
    frame:SetScript("OnHyperlinkLeave", OnLinkLeave)
    frame:SetScript("OnHyperlinkClick", function(_, link) OnLinkClick(page, link) end)
end

-- Gives `page` page:RefreshSoon(): a quest done, a bag change or an item's
-- name arriving redraws it (page:Refresh) once for a burst of them in one
-- frame, while it shows.
function PetPageKit.AddRefreshSoon(page)
    local isRefreshPending = false
    function page:RefreshSoon()
        if isRefreshPending or not self:IsVisible() then return end
        isRefreshPending = true
        C_Timer.After(0, function()
            isRefreshPending = false
            if self:IsVisible() then self:Refresh() end
        end)
    end
    page.onItemLoaded = function() page:RefreshSoon() end
end

-- The pet page. `parent` is the Classes tab; MainFrame.lua hosts the page
-- in the tab's content pane, with its strip.
function ns.UI.CreateHunterPetPage(parent)
    local page = PetPageKit.CreatePage(parent, CreateRow, SetupRow)
    ClassSpells.KeepOpenRanks(page, "hunterPets")
    CreateStripParts(page)

    function page:PlaceStrip(strip)
        for _, chip in ipairs(self.chips) do chip:SetParent(strip) end
        self.chips[1]:SetPoint("LEFT", STRIP_INSET, 0)
        for i = 2, #self.chips do self.chips[i]:SetPoint("LEFT", self.chips[i - 1], "RIGHT", CHIP_GAP, 0) end
        self.levelLine:SetParent(strip)
        self.levelLine:SetPoint("RIGHT", -STRIP_INSET, 0)
    end

    -- The chips' labels with how many beasts each lists of the family's
    -- `beasts`, the picked one filled; hidden on Pet trainer (`beasts` nil).
    function page:UpdateChips(beasts, filter, level)
        for _, chip in ipairs(self.chips) do
            chip:SetShown(beasts ~= nil)
            if beasts then
                local count = #ListedBeasts(beasts, chip.filter, level)
                chip:SetLabel(("%s  %d"):format(CHIP_LABELS[chip.filter], count))
                chip:SetTone(chip.filter == filter and Theme.color.heading or nil)
            end
        end
    end

    function page:ShowTitle(petPage)
        local familyID = petPage.familyID
        if not familyID then
            self:SetHeading(petPage.name, TrainerSubtitle(), TRAINER_ATLAS, true)
            return
        end
        local _, icon = FamilyInfo(familyID)
        self:SetHeading(petPage.name, FamilySubtitle(familyID), icon)
    end

    -- Every ability's name (by its rank 1) the game hasn't sent yet, redrawn
    -- once they arrive: a page names its family's and the any-pet ones, and
    -- its beasts' Teaches lines any of them.
    function page:LoadNames()
        local spellIDs = {}
        for _, ability in ipairs(Data().abilities) do table.insert(spellIDs, ability.ranks[1][RANK_SPELL]) end
        ClassSpells.Load(spellIDs, function()
            if self:IsVisible() then self:Refresh() end
        end)
    end

    -- The family's beasts nearest you first, worked out when the page is
    -- shown (you move between pages) and kept while it shows.
    function page:NearestBeasts(familyID)
        if not (self.beastOrder and self.beastOrder.familyID == familyID) then
            self.beastOrder = { familyID = familyID, beasts = ns.UI.NearestFirst(BeastsOf(familyID), BeastWorldSpot) }
        end
        return self.beastOrder.beasts
    end

    -- Redraws the page shown for the player as they are now: the heading,
    -- the chips and the rows the picked chip keeps, the opened abilities'
    -- ranks under them, keeping the scroll while the page and chip stay.
    function page:Refresh()
        local petPage = self.petPage
        if not petPage then return end
        local familyID = petPage.familyID
        local level = ns.PlayerLevel()
        local filter = ns.UI.state.petFilter or FILTER_NEAR
        local petLevel = PetLevel()
        local beasts = familyID and self:NearestBeasts(familyID)
        self:ShowTitle(petPage)
        self:UpdateChips(beasts, filter, level)
        self.levelLine:SetText(Theme:JoinDots(L["Level %d"]:format(level),
            petLevel and L["Pet level %d"]:format(petLevel)))
        local rows
        if familyID then
            rows = FamilyRows(familyID, filter, ListedBeasts(beasts, filter, level))
        else
            rows = TrainerPageRows()
        end
        rows = ClassSpells.WithRankRows(rows, function(entry) return RankRowsOf(entry, self) end)
        local place = ("%s:%s"):format(petPage.key, filter)
        self.column:SetData(rows, place == self.place)
        self.place = place
        self:LoadNames()
    end

    function page:ShowPage(petPage)
        self.petPage, self.beastOrder = petPage, nil
        self:Refresh()
    end

    -- A pet summoned, dismissed or learning a rank changes the abilities' lines.
    for _, event in ipairs({ "UNIT_PET", "PET_BAR_UPDATE" }) do
        ns:On(event, function()
            if page:IsVisible() then page:Refresh() end
        end)
    end
    return page
end
