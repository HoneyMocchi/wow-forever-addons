-- The Professions tab's profession bar (Mike's layout G, 2026-11-18): across
-- the top of the body, over the filter sidebar, the recipe list and the
-- recipe page, a badge for every profession list (Camping too) in the order
-- the profession list keeps (ns.UI.KnownProfessionsFirst): the character's
-- primary professions, its secondary ones, a thin divider, then the rest.
-- A badge is the profession's round icon, its name under it and, for one
-- the character has, its skill ("87/150"). The badges share the bar's
-- width evenly; a name too long for its badge shrinks a little, then is cut
-- short. A click opens the profession as a click on its row in the list
-- did; the badge of the profession open is ringed and underlined in gold.
local _, ns = ...
local Theme = ns.Theme
local L = ns.L

local BADGE = {
    ICON = 30,              -- the ring round the icon; the icon fills its middle
    ICON_INSET = 1,         -- the icon in from the ring's edge, each side
    TOP = 6,                -- the ring, down from the bar's top
    NAME_GAP = 2,           -- between the ring and the name
    UNDERLINE_GAP = 3,      -- between the skill line and the open profession's underline
    UNDERLINE_HEIGHT = 2,
    UNDERLINE_WIDTH = 40,   -- at most; never wider than the badge less UNDERLINE_MARGIN each side
    UNDERLINE_MARGIN = 4,
    BOTTOM = 4,             -- under the underline
    SIDE_ROOM = 2,          -- a name kept this far in from its badge's sides
    SKILL_SCALE = 0.9,      -- the skill line: `small` at this size
    NAME_SHRINK_STEP = 0.05, -- a name too long shrinks in steps of this
    NAME_MIN_SCALE = 0.8,   -- to this at the most, then is cut short
}
local BAR_INSET = 6         -- the badges in from the bar's sides
local DIVIDER_ROOM = 13     -- the room the line between the learned professions and the rest takes
local DIVIDER_INSET = 10    -- that line's ends in from the bar's top and bottom
-- The ring's art, desaturated, as the list headers' discs (UI/Lists.lua):
-- tinted `discRing` gold on the open profession, else grey.
local RING_ATLAS = "Mode-Selection-Ring-c60"
local RING_GREY, RING_HOVER = 0.35, 0.7  -- the grey ring's alpha, and under the mouse
local SKILL_FORMAT = "%d/%d"  -- a learned profession's skill under its name
local NO_PROFESSIONS = {}  -- the bar's list before SetData gives it one

-- The badge's tooltip: the profession's name, the character's skill in it
-- (or "Not learned"; nothing for Camping, which no one learns) and how
-- many recipes it lists.
local function ShowBadgeTooltip(badge)
    local profession = badge.profession
    GameTooltip:SetOwner(badge, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(profession.name, unpack(Theme.tip.title))
    local rank, maxRank = ns.UI.SkillRanks(profession)
    if rank then
        GameTooltip:AddLine(L["Skill %d/%d"]:format(rank, maxRank), unpack(Theme.tip.text))
    elseif ns.UI.HasSkillLine(profession) then
        GameTooltip:AddLine(L["Not learned"], unpack(Theme.tip.quiet))
    end
    local recipes = ns.RecipeBand.RecipeCount(profession)
    if recipes > 0 then GameTooltip:AddLine(L["%d recipes"]:format(recipes), unpack(Theme.tip.info)) end
    GameTooltip:Show()
end

-- The open profession's badge: its ring `discRing` gold, its name in
-- `heading` and its underline shown. Any other: a grey ring (lighter under
-- the mouse), its name in `muted` when the character hasn't learned it,
-- else `text`.
local function PaintBadge(badge)
    local colors = Theme.color
    local nameColor = badge.isOpen and colors.heading or badge.isNotLearned and colors.muted or colors.text
    Theme:SetTextColor(badge.name, nameColor)
    if badge.isOpen then
        local r, g, b = unpack(colors.discRing)
        badge.ring:SetVertexColor(r, g, b, 1)
    else
        badge.ring:SetVertexColor(1, 1, 1, badge.hover and RING_HOVER or RING_GREY)
    end
    badge.underline:SetShown(badge.isOpen)
end

local function CreateBadge(bar)
    local badge = CreateFrame("Button", nil, bar)
    badge.disc = CreateFrame("Frame", nil, badge)
    badge.disc:SetSize(BADGE.ICON, BADGE.ICON)
    badge.disc:SetPoint("TOP", 0, -BADGE.TOP)
    badge.icon = badge.disc:CreateTexture(nil, "ARTWORK", nil, 0)
    badge.icon:SetPoint("CENTER")
    local iconSize = BADGE.ICON - BADGE.ICON_INSET * 2
    badge.icon:SetSize(iconSize, iconSize)
    Theme:CropIcon(badge.icon)
    Theme:MaskRound(badge.disc, badge.icon)
    badge.ring = badge.disc:CreateTexture(nil, "ARTWORK", nil, 2)
    badge.ring:SetPoint("CENTER")
    Theme:FitAtlas(badge.ring, RING_ATLAS, BADGE.ICON)
    badge.ring:SetDesaturated(true)
    badge.name = Theme:Text(badge, Theme.font.small)
    badge.name:SetJustifyH("CENTER")
    badge.skill = Theme:Text(badge, Theme:ScaledFont(Theme.font.small, BADGE.SKILL_SCALE))
    badge.skill:SetJustifyH("CENTER")
    Theme:SetTextColor(badge.skill, Theme.color.muted)
    badge.underline = badge:CreateTexture(nil, "ARTWORK")
    badge.underline:SetColorTexture(unpack(Theme.color.heading))
    badge.underline:SetHeight(BADGE.UNDERLINE_HEIGHT)
    badge.underline:SetPoint("BOTTOM", 0, BADGE.BOTTOM)
    badge:SetScript("OnEnter", function(self)
        self.hover = true
        PaintBadge(self)
        ShowBadgeTooltip(self)
    end)
    badge:SetScript("OnLeave", function(self)
        self.hover = nil
        PaintBadge(self)
        GameTooltip:Hide()
    end)
    -- As a click on the profession's row in the list: a new Back trail.
    badge:SetScript("OnClick", function(self)
        ns.UI:ClearHistory()
        ns.UI:SelectInstance(self.profession)
    end)
    return badge
end

-- Sets the badge's name in `small`, shrunk in NAME_SHRINK_STEPs (to
-- NAME_MIN_SCALE at the most) when it is wider than `room`, then cut short
-- at `room` if it still doesn't fit. The steps keep the scaled fonts made
-- few, however the window is resized.
local function FitName(badge, text, room)
    local name = badge.name
    name:SetFontObject(Theme.font.small)
    name:SetText(text)
    local width = name:GetUnboundedStringWidth()
    if width > room then
        local steps = math.floor(room / width / BADGE.NAME_SHRINK_STEP)
        local scale = math.max(BADGE.NAME_MIN_SCALE, steps * BADGE.NAME_SHRINK_STEP)
        name:SetFontObject(Theme:ScaledFont(Theme.font.small, scale))
    end
    name:SetWidth(room)
end

-- Places `badge` `x` in from the bar's left, `width` wide and the bar's
-- height, and shows `profession` on it.
local function ShowBadge(bar, badge, profession, x, width)
    badge:ClearAllPoints()
    badge:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
    badge:SetSize(width, bar:GetHeight())
    badge.profession = profession
    badge.icon:SetTexture(ns.UI.ProfessionIcon(profession.id))
    local rank, maxRank = ns.UI.SkillRanks(profession)
    badge.isNotLearned = rank == nil and ns.UI.HasSkillLine(profession)
    -- Fixed lines under the ring, so a shrunk name sits in the middle of its own.
    local nameTop = BADGE.TOP + BADGE.ICON + BADGE.NAME_GAP
    FitName(badge, profession.name, width - BADGE.SIDE_ROOM * 2)
    badge.name:ClearAllPoints()
    badge.name:SetPoint("CENTER", badge, "TOP", 0, -(nameTop + bar.nameHeight / 2))
    badge.skill:ClearAllPoints()
    badge.skill:SetPoint("TOP", badge, "TOP", 0, -(nameTop + bar.nameHeight))
    badge.skill:SetText(rank and SKILL_FORMAT:format(rank, maxRank) or "")
    badge.underline:SetWidth(math.min(BADGE.UNDERLINE_WIDTH, width - BADGE.UNDERLINE_MARGIN * 2))
    badge:Show()
end

-- The thin line between the learned professions and the rest, centred in
-- the DIVIDER_ROOM that starts `x` in from the bar's left.
local function PlaceDivider(bar, x)
    local divider = bar.divider
    divider:ClearAllPoints()
    divider:SetPoint("TOP", bar, "TOPLEFT", math.floor(x + DIVIDER_ROOM / 2), -DIVIDER_INSET)
    divider:SetPoint("BOTTOM", bar, "BOTTOMLEFT", math.floor(x + DIVIDER_ROOM / 2), DIVIDER_INSET)
    divider:Show()
end

-- The bar on `parent`, as tall as its badges; the caller places its sides.
-- bar:SetData(professions) shows the profession lists, bar:Paint() marks
-- the one open (ns.UI.state.instance).
function ns.UI.CreateProfessionBar(parent)
    local bar = Theme:CreatePanel(parent, "list")
    bar.badges = {}
    bar.professions, bar.learnedCount = NO_PROFESSIONS, 0
    bar.divider = bar:CreateTexture(nil, "ARTWORK")
    bar.divider:SetColorTexture(unpack(Theme.color.line))
    bar.divider:SetWidth(1)
    bar.divider:Hide()
    -- Its height follows the name's and skill's lines (Theme:LineHeight).
    local measure = Theme:Text(bar, Theme.font.small)
    bar.nameHeight = Theme:LineHeight(measure)
    measure:SetFontObject(Theme:ScaledFont(Theme.font.small, BADGE.SKILL_SCALE))
    local skillHeight = Theme:LineHeight(measure)
    measure:Hide()
    bar:SetHeight(BADGE.TOP + BADGE.ICON + BADGE.NAME_GAP + bar.nameHeight + skillHeight + BADGE.UNDERLINE_GAP
        + BADGE.UNDERLINE_HEIGHT + BADGE.BOTTOM)

    -- The badges, evenly across the bar, the divider after the learned ones
    -- (none when every profession, or none, is learned).
    function bar:Layout()
        local professions, learnedCount = self.professions, self.learnedCount
        local hasDivider = learnedCount > 0 and learnedCount < #professions
        local room = self:GetWidth() - BAR_INSET * 2 - (hasDivider and DIVIDER_ROOM or 0)
        local badgeWidth = #professions > 0 and math.max(0, room) / #professions or 0
        local x = BAR_INSET
        for i, profession in ipairs(professions) do
            if hasDivider and i == learnedCount + 1 then
                PlaceDivider(self, x)
                x = x + DIVIDER_ROOM
            end
            local badge = self.badges[i] or CreateBadge(self)
            self.badges[i] = badge
            ShowBadge(self, badge, profession, math.floor(x + 0.5), math.floor(badgeWidth))
            x = x + badgeWidth
        end
        for i = #professions + 1, #self.badges do self.badges[i]:Hide() end
        self.divider:SetShown(hasDivider)
        self:Paint()
    end

    -- `professions`, the Professions tab's lists, in the profession list's order.
    function bar:SetData(professions)
        self.given, self.needsLayout = professions, nil
        self.professions, self.learnedCount = ns.UI.KnownProfessionsFirst(professions)
        self:Layout()
    end

    function bar:Paint()
        local open = ns.UI.state.instance
        for _, badge in ipairs(self.badges) do
            badge.isOpen = badge.profession == open
            if badge:IsShown() then PaintBadge(badge) end
        end
    end

    bar:HookScript("OnSizeChanged", function(self) self:Layout() end)
    bar:HookScript("OnShow", function(self)
        if self.needsLayout then self:SetData(self.given) end
    end)
    return bar
end

-- A profession learned or unlearned moves to its side of the divider, and a
-- skill-up changes the number under its name: the bar is laid out again,
-- at once while it shows, else as it next shows. The event also comes with
-- every weapon and defense skill-up, often in combat, with the bar hidden.
ns:On("SKILL_LINES_CHANGED", function()
    local bar = ns.UI.professionBar
    if not (bar and bar.given) then return end
    if bar:IsVisible() then
        bar:SetData(bar.given)
    else
        bar.needsLayout = true
    end
end)
