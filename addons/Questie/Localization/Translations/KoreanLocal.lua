-- 한국어 표시용 보완. 기본 번역을 먼저 로드한 뒤 필요한 항목만 추가합니다.
local l10n = QuestieLoader:ImportModule("l10n")
local ko = {
    ["Titan-Reforged Realm"] = "타이탄 리포지드 서버",
    ["NPC"] = "NPC",
    ["NPC ID"] = "NPC ID",
    ["NPCs"] = "NPC",
    ["DEBUG_SPAM"] = "상세 추적",
    ["DEBUG_INFO"] = "일반 정보",
    ["DEBUG_DEVELOP"] = "개발 정보",
    ["DEBUG_CRITICAL"] = "치명적 오류",
    ["DEBUG_ELEVATED"] = "중요 정보",
    ["DBM HUD"] = "DBM 화면 안내",
}
for key, text in pairs(ko) do
    if l10n.translations[key] then l10n.translations[key].koKR = text end
end
