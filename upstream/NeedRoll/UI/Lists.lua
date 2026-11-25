-- The two left-hand columns: instances in the active category, and the
-- encounters of the selected instance. Both are pooled, wheel-scrolled lists.
local _, ns = ...
local Theme = ns.Theme
local Size = Theme.size
local L = ns.L

local LABEL_HEIGHT = Size.paneLabel
local LABEL_Y = -(LABEL_HEIGHT / 2 - 4)  -- the pane label's top, about centred in its strip
local LIST_TOP = LABEL_HEIGHT + 4
local LABEL_ICON = 26     -- an icon left of the pane label, sized to the strip
local LABEL_ICON_GAP = 6
-- The lists' row heights, in one table so CreateEncounterList holds them as
-- one upvalue (see the note above that function).
local ROW = {
    NOTE = 40,       -- a row whose note line has text
    GROUP = 40,      -- a group's header row (Classic Raids, Quests, Encounters) and the Overview row
    MARKER = 22,     -- a line across the list ("Level 30", "Other classes")
    CHILD = 24,      -- a quest or encounter under a group's header
    CHILD_NOTE = 36, -- the same with a note line
    OR = 16,         -- the "or" between a questline's alternatives
}
local SLIDE_SECONDS = 0.2 -- to slide a group open or shut

local function IndexOf(list, value)
    for index, listed in ipairs(list) do
        if listed == value then return index end
    end
end

-- Eases a slide's progress (0 to 1) in and out.
local function Smooth(progress) return progress * progress * (3 - 2 * progress) end

-- Ends a group's slide where it is.
local function StopSlide(pane)
    pane.anim, pane.slide = nil, nil
    pane:SetScript("OnUpdate", nil)
end

-- Slides a group open or shut, in either list. pane:Rebuild() lists the
-- group's rows and adds their heights up into `anim.total`; the rows that
-- `isMember(entry)` then show through a strip (pane.slide) that grows from
-- nothing to that height, or shrinks back to nothing, and the rows below
-- move with its edge.
local function StartSlide(pane, anim, isMember, opening)
    local start = GetTime()
    pane.anim = anim
    pane:Rebuild()
    pane.slide = { member = isMember, height = opening and 0 or anim.total }
    pane:Refresh()
    pane:SetScript("OnUpdate", function()
        local progress = math.min(1, (GetTime() - start) / SLIDE_SECONDS)
        if progress >= 1 then
            StopSlide(pane)
            pane:Rebuild()
            return
        end
        -- Whole units, so the text below moves without shimmering.
        pane.slide.height = math.floor(anim.total * Smooth(opening and progress or 1 - progress) + 0.5)
        pane:Refresh()
    end)
end

-- Builds a list pane. `opts.label`, `opts.rowHeight`, `opts.entryHeight(entry)`
-- (required; it returns nil for rowHeight), `opts.setupRow(row, entry)`,
-- `opts.isSelected(entry)`, `opts.onClick(entry)`, and
-- `opts.onRightClick(entry, row)` when right-clicks on rows do something.
-- `opts.subtitle` adds a second line under the title (row.sub), `opts.note`
-- a smaller one (row.note), `opts.right` a figure at the right (row.right)
-- and `opts.suffix` smaller text right after the title (row.suffix).
-- `opts.rowInset(entry)` narrows an entry's row; `opts.afterRow(row, entry)`
-- runs after each row is drawn and `opts.afterRefresh()` after each redraw,
-- rows placed (row.top: a row's top, down from the first row's).
local function CreateList(parent, opts)
    local pane = Theme:CreatePanel(parent, "list")

    -- Hairline under the pane label, like a panel header.
    local rule = pane:CreateTexture(nil, "BORDER")
    rule:SetColorTexture(unpack(Theme.color.line))
    rule:SetPoint("TOPLEFT", 1, -LABEL_HEIGHT)
    rule:SetPoint("TOPRIGHT", -1, -LABEL_HEIGHT)
    rule:SetHeight(1)
    pane.rule = rule

    local label = Theme:Text(pane, Theme.font.pane)
    label:SetPoint("TOPLEFT", Size.pad, LABEL_Y)
    label:SetText(Theme:Label(opts.label))
    pane.label = label

    -- Optional icon left of the label (the Dungeons and Raids portals).
    local labelIcon = pane:CreateTexture(nil, "ARTWORK")
    labelIcon:SetPoint("RIGHT", label, "LEFT", -LABEL_ICON_GAP, 0)
    labelIcon:Hide()
    pane.labelIcon = labelIcon

    -- Shows `atlas` left of the label, or no icon when nil; `size` replaces
    -- LABEL_ICON for art with empty space around it.
    function pane:SetLabelIcon(atlas, size)
        local x = Size.pad
        if atlas then
            Theme:FitAtlas(self.labelIcon, atlas, size or LABEL_ICON)
            x = x + self.labelIcon:GetWidth() + LABEL_ICON_GAP
        end
        self.labelIcon:SetShown(atlas ~= nil)
        self.label:ClearAllPoints()
        self.label:SetPoint("TOPLEFT", x, LABEL_Y)
    end

    -- From the pane's left edge to the end of its label, icon included.
    function pane:LabelRight()
        local x = Size.pad + self.label:GetStringWidth()
        if self.labelIcon:IsShown() then x = x + self.labelIcon:GetWidth() + LABEL_ICON_GAP end
        return x
    end

    pane.rows = {}
    pane.entries = {}
    -- Rows live on a canvas clipped to the list area, so a row gliding past
    -- the top or bottom edge is cut off there, inside the pane's border.
    local canvas = Theme:ScrollView(pane, LIST_TOP, Size.scrollBottom)
    pane.canvas = canvas

    pane.rowHeight = opts.rowHeight
    pane.listTop = LIST_TOP  -- where the first row starts; less when the label is hidden

    -- Names too long for the row wrap onto a second line, and that row grows
    -- by a line: entry -> the extra height, found as rows are drawn.
    local wraps, wrapWidth = {}, nil

    -- An entry's height as drawn, a wrapped title's extra line included.
    function pane:EntryHeight(entry)
        return (opts.entryHeight(entry) or self.rowHeight) + (wraps[entry] or 0)
    end

    -- The list's height, below its label.
    local function Room()
        return pane:GetHeight() - pane.listTop - Size.scrollBottom
    end

    -- How many entries, from `first` to `last` (`step` 1 or -1), fit in the list.
    local function CountFitting(first, last, step)
        local room, used, count = Room(), 0, 0
        for i = first, last, step do
            used = used + pane:EntryHeight(pane.entries[i])
            if used > room then break end
            count = count + 1
        end
        return count
    end

    -- Largest offset that still fills the pane: the last entries that fit.
    local function MaxOffset()
        return math.max(0, #pane.entries - math.max(1, CountFitting(#pane.entries, 1, -1)))
    end

    -- Rows sliding in or out sit in this clipped strip, laid out whole; the
    -- strip grows or shrinks and the rows below it move with its edge.
    local drawer = CreateFrame("Frame", nil, canvas)
    drawer:SetClipsChildren(true)
    drawer:SetPoint("RIGHT")

    -- `inset` pulls the row in from both sides (opts.rowInset), its text
    -- staying where it was.
    local function Place(row, y, height, inset)
        row.top, row.inset = y, inset or 0
        row:SetHeight(height)
        row:SetPoint("TOPLEFT", pane, "TOPLEFT", 1 + row.inset, -pane.listTop - y)
        row:SetPoint("RIGHT", pane, "RIGHT", -1 - row.inset, 0)
    end

    -- Width of the last line `text` takes when wrapped at `width`, so a
    -- suffix can follow it.
    local measure = pane:CreateFontString(nil, "OVERLAY")
    measure:Hide()
    local function LastLineWidth(fontString, text, width)
        measure:SetFontObject(fontString:GetFontObject())
        local line = ""
        for word in text:gmatch("%S+") do
            local longer = line == "" and word or line .. " " .. word
            measure:SetText(longer)
            if line ~= "" and measure:GetUnboundedStringWidth() > width then line = word else line = longer end
        end
        measure:SetText(line)
        return measure:GetUnboundedStringWidth()
    end

    -- The width a title anchored at both sides has. When both anchors are
    -- on the row it comes from them and the pane's width: the title's drawn
    -- edges are stale while the window is being resized, and a title read
    -- as having no room took a second line and disappeared.
    local function TitleRoom(row)
        local title = row.title
        local left, right
        for i = 1, title:GetNumPoints() do
            local point, relativeTo, _, x = title:GetPoint(i)
            if relativeTo == row and point == "LEFT" then left = x end
            if relativeTo == row and point == "RIGHT" then right = -x end
        end
        -- A title stopping at icons on the row (a quest's crests) has their
        -- width added up as titleReserve, since its drawn edges can be from
        -- before the row moved (into the active section's card).
        right = right or row.titleReserve
        if left and right then
            return pane:GetWidth() - 2 - (row.inset or 0) * 2 - left - right
        end
        -- Anchored to something else on the row (a figure at its right).
        local titleLeft, titleRight = title:GetLeft(), title:GetRight()
        return titleLeft and titleRight and titleRight - titleLeft or title:GetUnboundedStringWidth()
    end

    -- A title with a suffix after it: sized to the text, or wrapped onto a
    -- second line with the suffix following that line. Returns whether it wraps.
    local function WrapBesideSuffix(row)
        local title, suffix = row.title, row.suffix
        local full = title:GetUnboundedStringWidth()
        local room = row:GetWidth() - Size.pad * 2 - (row.indent or 0) - (row.rightWidth or 0)
        local suffixWidth = suffix:GetStringWidth()
        local besideRoom = room - (suffixWidth > 0 and suffixWidth + 4 or 0)
        local wrap = full > besideRoom + 0.5
        title:SetWidth(math.max(1, wrap and room or full))
        title:SetWordWrap(wrap)
        title:SetMaxLines(wrap and 2 or 1)
        suffix:ClearAllPoints()
        if not wrap then
            suffix:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 4, 1)
            return false
        end
        -- The suffix follows the name's last line; when that line is too
        -- full, wrap a little narrower to leave it room.
        local text = title:GetText() or ""
        local last = LastLineWidth(title, text, room)
        if last + 4 + suffixWidth > room then
            title:SetWidth(math.max(1, besideRoom))
            last = LastLineWidth(title, text, besideRoom)
        end
        suffix:SetPoint("BOTTOMLEFT", title, "BOTTOMLEFT", last + 4, 1)
        return true
    end

    -- Lets the title take a second line when it doesn't fit, and returns the
    -- height that line adds (0 when one line is enough).
    local function FitTitle(row)
        local title = row.title
        local wrap
        if row.suffix then
            wrap = WrapBesideSuffix(row)
        else
            wrap = title:GetUnboundedStringWidth() > TitleRoom(row) + 0.5
            title:SetWordWrap(wrap)
            title:SetMaxLines(wrap and 2 or 1)
        end
        if not wrap then return 0 end
        local _, size = title:GetFont()
        return math.ceil((size or 12) + 2)
    end

    local function NewRow()
        local row = Theme:Row(canvas, pane.rowHeight)
        row.title = Theme:Text(row, Theme.font.body)
        row.title:SetPoint("LEFT", Size.pad, opts.subtitle and 6 or 0)
        if opts.right then
            -- Right-aligned figure, such as a recipe's skill level.
            row.right = Theme:Text(row, Theme.font.small)
            row.right:SetPoint("RIGHT", -Size.pad, 0)
            row.title:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
        elseif opts.suffix then
            -- Smaller text right after the title; Refresh sizes the title to leave room.
            row.suffix = Theme:Text(row, Theme.font.suffix)
            row.suffix:SetPoint("BOTTOMLEFT", row.title, "BOTTOMRIGHT", 4, 1)
        else
            row.title:SetPoint("RIGHT", -Size.pad, 0)
        end
        row.title:SetJustifyH("LEFT")
        if opts.subtitle then
            row.sub = Theme:Text(row, Theme.font.small)
            row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
        end
        if opts.note then
            row.note = Theme:Text(row, Theme.font.note)
            row.note:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
            row.note:SetJustifyH("LEFT")
        end
        if opts.onRightClick then
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.takesRightClicks = true -- its icons pass right-clicks on too (ns.UI.ClicksReachBeneath)
        end
        row:SetScript("OnClick", function(self, button)
            if button ~= "RightButton" then
                opts.onClick(self.entry)
            elseif opts.onRightClick then
                opts.onRightClick(self.entry, self)
            end
        end)
        table.insert(pane.rows, row)
        return row
    end

    -- Rows keep the entries they show when those are still near the top
    -- (from `first` on); the other rows are free for entries coming into
    -- view. Returns the function that hands out a row for an entry, and
    -- the rows it has handed out (taken[row] == "used").
    local function ClaimRows(first)
        local held, taken, free = {}, {}, {}
        for _, row in ipairs(pane.rows) do
            if row:IsShown() and row.entry then held[row.entry] = row end
        end
        for index = first, math.min(#pane.entries, first + #pane.rows) do
            local row = held[pane.entries[index]]
            if row then taken[row] = true end
        end
        for _, row in ipairs(pane.rows) do
            if not taken[row] then table.insert(free, row) end
        end
        local function RowFor(entry)
            local row = held[entry]
            if row and taken[row] ~= "used" then
                taken[row] = "used"
                return row
            end
            row = table.remove(free) or NewRow()
            taken[row] = "used"
            row.stamp = nil
            return row
        end
        return RowFor, taken
    end

    -- Fills `row` for `entry`. Returns true when the title's wrapping
    -- changed the row's height, so the list needs laying out again.
    local function DrawRow(row, entry)
        opts.setupRow(row, entry)
        if row.note then
            -- A note sits under the title, so the title moves up to make room.
            local text = row.note:GetText()
            local noteLift = text and text ~= "" and 6 or 0
            row.title:SetPoint("LEFT", Size.pad + (row.indent or 0) - row.inset, noteLift)
            if row.right then row.title:SetPoint("RIGHT", row.right, "LEFT", -6, noteLift) end
            row.note:SetShown(noteLift > 0)
        end
        local selected = opts.isSelected(entry)
        row:SetSelected(selected)
        local textColor = selected and Theme.color.selectedText or Theme.color.text
        Theme:SetTextColor(row.title, textColor)
        if row.suffix then Theme:SetTextColor(row.suffix, textColor) end
        local extra = FitTitle(row)
        local heightChanged = (wraps[entry] or 0) ~= extra
        if heightChanged then wraps[entry] = extra > 0 and extra or nil end
        if opts.afterRow then opts.afterRow(row, entry) end
        row:Show()
        return heightChanged
    end

    -- Each full redraw gets a new stamp. A row drawn under the current one
    -- is up to date, so while the list only scrolls it just moves.
    local stamp = 0

    -- `pane.slide = { member = fn(entry), height = n }` while some rows slide:
    -- those rows show through a strip `height` tall instead of at full size.
    -- `scrolling` (true) when only the scroll position changed: an entry
    -- that stays on screen keeps its row as drawn and the row just moves, so
    -- a glide sets up only the rows coming into view.
    function pane:Refresh(scrolling)
        scrolling = scrolling == true and not self.slide
        if not scrolling then stamp = stamp + 1 end
        local width = self:GetWidth()
        if width ~= wrapWidth then wipe(wraps); wrapWidth = width end
        canvas:SetTop(self.listTop)
        -- Mid-glide the first row sits partly above the top edge.
        local first, lift = Theme:ScrollStart(self.offset, function(i)
            return self.entries[i] and self:EntryHeight(self.entries[i]) or 0
        end)
        local RowFor, taken = ClaimRows(first)
        local room, y, shown, used = Room(), -lift, 0, 0
        local slide, slideTop, slideY = self.slide, nil, 0
        local refit = false
        for index = first, #self.entries do
            local entry = self.entries[index]
            local height = self:EntryHeight(entry)
            local sliding = slide and slide.member(entry)
            if slideTop and not sliding then
                -- Past the strip: the rows below follow its edge.
                y, slideTop = slideTop + slide.height, nil
            end
            local top = y
            if sliding then
                if not slideTop then
                    slideTop, slideY = y, 0
                    drawer:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -self.listTop - y)
                    drawer:SetHeight(math.max(slide.height, 0.01))
                end
                top = slideTop + slideY
                slideY = slideY + height
            end
            -- A row cut off by the bottom edge still shows the part that fits.
            if used > 0 and top >= room then break end
            shown = index - self.offset
            -- Rows still wholly hidden in the strip need no row.
            if not (sliding and top - slideTop >= slide.height) then
                used = used + 1
                local row = RowFor(entry)
                local rowParent = sliding and drawer or canvas
                if row:GetParent() ~= rowParent then row:SetParent(rowParent) end
                row.entry = entry
                Place(row, top, height, opts.rowInset and opts.rowInset(entry))
                if scrolling and row.stamp == stamp then
                    -- Drawn already: only its place changed.
                    row:Show()
                else
                    row.stamp = stamp
                    -- A sliding row fades in as the strip's edge passes over it
                    -- (and out as the edge passes back).
                    row:SetAlpha(sliding and math.min(1, (slideTop + slide.height - top) / height) or 1)
                    refit = DrawRow(row, entry) or refit
                end
            end
            if not sliding then y = y + height end
        end
        for _, row in ipairs(self.rows) do
            if taken[row] ~= "used" then
                row:Hide()
                row.entry = nil
            end
        end
        -- A row's height changed: lay the list out again with the new heights.
        -- (Rows the new heights bring into view may need a pass of their own.)
        local depth = self.refitting or 0
        if refit and depth < 3 then
            self.refitting = depth + 1
            self:Refresh(scrolling)
            self.refitting = depth
            return
        end
        if opts.afterRefresh then opts.afterRefresh() end
        self.scrollBar:Update(self.offset, MaxOffset(), shown)
        ns.UI:UpdateLink()
    end

    -- Compact rows: one line, no subtitle, so a short list fits unscrolled.
    function pane:SetCompact(on)
        if self.compact == on then return end
        self.compact = on
        -- Compact rows (the profession list) are 1.15x a normal row, for visibility.
        self.rowHeight = on and math.floor(Size.row * 1.15 + 0.5) or opts.rowHeight
        self:Refresh()
    end

    function pane:GetSelectedRow()
        for _, row in ipairs(self.rows) do
            if row.isSelected and row:IsShown() then return row end
        end
    end

    function pane:SetData(entries)
        self.entries = entries or {}
        self.offset = 0
        self:Refresh()
    end

    -- Scrolls so `entry` is in view, near the middle when it wasn't.
    function pane:ScrollTo(entry)
        local index = IndexOf(self.entries, entry)
        if not index then return end
        local visible = math.max(1, CountFitting(math.floor(self.offset) + 1, #self.entries, 1))
        if index > self.offset and index <= self.offset + visible then return end
        self.offset = math.min(MaxOffset(), math.max(0, index - math.ceil(visible / 2)))
        self:Refresh()
    end

    Theme:WheelScroll(pane, MaxOffset, function(scrolling) pane:Refresh(scrolling) end)
    pane.scrollBar = Theme:ScrollBar(pane, LIST_TOP + 4, 6, function(offset)
        pane.offset = offset
        pane:Refresh(true)
    end)
    pane:SetScript("OnSizeChanged", pane.Refresh)
    return pane
end

-- Each profession's icon: its skill spell's icon, else the icon file
-- (client art, nothing bundled), masked round so its square border is gone.
local PROFESSION_ICONS = {
    ALCHEMY = { 2259, "Trade_Alchemy" },
    BLACKSMITHING = { 2018, "Trade_BlackSmithing" },
    COOKING = { 2550, "INV_Misc_Food_15" },
    ENCHANTING = { 7411, "Trade_Engraving" },
    ENGINEERING = { 4036, "Trade_Engineering" },
    FIRST_AID = { 3273, "Spell_Holy_SealOfSacrifice" },
    FISHING = { 7620, "Trade_Fishing" },
    HERBALISM = { 2366, "Spell_Nature_NatureTouchGrow" },
    LEATHERWORKING = { 2108, "INV_Misc_ArmorKit_17" },
    MINING = { 2575, "Trade_Mining" },
    SKINNING = { 8613, "INV_Misc_Pelt_Wolf_01" },
    TAILORING = { 3908, "Trade_Tailoring" },
    CAMPING = { 818, "Spell_Fire_Fire" },  -- the Camping list: Basic Campfire
}
local LIST_ICON = 21  -- a profession's or currency's icon left of its name: 1.15x the first size, for visibility
ns.UI.professionIcons = PROFESSION_ICONS  -- /nr icondebug shows them too

local function ProfessionIcon(id)
    local icon = PROFESSION_ICONS[id]
    if not icon then return nil end
    return C_Spell.GetSpellTexture(icon[1]) or [[Interface\Icons\]] .. icon[2]
end
ns.UI.ProfessionIcon = ProfessionIcon  -- the profession bar, and the Scarce reagent page's source cells

-- A currency's icon (the Tarnished Undermine Real's list on the Collections
-- tab), else the coin icon file it uses, should the game not answer for it.
local CURRENCY_FALLBACK_ICON = [[Interface\Icons\INV_Misc_Coin_16]]
local function CurrencyIcon(currencyID)
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    return info and info.iconFileID or CURRENCY_FALLBACK_ICON
end

-- The icon shown left of a list's name in the left column, or nil for none.
local function ListIcon(instance)
    if instance.category == "PROFESSION" then return ProfessionIcon(instance.id) end
    if instance.currencyID then return CurrencyIcon(instance.currencyID) end
    return nil
end

-- What a recipe makes, in the recipe list (the Professions Icons module):
-- the item's icon masked round inside the client's greyed mode ring, with
-- the item's tooltip on hover. Clicks pass through to the row under it.
local RECIPE_RING = "Mode-Selection-Ring-Disable-c60"
local RECIPE_ICON = 24   -- the ring; the item fills its middle
local RECIPE_GAP = 6     -- between the ring and the name
local QUESTION_ICON = 134400  -- the question mark icon, for a recipe with nothing to show

function ns.UI.RecipeIcon(parent, size)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(size, size)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetPoint("CENTER")
    local inner = math.floor(size * 0.72 + 0.5)
    icon.tex:SetSize(inner, inner)
    Theme:CropIcon(icon.tex)
    Theme:MaskRound(icon, icon.tex)
    icon.ring = icon:CreateTexture(nil, "ARTWORK", nil, 2)
    icon.ring:SetPoint("CENTER")
    Theme:FitAtlas(icon.ring, RECIPE_RING, size)
    icon:EnableMouse(true)
    ns.UI.ClicksReachBeneath(icon)
    icon:SetScript("OnEnter", function(self)
        if parent.hover and not parent.isSelected then parent.hover:Show() end -- still over the row
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.itemID then
            GameTooltip:SetItemByID(self.itemID)
        elseif self.spellID then
            GameTooltip:SetSpellByID(self.spellID)
        end
        GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function()
        if parent.hover then parent.hover:Hide() end
        GameTooltip:Hide()
    end)
    -- The item it shows, or a spell's icon (an enchant makes no item).
    function icon:SetItem(itemID, spellID)
        self.itemID, self.spellID = itemID, spellID
        local file = itemID and C_Item.GetItemIconByID(itemID)
            or spellID and C_Spell.GetSpellTexture(spellID)
        self.tex:SetTexture(file or QUESTION_ICON)
    end
    function icon:SetDesaturated(on)
        self.tex:SetDesaturated(on)
    end
    return icon
end

-- What a recipe row's icon shows: the item it makes, else its spell.
local function RecipeProduct(encounter)
    local made = encounter.loot and encounter.loot[1]
    if made and made.itemID and not made.recipe then return made.itemID end
    return nil, encounter.spellID
end
ns.UI.RecipeProduct = RecipeProduct  -- the recipe list's slot chips (UI/RecipeBand.lua)

-- Whether `entry`, a row of `instance`'s list, shows what it makes (the
-- Professions Icons module): the item, or else the spell, and the item or
-- spell to show.
local function RecipeIconFor(entry, instance)
    if entry.header or entry.overview or entry.wingHeader or entry.marker or entry.quest
        or not instance or instance.category ~= "PROFESSION" or not ns.Modules:IsOn("PROFESSION_ICONS") then
        return false
    end
    local item, spell = RecipeProduct(entry)
    return item ~= nil or spell ~= nil, item, spell
end

-- Raids not confirmed in WoW: Forever yet fold into "Classic Raids" at the
-- end of the raid list. Its header row folds them away, shut until opened
-- (then kept as Settings' "Remember sections" says).
local CLASSIC_RAIDS = { MOLTEN_CORE = true, ZULGURUB = true, BWL = true, AQ20 = true, AQ40 = true, NAXXRAMAS = true }
local CLASSIC_HEADER = { header = true, name = L["Classic Raids"] }
local MEMBER_INDENT = 12  -- a member's name under Classic Raids

local function IsClassicRaid(instance)
    return instance.category == "RAID" and CLASSIC_RAIDS[instance.id] == true
end

-- Raids run in release order, smaller raids first within a patch. Raids
-- missing here (new in Forever) come after, smallest first.
local RAID_RELEASE = {
    ONYXIA = 1, MOLTEN_CORE = 1,  -- 1.0
    BWL = 2,                      -- 1.6
    ZULGURUB = 3,                 -- 1.7
    AQ20 = 4, AQ40 = 4,           -- 1.9
    NAXXRAMAS = 5,                -- 1.11
    HYJAL_SUMMIT = 6,             -- new in Forever
}

local function RaidOrder(a, b)
    local releaseA, releaseB = RAID_RELEASE[a.id] or math.huge, RAID_RELEASE[b.id] or math.huge
    if releaseA ~= releaseB then return releaseA < releaseB end
    local sizeA, sizeB = a.groupSize or 5, b.groupSize or 5
    if sizeA ~= sizeB then return sizeA < sizeB end
    return a.name < b.name
end

-- Dungeons run by level: the lowest first level first, then the lowest top
-- level, then by name, so dungeons with the same levels read alphabetically.
local function DungeonOrder(a, b)
    local levelsA, levelsB = a.levelRange, b.levelRange
    if levelsA[1] ~= levelsB[1] then return levelsA[1] < levelsB[1] end
    if levelsA[2] ~= levelsB[2] then return levelsA[2] < levelsB[2] end
    return a.name < b.name
end

-- How the Dungeons and Raids tabs sort their rows, by category. Other lists
-- keep the order their tab hands over.
local ORDER_BY_CATEGORY = { DUNGEON = DungeonOrder, RAID = RaidOrder }

-- Professions the character has learned lead the Professions list: their
-- primary professions (block 1), then their secondary ones (block 2), then
-- the rest (block 3) as the data files list them. Keyed by the list's ID,
-- which is the same in every language. Camping isn't a skill the character
-- learns, so it always stays with the rest.
local KNOWN_PROFESSION_BLOCK = {
    ALCHEMY = 1, BLACKSMITHING = 1, ENCHANTING = 1, ENGINEERING = 1, HERBALISM = 1, LEATHERWORKING = 1,
    MINING = 1, SKINNING = 1, TAILORING = 1,
    COOKING = 2, FIRST_AID = 2, FISHING = 2,
}
local UNKNOWN_PROFESSION_BLOCK = 3

local function ProfessionBlock(profession)
    local block = KNOWN_PROFESSION_BLOCK[profession.id]
    if not (block and ns.UI.SkillRank(profession)) then return UNKNOWN_PROFESSION_BLOCK end
    return block
end

-- A new list of `professions` in ProfessionBlock order, each block keeping
-- the order it had in `professions`, and how many lead it as learned (the
-- first two blocks).
local function KnownProfessionsFirst(professions)
    local blocks = {}
    for block = 1, UNKNOWN_PROFESSION_BLOCK do blocks[block] = {} end
    for _, profession in ipairs(professions) do table.insert(blocks[ProfessionBlock(profession)], profession) end
    local ordered = {}
    for _, block in ipairs(blocks) do
        for _, profession in ipairs(block) do table.insert(ordered, profession) end
    end
    return ordered, #ordered - #blocks[UNKNOWN_PROFESSION_BLOCK]
end
ns.UI.KnownProfessionsFirst = KnownProfessionsFirst  -- the profession bar's order (UI/ProfessionBar.lua)

-- Whether lists `a` and `b` hold the same entries in the same order.
local function SameOrder(a, b)
    if #a ~= #b then return false end
    for i, entry in ipairs(a) do
        if b[i] ~= entry then return false end
    end
    return true
end

-- A marker row's label centred between two lines, in the accent color: the
-- instance list's "Level N", the Quests group's "Other classes".
local function MarkerLine(row, text)
    if not row.marker then
        local marker = CreateFrame("Frame", nil, row)
        marker:SetAllPoints()
        marker.text = Theme:Text(marker, Theme.font.label)
        marker.text:SetPoint("CENTER", 0, 0)
        marker.left = marker:CreateTexture(nil, "ARTWORK")
        marker.left:SetPoint("LEFT", Size.pad, 0)
        marker.left:SetPoint("RIGHT", marker.text, "LEFT", -8, 0)
        marker.right = marker:CreateTexture(nil, "ARTWORK")
        marker.right:SetPoint("RIGHT", -Size.pad, 0)
        marker.right:SetPoint("LEFT", marker.text, "RIGHT", 8, 0)
        -- Centered one-pixel lines: when the row's middle falls on a pixel
        -- edge, snapping can round both edges to the same pixel and the line
        -- vanishes (it did with the list at the top). Unsnapped, the line
        -- always covers exactly one pixel row.
        for _, line in ipairs({ marker.left, marker.right }) do
            line:SetSnapToPixelGrid(false)
            line:SetTexelSnappingBias(0)
        end
        row.marker = marker
    end
    local marker = row.marker
    marker.text:SetText(text)
    Theme:SetTextColor(marker.text, Theme.color.accent)
    local _, pixel = Theme:LineWidth(marker)
    for _, line in ipairs({ marker.left, marker.right }) do
        line:SetColorTexture(unpack(Theme.color.accent))
        line:SetHeight(pixel)
    end
    marker:Show()
end

-- Dungeons and raids show their levels at the right of the name, colored
-- against your level, and dungeons get a "Level N" line where you fit.
local LEVEL_GAP = 8  -- between the name and the levels
-- Dungeon rows are one line (the name; the zone is on the Overview), so
-- more fit; raids keep their zone under the name.
local ONE_LINE_ROW = 30
-- The levels stop this far short of the right edge on every row, so they
-- line up down the list.
local ARROW_ROOM = 18
local NAME_ARROW_GAP = 6  -- a group's +/- follows its name

-- One-line rows: dungeons (and, sized by the list, the compact profession
-- rows).
local function OneLine(instance, compact)
    return compact or instance.category == "DUNGEON" or false
end

local function Leveled(instance)
    return instance.levelRange ~= nil and (instance.category == "DUNGEON" or instance.category == "RAID")
end

-- "19", or "60-62" for a range.
local function LevelText(minLevel, maxLevel)
    return minLevel == maxLevel and tostring(minLevel) or ("%d-%d"):format(minLevel, maxLevel)
end

-- The level colors' token for an instance spanning `minLevel`-`maxLevel`.
local function LevelColor(minLevel, maxLevel)
    local level = ns.PlayerLevel()
    if level > maxLevel + 4 then return Theme.color.levelTrivial end
    if level > maxLevel then return Theme.color.levelEasy end
    if level >= minLevel then return Theme.color.levelFair end
    if level >= minLevel - 3 then return Theme.color.levelHard end
    return Theme.color.levelImpossible
end

-- Shows `range` at the right of `row`, colored against your level, on the
-- name's line (`y`), and leaves the name room for it.
local function ShowLevels(row, range, y)
    local minLevel, maxLevel = range[1], range[2]
    if not row.levels then
        row.levels = Theme:Text(row, Theme.font.body)
        row.levels:SetJustifyH("RIGHT")
    end
    row.levels:ClearAllPoints()
    -- Raids keep room for the Classic Raids fold-out's toggle; dungeons,
    -- with no groups, run their levels to the edge.
    local room = row.levelRoom or 0
    row.levels:SetPoint("RIGHT", row, "RIGHT", -Size.pad - room, y)
    row.levels:SetText(LevelText(minLevel, maxLevel))
    Theme:SetTextColor(row.levels, LevelColor(minLevel, maxLevel))
    row.levels:Show()
    row.rightWidth = row.levels:GetStringWidth() + LEVEL_GAP + room
end

-- The Factions list shows the character's standing with each faction: the
-- standing's name at the right of the row's name, in the standing's colour,
-- and a slim bar under the zone filled through the standing in that colour.
-- A faction not met yet says "Not met" and has no bar; its row keeps the
-- same height, so nothing moves once it is met.
local STANDING = {
    BAR = 3,          -- the bar's height
    ROOM = 6,         -- what a faction's row grows by, for its bar
    BAR_GAP = 6,      -- from the zone's line down to the bar
}

local function ShowsStanding(instance)
    return instance.category == "FACTION"
end

-- What a row grows by for its standing bar: none outside the Factions tab.
local function StandingRoom(instance)
    if not ShowsStanding(instance) then return 0 end
    return STANDING.ROOM
end

-- A standing bar on `row`: a faint track and the fill along it, with round
-- ends in the skins with rounded corners. The native skin's are its own
-- see-through ones (Theme.nativeBar), as the Factions page's standing bar.
local function NewStandingBar(row)
    local bar = CreateFrame("Frame", nil, row)
    bar:SetHeight(STANDING.BAR)
    local function Piece(layer)
        if Theme.corners ~= "square" then return Theme:RoundedBarTexture(bar, layer, STANDING.BAR / 2) end
        local texture = bar:CreateTexture(nil, layer)
        texture:SetColorTexture(1, 1, 1, 1)
        return texture
    end
    bar.track = Piece("BACKGROUND")
    bar.track:SetAllPoints()
    bar.track:SetVertexColor(unpack(Theme.native and Theme.nativeBar.track or Theme.color.line))
    bar.fill = Piece("ARTWORK")
    bar.fill:SetPoint("TOPLEFT")
    bar.fill:SetPoint("BOTTOMLEFT")
    return bar
end

-- Shows `bar`, `width` long, filled through standing `reaction` as far as
-- `value` of `max` goes, in the standing's colour. The fill is at least as
-- long as the bar is high, so its colour shows at the very start of a standing.
local function FillStandingBar(bar, width, reaction, value, max)
    bar:SetWidth(width)
    bar.fill:SetWidth(math.max(width * ns.UI.StandingProgress(value, max), STANDING.BAR))
    local color = ns.UI.StandingColor(reaction) or Theme.color.accent
    bar.fill:SetVertexColor(color[1], color[2], color[3], Theme.native and Theme.nativeBar.fillAlpha or 1)
    bar:Show()
end

-- Writes the character's standing with `factionID` into `fontString`: its
-- name in its colour, or "Not met" in `faint`. Returns the standing.
local function WriteStanding(fontString, factionID)
    local reaction, value, max = ns.UI.Reputation(factionID)
    if not reaction then
        fontString:SetText(L["Not met"])
        Theme:SetTextColor(fontString, Theme.color.faint)
        return nil
    end
    fontString:SetText(ns.UI.StandingWord(reaction))
    Theme:SetTextColor(fontString, ns.UI.StandingColor(reaction) or Theme.color.text)
    return reaction, value, max
end

local function HideStanding(row)
    if row.standingWord then row.standingWord:Hide() end
    if row.standingBar then row.standingBar:Hide() end
end

-- A faction's row: its standing at the right of the name's line (`nameY`
-- up from the row's middle) and its bar under the zone, `width` long.
local function ShowFactionStanding(row, factionID, nameY, width)
    if not row.standingWord then row.standingWord = Theme:Text(row, Theme.font.small) end
    local word = row.standingWord
    word:ClearAllPoints()
    word:SetPoint("RIGHT", row, "RIGHT", -Size.pad, nameY)
    local reaction, value, max = WriteStanding(word, factionID)
    word:Show()
    row.rightWidth = word:GetStringWidth() + LEVEL_GAP
    if not reaction then return end
    if not row.standingBar then
        row.standingBar = NewStandingBar(row)
        row.standingBar:SetPoint("TOPLEFT", row.sub, "BOTTOMLEFT", 0, -STANDING.BAR_GAP)
    end
    FillStandingBar(row.standingBar, width, reaction, value, max)
end

-- Draws `instance`'s standing on its row (hidden by HideStanding), under a
-- name `nameY` up from the row's middle, its bar `width` long. Nothing
-- outside the Factions tab.
local function ShowStanding(row, instance, nameY, width)
    if not ShowsStanding(instance) then return end
    ShowFactionStanding(row, instance.factionID, nameY, width)
end

function ns.UI.CreateInstanceList(parent)
    local pane
    -- Whether Classic Raids is open, kept as Settings' "Remember sections"
    -- says (ns.SectionMemory's "instances" area, "CLASSIC_RAIDS").
    local groups = ns.SectionMemory.Area("instances")
    local function IsClassicOpen() return ns.SectionMemory.IsOpen(groups, "CLASSIC_RAIDS") end
    local function SetClassicOpen(isOpen) groups.CLASSIC_RAIDS = isOpen end
    local isMember = {}  -- a Classic Raids member on show -> true

    -- Classic Raids' members, while open, sit on a panel that fades from
    -- dark at the left to clear at the right (like the Overview stat boxes),
    -- with a tree line down its left edge and a tick to each member.
    local function StyleMember(row, instance)
        if not isMember[instance] then
            if row.wing then
                row.wing:Hide(); row.trunk:Hide(); row.tick:Hide()
            end
            return
        end
        local x = Size.pad - 6
        if not row.wing then
            row.wing = row:CreateTexture(nil, "BACKGROUND", nil, -2)
            row.wing:SetPoint("TOPLEFT", x, 0)
            row.wing:SetPoint("BOTTOMRIGHT")
            row.trunk = row:CreateTexture(nil, "BORDER")
            row.tick = row:CreateTexture(nil, "BORDER")
            row.tick:SetPoint("LEFT", row, "LEFT", x, 0)
            row.tick:SetWidth(10)
        end
        local fade, line = Theme.color.wingFade, Theme.color.wingLine
        row.wing:SetColorTexture(1, 1, 1, 1)
        row.wing:SetGradient("HORIZONTAL", CreateColor(fade[1], fade[2], fade[3], fade[4]),
            CreateColor(fade[1], fade[2], fade[3], 0))
        -- One whole screen pixel or more, so the line stays crisp.
        local _, unit = Theme:LineWidth(row)
        local lineWidth = math.ceil(1 / unit - 0.01) * unit
        row.trunk:SetColorTexture(unpack(line))
        row.trunk:SetWidth(lineWidth)
        row.trunk:ClearAllPoints()
        row.trunk:SetPoint("TOPLEFT", x, 0)
        -- The last member's line stops at its tick.
        if pane.lastMember[instance] then
            row.trunk:SetPoint("BOTTOMLEFT", row, "LEFT", x, -lineWidth / 2)
        else
            row.trunk:SetPoint("BOTTOMLEFT", x, 0)
        end
        row.tick:SetColorTexture(unpack(line))
        row.tick:SetHeight(lineWidth)
        row.band:Hide()
        row.wing:Show(); row.trunk:Show(); row.tick:Show()
    end

    -- Classic Raids: a gold section header, like Encounters, with a +/-
    -- right after the name, lit while open.
    local function SetupGroupHeader(row, header)
        if not row.arrow then
            -- Right after the name, so it reads as part of it.
            row.arrow = Theme:Arrow(row)
            row.arrow:SetPoint("LEFT", row.title, "RIGHT", NAME_ARROW_GAP, 0)
        end
        local isOpen = IsClassicOpen()
        row.arrow:SetOpen(isOpen)
        if not row.lit then
            row.lit = row:CreateTexture(nil, "BACKGROUND", nil, -1)
            row.lit:SetAllPoints()
        end
        row.lit:SetColorTexture(unpack(Theme.color.groupLit))
        row.lit:SetShown(isOpen)
        if isOpen then row.band:Hide() end
        row.indent = 0
        row.suffix:SetText(nil)
        row.title:SetPoint("LEFT", Size.pad, 0)
        row.title:SetFontObject(Theme.font.section)
        row.title:SetText(header.name)
        row.sub:Hide()
        row.rightWidth = NAME_ARROW_GAP + 10
    end

    -- Professions and currency lists show their icon left of the name;
    -- returns the icon file.
    local function ShowListIcon(row, instance)
        local icon = ListIcon(instance)
        if icon and not row.listIcon then
            row.listIcon = row:CreateTexture(nil, "ARTWORK")
            row.listIcon:SetSize(LIST_ICON, LIST_ICON)
            row.listIcon:SetPoint("CENTER", row, "LEFT", Size.pad + LIST_ICON / 2, 0)
            Theme:CropIcon(row.listIcon)
            Theme:ShapeIcon(row, row.listIcon)
        end
        if row.listIcon then
            row.listIcon:SetShown(icon ~= nil)
            if icon then row.listIcon:SetTexture(icon) end
        end
        return icon
    end

    pane = CreateList(parent, {
        label = L["Instances"],
        rowHeight = 44,
        subtitle = true,
        suffix = true,
        entryHeight = function(entry)
            if entry.marker then return ROW.MARKER end
            if OneLine(entry) then return ONE_LINE_ROW end
            if entry.header then return ROW.GROUP end
            local standingRoom = StandingRoom(entry)
            if standingRoom > 0 then return pane.rowHeight + standingRoom end
        end,
        setupRow = function(row, entry)
            local header = entry.header
            if row.arrow then row.arrow:SetShown(header) end
            if row.lit and not header then row.lit:Hide() end
            -- Every other instance row is faintly banded, to keep your place.
            if not row.band then
                row.band = row:CreateTexture(nil, "BACKGROUND", nil, -1)
                row.band:SetAllPoints()
            end
            row.band:SetColorTexture(unpack(Theme.color.band))
            row.band:SetShown(pane.banded[entry] or false)
            StyleMember(row, entry)
            if row.levels then row.levels:Hide() end
            if row.marker then row.marker:Hide() end
            HideStanding(row)
            row.rightWidth = nil
            row:EnableMouse(not entry.marker)
            local icon = ShowListIcon(row, entry)
            if entry.marker then
                -- The line marking where your level falls.
                MarkerLine(row, entry.name)
                row.title:SetText(nil)
                row.suffix:SetText(nil)
                row.sub:Hide()
                return
            end
            if header then
                SetupGroupHeader(row, entry)
                return
            end
            row.indent = (icon and LIST_ICON + 8 or 0) + (isMember[entry] and MEMBER_INDENT or 0)
            local oneLine = OneLine(entry, pane.compact)
            -- The name's line: centered when it is the only one, else 6 up
            -- for the zone under it, and up half of any standing bars' room
            -- too, so the name and zone keep their place at the row's top.
            local y = oneLine and 0 or 6 + StandingRoom(entry) / 2
            row.title:SetPoint("LEFT", Size.pad + row.indent, y)
            row.title:SetFontObject(Theme.font.body)
            row.title:SetText(entry.name)
            -- Group size after the name for anything bigger than a 5-player group.
            local bigGroup = entry.groupSize and entry.groupSize > 5
            row.suffix:SetText(bigGroup and L["(%d players)"]:format(entry.groupSize) or nil)
            if Leveled(entry) then
                row.levelRoom = entry.category == "RAID" and ARROW_ROOM or 0
                ShowLevels(row, entry.levelRange, y)
            end
            -- Only two-line rows (raids) get a second line: their zone.
            -- Dungeons show theirs on the Overview.
            row.sub:SetShown(not oneLine)
            if not oneLine then
                local levels = not Leveled(entry) and entry.levelRange
                    and Theme.DOTS .. ("%d-%d"):format(entry.levelRange[1], entry.levelRange[2]) or ""
                row.sub:SetText(entry.zone .. levels)
            end
            -- The row is the pane's width less its two 1-unit edges.
            local textWidth = pane:GetWidth() - 2 - Size.pad * 2 - row.indent
            ShowStanding(row, entry, y, textWidth)
        end,
        afterRow = function(row, entry)
            if not entry.header then return end
            -- Gold like the Encounters header.
            Theme:SetTextColor(row.title, Theme.color.heading)
        end,
        isSelected = function(entry) return not entry.header and not entry.marker and ns.UI.state.instance == entry end,
        onClick = function(entry)
            if entry.marker then return end
            if entry.header then
                pane:ToggleGroup()
                return
            end
            ns.UI:ClearHistory()
            ns.UI:SelectInstance(entry)
        end,
    })

    -- The rows on show, in list order, with a "Level N" line in Dungeons
    -- and the Classic Raids header at the end, followed by its members
    -- while it is open (or sliding).
    local levelLine = { marker = true }
    pane.banded = {}
    pane.lastMember = {}
    local function Entries()
        local list, members = {}, {}
        local level = ns.PlayerLevel()
        local all = pane.all or {}
        -- The line goes before the first dungeon starting above your level.
        local needsLevelLine = all[1] and all[1].category == "DUNGEON"
        wipe(isMember)
        for _, instance in ipairs(all) do
            if IsClassicRaid(instance) then
                table.insert(members, instance)
            else
                if needsLevelLine and instance.levelRange and instance.levelRange[1] > level then
                    levelLine.name = L["Level %d"]:format(level)
                    table.insert(list, levelLine)
                    needsLevelLine = false
                end
                table.insert(list, instance)
            end
        end
        if #members > 0 then
            table.insert(list, CLASSIC_HEADER)
            local sliding = pane.anim ~= nil
            if IsClassicOpen() or sliding then
                for _, member in ipairs(members) do
                    table.insert(list, member)
                    isMember[member] = true
                    if sliding then pane.anim.total = pane.anim.total + pane:EntryHeight(member) end
                end
            end
        end
        -- Band every other row. A group's members sit on their own panel
        -- instead, and don't count, so the rows below keep their bands as it
        -- opens. The last member ends the panel's tree line.
        wipe(pane.banded)
        wipe(pane.lastMember)
        local rowCount = 0
        for i, entry in ipairs(list) do
            if isMember[entry] then
                pane.lastMember[entry] = not isMember[list[i + 1]]
            elseif not entry.marker then
                rowCount = rowCount + 1
                pane.banded[entry] = rowCount % 2 == 0
            end
        end
        return list
    end

    -- Redraws with the groups as they are now, keeping the scroll position.
    function pane:Rebuild()
        if self.anim then self.anim.total = 0 end
        self.entries = Entries()
        self.offset = math.min(self.offset, math.max(0, #self.entries - 1))
        self:Refresh()
    end

    -- The members are laid out whole behind a strip that opens (or closes)
    -- over them, as the Encounters group does.
    function pane:ToggleGroup()
        SetClassicOpen(not IsClassicOpen())
        StartSlide(self, { total = 0 }, function(entry) return isMember[entry] end, IsClassicOpen())
    end

    -- The first row that is an instance: what a tab opens on.
    function pane:FirstInstance()
        for _, entry in ipairs(self.entries) do
            if not entry.header and not entry.marker then return entry end
        end
    end

    -- A new level moves the "Level N" line and recolors the levels.
    ns:On("PLAYER_LEVEL_UP", function()
        -- UnitLevel catches up a moment after the event.
        C_Timer.After(1, function()
            if pane.all then pane:Rebuild() end
        end)
    end)

    local function IsProfessionList(list)
        return list[1] ~= nil and list[1].category == "PROFESSION"
    end

    -- pane.given is the list as the tab handed it over; pane.all is it in
    -- the order shown.
    local setData = pane.SetData
    function pane:SetData(entries)
        self.given = entries or {}
        self.all = self.given
        local order = self.all[1] and ORDER_BY_CATEGORY[self.all[1].category]
        if order then
            local sorted = {}
            for i, instance in ipairs(self.all) do sorted[i] = instance end
            table.sort(sorted, order)
            self.all = sorted
        elseif IsProfessionList(self.all) then
            self.all = KnownProfessionsFirst(self.all)
        end
        StopSlide(self)
        setData(self, Entries())
    end

    -- A profession learned or unlearned moves to its block. Skill-ups fire
    -- this too, so the rows are redrawn only when the order changes; the
    -- selection is kept (ns.UI.state.instance) and the scroll stays put.
    ns:On("SKILL_LINES_CHANGED", function()
        if not (pane.given and IsProfessionList(pane.given)) then return end
        local ordered = KnownProfessionsFirst(pane.given)
        if SameOrder(ordered, pane.all) then return end
        pane.all = ordered
        pane:Rebuild()
    end)

    -- Scrolling to a Classic Raids member opens the group first.
    local scrollTo = pane.ScrollTo
    function pane:ScrollTo(entry)
        if entry and IsClassicRaid(entry) and not IsClassicOpen() then
            SetClassicOpen(true)
            StopSlide(self)
            self:Rebuild()
        end
        scrollTo(self, entry)
    end

    -- The setting changed: Classic Raids takes its state from the new set.
    ns.SectionMemory.OnModeChange(function()
        groups = ns.SectionMemory.Area("instances")
        if not pane.all then return end
        StopSlide(pane)
        pane:Rebuild()
    end)
    return pane
end

-- True when every word of `query` (lowercase) appears in `name` as written:
-- "iron bar" and "bar iron" find "Iron Bar", "cured" finds "Cured Light
-- Hide" but not "Cloudy Windraveled Armguards".
function ns.UI.WordsMatch(name, query)
    name = name:lower()
    for word in query:gmatch("%S+") do
        if not name:find(word, 1, true) then return false end
    end
    return true
end

-- Reaction index (4 = Neutral ... 8 = Exalted) of each standing group.
local STANDING_REACTION = { NEUTRAL = 4, FRIENDLY = 5, HONORED = 6, REVERED = 7, EXALTED = 8 }

-- The standing group the player has reached, so faction lists can mark it.
local function ReachedGroup(instance)
    local reaction = instance and ns.UI.PlayerStanding(instance.factionID)
    if not reaction then return nil end
    local best, bestReaction
    for _, encounter in ipairs(instance.encounters) do
        local need = STANDING_REACTION[encounter.id]
        if need and need <= reaction and (not bestReaction or need > bestReaction) then
            best, bestReaction = encounter, need
        end
    end
    return best
end

-- A chain's later step under its first quest (see ChainTrees): a circle
-- with its step number where the name would start, the name after it
-- (Mike's call, 2026-10-16: no tree lines).
local CHAIN_CIRCLE = 28
local CHAIN_GAP = 6  -- between the circle and the name

local function NewChainStep(row)
    local tree = CreateFrame("Frame", nil, row)
    tree:SetAllPoints()
    tree.fill = tree:CreateTexture(nil, "ARTWORK", nil, 1)
    tree.fill:SetTexture(Theme.roundMask)
    tree.fill:SetVertexColor(0.1, 0.08, 0.05, 1)
    tree.fill:SetSize(CHAIN_CIRCLE * 0.8, CHAIN_CIRCLE * 0.8)
    tree.ring = tree:CreateTexture(nil, "ARTWORK", nil, 2)
    tree.ring:SetAtlas("CovenantChoice-Offering-Ability-Ring-Venthyr")
    tree.ring:SetSize(CHAIN_CIRCLE, CHAIN_CIRCLE)
    tree.fill:SetPoint("CENTER", tree.ring)
    -- The number fills the ring's box, centred both ways, so one digit or
    -- two sit in the middle (PlaceChainStep picks the size).
    tree.number = Theme:Text(tree, Theme:ScaledFont(Theme.font.small, 1.2))
    tree.number:SetSize(CHAIN_CIRCLE, CHAIN_CIRCLE)
    tree.number:SetJustifyH("CENTER")
    tree.number:SetJustifyV("MIDDLE")
    tree.number:SetWordWrap(false)
    tree.number:SetTextColor(1, 0.82, 0)
    row.chainTree = tree
end

-- Places the circle for step `step`, its left edge at `left` (where the
-- first quest's name starts); returns how far the name moves right.
local function PlaceChainStep(row, step, left)
    local tree = row.chainTree
    tree.ring:ClearAllPoints()
    tree.ring:SetPoint("LEFT", row, "LEFT", math.floor(left + 0.5), 0)
    -- Two digits a touch smaller to fit the ring, and a pixel right (they
    -- read left of centre otherwise); the ring art is a little taller
    -- than wide, so its middle sits half a pixel up.
    local twoDigits = step >= 10
    tree.number:SetFontObject(Theme:ScaledFont(Theme.font.small, twoDigits and 1.05 or 1.2))
    tree.number:ClearAllPoints()
    tree.number:SetPoint("CENTER", tree.ring, "CENTER", twoDigits and 1 or 0.5, 0.5)
    tree.number:SetText(step)
    return CHAIN_CIRCLE + CHAIN_GAP
end

-- "Quests" and "Encounters", each a header that slides its smaller rows open
-- or shut. Raids have the same, less Quests. The Overview row looks like a
-- header but opens the dungeon's page. A gathering profession with Scarce
-- reagents splits it the same way into "Recipes" and "Scarce Reagents" (no
-- Overview). How far in their rows sit, in one table for the same reason
-- as ROW.
local INDENT = {
    CHILD = 8,
    -- A row in a fold-out: an encounter in a wing's (Stratholme: Live, Undead),
    -- a part of a questline in its fold (the warrior's Defensive Stance).
    FOLD = 22,
    SET_MEMBER = 18, -- a recipe folded under its colour set's row, added to the CHILD indent
}
local PAGE_ICON = 17     -- a section page's own icon before its name (a hunter pet family's)
local PAGE_ICON_GAP = 7  -- between that icon and the name
local CLASS_BADGE = 26    -- a class quest's class icon, as tall as its name and status lines
local CLASS_RING = CLASS_BADGE * 0.125 -- how far the class icon's ring reaches past it
local CLASS_NAME_GAP = 9   -- between a class fold's badge and its name, as on the Classes tab's class column
local FLOOR_PIN = 36      -- a boss's mini map pin, on the map's open floor (row height at most)
local TRASH_ICON = "SCRAP-deactivated"  -- in the selected Trash Drops row's mini pin
local ALL_DROPS_ICON = "BonusLoot-Chest"  -- All drops' mini pin, greyed while not selected
-- A header's Alliance / Horde toggle, in one table for the same reason as ROW.
local SIDE_TOGGLE = {
    GAP = 4, -- between the toggle and the text left of it
    -- A dungeon's Quests header has its count under the title, so its toggle
    -- sits nearer the arrow: its right edge this far right of the figure's left.
    NUDGE = 4,
}
local INSIDE_ICON = 26    -- the dungeon portal by a quest's insignia, when it starts inside
local INSIDE_GAP = 2      -- between the portal and the next icon
-- The people icon left of the portal on a quest a party member can be given.
local SHARE = { ICON = 20, GAP = 4, ATLAS = "socialqueuing-icon-group" }
local QUEST_FIGURE_GAP = 4 -- between a class quest's level and its icons (the Classes tab's Quests)
-- A name with an icon after it, a space between: |A markup sized 0:0 draws
-- the atlas at the line's text height, so it wraps and sits with the name.
local TITLE_ICON_MARKUP = "%s |A:%s:0:0|a"
local DISC = 30           -- the round disc behind a header's icon
local DISC_ICON = 23      -- the longer side of the icon on it (the ring draws over its edges)
local DISC_RING = "Mode-Selection-Ring-c60" -- the ring round each disc
local RING_GREY = 0.35    -- alpha of the other sections' rings
local CARD_INSET = 5      -- the active section's card (Theme:SectionCard), in from the pane's sides
local SHUT_GAP = 2        -- an inactive header's thin card, in from its row's top and bottom
local NO_ROWS = {}
-- Icons are Forever's own radial menu atlases (see /nr icondebug).
local OVERVIEW_ATLAS = "GameMenu-up-c60"
-- Honor rank insignia: the client's own PvPRankBadges art, by file ID
-- (interface/pvprankbadges/pvprank01..14.blp, the same for both factions).
local RANK_BADGE_FILE = 136765 -- + rank
local RANK_ICON = 20
-- The group headers, in list order.
local QUESTS_HEADER = { header = true, key = "QUESTS", name = L["Quests"], atlas = "Exclamation-up-c60" }
local INSTANCE_HEADERS = {
    QUESTS_HEADER,
    -- Quests that need a profession: its icon with the quest mark on it.
    { header = true, key = "PROFQUESTS", name = L["Profession Quests"], atlas = "Professions-up-c60",
        badge = "Exclamation-up-c60" },
    { header = true, key = "ENCOUNTERS", name = L["Encounters"], atlas = "AdventureGuide-up-c60" },
}
-- A recipe filter that names a recipe exactly lists it, then the recipes
-- that use what it makes under this group (shut to start).
local INCLUDED_HEADERS = {
    { header = true, key = "INCLUDED", name = L["Included In"], atlas = "Professions-up-c60" },
}
local PROFESSION_HEADERS = {
    { header = true, key = "SCARCE", name = L["Scarce Reagents"], atlas = "Bags-up-c60" },
    { header = true, key = "RECIPES", name = L["Recipes"], atlas = "Spellbook-up-c60" },
}
-- A collection whose vendor gives quests: those quests, then what the
-- vendor sells, its sections (Trinkets, Cloaks ...) under the Vendor group.
local VENDOR_HEADERS = {
    QUESTS_HEADER,
    { header = true, key = "ENCOUNTERS", name = L["Vendor"], atlas = "Shop-up-c60" },
}

-- Whether a list has a Quests group: every dungeon, and a collection whose
-- vendor gives quests (the Tarnished Undermine Real's weekly "In Demand"
-- quests, registered under the collection's ID).
local function HasQuestsGroup(instance)
    if not instance then return false end
    if instance.category == "DUNGEON" then return true end
    return instance.category == "COLLECTION" and #ns.Data:Quests(instance.id) > 0
end

-- Whether a list splits into Recipes and Scarce Reagents: a profession
-- with Scarce reagents to show.
local function HasScarce(instance)
    return instance ~= nil and instance.category == "PROFESSION" and #ns.Data:Scarce(instance.id) > 0
end

-- Which side's quests the Quests group lists: the player's own until the
-- switch in its header picks the other.
function ns.UI.QuestSide()
    return ns.UI.state and ns.UI.state.questSide or ns.PlayerFaction()
end

-- Whether some of a dungeon's quests only one side can take (then the
-- Quests header has the Alliance / Horde switch).
function ns.UI.HasSideQuests(instance)
    for _, quest in ipairs(ns.Data:Quests(instance.id)) do
        if quest.side then return true end
    end
    return false
end

-- Whether a quest is a class quest for a class other than the player's.
local function OtherClass(quest)
    local _, class = UnitClass("player")
    return quest.classes ~= nil and Theme:ClassToken(quest.classes) ~= class
end

-- A quest's chain, for the list's chain trees: its key (the chain's first
-- quest) and its step. Data/Chains.lua's chain for `side` and the player's
-- class comes first, so the tree matches the quest page's chain; without
-- one, the quest's own chain fields.
local function ChainSpot(quest, side)
    local _, class = UnitClass("player")
    local steps, step = ns.Data:Chain(quest.id, side, class)
    if steps then return steps[1][1], step end
    -- When its start is on a Data/Chains.lua chain that leaves this quest
    -- out, the quest is a branch off that chain: joining the tree would
    -- draw it as one of the chain's numbered steps, so it stands alone.
    if quest.chainStart and not ns.Data:Chain(quest.chainStart, side, class) then
        return quest.chainStart, quest.chainStep or 2
    end
    return quest.id, 1
end

-- `list`'s quests with each chain's quests (two or more of them here) put
-- together where its first one sits: that one as it is, the later steps
-- under it, earliest first, each a copy marked with its step
-- (chainStep) and the last one chainLast, for the list to draw a tree.
-- `side`: the side whose chains to follow.
local function ChainTrees(list, side)
    local chainOf, spot = {}, {}  -- chain key -> its entries; entry -> { key, step }
    for _, entry in ipairs(list) do
        local key, step = ChainSpot(entry.quest, side)
        -- A group's quest changes as the player moves, and a fold's quest is
        -- listed under its fold row: each stands alone.
        if entry.variants or entry.fold then key, step = entry.key, 1 end
        spot[entry] = { key, step }
        chainOf[key] = chainOf[key] or {}
        table.insert(chainOf[key], entry)
    end
    local out, placed = {}, {}
    for _, entry in ipairs(list) do
        local key = spot[entry][1]
        local chain = chainOf[key]
        if #chain < 2 then
            table.insert(out, entry)
        elseif not placed[key] then
            placed[key] = true
            table.sort(chain, function(a, b) return spot[a][2] < spot[b][2] end)
            table.insert(out, chain[1])
            for i = 2, #chain do
                local laterStep = {}
                for field, value in pairs(chain[i]) do laterStep[field] = value end
                laterStep.chainStep, laterStep.chainLast = spot[chain[i]][2], i == #chain or nil
                table.insert(out, laterStep)
            end
        end
    end
    return out
end

-- The quests one side (by default the one the switch shows) can take in a
-- dungeon, as list entries ({ quest = q }), kept per dungeon and side, with
-- one entry per quest so a quest both sides take is the same entry in both.
-- A quest on a quest chain is folded under its questline's row instead
-- (UI/DungeonQuestlines.lua: { isFold, questline, foldQuests = its quests'
-- entries }). Other classes' quests come last, under an "Other classes"
-- marker ({ marker = true }), flagged `other` so counts leave them out.
-- `professions`: the quests that need a profession (Profession Quests)
-- instead of the rest (Quests).
local questLists, questEntry = {}, {}

function ns.UI.DungeonQuests(instance, faction, professions)
    faction = faction or ns.UI.QuestSide()
    local key = instance.id .. ":" .. faction .. (professions and ":professions" or "")
    if questLists[key] then return questLists[key] end
    local list, others = {}, {}
    for _, quest in ipairs(ns.Data:Quests(instance.id)) do
        if (not quest.side or quest.side == faction) and (quest.profession ~= nil) == (professions == true) then
            questEntry[quest] = questEntry[quest] or { quest = quest, name = quest.name, other = OtherClass(quest) }
            table.insert(questEntry[quest].other and others or list, questEntry[quest])
        end
    end
    local listKey = professions and "PROFQUESTS" or "QUESTS"
    local FoldRows = ns.UI.DungeonQuestlines.FoldRows
    list, others = FoldRows(list, instance, faction, listKey), FoldRows(others, instance, faction, listKey .. ":OTHER")
    if #others > 0 then
        table.insert(list, { marker = true, name = L["Other classes"] })
        for _, entry in ipairs(others) do table.insert(list, entry) end
    end
    questLists[key] = list
    return list
end

-- Which side's quests the Classes tab's Quests section lists: the player's
-- own until its Alliance / Horde toggle picks the other.
function ns.UI.ClassQuestSide()
    return ns.UI.state and ns.UI.state.classQuestSide or ns.PlayerFaction()
end

-- The one of `givers` (a quest's givers or chainGivers: Data/Data.lua) who
-- serves side `side` and stands nearest the player.
local function NearestGiver(givers, side)
    local serving = {}
    for _, giver in ipairs(givers) do
        if not giver.side or giver.side == side then table.insert(serving, giver) end
    end
    return ns.UI.NearestFirst(serving)[1]
end

-- For a quest each side takes from its own NPCs (The Islander: every city's
-- warrior trainer), names the nearest of side `side`'s as its giver, and
-- likewise its chain's first giver, so its page and map pin never send the
-- player to the other side's city.
local function PickGivers(quest, side)
    local giver = quest.givers and NearestGiver(quest.givers, side)
    if giver then quest.giver, quest.giverNpc = giver.name, giver.npc end
    local chainGiver = quest.chainGivers and NearestGiver(quest.chainGivers, side)
    if chainGiver then quest.chainGiver, quest.chainGiverNpc = chainGiver.name, chainGiver.npc end
end

-- Picks the givers of every class quest, dungeon quest and chain step anew
-- as the player enters the world or a new zone. Inside a dungeon the
-- player's place in the world is unknown, so the picks made outside stay.
local hasPickedGivers = false
local function PickAllGivers()
    if hasPickedGivers and IsInInstance() then return end
    hasPickedGivers = true
    local side = ns.PlayerFaction()
    for _, quests in pairs(ns.Data.classQuests) do
        for _, quest in ipairs(quests) do PickGivers(quest, side) end
    end
    for _, quests in pairs(ns.Data.quests) do
        for _, quest in ipairs(quests) do PickGivers(quest, side) end
    end
    for _, step in pairs(ns.Data.chainSteps) do PickGivers(step, side) end
end
ns:On("PLAYER_ENTERING_WORLD", PickAllGivers)
ns:On("ZONE_CHANGED_NEW_AREA", PickAllGivers)

-- Where a group's quest starts: its chain's first giver, else its own.
local function StartNpc(quest)
    return quest.chainGiverNpc or quest.giverNpc
end

-- A group's quest with its start's place in the world, for UI.NearestFirst.
local function StartWorldSpot(quest)
    return ns.UI.SpotInWorld(ns.Data:NpcSpot(StartNpc(quest), quest.id))
end

-- What a group's row and page show for its quest `quest`: a copy whose
-- other versions (alt) are the group's other quests, so the row reads
-- Completed once any of them is done. Kept per quest, so its status is
-- worked out once (UI/Overview.lua keeps statuses per quest table). A
-- fold's group (Defensive Stance) lists each of its quests on a page of its
-- own, so the copy opens the quest's own page, not the group's.
local function GroupQuestShown(entry, quest)
    entry.shown = entry.shown or {}
    if entry.shown[quest] then return entry.shown[quest] end
    local shown = {}
    for field, value in pairs(quest) do shown[field] = value end
    shown.alt = {}
    for _, variant in ipairs(entry.variants) do
        if variant ~= quest then table.insert(shown.alt, variant.id) end
        for _, id in ipairs(variant.alt or {}) do table.insert(shown.alt, id) end
    end
    shown.groupKey = not entry.fold and entry.key or nil
    entry.shown[quest] = shown
    return shown
end

-- Points each group entry of `entries` (ns.UI.ClassQuests) at its quest
-- starting nearest the player, as they move between asks.
function ns.UI.PickNearestQuests(entries)
    for _, entry in ipairs(entries) do
        if entry.variants then
            entry.quest = GroupQuestShown(entry, ns.UI.NearestFirst(entry.variants, StartWorldSpot)[1])
            entry.name = entry.quest.name
        end
    end
end

-- The quests of the class with token `classToken` ("MAGE") that side
-- ns.UI.ClassQuestSide can take, as list entries ({ quest = q, key =
-- "QUEST:" .. its ID }), each chain's quests put together as a tree
-- (ChainTrees), kept per class and side. Quests sharing a group (the
-- warlock's Summon Imp quests, one per starting zone; the city copies of
-- one breadcrumb; one quest's versions from different givers:
-- Data/ClassQuests.lua) are one entry ({ variants = { q, ... }, key = "QUESTGROUP:" .. group }),
-- showing the one starting nearest the player (PickNearestQuests).
-- A questline's quests (Data/ClassQuests.lua's RegisterClassQuestFolds)
-- are here by the quests that end each of its stages only, marked with
-- their fold (entry.fold), and the ends of a stage whose branches are
-- alternatives (Defensive Stance, then its weapon quests), like a version
-- step's quests, are one group, so the count and Overview go by what the
-- player can do. The Quests section shows each as its fold's rows
-- (UI/Questlines.lua's ClassQuestPages).
local classQuestLists = {}

-- Adds `quest` to `list`: into its group's entry (`groupEntry`, by group)
-- when it has one, else as an entry of its own. `fold`: the fold it is
-- listed under, or nil; `stage`: the stage of the fold it ends (the fold,
-- or its followUp), whose alternatives are one group; `versionGroup`: the
-- group of the version step it is one of, whose versions are one entry.
local function AddClassQuest(list, groupEntry, quest, fold, stage, versionGroup)
    local group = quest.group or (stage and stage.oneOf and stage.key) or versionGroup
    if not group then
        questEntry[quest] = questEntry[quest]
            or { quest = quest, name = quest.name, key = "QUEST:" .. quest.id, fold = fold }
        table.insert(list, questEntry[quest])
        return
    end
    if groupEntry[group] then
        table.insert(groupEntry[group].variants, quest)
        return
    end
    groupEntry[group] = { variants = { quest }, name = quest.name, key = "QUESTGROUP:" .. group, fold = fold }
    table.insert(list, groupEntry[group])
end

local function ClassQuestList(classToken, side)
    local list, groupEntry = {}, {}
    for _, quest in ipairs(ns.Data:ClassQuests(classToken)) do
        local fold, isEnd, stage, versionGroup = ns.Data:ClassQuestFold(classToken, quest.id)
        local isListed = (not quest.side or quest.side == side) and (not fold or isEnd)
        if isListed then AddClassQuest(list, groupEntry, quest, fold, stage, versionGroup) end
    end
    ns.UI.PickNearestQuests(list)
    return ChainTrees(list, side)
end

function ns.UI.ClassQuests(classToken)
    local side = ns.UI.ClassQuestSide()
    local key = classToken .. ":" .. side
    classQuestLists[key] = classQuestLists[key] or ClassQuestList(classToken, side)
    return classQuestLists[key]
end

-- How many of class `classToken`'s quests (ns.UI.ClassQuests) the player
-- has completed, and how many there are.
function ns.UI.ClassQuestsDone(classToken)
    local entries = ns.UI.ClassQuests(classToken)
    local done = 0
    for _, entry in ipairs(entries) do
        if ns.UI.QuestStatus(entry.quest) == "Completed" then done = done + 1 end
    end
    return done, #entries
end

-- The quest entries of `entries` (a list of ns.UI.DungeonQuests), the
-- ones folded under a questline's row in their place, in order.
local function QuestEntries(entries)
    local quests = {}
    for _, entry in ipairs(entries) do
        for _, folded in ipairs(entry.foldQuests or { entry }) do
            if folded.quest then table.insert(quests, folded) end
        end
    end
    return quests
end

-- How many of a dungeon's quests the player can take (on the side the
-- switch shows) and how many of those are done, and how many are other
-- classes' quests. `key` "QUESTS" or "PROFQUESTS" counts only that
-- group's; with none, both.
function ns.UI.QuestCount(instance, key)
    local done, total, others = 0, 0, 0
    for _, professions in ipairs({ false, true }) do
        if not key or (key == "PROFQUESTS") == professions then
            for _, entry in ipairs(QuestEntries(ns.UI.DungeonQuests(instance, nil, professions))) do
                if entry.other then
                    others = others + 1
                else
                    total = total + 1
                    if ns.UI.QuestStatus(entry.quest) == "Completed" then done = done + 1 end
                end
            end
        end
    end
    return done, total, others
end

-- A colour set's row stands for the recipes folded under it
-- (UI/RecipeBand.lua). It reads missing fields from its first recipe, so
-- only its own fields count: rawget.
local function IsSetRow(entry)
    return rawget(entry, "setRow") ~= nil
end

-- Puts `icon` at the row's right edge, or `gap` left of the icons already
-- there, and makes it the edge the next icon (and the name) stop at.
local function PlaceLeftOfIcons(row, icon, gap)
    icon:ClearAllPoints()
    if row.iconEdge then
        icon:SetPoint("RIGHT", row.iconEdge, "LEFT", -gap, 0)
    else
        icon:SetPoint("RIGHT", row, "RIGHT", -Size.pad, 0)
    end
    row.iconEdge = icon
end

-- A quest row's insignia: the factions that can take it, at the right edge.
-- As big as the Quests header's Alliance / Horde toggle; a quest both sides
-- take stacks them (Theme:DrawCrests), the player's side in front. Every
-- quest row keeps a slot as wide as the pair (crestStack), a lone insignia
-- centred in it, so the icons left of it line up from row to row.
local function ShowCrests(row, quest)
    if quest and not row.crests then Theme:NewCrests(row) end
    if not row.crests then return end
    Theme:DrawCrests(row, quest and (quest.side or Theme.BOTH_SIDES), ns.PlayerFaction())
    if not quest then return end
    row.crestStack:ClearAllPoints()
    row.crestStack:SetPoint("RIGHT", row, "RIGHT", -Size.pad, 0)
    row.iconEdge = row.crestStack
end

-- A header row's Alliance / Horde toggle (Theme:FactionToggle) listing
-- quests, made once per row; a click runs `onPick` with the other side.
local function SideToggleOf(row, onPick)
    if not row.sideToggle then
        row.sideToggle = Theme:FactionToggle(row, onPick,
            { shown = L["%s quests"], click = L["Click to see %s quests"] })
    end
    row.sideToggle.onPick = onPick
    return row.sideToggle
end

-- A quest row ends with a class quest's class icon, then the people icon of
-- a quest that can be shared with the party, then the portal of a quest that
-- starts inside the dungeon, then the insignia of the factions that can take
-- it at the right edge, in one column with the other rows'; each is centred
-- beside the name and status. row.iconEdge is the leftmost of them, which the
-- name stops short of; a quest row always has the crest slot, so its iconEdge
-- is never nil.
local function ShowQuestIcons(row, quest, class, inside, shareable)
    if class and not row.classBadge then row.classBadge = Theme:ClassBadge(row, CLASS_BADGE) end
    if row.classBadge then row.classBadge:SetClass(class or nil) end
    if inside and not row.insideIcon then row.insideIcon = ns.UI.InsideIcon(row, INSIDE_ICON) end
    if row.insideIcon then row.insideIcon:SetShown(inside or false) end
    if shareable and not row.shareIcon then
        row.shareIcon = ns.UI.HintIcon(row, SHARE.ATLAS, SHARE.ICON, L["Shareable: whoever has it can share it with their party"])
    end
    if row.shareIcon then row.shareIcon:SetShown(shareable or false) end
    row.iconEdge = nil
    ShowCrests(row, quest)
    if inside then PlaceLeftOfIcons(row, row.insideIcon, INSIDE_GAP + 2) end
    if shareable then PlaceLeftOfIcons(row, row.shareIcon, SHARE.GAP) end
    if class then PlaceLeftOfIcons(row, row.classBadge, 4 + CLASS_RING) end
end

-- Honor rank lists show each rank's insignia left of its name; rows
-- without a rank ("Any rank") keep the names lined up.
local function ShowRankIcon(row, entry, instance)
    local honor = instance and tostring(instance.id):find("^HONOR_")
    local rank = honor and tonumber(entry.id and entry.id:match("^RANK_(%d+)$"))
    if rank and not row.rankIcon then
        row.rankIcon = row:CreateTexture(nil, "ARTWORK")
        row.rankIcon:SetSize(RANK_ICON, RANK_ICON)
        row.rankIcon:SetPoint("CENTER", row, "LEFT", Size.pad + RANK_ICON / 2, 0)
    end
    if row.rankIcon then
        row.rankIcon:SetShown(rank ~= nil)
        if rank then row.rankIcon:SetTexture(RANK_BADGE_FILE + rank) end
    end
    if honor then row.indent = RANK_ICON + 8 end
end

-- A later step of a chain under its first quest here: a circle with its
-- step before the name.
local function ShowChainStep(row, entry, isHeader)
    local step = not isHeader and entry.chainStep or nil
    if step and not row.chainTree then NewChainStep(row) end
    if row.chainTree then row.chainTree:SetShown(step ~= nil) end
    if step then
        row.indent = row.indent + PlaceChainStep(row, step, Size.pad + row.indent - row.inset)
    end
end

-- What a recipe makes (`product`, or `productSpell` for an enchant) in its
-- ring left of the row's name, while `hasIcon`; the name moves right of it.
local function ShowProductIcon(row, hasIcon, product, productSpell)
    if hasIcon and not row.recipeIcon then
        row.recipeIcon = ns.UI.RecipeIcon(row, RECIPE_ICON)
    end
    if not row.recipeIcon then return end
    row.recipeIcon:SetShown(hasIcon)
    if not hasIcon then return end
    row.recipeIcon:SetItem(product, productSpell)
    row.recipeIcon:SetPoint("CENTER", row, "LEFT", Size.pad + row.indent - row.inset + RECIPE_ICON / 2, 0)
    row.indent = row.indent + RECIPE_ICON + RECIPE_GAP
end

-- A recipe in a profession's list shows what it makes while the Professions
-- Icons module is on.
local function ShowRecipeIcon(row, entry, instance)
    ShowProductIcon(row, RecipeIconFor(entry, instance))
end

-- Section headers fold with a chevron; a wing's row, a class quest
-- fold's row (Defensive Stance) and a set list's class row with the plus,
-- the raid Attunement heading's.
local function ShowArrows(row, entry, isHeader)
    local hasPlus = entry.wingHeader or entry.isFold or entry.classFold or false
    if isHeader and not row.chevron then
        row.chevron = Theme:Arrow(row, true)
        row.chevron:SetPoint("RIGHT", -Size.pad + 2, 0)
    end
    if hasPlus and not row.plus then
        row.plus = Theme:Arrow(row)
        row.plus:SetPoint("RIGHT", -Size.pad + 2, 0)
    end
    if row.chevron then row.chevron:SetShown(isHeader) end
    if row.plus then row.plus:SetShown(hasPlus) end
    row.arrow = isHeader and row.chevron or hasPlus and row.plus or nil
end

-- The section's icon on a round disc (PaintHeader rings it in gold while
-- its section is active).
local function NewHeaderDisc(row)
    row.disc = CreateFrame("Frame", nil, row)
    row.disc:SetSize(DISC, DISC)
    row.disc.face = row.disc:CreateTexture(nil, "ARTWORK", nil, 0)
    row.disc.face:SetPoint("CENTER")
    row.disc.face:SetSize(DISC - 2, DISC - 2)
    Theme:MaskRound(row.disc, row.disc.face)
    row.disc.ring = row.disc:CreateTexture(nil, "ARTWORK", nil, 3)
    row.disc.ring:SetPoint("CENTER")
    Theme:FitAtlas(row.disc.ring, DISC_RING, DISC)
    row.disc.ring:SetDesaturated(true)
    row.icon = row.disc:CreateTexture(nil, "ARTWORK", nil, 1)
    row.icon:SetPoint("CENTER")
    -- A second icon on the first's upper right (the quest mark on
    -- Profession Quests' icon).
    row.badge = row.disc:CreateTexture(nil, "ARTWORK", nil, 4)
    row.badge:SetPoint("CENTER", row.icon, "TOPRIGHT", -2, -6)
end

-- A header other than the active one sits in a thin closed card
-- (PaintHeader shows it), lit under the mouse in place of the row's
-- highlight, so a shut section reads as a button.
local function NewShutCard(row)
    row.shutFill, row.shutEdge = Theme:RoundedOn(row, Theme.color.shutFill, Theme.color.shutEdge)
    for _, tex in ipairs({ row.shutFill, row.shutEdge }) do
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", 0, -SHUT_GAP)
        tex:SetPoint("BOTTOMRIGHT", 0, SHUT_GAP)
    end
    function row:PaintShut()
        local lit = self.shut and self:IsMouseOver()
        self.shutFill:SetShown(self.shut)
        self.shutEdge:SetShown(self.shut)
        self.shutFill:SetVertexColor(unpack(lit and Theme.color.shutFillLit or Theme.color.shutFill))
        self.shutEdge:SetVertexColor(unpack(lit and Theme.color.sectionEdge or Theme.color.shutEdge))
        if self.shut then self.hover:Hide() end
    end
    row:HookScript("OnEnter", row.PaintShut)
    row:HookScript("OnLeave", row.PaintShut)
end

-- The name stops short of the faction, portal, share and class icons (and
-- clear of the class icon's ring, past its edge).
local function SetupQuestRow(row, entry, class, inside, shareable)
    local ringRoom = class and CLASS_RING or 0
    row.right:SetPoint("RIGHT", row.iconEdge, "LEFT", -ringRoom, 0)
    -- The same distance added up, for the list to fit the name.
    local icons = (class and CLASS_BADGE + 4 or 0) + (inside and row.insideIcon:GetWidth() + INSIDE_GAP + 2 or 0)
        + (shareable and row.shareIcon:GetWidth() + SHARE.GAP or 0)
    icons = icons + (icons > 0 and 4 or 0) + row.crestStack:GetWidth()
    row.titleReserve = Size.pad + icons + ringRoom + 6
    -- The status under the name, colored as on the quest page.
    local _, color = ns.UI.QuestStatus(entry.quest)
    Theme:SetTextColor(row.note, color)
end

-- The active section's title is gold and its icon ringed in gold; the
-- others keep their color in thin cards of their own.
local function PaintHeader(row, isActive)
    local colors = Theme.color
    Theme:SetTextColor(row.title, isActive and colors.heading or colors.text)
    -- The ring art is desaturated, then tinted gold or left grey.
    if isActive then
        local r, g, b = unpack(colors.discRing)
        row.disc.ring:SetVertexColor(r, g, b, 1)
    else
        row.disc.ring:SetVertexColor(1, 1, 1, RING_GREY)
    end
    row.disc.face:SetColorTexture(unpack(colors.disc))
    row.shut = not isActive
    row:PaintShut()
end

-- The active section sits in a card behind its rows (Theme:SectionCard): a
-- fill and a rounded outline, both fading out from the header down, the
-- outline crisp only across the top. Drawn on the list's canvas, so the rows
-- (and their hover and selection) lie over it and the list's edges clip it.
-- The Overview has no rows under it, so its card is closed: the outline runs
-- all the way round, unfaded. So has the This run section (UI/RunPage.lua).
--
-- After each redraw of grouped list `pane`: the card spans `active` (its
-- header entry) and the rows under it, as far as a sliding group's strip
-- shows them, or hides while none is active or the section is out of view.
-- `isHeaderLike(entry)` says where the next section starts.
local function UpdateSectionCard(pane, card, active, isHeaderLike)
    local entries = pane.entries
    local first, last
    for i, entry in ipairs(entries) do
        if entry == active then
            first = i
        elseif first and isHeaderLike(entry) then
            last = i - 1
            break
        end
    end
    last = last or #entries
    local rowOf = {}
    for _, row in ipairs(pane.rows) do
        if row:IsShown() and row.entry then rowOf[row.entry] = row end
    end
    local slide = pane.slide
    local function Sliding(entry) return slide ~= nil and slide.member(entry) end
    -- Heights down to the strip's edge: rows in the strip count as the
    -- strip's height, once.
    local function Span(from, to)
        local y, inStrip = 0, false
        for i = from, to do
            if Sliding(entries[i]) then
                if not inStrip then y, inStrip = y + slide.height, true end
            else
                y = y + pane:EntryHeight(entries[i])
            end
        end
        return y
    end
    local top
    if first then
        -- The header's row, or worked back from the first of its rows on
        -- show when the header has scrolled away.
        for i = first, last do
            local row = rowOf[entries[i]]
            if row and not Sliding(entries[i]) then
                top = row.top - Span(first, i - 1)
                break
            end
        end
    end
    if not top then
        card:Hide()
        return
    end
    card:Draw(pane, CARD_INSET, pane.listTop + top, pane:GetWidth() - CARD_INSET * 2, Span(first, last),
        active.overview == true or active.runPage == true)
end

-- A profession's Overview row, at the top of the filter sidebar left of the
-- recipe list (UI/RecipeBand.lua's CreateSidebar): it picks the
-- profession's Overview page (UI/ProfessionOverview.lua). Drawn as a
-- dungeon's Overview row is, its disc ringed in gold and a closed card round
-- it while the page shows, in a thin card of its own while it doesn't
-- (PaintHeader). It belongs to the recipe list (pane.overviewRow), which
-- lights it after every redraw.
local OVERVIEW_ROW_GAP = 4  -- between the Overview row and the filters under it
-- Its functions, in one table so CreateEncounterList holds them as one upvalue.
local OverviewRow = {}

-- `host` is the sidebar's canvas.
function OverviewRow.Create(pane, host)
    local row = Theme:Row(host, ROW.GROUP)
    row.inset = CARD_INSET
    row.title = Theme:Text(row, Theme.font.section)
    NewHeaderDisc(row)
    NewShutCard(row)
    row.disc:SetPoint("CENTER", row, "LEFT", Size.pad + DISC / 2 - CARD_INSET, 0)
    Theme:FitAtlas(row.icon, OVERVIEW_ATLAS, DISC_ICON)
    row.title:SetPoint("LEFT", row.disc, "RIGHT", 6, 0)
    row.title:SetText(L["Overview"])
    row.card = Theme:SectionCard(host)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function()
        ns.UI:ClearHistory()
        ns.UI:SelectEncounter(pane.instance.professionOverview)
    end)
    return row
end

-- Lights the Overview row while its page shows.
function OverviewRow.Paint(pane)
    local row = pane.overviewRow
    if not (row and row:IsShown()) then return end
    local isActive = ns.UI.state.encounter == pane.instance.professionOverview
    PaintHeader(row, isActive)
    if isActive then
        local host = row:GetParent()
        row.card:Draw(host, CARD_INSET, row.top, host:GetWidth() - CARD_INSET * 2, ROW.GROUP, true)
    else
        row.card:Hide()
    end
end

-- Shows the Overview row `top` down the sidebar for a profession with an
-- Overview (`instance`; nil hides it) and returns the room it takes.
function OverviewRow.Show(pane, instance, top)
    local overview = instance and instance.professionOverview
    local row = pane.overviewRow
    if not overview then
        if row then
            row:Hide()
            row.card:Hide()
        end
        return 0
    end
    row = row or OverviewRow.Create(pane, pane.sidebar.canvas)
    pane.overviewRow = row
    row.top = top
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", CARD_INSET, -top)
    row:SetPoint("TOPRIGHT", -CARD_INSET, -top)
    row:Show()
    OverviewRow.Paint(pane)
    return ROW.GROUP + OVERVIEW_ROW_GAP
end

-- A section page's `note` under its name, in its `noteColor` (else muted),
-- cut short at the row's right.
local function ShowPageNote(row, entry)
    row.note:SetText(entry.note)
    row.note:SetPoint("RIGHT", -Size.pad, 0)
    row.note:SetWordWrap(false)
    Theme:SetTextColor(row.note, entry.noteColor or Theme.color.muted)
end

-- Rows that fold others under them (a questline's, a colour set's), their
-- functions in one table so CreateEncounterList holds them as one upvalue.
local Folds = {}

-- A questline's fold row (the Classes tab's, UI/Questlines.lua; a
-- dungeon's, UI/DungeonQuestlines.lua): its name over its `note` in
-- `noteColor`, its `figure` in `figureColor` level with the name, and the
-- plus that opens it, turned open while `isOpen`.
function Folds.ShowRow(row, entry, isOpen)
    row.right:SetText(entry.figure or "")
    Theme:SetTextColor(row.right, entry.figureColor or Theme.color.muted)
    row.right:SetPoint("RIGHT", row.arrow, "LEFT", -6, entry.note and 6 or 0)
    row.arrow:SetOpen(isOpen)
    ShowPageNote(row, entry)
end

-- The rows folded under `entry` on a list (a colour set's recipes, a
-- class's sets, a dungeon questline's quests), or nil when it folds none.
function Folds.RowsUnder(entry)
    if IsSetRow(entry) or entry.classFold then return entry.members end
    return entry.foldQuests
end

-- A class's fold row in a set list (UI/TierSets.lua's ClassFolds): the
-- class's ring badge before its name, what it holds under the name in
-- muted ("T1  ·  T2"), and the plus that opens it, turned open while
-- `isOpen`. AfterRow colours the name in the class's colour.
function Folds.ShowClassRow(row, fold, isOpen)
    if not row.foldBadge then row.foldBadge = Theme:ClassBadge(row, CLASS_BADGE) end
    row.foldBadge:SetPoint("CENTER", row, "LEFT", Size.pad + row.indent - row.inset + CLASS_BADGE / 2, 0)
    row.foldBadge:SetClass(fold.token)
    row.indent = row.indent + CLASS_BADGE + CLASS_NAME_GAP
    Theme:SetTextColor(row.note, Theme.color.muted)
    row.right:SetPoint("RIGHT", row.arrow, "LEFT", -6, 0)
    row.arrow:SetOpen(isOpen)
end

-- The row of `rows` (a dungeon's quest list) whose questline folds the
-- entry of `quest`, or nil.
function Folds.RowHolding(rows, quest)
    for _, row in ipairs(rows) do
        for _, entry in ipairs(row.foldQuests or NO_ROWS) do
            if entry.quest == quest then return row end
        end
    end
end

-- The questline row keyed `key` in `instance`'s Quests or Profession
-- Quests (the side the switch shows), or nil.
function Folds.QuestlineRow(instance, key)
    for _, professions in ipairs({ false, true }) do
        for _, row in ipairs(ns.UI.DungeonQuests(instance, nil, professions)) do
            if row.key == key then return row end
        end
    end
end

-- The note marking a dungeon quest folded under the questline row keyed
-- `key` in `instance`'s quest lists as that questline's goal ("The goal
-- ·  Step 3 of 4  ·  2 steps away", UI/DungeonQuestlines.lua), or nil.
function Folds.GoalNote(instance, key, quest)
    local row = key and Folds.QuestlineRow(instance, key)
    return row and ns.UI.DungeonQuestlines.GoalNote(row.questline, quest)
end

-- A goal's row (`note`, Folds.GoalNote) is marked as its questline's page
-- marks the goal: a purple bar down its left, a purple tint, the portal
-- before its name and the note under it in the goal's words colour. A
-- `note` of nil takes the mark off a row used for another.
local GOAL_BAR = 3 -- the bar's width
function Folds.ShowGoal(row, note)
    if note and not row.goalBar then
        row.goalTint = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.goalTint:SetAllPoints()
        row.goalBar = row:CreateTexture(nil, "ARTWORK")
        row.goalBar:SetPoint("TOPLEFT")
        row.goalBar:SetPoint("BOTTOMLEFT")
        row.goalBar:SetWidth(GOAL_BAR)
    end
    if not row.goalBar then return end
    row.goalBar:SetShown(note ~= nil)
    row.goalTint:SetShown(note ~= nil)
    if not note then return end
    row.goalTint:SetColorTexture(unpack(Theme.color.goalFill))
    row.goalBar:SetColorTexture(unpack(Theme.color.goal))
    row.title:SetText(Theme.portalMark .. " " .. (row.title:GetText() or ""))
    row.note:SetText(note)
    Theme:SetTextColor(row.note, Theme.color.goalText)
end

-- The recipe filter ("Filter recipes" on the Professions tab) matches a
-- recipe's name, the names of its materials or the buffs its food gives.
-- Material names come from the game in the client's language, by item ID,
-- and only once it has sent the item. They are kept here lowercase, so a
-- keystroke doesn't ask the game for every material of every recipe again.
local materialNames = {}       -- item ID -> its name, lowercase
local materialNamesAsked = {}  -- item ID -> true once its name was asked for

-- A material's name, lowercase, or nil while the game hasn't sent the item.
-- Then it is asked for, once per item (one the game never sends isn't asked
-- for on every keystroke), and `onNameArrives` runs when it comes.
local function MaterialName(itemID, onNameArrives)
    if materialNames[itemID] then return materialNames[itemID] end
    local name = C_Item.GetItemNameByID(itemID)
    if name then
        materialNames[itemID] = name:lower()
        return materialNames[itemID]
    end
    if not materialNamesAsked[itemID] then
        materialNamesAsked[itemID] = true
        ns.Items:Load(itemID, onNameArrives)
    end
    return nil
end

-- The forms of a filter (lowercase, trimmed) that count: as typed, and with
-- its last word made singular, so "copper bars" finds Copper Bar, "boxes"
-- Box and "berries" Berry. The rules are English ones, but they apply on
-- every client: there they may add a form ("épées" also tries "épée"), and
-- the filter as typed still counts. Words under 4 letters and "ss" endings
-- ("glass") keep their s, so short filters don't lose a letter.
local function FilterForms(filter)
    local forms = { filter }
    local before, last = filter:match("^(.-)(%S+)$")
    if not last or #last < 4 or last:find("ss$") then return forms end
    local singular
    if #last >= 5 and last:find("ies$") then
        singular = last:sub(1, -4) .. "y"
    elseif last:find("[sxz]es$") or last:find("[cs]hes$") then
        singular = last:sub(1, -3)
    elseif last:find("s$") then
        singular = last:sub(1, -2)
    end
    if singular then table.insert(forms, before .. singular) end
    return forms
end

-- Whether any of the filter's forms matches `name` (ns.UI.WordsMatch).
local function AnyFormMatches(name, forms)
    for _, form in ipairs(forms) do
        if ns.UI.WordsMatch(name, form) then return true end
    end
    return false
end

-- Whether any of a recipe's materials has a name the filter matches.
local function MaterialMatches(encounter, forms, onNameArrives)
    for _, reagent in ipairs(encounter.reagents or NO_ROWS) do
        local name = MaterialName(reagent.itemID, onNameArrives)
        if name and AnyFormMatches(name, forms) then return true end
    end
    return false
end

-- Whether the filter names a buff eating what the recipe makes gives
-- (Cooking's "Stamina"): the game's own word for it, in the player's
-- language (RecipeBand's BuffLabel), so a German player finds it with
-- "Ausdauer".
local function BuffMatches(encounter, forms)
    local RecipeBand = ns.RecipeBand
    for _, key in ipairs(RecipeBand.Buffs(encounter) or NO_ROWS) do
        local label = RecipeBand.BuffLabel(key)
        if label and AnyFormMatches(label, forms) then return true end
    end
    return false
end

-- Whether a recipe uses one of the `made` items (item ID -> true) or a
-- material named exactly as the filter: an exact match's Included In.
local function UsesExactly(encounter, made, forms, onNameArrives)
    for _, reagent in ipairs(encounter.reagents or NO_ROWS) do
        if made[reagent.itemID] then return true end
        local name = MaterialName(reagent.itemID, onNameArrives)
        if name and tContains(forms, name) then return true end
    end
    return false
end

-- The recipes outside `exact` and `named` (the filter's matches by name)
-- that use what an exact match makes, or a material named exactly as the
-- filter: the exact match's Included In group.
local function IncludedIn(list, exact, named, forms, onNameArrives)
    local made, listed = {}, {}
    for _, encounter in ipairs(exact) do
        local itemID = RecipeProduct(encounter)
        if itemID then made[itemID] = true end
        listed[encounter] = true
    end
    for _, encounter in ipairs(named) do listed[encounter] = true end
    local included = {}
    for _, encounter in ipairs(list) do
        if not listed[encounter] and UsesExactly(encounter, made, forms, onNameArrives) then
            table.insert(included, encounter)
        end
    end
    return included
end

-- A filtered recipe list for `filter` (lowercase): the recipes whose names
-- match, an exact match first, then the recipes with a material whose name
-- matches, then those whose food gives a buff the filter names. When a
-- name matches exactly, also its Included In group (IncludedIn), whose
-- recipes aren't listed again among the matches; nil otherwise. A material
-- name the game hasn't sent yet is asked for, and `onNameArrives` runs as
-- it comes, so the filter can run again.
local function RecipeMatches(list, filter, onNameArrives)
    local forms = FilterForms(filter:match("^%s*(.-)%s*$"))
    local exact, named, byMaterial, byBuff = {}, {}, {}, {}
    for _, encounter in ipairs(list) do
        local name = encounter.name:lower()
        if tContains(forms, name) then
            table.insert(exact, encounter)
        elseif AnyFormMatches(name, forms) then
            table.insert(named, encounter)
        elseif MaterialMatches(encounter, forms, onNameArrives) then
            table.insert(byMaterial, encounter)
        elseif BuffMatches(encounter, forms) then
            table.insert(byBuff, encounter)
        end
    end
    local included = #exact > 0 and IncludedIn(list, exact, named, forms, onNameArrives) or NO_ROWS
    local matches = exact
    for _, encounter in ipairs(named) do table.insert(matches, encounter) end
    for _, group in ipairs({ byMaterial, byBuff }) do
        for _, encounter in ipairs(group) do
            if not tContains(included, encounter) then table.insert(matches, encounter) end
        end
    end
    return matches, #included > 0 and included or nil
end

-- How the encounter list's groups start before the player opens or shuts
-- them: a dungeon's Encounters open and its Quests shut (wings, questlines
-- and colour sets shut too), a profession's Recipes open and its Scarce
-- Reagents shut, and in a set list folded by class (UI/TierSets.lua) the
-- player's own class open and the others shut. A metatable, so a
-- remembered table holds only the groups that changed (and with Remember
-- sections kept for the whole account, each character still starts on
-- their own class).
local GROUPS_OPEN_AT_START = { ENCOUNTERS = true, QUESTS = false, PROFQUESTS = false, RECIPES = true, SCARCE = false }
local GROUP_START = { __index = function(_, key)
    if GROUPS_OPEN_AT_START[key] ~= nil then return GROUPS_OPEN_AT_START[key] end
    local playerFoldKey = ns.UI.TierSets.PlayerFoldKey()
    if playerFoldKey and key == playerFoldKey then return true end
end }

-- CreateEncounterList's closures share its locals, and with the file-level
-- names it reads that comes close to Lua 5.1's limit of 60 upvalues per
-- function (past it the file won't load). Helpers that need no list state
-- live above, at file level, and related sizes and helpers are grouped in
-- tables (ROW, INDENT, SIDE_TOGGLE, OverviewRow, Folds) that each count as
-- one, to keep it well under: 42 in v0.16.0 (`luac5.1 -l -l -p` lists them).
function ns.UI.CreateEncounterList(parent)
    local pane
    -- A recipe filter's matches, drawn as plain rows above Included In.
    local topRow = {}
    local headers = INSTANCE_HEADERS
    local groupOf = {}  -- entry -> the key of the group it is listed under
    local parentOf = {} -- a wing's or colour set's key -> the group it sits in ("ENCOUNTERS")
    -- Group key -> whether it is open, for the instance shown; GROUP_START
    -- for any not opened or shut yet. While Settings' "Remember sections"
    -- is on, it is the instance's table in ns.SectionMemory's "list" area,
    -- so each instance's groups come back as they were left, whatever
    -- opened or shut them; off, they start over each time another instance
    -- shows.
    local open
    local function TakeGroups(instance)
        local isRemembered = instance ~= nil and ns.SectionMemory.IsRemembering()
        open = setmetatable(isRemembered and ns.SectionMemory.Area("list", instance.id) or {}, GROUP_START)
    end
    TakeGroups(nil)

    -- A recipe folded under a colour set's row: its group key is "SET:..".
    local function InColourSet(entry)
        return (groupOf[entry] or ""):match("^SET:") ~= nil
    end

    -- A set folded under its class's row in a set list: its group key is "CLASS:..".
    local function InClassFold(entry)
        return (groupOf[entry] or ""):match("^CLASS:") ~= nil
    end

    -- A quest folded under its questline's row: its group key is "QUESTLINE:..".
    local function InQuestline(entry)
        return (groupOf[entry] or ""):match("^QUESTLINE:") ~= nil
    end

    -- Lists worked out once per instance and kept while the instance is.
    local kept = setmetatable({}, { __mode = "k" })
    local function Kept(instance, key, Build)
        kept[instance] = kept[instance] or {}
        kept[instance][key] = kept[instance][key] or Build(instance)
        return kept[instance][key]
    end

    -- An instance made of wings (Data.lua's MergeWings) folds each wing's
    -- encounters out of a row of its own under Encounters: its key is
    -- "WING:" .. the wing's name.
    local function BuildWingHeaders(instance)
        local list = {}
        for _, wing in ipairs(instance.wings) do
            local wingRow = { wingHeader = true, key = "WING:" .. wing, name = wing, wingEncounters = {} }
            for _, encounter in ipairs(instance.encounters) do
                if encounter.wing == wing then table.insert(wingRow.wingEncounters, encounter) end
            end
            table.insert(list, wingRow)
        end
        return list
    end

    -- The Encounters group's rows: All drops first in a dungeon or raid,
    -- the Overview left out (it has a row of its own above the groups).
    local function BuildEncounters(instance)
        local list = {}
        if instance.category == "DUNGEON" or instance.category == "RAID" then
            table.insert(list, ns.UI.AllDrops(instance))
        end
        for _, encounter in ipairs(instance.encounters) do
            if not encounter.overview then table.insert(list, encounter) end
        end
        return list
    end

    -- The rows under group `key`.
    local function Kids(key)
        local instance = pane.instance
        if key == "QUESTS" then return ns.UI.DungeonQuests(instance) end
        if key == "PROFQUESTS" then return ns.UI.DungeonQuests(instance, nil, true) end
        if key == "RECIPES" then return pane.recipeRows or instance.encounters end
        -- A colour set's members (UI/RecipeBand.lua).
        if key:match("^SET:") then
            local setRow = pane.setRows and pane.setRows[key]
            return setRow and setRow.members or NO_ROWS
        end
        if key == "SCARCE" then return ns.Data:Scarce(instance.id) end
        -- A questline's quests (UI/DungeonQuestlines.lua).
        if key:match("^QUESTLINE:") then
            local row = Folds.QuestlineRow(instance, key)
            return row and row.foldQuests or NO_ROWS
        end
        if key == "INCLUDED" then return pane.includedRows or pane.included or NO_ROWS end
        -- A class's sets in a set list (UI/TierSets.lua).
        if key:match("^CLASS:") then
            for _, row in ipairs(pane.classFolds or NO_ROWS) do
                if row.key == key then return row.members end
            end
            return NO_ROWS
        end
        if not key:match("^WING:") then return Kept(instance, "ENCOUNTERS", BuildEncounters) end
        for _, wingRow in ipairs(Kept(instance, "WINGS", BuildWingHeaders)) do
            if wingRow.key == key then return wingRow.wingEncounters end
        end
        return NO_ROWS
    end

    -- In a dungeon the Overview row is drawn like a group header, and so is
    -- This run (UI/RunPage.lua, local checkouts only), which opens a page too.
    local function HeaderLike(entry)
        return entry.header or (pane.grouped and (entry.overview or entry.runPage))
    end

    -- The header whose page the content pane shows: the Overview (a raid's
    -- quests, its attunement steps, open from there too), Quests or
    -- Encounters; nil when none is.
    local function ActiveHeader()
        local state, instance = ns.UI.state, pane.instance
        if not (pane.grouped and instance) then return nil end
        local key
        if pane.included then
            key = state.encounter and groupOf[state.encounter]
        elseif instance.category == "PROFESSION" then
            -- The Overview, above the list, lights its own row.
            if state.encounter and state.encounter.professionOverview then return nil end
            key = state.encounter and (state.encounter.scarce and "SCARCE" or "RECIPES")
        elseif state.quest ~= nil and HasQuestsGroup(instance) then
            key = state.quest.profession and "PROFQUESTS" or "QUESTS"
        elseif state.questline ~= nil and instance.category == "DUNGEON" then
            key = state.questline.groupKey
        elseif state.encounter ~= nil and state.encounter.runPage then
            return state.encounter
        elseif state.encounter ~= nil and not state.encounter.overview then
            key = "ENCOUNTERS"
        elseif state.quest ~= nil or (state.encounter and state.encounter.overview) then
            for _, encounter in ipairs(instance.encounters) do
                if encounter.overview then return encounter end
            end
            return nil
        end
        for _, header in ipairs(headers) do
            if header.key == key then return header end
        end
    end

    -- Whether `entry` is the active header or one of the rows under it.
    local function InSection(entry, active)
        if not active then return false end
        if entry == active then return true end
        local group = groupOf[entry]
        return group ~= nil and active.header and (group == active.key or parentOf[group] == active.key)
    end

    -- The active section's card (Theme:SectionCard), made with the list.
    local card
    -- The selected boss in a dungeon or raid wears its portrait like a boss
    -- on the map's floor, and a gold name: a pin { encounter, x, y, display
    -- ID } for its mini pin, or nil for other rows (and for shared loot
    -- pools, which have no boss to show). Trash Drops wear a scrap icon.
    local function SelectedPin(entry)
        -- All drops always wears its chest, greyed (grey = true) unless selected.
        if entry.allDrops and pane.grouped then
            return { entry, 0, 0, ALL_DROPS_ICON, grey = ns.UI.state.encounter ~= entry or nil }
        end
        if not pane.grouped or ns.UI.state.encounter ~= entry or HeaderLike(entry)
            or entry.wingHeader or entry.quest or entry.marker then return nil end
        if entry.id == "TRASH" then return { entry, 0, 0, TRASH_ICON } end
        local boss = ns.Data:Bosses(pane.instance, entry)
        boss = boss and boss[1]
        if not boss then return nil end
        return { entry, 0, 0, boss[2] and boss[2] > 0 and boss[2] or nil }
    end

    -- A dungeon or raid boss's level: "Level 19", "Level 60-62" for a
    -- council, "Level ??" for a skull; nil for rows that aren't bosses.
    -- The number is colored against your level, like the instance list's.
    -- The second value says whether the boss is a rare.
    local function BossLevel(entry)
        local instance = pane.instance
        if not instance or (instance.category ~= "DUNGEON" and instance.category ~= "RAID")
            or entry.overview or entry.header or entry.wingHeader then return nil end
        local minLevel, maxLevel, rare
        for _, boss in ipairs(ns.Data:Bosses(instance, entry) or {}) do
            local level = boss[3]
            if level == -1 then return L["Level ??"], rare end
            if level then
                minLevel, maxLevel = math.min(minLevel or level, level), math.max(maxLevel or level, level)
            end
            rare = rare or boss[4] == "rare" or boss[4] == "rareelite"
        end
        if not minLevel then return nil end
        local levels = Theme:ColorCode(LevelColor(minLevel, maxLevel)) .. LevelText(minLevel, maxLevel) .. "|r"
        return L["Level %s"]:format(levels), rare
    end

    -- The small line under a row's name: a quest's status, or under an
    -- encounter its level and "rare" ("Level 19  ·  rare"), "zone-wide",
    -- "you". The data's own tags "new" and "use" are words for the player too.
    local NOTE_WORDS = { new = L["new"], use = L["use"] }
    local function Note(entry)
        if entry.quest then return ns.UI.QuestStatusText[(ns.UI.QuestStatus(entry.quest))] end
        -- A questline's row: where the player stands on it.
        if entry.isFold then return entry.note end
        -- A colour set's row: its colours; its members on show: no note.
        if IsSetRow(entry) then return ns.RecipeBand:Note(entry) end
        if InColourSet(entry) then return nil end
        -- A class's row in a set list: what it holds; its sets: their tier
        -- as the data writes it ("T1", "AQ40"), nothing when it names only
        -- the class (Zul'Gurub's).
        if entry.classFold then return ns.UI.TierSets.FoldNote(entry) end
        if InClassFold(entry) then return ns.UI.TierSets.TierOf(entry) end
        if entry.marker then return nil end
        local note = entry.note and (NOTE_WORDS[entry.note] or entry.note:lower())
        local level, rare = BossLevel(entry)
        if level then
            note = note or (rare and L["rare"] or nil)
            return note and level .. Theme.DOTS .. note or level
        end
        return note or (entry == pane.reached and L["you"] or nil)
    end

    -- A row's height before any wrapped title's extra line.
    local function RowHeight(entry)
        if entry.marker then return ROW.MARKER end
        -- Recipes showing what they make are all as tall as a row with
        -- a note ("new"), so the rings sit evenly spaced.
        local tall = Note(entry) or RecipeIconFor(entry, pane.instance) or entry.allDrops
        if not pane.grouped or topRow[entry] then
            -- Rows with a note (a boss's level, "zone-wide", "you") are two lines tall.
            return tall and ROW.NOTE or nil
        end
        if HeaderLike(entry) then return ROW.GROUP end
        return tall and ROW.CHILD_NOTE or ROW.CHILD
    end

    -- A quest row hovered: its markers on the map on show pulse gold.
    local function HookQuestGlow(row)
        row.questGlow = true
        row:HookScript("OnEnter", function(self)
            local quest = self.entry and self.entry.quest
            if quest then ns.UI.overview:GlowQuest(quest) end
        end)
        row:HookScript("OnLeave", function(self)
            if self.entry and self.entry.quest then ns.UI.overview:GlowQuest(nil) end
        end)
    end

    -- The Quests header's Alliance / Horde toggle, left of the count, when
    -- some quests are one side's only. Returns whether it shows.
    local function ShowSideToggle(row, header)
        local sides = header.key == "QUESTS" and ns.UI.HasSideQuests(pane.instance)
        if sides then
            -- Picking a side while Quests is shut also opens it.
            SideToggleOf(row, function(side)
                ns.UI:SetQuestSide(side)
                if not open.QUESTS then pane:ToggleGroup("QUESTS") end
            end)
        end
        if row.sideToggle then
            row.sideToggle:SetShown(sides)
            if sides then row.sideToggle:SetSide(ns.UI.QuestSide()) end
        end
        return sides
    end

    -- Other classes' quests aren't counted: "None" when they're all there
    -- is. The count is spelled out under the title, open or shut, so the
    -- side toggle never moves (clicking it opens the list under the cursor).
    local function ShowQuestCount(row, header, sides)
        local done, total = ns.UI.QuestCount(pane.instance, header.key)
        if total == 0 then
            row.note:SetText(L["None"])
        elseif sides or header.key == "PROFQUESTS" then
            -- Beside the Alliance / Horde toggle there's only room for the
            -- short count, kept clear of it; Profession Quests reads the
            -- same as Quests.
            row.note:SetText(L["%d/%d complete"]:format(done, total))
        else
            row.note:SetText((total == 1 and L["1 quest  ·  %d complete"] or L["%d quests  ·  %d complete"])
                :format(total == 1 and done or total, done))
        end
        if not sides then return end
        row.note:SetPoint("RIGHT", row.sideToggle, "LEFT", -SIDE_TOGGLE.GAP, 0)
        row.sideToggle:SetPoint("RIGHT", row.right, "LEFT", SIDE_TOGGLE.NUDGE, 0)
    end

    local function SetupHeaderRow(row, header)
        if not row.disc then NewHeaderDisc(row) end
        if not row.shutFill then NewShutCard(row) end
        -- Kept in line with the other headers' discs inside the card.
        row.disc:SetPoint("CENTER", row, "LEFT", Size.pad + DISC / 2 - row.inset, 0)
        -- One with a badge drawn a little bigger, to hold its own beside it.
        local iconSize = header.badge and DISC_ICON * 1.1 or DISC_ICON
        Theme:FitAtlas(row.icon, header.overview and OVERVIEW_ATLAS or header.atlas, iconSize)
        if header.badge then Theme:FitAtlas(row.badge, header.badge, DISC_ICON * 0.68) end
        row.badge:SetShown(header.badge ~= nil)
        row.indent = DISC + 6
        row.right:SetPoint("RIGHT", row.arrow, "LEFT", -6, 0)
        local sides = ShowSideToggle(row, header)
        local kids = (header.overview or header.runPage) and NO_ROWS or Kids(header.key)
        row.arrow:SetOpen(open[header.key])
        row.arrow:SetShown(#kids > 0)
        -- Included In counts its rows at the right; the quest groups count
        -- theirs under the title.
        if header.key == "INCLUDED" then row.right:SetText(#kids) end
        if header.key == "QUESTS" or header.key == "PROFQUESTS" then ShowQuestCount(row, header, sides) end
        Theme:SetTextColor(row.right, Theme.color.muted)
        -- This run's figure: its bosses down and how long it took.
        if header.runPage then ns.RunPage.ShowHeaderFigure(row, pane.instance) end
    end

    -- A boss on the floor the map shows carries a small copy of its map pin
    -- at the right; the name stops short of it. Recipes show the skill they
    -- need there, and a colour set's row the sections' arrow.
    local function SetupEncounterRow(row, encounter)
        local pin = ns.UI.MapFloorPin(encounter) or SelectedPin(encounter)
        if pin and not row.miniPin then row.miniPin = ns.UI.MiniPin(row, FLOOR_PIN) end
        if row.miniPin then
            -- Where it sits in the active section's card, card or not, so
            -- All drops' chest doesn't move when the card appears.
            row.miniPin:ClearAllPoints()
            row.miniPin:SetPoint("RIGHT", -Size.pad + 4 - (CARD_INSET - (row.inset or 0)), 0)
            row.miniPin:SetShown(pin ~= nil)
            if pin then
                local size = math.min(FLOOR_PIN, row:GetHeight())
                row.miniPin:SetSize(size, size)
                ns.UI.SetMiniPin(row.miniPin, pin)
                row.miniPin.portrait:SetDesaturated(pin.grey == true)
                row.miniPin:SetAlpha(pin.grey and 0.55 or 1)
            end
        end
        if pin then
            row.right:SetPoint("RIGHT", row.miniPin, "LEFT", -2, 0)
        else
            row.right:SetPoint("RIGHT", -Size.pad, 0)
        end
        -- A set's row has the sections' arrow at its right, turned open or
        -- shut, its skill just left of it.
        local isSetRow = IsSetRow(encounter)
        if isSetRow and not row.setArrow then
            row.setArrow = Theme:Arrow(row, true)
            row.setArrow:SetPoint("RIGHT", -Size.pad + 2, 0)
        end
        if row.setArrow then
            row.setArrow:SetShown(isSetRow)
            if isSetRow then
                row.setArrow:SetOpen(open[encounter.key])
                row.right:SetPoint("RIGHT", row.setArrow, "LEFT", -6, 0)
            end
        end
        -- A set's members leave the skill to their set row.
        row.right:SetText(not InColourSet(encounter) and encounter.skill and encounter.skill[1] or "")
        -- In the character's skill colour while they have the profession.
        Theme:SetTextColor(row.right, ns.RecipeBand:SkillColor(encounter, pane.instance) or Theme.color.muted)
        -- A boss killed in the run This run shows: a tick and the time (UI/RunPage.lua, local checkouts only).
        if ns.RunPage then ns.RunPage.ShowKillTime(row, pane.instance, encounter) end
    end

    -- A dot on a series row's variant picker (UI/RecipeBand.lua): the
    -- series shows that variant's pieces, opened.
    local function PickVariant(setRow, word)
        ns.RecipeBand:Choose(setRow, word)
        rawset(setRow, "name", ns.RecipeBand:Name(setRow))
        open[setRow.key] = true
        pane:Rebuild()
    end

    local function SetupRow(row, entry)
        if not row.questGlow then HookQuestGlow(row) end
        local isHeader = HeaderLike(entry)
        local child = pane.grouped and not isHeader and not topRow[entry]
        if row.marker then row.marker:Hide() end
        if row.setArrow then row.setArrow:Hide() end  -- a set's row shows it again
        if row.foldBadge then row.foldBadge:Hide() end  -- a class's row in a set list shows it again
        row:EnableMouse(not entry.marker)
        row.indent = child and ((entry.wing or InQuestline(entry)) and INDENT.FOLD or INDENT.CHILD) or 0
        if InColourSet(entry) or InClassFold(entry) then row.indent = row.indent + INDENT.SET_MEMBER end
        row.titleReserve = nil
        ShowRankIcon(row, entry, pane.instance)
        ShowRecipeIcon(row, entry, pane.instance)
        local quest = not isHeader and entry.quest
        local class = quest and Theme:ClassToken(quest.classes)
        local inside = quest and ns.UI.QuestStartsInside(quest, pane.instance)
        local shareable = quest and ns.Data:QuestShareable(quest)
        ShowQuestIcons(row, quest, class, inside, shareable)
        row.title:SetFontObject(isHeader and Theme.font.section or Theme.font.body)
        row.title:SetText(entry.name)
        row.note:SetText(not isHeader and Note(entry) or nil)
        Theme:SetTextColor(row.note, Theme.color.note)
        row.note:ClearAllPoints()
        row.note:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
        ns.RecipeBand:ShowPicker(row, entry, PickVariant)
        ShowArrows(row, entry, isHeader)
        if row.disc then row.disc:SetShown(isHeader) end
        if row.shutFill and not isHeader then
            row.shut = false
            row:PaintShut()
        end
        if row.sideToggle and not isHeader then row.sideToggle:Hide() end
        row.right:SetText("")  -- the figure at the right: only Included In's count and a recipe's skill
        if isHeader then
            SetupHeaderRow(row, entry)
        elseif entry.wingHeader then
            -- A wing's row: its name, and the arrow that folds it out.
            row.right:SetPoint("RIGHT", row.arrow, "LEFT", -6, 0)
            row.arrow:SetOpen(open[entry.key])
        elseif entry.isFold then
            ns.UI.DungeonQuestlines.UpdateRow(entry)
            Folds.ShowRow(row, entry, open[entry.key])
        elseif entry.classFold then
            Folds.ShowClassRow(row, entry, open[entry.key])
        elseif entry.marker then
            -- The line over other classes' quests.
            row.title:SetText(nil)
            MarkerLine(row, entry.name)
        elseif quest then
            SetupQuestRow(row, entry, class, inside, shareable)
        else
            SetupEncounterRow(row, entry)
        end
        if row.miniPin and (isHeader or entry.wingHeader or entry.quest or entry.marker or entry.isFold
            or entry.classFold) then
            row.miniPin:Hide()
        end
        local goalNote = quest and InQuestline(entry) and Folds.GoalNote(pane.instance, groupOf[entry], quest)
        Folds.ShowGoal(row, goalNote or nil)
    end

    -- While a layout map is open, the bosses pinned on the floor it shows
    -- are lit, and a wing holding any of them, so a shut wing still says so.
    local function LitByMapFloor(entry)
        if HeaderLike(entry) or entry.marker then return false end
        if not entry.wingHeader then return ns.UI.OnMapFloor(entry) end
        for _, kid in ipairs(entry.wingEncounters) do
            if ns.UI.OnMapFloor(kid) then return true end
        end
        return false
    end

    local function AfterRow(row, entry)
        -- A shut colour set holding the selected recipe has a gold name.
        if IsSetRow(entry) then
            if not open[entry.key] and ns.RecipeBand:Holds(entry, ns.UI.state.encounter) then
                Theme:SetTextColor(row.title, Theme.color.heading)
            end
            return
        end
        -- A questline's name is gold, as on the Classes tab.
        if entry.isFold then
            Theme:SetTextColor(row.title, Theme.color.heading)
            return
        end
        -- A class's name in its class colour, as on the Classes tab.
        if entry.classFold then
            ns.UI.SetClassColor(row.title, entry.token)
            return
        end
        -- The bosses on the map's floor have gold names and their mini pins
        -- (setupRow), as does the selected boss.
        local onFloor = LitByMapFloor(entry)
        local selected = SelectedPin(entry)
        if (onFloor and ns.UI.state.encounter ~= entry) or (selected and not selected.grey) then
            Theme:SetTextColor(row.title, Theme.color.heading)
        end
        if onFloor then return end
        -- A boss on another floor, while the map shows one, fades back.
        local isEncounter = not HeaderLike(entry) and not entry.wingHeader
            and not entry.quest and not entry.marker
        if isEncounter and ns.UI.MapFloorShown() and ns.UI.state.encounter ~= entry then
            row:SetAlpha(row:GetAlpha() * 0.4)
        end
        if pane.grouped and HeaderLike(entry) then PaintHeader(row, entry == ActiveHeader()) end
    end

    pane = CreateList(parent, {
        label = L["Encounters"],
        rowHeight = Size.row,
        right = true,
        note = true,
        entryHeight = RowHeight,
        setupRow = SetupRow,
        afterRow = AfterRow,
        rowInset = function(entry)
            local inCard = InSection(entry, ActiveHeader()) or (pane.grouped and HeaderLike(entry))
            return inCard and CARD_INSET or 0
        end,
        afterRefresh = function()
            card = card or Theme:SectionCard(pane.canvas)
            if pane.grouped then UpdateSectionCard(pane, card, ActiveHeader(), HeaderLike) else card:Hide() end
            OverviewRow.Paint(pane)
        end,
        isSelected = function(entry)
            if HeaderLike(entry) or entry.wingHeader or IsSetRow(entry) then return false end
            if entry.quest then return ns.UI.state.quest == entry.quest end
            if entry.isFold then return ns.UI.state.questline == entry.questline end
            return ns.UI.state.encounter == entry
        end,
        onClick = function(entry)
            -- A colour set only opens or shuts; Shift+click does nothing.
            if IsSetRow(entry) and IsShiftKeyDown() then return end
            -- A questline's row opens its page and slides its quests open;
            -- once its page shows, it opens or shuts them.
            local isShownQuestline = entry.isFold and ns.UI.state.questline == entry.questline
            if entry.header or entry.wingHeader or IsSetRow(entry) or entry.classFold or isShownQuestline then
                pane:ToggleGroup(entry.key)
                return
            end
            -- Dev edit's quest tool marks the quest instead of opening it.
            if entry.quest and ns.MapEdit:QuestClick(pane.instance, entry.quest, "LeftButton") then return end
            ns.UI:ClearHistory()
            if entry.isFold then
                ns.UI:SelectQuestline(entry.questline)
                if not open[entry.key] then pane:ToggleGroup(entry.key) end
                return
            end
            if entry.quest then
                ns.UI:SelectQuest(entry.quest)
                return
            end
            -- Shift+Click on a recipe searches for exactly its name.
            if IsShiftKeyDown() then ns.UI:FilterToRecipe(entry) end
            ns.UI:SelectEncounter(entry)
        end,
        -- Alt+right-click on a quest in dev edit takes its portal off.
        onRightClick = ns.MapEdit.available and function(entry)
            if entry.quest then ns.MapEdit:QuestClick(pane.instance, entry.quest, "RightButton") end
        end or nil,
    })

    -- Material names the game sends after the filter ran (RecipeMatches
    -- asked for them) arrive in bursts. NAME_BURST_SECONDS after the first
    -- of them, the filter runs again once for all that came by then, if it
    -- is still the one showing, to add the recipes they match. A name that
    -- comes after that run starts the wait again.
    local NAME_BURST_SECONDS = 0.2
    local filterAgainQueued = false
    local function FilterAgainOnceNamesArrive()
        local filter = pane.filter
        if filterAgainQueued or not filter then return end
        filterAgainQueued = true
        C_Timer.After(NAME_BURST_SECONDS, function()
            filterAgainQueued = false
            if pane.filter ~= filter then return end
            pane:SetData(pane.instance)
            ns.UI:ShowRecipeMatches()
        end)
    end

    -- Building the entries: `add(row, key)` puts a row on the list under
    -- group `key` and returns its height, Height(row).
    local function Adder(list, Height)
        return function(entry, key)
            table.insert(list, entry)
            groupOf[entry] = key
            return Height(entry)
        end
    end

    -- Runs addRows() while group `key` is open or sliding; a sliding group's
    -- strip opens to the height it added (pane.anim.total). Returns that height.
    local function AddIfOpen(key, addRows)
        local sliding = pane.anim and pane.anim.key == key
        if not (open[key] or sliding) then return 0 end
        local height = addRows()
        if sliding then pane.anim.total = height end
        return height
    end

    -- `rows` under group `key`, each colour set's or questline's row
    -- followed by the rows folded under it while it is open (or sliding).
    local function AddRows(rows, add, key)
        local height = 0
        for _, entry in ipairs(rows) do
            height = height + add(entry, key)
            local folded = Folds.RowsUnder(entry)
            if folded then
                parentOf[entry.key] = key
                height = height + AddIfOpen(entry.key, function() return AddRows(folded, add, entry.key) end)
            end
        end
        return height
    end

    -- All drops, then each wing's row followed by its encounters while it is
    -- open (or sliding), inside the Encounters group's strip.
    local function AddWings(instance, add, key)
        local height = add(ns.UI.AllDrops(instance), key)
        for _, wingRow in ipairs(Kept(instance, "WINGS", BuildWingHeaders)) do
            height = height + add(wingRow, key)
            parentOf[wingRow.key] = key
            height = height + AddIfOpen(wingRow.key, function()
                return AddRows(wingRow.wingEncounters, add, wingRow.key)
            end)
        end
        return height
    end

    -- The quest groups show in a dungeon (or a collection whose vendor gives
    -- quests), with the Quests module on; Profession Quests only when the
    -- dungeon has some. Recipes shows on a profession with recipes (not Skinning).
    local function ShowsHeader(header, instance)
        if header.key == "RECIPES" then return #instance.encounters > 0 end
        if header.key ~= "QUESTS" and header.key ~= "PROFQUESTS" then return true end
        return HasQuestsGroup(instance) and ns.Modules:IsOn("QUESTS")
            and (header.key == "QUESTS" or #ns.UI.DungeonQuests(instance, nil, true) > 0)
    end

    -- The entries on show: the plain encounter list, or in a dungeon or raid
    -- the Overview, then each group's header followed by its rows while it is
    -- open (or sliding). Raids have no Quests group, and dungeons none while
    -- the Quests module is off in Settings.
    local function Entries()
        local instance = pane.instance
        if not pane.grouped then
            -- A profession filtered to its matches, or a set list folded by class.
            local rows = pane.recipeRows or pane.classFolds
            if rows then
                wipe(groupOf)
                wipe(parentOf)
                local list = {}
                AddRows(rows, Adder(list, function(entry) return pane:EntryHeight(entry) end))
                return list
            end
            local list = instance and instance.encounters
            if list and pane.filter then list = pane.matches end
            return list
        end
        wipe(groupOf)
        wipe(parentOf)
        local list = {}
        if pane.included then
            -- A recipe filter's matches sit above its Included In group.
            AddRows(pane.matchRows or pane.matches,
                Adder(list, function(entry) return pane:EntryHeight(entry) end))
        end
        for _, encounter in ipairs(instance.encounters) do
            if encounter.overview then table.insert(list, encounter) end
        end
        local add = Adder(list, RowHeight)
        -- This run sits just above Encounters (UI/RunPage.lua, local checkouts only).
        local runEntry = ns.RunPage and ns.RunPage.ListEntry(instance)
        for _, header in ipairs(headers) do
            if runEntry and header.key == "ENCOUNTERS" then table.insert(list, runEntry) end
            if ShowsHeader(header, instance) then
                table.insert(list, header)
                AddIfOpen(header.key, function()
                    if header.key == "ENCOUNTERS" and instance.wings then
                        return AddWings(instance, add, header.key)
                    end
                    return AddRows(Kids(header.key), add, header.key)
                end)
            end
        end
        return list
    end

    -- Redraws with the groups as they are now, keeping the scroll position.
    function pane:Rebuild()
        self.entries = Entries() or {}
        self:Refresh()
    end

    -- The setting changed: the instance shown takes its groups from the new set.
    ns.SectionMemory.OnModeChange(function()
        if not pane.instance then return end
        TakeGroups(pane.instance)
        StopSlide(pane)
        pane:Rebuild()
    end)

    -- The group's rows are laid out whole behind a strip that opens (or
    -- closes) over them, and everything below moves with its edge; its open
    -- wings' and colour sets' rows slide with it.
    function pane:ToggleGroup(key)
        if #Kids(key) == 0 then return end
        open[key] = not open[key]
        StartSlide(self, { key = key, total = 0 }, function(entry)
            local group = groupOf[entry]
            return group == key or (group ~= nil and parentOf[group] == key)
        end, open[key])
    end

    -- Opens a wing's group (and Encounters, if shut) and shuts the other
    -- wings: the dungeon map does this for the wing on the floor it shows.
    function pane:OpenWing(wing)
        if not self.grouped then return end
        local key = "WING:" .. wing
        local others = {}
        for other in pairs(open) do
            if other ~= key and other:match("^WING:") and open[other] then
                table.insert(others, other)
            end
        end
        if open[key] and open.ENCOUNTERS then
            -- Already showing: slide the other wing shut.
            if #others == 1 then
                self:ToggleGroup(others[1])
            elseif #others > 1 then
                for _, other in ipairs(others) do open[other] = false end
                self:Rebuild()
            end
            return
        end
        for _, other in ipairs(others) do open[other] = false end
        if open.ENCOUNTERS then
            self:ToggleGroup(key)
        else
            open.ENCOUNTERS, open[key] = true, true
            self:Rebuild()
        end
    end

    -- Slides open the questline row folding `quest` while its group is
    -- open, so the quest picked (from its questline's page) shows its row.
    function pane:OpenFoldOf(quest)
        if not (self.grouped and quest) then return end
        local key = quest.profession and "PROFQUESTS" or "QUESTS"
        local row = open[key] and Folds.RowHolding(Kids(key), quest)
        if row and not open[row.key] then self:ToggleGroup(row.key) end
    end

    -- A profession's slot chips and toggles narrow what the text filter
    -- kept, then its colour sets fold (UI/RecipeBand.lua). The data's own
    -- lists are never changed.
    local function NarrowRecipes(instance)
        local RB = ns.RecipeBand
        local function Fold(list)
            local rows = RB:Fold(list)
            if rows == list then return rows end
            for _, row in ipairs(rows) do
                if IsSetRow(row) then
                    rawset(row, "name", RB:Name(row))
                    pane.setRows[row.key] = row
                end
            end
            return rows
        end
        local base = pane.matches or instance.encounters
        pane.recipeBase = base  -- for the chips' counts
        local narrowed = RB:Narrow(base, instance)
        if pane.matches then pane.matches = narrowed end
        local count = 0
        for _, entry in ipairs(narrowed) do
            if not entry.header and not entry.scarce then count = count + 1 end
        end
        pane.narrowedCount = count
        local rows = Fold(narrowed)
        if pane.matches then pane.matchRows = rows else pane.recipeRows = rows end
        if pane.included then pane.includedRows = Fold(RB:Narrow(pane.included, instance)) end
    end

    -- In a dungeon the group headers stand in for the pane label. A
    -- profession's strip holds the recipe filter and the count of recipes
    -- listed instead of a label (UI/MainFrame.lua), and its Overview row and
    -- filters are in the sidebar left of the list (no filters without
    -- recipes: Skinning).
    local function LayOutTop(instance, recipes)
        local hasStrip = not pane.grouped or recipes or pane.included ~= nil
        pane.label:SetShown(hasStrip and not recipes)
        pane.rule:SetShown(hasStrip)
        pane.listTop = hasStrip and LIST_TOP or 4
        -- Only the window's recipe list has a sidebar (UI/MainFrame.lua).
        if pane.sidebar then
            local RB = ns.RecipeBand
            local filtersTop = RB.SIDEBAR_TOP + OverviewRow.Show(pane, recipes and instance or nil, RB.SIDEBAR_TOP)
            local hasRecipes = recipes and #instance.encounters > 0
            RB:Layout(pane, hasRecipes and instance or nil, filtersTop)
        end
        pane.scrollBar:ClearAllPoints()
        pane.scrollBar:SetPoint("TOPRIGHT", -4, -(pane.listTop + 4))
        pane.scrollBar:SetPoint("BOTTOMRIGHT", -4, 6)
    end

    -- `filter` (lowercase) keeps only the recipes it matches (RecipeMatches).
    local setData = pane.SetData
    function pane:SetData(instance)
        if instance ~= self.instance then TakeGroups(instance) end
        self.instance = instance
        self.reached = ReachedGroup(instance)
        local profession = HasScarce(instance)
        -- A recipe filter lists the matching recipes alone, with an
        -- Included In group when it names one exactly.
        self.matches, self.included = nil, nil
        self.recipeRows, self.matchRows, self.includedRows, self.narrowedCount = nil, nil, nil, nil
        local recipes = instance and instance.category == "PROFESSION"
        if recipes and self.filter then
            self.matches, self.included = RecipeMatches(instance.encounters, self.filter, FilterAgainOnceNamesArrive)
        end
        self.setRows = {}
        self.classFolds = ns.UI.TierSets.ClassFolds(instance)
        if recipes then NarrowRecipes(instance) end
        wipe(topRow)
        if self.included then
            for _, entry in ipairs(self.matches) do topRow[entry] = true end
            for _, entry in ipairs(self.matchRows or NO_ROWS) do topRow[entry] = true end
        end
        local vendorQuests = HasQuestsGroup(instance) and instance.category == "COLLECTION"
        self.grouped = instance ~= nil and (instance.category == "DUNGEON" or instance.category == "RAID"
            or (profession and not self.filter) or self.included ~= nil or vendorQuests)
        headers = self.included and INCLUDED_HEADERS or profession and PROFESSION_HEADERS
            or vendorQuests and VENDOR_HEADERS or INSTANCE_HEADERS
        StopSlide(self)
        LayOutTop(instance, recipes)
        setData(self, Entries())
    end

    -- The group `entry` is listed under, in a grouped list; nil for a
    -- filter's matches, which are always on show.
    local function GroupKeyFor(entry)
        if pane.included then return not topRow[entry] and "INCLUDED" or nil end
        if pane.instance.category == "PROFESSION" then return entry.scarce and "SCARCE" or "RECIPES" end
        if entry.quest then return entry.quest.profession and "PROFQUESTS" or "QUESTS" end
        return "ENCOUNTERS"
    end

    -- Scrolling to a quest or encounter opens its group first.
    local scrollTo = pane.ScrollTo
    function pane:ScrollTo(entry)
        if self.grouped and entry and not entry.overview then
            local key = GroupKeyFor(entry)
            local wing = entry.wing and ("WING:" .. entry.wing)
            if key and (not open[key] or (wing and not open[wing])) then
                open[key] = true
                if wing then open[wing] = true end
                self:Rebuild()
            end
        end
        -- A set in a shut class fold opens it.
        local classFold = entry and self.classFolds and ns.UI.TierSets.FoldHolding(self.classFolds, entry)
        if classFold and not open[classFold.key] then
            open[classFold.key] = true
            self:Rebuild()
        end
        -- A recipe folded in a shut set opens it, picking its variant first.
        local set = entry and self:SetOf(entry)
        local otherVariant = set and not tContains(set.members, entry)
        if otherVariant then
            ns.RecipeBand:Choose(set, entry.tint)
            rawset(set, "name", ns.RecipeBand:Name(set))
        end
        if set and (otherVariant or not open[set.key]) then
            open[set.key] = true
            self:Rebuild()
        end
        scrollTo(self, entry)
    end

    -- The set a set list folded by class opens on (TierSets.StartingSet),
    -- or nil for any other list.
    function pane:StartingSet()
        return self.classFolds and ns.UI.TierSets.StartingSet(self.classFolds, open) or nil
    end

    -- The set row a recipe is folded under on this list, or nil.
    function pane:SetOf(entry)
        for _, setRow in pairs(self.setRows or NO_ROWS) do
            if ns.RecipeBand:Holds(setRow, entry) then return setRow end
        end
    end

    -- The first recipe on the list, past the Recipes / Scarce Reagents
    -- headers, a filter's Included In header and the colour set rows (a
    -- set's first member when only sets are left).
    function pane:FirstRecipe()
        local firstInSet
        for _, entry in ipairs(self.entries) do
            if IsSetRow(entry) then
                firstInSet = firstInSet or entry.members[1]
            elseif not entry.header then
                return entry
            end
        end
        return firstInSet
    end

    -- Whether `entry` is on the list: a row of it, or folded in one of its
    -- colour sets.
    function pane:IsListed(entry)
        if not entry then return false end
        return IndexOf(self.entries, entry) ~= nil or self:SetOf(entry) ~= nil
    end

    function pane:SetFilter(text)
        self.filter = text
        open.INCLUDED = nil  -- each new search starts it shut
        self:SetData(self.instance)
    end

    -- Quest states change when one is taken, handed in or abandoned, and
    -- when an objective moves on (QUEST_WATCH_UPDATE: Ready to turn in).
    -- Objectives move on in bursts (every quest mob of a pull), so the list
    -- redraws once a second after the first of them, not once for each.
    -- With the window shut, the list redraws when it next shows instead.
    local isRecheckQueued = false
    local function Recheck()
        if isRecheckQueued then return end
        isRecheckQueued = true
        C_Timer.After(1, function()
            isRecheckQueued = false
            ns.UI.ForgetQuestStatus()
            if not pane:IsVisible() then
                pane.questsStale = true
            elseif pane.grouped then
                pane:Refresh()
            end
        end)
    end
    pane:HookScript("OnShow", function()
        if not pane.questsStale then return end
        pane.questsStale = nil
        if pane.grouped then pane:Refresh() end
    end)
    ns:On("QUEST_TURNED_IN", Recheck)
    ns:On("QUEST_ACCEPTED", Recheck)
    ns:On("QUEST_REMOVED", Recheck)
    ns:On("QUEST_WATCH_UPDATE", Recheck)
    -- A new level recolors the bosses' levels.
    ns:On("PLAYER_LEVEL_UP", function()
        C_Timer.After(1, function()
            if pane:IsVisible() then pane:Refresh() end
        end)
    end)
    return pane
end

-- A plain list pane (see CreateList above), for tabs that list their own
-- rows: the Classes tab's class column.
ns.UI.CreateList = CreateList

-- A section page with an `icon` (a texture file: a hunter pet family's or a demon's)
-- shows it before its name (round, or square in a square-cornered skin), which moves right of it.
local function ShowPageIcon(row, icon)
    if not icon then return end
    if not row.pageIcon then
        row.pageIcon = row:CreateTexture(nil, "ARTWORK")
        row.pageIcon:SetSize(PAGE_ICON, PAGE_ICON)
        Theme:CropIcon(row.pageIcon)
        Theme:ShapeIcon(row, row.pageIcon)
    end
    row.pageIcon:SetTexture(icon)
    row.pageIcon:ClearAllPoints()
    row.pageIcon:SetPoint("CENTER", row, "LEFT", Size.pad + row.indent - row.inset + PAGE_ICON / 2, 0)
    row.pageIcon:Show()
    row.indent = row.indent + PAGE_ICON + PAGE_ICON_GAP
end

-- A column of sections drawn like a dungeon's Quests and Encounters: the
-- Classes tab's middle column. Each section's header (its icon on a disc, a
-- figure at the right, the section arrow) slides its pages open or shut, and
-- the section whose page shows sits in the active card. A section is
-- { key = ..., name = ..., atlas = ..., pages = { { name = ... }, ... } };
-- another section slots in by adding it to the list given to
-- list:SetSections. A page with a `note` shows it in `muted` under its name
-- on a taller row (a saved talent plan's "Saved plan"), and one marked
-- `isAction` has its name in `muted` ("+ New plan"). A section marked
-- `overview` is a page itself, like a dungeon's Overview row: no pages and
-- no arrow, the dungeon Overview's icon, onSelect(section) on a click, and
-- a closed card while it is active. A page with a `recipe` (a profession-
-- shaped recipe: the Poisons section's) shows what it makes before its name,
-- as the recipe list does. A page marked `isFold` (a questline on the
-- Classes tab, UI/Questlines.lua) opens and shuts the pages whose `inFold`
-- is its key, as a wing's row does, shut to start; its `figure` shows at its
-- right in `figureColor` and its `note` under its name in `noteColor`. A
-- click opens its own page (onSelect) and slides it open; once its page
-- shows, a click opens or shuts it. A page marked `isFoldNote` is a line of
-- text in its fold (what the questline teaches), and one marked `isOr` a
-- small "or" between alternatives, neither a button. A page marked
-- `isBranch` (a part of a questline) shows its `figure` in `figureColor`
-- and its `note`, dimmed while `dimmed`. `opts`: label,
-- headerRight(section) (the figure), pageRight(page) (a page's figure, or
-- nil), pageRightColor(page) (its colour, or nil for muted), isSelected(page),
-- titleIcon(page) (an atlas drawn after a quest page's name, at its line
-- height a space after it, or nil: the rogue's poison quest's mark),
-- onSelect(page), onRightClick(page, row) (or nil), afterRow(row, entry) (or
-- nil: run after every row, header or page, is drawn, for a section's own
-- widgets on its rows), activeKey() (the key of the section whose page
-- shows, or nil) and memoryArea (the ns.SectionMemory area the sections'
-- and folds' open or shut states are kept in: "classes"). After changing a
-- section's pages, list:Rebuild() shows them; list:ChangeSections(list)
-- swaps the sections, keeping the scroll.
function ns.UI.CreateSectionList(parent, opts)
    local pane, card
    local sections = {}
    -- Section or fold key -> whether its pages show, kept as Settings'
    -- "Remember sections" says (ns.SectionMemory's `opts.memoryArea` area).
    local open = ns.SectionMemory.Area(opts.memoryArea)
    local groupOf = {}  -- page -> its section's key

    local function IsHeader(entry) return entry.pages ~= nil end

    local function EntryHeight(entry)
        if IsHeader(entry) then return ROW.GROUP end
        if entry.isOr then return ROW.OR end
        return (entry.note or entry.quest) and ROW.CHILD_NOTE or ROW.CHILD
    end

    -- A fold's pages show while it is open, or sliding open or shut.
    local function IsFoldShowing(page)
        return not page.inFold or open[page.inFold] or (pane.anim ~= nil and pane.anim.key == page.inFold)
    end

    local function ActiveSection()
        local key = opts.activeKey()
        for _, section in ipairs(sections) do
            if section.key == key then return section end
        end
    end

    local function InSection(entry, active)
        return active ~= nil and (entry == active or groupOf[entry] == active.key)
    end

    -- A section with a side (opts.headerSide: the Classes tab's Quests) has
    -- the Alliance / Horde toggle left of its figure; a click runs
    -- opts.onPickSide with the other side and slides the section open.
    -- Hidden on every other row.
    local function ShowHeaderSide(row, section)
        local side = section and opts.headerSide and opts.headerSide(section)
        if not side then
            if row.sideToggle then row.sideToggle:Hide() end
            return
        end
        local toggle = SideToggleOf(row, function(picked)
            opts.onPickSide(picked)
            pane:OpenGroup(section.key)
        end)
        toggle:ClearAllPoints()
        toggle:SetPoint("RIGHT", row.right, "LEFT", -SIDE_TOGGLE.GAP, 0)
        toggle:SetSide(side)
        toggle:Show()
    end

    local function SetupHeaderRow(row, section)
        if not row.disc then NewHeaderDisc(row) end
        if not row.shutFill then NewShutCard(row) end
        row.disc:Show()
        row.disc:SetPoint("CENTER", row, "LEFT", Size.pad + DISC / 2 - row.inset, 0)
        Theme:FitAtlas(row.icon, section.overview and OVERVIEW_ATLAS or section.atlas, DISC_ICON)
        row.badge:Hide()
        row.indent = DISC + 6
        row.right:SetPoint("RIGHT", row.arrow, "LEFT", -6, 0)
        row.right:SetText(opts.headerRight(section) or "")
        row.arrow:SetOpen(open[section.key])
        row.arrow:SetShown(#section.pages > 0)
        ShowHeaderSide(row, section)
    end

    -- A quest's row as a dungeon's Quests group draws it, here with a
    -- chain's later step after its numbered circle: the status under the name, the
    -- people icon of a quest that can be shared, the portal of a quest that
    -- starts inside its dungeon and the insignia of the sides that can take
    -- it; then its figure (the class quest's level)
    -- left of them, level with the name. opts.titleIcon's atlas follows the name.
    local function SetupQuestPage(row, entry)
        local quest = entry.quest
        local inside = ns.UI.QuestStartsInside(quest, quest.dungeon and ns.Data:Get(quest.dungeon))
        local shareable = ns.Data:QuestShareable(quest)
        ShowChainStep(row, entry, false)
        ShowQuestIcons(row, quest, nil, inside, shareable)
        SetupQuestRow(row, entry, nil, inside, shareable)
        local titleIcon = opts.titleIcon and opts.titleIcon(entry)
        if titleIcon then row.title:SetText(TITLE_ICON_MARKUP:format(entry.name, titleIcon)) end
        row.note:SetText(ns.UI.QuestStatusText[(ns.UI.QuestStatus(quest))])
        row.right:SetText(opts.pageRight and opts.pageRight(entry) or "")
        row.right:SetPoint("RIGHT", row.iconEdge, "LEFT", -QUEST_FIGURE_GAP, 6)
        row.titleReserve = row.titleReserve + row.right:GetStringWidth() + QUEST_FIGURE_GAP
    end

    -- A questline's part: its name over its note, its figure level with
    -- the name.
    local function SetupBranchRow(row, entry)
        row.right:SetText(entry.figure or "")
        Theme:SetTextColor(row.right, entry.figureColor or Theme.color.muted)
        row.right:SetPoint("RIGHT", -Size.pad, entry.note and 6 or 0)
        ShowPageNote(row, entry)
    end

    local function SetupRow(row, entry)
        local isHeader = IsHeader(entry)
        row:EnableMouse(not (entry.isFoldNote or entry.isOr))
        row:SetAlpha(entry.dimmed and ns.UI.Questlines.DIM_ALPHA or 1) -- an alternative not taken
        row.titleReserve = nil
        if row.recipeIcon then row.recipeIcon:Hide() end
        row.title:SetFontObject(isHeader and Theme.font.section or Theme.font.body)
        row.title:SetText(entry.name)
        row.note:SetText(nil)
        ShowArrows(row, entry, isHeader)
        Theme:SetTextColor(row.right, Theme.color.muted)
        if row.pageIcon then row.pageIcon:Hide() end
        if not entry.quest then
            -- A row that showed a quest before drops its circle and icons.
            ShowChainStep(row, entry, true)
            ShowQuestIcons(row, nil, nil, false)
        end
        if isHeader then
            SetupHeaderRow(row, entry)
            return
        end
        ShowHeaderSide(row, nil)
        row.indent = entry.inFold and INDENT.FOLD or INDENT.CHILD
        if row.disc then row.disc:Hide() end
        ShowPageIcon(row, entry.icon)
        if row.shutFill then
            row.shut = false
            row:PaintShut()
        end
        if entry.quest then
            SetupQuestPage(row, entry)
            return
        end
        if entry.isFold then
            Folds.ShowRow(row, entry, open[entry.key])
            return
        end
        if entry.isBranch then
            SetupBranchRow(row, entry)
            return
        end
        if entry.isFoldNote or entry.isOr then
            row.title:SetFontObject(Theme.font.note)
            row.right:SetText("")
            row.right:SetPoint("RIGHT", -Size.pad, 0)
            return
        end
        -- The figure stays level with the name, which a note lifts by 6.
        row.right:SetText(opts.pageRight and opts.pageRight(entry) or "")
        row.right:SetPoint("RIGHT", -Size.pad, entry.note and 6 or 0)
        Theme:SetTextColor(row.right, opts.pageRightColor and opts.pageRightColor(entry) or Theme.color.muted)
        if entry.recipe then ShowProductIcon(row, true, RecipeProduct(entry.recipe)) end
        ShowPageNote(row, entry)
    end

    -- The entries on show: each section's header followed by its pages
    -- while it is open (or sliding; a sliding section's or fold's strip
    -- opens to the height its pages add up to, pane.anim.total), a fold's
    -- pages only while it is open too.
    local function Entries()
        wipe(groupOf)
        local list = {}
        local anim = pane.anim
        if anim then anim.total = 0 end
        for _, section in ipairs(sections) do
            table.insert(list, section)
            local sliding = anim and anim.key == section.key
            if open[section.key] or sliding then
                for _, page in ipairs(section.pages) do
                    if IsFoldShowing(page) then
                        table.insert(list, page)
                        groupOf[page] = section.key
                        if sliding or (anim and page.inFold == anim.key) then
                            anim.total = anim.total + EntryHeight(page)
                        end
                    end
                end
            end
        end
        return list
    end

    pane = CreateList(parent, {
        label = opts.label,
        rowHeight = Size.row,
        right = true,
        note = true,
        entryHeight = EntryHeight,
        setupRow = SetupRow,
        afterRow = function(row, entry)
            if IsHeader(entry) then PaintHeader(row, entry == ActiveSection()) end
            if entry.isAction then Theme:SetTextColor(row.title, Theme.color.muted) end
            -- A fold's name is gold, as the Attunement heading is.
            if entry.isFold then Theme:SetTextColor(row.title, Theme.color.heading) end
            if entry.isFoldNote then Theme:SetTextColor(row.title, Theme.color.note) end
            if entry.isOr then Theme:SetTextColor(row.title, Theme.color.faint) end
            if opts.afterRow then opts.afterRow(row, entry) end
        end,
        rowInset = function(entry)
            return (IsHeader(entry) or InSection(entry, ActiveSection())) and CARD_INSET or 0
        end,
        afterRefresh = function()
            card = card or Theme:SectionCard(pane.canvas)
            UpdateSectionCard(pane, card, ActiveSection(), IsHeader)
        end,
        isSelected = function(entry) return not IsHeader(entry) and opts.isSelected(entry) end,
        onClick = function(entry)
            if (IsHeader(entry) and not entry.overview) or (entry.isFold and opts.isSelected(entry)) then
                pane:ToggleGroup(entry.key)
                return
            end
            opts.onSelect(entry)
            if entry.isFold then pane:OpenGroup(entry.key) end
        end,
        onRightClick = opts.onRightClick and function(entry, row)
            if not IsHeader(entry) then opts.onRightClick(entry, row) end
        end,
    })

    -- Redraws with the sections as they are now, keeping the scroll position.
    function pane:Rebuild()
        self.entries = Entries()
        self:Refresh()
    end

    -- Slides section or fold `key` open or shut.
    function pane:ToggleGroup(key)
        open[key] = not open[key]
        local function IsMember(entry) return groupOf[entry] == key or entry.inFold == key end
        StartSlide(self, { key = key, total = 0 }, IsMember, open[key])
    end

    -- Slides section or fold `key` open unless it is already, so a page
    -- opened from elsewhere (the Classes tab's Overview) shows its row.
    function pane:OpenGroup(key)
        if not open[key] then self:ToggleGroup(key) end
    end

    -- Shows `list` (the sections above). Each section keeps whether it was
    -- open, so switching between lists that share sections moves nothing;
    -- a section seen for the first time opens if its page shows.
    local function TakeSections(list)
        sections = list
        local active = ActiveSection()
        for _, section in ipairs(sections) do
            if open[section.key] == nil then open[section.key] = section == active end
        end
        StopSlide(pane)
    end

    function pane:SetSections(list)
        TakeSections(list)
        self:SetData(Entries())
    end

    -- As SetSections, keeping the scroll: another class's list, with or
    -- without a section of its own (the rogue's Poisons, the hunter's Pets).
    function pane:ChangeSections(list)
        TakeSections(list)
        self:Rebuild()
    end

    -- The setting changed: the sections take their states from the new set.
    ns.SectionMemory.OnModeChange(function()
        open = ns.SectionMemory.Area(opts.memoryArea)
        if #sections > 0 then pane:ChangeSections(sections) end
    end)
    return pane
end
