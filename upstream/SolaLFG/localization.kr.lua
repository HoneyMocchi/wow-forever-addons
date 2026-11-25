-- =========================================================================
-- SolaLFG - Korean (koKR) Localization
-- =========================================================================

if (FP_GetLocale and FP_GetLocale() or GetLocale()) ~= "koKR" then return end

-- Korean Dictionary Table
FP_L_KR = {}

-- Common UI & Panel
FP_L_KR["LFG"] = "파티 찾기"
FP_L_KR["Close"] = "닫기"
FP_L_KR["Settings"] = "설정"
FP_L_KR["Refresh"] = "새로고침"
FP_L_KR["Apply"] = "신청"
FP_L_KR["Apply via Whisper"] = "파티 신청 (귓속말)"
FP_L_KR["Send Whisper"] = "귓속말 보내기"
FP_L_KR["Open Chat (/w)"] = "대화창 열기 (/w)"
FP_L_KR["Invite"] = "초대"
FP_L_KR["Who (/who)"] = "누구 (/who)"
FP_L_KR["List Group"] = "파티 등록"
FP_L_KR["Blizzard Group Finder"] = "블리자드 파티 찾기"
FP_L_KR["Dungeon Filter"] = "던전 필터"
FP_L_KR["Detailed Filters"] = "상세 필터"
FP_L_KR["Reset All Filters"] = "모든 필터 초기화"
FP_L_KR["All"] = "전체"
FP_L_KR["Select All"] = "전체 선택"
FP_L_KR["Clear"] = "지우기"
FP_L_KR["Clear All"] = "모두 지우기"
FP_L_KR["Add"] = "추가"
FP_L_KR["Level"] = "레벨"
FP_L_KR["Level ▲"] = "레벨 ▲"
FP_L_KR["Level ▼"] = "레벨 ▼"
FP_L_KR["Dungeons"] = "던전 목록"
FP_L_KR["Dungeons ▼"] = "던전 목록 ▼"
FP_L_KR["ROW_COUNT_FORMAT"] = "(%d팀) (%d명)"
FP_L_KR["Filters ▶"] = "필터 ▶"
FP_L_KR["Filters %s"] = "필터 %s"
FP_L_KR["Filters(%d) %s"] = "필터(%d) %s"
FP_L_KR["Active filters: %d"] = "적용 중인 필터: %d개"
FP_L_KR["%d listings found"] = "%d개 등록됨"
FP_L_KR["Groups: %d  ·  Seekers: %d"] = "파티: %d  ·  개인: %d"
FP_L_KR["Formed Groups  ·  %d"] = "구성된 파티  ·  %d"
FP_L_KR["Individual Seekers"] = "파티를 찾는 플레이어"
FP_L_KR["Individual Seekers  ·  %d"] = "파티를 찾는 플레이어  ·  %d"
FP_L_KR["No listings found."] = "등록된 파티/신청자가 없습니다."
FP_L_KR["Searching..."] = "검색 중..."
FP_L_KR["Initializing LFG (C_LFGList)..."] = "파티 탐색기 초기화 중 (C_LFGList)..."
FP_L_KR["Search timed out. Please click [Refresh]."] = "검색 시간이 초과되었습니다. [새로고침]을 눌러주세요."
FP_L_KR["Search request failed. (Please try again shortly)"] = "검색 요청에 실패했습니다. (잠시 후 다시 시도)"
FP_L_KR["Waiting to refresh... (%ds cooldown)"] = "검색 대기 중... (%d초 쿨다운)"
FP_L_KR["Last refreshed: %d sec ago"] = "마지막 검색: %d초 전"
FP_L_KR["Last refreshed: Never"] = "마지막 검색: 없음"
FP_L_KR["Cannot send a whisper to yourself."] = "자신에게는 귓속말을 보낼 수 없습니다."
FP_L_KR["Please select a listing first."] = "먼저 목록에서 대상을 선택하세요."
FP_L_KR["LFG filters have been reset."] = "파티 탐색기 필터가 초기화되었습니다."
FP_L_KR["All dungeon filters enabled."] = "모든 던전 필터가 활성화되었습니다."
FP_L_KR["Page: %d / %d (%d-%d of %d)"] = "페이지: %d / %d (%d-%d / 총 %d)"
FP_L_KR["(Currently Active)"] = "(현재 작동중)"
FP_L_KR["[Exclude]"] = "[제외]"
FP_L_KR["Anonymous"] = "익명"
FP_L_KR["Unnamed"] = "무명"
FP_L_KR["Unknown"] = "알 수 없음"
FP_L_KR["Unknown Class"] = "알 수 없는 직업"
FP_L_KR["Unspecified Activity"] = "활동 미지정"
FP_L_KR["Other Dungeon #%s"] = "기타 던전 #%s"
FP_L_KR["Hello, inquiring about your LFG listing."] = "안녕하세요, 파티 찾기 등록 보고 문의드립니다."

-- Roles
FP_L_KR["Tank"] = "방어"
FP_L_KR["Healer"] = "치유"
FP_L_KR["Damage"] = "공격"
FP_L_KR["DPS"] = "딜러"
FP_L_KR["Role_Tank_Short"] = "탱"
FP_L_KR["Role_Healer_Short"] = "힐"
FP_L_KR["Role_DPS_Short"] = "딜"
FP_L_KR["Open Roles"] = "비어있는 역할"
FP_L_KR["Open Tank Slot"] = "탱커 빈자리"
FP_L_KR["Open Healer Slot"] = "힐러 빈자리"
FP_L_KR["Open DPS Slot"] = "딜러 빈자리"
FP_L_KR["Formed Roles"] = "그룹 구성"
FP_L_KR["Has Tank"] = "탱커 있음"
FP_L_KR["Has Healer"] = "힐러 있음"
FP_L_KR["Groups with Tank"] = "탱커 보유 파티"
FP_L_KR["Groups with Healer"] = "힐러 보유 파티"
FP_L_KR["Tank Seekers"] = "탱커 플레이어"
FP_L_KR["Healer Seekers"] = "힐러 플레이어"
FP_L_KR["DPS Seekers"] = "딜러 플레이어"

-- Classes
FP_L_KR["Warrior"] = "전사"
FP_L_KR["Paladin"] = "성기사"
FP_L_KR["Hunter"] = "사냥꾼"
FP_L_KR["Rogue"] = "도적"
FP_L_KR["Priest"] = "사제"
FP_L_KR["Shaman"] = "주술사"
FP_L_KR["Mage"] = "마법사"
FP_L_KR["Warlock"] = "흑마법사"
FP_L_KR["Druid"] = "드루이드"

-- Filters & Chips Tooltips
FP_L_KR["Configure role vacancies, seeker roles, levels, and classes."] = "비어있는 역할, 파티를 찾는 플레이어, 레벨 및 직업 조건을 설정합니다."
FP_L_KR["Show groups with an open tank slot."] = "탱커를 구하는 중인 파티를 표시합니다."
FP_L_KR["Show groups with an open healer slot."] = "힐러를 구하는 중인 파티를 표시합니다."
FP_L_KR["Show groups with an open DPS slot."] = "딜러를 구하는 중인 파티를 표시합니다."
FP_L_KR["Show groups that already have 1 or more tanks."] = "탱커가 1명 이상 포함된 파티를 표시합니다."
FP_L_KR["Show groups that already have 1 or more healers."] = "힐러가 1명 이상 포함된 파티를 표시합니다."
FP_L_KR["Show individual players listed as Tank."] = "탱커로 등록한 플레이어를 표시합니다."
FP_L_KR["Show individual players listed as Healer."] = "힐러로 등록한 플레이어를 표시합니다."
FP_L_KR["Show individual players listed as DPS."] = "딜러로 등록한 플레이어를 표시합니다."
FP_L_KR["Hide Groups with Excluded Classes"] = "미선택 직업 포함 파티 숨김"
FP_L_KR["Hide formed groups that contain unselected classes."] = "선택되지 않은 직업이 포함된 파티를 목록에서 숨깁니다."
FP_L_KR["Seeker Level Filter"] = "레벨 필터"
FP_L_KR["Seeker Class Filter"] = "직업 필터"
FP_L_KR["%s Class Filter"] = "%s 직업 필터"
FP_L_KR["Toggle listings for %s individual seekers."] = "%s 플레이어 표시 여부를 전환합니다."
FP_L_KR["Filter: All Levels"] = "필터: 전체 레벨"
FP_L_KR["Filter: Level-appropriate"] = "필터: 내 레벨 던전"
FP_L_KR["Show all dungeon listings regardless of level."] = "레벨 제한 없이 등록된 모든 던전을 표시합니다."
FP_L_KR["Show dungeons appropriate for your current level."] = "현재 캐릭터 레벨에 맞는 던전만 표시합니다."
FP_L_KR["Click: Switch to All Levels mode"] = "클릭: 전체 레벨 모드로 전환"
FP_L_KR["Click: Switch to Level mode"] = "클릭: 레벨별 모드로 전환"
FP_L_KR["Filter by specific dungeons."] = "원하는 던전을 선택하여 관심 던전만 표시합니다."
FP_L_KR["Left-Click: Toggle dungeon filter menu"] = "좌클릭: 던전 필터 메뉴 열기/닫기"
FP_L_KR["Wheel-Click: Toggle View All / Filtered"] = "휠클릭: 모두 보기 / 관심 던전 전환"
FP_L_KR["Right-Click: Clear selected dungeons"] = "우클릭: 선택된 던전 비우기 (모두 보기)"
FP_L_KR["Reset Selection"] = "선택 비우기"
FP_L_KR["Select Fit"] = "적정 던전"
FP_L_KR["Level-fit Dungeons"] = "적정 던전 선택"
FP_L_KR["Showing all dungeons."] = "모든 던전을 표시합니다. (모두 보기)"
FP_L_KR["All dungeon filters cleared."] = "관심 던전 목록을 모두 비웠습니다. (모두 보기)"
FP_L_KR["Clear Excluded"] = "초기화"
FP_L_KR["Clear Exclusions"] = "제외 초기화"
FP_L_KR["Restore all dungeons excluded from the list via Ctrl+Left-Click."] = "Ctrl+좌클릭으로 목록에서 제외한 던전을 모두 복원합니다."
FP_L_KR["Excluded dungeons cleared."] = "제외된 던전 목록을 초기화했습니다. (모든 던전 표시)"
FP_L_KR["Currently excluded: %d"] = "|cffFF6666현재 제외된 던전: %d개|r"
FP_L_KR["Click: Clear exclusions"] = "|cff66FF99클릭|r: 제외 목록 초기화"
FP_L_KR["No dungeons currently excluded."] = "현재 제외된 던전이 없습니다."
FP_L_KR["Filtered to interested dungeons."] = "관심 던전 필터가 활성화되었습니다."
FP_L_KR["Filtered to interested dungeons (%s)."] = "관심 던전 필터가 활성화되었습니다. (%s)"
FP_L_KR["No interested dungeons selected."] = "선택된 관심 던전이 없습니다. 던전 목록에서 관심 던전을 먼저 선택해주세요."
FP_L_KR["Added '%s' to interested dungeons."] = "'%s' 던전을 관심 던전에 추가했습니다."
FP_L_KR["Removed '%s' from interested dungeons."] = "'%s' 던전을 관심 던전에서 제외했습니다."
FP_L_KR["Level-fit dungeons selected (%d)."] = "내 레벨에 맞는 적정 던전(%d개)이 관심 던전으로 선택되었습니다."
FP_L_KR["No level-fit dungeons found for your level."] = "현재 레벨에 맞는 적정 던전이 없습니다."
FP_L_KR["Filtering Interested Dungeons"] = "관심 던전 필터 적용 중"
FP_L_KR["Viewing All Dungeons (Paused)"] = "모두 보기 (관심 던전 필터 일시 해제)"
FP_L_KR["%d dungeons"] = "%d개 던전"
FP_L_KR["Dungeon Level Sorting"] = "던전 레벨 정렬"
FP_L_KR["Sort dungeon listings in ascending (▲) or descending (▼) level order."] = "던전 목록을 레벨 오름차순(▲) 또는 내림차순(▼)으로 정렬합니다."
FP_L_KR["Current: Ascending (Low to High)"] = "현재: 오름차순 (낮은 레벨부터)"
FP_L_KR["Current: Descending (High to Low)"] = "현재: 내림차순 (높은 레벨부터)"
FP_L_KR["Toggle the Blizzard LFGList panel."] = "블리자드 파티 탐색기(LFGList) 패널을 열거나 닫습니다."
FP_L_KR["Open or close the default Blizzard LFG window (I key)."] = "블리자드 기본 파티 찾기 창(단축키 I)을 열거나 닫습니다."
FP_L_KR["Click: Toggle filter panel"] = "클릭: 필터 패널 열기/닫기"
FP_L_KR["No dungeons found for your current level."] = "현재 레벨에 맞는 던전이 없습니다."
FP_L_KR["Dungeon List Scroll"] = "던전 목록 스크롤"
FP_L_KR["Scroll with mouse wheel or drag slider."] = "마우스 휠 스크롤 또는 슬라이더 드래그"

-- Row Details & Shortcuts
FP_L_KR["Left-Click: Collapse / Expand"] = "좌클릭: 접기 / 펼치기"
FP_L_KR["Ctrl + Left-Click: Exclude this dungeon"] = "|cffFF6666[Ctrl + 좌클릭]|r: 관심 던전 제외"
FP_L_KR["Status: Interested Dungeon"] = "|cff5ABFBA★ 현재 관심 던전으로 등록됨|r"
FP_L_KR["Ctrl + Left-Click: Add to interested dungeons"] = "|cff5ABFBA[Ctrl + 좌클릭]|r: 이 던전을 관심 던전으로 등록"
FP_L_KR["Ctrl + Left-Click: Remove from interested dungeons"] = "|cffFF6666[Ctrl + 좌클릭]|r: 관심 던전 제외"
FP_L_KR["Interested_Add"] = "관심 던전 등록"
FP_L_KR["Interested_Remove"] = "관심 던전 제외"
FP_L_KR["Alt+Left-Click: Whisper  ·  Ctrl+Left-Click: Interest  ·  Alt+Right-Click: Chat"] = "|cffD4A745Alt+좌클릭|r: 귓속말  |cff8A8580·|r  |cffD4A745Alt+우클릭|r: 대화창  |cff8A8580·|r  |cffFF6666[Ctrl+좌클릭]|r: %s"
FP_L_KR["Shortcut Tip: Ctrl+Click row to toggle interest"] = "|cffFF6666Ctrl+좌클릭|r: 관심 던전에서 제외"
FP_L_KR["Shortcut Tip: Ctrl+Click row to exclude"] = "|cffFF6666Ctrl+좌클릭|r: 관심 던전에서 제외"
FP_L_KR["Current Zone: %s"] = "현재 위치: %s"
FP_L_KR["Target Activity: %s"] = "신청 던전: %s"
FP_L_KR["Target Role: %s"] = "신청 역할: %s"
FP_L_KR["Leader Zone: %s"] = "파티장 위치: %s"
FP_L_KR["Party Members (%d):"] = "파티원 목록 (%d명):"
FP_L_KR["Leader: %s%s"] = "파티장: %s%s"
FP_L_KR["Voice Chat: %s"] = "음성 대화: %s"
FP_L_KR["Alt+Left-Click: Whisper  ·  Ctrl+Left-Click: Exclude  ·  Alt+Right-Click: Chat"] = "|cffD4A745Alt+좌클릭|r: 귓속말  |cff8A8580·|r  |cffD4A745Alt+우클릭|r: 대화창  |cff8A8580·|r  |cffFF6666[Ctrl+좌클릭]|r: 관심 던전 제외"
FP_L_KR["Shift+Left-Click: /who  ·  Right-Click: Context Menu"] = "Shift+좌클릭: /who 정보  ·  우클릭: 메뉴 열기"
FP_L_KR["Send whisper to the party leader.\n(Shortcut: Alt + Click in list or press Enter in input)"] = "선택한 파티장에게 귓속말 문구를 전송합니다.\n(단축키: 목록에서 Alt + 클릭 또는 입력창 Enter)"

-- Update Notice Dialog
FP_L_KR["Update Notes"] = "업데이트 안내"
FP_L_KR["Major Improvements & Feature Updates"] = "주요 변경 및 기능 개선 안내"
FP_L_KR["Confirm & Close"] = "확인 및 닫기"
FP_L_KR["UPDATE_NOTICE_P1_TITLE"] = "|cff5ABFBA· 채팅창 [Alt + 좌클릭] 파티 초대 기능 추가|r"
FP_L_KR["UPDATE_NOTICE_P1_DESC"]  = "  이제부터 채팅창의 플레이어 닉네임을 [Alt + 좌클릭]하면 파티 초대가 가능해집니다."

-- Minimap & LDB
FP_L_KR["Left-Click"] = "왼쪽 클릭"
FP_L_KR["Right-Click"] = "오른쪽 클릭"
FP_L_KR["Alt + Click"] = "Alt + 클릭"
FP_L_KR["Shift + Left-Click"] = "Shift + 좌클릭"
FP_L_KR["Toggle Party Finder"] = "파티 찾기 도우미 열기"
FP_L_KR["Lock / Unlock Icon"] = "아이콘 고정 / 해제"
FP_L_KR["Enable / Disable Addon"] = "애드온 작동 / 작동정지"
FP_L_KR["Active"] = "작동중"
FP_L_KR["Inactive"] = "작동정지"
FP_L_KR["Locked"] = "고정됨"
FP_L_KR["Movable (Drag)"] = "이동가능 (좌클릭 드래그)"
FP_L_KR["Addon Status"] = "애드온 상태"
FP_L_KR["Icon Position"] = "아이콘 위치"

-- Key Binding
FP_L_KR["SolaLFG Key Binding"] = "SolaLFG 열기 단축키 지정"
FP_L_KR["Press a key (or key combination) to bind."] = "지정할 키(또는 조합키)를 누르세요."
FP_L_KR["Waiting for key press..."] = "키 입력 대기 중..."
FP_L_KR["ESC: Cancel  ·  Right-Click button to unbind"] = "ESC: 취소  ·  단축키 해제는 버튼 우클릭"
FP_L_KR["Waiting for key"] = "키 입력 대기"
FP_L_KR["Key bound to [|cff66FF99%s|r]. (Replaced '%s')"] = "단축키가 [|cff66FF99%s|r](으)로 설정되었습니다. (기존 '%s' 기능 대체)"
FP_L_KR["Key bound to [|cff66FF99%s|r]."] = "단축키가 [|cff66FF99%s|r](으)로 설정되었습니다."
FP_L_KR["Key binding cancelled because combat started."] = "전투가 시작되어 단축키 설정을 취소했습니다."
FP_L_KR["Keybind"] = "단축키"
FP_L_KR["SolaLFG Toggle Hotkey"] = "SolaLFG 열기 단축키"
FP_L_KR["Current Key: |cff66FF99%s|r"] = "현재 단축키: |cff66FF99%s|r"
FP_L_KR["Saved in WoW Key Bindings to instantly open and close the window."] = "와우 단축키 설정(Bindings)에 저장되어 창을 바로 열고 닫을 수 있습니다."
FP_L_KR["Change Keybind"] = "단축키 변경"
FP_L_KR["Unbind"] = "단축키 해제"
FP_L_KR["No hotkey currently bound."] = "현재 설정된 단축키가 없습니다."
FP_L_KR["Click to set a hotkey to quickly open/close SolaLFG."] = "클릭하여 SolaLFG 창을 바로 여는 단축키를 지정할 수 있습니다."
FP_L_KR["Set Keybind"] = "단축키 지정"
FP_L_KR["Cannot change key bindings while in combat."] = "전투 중에는 단축키를 변경할 수 없습니다."
FP_L_KR["Hotkey has been unbound."] = "열기 단축키가 해제되었습니다."

-- UI Scale & Resize
FP_L_KR["Window Scale (UI Scale)"] = "창 크기 조절 (UI Scale)"
FP_L_KR["Drag the slider to adjust SolaLFG scale (50% ~ 200%)."] = "슬라이더를 드래그하여 SolaLFG 창 크기를 조절합니다. (50% ~ 200%)"
FP_L_KR["Drag: Resize window | Mouse wheel: Scroll list"] = "드래그: 창 크기 조절 (너비/높이) | 마우스 휠: 스크롤 이동"

-- Whisper Presets & Auto Msg
FP_L_KR["Whisper Msg: "] = "귓속말 문구 : "
FP_L_KR["Whisper Message Presets (Click to open)"] = "귓속말 문구 목록 (클릭하여 열기)"
FP_L_KR["Select or delete saved whisper messages.\nSupports [Auto] Level + Class option."] = "저장된 문구를 선택하거나 삭제할 수 있습니다.\n[자동] 레벨+직업 옵션도 지원합니다."
FP_L_KR["Add Whisper Preset"] = "귓속말 문구 추가"
FP_L_KR["Saves current input text to the preset list.\n(Up to 5 messages)"] = "현재 입력창의 문구를 목록에 저장합니다.\n(최대 5개까지 등록 가능)"
FP_L_KR["Whisper Message Presets"] = "귓속말 문구 목록"
FP_L_KR["Up to 5 saved"] = "최대 5개 저장"
FP_L_KR["Auto"] = "자동"
FP_L_KR["Selected"] = "선택됨"
FP_L_KR["Selected auto level/class message: %s"] = "[자동 신청] 현재 레벨/직업 문구로 선택되었습니다: %s"
FP_L_KR["Current Level + Class + Inv please"] = "현재레벨 + 직업 + 초대 부탁드립니다"
FP_L_KR["Automatically updates your level whenever SolaLFG opens."] = "선택 시 SolaLFG 창을 열 때마다 레벨이 자동으로 갱신됩니다."
FP_L_KR["Whisper message selected: %s"] = "귓속말 문구가 선택되었습니다: %s"
FP_L_KR["Delete Message"] = "문구 삭제"
FP_L_KR["Remove this message from the list."] = "이 문구를 목록에서 제거합니다."
FP_L_KR["Saved message deleted: %s"] = "저장 문구가 삭제되었습니다: %s"
FP_L_KR["No saved messages - Register using [Add]"] = "저장된 문구 없음 - [추가] 버튼으로 등록"
FP_L_KR["Please enter a message to save first."] = "저장할 문구를 먼저 입력해주세요."
FP_L_KR["This message is already saved."] = "이미 저장되어 있는 문구입니다."
FP_L_KR["You can save up to 5 preset messages."] = "저장 문구는 최대 5개까지 등록할 수 있습니다."
FP_L_KR["Whisper message saved: |cffD4A745%s|r"] = "귓속말 문구가 저장되었습니다: |cffD4A745%s|r"

-- Options Menu
FP_L_KR["Window Scale"] = "창 크기"
FP_L_KR["Window Color"] = "창 색상"
FP_L_KR["Minimap Icon"] = "미니맵 아이콘 보기"
FP_L_KR["Close with ESC"] = "ESC로 창 닫기"
FP_L_KR["Reset"] = "설정 초기화"
FP_L_KR["Reset Window Position"] = "창 위치 초기화"
FP_L_KR["Reset Window Size"] = "창 크기 초기화"
FP_L_KR["Reset All Settings"] = "모든 설정 초기화"
FP_L_KR["View Update Notes"] = "업데이트 안내 보기"
FP_L_KR["LFG_ONLY_ON_MSG"] = "기본 파티 탐색기 전용 모드가 활성화되었습니다. (채팅 감지 중지)"
FP_L_KR["LFG_ONLY_OFF_MSG"] = "통합 모드가 활성화되었습니다. (채팅 감지 재개)"

function FP_ApplyKoreanLegacyGlobals()
	FP_C_TITLE = "SolaLFG "..FP_GetVersionString()
	FP_DEFAULT_PARTY_CHANNEL = "파티"
	FP_DEFAULT_WHISPER = "%s %s 초대 부탁드립니다"
	FP_TEXT_AUTO_WHISPER_FORMAT = "%d %s 초대 부탁드립니다"
	FP_TEXT_AUTO_WHISPER_LABEL = "현재레벨 + 직업 + 초대 부탁드립니다"
	FP_TEXT_STOPPED = "(중단)"
	FP_TEXT_EXCEPTION = "제외"
	FP_TEXT_EXCEPTION_DELETE = "제외초기화"
	FP_TEXT_WHISPER = "귓말창열기"
	FP_TEXT_WHO = "파장누구지"
	FP_TEXT_HELP = "도움말"
	FP_TEXT_APPLY = "파티신청"
	FP_TEXT_START_AD = "광고시작"
	FP_TEXT_STOP_AD = "광고중단"
	FP_TEXT_APPLY_FILTER = "적용"
	FP_TEXT_IGNORE = "확인"
	FP_TEXT_WH_LABEL = "귓속말 문구 : "
	FP_TEXT_AD_LABEL = "광고글 문구 : "
	FP_TEXT_FILTER_LABEL = "필터링 문구 : "
	FP_TEXT_IGNORE_LABEL = "무시할 문구 : "
	FP_TEXT_CLOSE = "닫기"
	FP_TEXT_LIST_LABEL = "광고 문구"
	FP_OPTION = "설정"
	FP_TEXT_DUNGEON_LABEL = "던전 / 레이드"
	FP_TEXT_SHOUTER_LABEL = "닉네임"
	FP_TEXT_MSG_LABEL = "구인 내용"
	FP_TEXT_TIME_LABEL = "시간"
	FP_BTN_WHISPER = "귓말"
	FP_BTN_WHO = "정보"
	FP_BTN_RESET = "초기화"
	FP_LABEL_FILTER = "필터:"
	FP_LABEL_IGNORE = "제외:"
	FP_LABEL_WH = "귓속말:"
	FP_LABEL_AD = "광고글"
	FP_TEXT_ADD = "추가"
	FP_TEXT_WH_PRESET_TITLE = "귓속말 문구 목록"
	FP_TEXT_WH_FULL = "저장 문구는 최대 5개까지 등록할 수 있습니다."
	FP_TEXT_WH_EXISTS = "이미 저장되어 있는 문구입니다."
	FP_TEXT_WH_EMPTY = "저장할 문구를 먼저 입력해주세요."
	FP_TEXT_WH_SAVED = "귓속말 문구가 저장되었습니다: %s"
	FP_TEXT_WH_DELETED = "저장 문구가 삭제되었습니다."

	-- Dungeon Filter Text
	FP_DUNGEONFILTER_RESETALL = "선택된 던전 비우기"
	FP_DUNGEONFILTER_SINGLE = "던전: %s"
	FP_DUNGEONFILTER_MULTI = "던전: %d개 선택"
	FP_DUNGEONFILTER_NOT_FILTERED = "모두 보기"
	FP_DUNGEONFILTER_NONE = "없음"

	-- Tooltip & System Messages
	FP_TOOLTIP_CLOSE = "창 닫기"
	FP_TOOLTIP_MAXMIZE = "창 최대화"
	FP_TOOLTIP_MINIMIZE = "창 최소화"
	FP_TOOLTIP_DECREASE = "줄 줄이기"
	FP_TOOLTIP_INCREASE = "줄 늘리기"
	FP_TOOLTIP_OPTION = "설정"
	FP_TOOLTIP_SORT_TIME = "시간순으로 정렬"
	FP_TOOLTIP_ACTIVATE_ON = "작동중\n클릭하면 비활성화"
	FP_TOOLTIP_ACTIVATE_OFF = "비활성화됨\n클릭하면 다시 작동"
	FP_TOOLTIP_POPUP_ON = "팝업 및 소리 작동중\n클릭하면 중단"
	FP_TOOLTIP_POPUP_OFF = "팝업 및 소리 중단됨"
	FP_TOOLTIP_AD_ON = "파티 광고중\n클릭하면 중단"
	FP_TOOLTIP_AD_OFF = "클릭하면 파티 광고 시작"
	FP_TOOLTIP_DUNGEON_FILTER = "|cff6BBF8A좌클릭|r : 던전 목록 펼치기\n|cffE0C068휠클릭|r : 모두 보기 / 관심 던전 전환\n|cffCF6679우클릭|r : 선택 던전 초기화 (비우기)\n\n- 관심 던전 목록 -\n"
	FP_TOOLTIP_CLASS_FILTER = "왼쪽 클릭 : 내 직업 골라줌\n오른쪽 클릭 : 관심 직업만 골라줌\n선택 : "
	FP_TOOLTIP_SHORTCUT_ALT = "단축키: Alt + 클릭"
	FP_TOOLTIP_SHORTCUT_ALT_RIGHT = "단축키: Alt + 우클릭"
	FP_TOOLTIP_SHORTCUT_CTRL = "단축키: Ctrl + 클릭"
	FP_TOOLTIP_SHORTCUT_SHIFT = "단축키: Shift + 클릭"
	FP_TOOLTIP_IGNORE = "무시할 광고 문구를 ,로 구분해서 입력 후 엔터 또는 버튼 클릭"
	FP_TOOLTIP_DISABLED = "비활성화됨"

	FP_MESSAGE_POPUP_ACTIVE = "파티 목록이 갱신될때 팝업 및 소리 알림을 표시합니다."
	FP_MESSAGE_POPUP_DEACTIVE = "팝업 및 소리 알림 기능을 비활성화 합니다."
	FP_MESSAGE_DUNGEON_RESET = "관심 던전 목록을 모두 삭제하셨습니다."
	FP_MESSAGE_START_AD = "파티 광고를 시작합니다."
	FP_MESSAGE_STOP_AD = "파티 광고를 중단합니다."
	FP_MESSAGE_NO_AD_TEXT = "광고글을 입력하셔야 합니다."
	FP_MESSAGE_DISABLE_ANNOUNCE = "MessageQueue 애드온을 설치하지 않아 광고 기능을 중단하였습니다.\nCurseForge에서 MessageQueue 애드온을 설치하면 광고 기능을 다시 활성화할 수 있습니다."
	FP_MESSAGE_EXCEPTION = "%s 님의 광고를 목록에서 제외합니다."
	FP_MESSAGE_CLEAR_EXCEPTION = "제외 대상 목록을 초기화 하셨습니다. 이제 모든 광고가 표시됩니다."
	FP_MESSAGE_START_DUNGEON_FILTER = "관심 던전만 목록에 표시합니다."
	FP_MESSAGE_STOP_DUNGEON_FILTER = "모든 던전을 목록에 표시합니다."
	FP_MESSAGE_APPLY_CUSTOM_FILTER = "사용자 정의 필터링 문구를 적용합니다."
	FP_MESSAGE_CUSTOM_IGNORE = "지정한 문구가 들어있는 광고를 표시하지 않습니다."
	FP_MESSAGE_CUSTOM_IGNORE_RESET = "무시할 문구를 초기화 하셨습니다. 이제 모든 광고가 표시됩니다."
	FP_MESSAGE_APPLY_CUSTOM_IGNORE = "제외 문구가 적용되었습니다: |cffCF6679%s|r"
	FP_MESSAGE_IGNORE_EMPTY = "제외할 문구를 입력해주세요. (쉼표로 여러 개 가능)"
	FP_MESSAGE_IGNORE_ALL_RESET = "제외 목록 및 제외 문구가 초기화되었습니다. 모든 구인 글이 표시됩니다."
	FP_BADGE_DETECT_ON = "|cff6BBF8A감지 ON|r"
	FP_BADGE_DETECT_OFF = "|cffCF6679감지 OFF|r"
	FP_BADGE_SOUND_ON = "|cffE09050팝업 ON|r"
	FP_BADGE_SOUND_OFF = "|cff8A8580팝업 OFF|r"
	FP_BADGE_AD_ON = "|cff6BBF8A광고 ON|r"
	FP_BADGE_AD_OFF = "|cff8A8580광고 OFF|r"
	FP_OPTIONS_CHANNEL = "파티찾기 채널 지정"
	FP_OPTIONS_INTERVAL = "광고 주기"
	FP_OPTIONS_VALID = "광고 유지 시간"
	FP_OPTIONS_FONTSIZE = "글자 크기"
	FP_OPTIONS_SCALE = "창 크기"
	FP_OPTIONS_COLOR = "창 색상"
	FP_OPTIONS_ICON = "미니맵 아이콘 보기"
	FP_OPTIONS_ESC = "ESC로 창 닫기"
	FP_OPTIONS_RIGHTBUTTON = "Ctrl+우클릭 파티 신청"
	FP_OPTIONS_LFG_ONLY = "기본 파티 탐색기만 표시"
	FP_OPTIONS_NORAID = "레이드 던전에 있을때 비활성화"
	FP_OPTIONS_NOPVP = "전장에 있을때 비활성화"
	FP_OPTIONS_RESET = "설정 초기화"
	FP_OPTIONS_RESETPOS = "창 위치"
	FP_OPTIONS_RESETSIZE = "창 크기"
	FP_OPTIONS_RESETALL = "모든 설정 초기화"
	FP_TEXT_RESIZE_TIP = "드래그: 창 크기 조절 (너비/높이) | 마우스 휠: 스크롤 이동"
	FP_MESSAGE_LFG_ONLY_ON = "기본 파티 탐색기 전용 모드가 활성화되었습니다. (채팅 감지 중지)"
	FP_MESSAGE_LFG_ONLY_OFF = "통합 모드가 활성화되었습니다. (채팅 감지 재개)"
	FP_MESSAGE_NEWVERSION_RESET = "새로 설치 또는 구 버전에서 업그레이드 하셨습니다."
	FP_MESSAGE_RESETALL = "설정 초기값을 불러옵니다."
	FP_MESSAGE_NOTARGET = "명령을 실행할 대상을 먼저 목록에서 선택하세요."
	FP_MESSAGE_ICON_LOCK = "미니맵 아이콘을 이동할 수 없도록 고정합니다."
	FP_MESSAGE_ICON_UNLOCK = "이제 미니맵 아이콘을 이동할 수 있습니다."
	FP_MESSAGE_ACTIVE = "%s - 파티 찾기 도우미를 활성화 합니다."
	FP_MESSAGE_DEACTIVE = "%s - 파티 찾기 도우미를 비활성화 합니다."

	BINDING_HEADER_SOLALFG = "SolaLFG"
	BINDING_NAME_FP_TOGGLE = "SolaLFG 창 열기/닫기"
end

-- If running on a Korean client, apply Korean strings immediately
if FP_GetLocale() == "koKR" then
	FP_ApplyLocale("koKR")
end

FP_HELP_DATA = {
	{ t = "title", text = "-- 기본 사용법 --" },
	{ t = "text", text = "파티찾기 채널에 올라오는 구인 광고를 자동으로 수집하여 목록에 표시합니다." },
	{ t = "gap" },
	{ t = "header", text = "[채널 설정]" },
	{ t = "text", text = "1. 채팅창에 '/입장 파티찾기'를 입력하여 파티찾기 채널에 먼저 입장하세요." },
	{ t = "text", text = "2. 설정(톱니바퀴) > '파티찾기 채널 지정' 메뉴에서 해당 파티찾기 채널을 선택해 주어야 합니다." },
	{ t = "text", text = "※ 파티찾기 채널에 입장하고 설정에서 채널이 올바르게 지정되어야 구인 글이 정상적으로 수집됩니다." },
	{ t = "gap" },
	{ t = "header", text = "[목록 조작]" },
	{ t = "key", key = "왼쪽 클릭", desc = "구인 글 선택" },
	{ t = "key", key = "Alt + 왼쪽 클릭", desc = "선택한 파티에 귓속말로 신청" },
	{ t = "key", key = "Alt + 오른쪽 클릭", desc = "파티장에게 귓속말 창 열기" },
	{ t = "key", key = "Shift + 왼쪽 클릭", desc = "파티장 정보 보기 (/who)" },
	{ t = "key", key = "Ctrl + 왼쪽 클릭", desc = "선택한 대상의 구인 글 제외" },
	{ t = "gap" },
	{ t = "header", text = "[자동 구인 광고 (MessageQueue 연동)]" },
	{ t = "text", text = "'MessageQueue' 애드온을 함께 설치하면 파티 구인 광고를 설정된 주기마다 자동으로 채널에 등록하고 반복 전송할 수 있습니다." },
	{ t = "text", text = "1. MessageQueue 애드온을 설치합니다. (CurseForge 등)" },
	{ t = "text", text = "2. 애드온 설치 시 창 하단에 광고 입력창과 [광고시작] 버튼이 나타나며, 상단 타이틀바에 [광고 OFF] 버튼이 표시됩니다." },
	{ t = "text", text = "3. 설정(톱니바퀴) > '파티찾기 채널 지정'에서 광고를 전송할 채널이 체크되어 있는지 확인하세요." },
	{ t = "text", text = "4. 하단 광고 입력창에 구인 문구를 입력한 뒤 [광고시작] 버튼을 누르면 광고가 주기적으로 자동 전송됩니다." },
	{ t = "text", text = "5. 광고 중단: [광고중단] 버튼 클릭, 상단 [광고 ON] 버튼 클릭, 또는 미니맵 아이콘 Ctrl+클릭으로 즉시 중단할 수 있습니다." },
	{ t = "key", key = "광고 시작 / 중단", desc = "하단 버튼 또는 상단 광고 알약 버튼" },
	{ t = "key", key = "Ctrl + 미니맵 클릭", desc = "파티 광고 시작 / 정지 토글" },
	{ t = "key", key = "광고 주기 설정", desc = "설정 메뉴에서 30~300초 간격 선택 가능" },
	{ t = "gap" },
	{ t = "header", text = "[귓속말 문구]" },
	{ t = "text", text = "하단의 귓속말 입력창에 원하는 문구를 작성할 수 있습니다. [자동] 모드를 사용하면 현재 레벨과 직업이 자동으로 포함됩니다." },
	{ t = "text", text = "문구 목록 드롭다운에서 최대 5개까지 문구를 저장하고 전환할 수 있습니다." },
	{ t = "gap" },
	{ t = "header", text = "[던전 필터 (좌측 패널)]" },
	{ t = "key", key = "왼쪽 클릭", desc = "관심 던전만 보기 / 전체 보기 전환" },
	{ t = "key", key = "오른쪽 클릭", desc = "관심 던전 선택 (드롭다운)" },
	{ t = "gap" },
	{ t = "header", text = "[기본 파티 탐색기 (우측 패널)]" },
	{ t = "key", key = "던전 필터 좌클릭", desc = "던전 필터 드롭다운 메뉴 열기/닫기" },
	{ t = "key", key = "던전 필터 휠클릭", desc = "모두 보기 / 관심 던전 필터 빠른 전환" },
	{ t = "key", key = "던전 필터 우클릭", desc = "선택된 관심 던전 비우기 (모두 보기)" },
	{ t = "key", key = "Ctrl + 좌클릭", desc = "목록에서 해당 던전 관심 던전 제외" },
	{ t = "key", key = "Alt + 좌클릭", desc = "파티장에게 신청 귓속말 전송" },
	{ t = "key", key = "Alt + 우클릭", desc = "파티장에게 귓속말 창 열기" },
	{ t = "gap" },
	{ t = "header", text = "[제외 기능]" },
	{ t = "text", text = "제외 입력창에 무시할 키워드를 쉼표(,)로 구분하여 입력하면 해당 키워드가 포함된 광고가 숨겨집니다." },
	{ t = "gap" },
	{ t = "header", text = "[설정 항목]" },
	{ t = "key", key = "기본 탐색기만 표시", desc = "채팅 감지를 끄고 파티 탐색기만 단독 사용" },
	{ t = "key", key = "광고 주기", desc = "자동 광고 전송 간격 (30~300초)" },
	{ t = "key", key = "광고 유지 시간", desc = "구인 글 표시 유지 시간 (60~300초)" },
	{ t = "key", key = "글자 크기", desc = "목록 텍스트 크기 조절" },
	{ t = "key", key = "창 크기 (UI)", desc = "전체 UI 스케일 조절" },
	{ t = "key", key = "미니맵 아이콘", desc = "미니맵 아이콘 표시 여부" },
	{ t = "key", key = "ESC 닫기", desc = "ESC 키로 창 닫기" },
	{ t = "gap" },
	{ t = "header", text = "[기타]" },
	{ t = "key", key = "채팅창 이름 Alt+클릭", desc = "채팅창의 캐릭터 이름을 클릭하여 즉시 파티 초대" },
	{ t = "key", key = "빈 곳 우클릭", desc = "파티 찾기 창 닫기 (단독 우클릭)" },
	{ t = "key", key = "/sola, /sl", desc = "채팅 명령어로 창 열기/닫기" },
	{ t = "key", key = "/sola card", desc = "보기 방식 선택 카드 팝업 열기 (/sl card)" },
	{ t = "text", text = "단축키 설정에서 SolaLFG 표시 단축키를 지정할 수 있습니다." },
	{ t = "text", text = "※ Alt/Ctrl/Shift 키를 누른 상태에서는 창이 닫히지 않아 귓속말 등의 단축키와 충돌하지 않습니다." },
}