-- 답변의 아이템/퀘스트 참조를 허용된 ID로만 해석한다. 모델이 임의의 WoW 링크나
-- 실행 코드를 삽입할 수 없으며, 실제 링크·장착 장비·툴팁은 게임 API에서 읽는다.
local M = {}
WoWForeverGPT_EntityLinks = M

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i end
end

local function Readable(value)
    return type(issecretvalue) ~= "function" or not issecretvalue(value)
end

local SLOTS = {
    INVTYPE_HEAD={1}, INVTYPE_NECK={2}, INVTYPE_SHOULDER={3}, INVTYPE_BODY={4},
    INVTYPE_CHEST={5}, INVTYPE_ROBE={5}, INVTYPE_WAIST={6}, INVTYPE_LEGS={7},
    INVTYPE_FEET={8}, INVTYPE_WRIST={9}, INVTYPE_HAND={10}, INVTYPE_FINGER={11,12},
    INVTYPE_TRINKET={13,14}, INVTYPE_CLOAK={15}, INVTYPE_WEAPON={16,17},
    INVTYPE_2HWEAPON={16,17}, INVTYPE_WEAPONMAINHAND={16}, INVTYPE_WEAPONOFFHAND={17},
    INVTYPE_SHIELD={17}, INVTYPE_HOLDABLE={17}, INVTYPE_RANGED={18},
    INVTYPE_RANGEDRIGHT={18}, INVTYPE_THROWN={18}, INVTYPE_RELIC={18}, INVTYPE_TABARD={19},
}

function M.Slots(payload)
    local _, _, _, equipLoc = Call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant, payload)
    if not equipLoc or equipLoc == "" then
        equipLoc = select(9, Call(C_Item and C_Item.GetItemInfo or GetItemInfo, payload))
    end
    return SLOTS[equipLoc]
end

function M.Parse(text)
    local refs, seen = {}, {}
    local clean = tostring(text or ""):gsub("%[%[wow(%a+):(%d+)|([^%]\r\n]+)%]%]", function(kind, id, name)
        if kind ~= "item" and kind ~= "quest" then return "" end
        id = tonumber(id)
        if not id or id < 1 or id > 10000000 or #name > 180 then return "" end
        local key = kind .. ":" .. id
        if not seen[key] and #refs < 6 then
            refs[#refs+1] = {kind=kind, id=id, payload=kind == "quest" and (key..":-1") or key,
                name=name:gsub("|", "¦")}
            seen[key] = true
        end
        return ""
    end)
    return clean:gsub("\n\n\n+", "\n\n"):match("^%s*(.-)%s*$"), refs
end

function M.FirstItem(text)
    -- 입력된 원본 아이템 링크 전체를 유지해 무작위 옵션·강화·인챈트가 사라지지 않게 한다.
    return tostring(text or ""):match("|H(item:[^|]+)|h")
end

function M.Link(ref)
    if ref.kind == "item" then
        local _, link = Call(C_Item and C_Item.GetItemInfo or GetItemInfo, ref.payload)
        if link then return link end
    else
        local link = Call(GetQuestLink, ref.id)
        if link then return link end
    end
    return "|H" .. ref.payload .. "|h[" .. ref.name .. "]|h"
end

-- The game can fire a load result synchronously even for cached IDs.
-- Record each request before calling the API so a redraw cannot request it again.
local requested = { item = {}, quest = {} }
function M.Request(ref)
    local pending = requested[ref.kind]
    if not pending or pending[ref.id] then return end
    pending[ref.id] = true
    if ref.kind == "item" then Call(C_Item and C_Item.RequestLoadItemDataByID, ref.id)
    else Call(C_QuestLog and C_QuestLog.RequestLoadQuestByID, ref.id) end
end

local compareTips = {}
function M.HideTooltip()
    if GameTooltip then GameTooltip:Hide() end
    for _, tip in ipairs(compareTips) do tip:Hide() end
end

function M.Tooltip(owner, ref)
    M.HideTooltip()
    if not GameTooltip then return end
    M.Request(ref)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, ref.payload)
    if not ok or (GameTooltip:NumLines() or 0) == 0 then
        GameTooltip:ClearLines()
        local title = ref.kind == "quest" and Call(C_QuestLog and C_QuestLog.GetTitleForQuestID, ref.id)
        GameTooltip:SetText(title or ref.name)
        local objectives = title and Call(C_QuestLog and C_QuestLog.GetQuestObjectives, ref.id)
        if type(objectives) == "table" and #objectives > 0 then
            for i = 1, math.min(#objectives, 6) do
                local line = objectives[i]
                if type(line) == "table" and type(line.text) == "string" and Readable(line.text) then
                    GameTooltip:AddLine(line.text, 0.9,0.9,0.9,true)
                end
            end
        else
            GameTooltip:AddLine("정보를 불러오는 중입니다. 잠시 뒤 다시 올려보세요.", 0.8,0.8,0.8,true)
        end
    end
    GameTooltip:AddLine(ref.kind == "quest" and "클릭: 퀘스트 보기 · Shift+클릭: 링크 공유"
        or "클릭: 질문에 첨부 · Shift+클릭: 링크 공유", 0.6,0.8,1,true)
    GameTooltip:Show()
    if ref.kind ~= "item" then return end
    -- 전역 ShoppingTooltip 상태를 바꾸지 않고 두 비교 툴팁을 이 애드온에서만 소유한다.
    -- 반지/장신구/양손 무기는 두 장착 칸을 모두 보여준다.
    local previous, count = GameTooltip, 0
    for _, slot in ipairs(M.Slots(ref.payload) or {}) do
        if Call(GetInventoryItemLink, "player", slot) then
            count = count + 1
            local tip = compareTips[count]
            if not tip then
                tip = CreateFrame("GameTooltip", "WoWForeverGPTCompareTip"..count, UIParent, "GameTooltipTemplate")
                compareTips[count] = tip
            end
            tip:SetOwner(owner, "ANCHOR_NONE")
            tip:ClearLines()
            local setOK = pcall(tip.SetInventoryItem, tip, "player", slot)
            if setOK then
                tip:AddLine("현재 장착 중 · 슬롯 "..slot, 0.4,1,0.4)
                tip:ClearAllPoints()
                tip:SetPoint("TOPLEFT", previous, "TOPRIGHT", 4, 0)
                tip:Show()
                previous = tip
            end
        end
    end
end

function M.Click(ref, input)
    if IsShiftKeyDown and IsShiftKeyDown() then
        local insert = ChatFrameUtil and ChatFrameUtil.InsertLink or ChatEdit_InsertLink
        if insert then Call(insert, M.Link(ref)) end
        return
    end
    if ref.kind == "quest" and QuestMapFrame_OpenToQuestDetails then
        Call(QuestMapFrame_OpenToQuestDetails, ref.id)
    elseif input then
        input:SetFocus()
        input:Insert(M.Link(ref))
    end
end

function M.ComparisonBlock(payload, readTooltip, clip)
    local slots = M.Slots(payload)
    if not slots then return nil end
    -- 전송 패킷(최대 3200바이트) 안에 질문과 현재 직업/레벨/특성을 남긴다.
    -- 잘린 툴팁은 명시해 없는 옵션을 AI가 0으로 취급하지 않게 한다.
    local function Lines(link, budget)
        local value = table.concat(readTooltip(link), "; ")
        if value == "" then return "[Tooltip unavailable; stats unknown]" end
        if #value > budget then return clip(value, budget) .. " [truncated; omitted stats unknown]" end
        return value
    end
    local blocks = {"Candidate "..payload..": "..Lines(payload, 560)}
    for _, slot in ipairs(slots) do
        local equipped = Call(GetInventoryItemLink, "player", slot)
        if equipped then
            -- 툴팁은 원본 링크로 읽되 전송 헤더는 이름/ID만 써 패킷을 절약한다.
            local name = equipped:match("|h%[([^%]]*)%]|h") or "item"
            local id = equipped:match("item:(%d+)") or "?"
            blocks[#blocks+1] = "Equipped slot "..slot.." "..name.." #"..id..": "..Lines(equipped, 420)
        else
            blocks[#blocks+1] = "Equipped slot "..slot..": empty or unavailable; do not assume empty"
        end
    end
    return table.concat(blocks, "\n")
end

function M.QuestID()
    local id = Call(C_QuestLog and C_QuestLog.GetSelectedQuest)
    if not Readable(id) or type(id) ~= "number" or id <= 0 then
        id = Call(C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID)
    end
    if Readable(id) and type(id) == "number" and id > 0 then return id end
end

function M.Actions(text)
    local actions = {}
    local payload = M.FirstItem(text)
    if payload then
        local slots = M.Slots(payload)
        actions[#actions+1] = {label=slots and "장비 비교" or "아이템 분석", kind="item", payload=payload}
    end
    local exists = Call(UnitExists, "target")
    local player = Call(UnitIsPlayer, "target")
    if Readable(exists) and exists and Readable(player) and not player then
        actions[#actions+1] = {label="이 대상은?", kind="target"}
    end
    local quest = M.QuestID()
    if quest then actions[#actions+1] = {label="퀘스트 공략", kind="quest", id=quest} end
    return actions
end
