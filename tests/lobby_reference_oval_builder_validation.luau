-- Execute the production builder against native Roblox instances, not source strings.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local p=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local geometry=luau.load(fs.readFile('src/shared/LobbyDriveGeometry.luau'))()
local g=geometry.create(p)
local modules={LobbyDrivePolicy=p,LobbyDriveGeometry=geometry}
local node={WaitForChild=function(_,name)return name end}
-- Lune 0.10.5 lookAt mirrors planar Z for non-axis directions. Use the
-- equivalent yaw constructor so perimeter orientation matches Studio Roblox.
local frames={new=rb.CFrame.new,Angles=rb.CFrame.Angles,lookAt=function(a,b)
 local d=b-a;return rb.CFrame.new(a)*rb.CFrame.Angles(0,math.atan2(-d.X,-d.Z),0)
end}
local builder=luau.load(fs.readFile('src/server/LobbyFrontDriveZoneBuilder.luau'),{environment={
 game={GetService=function()return {WaitForChild=function()return node end}end},require=function(m)return modules[m]end,
 Vector2=rb.Vector2,UDim2=rb.UDim2,Instance=rb.Instance,Vector3=rb.Vector3,CFrame=frames,Color3=rb.Color3,Enum=rb.Enum,
 PhysicalProperties=rb.PhysicalProperties,
}})()
local n=0;local function check(v,label)assert(v,label);n+=1 end
local hub=rb.Instance.new('Model');hub.Name='KDMHub'
local spawn=rb.Instance.new('Part');spawn.Name='HubSpawn';spawn.Position=rb.Vector3.new(0,1,888);spawn.Parent=hub
local ground=rb.Instance.new('Part');ground.Position=rb.Vector3.new(0,-1,850);ground.Size=rb.Vector3.new(1100,2,340)
local zone=builder.build(hub,ground)
check(zone.Parent==hub and zone:GetAttribute('FootprintVersion')=='REFERENCE_OVAL_V2','production build revision')
local center=zone:GetAttribute('Center')
local roads,kerbs,barriers,rails=0,0,0,0
for _,o in zone:GetChildren() do if o:IsA('BasePart') then
 local pos=o.CFrame.Position-center
 if o.Name=='LobbyFrontFreeDriveRoad' then
  roads+=1
  check(not o.CanCollide and not o.CanTouch and not o.CanQuery and not o.CastShadow,'asphalt visual-only')
  for _,x in {-o.Size.X/2+.1,0,o.Size.X/2-.1} do check(g.inside(pos.X+x,pos.Z,19.8),'actual asphalt respects island and safety margin') end
 elseif o.Name=='LobbyFrontInnerKerb' then
  kerbs+=1
  check(o.Anchored and not o.CanCollide and not o.CanTouch and not o.CanQuery and not o.CastShadow,'noninteractive cyan kerbs')
  check(o.Color==rb.Color3.fromRGB(111,211,245),'reference cyan palette')
  check(g.contact(pos.X,pos.Z)>19.8,'kerb-to-barrier clearance at least 18 studs after widths')
 elseif o.Name=='LobbyFrontBarrier' then
  barriers+=1
  check(o.Transparency==1 and o.CanCollide and o.CollisionGroup=='LobbyBoundary','kart-only invisible boundary')
  check(math.abs(g.contact(pos.X,pos.Z))<1e-4,'actual collision wall matches admission outline')
  check(o.Size.X==2 and o.Size.Y==14,'original tall kart-only collision wall dimensions')
 elseif o.Name=='LobbyFrontGuardrail' then
  rails+=1
  check(o.Size.X==3 and math.abs(o.Size.Y-2.4)<1e-5 and o.Size.Z<=8.13,'original bounded guardrail dimensions')
  check(o.Anchored and not o.CanCollide and not o.CanTouch and not o.CanQuery,'guardrail visuals do not snag chassis')
  check(o.Color==rb.Color3.fromRGB(246,194,36) or o.Color==rb.Color3.fromRGB(23,25,28),'original yellow and black palette')
  check(math.abs(g.contact(pos.X,pos.Z))<1e-4,'rail matches collision boundary beyond safety shoulder')
 end
end end
check(roads>150 and roads<350 and kerbs>100 and barriers>100,'bounded native part counts')
local entry=zone.LobbyFrontDriveEntry
local sign=zone.LobbyDriveDiscovery
check((sign.Size-rb.Vector3.new(8.8,3.3,.24)).Magnitude<1e-5,'physical two-line sign dimensions')
check(sign.CFrame.Position.X+sign.Size.X/2<entry.CFrame.Position.X-entry.Size.X/2,'sign leaves full 12-stud pedestrian passage clear')
check(sign.CFrame.Position.Z==spawn.Position.Z-38 and sign.CFrame.Position.Y>4,'standing sign beside ramp instead of low garage opening')
for _,name in {'LobbyDriveDiscovery','LobbyDriveSignFrame','LobbyDriveSignPost','LobbyDriveSignBase'} do
 local o=zone:FindFirstChild(name)
 check(o.Anchored and not o.CanCollide and not o.CanTouch and not o.CanQuery and not o.CastShadow,'noninteractive sign assembly '..name)
end
local faces=0
for _,surface in sign:GetChildren() do
 if surface:IsA('SurfaceGui') then
  faces+=1
  check(not surface.AlwaysOnTop and surface.MaxDistance==100,'bounded physical surface rendering')
  check(surface.DrivingCount.Text=='LIVE TEST DRIVE' and surface.DriveHint.Text=='WATCH THE DEMO · TRY DRIVING','initial zero title and demo invitation on both faces')
  check(surface.DrivingCount.TextSize>=58 and surface.DriveHint.TextSize>=34,'separate readable title and subtitle typography')
  check(surface.DrivingCount.AutoLocalize==false and surface.DriveHint.AutoLocalize==false,'approved English wayfinding')
 end
end
check(faces==2,'interior and exterior faces present')
check(entry.Size.X==12 and not entry.CanCollide and zone:GetAttribute('EntryRailLine')==836,'walkway reaches new inner cyan edge')
check(g.inside(zone.LobbyFrontDriveStart.CFrame.Position.X-center.X,zone.LobbyFrontDriveStart.CFrame.Position.Z-center.Z,7),'unchanged start stays safe')
check(rails>300 and zone:GetAttribute('PermanentSkidMarkCount')==0,'guardrails restored around both perimeters, no baked skids')
-- Every collision edge endpoint is covered, including the pedestrian bridge.
local walls={};for _,o in zone:GetChildren()do if o.Name=='LobbyFrontBarrier'then table.insert(walls,o)end end
for _,e in g.boundaries do for _,v in {e.a,e.b}do
 local hits=0
 for _,wall in walls do
  local delta=center+rb.Vector3.new(v.x,7,v.z)-wall.CFrame.Position
  if math.abs(delta:Dot(wall.CFrame.RightVector))<=wall.Size.X/2+.001 and math.abs(delta:Dot(wall.CFrame.LookVector))<=wall.Size.Z/2+.001 then hits+=1 end
 end
 check(hits>=2,'adjacent collision walls overlap at each perimeter seam '..v.x..','..v.z..' hits='..hits)
end end
check(zone.LobbyFrontSmoothFloor.CanCollide,'smooth collision support retained')
-- Optional review artifacts derive from the actual builder and geometry.
if require('@lune/process').env.KDM_EXPORT_OVAL=='1' then
 local out='artifacts/lobby-reference-oval';fs.writeDir(out)
 fs.writeFile(out..'/REFERENCE_OVAL_ZONE.rbxm',rb.serializeModel({zone}))
 local road={};for _,o in zone:GetChildren() do if o:IsA('BasePart') and o.Name=='LobbyFrontFreeDriveRoad' then
  table.insert(road,{x=o.CFrame.Position.X,z=o.CFrame.Position.Z,w=o.Size.X,d=o.Size.Z})
 end end
 fs.writeFile(out..'/geometry.json',require('@lune/serde').encode('json',{roadLoops=g.roadLoops,boundaries=g.boundaries,roads=road}))
end
print('PASS: '..n..' actual oval builder / asphalt / kerb / collision / bridge / start / native budgets checks')
