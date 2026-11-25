local KO = setmetatable({}, { __index = function(_, key) return key end })
if GetLocale() == "koKR" then
    KO[" (default)"] = " (기본값)"
    KO[" open when you leave combat."] = "전투가 끝나면 열립니다."
    KO[" yards"] = "야드"
    KO[" yards after combat|r"] = "야드 (전투 종료 후 적용)|r"
    KO[" |cff808080(default)|r"] = " |cff808080(기본값)|r"
    KO[", or type its name or ID above."] = "를 누르거나 위에 이름 또는 ID를 입력하세요."
    KO["A mob is spotted as soon as its nameplate shows, so the radius is the game's nameplate distance. "] = "이름표가 표시되면 NPC를 감지하므로 감지 범위는 이름표 표시 거리와 같습니다. "
    KO["Add"] = "추가"
    KO["Add a mob by name or ID"] = "이름 또는 ID로 NPC 추가"
    KO["Alert"] = "알림"
    KO["Alerts you for any rare mob close by, also ones that aren't on your list, and puts the marker over it. They don't go on the list."] = "목록에 없는 희귀 NPC도 근처에서 감지하면 알림과 표식을 표시합니다. 목록에 자동 추가되지는 않습니다."
    KO["Alerts you when a mob on your list is close by."] = "등록한 NPC가 근처에 나타나면 알려줍니다."
    KO["Also makes the game's icon blink on your taskbar while the game is in the background."] = "게임이 백그라운드에 있을 때는 작업 표시줄의 게임 아이콘도 깜박입니다."
    KO["Animation"] = "애니메이션"
    KO["Flash the screen edges"] = "화면 가장자리 깜박임"
    KO["Game sounds"] = "게임 기본 소리"
    KO["Keybinds"] = "단축키"
    KO["Line in chat"] = "대화창 알림"
    KO["Look for this mob"] = "이 NPC 감지"
    KO["Map markers"] = "지도 표식"
    KO["Marker"] = "표식"
    KO["Marker for players"] = "플레이어 표시 아이콘"
    KO["Message at the top of the screen"] = "화면 상단 알림"
    KO["Mobs the game marks on the map"] = "지도에 표시된 NPC 감지"
    KO["Mobs to look for"] = "찾을 NPC 목록"
    KO["Nameplate marker"] = "이름표 표식"
    KO["Nothing here yet. Target a mob and press "] = "등록된 NPC가 없습니다. NPC를 선택하고 "
    KO["Opens the game's keybindings at MobSpot's key."] = "MobSpot 단축키 설정 화면을 엽니다."
    KO["Rare mobs the game puts a marker on, on the map or minimap, are spotted within your scan radius, and the alert says how far away they are."] = "지도나 미니맵에 표식이 있는 희귀 NPC를 감지 범위 안에서 찾고 거리를 알려줍니다."
    KO["Remove"] = "삭제"
    KO["Same as /ms minimap."] = "/ms minimap과 같습니다."
    KO["Same as /ms on and /ms off."] = "/ms on으로 켜고 /ms off로 끌 수 있습니다."
    KO["Scan enemy-faction players"] = "적 진영 플레이어 감지"
    KO["Scan for my mobs"] = "등록한 NPC 감지"
    KO["Scan players you can attack"] = "공격 가능한 플레이어 감지"
    KO["Scan radius"] = "감지 범위"
    KO["Scan rares automatically"] = "희귀 NPC 자동 감지"
    KO["Set keybinds"] = "단축키 설정"
    KO["Shared by your other addons"] = "다른 애드온의 공유 소리"
    KO["Show a marker over the mob's nameplate"] = "NPC 이름표 위에 표식 표시"
    KO["Show minimap button"] = "미니맵 버튼 표시"
    KO["Shows enemy nameplates, also out of combat, so MobSpot can spot mobs by them."] = "전투 중이 아닐 때도 적 이름표를 표시하여 NPC를 감지합니다."
    KO["Shows the alert as it would look for a mob on your list. Same as /ms test."] = "등록한 NPC를 발견했을 때의 알림을 시험합니다. /ms test와 같습니다."
    KO["Size"] = "크기"
    KO["Sound"] = "알림음"
    KO["Sound for players"] = "플레이어 알림음"
    KO["Takes the mob off the list."] = "이 NPC를 목록에서 삭제합니다."
    KO["Test alert"] = "알림 테스트"
    KO["The same, in your chat window, so you can look back at it."] = "나중에 확인할 수 있도록 대화창에도 알림을 남깁니다."
    KO["Track/Untrack Target"] = "대상 추적 등록/해제"
    KO["Turn on nameplates"] = "적 이름표 켜기"
    KO["Type a mob's name or ID"] = "NPC 이름 또는 ID 입력"
    KO["Type its name exactly as the game shows it, or its NPC ID (the number in its Wowhead link), then press Enter."] = "게임에 표시되는 정확한 이름 또는 NPC ID(Wowhead 링크의 숫자)를 입력한 뒤 Enter를 누르세요."
    KO["Untick to stop looking for it without taking it off the list."] = "체크를 해제하면 목록을 유지한 채 감지만 중지합니다."
    KO["set it under Esc > Options > Keybindings > MobSpot."] = "Esc > 설정 > 단축키 > MobSpot에서 지정하세요."
    KO["the keybindings"] = "단축키 설정 창이"
    KO["the options"] = "설정 창이"
    KO["your MobSpot key (set it under Keybinds below)"] = "MobSpot 단축키(아래에서 지정)"
    KO["|cff40ff40Enemy nameplates are on.|r"] = "|cff40ff40적 이름표가 켜져 있습니다.|r"
    KO["|cff808080no key set|r"] = "|cff808080미지정|r"
    KO["|cffff6060Enemy nameplates are off or only show in combat, so mobs aren't spotted by them.|r"] = "|cffff6060적 이름표가 꺼져 있거나 전투 중에만 표시되어 이름표로 NPC를 감지할 수 없습니다.|r"
end
-- MobSpot: options
-- Esc > Options > AddOns > MobSpot, or /ms. One page: the mob list, the scan radius, map
-- markers, the alert, keybinds and the minimap button.

local _, ns = ...

local WIDTH = 620     -- the page's content
local ROW_HEIGHT = 26 -- mob list rows
local LIST_ROWS = 7   -- rows the mob list shows before it scrolls
local SOUND_MENU_HEIGHT = 400 -- the sound menu scrolls past this

local category
local content
local refreshers = {} -- { tag = string, fn = function }

local function addRefresher(tag, fn)
	refreshers[#refreshers + 1] = { tag = tag, fn = fn }
end

local function refreshAll()
	for _, entry in ipairs(refreshers) do entry.fn() end
end

local function refreshTag(tag)
	if not (content and content:IsVisible()) then return end
	for _, entry in ipairs(refreshers) do
		if entry.tag == tag then entry.fn() end
	end
end

-- The game doesn't let addons open its settings during combat, so a request then waits for the fight to end.
local openAfterCombat -- the function to run when combat ends

local function waitForCombatEnd(open, what)
	if not openAfterCombat then
		ns.Print(what .. KO[" open when you leave combat."])
	end
	openAfterCombat = open
end

ns.On("PLAYER_REGEN_ENABLED", function()
	local open = openAfterCombat
	if open then
		openAfterCombat = nil
		open()
	end
end)

function ns.OpenOptions()
	if not category then return end
	if InCombatLockdown() then
		waitForCombatEnd(ns.OpenOptions, KO["the options"])
		return
	end
	Settings.OpenToCategory(category:GetID())
end

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------

local function tooltip(frame, title, body)
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function text(parent, font, value, width)
	local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
	fs:SetJustifyH("LEFT")
	if width then fs:SetWidth(width) end
	if value then fs:SetText(value) end
	return fs
end

local function heading(value, y)
	local fs = text(content, "GameFontNormalLarge", value)
	fs:SetPoint("TOPLEFT", 16, y)
	return fs
end

local function checkbox(label, help, get, set, tag)
	local check = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
	local fs = text(check, "GameFontHighlight", label)
	fs:SetPoint("LEFT", check, "RIGHT", 4, 1)
	check.label = fs
	check:SetHitRectInsets(0, -fs:GetStringWidth() - 8, 0, 0)
	check:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	tooltip(check, label, help)
	addRefresher(tag, function() check:SetChecked(get()) end)
	return check
end

local function setting(key)
	return function() return ns.db[key] end, function(v)
		ns.db[key] = v
		ns.Fire("SettingChanged", key)
	end, key
end

-- A slider for the setting `key`, from `minValue` to `maxValue` in steps of `step`, at x, y.
-- `describe(value)` is the text beside it.
local function settingSlider(x, y, minValue, maxValue, step, key, describe)
	local slider = CreateFrame("Frame", nil, content, "MinimalSliderWithSteppersTemplate")
	slider:SetSize(260, 20)
	slider:SetPoint("TOPLEFT", x, y)
	local value = text(content, "GameFontHighlight")
	value:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	slider:Init(ns.db[key], minValue, maxValue, (maxValue - minValue) / step)
	local syncing = false
	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, picked)
		local v = math.floor(picked + 0.5)
		value:SetText(describe(v))
		if syncing or ns.db[key] == v then return end
		ns.db[key] = v
		ns.Fire("SettingChanged", key)
	end, slider)
	addRefresher(key, function()
		syncing = true
		slider:SetValue(ns.db[key])
		syncing = false
		value:SetText(describe(ns.db[key]))
	end)
	return slider
end

local function button(parent, label, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetText(label)
	b:SetSize(width, 24)
	b:SetScript("OnClick", onClick)
	return b
end

---------------------------------------------------------------------------
-- Mobs to look for
---------------------------------------------------------------------------

local mobList, mobEmpty

local function drawMobRow(row, data)
	if not row.name then
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		row.check:SetSize(24, 24)
		row.check:SetPoint("LEFT", 2, 0)
		row.check:SetScript("OnClick", function(self)
			ns.SetMobOn(self:GetParent().key, self:GetChecked() and true or false)
		end)
		tooltip(row.check, KO["Look for this mob"], KO["Untick to stop looking for it without taking it off the list."])
		row.name = text(row, "GameFontHighlight")
		row.name:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
		row.name:SetPoint("RIGHT", -120, 0)
		row.name:SetWordWrap(false)
		row.id = text(row, "GameFontDisable")
		row.id:SetPoint("RIGHT", -34, 0)
		row.remove = CreateFrame("Button", nil, row, "UIPanelCloseButtonNoScripts")
		row.remove:SetSize(22, 22)
		row.remove:SetPoint("RIGHT", -4, 0)
		row.remove:SetScript("OnClick", function(self) ns.RemoveMob(self:GetParent().key) end)
		tooltip(row.remove, KO["Remove"], KO["Takes the mob off the list."])
	end
	row.key = data.key
	row.check:SetChecked(data.mob.on)
	row.name:SetText(data.mob.name)
	row.name:SetTextColor(data.mob.on and 1 or 0.5, data.mob.on and 1 or 0.5, data.mob.on and 1 or 0.5)
	row.id:SetText((data.mob.npcID and not data.mob.unnamed) and ("ID " .. data.mob.npcID) or "")
end

local function addTyped(box)
	if ns.AddTyped(box:GetText()) then box:SetText("") end
	box:ClearFocus()
end

local function buildMobs(y)
	heading(KO["Mobs to look for"], y)
	y = y - 30

	local box = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	box:SetSize(240, 20)
	box:SetPoint("TOPLEFT", 24, y)
	box:SetAutoFocus(false)
	box:SetFontObject("GameFontHighlight")
	box:SetScript("OnEnterPressed", addTyped)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	local hint = text(box, "GameFontDisable", KO["Type a mob's name or ID"])
	hint:SetPoint("LEFT", 2, 0)
	box:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
	box:HookScript("OnEditFocusGained", function() hint:Hide() end)
	box:HookScript("OnEditFocusLost", function(self) hint:SetShown(self:GetText() == "") end)
	tooltip(box, KO["Add a mob by name or ID"],
		KO["Type its name exactly as the game shows it, or its NPC ID (the number in its Wowhead link), then press Enter."])

	local add = button(content, KO["Add"], 70, function() addTyped(box) end)
	add:SetPoint("LEFT", box, "RIGHT", 8, 0)
	y = y - 32

	local scrollBox = CreateFrame("Frame", nil, content, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", 16, y)
	scrollBox:SetSize(WIDTH - 30, ROW_HEIGHT * LIST_ROWS)
	-- A sunken box around the list, so an empty or short list still reads as a list.
	local inset = CreateFrame("Frame", nil, content, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", scrollBox, "TOPLEFT", -4, 4)
	inset:SetPoint("BOTTOMRIGHT", scrollBox, "BOTTOMRIGHT", 4, -4)
	inset:SetFrameLevel(scrollBox:GetFrameLevel() - 1)
	local bar = CreateFrame("EventFrame", nil, content, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Button", drawMobRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, bar, view)
	bar:SetHideIfUnscrollable(true)
	mobList = scrollBox

	mobEmpty = text(content, "GameFontDisable", nil, WIDTH - 40)
	mobEmpty:SetPoint("TOPLEFT", scrollBox, "TOPLEFT", 8, -6)

	addRefresher("mobs", function()
		mobList:SetDataProvider(CreateDataProvider(ns.SortedMobs()), ScrollBoxConstants.RetainScrollPosition)
		mobEmpty:SetShown(ns.MobCount() == 0)
	end)
	addRefresher("bindings", function()
		local key = ns.BoundKey(ns.BIND_ADD)
		mobEmpty:SetText(KO["Nothing here yet. Target a mob and press "]
			.. (key and key or KO["your MobSpot key (set it under Keybinds below)"])
			.. KO[", or type its name or ID above."])
	end)
	y = y - ROW_HEIGHT * LIST_ROWS - 20

	checkbox(KO["Scan rares automatically"],
		KO["Alerts you for any rare mob close by, also ones that aren't on your list, and puts the marker over it. They don't go on the list."],
		setting("rares")):SetPoint("TOPLEFT", 16, y)
	y = y - 30
	checkbox(KO["Scan enemy-faction players"],
		"Alerts you when a player of the other faction is close by, flagged for PvP or not. All enemy players share one \"Enemy players\" line that says how many are close by.",
		setting("playersEnemy")):SetPoint("TOPLEFT", 16, y)
	y = y - 30
	checkbox(KO["Scan players you can attack"],
		"Alerts you when a player you can attack right now is close by, whatever their faction. They share the same \"Enemy players\" line.",
		setting("playersAttack")):SetPoint("TOPLEFT", 16, y)
	y = y - 30
	checkbox("Scan players in battlegrounds and arenas too",
		"Without this, players don't alert inside battlegrounds and arenas, where enemies are everywhere.",
		setting("playersPvp")):SetPoint("TOPLEFT", 40, y)
	return y - 40
end

---------------------------------------------------------------------------
-- Scan radius
---------------------------------------------------------------------------

local function buildRadius(y)
	heading(KO["Scan radius"], y)
	y = y - 26
	local about = text(content, "GameFontHighlight",
		KO["A mob is spotted as soon as its nameplate shows, so the radius is the game's nameplate distance. "]
			.. "It changes how far away every nameplate shows. The game shows none further away than 40 yards.",
		WIDTH - 20)
	about:SetPoint("TOPLEFT", 20, y)
	y = y - 44

	local slider = CreateFrame("Frame", nil, content, "MinimalSliderWithSteppersTemplate")
	slider:SetSize(260, 20)
	slider:SetPoint("TOPLEFT", 20, y)
	local value = text(content, "GameFontHighlight")
	value:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	local step = 5
	slider:Init(ns.Radius(), ns.RADIUS_MIN, ns.RADIUS_MAX, (ns.RADIUS_MAX - ns.RADIUS_MIN) / step)
	local syncing = false
	local function showValue()
		value:SetText(math.floor(ns.Radius() + 0.5) .. KO[" yards"])
	end
	slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, picked)
		if syncing then return end
		if not ns.SetRadius(picked) then
			value:SetText("|cffffd100" .. math.floor(picked + 0.5) .. KO[" yards after combat|r"])
			return
		end
		showValue()
	end, slider)
	addRefresher("radius", function()
		syncing = true
		slider:SetValue(ns.Radius())
		syncing = false
		showValue()
	end)
	y = y - 34

	local status = text(content, "GameFontHighlight", nil, WIDTH - 200)
	status:SetPoint("TOPLEFT", 20, y)
	local turnOn = button(content, KO["Turn on nameplates"], 170, function() ns.TurnOnNameplates() end)
	turnOn:SetPoint("TOPRIGHT", content, "TOPLEFT", WIDTH, y + 4)
	tooltip(turnOn, KO["Turn on nameplates"], KO["Shows enemy nameplates, also out of combat, so MobSpot can spot mobs by them."])
	addRefresher("nameplates", function()
		if ns.NameplatesOn() then
			status:SetText(KO["|cff40ff40Enemy nameplates are on.|r"])
			turnOn:Hide()
		else
			status:SetText(KO["|cffff6060Enemy nameplates are off or only show in combat, so mobs aren't spotted by them.|r"])
			turnOn:Show()
		end
	end)
	return y - 40
end

---------------------------------------------------------------------------
-- Map markers
---------------------------------------------------------------------------

local function buildOther(y)
	heading(KO["Map markers"], y)
	y = y - 30
	local markers = checkbox(KO["Mobs the game marks on the map"],
		KO["Rare mobs the game puts a marker on, on the map or minimap, are spotted within your scan radius, and the alert says how far away they are."],
		setting("mapMarkers"))
	markers:SetPoint("TOPLEFT", 16, y)
	return y - 44
end

---------------------------------------------------------------------------
-- Alert
---------------------------------------------------------------------------

local function buildAlert(y)
	heading(KO["Alert"], y)
	y = y - 30

	-- A dropdown picking the sound saved under `setKey`; picking one plays it.
	local function soundMenu(labelText, setKey)
		local label = text(content, "GameFontHighlight", labelText)
		label:SetPoint("TOPLEFT", 22, y - 6)
		local menu = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
		menu:SetWidth(180)
		menu:SetPoint("TOPLEFT", 170, y)
		if menu.Text then menu.Text:SetFontObject("GameFontHighlight") end
		local function radio(root, name, key)
			root:CreateRadio(name, function() return ns.db[setKey] == key end, function()
				ns.db[setKey] = key
				ns.PlayAlertSound(key)
			end)
		end
		menu:SetupMenu(function(_, root)
			if root.SetScrollMode then root:SetScrollMode(SOUND_MENU_HEIGHT) end
			root:CreateTitle(KO["Game sounds"])
			for _, sound in ipairs(ns.SOUNDS) do radio(root, sound.name, sound.key) end
			-- listed each time the menu opens, since other addons may add theirs later
			local shared = ns.SharedSounds()
			if #shared > 0 then
				root:CreateDivider()
				root:CreateTitle(KO["Shared by your other addons"])
				for _, name in ipairs(shared) do radio(root, name, ns.SharedSoundKey(name)) end
			end
		end)
		addRefresher(setKey, function() menu:GenerateMenu() end)
		y = y - 36
		return menu
	end

	local menu = soundMenu(KO["Sound"], "sound")
	local test = button(content, KO["Test alert"], 110, function() ns.TestAlert() end)
	test:SetPoint("LEFT", menu, "RIGHT", 16, 0)
	tooltip(test, KO["Test alert"], KO["Shows the alert as it would look for a mob on your list. Same as /ms test."])
	tooltip(soundMenu(KO["Sound for players"], "playerSound"), KO["Sound for players"],
		"The sound of the Enemy players alert, so you can tell it from a mob's by ear.")

	local again = text(content, "GameFontHighlight",
		"While a mob stays close by it alerts only once. It alerts again when it has left and come back.",
		WIDTH - 20)
	again:SetPoint("TOPLEFT", 20, y)
	y = y - 28

	checkbox("Alert for each mob of the same name",
		"Every mob of the same name that comes close gets its own alert, which says how many are in range. Without this, one alert covers them all until none of them is in range any more.",
		setting("alertEach")):SetPoint("TOPLEFT", 16, y)
	y = y - 34

	checkbox(KO["Message at the top of the screen"], "The mob's name and how close it is, for a few seconds. To move it, open the game's Edit Mode and drag the MobSpot alert box.", setting("screenText"))
		:SetPoint("TOPLEFT", 16, y)
	y = y - 30
	checkbox("Keep the message on screen, and 1 minute more when you look away",
		"The message stays for as long as the mob is in range, instead of fading after a few seconds. When you look away from the mob, the time is extended by 1 minute.",
		setting("keepMessage")):SetPoint("TOPLEFT", 40, y)
	y = y - 30
	checkbox(KO["Line in chat"], KO["The same, in your chat window, so you can look back at it."], setting("chatLine"))
		:SetPoint("TOPLEFT", 16, y)
	y = y - 30
	checkbox(KO["Flash the screen edges"], KO["Also makes the game's icon blink on your taskbar while the game is in the background."], setting("flash"))
		:SetPoint("TOPLEFT", 16, y)
	return y - 44
end

---------------------------------------------------------------------------
-- Nameplate marker
---------------------------------------------------------------------------

local PREVIEW_BOX = 120 -- the preview's box, wide enough for the biggest marker

local function buildMarker(y)
	heading(KO["Nameplate marker"], y)
	local top = y
	y = y - 30

	checkbox(KO["Show a marker over the mob's nameplate"],
		"Shows a marker over a listed mob's nameplate for as long as it shows, so you can pick the mob out. Enemy players you scan for get the marker picked under Marker for players. Only you see it. Not in dungeons and raids, where the game keeps nameplates from addons.",
		setting("marker")):SetPoint("TOPLEFT", 16, y)
	y = y - 36

	-- A dropdown picking one of `list` ({ key, name }) for the setting `key`.
	local function choice(label, list, key, default, decorate)
		local fs = text(content, "GameFontHighlight", label)
		fs:SetPoint("TOPLEFT", 22, y - 6)
		local menu = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
		menu:SetWidth(200)
		menu:SetPoint("TOPLEFT", 170, y)
		if menu.Text then menu.Text:SetFontObject("GameFontHighlight") end
		menu:SetupMenu(function(_, root)
			for _, item in ipairs(list) do
				local name = (decorate and decorate(item) or "") .. item.name
					.. (item.key == default and KO[" |cff808080(default)|r"] or "")
				root:CreateRadio(name, function() return ns.db[key] == item.key end, function()
					ns.db[key] = item.key
					ns.Fire("SettingChanged", key)
				end)
			end
		end)
		addRefresher(key, function() menu:GenerateMenu() end)
		y = y - 40
	end
	local function icon(m) return ns.MarkerIcon(m, 16) .. " " end
	choice(KO["Marker"], ns.MARKERS, "markerStyle", ns.DEFAULT_MARKER, icon)
	choice(KO["Marker for players"], ns.PLAYER_MARKERS, "playerMarkerStyle", ns.DEFAULT_PLAYER_MARKER, icon)
	choice(KO["Animation"], ns.MOTIONS, "markerMotion", ns.DEFAULT_MOTION)

	local size = text(content, "GameFontHighlight", KO["Size"])
	size:SetPoint("TOPLEFT", 22, y - 2)
	settingSlider(170, y, ns.MARKER_SIZE_MIN, ns.MARKER_SIZE_MAX, 2, "markerSize", function(v)
		return v .. (v == 34 and KO[" (default)"] or "")
	end)

	-- The preview, moving the way it does over a nameplate.
	local box = CreateFrame("Frame", nil, content, "InsetFrameTemplate")
	box:SetSize(PREVIEW_BOX, PREVIEW_BOX)
	box:SetPoint("TOPRIGHT", content, "TOPLEFT", WIDTH, top - 30)
	local preview = ns.NewMarker(box)
	preview:SetPoint("CENTER")
	preview:SetFrameLevel(box:GetFrameLevel() + 5)
	addRefresher("marker", function()
		preview:SetAlpha(ns.db.marker and 1 or 0.35)
	end)
	return math.min(y - 44, top - 30 - PREVIEW_BOX - 20)
end

---------------------------------------------------------------------------
-- Keybinds and minimap button
---------------------------------------------------------------------------

local function bindLine(label, binding, y)
	local fs = text(content, "GameFontHighlight", nil, WIDTH - 200)
	fs:SetPoint("TOPLEFT", 22, y)
	addRefresher("bindings", function()
		local key = ns.BoundKey(binding)
		fs:SetText(label .. ": " .. (key and ("|cffffd100" .. key .. "|r") or KO["|cff808080no key set|r"]))
	end)
end

-- Opens the game's Keybindings page scrolled to MobSpot's own section.
local function openKeybinds()
	if not Settings.KEYBINDINGS_CATEGORY_ID then
		ns.Print(KO["set it under Esc > Options > Keybindings > MobSpot."])
		return
	end
	if InCombatLockdown() then
		waitForCombatEnd(openKeybinds, KO["the keybindings"])
		return
	end
	Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID, ns.BIND_SECTION)
end

local function buildKeybinds(y)
	heading(KO["Keybinds"], y)
	y = y - 30
	bindLine(KO["Track/Untrack Target"], ns.BIND_ADD, y)
	local set = button(content, KO["Set keybinds"], 130, openKeybinds)
	set:SetPoint("TOPRIGHT", content, "TOPLEFT", WIDTH, y + 4)
	tooltip(set, KO["Set keybinds"], KO["Opens the game's keybindings at MobSpot's key."])
	y = y - 40

	local minimap = checkbox(KO["Show minimap button"], KO["Same as /ms minimap."],
		function() return not ns.db.minimap.hide end, function(v) ns.SetMinimapShown(v) end, "minimap")
	minimap:SetPoint("TOPLEFT", 16, y)
	return y - 40
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

local function build()
	local panel = CreateFrame("Frame")
	panel.name = ns.TITLE

	local scroll = CreateFrame("ScrollFrame", nil, panel)
	scroll:SetPoint("TOPLEFT", 0, -4)
	scroll:SetPoint("BOTTOMRIGHT", -22, 4)
	local bar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
	bar:SetHideIfUnscrollable(true)
	scroll:EnableMouseWheel(true)

	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WIDTH + 20, 1)
	scroll:SetScrollChild(content)

	local title = text(content, "GameFontNormalHuge", ns.TITLE)
	title:SetPoint("TOPLEFT", 16, -16)
	local sub = text(content, "GameFontHighlight", KO["Alerts you when a mob on your list is close by."])
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	local y = -70
	checkbox(KO["Scan for my mobs"], KO["Same as /ms on and /ms off."], setting("enabled")):SetPoint("TOPLEFT", 16, y)
	y = y - 44

	y = buildMobs(y)
	y = buildRadius(y)
	y = buildOther(y)
	y = buildAlert(y)
	y = buildMarker(y)
	y = buildKeybinds(y)
	content:SetHeight(-y + 24)

	panel:SetScript("OnShow", refreshAll)
	category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
	Settings.RegisterAddOnCategory(category)
end

ns.Listen("Loaded", build)

ns.Listen("MobsChanged", function() refreshTag("mobs") end)
ns.Listen("SettingChanged", function(key)
	if key then refreshTag(key) elseif content and content:IsVisible() then refreshAll() end
end)
ns.On("UPDATE_BINDINGS", function() refreshTag("bindings") end)
ns.On("CVAR_UPDATE", function(name)
	local lower = type(name) == "string" and name:lower() or ""
	if lower == "nameplatemaxdistance" then
		refreshTag("radius")
	elseif lower == "nameplateshowenemies" or lower == "nameplateshowall" then
		refreshTag("nameplates")
	end
end)
