from pathlib import Path
import json,hashlib,struct,zstandard
root=Path.cwd();scope={}
exec((root/'artifacts/r8-a3b/native-binary-audit.py').read_text().split('before,beforeOther=')[0],scope)
a=root/'artifacts/lobby-vfx-audio-integration/KDM_PUBLISHED_PV655_VERIFIED.rbxl'
b=root/'artifacts/race-presentation-checkpoints/KDM_RACE_PRESENTATION_NATIVE_CANDIDATE.rbxl'
ap,ao=scope['inspect'](a);bp,bo=scope['inspect'](b)
t={k:v for k,v in ap.items() if k.startswith('Terrain/')}
assert t and all(bp.get(k)==v for k,v in t.items() if k!='Terrain/Materials')
def materials(path):
 data=path.read_bytes();i=32;classes={};strings=[];target=None
 while i<len(data):
  tag,c,n,_=struct.unpack_from('<4sIII',data,i);i+=16
  raw=data[i:i+(c or n)];i+=c or n
  block=(zstandard.ZstdDecompressor().decompress(raw,max_output_size=n) if raw[:4]==bytes.fromhex('28b52ffd') else scope['lz4'](raw,n)) if c else raw
  if tag==b'INST':
   cid,l=struct.unpack_from('<II',block);classes[cid]=block[8:8+l].decode()
  if tag==b'SSTR':
   _,count=struct.unpack_from('<II',block);j=8
   for _ in range(count):
    j+=16;l=struct.unpack_from('<I',block,j)[0];j+=4;strings.append(block[j:j+l]);j+=l
  if tag==b'PROP':
   cid,l=struct.unpack_from('<II',block);name=block[8:8+l].decode()
   if classes[cid]=='Terrain' and name=='Materials':target=block[8+l:]
 assert target and len(target)==5 and target[0]==28
 return strings[int.from_bytes(target[1:],'big')]
assert materials(a)==materials(b),'actual Terrain material content changed'
result={'status':'PASS','terrainGroups':len(t),'baselineSha256':hashlib.sha256(a.read_bytes()).hexdigest(),'candidateSha256':hashlib.sha256(b.read_bytes()).hexdigest(),'candidateBytes':b.stat().st_size,'method':'raw binary read-only; Studio native Save As, no Lune reserialize'}
result['materials']='identical 323 content bytes; SharedString index relocated by new assets'
(root/'artifacts/race-presentation-checkpoints/native-terrain.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result))
