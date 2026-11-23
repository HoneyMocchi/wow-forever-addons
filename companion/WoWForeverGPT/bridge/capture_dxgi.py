"""WoW 픽셀 통신용 DirectX 수신기. 게임 신호 영역만 처리하고 화면 파일은 저장하지 않는다.

GDI CopyFromScreen에서 검게 읽히는 게임 렌더링 경로를 Desktop Duplication으로 대체한다.
출력 JSON 계약은 기존 capture.ps1과 같아 브리지/질문/대화 형식을 변경하지 않는다.
"""
import argparse,ctypes,json,sys,time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent/'capture-vendor'))
import numpy as np

def emit(value):
 print(json.dumps(value,ensure_ascii=False,separators=(',',':')),flush=True)

def decode(frame,cell=4,cells=200,rows=48):
 """순수 함수: 길이/체크섬 검증을 통과한 UTF-8 패킷만 반환한다."""
 h,w=frame.shape[:2]
 first=np.floor((np.arange(6)+.5)*cell).astype(int);y=int(.5*cell)
 if y>=h or first[-1]>=w:return None
 rgb=frame[y,first,:3]
 values=((rgb[:,0]>=128).astype(np.uint8)<<2)|((rgb[:,1]>=128).astype(np.uint8)<<1)|(rgb[:,2]>=128).astype(np.uint8)
 magic=0
 for value in values:magic=(magic<<3)|int(value)
 if magic>>2 != 0xC71A:return None
 # 프레임 크기를 넘는 칸은 읽지 않는다. 캡처 영역은 최대 패킷까지 담도록 잡는다.
 i=np.arange(cells*rows);xs=np.floor((i%cells+.5)*cell).astype(int);ys=np.floor((i//cells+.5)*cell).astype(int)
 if xs.max()>=w or ys.max()>=h:return {'error':'truncated'}
 rgb=frame[ys,xs,:3]
 values=((rgb[:,0]>=128).astype(np.uint8)<<2)|((rgb[:,1]>=128).astype(np.uint8)<<1)|(rgb[:,2]>=128).astype(np.uint8)
 bits=((values[:,None]>>np.array([2,1,0],dtype=np.uint8))&1).reshape(-1)
 data=np.packbits(bits).tobytes()
 length=int.from_bytes(data[4:6],'big')
 if length>3200 or length+8>len(data):return {'error':'length'}
 a=b=0
 for value in data[2:length+6]:a=(a+value)%255;b=(b+a)%255
 if data[length+6:length+8]!=bytes((a,b)):return {'error':'checksum'}
 try:text=data[6:length+6].decode('utf-8')
 except UnicodeDecodeError:return {'error':'utf8'}
 return {'id':int.from_bytes(data[2:4],'big'),'text':text}

class GameWindow:
 """게임 실행 파일 경로를 확인한 창만 선택한다. 다른 Wow 설치본은 제외한다."""
 def __init__(self,name,folder):
  from ctypes import wintypes as W
  self.W=W;self.name=name.lower().removesuffix('.exe')+'.exe';self.folder=folder.lower()
  self.u=ctypes.WinDLL('user32',use_last_error=True);self.k=ctypes.WinDLL('kernel32',use_last_error=True)
  self.callback=ctypes.WINFUNCTYPE(W.BOOL,W.HWND,W.LPARAM)
  self.u.EnumWindows.argtypes=[self.callback,W.LPARAM]
  self.u.GetWindowThreadProcessId.argtypes=[W.HWND,ctypes.POINTER(W.DWORD)]
  self.u.IsWindowVisible.argtypes=[W.HWND];self.u.IsIconic.argtypes=[W.HWND]
  self.u.ClientToScreen.argtypes=[W.HWND,ctypes.POINTER(W.POINT)]
  self.u.GetClientRect.argtypes=[W.HWND,ctypes.POINTER(W.RECT)]
  self.k.OpenProcess.argtypes=[W.DWORD,W.BOOL,W.DWORD];self.k.OpenProcess.restype=W.HANDLE
  self.k.QueryFullProcessImageNameW.argtypes=[W.HANDLE,W.DWORD,W.LPWSTR,ctypes.POINTER(W.DWORD)]
  self.k.CloseHandle.argtypes=[W.HANDLE]
  try:self.u.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
  except AttributeError:self.u.SetProcessDPIAware()
 def locate(self):
  found=[];W=self.W
  def visit(hwnd,_):
   if not self.u.IsWindowVisible(hwnd) or self.u.IsIconic(hwnd):return True
   rect=W.RECT();self.u.GetClientRect(hwnd,ctypes.byref(rect))
   if rect.right<400 or rect.bottom<300:return True
   pid=W.DWORD();self.u.GetWindowThreadProcessId(hwnd,ctypes.byref(pid))
   handle=self.k.OpenProcess(0x1000,False,pid.value)
   if not handle:return True
   try:
    size=W.DWORD(32768);buffer=ctypes.create_unicode_buffer(size.value)
    if not self.k.QueryFullProcessImageNameW(handle,0,buffer,ctypes.byref(size)):return True
    path=Path(buffer.value)
    if path.name.lower()!=self.name or (self.folder and path.parent.name.lower()!=self.folder):return True
    origin=W.POINT()
    if self.u.ClientToScreen(hwnd,ctypes.byref(origin)):found.append((pid.value,origin.x,origin.y,rect.right,rect.bottom))
   finally:self.k.CloseHandle(handle)
   return True
  self.u.EnumWindows(self.callback(visit),0)
  return found[0] if len(found)==1 else None

def main():
 p=argparse.ArgumentParser();p.add_argument('--cell',type=int,default=4);p.add_argument('--cells',type=int,default=200);p.add_argument('--max-rows',type=int,default=48);p.add_argument('--interval-ms',type=int,default=250);p.add_argument('--process-name',default='Wow');p.add_argument('--client-folder',default='');p.add_argument('--test-image',default='');args=p.parse_args()
 if args.test_image:
  from PIL import Image
  frame=np.asarray(Image.open(args.test_image).convert('RGB'))
  msg=decode(frame,args.cell,args.cells,args.max_rows)
  if not msg or 'error' in msg:
   for delta in range(1,int(args.cell*.1*512)+1):
    for pitch in (args.cell+delta/512,args.cell-delta/512):
     candidate=decode(frame,pitch,args.cells,args.max_rows)
     if candidate and 'error' not in candidate:msg=candidate;break
    if msg and 'error' not in msg:break
  emit(msg or {'error':'no valid strip in image'});return
 window=GameWindow(args.process_name,args.client_folder)
 import dxcam
 # DXcam 0.3.0의 출력 열거 정보를 사용해 게임이 위치한 모니터를 선택한다.
 # 화면 캡처는 잘라낸 신호 사각형만 반환한다. 여러 모니터에 걸치면 창 안쪽 영역만 읽는다.
 factory=getattr(dxcam,"__factory");camera=None;selected=None;last=None;pitch=float(args.cell);search_at=0;warn_at=0;last_window=None
 pulse_at=0
 try:
  while True:
   # 최소화하거나 픽셀 띠가 없어도 루프의 생존을 10초마다 알린다.
   # 실제 캡처 호출이 멈추면 이 신호도 멈추므로 부모가 수신기만 재시작할 수 있다.
   pulse_now=time.monotonic()
   if pulse_now-pulse_at>=10:emit({'pulse':True});pulse_at=pulse_now
   game=window.locate()
   if not game:time.sleep(1);continue
   pid,x,y,cw,ch=game;choice=None
   for di,outputs in enumerate(factory.outputs):
    for oi,output in enumerate(outputs):
     output.update_desc();r=output.desc.DesktopCoordinates
     if r.left<=x<r.right and r.top<=y<r.bottom:choice=(di,oi,r.left,r.top,r.right,r.bottom)
   if choice is None:time.sleep(1);continue
   if selected!=choice:
    if camera:camera.release()
    camera=dxcam.create(device_idx=choice[0],output_idx=choice[1],output_color='RGB',max_buffer_len=2,processor_backend='numpy')
    selected=choice;last_window=None
   if last_window!=(pid,selected):emit({'info':f'DirectX capture attached to {args.process_name} (pid {pid})'});last_window=(pid,selected)
   width=min(int(args.cells*args.cell*1.1)+1,cw,choice[4]-x);height=min(int(args.max_rows*args.cell*1.1)+1,ch,choice[5]-y)
   region=(x-choice[2],y-choice[3],x-choice[2]+width,y-choice[3]+height)
   frame=camera.grab(region=region,copy=False)
   if frame is not None:
    now=time.monotonic();msg=decode(frame,pitch,args.cells,args.max_rows)
    if (not msg or 'error' in msg) and now-search_at>=3:
     search_at=now
     for step in range(1,int(args.cell*.1*512)+1):
      for guess in (args.cell+step/512,args.cell-step/512):
       candidate=decode(frame,guess,args.cells,args.max_rows)
       if candidate and 'error' not in candidate:msg=candidate;pitch=guess;emit({'info':f'pixel pitch calibrated: {pitch}'});break
      if msg and 'error' not in msg:break
    if msg and 'id' in msg:
     key=(msg['id'],msg['text'])
     if key!=last:emit(msg);last=key
    elif msg and now-warn_at>=5:emit({'warn':'strip rejected: '+msg['error']});warn_at=now
   time.sleep(max(.05,args.interval_ms/1000))
 finally:
  if camera:camera.release()
if __name__=='__main__':main()
