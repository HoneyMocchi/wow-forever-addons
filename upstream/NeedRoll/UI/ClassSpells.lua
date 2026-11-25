-- The Classes tab's Abilities: each class's trainer spells (Data/ClassSpells.lua,
-- read from Classic-DB's class trainers) in its spellbook's tabs, and the
-- right pane's page for one tab. Only spell IDs, levels and costs ship: the
-- names, icons, descriptions and tooltips come from the game by spell ID.
-- A level or cost the player has read at WoW: Forever's own class trainers
-- since shows in place of the shipped one (Core/Trainers.lua, through
-- ns.Data:ClassSpells); ones heard from other players wait for a data update.
-- Your own class shows the ranks you know (C_SpellBook.IsSpellKnown), the
-- ranks you can train now and what is left to pay up to the level cap;
-- another class shows the levels each spell is trained at and its cost.
-- A priest's racial spells sit on a Racial Abilities page of their own,
-- under each race's heading: only your own race's count as yours.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L
local Talents = ns.Talents

local ClassSpells = {}
ns.UI.ClassSpells = ClassSpells

local STRIP_INSET = Size.pad - 4  -- the chips and the level line, from the strip's ends (as Back's)
local CHIP_GAP = 6                -- between two chips
local HEADING_LEFT = 16           -- the heading, the line under it and the spells' icons, in from the left
local HEADING_TOP = 12            -- the heading, down from the pane's top
local SUBTITLE_GAP = 4            -- between the heading and the line under it
local ROWS_GAP = 10               -- between the line under the heading and the first spell
local SPELL_ROW = 46              -- a spell's row
local ICON = 32                   -- its icon, centred in the row
local ICON_GAP = 10               -- between the icon and the name
local NAME_TOP = 7                -- the name, down from the row's top
local ABOUT_TOP = 25              -- the description and the training line, down from the row's top
local RIGHT_INSET = 16            -- the rank dots and the training line, in from the row's right
local DOT = 7                     -- a rank's dot
local DOT_GAP = 3                 -- between two dots
local DOTS_TOP = 10               -- the dots, down from the row's top (level with the name)
local TEXT_ROOM = 12              -- the least room between the name or description and what's right of it
local RACE_ROW = 36               -- a race's heading on the Racial Abilities page
local RACE_BADGE = 24             -- its race's icon in the class badges' ring, centred where a spell's icon is
local RACE_NOTE_GAP = 8           -- between the race's name and its side after it
local RANK_ROW = 20               -- a rank's row under an opened spell (or pet ability)
local RANK_NAME_COLUMN = 64       -- its "Rank 3", from the row's text edge
local RANK_LEVEL_COLUMN = 84      -- its level ("Level 20", "Pet level 20"), after that
local RANK_STATE_COLUMN = 70      -- its state ("Known", "Train now", "Later") at the right
local RANK_COLUMN_GAP = 8         -- between its cost and its state
local OPEN_ARROW = 10             -- the arrow after a spell's name, pointing down while its ranks show (as the
                                  -- Overview's "N more trainers" arrow)
local OPEN_ARROW_GAP = 6          -- between the name and that arrow

-- Spell rows' rank fields: { spellID, level, copper }; a rank 1 from a
-- quest or talent is { spellID } alone (no level or cost: no trainer has it),
-- and one no Classic trainer taught (new in WoW: Forever, or the priest's Fear
-- Ward), whose price isn't known, { spellID, level }.
local RANK_SPELL, RANK_LEVEL, RANK_COST = 1, 2, 3

-- The page's chips, in order: every spell, the spells with a rank to train
-- now, and the spells with a rank at the next level that brings one.
local FILTER_ALL, FILTER_TRAIN, FILTER_NEXT = "ALL", "TRAIN", "NEXT"
local CHIP_FILTERS = { FILTER_ALL, FILTER_TRAIN, FILTER_NEXT }
-- The Overview's boxes open a tab on its Train now or next level chip.
ClassSpells.FILTER_ALL, ClassSpells.FILTER_TRAIN, ClassSpells.FILTER_NEXT = FILTER_ALL, FILTER_TRAIN, FILTER_NEXT

-- Your own class's first page: every spell with a rank to train now,
-- whichever spellbook tab it sits in (the Overview's Train now opens it).
local TRAINABLE = "TRAINABLE"
ClassSpells.TRAINABLE = TRAINABLE

-- The tab of the spells only one race has (Data/ClassSpells.lua marks each
-- with its race ID), listed under a heading per race.
local RACIAL = "RACIAL"

-- The spellbook tabs' names, by the keys Data/ClassSpells.lua uses: the
-- classic talent trees, General (weapon and armor skills) and the mage's
-- teleports and portals.
local TAB_NAMES = {
    ARMS = L["Arms"], FURY = L["Fury"], PROTECTION = L["Protection"],
    HOLY = L["Holy"], RETRIBUTION = L["Retribution"],
    BEAST_MASTERY = L["Beast Mastery"], MARKSMANSHIP = L["Marksmanship"], SURVIVAL = L["Survival"],
    ASSASSINATION = L["Assassination"], COMBAT = L["Combat"], SUBTLETY = L["Subtlety"],
    DISCIPLINE = L["Discipline"], SHADOW = L["Shadow"],
    ELEMENTAL = L["Elemental"], ENHANCEMENT = L["Enhancement"], RESTORATION = L["Restoration"],
    ARCANE = L["Arcane"], FIRE = L["Fire"], FROST = L["Frost"], PORTALS = L["Teleports & Portals"],
    AFFLICTION = L["Affliction"], DEMONOLOGY = L["Demonology"], DESTRUCTION = L["Destruction"],
    BALANCE = L["Balance"], FERAL_COMBAT = L["Feral Combat"],
    GENERAL = L["General"],
    RACIAL = L["Racial Abilities"],
    TRAINABLE = L["Trainable"],
}

-- Spells ------------------------------------------------------------------------

local function ClassToken(classID)
    return select(2, GetClassInfo(classID))
end

local function IsPlayerClass(classID)
    return classID == Talents.PlayerClassID()
end

-- Whether the game has any rank of `spell`: Forever may have dropped one.
local function GameHas(spell)
    for _, rank in ipairs(spell.ranks) do
        if C_Spell.DoesSpellExist(rank[RANK_SPELL]) then return true end
    end
    return false
end

-- Each class's spells the game has, worked out once per class token.
local spellsByClass = {}

local function SpellsTheGameHas(token)
    if spellsByClass[token] then return spellsByClass[token] end
    local data = ns.Data:ClassSpells(token)
    local spells = {}
    for _, spell in ipairs(data and data.spells or {}) do
        if GameHas(spell) then table.insert(spells, spell) end
    end
    spellsByClass[token] = spells
    return spells
end

local function PlayerRaceID()
    return select(3, UnitRace("player"))
end

-- Whether a spell of your own class is one you can have: a racial spell
-- only for its race, else one your side's trainers teach.
local function IsYours(spell)
    if spell.race then return spell.race == PlayerRaceID() end
    return not spell.side or spell.side == ns.PlayerFaction()
end

-- The spells counted for class `classID`: your own class's only yours
-- (IsYours), another class's both sides' and every race's (as Quests lists
-- them).
function ClassSpells.Of(classID)
    local spells = SpellsTheGameHas(ClassToken(classID))
    if not IsPlayerClass(classID) then return spells end
    local mine = {}
    for _, spell in ipairs(spells) do
        if IsYours(spell) then table.insert(mine, spell) end
    end
    return mine
end

-- The class's racial spells, every race's, your own race's first: another
-- race's are still listed on your own class, as the trainers' levels and costs.
local function RacialSpells(classID)
    local yourRace, others = {}, {}
    for _, spell in ipairs(SpellsTheGameHas(ClassToken(classID))) do
        if spell.tab == RACIAL then
            table.insert(spell.race == PlayerRaceID() and yourRace or others, spell)
        end
    end
    for _, spell in ipairs(others) do table.insert(yourRace, spell) end
    return yourRace
end

-- Whether the player can train a rank of `spell` now.
local function IsTrainable(spell)
    return ClassSpells.Progress(spell, ns.PlayerLevel()).trainFirst ~= nil
end

-- The class's spells in spellbook tab `tab`, or with a rank to train now
-- on the Trainable page.
local function SpellsIn(classID, tab)
    if tab == RACIAL then return RacialSpells(classID) end
    local inTab = {}
    for _, spell in ipairs(ClassSpells.Of(classID)) do
        local isListed = (tab == TRAINABLE and IsTrainable(spell)) or spell.tab == tab
        if isListed then table.insert(inTab, spell) end
    end
    return inTab
end

-- The class's spellbook tabs that list a spell, in the spellbook's order;
-- your own class's start with Trainable, even when there's nothing to train.
function ClassSpells.Tabs(classID)
    local data = ns.Data:ClassSpells(ClassToken(classID))
    local tabs = {}
    if IsPlayerClass(classID) and data then table.insert(tabs, TRAINABLE) end
    for _, tab in ipairs(data and data.tabs or {}) do
        if #SpellsIn(classID, tab) > 0 then table.insert(tabs, tab) end
    end
    return tabs
end

function ClassSpells.TabName(tab)
    return TAB_NAMES[tab] or tab
end

-- How many spells tab `tab` lists, for its row in the sections column;
-- on your own class only yours (another race's racial spells aren't).
function ClassSpells.TabCount(classID, tab)
    local spells = SpellsIn(classID, tab)
    if not IsPlayerClass(classID) then return #spells end
    local count = 0
    for _, spell in ipairs(spells) do
        if IsYours(spell) then count = count + 1 end
    end
    return count
end

-- The highest rank of `spell` the player knows, 0 for none; with
-- `spellBank` Enum.SpellBookSpellBank.Pet, the rank the player's pet knows.
-- A rank is only trained after the one before it, so the ranks under it
-- are known too.
local function KnownRank(spell, spellBank)
    for i = #spell.ranks, 1, -1 do
        if C_SpellBook.IsSpellKnown(spell.ranks[i][RANK_SPELL], spellBank) then return i end
    end
    return 0
end

-- Where the player stands with `spell` at `level`: `known`, the highest
-- rank known; `trainFirst` to `trainLast`, the ranks a trainer teaches them
-- now, for `trainCost`; `nextRank`, the next one after those; `leftCost`,
-- what every rank still to train costs. Training runs up from the first
-- rank not known while the level allows, as each rank needs the one before
-- it; a rank 1 from a quest or talent isn't a trainer's, so a spell whose
-- rank 1 the player hasn't got has nothing to train or pay for.
-- `spellBank` (nil: the player's) reads the pet's spellbook instead, for
-- the pet abilities a pet has at its `level` (UI/HunterPets.lua), whose
-- ranks no trainer sells have no cost (counted as nothing here).
function ClassSpells.Progress(spell, level, spellBank)
    local ranks = spell.ranks
    local known = KnownRank(spell, spellBank)
    local progress = { known = known, trainCost = 0, leftCost = 0 }
    local index = known + 1
    while ranks[index] and ranks[index][RANK_LEVEL] and ranks[index][RANK_LEVEL] <= level do
        progress.trainFirst = progress.trainFirst or index
        progress.trainLast = index
        progress.trainCost = progress.trainCost + (ranks[index][RANK_COST] or 0)
        index = index + 1
    end
    if ranks[index] and ranks[index][RANK_LEVEL] then progress.nextRank = index end
    if known == 0 and not ranks[1][RANK_LEVEL] then return progress end
    for i = known + 1, #ranks do progress.leftCost = progress.leftCost + (ranks[i][RANK_COST] or 0) end
    return progress
end

-- The Abilities header's figure: for your own class how many of its spells
-- you've trained ("31/47", as Quests counts done quests); for another
-- class, how many it has.
function ClassSpells.CountText(classID)
    local spells = ClassSpells.Of(classID)
    if not IsPlayerClass(classID) then return tostring(#spells) end
    local trained = 0
    for _, spell in ipairs(spells) do
        if KnownRank(spell) > 0 then trained = trained + 1 end
    end
    return ("%d/%d"):format(trained, #spells)
end

-- What's ahead for your own class (the Overview page) ------------------------------

-- A rank as the Overview names it: { spellID, rank (its number), cost, tab,
-- level (the level a trainer teaches it at; nil for a rank 1 from a quest or
-- talent), spell (the spell it is a rank of, ClassSpells.Of's entry) }.
local function RankRef(spell, index)
    local rank = spell.ranks[index]
    return { spellID = rank[RANK_SPELL], rank = index, cost = rank[RANK_COST] or 0, tab = spell.tab,
        level = rank[RANK_LEVEL], spell = spell }
end

-- "Frostbolt 7", or the name alone for a rank 1. Empty until the game has
-- sent the spell's name (ClassSpells.Load).
function ClassSpells.RankName(ref)
    local name = C_Spell.GetSpellName(ref.spellID) or ""
    if ref.rank == 1 or name == "" then return name end
    return ("%s %d"):format(name, ref.rank)
end

-- Where the player stands with all of their class's spells at `level`:
-- `trained` of `total` spells; `trainNow`, the ranks to train now
-- (RankRef), for `trainCost`; `ahead`, level -> the ranks first trained
-- there, for each level above `level` that brings one, and `aheadLevels`,
-- those levels lowest first; `leftCost`, what every rank still to train
-- costs. A spell whose rank 1 comes from a quest or talent the player
-- hasn't got has nothing ahead (ClassSpells.Progress).
function ClassSpells.Outlook(classID, level)
    local outlook = { trained = 0, total = 0, trainNow = {}, trainCost = 0, ahead = {}, aheadLevels = {},
        leftCost = 0 }
    for _, spell in ipairs(ClassSpells.Of(classID)) do
        local progress = ClassSpells.Progress(spell, level)
        outlook.total = outlook.total + 1
        if progress.known > 0 then outlook.trained = outlook.trained + 1 end
        outlook.trainCost = outlook.trainCost + progress.trainCost
        outlook.leftCost = outlook.leftCost + progress.leftCost
        for index = progress.trainFirst or 1, progress.trainLast or 0 do
            table.insert(outlook.trainNow, RankRef(spell, index))
        end
        local first = progress.trainLast and progress.trainLast + 1 or progress.nextRank
        for index = first or #spell.ranks + 1, #spell.ranks do
            local rankLevel = spell.ranks[index][RANK_LEVEL]
            if not outlook.ahead[rankLevel] then
                outlook.ahead[rankLevel] = {}
                table.insert(outlook.aheadLevels, rankLevel)
            end
            table.insert(outlook.ahead[rankLevel], RankRef(spell, index))
        end
    end
    table.sort(outlook.aheadLevels)
    return outlook
end

-- What every rank of class `classID`'s spells costs, for another class's Overview.
function ClassSpells.AllRanksCost(classID)
    local cost = 0
    for _, spell in ipairs(ClassSpells.Of(classID)) do
        for _, rank in ipairs(spell.ranks) do cost = cost + (rank[RANK_COST] or 0) end
    end
    return cost
end

-- Asks the game for the spells it hasn't sent yet (their names and
-- descriptions read "" until it comes), running `onLoaded` once all of a
-- burst has arrived. Returns how many it is waiting for: with 0, every
-- spell is already there and `onLoaded` doesn't run.
function ClassSpells.Load(spellIDs, onLoaded)
    local waiting = 0
    for _, spellID in ipairs(spellIDs) do
        local spell = Spell:CreateFromSpellID(spellID)
        if not spell:IsSpellDataCached() then
            waiting = waiting + 1
            spell:ContinueOnSpellLoad(function()
                waiting = waiting - 1
                if waiting == 0 then onLoaded() end
            end)
        end
    end
    return waiting
end

-- The page's figures ----------------------------------------------------------------

-- The levels a spell's trainers teach it at: "Level 20", "Levels 4 to 56".
local function LevelsText(spell)
    local first, last
    for _, rank in ipairs(spell.ranks) do
        if rank[RANK_LEVEL] then
            first = first or rank[RANK_LEVEL]
            last = rank[RANK_LEVEL]
        end
    end
    if first == last then return L["Level %d"]:format(first) end
    return L["Levels %d to %d"]:format(first, last)
end

-- What all of a spell's trained ranks cost.
local function TotalCost(spell)
    local total = 0
    for _, rank in ipairs(spell.ranks) do total = total + (rank[RANK_COST] or 0) end
    return total
end

-- Where rank 1 of a spell no trainer starts comes from.
local function FirstRankText(spell)
    if spell.first == "talent" then return L["Rank 1 from a talent"] end
    if spell.first == "quest" then return L["Rank 1 from a quest"] end
end

-- After the spell's name: the rank you have ("Rank 6 of 10"), or for
-- another class how many ranks it has.
local function RankText(entry)
    local count, progress = #entry.spell.ranks, entry.progress
    if not progress then return count > 1 and L["%d ranks"]:format(count) or "" end
    if progress.known == 0 then return L["Not trained"] end
    if count == 1 then return L["Trained"] end
    return L["Rank %d of %d"]:format(progress.known, count)
end

-- The line under the rank dots, and its color: what to train now, the next
-- rank's level and cost, or (another class) the levels and the whole cost.
local function StatusText(entry)
    local spell, progress = entry.spell, entry.progress
    if not progress then
        local wholeCost = ns.Money(TotalCost(spell))
        return Theme:JoinDots(FirstRankText(spell), LevelsText(spell), wholeCost), Theme.color.muted
    end
    if progress.trainFirst then
        local which = progress.trainFirst == progress.trainLast and L["Train now: rank %d"]:format(progress.trainLast)
            or L["Train now: ranks %d to %d"]:format(progress.trainFirst, progress.trainLast)
        return Theme:JoinDots(which, ns.Money(progress.trainCost)), Theme.color.complete
    end
    if progress.nextRank then
        local rank = spell.ranks[progress.nextRank]
        return Theme:JoinDots(L["Rank %d at level %d"]:format(progress.nextRank, rank[RANK_LEVEL]),
            ns.Money(rank[RANK_COST] or 0)), Theme.color.muted
    end
    if progress.known < #spell.ranks then return FirstRankText(spell) or "", Theme.color.muted end
    return L["All ranks trained"], Theme.color.muted
end

-- The rank a row's icon, name and description show: the one you know, else
-- rank 1. Its tooltip shows the rank its training line names.
local function ShownRank(entry)
    local progress = entry.progress
    return math.max(progress and progress.known or 0, 1)
end

local function TooltipRank(entry)
    local progress = entry.progress
    if not progress then return #entry.spell.ranks end
    return progress.trainLast or progress.nextRank or ShownRank(entry)
end

-- Where rank `index` stands for you (or your pet) by `progress`
-- (ClassSpells.Progress): KNOWN, TRAIN_NOW (its level reached), else LATER;
-- nil without progress (another class, or no pet out).
local KNOWN, TRAIN_NOW, LATER = "KNOWN", "TRAIN_NOW", "LATER"

local function RankStanding(progress, index)
    if not progress then return nil end
    if index <= progress.known then return KNOWN end
    if progress.trainFirst and index >= progress.trainFirst and index <= progress.trainLast then return TRAIN_NOW end
    return LATER
end

-- The rank dots' colors: ranks you know gold, ranks to train now green,
-- the rest (and every rank of another class) faint.
local STANDING_DOT_COLORS = { [KNOWN] = "accepted", [TRAIN_NOW] = "complete" }

local function DotColor(progress, index)
    return Theme.color[STANDING_DOT_COLORS[RankStanding(progress, index)] or "faint"]
end

-- Rank rows -----------------------------------------------------------------------
-- A click on a spell's row (or a hunter pet ability's, UI/HunterPets.lua, or
-- a demon's, UI/WarlockPets.lua) opens a row per rank under it: "Rank 3",
-- its level, its cost and where it stands for you.

local STANDING_TEXTS = { [KNOWN] = L["Known"], [TRAIN_NOW] = L["Train now"], [LATER] = L["Later"] }
local STANDING_COLORS = { [KNOWN] = "accepted", [TRAIN_NOW] = "complete", [LATER] = "muted" }

-- Rank `index` of `spell` as a row's entry: `levelText` and `costText` as
-- the page words them, its state from `progress` (nil: none shown). A rank
-- with no level (rank 1 from a quest or talent) has no state until known.
function ClassSpells.RankEntry(spell, index, progress, levelText, costText)
    local standing = RankStanding(progress, index)
    if standing ~= KNOWN and not spell.ranks[index][RANK_LEVEL] then standing = nil end
    return { height = RANK_ROW, rankOf = spell, rankIndex = index, spellID = spell.ranks[index][RANK_SPELL],
        levelText = levelText, costText = costText, standing = standing, isLastRank = index == #spell.ranks }
end

-- `entries` with, after each one `ranksOf(entry)` gives rank entries for
-- (an opened spell's), those rows.
function ClassSpells.WithRankRows(entries, ranksOf)
    local withRanks = {}
    for _, entry in ipairs(entries) do
        table.insert(withRanks, entry)
        for _, rankEntry in ipairs(ranksOf(entry) or {}) do table.insert(withRanks, rankEntry) end
    end
    return withRanks
end

-- A rank row's texts on `row`, from `left` (the spell name's edge): the
-- rank, its level, its state at the right and its cost right before that.
function ClassSpells.CreateRankParts(row, left)
    local parts = {}
    parts.name = Theme:Text(row, Theme.font.small)
    parts.name:SetPoint("LEFT", left, 0)
    parts.name:SetWidth(RANK_NAME_COLUMN)
    parts.name:SetJustifyH("LEFT")
    parts.level = Theme:Text(row, Theme.font.small)
    parts.level:SetPoint("LEFT", left + RANK_NAME_COLUMN, 0)
    parts.level:SetWidth(RANK_LEVEL_COLUMN)
    parts.level:SetJustifyH("LEFT")
    Theme:SetTextColor(parts.level, Theme.color.muted)
    parts.state = Theme:Text(row, Theme.font.small)
    parts.state:SetPoint("RIGHT", -RIGHT_INSET, 0)
    parts.state:SetWidth(RANK_STATE_COLUMN)
    parts.state:SetJustifyH("RIGHT")
    parts.cost = Theme:Text(row, Theme.font.small)
    parts.cost:SetPoint("LEFT", parts.level, "RIGHT", RANK_COLUMN_GAP, 0)
    parts.cost:SetPoint("RIGHT", parts.state, "LEFT", -RANK_COLUMN_GAP, 0)
    parts.cost:SetJustifyH("RIGHT")
    parts.cost:SetWordWrap(false)
    Theme:SetTextColor(parts.cost, Theme.color.muted)
    row.rankParts = parts
end

-- Fills the rank texts from rank `entry`, or hides them for another row (nil).
function ClassSpells.ShowRankParts(row, entry)
    for _, part in pairs(row.rankParts) do part:SetShown(entry ~= nil) end
    if not entry then return end
    local parts = row.rankParts
    parts.name:SetText(L["Rank %d"]:format(entry.rankIndex))
    parts.level:SetText(entry.levelText or "")
    parts.cost:SetText(entry.costText or "")
    parts.state:SetText(STANDING_TEXTS[entry.standing] or "")
    Theme:SetTextColor(parts.state, Theme.color[STANDING_COLORS[entry.standing] or "muted"])
end

-- The arrow after a spell's name on `row`, turned down while its ranks show.
function ClassSpells.CreateOpenArrow(row)
    row.openArrow = Theme:Arrow(row, true, OPEN_ARROW)
end

-- Puts the arrow right after the words of `nameText` (no further than its
-- right edge), open or shut; nil `isOpen` hides it.
function ClassSpells.PlaceOpenArrow(row, nameText, isOpen)
    row.openArrow:SetShown(isOpen ~= nil)
    if isOpen == nil then return end
    local wordsWidth = math.ceil(nameText:GetStringWidth())
    local room = nameText:GetWidth()
    if room > 0 then wordsWidth = math.min(wordsWidth, math.ceil(room)) end
    row.openArrow:SetOpen(isOpen)
    row.openArrow:ClearAllPoints()
    row.openArrow:SetPoint("LEFT", nameText, "LEFT", wordsWidth + OPEN_ARROW_GAP, 0)
end

-- A rank row's tooltip: that rank's spell.
function ClassSpells.ShowRankTooltip(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:SetSpellByID(row.data.spellID)
    GameTooltip:Show()
end

-- Puts spell `spellID`'s link in chat (Shift-click on a spell's or rank's row).
function ClassSpells.LinkInChat(spellID)
    local link = C_Spell.GetSpellLink(spellID)
    if link then ChatFrameUtil.InsertLink(link) end
end

-- The key a spell's (or pet ability's) open ranks are remembered by: its
-- first rank's spell ID, the same whichever class, tab or family lists it.
local function RanksKey(spell)
    return spell.ranks[1][RANK_SPELL]
end

-- A page's spells whose ranks show (page.openRanks, by RanksKey), kept as
-- Settings' "Remember sections" says (ns.SectionMemory's `area` area:
-- "spells", "hunterPets" or "warlockPets"). Each starts shut. A click opens
-- or shuts one; leaving the page or showing another tab keeps them.
function ClassSpells.KeepOpenRanks(page, area)
    page.openRanks = ns.SectionMemory.Area(area)
    ns.SectionMemory.OnModeChange(function()
        page.openRanks = ns.SectionMemory.Area(area)
        if page:IsVisible() then page:Refresh() end
    end)
end

-- Whether `spell`'s ranks show on `page` (see KeepOpenRanks).
function ClassSpells.AreRanksOpen(page, spell)
    return ns.SectionMemory.IsOpen(page.openRanks, RanksKey(spell))
end

function ClassSpells.ToggleRanks(page, spell)
    ns.SectionMemory.Toggle(page.openRanks, RanksKey(spell))
    page:Refresh()
end

-- Rows ----------------------------------------------------------------------------

local function SpellOf(entry, rankIndex)
    return entry.spell.ranks[rankIndex][RANK_SPELL]
end

-- A spell's row shows the game's tooltip of the rank its training line
-- names; a rank's row, that rank's.
local function ShowTooltip(row)
    local entry = row.data
    if entry.rankIndex then return ClassSpells.ShowRankTooltip(row) end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:SetSpellByID(SpellOf(entry, TooltipRank(entry)))
    GameTooltip:Show()
end

-- How wide `count` rank dots are.
local function DotsWidth(count)
    return count * (DOT + DOT_GAP) - DOT_GAP
end

-- One dot per rank, right to left from the row's top right corner; none
-- (`entry` nil) on a rank's row.
local function ShowDots(row, entry)
    local count = entry and #entry.spell.ranks or 0
    row.dots = row.dots or {}
    for i = 1, count do
        local dot = row.dots[i]
        if not dot then
            dot = row:CreateTexture(nil, "ARTWORK")
            dot:SetTexture(Theme.roundMask)
            dot:SetSize(DOT, DOT)
            row.dots[i] = dot
        end
        dot:ClearAllPoints()
        dot:SetPoint("TOPRIGHT", -RIGHT_INSET - (count - i) * (DOT + DOT_GAP), -DOTS_TOP)
        dot:SetVertexColor(unpack(DotColor(entry.progress, i)))
        dot:Show()
    end
    for i = count + 1, #row.dots do row.dots[i]:Hide() end
end

-- The parts only a spell's row shows, shown or hidden together; its dots
-- and open arrow are placed by SetupSpellRow, so here they only hide.
local function ShowSpellParts(row, isShown)
    for _, part in ipairs({ row.iconBorder, row.icon, row.name, row.status, row.about }) do part:SetShown(isShown) end
    if isShown then return end
    ShowDots(row, nil)
    ClassSpells.PlaceOpenArrow(row, row.name, nil)
end

-- The race icons' names in the game's atlases, where they differ from the
-- race's file name lowercased (C_CreatureInfo.GetRaceInfo's clientFileString).
local RACE_ICON_NAMES = { Scourge = "undead" }

-- The game's icon of a race (`raceInfo` from C_CreatureInfo.GetRaceInfo),
-- the male portrait for every race; nil when the client has no such atlas.
local function RaceIconAtlas(raceInfo)
    local fileName = raceInfo and raceInfo.clientFileString
    if not fileName then return nil end
    local atlas = ("raceicon-%s-male"):format(RACE_ICON_NAMES[fileName] or fileName:lower())
    if not C_Texture.GetAtlasInfo(atlas) then return nil end
    return atlas
end

-- A race's heading on the Racial Abilities page: its icon in a ring badge,
-- its name, then its side. Without an icon the name stays where it is.
-- It takes no clicks, so it has no tooltip and doesn't open.
local function ShowRaceParts(row, entry)
    local isRace = entry.race ~= nil
    row.raceBadge:SetShown(isRace)
    row.raceName:SetShown(isRace)
    row.raceSide:SetShown(isRace)
    row:EnableMouse(not isRace)
    if not isRace then return end
    local raceInfo = C_CreatureInfo.GetRaceInfo(entry.race)
    local iconAtlas = RaceIconAtlas(raceInfo)
    if iconAtlas then
        row.raceBadge:SetIcon(iconAtlas, true)
    else
        row.raceBadge:Hide()
    end
    row.raceName:SetText(raceInfo and raceInfo.raceName or "")
    row.raceSide:SetText(ns.SideName(entry.side))
    if GameTooltip:IsOwned(row) then GameTooltip_Hide() end
end

-- A row of the list as a race's heading, a spell's row or one of its ranks.
local function SetupSpellRow(row, entry)
    local isRace, isRank = entry.race ~= nil, entry.rankIndex ~= nil
    -- The 1px rule closes a spell's block: under a shut spell, or under its
    -- last rank. A race's heading has none.
    row.rule:SetShown(not isRace and not entry.isOpen and (not isRank or entry.isLastRank))
    ShowSpellParts(row, not (isRace or isRank))
    ClassSpells.ShowRankParts(row, isRank and entry or nil)
    ShowRaceParts(row, entry)
    if isRace then return end
    if isRank then
        if GameTooltip:IsOwned(row) then ShowTooltip(row) end
        return
    end
    local spellID = SpellOf(entry, ShownRank(entry))
    row.icon:SetTexture(C_Spell.GetSpellTexture(spellID))
    row.name:SetText(("%s  %s%s|r"):format(C_Spell.GetSpellName(spellID) or "", Theme:ColorCode(Theme.color.muted),
        RankText(entry)))
    local status, color = StatusText(entry)
    row.status:SetText(status)
    Theme:SetTextColor(row.status, color)
    -- Its first line only: the row has room for one, and a line break would
    -- draw the rest over the row below.
    row.about:SetText((C_Spell.GetSpellDescription(spellID) or ""):match("^[^\r\n]*"))
    row.name:SetPoint("TOPRIGHT", -(RIGHT_INSET + DotsWidth(#entry.spell.ranks) + TEXT_ROOM), -NAME_TOP)
    ClassSpells.PlaceOpenArrow(row, row.name, entry.isOpen == true)
    ShowDots(row, entry)
    if GameTooltip:IsOwned(row) then ShowTooltip(row) end
end

-- Shift-click links the spell the row's tooltip shows in chat; a plain
-- click on a spell's row opens or shuts its ranks.
local function OnSpellRowClick(row, page)
    local entry = row.data
    if IsModifiedClick("CHATLINK") then
        ClassSpells.LinkInChat(entry.rankIndex and entry.spellID or SpellOf(entry, TooltipRank(entry)))
        return
    end
    if entry.rankIndex then return end
    GameTooltip:Hide()
    ClassSpells.ToggleRanks(page, entry.spell)
end

-- A row of the list. A spell's: its icon, its name with the rank you have
-- and the open arrow, the start of its description under it; at the right
-- its rank dots over its training line. A rank's: CreateRankParts' texts,
-- level with the name. A race's heading: its badge where the icon is, its
-- name and side level with the spells' names.
local function CreateSpellRow(column, page)
    local row = Theme:Row(column, SPELL_ROW)
    Theme:QualityIcon(row)
    row.iconBorder:SetSize(ICON, ICON)
    row.iconBorder:SetPoint("LEFT", HEADING_LEFT, 0)
    row:SetBorderColor(unpack(Theme.color.line))
    local textLeft = HEADING_LEFT + ICON + ICON_GAP
    row.name = Theme:Text(row, Theme.font.body)
    row.name:SetPoint("TOPLEFT", textLeft, -NAME_TOP)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    ClassSpells.CreateOpenArrow(row)
    row.status = Theme:Text(row, Theme.font.small)
    row.status:SetPoint("TOPRIGHT", -RIGHT_INSET, -ABOUT_TOP)
    row.status:SetJustifyH("RIGHT")
    row.about = Theme:Text(row, Theme.font.small)
    row.about:SetPoint("TOPLEFT", textLeft, -ABOUT_TOP)
    row.about:SetPoint("TOPRIGHT", row.status, "TOPLEFT", -TEXT_ROOM, 0)
    row.about:SetJustifyH("LEFT")
    row.about:SetWordWrap(false)
    Theme:SetTextColor(row.about, Theme.color.muted)
    ClassSpells.CreateRankParts(row, textLeft)
    row.rule = row:CreateTexture(nil, "BORDER")
    row.rule:SetColorTexture(unpack(Theme.color.line))
    row.rule:SetHeight(1)
    row.rule:SetPoint("BOTTOMLEFT", 4, 0)
    row.rule:SetPoint("BOTTOMRIGHT", -4, 0)
    row.raceBadge = Theme:ClassBadge(row, RACE_BADGE)
    row.raceBadge:SetPoint("CENTER", row, "LEFT", HEADING_LEFT + ICON / 2, 0)
    row.raceName = Theme:Text(row, Theme.font.section)
    row.raceName:SetPoint("LEFT", textLeft, 0)
    Theme:SetTextColor(row.raceName, Theme.color.heading)
    row.raceSide = Theme:Text(row, Theme.font.small)
    row.raceSide:SetPoint("LEFT", row.raceName, "RIGHT", RACE_NOTE_GAP, 0)
    Theme:SetTextColor(row.raceSide, Theme.color.muted)
    row:RegisterForClicks("LeftButtonUp")
    row:HookScript("OnEnter", ShowTooltip)
    row:HookScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self) OnSpellRowClick(self, page) end)
    return row
end

-- The page -----------------------------------------------------------------------

-- Each spell of the tab with where the player stands with it (own class,
-- the spells that are yours only), as rows for the column.
local function Entries(classID, tab, level)
    local isOwn = IsPlayerClass(classID)
    local entries = {}
    for _, spell in ipairs(SpellsIn(classID, tab)) do
        local progress = isOwn and IsYours(spell) and ClassSpells.Progress(spell, level) or nil
        table.insert(entries, { spell = spell, progress = progress, height = SPELL_ROW })
    end
    return entries
end

-- Spell `entry`'s rank rows while they show on `page`: each rank's level
-- and cost, or where a rank 1 no trainer teaches comes from; nil while
-- shut (and on a race's heading).
local function RankRowsOf(entry, page)
    if not (entry.spell and ClassSpells.AreRanksOpen(page, entry.spell)) then return nil end
    entry.isOpen = true
    local spell, rows = entry.spell, {}
    for index, rank in ipairs(spell.ranks) do
        local level = rank[RANK_LEVEL]
        local levelText = level and L["Level %d"]:format(level) or ""
        -- A rank with a level but no price (one no Classic trainer taught) shows no cost.
        local cost = rank[RANK_COST]
        local costText = cost and ns.Money(cost) or (not level and FirstRankText(spell)) or ""
        table.insert(rows, ClassSpells.RankEntry(spell, index, entry.progress, levelText, costText))
    end
    return rows
end

-- The rows with a heading before each race's spells (Racial Abilities).
local function WithRaceHeadings(entries)
    local rows, lastRace = {}, nil
    for _, entry in ipairs(entries) do
        local spell = entry.spell
        if spell.race ~= lastRace then
            table.insert(rows, { race = spell.race, side = spell.side, height = RACE_ROW })
            lastRace = spell.race
        end
        table.insert(rows, entry)
    end
    return rows
end

-- Over the tab's spells that are yours (own class): how many there are
-- and are trained, the ranks to train now and their cost, what every rank
-- left costs, the next level a rank comes at (nil when none) and how many
-- spells have one there. Another race's racial spells have no progress and
-- aren't counted.
local function Totals(entries)
    local yours = {}
    for _, entry in ipairs(entries) do
        if entry.progress then table.insert(yours, entry) end
    end
    local totals = { yours = #yours, trained = 0, trainRanks = 0, trainSpells = 0, trainCost = 0, leftCost = 0,
        nextCount = 0 }
    for _, entry in ipairs(yours) do
        local progress = entry.progress
        if progress.known > 0 then totals.trained = totals.trained + 1 end
        if progress.trainFirst then
            totals.trainSpells = totals.trainSpells + 1
            totals.trainRanks = totals.trainRanks + progress.trainLast - progress.trainFirst + 1
            totals.trainCost = totals.trainCost + progress.trainCost
        end
        totals.leftCost = totals.leftCost + progress.leftCost
        local nextRank = progress.nextRank and entry.spell.ranks[progress.nextRank]
        if nextRank and (not totals.nextLevel or nextRank[RANK_LEVEL] < totals.nextLevel) then
            totals.nextLevel = nextRank[RANK_LEVEL]
        end
    end
    for _, entry in ipairs(yours) do
        local nextRank = entry.progress.nextRank and entry.spell.ranks[entry.progress.nextRank]
        if nextRank and nextRank[RANK_LEVEL] == totals.nextLevel then totals.nextCount = totals.nextCount + 1 end
    end
    return totals
end

-- The entries the picked chip keeps.
local function Filtered(entries, filter, totals)
    if filter == FILTER_ALL or not totals then return entries end
    local kept = {}
    for _, entry in ipairs(entries) do
        local progress = entry.progress
        local nextRank = progress and progress.nextRank and entry.spell.ranks[progress.nextRank]
        local isKept = progress ~= nil and ((filter == FILTER_TRAIN and progress.trainFirst ~= nil)
            or (filter == FILTER_NEXT and nextRank and nextRank[RANK_LEVEL] == totals.nextLevel))
        if isKept then table.insert(kept, entry) end
    end
    return kept
end

-- The line under the heading. Own class: "Mage  ·  6 of 9 spells trained
-- ·  1 rank to train now (1g 40s)  ·  To level 60: 45g 27s", the training
-- part green. Another class: "Mage  ·  9 spells  ·  45 ranks  ·  All ranks: 45g".
local function SubtitleText(className, entries, totals)
    if not totals then
        local rankCount, cost = 0, 0
        for _, entry in ipairs(entries) do
            rankCount = rankCount + #entry.spell.ranks
            cost = cost + TotalCost(entry.spell)
        end
        return Theme:JoinDots(className, Theme:Plural(#entries, L["%d spell"], L["%d spells"]),
            Theme:Plural(rankCount, L["%d rank"], L["%d ranks"]), L["All ranks: %s"]:format(ns.Money(cost)))
    end
    local trainText
    if totals.trainRanks > 0 then
        local phrase = totals.trainRanks == 1 and L["%d rank to train now (%s)"] or L["%d ranks to train now (%s)"]
        trainText = ("%s%s|r"):format(Theme:ColorCode(Theme.color.complete),
            phrase:format(totals.trainRanks, ns.Money(totals.trainCost)))
    end
    local leftText = totals.leftCost > 0
        and L["To level %d: %s"]:format(Talents.MAX_LEVEL, ns.Money(totals.leftCost)) or nil
    return Theme:JoinDots(className, L["%d of %d spells trained"]:format(totals.trained, totals.yours), trainText,
        leftText)
end

-- The heading: the tab's name, and the line under it.
local function CreateHeading(page)
    page.title = Theme:Text(page, Theme.font.instance)
    page.title:SetPoint("TOPLEFT", HEADING_LEFT, -HEADING_TOP)
    page.subtitle = Theme:Text(page, Theme.font.body)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -SUBTITLE_GAP)
    page.subtitle:SetPoint("RIGHT", -HEADING_LEFT, 0)
    page.subtitle:SetJustifyH("LEFT")
    page.subtitle:SetWordWrap(false)
    Theme:SetTextColor(page.subtitle, Theme.color.muted)
end

-- The chips (own class only): All, Train now and the next level, as pills
-- with their counts, the picked one filled (as the Wishlist's). The level
-- line ("Level 38  ·  Frost") sits at the strip's right.
local function CreateStripParts(page)
    page.chips = {}
    for i, filter in ipairs(CHIP_FILTERS) do
        local chip = Theme:Pill(page)
        chip.filter = filter
        chip:SetScript("OnClick", function(self)
            ns.UI.state.spellFilter = self.filter
            page:Refresh()
        end)
        page.chips[i] = chip
    end
    page.levelLine = Theme:Text(page, Theme.font.body)
    Theme:SetTextColor(page.levelLine, Theme.color.muted)
end

-- The spells' page. `parent` is the Classes tab; MainFrame.lua hosts the
-- page in the tab's content pane, with its strip.
function ns.UI.CreateClassSpellPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    CreateHeading(page)
    CreateStripParts(page)
    ClassSpells.KeepOpenRanks(page, "spells")
    page.column = Theme:ScrollColumn(page, function(column) return CreateSpellRow(column, page) end, SetupSpellRow)
    page.column:SetPoint("TOPLEFT", page.subtitle, "BOTTOMLEFT", -HEADING_LEFT, -ROWS_GAP)
    page.column:SetPoint("BOTTOMRIGHT")
    page.empty = Theme:Text(page, Theme.font.body)
    page.empty:SetPoint("TOPLEFT", page.column, "TOPLEFT", HEADING_LEFT, -ROWS_GAP)
    page.empty:SetText(L["Nothing to train right now."])
    Theme:SetTextColor(page.empty, Theme.color.muted)

    function page:PlaceStrip(strip)
        for _, chip in ipairs(self.chips) do chip:SetParent(strip) end
        self.chips[1]:SetPoint("LEFT", STRIP_INSET, 0)
        for i = 2, #self.chips do self.chips[i]:SetPoint("LEFT", self.chips[i - 1], "RIGHT", CHIP_GAP, 0) end
        self.levelLine:SetParent(strip)
        self.levelLine:SetPoint("RIGHT", -STRIP_INSET, 0)
    end

    -- The chips' labels and fill for the tab's totals; none on another class.
    function page:UpdateChips(entries, totals, filter)
        local counts = totals and { #entries, totals.trainSpells, totals.nextCount }
        local nextLevel = totals and totals.nextLevel
        local labels = { L["All"], L["Train now"], nextLevel and L["Level %d"]:format(nextLevel) }
        for i, chip in ipairs(self.chips) do
            chip:SetShown(counts ~= nil and labels[i] ~= nil)
            if chip:IsShown() then
                chip:SetLabel(("%s  %d"):format(labels[i], counts[i]))
                chip:SetTone(chip.filter == filter and Theme.color.heading or nil)
            end
        end
    end

    -- The rows' spells the game hasn't sent yet, redrawn once they arrive.
    function page:LoadSpells(entries)
        local spellIDs = {}
        for _, entry in ipairs(entries) do
            if entry.spell then table.insert(spellIDs, SpellOf(entry, ShownRank(entry))) end
        end
        ClassSpells.Load(spellIDs, function()
            if self:IsVisible() then self.column:Refresh() end
        end)
    end

    -- Redraws the tab shown for the player as they are now: the heading,
    -- the chips and the rows the picked chip keeps, the opened spells' ranks
    -- under them. A chip that keeps nothing on another tab or class goes
    -- back to All. The scroll stays while the tab and chip do.
    function page:Refresh()
        local classID, tab = self.classID, self.tab
        if not (classID and tab) then return end
        local level = ns.PlayerLevel()
        local entries = Entries(classID, tab, level)
        local totals = IsPlayerClass(classID) and Totals(entries) or nil
        local state = ns.UI.state
        -- Trainable lists only what the Train now chip would keep, so it has no chips.
        local hasChips = totals ~= nil and tab ~= TRAINABLE
        if not hasChips or (state.spellFilter == FILTER_NEXT and not totals.nextLevel) then
            state.spellFilter = FILTER_ALL
        end
        local filter = state.spellFilter or FILTER_ALL
        local shown = Filtered(entries, filter, totals)
        local hasSpells = #shown > 0
        if tab == RACIAL then shown = WithRaceHeadings(shown) end
        self.title:SetText(ClassSpells.TabName(tab))
        self.subtitle:SetText(SubtitleText(GetClassInfo(classID) or "", entries, totals))
        self:UpdateChips(entries, hasChips and totals or nil, filter)
        self.levelLine:SetText(Theme:JoinDots(totals and L["Level %d"]:format(level), ClassSpells.TabName(tab)))
        self.empty:SetShown(not hasSpells)
        local place = ("%d:%s:%s"):format(classID, tab, filter)
        local rows = ClassSpells.WithRankRows(shown, function(entry) return RankRowsOf(entry, self) end)
        self.column:SetData(rows, place == self.place)
        self.place = place
        self:LoadSpells(shown)
    end

    function page:ShowTab(classID, tab)
        self.classID, self.tab = classID, tab
        self:Refresh()
    end
    return page
end
