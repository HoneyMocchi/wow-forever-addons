-- 답변의 짧은 강조 표기만 화면 색상으로 변환한다. 외부 라이브러리/타이머는 사용하지 않는다.
-- 저장된 답변은 수정하지 않으며, 복사 문자열에는 WoW 색상 코드나 Markdown 구분자를 넣지 않는다.
local TextFormat = {}
_G.WoWForeverGPT_Text = TextFormat

local COLORS = {
    emphasis = "|cfff2d6a2", -- 어두운 답변 배경에서 읽기 쉬운 크림색
    code = "|cff9ed9d8",     -- 명령어/스킬 표기의 연한 청록색
    warning = "|cffe7b58d",  -- 주의 문구의 연한 살구색
}

local function SafeText(text)
    -- 모델/사용자 문자열이 임의의 텍스처·링크·색상 태그로 해석되지 않게 먼저 무해화한다.
    -- 색상 제어 코드는 이 파일에서만 생성한다. 한글 바이트는 자르거나 대소문자 변환하지 않는다.
    return (tostring(text or ""):gsub("|", "¦"))
end

local MARKERS = {
    { open = "**", close = "**", kind = "emphasis", strip = true },
    { open = "`", close = "`", kind = "code", strip = true },
    -- 기존 답변의 ‘스킬명’ 같은 표기도 추가 GPT 요청 없이 강조한다.
    { open = "‘", close = "’", kind = "emphasis" },
    { open = "“", close = "”", kind = "emphasis" },
}

local function Inline(text, inheritedColor, depth)
    local rich, plain = {}, {}
    local function append(part, color)
        if part == "" then return end
        plain[#plain + 1] = part
        local safe = SafeText(part)
        rich[#rich + 1] = color and (color .. safe .. "|r") or safe
    end
    if depth >= 4 then append(text, inheritedColor); return table.concat(rich), table.concat(plain) end

    local cursor = 1
    while cursor <= #text do
        local first, marker
        for _, candidate in ipairs(MARKERS) do
            local at = text:find(candidate.open, cursor, true)
            if at and (not first or at < first) then first, marker = at, candidate end
        end
        if not first then append(text:sub(cursor), inheritedColor); break end
        append(text:sub(cursor, first - 1), inheritedColor)
        local insideAt = first + #marker.open
        local ending = text:find(marker.close, insideAt, true)
        if not ending or ending == insideAt then
            -- 닫히지 않은 표기는 그대로 보여준다. 별표가 있는 계산식/일반 문장을 임의로 없애지 않는다.
            append(marker.open, inheritedColor)
            cursor = insideAt
        else
            local inside = text:sub(insideAt, ending - 1)
            if marker.kind == "emphasis" and marker.strip then
                local styled, readable = Inline(inside, COLORS.emphasis, depth + 1)
                rich[#rich + 1], plain[#plain + 1] = styled, readable
            else
                local part = marker.strip and inside or (marker.open .. inside .. marker.close)
                append(part, COLORS[marker.kind])
            end
            cursor = ending + #marker.close
        end
    end
    return table.concat(rich), table.concat(plain)
end

local WARNING_LABELS = { "주의사항:", "주의:", "확인 필요:" }
local function FormatLine(line)
    local indent, body = line:match("^([ \t]*)(.*)$")
    local bullet = body:match("^([*-] +)")
    if bullet then indent, body = indent .. bullet, body:sub(#bullet + 1) end
    for _, label in ipairs(WARNING_LABELS) do
        if body:sub(1, #label) == label then
            local rich, plain = Inline(body:sub(#label + 1), nil, 0)
            return SafeText(indent) .. COLORS.warning .. label .. "|r" .. rich, indent .. label .. plain
        end
    end
    return Inline(line, nil, 0)
end

function TextFormat.Format(text)
    text = tostring(text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    local rich, plain = {}, {}
    local inCode = false
    -- 줄별로 처리하므로 닫히지 않은 강조 표기가 다음 문단까지 색을 번지게 하지 않는다.
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line:match("^[ \t]*```[A-Za-z0-9_+%-]*[ \t]*$") then
            inCode = not inCode
        else
            local styled, readable
            if inCode then
                styled, readable = COLORS.code .. SafeText(line) .. "|r", line
            else
                styled, readable = FormatLine(line)
            end
            rich[#rich + 1], plain[#plain + 1] = styled, readable
        end
    end
    return table.concat(rich, "\n"), table.concat(plain, "\n")
end

function TextFormat.Plain(text)
    local _, plain = TextFormat.Format(text)
    return plain
end
