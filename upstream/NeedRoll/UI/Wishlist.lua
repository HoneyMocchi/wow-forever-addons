-- Wishlist tab: the current wishlist (Core/Wishlist.lua) in one pane across
-- the body, with two pages. Overview: four stat boxes, the list's dungeon
-- and raid drops grouped into runs (best odds first) and everything else
-- by where it comes from. Details: the whole list as a table whose column
-- headers sort it, with chips that filter it by source. Items this
-- character owns are greyed out on both pages; Overview leaves them out of
-- its facts and runs and lists them last, under Owned. Every item row has
-- a star: clicked off, the item leaves the list but keeps its row, greyed
-- out, until the player leaves the page, so a slip is one click to undo.
-- The header holds the list menu (switch, rename, delete lists); the strip
-- above holds Save preset, Import, Export and Clear list. Both work as on
-- the Shopping List (UI/SavedLists.lua).
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local WL = ns.Wishlist
local ListUI = ns.UI.SavedLists
local L = ns.L

local HEADER_HEIGHT = 64
local LABEL_HEIGHT = 26   -- column label above each Overview column
local FACT_HEIGHT = 52
local FACT_GAP = 10
local CHIP_HEIGHT = 30    -- the source filter chips on Details
local HEAD_HEIGHT = 24    -- Details' column headers
local ICON = 20
local ITEM_INDENT = ICON + 8 -- an item's name starts past its icon
local STAR = 14           -- the star at the left of every item row, on both pages
local STAR_COLUMN = 28    -- room for it: an item row's icon starts this far in
local RUN_ROW = 30        -- a run's header on Overview
local ITEM_ROW = 36       -- an item on Overview (name, then slot and source)
local GROUP_ROW = 28      -- an "Everything else" group label
local TABLE_ROW = 30      -- a row of the Details table
local SPACER = 8
local WIDE_DIALOG = 520   -- Import and Export

-- Sources in the order Details sorts and filters them by.
local KINDS = { "Drop", "Crafted", "PvP", "Faction", "Quest", "Collection", "Unknown" }
local KIND_ORDER = {}
for order, kind in ipairs(KINDS) do KIND_ORDER[kind] = order end
local KIND_LABELS = { Drop = L["Drop"], Crafted = L["Crafted"], PvP = L["PvP"], Faction = L["Faction"],
                      Quest = L["Quest"], Collection = L["Collection"], Unknown = L["Unknown"] }
-- "Everything else" groups on Overview, in this order.
local GROUPS = {
    { "Quest", L["Quest rewards"] }, { "Collection", L["Collections"] }, { "Crafted", L["Crafted"] },
    { "PvP", L["PvP vendors"] }, { "Faction", L["Faction vendors"] }, { "Unknown", L["Not in NeedRoll yet"] },
}

-- Looked up on each call: Theme.color changes with the window style picked in Settings.
local function KindColor(kind)
    local colors = Theme.color
    return ({ Drop = colors.complete, Crafted = colors.accepted, PvP = colors.incomplete, Faction = colors.link,
              Quest = colors.quest, Collection = colors.text })[kind] or colors.faint
end

local function ChanceText(chance)
    if not chance then return "" end
    if chance >= 0.995 then return "100%" end
    if chance < 0.01 then return "<1%" end
    return ("%.0f%%"):format(chance * 100)
end

local function ItemCountText(count)
    return Theme:Plural(count, L["%d item"], L["%d items"])
end

local function CountDrops(entries)
    local drops = 0
    for _, entry in ipairs(entries) do
        if WL:Kind(entry.itemID) == "Drop" then drops = drops + 1 end
    end
    return drops
end

-- "3 owned", or nil when nothing is (Theme:JoinDots then leaves it out).
local function OwnedText(ownedCount)
    return ownedCount > 0 and L["%d owned"]:format(ownedCount) or nil
end

-- Unstarring ---------------------------------------------------------------

-- What the page lists while the player is on it: the list's items in order, plus the ones
-- unstarred since they came, each still in its place. { list, view, items, unstarred = { [itemID]
-- = true } }. Nil until the page draws; the pane's OnHide clears it.
local visit

-- Whether `items` is the visit's items less the unstarred ones: nothing but this page's stars
-- has changed the list since.
local function IsStillVisit(items)
    local index = 0
    for _, entry in ipairs(visit.items) do
        if not visit.unstarred[entry.itemID] then
            index = index + 1
            if items[index] ~= entry then return false end
        end
    end
    return index == #items
end

-- The visit for `list` on `view`. Another list or page, or a change from anywhere else (Clear
-- list, Import), starts a new one: unstarred rows drop off then.
local function CurrentVisit(list, view)
    if visit and visit.list == list and visit.view == view and IsStillVisit(list.items) then return visit end
    visit = { list = list, view = view, items = { unpack(list.items) }, unstarred = {} }
    return visit
end

-- A row's star: takes the item off the list, or puts it back where it was.
local function ToggleStar(entry)
    local itemID = entry.itemID
    if not visit.unstarred[itemID] then
        visit.unstarred[itemID] = true -- first, so the redraw Remove sets off keeps the row
        WL:Remove(itemID)
        return
    end
    -- Its old place: just after the items above it that are still on the list.
    local index = 1
    for _, shown in ipairs(visit.items) do
        if shown == entry then break end
        if not visit.unstarred[shown.itemID] then index = index + 1 end
    end
    visit.unstarred[itemID] = nil
    WL:Restore(entry, index)
end

-- The star at an item row's left, lit while the item is on the list.
local function CreateRowStar(row)
    local star = Theme:Star(row, STAR)
    star:SetPoint("LEFT", 6, 0)
    star:SetScript("OnEnter", function(self)
        self:Paint()
        row.hover:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
        GameTooltip:AddLine(self.on and L["Remove from wishlist"] or L["Add to wishlist"])
        GameTooltip:Show()
    end)
    star:SetScript("OnLeave", function(self)
        self:Paint()
        row.hover:Hide()
        GameTooltip:Hide()
    end)
    star:SetScript("OnClick", function()
        GameTooltip:Hide()
        ToggleStar(row.data.entry)
    end)
    return star
end

-- An owned item, or one unstarred on this visit, stays listed but greys out: icon desaturated,
-- edge in `line`, each of `texts` in `faint`. An unstarred one's star is unlit too. Rows are
-- reused, so all of it is set either way and the caller resets the text colours before this.
local function ShowFaded(row, data, texts)
    local isFaded = data.owned or data.unstarred or false
    row.icon:SetDesaturated(isFaded)
    row.star:SetOn(not data.unstarred)
    if not isFaded then return end
    row:SetBorderColor(unpack(Theme.color.line))
    for _, text in ipairs(texts) do Theme:SetTextColor(text, Theme.color.faint) end
end

-- "Garr, Gehennas, Shazzrah +2" for an item several bosses drop.
local MAX_BOSS_NAMES = 3
local function BossNames(srcs)
    local names, seen = {}, {}
    for _, src in ipairs(srcs) do
        if not seen[src.name] then
            seen[src.name] = true
            names[#names + 1] = src.name
        end
    end
    local line = table.concat({ unpack(names, 1, math.min(MAX_BOSS_NAMES, #names)) }, ", ")
    if #names > MAX_BOSS_NAMES then line = line .. (" +%d"):format(#names - MAX_BOSS_NAMES) end
    return line
end

-- Where a source is, in a few words: "Edwin VanCleef  ·  The Deadmines",
-- "Blacksmithing", "The Missing Diplomat  ·  Stormwind Stockade".
local function WhereText(src)
    if not src then return L["Not in NeedRoll yet"] end
    if src.kind == "Crafted" then return src.inst.name end
    if src.name == src.inst.name then return src.inst.name end
    return Theme:JoinDots(src.name, src.inst.name)
end

-- Opens a source's page (WL:Sources, or a class quest's: src.classToken);
-- Back returns to where the click was (the Wishlist, the Classes tab's tier
-- sets). Not one on a tab turned off in Settings.
function ns.UI.OpenItemSource(src, itemID)
    if not src then return end
    local UI = ns.UI
    if src.classToken then
        GameTooltip:Hide()
        return UI:SelectClassQuest(src.classToken, src.quest)
    end
    if not ns.Modules:IsOn(src.inst.category) then return end
    GameTooltip:Hide()
    if src.kind == "Crafted" then
        UI:ClearHistory()
        UI:SelectRecipe(src.inst, src.enc)
    elseif src.kind == "Quest" then
        UI:GoToSource(src.inst)
        UI:SelectQuest(src.quest)
    else
        UI:GoToSource(src.inst, src.enc, itemID)
    end
end

-- Opens the item's source; Shift- or Ctrl-click links or tries it on, as anywhere in the game.
local function ClickItem(data)
    if IsModifierKeyDown() then
        ns.Items:HandleModifiedClick(data.itemID)
    else
        ns.UI.OpenItemSource(data.src, data.itemID)
    end
end

-- An item's tooltip with every place NeedRoll knows it from, each after the
-- icon for how it is got (Tooltip.SourceIcon: the tab's, a quest's marker).
local MAX_SOURCES = 6
local function ShowItemTooltip(row)
    local itemID = row.data and row.data.itemID
    if not itemID then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:SetItemByID(itemID)
    local srcs = WL:Sources(itemID)
    GameTooltip:AddLine(" ")
    if #srcs == 0 then GameTooltip:AddLine(L["Not in NeedRoll yet"], unpack(Theme.tip.hint)) end
    for i, src in ipairs(srcs) do
        if i > MAX_SOURCES then
            GameTooltip:AddLine(L["+%d more"]:format(#srcs - MAX_SOURCES), unpack(Theme.tip.hint))
            break
        end
        local where = src.kind == "Quest" and Theme:JoinDots(L["Quest: %s"]:format(src.name), src.inst.name)
            or WhereText(src)
        where = ns.Tooltip.SourceIcon(src.kind == "Quest" and "QUEST" or src.inst.category) .. where
        local right = src.rate and ChanceText(src.rate) or KIND_LABELS[src.kind] or src.kind
        local r, g, b = unpack(Theme.tip.info)
        GameTooltip:AddDoubleLine(where, right, r, g, b, unpack(Theme.tip.good))
    end
    if #srcs > 0 then GameTooltip:AddLine(L["Click to open its source"], unpack(Theme.tip.hint)) end
    GameTooltip:Show()
end

-- Import: a sixtyupgrades.com export or share string, previewed, becomes a new list or replaces the current.
local function CreateImportDialog(pane)
    local box = Theme:Dialog(pane, WIDE_DIALOG, 360, L["Import"])
    box:AddHint(L["Paste a sixtyupgrades.com export (Export, then Copy JSON) or a NeedRoll share string."])
    local paste = ListUI.PasteBox(box, WIDE_DIALOG - Size.pad * 2, L["Paste here (Ctrl+V)"])
    paste:SetPoint("TOPLEFT", box.hint, "BOTTOMLEFT", 0, -10)
    local edit = paste.edit
    box.preview = Theme:Text(box, Theme.font.body)
    box.preview:SetPoint("TOPLEFT", paste, "BOTTOMLEFT", 0, -12)
    box.preview:SetWidth(WIDE_DIALOG - Size.pad * 2)
    box.preview:SetJustifyH("LEFT")
    box.detail = Theme:Text(box, Theme.font.small)
    box.detail:SetPoint("TOPLEFT", box.preview, "BOTTOMLEFT", 0, -4)
    box.detail:SetWidth(WIDE_DIALOG - Size.pad * 2)
    box.detail:SetJustifyH("LEFT")
    -- As its own list (named here) or in place of the current list's items.
    ListUI.AddImportTarget(box, box.detail)
    box.cosmetic = Theme:CheckBox(box, L["Leave out shirt and tabard"])
    box.cosmetic:SetPoint("BOTTOMLEFT", Size.pad, Size.pad + 3)

    local parsed
    local function Preview()
        local text = edit:GetText()
        paste.placeholder:SetShown(text == "" and not edit:HasFocus())
        local result, err
        if strtrim(text) ~= "" then result, err = WL:Parse(text) end
        parsed = result
        if not result then
            box.preview:SetText(err or "")
            Theme:SetTextColor(box.preview, err and Theme.color.incomplete or Theme.color.muted)
            box.detail:SetText("")
            ListUI.EnablePill(box.ok, false)
            return
        end
        local known = 0
        for _, entry in ipairs(result.items) do
            if WL:Sources(entry.itemID)[1] then known = known + 1 end
        end
        box.preview:SetText(Theme:JoinDots(result.name, ItemCountText(#result.items)))
        Theme:SetTextColor(box.preview, Theme.color.heading)
        box.detail:SetText(Theme:JoinDots(result.note,
            L["%d found in NeedRoll, %d from dungeons and raids"]:format(known, CountDrops(result.items))))
        Theme:SetTextColor(box.detail, Theme.color.muted)
        box:SuggestName(WL:FreeName(result.name))
        ListUI.EnablePill(box.ok, true)
    end
    edit:SetScript("OnTextChanged", Preview)

    local function Import()
        if not parsed then return end
        local items = {}
        for _, entry in ipairs(parsed.items) do
            if not (box.cosmetic:IsOn() and WL:IsShirtOrTabard(entry)) then table.insert(items, entry) end
        end
        if box:IsReplacing() then
            WL:Replace(items, parsed.note)
        else
            WL:AddList(WL:CleanName(box.name:GetText()) or parsed.name, items, parsed.note)
        end
        ns.UI.status:SetText(L["Imported %s"]:format(ItemCountText(#items)))
        box:Close()
    end
    box:Buttons(L["Import"], Import)
    function box:Present()
        edit:SetText("")
        paste.scroll:SetVerticalScroll(0)
        box:ResetTarget()
        box.cosmetic:Set(true)
        Preview()
        self:Open()
        edit:SetFocus()
    end
    return box
end

-- Export: the current list as a share string to paste in chat, for another player's Import.
local function CreateExportDialog(pane)
    local box = Theme:Dialog(pane, WIDE_DIALOG, 170, L["Export"])
    box:AddHint(L["Press Ctrl+C to copy, then paste it in chat. Other NeedRoll players paste it into Import."])
    ListUI.AddCopyInput(box, WIDE_DIALOG - Size.pad * 2)
    local function Fill()
        box:ShowCopyText(WL:Export(not box.cosmetic:IsOn()))
    end
    box.cosmetic = Theme:CheckBox(box, L["Leave out shirt and tabard"], Fill)
    box.cosmetic:SetPoint("BOTTOMLEFT", Size.pad, Size.pad + 3)
    box:Buttons(nil)
    box.cancel:SetLabel(L["Done"])
    function box:Present()
        self.cosmetic:Set(true)
        self:Open()
        Fill()
    end
    return box
end

-- Overview ----------------------------------------------------------------

local function CreatePage(pane)
    local page = CreateFrame("Frame", nil, pane)
    page:SetPoint("TOPLEFT", Size.pad, -HEADER_HEIGHT)
    page:SetPoint("BOTTOMRIGHT", -Size.pad, Size.pad)
    return page
end

local function CreateFact(parent, label)
    local box = CreateFrame("Frame", nil, parent)
    box:SetHeight(FACT_HEIGHT)
    Theme:StatBackdrop(box)
    box.label = Theme:Text(box, Theme.font.factLabel)
    box.label:SetPoint("TOPLEFT", 10, -8)
    box.label:SetText(label)
    box.value = Theme:Text(box, Theme.font.factValue)
    box.value:SetPoint("TOPLEFT", box.label, "BOTTOMLEFT", 0, -5)
    box.value:SetPoint("RIGHT", -8, 0)
    box.value:SetJustifyH("LEFT")
    return box
end

-- An Overview row is an item (slot and source under its name), a run's header, a group label or a note.
local function SetupOverviewRow(row, data)
    local isItem = data.itemID ~= nil
    row.iconBorder:SetShown(isItem)
    row.icon:SetShown(isItem)
    row.sub:SetShown(isItem)
    row.star:SetShown(isItem)
    row.rule:SetShown(data.run ~= nil)
    row.name:ClearAllPoints()
    row.right:SetText(data.right or "")
    Theme:SetTextColor(row.right, isItem and Theme.color.rate or Theme.color.muted)
    if isItem then row.name:SetPoint("TOPLEFT", STAR_COLUMN + ITEM_INDENT, -4) else row.name:SetPoint("LEFT", 4, 0) end
    row.name:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
    if isItem then
        row.name:SetFontObject(Theme.font.body)
        row.sub:SetText(data.sub or "")
        Theme:SetTextColor(row.sub, Theme.color.muted)
        Theme:SetRowItem(row, data.itemID, SetupOverviewRow)
        ShowFaded(row, data, { row.name, row.sub, row.right })
    elseif data.run then
        row.name:SetFontObject(Theme.font.section)
        row.name:SetText(data.text)
        Theme:SetTextColor(row.name, Theme.color.heading)
    else
        row.name:SetFontObject(data.note and Theme.font.small or Theme.font.label)
        row.name:SetText(data.note and data.text or Theme:Label(data.text))
        Theme:SetTextColor(row.name, data.note and Theme.color.muted or Theme.color.heading)
    end
    if GameTooltip:IsOwned(row) and isItem then ShowItemTooltip(row) end
end

local function CreateOverviewRow(column)
    local row = Theme:Row(column, ITEM_ROW)
    row.star = CreateRowStar(row)
    Theme:QualityIcon(row)
    row.iconBorder:SetSize(ICON, ICON)
    row.iconBorder:SetPoint("TOPLEFT", STAR_COLUMN, -8)
    row.name = Theme:Text(row, Theme.font.body)
    row.name:SetJustifyH("LEFT")
    row.right = Theme:Text(row, Theme.font.small)
    row.right:SetPoint("RIGHT", -8, 0)
    row.sub = Theme:Text(row, Theme.font.small)
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.sub:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
    row.sub:SetJustifyH("LEFT")
    row.rule = row:CreateTexture(nil, "BORDER")
    row.rule:SetColorTexture(unpack(Theme.color.line))
    row.rule:SetHeight(1)
    row.rule:SetPoint("BOTTOMLEFT", 4, 0)
    row.rule:SetPoint("BOTTOMRIGHT", -4, 0)
    row:RegisterForClicks("LeftButtonUp")
    row:HookScript("OnEnter", function(self)
        local data = self.data
        if data.itemID then
            ShowItemTooltip(self)
        elseif data.run then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 0)
            GameTooltip:AddLine(data.text)
            if ns.SHOW_DROP_RATES then
                GameTooltip:AddLine(L["Chance at least one of these drops in a clear"], unpack(Theme.tip.info))
            end
            GameTooltip:AddLine(L["Click to open its Overview"], unpack(Theme.tip.hint))
            GameTooltip:Show()
        else
            -- Group labels and notes aren't clickable, so they don't light up.
            self.hover:Hide()
        end
    end)
    row:HookScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
        local data = self.data
        if data.itemID then
            ClickItem(data)
        elseif data.run then
            GameTooltip:Hide()
            ns.UI:GoToSource(data.run.inst)
        end
    end)
    return row
end

local function CreateOverviewPage(pane)
    local page = CreatePage(pane)
    page.facts = {
        wished = CreateFact(page, L["Wished"]),
        drops = CreateFact(page, L["Dungeon & raid drops"]),
        bestRun = CreateFact(page, L["Best run"]),
        other = CreateFact(page, L["Other sources"]),
    }
    local factsInOrder = { page.facts.wished, page.facts.drops, page.facts.bestRun, page.facts.other }
    local top = FACT_HEIGHT + 14 + LABEL_HEIGHT
    page.runs = Theme:ScrollColumn(page, CreateOverviewRow, SetupOverviewRow)
    page.runs:SetPoint("TOPLEFT", 0, -top)
    page.runs:SetPoint("BOTTOMLEFT")
    page.other = Theme:ScrollColumn(page, CreateOverviewRow, SetupOverviewRow)
    page.other:SetPoint("TOPRIGHT", 4, -top)
    page.other:SetPoint("BOTTOMRIGHT", 4, 0)
    page.other:SetPoint("LEFT", page.runs, "RIGHT", 24, 0)
    for _, info in ipairs({ { page.runs, L["Dungeon & raid drops  ·  best run first"] },
                            { page.other, L["Everything else"] } }) do
        local label = Theme:Text(page, Theme.font.label)
        label:SetPoint("BOTTOMLEFT", info[1], "TOPLEFT", 4, 9)
        label:SetText(Theme:Label(info[2]))
    end
    page.divider = page:CreateTexture(nil, "BORDER")
    page.divider:SetColorTexture(unpack(Theme.color.line))
    page.divider:SetPoint("TOPLEFT", page.runs, "TOPRIGHT", 12, LABEL_HEIGHT)
    page.divider:SetPoint("BOTTOMLEFT", page.runs, "BOTTOMRIGHT", 12, 0)
    page.divider:SetWidth(1)
    page:SetScript("OnSizeChanged", function(self, width)
        local factWidth = (width - FACT_GAP * 3) / 4
        for i, fact in ipairs(factsInOrder) do
            fact:SetWidth(factWidth)
            fact:ClearAllPoints()
            fact:SetPoint("TOPLEFT", (i - 1) * (factWidth + FACT_GAP), 0)
        end
        self.runs:SetWidth(math.floor(width * 0.56))
    end)
    return page
end

-- The left column: each run's header, then its items. `shownRuns` are the page's runs, unstarred
-- items in them too, so rows don't move; each header counts and rates only what `wishedRuns`
-- (the list's own) still hold there. `hasOwnedDrop`: with no runs, the note says the drops are
-- owned rather than that nothing drops.
local function RunEntries(shownRuns, wishedRuns, hasOwnedDrop, unstarred)
    local wishedRunByInstance = {}
    for _, run in ipairs(wishedRuns) do wishedRunByInstance[run.inst] = run end
    local entries = {}
    for runIndex, run in ipairs(shownRuns) do
        local wishedRun = wishedRunByInstance[run.inst]
        local chance = wishedRun and wishedRun.chance
        if runIndex > 1 then table.insert(entries, { spacer = true, height = SPACER }) end
        table.insert(entries, { run = run, text = run.inst.name, height = RUN_ROW,
                                right = Theme:JoinDots(ItemCountText(wishedRun and #wishedRun.items or 0),
                                    chance and L["%s per clear"]:format(ChanceText(chance))) })
        for _, item in ipairs(run.items) do
            local itemID = item.entry.itemID
            -- A click opens the boss likeliest to drop it.
            local likeliest = item.srcs[1]
            for _, src in ipairs(item.srcs) do
                if (src.rate or 0) > (likeliest.rate or 0) then likeliest = src end
            end
            table.insert(entries, { itemID = itemID, entry = item.entry, height = ITEM_ROW, src = likeliest,
                                    unstarred = unstarred[itemID],
                                    sub = Theme:JoinDots((WL:Slot(item.entry)), BossNames(item.srcs)),
                                    right = ChanceText(item.chance) })
        end
    end
    if #shownRuns == 0 then
        table.insert(entries, { note = true, height = GROUP_ROW,
                                text = hasOwnedDrop and L["You own every dungeon and raid drop on this list."]
                                    or L["Nothing on this list drops in a dungeon or raid."] })
    end
    return entries
end

-- How many items `runs` hold between them; one several dungeons drop counts once.
local function CountRunItems(runs)
    local isCounted, count = {}, 0
    for _, run in ipairs(runs) do
        for _, item in ipairs(run.items) do
            local itemID = item.entry.itemID
            if not isCounted[itemID] then
                isCounted[itemID] = true
                count = count + 1
            end
        end
    end
    return count
end

local function SlotOrder(entry) return select(2, WL:Slot(entry)) end

-- A right-column item: its slot and where it comes from (a drop's likeliest place) under its name.
local function GroupItemEntry(entry, isOwnedGroup, isUnstarred)
    local src = WL:BestSource(entry.itemID)
    local where = src and (src.kind == "Quest" and Theme:JoinDots(src.name, src.inst.name) or WhereText(src))
    return { itemID = entry.itemID, entry = entry, height = ITEM_ROW, src = src, owned = isOwnedGroup,
             unstarred = isUnstarred, sub = Theme:JoinDots((WL:Slot(entry)), where) }
end

-- A right-column group: a gap unless it's first, its label and how many of its items are still
-- wished, then its items in paper-doll order.
local function AddGroup(entries, label, groupItems, isOwnedGroup, unstarred)
    local wishedCount = 0
    for _, entry in ipairs(groupItems) do
        if not unstarred[entry.itemID] then wishedCount = wishedCount + 1 end
    end
    if #entries > 0 then table.insert(entries, { spacer = true, height = SPACER }) end
    table.insert(entries, { text = ("%s (%d)"):format(label, wishedCount), height = GROUP_ROW })
    table.sort(groupItems, function(a, b) return SlotOrder(a) < SlotOrder(b) end)
    for _, entry in ipairs(groupItems) do
        table.insert(entries, GroupItemEntry(entry, isOwnedGroup, unstarred[entry.itemID]))
    end
end

-- The right column: items not owned that no dungeon or raid drops, by source, then every owned
-- item (drops too) under Owned; how many still wished and not owned it lists; and whether any
-- owned item is a drop.
local function OtherEntries(items, isOwned, unstarred)
    local byKind, ownedEntries, otherCount, hasOwnedDrop = {}, {}, 0, false
    for _, entry in ipairs(items) do
        local kind = WL:Kind(entry.itemID)
        if isOwned[entry.itemID] then
            table.insert(ownedEntries, entry)
            hasOwnedDrop = hasOwnedDrop or kind == "Drop"
        elseif kind ~= "Drop" then
            byKind[kind] = byKind[kind] or {}
            table.insert(byKind[kind], entry)
            if not unstarred[entry.itemID] then otherCount = otherCount + 1 end
        end
    end
    local entries = {}
    for _, group in ipairs(GROUPS) do
        local kind, label = group[1], group[2]
        if byKind[kind] then AddGroup(entries, label, byKind[kind], false, unstarred) end
    end
    if #ownedEntries > 0 then AddGroup(entries, L["Owned"], ownedEntries, true, unstarred) end
    if #entries == 0 then
        table.insert(entries, { note = true, height = GROUP_ROW,
                                text = L["Everything here drops in a dungeon or raid."] })
    end
    return entries, otherCount, hasOwnedDrop
end

-- Redraws Overview: its rows from `shown` (the visit, unstarred items in place), its facts from
-- `list` and only items not owned; `keep` holds both columns' scroll positions. `isOwned` is
-- WL:OwnedItems' set for the shown items, `ownedCount` how many on the list are owned.
local function UpdateOverview(page, list, shown, keep, isOwned, ownedCount)
    local runs = WL:Runs(list, isOwned)
    local otherEntries, otherCount, hasOwnedDrop = OtherEntries(shown.items, isOwned, shown.unstarred)
    page.other:SetData(otherEntries, keep)
    page.runs:SetData(RunEntries(WL:Runs(shown, isOwned), runs, hasOwnedDrop, shown.unstarred), keep)
    local dropCount = CountRunItems(runs)
    local facts = page.facts
    facts.wished.value:SetText(ownedCount == 0 and ItemCountText(#list.items)
        or Theme:JoinDots(L["%d to get"]:format(#list.items - ownedCount), OwnedText(ownedCount)))
    local placesText = (#runs == 1 and L["%d place"] or L["%d places"]):format(#runs)
    facts.drops.value:SetText(dropCount == 0 and L["None"]
        or L["%s in %s"]:format(ItemCountText(dropCount), placesText))
    local bestRun = runs[1]
    facts.bestRun.value:SetText(bestRun
        and Theme:JoinDots(bestRun.inst.name, bestRun.chance and ChanceText(bestRun.chance)) or L["None"])
    facts.other.value:SetText(otherCount == 0 and L["None"] or ItemCountText(otherCount))
end

-- Details -----------------------------------------------------------------

-- The table's columns: key, label, width (or a share of what is left), which way a first click sorts.
local COLUMNS = {
    { key = "slot", label = L["Slot"], tip = L["Sort by slot"], width = 84 },
    { key = "item", label = L["Item"], tip = L["Sort by item"], share = 0.56 },
    { key = "source", label = L["Source"], tip = L["Sort by source"], width = 84 },
    { key = "where", label = L["Where"], tip = L["Sort by where"], share = 0.44 },
    { key = "chance", label = L["Chance"], tip = L["Sort by chance"], width = 64, desc = true, right = true },
    { key = "owned", label = L["Owned"], tip = L["Sort by owned"], width = 52, desc = true, right = true },
}
if not ns.SHOW_DROP_RATES then table.remove(COLUMNS, 5) end -- no Chance column while drop chances are hidden
local COLUMN_GAP = 8

-- Each column's left edge and width across `width`.
local function ColumnLayout(width)
    local fixed, layout = STAR_COLUMN, {}
    for _, col in ipairs(COLUMNS) do fixed = fixed + (col.width or 0) + COLUMN_GAP end
    local free = math.max(120, width - fixed)
    local x = STAR_COLUMN
    for i, col in ipairs(COLUMNS) do
        local colWidth = col.width or math.floor(free * col.share)
        layout[i] = { x = x, w = colWidth }
        x = x + colWidth + COLUMN_GAP
    end
    return layout
end

local function SetupTableRow(row, data)
    -- The row sits on the table column's clipped view (Theme:ScrollColumn).
    local layout = row:GetParent():GetParent().layout
    if layout then
        for i, cell in ipairs(row.cells) do
            local col = layout[i]
            local indent = i == 2 and ITEM_INDENT or 0
            cell:ClearAllPoints()
            cell:SetPoint("LEFT", col.x + indent, 0)
            cell:SetWidth(math.max(1, col.w - indent))
        end
        row.iconBorder:SetPoint("LEFT", layout[2].x, 0)
        local ownedCol = layout[#layout]
        row.owned:SetPoint("CENTER", row, "LEFT", ownedCol.x + ownedCol.w - 12, 0)
    end
    row.slot:SetText(data.slot)
    Theme:SetTextColor(row.slot, Theme.color.muted)
    Theme:SetRowItem(row, data.itemID, SetupTableRow)
    row.source:SetText(KIND_LABELS[data.kind] or data.kind)
    Theme:SetTextColor(row.source, KindColor(data.kind))
    row.where:SetText(data.where)
    Theme:SetTextColor(row.where, Theme.color.muted)
    row.chance:SetText(ChanceText(data.chance))
    Theme:SetTextColor(row.chance, Theme.color.rate)
    row.owned:SetShown(data.owned)
    ShowFaded(row, data, row.cells)
    if GameTooltip:IsOwned(row) then ShowItemTooltip(row) end
end

local function CreateTableRow(column)
    local row = Theme:Row(column, TABLE_ROW)
    row.star = CreateRowStar(row)
    Theme:QualityIcon(row)
    row.iconBorder:SetSize(ICON, ICON)
    row.slot = Theme:Text(row, Theme.font.small)
    row.name = Theme:Text(row, Theme.font.body)
    row.source = Theme:Text(row, Theme.font.small)
    row.where = Theme:Text(row, Theme.font.small)
    row.chance = Theme:Text(row, Theme.font.small)
    row.chance:SetJustifyH("RIGHT")
    row.cells = { row.slot, row.name, row.source, row.where, ns.SHOW_DROP_RATES and row.chance or nil }
    row.chance:SetShown(ns.SHOW_DROP_RATES)
    for _, cell in ipairs(row.cells) do
        if cell ~= row.chance then cell:SetJustifyH("LEFT") end
    end
    row.owned = row:CreateTexture(nil, "OVERLAY")
    row.owned:SetAtlas("common-icon-checkmark")
    row.owned:SetSize(14, 14)
    row:RegisterForClicks("LeftButtonUp")
    row:HookScript("OnEnter", ShowItemTooltip)
    row:HookScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self) ClickItem(self.data) end)
    return row
end

local function SortValue(data, key)
    if key == "slot" then return data.slotOrder end
    if key == "item" then return data.sortName end
    if key == "source" then return KIND_ORDER[data.kind] or 99 end
    if key == "where" then return data.where:lower() end
    if key == "chance" then return data.chance or -1 end
    if key == "owned" then return data.owned and 1 or 0 end
end

-- Ties fall back to slot order, name, then item ID, so rows never shuffle between redraws.
local function SortRows(rows, key, descending)
    table.sort(rows, function(a, b)
        local valueA, valueB = SortValue(a, key), SortValue(b, key)
        if valueA ~= valueB then
            if descending then return valueA > valueB end
            return valueA < valueB
        end
        if a.slotOrder ~= b.slotOrder then return a.slotOrder < b.slotOrder end
        if a.sortName ~= b.sortName then return a.sortName < b.sortName end
        return a.itemID < b.itemID
    end)
end

-- The source filter: "All 19", "Drop 3", "Crafted 5"... as pills, the picked one filled.
local function CreateChips(page)
    local bar = CreateFrame("Frame", nil, page)
    bar:SetHeight(CHIP_HEIGHT)
    bar.pills = {}
    function bar:Set(counts, total, activeKind, onPick) -- onPick(kind), nil for All
        local chips = { { nil, L["All"], total } }
        for _, kind in ipairs(KINDS) do
            if counts[kind] then chips[#chips + 1] = { kind, KIND_LABELS[kind], counts[kind] } end
        end
        local prev
        for i, chip in ipairs(chips) do
            local kind, label, count = chip[1], chip[2], chip[3]
            local pill = self.pills[i] or Theme:Pill(self)
            self.pills[i] = pill
            pill:SetLabel(("%s  %d"):format(label, count))
            pill:SetTone(kind == activeKind and Theme.color.heading or nil)
            pill:SetScript("OnClick", function() onPick(kind) end)
            pill:ClearAllPoints()
            if prev then pill:SetPoint("LEFT", prev, "RIGHT", 6, 0) else pill:SetPoint("LEFT") end
            pill:Show()
            prev = pill
        end
        for i = #chips + 1, #self.pills do self.pills[i]:Hide() end
    end
    return bar
end

local function CreateHeaderButton(page, col)
    local btn = CreateFrame("Button", nil, page)
    btn:SetHeight(HEAD_HEIGHT)
    btn.text = Theme:Text(btn, Theme.font.label)
    btn.text:SetText(Theme:Label(col.label))
    -- A right-aligned column's name leaves room for the mark after it.
    if col.right then btn.text:SetPoint("RIGHT", -13, 0) else btn.text:SetPoint("LEFT") end
    btn.mark = Theme:SortMark(btn)
    btn.mark:SetPoint("LEFT", btn.text, "RIGHT", 3, 0)
    btn.col = col
    btn:SetScript("OnEnter", function(self)
        if not self.active then Theme:SetTextColor(self.text, Theme.color.text) end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(col.tip)
        GameTooltip:AddLine(L["Click again to reverse"], unpack(Theme.tip.hint))
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self:Paint()
        GameTooltip:Hide()
    end)
    function btn:Paint()
        Theme:SetTextColor(self.text, self.active and Theme.color.heading or Theme.color.muted)
        self.mark:SetShown(self.active)
    end
    return btn
end

-- A Details row's data. A drop's Where also counts the other dungeons and raids that drop it.
local function TableRowData(entry, kind, isOwned, isUnstarred)
    local itemID = entry.itemID
    local slot, slotOrder = WL:Slot(entry)
    local src = WL:BestSource(itemID)
    local where = WhereText(src)
    if kind == "Drop" then
        local seen, otherPlaces = { [src.inst] = true }, 0
        for _, other in ipairs(WL:Sources(itemID)) do
            if other.kind == "Drop" and not seen[other.inst] then
                seen[other.inst] = true
                otherPlaces = otherPlaces + 1
            end
        end
        if otherPlaces > 0 then where = L["%s  +%d more"]:format(where, otherPlaces) end
    end
    return {
        itemID = itemID, entry = entry, slot = slot, slotOrder = slotOrder, kind = kind, src = src, where = where,
        chance = WL:BestChance(itemID), owned = isOwned[itemID] == true, unstarred = isUnstarred, height = TABLE_ROW,
        sortName = (C_Item.GetItemNameByID(itemID) or ""):lower(),
    }
end

local function CreateDetailsPage(pane)
    local page = CreatePage(pane)
    page.sortKey, page.sortDesc = "slot", false
    page.chips = CreateChips(page)
    page.chips:SetPoint("TOPLEFT", 0, 0)
    page.chips:SetPoint("TOPRIGHT", 0, 0)
    local top = CHIP_HEIGHT + 6 + HEAD_HEIGHT + 4
    page.table = Theme:ScrollColumn(page, CreateTableRow, SetupTableRow)
    page.table:SetPoint("TOPLEFT", 0, -top)
    page.table:SetPoint("BOTTOMRIGHT", 4, 0)
    page.rule = page:CreateTexture(nil, "BORDER")
    page.rule:SetColorTexture(unpack(Theme.color.line))
    page.rule:SetHeight(1)
    page.rule:SetPoint("BOTTOMLEFT", page.table, "TOPLEFT", 0, 2)
    page.rule:SetPoint("BOTTOMRIGHT", page.table, "TOPRIGHT", -8, 2)
    page.headers = {}
    for i, col in ipairs(COLUMNS) do
        local btn = CreateHeaderButton(page, col)
        btn:SetScript("OnClick", function()
            if page.sortKey == col.key then
                page.sortDesc = not page.sortDesc
            else
                page.sortKey, page.sortDesc = col.key, col.desc or false
            end
            page:Update(page.shown, true, page.isOwned)
        end)
        page.headers[i] = btn
    end
    page:SetScript("OnSizeChanged", function(self, width)
        local layout = ColumnLayout(width - 8)
        self.table.layout = layout
        for i, btn in ipairs(self.headers) do
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOMLEFT", self.table, "TOPLEFT", layout[i].x, 4)
            btn:SetWidth(layout[i].w)
        end
        self.table:Refresh()
    end)

    -- `shown` is the visit (the list's items and the ones unstarred on this visit); `isOwned` is
    -- WL:OwnedItems' set for them. Both are kept for re-sorting and filtering until the next redraw.
    function page:Update(shown, keep, isOwned)
        self.shown, self.isOwned = shown, isOwned
        -- A source keeps its chip while it has rows, unstarred ones too; the chips count what's still wished.
        local counts, rows, wishedCount = {}, {}, 0
        for _, entry in ipairs(shown.items) do
            local kind = WL:Kind(entry.itemID)
            local isUnstarred = shown.unstarred[entry.itemID] == true
            local wished = isUnstarred and 0 or 1
            counts[kind] = (counts[kind] or 0) + wished
            wishedCount = wishedCount + wished
            if not self.filter or self.filter == kind then
                table.insert(rows, TableRowData(entry, kind, isOwned, isUnstarred))
            end
        end
        if self.filter and not counts[self.filter] then
            self.filter = nil
            return self:Update(shown, keep, isOwned)
        end
        self.chips:Set(counts, wishedCount, self.filter, function(kind)
            self.filter = kind
            self:Update(self.shown, nil, self.isOwned)
        end)
        for _, btn in ipairs(self.headers) do
            btn.active = btn.col.key == self.sortKey
            btn.mark:SetDescending(self.sortDesc)
            btn:Paint()
        end
        SortRows(rows, self.sortKey, self.sortDesc)
        self.table:SetData(rows, keep)
    end
    return page
end

-- The pane ----------------------------------------------------------------

local function CreateHeader(pane)
    pane.icon = Theme:Star(pane, 24)
    pane.icon:EnableMouse(false)
    pane.icon:SetOn(true)
    pane.title = Theme:Text(pane, Theme.font.heading)
    pane.title:SetPoint("TOPLEFT", Size.pad + 4 + 24 + 6, -18)
    pane.icon:SetPoint("RIGHT", pane.title, "LEFT", -6, 0)
    pane.title:SetText(L["Wishlist"])
    pane.subtitle = Theme:Text(pane, Theme.font.small)
    pane.subtitle:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -6)
    pane.subtitle:SetPoint("RIGHT", -Size.pad, 0)
    pane.subtitle:SetJustifyH("LEFT")
    pane.view = Theme:LabelToggle(pane, { L["Overview"], L["Details"] }, function(name)
        WL:SetView(name == L["Details"] and "details" or "overview")
    end, Theme.font.pane)
    pane.view:SetPoint("TOPRIGHT", -Size.pad + 6, -18)
    pane.empty = Theme:Text(pane, Theme.font.body)
    pane.empty:SetPoint("CENTER", 0, 10)
    pane.empty:SetText(L["This wishlist is empty"])
    Theme:SetTextColor(pane.empty, Theme.color.muted)
    pane.emptyHint = Theme:Text(pane, Theme.font.small)
    pane.emptyHint:SetPoint("TOP", pane.empty, "BOTTOM", 0, -8)
    pane.emptyHint:SetText(L["Star gear on any loot list, or Import a sixtyupgrades.com export."])
end

function ns.UI.CreateWishlist(parent)
    local pane = Theme:CreatePanel(parent, "loot")
    CreateHeader(pane)
    pane.overview = CreateOverviewPage(pane)
    pane.details = CreateDetailsPage(pane)
    ListUI.Add(pane, WL, {
        listsTitle = L["Your wishlists"],
        listsTip = L["Saved for every character on this account. Stars add to the list shown here."],
        newListName = L["Wishlist"],
        newListHint = L["An empty list, starred items go on it."],
        importTip = L["Add gear from a sixtyupgrades.com export or a NeedRoll share string."],
        exportTip = L["A share string for this list, to paste in chat."],
    })
    pane.listButton:SetPoint("LEFT", pane.title, "RIGHT", 12, 0)
    pane.importDialog = CreateImportDialog(pane)
    pane.exportDialog = CreateExportDialog(pane)
    pane:HookScript("OnHide", function()
        visit = nil -- leaving the page: rows unstarred on it drop off
    end)

    -- Redraws from the saved list, keeping rows unstarred on this visit; a new list starts at the
    -- top. MainFrame reads `count`, the items still on the list.
    function pane:Update()
        local list = WL:Current()
        local keep = self.shownList == list
        self.shownList = list
        local count = #list.items
        local view = WL:View()
        local shown = CurrentVisit(list, view)
        local isEmpty = #shown.items == 0
        self:UpdateListControls()
        self.view:SetActive(view == "details" and L["Details"] or L["Overview"])
        self.view:SetShown(not isEmpty)
        self.empty:SetShown(isEmpty)
        self.emptyHint:SetShown(isEmpty)
        self.overview:SetShown(not isEmpty and view == "overview")
        self.details:SetShown(not isEmpty and view == "details")
        local isOwned = WL:OwnedItems(shown)
        local _, ownedCount = WL:OwnedItems(list)
        self.subtitle:SetText(isEmpty and "" or Theme:JoinDots(list.note, ItemCountText(count),
            OwnedText(ownedCount), L["%d from dungeons and raids"]:format(CountDrops(list.items))))
        if self.overview:IsShown() then UpdateOverview(self.overview, list, shown, keep, isOwned, ownedCount) end
        if self.details:IsShown() then self.details:Update(shown, keep, isOwned) end
        self.count = count
    end
    -- What's owned follows the character: bags and bank change through bag updates, worn gear
    -- through equipment changes (a worn item sold or destroyed changes no bag).
    local function RedrawOwned()
        if pane:IsVisible() then pane:Update() end
    end
    ns:On("BAG_UPDATE_DELAYED", RedrawOwned)
    ns:On("PLAYER_EQUIPMENT_CHANGED", RedrawOwned)
    return pane
end
