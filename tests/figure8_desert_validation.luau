local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local count=0;local function check(v,m)count+=1;assert(v,m)end
local policy=luau.load(fs.readFile('src/shared/Figure8DesertPolicy.luau'))()
local ws={GetAttribute=function()return true end}
check(policy.enabled(ws,false,10772198697,106553302629620),'exact authorized staging pair')
for _,pair in {{10768420544,127925465904803},{10772198697,127925465904803},{10768420544,106553302629620},{0,0}}do
 check(not policy.enabled(ws,false,pair[1],pair[2]),'no production, mixed pair or live flag bypass')
end
check(policy.enabled(ws,true,0,0),'explicit Studio preview')
check(not policy.enabled({GetAttribute=function()return nil end},true,0,0),'Studio requires opt-in')
local geometry=luau.load(fs.readFile('src/shared/TrackGeometry.luau'),{environment={Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame}})()
local env=luau.load(fs.readFile('src/client/Figure8DesertEnvironment.luau'),{environment={Color3=rb.Color3,game={GetService=function(_,n)return if n=='ReplicatedStorage'then {Shared={TrackGeometry='geometry'}}else {} end},require=function()return geometry end}})()
local course=geometry.getCourse(geometry.getDefinition('PracticeFigure8V1'))
for _,p in course.Samples do
 for _,dx in {-90,0,90}do for _,dz in {-90,0,90}do check(env.protected(p.X+dx,p.Z+dz),'terrain exclusion preserves road plus 90-stud recovery envelope')end end
 check(env.roadDistance(course.Samples,p.X,p.Z)<.001,'actual polyline clearance evaluator')
end
local surface=luau.load(fs.readFile('src/assets/DesertSource/TerrainSurface.luau'),{environment={script={Parent={WaitForChild=function(_,name)return name end}},require=function(name)return luau.load(fs.readFile('src/assets/DesertSource/'..name..'.luau'))()end}})()
check(#surface.Rows==608 and surface.Width==608 and surface.Depth==448,'source terrain sample dimensions')
local max=0
for _,row in surface.Rows do
 check(#row==surface.Depth*4,'untruncated source row')
 for z=1,surface.Depth do local q=tonumber(row:sub((z-1)*4+1,(z-1)*4+3),16);local m=tonumber(row:sub(z*4,z*4),16)
  check(q~=nil and surface.Materials[m+1]~=nil,'valid original height/material encoding');max=math.max(max,q/4-8)
 end
end
check(max>140 and max<=256,'source contains real tall cliff relief')
local resources=rb.deserializeModel(fs.readFile('src/assets/KDMDesertResources.rbxmx'))[1]
check(#resources.Natural:GetChildren()==4,'only cactus/agave/tumbleweed/boulder; grass excluded')
for _,x in resources:GetDescendants()do check(not x:IsA('LuaSourceContainer'),'no imported template scripts')end
check(resources.Natural:FindFirstChild('Racing_Foliage_Cactus_a')~=nil,'original cactus is present')
check(resources.Materials:FindFirstChild('Racing_Buttes_A')~=nil,'original cliff material present')
print('PASS: '..count..' staging isolation, original resources/terrain and actual Figure-8 road/recovery clearance checks')
