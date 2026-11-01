"""Read-only source checks and optional installed-game Kahlua/native-parser tests."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--game-dir',type=Path);p.add_argument('--javac',default='javac');p.add_argument('--java');a=p.parse_args()
 record=json.loads((ROOT/'docs/runtime-sha256.json').read_text(encoding='utf-8'));source=ROOT/'mods'/record['mod_id']
 current={f.relative_to(source).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(source.rglob('*')) if f.is_file()}
 assert current==record['files'],'Package differs from the preserved source snapshot.'
 info=dict(line.split('=',1) for line in (source/'42/mod.info').read_text(encoding='utf-8-sig').splitlines() if '=' in line)
 assert info['id']==record['mod_id'] and info['modversion']==record['version']
 for f in source.rglob('*.json'):json.loads(f.read_text(encoding='utf-8-sig'))
 print('STATIC PASS: '+str(len(current))+' package files, identity/version/JSON/hash checks.')
 if not a.game_dir:return
 game=a.game_dir.expanduser().resolve();jar=game/'projectzomboid.jar';assert jar.is_file()
 java=a.java or str(game/'jre64/bin'/('java.exe' if os.name=='nt' else 'java'))
 if not Path(java).is_file():java=shutil.which('java') or java
 tests=ROOT/'tests';lua=source/'42/media/lua';stdlib=game/'stdlib.lua';assert stdlib.is_file(),'Point to a game installation containing stdlib.lua.'
 with tempfile.TemporaryDirectory(prefix='suqing-offline-') as temporary:
  work=Path(temporary);native='NativeRecipeAudit' if record['mod_id'].startswith('Ex') else 'NativeAutoAudit'
  subprocess.run([a.javac,'-encoding','UTF-8','-d',str(work),str(tests/'KahluaValidation.java'),str(tests/(native+'.java'))],check=True)
  cp=str(jar)+os.pathsep+str(work);base=[java,'-Duser.home='+str(work/'home'),'-cp',cp]
  compile_file=work/'compile.lua'
  compile_file.write_text('\n'.join('assert(loadstring('+json.dumps(f.read_text(encoding='utf-8-sig'),ensure_ascii=False)+','+json.dumps(f.name)+'))' for f in sorted(lua.rglob('*.lua')))+'\nreturn "all runtime Lua compiled"\n',encoding='utf-8')
  subprocess.run(base+['KahluaValidation',str(compile_file)],check=True)
  if record['mod_id'].startswith('Ex'):
   shared=lua/'shared/ExSuQingBackpackSuperUpgrade'
   common=[stdlib,tests/'fixture.lua',shared/'Core.lua',shared/'Capacity.lua',shared/'Refund.lua']
   suites=[common+[tests/'core_capacity_tests.lua'],common+[lua/'client/ExSuQingBackpackSuperUpgrade_Crafting.lua',tests/'crafting_tests.lua']]
   recipe=source/'42/media/scripts/ExSuQingBackpackSuperUpgrade.txt'
  else:
   shared=lua/'shared/SuQingContainerUpgradeAuto'
   suites=[[stdlib,tests/'engine_fixture.lua',shared/'Compatibility.lua',shared/'AutoPolicy.lua',shared/'Core.lua',shared/'Refund.lua',shared/'Auto.lua',lua/'client/SuQingContainerUpgradeAuto_Crafting.lua',tests/'auto_fixture.lua',tests/'auto_tests.lua']]
   recipe=source/'42/media/scripts/SuQingContainerUpgradeAuto.txt'
  for suite in suites:subprocess.run(base+['KahluaValidation']+[str(f) for f in suite],check=True)
  subprocess.run(base+[native,str(recipe)],check=True)
 print('OFFLINE PASS. Controlled fixtures/native parser do not establish in-game acceptance.')
if __name__=='__main__':main()
