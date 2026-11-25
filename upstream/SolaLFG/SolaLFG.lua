-- Version is read from TOC metadata
-- Increment Revision to reset options in FP_Init
local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
FP_DISPLAY_VERSION = (getMeta and (getMeta("SolaLFG", "version") or getMeta("FindParty", "version"))) or "1.0"
FP_Revision = 20

----------------------
-- Core variables
----------------------
FP_Version = 1
FP_Options = nil
FP_Filter_Dungeon = {}
FP_UserDefinedWhMsg = nil
FP_UserDefineFilterMsg = ""
FP_UserDefineIgnoreMsg = ""

FP_Minimap_Save = {
	ButtonRadius = 78,
	ButtonShown = true,
	ButtonPosition = 336,
	Angle = 0
}

FP_Position_Save = {
	["point"] = nil,
	["relpoint"] = nil,
	["x"] = nil,
	["y"] = nil,
	["width"] = nil
}

FP_Backdrop_Info = {
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
	if FP_Filter_Dungeon then
		for _, tbl in pairs(FP_Filter_Dungeon) do
			for _, _ in pairs(tbl) do
				num = num + 1
			end
		end
	end
	return num
end
FP_GetDungeonFilterNum = getDungeonFilterNum
local frameData = {}
local exceptionData = {}
local custom_ignore_keywords = {}
local colName = {"time", "dungeon", "name", "msg"}
local colFrame = {"DungeonText", "NameText", "MsgText"}

local FP_UPDATE_INTERVAL = 2
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

local FP_Option_Menu = {
	[1] = {
		name = FP_OPTIONS_CHANNEL,
		dbname = "channel",
		value = {},
	},
	[2] = {
		name = FP_OPTIONS_INTERVAL,
		dbname = "interval",
		value = {"30","45","60","90","120","300"},
	},
	[3] = {
		name = FP_OPTIONS_VALID,
		dbname = "valid",
		value = {"60","90","120","180","240","300"},
	},
	[4] = {
		name = "",
	},
	[5] = {
		name = FP_OPTIONS_FONTSIZE,
		dbname = "fontsize",
		value = {"12","13","14","15","16","17","18"},
	},
	[6] = {
		name = FP_L["Window Scale"] or FP_OPTIONS_SCALE or "창 크기",
		dbname = "scale",
		value = {"2","1.9","1.8","1.7","1.6","1.5","1.4","1.3","1.2","1.1","1","0.9","0.8","0.7","0.6","0.5"},
	},
	[7] = {
		name = FP_L["Window Color"] or FP_OPTIONS_COLOR or "창 색상",
		dbname = "color",
	},
	[8] = {
		name = "",
	},
	[9] = {
		name = FP_L["Minimap Icon"] or FP_OPTIONS_ICON or "미니맵 아이콘 보기",
		dbname = "icon",
		exec = function(self) FP_Minimap_ButtonToggle(self.checked) end,
	},
	[10] = {
		name = FP_L["Close with ESC"] or FP_OPTIONS_ESC or "ESC로 창 닫기",
		dbname = "esc",
		exec = function(self) FP_SetSpecialFrame(self.checked) end,
	},
	[11] = {
		name = FP_OPTIONS_RIGHTBUTTON,
		dbname = "rightButton",
		exec = function(self) FP_Options.rightButton = self.checked end,
	},
	[12] = {
		name = FP_OPTIONS_LFG_ONLY or "기본 파티 탐색기만 표시",
		dbname = "lfgOnly",
		exec = function(self)
			local chk = self.checked
			if C_Timer and C_Timer.After then
				C_Timer.After(0, function()
					if FP_SetLFGOnlyMode then
						FP_SetLFGOnlyMode(chk)
					else
						FP_Options.lfgOnly = chk
					end
				end)
			else
				if FP_SetLFGOnlyMode then
					FP_SetLFGOnlyMode(chk)
				else
					FP_Options.lfgOnly = chk
				end
			end
		end,
	},
	[13] = {
		name = "",
	},
	[14] = {
		name = FP_OPTIONS_NORAID,
		dbname = "noraid",
		exec = function(self) FP_Options.noraid = self.checked end,
	},
	[15] = {
		name = FP_OPTIONS_NOPVP,
		dbname = "nopvp",
		exec = function(self) FP_Options.nopvp = self.checked end,
	},
	[16] = {
		name = "",
	},
	[17] = {
		name = FP_L["Reset"] or FP_OPTIONS_RESET or "설정 초기화",
		dbname = "reset",
		value = {
			[1] = {
				name = FP_L["Reset Window Position"] or FP_OPTIONS_RESETPOS or "창 위치",
				exec = function() FP_LoadDefaultWinPos() end,
			},
			[2] = {
				name = FP_L["Reset Window Size"] or FP_OPTIONS_RESETSIZE or "창 크기",
				exec = function() FP_LoadDefaultWinSize() end,
			},
			[3] = {
				name = FP_L["Reset All Settings"] or FP_OPTIONS_RESETALL or "모든 설정 초기화",
				exec = function() FP_LoadDefaultOption() end,
			},
		},
	},
	[18] = {
		name = FP_L["View Update Notes"] or "업데이트 안내 보기",
		exec = function()
			if FP_ShowUpdatePopup then FP_ShowUpdatePopup(true) end
		end,
	},
	[19] = {
		name = FP_L["Close"] or FP_TEXT_CLOSE or "닫기",
		dbname = "close",
		exec = "",
	},
}

local FP_Default_Options= {
	["channel"] = {
		[FP_DEFAULT_PARTY_CHANNEL] = true,
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

local FP_Category_Color = {
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
CreateFrame("Button", "FP_Minimap_Button", Minimap)

FP_Minimap_Button:EnableMouse(true)
FP_Minimap_Button:SetMovable(false)
FP_Minimap_Button:SetFrameStrata("MEDIUM")
FP_Minimap_Button:SetWidth(33)
FP_Minimap_Button:SetHeight(33)
FP_Minimap_Button:SetPoint("TOPLEFT", Minimap, "LEFT", 2, 0)
FP_Minimap_Button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

FP_Minimap_Button:CreateTexture("FP_Minimap_ButtonIcon", "BORDER")
FP_Minimap_ButtonIcon:SetWidth(20)
FP_Minimap_ButtonIcon:SetHeight(20)
FP_Minimap_ButtonIcon:SetPoint("CENTER", -2, 1)
FP_Minimap_ButtonIcon:SetTexture("Interface\\AddOns\\SolaLFG\\SIM-Icon") --INV_Misc_Bag_10_Blue

FP_Minimap_Button:CreateTexture("FP_Minimap_ButtonBorder", "OVERLAY")
FP_Minimap_ButtonBorder:SetWidth(52)
FP_Minimap_ButtonBorder:SetHeight(52)
FP_Minimap_ButtonBorder:SetPoint("TOPLEFT")
FP_Minimap_ButtonBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

function FP_Minimap_Button_Init()
	FP_Minimap_Save.ButtonRadius = FP_Minimap_Save.ButtonRadius or 78
	FP_Minimap_Save.ButtonPosition = FP_Minimap_Save.ButtonPosition or 345
	FP_Minimap_Button_UpdatePosition()
	FP_Minimap_Button:UnregisterEvent("VARIABLES_LOADED")
end

function FP_Minimap_Button_UpdatePosition()
	FP_Minimap_Button:ClearAllPoints()
	FP_Minimap_Button:SetSize(33, 33)
	if FP_Minimap_ButtonIcon then
		FP_Minimap_ButtonIcon:SetSize(20, 20)
	end
	FP_Minimap_Button:SetPoint(
		"TOPLEFT",
		"Minimap",
		"TOPLEFT",
		54 - (FP_Minimap_Save.ButtonRadius * cos(FP_Minimap_Save.ButtonPosition)),
		(FP_Minimap_Save.ButtonRadius * sin(FP_Minimap_Save.ButtonPosition)) - 55
	)
end

-- Thanks to Yatlas for this code
function FP_Minimap_Button_BeingDragged()
	-- Thanks to Gello for this code
	local xpos,ypos = GetCursorPosition()
	local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom()

	xpos = xmin-xpos/UIParent:GetScale()+70
	ypos = ypos/UIParent:GetScale()-ymin-70

	local v = math.deg(math.atan2(ypos, xpos))
	if v < 0 then
		v = v + 360
	end
	FP_Minimap_Save.ButtonPosition = v
	FP_Minimap_Button_UpdatePosition()

end

FP_Minimap_Button:RegisterEvent("VARIABLES_LOADED")
FP_Minimap_Button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
FP_Minimap_Button:RegisterForDrag("LeftButton")
FP_Minimap_Button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", FP_Minimap_Button_BeingDragged) end)
FP_Minimap_Button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
FP_Minimap_Button:SetScript("OnClick", function(self, button)
	if FP_IconClicked then
		FP_IconClicked(self, button)
	end
end)
local function FP_ShowMinimapTooltip(tooltip, owner, anchor)
	if owner and anchor then
		tooltip:SetOwner(owner, anchor)
	end
	tooltip:ClearLines()

	local verStr = FP_DISPLAY_VERSION or (FP_GetVersionString and FP_GetVersionString()) or "1.0"
	local authorStr = ((FP_GetLocale and FP_GetLocale() or GetLocale()) == "koKR") and "Sola-아즈샤라" or "Sola"
	tooltip:SetText("|cffD4A745SolaLFG [" .. verStr .. "]|r |cff8A8580/|r |cff5ABFB0" .. authorStr .. "|r")

	tooltip:AddDoubleLine("|cffD4A745" .. (FP_L["Left-Click"] or "왼쪽 클릭") .. "|r", "|cffffffff" .. (FP_L["Toggle Party Finder"] or "파티 찾기 도우미 열기") .. "|r")
	tooltip:AddDoubleLine("|cffD4A745" .. (FP_L["Right-Click"] or "오른쪽 클릭") .. "|r", "|cffffffff" .. (FP_L["Settings"] or "설정") .. "|r")
	tooltip:AddDoubleLine("|cffD4A745" .. (FP_L["Alt + Click"] or "Alt + 클릭") .. "|r", "|cffffffff" .. (FP_L["Lock / Unlock Icon"] or "아이콘 고정 / 해제") .. "|r")
	tooltip:AddDoubleLine("|cffD4A745" .. (FP_L["Shift + Left-Click"] or "Shift + 좌클릭") .. "|r", "|cffffffff" .. (FP_L["Enable / Disable Addon"] or "애드온 작동 / 작동정지") .. "|r")

	tooltip:AddLine(" ")

	local actText = (FP_Options and FP_Options.activated) and ("|cff6BBF8A" .. (FP_L["Active"] or "작동중") .. "|r") or ("|cffCF6679" .. (FP_L["Inactive"] or "작동정지") .. "|r")
	local lockText = (FP_Options and FP_Options.iconLocked) and ("|cff8A8580" .. (FP_L["Locked"] or "고정됨") .. "|r") or ("|cffE09050" .. (FP_L["Movable (Drag)"] or "이동가능 (좌클릭 드래그)") .. "|r")
	tooltip:AddDoubleLine("|cff8A8580" .. (FP_L["Addon Status"] or "애드온 상태") .. "|r", actText)
	tooltip:AddDoubleLine("|cff8A8580" .. (FP_L["Icon Position"] or "아이콘 위치") .. "|r", lockText)

	tooltip:Show()
end

FP_Minimap_Button:SetScript("OnEnter", function(self)
	FP_ShowMinimapTooltip(GameTooltip, self, "ANCHOR_LEFT")
end)
FP_Minimap_Button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
FP_Minimap_Button:SetScript("OnEvent", FP_Minimap_Button_Init)

----------------
-- LibDataBroker feed
----------------
local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
if ldb then
	ldb:NewDataObject("SolaLFG", {
		type = "launcher",
		text = FP_C_TITLE,
		icon = "Interface\\AddOns\\SolaLFG\\SIM-Icon",
		OnClick = function(self, button)
			if FP_IconClicked then
				FP_IconClicked(self, button)
			end
		end,
		OnTooltipShow = function(tooltip)
			if FP_ShowMinimapTooltip then
				FP_ShowMinimapTooltip(tooltip)
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

function FP_ToggleHelpFrame()
	if fp_helpFrame and fp_helpFrame:IsShown() then
		fp_helpFrame:Hide()
		return
	end

	if not fp_helpFrame then
		local f = CreateFrame("Frame", "FP_HelpFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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
		tinsert(UISpecialFrames, "FP_HelpFrame")

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
		title:SetText("SolaLFG - " .. (FP_TEXT_HELP or "Help"))
		title:SetTextColor(0.831, 0.655, 0.271)
		title:SetFont(title:GetFont(), 13)

		-- Version
		local ver = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		ver:SetPoint("TOPRIGHT", -14, -14)
		ver:SetText("v" .. (FP_DISPLAY_VERSION or (FP_GetVersionString and FP_GetVersionString()) or "1.0"))
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
		local sf = CreateFrame("ScrollFrame", "FP_HelpScrollFrame", f, "UIPanelScrollFrameTemplate")
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
		local sb = _G["FP_HelpScrollFrameScrollBar"]
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
			local upBtn = _G["FP_HelpScrollFrameScrollBarScrollUpButton"]
			local downBtn = _G["FP_HelpScrollFrameScrollBarScrollDownButton"]
			if upBtn then upBtn:Hide(); upBtn:SetAlpha(0) end
			if downBtn then downBtn:Hide(); downBtn:SetAlpha(0) end
		end

		-- Build help content
		local helpLines = FP_HELP_DATA or {}

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

FP_Tooltip = {
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
			FP_Tooltip.DEFAULT(text, _G[self:GetName().."Name"], "ANCHOR_TOPLEFT", 0, 0)
		end
	end,
	["SORTTIME"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_SORT_TIME, self, "ANCHOR_TOPRIGHT")
	end,
	["FILTERDUNGEON"] = function(self)
		local msg = FP_TOOLTIP_DUNGEON_FILTER or ""
		local stateHeader = ""
		if getDungeonFilterNum() > 0 then
			if isDungeonFiltering then
				stateHeader = "|cff6BBF8A[" .. (FP_L and FP_L["Filtering Interested Dungeons"] or "관심 던전 필터 적용 중") .. "]|r\n\n"
			else
				stateHeader = "|cffE0C068[" .. (FP_L and FP_L["Viewing All Dungeons (Paused)"] or "모두 보기 (관심 던전 필터 일시 해제)") .. "]|r\n\n"
			end
		end
		local desc = FP_GetDungeonFilterList()
		if desc and desc ~= "" then
			msg = stateHeader .. msg .. desc
		end
		FP_Tooltip.DEFAULT(msg, self, "ANCHOR_TOPRIGHT")
	end,
	["CLOSE"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_CLOSE, self, "ANCHOR_TOPRIGHT")
	end,
	["MAXMIZE"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_MAXMIZE, self, "ANCHOR_TOPRIGHT")
	end,
	["MINIMIZE"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_MINIMIZE, self, "ANCHOR_TOPRIGHT")
	end,
	["DECREASE"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_DECREASE, self, "ANCHOR_TOPRIGHT")
	end,
	["INCREASE"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_INCREASE, self, "ANCHOR_TOPRIGHT")
	end,
	["OPTION"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_OPTION, self, "ANCHOR_TOPRIGHT")
	end,
	["ANNOUNCE"] = function(self)
		local msg
		if FP_IsAnnoucing and FP_IsAnnoucing() then
			msg = FP_TOOLTIP_AD_ON
		else
			msg = FP_TOOLTIP_AD_OFF
		end
		FP_Tooltip.DEFAULT(msg, self, "ANCHOR_TOPRIGHT")
	end,
	["ACTIVATE"] = function(self)
		local msg
		if FP_Options.activated then
			msg = FP_TOOLTIP_ACTIVATE_ON
		else
			msg = FP_TOOLTIP_ACTIVATE_OFF
		end
		FP_Tooltip.DEFAULT(msg, self, "ANCHOR_TOPRIGHT")
	end,
	["ACTIVATEBELLNWINDOW"] = function(self)
		local msg
		if FP_Options.activateBellnWindow then
			msg = FP_TOOLTIP_POPUP_ON
		else
			msg = FP_TOOLTIP_POPUP_OFF
		end
		FP_Tooltip.DEFAULT(msg, self, "ANCHOR_TOPRIGHT")
	end,
	["APPLYBINDING"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_SHORTCUT_ALT, self, "ANCHOR_TOPRIGHT")
	end,
	["EXCEPTIONBINDING"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_SHORTCUT_CTRL, self, "ANCHOR_TOPRIGHT")
	end,
	["WHOBINDING"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_SHORTCUT_SHIFT, self, "ANCHOR_TOPRIGHT")
	end,
	["WHISPERBINDING"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_SHORTCUT_ALT_RIGHT, self, "ANCHOR_TOPRIGHT")
	end,
	["IGNORE"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_IGNORE, self, "ANCHOR_TOPRIGHT")
	end,
	["DISABLED"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_DISABLED, self, "ANCHOR_TOPRIGHT")
	end,
}

-------------------
-- Addon initialization
-------------------

-------------------------------------------------
-- Modern Translucent Dark Glass Theme
-------------------------------------------------
local SolaC = {
	bgMain     = { 0.078, 0.071, 0.067, 0.88 },
	bgSidebar  = { 0.050, 0.047, 0.043, 0.94 },
	bgSelected = { 0.165, 0.153, 0.145, 0.95 },
	bgInput    = { 0.098, 0.090, 0.086, 0.98 },
	bgHover    = { 0.130, 0.122, 0.114, 0.75 },
	bgBtn      = { 0.220, 0.210, 0.200, 0.88 },

	fgMain     = { 0.941, 0.929, 0.910 },
	fgDim      = { 0.541, 0.522, 0.502 },
	fgDisabled = { 0.480, 0.460, 0.440 },

	gold       = { 0.831, 0.655, 0.271 },
	goldBeige  = { 0.825, 0.725, 0.485 },
	goldMuted  = { 0.623, 0.491, 0.203 },
	teal       = { 0.353, 0.749, 0.690 },
	mint       = { 0.420, 0.749, 0.541 },
	rose       = { 0.812, 0.400, 0.475 },
	amber      = { 0.878, 0.565, 0.314 },
	lavender   = { 0.608, 0.557, 0.769 },

	rimLight   = { 1.0, 1.0, 1.0, 0.08 },
	glassLine  = { 1.0, 1.0, 1.0, 0.06 },
	borderDark = { 0.0, 0.0, 0.0, 0.70 },
}

FP_SolaC = SolaC

function FP_EnsureSpecialFrame()
	if FP_Options and FP_Options.esc == false then return end
	for i = 1, #UISpecialFrames do
		if UISpecialFrames[i] == "FP_Frame" then
			return
		end
	end
	tinsert(UISpecialFrames, "FP_Frame")
end

-------------------------------------------------
-- Window Width Limits & Responsive UI Support
-------------------------------------------------
-- Window width limits and responsive breakpoints
local FP_MIN_WIDTH = 535
local FP_MAX_WIDTH = 992
local FP_COLLAPSE_WIDTH = 616
local FP_COLLAPSE_WIDTH_EARLY = 633
local FP_COLLAPSE_WIDTH_SLIDER = 608

local function FP_UpdateWidthResponsiveUI(width)
	local curWidth = width
	if not curWidth then
		if FP_Position_Save and FP_Position_Save.width then
			curWidth = FP_Position_Save.width
		elseif FP_ListFrame and FP_ListFrame.GetWidth then
			curWidth = FP_ListFrame:GetWidth()
		end
	end
	curWidth = curWidth or 750

	-- Dynamically detect the rightmost edge of visible left-side title bar buttons
	-- (KeyBind -> Activation [감지] -> ActivateBellnWindow [팝업] -> Announcing [광고])
	local leftPillRight = 0
	if FP_TitleFrame and FP_TitleFrame.GetLeft and FP_TitleFrame:GetLeft() then
		local tfLeft = FP_TitleFrame:GetLeft()
		if FP_TitleFrameAnnouncing and FP_TitleFrameAnnouncing:IsShown() and FP_TitleFrameAnnouncing.GetRight and FP_TitleFrameAnnouncing:GetRight() then
			local r = FP_TitleFrameAnnouncing:GetRight() - tfLeft
			if r > 200 and r < 600 then
				leftPillRight = r
			end
		elseif FP_TitleFrameActivateBellnWindow and FP_TitleFrameActivateBellnWindow:IsShown() and FP_TitleFrameActivateBellnWindow.GetRight and FP_TitleFrameActivateBellnWindow:GetRight() then
			local r = FP_TitleFrameActivateBellnWindow:GetRight() - tfLeft
			if r > 200 and r < 500 then
				leftPillRight = r
			end
		elseif FP_TitleFrameActivation and FP_TitleFrameActivation:IsShown() and FP_TitleFrameActivation.GetRight and FP_TitleFrameActivation:GetRight() then
			local r = FP_TitleFrameActivation:GetRight() - tfLeft
			if r > 150 and r < 400 then
				leftPillRight = r
			end
		end
	end

	-- Safe fallbacks if frames have not been laid out by the renderer yet
	if leftPillRight <= 0 then
		if FP_TitleFrameAnnouncing and FP_TitleFrameAnnouncing:IsShown() then
			leftPillRight = 405
		elseif FP_TitleFrameActivateBellnWindow and FP_TitleFrameActivateBellnWindow:IsShown() then
			leftPillRight = 324
		elseif FP_TitleFrameActivation and FP_TitleFrameActivation:IsShown() then
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

	local hideElements = (curWidth < FP_COLLAPSE_WIDTH)
	local hideEarlyElements = (curWidth < FP_COLLAPSE_WIDTH_EARLY)
	local hideSlider = (curWidth < sliderCollapseWidth)
	local hideHelp = (curWidth < helpCollapseWidth)

	-- Scale slider (leftmost right-side element: hides FIRST as "UI" text approaches Ad button)
	if FP_ScaleSlider then
		if hideSlider then
			FP_ScaleSlider:Hide()
			if FP_ScaleSlider.__fp_label then
				FP_ScaleSlider.__fp_label:Hide()
			end
		else
			FP_ScaleSlider:ClearAllPoints()
			if FP_MenuFrameInfo then
				FP_ScaleSlider:SetPoint("RIGHT", FP_MenuFrameInfo, "LEFT", -12, 0)
			elseif FP_TitleFrameOption then
				FP_ScaleSlider:SetPoint("RIGHT", FP_TitleFrameOption, "LEFT", -12, 0)
			end
			FP_ScaleSlider:Show()
			if FP_ScaleSlider.__fp_label then
				FP_ScaleSlider.__fp_label:Show()
			end
		end
	end

	-- Help button (positioned to the right of slider: stays visible down to ~553px and hides SECOND)
	if FP_MenuFrameInfo then
		if hideHelp then
			FP_MenuFrameInfo:Hide()
		else
			FP_MenuFrameInfo:Show()
		end
	end

	-- Whisper button
	if FP_MenuFrameWhisper then
		if hideElements then
			FP_MenuFrameWhisper:Hide()
		else
			FP_MenuFrameWhisper:Show()
		end
	end

	-- Who button
	if FP_MenuFrameWho then
		if hideElements then
			FP_MenuFrameWho:Hide()
		else
			FP_MenuFrameWho:Show()
		end
	end

	-- Exclude filter button
	if FP_MenuFrameIgnoreButton then
		if hideEarlyElements then
			FP_MenuFrameIgnoreButton:Hide()
		else
			FP_MenuFrameIgnoreButton:Show()
		end
	end

	-- Reset exclusions button
	if FP_MenuFrameExceptionDelete then
		if hideEarlyElements then
			FP_MenuFrameExceptionDelete:Hide()
		else
			FP_MenuFrameExceptionDelete:Show()
		end
	end

	-- LFG toggle button
	if FP_ListFrameLFGBtn then
		FP_ListFrameLFGBtn:Show()
	end
end

function FP_OnFrameShow(self)
	FP_EnsureSpecialFrame()
	if not self.__fp_whHideHooked then
		self.__fp_whHideHooked = true
		self:HookScript("OnHide", function()
			if FP_WhPresetFrame and FP_WhPresetFrame:IsShown() then
				FP_WhPresetFrame:Hide()
			end
		end)
	end
	if FP_Options and FP_Options.lfgOnly then
		self:Hide()
		if FP_LFGPanel then
			FP_LFGPanel:Show()
		elseif FP_LFG_Init then
			FP_LFG_Init()
			if FP_LFGPanel then FP_LFGPanel:Show() end
		end
		return
	end
	if FP_WhAutoLevel then
		FP_RefreshAutoWhMsg()
	end
	FP_UpdateWidthResponsiveUI()
	if FP_UpdateKeyBindingButton then FP_UpdateKeyBindingButton() end
	if FP_LFG_OnFrameShow then
		FP_LFG_OnFrameShow()
	end
end

function FP_StyleModernButton(btn, colorKey, customText)
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
		r, g, b = 0.12, 0.11, 0.10
	end
	btn._r, btn._g, btn._b = r, g, b

	btn:SetBackdrop(FP_Backdrop_Info)
	btn:SetBackdropColor(r, g, b, 0.88)
	btn:SetBackdropBorderColor(0, 0, 0, 0.65)

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

function FP_StyleModernEditBox(eb, focusKey)
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

	eb:SetBackdrop(FP_Backdrop_Info)
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

function FP_StyleCloseButton(btn)
	if not btn then return end
	btn:SetSize(22, 22)
	if BackdropTemplateMixin and not btn.SetBackdrop then
		Mixin(btn, BackdropTemplateMixin)
		btn:OnBackdropLoaded()
	end
	btn:SetBackdrop(FP_Backdrop_Info)
	btn:SetBackdropColor(1, 1, 1, 0.04)
	btn:SetBackdropBorderColor(0, 0, 0, 0.65)
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

_G.FP_StyleModernButton = FP_StyleModernButton
_G.FP_StyleCloseButton = FP_StyleCloseButton
_G.FP_StyleModernEditBox = FP_StyleModernEditBox
_G.FP_SolaC = SolaC

function FP_UpdateStatusPills()
	if FP_TitleFrameActivation then
		local btn = FP_TitleFrameActivation
		if BackdropTemplateMixin and not btn.SetBackdrop then
			Mixin(btn, BackdropTemplateMixin)
			btn:OnBackdropLoaded()
		end
		btn:SetBackdrop(FP_Backdrop_Info)
		if FP_Options and FP_Options.activated then
			btn._r, btn._g, btn._b = 0.22, 0.42, 0.32
			btn:SetBackdropColor(0.22, 0.42, 0.32, 0.88)
			btn:SetBackdropBorderColor(0, 0, 0, 0.65)
			btn:SetText(FP_BADGE_DETECT_ON or "감지 ON")
		else
			btn._r, btn._g, btn._b = 0.48, 0.22, 0.26
			btn:SetBackdropColor(0.48, 0.22, 0.26, 0.88)
			btn:SetBackdropBorderColor(0, 0, 0, 0.65)
			btn:SetText(FP_BADGE_DETECT_OFF or "감지 OFF")
		end
	end

	if FP_TitleFrameActivateBellnWindow then
		local btn = FP_TitleFrameActivateBellnWindow
		btn:SetWidth(72)
		if BackdropTemplateMixin and not btn.SetBackdrop then
			Mixin(btn, BackdropTemplateMixin)
			btn:OnBackdropLoaded()
		end
		btn:SetBackdrop(FP_Backdrop_Info)
		if FP_Options and FP_Options.activateBellnWindow then
			btn._r, btn._g, btn._b = 0.46, 0.36, 0.26
			btn:SetBackdropColor(0.46, 0.36, 0.26, 0.88)
			btn:SetBackdropBorderColor(0, 0, 0, 0.65)
			btn:SetText(FP_BADGE_SOUND_ON or "팝업 ON")
		else
			btn._r, btn._g, btn._b = 0.16, 0.15, 0.14
			btn:SetBackdropColor(0.16, 0.15, 0.14, 0.85)
			btn:SetBackdropBorderColor(0, 0, 0, 0.65)
			btn:SetText(FP_BADGE_SOUND_OFF or "팝업 OFF")
		end
	end

	if FP_TitleFrameAnnouncing then
		local btn = FP_TitleFrameAnnouncing
		btn:SetWidth(72)
		if BackdropTemplateMixin and not btn.SetBackdrop then
			Mixin(btn, BackdropTemplateMixin)
			btn:OnBackdropLoaded()
		end
		btn:SetBackdrop(FP_Backdrop_Info)
		if isAnnouncing then
			btn._r, btn._g, btn._b = 0.22, 0.42, 0.32
			btn:SetBackdropColor(0.22, 0.42, 0.32, 0.88)
			btn:SetBackdropBorderColor(0, 0, 0, 0.65)
			btn:SetText(FP_BADGE_AD_ON or "광고 ON")
		else
			btn._r, btn._g, btn._b = 0.16, 0.15, 0.14
			btn:SetBackdropColor(0.16, 0.15, 0.14, 0.85)
			btn:SetBackdropBorderColor(0, 0, 0, 0.65)
			btn:SetText(FP_BADGE_AD_OFF or "광고 OFF")
		end
	end
end

-------------------------------------------------
-- Keybinding toggle dialog
-------------------------------------------------
local keyBindDialog = nil

function FP_FormatBindingKey(key)
	if not key or key == "" then return nil end
	local s = key
	s = s:gsub("CTRL%-", "Ctrl+")
	s = s:gsub("ALT%-", "Alt+")
	s = s:gsub("SHIFT%-", "Shift+")
	s = s:gsub("BUTTON", "M")
	s = s:gsub("NUMPAD", "Num")
	return s
end

function FP_OpenKeyBindDialog(anchorBtn)
	if InCombatLockdown() then
		DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (FP_L["Cannot change key bindings while in combat."] or "전투 중에는 단축키를 변경할 수 없습니다."))
		return
	end

	if keyBindDialog and keyBindDialog:IsShown() then
		keyBindDialog:Hide()
		return
	end

	if not keyBindDialog then
		local d = CreateFrame("Frame", "FP_KeyBindDialog", UIParent, "BackdropTemplate")
		d:SetSize(270, 130)
		d:SetFrameStrata("DIALOG")
		d:SetBackdrop(FP_Backdrop_Info)
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
		title:SetText("|cffD4A745" .. (FP_L["SolaLFG Key Binding"] or "SolaLFG 열기 단축키 지정") .. "|r")

		local closeBtn = CreateFrame("Button", nil, d, "BackdropTemplate")
		closeBtn:SetSize(20, 20)
		closeBtn:SetPoint("TOPRIGHT", -6, -6)
		FP_StyleCloseButton(closeBtn)
		closeBtn:SetScript("OnClick", function()
			d:Hide()
		end)

		local info = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		info:SetPoint("TOP", 0, -33)
		info:SetText(FP_L["Press a key (or key combination) to bind."] or "지정할 키(또는 조합키)를 누르세요.")
		info:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])

		local box = CreateFrame("Frame", nil, d, "BackdropTemplate")
		box:SetSize(230, 32)
		box:SetPoint("TOP", 0, -52)
		box:SetBackdrop(FP_Backdrop_Info)
		box:SetBackdropColor(0.06, 0.05, 0.05, 0.95)
		box:SetBackdropBorderColor(SolaC.teal[1] * 0.6, SolaC.teal[2] * 0.6, SolaC.teal[3] * 0.6, 0.85)

		local keyText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
		keyText:SetPoint("CENTER", 0, 0)
		keyText:SetText("|cff35BFB0[ " .. (FP_L["Waiting for key press..."] or "키 입력 대기 중...") .. " ]|r")
		d.keyText = keyText
		d.box = box

		local footer = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		footer:SetPoint("BOTTOM", 0, 10)
		footer:SetText("|cff8A8580" .. (FP_L["ESC: Cancel  ·  Right-Click button to unbind"] or "ESC: 취소  ·  단축키 해제는 버튼 우클릭") .. "|r")

		local function ProcessKey(rawKey)
			if InCombatLockdown() then
				DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (FP_L["Cannot change key bindings while in combat."] or "전투 중에는 단축키를 변경할 수 없습니다."))
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
				keyText:SetText(string.format("|cffE09050%s[%s]|r", prefix, FP_L["Waiting for key"] or "키 입력 대기"))
				return
			end

			local prefix = ""
			if IsAltKeyDown() then prefix = prefix .. "ALT-" end
			if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
			if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
			local combo = prefix .. rawKey

			local oldAction = GetBindingAction(combo)
			local k1, k2 = GetBindingKey("FP_TOGGLE")
			if k1 then SetBinding(k1, nil) end
			if k2 then SetBinding(k2, nil) end

			SetBinding(combo, "FP_TOGGLE")
			SaveBindings(GetCurrentBindingSet())
			FP_UpdateKeyBindingButton()

			local formatted = FP_FormatBindingKey(combo)
			if oldAction and oldAction ~= "" and oldAction ~= "FP_TOGGLE" then
				DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffD4A745[SolaLFG]|r " .. (FP_L["Key bound to [|cff66FF99%s|r]. (Replaced '%s')"] or "단축키가 [|cff66FF99%s|r](으)로 설정되었습니다. (기존 '%s' 기능 대체)"), formatted, oldAction))
			else
				DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffD4A745[SolaLFG]|r " .. (FP_L["Key bound to [|cff66FF99%s|r]."] or "단축키가 [|cff66FF99%s|r](으)로 설정되었습니다."), formatted))
			end

			PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK or 856)
			d:Hide()
		end

		d:SetScript("OnKeyDown", function(self, key)
			ProcessKey(key)
		end)

		d:SetScript("OnKeyUp", function(self, key)
			if not IsAltKeyDown() and not IsControlKeyDown() and not IsShiftKeyDown() then
				keyText:SetText("|cff35BFB0[ " .. (FP_L["Waiting for key press..."] or "키 입력 대기 중...") .. " ]|r")
			else
				local prefix = ""
				if IsAltKeyDown() then prefix = prefix .. "Alt+" end
				if IsControlKeyDown() then prefix = prefix .. "Ctrl+" end
				if IsShiftKeyDown() then prefix = prefix .. "Shift+" end
				keyText:SetText(string.format("|cffE09050%s[%s]|r", prefix, FP_L["Waiting for key"] or "키 입력 대기"))
			end
		end)

		d:RegisterEvent("PLAYER_REGEN_DISABLED")
		d:SetScript("OnEvent", function(self, event)
			if event == "PLAYER_REGEN_DISABLED" and self:IsShown() then
				self:Hide()
				DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (FP_L["Key binding cancelled because combat started."] or "전투가 시작되어 단축키 설정을 취소했습니다."))
			end
		end)

		keyBindDialog = d
	end

	local anchor = anchorBtn
	if not anchor or not anchor:IsShown() then
		if FP_Options and FP_Options.lfgOnly and FP_LFG_KeyBindBtn and FP_LFG_KeyBindBtn:IsShown() then
			anchor = FP_LFG_KeyBindBtn
		elseif FP_TitleFrameKeyBind and FP_TitleFrameKeyBind:IsShown() then
			anchor = FP_TitleFrameKeyBind
		end
	end

	local sc = tonumber(FP_Options and FP_Options.scale) or 1.0
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

	keyBindDialog.keyText:SetText("|cff35BFB0[ " .. (FP_L["Waiting for key press..."] or "키 입력 대기 중...") .. " ]|r")
	keyBindDialog:Show()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
end

function FP_UpdateKeyBindingButton()
	local k1, k2 = GetBindingKey("FP_TOGGLE")
	local activeKey = k1 or k2
	local hasKey = (activeKey and activeKey ~= "")
	local formatted = hasKey and FP_FormatBindingKey(activeKey) or nil

	local function updateSingleBtn(btn, isTitleBar)
		if not btn then return end
		if hasKey then
			btn:SetText(string.format("|cffffffff%s|r", formatted))
			btn._hasKey = true
		else
			btn:SetText("|cffFFE29A" .. (FP_L["Keybind"] or "단축키") .. "|r")
			btn._hasKey = false
		end
		local textW = btn.text and btn.text:GetStringWidth() or 34
		btn:SetWidth(math.max(50, math.floor(textW + 14)))
		if isTitleBar and FP_TitleFrameActivation and FP_TitleFrameActivation.ClearAllPoints then
			FP_TitleFrameActivation:ClearAllPoints()
			FP_TitleFrameActivation:SetPoint("LEFT", btn, "RIGHT", 8, 0)
		end
	end

	if FP_TitleFrameKeyBind then
		updateSingleBtn(FP_TitleFrameKeyBind, true)
	end
	if FP_LFG_KeyBindBtn then
		updateSingleBtn(FP_LFG_KeyBindBtn, false)
	end
end

function FP_StyleAndHookKeyBindButton(btn)
	if not btn then return end

	if BackdropTemplateMixin and not btn.SetBackdrop then
		Mixin(btn, BackdropTemplateMixin)
		btn:OnBackdropLoaded()
	end
	btn:SetBackdrop(FP_Backdrop_Info)

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
			FP_UpdateKeyBindingButton()
		end
	end)

	btn:SetScript("OnShow", function(self)
		if FP_UpdateKeyBindingButton then
			FP_UpdateKeyBindingButton()
		end
	end)

	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:SetScript("OnEnter", function(self)
		self:SetBackdropColor(self._bgR * 1.45, self._bgG * 1.45, self._bgB * 1.45, 0.98)
		self:SetBackdropBorderColor(1.0, 0.88, 0.50, 1.0)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(FP_L["SolaLFG Toggle Hotkey"] or "SolaLFG 열기 단축키", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		local k1, k2 = GetBindingKey("FP_TOGGLE")
		if k1 or k2 then
			local keyStr = FP_FormatBindingKey(k1 or k2)
			GameTooltip:AddLine(string.format(FP_L["Current Key: |cff66FF99%s|r"] or "현재 단축키: |cff66FF99%s|r", keyStr), 0.94, 0.93, 0.91)
			GameTooltip:AddLine(FP_L["Saved in WoW Key Bindings to instantly open and close the window."] or "와우 단축키 설정(Bindings)에 저장되어 창을 바로 열고 닫을 수 있습니다.", 0.7, 0.7, 0.7, true)
			GameTooltip:AddLine("|cff66FF99" .. (FP_L["Left-Click"] or "좌클릭") .. "|r: " .. (FP_L["Change Keybind"] or "단축키 변경"), SolaC.goldBeige[1], SolaC.goldBeige[2], SolaC.goldBeige[3])
			GameTooltip:AddLine("|cffFF6666" .. (FP_L["Right-Click"] or "우클릭") .. "|r: " .. (FP_L["Unbind"] or "단축키 해제"), SolaC.rose[1], SolaC.rose[2], SolaC.rose[3])
		else
			GameTooltip:AddLine(FP_L["No hotkey currently bound."] or "현재 설정된 단축키가 없습니다.", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
			GameTooltip:AddLine(FP_L["Click to set a hotkey to quickly open/close SolaLFG."] or "클릭하여 SolaLFG 창을 바로 여는 단축키를 지정할 수 있습니다.", 0.7, 0.7, 0.7, true)
			GameTooltip:AddLine("|cff66FF99" .. (FP_L["Left-Click"] or "좌클릭") .. "|r: " .. (FP_L["Set Keybind"] or "단축키 지정"), SolaC.goldBeige[1], SolaC.goldBeige[2], SolaC.goldBeige[3])
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
			DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (FP_L["Cannot change key bindings while in combat."] or "전투 중에는 단축키를 변경할 수 없습니다."))
			return
		end
		if button == "RightButton" then
			local k1, k2 = GetBindingKey("FP_TOGGLE")
			if k1 or k2 then
				if k1 then SetBinding(k1, nil) end
				if k2 then SetBinding(k2, nil) end
				SaveBindings(GetCurrentBindingSet())
				FP_UpdateKeyBindingButton()
				DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (FP_L["Hotkey has been unbound."] or "열기 단축키가 해제되었습니다."))
				PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
			end
		else
			FP_OpenKeyBindDialog(self)
		end
	end)
end

function FP_CreateKeyBindingButton()
	if FP_TitleFrameKeyBind or not FP_TitleFrame or not FP_TitleFrameText then return end

	local btn = CreateFrame("Button", "FP_TitleFrameKeyBind", FP_TitleFrame, "BackdropTemplate")
	btn:SetSize(50, 22)
	btn:SetPoint("LEFT", FP_TitleFrameText, "RIGHT", 10, 0)
	if FP_TitleFrameActivation and FP_TitleFrameActivation.ClearAllPoints then
		FP_TitleFrameActivation:ClearAllPoints()
		FP_TitleFrameActivation:SetPoint("LEFT", btn, "RIGHT", 8, 0)
	end

	FP_StyleAndHookKeyBindButton(btn)
	FP_UpdateKeyBindingButton()
end

function FP_CreateScaleSlider()
	if FP_ScaleSlider or not FP_TitleFrame or not FP_MenuFrameInfo then return end

	local slider = CreateFrame("Slider", "FP_ScaleSlider", FP_TitleFrame)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(80, 8)
	slider:SetPoint("RIGHT", FP_MenuFrameInfo, "LEFT", -12, 0)
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
	local sLabel = FP_TitleFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
		GameTooltip:SetText(FP_L["Window Scale (UI Scale)"] or "창 크기 조절 (UI Scale)", 1, 0.82, 0)
		GameTooltip:AddLine(FP_L["Drag the slider to adjust SolaLFG scale (50% ~ 200%)."] or "슬라이더를 드래그하여 SolaLFG 창 크기를 조절합니다. (50% ~ 200%)", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", function() GameTooltip:Hide() end)

	slider:SetScript("OnMouseUp", function(self)
		local val = self:GetValue()
		val = math.floor(val * 20 + 0.5) / 20
		FP_Options.scale = val
		FP_UIResize(val)
	end)

	slider:SetScript("OnValueChanged", function(self, val)
		val = math.floor(val * 20 + 0.5) / 20
		FP_Options.scale = val
		UpdateScaleLabel(val)
		UpdateScaleFill(val)
		if not IsMouseButtonDown("LeftButton") then
			FP_UIResize(val)
		end
	end)

	slider:SetScript("OnSizeChanged", function(self)
		UpdateScaleFill(self:GetValue())
	end)

	local curScale = tonumber(FP_Options and FP_Options.scale) or 1.0
	slider:SetValue(curScale)
	UpdateScaleLabel(curScale)
	UpdateScaleFill(curScale)

	FP_TitleFrame:HookScript("OnShow", function()
		local sc = tonumber(FP_Options and FP_Options.scale) or 1.0
		slider:SetValue(sc)
		UpdateScaleLabel(sc)
		UpdateScaleFill(sc)
		FP_UpdateWidthResponsiveUI()
	end)
	FP_UpdateWidthResponsiveUI()
end

-------------------------------------------------
-- Mouse Wheel Scrolling Support
-------------------------------------------------
local function FP_OnListMouseWheel(self, delta)
	local scrollFrame = FP_ListFrameScrollFrame
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
			FP_Refresh(true)
		end
	end
end

local function FP_SetupMouseWheel()
	if FP_ListFrameScrollFrame then
		FP_ListFrameScrollFrame:EnableMouseWheel(true)
		FP_ListFrameScrollFrame:SetScript("OnMouseWheel", FP_OnListMouseWheel)
	end
	if FP_ListFrame then
		FP_ListFrame:EnableMouseWheel(true)
		FP_ListFrame:SetScript("OnMouseWheel", FP_OnListMouseWheel)
	end
	for i = 1, 28 do
		local row = _G["FP_ListFrameRow" .. i]
		if row then
			row:EnableMouseWheel(true)
			row:SetScript("OnMouseWheel", FP_OnListMouseWheel)
			local parts = { "Time", "Dungeon", "Name", "Msg" }
			for j = 1, #parts do
				local child = _G["FP_ListFrameRow" .. i .. parts[j]]
				if child and child.EnableMouseWheel then
					child:EnableMouseWheel(true)
					child:SetScript("OnMouseWheel", FP_OnListMouseWheel)
				end
			end
		end
	end
end

-------------------------------------------------
-- Window Resize (Width & Height) Support
-------------------------------------------------
local FP_ResizeWatcher = CreateFrame("Frame", "FP_ResizeWatcher", UIParent)
FP_ResizeWatcher:Hide()

local resizeActive = false
local resizeMode = "corner"
local resizeStartX = 0
local resizeStartY = 0
local resizeStartWidth = 750
local resizeStartLines = 20

local function FP_StartResize(mode)
	if resizeActive then return end
	if not FP_ListFrame then return end

	local top = FP_ListFrame:GetTop()
	local left = FP_ListFrame:GetLeft()
	if not top or not left then return end

	resizeActive = true
	resizeMode = mode or "corner"

	local cursorX, cursorY = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	resizeStartX = cursorX / scale
	resizeStartY = cursorY / scale

	local curW = FP_Position_Save.width or FP_ListFrame:GetWidth() or 750
	resizeStartWidth = math.max(FP_MIN_WIDTH, math.min(FP_MAX_WIDTH, curW))
	resizeStartLines = FP_Options.viewLines or 20

	-- Anchor top-left during resize to prevent shifting
	FP_ListFrame:ClearAllPoints()
	FP_ListFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)

	FP_ResizeWatcher:Show()
end

local function FP_StopResize()
	if not resizeActive then return end
	resizeActive = false
	FP_ResizeWatcher:Hide()

	FP_ListMove()
	if FP_Position_Save then
		FP_Position_Save.width = FP_ListFrame:GetWidth()
		FP_Position_Save.viewLines = FP_Options.viewLines
	end
	FP_UpdateWidthResponsiveUI(FP_Position_Save and FP_Position_Save.width)
	FP_Refresh()
end

FP_ResizeWatcher:SetScript("OnUpdate", function(self)
	if not resizeActive then
		self:Hide()
		return
	end
	if not IsMouseButtonDown("LeftButton") then
		FP_StopResize()
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
		newWidth = math.max(FP_MIN_WIDTH, math.min(FP_MAX_WIDTH, newWidth))

		local curWidth = FP_ListFrame:GetWidth()
		if curWidth ~= newWidth then
			FP_TitleFrame:SetWidth(newWidth)
			FP_ListFrame:SetWidth(newWidth)
			FP_MenuFrame:SetWidth(newWidth)
			FP_Position_Save.width = newWidth
			FP_UpdateWidthResponsiveUI(newWidth)
			changed = true
		end
	end

	-- Height and line count resizing
	local deltaY = resizeStartY - currentY
	local deltaLines = math.floor((deltaY / 24) + 0.5)
	local lines = math.max(4, math.min(26, resizeStartLines + deltaLines))

	if lines ~= FP_Options.viewLines then
		FP_Options.viewLines = lines
		FP_ListFrame:SetHeight(84 + (lines * 24))
		changed = true
	end

	if changed then
		FP_Refresh()
		if FP_LFGPanel and FP_LFGPanel:IsShown() and FP_LFGPanel.Layout then
			FP_LFGPanel:Layout()
		end
	end
end)

local function FP_SetupResizeHandles()
	-- Menu frame drag move and resize handle
	if FP_MenuFrame and not FP_MenuFrame.__fp_resize_setup then
		FP_MenuFrame.__fp_resize_setup = true

		-- Drag to move or right click to close
		FP_MenuFrame:EnableMouse(true)
		FP_MenuFrame:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				FP_ListFrame:StartMoving()
			elseif button == "RightButton" then
				FP_CloseOnRightClick()
			end
		end)
		FP_MenuFrame:SetScript("OnMouseUp", function(self, button)
			if button == "LeftButton" then
				FP_ListFrame:StopMovingOrSizing()
				FP_ListMove()
			end
		end)

		-- Corner grip: 2D resize
		local cornerGrip = CreateFrame("Button", "FP_MenuCornerResizeGrip", FP_MenuFrame)
		cornerGrip:SetSize(22, 22)
		cornerGrip:SetPoint("BOTTOMRIGHT", FP_MenuFrame, "BOTTOMRIGHT", -2, 2)
		cornerGrip:EnableMouse(true)
		cornerGrip:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
		cornerGrip:SetFrameLevel(FP_MenuFrame:GetFrameLevel() + 11)

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
			GameTooltip:SetText(FP_TEXT_RESIZE_TIP or "드래그: 창 크기 조절 (너비/높이) | 마우스 휠: 스크롤 이동")
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
				FP_StartResize("corner")
			elseif button == "RightButton" then
				FP_CloseOnRightClick()
			end
		end)
		cornerGrip:SetScript("OnMouseUp", function(self, button)
			if button == "LeftButton" then FP_StopResize() end
		end)
	end

	-- Bottom edge resize
	if FP_ListFrame and not FP_ListFrame.__fp_resize_setup then
		FP_ListFrame.__fp_resize_setup = true

		local listBottomBar = CreateFrame("Button", "FP_ListBottomResizeBar", FP_ListFrame)
		listBottomBar:SetHeight(10)
		listBottomBar:SetPoint("BOTTOMLEFT", FP_ListFrame, "BOTTOMLEFT", 0, 0)
		listBottomBar:SetPoint("BOTTOMRIGHT", FP_ListFrame, "BOTTOMRIGHT", 0, 0)
		listBottomBar:EnableMouse(true)
		listBottomBar:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
		listBottomBar:SetFrameLevel(FP_ListFrame:GetFrameLevel() + 10)

		listBottomBar:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				FP_StartResize("bottom")
			elseif button == "RightButton" then
				FP_CloseOnRightClick()
			end
		end)
		listBottomBar:SetScript("OnMouseUp", function(self, button)
			if button == "LeftButton" then FP_StopResize() end
		end)
	end

	-- Enable dragging on FP_ListFrame empty space
	if FP_ListFrame and not FP_ListFrame.__fp_drag_setup then
		FP_ListFrame.__fp_drag_setup = true
		FP_ListFrame:EnableMouse(true)
		FP_ListFrame:SetMovable(true)
		FP_ListFrame:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				FP_ListFrame:StartMoving()
			elseif button == "RightButton" then
				FP_CloseOnRightClick()
			end
		end)
		FP_ListFrame:SetScript("OnMouseUp", function(self, button)
			FP_ListFrame:StopMovingOrSizing()
			FP_ListMove()
		end)
	end

	-- Enable dragging on FP_ListFrameScrollFrame empty space (empty list / rows)
	if FP_ListFrameScrollFrame and not FP_ListFrameScrollFrame.__fp_drag_setup then
		FP_ListFrameScrollFrame.__fp_drag_setup = true
		FP_ListFrameScrollFrame:EnableMouse(true)
		FP_ListFrameScrollFrame:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				FP_ListFrame:StartMoving()
			elseif button == "RightButton" then
				FP_CloseOnRightClick()
			end
		end)
		FP_ListFrameScrollFrame:SetScript("OnMouseUp", function(self, button)
			FP_ListFrame:StopMovingOrSizing()
			FP_ListMove()
		end)
	end
end

function FP_ApplyModernTheme()
	FP_HookDropDownLists()
	FP_SetListColor()

	if FP_TitleFrame and not FP_TitleFrame.__fp_gold_accent then
		local accent = FP_TitleFrame:CreateTexture(nil, "ARTWORK", nil, 7)
		accent:SetPoint("TOPLEFT", 1, -1)
		accent:SetPoint("TOPRIGHT", -1, -1)
		accent:SetHeight(1)
		accent:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.75)
		FP_TitleFrame.__fp_gold_accent = accent

		local shine = FP_TitleFrame:CreateTexture(nil, "BORDER")
		shine:SetPoint("TOPLEFT", 1, -2)
		shine:SetPoint("TOPRIGHT", -1, -2)
		shine:SetHeight(28)
		shine:SetColorTexture(1, 1, 1, 0.025)
		FP_TitleFrame.__fp_shine = shine

		local titleSep = FP_TitleFrame:CreateTexture(nil, "ARTWORK", nil, 6)
		titleSep:SetPoint("BOTTOMLEFT", 1, 0)
		titleSep:SetPoint("BOTTOMRIGHT", -1, 0)
		titleSep:SetHeight(1)
		titleSep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.06)
		FP_TitleFrame.__fp_title_sep = titleSep
	end

	if FP_TitleFrameText then
		FP_TitleFrameText:SetText("|cffD4A745SolaLFG|r")
		FP_TitleFrameText:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		FP_TitleFrameText:SetShadowOffset(1, -1)
		FP_TitleFrameText:SetShadowColor(0, 0, 0, 1)
	end

	FP_StyleCloseButton(FP_TitleFrameCloseButton)
	FP_StyleModernButton(FP_TitleFrameIncreaseButton, "dark", "+")
	FP_StyleModernButton(FP_TitleFrameDecreaseButton, "dark", "-")
	FP_StyleModernButton(FP_TitleFrameMaxButton, "dark", "20")
	FP_StyleModernButton(FP_TitleFrameMinButton, "dark", "1")
	FP_StyleModernButton(FP_MenuFrameInfo, "amber", FP_TEXT_HELP or "Help")
	FP_StyleModernButton(FP_TitleFrameOption, "default", FP_OPTION or "Option")

	FP_CreateScaleSlider()
	FP_CreateKeyBindingButton()
	FP_UpdateKeyBindingButton()
	if FP_LFG_Init then FP_LFG_Init() end

	FP_UpdateStatusPills()

	if FP_ListFrame then
		if not FP_ListFrame.__fp_tool_sep then
			local toolSep = FP_ListFrame:CreateTexture(nil, "ARTWORK", nil, 6)
			toolSep:SetHeight(1)
			toolSep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.06)
			FP_ListFrame.__fp_tool_sep = toolSep
		end
		FP_ListFrame.__fp_tool_sep:ClearAllPoints()
		FP_ListFrame.__fp_tool_sep:SetPoint("TOPLEFT", 1, -39)
		FP_ListFrame.__fp_tool_sep:SetPoint("TOPRIGHT", -1, -39)

		if not FP_ListFrame.__fp_header_sep then
			local headerSep = FP_ListFrame:CreateTexture(nil, "ARTWORK", nil, 6)
			headerSep:SetHeight(1)
			headerSep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.06)
			FP_ListFrame.__fp_header_sep = headerSep
		end
		FP_ListFrame.__fp_header_sep:ClearAllPoints()
		FP_ListFrame.__fp_header_sep:SetPoint("TOPLEFT", 1, -79)
		FP_ListFrame.__fp_header_sep:SetPoint("TOPRIGHT", -1, -79)
	end

	if FP_ListFrameFilterDungeon then
		local btn = FP_ListFrameFilterDungeon
		btn:RegisterForClicks("LeftButtonDown", "RightButtonDown", "MiddleButtonDown")
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", 12, -7)
		btn:SetSize(146, 26)
		if BackdropTemplateMixin and not btn.SetBackdrop then
			Mixin(btn, BackdropTemplateMixin)
			btn:OnBackdropLoaded()
		end
		btn:SetBackdrop(FP_Backdrop_Info)
		btn:SetBackdropColor(0.14, 0.12, 0.10, 0.95)
		btn:SetBackdropBorderColor(SolaC.gold[1] * 0.75, SolaC.gold[2] * 0.75, SolaC.gold[3] * 0.75, 0.75)
		if FP_ListFrameFilterDungeonText then
			FP_ListFrameFilterDungeonText:ClearAllPoints()
			FP_ListFrameFilterDungeonText:SetPoint("LEFT", btn, "LEFT", 8, 0)
			FP_ListFrameFilterDungeonText:SetPoint("RIGHT", btn, "RIGHT", -26, 0)
			FP_ListFrameFilterDungeonText:SetFontObject("GameFontHighlightSmall")
			FP_ListFrameFilterDungeonText:SetTextColor(SolaC.fgMain[1], SolaC.fgMain[2], SolaC.fgMain[3])
			FP_ListFrameFilterDungeonText:SetShadowOffset(1, -1)
			FP_ListFrameFilterDungeonText:SetShadowColor(0, 0, 0, 0.9)
		end
		if FP_ListFrameFilterDungeonArrow then
			FP_ListFrameFilterDungeonArrow:SetText("")
			FP_ListFrameFilterDungeonArrow:Hide()
		end
		if not btn.__fp_v_btn then
			local vBtn = CreateFrame("Frame", nil, btn, BackdropTemplateMixin and "BackdropTemplate" or nil)
			vBtn:SetSize(22, 22)
			vBtn:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
			if BackdropTemplateMixin and not vBtn.SetBackdrop then
				Mixin(vBtn, BackdropTemplateMixin)
				vBtn:OnBackdropLoaded()
			end
			vBtn:SetBackdrop(FP_Backdrop_Info)
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

	if FP_MenuFrameFilter and FP_ListFrameFilterDungeon then
		FP_MenuFrameFilter:ClearAllPoints()
		FP_MenuFrameFilter:SetPoint("LEFT", FP_ListFrameFilterDungeon, "RIGHT", 14, 0)
		FP_MenuFrameFilter:SetText(FP_LABEL_FILTER or "Filter:")
		FP_MenuFrameFilter:SetTextColor(SolaC.teal[1], SolaC.teal[2], SolaC.teal[3])
	end
	FP_StyleModernEditBox(FP_MenuFrameFilterText, "teal")
	FP_StyleModernButton(FP_MenuFrameFilterApply, "mint", FP_TEXT_APPLY_FILTER or "적용")

	if FP_MenuFrameIgnore and FP_MenuFrameFilterApply then
		FP_MenuFrameIgnore:ClearAllPoints()
		FP_MenuFrameIgnore:SetPoint("LEFT", FP_MenuFrameFilterApply, "RIGHT", 8, 0)
		FP_MenuFrameIgnore:SetText(FP_LABEL_IGNORE or "Ignore:")
		FP_MenuFrameIgnore:SetTextColor(SolaC.rose[1], SolaC.rose[2], SolaC.rose[3])
	end
	FP_StyleModernEditBox(FP_MenuFrameIgnoreText, "rose")
	FP_StyleModernButton(FP_MenuFrameIgnoreButton, "rose", FP_TEXT_IGNORE or "Ignore")
	FP_StyleModernButton(FP_MenuFrameExceptionDelete, "amber", FP_BTN_RESET or "Reset")

	if FP_ListFrameDungeonHeader then
		FP_ListFrameDungeonHeader:ClearAllPoints()
		FP_ListFrameDungeonHeader:SetPoint("TOPLEFT", 64, -61)
		FP_ListFrameDungeonHeader:SetText(FP_TEXT_DUNGEON_LABEL or "Dungeon")
		FP_ListFrameDungeonHeader:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
	end
	if FP_ListFrameDungeonSort then
		FP_ListFrameDungeonSort:SetWidth(115)
	end
	if FP_ListFrameNameHeader then
		FP_ListFrameNameHeader:ClearAllPoints()
		FP_ListFrameNameHeader:SetPoint("TOPLEFT", 187, -61)
		FP_ListFrameNameHeader:SetText(FP_TEXT_SHOUTER_LABEL or "Leader")
		FP_ListFrameNameHeader:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
	end
	if FP_ListFrameMsgHeader then
		FP_ListFrameMsgHeader:ClearAllPoints()
		FP_ListFrameMsgHeader:SetPoint("TOPLEFT", 275, -61)
		FP_ListFrameMsgHeader:SetText(FP_TEXT_MSG_LABEL or "Message")
		FP_ListFrameMsgHeader:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
	end
	for r = 1, 30 do
		local dFrame = _G["FP_ListFrameRow"..r.."Dungeon"]
		if dFrame and dFrame.SetWidth then dFrame:SetWidth(115) end
		local nFrame = _G["FP_ListFrameRow"..r.."Name"]
		if nFrame and nFrame.SetWidth then nFrame:SetWidth(80) end
	end
	if FP_ListFrameTimeSort then
		FP_ListFrameTimeSort:ClearAllPoints()
		FP_ListFrameTimeSort:SetPoint("TOPLEFT", 12, -61)
		-- Remove button styling, apply plain gold text like DungeonHeader
		if FP_ListFrameTimeSort.SetBackdrop then
			FP_ListFrameTimeSort:SetBackdrop(nil)
		end
		if FP_ListFrameTimeSort.SetNormalTexture then FP_ListFrameTimeSort:SetNormalTexture("") end
		if FP_ListFrameTimeSort.SetPushedTexture then FP_ListFrameTimeSort:SetPushedTexture("") end
		if FP_ListFrameTimeSort.SetHighlightTexture then FP_ListFrameTimeSort:SetHighlightTexture("") end
		local tsRegions = {FP_ListFrameTimeSort:GetRegions()}
		for i = 1, #tsRegions do
			local r = tsRegions[i]
			if r:IsObjectType("Texture") then
				r:SetAlpha(0)
			end
		end
		local tsFs = FP_ListFrameTimeSort:GetFontString()
		if not tsFs then
			tsFs = FP_ListFrameTimeSort:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			FP_ListFrameTimeSort:SetFontString(tsFs)
		end
		tsFs:ClearAllPoints()
		tsFs:SetPoint("TOPLEFT", 0, 0)
		tsFs:SetJustifyH("LEFT")
		tsFs:SetText(FP_TEXT_TIME_LABEL or "Time")
		tsFs:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		tsFs:SetShadowOffset(1, -1)
		tsFs:SetShadowColor(0, 0, 0, 0.8)
	end

	if FP_ListFrameRow1 then
		FP_ListFrameRow1:ClearAllPoints()
		FP_ListFrameRow1:SetPoint("TOPLEFT", 12, -82)
		FP_ListFrameRow1:SetPoint("RIGHT", -30, 0)
	end
	if FP_ListFrameScrollFrame then
		FP_ListFrameScrollFrame:ClearAllPoints()
		FP_ListFrameScrollFrame:SetPoint("TOPLEFT", 0, -82)
		FP_ListFrameScrollFrame:SetPoint("BOTTOMRIGHT", -30, 8)
	end

	if FP_MenuFrame and not FP_MenuFrame.__fp_footer_sep then
		local footerSep = FP_MenuFrame:CreateTexture(nil, "ARTWORK", nil, 6)
		footerSep:SetPoint("TOPLEFT", 1, 0)
		footerSep:SetPoint("TOPRIGHT", -1, 0)
		footerSep:SetHeight(1)
		footerSep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.06)
		FP_MenuFrame.__fp_footer_sep = footerSep
	end

	if FP_MenuFrameWh then
		FP_MenuFrameWh:SetText(FP_LABEL_WH or "Whisper:")
		FP_MenuFrameWh:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
	end
	FP_StyleModernEditBox(FP_MenuFrameWhText, "gold")
	FP_StyleModernButton(FP_MenuFrameWhPresetBtn, "gold", "v")
	FP_StyleModernButton(FP_MenuFrameWhAddBtn, "default", FP_TEXT_ADD or "추가")
	FP_StyleModernButton(FP_MenuFrameApply, "teal", FP_TEXT_APPLY or "Apply")
	FP_StyleModernButton(FP_MenuFrameWhisper, "default", FP_BTN_WHISPER or "Whisper")
	FP_StyleModernButton(FP_MenuFrameWho, "default", FP_BTN_WHO or "Who")
	FP_StyleModernButton(FP_MenuFrameException, "rose", FP_TEXT_EXCEPTION or "Exclude")

	if FP_ListFrameResizeGrip and not FP_ListFrameResizeGrip.__fp_txt then
		local gripTxt = FP_ListFrameResizeGrip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		gripTxt:SetPoint("BOTTOMRIGHT", -2, 2)
		gripTxt:SetText("")
		gripTxt:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		FP_ListFrameResizeGrip.__fp_txt = gripTxt
	end

	local sb = _G["FP_ListFrameScrollFrameScrollBar"]
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
		local upBtn = _G["FP_ListFrameScrollFrameScrollBarScrollUpButton"]
		if upBtn then upBtn:Hide(); upBtn:SetAlpha(0) end
		local downBtn = _G["FP_ListFrameScrollFrameScrollBarScrollDownButton"]
		if downBtn then downBtn:Hide(); downBtn:SetAlpha(0) end
	end

	for i = 1, 28 do
		local row = _G["FP_ListFrameRow"..i]
		if row then
			local ht = row:GetHighlightTexture()
			if ht then
				ht:SetColorTexture(SolaC.bgHover[1], SolaC.bgHover[2], SolaC.bgHover[3], 0.75)
			end
			local timeText = _G["FP_ListFrameRow"..i.."TimeText"]
			if timeText then
				timeText:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
				timeText:SetJustifyH("LEFT")
			end
			local msgText = _G["FP_ListFrameRow"..i.."MsgText"]
			if msgText then
				msgText:SetTextColor(SolaC.fgMain[1], SolaC.fgMain[2], SolaC.fgMain[3])
			end
		end
	end

	FP_SetupMouseWheel()
	FP_SetupResizeHandles()

	local curW = (FP_Position_Save and FP_Position_Save.width) or (FP_ListFrame and FP_ListFrame:GetWidth()) or 750
	FP_UpdateWidthResponsiveUI(curW)

	if MessageQueue then
		FP_EnableAnnounce()
	else
		FP_DisableAnnounce(true)
	end
end

function FP_Init()
	if not (FP_Version == FP_Revision) then
		if type(FP_Version) ~= "number" then
			FP_Print(FP_MESSAGE_NEWVERSION_RESET)
			if FP_DUNGEON_LIST then
				FP_DUNGEON_LIST = nil
			end
			FP_LoadDefaultOption()
		else
			if FP_Version < 10 then
				FP_Print(FP_MESSAGE_NEWVERSION_RESET)
				if FP_DUNGEON_LIST then
					FP_DUNGEON_LIST = nil
				end
				FP_LoadDefaultOption()
			else
				if FP_Version < 20 then
					if FP_Options and FP_Options.channel then
						FP_Options.channel["거래"] = true
						FP_Options.channel["공개"] = true
						FP_Options.channel["Trade"] = true
						FP_Options.channel["General"] = true
					end
				end
				if FP_Version < 19 then
					if FP_Options then
						FP_Options.lfgFilterDrawerOpen = true
						FP_Options.viewModeSelected = false
						FP_Options.lastShownUpdateNotice = nil
					end
				end
				if FP_Version < 16 then
					FP_Options.noparty = nil
				end
				if FP_Version < 15 then
					FP_Options.noraid = true
					FP_Options.noparty = false
					FP_Options.nopvp = true
				end
				if FP_Version < 14 then
					local savedViewLines
					if FP_Scroll_Info and FP_Scroll_Info.viewLines and type(FP_Scroll_Info.viewLines) == "number" then
						savedViewLines = FP_Scroll_Info.viewLines
					end
					FP_Scroll_Info = nil
					FP_Options.viewLines = savedViewLines or 20
				end
				if FP_Version < 13 then
					FP_Filter_Dungeon = {}
					FP_Filter_Class = nil
				end
			end
		end

		FP_Version = FP_Revision
	end

	if not FP_Options then
		FP_LoadDefaultOption()
	end

	if (FP_GetLocale and FP_GetLocale() or GetLocale()) ~= "koKR" then
		FP_Options.lfgOnly = true
		FP_Options.viewModeSelected = true
	end

	if FP_Options.esc == nil or FP_Options.esc == false then
		FP_Options.esc = true
	end
	if FP_Options.lfgFilterDrawerOpen == nil then
		FP_Options.lfgFilterDrawerOpen = true
	end
	if FP_Options.color and FP_Options.color.r == 0 and FP_Options.color.g == 0 and FP_Options.color.b == 0 then
		FP_Options.color.r = 0.04
		FP_Options.color.g = 0.06
		FP_Options.color.b = 0.09
		FP_Options.color.opacity = 0.85
	end
	if FP_Options.channel == nil then
		FP_Options.channel = {}
		for k, v in pairs(FP_Default_Options.channel) do
			FP_Options.channel[k] = v
		end
	end

		if FP_Options.titlebarVisible ~= false then
		FP_TitleFrame:Show()
	else
		FP_TitleFrame:Hide()
	end
	if FP_Options.menubarVisible ~= false then
		FP_MenuFrame:Show()
	else
		FP_MenuFrame:Hide()
	end
	FP_ListFrame:SetClampedToScreen(false)
	if FP_Frame and FP_Frame.SetClampedToScreen then
		FP_Frame:SetClampedToScreen(false)
	end
	if FP_ListFrame.SetResizable then
		FP_ListFrame:SetResizable(false)
	end

	FP_FontResize()
	FP_SetListPosition()
	FP_UIResize(FP_Options.scale)
	FP_EnsureSpecialFrame()
	FP_ApplyModernTheme()

	-- Setup minimap icon
	if FP_Minimap_Button and not FP_Options.icon then FP_Minimap_Button:Hide() end
	if FP_Minimap_Button and FP_Options.iconLocked then FP_Minimap_Button:RegisterForDrag(nil) end

	-- Initialize whisper message and level
	-- Whisper Preset & Auto Level Init
	if not FP_WhPresets then FP_WhPresets = {} end
	if FP_WhAutoLevel == nil then
		if not FP_UserDefinedWhMsg or FP_UserDefinedWhMsg == "" then
			FP_WhAutoLevel = true
		else
			FP_WhAutoLevel = false
		end
	end

	if FP_WhAutoLevel or (FP_UserDefinedWhMsg and string.find(FP_UserDefinedWhMsg, "손이요")) then
		FP_WhAutoLevel = true
		FP_RefreshAutoWhMsg()
	elseif FP_UserDefinedWhMsg then
		FP_MenuFrameWhText:SetText(FP_UserDefinedWhMsg)
	end

	if FP_InviteControlFrame and FP_InviteControlFrame.RegisterEvent then
		FP_InviteControlFrame:RegisterEvent("PLAYER_LEVEL_UP")
	end

	-- Patch settings
	if not FP_Options.valid or FP_Options.valid < 60 then
		FP_Options.valid = 120 -- Default cache duration 2 minutes
	end

	-- Initialize filter strings
	if getDungeonFilterNum() > 0 then
		isDungeonFiltering = true
	end
	FP_SetDungeonFilterText()

	-- Initialize exclude strings
	if FP_UserDefinedIgnoreMsg ~= "" then
		FP_MenuFrameIgnoreText:SetText(FP_UserDefineIgnoreMsg)
		FP_SetCustomIgnoreText()
	end

	-- MessageQueue 애드온 설치 검사 및 광고 UI 초기화
	if MessageQueue then
		FP_EnableAnnounce()
	else
		FP_DisableAnnounce(true)
	end

	-- Activate addon
	FP_Activate(FP_Options.activated, true)
	if FP_Options.activateBellnWindow then
		FP_ActiveBellnWindow(true)
	end

	local function printLoadMsg()
		if DEFAULT_CHAT_FRAME then
			local verStr = FP_DISPLAY_VERSION or (FP_GetVersionString and FP_GetVersionString()) or "1.0"
			DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745SolaLFG [" .. verStr .. "]|r |cff8A8580/|r |cff5ABFB0" .. (((FP_GetLocale and FP_GetLocale() or GetLocale()) == "koKR") and "Sola-아즈샤라" or "Sola") .. "|r")
		end
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(1.5, printLoadMsg)
	else
		printLoadMsg()
	end

	if FP_Options and FP_Options.lfgOnly then
		if C_Timer and C_Timer.After then
			C_Timer.After(0.1, function()
				if FP_ApplyLFGOnlyMode then FP_ApplyLFGOnlyMode(false, false) end
			end)
		end
	end

	-- First-time user welcome card choice popup (for fresh installs and revision 18 update)
	if FP_Options and not FP_Options.viewModeSelected then
		if C_Timer and C_Timer.After then
			C_Timer.After(1.2, function()
				if FP_Options and not FP_Options.viewModeSelected and FP_OpenCardChoiceFrame then
					FP_OpenCardChoiceFrame()
				end
			end)
		end
	end

	-- Update notice popup (shows in front of card choice popup or alone)
	local targetUpdateVer = "1.39"
	if FP_Options and FP_Options.lastShownUpdateNotice ~= targetUpdateVer then
		if C_Timer and C_Timer.After then
			C_Timer.After(1.2, function()
				if FP_ShowUpdatePopup then FP_ShowUpdatePopup(true) end
			end)
		end
	end
end

---------------
-- Parse dungeon text
---------------
-- String filtering helper
function FP_FilterIgnoreText(msg, ignoreTextTable, isTooltip)
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

function FP_DungeonParse(msg)
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
						for j = 1, #FP_GLOBAL_EXCLUDE_KEYWORDS do
							if string.find(nmsg_dungeon, string.lower(FP_GLOBAL_EXCLUDE_KEYWORDS[j]), 1, true) then
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
						for k = 1, #FP_DUNGEON_IGNORE_POSTFIX_KEYWORDS do
							if string.find(nmsg_dungeon, normalizedKeyword..string.lower(FP_DUNGEON_IGNORE_POSTFIX_KEYWORDS[k]), 1, true) then
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
	for _, tbl in ipairs(FP_DUNGEON_KEYWORDS) do
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
		for _, tbl in ipairs(FP_DUNGEON_KEYWORDS) do
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

local FP_UpdateDropdownButtonCheckbox

local function syncDungeonCategoryDropdown(category)
	local categorySelected = FP_Filter_Dungeon[category]
	local categoryData
	for _, tbl in ipairs(FP_DUNGEON_KEYWORDS) do
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
			if FP_UpdateDropdownButtonCheckbox then FP_UpdateDropdownButtonCheckbox(button) end
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
			if FP_UpdateDropdownButtonCheckbox then FP_UpdateDropdownButtonCheckbox(button) end
		end
	end
end

local function toggleDungeonCategoryFilter(self, categoryIndex)
	local tbl = FP_DUNGEON_KEYWORDS[categoryIndex]
	if not tbl then return end
	local selected = FP_Filter_Dungeon[tbl.category] or {}
	local allSelected = #tbl.dungeon > 0
	for _, dungeon in ipairs(tbl.dungeon) do
		if not selected[dungeon.name] then allSelected = false; break end
	end
	if allSelected then
		FP_Filter_Dungeon[tbl.category] = nil
	else
		FP_Filter_Dungeon[tbl.category] = {}
		for _, dungeon in ipairs(tbl.dungeon) do
			FP_Filter_Dungeon[tbl.category][dungeon.name] = true
		end
	end
	isDungeonFiltering = getDungeonFilterNum() > 0
	syncDungeonCategoryDropdown(tbl.category)
	FP_SetDungeonFilterText()
	FP_Refresh(true)
end

function FP_DropDownMenuFilterDungeon_Initialize(frame, level, menu)
	level = level or 1
	local info
	if (level == 1) then
		for idx, tbl in ipairs(FP_DUNGEON_KEYWORDS) do
			info = UIDropDownMenu_CreateInfo()
			info.text = tbl.category
			info.keepShownOnClick = true
			info.disabled = false
			info.hasArrow = true
			info.notCheckable = false
			info.isNotRadio = true
			info.checked = FP_Filter_Dungeon[tbl.category] and #tbl.dungeon > 0
			if info.checked then
				for _, dungeon in ipairs(tbl.dungeon) do
					if not FP_Filter_Dungeon[tbl.category][dungeon.name] then info.checked = false; break end
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
		info.text = FP_TEXT_CLOSE
		info.func = nil
		info.notCheckable = true
		info.keepShownOnClick = false
		UIDropDownMenu_AddButton(info, level)
	elseif (level == 2) then
		for _, tbl in ipairs(FP_DUNGEON_KEYWORDS[menu].dungeon) do
			info = UIDropDownMenu_CreateInfo()
			info.text = tbl.name
			info.keepShownOnClick = true
			info.disabled = false
			info.hasArrow = false
			info.isNotRadio = true
			info.func = FP_FilterDungeonSelected
			info.checked = (FP_Filter_Dungeon[FP_DUNGEON_KEYWORDS[menu].category] and FP_Filter_Dungeon[FP_DUNGEON_KEYWORDS[menu].category][info.text]) or false
			info.menuList = info.text
			info.arg1 = info.text
			info.arg2 = nil
			UIDropDownMenu_AddButton(info, level)
		end -- for key, subarray
	end
end

function FP_FilterDungeonSelected(self, dungeon, _, checked)
	if not dungeon then return end
	local category = getCategory(dungeon)

	-- Add to filter
	if checked then
		-- Create table if needed
		if not FP_Filter_Dungeon[category] then
			FP_Filter_Dungeon[category] = {}
		end
		if not FP_Filter_Dungeon[category][dungeon] then
			FP_Filter_Dungeon[category][dungeon] = true
		end
	else
	-- Remove from filter
		FP_Filter_Dungeon[category][dungeon] = nil
		-- Clean up table
		local category_tables = 0
		for _, tbl in pairs(FP_Filter_Dungeon[category]) do
			category_tables = category_tables + 1
		end
		if category_tables == 0 then
			FP_Filter_Dungeon[category] = nil
		end
	end

	-- Update dungeon filter state
	if getDungeonFilterNum() > 0 then
		isDungeonFiltering = true
	else
		isDungeonFiltering = false
	end
	FP_SetDungeonFilterText()

	-- Synchronize checkboxes
	local idx = 1
	local loop = true
	-- Loop guard: limit 30
	while loop and idx < 30 do
		local button = _G["DropDownList2Button"..idx]
		if button and button:GetText() then
			local button_text = button:GetText()
			if FP_Filter_Dungeon[category] and FP_Filter_Dungeon[category][button_text] then
				button.checked = true
				_G["DropDownList2Button"..idx.."Check"]:Show()
			else
				button.checked = false
				_G["DropDownList2Button"..idx.."Check"]:Hide()
			end
			if FP_UpdateDropdownButtonCheckbox then
				FP_UpdateDropdownButtonCheckbox(button)
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
			if FP_Filter_Dungeon[category] and FP_Filter_Dungeon[category][dungeon] and FP_Filter_Dungeon[category][dungeon][button2_text] then
				button2.checked = true
				_G["DropDownList3Button"..idx2.."Check"]:Show()
			else
				button2.checked = false
				_G["DropDownList3Button"..idx2.."Check"]:Hide()
			end
			if FP_UpdateDropdownButtonCheckbox then
				FP_UpdateDropdownButtonCheckbox(button2)
			end
		else
			loop2 = false
			break
		end
		idx2 = idx2 + 1
	end

	FP_Refresh(true)
end

function FP_GetDungeonFilterList()
	local desc = ""
	local i = 0
	local num = getDungeonFilterNum()

	for _, tbl in pairs(FP_Filter_Dungeon) do
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
		desc = FP_DUNGEONFILTER_NONE or "없음"
	end

	return desc
end

function FP_SetDungeonFilterText()
	local desc = FP_DUNGEONFILTER_NOT_FILTERED or "모두 보기"
	local filtered_count = getDungeonFilterNum()

	if isDungeonFiltering and filtered_count > 1 then
		desc = string.format(FP_DUNGEONFILTER_MULTI or "던전: %d개 선택", filtered_count)
	elseif isDungeonFiltering and filtered_count > 0 then
		for _, tbl in pairs(FP_Filter_Dungeon) do
			for idx, _ in pairs(tbl) do
				desc = string.format(FP_DUNGEONFILTER_SINGLE or "던전: %s", idx)
			end
		end
	end

	if FP_ListFrameFilterDungeonText then
		FP_ListFrameFilterDungeonText:SetText(desc)
	end
end

-- Clear all selected dungeon filters and switch to View All
function FP_ClearDungeonFilter()
	local hadFilters = (getDungeonFilterNum() > 0)
	FP_Filter_Dungeon = {}
	isDungeonFiltering = false
	FP_SetDungeonFilterText()
	FP_Refresh(true)
	CloseDropDownMenus()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
	if hadFilters then
		FP_Print(FP_MESSAGE_DUNGEON_RESET)
	end
end

-- Toggle between View All and Interested Dungeons filter without clearing selections
function FP_ToggleDungeonFilterView()
	local count = getDungeonFilterNum()
	if count == 0 then
		FP_Print(FP_L and FP_L["No interested dungeons selected."] or "선택된 관심 던전이 없습니다. 던전 목록에서 관심 던전을 먼저 선택해주세요.")
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		return
	end

	isDungeonFiltering = not isDungeonFiltering
	FP_SetDungeonFilterText()
	FP_Refresh(true)
	CloseDropDownMenus()

	if isDungeonFiltering then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
		local desc = ""
		if count == 1 then
			for _, tbl in pairs(FP_Filter_Dungeon) do
				for idx in pairs(tbl) do
					desc = idx
				end
			end
		else
			desc = string.format(FP_L and FP_L["%d dungeons"] or "%d개 던전", count)
		end
		FP_Print(string.format(FP_L and FP_L["Filtered to interested dungeons (%s)."] or "관심 던전 필터가 활성화되었습니다. (%s)", desc))
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		FP_Print(FP_L and FP_L["Showing all dungeons."] or "모든 던전 광고를 표시합니다. (모두 보기)")
	end
end

function FP_DungeonFilter(dungeon)
	if isDungeonFiltering and getDungeonFilterNum() > 0 then
		for _, tbl in pairs(FP_Filter_Dungeon) do
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
function FP_CustomFilter(msg)
	local table = {
		['flag'] = false,
		['msg'] = msg
	}
	local userInputCustomFilterString = FP_UserDefineFilterMsg
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

function FP_SetCustomFilterText()
	FP_UserDefineFilterMsg = FP_MenuFrameFilterText:GetText();
end

function FP_SetCustomIgnoreText()
	FP_UserDefineIgnoreMsg = FP_MenuFrameIgnoreText:GetText();

	local userString = FP_UserDefineIgnoreMsg

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
		FP_Refresh()
	else
		wipe(custom_ignore_keywords)
	end
end

-----------------
-- Exclusion filtering
-----------------
function FP_ExceptionFilter(exception)
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
function FP_Activate(active, noMsg)
	FP_Options.activated = active
	if active then
		if not noMsg then FP_Print(string.format(FP_MESSAGE_ACTIVE, FP_DISPLAY_VERSION)) end
		FP_Refresh()
	else
		if not noMsg then FP_Print(string.format(FP_MESSAGE_DEACTIVE, FP_DISPLAY_VERSION)) end
	end
	FP_UpdateStatusPills()
end

function FP_ActiveBellnWindow(active)
	FP_Options.activateBellnWindow = active
	if active then
		FP_Print(FP_MESSAGE_POPUP_ACTIVE)
	else
		FP_Print(FP_MESSAGE_POPUP_DEACTIVE)
	end
	FP_UpdateStatusPills()
end

function FP_AutoDeactivate()
	local _, instancetype = GetInstanceInfo()
	if FP_Options.activated then
		if instancetype == "raid" and FP_Options.noraid then FP_Activate(false) end
		if instancetype == "pvp" and FP_Options.nopvp then FP_Activate(false) end
	elseif not FP_Options.useroffed and not FP_Options.activated then
		if FP_Options.noraid and FP_Options.nopvp then
			if instancetype ~= "raid" and instancetype ~= "pvp" then FP_Activate(true) end
		elseif FP_Options.noraid then
			if instancetype ~= "raid" then FP_Activate(true) end
		elseif FP_Options.nopvp then
			if instancetype ~= "pvp" then FP_Activate(true) end
		end
	end
end

-------------------------------------------------
-- Whisper Macro Preset System (Max 5 + Auto Level)
-------------------------------------------------
-------------------------------------------------
-- Whisper Macro Preset System (Max 5 + Auto Level)
-------------------------------------------------
FP_WhPresets = FP_WhPresets or {}
FP_WhAutoLevel = true

function FP_RefreshAutoWhMsg()
	local lvl = UnitLevel("player")
	local cls = (FP_GetPlayerClassName and FP_GetPlayerClassName()) or UnitClass("player")
	if lvl and cls then
		local autoMsg = string.format(FP_TEXT_AUTO_WHISPER_FORMAT or "%d %s 초대 부탁드립니다", lvl, cls)
		if FP_MenuFrameWhText then
			FP_MenuFrameWhText:SetText(autoMsg)
		end
		if FP_LFG_WhText then
			FP_LFG_WhText:SetText(autoMsg)
		end
		FP_UserDefinedWhMsg = autoMsg
	end
end

function FP_Tooltip_WhPresetBtn(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(FP_L["Whisper Message Presets (Click to open)"] or "귓속말 문구 목록 (클릭하여 열기)", 1, 0.85, 0.5)
	GameTooltip:AddLine(FP_L["Select or delete saved whisper messages.\nSupports [Auto] Level + Class option."] or "저장된 문구를 선택하거나 삭제할 수 있습니다.\n[자동] 레벨+직업 옵션도 지원합니다.", 0.8, 0.8, 0.8, true)
	GameTooltip:Show()
end

function FP_Tooltip_WhAddBtn(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(FP_L["Add Whisper Preset"] or "귓속말 문구 추가", 1, 0.85, 0.5)
	GameTooltip:AddLine(FP_L["Saves current input text to the preset list.\n(Up to 5 messages)"] or "현재 입력창의 문구를 목록에 저장합니다.\n(최대 5개까지 등록 가능)", 0.8, 0.8, 0.8, true)
	GameTooltip:Show()
end

local whPresetFrame = nil

function FP_EnsureWhPresetFrame()
	if whPresetFrame then return whPresetFrame end

	local f = CreateFrame("Frame", "FP_WhPresetFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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
	title:SetText("|cffD4A745" .. (FP_L["Whisper Message Presets"] or "귓속말 문구 목록") .. "|r |cff8A8580(" .. (FP_L["Up to 5 saved"] or "최대 5개 저장") .. ")|r")
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
		FP_WhAutoLevel = true
		FP_RefreshAutoWhMsg()
		local cur = (FP_LFG_WhText and FP_LFG_WhText:GetText()) or (FP_MenuFrameWhText and FP_MenuFrameWhText:GetText()) or FP_UserDefinedWhMsg or ""
		FP_Print(string.format(FP_L["Selected auto level/class message: %s"] or "|cff6BBF8A[자동 신청]|r 현재 레벨/직업 문구로 선택되었습니다: %s", cur))
		f:Hide()
	end)
	autoBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(FP_TEXT_AUTO_WHISPER_LABEL or FP_L["Current Level + Class + Inv please"] or "현재레벨 + 직업 + 초대 부탁드립니다", 1, 0.85, 0.5)
		GameTooltip:AddLine(FP_L["Automatically updates your level whenever SolaLFG opens."] or "선택 시 SolaLFG 창을 열 때마다 레벨이 자동으로 갱신됩니다.", 0.8, 0.8, 0.8, true)
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
			if FP_WhPresets and FP_WhPresets[idx] then
				FP_WhAutoLevel = false
				local chosen = FP_WhPresets[idx]
				if FP_MenuFrameWhText then FP_MenuFrameWhText:SetText(chosen) end
				if FP_LFG_WhText then FP_LFG_WhText:SetText(chosen) end
				FP_UserDefinedWhMsg = chosen
				FP_Print(string.format(FP_L["Whisper message selected: %s"] or "귓속말 문구가 선택되었습니다: %s", chosen))
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
			GameTooltip:SetText(FP_L["Delete Message"] or "문구 삭제", 1, 0.4, 0.4)
			GameTooltip:AddLine(FP_L["Remove this message from the list."] or "이 문구를 목록에서 제거합니다.", 0.8, 0.8, 0.8)
			GameTooltip:Show()
		end)
		delBtn:SetScript("OnLeave", function(self)
			self.txt:SetText("|cffCF6679X|r")
			GameTooltip:Hide()
		end)
		delBtn:SetScript("OnClick", function()
			if FP_WhPresets and FP_WhPresets[idx] then
				local removed = table.remove(FP_WhPresets, idx)
				FP_Print(string.format(FP_L["Saved message deleted: %s"] or "저장 문구가 삭제되었습니다: %s", removed or ""))
				FP_UpdateWhPresetMenu()
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
	emptyTxt:SetText("|cff8A8580(" .. (FP_L["No saved messages - Register using [Add]"] or "저장된 문구 없음 - [추가] 버튼으로 등록") .. ")|r")
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

	tinsert(UISpecialFrames, "FP_WhPresetFrame")
	return f
end

function FP_UpdateWhPresetMenu()
	local f = FP_EnsureWhPresetFrame()
	if not FP_WhPresets then FP_WhPresets = {} end

	local lvl = UnitLevel("player") or 1
	local cls = (FP_GetPlayerClassName and FP_GetPlayerClassName()) or UnitClass("player") or FP_L["Unknown Class"] or "직업"
	local autoMsg = string.format(FP_TEXT_AUTO_WHISPER_FORMAT or "%d %s 초대 부탁드립니다", lvl, cls)

	local autoLabel = FP_L["Auto"] or "자동"
	local selLabel = FP_L["Selected"] or "선택됨"
	if FP_WhAutoLevel then
		f.__fp_autoBtn.txt:SetText(string.format("|cff6BBF8A[V] [%s] %s (%s)|r", autoLabel, autoMsg, selLabel))
	else
		f.__fp_autoBtn.txt:SetText(string.format("|cffD4A745[%s]|r %s", autoLabel, autoMsg))
	end

	local count = #FP_WhPresets
	local curText = ""
	if FP_LFG_WhText and FP_LFG_WhText:IsShown() and FP_LFG_WhText:GetText() and FP_LFG_WhText:GetText() ~= "" then
		curText = FP_LFG_WhText:GetText()
	elseif FP_MenuFrameWhText and FP_MenuFrameWhText:IsShown() and FP_MenuFrameWhText:GetText() and FP_MenuFrameWhText:GetText() ~= "" then
		curText = FP_MenuFrameWhText:GetText()
	else
		curText = FP_UserDefinedWhMsg or ""
	end

	for i = 1, 5 do
		local row = f.presetRows[i]
		if i <= count then
			local preset = FP_WhPresets[i]
			local isSelected = (not FP_WhAutoLevel) and (curText == preset)
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

function FP_ToggleWhPresetMenu(anchorFrame)
	local f = FP_EnsureWhPresetFrame()
	if f:IsShown() then
		f:Hide()
		return
	end

	-- Accurately detect whether opened from LFG panel or Chat Filter window
	local isLfgTarget = false
	if anchorFrame then
		local aName = (anchorFrame.GetName and anchorFrame:GetName()) or ""
		if aName:find("LFG") or anchorFrame == FP_LFG_WhPresetBtn or anchorFrame == FP_LFG_WhText then
			isLfgTarget = true
		elseif FP_LFGPanel and anchorFrame.IsDescendantOf and anchorFrame:IsDescendantOf(FP_LFGPanel) then
			isLfgTarget = true
		end
	else
		if (FP_Options and FP_Options.lfgOnly) or (FP_LFGPanel and FP_LFGPanel:IsShown() and not (FP_ListFrame and FP_ListFrame:IsShown())) then
			isLfgTarget = true
		end
	end

	local hostParent = nil
	local hostAnchor = nil
	local xOff, yOff = 10, 4

	if isLfgTarget then
		hostParent = FP_LFG_BottomBar or FP_LFGPanel
		hostAnchor = hostParent
		if hostParent == FP_LFGPanel then
			yOff = 36
		end
	else
		hostParent = FP_MenuFrame or FP_Frame or UIParent
		hostAnchor = FP_MenuFrame or FP_Frame
	end

	if hostParent and hostParent ~= UIParent then
		f:SetParent(hostParent)
		f:SetScale(1.0)
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f:SetFrameLevel((hostParent.GetFrameLevel and hostParent:GetFrameLevel() or 20) + 50)
	else
		f:SetParent(UIParent)
		local sc = tonumber(FP_Options and FP_Options.scale) or 1.0
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

	FP_UpdateWhPresetMenu()
	f:Show()
end

function FP_AddCurrentWhPreset()
	local eb = (FP_Options and FP_Options.lfgOnly and FP_LFG_WhText) or FP_MenuFrameWhText
	local text = eb and eb:GetText()
	if not text or text:match("^%s*$") then
		FP_Print(FP_L["Please enter a message to save first."] or "저장할 문구를 먼저 입력해주세요.")
		return
	end

	if not FP_WhPresets then FP_WhPresets = {} end

	for _, v in ipairs(FP_WhPresets) do
		if v == text then
			FP_Print(FP_L["This message is already saved."] or "이미 저장되어 있는 문구입니다.")
			return
		end
	end

	if #FP_WhPresets >= 5 then
		FP_Print(FP_L["You can save up to 5 preset messages."] or "저장 문구는 최대 5개까지 등록할 수 있습니다.")
		return
	end

	table.insert(FP_WhPresets, text)
	FP_Print(string.format(FP_L["Whisper message saved: |cffD4A745%s|r"] or "귓속말 문구가 저장되었습니다: |cffD4A745%s|r", text))

	if whPresetFrame and whPresetFrame:IsShown() then
		FP_UpdateWhPresetMenu()
	end
end

function FP_Whisper(target)
	if not target or target == "" then return end

	local msg = ""
	if FP_Options and FP_Options.lfgOnly then
		msg = (FP_LFG_WhText and FP_LFG_WhText:GetText()) or (FP_MenuFrameWhText and FP_MenuFrameWhText:GetText()) or FP_UserDefinedWhMsg or ""
	else
		msg = (FP_MenuFrameWhText and FP_MenuFrameWhText:GetText()) or (FP_LFG_WhText and FP_LFG_WhText:GetText()) or FP_UserDefinedWhMsg or ""
	end

	if msg and msg ~= "" then
		FP_UserDefinedWhMsg = msg
	end

	if not msg or string.len(msg) == 0 then
		local playerClass = (FP_GetPlayerClassName and FP_GetPlayerClassName()) or UnitClass("player") or ""
		local myTalent = FP_GetMyTalent() or ""
		local formatStr = FP_DEFAULT_WHISPER or "%s %s 초대 부탁드립니다"
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

function FP_Exception(target)
	if exceptionData then
		savePlace = #exceptionData + 1
	else
		savePlace = 1
	end
	exceptionData[savePlace] = target

	FP_Print(string.format(FP_MESSAGE_EXCEPTION, target))
	FP_Refresh(true)
end

function FP_GetMyTalent()
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
function FP_SortButtonClicked(self)
	local id = self:GetID()

	column = colName[id]

	sortData[column] = not sortData[column]
	sortData.current_sort = column

	FP_Refresh()
	return sortData[column]
end

function FP_ListSort(list, col, ascd)
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

local function FP_SendWho(name)
	if not name then return end
	if C_FriendList and C_FriendList.SendWho then
		C_FriendList.SendWho(name)
	elseif SendWho then
		SendWho(name)
	end
end

local dropDownCloseTime = 0

local function FP_SetDropdownCboxBorder(cbox, r, g, b, a)
	if not cbox then return end
	cbox.b_top:SetColorTexture(r, g, b, a)
	cbox.b_btm:SetColorTexture(r, g, b, a)
	cbox.b_lft:SetColorTexture(r, g, b, a)
	cbox.b_rgt:SetColorTexture(r, g, b, a)
end

function FP_UpdateDropdownButtonCheckbox(btn)
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
		FP_SetDropdownCboxBorder(cbox, SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.95)
	else
		if cbox.rdot then cbox.rdot:Hide() end
		cbox.bg:SetColorTexture(0.08, 0.09, 0.11, 0.90)
		FP_SetDropdownCboxBorder(cbox, 0.28, 0.32, 0.36, 0.75)
	end
end

local function FP_RestoreDropDownList(list)
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

function FP_GetDropdownTargetScale(anchor)
	if anchor and anchor.GetEffectiveScale and UIParent and UIParent.GetEffectiveScale then
		local uScale = UIParent:GetEffectiveScale()
		if uScale and uScale > 0 then
			local effScale = anchor:GetEffectiveScale()
			if effScale and effScale > 0 then
				return effScale / uScale
			end
		end
	end
	if FP_Frame and FP_Frame.GetScale then
		local s = FP_Frame:GetScale()
		if s and s > 0 then return s end
	end
	return 1.0
end

local function FP_SkinDropDownList(list)
	if not list then return end
	if (UIDROPDOWNMENU_OPEN_MENU ~= FP_DropDownMenu) and (list.dropdown ~= FP_DropDownMenu) then return end

	local name = list:GetName()
	if not name then return end

	-- Apply target scale (match window/anchor scale 1:1, no 0.64 shrinking)
	local targetScale = FP_DropDownMenu.__fp_target_scale or FP_GetDropdownTargetScale(FP_DropDownMenu or FP_Frame)
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
						hooksecurefunc(check, "Show", function() FP_UpdateDropdownButtonCheckbox(btn) end)
						hooksecurefunc(check, "Hide", function() FP_UpdateDropdownButtonCheckbox(btn) end)
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
								FP_SetDropdownCboxBorder(self.__fp_cbox, 1.0, 0.88, 0.45, 1.0)
							else
								FP_SetDropdownCboxBorder(self.__fp_cbox, 0.50, 0.62, 0.68, 0.95)
							end
						end
					end)
					btn:HookScript("OnLeave", function(self)
						FP_UpdateDropdownButtonCheckbox(self)
					end)
				end

				FP_UpdateDropdownButtonCheckbox(btn)
			end)
		end
	end
end

local function FP_SkinAllDropDowns()
	for level = 1, 3 do
		local list = _G["DropDownList"..level]
		if list and list:IsShown() then
			FP_SkinDropDownList(list)
		end
	end
end

function FP_HookDropDownLists()
	for level = 1, 3 do
		local list = _G["DropDownList"..level]
		if list and not list.__fp_hooked then
			list.__fp_hooked = true
			list:HookScript("OnShow", function(self)
				FP_SkinDropDownList(self)
			end)
			list:HookScript("OnHide", function(self)
				FP_RestoreDropDownList(self)
				if self.__fp_scaled then
					if self.SetScale then self:SetScale(1.0) end
					self.__fp_scaled = nil
				end
				if level == 1 then
					dropDownCloseTime = GetTime()
					FP_DropDownCloseTime = dropDownCloseTime
				end
			end)
		end
	end
end

-------------------------------------------------
-- Auto Announce (MessageQueue Support)
-------------------------------------------------
function FP_IsAnnoucing()
	return isAnnouncing
end

function FP_Announce()
	if not MessageQueue then
		FP_StopAnnounce()
		return
	end

	local msg = (FP_MenuFrameAdText and FP_MenuFrameAdText:GetText()) or FP_UserDefinedAdMsg
	FP_UserDefinedAdMsg = msg
	if (not msg or string.len(msg) == 0) then
		FP_Print(FP_MESSAGE_NO_AD_TEXT)
		FP_StopAnnounce()
		return
	end

	local list = { GetChannelList() }
	local chaNum = 0
	for chan, enabled in pairs(FP_Options.channel) do
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

function FP_StartAnnounce()
	if not MessageQueue then
		FP_Print(FP_MESSAGE_DISABLE_ANNOUNCE)
		return
	end
	local msg = (FP_MenuFrameAdText and FP_MenuFrameAdText:GetText()) or FP_UserDefinedAdMsg
	if not msg or string.len(msg) == 0 then
		FP_Print(FP_MESSAGE_NO_AD_TEXT)
		return
	end

	FP_Print(FP_MESSAGE_START_AD)
	isAnnouncing = true
	lastAnnouncedTime = 0

	if FP_MenuFrameAnnounce then
		FP_MenuFrameAnnounce:SetText(FP_TEXT_STOP_AD)
		FP_StyleModernButton(FP_MenuFrameAnnounce, "rose", FP_TEXT_STOP_AD)
	end
	FP_UpdateStatusPills()

	-- Send initial announcement immediately during the current hardware click event
	FP_Announce()
	if MessageQueue and MessageQueue.Run and MessageQueue.GetNumPendingMessages and MessageQueue.GetNumPendingMessages() > 0 then
		MessageQueue.Run()
	end
end

function FP_StopAnnounce()
	if isAnnouncing then
		FP_Print(FP_MESSAGE_STOP_AD)
	end
	isAnnouncing = false
	lastAnnouncedTime = 0

	-- Clear any pending message in MessageQueue so no unwanted ad message is sent on/after stopping
	if MessageQueue and MessageQueue.Clear then
		MessageQueue.Clear()
	end

	if FP_MenuFrameAnnounce then
		FP_MenuFrameAnnounce:SetText(FP_TEXT_START_AD)
		FP_StyleModernButton(FP_MenuFrameAnnounce, "teal", FP_TEXT_START_AD)
	end
	FP_UpdateStatusPills()
end

function FP_EnableAnnounce()
	if not FP_MenuFrame then return end

	-- 2-row layout (height 96px for generous spacing)
	FP_MenuFrame:SetHeight(96)

	-- Row 1: Whisper & actions (top=-6, bottom=-32 aligned with Apply button)
	if FP_MenuFrameWh then
		FP_MenuFrameWh:ClearAllPoints()
		FP_MenuFrameWh:SetPoint("TOPLEFT", FP_MenuFrame, "TOPLEFT", 14, -13)
	end
	if FP_MenuFrameException then
		FP_MenuFrameException:ClearAllPoints()
		local yOff = -6
		if FP_MenuFrameApply and FP_MenuFrame and FP_MenuFrameApply:GetTop() and FP_MenuFrame:GetTop() then
			local calculated = FP_MenuFrameApply:GetTop() - FP_MenuFrame:GetTop()
			if calculated and calculated < 0 and calculated > -40 then
				yOff = calculated
			end
		end
		FP_MenuFrameException:SetPoint("TOPRIGHT", FP_MenuFrame, "TOPRIGHT", -20, yOff)
	end

	if FP_MenuFrame and not FP_MenuFrame.__fp_align_hooked then
		FP_MenuFrame.__fp_align_hooked = true
		FP_MenuFrame:HookScript("OnShow", function()
			if FP_MenuFrameAd and FP_MenuFrameAd:IsShown() and FP_MenuFrameException and FP_MenuFrameApply and FP_MenuFrameApply:GetTop() and FP_MenuFrame:GetTop() then
				local calculated = FP_MenuFrameApply:GetTop() - FP_MenuFrame:GetTop()
				if calculated and calculated < 0 and calculated > -40 then
					FP_MenuFrameException:ClearAllPoints()
					FP_MenuFrameException:SetPoint("TOPRIGHT", FP_MenuFrame, "TOPRIGHT", -20, calculated)
				end
			end
		end)
	end

	-- Row separator (Y=-43: 11px padding below Row 1 bottom -32; +1px top margin)
	if not FP_MenuFrame.__fp_row_sep then
		local rowSep = FP_MenuFrame:CreateTexture(nil, "ARTWORK", nil, 6)
		rowSep:SetHeight(1)
		rowSep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.08)
		FP_MenuFrame.__fp_row_sep = rowSep
	end
	if FP_MenuFrame.__fp_row_sep then
		FP_MenuFrame.__fp_row_sep:ClearAllPoints()
		FP_MenuFrame.__fp_row_sep:SetPoint("TOPLEFT", 14, -43)
		FP_MenuFrame.__fp_row_sep:SetPoint("TOPRIGHT", -14, -43)
		FP_MenuFrame.__fp_row_sep:Show()
	end

	-- Row 2: Ad announce controls (TOP=-55: 12px gap below separator Y=-43, height=24, bottom=-79)
	-- 1) Announce Button (bottom right, TOP=-55, height=24, bottom=-79)
	if FP_MenuFrameAnnounce then
		FP_MenuFrameAnnounce:ClearAllPoints()
		FP_MenuFrameAnnounce:SetPoint("TOPRIGHT", FP_MenuFrame, "TOPRIGHT", -20, -55)
		FP_MenuFrameAnnounce:SetSize(74, 24)
		if isAnnouncing then
			FP_StyleModernButton(FP_MenuFrameAnnounce, "rose", FP_TEXT_STOP_AD)
		else
			FP_StyleModernButton(FP_MenuFrameAnnounce, "teal", FP_TEXT_START_AD)
		end
		FP_MenuFrameAnnounce:Show()
	end

	-- 2) Ad Label (left margin 14, Center Y=-67 matches Announce button center)
	if FP_MenuFrameAd then
		FP_MenuFrameAd:ClearAllPoints()
		FP_MenuFrameAd:SetPoint("LEFT", FP_MenuFrame, "TOPLEFT", 14, -67)
		FP_MenuFrameAd:SetText(FP_LABEL_AD or FP_TEXT_AD_LABEL)
		FP_MenuFrameAd:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		FP_MenuFrameAd:Show()
	end

	-- 3) Ad EditBox (Explicit TOP=-55 to ensure clear gap below separator, BOTTOM=-79 matching button)
	if FP_MenuFrameAdText then
		FP_MenuFrameAdText:ClearAllPoints()
		FP_MenuFrameAdText:SetPoint("TOPLEFT", FP_MenuFrame, "TOPLEFT", 68, -55)
		FP_MenuFrameAdText:SetPoint("BOTTOMRIGHT", FP_MenuFrameAnnounce, "BOTTOMLEFT", -8, 0)
		FP_StyleModernEditBox(FP_MenuFrameAdText, "gold")
		if FP_UserDefinedAdMsg then
			FP_MenuFrameAdText:SetText(FP_UserDefinedAdMsg)
		end
		FP_MenuFrameAdText:Show()
	end

	-- Intercept MessageQueueFrame so clicking "Stop Ad" stops advertising instantly without sending queued message
	local mqf = _G["MessageQueueFrame"]
	if mqf and not mqf.__fp_stop_hooked then
		mqf.__fp_stop_hooked = true
		local origDown = mqf:GetScript("OnMouseDown")
		mqf:SetScript("OnMouseDown", function(self, btn, ...)
			if isAnnouncing then
				local overAnnounce = FP_MenuFrameAnnounce and FP_MenuFrameAnnounce:IsShown() and FP_MenuFrameAnnounce:IsMouseOver()
				local overTitlePill = FP_TitleFrameAnnouncing and FP_TitleFrameAnnouncing:IsShown() and FP_TitleFrameAnnouncing:IsMouseOver()
				if overAnnounce or overTitlePill then
					if MessageQueue and MessageQueue.Clear then
						MessageQueue.Clear()
					end
					FP_StopAnnounce()
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

	if FP_TitleFrameAnnouncing then
		FP_TitleFrameAnnouncing:Show()
	end

	FP_UpdateStatusPills()
	FP_UpdateWidthResponsiveUI()
end

function FP_DisableAnnounce(silent)
	if isAnnouncing then
		FP_StopAnnounce()
	end

	if FP_TitleFrameAnnouncing then
		FP_TitleFrameAnnouncing:Hide()
	end

	if FP_MenuFrameAd then FP_MenuFrameAd:Hide() end
	if FP_MenuFrameAdText then FP_MenuFrameAdText:Hide() end
	if FP_MenuFrameAnnounce then FP_MenuFrameAnnounce:Hide() end
	if FP_MenuFrame.__fp_row_sep then FP_MenuFrame.__fp_row_sep:Hide() end

	if FP_MenuFrameWh then
		FP_MenuFrameWh:ClearAllPoints()
		FP_MenuFrameWh:SetPoint("LEFT", FP_MenuFrame, "LEFT", 14, 0)
	end
	if FP_MenuFrameException then
		FP_MenuFrameException:ClearAllPoints()
		FP_MenuFrameException:SetPoint("RIGHT", FP_MenuFrame, "RIGHT", -20, 0)
	end

	if FP_MenuFrame then
		FP_MenuFrame:SetHeight(44)
	end

	if not silent then
		FP_Print(FP_MESSAGE_DISABLE_ANNOUNCE)
	end

	FP_UpdateStatusPills()
	FP_UpdateWidthResponsiveUI()
end

-------------------------------------------------
-- Close on empty space right click
-------------------------------------------------
function FP_CloseOnRightClick()
	-- Do NOT close if modifier keys (Alt, Ctrl, Shift) are held
	-- This completely prevents conflicts with Alt+RightClick (whisper tell) or other shortcuts
	if IsAltKeyDown() or IsControlKeyDown() or IsShiftKeyDown() then
		return false
	end

	CloseDropDownMenus()
	if FP_WhPresetFrame and FP_WhPresetFrame:IsShown() then
		FP_WhPresetFrame:Hide()
	end

	if FP_Options and FP_Options.lfgOnly then
		if FP_LFGPanel and FP_LFGPanel:IsShown() then
			FP_LFGPanel:Hide()
			PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE or 851)
			return true
		end
	else
		if FP_Frame and FP_Frame:IsShown() then
			FP_Frame:Hide()
			PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE or 851)
			return true
		end
	end
	return false
end

function FP_MenuClicked(self, button, menu, option)
	if menu == "MENU_FILTERDUNGEON" then
		if button == "MiddleButton" then
			FP_ToggleDungeonFilterView()
			return
		elseif button == "RightButton" then
			FP_ClearDungeonFilter()
			return
		end
	end

	if menu == "MENU_FILTERDUNGEON" or menu == "MENU_OPTION" then
		FP_HookDropDownLists()
		local anchor = self
		if not anchor or not anchor:IsShown() then
			anchor = (menu == "MENU_FILTERDUNGEON") and FP_ListFrameFilterDungeon or FP_TitleFrameOption
		end
		local initFunc = (menu == "MENU_FILTERDUNGEON") and FP_DropDownMenuFilterDungeon_Initialize or FP_DropDownMenuOption_Initialize

		local closeTime = FP_DropDownCloseTime or dropDownCloseTime or 0
		local isJustClosed = (GetTime() - closeTime) < 0.20
		local isCurrentlyOpen = DropDownList1 and DropDownList1:IsShown() and (UIDROPDOWNMENU_OPEN_MENU == FP_DropDownMenu)

		if isCurrentlyOpen or isJustClosed then
			CloseDropDownMenus()
			return
		end

		local targetScale = FP_GetDropdownTargetScale(anchor)
		FP_DropDownMenu.__fp_target_scale = targetScale
		for level = 1, 3 do
			local dl = _G["DropDownList"..level]
			if dl and dl.SetScale then
				dl:SetScale(targetScale)
				dl.__fp_scaled = true
			end
		end
		UIDropDownMenu_Initialize(FP_DropDownMenu, initFunc)
		ToggleDropDownMenu(1, nil, FP_DropDownMenu, anchor, 0, 0)
		FP_SkinAllDropDowns()
	elseif menu == "MENU_APPLY" then
		if shouterSelected then
			FP_Whisper(shouterSelected.name)
		else
			FP_Print(FP_MESSAGE_NOTARGET)
		end
	elseif menu == "MENU_WHISPER" then
		if shouterSelected then
			ChatFrame_SendTell(shouterSelected.name, FCF_GetCurrentChatFrame())
		else
			FP_Print(FP_MESSAGE_NOTARGET)
		end
	elseif menu == "MENU_WHO" then
		if shouterSelected then
			FP_SendWho(shouterSelected.name)
		else
			FP_Print(FP_MESSAGE_NOTARGET)
		end
	elseif menu == "MENU_EXCEPTION" then
		if shouterSelected then
			FP_Exception(shouterSelected.name)
		else
			FP_Print(FP_MESSAGE_NOTARGET)
		end
	elseif menu == "MENU_EXCEPTION_DELETE" then
		if FP_MenuFrameIgnoreText then
			FP_MenuFrameIgnoreText:SetText("")
		end
		FP_SetCustomIgnoreText()
		exceptionData = {}
		FP_Print(FP_MESSAGE_IGNORE_ALL_RESET or "Reset complete.")
		FP_Refresh(true)
	elseif menu == "APPLY_FILTER" then
		FP_SetCustomFilterText()
		FP_Print(FP_MESSAGE_APPLY_CUSTOM_FILTER)
	elseif menu == "IGNORE" then
		local text = FP_MenuFrameIgnoreText and FP_MenuFrameIgnoreText:GetText()
		if text and text:match("%S") then
			FP_SetCustomIgnoreText()
			FP_Print(string.format(FP_MESSAGE_APPLY_CUSTOM_IGNORE or "Filter applied: |cffCF6679%s|r", text))
			FP_Refresh(true)
		else
			FP_Print(FP_MESSAGE_IGNORE_EMPTY or "Please enter filter text.")
		end
	elseif menu == "MENU_ACTIVATE_BELLNWINDOW" then
		if FP_Options.activateBellnWindow then
			FP_ActiveBellnWindow(false)
		else
			FP_ActiveBellnWindow(true)
		end
	elseif menu == "MENU_ANNOUNCE" then
		if not MessageQueue then
			FP_Print(FP_MESSAGE_DISABLE_ANNOUNCE)
			return
		end
		if isAnnouncing then
			FP_StopAnnounce()
		else
			FP_StartAnnounce()
		end
	elseif menu == "MENU_ACTIVATION" then
		if FP_Options.activated then
			FP_Activate(false)
			FP_Options.useroffed = true
		else
			FP_Activate(true)
			FP_Options.useroffed = false
		end
	elseif menu == "MENU_INC" then
		FP_ListAdjust(INC)
	elseif menu == "MENU_DEC" then
		FP_ListAdjust(DEC)
	elseif menu == "MENU_MAX" then
		FP_ListAdjust(MAX)
	elseif menu == "MENU_MIN" then
		FP_ListAdjust(MIN)
	elseif menu == "MENU_INFO" then
		FP_ToggleHelpFrame()
	elseif menu == "SEL_SHOUT" then
		local index = self:GetID()
		local data = frameData[index]
		if not data then
			if button == "RightButton" then
				FP_CloseOnRightClick()
			end
			return
		end
		if button == "LeftButton" then
			if IsAltKeyDown() then
				shouterSelected = data
				FP_Whisper(shouterSelected.name)
			elseif IsShiftKeyDown() then
				shouterSelected = data
				FP_SendWho(shouterSelected.name)
			elseif IsControlKeyDown() then
				shouterSelected = data
				FP_Exception(shouterSelected.name)
			else
				if shouterSelected == data then
					shouterSelected = nil
				else
					shouterSelected = data
				end
			end
			FP_Refresh()
		elseif button == "RightButton" then
			if IsAltKeyDown() then
				shouterSelected = data
				ChatFrame_SendTell(shouterSelected.name, FCF_GetCurrentChatFrame())
			elseif FP_Options.rightButton then
				-- Ctrl + right click: whisper party leader



				if IsControlKeyDown() then
					shouterSelected = data
					FP_Whisper(shouterSelected.name)
				end
			end
		end
	end
end

function FP_IconClicked(self, button)
	if button == "LeftButton" then
		if IsAltKeyDown() then
			if FP_Minimap_Button:IsShown() then
				FP_Options.iconLocked = not FP_Options.iconLocked
				if FP_Options.iconLocked then
					FP_Print(FP_MESSAGE_ICON_LOCK)
					FP_Minimap_Button:RegisterForDrag(nil)
					GameTooltip:Hide()
				else
					FP_Print(FP_MESSAGE_ICON_UNLOCK)
					FP_Minimap_Button:RegisterForDrag("LeftButton")
					GameTooltip:Hide()
				end
			end
		elseif (IsControlKeyDown()) then
			if not MessageQueue then
				FP_Print(FP_MESSAGE_DISABLE_ANNOUNCE)
				return
			end
			if isAnnouncing then
				FP_StopAnnounce()
			else
				FP_StartAnnounce()
			end
		elseif (IsShiftKeyDown()) then
			if FP_Options.activated then
				FP_Activate(false)
				FP_Options.useroffed = true
			else
				FP_Activate(true)
				FP_Options.useroffed = false
			end
		else
			FP_Toggle(true)
		end
	elseif button == "RightButton" then
		FP_HookDropDownLists()
		local targetScale = FP_GetDropdownTargetScale(self or FP_Frame)
		FP_DropDownMenu.__fp_target_scale = targetScale
		for level = 1, 3 do
			local dl = _G["DropDownList"..level]
			if dl and dl.SetScale then
				dl:SetScale(targetScale)
				dl.__fp_scaled = true
			end
		end
		UIDropDownMenu_Initialize(FP_DropDownMenu, FP_DropDownMenuOption_Initialize)
		ToggleDropDownMenu(1, nil, FP_DropDownMenu, self, 0, 0)
		FP_SkinAllDropDowns()
	end
end

-----------------------------------
-- List frame functions
-----------------------------------
function FP_Refresh(quick)
	local listOffset = FauxScrollFrame_GetOffset(FP_ListFrameScrollFrame)
	if not listOffset then listOffset = 0 end

	if not quick then
		local sort_col = sortData.current_sort
		local ascd = sortData[sort_col]

		FP_ListSort(frameData, sort_col, ascd)
	end

	local maxScroll = 0
	local rowIdx = 1

	for i = 1, #frameData do
		local info = frameData[i]
		if info then

			-- Custom filter check
			--
			-- Custom filter function




			local filtered = FP_CustomFilter(info.msg)
			if (not FP_DungeonFilter(info.dungeon) or not FP_ExceptionFilter(info.name) or not filtered.flag) then
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


			if info.enabled and info.num > listOffset and rowIdx <= FP_Options.viewLines then
				local rowName = "FP_ListFrameRow"..tostring(rowIdx)
				if info.time <= 0 then
					if FP_Options["activateBellnWindow"] then
						PlaySoundFile("Interface\\AddOns\\SolaLFG\\SolaLFG.ogg")
						FP_Frame:Show()
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
					if FP_Category_Color[info.mode] then
						_G[rowName.."DungeonText"]:SetTextColor(FP_Category_Color[info.mode][1], FP_Category_Color[info.mode][2], FP_Category_Color[info.mode][3])
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
		local rowName = "FP_ListFrameRow"..tostring(i)
		local r = _G[rowName]
		if r then
			r:Hide()
			if r.__fp_sel_bg then r.__fp_sel_bg:Hide() end
			if r.__fp_gold_bar then r.__fp_gold_bar:Hide() end
		end
	end
	FauxScrollFrame_Update(FP_ListFrameScrollFrame, maxScroll, FP_Options.viewLines, 24)
end

function FP_ListAdjust(adjust)
	local newNumRow = 20
	local newWidth = 750

	FP_TitleFrame:SetWidth(newWidth)
	FP_ListFrame:SetWidth(newWidth)
	FP_MenuFrame:SetWidth(newWidth)

	local newHeight = 84 + (newNumRow * 24)
	FP_ListFrame:SetHeight(newHeight)

	FP_Position_Save.width = newWidth
	FP_Options.viewLines = newNumRow
	FP_ListMove()

	FP_UpdateWidthResponsiveUI(newWidth)
	FP_Refresh()
end
function FP_ListMove()
	FP_Position_Save.point, _, FP_Position_Save.relpoint, FP_Position_Save.x, FP_Position_Save.y = FP_ListFrame:GetPoint()
end

local fp_in_ui_resize = false
function FP_UIResize(scale)
	if fp_in_ui_resize then return end
	fp_in_ui_resize = true

	local sc = tonumber(scale) or 1.0
	sc = math.floor(sc * 20 + 0.5) / 20
	if FP_Options then
		FP_Options.scale = sc
	end

	if FP_Frame and FP_Frame.SetScale then
		FP_Frame:SetScale(sc)
	end

	if FP_LFGPanel and FP_LFGPanel.SetScale then
		if FP_Options and FP_Options.lfgOnly then
			FP_LFGPanel:SetScale(sc)
		else
			FP_LFGPanel:SetScale(1.0)
		end
	end

	if FP_LFG_FilterDrawer and FP_LFG_FilterDrawer:IsShown() and FP_LFG_AnchorDrawer then
		FP_LFG_AnchorDrawer()
	end

	-- Synchronize both sliders
	if FP_ScaleSlider and FP_ScaleSlider.SetValue then
		if math.abs((FP_ScaleSlider:GetValue() or 0) - sc) > 0.01 then
			FP_ScaleSlider:SetValue(sc)
		end
		if FP_ScaleSlider.__fp_label and FP_ScaleSlider.__fp_label.SetText then
			local pct = math.floor(sc * 100 + 0.5)
			FP_ScaleSlider.__fp_label:SetText(string.format("UI |cffD4A745%d%%|r", pct))
		end
		if FP_ScaleSlider.__fp_fill and FP_ScaleSlider.__fp_fill.SetWidth then
			local ratio = (sc - 0.5) / 1.5
			if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
			local w = FP_ScaleSlider:GetWidth()
			if w and w > 0 then
				FP_ScaleSlider.__fp_fill:SetWidth(math.max(1, w * ratio))
			end
		end
	end
	if FP_LFG_ScaleSlider and FP_LFG_ScaleSlider.SetValue then
		if math.abs((FP_LFG_ScaleSlider:GetValue() or 0) - sc) > 0.01 then
			FP_LFG_ScaleSlider:SetValue(sc)
		end
		if FP_LFG_ScaleSlider.__fp_label and FP_LFG_ScaleSlider.__fp_label.SetText then
			local pct = math.floor(sc * 100 + 0.5)
			FP_LFG_ScaleSlider.__fp_label:SetText(string.format("UI |cffD4A745%d%%|r", pct))
		end
		if FP_LFG_ScaleSlider.__fp_fill and FP_LFG_ScaleSlider.__fp_fill.SetWidth then
			local ratio = (sc - 0.5) / 1.5
			if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
			local w = FP_LFG_ScaleSlider:GetWidth()
			if w and w > 0 then
				FP_LFG_ScaleSlider.__fp_fill:SetWidth(math.max(1, w * ratio))
			end
		end
	end

	fp_in_ui_resize = false
end

function FP_FontResize()
	for i = 1, 28 do
		local rowName = "FP_ListFrameRow"..i
		for j = 1, 3 do
			local tempFrame = _G[rowName..colFrame[j]]
			local fontFile, unused, fontFlags = tempFrame:GetFont()
			tempFrame:SetFont(fontFile, FP_Options.fontsize, fontFlags)
		end
	end
end

function FP_SetListColor()
	if FP_TitleFrame then
		FP_TitleFrame:SetBackdropColor(SolaC.bgSidebar[1], SolaC.bgSidebar[2], SolaC.bgSidebar[3], SolaC.bgSidebar[4])
		FP_TitleFrame:SetBackdropBorderColor(0, 0, 0, 0.70)
	end
	if FP_ListFrame then
		FP_ListFrame:SetBackdropColor(SolaC.bgMain[1], SolaC.bgMain[2], SolaC.bgMain[3], SolaC.bgMain[4])
		FP_ListFrame:SetBackdropBorderColor(0, 0, 0, 0.70)
	end
	if FP_MenuFrame then
		FP_MenuFrame:SetBackdropColor(SolaC.bgSidebar[1], SolaC.bgSidebar[2], SolaC.bgSidebar[3], SolaC.bgSidebar[4])
		FP_MenuFrame:SetBackdropBorderColor(0, 0, 0, 0.70)
	end
end

function FP_SetListPosition()
	if FP_Position_Save.x and FP_Position_Save.y and FP_Position_Save.width and FP_Options.viewLines then
		local w = math.max(FP_MIN_WIDTH, math.min(FP_MAX_WIDTH, FP_Position_Save.width))
		FP_ListFrame:ClearAllPoints()
		FP_TitleFrame:SetWidth(w)
		FP_ListFrame:SetWidth(w)
		FP_MenuFrame:SetWidth(w)
		FP_ListFrame:SetPoint(FP_Position_Save.point, UIParent, FP_Position_Save.relpoint, FP_Position_Save.x, FP_Position_Save.y)
		FP_ListFrame:SetHeight(84 + (FP_Options.viewLines * 24))
		FP_UpdateWidthResponsiveUI(w)
	else
		FP_ListAdjust()
	end
end

-------------------------
-- Settings menu handlers
-------------------------
local function getChannel()
	table.wipe(FP_Option_Menu[1]["value"])
	local list = { GetChannelList() }
	for i = 1, #list do
		if i % 3 == 2 then
			table.insert(FP_Option_Menu[1]["value"], list[i])
		end
	end
end

local function setChannel(self, channel)
	if FP_Options["channel"][channel] then
		FP_Options["channel"][channel] = nil
	else
		FP_Options["channel"][channel] = true
	end
	-- Update chat channels
	local list = { GetChannelList() }
	for channelname, _ in pairs(FP_Options["channel"]) do
		local isValidChannel = false
		for i = 1, #list do
			if i % 3 == 2 and list[i] == channelname then
				isValidChannel = true
				break
			end
		end
		if not isValidChannel then
			FP_Options["channel"][channelname] = nil
		end
	end
end

local function setOption(self, option, number)
	if not option or not number then return end
	FP_Options[option] = number

	-- Apply size and font options
	if option == "scale" then
		FP_UIResize(FP_Options.scale)
		if FP_ScaleSlider then
			FP_ScaleSlider:SetValue(tonumber(FP_Options.scale) or 1.0)
		end
	elseif option == "fontsize" then
		FP_FontResize()
	end

	-- Sync the submenu's radio state from the saved option. Compare against the
	-- configured values rather than the dropdown button's transient value,
	-- which can be cleared/reused by the legacy dropdown implementation.
	if UIDROPDOWNMENU_MENU_LEVEL == 2 then
		for _, tbl in ipairs(FP_Option_Menu) do
			if tbl.dbname == option then
				for i = 1, #(tbl.value or {}) do
					local button = _G["DropDownList2Button"..i]
					local check = _G["DropDownList2Button"..i.."Check"]
					local selected = tonumber(FP_Options[option]) == tonumber(tbl.value[i])
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
		FP_Options.color.r, FP_Options.color.g, FP_Options.color.b = ColorPickerFrame:GetColorRGB()
		FP_Options.color.opacity = OpacitySliderFrame:GetValue()
	else
		FP_Options.color=previousValues
	end

	FP_SetListColor()
end

function FP_SetSpecialFrame(value)
	FP_Options.esc = value
	if FP_Options.esc then
		FP_EnsureSpecialFrame()
	else
		for i = #UISpecialFrames, 1, -1 do
			if (UISpecialFrames[i] == "FP_Frame") then
				table.remove(UISpecialFrames, i)
			end
		end
	end
end

function FP_Minimap_ButtonToggle(value)
	FP_Options.icon = value
	if FP_Options.icon then
		FP_Minimap_Button:Show()
	else
		FP_Minimap_Button:Hide()
	end
end

function FP_LoadDefaultWinPos()
	FP_Position_Save = {
		["point"] = "CENTER",
		["relpoint"] = "CENTER",
		["x"] = 0,
		["y"] = 0,
		["width"] = FP_Position_Save.width or 750
	}
	FP_Options.viewLines = FP_Options.viewLines or 20
	FP_SetListPosition()
end

function FP_LoadDefaultWinSize()
	FP_Position_Save = {
		["point"] = FP_Position_Save.point or "CENTER",
		["relpoint"] = FP_Position_Save.relpoint or "CENTER",
		["x"] = FP_Position_Save.x or 0,
		["y"] = FP_Position_Save.y or 0,
		["width"] = 750
	}
	FP_Options.viewLines = 20
	FP_Options.scale = 1
	FP_UIResize(FP_Options.scale)
	if FP_ScaleSlider then
		FP_ScaleSlider:SetValue(1.0)
	end
	FP_SetListPosition()
end

function FP_LoadDefaultOption()
	FP_Print(FP_MESSAGE_RESETALL)

	FP_Options = {}
	for k,v in pairs(FP_Default_Options) do
		FP_Options[k] = v
	end
	FP_Options.channel = {}
	for k,v in pairs(FP_Default_Options.channel) do
		FP_Options.channel[k] = v
	end
	FP_Options.color = {}
	for k,v in pairs(FP_Default_Options.color) do
		FP_Options.color[k] = v
	end

	FP_Filter_Dungeon = {}

	FP_Position_Save = {
		["point"] = "CENTER",
		["relpoint"] = "CENTER",
		["x"] = 0,
		["y"] = 0,
		["width"] = 750
	}
	FP_Minimap_Save = {
		ButtonRadius = 78,
		ButtonShown = true,
		ButtonPosition = 336,
		Angle = 0
	}
	if (FP_GetLocale and FP_GetLocale() or GetLocale()) ~= "koKR" then
		FP_Options.lfgOnly = true
		FP_Options.viewModeSelected = true
	end

	FP_Minimap_Button_UpdatePosition()
	FP_UIResize(FP_Options.scale)
	FP_SetListPosition()

	FP_Frame:Hide()
end

function FP_DropDownMenuOption_Initialize(frame, level, menu)
	level = level or 1
	local info
	if (level == 1) then
		local lastWasSep = false
		for _, tbl in ipairs(FP_Option_Menu) do
			local skip = false
			if (FP_GetLocale and FP_GetLocale() or GetLocale()) ~= "koKR" then
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
					info.checked = FP_Options[tbl.dbname] or false
					info.isNotRadio = true
					info.menuList = tbl.dbname
					info.value = tbl.value or nil
					if tbl.dbname == "color" then
						info.keepShownOnClick = false
						info.hasColorSwatch = true
						info.hasOpacity = true
						info.r = FP_Options.color.r
						info.g = FP_Options.color.g
						info.b = FP_Options.color.b
						info.opacity = FP_Options.color.opacity
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
				info.checked = FP_Options[menu][info.text]
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
				info.checked = tonumber(info.text) == tonumber(FP_Options[menu])
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
local function FP_IsSecretString(val)
	if val == nil then return false end
	if issecretvalue and issecretvalue(val) then return true end
	if type(val) ~= "string" then return true end
	local ok, _ = pcall(string.lower, val)
	return not ok
end

local function FP_FindDataByName(targetName)
	if not targetName or FP_IsSecretString(targetName) then return nil, nil end
	for i = 1, #frameData do
		local item = frameData[i]
		if item and item.name == targetName then
			return item, i
		end
	end
	return nil, nil
end

function FP_AddList(name, rawmsg, class)
	if not name or not rawmsg then return end
	if FP_IsSecretString(name) or FP_IsSecretString(rawmsg) then return end
	if class and FP_IsSecretString(class) then class = nil end

	local msg
	local t = GetTime()
	local existing, existingIdx = FP_FindDataByName(name)

	-- See if sender already exists in our frameData
	if existing then
		if (t - (existing.fullscan or 0)) < 90 then
			if rawmsg == existing.rawmsg then
				existing.time = 0
				return
			else
				msg = FP_FilterIgnoreText(rawmsg, FP_TOOLTIP_IGNORE_KEYWORDS, true)
				msg = removeQuestieLink(msg)
				if existing.dungeon_keyword and string.find(string.lower(msg), string.lower(existing.dungeon_keyword), 1, true) then
					existing.msg = msg
					existing.rawmsg = rawmsg
					existing.time = 0
					FP_Refresh(true)
					return
				end
			end
		end
	end

	-- Dungeon Parse
	local dungeon, color, dungeon_keyword = FP_DungeonParse(rawmsg)

	if dungeon then
		msg = FP_FilterIgnoreText(rawmsg, FP_TOOLTIP_IGNORE_KEYWORDS, true)
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

		FP_Refresh()
	end
end

function FP_RemoveList(name)
	if not name or FP_IsSecretString(name) then return end
	if shouterSelected and shouterSelected.name == name then
		shouterSelected = nil
	end

	local _, idx = FP_FindDataByName(name)
	if idx then
		table.remove(frameData, idx)
		FP_Refresh()
	end
end

function FP_RemoveAllList()
	frameData = {}
	shouterSelected = nil
	if not (FP_Options and FP_Options.lfgOnly) then
		FP_Refresh()
	end
end

function FP_Print(msg)
	if msg and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00SolaLFG: |cffffff00"..tostring(msg)) end
end

function FP_Nprint(msg)
	if msg and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(tostring(msg)) end
end

function FP_OnLoad()
	FP_InviteControlFrame:RegisterEvent("VARIABLES_LOADED")
	FP_InviteControlFrame:RegisterEvent("CHAT_MSG_CHANNEL")
	FP_InviteControlFrame:RegisterEvent("CHAT_MSG_SYSTEM")
	FP_InviteControlFrame:RegisterEvent("WHO_LIST_UPDATE")
	FP_InviteControlFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	FP_InviteControlFrame:RegisterEvent("ZONE_CHANGED")
	FP_InviteControlFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
	FP_InviteControlFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end

function FP_OnEvent(self, event, ...)
		if event == "PLAYER_LEVEL_UP" then
		if FP_WhAutoLevel then
			FP_RefreshAutoWhMsg()
		end
		return
	end

	if event == "VARIABLES_LOADED" then
		FP_InviteControlFrame:UnregisterEvent("VARIABLES_LOADED")
		FP_Init()
		return
	end

	-- Handle auto-deactivation events
	if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
		if FP_Options and (FP_Options.noraid or FP_Options.nopvp) then
			FP_AutoDeactivate()
		end
		return
	end

	-- Ignore events if disabled or in LFG-only mode
	if not FP_Options or not FP_Options.activated then return end
	if FP_Options.lfgOnly then return end

	if event == "CHAT_MSG_CHANNEL" then
		local arg1, arg2, _, _, _, _, _, _, arg9, _, _, arg12 = ...

		if not arg1 or not arg2 or not arg9 then return end

		-- Discard restricted secret strings immediately to prevent taint / crash
		if FP_IsSecretString(arg1) or FP_IsSecretString(arg2) or FP_IsSecretString(arg9) then
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

		-- now pass to FP_AddList()
		if FP_Options.channel and FP_Options.channel[arg9] then
			local name = Ambiguate(arg2, "none")
			local class = nil
			if arg12 and not FP_IsSecretString(arg12) then
				local ok, _, c = pcall(GetPlayerInfoByGUID, arg12)
				if ok then class = c end
			end
			FP_AddList(name, arg1, class)
		end
	end
end

function FP_OnUpdate(self, elapsed)
	-- 자동 광고 기능 (MessageQueue 설치 시, 애드온 탐색 활성화 여부와 무관하게 동작)
	if isAnnouncing then
		lastAnnouncedTime = lastAnnouncedTime + elapsed
		local interval = (FP_Options and FP_Options.interval) or 30
		if lastAnnouncedTime >= interval then
			FP_Announce()
			lastAnnouncedTime = 0
		end
	end
	-- Stop update if disabled or in LFG-only mode
	if not FP_Options or not FP_Options.activated then return end
	if FP_Options.lfgOnly then return end
	lastUpdatedTime = lastUpdatedTime + elapsed
	if lastUpdatedTime > FP_UPDATE_INTERVAL and #frameData > 0 then
		local i = 1
		while i <= #frameData do
			frameData[i].time = frameData[i].time + FP_UPDATE_INTERVAL

			if frameData[i].time > FP_Options.valid then
				FP_RemoveList(frameData[i].name)
			elseif frameData[i].ignored then
				FP_RemoveList(frameData[i].name)
			else
				i = i + 1
			end

		end
		lastUpdatedTime = 0

		FP_Refresh(true)
	end
end

------------------------
-- Window toggle
------------------------
function FP_Toggle(isUserClick)
	if isUserClick == nil then isUserClick = true end
	if FP_Options and FP_Options.lfgOnly then
		if not FP_LFGPanel and FP_LFG_Init then
			FP_LFG_Init()
		end
		if FP_ApplyLFGOnlyMode then
			FP_ApplyLFGOnlyMode()
		end
		if FP_LFGPanel then
			if FP_LFGPanel:IsShown() then
				FP_LFGPanel:Hide()
			else
				FP_LFGPanel:Show()
				if FP_LFGPanel.Layout then
					FP_LFGPanel:Layout()
				end
				if isUserClick and FP_LFG_OnUserOpen then
					FP_LFG_OnUserOpen()
				end
			end
		end
	else
		if FP_Frame:IsShown() then
			FP_Frame:Hide()
		else
			FP_Frame:Show()
			if isUserClick and FP_LFG_OnUserOpen then
				FP_LFG_OnUserOpen()
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
	local curLocale = (FP_GetLocale and FP_GetLocale() or GetLocale())

	if cmd == "card" or cmd == "카드" then
		if curLocale == "koKR" and FP_OpenCardChoiceFrame then
			FP_OpenCardChoiceFrame()
		end
		return
	elseif cmd == "update" or cmd == "udt" or cmd == "업데이트" or cmd == "notice" or cmd == "공지" then
		if FP_ShowUpdatePopup then
			FP_ShowUpdatePopup(true)
		end
		return
	elseif cmd == "test" or cmd == "테스트" then
		if FP_Options then
			if curLocale == "koKR" then
				FP_Options.viewModeSelected = false
			else
				FP_Options.viewModeSelected = true
				FP_Options.lfgOnly = true
			end
			FP_Options.lastShownUpdateNotice = nil
		end
		if curLocale == "koKR" and FP_OpenCardChoiceFrame then
			FP_OpenCardChoiceFrame()
		end
		if FP_ShowUpdatePopup then
			FP_ShowUpdatePopup(true)
		end
		return
	end
	FP_Toggle()
end
_G.SolaLFG_SlashCmd = SolaLFG_SlashCmd

SlashCmdList["SOLALFG"] = SolaLFG_SlashCmd

_G.SolaLFG = FP_Frame
_G.FindParty = FP_Frame

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
function FP_InviteFromChatLink(link)
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
	hooksecurefunc("SetItemRef", FP_InviteFromChatLink)
end



