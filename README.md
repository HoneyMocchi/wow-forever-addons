# WoW Forever 팀 애드온 팩

현재 설치된 한글화·기능 수정본을 보존한 비공개 팀 저장소입니다. `2026.11.14.1`은 업데이트 검토 후보이며 게임 내 검증 전입니다. 기본 배포 태그는 `pack-2026.11.13.1`입니다.

## 포함 범위

- 주요 애드온/부속 모듈 34개 폴더와 AI 응답 슬롯 200개: 총 234개.
- `addons/`: 팀에서 유지하는 실제 배포 소스. 변경은 이곳에서 수행합니다.
- `upstream/`: 출처를 확인한 수정 없는 원본. 최신 파일 ID와 SHA-256은 lock을 참고하세요.
- `manifests/addons.lock.json`: 버전, 의존성, 각 파일 SHA-256, 원본 확보 여부.
- `docs/`: 수정 이력과 한글 용어집.

원본을 확보하지 못한 애드온은 `unverified`입니다. 현재 수정본을 원본이라고 간주해 자동 업데이트하지 마세요. 원본 출처가 확인되지 않은 항목의 URL은 비워 두었습니다.

AI 응답/통신 자료, 계정 설정(WTF/SavedVariables), 인증 정보와 PC 브리지 실행 환경은 포함하지 않습니다. AI 슬롯의 Inbox.lua는 빈 배포 템플릿입니다. 각 팀원 PC에서 AI 기능을 쓰려면 브리지를 별도로 구성해야 합니다.

## 팀원 동기화

Python 3.12 이상, Git이 필요합니다. 본인의 GitHub 계정에 이 비공개 저장소 읽기 권한이 있어야 합니다.

```powershell
git clone https://github.com/HoneyMocchi/wow-forever-addons.git
cd wow-forever-addons
git fetch origin --tags
git checkout --detach pack-2026.11.13.1
python tools/sync.py --addons-path "D:\Game\World of Warcraft\_forever_\Interface\AddOns"
# 미리보기 결과를 확인한 뒤 실제 적용
python tools/sync.py --addons-path "D:\Game\World of Warcraft\_forever_\Interface\AddOns" --apply
```

게임 종료, 깨끗한 체크아웃, 원격과 일치하는 배포 태그, 파일 해시를 검사합니다. 이미 설치된 파일이 팀 기준과 다르면 덮어쓰지 않고 중단합니다. 첫 설치 때 다른 버전이 설치되어 있다면 기존 폴더를 직접 백업한 뒤 해당 관리 폴더만 비운 상태에서 다시 실행하세요.

목록 밖 개인 애드온은 건드리지 않습니다. AI Inbox 및 통신 디렉터리는 해당 PC의 내용을 유지합니다. 교체 전 파일은 `Interface/.addonpack-backup-*`에 남습니다. 교체 중 예외가 나면 이미 교체한 폴더도 역순으로 복구합니다. 전원 차단 등 프로세스 자체가 중단된 경우에는 이 백업을 이용해 수동 복구해야 합니다.

이전 버전이 변경한 SavedVariables 데이터 형식까지 되돌려 주지는 않습니다. 설정 구조를 바꾸는 업데이트는 별도 설정 백업과 게임 내 확인이 필요합니다.

## 수정 제출

1. 기본 브랜치에서 작업 브랜치를 만듭니다.
2. `addons/`의 소스를 수정하고 변경 목적을 `docs/modifications.md`에 기록합니다.
3. `python tools/refresh-lock.py`로 파일 해시를 갱신합니다. 해시 갱신은 검토 승인이나 안전성 검증을 대신하지 않습니다.
4. 아래 검사를 실행한 뒤 PR을 제출합니다.

```powershell
python tools/validate.py
python -m pip install lupa==2.8
python tools/check-lua.py
python -m unittest discover -s tests -v
```

기본 브랜치 보호가 적용되어야 일반 팀원의 직접 업로드를 서버에서 막을 수 있습니다. `.github/CODEOWNERS`와 자동 검사만으로 강제 차단되는 것은 아닙니다. 실제 보호 적용 결과는 `docs/repository-status.json`을 확인하세요. 현재 GitHub가 비공개 저장소의 브랜치 보호에 Pro 업그레이드를 요구해 서버 강제 차단은 적용되지 않았습니다. 팀원 초대는 아직 하지 않았습니다. 강제 보호가 필요한 공동 편집은 지원 플랜에서 보호 규칙을 적용한 뒤 시작하세요. 개인 계정의 비공개 저장소에 공동 작업자를 초대하면 쓰기 권한이 부여될 수 있으므로 단순 읽기 공유라고 간주하지 마세요. 소유자 권한은 배포 담당자에게만 둡니다.

## 애드온 추가 / 업데이트

현재 버전은 초기 관리 기반입니다. 신규 버전 감지·다운로드·3방향 병합·PR 자동 생성은 아직 구현하지 않았습니다.

추가/업데이트 담당자는 배포처와 Forever 호환성을 확인하고 원본을 먼저 확보합니다. 이전 원본 / 현재 팀 수정본 / 새 원본을 비교하여 번역·호환성 수정을 보존합니다. 원본이 미확인인 항목은 자동 병합하지 않습니다. 새 원본 및 파일 목록, 버전, 출처와 의존성을 등록하고 변경 이유를 기록합니다.

검사 통과 후 게임 내 동작을 확인한 커밋에 새 `pack-*` 태그를 발행합니다. CI 통과만으로 게임 호환성이 보증되지는 않습니다. 배포는 승인된 태그로 수행합니다.

기존 애드온과 포함 라이브러리의 저작권·라이선스는 원저작자에게 있습니다. 이 저장소에 추가한 관리 도구는 별도 고지 전까지 비공개 팀 내부 용도로 유지합니다.
