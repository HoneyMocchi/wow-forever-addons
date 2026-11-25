local KO = setmetatable({}, { __index = function(_, key) return key end })
if GetLocale() == "koKR" then
    KO["  /ms - options"] = "  /ms - 설정"
    KO["  /ms add <name or ID> - add a mob by name or NPC ID"] = "  /ms add <이름 또는 ID> - NPC 추가"
    KO["  /ms list - show the list"] = "  /ms list - 등록 목록 표시"
    KO["  /ms minimap - show or hide the minimap button"] = "  /ms minimap - 미니맵 버튼 표시/숨김"
    KO["  /ms on | off - scan for your mobs, or stop"] = "  /ms on | off - NPC 감지 켜기/끄기"
    KO["  /ms remove <name or ID> - take a mob off the list"] = "  /ms remove <이름 또는 ID> - NPC 삭제"
    KO["  /ms target - add your target to the list, or take it off"] = "  /ms target - 현재 대상 등록/해제"
    KO["  /ms test - show a test alert"] = "  /ms test - 알림 테스트"
    KO[" is already on the list."] = ": 이미 목록에 있습니다."
    KO[" is off the list."] = ": 목록에서 삭제했습니다."
    KO[" is on the list."] = ": 목록에 등록했습니다."
    KO[" is on the list. Its name shows once the game knows it."] = ": 목록에 등록했습니다. 게임에서 이름을 확인하면 표시됩니다."
    KO[" is on the list. You'll get an alert when it's close by."] = ": 등록했습니다. 근처에서 감지되면 알려드립니다."
    KO[" on the list."] = " (등록되지 않음)"
    KO[" |cff808080(off)|r"] = " |cff808080(꺼짐)|r"
    KO[") is on the list."] = "): 목록에 등록했습니다."
    KO["Mob ID "] = "NPC ID "
    KO["MobSpot looks for mobs, not players."] = "플레이어는 등록할 수 없습니다. NPC를 선택하세요."
    KO["MobSpot: Track/Untrack Target"] = "MobSpot: 대상 추적 등록/해제"
    KO["commands:"] = "명령어:"
    KO["looking for:"] = "감지할 NPC:"
    KO["minimap button hidden."] = "미니맵 버튼을 숨겼습니다."
    KO["minimap button shown."] = "미니맵 버튼을 표시했습니다."
    KO["mob ID "] = "NPC ID "
    KO["put the mob's name or ID after /ms add."] = "/ms add 뒤에 NPC 이름 또는 ID를 입력하세요."
    KO["scanning for your mobs."] = "등록한 NPC 감지를 시작합니다."
    KO["scanning is off."] = "NPC 감지를 중지합니다."
    KO["target a mob first, then press the key again to add it."] = "먼저 NPC를 선택한 뒤 단축키를 다시 누르면 등록됩니다."
    KO["the list is empty. Target a mob and type /ms target, or add one by name in /ms."] = "목록이 비어 있습니다. NPC를 선택하고 /ms target을 입력하거나 /ms 설정에서 이름으로 추가하세요."
    KO["there's no "] = "목록에 없음: "
end
-- MobSpot
-- Keeps a list of mobs to look for and alerts the player when one of them is close by.
--
-- Files, in load order (see the .toc):
--   Core.lua      namespace, saved settings, the mob list, slash command
--   Scan.lua      finding listed mobs: nameplates and the map's markers
--   Alert.lua     what the player sees and hears
--   Marker.lua    a marker over a listed mob's nameplate
--   Distance.lua  /ms distance, a test of how far the target is
--   Options.lua   Esc > Options > AddOns > MobSpot
--   Minimap.lua   minimap button and addon compartment entry

local ADDON_NAME, ns = ...

ns.ADDON_NAME = ADDON_NAME
ns.TITLE = "MobSpot"
ns.ICON = "Interface\\Icons\\Ability_Hunter_MarkedForDeath"
ns.PREFIX = "|cff33ff99MobSpot:|r "

function ns.Print(text)
	DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. text)
end

-- A line in chat only while /ms debug is on, for finding out what the game reports.
function ns.Debug(text)
	if ns.debug then DEFAULT_CHAT_FRAME:AddMessage("|cff808080MobSpot debug:|r " .. text) end
end

-- A value the addon can read: nil for the game's hidden ("secret") values, which can't be compared.
function ns.Plain(value)
	if issecretvalue and issecretvalue(value) then return nil end
	return value
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local DEFAULTS = {
	enabled = true,          -- scanning on or off
	mobs = {},               -- [lowercase name] = { name = "Shown name", npcID = number or nil, on = true }
	mapMarkers = true,       -- mobs the game marks on the map and minimap
	rares = false,           -- also every rare mob, listed or not
	playersEnemy = false,    -- also players of the other faction
	playersAttack = false,   -- also players the player can attack
	playersPvp = false,      -- those two also inside battlegrounds and arenas
	sound = "raidwarning",   -- a key of ns.SOUNDS
	playerSound = "alarm",   -- the same, for the enemy players alert
	radius = false,          -- the scan radius the player picked, in yards; false until they pick one
	nameplates = false,      -- true once the player had MobSpot turn on enemy nameplates
	alertEach = false,       -- every mob of the same name alerts on its own, not only the first
	screenText = true,       -- big message at the top of the screen
	keepMessage = false,     -- that message stays for as long as the mob is in range
	messageSpot = false,     -- { x, y } where the player dragged that message in Edit Mode
	chatLine = true,         -- a line in chat
	flash = true,            -- flash the screen edges, and the game's taskbar icon
	marker = true,           -- a marker over a listed mob's nameplate
	markerStyle = "skull",   -- a key of ns.MARKERS
	playerMarkerStyle = "cross", -- a key of ns.PLAYER_MARKERS, for enemy players
	markerSize = 34,         -- the marker's size
	markerMotion = "bob",    -- a key of ns.MOTIONS
	minimap = { hide = false, minimapPos = 120 },
}

local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = copy(v) end
	return out
end

local function load()
	local saved = type(MobSpotDB) == "table" and MobSpotDB or {}
	MobSpotDB = saved
	for key, value in pairs(DEFAULTS) do
		if saved[key] == nil then saved[key] = copy(value) end
	end
	for key in pairs(saved) do
		if DEFAULTS[key] == nil then saved[key] = nil end
	end
	for key, mob in pairs(saved.mobs) do
		if type(mob) ~= "table" or type(mob.name) ~= "string" then saved.mobs[key] = nil end
	end
	ns.db = saved
end

---------------------------------------------------------------------------
-- The mob list
---------------------------------------------------------------------------

local function keyOf(name)
	return strtrim(name or ""):lower()
end
ns.KeyOf = keyOf

-- The NPC ID in a creature's GUID ("Creature-0-1-2-3-<npcID>-..."), or nil for players and objects.
function ns.NpcID(guid)
	guid = ns.Plain(guid)
	if type(guid) ~= "string" then return end
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
	if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- Mobs sorted by name, for the options list and /ms list.
function ns.SortedMobs()
	local out = {}
	for key, mob in pairs(ns.db.mobs) do out[#out + 1] = { key = key, mob = mob } end
	table.sort(out, function(a, b) return a.key < b.key end)
	return out
end

function ns.MobCount()
	local n = 0
	for _ in pairs(ns.db.mobs) do n = n + 1 end
	return n
end

-- The list key of a listed mob with this name or NPC ID, or nil.
function ns.FindMob(name, npcID)
	local key = name and keyOf(name)
	if key and ns.db.mobs[key] then return key end
	if not npcID then return end
	for k, mob in pairs(ns.db.mobs) do
		if mob.npcID == npcID then return k end
	end
end

-- The NPC ID typed in the box or after /ms add ("1234"), or nil for a name.
function ns.TypedID(text)
	local id = tonumber(strtrim(text or ""):match("^%d+$"))
	if id and id > 0 then return id end
end

-- A mob's name from its NPC ID, read from the game's tooltip for it, or nil while the game
-- doesn't have it yet (it may have to ask the server first).
function ns.NpcName(npcID)
	if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return end
	local data = C_TooltipInfo.GetHyperlink(("unit:Creature-0-0-0-0-%d-0000000000"):format(npcID))
	local line = data and data.lines and data.lines[1]
	local name = line and ns.Plain(line.leftText)
	if type(name) ~= "string" or name == "" or name == RETRIEVING_DATA then return end
	return name
end

-- Gives a mob added by ID its name, once known: from the game's tooltip, or from the mob itself
-- when it's spotted. Returns the mob's list key, which changes with the name.
function ns.NameMob(key, name)
	local mob = ns.db.mobs[key]
	name = ns.Plain(name)
	if not (mob and mob.unnamed) then return key end
	if type(name) ~= "string" or name == "" then return key end
	local newKey = keyOf(name)
	ns.db.mobs[key] = nil
	if ns.db.mobs[newKey] then
		local listed = ns.db.mobs[newKey] -- already listed by name too: keep that one
		listed.npcID = listed.npcID or mob.npcID
	else
		mob.name, mob.unnamed = name, nil
		ns.db.mobs[newKey] = mob
	end
	ns.Fire("MobsChanged")
	return newKey
end

local LOOKUP_TRIES = { 1, 3, 10 } -- seconds after adding by ID to ask the tooltip again

local function nameLater(npcID)
	for _, delay in ipairs(LOOKUP_TRIES) do
		C_Timer.After(delay, function()
			local key = "#" .. npcID
			if ns.db.mobs[key] then ns.NameMob(key, ns.NpcName(npcID)) end
		end)
	end
end

-- Adds a mob by its NPC ID. Until its name is known it's listed as "Mob ID 1234", and it's spotted
-- by its ID all the same. Returns false when it's already listed.
function ns.AddMobByID(npcID)
	if ns.FindMob(nil, npcID) then return false end
	local name = ns.NpcName(npcID)
	if name then
		if ns.db.mobs[keyOf(name)] then -- listed by name without its ID yet
			ns.db.mobs[keyOf(name)].npcID = npcID
			ns.Fire("MobsChanged")
			return true
		end
		return ns.AddMob(name, npcID)
	end
	ns.db.mobs["#" .. npcID] = { name = KO["Mob ID "] .. npcID, npcID = npcID, on = true, unnamed = true }
	ns.Fire("MobsChanged")
	nameLater(npcID)
	return true
end

-- The options box and /ms add: a mob's name, or its NPC ID. Says in chat what happened; returns
-- true when the mob went on the list.
function ns.AddTyped(text)
	text = strtrim(text or "")
	if text == "" then return false end
	local id = ns.TypedID(text)
	if id then
		if ns.AddMobByID(id) then
			local key = ns.FindMob(nil, id)
			local mob = key and ns.db.mobs[key]
			ns.Print((mob and not mob.unnamed) and (mob.name .. " (ID " .. id .. KO[") is on the list."])
				or (KO["mob ID "] .. id .. KO[" is on the list. Its name shows once the game knows it."]))
			return true
		end
		ns.Print(KO["mob ID "] .. id .. KO[" is already on the list."])
		return false
	end
	if ns.AddMob(text) then
		ns.Print(text .. KO[" is on the list."])
		return true
	end
	ns.Print(text .. KO[" is already on the list."])
	return false
end

-- Adds a mob by name. Returns false when the name is empty or already listed.
function ns.AddMob(name, npcID)
	name = strtrim(name or "")
	local key = keyOf(name)
	if key == "" then return false end
	local mob = ns.db.mobs[key]
	if mob then
		mob.npcID = mob.npcID or npcID
		return false
	end
	ns.db.mobs[key] = { name = name, npcID = npcID, on = true }
	ns.Fire("MobsChanged")
	return true
end

function ns.RemoveMob(key)
	if not ns.db.mobs[key] then return false end
	ns.db.mobs[key] = nil
	ns.Fire("MobsChanged")
	return true
end

function ns.SetMobOn(key, on)
	local mob = ns.db.mobs[key]
	if not mob then return end
	mob.on = on
	ns.Fire("MobsChanged")
end

-- The keybind and /ms target: puts the current target on the list, or takes it off.
function ns.ToggleTarget()
	local name = ns.Plain(UnitName("target"))
	if ns.Plain(UnitExists("target")) ~= true or not name then
		ns.Print(KO["target a mob first, then press the key again to add it."])
		return
	end
	if ns.Plain(UnitIsPlayer("target")) == true then
		ns.Print(KO["MobSpot looks for mobs, not players."])
		return
	end
	local key = ns.FindMob(name, ns.NpcID(UnitGUID("target")))
	if key then
		ns.RemoveMob(key)
		ns.Print(name .. KO[" is off the list."])
	else
		ns.AddMob(name, ns.NpcID(UnitGUID("target")))
		ns.Print(name .. KO[" is on the list. You'll get an alert when it's close by."])
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local handlers = {}
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
	for _, handler in ipairs(handlers[event]) do handler(...) end
end)

-- Runs `handler(...)` on every `event`.
function ns.On(event, handler)
	if not handlers[event] then
		handlers[event] = {}
		events:RegisterEvent(event)
	end
	table.insert(handlers[event], handler)
end

local listeners = {}

-- Runs `handler(...)` whenever the addon calls ns.Fire(name, ...).
function ns.Listen(name, handler)
	listeners[name] = listeners[name] or {}
	table.insert(listeners[name], handler)
end

function ns.Fire(name, ...)
	for _, handler in ipairs(listeners[name] or {}) do handler(...) end
end

ns.On("ADDON_LOADED", function(name)
	if name ~= ADDON_NAME then return end
	load()
	ns.Fire("Loaded")
end)

-- Mobs added by ID whose name wasn't known yet get another try each login.
ns.On("PLAYER_LOGIN", function()
	for _, mob in pairs(ns.db.mobs) do
		if mob.unnamed and mob.npcID then nameLater(mob.npcID) end
	end
end)

-- Turns scanning on or off, from the slash command, the options or the minimap button.
function ns.SetEnabled(on)
	ns.db.enabled = on
	ns.Fire("SettingChanged", "enabled")
	ns.Print(on and KO["scanning for your mobs."] or KO["scanning is off."])
end

---------------------------------------------------------------------------
-- Keybinds (Esc > Options > Keybindings > MobSpot)
---------------------------------------------------------------------------

BINDING_CATEGORY_MOBSPOT = "MobSpot" -- its own section on the Keybindings page
ns.BIND_SECTION = BINDING_CATEGORY_MOBSPOT
BINDING_NAME_MOBSPOT_TOGGLETARGET = KO["MobSpot: Track/Untrack Target"]

-- The key bound to a keybind, as the game writes it ("SHIFT-K"), or nil.
function ns.BoundKey(binding)
	local key = GetBindingKey(binding)
	return key and GetBindingText(key, "KEY_") or nil
end
ns.BIND_ADD = "MOBSPOT_TOGGLETARGET"

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------

local function help()
	ns.Print(KO["commands:"])
	print(KO["  /ms - options"])
	print(KO["  /ms on | off - scan for your mobs, or stop"])
	print(KO["  /ms target - add your target to the list, or take it off"])
	print(KO["  /ms add <name or ID> - add a mob by name or NPC ID"])
	print(KO["  /ms remove <name or ID> - take a mob off the list"])
	print(KO["  /ms list - show the list"])
	print(KO["  /ms test - show a test alert"])
	print("  /ms distance - test how far your target is and whether its nameplate shows")
	print(KO["  /ms minimap - show or hide the minimap button"])
end

local function list()
	local mobs = ns.SortedMobs()
	if #mobs == 0 then
		ns.Print(KO["the list is empty. Target a mob and type /ms target, or add one by name in /ms."])
		return
	end
	ns.Print(KO["looking for:"])
	for _, entry in ipairs(mobs) do
		print("  " .. entry.mob.name .. (entry.mob.on and "" or KO[" |cff808080(off)|r"]))
	end
end

SLASH_MOBSPOT1 = "/mobspot"
SLASH_MOBSPOT2 = "/ms"
SlashCmdList.MOBSPOT = function(msg)
	msg = strtrim(msg or "")
	local command, rest = msg:match("^(%S*)%s*(.-)$")
	command = command:lower()
	if command == "" or command == "options" or command == "config" then
		ns.OpenOptions()
	elseif command == "on" or command == "off" then
		ns.SetEnabled(command == "on")
	elseif command == "target" then
		ns.ToggleTarget()
	elseif command == "add" then
		if rest == "" then
			ns.Print(KO["put the mob's name or ID after /ms add."])
		else
			ns.AddTyped(rest)
		end
	elseif command == "remove" then
		local id = ns.TypedID(rest)
		local key = id and ns.FindMob(nil, id) or keyOf(rest)
		local mob = ns.db.mobs[key]
		if mob and ns.RemoveMob(key) then
			ns.Print(mob.name .. KO[" is off the list."])
		else
			ns.Print(KO["there's no "] .. rest .. KO[" on the list."])
		end
	elseif command == "list" then
		list()
	elseif command == "test" then
		ns.TestAlert()
	elseif command == "distance" or command == "range" then
		ns.TestDistance()
	elseif command == "debug" then
		ns.debug = not ns.debug
		ns.Print(ns.debug and "debug lines are on until you reload or type /ms debug again." or "debug lines are off.")
	elseif command == "minimap" then
		ns.SetMinimapShown(ns.db.minimap.hide)
		ns.Print(ns.db.minimap.hide and KO["minimap button hidden."] or KO["minimap button shown."])
	else
		help()
	end
end
