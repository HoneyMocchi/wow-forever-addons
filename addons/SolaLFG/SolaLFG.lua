-- Version is read from TOC metadata
-- Increment Revision to reset options in SolaFP_Init
local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
SolaFP_DISPLAY_VERSION = (getMeta and (getMeta("SolaLFG", "version") or getMeta("FindParty", "version"))) or "1.0"
SolaFP_Revision = 20

----------------------
-- Core variables
----------------------
SolaFP_Version = 1
SolaFP_Options = nil
SolaFP_Filter_Dungeon = {}
SolaFP_UserDefinedWhMsg = nil
SolaFP_UserDefineFilterMsg = ""
SolaFP_UserDefineIgnoreMsg = ""

SolaFP_Minimap_Save = {
	ButtonRadius = 78,
	ButtonShown = true,
	ButtonPosition = 336,
	Angle = 0
}

SolaFP_Position_Save = {
	["point"] = nil,
	["relpoint"] = nil,
	["x"] = nil,
	["y"] = nil,
	["width"] = nil
}

SolaFP_Backdrop_Info = {
	bgFile   = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
}

local lastUpdatedTime = 0
local isAnnouncing = false
local lastAnnouncedTime = 0
local isDungeonFiltering = false
local shouterSelected = nil

local function getDungeonFilterNum()
	local num = 0
	if SolaFP_Filter_Dungeon then
		for _, tbl in pairs(SolaFP_Filter_Dungeon) do
			for _, _ in pairs(tbl) do
				num = num + 1
			end
		end
	end
	return num
end
SolaFP_GetDungeonFilterNum = getDungeonFilterNum
local frameData = {}
local exceptionData = {}
local custom_ignore_keywords = {}
local colName = {"time", "dungeon", "name", "msg"}
local colFrame = {"DungeonText", "NameText", "MsgText"}

local SolaFP_UPDATE_INTERVAL = 2
local ASCD = true
local DESC = false
local INC = 1
local DEC = 2
local MAX = 3
local MIN = 4

local sortData = {
	["time"] = ASCD,
	["dungeon"] = ASCD,
	["name"] = ASCD,
	["msg"] = ASCD,
	["current_sort"] = "dungeon"
}

local SolaFP_Option_Menu = {
	[1] = {
		name = SolaFP_OPTIONS_CHANNEL,
		dbname = "channel",
		value = {},
	},
	[2] = {
		name = SolaFP_OPTIONS_INTERVAL,
		dbname = "interval",
		value = {"30","45","60","90","120","300"},
	},
	[3] = {
		name = SolaFP_OPTIONS_VALID,
		dbname = "valid",
		value = {"60","90","120","180","240","300"},
	},
	[4] = {
		name = "",
	},
	[5] = {
		name = SolaFP_OPTIONS_FONTSIZE,
		dbname = "fontsize",
		value = {"12","13","14","15","16","17","18"},
	},
	[6] = {
		name = SolaFP_L["Window Scale"] or SolaFP_OPTIONS_SCALE or "창 크기",
		dbname = "scale",
		value = {"2","1.9","1.8","1.7","1.6","1.5","1.4","1.3","1.2","1.1","1","0.9","0.8","0.7","0.6","0.5"},
	},
	[7] = {
		name = SolaFP_L["Window Color"] or SolaFP_OPTIONS_COLOR or "창 색상",
		dbname = "color",
	},
	[8] = {
		name = "",
	},
	[9] = {
		name = SolaFP_L["Minimap Icon"] or SolaFP_OPTIONS_ICON or "미니맵 아이콘 보기",
		dbname = "icon",
		exec = function(self) SolaFP_Minimap_ButtonToggle(self.checked) end,
	},
	[10] = {
		name = SolaFP_L["Close with ESC"] or SolaFP_OPTIONS_ESC or "ESC로 창 닫기",
		dbname = "esc",
		exec = function(self) SolaFP_SetSpecialFrame(self.checked) end,
	},
	[11] = {
		name = SolaFP_OPTIONS_RIGHTBUTTON,
		dbname = "rightButton",
		exec = function(self) SolaFP_Options.rightButton = self.checked end,
	},
	[12] = {
		name = SolaFP_OPTIONS_LFG_ONLY or "기본 파티 탐색기만 표시",
		dbname = "lfgOnly",
		exec = function(self)
			local chk = self.checked
			if C_Timer and C_Timer.After then
				C_Timer.After(0, function()
					if SolaFP_SetLFGOnlyMode then
						SolaFP_SetLFGOnlyMode(chk)
					else
						SolaFP_Options.lfgOnly = chk
					end
				end)
			else
				if SolaFP_SetLFGOnlyMode then
					SolaFP_SetLFGOnlyMode(chk)
				else
					SolaFP_Options.lfgOnly = chk
				end
			end
		end,
	},
	[13] = {
		name = "",
	},
	[14] = {
		name = SolaFP_OPTIONS_NORAID,
		dbname = "noraid",
		exec = function(self) SolaFP_Options.noraid = self.checked end,
	},
	[15] = {
		name = SolaFP_OPTIONS_NOPVP,
		dbname = "nopvp",
		exec = function(self) SolaFP_Options.nopvp = self.checked end,
	},
	[16] = {
		name = "",
	},
	[17] = {
		name = SolaFP_L["Reset"] or SolaFP_OPTIONS_RESET or "설정 초기화",
		dbname = "reset",
		value = {
			[1] = {
				name = SolaFP_L["Reset Window Position"] or SolaFP_OPTIONS_RESETPOS or "창 위치",
				exec = function() SolaFP_LoadDefaultWinPos() end,
			},
			[2] = {
				name = SolaFP_L["Reset Window Size"] or SolaFP_OPTIONS_RESETSIZE or "창 크기",
				exec = function() SolaFP_LoadDefaultWinSize() end,
			},
			[3] = {
				name = SolaFP_L["Reset All Settings"] or SolaFP_OPTIONS_RESETALL or "모든 설정 초기화",
				exec = function() SolaFP_LoadDefaultOption() end,
			},
		},
	},
	[18] = {
		name = SolaFP_L["View Update Notes"] or "업데이트 안내 보기",
		exec = function()
			if SolaFP_ShowUpdatePopup then SolaFP_ShowUpdatePopup(true) end
		end,
	},
	[19] = {
		name = SolaFP_L["Close"] or SolaFP_TEXT_CLOSE or "닫기",
		dbname = "close",
		exec = "",
	},
}

local SolaFP_Default_Options= {
	["channel"] = {
		[SolaFP_DEFAULT_PARTY_CHANNEL] = true,
		["파티"] = true,
		["파티찾기"] = true,
		["거래"] = true,
		["공개"] = true,
		["LookingForGroup"] = true,
		["Trade"] = true,
		["General"] = true,
	},
	["color"] = { ["r"] = 0.04, ["g"] = 0.06, ["b"] = 0.09, ["opacity"] = 0.85 },
	["interval"] = 30,
	["valid"] = 120,
	["scale"] = 1,
	["fontsize"] = 13,
	["viewLines"] = 20,
	["titlebarVisible"] = true,
	["menubarVisible"] = true,
	["activated"] = true,
	["icon"] = true,
	["iconLocked"] = false,
	["activateBellnWindow"] = false,
	["useroffed"] = false,
	["rightButton"] = false,
	["esc"] = true,
	["noraid"] = true,
	["nopvp"] = true,
	["lfgPanelOpen"] = false,
	["lfgFilterDrawerOpen"] = true,
	["lfgAllLevels"] = true,
	["lfgSelectedActivities"] = {},
	["lfgOnly"] = false,
	["viewModeSelected"] = false,
}

local SolaFP_Category_Color = {
	["forever"] = { 0.831, 0.655, 0.271 }, -- Sola Gold (#D4A745)
	["raid40"]  = { 0.608, 0.557, 0.769 }, -- Sola Lavender (#9B8EC4)
	["raid20"]  = { 0.812, 0.400, 0.475 }, -- Sola Rose (#CF6679)
	["raid10"]  = { 0.878, 0.565, 0.314 }, -- Sola Amber (#E09050)
	["field"]   = { 0.825, 0.725, 0.485 }, -- Sola Gold-Beige (#D2B97C)
	["dungeon"] = { 0.353, 0.749, 0.690 }, -- Sola Teal (#5ABFBA)
	["bg"]      = { 0.420, 0.749, 0.541 }, -- Sola Mint (#6BBF8A)
	["quest"]   = { 0.941, 0.929, 0.910 }, -- Sola fgMain (#F0EDE8)
	["service"] = { 0.424, 0.745, 0.890 }, -- Sola Sky Blue (#6CBDDF)
	["guild"]   = { 0.550, 0.820, 0.450 }, -- Sola Soft Green (#8CD173)
	["trade"]   = { 0.950, 0.720, 0.320 }, -- Sola Warm Gold (#F2B852)
	["craft"]   = { 0.550, 0.850, 0.750 }, -- Sola Sage Green (#8CD9BF)
}

------------------------
-- Minimap icon setup
------------------------
-- Based on the Hit Assist minimap button
CreateFrame("Button", "SolaFP_Minimap_Button", Minimap)

SolaFP_Minimap_Button:EnableMouse(true)
SolaFP_Minimap_Button:SetMovable(false)
SolaFP_Minimap_Button:SetFrameStrata("MEDIUM")
SolaFP_Minimap_Button:SetWidth(33)
SolaFP_Minimap_Button:SetHeight(33)
SolaFP_Minimap_Button:SetPoint("TOPLEFT", Minimap, "LEFT", 2, 0)
SolaFP_Minimap_Button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

SolaFP_Minimap_Button:CreateTexture("SolaFP_Minimap_ButtonIcon", "BORDER")
SolaFP_Minimap_ButtonIcon:SetWidth(20)
SolaFP_Minimap_ButtonIcon:SetHeight(20)
SolaFP_Minimap_ButtonIcon:SetPoint("CENTER", -2, 1)
SolaFP_Minimap_ButtonIcon:SetTexture("Interface\\AddOns\\SolaLFG\\SIM-Icon") --INV_Misc_Bag_10_Blue

SolaFP_Minimap_Button:CreateTexture("SolaFP_Minimap_ButtonBorder", "OVERLAY")
SolaFP_Minimap_ButtonBorder:SetWidth(52)
SolaFP_Minimap_ButtonBorder:SetHeight(52)
SolaFP_Minimap_ButtonBorder:SetPoint("TOPLEFT")
SolaFP_Minimap_ButtonBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

function SolaFP_Minimap_Button_Init()
	SolaFP_Minimap_Save.ButtonRadius = SolaFP_Minimap_Save.ButtonRadius or 78
	SolaFP_Minimap_Save.ButtonPosition = SolaFP_Minimap_Save.ButtonPosition or 345
	SolaFP_Minimap_Button_UpdatePosition()
	SolaFP_Minimap_Button:UnregisterEvent("VARIABLES_LOADED")
end

function SolaFP_Minimap_Button_UpdatePosition()
	SolaFP_Minimap_Button:ClearAllPoints()
	SolaFP_Minimap_Button:SetSize(33, 33)
	if SolaFP_Minimap_ButtonIcon then
		SolaFP_Minimap_ButtonIcon:SetSize(20, 20)
	end
	SolaFP_Minimap_Button:SetPoint(
		"TOPLEFT",
		"Minimap",
		"TOPLEFT",
		54 - (SolaFP_Minimap_Save.ButtonRadius * cos(SolaFP_Minimap_Save.ButtonPosition)),
		(SolaFP_Minimap_Save.ButtonRadius * sin(SolaFP_Minimap_Save.ButtonPosition)) - 55
	)
end

-- Thanks to Yatlas for this code
function SolaFP_Minimap_Button_BeingDragged()
	-- Thanks to Gello for this code
	local xpos,ypos = GetCursorPosition()
	local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom()

	xpos = xmin-xpos/UIParent:GetScale()+70
	ypos = ypos/UIParent:GetScale()-ymin-70

	local v = math.deg(math.atan2(ypos, xpos))
	if v < 0 then
		v = v + 360
	end
	SolaFP_Minimap_Save.ButtonPosition = v
	SolaFP_Minimap_Button_UpdatePosition()

end

SolaFP_Minimap_Button:RegisterEvent("VARIABLES_LOADED")
SolaFP_Minimap_Button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
SolaFP_Minimap_Button:RegisterForDrag("LeftButton")
SolaFP_Minimap_Button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", SolaFP_Minimap_Button_BeingDragged) end)
SolaFP_Minimap_Button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
SolaFP_Minimap_Button:SetScript("OnClick", function(self, button)
	if SolaFP_IconClicked then
		SolaFP_IconClicked(self, button)
	end
end)
local function SolaFP_ShowMinimapTooltip(tooltip, owner, anchor)
	if owner and anchor then
		tooltip:SetOwner(owner, anchor)
	end
	tooltip:ClearLines()

	local verStr = SolaFP_DISPLAY_VERSION or (SolaFP_GetVersionString and SolaFP_GetVersionString()) or "1.0"
	local authorStr = ((SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) == "koKR") and "Sola-아즈샤라" or "Sola"
	tooltip:SetText("|cffD4A745SolaLFG [" .. verStr .. "]|r |cff8A8580/|r |cff5ABFB0" .. authorStr .. "|r")

	tooltip:AddDoubleLine("|cffD4A745" .. (SolaFP_L["Left-Click"] or "왼쪽 클릭") .. "|r", "|cffffffff" .. (SolaFP_L["Toggle Party Finder"] or "파티 찾기 도우미 열기") .. "|r")
	tooltip:AddDoubleLine("|cffD4A745" .. (SolaFP_L["Right-Click"] or "오른쪽 클릭") .. "|r", "|cffffffff" .. (SolaFP_L["Settings"] or "설정") .. "|r")
	tooltip:AddDoubleLine("|cffD4A745" .. (SolaFP_L["Alt + Click"] or "Alt + 클릭") .. "|r", "|cffffffff" .. (SolaFP_L["Lock / Unlock Icon"] or "아이콘 고정 / 해제") .. "|r")
	tooltip:AddDoubleLine("|cffD4A745" .. (SolaFP_L["Shift + Left-Click"] or "Shift + 좌클릭") .. "|r", "|cffffffff" .. (SolaFP_L["Enable / Disable Addon"] or "애드온 작동 / 작동정지") .. "|r")

	tooltip:AddLine(" ")

	local actText = (SolaFP_Options and SolaFP_Options.activated) and ("|cff6BBF8A" .. (SolaFP_L["Active"] or "작동중") .. "|r") or ("|cffCF6679" .. (SolaFP_L["Inactive"] or "작동정지") .. "|r")
	local lockText = (SolaFP_Options and SolaFP_Options.iconLocked) and ("|cff8A8580" .. (SolaFP_L["Locked"] or "고정됨") .. "|r") or ("|cffE09050" .. (SolaFP_L["Movable (Drag)"] or "이동가능 (좌클릭 드래그)") .. "|r")
	tooltip:AddDoubleLine("|cff8A8580" .. (SolaFP_L["Addon Status"] or "애드온 상태") .. "|r", actText)
	tooltip:AddDoubleLine("|cff8A8580" .. (SolaFP_L["Icon Position"] or "아이콘 위치") .. "|r", lockText)

	tooltip:Show()
end

SolaFP_Minimap_Button:SetScript("OnEnter", function(self)
	SolaFP_ShowMinimapTooltip(GameTooltip, self, "ANCHOR_LEFT")
end)
SolaFP_Minimap_Button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
SolaFP_Minimap_Button:SetScript("OnEvent", SolaFP_Minimap_Button_Init)

----------------
-- LibDataBroker feed
----------------
local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
if ldb then
	ldb:NewDataObject("SolaLFG", {
		type = "launcher",
		text = SolaFP_C_TITLE,
		icon = "Interface\\AddOns\\SolaLFG\\SIM-Icon",
		OnClick = function(self, button)
			if SolaFP_IconClicked then
				SolaFP_IconClicked(self, button)
			end
		end,
		OnTooltipShow = function(tooltip)
			if SolaFP_ShowMinimapTooltip then
				SolaFP_ShowMinimapTooltip(tooltip)
			end
		end,
	})
end

-----------------
-- Tooltip definitions
-----------------

-------------------------------------------------
-- Help Popup Frame
-------------------------------------------------
local fp_helpFrame = nil

function SolaFP_ToggleHelpFrame()
	if fp_helpFrame and fp_helpFrame:IsShown() then
		fp_helpFrame:Hide()
		return
	end

	if not fp_helpFrame then
		local f = CreateFrame("Frame", "SolaFP_HelpFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		fp_helpFrame = f
		f:SetScale(1.32)
		f:SetSize(380, 420)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		f:SetFrameStrata("DIALOG")
		f:SetFrameLevel(200)
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)

		local function OnHelpMouseDown(self, button)
			if button == "RightButton" and not IsAltKeyDown() and not IsControlKeyDown() and not IsShiftKeyDown() then
				if fp_helpFrame and fp_helpFrame:IsShown() then
					fp_helpFrame:Hide()
				end
			end
		end
		f:SetScript("OnMouseDown", OnHelpMouseDown)
		f:SetScript("OnHide", function()
			PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE or 851)
		end)
		tinsert(UISpecialFrames, "SolaFP_HelpFrame")

		f:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
			insets = { left = 1, right = 1, top = 1, bottom = 1 },
		})
		f:SetBackdropColor(0.055, 0.050, 0.045, 0.96)
		f:SetBackdropBorderColor(0.831, 0.655, 0.271, 0.45)

		-- Title bar accent line
		local accent = f:CreateTexture(nil, "ARTWORK")
		accent:SetHeight(2)
		accent:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
		accent:SetColorTexture(0.831, 0.655, 0.271, 0.7)

		-- Title
		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOPLEFT", 14, -12)
		title:SetText("SolaLFG - " .. (SolaFP_TEXT_HELP or "Help"))
		title:SetTextColor(0.831, 0.655, 0.271)
		title:SetFont(title:GetFont(), 13)

		-- Version
		local ver = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		ver:SetPoint("TOPRIGHT", -14, -14)
		ver:SetText("v" .. (SolaFP_DISPLAY_VERSION or (SolaFP_GetVersionString and SolaFP_GetVersionString()) or "1.0"))
		ver:SetTextColor(0.541, 0.522, 0.502)

		-- Close button
		local closeBtn = CreateFrame("Button", nil, f)
		closeBtn:SetSize(20, 20)
		closeBtn:SetPoint("TOPRIGHT", -4, -4)
		closeBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		closeBtn:SetScript("OnClick", function() f:Hide() end)
		local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		closeTxt:SetPoint("CENTER")
		closeTxt:SetText("X")
		closeTxt:SetTextColor(0.7, 0.5, 0.5)
		closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 0.6, 0.6) end)
		closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(0.7, 0.5, 0.5) end)

		-- Separator under title
		local sep = f:CreateTexture(nil, "ARTWORK")
		sep:SetHeight(1)
		sep:SetPoint("TOPLEFT", 10, -32)
		sep:SetPoint("TOPRIGHT", -10, -32)
		sep:SetColorTexture(0.831, 0.655, 0.271, 0.15)

		-- Scroll frame for content
		local sf = CreateFrame("ScrollFrame", "SolaFP_HelpScrollFrame", f, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", 12, -38)
		sf:SetPoint("BOTTOMRIGHT", -28, 12)
		sf:EnableMouse(true)
		sf:SetScript("OnMouseDown", OnHelpMouseDown)

		local scrollChild = CreateFrame("Frame", nil, sf)
		scrollChild:SetSize(330, 1)
		scrollChild:EnableMouse(true)
		scrollChild:SetScript("OnMouseDown", OnHelpMouseDown)
		scrollChild:SetScript("OnMouseWheel", function(self, delta)
			local wheelFunc = sf:GetScript("OnMouseWheel")
			if wheelFunc then
				wheelFunc(sf, delta)
			elseif ScrollFrame_OnMouseWheel then
				ScrollFrame_OnMouseWheel(sf, delta)
			end
		end)
		sf:SetScrollChild(scrollChild)

		-- Style scrollbar
		local sb = _G["SolaFP_HelpScrollFrameScrollBar"]
		if sb then
			sb:SetWidth(6)
			local regions = {sb:GetRegions()}
			for i = 1, #regions do
				local r = regions[i]
				if r:IsObjectType("Texture") then r:SetAlpha(0) end
			end
			local thumb = sb:GetThumbTexture()
			if thumb then
				thumb:SetColorTexture(0.831, 0.655, 0.271, 0.4)
				thumb:SetWidth(4)
			end
			local upBtn = _G["SolaFP_HelpScrollFrameScrollBarScrollUpButton"]
			local downBtn = _G["SolaFP_HelpScrollFrameScrollBarScrollDownButton"]
			if upBtn then upBtn:Hide(); upBtn:SetAlpha(0) end
			if downBtn then downBtn:Hide(); downBtn:SetAlpha(0) end
		end

		-- Build help content
		local helpLines = SolaFP_HELP_DATA or {}

		local yOff = -4
		for _, line in ipairs(helpLines) do
			if line.t == "gap" then
				yOff = yOff - 10
			elseif line.t == "title" then
				local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				fs:SetPoint("TOPLEFT", 4, yOff)
				fs:SetPoint("RIGHT", scrollChild, "RIGHT", -4, 0)
				fs:SetJustifyH("CENTER")
				fs:SetText(line.text)
				fs:SetTextColor(0.831, 0.655, 0.271)
				yOff = yOff - 22
			elseif line.t == "header" then
				local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				fs:SetPoint("TOPLEFT", 4, yOff)
				fs:SetText(line.text)
				fs:SetTextColor(1, 0.85, 0.5)
				fs:SetFont(fs:GetFont(), 11)
				yOff = yOff - 18
			elseif line.t == "key" then
				local kfs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				kfs:SetPoint("TOPLEFT", 12, yOff)
				kfs:SetText("|cffD4A745" .. line.key .. "|r")
				local dfs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				dfs:SetPoint("TOPLEFT", 170, yOff)
				dfs:SetPoint("RIGHT", scrollChild, "RIGHT", -4, 0)
				dfs:SetText(line.desc)
				dfs:SetTextColor(0.85, 0.84, 0.82)
				yOff = yOff - 16
			elseif line.t == "text" then
				local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				fs:SetPoint("TOPLEFT", 12, yOff)
				fs:SetPoint("RIGHT", scrollChild, "RIGHT", -4, 0)
				fs:SetJustifyH("LEFT")
				fs:SetText(line.text)
				fs:SetTextColor(0.82, 0.81, 0.79)
				fs:SetWordWrap(true)
				local textH = fs:GetStringHeight() or 14
				yOff = yOff - textH - 4
			elseif line.t == "dim" then
				local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				fs:SetPoint("TOPLEFT", 4, yOff)
				fs:SetPoint("RIGHT", scrollChild, "RIGHT", -4, 0)
				fs:SetJustifyH("CENTER")
				fs:SetText(line.text)
				fs:SetTextColor(0.45, 0.43, 0.41)
				fs:SetWordWrap(true)
				local textH = fs:GetStringHeight() or 14
				yOff = yOff - textH - 6
			end
		end

		scrollChild:SetHeight(math.abs(yOff) + 10)
	end

	fp_helpFrame:Show()
end

SolaFP_Tooltip = {
	["DEFAULT"] = function(msg, frame, anchor, pX, pY)
		GameTooltip:SetOwner(frame, anchor, pX or 0, pY or 0)
		GameTooltip:ClearLines()
		local title, desc = msg, nil
		local nlPos = string.find(msg, "\n")
		if nlPos then
			title = string.sub(msg, 1, nlPos - 1)
			desc = string.sub(msg, nlPos + 1)
		end
		GameTooltip:SetText(title, 1, 0.85, 0.5)
		if desc and desc ~= "" then
			GameTooltip:AddLine(desc, 0.8, 0.8, 0.8, true)
		end
		GameTooltip:Show()
	end,
	["LIST"] = function(self)
		local text = _G[self:GetName().."MsgText"]:GetText()
		if text then
			SolaFP_Tooltip.DEFAULT(text, _G[self:GetName().."Name"], "ANCHOR_TOPLEFT", 0, 0)
		end
	end,
	["SORTTIME"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_SORT_TIME, self, "ANCHOR_TOPRIGHT")
	end,
	["FILTERDUNGEON"] = function(self)
		local msg = SolaFP_TOOLTIP_DUNGEON_FILTER or ""
		local stateHeader = ""
		if getDungeonFilterNum() > 0 then
			if isDungeonFiltering then
				stateHeader = "|cff6BBF8A[" .. (SolaFP_L and SolaFP_L["Filtering Interested Dungeons"] or "관심 던전 필터 적용 중") .. "]|r\n\n"
			else
				stateHeader = "|cffE0C068[" .. (SolaFP_L and SolaFP_L["Viewing All Dungeons (Paused)"] or "모두 보기 (관심 던전 필터 일시 해제)") .. "]|r\n\n"
			end
		end
		local desc = SolaFP_GetDungeonFilterList()
		if desc and desc ~= "" then
			msg = stateHeader .. msg .. desc
		end
		SolaFP_Tooltip.DEFAULT(msg, self, "ANCHOR_TOPRIGHT")
	end,
	["CLOSE"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_CLOSE, self, "ANCHOR_TOPRIGHT")
	end,
	["MAXMIZE"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_MAXMIZE, self, "ANCHOR_TOPRIGHT")
	end,
	["MINIMIZE"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_MINIMIZE, self, "ANCHOR_TOPRIGHT")
	end,
	["DECREASE"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_DECREASE, self, "ANCHOR_TOPRIGHT")
	end,
	["INCREASE"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_INCREASE, self, "ANCHOR_TOPRIGHT")
	end,
	["OPTION"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_OPTION, self, "ANCHOR_TOPRIGHT")
	end,
	["ANNOUNCE"] = function(self)
		local msg
		if SolaFP_IsAnnoucing and SolaFP_IsAnnoucing() then
			msg = SolaFP_TOOLTIP_AD_ON
		else
			msg = SolaFP_TOOLTIP_AD_OFF
		end
		SolaFP_Tooltip.DEFAULT(msg, self, "ANCHOR_TOPRIGHT")
	end,
	["ACTIVATE"] = function(self)
		local msg
		if SolaFP_Options.activated then
			msg = SolaFP_TOOLTIP_ACTIVATE_ON
		else
			msg = SolaFP_TOOLTIP_ACTIVATE_OFF
		end
		SolaFP_Tooltip.DEFAULT(msg, self, "ANCHOR_TOPRIGHT")
	end,
	["ACTIVATEBELLNWINDOW"] = function(self)
		local msg
		if SolaFP_Options.activateBellnWindow then
			msg = SolaFP_TOOLTIP_POPUP_ON
		else
			msg = SolaFP_TOOLTIP_POPUP_OFF
		end
		SolaFP_Tooltip.DEFAULT(msg, self, "ANCHOR_TOPRIGHT")
	end,
	["APPLYBINDING"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_SHORTCUT_ALT, self, "ANCHOR_TOPRIGHT")
	end,
	["EXCEPTIONBINDING"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_SHORTCUT_CTRL, self, "ANCHOR_TOPRIGHT")
	end,
	["WHOBINDING"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_SHORTCUT_SHIFT, self, "ANCHOR_TOPRIGHT")
	end,
	["WHISPERBINDING"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_SHORTCUT_ALT_RIGHT, self, "ANCHOR_TOPRIGHT")
	end,
	["IGNORE"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_IGNORE, self, "ANCHOR_TOPRIGHT")
	end,
	["DISABLED"] = function(self)
		SolaFP_Tooltip.DEFAULT(SolaFP_TOOLTIP_DISABLED, self, "ANCHOR_TOPRIGHT")
	end,
}

-------------------
-- Addon initialization
-------------------

-------------------------------------------------
-- Modern Translucent Dark Glass Theme
-------------------------------------------------
local SolaC = {
	bgMain     = { 0.105, 0.087, 0.067, 0.98 },
	bgSidebar  = { 0.133, 0.109, 0.081, 0.99 },
	bgSelected = { 0.290, 0.218, 0.126, 1 },
	bgInput    = { 0.073, 0.061, 0.048, 0.99 },
	bgHover    = { 0.196, 0.161, 0.114, 1 },
	bgBtn      = { 0.205, 0.170, 0.119, 1 },

	fgMain     = { 0.951, 0.914, 0.828 },
	fgDim      = { 0.746, 0.700, 0.604 },
	fgDisabled = { 0.480, 0.460, 0.440 },

	gold       = { 0.908, 0.747, 0.422 },
	goldBeige  = { 0.951, 0.869, 0.664 },
	goldMuted  = { 0.570, 0.445, 0.261 },
	teal       = { 0.498, 0.648, 0.472 },
	mint       = { 0.420, 0.749, 0.541 },
	rose       = { 0.812, 0.400, 0.475 },
	amber      = { 0.878, 0.565, 0.314 },
	lavender   = { 0.608, 0.557, 0.769 },

	rimLight   = { 1.0, 1.0, 1.0, 0.08 },
	glassLine  = { 0.630, 0.526, 0.352, 0.27 },
	borderDark = { 0.0, 0.0, 0.0, 0.70 },
}

SolaFP_SolaC = SolaC

function SolaFP_EnsureSpecialFrame()
	if SolaFP_Options and SolaFP_Options.esc == false then return end
	for i = 1, #UISpecialFrames do
		if UISpecialFrames[i] == "SolaFP_Frame" then
			return
		end
	end
	tinsert(UISpecialFrames, "SolaFP_Frame")
end

-------------------------------------------------
-- Window Width Limits & Responsive UI Support
-------------------------------------------------
-- Window width limits and responsive breakpoints
local SolaFP_MIN_WIDTH = 535
local SolaFP_MAX_WIDTH = 992
local SolaFP_COLLAPSE_WIDTH = 616
local SolaFP_COLLAPSE_WIDTH_EARLY = 633
local SolaFP_COLLAPSE_WIDTH_SLIDER = 608

local function SolaFP_UpdateWidthResponsiveUI(width)
	local curWidth = width
	if not curWidth then
		if SolaFP_Position_Save and SolaFP_Position_Save.width then
			curWidth = SolaFP_Position_Save.width
		elseif SolaFP_ListFrame and SolaFP_ListFrame.GetWidth then
			curWidth = SolaFP_ListFrame:GetWidth()
		end
	end
	curWidth = curWidth or 750

	-- Dynamically detect the rightmost edge of visible left-side title bar buttons
	-- (KeyBind -> Activation [감지] -> ActivateBellnWindow [팝업] -> Announcing [광고])
	local leftPillRight = 0
	if SolaFP_TitleFrame and SolaFP_TitleFrame.GetLeft and SolaFP_TitleFrame:GetLeft() then
		local tfLeft = SolaFP_TitleFrame:GetLeft()
		if SolaFP_TitleFrameAnnouncing and SolaFP_TitleFrameAnnouncing:IsShown() and SolaFP_TitleFrameAnnouncing.GetRight and SolaFP_TitleFrameAnnouncing:GetRight() then
			local r = SolaFP_TitleFrameAnnouncing:GetRight() - tfLeft
			if r > 200 and r < 600 then
				leftPillRight = r
			end
		elseif SolaFP_TitleFrameActivateBellnWindow and SolaFP_TitleFrameActivateBellnWindow:IsShown() and SolaFP_TitleFrameActivateBellnWindow.GetRight and SolaFP_TitleFrameActivateBellnWindow:GetRight() then
			local r = SolaFP_TitleFrameActivateBellnWindow:GetRight() - tfLeft
			if r > 200 and r < 500 then
				leftPillRight = r
			end
		elseif SolaFP_TitleFrameActivation and SolaFP_TitleFrameActivation:IsShown() and SolaFP_TitleFrameActivation.GetRight and SolaFP_TitleFrameActivation:GetRight() then
			local r = SolaFP_TitleFrameActivation:GetRight() - tfLeft
			if r > 150 and r < 400 then
				leftPillRight = r
			end
		end
	end

	-- Safe fallbacks if frames have not been laid out by the renderer yet
	if leftPillRight <= 0 then
		if SolaFP_TitleFrameAnnouncing and SolaFP_TitleFrameAnnouncing:IsShown() then
			leftPillRight = 405
		elseif SolaFP_TitleFrameActivateBellnWindow and SolaFP_TitleFrameActivateBellnWindow:IsShown() then
			leftPillRight = 324
		elseif SolaFP_TitleFrameActivation and SolaFP_TitleFrameActivation:IsShown() then
			leftPillRight = 246
		else
			leftPillRight = 144
		end
	end

	-- 1. UI Slider collision timing:
	-- Distance from window right edge to leftmost tip of "UI" label is ~276px + 8px margin = 284px.
	-- It hides right as the "UI" text approaches the rightmost left-side button (e.g. ~608px for 팝업, ~689px for 광고).
	local sliderCollapseWidth = math.floor(leftPillRight + 284)

	-- 2. Help Button collision timing:
	-- Distance from window right edge to left edge of Help button is 140px + 8px margin = 148px.
	-- It hides right as it approaches the left-side buttons (e.g. ~553px for 광고).
	local helpCollapseWidth = math.floor(leftPillRight + 148)

	local hideElements = (curWidth < SolaFP_COLLAPSE_WIDTH)
	local hideEarlyElements = (curWidth < SolaFP_COLLAPSE_WIDTH_EARLY)
	local hideSlider = (curWidth < sliderCollapseWidth)
	local hideHelp = (curWidth < helpCollapseWidth)

	-- Scale slider (leftmost right-side element: hides FIRST as "UI" text approaches Ad button)
	if SolaFP_ScaleSlider then
		if hideSlider then
			SolaFP_ScaleSlider:Hide()
			if SolaFP_ScaleSlider.__fp_label then
				SolaFP_ScaleSlider.__fp_label:Hide()
			end
		else
			SolaFP_ScaleSlider:ClearAllPoints()
			if SolaFP_MenuFrameInfo then
				SolaFP_ScaleSlider:SetPoint("RIGHT", SolaFP_MenuFrameInfo, "LEFT", -12, 0)
			elseif SolaFP_TitleFrameOption then
				SolaFP_ScaleSlider:SetPoint("RIGHT", SolaFP_TitleFrameOption, "LEFT", -12, 0)
			end
			SolaFP_ScaleSlider:Show()
			if SolaFP_ScaleSlider.__fp_label then
				SolaFP_ScaleSlider.__fp_label:Show()
			end
		end
	end

	-- Help button (positioned to the right of slider: stays visible down to ~553px and hides SECOND)
	if SolaFP_MenuFrameInfo then
		if hideHelp then
			SolaFP_MenuFrameInfo:Hide()
		else
			SolaFP_MenuFrameInfo:Show()
		end
	end

	-- Whisper button
	if SolaFP_MenuFrameWhisper then
		if hideElements then
			SolaFP_MenuFrameWhisper:Hide()
		else
			SolaFP_MenuFrameWhisper:Show()
		end
	end

	-- Who button
	if SolaFP_MenuFrameWho then
		if hideElements then
			SolaFP_MenuFrameWho:Hide()
		else
			SolaFP_MenuFrameWho:Show()
		end
	end

	-- Exclude filter button
	if SolaFP_MenuFrameIgnoreButton then
		if hideEarlyElements then
			SolaFP_MenuFrameIgnoreButton:Hide()
		else
			SolaFP_MenuFrameIgnoreButton:Show()
		end
	end

	-- Reset exclusions button
	if SolaFP_MenuFrameExceptionDelete then
		if hideEarlyElements then
			SolaFP_MenuFrameExceptionDelete:Hide()
		else
			SolaFP_MenuFrameExceptionDelete:Show()
		end
	end

	-- LFG toggle button
	if SolaFP_ListFrameLFGBtn then
		SolaFP_ListFrameLFGBtn:Show()
	end
end

function SolaFP_OnFrameShow(self)
	SolaFP_EnsureSpecialFrame()
	if not self.__fp_whHideHooked then
		self.__fp_whHideHooked = true
		self:HookScript("OnHide", function()
			if SolaFP_WhPresetFrame and SolaFP_WhPresetFrame:IsShown() then
				SolaFP_WhPresetFrame:Hide()
			end
		end)
	end
	if SolaFP_Options and SolaFP_Options.lfgOnly then
		self:Hide()
		if SolaFP_LFGPanel then
			SolaFP_LFGPanel:Show()
		elseif SolaFP_LFG_Init then
			SolaFP_LFG_Init()
			if SolaFP_LFGPanel then SolaFP_LFGPanel:Show() end
		end
		return
	end
	if SolaFP_WhAutoLevel then
		SolaFP_RefreshAutoWhMsg()
	end
	SolaFP_UpdateWidthResponsiveUI()
	if SolaFP_UpdateKeyBindingButton then SolaFP_UpdateKeyBindingButton() end
	if SolaFP_LFG_OnFrameShow then
		SolaFP_LFG_OnFrameShow()
	end
end

function SolaFP_StyleModernButton(btn, colorKey, customText)
	if not btn or not btn.IsObjectType or not btn:IsObjectType("Button") then return end

	if BackdropTemplateMixin and not btn.SetBackdrop then
		Mixin(btn, BackdropTemplateMixin)
		btn:OnBackdropLoaded()
	end

	if btn.SetNormalTexture then btn:SetNormalTexture("") end
	if btn.SetPushedTexture then btn:SetPushedTexture("") end
	if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
	if btn.SetHighlightTexture then btn:SetHighlightTexture("") end

	local regions = {btn:GetRegions()}
	for i = 1, #regions do
		local r = regions[i]
		if r:IsObjectType("Texture") and r ~= btn._fp_bg and r ~= btn._fp_border then
			r:SetAlpha(0)
		end
	end

	local r, g, b = SolaC.bgBtn[1], SolaC.bgBtn[2], SolaC.bgBtn[3]
	if colorKey == "teal" or colorKey == "primary" then
		r, g, b = SolaC.teal[1] * 0.42, SolaC.teal[2] * 0.42, SolaC.teal[3] * 0.42
	elseif colorKey == "mint" or colorKey == "success" then
		r, g, b = 0.22, 0.42, 0.32
	elseif colorKey == "rose" or colorKey == "danger" then
		r, g, b = 0.48, 0.22, 0.26
	elseif colorKey == "amber" or colorKey == "warning" then
		r, g, b = 0.46, 0.36, 0.26
	elseif colorKey == "gold" then
		r, g, b = SolaC.gold[1] * 0.48, SolaC.gold[2] * 0.48, SolaC.gold[3] * 0.48
	elseif colorKey == "dark" then
		r, g, b = 0.155, 0.128, 0.091
	end
	btn._r, btn._g, btn._b = r, g, b

	btn:SetBackdrop(SolaFP_Backdrop_Info)
	btn:SetBackdropColor(r, g, b, 0.88)
	btn:SetBackdropBorderColor(0.57, 0.46, 0.30, 0.45)

	local fs = btn:GetFontString()
	if not fs then
		fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("CENTER")
		btn:SetFontString(fs)
	end
	if customText then
		fs:SetText(customText)
	end
	fs:SetTextColor(SolaC.fgMain[1], SolaC.fgMain[2], SolaC.fgMain[3])
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 0.8)

	if not btn.__fp_btn_hooked then
		btn.__fp_btn_hooked = true
		btn:HookScript("OnEnter", function(self)
			local br = self._r or SolaC.bgBtn[1]
			local bg = self._g or SolaC.bgBtn[2]
			local bb = self._b or SolaC.bgBtn[3]
			self:SetBackdropColor(
				math.min(1, br * 1.5),
				math.min(1, bg * 1.5),
				math.min(1, bb * 1.5),
				0.95
			)
			local sfs = self:GetFontString()
			if sfs then sfs:SetTextColor(1, 1, 1) end
		end)
		btn:HookScript("OnLeave", function(self)
			local br = self._r or SolaC.bgBtn[1]
			local bg = self._g or SolaC.bgBtn[2]
			local bb = self._b or SolaC.bgBtn[3]
			self:SetBackdropColor(br, bg, bb, 0.88)
			local sfs = self:GetFontString()
			if sfs then sfs:SetTextColor(SolaC.fgMain[1], SolaC.fgMain[2], SolaC.fgMain[3]) end
		end)
	end
end

function SolaFP_StyleModernEditBox(eb, focusKey)
	if not eb or not eb.IsObjectType or not eb:IsObjectType("EditBox") then return end

	if BackdropTemplateMixin and not eb.SetBackdrop then
		Mixin(eb, BackdropTemplateMixin)
		eb:OnBackdropLoaded()
	end

	local regions = {eb:GetRegions()}
	for i = 1, #regions do
		local r = regions[i]
		if r:IsObjectType("Texture") and r ~= eb._fp_bg and r ~= eb._fp_border then
			r:SetAlpha(0)
		end
	end

	eb:SetBackdrop(SolaFP_Backdrop_Info)
	eb:SetBackdropColor(SolaC.bgInput[1], SolaC.bgInput[2], SolaC.bgInput[3], 0.98)
	eb:SetBackdropBorderColor(1, 1, 1, 0.08)
	eb:SetTextInsets(8, 8, 0, 0)
	eb:SetFontObject("GameFontHighlight")
	eb:SetTextColor(SolaC.fgMain[1], SolaC.fgMain[2], SolaC.fgMain[3])

	local fCol = SolaC.teal
	if focusKey == "rose" then
		fCol = SolaC.rose
	elseif focusKey == "gold" then
		fCol = SolaC.gold
	end

	if not eb.__fp_eb_hooked then
		eb.__fp_eb_hooked = true
		eb:HookScript("OnEscapePressed", function(self) self:ClearFocus() end)
		eb:HookScript("OnEditFocusGained", function(self)
			self:SetBackdropBorderColor(fCol[1], fCol[2], fCol[3], 0.65)
		end)
		eb:HookScript("OnEditFocusLost", function(self)
			self:SetBackdropBorderColor(1, 1, 1, 0.08)
		end)
	end
end

function SolaFP_StyleCloseButton(btn)
	if not btn then return end
	btn:SetSize(22, 22)
	if BackdropTemplateMixin and not btn.SetBackdrop then
		Mixin(btn, BackdropTemplateMixin)
		btn:OnBackdropLoaded()
	end
	btn:SetBackdrop(SolaFP_Backdrop_Info)
	btn:SetBackdropColor(1, 1, 1, 0.04)
	btn:SetBackdropBorderColor(0.57, 0.46, 0.30, 0.45)
	if btn.SetNormalTexture then btn:SetNormalTexture("") end
	if btn.SetPushedTexture then btn:SetPushedTexture("") end
	if btn.SetHighlightTexture then btn:SetHighlightTexture("") end

	local txt = btn:GetFontString()
	if not txt then
		txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		txt:SetPoint("CENTER", 0, 0)
		btn:SetFontString(txt)
	end
	txt:SetText("X")
	txt:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])

	if not btn.__fp_close_hooked then
		btn.__fp_close_hooked = true
		btn:HookScript("OnEnter", function(self)
			self:SetBackdropColor(SolaC.rose[1] * 0.5, SolaC.rose[2] * 0.5, SolaC.rose[3] * 0.5, 0.9)
			local t = self:GetFontString()
			if t then t:SetTextColor(1, 1, 1) end
		end)
		btn:HookScript("OnLeave", function(self)
			self:SetBackdropColor(1, 1, 1, 0.04)
			local t = self:GetFontString()
			if t then t:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3]) end
		end)
	end
end

_G.SolaFP_StyleModernButton = SolaFP_StyleModernButton
_G.SolaFP_StyleCloseButton = SolaFP_StyleCloseButton
_G.SolaFP_StyleModernEditBox = SolaFP_StyleModernEditBox
_G.SolaFP_SolaC = SolaC

function SolaFP_UpdateStatusPills()
	if SolaFP_TitleFrameActivation then
		local btn = SolaFP_TitleFrameActivation
		if BackdropTemplateMixin and not btn.SetBackdrop then
			Mixin(btn, BackdropTemplateMixin)
			btn:OnBackdropLoaded()
		end
		btn:SetBackdrop(SolaFP_Backdrop_Info)
		if SolaFP_Options and SolaFP_Options.activated then
			btn._r, btn._g, btn._b = 0.22, 0.42, 0.32
			btn:SetBackdropColor(0.22, 0.42, 0.32, 0.88)
			btn:SetBackdropBorderColor(0.57, 0.46, 0.30, 0.45)
			btn:SetText(SolaFP_BADGE_DETECT_ON or "감지 ON")
		else
			btn._r, btn._g, btn._b = 0.48, 0.22, 0.26
			btn:SetBackdropColor(0.48, 0.22, 0.26, 0.88)
			btn:SetBackdropBorderColor(0.57, 0.46, 0.30, 0.45)
			btn:SetText(SolaFP_BADGE_DETECT_OFF or "감지 OFF")
		end
	end

	if SolaFP_TitleFrameActivateBellnWindow then
		local btn = SolaFP_TitleFrameActivateBellnWindow
		btn:SetWidth(72)
		if BackdropTemplateMixin and not btn.SetBackdrop then
			Mixin(btn, BackdropTemplateMixin)
			btn:OnBackdropLoaded()
		end
		btn:SetBackdrop(SolaFP_Backdrop_Info)
		if SolaFP_Options and SolaFP_Options.activateBellnWindow then
			btn._r, btn._g, btn._b = 0.46, 0.36, 0.26
			btn:SetBackdropColor(0.46, 0.36, 0.26, 0.88)
			btn:SetBackdropBorderColor(0.57, 0.46, 0.30, 0.45)
			btn:SetText(SolaFP_BADGE_SOUND_ON or "팝업 ON")
		else
			btn._r, btn._g, btn._b = 0.16, 0.15, 0.14
			btn:SetBackdropColor(0.16, 0.15, 0.14, 0.85)
			btn:SetBackdropBorderColor(0.57, 0.46, 0.30, 0.45)
			btn:SetText(SolaFP_BADGE_SOUND_OFF or "팝업 OFF")
		end
	end

	if SolaFP_TitleFrameAnnouncing then
		local btn = SolaFP_TitleFrameAnnouncing
		btn:SetWidth(72)
		if BackdropTemplateMixin and not btn.SetBackdrop then
			Mixin(btn, BackdropTemplateMixin)
			btn:OnBackdropLoaded()
		end
		btn:SetBackdrop(SolaFP_Backdrop_Info)
		if isAnnouncing then
			btn._r, btn._g, btn._b = 0.22, 0.42, 0.32
			btn:SetBackdropColor(0.22, 0.42, 0.32, 0.88)
			btn:SetBackdropBorderColor(0.57, 0.46, 0.30, 0.45)
			btn:SetText(SolaFP_BADGE_AD_ON or "광고 ON")
		else
			btn._r, btn._g, btn._b = 0.16, 0.15, 0.14
			btn:SetBackdropColor(0.16, 0.15, 0.14, 0.85)
			btn:SetBackdropBorderColor(0.57, 0.46, 0.30, 0.45)
			btn:SetText(SolaFP_BADGE_AD_OFF or "광고 OFF")
		end
	end
end

-------------------------------------------------
-- Keybinding toggle dialog
-------------------------------------------------
local keyBindDialog = nil

function SolaFP_FormatBindingKey(key)
	if not key or key == "" then return nil end
	local s = key
	s = s:gsub("CTRL%-", "Ctrl+")
	s = s:gsub("ALT%-", "Alt+")
	s = s:gsub("SHIFT%-", "Shift+")
	s = s:gsub("BUTTON", "M")
	s = s:gsub("NUMPAD", "Num")
	return s
end

function SolaFP_OpenKeyBindDialog(anchorBtn)
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Cannot change key bindings while in combat."] or "전투 중에는 단축키를 변경할 수 없습니다."))
		return
	end

	if keyBindDialog and keyBindDialog:IsShown() then
		keyBindDialog:Hide()
		return
	end

	if not keyBindDialog then
		local d = CreateFrame("Frame", "SolaFP_KeyBindDialog", UIParent, "BackdropTemplate")
		d:SetSize(270, 130)
		d:SetFrameStrata("DIALOG")
		d:SetBackdrop(SolaFP_Backdrop_Info)
		d:SetBackdropColor(SolaC.bgSidebar[1], SolaC.bgSidebar[2], SolaC.bgSidebar[3], 0.98)
		d:SetBackdropBorderColor(SolaC.gold[1] * 0.85, SolaC.gold[2] * 0.85, SolaC.gold[3] * 0.85, 0.95)
		d:EnableMouse(true)
		d:EnableKeyboard(true)
		d:SetClampedToScreen(true)

		local accent = d:CreateTexture(nil, "ARTWORK", nil, 7)
		accent:SetPoint("TOPLEFT", 1, -1)
		accent:SetPoint("TOPRIGHT", -1, -1)
		accent:SetHeight(1)
		accent:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.8)

		local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOP", 0, -12)
		title:SetText("|cffD4A745" .. (SolaFP_L["SolaLFG Key Binding"] or "SolaLFG 열기 단축키 지정") .. "|r")

		local closeBtn = CreateFrame("Button", nil, d, "BackdropTemplate")
		closeBtn:SetSize(20, 20)
		closeBtn:SetPoint("TOPRIGHT", -6, -6)
		SolaFP_StyleCloseButton(closeBtn)
		closeBtn:SetScript("OnClick", function()
			d:Hide()
		end)

		local info = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		info:SetPoint("TOP", 0, -33)
		info:SetText(SolaFP_L["Press a key (or key combination) to bind."] or "지정할 키(또는 조합키)를 누르세요.")
		info:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])

		local box = CreateFrame("Frame", nil, d, "BackdropTemplate")
		box:SetSize(230, 32)
		box:SetPoint("TOP", 0, -52)
		box:SetBackdrop(SolaFP_Backdrop_Info)
		box:SetBackdropColor(0.06, 0.05, 0.05, 0.95)
		box:SetBackdropBorderColor(SolaC.teal[1] * 0.6, SolaC.teal[2] * 0.6, SolaC.teal[3] * 0.6, 0.85)

		local keyText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
		keyText:SetPoint("CENTER", 0, 0)
		keyText:SetText("|cff35BFB0[ " .. (SolaFP_L["Waiting for key press..."] or "키 입력 대기 중...") .. " ]|r")
		d.keyText = keyText
		d.box = box

		local footer = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		footer:SetPoint("BOTTOM", 0, 10)
		footer:SetText("|cff8A8580" .. (SolaFP_L["ESC: Cancel  ·  Right-Click button to unbind"] or "ESC: 취소  ·  단축키 해제는 버튼 우클릭") .. "|r")

		local function ProcessKey(rawKey)
			if InCombatLockdown() then
				DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Cannot change key bindings while in combat."] or "전투 중에는 단축키를 변경할 수 없습니다."))
				d:Hide()
				return
			end

			if rawKey == "ESCAPE" then
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
				d:Hide()
				return
			end

			if rawKey == "LALT" or rawKey == "RALT" or
			   rawKey == "LCTRL" or rawKey == "RCTRL" or
			   rawKey == "LSHIFT" or rawKey == "RSHIFT" then
				local prefix = ""
				if IsAltKeyDown() then prefix = prefix .. "Alt+" end
				if IsControlKeyDown() then prefix = prefix .. "Ctrl+" end
				if IsShiftKeyDown() then prefix = prefix .. "Shift+" end
				keyText:SetText(string.format("|cffE09050%s[%s]|r", prefix, SolaFP_L["Waiting for key"] or "키 입력 대기"))
				return
			end

			local prefix = ""
			if IsAltKeyDown() then prefix = prefix .. "ALT-" end
			if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
			if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
			local combo = prefix .. rawKey

			local oldAction = GetBindingAction(combo)
			local k1, k2 = GetBindingKey("SolaFP_TOGGLE")
			if k1 then SetBinding(k1, nil) end
			if k2 then SetBinding(k2, nil) end

			SetBinding(combo, "SolaFP_TOGGLE")
			SaveBindings(GetCurrentBindingSet())
			SolaFP_UpdateKeyBindingButton()

			local formatted = SolaFP_FormatBindingKey(combo)
			if oldAction and oldAction ~= "" and oldAction ~= "SolaFP_TOGGLE" then
				DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Key bound to [|cff66FF99%s|r]. (Replaced '%s')"] or "단축키가 [|cff66FF99%s|r](으)로 설정되었습니다. (기존 '%s' 기능 대체)"), formatted, oldAction))
			else
				DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Key bound to [|cff66FF99%s|r]."] or "단축키가 [|cff66FF99%s|r](으)로 설정되었습니다."), formatted))
			end

			PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK or 856)
			d:Hide()
		end

		d:SetScript("OnKeyDown", function(self, key)
			ProcessKey(key)
		end)

		d:SetScript("OnKeyUp", function(self, key)
			if not IsAltKeyDown() and not IsControlKeyDown() and not IsShiftKeyDown() then
				keyText:SetText("|cff35BFB0[ " .. (SolaFP_L["Waiting for key press..."] or "키 입력 대기 중...") .. " ]|r")
			else
				local prefix = ""
				if IsAltKeyDown() then prefix = prefix .. "Alt+" end
				if IsControlKeyDown() then prefix = prefix .. "Ctrl+" end
				if IsShiftKeyDown() then prefix = prefix .. "Shift+" end
				keyText:SetText(string.format("|cffE09050%s[%s]|r", prefix, SolaFP_L["Waiting for key"] or "키 입력 대기"))
			end
		end)

		d:RegisterEvent("PLAYER_REGEN_DISABLED")
		d:SetScript("OnEvent", function(self, event)
			if event == "PLAYER_REGEN_DISABLED" and self:IsShown() then
				self:Hide()
				DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Key binding cancelled because combat started."] or "전투가 시작되어 단축키 설정을 취소했습니다."))
			end
		end)

		keyBindDialog = d
	end

	local anchor = anchorBtn
	if not anchor or not anchor:IsShown() then
		if SolaFP_Options and SolaFP_Options.lfgOnly and SolaFP_LFG_KeyBindBtn and SolaFP_LFG_KeyBindBtn:IsShown() then
			anchor = SolaFP_LFG_KeyBindBtn
		elseif SolaFP_TitleFrameKeyBind and SolaFP_TitleFrameKeyBind:IsShown() then
			anchor = SolaFP_TitleFrameKeyBind
		end
	end

	local sc = tonumber(SolaFP_Options and SolaFP_Options.scale) or 1.0
	if keyBindDialog.SetScale then
		keyBindDialog:SetScale(sc)
	end

	if anchor and anchor:IsShown() then
		keyBindDialog:ClearAllPoints()
		keyBindDialog:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
	else
		keyBindDialog:ClearAllPoints()
		keyBindDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
	end

	keyBindDialog.keyText:SetText("|cff35BFB0[ " .. (SolaFP_L["Waiting for key press..."] or "키 입력 대기 중...") .. " ]|r")
	keyBindDialog:Show()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
end

function SolaFP_UpdateKeyBindingButton()
	local k1, k2 = GetBindingKey("SolaFP_TOGGLE")
	local activeKey = k1 or k2
	local hasKey = (activeKey and activeKey ~= "")
	local formatted = hasKey and SolaFP_FormatBindingKey(activeKey) or nil

	local function updateSingleBtn(btn, isTitleBar)
		if not btn then return end
		if hasKey then
			btn:SetText(string.format("|cffffffff%s|r", formatted))
			btn._hasKey = true
		else
			btn:SetText("|cffFFE29A" .. (SolaFP_L["Keybind"] or "단축키") .. "|r")
			btn._hasKey = false
		end
		local textW = btn.text and btn.text:GetStringWidth() or 34
		btn:SetWidth(math.max(50, math.floor(textW + 14)))
		if isTitleBar and SolaFP_TitleFrameActivation and SolaFP_TitleFrameActivation.ClearAllPoints then
			SolaFP_TitleFrameActivation:ClearAllPoints()
			SolaFP_TitleFrameActivation:SetPoint("LEFT", btn, "RIGHT", 8, 0)
		end
	end

	if SolaFP_TitleFrameKeyBind then
		updateSingleBtn(SolaFP_TitleFrameKeyBind, true)
	end
	if SolaFP_LFG_KeyBindBtn then
		updateSingleBtn(SolaFP_LFG_KeyBindBtn, false)
	end
end

function SolaFP_StyleAndHookKeyBindButton(btn)
	if not btn then return end

	if BackdropTemplateMixin and not btn.SetBackdrop then
		Mixin(btn, BackdropTemplateMixin)
		btn:OnBackdropLoaded()
	end
	btn:SetBackdrop(SolaFP_Backdrop_Info)

	local bgR, bgG, bgB = 0.26, 0.20, 0.11
	local bdR, bdG, bdB = 0.72, 0.58, 0.25
	btn._bgR, btn._bgG, btn._bgB = bgR, bgG, bgB
	btn._bdR, btn._bdG, btn._bdB = bdR, bdG, bdB
	btn:SetBackdropColor(bgR, bgG, bgB, 0.90)
	btn:SetBackdropBorderColor(bdR, bdG, bdB, 0.85)

	local fs = btn:GetFontString()
	if not fs then
		fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("CENTER", 0, 0)
		btn:SetFontString(fs)
	else
		fs:SetFontObject("GameFontHighlightSmall")
	end
	btn.text = fs

	btn:RegisterEvent("UPDATE_BINDINGS")
	btn:SetScript("OnEvent", function(self, event)
		if event == "UPDATE_BINDINGS" then
			SolaFP_UpdateKeyBindingButton()
		end
	end)

	btn:SetScript("OnShow", function(self)
		if SolaFP_UpdateKeyBindingButton then
			SolaFP_UpdateKeyBindingButton()
		end
	end)

	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:SetScript("OnEnter", function(self)
		self:SetBackdropColor(self._bgR * 1.45, self._bgG * 1.45, self._bgB * 1.45, 0.98)
		self:SetBackdropBorderColor(1.0, 0.88, 0.50, 1.0)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(SolaFP_L["SolaLFG Toggle Hotkey"] or "SolaLFG 열기 단축키", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		local k1, k2 = GetBindingKey("SolaFP_TOGGLE")
		if k1 or k2 then
			local keyStr = SolaFP_FormatBindingKey(k1 or k2)
			GameTooltip:AddLine(string.format(SolaFP_L["Current Key: |cff66FF99%s|r"] or "현재 단축키: |cff66FF99%s|r", keyStr), 0.94, 0.93, 0.91)
			GameTooltip:AddLine(SolaFP_L["Saved in WoW Key Bindings to instantly open and close the window."] or "와우 단축키 설정(Bindings)에 저장되어 창을 바로 열고 닫을 수 있습니다.", 0.7, 0.7, 0.7, true)
			GameTooltip:AddLine("|cff66FF99" .. (SolaFP_L["Left-Click"] or "좌클릭") .. "|r: " .. (SolaFP_L["Change Keybind"] or "단축키 변경"), SolaC.goldBeige[1], SolaC.goldBeige[2], SolaC.goldBeige[3])
			GameTooltip:AddLine("|cffFF6666" .. (SolaFP_L["Right-Click"] or "우클릭") .. "|r: " .. (SolaFP_L["Unbind"] or "단축키 해제"), SolaC.rose[1], SolaC.rose[2], SolaC.rose[3])
		else
			GameTooltip:AddLine(SolaFP_L["No hotkey currently bound."] or "현재 설정된 단축키가 없습니다.", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
			GameTooltip:AddLine(SolaFP_L["Click to set a hotkey to quickly open/close SolaLFG."] or "클릭하여 SolaLFG 창을 바로 여는 단축키를 지정할 수 있습니다.", 0.7, 0.7, 0.7, true)
			GameTooltip:AddLine("|cff66FF99" .. (SolaFP_L["Left-Click"] or "좌클릭") .. "|r: " .. (SolaFP_L["Set Keybind"] or "단축키 지정"), SolaC.goldBeige[1], SolaC.goldBeige[2], SolaC.goldBeige[3])
		end
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function(self)
		self:SetBackdropColor(self._bgR, self._bgB, self._bgB, 0.90)
		self:SetBackdropBorderColor(self._bdR, self._bdG, self._bdB, 0.85)
		GameTooltip:Hide()
	end)

	btn:SetScript("OnClick", function(self, button)
		if InCombatLockdown() then
			DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Cannot change key bindings while in combat."] or "전투 중에는 단축키를 변경할 수 없습니다."))
			return
		end
		if button == "RightButton" then
			local k1, k2 = GetBindingKey("SolaFP_TOGGLE")
			if k1 or k2 then
				if k1 then SetBinding(k1, nil) end
				if k2 then SetBinding(k2, nil) end
				SaveBindings(GetCurrentBindingSet())
				SolaFP_UpdateKeyBindingButton()
				DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Hotkey has been unbound."] or "열기 단축키가 해제되었습니다."))
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
			end
		else
			SolaFP_OpenKeyBindDialog(self)
		end
	end)
end

function SolaFP_CreateKeyBindingButton()
	if SolaFP_TitleFrameKeyBind or not SolaFP_TitleFrame or not SolaFP_TitleFrameText then return end

	local btn = CreateFrame("Button", "SolaFP_TitleFrameKeyBind", SolaFP_TitleFrame, "BackdropTemplate")
	btn:SetSize(50, 22)
	btn:SetPoint("LEFT", SolaFP_TitleFrameText, "RIGHT", 10, 0)
	if SolaFP_TitleFrameActivation and SolaFP_TitleFrameActivation.ClearAllPoints then
		SolaFP_TitleFrameActivation:ClearAllPoints()
		SolaFP_TitleFrameActivation:SetPoint("LEFT", btn, "RIGHT", 8, 0)
	end

	SolaFP_StyleAndHookKeyBindButton(btn)
	SolaFP_UpdateKeyBindingButton()
end

function SolaFP_CreateScaleSlider()
	if SolaFP_ScaleSlider or not SolaFP_TitleFrame or not SolaFP_MenuFrameInfo then return end

	local slider = CreateFrame("Slider", "SolaFP_ScaleSlider", SolaFP_TitleFrame)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(80, 8)
	slider:SetPoint("RIGHT", SolaFP_MenuFrameInfo, "LEFT", -12, 0)
	slider:SetMinMaxValues(0.5, 2.0)
	slider:SetValueStep(0.05)
	if slider.SetObeyStepOnDrag then
		slider:SetObeyStepOnDrag(true)
	end

	-- Slider track background (Sola dark input)
	local sBg = slider:CreateTexture(nil, "BACKGROUND")
	sBg:SetAllPoints()
	sBg:SetColorTexture(SolaC.bgInput[1], SolaC.bgInput[2], SolaC.bgInput[3], 0.8)

	-- Slider fill (toned-down gold, left side)
	local sFill = slider:CreateTexture(nil, "ARTWORK")
	sFill:SetPoint("LEFT", slider, "LEFT", 0, 0)
	sFill:SetHeight(8)
	sFill:SetColorTexture(SolaC.goldMuted[1], SolaC.goldMuted[2], SolaC.goldMuted[3], 0.45)
	slider.__fp_fill = sFill

	-- Thumb texture (Sola gold)
	local sThumb = slider:CreateTexture(nil, "ARTWORK", nil, 1)
	sThumb:SetSize(8, 14)
	sThumb:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 1)
	slider:SetThumbTexture(sThumb)

	-- UI scale label (placed to the left of the slider)
	local sLabel = SolaFP_TitleFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sLabel:SetPoint("RIGHT", slider, "LEFT", -6, 0)
	sLabel:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
	slider.__fp_label = sLabel

	local function UpdateScaleLabel(val)
		local pct = math.floor(val * 100 + 0.5)
		sLabel:SetText(string.format("UI |cffD4A745%d%%|r", pct))
	end

	local function UpdateScaleFill(val)
		local ratio = (val - 0.5) / 1.5
		if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
		local w = slider:GetWidth()
		if w and w > 0 then
			sFill:SetWidth(math.max(1, w * ratio))
		end
	end

	slider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(SolaFP_L["Window Scale (UI Scale)"] or "창 크기 조절 (UI Scale)", 1, 0.82, 0)
		GameTooltip:AddLine(SolaFP_L["Drag the slider to adjust SolaLFG scale (50% ~ 200%)."] or "슬라이더를 드래그하여 SolaLFG 창 크기를 조절합니다. (50% ~ 200%)", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function() GameTooltip:Hide() end)

	slider:SetScript("OnMouseUp", function(self)
		local val = self:GetValue()
		val = math.floor(val * 20 + 0.5) / 20
		SolaFP_Options.scale = val
		SolaFP_UIResize(val)
	end)

	slider:SetScript("OnValueChanged", function(self, val)
		val = math.floor(val * 20 + 0.5) / 20
		SolaFP_Options.scale = val
		UpdateScaleLabel(val)
		UpdateScaleFill(val)
		if not IsMouseButtonDown("LeftButton") then
			SolaFP_UIResize(val)
		end
	end)

	slider:SetScript("OnSizeChanged", function(self)
		UpdateScaleFill(self:GetValue())
	end)

	local curScale = tonumber(SolaFP_Options and SolaFP_Options.scale) or 1.0
	slider:SetValue(curScale)
	UpdateScaleLabel(curScale)
	UpdateScaleFill(curScale)

	SolaFP_TitleFrame:HookScript("OnShow", function()
		local sc = tonumber(SolaFP_Options and SolaFP_Options.scale) or 1.0
		slider:SetValue(sc)
		UpdateScaleLabel(sc)
		UpdateScaleFill(sc)
		SolaFP_UpdateWidthResponsiveUI()
	end)
	SolaFP_UpdateWidthResponsiveUI()
end

-------------------------------------------------
-- Mouse Wheel Scrolling Support
-------------------------------------------------
local function SolaFP_OnListMouseWheel(self, delta)
	local scrollFrame = SolaFP_ListFrameScrollFrame
	if not scrollFrame then return end
	local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
	if not scrollBar or not scrollBar:IsShown() then return end

	local current = scrollBar:GetValue() or 0
	local minVal, maxVal = scrollBar:GetMinMaxValues()
	if not minVal or not maxVal or minVal >= maxVal then return end

	-- Mouse wheel list navigation: 2 rows normal, 5 rows with Shift
	local step = IsShiftKeyDown() and 120 or 48
	local target = (delta > 0) and math.max(minVal, current - step) or math.min(maxVal, current + step)

	if target ~= current then
		scrollBar:SetValue(target)
		local newOffset = math.floor(target / 24 + 0.5)
		if scrollFrame.offset ~= newOffset then
			scrollFrame.offset = newOffset
			SolaFP_Refresh(true)
		end
	end
end

local function SolaFP_SetupMouseWheel()
	if SolaFP_ListFrameScrollFrame then
		SolaFP_ListFrameScrollFrame:EnableMouseWheel(true)
		SolaFP_ListFrameScrollFrame:SetScript("OnMouseWheel", SolaFP_OnListMouseWheel)
	end
	if SolaFP_ListFrame then
		SolaFP_ListFrame:EnableMouseWheel(true)
		SolaFP_ListFrame:SetScript("OnMouseWheel", SolaFP_OnListMouseWheel)
	end
	for i = 1, 28 do
		local row = _G["SolaFP_ListFrameRow" .. i]
		if row then
			row:EnableMouseWheel(true)
			row:SetScript("OnMouseWheel", SolaFP_OnListMouseWheel)
			local parts = { "Time", "Dungeon", "Name", "Msg" }
			for j = 1, #parts do
				local child = _G["SolaFP_ListFrameRow" .. i .. parts[j]]
				if child and child.EnableMouseWheel then
					child:EnableMouseWheel(true)
					child:SetScript("OnMouseWheel", SolaFP_OnListMouseWheel)
				end
			end
		end
	end
end

-------------------------------------------------
-- Window Resize (Width & Height) Support
-------------------------------------------------
local SolaFP_ResizeWatcher = CreateFrame("Frame", "SolaFP_ResizeWatcher", UIParent)
SolaFP_ResizeWatcher:Hide()

local resizeActive = false
local resizeMode = "corner"
local resizeStartX = 0
local resizeStartY = 0
local resizeStartWidth = 750
local resizeStartLines = 20

local function SolaFP_StartResize(mode)
	if resizeActive then return end
	if not SolaFP_ListFrame then return end

	local top = SolaFP_ListFrame:GetTop()
	local left = SolaFP_ListFrame:GetLeft()
	if not top or not left then return end

	resizeActive = true
	resizeMode = mode or "corner"

	local cursorX, cursorY = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	resizeStartX = cursorX / scale
	resizeStartY = cursorY / scale

	local curW = SolaFP_Position_Save.width or SolaFP_ListFrame:GetWidth() or 750
	resizeStartWidth = math.max(SolaFP_MIN_WIDTH, math.min(SolaFP_MAX_WIDTH, curW))
	resizeStartLines = SolaFP_Options.viewLines or 20

	-- Anchor top-left during resize to prevent shifting
	SolaFP_ListFrame:ClearAllPoints()
	SolaFP_ListFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)

	SolaFP_ResizeWatcher:Show()
end

local function SolaFP_StopResize()
	if not resizeActive then return end
	resizeActive = false
	SolaFP_ResizeWatcher:Hide()

	SolaFP_ListMove()
	if SolaFP_Position_Save then
		SolaFP_Position_Save.width = SolaFP_ListFrame:GetWidth()
		SolaFP_Position_Save.viewLines = SolaFP_Options.viewLines
	end
	SolaFP_UpdateWidthResponsiveUI(SolaFP_Position_Save and SolaFP_Position_Save.width)
	SolaFP_Refresh()
end

SolaFP_ResizeWatcher:SetScript("OnUpdate", function(self)
	if not resizeActive then
		self:Hide()
		return
	end
	if not IsMouseButtonDown("LeftButton") then
		SolaFP_StopResize()
		return
	end

	local cursorX, cursorY = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	local currentX = cursorX / scale
	local currentY = cursorY / scale

	local changed = false

	-- Width resizing
	if resizeMode == "corner" then
		local deltaX = currentX - resizeStartX
		local newWidth = math.floor(resizeStartWidth + deltaX + 0.5)
		newWidth = math.max(SolaFP_MIN_WIDTH, math.min(SolaFP_MAX_WIDTH, newWidth))

		local curWidth = SolaFP_ListFrame:GetWidth()
		if curWidth ~= newWidth then
			SolaFP_TitleFrame:SetWidth(newWidth)
			SolaFP_ListFrame:SetWidth(newWidth)
			SolaFP_MenuFrame:SetWidth(newWidth)
			SolaFP_Position_Save.width = newWidth
			SolaFP_UpdateWidthResponsiveUI(newWidth)
			changed = true
		end
	end

	-- Height and line count resizing
	local deltaY = resizeStartY - currentY
	local deltaLines = math.floor((deltaY / 24) + 0.5)
	local lines = math.max(4, math.min(26, resizeStartLines + deltaLines))

	if lines ~= SolaFP_Options.viewLines then
		SolaFP_Options.viewLines = lines
		SolaFP_ListFrame:SetHeight(84 + (lines * 24))
		changed = true
	end

	if changed then
		SolaFP_Refresh()
		if SolaFP_LFGPanel and SolaFP_LFGPanel:IsShown() and SolaFP_LFGPanel.Layout then
			SolaFP_LFGPanel:Layout()
		end
	end
end)

local function SolaFP_SetupResizeHandles()
	-- Menu frame drag move and resize handle
	if SolaFP_MenuFrame and not SolaFP_MenuFrame.__fp_resize_setup then
		SolaFP_MenuFrame.__fp_resize_setup = true

		-- Drag to move or right click to close
		SolaFP_MenuFrame:EnableMouse(true)
		SolaFP_MenuFrame:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				SolaFP_ListFrame:StartMoving()
			elseif button == "RightButton" then
				SolaFP_CloseOnRightClick()
			end
		end)
		SolaFP_MenuFrame:SetScript("OnMouseUp", function(self, button)
			if button == "LeftButton" then
				SolaFP_ListFrame:StopMovingOrSizing()
				SolaFP_ListMove()
			end
		end)

		-- Corner grip: 2D resize
		local cornerGrip = CreateFrame("Button", "SolaFP_MenuCornerResizeGrip", SolaFP_MenuFrame)
		cornerGrip:SetSize(22, 22)
		cornerGrip:SetPoint("BOTTOMRIGHT", SolaFP_MenuFrame, "BOTTOMRIGHT", -2, 2)
		cornerGrip:EnableMouse(true)
		cornerGrip:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
		cornerGrip:SetFrameLevel(SolaFP_MenuFrame:GetFrameLevel() + 11)

		local gripLines = {}
		for i = 1, 3 do
			local line = cornerGrip:CreateTexture(nil, "OVERLAY")
			line:SetHeight(1)
			line:SetWidth(4 + i * 3)
			line:SetPoint("BOTTOMRIGHT", -2, 2 + (i - 1) * 4)
			line:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.5)
			gripLines[i] = line
		end

		cornerGrip:SetScript("OnEnter", function(self)
			for i = 1, #gripLines do
				gripLines[i]:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 1.0)
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(SolaFP_TEXT_RESIZE_TIP or "드래그: 창 크기 조절 (너비/높이) | 마우스 휠: 스크롤 이동")
			GameTooltip:Show()
		end)
		cornerGrip:SetScript("OnLeave", function(self)
			for i = 1, #gripLines do
				gripLines[i]:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.5)
			end
			GameTooltip:Hide()
		end)
		cornerGrip:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				SolaFP_StartResize("corner")
			elseif button == "RightButton" then
				SolaFP_CloseOnRightClick()
			end
		end)
		cornerGrip:SetScript("OnMouseUp", function(self, button)
			if button == "LeftButton" then SolaFP_StopResize() end
		end)
	end

	-- Bottom edge resize
	if SolaFP_ListFrame and not SolaFP_ListFrame.__fp_resize_setup then
		SolaFP_ListFrame.__fp_resize_setup = true

		local listBottomBar = CreateFrame("Button", "SolaFP_ListBottomResizeBar", SolaFP_ListFrame)
		listBottomBar:SetHeight(10)
		listBottomBar:SetPoint("BOTTOMLEFT", SolaFP_ListFrame, "BOTTOMLEFT", 0, 0)
		listBottomBar:SetPoint("BOTTOMRIGHT", SolaFP_ListFrame, "BOTTOMRIGHT", 0, 0)
		listBottomBar:EnableMouse(true)
		listBottomBar:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
		listBottomBar:SetFrameLevel(SolaFP_ListFrame:GetFrameLevel() + 10)

		listBottomBar:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				SolaFP_StartResize("bottom")
			elseif button == "RightButton" then
				SolaFP_CloseOnRightClick()
			end
		end)
		listBottomBar:SetScript("OnMouseUp", function(self, button)
			if button == "LeftButton" then SolaFP_StopResize() end
		end)
	end

	-- Enable dragging on SolaFP_ListFrame empty space
	if SolaFP_ListFrame and not SolaFP_ListFrame.__fp_drag_setup then
		SolaFP_ListFrame.__fp_drag_setup = true
		SolaFP_ListFrame:EnableMouse(true)
		SolaFP_ListFrame:SetMovable(true)
		SolaFP_ListFrame:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				SolaFP_ListFrame:StartMoving()
			elseif button == "RightButton" then
				SolaFP_CloseOnRightClick()
			end
		end)
		SolaFP_ListFrame:SetScript("OnMouseUp", function(self, button)
			SolaFP_ListFrame:StopMovingOrSizing()
			SolaFP_ListMove()
		end)
	end

	-- Enable dragging on SolaFP_ListFrameScrollFrame empty space (empty list / rows)
	if SolaFP_ListFrameScrollFrame and not SolaFP_ListFrameScrollFrame.__fp_drag_setup then
		SolaFP_ListFrameScrollFrame.__fp_drag_setup = true
		SolaFP_ListFrameScrollFrame:EnableMouse(true)
		SolaFP_ListFrameScrollFrame:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				SolaFP_ListFrame:StartMoving()
			elseif button == "RightButton" then
				SolaFP_CloseOnRightClick()
			end
		end)
		SolaFP_ListFrameScrollFrame:SetScript("OnMouseUp", function(self, button)
			SolaFP_ListFrame:StopMovingOrSizing()
			SolaFP_ListMove()
		end)
	end
end

function SolaFP_ApplyModernTheme()
	SolaFP_HookDropDownLists()
	SolaFP_SetListColor()

	if SolaFP_TitleFrame and not SolaFP_TitleFrame.__fp_gold_accent then
		local accent = SolaFP_TitleFrame:CreateTexture(nil, "ARTWORK", nil, 7)
		accent:SetPoint("TOPLEFT", 1, -1)
		accent:SetPoint("TOPRIGHT", -1, -1)
		accent:SetHeight(1)
		accent:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.75)
		SolaFP_TitleFrame.__fp_gold_accent = accent

		local shine = SolaFP_TitleFrame:CreateTexture(nil, "BORDER")
		shine:SetPoint("TOPLEFT", 1, -2)
		shine:SetPoint("TOPRIGHT", -1, -2)
		shine:SetHeight(28)
		shine:SetColorTexture(1, 1, 1, 0.025)
		SolaFP_TitleFrame.__fp_shine = shine

		local titleSep = SolaFP_TitleFrame:CreateTexture(nil, "ARTWORK", nil, 6)
		titleSep:SetPoint("BOTTOMLEFT", 1, 0)
		titleSep:SetPoint("BOTTOMRIGHT", -1, 0)
		titleSep:SetHeight(1)
		titleSep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.06)
		SolaFP_TitleFrame.__fp_title_sep = titleSep
	end

	if SolaFP_TitleFrameText then
		SolaFP_TitleFrameText:SetText("|cffD4A745SolaLFG|r")
		SolaFP_TitleFrameText:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		SolaFP_TitleFrameText:SetShadowOffset(1, -1)
		SolaFP_TitleFrameText:SetShadowColor(0, 0, 0, 1)
	end

	SolaFP_StyleCloseButton(SolaFP_TitleFrameCloseButton)
	SolaFP_StyleModernButton(SolaFP_TitleFrameIncreaseButton, "dark", "+")
	SolaFP_StyleModernButton(SolaFP_TitleFrameDecreaseButton, "dark", "-")
	SolaFP_StyleModernButton(SolaFP_TitleFrameMaxButton, "dark", "20")
	SolaFP_StyleModernButton(SolaFP_TitleFrameMinButton, "dark", "1")
	SolaFP_StyleModernButton(SolaFP_MenuFrameInfo, "amber", SolaFP_TEXT_HELP or "Help")
	SolaFP_StyleModernButton(SolaFP_TitleFrameOption, "default", SolaFP_OPTION or "Option")

	SolaFP_CreateScaleSlider()
	SolaFP_CreateKeyBindingButton()
	SolaFP_UpdateKeyBindingButton()
	if SolaFP_LFG_Init then SolaFP_LFG_Init() end

	SolaFP_UpdateStatusPills()

	if SolaFP_ListFrame then
		if not SolaFP_ListFrame.__fp_tool_sep then
			local toolSep = SolaFP_ListFrame:CreateTexture(nil, "ARTWORK", nil, 6)
			toolSep:SetHeight(1)
			toolSep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.06)
			SolaFP_ListFrame.__fp_tool_sep = toolSep
		end
		SolaFP_ListFrame.__fp_tool_sep:ClearAllPoints()
		SolaFP_ListFrame.__fp_tool_sep:SetPoint("TOPLEFT", 1, -39)
		SolaFP_ListFrame.__fp_tool_sep:SetPoint("TOPRIGHT", -1, -39)

		if not SolaFP_ListFrame.__fp_header_sep then
			local headerSep = SolaFP_ListFrame:CreateTexture(nil, "ARTWORK", nil, 6)
			headerSep:SetHeight(1)
			headerSep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.06)
			SolaFP_ListFrame.__fp_header_sep = headerSep
		end
		SolaFP_ListFrame.__fp_header_sep:ClearAllPoints()
		SolaFP_ListFrame.__fp_header_sep:SetPoint("TOPLEFT", 1, -79)
		SolaFP_ListFrame.__fp_header_sep:SetPoint("TOPRIGHT", -1, -79)
	end

	if SolaFP_ListFrameFilterDungeon then
		local btn = SolaFP_ListFrameFilterDungeon
		btn:RegisterForClicks("LeftButtonDown", "RightButtonDown", "MiddleButtonDown")
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", 12, -7)
		btn:SetSize(146, 26)
		if BackdropTemplateMixin and not btn.SetBackdrop then
			Mixin(btn, BackdropTemplateMixin)
			btn:OnBackdropLoaded()
		end
		btn:SetBackdrop(SolaFP_Backdrop_Info)
		btn:SetBackdropColor(0.14, 0.12, 0.10, 0.95)
		btn:SetBackdropBorderColor(SolaC.gold[1] * 0.75, SolaC.gold[2] * 0.75, SolaC.gold[3] * 0.75, 0.75)
		if SolaFP_ListFrameFilterDungeonText then
			SolaFP_ListFrameFilterDungeonText:ClearAllPoints()
			SolaFP_ListFrameFilterDungeonText:SetPoint("LEFT", btn, "LEFT", 8, 0)
			SolaFP_ListFrameFilterDungeonText:SetPoint("RIGHT", btn, "RIGHT", -26, 0)
			SolaFP_ListFrameFilterDungeonText:SetFontObject("GameFontHighlightSmall")
			SolaFP_ListFrameFilterDungeonText:SetTextColor(SolaC.fgMain[1], SolaC.fgMain[2], SolaC.fgMain[3])
			SolaFP_ListFrameFilterDungeonText:SetShadowOffset(1, -1)
			SolaFP_ListFrameFilterDungeonText:SetShadowColor(0, 0, 0, 0.9)
		end
		if SolaFP_ListFrameFilterDungeonArrow then
			SolaFP_ListFrameFilterDungeonArrow:SetText("")
			SolaFP_ListFrameFilterDungeonArrow:Hide()
		end
		if not btn.__fp_v_btn then
			local vBtn = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate" or nil)
			vBtn:SetSize(22, 22)
			vBtn:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
			if BackdropTemplateMixin and not vBtn.SetBackdrop then
				Mixin(vBtn, BackdropTemplateMixin)
				vBtn:OnBackdropLoaded()
			end
			vBtn:SetBackdrop(SolaFP_Backdrop_Info)
			local gr, gg, gb = SolaC.gold[1] * 0.48, SolaC.gold[2] * 0.48, SolaC.gold[3] * 0.48
			vBtn:SetBackdropColor(gr, gg, gb, 0.95)
			vBtn:SetBackdropBorderColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.8)
			local vTxt = vBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			vTxt:SetPoint("CENTER", 0, 0)
			vTxt:SetText("v")
			vTxt:SetTextColor(1, 1, 1)
			vTxt:SetShadowOffset(1, -1)
			vTxt:SetShadowColor(0, 0, 0, 0.8)
			vBtn.__fp_txt = vTxt
			btn.__fp_v_btn = vBtn
			btn:HookScript("OnEnter", function(self)
				self:SetBackdropColor(0.20, 0.17, 0.13, 0.98)
				self:SetBackdropBorderColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 1.0)
				vBtn:SetBackdropColor(math.min(1, gr * 1.5), math.min(1, gg * 1.5), math.min(1, gb * 1.5), 1.0)
			end)
			btn:HookScript("OnLeave", function(self)
				self:SetBackdropColor(0.14, 0.12, 0.10, 0.95)
				self:SetBackdropBorderColor(SolaC.gold[1] * 0.75, SolaC.gold[2] * 0.75, SolaC.gold[3] * 0.75, 0.75)
				vBtn:SetBackdropColor(gr, gg, gb, 0.95)
			end)
		end
	end

	if SolaFP_MenuFrameFilter and SolaFP_ListFrameFilterDungeon then
		SolaFP_MenuFrameFilter:ClearAllPoints()
		SolaFP_MenuFrameFilter:SetPoint("LEFT", SolaFP_ListFrameFilterDungeon, "RIGHT", 14, 0)
		SolaFP_MenuFrameFilter:SetText(SolaFP_LABEL_FILTER or "Filter:")
		SolaFP_MenuFrameFilter:SetTextColor(SolaC.teal[1], SolaC.teal[2], SolaC.teal[3])
	end
	SolaFP_StyleModernEditBox(SolaFP_MenuFrameFilterText, "teal")
	SolaFP_StyleModernButton(SolaFP_MenuFrameFilterApply, "mint", SolaFP_TEXT_APPLY_FILTER or "적용")

	if SolaFP_MenuFrameIgnore and SolaFP_MenuFrameFilterApply then
		SolaFP_MenuFrameIgnore:ClearAllPoints()
		SolaFP_MenuFrameIgnore:SetPoint("LEFT", SolaFP_MenuFrameFilterApply, "RIGHT", 8, 0)
		SolaFP_MenuFrameIgnore:SetText(SolaFP_LABEL_IGNORE or "Ignore:")
		SolaFP_MenuFrameIgnore:SetTextColor(SolaC.rose[1], SolaC.rose[2], SolaC.rose[3])
	end
	SolaFP_StyleModernEditBox(SolaFP_MenuFrameIgnoreText, "rose")
	SolaFP_StyleModernButton(SolaFP_MenuFrameIgnoreButton, "rose", SolaFP_TEXT_IGNORE or "Ignore")
	SolaFP_StyleModernButton(SolaFP_MenuFrameExceptionDelete, "amber", SolaFP_BTN_RESET or "Reset")

	if SolaFP_ListFrameDungeonHeader then
		SolaFP_ListFrameDungeonHeader:ClearAllPoints()
		SolaFP_ListFrameDungeonHeader:SetPoint("TOPLEFT", 64, -61)
		SolaFP_ListFrameDungeonHeader:SetText(SolaFP_TEXT_DUNGEON_LABEL or "Dungeon")
		SolaFP_ListFrameDungeonHeader:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
	end
	if SolaFP_ListFrameDungeonSort then
		SolaFP_ListFrameDungeonSort:SetWidth(115)
	end
	if SolaFP_ListFrameNameHeader then
		SolaFP_ListFrameNameHeader:ClearAllPoints()
		SolaFP_ListFrameNameHeader:SetPoint("TOPLEFT", 187, -61)
		SolaFP_ListFrameNameHeader:SetText(SolaFP_TEXT_SHOUTER_LABEL or "Leader")
		SolaFP_ListFrameNameHeader:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
	end
	if SolaFP_ListFrameMsgHeader then
		SolaFP_ListFrameMsgHeader:ClearAllPoints()
		SolaFP_ListFrameMsgHeader:SetPoint("TOPLEFT", 275, -61)
		SolaFP_ListFrameMsgHeader:SetText(SolaFP_TEXT_MSG_LABEL or "Message")
		SolaFP_ListFrameMsgHeader:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
	end
	for r = 1, 30 do
		local dFrame = _G["SolaFP_ListFrameRow"..r.."Dungeon"]
		if dFrame and dFrame.SetWidth then dFrame:SetWidth(115) end
		local nFrame = _G["SolaFP_ListFrameRow"..r.."Name"]
		if nFrame and nFrame.SetWidth then nFrame:SetWidth(80) end
	end
	if SolaFP_ListFrameTimeSort then
		SolaFP_ListFrameTimeSort:ClearAllPoints()
		SolaFP_ListFrameTimeSort:SetPoint("TOPLEFT", 12, -61)
		-- Remove button styling, apply plain gold text like DungeonHeader
		if SolaFP_ListFrameTimeSort.SetBackdrop then
			SolaFP_ListFrameTimeSort:SetBackdrop(nil)
		end
		if SolaFP_ListFrameTimeSort.SetNormalTexture then SolaFP_ListFrameTimeSort:SetNormalTexture("") end
		if SolaFP_ListFrameTimeSort.SetPushedTexture then SolaFP_ListFrameTimeSort:SetPushedTexture("") end
		if SolaFP_ListFrameTimeSort.SetHighlightTexture then SolaFP_ListFrameTimeSort:SetHighlightTexture("") end
		local tsRegions = {SolaFP_ListFrameTimeSort:GetRegions()}
		for i = 1, #tsRegions do
			local r = tsRegions[i]
			if r:IsObjectType("Texture") then
				r:SetAlpha(0)
			end
		end
		local tsFs = SolaFP_ListFrameTimeSort:GetFontString()
		if not tsFs then
			tsFs = SolaFP_ListFrameTimeSort:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			SolaFP_ListFrameTimeSort:SetFontString(tsFs)
		end
		tsFs:ClearAllPoints()
		tsFs:SetPoint("TOPLEFT", 0, 0)
		tsFs:SetJustifyH("LEFT")
		tsFs:SetText(SolaFP_TEXT_TIME_LABEL or "Time")
		tsFs:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		tsFs:SetShadowOffset(1, -1)
		tsFs:SetShadowColor(0, 0, 0, 0.8)
	end

	if SolaFP_ListFrameRow1 then
		SolaFP_ListFrameRow1:ClearAllPoints()
		SolaFP_ListFrameRow1:SetPoint("TOPLEFT", 12, -82)
		SolaFP_ListFrameRow1:SetPoint("RIGHT", -30, 0)
	end
	if SolaFP_ListFrameScrollFrame then
		SolaFP_ListFrameScrollFrame:ClearAllPoints()
		SolaFP_ListFrameScrollFrame:SetPoint("TOPLEFT", 0, -82)
		SolaFP_ListFrameScrollFrame:SetPoint("BOTTOMRIGHT", -30, 8)
	end

	if SolaFP_MenuFrame and not SolaFP_MenuFrame.__fp_footer_sep then
		local footerSep = SolaFP_MenuFrame:CreateTexture(nil, "ARTWORK", nil, 6)
		footerSep:SetPoint("TOPLEFT", 1, 0)
		footerSep:SetPoint("TOPRIGHT", -1, 0)
		footerSep:SetHeight(1)
		footerSep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.06)
		SolaFP_MenuFrame.__fp_footer_sep = footerSep
	end

	if SolaFP_MenuFrameWh then
		SolaFP_MenuFrameWh:SetText(SolaFP_LABEL_WH or "Whisper:")
		SolaFP_MenuFrameWh:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
	end
	SolaFP_StyleModernEditBox(SolaFP_MenuFrameWhText, "gold")
	SolaFP_StyleModernButton(SolaFP_MenuFrameWhPresetBtn, "gold", "v")
	SolaFP_StyleModernButton(SolaFP_MenuFrameWhAddBtn, "default", SolaFP_TEXT_ADD or "추가")
	SolaFP_StyleModernButton(SolaFP_MenuFrameApply, "teal", SolaFP_TEXT_APPLY or "Apply")
	SolaFP_StyleModernButton(SolaFP_MenuFrameWhisper, "default", SolaFP_BTN_WHISPER or "Whisper")
	SolaFP_StyleModernButton(SolaFP_MenuFrameWho, "default", SolaFP_BTN_WHO or "Who")
	SolaFP_StyleModernButton(SolaFP_MenuFrameException, "rose", SolaFP_TEXT_EXCEPTION or "Exclude")

	if SolaFP_ListFrameResizeGrip and not SolaFP_ListFrameResizeGrip.__fp_txt then
		local gripTxt = SolaFP_ListFrameResizeGrip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		gripTxt:SetPoint("BOTTOMRIGHT", -2, 2)
		gripTxt:SetText("")
		gripTxt:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		SolaFP_ListFrameResizeGrip.__fp_txt = gripTxt
	end

	local sb = _G["SolaFP_ListFrameScrollFrameScrollBar"]
	if sb then
		sb:SetWidth(6)
		local regions = {sb:GetRegions()}
		for i = 1, #regions do
			local r = regions[i]
			if r:IsObjectType("Texture") then
				r:SetAlpha(0)
			end
		end
		local thumb = sb:GetThumbTexture()
		if thumb then
			thumb:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.6)
			thumb:SetSize(6, 24)
		end
		local upBtn = _G["SolaFP_ListFrameScrollFrameScrollBarScrollUpButton"]
		if upBtn then upBtn:Hide(); upBtn:SetAlpha(0) end
		local downBtn = _G["SolaFP_ListFrameScrollFrameScrollBarScrollDownButton"]
		if downBtn then downBtn:Hide(); downBtn:SetAlpha(0) end
	end

	for i = 1, 28 do
		local row = _G["SolaFP_ListFrameRow"..i]
		if row then
			local ht = row:GetHighlightTexture()
			if ht then
				ht:SetColorTexture(SolaC.bgHover[1], SolaC.bgHover[2], SolaC.bgHover[3], 0.75)
			end
			local timeText = _G["SolaFP_ListFrameRow"..i.."TimeText"]
			if timeText then
				timeText:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
				timeText:SetJustifyH("LEFT")
			end
			local msgText = _G["SolaFP_ListFrameRow"..i.."MsgText"]
			if msgText then
				msgText:SetTextColor(SolaC.fgMain[1], SolaC.fgMain[2], SolaC.fgMain[3])
			end
		end
	end

	SolaFP_SetupMouseWheel()
	SolaFP_SetupResizeHandles()

	local curW = (SolaFP_Position_Save and SolaFP_Position_Save.width) or (SolaFP_ListFrame and SolaFP_ListFrame:GetWidth()) or 750
	SolaFP_UpdateWidthResponsiveUI(curW)

	if MessageQueue then
		SolaFP_EnableAnnounce()
	else
		SolaFP_DisableAnnounce(true)
	end
end

function SolaFP_Init()
	if not (SolaFP_Version == SolaFP_Revision) then
		if type(SolaFP_Version) ~= "number" then
			SolaFP_Print(SolaFP_MESSAGE_NEWVERSION_RESET)
			if SolaFP_DUNGEON_LIST then
				SolaFP_DUNGEON_LIST = nil
			end
			SolaFP_LoadDefaultOption()
		else
			if SolaFP_Version < 10 then
				SolaFP_Print(SolaFP_MESSAGE_NEWVERSION_RESET)
				if SolaFP_DUNGEON_LIST then
					SolaFP_DUNGEON_LIST = nil
				end
				SolaFP_LoadDefaultOption()
			else
				if SolaFP_Version < 20 then
					if SolaFP_Options and SolaFP_Options.channel then
						SolaFP_Options.channel["거래"] = true
						SolaFP_Options.channel["공개"] = true
						SolaFP_Options.channel["Trade"] = true
						SolaFP_Options.channel["General"] = true
					end
				end
				if SolaFP_Version < 19 then
					if SolaFP_Options then
						SolaFP_Options.lfgFilterDrawerOpen = true
						SolaFP_Options.viewModeSelected = false
						SolaFP_Options.lastShownUpdateNotice = nil
					end
				end
				if SolaFP_Version < 16 then
					SolaFP_Options.noparty = nil
				end
				if SolaFP_Version < 15 then
					SolaFP_Options.noraid = true
					SolaFP_Options.noparty = false
					SolaFP_Options.nopvp = true
				end
				if SolaFP_Version < 14 then
					local savedViewLines
					if SolaFP_Scroll_Info and SolaFP_Scroll_Info.viewLines and type(SolaFP_Scroll_Info.viewLines) == "number" then
						savedViewLines = SolaFP_Scroll_Info.viewLines
					end
					SolaFP_Scroll_Info = nil
					SolaFP_Options.viewLines = savedViewLines or 20
				end
				if SolaFP_Version < 13 then
					SolaFP_Filter_Dungeon = {}
					SolaFP_Filter_Class = nil
				end
			end
		end

		SolaFP_Version = SolaFP_Revision
	end

	if not SolaFP_Options then
		SolaFP_LoadDefaultOption()
	end

	if (SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) ~= "koKR" then
		SolaFP_Options.lfgOnly = true
		SolaFP_Options.viewModeSelected = true
	end

	if SolaFP_Options.esc == nil or SolaFP_Options.esc == false then
		SolaFP_Options.esc = true
	end
	if SolaFP_Options.lfgFilterDrawerOpen == nil then
		SolaFP_Options.lfgFilterDrawerOpen = true
	end
	if SolaFP_Options.color and SolaFP_Options.color.r == 0 and SolaFP_Options.color.g == 0 and SolaFP_Options.color.b == 0 then
		SolaFP_Options.color.r = 0.04
		SolaFP_Options.color.g = 0.06
		SolaFP_Options.color.b = 0.09
		SolaFP_Options.color.opacity = 0.85
	end
	if SolaFP_Options.channel == nil then
		SolaFP_Options.channel = {}
		for k, v in pairs(SolaFP_Default_Options.channel) do
			SolaFP_Options.channel[k] = v
		end
	end

		if SolaFP_Options.titlebarVisible ~= false then
		SolaFP_TitleFrame:Show()
	else
		SolaFP_TitleFrame:Hide()
	end
	if SolaFP_Options.menubarVisible ~= false then
		SolaFP_MenuFrame:Show()
	else
		SolaFP_MenuFrame:Hide()
	end
	SolaFP_ListFrame:SetClampedToScreen(false)
	if SolaFP_Frame and SolaFP_Frame.SetClampedToScreen then
		SolaFP_Frame:SetClampedToScreen(false)
	end
	if SolaFP_ListFrame.SetResizable then
		SolaFP_ListFrame:SetResizable(false)
	end

	SolaFP_FontResize()
	SolaFP_SetListPosition()
	SolaFP_UIResize(SolaFP_Options.scale)
	SolaFP_EnsureSpecialFrame()
	SolaFP_ApplyModernTheme()

	-- Setup minimap icon
	if SolaFP_Minimap_Button and not SolaFP_Options.icon then SolaFP_Minimap_Button:Hide() end
	if SolaFP_Minimap_Button and SolaFP_Options.iconLocked then SolaFP_Minimap_Button:RegisterForDrag(nil) end

	-- Initialize whisper message and level
	-- Whisper Preset & Auto Level Init
	if not SolaFP_WhPresets then SolaFP_WhPresets = {} end
	if SolaFP_WhAutoLevel == nil then
		if not SolaFP_UserDefinedWhMsg or SolaFP_UserDefinedWhMsg == "" then
			SolaFP_WhAutoLevel = true
		else
			SolaFP_WhAutoLevel = false
		end
	end

	if SolaFP_WhAutoLevel or (SolaFP_UserDefinedWhMsg and string.find(SolaFP_UserDefinedWhMsg, "손이요")) then
		SolaFP_WhAutoLevel = true
		SolaFP_RefreshAutoWhMsg()
	elseif SolaFP_UserDefinedWhMsg then
		SolaFP_MenuFrameWhText:SetText(SolaFP_UserDefinedWhMsg)
	end

	if SolaFP_InviteControlFrame and SolaFP_InviteControlFrame.RegisterEvent then
		SolaFP_InviteControlFrame:RegisterEvent("PLAYER_LEVEL_UP")
	end

	-- Patch settings
	if not SolaFP_Options.valid or SolaFP_Options.valid < 60 then
		SolaFP_Options.valid = 120 -- Default cache duration 2 minutes
	end

	-- Initialize filter strings
	if getDungeonFilterNum() > 0 then
		isDungeonFiltering = true
	end
	SolaFP_SetDungeonFilterText()

	-- Initialize exclude strings
	if SolaFP_UserDefinedIgnoreMsg ~= "" then
		SolaFP_MenuFrameIgnoreText:SetText(SolaFP_UserDefineIgnoreMsg)
		SolaFP_SetCustomIgnoreText()
	end

	-- MessageQueue 애드온 설치 검사 및 광고 UI 초기화
	if MessageQueue then
		SolaFP_EnableAnnounce()
	else
		SolaFP_DisableAnnounce(true)
	end

	-- Activate addon
	SolaFP_Activate(SolaFP_Options.activated, true)
	if SolaFP_Options.activateBellnWindow then
		SolaFP_ActiveBellnWindow(true)
	end

	local function printLoadMsg()
		if DEFAULT_CHAT_FRAME then
			local verStr = SolaFP_DISPLAY_VERSION or (SolaFP_GetVersionString and SolaFP_GetVersionString()) or "1.0"
			DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745SolaLFG [" .. verStr .. "]|r |cff8A8580/|r |cff5ABFB0" .. (((SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) == "koKR") and "Sola-아즈샤라" or "Sola") .. "|r")
		end
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(1.5, printLoadMsg)
	else
		printLoadMsg()
	end

	if SolaFP_Options and SolaFP_Options.lfgOnly then
		if C_Timer and C_Timer.After then
			C_Timer.After(0.1, function()
				if SolaFP_ApplyLFGOnlyMode then SolaFP_ApplyLFGOnlyMode(false, false) end
			end)
		end
	end

	-- First-time user welcome card choice popup (for fresh installs and revision 18 update)
	if SolaFP_Options and not SolaFP_Options.viewModeSelected then
		if C_Timer and C_Timer.After then
			C_Timer.After(1.2, function()
				if SolaFP_Options and not SolaFP_Options.viewModeSelected and SolaFP_OpenCardChoiceFrame then
					SolaFP_OpenCardChoiceFrame()
				end
			end)
		end
	end

	-- Update notice popup (shows in front of card choice popup or alone)
	local targetUpdateVer = "1.39"
	if SolaFP_Options and SolaFP_Options.lastShownUpdateNotice ~= targetUpdateVer then
		if C_Timer and C_Timer.After then
			C_Timer.After(1.2, function()
				if SolaFP_ShowUpdatePopup then SolaFP_ShowUpdatePopup(true) end
			end)
		end
	end
end

---------------
-- Parse dungeon text
---------------
-- String filtering helper
function SolaFP_FilterIgnoreText(msg, ignoreTextTable, isTooltip)
	local tempMsg
	if not msg then return tempMsg end
	tempMsg = msg
	if not isTooltip then
		-- Strip whitespace
		--tempMsg = string.gsub(tempMsg, " ", "")
		-- Convert to uppercase
		tempMsg = string.upper(tempMsg)
		-- Re-verify
		if not msg then return tempMsg end
	end
	local x = nil
	local y = nil
	local j = 1

	if ((tempMsg == nil) or (ignoreTextTable == nil)) then
		return nil
	end

	for _, v in pairs(ignoreTextTable) do
		j = 1

		while (true) do
			x, y = string.find(tempMsg, v, j)
			if x then
				tempMsg = string.sub(tempMsg, 1, x-1)..string.sub(tempMsg, y+1)
			else
				break
			end
			j = x
			x = nil
		end
	end
	return tempMsg
end

function SolaFP_DungeonParse(msg)
	local dungeon
	local dungeon_keyword
	local color
	if not msg then return dungeon end
	-- Parse the full message so dungeon names near the end of a listing remain
	-- eligible for classification.
	-- Lua's string functions are byte based; lowercasing still normalizes ASCII
	-- aliases (for example lbrs/LBRS) while leaving Korean text intact.
	local nmsg_dungeon = string.lower(msg)
	if (nmsg_dungeon == nil) then
		return dungeon
	end

	-- Quest/group messages often carry a level prefix (for example [50]).
	-- Treat that as a clue only when the message also reads like a group request;
	-- a level marker by itself is not enough to reject a real summon service ad.
	local hasLevelPrefix = string.find(nmsg_dungeon, "%[%d+%]") ~= nil
	local groupSeekingPhrases = {
		"같이 잡", "잡으실", "잡을 분", "잡을분", "같이 갈", "같이 가실",
		"같이 하실", "퀘팟", "퀘스트", "파티 모집", "파티모집",
	}
	local isLevelPrefixedGroupRequest = false
	if hasLevelPrefix then
		for _, phrase in ipairs(groupSeekingPhrases) do
			if string.find(nmsg_dungeon, phrase, 1, true) then
				isLevelPrefixedGroupRequest = true
				break
			end
		end
	end

	-- Future dungeons may be advertised before all their aliases are added.
	-- A bracketed activity name plus a party count and an explicit recruiting
	-- phrase is stronger evidence of a group listing than the word "summon".
	local hasBracketedActivityName = string.find(nmsg_dungeon, "%b[]") ~= nil
	local hasPartyCount = string.find(nmsg_dungeon, "%(%s*%d+%s*/%s*%d+%s*%)") ~= nil
	local recruitmentPhrases = {
		"구해요", "구합니다", "구함", "모집", "모셔요", "모십니다",
		"자리 구해", "자리구해", "팟원", "파티원",
	}
	local hasRecruitmentPhrase = false
	for _, phrase in ipairs(recruitmentPhrases) do
		if string.find(nmsg_dungeon, phrase, 1, true) then
			hasRecruitmentPhrase = true
			break
		end
	end
	local isBracketedActivityGroupAd = hasBracketedActivityName and hasPartyCount and hasRecruitmentPhrase

	local function checkCategory(tbl)
		for _, tbl2 in ipairs(tbl.dungeon) do
			for i = 1, #tbl2.keywords do
				local keyword = tbl2.keywords[i]
				local normalizedKeyword = string.lower(keyword)
				local genericSummonForGroup = tbl2.name == "포탈 / 소환"
					and (isLevelPrefixedGroupRequest or isBracketedActivityGroupAd)
					and (normalizedKeyword == "소환" or normalizedKeyword == "솬" or normalizedKeyword == "흑마소환" or normalizedKeyword == "흑마솬")
				if string.find(nmsg_dungeon, normalizedKeyword, 1, true) and not genericSummonForGroup then
					local breaking = false
					if tbl2.excludekeywords then
						for j = 1, #tbl2.excludekeywords do
							if string.find(nmsg_dungeon, string.lower(tbl2.excludekeywords[j]), 1, true) then
								breaking = true
								break
							end
						end
					end
					if not breaking and not tbl2.ignoreGlobalExclude then
						for j = 1, #SolaFP_GLOBAL_EXCLUDE_KEYWORDS do
							if string.find(nmsg_dungeon, string.lower(SolaFP_GLOBAL_EXCLUDE_KEYWORDS[j]), 1, true) then
								breaking = true
								break
							end
						end
					end
					-- Apply custom exclude keywords
					if not breaking and #custom_ignore_keywords > 0 then
						for j = 1, #custom_ignore_keywords do
							if string.find(nmsg_dungeon, string.lower(custom_ignore_keywords[j]), 1, true) then
								breaking = true
								break
							end
						end
					end
					-- Strip noise suffixes
					if not breaking then
						local ignore = false
						for k = 1, #SolaFP_DUNGEON_IGNORE_POSTFIX_KEYWORDS do
							if string.find(nmsg_dungeon, normalizedKeyword..string.lower(SolaFP_DUNGEON_IGNORE_POSTFIX_KEYWORDS[k]), 1, true) then
								ignore = true
								break
							end
						end
						if not ignore then
							dungeon = tbl2.name
							dungeon_keyword = keyword
							color = tbl2.color
							return true
						end
					end
				end
			end
		end
		return false
	end

	-- 1단계: 던전/레이드/포에버/PvP/필드보스/퀘스트 우선 매칭
	-- (서비스/거래 키워드가 일반 파티모집 광고를 가로채지 못하도록 보장)
	local serviceCategory
	for _, tbl in ipairs(SolaFP_DUNGEON_KEYWORDS) do
		if tbl.category == "서비스" then
			serviceCategory = tbl
		else
			if checkCategory(tbl) then break end
		end
	end

	-- 2단계: 던전/레이드에 매칭되지 않은 경우에만 서비스/거래 카테고리 매칭
	if not dungeon and serviceCategory then
		checkCategory(serviceCategory)
	end
	-- Debug output
	-- print("---")
	-- print(dungeon..", "..color)

	return dungeon, color, dungeon_keyword
end

-----------------------
-- Strip Questie links
-----------------------
local function removeQuestieLink(msg)
	if string.find(msg, "%[(..-) %((%d+)%)%]..+") then
		if string.find(msg, "%[%d") then
			msg = string.gsub(msg, "%[%[", "%[")
		else
			msg = string.gsub(msg, "%[", "")
		end
		msg = string.gsub(msg, " %(.-%)%]", "")
	end
	return msg
end

-------------------
-- Get dungeon category
-------------------
local function getCategory(dungeon)
	local category
	if dungeon then
		for _, tbl in ipairs(SolaFP_DUNGEON_KEYWORDS) do
			for _, tbl2 in ipairs(tbl.dungeon) do
				if tbl2.name == dungeon then
					category = tbl.category
					break
				end
			end
			if category then break end
		end
	end

	return category or ""
end

local function toggleDungeonFilter()
	isDungeonFiltering = not isDungeonFiltering
end

local SolaFP_UpdateDropdownButtonCheckbox

local function syncDungeonCategoryDropdown(category)
	local categorySelected = SolaFP_Filter_Dungeon[category]
	local categoryData
	for _, tbl in ipairs(SolaFP_DUNGEON_KEYWORDS) do
		if tbl.category == category then categoryData = tbl; break end
	end
	if not categoryData then return end
	for i = 1, 30 do
		local button = _G["DropDownList1Button"..i]
		if not button then break end
		if button:GetText() == category then
			local allSelected = categorySelected ~= nil
			for _, dungeon in ipairs(categoryData.dungeon) do
				if not categorySelected or not categorySelected[dungeon.name] then allSelected = false; break end
			end
			button.checked = allSelected
			local check = _G[button:GetName().."Check"]
			if check then
				if allSelected then check:Show() else check:Hide() end
			end
			if SolaFP_UpdateDropdownButtonCheckbox then SolaFP_UpdateDropdownButtonCheckbox(button) end
			break
		end
	end

	for i, dungeon in ipairs(categoryData.dungeon) do
		local button = _G["DropDownList2Button"..i]
		if button then
			local checked = categorySelected and categorySelected[dungeon.name] == true or false
			button.checked = checked
			local check = _G[button:GetName().."Check"]
			if check then
				if checked then check:Show() else check:Hide() end
			end
			if SolaFP_UpdateDropdownButtonCheckbox then SolaFP_UpdateDropdownButtonCheckbox(button) end
		end
	end
end

local function toggleDungeonCategoryFilter(self, categoryIndex)
	local tbl = SolaFP_DUNGEON_KEYWORDS[categoryIndex]
	if not tbl then return end
	local selected = SolaFP_Filter_Dungeon[tbl.category] or {}
	local allSelected = #tbl.dungeon > 0
	for _, dungeon in ipairs(tbl.dungeon) do
		if not selected[dungeon.name] then allSelected = false; break end
	end
	if allSelected then
		SolaFP_Filter_Dungeon[tbl.category] = nil
	else
		SolaFP_Filter_Dungeon[tbl.category] = {}
		for _, dungeon in ipairs(tbl.dungeon) do
			SolaFP_Filter_Dungeon[tbl.category][dungeon.name] = true
		end
	end
	isDungeonFiltering = getDungeonFilterNum() > 0
	syncDungeonCategoryDropdown(tbl.category)
	SolaFP_SetDungeonFilterText()
	SolaFP_Refresh(true)
end

function SolaFP_DropDownMenuFilterDungeon_Initialize(frame, level, menu)
	level = level or 1
	local info
	if (level == 1) then
		for idx, tbl in ipairs(SolaFP_DUNGEON_KEYWORDS) do
			info = UIDropDownMenu_CreateInfo()
			info.text = tbl.category
			info.keepShownOnClick = true
			info.disabled = false
			info.hasArrow = true
			info.notCheckable = false
			info.isNotRadio = true
			info.checked = SolaFP_Filter_Dungeon[tbl.category] and #tbl.dungeon > 0
			if info.checked then
				for _, dungeon in ipairs(tbl.dungeon) do
					if not SolaFP_Filter_Dungeon[tbl.category][dungeon.name] then info.checked = false; break end
				end
			end
			info.func = toggleDungeonCategoryFilter
			info.arg1 = idx
			info.menuList = idx
			UIDropDownMenu_AddButton(info, level)
		end -- for key, subarray

		-- Blank line
		info = UIDropDownMenu_CreateInfo()
		info.text = ""
		info.disabled = true
		info.checked = false
		info.hasArrow = false
		UIDropDownMenu_AddButton(info, level)

		info = UIDropDownMenu_CreateInfo()
		info.text = SolaFP_TEXT_CLOSE
		info.func = nil
		info.notCheckable = true
		info.keepShownOnClick = false
		UIDropDownMenu_AddButton(info, level)
	elseif (level == 2) then
		for _, tbl in ipairs(SolaFP_DUNGEON_KEYWORDS[menu].dungeon) do
			info = UIDropDownMenu_CreateInfo()
			info.text = tbl.name
			info.keepShownOnClick = true
			info.disabled = false
			info.hasArrow = false
			info.isNotRadio = true
			info.func = SolaFP_FilterDungeonSelected
			info.checked = (SolaFP_Filter_Dungeon[SolaFP_DUNGEON_KEYWORDS[menu].category] and SolaFP_Filter_Dungeon[SolaFP_DUNGEON_KEYWORDS[menu].category][info.text]) or false
			info.menuList = info.text
			info.arg1 = info.text
			info.arg2 = nil
			UIDropDownMenu_AddButton(info, level)
		end -- for key, subarray
	end
end

function SolaFP_FilterDungeonSelected(self, dungeon, _, checked)
	if not dungeon then return end
	local category = getCategory(dungeon)

	-- Add to filter
	if checked then
		-- Create table if needed
		if not SolaFP_Filter_Dungeon[category] then
			SolaFP_Filter_Dungeon[category] = {}
		end
		if not SolaFP_Filter_Dungeon[category][dungeon] then
			SolaFP_Filter_Dungeon[category][dungeon] = true
		end
	else
	-- Remove from filter
		SolaFP_Filter_Dungeon[category][dungeon] = nil
		-- Clean up table
		local category_tables = 0
		for _, tbl in pairs(SolaFP_Filter_Dungeon[category]) do
			category_tables = category_tables + 1
		end
		if category_tables == 0 then
			SolaFP_Filter_Dungeon[category] = nil
		end
	end

	-- Update dungeon filter state
	if getDungeonFilterNum() > 0 then
		isDungeonFiltering = true
	else
		isDungeonFiltering = false
	end
	SolaFP_SetDungeonFilterText()

	-- Synchronize checkboxes
	local idx = 1
	local loop = true
	-- Loop guard: limit 30
	while loop and idx < 30 do
		local button = _G["DropDownList2Button"..idx]
		if button and button:GetText() then
			local button_text = button:GetText()
			if SolaFP_Filter_Dungeon[category] and SolaFP_Filter_Dungeon[category][button_text] then
				button.checked = true
				_G["DropDownList2Button"..idx.."Check"]:Show()
			else
				button.checked = false
				_G["DropDownList2Button"..idx.."Check"]:Hide()
			end
			if SolaFP_UpdateDropdownButtonCheckbox then
				SolaFP_UpdateDropdownButtonCheckbox(button)
			end
		else
			loop = false
			break
		end
		idx = idx + 1
	end

	local idx2 = 1
	local loop2 = true
	-- Loop guard: limit 10
	while loop2 and idx2 < 15 do
		local button2 = _G["DropDownList3Button"..idx2]
		if button2 and button2.value then
			local button2_text = button2.value
			if SolaFP_Filter_Dungeon[category] and SolaFP_Filter_Dungeon[category][dungeon] and SolaFP_Filter_Dungeon[category][dungeon][button2_text] then
				button2.checked = true
				_G["DropDownList3Button"..idx2.."Check"]:Show()
			else
				button2.checked = false
				_G["DropDownList3Button"..idx2.."Check"]:Hide()
			end
			if SolaFP_UpdateDropdownButtonCheckbox then
				SolaFP_UpdateDropdownButtonCheckbox(button2)
			end
		else
			loop2 = false
			break
		end
		idx2 = idx2 + 1
	end

	SolaFP_Refresh(true)
end

function SolaFP_GetDungeonFilterList()
	local desc = ""
	local i = 0
	local num = getDungeonFilterNum()

	for _, tbl in pairs(SolaFP_Filter_Dungeon) do
		for idx, _ in pairs(tbl) do
			i = i + 1
			-- Add thousands separator
			if i == num then
				desc = desc..idx
			elseif i % 3 == 0 then
				desc = desc..idx.."\n"
			else
				desc = desc..idx..", "
			end
		end
	end
	if desc == "" then
		desc = SolaFP_DUNGEONFILTER_NONE or "없음"
	end

	return desc
end

function SolaFP_SetDungeonFilterText()
	local desc = SolaFP_DUNGEONFILTER_NOT_FILTERED or "모두 보기"
	local filtered_count = getDungeonFilterNum()

	if isDungeonFiltering and filtered_count > 1 then
		desc = string.format(SolaFP_DUNGEONFILTER_MULTI or "던전: %d개 선택", filtered_count)
	elseif isDungeonFiltering and filtered_count > 0 then
		for _, tbl in pairs(SolaFP_Filter_Dungeon) do
			for idx, _ in pairs(tbl) do
				desc = string.format(SolaFP_DUNGEONFILTER_SINGLE or "던전: %s", idx)
			end
		end
	end

	if SolaFP_ListFrameFilterDungeonText then
		SolaFP_ListFrameFilterDungeonText:SetText(desc)
	end
end

-- Clear all selected dungeon filters and switch to View All
function SolaFP_ClearDungeonFilter()
	local hadFilters = (getDungeonFilterNum() > 0)
	SolaFP_Filter_Dungeon = {}
	isDungeonFiltering = false
	SolaFP_SetDungeonFilterText()
	SolaFP_Refresh(true)
	CloseDropDownMenus()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
	if hadFilters then
		SolaFP_Print(SolaFP_MESSAGE_DUNGEON_RESET)
	end
end

-- Toggle between View All and Interested Dungeons filter without clearing selections
function SolaFP_ToggleDungeonFilterView()
	local count = getDungeonFilterNum()
	if count == 0 then
		SolaFP_Print(SolaFP_L and SolaFP_L["No interested dungeons selected."] or "선택된 관심 던전이 없습니다. 던전 목록에서 관심 던전을 먼저 선택해주세요.")
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		return
	end

	isDungeonFiltering = not isDungeonFiltering
	SolaFP_SetDungeonFilterText()
	SolaFP_Refresh(true)
	CloseDropDownMenus()

	if isDungeonFiltering then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
		local desc = ""
		if count == 1 then
			for _, tbl in pairs(SolaFP_Filter_Dungeon) do
				for idx in pairs(tbl) do
					desc = idx
				end
			end
		else
			desc = string.format(SolaFP_L and SolaFP_L["%d dungeons"] or "%d개 던전", count)
		end
		SolaFP_Print(string.format(SolaFP_L and SolaFP_L["Filtered to interested dungeons (%s)."] or "관심 던전 필터가 활성화되었습니다. (%s)", desc))
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		SolaFP_Print(SolaFP_L and SolaFP_L["Showing all dungeons."] or "모든 던전 광고를 표시합니다. (모두 보기)")
	end
end

function SolaFP_DungeonFilter(dungeon)
	if isDungeonFiltering and getDungeonFilterNum() > 0 then
		for _, tbl in pairs(SolaFP_Filter_Dungeon) do
			for idx, tbl2 in pairs(tbl) do
				if dungeon == idx then
					return true
				end
			end
		end
		return false
	end
	return true
end

-- Custom filter matching
function SolaFP_CustomFilter(msg)
	local table = {
		['flag'] = false,
		['msg'] = msg
	}
	local userInputCustomFilterString = SolaFP_UserDefineFilterMsg
	if userInputCustomFilterString == "" then
		table.flag = true
		table.msg = msg
		return table
	end
	for word in string.gmatch(userInputCustomFilterString, '([^,]+)') do
		word = string.gsub(word, " ", "")
		if string.find(msg, word) then
			msg = string.gsub(msg, word, '|cff7fff00'..word..'|cffffffff')
			table.flag = true
			table.msg = msg
		end
	end
	return table
end

function SolaFP_SetCustomFilterText()
	SolaFP_UserDefineFilterMsg = SolaFP_MenuFrameFilterText:GetText();
end

function SolaFP_SetCustomIgnoreText()
	SolaFP_UserDefineIgnoreMsg = SolaFP_MenuFrameIgnoreText:GetText();

	local userString = SolaFP_UserDefineIgnoreMsg

	if userString ~= "" then
		wipe(custom_ignore_keywords)
		for word in string.gmatch(userString, '([^,]+)') do
			tinsert(custom_ignore_keywords, word)
		end
		for i = 1, #frameData do
			for j = 1, #custom_ignore_keywords do
				if string.find(frameData[i].rawmsg, custom_ignore_keywords[j]) then
					frameData[i].ignored = true
				end
			end
		end
		SolaFP_Refresh()
	else
		wipe(custom_ignore_keywords)
	end
end

-----------------
-- Exclusion filtering
-----------------
function SolaFP_ExceptionFilter(exception)
	if exceptionData then
		for i = 1, #exceptionData, 1 do
			if (exceptionData[i]==exception) then
				return false
			end
		end
	end
	return true
end

---------------------------------------
-- Action handlers
---------------------------------------
function SolaFP_Activate(active, noMsg)
	SolaFP_Options.activated = active
	if active then
		if not noMsg then SolaFP_Print(string.format(SolaFP_MESSAGE_ACTIVE, SolaFP_DISPLAY_VERSION)) end
		SolaFP_Refresh()
	else
		if not noMsg then SolaFP_Print(string.format(SolaFP_MESSAGE_DEACTIVE, SolaFP_DISPLAY_VERSION)) end
	end
	SolaFP_UpdateStatusPills()
end

function SolaFP_ActiveBellnWindow(active)
	SolaFP_Options.activateBellnWindow = active
	if active then
		SolaFP_Print(SolaFP_MESSAGE_POPUP_ACTIVE)
	else
		SolaFP_Print(SolaFP_MESSAGE_POPUP_DEACTIVE)
	end
	SolaFP_UpdateStatusPills()
end

function SolaFP_AutoDeactivate()
	local _, instancetype = GetInstanceInfo()
	if SolaFP_Options.activated then
		if instancetype == "raid" and SolaFP_Options.noraid then SolaFP_Activate(false) end
		if instancetype == "pvp" and SolaFP_Options.nopvp then SolaFP_Activate(false) end
	elseif not SolaFP_Options.useroffed and not SolaFP_Options.activated then
		if SolaFP_Options.noraid and SolaFP_Options.nopvp then
			if instancetype ~= "raid" and instancetype ~= "pvp" then SolaFP_Activate(true) end
		elseif SolaFP_Options.noraid then
			if instancetype ~= "raid" then SolaFP_Activate(true) end
		elseif SolaFP_Options.nopvp then
			if instancetype ~= "pvp" then SolaFP_Activate(true) end
		end
	end
end

-------------------------------------------------
-- Whisper Macro Preset System (Max 5 + Auto Level)
-------------------------------------------------
-------------------------------------------------
-- Whisper Macro Preset System (Max 5 + Auto Level)
-------------------------------------------------
SolaFP_WhPresets = SolaFP_WhPresets or {}
SolaFP_WhAutoLevel = true

function SolaFP_RefreshAutoWhMsg()
	local lvl = UnitLevel("player")
	local cls = (SolaFP_GetPlayerClassName and SolaFP_GetPlayerClassName()) or UnitClass("player")
	if lvl and cls then
		local autoMsg = string.format(SolaFP_TEXT_AUTO_WHISPER_FORMAT or "%d %s 초대 부탁드립니다", lvl, cls)
		if SolaFP_MenuFrameWhText then
			SolaFP_MenuFrameWhText:SetText(autoMsg)
		end
		if SolaFP_LFG_WhText then
			SolaFP_LFG_WhText:SetText(autoMsg)
		end
		SolaFP_UserDefinedWhMsg = autoMsg
	end
end

function SolaFP_Tooltip_WhPresetBtn(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(SolaFP_L["Whisper Message Presets (Click to open)"] or "귓속말 문구 목록 (클릭하여 열기)", 1, 0.85, 0.5)
	GameTooltip:AddLine(SolaFP_L["Select or delete saved whisper messages.\nSupports [Auto] Level + Class option."] or "저장된 문구를 선택하거나 삭제할 수 있습니다.\n[자동] 레벨+직업 옵션도 지원합니다.", 0.8, 0.8, 0.8, true)
	GameTooltip:Show()
end

function SolaFP_Tooltip_WhAddBtn(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(SolaFP_L["Add Whisper Preset"] or "귓속말 문구 추가", 1, 0.85, 0.5)
	GameTooltip:AddLine(SolaFP_L["Saves current input text to the preset list.\n(Up to 5 messages)"] or "현재 입력창의 문구를 목록에 저장합니다.\n(최대 5개까지 등록 가능)", 0.8, 0.8, 0.8, true)
	GameTooltip:Show()
end

local whPresetFrame = nil

function SolaFP_EnsureWhPresetFrame()
	if whPresetFrame then return whPresetFrame end

	local f = CreateFrame("Frame", "SolaFP_WhPresetFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	whPresetFrame = f
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetClampedToScreen(true)
	f:SetWidth(360)
	f:Hide()

	if BackdropTemplateMixin and not f.SetBackdrop then
		Mixin(f, BackdropTemplateMixin)
		f:OnBackdropLoaded()
	end
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile   = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1,
			insets   = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		f:SetBackdropColor(SolaC.bgSidebar[1], SolaC.bgSidebar[2], SolaC.bgSidebar[3], 0.98)
		f:SetBackdropBorderColor(0, 0, 0, 0.85)
	end

	-- Top 1px Gold Accent Line (SolaQoL Signature)
	local accent = f:CreateTexture(nil, "ARTWORK", nil, 7)
	accent:SetPoint("TOPLEFT", 1, -1)
	accent:SetPoint("TOPRIGHT", -1, -1)
	accent:SetHeight(1)
	accent:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.85)
	f.__fp_accent = accent

	-- Top Sheen
	local shine = f:CreateTexture(nil, "BORDER", nil, 5)
	shine:SetPoint("TOPLEFT", 1, -2)
	shine:SetPoint("TOPRIGHT", -1, -2)
	shine:SetHeight(18)
	shine:SetColorTexture(1, 1, 1, 0.025)
	f.__fp_shine = shine

	-- Header Title
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	title:SetPoint("TOPLEFT", 12, -8)
	title:SetText("|cffD4A745" .. (SolaFP_L["Whisper Message Presets"] or "귓속말 문구 목록") .. "|r |cff8A8580(" .. (SolaFP_L["Up to 5 saved"] or "최대 5개 저장") .. ")|r")
	f.__fp_title = title

	-- Header Close Button [X]
	local closeBtn = CreateFrame("Button", nil, f)
	closeBtn:SetSize(18, 18)
	closeBtn:SetPoint("TOPRIGHT", -6, -6)
	local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	closeTxt:SetPoint("CENTER", 0, 0)
	closeTxt:SetText("|cff8A8580X|r")
	closeBtn:SetScript("OnEnter", function() closeTxt:SetText("|cffCF6679X|r") end)
	closeBtn:SetScript("OnLeave", function() closeTxt:SetText("|cff8A8580X|r") end)
	closeBtn:SetScript("OnClick", function() f:Hide() end)

	-- Auto Level/Class Item (Row 0 - Always available)
	local autoBtn = CreateFrame("Button", nil, f)
	autoBtn:SetHeight(24)
	autoBtn:SetPoint("TOPLEFT", 8, -28)
	autoBtn:SetPoint("TOPRIGHT", -8, -28)

	local autoHl = autoBtn:CreateTexture(nil, "HIGHLIGHT")
	autoHl:SetAllPoints(autoBtn)
	autoHl:SetColorTexture(SolaC.bgSelected[1], SolaC.bgSelected[2], SolaC.bgSelected[3], 0.90)

	local autoTxt = autoBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	autoTxt:SetPoint("LEFT", 6, 0)
	autoTxt:SetPoint("RIGHT", -6, 0)
	autoTxt:SetJustifyH("LEFT")
	autoBtn.txt = autoTxt

	autoBtn:SetScript("OnClick", function()
		SolaFP_WhAutoLevel = true
		SolaFP_RefreshAutoWhMsg()
		local cur = (SolaFP_LFG_WhText and SolaFP_LFG_WhText:GetText()) or (SolaFP_MenuFrameWhText and SolaFP_MenuFrameWhText:GetText()) or SolaFP_UserDefinedWhMsg or ""
		SolaFP_Print(string.format(SolaFP_L["Selected auto level/class message: %s"] or "|cff6BBF8A[자동 신청]|r 현재 레벨/직업 문구로 선택되었습니다: %s", cur))
		f:Hide()
	end)
	autoBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(SolaFP_TEXT_AUTO_WHISPER_LABEL or SolaFP_L["Current Level + Class + Inv please"] or "현재레벨 + 직업 + 초대 부탁드립니다", 1, 0.85, 0.5)
		GameTooltip:AddLine(SolaFP_L["Automatically updates your level whenever SolaLFG opens."] or "선택 시 SolaLFG 창을 열 때마다 레벨이 자동으로 갱신됩니다.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	autoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.__fp_autoBtn = autoBtn

	-- Separator line below Auto Item
	local sep = f:CreateTexture(nil, "ARTWORK", nil, 6)
	sep:SetPoint("TOPLEFT", 8, -54)
	sep:SetPoint("TOPRIGHT", -8, -54)
	sep:SetHeight(1)
	sep:SetColorTexture(1, 1, 1, 0.08)
	f.__fp_sep = sep

	-- Custom Preset Rows (1..5)
	f.presetRows = {}
	for i = 1, 5 do
		local row = CreateFrame("Frame", nil, f)
		row:SetHeight(24)
		row:SetPoint("TOPLEFT", 8, -58 - (i - 1) * 26)
		row:SetPoint("TOPRIGHT", -8, -58 - (i - 1) * 26)

		local selBtn = CreateFrame("Button", nil, row)
		selBtn:SetPoint("TOPLEFT", 0, 0)
		selBtn:SetPoint("BOTTOMRIGHT", -26, 0)

		local selHl = selBtn:CreateTexture(nil, "HIGHLIGHT")
		selHl:SetAllPoints(selBtn)
		selHl:SetColorTexture(SolaC.bgSelected[1], SolaC.bgSelected[2], SolaC.bgSelected[3], 0.90)

		local selTxt = selBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		selTxt:SetPoint("LEFT", 6, 0)
		selTxt:SetPoint("RIGHT", -4, 0)
		selTxt:SetJustifyH("LEFT")
		selBtn.txt = selTxt

		local idx = i
		selBtn:SetScript("OnClick", function()
			if SolaFP_WhPresets and SolaFP_WhPresets[idx] then
				SolaFP_WhAutoLevel = false
				local chosen = SolaFP_WhPresets[idx]
				if SolaFP_MenuFrameWhText then SolaFP_MenuFrameWhText:SetText(chosen) end
				if SolaFP_LFG_WhText then SolaFP_LFG_WhText:SetText(chosen) end
				SolaFP_UserDefinedWhMsg = chosen
				SolaFP_Print(string.format(SolaFP_L["Whisper message selected: %s"] or "귓속말 문구가 선택되었습니다: %s", chosen))
				f:Hide()
			end
		end)

		local delBtn = CreateFrame("Button", nil, row)
		delBtn:SetSize(22, 22)
		delBtn:SetPoint("RIGHT", 0, 0)

		local delTxt = delBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		delTxt:SetPoint("CENTER", 0, 0)
		delTxt:SetText("|cffCF6679X|r")
		delBtn.txt = delTxt

		delBtn:SetScript("OnEnter", function(self)
			self.txt:SetText("|cffFF4D4DX|r")
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(SolaFP_L["Delete Message"] or "문구 삭제", 1, 0.4, 0.4)
			GameTooltip:AddLine(SolaFP_L["Remove this message from the list."] or "이 문구를 목록에서 제거합니다.", 0.8, 0.8, 0.8)
			GameTooltip:Show()
		end)
		delBtn:SetScript("OnLeave", function(self)
			self.txt:SetText("|cffCF6679X|r")
			GameTooltip:Hide()
		end)
		delBtn:SetScript("OnClick", function()
			if SolaFP_WhPresets and SolaFP_WhPresets[idx] then
				local removed = table.remove(SolaFP_WhPresets, idx)
				SolaFP_Print(string.format(SolaFP_L["Saved message deleted: %s"] or "저장 문구가 삭제되었습니다: %s", removed or ""))
				SolaFP_UpdateWhPresetMenu()
			end
		end)

		row.selBtn = selBtn
		row.delBtn = delBtn
		f.presetRows[i] = row
	end

	-- Empty notice label
	local emptyTxt = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	emptyTxt:SetPoint("TOPLEFT", 14, -66)
	emptyTxt:SetPoint("TOPRIGHT", -14, -66)
	emptyTxt:SetJustifyH("LEFT")
	emptyTxt:SetText("|cff8A8580(" .. (SolaFP_L["No saved messages - Register using [Add]"] or "저장된 문구 없음 - [추가] 버튼으로 등록") .. ")|r")
	f.__fp_emptyTxt = emptyTxt

	-- Fullscreen click-catcher to dismiss dropdown when clicking outside
	local catcher = CreateFrame("Button", nil, f)
	catcher:SetFrameStrata("FULLSCREEN_DIALOG")
	catcher:SetFrameLevel(f:GetFrameLevel() - 1)
	catcher:SetAllPoints(UIParent)
	catcher:RegisterForClicks("AnyUp", "AnyDown")
	catcher:SetScript("OnClick", function()
		f:Hide()
	end)
	f.__fp_catcher = catcher

	tinsert(UISpecialFrames, "SolaFP_WhPresetFrame")
	return f
end

function SolaFP_UpdateWhPresetMenu()
	local f = SolaFP_EnsureWhPresetFrame()
	if not SolaFP_WhPresets then SolaFP_WhPresets = {} end

	local lvl = UnitLevel("player") or 1
	local cls = (SolaFP_GetPlayerClassName and SolaFP_GetPlayerClassName()) or UnitClass("player") or SolaFP_L["Unknown Class"] or "직업"
	local autoMsg = string.format(SolaFP_TEXT_AUTO_WHISPER_FORMAT or "%d %s 초대 부탁드립니다", lvl, cls)

	local autoLabel = SolaFP_L["Auto"] or "자동"
	local selLabel = SolaFP_L["Selected"] or "선택됨"
	if SolaFP_WhAutoLevel then
		f.__fp_autoBtn.txt:SetText(string.format("|cff6BBF8A[V] [%s] %s (%s)|r", autoLabel, autoMsg, selLabel))
	else
		f.__fp_autoBtn.txt:SetText(string.format("|cffD4A745[%s]|r %s", autoLabel, autoMsg))
	end

	local count = #SolaFP_WhPresets
	local curText = ""
	if SolaFP_LFG_WhText and SolaFP_LFG_WhText:IsShown() and SolaFP_LFG_WhText:GetText() and SolaFP_LFG_WhText:GetText() ~= "" then
		curText = SolaFP_LFG_WhText:GetText()
	elseif SolaFP_MenuFrameWhText and SolaFP_MenuFrameWhText:IsShown() and SolaFP_MenuFrameWhText:GetText() and SolaFP_MenuFrameWhText:GetText() ~= "" then
		curText = SolaFP_MenuFrameWhText:GetText()
	else
		curText = SolaFP_UserDefinedWhMsg or ""
	end

	for i = 1, 5 do
		local row = f.presetRows[i]
		if i <= count then
			local preset = SolaFP_WhPresets[i]
			local isSelected = (not SolaFP_WhAutoLevel) and (curText == preset)
			if isSelected then
				row.selBtn.txt:SetText(string.format("|cff6BBF8A[V] %d. %s|r", i, preset))
			else
				row.selBtn.txt:SetText(string.format("|cffF0ECE8%d. %s|r", i, preset))
			end
			row:Show()
		else
			row:Hide()
		end
	end

	if count == 0 then
		f.__fp_emptyTxt:Show()
		f:SetHeight(94)
	else
		f.__fp_emptyTxt:Hide()
		f:SetHeight(64 + (count * 26))
	end
end

function SolaFP_ToggleWhPresetMenu(anchorFrame)
	local f = SolaFP_EnsureWhPresetFrame()
	if f:IsShown() then
		f:Hide()
		return
	end

	-- Accurately detect whether opened from LFG panel or Chat Filter window
	local isLfgTarget = false
	if anchorFrame then
		local aName = (anchorFrame.GetName and anchorFrame:GetName()) or ""
		if aName:find("LFG") or anchorFrame == SolaFP_LFG_WhPresetBtn or anchorFrame == SolaFP_LFG_WhText then
			isLfgTarget = true
		elseif SolaFP_LFGPanel and anchorFrame.IsDescendantOf and anchorFrame:IsDescendantOf(SolaFP_LFGPanel) then
			isLfgTarget = true
		end
	else
		if (SolaFP_Options and SolaFP_Options.lfgOnly) or (SolaFP_LFGPanel and SolaFP_LFGPanel:IsShown() and not (SolaFP_ListFrame and SolaFP_ListFrame:IsShown())) then
			isLfgTarget = true
		end
	end

	local hostParent = nil
	local hostAnchor = nil
	local xOff, yOff = 10, 4

	if isLfgTarget then
		hostParent = SolaFP_LFG_BottomBar or SolaFP_LFGPanel
		hostAnchor = hostParent
		if hostParent == SolaFP_LFGPanel then
			yOff = 36
		end
	else
		hostParent = SolaFP_MenuFrame or SolaFP_Frame or UIParent
		hostAnchor = SolaFP_MenuFrame or SolaFP_Frame
	end

	if hostParent and hostParent ~= UIParent then
		f:SetParent(hostParent)
		f:SetScale(1.0)
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f:SetFrameLevel((hostParent.GetFrameLevel and hostParent:GetFrameLevel() or 20) + 50)
	else
		f:SetParent(UIParent)
		local sc = tonumber(SolaFP_Options and SolaFP_Options.scale) or 1.0
		f:SetScale(sc)
		f:SetFrameStrata("FULLSCREEN_DIALOG")
	end

	f:ClearAllPoints()
	if hostAnchor and hostAnchor ~= UIParent then
		f:SetPoint("BOTTOMLEFT", hostAnchor, "TOPLEFT", xOff, yOff)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end

	-- Natural width: 360px default, fitted comfortably if host window is narrower
	local targetWidth = 360
	if hostParent and hostParent.GetWidth and hostParent:GetWidth() then
		local hw = hostParent:GetWidth()
		if hw > 150 and hw < 380 then
			targetWidth = math.max(280, hw - 20)
		end
	end
	f:SetWidth(targetWidth)

	SolaFP_UpdateWhPresetMenu()
	f:Show()
end

function SolaFP_AddCurrentWhPreset()
	local eb = (SolaFP_Options and SolaFP_Options.lfgOnly and SolaFP_LFG_WhText) or SolaFP_MenuFrameWhText
	local text = eb and eb:GetText()
	if not text or text:match("^%s*$") then
		SolaFP_Print(SolaFP_L["Please enter a message to save first."] or "저장할 문구를 먼저 입력해주세요.")
		return
	end

	if not SolaFP_WhPresets then SolaFP_WhPresets = {} end

	for _, v in ipairs(SolaFP_WhPresets) do
		if v == text then
			SolaFP_Print(SolaFP_L["This message is already saved."] or "이미 저장되어 있는 문구입니다.")
			return
		end
	end

	if #SolaFP_WhPresets >= 5 then
		SolaFP_Print(SolaFP_L["You can save up to 5 preset messages."] or "저장 문구는 최대 5개까지 등록할 수 있습니다.")
		return
	end

	table.insert(SolaFP_WhPresets, text)
	SolaFP_Print(string.format(SolaFP_L["Whisper message saved: |cffD4A745%s|r"] or "귓속말 문구가 저장되었습니다: |cffD4A745%s|r", text))

	if whPresetFrame and whPresetFrame:IsShown() then
		SolaFP_UpdateWhPresetMenu()
	end
end

function SolaFP_Whisper(target)
	if not target or target == "" then return end

	local msg = ""
	if SolaFP_Options and SolaFP_Options.lfgOnly then
		msg = (SolaFP_LFG_WhText and SolaFP_LFG_WhText:GetText()) or (SolaFP_MenuFrameWhText and SolaFP_MenuFrameWhText:GetText()) or SolaFP_UserDefinedWhMsg or ""
	else
		msg = (SolaFP_MenuFrameWhText and SolaFP_MenuFrameWhText:GetText()) or (SolaFP_LFG_WhText and SolaFP_LFG_WhText:GetText()) or SolaFP_UserDefinedWhMsg or ""
	end

	if msg and msg ~= "" then
		SolaFP_UserDefinedWhMsg = msg
	end

	if not msg or string.len(msg) == 0 then
		local playerClass = (SolaFP_GetPlayerClassName and SolaFP_GetPlayerClassName()) or UnitClass("player") or ""
		local myTalent = SolaFP_GetMyTalent() or ""
		local formatStr = SolaFP_DEFAULT_WHISPER or "%s %s 초대 부탁드립니다"
		if myTalent ~= "" then
			msg = string.format(formatStr, myTalent, playerClass)
		else
			msg = string.format(formatStr, "", playerClass)
		end
		msg = strtrim(msg)
	end

	if msg and msg ~= "" then
		SendChatMessage(msg, "WHISPER", nil, target)
	end
end

function SolaFP_Exception(target)
	if exceptionData then
		savePlace = #exceptionData + 1
	else
		savePlace = 1
	end
	exceptionData[savePlace] = target

	SolaFP_Print(string.format(SolaFP_MESSAGE_EXCEPTION, target))
	SolaFP_Refresh(true)
end

function SolaFP_GetMyTalent()
	local ok, talentName = pcall(function()
		-- 1. Modern WoW / WoW Forever C_SpecializationInfo
		if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
			local specIdx = C_SpecializationInfo.GetSpecialization()
			if specIdx and specIdx > 0 and GetSpecializationInfo then
				local _, name = GetSpecializationInfo(specIdx)
				if name and name ~= "" then return name end
			end
		end

		-- 2. Modern WoW global GetSpecialization
		if GetSpecialization and GetSpecializationInfo then
			local specIdx = GetSpecialization()
			if specIdx and specIdx > 0 then
				local _, name = GetSpecializationInfo(specIdx)
				if name and name ~= "" then return name end
			end
		end

		-- 3. Classic Era GetTalentTabInfo
		if GetNumTalentTabs and GetTalentTabInfo then
			local maxPts = -1
			local bestName = ""
			local numTabs = GetNumTalentTabs() or 0
			for i = 1, numTabs do
				local ret1, ret2, ret3, ret4, ret5 = GetTalentTabInfo(i)
				local tabName = (type(ret2) == "string" and ret2 ~= "") and ret2 or ((type(ret1) == "string") and ret1 or "")
				local pts = tonumber(ret5) or tonumber(ret3) or 0
				if pts > maxPts then
					maxPts = pts
					bestName = tabName
				end
			end
			if bestName ~= "" and maxPts > 0 then
				return bestName
			end
		end

		return ""
	end)

	if ok and type(talentName) == "string" then
		return talentName
	end
	return ""
end

------------------------------
-- UI button click handlers
------------------------------
function SolaFP_SortButtonClicked(self)
	local id = self:GetID()

	column = colName[id]

	sortData[column] = not sortData[column]
	sortData.current_sort = column

	SolaFP_Refresh()
	return sortData[column]
end

function SolaFP_ListSort(list, col, ascd)
	if list ~= nil and col ~= nil then
		local endIdx = #list
		for i = 1, endIdx,1 do
			for j = i + 1, endIdx, 1 do
				local pivot = list[i][col]
				local comp = list[j][col]

				if col == "dungeon" then
					pivot = pivot..list[i]["mode"]
					comp = comp..list[j]["mode"]
				end
				if ((ascd and (pivot > comp)) or (not ascd and (pivot < comp))) then
					local temp = list[i]
					list[i] = list[j]
					list[j] = temp
				end
			end
		end
	end
end

local function SolaFP_SendWho(name)
	if not name then return end
	if C_FriendList and C_FriendList.SendWho then
		C_FriendList.SendWho(name)
	elseif SendWho then
		SendWho(name)
	end
end

local dropDownCloseTime = 0

local function SolaFP_SetDropdownCboxBorder(cbox, r, g, b, a)
	if not cbox then return end
	cbox.b_top:SetColorTexture(r, g, b, a)
	cbox.b_btm:SetColorTexture(r, g, b, a)
	cbox.b_lft:SetColorTexture(r, g, b, a)
	cbox.b_rgt:SetColorTexture(r, g, b, a)
end

function SolaFP_UpdateDropdownButtonCheckbox(btn)
	if not btn or not btn.__fp_cbox then return end
	local text = btn:GetText()
	if not btn:IsShown() or btn.notCheckable or (text == "" or text == nil) then
		btn.__fp_cbox:Hide()
		return
	end

	local check = _G[btn:GetName().."Check"]
	local isChecked = (check and check:IsShown()) or (btn.checked == true)
	local cbox = btn.__fp_cbox

	cbox:Show()
	if cbox.cmark then cbox.cmark:Hide() end

	if isChecked then
		if cbox.rdot then cbox.rdot:Show() end
		cbox.bg:SetColorTexture(0.14, 0.12, 0.06, 0.95)
		SolaFP_SetDropdownCboxBorder(cbox, SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.95)
	else
		if cbox.rdot then cbox.rdot:Hide() end
		cbox.bg:SetColorTexture(0.08, 0.09, 0.11, 0.90)
		SolaFP_SetDropdownCboxBorder(cbox, 0.28, 0.32, 0.36, 0.75)
	end
end

local function SolaFP_RestoreDropDownList(list)
	if not list then return end
	local name = list:GetName()
	if not name then return end
	local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 32
	for i = 1, maxButtons do
		local btn = _G[name.."Button"..i]
		if btn then
			if btn.__fp_cbox then
				btn.__fp_cbox:Hide()
			end
			local check = _G[name.."Button"..i.."Check"]
			if check and check.SetAlpha then
				check:SetAlpha(1)
			end
			local uncheck = _G[name.."Button"..i.."UnCheck"]
			if uncheck and uncheck.SetAlpha then
				uncheck:SetAlpha(1)
			end
		end
	end
end

function SolaFP_GetDropdownTargetScale(anchor)
	if anchor and anchor.GetEffectiveScale and UIParent and UIParent.GetEffectiveScale then
		local uScale = UIParent:GetEffectiveScale()
		if uScale and uScale > 0 then
			local effScale = anchor:GetEffectiveScale()
			if effScale and effScale > 0 then
				return effScale / uScale
			end
		end
	end
	if SolaFP_Frame and SolaFP_Frame.GetScale then
		local s = SolaFP_Frame:GetScale()
		if s and s > 0 then return s end
	end
	return 1.0
end

local function SolaFP_SkinDropDownList(list)
	if not list then return end
	if (UIDROPDOWNMENU_OPEN_MENU ~= SolaFP_DropDownMenu) and (list.dropdown ~= SolaFP_DropDownMenu) then return end

	local name = list:GetName()
	if not name then return end

	-- Apply target scale (match window/anchor scale 1:1, no 0.64 shrinking)
	local targetScale = SolaFP_DropDownMenu.__fp_target_scale or SolaFP_GetDropdownTargetScale(SolaFP_DropDownMenu or SolaFP_Frame)
	if list.SetScale and targetScale and targetScale > 0 then
		if list:GetScale() ~= targetScale then
			list:SetScale(targetScale)
		end
		list.__fp_scaled = true
	end

	-- Ensure dropdown is in high strata
	if list.SetFrameStrata then
		list:SetFrameStrata("FULLSCREEN_DIALOG")
	end

	local bd = _G[name.."Backdrop"] or list.Border or list.Backdrop
	local mbd = _G[name.."MenuBackdrop"] or list.MenuBackdrop

	-- 1. Create or retrieve our dedicated solid background frame on list
	if not list.__fp_bg_frame then
		local bg = CreateFrame("Frame", nil, list)
		list.__fp_bg_frame = bg

		-- Solid opaque background texture (SolaQoL dark charcoal)
		local tex = bg:CreateTexture(nil, "BACKGROUND", nil, -8)
		tex:SetAllPoints(bg)
		tex:SetColorTexture(SolaC.bgSidebar[1], SolaC.bgSidebar[2], SolaC.bgSidebar[3], 0.98)
		bg.__fp_tex = tex

		-- 1px Border textures around all four sides
		local function CreateBorder(p1, p2, p3, p4, w, h)
			local b = bg:CreateTexture(nil, "BORDER", nil, 6)
			b:SetPoint(p1, bg, p2, 0, 0)
			b:SetPoint(p3, bg, p4, 0, 0)
			if w then b:SetWidth(w) end
			if h then b:SetHeight(h) end
			b:SetColorTexture(0, 0, 0, 0.85)
			return b
		end
		bg.__fp_b_top = CreateBorder("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT", nil, 1)
		bg.__fp_b_btm = CreateBorder("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 1)
		bg.__fp_b_lft = CreateBorder("TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT", 1, nil)
		bg.__fp_b_rgt = CreateBorder("TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT", 1, nil)

		-- SolaQoL Signature: Top 1px Gold Accent Line (#D4A745)
		local accent = bg:CreateTexture(nil, "ARTWORK", nil, 7)
		accent:SetPoint("TOPLEFT", bg, "TOPLEFT", 1, -1)
		accent:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -1, -1)
		accent:SetHeight(1)
		accent:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.85)
		bg.__fp_accent = accent

		-- Subtle top sheen
		local shine = bg:CreateTexture(nil, "BORDER", nil, 5)
		shine:SetPoint("TOPLEFT", bg, "TOPLEFT", 1, -2)
		shine:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -1, -2)
		shine:SetHeight(18)
		shine:SetColorTexture(1, 1, 1, 0.025)
		bg.__fp_shine = shine
	end

	local bgFrame = list.__fp_bg_frame
	bgFrame:ClearAllPoints()
	local anchorTarget = (bd and bd:IsShown()) and bd or ((mbd and mbd:IsShown()) and mbd or list)
	if anchorTarget == list then
		bgFrame:SetPoint("TOPLEFT", list, "TOPLEFT", -4, 4)
		bgFrame:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 4, -4)
	else
		bgFrame:SetAllPoints(anchorTarget)
	end

	local baseLevel = list:GetFrameLevel() or 100
	if baseLevel < 50 then baseLevel = 50 end
	list:SetFrameLevel(baseLevel)
	bgFrame:SetFrameLevel(baseLevel)
	bgFrame:Show()

	-- 2. Hide old Blizzard NineSlice / brass textures from bd and mbd
	for _, target in ipairs({ bd, mbd }) do
		if target then
			pcall(function()
				if target.NineSlice then
					target.NineSlice:SetAlpha(0)
				end
				for _, region in ipairs({ target:GetRegions() }) do
					if region and region.SetAlpha and not region.__fp_custom then
						region:SetAlpha(0)
					end
				end
			end)
		end
	end

	-- 3. Style buttons, hover highlight, modern checkboxes, and gold arrows
	local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 32
	for i = 1, maxButtons do
		local btn = _G[name.."Button"..i]
		if btn then
			pcall(function()
				if btn.SetFrameLevel then
					btn:SetFrameLevel(baseLevel + 2)
				end

				local hl = _G[name.."Button"..i.."Highlight"]
				if hl and hl.SetTexture and hl.SetVertexColor then
					hl:SetTexture("Interface\\Buttons\\WHITE8X8")
					hl:SetVertexColor(SolaC.bgSelected[1], SolaC.bgSelected[2], SolaC.bgSelected[3], 0.90)
				end

				local txt = _G[name.."Button"..i.."NormalText"]
				if txt and txt.SetFontObject then
					txt:SetFontObject("GameFontHighlightSmall")
				end

				local arrow = _G[name.."Button"..i.."ExpandArrow"]
				if arrow then
					if arrow.SetVertexColor then
						arrow:SetVertexColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.90)
					elseif arrow.GetNormalTexture then
						local nt = arrow:GetNormalTexture()
						if nt and nt.SetVertexColor then
							nt:SetVertexColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.90)
						end
					end
				end

				local check = _G[name.."Button"..i.."Check"]
				local uncheck = _G[name.."Button"..i.."UnCheck"]

				if not btn.__fp_cbox then
					local cbox = CreateFrame("Frame", nil, btn)
					cbox:SetSize(13, 13)
					cbox:EnableMouse(false)

					local bg = cbox:CreateTexture(nil, "BACKGROUND", nil, -7)
					bg:SetAllPoints(cbox)
					cbox.bg = bg

					local function CreateCboxBorder(p1, p2, p3, p4, w, h)
						local b = cbox:CreateTexture(nil, "BORDER", nil, 6)
						b:SetPoint(p1, cbox, p2, 0, 0)
						b:SetPoint(p3, cbox, p4, 0, 0)
						if w then b:SetWidth(w) end
						if h then b:SetHeight(h) end
						return b
					end
					cbox.b_top = CreateCboxBorder("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT", nil, 1)
					cbox.b_btm = CreateCboxBorder("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 1)
					cbox.b_lft = CreateCboxBorder("TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT", 1, nil)
					cbox.b_rgt = CreateCboxBorder("TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT", 1, nil)

					local cmark = cbox:CreateTexture(nil, "ARTWORK", nil, 7)
					cmark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
					cmark:SetSize(16, 16)
					cmark:SetPoint("CENTER", cbox, "CENTER", 0, 0)
					cmark:SetVertexColor(0.35, 0.92, 0.75, 1.0)
					cbox.cmark = cmark

					local rdot = cbox:CreateTexture(nil, "ARTWORK", nil, 7)
					rdot:SetTexture("Interface\\Buttons\\WHITE8X8")
					rdot:SetSize(5, 5)
					rdot:SetPoint("CENTER", cbox, "CENTER", 0, 0)
					rdot:SetVertexColor(SolaC.gold[1] * 1.15, SolaC.gold[2] * 1.15, SolaC.gold[3] * 1.15, 1.0)
					cbox.rdot = rdot

					btn.__fp_cbox = cbox
				end

				if check then
					btn.__fp_cbox:ClearAllPoints()
					btn.__fp_cbox:SetPoint("CENTER", check, "CENTER", 0, 0)
				else
					btn.__fp_cbox:ClearAllPoints()
					btn.__fp_cbox:SetPoint("LEFT", btn, "LEFT", 3, 0)
				end
				btn.__fp_cbox:SetFrameLevel(btn:GetFrameLevel() + 3)

				if check and check.SetAlpha then
					check:SetAlpha(0)
					if not check.__fp_hooked then
						check.__fp_hooked = true
						hooksecurefunc(check, "Show", function() SolaFP_UpdateDropdownButtonCheckbox(btn) end)
						hooksecurefunc(check, "Hide", function() SolaFP_UpdateDropdownButtonCheckbox(btn) end)
					end
				end
				if uncheck and uncheck.SetAlpha then
					uncheck:SetAlpha(0)
				end

				if not btn.__fp_hover_hooked then
					btn.__fp_hover_hooked = true
					btn:HookScript("OnEnter", function(self)
						if self.__fp_cbox and self.__fp_cbox:IsShown() then
							local chk = _G[self:GetName().."Check"]
							local isChecked = (chk and chk:IsShown()) or (self.checked == true)
							if isChecked then
								SolaFP_SetDropdownCboxBorder(self.__fp_cbox, 1.0, 0.88, 0.45, 1.0)
							else
								SolaFP_SetDropdownCboxBorder(self.__fp_cbox, 0.50, 0.62, 0.68, 0.95)
							end
						end
					end)
					btn:HookScript("OnLeave", function(self)
						SolaFP_UpdateDropdownButtonCheckbox(self)
					end)
				end

				SolaFP_UpdateDropdownButtonCheckbox(btn)
			end)
		end
	end
end

local function SolaFP_SkinAllDropDowns()
	for level = 1, 3 do
		local list = _G["DropDownList"..level]
		if list and list:IsShown() then
			SolaFP_SkinDropDownList(list)
		end
	end
end

function SolaFP_HookDropDownLists()
	for level = 1, 3 do
		local list = _G["DropDownList"..level]
		if list and not list.__fp_hooked then
			list.__fp_hooked = true
			list:HookScript("OnShow", function(self)
				SolaFP_SkinDropDownList(self)
			end)
			list:HookScript("OnHide", function(self)
				SolaFP_RestoreDropDownList(self)
				if self.__fp_scaled then
					if self.SetScale then self:SetScale(1.0) end
					self.__fp_scaled = nil
				end
				if level == 1 then
					dropDownCloseTime = GetTime()
					SolaFP_DropDownCloseTime = dropDownCloseTime
				end
			end)
		end
	end
end

-------------------------------------------------
-- Auto Announce (MessageQueue Support)
-------------------------------------------------
function SolaFP_IsAnnoucing()
	return isAnnouncing
end

function SolaFP_Announce()
	if not MessageQueue then
		SolaFP_StopAnnounce()
		return
	end

	local msg = (SolaFP_MenuFrameAdText and SolaFP_MenuFrameAdText:GetText()) or SolaFP_UserDefinedAdMsg
	SolaFP_UserDefinedAdMsg = msg
	if (not msg or string.len(msg) == 0) then
		SolaFP_Print(SolaFP_MESSAGE_NO_AD_TEXT)
		SolaFP_StopAnnounce()
		return
	end

	local list = { GetChannelList() }
	local chaNum = 0
	for chan, enabled in pairs(SolaFP_Options.channel) do
		if enabled then
			local found
			for i = 1, #list do
				if i % 3 == 2 and list[i] == chan then
					chaNum = list[i-1]
					found = true
					break
				end
			end
			if found then
				MessageQueue.SendChatMessage(msg, "CHANNEL", nil, chaNum)
				found = nil
			end
		end
	end
end

function SolaFP_StartAnnounce()
	if not MessageQueue then
		SolaFP_Print(SolaFP_MESSAGE_DISABLE_ANNOUNCE)
		return
	end
	local msg = (SolaFP_MenuFrameAdText and SolaFP_MenuFrameAdText:GetText()) or SolaFP_UserDefinedAdMsg
	if not msg or string.len(msg) == 0 then
		SolaFP_Print(SolaFP_MESSAGE_NO_AD_TEXT)
		return
	end

	SolaFP_Print(SolaFP_MESSAGE_START_AD)
	isAnnouncing = true
	lastAnnouncedTime = 0

	if SolaFP_MenuFrameAnnounce then
		SolaFP_MenuFrameAnnounce:SetText(SolaFP_TEXT_STOP_AD)
		SolaFP_StyleModernButton(SolaFP_MenuFrameAnnounce, "rose", SolaFP_TEXT_STOP_AD)
	end
	SolaFP_UpdateStatusPills()

	-- Send initial announcement immediately during the current hardware click event
	SolaFP_Announce()
	if MessageQueue and MessageQueue.Run and MessageQueue.GetNumPendingMessages and MessageQueue.GetNumPendingMessages() > 0 then
		MessageQueue.Run()
	end
end

function SolaFP_StopAnnounce()
	if isAnnouncing then
		SolaFP_Print(SolaFP_MESSAGE_STOP_AD)
	end
	isAnnouncing = false
	lastAnnouncedTime = 0

	-- Clear any pending message in MessageQueue so no unwanted ad message is sent on/after stopping
	if MessageQueue and MessageQueue.Clear then
		MessageQueue.Clear()
	end

	if SolaFP_MenuFrameAnnounce then
		SolaFP_MenuFrameAnnounce:SetText(SolaFP_TEXT_START_AD)
		SolaFP_StyleModernButton(SolaFP_MenuFrameAnnounce, "teal", SolaFP_TEXT_START_AD)
	end
	SolaFP_UpdateStatusPills()
end

function SolaFP_EnableAnnounce()
	if not SolaFP_MenuFrame then return end

	-- 2-row layout (height 96px for generous spacing)
	SolaFP_MenuFrame:SetHeight(96)

	-- Row 1: Whisper & actions (top=-6, bottom=-32 aligned with Apply button)
	if SolaFP_MenuFrameWh then
		SolaFP_MenuFrameWh:ClearAllPoints()
		SolaFP_MenuFrameWh:SetPoint("TOPLEFT", SolaFP_MenuFrame, "TOPLEFT", 14, -13)
	end
	if SolaFP_MenuFrameException then
		SolaFP_MenuFrameException:ClearAllPoints()
		local yOff = -6
		if SolaFP_MenuFrameApply and SolaFP_MenuFrame and SolaFP_MenuFrameApply:GetTop() and SolaFP_MenuFrame:GetTop() then
			local calculated = SolaFP_MenuFrameApply:GetTop() - SolaFP_MenuFrame:GetTop()
			if calculated and calculated < 0 and calculated > -40 then
				yOff = calculated
			end
		end
		SolaFP_MenuFrameException:SetPoint("TOPRIGHT", SolaFP_MenuFrame, "TOPRIGHT", -20, yOff)
	end

	if SolaFP_MenuFrame and not SolaFP_MenuFrame.__fp_align_hooked then
		SolaFP_MenuFrame.__fp_align_hooked = true
		SolaFP_MenuFrame:HookScript("OnShow", function()
			if SolaFP_MenuFrameAd and SolaFP_MenuFrameAd:IsShown() and SolaFP_MenuFrameException and SolaFP_MenuFrameApply and SolaFP_MenuFrameApply:GetTop() and SolaFP_MenuFrame:GetTop() then
				local calculated = SolaFP_MenuFrameApply:GetTop() - SolaFP_MenuFrame:GetTop()
				if calculated and calculated < 0 and calculated > -40 then
					SolaFP_MenuFrameException:ClearAllPoints()
					SolaFP_MenuFrameException:SetPoint("TOPRIGHT", SolaFP_MenuFrame, "TOPRIGHT", -20, calculated)
				end
			end
		end)
	end

	-- Row separator (Y=-43: 11px padding below Row 1 bottom -32; +1px top margin)
	if not SolaFP_MenuFrame.__fp_row_sep then
		local rowSep = SolaFP_MenuFrame:CreateTexture(nil, "ARTWORK", nil, 6)
		rowSep:SetHeight(1)
		rowSep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.08)
		SolaFP_MenuFrame.__fp_row_sep = rowSep
	end
	if SolaFP_MenuFrame.__fp_row_sep then
		SolaFP_MenuFrame.__fp_row_sep:ClearAllPoints()
		SolaFP_MenuFrame.__fp_row_sep:SetPoint("TOPLEFT", 14, -43)
		SolaFP_MenuFrame.__fp_row_sep:SetPoint("TOPRIGHT", -14, -43)
		SolaFP_MenuFrame.__fp_row_sep:Show()
	end

	-- Row 2: Ad announce controls (TOP=-55: 12px gap below separator Y=-43, height=24, bottom=-79)
	-- 1) Announce Button (bottom right, TOP=-55, height=24, bottom=-79)
	if SolaFP_MenuFrameAnnounce then
		SolaFP_MenuFrameAnnounce:ClearAllPoints()
		SolaFP_MenuFrameAnnounce:SetPoint("TOPRIGHT", SolaFP_MenuFrame, "TOPRIGHT", -20, -55)
		SolaFP_MenuFrameAnnounce:SetSize(74, 24)
		if isAnnouncing then
			SolaFP_StyleModernButton(SolaFP_MenuFrameAnnounce, "rose", SolaFP_TEXT_STOP_AD)
		else
			SolaFP_StyleModernButton(SolaFP_MenuFrameAnnounce, "teal", SolaFP_TEXT_START_AD)
		end
		SolaFP_MenuFrameAnnounce:Show()
	end

	-- 2) Ad Label (left margin 14, Center Y=-67 matches Announce button center)
	if SolaFP_MenuFrameAd then
		SolaFP_MenuFrameAd:ClearAllPoints()
		SolaFP_MenuFrameAd:SetPoint("LEFT", SolaFP_MenuFrame, "TOPLEFT", 14, -67)
		SolaFP_MenuFrameAd:SetText(SolaFP_LABEL_AD or SolaFP_TEXT_AD_LABEL)
		SolaFP_MenuFrameAd:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		SolaFP_MenuFrameAd:Show()
	end

	-- 3) Ad EditBox (Explicit TOP=-55 to ensure clear gap below separator, BOTTOM=-79 matching button)
	if SolaFP_MenuFrameAdText then
		SolaFP_MenuFrameAdText:ClearAllPoints()
		SolaFP_MenuFrameAdText:SetPoint("TOPLEFT", SolaFP_MenuFrame, "TOPLEFT", 68, -55)
		SolaFP_MenuFrameAdText:SetPoint("BOTTOMRIGHT", SolaFP_MenuFrameAnnounce, "BOTTOMLEFT", -8, 0)
		SolaFP_StyleModernEditBox(SolaFP_MenuFrameAdText, "gold")
		if SolaFP_UserDefinedAdMsg then
			SolaFP_MenuFrameAdText:SetText(SolaFP_UserDefinedAdMsg)
		end
		SolaFP_MenuFrameAdText:Show()
	end

	-- Intercept MessageQueueFrame so clicking "Stop Ad" stops advertising instantly without sending queued message
	local mqf = _G["MessageQueueFrame"]
	if mqf and not mqf.__fp_stop_hooked then
		mqf.__fp_stop_hooked = true
		local origDown = mqf:GetScript("OnMouseDown")
		mqf:SetScript("OnMouseDown", function(self, btn, ...)
			if isAnnouncing then
				local overAnnounce = SolaFP_MenuFrameAnnounce and SolaFP_MenuFrameAnnounce:IsShown() and SolaFP_MenuFrameAnnounce:IsMouseOver()
				local overTitlePill = SolaFP_TitleFrameAnnouncing and SolaFP_TitleFrameAnnouncing:IsShown() and SolaFP_TitleFrameAnnouncing:IsMouseOver()
				if overAnnounce or overTitlePill then
					if MessageQueue and MessageQueue.Clear then
						MessageQueue.Clear()
					end
					SolaFP_StopAnnounce()
					return
				end
			end
			if origDown then
				origDown(self, btn, ...)
			elseif MessageQueue and MessageQueue.Run then
				MessageQueue.Run()
			end
		end)
		local origUp = mqf:GetScript("OnMouseUp")
		mqf:SetScript("OnMouseUp", function(self, btn, ...)
			if not isAnnouncing or (MessageQueue and MessageQueue.GetNumPendingMessages and MessageQueue.GetNumPendingMessages() == 0) then
				if origUp then
					origUp(self, btn, ...)
				elseif MessageQueue and MessageQueue.Run then
					MessageQueue.Run()
				end
			end
		end)
	end

	if SolaFP_TitleFrameAnnouncing then
		SolaFP_TitleFrameAnnouncing:Show()
	end

	SolaFP_UpdateStatusPills()
	SolaFP_UpdateWidthResponsiveUI()
end

function SolaFP_DisableAnnounce(silent)
	if isAnnouncing then
		SolaFP_StopAnnounce()
	end

	if SolaFP_TitleFrameAnnouncing then
		SolaFP_TitleFrameAnnouncing:Hide()
	end

	if SolaFP_MenuFrameAd then SolaFP_MenuFrameAd:Hide() end
	if SolaFP_MenuFrameAdText then SolaFP_MenuFrameAdText:Hide() end
	if SolaFP_MenuFrameAnnounce then SolaFP_MenuFrameAnnounce:Hide() end
	if SolaFP_MenuFrame.__fp_row_sep then SolaFP_MenuFrame.__fp_row_sep:Hide() end

	if SolaFP_MenuFrameWh then
		SolaFP_MenuFrameWh:ClearAllPoints()
		SolaFP_MenuFrameWh:SetPoint("LEFT", SolaFP_MenuFrame, "LEFT", 14, 0)
	end
	if SolaFP_MenuFrameException then
		SolaFP_MenuFrameException:ClearAllPoints()
		SolaFP_MenuFrameException:SetPoint("RIGHT", SolaFP_MenuFrame, "RIGHT", -20, 0)
	end

	if SolaFP_MenuFrame then
		SolaFP_MenuFrame:SetHeight(44)
	end

	if not silent then
		SolaFP_Print(SolaFP_MESSAGE_DISABLE_ANNOUNCE)
	end

	SolaFP_UpdateStatusPills()
	SolaFP_UpdateWidthResponsiveUI()
end

-------------------------------------------------
-- Close on empty space right click
-------------------------------------------------
function SolaFP_CloseOnRightClick()
	-- Do NOT close if modifier keys (Alt, Ctrl, Shift) are held
	-- This completely prevents conflicts with Alt+RightClick (whisper tell) or other shortcuts
	if IsAltKeyDown() or IsControlKeyDown() or IsShiftKeyDown() then
		return false
	end

	CloseDropDownMenus()
	if SolaFP_WhPresetFrame and SolaFP_WhPresetFrame:IsShown() then
		SolaFP_WhPresetFrame:Hide()
	end

	if SolaFP_Options and SolaFP_Options.lfgOnly then
		if SolaFP_LFGPanel and SolaFP_LFGPanel:IsShown() then
			SolaFP_LFGPanel:Hide()
			PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE or 851)
			return true
		end
	else
		if SolaFP_Frame and SolaFP_Frame:IsShown() then
			SolaFP_Frame:Hide()
			PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE or 851)
			return true
		end
	end
	return false
end

function SolaFP_MenuClicked(self, button, menu, option)
	if menu == "MENU_FILTERDUNGEON" then
		if button == "MiddleButton" then
			SolaFP_ToggleDungeonFilterView()
			return
		elseif button == "RightButton" then
			SolaFP_ClearDungeonFilter()
			return
		end
	end

	if menu == "MENU_FILTERDUNGEON" or menu == "MENU_OPTION" then
		SolaFP_HookDropDownLists()
		local anchor = self
		if not anchor or not anchor:IsShown() then
			anchor = (menu == "MENU_FILTERDUNGEON") and SolaFP_ListFrameFilterDungeon or SolaFP_TitleFrameOption
		end
		local initFunc = (menu == "MENU_FILTERDUNGEON") and SolaFP_DropDownMenuFilterDungeon_Initialize or SolaFP_DropDownMenuOption_Initialize

		local closeTime = SolaFP_DropDownCloseTime or dropDownCloseTime or 0
		local isJustClosed = (GetTime() - closeTime) < 0.20
		local isCurrentlyOpen = DropDownList1 and DropDownList1:IsShown() and (UIDROPDOWNMENU_OPEN_MENU == SolaFP_DropDownMenu)

		if isCurrentlyOpen or isJustClosed then
			CloseDropDownMenus()
			return
		end

		local targetScale = SolaFP_GetDropdownTargetScale(anchor)
		SolaFP_DropDownMenu.__fp_target_scale = targetScale
		for level = 1, 3 do
			local dl = _G["DropDownList"..level]
			if dl and dl.SetScale then
				dl:SetScale(targetScale)
				dl.__fp_scaled = true
			end
		end
		UIDropDownMenu_Initialize(SolaFP_DropDownMenu, initFunc)
		ToggleDropDownMenu(1, nil, SolaFP_DropDownMenu, anchor, 0, 0)
		SolaFP_SkinAllDropDowns()
	elseif menu == "MENU_APPLY" then
		if shouterSelected then
			SolaFP_Whisper(shouterSelected.name)
		else
			SolaFP_Print(SolaFP_MESSAGE_NOTARGET)
		end
	elseif menu == "MENU_WHISPER" then
		if shouterSelected then
			ChatFrame_SendTell(shouterSelected.name, FCF_GetCurrentChatFrame())
		else
			SolaFP_Print(SolaFP_MESSAGE_NOTARGET)
		end
	elseif menu == "MENU_WHO" then
		if shouterSelected then
			SolaFP_SendWho(shouterSelected.name)
		else
			SolaFP_Print(SolaFP_MESSAGE_NOTARGET)
		end
	elseif menu == "MENU_EXCEPTION" then
		if shouterSelected then
			SolaFP_Exception(shouterSelected.name)
		else
			SolaFP_Print(SolaFP_MESSAGE_NOTARGET)
		end
	elseif menu == "MENU_EXCEPTION_DELETE" then
		if SolaFP_MenuFrameIgnoreText then
			SolaFP_MenuFrameIgnoreText:SetText("")
		end
		SolaFP_SetCustomIgnoreText()
		exceptionData = {}
		SolaFP_Print(SolaFP_MESSAGE_IGNORE_ALL_RESET or "Reset complete.")
		SolaFP_Refresh(true)
	elseif menu == "APPLY_FILTER" then
		SolaFP_SetCustomFilterText()
		SolaFP_Print(SolaFP_MESSAGE_APPLY_CUSTOM_FILTER)
	elseif menu == "IGNORE" then
		local text = SolaFP_MenuFrameIgnoreText and SolaFP_MenuFrameIgnoreText:GetText()
		if text and text:match("%S") then
			SolaFP_SetCustomIgnoreText()
			SolaFP_Print(string.format(SolaFP_MESSAGE_APPLY_CUSTOM_IGNORE or "Filter applied: |cffCF6679%s|r", text))
			SolaFP_Refresh(true)
		else
			SolaFP_Print(SolaFP_MESSAGE_IGNORE_EMPTY or "Please enter filter text.")
		end
	elseif menu == "MENU_ACTIVATE_BELLNWINDOW" then
		if SolaFP_Options.activateBellnWindow then
			SolaFP_ActiveBellnWindow(false)
		else
			SolaFP_ActiveBellnWindow(true)
		end
	elseif menu == "MENU_ANNOUNCE" then
		if not MessageQueue then
			SolaFP_Print(SolaFP_MESSAGE_DISABLE_ANNOUNCE)
			return
		end
		if isAnnouncing then
			SolaFP_StopAnnounce()
		else
			SolaFP_StartAnnounce()
		end
	elseif menu == "MENU_ACTIVATION" then
		if SolaFP_Options.activated then
			SolaFP_Activate(false)
			SolaFP_Options.useroffed = true
		else
			SolaFP_Activate(true)
			SolaFP_Options.useroffed = false
		end
	elseif menu == "MENU_INC" then
		SolaFP_ListAdjust(INC)
	elseif menu == "MENU_DEC" then
		SolaFP_ListAdjust(DEC)
	elseif menu == "MENU_MAX" then
		SolaFP_ListAdjust(MAX)
	elseif menu == "MENU_MIN" then
		SolaFP_ListAdjust(MIN)
	elseif menu == "MENU_INFO" then
		SolaFP_ToggleHelpFrame()
	elseif menu == "SEL_SHOUT" then
		local index = self:GetID()
		local data = frameData[index]
		if not data then
			if button == "RightButton" then
				SolaFP_CloseOnRightClick()
			end
			return
		end
		if button == "LeftButton" then
			if IsAltKeyDown() then
				shouterSelected = data
				SolaFP_Whisper(shouterSelected.name)
			elseif IsShiftKeyDown() then
				shouterSelected = data
				SolaFP_SendWho(shouterSelected.name)
			elseif IsControlKeyDown() then
				shouterSelected = data
				SolaFP_Exception(shouterSelected.name)
			else
				if shouterSelected == data then
					shouterSelected = nil
				else
					shouterSelected = data
				end
			end
			SolaFP_Refresh()
		elseif button == "RightButton" then
			if IsAltKeyDown() then
				shouterSelected = data
				ChatFrame_SendTell(shouterSelected.name, FCF_GetCurrentChatFrame())
			elseif SolaFP_Options.rightButton then
				-- Ctrl + right click: whisper party leader



				if IsControlKeyDown() then
					shouterSelected = data
					SolaFP_Whisper(shouterSelected.name)
				end
			end
		end
	end
end

function SolaFP_IconClicked(self, button)
	if button == "LeftButton" then
		if IsAltKeyDown() then
			if SolaFP_Minimap_Button:IsShown() then
				SolaFP_Options.iconLocked = not SolaFP_Options.iconLocked
				if SolaFP_Options.iconLocked then
					SolaFP_Print(SolaFP_MESSAGE_ICON_LOCK)
					SolaFP_Minimap_Button:RegisterForDrag(nil)
					GameTooltip:Hide()
				else
					SolaFP_Print(SolaFP_MESSAGE_ICON_UNLOCK)
					SolaFP_Minimap_Button:RegisterForDrag("LeftButton")
					GameTooltip:Hide()
				end
			end
		elseif (IsControlKeyDown()) then
			if not MessageQueue then
				SolaFP_Print(SolaFP_MESSAGE_DISABLE_ANNOUNCE)
				return
			end
			if isAnnouncing then
				SolaFP_StopAnnounce()
			else
				SolaFP_StartAnnounce()
			end
		elseif (IsShiftKeyDown()) then
			if SolaFP_Options.activated then
				SolaFP_Activate(false)
				SolaFP_Options.useroffed = true
			else
				SolaFP_Activate(true)
				SolaFP_Options.useroffed = false
			end
		else
			SolaFP_Toggle(true)
		end
	elseif button == "RightButton" then
		SolaFP_HookDropDownLists()
		local targetScale = SolaFP_GetDropdownTargetScale(self or SolaFP_Frame)
		SolaFP_DropDownMenu.__fp_target_scale = targetScale
		for level = 1, 3 do
			local dl = _G["DropDownList"..level]
			if dl and dl.SetScale then
				dl:SetScale(targetScale)
				dl.__fp_scaled = true
			end
		end
		UIDropDownMenu_Initialize(SolaFP_DropDownMenu, SolaFP_DropDownMenuOption_Initialize)
		ToggleDropDownMenu(1, nil, SolaFP_DropDownMenu, self, 0, 0)
		SolaFP_SkinAllDropDowns()
	end
end

-----------------------------------
-- List frame functions
-----------------------------------
function SolaFP_Refresh(quick)
	local listOffset = FauxScrollFrame_GetOffset(SolaFP_ListFrameScrollFrame)
	if not listOffset then listOffset = 0 end

	if not quick then
		local sort_col = sortData.current_sort
		local ascd = sortData[sort_col]

		SolaFP_ListSort(frameData, sort_col, ascd)
	end

	local maxScroll = 0
	local rowIdx = 1

	for i = 1, #frameData do
		local info = frameData[i]
		if info then

			-- Custom filter check
			--
			-- Custom filter function




			local filtered = SolaFP_CustomFilter(info.msg)
			if (not SolaFP_DungeonFilter(info.dungeon) or not SolaFP_ExceptionFilter(info.name) or not filtered.flag) then
				if info == shouterSelected then
					shouterSelected = nil
				end
				info.enabled = false
				info.num = nil
			else
				maxScroll = maxScroll + 1
				info.enabled = true
				info.num = maxScroll
			end


			if info.enabled and info.num > listOffset and rowIdx <= SolaFP_Options.viewLines then
				local rowName = "SolaFP_ListFrameRow"..tostring(rowIdx)
				if info.time <= 0 then
					if SolaFP_Options["activateBellnWindow"] then
						PlaySoundFile("Interface\\AddOns\\SolaLFG\\SolaLFG.ogg")
						SolaFP_Frame:Show()
						info.time = 1
					end
				end
				_G[rowName]:Show()
				_G[rowName]:SetID(i)
				-- Time
				_G[rowName.."TimeText"]:SetText(info.time)

				--Message
				local msg = filtered.msg

				_G[rowName.."MsgText"]:SetText(msg)
				_G[rowName.."DungeonText"]:SetText(info.dungeon)
			
				-- Coloring
				if info.mode then
					if SolaFP_Category_Color[info.mode] then
						_G[rowName.."DungeonText"]:SetTextColor(SolaFP_Category_Color[info.mode][1], SolaFP_Category_Color[info.mode][2], SolaFP_Category_Color[info.mode][3])
						local postfix = {
							"|cffff0000 (40)",
							"|cffff0000 (20)",
							"|cffff0000 (10)",
						}
												if info.mode == "raid40" then
							_G[rowName.."DungeonText"]:SetText(info.dungeon.." |cff9B8EC4(40)|r")
						elseif info.mode == "raid20" then
							_G[rowName.."DungeonText"]:SetText(info.dungeon.." |cffCF6679(20)|r")
						elseif info.mode == "raid10" then
							_G[rowName.."DungeonText"]:SetText(info.dungeon.." |cffE09050(10)|r")
						
						end
					end
				end
				-- Name
				local name = info.name
				if info.class then
					local color = RAID_CLASS_COLORS[info.class]
					if color then
						_G[rowName.."NameText"]:SetTextColor(color.r, color.g, color.b)
					end
				else
					_G[rowName.."NameText"]:SetTextColor(1,1,1)
				end
				_G[rowName.."NameText"]:SetText(name)

				-- Modern Selection Highlight & Accent Indicator
				local row = _G[rowName]
				if not row.__fp_sel_bg then
					local selBg = row:CreateTexture(nil, "BACKGROUND")
					selBg:SetAllPoints()
					selBg:SetColorTexture(SolaC.bgSelected[1], SolaC.bgSelected[2], SolaC.bgSelected[3], 0.95)
					selBg:Hide()
					row.__fp_sel_bg = selBg

					local goldBar = row:CreateTexture(nil, "OVERLAY")
					goldBar:SetPoint("TOPLEFT", 0, 0)
					goldBar:SetPoint("BOTTOMLEFT", 0, 0)
					goldBar:SetWidth(2)
					goldBar:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.95)
					goldBar:Hide()
					row.__fp_gold_bar = goldBar
				end

				if info == shouterSelected then
					row:LockHighlight()
					row.__fp_sel_bg:Show()
					row.__fp_gold_bar:Show()
				else
					row:UnlockHighlight()
					row.__fp_sel_bg:Hide()
					row.__fp_gold_bar:Hide()
				end
				rowIdx = rowIdx + 1
			end
		end
	end
	for i = rowIdx, 28 do
		local rowName = "SolaFP_ListFrameRow"..tostring(i)
		local r = _G[rowName]
		if r then
			r:Hide()
			if r.__fp_sel_bg then r.__fp_sel_bg:Hide() end
			if r.__fp_gold_bar then r.__fp_gold_bar:Hide() end
		end
	end
	FauxScrollFrame_Update(SolaFP_ListFrameScrollFrame, maxScroll, SolaFP_Options.viewLines, 24)
end

function SolaFP_ListAdjust(adjust)
	local newNumRow = 20
	local newWidth = 750

	SolaFP_TitleFrame:SetWidth(newWidth)
	SolaFP_ListFrame:SetWidth(newWidth)
	SolaFP_MenuFrame:SetWidth(newWidth)

	local newHeight = 84 + (newNumRow * 24)
	SolaFP_ListFrame:SetHeight(newHeight)

	SolaFP_Position_Save.width = newWidth
	SolaFP_Options.viewLines = newNumRow
	SolaFP_ListMove()

	SolaFP_UpdateWidthResponsiveUI(newWidth)
	SolaFP_Refresh()
end
function SolaFP_ListMove()
	SolaFP_Position_Save.point, _, SolaFP_Position_Save.relpoint, SolaFP_Position_Save.x, SolaFP_Position_Save.y = SolaFP_ListFrame:GetPoint()
end

local fp_in_ui_resize = false
function SolaFP_UIResize(scale)
	if fp_in_ui_resize then return end
	fp_in_ui_resize = true

	local sc = tonumber(scale) or 1.0
	sc = math.floor(sc * 20 + 0.5) / 20
	if SolaFP_Options then
		SolaFP_Options.scale = sc
	end

	if SolaFP_Frame and SolaFP_Frame.SetScale then
		SolaFP_Frame:SetScale(sc)
	end

	if SolaFP_LFGPanel and SolaFP_LFGPanel.SetScale then
		if SolaFP_Options and SolaFP_Options.lfgOnly then
			SolaFP_LFGPanel:SetScale(sc)
		else
			SolaFP_LFGPanel:SetScale(1.0)
		end
	end

	if SolaFP_LFG_FilterDrawer and SolaFP_LFG_FilterDrawer:IsShown() and SolaFP_LFG_AnchorDrawer then
		SolaFP_LFG_AnchorDrawer()
	end

	-- Synchronize both sliders
	if SolaFP_ScaleSlider and SolaFP_ScaleSlider.SetValue then
		if math.abs((SolaFP_ScaleSlider:GetValue() or 0) - sc) > 0.01 then
			SolaFP_ScaleSlider:SetValue(sc)
		end
		if SolaFP_ScaleSlider.__fp_label and SolaFP_ScaleSlider.__fp_label.SetText then
			local pct = math.floor(sc * 100 + 0.5)
			SolaFP_ScaleSlider.__fp_label:SetText(string.format("UI |cffD4A745%d%%|r", pct))
		end
		if SolaFP_ScaleSlider.__fp_fill and SolaFP_ScaleSlider.__fp_fill.SetWidth then
			local ratio = (sc - 0.5) / 1.5
			if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
			local w = SolaFP_ScaleSlider:GetWidth()
			if w and w > 0 then
				SolaFP_ScaleSlider.__fp_fill:SetWidth(math.max(1, w * ratio))
			end
		end
	end
	if SolaFP_LFG_ScaleSlider and SolaFP_LFG_ScaleSlider.SetValue then
		if math.abs((SolaFP_LFG_ScaleSlider:GetValue() or 0) - sc) > 0.01 then
			SolaFP_LFG_ScaleSlider:SetValue(sc)
		end
		if SolaFP_LFG_ScaleSlider.__fp_label and SolaFP_LFG_ScaleSlider.__fp_label.SetText then
			local pct = math.floor(sc * 100 + 0.5)
			SolaFP_LFG_ScaleSlider.__fp_label:SetText(string.format("UI |cffD4A745%d%%|r", pct))
		end
		if SolaFP_LFG_ScaleSlider.__fp_fill and SolaFP_LFG_ScaleSlider.__fp_fill.SetWidth then
			local ratio = (sc - 0.5) / 1.5
			if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
			local w = SolaFP_LFG_ScaleSlider:GetWidth()
			if w and w > 0 then
				SolaFP_LFG_ScaleSlider.__fp_fill:SetWidth(math.max(1, w * ratio))
			end
		end
	end

	fp_in_ui_resize = false
end

function SolaFP_FontResize()
	for i = 1, 28 do
		local rowName = "SolaFP_ListFrameRow"..i
		for j = 1, 3 do
			local tempFrame = _G[rowName..colFrame[j]]
			local fontFile, unused, fontFlags = tempFrame:GetFont()
			tempFrame:SetFont(fontFile, SolaFP_Options.fontsize, fontFlags)
		end
	end
end

function SolaFP_SetListColor()
	if SolaFP_TitleFrame then
		SolaFP_TitleFrame:SetBackdropColor(SolaC.bgSidebar[1], SolaC.bgSidebar[2], SolaC.bgSidebar[3], SolaC.bgSidebar[4])
		SolaFP_TitleFrame:SetBackdropBorderColor(0, 0, 0, 0.70)
	end
	if SolaFP_ListFrame then
		SolaFP_ListFrame:SetBackdropColor(SolaC.bgMain[1], SolaC.bgMain[2], SolaC.bgMain[3], SolaC.bgMain[4])
		SolaFP_ListFrame:SetBackdropBorderColor(0, 0, 0, 0.70)
	end
	if SolaFP_MenuFrame then
		SolaFP_MenuFrame:SetBackdropColor(SolaC.bgSidebar[1], SolaC.bgSidebar[2], SolaC.bgSidebar[3], SolaC.bgSidebar[4])
		SolaFP_MenuFrame:SetBackdropBorderColor(0, 0, 0, 0.70)
	end
end

function SolaFP_SetListPosition()
	if SolaFP_Position_Save.x and SolaFP_Position_Save.y and SolaFP_Position_Save.width and SolaFP_Options.viewLines then
		local w = math.max(SolaFP_MIN_WIDTH, math.min(SolaFP_MAX_WIDTH, SolaFP_Position_Save.width))
		SolaFP_ListFrame:ClearAllPoints()
		SolaFP_TitleFrame:SetWidth(w)
		SolaFP_ListFrame:SetWidth(w)
		SolaFP_MenuFrame:SetWidth(w)
		SolaFP_ListFrame:SetPoint(SolaFP_Position_Save.point, UIParent, SolaFP_Position_Save.relpoint, SolaFP_Position_Save.x, SolaFP_Position_Save.y)
		SolaFP_ListFrame:SetHeight(84 + (SolaFP_Options.viewLines * 24))
		SolaFP_UpdateWidthResponsiveUI(w)
	else
		SolaFP_ListAdjust()
	end
end

-------------------------
-- Settings menu handlers
-------------------------
local function getChannel()
	table.wipe(SolaFP_Option_Menu[1]["value"])
	local list = { GetChannelList() }
	for i = 1, #list do
		if i % 3 == 2 then
			table.insert(SolaFP_Option_Menu[1]["value"], list[i])
		end
	end
end

local function setChannel(self, channel)
	if SolaFP_Options["channel"][channel] then
		SolaFP_Options["channel"][channel] = nil
	else
		SolaFP_Options["channel"][channel] = true
	end
	-- Update chat channels
	local list = { GetChannelList() }
	for channelname, _ in pairs(SolaFP_Options["channel"]) do
		local isValidChannel = false
		for i = 1, #list do
			if i % 3 == 2 and list[i] == channelname then
				isValidChannel = true
				break
			end
		end
		if not isValidChannel then
			SolaFP_Options["channel"][channelname] = nil
		end
	end
end

local function setOption(self, option, number)
	if not option or not number then return end
	SolaFP_Options[option] = number

	-- Apply size and font options
	if option == "scale" then
		SolaFP_UIResize(SolaFP_Options.scale)
		if SolaFP_ScaleSlider then
			SolaFP_ScaleSlider:SetValue(tonumber(SolaFP_Options.scale) or 1.0)
		end
	elseif option == "fontsize" then
		SolaFP_FontResize()
	end

	-- Sync the submenu's radio state from the saved option. Compare against the
	-- configured values rather than the dropdown button's transient value,
	-- which can be cleared/reused by the legacy dropdown implementation.
	if UIDROPDOWNMENU_MENU_LEVEL == 2 then
		for _, tbl in ipairs(SolaFP_Option_Menu) do
			if tbl.dbname == option then
				for i = 1, #(tbl.value or {}) do
					local button = _G["DropDownList2Button"..i]
					local check = _G["DropDownList2Button"..i.."Check"]
					local selected = tonumber(SolaFP_Options[option]) == tonumber(tbl.value[i])
					if button and check and selected then
						check:Show()
					elseif button and check then
						check:Hide()
					end
				end
			end
		end
	end
end

local function setWindowColor(previousValues)
	if (not previousValues) then
		SolaFP_Options.color.r, SolaFP_Options.color.g, SolaFP_Options.color.b = ColorPickerFrame:GetColorRGB()
		SolaFP_Options.color.opacity = OpacitySliderFrame:GetValue()
	else
		SolaFP_Options.color=previousValues
	end

	SolaFP_SetListColor()
end

function SolaFP_SetSpecialFrame(value)
	SolaFP_Options.esc = value
	if SolaFP_Options.esc then
		SolaFP_EnsureSpecialFrame()
	else
		for i = #UISpecialFrames, 1, -1 do
			if (UISpecialFrames[i] == "SolaFP_Frame") then
				table.remove(UISpecialFrames, i)
			end
		end
	end
end

function SolaFP_Minimap_ButtonToggle(value)
	SolaFP_Options.icon = value
	if SolaFP_Options.icon then
		SolaFP_Minimap_Button:Show()
	else
		SolaFP_Minimap_Button:Hide()
	end
end

function SolaFP_LoadDefaultWinPos()
	SolaFP_Position_Save = {
		["point"] = "CENTER",
		["relpoint"] = "CENTER",
		["x"] = 0,
		["y"] = 0,
		["width"] = SolaFP_Position_Save.width or 750
	}
	SolaFP_Options.viewLines = SolaFP_Options.viewLines or 20
	SolaFP_SetListPosition()
end

function SolaFP_LoadDefaultWinSize()
	SolaFP_Position_Save = {
		["point"] = SolaFP_Position_Save.point or "CENTER",
		["relpoint"] = SolaFP_Position_Save.relpoint or "CENTER",
		["x"] = SolaFP_Position_Save.x or 0,
		["y"] = SolaFP_Position_Save.y or 0,
		["width"] = 750
	}
	SolaFP_Options.viewLines = 20
	SolaFP_Options.scale = 1
	SolaFP_UIResize(SolaFP_Options.scale)
	if SolaFP_ScaleSlider then
		SolaFP_ScaleSlider:SetValue(1.0)
	end
	SolaFP_SetListPosition()
end

function SolaFP_LoadDefaultOption()
	SolaFP_Print(SolaFP_MESSAGE_RESETALL)

	SolaFP_Options = {}
	for k,v in pairs(SolaFP_Default_Options) do
		SolaFP_Options[k] = v
	end
	SolaFP_Options.channel = {}
	for k,v in pairs(SolaFP_Default_Options.channel) do
		SolaFP_Options.channel[k] = v
	end
	SolaFP_Options.color = {}
	for k,v in pairs(SolaFP_Default_Options.color) do
		SolaFP_Options.color[k] = v
	end

	SolaFP_Filter_Dungeon = {}

	SolaFP_Position_Save = {
		["point"] = "CENTER",
		["relpoint"] = "CENTER",
		["x"] = 0,
		["y"] = 0,
		["width"] = 750
	}
	SolaFP_Minimap_Save = {
		ButtonRadius = 78,
		ButtonShown = true,
		ButtonPosition = 336,
		Angle = 0
	}
	if (SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) ~= "koKR" then
		SolaFP_Options.lfgOnly = true
		SolaFP_Options.viewModeSelected = true
	end

	SolaFP_Minimap_Button_UpdatePosition()
	SolaFP_UIResize(SolaFP_Options.scale)
	SolaFP_SetListPosition()

	SolaFP_Frame:Hide()
end

function SolaFP_DropDownMenuOption_Initialize(frame, level, menu)
	level = level or 1
	local info
	if (level == 1) then
		local lastWasSep = false
		for _, tbl in ipairs(SolaFP_Option_Menu) do
			local skip = false
			if (SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) ~= "koKR" then
				local db = tbl.dbname
				if db == "channel" or db == "interval" or db == "valid" or db == "fontsize"
				   or db == "rightButton" or db == "lfgOnly" or db == "noraid" or db == "nopvp" then
					skip = true
				end
			end

			if not skip then
				local isSep = (tbl.name == "")
				if not (isSep and lastWasSep) then
					lastWasSep = isSep
					info = UIDropDownMenu_CreateInfo()
					info.text = tbl.name
					info.keepShownOnClick = true
					info.disabled = tbl.name == ""
					info.hasArrow = type(tbl.value) == "table"
					info.notCheckable = type(tbl.exec) ~= "function"
					info.func = tbl.exec or nil
					info.checked = SolaFP_Options[tbl.dbname] or false
					info.isNotRadio = true
					info.menuList = tbl.dbname
					info.value = tbl.value or nil
					if tbl.dbname == "color" then
						info.keepShownOnClick = false
						info.hasColorSwatch = true
						info.hasOpacity = true
						info.r = SolaFP_Options.color.r
						info.g = SolaFP_Options.color.g
						info.b = SolaFP_Options.color.b
						info.opacity = SolaFP_Options.color.opacity
						info.func = UIDropDownMenuButton_OpenColorPicker
						info.swatchFunc = setWindowColor
						info.opacityFunc = setWindowColor
						info.cancelFunc = setWindowColor
					end
					if tbl.dbname == "close" then
						info.keepShownOnClick = false
						info.func = nil
					end
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end
	end

	if (level == 2) then
		if menu == "channel" then
			getChannel()
			info = UIDropDownMenu_CreateInfo()
			info.keepShownOnClick = true
			for i = 1, #UIDROPDOWNMENU_MENU_VALUE do
				info.text = UIDROPDOWNMENU_MENU_VALUE[i]
				info.checked = SolaFP_Options[menu][info.text]
				info.isNotRadio = true
				info.arg1 = info.text
				info.func = setChannel
				UIDropDownMenu_AddButton(info, level)
			end
		elseif menu == "interval" or menu == "valid" or menu == "fontsize" or menu == "scale" then
			info = UIDropDownMenu_CreateInfo()
			info.keepShownOnClick = true
			-- These are single-choice settings, so render them as radio items.
			info.isNotRadio = false
			for i = 1, #UIDROPDOWNMENU_MENU_VALUE do
				info.text = UIDROPDOWNMENU_MENU_VALUE[i]
				info.checked = tonumber(info.text) == tonumber(SolaFP_Options[menu])
				info.arg1 = menu
				info.arg2 = tonumber(info.text)
				info.value = tonumber(info.text)
				info.func = setOption
				UIDropDownMenu_AddButton(info, level)
			end
		elseif menu == "reset" then
			info = UIDropDownMenu_CreateInfo()
			info.notCheckable = true
			info.keepShownOnClick = false
			for _, tbl in ipairs(UIDROPDOWNMENU_MENU_VALUE) do
				info.text = tbl.name
				info.func = tbl.exec
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end
end

----------------------
-- Helpers and utilities
----------------------
local function SolaFP_IsSecretString(val)
	if val == nil then return false end
	if issecretvalue and issecretvalue(val) then return true end
	if type(val) ~= "string" then return true end
	local ok, _ = pcall(string.lower, val)
	return not ok
end

local function SolaFP_FindDataByName(targetName)
	if not targetName or SolaFP_IsSecretString(targetName) then return nil, nil end
	for i = 1, #frameData do
		local item = frameData[i]
		if item and item.name == targetName then
			return item, i
		end
	end
	return nil, nil
end

function SolaFP_AddList(name, rawmsg, class)
	if not name or not rawmsg then return end
	if SolaFP_IsSecretString(name) or SolaFP_IsSecretString(rawmsg) then return end
	if class and SolaFP_IsSecretString(class) then class = nil end

	local msg
	local t = GetTime()
	local existing, existingIdx = SolaFP_FindDataByName(name)

	-- See if sender already exists in our frameData
	if existing then
		if (t - (existing.fullscan or 0)) < 90 then
			if rawmsg == existing.rawmsg then
				existing.time = 0
				return
			else
				msg = SolaFP_FilterIgnoreText(rawmsg, SolaFP_TOOLTIP_IGNORE_KEYWORDS, true)
				msg = removeQuestieLink(msg)
				if existing.dungeon_keyword and string.find(string.lower(msg), string.lower(existing.dungeon_keyword), 1, true) then
					existing.msg = msg
					existing.rawmsg = rawmsg
					existing.time = 0
					SolaFP_Refresh(true)
					return
				end
			end
		end
	end

	-- Dungeon Parse
	local dungeon, color, dungeon_keyword = SolaFP_DungeonParse(rawmsg)

	if dungeon then
		msg = SolaFP_FilterIgnoreText(rawmsg, SolaFP_TOOLTIP_IGNORE_KEYWORDS, true)
		msg = removeQuestieLink(msg)

		if existing then
			existing.dungeon = dungeon
			existing.dungeon_keyword = dungeon_keyword
			existing.msg = msg
			existing.rawmsg = rawmsg
			existing.time = 0
			existing.mode = color
			existing.fullscan = t
		else
			local info = {}
			info.name = name
			info.class = class
			info.msg = msg
			info.rawmsg = rawmsg
			info.dungeon = dungeon
			info.dungeon_keyword = dungeon_keyword
			info.mode = color
			info.time = 0
			info.fullscan = t
			info.enabled = nil
			info.num = nil
			table.insert(frameData, info)
		end

		SolaFP_Refresh()
	end
end

function SolaFP_RemoveList(name)
	if not name or SolaFP_IsSecretString(name) then return end
	if shouterSelected and shouterSelected.name == name then
		shouterSelected = nil
	end

	local _, idx = SolaFP_FindDataByName(name)
	if idx then
		table.remove(frameData, idx)
		SolaFP_Refresh()
	end
end

function SolaFP_RemoveAllList()
	frameData = {}
	shouterSelected = nil
	if not (SolaFP_Options and SolaFP_Options.lfgOnly) then
		SolaFP_Refresh()
	end
end

function SolaFP_Print(msg)
	if msg and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00SolaLFG: |cffffff00"..tostring(msg)) end
end

function SolaFP_Nprint(msg)
	if msg and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(tostring(msg)) end
end

function SolaFP_OnLoad()
	SolaFP_InviteControlFrame:RegisterEvent("VARIABLES_LOADED")
	SolaFP_InviteControlFrame:RegisterEvent("CHAT_MSG_CHANNEL")
	SolaFP_InviteControlFrame:RegisterEvent("CHAT_MSG_SYSTEM")
	SolaFP_InviteControlFrame:RegisterEvent("WHO_LIST_UPDATE")
	SolaFP_InviteControlFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	SolaFP_InviteControlFrame:RegisterEvent("ZONE_CHANGED")
	SolaFP_InviteControlFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
	SolaFP_InviteControlFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end

function SolaFP_OnEvent(self, event, ...)
		if event == "PLAYER_LEVEL_UP" then
		if SolaFP_WhAutoLevel then
			SolaFP_RefreshAutoWhMsg()
		end
		return
	end

	if event == "VARIABLES_LOADED" then
		SolaFP_InviteControlFrame:UnregisterEvent("VARIABLES_LOADED")
		SolaFP_Init()
		return
	end

	-- Handle auto-deactivation events
	if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
		if SolaFP_Options and (SolaFP_Options.noraid or SolaFP_Options.nopvp) then
			SolaFP_AutoDeactivate()
		end
		return
	end

	-- Ignore events if disabled or in LFG-only mode
	if not SolaFP_Options or not SolaFP_Options.activated then return end
	if SolaFP_Options.lfgOnly then return end

	if event == "CHAT_MSG_CHANNEL" then
		local arg1, arg2, _, _, _, _, _, _, arg9, _, _, arg12 = ...

		if not arg1 or not arg2 or not arg9 then return end

		-- Discard restricted secret strings immediately to prevent taint / crash
		if SolaFP_IsSecretString(arg1) or SolaFP_IsSecretString(arg2) or SolaFP_IsSecretString(arg9) then
			return
		end

		-- Filter out excluded messages
		if exceptionData then
			for _, v in pairs(exceptionData) do
				if arg1 == v or arg2 == v then
					return
				end
			end
		end

		-- remove zone suffix
		local isZoneChannel = string.find(arg9, " - ")
		if isZoneChannel then
			arg9 = string.sub(arg9, 1, isZoneChannel - 1)
		end

		-- now pass to SolaFP_AddList()
		if SolaFP_Options.channel and SolaFP_Options.channel[arg9] then
			local name = Ambiguate(arg2, "none")
			local class = nil
			if arg12 and not SolaFP_IsSecretString(arg12) then
				local ok, _, c = pcall(GetPlayerInfoByGUID, arg12)
				if ok then class = c end
			end
			SolaFP_AddList(name, arg1, class)
		end
	end
end

function SolaFP_OnUpdate(self, elapsed)
	-- 자동 광고 기능 (MessageQueue 설치 시, 애드온 탐색 활성화 여부와 무관하게 동작)
	if isAnnouncing then
		lastAnnouncedTime = lastAnnouncedTime + elapsed
		local interval = (SolaFP_Options and SolaFP_Options.interval) or 30
		if lastAnnouncedTime >= interval then
			SolaFP_Announce()
			lastAnnouncedTime = 0
		end
	end
	-- Stop update if disabled or in LFG-only mode
	if not SolaFP_Options or not SolaFP_Options.activated then return end
	if SolaFP_Options.lfgOnly then return end
	lastUpdatedTime = lastUpdatedTime + elapsed
	if lastUpdatedTime > SolaFP_UPDATE_INTERVAL and #frameData > 0 then
		local i = 1
		while i <= #frameData do
			frameData[i].time = frameData[i].time + SolaFP_UPDATE_INTERVAL

			if frameData[i].time > SolaFP_Options.valid then
				SolaFP_RemoveList(frameData[i].name)
			elseif frameData[i].ignored then
				SolaFP_RemoveList(frameData[i].name)
			else
				i = i + 1
			end

		end
		lastUpdatedTime = 0

		SolaFP_Refresh(true)
	end
end

------------------------
-- Window toggle
------------------------
function SolaFP_Toggle(isUserClick)
	if isUserClick == nil then isUserClick = true end
	if SolaFP_Options and SolaFP_Options.lfgOnly then
		if not SolaFP_LFGPanel and SolaFP_LFG_Init then
			SolaFP_LFG_Init()
		end
		if SolaFP_ApplyLFGOnlyMode then
			SolaFP_ApplyLFGOnlyMode()
		end
		if SolaFP_LFGPanel then
			if SolaFP_LFGPanel:IsShown() then
				SolaFP_LFGPanel:Hide()
			else
				SolaFP_LFGPanel:Show()
				if SolaFP_LFGPanel.Layout then
					SolaFP_LFGPanel:Layout()
				end
				if isUserClick and SolaFP_LFG_OnUserOpen then
					SolaFP_LFG_OnUserOpen()
				end
			end
		end
	else
		if SolaFP_Frame:IsShown() then
			SolaFP_Frame:Hide()
		else
			SolaFP_Frame:Show()
			if isUserClick and SolaFP_LFG_OnUserOpen then
				SolaFP_LFG_OnUserOpen()
			end
		end
	end
end

------------------------
-- Slash commands
------------------------
SLASH_SOLALFG1 = "/sola"
SLASH_SOLALFG2 = "/SOLA"
SLASH_SOLALFG3 = "/sl"
SLASH_SOLALFG4 = "/SL"
SLASH_SOLALFG5 = "/solalfg"
SLASH_SOLALFG6 = "/SOLALFG"
SLASH_SOLALFG7 = "/니"
SLASH_SOLALFG8 = "/솔라"

local function SolaLFG_SlashCmd(msg)
	local cmd = msg and string.lower(string.trim and string.trim(msg) or msg:match("^%s*(.-)%s*$") or "")
	local curLocale = (SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale())

	if cmd == "card" or cmd == "카드" then
		if curLocale == "koKR" and SolaFP_OpenCardChoiceFrame then
			SolaFP_OpenCardChoiceFrame()
		end
		return
	elseif cmd == "update" or cmd == "udt" or cmd == "업데이트" or cmd == "notice" or cmd == "공지" then
		if SolaFP_ShowUpdatePopup then
			SolaFP_ShowUpdatePopup(true)
		end
		return
	elseif cmd == "test" or cmd == "테스트" then
		if SolaFP_Options then
			if curLocale == "koKR" then
				SolaFP_Options.viewModeSelected = false
			else
				SolaFP_Options.viewModeSelected = true
				SolaFP_Options.lfgOnly = true
			end
			SolaFP_Options.lastShownUpdateNotice = nil
		end
		if curLocale == "koKR" and SolaFP_OpenCardChoiceFrame then
			SolaFP_OpenCardChoiceFrame()
		end
		if SolaFP_ShowUpdatePopup then
			SolaFP_ShowUpdatePopup(true)
		end
		return
	end
	SolaFP_Toggle()
end
_G.SolaLFG_SlashCmd = SolaLFG_SlashCmd

SlashCmdList["SOLALFG"] = SolaLFG_SlashCmd

-- Publish only the SolaLFG frame so FindParty can own its own frame names.
_G.SolaLFG = SolaFP_Frame

-----------------------------------
-- Reload UI shorthand
-----------------------------------
SLASH_RELOADUI_KR1 = "/\234\184\176"
SLASH_RELOADUI_KR2 = "/rl"
SlashCmdList["RELOADUI_KR"] = function()
	ReloadUI()
end

-----------------------------------
-- Chat Player Link Alt+Click Invite
-----------------------------------
function SolaFP_InviteFromChatLink(link)
	if not IsAltKeyDown() or type(link) ~= "string" then return end
	local linkType, targetPlayer = strsplit(":", link)
	if linkType ~= "player" or not targetPlayer or targetPlayer == "" then return end

	local sendInvite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
	if sendInvite then
		sendInvite(targetPlayer)
	end

	local activeChatBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
	if activeChatBox then
		activeChatBox:Hide()
	end
end

if hooksecurefunc then
	hooksecurefunc("SetItemRef", SolaFP_InviteFromChatLink)
end



