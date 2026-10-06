local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local theme=luau.load(fs.readFile("src/shared/KDMUiTheme.luau"),{environment={Color3=rb.Color3}})()
local module={WaitForChild=function(self) return self end,FindFirstChild=function() return nil end}
local builder=luau.load(fs.readFile("src/server/CompactHubBuilder.luau"),{environment={
 game={GetService=function() return module end},require=function() return theme end,
 Instance=rb.Instance,Color3=rb.Color3,Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame,UDim2=rb.UDim2,Enum=rb.Enum}})()
local count=0
local function check(v,s) assert(v,s);count+=1 end
local world=rb.Instance.new("Model");world:SetAttribute("KDMServerRole","RACE")
local original=rb.Instance.new("Part");original.Name="TestTrack";original.Parent=world
local spawn=rb.Instance.new("SpawnLocation");spawn.CFrame=rb.CFrame.new(0,.5,900)
check(builder.build(world,spawn)==nil and #world:GetChildren()==1,"RACE role builds nothing")
world:SetAttribute("KDMServerRole","HUB")
local hub=builder.build(world,spawn)
check(hub.Name=="KDMHub" and hub.Parent==world,"HUB root")
check(builder.build(world,spawn)==hub and #world:GetChildren()==2,"idempotent creation")
check(world.TestTrack==original and original.CFrame==rb.CFrame.identity,"race world untouched")
check(hub.HubSpawn:IsA("SpawnLocation") and hub.HubSpawn.Neutral,"valid spawn")
local parts,signs,labels,prompts=0,0,0,0
for _,node in hub:GetDescendants() do
 if node:IsA("BasePart") then parts+=1;check(node.Anchored,"static build-time world")
 elseif node:IsA("SurfaceGui") then signs+=1
 elseif node:IsA("TextLabel") then labels+=1
 elseif node:IsA("ProximityPrompt") then prompts+=1 end
end
for _,definition in {{"GarageStation","GARAGE"},{"TrackStation","TRACKS"},{"RaceStation","RACE"}} do
 local station=hub.Stations:FindFirstChild(definition[1]);check(station:GetAttribute("HubAction")==definition[2],"station identity")
 check(station.HubPrompt.HoldDuration==0 and not station.HubPrompt.RequiresLineOfSight,"mobile prompt")
 check((station.CFrame.Position-hub.HubSpawn.CFrame.Position).Magnitude/16<=10,"compact walking range")
end
check(parts==9 and signs==4 and labels==4 and prompts==3,"bounded foundation budget")
print(string.format("PASS: %d Compact Hub checks; Parts=%d SurfaceGui=%d TextLabel=%d Prompts=%d",count,parts,signs,labels,prompts))

-- Exercise the production staging function with independent players and race guard.
local source=fs.readFile("src/server/GarageController.luau")
local stageSource=assert(source:match("(local function stageCharacter.-)\nfunction GarageController.start"))
local stage=luau.load(stageSource.."\nreturn stageCharacter",{environment={Enum=rb.Enum,CFrame=rb.CFrame,task={wait=function() end},warn=function() end}})()
local function racer(state)
 local root={Anchored=true,IsA=function(_,class) return class=="BasePart" end}
 local humanoid={Sit=true,WalkSpeed=19,JumpPower=52,ChangeState=function() end}
 local character={FindFirstChildOfClass=function() return humanoid end,FindFirstChild=function() return root end,PivotTo=function(self,value) self.frame=value end}
 local attributes={RaceState=state}
 local player={Character=character,GetAttribute=function(_,name) return attributes[name] end,SetAttribute=function(_,name,value) attributes[name]=value end}
 return player,root,humanoid,character
end
local a,ar,ah,ac=racer("GARAGE")
local b,br,bh,bc=racer("GARAGE")
stage(a,hub.HubSpawn);check(not ar.Anchored and br.Anchored,"one player's staging does not change another")
stage(b,hub.HubSpawn);check(not br.Anchored and not ar.Anchored,"independent movable players")
check(a:GetAttribute("HubArrivalSerial")==1 and b:GetAttribute("HubArrivalSerial")==1,"independent arrival camera notifications")
stage(a,hub.HubSpawn);check(a:GetAttribute("HubArrivalSerial")==2 and b:GetAttribute("HubArrivalSerial")==1,"repeat arrival signals only staged racer")
check(ah.WalkSpeed==19 and ah.JumpPower==52 and bh.WalkSpeed==19 and bh.JumpPower==52,"walking/jump settings preserved")
check(ac.frame==hub.HubSpawn.CFrame*rb.CFrame.new(0,3,0),"Hub spawn placement")
local c,cr=racer("RACING");stage(c,hub.HubSpawn);check(cr.Anchored,"Hub staging rejects race state")
check(c:GetAttribute("HubArrivalSerial")==nil,"race rejection cannot reset Hub camera")
check(source:find('player.RespawnLocation = spawnLocation',1,true),"Hub native respawn location bound")
print("PASS: "..count.." total Hub foundation / movement checks")
