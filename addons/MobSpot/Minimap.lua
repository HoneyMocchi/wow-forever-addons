local KO = setmetatable({}, { __index = function(_, key) return key end })
if GetLocale() == "koKR" then
    KO[" of "] = " / "
    KO["Click for options, right-click to turn scanning on or off"] = "왼쪽 클릭: 설정 / 오른쪽 클릭: 감지 켜기·끄기"
    KO["Mobs on the list"] = "등록된 NPC"
    KO["Scanning for your mobs"] = "등록한 NPC 감지 중"
    KO["Scanning is off"] = "감지 꺼짐"
end
-- MobSpot: minimap button (LibDBIcon, so minimap button collectors pick it up) and addon
-- compartment entry. Click for options, right-click to turn scanning on or off.

local _, ns = ...

local NAME = "MobSpot" -- the button's name with LibDBIcon
local LDBIcon = LibStub("LibDBIcon-1.0")
local registered = false

local function fillTooltip(tooltip)
	tooltip:SetText(ns.TITLE)
	if ns.db.enabled then
		tooltip:AddLine(KO["Scanning for your mobs"], 0.25, 1, 0.25)
	else
		tooltip:AddLine(KO["Scanning is off"], 1, 0.82, 0)
	end
	local on, total = 0, 0
	for _, mob in pairs(ns.db.mobs) do
		total = total + 1
		if mob.on then on = on + 1 end
	end
	tooltip:AddDoubleLine(KO["Mobs on the list"], on == total and total or (on .. KO[" of "] .. total), 1, 0.82, 0, 1, 1, 1)
	tooltip:AddLine(" ")
	tooltip:AddLine(KO["Click for options, right-click to turn scanning on or off"], 0.6, 0.6, 0.6)
end

local function onClick(mouseButton)
	if mouseButton == "RightButton" then
		ns.SetEnabled(not ns.db.enabled)
	else
		ns.OpenOptions()
	end
end

-- Shows or hides the minimap button, from the options or /ms minimap.
function ns.SetMinimapShown(shown)
	ns.db.minimap.hide = not shown
	if registered then
		if shown then LDBIcon:Show(NAME) else LDBIcon:Hide(NAME) end
	end
	ns.Fire("SettingChanged", "minimap")
end

ns.On("PLAYER_LOGIN", function()
	local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(NAME, {
		type = "launcher",
		label = ns.TITLE,
		icon = ns.ICON,
		OnClick = function(_, mouseButton) onClick(mouseButton) end,
		OnTooltipShow = fillTooltip,
	})
	LDBIcon:Register(NAME, launcher, ns.db.minimap)
	registered = true
end)

-- Addon compartment (the addon menu on the minimap), named in the .toc.
function MobSpot_OnAddonCompartmentClick(_, mouseButton)
	onClick(mouseButton)
end

function MobSpot_OnAddonCompartmentEnter(_, menuButton)
	GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
	fillTooltip(GameTooltip)
	GameTooltip:Show()
end

function MobSpot_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
