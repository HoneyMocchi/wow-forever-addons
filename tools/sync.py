"""검증된 태그의 애드온만 설치한다. 기본 동작은 미리보기이며 --apply로 적용한다."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,tempfile,datetime
from validate import ROOT,LOCK,validate

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],text=True).strip()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--addons-path',required=True,type=Path)
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    target=args.addons_path.resolve()
    # 오타로 게임 전체나 다른 위치를 교체하지 못하도록 실제 AddOns 폴더만 허용한다.
    if target.name.lower()!='addons' or target.parent.name.lower()!='interface' or not target.is_dir():raise SystemExit('기존 Interface/AddOns 경로를 지정하세요.')
    validate()
    if git('status','--porcelain'):raise SystemExit('작업 사본에 변경이 있습니다. 배포 태그의 깨끗한 사본에서 실행하세요.')
    tags=[t for t in git('tag','--points-at','HEAD').splitlines() if t.startswith('pack-')]
    if len(tags)!=1:raise SystemExit('pack-* 배포 태그 한 개를 체크아웃해야 합니다.')
    # 로컬에서 임의로 붙인 태그를 배포본으로 오인하지 않도록 원격의 태그 객체도 대조한다.
    remote=git('ls-remote','--tags','origin','refs/tags/'+tags[0]).split()
    if not remote or remote[0]!=git('rev-parse','refs/tags/'+tags[0]):raise SystemExit('원격 배포 태그와 일치하지 않습니다.')
    if os.name=='nt':
        processes=subprocess.check_output(['tasklist','/FO','CSV','/NH'],text=True,errors='replace').lower()
        if any(line.startswith('"wow') and '.exe"' in line for line in processes.splitlines()):raise SystemExit('게임을 종료한 뒤 동기화하세요.')
    data=json.loads(LOCK.read_text(encoding='utf-8'))
    state_dir=ROOT/'.local'/hashlib.sha256(str(target).lower().encode()).hexdigest()[:16]
    state_file=state_dir/'installed.json'
    previous=json.loads(state_file.read_text(encoding='utf-8')) if state_file.exists() else {'addons':[]}
    old={a['id']:a for a in previous['addons']}
    changed=[]
    for addon in data['addons']:
        live=target/addon['id']; baseline=old.get(addon['id'],addon)['files']
        if live.is_symlink():raise SystemExit(addon['id']+': 링크된 폴더는 자동 교체하지 않습니다.')
        runtime=addon.get('runtime_inbox_template',False)
        # 이전 설치 기록이 없으면 현재 배포본과 일치하는 파일만 인수한다. 수동 설치본을 강제로 덮어쓰지 않는다.
        if live.exists():
            for p in live.rglob('*'):
                if p.is_symlink():raise SystemExit(addon['id']+': 내부 링크 발견')
                if not p.is_file():continue
                rel=p.relative_to(live).as_posix()
                if runtime and (rel=='Inbox.lua' or rel.split('/')[0] in {'ack','act','ctl','presence','sig'}):continue
                if rel not in baseline or digest(p)!=baseline[rel]:raise SystemExit(addon['id']+': 로컬 수정/미등록 파일 발견. 변경 내용을 먼저 보존하세요.')
        changed.append(addon)
    # 삭제된 애드온은 자동 제거하지 않는다. 개인 파일 삭제를 피하고 별도의 제거 검토 대상으로 남긴다.
    retired=set(old)-{a['id'] for a in data['addons']}
    print(f'{tags[0]}: {len(changed)}개 폴더 동기화; 목록 밖 개인 애드온 보존')
    if retired:print('자동 제거하지 않는 이전 관리 폴더: '+', '.join(sorted(retired)))
    if not args.apply:
        print('미리보기 완료. 실제 적용에는 --apply를 추가하세요.');return
    state_dir.mkdir(parents=True,exist_ok=True)
    stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    # 교체 전 모든 파일을 같은 드라이브의 임시 폴더에 완성한다. 이동은 폴더별이며, 전체 실패 시 역순으로 복원한다.
    stage=Path(tempfile.mkdtemp(prefix='.addonpack-stage-',dir=target.parent))
    backup=target.parent/('.addonpack-backup-'+stamp);backup.mkdir()
    completed=[]
    try:
        for addon in changed:
            name=addon['id'];src=ROOT/'addons'/name;dst=stage/name;live=target/name
            shutil.copytree(src,dst)
            if addon.get('runtime_inbox_template') and live.exists():
                # 각 PC의 기존 AI 대화/통신 자료는 그 PC에만 남긴다. 저장소의 빈 템플릿으로 초기화하지 않는다.
                for path in live.iterdir():
                    if path.name=='Inbox.lua':shutil.copy2(path,dst/path.name)
                    elif path.name in {'ack','act','ctl','presence','sig'} and path.is_dir():shutil.copytree(path,dst/path.name)
            for rel,expected in addon['files'].items():
                if addon.get('runtime_inbox_template') and rel=='Inbox.lua' and live.exists():continue
                if digest(dst/rel)!=expected:raise RuntimeError(name+': 스테이징 해시 불일치')
        for addon in changed:
            name=addon['id'];live=target/name;had=live.exists()
            if had:live.rename(backup/name)
            try:(stage/name).rename(live)
            except BaseException:
                if had:(backup/name).rename(live)
                raise
            completed.append((name,had))
        temp=state_dir/'installed.next.json';temp.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8');temp.replace(state_file)
    except BaseException:
        for name,had in reversed(completed):
            (target/name).rename(stage/name)
            if had:(backup/name).rename(target/name)
        raise
    # 백업 폴더를 자동 삭제하지 않는다. 게임 확인 후 사용자가 필요한 기간만 보관한다.
    print('동기화 완료. 교체 전 원본: '+str(backup))
if __name__=='__main__':main()
