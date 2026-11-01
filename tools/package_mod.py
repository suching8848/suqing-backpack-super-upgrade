"""Create an installable ZIP from checked-in sources; never installs or contacts Steam."""
from pathlib import Path
import argparse, json, zipfile
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 record=json.loads((ROOT/'docs/runtime-sha256.json').read_text(encoding='utf-8'))
 destination=a.output.expanduser().resolve()
 if destination.exists():raise SystemExit('Output already exists; choose a new filename.')
 source=ROOT/'mods'/record['mod_id']
 destination.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(destination,'x',compression=zipfile.ZIP_DEFLATED) as z:
  for path in sorted(source.rglob('*')):
   if path.is_file():z.write(path,record['mod_id']+'/'+path.relative_to(source).as_posix())
 print('Created '+str(destination))
if __name__=='__main__':main()
