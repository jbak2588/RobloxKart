local fs,rb,luau,serde=require('@lune/fs'),require('@lune/roblox'),require('@lune/luau'),require('@lune/serde')
local V=rb.Vector3
local e={Vector3=V,Vector2=rb.Vector2,CFrame=rb.CFrame,Color3=rb.Color3}
local G=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment=e})()
local S=luau.load(fs.readFile('src/shared/TrackSurfaceStandard.luau'),{environment=e})()
local C=luau.load(fs.readFile('src/shared/TrackCatalog.luau'),{environment=e})()
local assets=rb.deserializeModel(fs.readFile('src/assets/KDMRoadMaterials.rbxmx'))[1]
local meta=serde.decode('json',fs.readFile('src/assets/OfficialContinuousAsphaltGeometry.json'))
local n=0;local function check(v,m)assert(v,m);n+=1 end
local sources={};local available=true
for geometry,d in meta do
 local native=assert(assets:FindFirstChild(geometry..'ContinuousAsphalt'))
 check(native.Size.X>0 and native.Size.Y>0 and native.Size.Z>0,'positive intrinsic dimensions')
 check(not native.CanCollide and not native.CanQuery and not native.CanTouch,'inert asset')
 check(native.RenderFidelity==rb.Enum.RenderFidelity.Precise,'no distance geometry simplification')
 local p={MeshId='rbxassetid://'..({PracticeFigure8V1=96125611983857,PracticeCircuitV1=84772715021686,HardCircuitV1=74812628911192})[geometry],MeshSize=native.Size,Size=native.Size,CFrame=native.CFrame}
 function p:IsA(c)return c=='MeshPart'end
 function p:Clone()return table.clone(self)end
 sources[geometry..'ContinuousAsphalt']=p
 local vertices,uvs,faces={},{},{}
 for line in fs.readFile('src/assets/'..geometry..'ContinuousAsphalt.obj'):gmatch('[^\r\n]+')do
  local x,y,z=line:match('^v ([%d%.%-]+) ([%d%.%-]+) ([%d%.%-]+)')
  if x then table.insert(vertices,V.new(tonumber(x),tonumber(y),tonumber(z)))end
  local u,v=line:match('^vt ([%d%.%-]+) ([%d%.%-]+)')
  if u then table.insert(uvs,rb.Vector2.new(tonumber(u),tonumber(v)))end
  local a,b,c=line:match('^f (%d+)/%d+/%d+ (%d+)/%d+/%d+ (%d+)/%d+/%d+')
  if a then table.insert(faces,{tonumber(a),tonumber(b),tonumber(c)})end
 end
 check(#vertices==d.vertices and #faces==d.faces and #uvs==#vertices,'asset topology matches bake')
 local low,high=V.new(math.huge,math.huge,math.huge),V.new(-math.huge,-math.huge,-math.huge)
 for i,v in vertices do
  low=low:Min(v);high=high:Max(v)
  check(math.abs(uvs[i].X-v.X/24)<.00001 and math.abs(uvs[i].Y-v.Z/24)<.00001,'continuous UV field across shared faces')
 end
 check(((low+high)/2-native.CFrame.Position).Magnitude<.0001,'exact intrinsic center / accepted road elevation')
 check(((high-low)-native.Size).Magnitude<.0001,'exact intrinsic size')
 for i=1,d.topFaces do local f=faces[i];local a,b,c=vertices[f[1]],vertices[f[2]],vertices[f[3]]
  check((b-a):Cross(c-a).Y>0,'all visible faces upward including crossover')
 end
 check(math.abs(high.Y-(if geometry=='PracticeFigure8V1'then .12 else .065))<.000001,'accepted road and crossover height')
 -- Every official centerline station must be covered by the baked top mesh.
 local function inside(p,a,b,c)
  local function side(u,v)return (v.X-u.X)*(p.Z-u.Z)-(v.Z-u.Z)*(p.X-u.X)end
  local x,y,z=side(a,b),side(b,c),side(c,a)
  return (x>=-.001 and y>=-.001 and z>=-.001)or(x<=.001 and y<=.001 and z<=.001)
 end
 for _,p0 in G.getCourse(G.getDefinition(geometry)).Samples do
  local covered=false
  for i=1,d.topFaces do local f=faces[i]
   if inside(p0,vertices[f[1]],vertices[f[2]],vertices[f[3]])then covered=true;break end
  end
  check(covered,'complete official centerline coverage')
 end
end
e.game={GetService=function()return {Shared={TrackGeometry=G,HubParkRookieLoopLayout={},TrackSurfaceStandard=S},
 WaitForChild=function()return {WaitForChild=function(_,name)return if available then sources[name]else nil end}end}end}
e.require=function(m)return m end;e.Enum=rb.Enum;e.workspace={FindFirstChild=function()return nil end}
local R=luau.load(fs.readFile('src/client/TrackRoadRibbon.luau'),{environment=e})()
for _,id in C.Order do
 local entry=C.Entries[id];local attrs={TrackId=id,GeometryId=entry.GeometryId}
 local t={GetAttribute=function(_,k)return attrs[k]end,FindFirstChild=function()return {Position=V.new(0,6.5,0),Size=V.new(1,1,1)}end}
 local model={SetAttribute=function(self,k,v)self[k]=v end}
 check(R.official(model,t,'Reference',id=='Track01'),'all five selectable tracks use continuous surface')
 check(model.ContinuousAsphaltVersion==1 and model.ContinuousAsphaltGeometry==entry.GeometryId,'track identity preserved')
 attrs.GeometryId='foreign';check(not R.official(model,t,'Reference',false),'reject geometry mismatch')
 attrs.GeometryId=entry.GeometryId;available=false;check(not R.official(model,t,'Reference',false),'missing prefab keeps old road');available=true
end
local source=fs.readFile('src/client/TrackRoadRibbon.luau')
check(not source:find('CreateEditableMesh',1,true)and not source:find('CreateMeshPartAsync',1,true),'no runtime mesh generation or security API')
print('PASS '..n..' official coverage / UV / crossover / prefab / isolation checks')
