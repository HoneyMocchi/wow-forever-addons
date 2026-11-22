-- The Classes tab's Pets section on a warlock: Demon trainer, then each
-- demon in the order a warlock gets it (Data/WarlockPets.lua: the
-- grimoires and demon trainers Mike saved from WoW: Forever, what each
-- grimoire teaches, the summons' quests and who sells what from Classic-DB,
-- the trainers' map spots from QuestieDB), and the right pane's page for
-- one of them. The pages are built from the hunter's pet pages' parts
-- (ns.UI.PetPageKit, UI/HunterPets.lua).
-- A demon's page says how to get it (the summon with its spell's icon, then
-- under "Quest" the class quests that teach it, each opening its quest
-- page), then each ability with its ranks:
-- rank 1 of some comes with the demon, the rest from a grimoire used with
-- the demon out. A click on an ability opens a row per rank under it
-- (ClassSpells' rank rows, as the hunter's pet abilities): the grimoire as an
-- item link, its level, cost and where it stands. Last come your
-- side's demon trainers selling its grimoires, nearest first, each pinned
-- on the map like the class trainers on the Overview.
-- With that demon out, an ability's line says the rank it knows and the
-- grimoire to buy next (ClassSpells.Progress on the pet's spellbook).
-- Only IDs, levels, costs and NPC names ship: the game names each demon
-- (a creature family), grimoire and spell.
local _, ns = ...
local Theme = ns.Theme
local L = ns.L
local Talents = ns.Talents
local ClassSpells = ns.UI.ClassSpells
local PetPageKit = ns.UI.PetPageKit

local WarlockPets = {}
ns.UI.WarlockPets = WarlockPets

local WARLOCK = "WARLOCK"
local PAGE_KEY_PREFIX = "DEMONS:"
local TRAINER_PAGE_KEY = PAGE_KEY_PREFIX .. "TRAINER"
local LINE_ROW = PetPageKit.LINE_ROW

local STRIP_INSET = Theme.size.pad - 4  -- the level line, from the strip's right end (as the hunter's)
local ROW_LEFT = 16                     -- the rows' text, in from the left (as PetPageKit's rows)
local SUMMON_ROW = 36                   -- the summon's row, taller than a line for its spell's icon
local SUMMON_ICON = 28                  -- that icon, at the row's left in the rows' text's place
local SUMMON_ICON_GAP = 10              -- between the icon and the summon's name (as the Abilities pages')

-- Ranks: { the pet's spellID, level, copper, grimoire itemID }
-- (Data/WarlockPets.lua); the first three as ClassSpells reads them. A rank
-- with no grimoire comes with the demon, for nothing.
local RANK_SPELL, RANK_LEVEL, RANK_COST, RANK_ITEM = 1, 2, 3, 4

-- The list's rows, by `kind`; RANK is one rank of an opened ability.
local HEADING, SUMMON, QUEST, ABILITY, RANK, TRAINER, NOTE =
    "HEADING", "SUMMON", "QUEST", "ABILITY", "RANK", "TRAINER", "NOTE"

-- The data --------------------------------------------------------------------------

local function Data()
    return ns.Data.warlockPets
end

local function IsPlayerWarlock()
    local classID = Talents.PlayerClassID()
    return classID ~= nil and select(2, GetClassInfo(classID)) == WARLOCK
end

-- Whether class `classID` has the warlock's Pets section: the warlock,
-- while the data loaded.
function WarlockPets.Has(classID)
    return select(2, GetClassInfo(classID)) == WARLOCK and Data() ~= nil
end

-- The section header's figure: how many demons a warlock summons.
function WarlockPets.HeaderFigure()
    return tostring(#(Data() and Data().demons or {}))
end

-- How many grimoires teach `demon`'s ranks; every demon's with none given.
local function GrimoireCount(demon)
    local count = 0
    for _, shown in ipairs(demon and { demon } or Data().demons) do
        for _, ability in ipairs(shown.abilities) do
            for _, rank in ipairs(ability.ranks) do
                if rank[RANK_ITEM] then count = count + 1 end
            end
        end
    end
    return count
end

-- Each page's entry in the sections column, by its key, kept so its row
-- stays the same row as the list redraws.
local pagesByKey = {}

local function PageFor(key, fields)
    local page = pagesByKey[key] or { key = key, demonPage = true }
    for field, value in pairs(fields) do page[field] = value end
    pagesByKey[key] = page
    return page
end

-- Demon trainer, then the demons in the order a warlock gets them; none
-- for a class but the warlock.
function WarlockPets.Pages(classID)
    if not WarlockPets.Has(classID) then return {} end
    local pages = { PageFor(TRAINER_PAGE_KEY, { name = L["Demon trainer"] }) }
    for _, demon in ipairs(Data().demons) do
        local name, icon = PetPageKit.FamilyInfo(demon.family)
        table.insert(pages, PageFor(PAGE_KEY_PREFIX .. demon.key, { demon = demon, name = name, icon = icon }))
    end
    return pages
end

-- A demon's row shows the level it comes at.
function WarlockPets.PageFigure(page)
    return page.demon and tostring(page.demon.level) or nil
end

-- The demon your warlock has out, or nil: the one whose abilities the pet's
-- spellbook knows (each knows at least one from its first summon). Read
-- this way since the game has no call naming a pet's creature family by ID.
local function SummonedDemon()
    if not (IsPlayerWarlock() and UnitExists("pet")) then return nil end
    for _, demon in ipairs(Data().demons) do
        for _, ability in ipairs(demon.abilities) do
            if ClassSpells.Progress(ability, 0, Enum.SpellBookSpellBank.Pet).known > 0 then return demon end
        end
    end
    return nil
end

-- The ability lines ------------------------------------------------------------------

-- "Levels 8 to 58", or "Level 26" for an ability with one rank.
local function LevelsText(ability)
    local first, last = ability.ranks[1][RANK_LEVEL], ability.ranks[#ability.ranks][RANK_LEVEL]
    if first == last then return L["Level %d"]:format(first) end
    return L["Levels %d to %d"]:format(first, last)
end

-- An ability's line at the right, and its color: with its demon out, the
-- rank it knows and the grimoire to use now or next; else its ranks, the levels
-- they come at and what all their grimoires cost.
local function AbilityStatus(entry)
    local ability, ranks = entry.ability, entry.ability.ranks
    if not entry.isOut then
        return Theme:JoinDots(Theme:Plural(#ranks, L["%d rank"], L["%d ranks"]), LevelsText(ability),
            PetPageKit.RanksCostText(ability, 1, #ranks)), Theme.color.muted
    end
    local progress = ClassSpells.Progress(ability, entry.level, Enum.SpellBookSpellBank.Pet)
    local knownText = progress.known == 0 and L["Not learned"] or L["Rank %d of %d"]:format(progress.known, #ranks)
    if progress.trainFirst then
        local which = progress.trainFirst == progress.trainLast and L["Train now: rank %d"]:format(progress.trainLast)
            or L["Train now: ranks %d to %d"]:format(progress.trainFirst, progress.trainLast)
        return Theme:JoinDots(knownText, which, PetPageKit.RanksCostText(ability, progress.trainFirst,
            progress.trainLast)), Theme.color.complete
    end
    if progress.nextRank then
        return Theme:JoinDots(knownText, L["Rank %d at level %d"]:format(progress.nextRank,
            ranks[progress.nextRank][RANK_LEVEL])), Theme.color.muted
    end
    return L["All ranks learned"], Theme.color.muted
end

-- A grimoire as a rank row's item link: its icon and name in its quality's
-- colour; nil while the game hasn't sent its name (then `onLoaded` runs).
local function GrimoireText(itemID, onLoaded)
    local name = C_Item.GetItemNameByID(itemID)
    if not name then
        ns.Items:Load(itemID, onLoaded)
        return nil
    end
    local r, g, b = Theme:QualityColor(ns.Items:Quality(itemID))
    return ("|T%d:0|t %s%s|r"):format(C_Item.GetItemIconByID(itemID) or 0, Theme:ColorCode({ r, g, b }), name)
end

-- Ability `entry`'s rank rows while they show on `page`: each rank's level,
-- its grimoire and cost (or that it comes with the demon) and, with its
-- demon out, where it stands; nil for another row or a shut ability.
-- `onLoaded` redraws once a grimoire's name arrives.
local function RankRowsOf(entry, page, onLoaded)
    if entry.kind ~= ABILITY or not ClassSpells.AreRanksOpen(page, entry.ability) then return nil end
    entry.isOpen = true
    local ability, rows = entry.ability, {}
    local progress = entry.isOut and ClassSpells.Progress(ability, entry.level, Enum.SpellBookSpellBank.Pet)
    for index, rank in ipairs(ability.ranks) do
        local itemID = rank[RANK_ITEM]
        local costText = L["comes with the demon"]
        if itemID then
            costText = Theme:JoinDots(GrimoireText(itemID, onLoaded) or L["Loading..."], ns.Money(rank[RANK_COST]))
        end
        local rankEntry = ClassSpells.RankEntry(ability, index, progress or nil,
            L["Level %d"]:format(rank[RANK_LEVEL]), costText)
        rankEntry.kind, rankEntry.itemID = RANK, itemID
        table.insert(rows, rankEntry)
    end
    return rows
end

-- The rows ---------------------------------------------------------------------------

-- The class quests teaching `demon`'s summon that the Quests section lists
-- (the side its emblem picks), each once: every quest of a group, though
-- the section shows one of them (the Bindings, one per city).
local function SummonQuests(demon)
    local wanted, quests = {}, {}
    for _, questID in ipairs(demon.quests) do wanted[questID] = true end
    for _, listed in ipairs(ns.UI.ClassQuests(WARLOCK)) do
        for _, quest in ipairs(listed.variants or { listed.quest }) do
            if wanted[quest.id] then
                wanted[quest.id] = nil
                table.insert(quests, quest)
            end
        end
    end
    return quests
end

-- "Summon", then the summon's row.
local function AddSummonRows(rows, demon)
    PetPageKit.AddHeading(rows, L["Summon"])
    table.insert(rows, { kind = SUMMON, height = SUMMON_ROW, demon = demon })
end

-- "Quest" ("Quests" for more than one), then a row per class quest teaching
-- the summon; nothing for a demon without one.
local function AddQuestRows(rows, demon)
    local quests = SummonQuests(demon)
    if #quests == 0 then return end
    PetPageKit.AddHeading(rows, #quests == 1 and L["Quest"] or L["Quests"])
    for _, quest in ipairs(quests) do
        table.insert(rows, { kind = QUEST, height = LINE_ROW, quest = quest })
    end
end

-- "Abilities", then each ability's row (its ranks open under it, RankRowsOf).
local function AddAbilityRows(rows, demon)
    local isOut = SummonedDemon() == demon
    local level = ns.PlayerLevel()
    PetPageKit.AddHeading(rows, L["Abilities"], L["use a grimoire with the demon out to teach it a rank"])
    for _, ability in ipairs(demon.abilities) do
        table.insert(rows, { kind = ABILITY, height = LINE_ROW, ability = ability, isOut = isOut, level = level })
    end
end

-- How many of `demon`'s grimoires `trainer` sells.
local function SoldCount(trainer, demon)
    local sells, count = {}, 0
    for _, itemID in ipairs(trainer.grimoires) do sells[itemID] = true end
    for _, ability in ipairs(demon.abilities) do
        for _, rank in ipairs(ability.ranks) do
            if sells[rank[RANK_ITEM]] then count = count + 1 end
        end
    end
    return count
end

-- What a trainer's row says after their name: on a demon's page, "9 of 10
-- grimoires" when they don't sell all of them; on Demon trainer, the demons
-- whose grimoires they sell.
local function TrainerTag(trainer, demon)
    if demon then
        local sold, total = SoldCount(trainer, demon), GrimoireCount(demon)
        return sold < total and L["%d of %d grimoires"]:format(sold, total) or nil
    end
    local names = {}
    for _, shown in ipairs(Data().demons) do
        if SoldCount(trainer, shown) > 0 then table.insert(names, (PetPageKit.FamilyInfo(shown.family))) end
    end
    return table.concat(names, ", ")
end

-- "Your demon trainers  Horde", then your side's who sell `demon`'s
-- grimoires (any grimoire, on Demon trainer), nearest first; on a
-- character who isn't a warlock, a line saying why there are none.
local function AddTrainerRows(rows, demon)
    if not IsPlayerWarlock() then
        table.insert(rows, { kind = NOTE, height = LINE_ROW, text = L["Your demon trainers show on a warlock."] })
        return
    end
    local selling = {}
    for _, trainer in ipairs(Data().trainers) do
        if not demon or SoldCount(trainer, demon) > 0 then table.insert(selling, trainer) end
    end
    local trainers = ns.UI.NearestFirst(ns.UI.YourSideTrainers(selling))
    if #trainers == 0 then return end
    PetPageKit.AddHeading(rows, L["Your demon trainers"], ns.SideName(ns.PlayerFaction()))
    for _, trainer in ipairs(trainers) do
        table.insert(rows, { kind = TRAINER, height = LINE_ROW, trainer = trainer, tag = TrainerTag(trainer, demon) })
    end
end

local function DemonRows(demon)
    local rows = {}
    AddSummonRows(rows, demon)
    AddQuestRows(rows, demon)
    AddAbilityRows(rows, demon)
    AddTrainerRows(rows, demon)
    return rows
end

local function TrainerPageRows()
    local rows = {}
    AddTrainerRows(rows, nil)
    return rows
end

-- The spell a row's tooltip and link show: the summon; an ability's next
-- rank to buy with its demon out, else its last; a rank's own.
local function RowSpell(entry)
    if entry.kind == SUMMON then return entry.demon.summon end
    if entry.kind == RANK then return entry.spellID end
    return PetPageKit.ShownRank(entry.ability, entry.isOut and entry.level or nil)
end

local function ShowQuestTooltip(row)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:SetText(row.data.quest.name)
    GameTooltip:AddLine(L["Click to open this quest"], unpack(Theme.tip.text))
    GameTooltip:Show()
end

-- A grimoire's tooltip, or the spell's for the summon, an ability or a rank
-- that comes with the demon.
local function ShowLinkTooltip(row)
    local itemID = row.data.itemID
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    if itemID then
        GameTooltip:SetItemByID(itemID)
    else
        GameTooltip:SetSpellByID(RowSpell(row.data))
    end
    GameTooltip:Show()
end

-- A trainer's row is a link that pins them (UI.HoverMapLink); a quest's
-- opens its page; the others show their grimoire's or spell's tooltip.
local function OnRowEnter(row)
    local entry = row.data
    local kind = entry and entry.kind
    if kind == TRAINER then
        ns.UI.HoverMapLink(row, ns.Data.npcs[entry.trainer.npc])
        ns.UI.ShowTrainerTooltip(row)
    elseif kind == QUEST then
        ShowQuestTooltip(row)
    elseif kind == SUMMON or kind == ABILITY or kind == RANK then
        ShowLinkTooltip(row)
    end
end

local function OnRowLeave(row)
    ns.UI.LeaveMapLink(row)
    GameTooltip:Hide()
end

-- Shift-click on a grimoire or spell links it in chat; a plain click on an
-- ability opens or shuts its ranks.
local function OnLinkClick(entry, page)
    if IsModifiedClick("CHATLINK") then
        if entry.itemID then return ns.Items:HandleModifiedClick(entry.itemID) end
        ClassSpells.LinkInChat(RowSpell(entry))
        return
    end
    if entry.kind ~= ABILITY then return end
    GameTooltip:Hide()
    ClassSpells.ToggleRanks(page, entry.ability)
end

-- A click in combat on a trainer reaches here (out of combat the map pin
-- link's secure button takes it, UI/MainFrame.lua). A quest opens its page;
-- the others go to OnLinkClick.
local function OnRowClick(row, page)
    local entry = row.data
    if entry.kind == TRAINER then
        GameTooltip:Hide()
        ns.UI.ShowOnMap(ns.Data.npcs[entry.trainer.npc], entry.trainer.name)
    elseif entry.kind == QUEST then
        GameTooltip:Hide()
        page.onOpen({ section = "QUESTS", quest = entry.quest })
    else
        OnLinkClick(entry, page)
    end
end

-- A row of the list (PetPageKit.CreateListRow's), its tooltip and clicks,
-- and the summon spell's icon in the Abilities pages' bordered style
-- (Theme:QualityIcon), shown on the summon's row alone.
local function CreateRow(column, page)
    local row = PetPageKit.CreateListRow(column)
    Theme:QualityIcon(row)
    row.iconBorder:SetSize(SUMMON_ICON, SUMMON_ICON)
    row.iconBorder:SetPoint("LEFT", ROW_LEFT, 0)
    row:SetBorderColor(unpack(Theme.color.line))
    row:HookScript("OnEnter", OnRowEnter)
    row:HookScript("OnLeave", OnRowLeave)
    row:SetScript("OnClick", function(self) OnRowClick(self, page) end)
    return row
end

-- The summon's row: its spell's icon and name, and at the right "Known" on
-- your warlock who has it, else the level it comes at.
local function SetupSummonRow(row, entry)
    local demon = entry.demon
    local isKnown = IsPlayerWarlock() and C_SpellBook.IsSpellKnown(demon.summon)
    row.icon:SetTexture(C_Spell.GetSpellTexture(demon.summon))
    PetPageKit.PlaceRowText(row, Theme.font.body, Theme.color.text, row.right)
    row.text:SetPoint("LEFT", row.iconBorder, "RIGHT", SUMMON_ICON_GAP, 0)
    row.text:SetText(C_Spell.GetSpellName(demon.summon) or "")
    row.right:SetText(isKnown and L["Known"] or L["Level %d"]:format(demon.level))
    Theme:SetTextColor(row.right, isKnown and Theme.color.complete or Theme.color.muted)
end

-- A quest's row: its name, and at the right its level and, on your own
-- warlock, how far you are with it (else "Class quest").
local function SetupQuestRow(row, entry)
    local quest = entry.quest
    local status, color = L["Class quest"], Theme.color.muted
    if IsPlayerWarlock() then
        local questStatus
        questStatus, color = ns.UI.QuestStatus(quest)
        status = ns.UI.QuestStatusText[questStatus]
    end
    local level = quest.level or quest.minLevel
    row.right:SetText(Theme:JoinDots(level and L["Level %d"]:format(level), status))
    Theme:SetTextColor(row.right, color)
    PetPageKit.PlaceRowText(row, Theme.font.body, Theme.color.quest, row.right)
    row.text:SetText(quest.name)
end

local function SetupRow(row, entry)
    local kind = entry.kind
    row.note:SetText(kind == HEADING and entry.note or "")
    row.divider:SetShown(entry.hasDivider == true)
    row.right:SetFontObject(Theme.font.small)
    row.right:SetText("")
    row:EnableMouse(kind ~= HEADING and kind ~= NOTE)
    row.iconBorder:SetShown(kind == SUMMON)
    row.icon:SetShown(kind == SUMMON)
    ClassSpells.ShowRankParts(row, kind == RANK and entry or nil)
    ClassSpells.PlaceOpenArrow(row, row.text, nil)
    if kind == HEADING then
        PetPageKit.PlaceRowText(row, Theme.font.section, Theme.color.heading)
        row.text:SetText(entry.text)
    elseif kind == SUMMON then
        SetupSummonRow(row, entry)
    elseif kind == QUEST then
        SetupQuestRow(row, entry)
    elseif kind == ABILITY then
        local status, color = AbilityStatus(entry)
        row.right:SetText(status)
        Theme:SetTextColor(row.right, color)
        PetPageKit.PlaceRowText(row, Theme.font.body, Theme.color.text, row.right)
        row.text:SetText(C_Spell.GetSpellName(entry.ability.ranks[1][RANK_SPELL]) or "")
        ClassSpells.PlaceOpenArrow(row, row.text, entry.isOpen == true)
    elseif kind == RANK then
        PetPageKit.PlaceRowText(row, Theme.font.small, Theme.color.text, row.right)
        row.text:SetText("")
    elseif kind == TRAINER then
        row.right:SetText(ns.UI.SourceZone(entry.trainer) or "")
        Theme:SetTextColor(row.right, Theme.color.muted)
        PetPageKit.PlaceRowText(row, Theme.font.body, Theme.color.text, row.right)
        row.text:SetText(ns.UI.TrainerText(entry.trainer, row.text, entry.tag))
    else
        PetPageKit.PlaceRowText(row, Theme.font.small, Theme.color.muted, row.right)
        row.text:SetText(entry.text)
    end
    if GameTooltip:IsOwned(row) then OnRowEnter(row) end
end

-- The page ---------------------------------------------------------------------------

-- A demon's line under the heading: "Summon Voidwalker at level 10  ·
-- 4 abilities  ·  21 grimoires". The summon's name reads "" until the game
-- has sent it (ClassSpells.Load).
local function DemonSubtitle(demon)
    local summonName = C_Spell.GetSpellName(demon.summon) or ""
    return Theme:JoinDots(L["%s at level %d"]:format(summonName, demon.level),
        Theme:Plural(#demon.abilities, L["%d ability"], L["%d abilities"]),
        Theme:Plural(GrimoireCount(demon), L["%d grimoire"], L["%d grimoires"]))
end

local function TrainerSubtitle()
    return Theme:JoinDots(Theme:Plural(GrimoireCount(nil), L["%d grimoire"], L["%d grimoires"]),
        L["sold by the demon trainers"])
end

-- The Demon trainer page's icon: a grimoire's (a book).
local function GrimoireIcon()
    local firstRanks = Data().demons[1].abilities[1].ranks
    return C_Item.GetItemIconByID(firstRanks[#firstRanks][RANK_ITEM])
end

-- The demon page. `parent` is the Classes tab; MainFrame.lua hosts the page
-- in the tab's content pane, with its strip. page.onOpen(target) opens a
-- quest's page (the Classes tab's OpenFromOverview).
function ns.UI.CreateWarlockPetPage(parent)
    local page = PetPageKit.CreatePage(parent, CreateRow, SetupRow)
    ClassSpells.KeepOpenRanks(page, "warlockPets")
    -- A grimoire's name arriving redraws the tab once for the lot of them.
    local function RefreshTab() parent:RefreshSoon() end
    page.levelLine = Theme:Text(page, Theme.font.body)
    Theme:SetTextColor(page.levelLine, Theme.color.muted)

    function page:PlaceStrip(strip)
        self.levelLine:SetParent(strip)
        self.levelLine:SetPoint("RIGHT", -STRIP_INSET, 0)
    end

    function page:ShowTitle(demonPage)
        local demon = demonPage.demon
        if demon then
            self:SetHeading(demonPage.name, DemonSubtitle(demon), demonPage.icon)
        else
            self:SetHeading(demonPage.name, TrainerSubtitle(), GrimoireIcon())
        end
    end

    -- The spells the page names whose names the game hasn't sent yet,
    -- redrawn once they arrive.
    function page:LoadNames(demon)
        if not demon then return end
        local spellIDs = { demon.summon }
        for _, ability in ipairs(demon.abilities) do table.insert(spellIDs, ability.ranks[1][RANK_SPELL]) end
        ClassSpells.Load(spellIDs, function()
            if self:IsVisible() then self:Refresh() end
        end)
    end

    -- Redraws the page shown for the player as they are now: the heading,
    -- the level line ("Level 38  ·  Voidwalker summoned") and the rows, the
    -- opened abilities' ranks under them, keeping the scroll while the page
    -- stays.
    function page:Refresh()
        local demonPage = self.demonPage
        if not demonPage then return end
        local demon = demonPage.demon
        local summoned = SummonedDemon()
        self:ShowTitle(demonPage)
        self.levelLine:SetText(Theme:JoinDots(L["Level %d"]:format(ns.PlayerLevel()),
            summoned and L["%s summoned"]:format((PetPageKit.FamilyInfo(summoned.family)))))
        local rows = ClassSpells.WithRankRows(demon and DemonRows(demon) or TrainerPageRows(),
            function(entry) return RankRowsOf(entry, self, RefreshTab) end)
        self.column:SetData(rows, demonPage.key == self.place)
        self.place = demonPage.key
        self:LoadNames(demon)
    end

    function page:ShowPage(demonPage)
        self.demonPage = demonPage
        self:Refresh()
    end

    -- A demon summoned, dismissed or reading a grimoire changes the lines.
    for _, event in ipairs({ "UNIT_PET", "PET_BAR_UPDATE" }) do
        ns:On(event, function()
            if page:IsVisible() then page:Refresh() end
        end)
    end
    page:Hide()
    return page
end
