-- 포에버 한국어 특성 툴팁의 잘못된 format 문구만 표시 단계에서 처리합니다.
-- XML 템플릿과 프레임 풀은 믹스인 함수를 미리 복사하므로 공용 믹스인만
-- 교체하면 실제 버튼이 이전 함수를 계속 호출할 수 있습니다. Blizzard가
-- 툴팁 표시 직전에 발생시키는 이벤트에서 실제 버튼 인스턴스를 보완합니다.
local interface = select(4, GetBuildInfo());
if GetLocale() ~= "koKR" or interface < 16000 or interface >= 20000 then return end
if not EventRegistry then return end

local owner = {};
local patched = setmetatable({}, { __mode = "k" });
local failed = setmetatable({}, { __mode = "k" });
local methods = { "AddTooltipInfo", "AddTooltipDescription", "AddTooltipCost",
    "AddTooltipInstructions", "AddTooltipErrors" };

local function IsKnownFormatError(message)
    return type(message) == "string"
        and message:find("Blizzard_SharedTalentUtil.lua", 1, true)
        and message:find("invalid option", 1, true)
        and message:find("format", 1, true);
end

EventRegistry:RegisterCallback("TalentDisplay.TooltipHook", function(_, display)
    if not display then return end
    failed[display] = nil;
    local records = patched[display];
    if not records then records = {}; patched[display] = records end
    for _, method in ipairs(methods) do
        local original = display[method];
        -- 다른 애드온이 나중에 함수를 바꿔도 새 함수를 기준으로 한 번만 감쌉니다.
        -- 같은 래퍼를 중첩하지 않으며 다른 버튼/전역 API에는 영향을 주지 않습니다.
        if type(original) == "function" and original ~= records[method] then
            local guarded = function(self, ...)
                local ok, result = pcall(original, self, ...);
                if ok then return result end
                if not IsKnownFormatError(result) then error(result, 0) end
                failed[self] = true;
                -- 잘못된 조건 안내만 생략합니다. 호출한 기본 툴팁 함수는
                -- 계속 실행되어 정상 제목/주문 설명/다음 등급을 표시합니다.
            end;
            records[method] = guarded;
            display[method] = guarded;
        end
    end
end, owner);

EventRegistry:RegisterCallback("TalentDisplay.TooltipCreated", function(_, display, tooltip)
    if not display or not failed[display] then return end
    failed[display] = nil;
    if tooltip then
        tooltip:AddLine("일부 한국어 특성 조건 설명을 표시할 수 없습니다.", 1, 0.65, 0.2, true);
        tooltip:Show();
    end
end, owner);
