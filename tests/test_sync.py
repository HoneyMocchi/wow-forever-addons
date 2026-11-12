"""실제 게임 폴더를 사용하지 않고 임시 디렉터리에서 동기화 보호 동작을 확인한다."""
import importlib.util,json,sys,tempfile,unittest,hashlib
from pathlib import Path
from unittest.mock import patch
TOOLS=Path(__file__).resolve().parents[1]/'tools';sys.path.insert(0,str(TOOLS))
spec=importlib.util.spec_from_file_location('pack_sync',TOOLS/'sync.py');sync=importlib.util.module_from_spec(spec);spec.loader.exec_module(sync)
class SyncTests(unittest.TestCase):
 def setUp(self):
  scratch=TOOLS.parent/'.local/test-tmp';scratch.mkdir(parents=True,exist_ok=True)
  self.tmp=tempfile.TemporaryDirectory(dir=scratch)
  assert Path(self.tmp.name).resolve().is_relative_to(scratch.resolve())
  self.addCleanup(self.tmp.cleanup)
  self.root=Path(self.tmp.name)/'repo';self.target=Path(self.tmp.name)/'game/Interface/AddOns';self.target.mkdir(parents=True)
  self.root.mkdir();(self.root/'manifests').mkdir()
 def addon(self,name,text='new',runtime=False):
  folder=self.root/'addons'/name;folder.mkdir(parents=True)
  (folder/'main.lua').write_text(text)
  if runtime:(folder/'Inbox.lua').write_text('empty')
  files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.iterdir()}
  return {'id':name,'files':files,'runtime_inbox_template':runtime}
 def run_sync(self,addons,apply=True):
  lock=self.root/'manifests/addons.lock.json';lock.write_text(json.dumps({'addons':addons}))
  def git(*args):
   if args[0]=='status':return ''
   if args[0]=='tag':return 'pack-test'
   if args[0]=='ls-remote':return 'abc refs/tags/pack-test'
   return 'abc'
  argv=['sync.py','--addons-path',str(self.target)]+(['--apply'] if apply else [])
  with patch.object(sync,'ROOT',self.root),patch.object(sync,'LOCK',lock),patch.object(sync,'validate'),patch.object(sync,'git',git),patch.object(sync.subprocess,'check_output',return_value=''),patch.object(sys,'argv',argv):sync.main()
 def test_preview_does_not_install(self):
  self.run_sync([self.addon('A')],False);self.assertFalse((self.target/'A').exists())
 def test_local_edit_refuses_write(self):
  addon=self.addon('A');live=self.target/'A';live.mkdir();(live/'main.lua').write_text('local edit')
  with self.assertRaises(SystemExit):self.run_sync([addon])
  self.assertEqual((live/'main.lua').read_text(),'local edit')
 def test_preserves_personal_addon_and_runtime(self):
  addon=self.addon('WoWForeverGPT',runtime=True);live=self.target/'WoWForeverGPT';live.mkdir();(live/'main.lua').write_text('new');(live/'Inbox.lua').write_text('personal reply')
  (live/'ack').mkdir();(live/'ack/1').write_text('ack')
  personal=self.target/'Personal';personal.mkdir();(personal/'mine').write_text('keep')
  self.run_sync([addon]);self.assertEqual((live/'Inbox.lua').read_text(),'personal reply');self.assertEqual((live/'ack/1').read_text(),'ack');self.assertTrue((personal/'mine').exists())
 def test_second_folder_failure_restores_first(self):
  addons=[self.addon('A'),self.addon('B')]
  for a in addons:
   live=self.target/a['id'];live.mkdir();(live/'main.lua').write_text('new')
  original=Path.rename
  def rename(path,destination):
   if path.name=='B' and path.parent.name.startswith('.addonpack-stage-'):raise OSError('injected second-folder failure')
   return original(path,destination)
  with patch.object(Path,'rename',rename),self.assertRaises(OSError):self.run_sync(addons)
  self.assertEqual((self.target/'A/main.lua').read_text(),'new');self.assertEqual((self.target/'B/main.lua').read_text(),'new')
if __name__=='__main__':unittest.main()
