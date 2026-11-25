-- The pieces NeedRoll's dev and debug windows are built from (/nr
-- icondebug, /nr framedebug, /nr sounds, /nr loot fished, /nr droptalk), as
-- ns.DevKit: a movable window (and a plain one in the game's own style for
-- /nr devedit and /nr linedump), a scroll area over a modern or native pane
-- background with a switch between them, text recolored with the switch,
-- clickable cells in a grid, and (local checkouts only) a list window and a card that fades
-- in at the upper middle of the screen in the style of NeedRoll's window. The rest
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
local LOAD_BURST_SECONDS = 0.2 -- items asked for that arrive this close together get one refresh

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
-- is on its way; the window refreshes when it arrives (RefreshSoon). An item
-- the client already has is left alone: refreshing for it would only ask again.
function List:LoadItem(itemID)
    if self.loading[itemID] or C_Item.IsItemDataCachedByID(itemID) then return end
    self.loading[itemID] = true
    ns.Items:Load(itemID, function()
        self.loading[itemID] = nil
        self:RefreshSoon()
    end)
end

-- Refreshes the window LOAD_BURST_SECONDS from now, once however many items
-- arrive meanwhile: a page of items the client hadn't cached comes in a
-- burst, and a refresh each would re-read the window's data hundreds of times.
function List:RefreshSoon()
    if self.refreshDue then return end
    self.refreshDue = true
    C_Timer.After(LOAD_BURST_SECONDS, function()
        self.refreshDue = false
        self.refresh()
    end)
end

-- spec: name (the frame's global name), title, width, height, tabs (their
-- names), createRow(parent) -> row, fillRow(row, entry), onTab(name), and
-- refresh(), which rereads the window's data and calls list:SetEntries.
-- The list re-reads on show, on a tab switch (from the top) and shortly
-- after items it asked for arrive (List:RefreshSoon).
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

-- A card at the upper middle of the screen in the style picked for NeedRoll's window (local
-- checkouts only): the level-up window (UI/LevelUp.lua) and the run tracker's cards
-- (UI/RunTracker.lua). The game's own window frame in Native, a rounded (square in ElvUI's)
-- panel as NeedRoll's dialogs draw in the flat styles (StyledCard); or nothing behind what it
-- shows, straight on the game world (PlainCard, the kill card). It fades in; with `showSeconds`
-- it fades out that long after it has fully faded in, the mouse over it holding it. A right-click
-- on it closes it. A frame keeps the colors and fonts it was made with, so each style gets a card
-- of its own (CardsBySkin).
local CARD = {
    SCREEN_TOP = 140,          -- the card's top, down from the screen's: upper middle, clear of the action bars
    SUBTITLE_GAP = 3,          -- the flat styles: between the title and the line under it
    NATIVE_SUBTITLE_TOP = 36,  -- Native: the line under the title bar, where the flat styles' falls
    NATIVE_TITLE_MIDDLE = 12,  -- Native: the title bar's middle, down from the card's top
    CLOSE_SIZE = 20,           -- the flat styles' close cross, square
    CLOSE_INSET = 8,           -- the flat styles' close cross, in from the card's top right corner
    FADE_IN_SECONDS = 0.4,
    FADE_OUT_SECONDS = 0.8,
}

-- Native: the game's window frame (ButtonFrameTemplate without its portrait or inset, as
-- NeedRoll's own window), the title in its title bar, its own close button (hidden without
-- `hasClose`), and the line under the title below the bar.
local function CreateNativeCard(hasClose)
    local card = CreateFrame("Frame", nil, UIParent, "ButtonFrameTemplate")
    ButtonFrameTemplate_HidePortrait(card)
    card.Inset:Hide()
    -- TitleContainer comes from PortraitFrameBaseTemplate; older clients had TitleText.
    card.title = card.TitleContainer and card.TitleContainer.TitleText or card.TitleText
    card.titleMiddle = CARD.NATIVE_TITLE_MIDDLE
    card.subtitle = Theme:Text(card, Theme.font.small)
    card.subtitle:SetPoint("TOPLEFT", PAD, -CARD.NATIVE_SUBTITLE_TOP)
    card.CloseButton:SetShown(hasClose == true)
    card.close = hasClose and card.CloseButton or nil
    return card
end

-- The flat styles: a panel as NeedRoll's dialogs draw it (`popup` inside the thick `accent`
-- outline, in the style's corners), the title and the line under it at the top left and, with
-- `hasClose`, the close cross at the top right.
local function CreateFlatCard(hasClose)
    local card = CreateFrame("Frame", nil, UIParent)
    Theme:Rounded(card, Theme.color.popup, Theme.color.accent, true)
    card.title = Theme:Text(card, Theme.font.heading)
    card.title:SetPoint("TOPLEFT", PAD, -PAD)
    card.titleMiddle = PAD + Theme:LineHeight(card.title) / 2
    card.subtitle = Theme:Text(card, Theme.font.small)
    card.subtitle:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -CARD.SUBTITLE_GAP)
    if not hasClose then return card end
    card.close = Theme:CloseButton(card, CARD.CLOSE_SIZE)
    card.close:SetPoint("TOPRIGHT", -CARD.CLOSE_INSET, -CARD.CLOSE_INSET)
    return card
end

-- An animation taking the card's alpha from `fromAlpha` to `toAlpha` over `seconds`, then
-- running `onFinished`.
local function Fade(card, fromAlpha, toAlpha, seconds, onFinished)
    local group = card:CreateAnimationGroup()
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(fromAlpha)
    alpha:SetToAlpha(toAlpha)
    alpha:SetDuration(seconds)
    group:SetToFinalAlpha(true)
    group:SetScript("OnFinished", onFinished)
    return group
end

-- Each frame while the card shows: once it has fully faded in (secondsLeft set), counts down to
-- its fade-out. The mouse over it holds the count at its showSeconds, so it stays while the
-- player reads it, and brings it back if it was already fading.
local function CountDown(card, elapsed)
    if not card.secondsLeft then return end
    if card:IsMouseOver() then
        if card.fadeOut:IsPlaying() then
            card.fadeOut:Stop()
            card:SetAlpha(1)
        end
        card.secondsLeft = card.showSeconds
        return
    end
    if card.fadeOut:IsPlaying() then return end
    card.secondsLeft = card.secondsLeft - elapsed
    if card.secondsLeft <= 0 then card.fadeOut:Play() end
end

-- What every card does, whatever it looks like: `card` takes the style in use (card.skin,
-- Theme.name) and keeps its colors and fonts (card.colors, card.fonts) for what it adds later,
-- whatever style NeedRoll's window has by then. `width` wide, hidden. `showSeconds`: how long it
-- stays once faded in (nil: until closed). A right-click on it closes it.
local function SetUpCard(card, width, showSeconds)
    card.skin, card.colors, card.fonts = Theme.name, Theme.color, Theme.font
    card.showSeconds = showSeconds
    card:SetWidth(width)
    card:SetFrameStrata("DIALOG")
    card:SetClampedToScreen(true)
    card:EnableMouse(true)
    card:Hide()
    card.fadeIn = Fade(card, 0, 1, CARD.FADE_IN_SECONDS, function()
        card:SetAlpha(1)
        card.secondsLeft = card.showSeconds
    end)
    card.fadeOut = Fade(card, 1, 0, CARD.FADE_OUT_SECONDS, function() card:Hide() end)
    card:SetScript("OnUpdate", CountDown)
    card:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then self:Hide() end
    end)
    -- Hooked, so the game's frame template keeps any OnHide of its own.
    card:HookScript("OnHide", function(self)
        self.fadeIn:Stop()
        self.fadeOut:Stop()
        self.secondsLeft = nil
    end)
end

-- A card in the style in use (SetUpCard), drawn as that style's window: `hasClose` puts a close
-- button at its top right. card.titleMiddle is how far down from its top the title's middle is,
-- for a word at the title's right.
local function StyledCard(width, showSeconds, hasClose)
    local card = Theme.native and CreateNativeCard(hasClose) or CreateFlatCard(hasClose)
    SetUpCard(card, width, showSeconds)
    Theme:SetTextColor(card.subtitle, card.colors.muted)
    card.subtitle:SetWidth(width - PAD * 2)
    card.subtitle:SetJustifyH("LEFT")
    if card.close then card.close:SetScript("OnClick", function() card:Hide() end) end
    return card
end

-- A card in the style in use (SetUpCard) with nothing drawn behind it: no frame, no title. What
-- it shows sits on the game world, so it is the caller's to give a shadow.
local function PlainCard(width, showSeconds)
    local card = CreateFrame("Frame", nil, UIParent)
    SetUpCard(card, width, showSeconds)
    return card
end

-- Places the card at the upper middle of the screen, as big as the text size asks (Large
-- draws it 4/3 as big, as it does NeedRoll's window), and fades it in from clear.
local function FadeInCard(card)
    local scale = Theme.textScale[ns.db.textSize] or 1
    card:SetScale(scale)
    card:ClearAllPoints()
    card:SetPoint("TOP", UIParent, "TOP", 0, -CARD.SCREEN_TOP / scale)
    card.fadeIn:Stop()
    card.fadeOut:Stop()
    card.secondsLeft = nil
    card:SetAlpha(0)
    card:Show()
    card.fadeIn:Play()
end

-- A function giving `create()`'s card in the style NeedRoll's window uses: built the first time
-- it shows in that style, with the style saved in Settings in place even if NeedRoll's window
-- hasn't opened yet, and kept. Another style's card still on show (the style changed since) is
-- hidden.
local function CardsBySkin(create)
    local cardsBySkin, lastCard = {}, nil
    return function()
        ns.UI:UseSavedSkin()
        local card = cardsBySkin[Theme.name] or create()
        cardsBySkin[Theme.name] = card
        if lastCard and lastCard ~= card then lastCard:Hide() end
        lastCard = card
        return card
    end
end

ns.DevKit.StyledCard = StyledCard
ns.DevKit.PlainCard = PlainCard
ns.DevKit.FadeInCard = FadeInCard
ns.DevKit.CardsBySkin = CardsBySkin
--@end-debug@]==]
