-- The pieces NeedRoll's dev and debug windows are built from (/nr
-- icondebug, /nr framedebug, /nr sounds, /nr loot fished, /nr droptalk), as
-- ns.DevKit: a movable window (and a plain one in the game's own style for
-- /nr devedit and /nr linedump), a scroll area over a modern or native pane
-- background with a switch between them, text recolored with the switch,
-- clickable cells in a grid, and (local checkouts only) a list window. The rest
-- keep the modern skin's look (C, F) whichever style the player picked.
local _, ns = ...
local Theme = ns.Theme

local C = Theme:Palette("modern")
local nativeColors = Theme:Palette("native")
local F = Theme:Fonts("modern")

local WIDTH, HEIGHT = 760, 580  -- a window's size unless it asks for another
local PAD = 16
local HINT_SCROLL_TOP = 66      -- a scroll area's top under the title and Hint's line

-- A faint white wash while the mouse is over `btn`; reads on both backgrounds.
local function Hover(btn)
    btn.hover = btn:CreateTexture(nil, "BACKGROUND")
    btn.hover:SetColorTexture(1, 1, 1, 0.07)
    btn.hover:SetAllPoints()
    btn.hover:Hide()
    btn:SetScript("OnEnter", function(self) self.hover:Show() end)
    btn:SetScript("OnLeave", function(self) self.hover:Hide() end)
end

-- Shows an atlas at most `size` px on its longer side, keeping its shape.
-- An atlas this client doesn't have gets a red square instead; returns
-- whether the atlas was there. (Theme:FitAtlas shows a missing one blank.)
local function FitAtlas(tex, atlas, size)
    local info = C_Texture.GetAtlasInfo(atlas)
    if not info then
        tex:SetColorTexture(1, 0, 0, 0.25)
        tex:SetSize(size, size)
        return false
    end
    tex:SetAtlas(atlas)
    local scale = size / math.max(info.width, info.height)
    tex:SetSize(info.width * scale, info.height * scale)
    return true
end

-- A movable window `width` by `height` (WIDTH by HEIGHT when left out)
-- with a title and a close button; Escape closes it.
local function Window(globalName, heading, width, height)
    local f = CreateFrame("Frame", globalName, UIParent)
    f:SetSize(width or WIDTH, height or HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    Theme:Rounded(f, C.bg, C.accent, true)
    tinsert(UISpecialFrames, globalName)

    local title = Theme:Text(f, F.heading)
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(heading)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -8, -8)
    close.text = Theme:Text(close, F.title)
    close.text:SetPoint("CENTER")
    close.text:SetText("×")
    close:SetScript("OnClick", function() f:Hide() end)
    return f
end

-- A plain movable window in the game's own style (BasicFrameTemplateWithInset,
-- with its close button), `width` by `height`, for the map editor and the
-- line looks; the caller titles and places it.
local function GameWindow(globalName, width, height)
    local f = CreateFrame("Frame", globalName, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(width, height)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    return f
end

-- One muted line of help under a window's title; a scroll area under it
-- starts HINT_SCROLL_TOP px down.
local function Hint(f, text)
    local hint = Theme:Text(f, F.small)
    hint:SetPoint("TOPLEFT", PAD, -42)
    hint:SetText(text)
    Theme:SetTextColor(hint, C.muted)
    return hint
end

-- A scroll area filling `f` below `top` px; returns its content frame and
-- the scroll frame, with the mouse wheel scrolling `step` px a notch.
local function ScrollArea(f, top, step)
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", PAD, -top)
    scroll:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(f:GetWidth() - PAD * 2)
    scroll:SetScrollChild(content)
    -- Glides like NeedRoll's own lists; here the offset is in pixels.
    scroll.offset = 0
    scroll.scrollRefresh = function() scroll:SetVerticalScroll(math.floor(scroll.offset + 0.5)) end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = math.max(0, content:GetHeight() - self:GetHeight())
        local from = self.glide and self.glide.target or self.offset
        Theme:GlideTo(self, math.min(maxOffset, math.max(0, from - delta * step)))
    end)
    return content, scroll
end

-- The two pane backgrounds behind the scroll area: NeedRoll's modern list
-- panel, and the native skin's inset frame over the tinted Collections
-- parchment (both as Theme:CreatePanel draws them).
local function Backgrounds(f, top)
    local function Place(pane)
        pane:SetPoint("TOPLEFT", PAD - 4, -top + 4)
        pane:SetPoint("BOTTOMRIGHT", -PAD + 4, PAD - 4)
    end
    local modern = CreateFrame("Frame", nil, f)
    Place(modern)
    Theme:Rounded(modern, C.panel, C.edge)

    local native = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    Place(native)
    native.Bg:Hide()
    local parchment = native:CreateTexture(nil, "BACKGROUND", nil, -5)
    parchment:SetAtlas("collections-background-tile")
    parchment:SetHorizTile(true)
    parchment:SetVertTile(true)
    parchment:SetVertexColor(0.55, 0.55, 0.55)
    parchment:SetAllPoints()
    return { modern = modern, native = native }
end

-- "Background:  Modern  ·  Native" left of the close button; `onPick(style)`
-- runs on a click. Returns the two buttons by style.
local function StyleSwitch(f, onPick)
    local function Choice(style, right)
        local btn = CreateFrame("Button", nil, f)
        btn.text = Theme:Text(btn, F.small)
        btn.text:SetPoint("CENTER")
        btn.text:SetText(Theme.skinNames[style])
        btn:SetSize(btn.text:GetStringWidth() + 8, 20)
        btn:SetPoint("TOPRIGHT", right, -10)
        btn:SetScript("OnClick", function() onPick(style) end)
        return btn
    end
    local native = Choice("native", -40)
    local dot = Theme:Text(f, F.small)
    dot:SetPoint("RIGHT", native, "LEFT", 1, 0)
    dot:SetText(ns.DOT)
    Theme:SetTextColor(dot, C.muted)
    local modern = Choice("modern", -40 - native:GetWidth() - 10)

    local label = Theme:Text(f, F.small)
    label:SetPoint("RIGHT", modern, "LEFT", -2, 0)
    label:SetText("Background:")
    Theme:SetTextColor(label, C.muted)
    return { modern = modern, native = native }
end

-- Text that takes its color from the pane background in view. Each window
-- has its own painter, so its switch recolors only its own text.
local Painter = {}
Painter.__index = Painter

local function NewPainter()
    return setmetatable({ texts = {} }, Painter)
end

-- Keeps `fontString` to be colored as palette `role` ("heading", "text" or
-- "muted") of the background in view.
function Painter:Paint(fontString, role)
    self.texts[#self.texts + 1] = { fontString = fontString, role = role }
    return fontString
end

-- A section heading `y` px down `content`; returns the y under it. Its "·"
-- draws as ns.DOT, so a Russian client's font has it.
function Painter:Section(content, text, y)
    local label = self:Paint(Theme:Text(content, F.label), "heading")
    label:SetPoint("TOPLEFT", 8, -y)
    label:SetText(ns.WithDots(text))
    return y + 20
end

-- Shows `window`'s pane background for `style` ("modern" or "native"),
-- recolors its painted text to match and lights the picked switch button.
-- `window` is a debug page with .backgrounds, .switch and .painter.
local function ShowBackground(window, style)
    local palette = style == "native" and nativeColors or C
    window.backgrounds.modern:SetShown(style ~= "native")
    window.backgrounds.native:SetShown(style == "native")
    for _, painted in ipairs(window.painter.texts) do
        Theme:SetTextColor(painted.fontString, palette[painted.role])
    end
    for name, btn in pairs(window.switch) do
        Theme:SetTextColor(btn.text, name == style and C.heading or C.text)
    end
end

-- A cell `width` by `height` that prints `copy` to chat when clicked, with
-- a frame for its art (cell.art) at the top; the caller adds the text.
local function ClickCell(parent, width, height, copy)
    local cell = CreateFrame("Button", nil, parent)
    cell:SetSize(width, height)
    Hover(cell)
    cell:SetScript("OnClick", function() ns:Print(copy) end)
    cell.art = CreateFrame("Frame", nil, cell)
    cell.art:SetPoint("TOP", 0, -4)
    return cell
end

-- Lays `cells`, each `cellWidth` by `cellHeight`, out in rows across
-- `content` from `y` px down; returns the y under the last row.
local function Grid(content, cells, y, cellWidth, cellHeight)
    local columns = math.max(1, math.floor(content:GetWidth() / cellWidth))
    for i, cell in ipairs(cells) do
        local column, row = (i - 1) % columns, math.floor((i - 1) / columns)
        cell:SetPoint("TOPLEFT", column * cellWidth, -(y + row * cellHeight))
    end
    return y + math.ceil(#cells / columns) * cellHeight
end

ns.DevKit = {
    Window = Window, GameWindow = GameWindow, Hint = Hint, ScrollArea = ScrollArea, Backgrounds = Backgrounds,
    StyleSwitch = StyleSwitch,
    NewPainter = NewPainter, ShowBackground = ShowBackground, Hover = Hover, FitAtlas = FitAtlas,
    ClickCell = ClickCell, Grid = Grid, PAD = PAD, HINT_SCROLL_TOP = HINT_SCROLL_TOP,
}

--[==[@debug@
-- A list window, as /nr loot fished and /nr droptalk are (both local
-- checkouts only): a status line under the title, then a list pane with tabs
-- over its top right corner, a note for when the list is empty, and a fixed
-- pool of LIST_ROW_H rows that scrolls by whole rows.
local LIST_TOP = 100   -- the list pane's top, under the title, status line and tabs
local LIST_ROW_H = 36
local LIST_INSET = 4   -- the list's space inside the pane, top and bottom
local BAR_ROOM = 10    -- kept clear on the right for the scroll bar

local List = {}
List.__index = List

-- How many whole rows fit in the pane.
function List:Fits()
    return math.floor((self.pane:GetHeight() - LIST_INSET * 2) / LIST_ROW_H)
end

function List:MaxOffset()
    return math.max(0, #self.entries - self:Fits())
end

-- Shows `entries`, keeping the scroll spot where it still fits.
function List:SetEntries(entries)
    self.entries = entries
    self.pane.offset = math.min(self.pane.offset or 0, self:MaxOffset())
    self:Draw()
end

-- Draws the rows at the current (possibly mid-glide) scroll offset.
function List:Draw()
    self.empty:SetShown(#self.entries == 0)
    local first, shift = Theme:ScrollStart(self.pane.offset, function() return LIST_ROW_H end)
    for i, row in ipairs(self.rows) do
        local entry = self.entries[first + i - 1]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 1, -(LIST_INSET + (i - 1) * LIST_ROW_H - shift))
        row:SetPoint("RIGHT", -BAR_ROOM, 0)
        if entry then
            self.fillRow(row, entry)
            row:Show()
        else
            row:Hide()
        end
    end
    self.bar:Update(self.pane.offset, self:MaxOffset(), self:Fits())
end

-- Asks the server for an item the client hasn't loaded yet, once while it
-- is on its way; the window refreshes when it arrives.
function List:LoadItem(itemID)
    if self.loading[itemID] then return end
    self.loading[itemID] = true
    ns.Items:Load(itemID, function()
        self.loading[itemID] = nil
        self.refresh()
    end)
end

-- spec: name (the frame's global name), title, width, height, tabs (their
-- names), createRow(parent) -> row, fillRow(row, entry), onTab(name), and
-- refresh(), which rereads the window's data and calls list:SetEntries.
-- The list re-reads on show, on a tab switch (from the top) and when an
-- item it asked for arrives.
local function ListWindow(spec)
    local f = Window(spec.name, spec.title, spec.width, spec.height)
    local list = setmetatable({ frame = f, entries = {}, rows = {}, loading = {},
        fillRow = spec.fillRow, refresh = spec.refresh }, List)

    list.status = Theme:Text(f, F.small)
    list.status:SetPoint("TOPLEFT", PAD, -44)
    list.status:SetPoint("RIGHT", -PAD, 0)
    list.status:SetJustifyH("LEFT")
    list.status:SetWordWrap(true)
    Theme:SetTextColor(list.status, C.muted)

    local pane = CreateFrame("Frame", nil, f)
    pane:SetPoint("TOPLEFT", PAD, -LIST_TOP)
    pane:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    Theme:Rounded(pane, C.panel, C.edge)
    list.pane = pane

    list.empty = Theme:Text(pane, F.body)
    list.empty:SetPoint("CENTER")
    Theme:SetTextColor(list.empty, C.muted)

    list.tabs = Theme:LabelToggle(f, spec.tabs, function(name)
        spec.onTab(name)
        pane.offset = 0
        spec.refresh()
    end)
    list.tabs:SetPoint("BOTTOMRIGHT", pane, "TOPRIGHT", 0, 2)

    list.canvas = Theme:ScrollView(pane, LIST_INSET, LIST_INSET)
    local rowCount = math.ceil((spec.height - LIST_TOP - PAD - LIST_INSET * 2) / LIST_ROW_H) + 1
    for i = 1, rowCount do list.rows[i] = spec.createRow(list.canvas) end

    Theme:WheelScroll(pane, function() return list:MaxOffset() end, function() list:Draw() end)
    list.bar = Theme:ScrollBar(pane, LIST_INSET, LIST_INSET, function(offset)
        pane.offset = offset
        list:Draw()
    end)
    f:SetScript("OnShow", spec.refresh)
    return list
end

ns.DevKit.ListWindow = ListWindow
ns.DevKit.LIST_ROW_H = LIST_ROW_H
--@end-debug@]==]
