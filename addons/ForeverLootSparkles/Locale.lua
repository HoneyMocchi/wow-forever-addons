local _, ns = ...
-- 한국어 클라이언트에서만 표시 문구를 바꾼다. 다른 언어는 원문으로 되돌리는 사전이다.
-- 설정 식별자와 게임 로직에는 개입하지 않으며, 모든 파일이 같은 사전을 사용한다.
ns.L = setmetatable({}, {__index = function(_, key) return key end})
if GetLocale() ~= "koKR" then return end
local L = ns.L
L["Forever Loot Sparkles"] = "전리품 반짝임"
L["|cffff8000Forever Loot Sparkles:|r restart the game to remove the sparkles. /reload is not enough."] = "|cffff8000전리품 반짝임:|r 효과를 끄려면 게임을 완전히 종료한 뒤 다시 실행하세요. /reload만으로는 적용되지 않습니다."
L["Show quest item sparkles"] = "퀘스트 아이템 반짝임 표시"
L["Keeps the game's loot sparkle on, even after a graphics preset turns it off. Your outline mode is left as you set it. Switching this off takes effect after restarting the game."] = "그래픽 품질 설정을 변경해도 기본 전리품 반짝임을 유지합니다. 윤곽선 모드는 기존 설정을 따릅니다. 이 옵션을 끄면 게임을 다시 실행한 뒤 적용됩니다."
L["Sparkles while approaching"] = "가까이 가면 반짝임 표시"
L[" Uses Blizzard's soft targeting: the nearest object within about 15 yards sparkles, brighter once you can reach it. Needs the game's Enable Interact Key setting and its interact icons on objects; switching this on turns both on, and with them off nothing sparkles."] = " 블리자드의 자동 상호작용 대상 선택 기능을 사용합니다. 약 15미터 안에서 가장 가까운 물체가 반짝이며, 상호작용할 수 있는 거리에 들어오면 더 밝아집니다. 게임의 상호작용 키 사용 및 오브젝트 상호작용 아이콘 설정이 필요합니다. 이 옵션을 켜면 두 설정도 켜지며, 두 설정이 꺼져 있으면 반짝임이 표시되지 않습니다."
L["Ore veins"] = "광맥"
L["Herbs"] = "약초"
L["Quest objects"] = "퀘스트 오브젝트"
L["Corpses with loot"] = "전리품이 남은 시체"
L["Sparkles on mining nodes as you approach them."] = "광맥에 가까이 가면 반짝임을 표시합니다."
L["Sparkles on herbs as you approach them."] = "약초에 가까이 가면 반짝임을 표시합니다."
L["Extra sparkles on quest objects as you approach them. Off by default: the game's loot sparkle already marks most of them."] = "퀘스트 오브젝트에 가까이 가면 반짝임을 추가로 표시합니다. 대부분은 게임 기본 효과로 표시되므로 기본값은 꺼짐입니다."
L["Sparkles on a corpse that still holds loot for you, bosses included. Only after the fight: the game doesn't let addons switch the nameplate it hangs on during combat."] = "우두머리를 포함해 획득할 전리품이 남은 시체에 반짝임을 표시합니다. 전투 중에는 반짝임을 붙이는 이름표를 애드온에서 변경할 수 없어 전투가 끝난 뒤 표시됩니다."
