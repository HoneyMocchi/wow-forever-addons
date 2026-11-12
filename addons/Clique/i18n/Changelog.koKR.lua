local _, addon = ...
if GetLocale() ~= "koKR" then return end
-- 한국어 보완: 변경 내역의 표시 문자열만 바꾸며 버전·날짜·자동 표시 규칙은 보존한다.
local text = {
    ["Added this in-game changelog, shown automatically after an update. You can turn off the automatic display with the checkbox at the bottom of this page."] = "업데이트 후 자동으로 표시되는 게임 내 변경 내역을 추가했습니다. 이 화면 아래의 확인란에서 자동 표시를 끌 수 있습니다.",
    ["Fix an issue with flyout spells"] = "펼침 메뉴 주문 관련 문제를 수정했습니다.",
    ["Clique has a new binding editor that should better explain how and when your bindings work."] = "단축키가 언제, 어떻게 작동하는지 더 쉽게 확인할 수 있는 새 편집기를 추가했습니다.",
    ["Binding resolution has been simplified and should behave more predictably."] = "단축키 적용 규칙을 단순화하여 동작을 더 예측하기 쉽게 개선했습니다.",
    ["Added support for in-combat specific bindings."] = "전투 중에만 적용되는 단축키를 지원합니다.",
    ["Added support for World of Warcraft: Forever."] = "월드 오브 워크래프트: 포에버를 지원합니다.",
    ["Update TOC for Classic Era 1.15.9."] = "클래식 시대 1.15.9에 맞게 애드온 버전 정보를 갱신했습니다.",
    ["Add a macro-based dispatch mode, as an alternative to click."] = "클릭 방식 대신 사용할 수 있는 매크로 기반 실행 방식을 추가했습니다.",
    ["Fixed menu binding not including the \"Move Frame\" sub-menu on Classic Era."] = "클래식 시대에서 메뉴 단축키로 연 메뉴에 프레임 이동 항목이 빠지는 문제를 수정했습니다.",
    ["Fixed bindings on raid and party pet frames casting on the pet's owner instead of the pet."] = "파티·공격대 소환수 프레임에서 주문이 소환수 대신 주인에게 시전되는 문제를 수정했습니다.",
    ["Fixed key bindings on unit frames always triggering on key release, ignoring the Down/Up/Both \"Trigger bindings on\" setting. They now fire on the edge you've chosen, the same as click bindings."] = "유닛 프레임의 키보드 단축키가 실행 시점 설정을 무시하고 키를 뗄 때만 작동하던 문제를 수정했습니다. 이제 마우스 단축키처럼 누를 때·뗄 때·둘 다 중 선택한 설정을 따릅니다.",
    ["Fixed issues on the 12.1.0 PTR caused by removed globals: the account macro limit is now read from the new Constants table, with a fallback for older clients."] = "12.1.0 공개 테스트 서버에서 전역 변수 제거로 발생하던 문제를 수정했습니다. 계정 매크로 수 제한은 새 상수 표에서 읽으며 이전 클라이언트도 지원합니다.",
    ["Fixed unit frames with modified actions (shift-right-click, etc.): Clique now overwrites those attributes when configured to, instead of relying on wildcards. This means your modified-click bindings apply reliably on frames that set their own."] = "Shift+오른쪽 클릭 등 보조키 동작이 있는 유닛 프레임의 문제를 수정했습니다. 필요한 속성을 직접 적용하여 프레임 자체 설정이 있어도 지정한 단축키가 안정적으로 작동합니다.",
    ["Fixed the in-game changelog and What's New page not appearing on Classic Era, Burning Crusade, Wrath, Cataclysm, and Mists of Pandaria."] = "클래식 시대·불타는 성전·리치 왕의 분노·대격변·판다리아의 안개에서 변경 내역과 새 소식 화면이 표시되지 않던 문제를 수정했습니다.",
    ["Patch 12.0.7 broke core unit frame and click-casting behaviour. Clique now fully takes control of the frames that it manages."] = "12.0.7 패치로 유닛 프레임과 클릭 시전 동작에 문제가 생겼습니다. 이제 Clique가 관리하는 프레임의 클릭 동작을 직접 제어합니다.",
    ["If you want the default left-click (target) and right-click (menu) behaviour, bind those actions in Clique or add the frames to the denylist."] = "기본 왼쪽 클릭의 대상 선택과 오른쪽 클릭의 메뉴 표시를 사용하려면 해당 동작을 Clique에서 지정하거나 프레임을 제외 목록에 추가하세요.",
    ["Target and menu actions should now work reliably, if you don't have them just create new bindings for them as you prefer."] = "대상 선택과 메뉴 표시 동작을 안정적으로 사용할 수 있도록 개선했습니다. 동작이 없다면 원하는 키로 새 단축키를 만드세요.",
    ["Overriding default Blizzard frame actions should work better now, Clique is more aggressive in managing registered frames."] = "등록된 프레임 관리를 강화하여 블리자드 기본 클릭 동작을 원하는 설정으로 더 안정적으로 바꿀 수 있습니다.",
    ["Options have been moved into the main config window, so you no longer have to flip back and forth."] = "옵션을 기본 설정 창으로 옮겨 창을 오가며 설정할 필요가 줄었습니다.",
    ["A warning now shows if you have changed the Blizzard click-casting defaults for target/menu. These MUST be left at the default, otherwise weird things will happen with your clicks."] = "블리자드 클릭 시전의 기본 대상 선택·메뉴 표시 설정을 변경하면 경고가 표시됩니다. 해당 설정은 기본값으로 유지해야 클릭 동작 문제를 피할 수 있습니다.",
    ["A warning now shows if you have 'Self Cast' set to 'Key' and you're using that key in a binding."] = "자신에게 시전을 특정 키로 설정하고 같은 키를 Clique 단축키에도 사용하면 경고가 표시됩니다.",
    ["Added support for pet spells in the action window."] = "동작 창에서 소환수 주문을 지원합니다.",
    ["Numerous other bug fixes and improvements."] = "그 밖의 여러 오류를 수정하고 기능을 개선했습니다.",
    ["Known issues"] = "알려진 문제",
    ["You can no longer unbind the target and menu actions in Blizzard's click-casting, and they must be left at the default left-click and right-click. Reset them to default, and then make your changes in Clique. This is not an issue we can fix, we just acknowledge it here for clarity."] = "블리자드 클릭 시전에서는 대상 선택·메뉴 표시 동작을 해제할 수 없으며 기본 왼쪽·오른쪽 클릭으로 유지해야 합니다. 기본값으로 복원한 뒤 Clique에서 원하는 동작을 지정하세요. 이 제한은 Clique에서 수정할 수 없습니다.",
    ["Frames that load or change their unit while you're in combat may not get bindings applied until combat ends."] = "전투 중 새로 불러오거나 표시 대상을 변경한 프레임에는 전투가 끝난 뒤 단축키가 적용될 수 있습니다.",
}
for _, entry in ipairs(addon.changelog or {}) do
    for i, item in ipairs(entry.items or {}) do entry.items[i] = text[item] or item end
end
local known = addon.changelogKnownIssues
if known then
    known.title = text[known.title] or known.title
    for i, item in ipairs(known.items or {}) do known.items[i] = text[item] or item end
end
