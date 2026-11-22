-- The Classes tab's Comprehension section, the mage's alone: one page, the
-- "Scroll of ..." items only a mage can use (Data/MageScrolls.lua), under
-- headings by the level they need. Only item IDs and levels ship: the game
-- names each scroll and gives its icon, quality and tooltip by item ID.
-- A scroll's row shows its tooltip on hover; Shift-click links it in chat
-- (Ctrl-click tries it on, as any item link). Scrolls in your bags say how
-- many you carry.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L

local MageScrolls = {}
ns.UI.MageScrolls = MageScrolls

local MAGE = "MAGE"
local PAGE_KEY = "COMPREHENSION:SCROLLS"
local COMPREHENSION_SCROLL = 215257  -- Scroll of Comprehension, whose icon heads the page and marks its row

local STRIP_INSET = Size.pad - 4  -- the level line, from the strip's end (as Back's)
local HEADING_LEFT = 16           -- the icon, the line under the heading and the rows, in from the left
local HEADING_TOP = 12            -- the icon, down from the pane's top
local TITLE_ICON = 30             -- the page's icon before its name
local TITLE_ICON_GAP = 10         -- between the icon and the name
local SUBTITLE_GAP = 4            -- between the icon and the line under it
local ROWS_GAP = 10               -- between the line under the heading and the first row
local HEADING_ROW = 30            -- a level heading's row
local SCROLL_ROW = 28             -- a scroll's row
local ITEM_ICON = 20              -- a scroll's icon, with its quality edge
local ITEM_ICON_GAP = 8           -- between the icon and the name
local HEADING_NOTE_GAP = 8        -- between a heading and its count
local RIGHT_INSET = 16            -- the bag count, in from the row's right
local TEXT_ROOM = 12              -- the least room between a scroll's name and the bag count

-- The list's rows, by `kind`.
local HEADING, SCROLL = "HEADING", "SCROLL"

-- The data --------------------------------------------------------------------------

local function Scrolls()
    return ns.Data.mageScrolls
end

-- Whether class `classID` has the Comprehension section: the mage, while the data loaded.
function MageScrolls.Has(classID)
    return select(2, GetClassInfo(classID)) == MAGE and Scrolls() ~= nil
end

-- How many scrolls there are, for the section's header.
function MageScrolls.Count()
    return #(Scrolls() or {})
end

-- The section's one page, kept so its row stays the same row as the list redraws.
local SCROLLS_PAGE = { key = PAGE_KEY, name = L["Scrolls"], scrollPage = true }

-- The section's pages: the scrolls page for a mage, none for another class.
function MageScrolls.Pages(classID)
    if not MageScrolls.Has(classID) then return {} end
    SCROLLS_PAGE.icon = C_Item.GetItemIconByID(COMPREHENSION_SCROLL)
    return { SCROLLS_PAGE }
end

-- How many of item `itemID` are in your bags.
local function BagCount(itemID)
    return C_Item.GetItemCount(itemID) or 0
end

-- The scrolls grouped by the level they need, those that need none first,
-- each group in the data's order: { { level = nil or 5, scrolls = { ... } }, ... }.
local function LevelGroups()
    local groups, groupOf = {}, {}
    for _, scroll in ipairs(Scrolls()) do
        local level = scroll.level or 0
        if not groupOf[level] then
            groupOf[level] = { level = scroll.level, scrolls = {} }
            table.insert(groups, groupOf[level])
        end
        table.insert(groupOf[level].scrolls, scroll)
    end
    table.sort(groups, function(a, b) return (a.level or 0) < (b.level or 0) end)
    return groups
end

-- A heading per level ("Any level", then "Level 5" ...) with how many
-- scrolls it holds, each followed by its scrolls' rows.
local function PageRows()
    local rows = {}
    for _, group in ipairs(LevelGroups()) do
        table.insert(rows, { kind = HEADING, height = HEADING_ROW,
            text = group.level and L["Level %d"]:format(group.level) or L["Any level"],
            note = Theme:Plural(#group.scrolls, L["%d scroll"], L["%d scrolls"]) })
        for _, scroll in ipairs(group.scrolls) do
            table.insert(rows, { kind = SCROLL, height = SCROLL_ROW, itemID = scroll.itemID })
        end
    end
    return rows
end

-- The rows ---------------------------------------------------------------------------

local function ShowScrollTooltip(row)
    local entry = row.data
    if not (entry and entry.kind == SCROLL) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT", 4, 0)
    GameTooltip:SetItemByID(entry.itemID)
    GameTooltip:Show()
end

-- A modified click on a scroll does what it does on any item link: Shift
-- links it in chat, Ctrl tries it on.
local function OnRowClick(row)
    local entry = row.data
    if entry and entry.kind == SCROLL then ns.Items:HandleModifiedClick(entry.itemID) end
end

-- A row of the list: a heading's text and count, or a scroll's icon with
-- its quality edge, its name in its quality colour and at the right how
-- many you carry.
local function CreateRow(column)
    local row = Theme:Row(column, SCROLL_ROW)
    Theme:QualityIcon(row)
    row.iconBorder:SetSize(ITEM_ICON, ITEM_ICON)
    row.iconBorder:SetPoint("LEFT", HEADING_LEFT, 0)
    row.name = Theme:Text(row, Theme.font.body)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.note = Theme:Text(row, Theme.font.small)
    row.note:SetPoint("LEFT", row.name, "RIGHT", HEADING_NOTE_GAP, 0)
    Theme:SetTextColor(row.note, Theme.color.muted)
    row.right = Theme:Text(row, Theme.font.small)
    row.right:SetPoint("RIGHT", -RIGHT_INSET, 0)
    row.right:SetJustifyH("RIGHT")
    Theme:SetTextColor(row.right, Theme.color.complete)
    row:RegisterForClicks("LeftButtonUp")
    row:HookScript("OnEnter", ShowScrollTooltip)
    row:HookScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", OnRowClick)
    return row
end

local function SetupHeadingRow(row, entry)
    row.iconBorder:Hide()
    row.icon:Hide()
    row:EnableMouse(false)
    row.name:SetFontObject(Theme.font.section)
    Theme:SetTextColor(row.name, Theme.color.heading)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", HEADING_LEFT, 0)
    row.name:SetText(entry.text)
    row.note:SetText(entry.note)
    row.right:SetText("")
end

local function SetupRow(row, entry)
    if entry.kind == HEADING then return SetupHeadingRow(row, entry) end
    row.iconBorder:Show()
    row.icon:Show()
    row:EnableMouse(true)
    row.name:SetFontObject(Theme.font.body)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.iconBorder, "RIGHT", ITEM_ICON_GAP, 0)
    row.name:SetPoint("RIGHT", row.right, "LEFT", -TEXT_ROOM, 0)
    row.note:SetText("")
    local count = BagCount(entry.itemID)
    row.right:SetText(count > 0 and L["%d in bags"]:format(count) or "")
    Theme:SetRowItem(row, entry.itemID, SetupRow)
    if GameTooltip:IsOwned(row) then ShowScrollTooltip(row) end
end

-- The page ---------------------------------------------------------------------------

-- The heading: Scroll of Comprehension's icon and "Comprehension", and the
-- line under it.
local function CreateHeading(page)
    page.icon = page:CreateTexture(nil, "ARTWORK")
    page.icon:SetPoint("TOPLEFT", HEADING_LEFT, -HEADING_TOP)
    page.icon:SetSize(TITLE_ICON, TITLE_ICON)
    Theme:CropIcon(page.icon)
    page.title = Theme:Text(page, Theme.font.instance)
    page.title:SetPoint("LEFT", page.icon, "RIGHT", TITLE_ICON_GAP, 0)
    page.title:SetText(L["Comprehension"])
    page.subtitle = Theme:Text(page, Theme.font.body)
    page.subtitle:SetPoint("TOPLEFT", page.icon, "BOTTOMLEFT", 0, -SUBTITLE_GAP)
    page.subtitle:SetPoint("RIGHT", -HEADING_LEFT, 0)
    page.subtitle:SetJustifyH("LEFT")
    page.subtitle:SetWordWrap(false)
    Theme:SetTextColor(page.subtitle, Theme.color.muted)
end

-- "22 scrolls  ·  only a mage can use them  ·  3 in your bags" (the last
-- part while you carry any).
local function SubtitleText()
    local carried = 0
    for _, scroll in ipairs(Scrolls()) do carried = carried + BagCount(scroll.itemID) end
    return Theme:JoinDots(Theme:Plural(MageScrolls.Count(), L["%d scroll"], L["%d scrolls"]),
        L["only a mage can use them"], carried > 0 and L["%d in your bags"]:format(carried) or nil)
end

-- The scrolls page. `parent` is the Classes tab; MainFrame.lua hosts the
-- page in the tab's content pane, with its strip.
function ns.UI.CreateMageScrollPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    CreateHeading(page)
    page.levelLine = Theme:Text(page, Theme.font.body)
    Theme:SetTextColor(page.levelLine, Theme.color.muted)
    page.column = Theme:ScrollColumn(page, CreateRow, SetupRow)

    function page:PlaceStrip(strip)
        self.levelLine:SetParent(strip)
        self.levelLine:SetPoint("RIGHT", -STRIP_INSET, 0)
    end

    -- The rows under the line below the heading.
    function page:PlaceColumn()
        local top = HEADING_TOP + TITLE_ICON + SUBTITLE_GAP + Theme:LineHeight(self.subtitle) + ROWS_GAP
        self.column:ClearAllPoints()
        self.column:SetPoint("TOPLEFT", 0, -top)
        self.column:SetPoint("BOTTOMRIGHT")
    end

    -- Redraws the page for the bags as they are now, keeping the scroll.
    function page:Refresh()
        self.icon:SetTexture(C_Item.GetItemIconByID(COMPREHENSION_SCROLL))
        self.subtitle:SetText(SubtitleText())
        self.levelLine:SetText(L["Level %d"]:format(ns.PlayerLevel()))
        self:PlaceColumn()
        self.column:SetData(PageRows(), self.hasRows)
        self.hasRows = true
    end

    -- A scroll picked up, used or sold changes the bag counts.
    ns:On("BAG_UPDATE_DELAYED", function()
        if page:IsVisible() then page:Refresh() end
    end)
    return page
end
