-- 위치 메타데이터만 읽는다. 답변의 일반 숫자/좌표를 추측해 핀으로 바꾸지 않는다.
-- [[wowmap:uiMapID:x:y:verified|장소명]]: 검증된 좌표(0..100), 자동 핀 후보.
-- [[wowmap:uiMapID:x:y:approximate|장소명]]: 대략적인 좌표, 클릭해야 핀 설정.
-- [[wowmap:uiMapID|지역명]]: 좌표 미확인, 클릭하면 지도만 연다.
local M = {}
WoWForeverGPT_MapLinks = M

function M.Parse(text)
    local points = {}
    local clean = tostring(text or ""):gsub("%[%[wowmap:([^%]\r\n]+)%]%]", function(payload)
        local spec, label = payload:match("^([^|]+)|(.+)$")
        if not spec or #points >= 4 or #label > 180 then return "" end
        local id, x, y, confidence = spec:match("^(%d+):([%d.]+):([%d.]+):([a-z]+)$")
        if not id then id = spec:match("^(%d+)$") end
        id, x, y = tonumber(id), tonumber(x), tonumber(y)
        if not id or id < 1 or id > 100000 then return "" end
        if confidence and (not x or not y or x < 0 or x > 100 or y < 0 or y > 100
            or (confidence ~= "verified" and confidence ~= "approximate")) then return "" end
        -- 외부에서 받은 WoW 제어 문자열은 버튼 라벨에 넣지 않는다.
        points[#points + 1] = { mapID = id, x = x, y = y, confidence = confidence,
            label = label:gsub("|", "¦") }
        return ""
    end)
    return clean:gsub("\n\n\n+", "\n\n"):match("^%s*(.-)%s*$"), points
end

local function ValidMap(point)
    if not C_Map or not C_Map.GetMapInfo then return false end
    local ok, info = pcall(C_Map.GetMapInfo, point.mapID)
    return ok and info ~= nil
end

function M.SetPin(point)
    if not ValidMap(point) or not point.x or not point.y or not C_Map.SetUserWaypoint
        or not UiMapPoint or not UiMapPoint.CreateFromCoordinates then return false end
    -- 클라이언트가 핀을 지원하지 않는다고 보고하는 지도는 변경하지 않는다.
    if C_Map.CanSetUserWaypointOnMap then
        local ok, allowed = pcall(C_Map.CanSetUserWaypointOnMap, point.mapID)
        if not ok or not allowed then return false end
    end
    local ok = pcall(function()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(point.mapID, point.x / 100, point.y / 100))
    end)
    if not ok then return false end
    -- API가 예외 없이 무시되는 빌드에서도 성공으로 오인하지 않도록 실제 핀을 비교한다.
    if not C_Map.GetUserWaypoint then return false end
    local readOK, pin = pcall(C_Map.GetUserWaypoint)
    if not readOK or not pin or pin.uiMapID ~= point.mapID or not pin.position then return false end
    local posOK, px, py = pcall(function() return pin.position:GetXY() end)
    if not posOK or not px or not py or math.abs(px - point.x / 100) > 0.0001
        or math.abs(py - point.y / 100) > 0.0001 then return false end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    return true
end

function M.Auto(text)
    local _, points = M.Parse(text)
    -- 답변 수신 시에만 한 번 호출한다. 기록 표시/창 열기/복원은 핀을 다시 덮어쓰지 않는다.
    -- 여러 목적지가 있어도 다음 행동에 해당하는 첫 검증 좌표 하나만 선택한다.
    for _, point in ipairs(points) do
        if point.confidence == "verified" then return M.SetPin(point) end
    end
    return false
end

function M.Open(point)
    if not ValidMap(point) then return end
    -- 불확실한 좌표는 사용자가 직접 링크를 누른 경우에만 표시한다.
    if point.x then M.SetPin(point) end
    if not WorldMapFrame and UIParentLoadAddOn then pcall(UIParentLoadAddOn, "Blizzard_WorldMap") end
    if WorldMapFrame and WorldMapFrame.SetMapID then
        if ShowUIPanel then ShowUIPanel(WorldMapFrame) else WorldMapFrame:Show() end
        WorldMapFrame:SetMapID(point.mapID)
    end
end

-- 위치 정보는 내부에 유지하고 링크에는 짧은 이름만 표시한다.
function M.Label(point)
    return "[위치]"
end
