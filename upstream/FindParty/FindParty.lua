-- 표시 버전은 TOC에서 직접 읽어옵니다. 버전업시 TOC에 Version을 변경하세요.
-- 업데이트 후 옵션 초기화 필요시 Revision 값을 증가시킨후 FP_Init을 변경하시기 바랍니다.
FP_DISPLAY_VERSION = C_AddOns.GetAddOnMetadata("FindParty", "version")
FP_Revision = 17

----------------------
-- 기본 변수들 선언 --
----------------------
FP_Version = 1
FP_Options = nil
FP_Filter_Dungeon = {}
FP_Filter_Dungeon_Personal = {}
FP_UserDefinedWhMsg = nil
FP_UserDefinedAdMsg = nil
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
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
	tile = false,
	tileEdge = true,
	edgeSize = 2,
	insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local lastUpdatedTime = 0
local lastAnnouncedTime = 0
local isAnnouncing = false
local isDungeonFiltering = false
local shouterSelected = nil
local frameData = {}
local exceptionData = {}
local custom_ignore_keywords = {}
local colName = {"time", "dungeon", "name", "msg"}
local colFrame = {"Dungeon", "Name", "Msg"}
local lastActivation = false

local FP_UPDATE_INTERVAL = 2
local PHARSING_MSG_LENGTH = 100
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
		value = {"30","45","60","90","120","300","600"},
	},
	[3] = {
		name = FP_OPTIONS_VALID,
		dbname = "valid",
		value = {"30","60","90","120","300","600"},
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
		name = FP_OPTIONS_SCALE,
		dbname = "scale",
		value = {"2","1.9","1.8","1.7","1.6","1.5","1.4","1.3","1.2","1.1","1","0.9","0.8","0.7","0.6","0.5"},
	},
	[7] = {
		name = FP_OPTIONS_COLOR,
		dbname = "color",
	},
	[8] = {
		name = "",
	},
	[9] = {
		name = FP_OPTIONS_ICON,
		dbname = "icon",
		exec = function(self) FP_Minimap_ButtonToggle(self.checked) end,
	},
	[10] = {
		name = FP_OPTIONS_ESC,
		dbname = "esc",
		exec = function(self) FP_SetSpecialFrame(self.checked) end,
	},
	[11] = {
		name = FP_OPTIONS_RIGHTBUTTON,
		dbname = "rightButton",
		exec = function(self) FP_Options.rightButton = self.checked end,
	},
	[12] = {
		name = FP_OPTIONS_PERSONALFILTER,
		dbname = "personalFilter",
		exec = function(self) FP_Options.personalFilter = self.checked
					if getDungeonFilterNum() > 0 then
						isDungeonFiltering = true
					end
					FP_SetDungeonFilterText()
		end,
	},
	[13] = {
		name = "",
	},
	--[[
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
	]]
	[14] = {
		name = "",
	},
	[15] = {
		name = FP_OPTIONS_RESET,
		dbname = "reset",
		value = {
			[1] = {
				name = FP_OPTIONS_RESETPOS,
				exec = function() FP_LoadDefaultWinPos() end,
			},
			[2] = {
				name = FP_OPTIONS_RESETSIZE,
				exec = function() FP_LoadDefaultWinSize() end,
			},
			[3] = {
				name = FP_OPTIONS_RESETALL,
				exec = function() FP_LoadDefaultOption() end,
			},
		},
	},
	[16] = {
		name = "",
	},
	[17] = {
		name = FP_TEXT_CLOSE,
		dbname = "close",
		exec = "",
	},
}

local FP_Default_Options= {
	["channel"] = { [FP_DEFAULT_PARTY_CHANNEL] = true },
	["color"] = { ["r"] = 0, ["g"] = 0, ["b"] = 0, ["opacity"] = 0.5, },
	["interval"] = 30,
	["valid"] = 60,
	["scale"] = 1,
	["fontsize"] = 13,
	["viewLines"] = 20,
	["titlebarVisible"] = true,
	["menubarVisible"] = true,
	["activated"] = true,
	["icon"] = true,
	["iconLocked"] = false,
	["activateBellnWindow"] = false,
	["rightButton"] = false,
	["personalFilter"] = false,
	["esc"] = false,
	--["noraid"] = true,
	--["nopvp"] = true,
}

--[[
	색상 rgb 코드
	보라 (40인 레이드) 0.745, 0.27, 0.84
	분홍 (20인 레이드) 1, 0.7, 0.7
	하늘 (10인 레이드) 0, 0.95, 1
	남색 (던전) 0.5 0.5 0.8
	노랑 (필드보스) 1, 0.7, 0
	녹색 (PvP) 0, 1, 0
	주황 (불성 리분 25인 레이드) 1, 0.5, 0
	청록 (법사세린 버전 10인 일반) 0, 1, 0.7
	빨강 (일분일초 버전 명예) 1, 0. 0
	파랑 (법사세린 버전 공찾) 0.2, 0.6, 0.8
]]
local FP_Category_Color = {
	["raid40"] = {0.745, 0.27, 0.84},
	["raid20"] = {1, 0.7, 0.7},
	["raid10"] = {0, 0.95, 1},
	--["field"] = {1, 0.7, 0},
	["dungeon"] = {0.5, 0.5, 0.8},
	["pvp"] = {0, 1, 0},
	["quest"] = {1, 1, 1},
}

------------------------
-- 미니맵 아이콘 설정 --
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
FP_Minimap_ButtonIcon:SetTexture("Interface\\AddOns\\FindParty\\SIM-Icon") --INV_Misc_Bag_10_Blue

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
	if FP_Options.iconLocked then return end
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
FP_Minimap_Button:SetScript("OnClick", function(self, button) FP_IconClicked(self, button) end)
FP_Minimap_Button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	local msg = ""
	for _,v in ipairs(FP_TOOLTIP_MINIMAP) do
		msg = msg..v
	end
	if FP_Options.activated then
		msg = msg..FP_TOOLTIP_MINIMAP_ON
	else
		msg = msg..FP_TOOLTIP_MINIMAP_OFF
	end
	if isAnnouncing then
		msg = msg..FP_TOOLTIP_MINIMAP_AD
	end
	if FP_Options.iconLocked then
		msg = msg..FP_TOOLTIP_MINIMAP_LOCK
	else
		msg = msg..FP_TOOLTIP_MINIMAP_NOLOCK
	end
	GameTooltip:AddLine(msg)
	GameTooltip:Show()
end)
FP_Minimap_Button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
FP_Minimap_Button:SetScript("OnEvent", FP_Minimap_Button_Init)

----------------
--  LDB 지원  --
----------------
LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("FindParty", 
{
	type = "launcher",
	text = FP_C_TITLE,
	icon = "Interface\\AddOns\\FindParty\\SIM-Icon",
	OnClick = function(self, button)
		FP_IconClicked(self, button)
	end,
	OnTooltipShow = function(self)
		local msg = ""
		for k,v in ipairs(FP_TOOLTIP_MINIMAP) do
			if k ~= 5 then
				msg = msg..v
			end
		end

		if FP_Options.activated then
			msg = msg..FP_TOOLTIP_MINIMAP_ON
		else
			msg = msg..FP_TOOLTIP_MINIMAP_OFF
		end
		if isAnnouncing then
			msg = msg..FP_TOOLTIP_MINIMAP_AD
		end
		GameTooltip:ClearLines()
		GameTooltip:AddLine(msg)
		GameTooltip:Show()
	end,
})

-----------------
-- 툴팁 테이블 --
-----------------
FP_Tooltip = {
	["DEFAULT"] = function(msg, frame, anchor, pX, pY)
		GameTooltip:SetOwner(frame, anchor, pX or 0, pY or 0)
		GameTooltip:ClearLines()
		GameTooltip:AddLine(msg)
		GameTooltip:Show()
	end,
	["LIST"] = function(self)
		local text = self.Msg.Text:GetText()
		if text then
			FP_Tooltip.DEFAULT(text, self.Name, "ANCHOR_TOPLEFT", 0, 0)
		end
	end,
	["SORTTIME"] = function(self)
		FP_Tooltip.DEFAULT(FP_TOOLTIP_SORT_TIME, self, "ANCHOR_TOPRIGHT")
	end,
	["FILTERDUNGEON"] = function(self)
		local msg = FP_TOOLTIP_DUNGEON_FILTER
		local desc = FP_GetDungeonFilterList()
		if desc then
			msg = msg..desc
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
	["ACTIVATE"] = function(self)
		local msg
		if FP_Options.activated then
			msg = FP_TOOLTIP_ACTIVATE_ON
		else
			msg = FP_TOOLTIP_ACTIVATE_OFF
		end
		FP_Tooltip.DEFAULT(msg, self, "ANCHOR_TOPRIGHT")
	end,
	["ANNOUNCE"] = function(self)
		local msg
		if isAnnouncing then
			msg = FP_TOOLTIP_AD_ON
		else
			msg = FP_TOOLTIP_AD_OFF
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
}

-------------------
-- 애드온 초기화 --
-------------------
function getDungeonFilterNum()
	local num = 0
	local filter_table = {}
	if FP_Options.personalFilter then
		filter_table = FP_Filter_Dungeon_Personal
	else
		filter_table = FP_Filter_Dungeon
	end

	for _, tbl in pairs(filter_table) do
		for _, tbl2 in pairs(tbl) do
			num = num + 1
		end
	end

	return num
end

function FP_Init()
	-- SavedVariables 에 저장된 버전과 현재 lua 파일 내의 버전이 다를경우 처리하는 부분
	if not (FP_Version == FP_Revision) then
		--FP_Debug("--  New version Init")

		-- FP_Version 값이 number 형식이 아닌 경우 강제 리셋
		if type(FP_Version) ~= "number" then
			FP_Print(FP_MESSAGE_NEWVERSION_RESET)
			if FP_DUNGEON_LIST then
				FP_DUNGEON_LIST = nil
			end
			FP_LoadDefaultOption()
		end

		FP_Version = FP_Revision
	end
	-- 옵션 테이블이 없을 경우 기본 옵션 테이블을 생성한다.
	if not FP_Options then
		FP_LoadDefaultOption()
	end

	-- 상단, 하단 프레임 설정 및 모양 변경
	if FP_Options.titlebarVisible then FP_TitleFrame:Hide() else FP_TitleFrame:Show() end
	FP_ListFrameBridgeToTitle:GetScript("OnClick")()
	if FP_Options.menubarVisible then FP_MenuFrame:Hide() else FP_MenuFrame:Show() end
	FP_ListFrameBridgeToMenu:GetScript("OnClick")()
	FP_ListFrame:SetClampedToScreen(true)

	-- UI 설정 및 모양 변경
	FP_FontResize()
	FP_SetListColor()
	FP_SetListPosition()
	FP_UIResize(FP_Options.scale)
	if FP_Options.esc then tinsert(UISpecialFrames, "FP_Frame") end

	--미니맵 아이콘 설정
	if FP_Minimap_Button and not FP_Options.icon then FP_Minimap_Button:Hide() end

	--광고글 설정
	if FP_UserDefinedAdMsg then FP_MenuFrameAdText:SetText(FP_UserDefinedAdMsg) end
	if FP_UserDefinedWhMsg then FP_MenuFrameWhText:SetText(FP_UserDefinedWhMsg) end

	--귓속말 설정
	if FP_UserDefinedWhMsg then FP_MenuFrameWhText:SetText(FP_UserDefinedWhMsg) end

	-- 필터 문자열 설정
	if FP_UserDefineFilterMsg then FP_MenuFrameFilterText:SetText(FP_UserDefineFilterMsg) end

	if getDungeonFilterNum() > 0 then
		isDungeonFiltering = true
	end
	FP_SetDungeonFilterText()

	-- 무시할 문자열 설정
	if FP_UserDefinedIgnoreMsg ~= "" then
		FP_MenuFrameIgnoreText:SetText(FP_UserDefineIgnoreMsg)
		FP_SetCustomIgnoreText()
	end

	-- MessageQueue 애드온 설치 검사
	if not MessageQueue then
		FP_DisableAnnounce()
	end

	-- 스크롤 초기화
	FP_InitScrollBox()

	-- 애드온 활성화
	FP_Activate(FP_Options.activated, true)
	if FP_Options.activateBellnWindow then
		FP_ActiveBellnWindow(true)
	end
	if FP_Options.activated then
		lastActivation = true
	end
end

function FP_Hardcore()
	table.remove(FP_DUNGEON_KEYWORDS, 3) -- PvP 카테고리 삭제
end

---------------
-- 던전 파싱 --
---------------
local function normalizeFullWidth(msg)
	-- 한글 전각 문자 ASCII로 치환
	msg = msg:gsub("＆", "&")
	msg = msg:gsub("＋", "+")
	msg = msg:gsub("／", "/")
	return msg
end

-- 유아원때일진님 파티찾기에서 참조 // 문자열 필터링 함수
function FP_FilterIgnoreText(msg, ignoreTextTable, isTooltip)
	local tempMsg
	if not msg then return tempMsg end
	tempMsg = msg
	if not isTooltip then
		-- 공백제거
		--tempMsg = string.gsub(tempMsg, " ", "")
		-- 전각 문자 ASCII 치환
		tempMsg = normalizeFullWidth(tempMsg)
		-- 대문자로 변환
		tempMsg = string.upper(tempMsg)
		-- 다시체크
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
	-- 문자열 파싱 시작
	-- 모든 부분을 파싱하지 않고 앞부분만 짤라냄
	local nmsg = string.sub(msg, 1, PHARSING_MSG_LENGTH)
	if not nmsg then return dungeon end
	local nmsg_dungeon = msg
	if (nmsg_dungeon == nil) then
		return dungeon
	end

	-- 던전을 찾는다(인덱스 테이블이라 순서가 섞일 우려가 없기 때문에, 잡다한 처리는 모조리 삭제. 가장 최근에 출시된 인던으로 무조건 분류.. 어느정도 오분류는 감안하자)
	for _, tbl in ipairs(FP_DUNGEON_KEYWORDS) do
		for _, tbl2 in ipairs(tbl.dungeon) do
			for i = 1, #tbl2.keywords do
				local keyword = tbl2.keywords[i]
				if string.find(nmsg_dungeon, keyword) then
					local breaking
					if tbl2.excludekeywords then
						breaking = false
						for j = 1, #tbl2.excludekeywords do
							if string.find(nmsg_dungeon, tbl2.excludekeywords[j]) then
								breaking = true
							end
						end
						if breaking then break end
					end
					breaking = false
					for j = 1, #FP_GLOBAL_EXCLUDE_KEYWORDS do
						if string.find(nmsg_dungeon, FP_GLOBAL_EXCLUDE_KEYWORDS[j]) then
							breaking = true
						end
					end
					if breaking then break end
					-- 사용자 정의 무시할 문자열 체크
					if #custom_ignore_keywords > 0 then
						for j = 1, #custom_ignore_keywords do
							if string.find(nmsg_dungeon, custom_ignore_keywords[j]) then
								breaking = true
							end
						end
						if breaking then break end
					end
					-- 운다손, 갈레온손 같은 문자열 제거
					local ignore = false
					for i = 1, #FP_DUNGEON_IGNORE_POSTFIX_KEYWORDS do
						if string.find(nmsg_dungeon, keyword..FP_DUNGEON_IGNORE_POSTFIX_KEYWORDS[i]) then
							ignore = true
							break
						end
					end
					if ignore then break end
					dungeon = tbl2.name
					dungeon_keyword = keyword
					color = tbl2.color
					break
				end
			end
			if dungeon then break end
		end
		if dungeon then break end
	end
	-- 디버깅용
	-- print("---")
	-- print(dungeon..", "..color)

	return dungeon, color, dungeon_keyword
end

----------------------
-- 하이퍼 링크 삭제 --
----------------------
local function removeHyperLink(msg)
	if not msg then return msg end

	msg = msg:gsub("|H([^:|]+):.-|h(.-)|h", function(linkType, displayText)
		linkType = linkType:lower()

		if linkType == "item" then
			return "|r" .. displayText .. "|r"
		elseif linkType == "quest" then
			return "|r" .. displayText .. "|r"
		end

		return displayText
	end)

	msg = msg:gsub("%[%[(%d+%+?)%]%s*(.-)%s*%(%d+%)%]", "[%1] %2")
	msg = msg:gsub("%[%[(%d+%+?)%]%s*(.-)%]", "[%1] %2")

	return msg
end

-------------------
-- 난이도 필터링 --
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

function FP_DropDownMenuFilterDungeon_Initialize(frame, level, menu)
	level = level or 1
	local info
	local filter_table = {}
	if FP_Options.personalFilter then
		filter_table = FP_Filter_Dungeon_Personal
	else
		filter_table = FP_Filter_Dungeon
	end
	if (level == 1) then
		for idx, tbl in ipairs(FP_DUNGEON_KEYWORDS) do
			if #tbl.dungeon == 1 then
				-- 항목이 하나뿐인 카테고리는 서브메뉴 없이 바로 체크박스
				for _, tbl2 in ipairs(tbl.dungeon) do
					info = UIDropDownMenu_CreateInfo()
					info.text = tbl2.name
					info.keepShownOnClick = true
					info.disabled = false
					info.hasArrow = false
					info.isNotRadio = true
					info.func = FP_FilterDungeonSelected
					info.checked = (filter_table[tbl.category] and filter_table[tbl.category][tbl2.name]) or false
					info.arg1 = tbl2.name
					info.arg2 = nil
					UIDropDownMenu_AddButton(info, level)
				end
			else
				info = UIDropDownMenu_CreateInfo()
				info.text = tbl.category
				info.keepShownOnClick = true
				info.disabled = false
				info.hasArrow = true
				info.notCheckable = true
				info.menuList = idx
				UIDropDownMenu_AddButton(info, level)
			end
		end -- for key, subarray

		-- 한줄 비움 (직전 항목이 체크박스일 수 있어서 info를 새로 만든다)
		info = UIDropDownMenu_CreateInfo()
		info.text = ""
		info.disabled = true
		info.notCheckable = true
		UIDropDownMenu_AddButton(info, level)

		info.text = FP_DUNGEONFILTER_RESETALL
		info.func = function()
						if FP_Options.personalFilter then
							FP_Filter_Dungeon_Personal = {}
						else
							FP_Filter_Dungeon = {}
						end
						FP_SetDungeonFilterText()
						FP_Print(FP_MESSAGE_DUNGEON_RESET)
					end
		info.notCheckable = true
		info.disabled = false
		info.keepShownOnClick = false
		info.textR = 0.95
		info.textG = 0.30
		info.textB = 0.30
		info.arg1 = "resetall"
		info.arg2 = nil
		info.arg3 = nil
		UIDropDownMenu_AddButton(info, level)

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
			info.checked = (filter_table[FP_DUNGEON_KEYWORDS[menu].category] and filter_table[FP_DUNGEON_KEYWORDS[menu].category][info.text]) or false
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
	local filter_table = {}
	if FP_Options.personalFilter then
		filter_table = FP_Filter_Dungeon_Personal
	else
		filter_table = FP_Filter_Dungeon
	end

	-- 체크설정됨, 필터링 추가
	if checked then
		-- 빈 테이블일 경우 먼저 생성
		if not filter_table[category] then
			filter_table[category] = {}
		end
		if not filter_table[category][dungeon] then
			filter_table[category][dungeon] = {}
		end
	else
	-- 체크해제됨, 필터링 삭제
		filter_table[category][dungeon] = nil
		-- 빈 테이블 삭제
		local category_tables = 0
		for _, tbl in pairs(filter_table[category]) do
			category_tables = category_tables + 1
		end
		if category_tables == 0 then
			filter_table[category] = nil
		end
	end

	-- 던전 필터링 정보 텍스트 업데이트
	if getDungeonFilterNum() > 0 then
		isDungeonFiltering = true
	else
		isDungeonFiltering = false
	end
	FP_SetDungeonFilterText()

	-- 체크 항목 동기화 부분
	local idx = 1
	local loop = true
	-- 무한 루프 방지 (30미만)
	while loop and idx < 30 do
		local button = _G["DropDownList2Button"..idx]
		if button and button:GetText() then
			local button_text = button:GetText()
			if filter_table[category] and filter_table[category][button_text] then
				button.checked = true
				_G["DropDownList2Button"..idx.."Check"]:Show()
			else
				button.checked = false
				_G["DropDownList2Button"..idx.."Check"]:Hide()
			end
		else
			loop = false
			break
		end
		idx = idx + 1
	end

	local idx2 = 1
	local loop2 = true
	-- 무한 루프 방지 (10미만)
	while loop2 and idx2 < 15 do
		local button2 = _G["DropDownList3Button"..idx2]
		if button2 and button2.value then
			local button2_text = button2.value
			if filter_table[category] and filter_table[category][dungeon] and filter_table[category][dungeon][button2_text] then
				button2.checked = true
				_G["DropDownList3Button"..idx2.."Check"]:Show()
			else
				button2.checked = false
				_G["DropDownList3Button"..idx2.."Check"]:Hide()
			end
		else
			loop2 = false
			break
		end
		idx2 = idx2 + 1
	end

	if FP_Options.personalFilter then
		FP_Filter_Dungeon_Personal = filter_table
	else
		FP_Filter_Dungeon = filter_table
	end
end

function FP_GetDungeonFilterList()
	local desc = ""
	local i = 0
	local num = getDungeonFilterNum()
	local filter_table = {}
	if FP_Options.personalFilter then
		filter_table = FP_Filter_Dungeon_Personal
	else
		filter_table = FP_Filter_Dungeon
	end

	for _, tbl in pairs(filter_table) do
		for idx, _ in pairs(tbl) do
			i = i + 1
			-- 3개 마다 콤마
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
		desc = FP_DUNGEONFILTER_NONE
	end

	return desc
end

function FP_SetDungeonFilterText()
	local desc = FP_DUNGEONFILTER_NOT_FILTERED
	local filtered_count = getDungeonFilterNum()
	local filter_table = {}
	if FP_Options.personalFilter then
		filter_table = FP_Filter_Dungeon_Personal
	else
		filter_table = FP_Filter_Dungeon
	end

	if isDungeonFiltering and filtered_count > 1 then
		desc = string.format(FP_DUNGEONFILTER_MULTI, filtered_count)
	elseif isDungeonFiltering and filtered_count > 0 then
		for _, tbl in pairs(filter_table) do
			for idx, _ in pairs(tbl) do
				desc = string.format(FP_DUNGEONFILTER_SINGLE, idx)
			end
		end
	end

	FP_ListFrameFilterDungeonText:SetText(desc)
end

function FP_DungeonFilter(dungeon)
	local filter_table = {}
	if FP_Options.personalFilter then
		filter_table = FP_Filter_Dungeon_Personal
	else
		filter_table = FP_Filter_Dungeon
	end

	if isDungeonFiltering and getDungeonFilterNum() > 0 then
		for _, tbl in pairs(filter_table) do
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

--[[- 2016-10-23 아리보리(아즈샤라)
--
-- 사용자 필터 기능 추가.
-- 사용자가 직접 입력한 필터를 검사하여, 원하는 광고를 구체적으로 필터링 할 수 있다.
-- FP_CustomFiletr 함수는 광고 문자열을 인자로 받아, 사용자가 직접 입력한 문자들과 대조해
-- 입력한 문자열이 광고 문자열 내에 존재하면 true, 아니면 false를 반환한다.
-- -]]
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
-- 제외 필터링 --
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
-- 애드온의 기능들을 처리하는 함수들 --
---------------------------------------
function FP_Activate(active, noMsg)
	FP_Options.activated = active
	if active then
		if not noMsg then FP_Print(string.format(FP_MESSAGE_ACTIVE, FP_DISPLAY_VERSION)) end
		FP_TitleFrameText:SetText(FP_C_TITLE)
		FP_TitleFrameActivation:SetNormalTexture("Interface\\AddOns\\FindParty\\activated")
		FP_RemoveAllList()
		FP_Refresh()
	else
		if not noMsg then FP_Print(string.format(FP_MESSAGE_DEACTIVE, FP_DISPLAY_VERSION)) end
		FP_TitleFrameText:SetText(FP_C_TITLE.." "..FP_TEXT_STOPPED)
		FP_TitleFrameActivation:SetNormalTexture("Interface\\AddOns\\FindParty\\deactivated")
	end
end

function FP_ActiveBellnWindow(active)
	FP_Options.activateBellnWindow = active
	if active then
		FP_Print(FP_MESSAGE_POPUP_ACTIVE)
		FP_TitleFrameActivateBellnWindow:SetNormalTexture("Interface\\AddOns\\FindParty\\bellActivated")
	else
		FP_Print(FP_MESSAGE_POPUP_DEACTIVE)
		FP_TitleFrameActivateBellnWindow:SetNormalTexture("Interface\\AddOns\\FindParty\\bellDeactivated")
	end
end

local function GetShortClassName(class, spec)
	local short_Class = {
		["드루이드"] = {
			["조화"] = "조드",
			["야성"] = "야드",
			["회복"] = "회드"
		},
		["사냥꾼"] = {
			["야수"] = "야냥",
			["사격"] = "격냥",
			["생존"] = "생냥"
		},
		["마법사"] = {
			["비전"] = "비법",
			["화염"] = "화법",
			["냉기"] = "냉법"
		},
		["성기사"] = {
			["신성"] = "신기",
			["보호"] = "보기",
			["징벌"] = "징기"
		},
		["사제"] = {
			["수양"] = "수사",
			["신성"] = "신사",
			["암흑"] = "암사"
		},
		["도적"] = {
			["암살"] = "암살",
			["전투"] = "전투",
			["잠행"] = "잠행"
		},
		["주술사"] = {
			["정기"] = "정술",
			["고양"] = "고술",
			["복원"] = "복술"
		},
		["흑마법사"] = {
			["고통"] = "고흑",
			["악마"] = "악흑",
			["파괴"] = "파흑"
		},
		["전사"] = {
			["무기"] = "무전",
			["분노"] = "분전",
			["방어"] = "전탱"
		}
	}
	return short_Class[class][spec]
end

function FP_Whisper(target)
	if C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Chat) then
		FP_Print(FP_MESSAGE_RESTRICTION_CHAT)
		return
	end
	local msg = FP_MenuFrameWhText:GetText()
	FP_UserDefinedWhMsg = msg -- For save
	if (not msg or string.len(msg) == 0) then
		local playerClass = UnitClass("player")
		local myTalent = FP_GetMyTalent()
		if GetLocale() == "koKR" then
			myTalent = myTalent and GetShortClassName(playerClass, myTalent) or playerClass
			msg = string.format(FP_DEFAULT_WHISPER_SHORT, myTalent)
		else
			msg = string.format(FP_DEFAULT_WHISPER, myTalent, playerClass)
		end
	end

	C_ChatInfo.SendChatMessage(msg, "WHISPER", nil, target)
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
	if UnitLevel("player") < 10 then
		return nil
	end

	local configID = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(C_SpecializationInfo.GetActiveSpecGroup())
	local configInfo = configID and C_Traits.GetConfigInfo(configID)
	local treeID = configInfo and configInfo.treeIDs and configInfo.treeIDs[1]
	local groups = treeID and C_Traits.GetGroupDisplayInfoByTreeID(treeID)
	if not groups then
		return nil
	end

	local groupIDs, names = {}, {}
	for i = 1, #groups do
		local group = groups[i]
		groupIDs[i] = group.groupID
		names[group.groupID] = group.displayName
	end

	local bestName, maxPoints = nil, 0
	for _, info in ipairs(C_Traits.GetGroupCurrencyInfo(configID, groupIDs)) do
		local currency = info.currencyInfos[1]
		local spent = currency and currency.spent or 0
		if spent > maxPoints then
			bestName, maxPoints = names[info.traitNodeGroupID], spent
		end
	end

	if maxPoints > 0 then
		return bestName
	end

	return nil
end

function FP_Announce()
	if C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Chat) then
		return
	end
	local msg = FP_MenuFrameAdText:GetText()
	FP_UserDefinedAdMsg = msg -- For save
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
	FP_Print(FP_MESSAGE_START_AD)
	isAnnouncing = true
	lastAnnouncedTime = GetTime()

	FP_MenuFrameAnnounce:SetText(FP_TEXT_STOP_AD)
	FP_TitleFrameAnnouncing:SetNormalTexture(134149) -- Inv_misc_groupneedmore
end

function FP_StopAnnounce()
	FP_Print(FP_MESSAGE_STOP_AD)
	isAnnouncing = false
	lastAnnouncedTime = 0

	FP_MenuFrameAnnounce:SetText(FP_TEXT_START_AD)
	FP_TitleFrameAnnouncing:SetNormalTexture(134148) -- Inv_misc_grouplooking
end

function FP_IsAnnoucing()
	return isAnnouncing
end

function FP_DisableAnnounce()
	FP_TitleFrameAnnouncing:Hide()
	FP_TitleFrameActivateBellnWindow:ClearAllPoints() FP_TitleFrameActivateBellnWindow:SetPoint("LEFT", FP_TitleFrameActivation, "LEFT", 25, 0)
	FP_MenuFrameAd:Hide()
	FP_MenuFrameAdText:Hide()
	FP_MenuFrameAnnounce:Hide()
	FP_MenuFrameFilter:ClearAllPoints() FP_MenuFrameFilter:SetPoint("TOPLEFT", FP_MenuFrameWh, "TOPLEFT", 0, -27)
	FP_MenuFrameIgnore:ClearAllPoints() FP_MenuFrameIgnore:SetPoint("TOPLEFT", FP_MenuFrameWh, "TOPLEFT", 0, -54)
	FP_MenuFrame:SetHeight(135)
	FP_Print(FP_MESSAGE_DISABLE_ANNOUNCE)
end

------------------------------
-- UI 버튼 클릭시 처리 부분 --
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

local function RGBToHex(r, g, b)
    return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
end

local function FP_UpdateMenuFonts()
	local size = math.floor(FP_Options.fontsize * FP_Options.scale + 0.5)

	local buttonFont = _G.FP_MenuFont or CreateFont("FP_MenuFont")
	buttonFont:CopyFontObject(GameFontHighlight)
	local font, _, flags = buttonFont:GetFont()
	buttonFont:SetFont(font, size, flags)

	local titleFont = _G.FP_MenuTitleFont or CreateFont("FP_MenuTitleFont")
	titleFont:CopyFontObject(GameFontNormal)
	font, _, flags = titleFont:GetFont()
	titleFont:SetFont(font, size, flags)
end

local function FP_SetMenuFont(description, fontName)
	description:AddInitializer(function(frame)
		local fontString = frame.fontString
		if fontString then
			fontString:SetFontObject(fontName)
		end
	end)
end

function FP_ShowListDropDown(shouterSelected)
	local dungeon_name = shouterSelected.dungeon
	local dungeon_color = RGBToHex(FP_Category_Color[shouterSelected.mode][1], FP_Category_Color[shouterSelected.mode][2], FP_Category_Color[shouterSelected.mode][3])
	local ad_name = shouterSelected.name
	local ad_color = "|c"..select(4, GetClassColor(shouterSelected.class))

	local buttons = {
		{ _G.WHISPER, function() ChatFrame_SendTell(shouterSelected.name, FCF_GetCurrentChatFrame()) end },
		{ FP_TEXT_WHO, function() C_FriendList.SendWho(shouterSelected.name, Enum.SocialWhoOrigin.Chat) end },
		{ FP_TEXT_APPLY, function() FP_MenuClicked(nil, "LeftButton", true, "MENU_APPLY") end },
		{ FP_TEXT_EXCEPTION, function() FP_Exception(shouterSelected.name) end },
		{ "|cffffd100".._G.CLOSE.."|r", function() end },
	}

	FP_UpdateMenuFonts()

	local menu = MenuUtil.CreateContextMenu(UIParent, function(owner, rootDescription)
		FP_SetMenuFont(rootDescription:CreateTitle(dungeon_color..dungeon_name.."|r / "..ad_color..ad_name.."|r"), "FP_MenuTitleFont")
		for _, button in ipairs(buttons) do
			FP_SetMenuFont(rootDescription:CreateButton(button[1], button[2]), "FP_MenuFont")
		end
	end)

	if menu then
		menu:SetWidth(menu:GetWidth() - 20)
	end
end

function FP_MenuClicked(self, button, down, menu)
	if menu == "MENU_FILTERDUNGEON" then
		if button == "LeftButton" then
			local filtered_count = getDungeonFilterNum()
			if filtered_count > 0 and not isDungeonFiltering then
				toggleDungeonFilter()
				FP_SetDungeonFilterText()
				FP_Print(FP_MESSAGE_START_DUNGEON_FILTER)
			elseif filtered_count > 0 then
				toggleDungeonFilter()
				FP_SetDungeonFilterText()
				FP_Print(FP_MESSAGE_STOP_DUNGEON_FILTER)
			else
				FP_SortButtonClicked(self)
			end
			FP_Refresh()
		elseif button == "RightButton" then
			UIDropDownMenu_Initialize(FP_DropDownMenu, FP_DropDownMenuFilterDungeon_Initialize)
			ToggleDropDownMenu(1, nil, FP_DropDownMenu, FP_ListFrameFilterDungeon, 0, 0)
		end
	elseif menu == "MENU_OPTION" then
		UIDropDownMenu_Initialize(FP_DropDownMenu, FP_DropDownMenuOption_Initialize)
		ToggleDropDownMenu(1, nil, FP_DropDownMenu, FP_TitleFrameOption, 0, 0)
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
			C_FriendList.SendWho(shouterSelected.name, Enum.SocialWhoOrigin.Chat)
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
		exceptionData = {}
		FP_Print(FP_MESSAGE_CLEAR_EXCEPTION)
	elseif menu == "MENU_ANNOUNCE" then
		if not MessageQueue then
			return
		end
		if isAnnouncing then
			FP_StopAnnounce()
		else
			FP_StartAnnounce()
		end
	elseif menu == "APPLY_FILTER" then
		FP_SetCustomFilterText()
		FP_Print(FP_MESSAGE_APPLY_CUSTOM_FILTER)
	elseif menu == "IGNORE" then
		FP_SetCustomIgnoreText()
		if FP_MenuFrameIgnoreText:GetText() == "" then
			FP_Print(FP_MESSAGE_CUSTOM_IGNORE_RESET)
		else
			FP_Print(FP_MESSAGE_CUSTOM_IGNORE)
		end
		FP_Refresh(true)
	elseif menu == "MENU_ACTIVATE_BELLNWINDOW" then
		if FP_Options.activateBellnWindow then
			FP_ActiveBellnWindow(false)
		else
			FP_ActiveBellnWindow(true)
		end
	elseif menu == "MENU_ACTIVATION" then
		if FP_Options.activated then
			FP_Activate(false)
			lastActivation = false
		else
			if C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Chat) then
				FP_Print(FP_MESSAGE_RESTRICTION)
				return
			end
			FP_Activate(true)
			lastActivation = true
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
		for _, v in ipairs(FP_HELPS) do FP_Nprint(v) end
	elseif menu == "SEL_SHOUT" then
		local index = self:GetID()
		local data = frameData[index]
		if button == "LeftButton" and down then
			if IsAltKeyDown() then
				shouterSelected = data
				FP_Whisper(shouterSelected.name)
			elseif IsShiftKeyDown() then
				shouterSelected = data
				C_FriendList.SendWho(shouterSelected.name, Enum.SocialWhoOrigin.Chat)
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
				-- 2016.10.23 아리보리(아즈샤라) 추가

				-- 파티찾기 창을 띄워놓고 퀘스트를 하다가 자꾸 오른쪽 클릭 실수로 귓말은 보내게 되어
				-- Ctrl 키까지 눌러야 귓말이 가도록 수정
				if IsControlKeyDown() then
					shouterSelected = data
					FP_Whisper(shouterSelected.name)
				end
			else
				shouterSelected = data
				FP_ShowListDropDown(shouterSelected)
				FP_Refresh()
			end
		end
	elseif menu == "WHISPER_SHORTCUT" and button == "LeftButton" then
		local index = self:GetID()
		local data = frameData[index]
		shouterSelected = data
		ChatFrame_SendTell(shouterSelected.name, FCF_GetCurrentChatFrame())
	end
end

function FP_IconClicked(self, button)
	if button == "LeftButton" then
		if IsAltKeyDown() then
			if FP_Minimap_Button:IsShown() then
				FP_Options.iconLocked = not FP_Options.iconLocked
				if FP_Options.iconLocked then
					FP_Print(FP_MESSAGE_ICON_LOCK)
					GameTooltip:Hide()
				else
					FP_Print(FP_MESSAGE_ICON_UNLOCK)
					GameTooltip:Hide()
				end
			end
		elseif (IsShiftKeyDown()) then
			if FP_Options.activated then
				FP_Activate(false)
				lastActivation = false
			else
				if C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Chat) then
					FP_Print(FP_MESSAGE_RESTRICTION)
					return
				end
				FP_Activate(true)
				lastActivation = true
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
		else
			if FP_Frame:IsShown() then
				FP_Frame:Hide()
			else
				FP_Frame:Show()
			end
		end
	elseif button == "RightButton" then
		UIDropDownMenu_Initialize(FP_DropDownMenu, FP_DropDownMenuOption_Initialize)
		ToggleDropDownMenu(1, nil, FP_DropDownMenu, self, 0, 0)
	end
end

-----------------------------------
-- 목록 프레임을 처리하는 함수들 --
-----------------------------------
local FP_ScrollBoxReady = false
local FP_ShownList = {}  -- 현재 스크롤 목록

local function FP_ApplyRowFont(row)
	for _, key in ipairs(colFrame) do
		local fontString = row[key].Text
		local fontFile, _, fontFlags = fontString:GetFont()
		fontString:SetFont(fontFile, FP_Options.fontsize, fontFlags)
	end
end

-- 행 하나를 info 내용으로 채움
local function FP_FillRow(row, info)
	-- 클릭/툴팁 처리는 row:GetID()로 frameData[index]를 찾는다
	row:SetID(info.index)

	row.Time.Text:SetText(info.time)
	row.Msg.Text:SetText(info.displayMsg)

	local dungeonText = row.Dungeon.Text
	local color = info.mode and FP_Category_Color[info.mode]
	if color then
		dungeonText:SetTextColor(color[1], color[2], color[3])
		if string.find(info.mode, "raid") then
			local postfix = string.gsub(info.mode, "raid", "")
			dungeonText:SetText(info.dungeon.." |cffff0000("..postfix..")")
		else
			dungeonText:SetText(info.dungeon)
		end
	else
		dungeonText:SetTextColor(1, 1, 1)
		dungeonText:SetText(info.dungeon)
	end

	local nameText = row.Name.Text
	local classColor = info.class and RAID_CLASS_COLORS[info.class]
	if classColor then
		nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
	else
		nameText:SetTextColor(1, 1, 1)
	end
	nameText:SetWordWrap(false)
	nameText:SetText(info.name)

	if info == shouterSelected then
		row:LockHighlight()
	else
		row:UnlockHighlight()
	end
end

local function FP_InitRow(row, info)
	FP_ApplyRowFont(row)
	FP_FillRow(row, info)
end

function FP_InitScrollBox()
	if FP_ScrollBoxReady then return end

	local scrollBox = FP_ListFrame.ScrollBox
	local scrollBar = FP_ListFrame.ScrollBar

	local view = CreateScrollBoxListLinearView()
	view:SetElementInitializer("FP_RowTemplate", FP_InitRow)
	view:SetElementExtent(25)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	-- 스크롤할 내용이 없으면 스크롤바 숨김
	local anchors = {
		CreateAnchor("TOPLEFT", FP_ListFrame, "TOPLEFT", 15, -30),
		CreateAnchor("BOTTOMRIGHT", FP_ListFrame, "BOTTOMRIGHT", -30, 10),
	}
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar, anchors, anchors)

	scrollBox:HookScript("OnShow", function() FP_Refresh() end)
	FP_ScrollBoxReady = true
end

local function FP_IsSameList(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

function FP_Refresh(quick)
	if not FP_ScrollBoxReady then return end

	if not quick then
		local sort_col = sortData.current_sort
		local ascd = sortData[sort_col]

		FP_ListSort(frameData, sort_col, ascd)
	end

	local list = {}
	for i = 1, #frameData do
		local info = frameData[i]
		if info then

			--[[- 2016-10-23 아리보리(아즈샤라)
			--
			-- 사용자 필터 기능 추가.
			-- 사용자가 직접 입력한 필터를 검사하여, 원하는 광고를 구체적으로 필터링 할 수 있다.
			-- FP_CustomFiletr 함수는 광고 문자열을 인자로 받아, 사용자가 직접 입력한 문자들과 대조해
			-- 입력한 문자열이 광고 문자열 내에 존재하면 true, 아니면 false를 반환한다.
			-- -]]
			local filtered = FP_CustomFilter(info.msg)
			if (not FP_DungeonFilter(info.dungeon) or not FP_ExceptionFilter(info.name) or not filtered.flag) then
				if info == shouterSelected then
					shouterSelected = nil
				end
				info.enabled = false
				info.num = nil
			else
				info.enabled = true
				info.num = #list + 1
				info.index = i
				info.displayMsg = filtered.msg
				list[info.num] = info

				if info.time <= 0 and FP_Options["activateBellnWindow"] then
					PlaySoundFile("Interface\\AddOns\\FindParty\\FindParty.ogg")
					FP_Frame:Show()
					info.time = 1
				end
			end
		end
	end

	local scrollBox = FP_ListFrame.ScrollBox
	if FP_IsSameList(FP_ShownList, list) then
		-- 구성과 순서가 같으면 보이는 행의 글자만 갱신 (툴팁/마우스오버가 끊기지 않음)
		scrollBox:ForEachFrame(function(row, info)
			info = info or row:GetElementData()
			if info then
				FP_FillRow(row, info)
			end
		end)
	else
		FP_ShownList = list
		scrollBox:SetDataProvider(CreateDataProvider(list), ScrollBoxConstants.RetainScrollPosition)
	end
end

function FP_ListAdjust(adjust)
	local newNumRow
	local curNumRow = FP_Options.viewLines
	if not adjust then
		local curHeight = FP_ListFrame:GetHeight()
		if curHeight > 540 then curHeight = 540 end
		newNumRow = math.floor((curHeight - 40) / 25)
	elseif (adjust == INC) then
		newNumRow = math.min(20, FP_Options.viewLines + 1)
	elseif (adjust == DEC) then
		newNumRow = math.max(1, FP_Options.viewLines - 1)
	elseif (adjust == MAX) then
		newNumRow = 20
	elseif (adjust == MIN) then
		newNumRow = 1
	end

	local newWidth = FP_ListFrame:GetWidth() or 750
	FP_TitleFrame:SetWidth(newWidth)
	FP_ListFrame:SetWidth(newWidth)
	FP_MenuFrame:SetWidth(newWidth)
	if newWidth < 1500 then
		FP_MenuFrameWhText:SetWidth(newWidth-210)
		FP_MenuFrameAdText:SetWidth(newWidth-210)
		FP_MenuFrameFilterText:SetWidth(newWidth-210)
		FP_MenuFrameIgnoreText:SetWidth(newWidth-210)
	end
	local newHeight = 40 + (newNumRow * 25)
	FP_ListFrame:SetHeight(newHeight)

	-- 구한값들을 저장
	FP_Position_Save.width = newWidth
	FP_Options.viewLines = newNumRow
	FP_ListMove()

	-- 화면 갱신
	FP_Refresh()
end

function FP_ListMove()
	FP_Position_Save.point, _, FP_Position_Save.relpoint, FP_Position_Save.x, FP_Position_Save.y = FP_ListFrame:GetPoint()
end

function FP_UIResize(scale)
	FP_Frame:SetScale(scale)
end

function FP_FontResize()
	if not FP_ScrollBoxReady then return end
	FP_ListFrame.ScrollBox:ForEachFrame(FP_ApplyRowFont)
end

function FP_SetListColor()
	FP_ListFrame:SetBackdropColor(FP_Options.color.r, FP_Options.color.g, FP_Options.color.b, FP_Options.color.opacity)
end

function FP_SetListPosition()
	if FP_Position_Save.x and FP_Position_Save.y and FP_Position_Save.width and FP_Options.viewLines then
		FP_ListFrame:ClearAllPoints()
		FP_TitleFrame:SetWidth(FP_Position_Save.width)
		FP_ListFrame:SetWidth(FP_Position_Save.width)
		FP_MenuFrame:SetWidth(FP_Position_Save.width)
		FP_ListFrame:SetPoint(FP_Position_Save.point, UIParent, FP_Position_Save.relpoint, FP_Position_Save.x, FP_Position_Save.y)
		if FP_Position_Save.width < 1500 then
			FP_MenuFrameWhText:SetWidth(FP_Position_Save.width-210)
			FP_MenuFrameAdText:SetWidth(FP_Position_Save.width-210)
			FP_MenuFrameFilterText:SetWidth(FP_Position_Save.width-210)
			FP_MenuFrameIgnoreText:SetWidth(FP_Position_Save.width-210)
		end
		FP_ListFrame:SetHeight(40 + (FP_Options.viewLines * 25))
	else
		FP_ListAdjust()
	end
end

-------------------------
-- 설정 메뉴 처리 부분 --
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
	-- 존재하지 않는 채널 제거
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

	-- 창 크기 및 폰트 옵션 변경 처리
	if option == "scale" then
		FP_UIResize(FP_Options.scale)
	elseif option == "fontsize" then
		FP_FontResize()
	end

	-- 체크표시 동기화를 위한 부분
	if UIDROPDOWNMENU_MENU_LEVEL == 2 then
		for _, tbl in ipairs(FP_Option_Menu) do
			if tbl.dbname == option then
				for i = 1, (#tbl.value or 1) do
					local button = _G["DropDownList2Button"..i]
					if FP_Options[option] == button.value then
						_G["DropDownList2Button"..i.."Check"]:Show()
					else
						_G["DropDownList2Button"..i.."Check"]:Hide()
					end
				end
			end
		end
	end
end

local function setWindowColor()
	local r, g, b = ColorPickerFrame:GetColorRGB()
	local a = 1.0
	if ColorPickerFrame.GetColorAlpha then
		a = ColorPickerFrame:GetColorAlpha()
	elseif ColorPickerFrame.hasOpacity then
		a = OpacitySliderFrame:GetValue()
	end

	FP_Options.color.r = r
	FP_Options.color.g = g
	FP_Options.color.b = b
	FP_Options.color.opacity = a

	FP_SetListColor()
end

local function cancelWindowColor(previousValues)
	previousValues = previousValues or ColorPickerFrame.previousValues
	if previousValues then
		local color = FP_Options.color
		color.r = previousValues.r
		color.g = previousValues.g
		color.b = previousValues.b
		color.opacity = previousValues.opacity or previousValues.a or 0.5
		FP_SetListColor()
	end
end

function FP_SetSpecialFrame(value)
	FP_Options.esc = value
	if FP_Options.esc then
		tinsert(UISpecialFrames, "FP_Frame")
	else
		for i = 1, #UISpecialFrames do
			local v = UISpecialFrames[i]
			if (v == "FP_Frame") then
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
	FP_Minimap_Save = {
		ButtonRadius = 78,
		ButtonShown = true,
		ButtonPosition = 336,
		Angle = 0
	}
	FP_Minimap_Button_UpdatePosition()
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
	FP_Filter_Dungeon_Personal = {}

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
	FP_Minimap_Button_UpdatePosition()
	FP_UIResize(FP_Options.scale)
	FP_SetListPosition()

	FP_Frame:Hide()
end

function FP_DropDownMenuOption_Initialize(frame, level, menu)
	level = level or 1
	local info
	if (level == 1) then
		for _, tbl in ipairs(FP_Option_Menu) do
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
			for i = 1, #UIDROPDOWNMENU_MENU_VALUE do
				info.text = UIDROPDOWNMENU_MENU_VALUE[i]
				info.checked = info.text == tostring(FP_Options[menu])
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
-- 이벤트 처리 부분 --
----------------------
function FP_AddList(name, rawmsg, class)
	local msg
	local msg_dungeon
	local t = GetTime()
	
	-- See if sender already exists in our frameData
	if frameData[name] then
		if (t - frameData[name].fullscan) < 90 then
			if rawmsg == frameData[name].rawmsg then
				frameData[name].time = 0
				return
			else
				msg = FP_FilterIgnoreText(rawmsg, FP_TOOLTIP_IGNORE_KEYWORDS, true)
				msg = removeHyperLink(msg)
				if string.find(msg, frameData[name].dungeon_keyword) then
					frameData[name].msg = msg
					frameData[name].rawmsg = rawmsg
					frameData[name].time = 0
					FP_Refresh(quick)
					return
				end
			end
		end
	end
	
	-- Dungeon Parse
	local dungeon, color, dungeon_keyword = FP_DungeonParse(rawmsg)
	
	if dungeon then
		msg = FP_FilterIgnoreText(rawmsg, FP_TOOLTIP_IGNORE_KEYWORDS, true)
		msg = removeHyperLink(msg)

		if frameData[name] then
			frameData[name].dungeon = dungeon
			frameData[name].dungeon_keyword = dungeon_keyword
			frameData[name].msg = msg
			frameData[name].rawmsg = rawmsg
			frameData[name].time = 0
			frameData[name].mode = color
			frameData[name].fullscan = t
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
			frameData[name] = info
		end

		FP_Refresh()
	end
end

function FP_RemoveList(name)
	if frameData[name] then
		if shouterSelected and shouterSelected.name == name then
			shouterSelected = nil
		end

		for i = 1, #frameData do
			if frameData[i].name == name then
				table.remove(frameData, i)
				break
			end
		end
		frameData[name] = nil
		FP_Refresh()
	end
end

function FP_RemoveAllList()
	frameData = {}
	shouterSelected = nil
end

function FP_Print(msg)
	if msg and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00FindParty: |cffffff00"..tostring(msg)) end
end

function FP_Nprint(msg)
	if msg and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(tostring(msg)) end
end

function FP_OnLoad()
	FP_InviteControlFrame:RegisterEvent("VARIABLES_LOADED")
	FP_InviteControlFrame:RegisterEvent("CHAT_MSG_CHANNEL")
	FP_InviteControlFrame:RegisterEvent("CHAT_MSG_SYSTEM")
	FP_InviteControlFrame:RegisterEvent("WHO_LIST_UPDATE")
	FP_InviteControlFrame:RegisterEvent("ENCOUNTER_START")
	FP_InviteControlFrame:RegisterEvent("ENCOUNTER_END")
end

function FP_OnEvent(self, event, ...)
	if event == "VARIABLES_LOADED" then
		FP_InviteControlFrame:UnregisterEvent("VARIABLES_LOADED")
		FP_Init()
		if C_GameRules.IsHardcoreActive() then
			FP_Hardcore()
		end
	end
	-- 자동 비활성화 기능 관련 이벤트 등록
	if event == "ENCOUNTER_START" and FP_Options.activated then
		FP_Print(FP_MESSAGE_RESTRICTION)
		FP_Activate(false)
	end

	if event == "ENCOUNTER_END" and lastActivation then
		FP_Activate(true)
	end

	-- 활성화 되어 있지 않을 경우 메세지 처리 안함
	if not FP_Options.activated then return end

	if event == "CHAT_MSG_CHANNEL" then
		local arg1, arg2, _, _, _, _, _, _, arg9, _, _, arg12 = ...
		
		-- 제외부터 필터
		if exceptionData then
			for _,v in pairs(exceptionData) do
				if arg1 == v then
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
		if arg1 and FP_Options.channel[arg9] then
			local name = Ambiguate(arg2, "none")
			local _, class = GetPlayerInfoByGUID(arg12)
			FP_AddList(name, arg1, class)
		end
	end
end

function FP_OnUpdate(self, elapsed)
	-- 자동 광고기능. 활성화 유무에 관련 없이 동작
	if isAnnouncing then
		lastAnnouncedTime = lastAnnouncedTime + elapsed

		if lastAnnouncedTime > FP_Options.interval then
			FP_Announce()
			lastAnnouncedTime = 0
		end
	end

	-- 비 활성화시 프레임 업데이트 안함
	if not FP_Options or not FP_Options.activated then return end
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
-- 슬래쉬 명령어 등록 --
------------------------
SLASH_FINDPARTY1 = "/FP"
SLASH_FINDPARTY2 = "/fp"
SLASH_FINDPARTY3 = "/findparty"

SlashCmdList["FINDPARTY"] = function(msg)
	if FP_Frame:IsShown() then
		FP_Frame:Hide()
	else
		FP_Frame:Show()
	end
end
