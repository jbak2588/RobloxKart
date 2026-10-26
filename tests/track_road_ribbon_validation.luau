local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local env={Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame,Color3=rb.Color3}
local G=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment=env})()
local P=luau.load(fs.readFile('src/shared/HubParkRookieLoopLayout.luau'),{environment=env})()
local S=luau.load(fs.readFile('src/shared/TrackSurfaceStandard.luau'),{environment=env})()
local parts={};local function object(class)
 local p={class=class};function p:IsA(c)return c==self.class end
 function p:SetAttribute(k,v)self[k]=v end
 table.insert(parts,p);return p
end
local e=table.clone(env);e.game={GetService=function()return {Shared={TrackGeometry=G,HubParkRookieLoopLayout=P,TrackSurfaceStandard=S}}end};e.require=function(m)return m end
e.Instance={new=object};e.Enum=rb.Enum
local R=luau.load(fs.readFile('src/client/TrackRoadRibbon.luau'),{environment=e})()
local n=0;local function check(v,m)assert(v,m);n+=1 end
local parent={}
R.triangle(parent,rb.Vector3.new(0,0,0),rb.Vector3.new(10,0,0),rb.Vector3.new(0,0,20),'ignored')
local area=0
for _,p in parts do if p.class=='WedgePart'then
 area+=p.Size.Y*p.Size.Z/2
 check(not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow,'visual-only triangles')
 check(math.abs(p.CFrame.RightVector.Y)>.9999,'asphalt triangle lies flat')
 check(p.Material==rb.Enum.Material.Concrete and p.MaterialVariant=='','matte without wet PBR variant')
end end
check(math.abs(area-100)<.001,'two wedges cover exactly the source triangle area')
for _,park in {true,false}do
 table.clear(parts);local t={};function t:GetAttribute(k)return ({Origin=rb.Vector3.zero,GeometryId='PracticeFigure8V1',RoadWidth=60})[k]end
 function t:FindFirstChild()return nil end
 local model=object('Model');R.build(model,t,park,'ignored')
 local faces=0
 for _,p in parts do if p.class=='WedgePart'then
  faces+=1;check(p.Color==(if park then S.ParkRoadTint else S.RoadTint),'Park-only dark tint; Green albedo unchanged')
  check(p.Size.Y>0 and p.Size.Z>0,'no degenerate road faces')
  local top=p.CFrame.Position.Y+.005
  check(math.abs(top-(if park then .02 else .065))<.00001,'accepted road top / skid datum retained')
 end end
 check(faces>100 and faces<5000,'bounded road tessellation')
 print((if park then 'Park'else 'Green')..': '..faces..' shared-edge asphalt faces')
end
print('PASS '..n..' road coverage / matte / visual-only / height checks')
