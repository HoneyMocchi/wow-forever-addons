-- The Classes tab: the nine classes (left), the picked class's sections in
-- the dungeon list's accordion (middle), and the picked page (right, in the
-- content pane MainFrame.lua puts round it). The class and page picked are
-- kept in UI.state (classID, classPage), so a style switch keeps them.
-- Overview, the first row, is the page a class opens on until another is
-- picked (UI/ClassOverview.lua); its boxes open the sections' pages.
-- The Abilities section lists the class's spellbook tabs, each opening the
-- page of its trainer spells (UI/ClassSpells.lua). The Quests section lists
-- the class's quests (Data/ClassQuests.lua) as a dungeon's Quests group
-- does, each opening its quest page (the Dungeons tab's, UI/Overview.lua):
-- one side's, which its header's Alliance / Horde emblem picks for every
-- class, and a group of quests teaching one spell as one row, its page the
-- quest starting nearest the player. A class's questlines picked by hand
-- (the warrior's Defensive Stance, the warlock's Summon Voidwalker) sit
-- under fold rows of their own, shut to start, each opening its questline
-- page (UI/Questlines.lua); following a card or a link there leaves a trail
-- that ‹ › and a right-click go back and forth along.
-- The Talents section lists the class's saved plans under Planner; which
-- one the planner shows is kept by Core/Talents.lua.
-- The Class Sets section lists the class's item sets (UI/TierSets.lua), each
-- opening its set page.
-- The rogue's Poisons section, after them, lists the poison recipes under
-- their chips, its header's Known box listing the poisons known or not
-- (UI/Poisons.lua), each opening its recipe page.
-- The hunter's Pets section, after them, lists Pet trainer and the tameable
-- families (UI/HunterPets.lua, loaded after this file), each opening its page;
-- the warlock's lists Demon trainer and the demons (UI/WarlockPets.lua, also
-- loaded after it).
-- The mage's Comprehension section, in the same place, holds one page: the
-- scrolls only a mage can use (UI/MageScrolls.lua, also loaded after).
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L
local Talents = ns.Talents
local ClassSpells = ns.UI.ClassSpells
local Poisons = ns.UI.Poisons

local CLASS_ROW = 34          -- a class's row
local CLASS_BADGE = 26        -- its ring badge (Theme:ClassBadge)
local CLASS_NAME_GAP = 9      -- between the badge and the name
local LABEL_BADGE = 22        -- the class badge before the sections column's label
local LABEL_BADGE_GAP = 8
local PLAN_MENU_WIDTH = 180   -- a saved plan's right-click menu
local PLAN_MENU_GAP = 2       -- between the plan's row and its menu
local LEVEL_UP_DELAY = 1      -- seconds after a level up before the spells are read again

-- The Talents section's fixed pages: the planner's working plan, and the
-- row that saves what the planner shows as a new plan. The class's saved
-- plans go between them (TalentPages), all three opening the planner.
local PLANNER_PAGE = { key = "PLANNER", name = L["Planner"] }
local NEW_PLAN_PAGE = { key = "PLANNER", name = L["+ New plan"], isAction = true }

-- The sections every class has, in order: each a header in the middle
-- column over its pages. Overview is a page of its own, with none under it
-- (as a dungeon's Overview row); then Talents, Abilities, Quests and Class
-- Sets; the class-only section goes last.
-- Shared by every class, so a section left open stays open across them.
local OVERVIEW_SECTION = { key = "OVERVIEW", name = L["Overview"], overview = true, pages = {} }
local ABILITIES_SECTION = { key = "ABILITIES", name = L["Abilities"], atlas = "Spellbook-up-c60", pages = {} }
local QUESTS_SECTION = { key = "QUESTS", name = L["Quests"], atlas = "Exclamation-up-c60", pages = {} }
local TALENTS_SECTION = { key = "TALENTS", name = L["Talents"], atlas = "Talents-up-c60", pages = { PLANNER_PAGE } }
-- Its icon is the Collections tab's, set once the tab is built (UI.TabIcon).
local CLASS_SETS_SECTION = { key = "TIER_SETS", name = L["Class Sets"], pages = {} }
local SECTIONS = { OVERVIEW_SECTION, TALENTS_SECTION, ABILITIES_SECTION, QUESTS_SECTION, CLASS_SETS_SECTION }
local FIRST_PAGE = OVERVIEW_SECTION.key
-- The rogue's own section, its icon the minimap's poison vendor mark.
local POISONS_SECTION = { key = Poisons.SECTION_KEY, name = L["Poisons"], atlas = "Poisons", pages = {} }
-- The hunter's and the warlock's own section, its icon the minimap's stable
-- master mark; its pages are the class's (PetsOf).
local PETS_SECTION = { key = "PETS", name = L["Pets"], atlas = "StableMaster", pages = {} }
-- The mage's own section, its icon the quest log's lore book.
local COMPREHENSION_SECTION = { key = "COMPREHENSION", name = L["Comprehension"],
    atlas = "Campaign-QuestLog-LoreBook", pages = {} }

-- What fills class `classID`'s Pets section: UI/HunterPets.lua's for the
-- hunter, UI/WarlockPets.lua's for the warlock, else nil. Each has Has,
-- Pages, HeaderFigure and PageFigure.
local function PetsOf(classID)
    if ns.UI.HunterPets.Has(classID) then return ns.UI.HunterPets end
    if ns.UI.WarlockPets.Has(classID) then return ns.UI.WarlockPets end
    return nil
end

-- The class-only sections, each with whether class `classID` has it. A
-- class has at most one; it goes after Class Sets. The modules are read
-- when asked, as UI/HunterPets.lua, UI/WarlockPets.lua and UI/MageScrolls.lua
-- load after this file.
local CLASS_ONLY_SECTIONS = {
    { section = POISONS_SECTION, has = function(classID) return Poisons.Of(classID) ~= nil end },
    { section = PETS_SECTION, has = function(classID) return PetsOf(classID) ~= nil end },
    { section = COMPREHENSION_SECTION, has = function(classID) return ns.UI.MageScrolls.Has(classID) end },
}

-- Each saved plan's and set's page, kept while the plan is, so its row stays
-- the same row as the list redraws.
local savedPlanPages = setmetatable({}, { __mode = "k" })
local setPages = setmetatable({}, { __mode = "k" })
-- Each spellbook tab's page, by its key, kept for the same reason.
local spellTabPages = {}

-- One row per class, in Talents.CLASS_IDS order, named as the game names it.
local function ClassEntries()
    local entries = {}
    for _, classID in ipairs(Talents.CLASS_IDS) do
        local name, token = GetClassInfo(classID)
        table.insert(entries, { classID = classID, name = name or "", token = token })
    end
    return entries
end

-- The class picked: the one chosen on the tab, else the player's own.
local function PickedClass()
    local state = ns.UI.state
    return state.classID or Talents.PlayerClassID() or Talents.CLASS_IDS[1]
end

-- The left column: each class's ring badge and name in its class colour,
-- "You" at the right of the player's own.
local function CreateClassList(tab)
    local list
    local function SetupRow(row, entry)
        if not row.badge then
            row.badge = Theme:ClassBadge(row, CLASS_BADGE)
            row.badge:SetPoint("CENTER", row, "LEFT", Size.pad + CLASS_BADGE / 2, 0)
            row.title:SetPoint("LEFT", Size.pad + CLASS_BADGE + CLASS_NAME_GAP, 0)
        end
        row.badge:SetClass(entry.token)
        row.title:SetText(entry.name)
        row.right:SetText(entry.classID == Talents.PlayerClassID() and L["You"] or "")
        Theme:SetTextColor(row.right, Theme.color.muted)
    end
    list = ns.UI.CreateList(tab, {
        label = L["Classes"],
        rowHeight = CLASS_ROW,
        right = true,
        entryHeight = function() return nil end,
        setupRow = SetupRow,
        afterRow = function(row, entry) ns.UI.SetClassColor(row.title, entry.token) end,
        isSelected = function(entry) return entry.classID == PickedClass() end,
        onClick = function(entry)
            tab:ClearTrail()
            tab:PickClass(entry.classID)
        end,
    })
    list:SetLabelIcon(ns.UI.TabIcon("CLASSES"))
    list:SetData(ClassEntries())
    return list
end

-- Every class's sections, then `ownSection`: one list per class-only
-- section, made once, so a class keeps getting the same list (UpdateSections
-- tells a new list from the one on show by that).
local sectionsWithOwn = {}
local function SectionsWith(ownSection)
    if not sectionsWithOwn[ownSection] then
        local sections = { unpack(SECTIONS) }
        table.insert(sections, ownSection)
        sectionsWithOwn[ownSection] = sections
    end
    return sectionsWithOwn[ownSection]
end

-- The sections class `classID` has: every class's, then its own (the
-- rogue's Poisons, the hunter's and the warlock's Pets, the mage's
-- Comprehension).
local function SectionsOf(classID)
    for _, classOnly in ipairs(CLASS_ONLY_SECTIONS) do
        if classOnly.has(classID) then return SectionsWith(classOnly.section) end
    end
    return SECTIONS
end

-- The class's token ("MAGE"), as UnitClass and the data name it.
local function ClassToken(classID)
    return select(2, GetClassInfo(classID))
end

-- Picks the class with token `classToken` ("ROGUE") on the tab.
local function PickClassOf(classToken)
    for _, classID in ipairs(Talents.CLASS_IDS) do
        if ClassToken(classID) == classToken then ns.UI.state.classID = classID end
    end
end

-- A class quest page's key, for UI.state.classPage: a group's row's
-- (UI/Lists.lua's ClassQuests) for the quest that row shows, else the
-- quest's own.
local function QuestPageKey(quest)
    return quest.groupKey or "QUEST:" .. quest.id
end

-- The Quests header's figure: for the player's own class how many of its
-- quests are done ("4/7", the dungeon list's count); another class's quests
-- can't be done by this character, so just how many there are.
local function QuestCountText(classID)
    local done, total = ns.UI.ClassQuestsDone(ClassToken(classID))
    if classID ~= Talents.PlayerClassID() then return tostring(total) end
    return ("%d/%d"):format(done, total)
end

-- The figure at a section header's right: Abilities counts the class's
-- spells (trained of them, on your own class), Quests the class's quests,
-- Talents shows the points in each tree of the plan on show, Class Sets how
-- many sets the class has, Poisons your Poisons skill (else its recipes), Pets
-- how many families a hunter can tame or demons a warlock summons,
-- Comprehension how many scrolls there are.
local function SectionFigure(section)
    if section == ABILITIES_SECTION then return ClassSpells.CountText(PickedClass()) end
    if section == POISONS_SECTION then return Poisons.HeaderFigure(PickedClass()) end
    if section == PETS_SECTION then return PetsOf(PickedClass()).HeaderFigure() end
    if section == COMPREHENSION_SECTION then return tostring(ns.UI.MageScrolls.Count()) end
    if section == QUESTS_SECTION then return QuestCountText(PickedClass()) end
    if section == CLASS_SETS_SECTION then return tostring(#section.pages) end
    if section ~= TALENTS_SECTION then return nil end
    local classID = PickedClass()
    return Talents:SplitText(classID, Talents:Plan(classID))
end

-- Each kind of page a row opens in the right pane, other than the planner
-- (saved plans) and Overview. `field` is what the row carries, `pane` the
-- tab's pane that shows it. Show(pane, page, classID) shows the row's page
-- there; Refresh(pane), when given, brings a shown pane up to date
-- (tab:RefreshSoon); Figure(page, onLoaded) is the row's figure at its right,
-- with `onLoaded` run as pieces the game hadn't sent arrive. Showing,
-- hiding and refreshing the panes and the rows' figures all go by this list.
local PAGE_KINDS = {
    {   -- a questline: its fold row draws its own figure
        field = "questline", pane = "questlinePage",
        Show = function(pane, page, classID) pane:ShowQuestline(classID, page.questline) end,
        Refresh = function(pane) pane:Refresh() end,
    },
    {   -- a spellbook tab: how many spells it lists
        field = "spellTab", pane = "spellPage",
        Show = function(pane, page, classID) pane:ShowTab(classID, page.spellTab) end,
        Refresh = function(pane) pane:Refresh() end,
        Figure = function(page) return tostring(ClassSpells.TabCount(PickedClass(), page.spellTab)) end,
    },
    {   -- a quest: its level
        field = "quest", pane = "questPage",
        Show = function(pane, page, classID) pane:ShowClassQuest(GetClassInfo(classID) or "", page.quest) end,
        Figure = function(page) return page.quest.level and tostring(page.quest.level) end,
    },
    {   -- a class set: how many of its looks are collected ("3/8")
        field = "set", pane = "setPage",
        Show = function(pane, page) pane:ShowSet(page.set) end,
        Refresh = function(pane) pane:UpdateStrip() end,
        Figure = function(page, onLoaded) return ("%d/%d"):format(ns.UI.TierSets.Collected(page.set, onLoaded)) end,
    },
    {   -- a poison recipe: the skill it needs
        field = "recipe", pane = "poisonPage",
        Show = function(pane, page, classID) pane:ShowRecipe(classID, page.recipe) end,
        Refresh = function(pane) pane:Refresh() end,
        Figure = function(page) return Poisons.PageFigure(page) end,
    },
    {   -- a pet family: how many of its beasts there are to tame
        field = "petPage", pane = "petPage",
        Show = function(pane, page) pane:ShowPage(page) end,
        Refresh = function(pane) pane:Refresh() end,
        Figure = function(page) return ns.UI.HunterPets.PageFigure(page) end,
    },
    {   -- a demon: the level it comes at
        field = "demonPage", pane = "demonPage",
        Show = function(pane, page) pane:ShowPage(page) end,
        Refresh = function(pane) pane:Refresh() end,
        Figure = function(page) return ns.UI.WarlockPets.PageFigure(page) end,
    },
    {   -- the mage's scrolls: no figure
        field = "scrollPage", pane = "scrollPage",
        Show = function(pane) pane:Refresh() end,
        Refresh = function(pane) pane:Refresh() end,
    },
}

-- The kind of page `page`'s row opens (PAGE_KINDS), or nil for the
-- planner's rows, Overview and the poison chips.
local function PageKindOf(page)
    for _, kind in ipairs(PAGE_KINDS) do
        if page[kind.field] ~= nil then return kind end
    end
    return nil
end

-- A row's figure: its kind's, else a saved plan's points per tree.
local function PageFigure(page, onLoaded)
    local kind = PageKindOf(page)
    if kind then return kind.Figure and kind.Figure(page, onLoaded) end
    if not page.savedPlan then return nil end
    return Talents:SplitText(PickedClass(), page.savedPlan)
end

-- Planner, then each of the class's saved plans ("Saved plan" under its
-- name), then + New plan.
local function TalentPages(classID)
    local pages = { PLANNER_PAGE }
    for _, savedPlan in ipairs(Talents:SavedPlans(classID)) do
        local page = savedPlanPages[savedPlan] or { key = "PLANNER", savedPlan = savedPlan, note = L["Saved plan"] }
        savedPlanPages[savedPlan] = page
        page.name = savedPlan.name
        table.insert(pages, page)
    end
    table.insert(pages, NEW_PLAN_PAGE)
    return pages
end

-- The class's sets, a page each: the set's name over its tier and where it
-- comes from ("T1  ·  Molten Core").
local function SetPages(classID)
    local pages = {}
    for _, set in ipairs(ns.UI.TierSets.Of(ClassToken(classID))) do
        local page = setPages[set] or { key = set.key, set = set }
        setPages[set] = page
        page.name = set.encounter.name
        local note = Theme:JoinDots(ns.UI.TierSets.TierOf(set.encounter), ns.UI.TierSets.PlaceText(set))
        page.note = note ~= "" and note or nil
        table.insert(pages, page)
    end
    return pages
end

-- The class's spellbook tabs, a page each.
local function SpellTabPages(classID)
    local pages = {}
    for _, spellTab in ipairs(ClassSpells.Tabs(classID)) do
        local key = "ABILITIES:" .. spellTab
        local page = spellTabPages[key] or { key = key, spellTab = spellTab, name = ClassSpells.TabName(spellTab) }
        spellTabPages[key] = page
        table.insert(pages, page)
    end
    return pages
end

-- The class's quests on the side picked, a page each (UI/Questlines.lua's
-- ClassQuestPages, with their keys and fold rows), each group's showing
-- its quest nearest the player now. `onLoaded`, when given, runs as the
-- names of spells and items a fold names arrive.
local function QuestPages(classID, onLoaded)
    return ns.UI.ClassQuestPages(ClassToken(classID), onLoaded)
end

-- The first of `pages` that isn't a questline's, else the first questline's
-- row (nothing in a fold, which starts shut). Nil when none.
local function FirstPage(pages)
    local firstFold
    for _, page in ipairs(pages) do
        if page.isFold then
            firstFold = firstFold or page
        elseif not page.inFold then
            return page
        end
    end
    return firstFold
end

-- `pageKey` when `pages` holds its page, else the first page's key (nil
-- when there are none).
local function KeptOrFirstKey(pages, pageKey)
    for _, page in ipairs(pages) do
        if page.key == pageKey then return pageKey end
    end
    local first = FirstPage(pages)
    return first and first.key
end

-- The section listing the page `pageKey`, or nil when the class has none.
local function SectionOf(pageKey)
    for _, section in ipairs(SectionsOf(PickedClass())) do
        for _, page in ipairs(section.pages) do
            if page.key == pageKey then return section, page end
        end
    end
end

-- A quest opened from another quest's page (a step of its chain) that the
-- section doesn't list: its page shows while UI.state.classPage is its key.
local function UnlistedQuest()
    local state = ns.UI.state
    local quest = state.classQuest
    if quest and state.classPage == QuestPageKey(quest) and not SectionOf(state.classPage) then return quest end
end

-- The poison recipe whose page `pageKey` is, also while the chip picked
-- leaves its row off the list; nil on another page or class.
local function RecipeOf(pageKey)
    return Poisons.RecipeOf(PickedClass(), pageKey)
end

-- The page picked on the tab, while the class has it; else Overview. A set
-- picked stays picked across classes: every class has its T1 and so on.
local function PickedPageKey()
    local pageKey = ns.UI.state.classPage
    return (SectionOf(pageKey) or UnlistedQuest() or RecipeOf(pageKey)) and pageKey or FIRST_PAGE
end

-- The quest whose page shows, or nil.
local function PickedQuest()
    local _, page = SectionOf(PickedPageKey())
    return page and page.quest or UnlistedQuest()
end

-- The page picked, and its kind (PAGE_KINDS; nil for the planner and
-- Overview). A quest opened from a chain step and a poison recipe whose row
-- the chip leaves off have no row listed, so they get a page made for them.
local function PickedPage()
    local pageKey = PickedPageKey()
    local _, page = SectionOf(pageKey)
    if not page then
        local quest, recipe = UnlistedQuest(), RecipeOf(pageKey)
        if quest then
            page = { quest = quest }
        elseif recipe then
            page = { recipe = recipe }
        end
    end
    return page, page and PageKindOf(page)
end

-- A page with a page of its own: one of PAGE_KINDS.
local function HasOwnPage(page)
    return PageKindOf(page) ~= nil
end

-- Whether the quest whose page shows is one of `quests`.
local function IsQuestPicked(quests)
    local picked = PickedQuest()
    if not picked then return false end
    for _, quest in ipairs(quests) do
        if quest.id == picked.id then return true end
    end
    return false
end

-- A row with a page of its own is picked while that page shows, a
-- questline's part while one of its quests' does. Planner is picked while
-- no saved plan is open; a saved plan's row while it is. The poison chips'
-- row never is.
local function IsPagePicked(page)
    if page.isBranch then return IsQuestPicked(page.quests) end
    if page.key ~= PickedPageKey() or page.isAction or page.chips then return false end
    if HasOwnPage(page) then return true end
    return Talents:OpenedPlan(PickedClass()) == page.savedPlan
end

-- A spellbook tab, questline, quest, set, recipe or pet opens its page (the
-- poison chips' row only holds its chips), a questline's part the page of
-- its first quest not done. Planner goes back to the working plan, a saved
-- plan opens in the planner, and + New plan saves what the planner shows
-- and opens that.
local function OpenPage(tab, page)
    local classID = PickedClass()
    if page.chips then return end
    if page.isBranch then
        tab:OpenQuest(ns.UI.Questlines.PartQuest(page))
        return
    end
    if HasOwnPage(page) then
        tab:PickPage(page.key)
        return
    end
    if page.isAction then
        Talents:SaveNew(classID)
    elseif page.savedPlan then
        Talents:OpenSaved(classID, page.savedPlan)
    else
        Talents:CloseSaved(classID)
    end
    tab:PickPage(page.key)
end

-- The section holding the page that shows (Overview while it shows).
local function ActiveSectionKey()
    if UnlistedQuest() then return QUESTS_SECTION.key end
    if RecipeOf(PickedPageKey()) then return POISONS_SECTION.key end
    if PickedPageKey() == OVERVIEW_SECTION.key then return OVERVIEW_SECTION.key end
    local section = SectionOf(PickedPageKey())
    return section and section.key
end

-- The middle column, its label the picked class's badge and name.
local function CreateSectionList(tab)
    CLASS_SETS_SECTION.atlas = ns.UI.TabIcon("COLLECTION")
    local list = ns.UI.CreateSectionList(tab, {
        label = "",
        memoryArea = "classes",
        headerRight = SectionFigure,
        headerSide = function(section) return section == QUESTS_SECTION and ns.UI.ClassQuestSide() or nil end,
        onPickSide = function(side) tab:PickQuestSide(side) end,
        pageRight = function(page) return PageFigure(page, function() tab:RefreshSoon() end) end,
        pageRightColor = function(page)
            if page.recipe then return Poisons.PageFigureColor(page, PickedClass()) end
        end,
        titleIcon = function(page) return page.quest and Poisons.QuestTitleIcon(page.quest) end,
        afterRow = function(row, entry)
            Poisons.ShowChips(row, entry, PickedClass(), function(chipKey) tab:PickPoisonChip(chipKey) end)
            Poisons.ShowKnownBox(row, entry, PickedClass(), function(on) tab:ListKnownPoisons(on) end)
        end,
        isSelected = IsPagePicked,
        -- A pick by hand starts a new trail.
        onSelect = function(page)
            tab:ClearTrail()
            if page == OVERVIEW_SECTION then return tab:PickPage(OVERVIEW_SECTION.key) end
            OpenPage(tab, page)
        end,
        onRightClick = function(page, row)
            if page.savedPlan then tab:OpenPlanMenu(page.savedPlan, row) end
        end,
        activeKey = ActiveSectionKey,
    })
    list.classBadge = Theme:ClassBadge(list, LABEL_BADGE)
    list.classBadge:SetPoint("CENTER", list, "TOPLEFT", Size.pad + LABEL_BADGE / 2, -Size.paneLabel / 2)
    list.label:ClearAllPoints()
    list.label:SetPoint("LEFT", list.classBadge, "RIGHT", LABEL_BADGE_GAP, 0)
    list:SetSections(SectionsOf(PickedClass()))
    return list
end

-- A saved plan's right-click menu: Link in chat, Rename... and Delete plan
-- (which asks once). tab.planMenu.savedPlan is the plan it is for.
local function CreatePlanMenu(tab)
    local menu = Theme:Menu(tab, PLAN_MENU_WIDTH)
    local function Rename()
        local savedPlan = menu.savedPlan
        menu:Hide()
        tab.nameDialog:Ask(L["Rename plan"], L["A new name for %s."]:format(savedPlan.name), savedPlan.name,
            function(text)
                if not Talents.RenameSaved(savedPlan, text) then return L["Type a name."] end
            end)
    end
    local function LinkInChat()
        menu:Hide()
        tab.planner:LinkInChat(PickedClass(), menu.savedPlan)
    end
    function menu:Fill()
        self:Begin()
        self:AddRow(L["Link in chat"], Theme.color.muted, LinkInChat)
        self:AddRow(L["Rename..."], Theme.color.muted, Rename)
        self:AddConfirmRow(L["Delete plan"], L["Click again to delete"], function()
            Talents:DeleteSaved(PickedClass(), menu.savedPlan)
        end)
        self:Finish()
    end
    return menu
end

-- The picked class's quest with ID `questID` (or with it among its other
-- versions' IDs), for a chain step named on a quest page.
local function ClassQuestByID(questID)
    return ns.Data:ClassQuest(ClassToken(PickedClass()), questID)
end

-- The dungeon or raid a class quest's targets stand in, or nil.
local function QuestDungeon(quest)
    return quest.dungeon and ns.Data:Get(quest.dungeon)
end

-- The quest page: the Dungeons tab's (UI/Overview.lua), opening the quests
-- its links name here, and the bosses and maps it links to on their own
-- tab. Its strip shows where it is: "Mage  >  Destroy Morphaz", and ‹ › to
-- step along the tab's trail.
local function CreateQuestPage(tab)
    local page = ns.UI.CreateOverview(tab)
    page.findQuest = ClassQuestByID
    page.openQuest = function(quest)
        tab:PushTrail()
        tab:OpenQuest(quest)
    end
    page.openInDungeon = function(instance, show) ns.UI:ShowInDungeon(instance, show) end
    function page:PlaceStrip(strip) tab:AddTrailStrip(self, strip) end
    function page:ShowClassQuest(className, quest)
        self:ShowQuest(QuestDungeon(quest), quest)
        self.crumbs:SetText(("%s%s|r  %s>|r  %s%s|r"):format(Theme:ColorCode(Theme.color.muted), className,
            Theme:ColorCode(Theme.color.muted), Theme:ColorCode(Theme.color.heading), quest.name))
    end
    page:Hide()
    return page
end

-- What an Overview box or quest row opens (UI/ClassOverview.lua's targets):
-- a spellbook tab on a chip (the class's first tab on All when none is
-- named), a quest's page (the class's first quest when none is named) or
-- the planner, as it was. Nil when the class has no such page.
local function OverviewTargetKey(classID, target)
    if target.section == "ABILITIES" then
        local spellTab = target.spellTab or ClassSpells.Tabs(classID)[1]
        ns.UI.state.spellFilter = target.filter or ClassSpells.FILTER_ALL
        return spellTab and "ABILITIES:" .. spellTab
    end
    if target.section == "QUESTS" then
        local first = FirstPage(QuestPages(classID))
        local quest = target.quest or first and first.quest
        if not quest then return first and first.key end
        -- A group's other quest (a demon page's) shows on its own page.
        ns.UI.state.classQuest = quest
        return QuestPageKey(quest)
    end
    return PLANNER_PAGE.key
end

-- The whole tab, filling `parent` (the window's body). tab.overview,
-- tab.planner, tab.spellPage, tab.setPage, tab.questlinePage, tab.questPage,
-- tab.poisonPage, tab.petPage, tab.demonPage and tab.scrollPage are the
-- right pane's pages; MainFrame.lua hosts them.
function ns.UI.CreateClassesTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints()
    ns.UI.Questlines.AddTrail(tab)
    tab.classes = CreateClassList(tab)
    tab.classes:SetPoint("TOPLEFT", Size.gutter, -Size.gutter)
    tab.classes:SetPoint("BOTTOMLEFT", Size.gutter, Size.gutter)
    -- As wide as the Dungeons and Raids tabs' instance and encounter columns.
    tab.classes:SetWidth(Size.instanceList)
    tab.sections = CreateSectionList(tab)
    tab.sections:SetPoint("TOPLEFT", tab.classes, "TOPRIGHT", Size.gutter, 0)
    tab.sections:SetPoint("BOTTOMLEFT", tab.classes, "BOTTOMRIGHT", Size.gutter, 0)
    tab.sections:SetWidth(Size.questList)
    tab.overview = ns.UI.CreateClassOverview(tab)
    tab.overview.onOpen = function(target) tab:OpenFromOverview(target) end
    tab.planner = ns.UI.CreateTalentPlanner(tab)
    tab.spellPage = ns.UI.CreateClassSpellPage(tab)
    tab.spellPage:Hide()
    tab.setPage = ns.UI.CreateTierSetPage(tab)
    tab.setPage:Hide()
    tab.questPage = CreateQuestPage(tab)
    tab.questlinePage = ns.UI.CreateQuestlinePage(tab)
    tab.poisonPage = ns.UI.CreatePoisonPage(tab)
    tab.petPage = ns.UI.CreateHunterPetPage(tab)
    tab.petPage:Hide()
    tab.demonPage = ns.UI.CreateWarlockPetPage(tab)
    tab.demonPage.onOpen = function(target) tab:OpenFromOverview(target) end
    tab.scrollPage = ns.UI.CreateMageScrollPage(tab)
    tab.scrollPage:Hide()
    tab.planMenu = CreatePlanMenu(tab)
    tab.nameDialog = Theme:NameDialog(tab, Talents.MAX_PLAN_NAME)
    tab:SetScript("OnHide", function()
        tab.planMenu:Hide()
        tab.nameDialog:Close()
    end)

    -- A quest or questline page open stays in Quests: the new class's
    -- first quest. A spellbook tab the new class hasn't got (Frost on a
    -- warrior) opens its first tab.
    function tab:PickClass(classID)
        local state = ns.UI.state
        local onQuest = ActiveSectionKey() == QUESTS_SECTION.key
        local onSpellTab = SectionOf(PickedPageKey()) == ABILITIES_SECTION
        state.classID = classID
        state.classQuest = nil
        if onQuest then
            state.classPage = KeptOrFirstKey(QuestPages(classID), nil)
        elseif onSpellTab then
            state.classPage = KeptOrFirstKey(SpellTabPages(classID), state.classPage)
        end
        self:Update()
    end

    function tab:PickPage(pageKey)
        ns.UI.state.classPage = pageKey
        self:Update()
    end

    -- The Quests header's emblem picks the side whose quests it lists, for
    -- every class (nil: the player's own). A quest or questline page open
    -- stays when the new side lists it, else shows that side's first quest.
    function tab:PickQuestSide(side)
        local state = ns.UI.state
        local onQuest = ActiveSectionKey() == QUESTS_SECTION.key
        state.classQuestSide = side
        state.classQuest = nil
        if onQuest then state.classPage = KeptOrFirstKey(QuestPages(PickedClass()), state.classPage) end
        self:Update()
    end

    -- Shows `classID`'s planner, with the plan open there (a linked plan
    -- just saved, UI/TalentLinks.lua).
    function tab:ShowPlanner(classID)
        ns.UI.state.classID, ns.UI.state.classPage = classID, PLANNER_PAGE.key
        self:Update()
    end

    -- Opens what an Overview box or quest row names, its section sliding
    -- open so its row shows.
    function tab:OpenFromOverview(target)
        local pageKey = OverviewTargetKey(PickedClass(), target)
        if not pageKey then return end
        self:PickPage(pageKey)
        self.sections:OpenGroup(ActiveSectionKey())
        self:OpenFoldOf(PickedQuest())
    end

    -- A questline's quest (Defensive Stance's) opened from elsewhere: its
    -- fold slides open so the row of its part shows.
    function tab:OpenFoldOf(quest)
        local fold = quest and ns.Data:ClassQuestFold(ClassToken(PickedClass()), quest.id)
        if fold then self.sections:OpenGroup(ns.UI.Questlines.FoldKey(fold)) end
    end

    -- A poison chip narrows the Poisons section's recipes.
    function tab:PickPoisonChip(chipKey)
        Poisons.PickChip(Poisons.Of(PickedClass()), chipKey)
        self:UpdateSections()
    end

    -- The Known box lists the poisons the character knows, or leaves them out.
    function tab:ListKnownPoisons(on)
        Poisons.SetListsKnown(on)
        self:UpdateSections()
    end

    -- Opens a class's recipe page from elsewhere (a Shopping List row): its
    -- class, the recipe's row shown in its open section.
    function tab:ShowClassRecipe(instance, encounter)
        PickClassOf(instance.classToken)
        Poisons.Reveal(instance, encounter)
        self:PickPage(Poisons.PageKey(encounter))
        self.sections:OpenGroup(POISONS_SECTION.key)
    end

    -- A quest a quest page links to (a step of its chain): its row when the
    -- class lists it, else its page alone.
    function tab:OpenQuest(quest)
        ns.UI.state.classQuest = quest
        self:PickPage(QuestPageKey(quest))
        self:OpenFoldOf(quest)
    end

    -- Opens a class quest from elsewhere (a poison's "Quest:" line): its
    -- class, the quest's page.
    function tab:ShowClassQuest(classToken, quest)
        PickClassOf(classToken)
        self:OpenQuest(quest)
    end

    -- Opens `savedPlan`'s menu under its row in the sections column.
    function tab:OpenPlanMenu(savedPlan, row)
        local menu = self.planMenu
        menu:Hide()
        menu.savedPlan, menu.anchor = savedPlan, row
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", row, "BOTTOMLEFT", Size.pad, -PLAN_MENU_GAP)
        menu:Show()
    end

    -- The sections column with the class's sections, and its quests, saved
    -- plans, sets, recipes, pets and the scrolls page as they are now.
    local shownSections
    function tab:UpdateSections()
        local classID = PickedClass()
        ABILITIES_SECTION.pages = SpellTabPages(classID)
        QUESTS_SECTION.pages = QuestPages(classID, function() self:RefreshSoon() end)
        TALENTS_SECTION.pages = TalentPages(classID)
        CLASS_SETS_SECTION.pages = SetPages(classID)
        POISONS_SECTION.pages = Poisons.Pages(classID, function() self:RefreshSoon() end)
        local pets = PetsOf(classID)
        PETS_SECTION.pages = pets and pets.Pages(classID) or {}
        COMPREHENSION_SECTION.pages = ns.UI.MageScrolls.Pages(classID)
        local sections = SectionsOf(classID)
        if sections == shownSections then
            self.sections:Rebuild()
            return
        end
        shownSections = sections
        self.sections:ChangeSections(sections)
    end

    -- The figures, the quests' statuses and the set page's count again,
    -- once for a burst of pieces arriving, looks collected or quest log
    -- changes.
    local isRefreshPending = false
    function tab:RefreshSoon()
        if isRefreshPending then return end
        isRefreshPending = true
        C_Timer.After(0, function()
            isRefreshPending = false
            if not self:IsVisible() then return end
            self:UpdateSections()
            if self.overview:IsShown() then self.overview:Refresh() end
            for _, kind in ipairs(PAGE_KINDS) do
                local pane = self[kind.pane]
                if kind.Refresh and pane:IsShown() then kind.Refresh(pane) end
            end
        end)
    end

    -- Redraws all three columns for the class and page picked: the right
    -- pane shows Overview, the picked row's page (PAGE_KINDS), else the planner.
    function tab:Update()
        local classID = PickedClass()
        local name, token = GetClassInfo(classID)
        self.classes:Refresh()
        self.sections.label:SetText(Theme:Label(name or ""))
        self.sections.classBadge:SetClass(token)
        self:UpdateSections()
        local isOverview = PickedPageKey() == OVERVIEW_SECTION.key
        local page, pageKind = PickedPage()
        if isOverview then pageKind = nil end
        self.overview:SetShown(isOverview)
        self.planner:SetShown(not isOverview and pageKind == nil)
        for _, kind in ipairs(PAGE_KINDS) do self[kind.pane]:SetShown(kind == pageKind) end
        if isOverview then
            self.overview:ShowClass(classID)
        elseif pageKind then
            pageKind.Show(self[pageKind.pane], page, classID)
        else
            self.planner:ShowClass(classID)
        end
    end

    -- A planned point changes the figures and Overview's Talents box;
    -- saving, renaming or deleting a plan changes the rows.
    Talents:OnChange(function()
        if not tab:IsVisible() then return end
        tab:UpdateSections()
        if tab.overview:IsShown() then tab.overview:Refresh() end
    end)
    -- A look collected or lost changes the sets' counts (Core/Items.lua
    -- forgets what it knew first), the quest log the quests' statuses and
    -- count (UI/Overview.lua forgets the statuses it kept first), and a
    -- spell learned the spells' ranks and figures, a skill-up the poisons'
    -- colours and Poisons figure.
    for _, event in ipairs({ "TRANSMOG_COLLECTION_UPDATED", "TRANSMOG_COLLECTION_SOURCE_ADDED",
        "TRANSMOG_COLLECTION_SOURCE_REMOVED", "QUEST_LOG_UPDATE", "SPELLS_CHANGED", "SKILL_LINES_CHANGED" }) do
        ns:On(event, function() tab:RefreshSoon() end)
    end
    -- A new level brings ranks to train. UnitLevel can still give the old
    -- level as the event fires, so this waits a moment (as UI/Lists.lua does).
    ns:On("PLAYER_LEVEL_UP", function()
        C_Timer.After(LEVEL_UP_DELAY, function() tab:RefreshSoon() end)
    end)
    return tab
end
