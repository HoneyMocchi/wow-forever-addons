-- The Classes tab's Poisons section, the rogue's own recipe list: its rows
-- in the sections column and the right pane's page for one recipe. The
-- recipes (Data/Poisons.lua, read from Classic-DB's rogue trainers) are a
-- profession-shaped list (ns.Data:ClassRecipes), so the Professions tab's
-- pieces serve them as they are: the skill colours and the Skill-ups /
-- Learnable narrowing (UI/RecipeBand.lua), the product icons (UI/Lists.lua), the
-- recipe page's boxes and trainer lines (UI/LootGrid.lua) and Add to
-- shopping list (Core/Shopping.lua). Only IDs and numbers ship: the poisons'
-- and reagents' names, icons and tooltips come from the game by item ID.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L

local Poisons = {}
ns.UI.Poisons = Poisons

Poisons.SECTION_KEY = "POISONS"
local CHIPS_PAGE_KEY = "POISONS:CHIPS"
local RECIPE_PAGE_PREFIX = "POISON:"
local STRIP_INSET = Size.pad - 4  -- the strip's pill and skill line, from its ends (as Back's)
local CHIPS_LEFT = 8              -- the chips, in from the row's text (level with the recipes' icons)
local KNOWN_BOX_GAP = 8           -- the header's Known box, left of its figure

-- The chips over the recipes, one at a time: every recipe, those that still
-- give skill-ups, and those not known yet that the skill allows learning.
-- They set the recipe list's own toggles: RecipeBand's SKILLUP, and
-- LEARNABLE at its second step.
local CHIPS = { { key = "ALL", label = L["All"] }, { key = "SKILLUP", label = L["Skill-ups"] },
    { key = "LEARNABLE", label = L["Learnable now"] } }

-- Recipes ----------------------------------------------------------------------

local function ClassToken(classID)
    return select(2, GetClassInfo(classID))
end

-- Class `classID`'s own recipe list (an instance), or nil: only the rogue has one.
function Poisons.Of(classID)
    return ns.Data:ClassRecipes(ClassToken(classID))
end

local function ProductID(encounter)
    return encounter.loot[1].itemID
end

-- The name the game gives what the recipe makes (the recipe spell's while
-- the item isn't loaded), kept on the recipe as encounter.name for the page
-- title and the Shopping List. The item is asked for once; `onLoaded` runs
-- when it arrives.
local requestedItems = {}
local function FillName(encounter, onLoaded)
    local itemID = ProductID(encounter)
    local name = C_Item.GetItemNameByID(itemID)
    if not name and not requestedItems[itemID] then
        requestedItems[itemID] = true
        ns.Items:Load(itemID, onLoaded)
    end
    encounter.name = name or C_Spell.GetSpellName(encounter.spellID) or ""
end

-- The character's Poisons skill, or nil without it (another class, a rogue
-- before the poison quest, or a client with no such skill line).
local function Rank(instance)
    return ns.RecipeBand:Rank(instance)
end

-- The chip picked, by the recipe list's toggles for the list.
local function PickedChip(instance)
    return next(ns.RecipeBand:State(instance).toggles) or "ALL"
end

function Poisons.PickChip(instance, key)
    local toggles = ns.RecipeBand:State(instance).toggles
    wipe(toggles)
    if key == "LEARNABLE" then
        toggles[key] = ns.RecipeBand.LEARNABLE_NOW
    elseif key ~= "ALL" then
        toggles[key] = true
    end
end

-- The Known box on the section's header: ticked (the default, as the
-- Professions tab lists every recipe), the poisons the character already
-- knows are listed too; unticked, they are left out. Unticked is saved per
-- character in NeedRollDB.hideKnownPoisons.
local function ListsKnown()
    local hidden = ns.db and ns.db.hideKnownPoisons
    return not (hidden and hidden[ns.CharacterKey()])
end

function Poisons.SetListsKnown(on)
    if not ns.db then return end
    ns.db.hideKnownPoisons = ns.db.hideKnownPoisons or {}
    ns.db.hideKnownPoisons[ns.CharacterKey()] = not on or nil
end

-- The recipes the section lists: those the chip keeps, less the ones the
-- character knows while the Known box is unticked. The box shows only with
-- the skill, so without it nothing is left out for being known.
local function ListedRecipes(instance)
    local kept = ns.RecipeBand:Narrow(instance.encounters, instance)
    if ListsKnown() or not Rank(instance) then return kept end
    local listed = {}
    for _, encounter in ipairs(kept) do
        if not ns.RecipeBand:IsKnown(encounter.spellID) then table.insert(listed, encounter) end
    end
    return listed
end

-- A recipe's row in the sections column, kept per recipe so its row stays
-- the same row as the list redraws.
local recipePages = setmetatable({}, { __mode = "k" })
local CHIPS_PAGE = { key = CHIPS_PAGE_KEY, name = "", chips = true }

function Poisons.PageKey(encounter)
    return RECIPE_PAGE_PREFIX .. encounter.spellID
end

-- The Poisons section's rows: the chips (while the character has the skill:
-- they narrow by it), then each recipe listed (the picked chip keeps it, and
-- the Known box when the character knows it), lowest skill first. `onLoaded` runs as names the game hadn't sent arrive.
function Poisons.Pages(classID, onLoaded)
    local instance = Poisons.Of(classID)
    if not instance then return {} end
    local pages = {}
    if Rank(instance) then table.insert(pages, CHIPS_PAGE) end
    for _, encounter in ipairs(ListedRecipes(instance)) do
        FillName(encounter, onLoaded)
        local page = recipePages[encounter] or { key = Poisons.PageKey(encounter), recipe = encounter }
        recipePages[encounter] = page
        page.name = encounter.name
        table.insert(pages, page)
    end
    return pages
end

-- The recipe whose page key is `pageKey`, in class `classID`'s list (listed
-- or not under the chip picked), or nil.
function Poisons.RecipeOf(classID, pageKey)
    local instance = Poisons.Of(classID)
    if not (instance and type(pageKey) == "string") then return nil end
    for _, encounter in ipairs(instance.encounters) do
        if Poisons.PageKey(encounter) == pageKey then return encounter end
    end
end

-- Back to All with the Known box ticked when the chip or the box leaves
-- `encounter` off the list, so a recipe opened from elsewhere (the Shopping
-- List) shows its row.
function Poisons.Reveal(instance, encounter)
    for _, listed in ipairs(ListedRecipes(instance)) do
        if listed == encounter then return end
    end
    Poisons.PickChip(instance, "ALL")
    Poisons.SetListsKnown(true)
end

-- The section header's figure: the character's Poisons skill, else how many
-- recipes there are.
function Poisons.HeaderFigure(classID)
    local instance = Poisons.Of(classID)
    if not instance then return nil end
    local rank = Rank(instance)
    return tostring(rank or #instance.encounters)
end

-- A recipe row's figure, the skill it is learned at, and its colour for the
-- character's skill (nil: muted, without the skill).
function Poisons.PageFigure(page)
    return tostring(page.recipe.skill[1])
end

function Poisons.PageFigureColor(page, classID)
    return ns.RecipeBand:SkillColor(page.recipe, Poisons.Of(classID))
end

-- The poison quest ------------------------------------------------------------------

-- Each side's poison quest, the last step of its level 20 chain about
-- Zanzil's mixture: Alliance "The Touch of Zanzil", Horde "Hinott's
-- Assistance" (Data/ClassQuests.lua). Its row in the Quests section shows
-- the poison mark after its name.
local POISON_QUEST_IDS = { [2609] = true, [2480] = true }
local POISON_QUEST_ATLAS = "icons_64x64_poison"

-- The atlas a class quest's row shows after its name: the poison mark on
-- the poison quests, else nil (also while the client lacks that atlas).
function Poisons.QuestTitleIcon(quest)
    if not POISON_QUEST_IDS[quest.id] then return nil end
    if not C_Texture.GetAtlasInfo(POISON_QUEST_ATLAS) then return nil end
    Theme:KeepLoaded(POISON_QUEST_ATLAS)
    return POISON_QUEST_ATLAS
end

-- The chips row --------------------------------------------------------------------

-- The chips on the chips row, text tab chips (UI/RecipeBand.lua)
-- left to right, the picked one gold and underlined; hidden on every other
-- row (rows are reused). `onPick(key)` runs on a click.
function Poisons.ShowChips(row, page, classID, onPick)
    local chips = row.poisonChips
    if not page.chips then
        for _, chip in ipairs(chips or {}) do chip:Hide() end
        return
    end
    if not chips then
        chips = {}
        for i, chipInfo in ipairs(CHIPS) do
            local chip = ns.RecipeBand.Chip(row)
            chip.key = chipInfo.key
            chip:SetLabel(chipInfo.label)
            chip:SetScript("OnClick", function(self) row.onPickChip(self.key) end)
            chips[i] = chip
        end
        row.poisonChips = chips
    end
    row.onPickChip = onPick
    local picked = PickedChip(Poisons.Of(classID))
    for i, chip in ipairs(chips) do
        chip.first = i == 1
        chip:ClearAllPoints()
        if i == 1 then
            chip:SetPoint("LEFT", row, "LEFT", Size.pad + CHIPS_LEFT - row.inset, 0)
        else
            chip:SetPoint("LEFT", chips[i - 1], "RIGHT", 0, 0)
        end
        chip:Paint(chip.key == picked)
        chip:Show()
    end
end

-- The Known box --------------------------------------------------------------------

-- The Known box on the Poisons header, "Known" at its left, just left of the
-- header's figure, while the character has the skill; hidden on every other
-- row (rows are reused). A click on it doesn't open or shut the section: the
-- box is a button of its own over the row. `onToggle(on)` runs on a click.
function Poisons.ShowKnownBox(row, entry, classID, onToggle)
    local isPoisonsHeader = entry.key == Poisons.SECTION_KEY and entry.pages ~= nil
    local instance = isPoisonsHeader and Poisons.Of(classID)
    local box = row.knownPoisonsBox
    if not (instance and Rank(instance)) then
        if box then box:Hide() end
        return
    end
    if not box then
        box = Theme:CheckBox(row, L["Known"], function(on) row.onToggleKnown(on) end, "LEFT")
        box:SetPoint("RIGHT", row.right, "LEFT", -KNOWN_BOX_GAP, 0)
        row.knownPoisonsBox = box
    end
    row.onToggleKnown = onToggle
    box:Set(ListsKnown())
    box:Show()
end

-- The recipe page --------------------------------------------------------------------

-- The page's boxes, as a profession recipe's: what it makes beside who
-- teaches it (the trainers of the player's side, nearest first; for the
-- first Instant Poison the quest that brings it and who gives it), then
-- the materials, each with the nearest vendor selling it. Built once per
-- recipe, so a redraw keeps the scroll.
local function PageEntries(encounter)
    if encounter.poisonPage then return encounter.poisonPage end
    local entries = {
        { header = L["Creates"], header2 = L["Learned from"], box = true },
        { itemID = ProductID(encounter) },
        { taughtBy = encounter.spellID, quests = encounter.quests },
        { header = L["Materials"], box = true },
    }
    for _, reagent in ipairs(encounter.reagents) do
        table.insert(entries, { itemID = reagent.itemID, count = reagent.count, soldBy = true })
    end
    encounter.poisonPage = entries
    return entries
end

-- The line under the title: "Poisons  ·  Skill 210 225 240 255  ·  Rogue
-- level 46  ·  Costs 3g 10s" (the quest's recipe has no cost).
local function Subtitle(classID, instance, encounter)
    local className = GetClassInfo(classID) or ""
    return Theme:JoinDots(instance.name, L["Skill  %s"]:format(ns.UI.SkillText(encounter.skill)),
        L["%s level %d"]:format(className, encounter.level),
        encounter.cost and L["Costs %s"]:format(ns.Money(encounter.cost)) or nil)
end

-- "Poisons  220 / 300" at the strip's right while the character has the skill.
local function SkillLineText(instance)
    local skillLine = C_SkillInfo.GetSkillLineInfoByID(instance.skillLine)
    if not (skillLine and skillLine.rank > 0) then return "" end
    return L["Poisons  %d / %d"]:format(skillLine.rank, skillLine.maxRank)
end

-- A recipe's page. `parent` is the Classes tab; MainFrame.lua hosts the page
-- in the tab's content pane, with its strip.
function ns.UI.CreatePoisonPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.grid = ns.UI.CreateLootGrid(page)
    Theme:Unframe(page.grid)
    page.grid:SetPoint("TOPLEFT")
    page.grid:SetPoint("BOTTOMRIGHT")
    page.skillLine = Theme:Text(page, Theme.font.body)
    Theme:SetTextColor(page.skillLine, Theme.color.muted)

    -- Add to shopping list at the strip's left, the skill at its right.
    function page:PlaceStrip(strip)
        self.addButton = ns.UI.CreateAddButton(strip, function() return self.instance, self.encounter end)
        self.addButton:SetPoint("LEFT", STRIP_INSET, 0)
        self.skillLine:SetParent(strip)
        self.skillLine:SetPoint("RIGHT", -STRIP_INSET, 0)
    end

    function page:UpdateStrip()
        local canAdd = ns.Modules:IsOn("SHOPPING") and ns.Shopping:CanAdd(self.encounter)
        self.addButton:SetShown(canAdd)
        if canAdd then self.addButton:UpdateLabel() end
        self.skillLine:SetText(SkillLineText(self.instance))
    end

    function page:Refresh()
        local encounter = self.encounter
        if not encounter then return end
        FillName(encounter, function() parent:RefreshSoon() end)
        local entries = PageEntries(encounter)
        self.grid:ShowItems(encounter.name, Subtitle(self.classID, self.instance, encounter), entries, nil, nil,
            self.grid.entries == entries)
        self:UpdateStrip()
    end

    function page:ShowRecipe(classID, encounter)
        self.classID, self.instance, self.encounter = classID, Poisons.Of(classID), encounter
        self:Refresh()
    end

    -- An add or a change on the Shopping List changes the pill's count.
    ns.Shopping:OnChange(function()
        if page.encounter and page:IsVisible() then page:UpdateStrip() end
    end)
    page:Hide()
    return page
end
