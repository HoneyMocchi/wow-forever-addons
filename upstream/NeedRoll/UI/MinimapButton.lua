-- NeedRoll: the minimap button. LibDBIcon-1.0 makes it, so minimap addons
-- that gather, skin or hide other addons' buttons (SexyMap, HidingBar,
-- ElvUI, Leatrix Plus and the like) treat it as one of theirs, and
-- LibDataBroker displays (Titan Panel and the like) list it as a launcher.
-- A round NR logo on the minimap's edge: left-click toggles the window,
-- right-click opens it on Settings, and LibDBIcon moves it round the edge
-- by dragging. Where it sits (minimapPos, degrees counterclockwise from the
-- right) and whether it shows (hide) live in NeedRollDB.minimap, the table
-- LibDBIcon reads and writes. /nr minimap and Settings hide or show it.
local _, ns = ...
local L = ns.L
local Theme = ns.Theme
local LibDataBroker = LibStub("LibDataBroker-1.1")
local LibDBIcon = LibStub("LibDBIcon-1.0")

local MinimapButton = {}
ns.MinimapButton = MinimapButton

-- The name LibDBIcon and broker displays know NeedRoll by. LibDBIcon names
-- the button's frame after it: LibDBIcon10_NeedRoll.
local LAUNCHER_NAME = "NeedRoll"
local ICON = "Interface\\AddOns\\NeedRoll\\Media\\MinimapIcon"
-- Forever's bronze ring around the minimap's day/night disc, round the logo.
local BRONZE = { atlas = "UI-HUD-Minimap-Frame-Cycle", ringSize = 32, logoSize = 25, logoY = 0 }
-- Clients without that ring: the classic gold tracking border, on a dark
-- disc, with the logo a pixel above the centre to sit inside it.
local GOLD = { ringSize = 53, discSize = 24, logoSize = 20, logoY = 1 }
local GOLD_RING = "Interface\\Minimap\\MiniMap-TrackingBorder"
local DARK_DISC = "Interface\\Minimap\\UI-Minimap-Background"

local function AddTooltipLines(tooltip)
    tooltip:SetText("NeedRoll")
    tooltip:AddLine(L["Left-click: Open NeedRoll"], unpack(Theme.tip.text))
    tooltip:AddLine(L["Right-click: Open NeedRoll Settings"], unpack(Theme.tip.text))
    tooltip:AddLine(L["Drag to move."], 0.7, 0.7, 0.7)
end

-- Right-click: the window open on its Settings page, or shut if it is
-- already there (as a left-click shuts an open window).
local function ToggleSettings()
    local UI = ns.UI
    if UI.frame and UI.frame:IsShown() and UI.settingsOpen then
        UI:Hide()
        return
    end
    UI:Show()
    UI:OpenSettings()
end

-- LibDBIcon's button takes every mouse button; only the left and right ones do something.
local function OnClick(_, mouseButton)
    if mouseButton == "RightButton" then
        ToggleSettings()
    elseif mouseButton == "LeftButton" then
        ns:Toggle()
    end
end

-- LibDBIcon calls the logo's UpdateCoord on each press, release and drag
-- (its own zooms the logo a little). NeedRoll's keeps the whole logo and
-- nudges it a pixel down and right while the button is held, like the
-- game's buttons. `logoY` is the logo's resting height above the centre.
local function NudgeLogoWhilePressed(button, logoY)
    function button.icon:UpdateCoord()
        local pressedOffset = button.isMouseDown and 1 or 0
        self:ClearAllPoints()
        self:SetPoint("CENTER", pressedOffset, logoY - pressedOffset)
    end
    button.icon:UpdateCoord()
end

-- LibDBIcon's button draws its logo in the gold tracking border. This gives
-- it NeedRoll's look: the logo inside Forever's bronze ring when the client
-- has the ring, else larger in the gold border. It restyles the textures
-- LibDBIcon made (icon, border, background), so addons that skin LibDBIcon
-- buttons still find them.
function MinimapButton:Restyle()
    local button = self.button
    local logo, ring, disc = button.icon, button.border, button.background
    local look = C_Texture.GetAtlasInfo(BRONZE.atlas) and BRONZE or GOLD
    ring:ClearAllPoints()
    if look == BRONZE then
        ring:SetAtlas(BRONZE.atlas)
        ring:SetPoint("CENTER")
        disc:Hide()
    else
        ring:SetTexture(GOLD_RING)
        ring:SetPoint("TOPLEFT")
        disc:SetTexture(DARK_DISC)
        disc:SetSize(GOLD.discSize, GOLD.discSize)
        disc:ClearAllPoints()
        disc:SetPoint("CENTER")
        disc:Show()
    end
    ring:SetSize(look.ringSize, look.ringSize)
    logo:SetSize(look.logoSize, look.logoSize)
    logo:SetTexCoord(0, 1, 0, 1)
    NudgeLogoWhilePressed(button, look.logoY)
end

-- Once, at login: NeedRoll's launcher, the button LibDBIcon makes for it
-- (placed and shown or hidden from NeedRollDB.minimap), then NeedRoll's look.
function MinimapButton:Build()
    if LibDBIcon:IsRegistered(LAUNCHER_NAME) then return end
    local launcher = LibDataBroker:NewDataObject(LAUNCHER_NAME, {
        type = "launcher",
        icon = ICON,
        OnClick = OnClick,
        OnTooltipShow = AddTooltipLines,
    })
    LibDBIcon:Register(LAUNCHER_NAME, launcher, ns.db.minimap)
    self.button = LibDBIcon:GetMinimapButton(LAUNCHER_NAME)
    self:Restyle()
end

-- The Settings page's Minimap button switch. NeedRollDB.minimap.hide is
-- what LibDBIcon reads at login; Show and Hide only change the button now.
function MinimapButton:SetHidden(hide)
    ns.db.minimap.hide = hide
    if hide then
        LibDBIcon:Hide(LAUNCHER_NAME)
    else
        LibDBIcon:Show(LAUNCHER_NAME)
    end
end

-- /nr minimap: show or hide the button.
function MinimapButton:Toggle()
    self:SetHidden(not ns.db.minimap.hide)
    ns:Print(ns.db.minimap.hide and L["Minimap button hidden. Type /nr minimap to show it again."]
        or L["Minimap button shown."])
end

ns:On("PLAYER_LOGIN", function() MinimapButton:Build() end)
