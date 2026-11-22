-- The Game hotfixes page: Blizzard's WoW: Forever hotfix list in NeedRoll's
-- own short words (Data/Hotfixes.lua), for reference. The quiet link at the
-- bottom of the Settings page and /nr hotfixes open it in the Settings
-- page's place, with Back to Settings (UI:OpenHotfixes in MainFrame.lua).
-- Each day's hotfixes sit under its date, each under its topic (Blizzard's
-- section names), a developers' note indented under its hotfix. A hotfix
-- Blizzard has since taken off its list stays where it was, dimmed and
-- struck through, its tooltip saying when it left.
local _, ns = ...
local Theme = ns.Theme
local L = ns.L

local HotfixPage = {}
ns.HotfixPage = HotfixPage

local PAD = ns.Settings.PAD
local HEADER_HEIGHT = 44  -- the title and the line under it, as on the Settings page
local LINK_WIDTH = 380    -- the box holding the forum post's address
local LINK_ROW = 32       -- that box (24 high) and the gap under it
local LIST_TOP = PAD + HEADER_HEIGHT + LINK_ROW
local DAY_GAP = 18        -- above each day's date but the first
local TOPIC_GAP = 8       -- above a topic
local ENTRY_GAP = 3       -- above a hotfix
local NOTE_GAP = 2        -- above a developers' note
local ENTRY_INDENT = 10   -- a hotfix, in from its topic
local NOTE_INDENT = 22    -- a developers' note, in from its topic
local TEXT_RIGHT = 16     -- room right of the text, clear of the scroll bar
-- The strike line crosses each line of text this far down it (a share of
-- the line's height): a little under the middle, where lower-case letters
-- sit. It runs STRIKE_OVERHANG past the text at each end.
local STRIKE_DROP = 0.55
local STRIKE_OVERHANG = 1

-- Dates -------------------------------------------------------------------
-- The game's own month and weekday names, as its full dates use them.
local MONTH_NAMES = {
    FULLDATE_MONTH_JANUARY, FULLDATE_MONTH_FEBRUARY, FULLDATE_MONTH_MARCH, FULLDATE_MONTH_APRIL,
    FULLDATE_MONTH_MAY, FULLDATE_MONTH_JUNE, FULLDATE_MONTH_JULY, FULLDATE_MONTH_AUGUST,
    FULLDATE_MONTH_SEPTEMBER, FULLDATE_MONTH_OCTOBER, FULLDATE_MONTH_NOVEMBER, FULLDATE_MONTH_DECEMBER,
}
-- In date("*t").wday's order: Sunday first.
local WEEKDAY_NAMES = {
    WEEKDAY_SUNDAY, WEEKDAY_MONDAY, WEEKDAY_TUESDAY, WEEKDAY_WEDNESDAY,
    WEEKDAY_THURSDAY, WEEKDAY_FRIDAY, WEEKDAY_SATURDAY,
}

-- "2026-11-16" as the game writes a full date in the player's language
-- (FULLDATE: "Monday, November 16 2026" in English; other languages put the
-- parts in their own order through its numbered %1$s codes).
local function FormatDate(isoDate)
    local year, month, day = isoDate:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not year then return isoDate end
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    -- At noon, so no time zone can move it to the day before or after.
    local weekday = date("*t", time({ year = year, month = month, day = day, hour = 12 })).wday
    return FULLDATE:format(WEEKDAY_NAMES[weekday], MONTH_NAMES[month], day, year)
end
HotfixPage.FormatDate = FormatDate -- for the smoke tests (tests/smoke)

-- Header ------------------------------------------------------------------
-- Addons can't open a browser, so the post's address sits in a box,
-- selected for Ctrl+C on a click, with what to do beside it.
local function ShowCopyHint(page, isCopied)
    page.copyHint:SetText(isCopied and L["Copied. Paste it in your browser."]
        or L["Click the address and press Ctrl+C to copy it."])
    Theme:SetTextColor(page.copyHint, isCopied and Theme.color.complete or Theme.color.muted)
end

local function AddHeader(page, canvas)
    local title = Theme:Text(canvas, Theme.font.heading)
    title:SetPoint("TOPLEFT", PAD, -PAD + 4)
    title:SetText(L["Game hotfixes"])
    local subtitle = Theme:Text(canvas, Theme.font.small)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText(L["Blizzard's WoW: Forever hotfix list, in short. Last checked %s."]
        :format(FormatDate(ns.Hotfixes.checked)))
    page.link = Theme:LinkBox(canvas, LINK_WIDTH, ns.Hotfixes.source, function() ShowCopyHint(page, true) end)
    -- The native box's border is drawn outside it.
    page.link:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", Theme.native and 6 or 0, -8)
    page.copyHint = Theme:Text(canvas, Theme.font.small)
    page.copyHint:SetPoint("LEFT", page.link, "RIGHT", 10, 0)
end

-- Struck-through hotfixes ---------------------------------------------------
-- A font string has no strikethrough of its own, so a thin line is drawn
-- through each line its text wraps to, as long as that line's words.

local function NewStrike(label)
    local strike = label:GetParent():CreateTexture(nil, "OVERLAY", nil, 7)
    strike:SetColorTexture(unpack(Theme.color.muted))
    PixelUtil.SetHeight(strike, 1)
    return strike
end

-- The width of each line `label`'s text wraps to at `width`, wrapped word
-- by word as the game wraps it.
local function WrappedLineWidths(label, width)
    local widths, line = {}, nil
    for word in label:GetText():gmatch("%S+") do
        local longer = line and (line .. " " .. word) or word
        if line and label:GetUnboundedStringWidthForText(longer) > width then
            table.insert(widths, label:GetUnboundedStringWidthForText(line))
            longer = word
        end
        line = longer
    end
    if line then table.insert(widths, label:GetUnboundedStringWidthForText(line)) end
    for index, lineWidth in ipairs(widths) do widths[index] = math.min(lineWidth, width) end
    return widths
end

-- Line `index` of `lineCount`'s strike width. The measured widths count only
-- while they wrap into as many lines as the game drew; otherwise every line
-- but the last spans the text's width, and the last is measured.
local function StrikeWidth(widths, lineCount, index, width)
    if #widths == lineCount then return widths[index] end
    if index == lineCount then return widths[#widths] or width end
    return width
end

local function DrawStrikes(row, width)
    local label = row.label
    local lineCount = math.max(1, label:GetNumLines())
    local widths = WrappedLineWidths(label, width)
    local lineHeight = label:GetLineHeight()
    local linePitch = lineHeight + label:GetSpacing()
    for index = 1, lineCount do
        local strike = row.strikes[index] or NewStrike(label)
        row.strikes[index] = strike
        strike:SetPoint("LEFT", label, "TOPLEFT", -STRIKE_OVERHANG,
            -(index - 1) * linePitch - lineHeight * STRIKE_DROP)
        strike:SetWidth(StrikeWidth(widths, lineCount, index, width) + STRIKE_OVERHANG * 2)
        strike:Show()
    end
    for index = lineCount + 1, #row.strikes do row.strikes[index]:Hide() end
end

local function ShowRemovedTooltip(hoverArea)
    GameTooltip:SetOwner(hoverArea, "ANCHOR_TOPLEFT")
    GameTooltip:AddLine(L["Removed from Blizzard's list on %s"]:format(FormatDate(hoverArea.removed)),
        unpack(Theme.tip.info))
    GameTooltip:Show()
end

-- Strike lines are drawn at layout (LayOutRows); the tooltip is hovered
-- over the text itself.
local function MarkRemoved(row, removed)
    row.strikes = {}
    local hoverArea = CreateFrame("Frame", nil, row.label:GetParent())
    hoverArea:SetAllPoints(row.label)
    hoverArea:EnableMouseMotion(true)
    hoverArea.removed = removed
    hoverArea:SetScript("OnEnter", ShowRemovedTooltip)
    hoverArea:SetScript("OnLeave", GameTooltip_Hide)
    row.hoverArea = hoverArea
end

-- The list ----------------------------------------------------------------
-- Every line is built once, the first time the page shows; a change of the
-- window's width only wraps them again (LayOutRows).

-- A line of the list: `text` in `font` and `color`, `indent` in from the
-- page's edge and `gap` under the line above.
local function AddRow(page, font, color, indent, gap, text)
    local label = Theme:Text(page.canvas, font)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    label:SetText(text)
    Theme:SetTextColor(label, color)
    local row = { label = label, indent = indent, gap = gap }
    table.insert(page.rows, row)
    return row
end

local function AddEntryRow(page, entry)
    local font = entry.note and Theme.font.small or Theme.font.body
    local color = entry.removed and Theme.color.faint or entry.note and Theme.color.muted or Theme.color.text
    local indent, gap = ENTRY_INDENT, ENTRY_GAP
    if entry.note then indent, gap = NOTE_INDENT, NOTE_GAP end
    local row = AddRow(page, font, color, indent, gap, entry.text)
    if entry.removed then MarkRemoved(row, entry.removed) end
end

-- Each day: its date, then its hotfixes, a topic line ("Classes  ·  Priest")
-- wherever the topic changes.
local function BuildRows(page)
    for dayIndex, day in ipairs(ns.Hotfixes.days) do
        AddRow(page, Theme.font.section, Theme.color.heading, 0, dayIndex > 1 and DAY_GAP or 0, FormatDate(day.date))
        local shownTopic
        for _, entry in ipairs(day.entries) do
            local topic = Theme:JoinDots(unpack(entry.topic))
            if topic ~= shownTopic then
                AddRow(page, Theme.font.small, Theme.color.muted, 0, TOPIC_GAP, topic)
                shownTopic = topic
            end
            AddEntryRow(page, entry)
        end
    end
    page.isBuilt = true
end

-- Wraps every line to the page's `width`, stacks them and redraws the
-- strike lines. Nothing to do while the width is what it was.
local function LayOutRows(page, width)
    if width <= 0 or width == page.laidOutWidth then return end
    page.laidOutWidth = width
    local y = LIST_TOP
    for _, row in ipairs(page.rows) do
        local textWidth = width - PAD - row.indent - TEXT_RIGHT
        y = y + row.gap
        row.label:SetWidth(textWidth)
        row.label:SetPoint("TOPLEFT", PAD + row.indent, -y)
        -- Asked before the strike lines, so the game has wrapped the text.
        y = y + row.label:GetStringHeight()
        if row.strikes then DrawStrikes(row, textWidth) end
    end
    page.canvas:SetHeight(y + PAD)
end

local function RefreshPage(page)
    if not page.isBuilt then BuildRows(page) end
    ShowCopyHint(page, false)
    LayOutRows(page, page.scroll:GetWidth())
    ns.Settings.ScrollPageTo(page, page.offset)
end

-- The page, in the Settings page's place (MainFrame.lua's UI:BuildSettingsPage).
function HotfixPage.CreatePage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.rows, page.offset = {}, 0
    page.Refresh = RefreshPage
    local canvas = ns.Settings.AddScrolling(page)
    AddHeader(page, canvas)
    page.scroll:HookScript("OnSizeChanged", function(_, width)
        LayOutRows(page, width)
        ns.Settings.ScrollPageTo(page, page.offset)
    end)
    return page
end
