"""Compare the shipped inert resource palette against the original city place."""
from pathlib import Path
import hashlib
import xml.etree.ElementTree as ET
source=Path('C:/dev/rbxlx_data/city.rbxlx')
assert hashlib.sha256(source.read_bytes()).hexdigest()=='da91339e3c6a5f5159c7cb471d3f9473aa03c13d241655283605045144ea5ff5'
original=ET.parse(source).getroot()
asset=ET.parse('src/assets/KDMMetroResources.rbxmx').getroot().find('Item')
def name(n):return n.findtext("Properties/string[@name='Name']")
def child(n,key):return next(v for v in n.findall('Item') if name(v)==key)
def props(n):return {p.get('name'):(p.tag,''.join(''.join(p.itertext()).split())) for p in n.find('Properties')}
allowed={'Folder','Model','MeshPart','Part','WedgePart','SurfaceAppearance','Texture','Decal','Sky','Atmosphere','ColorCorrectionEffect','MaterialVariant'}
for n in asset.iter('Item'):assert n.get('class') in allowed,n.get('class')
lighting=child(original,'Lighting')
for item in child(asset,'Lighting').findall('Item'):
 old=next(n for n in lighting.findall('Item') if n.get('class')==item.get('class') and name(n)==name(item))
 before=props(old)
 for key,value in props(item).items():assert before[key]==value,(item.get('class'),key)
material=child(original,'MaterialService')
for item in child(asset,'Materials').findall('Item'):
 if name(item)=='Metro_Racing_Asphalt_Matte':
  desert=ET.parse('src/assets/KDMDesertResources.rbxmx').getroot()
  before=props(next(n for n in desert.iter('Item') if name(n)=='Racing_Asphalt_A'))
  for key,value in props(item).items():
   if key=='Name':continue
   if key=='NormalMap':assert value==('Content','');continue
   assert before[key]==value,(name(item),key)
  continue
 before=props(child(material,name(item)))
 for key,value in props(item).items():assert before[key]==value,(name(item),key)
mesh_ids={n.findtext("Properties/Content[@name='MeshId']/url") for n in original.iter('Item') if n.get('class')=='MeshPart'}
intrinsic_sizes={}
for n in original.iter('Item'):
 if n.get('class')!='MeshPart':continue
 mesh=n.findtext("Properties/Content[@name='MeshId']/url")
 size=n.find("Properties/Vector3[@name='InitialSize']")
 if size is not None:
  intrinsic_sizes.setdefault(mesh,set()).add(tuple(float(size.findtext(k)) for k in ('X','Y','Z')))
parts=0
meshes=0
for n in asset.iter('Item'):
 if n.get('class') not in ('MeshPart','Part','WedgePart'):continue
 parts+=1
 if n.get('class')=='MeshPart':
  mesh=n.findtext("Properties/Content[@name='MeshId']/url")
  assert mesh in mesh_ids
  size=n.find("Properties/Vector3[@name='InitialSize']")
  assert size is not None,('missing serialized intrinsic mesh size',name(n))
  values=tuple(float(size.findtext(k)) for k in ('X','Y','Z'))
  assert min(values)>0,('invalid intrinsic mesh size',name(n))
  assert values in intrinsic_sizes[mesh],('intrinsic size differs from original city',name(n))
  meshes+=1
 p=props(n)
 for k,v in {'Anchored':'true','CanCollide':'false','CanTouch':'false','CanQuery':'false','CastShadow':'false'}.items():assert p[k]==('bool',v)
assert parts==2536
assert meshes==2248
print('PASS: original city hash, original lighting/materials, all2248 original intrinsic mesh sizes and identities, inert2536-part palette')
