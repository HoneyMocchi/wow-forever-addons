"""Lua 5.1 파싱만 수행하며 게임 함수나 애드온 코드는 실행하지 않는다."""
from pathlib import Path
import sys
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
parse=lua.eval('function(s,n) local f,e=loadstring(s,n); return f~=nil,e end')
count=0;errors=[]
for p in (ROOT/'addons').rglob('*.lua'):
    count+=1
    try:
        ok,error=parse(p.read_text(encoding='utf-8-sig'),p.relative_to(ROOT).as_posix())
        if not ok:errors.append(str(error))
    except (UnicodeError,ValueError) as error:errors.append(str(p.relative_to(ROOT))+': '+type(error).__name__)
if errors:raise SystemExit('\n'.join(errors))
print(f'PASS: Lua 5.1 문법 {count}개 파일')
