from pathlib import Path
import copy,xml.etree.ElementTree as E,json,hashlib
source=Path(r'C:\Users\OWNER\Downloads\Engine_sound_N_Nitro_vfx.rbxlx')
root=E.parse(source).getroot()
def name(o):
 p=o.find("Properties/*[@name='Name']");return p.text if p is not None else ''
def folder(n):
 o=E.Element('Item',{'class':'Folder','referent':n});p=E.SubElement(o,'Properties');E.SubElement(p,'string',{'name':'Name'}).text=n;return o
assets=folder('KDMRacePresentationResources')
for n in ['CheckpointFlag','FinishFlag','CheckpointFrame','StartPlayer','TickPlayer']:
 item=copy.deepcopy(next(o for o in root.iter('Item') if name(o)==n))
 # Audio output is wired by KDM; no external bus or scripted race manager.
 for o in list(item.iter('Item')):
  for c in list(o.findall('Item')):
   if c.get('class') in ['Wire','Script','LocalScript','ModuleScript']:o.remove(c)
 assets.append(item)
refs={o.get('referent') for o in assets.iter('Item')}
for o in assets.iter('Item'):
 assert o.get('class') not in ['Script','LocalScript','ModuleScript','RemoteEvent','RemoteFunction','VehicleSeat']
 for ref in o.findall('Properties/Ref'):
  if ref.text not in refs:ref.text='null'
doc=E.Element('roblox',{'version':'4'});doc.append(assets)
needed={s.text for s in assets.iter('SharedString')};strings=E.SubElement(doc,'SharedStrings')
for o in root.findall('SharedStrings/SharedString'):
 if o.get('md5') in needed:strings.append(copy.deepcopy(o))
target=Path('src/assets/KDMRacePresentationResources.rbxmx')
E.ElementTree(doc).write(target,encoding='utf-8',xml_declaration=False)
report={'source':str(source),'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'assetSha256':hashlib.sha256(target.read_bytes()).hexdigest(),'entries':len(list(assets.iter('Item'))),'safeAssets':['CheckpointFlag','FinishFlag','CheckpointFrame','StartPlayer','TickPlayer'],'scripts':0}
Path('artifacts/race-presentation-checkpoints/extraction.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
