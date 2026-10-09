"""Portable checkpoint validation entry point. Run from any full Git clone."""
from pathlib import Path
import hashlib,json,subprocess,sys
root=Path(__file__).resolve().parents[2]
folder=Path(__file__).resolve().parent
manifest=json.loads((folder/'source-manifest.json').read_text())['files']
for row in manifest:
 actual=hashlib.sha256((root/row['file']).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
 if actual!=row['lfSha256']:raise SystemExit('Source differs from validated checkpoint: '+row['file'])
plan=json.loads((folder/'regression-evidence.json').read_text())['rows']
if '--list' in sys.argv:
 print(json.dumps([r['command'] for r in plan],indent=2));sys.exit(0)
for row in plan:
 print(row['label'],flush=True)
 run=subprocess.run(row['command'],cwd=root)
 if run.returncode:sys.exit(run.returncode)
print('PASS: all 109 checkpoint commands')
