-- The Classes tab's Tier Sets: each class's item sets from the set lists the
-- Collections tab shows (Data/Collections, the sets marked with a class),
-- and the right pane's page for one set. The page is the loot grid of
-- Collections showing the set's pieces, each with the boss or quest it comes
-- from as a link, the tick of a collected look and the wishlist star; under
-- them the set bonuses, read from the game's own item tooltip so no bonus
-- text ships with NeedRoll. The strip wishlists the whole set and opens the
-- place it comes from.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L
local WL = ns.Wishlist

local TierSets = {}
ns.UI.TierSets = TierSets

local STRIP_INSET = Size.pad - 4  -- the strip's pills and count, from its ends (as Back's)
local STRIP_BUTTON_GAP = 6        -- between Wishlist the set and Open
local BONUS_LEFT = Size.pad + 4   -- the set bonuses, in from the pane's left (level with the set's name)
local BONUS_GAP = 14              -- between the pieces and the set bonuses
local BONUS_BOTTOM = Size.pad     -- the least room under the set bonuses
local BONUS_HEADING_GAP = 8       -- between "Set bonuses" and the first bonus
local BONUS_ROW_GAP = 4           -- between two bonuses
local BONUS_COUNT_WIDTH = 28      -- the pieces a bonus needs, in a column of its own

-- The set lists, in the order a class's sets are listed: dungeon sets, Zul'Gurub,
-- Ahn'Qiraj, then the raid tiers. Ahn'Qiraj 40's sets are Tier Sets' T2.5
-- too; a set two lists hold is listed once, at its later place.
local SET_LISTS = { "DUNGEON_SETS", "ZG_SETS", "AQ_SETS", "TIER_SETS" }

-- Set bonus lines as the game's tooltip writes them, "(3) Set: ..." for one
-- not reached yet and "Set: ..." for one that is, turned into patterns that
-- capture the count and the bonus.
local BONUS_TO_REACH = ns.GameTextPatterns(ITEM_SET_BONUS_GRAY)
local BONUS_REACHED = ns.GameTextPatterns(ITEM_SET_BONUS)

-- What the first of `patterns` that `text` matches captures.
local function MatchFirst(text, patterns)
    for _, pattern in ipairs(patterns) do
        local first, second = text:match(pattern)
        if first then return first, second end
    end
end

-- Sets ------------------------------------------------------------------------

-- The class's sets as { key, instance, encounter, itemIDs }, in SET_LISTS
-- order. A set's key is its list and its place among the class's sets there
-- ("TIER_SETS:1" is every class's T1), so switching class keeps the same tier
-- open. The lists never change, so each class's is made once.
local setsByClass = {}

local function FindSets(token)
    local found, lastPlace = {}, {}
    for _, listID in ipairs(SET_LISTS) do
        local instance = ns.Data:Get(listID)
        local countHere = 0
        for _, encounter in ipairs(instance and instance.encounters or {}) do
            if Theme:ClassToken(encounter.classes) == token and encounter.loot[1] then
                countHere = countHere + 1
                table.insert(found, { key = ("%s:%d"):format(listID, countHere), instance = instance,
                    encounter = encounter })
                lastPlace[encounter.loot[1].itemID] = #found
            end
        end
    end
    local sets = {}
    for i, set in ipairs(found) do
        if lastPlace[set.encounter.loot[1].itemID] == i then
            set.itemIDs = {}
            for _, piece in ipairs(set.encounter.loot) do table.insert(set.itemIDs, piece.itemID) end
            table.insert(sets, set)
        end
    end
    return sets
end

function TierSets.Of(token)
    setsByClass[token] = setsByClass[token] or FindSets(token)
    return setsByClass[token]
end

-- Where a piece comes from (one of ns.Wishlist:Sources): the boss likeliest
-- to drop it, else a quest or anything else NeedRoll lists it under, but not
-- the set list itself. Nil when NeedRoll knows of none.
local function PieceSource(itemID)
    local best = WL:BestSource(itemID)
    if best and best.kind ~= "Collection" then return best end
    for _, source in ipairs(WL:Sources(itemID)) do
        if source.kind ~= "Collection" then return source end
    end
end

-- The places the set's pieces come from, each once, worked out on first ask.
local function Places(set)
    if set.places then return set.places end
    local places, seen = {}, {}
    for _, itemID in ipairs(set.itemIDs) do
        local source = PieceSource(itemID)
        if source and not seen[source.inst] then
            seen[source.inst] = true
            table.insert(places, source.inst)
        end
    end
    set.places = places
    return places
end

-- The one dungeon or raid every piece comes from, or nil.
function TierSets.Home(set)
    local places = Places(set)
    return #places == 1 and places[1] or nil
end

-- Where the set comes from, in a word: its dungeon or raid, "Dungeons" for
-- pieces from several dungeons, else nil.
function TierSets.PlaceText(set)
    local places = Places(set)
    if #places == 1 then return ns.Data:PlaceName(places[1]) end
    if #places == 0 then return nil end
    for _, instance in ipairs(places) do
        if instance.category ~= "DUNGEON" then return nil end
    end
    return L["Dungeons"]
end

-- A set's tier from its note ("T1" of "T1 · Mage"), the class's name left
-- out; nil when the note only names the class (Zul'Gurub's sets).
-- Core/Names.lua puts the note's class name in the player's language soon
-- after login, so until then the data's own name for it is left out too.
function TierSets.TierOf(encounter)
    local className = ns.UI.ClassName(Theme:ClassToken(encounter.classes))
    local parts = {}
    for _, part in ipairs(ns.Names.SplitParts(encounter.note or "")) do
        if part ~= "" and part ~= className and part ~= encounter.classes then table.insert(parts, part) end
    end
    return #parts > 0 and ns.Names.JoinParts(parts) or nil
end

-- Collections' set lists, by class ------------------------------------------------

-- A set list on the Collections tab whose sets carry a class (Tier Sets,
-- Dungeon Sets, Zul'Gurub's, Ahn'Qiraj's) lists them folded under a row per
-- class, which UI/Lists.lua draws and opens. A fold row is { classFold =
-- true, key = "CLASS:" .. the class token, token, name (the class's name in
-- the player's language), members (its sets, in the list's order) }.
local function FoldKey(token)
    return "CLASS:" .. token
end
-- The loot pane's PvP class folds are keyed the same way (ns.UI.ClassFolds).
TierSets.ClassFoldKey = FoldKey

-- The list's rows: a fold row for each class with sets there, in the game's
-- class order (Talents.CLASS_IDS), then the sets with no class (Zul'Gurub's
-- Misc ones) as plain rows. False for a list with no class sets.
local function BuildClassFolds(instance)
    local foldOf, folds = {}, {}
    for _, classID in ipairs(ns.Talents.CLASS_IDS) do
        local _, token = GetClassInfo(classID)
        if token then
            foldOf[token] = { classFold = true, key = FoldKey(token), token = token, name = ns.UI.ClassName(token),
                members = {} }
            table.insert(folds, foldOf[token])
        end
    end
    local rows, classless = {}, {}
    for _, encounter in ipairs(instance.encounters) do
        local fold = foldOf[Theme:ClassToken(encounter.classes)]
        table.insert(fold and fold.members or classless, encounter)
    end
    for _, fold in ipairs(folds) do
        if #fold.members > 0 then table.insert(rows, fold) end
    end
    if #rows == 0 then return false end
    for _, encounter in ipairs(classless) do table.insert(rows, encounter) end
    return rows
end

-- The data never changes, so each list's rows are made once.
local classFoldsOf = setmetatable({}, { __mode = "k" })

-- The rows of a Collections list whose sets carry a class (BuildClassFolds),
-- or nil for any other list.
function TierSets.ClassFolds(instance)
    if not (instance and instance.category == "COLLECTION") then return nil end
    if classFoldsOf[instance] == nil then classFoldsOf[instance] = BuildClassFolds(instance) end
    return classFoldsOf[instance] or nil
end

-- The key of the player's own class's fold; nil while the game keeps the
-- class secret.
function TierSets.PlayerFoldKey()
    local classID = ns.Talents.PlayerClassID()
    local token = classID and select(2, GetClassInfo(classID))
    return token and FoldKey(token) or nil
end

-- What a class fold holds, in the line under its name: its sets' tiers
-- ("T1  ·  T2  ·  T2.5  ·  T3"), or how many sets it has when they have no
-- tier (Zul'Gurub's).
function TierSets.FoldNote(fold)
    local tiers = {}
    for _, encounter in ipairs(fold.members) do
        local tier = TierSets.TierOf(encounter)
        if tier and not tContains(tiers, tier) then table.insert(tiers, tier) end
    end
    if #tiers == 0 then return Theme:Plural(#fold.members, L["%d set"], L["%d sets"]) end
    return Theme:JoinDots(unpack(tiers))
end

-- The class fold of `rows` (TierSets.ClassFolds) holding set `encounter`, or nil.
function TierSets.FoldHolding(rows, encounter)
    for _, row in ipairs(rows) do
        if row.classFold and tContains(row.members, encounter) then return row end
    end
end

-- The set a list folded by class opens on, `isOpen` being the list's fold
-- key -> whether it is open: the first of the player's class while its fold
-- is open (as it starts), else the first set on show, else the first of the
-- player's class (or of the first class), whose fold then opens to show it.
function TierSets.StartingSet(rows, isOpen)
    local playerKey, playerFold = TierSets.PlayerFoldKey(), nil
    for _, row in ipairs(rows) do
        if row.classFold and row.key == playerKey then playerFold = row end
    end
    if playerFold and isOpen[playerFold.key] then return playerFold.members[1] end
    for _, row in ipairs(rows) do
        if not row.classFold then return row end
        if isOpen[row.key] then return row.members[1] end
    end
    return (playerFold or rows[1]).members[1]
end

-- How many of the set's pieces have their look collected (the loot grid's
-- tick), and how many pieces it has. A piece the game hasn't sent yet counts
-- as not collected; it is asked for once, and `onLoaded` runs when it comes.
local requested = {}
function TierSets.Collected(set, onLoaded)
    local collected = 0
    for _, itemID in ipairs(set.itemIDs) do
        if C_Item.IsItemDataCachedByID(itemID) then
            if ns.Items:Collected(itemID) then collected = collected + 1 end
        elseif not requested[itemID] then
            requested[itemID] = true
            ns.Items:Load(itemID, onLoaded)
        end
    end
    return collected, #set.itemIDs
end

-- The set bonuses its first piece's tooltip lists, { count, text, color }
-- each (count, as text, nil on a bonus already reached, which the game
-- writes without one); nil while the piece isn't cached.
local function SetBonuses(set)
    local lines = ns.Items.TooltipLines(set.itemIDs[1])
    if not lines then return nil end
    local bonuses = {}
    for _, line in ipairs(lines) do
        local text = ns.Plain(line.leftText)
        local count, bonus = MatchFirst(text or "", BONUS_TO_REACH)
        if not count then bonus = MatchFirst(text or "", BONUS_REACHED) end
        if bonus then table.insert(bonuses, { count = count, text = bonus, color = line.leftColor }) end
    end
    return bonuses
end

-- The page ----------------------------------------------------------------------

-- The set bonuses under the pieces: "Set bonuses", then each bonus with the
-- pieces it needs in a column at its left, in the colour the game's tooltip
-- gives it (green once reached, grey until then).
local function CreateBonusBlock(page)
    local block = CreateFrame("Frame", nil, page)
    block.heading = Theme:Text(block, Theme.font.section)
    block.heading:SetPoint("TOPLEFT")
    block.heading:SetText(L["Set bonuses"])
    block.rows = {}

    local function Row(i)
        local row = block.rows[i]
        if row then return row end
        row = { count = Theme:Text(block, Theme.font.body), text = Theme:Text(block, Theme.font.body) }
        row.count:SetWidth(BONUS_COUNT_WIDTH)
        row.count:SetJustifyH("LEFT")
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(true)
        block.rows[i] = row
        return row
    end

    function block:Fill(bonuses)
        for i, bonus in ipairs(bonuses) do
            local row = Row(i)
            row.count:SetText(bonus.count or "")
            row.text:SetText(bonus.text)
            local color = bonus.color
            if color then
                row.text:SetTextColor(color.r, color.g, color.b)
            else
                Theme:SetTextColor(row.text, Theme.color.text)
            end
            Theme:SetTextColor(row.count, Theme.color.heading)
            row.count:Show()
            row.text:Show()
        end
        for i = #bonuses + 1, #self.rows do
            self.rows[i].count:Hide()
            self.rows[i].text:Hide()
        end
        self.shownRows = #bonuses
    end

    -- Lays the bonuses out `width` wide (at least a sliver past the count
    -- column, before the pane has a size), wrapping each; sets the block's height.
    function block:Lay(width)
        width = math.max(BONUS_COUNT_WIDTH + 1, width)
        self:SetWidth(width)
        local y = self.heading:GetStringHeight() + BONUS_HEADING_GAP
        for i = 1, self.shownRows or 0 do
            local row = self.rows[i]
            row.count:ClearAllPoints()
            row.count:SetPoint("TOPLEFT", 0, -y)
            row.text:ClearAllPoints()
            row.text:SetPoint("TOPLEFT", BONUS_COUNT_WIDTH, -y)
            row.text:SetWidth(width - BONUS_COUNT_WIDTH)
            y = y + math.ceil(row.text:GetStringHeight()) + BONUS_ROW_GAP
        end
        self:SetHeight(math.max(1, y - BONUS_ROW_GAP))
    end
    block:Hide()
    return block
end

-- Wishlist the set (or Remove from wishlist once every piece is on it), and
-- Open with the place the set comes from, at the strip's left; how many
-- looks are collected at its right.
local function CreateStripButtons(page)
    page.wishSet = Theme:Pill(page)
    page.wishSet:SetScript("OnClick", function()
        WL:ToggleAll(page.set.itemIDs)
    end)
    page.openHome = Theme:Pill(page)
    page.openHome:SetScript("OnClick", function()
        local home = TierSets.Home(page.set)
        if home then ns.UI:GoToSource(home) end
    end)
    page.collected = Theme:Text(page, Theme.font.body)
    Theme:SetTextColor(page.collected, Theme.color.muted)
end

-- Whether every one of `itemIDs` is on the current wishlist.
local function IsAllWished(itemIDs)
    for _, itemID in ipairs(itemIDs) do
        if not WL:Has(itemID) then return false end
    end
    return true
end

-- The pieces as loot grid entries, made once per set so a redraw keeps the
-- grid's scroll and measurements.
local function Entries(set)
    if set.entries then return set.entries end
    set.entries = {}
    for _, itemID in ipairs(set.itemIDs) do
        table.insert(set.entries, { itemID = itemID, from = PieceSource(itemID) })
    end
    return set.entries
end

-- The set page. `parent` is the Classes tab (its RefreshSoon redraws the
-- counts as pieces arrive); MainFrame.lua hosts the page in the tab's
-- content pane, with its strip.
function ns.UI.CreateTierSetPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.grid = ns.UI.CreateLootGrid(page)
    Theme:Unframe(page.grid)
    page.grid:SetPoint("TOPLEFT")
    page.grid:SetPoint("BOTTOMRIGHT")
    page.bonuses = CreateBonusBlock(page)
    CreateStripButtons(page)

    -- Moves the pills and the count onto the content pane's strip.
    function page:PlaceStrip(strip)
        for _, widget in ipairs({ self.wishSet, self.openHome, self.collected }) do widget:SetParent(strip) end
        self.wishSet:SetPoint("LEFT", STRIP_INSET, 0)
        self.openHome:SetPoint("LEFT", self.wishSet, "RIGHT", STRIP_BUTTON_GAP, 0)
        self.collected:SetPoint("RIGHT", -STRIP_INSET, 0)
    end

    -- The set bonuses right under the pieces when they fit there, else at
    -- the pane's foot with the pieces scrolling above them. Run after each
    -- redraw of the grid, as items loading can lay its pieces out anew.
    function page:PlaceBonuses()
        local bonuses = self.bonuses
        local gridBottom = 0
        if bonuses:IsShown() then
            bonuses:Lay(self:GetWidth() - BONUS_LEFT - Size.pad)
            local below = self.grid:ContentHeight() + BONUS_GAP
            local room = self:GetHeight() - bonuses:GetHeight() - BONUS_BOTTOM
            local top = math.min(below, room)
            if below > room then gridBottom = bonuses:GetHeight() + BONUS_BOTTOM + BONUS_GAP end
            bonuses:SetPoint("TOPLEFT", BONUS_LEFT, -top)
        end
        if gridBottom ~= self.gridBottom then
            self.gridBottom = gridBottom
            self.grid:SetPoint("BOTTOMRIGHT", 0, gridBottom)
        end
    end
    -- The grid redraws as pieces arrive and looks are collected, so the
    -- count follows its ticks from here (a scroll changes neither).
    hooksecurefunc(page.grid, "Refresh", function(_, scrolling)
        if page.set and not scrolling then page:UpdateStrip() end
        page:PlaceBonuses()
    end)

    -- The bonuses from the first piece's tooltip, once the game has it. The
    -- game can send the piece before its set, its tooltip then listing no
    -- bonuses until a TOOLTIP_DATA_UPDATE, so until some show they are
    -- read again on each one.
    function page:ShowBonuses()
        local set = self.set
        local bonuses = SetBonuses(set)
        if not bonuses and self.bonusesAwaited ~= set then
            self.bonusesAwaited = set
            ns.Items:Load(set.itemIDs[1], function()
                if self.set == set then self:ShowBonuses() end
            end)
        end
        self.isMissingBonuses = not (bonuses and #bonuses > 0)
        self.bonuses:SetShown(not self.isMissingBonuses)
        if bonuses then self.bonuses:Fill(bonuses) end
        self:PlaceBonuses()
    end
    ns:On("TOOLTIP_DATA_UPDATE", function()
        if page.isMissingBonuses and page:IsVisible() then page:ShowBonuses() end
    end)

    -- The strip for the set as it is now: the wishlist pill's label (none
    -- while the Wishlist is off), Open while the set comes from one place
    -- on a tab that is on, and the collected count.
    function page:UpdateStrip()
        local set = self.set
        self.wishSet:SetShown(ns.Modules:IsOn("WISHLIST"))
        self.wishSet:SetLabel(IsAllWished(set.itemIDs) and L["Remove from wishlist"] or L["Wishlist the set"])
        local home = TierSets.Home(set)
        self.openHome:SetShown(home ~= nil and ns.Modules:IsOn(home.category))
        if home then self.openHome:SetLabel(L["Open %s"]:format(ns.Data:PlaceName(home))) end
        local collected, total = TierSets.Collected(set, function() parent:RefreshSoon() end)
        self.collected:SetText(L["%d of %d appearances collected"]:format(collected, total))
    end

    -- Shows `set`: its full name (the game's, once Core/Names.lua has it),
    -- tier, class and place under it, its pieces and bonuses, and (with the
    -- grid's redraw) its strip.
    function page:ShowSet(set)
        local isSameSet = set == self.set
        self.set = set
        local encounter = set.encounter
        local className = ns.UI.ClassName(Theme:ClassToken(encounter.classes))
        local subtitle = Theme:JoinDots(TierSets.TierOf(encounter), className, TierSets.PlaceText(set))
        self.grid:ShowItems(encounter.name, subtitle, Entries(set), nil, nil, isSameSet)
        self:ShowBonuses()
    end

    -- A star or Wishlist the set changed the list: the stars and the pill follow.
    WL:OnChange(function()
        if not (page.set and page:IsVisible()) then return end
        page.grid:UpdateStars()
        page:UpdateStrip()
    end)
    return page
end
