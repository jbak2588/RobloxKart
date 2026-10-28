"""R2 isolated HEAD/candidate comparison. Does not modify either game tree."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('state',type=Path,help='External temporary-worktree state JSON')
parser.add_argument('--resume',action='store_true',help='Reuse completed pairs after checking preservation and tool/HEAD identity')
args=parser.parse_args()
state=json.loads(args.state.read_text())
root,baseline,out=map(Path,(state['original'],state['baseline'],state['output']))
out.mkdir(parents=True,exist_ok=True)
def git(cwd,*args):
    return subprocess.check_output(['git',*args],cwd=cwd,text=True).strip()
assert git(root,'rev-parse','HEAD')==state['head']==git(baseline,'rev-parse','HEAD')
assert not git(baseline,'status','--porcelain'), 'Baseline must be pristine'
assert root.resolve()!=baseline.resolve()
prior=json.loads((root/'docs/testing/source_freeze_r1_validation_20261028.json').read_text(encoding='utf-8'))
failures=[row['test'] for row in prior['failureDetails']]
assert len(failures)==75 and len(set(failures))==75
core=[name+'_validation.luau' for name in (
 'gas_pedal','mobile_touch','mobile_controls_v1','mobile_reverse_transition',
 'speed_sensation_camera','speed_world_vfx','camera_motion','impact_camera',
 'r8_d4_camera','r8_d4_restore_camera','race_network_ownership','race_item',
 'lobby_practice_combat','shield_restore','slick','smoke_effect_view',
 'six_item_race_ui','race_loadout_slots','item_world_vfx','finish_sequence',
 'finish_presentation','invited_public_start','public_race_controller',
 'rematch_reward','kart_audio','race_audio','boost_audio','reserved_match')]
tests=sorted(set(failures+core))
lune=shutil.which('lune')
assert lune
env=os.environ.copy()
metadata={'lunePath':lune,'luneVersion':subprocess.check_output([lune,'--version'],text=True).strip(),
 'rojoPath':shutil.which('rojo'),'pythonVersion':os.sys.version,
 'baseline':str(baseline),'candidate':str(root),'head':state['head'],
 'sameEnvironment':True,'priorFailedTests':failures,'coreTests':core}
results=[]
completed={}
if args.resume:
    previous=json.loads((out/'comparison.json').read_text())
    for key in ('lunePath','luneVersion','head','baseline','candidate'):
        assert previous['metadata'][key]==metadata[key],key
    for path,expected in state['preserved'].items():
        assert hashlib.sha256((root/path).read_bytes()).hexdigest()==expected,path
    completed={r['test']:r for r in previous['results']}
for test in tests:
    row={'test':test,'priorFailure':test in failures,'core':test in core}
    assert (root/'tests'/test).exists() and (baseline/'tests'/test).exists(),test
    if test in completed:
        row.update({key:completed[test][key] for key in ('baseline','candidate','comparison')})
        results.append(row)
        continue
    for label,cwd in [('baseline',baseline),('candidate',root)]:
        start=time.monotonic()
        try:
            run=subprocess.run([lune,'run','tests/'+test],cwd=cwd,env=env,capture_output=True,timeout=120)
            log=run.stdout.decode('utf-8',errors='replace')+run.stderr.decode('utf-8',errors='replace')
            code=run.returncode
        except subprocess.TimeoutExpired:
            code,log=124,'TIMEOUT after120 seconds'
        (out/label).mkdir(exist_ok=True)
        (out/label/(Path(test).stem+'.log')).write_text(log,encoding='utf-8')
        lines=[line for line in log.split('[Stack Begin]')[0].splitlines() if line.strip()]
        row[label]={'code':code,'seconds':round(time.monotonic()-start,3),
                    'observedFailure':lines[-1] if code and lines else None}
    row['comparison']=('EXISTING_FAILURE' if row['baseline']['code'] and row['candidate']['code']
                       else 'NEW_FAILURE' if row['candidate']['code']
                       else 'RESOLVED_FAILURE' if row['baseline']['code'] else 'BOTH_PASS')
    results.append(row)
    (out/'comparison.json').write_text(json.dumps({'metadata':metadata,'results':results},indent=2),encoding='utf-8')
    print(f"{row['comparison']} {test} HEAD={row['baseline']['code']} FOV={row['candidate']['code']}",flush=True)
assert not git(baseline,'status','--porcelain'), 'Baseline was modified by a test'
for path,expected in state['preserved'].items():
    assert hashlib.sha256((root/path).read_bytes()).hexdigest()==expected,'Existing local work changed: '+path
print(json.dumps({'tests':len(results),'preservation':'PASS','pristineBaseline':'PASS',
 'counts':{key:sum(r['comparison']==key for r in results) for key in
 ('EXISTING_FAILURE','NEW_FAILURE','RESOLVED_FAILURE','BOTH_PASS')}}),flush=True)
