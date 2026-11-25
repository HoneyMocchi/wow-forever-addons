--[[
    SolaLFG_LFG.lua
    SolaLFG - WoW Forever 기본 파티 탐색기 (C_LFGList 기반 통합 패널)
    - ForeverIsParty의 C_LFGList 데이터 연동 및 커스텀 던전 매핑 이식
    - SolaLFG Sola Gold 다크 옵시디언 테마 일체화
    - 우측 접고 펼 수 있는 사이드 패널 및 Alt+클릭 빠른 귓속말 연동
]]

local SolaC = SolaFP_SolaC or {
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
	glassLine  = { 1.0, 1.0, 1.0, 0.06 },
	borderDark = { 0.0, 0.0, 0.0, 0.70 },
}

-- Use WoW's thin tooltip trim on the outer window. Inner rows keep
-- a flat surface so the title, filters, and recruitment text stand out.
local windowBackdrop = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 12,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
}
local SolaFP_Backdrop = SolaFP_Backdrop_Info or {
	bgFile   = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 1,
}

local function SolaFP_StyleCloseButton(btn)
	if _G.SolaFP_StyleCloseButton then
		return _G.SolaFP_StyleCloseButton(btn)
	end
	if not btn then return end
	btn:SetSize(22, 22)
	if BackdropTemplateMixin and not btn.SetBackdrop then
		Mixin(btn, BackdropTemplateMixin)
		btn:OnBackdropLoaded()
	end
	btn:SetBackdrop(SolaFP_Backdrop)
	btn:SetBackdropColor(1, 1, 1, 0.04)
	btn:SetBackdropBorderColor(0, 0, 0, 0.65)
	if btn.SetNormalTexture then btn:SetNormalTexture("") end
	local txt = btn:GetFontString()
	if not txt then
		txt = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		txt:SetPoint("CENTER", 0, 0)
		btn:SetFontString(txt)
	end
	txt:SetText("X")
	txt:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
end

local function SolaFP_StyleModernButton(btn, colorKey, customText)
	if _G.SolaFP_StyleModernButton then
		return _G.SolaFP_StyleModernButton(btn, colorKey, customText)
	end
	if not btn or not btn.IsObjectType or not btn:IsObjectType("Button") then return end
	if BackdropTemplateMixin and not btn.SetBackdrop then
		Mixin(btn, BackdropTemplateMixin)
		btn:OnBackdropLoaded()
	end
	if btn.SetNormalTexture then btn:SetNormalTexture("") end
	if btn.SetPushedTexture then btn:SetPushedTexture("") end
	if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
	if btn.SetHighlightTexture then btn:SetHighlightTexture("") end

	local r, g, b = SolaC.bgBtn[1], SolaC.bgBtn[2], SolaC.bgBtn[3]
	if colorKey == "teal" or colorKey == "primary" then
		r, g, b = SolaC.teal[1] * 0.42, SolaC.teal[2] * 0.42, SolaC.teal[3] * 0.42
	elseif colorKey == "dark" then
		r, g, b = 0.12, 0.11, 0.10
	end
	btn:SetBackdrop(SolaFP_Backdrop)
	btn:SetBackdropColor(r, g, b, 0.88)
	btn:SetBackdropBorderColor(0, 0, 0, 0.65)

	local fs = btn:GetFontString()
	if not fs then
		fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("CENTER")
		btn:SetFontString(fs)
	end
	if customText then fs:SetText(customText) end
	fs:SetTextColor(SolaC.fgMain[1], SolaC.fgMain[2], SolaC.fgMain[3])
end

local function SolaFP_StyleModernEditBox(eb, focusKey)
	if _G.SolaFP_StyleModernEditBox then
		return _G.SolaFP_StyleModernEditBox(eb, focusKey)
	end
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

	eb:SetBackdrop(SolaFP_Backdrop)
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

local function doWhisper(target)
	if _G.SolaFP_Whisper then
		_G.SolaFP_Whisper(target)
	elseif SendChatMessage and target then
		local msg = SolaFP_L["Hello, inquiring about your LFG listing."] or "파티 찾기 보고 귓 드립니다."
		SendChatMessage(msg, "WHISPER", nil, target)
	end
end

local function doSendWho(target)
	if _G.SolaFP_SendWho then
		_G.SolaFP_SendWho(target)
	elseif C_FriendList and C_FriendList.SendWho then
		C_FriendList.SendWho(target)
	elseif SendWho then
		SendWho(target)
	end
end

-------------------------------------------------
-- Dungeon and activity mapping data
-------------------------------------------------
local exactNames = {
	bfd = "검은 심연의 나락, 검은심연의 나락, 검은심연의나락, 검은 심연 나락, 검은심연 나락, 검은심연나락, Blackfathom Deeps",
	brd = "검은바위 나락, 검은바위나락, Blackrock Depths",
}

local definitions_ko = [[
rfc|성난불길 협곡|13-18|성불, rfc, ragefire chasm, ragefire
wc|통곡의 동굴|15-24|통곡, wc, wailing caverns
dm|죽음의 폐광|17-26|죽폐, 폐광, dm, deadmines, the deadmines, vc
sfk|그림자송곳니 성채|20-30|그송, 성채, 그림자송곳니, 그림자 송곳니, sfk, shadowfang keep, shadowfang
bfd|검은심연의 나락|24-32|검심, 나락, 검은심연, 검은 심연, bfd, blackfathom deeps, blackfathom
stk|스톰윈드 지하감옥|24-32|지하감옥, 스톰윈드, 지하 감옥, 감옥, stk, the stockade, stockade, stocks
gnomer|놈리건|29-38|gnomer, gnomeregan
rfk|가시덩굴 우리|29-38|가덩우리, 가덩 우리, 가시우리, 가시 우리, rfk, razorfen kraul, kraul
sm|붉은십자군 수도원|30-46|붉은 수도원, 수도원, sm, scarlet monastery, monastery
rfd|가시덩굴 구릉|37-46|가덩구릉, 가덩 구릉, 가시구릉, 가시 구릉, rfd, razorfen downs, downs
ulda|울다만|41-51|ulda, uldaman
zf|줄파락|44-54|zf, zul'farrak, zulfarrak
mara|마라우돈|46-55|마라, 마라우동, 우동, mara, maraudon
st|가라앉은 사원|50-60|아탈학카르 신전, sunken temple, temple of atal'hakkar, atal hakkar, st
brd|검은바위 나락|52-60|나락, brd, blackrock depths, depths
dire|혈투의 전장|54-60|혈투, dire maul
lbrs|검은바위 첨탑 하층|55-60|검바하층, lbrs, lower blackrock spire, lower spire
ubrs|검은바위 첨탑 상층|59-60|검바상층, ubrs, upper blackrock spire, upper spire
scholo|스칼로맨스|58-60|스칼, scholo, scholomance
strat|스트라솔름|58-60|솔름, strat, stratholme
hot|영주의 전당|13-18|영주, 전당, hot, hall of the lords, hall of the keepers
rol|로데론의 폐허|15-20|로데론 폐허, 로데론, 폐허, rol, ruins of lordaeron
excav|발굴 현장: 저습지|26-31|발굴 현장, 웰가르 발굴 현장, 웰가르의 발굴현장, 저습지, 웰가르, excav, excavation site, excavation site: wetlands
dal|달라란|28-33|달라란 도시, 달라란 시가지, dal, dalaran
drown|가라앉은 도시|35-40|침몰한 도시, 도시, drown, sunken city
krol|크롤도크 보루|40-45|크롤도크 요새, krol, kroldok, kroldok fortress
alcaz|알카즈 감옥|48-53|알카즈, alcaz, alcaz island
bmh|검은아귀 요새|55-60|bmh, blackfang, blackfang stronghold
shaper|구체자의 정원|58-60|형상술사의 테라스, 정원, shaper, garden of the shapers
ony|오닉시아의 둥지|60|오닉, 오닉시아 둥지, ony, onyxia, onyxia's lair
hyjal|하이잘 정상|60|하이잘, hyjal, mount hyjal
barrow|지하 심굴|60|심굴, barrow, the barrow dens, barrow dens
mc|화산 심장부|60|화심, mc, molten core
zg|줄구룹|60|zg, zul'gurub, zulgurub
bwl|검은날개 둥지|60|검둥, bwl, blackwing lair
aq20|안퀴라즈 폐허|60|안퀴20, aq20, ruins of ahn'qiraj
aq40|안퀴라즈 사원|60|안퀴40, aq40, temple of ahn'qiraj
naxx|낙스라마스|60|낙스, naxx, naxxramas
]]

local definitions_en = [[
rfc|Ragefire Chasm|13-18|rfc, ragefire, 성난불길 협곡, 성불
wc|Wailing Caverns|15-24|wc, wailing caverns, caverns, 통곡의 동굴, 통곡
dm|The Deadmines|17-26|dm, deadmines, the deadmines, vc, 죽음의 폐광, 죽폐, 폐광
sfk|Shadowfang Keep|20-30|sfk, shadowfang, shadowfang keep, 그림자송곳니 성채, 그송, 성채
bfd|Blackfathom Deeps|24-32|bfd, blackfathom, blackfathom deeps, deeps, 검은심연의 나락, 검심, 나락
stk|The Stockade|24-32|stk, the stockade, stockade, stocks, 스톰윈드 지하감옥, 지하감옥, 감옥
gnomer|Gnomeregan|29-38|gnomer, gnomeregan, 놈리건
rfk|Razorfen Kraul|29-38|rfk, razorfen kraul, kraul, 가시덩굴 우리, 가덩우리, 가시우리
sm|Scarlet Monastery|30-46|sm, scarlet monastery, monastery, 붉은십자군 수도원, 수도원
rfd|Razorfen Downs|37-46|rfd, razorfen downs, downs, 가시덩굴 구릉, 가덩구릉, 가시구릉
ulda|Uldaman|41-51|ulda, uldaman, 울다만
zf|Zul'Farrak|44-54|zf, zul'farrak, zulfarrak, 줄파락
mara|Maraudon|46-55|mara, maraudon, 마라우돈, 마라
st|Sunken Temple|50-60|sunken temple, temple of atal'hakkar, atal hakkar, st, 가라앉은 사원, 아탈학카르 신전
brd|Blackrock Depths|52-60|brd, blackrock depths, depths, 검은바위 나락, 나락
dire|Dire Maul|54-60|dire maul, dm, 혈투의 전장, 혈투
lbrs|Lower Blackrock Spire|55-60|lbrs, lower blackrock spire, lower spire, 검은바위 첨탑 하층, 검바하층
ubrs|Upper Blackrock Spire|59-60|ubrs, upper blackrock spire, upper spire, 검은바위 첨탑 상층, 검바상층
scholo|Scholomance|58-60|scholo, scholomance, 스칼로맨스, 스칼
strat|Stratholme|58-60|strat, stratholme, 스트라솔름, 솔름
hot|Hall of the Lords|13-18|hot, hall of the lords, hall of the keepers, 영주의 전당, 영주, 전당
rol|Ruins of Lordaeron|15-20|rol, ruins of lordaeron, 로데론의 폐허, 로데론 폐허, 폐허
excav|Excavation Site: Wetlands|26-31|excav, excavation site, wetlands, 발굴 현장: 저습지, 발굴 현장, 저습지
dal|Dalaran|28-33|dal, dalaran, 달라란, 달라란 도시
drown|Sunken City|35-40|drown, sunken city, 가라앉은 도시, 침몰한 도시
krol|Kroldok Fortress|40-45|krol, kroldok, kroldok fortress, 크롤도크 보루, 크롤도크 요새
alcaz|Alcaz Island|48-53|alcaz, alcaz island, 알카즈 감옥, 알카즈
bmh|Blackfang Stronghold|55-60|bmh, blackfang, blackfang stronghold, 검은아귀 요새
shaper|Garden of the Shapers|58-60|shaper, garden of the shapers, 구체자의 정원, 형상술사의 테라스
ony|Onyxia's Lair|60|ony, onyxia, onyxia's lair, 오닉시아의 둥지, 오닉
hyjal|Mount Hyjal|60|hyjal, mount hyjal, 하이잘 정상, 하이잘
barrow|The Barrow Dens|60|barrow, the barrow dens, barrow dens, 지하 심굴, 심굴
mc|Molten Core|60|mc, molten core, 화산 심장부, 화심
zg|Zul'Gurub|60|zg, zul'gurub, zulgurub, 줄구룹
bwl|Blackwing Lair|60|bwl, blackwing lair, 검은날개 둥지, 검둥
aq20|Ruins of Ahn'Qiraj|60|aq20, ruins of ahn'qiraj, 안퀴라즈 폐허, 안퀴20
aq40|Temple of Ahn'Qiraj|60|aq40, temple of ahn'qiraj, 안퀴라즈 사원, 안퀴40
naxx|Naxxramas|60|naxx, naxxramas, 낙스라마스, 낙스
]]

local definitions = ((SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) == "koKR") and definitions_ko or definitions_en

local dungeonCategories = {}
local dungeonLevels = {}
local nativeNameIndex = {}

local function normalize(s)
	if type(s) ~= "string" then return "" end
	return s:lower():gsub("'", ""):gsub("’", ""):gsub("…", " "):gsub("。", " "):gsub("　", " "):gsub("[%p%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
end

local function nameKey(name)
	return normalize(name):gsub("%s+", "")
end

for id, label, level, aliases in definitions:gmatch("([^|\r\n]+)|([^|\r\n]+)|([^|\r\n]+)|([^\r\n]*)") do
	dungeonLevels[id] = level
	if exactNames[id] then aliases = aliases .. ", " .. exactNames[id] end
	local defaults = label .. (label:find(" ", 1, true) and (", " .. label:gsub(" ", "")) or "") .. (aliases ~= "" and (", " .. aliases) or "")
	dungeonCategories[#dungeonCategories + 1] = { id = id, label = label, defaults = defaults }
end

for _, category in ipairs(dungeonCategories) do
	for name in category.defaults:gmatch("[^,]+") do
		local key = nameKey(name)
		if nativeNameIndex[key] == nil then
			nativeNameIndex[key] = category
		elseif nativeNameIndex[key] ~= category then
			nativeNameIndex[key] = false
		end
	end
end

local wings = {
	sm = { "붉은십자군 수도원 묘지", "붉은십자군 수도원 도서관", "붉은십자군 수도원 무기고", "붉은십자군 수도원 대성당",
	       "Scarlet Monastery - Graveyard", "Scarlet Monastery - Library", "Scarlet Monastery - Armory", "Scarlet Monastery - Cathedral" },
	dire = { "혈투의 전장 동쪽", "혈투의 전장 서쪽", "혈투의 전장 북쪽",
	         "Dire Maul - East", "Dire Maul - West", "Dire Maul - North" },
	strat = { "스트라솔름 정문", "스트라솔름 정비용 입구", "스트라솔름 후문",
	          "Stratholme - Main Gate", "Stratholme - Service Entrance" },
}
for _, category in ipairs(dungeonCategories) do
	for _, wing in ipairs(wings[category.id] or {}) do
		nativeNameIndex[nameKey(wing)] = category
	end
end

function SolaFP_LFG_GetDungeonDisplay(fullName, shortName)
	local category = type(fullName) == "string" and nativeNameIndex[nameKey(fullName)]
	if not category and type(shortName) == "string" then
		category = nativeNameIndex[nameKey(shortName)]
	end
	if category then
		return category.label, dungeonLevels[category.id]
	end
	return nil, nil
end

-------------------------------------------------
-- C_LFGList safe wrapper
-------------------------------------------------
local function safe(value)
	if value == nil then return nil end
	if issecretvalue and issecretvalue(value) then return nil end
	local ok = pcall(function()
		local t = type(value)
		if t == "string" then
			return value == ""
		elseif t == "number" then
			return value == 0
		elseif t == "boolean" then
			return value == false
		elseif t == "table" then
			return next(value)
		end
		return false
	end)
	if not ok then return nil end
	return value
end

local function api(name, ...)
	local call = C_LFGList and C_LFGList[name]
	if not call then return end
	local ok, first, second, third = pcall(call, ...)
	if ok then return safe(first), safe(second), safe(third) end
	return nil
end

local function plain(value)
	value = safe(value)
	if type(value) == "string" then
		-- In WoW 10.x/11.x, protected text tokens (|K...|k) must keep single pipes (|)
		-- Doubling pipes (||) breaks client token resolution and renders literal "lKt58lk"
		local ok, res = pcall(function()
			return (value:gsub("||([Kk])", "|%1"):gsub("[%c]", " "))
		end)
		if ok and res then return res end
	end
	return ""
end

-------------------------------------------------
-- Role icon strings
-------------------------------------------------
local roles = { TANK = SolaFP_L["Tank"] or "방어", HEALER = SolaFP_L["Healer"] or "치유", DAMAGER = SolaFP_L["Damage"] or "공격", NONE = "" }

local roleDefs = {
	TANK    = { flag = "tank",   atlas = "roleicon-tiny-tank",   color = "5A9BEF", text = SolaFP_L["Role_Tank_Short"] or "탱" },
	HEALER  = { flag = "healer", atlas = "roleicon-tiny-healer", color = "4CAF50", text = SolaFP_L["Role_Healer_Short"] or "힐" },
	DAMAGER = { flag = "dps",    atlas = "roleicon-tiny-dps",    color = "EF5350", text = SolaFP_L["Role_DPS_Short"] or "딜" },
}

local function formatSingleRole(roleKey, count)
	local def = roleDefs[roleKey]
	if not def then return "" end
	local icon = ""
	if CreateAtlasMarkup then
		local ok, markup = pcall(CreateAtlasMarkup, def.atlas, 15, 15)
		if ok and markup and markup ~= "" then
			icon = markup
		end
	end
	if icon == "" then
		icon = "|cff" .. def.color .. def.text .. "|r"
	end
	if count ~= nil and count > 0 then
		return icon .. "|cffffffff" .. count .. "|r"
	else
		return icon
	end
end

local function getRoleIcons(id, members, player)
	local counts = (members > 1) and api("GetSearchResultMemberCounts", id) or nil
	if members > 1 and type(counts) ~= "table" then
		local known = {}
		for index = 1, members do
			local member = api("GetSearchResultPlayerInfo", id, index)
			local role = type(member) == "table" and safe(member.assignedRole)
			if role and roles[role] and role ~= "NONE" then
				known[role] = (known[role] or 0) + 1
			end
		end
		counts = known
	end

	local flags = (type(player) == "table") and safe(player.lfgRoles) or nil
	local assigned = (type(player) == "table") and safe(player.assignedRole) or nil
	local out = {}

	local roleOrder = { "TANK", "HEALER", "DAMAGER" }
	for _, roleKey in ipairs(roleOrder) do
		local def = roleDefs[roleKey]
		local count = (type(counts) == "table") and tonumber(safe(counts[roleKey])) or nil
		local listed = (type(flags) == "table") and safe(flags[def.flag])
		if count ~= nil and count > 0 then
			out[#out + 1] = formatSingleRole(roleKey, count)
		elseif members == 1 and (listed or assigned == roleKey) then
			out[#out + 1] = formatSingleRole(roleKey)
		end
	end

	if #out > 0 then
		return table.concat(out, " ")
	end
	return ""
end

-------------------------------------------------
-- Note & Memo extraction helper
-------------------------------------------------
function SolaFP_LFG_GetItemNote(item)
	if not item then return nil end

	-- 1. Try querying C_LFGList fresh on demand using item.id
	local freshInfo
	if item.id and C_LFGList and C_LFGList.GetSearchResultInfo then
		local ok, res = pcall(C_LFGList.GetSearchResultInfo, item.id)
		if ok and type(res) == "table" then
			freshInfo = res
		end
	end

	-- Candidate 1: freshInfo.comment
	if freshInfo and freshInfo.comment then
		local c = plain(freshInfo.comment)
		if c ~= "" then return c end
	end

	-- Candidate 2: cached item.comment
	if item.comment and type(item.comment) == "string" and item.comment ~= "" then
		return item.comment
	end

	-- Candidate 3: freshInfo.name (if user entered note in title/name field)
	if freshInfo and freshInfo.name then
		local n = plain(freshInfo.name)
		if n ~= "" and n ~= item.group and n ~= item.activity and n ~= item.leader and n ~= (SolaFP_L["Unspecified Activity"] or "활동 미지정") and n ~= "활동 미지정" then
			return n
		end
	end

	-- Candidate 4: cached item.title (if user entered note in title)
	if item.title and type(item.title) == "string" then
		local t = item.title
		if t ~= "" and t ~= item.group and t ~= item.activity and t ~= item.leader and t ~= (SolaFP_L["Unspecified Activity"] or "활동 미지정") and t ~= "활동 미지정" then
			return t
		end
	end

	-- Candidate 5: Player or Leader info comments/notes
	if item.id and C_LFGList then
		if C_LFGList.GetSearchResultPlayerInfo then
			local ok, pInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, item.id, 1)
			if ok and type(pInfo) == "table" then
				local c = plain(pInfo.comment)
				if c ~= "" then return c end
				local n = plain(pInfo.notes)
				if n ~= "" then return n end
			end
		end
		if C_LFGList.GetSearchResultLeaderInfo then
			local ok, lInfo = pcall(C_LFGList.GetSearchResultLeaderInfo, item.id)
			if ok and type(lInfo) == "table" then
				local c = plain(lInfo.comment)
				if c ~= "" then return c end
				local n = plain(lInfo.notes)
				if n ~= "" then return n end
			end
		end
	end

	return nil
end

-------------------------------------------------
-- LFG panel state variables
-------------------------------------------------
SolaFP_LFGPanel = nil
local actionMenu = nil
local activitiesMenu = nil

local items = {}
local rows = {}
local offset = 0
local availableHeight = 540
local expandedGroups = {}
local selectedActivities = {}
local excludedActivities = {}
local isActivityFiltering = false
local activities = {}
local activityLevels = {}
local activityRows = {}
local activityOffset = 0

local function isDungeonOrRaidCategory(cId)
	if not cId then return false end
	if cId == 2 or cId == 3 then return true end
	local info = api("GetLfgCategoryInfo", cId)
	if type(info) == "table" and info.name then
		local name = plain(info.name):lower()
		if name:find("던전") or name:find("dungeon") or name:find("공격대") or name:find("raid") then
			return true
		end
	end
	return false
end

local function getDungeonCategories()
	local cats = {}
	local categories = api("GetAvailableCategories")
	if type(categories) == "table" and #categories > 0 then
		for _, id in ipairs(categories) do
			id = safe(id)
			if type(id) == "number" and isDungeonOrRaidCategory(id) then
				cats[#cats + 1] = id
			end
		end
	end
	if #cats == 0 then
		cats = { 2, 3 }
	end
	return cats
end

local function updateAvailableActivities()
	if not (C_LFGList and C_LFGList.GetAvailableActivities) then return end
	local cats = getDungeonCategories()
	for _, cId in ipairs(cats) do
		local acts = api("GetAvailableActivities", cId)
		if type(acts) == "table" then
			for _, actID in ipairs(acts) do
				local act = api("GetActivityInfoTable", safe(actID))
				if type(act) == "table" then
					local cat = safe(act.categoryID)
					if not cat or isDungeonOrRaidCategory(cat) then
						local dName, dRange = SolaFP_LFG_GetDungeonDisplay(safe(act.fullName), safe(act.shortName))
						if not dName or dName == "" then
							dName = safe(act.fullName)
							if not dName or dName == "" then dName = safe(act.shortName) end
						end
						if not dRange and act.minLevel and act.maxLevel then
							if act.minLevel == act.maxLevel then
								dRange = tostring(act.minLevel)
							else
								dRange = string.format("%d-%d", act.minLevel, act.maxLevel)
							end
						end
						if dName and dName ~= "" then
							activities[dName] = true
							if dRange then
								activityLevels[dName] = dRange
							end
						end
					end
				end
			end
		end
	end
end

local function getSelectedActivitiesCount()
	local count = 0
	for _, isSel in pairs(selectedActivities) do
		if isSel then count = count + 1 end
	end
	return count
end

local function getExcludedActivitiesCount()
	local count = 0
	for _, isEx in pairs(excludedActivities) do
		if isEx then count = count + 1 end
	end
	return count
end

function SolaFP_LFG_UpdateClearExcludedButton()
	local btn = SolaFP_LFG_ClearExcludedBtn
	if not btn then return end
	local exCount = getExcludedActivitiesCount()
	local fs = btn:GetFontString()
	local baseText = SolaFP_L["Clear Excluded"] or "초기화"
	if exCount > 0 then
		btn:SetText(string.format("%s (%d)", baseText, exCount))
		btn:SetBackdropColor(0.24, 0.10, 0.10, 0.92)
		btn:SetBackdropBorderColor(0.85, 0.38, 0.38, 0.85)
		if fs then
			fs:SetTextColor(1.0, 0.75, 0.75)
		end
	else
		btn:SetText(baseText)
		btn:SetBackdropColor(0.12, 0.11, 0.10, 0.85)
		btn:SetBackdropBorderColor(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.25)
		if fs then
			fs:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		end
	end
end

local function isGroupExpanded(groupName)
	if not groupName then return false end
	if expandedGroups[groupName] ~= nil then
		return expandedGroups[groupName] == true
	end
	-- Fresh results should show their listings immediately. Explicit clicks
	-- still close a dungeon, and searching only overrides that temporarily.
	return true
end

function SolaFP_LFG_UpdateDungeonButtonDisplay()
	local btn = SolaFP_LFG_DungeonBtn
	if not btn then return end
	local count = getSelectedActivitiesCount()
	local exCount = getExcludedActivitiesCount()
	local isFiltered = isActivityFiltering and (count > 0)
	local isEn = ((SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) ~= "koKR")
	local text = ""

	if not isFiltered then
		local baseText = SolaFP_DUNGEONFILTER_NOT_FILTERED or "모두 보기"
		text = baseText .. " |cffD4A745▼|r"
		btn:SetBackdropBorderColor(SolaC.goldMuted[1], SolaC.goldMuted[2], SolaC.goldMuted[3], 0.80)
	elseif count == 1 then
		local firstName = ""
		for name, isSel in pairs(selectedActivities) do
			if isSel then firstName = name break end
		end
		local shortName = firstName
		if isEn and #shortName > 12 then
			shortName = shortName:sub(1, 10) .. ".."
		elseif not isEn and #shortName > 15 then
			shortName = shortName:sub(1, 12) .. ".."
		end
		text = string.format(SolaFP_DUNGEONFILTER_SINGLE or "던전: %s", shortName) .. " |cff5ABFBA▼|r"
		btn:SetBackdropBorderColor(SolaC.teal[1] * 0.70, SolaC.teal[2] * 0.70, SolaC.teal[3] * 0.70, 0.90)
	else
		text = string.format(SolaFP_DUNGEONFILTER_MULTI or "던전: %d개 선택", count) .. " |cff5ABFBA▼|r"
		btn:SetBackdropBorderColor(SolaC.teal[1] * 0.70, SolaC.teal[2] * 0.70, SolaC.teal[3] * 0.70, 0.90)
	end

	local fs = btn:GetFontString()
	if fs then
		fs:SetText(text)
	end
	if SolaFP_LFG_UpdateClearExcludedButton then
		SolaFP_LFG_UpdateClearExcludedButton()
	end
end

local pending = false
local requestID = 0
local lastSearchTime = 0
local selectedID = nil
local dungeonCategory = nil
local parseSearchResults = nil

local function isPanelVisible()
	if not SolaFP_LFGPanel or not SolaFP_LFGPanel:IsShown() then return false end
	local parent = SolaFP_LFGPanel:GetParent()
	if parent and parent ~= UIParent then
		return parent:IsShown()
	end
	return true
end

-------------------------------------------------
-- Advanced LFG Filter Definitions & Logic
-------------------------------------------------
SolaFP_LFG_FilterDrawer = nil
SolaFP_LFG_FilterToggleBtn = nil
local SolaFP_LFG_DrawerWidgets = {}

local SolaFP_LFG_CLASS_LIST = {
	"WARRIOR", "PALADIN", "PRIEST",
	"SHAMAN",  "DRUID",   "ROGUE",
	"MAGE",    "WARLOCK", "HUNTER",
}

local SolaFP_LFG_CLASS_NAMES = {
	WARRIOR = SolaFP_L["Warrior"] or "전사",
	PALADIN = SolaFP_L["Paladin"] or "성기사",
	PRIEST  = SolaFP_L["Priest"] or "사제",
	SHAMAN  = SolaFP_L["Shaman"] or "주술사",
	DRUID   = SolaFP_L["Druid"] or "드루이드",
	ROGUE   = SolaFP_L["Rogue"] or "도적",
	MAGE    = SolaFP_L["Mage"] or "마법사",
	WARLOCK = SolaFP_L["Warlock"] or "흑마법사",
	HUNTER  = SolaFP_L["Hunter"] or "사냥꾼",
}

local SolaFP_LFG_CLASS_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 },
	MAGE    = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE   = { 0.49609375, 0.7421875, 0, 0.25 },
	DRUID   = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER  = { 0, 0.25, 0.25, 0.5 },
	SHAMAN  = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST  = { 0.49609375, 0.7421875, 0.25, 0.5 },
	WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 },
}

local SolaFP_LFG_CLASS_FALLBACK_COLORS = {
	WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
	PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
	HUNTER  = { r = 0.67, g = 0.83, b = 0.45 },
	ROGUE   = { r = 1.00, g = 0.96, b = 0.41 },
	PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
	SHAMAN  = { r = 0.00, g = 0.44, b = 0.87 },
	MAGE    = { r = 0.25, g = 0.78, b = 0.92 },
	WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
	DRUID   = { r = 1.00, g = 0.49, b = 0.04 },
}

local function SolaFP_LFG_GetClassColor(token)
	if RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] then
		return RAID_CLASS_COLORS[token]
	end
	return SolaFP_LFG_CLASS_FALLBACK_COLORS[token] or { r = 0.8, g = 0.8, b = 0.8 }
end

local function SolaFP_LFG_GetClassIconMarkup(token)
	local c = SolaFP_LFG_CLASS_COORDS[token]
	if not c then return "" end
	local l, r, t, b = math.floor(c[1] * 256), math.floor(c[2] * 256), math.floor(c[3] * 256), math.floor(c[4] * 256)
	return string.format("|TInterface\\TargetingFrame\\UI-Classes-Circles:13:13:0:0:256:256:%d:%d:%d:%d|t", l, r, t, b)
end

local function SolaFP_LFG_GetRoleIconMarkup(roleKey)
	local def = roleDefs and roleDefs[roleKey]
	if not def then return "" end
	if CreateAtlasMarkup then
		local ok, markup = pcall(CreateAtlasMarkup, def.atlas, 13, 13)
		if ok and markup and markup ~= "" then
			return markup
		end
	end
	return "|cff" .. def.color .. def.text .. "|r"
end

local SolaFP_LFG_DEFAULT_FILTERS = {
	-- 파티 구인 조건 (기본 false: 제약 없음)
	tankAvailable   = false,
	healerAvailable = false,
	damageAvailable = false,
	hasTank         = false,
	hasHealer       = false,
	excludePartyClasses = false,

	-- 구직자 역할 필터 (기본 모두 true: 제한 없음)
	soloRoleTank   = true,
	soloRoleHealer = true,
	soloRoleDamage = true,

	-- 구직자 레벨 범위 (0 = 제한 없음)
	soloMinLevel = 0,
	soloMaxLevel = 0,

	-- 구직자 직업 필터 (기본 모두 true)
	soloClasses = {
		WARRIOR = true,
		PALADIN = true,
		PRIEST  = true,
		SHAMAN  = true,
		DRUID   = true,
		ROGUE   = true,
		MAGE    = true,
		WARLOCK = true,
		HUNTER  = true,
	},
}

local function SolaFP_LFG_GetFilters()
	if not SolaFP_Options then return SolaFP_LFG_DEFAULT_FILTERS end
	if not SolaFP_Options.lfgFilters then
		local f = {}
		for k, v in pairs(SolaFP_LFG_DEFAULT_FILTERS) do
			if type(v) == "table" then
				f[k] = {}
				for k2, v2 in pairs(v) do f[k][k2] = v2 end
			else
				f[k] = v
			end
		end
		SolaFP_Options.lfgFilters = f
	end
	for k, v in pairs(SolaFP_LFG_DEFAULT_FILTERS) do
		if SolaFP_Options.lfgFilters[k] == nil then
			if type(v) == "table" then
				SolaFP_Options.lfgFilters[k] = {}
				for k2, v2 in pairs(v) do SolaFP_Options.lfgFilters[k][k2] = v2 end
			else
				SolaFP_Options.lfgFilters[k] = v
			end
		end
	end
	if type(SolaFP_Options.lfgFilters.soloClasses) == "table" then
		for _, k in ipairs(SolaFP_LFG_CLASS_LIST) do
			if SolaFP_Options.lfgFilters.soloClasses[k] == nil then
				SolaFP_Options.lfgFilters.soloClasses[k] = true
			end
		end
	end
	return SolaFP_Options.lfgFilters
end

function SolaFP_LFG_CountActiveFilters()
	local f = SolaFP_LFG_GetFilters()
	local count = 0
	if f.tankAvailable then count = count + 1 end
	if f.healerAvailable then count = count + 1 end
	if f.damageAvailable then count = count + 1 end
	if f.hasTank then count = count + 1 end
	if f.hasHealer then count = count + 1 end
	if f.excludePartyClasses then count = count + 1 end

	if not (f.soloRoleTank and f.soloRoleHealer and f.soloRoleDamage) then
		count = count + 1
	end

	if (f.soloMinLevel and f.soloMinLevel > 0) or (f.soloMaxLevel and f.soloMaxLevel > 0) then
		count = count + 1
	end

	local unselectedClass = 0
	if f.soloClasses then
		for _, c in ipairs(SolaFP_LFG_CLASS_LIST) do
			if f.soloClasses[c] == false then
				unselectedClass = unselectedClass + 1
			end
		end
	end
	if unselectedClass > 0 then
		count = count + 1
	end

	return count
end

local function SolaFP_LFG_MatchesGroupFilter(resultID, members)
	local f = SolaFP_LFG_GetFilters()
	local anyGroupRule = f.tankAvailable or f.healerAvailable or f.damageAvailable or f.hasTank or f.hasHealer

	if anyGroupRule then
		local counts = api("GetSearchResultMemberCounts", resultID)
		if type(counts) ~= "table" then
			local t, h, d = 0, 0, 0
			for idx = 1, members do
				local mem = api("GetSearchResultPlayerInfo", resultID, idx)
				local r = type(mem) == "table" and safe(mem.assignedRole)
				if r == "TANK" then t = t + 1
				elseif r == "HEALER" then h = h + 1
				elseif r == "DAMAGER" then d = d + 1 end
			end
			counts = { TANK = t, HEALER = h, DAMAGER = d }
		end

		local tCount = tonumber(safe(counts.TANK)) or 0
		local hCount = tonumber(safe(counts.HEALER)) or 0
		local dCount = tonumber(safe(counts.DAMAGER)) or 0

		if f.tankAvailable and tCount >= 1 then return false end
		if f.healerAvailable and hCount >= 1 then return false end
		if f.damageAvailable and dCount >= 3 then return false end
		if f.hasTank and tCount < 1 then return false end
		if f.hasHealer and hCount < 1 then return false end
	end

	if f.excludePartyClasses and f.soloClasses then
		for idx = 1, members do
			local mem = api("GetSearchResultPlayerInfo", resultID, idx)
			local cToken = type(mem) == "table" and safe(mem.classFilename)
			if cToken and f.soloClasses[cToken] == false then
				return false
			end
		end
	end

	return true
end

local function SolaFP_LFG_MatchesSoloFilter(resultID, player, classToken, level)
	local f = SolaFP_LFG_GetFilters()

	-- 1. Role filter
	local rTank = f.soloRoleTank
	local rHeal = f.soloRoleHealer
	local rDam = f.soloRoleDamage
	if not (rTank and rHeal and rDam) and (rTank or rHeal or rDam) then
		local lfgRoles = type(player) == "table" and safe(player.lfgRoles)
		local assigned = type(player) == "table" and safe(player.assignedRole)
		local matched = false
		if type(lfgRoles) == "table" then
			if rTank and safe(lfgRoles.tank) then matched = true end
			if rHeal and safe(lfgRoles.healer) then matched = true end
			if rDam and safe(lfgRoles.dps) then matched = true end
		end
		if not matched and assigned then
			if rTank and assigned == "TANK" then matched = true end
			if rHeal and assigned == "HEALER" then matched = true end
			if rDam and assigned == "DAMAGER" then matched = true end
		end
		if not matched then return false end
	end

	-- 2. Level filter
	local minL = f.soloMinLevel or 0
	local maxL = f.soloMaxLevel or 0
	if (minL > 0 or maxL > 0) and level then
		if minL > 0 and level < minL then return false end
		if maxL > 0 and level > maxL then return false end
	end

	-- 3. Class filter
	if f.soloClasses and classToken then
		if f.soloClasses[classToken] == false then
			return false
		end
	end

	return true
end

function SolaFP_LFG_UpdateFilterButton()
	if not SolaFP_LFG_FilterToggleBtn then return end
	local count = SolaFP_LFG_CountActiveFilters()
	local isOpen = SolaFP_LFG_FilterDrawer and SolaFP_LFG_FilterDrawer:IsShown()
	local arrow = isOpen and "◀" or "▶"

	local fs = SolaFP_LFG_FilterToggleBtn:GetFontString()
	if count > 0 then
		if fs then fs:SetText(string.format(SolaFP_L["Filters(%d) %s"] or "필터(%d) %s", count, arrow)) end
		SolaFP_LFG_FilterToggleBtn:SetBackdropColor(SolaC.gold[1] * 0.35, SolaC.gold[2] * 0.35, SolaC.gold[3] * 0.35, 0.95)
		SolaFP_LFG_FilterToggleBtn:SetBackdropBorderColor(SolaC.gold[1] * 0.85, SolaC.gold[2] * 0.85, SolaC.gold[3] * 0.85, 0.95)
		if fs then fs:SetTextColor(SolaC.goldBeige[1], SolaC.goldBeige[2], SolaC.goldBeige[3]) end
	else
		if fs then fs:SetText(string.format(SolaFP_L["Filters %s"] or "필터 %s", arrow)) end
		if isOpen then
			SolaFP_LFG_FilterToggleBtn:SetBackdropColor(SolaC.teal[1] * 0.28, SolaC.teal[2] * 0.28, SolaC.teal[3] * 0.28, 0.90)
			SolaFP_LFG_FilterToggleBtn:SetBackdropBorderColor(SolaC.teal[1] * 0.70, SolaC.teal[2] * 0.70, SolaC.teal[3] * 0.70, 0.85)
			if fs then fs:SetTextColor(SolaC.teal[1], SolaC.teal[2], SolaC.teal[3]) end
		else
			SolaFP_LFG_FilterToggleBtn:SetBackdropColor(SolaC.bgBtn[1], SolaC.bgBtn[2], SolaC.bgBtn[3], 0.88)
			SolaFP_LFG_FilterToggleBtn:SetBackdropBorderColor(0, 0, 0, 0.65)
			if fs then fs:SetTextColor(SolaC.fgMain[1], SolaC.fgMain[2], SolaC.fgMain[3]) end
		end
	end
end

function SolaFP_LFG_UpdateDrawerVisuals()
	local f = SolaFP_LFG_GetFilters()
	if SolaFP_LFG_DrawerWidgets.tankAvailable then
		SolaFP_LFG_DrawerWidgets.tankAvailable.UpdateVisual(f.tankAvailable)
	end
	if SolaFP_LFG_DrawerWidgets.healerAvailable then
		SolaFP_LFG_DrawerWidgets.healerAvailable.UpdateVisual(f.healerAvailable)
	end
	if SolaFP_LFG_DrawerWidgets.damageAvailable then
		SolaFP_LFG_DrawerWidgets.damageAvailable.UpdateVisual(f.damageAvailable)
	end
	if SolaFP_LFG_DrawerWidgets.hasTank then
		SolaFP_LFG_DrawerWidgets.hasTank.UpdateVisual(f.hasTank)
	end
	if SolaFP_LFG_DrawerWidgets.hasHealer then
		SolaFP_LFG_DrawerWidgets.hasHealer.UpdateVisual(f.hasHealer)
	end
	if SolaFP_LFG_DrawerWidgets.excludePartyClasses then
		SolaFP_LFG_DrawerWidgets.excludePartyClasses.UpdateVisual(f.excludePartyClasses)
	end

	if SolaFP_LFG_DrawerWidgets.soloRoleTank then
		SolaFP_LFG_DrawerWidgets.soloRoleTank.UpdateVisual(f.soloRoleTank)
	end
	if SolaFP_LFG_DrawerWidgets.soloRoleHealer then
		SolaFP_LFG_DrawerWidgets.soloRoleHealer.UpdateVisual(f.soloRoleHealer)
	end
	if SolaFP_LFG_DrawerWidgets.soloRoleDamage then
		SolaFP_LFG_DrawerWidgets.soloRoleDamage.UpdateVisual(f.soloRoleDamage)
	end

	if SolaFP_LFG_DrawerWidgets.minLevelEb then
		local curMin = (f.soloMinLevel and f.soloMinLevel > 0) and tostring(f.soloMinLevel) or ""
		if not SolaFP_LFG_DrawerWidgets.minLevelEb:HasFocus() then
			SolaFP_LFG_DrawerWidgets.minLevelEb:SetText(curMin)
		end
	end
	if SolaFP_LFG_DrawerWidgets.maxLevelEb then
		local curMax = (f.soloMaxLevel and f.soloMaxLevel > 0) and tostring(f.soloMaxLevel) or ""
		if not SolaFP_LFG_DrawerWidgets.maxLevelEb:HasFocus() then
			SolaFP_LFG_DrawerWidgets.maxLevelEb:SetText(curMax)
		end
	end

	if SolaFP_LFG_DrawerWidgets.classChips and f.soloClasses then
		for _, token in ipairs(SolaFP_LFG_CLASS_LIST) do
			local chip = SolaFP_LFG_DrawerWidgets.classChips[token]
			if chip then
				chip.UpdateVisual(f.soloClasses[token] ~= false)
			end
		end
	end

	SolaFP_LFG_UpdateFilterButton()
end

function SolaFP_LFG_ResetAllFilters()
	local f = {}
	for k, v in pairs(SolaFP_LFG_DEFAULT_FILTERS) do
		if type(v) == "table" then
			f[k] = {}
			for k2, v2 in pairs(v) do f[k][k2] = v2 end
		else
			f[k] = v
		end
	end
	if SolaFP_Options then SolaFP_Options.lfgFilters = f end
	SolaFP_LFG_UpdateDrawerVisuals()
	parseSearchResults()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["LFG filters have been reset."] or "기본 파티 탐색기 필터가 초기화되었습니다."))
	end
end

function SolaFP_LFG_SetAllClasses(val)
	local f = SolaFP_LFG_GetFilters()
	if not f.soloClasses then f.soloClasses = {} end
	for _, c in ipairs(SolaFP_LFG_CLASS_LIST) do
		f.soloClasses[c] = val
	end
	SolaFP_LFG_UpdateDrawerVisuals()
	parseSearchResults()
	PlaySound(val and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
end

function SolaFP_LFG_StartMoving()
	local p = SolaFP_LFGPanel
	if SolaFP_Options and SolaFP_Options.lfgOnly then
		if p and not p.isMoving then
			p.isMoving = true
			p:StartMoving()
		end
	elseif SolaFP_ListFrame then
		SolaFP_ListFrame:StartMoving()
	end
end

function SolaFP_LFG_StopMoving()
	local p = SolaFP_LFGPanel
	if SolaFP_Options and SolaFP_Options.lfgOnly then
		if p and p.isMoving then
			p.isMoving = nil
			p:StopMovingOrSizing()
			if SolaFP_Position_Save then
				SolaFP_Position_Save.lfgPoint, _, SolaFP_Position_Save.lfgRelpoint, SolaFP_Position_Save.lfgX, SolaFP_Position_Save.lfgY = p:GetPoint()
			end
		end
	elseif SolaFP_ListFrame then
		SolaFP_ListFrame:StopMovingOrSizing()
		if SolaFP_ListMove then SolaFP_ListMove() end
	end
end

function SolaFP_LFG_AnchorDrawer()
	if not SolaFP_LFG_FilterDrawer or not SolaFP_LFGPanel then return end
	if SolaFP_LFG_FilterDrawer:GetParent() ~= SolaFP_LFGPanel then
		SolaFP_LFG_FilterDrawer:SetParent(SolaFP_LFGPanel)
	end
	SolaFP_LFG_FilterDrawer:ClearAllPoints()
	SolaFP_LFG_FilterDrawer:SetPoint("TOPLEFT", SolaFP_LFGPanel, "TOPRIGHT", 2, 0)
	SolaFP_LFG_FilterDrawer:SetPoint("BOTTOMLEFT", SolaFP_LFGPanel, "BOTTOMRIGHT", 2, 0)
	SolaFP_LFG_FilterDrawer:SetWidth(270)
	local pH = SolaFP_LFGPanel:GetHeight() or 560
	if pH > 0 then
		SolaFP_LFG_FilterDrawer:SetHeight(pH)
	end
	SolaFP_LFG_FilterDrawer:SetScale(1.0)
	local pStrata = SolaFP_LFGPanel:GetFrameStrata() or "HIGH"
	SolaFP_LFG_FilterDrawer:SetFrameStrata(pStrata)
	SolaFP_LFG_FilterDrawer:SetFrameLevel((SolaFP_LFGPanel:GetFrameLevel() or 20) + 15)
	SolaFP_LFG_FilterDrawer:SetClampedToScreen(false)
end

function SolaFP_LFG_CreateFilterDrawer(parentPanel)
	if SolaFP_LFG_FilterDrawer then return SolaFP_LFG_FilterDrawer end
	parentPanel = parentPanel or SolaFP_LFGPanel
	if not parentPanel then return end

	local drawer = CreateFrame("Frame", "SolaFP_LFG_FilterDrawer", parentPanel, "BackdropTemplate")
	if BackdropTemplateMixin and not drawer.SetBackdrop then
		Mixin(drawer, BackdropTemplateMixin)
		drawer:OnBackdropLoaded()
	end
	drawer:SetWidth(270)
	drawer:SetHeight(parentPanel:GetHeight() or 560)
	drawer:ClearAllPoints()
	drawer:SetPoint("TOPLEFT", parentPanel, "TOPRIGHT", 2, 0)
	drawer:SetPoint("BOTTOMLEFT", parentPanel, "BOTTOMRIGHT", 2, 0)
	drawer:SetScale(1.0)
	drawer:SetBackdrop(SolaFP_Backdrop)
	drawer:SetBackdropColor(SolaC.bgSidebar[1], SolaC.bgSidebar[2], SolaC.bgSidebar[3], 0.96)
	drawer:SetBackdropBorderColor(0, 0, 0, 0.75)
	drawer:EnableMouse(true)
	drawer:SetClampedToScreen(false)
	drawer:SetFrameStrata(parentPanel:GetFrameStrata() or "HIGH")
	drawer:SetFrameLevel((parentPanel:GetFrameLevel() or 20) + 15)

	-- Right-click on drawer closes only the drawer (keeps main LFG panel open)
	local function OnDrawerRightClick(_, button)
		if button == "RightButton" then
			drawer:Hide()
			if SolaFP_Options then SolaFP_Options.lfgFilterDrawerOpen = false end
			SolaFP_LFG_UpdateFilterButton()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		end
	end

	local function OnDrawerMouseDown(self, button)
		if DropDownList1 and DropDownList1:IsShown() then
			CloseDropDownMenus()
		end
		if actionMenu and actionMenu:IsShown() then
			actionMenu:Hide()
		end
		if activitiesMenu and activitiesMenu:IsShown() then
			activitiesMenu:Hide()
		end
		if button == "LeftButton" then
			SolaFP_LFG_StartMoving()
		elseif button == "RightButton" then
			OnDrawerRightClick(self, button)
		end
	end

	local function OnDrawerMouseUp(self, button)
		if button == "LeftButton" then
			SolaFP_LFG_StopMoving()
		end
	end

	drawer:SetScript("OnMouseDown", OnDrawerMouseDown)
	drawer:SetScript("OnMouseUp", OnDrawerMouseUp)
	drawer:HookScript("OnHide", function()
		SolaFP_LFG_StopMoving()
	end)

	-- Header
	local header = CreateFrame("Frame", nil, drawer, "BackdropTemplate")
	header:SetHeight(36)
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", 0, 0)
	header:SetBackdrop(SolaFP_Backdrop)
	header:SetBackdropColor(SolaC.bgMain[1], SolaC.bgMain[2], SolaC.bgMain[3], 0.98)
	header:SetBackdropBorderColor(0, 0, 0, 0.70)
	header:EnableMouse(true)
	header:SetScript("OnMouseDown", OnDrawerMouseDown)
	header:SetScript("OnMouseUp", OnDrawerMouseUp)

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", 12, 0)
	title:SetText(SolaFP_L["Detailed Filters"] or "상세 필터")
	title:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])

	local closeBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
	closeBtn:SetSize(22, 22)
	closeBtn:SetPoint("RIGHT", -8, 0)
	SolaFP_StyleCloseButton(closeBtn)
	closeBtn:SetScript("OnClick", function()
		drawer:Hide()
		if SolaFP_Options then SolaFP_Options.lfgFilterDrawerOpen = false end
		SolaFP_LFG_UpdateFilterButton()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
	end)

	local headerLine = drawer:CreateTexture(nil, "OVERLAY")
	headerLine:SetHeight(1)
	headerLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	headerLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
	headerLine:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.08)

	-- Scrollable Content
	local scrollFrame = CreateFrame("ScrollFrame", "SolaFP_LFG_FilterDrawerScrollFrame", drawer)
	scrollFrame:SetPoint("TOPLEFT", 0, -37)
	scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScript("OnMouseDown", OnDrawerMouseDown)
	scrollFrame:SetScript("OnMouseUp", OnDrawerMouseUp)

	local content = CreateFrame("Frame", "SolaFP_LFG_FilterDrawerContent", scrollFrame)
	content:SetSize(270, 520)
	content:EnableMouse(true)
	content:SetScript("OnMouseDown", OnDrawerMouseDown)
	content:SetScript("OnMouseUp", OnDrawerMouseUp)
	scrollFrame:SetScrollChild(content)

	scrollFrame:SetScript("OnMouseWheel", function(self, delta)
		local cur = self:GetVerticalScroll()
		local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
		local newScroll = math.max(0, math.min(maxScroll, cur - (delta * 24)))
		self:SetVerticalScroll(newScroll)
	end)

	-- Chip creation helper
	local function CreateFilterChip(width, height, text, iconMarkup, theme, onClick, tipTitle, tipDesc)
		local btn = CreateFrame("Button", nil, content, "BackdropTemplate")
		if BackdropTemplateMixin and not btn.SetBackdrop then
			Mixin(btn, BackdropTemplateMixin)
			btn:OnBackdropLoaded()
		end
		btn:SetSize(width, height)
		btn:SetBackdrop(SolaFP_Backdrop)
		btn:EnableMouse(true)
		btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

		local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetPoint("CENTER", 0, 0)
		btn.fs = fs
		btn.iconMarkup = iconMarkup or ""
		btn.baseText = text
		btn.theme = theme
		btn.tipTitle = tipTitle
		btn.tipDesc = tipDesc

		local function UpdateVisual(isOn)
			btn.isOn = isOn
			if isOn then
				btn:SetBackdropColor(theme.bg[1], theme.bg[2], theme.bg[3], 0.92)
				btn:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], 0.95)
				fs:SetText(btn.iconMarkup .. (btn.iconMarkup ~= "" and " " or "") .. btn.baseText)
				fs:SetTextColor(theme.text[1], theme.text[2], theme.text[3])
			else
				btn:SetBackdropColor(0.11, 0.10, 0.09, 0.85)
				btn:SetBackdropBorderColor(0.24, 0.22, 0.20, 0.65)
				fs:SetText(btn.iconMarkup .. (btn.iconMarkup ~= "" and " " or "") .. btn.baseText)
				fs:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
			end
		end

		btn:SetScript("OnEnter", function(self)
			if self.isOn then
				self:SetBackdropBorderColor(1, 1, 1, 0.95)
			else
				self:SetBackdropColor(0.16, 0.15, 0.14, 0.90)
				self:SetBackdropBorderColor(SolaC.gold[1] * 0.5, SolaC.gold[2] * 0.5, SolaC.gold[3] * 0.5, 0.70)
			end
			if self.tipTitle then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine(self.tipTitle, SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
				if self.tipDesc then
					GameTooltip:AddLine(self.tipDesc, 0.941, 0.929, 0.910, true)
				end
				GameTooltip:Show()
			end
		end)

		btn:SetScript("OnLeave", function(self)
			UpdateVisual(self.isOn)
			GameTooltip:Hide()
		end)

		btn:SetScript("OnClick", function(self)
			if onClick then onClick(self) end
		end)

		btn.UpdateVisual = UpdateVisual
		return btn
	end

	-- Themes
	local themeTank = {
		bg     = { 0.10, 0.22, 0.35 },
		border = { 0.35, 0.65, 0.95 },
		text   = { 0.70, 0.88, 1.0 },
	}
	local themeHealer = {
		bg     = { 0.10, 0.28, 0.18 },
		border = { 0.35, 0.85, 0.55 },
		text   = { 0.65, 1.0, 0.80 },
	}
	local themeDamage = {
		bg     = { 0.32, 0.14, 0.14 },
		border = { 0.92, 0.40, 0.35 },
		text   = { 1.0, 0.75, 0.70 },
	}
	local themeGold = {
		bg     = { 0.28, 0.22, 0.10 },
		border = { 0.85, 0.68, 0.28 },
		text   = { 1.0, 0.88, 0.60 },
	}
	local themeDanger = {
		bg     = { 0.28, 0.12, 0.12 },
		border = { 0.85, 0.35, 0.35 },
		text   = { 1.0, 0.70, 0.70 },
	}

	local y = -10

	-- Section 1: 파티 구인 조건
	local sec1Title = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sec1Title:SetPoint("TOPLEFT", 12, y)
	sec1Title:SetText("|cffD4A745▶ |r" .. (SolaFP_L["Open Roles"] or "비어있는 역할"))

	y = y - 20
	-- Row 1: Tank / Healer / Damage available (3 chips)
	local chipW3 = 78
	local chipH = 24
	local gapX = 6

	local chipTankAvail = CreateFilterChip(chipW3, chipH, SolaFP_L["Tank"] or "탱커", SolaFP_LFG_GetRoleIconMarkup("TANK"), themeTank, function(self)
		local f = SolaFP_LFG_GetFilters()
		f.tankAvailable = not f.tankAvailable
		self.UpdateVisual(f.tankAvailable)
		SolaFP_LFG_UpdateFilterButton()
		parseSearchResults()
		PlaySound(f.tankAvailable and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
	end, SolaFP_L["Open Tank Slot"] or "탱커 빈자리", SolaFP_L["Show groups with an open tank slot."] or "탱커 자리가 비어있는(1명 미만) 파티만 표시합니다.")
	chipTankAvail:SetPoint("TOPLEFT", 12, y)
	SolaFP_LFG_DrawerWidgets.tankAvailable = chipTankAvail

	local chipHealAvail = CreateFilterChip(chipW3, chipH, SolaFP_L["Healer"] or "힐러", SolaFP_LFG_GetRoleIconMarkup("HEALER"), themeHealer, function(self)
		local f = SolaFP_LFG_GetFilters()
		f.healerAvailable = not f.healerAvailable
		self.UpdateVisual(f.healerAvailable)
		SolaFP_LFG_UpdateFilterButton()
		parseSearchResults()
		PlaySound(f.healerAvailable and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
	end, SolaFP_L["Open Healer Slot"] or "힐러 빈자리", SolaFP_L["Show groups with an open healer slot."] or "힐러 자리가 비어있는(1명 미만) 파티만 표시합니다.")
	chipHealAvail:SetPoint("LEFT", chipTankAvail, "RIGHT", gapX, 0)
	SolaFP_LFG_DrawerWidgets.healerAvailable = chipHealAvail

	local chipDamAvail = CreateFilterChip(chipW3, chipH, SolaFP_L["DPS"] or "딜러", SolaFP_LFG_GetRoleIconMarkup("DAMAGER"), themeDamage, function(self)
		local f = SolaFP_LFG_GetFilters()
		f.damageAvailable = not f.damageAvailable
		self.UpdateVisual(f.damageAvailable)
		SolaFP_LFG_UpdateFilterButton()
		parseSearchResults()
		PlaySound(f.damageAvailable and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
	end, SolaFP_L["Open DPS Slot"] or "딜러 빈자리", SolaFP_L["Show groups with an open DPS slot."] or "딜러 자리가 비어있는(3명 미만) 파티만 표시합니다.")
	chipDamAvail:SetPoint("LEFT", chipHealAvail, "RIGHT", gapX, 0)
	SolaFP_LFG_DrawerWidgets.damageAvailable = chipDamAvail

	y = y - 30
	local sec1SubTitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sec1SubTitle:SetPoint("TOPLEFT", 12, y)
	sec1SubTitle:SetText("|cffD4A745▶ |r" .. (SolaFP_L["Formed Roles"] or "그룹 구성"))

	y = y - 20
	-- Row 2: Has Tank / Has Healer (2 chips)
	local chipW2 = 120
	local chipHasTank = CreateFilterChip(chipW2, chipH, SolaFP_L["Has Tank"] or "탱커 보유", SolaFP_LFG_GetRoleIconMarkup("TANK"), themeGold, function(self)
		local f = SolaFP_LFG_GetFilters()
		f.hasTank = not f.hasTank
		self.UpdateVisual(f.hasTank)
		SolaFP_LFG_UpdateFilterButton()
		parseSearchResults()
		PlaySound(f.hasTank and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
	end, SolaFP_L["Groups with Tank"] or "탱커 보유 파티", SolaFP_L["Show groups that already have 1 or more tanks."] or "탱커가 이미 파티에 1명 이상 있는 파티만 표시합니다.")
	chipHasTank:SetPoint("TOPLEFT", 12, y)
	SolaFP_LFG_DrawerWidgets.hasTank = chipHasTank

	local chipHasHeal = CreateFilterChip(chipW2, chipH, SolaFP_L["Has Healer"] or "힐러 보유", SolaFP_LFG_GetRoleIconMarkup("HEALER"), themeGold, function(self)
		local f = SolaFP_LFG_GetFilters()
		f.hasHealer = not f.hasHealer
		self.UpdateVisual(f.hasHealer)
		SolaFP_LFG_UpdateFilterButton()
		parseSearchResults()
		PlaySound(f.hasHealer and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
	end, SolaFP_L["Groups with Healer"] or "힐러 보유 파티", SolaFP_L["Show groups that already have 1 or more healers."] or "힐러가 이미 파티에 1명 이상 있는 파티만 표시합니다.")
	chipHasHeal:SetPoint("LEFT", chipHasTank, "RIGHT", gapX, 0)
	SolaFP_LFG_DrawerWidgets.hasHealer = chipHasHeal

	y = y - 32
	-- Separator 1
	local sep1 = content:CreateTexture(nil, "ARTWORK")
	sep1:SetHeight(1)
	sep1:SetPoint("TOPLEFT", 12, y)
	sep1:SetPoint("TOPRIGHT", -12, y)
	sep1:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.08)

	y = y - 10
	-- Section 2: 파티를 찾는 플레이어 역할 & 레벨
	local sec2Title = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sec2Title:SetPoint("TOPLEFT", 12, y)
	sec2Title:SetText("|cffD4A745▶ |r" .. (SolaFP_L["Individual Seekers"] or "파티를 찾는 플레이어"))

	y = y - 20
	local chipSoloTank = CreateFilterChip(chipW3, chipH, SolaFP_L["Tank"] or "방어", SolaFP_LFG_GetRoleIconMarkup("TANK"), themeTank, function(self)
		local f = SolaFP_LFG_GetFilters()
		f.soloRoleTank = not f.soloRoleTank
		self.UpdateVisual(f.soloRoleTank)
		SolaFP_LFG_UpdateFilterButton()
		parseSearchResults()
		PlaySound(f.soloRoleTank and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
	end, SolaFP_L["Tank Seekers"] or "탱커 플레이어", SolaFP_L["Show individual players listed as Tank."] or "탱커로 등록한 플레이어를 표시합니다.")
	chipSoloTank:SetPoint("TOPLEFT", 12, y)
	SolaFP_LFG_DrawerWidgets.soloRoleTank = chipSoloTank

	local chipSoloHeal = CreateFilterChip(chipW3, chipH, SolaFP_L["Healer"] or "치유", SolaFP_LFG_GetRoleIconMarkup("HEALER"), themeHealer, function(self)
		local f = SolaFP_LFG_GetFilters()
		f.soloRoleHealer = not f.soloRoleHealer
		self.UpdateVisual(f.soloRoleHealer)
		SolaFP_LFG_UpdateFilterButton()
		parseSearchResults()
		PlaySound(f.soloRoleHealer and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
	end, SolaFP_L["Healer Seekers"] or "힐러 플레이어", SolaFP_L["Show individual players listed as Healer."] or "힐러로 등록한 플레이어를 표시합니다.")
	chipSoloHeal:SetPoint("LEFT", chipSoloTank, "RIGHT", gapX, 0)
	SolaFP_LFG_DrawerWidgets.soloRoleHealer = chipSoloHeal

	local chipSoloDam = CreateFilterChip(chipW3, chipH, SolaFP_L["DPS"] or "공격", SolaFP_LFG_GetRoleIconMarkup("DAMAGER"), themeDamage, function(self)
		local f = SolaFP_LFG_GetFilters()
		f.soloRoleDamage = not f.soloRoleDamage
		self.UpdateVisual(f.soloRoleDamage)
		SolaFP_LFG_UpdateFilterButton()
		parseSearchResults()
		PlaySound(f.soloRoleDamage and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
	end, SolaFP_L["DPS Seekers"] or "딜러 플레이어", SolaFP_L["Show individual players listed as DPS."] or "딜러로 등록한 플레이어를 표시합니다.")
	chipSoloDam:SetPoint("LEFT", chipSoloHeal, "RIGHT", gapX, 0)
	SolaFP_LFG_DrawerWidgets.soloRoleDamage = chipSoloDam

	y = y - 30
	local sec2SubTitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sec2SubTitle:SetPoint("TOPLEFT", 12, y)
	sec2SubTitle:SetText("|cffD4A745▶ |r" .. (SolaFP_L["Seeker Level Filter"] or "레벨 필터"))

	y = y - 22
	-- Level range inputs: [min] ~ [max] [해제]
	local minEb = CreateFrame("EditBox", "SolaFP_LFG_FilterMinLevel", content, "BackdropTemplate")
	minEb:SetSize(62, 22)
	minEb:SetPoint("TOPLEFT", 12, y)
	minEb:SetNumeric(true)
	minEb:SetMaxLetters(2)
	minEb:SetAutoFocus(false)
	minEb:SetJustifyH("CENTER")
	SolaFP_StyleModernEditBox(minEb, "teal")
	SolaFP_LFG_DrawerWidgets.minLevelEb = minEb

	local tilde = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	tilde:SetPoint("LEFT", minEb, "RIGHT", 5, 0)
	tilde:SetText("~")
	tilde:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])

	local maxEb = CreateFrame("EditBox", "SolaFP_LFG_FilterMaxLevel", content, "BackdropTemplate")
	maxEb:SetSize(62, 22)
	maxEb:SetPoint("LEFT", tilde, "RIGHT", 5, 0)
	maxEb:SetNumeric(true)
	maxEb:SetMaxLetters(2)
	maxEb:SetAutoFocus(false)
	maxEb:SetJustifyH("CENTER")
	SolaFP_StyleModernEditBox(maxEb, "teal")
	SolaFP_LFG_DrawerWidgets.maxLevelEb = maxEb

	local function OnLevelChanged()
		local f = SolaFP_LFG_GetFilters()
		local minV = tonumber(minEb:GetText()) or 0
		local maxV = tonumber(maxEb:GetText()) or 0
		f.soloMinLevel = minV
		f.soloMaxLevel = maxV
		SolaFP_LFG_UpdateFilterButton()
		parseSearchResults()
	end
	minEb:HookScript("OnEnterPressed", function(self) self:ClearFocus(); OnLevelChanged() end)
	minEb:HookScript("OnEditFocusLost", function() OnLevelChanged() end)
	maxEb:HookScript("OnEnterPressed", function(self) self:ClearFocus(); OnLevelChanged() end)
	maxEb:HookScript("OnEditFocusLost", function() OnLevelChanged() end)

	local clearLvlBtn = CreateFrame("Button", nil, content, "BackdropTemplate")
	clearLvlBtn:SetSize(52, 22)
	clearLvlBtn:SetPoint("LEFT", maxEb, "RIGHT", 8, 0)
	SolaFP_StyleModernButton(clearLvlBtn, "dark", SolaFP_L["Clear"] or "해제")
	clearLvlBtn:SetScript("OnClick", function()
		minEb:SetText("")
		maxEb:SetText("")
		OnLevelChanged()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
	end)

	y = y - 32
	-- Separator 2
	local sep2 = content:CreateTexture(nil, "ARTWORK")
	sep2:SetHeight(1)
	sep2:SetPoint("TOPLEFT", 12, y)
	sep2:SetPoint("TOPRIGHT", -12, y)
	sep2:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.08)

	y = y - 10
	-- Section 3: 구직자 직업 필터
	local sec3Title = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sec3Title:SetPoint("TOPLEFT", 12, y)
	sec3Title:SetText("|cffD4A745▶ |r" .. (SolaFP_L["Seeker Class Filter"] or "플레이어 직업 필터"))

	local isEnLocale = ((SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) ~= "koKR")
	local deselectAllBtn = CreateFrame("Button", nil, content, "BackdropTemplate")
	deselectAllBtn:SetSize(isEnLocale and 48 or 42, 18)
	deselectAllBtn:SetPoint("TOPRIGHT", -12, y + 2)
	SolaFP_StyleModernButton(deselectAllBtn, "dark", SolaFP_L["Clear"] or "해제")
	local deselectFs = deselectAllBtn:GetFontString()
	if deselectFs then
		deselectFs:SetFontObject("GameFontHighlightSmall")
	end
	deselectAllBtn:SetScript("OnClick", function()
		SolaFP_LFG_SetAllClasses(false)
	end)

	local selectAllBtn = CreateFrame("Button", nil, content, "BackdropTemplate")
	selectAllBtn:SetSize(isEnLocale and 68 or 52, 18)
	selectAllBtn:SetPoint("RIGHT", deselectAllBtn, "LEFT", -6, 0)
	SolaFP_StyleModernButton(selectAllBtn, "dark", SolaFP_L["Select All"] or "전체선택")
	local selectFs = selectAllBtn:GetFontString()
	if selectFs then
		selectFs:SetFontObject("GameFontHighlightSmall")
	end
	selectAllBtn:SetScript("OnClick", function()
		SolaFP_LFG_SetAllClasses(true)
	end)

	y = y - 22
	-- Class chips: 3 rows x 3 columns
	SolaFP_LFG_DrawerWidgets.classChips = {}
	for idx, token in ipairs(SolaFP_LFG_CLASS_LIST) do
		local row = math.floor((idx - 1) / 3)
		local col = (idx - 1) % 3
		local cX = 12 + (col * (chipW3 + gapX))
		local cY = y - (row * (chipH + 4))

		local color = SolaFP_LFG_GetClassColor(token)
		local themeClass = {
			bg     = { color.r * 0.28, color.g * 0.28, color.b * 0.28 },
			border = { color.r * 0.88, color.g * 0.88, color.b * 0.88 },
			text   = { color.r, color.g, color.b },
		}
		local nameKo = SolaFP_LFG_CLASS_NAMES[token] or token
		local iconMarkup = SolaFP_LFG_GetClassIconMarkup(token)

		local chip = CreateFilterChip(chipW3, chipH, nameKo, iconMarkup, themeClass, function(self)
			local f = SolaFP_LFG_GetFilters()
			local cur = f.soloClasses and (f.soloClasses[token] ~= false)
			f.soloClasses[token] = not cur
			self.UpdateVisual(f.soloClasses[token])
			SolaFP_LFG_UpdateFilterButton()
			parseSearchResults()
			PlaySound(f.soloClasses[token] and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
		end, string.format(SolaFP_L["%s Class Filter"] or "%s 직업 필터", nameKo), string.format(SolaFP_L["Toggle listings for %s individual seekers."] or "%s 플레이어의 목록 표시 여부를 설정합니다.", nameKo))
		chip:SetPoint("TOPLEFT", cX, cY)
		SolaFP_LFG_DrawerWidgets.classChips[token] = chip
	end

	y = y - (3 * (chipH + 4)) - 6

	-- Separator 3
	local sep3 = content:CreateTexture(nil, "ARTWORK")
	sep3:SetHeight(1)
	sep3:SetPoint("TOPLEFT", 12, y)
	sep3:SetPoint("TOPRIGHT", -12, y)
	sep3:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.08)

	y = y - 10
	-- Section 4: Advanced option (exclude party with unselected classes)
	local chipExcludeParty = CreateFilterChip(246, 24, "|cffEF5350" .. (SolaFP_L["[Exclude]"] or "[제외]") .. "|r", "", themeDanger, function(self)
		local f = SolaFP_LFG_GetFilters()
		f.excludePartyClasses = not f.excludePartyClasses
		self.UpdateVisual(f.excludePartyClasses)
		SolaFP_LFG_UpdateFilterButton()
		parseSearchResults()
		PlaySound(f.excludePartyClasses and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
	end, SolaFP_L["Hide Groups with Excluded Classes"] or "파티 내 제외 직업 숨김", SolaFP_L["Hide formed groups that contain unselected classes."] or "구성된 파티에 제외된 직업이 포함되어 있으면 목록에서 숨깁니다.")
	chipExcludeParty:SetPoint("TOPLEFT", 12, y)
	SolaFP_LFG_DrawerWidgets.excludePartyClasses = chipExcludeParty

	y = y - 32
	-- Full Reset Button
	local fullResetBtn = CreateFrame("Button", nil, content, "BackdropTemplate")
	fullResetBtn:SetSize(246, 26)
	fullResetBtn:SetPoint("TOPLEFT", 12, y)
	SolaFP_StyleModernButton(fullResetBtn, "dark", SolaFP_L["Reset All Filters"] or "모든 필터 초기화")
	fullResetBtn:SetScript("OnClick", function()
		SolaFP_LFG_ResetAllFilters()
	end)

	y = y - 38
	content:SetHeight(math.abs(y) + 10)

	SolaFP_LFG_FilterDrawer = drawer
	SolaFP_LFG_UpdateDrawerVisuals()

	-- Restore open state only if parent panel is currently visible
	if SolaFP_Options and SolaFP_Options.lfgFilterDrawerOpen and parentPanel and parentPanel:IsVisible() then
		SolaFP_LFG_AnchorDrawer()
		drawer:Show()
	else
		drawer:Hide()
	end

	return drawer
end

local function doWhisperSelected()
	local targetLeader = nil
	if selectedID then
		for _, it in ipairs(items) do
			if it.id == selectedID then
				targetLeader = it.author or it.leader
				break
			end
		end
	end
	if targetLeader and targetLeader ~= "" and targetLeader ~= "이름 미표시" and targetLeader ~= "Anonymous" and targetLeader ~= (SolaFP_L["Anonymous"] or "이름 미표시") then
		if targetLeader == UnitName("player") then
			if SolaFP_Print then
				SolaFP_Print(SolaFP_L["Cannot send a whisper to yourself."] or "자신에게는 귓속말을 보낼 수 없습니다.")
			end
			return
		end
		doWhisper(targetLeader)
		PlaySound(SOUNDKIT.IG_CHAT_EMOTE_BUTTON or 856)
	else
		if SolaFP_Print then
			SolaFP_Print(SolaFP_L["Please select a listing first."] or SolaFP_MESSAGE_NOTARGET or "대상을 먼저 선택하세요.")
		elseif DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[SolaLFG]|r " .. (SolaFP_L["Please select a listing first."] or "대상을 먼저 선택하세요."))
		end
	end
end

-- The query narrows the already loaded list and does not call Blizzard's search API.
local searchText = ""
local listingView = "all"
-- Keep the tab strip and the scroll budget on the same layout measurements.
local resultsTop = 157
local function resultsHeight(height, standalone)
	return math.max(40, height - resultsTop - (standalone and 42 or 8))
end
local statusText = nil
local scrollBarSlider = nil
local levelSortBtn = nil
local dungeonLevelSortAsc = false

local refreshTickerHandle = nil
local MIN_REFRESH_THROTTLE = 5

function SolaFP_LFG_UpdateRefreshTimer()
	local btn = SolaFP_LFG_RefreshBtn
	if not btn or not isPanelVisible() then return end
	local now = GetTime and GetTime() or 0
	local elapsed = now - (lastSearchTime or 0)
	local stale = not pending and (lastSearchTime == 0 or elapsed >= 60)
	btn:SetBackdropBorderColor(0.57, 0.46, 0.30, stale and 0.85 or 0.45)
	if pending or (lastSearchTime and lastSearchTime > 0 and elapsed < MIN_REFRESH_THROTTLE) then
		btn:SetAlpha(0.65)
	else
		btn:SetAlpha(1.0)
	end
end

local function startRefreshTicker()
	if refreshTickerHandle then
		refreshTickerHandle:Cancel()
		refreshTickerHandle = nil
	end
	SolaFP_LFG_UpdateRefreshTimer()
	if C_Timer and C_Timer.NewTicker then
		refreshTickerHandle = C_Timer.NewTicker(1, SolaFP_LFG_UpdateRefreshTimer)
	end
end

local function stopRefreshTicker()
	if refreshTickerHandle then
		refreshTickerHandle:Cancel()
		refreshTickerHandle = nil
	end
end

function SolaFP_LFG_HasResults()
	return (items and #items > 0)
end

function SolaFP_LFG_OnUserOpen()
	if not SolaFP_LFGPanel or not SolaFP_LFGPanel:IsShown() then return end
	local now = GetTime and GetTime() or 0
	if not items or #items == 0 or (now - (lastSearchTime or 0) >= 30) then
		SolaFP_LFG_Search(true)
	else
		parseSearchResults()
	end
end

function SolaFP_LFG_UpdateStatusText(msg, showSort)
	if not statusText then return end
	statusText:SetText(msg)
	-- Fixed anchors keep long status messages from moving the sort button.
	if levelSortBtn then levelSortBtn:SetShown(showSort == true) end
	local panel = SolaFP_LFGPanel
	if panel and panel.emptyText and panel.emptyText:IsShown() and panel.RefreshListingView then
		panel.RefreshListingView()
	end
end

-------------------------------------------------
-- Note formatting helper
-------------------------------------------------
local function formatNote(n)
	if not n or n == "" then return "" end
	n = n:gsub("||([Kk])", "|%1")
	if n:find('^["“]') and n:find('["”]$') then
		return n
	end
	return "“" .. n .. "”"
end

-------------------------------------------------
-- List rendering
-------------------------------------------------
local function renderList()
	if not SolaFP_LFGPanel or not SolaFP_LFGPanel:IsShown() then return end

	-- Calculate list height dynamically
	local curH = SolaFP_LFGPanel:GetHeight() or 0
	if curH > 0 then
		local isStandalone = (SolaFP_Options and SolaFP_Options.lfgOnly)
		availableHeight = resultsHeight(curH, isStandalone)
	end

	local shown, matching, sections, groups = {}, {}, {}, {}
	local counts = { all = 0, party = 0, solo = 0 }
	local isSearching = searchText ~= ""
	local function matches(value)
		value = safe(value)
		return type(value) == "string" and value:lower():find(searchText, 1, true) ~= nil
	end
	-- Count both views before applying the tab. Counts describe the current
	-- search and filters, even while the other view is selected.
	for _, item in ipairs(items) do
		if not item.dungeon and not item.section and item.group and (not isSearching
			or matches(item.group) or matches(item.leader) or matches(item.area)
			or matches(item.className) or matches(item.comment)) then
			local mode = item.solo and "solo" or "party"
			counts[mode] = counts[mode] + 1
			counts.all = counts.all + 1
			if listingView == "all" or listingView == mode then
				matching[item] = true
				groups[item.group] = true
				local key = item.group .. ":" .. mode
				sections[key] = (sections[key] or 0) + 1
			end
		end
	end
	for _, item in ipairs(items) do
		local visible
		if item.dungeon then
			visible = (not isSearching and listingView == "all") or groups[item.group]
		elseif isSearching or isGroupExpanded(item.group) then
			if item.section then
				-- A scoped tab already identifies the listing kind.
				visible = listingView == "all" and sections[item.group .. ":" .. item.section]
			else
				visible = matching[item]
			end
		end
		if visible then shown[#shown + 1] = item end
	end
	local panel = SolaFP_LFGPanel
	if panel.UpdateListingTabs then panel:UpdateListingTabs(counts) end
	if panel.emptyText then
		local korean = SolaFP_GetLocale() == "koKR"
		local message = statusText and statusText:GetText() or ""
		-- A zero-row server response or failed request already has a status.
		-- Only show a tab/search empty message when narrowing existing rows.
		if not pending and #items > 0 then
			if isSearching then
				message = korean and "검색어와 일치하는 결과가 없습니다." or "No listings match your search."
			elseif listingView == "party" then
				message = korean and "현재 조건에 맞는 파티 모집글이 없습니다." or "No groups match your filters."
			elseif listingView == "solo" then
				message = korean and "현재 조건에 맞는 플레이어가 없습니다." or "No players match your filters."
			end
		end
		panel.emptyText:SetText(message)
		panel.emptyText:SetShown(#shown == 0)
		if panel.resetView then
			panel.resetView:SetShown(#shown == 0 and not pending and (isSearching or listingView ~= "all"))
		end
	end

	local function getItemHeight(item)
		if item.section then return 20 end
		if item.dungeon then return 26 end
		if item.noteChecked == nil then
			item.noteChecked = true
			if not item.comment or item.comment == "" then
				local n = SolaFP_LFG_GetItemNote(item)
				if n and n ~= "" then
					item.comment = n
				end
			end
		end
		if item.comment and item.comment ~= "" then
			return 52
		end
		return 36
	end

	local tail, used = #shown, 0
	while tail > 0 and used + getItemHeight(shown[tail]) + 2 <= availableHeight do
		used = used + getItemHeight(shown[tail]) + 2
		tail = tail - 1
	end
	offset = math.max(0, math.min(offset, tail))

	if scrollBarSlider and scrollBarSlider.Sync then
		scrollBarSlider:Sync(offset, tail)
	end

	local y = 0
	for i, row in ipairs(rows) do
		local item = shown[offset + i]
		if item and y + getItemHeight(item) > availableHeight then
			item = nil
		end
		if item and item.noteChecked == nil and not item.dungeon and not item.section then
			item.noteChecked = true
			if (not item.comment or item.comment == "") then
				local n = SolaFP_LFG_GetItemNote(item)
				if n and n ~= "" then
					item.comment = n
				end
			end
		end
		row.item = item
		-- Recycled rows hide the action on headers and on anonymized listings.
		local contact = item and (safe(item.author) or safe(item.leader))
		local canWhisper = item and not item.dungeon and not item.section
			and type(contact) == "string" and contact ~= "" and contact ~= "Anonymous"
			and contact ~= "이름 미표시" and contact ~= SolaFP_L["Anonymous"]
			and contact ~= UnitName("player")
		row.whisperTarget = canWhisper and contact or nil
		row.whisper:SetShown(row.whisperTarget ~= nil)

		if item then
			local h = getItemHeight(item)
			local indent = item.dungeon and 0 or (item.section and 6 or 12)
			local curPanelW = SolaFP_LFGPanel:GetWidth() or 390
			local rowW = math.max(350, curPanelW - 24)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 12 + indent, -resultsTop - y)
			row:SetSize(rowW - indent, h)
			y = y + h + 2

			-- Reset view elements
			row.dungeonIcon:Hide()
			row.expandIcon:Hide()
			row.dungeonCounts:SetShown(item.dungeon == true)
			row.classIcon:SetShown(item.solo == true and item.classToken ~= nil)

			if item.dungeon then
				-- Dungeon group header
				local isExpanded = searchText ~= "" or isGroupExpanded(item.group)
				local bullet = isExpanded and "|cffC9A568▼|r  " or "|cffC9A568▶|r  "
				local lvlStr = item.level and (" |cffB9A584Lv. " .. item.level .. "|r") or ""
				row.title:SetText(bullet .. item.heading .. lvlStr)
				row.title:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
				row.title:ClearAllPoints()
				row.title:SetPoint("LEFT", row, "LEFT", 10, 0)
				row.title:SetPoint("RIGHT", row.dungeonCounts, "LEFT", -4, 0)
				row.title:Show()

				local countFmt = SolaFP_L["ROW_COUNT_FORMAT"] or "(%d팀) (%d명)"
				local partyCount, soloCount = item.partyCount or 0, item.soloCount or 0
				if searchText ~= "" or listingView ~= "all" then
					partyCount = sections[item.group .. ":party"] or 0
					soloCount = sections[item.group .. ":solo"] or 0
				end
				local countStr = string.format(countFmt, partyCount, soloCount)
				row.dungeonCounts:SetText(countStr)
				row.dungeonCounts:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])

				row.soloName:Hide()
				row.info:Hide()
				if row.soloLevel then row.soloLevel:Hide() end
				if row.soloComment then row.soloComment:Hide() end
				row.roles:Hide()

				row:SetBackdropColor(0.198, 0.154, 0.101, 1)
				row:SetBackdropBorderColor(SolaC.gold[1] * 0.5, SolaC.gold[2] * 0.5, SolaC.gold[3] * 0.5, 0.4)

			elseif item.section then
				-- Party or solo subheader
				local heading = item.heading
				if searchText ~= "" then
					local fmt = item.section == "party"
						and (SolaFP_L["Formed Groups  ·  %d"] or "구성된 파티  ·  %d팀")
						or (SolaFP_L["Individual Seekers  ·  %d"] or "파티를 찾는 중  ·  %d명")
					heading = string.format(fmt, sections[item.group .. ":" .. item.section] or 0)
				end
				row.title:SetText(heading)
				row.title:ClearAllPoints()
				row.title:SetPoint("LEFT", 6, 0)
				row.title:SetPoint("RIGHT", -6, 0)
				row.title:Show()

				row.title:SetTextColor(0.84, 0.77, 0.63)
				row:SetBackdropColor(0.133, 0.109, 0.081, 1)
				row:SetBackdropBorderColor(0, 0, 0, 0.5)

				row.soloName:Hide()
				row.info:Hide()
				if row.soloLevel then row.soloLevel:Hide() end
				if row.soloComment then row.soloComment:Hide() end
				row.roles:Hide()

			else
				-- Party or solo result row
				row.title:Hide()

				local hasComment = (item.comment and item.comment ~= "")
				local commentText = hasComment and formatNote(item.comment) or ""

				if item.solo then
					-- Solo applicant row
					local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[item.classToken]
					if coords then
						row.classIcon:SetTexCoord(unpack(coords))
						row.classIcon:ClearAllPoints()
						row.classIcon:SetPoint("TOPLEFT", 4, -4)
						row.classIcon:Show()
					else
						row.classIcon:Hide()
					end

					-- Line 1 (TOP): 닉네임 + 현재 위치
					local nameOffset = row.classIcon:IsShown() and 24 or 6
					row.soloName:ClearAllPoints()
					row.soloName:SetPoint("TOPLEFT", nameOffset, -3)
					row.soloName:SetPoint("RIGHT", row.roles, "LEFT", -4, 0)

					local locStr = (item.area and item.area ~= "") and ("  |cffB5A78D· " .. item.area .. "|r") or ""
					local cCol = RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.classToken]
					if cCol then
						row.soloName:SetText(string.format("|cff%02x%02x%02x%s|r%s", cCol.r * 255, cCol.g * 255, cCol.b * 255, item.leader, locStr))
					else
						row.soloName:SetText(item.leader .. locStr)
					end
					row.soloName:Show()

					-- Line 2: 직업 + 레벨
					local lvl = item.level and (" · Lv." .. item.level) or ""
					row.info:ClearAllPoints()
					row.info:SetWidth(0)
					if hasComment then
						row.info:SetPoint("TOPLEFT", nameOffset, -18)
					else
						row.info:SetPoint("BOTTOMLEFT", nameOffset, 3)
					end
					row.info:SetPoint("RIGHT", row.roles, "LEFT", -4, 0)
					row.info:SetText((item.className or "") .. lvl)
					row.info:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
					row.info:Show()

					-- Line 3: 메모 (한 칸 내려서 마우스오버와 동일한 색상으로 출력)
					if hasComment and row.soloComment then
						row.soloComment:ClearAllPoints()
						row.soloComment:SetPoint("TOPLEFT", nameOffset, -34)
						row.soloComment:SetPoint("RIGHT", row, "RIGHT", row.whisperTarget and -66 or -8, 0)
						row.soloComment:SetJustifyH("LEFT")
						row.soloComment:SetWordWrap(false)
						row.soloComment:SetText(commentText)
						row.soloComment:SetTextColor(0.84, 0.79, 0.68)
						row.soloComment:Show()
					elseif row.soloComment then
						row.soloComment:Hide()
					end
					if row.soloLevel then row.soloLevel:Hide() end

				else
					-- Party listing row
					local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[item.classToken]
					if coords then
						row.classIcon:SetTexCoord(unpack(coords))
						row.classIcon:ClearAllPoints()
						row.classIcon:SetPoint("TOPLEFT", 4, -4)
						row.classIcon:Show()
					else
						row.classIcon:Hide()
					end

					-- Line 1 (TOP): 파티장 닉네임 + 현재 위치
					local nameOffset = row.classIcon:IsShown() and 24 or 6
					row.soloName:ClearAllPoints()
					row.soloName:SetPoint("TOPLEFT", nameOffset, -3)
					row.soloName:SetPoint("RIGHT", row.roles, "LEFT", -4, 0)

					local locStr = (item.area and item.area ~= "") and ("  |cffB5A78D· " .. item.area .. "|r") or ""
					local cCol = RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.classToken]
					if cCol then
						row.soloName:SetText(string.format("|cff%02x%02x%02x%s|r%s", cCol.r * 255, cCol.g * 255, cCol.b * 255, item.leader, locStr))
					else
						row.soloName:SetText(item.leader .. locStr)
					end
					row.soloName:Show()

					-- Line 2: 직업 + 레벨
					local lvl = item.level and (" · Lv." .. item.level) or ""
					row.info:ClearAllPoints()
					row.info:SetWidth(0)
					if hasComment then
						row.info:SetPoint("TOPLEFT", nameOffset, -18)
					else
						row.info:SetPoint("BOTTOMLEFT", nameOffset, 3)
					end
					row.info:SetPoint("RIGHT", row.roles, "LEFT", -4, 0)

					local classStr = (item.className and item.className ~= "" and item.className ~= "직업 미표시" and item.className ~= "Unknown Class" and item.className ~= (SolaFP_L["Unknown Class"] or "직업 미표시")) and item.className or ""
					if classStr ~= "" then
						row.info:SetText(classStr .. lvl)
					else
						row.info:SetText(lvl:gsub("^ · ", ""))
					end
					row.info:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
					row.info:Show()

					-- Line 3: 메모 (제일 아래쪽에 마우스오버와 동일한 색상으로 출력)
					if hasComment and row.soloComment then
						row.soloComment:ClearAllPoints()
						row.soloComment:SetPoint("TOPLEFT", nameOffset, -34)
						row.soloComment:SetPoint("RIGHT", row, "RIGHT", row.whisperTarget and -66 or -8, 0)
						row.soloComment:SetJustifyH("LEFT")
						row.soloComment:SetWordWrap(false)
						row.soloComment:SetText(commentText)
						row.soloComment:SetTextColor(0.84, 0.79, 0.68)
						row.soloComment:Show()
					elseif row.soloComment then
						row.soloComment:Hide()
					end
					if row.soloLevel then row.soloLevel:Hide() end
				end

				row.roles:ClearAllPoints()
				local roleInset = row.whisperTarget and -65 or -6
				if hasComment then
					row.roles:SetPoint("TOPRIGHT", roleInset, -4)
				else
					row.roles:SetPoint("RIGHT", roleInset, 0)
				end
				row.roles:SetText(item.icons or "")
				row.roles:Show()

				-- Background color
				if selectedID == item.id then
					row:SetBackdropColor(SolaC.bgSelected[1], SolaC.bgSelected[2], SolaC.bgSelected[3], 0.95)
					row:SetBackdropBorderColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.8)
				elseif i % 2 == 0 then
					row:SetBackdropColor(0.122, 0.101, 0.078, 1)
					row:SetBackdropBorderColor(0, 0, 0, 0.5)
				else
					row:SetBackdropColor(0.098, 0.081, 0.062, 1)
					row:SetBackdropBorderColor(0, 0, 0, 0.5)
				end
			end

			row:Show()
		else
			row:Hide()
		end
	end
end

-------------------------------------------------
-- Parse search results
-------------------------------------------------
parseSearchResults = function()
	local _, ids = api("GetSearchResults")
	items = {}
	local groups, order, totalCount = {}, {}, 0
	activities, activityLevels = {}, {}
	if updateAvailableActivities then
		updateAvailableActivities()
	end

	local active = api("GetActiveEntryInfo")
	local own = {}
	local ownIDs = (type(active) == "table") and safe(active.activityIDs)
	if type(ownIDs) == "table" then
		for _, oId in ipairs(ownIDs) do
			oId = safe(oId)
			if oId then own[oId] = true end
		end
	end

	local level = UnitLevel and safe(UnitLevel("player"))
	local allLevels = (SolaFP_Options == nil) or (SolaFP_Options.lfgAllLevels ~= false)
	local hasInterestFilter = isActivityFiltering and (getSelectedActivitiesCount() > 0)

	if type(ids) == "table" then
		for _, id in ipairs(ids) do
			local info = api("GetSearchResultInfo", id)
			if type(info) == "table" and not safe(info.isDelisted) then
				local player = api("GetSearchResultLeaderInfo", id)
				local leader = plain(info.leaderName)
				if type(player) ~= "table" then
					local first = api("GetSearchResultPlayerInfo", id, 1)
					if type(first) == "table" and (safe(first.isLeader) or (leader ~= "" and plain(first.name) == leader) or safe(info.numMembers) == 1) then
						player = first
					end
				end
				if leader == "" and type(player) == "table" then
					leader = plain(player.name)
				end
				local classToken = (type(player) == "table") and safe(player.classFilename) or nil
				local title = plain(info.name)
				local activityIDs = safe(info.activityIDs)
				local groupName = nil
				local hasActivity = false
				local matchedActivities = {}

				if type(activityIDs) == "table" then
					for _, actID in ipairs(activityIDs) do
						local act = api("GetActivityInfoTable", safe(actID))
						local cat = (type(act) == "table") and safe(act.categoryID)
						local dName, dRange
						if type(act) == "table" then
							dName, dRange = SolaFP_LFG_GetDungeonDisplay(safe(act.fullName), safe(act.shortName))
							if not dName or dName == "" then
								dName = safe(act.fullName)
								if not dName or dName == "" then dName = safe(act.shortName) end
							end
							if not dRange and act.minLevel and act.maxLevel then
								if act.minLevel == act.maxLevel then
									dRange = tostring(act.minLevel)
								else
									dRange = string.format("%d-%d", act.minLevel, act.maxLevel)
								end
							end
						end
						dName = dName or string.format(SolaFP_L["Other Dungeon #%s"] or "기타 던전 #%s", tostring(safe(actID) or "?"))
						if cat and not isDungeonOrRaidCategory(cat) then
							hasActivity = true
							dName = ""
						end
						if dName ~= "" then
							activities[dName] = true
							hasActivity = true
							activityLevels[dName] = dRange
							local isMatch = true
							if excludedActivities and excludedActivities[dName] then
								isMatch = false
							elseif hasInterestFilter then
								isMatch = (selectedActivities[dName] == true)
							elseif (not allLevels) and level and not own[actID] and dRange then
								local low, high = dRange:match("^(%d+)%D+(%d+)$")
								low = tonumber(low) or tonumber(dRange)
								high = tonumber(high) or low
								if low and (level < low or level > high) then
									isMatch = false
								end
							end
							if isMatch and not matchedActivities[dName] then
								groupName = groupName or dName
								matchedActivities[dName] = true
							end
						end
					end
				end

				if not hasActivity then
					local unspec = SolaFP_L["Unspecified Activity"] or "활동 미지정"
					activities[unspec] = true
					local isMatch = true
					if excludedActivities and (excludedActivities[unspec] or excludedActivities["활동 미지정"]) then
						isMatch = false
					elseif hasInterestFilter then
						isMatch = (selectedActivities[unspec] == true or selectedActivities["활동 미지정"] == true)
					end
					if isMatch and not matchedActivities[unspec] then
						groupName = unspec
						matchedActivities[groupName] = true
					end
				end

				if groupName then
					local members = tonumber(safe(info.numMembers)) or 0
					local leaderName = plain(leader)
					if leaderName == "" then leaderName = SolaFP_L["Anonymous"] or "이름 미표시" end
					local comment = plain(info.comment)
					if (not comment or comment == "") and title ~= "" and title ~= groupName and title ~= leaderName and title ~= (SolaFP_L["Unspecified Activity"] or "활동 미지정") and title ~= "활동 미지정" then
						comment = title
					end

					-- Extract location (zone/area) for solo player or party leader
					local areaName = nil
					if type(player) == "table" then
						local pArea = plain(player.areaName)
						if pArea ~= "" then
							areaName = pArea
						end
					end
					if not areaName or areaName == "" then
						if members <= 1 then
							local p1 = api("GetSearchResultPlayerInfo", id, 1)
							if type(p1) == "table" then
								local p1Area = plain(p1.areaName)
								if p1Area ~= "" then
									areaName = p1Area
								end
							end
						else
							local fallbackArea = nil
							local count = math.min(members, 5)
							for idx = 1, count do
								local mem = api("GetSearchResultPlayerInfo", id, idx)
								if type(mem) == "table" then
									local isLead = safe(mem.isLeader) or (leader ~= "" and plain(mem.name) == leader)
									if isLead then
										if type(player) ~= "table" then player = mem end
										if not classToken and safe(mem.classFilename) then
											classToken = safe(mem.classFilename)
										end
									end
									local mArea = plain(mem.areaName)
									if mArea ~= "" then
										if isLead then
											areaName = mArea
											break
										end
										if not fallbackArea then
											fallbackArea = mArea
										end
									end
								end
							end
							if not areaName or areaName == "" then
								areaName = fallbackArea
							end
						end
					end
					if areaName then
						areaName = strtrim(areaName)
						if areaName == "" then areaName = nil end
					end

					local cName = (type(player) == "table") and plain(player.className) or ""
					if (not cName or cName == "") and classToken then
						if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken] then
							cName = LOCALIZED_CLASS_NAMES_MALE[classToken]
						end
					end

					local item = {
						id = id,
						title = (title ~= "" and title) or groupName,
						author = leader,
						leader = leaderName,
						count = members,
						activity = groupName,
						comment = comment,
						area = areaName,
						voiceChat = plain(info.voiceChat),
						classToken = classToken,
						className = cName,
						group = groupName,
						level = (type(player) == "table") and tonumber(safe(player.level)) or nil,
						icons = getRoleIcons(id, members, player)
					}

					local function addGroupEntry(targetGroup, entry, sec)
						local g = groups[targetGroup]
						if not g then
							g = { party = {}, solo = {} }
							groups[targetGroup] = g
							order[#order + 1] = targetGroup
						end
						g[sec][#g[sec] + 1] = entry
					end

					if members == 1 then
						if SolaFP_LFG_MatchesSoloFilter(id, player, classToken, item.level) then
							item.solo = true
							item.className = (type(player) == "table") and plain(player.className) or ""
							if item.className == "" then item.className = SolaFP_L["Unknown Class"] or "직업 미표시" end
							for name in pairs(matchedActivities) do
								local soloEntry = {}
								for k, v in pairs(item) do soloEntry[k] = v end
								soloEntry.group = name
								addGroupEntry(name, soloEntry, "solo")
							end
							totalCount = totalCount + 1
						end
					else
						if SolaFP_LFG_MatchesGroupFilter(id, members) then
							addGroupEntry(groupName, item, "party")
							totalCount = totalCount + 1
						end
					end
				end
			end
		end
	end

	-- Sort dungeons by level requirement
	local function avgLvl(name)
		local range = activityLevels[name] or ""
		local low, high = range:match("^(%d+)%D+(%d+)$")
		if low and high then return (tonumber(low) + tonumber(high)) / 2 end
		return tonumber(range) or 0
	end
	table.sort(order, function(a, b)
		local l1, l2 = avgLvl(a), avgLvl(b)
		if l1 ~= l2 then
			if dungeonLevelSortAsc then
				return l1 < l2
			else
				return l1 > l2
			end
		end
		return a < b
	end)

	for _, name in ipairs(order) do
		local g = groups[name]
		items[#items + 1] = {
			heading = name,
			dungeon = true,
			group = name,
			level = activityLevels[name],
			partyCount = #g.party,
			soloCount = #g.solo
		}
		if #g.party > 0 then
			items[#items + 1] = { heading = string.format(SolaFP_L["Formed Groups  ·  %d"] or "구성된 파티  ·  %d팀", #g.party), section = "party", group = name }
			for _, pItem in ipairs(g.party) do
				items[#items + 1] = pItem
			end
		end
		if #g.solo > 0 then
			table.sort(g.solo, function(a, b)
				if (a.classToken or "~") ~= (b.classToken or "~") then
					return (a.classToken or "~") < (b.classToken or "~")
				end
				if (a.level or 0) ~= (b.level or 0) then
					return (a.level or 0) > (b.level or 0)
				end
				return a.leader < b.leader
			end)
			items[#items + 1] = { heading = string.format(SolaFP_L["Individual Seekers  ·  %d"] or "파티를 찾는 중  ·  %d명", #g.solo), section = "solo", group = name }
			for _, sItem in ipairs(g.solo) do
				items[#items + 1] = sItem
			end
		end
	end

	if statusText then
		SolaFP_LFG_UpdateStatusText(totalCount > 0 and string.format(SolaFP_L["%d listings found"] or (totalCount .. "개 등록 결과"), totalCount) or (SolaFP_L["No listings found."] or "표시할 검색 결과가 없습니다."), totalCount > 0)
	end
	renderList()
	SolaFP_LFG_UpdateFilterButton()
	SolaFP_LFG_UpdateDungeonButtonDisplay()
	SolaFP_LFG_UpdateClearExcludedButton()
end

-------------------------------------------------
-- Exclude dungeon from filter (FindParty style)
-------------------------------------------------
function SolaFP_LFG_ExcludeDungeon(dungeonName)
	if not dungeonName or dungeonName == "" then return end
	if selectedActivities and selectedActivities[dungeonName] then
		selectedActivities[dungeonName] = nil
		if SolaFP_Options and SolaFP_Options.lfgSelectedActivities then
			SolaFP_Options.lfgSelectedActivities[dungeonName] = nil
		end
		local count = getSelectedActivitiesCount()
		isActivityFiltering = (count > 0)
	end
	excludedActivities[dungeonName] = true
	if SolaFP_Options then
		if not SolaFP_Options.lfgExcludedActivities then SolaFP_Options.lfgExcludedActivities = {} end
		SolaFP_Options.lfgExcludedActivities[dungeonName] = true
	end
	expandedGroups[dungeonName] = nil
	SolaFP_LFG_UpdateDungeonButtonDisplay()
	offset = 0
	parseSearchResults()
	if activitiesMenu and activitiesMenu.UpdateList then
		activitiesMenu.UpdateList()
	end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Removed '%s' from interested dungeons."] or "'%s' 던전을 관심 던전에서 제외했습니다."), dungeonName))
	end
end

-------------------------------------------------
-- Dungeon category and activity search
-------------------------------------------------
local function getDungeonCategory()
	local categories = api("GetAvailableCategories")
	if type(categories) ~= "table" then return end
	local defaultID
	for _, id in ipairs(categories) do
		id = safe(id)
		if type(id) == "number" then
			local info = api("GetLfgCategoryInfo", id)
			local name = (type(info) == "table") and plain(info.name):lower() or ""
			if name == "던전" or name == "dungeons" or name == "dungeon" then
				return id
			end
			if id == 2 and name == "" then
				defaultID = id
			end
		end
	end
	return defaultID or 2
end

local function searchActivities(categoryID)
	local available = api("GetAvailableActivities", categoryID)
	if type(available) ~= "table" then return end

	local result = {}
	for _, id in ipairs(available) do
		id = safe(id)
		if type(id) == "number" then
			result[#result + 1] = id
		end
	end
	return result
end

function SolaFP_LFG_Search(force)
	if InCombatLockdown and InCombatLockdown() then return end
	if not isPanelVisible() then return end

	local now = GetTime and GetTime() or 0

	-- If force is false, refresh display from existing items or cached GetSearchResults without calling C_LFGList.Search
	if not force then
		if items and #items > 0 then
			parseSearchResults()
			return
		else
			local _, rIds = api("GetSearchResults")
			if type(rIds) == "table" and #rIds > 0 then
				parseSearchResults()
				return
			elseif statusText then
				SolaFP_LFG_UpdateStatusText(SolaFP_L["No listings found."] or "표시할 검색 결과가 없습니다.")
				return
			end
		end
		return
	end

	if pending then return end

	-- If user clicked refresh button, prevent fast double-clicks within throttle
	if (now - lastSearchTime < MIN_REFRESH_THROTTLE) and lastSearchTime > 0 then
		local waitSec = math.ceil(MIN_REFRESH_THROTTLE - (now - lastSearchTime))
		if statusText then SolaFP_LFG_UpdateStatusText(string.format(SolaFP_L["Waiting to refresh... (%ds cooldown)"] or "새로고침 대기 중... (%d초 후 가능)", waitSec)) end
		return
	end

	if actionMenu then actionMenu:Hide() end

	local catID = getDungeonCategory()
	dungeonCategory = catID
	if not catID or not (C_LFGList and C_LFGList.Search) then
		if statusText then SolaFP_LFG_UpdateStatusText(SolaFP_L["Initializing LFG (C_LFGList)..."] or "기본 파티 탐색기(C_LFGList)를 준비 중입니다.") end
		if C_LFGList and C_LFGList.RequestAvailableActivities then
			api("RequestAvailableActivities")
		end
		return
	end

	local ids = searchActivities(catID)
	if not ids or #ids == 0 then
		items = {}
		offset = 0
		renderList()
		if statusText then SolaFP_LFG_UpdateStatusText(SolaFP_L["No listings found."] or "표시할 검색 결과가 없습니다.") end
		return
	end

	pending = true
	lastSearchTime = now
	requestID = requestID + 1
	local currentReq = requestID
	items = {}
	offset = 0
	renderList()
	if statusText then SolaFP_LFG_UpdateStatusText(SolaFP_L["Searching..."] or "|cffD4A745검색 중...|r") end
	if SolaFP_LFG_UpdateRefreshTimer then SolaFP_LFG_UpdateRefreshTimer() end

	local ok, res = pcall(C_LFGList.Search, catID, 0, 0, nil, false, nil, ids)
	if not ok or safe(res) == false then
		pending = false
		if statusText then SolaFP_LFG_UpdateStatusText(SolaFP_L["Search request failed. (Please try again shortly)"] or "검색 요청에 실패했습니다. (잠시 후 다시 시도)") end
		if SolaFP_LFG_UpdateRefreshTimer then SolaFP_LFG_UpdateRefreshTimer() end
	elseif C_Timer and C_Timer.After then
		C_Timer.After(8, function()
			if pending and currentReq == requestID then
				pending = false
				if statusText then SolaFP_LFG_UpdateStatusText(SolaFP_L["Search timed out. Please click [Refresh]."] or "응답 시간 초과. [새로고침]을 눌러주세요.") end
				if SolaFP_LFG_UpdateRefreshTimer then SolaFP_LFG_UpdateRefreshTimer() end
			end
		end)
	end
end

-------------------------------------------------
-- Blizzard LFG Registration Window Toggle
-- Pure frame Show/Hide toggle (Taint-Free, no LFDMicroButton or ShowUIPanel)
-- Safe to use during and out of combat
-------------------------------------------------
function SolaFP_LFG_ElevateBlizzardLFGFrame(frame)
	if not frame then return end
	if frame.SetFrameStrata then
		frame:SetFrameStrata("DIALOG")
	end
	if frame.Raise then
		frame:Raise()
	end
	if not frame.__fp_elevate_hooked and frame.HookScript then
		frame.__fp_elevate_hooked = true
		frame:HookScript("OnShow", function(self)
			if self.SetFrameStrata then
				self:SetFrameStrata("DIALOG")
			end
			if self.Raise then
				self:Raise()
			end
		end)
	end
end

function SolaFP_LFG_OpenBlizzardRegister()
	-- Check if blizzard lfg addon is loaded
	if GroupFinderVanillaStyle_LoadUI then
		pcall(GroupFinderVanillaStyle_LoadUI)
	elseif C_AddOns and C_AddOns.LoadAddOn then
		pcall(C_AddOns.LoadAddOn, "Blizzard_GroupFinder_VanillaStyle")
	end

	-- Target parent lfg frame
	local frame = LFGParentFrame or PVEFrame
	if not frame then return end

	SolaFP_LFG_ElevateBlizzardLFGFrame(frame)

	-- Toggle parent frame visibility
	if frame:IsShown() then
		if frame.Hide then
			pcall(function() frame:Hide() end)
		end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
	else
		if frame.Show then
			pcall(function() frame:Show() end)
		end
		if frame.Raise then
			pcall(function() frame:Raise() end)
		end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
	end
end

local function createActionMenu(parent)
	local menu = CreateFrame("Frame", "SolaFP_LFG_ActionMenu", parent, "BackdropTemplate")
	menu:SetFrameStrata("DIALOG")
	menu:SetFrameLevel(parent:GetFrameLevel() + 50)
	menu:SetSize(156, 148)
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu:SetBackdrop(SolaFP_Backdrop)
	menu:SetBackdropColor(0.06, 0.05, 0.05, 0.98)
	menu:SetBackdropBorderColor(SolaC.gold[1] * 0.75, SolaC.gold[2] * 0.75, SolaC.gold[3] * 0.75, 0.70)

	-- Fullscreen click-catcher to dismiss menu when clicking outside
	local catcher = CreateFrame("Button", nil, menu)
	catcher:SetFrameStrata("DIALOG")
	catcher:SetFrameLevel(math.max(1, menu:GetFrameLevel() - 1))
	catcher:SetAllPoints(UIParent)
	catcher:RegisterForClicks("AnyUp", "AnyDown")
	catcher:SetScript("OnClick", function()
		menu:Hide()
	end)
	menu.__catcher = catcher

	menu:SetScript("OnMouseDown", function(_, button)
		if button == "RightButton" then
			menu:Hide()
		end
	end)

	local title = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetPoint("TOPRIGHT", -10, -8)
	title:SetJustifyH("CENTER")
	menu.title = title

	local sep = menu:CreateTexture(nil, "ARTWORK")
	sep:SetHeight(1)
	sep:SetPoint("TOPLEFT", 6, -26)
	sep:SetPoint("TOPRIGHT", -6, -26)
	sep:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.3)

	local btnWhisper = CreateFrame("Button", nil, menu, "BackdropTemplate")
	btnWhisper:SetSize(140, 20)
	btnWhisper:SetPoint("TOPLEFT", 8, -32)
	SolaFP_StyleModernButton(btnWhisper, "teal", SolaFP_L["Send Whisper"] or "귓속말 전송 (문구)")
	btnWhisper:SetScript("OnClick", function()
		menu:Hide()
		if menu.target and menu.target ~= "" then
			doWhisper(menu.target)
		end
	end)

	local btnTell = CreateFrame("Button", nil, menu, "BackdropTemplate")
	btnTell:SetSize(140, 20)
	btnTell:SetPoint("TOPLEFT", 8, -54)
	SolaFP_StyleModernButton(btnTell, "dark", SolaFP_L["Open Chat (/w)"] or "대화창 열기 (/w)")
	btnTell:SetScript("OnClick", function()
		menu:Hide()
		if menu.target and menu.target ~= "" and ChatFrame_OpenChat then
			ChatFrame_OpenChat("/w " .. menu.target .. " ")
		end
	end)

	local btnInvite = CreateFrame("Button", nil, menu, "BackdropTemplate")
	btnInvite:SetSize(140, 20)
	btnInvite:SetPoint("TOPLEFT", 8, -76)
	SolaFP_StyleModernButton(btnInvite, "dark", SolaFP_L["Invite"] or "파티 초대")
	btnInvite:SetScript("OnClick", function()
		menu:Hide()
		if menu.target and menu.target ~= "" then
			local inv = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
			if inv then inv(menu.target) end
		end
	end)

	local btnWho = CreateFrame("Button", nil, menu, "BackdropTemplate")
	btnWho:SetSize(140, 20)
	btnWho:SetPoint("TOPLEFT", 8, -98)
	SolaFP_StyleModernButton(btnWho, "dark", SolaFP_L["Who (/who)"] or "정보 조회 (/who)")
	btnWho:SetScript("OnClick", function()
		menu:Hide()
		if menu.target and menu.target ~= "" then
			doSendWho(menu.target)
		end
	end)

	local btnClose = CreateFrame("Button", nil, menu, "BackdropTemplate")
	btnClose:SetSize(140, 18)
	btnClose:SetPoint("TOPLEFT", 8, -120)
	SolaFP_StyleModernButton(btnClose, "dark", SolaFP_L["Close"] or "닫기")
	btnClose:SetScript("OnClick", function() menu:Hide() end)

	local outsideTimer = 0
	menu:SetScript("OnShow", function() outsideTimer = 0 end)
	menu:SetScript("OnUpdate", function(self, elapsed)
		if self:IsMouseOver() then
			outsideTimer = 0
		else
			outsideTimer = outsideTimer + elapsed
			if outsideTimer > 3.0 then
				self:Hide()
			end
		end
	end)

	menu:Hide()
	return menu
end

-------------------------------------------------
-- Clear selected activities (Reset to View All)
-------------------------------------------------
function SolaFP_LFG_ClearSelectedActivities()
	local hadFilters = (getSelectedActivitiesCount() > 0)
	selectedActivities = {}
	isActivityFiltering = false
	expandedGroups = {}
	if SolaFP_Options then
		SolaFP_Options.lfgSelectedActivities = {}
	end
	SolaFP_LFG_UpdateDungeonButtonDisplay()
	offset = 0
	parseSearchResults()
	if activitiesMenu and activitiesMenu.UpdateList then
		activitiesMenu.UpdateList()
	end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
	if hadFilters and DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["All dungeon filters cleared."] or "관심 던전 목록을 모두 비웠습니다. (모두 보기)"))
	end
end

-------------------------------------------------
-- Clear excluded activities (Restore all dungeons)
-------------------------------------------------
function SolaFP_LFG_ClearExcludedActivities()
	local exCount = getExcludedActivitiesCount()
	if exCount == 0 then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["No dungeons currently excluded."] or "현재 제외된 던전이 없습니다."))
		end
		return
	end
	excludedActivities = {}
	if SolaFP_Options then
		SolaFP_Options.lfgExcludedActivities = {}
	end
	SolaFP_LFG_UpdateDungeonButtonDisplay()
	offset = 0
	parseSearchResults()
	if activitiesMenu and activitiesMenu.UpdateList then
		activitiesMenu.UpdateList()
	end
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Excluded dungeons cleared."] or "제외된 던전 목록을 초기화했습니다. (모든 던전 표시)"))
	end
end

-------------------------------------------------
-- Select level-appropriate activities
-------------------------------------------------
local function selectFitActivities()
	local level = UnitLevel and safe(UnitLevel("player"))
	if not level then return end

	selectedActivities = {}
	local count = 0
	if updateAvailableActivities then updateAvailableActivities() end
	for name in pairs(activities) do
		local range = activityLevels and activityLevels[name]
		if range then
			local low, high = range:match("^(%d+)%D+(%d+)$")
			low = tonumber(low) or tonumber(range)
			high = tonumber(high) or low
			if low and level >= low and level <= high then
				selectedActivities[name] = true
				count = count + 1
			end
		end
	end

	if count > 0 then
		isActivityFiltering = true
		expandedGroups = {}
		if SolaFP_Options then
			SolaFP_Options.lfgSelectedActivities = {}
			for k, v in pairs(selectedActivities) do
				SolaFP_Options.lfgSelectedActivities[k] = v
			end
		end
		SolaFP_LFG_UpdateDungeonButtonDisplay()
	SolaFP_LFG_UpdateClearExcludedButton()
		offset = 0
		parseSearchResults()
		if activitiesMenu and activitiesMenu.UpdateList then
			activitiesMenu.UpdateList()
		end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Level-fit dungeons selected (%d)."] or "내 레벨에 맞는 적정 던전(%d개)이 관심 던전으로 선택되었습니다."), count))
		end
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["No level-fit dungeons found for your level."] or "현재 레벨에 맞는 적정 던전이 없습니다."))
		end
	end
end

-------------------------------------------------
-- Toggle between View All and Interested Dungeons filter
-------------------------------------------------
function SolaFP_LFG_ToggleSelectedActivitiesFilter()
	local count = getSelectedActivitiesCount()
	if count == 0 then
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["No interested dungeons selected."] or "선택된 관심 던전이 없습니다. 던전 목록에서 관심 던전을 먼저 선택해주세요."))
		end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		return
	end

	isActivityFiltering = not isActivityFiltering
	SolaFP_LFG_UpdateDungeonButtonDisplay()
	offset = 0
	parseSearchResults()
	if activitiesMenu and activitiesMenu.UpdateList then
		activitiesMenu.UpdateList()
	end

	if isActivityFiltering then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Filtered to interested dungeons."] or "관심 던전 필터가 활성화되었습니다."))
		end
	else
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		if DEFAULT_CHAT_FRAME then
			DEFAULT_CHAT_FRAME:AddMessage("|cffD4A745[SolaLFG]|r " .. (SolaFP_L["Showing all dungeons."] or "모든 던전을 표시합니다. (모두 보기)"))
		end
	end
end

-------------------------------------------------
-- Dungeon filter dropdown menu
-------------------------------------------------
local function createActivitiesMenu(parent)
	local menu = CreateFrame("Frame", "SolaFP_LFG_ActivitiesMenu", parent, "BackdropTemplate")
	menu:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -66)
	menu:SetSize(248, 252)
	menu:SetFrameStrata("DIALOG")
	menu:SetFrameLevel(parent:GetFrameLevel() + 45)
	menu:EnableMouse(true)
	menu:SetBackdrop(SolaFP_Backdrop)
	menu:SetBackdropColor(0.06, 0.05, 0.05, 0.98)
	menu:SetBackdropBorderColor(SolaC.gold[1] * 0.75, SolaC.gold[2] * 0.75, SolaC.gold[3] * 0.75, 0.70)

	menu:SetScript("OnMouseDown", function(_, button)
		if button == "RightButton" then
			menu:Hide()
		end
	end)

	local scrollSlider, sThumb, btnUp, btnDown, pageFrame, pageText
	local syncing = false

	local function updateActivityRows()
		if updateAvailableActivities then updateAvailableActivities() end
		local names = {}
		for name in pairs(activities) do names[#names + 1] = name end

		local function getDungeonLevel(name)
			local range = (activityLevels and activityLevels[name]) or ""
			local low, high = range:match("^(%d+)%D+(%d+)$")
			if low and high then
				return tonumber(high) or 0, tonumber(low) or 0
			end
			local single = tonumber(range) or 0
			return single, single
		end

		table.sort(names, function(a, b)
			local maxA, minA = getDungeonLevel(a)
			local maxB, minB = getDungeonLevel(b)
			if maxA ~= maxB then
				return maxA > maxB
			end
			if minA ~= minB then
				return minA > minB
			end
			return a < b
		end)
		local maxOffset = math.max(0, #names - 12)
		activityOffset = math.max(0, math.min(activityOffset, maxOffset))
		local visible = math.min(12, #names)
		menu:SetHeight(visible * 24 + 40)
		for i, row in ipairs(activityRows) do
			local name = names[activityOffset + i]
			row.actName = name
			if name then
				row.text:SetText(name)
				local range = activityLevels and activityLevels[name]
				if range and range ~= "" then
					local displayLvl = tostring(range):gsub("^%s*[Ll][Vv]%.?%s*", "")
					row.levelText:SetText(displayLvl)
				else
					row.levelText:SetText("")
				end
				row.check:SetChecked(selectedActivities[name] == true)
				row:Show()
			else
				row:Hide()
			end
		end

		if scrollSlider then
			if maxOffset > 0 then
				syncing = true
				scrollSlider:SetMinMaxValues(0, maxOffset)
				scrollSlider:SetValue(activityOffset)

				local trackH = scrollSlider:GetHeight() or 0
				if trackH < 30 then trackH = 240 end
				local thumbH = math.max(16, math.min(trackH - 6, math.floor(trackH * (visible / #names))))
				sThumb:SetSize(6, thumbH)
				scrollSlider:SetThumbTexture(sThumb)

				scrollSlider:Show()
				btnUp:Show()
				btnDown:Show()
				pageFrame:Show()

				if activityOffset <= 0 then
					btnUp:Disable()
					btnUp.text:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3], 0.3)
				else
					btnUp:Enable()
					btnUp.text:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.9)
				end

				if activityOffset >= maxOffset then
					btnDown:Disable()
					btnDown.text:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3], 0.3)
				else
					btnDown:Enable()
					btnDown.text:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.9)
				end

				local curPage = math.floor(activityOffset / 12) + 1
				local totalPages = math.max(1, math.ceil(#names / 12))
				pageText:SetText(string.format("%d/%d", curPage, totalPages))
				syncing = false
			else
				scrollSlider:Hide()
				btnUp:Hide()
				btnDown:Hide()
				pageFrame:Hide()
			end
		end
	end

	local btnClear = CreateFrame("Button", nil, menu, "BackdropTemplate")
	btnClear:SetSize(84, 20)
	btnClear:SetPoint("TOPLEFT", 8, -8)
	SolaFP_StyleModernButton(btnClear, "dark", SolaFP_L["Reset Selection"] or "선택 비우기")
	btnClear:SetScript("OnClick", SolaFP_LFG_ClearSelectedActivities)

	local btnFit = CreateFrame("Button", nil, menu, "BackdropTemplate")
	btnFit:SetSize(84, 20)
	btnFit:SetPoint("LEFT", btnClear, "RIGHT", 6, 0)
	SolaFP_StyleModernButton(btnFit, "teal", SolaFP_L["Select Fit"] or "적정 던전")
	btnFit:SetScript("OnClick", selectFitActivities)

	local sep = menu:CreateTexture(nil, "ARTWORK")
	sep:SetHeight(1)
	sep:SetPoint("TOPLEFT", 6, -32)
	sep:SetPoint("TOPRIGHT", -6, -32)
	sep:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.3)

	pageFrame = CreateFrame("Frame", nil, menu)
	pageFrame:SetPoint("LEFT", btnFit, "RIGHT", 4, 0)
	pageFrame:SetPoint("RIGHT", menu, "RIGHT", -6, 0)
	pageFrame:SetPoint("TOP", menu, "TOP", 0, -8)
	pageFrame:SetPoint("BOTTOM", sep, "TOP", 0, 4)

	pageText = pageFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	pageText:SetPoint("CENTER", 0, 0)
	pageText:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.9)
	pageFrame.text = pageText

	local function showScrollTip(self)
		local names = {}
		for name in pairs(activities) do names[#names + 1] = name end
		local total = #names
		if total <= 12 then return end
		local curStart = activityOffset + 1
		local curEnd = math.min(total, activityOffset + 12)
		local curPage = math.floor(activityOffset / 12) + 1
		local totalPages = math.max(1, math.ceil(total / 12))
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(SolaFP_L["Dungeon List Scroll"] or "던전 목록 스크롤", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		GameTooltip:AddLine(string.format(SolaFP_L["Page: %d / %d (%d-%d of %d)"] or "페이지: %d / %d (항목: %d-%d / 총 %d개)", curPage, totalPages, curStart, curEnd, total), 1, 1, 1)
		GameTooltip:AddLine(SolaFP_L["Scroll with mouse wheel or drag slider."] or "|cff66FF99마우스 휠|r 또는 |cff66FF99드래그|r로 목록을 이동할 수 있습니다.", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		GameTooltip:Show()
	end
	local function hideScrollTip()
		GameTooltip:Hide()
	end

	pageFrame:EnableMouse(true)
	pageFrame:SetScript("OnEnter", showScrollTip)
	pageFrame:SetScript("OnLeave", hideScrollTip)
	pageFrame:SetScript("OnMouseDown", function(_, button)
		if button == "RightButton" then
			menu:Hide()
		end
	end)

	local function onWheel(_, delta)
		local names = {}
		for name in pairs(activities) do names[#names + 1] = name end
		local maxOffset = math.max(0, #names - 12)
		if maxOffset <= 0 then return end
		activityOffset = math.max(0, math.min(maxOffset, activityOffset - delta))
		updateActivityRows()
	end

	pageFrame:EnableMouseWheel(true)
	pageFrame:SetScript("OnMouseWheel", onWheel)

	btnUp = CreateFrame("Button", nil, menu)
	btnUp:SetSize(14, 12)
	btnUp:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -5, -36)
	local upText = btnUp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	upText:SetPoint("CENTER", 0, 0)
	upText:SetText("▲")
	upText:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.9)
	btnUp.text = upText
	btnUp:EnableMouseWheel(true)
	btnUp:SetScript("OnMouseWheel", onWheel)
	btnUp:SetScript("OnClick", function()
		activityOffset = math.max(0, activityOffset - 1)
		updateActivityRows()
	end)
	btnUp:HookScript("OnEnter", function(self)
		if self:IsEnabled() then self.text:SetTextColor(1, 1, 1) end
		showScrollTip(self)
	end)
	btnUp:HookScript("OnLeave", function(self)
		if self:IsEnabled() then self.text:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.9) end
		hideScrollTip()
	end)

	btnDown = CreateFrame("Button", nil, menu)
	btnDown:SetSize(14, 12)
	btnDown:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -5, 8)
	local downText = btnDown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	downText:SetPoint("CENTER", 0, 0)
	downText:SetText("▼")
	downText:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.9)
	btnDown.text = downText
	btnDown:EnableMouseWheel(true)
	btnDown:SetScript("OnMouseWheel", onWheel)
	btnDown:SetScript("OnClick", function()
		local names = {}
		for name in pairs(activities) do names[#names + 1] = name end
		local maxOffset = math.max(0, #names - 12)
		if maxOffset <= 0 then return end
		activityOffset = math.min(maxOffset, activityOffset + 1)
		updateActivityRows()
	end)
	btnDown:HookScript("OnEnter", function(self)
		if self:IsEnabled() then self.text:SetTextColor(1, 1, 1) end
		showScrollTip(self)
	end)
	btnDown:HookScript("OnLeave", function(self)
		if self:IsEnabled() then self.text:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.9) end
		hideScrollTip()
	end)

	scrollSlider = CreateFrame("Slider", nil, menu)
	scrollSlider:SetPoint("TOP", btnUp, "BOTTOM", 0, -2)
	scrollSlider:SetPoint("BOTTOM", btnDown, "TOP", 0, 2)
	scrollSlider:SetPoint("RIGHT", menu, "RIGHT", -8, 0)
	scrollSlider:SetWidth(8)
	scrollSlider:SetOrientation("VERTICAL")
	scrollSlider:SetValueStep(1)
	if scrollSlider.SetObeyStepOnDrag then scrollSlider:SetObeyStepOnDrag(true) end
	scrollSlider:EnableMouse(true)
	scrollSlider:EnableMouseWheel(true)
	scrollSlider:SetScript("OnMouseWheel", onWheel)

	local sTrack = scrollSlider:CreateTexture(nil, "BACKGROUND")
	sTrack:SetAllPoints()
	sTrack:SetColorTexture(SolaC.bgInput[1], SolaC.bgInput[2], SolaC.bgInput[3], 0.85)

	local sTrackLine = scrollSlider:CreateTexture(nil, "BORDER")
	sTrackLine:SetPoint("TOPLEFT", -1, 0)
	sTrackLine:SetPoint("BOTTOMLEFT", -1, 0)
	sTrackLine:SetWidth(1)
	sTrackLine:SetColorTexture(SolaC.gold[1] * 0.4, SolaC.gold[2] * 0.4, SolaC.gold[3] * 0.4, 0.35)

	sThumb = scrollSlider:CreateTexture(nil, "ARTWORK")
	sThumb:SetSize(6, 22)
	sThumb:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.75)
	scrollSlider:SetThumbTexture(sThumb)

	scrollSlider:SetScript("OnValueChanged", function(_, val)
		if not syncing then
			local newOffset = math.floor(val + 0.5)
			if newOffset ~= activityOffset then
				activityOffset = newOffset
				updateActivityRows()
			end
		end
	end)
	scrollSlider:SetScript("OnEnter", function(self)
		sThumb:SetColorTexture(SolaC.gold[1] * 1.2, SolaC.gold[2] * 1.2, SolaC.gold[3] * 1.2, 1.0)
		showScrollTip(self)
	end)
	scrollSlider:SetScript("OnLeave", function()
		sThumb:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.75)
		hideScrollTip()
	end)

	for i = 1, 12 do
		local row = CreateFrame("Button", nil, menu)
		row:SetSize(216, 22)
		row:SetPoint("TOPLEFT", 8, -36 - (i - 1) * 24)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:EnableMouseWheel(true)
		row:SetScript("OnMouseWheel", onWheel)

		local rowHl = row:CreateTexture(nil, "BACKGROUND")
		rowHl:SetAllPoints(row)
		rowHl:SetColorTexture(1, 1, 1, 0.04)
		rowHl:Hide()
		row.hl = rowHl

		local cbox = CreateFrame("Frame", nil, row)
		cbox:SetSize(13, 13)
		cbox:SetPoint("LEFT", row, "LEFT", 3, 0)
		cbox:EnableMouse(false)

		local cboxBg = cbox:CreateTexture(nil, "BACKGROUND")
		cboxBg:SetAllPoints(cbox)
		cboxBg:SetColorTexture(0.08, 0.09, 0.11, 0.90)
		cbox.bg = cboxBg

		local function CreateBorder(p1, p2, p3, p4, w, h)
			local b = cbox:CreateTexture(nil, "BORDER")
			b:SetPoint(p1, cbox, p2, 0, 0)
			b:SetPoint(p3, cbox, p4, 0, 0)
			if w then b:SetWidth(w) end
			if h then b:SetHeight(h) end
			return b
		end
		cbox.b_top = CreateBorder("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT", nil, 1)
		cbox.b_btm = CreateBorder("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT", nil, 1)
		cbox.b_lft = CreateBorder("TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT", 1, nil)
		cbox.b_rgt = CreateBorder("TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT", 1, nil)

		local function SetCboxBorder(r, g, b, a)
			cbox.b_top:SetColorTexture(r, g, b, a)
			cbox.b_btm:SetColorTexture(r, g, b, a)
			cbox.b_lft:SetColorTexture(r, g, b, a)
			cbox.b_rgt:SetColorTexture(r, g, b, a)
		end

		local gdot = cbox:CreateTexture(nil, "ARTWORK")
		gdot:SetTexture("Interface\\Buttons\\WHITE8X8")
		gdot:SetSize(5, 5)
		gdot:SetPoint("CENTER", cbox, "CENTER", 0, 0)
		gdot:SetVertexColor(SolaC.gold[1] * 1.15, SolaC.gold[2] * 1.15, SolaC.gold[3] * 1.15, 1.0)
		gdot:Hide()
		cbox.gdot = gdot

		local levelText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		levelText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		levelText:SetJustifyH("RIGHT")
		levelText:SetWordWrap(false)

		local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		text:SetPoint("LEFT", cbox, "RIGHT", 6, 0)
		text:SetPoint("RIGHT", levelText, "LEFT", -6, 0)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)

		local function UpdateRowVisuals(isChecked)
			row.__isChecked = isChecked
			if isChecked then
				cbox.bg:SetColorTexture(0.14, 0.12, 0.06, 0.95)
				SetCboxBorder(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.95)
				gdot:Show()
				text:SetTextColor(0.95, 0.95, 0.95, 1.0)
				levelText:SetTextColor(0.50, 0.75, 0.85, 1.0)
			else
				cbox.bg:SetColorTexture(0.08, 0.09, 0.11, 0.90)
				SetCboxBorder(0.28, 0.32, 0.36, 0.75)
				gdot:Hide()
				text:SetTextColor(0.55, 0.55, 0.55, 0.85)
				levelText:SetTextColor(0.40, 0.50, 0.58, 0.80)
			end
		end

		row.check = {
			SetChecked = function(_, val)
				UpdateRowVisuals(val and true or false)
			end,
			GetChecked = function(_)
				return row.__isChecked == true
			end,
		}

		row:SetScript("OnClick", function(self, button)
			if button == "RightButton" then
				menu:Hide()
				return
			end
			if row.actName then
				local newVal = not row.__isChecked
				UpdateRowVisuals(newVal)
				if newVal then
					selectedActivities[row.actName] = true
					excludedActivities[row.actName] = nil
					expandedGroups[row.actName] = nil
				else
					selectedActivities[row.actName] = nil
					excludedActivities[row.actName] = nil
					expandedGroups[row.actName] = nil
				end
				if SolaFP_Options then
					if not SolaFP_Options.lfgSelectedActivities then SolaFP_Options.lfgSelectedActivities = {} end
					SolaFP_Options.lfgSelectedActivities[row.actName] = newVal or nil
					if SolaFP_Options.lfgExcludedActivities then
						SolaFP_Options.lfgExcludedActivities[row.actName] = nil
					end
				end

				local count = getSelectedActivitiesCount()
				isActivityFiltering = (count > 0)
				SolaFP_LFG_UpdateDungeonButtonDisplay()
				PlaySound(newVal and (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857))
				offset = 0
				parseSearchResults()
			end
		end)

		row:SetScript("OnEnter", function()
			rowHl:Show()
			if row.__isChecked then
				SetCboxBorder(1.0, 0.88, 0.45, 1.0)
				text:SetTextColor(1, 1, 1, 1.0)
				levelText:SetTextColor(0.65, 0.88, 0.98, 1.0)
			else
				SetCboxBorder(0.50, 0.62, 0.68, 0.95)
				text:SetTextColor(0.85, 0.85, 0.85, 1.0)
				levelText:SetTextColor(0.55, 0.68, 0.78, 0.95)
			end
		end)

		row:SetScript("OnLeave", function()
			rowHl:Hide()
			UpdateRowVisuals(row.__isChecked)
		end)

		row.text = text
		row.levelText = levelText
		activityRows[i] = row
	end

	menu:EnableMouseWheel(true)
	menu:SetScript("OnMouseWheel", onWheel)

	menu.UpdateList = updateActivityRows
	menu:Hide()
	return menu
end

-------------------------------------------------
-- Initialize LFG panel
-------------------------------------------------
function SolaFP_LFG_Init()
	-- Preload Blizzard LFG UI to prevent dynamic load taint during combat
	if GroupFinderVanillaStyle_LoadUI then
		pcall(GroupFinderVanillaStyle_LoadUI)
	elseif C_AddOns and C_AddOns.LoadAddOn then
		pcall(C_AddOns.LoadAddOn, "Blizzard_GroupFinder_VanillaStyle")
	end
	if SolaFP_LFG_ElevateBlizzardLFGFrame then
		SolaFP_LFG_ElevateBlizzardLFGFrame(LFGParentFrame or PVEFrame)
	end

	if SolaFP_LFGPanel or not SolaFP_Frame or not SolaFP_TitleFrame or not SolaFP_MenuFrame then return end

	local panel = CreateFrame("Frame", "SolaFP_LFGPanel", SolaFP_Frame, "BackdropTemplate")
	panel:SetFrameStrata("HIGH")
	panel:SetPoint("TOPLEFT", SolaFP_TitleFrame, "TOPRIGHT", 2, 0)
	panel:SetPoint("BOTTOMLEFT", SolaFP_MenuFrame, "BOTTOMRIGHT", 2, 0)
	panel:SetWidth(390)
	panel:SetBackdrop(windowBackdrop)
	panel:SetBackdropColor(SolaC.bgSidebar[1], SolaC.bgSidebar[2], SolaC.bgSidebar[3], SolaC.bgSidebar[4])
	panel:SetBackdropBorderColor(0.73, 0.58, 0.35, 0.90)
	panel:EnableMouse(true)
	panel:SetClampedToScreen(false)

	-- Match the visual vocabulary of Blizzard's quest windows with a small
	-- in-game note icon and the client's locale-aware heading font.
	local emblem = panel:CreateTexture(nil, "ARTWORK")
	emblem:SetPoint("TOPLEFT", 12, -8)
	emblem:SetSize(21, 21)
	emblem:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
	emblem:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", emblem, "RIGHT", 8, 0)
	title:SetText(SolaFP_GetLocale() == "koKR" and "파티 탐색기" or "Group Finder")
	panel.titleText = title

	-- Standalone Keybind button
	local keyBtn = CreateFrame("Button", "SolaFP_LFG_KeyBindBtn", panel, "BackdropTemplate")
	keyBtn:SetSize(50, 22)
	keyBtn:SetPoint("LEFT", title, "RIGHT", 8, 0)
	if SolaFP_StyleAndHookKeyBindButton then
		SolaFP_StyleAndHookKeyBindButton(keyBtn)
	end
	if not (SolaFP_Options and SolaFP_Options.lfgOnly) then
		keyBtn:Hide()
	end

	-- Close button
	local closeBtn = CreateFrame("Button", "SolaFP_LFG_CloseBtn", panel, "BackdropTemplate")
	closeBtn:SetSize(22, 22)
	closeBtn:SetPoint("TOPRIGHT", -6, -7)
	SolaFP_StyleCloseButton(closeBtn)
	closeBtn:SetScript("OnClick", function()
		if SolaFP_Options and SolaFP_Options.lfgOnly then
			panel:Hide()
		else
			SolaFP_LFG_Toggle(false)
		end
	end)

	-- Standalone Option button
	local isEnLocale = ((SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) ~= "koKR")
	local optBtn = CreateFrame("Button", "SolaFP_LFG_OptionBtn", panel, "BackdropTemplate")
	optBtn:SetSize(isEnLocale and 58 or 36, 22)
	optBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -4, 0)
	SolaFP_StyleModernButton(optBtn, "dark", SolaFP_L["Settings"] or "설정")
	optBtn:RegisterForClicks("LeftButtonDown", "RightButtonDown")
	optBtn:SetScript("OnClick", function(self, button)
		if SolaFP_MenuClicked then
			SolaFP_MenuClicked(self, button, "MENU_OPTION")
		end
	end)
	optBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(SolaFP_L["Settings"] or "설정", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		GameTooltip:Show()
	end)
	optBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	if not (SolaFP_Options and SolaFP_Options.lfgOnly) then
		optBtn:Hide()
	end

	-- Standalone Scale Slider (placed to the left of optBtn)
	local lfgScaleSlider = CreateFrame("Slider", "SolaFP_LFG_ScaleSlider", panel)
	lfgScaleSlider:SetOrientation("HORIZONTAL")
	lfgScaleSlider:SetSize(56, 8)
	lfgScaleSlider:SetPoint("RIGHT", optBtn, "LEFT", -8, 0)
	lfgScaleSlider:SetMinMaxValues(0.5, 2.0)
	lfgScaleSlider:SetValueStep(0.05)
	if lfgScaleSlider.SetObeyStepOnDrag then
		lfgScaleSlider:SetObeyStepOnDrag(true)
	end

	local lfgSBg = lfgScaleSlider:CreateTexture(nil, "BACKGROUND")
	lfgSBg:SetAllPoints()
	lfgSBg:SetColorTexture(SolaC.bgInput[1], SolaC.bgInput[2], SolaC.bgInput[3], 0.8)

	local lfgSFill = lfgScaleSlider:CreateTexture(nil, "ARTWORK")
	lfgSFill:SetPoint("LEFT", lfgScaleSlider, "LEFT", 0, 0)
	lfgSFill:SetHeight(8)
	lfgSFill:SetColorTexture(SolaC.goldMuted[1], SolaC.goldMuted[2], SolaC.goldMuted[3], 0.45)
	lfgScaleSlider.__fp_fill = lfgSFill

	local lfgSThumb = lfgScaleSlider:CreateTexture(nil, "ARTWORK", nil, 1)
	lfgSThumb:SetSize(8, 14)
	lfgSThumb:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 1)
	lfgScaleSlider:SetThumbTexture(lfgSThumb)

	local lfgSLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	lfgSLabel:SetPoint("RIGHT", lfgScaleSlider, "LEFT", -4, 0)
	lfgSLabel:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
	lfgScaleSlider.__fp_label = lfgSLabel

	local function UpdateLFGScaleLabel(val)
		local pct = math.floor(val * 100 + 0.5)
		lfgSLabel:SetText(string.format("UI |cffD4A745%d%%|r", pct))
	end

	local function UpdateLFGScaleFill(val)
		local ratio = (val - 0.5) / 1.5
		if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
		local w = lfgScaleSlider:GetWidth()
		if w and w > 0 then
			lfgSFill:SetWidth(math.max(1, w * ratio))
		end
	end

	lfgScaleSlider:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(SolaFP_L["Window Scale (UI Scale)"] or "창 크기 조절 (UI Scale)", 1, 0.82, 0)
		GameTooltip:AddLine(SolaFP_L["Drag the slider to adjust SolaLFG scale (50% ~ 200%)."] or "슬라이더를 드래그하여 SolaLFG 창 크기를 조절합니다. (50% ~ 200%)", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	lfgScaleSlider:SetScript("OnLeave", function() GameTooltip:Hide() end)

	lfgScaleSlider:SetScript("OnMouseUp", function(self)
		local val = self:GetValue()
		val = math.floor(val * 20 + 0.5) / 20
		SolaFP_Options.scale = val
		if SolaFP_UIResize then SolaFP_UIResize(val) end
	end)

	lfgScaleSlider:SetScript("OnValueChanged", function(self, val)
		val = math.floor(val * 20 + 0.5) / 20
		UpdateLFGScaleLabel(val)
		UpdateLFGScaleFill(val)
		if not IsMouseButtonDown("LeftButton") then
			SolaFP_Options.scale = val
			if SolaFP_UIResize then SolaFP_UIResize(val) end
		end
	end)

	lfgScaleSlider:SetScript("OnSizeChanged", function(self)
		UpdateLFGScaleFill(self:GetValue())
	end)

	local curSc = tonumber(SolaFP_Options and SolaFP_Options.scale) or 1.0
	lfgScaleSlider:SetValue(curSc)
	UpdateLFGScaleLabel(curSc)
	UpdateLFGScaleFill(curSc)

	if not (SolaFP_Options and SolaFP_Options.lfgOnly) then
		lfgScaleSlider:Hide()
		lfgSLabel:Hide()
	end

	-- Unified drag move handlers for smooth movement
	local function OnLFGDragStart()
		SolaFP_LFG_StartMoving()
	end

	local function OnLFGDragStop()
		SolaFP_LFG_StopMoving()
	end

	-- Dedicated title bar drag frame (covers header title area without blocking buttons)
	local titleBar = CreateFrame("Frame", "SolaFP_LFG_TitleBar", panel)
	titleBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
	local initialRight = (SolaFP_Options and SolaFP_Options.lfgOnly) and -182 or -32
	titleBar:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", initialRight, -36)
	titleBar:EnableMouse(true)
	titleBar:SetScript("OnMouseDown", function(self, button)
		if DropDownList1 and DropDownList1:IsShown() then
			CloseDropDownMenus()
		end
		if actionMenu and actionMenu:IsShown() then
			actionMenu:Hide()
		end
		if activitiesMenu and activitiesMenu:IsShown() then
			activitiesMenu:Hide()
		end
		if button == "LeftButton" then
			OnLFGDragStart()
		elseif button == "RightButton" then
			if SolaFP_CloseOnRightClick then
				SolaFP_CloseOnRightClick()
			end
		end
	end)
	titleBar:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			OnLFGDragStop()
		end
	end)
	if keyBtn and titleBar then
		keyBtn:SetFrameLevel(titleBar:GetFrameLevel() + 5)
	end

	-- Panel background dragging and right-click handling
	panel:SetMovable(true)
	panel:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			OnLFGDragStart()
		elseif button == "RightButton" then
			if SolaFP_CloseOnRightClick then
				SolaFP_CloseOnRightClick()
			end
		end
	end)
	panel:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			OnLFGDragStop()
		end
	end)

	-- Header divider
	local headerSep = panel:CreateTexture(nil, "ARTWORK", nil, 6)
	headerSep:SetPoint("TOPLEFT", 1, -36)
	headerSep:SetPoint("TOPRIGHT", -1, -36)
	headerSep:SetHeight(1)
	headerSep:SetColorTexture(unpack(SolaC.glassLine))

	-- Dungeon filter button
	local isEnLocale = ((SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) ~= "koKR")
	local dungeonBtn = CreateFrame("Button", "SolaFP_LFG_DungeonBtn", panel, "BackdropTemplate")
	dungeonBtn:SetSize(isEnLocale and 116 or 102, 22)
	dungeonBtn:SetPoint("TOPLEFT", 10, -42)
	SolaFP_StyleModernButton(dungeonBtn, nil, (SolaFP_DUNGEONFILTER_NOT_FILTERED or "모두 보기") .. " |cffD4A745▼|r")
	dungeonBtn:SetBackdropBorderColor(SolaC.goldMuted[1], SolaC.goldMuted[2], SolaC.goldMuted[3], 0.80)
	local dungeonFs = dungeonBtn:GetFontString()
	if dungeonFs then
		dungeonFs:SetWordWrap(false)
	end
	dungeonBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	dungeonBtn:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			SolaFP_LFG_ClearSelectedActivities()
		elseif button == "MiddleButton" then
			SolaFP_LFG_ToggleSelectedActivitiesFilter()
		else
			if not activitiesMenu then return end
			if activitiesMenu:IsShown() then
				activitiesMenu:Hide()
				SolaFP_LFG_UpdateDungeonButtonDisplay()
			else
				activityOffset = 0
				if activitiesMenu.UpdateList then activitiesMenu.UpdateList() end
				activitiesMenu:Show()
				self:SetBackdropBorderColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.95)
			end
		end
		-- When clicking dungeon filter, ensure search results are loaded
		if not items or #items == 0 or (lastSearchTime == 0) then
			SolaFP_LFG_Search(true)
		end
	end)

	dungeonBtn:HookScript("OnEnter", function(self)
		self:SetBackdropBorderColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.95)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(SolaFP_L["Dungeon Filter"] or "던전 필터", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		GameTooltip:AddLine(SolaFP_L["Filter by specific dungeons."] or "원하는 던전을 선택하여 관심 던전만 표시합니다.", 0.941, 0.929, 0.910, true)
		GameTooltip:AddLine(SolaFP_L["Left-Click: Toggle dungeon filter menu"] or "|cff66FF99좌클릭|r: 던전 필터 메뉴 열기/닫기", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		GameTooltip:AddLine(SolaFP_L["Wheel-Click: Toggle View All / Filtered"] or "|cffE0C068휠클릭|r: 모두 보기 / 관심 던전 전환", 0.90, 0.80, 0.40)
		GameTooltip:AddLine(SolaFP_L["Right-Click: Clear selected dungeons"] or "|cff66FF99우클릭|r: 선택된 던전 비우기 (모두 보기)", 0.45, 0.98, 0.75)
		GameTooltip:AddLine(SolaFP_L["Shortcut Tip: Ctrl+Click row to exclude"] or "|cffFF6666Ctrl+좌클릭|r: 관심 던전에서 제외", 0.85, 0.55, 0.55)
		GameTooltip:Show()
	end)
	dungeonBtn:HookScript("OnLeave", function(self)
		if activitiesMenu and activitiesMenu:IsShown() then
			self:SetBackdropBorderColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.95)
		else
			SolaFP_LFG_UpdateDungeonButtonDisplay()
		end
		GameTooltip:Hide()
	end)

	-- Refresh button
	local refreshBtn = CreateFrame("Button", "SolaFP_LFG_RefreshBtn", panel, "BackdropTemplate")
	refreshBtn:SetSize(isEnLocale and 72 or 56, 22)
	refreshBtn:SetPoint("LEFT", dungeonBtn, "RIGHT", 4, 0)
	SolaFP_StyleModernButton(refreshBtn, "dark", SolaFP_L["Refresh"] or "새로고침")
	refreshBtn:SetBackdropBorderColor(0.57, 0.46, 0.30, 0.45)

	refreshBtn:SetScript("OnClick", function()
		SolaFP_LFG_Search(true)
	end)

	refreshBtn:HookScript("OnEnter", function(self)
		self._tipTimer = 0
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		local now = GetTime and GetTime() or 0
		if lastSearchTime and lastSearchTime > 0 then
			local elapsed = math.floor(now - lastSearchTime)
			GameTooltip:AddLine(string.format(SolaFP_L["Last refreshed: %d sec ago"] or "이전 전체 새로고침 시간: %d초 전", elapsed), 0.941, 0.929, 0.910)
		else
			GameTooltip:AddLine(SolaFP_L["Last refreshed: Never"] or "이전 전체 새로고침 시간: 없음", 0.941, 0.929, 0.910)
		end
		GameTooltip:Show()
	end)
	refreshBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

	-- Level filter segment switch
	local levelSegFrame = CreateFrame("Frame", "SolaFP_LFG_LevelSegment", panel, "BackdropTemplate")
	levelSegFrame:SetSize(isEnLocale and 102 or 84, 22)
	levelSegFrame:SetPoint("LEFT", refreshBtn, "RIGHT", 4, 0)
	levelSegFrame:SetBackdrop(SolaFP_Backdrop)
	levelSegFrame:SetBackdropColor(0.06, 0.05, 0.05, 0.95)
	levelSegFrame:SetBackdropBorderColor(0.28, 0.26, 0.24, 0.85)

	local segDivider = levelSegFrame:CreateTexture(nil, "BORDER")
	segDivider:SetSize(1, 12)
	segDivider:SetPoint("CENTER", levelSegFrame, "CENTER", 0, 0)
	segDivider:SetColorTexture(1, 1, 1, 0.08)

	local segFitBtn = CreateFrame("Button", "SolaFP_LFG_SegFitBtn", levelSegFrame, "BackdropTemplate")
	segFitBtn:SetSize(isEnLocale and 56 or 41, 20)
	segFitBtn:SetPoint("TOPLEFT", levelSegFrame, "TOPLEFT", 1, -1)
	local fitText = segFitBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fitText:SetPoint("CENTER", 0, 0)
	fitText:SetText(SolaFP_L["Level"] or "적정")
	fitText:SetShadowOffset(1, -1)
	fitText:SetShadowColor(0, 0, 0, 0.9)
	segFitBtn.text = fitText

	local segAllBtn = CreateFrame("Button", "SolaFP_LFG_SegAllBtn", levelSegFrame, "BackdropTemplate")
	segAllBtn:SetSize(isEnLocale and 44 or 41, 20)
	segAllBtn:SetPoint("TOPRIGHT", levelSegFrame, "TOPRIGHT", -1, -1)
	local allText = segAllBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	allText:SetPoint("CENTER", 0, 0)
	allText:SetText(SolaFP_L["All"] or "모든")
	allText:SetShadowOffset(1, -1)
	allText:SetShadowColor(0, 0, 0, 0.9)
	segAllBtn.text = allText

	local function updateLevelSegmentDisplay(isAllLevels)
		if isAllLevels then
			-- All levels selected
			segAllBtn:SetBackdrop(SolaFP_Backdrop)
			segAllBtn:SetBackdropColor(SolaC.gold[1] * 0.40, SolaC.gold[2] * 0.40, SolaC.gold[3] * 0.40, 0.95)
			segAllBtn:SetBackdropBorderColor(SolaC.gold[1] * 0.85, SolaC.gold[2] * 0.85, SolaC.gold[3] * 0.85, 0.85)
			allText:SetTextColor(SolaC.goldBeige[1], SolaC.goldBeige[2], SolaC.goldBeige[3])

			-- Appropriate level unselected
			segFitBtn:SetBackdrop(SolaFP_Backdrop)
			segFitBtn:SetBackdropColor(0, 0, 0, 0)
			segFitBtn:SetBackdropBorderColor(0, 0, 0, 0)
			fitText:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		else
			-- Appropriate level selected
			segFitBtn:SetBackdrop(SolaFP_Backdrop)
			segFitBtn:SetBackdropColor(0.18, 0.38, 0.28, 0.95)
			segFitBtn:SetBackdropBorderColor(0.35, 0.82, 0.62, 0.85)
			fitText:SetTextColor(0.45, 0.98, 0.75)

			-- All levels unselected
			segAllBtn:SetBackdrop(SolaFP_Backdrop)
			segAllBtn:SetBackdropColor(0, 0, 0, 0)
			segAllBtn:SetBackdropBorderColor(0, 0, 0, 0)
			allText:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		end
	end

	local initialAll = true
	if SolaFP_Options and SolaFP_Options.lfgAllLevels ~= nil then
		initialAll = not not SolaFP_Options.lfgAllLevels
	end
	updateLevelSegmentDisplay(initialAll)

	segFitBtn:SetScript("OnClick", function()
		if SolaFP_Options and SolaFP_Options.lfgAllLevels == false then return end
		if SolaFP_Options then
			SolaFP_Options.lfgAllLevels = false
		end
		updateLevelSegmentDisplay(false)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		offset = 0
		if not items or #items == 0 or (lastSearchTime == 0) then
			SolaFP_LFG_Search(true)
		else
			parseSearchResults()
		end
	end)

	segAllBtn:SetScript("OnClick", function()
		if SolaFP_Options and SolaFP_Options.lfgAllLevels == true then return end
		if SolaFP_Options then
			SolaFP_Options.lfgAllLevels = true
		end
		updateLevelSegmentDisplay(true)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
		offset = 0
		if not items or #items == 0 or (lastSearchTime == 0) then
			SolaFP_LFG_Search(true)
		else
			parseSearchResults()
		end
	end)

	segFitBtn:SetScript("OnEnter", function(self)
		local currentAll = (SolaFP_Options == nil) or (SolaFP_Options.lfgAllLevels ~= false)
		if currentAll then
			self:SetBackdrop(SolaFP_Backdrop)
			self:SetBackdropColor(1, 1, 1, 0.08)
			self:SetBackdropBorderColor(1, 1, 1, 0.25)
			fitText:SetTextColor(1, 1, 1)
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(SolaFP_L["Filter: Level-appropriate"] or "필터: 적정 레벨", 0.45, 0.98, 0.75)
		GameTooltip:AddLine(SolaFP_L["Show dungeons appropriate for your current level."] or "내 캐릭터 레벨에 맞는 던전만 필터링하여 표시합니다.", 0.941, 0.929, 0.910, true)
		if currentAll then
			GameTooltip:AddLine(SolaFP_L["Click: Switch to Level mode"] or "|cff66FF99클릭|r: 적정 레벨 모드로 전환", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		else
			GameTooltip:AddLine(SolaFP_L["(Currently Active)"] or "(현재 활성화됨)", 0.45, 0.85, 0.65)
		end
		GameTooltip:Show()
	end)

	segFitBtn:SetScript("OnLeave", function(self)
		local currentAll = (SolaFP_Options == nil) or (SolaFP_Options.lfgAllLevels ~= false)
		updateLevelSegmentDisplay(currentAll)
		GameTooltip:Hide()
	end)

	segAllBtn:SetScript("OnEnter", function(self)
		local currentAll = (SolaFP_Options == nil) or (SolaFP_Options.lfgAllLevels ~= false)
		if not currentAll then
			self:SetBackdrop(SolaFP_Backdrop)
			self:SetBackdropColor(1, 1, 1, 0.08)
			self:SetBackdropBorderColor(1, 1, 1, 0.25)
			allText:SetTextColor(1, 1, 1)
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(SolaFP_L["Filter: All Levels"] or "필터: 모든 레벨", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		GameTooltip:AddLine(SolaFP_L["Show all dungeon listings regardless of level."] or "모든 레벨 대의 던전 및 파티 목록을 표시합니다.", 0.941, 0.929, 0.910, true)
		if not currentAll then
			GameTooltip:AddLine(SolaFP_L["Click: Switch to All Levels mode"] or "|cff66FF99클릭|r: 모든 레벨 모드로 전환", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		else
			GameTooltip:AddLine(SolaFP_L["(Currently Active)"] or "(현재 활성화됨)", SolaC.goldMuted[1], SolaC.goldMuted[2], SolaC.goldMuted[3])
		end
		GameTooltip:Show()
	end)

	segAllBtn:SetScript("OnLeave", function(self)
		local currentAll = (SolaFP_Options == nil) or (SolaFP_Options.lfgAllLevels ~= false)
		updateLevelSegmentDisplay(currentAll)
		GameTooltip:Hide()
	end)

	-- Post party button, unsecure to avoid addon action blocked
	local registerBtn = CreateFrame("Button", "SolaFP_LFG_RegisterBtn", panel, "BackdropTemplate")
	registerBtn:SetSize(isEnLocale and 96 or 74, 24)
	registerBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -42)
	SolaFP_StyleModernButton(registerBtn, "gold", SolaFP_L["List Group"] or "파티 등록")
	registerBtn:SetBackdropColor(0.29, 0.205, 0.104, 1)
	registerBtn:SetBackdropBorderColor(0.65, 0.50, 0.29, 0.78)
	local registerFs = registerBtn:GetFontString()
	if registerFs then
		registerFs:SetTextColor(1.0, 0.95, 0.82)
	end

	registerBtn:SetScript("OnClick", function()
		SolaFP_LFG_OpenBlizzardRegister()
	end)

	registerBtn:SetScript("OnEnter", function(self)
		self:SetBackdropColor(0.37, 0.27, 0.14, 1)
		self:SetBackdropBorderColor(0.83, 0.68, 0.40, 0.92)
		if registerFs then registerFs:SetTextColor(1, 1, 1) end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(SolaFP_L["Blizzard Group Finder"] or "블리자드 파티 등록", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		GameTooltip:AddLine(SolaFP_L["Open or close the default Blizzard LFG window (I key)."] or "블리자드 기본 파티찾기(I키) 창을 열거나 닫습니다.", 0.941, 0.929, 0.910, true)
		GameTooltip:AddLine(SolaFP_L["Click: Toggle window"] or "|cff66FF99클릭|r: 열기 / 닫기 (토글)", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		GameTooltip:Show()
	end)
	registerBtn:SetScript("OnLeave", function(self)
		self:SetBackdropColor(0.29, 0.205, 0.104, 1)
		self:SetBackdropBorderColor(0.65, 0.50, 0.29, 0.78)
		if registerFs then registerFs:SetTextColor(1.0, 0.95, 0.82) end
		GameTooltip:Hide()
	end)

	-- Detailed Filter toggle button (placed directly below registerBtn on the 2nd row)
	local filterToggleBtn = CreateFrame("Button", "SolaFP_LFG_FilterToggleBtn", panel, "BackdropTemplate")
	filterToggleBtn:SetSize(isEnLocale and 86 or 74, 22)
	filterToggleBtn:SetPoint("TOPRIGHT", registerBtn, "BOTTOMRIGHT", 0, -6)
	filterToggleBtn:EnableMouse(true)
	filterToggleBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	SolaFP_StyleModernButton(filterToggleBtn, "dark", SolaFP_L["Filters ▶"] or "필터 ▶")
	local filterFs = filterToggleBtn:GetFontString()
	if filterFs then
		filterFs:SetWordWrap(false)
	end
	SolaFP_LFG_FilterToggleBtn = filterToggleBtn

	filterToggleBtn:SetScript("OnClick", function()
		if not SolaFP_LFG_FilterDrawer then
			SolaFP_LFG_CreateFilterDrawer(panel)
		end
		if not SolaFP_LFG_FilterDrawer then return end
		if SolaFP_LFG_FilterDrawer:IsShown() then
			SolaFP_LFG_FilterDrawer:Hide()
			if SolaFP_Options then SolaFP_Options.lfgFilterDrawerOpen = false end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)
		else
			SolaFP_LFG_AnchorDrawer()
			SolaFP_LFG_FilterDrawer:Show()
			SolaFP_LFG_UpdateDrawerVisuals()
			if SolaFP_Options then SolaFP_Options.lfgFilterDrawerOpen = true end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
		end
		SolaFP_LFG_UpdateFilterButton()
	end)

	filterToggleBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(SolaFP_L["Detailed Filters"] or "상세 필터", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		GameTooltip:AddLine(SolaFP_L["Configure role vacancies, seeker roles, levels, and classes."] or "비어있는 역할/구성, 플레이어 역할/레벨/직업 필터를 설정합니다.", 0.941, 0.929, 0.910, true)
		local count = SolaFP_LFG_CountActiveFilters()
		if count > 0 then
			GameTooltip:AddLine(string.format(SolaFP_L["Active filters: %d"] or "|cff66FF99현재 활성화된 필터: %d개|r", count), 0.45, 0.98, 0.75)
		end
		GameTooltip:AddLine(SolaFP_L["Click: Toggle filter panel"] or "|cff66FF99클릭|r: 필터 패널 열기/닫기", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		GameTooltip:Show()
	end)
	filterToggleBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Clear Excluded Dungeons button (Row 2, directly below levelSegFrame)
	local clearExcludedBtn = CreateFrame("Button", "SolaFP_LFG_ClearExcludedBtn", panel, "BackdropTemplate")
	clearExcludedBtn:SetSize(isEnLocale and 102 or 84, 22)
	clearExcludedBtn:SetPoint("RIGHT", filterToggleBtn, "LEFT", -6, 0)
	clearExcludedBtn:EnableMouse(true)
	clearExcludedBtn:RegisterForClicks("LeftButtonUp")
	SolaFP_StyleModernButton(clearExcludedBtn, "dark", SolaFP_L["Clear Excluded"] or "초기화")
	local clearFs = clearExcludedBtn:GetFontString()
	if clearFs then
		clearFs:SetWordWrap(false)
	end

	clearExcludedBtn:SetScript("OnClick", function()
		SolaFP_LFG_ClearExcludedActivities()
	end)

	clearExcludedBtn:SetScript("OnEnter", function(self)
		local exCount = getExcludedActivitiesCount()
		if exCount > 0 then
			self:SetBackdropColor(0.32, 0.14, 0.14, 0.98)
			self:SetBackdropBorderColor(1.0, 0.55, 0.55, 1.0)
		else
			self:SetBackdropColor(0.18, 0.16, 0.15, 0.95)
			self:SetBackdropBorderColor(1, 1, 1, 0.70)
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(SolaFP_L["Clear Exclusions"] or "제외 초기화", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		GameTooltip:AddLine(SolaFP_L["Restore all dungeons excluded from the list via Ctrl+Left-Click."] or "Ctrl+좌클릭으로 목록에서 제외한 던전을 모두 복원합니다.", 0.941, 0.929, 0.910, true)
		if exCount > 0 then
			GameTooltip:AddLine(string.format(SolaFP_L["Currently excluded: %d"] or "|cffFF6666현재 제외된 던전: %d개|r", exCount), 1.0, 0.60, 0.60)
			GameTooltip:AddLine(SolaFP_L["Click: Clear exclusions"] or "|cff66FF99클릭|r: 제외 목록 초기화", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		else
			GameTooltip:AddLine(SolaFP_L["No dungeons currently excluded."] or "현재 제외된 던전이 없습니다.", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
		end
		GameTooltip:Show()
	end)

	clearExcludedBtn:SetScript("OnLeave", function()
		SolaFP_LFG_UpdateClearExcludedButton()
		GameTooltip:Hide()
	end)

	-- Keep text search beside the filter actions. Pressing Escape in the box
	-- clears the query without closing the recruitment window.
	local queryBox = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
	queryBox:SetPoint("LEFT", panel, "TOPLEFT", 12, -81)
	queryBox:SetPoint("RIGHT", clearExcludedBtn, "LEFT", -6, 0)
	queryBox:SetHeight(22)
	queryBox:SetAutoFocus(false)
	SolaFP_StyleModernEditBox(queryBox, "teal")
	queryBox:SetFontObject("GameFontHighlightSmall")
	queryBox:SetTextInsets(8, 24, 0, 0)
	-- The clear action is available without requiring a keyboard shortcut.
	local clearQuery = CreateFrame("Button", nil, queryBox)
	clearQuery:SetSize(20, 20)
	clearQuery:SetPoint("RIGHT", -2, 0)
	clearQuery:SetNormalFontObject("GameFontHighlightSmall")
	clearQuery:SetText("×")
	clearQuery:SetScript("OnClick", function()
		queryBox:SetText("")
		queryBox:ClearFocus()
	end)
	clearQuery:Hide()
	local hint = queryBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("LEFT", 8, 0)
	hint:SetPoint("RIGHT", -6, 0)
	hint:SetJustifyH("LEFT")
	hint:SetTextColor(unpack(SolaC.fgDim))
	hint:SetText(isEnLocale and "Dungeon, player, or note" or "던전·이름·메모 검색")
	queryBox:SetScript("OnTextChanged", function(self)
		local value = self:GetText() or ""
		hint:SetShown(value == "")
		clearQuery:SetShown(value ~= "")
		searchText = value:match("^%s*(.-)%s*$"):lower()
		offset = 0
		renderList()
	end)
	queryBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	queryBox:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)

	-- Keep the response or empty-state message in the list area as well.
	local empty = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -197)
	empty:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -197)
	empty:SetJustifyH("CENTER")
	empty:SetTextColor(unpack(SolaC.fgDim))
	empty:Hide()
	panel.emptyText = empty

	-- Text tabs act as views of one result set, so a click never sends a
	-- new server request. The active underline works in both locales.
	local tabs = {}
	local tabDefinitions = {
		{ id = "all", label = isEnLocale and "All" or "모두", width = 70 },
		{ id = "party", label = isEnLocale and "Groups" or "파티 모집", width = 102 },
		{ id = "solo", label = isEnLocale and "Players" or "파티 찾는 중", width = 114 },
	}
	local tabLeft = 12
	for _, definition in ipairs(tabDefinitions) do
		local id = definition.id
		local tab = CreateFrame("Button", nil, panel)
		tab:SetSize(definition.width, 21)
		tab:SetPoint("TOPLEFT", panel, "TOPLEFT", tabLeft, -99)
		tabLeft = tabLeft + definition.width + 5
		local label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("CENTER", 0, 1)
		local underline = tab:CreateTexture(nil, "ARTWORK")
		underline:SetPoint("BOTTOMLEFT", 3, 0)
		underline:SetPoint("BOTTOMRIGHT", -3, 0)
		underline:SetHeight(2)
		underline:SetColorTexture(unpack(SolaC.gold))
		local hover = tab:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints()
		hover:SetColorTexture(1, 0.85, 0.55, 0.08)
		tabs[id] = { label = label, underline = underline, name = definition.label }
		tab:SetScript("OnClick", function()
			if listingView == id then return end
			listingView = id
			offset = 0
			selectedID = nil
			renderList()
		end)
	end
	function panel:UpdateListingTabs(counts)
		for id, tab in pairs(tabs) do
			local active = id == listingView
			tab.label:SetText(string.format("%s  %d", tab.name, counts[id] or 0))
			tab.label:SetTextColor(unpack(active and SolaC.goldBeige or SolaC.fgDim))
			tab.underline:SetShown(active)
		end
	end
	panel:UpdateListingTabs({})

	local resetView = CreateFrame("Button", nil, panel, "BackdropTemplate")
	resetView:SetSize(isEnLocale and 110 or 90, 22)
	resetView:SetPoint("TOP", empty, "BOTTOM", 0, -12)
	SolaFP_StyleModernButton(resetView, "dark", isEnLocale and "Show all results" or "전체 결과 보기")
	resetView:SetScript("OnClick", function()
		listingView = "all"
		queryBox:SetText("")
		queryBox:ClearFocus()
		offset = 0
		renderList()
	end)
	resetView:Hide()
	panel.resetView = resetView

	-- Status and sorting occupy a separate line above the results.
	statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusText:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -133)
	statusText:SetWordWrap(false)
	statusText:SetJustifyH("LEFT")
	SolaFP_LFG_UpdateStatusText(SolaFP_L["Initializing LFG (C_LFGList)..."] or "기본 파티 탐색기(C_LFGList)를 준비 중입니다.")
	statusText:SetTextColor(SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])

	-- Sort button (Row 2, vertically centered at y = -81)
	if not levelSortBtn then
		local sortBtn = CreateFrame("Button", "SolaFP_LFG_LevelSortBtn", panel, "BackdropTemplate")
		sortBtn:SetSize(isEnLocale and 72 or 62, 18)
		sortBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -126)
		statusText:SetPoint("RIGHT", sortBtn, "LEFT", -8, 0)
		sortBtn:EnableMouse(true)
		if SolaFP_Options and SolaFP_Options.lfgLevelSortAsc ~= nil then
			dungeonLevelSortAsc = SolaFP_Options.lfgLevelSortAsc
		end
		local sortLabel = dungeonLevelSortAsc and (SolaFP_L["Level ▲"] or "레벨 ▲") or (SolaFP_L["Level ▼"] or "레벨 ▼")
		SolaFP_StyleModernButton(sortBtn, "dark", sortLabel)

		sortBtn:SetScript("OnClick", function(self)
			dungeonLevelSortAsc = not dungeonLevelSortAsc
			if SolaFP_Options then
				SolaFP_Options.lfgLevelSortAsc = dungeonLevelSortAsc
			end
			self:SetText(dungeonLevelSortAsc and (SolaFP_L["Level ▲"] or "레벨 ▲") or (SolaFP_L["Level ▼"] or "레벨 ▼"))
			parseSearchResults()
		end)

		sortBtn:SetScript("OnEnter", function(self)
			self:SetBackdropBorderColor(1, 1, 1, 0.95)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(SolaFP_L["Dungeon Level Sorting"] or "던전 레벨 정렬", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
			GameTooltip:AddLine(SolaFP_L["Sort dungeon listings in ascending (▲) or descending (▼) level order."] or "던전 목록을 레벨 오름차순(▲) / 내림차순(▼)으로 정렬합니다.", 0.941, 0.929, 0.910, true)
			local stateStr = dungeonLevelSortAsc and (SolaFP_L["Current: Ascending (Low to High)"] or "|cff66FF99오름차순 (저레벨 우선)|r") or (SolaFP_L["Current: Descending (High to Low)"] or "|cffFFCC00내림차순 (고레벨 우선)|r")
			GameTooltip:AddLine(stateStr, SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
			GameTooltip:Show()
		end)

		sortBtn:SetScript("OnLeave", function(self)
			self:SetBackdropBorderColor(SolaC.gold[1] * 0.75, SolaC.gold[2] * 0.75, SolaC.gold[3] * 0.75, 0.75)
			GameTooltip:Hide()
		end)

		sortBtn:Hide()
		levelSortBtn = sortBtn
	end

	-- Restore the interest list as a preset. Start with all dungeons so
	-- previously selected activities cannot hide fresh listings on login.
	if SolaFP_Options and SolaFP_Options.lfgSelectedActivities then
		for name, isSel in pairs(SolaFP_Options.lfgSelectedActivities) do
			if isSel then selectedActivities[name] = true end
		end
	end
	if SolaFP_Options and SolaFP_Options.lfgExcludedActivities then
		for name, isEx in pairs(SolaFP_Options.lfgExcludedActivities) do
			if isEx then excludedActivities[name] = true end
		end
	end
	SolaFP_LFG_UpdateDungeonButtonDisplay()
	SolaFP_LFG_UpdateClearExcludedButton()

	-- Status bar divider
	local listSep = panel:CreateTexture(nil, "ARTWORK", nil, 6)
	listSep:SetPoint("TOPLEFT", 12, -149)
	listSep:SetPoint("TOPRIGHT", -12, -149)
	listSep:SetHeight(1)
	listSep:SetColorTexture(unpack(SolaC.glassLine))

	-- Scroll bar
	local scrollSlider = CreateFrame("Slider", nil, panel)
	scrollSlider:SetPoint("TOPRIGHT", -4, -resultsTop)
	scrollSlider:SetPoint("BOTTOMRIGHT", -3, 8)
	scrollSlider:SetWidth(8)
	scrollSlider:SetOrientation("VERTICAL")
	scrollSlider:SetValueStep(1)
	if scrollSlider.SetObeyStepOnDrag then scrollSlider:SetObeyStepOnDrag(true) end
	scrollSlider:EnableMouse(true)

	local sTrack = scrollSlider:CreateTexture(nil, "BACKGROUND")
	sTrack:SetAllPoints()
	sTrack:SetColorTexture(SolaC.bgInput[1], SolaC.bgInput[2], SolaC.bgInput[3], 0.8)

	local sThumb = scrollSlider:CreateTexture(nil, "ARTWORK")
	sThumb:SetSize(6, 24)
	sThumb:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.6)
	scrollSlider:SetThumbTexture(sThumb)

	local syncing = false
	scrollSlider:SetScript("OnValueChanged", function(_, val)
		if not syncing then
			offset = math.floor(val + 0.5)
			renderList()
		end
	end)
	function scrollSlider:Sync(curOffset, limit)
		syncing = true
		self:SetMinMaxValues(0, math.max(1, limit))
		self:SetValue(limit > 0 and curOffset or 0)
		if limit > 0 then
			self:Enable()
			sThumb:SetAlpha(1)
		else
			self:Disable()
			sThumb:SetAlpha(0.2)
		end
		syncing = false
	end
	scrollBarSlider = scrollSlider

	-- Mouse wheel scrolling
	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", function(_, delta)
		offset = offset - delta * 3
		renderList()
	end)

	-- Drag to move window from empty space, or right click to close
	panel:SetScript("OnMouseDown", function(_, button)
		if DropDownList1 and DropDownList1:IsShown() then
			CloseDropDownMenus()
		end
		if actionMenu and actionMenu:IsShown() then
			actionMenu:Hide()
		end
		if activitiesMenu and activitiesMenu:IsShown() then
			activitiesMenu:Hide()
		end
		if button == "LeftButton" then
			OnLFGDragStart()
		elseif button == "RightButton" then
			if SolaFP_CloseOnRightClick then
				SolaFP_CloseOnRightClick()
			end
		end
	end)
	panel:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			OnLFGDragStop()
		end
	end)

	local function SolaFP_BumpFontSize(fs, delta)
		if not fs then return end
		local font, size, flags = fs:GetFont()
		if font and size then
			fs:SetFont(font, math.floor(size + (delta or 1) + 0.5), flags)
		end
	end

	-- Reusable row pool
	for i = 1, 35 do
		local row = CreateFrame("Button", nil, panel, "BackdropTemplate")
		row:SetSize(372, 34)
		row:SetPoint("TOPLEFT", 8, -resultsTop - (i - 1) * 36)
		row:SetBackdrop(SolaFP_Backdrop)
		row:SetBackdropColor(0.08, 0.07, 0.07, 0.85)
		row:SetBackdropBorderColor(0, 0, 0, 0.5)
		row:EnableMouse(true)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

		-- Hover highlight
		local hl = row:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.08)

		-- Dungeon icon
		local dIcon = row:CreateTexture(nil, "ARTWORK")
		dIcon:SetSize(16, 16)
		dIcon:SetPoint("LEFT", 6, 0)
		dIcon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
		dIcon:Hide()
		row.dungeonIcon = dIcon

		-- Expand/collapse icon
		local exp = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		SolaFP_BumpFontSize(exp, 1)
		exp:SetPoint("LEFT", dIcon, "LEFT", -1, 0)
		exp:SetText("[+]")
		exp:Hide()
		row.expandIcon = exp

		-- Class icon
		local cIcon = row:CreateTexture(nil, "ARTWORK")
		cIcon:SetSize(17, 17)
		cIcon:SetPoint("LEFT", 4, 0)
		cIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
		cIcon:Hide()
		row.classIcon = cIcon

		-- Title text
		local tFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		SolaFP_BumpFontSize(tFs, 1)
		tFs:SetPoint("LEFT", 6, 0)
		tFs:SetJustifyH("LEFT")
		tFs:SetWordWrap(false)
		row.title = tFs

		-- Listing count
		local dcFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		SolaFP_BumpFontSize(dcFs, 1)
		dcFs:SetPoint("RIGHT", -6, 0)
		dcFs:SetJustifyH("RIGHT")
		row.dungeonCounts = dcFs

		-- Listing title or leader
		local snFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		SolaFP_BumpFontSize(snFs, 1)
		snFs:SetPoint("TOPLEFT", 6, -2)
		snFs:SetJustifyH("LEFT")
		snFs:SetWordWrap(false)
		row.soloName = snFs

		-- Member info
		local infFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		SolaFP_BumpFontSize(infFs, 1)
		infFs:SetPoint("BOTTOMLEFT", 6, 2)
		infFs:SetJustifyH("LEFT")
		infFs:SetWordWrap(false)
		row.info = infFs

		-- Solo aligned columns: level & comment
		local lvlFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		SolaFP_BumpFontSize(lvlFs, 1)
		lvlFs:SetJustifyH("LEFT")
		lvlFs:SetWordWrap(false)
		row.soloLevel = lvlFs

		local cmtFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		SolaFP_BumpFontSize(cmtFs, 1)
		cmtFs:SetJustifyH("LEFT")
		cmtFs:SetWordWrap(false)
		row.soloComment = cmtFs

		-- Role icons
		local rFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		SolaFP_BumpFontSize(rFs, 1)
		rFs:SetPoint("RIGHT", -6, 0)
		rFs:SetJustifyH("RIGHT")
		row.roles = rFs

		-- Open the chat composer with the recipient filled in. Sending a
		-- preset remains a separate action in the existing context menu.
		local whisper = CreateFrame("Button", nil, row, "BackdropTemplate")
		whisper:SetSize(54, 19)
		whisper:SetPoint("RIGHT", -5, 0)
		SolaFP_StyleModernButton(whisper, "dark", isEnLocale and "Whisper" or "귓속말")
		whisper:SetScript("OnClick", function()
			if row.whisperTarget and ChatFrame_OpenChat then
				ChatFrame_OpenChat("/w " .. row.whisperTarget .. " ")
			end
		end)
		whisper:Hide()
		row.whisper = whisper

		-- Row click handlers
		row:SetScript("OnClick", function(self, button)
			if DropDownList1 and DropDownList1:IsShown() then
				CloseDropDownMenus()
			end
			if activitiesMenu and activitiesMenu:IsShown() then
				activitiesMenu:Hide()
			end
			local item = self.item
			if not item then
				if button == "RightButton" and SolaFP_CloseOnRightClick then
					SolaFP_CloseOnRightClick()
				end
				return
			end

			-- Toggle group expansion or exclude dungeon (FindParty style)
			if item.dungeon then
				if button == "LeftButton" then
					if IsControlKeyDown() then
						SolaFP_LFG_ExcludeDungeon(item.group)
					elseif searchText == "" then
						expandedGroups[item.group] = not isGroupExpanded(item.group)
						renderList()
					end
				end
				return
			end

			-- Ignore section header clicks
			if item.heading then
				if button == "RightButton" and SolaFP_CloseOnRightClick then
					SolaFP_CloseOnRightClick()
				end
				return
			end

			local leader = item.leader
			if not leader or leader == "" or leader == "이름 미표시" or leader == "Anonymous" or leader == (SolaFP_L["Anonymous"] or "이름 미표시") then return end

			if button == "LeftButton" then
				if IsControlKeyDown() then
					-- Ctrl + click: exclude dungeon
					if item.group then
						SolaFP_LFG_ExcludeDungeon(item.group)
					end
					return
				elseif IsAltKeyDown() then
					-- Alt + click: whisper leader
					if leader ~= UnitName("player") then
						doWhisper(leader)
						PlaySound(SOUNDKIT.IG_CHAT_EMOTE_BUTTON or 856)
					end
				elseif IsShiftKeyDown() then
					-- Shift + click: who query
					doSendWho(leader)
				else
					if actionMenu and actionMenu:IsShown() then
						actionMenu:Hide()
					end
					-- Left click: select row
					selectedID = (selectedID == item.id) and nil or item.id
					renderList()
				end
			elseif button == "RightButton" then
				if IsAltKeyDown() then
					-- Alt + right click: open whisper prompt
					if ChatFrame_OpenChat then
						ChatFrame_OpenChat("/w " .. leader .. " ")
					end
				else
					-- Right click: open menu (toggle)
					if actionMenu then
						if actionMenu:IsShown() and actionMenu.target == leader then
							actionMenu:Hide()
							return
						end
						actionMenu.target = leader
						local cCol = RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.classToken] or { r = 1, g = 1, b = 1 }
						actionMenu.title:SetText(leader)
						actionMenu.title:SetTextColor(cCol.r, cCol.g, cCol.b)
						actionMenu:ClearAllPoints()
						actionMenu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 10, -2)
						actionMenu:Show()
					end
				end
			end
		end)

		-- Tooltip details
		row:SetScript("OnEnter", function(self)
			local item = self.item
			if not item or item.heading then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:ClearLines()

			if item.dungeon then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:ClearLines()
				local lvlStr = item.level and ("  |cffB9A584Lv. " .. item.level .. "|r") or ""
				GameTooltip:AddLine(item.heading .. lvlStr, SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
				local countFmt = SolaFP_L["Groups: %d  ·  Seekers: %d"] or "등록 파티: %d팀 · 대기 개인: %d명"; local countDesc = string.format(countFmt, item.partyCount or 0, item.soloCount or 0)
				GameTooltip:AddLine(countDesc, 0.85, 0.85, 0.85)
				GameTooltip:AddLine(" ", 1, 1, 1)

				local isInterested = (selectedActivities and item.group and selectedActivities[item.group]) and true or false
				if isInterested then
					GameTooltip:AddLine(SolaFP_L["Status: Interested Dungeon"] or "|cff5ABFBA★ 현재 관심 던전으로 등록됨|r", 0.35, 0.75, 0.69)
				end

				GameTooltip:AddLine(SolaFP_L["Left-Click: Collapse / Expand"] or "|cffD4A745좌클릭|r: 파티 목록 접기/펼치기", 0.9, 0.9, 0.9)
				GameTooltip:AddLine(SolaFP_L["Ctrl + Left-Click: Exclude this dungeon"] or "|cffFF6666[Ctrl + 좌클릭]|r: 관심 던전 제외", 0.9, 0.9, 0.9)
				GameTooltip:Show()
				return
			end

			local note = SolaFP_LFG_GetItemNote(item)
			if note and note ~= "" then
				item.comment = note
			end


			if item.solo then
				local cCol = RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.classToken] or { r = 1, g = 1, b = 1 }
				GameTooltip:AddLine(item.leader, cCol.r, cCol.g, cCol.b)
				local details = (item.className or "") .. (item.level and ("  Lv." .. item.level) or "")
				GameTooltip:AddLine(details, 0.8, 0.8, 0.8)

				if item.area and item.area ~= "" then
					GameTooltip:AddLine(string.format(SolaFP_L["Current Zone: %s"] or "현재 위치: |cffffffff%s|r", item.area), 0.55, 0.80, 1.0)
				end

				if note and note ~= "" then
					GameTooltip:AddLine(formatNote(note), 1, 0.95, 0.75, true)
				end

				if item.group and item.group ~= "" then
					GameTooltip:AddLine(string.format(SolaFP_L["Target Activity: %s"] or "희망 던전: %s", item.group), SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
				end
				if item.icons and item.icons ~= "" then
					GameTooltip:AddLine(string.format(SolaFP_L["Target Role: %s"] or "희망 역할: %s", item.icons), 0.9, 0.9, 0.9)
				end
			else
				GameTooltip:AddLine(item.title or item.group, SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
				if item.activity and item.activity ~= "" and item.activity ~= item.title then
					GameTooltip:AddLine(item.activity, SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
				end

				if item.area and item.area ~= "" then
					GameTooltip:AddLine(string.format(SolaFP_L["Leader Zone: %s"] or "파티장 위치: |cffffffff%s|r", item.area), 0.55, 0.80, 1.0)
				end

				if note and note ~= "" then
					GameTooltip:AddLine(formatNote(note), 1, 0.95, 0.75, true)
				end

				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(string.format(SolaFP_L["Party Members (%d):"] or "파티원 목록 (%d명):", item.count or 1), SolaC.goldBeige[1], SolaC.goldBeige[2], SolaC.goldBeige[3])

				local shownMembers = 0
				for idx = 1, item.count do
					local mem = api("GetSearchResultPlayerInfo", item.id, idx)
					if type(mem) == "table" then
						local mName = plain(mem.name)
						if mName == "" then mName = SolaFP_L["Unnamed"] or "이름 미표시" end
						local mClass = plain(mem.className)
						local mLvl = tonumber(safe(mem.level))
						local mToken = safe(mem.classFilename)
						local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[mToken] or { r = 1, g = 1, b = 1 }
						local roleIcon = formatSingleRole(safe(mem.assignedRole))
						local memArea = plain(mem.areaName)
						local mArea = (memArea ~= "") and ("  |cff82C5FF[" .. memArea .. "]|r") or ""
						local line = string.format("%s  %s  %s  %s%s", mName, (mLvl and ("Lv." .. mLvl) or ""), mClass, roleIcon, mArea)
						GameTooltip:AddLine(line, col.r, col.g, col.b)
						shownMembers = shownMembers + 1
					end
				end
				if shownMembers == 0 then
					local leadArea = (item.area and item.area ~= "") and (" (" .. item.area .. ")") or ""
					GameTooltip:AddLine(string.format(SolaFP_L["Leader: %s%s"] or "파티장: %s%s", item.leader or (SolaFP_L["Unknown"] or "알 수 없음"), leadArea), 0.9, 0.9, 0.9)
				end
			end

			-- Voice chat info
			local voice = item.voiceChat
			if (not voice or voice == "") and item.id and C_LFGList and C_LFGList.GetSearchResultInfo then
				local ok, res = pcall(C_LFGList.GetSearchResultInfo, item.id)
				if ok and type(res) == "table" then
					local v = plain(res.voiceChat)
					if v ~= "" then
						voice = v
					end
				end
			end
			if voice and voice ~= "" then
				GameTooltip:AddLine(string.format(SolaFP_L["Voice Chat: %s"] or "음성 대화: |cffffffff%s|r", voice), 0.6, 0.85, 1, true)
			end

			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(SolaFP_L["Alt+Left-Click: Whisper  ·  Ctrl+Left-Click: Exclude  ·  Alt+Right-Click: Chat"] or "|cffD4A745Alt+좌클릭|r: 귓속말  |cff8A8580·|r  |cffFF6666[Ctrl+좌클릭]|r: 관심 던전 제외  |cff8A8580·|r  |cffD4A745Alt+우클릭|r: 대화창", 0.6, 0.6, 0.6)
			GameTooltip:AddLine(SolaFP_L["Shift+Left-Click: /who  ·  Right-Click: Context Menu"] or "|cffD4A745Shift+좌클릭|r: /who 조회  |cff8A8580·|r  |cffD4A745우클릭|r: 팝업 메뉴", 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)

		rows[i] = row
	end

	-- Create menus
	actionMenu = createActionMenu(panel)
	activitiesMenu = createActivitiesMenu(panel)

	-- Register LFG events
	if C_LFGList then
		panel:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
		panel:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
		panel:RegisterEvent("LFG_LIST_SEARCH_FAILED")
		panel:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
		panel:SetScript("OnEvent", function(_, event)
			if event == "LFG_LIST_AVAILABILITY_UPDATE" then
				if isPanelVisible() and not pending then
					parseSearchResults()
				end
			elseif event == "LFG_LIST_SEARCH_FAILED" then
				pending = false
				if statusText then SolaFP_LFG_UpdateStatusText(SolaFP_L["Search request failed. (Please try again shortly)"] or "검색에 실패했습니다. [새로고침]을 눌러주세요.") end
				if SolaFP_LFG_UpdateRefreshTimer then SolaFP_LFG_UpdateRefreshTimer() end
			elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" or event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
				pending = false
				parseSearchResults()
				if SolaFP_LFG_UpdateRefreshTimer then SolaFP_LFG_UpdateRefreshTimer() end
			end
		end)
	end

	panel:SetScript("OnHide", function()
		if panel.isMoving then
			panel.isMoving = nil
			panel:StopMovingOrSizing()
		end
		if activitiesMenu then activitiesMenu:Hide() end
		if actionMenu then actionMenu:Hide() end
		if SolaFP_WhPresetFrame and SolaFP_WhPresetFrame:IsShown() then SolaFP_WhPresetFrame:Hide() end
	end)

	-- Synchronize size with main frame
	panel:SetScript("OnSizeChanged", function(self, w, h)
		local curH = h or (self and self:GetHeight()) or 0
		if curH > 0 then
			local isStandalone = (SolaFP_Options and SolaFP_Options.lfgOnly)
			availableHeight = resultsHeight(curH, isStandalone)
			if self:IsShown() then
				renderList()
			end
		end
	end)

	function panel:Layout(height)
		local totalH = height or panel:GetHeight()
		local isStandalone = (SolaFP_Options and SolaFP_Options.lfgOnly)
		availableHeight = resultsHeight(totalH, isStandalone)
		renderList()
		if SolaFP_LFG_FilterDrawer and SolaFP_LFG_FilterDrawer:IsShown() and SolaFP_LFG_AnchorDrawer then
			SolaFP_LFG_AnchorDrawer()
		end
	end

	SolaFP_LFGPanel = panel
	panel.RefreshListingView = renderList

	-- Corner resize grip for SolaFP_LFGPanel (active in standalone mode)
	local lfgCornerGrip = CreateFrame("Button", "SolaFP_LFG_CornerResizeGrip", panel)
	lfgCornerGrip:SetSize(22, 22)
	lfgCornerGrip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
	lfgCornerGrip:EnableMouse(true)
	lfgCornerGrip:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
	lfgCornerGrip:SetFrameLevel(panel:GetFrameLevel() + 25)

	local lfgGripLines = {}
	for i = 1, 3 do
		local line = lfgCornerGrip:CreateTexture(nil, "OVERLAY")
		line:SetHeight(1)
		line:SetWidth(4 + i * 3)
		line:SetPoint("BOTTOMRIGHT", -2, 2 + (i - 1) * 4)
		line:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.5)
		lfgGripLines[i] = line
	end

	lfgCornerGrip:SetScript("OnEnter", function(self)
		for i = 1, #lfgGripLines do
			lfgGripLines[i]:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 1.0)
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(SolaFP_L["Drag: Resize window | Mouse wheel: Scroll list"] or SolaFP_TEXT_RESIZE_TIP or "드래그: 창 크기 조절 (너비/높이)")
		GameTooltip:Show()
	end)
	lfgCornerGrip:SetScript("OnLeave", function(self)
		for i = 1, #lfgGripLines do
			lfgGripLines[i]:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.5)
		end
		GameTooltip:Hide()
	end)

	local lfgResizeActive = false
	local lfgResizeStartX, lfgResizeStartY = 0, 0
	local lfgResizeStartW, lfgResizeStartH = 390, 560
	local lfgResizeWatcher = CreateFrame("Frame", "SolaFP_LFG_ResizeWatcher", UIParent)
	lfgResizeWatcher:Hide()

	local SolaFP_LFG_MIN_WIDTH = isEnLocale and 500 or 390
	local SolaFP_LFG_MAX_WIDTH = 850
	local SolaFP_LFG_MIN_HEIGHT = 350
	local SolaFP_LFG_MAX_HEIGHT = 900

	local function SolaFP_LFG_StartResize()
		if not (SolaFP_Options and SolaFP_Options.lfgOnly) then return end
		lfgResizeActive = true
		local cursorX, cursorY = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		lfgResizeStartX = cursorX / scale
		lfgResizeStartY = cursorY / scale
		lfgResizeStartW = panel:GetWidth() or 350
		lfgResizeStartH = panel:GetHeight() or 560

		local left, top = panel:GetLeft(), panel:GetTop()
		if left and top then
			panel:ClearAllPoints()
			panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		end
		lfgResizeWatcher:Show()
	end

	local function SolaFP_LFG_StopResize()
		if not lfgResizeActive then return end
		lfgResizeActive = false
		lfgResizeWatcher:Hide()

		if SolaFP_Position_Save then
			SolaFP_Position_Save.lfgPoint, _, SolaFP_Position_Save.lfgRelpoint, SolaFP_Position_Save.lfgX, SolaFP_Position_Save.lfgY = panel:GetPoint()
			SolaFP_Position_Save.lfgWidth = panel:GetWidth()
			SolaFP_Position_Save.lfgHeight = panel:GetHeight()
		end
		if SolaFP_Options then
			SolaFP_Options.lfgWidth = panel:GetWidth()
			SolaFP_Options.lfgHeight = panel:GetHeight()
		end
		if panel.Layout then
			panel:Layout()
		end
	end

	lfgCornerGrip:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			SolaFP_LFG_StartResize()
		elseif button == "RightButton" then
			if SolaFP_CloseOnRightClick then SolaFP_CloseOnRightClick() end
		end
	end)
	lfgCornerGrip:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			SolaFP_LFG_StopResize()
		end
	end)

	lfgResizeWatcher:SetScript("OnUpdate", function(self)
		if not lfgResizeActive then
			self:Hide()
			return
		end
		if not IsMouseButtonDown("LeftButton") then
			SolaFP_LFG_StopResize()
			return
		end

		local cursorX, cursorY = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		local currentX = cursorX / scale
		local currentY = cursorY / scale

		local deltaX = currentX - lfgResizeStartX
		local deltaY = lfgResizeStartY - currentY

		local newW = math.floor(lfgResizeStartW + deltaX + 0.5)
		local newH = math.floor(lfgResizeStartH + deltaY + 0.5)

		newW = math.max(SolaFP_LFG_MIN_WIDTH, math.min(SolaFP_LFG_MAX_WIDTH, newW))
		newH = math.max(SolaFP_LFG_MIN_HEIGHT, math.min(SolaFP_LFG_MAX_HEIGHT, newH))

		if panel:GetWidth() ~= newW or panel:GetHeight() ~= newH then
			panel:SetSize(newW, newH)
			if panel.Layout then
				panel:Layout(newH)
			end
		end
	end)
	if not (SolaFP_Options and SolaFP_Options.lfgOnly) then
		lfgCornerGrip:Hide()
	end

	-- Bottom Whisper Bar (active in standalone mode)
	local bottomBar = CreateFrame("Frame", "SolaFP_LFG_BottomBar", panel)
	bottomBar:SetHeight(32)
	bottomBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 0)
	bottomBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
	bottomBar:SetFrameLevel(panel:GetFrameLevel() + 5)

	local bottomSep = panel:CreateTexture("SolaFP_LFG_BottomSep", "BORDER")
	bottomSep:SetHeight(1)
	bottomSep:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 32)
	bottomSep:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 32)
	bottomSep:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.35)

	-- Whisper Label ("귓속말:")
	local whLabel = bottomBar:CreateFontString("SolaFP_LFG_WhLabel", "OVERLAY", "GameFontHighlightSmall")
	whLabel:SetPoint("LEFT", bottomBar, "LEFT", 10, 0)
	whLabel:SetText(SolaFP_L["Whisper Msg: "] or SolaFP_LABEL_WH or "귓속말:")
	whLabel:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])

	-- Whisper Send Button ("신청") - rightmost before resize grip
	local whSendBtn = CreateFrame("Button", "SolaFP_LFG_WhSendBtn", bottomBar, "BackdropTemplate")
	whSendBtn:SetSize(isEnLocale and 56 or 46, 22)
	whSendBtn:SetPoint("RIGHT", bottomBar, "RIGHT", -26, 0)
	whSendBtn:EnableMouse(true)
	SolaFP_StyleModernButton(whSendBtn, "primary", SolaFP_L["Apply"] or SolaFP_TEXT_APPLY or "신청")
	whSendBtn:SetScript("OnClick", function()
		doWhisperSelected()
	end)
	whSendBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(SolaFP_L["Apply via Whisper"] or "파티 신청 (귓속말)", 1, 0.85, 0.5)
		GameTooltip:AddLine(SolaFP_L["Send whisper to the party leader.\n(Shortcut: Alt + Click in list or press Enter in input)"] or "선택한 파티장에게 귓속말 문구를 전송합니다.\n(단축키: 목록에서 Alt + 클릭 또는 입력창 Enter)", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	whSendBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Whisper Add Button ("추가")
	local whAddBtn = CreateFrame("Button", "SolaFP_LFG_WhAddBtn", bottomBar, "BackdropTemplate")
	whAddBtn:SetSize(isEnLocale and 44 or 36, 22)
	whAddBtn:SetPoint("RIGHT", whSendBtn, "LEFT", -4, 0)
	whAddBtn:EnableMouse(true)
	SolaFP_StyleModernButton(whAddBtn, "default", SolaFP_L["Add"] or SolaFP_TEXT_ADD or "추가")
	whAddBtn:SetScript("OnClick", function()
		if SolaFP_AddCurrentWhPreset then SolaFP_AddCurrentWhPreset() end
	end)
	whAddBtn:SetScript("OnEnter", function(self)
		if SolaFP_Tooltip_WhAddBtn then
			SolaFP_Tooltip_WhAddBtn(self)
		end
	end)
	whAddBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Whisper Preset Dropdown Toggle Button ("v")
	local whPresetBtn = CreateFrame("Button", "SolaFP_LFG_WhPresetBtn", bottomBar, "BackdropTemplate")
	whPresetBtn:SetSize(22, 22)
	whPresetBtn:SetPoint("RIGHT", whAddBtn, "LEFT", -4, 0)
	whPresetBtn:EnableMouse(true)
	SolaFP_StyleModernButton(whPresetBtn, "gold", "v")
	whPresetBtn:SetScript("OnClick", function(self)
		if SolaFP_ToggleWhPresetMenu then SolaFP_ToggleWhPresetMenu(self) end
	end)
	whPresetBtn:SetScript("OnEnter", function(self)
		if SolaFP_Tooltip_WhPresetBtn then
			SolaFP_Tooltip_WhPresetBtn(self)
		end
	end)
	whPresetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Whisper Input EditBox
	local whEditBox = CreateFrame("EditBox", "SolaFP_LFG_WhText", bottomBar, "BackdropTemplate")
	whEditBox:SetHeight(22)
	whEditBox:SetPoint("LEFT", whLabel, "RIGHT", 6, 0)
	whEditBox:SetPoint("RIGHT", whPresetBtn, "LEFT", -5, 0)
	whEditBox:SetAutoFocus(false)
	SolaFP_StyleModernEditBox(whEditBox, "gold")

	whEditBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	whEditBox:SetScript("OnEnterPressed", function(self)
		doWhisperSelected()
		self:ClearFocus()
	end)
	whEditBox:SetScript("OnTextChanged", function(self)
		local txt = self:GetText() or ""
		if txt ~= SolaFP_UserDefinedWhMsg then
			SolaFP_UserDefinedWhMsg = txt
			if SolaFP_MenuFrameWhText and SolaFP_MenuFrameWhText:GetText() ~= txt then
				SolaFP_MenuFrameWhText:SetText(txt)
			end
			local lvl = UnitLevel("player")
			local cls = (SolaFP_GetPlayerClassName and SolaFP_GetPlayerClassName()) or UnitClass("player")
			local expectedAuto = (lvl and cls) and string.format(SolaFP_TEXT_AUTO_WHISPER_FORMAT or "%d %s 초대 부탁드립니다", lvl, cls) or ""
			if txt ~= expectedAuto then
				SolaFP_WhAutoLevel = false
			end
		end
	end)

	if SolaFP_UserDefinedWhMsg and SolaFP_UserDefinedWhMsg ~= "" then
		whEditBox:SetText(SolaFP_UserDefinedWhMsg)
	end

	if not (SolaFP_Options and SolaFP_Options.lfgOnly) then
		bottomBar:Hide()
		bottomSep:Hide()
	end

	-- LFG toggle button
	if SolaFP_ListFrame and not _G.SolaFP_ListFrameLFGBtn then
		local lfgBtn = CreateFrame("Button", "SolaFP_ListFrameLFGBtn", SolaFP_ListFrame, "BackdropTemplate")
		lfgBtn:SetSize(80, 36)
		lfgBtn:SetPoint("TOPRIGHT", SolaFP_ListFrame, "TOPRIGHT", -10, -41)
		lfgBtn:EnableMouse(true)
		SolaFP_StyleModernButton(lfgBtn, "dark", (SolaFP_L["LFG"] or "파티찾기") .. " ▶")

		lfgBtn:SetScript("OnClick", function()
			SolaFP_LFG_Toggle(nil, true)
		end)

		lfgBtn:SetScript("OnEnter", function(self)
			local isOpen = SolaFP_LFGPanel and SolaFP_LFGPanel:IsShown()
			if isOpen then
				self:SetBackdropBorderColor(1, 1, 1, 0.95)
				self:SetBackdropColor(0.12, 0.28, 0.24, 0.98)
			else
				self:SetBackdropBorderColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 1.0)
				self:SetBackdropColor(0.20, 0.18, 0.14, 0.95)
			end
			local fs = self:GetFontString()
			if fs then fs:SetTextColor(1, 1, 1) end

			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(SolaFP_L["Blizzard Group Finder"] or "기본 파티 탐색기 (LFG)", SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
			GameTooltip:AddLine(SolaFP_L["Toggle the Blizzard LFGList panel."] or "와우 기본 파티찾기(C_LFGList) 패널을 우측에 접거나 펼칩니다.", 0.941, 0.929, 0.910, true)
			GameTooltip:AddLine(SolaFP_L["Click: Toggle window"] or "클릭 시 파티찾기 패널을 토글합니다.", SolaC.fgDim[1], SolaC.fgDim[2], SolaC.fgDim[3])
			GameTooltip:Show()
		end)

		lfgBtn:SetScript("OnLeave", function(self)
			SolaFP_LFG_UpdateToggleButton()
			GameTooltip:Hide()
		end)

		_G.SolaFP_ListFrameLFGBtn = lfgBtn
	end

	-- Initialize detailed filter drawer
	SolaFP_LFG_CreateFilterDrawer(panel)
	SolaFP_LFG_UpdateFilterButton()

	-- Automatically close filter drawer when main LFG panel hides, and restore it on show
	panel:HookScript("OnHide", function()
		if SolaFP_LFG_FilterDrawer then
			SolaFP_LFG_FilterDrawer:Hide()
		end
		if SolaFP_LFG_UpdateFilterButton then
			SolaFP_LFG_UpdateFilterButton()
		end
		stopRefreshTicker()
	end)

	panel:HookScript("OnShow", function()
		if SolaFP_Options and SolaFP_Options.lfgFilterDrawerOpen then
			if not SolaFP_LFG_FilterDrawer then
				SolaFP_LFG_CreateFilterDrawer(panel)
			end
			if SolaFP_LFG_FilterDrawer then
				if SolaFP_LFG_AnchorDrawer then SolaFP_LFG_AnchorDrawer() end
				SolaFP_LFG_FilterDrawer:Show()
				if SolaFP_LFG_UpdateDrawerVisuals then SolaFP_LFG_UpdateDrawerVisuals() end
			end
		end
		if SolaFP_LFG_UpdateFilterButton then
			SolaFP_LFG_UpdateFilterButton()
		end
		if isPanelVisible() and not pending then
			SolaFP_LFG_Search(false)
		end
		startRefreshTicker()
	end)

	-- Restore saved filter settings
	if SolaFP_Options and SolaFP_Options.lfgOnly then
		panel:Hide()
	else
		local shouldOpen = (SolaFP_Options and SolaFP_Options.lfgPanelOpen == true)
		SolaFP_LFG_Toggle(shouldOpen, false)
		SolaFP_LFG_UpdateToggleButton()
	end
	if SolaFP_UpdateKeyBindingButton then
		SolaFP_UpdateKeyBindingButton()
	end
end

-------------------------------------------------
-- Update toolbar button appearance
-------------------------------------------------
function SolaFP_LFG_UpdateToggleButton()
	local btn = _G.SolaFP_ListFrameLFGBtn
	if not btn then return end
	local isOpen = SolaFP_LFGPanel and SolaFP_LFGPanel:IsShown()
	local fs = btn:GetFontString()
	if isOpen then
		btn:SetText((SolaFP_L["LFG"] or "파티찾기") .. " ◀")
		btn._r, btn._g, btn._b = 0.08, 0.18, 0.16
		btn:SetBackdropColor(0.08, 0.18, 0.16, 0.95)
		btn:SetBackdropBorderColor(SolaC.teal[1], SolaC.teal[2], SolaC.teal[3], 0.85)
		if fs then
			fs:SetTextColor(SolaC.teal[1], SolaC.teal[2], SolaC.teal[3])
		end
	else
		btn:SetText((SolaFP_L["LFG"] or "파티찾기") .. " ▶")
		btn._r, btn._g, btn._b = 0.12, 0.11, 0.10
		btn:SetBackdropColor(0.12, 0.11, 0.10, 0.90)
		btn:SetBackdropBorderColor(SolaC.gold[1] * 0.75, SolaC.gold[2] * 0.75, SolaC.gold[3] * 0.75, 0.75)
		if fs then
			fs:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		end
	end
end

-------------------------------------------------
-- Toggle LFG panel
-------------------------------------------------
function SolaFP_LFG_Toggle(forceState, isUserClick)
	if not SolaFP_LFGPanel then
		SolaFP_LFG_Init()
	end
	if not SolaFP_LFGPanel then return end

	local newState
	if forceState ~= nil then
		newState = forceState
	else
		newState = not SolaFP_LFGPanel:IsShown()
	end

	if SolaFP_Options then
		SolaFP_Options.lfgPanelOpen = newState
	end

	SolaFP_LFGPanel:SetShown(newState)
	if SolaFP_LFG_KeyBindBtn then
		if SolaFP_Options and SolaFP_Options.lfgOnly then
			SolaFP_LFG_KeyBindBtn:Show()
		else
			SolaFP_LFG_KeyBindBtn:Hide()
		end
	end

	if SolaFP_TitleFrameLFGToggle then
		SolaFP_TitleFrameLFGToggle:SetText(newState and ((SolaFP_L["LFG"] or "파티찾기") .. " ◀") or ((SolaFP_L["LFG"] or "파티찾기") .. " ▶"))
	end

	SolaFP_LFG_UpdateToggleButton()

	if newState then
		if SolaFP_Options and SolaFP_Options.lfgFilterDrawerOpen then
			if not SolaFP_LFG_FilterDrawer then SolaFP_LFG_CreateFilterDrawer(SolaFP_LFGPanel) end
			if SolaFP_LFG_AnchorDrawer then SolaFP_LFG_AnchorDrawer() end
			if SolaFP_LFG_FilterDrawer then
				SolaFP_LFG_FilterDrawer:Show()
				SolaFP_LFG_UpdateDrawerVisuals()
			end
		end
		SolaFP_LFG_UpdateFilterButton()
		SolaFP_LFGPanel:Layout()
		local now = GetTime and GetTime() or 0
		if isUserClick and ((not items or #items == 0) or (now - (lastSearchTime or 0) >= 30)) then
			SolaFP_LFG_Search(true)
		else
			SolaFP_LFG_Search(false)
		end
	else
		if SolaFP_LFG_FilterDrawer then SolaFP_LFG_FilterDrawer:Hide() end
		if activitiesMenu then activitiesMenu:Hide() end
		if actionMenu then actionMenu:Hide() end
	end
end

-------------------------------------------------
-- Handle main frame show event
-------------------------------------------------
function SolaFP_LFG_OnFrameShow(isUserClick)
	if SolaFP_Options and SolaFP_Options.lfgOnly then
		return
	end
	if not SolaFP_LFGPanel then
		SolaFP_LFG_Init()
	end
	local shouldOpen = (SolaFP_Options and (SolaFP_Options.lfgPanelOpen or SolaFP_Options.lfgPanelShown))
	SolaFP_LFG_Toggle(shouldOpen and true or false, isUserClick or false)
end

-------------------------------------------------
-- Standalone LFG Only Mode & Mode Switcher
-------------------------------------------------
local fp_lfg_standalone_applied = false

function SolaFP_SetLFGOnlyMode(enabled)
	if not SolaFP_Options then return end
	SolaFP_Options.lfgOnly = enabled and true or false

	if SolaFP_Options.lfgOnly then
		frameData = {}
		shouterSelected = nil
	end

	local function doApply()
		if SolaFP_ApplyLFGOnlyMode then
			SolaFP_ApplyLFGOnlyMode(true, true)
		end

		if SolaFP_Print then
			if SolaFP_Options and SolaFP_Options.lfgOnly then
				SolaFP_Print(SolaFP_L["LFG_ONLY_ON_MSG"] or SolaFP_MESSAGE_LFG_ONLY_ON or "기본 파티 탐색기 전용 모드가 활성화되었습니다. (채팅 감지 중지)")
			else
				SolaFP_Print(SolaFP_L["LFG_ONLY_OFF_MSG"] or SolaFP_MESSAGE_LFG_ONLY_OFF or "통합 모드가 활성화되었습니다. (채팅 감지 재개)")
			end
		end
	end

	if C_Timer and C_Timer.After then
		C_Timer.After(0, doApply)
	else
		doApply()
	end
end

function SolaFP_ApplyLFGOnlyMode(force, explicitVisibility)
	local wasVisible = false
	if explicitVisibility ~= nil then
		wasVisible = (explicitVisibility == true)
	else
		wasVisible = (SolaFP_Frame and SolaFP_Frame:IsShown()) or (SolaFP_LFGPanel and SolaFP_LFGPanel:IsVisible())
	end

	if not SolaFP_LFGPanel then
		SolaFP_LFG_Init()
	end
	if not SolaFP_LFGPanel then return end

	local isLfgOnly = (SolaFP_Options and SolaFP_Options.lfgOnly == true)

	if isLfgOnly then
		if fp_lfg_standalone_applied and not force then
			if explicitVisibility ~= nil then
				SolaFP_LFGPanel:SetShown(explicitVisibility)
			end
			return
		end
		fp_lfg_standalone_applied = true

		-- Record current docked position before detaching, if visible
		local curLeft, curTop = nil, nil
		if SolaFP_LFGPanel:IsShown() and SolaFP_LFGPanel:GetLeft() then
			curLeft = SolaFP_LFGPanel:GetLeft()
			curTop = SolaFP_LFGPanel:GetTop()
		end

		-- 1. Hide legacy frames
		if SolaFP_Frame then SolaFP_Frame:Hide() end
		if SolaFP_ListFrame then SolaFP_ListFrame:Hide() end
		if SolaFP_TitleFrame then SolaFP_TitleFrame:Hide() end
		if SolaFP_MenuFrame then SolaFP_MenuFrame:Hide() end
		if SolaFP_WhPresetFrame then SolaFP_WhPresetFrame:Hide() end
		if SolaFP_ListFrameLFGBtn then SolaFP_ListFrameLFGBtn:Hide() end

		-- 2. Reparent to UIParent for full independence
		SolaFP_LFGPanel:SetParent(UIParent)
		SolaFP_LFGPanel:SetFrameStrata("HIGH")
		SolaFP_LFGPanel:ClearAllPoints()
		if curLeft and curTop then
			SolaFP_LFGPanel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", curLeft, curTop)
		else
			local pt = (SolaFP_Position_Save and SolaFP_Position_Save.lfgPoint) or (SolaFP_Position_Save and SolaFP_Position_Save.point) or "CENTER"
			local relPt = (SolaFP_Position_Save and SolaFP_Position_Save.lfgRelpoint) or (SolaFP_Position_Save and SolaFP_Position_Save.relpoint) or "CENTER"
			local posX = (SolaFP_Position_Save and SolaFP_Position_Save.lfgX) or (SolaFP_Position_Save and SolaFP_Position_Save.x) or 0
			local posY = (SolaFP_Position_Save and SolaFP_Position_Save.lfgY) or (SolaFP_Position_Save and SolaFP_Position_Save.y) or 0
			SolaFP_LFGPanel:SetPoint(pt, UIParent, relPt, posX, posY)
		end

		local isEnLocale = ((SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) ~= "koKR")
		local defaultW = isEnLocale and 500 or 390
		local standaloneW = (SolaFP_Options and SolaFP_Options.lfgWidth) or (SolaFP_Position_Save and SolaFP_Position_Save.lfgWidth) or defaultW
		local standaloneH = (SolaFP_Options and SolaFP_Options.lfgHeight) or (SolaFP_Position_Save and SolaFP_Position_Save.lfgHeight) or 560
		standaloneW = math.max(isEnLocale and 500 or 390, math.min(850, standaloneW))
		standaloneH = math.max(350, math.min(900, standaloneH))

		SolaFP_LFGPanel:SetSize(standaloneW, standaloneH)
		SolaFP_LFGPanel:SetMovable(true)
		SolaFP_LFGPanel:SetClampedToScreen(false)

		-- Register for ESC close
		local foundSpecial = false
		for i = 1, #UISpecialFrames do
			if UISpecialFrames[i] == "SolaFP_LFGPanel" then
				foundSpecial = true
				break
			end
		end
		if not foundSpecial then
			tinsert(UISpecialFrames, "SolaFP_LFGPanel")
		end

		-- Show standalone header buttons, scale slider & resize grip
		if SolaFP_LFG_OptionBtn then SolaFP_LFG_OptionBtn:Show() end
		if SolaFP_LFG_KeyBindBtn then SolaFP_LFG_KeyBindBtn:Show() end
		if SolaFP_LFG_ScaleSlider then
			SolaFP_LFG_ScaleSlider:Show()
			if SolaFP_LFG_ScaleSlider.__fp_label then SolaFP_LFG_ScaleSlider.__fp_label:Show() end
			local sc = tonumber(SolaFP_Options and SolaFP_Options.scale) or 1.0
			SolaFP_LFG_ScaleSlider:SetValue(sc)
		end
		if SolaFP_LFG_TitleBar then
			SolaFP_LFG_TitleBar:SetPoint("BOTTOMRIGHT", SolaFP_LFGPanel, "TOPRIGHT", -182, -36)
		end
		if SolaFP_LFG_CornerResizeGrip then SolaFP_LFG_CornerResizeGrip:Show() end

		-- Show bottom whisper bar & adjust scrollbar in standalone mode
		if SolaFP_LFG_BottomBar then SolaFP_LFG_BottomBar:Show() end
		if SolaFP_LFG_BottomSep then SolaFP_LFG_BottomSep:Show() end
		if SolaFP_LFG_WhText and SolaFP_UserDefinedWhMsg then
			SolaFP_LFG_WhText:SetText(SolaFP_UserDefinedWhMsg)
		end
		if scrollBarSlider then
			scrollBarSlider:ClearAllPoints()
			scrollBarSlider:SetPoint("TOPRIGHT", SolaFP_LFGPanel, "TOPRIGHT", -3, -resultsTop)
			scrollBarSlider:SetPoint("BOTTOMRIGHT", SolaFP_LFGPanel, "BOTTOMRIGHT", -3, 38)
		end

		-- Apply UI scale to standalone panel
		if SolaFP_UIResize then
			SolaFP_UIResize(SolaFP_Options and SolaFP_Options.scale or 1.0)
		end

		if wasVisible then
			SolaFP_LFGPanel:Show()
			if SolaFP_Options and SolaFP_Options.lfgFilterDrawerOpen then
				if not SolaFP_LFG_FilterDrawer then SolaFP_LFG_CreateFilterDrawer(SolaFP_LFGPanel) end
				if SolaFP_LFG_AnchorDrawer then SolaFP_LFG_AnchorDrawer() end
				if SolaFP_LFG_FilterDrawer then
					SolaFP_LFG_FilterDrawer:Show()
					SolaFP_LFG_UpdateDrawerVisuals()
				end
			end
			SolaFP_LFG_UpdateFilterButton()
			if SolaFP_LFGPanel.Layout then
				SolaFP_LFGPanel:Layout(standaloneH)
			end
		else
			SolaFP_LFGPanel:Hide()
			if SolaFP_LFG_FilterDrawer then SolaFP_LFG_FilterDrawer:Hide() end
		end
	else
		if not fp_lfg_standalone_applied and not force then
			if explicitVisibility ~= nil then
				if SolaFP_Frame then SolaFP_Frame:SetShown(explicitVisibility) end
				if SolaFP_LFGPanel then SolaFP_LFGPanel:SetShown(explicitVisibility) end
			end
			return
		end
		fp_lfg_standalone_applied = false

		-- Record standalone LFG position before docking so legacy frame can position naturally to its left
		local lfgLeft, lfgTop = nil, nil
		if SolaFP_LFGPanel:IsShown() and SolaFP_LFGPanel:GetLeft() then
			lfgLeft = SolaFP_LFGPanel:GetLeft()
			lfgTop = SolaFP_LFGPanel:GetTop()
		end

		-- 1. Restore legacy frames
		local legacyW = (SolaFP_Position_Save and SolaFP_Position_Save.width) or 750
		legacyW = math.max(SolaFP_MIN_WIDTH or 750, math.min(SolaFP_MAX_WIDTH or 950, legacyW))

		if lfgLeft and lfgTop then
			-- Keep LFG panel at its current spot and place legacy frame to its left!
			local targetLeft = lfgLeft - legacyW - 2
			local targetTop = lfgTop - 36 -- SolaFP_TitleFrame is 36px high above SolaFP_ListFrame
			local uiW = UIParent:GetWidth() or 1920
			local uiH = UIParent:GetHeight() or 1080
			if targetLeft < 10 then
				targetLeft = 10
			end
			if targetLeft + legacyW + 382 > uiW then
				targetLeft = math.max(10, uiW - legacyW - 382)
			end
			if targetTop > uiH - 40 then
				targetTop = uiH - 40
			end
			if targetTop < 150 then
				targetTop = 150
			end

			if SolaFP_ListFrame then
				SolaFP_ListFrame:ClearAllPoints()
				SolaFP_ListFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", targetLeft, targetTop)
				if SolaFP_ListMove then SolaFP_ListMove() end
			end
		else
			if SolaFP_SetListPosition then
				SolaFP_SetListPosition()
			end
		end

		-- 2. Re-anchor SolaFP_LFGPanel to the right side of legacy frames
		if SolaFP_Frame then
			SolaFP_LFGPanel:SetParent(SolaFP_Frame)
		end
		SolaFP_LFGPanel:SetFrameStrata("HIGH")
		SolaFP_LFGPanel:ClearAllPoints()
		SolaFP_LFGPanel:SetPoint("TOPLEFT", SolaFP_TitleFrame, "TOPRIGHT", 2, 0)
		SolaFP_LFGPanel:SetPoint("BOTTOMLEFT", SolaFP_MenuFrame, "BOTTOMRIGHT", 2, 0)
		SolaFP_LFGPanel:SetWidth(SolaFP_GetLocale() == "koKR" and 390 or 440)
		SolaFP_LFGPanel:SetMovable(false)

		-- Hide standalone buttons & resize grip (already in titlebar)
		if SolaFP_LFG_OptionBtn then SolaFP_LFG_OptionBtn:Hide() end
		if SolaFP_LFG_KeyBindBtn then SolaFP_LFG_KeyBindBtn:Hide() end
		if SolaFP_LFG_ScaleSlider then
			SolaFP_LFG_ScaleSlider:Hide()
			if SolaFP_LFG_ScaleSlider.__fp_label then SolaFP_LFG_ScaleSlider.__fp_label:Hide() end
		end
		if SolaFP_LFG_TitleBar then
			SolaFP_LFG_TitleBar:SetPoint("BOTTOMRIGHT", SolaFP_LFGPanel, "TOPRIGHT", -32, -36)
		end
		if SolaFP_LFG_CornerResizeGrip then SolaFP_LFG_CornerResizeGrip:Hide() end

		-- Hide bottom whisper bar & restore scrollbar in docked mode
		if SolaFP_LFG_BottomBar then SolaFP_LFG_BottomBar:Hide() end
		if SolaFP_LFG_BottomSep then SolaFP_LFG_BottomSep:Hide() end
		if SolaFP_WhPresetFrame and SolaFP_WhPresetFrame:IsShown() then SolaFP_WhPresetFrame:Hide() end
		if SolaFP_MenuFrameWhText and SolaFP_UserDefinedWhMsg then
			SolaFP_MenuFrameWhText:SetText(SolaFP_UserDefinedWhMsg)
		end
		if scrollBarSlider then
			scrollBarSlider:ClearAllPoints()
			scrollBarSlider:SetPoint("TOPRIGHT", SolaFP_LFGPanel, "TOPRIGHT", -3, -resultsTop)
			scrollBarSlider:SetPoint("BOTTOMRIGHT", SolaFP_LFGPanel, "BOTTOMRIGHT", -3, 8)
		end

		if SolaFP_ListFrameLFGBtn then
			SolaFP_ListFrameLFGBtn:Show()
		end

		-- Always keep LFG panel open when switching out of standalone mode
		if SolaFP_Options then
			SolaFP_Options.lfgPanelOpen = true
		end

		if wasVisible then
			if SolaFP_Frame then SolaFP_Frame:Show() end
			if SolaFP_TitleFrame and (not SolaFP_Options or SolaFP_Options.titlebarVisible ~= false) then
				SolaFP_TitleFrame:Show()
			end
			if SolaFP_MenuFrame and (not SolaFP_Options or SolaFP_Options.menubarVisible ~= false) then
				SolaFP_MenuFrame:Show()
			end
			if SolaFP_ListFrame then SolaFP_ListFrame:Show() end
			SolaFP_LFGPanel:Show()
			if SolaFP_Options and SolaFP_Options.lfgFilterDrawerOpen then
				if not SolaFP_LFG_FilterDrawer then SolaFP_LFG_CreateFilterDrawer(SolaFP_LFGPanel) end
				if SolaFP_LFG_AnchorDrawer then SolaFP_LFG_AnchorDrawer() end
				if SolaFP_LFG_FilterDrawer then
					SolaFP_LFG_FilterDrawer:Show()
					SolaFP_LFG_UpdateDrawerVisuals()
				end
			end
			SolaFP_LFG_UpdateFilterButton()
		else
			if SolaFP_Frame then SolaFP_Frame:Hide() end
			SolaFP_LFGPanel:Hide()
			if SolaFP_LFG_FilterDrawer then SolaFP_LFG_FilterDrawer:Hide() end
		end

		-- Restore scale (SolaFP_Frame gets scale, SolaFP_LFGPanel inherits 1.0)
		if SolaFP_UIResize then
			SolaFP_UIResize(SolaFP_Options and SolaFP_Options.scale or 1.0)
		end

		if SolaFP_LFG_UpdateToggleButton then
			SolaFP_LFG_UpdateToggleButton()
		end
		if SolaFP_LFGPanel.Layout then
			SolaFP_LFGPanel:Layout()
		end
	end
end

-------------------------------------------------
-- First-Time Mode Selection Card Frame (/fp card)
-------------------------------------------------
local fp_cardChoiceFrame = nil

function SolaFP_OpenCardChoiceFrame()
	if (SolaFP_GetLocale and SolaFP_GetLocale() or GetLocale()) ~= "koKR" then return end
	if fp_cardChoiceFrame and fp_cardChoiceFrame:IsShown() then
		fp_cardChoiceFrame:Hide()
		return
	end

	if not fp_cardChoiceFrame then
		local f = CreateFrame("Frame", "SolaFP_CardChoiceFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		fp_cardChoiceFrame = f
		f:SetSize(800, 520)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
		f:SetFrameStrata("DIALOG")
		f:SetFrameLevel(200)
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		tinsert(UISpecialFrames, "SolaFP_CardChoiceFrame")

		f:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
			insets = { left = 1, right = 1, top = 1, bottom = 1 },
		})
		f:SetBackdropColor(0.055, 0.050, 0.045, 0.98)
		f:SetBackdropBorderColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.55)

		-- Accent line
		local accent = f:CreateTexture(nil, "ARTWORK")
		accent:SetHeight(2)
		accent:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
		accent:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 0.8)

		-- Title
		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOPLEFT", 24, -16)
		title:SetText("SolaLFG - 파티 찾기 보기 방식 선택")
		title:SetTextColor(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3])
		local titleFont = title:GetFont()
		if titleFont then
			title:SetFont(titleFont, 16, "OUTLINE")
		end

		-- Subtitle
		local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		subtitle:SetPoint("TOPLEFT", 24, -42)
		subtitle:SetPoint("RIGHT", f, "RIGHT", -24, 0)
		subtitle:SetJustifyH("LEFT")
		subtitle:SetText("원하시는 보기 방식을 선택하세요.")
		subtitle:SetTextColor(0.80, 0.78, 0.76)
		local subFont = subtitle:GetFont()
		if subFont then
			subtitle:SetFont(subFont, 13)
		end

		-- Close button
		local closeBtn = CreateFrame("Button", nil, f)
		closeBtn:SetSize(22, 22)
		closeBtn:SetPoint("TOPRIGHT", -6, -6)
		SolaFP_StyleCloseButton(closeBtn)
		closeBtn:SetScript("OnClick", function()
			if SolaFP_Options then
				SolaFP_Options.viewModeSelected = true
			end
			f:Hide()
		end)

		-- Helper to style card frame
		local function CreateSelectionCard(parent, x, y, width, height, tagText, tagColor, badgeText, cardTitle, subTitle, bulletPoints, btnText, btnStyle, isLfgOnlyMode)
			local card = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			card:SetSize(width, height)
			card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
			card:EnableMouse(true)

			card:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8x8",
				edgeFile = "Interface\\Buttons\\WHITE8x8",
				edgeSize = 1,
				insets = { left = 1, right = 1, top = 1, bottom = 1 },
			})
			local normalBg = { 0.08, 0.075, 0.07, 0.95 }
			local hoverBg = { 0.11, 0.10, 0.09, 0.98 }
			local normalBorder = { 0.28, 0.26, 0.24, 0.6 }
			local hoverBorder = tagColor

			card:SetBackdropColor(normalBg[1], normalBg[2], normalBg[3], normalBg[4])
			card:SetBackdropBorderColor(normalBorder[1], normalBorder[2], normalBorder[3], normalBorder[4])

			-- Card Tag
			local tag = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			tag:SetPoint("TOPLEFT", 20, -18)
			tag:SetText(tagText)
			tag:SetTextColor(tagColor[1], tagColor[2], tagColor[3])
			local tagFont = tag:GetFont()
			if tagFont then
				tag:SetFont(tagFont, 12, "OUTLINE")
			end

			-- Card Title
			local cTitle = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			cTitle:SetPoint("TOPLEFT", 20, -44)
			cTitle:SetText(cardTitle)
			cTitle:SetTextColor(1, 0.95, 0.88)
			local cTitleFont = cTitle:GetFont()
			if cTitleFont then
				cTitle:SetFont(cTitleFont, 18, "OUTLINE")
			end

			-- Subtitle
			local cSub = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			cSub:SetPoint("TOPLEFT", 20, -72)
			cSub:SetText(subTitle)
			cSub:SetTextColor(0.60, 0.58, 0.56)
			local cSubFont = cSub:GetFont()
			if cSubFont then
				cSub:SetFont(cSubFont, 13)
			end

			-- Divider
			local sep = card:CreateTexture(nil, "ARTWORK")
			sep:SetHeight(1)
			sep:SetPoint("TOPLEFT", 18, -96)
			sep:SetPoint("TOPRIGHT", -18, -96)
			sep:SetColorTexture(SolaC.glassLine[1], SolaC.glassLine[2], SolaC.glassLine[3], 0.12)

			-- Bullets
			local bulletY = -112
			for _, text in ipairs(bulletPoints) do
				local bullet = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				bullet:SetPoint("TOPLEFT", 20, bulletY)
				bullet:SetPoint("RIGHT", card, "RIGHT", -20, 0)
				bullet:SetJustifyH("LEFT")
				bullet:SetWordWrap(true)
				bullet:SetText(text)
				bullet:SetTextColor(0.85, 0.83, 0.80)
				local bFont = bullet:GetFont()
				if bFont then
					bullet:SetFont(bFont, 13)
				end
				local h = bullet:GetStringHeight() or 16
				bulletY = bulletY - h - 12
			end

			-- Select Button (SolaQoL Modern Confirm Fill Animation)
			local btn = CreateFrame("Button", nil, card, BackdropTemplateMixin and "BackdropTemplate" or nil)
			btn:SetSize(width - 40, 42)
			btn:SetPoint("BOTTOM", card, "BOTTOM", 0, 20)
			btn:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				edgeSize = 1,
			})

			-- Theme colors
			local cR, cG, cB, hR, hG, hB
			if btnStyle == "positive" then
				-- Positive green theme (Tailwind green-400 / green-300)
				cR, cG, cB = 0.29, 0.87, 0.50
				hR, hG, hB = 0.52, 0.93, 0.67
			else
				-- Dark / Gold theme (Warm Gold)
				cR, cG, cB = 0.75, 0.58, 0.22
				hR, hG, hB = 0.95, 0.78, 0.35
			end

			-- Base color is dark tone of theme color
			btn:SetBackdropColor(cR * 0.2, cG * 0.2, cB * 0.2, 1)
			btn:SetBackdropBorderColor(0, 0, 0, 0.8)

			local btnFs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			btnFs:SetPoint("CENTER")
			btnFs:SetText(btnText)
			local btnFont = btnFs:GetFont()
			if btnFont then
				btnFs:SetFont(btnFont, 14, "OUTLINE")
			end
			btnFs:SetShadowColor(0, 0, 0, 0)
			btnFs:SetTextColor(1, 1, 1)
			btn:SetFontString(btnFs)

			-- Animated fill texture
			local fill = btn:CreateTexture(nil, "BORDER")
			fill:SetPoint("TOPLEFT", 1, -1)
			fill:SetPoint("BOTTOMLEFT", 1, 1)
			fill:SetColorTexture(cR, cG, cB, 1)
			fill:SetWidth(0.001)
			fill:Hide()
			btn.fillWidth = 0

			local function ResetBtnGauge()
				btn.fillWidth = 0
				fill:Hide()
				fill:SetWidth(0.001)
				fill:SetColorTexture(cR, cG, cB, 1)
			end

			btn:SetScript("OnUpdate", function(self, elapsed)
				local targetWidth = self:GetWidth() - 2
				if targetWidth <= 0 then return end
				if not self.fillWidth then self.fillWidth = 0 end

				if self:IsMouseOver() or card:IsMouseOver() then
					if self.fillWidth < targetWidth then
						self.fillWidth = self.fillWidth + (targetWidth / 1.8) * elapsed
						if self.fillWidth > targetWidth then self.fillWidth = targetWidth end
						fill:Show()
						fill:SetWidth(math.max(1, self.fillWidth))
						if self.fillWidth >= targetWidth then
							fill:SetColorTexture(hR, hG, hB, 1)
						end
					end
				else
					if self.fillWidth > 0 then
						ResetBtnGauge()
					end
				end
			end)

			btn:SetScript("OnEnter", function(self)
				local targetWidth = self:GetWidth() - 2
				if self.fillWidth and self.fillWidth >= targetWidth then
					fill:Show()
					fill:SetColorTexture(hR, hG, hB, 1)
				end
			end)

			btn:SetScript("OnLeave", function(self)
				if not card:IsMouseOver() then
					ResetBtnGauge()
				end
			end)

			btn:HookScript("OnShow", function(self)
				ResetBtnGauge()
			end)

			-- Notice label directly above the selection button
			if badgeText and badgeText ~= "" then
				local notice = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				notice:SetPoint("BOTTOM", btn, "TOP", 0, 10)
				notice:SetPoint("LEFT", card, "LEFT", 16, 0)
				notice:SetPoint("RIGHT", card, "RIGHT", -16, 0)
				notice:SetJustifyH("CENTER")
				notice:SetText(badgeText)
				local nFont = notice:GetFont()
				if nFont then
					notice:SetFont(nFont, 13, "OUTLINE")
				end
			end

			local function SelectThisMode()
				SolaFP_SetLFGOnlyMode(isLfgOnlyMode)
				if SolaFP_Options then
					SolaFP_Options.viewModeSelected = true
				end
				f:Hide()
				if isLfgOnlyMode then
					if SolaFP_LFGPanel then SolaFP_LFGPanel:Show() end
				else
					if SolaFP_Frame then SolaFP_Frame:Show() end
					if SolaFP_LFGPanel then SolaFP_LFGPanel:Show() end
				end
			end

			btn:SetScript("OnClick", function(self)
				local targetWidth = self:GetWidth() - 2
				if not self.fillWidth or self.fillWidth < targetWidth then
					return -- Do not close/select until animation is completely full
				end
				SelectThisMode()
			end)

			card:RegisterForClicks("LeftButtonUp")
			card:SetScript("OnClick", function(self)
				local targetWidth = btn:GetWidth() - 2
				if not btn.fillWidth or btn.fillWidth < targetWidth then
					return -- Do not close/select until animation is completely full
				end
				SelectThisMode()
			end)

			card:SetScript("OnEnter", function()
				card:SetBackdropColor(hoverBg[1], hoverBg[2], hoverBg[3], hoverBg[4])
				card:SetBackdropBorderColor(hoverBorder[1], hoverBorder[2], hoverBorder[3], hoverBorder[4])
			end)
			card:SetScript("OnLeave", function()
				if not card:IsMouseOver() then
					card:SetBackdropColor(normalBg[1], normalBg[2], normalBg[3], normalBg[4])
					card:SetBackdropBorderColor(normalBorder[1], normalBorder[2], normalBorder[3], normalBorder[4])
					ResetBtnGauge()
				end
			end)

			return card
		end

		-- Card 1: Integrated Mode (Left)
		local integratedBullets = {
			"|cffD4A745·|r 파티찾기 채널 구인 광고 실시간 수집 및 분류",
			"|cffD4A745·|r 관심 던전 필터링 & 제외 키워드 관리",
			"|cffD4A745·|r 우측 패널로 기본 파티 탐색기(LFG) 함께 표시",
		}
		CreateSelectionCard(
			f, 26, -76, 360, 420,
			"[ 통합 모드 ]", SolaC.gold,
			"|cffFF6B6B[ 사용을 권장하지 않음 ]|r",
			"통합 탐색 모드", "채팅 감지 + 기본 탐색기",
			integratedBullets,
			"통합 모드로 사용", "dark", false
		)

		-- Card 2: LFG Standalone Only (Right)
		local standaloneBullets = {
			"|cff5ABFBA·|r 레거시 채팅 광고글 수집 기능 완전 중지 (부하 0)",
			"|cff5ABFBA·|r 채팅 감지 창을 숨기고 파티 탐색기만 단독 표시",
			"|cff5ABFBA·|r 최신 파티찾기 시스템 기반 직관적 파티 탐색",
			"|cff5ABFBA·|r 채팅창 렉 없이 깔끔하고 쾌적한 인터페이스",
		}
		CreateSelectionCard(
			f, 414, -76, 360, 420,
			"[ 편리하고 직관적인 ]", SolaC.teal,
			"|cff00FF99[ 포에버 파티찾기 사용을 강력히 추천 ]|r",
			"포에버 파티 탐색기", "새로 나온 파티찾기 도구",
			standaloneBullets,
			"포에버 파티 탐색기 사용", "positive", true
		)
	end

	fp_cardChoiceFrame:Show()
end

-------------------------------------------------
-- Update Notice Popup Frame (SolaQoL Modern Style)
-------------------------------------------------
local fp_updateNoticePopup = nil
local SolaFP_UPDATE_NOTICE_VERSION = "1.39"

function SolaFP_ShowUpdatePopup(force)
	if fp_updateNoticePopup and fp_updateNoticePopup:IsShown() and not force then
		fp_updateNoticePopup:Hide()
		return
	end

	if not fp_updateNoticePopup then
		local f = CreateFrame("Frame", "SolaFP_UpdateNoticePopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		fp_updateNoticePopup = f
		f:SetSize(720, 410)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		f:SetFrameStrata("DIALOG")
		f:SetFrameLevel(300)
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)

		f:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		f:SetBackdropColor(0.07, 0.06, 0.06, 0.96)
		f:SetBackdropBorderColor(0, 0, 0, 0.75)

		-- Header
		local header = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
		header:SetPoint("TOPLEFT", 1, -1)
		header:SetPoint("TOPRIGHT", -1, -1)
		header:SetHeight(40)
		header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
		header:SetBackdropColor(0.05, 0.04, 0.04, 0.95)

		local topGoldLine = header:CreateTexture(nil, "OVERLAY")
		topGoldLine:SetPoint("TOPLEFT", 0, 0)
		topGoldLine:SetPoint("TOPRIGHT", 0, 0)
		topGoldLine:SetHeight(1.5)
		topGoldLine:SetColorTexture(SolaC.gold[1], SolaC.gold[2], SolaC.gold[3], 1)

		local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("CENTER", 0, 0)
		title:SetText(string.format("|cffD4A745SolaLFG|r  |cffA8A29E[ %s ]|r", SolaFP_L["Update Notes"] or "업데이트 안내"))
		local tFont, tSize = title:GetFont()
		if tFont then title:SetFont(tFont, (tSize or 14) + 4, "OUTLINE") end

		-- Date / version label
		local dateLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		dateLbl:SetPoint("TOPLEFT", 30, -56)
		dateLbl:SetText("|cff8A85802026. 11. 23 / v1.39|r")
		local dFont, dSize = dateLbl:GetFont()
		if dFont then dateLbl:SetFont(dFont, (dSize or 12) + 2) end

		-- Section Title
		local titleLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		titleLbl:SetPoint("TOPLEFT", dateLbl, "BOTTOMLEFT", 0, -8)
		titleLbl:SetText(string.format("|cffD4A745[ %s ]|r", SolaFP_L["Major Improvements & Feature Updates"] or "주요 변경 및 기능 개선 안내"))
		local stFont, stSize = titleLbl:GetFont()
		if stFont then titleLbl:SetFont(stFont, (stSize or 14) + 3, "OUTLINE") end

		-- Body text
		local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		desc:SetPoint("TOPLEFT", titleLbl, "BOTTOMLEFT", 0, -16)
		desc:SetPoint("BOTTOMRIGHT", -30, 75)
		desc:SetJustifyH("LEFT")
		desc:SetJustifyV("TOP")
		desc:SetSpacing(6)
		local bFont, bSize = desc:GetFont()
		if bFont then desc:SetFont(bFont, (bSize or 12) + 4) end

		local descLines = {
			SolaFP_L["UPDATE_NOTICE_P1_TITLE"] or "|cff5ABFBA· 채팅창 [Alt + 좌클릭] 파티 초대 기능 추가|r",
			SolaFP_L["UPDATE_NOTICE_P1_DESC"] or "  이제부터 채팅창의 플레이어 닉네임을 [Alt + 좌클릭]하면 파티 초대가 가능해집니다.",
		}
		desc:SetText(table.concat(descLines, "\n"))

		-- Close Button (SolaQoL Modern Green Theme)
		local closeBtn = CreateFrame("Button", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
		closeBtn:SetSize(190, 38)
		closeBtn:SetPoint("BOTTOM", 0, 20)
		closeBtn:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		local cR, cG, cB = 0.29, 0.87, 0.50
		local hR, hG, hB = 0.52, 0.93, 0.67

		closeBtn:SetBackdropColor(cR * 0.2, cG * 0.2, cB * 0.2, 1)
		closeBtn:SetBackdropBorderColor(0, 0, 0, 0.8)

		local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		closeTxt:SetPoint("CENTER")
		closeTxt:SetText(SolaFP_L["Confirm & Close"] or "확인 및 닫기")
		local font, size = closeTxt:GetFont()
		if font then closeTxt:SetFont(font, (size or 12) + 3, "OUTLINE") end
		closeTxt:SetShadowColor(0, 0, 0, 0)
		closeTxt:SetTextColor(1, 1, 1)

		-- Animated fill (SolaQoL gauge)
		local fill = closeBtn:CreateTexture(nil, "BORDER")
		fill:SetPoint("TOPLEFT", 1, -1)
		fill:SetPoint("BOTTOMLEFT", 1, 1)
		fill:SetColorTexture(cR, cG, cB, 1)
		fill:SetWidth(1)

		closeBtn:SetScript("OnUpdate", function(self, elapsed)
			local targetWidth = self:GetWidth() - 2
			if not self.fillWidth then self.fillWidth = 1 end
			if self.fillWidth < targetWidth then
				self.fillWidth = self.fillWidth + (targetWidth / 2.0) * elapsed
				if self.fillWidth > targetWidth then self.fillWidth = targetWidth end
				fill:SetWidth(self.fillWidth)
			end
		end)

		closeBtn:SetScript("OnEnter", function(self)
			local targetWidth = self:GetWidth() - 2
			if self.fillWidth and self.fillWidth >= targetWidth then
				fill:SetColorTexture(hR, hG, hB, 1)
			end
		end)
		closeBtn:SetScript("OnLeave", function(self)
			fill:SetColorTexture(cR, cG, cB, 1)
		end)

		local function ConfirmAndClose()
			local targetWidth = closeBtn:GetWidth() - 2
			if not closeBtn.fillWidth or closeBtn.fillWidth < targetWidth then
				return -- Do not close until animation is completely full
			end
			if SolaFP_Options then
				SolaFP_Options.lastShownUpdateNotice = SolaFP_UPDATE_NOTICE_VERSION
			end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
			f:Hide()
			if SolaFP_Options and SolaFP_Options.lfgOnly and SolaFP_LFGPanel and not SolaFP_LFGPanel:IsShown() then
				SolaFP_LFGPanel:Show()
			end
		end

		closeBtn:SetScript("OnClick", ConfirmAndClose)

		f.ResetGauge = function()
			closeBtn.fillWidth = 1
			fill:SetWidth(1)
			fill:SetColorTexture(cR, cG, cB, 1)
		end
	end

	fp_updateNoticePopup.ResetGauge()
	fp_updateNoticePopup:Show()
	fp_updateNoticePopup:Raise()
end
