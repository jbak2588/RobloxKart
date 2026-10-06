local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local checks=0
local function check(value,label) assert(value,label);checks+=1 end
local theme=luau.load(fs.readFile('src/shared/KDMUiTheme.luau'),{environment={Color3=rb.Color3}})()
local assets=luau.load(fs.readFile('src/shared/KDMWorldAssets.luau'))()
local art=rb.deserializeModel(fs.readFile('src/shared/KDMPitGarageArt.rbxm'))[1]
local shared={WaitForChild=function(_,name) return {Name=name} end,FindFirstChild=function(_,name) return if name=='KDMPitGarageArt' then art else nil end}
local storage={WaitForChild=function() return shared end}
local function builder(template)
 shared.FindFirstChild=function() return template end
 return luau.load(fs.readFile('src/server/CompactHubBuilder.luau'),{environment={game={GetService=function() return storage end},require=function(m) return if m.Name=='KDMWorldAssets' then assets else theme end,
  Instance=rb.Instance,Color3=rb.Color3,Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame,UDim2=rb.UDim2,Enum=rb.Enum,warn=function() end}})()
end
local spawn=rb.Instance.new('SpawnLocation');spawn.CFrame=rb.CFrame.new(0,.5,900)
local world=rb.Instance.new('Model');world:SetAttribute('KDMServerRole','RACE')
local b=builder(art)
check(b.build(world,spawn)==nil,'reserved RACE isolation')
world:SetAttribute('KDMServerRole','HUB')
local hub=b.build(world,spawn)
check(hub:GetAttribute('HubPresentation')=='PIT_GARAGE','actual art build succeeds')
check(b.build(world,spawn)==hub and #world:GetChildren()==1,'idempotent')
check(hub:FindFirstChild('HubFloor')==nil,'no H1 duplicate floor/stations')
check(hub.KDMPitGarageArt:IsA('Model') and hub.HubSpawn:IsA('SpawnLocation'),'art and spawn')
for _,name in {'GarageStationSign','RaceStationSign','TrackStationSign'} do
 check((hub.Visuals[name].CFrame.Position-hub.HubSpawn.CFrame.Position):Dot(hub.HubSpawn.CFrame.LookVector)>0,'arrival faces navigation sign '..name)
end
local floor=hub.GarageFloor
check(floor and math.abs(floor.CFrame.Position.Y+floor.Size.Y/2-.25)<.001,'interior floor clears Baseplate by .25 studs')
local donorFloor=hub.KDMPitGarageArt.Garage_Part_Architecture:FindFirstChild('Union')
check(donorFloor.Transparency==1 and not donorFloor.CanCollide and floor:IsA('Part') and floor.CanCollide,'one continuous floor replaces donor lift cutouts')
check(math.abs(hub.Forecourt.CFrame.Position.Y+hub.Forecourt.Size.Y/2-.25)<.001,'forecourt also clears Baseplate')
check(math.abs(hub.Anchors.MyKartDisplayAnchor.CFrame.Position.Y-.33)<.001,'display anchor follows raised floor')
for _,name in {'GaragePromptAnchor','TracksPromptAnchor','RacePromptAnchor','MyKartDisplayAnchor','HeroBoardAnchor','GarageBoardAnchor','TracksBoardAnchor','QueueFutureAnchor'} do
 local a=hub.Anchors:FindFirstChild(name)
 check(a and a.Anchored and a.Transparency==1 and not a.CanCollide and not a.CanTouch,'safe anchor '..name)
end
local classes={}
for _,node in hub.KDMPitGarageArt:GetDescendants() do
 classes[node.ClassName]=(classes[node.ClassName] or 0)+1
 check(not node:IsA('LuaSourceContainer') and not node:IsA('RemoteEvent') and not node:IsA('RemoteFunction') and not node:IsA('Seat') and not node:IsA('Constraint') and not node:IsA('ProximityPrompt') and not node:IsA('Terrain'),'sanitized '..node.ClassName)
 if node:IsA('BasePart') then check(node.Anchored and not node.CanTouch,'static art');if node.CanCollide then check(node:IsDescendantOf(hub.KDMPitGarageArt.Garage_Part_Architecture) or node:IsDescendantOf(hub.KDMPitGarageArt.Bldg_Kit),'structural-only collision') end end
end
check(classes.MeshPart==254 and classes.SurfaceAppearance==202,'native geometry/materials preserved')
check(not hub.KDMPitGarageArt:FindFirstChild('Auto_Lifts'),'Bay floor clear of lifts')
local runtimeCounts={BasePart=0,MeshPart=0,Decal=0,SurfaceGui=0,Light=0,ProximityPrompt=0}
local prompts,boards=0,0
for _,node in hub:GetDescendants() do
 if runtimeCounts[node.ClassName] then runtimeCounts[node.ClassName]+=1 end
 if node:IsA('BasePart') then runtimeCounts.BasePart+=1 end
 if node:IsA('Light') then runtimeCounts.Light+=1;check(node.Brightness<=1 and node.Range<=30,'showroom lighting bounded') end
 if node:IsA('ProximityPrompt') then prompts+=1;check(node.ActionText=='OPEN' and node:IsDescendantOf(hub.Stations),'only KDM navigation');check((node.Parent.CFrame.Position-hub.HubSpawn.CFrame.Position).Magnitude/16<=5,'compact walking') end
 if node:IsA('ImageLabel') then boards+=1;check(node.ScaleType==rb.Enum.ScaleType.Fit,'board aspect ratio') end
end
check(prompts==3 and boards==3,'bounded static primary boards')
for _,template in {false,rb.Instance.new('Model')} do
 local w=rb.Instance.new('Model');w:SetAttribute('KDMServerRole','HUB')
 local fallback=builder(if template then template else nil).build(w,spawn)
 check(fallback.HubFloor and fallback.HubSpawn and not fallback:FindFirstChild('KDMPitGarageArt'),'missing/unsafe art safe H1 fallback')
end
print(require('@lune/serde').encode('json',runtimeCounts))
print('Pit Garage art validation PASS: '..checks..' checks')

