-- WoWForeverGPT: talk to local coding agents (Claude Code, Codex, Grok) from inside WoW,
-- without reloading.
--
-- The WoW sandbox has no network and no file reads at runtime. Two doors remain open:
--
--   OUT ("pixel" mode): pending messages are drawn as a strip of colored squares in
--        the top-left corner of the screen until the bridge acknowledges them.
--        bridge.js screen-captures that corner and decodes it. Nothing touches the game.
--   IN:  load-on-demand addons read their files from disk at the moment they load.
--        The bridge writes the latest replies for every chat into a pool of pre-made
--        slot addons (WoWForeverGPT_S001..S200); we load a fresh slot from a timer.
--        Each slot is single-use per session; a /reload frees them all.
--   Fallback ("reload" mode): SavedVariables + Inbox.lua, a ReloadUI() per step.
--
-- Chats: each chat is its own agent session (like a separate terminal) with its own
-- folder, agent, history and pending message. The bridge runs them in parallel.
-- Everything here is plain addon API. No automation, no memory reading.

local ADDON_NAME = ...
local WoWForeverGPT = {}
_G.WoWForeverGPT = WoWForeverGPT
local Codec = WoWForeverGPT_Codec
local TextFormat = WoWForeverGPT_Text
local MapLinks = WoWForeverGPT_MapLinks
local EntityLinks = WoWForeverGPT_EntityLinks

-- 제품 이름은 연결 모델과 분리한다. 답변 말풍선의 모델 이름은
-- ReplyAgentName에서 실제 연결 정보를 표시하므로 이 상수로 덮어쓰지 않는다.
local APP_NAME = "와우 AI"

local DEFAULT_CWD = "" -- empty = the bridge's configured defaultCwd
local MAX_HISTORY = 200
local MAX_CHATS = 16

local SLOT_COUNT = 200
local SLOT_PREFIX = "WoWForeverGPT_S"
local ACT_MAX = 60 -- heartbeat files per message (act/NNN/01..60.wav)
local PRESENCE_MAX = 2000 -- presence/0001..2000.wav, one flipped by the bridge every 30 s
local STRIP_TRIES = 3 -- re-show an unacknowledged message this many times before falling back
local CELL, CELLS_PER_ROW, MAX_ROWS = 4, 200, 48
local STRIP_SECONDS = 40 -- max per message; it leaves the strip as soon as the bridge acknowledges
local POLL_SCHEDULE = { 5, 10, 16, 24, 34, 46, 60, 80, 100, 130, 160, 200, 240, 300 }
local POLL_TAIL = 60
local TICK_SECONDS = 2
local CONNECT_WAIT = 15 -- seconds the Connect button waits for the bridge before giving up
local PRESENCE_SILENCE_SECONDS = 60 -- 소리 신호가 멈추면 상태등이 꺼지기 전에 슬롯으로 재확인
local IDLE_POLL_SECONDS = 600 -- without the sound channel, spend one slot this often while idle to check the bridge
local RS, US = "\30", "\31" -- record / unit separators in the strip payload

local db
local ui = {}
-- Transport state for this UI session. outbound[id] = { chat, cwd, flags, text, sentAt, acked }
local run = { outbound = {} }

-- Shared window backdrop. Declared up here because ShowCopy (rendering section)
-- uses it too: a later `local` would be invisible there and resolve to a nil global.
local BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- The assistant bubble is labelled with the agent that wrote it (see AgentName).
local ROLE_STYLE = {
	user      = { label = "나",    color = { 0.49, 0.78, 1.00 }, bg = { 0.25, 0.45, 0.75, 0.16 } },
	assistant = { label = "AI",     color = { 1.00, 0.82, 0.25 }, bg = { 0.85, 0.70, 0.30, 0.10 } },
	system    = { label = "안내", color = { 0.62, 0.62, 0.62 }, bg = { 0.50, 0.50, 0.50, 0.10 } },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function ToHex(s)
	return (s:gsub(".", function(c)
		return string.format("%02x", c:byte())
	end))
end

-- Record fields use control characters as separators, so keep them out of the wire format.
local function Wire(s)
	local value = tostring(s or "")
	return (value:gsub("[\30\31]", " "))
end

-- EditBoxes do not render UI escape sequences, so just make pipes harmless.
local function Display(s)
	return (tostring(s or ""):gsub("|", "¦"))
end

local function Trim(s)
	-- C 로캘의 %s 분류 대신 ASCII 공백만 제거해 UTF-8 한글 바이트를 보존한다.
	return (s:gsub("^[ \9-\13]+", ""):gsub("[ \9-\13]+$", ""))
end

local function UpperAsciiFirst(text)
	-- string.upper는 게임 로캘에 따라 0x80 이상의 바이트까지 바꿀 수 있다.
	-- 첫 문자가 영문 소문자일 때만 ASCII 코드로 대문자를 만들어 한글/이모지를 보존한다.
	return (text:gsub("^[a-z]", function(ch) return string.char(ch:byte() - 32) end))
end

local function Utf8Prefix(text, maxBytes)
	-- 전송 길이 제한은 바이트 단위지만, 자르는 위치는 반드시 UTF-8 문자 사이여야 한다.
	local cut = math.min(#text, math.max(0, maxBytes))
	while cut > 0 do
		local following = text:byte(cut + 1)
		if not following or following < 128 or following > 191 then break end
		cut = cut - 1
	end
	return text:sub(1, cut)
end

local function IsValidUtf8(text)
	if type(text) ~= "string" then return false end
	local position = 1
	for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		if text:sub(position, position + #ch - 1) ~= ch then return false end
		local lead, second = ch:byte(1, 2)
		local length = lead < 128 and 1 or (lead < 224 and 2 or (lead < 240 and 3 or 4))
		if #ch ~= length then return false end
		if lead == 224 and second < 160 or lead == 237 and second >= 160
			or lead == 240 and second < 144 or lead == 244 and second > 143 then return false end
		position = position + #ch
	end
	return position == #text + 1
end

local function TrimAsciiPunctuation(text)
	local function punctuation(b)
		return b and (b >= 33 and b <= 47 or b >= 58 and b <= 64
			or b >= 91 and b <= 96 or b >= 123 and b <= 126)
	end
	local first, last = 1, #text
	while first <= last and punctuation(text:byte(first)) do first = first + 1 end
	while last >= first and punctuation(text:byte(last)) do last = last - 1 end
	return text:sub(first, last)
end

local function FmtDur(sec)
	sec = math.floor(sec or 0)
	if sec < 60 then return sec .. "초" end
	if sec < 3600 then return math.floor(sec / 60) .. "분 " .. string.format("%02d", sec % 60) .. "초" end
	return math.floor(sec / 3600) .. "시간 " .. string.format("%02d", math.floor(sec / 60) % 60) .. "분"
end

-- Last path component of a folder, for labels.
local function FolderName(cwd)
	local name = tostring(cwd or ""):gsub("[\\/]+$", ""):match("([^\\/]+)$")
	return name or ""
end

-- The folder a chat works in: its own, or the bridge's default (the folder the
-- bridge was started from), which the bridge reports in every slot file.
local function ChatFolder(c)
	if c and c.cwd ~= "" then return c.cwd end
	return run.bridgeCwd or ""
end

-- Agents are named by id as the bridge knows them ("claude", "codex", "grok");
-- the bridge lists the ones it has, and its default, in every slot file. A chat
-- with no agent of its own runs on the bridge's default.
local AGENT_NAMES = { gpt = "GPT", claude = "Claude", codex = "Codex", grok = "Grok", agy = "Antigravity", hermes = "Hermes" }

local function AgentName(id)
	id = tostring(id or "")
	if id == "" then return "AI" end
	return AGENT_NAMES[id] or UpperAsciiFirst(id)
end

local function ChatAgent(c)
	if c and c.agent and c.agent ~= "" then return c.agent end
	-- AI를 따로 고르지 않은 대화는 마지막으로 고른 AI를 따른다(새 대화·다른 대화에서도 유지).
	-- 고른 적이 없으면 브리지 기본값을 쓴다.
	local last = db and db.settings and db.settings.lastAgent
	if last and last ~= "" then
		if not run.bridgeAgents then return last end
		for _, a in ipairs(run.bridgeAgents) do if a == last then return last end end   -- (Contains는 아래에 정의됨)
	end
	return run.bridgeAgent or "claude"
end

-- 회사(AI)별 선택 가능한 모델. 브리지가 슬롯 파일의 models로 알려 주며, 아직
-- 연결 전이거나 이전 브리지라면 아래 기본 목록을 쓴다. 실제 허용 여부는 브리지가 다시 확인한다.
local FALLBACK_MODELS = {
	gpt = { company = "OpenAI", default = "gpt-6.1-sol", options = {
		{ id = "gpt-6.1-sol", label = "Sol 6.1" },
	} },
	claude = { company = "Anthropic", default = "claude-sonnet-5-5", options = {
		{ id = "claude-fable-5-2", label = "Fable 5.2" },
		{ id = "claude-opus-5-5", label = "Opus 5.5" },
		{ id = "claude-sonnet-5-5", label = "Sonnet 5.5" },
		{ id = "claude-haiku-5-5", label = "Haiku 5.5" },
	} },
}

local function ModelsFor(agent)
	local m = run.bridgeModels and run.bridgeModels[agent]
	if type(m) == "table" and type(m.options) == "table" and #m.options > 0 then return m end
	return FALLBACK_MODELS[agent]
end

local function ModelLabel(agent, id)
	if not id or id == "" then return nil end
	local m = ModelsFor(agent)
	for _, o in ipairs(m and m.options or {}) do
		if o.id == id then return o.label or id end
	end
	return id
end

-- 이 대화에 적용될 모델 ID: 그 회사에서 사용자가 고른 모델, 목록에 없으면 회사 기본값.
local function ChatModel(c)
	local agent = ChatAgent(c)
	local m = ModelsFor(agent)
	if not m then return nil end
	local chosen = db and db.settings.models and db.settings.models[agent]
	for _, o in ipairs(m.options) do
		if o.id == chosen then return chosen end
	end
	return m.default
end

-- 화면에는 회사 이름(GPT/Claude) 대신 짧은 모델 이름만 쓴다. 예: "Opus 5.5", "Sol 6.1"
-- 이 대화에 다음 질문부터 적용될 모델의 이름.
local function ChatAgentName(c)
	local agent = ChatAgent(c)
	return ModelLabel(agent, ChatModel(c)) or AgentName(agent)
end

-- 답변 이름표: 실제로 답한 모델. 모델 정보가 없는 이전 기록은 당시 쓰던 회사 기본 모델로 표시한다.
local function ReplyAgentName(c, agent, model)
	if not agent or agent == "" then return ChatAgentName(c) end
	local m = ModelsFor(agent)
	return ModelLabel(agent, model or (m and m.default)) or AgentName(agent)
end

local function Contains(list, v)
	for _, x in ipairs(list or {}) do
		if x == v then return true end
	end
	return false
end

-- First few words of a message, as a chat title.
local function ShortTitle(text)
	local chars = {}
	for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		chars[#chars + 1] = ch
		if #chars >= 24 then break end
	end
	return table.concat(chars)
end

local function AutoTitle(text)
	local words = {}
	for w in tostring(text or ""):gmatch("[^ \9-\13]+") do
		w = TrimAsciiPunctuation(w)
		if w ~= "" then
			table.insert(words, w)
			if #words >= 5 then break end
		end
	end
	local title = table.concat(words, " ")
	title = ShortTitle(title)
	if title == "" then return nil end
	return UpperAsciiFirst(title)
end

local function RepairChatTitle(chat)
	-- 과거 버전이 망가뜨린 제목만 첫 질문에서 복구한다. 정상적으로 바꾼 제목과 대화는 유지한다.
	local name = chat.name
	if IsValidUtf8(name) and not name:find("\239\191\189", 1, true) then return false end
	for _, message in ipairs(chat.history or {}) do
		if message.role == "user" and IsValidUtf8(message.text) then
			local restored = AutoTitle(message.text)
			if restored then chat.name = restored; return true end
		end
	end
	return false
end

local function NewId()
	return string.format("%x%04x", time() % 0xFFFFFF, math.random(0, 0xFFFF))
end

local function FindChat(id)
	for i, c in ipairs(db.chats) do
		if c.id == id then return c, i end
	end
end

local function ActiveChat()
	return FindChat(db.activeChat)
end

local function AddChat(name, cwd)
	if #db.chats >= MAX_CHATS then return nil end
	local current = ActiveChat()
	local c = {
		id = NewId(),
		name = name or ("질문 " .. (#db.chats + 1)),
		cwd = cwd or (current and current.cwd) or DEFAULT_CWD,
		agent = (current and current.agent) or "",
		history = {},
		unread = 0,
		created = time(),
	}
	table.insert(db.chats, c)
	return c
end

local function AnyPending()
	for _, c in ipairs(db.chats) do
		if c.pendingId then return true end
	end
	return false
end

local EFFORT_LABEL = { low = "낮음", medium = "보통", high = "높음" }
local NEXT_EFFORT = { low = "medium", medium = "high", high = "low" }

local function InitDB()
	WoWForeverGPTDB = WoWForeverGPTDB or {}
	db = WoWForeverGPTDB
	db.settings = db.settings or {}
	local s = db.settings
	if not EFFORT_LABEL[s.effort] then s.effort = "low" end
	-- 회사(AI)별로 마지막에 고른 모델 ID. 예: { gpt = "gpt-6.1-sol", claude = "claude-opus-5-5" }
	if type(s.models) ~= "table" then s.models = {} end
	if s.autoRefresh == nil then s.autoRefresh = true end
	if s.signal == nil then s.signal = true end
	-- 이전 버전은 매 로그인 때 정보를 강제로 껐다. 이번 요청에 맞춰 한 번 켠 뒤,
	-- 이후 /wow-ai context off로 사용자가 끈 선택은 다시 덮어쓰지 않는다.
	if s.characterContextVersion ~= 1 then
		s.context = true
		s.characterContextVersion = 1
	elseif s.context == nil then s.context = true end
	s.echo = "off"
	s.mode = s.mode or "pixel"
	s.interval = s.interval or 20
	s.cwd = s.cwd or DEFAULT_CWD
	-- 새 컴팩트 배치로 한 번만 전환한다. 이후 사용자가 조절한 크기/목록 상태는 계속 유지한다.
	if s.compactVersion ~= 1 then
		s.width = math.min(s.width or 460, 460)
		s.height = math.min(s.height or 310, 310)
		s.sidebarOpen = false
		s.compactVersion = 1
	end
	s.width = math.max(380, s.width or 460)
	s.height = math.max(260, s.height or 310)
	db.lastSeq = db.lastSeq or 0
	-- Chats deleted in game that the bridge hasn't confirmed forgetting yet.
	db.forget = db.forget or {}
	-- Identifies this counter's lifetime. If the saved data is ever reset, a new
	-- session lets the bridge tell "message #1 again" from "message #1, already done".
	if not db.session then
		db.session = string.format("%x%04x%04x", time() % 0xFFFFFF, math.random(0, 0xFFFF), math.random(0, 0xFFFF))
	end
	if not db.chats then
		-- Migrate the single-chat layout into the first chat.
		db.chats = {}
		local c = {
			id = NewId(),
			name = "질문 1",
			cwd = s.cwd,
			history = db.history or {},
			pendingId = db.pendingId,
			unread = db.unread or 0,
			draft = db.draft,
			created = time(),
		}
		table.insert(db.chats, c)
		db.activeChat = c.id
		db.history, db.pendingId, db.unread, db.draft = nil, nil, nil, nil
	end
	if #db.chats == 0 then AddChat() end
	if not FindChat(db.activeChat) then db.activeChat = db.chats[1].id end
	-- Chats from before agents had names: replies were stored with role "claude".
	for _, c in ipairs(db.chats) do
		c.agent, c.cwd = "", ""
		for _, m in ipairs(c.history or {}) do
			if m.role == "claude" then m.role, m.agent = "assistant", m.agent or "claude" end
		end
		RepairChatTitle(c)
	end
end

local function AddHistory(chat, role, text, id, denied, agent, macros, model)
	table.insert(chat.history, { role = role, text = text, id = id, t = time(), denied = denied, agent = agent, macros = macros, model = model })
	while #chat.history > MAX_HISTORY do
		table.remove(chat.history, 1)
	end
end

local function SlotName(i)
	return string.format("%s%03d", SLOT_PREFIX, i)
end

local function SlotNumber(id)
	return ((id - 1) % SLOT_COUNT) + 1
end

---------------------------------------------------------------------------
-- Reload plumbing (fallback path)
---------------------------------------------------------------------------

local function SafeReload()
	if InCombatLockdown() then
		WoWForeverGPT.reloadAfterCombat = true
		if ui.status then
			ui.status:SetText("전투가 끝나면 UI를 새로고침합니다.")
		end
		return
	end
	ReloadUI()
end

-- ReloadUI() only works from a hardware event (a keypress or click), never from
-- a timer. So the automatic reload piggybacks on the player's own next keypress
-- once the interval has elapsed. The key still reaches the game normally.
local keyCatcher = CreateFrame("Frame", "WoWForeverGPTKeyCatcher", UIParent)
keyCatcher:Hide()
keyCatcher:EnableKeyboard(true)
keyCatcher:SetScript("OnKeyDown", function(self, key)
	if db and AnyPending() and db.settings.autoRefresh
		and GetTime() >= (WoWForeverGPT.nextAutoRefresh or 0)
		and not InCombatLockdown() then
		self:Hide()
		ReloadUI()
	end
end)

-- Arm the keypress reload. In pixel mode this is only used once the slot pool
-- is exhausted (a reload frees every slot) or the slots are not installed.
function WoWForeverGPT.ArmAutoRefresh()
	keyCatcher:Hide()
	if not AnyPending() or not db.settings.autoRefresh then return end
	if db.settings.mode == "pixel" and not (run.slotsExhausted or run.slotsMissing or run.pixelFailed) then return end
	-- Propagation can't be changed in combat. Never show the catcher without it,
	-- or it would eat every keypress. PLAYER_REGEN_ENABLED re-arms after combat.
	if not keyCatcher.propagates then
		if InCombatLockdown() or not keyCatcher.SetPropagateKeyboardInput then return end
		keyCatcher:SetPropagateKeyboardInput(true)
		keyCatcher.propagates = true
	end
	WoWForeverGPT.nextAutoRefresh = GetTime() + db.settings.interval
	keyCatcher:Show()
end

---------------------------------------------------------------------------
-- Pixel strip (out)
---------------------------------------------------------------------------

local strip
local cellPool = {}

local function EnsureStrip()
	if strip then return strip end
	strip = CreateFrame("Frame", "WoWForeverGPTStrip", UIParent)
	strip:SetFrameStrata("TOOLTIP")
	strip:SetFrameLevel(10000)
	-- Scale so that one UI unit is exactly one physical pixel (see Blizzard's PixelUtil).
	local physH = 1080
	if GetPhysicalScreenSize then
		local _, h = GetPhysicalScreenSize()
		physH = h or physH
	end
	if strip.SetIgnoreParentScale then strip:SetIgnoreParentScale(true) end
	strip:SetScale(768 / physH)
	strip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
	strip:SetSize(CELLS_PER_ROW * CELL, MAX_ROWS * CELL)
	strip:Hide()
	return strip
end

local function HideStrip()
	if strip then strip:Hide() end
	run.stripShown = nil
end

local function ShowStrip(id, payload)
	local cells = Codec.Encode(id % 65536, payload)
	local s = EnsureStrip()
	local rows = math.ceil(#cells / CELLS_PER_ROW)
	local total = rows * CELLS_PER_ROW
	for i = 1, total do
		local t = cellPool[i]
		if not t then
			t = s:CreateTexture(nil, "OVERLAY")
			t:SetSize(CELL, CELL)
			local c = (i - 1) % CELLS_PER_ROW
			local r = math.floor((i - 1) / CELLS_PER_ROW)
			t:SetPoint("TOPLEFT", s, "TOPLEFT", c * CELL, -r * CELL)
			cellPool[i] = t
		end
		local cr, cg, cb = Codec.CellColor(cells[i] or 0)
		t:SetColorTexture(cr, cg, cb, 1)
		t:Show()
	end
	for i = total + 1, #cellPool do
		cellPool[i]:Hide()
	end
	s:Show()
	run.stripShown = true
end

-- Record: session, chat, id, cwd, flags, name, [context,] text. Several records
-- per frame. The context field is only present when the flags carry "c", so the
-- bridge can tell it from a separator inside the text.
-- SC1 고정 사전은 bridge/context-codec.js와 같은 순서다. 기존 번호의 뜻은 바꾸지 않는다.
-- 수집 정보나 잘림 예산을 바꾸지 않고, 전송 직전에 반복 문구만 짧게 치환한다.
-- 사용자 이름/아이템에 포함된 ~를 먼저 이스케이프하여 코드처럼 보이는 실제 문자열도 보존한다.
local CONTEXT_WORDS = {
	"Character: level=", "; class=", "; race=", "; faction=", "; name=",
	"Game: World of Warcraft Forever; client=", "; build=", "Location: ",
	"Talents (points spent): ", "Purchased talents: ", "Talents: not available; do not infer a specialization",
	"Current primary stats: ", "Position: map=",
	"Equipped (names/IDs only; full item stats are not attached):",
	": empty or unreadable", "Selected quest: #", "Professions: ",
	"[Snapshot truncated: omitted fields are unknown.]", "none (0 spent)", "not readable", " [partial]",
	"주무기: ", "보조무기: ", "원거리: ", "가슴: ", "다리: ", "머리: ", "어깨: ",
	"손목: ", "손: ", "허리: ", "발: ", "반지1: ", "반지2: ", "장신구1: ", "장신구2: ", "목: ", "등: ",
}
-- SC2는 SC1의 번호를 유지하고 새로 수집하는 대상·스킬북 문구만 뒤에 추가한다.
-- SC1/원문도 계속 지원하므로 /reload 전후 패킷이 섞여도 복원할 수 있다.
local CONTEXT_EXTRA = {
	"Target: ", "; level=", "; type=", "Quest objective: ",
	"Ranged weapon: ", "Ranged tooltip: ",
	"Known spells (partial; omission does not mean unlearned): ", "Known spells: not readable",
}
local CONTEXT_CODES = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
local REPEAT_CODES = CONTEXT_CODES .. "-_"

local function PackDictionary(text, extended)
	local packed = text:gsub("~", "~_")
	-- 긴 추가 문구를 먼저 치환하여 그 안의 "not readable" 같은 SC1 단어가
	-- 부분 치환되어 더 큰 문구의 압축 기회를 없애지 않도록 한다.
	if extended then
		for i, word in ipairs(CONTEXT_EXTRA) do
			local code = #CONTEXT_WORDS + i
			packed = packed:gsub(word:gsub("(%W)", "%%%1"), "~" .. CONTEXT_CODES:sub(code, code))
		end
	end
	for i, word in ipairs(CONTEXT_WORDS) do
		packed = packed:gsub(word:gsub("(%W)", "%%%1"), "~" .. CONTEXT_CODES:sub(i, i))
	end
	return packed
end

local function PackRepeats(text)
	-- 패킷 안에서만 앞서 나온 문자열을 참조한다. 이전 질문/캐릭터/접수 ACK에
	-- 의존하지 않으므로 재접속·브리지 재시작·요청 재정렬 시에도 독립 복원된다.
	-- ^ + 거리 2자리 + 길이 1자리(모두 64진수): 거리 1..4096, 길이 5..68.
	-- 원문의 ^는 ^^로 이스케이프한다. 한글/이모지의 중간 바이트는 절대 자르지 않는다.
	local n, parts, positions, pos = #text, {}, {}, 1
	local function Boundary(at)
		local b = text:byte(at)
		return not b or b < 128 or b >= 192
	end
	while pos <= n do
		local best, distance = 0, 0
		local candidates = positions[text:sub(pos, pos + 4)]
		if candidates then
			for k = #candidates, 1, -1 do
				local previous = candidates[k]
				if pos - previous > 4096 then break end
				local length = 0
				while length < 68 and pos + length <= n and text:byte(previous + length) == text:byte(pos + length) do
					length = length + 1
				end
				while length > 0 and not Boundary(pos + length) do length = length - 1 end
				if length >= 5 and length > best then best, distance = length, pos - previous end
			end
		end
		local consumed
		if best >= 5 then
			local d = distance - 1
			parts[#parts + 1] = "^" .. REPEAT_CODES:sub(math.floor(d / 64) + 1, math.floor(d / 64) + 1)
				.. REPEAT_CODES:sub(d % 64 + 1, d % 64 + 1) .. REPEAT_CODES:sub(best - 4, best - 4)
			consumed = best
		else
			consumed = 1
			while pos + consumed <= n and not Boundary(pos + consumed) do consumed = consumed + 1 end
			local literal = text:sub(pos, pos + consumed - 1)
			parts[#parts + 1] = literal == "^" and "^^" or literal
		end
		-- 탐색 후보는 같은 5바이트 접두사마다 최근 16개로 제한한다.
		-- 반복이 많은 툴팁에서도 질문 전송 시 CPU 사용이 과도하게 늘지 않는다.
		for at = pos, pos + consumed - 1 do
			if Boundary(at) and at + 4 <= n then
				local key = text:sub(at, at + 4)
				local list = positions[key] or {}
				positions[key] = list
				list[#list + 1] = at
				if #list > 16 then table.remove(list, 1) end
			end
		end
		pos = pos + consumed
	end
	return table.concat(parts)
end

local function PackContext(text)
	if type(text) ~= "string" or text == "" then return text end
	-- 짧은 원문이나 압축하기 어려운 값은 커지지 않도록 가장 작은 형식을 선택한다.
	local sc1 = "SC1\n" .. PackDictionary(text, false)
	local best = sc1
	-- 원문이 버전 접두사로 시작하면 반드시 감싸서 압축 형식으로 오인되지 않게 한다.
	if not text:match("^SC[12]\n") and #text < #best then best = text end
	local sc2 = "SC2\n" .. PackRepeats(PackDictionary(text, true))
	if #sc2 < #best then best = sc2 end
	return best
end

local function RecordFor(id, rec)
	local flags = Wire(rec.flags)
	local fields = { Wire(db.session), Wire(rec.chat), tostring(id), Wire(rec.cwd), flags, Wire(rec.name) }
	if rec.ctx ~= nil then
		fields[5] = flags == "" and "c" or (flags .. ";c")
		-- 재표시 때 같은 스냅샷을 다시 압축하지 않는다. rec.ctx는 이 요청의 고정 값이다.
		if rec.packedCtx == nil then rec.packedCtx = PackContext(rec.ctx) end
		table.insert(fields, Wire(rec.packedCtx))
	end
	table.insert(fields, Wire(rec.text))
	return table.concat(fields, US)
end

-- Redraw the strip from every outbound message the bridge hasn't acknowledged.
local function RefreshStrip()
	local ids = {}
	for id, rec in pairs(run.outbound) do
		if not rec.acked then table.insert(ids, id) end
	end
	if #ids == 0 then
		HideStrip()
		return
	end
	table.sort(ids)
	-- Newest first; drop the oldest if the frame would overflow.
	local parts, size, latest = {}, 0, ids[#ids]
	for i = #ids, 1, -1 do
		local r = RecordFor(ids[i], run.outbound[ids[i]])
		if size + #r + 1 > Codec.MAX_PAYLOAD then break end
		table.insert(parts, 1, r)
		size = size + #r + 1
	end
	ShowStrip(latest, table.concat(parts, RS))
end

---------------------------------------------------------------------------
-- Signals and slots (in)
---------------------------------------------------------------------------

-- Optional cheap poll: an empty .wav won't play, a valid one will. The bridge
-- fills sig/NNN.wav when reply NNN is ready. Self-disables if it misbehaves.
local signalAvailable = type(PlaySoundFile) == "function"
local signalStats = { checks = 0, hits = 0, lastHit = nil }

local function SoundValid(path)
	if not signalAvailable or not db.settings.signal then return false end
	signalStats.checks = signalStats.checks + 1
	local ok, willPlay, handle = pcall(PlaySoundFile, path, "Master")
	if not ok then
		signalAvailable = false
		signalStats.error = tostring(willPlay)
		return false
	end
	if willPlay and handle then pcall(StopSound, handle) end
	if willPlay then
		signalStats.hits = signalStats.hits + 1
		signalStats.lastHit = GetTime()
	end
	return willPlay and true or false
end

local function CheckSignal(kind, id)
	if run.signalUnreliable then return false end
	return SoundValid(string.format("Interface\\AddOns\\WoWForeverGPT\\%s\\%03d.wav", kind, SlotNumber(id)))
end

-- Heartbeat: the bridge flips act/NNN/kk.wav for the k-th action of message NNN.
local function ActPath(id, k)
	return string.format("Interface\\AddOns\\WoWForeverGPT\\act\\%03d\\%02d.wav", SlotNumber(id), k)
end

local function StartActivity(chat, id)
	local a = { next = 1, count = 0, startedAt = GetTime() }
	-- The bridge can't have written anything yet, so a valid first file means the
	-- client cached this slot number's files from an earlier use: don't trust them.
	if SoundValid(ActPath(id, 1)) then a.unreliable = true end
	run.act = run.act or {}
	run.act[chat.id] = a
end

-- Returns true if the counter moved.
local function PollActivity(chat)
	local a = run.act and run.act[chat.id]
	if not a or a.unreliable or not chat.pendingId then return false end
	local moved = false
	for _ = 1, 3 do
		if a.next > ACT_MAX then break end
		if not SoundValid(ActPath(chat.pendingId, a.next)) then break end
		a.count = a.count + 1
		a.next = a.next + 1
		a.last = GetTime()
		moved = true
	end
	return moved
end

-- Bridge presence. Evidence the bridge is alive comes from several places:
-- presence beats, acks, slot data (which carries the bridge's clock), replies.
local function NotedBridge(at)
	at = at or GetTime()
	if not run.bridgeSeen or at > run.bridgeSeen then run.bridgeSeen = at end
	run.pixelFailed = nil
end

local function PresencePath(k)
	return string.format("Interface\\AddOns\\WoWForeverGPT\\presence\\%04d.wav", k)
end

-- Valid presence files form a prefix 1..k, so a binary search finds the head.
local function FindPresenceHead()
	local lo, hi = 0, PRESENCE_MAX
	while lo < hi do
		local mid = math.ceil((lo + hi) / 2)
		if SoundValid(PresencePath(mid)) then lo = mid else hi = mid - 1 end
	end
	return lo
end

local function PollPresence()
	if not signalAvailable or not db.settings.signal then return end
	run.presence = run.presence or { last = FindPresenceHead() }
	local p = run.presence
	for _ = 1, 3 do
		local k = (p.last % PRESENCE_MAX) + 1
		if not SoundValid(PresencePath(k)) then break end
		p.last = k
		p.beats = (p.beats or 0) + 1
		p.lastBeatAt = GetTime()
		run.presenceFallback = nil
		NotedBridge()
	end
end

-- Whether the 30-second presence beats can reach us at all. When they can't
-- (self-test failed, or signal checks turned off), the only evidence of the
-- bridge is a slot read: the idle poll below and the replies themselves.
local function PresenceWorks()
	return signalAvailable and db ~= nil and db.settings.signal and not run.presenceFallback
end

-- Returns state ("ok" | "stale" | "down" | "unknown"), a color and a description.
-- With presence beats the bridge is heard from every 30 s, so 90 s of silence is
-- suspicious. Without them the addon only hears from it every IDLE_POLL_SECONDS,
-- so the windows have to be wider or the light could never stay green between
-- messages and every reply would be followed by a Reconnect.
function WoWForeverGPT.BridgeState()
	local seen = run.bridgeSeen
	if not seen then
		return "unknown", 0.6, 0.6, 0.6, "연결되지 않음"
	end
	local age = GetTime() - seen
	local okFor, staleFor = 90, 300
	if not PresenceWorks() then
		okFor, staleFor = IDLE_POLL_SECONDS + 120, IDLE_POLL_SECONDS * 2 + 120
	end
	if age < okFor then
		return "ok", 0.2, 0.9, 0.3, "연결됨 · 마지막 확인 " .. FmtDur(age) .. " 전"
	elseif age < staleFor then
		return "stale", 0.95, 0.8, 0.2, "연결 확인 대기 · " .. FmtDur(age) .. " 경과"
	end
	return "down", 0.9, 0.25, 0.25, "연결이 끊겼습니다. 브리지를 확인하세요."
end

-- Same icons the friends list uses for online / away / busy / offline.
local STATE_ICON = {
	ok = "Interface\\FriendsFrame\\StatusIcon-Online",
	stale = "Interface\\FriendsFrame\\StatusIcon-Away",
	down = "Interface\\FriendsFrame\\StatusIcon-DnD",
	unknown = "Interface\\FriendsFrame\\StatusIcon-Offline",
}

function WoWForeverGPT.UpdateDot()
	local state, _, _, _, tip = WoWForeverGPT.BridgeState()
	if run.pixelFailed then state = "down" end
	if not signalAvailable and signalStats.selftest then
		tip = tip .. "\n(소리 파일 신호를 사용할 수 없음: " .. signalStats.selftest .. "; 응답 슬롯만 확인합니다.)"
	end
	for _, dot in ipairs({ ui.dot, ui.miniDot }) do
		if dot then
			dot:SetTexture(STATE_ICON[state] or STATE_ICON.unknown)
			dot.tip = tip
		end
	end
end

-- Connected = the bridge has been seen recently. In pixel mode, sending needs this;
-- until then the Connect button takes the Send button's place. The reload
-- transport has no idea whether the bridge is there, so it never gates.
function WoWForeverGPT.IsConnected()
	if not db or db.settings.mode ~= "pixel" then return true end
	return WoWForeverGPT.BridgeState() == "ok" and not run.pixelFailed
end

-- Connect button: say hello to the bridge (it acks, refreshes the slots and
-- offers a restore), ignoring SayHello's throttle so a click always does something.
function WoWForeverGPT.Connect()
	if db.settings.mode ~= "pixel" then
		SafeReload()
		return
	end
	run.lastHelloAt = nil
	run.pixelFailed = nil
	run.connectFailed = nil
	run.connectingAt = GetTime()
	WoWForeverGPT.SayHello()
end

-- One word for the connection state, so Tick can tell when it changed.
local function ConnectionKey()
	if WoWForeverGPT.IsConnected() then return "ok" end
	if run.connectingAt then return "connecting" end
	if run.connectFailed then return "failed" end
	return WoWForeverGPT.BridgeState()
end

-- Called every tick: time out a Connect attempt, and redraw when the state flips
-- (light, button, status line, placeholder) without redrawing every tick.
function WoWForeverGPT.CheckConnection()
	if run.connectingAt then
		if WoWForeverGPT.IsConnected() then
			run.connectingAt, run.connectFailed = nil, nil
			-- A message typed while disconnected goes out now, without a second click,
			-- as long as the same chat is still in front and free.
			local queued = run.sendOnConnect
			run.sendOnConnect = nil
			local c = queued and ActiveChat()
			if c and c.id == queued.chat and not c.pendingId then
				if ui.input and Trim(ui.input:GetText() or "") == queued.text then ui.input:SetText("") end
				WoWForeverGPT.Send(queued.text, queued.allow)
			end
		elseif GetTime() - run.connectingAt > CONNECT_WAIT then
			run.connectingAt, run.connectFailed = nil, true
			run.sendOnConnect = nil -- the text is still in the box
		end
	elseif run.connectFailed and WoWForeverGPT.IsConnected() then
		run.connectFailed = nil
	end
	local key = ConnectionKey()
	if key ~= run.connKey then
		run.connKey = key
		WoWForeverGPT.Render()
	end
end

-- Swap Send and Connect depending on the state; part of UpdateStatus.
function WoWForeverGPT.UpdateConnect()
	if not ui.connect or not ui.send then return end
	local connected = WoWForeverGPT.IsConnected()
	ui.send:SetShown(connected)
	ui.connect:SetShown(not connected)
	if connected then return end
	if run.connectingAt then
		ui.connect:SetText("연결 중…")
		ui.connect:Disable()
	else
		ui.connect:SetText(WoWForeverGPT.BridgeState() == "stale" and "다시 연결" or "연결")
		ui.connect:Enable()
	end
end

-- Prove the sound-file trick actually distinguishes empty from valid files on this
-- client before trusting it for presence, heartbeats and readiness signals.
local function SelfTestSignals()
	if not signalAvailable then
		signalStats.selftest = "PlaySoundFile 함수를 사용할 수 없음"
		return
	end
	local emptyLooksValid = SoundValid("Interface\\AddOns\\WoWForeverGPT\\ctl\\empty.wav")
	local validLooksValid = SoundValid("Interface\\AddOns\\WoWForeverGPT\\ctl\\valid.wav")
	if emptyLooksValid then
		signalAvailable = false
		signalStats.selftest = "빈 파일도 재생 가능한 것으로 감지됨"
	elseif not validLooksValid then
		signalAvailable = false
		signalStats.selftest = "정상 파일을 재생할 수 없음 (파일 인식을 위해 와우를 재시작하세요.)"
	else
		signalStats.selftest = "통과"
	end
end

local function ActivityLine(chat)
	local a = run.act and run.act[chat.id]
	local now = GetTime()
	local started = (a and a.startedAt) or run.sentAt or now
	local s = "처리 중 " .. FmtDur(now - started)
	if a and not a.unreliable then
		s = s .. " · 작업 " .. a.count .. "회"
		if a.last then
			local quiet = now - a.last
			s = s .. ", 마지막 활동 " .. FmtDur(quiet) .. " 전"
			if quiet > 120 then s = s .. " (오랫동안 활동이 없습니다. 대기 중단: /wow-ai cancel)" end
		elseif now - started > 60 then
			s = s .. ", 아직 활동이 감지되지 않음"
		end
	end
	return s
end

local function FreeSlot()
	for i = 1, SLOT_COUNT do
		local name = SlotName(i)
		if not C_AddOns.IsAddOnLoaded(name) then
			return name
		end
	end
end

local function ScheduleNextPoll()
	local idx = (run.polls or 0) + 1
	local t = POLL_SCHEDULE[idx]
	if not t then
		t = POLL_SCHEDULE[#POLL_SCHEDULE] + POLL_TAIL * (idx - #POLL_SCHEDULE)
	end
	run.nextPollAt = (run.sentAt or GetTime()) + t
end

local Finish -- defined below

-- The bridge has read this record: whatever game context rode on it is now
-- what the bridge knows, so later messages only carry it again if it changes.
local function NoteAcked(rec)
	rec.acked = true
	if rec.ctx ~= nil then run.contextSent = rec.ctx end
end

local function MarkAcked(id)
	local rec = run.outbound[id]
	if rec and not rec.acked then
		NoteAcked(rec)
		RefreshStrip()
	end
	NotedBridge()
end

-- PlaySoundFile은 이전에 읽은 파일 상태를 캐시할 수 있어 접수 확인이 누락된다.
-- 응답 슬롯의 접수증은 현재 세션과 실제 대기 중인 번호가 모두 맞을 때만 적용한다.
-- 질문의 답변 대기는 유지하고 화면으로 재전송하는 신호만 즉시 감춘다.
local function ApplyAcknowledgements(data)
	if type(data) ~= "table" or type(data.acks) ~= "table" then return end
	for _, ack in ipairs(data.acks) do
		if type(ack) == "table" and ack.session == db.session and type(ack.id) == "number" then
			local rec = run.outbound[ack.id]
			if rec and not rec.acked then MarkAcked(ack.id) end
		end
	end
end

-- Dispatch a list of reply records to the chats waiting for them.
local function ApplyReplies(replies)
	local matched = false
	for _, r in ipairs(replies or {}) do
		local c = FindChat(r.chat)
		if c and c.pendingId and r.id == c.pendingId then
			matched = true
			MarkAcked(r.id)
			local denied = type(r.denied) == "table" and #r.denied > 0 and r.denied or nil
			if r.status == "done" then
				if MapLinks then MapLinks.Auto(r.text) end
				Finish(c, "assistant", r.text or "", denied, r.agent, r.summary, WoWForeverGPT.CleanMacros(r.macros), r.model)
			elseif r.status == "error" then
				Finish(c, "system", "오류: " .. tostring(r.text), denied)
			elseif r.status == "working" then
				c.progress = r.text
			end
		end
	end
	return matched
end

-- The bridge keeps every chat's transcript. After the client wipes our saved data,
-- it sends them back once, addressed to our new session token.
local function ImportRestore(r)
	if type(r) ~= "table" or r.token ~= db.session or db.restored then return end
	db.restored = true
	local added = 0
	local current = ActiveChat()
	for _, rc in ipairs(r.chats or {}) do
		-- Skip chats deleted here that the bridge hasn't been told about yet.
		if type(rc) == "table" and rc.id and not FindChat(rc.id) and not db.forget[rc.id] and #db.chats < MAX_CHATS then
			local chat = {
				id = rc.id,
				name = (rc.name and rc.name ~= "") and rc.name or ("질문 " .. (#db.chats + 1)),
				cwd = rc.cwd or DEFAULT_CWD,
				agent = "",
				history = {},
				unread = 0,
				created = time(),
			}
			for _, m in ipairs(rc.messages or {}) do
				local role, agent = m.role, m.agent
				if role == "claude" then role, agent = "assistant", agent or "claude" end -- an older bridge's transcript
				if agent == "" then agent = nil end
				local model = (type(m.model) == "string" and m.model ~= "") and m.model or nil
				table.insert(chat.history, { role = role, text = m.text, id = m.id, t = m.t, agent = agent, model = model })
			end
			RepairChatTitle(chat)
			-- Keep the chat we're currently using last so it stays where it was.
			table.insert(db.chats, math.max(1, #db.chats), chat)
			added = added + 1
		end
	end
	run.restoring = nil
	if added > 0 then
		if current and #current.history <= 2 then
			for _, ch in ipairs(db.chats) do
				if ch ~= current and ch.name == current.name then current.name = "새 대화" end
			end
		end
		AddHistory(current, "system", "브리지에서 대화 " .. added .. "개를 복원했습니다.")
		WoWForeverGPT.RenderChatList()
	end
end

local function TryLoadSlot(why)
	local name = FreeSlot()
	if not name then
		run.slotsExhausted = true
		WoWForeverGPT.ArmAutoRefresh()
		WoWForeverGPT.UpdateStatus()
		return
	end
	WoWForeverGPT_SlotData = nil
	local loaded, reason = C_AddOns.LoadAddOn(name)
	if not loaded then
		run.slotError = reason
		if reason == "MISSING" or reason == "DISABLED" then
			run.slotsMissing = true
			WoWForeverGPT.ArmAutoRefresh()
		end
		WoWForeverGPT.UpdateStatus()
		return
	end
	run.polls = (run.polls or 0) + 1
	ScheduleNextPoll()
	local data = WoWForeverGPT_SlotData
	if type(data) == "table" and type(data.now) == "number" then
		-- The bridge's clock and ours are the same machine; translate to GetTime().
		NotedBridge(GetTime() - (time() - data.now))
	end
	if type(data) == "table" and type(data.cwd) == "string" and data.cwd ~= "" then run.bridgeCwd = data.cwd end
	if type(data) == "table" then
		if type(data.agent) == "string" and data.agent ~= "" then run.bridgeAgent = data.agent end
		if type(data.agents) == "table" and #data.agents > 0 then run.bridgeAgents = data.agents end
		if type(data.models) == "table" then run.bridgeModels = data.models end
	end
	ApplyAcknowledgements(data)
	local matched = ApplyReplies(type(data) == "table" and data.replies or nil)
	if type(data) == "table" and data.restore then ImportRestore(data.restore) end
	if type(data) == "table" and data.map and WoWForeverGPTMap then WoWForeverGPTMap.Sync(data.map) end
	if why == "signal" and not matched then
		run.signalUnreliable = true
	end
	WoWForeverGPT.Render()
end

local function Tick()
	if not db then return end
	local now = GetTime()
	PollPresence()
	-- Without presence beats, the only evidence is a slot read; spend one every
	-- IDLE_POLL_SECONDS while idle so the light still reflects reality (and stays
	-- green while the bridge is up: BridgeState allows for this interval).
	-- 자동 신호 판별: 최초 자체 검사가 통과해도 이후 WAV 조회가 캐시될 수 있다.
	-- 신호 중단 60초에 보조 슬롯을 읽고, 이후에는 10분 간격으로 확인해 200개 슬롯을 아낀다.
	-- 시간 제한을 없애 초록색으로 고정하지 않고, 슬롯에 기록된 실제 브리지 시각으로 판정한다.
	local presenceAt = run.presence and run.presence.lastBeatAt or run.connectionStartedAt or now
	if signalAvailable and db.settings.signal and now - presenceAt >= PRESENCE_SILENCE_SECONDS then
		run.presenceFallback = true
	end
	if not PresenceWorks() and db.settings.mode == "pixel" and not AnyPending()
		and now - (run.lastIdlePoll or -1e9) >= IDLE_POLL_SECONDS then
		run.lastIdlePoll = now
		TryLoadSlot("idle")
	end
	-- 연결 요청은 AI 호출 없이 hello/접수증만 교환한다. 실패 후에도 60초마다 재시도한다.
	-- 답변 대기 중에는 원래 전송/재전송 절차를 유지해 질문을 중복 생성하지 않는다.
	if db.settings.mode == "pixel" and not AnyPending() and not WoWForeverGPT.IsConnected()
		and not run.connectingAt and now - (run.lastHelloAt or -1e9) >= 60 then
		WoWForeverGPT.Connect()
	end
	WoWForeverGPT.UpdateDot()
	WoWForeverGPT.CheckConnection()
	if db.settings.mode ~= "pixel" then return end
	local changed = false
	if run.helloPollAt and now >= run.helloPollAt then
		run.helloPollAt = nil
		TryLoadSlot("hello")
		-- Whatever that slot held, the wait is over.
		if run.restoring then
			run.restoring = nil
			WoWForeverGPT.Render()
		end
	end
	if run.restoring and now - run.restoring > 25 then
		run.restoring = nil
		WoWForeverGPT.Render()
	end
	-- 삭제 요청은 답변을 기다리는 질문이 아니므로 일반 응답 폴링이 실행되지 않는다.
	-- 별도로 접수증을 최대 3번 확인하고, 받지 못하면 기존 재전송 절차를 유지한다.
	if run.controlPollAt and now >= run.controlPollAt then
		run.controlPollAt = nil
		run.controlPolls = (run.controlPolls or 0) + 1
		TryLoadSlot("receipt")
		for _, rec in pairs(run.outbound) do
			if rec.forget and not rec.acked and run.controlPolls < 3 then
				run.controlPollAt = now + 5
				break
			end
		end
	end
	for id, rec in pairs(run.outbound) do
		if not rec.acked and CheckSignal("ack", id) then
			NoteAcked(rec)
			changed = true
			NotedBridge()
		end
		-- 연결 인사는 브리지의 최신 시각으로도 확인할 수 있다. 삭제 요청은
		-- 다른 요청의 응답 시각으로 완료를 추정하지 않고 실제 접수증을 기다린다.
		if rec.hello and not rec.acked and run.bridgeSeen and run.bridgeSeen >= rec.sentAt then
			NoteAcked(rec)
			changed = true
		end
		if rec.acked then
			if rec.forget then db.forget[rec.forget] = nil end
			run.outbound[id] = nil
			changed = true
		elseif rec.hello and now - rec.sentAt >= 20 then
			run.outbound[id] = nil
			changed = true
		elseif now - rec.sentAt >= STRIP_SECONDS then
			rec.tries = (rec.tries or 1) + 1
			if rec.tries <= STRIP_TRIES then
				-- Nobody picked it up: show it again.
				rec.sentAt = now
				changed = true
			elseif rec.forget then
				-- The bridge is away; db.forget keeps it for the next hello.
				run.outbound[id] = nil
				changed = true
			else
				-- Give up on pixels for this message; the reload path still has it.
				run.outbound[id] = nil
				run.pixelFailed = true
				changed = true
				WoWForeverGPT.ArmAutoRefresh()
			end
		end
	end
	if changed then
		RefreshStrip()
		WoWForeverGPT.UpdateStatus()
	end
	if not AnyPending() then return end
	local moved = false
	for _, c in ipairs(db.chats) do
		if c.pendingId and PollActivity(c) then moved = true end
	end
	if moved then WoWForeverGPT.Render() end
	WoWForeverGPT.CheckPendingRecovery()
	if not AnyPending() then return end
	for _, c in ipairs(db.chats) do
		if c.pendingId and CheckSignal("sig", c.pendingId) then
			TryLoadSlot("signal")
			return
		end
	end
	if run.nextPollAt and now >= run.nextPollAt then
		TryLoadSlot("schedule")
	end
end

-- Pull whatever bridge.js last wrote into Inbox.lua (the reload path).
local function ProcessInbox()
	local inbox = WoWForeverGPT_Inbox
	if type(inbox) ~= "table" then return end
	if type(inbox.cwd) == "string" and inbox.cwd ~= "" then run.bridgeCwd = inbox.cwd end
	if type(inbox.agent) == "string" and inbox.agent ~= "" then run.bridgeAgent = inbox.agent end
	if type(inbox.agents) == "table" and #inbox.agents > 0 then run.bridgeAgents = inbox.agents end
	if type(inbox.models) == "table" then run.bridgeModels = inbox.models end
	ApplyAcknowledgements(inbox)
	ApplyReplies(inbox.replies)
	if inbox.restore then ImportRestore(inbox.restore) end
	if inbox.map and WoWForeverGPTMap then WoWForeverGPTMap.Sync(inbox.map) end
end

Finish = function(chat, role, text, denied, agent, summary, macros, model)
	AddHistory(chat, role, text, chat.pendingId, denied, agent, macros, model)
	chat.pendingId = nil
	chat.progress = nil
	chat.recovering, chat.recoveryStalled = nil, nil
	if run.recovery then run.recovery[chat.id] = nil end
	if run.act then run.act[chat.id] = nil end
	NotedBridge()
	local visible = ui.frame and ui.frame:IsShown() and db.activeChat == chat.id
	if not visible then
		chat.unread = (chat.unread or 0) + 1
	end
	if not AnyPending() then
		keyCatcher:Hide()
	end
	if visible and ui.input and chat.draft and chat.draft ~= "" then
		ui.input:SetText(chat.draft)
		chat.draft = nil
	end
	WoWForeverGPT.Render()
	WoWForeverGPT.Notify(chat, text, agent, summary, model)
end

---------------------------------------------------------------------------
-- Game context and links
---------------------------------------------------------------------------

-- The agent only sees text, so two things about the game are spelled out for it:
-- who is asking (the character, where they are; sent with the hello and again
-- when it changes, and put into the agent's system prompt by the bridge), and
-- what the player shift-clicked into the message (item, spell and quest links
-- are meaningless markup to the agent; their tooltips are what the player sees).
-- Every game API here is optional: whatever the client lacks is left out.

local CONTEXT_MAX = 2600 -- 3200바이트 패킷 안에서 질문 여유를 남기고 현재 전투/퀘스트 정보를 우선한다.
local CONTEXT_MIN = 512 -- 질문이 길어도 직업·레벨·지역을 위한 전송 공간을 확보한다.
local LINK_LINES_MAX = 30 -- tooltip lines kept per link
local LINK_BYTES_MAX = 900 -- bytes kept per link

-- Call a game API that may not exist or may throw, and get its returns or nothing.
local function Try(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f, g = pcall(fn, ...)
	if ok then return a, b, c, d, e, f, g end
end

local function Money(copper)
	copper = tonumber(copper) or 0
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	if g > 0 then return g .. "g " .. s .. "s " .. c .. "c" end
	if s > 0 then return s .. "s " .. c .. "c" end
	return c .. "c"
end

-- A few lines about the game and the character, as the bridge will show them to the agent.
-- Profession and secondary skill lines by skill id (vanilla ids).
local PROFESSION_SKILL_IDS = {
	[164] = true, [165] = true, [171] = true, [182] = true, [186] = true, [197] = true, [202] = true,
	[333] = true, [393] = true, [129] = true, [185] = true, [356] = true,
}

-- The character's skill lines as { name, isHeader, rank, maxRank, skillID }.
-- Forever only has C_SkillInfo (one table per line); the classic globals
-- (multiple returns) are the fallback for other clients.
function WoWForeverGPT.SkillLines()
	local out = {}
	if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
		local n = Try(C_SkillInfo.GetNumSkillLines)
		local seen = {}
		for i = 1, (type(n) == "number" and n or 0) do
			local sk = Try(C_SkillInfo.GetSkillLineInfo, i)
			-- Child lines (parentSkillLineID ~= 0) repeat their parent; Blizzard's
			-- skills frame skips them too.
			if type(sk) == "table" and type(sk.name) == "string" and (sk.parentSkillLineID or 0) == 0 then
				local key = sk.isHeader and ("h:" .. sk.name) or (sk.skillID or sk.name)
				if not seen[key] then
					seen[key] = true
					out[#out + 1] = { name = sk.name, isHeader = sk.isHeader, rank = sk.rank, maxRank = sk.maxRank, skillID = sk.skillID }
				end
			end
		end
		return out
	end
	local n = Try(GetNumSkillLines)
	for i = 1, (type(n) == "number" and n or 0) do
		local sname, isHeader, _, rank, _, _, maxRank = Try(GetSkillLineInfo, i)
		if type(sname) == "string" then
			out[#out + 1] = { name = sname, isHeader = isHeader and true or false, rank = rank, maxRank = maxRank }
		end
	end
	return out
end

function WoWForeverGPT.GameContext(maxBytes)
	-- 기본 질문창 뒤에서 전송 시점에만 읽는다. 이벤트 감시/별도 창/캐릭터별 DB를 추가하지 않는다.
	-- 기본 신원을 먼저 담고, 패킷 여유가 있을 때 특성·현재 장비·퀘스트를 추가한다.
	local budget = math.max(0, math.min(tonumber(maxBytes) or CONTEXT_MAX, CONTEXT_MAX))
	local lines, used, omitted = {}, 0, false
	local marker = "[Snapshot truncated: omitted fields are unknown.]"
	local function Readable(value)
		return type(issecretvalue) ~= "function" or not issecretvalue(value)
	end
	local function Short(value, bytes)
		if not Readable(value) or value == nil then return "?" end
		return Utf8Prefix(tostring(value):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\30\31\r\n]", " "), bytes)
	end
	local function Add(text)
		local size = #text + (#lines > 0 and 1 or 0)
		if used + size <= budget - #marker - 1 then
			lines[#lines + 1] = text
			used = used + size
			return true
		end
		omitted = true
		return false
	end
	local version, build, _, toc = Try(GetBuildInfo)
	toc = tonumber(toc)
	if not toc or toc < 16000 or toc >= 20000 then
		return Utf8Prefix("Game: not a verified Forever client. Current character information is unavailable.", budget)
	end
	local class, classID = Try(UnitClass, "player")
	-- 이름이 아직 없더라도 직업/레벨은 독립적으로 읽어 빠뜨리지 않는다.
	Add("Character: level=" .. Short(Try(UnitLevel, "player"), 10)
		.. "; class=" .. Short(class, 36) .. "(" .. Short(classID, 16) .. ")"
		.. "; race=" .. Short(Try(UnitRace, "player"), 36)
		.. "; faction=" .. Short(Try(UnitFactionGroup, "player"), 16)
		.. "; name=" .. Short(Try(UnitName, "player"), 48))
	Add("Game: World of Warcraft Forever; client=" .. Short(version, 24) .. "; build=" .. Short(build, 16))
	local zone, sub = Try(GetZoneText), Try(GetSubZoneText)
	Add("Location: " .. Short(zone, 70) .. (sub and sub ~= "" and sub ~= zone and (" / " .. Short(sub, 50)) or ""))

	-- 질문마다 읽는 현재 대상/퀘스트를 장비 목록보다 먼저 넣는다. 보호값은 변환·비교하지 않는다.
	local exists = Try(UnitExists, "target")
	if Readable(exists) and exists then
		Add("Target: " .. Short(Try(UnitName, "target"), 65) .. "; level=" .. Short(Try(UnitLevel, "target"), 8)
			.. "; type=" .. Short(Try(UnitCreatureType, "target"), 25))
	end
	local selected = Try(C_QuestLog and C_QuestLog.GetSelectedQuest)
	if not Readable(selected) or type(selected) ~= "number" or selected <= 0 then
		selected = Try(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)
	end
	if Readable(selected) and type(selected) == "number" and selected > 0 then
		Add("Selected quest: #" .. selected .. " " .. Short(Try(C_QuestLog and C_QuestLog.GetTitleForQuestID, selected), 95))
		local objectives = Try(C_QuestLog and C_QuestLog.GetQuestObjectives, selected)
		if type(objectives) == "table" then
			for i = 1, math.min(#objectives, 4) do
				local o = objectives[i]
				if type(o) == "table" then
					Add("Quest objective: " .. Short(o.text, 110) .. " (" .. Short(o.numFulfilled, 8) .. "/" .. Short(o.numRequired, 8) .. ")")
				end
			end
		end
	end
	-- 실제 장착 원거리 무기의 툴팁을 읽는다. 장비 이름만으로 피해량/공속을 추정하지 않는다.
	local wand = Try(GetInventoryItemLink, "player", 18)
	if type(wand) == "string" then
		Add("Ranged weapon: " .. Short(wand:match("|h%[([^%]]*)%]|h") or wand, 65))
		local tip = Try(C_TooltipInfo and C_TooltipInfo.GetInventoryItem, "player", 18)
		local texts, size = {}, 0
		if type(tip) == "table" and type(tip.lines) == "table" then
			for _, line in ipairs(tip.lines) do
				for _, field in ipairs({"leftText", "rightText"}) do
					local text = Short(line[field], 90)
					if text ~= "?" and text ~= "" and size + #text < 280 then texts[#texts + 1] = text; size = size + #text end
				end
			end
		end
		if #texts > 0 then Add("Ranged tooltip: " .. table.concat(texts, "; ")) end
	end
	-- 스킬북의 실제 습득 주문만 담는다. FUTURESPELL은 빼고 불완전한 목록임을 명시한다.
	-- 매 질문 최대 400슬롯/520바이트로 제한하여 전문기술/고레벨 캐릭터도 패킷을 넘기지 않는다.
	local spells, seen, spellBytes, scanned = {}, {}, 0, 0
	local function TakeSpell(id, name)
		if not Readable(id) or type(id) ~= "number" or seen[id] then return end
		seen[id] = true
		local info = Try(C_Spell and C_Spell.GetSpellInfo, id)
		name = name or (type(info) == "table" and info.name) or Try(GetSpellInfo, id)
		local text = Short(name, 45) .. "#" .. id
		if spellBytes + #text + 2 <= 520 then spells[#spells + 1] = text; spellBytes = spellBytes + #text + 2 end
	end
	local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
	local skillCount = Try(C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines)
	if bank and type(skillCount) == "number" then
		-- 일반/전문기술 탭이 먼저 나와도 직업 주문이 잘리지 않도록 직업 탭부터 수집한다.
		local skillLines = {}
		for tab = 1, math.min(skillCount, 12) do
			local line = Try(C_SpellBook.GetSpellBookSkillLineInfo, tab)
			if type(line) == "table" then skillLines[#skillLines + 1] = {line = line, tab = tab} end
		end
		table.sort(skillLines, function(a, b)
			local ap = a.line.name == class and 0 or 1
			local bp = b.line.name == class and 0 or 1
			if ap ~= bp then return ap < bp end
			return a.tab < b.tab
		end)
		for _, entry in ipairs(skillLines) do
			local line = entry.line
			if type(line) == "table" and type(line.itemIndexOffset) == "number" and type(line.numSpellBookItems) == "number" then
				for i = line.itemIndexOffset + 1, line.itemIndexOffset + math.min(line.numSpellBookItems, 400 - scanned) do
					scanned = scanned + 1
					local info = Try(C_SpellBook.GetSpellBookItemInfo, i, bank)
					if type(info) == "table" and info.itemType == (Enum.SpellBookItemType and Enum.SpellBookItemType.Spell) then
						local passive = Try(C_SpellBook.IsSpellBookItemPassive, i, bank)
						if not passive then TakeSpell(info.spellID, info.name) end
					end
				end
			end
		end
	elseif type(GetSpellBookItemInfo) == "function" then
		for i = 1, 400 do
			local kind, id = Try(GetSpellBookItemInfo, i, BOOKTYPE_SPELL or "spell")
			if not kind then break end
			if kind == "SPELL" then TakeSpell(id, Try(GetSpellBookItemName, i, BOOKTYPE_SPELL or "spell")) end
		end
	end
	if #spells > 0 then Add("Known spells (partial; omission does not mean unlearned): " .. table.concat(spells, ", "))
	else Add("Known spells: not readable") end

	local tabs, talents = Try((C_SpecializationInfo and C_SpecializationInfo.GetNumTalentTabs) or GetNumTalentTabs), {}
	if type(tabs) == "number" then
		for i = 1, math.min(tabs, 3) do
			local name, points
			local info = Try(C_SpecializationInfo and C_SpecializationInfo.GetTalentTabInfo, i)
			if type(info) == "table" then name, points = info.name, info.pointsSpent
			else
				local a, b, c, _, e = Try(GetTalentTabInfo, i)
				if type(a) == "string" then name, points = a, c else name, points = b, e end
			end
			if type(name) == "string" and Readable(points) and type(points) == "number" then talents[#talents + 1] = Short(name, 30) .. "=" .. points end
		end
	end
	if #talents > 0 then
		Add("Talents (points spent): " .. table.concat(talents, ", "))
		local purchased = {}
		for tab = 1, math.min(tabs or 0, 3) do
			local count = Try(GetNumTalents, tab)
			for index = 1, math.min(type(count) == "number" and count or 0, 50) do
				local name, _, _, _, rank = Try(GetTalentInfo, tab, index)
				if Readable(rank) and type(rank) == "number" and rank > 0 then purchased[#purchased + 1] = Short(name, 45) .. "=" .. rank end
			end
		end
		if #purchased > 0 then Add("Purchased talents: " .. table.concat(purchased, ", ")) end
	else
		-- 포에버의 Traits 방식은 탭 API가 없을 수 있다. 좌표로 특성 계열을 추측하지
		-- 않고 실제 투자한 노드의 주문 이름과 등급만 읽는다. 전송 시 한 번만 조회한다.
		local config = Try(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
		if not Readable(config) or type(config) ~= "number" or config <= 0 then config = nil end
		local info = config and Try(C_Traits and C_Traits.GetConfigInfo, config)
		local tree = type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
		if not Readable(tree) or type(tree) ~= "number" then tree = nil end
		local nodes = tree and Try(C_Traits and C_Traits.GetTreeNodes, tree)
		local unknown = false
		if type(nodes) == "table" and #nodes > 0 then
			unknown = #nodes > 300
			for i = 1, math.min(#nodes, 300) do
				local node = Try(C_Traits.GetNodeInfo, config, nodes[i])
				local ranks = type(node) == "table" and node.ranksPurchased
				if not Readable(ranks) or type(ranks) ~= "number" then unknown = true
				elseif ranks > 0 then
					local entry = node.activeEntry and node.activeEntry.entryID
					if not Readable(entry) then entry = nil end
					if not entry and node.entryIDs and #node.entryIDs == 1 then entry = node.entryIDs[1] end
					if not Readable(entry) then entry = nil end
					local data = entry and Try(C_Traits.GetEntryInfo, config, entry)
					local definitionID = type(data) == "table" and data.definitionID
					if not Readable(definitionID) then definitionID = nil end
					local definition = definitionID and Try(C_Traits.GetDefinitionInfo, definitionID)
					local spell = type(definition) == "table" and definition.spellID
					if not Readable(spell) then spell = nil end
					local spellInfo = spell and Try(C_Spell and C_Spell.GetSpellInfo, spell)
					local name = type(spellInfo) == "table" and spellInfo.name or (spell and Try(GetSpellInfo, spell))
					if not Readable(name) then name = nil end
					talents[#talents + 1] = (name and Short(name, 60) or ("node#" .. nodes[i])) .. "=" .. ranks
				end
				if #talents >= 12 then unknown = unknown or i < #nodes; break end
			end
			Add("Purchased talents: " .. (#talents > 0 and table.concat(talents, ", ") or (unknown and "not readable" or "none (0 spent)")) .. (unknown and " [partial]" or ""))
		else Add("Talents: not available; do not infer a specialization") end
	end
	local stats = {}
	for index, label in ipairs({"힘", "민첩", "체력", "지능", "정신력"}) do
		local base, effective = Try(UnitStat, "player", index)
		local value = base
		if Readable(effective) and type(effective) == "number" then value = effective end
		if Readable(value) and type(value) == "number" then stats[#stats + 1] = label .. "=" .. value end
	end
	if #stats > 0 then Add("Current primary stats: " .. table.concat(stats, ", ")) end
	local map = Try(C_Map and C_Map.GetBestMapForUnit, "player")
	local pos = map and Try(C_Map and C_Map.GetPlayerMapPosition, map, "player")
	if type(map) == "number" and type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
		Add(("Position: map=%d, %.1f, %.1f"):format(map, pos.x * 100, pos.y * 100))
	end

	-- 장비 요약은 실제 링크의 이름과 ID다. 모르는 랜덤 옵션/주문력/무기 DPS를 만들어내지 않는다.
	-- 무기부터 보내 짧은 패킷에서도 전투 관련 핵심 장비를 우선한다. 셔츠/휘장은 제외한다.
	local slots = {{16,"주무기"},{17,"보조무기"},{18,"원거리"},{5,"가슴"},{7,"다리"},{1,"머리"},{3,"어깨"},{9,"손목"},{10,"손"},{6,"허리"},{8,"발"},{11,"반지1"},{12,"반지2"},{13,"장신구1"},{14,"장신구2"},{2,"목"},{15,"등"}}
	Add("Equipped (names/IDs only; full item stats are not attached):")
	for _, entry in ipairs(slots) do
		local link = Try(GetInventoryItemLink, "player", entry[1])
		if type(link) == "string" then
			local id = link:match("item:(%d+)")
			local name = Try((C_Item and C_Item.GetItemInfo) or GetItemInfo, link) or link:match("|h%[([^%]]*)%]|h")
			Add(entry[2] .. ": " .. Short(name, 75) .. (id and (" #" .. id) or ""))
		else Add(entry[2] .. ": empty or unreadable") end
	end
	local professions = {}
	for _, skill in ipairs(WoWForeverGPT.SkillLines()) do
		if PROFESSION_SKILL_IDS[skill.skillID] then professions[#professions + 1] = Short(skill.name, 45) .. "=" .. tostring(skill.rank or "?") end
	end
	if #professions > 0 then Add("Professions: " .. table.concat(professions, ", ")) end
	if omitted and used + #marker + 1 <= budget then lines[#lines + 1] = marker end
	return table.concat(lines, "\n")
end

local function ContextToSend(room)
	-- 매 질문의 실제 스냅샷을 보낸다. 이전 캐릭터/레벨의 캐시를 재사용하거나
	-- 긴 질문이라는 이유로 정보를 통째로 빼지 않는다. 끄기 명령은 빈 값으로 명시한다.
	if not db.settings.context then return "" end
	return WoWForeverGPT.GameContext(room)
end

-- Read a link's tooltip off a hidden GameTooltip, one line per row.
local scanTip
local function TooltipLines(payload)
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "WoWForeverGPTScanTip", UIParent, "GameTooltipTemplate")
	end
	scanTip:SetOwner(UIParent, "ANCHOR_NONE")
	scanTip:ClearLines()
	local lines = {}
	if pcall(scanTip.SetHyperlink, scanTip, payload) then
		for i = 1, math.min(scanTip:NumLines() or 0, LINK_LINES_MAX) do
			local left = _G["WoWForeverGPTScanTipTextLeft" .. i]
			local right = _G["WoWForeverGPTScanTipTextRight" .. i]
			local l = Trim(tostring((left and left:GetText()) or ""))
			local r = Trim(tostring((right and right:IsShown() and right:GetText()) or ""))
			if r ~= "" then l = l .. "  " .. r end
			if l ~= "" then table.insert(lines, l) end
		end
	end
	scanTip:Hide()
	return lines
end

-- What a link is, in words: "item 2140 (Uncommon)", "spell 1978", "quest 176".
local function DescribeLink(payload)
	local kind, id = payload:match("^(%a+):(%d+)")
	if not kind then return payload:match("^(%a+)") or "link" end
	local s = kind .. " " .. id
	if kind == "item" then
		local _, _, quality = Try((C_Item and C_Item.GetItemInfo) or GetItemInfo, payload)
		local desc = type(quality) == "number" and _G["ITEM_QUALITY" .. quality .. "_DESC"]
		if desc then s = s .. " (" .. desc .. ")" end
	end
	return s
end

-- Turn the links in a message into text the agent can use: each becomes [Name]
-- in place, and a block at the end lists what the tooltip says about it.
-- Returns the new text and the number of links found.
function WoWForeverGPT.ExpandLinks(text)
	local links, seen = {}, {}
	local function Take(payload, name)
		if not seen[payload] then
			seen[payload] = true
			table.insert(links, { payload = payload, name = name })
		end
		return "[" .. name .. "]"
	end
	-- Coloured links first (|cAARRGGBB|H...|h[Name]|h|r), then bare ones.
	local out = text:gsub("|c%x%x%x%x%x%x%x%x|H([^|]+)|h%[([^%]]*)%]|h|r", Take)
	out = out:gsub("|H([^|]+)|h%[([^%]]*)%]|h", Take)
	if #links == 0 then return text, 0 end
	local blocks = {}
	local compared = false
	for _, l in ipairs(links) do
		local head = "[" .. l.name .. "] " .. DescribeLink(l.payload)
		local body = table.concat(TooltipLines(l.payload), "\n  ")
		local block = body ~= "" and (head .. "\n  " .. body) or head
		if #block > LINK_BYTES_MAX then block = Utf8Prefix(block, LINK_BYTES_MAX) .. "..." end
		-- 첫 장비 아이템에는 같은 부위의 현재 장비 툴팁을 추가한다.
		-- 원본 링크 전체를 사용하므로 랜덤 옵션·인챈트도 현재 값으로 비교한다.
		if not compared and EntityLinks and l.payload:match("^item:") then
			local comparison = EntityLinks.ComparisonBlock(l.payload, TooltipLines, Utf8Prefix)
			if comparison then block, compared = comparison, true end
		end
		table.insert(blocks, block)
	end
	return out .. "\n\n--- Linked from the game ---\n" .. table.concat(blocks, "\n"), #links
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

-- allow: optional list of permission rules to grant before this message runs.
function WoWForeverGPT.Send(text, allow)
	local c = ActiveChat()
	if not c then return end
	text = Trim(text or "")
	if c.pendingId then
		-- Typing while waiting: keep the draft, and check for the reply.
		if text ~= "" then c.draft = text end
		if db.settings.mode == "pixel" and not (run.slotsExhausted or run.slotsMissing) then
			TryLoadSlot("manual")
		else
			SafeReload()
		end
		return
	end
	if text == "" then return end
	if not WoWForeverGPT.IsConnected() then
		-- Not connected: the message stays in the box and we try to connect;
		-- CheckConnection sends it the moment the light turns green. If the bridge
		-- never answers, the text is still in the box for a later try.
		if ui.input then ui.input:SetText(text) end
		run.sendOnConnect = { chat = c.id, text = text, allow = allow }
		if not run.connectingAt then WoWForeverGPT.Connect() end
		WoWForeverGPT.Toggle(true)
		return
	end
	-- Shift-clicked links become [Name] plus their tooltip, which is what the agent can read.
	local links
	text, links = WoWForeverGPT.ExpandLinks(text)
	local totalLimit = math.min(Codec.MAX_PAYLOAD - 300, 3000)
	local limit = totalLimit - (db.settings.context and CONTEXT_MIN or 0)
	if #text > limit then
		AddHistory(c, "system", "질문이 너무 깁니다. 내용을 줄이거나 나누어 보내세요." .. (links > 0 and " 링크를 첨부하면 툴팁도 함께 포함됩니다." or ""))
		WoWForeverGPT.Render()
		return
	end
	-- The game context rides along when the bridge doesn't have this version yet.
	local ctx = ContextToSend(totalLimit - #text)

	db.lastSeq = db.lastSeq + 1
	local id = db.lastSeq
	local effort = db.settings.effort
	local model = ChatModel(c)
	local tokens = { "effort=" .. effort }
	if c.resetNext then table.insert(tokens, "n") end
	-- 화면에 보이는 AI와 실제 질문이 일치하도록, 고르지 않은 대화도 적용될 AI를 명시해 보낸다.
	local sendAgent = ChatAgent(c)
	if sendAgent and sendAgent ~= "" then table.insert(tokens, "agent=" .. sendAgent) end
	if model then table.insert(tokens, "model=" .. model) end
	local allowHex
	if type(allow) == "table" and #allow > 0 then
		table.insert(tokens, "allow=" .. table.concat(allow, ","))
		allowHex = ToHex(table.concat(allow, US))
	end
	local flags = table.concat(tokens, ";")
	local newSession = c.resetNext and true or nil
	c.resetNext = nil
	db.outbox = {
		id = id,
		session = db.session,
		chat = c.id,
		text = ToHex(text),
		cwd = ToHex(c.cwd),
		ctx = ctx and ToHex(ctx) or nil,
		agent = (sendAgent and sendAgent ~= "") and sendAgent or nil,
		allow = allowHex,
		effort = effort,
		model = model,
		newSession = newSession,
		t = time(),
	}
	c.pendingId = id
	c.recovering, c.recoveryStalled = nil, nil
	c.draft = nil
	c.progress = nil
	AddHistory(c, "user", text, id)
	-- A chat still carrying its default name takes its title from the first message
	-- you send (system notes like "/wow-ai cd" before it don't count).
	if c.name:match("^질문 %d+$") then
		local first = true
		for _, m in ipairs(c.history) do
			if m.role == "user" and m.id ~= id then first = false break end
		end
		if first then c.name = AutoTitle(text) or c.name end
	end
	db.settings.shown = true

	if db.settings.mode == "pixel" then
		run.outbound[id] = { chat = c.id, cwd = c.cwd, flags = flags, name = c.name, text = text, ctx = ctx, sentAt = GetTime() }
		run.sentAt = GetTime()
		run.polls = 0
		StartActivity(c, id)
		ScheduleNextPoll()
		RefreshStrip()
		WoWForeverGPT.Render()
	else
		SafeReload()
	end
end

-- Forget: a record with no text telling the bridge a chat was deleted, so it drops
-- the transcript (which a later restore would otherwise bring back) and the
-- agent session. db.forget keeps the id until the bridge acks, so a delete made
-- while the bridge was away is sent again with the next hello.
local function SendForget(chatId)
	if db.settings.mode ~= "pixel" then return end
	for _, rec in pairs(run.outbound) do
		if rec.forget == chatId and not rec.acked then return end
	end
	local info = db.forget[chatId] or {}
	db.lastSeq = db.lastSeq + 1
	run.outbound[db.lastSeq] = { chat = chatId, cwd = info.cwd or "", flags = "d", name = info.name or "", text = "", sentAt = GetTime(), forget = chatId }
	run.controlPollAt = math.min(run.controlPollAt or math.huge, GetTime() + 3)
	run.controlPolls = 0
	RefreshStrip()
end

local function ForgetOnBridge(c)
	if not c or not c.id then return end
	db.forget[c.id] = { name = c.name, cwd = c.cwd }
	SendForget(c.id)
end

-- Hello: a record with no text that just announces our session token. The bridge
-- acks it, offers a restore if our saved data is fresh, and refreshes the slots,
-- so the status light and any lost chats come back before the first message.
-- 연결 확인에는 세션/대화 식별자만 필요하다. 브리지의 hello 처리부는 캐릭터 정보를
-- 사용하지 않으며, 실제 질문이 매번 최신 스냅샷을 독립적으로 전송한다.
function WoWForeverGPT.SayHello()
	if db.settings.mode ~= "pixel" then return end
	local now = GetTime()
	if run.lastHelloAt and now - run.lastHelloAt < 60 then return end
	run.lastHelloAt = now
	db.lastSeq = db.lastSeq + 1
	local c = ActiveChat()
	run.outbound[db.lastSeq] = { chat = c and c.id or "", cwd = c and c.cwd or "", flags = "h", name = c and c.name or "", text = "", sentAt = now, hello = true }
	run.helloPollAt = now + 5
	-- Deletions the bridge never confirmed ride along with the hello.
	for id in pairs(db.forget) do SendForget(id) end
	-- Fresh saved data: show "restoring" instead of an empty panel until we hear back.
	if not db.restored then
		local empty = true
		for _, ch in ipairs(db.chats) do
			if #ch.history > 0 then empty = false end
		end
		if empty then run.restoring = now end
	end
	RefreshStrip()
	WoWForeverGPT.Render()
end

-- Put the active chat's pending message back on the strip.
function WoWForeverGPT.Resend(chat)
	-- 자동 복구는 현재 열어 둔 창과 무관하게 대기 중인 대화를 지정할 수 있다.
	local c = type(chat) == "table" and type(chat.history) == "table" and chat or ActiveChat()
	if not c or not c.pendingId then return end
	local text
	for i = #c.history, 1, -1 do
		if c.history[i].id == c.pendingId and c.history[i].role == "user" then
			text = c.history[i].text
			break
		end
	end
	if not text then return end
	local outbox = db.outbox
	local previous = outbox and outbox.id == c.pendingId and outbox.chat == c.id and outbox or nil
	local pending = run.outbound[c.pendingId]
	local effort = previous and EFFORT_LABEL[previous.effort] and previous.effort or db.settings.effort
	-- 원래 전송 기록이 없으면 저장된 outbox에서 AI와 모델까지 복원해 같은 조건으로 다시 보낸다.
	local flags = pending and pending.flags
	if not flags then
		local parts = { "effort=" .. effort }
		if previous and previous.newSession then table.insert(parts, "n") end
		local agent = previous and previous.agent or ChatAgent(c)
		if agent then table.insert(parts, "agent=" .. agent) end
		local model = previous and previous.model or ChatModel(c)
		if model then table.insert(parts, "model=" .. model) end
		flags = table.concat(parts, ";")
	end
	-- 같은 질문의 재전송은 최초 질문 시점의 정보를 유지한다. 새 위치/장비로 바꾸면
	-- 브리지 재시작 직후 아직 처리되지 않은 질문의 의미가 달라질 수 있다.
	local ctx = pending and pending.ctx
	if ctx == nil and previous and type(previous.ctx) == "string" then
		ctx = previous.ctx:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end)
	end
	if ctx == nil then ctx = ContextToSend(math.max(0, Codec.MAX_PAYLOAD - 300 - #text)) end
	run.outbound[c.pendingId] = { chat = c.id, cwd = c.cwd, flags = flags, name = c.name, text = text, ctx = ctx, sentAt = GetTime() }
	run.sentAt = GetTime()
	run.polls = 0
	ScheduleNextPoll()
	RefreshStrip()
	WoWForeverGPT.UpdateStatus()
end


-- 기존 재전송 버튼/명령에서 먼저 완료 답변을 확인하고, 없을 때만 같은 번호를 다시 보낸다.
-- 자동 복구는 UI를 강제로 새로고침하지 않는다. 슬롯 소진 시에는 사용자의 기존 버튼
-- 클릭으로만 SafeReload를 호출하며, 전투 중에는 기존 전투 종료 대기 절차를 따른다.
function WoWForeverGPT.RecoverPending(chat, automatic)
	local c = type(chat) == "table" and type(chat.history) == "table" and chat or ActiveChat()
	if not c or not c.pendingId then return false end
	if not automatic then
		run.recovery = run.recovery or {}
		run.recovery[c.id] = { id = c.pendingId, attempts = 0, nextAt = GetTime() + 60, progress = c.progress }
		c.recoveryStalled = nil
	end
	if db.settings.mode ~= "pixel" or run.slotsExhausted or run.slotsMissing or run.pixelFailed then
		c.recoveryStalled = true
		if not automatic then SafeReload() end
		WoWForeverGPT.UpdateStatus()
		return false
	end
	TryLoadSlot("recovery")
	if not c.pendingId then return true end
	-- 방금 확인하면서 슬롯 소진이 발견될 수도 있다. 자동 재전송으로 이를 덮어쓰지 않는다.
	if run.slotsExhausted or run.slotsMissing then
		c.recoveryStalled = true
		if not automatic then SafeReload() end
		WoWForeverGPT.UpdateStatus()
		return false
	end
	c.recovering = true
	WoWForeverGPT.Resend(c)
	return false
end

function WoWForeverGPT.CheckPendingRecovery()
	-- 활동/진행 문구가 60초 동안 바뀌지 않으면 수신을 다시 확인한다.
	-- 동일 요청 번호를 유지하므로 브리지는 답변을 다시 게시하고 AI를 중복 실행하지 않는다.
	-- 대화별 최대 3회로 제한해 장시간 처리나 브리지 종료 시 전송/슬롯을 계속 소비하지 않는다.
	local now = GetTime()
	run.recovery = run.recovery or {}
	for _, c in ipairs(db.chats) do
		if c.pendingId then
			local state = run.recovery[c.id]
			if not state or state.id ~= c.pendingId then
				state = { id = c.pendingId, attempts = 0, nextAt = now + 60, progress = c.progress }
				run.recovery[c.id] = state
			end
			if state.progress ~= c.progress then
				state.progress, state.nextAt = c.progress, now + 60
			end
			local activity = run.act and run.act[c.id]
			if activity and activity.last then state.nextAt = math.max(state.nextAt, activity.last + 60) end
			if now >= state.nextAt and state.attempts < 3 then
				-- 전투 중에는 애드온 로드/재전송을 새로 시도하지 않고 잠시 미룬다.
				if InCombatLockdown() then state.nextAt = now + 10; return end
				state.attempts, state.nextAt = state.attempts + 1, now + 60
				WoWForeverGPT.RecoverPending(c, true)
				if c.pendingId and state.attempts >= 3 then
					c.recoveryStalled = true
					WoWForeverGPT.UpdateStatus()
				end
				return -- 한 틱에 한 대화만 처리한다. 동시 대기의 슬롯 소비가 몰리지 않는다.
			end
		else
			run.recovery[c.id] = nil
		end
	end
end

function WoWForeverGPT.SendFromInput()
	if not ui.input then return end
	local text = ui.input:GetText()
	ui.input:SetText("")
	ui.input:ClearFocus() -- hand the keyboard back to the game after sending
	WoWForeverGPT.Send(text)
end

-- The Allow button: grant the rules a reply asked for, then tell the agent to carry on.
function WoWForeverGPT.Allow(chatId, rules)
	local c = FindChat(chatId)
	if not c or c.pendingId or not rules or #rules == 0 then return end
	if db.activeChat ~= c.id then WoWForeverGPT.SwitchChat(c.id) end
	for _, m in ipairs(c.history) do m.denied = nil end
	AddHistory(c, "system", "허용한 작업: " .. table.concat(rules, ", "))
	WoWForeverGPT.Send("해당 작업을 허용했습니다. 중단된 부분부터 계속하세요.", rules)
end

---------------------------------------------------------------------------
-- Chats
---------------------------------------------------------------------------

function WoWForeverGPT.SwitchChat(id)
	local c = FindChat(id)
	if not c then return end
	local prev = ActiveChat()
	if prev and prev ~= c and ui.input then
		local typed = Trim(ui.input:GetText() or "")
		prev.draft = typed ~= "" and typed or nil
	end
	db.activeChat = c.id
	c.unread = 0
	if ui.input then
		ui.input:SetText(c.draft or "")
		c.draft = nil
	end
	WoWForeverGPT.Render()
	WoWForeverGPT.RenderChatList()
end

function WoWForeverGPT.NewChat(name)
	local c = AddChat(name and name ~= "" and name or nil)
	if not c then
		local a = ActiveChat()
		AddHistory(a, "system", "대화는 최대 " .. MAX_CHATS .. "개입니다. 기존 대화 하나를 삭제하세요.")
		WoWForeverGPT.Render()
		return
	end
	WoWForeverGPT.SwitchChat(c.id)
	WoWForeverGPT.Toggle(true)
end

-- Folder this chat's agent works in. Empty (or "-" / "default") = the bridge's
-- default. Relative paths are resolved by the bridge against that default.
function WoWForeverGPT.SetFolder(rest, c)
	c = c or ActiveChat()
	if not c then return end
	rest = Trim(rest or "")
	if rest == "-" or rest == "default" then rest = "" end
	local base = run.bridgeCwd or "브리지 기본 폴더"
	if rest ~= "" then
		local changed = rest ~= c.cwd
		c.cwd = rest
		local absolute = rest:match("^%a:[\\/]") or rest:match("^[\\/~]")
		local note = absolute and "" or (" (기준 폴더: " .. base .. ")")
		AddHistory(c, "system", "작업 폴더: " .. rest .. note .. (changed and #c.history > 1 and (". 다음 질문부터 이 폴더에서 새 " .. ChatAgentName(c) .. " 세션을 시작합니다.") or ""))
	elseif c.cwd ~= "" then
		c.cwd = ""
		AddHistory(c, "system", "작업 폴더를 브리지 기본값으로 되돌렸습니다: " .. base)
	else
		AddHistory(c, "system", "현재 작업 폴더: " .. base .. " (변경: /wow-ai cd <폴더> 또는 대화 우클릭 → 작업 폴더)")
	end
	WoWForeverGPT.Render()
end

-- 화면 문구만 번역하고 팝업 ID·%s 치환자·명령어는 유지한다.
-- 삭제·매크로 확인의 결과도 그대로 안내해 번역 때문에 동작이 모호해지지 않게 한다.
StaticPopupDialogs["WOWFOREVERGPT_FOLDER"] = {
	text = "이 대화의 작업 폴더\n\n기준 폴더: %s\n상대 경로, ~ 또는 전체 경로를 입력하세요.\n비워 두면 기본 폴더를 사용합니다. 변경하면 새 AI 세션을 시작합니다.",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = 1,
	editBoxWidth = 320,
	maxLetters = 250,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnShow = function(dialog, data)
		local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
		if box then
			box:SetText(data and data.cwd or "")
			box:HighlightText()
			box:SetFocus()
		end
	end,
	OnAccept = function(dialog, data)
		local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
		local chat = data and FindChat(data.id)
		if chat and box then WoWForeverGPT.SetFolder(box:GetText(), chat) end
	end,
	EditBoxOnEnterPressed = function(box)
		local dialog = box:GetParent()
		StaticPopupDialogs["WOWFOREVERGPT_FOLDER"].OnAccept(dialog, dialog.data)
		dialog:Hide()
	end,
	EditBoxOnEscapePressed = function(box)
		box:GetParent():Hide()
	end,
}

-- Folder dialog for a chat (the active one when no id is given).
function WoWForeverGPT.FolderPrompt(id)
	local c = (id and FindChat(id)) or ActiveChat()
	if not c then return end
	StaticPopup_Show("WOWFOREVERGPT_FOLDER", run.bridgeCwd or "연결 후 확인 가능", nil, { id = c.id, cwd = c.cwd })
end

-- The agent this chat talks to, by id. Empty (or
-- "-" / "default") = the bridge's default. The bridge starts a fresh session
-- when a chat changes agent, since a session belongs to the agent that made it.
local function AgentList()
	return run.bridgeAgents and table.concat(run.bridgeAgents, ", ") or "claude, codex, grok, agy, hermes"
end

function WoWForeverGPT.SetAgent(rest, c)
	c = c or ActiveChat()
	if not c then return end
	rest = Trim(rest or ""):lower()
	if rest == "-" or rest == "default" then rest = "" end
	if rest ~= "" and run.bridgeAgents and not Contains(run.bridgeAgents, rest) then
		AddHistory(c, "system", "알 수 없는 AI: \"" .. rest .. "\". 사용 가능: " .. AgentList())
		WoWForeverGPT.Render()
		return
	end
	local changed = rest ~= (c.agent or "")
	c.agent = rest
	-- 명령으로 고른 AI도 마지막 선택으로 기억한다. "default"로 되돌리면 기억도 지운다.
	db.settings.lastAgent = rest ~= "" and rest or nil
	if rest ~= "" then
		AddHistory(c, "system", "모델: " .. ChatAgentName(c) .. (changed and " (다음 질문부터 적용)" or ""))
	elseif changed then
		AddHistory(c, "system", "기본 모델로 되돌렸습니다: " .. ChatAgentName(c))
	else
		AddHistory(c, "system", "현재 모델: " .. ChatAgentName(c) .. " (변경: 창 오른쪽 위 모델 버튼 또는 /wow-ai agent " .. table.concat(run.bridgeAgents or { "gpt", "claude" }, "|") .. ")")
	end
	WoWForeverGPT.Render()
end

-- 모델 선택 버튼 글자: 이 대화에 적용될 모델 이름만 짧게 쓴다. 예: "Opus 5.5", "Sol 6.1"
function WoWForeverGPT.UpdateModelButton()
	local b = ui.modelButton
	if not b or not db then return end
	b:SetText(ChatAgentName(ActiveChat()))
end

-- 메뉴에서 모델을 고르면 그 회사의 선택으로 저장하고, 이 대화의 AI를 그 회사로 바꾼다.
function WoWForeverGPT.SelectModel(agent, model)
	local c = ActiveChat()
	if not c or not agent or not model then return end
	if run.bridgeAgents and not Contains(run.bridgeAgents, agent) then
		AddHistory(c, "system", "연결된 PC 프로그램이 " .. AgentName(agent) .. "를 지원하지 않습니다. 사용 가능: " .. AgentList())
		WoWForeverGPT.Render()
		return
	end
	local beforeAgent, beforeModel = ChatAgent(c), ChatModel(c)
	db.settings.models[agent] = model
	db.settings.lastAgent = agent     -- (마지막으로 고른 AI: 고르지 않은 대화와 새 대화가 따른다)
	c.agent = agent
	if beforeAgent ~= agent or beforeModel ~= model then
		AddHistory(c, "system", "모델: " .. (ModelLabel(agent, model) or model) .. (c.pendingId and " (진행 중인 답변 다음 질문부터 적용)" or " (다음 질문부터 적용)"))
	end
	WoWForeverGPT.Render()
end

StaticPopupDialogs["WOWFOREVERGPT_AGENT"] = {
	text = "이 대화에서 사용할 AI\n\n사용 가능: %s\n비워 두면 기본 AI(%s)를 사용합니다. 변경하면 새 세션을 시작합니다.",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = 1,
	editBoxWidth = 200,
	maxLetters = 32,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnShow = function(dialog, data)
		local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
		if box then
			box:SetText(data and data.agent or "")
			box:HighlightText()
			box:SetFocus()
		end
	end,
	OnAccept = function(dialog, data)
		local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
		local chat = data and FindChat(data.id)
		if chat and box then WoWForeverGPT.SetAgent(box:GetText(), chat) end
	end,
	EditBoxOnEnterPressed = function(box)
		local dialog = box:GetParent()
		StaticPopupDialogs["WOWFOREVERGPT_AGENT"].OnAccept(dialog, dialog.data)
		dialog:Hide()
	end,
	EditBoxOnEscapePressed = function(box)
		box:GetParent():Hide()
	end,
}

-- Agent dialog for a chat (the active one when no id is given).
function WoWForeverGPT.AgentPrompt(id)
	local c = (id and FindChat(id)) or ActiveChat()
	if not c then return end
	StaticPopup_Show("WOWFOREVERGPT_AGENT", AgentList(), run.bridgeAgent and AgentName(run.bridgeAgent) or "연결 후 확인 가능", { id = c.id, agent = c.agent or "" })
end

StaticPopupDialogs["WOWFOREVERGPT_RENAME"] = {
	text = "대화 이름 바꾸기",
	button1 = OKAY,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 24,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnShow = function(dialog, data)
		local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
		if box then
			box:SetText(data and data.name or "")
			box:HighlightText()
			box:SetFocus()
		end
	end,
	OnAccept = function(dialog, data)
		local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
		local chat = data and FindChat(data.id)
		local name = box and Trim(box:GetText() or "") or ""
		if chat and name ~= "" then
			chat.name = ShortTitle(name)
			WoWForeverGPT.Render()
		end
	end,
	EditBoxOnEnterPressed = function(box)
		local dialog = box:GetParent()
		StaticPopupDialogs["WOWFOREVERGPT_RENAME"].OnAccept(dialog, dialog.data)
		dialog:Hide()
	end,
	EditBoxOnEscapePressed = function(box)
		box:GetParent():Hide()
	end,
}

-- Rename dialog for a chat (the active one when no id is given).
function WoWForeverGPT.RenamePrompt(id)
	local c = (id and FindChat(id)) or ActiveChat()
	if not c then return end
	StaticPopup_Show("WOWFOREVERGPT_RENAME", nil, nil, { id = c.id, name = c.name })
end
WoWForeverGPT.RenameActive = WoWForeverGPT.RenamePrompt

-- Delete a chat (the active one when no id is given). The last chat is cleared
-- and renamed instead of removed, so there is always one to type into. Either
-- way the bridge is told to forget it, so a restore won't bring it back.
function WoWForeverGPT.DeleteChat(id)
	local c, idx = nil, nil
	if id then c, idx = FindChat(id) end
	if not c then c, idx = ActiveChat() end
	if not c then return end
	ForgetOnBridge(c)
	if #db.chats == 1 then
		wipe(c.history)
		c.pendingId, c.progress, c.unread, c.draft = nil, nil, 0, nil
		c.name = "질문 1"
		WoWForeverGPT.Render()
		WoWForeverGPT.RenderChatList()
		return
	end
	table.remove(db.chats, idx)
	if db.activeChat == c.id then
		WoWForeverGPT.SwitchChat(db.chats[math.min(idx, #db.chats)].id)
	else
		WoWForeverGPT.RenderChatList()
	end
end

-- The trash can on a chat row asks first; /wow-ai delete does not.
StaticPopupDialogs["WOWFOREVERGPT_DELETE"] = {
	text = "\"%s\" 대화를 삭제할까요?\n\n대화 기록이 삭제됩니다.\n마지막 남은 대화는 내용만 비워집니다.",
	button1 = OKAY,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnAccept = function(dialog, data)
		if data then WoWForeverGPT.DeleteChat(data.id) end
	end,
}

function WoWForeverGPT.ConfirmDelete(id)
	local c = (id and FindChat(id)) or ActiveChat()
	if not c then return end
	StaticPopup_Show("WOWFOREVERGPT_DELETE", Display(c.name), nil, { id = c.id })
end

---------------------------------------------------------------------------
-- Macros
---------------------------------------------------------------------------

-- The agent can hand over ready-made macros (a ```wowmacro block the bridge turns
-- into `macros` on the reply). Each gets a button under its message that creates
-- the macro, or updates the one with that name, and puts it on the cursor to drop
-- on an action bar. The addon never runs a macro; the player's own click does.

local MACRO_ACCOUNT_MAX = (Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_ACCOUNT_MACROS) or 120
local MACRO_CHAR_MAX = (Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS) or 30
local MACRO_DEFAULT_ICON = 134400 -- question mark: with #showtooltip the game shows the spell's icon

local function MacroSay(msg)
	print("|cff66ccff[" .. APP_NAME .. "]|r " .. msg)
end

-- Only well-formed entries survive (the slot file is trusted, but not blindly).
function WoWForeverGPT.CleanMacros(list)
	if type(list) ~= "table" then return nil end
	local out = {}
	for _, m in ipairs(list) do
		if type(m) == "table" and type(m.name) == "string" and m.name ~= "" and type(m.body) == "string" and m.body ~= "" then
			out[#out + 1] = {
				name = m.name, body = m.body, char = m.char == true, risky = m.risky == true,
				icon = (type(m.icon) == "number" or type(m.icon) == "string") and m.icon or nil,
			}
		end
	end
	return #out > 0 and out or nil
end

-- The macro called `name` among account (1..120) or character (121..150) macros:
-- the same name may exist in both, and only the requested kind counts.
local function FindMacro(name, perCharacter)
	local first = perCharacter and MACRO_ACCOUNT_MAX + 1 or 1
	local last = perCharacter and MACRO_ACCOUNT_MAX + MACRO_CHAR_MAX or MACRO_ACCOUNT_MAX
	for i = first, last do
		local n, icon, body = Try(GetMacroInfo, i)
		if n == name then return i, icon, body end
	end
end

local function MacroIcon(icon)
	if type(icon) == "number" then return icon end
	if type(icon) == "string" then
		local id = Try(GetFileIDFromPath, "Interface\\Icons\\" .. icon)
		if type(id) == "number" and id > 0 then return id end
		return icon -- CreateMacro also takes a texture name
	end
	return MACRO_DEFAULT_ICON
end

function WoWForeverGPT.MacroLabel(m)
	local verb = FindMacro(m.name, m.char) and "수정" or "만들기"
	return "매크로 " .. verb .. ": " .. Display(m.name) .. (m.char and " (캐릭터 전용)" or "") .. (m.risky and "  |cffff6060(코드 실행)|r" or "")
end

StaticPopupDialogs["WOWFOREVERGPT_MACRO"] = {
	text = "%s",
	button1 = OKAY,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	OnAccept = function(dialog, data)
		if data then WoWForeverGPT.InstallMacro(data, true) end
	end,
}

-- Create or update macro `m` ({ name, body, icon, char, risky }). Asks first when it
-- would replace a different macro of yours, or when it runs code (/run, /click...).
function WoWForeverGPT.InstallMacro(m, confirmed)
	if type(m) ~= "table" then return end
	if InCombatLockdown() then
		MacroSay("전투 중에는 매크로를 변경할 수 없습니다. 전투가 끝나면 다시 누르세요.")
		return
	end
	local index, _, oldBody = FindMacro(m.name, m.char)
	if not confirmed then
		local why = {}
		if m.risky then table.insert(why, "이 매크로는 코드를 실행하거나 버튼을 누릅니다 (/run, /script, /click). 내용을 확인하고 신뢰할 수 있을 때만 추가하세요.") end
		if index and oldBody ~= m.body then table.insert(why, "기존 매크로 \"" .. m.name .. "\"을 덮어씁니다. /wow-ai macro undo로 이전 내용을 복원할 수 있습니다.") end
		if #why > 0 then
			StaticPopup_Show("WOWFOREVERGPT_MACRO", table.concat(why, "\n\n") .. "\n\n" .. Display(m.body), nil, m)
			return
		end
	end
	-- Blizzard's macro window saves its edit box into its selected macro when it
	-- hides; close it first so that can't land on a macro we just moved.
	if MacroFrame and MacroFrame:IsShown() then
		Try(HideUIPanel, MacroFrame)
		index, _, oldBody = FindMacro(m.name, m.char)
	end
	local ok, newIndex
	if index then
		local _, oldIcon = FindMacro(m.name, m.char)
		ok, newIndex = pcall(EditMacro, index, m.name, m.icon ~= nil and MacroIcon(m.icon) or nil, m.body)
		if ok and type(newIndex) == "number" then
			db.macroUndo = { name = m.name, char = m.char, icon = oldIcon, body = oldBody }
		end
	else
		local acc, chr = Try(GetNumMacros)
		if m.char and type(chr) == "number" and chr >= MACRO_CHAR_MAX then
			MacroSay("캐릭터 전용 매크로가 가득 찼습니다 (" .. MACRO_CHAR_MAX .. "개). /macro에서 하나를 먼저 삭제하세요.")
			return
		elseif not m.char and type(acc) == "number" and acc >= MACRO_ACCOUNT_MAX then
			MacroSay("공통 매크로가 가득 찼습니다 (" .. MACRO_ACCOUNT_MAX .. "개). /macro에서 하나를 먼저 삭제하세요.")
			return
		end
		ok, newIndex = pcall(CreateMacro, m.name, MacroIcon(m.icon), m.body, m.char)
		if (not ok or type(newIndex) ~= "number") and m.icon ~= nil then
			ok, newIndex = pcall(CreateMacro, m.name, MACRO_DEFAULT_ICON, m.body, m.char)
		end
		if ok and type(newIndex) == "number" then
			db.macroUndo = { name = m.name, char = m.char, created = true }
		end
	end
	if not ok or type(newIndex) ~= "number" then
		MacroSay("매크로 \"" .. m.name .. "\" 저장 실패: " .. (ok and "게임에서 저장을 거부했습니다. 매크로 목록이 가득 찼는지 확인하세요." or tostring(newIndex)))
		return
	end
	-- EditMacro may move the macro (names are sorted): pick up the index it returned.
	Try(PickupMacro, newIndex)
	MacroSay("매크로 \"" .. m.name .. "\" " .. (index and "수정" or "생성") .. " 완료. 커서에 있는 매크로를 행동 단축바의 빈칸에 놓으세요. /macro에서도 확인할 수 있습니다.")
	WoWForeverGPT.Render()
end

function WoWForeverGPT.UndoMacro()
	local u = db.macroUndo
	if not u then MacroSay("되돌릴 매크로 변경이 없습니다."); return end
	if InCombatLockdown() then MacroSay("전투 중에는 매크로를 변경할 수 없습니다."); return end
	local index = FindMacro(u.name, u.char)
	if not index then MacroSay("매크로 \"" .. u.name .. "\"이 이미 삭제되었습니다."); db.macroUndo = nil; return end
	if MacroFrame and MacroFrame:IsShown() then Try(HideUIPanel, MacroFrame); index = FindMacro(u.name, u.char) end
	if u.created then
		Try(DeleteMacro, index)
		MacroSay("매크로 \"" .. u.name .. "\"을 삭제했습니다.")
	else
		Try(EditMacro, index, u.name, u.icon, u.body)
		MacroSay("매크로 \"" .. u.name .. "\"을 이전 내용으로 복원했습니다.")
	end
	db.macroUndo = nil
	WoWForeverGPT.Render()
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

function WoWForeverGPT.UpdateStatus()
	if not ui.status then return end
	local c = ActiveChat()
	local mode = db.settings.mode
	local status = "질문을 입력하고 Enter를 누르세요."
	if c and c.pendingId then
		local rec = run.outbound[c.pendingId]
		if run.slotsMissing or run.slotsExhausted then
			status = "응답 슬롯을 읽을 수 없습니다. 설치 상태를 확인하거나 UI를 새로고침하세요."
		elseif run.pixelFailed then
			status = "질문을 보내지 못했습니다. 브리지와 게임의 창 모드를 확인하세요."
		elseif mode == "reload" then
			status = "UI 새로고침으로 답변을 확인할 수 있습니다."
		elseif c.recoveryStalled then
			status = "응답 확인이 지연됩니다. 재전송을 눌러 복구하세요."
		elseif c.recovering then
			status = "답변을 다시 확인하고 있습니다…"
		elseif rec and not rec.acked then
			status = "질문 보내는 중…"
		else
			status = "AI 답변 중…"
		end
	elseif not WoWForeverGPT.IsConnected() then
		if run.connectingAt then
			status = "브리지에 연결 중…"
		elseif run.connectFailed then
			status = "연결 신호를 읽지 못했습니다. 다시 연결을 눌러 확인하세요."
		else
			-- 게임에서는 Windows 프로세스의 실행 여부를 알 수 없다.
			-- 신호 미수신을 프로그램 미실행으로 단정해 CMD 실행을 반복 안내하지 않는다.
			status = "연결 신호 확인 대기 · 아래 연결을 누르세요."
		end
	elseif run.restoring then
		status = "이전 대화를 불러오는 중…"
	end
	ui.status:SetText(status)
	WoWForeverGPT.UpdateDot()
	WoWForeverGPT.UpdateConnect()
	if ui.title then ui.title:SetText(c and (APP_NAME .. " · " .. Display(c.name)) or APP_NAME) end
	local needsRefresh = mode ~= "pixel" or run.slotsExhausted or run.slotsMissing or run.pixelFailed or false
	-- 두 보조 동작은 같은 자리를 사용한다. 슬롯이 소진되면 새로고침을 우선 표시해 겹침을 막는다.
	if ui.resend then ui.resend:SetShown(c and c.pendingId ~= nil and mode == "pixel" and not needsRefresh) end
	if ui.refresh then ui.refresh:SetShown(needsRefresh) end
	WoWForeverGPT.UpdateMini()
end

local function GetBubble(i)
	local b = ui.bubbles[i]
	if b then return b end
	b = CreateFrame("Frame", nil, ui.content)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.accent = b:CreateTexture(nil, "BORDER")
	b.accent:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.accent:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	b.accent:SetWidth(3)
	b.who = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.who:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -6)
	b.who:SetJustifyH("LEFT")
	b.when = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	b.when:SetPoint("TOPRIGHT", b, "TOPRIGHT", -8, -6)
	b.body = b:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
	b.body:SetPoint("TOPLEFT", b.who, "BOTTOMLEFT", 0, -4)
	b.body:SetJustifyH("LEFT")
	b.body:SetJustifyV("TOP")
	b.body:SetWordWrap(true)
	b.body:SetNonSpaceWrap(true)
	b.allow = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
	b.allow:SetHeight(22)
	b.allow:SetPoint("TOPLEFT", b.body, "BOTTOMLEFT", 0, -6)
	b.allow:SetScript("OnClick", function(self)
		WoWForeverGPT.Allow(self.chatId, self.rules)
	end)
	b.allow:Hide()
	b.macroBtns = {}
	b.mapBtns = {}
	b.entityBtns = {}
	-- FontStrings can't be selected, so a click opens the message in the copy box.
	b:EnableMouse(true)
	b:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self.text and self.text ~= "" then WoWForeverGPT.ShowCopy(self.text) end
	end)
	ui.bubbles[i] = b
	return b
end

function WoWForeverGPT.Render()
	local c = ActiveChat()
	if WoWForeverGPT.UpdateModelButton then WoWForeverGPT.UpdateModelButton() end
	if ui.content and c then
		local width = ui.scroll:GetWidth()
		if not width or width < 80 then width = 400 end
		ui.content:SetWidth(width)
		local y, n = 0, 0
		local function Place(role, text, when, dim, denied, agent, macros, model)
			n = n + 1
			local b = GetBubble(n)
			local st = ROLE_STYLE[role] or ROLE_STYLE.system
			b:SetWidth(width)
			b.bg:SetColorTexture(st.bg[1], st.bg[2], st.bg[3], st.bg[4])
			b.accent:SetColorTexture(st.color[1], st.color[2], st.color[3], 0.9)
			b.who:SetText(st == ROLE_STYLE.assistant and ReplyAgentName(c, agent, model) or st.label)
			b.who:SetTextColor(st.color[1], st.color[2], st.color[3])
			b.when:SetText(when or "")
			b.body:SetWidth(width - 18)
			-- 답변 원문은 기록에 남기고 화면/복사 표현만 별도로 만든다.
			-- 같은 메시지를 다시 그릴 때 재파싱하지 않도록 말풍선에 결과를 캐시한다.
			if b.sourceText ~= text or b.sourceRole ~= role then
				if role == "assistant" and TextFormat then
					local body
					if MapLinks then body, b.mapPoints = MapLinks.Parse(text) else body, b.mapPoints = text, {} end
					if EntityLinks then
						body, b.entityRefs = EntityLinks.Parse(body)
						for _, ref in ipairs(b.entityRefs) do EntityLinks.Request(ref) end
					end
					b.richText, b.copyText = TextFormat.Format(body)
				else
					b.richText, b.copyText = Display(text), text
					b.mapPoints = {}
					b.entityRefs = {}
				end
				b.sourceText, b.sourceRole = text, role
			end
			b.body:SetText(b.richText)
			if dim then
				b.body:SetTextColor(0.72, 0.72, 0.72)
			else
				b.body:SetTextColor(0.93, 0.93, 0.93)
			end
			local h = b.body:GetStringHeight()
			if not h or h < 1 then h = 14 end
			local extra = 0
			if denied then
				local label = "허용 후 재시도: " .. table.concat(denied, ", ")
				b.allow:SetText(label)
				b.allow:SetWidth(math.min(width - 24, math.max(160, b.allow:GetFontString():GetStringWidth() + 30)))
				b.allow.chatId = c.id
				b.allow.rules = denied
				b.allow:Show()
				extra = 28
			else
				b.allow:Hide()
			end
			-- One button per macro the agent handed over.
			local shownMacros = 0
			for k, m in ipairs(macros or {}) do
				local mb = b.macroBtns[k]
				if not mb then
					mb = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
					mb:SetHeight(22)
					mb:SetScript("OnClick", function(self) WoWForeverGPT.InstallMacro(self.macro) end)
					mb:SetScript("OnEnter", function(self)
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:AddLine(Display(self.macro.name))
						GameTooltip:AddLine(Display(self.macro.body), 1, 1, 1, true)
						GameTooltip:Show()
					end)
					mb:SetScript("OnLeave", function() GameTooltip:Hide() end)
					b.macroBtns[k] = mb
				end
				mb.macro = m
				mb:SetText(WoWForeverGPT.MacroLabel(m))
				mb:SetWidth(math.min(width - 24, math.max(160, mb:GetFontString():GetStringWidth() + 30)))
				mb:ClearAllPoints()
				mb:SetPoint("TOPLEFT", b.body, "BOTTOMLEFT", 0, -6 - extra)
				mb:Show()
				extra = extra + 28
				shownMacros = k
			end
			for k = shownMacros + 1, #b.macroBtns do b.macroBtns[k]:Hide() end
			-- 위치 링크는 FontString 대신 버튼으로 표시해 기존 답변 복사 기능과 분리한다.
			-- 재사용 말풍선의 남은 버튼은 반드시 숨겨 다른 답변의 위치가 남지 않게 한다.
			for k, point in ipairs(b.mapPoints or {}) do
				local link = b.mapBtns[k]
				if not link then
					link = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
					link:SetHeight(22)
					link:SetScript("OnClick", function(self) MapLinks.Open(self.point) end)
					b.mapBtns[k] = link
				end
				link.point = point
				link:SetText(MapLinks.Label(point))
				-- 고정 최소 너비 없이 [위치] 글자 양옆에 10px씩 여유를 둔다.
				link:SetWidth(link:GetFontString():GetStringWidth() + 20)
				link:ClearAllPoints()
				link:SetPoint("TOPLEFT", b.body, "BOTTOMLEFT", 0, -6 - extra)
				link:Show()
				extra = extra + 28
			end
			for k = #(b.mapPoints or {}) + 1, #b.mapBtns do b.mapBtns[k]:Hide() end
			-- 참조 버튼은 기존 텍스트 복사 영역과 별도로 동작하며 좁은 창에서는 줄바꿈한다.
			local entityCount, rowX, rowY = 0, 0, extra
			local function EntityButton(ref, compare)
				entityCount = entityCount + 1
				local button = b.entityBtns[entityCount]
				if not button then
					button = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
					button:SetHeight(22)
					button:SetScript("OnEnter", function(self) EntityLinks.Tooltip(self, self.ref) end)
					button:SetScript("OnLeave", EntityLinks.HideTooltip)
					button:SetScript("OnHide", EntityLinks.HideTooltip)
					button:SetScript("OnClick", function(self)
						if self.compare then WoWForeverGPT.CompareItem(self.ref)
						else EntityLinks.Click(self.ref, ui.input) end
					end)
					b.entityBtns[entityCount] = button
				end
				button.ref, button.compare = ref, compare
				button:SetText(compare and "장비 비교" or ("[" .. Display(ref.name) .. "]"))
				local bw = math.min(width - 24, button:GetFontString():GetStringWidth() + 20)
				if rowX > 0 and rowX + bw > width - 24 then rowX, rowY = 0, rowY + 28 end
				button:SetWidth(bw)
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", b.body, "BOTTOMLEFT", rowX, -6 - rowY)
				button:Show()
				rowX = rowX + bw + 4
			end
			for _, ref in ipairs(b.entityRefs or {}) do
				EntityButton(ref, false)
				if ref.kind == "item" and EntityLinks.Slots(ref.payload) then EntityButton(ref, true) end
			end
			for k = entityCount + 1, #b.entityBtns do b.entityBtns[k]:Hide() end
			if entityCount > 0 then extra = rowY + 28 end
			b:SetHeight(6 + 12 + 4 + h + 8 + extra)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 0, -y)
			b.text = b.copyText
			b:Show()
			y = y + b:GetHeight() + 6
		end
		local last = #c.history
		for i, m in ipairs(c.history) do
			-- The Allow button only makes sense on the newest reply, and only while idle.
			Place(m.role, m.text, m.t and date("%H:%M", m.t) or "", false, nil, m.agent, nil, m.model)
		end
		if c.pendingId then
			local sent = db.outbox and db.outbox.id == c.pendingId and db.outbox.model or nil
			Place("assistant", "답변을 기다리는 중…", "", true, nil, ChatAgent(c), nil, sent or ChatModel(c))
		elseif #c.history == 0 then
			if run.restoring then
				Place("system", "연결 후 이전 대화를 불러오는 중…", "", true)
			elseif not WoWForeverGPT.IsConnected() then
				Place("system", run.connectFailed and "PC 연결 프로그램에서 응답 신호를 받지 못했습니다. 프로그램이 이미 실행 중이라면 다시 켤 필요는 없습니다. 연결 진단: /wow-ai diag" or "아래 연결을 눌러 PC 연결 프로그램의 응답을 확인하세요.", "", true)
			else
				Place("system", "포에버에서 궁금한 내용을 입력하세요. 게임 채팅창에 /ai 질문을 입력해도 됩니다. 아이템이나 퀘스트는 Shift+클릭으로 첨부할 수 있습니다.", "", true)
			end
		end
		for i = n + 1, #ui.bubbles do
			ui.bubbles[i]:Hide()
		end
		ui.content:SetHeight(math.max(y, 1))
		C_Timer.After(0.05, function()
			if ui.scroll then
				ui.scroll:SetVerticalScroll(ui.scroll:GetVerticalScrollRange())
			end
		end)
	end
	WoWForeverGPT.UpdateStatus()
	WoWForeverGPT.RenderChatList()
	if WoWForeverGPT.UpdateQuickQuestions then WoWForeverGPT.UpdateQuickQuestions() end
end

-- Copy box (/wow-ai copy): a selectable EditBox with the last reply pre-highlighted for Ctrl+C.
function WoWForeverGPT.ShowCopy(text)
	if not ui.copy then
		local cf = CreateFrame("Frame", "WoWForeverGPTCopy", UIParent, "BackdropTemplate")
		cf:SetSize(560, 320)
		cf:SetPoint("CENTER")
		cf:SetFrameStrata("FULLSCREEN_DIALOG")
		cf:SetMovable(true)
		cf:SetClampedToScreen(true)
		cf:EnableMouse(true)
		cf:RegisterForDrag("LeftButton")
		cf:SetScript("OnDragStart", cf.StartMoving)
		cf:SetScript("OnDragStop", cf.StopMovingOrSizing)
		cf:SetBackdrop(BACKDROP)
		cf:SetBackdropColor(0.05, 0.05, 0.07, 0.97)
		cf:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
		tinsert(UISpecialFrames, "WoWForeverGPTCopy")

		local t = cf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		t:SetPoint("TOPLEFT", cf, "TOPLEFT", 14, -12)
		t:SetText("Ctrl+C로 복사하고 Esc로 닫으세요.")

		local x = CreateFrame("Button", nil, cf, "UIPanelCloseButton")
		x:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -4, -4)

		local sc = CreateFrame("ScrollFrame", "WoWForeverGPTCopyScroll", cf, "UIPanelScrollFrameTemplate")
		sc:SetPoint("TOPLEFT", cf, "TOPLEFT", 14, -36)
		sc:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -32, 14)
		local eb = CreateFrame("EditBox", "WoWForeverGPTCopyBox", sc)
		eb:SetMultiLine(true)
		eb:SetAutoFocus(false)
		eb:SetFontObject(ChatFontNormal)
		eb:SetMaxLetters(0)
		eb:SetSize(500, 260)
		eb:SetScript("OnEscapePressed", function() cf:Hide() end)
		sc:SetScrollChild(eb)
		sc:HookScript("OnSizeChanged", function(self, w) eb:SetWidth(w) end)
		ui.copy, ui.copyBox = cf, eb
	end
	ui.copyBox:SetText(TextFormat and TextFormat.Plain(text) or text)
	ui.copy:Show()
	ui.copyBox:SetFocus()
	ui.copyBox:HighlightText()
end

function WoWForeverGPT.RenderChatList()
	if not ui.chatButtons then return end
	if ui.chatListContent then ui.chatListContent:SetHeight(math.max(1, #db.chats * 21)) end
	for i, btn in ipairs(ui.chatButtons) do
		local c = db.chats[i]
		if c then
			local label = Display(c.name)
			local folder = FolderName(ChatFolder(c))
			if folder ~= "" and folder:lower() ~= c.name:lower() then
				label = label .. " |cff888888" .. Display(folder) .. "|r"
			end
			if c.agent and c.agent ~= "" then
				label = label .. " |cff888888" .. ChatAgentName(c) .. "|r"
			end
			if c.pendingId then
				label = label .. " |cffffd100...|r"
			elseif (c.unread or 0) > 0 then
				label = label .. " |cff55ff55(" .. c.unread .. ")|r"
			end
			btn.label:SetText(label)
			btn.chatId = c.id
			btn.selected:SetShown(c.id == db.activeChat)
			btn:Show()
		else
			btn:Hide()
		end
	end
end

function WoWForeverGPT.UpdateMini()
	if not ui.miniBadge then return end
	local unread, working = 0, 0
	for _, c in ipairs(db.chats) do
		unread = unread + (c.unread or 0)
		if c.pendingId then working = working + 1 end
	end
	local t
	if working > 0 and unread > 0 then
		t = "|cff55ff55" .. unread .. "개 도착|r |cffffd100" .. working .. "개 답변 중|r"
	elseif working > 0 then
		t = "|cffffd100" .. (working == 1 and "답변 중…" or (working .. "개 답변 중…")) .. "|r"
	elseif unread > 0 then
		t = "|cff55ff55" .. unread .. "개 답변 도착" .. "|r"
	else
		t = "|cff999999대기 중|r"
	end
	ui.miniBadge:SetText(t)
	if ui.miniPulse then
		if unread > 0 then
			if not ui.miniPulse:IsPlaying() then ui.miniPulse:Play() end
		else
			ui.miniPulse:Stop()
			ui.miniBadge:SetAlpha(1)
		end
	end
end

local ECHO_DEFAULT = 4000 -- characters of a reply to print into the game chat ("/wow-ai echo <n>")

local function ChatLinks(chat)
	return "  |Hwowforevergpt:reply:" .. chat.id .. "|h|cff55ff55[답장]|r|h |Hwowforevergpt:open:" .. chat.id .. "|h|cff7ec8ff[열기]|r|h"
end

local SUMMARY_LINES = 3 -- lines of the agent's TL;DR block printed in "summary" mode
local SUMMARY_FALLBACK_LINES = 2 -- lines of the reply shown when it came without one

-- Print a reply into the game chat: prefix on the first line, then the text line
-- by line up to the limit, then clickable links. `short` prints one preview line.
-- `summary` (the default) prints the TL;DR block the bridge split off the reply,
-- or the first lines of the reply when the agent didn't write one; the full text
-- is in the window, behind [open].
local function EchoToChat(chat, text, agent, summary)
	local mode = db.settings.echo
	if mode == "off" then return end
	local prefix = "|cff7ec8ff[" .. ReplyAgentName(chat, agent) .. " · " .. Display(chat.name) .. "]|r "
	local body = Display(text)
	if mode == "short" then
		local flat = (body:gsub("%s+", " "))
		if #flat > 200 then flat = Utf8Prefix(flat, 200) .. " ..." end
		print(prefix .. flat .. ChatLinks(chat))
		return
	end
	if mode == "summary" then
		local source, max = Display(summary or ""), SUMMARY_LINES
		if not source:match("%S") then source, max = body, SUMMARY_FALLBACK_LINES end
		local lines, total = {}, 0
		for line in (source .. "\n"):gmatch("(.-)\n") do
			if line:match("%S") then
				total = total + 1
				if total <= max then table.insert(lines, line) end
			end
		end
		for i, line in ipairs(lines) do
			print((i == 1 and prefix or "    ") .. line)
		end
		if total > max then
			print("    |cff888888... [열기]를 눌러 전체 답변을 확인하세요.|r")
		end
		print("    " .. ChatLinks(chat):sub(3))
		return
	end
	local limit = tonumber(mode) or ECHO_DEFAULT
	local first, shown = true, 0
	for line in (body .. "\n"):gmatch("(.-)\n") do
		if line:match("%S") then
			if shown + #line > limit then
				print("    |cff888888... 나머지 내용은 [열기]를 눌러 확인하세요.|r")
				break
			end
			print((first and prefix or "    ") .. line)
			first = false
			shown = shown + #line
		end
	end
	print("    " .. ChatLinks(chat):sub(3))
end

-- A reply landed. Always play the sound and echo it to the game chat; if that
-- chat isn't on screen, also flash the screen text and light up the mini bar.
function WoWForeverGPT.Notify(chat, text, agent, summary, model)
	pcall(PlaySound, 3081)
	WoWForeverGPT.UpdateMini()
	-- Until a real whisper arrives, /r replies to this chat.
	if ui.frame and ui.frame:IsShown() and db.activeChat == chat.id then return end
	if UIErrorsFrame then
		UIErrorsFrame:AddMessage(ReplyAgentName(chat, agent, model) .. " 답변 도착 · " .. Display(chat.name), 0.5, 0.8, 1, 1)
	end
end

-- /r goes to the agent when it was the last one to message you, exactly like
-- whisper reply, and the box shows a "To Codex [chat]:" header while you type.
--
-- The chat type underneath is left alone (a custom type would leak into chat
-- settings); instead the box remembers an agent target, the header is repainted
-- over the game's own, and the send entry points are intercepted. Any other chat
-- type, Tab, Esc or a cleared box drops the target again.
local AGENT_R, AGENT_G, AGENT_B = 0.49, 0.78, 1.0

local function PaintAgentHeader(eb, chat)
	local header = _G[eb:GetName() .. "Header"]
	local suffix = _G[eb:GetName() .. "HeaderSuffix"]
	if not header then return end
	eb.agentPainting = true
	eb:UpdateHeader() -- lay out normally first, then repaint
	eb.agentPainting = nil
	header:SetWidth(0)
	header:SetText(ChatAgentName(chat) .. "에게 [" .. Display(chat.name) .. "]: ")
	header:SetTextColor(AGENT_R, AGENT_G, AGENT_B)
	if suffix then suffix:Hide() end
	eb:SetTextInsets(15 + header:GetWidth(), 13, 0, 0)
	eb:SetTextColor(AGENT_R, AGENT_G, AGENT_B)
end

local function SendBoxToAgent(eb)
	local chat = FindChat(eb.agentTarget)
	local text = Trim(eb:GetText() or "")
	eb.agentTarget = nil
	eb:ClearChat()
	if chat and db.activeChat ~= chat.id then WoWForeverGPT.SwitchChat(chat.id) end
	if text ~= "" then
		WoWForeverGPT.Send(text)
	else
		WoWForeverGPT.Toggle(true)
		if ui.input then ui.input:SetFocus() end
	end
end

local function HookReplyCommand()
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local eb = _G["ChatFrame" .. i .. "EditBox"]
		if eb and eb.ProcessChatType and not eb.agentReplyHooked then
			eb.agentReplyHooked = true

			local origProcess = eb.ProcessChatType
			eb.ProcessChatType = function(self, msg, index, send, ...)
				if index ~= "REPLY" then
					self.agentTarget = nil
					return origProcess(self, msg, index, send, ...)
				end
				if not (db and run.lastMessenger == "agent") then
					return origProcess(self, msg, index, send, ...)
				end
				local chat = FindChat(run.lastReplyChat) or ActiveChat()
				if send == 1 then
					self:SetText(msg or "")
					self.agentTarget = chat and chat.id
					SendBoxToAgent(self)
					return true
				end
				self.agentTarget = chat and chat.id
				self:SetText(msg or "")
				if chat then PaintAgentHeader(self, chat) end
				return true
			end

			-- Enter arrives here; nothing below us ever sees an agent-targeted box.
			for _, name in ipairs({ "SendMessage", "SendText" }) do
				local orig = eb[name]
				if orig then
					eb[name] = function(self, ...)
						if self.agentTarget then
							SendBoxToAgent(self)
							return
						end
						return orig(self, ...)
					end
				end
			end

			-- Anything that repaints the header normally (Tab, /s, sticky reset) ends agent mode.
			hooksecurefunc(eb, "UpdateHeader", function(self)
				if not self.agentPainting then self.agentTarget = nil end
			end)
			hooksecurefunc(eb, "ClearChat", function(self)
				self.agentTarget = nil
			end)
		end
	end
end

-- Clicks on our [reply] / [open] links in the chat frame.
hooksecurefunc("SetItemRef", function(link)
	local action, chatId = tostring(link):match("^wowforevergpt:(%a+):(%w+)")
	if not action or not db then return end
	if FindChat(chatId) then WoWForeverGPT.SwitchChat(chatId) end
	WoWForeverGPT.Toggle(true)
	if action == "reply" and ui.input then ui.input:SetFocus() end
end)

-- Shift-clicking an item, spell, quest or name puts its link into the chat box
-- being typed in. Blizzard's insert function only knows its own boxes, so when
-- ours has the keyboard, take the link too. With no box focused the shift-click
-- keeps its normal meaning (splitting a stack, for one).
--
-- On this client (modern UI code, Blizzard_ChatFrameUtil) every shift-click
-- ends in ChatFrameUtil.InsertLink; ChatEdit_InsertLink is the older global
-- name, hooked only where the new one is missing so one click inserts once.
local function TakeLink(text)
	if text and text ~= "" and ui.input and ui.input:HasFocus() then
		ui.input:Insert(text)
	end
end
if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
	hooksecurefunc(ChatFrameUtil, "InsertLink", TakeLink)
elseif type(ChatEdit_InsertLink) == "function" then
	hooksecurefunc("ChatEdit_InsertLink", TakeLink)
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local function MakeButton(parent, label, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

-- 빠른 질문은 버튼 클릭 시점의 대상/선택 퀘스트/장착 장비를 다시 읽는다.
-- 답변 대기 중에는 비활성화하고, 기존에 입력 중인 초안은 덮어쓰지 않는다.
function WoWForeverGPT.CompareItem(ref)
	local chat = ActiveChat()
	if not chat or chat.pendingId then return end
	WoWForeverGPT.Send(EntityLinks.Link(ref) .. " 이 아이템을 같은 부위의 현재 장비와 비교해 줘. 실제 툴팁·직업·레벨·특성을 기준으로 교체 여부와 핵심 차이를 알려줘. 누락된 옵션이나 DPS는 추측하지 마.")
end

function WoWForeverGPT.QuickQuestion(kind)
	local chat = ActiveChat()
	if not chat or chat.pendingId or not EntityLinks then return end
	if kind == "item" then
		local payload = EntityLinks.FirstItem(ui.input:GetText())
		if not payload then return end
		local id = tonumber(payload:match("^item:(%d+)"))
		if EntityLinks.Slots(payload) then
			WoWForeverGPT.CompareItem({kind="item", id=id, payload=payload, name="첨부 아이템"})
		else
			WoWForeverGPT.Send(EntityLinks.Link({kind="item", id=id, payload=payload, name="첨부 아이템"}) .. " 이 아이템의 용도와 내 캐릭터에게 유용한지 알려줘. 실제 툴팁에 없는 정보는 추측하지 마.")
		end
	elseif kind == "target" then
		local name = Try(UnitName, "target")
		if type(name) ~= "string" then return end
		WoWForeverGPT.Send("현재 선택한 대상 " .. name .. "에 대해 알려줘. 관련 퀘스트·상점·기능 또는 전투에서 주의할 점을 내 현재 상황에 맞춰 설명해 줘.")
	elseif kind == "quest" then
		local id = EntityLinks.QuestID()
		if not id then return end
		local title = Try(C_QuestLog and C_QuestLog.GetTitleForQuestID, id) or "선택 퀘스트"
		WoWForeverGPT.Send("현재 선택한 퀘스트 " .. title .. " (#" .. id .. ")의 현재 진행도에서 다음에 할 행동을 알려줘. 이동 목적지는 [위치] 버튼으로 안내해 줘.")
	end
end

function WoWForeverGPT.UpdateQuickQuestions()
	if not ui.quickButtons or not EntityLinks then return end
	local actions = EntityLinks.Actions(ui.input:GetText())
	local x, chat = 0, ActiveChat()
	for i, button in ipairs(ui.quickButtons) do
		local action = actions[i]
		if action then
			button.kind = action.kind
			button:SetText(action.label)
			local w = button:GetFontString():GetStringWidth() + 20
			button:SetWidth(w)
			button:ClearAllPoints()
			button:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", 8 + x, 84)
			button:SetEnabled(chat and not chat.pendingId and true or false)
			button:Show()
			x = x + w + 4
		else button:Hide() end
	end
	-- 앵커가 바뀔 때만 적용해 OnSizeChanged → Render의 반복 호출을 막는다.
	local bottom = #actions > 0 and 114 or 86
	if ui.quickBottom ~= bottom then
		ui.quickBottom = bottom
		ui.scroll:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -26, bottom)
	end
end

local PANEL_W = 112

function WoWForeverGPT.ApplyCompactLayout()
	if not ui.frame or not ui.sidebar or not ui.scroll then return end
	local open = db.settings.sidebarOpen == true
	ui.sidebar:SetShown(open)
	if ui.sidebarToggle then ui.sidebarToggle:SetText(open and "접기" or "목록") end
	if ui.chatMenu then ui.chatMenu:Hide() end
	-- 목록을 감추면 동일한 창 크기 안에서 답변 영역이 바로 넓어진다.
	ui.scroll:ClearAllPoints()
	ui.scroll:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", open and (8 + PANEL_W + 6) or 8, -44)
	ui.scroll:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -26, ui.quickBottom or 86)
	if ui.frame:IsShown() then WoWForeverGPT.Render() end
end

function WoWForeverGPT.ToggleSidebar()
	db.settings.sidebarOpen = not db.settings.sidebarOpen
	WoWForeverGPT.ApplyCompactLayout()
end

local function BuildUI()
	if ui.frame then return end
	local s = db.settings

	local f = CreateFrame("Frame", "WoWForeverGPTFrame", UIParent, "BackdropTemplate")
	ui.frame = f
	f:SetSize(s.width, s.height)
	if s.point then
		f:SetPoint(s.point, UIParent, s.relPoint or s.point, s.x or 0, s.y or 0)
	else
		f:SetPoint("CENTER")
	end
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:SetResizable(true)
	f:SetClampedToScreen(true)
	f:SetResizeBounds(380, 260)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		s.point, s.relPoint, s.x, s.y = point, relPoint, x, y
	end)
	f:SetBackdrop(BACKDROP)
	f:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
	f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	f:Hide()
	tinsert(UISpecialFrames, "WoWForeverGPTFrame")

	-- Status light: green = bridge seen recently, yellow = stale, red = gone.
	local function MakeDot(parent)
		local holder = CreateFrame("Frame", nil, parent)
		holder:SetSize(12, 12)
		local dot = holder:CreateTexture(nil, "OVERLAY")
		dot:SetAllPoints()
		dot:SetTexture("Interface\\FriendsFrame\\StatusIcon-Offline")
		holder:EnableMouse(true)
		holder:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(dot.tip or "연결 상태", 0.9, 0.9, 0.9, 1, true)
			GameTooltip:Show()
		end)
		holder:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return holder, dot
	end

	local sidebarToggle = MakeButton(f, "목록", 36, WoWForeverGPT.ToggleSidebar)
	sidebarToggle:SetHeight(20)
	sidebarToggle:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
	sidebarToggle:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(db.settings.sidebarOpen and "대화 목록 접기" or "대화 목록 펼치기")
		GameTooltip:Show()
	end)
	sidebarToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
	ui.sidebarToggle = sidebarToggle
	local dotHolder, dot = MakeDot(f)
	dotHolder:SetPoint("LEFT", sidebarToggle, "RIGHT", 4, 0)
	ui.dot = dot

	-- 모델 선택: 헤더 오른쪽 버튼을 누르면 회사별로 묶인 모델 목록이 열린다.
	-- 고른 모델은 그 회사의 기본 선택으로 저장되고, 이 대화의 AI도 그 회사로 바뀐다.
	local modelBtn = MakeButton(f, "", 136, nil)
	modelBtn:SetHeight(20)
	modelBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -6)
	if modelBtn.SetNormalFontObject then modelBtn:SetNormalFontObject("GameFontHighlightSmall") end
	if modelBtn.SetHighlightFontObject then modelBtn:SetHighlightFontObject("GameFontHighlightSmall") end
	ui.modelButton = modelBtn

	local modelMenu = CreateFrame("Frame", "WoWForeverGPTModelMenu", f, "BackdropTemplate")
	modelMenu:SetWidth(176)
	modelMenu:SetFrameStrata("TOOLTIP")
	modelMenu:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	modelMenu:SetBackdropColor(0.08, 0.08, 0.1, 0.97)
	modelMenu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	modelMenu:EnableMouse(true)
	modelMenu.rows = {}
	modelMenu:Hide()
	ui.modelMenu = modelMenu

	local MENU_ROW = 18
	local function MenuRow(i)
		local row = modelMenu.rows[i]
		if row then return row end
		row = CreateFrame("Button", nil, modelMenu)
		row:SetSize(176 - 12, MENU_ROW)
		row:SetPoint("TOPLEFT", modelMenu, "TOPLEFT", 6, -6 - (i - 1) * MENU_ROW)
		row.hl = row:CreateTexture(nil, "HIGHLIGHT")
		row.hl:SetAllPoints()
		row.hl:SetColorTexture(1, 1, 1, 0.12)
		row.check = row:CreateTexture(nil, "OVERLAY")
		row.check:SetSize(14, 14)
		row.check:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.label:SetPoint("LEFT", row, "LEFT", 18, 0)
		row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
		row.label:SetJustifyH("LEFT")
		row.label:SetWordWrap(false)
		row:SetScript("OnClick", function(self)
			if not self.agent then return end
			modelMenu:Hide()
			WoWForeverGPT.SelectModel(self.agent, self.model)
		end)
		modelMenu.rows[i] = row
		return row
	end

	function WoWForeverGPT.ShowModelMenu()
		if modelMenu:IsShown() then modelMenu:Hide() return end
		local c = ActiveChat()
		local current = ChatAgent(c)
		local n = 0
		for _, agent in ipairs(run.bridgeAgents or { "gpt", "claude" }) do
			local m = ModelsFor(agent)
			if m then
				n = n + 1
				local head = MenuRow(n)
				head.agent, head.model = nil, nil
				head:EnableMouse(false)
				head.check:Hide()
				head.label:SetFontObject("GameFontNormalSmall")
				head.label:SetTextColor(1, 0.82, 0)
				-- 묶음 제목은 회사 이름만 쓴다(OpenAI / Anthropic).
				local company = (m.company and m.company ~= "") and m.company or AgentName(agent)
				head.label:SetText(company .. (agent == current and "  (사용 중)" or ""))
				head:Show()
				local chosen = (db.settings.models and db.settings.models[agent]) or m.default
				local valid = false
				for _, o in ipairs(m.options) do if o.id == chosen then valid = true end end
				if not valid then chosen = m.default end
				for _, o in ipairs(m.options) do
					n = n + 1
					local row = MenuRow(n)
					row.agent, row.model = agent, o.id
					row:EnableMouse(true)
					row.label:SetFontObject("GameFontHighlightSmall")
					row.label:SetText("   " .. (o.label or o.id))
					row.check:SetShown(o.id == chosen)
					if agent == current and o.id == chosen then
						row.label:SetTextColor(0.55, 1, 0.55)
					else
						row.label:SetTextColor(0.9, 0.9, 0.9)
					end
					row:Show()
				end
			end
		end
		for i = n + 1, #modelMenu.rows do modelMenu.rows[i]:Hide() end
		modelMenu:SetHeight(n * MENU_ROW + 12)
		modelMenu:ClearAllPoints()
		modelMenu:SetPoint("TOPRIGHT", modelBtn, "BOTTOMRIGHT", 0, -2)
		modelMenu.away = 0
		modelMenu:Show()
	end

	-- 마우스가 메뉴와 버튼 밖으로 나가면 잠시 뒤 닫는다(대화 우클릭 메뉴와 같은 방식).
	modelMenu:SetScript("OnUpdate", function(self, dt)
		if not MouseIsOver then return end
		if MouseIsOver(self) or MouseIsOver(modelBtn) then
			self.away = 0
		else
			self.away = (self.away or 0) + dt
			if self.away > 0.6 then self:Hide() end
		end
	end)

	modelBtn:SetScript("OnClick", function() WoWForeverGPT.ShowModelMenu() end)
	modelBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText("AI 모델 선택")
		GameTooltip:AddLine("회사별 모델 목록에서 고릅니다. 이 대화의 AI가 그 회사로 바뀌고, 고른 모델은 다음 질문부터 쓰입니다.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	modelBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("LEFT", dotHolder, "RIGHT", 4, 0)
	-- 양쪽 기준점의 높이를 헤더 중앙(-16)으로 맞춘다. 창 중앙을 기준으로
	-- 잡으면 창 크기를 바꿀 때 제목 영역이 세로로 늘어나 본문과 겹칠 수 있다.
	-- 오른쪽 끝은 모델 선택 버튼 앞에서 멈춘다.
	title:SetPoint("RIGHT", modelBtn, "LEFT", -4, 0)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetText(APP_NAME)
	ui.title = title

	local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	status:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -29)
	status:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -29)
	status:SetJustifyH("LEFT")
	ui.status = status

	-- Minimize button in the corner where a close X would be: this window is never
	-- closed from here, only collapsed to the mini bar (Esc does the same, see OnHide).
	-- The mini bar's own X is the one that hides everything.
	local mini
	if C_Texture and C_Texture.GetAtlasExists and C_Texture.GetAtlasExists("RedButton-MiniCondense") then
		-- Blizzard's own minimize button: the close button's chrome with a "condense" glyph.
		local ok, b = pcall(CreateFrame, "Button", nil, f, "UIPanelHideButtonNoScripts")
		if ok and b then mini = b end
	end
	if not mini then
		-- Older art: draw a dash on a plain button.
		mini = CreateFrame("Button", nil, f)
		mini:SetSize(24, 24)
		local dash = mini:CreateTexture(nil, "ARTWORK")
		dash:SetSize(10, 2)
		dash:SetPoint("CENTER", mini, "CENTER", 0, -3)
		dash:SetColorTexture(0.9, 0.9, 0.9, 1)
		local hl = mini:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.15)
	end
	mini:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
	mini:SetScript("OnClick", function() WoWForeverGPT.Minimize(true) end)
	mini:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("작은 바로 접기 (Esc)")
		GameTooltip:AddLine("답변이 도착하면 접힌 바에 표시됩니다.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	mini:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Esc (via UISpecialFrames) just calls Hide(); treat that as a minimize unless
	-- we're hiding on purpose. Ignore hides caused by the whole UI going away.
	f:SetScript("OnHide", function()
		if ui.quitting then
			ui.quitting = nil
			return
		end
		if not db or not db.settings.shown or not UIParent:IsShown() then return end
		db.settings.minimized = true
		if ui.mini then ui.mini:Show() end
		WoWForeverGPT.UpdateMini()
	end)

	-- Left panel: chat list
	local panel = CreateFrame("Frame", nil, f, "BackdropTemplate")
	panel:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -44)
	panel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 86)
	panel:SetWidth(PANEL_W)
	ui.sidebar = panel
	panel:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	panel:SetBackdropColor(0, 0, 0, 0.4)
	panel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

	local listTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	listTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
	listTitle:SetText("대화 목록")
	-- 작은 창에서도 목록이 입력창 밖으로 넘치지 않도록 목록 자체를 스크롤한다.
	local listScroll = CreateFrame("ScrollFrame", nil, panel)
	listScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -24)
	listScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 4)
	local listContent = CreateFrame("Frame", nil, listScroll)
	listContent:SetSize(PANEL_W - 8, MAX_CHATS * 21)
	listScroll:SetScrollChild(listContent)
	listScroll:EnableMouseWheel(true)
	listScroll:SetScript("OnMouseWheel", function(self, delta)
		self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 42)))
	end)
	ui.chatListContent = listContent

	-- Per-chat menu: Rename, Folder and Agent, opened by right-clicking a chat
	-- row. A plain frame of our own rather than a Blizzard dropdown, so it looks
	-- the same on every client.
	local menu = CreateFrame("Frame", "WoWForeverGPTChatMenu", f, "BackdropTemplate")
	menu:SetSize(110, 2 * 20 + 12)
	menu:SetFrameStrata("TOOLTIP")
	menu:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	menu:SetBackdropColor(0.08, 0.08, 0.1, 0.97)
	menu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	menu:EnableMouse(true)
	menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -8)
	menu.title:SetPoint("RIGHT", menu, "RIGHT", -8, 0)
	menu.title:SetJustifyH("LEFT")
	menu.title:SetWordWrap(false)
	local function MenuItem(label, order, onClick)
		local it = CreateFrame("Button", nil, menu)
		it:SetSize(110 - 12, 20)
		it:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - order * 20)
		local hl = it:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.12)
		it.label = it:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		it.label:SetPoint("LEFT", it, "LEFT", 6, 0)
		it.label:SetText(label)
		it:SetScript("OnClick", function()
			menu:Hide()
			onClick(menu.chatId)
		end)
		return it
	end
	MenuItem("이름 바꾸기", 1, WoWForeverGPT.RenamePrompt)
	-- Close once the mouse has wandered away from the menu and the row it came from.
	menu:SetScript("OnUpdate", function(self, dt)
		if not MouseIsOver then return end
		if MouseIsOver(self) or (self.owner and MouseIsOver(self.owner)) then
			self.away = 0
		else
			self.away = (self.away or 0) + dt
			if self.away > 0.5 then self:Hide() end
		end
	end)
	menu:Hide()
	ui.chatMenu = menu

	function WoWForeverGPT.ShowChatMenu(chatId, anchor)
		local c = FindChat(chatId)
		if not c then return end
		if menu:IsShown() and menu.chatId == chatId then
			menu:Hide()
			return
		end
		menu.chatId = chatId
		menu.owner = anchor
		menu.away = 0
		menu.title:SetText(Display(c.name))
		menu:ClearAllPoints()
		menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 8, 2)
		menu:Show()
	end

	ui.chatButtons = {}
	for i = 1, MAX_CHATS do
		local b = CreateFrame("Button", nil, listContent)
		b:SetSize(PANEL_W - 8, 20)
		b:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i - 1) * 21)
		b.selected = b:CreateTexture(nil, "BACKGROUND")
		b.selected:SetAllPoints()
		b.selected:SetColorTexture(1, 1, 1, 0.12)
		b.selected:Hide()
		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.08)

		-- Trash can: delete this chat (asks first). Blizzard's red delete button
		-- where the client has it, a plain X elsewhere.
		b.del = CreateFrame("Button", nil, b)
		b.del:SetSize(16, 16)
		b.del:SetPoint("RIGHT", b, "RIGHT", -2, 0)
		if C_Texture and C_Texture.GetAtlasExists and C_Texture.GetAtlasExists("128-RedButton-Delete") then
			b.del:SetNormalAtlas("128-RedButton-Delete")
			b.del:SetPushedAtlas("128-RedButton-Delete-Pressed")
			b.del:SetHighlightAtlas("128-RedButton-Delete-Highlight")
		else
			b.del:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
			b.del:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
		end
		b.del:SetAlpha(0.6)
		b.del:SetScript("OnClick", function() WoWForeverGPT.ConfirmDelete(b.chatId) end)
		b.del:SetScript("OnEnter", function(self)
			self:SetAlpha(1)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("이 대화 삭제")
			GameTooltip:Show()
		end)
		b.del:SetScript("OnLeave", function(self)
			self:SetAlpha(0.6)
			GameTooltip:Hide()
		end)

		b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
		b.label:SetPoint("RIGHT", b.del, "LEFT", -4, 0)
		b.label:SetJustifyH("LEFT")
		b.label:SetWordWrap(false)
		-- Left-click switches to the chat; right-click opens its menu (Rename,
		-- Folder, Agent). A second right-click on the same row closes the menu again.
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", function(self, button)
			if button == "RightButton" then
				WoWForeverGPT.ShowChatMenu(self.chatId, self)
			else
				WoWForeverGPT.SwitchChat(self.chatId)
			end
		end)
		b:SetScript("OnDoubleClick", function(self)
			WoWForeverGPT.SwitchChat(self.chatId)
			WoWForeverGPT.RenamePrompt(self.chatId)
		end)
		b:Hide()
		ui.chatButtons[i] = b
	end

	-- Transcript: a scrolling stack of message bubbles
	local scroll = CreateFrame("ScrollFrame", "WoWForeverGPTScroll", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -44)
	scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 86)
	ui.scroll = scroll

	local content = CreateFrame("Frame", "WoWForeverGPTContent", scroll)
	content:SetSize(500, 1)
	scroll:SetScrollChild(content)
	ui.content = content
	ui.bubbles = {}
	scroll:HookScript("OnSizeChanged", function(self, w, h)
		if ui.frame:IsShown() then WoWForeverGPT.Render() end
	end)

	-- Input box, with Send docked at its right end like a messaging app.
	local SEND_W = 64
	local inputBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
	inputBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 36)
	inputBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8 - SEND_W - 6, 36)
	inputBg:SetHeight(42)
	inputBg:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	inputBg:SetBackdropColor(0, 0, 0, 0.6)
	inputBg:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

	local inScroll = CreateFrame("ScrollFrame", "WoWForeverGPTInputScroll", inputBg, "UIPanelScrollFrameTemplate")
	inScroll:SetPoint("TOPLEFT", inputBg, "TOPLEFT", 6, -4)
	inScroll:SetPoint("BOTTOMRIGHT", inputBg, "BOTTOMRIGHT", -24, 4)

	local input = CreateFrame("EditBox", "WoWForeverGPTInput", inScroll)
	input:SetMultiLine(true)
	input:SetAutoFocus(false)
	input:SetFontObject(ChatFontNormal)
	input:SetMaxLetters(0)
	input:SetSize(500, 30)
	input:SetScript("OnEnterPressed", function() WoWForeverGPT.SendFromInput() end)
	input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	inScroll:SetScrollChild(input)
	inScroll:HookScript("OnSizeChanged", function(self, w, h)
		input:SetWidth(w)
	end)
	inputBg:SetScript("OnMouseDown", function() input:SetFocus() end)
	ui.input = input
	ui.quickButtons = {}
	for i = 1, 3 do
		local button = MakeButton(f, "", 80, function(self) WoWForeverGPT.QuickQuestion(self.kind) end)
		button:Hide()
		ui.quickButtons[i] = button
	end
	input:HookScript("OnTextChanged", function() WoWForeverGPT.UpdateQuickQuestions() end)
	-- 창을 열어 둔 동안에만 버튼 표시를 갱신한다. 툴팁/장비 스캔은 전송 시 수행한다.
	local contextEvents = CreateFrame("Frame")
	for _, event in ipairs({"PLAYER_TARGET_CHANGED", "QUEST_LOG_UPDATE", "SUPER_TRACKING_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "ITEM_DATA_LOAD_RESULT"}) do
		pcall(contextEvents.RegisterEvent, contextEvents, event)
	end
	local itemRedrawQueued = false
	contextEvents:SetScript("OnEvent", function(_, event)
		if ui.frame:IsShown() then
			if event == "ITEM_DATA_LOAD_RESULT" then
				-- A load result may arrive inside Render. Defer and combine redraws.
				if itemRedrawQueued then return end
				itemRedrawQueued = true
				C_Timer.After(0, function()
					itemRedrawQueued = false
					if ui.frame:IsShown() then WoWForeverGPT.Render() end
				end)
			else WoWForeverGPT.UpdateQuickQuestions() end
		end
	end)

	-- Send sits to the right of the input box, vertically centred on it.
	local send = MakeButton(f, "보내기", SEND_W, WoWForeverGPT.SendFromInput)
	send:SetHeight(26)
	send:SetPoint("LEFT", inputBg, "RIGHT", 6, 0)
	ui.send = send

	-- Connect stands in for Send until the bridge has been seen (see UpdateConnect).
	local connect = MakeButton(f, "연결", SEND_W, WoWForeverGPT.Connect)
	connect:SetHeight(26)
	connect:SetPoint("LEFT", inputBg, "RIGHT", 6, 0)
	connect:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(APP_NAME .. " 연결")
		GameTooltip:AddLine("실행 중인 PC 연결 프로그램에 응답을 요청합니다. 연결되면 상태등이 초록색으로 바뀝니다.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	connect:SetScript("OnLeave", function() GameTooltip:Hide() end)
	connect:Hide()
	ui.connect = connect

	-- Reload is the fallback transport's button; it sits apart on the right and
	-- only shows when a reload would do something (see UpdateStatus).
	local refresh = MakeButton(f, "새로고침", 72, function() SafeReload() end)
	refresh:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 8)
	refresh:Hide()
	ui.refresh = refresh

	-- Bottom row: Clear, plus Resend while a message is in flight. Rename, Folder
	-- and Delete live on each chat row in the left panel.
	local newQuestion = MakeButton(f, "새 질문", 64, function() WoWForeverGPT.NewChat() end)
	newQuestion:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
	local clear = MakeButton(f, "비우기", 56, function()
		local c = ActiveChat()
		if c and not c.pendingId then
			wipe(c.history)
			c.resetNext = true
		end
		WoWForeverGPT.Render()
	end)
	clear:SetPoint("LEFT", newQuestion, "RIGHT", 4, 0)

	local resend = MakeButton(f, "재전송", 72, function() WoWForeverGPT.RecoverPending() end)
	resend:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 8)
	resend:Hide()
	ui.resend = resend

	local effort = MakeButton(f, "추론: " .. EFFORT_LABEL[s.effort], 84, function(button)
		s.effort = NEXT_EFFORT[s.effort]
		button:SetText("추론: " .. EFFORT_LABEL[s.effort])
	end)
	effort:SetPoint("LEFT", clear, "RIGHT", 4, 0)
	effort:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_TOP")
		GameTooltip:SetText("추론 강도")
		GameTooltip:AddLine("클릭하면 낮음 → 보통 → 높음 순으로 바뀝니다. GPT와 Claude에 모두 적용되며 다음 질문부터 쓰입니다.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	effort:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- A named, always-present button so a keybinding can click it (see /wow-ai bind).
	local hotkey = CreateFrame("Button", "WoWForeverGPTRefreshButton", UIParent)
	hotkey:SetSize(1, 1)
	hotkey:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
	hotkey:SetScript("OnClick", function()
		local c = ActiveChat()
		if c and c.pendingId then
			WoWForeverGPT.Send("")
		else
			WoWForeverGPT.Toggle()
		end
	end)

	-- Resize grip
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
	grip:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		s.width, s.height = f:GetSize()
	end)

	-- Mini bar: what the window collapses into. Click it to expand, drag to move.
	local m = CreateFrame("Frame", "WoWForeverGPTMini", UIParent, "BackdropTemplate")
	ui.mini = m
	m:SetSize(220, 26)
	if s.miniPoint then
		m:SetPoint(s.miniPoint, UIParent, s.miniRelPoint or s.miniPoint, s.miniX or 0, s.miniY or 0)
	else
		m:SetPoint("TOP", UIParent, "TOP", 0, -40)
	end
	m:SetFrameStrata("DIALOG")
	m:SetMovable(true)
	m:SetClampedToScreen(true)
	m:EnableMouse(true)
	m:RegisterForDrag("LeftButton")
	m:SetScript("OnDragStart", function(self)
		self.dragging = true
		self:StartMoving()
	end)
	m:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint()
		s.miniPoint, s.miniRelPoint, s.miniX, s.miniY = point, relPoint, x, y
		C_Timer.After(0, function() self.dragging = nil end)
	end)
	m:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and not self.dragging then
			WoWForeverGPT.Minimize(false)
		end
	end)
	m:SetBackdrop(BACKDROP)
	m:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
	m:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	m:Hide()

	local miniDotHolder, miniDot = MakeDot(m)
	miniDotHolder:SetPoint("LEFT", m, "LEFT", 9, 0)
	ui.miniDot = miniDot

	local mlabel = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	mlabel:SetPoint("LEFT", miniDotHolder, "RIGHT", 6, 0)
	mlabel:SetText(APP_NAME)

	local badge = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	badge:SetPoint("LEFT", mlabel, "RIGHT", 8, 0)
	badge:SetPoint("RIGHT", m, "RIGHT", -26, 0)
	badge:SetJustifyH("LEFT")
	badge:SetWordWrap(false)
	ui.miniBadge = badge

	local ok, pulse = pcall(function()
		local g = badge:CreateAnimationGroup()
		local a1 = g:CreateAnimation("Alpha")
		a1:SetFromAlpha(1)
		a1:SetToAlpha(0.25)
		a1:SetDuration(0.6)
		a1:SetOrder(1)
		local a2 = g:CreateAnimation("Alpha")
		a2:SetFromAlpha(0.25)
		a2:SetToAlpha(1)
		a2:SetDuration(0.6)
		a2:SetOrder(2)
		g:SetLooping("REPEAT")
		return g
	end)
	if ok then ui.miniPulse = pulse end

	local mclose = CreateFrame("Button", nil, m, "UIPanelCloseButton")
	mclose:SetSize(24, 24)
	mclose:SetPoint("RIGHT", m, "RIGHT", -2, 0)
	mclose:SetScript("OnClick", function() WoWForeverGPT.Toggle(false) end)
	mclose:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("창 닫기 (/ai로 다시 열기)")
		GameTooltip:Show()
	end)
	mclose:SetScript("OnLeave", function() GameTooltip:Hide() end)
	WoWForeverGPT.ApplyCompactLayout()
end

function WoWForeverGPT.Toggle(show)
	if not ui.frame then return end
	if show == nil then show = not ui.frame:IsShown() end
	if show then
		db.settings.minimized = false
		local c = ActiveChat()
		if c then c.unread = 0 end
	end
	if ui.mini then ui.mini:Hide() end
	if not show then ui.quitting = true end
	ui.frame:SetShown(show)
	ui.quitting = nil
	db.settings.shown = show
	if show then
		WoWForeverGPT.Render()
		-- No auto-focus: the game keeps the keyboard until you click the box.
		-- No automatic hello either: if the bridge hasn't been seen, the panel
		-- shows Connect in place of Send and waits for a click.
	end
	WoWForeverGPT.UpdateMini()
end

function WoWForeverGPT.Minimize(mini)
	if not ui.frame then return end
	if mini == nil then mini = not db.settings.minimized end
	if mini then
		db.settings.minimized = true
		db.settings.shown = true
		ui.frame:Hide() -- OnHide shows the mini bar
		if ui.mini and not ui.mini:IsShown() then ui.mini:Show() end
		WoWForeverGPT.UpdateMini()
	else
		WoWForeverGPT.Toggle(true)
	end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local HELP = table.concat({
	"/ai                            질문 창 열기 또는 닫기",
	"/ai 질문                      채팅창에서 AI에게 질문",
	"/wow-ai new [이름]        새 대화",
	"/wow-ai clear                현재 대화 비우기",
	"/wow-ai copy                 마지막 답변 복사",
	"/wow-ai bind 키              질문 창 단축키",
	"/wow-ai recover              대기 중인 답변 복구",
	"/wow-ai reload               UI 새로고침",
}, "\n")

-- What each subcommand accepts, so that free text which happens to start with
-- one of these words ("delete the unused imports", "help me with this macro")
-- is sent as a message instead of run as a command. 0 = no arguments, 1 = at
-- most one word, a table = one of those words, a function decides, true = anything.
local function OnOffOrNumber(rest)
	return rest == "" or rest == "on" or rest == "off" or tonumber(rest) ~= nil
end

local function ChatArgument(rest)
	if rest == "" or tonumber(rest) or not rest:find("%s") then return true end
	for _, ch in ipairs(db.chats) do
		if ch.name:lower() == rest:lower() then return true end
	end
	return false
end

local COMMAND_ARGS = {
	mini = 0, min = 0, hide = 0, quit = 0, help = 0, clear = 0, delete = 0, reset = 0, copy = 0,
	cancel = 0, resend = 0, recover = 0, reload = 0, refresh = 0, slots = 0, diag = 0,
	mode = { [""] = true, pixel = true, reload = true },
	signal = { [""] = true, on = true, off = true }, longchat = { [""] = true, on = true, off = true },
	auto = OnOffOrNumber,
	echo = function(rest) return rest == "" or rest == "summary" or rest == "full" or rest == "short" or rest == "off" or tonumber(rest) ~= nil end,
	bind = 1,
	chat = ChatArgument, chats = ChatArgument,
	new = true, rename = true,
}

local function IsCommand(cmd, rest)
	local spec = COMMAND_ARGS[cmd]
	if spec == nil then return false end
	if spec == true then return true end
	if spec == 0 then return rest == "" end
	if spec == 1 then return not rest:find("%s") end
	if type(spec) == "table" then return spec[rest:lower()] == true end
	return spec(rest) == true
end

local function ApplyLongChat()
	local box = ChatFrame1EditBox
	if not box or not box.SetMaxLetters then return end
	box:SetMaxLetters(db.settings.longchat and 4000 or 255)
end

SLASH_WOWFOREVERGPT1 = "/wow-ai"
SLASH_WOWFOREVERGPT2 = "/wowai"
SLASH_WOWFOREVERGPTASK1 = "/ai"
SLASH_WOWFOREVERGPTASK2 = "/ask"
SlashCmdList["WOWFOREVERGPTASK"] = function(msg)
	msg = Trim(msg or "")
	if msg == "" then
		WoWForeverGPT.Toggle()
	else
		WoWForeverGPT.Toggle(true)
		WoWForeverGPT.Send(msg)
	end
end
SlashCmdList["WOWFOREVERGPT"] = function(msg)
	msg = Trim(msg or "")
	local cmd, rest = msg:match("^(%S+)%s*(.-)$")
	cmd = cmd and cmd:lower() or ""
	local s = db.settings
	local c = ActiveChat()

	-- Anything that isn't a command, or a command word followed by something it
	-- doesn't take, is a message for the agent.
	if cmd ~= "" and not IsCommand(cmd, rest) then
		WoWForeverGPT.Toggle(true)
		WoWForeverGPT.Send(msg)
		return
	end
	if cmd == "" then
		WoWForeverGPT.Toggle()
	elseif cmd == "mini" or cmd == "min" then
		WoWForeverGPT.Minimize(true)
	elseif cmd == "new" then
		WoWForeverGPT.NewChat(rest)
	elseif cmd == "chat" or cmd == "chats" then
		local n = tonumber(rest)
		local target = n and db.chats[n]
		if not target and rest ~= "" then
			for _, ch in ipairs(db.chats) do
				if ch.name:lower() == rest:lower() then target = ch end
			end
		end
		if target then
			WoWForeverGPT.SwitchChat(target.id)
		else
			local lines = {}
			for i, ch in ipairs(db.chats) do
				table.insert(lines, i .. ". " .. ch.name .. (ch.id == db.activeChat and "  (현재 대화)" or "") .. (ch.pendingId and "  답변 중" or "") .. ((ch.unread or 0) > 0 and ("  새 답변 " .. ch.unread .. "개") or ""))
			end
			AddHistory(c, "system", "대화 목록:\n" .. table.concat(lines, "\n"))
			WoWForeverGPT.Render()
		end
		WoWForeverGPT.Toggle(true)
	elseif cmd == "rename" then
		if rest ~= "" then
			c.name = ShortTitle(rest)
			WoWForeverGPT.Render()
		else
			WoWForeverGPT.RenameActive()
		end
		WoWForeverGPT.Toggle(true)
	elseif cmd == "delete" then
		WoWForeverGPT.DeleteChat()
	elseif cmd == "cd" then
		WoWForeverGPT.SetFolder(rest, c)
		WoWForeverGPT.Toggle(true)
	elseif cmd == "map" then
		if WoWForeverGPTMap then WoWForeverGPTMap.Command(rest) else print("|cff66ccff[" .. APP_NAME .. "]|r 지도 모듈을 불러오지 못했습니다.") end
	elseif cmd == "agent" then
		WoWForeverGPT.SetAgent(rest, c)
		WoWForeverGPT.Toggle(true)
	elseif cmd == "reset" then
		c.resetNext = true
		AddHistory(c, "system", "다음 질문부터 이전 대화 문맥을 사용하지 않습니다.")
		WoWForeverGPT.Render()
		WoWForeverGPT.Toggle(true)
	elseif cmd == "context" or cmd == "ctx" then
		rest = rest:lower()
		if rest == "on" or rest == "off" then
			s.context = rest == "on"
			-- Make sure the next record carries the change, hello throttle or not.
			run.contextSent = nil
			run.lastHelloAt = nil
			if WoWForeverGPT.IsConnected() then WoWForeverGPT.SayHello() end
		end
		local ctx = WoWForeverGPT.GameContext()
		AddHistory(c, "system", (s.context
			and "게임 정보 전달: 켜짐. 질문할 때 아래 정보를 AI에 함께 전달합니다. 끄기: /wow-ai context off\n\n"
			or "게임 정보 전달: 꺼짐. AI에 게임 정보를 전달하지 않습니다. 켜기: /wow-ai context on\n\n") .. ctx
			.. "\n\n입력창을 선택한 뒤 아이템·주문·퀘스트를 Shift+클릭하면 링크와 툴팁을 질문에 첨부할 수 있습니다.")
		WoWForeverGPT.Render()
		WoWForeverGPT.Toggle(true)
	elseif cmd == "mode" then
		if rest == "pixel" or rest == "reload" then
			s.mode = rest
			AddHistory(c, "system", "전송 방식 변경: " .. (rest == "pixel" and "화면 신호 (pixel)" or "UI 새로고침 (reload)"))
		else
			AddHistory(c, "system", "현재 전송 방식: " .. (s.mode == "pixel" and "화면 신호 (pixel)" or "UI 새로고침 (reload)") .. " (변경: /wow-ai mode pixel 또는 reload)")
		end
		WoWForeverGPT.Render()
		WoWForeverGPT.Toggle(true)
	elseif cmd == "resend" or cmd == "recover" then
		WoWForeverGPT.RecoverPending()
	elseif cmd == "auto" then
		local n = tonumber(rest)
		if n then
			s.interval = math.max(5, math.floor(n))
			s.autoRefresh = true
		elseif rest == "on" then
			s.autoRefresh = true
		elseif rest == "off" then
			s.autoRefresh = false
		end
		WoWForeverGPT.UpdateStatus()
		WoWForeverGPT.ArmAutoRefresh()
	elseif cmd == "hide" or cmd == "quit" then
		WoWForeverGPT.Toggle(false)
	elseif cmd == "macro" and rest == "undo" then
		WoWForeverGPT.UndoMacro()
	elseif cmd == "copy" then
		for i = #c.history, 1, -1 do
			if c.history[i].role == "assistant" then
				WoWForeverGPT.ShowCopy(c.history[i].text)
				break
			end
		end
	elseif cmd == "echo" then
		if rest == "summary" or rest == "full" or rest == "short" or rest == "off" then
			s.echo = rest
		elseif tonumber(rest) then
			s.echo = tostring(math.max(200, math.floor(tonumber(rest))))
		end
		AddHistory(c, "system", "게임 채팅창 답변 표시: " .. s.echo .. " (summary: 요약, full: 최대 " .. ECHO_DEFAULT .. "자, short: 짧게, off: 끄기, 숫자: 표시할 글자 수)")
		WoWForeverGPT.Render()
	elseif cmd == "longchat" then
		if rest == "on" then s.longchat = true elseif rest == "off" then s.longchat = false end
		ApplyLongChat()
		AddHistory(c, "system", "게임 채팅 입력 제한: " .. (s.longchat and "4000자 (/ai에서 사용 가능. 일반 채팅은 255자를 넘으면 서버에서 거부될 수 있습니다.)" or "255자 (기본값)"))
		WoWForeverGPT.Render()
	elseif cmd == "signal" then
		if rest == "on" then s.signal = true elseif rest == "off" then s.signal = false end
		AddHistory(c, "system", "신호 확인: " .. (s.signal and "켜짐" or "꺼짐"))
		WoWForeverGPT.Render()
	elseif cmd == "slots" then
		local free = 0
		for i = 1, SLOT_COUNT do
			if not C_AddOns.IsAddOnLoaded(SlotName(i)) then free = free + 1 end
		end
		AddHistory(c, "system", "남은 응답 슬롯: " .. free .. "/" .. SLOT_COUNT .. " (UI를 새로고침하면 모두 다시 사용할 수 있습니다.)")
		WoWForeverGPT.Render()
		WoWForeverGPT.Toggle(true)
	elseif cmd == "refresh" or cmd == "reload" then
		SafeReload()
	elseif cmd == "bind" then
		local key = rest:upper()
		if key ~= "" and not InCombatLockdown() then
			SetBinding(key, "CLICK WoWForeverGPTRefreshButton:LeftButton")
			SaveBindings(GetCurrentBindingSet())
			AddHistory(c, "system", "단축키 설정: " .. key .. ". 답변 대기 중에는 응답을 확인하고, 그 외에는 질문 창을 열거나 닫습니다.")
		end
		WoWForeverGPT.Render()
		WoWForeverGPT.Toggle(true)
	elseif cmd == "diag" then
		local free = 0
		for i = 1, SLOT_COUNT do
			if not C_AddOns.IsAddOnLoaded(SlotName(i)) then free = free + 1 end
		end
		local lines = {
			"소리 파일 신호: " .. (signalAvailable and "사용 가능" or "사용 불가") .. " (자체 검사: " .. tostring(signalStats.selftest) .. ")" .. (signalStats.error and (" 오류: " .. signalStats.error) or ""),
			"신호 확인 설정: " .. (s.signal and "켜짐" or "꺼짐") .. ", 이번 접속에서 신호 불안정 감지: " .. (run.signalUnreliable and "예" or "아니요"),
			"신호 검사: " .. signalStats.checks .. "회, 유효 신호: " .. signalStats.hits .. "회" .. (signalStats.lastHit and (", 마지막 감지 " .. FmtDur(GetTime() - signalStats.lastHit) .. " 전") or ""),
			"이번 접속의 슬롯 확인: " .. (run.polls or 0) .. "회, 남은 슬롯: " .. free .. "/" .. SLOT_COUNT,
			"연결 확인 위치: " .. tostring(run.presence and run.presence.last or "?") .. ", 감지한 신호: " .. tostring(run.presence and run.presence.beats or 0) .. "회",
			select(5, WoWForeverGPT.BridgeState()),
			"전송 방식: " .. s.mode .. ", 세션 식별자: " .. tostring(db.session),
		}
		for _, ch in ipairs(db.chats) do
			local a = run.act and run.act[ch.id]
			if ch.pendingId then
				table.insert(lines, ch.name .. ": 답변 대기 #" .. ch.pendingId .. (a and (", 활동 신호 " .. (a.unreliable and "불안정" or (a.count .. "회"))) or ", 활동 신호 없음"))
			end
		end
		AddHistory(c, "system", "연결 진단:\n" .. table.concat(lines, "\n"))
		WoWForeverGPT.Render()
		WoWForeverGPT.Toggle(true)
	elseif cmd == "cancel" then
		if c.pendingId then
			AddHistory(c, "system", "이 질문의 답변 대기를 중단했습니다. 번호 " .. c.pendingId)
			run.outbound[c.pendingId] = nil
			if run.act then run.act[c.id] = nil end
			c.pendingId = nil
			c.progress = nil
			c.recovering, c.recoveryStalled = nil, nil
			if run.recovery then run.recovery[c.id] = nil end
			RefreshStrip()
			if not AnyPending() then keyCatcher:Hide() end
		end
		WoWForeverGPT.Render()
	elseif cmd == "clear" then
		if not c.pendingId then
			wipe(c.history)
			c.resetNext = true
		end
		WoWForeverGPT.Render()
	elseif cmd == "help" then
		AddHistory(c, "system", HELP)
		WoWForeverGPT.Render()
		WoWForeverGPT.Toggle(true)
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("UPDATE_MACROS")
ev:RegisterEvent("CHAT_MSG_WHISPER")
ev:RegisterEvent("CHAT_MSG_BN_WHISPER")
ev:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			InitDB()
		end
	elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
		-- A real person whispered: /r belongs to them again.
		run.lastMessenger = "player"
	elseif event == "PLAYER_LOGIN" then
		if not db then InitDB() end
		BuildUI()
		run = { outbound = {}, connectionStartedAt = GetTime() }
		SelfTestSignals()
		ProcessInbox()
		if AnyPending() then
			-- Still waiting after a reload: resume polling with a fresh slot pool.
			run.sentAt = GetTime()
			run.polls = 0
			run.act = {}
			for _, ch in ipairs(db.chats) do
				if ch.pendingId then
					-- Beats already written stay valid, so the counter catches up on its own.
					run.act[ch.id] = { next = 1, count = 0, startedAt = GetTime() }
				end
			end
			ScheduleNextPoll()
		end
		local c = ActiveChat()
		if c and c.draft and c.draft ~= "" then
			ui.input:SetText(c.draft)
			if not c.pendingId then c.draft = nil end
		end
		WoWForeverGPT.Render()
		if db.settings.shown then
			if db.settings.minimized then
				WoWForeverGPT.Minimize(true)
			else
				WoWForeverGPT.Toggle(true)
			end
		end
		WoWForeverGPT.ArmAutoRefresh()
		WoWForeverGPT.UpdateDot()
		if db.settings.longchat then ApplyLongChat() end
		C_Timer.NewTicker(TICK_SECONDS, Tick)
		C_Timer.After(3, WoWForeverGPT.SayHello)
	elseif event == "UPDATE_MACROS" then
		-- "Create" / "Update" on the macro buttons follows what exists now.
		if ui.frame and ui.frame:IsShown() then WoWForeverGPT.Render() end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if WoWForeverGPT.reloadAfterCombat then
			WoWForeverGPT.reloadAfterCombat = nil
			ReloadUI()
		elseif db then
			WoWForeverGPT.ArmAutoRefresh()
		end
	end
end)
