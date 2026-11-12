"""검토용으로 애드온 파일 해시를 갱신한다. 검사를 통과시키는 승인 도구가 아니다."""
from pathlib import Path
import json,sys
from validate import ROOT,LOCK,inventory
# 추가/제거는 원본 출처, 의존성, 버전을 검토한 다음 manifest 항목을 먼저 등록해야 한다.
data=json.loads(LOCK.read_text(encoding='utf-8'))
expected={a['id'] for a in data['addons']}
actual={p.name for p in (ROOT/'addons').iterdir() if p.is_dir()}
if expected != actual: raise SystemExit('애드온 추가/제거는 manifest 항목과 원본 출처 검토가 먼저 필요합니다.')
for addon in data['addons']:addon['files']=inventory(ROOT/'addons'/addon['id'])
LOCK.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('파일 해시를 갱신했습니다. PR에서 코드와 lock 변경을 함께 검토하세요.')
