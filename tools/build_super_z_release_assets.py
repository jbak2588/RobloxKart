"""Extract approved native Super Z static scene and compact official route data.
No Studio mutation, asset upload or publication. Keeps intrinsic native mesh data.
"""
from pathlib import Path
import copy,json,numpy as np,xml.etree.ElementTree as ET
R=Path(__file__).resolve().parents[1];O=R/'artifacts/super-z-release-20261107';O.mkdir(exist_ok=True)
source=R/'artifacts/super-z-track-local/KDM_Super_Z_Track_R1_Local.rbxlx'
r=ET.parse(source).getroot()
def name(i):return i.findtext("./Properties/string[@name='Name']",'')
scene=copy.deepcopy(next(x for x in r.iter('Item') if name(x)=='SuperZTrack'))
for x in scene.iter('Item'):assert x.get('class') not in ('Script','LocalScript','ModuleScript')
mat=copy.deepcopy(next(x for x in r.iter('Item') if x.get('class')=='MaterialVariant' and name(x)=='SuperZ_Park_Matte'))
out=ET.Element('roblox',{'version':'4'});folder=ET.SubElement(out,'Item',{'class':'Folder','referent':'SUPERZ_RESOURCES'})
props=ET.SubElement(folder,'Properties');ET.SubElement(props,'string',{'name':'Name'}).text='KDMSuperZResources'
folder.extend([scene,mat]);ss=r.find('SharedStrings')
if ss is not None:out.append(copy.deepcopy(ss))
for x in out.iter('Item'):
 p=x.find('Properties')
 if p is not None:
  for q in list(p):
   if q.tag in ('UniqueId','SecurityCapabilities') or q.get('name') in ('HistoryId','SourceAssetId','ScriptGuid'):p.remove(q)
ET.indent(out);ET.ElementTree(out).write(R/'src/assets/KDMSuperZResources.rbxmx',encoding='utf-8',xml_declaration=False)
d=json.loads((R/'artifacts/super-z-track-local/geometry.json').read_text());p=d['points']
st=np.array([v['s'] for v in p]);pts=np.array([[v['x'],v['z']] for v in p]);hs=np.array([v['half'] for v in p]);L=d['measuredPolylineLength']
# Original station0 is the LEFT end of the top straight; finish is its midpoint.
start=next(v['length'] for v in json.loads((R/'artifacts/super-z-track-plan/geometry_summary.json').read_text())['segments'] if v['type']=='STRAIGHT')/2
stations=(start+np.arange(600)*L/600)%L
xp=np.r_[st,L];pos=np.vstack([pts,pts[0]]);hp=np.r_[hs,hs[0]]
route=np.column_stack([np.interp(stations,xp,pos[:,k]) for k in (0,1)])
width=np.interp(stations,xp,hp)
road_route=route.copy()
# The old circle poles lie inside the expanded asphalt. A nearest projection
# against that old path jumps between its arc endpoints on legitimate inner
# lines. Offset the NEW inner boundaries into the road for the race reference.
# This changes route analysis only; all native asphalt/outer edges stay fixed.
def bez(a,b,c,d,count=160):
 u=np.linspace(0,1,count)[:,None];return (1-u)**3*a+3*(1-u)**2*u*b+3*(1-u)*u*u*c+u**3*d
t=np.array([[v['fx'],v['fz']] for v in p]);normal=np.column_stack([-t[:,1],t[:,0]])
half=np.array([v['half'] for v in p]);adjusted=pts.copy();probes={}
for label,lo,hi,side in [('central',1166,1484,-1),('bowl',1729,2435,1)]:
 i=int(np.argmin(abs(st-lo)));j=int(np.argmin(abs(st-hi)));edge=pts+normal*half[:,None]*side;a,b=edge[i],edge[j]
 if label=='central':new=bez(a,a+t[i]*50,b-t[j]*50,b)
 else:
  u=np.linspace(-np.pi/2,np.pi/2,180);arc=np.column_stack([474.5925+65*np.cos(u),486.0571+65*np.sin(u)])
  new=np.vstack([bez(a,a+t[i]*35,arc[0]-[30,0],arc[0],60),arc[1:],bez(arc[-1],arc[-1]+[-30,0],b-t[j]*35,b,60)[1:]])
 dist=np.r_[0,np.cumsum(np.linalg.norm(np.diff(new,axis=0),axis=1))];target=(st[i:j+1]-st[i])/(st[j]-st[i])*dist[-1]
 q=np.column_stack([np.interp(target,dist,new[:,k]) for k in (0,1)])
 before=np.column_stack([np.interp(np.maximum(0,target-.02),dist,new[:,k]) for k in (0,1)]);after=np.column_stack([np.interp(np.minimum(dist[-1],target+.02),dist,new[:,k]) for k in (0,1)])
 tangent=after-before;tangent/=np.linalg.norm(tangent,axis=1)[:,None];n=np.column_stack([-tangent[:,1],tangent[:,0]])
 adjusted[i:j+1]=q-n*half[i:j+1,None]*side
 inside=pts.copy();inside[i:j+1]=q-n*7*side
 outside=pts.copy();outside[i:j+1]=pts[i:j+1]-normal[i:j+1]*(half[i:j+1,None]-7)*side
 probes[label+'_inner']=inside;probes[label+'_outer']=outside
adjusted=np.vstack([adjusted,adjusted[0]]);newcum=np.r_[0,np.cumsum(np.linalg.norm(np.diff(adjusted,axis=0),axis=1))];newlen=newcum[-1]
startnew=np.interp(start,xp,newcum);newstations=(startnew+np.arange(600)*newlen/600)%newlen
route=np.column_stack([np.interp(newstations,newcum,adjusted[:,k]) for k in (0,1)])
checkpoints=[(np.interp(v,xp,newcum)-startnew)%newlen/newlen for v in [880,1160,1640,1840,2500,2900,3200,3600,4100,4700,5250,5700]]
definition="\n-- Super Z: owner-approved native R1 + two inner asphalt additions (2026-11-07).\nTrackGeometry.Definitions.SuperZV1 = {\n RoadWidth=60, RouteCorridorWidth=100, SampleSpacing=10,\n CheckpointFractions={"+','.join(f'{v:.10f}' for v in checkpoints)+"},\n Samples={\n"+'\n'.join(f'  Vector3.new({x:.6f},0,{z:.6f}),' for x,z in route)+"\n },\n RoadSamples={\n"+'\n'.join(f'  Vector3.new({x:.6f},0,{z:.6f}),' for x,z in road_route)+"\n },\n HalfWidths={"+','.join(f'{h:.5f}' for h in width)+"},\n}\n"
(O/'definition_insert.luau').write_text(definition)
adds=json.loads((R/'artifacts/super-z-track-local/corner-fill-20261107/road_additions.json').read_text())
# Preserve the author's polygons, but remove duplicate/collinear points to bound runtime work.
from shapely.geometry import Polygon
adds=[list(Polygon(q).simplify(.03,preserve_topology=True).exterior.coords) for q in adds]
literal='{'+','.join('{'+','.join('{'+f'{x:.6f},{z:.6f}'+'}' for x,z in q)+'}' for q in adds)+'}'
(O/'additions_insert.luau').write_text('local additions='+literal+'\n')
(O/'route.json').write_text(json.dumps({'points':route.tolist(),'halfWidths':width.tolist(),'length':L,'startStation':start,'additions':adds}))
(O/'line_probes.json').write_text(json.dumps({key:value.tolist() for key,value in probes.items()}))
fixture={'base':np.round(pts,6).tolist(),'variants':{}}
for key,value in probes.items():
 changed=np.flatnonzero(np.any(value!=pts,axis=1));i,j=int(changed[0]),int(changed[-1])
 fixture['variants'][key]={'first':i+1,'points':np.round(value[i:j+1],6).tolist()}
(R/'tests/fixtures/super_z_line_probes_20261107.json').write_text(json.dumps(fixture,separators=(',',':'))+'\n')
print('Revised reference polyline length:',newlen)
print('Extracted inert native scene,600 route samples,2 added-road polygons:',[len(q) for q in adds])
