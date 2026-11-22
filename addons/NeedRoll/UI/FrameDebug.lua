-- Debug page (/nr framedebug): WoW: Forever's unit frames, so we can see
-- them in the client and pick which one NeedRoll's boss portraits use.
-- Shows the game's frames put together the way its own FrameXML does
-- (player, target, focus, rare, elite, boss, party, target of target), each
-- with a sample portrait and level badge; the boss portraits as the loot
-- pane header draws them; every unit frame atlas on its own; and the older
-- TargetingFrame textures. Missing atlases and textures say so. Same window,
-- background switch and click-to-print as /nr icondebug.
local _, ns = ...
local Theme = ns.Theme

local FrameDebug = {}
ns.FrameDebug = FrameDebug

local kit = ns.DevKit
local F = Theme:Fonts("modern")

local SAMPLE_DISPLAY = 6915 -- Electrocutioner 6000, the sample target
local SAMPLE_LEVEL = 32
local SKULL = "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon"
local CIRCLE = "UI-HUD-UnitFrame-SmallCircle"

-- Frames as Forever's FrameXML builds them (Blizzard_UnitFrame, Mainline
-- layout with the Camelot overrides): the frame's size, its portrait's size
-- and top left corner, the frame atlas (centered unless `frameAt` gives its
-- top left), the level circle's corner and offset, and the boss ring on top
-- with its top right offset (Camelot's GetBossPortraitFrameData).
local TARGET = { size = { 232, 100 }, portrait = { 58, 148, -19 }, level = { "BOTTOMRIGHT", -13, 7 } }
local function Target(name, frame, ring, ringX, ringY, skull)
    return { name = ns.WithDots(name), size = TARGET.size, portrait = TARGET.portrait, frame = frame,
             level = TARGET.level, ring = ring, ringAt = ring and { ringX, ringY }, skull = skull, unit = "target" }
end
local COMPOSED = {
    { name = "Player", size = { 232, 100 }, portrait = { 60, 24, -19 }, frame = "UI-HUD-UnitFrame-Player-PortraitOn",
      level = { "BOTTOMLEFT", 13, 7 }, unit = "player" },
    Target("Target  ·  normal (also Focus)", "UI-HUD-UnitFrame-Target-PortraitOn"),
    Target("Target  ·  minus mob", "UI-HUD-UnitFrame-Target-MinusMob-PortraitOn"),
    Target("Target  ·  elite", "UI-HUD-UnitFrame-Target-PortraitOn",
        "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold", 0, 1),
    Target("Target  ·  boss (??)", "UI-HUD-UnitFrame-Target-PortraitOn",
        "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", 11, -4, true),
    Target("Target  ·  rare / rare elite", "UI-HUD-UnitFrame-Target-Rare-PortraitOn",
        "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged", 8, -7),
    Target("Target  ·  rare silver (unused)", "UI-HUD-UnitFrame-Target-Rare-PortraitOn",
        "ui-hud-unitframe-target-portraiton-boss-rare-silver", 0, 1),
    { name = "Party member", size = { 120, 53 }, portrait = { 37, 7, -6 }, frame = "UI-HUD-UnitFrame-Party-PortraitOn",
      frameAt = { 1, -2 }, unit = "player" },
    { name = "Target of target", size = { 120, 49 }, portrait = { 37, 5, -5 },
      frame = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn", unit = "target" },
}

-- Every unit frame atlas in Forever's atlas list (Ketho/BlizzardInterfaceResources,
-- forever branch) that a portrait frame is made of.
local ATLASES = {
    "UI-HUD-UnitFrame-Player-PortraitOn", "UI-HUD-UnitFrame-Player-PortraitOff",
    "UI-HUD-UnitFrame-Player-PortraitOn-ClassResource", "UI-HUD-UnitFrame-Player-PortraitOn-Vehicle",
    "UI-HUD-UnitFrame-Player-PortraitOn-CornerEmbellishment", "UI-HUD-UnitFrame-Player-PortraitOn-OuterGlow",
    "UI-HUD-UnitFrame-Target-PortraitOn", "UI-HUD-UnitFrame-Target-Rare-PortraitOn",
    "UI-HUD-UnitFrame-Target-MinusMob-PortraitOn", "UI-HUD-UnitFrame-Target-PortraitOn-Vehicle",
    "UI-HUD-UnitFrame-Target-PortraitOn-OuterGlow",
    "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged",
    "ui-hud-unitframe-target-portraiton-boss-rare-silver", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Silver-Winged",
    "UI-HUD-UnitFrame-Target-PortraitOn-Boss-IconRing", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest",
    "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star",
    "UI-HUD-UnitFrame-Target-Boss-Small-PortraitOff", "hud-UnitFrame-Boss",
    "UI-HUD-UnitFrame-Party-PortraitOn", "UI-HUD-UnitFrame-Party-PortraitOn-Vehicle",
    "ui-hud-unitframe-characterframeonparty-portraiton", "UI-HUD-UnitFrame-TargetofTarget-PortraitOn",
    "UI-HUD-UnitFrame-SmallCircle", "UI-HUD-UnitFrame-SmallCircle-Alliance", "UI-HUD-UnitFrame-SmallCircle-Horde",
    "UI-HUD-UnitFrame-Target-HighLevelTarget_Icon", "UI-HUD-UnitFrame-TotemFrame",
    "UI-HUD-UnitFrame-Target-PortraitOn-LevelIcon-Green", "UI-HUD-UnitFrame-Target-PortraitOn-LevelIcon-Grey",
    "UI-HUD-UnitFrame-Target-PortraitOn-LevelIcon-Orange", "UI-HUD-UnitFrame-Target-PortraitOn-LevelIcon-Red",
    "CircleMask",
}

-- The pre-Dragonflight frame textures, if the client still ships them.
local TARGETING_FRAME = [[Interface\TargetingFrame\]]
local TEXTURES = {
    "UI-TargetingFrame", "UI-TargetingFrame-Elite", "UI-TargetingFrame-Rare", "UI-TargetingFrame-Rare-Elite",
    "UI-TargetingFrame-Skull", "UI-TargetingFrame-MinusMob", "UI-PartyFrame", "UI-SmallTargetingFrame",
    "UI-TargetofTargetFrame", "UI-FocusTargetingFrame", "UI-Player-Status",
}

-- The loot pane header's boss portrait for each rank: { label, level (-1
-- for "??", nil when unknown), rank }.
local HEADER_SAMPLES = {
    { "Elite", 32, "elite" }, { "Boss (??)", -1, "worldboss" },
    { "Rare elite", 32, "rareelite" }, { "Normal", 32, "normal" }, { "Level unknown", nil, "elite" },
}

local COMPOSED_W, COMPOSED_H = 240, 140
local ATLAS_W, ATLAS_H = 176, 120
local ART_W, ART_H = ATLAS_W - 16, 76 -- the room for an atlas or texture in its cell
local SECTION_GAP = 12

local painter = kit.NewPainter()
FrameDebug.painter = painter

-- A clickable cell, `width` by `height`, with the art in `cell.art` and two
-- lines of text under it; a click prints `copy` to chat.
local function Cell(content, width, height, name, detail, copy)
    local cell = kit.ClickCell(content, width, height, copy)
    cell.name = painter:Paint(Theme:Text(cell, F.small), "text")
    cell.name:SetPoint("BOTTOM", 0, 18)
    cell.name:SetWidth(width - 6)
    cell.name:SetWordWrap(false)
    cell.name:SetText(name)
    cell.detail = painter:Paint(Theme:Text(cell, F.hint), "muted")
    cell.detail:SetPoint("TOP", cell.name, "BOTTOM", 0, -2)
    cell.detail:SetWidth(width - 6)
    cell.detail:SetWordWrap(false)
    cell.detail:SetText(detail or "")
    return cell
end

-- The level circle in `spec.level`'s corner of `box`, with the skull of a
-- boss or the sample level (the player's own for the player frames).
local function AddLevelBadge(box, spec)
    local circle = box:CreateTexture(nil, "OVERLAY", nil, 1)
    circle:SetAtlas(CIRCLE, true)
    circle:SetPoint(spec.level[1], spec.level[2], spec.level[3])
    if spec.skull then
        local skull = box:CreateTexture(nil, "OVERLAY", nil, 2)
        skull:SetAtlas(SKULL, true)
        skull:SetPoint("CENTER", circle)
        return
    end
    local level = box:CreateFontString(nil, "OVERLAY")
    level:SetFontObject(WhiteLargeNumberFont or NumberFontNormalLarge or GameFontNormalLarge)
    level:SetPoint("CENTER", circle, "CENTER", 0, -0.5)
    local isPlayer = spec.unit == "player"
    level:SetText(isPlayer and ns.PlayerLevel() or SAMPLE_LEVEL)
    if isPlayer then level:SetTextColor(1, 0.82, 0) end
end

-- One frame as the game puts it together.
local function ComposedCell(content, spec)
    local parts, missing = { spec.frame }, {}
    if spec.ring then parts[#parts + 1] = spec.ring end
    for _, atlas in ipairs(parts) do
        if not C_Texture.GetAtlasInfo(atlas) then missing[#missing + 1] = atlas end
    end
    local partList = table.concat(parts, "  +  ")
    local cell = Cell(content, COMPOSED_W, COMPOSED_H, spec.name,
        #missing > 0 and ("missing: " .. table.concat(missing, ", ")) or partList, partList)
    local box = cell.art
    box:SetSize(spec.size[1], spec.size[2])
    local portrait = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    portrait:SetSize(spec.portrait[1], spec.portrait[1])
    portrait:SetPoint("TOPLEFT", spec.portrait[2], spec.portrait[3])
    if spec.unit == "player" then
        SetPortraitTexture(portrait, "player")
    else
        SetPortraitTextureFromCreatureDisplayID(portrait, SAMPLE_DISPLAY)
    end
    Theme:MaskRound(box, portrait)
    local frame = box:CreateTexture(nil, "BACKGROUND", nil, 2)
    frame:SetAtlas(spec.frame, true)
    if spec.frameAt then
        frame:SetPoint("TOPLEFT", spec.frameAt[1], spec.frameAt[2])
    else
        frame:SetPoint("CENTER")
    end
    if spec.ring then
        local ring = box:CreateTexture(nil, "ARTWORK")
        ring:SetAtlas(spec.ring, true)
        ring:SetPoint("TOPRIGHT", spec.ringAt[1], spec.ringAt[2])
    end
    if spec.level then AddLevelBadge(box, spec) end
    return cell
end

-- The loot pane header's boss portrait for each rank, at 0.8 scale.
local function HeaderPortraitCells(content)
    local cells = {}
    for _, sample in ipairs(HEADER_SAMPLES) do
        local label, level, rank = sample[1], sample[2], sample[3]
        local cell = Cell(content, ATLAS_W, ATLAS_H, label, "loot header, rank " .. rank, "rank " .. rank)
        cell.art:SetSize(1, 1)
        local portrait = ns.UI.CreateBossPortrait(cell.art)
        portrait:SetScale(0.8)
        portrait:SetPoint("TOP", cell, "TOP", 0, -4 / 0.8)
        portrait:SetBoss({ "Electrocutioner 6000", SAMPLE_DISPLAY, level, rank })
        cells[#cells + 1] = cell
    end
    return cells
end

-- An atlas on its own, fitted into the cell, with its size.
local function AtlasCells(content)
    local cells = {}
    for _, atlas in ipairs(ATLASES) do
        local info = C_Texture.GetAtlasInfo(atlas)
        local detail = info and ("%d x %d"):format(info.width, info.height) or "missing"
        local cell = Cell(content, ATLAS_W, ATLAS_H, atlas, detail, atlas)
        cell.art:SetSize(ART_W, ART_H)
        local tex = cell.art:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("CENTER")
        if info then
            -- Native size, shrunk only when it doesn't fit.
            local scale = math.min(1, ART_W / math.max(info.width, 1), ART_H / math.max(info.height, 1))
            tex:SetAtlas(atlas)
            tex:SetSize(math.max(info.width * scale, 1), math.max(info.height * scale, 1))
        else
            kit.FitAtlas(tex, atlas, 40)
        end
        cells[#cells + 1] = cell
    end
    return cells
end

local function TextureCells(content)
    local cells = {}
    for _, name in ipairs(TEXTURES) do
        local path = TARGETING_FRAME .. name
        local cell = Cell(content, ATLAS_W, ATLAS_H, name, "texture", path)
        cell.art:SetSize(ART_W, ART_H)
        local tex = cell.art:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        -- SetTexture reports false for a file the client doesn't have.
        if tex:SetTexture(path) == false then
            tex:SetColorTexture(1, 0, 0, 0.25)
            cell.detail:SetText("missing")
        end
        cells[#cells + 1] = cell
    end
    return cells
end

local function BuildContent(content)
    local composed = {}
    for _, spec in ipairs(COMPOSED) do composed[#composed + 1] = ComposedCell(content, spec) end
    local y = painter:Section(content, "Unit frames as the game builds them  ·  sample portrait and level", 8)
    y = kit.Grid(content, composed, y, COMPOSED_W, COMPOSED_H) + SECTION_GAP
    y = painter:Section(content, "Boss portraits as NeedRoll's loot header draws them", y)
    y = kit.Grid(content, HeaderPortraitCells(content), y, ATLAS_W, ATLAS_H) + SECTION_GAP
    y = painter:Section(content, "Unit frame atlases", y)
    y = kit.Grid(content, AtlasCells(content), y, ATLAS_W, ATLAS_H) + SECTION_GAP
    y = painter:Section(content, "Older TargetingFrame textures", y)
    y = kit.Grid(content, TextureCells(content), y, ATLAS_W, ATLAS_H) + SECTION_GAP
    content:SetHeight(y + kit.PAD)
end

function FrameDebug:SetStyle(style)
    kit.ShowBackground(self, style)
end

function FrameDebug:Build()
    if self.frame then return end
    local f = kit.Window("NeedRollFrameDebug", "Frame debug")
    self.frame = f
    kit.Hint(f, "Click any frame to print its atlas names to chat.")

    self.backgrounds = kit.Backgrounds(f, kit.HINT_SCROLL_TOP)
    self.switch = kit.StyleSwitch(f, function(style) self:SetStyle(style) end)
    local content, scroll = kit.ScrollArea(f, kit.HINT_SCROLL_TOP, 60)
    scroll:SetFrameLevel(self.backgrounds.native:GetFrameLevel() + 2)
    BuildContent(content)
    self:SetStyle(Theme.native and "native" or "modern")
end

function FrameDebug:Toggle()
    self:Build()
    self.frame:SetShown(not self.frame:IsShown())
end

--[==[@debug@
-- /nr fontdebug (local checkouts only): hovering any text or icon in the
-- NeedRoll window shows what it is and its size, and the mouse wheel over
-- it makes text 1pt and icons 5% bigger or smaller. Edits are drawn in
-- place until /nr fontdebug reset or /nr devedit reset, and /nr devexport
-- lists each one (text sizes as a scale of their skin font), for the code.
-- Stays on across /reload until toggled off. Edits live in
-- NeedRollDB.fontEdit[name] (text) and NeedRollDB.iconEdit[name] (icons).
local FontDebug = {}
ns.FontDebug = FontDebug

local ICON_MAX = 96 -- bigger pictures (backgrounds, maps) aren't icons

-- The string key under which `holder` keeps `value`, if any.
local function KeyOf(holder, value)
    for key, held in pairs(holder) do
        if held == value and type(key) == "string" then return key end
    end
end

-- A text's or icon's name: what the page called it (devLabel), or the
-- keys that lead to it from ns.UI ("overview.title"), worked out once.
local named = setmetatable({}, { __mode = "k" })
local function Label(region)
    if region.devLabel then return region.devLabel end
    if named[region] then return named[region] end
    local keys, current = {}, region
    while current and #keys < 6 do
        local key = KeyOf(ns.UI, current)
        if key then
            table.insert(keys, 1, key)
            break
        end
        -- Kept on the frame that holds it, or on one a few levels up.
        local holder, found = current:GetParent(), nil
        for _ = 1, 3 do
            if not holder then break end
            found = KeyOf(holder, current)
            if found then break end
            holder = holder:GetParent()
        end
        if not found then break end
        table.insert(keys, 1, found)
        current = holder
    end
    named[region] = #keys > 0 and table.concat(keys, ".") or nil
    return named[region]
end

-- A skin's own font and how many times its size a scaled font is.
local function Root(font)
    local scale = 1
    while Theme.scaledFrom[font] do
        scale = scale * Theme.scaledFrom[font][2]
        font = Theme.scaledFrom[font][1]
    end
    return font, scale
end

-- A skin's font by its key ("body"), whichever skin made it; any other font by its own name.
local function SkinFontName(font)
    if font and Theme.fontKeys[font] then return Theme.fontKeys[font] end
    return (font and font:GetName() or "(unnamed font)"):lower()
end

-- "body x0.75" for a scaled font, "body" for a skin's own.
local function FontName(font)
    if not font then return "(none)" end
    local root, scale = Root(font)
    return scale == 1 and SkinFontName(root) or ("%s x%g"):format(SkinFontName(root), scale)
end

-- The size its font gives a text, before any edit.
local function BaseSize(fontString)
    local font = fontString:GetFontObject()
    local _, size = (font or fontString):GetFont()
    return size or 0
end

local function IsText(region)
    return region:GetObjectType() == "FontString"
end

-- Every shown text and picture in `frame`, with `fn(region)`.
local function EachRegion(frame, fn)
    if not frame:IsVisible() then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        local kind = region:GetObjectType()
        if (kind == "FontString" or kind == "Texture") and region:IsVisible() then fn(region) end
    end
    for _, child in ipairs({ frame:GetChildren() }) do EachRegion(child, fn) end
end

-- What resizing a picture changes: the small frame it makes up (a class
-- badge, the portal), scaled whole; or the picture itself, or the one it
-- is pinned to, sized. Nil when it can't be resized on its own.
local function IconTarget(tex)
    if not (tex:GetTexture() or (tex.GetAtlas and tex:GetAtlas())) then return end
    local width, height = tex:GetSize()
    if not width or width <= 0 or width > ICON_MAX or height > ICON_MAX then return end
    local parent = tex:GetParent()
    local parentWidth, parentHeight = parent:GetSize()
    if parent ~= ns.UI.frame and parentWidth and parentWidth > 0 and parentWidth <= ICON_MAX
        and parentHeight <= ICON_MAX then
        return parent
    end
    if tex:GetNumPoints() <= 1 then return tex end
    local _, pinnedTo = tex:GetPoint(1)
    if pinnedTo and pinnedTo.GetObjectType and pinnedTo:GetObjectType() == "Texture"
        and pinnedTo:GetNumPoints() <= 1 then
        return pinnedTo
    end
end

-- The smallest text under the mouse in the window, or failing that the
-- smallest icon: the region to show and the one an edit resizes.
local function Hovered(window)
    local text, textArea, icon, iconArea, iconTarget
    EachRegion(window, function(region)
        if not region:IsMouseOver() then return end
        local area = (region:GetWidth() or 0) * (region:GetHeight() or 0)
        if IsText(region) then
            if (region:GetText() or "") ~= "" and (not text or area < textArea) then text, textArea = region, area end
        elseif not icon or area < iconArea then
            local resized = IconTarget(region)
            if resized then icon, iconArea, iconTarget = region, area, resized end
        end
    end)
    if text then return text, text end
    return icon, iconTarget
end

-- Draws an edited text at its edited size (its page sets its own again
-- on every redraw, so the watcher does this over and over).
local function ApplyText(fontString)
    local edit = ns.db.fontEdit and ns.db.fontEdit[Label(fontString)]
    local path, size, flags = fontString:GetFont()
    local wanted = edit and edit.size or BaseSize(fontString)
    if path and size ~= wanted then fontString:SetFont(path, wanted, flags or "") end
end

-- Draws an icon at its edited scale. What its page set last is its base:
-- a size or scale other than the one drawn here means the page set it anew.
local function ApplyIcon(region)
    local edit = ns.db.iconEdit and ns.db.iconEdit[Label(region)]
    local editScale = edit and edit.scale or 1
    if region:GetObjectType() == "Texture" then
        local width, height = region:GetSize()
        if not region.devDrawn or math.abs(width - region.devDrawn) > 0.01 then region.devBase = { width, height } end
        local wanted = region.devBase[1] * editScale
        if math.abs(width - wanted) > 0.01 then region:SetSize(wanted, region.devBase[2] * editScale) end
        region.devDrawn = wanted
    else
        local scale = region:GetScale()
        if not region.devDrawn or math.abs(scale - region.devDrawn) > 0.0001 then region.devBase = scale end
        local wanted = region.devBase * editScale
        if math.abs(scale - wanted) > 0.0001 then region:SetScale(wanted) end
        region.devDrawn = wanted
    end
end

-- An icon's width as drawn by its page, before any edit.
local function IconWidth(region)
    local width = region:GetWidth() or 0
    if region:GetObjectType() == "Texture" then return region.devBase and region.devBase[1] or width end
    return width * (region.devBase or region:GetScale())
end

-- Rounded to one decimal, for the tooltip and the saved widths.
local function OneDecimal(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function IsInspecting()
    return ns.db and ns.db.fontDebug or false
end

local function CurrentEdits()
    return { text = ns.db.fontEdit or {}, icon = ns.db.iconEdit or {} }
end

local function AnyEdits()
    return (ns.db.fontEdit and next(ns.db.fontEdit) or ns.db.iconEdit and next(ns.db.iconEdit)) ~= nil
end

-- The tooltip, the wheel catcher and the watcher (made on first use), and
-- the region the tooltip is showing with the one an edit of it resizes.
local tip, wheel, watcher
local shownRegion, shownTarget

local function AddTextLines(region, label)
    local _, size = region:GetFont()
    size = size or 0
    local windowScale = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
    tip:AddLine(("Font: %s"):format(FontName(region:GetFontObject())), unpack(Theme.tip.text))
    tip:AddLine(("Size: %g  (%.1f with the window's %.2fx scale)"):format(size, size * windowScale, windowScale),
        unpack(Theme.tip.text))
    local edit = label and ns.db.fontEdit and ns.db.fontEdit[label]
    if edit then tip:AddLine(("Edited from %g"):format(edit.was), 0.4, 1, 0.4) end
    local text = Theme:PlainText(region:GetText() or "")
    if #text > 60 then text = text:sub(1, 57) .. "..." end
    tip:AddLine(text, 0.7, 0.7, 0.7, true)
    if label then tip:AddLine("Mouse wheel: 1pt bigger or smaller", 0.5, 0.8, 1) end
end

local function AddIconLines(region, resized, label)
    local width, height = region:GetSize()
    -- A frame scaled whole draws its pictures that many times their size.
    local scale = resized:GetObjectType() == "Texture" and 1 or resized:GetScale()
    tip:AddLine(("Icon: %g x %g"):format(OneDecimal(width * scale), OneDecimal(height * scale)), unpack(Theme.tip.text))
    local edit = label and ns.db.iconEdit and ns.db.iconEdit[label]
    if edit then tip:AddLine(("Edited: x%.2f of %g"):format(edit.scale, edit.was), 0.4, 1, 0.4) end
    if label then tip:AddLine("Mouse wheel: 5% bigger or smaller", 0.5, 0.8, 1) end
end

-- Shows what `region` is in the tooltip (nil hides it); `resized` is what
-- an edit of it resizes.
local function Show(region, resized)
    shownRegion, shownTarget = region, resized
    if not region then
        wheel:Hide()
        return tip:Hide()
    end
    -- The wheel catcher sits over it: the wheel resizes it instead of
    -- scrolling, while clicks still reach what is under it.
    wheel:ClearAllPoints()
    wheel:SetAllPoints(region)
    wheel:Show()
    tip:SetOwner(UIParent, "ANCHOR_CURSOR_RIGHT", 16, 16)
    local label = Label(resized)
    tip:SetText(label or "(no name: can't be edited)", 1, 0.82, 0)
    if IsText(region) then
        AddTextLines(region, label)
    else
        AddIconLines(region, resized, label)
    end
    tip:Show()
end

local function NudgeText(region, label, delta)
    ns.db.fontEdit = ns.db.fontEdit or {}
    local baseSize = BaseSize(region)
    local edit = ns.db.fontEdit[label]
    local size = math.max(4, math.floor((edit and edit.size or baseSize) + 0.5) + delta)
    if math.abs(size - baseSize) < 0.01 then
        ns.db.fontEdit[label] = nil
    else
        -- Kept as names and numbers: font objects can't be saved.
        local font = region:GetFontObject()
        local root = font and Root(font)
        local _, rootSize = (root or region):GetFont()
        ns.db.fontEdit[label] = { size = size, was = baseSize, font = FontName(font),
            root = root and SkinFontName(root), rootSize = root and rootSize }
    end
    ApplyText(region)
end

local function NudgeIcon(resized, label, delta)
    ns.db.iconEdit = ns.db.iconEdit or {}
    ApplyIcon(resized)  -- notes its base first
    local edit = ns.db.iconEdit[label]
    -- Snapped to the 5% grid (20 steps to 1x) before the 5% step, and kept
    -- at a quarter size or more.
    local snapped = math.floor((edit and edit.scale or 1) * 20 + 0.5) / 20
    local scale = math.max(0.25, snapped + delta * 0.05)
    if math.abs(scale - 1) < 0.001 then
        ns.db.iconEdit[label] = nil
    else
        ns.db.iconEdit[label] = { scale = scale, was = OneDecimal(IconWidth(resized)) }
    end
    ApplyIcon(resized)
end

-- The hovered text `delta` points bigger (1) or smaller (-1), or the
-- hovered icon 5% for each. Back at its own size, it is no longer an edit.
function FontDebug:Nudge(region, resized, delta)
    local label = Label(resized)
    if not label then return end
    if IsText(region) then
        NudgeText(region, label, delta)
    else
        NudgeIcon(resized, label, delta)
    end
    Show(region, resized)
end

-- Lua comments for /nr devexport: each edited text's name and font, its
-- size before and after, and the new size as a scale of its skin font;
-- each edited icon's width before and after, and the scale between them.
function FontDebug:Text()
    local lines = {}
    local function SortedNames(edits)
        local names = {}
        for name in pairs(edits or {}) do table.insert(names, name) end
        table.sort(names)
        return names
    end
    for _, name in ipairs(SortedNames(ns.db and ns.db.fontEdit)) do
        local edit = ns.db.fontEdit[name]
        local scaled = edit.rootSize and ("  =  %s x%.3g"):format(edit.root, edit.size / edit.rootSize) or ""
        table.insert(lines, ("-- %s (%s): %g -> %g%s"):format(name, edit.font or "?", edit.was, edit.size, scaled))
    end
    for _, name in ipairs(SortedNames(ns.db and ns.db.iconEdit)) do
        local edit = ns.db.iconEdit[name]
        table.insert(lines, ("-- %s (icon): %g -> %g wide  =  x%.2f"):format(name, edit.was, edit.was * edit.scale,
            edit.scale))
    end
    return lines
end

-- Every text and icon an edit could reach, with the right Apply.
local function ApplyAll(window, edits)
    EachRegion(window, function(region)
        if IsText(region) then
            if edits.text[Label(region) or ""] then ApplyText(region) end
        else
            local resized = IconTarget(region)
            if resized and edits.icon[Label(resized) or ""] then ApplyIcon(resized) end
        end
    end)
end

function FontDebug:Reset()
    local edits = CurrentEdits()
    ns.db.fontEdit, ns.db.iconEdit = nil, nil
    local window = ns.UI.frame
    if window then ApplyAll(window, edits) end
    if shownRegion then Show(shownRegion, shownTarget) end
    self:Update()
end

-- Every 0.1 seconds while the window shows: draws the edits
-- again and, while inspecting, shows what the mouse is over.
local function Watch()
    local window = ns.UI.frame
    if not (window and window:IsVisible()) then
        if shownRegion then Show(nil) end
        return
    end
    if AnyEdits() then ApplyAll(window, CurrentEdits()) end
    local region, resized
    if IsInspecting() then region, resized = Hovered(window) end
    if region ~= shownRegion then Show(region, resized) end
end

local function CreateInspector()
    tip = CreateFrame("GameTooltip", "NeedRollFontDebugTip", UIParent, "GameTooltipTemplate")
    wheel = CreateFrame("Frame", "NeedRollFontDebugWheel", UIParent)
    wheel:SetFrameStrata("FULLSCREEN_DIALOG")
    wheel:EnableMouse(false)
    wheel:EnableMouseWheel(true)
    wheel:SetScript("OnMouseWheel", function(_, delta)
        if shownRegion then FontDebug:Nudge(shownRegion, shownTarget, delta > 0 and 1 or -1) end
    end)
    wheel:Hide()
    watcher = CreateFrame("Frame", nil, UIParent)
    local untilNextLook = 0
    watcher:SetScript("OnUpdate", function(_, elapsed)
        untilNextLook = untilNextLook - elapsed
        if untilNextLook > 0 then return end
        untilNextLook = 0.1
        Watch()
    end)
end

-- Starts or stops the watcher, which shows the tooltip and the wheel
-- catcher while the inspector is on and draws the edits whenever there
-- are any.
function FontDebug:Update()
    if not ns.db then return end
    if not tip then CreateInspector() end
    watcher:SetShown(IsInspecting() or AnyEdits())
    if not IsInspecting() and shownRegion then Show(nil) end
end

function FontDebug:Toggle(arg)
    if arg == "reset" then
        self:Reset()
        return ns:Print("Text and icon size edits dropped.")
    end
    ns.db.fontDebug = not ns.db.fontDebug or nil
    self:Update()
    if ns.db.fontDebug then
        ns:Print("Font debug on: hover text or an icon for its size, mouse wheel to change it;"
            .. " /nr devexport lists the changes.")
    else
        ns:Print("Font debug off. Your size edits stay in place; /nr fontdebug reset drops them.")
    end
end

ns:On("PLAYER_LOGIN", function() FontDebug:Update() end)
--@end-debug@]==]
