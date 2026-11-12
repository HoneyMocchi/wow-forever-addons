"""팀 배포본의 무결성과 번역 관련 오류를 검사한다. 게임 API를 실행하지 않는다."""
from pathlib import Path
import argparse, hashlib, json, re, sys
ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / 'manifests/addons.lock.json'
# 패턴에 맞는 값은 출력하지 않는다. 검사 결과에는 파일명과 종류만 남긴다.
SECRET = re.compile(rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|sk-(?:proj-)?[A-Za-z0-9_-]{32,}|-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----)')

def inventory(folder):
    return {p.relative_to(folder).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(folder.rglob('*')) if p.is_file()}

def validate():
    data = json.loads(LOCK.read_text(encoding='utf-8'))
    errors = []
    expected = {a['id'] for a in data['addons']}
    actual = {p.name for p in (ROOT/'addons').iterdir() if p.is_dir()}
    if expected != actual: errors.append('등록되지 않았거나 사라진 애드온 폴더가 있습니다.')
    for addon in data['addons']:
        folder = ROOT/'addons'/addon['id']
        if inventory(folder) != addon['files']: errors.append(addon['id']+': 파일 목록/해시 불일치. 변경 검토 후 lock 갱신이 필요합니다.')
        if not list(folder.glob('*.toc')): errors.append(addon['id']+': TOC 누락')
    # .git과 로컬 백업은 검사 대상에서 제외한다. 계정 설정이나 로그는 배포 디렉터리에 들어갈 수 없다.
    for parent in ['addons','upstream']:
        for p in (ROOT/parent).rglob('*'):
            if p.is_symlink(): errors.append(str(p.relative_to(ROOT))+': 심볼릭 링크 금지')
            if not p.is_file(): continue
            rel = p.relative_to(ROOT)
            if p.stat().st_size >= 95*1024*1024: errors.append(str(rel)+': Git 파일 크기 제한 초과')
            if p.suffix.lower() in {'.log','.sqlite','.db','.env'} or any(part in {'WTF','SavedVariables','ack','act','ctl','presence','sig'} for part in rel.parts): errors.append(str(rel)+': 런타임/개인 설정 파일 금지')
            if p.suffix.lower() in {'.lua','.toc','.json','.xml','.py','.js','.ini','.txt'} and SECRET.search(p.read_bytes()): errors.append(str(rel)+': 인증 정보 의심 패턴')
    # 대화 수신 파일은 모든 배포본에서 비어 있어야 한다. 실제 답변은 각 PC 브리지가 채운다.
    for folder in (ROOT/'addons').glob('WoWForeverGPT*'):
        inbox = folder/'Inbox.lua'
        value = 'WoWForeverGPT_Inbox' if folder.name=='WoWForeverGPT' else 'WoWForeverGPT_SlotData'
        expected_text = '-- Empty distribution template; populated locally by the AI bridge.\n'+value+' = {}\n'
        if inbox.read_text(encoding='utf-8') != expected_text: errors.append(folder.name+': AI 대화 수신 파일이 비어 있지 않습니다.')
    if errors: raise SystemExit('\n'.join(errors))
    print(f"PASS: {len(expected)}개 폴더, 파일 해시·비밀정보 패턴·빈 AI 슬롯 검사")

if __name__ == '__main__':
    validate()
