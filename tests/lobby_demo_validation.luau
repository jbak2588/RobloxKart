local fs,luau=require("@lune/fs"),require("@lune/luau")
local route=luau.load(fs.readFile("src/shared/LobbyDemoRoute.luau"))()
local policy=luau.load(fs.readFile("src/shared/LobbyDrivePolicy.luau"))()
local geometry=luau.load(fs.readFile("src/shared/LobbyDriveGeometry.luau"))().create(policy)
local count=0
local function check(v,label) assert(v,label);count+=1 end
-- Sweep the real footprint through every pose, including sideways donut exits.
local previous
local seen,leftTurns,rightTurns={},0,0
check(route.PatternCount==5 and #route.Patterns==5,'three original patterns plus two side excursions')
check(route.VisualScale>=1.10 and route.VisualScale<=1.15,'bot-only approved enlargement range')
for i=0,math.ceil(route.CycleSeconds*240) do
 local t=i/120
 local x,z,dx,dz,drift,phase,pattern,boosting=route.sample(t)
 seen[pattern]=true
 local a=math.atan2(dz,dx)-math.rad(32)*drift
 check(policy.fits(geometry,x,z,math.cos(a),math.sin(a)),"full kart stays inside existing apron")
 -- Conservative 12% enlarged visual bounds, including sideways drift poses.
 for _,front in {-6,6}do for _,side in {-4.2,4.2}do
  check(geometry.inside(x+math.cos(a)*front-math.sin(a)*side,z+math.sin(a)*front+math.cos(a)*side,1.35),'enlarged full visual stays inside apron')
 end end
 check(math.abs(dx*dx+dz*dz-1)<1e-8,"unit tangent")
 if previous then
  local distance=math.sqrt((x-previous[1])^2+(z-previous[2])^2)
  check(distance<=route.Speed/120+.0001,"continuous travel across donut and lap joins")
  check(dx*previous[3]+dz*previous[4]>=math.cos(math.rad(180)/120),'no abrupt heading change on entry, circle or return')
 end
 if phase=="DONUT" then
  local radius=if pattern=='DOUBLE_DONUT'then 22 else 28
  check(math.abs(math.sqrt((x+120)^2+(z-(50-radius))^2)-radius)<.01,"circle is in front of Lobby exit")
 elseif phase=="SIDE_DRIFT" then
  local meta
  for _,v in route.Patterns do if v.Name==pattern then meta=v end end
  check(meta and meta.Side~=nil,'side circle identity')
  check(math.abs(math.sqrt((x-meta.SideCenterX)^2+(z-meta.SideCenterZ)^2)-meta.SideRadius)<.01,'exactly authored side circle')
  check(math.abs(drift)>=.2 and not boosting,'side circle always drifts without boost')
 elseif phase=="TURN" then check(math.abs(drift)>=.2,'all left/right bends produce friction regardless of charge')
 else check(drift==0,"no smoke while driving straight") end
 if drift<0 then leftTurns+=1 elseif drift>0 then rightTurns+=1 end
 check(type(boosting)=='boolean','explicit per-pattern boost phase')
 if pattern=='RIGHT_SIDE_DRIFT' or pattern=='LEFT_SIDE_DRIFT' then check(not boosting,'entire side entry/circle/return has no boost') end
 previous={x,z,dx,dz}
end
check(seen.WIDE_LOOP and seen.S_SLALOM and seen.DOUBLE_DONUT,'all three patterns mixed in a shared cycle')
check(seen.RIGHT_SIDE_DRIFT and seen.LEFT_SIDE_DRIFT,'both side excursions appear every cycle')
check(leftTurns>0 and rightTurns>0,'both steering directions drift')
for _,pattern in route.Patterns do
 if pattern.Side then
  check(math.abs((pattern.SideEndSeconds-pattern.SideStartSeconds)*route.Speed-2*math.pi*pattern.SideRadius)<.01,'one full side revolution only')
 end
 local t=pattern.StartSeconds+route.CycleSeconds
 local ax,az,adx,adz=route.sample(t-.001)
 local bx,bz,bdx,bdz=route.sample(t+.001)
 check(math.sqrt((ax-bx)^2+(az-bz)^2)<.073,'pattern switch has no position jump')
 check(adx*bdx+adz*bdz>.999,'pattern switch keeps common forward tangent')
end
local function signal()
 local callbacks={}
 return {Connect=function(_,fn)
  callbacks[fn]=true;return {Disconnect=function()callbacks[fn]=nil end}
 end,Fire=function(_,...)for fn in callbacks do fn(...)end end,
 count=function()local n=0;for _ in callbacks do n+=1 end;return n end}
end
local function player()
 local p={attrs={},signals={}}
 function p:GetAttribute(n)return self.attrs[n]end
 function p:GetAttributeChangedSignal(n)self.signals[n]=self.signals[n]or signal();return self.signals[n]end
 function p:set(n,v)self.attrs[n]=v;self:GetAttributeChangedSignal(n):Fire()end
 return p
end
local p1,p2=player(),player()
local list={}
local players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function()return list end}
local world={GetAttribute=function()return "HUB"end,GetServerTimeNow=function()return 123 end}
local created,destroyed=0,0
local instances={new=function()
 created+=1
 local f={attributes={}}
 function f:SetAttribute(n,v)self.attributes[n]=v end
 function f:Destroy()self.Parent=nil;destroyed+=1 end
 return f
end}
local rb=require("@lune/roblox")
local game={PrivateServerId="",GetService=function(_,name)
 return if name=="Players"then players elseif name=="Workspace"then world else {Shared={LobbyDemoRoute=route,LobbyPracticePolicy=luau.load(fs.readFile("src/shared/LobbyPracticePolicy.luau"),{environment={Color3=rb.Color3}})()}}
end}
local service=luau.load(fs.readFile("src/server/LobbyDemoService.luau"),{environment={game=game,require=function(x)return x end,Instance=instances}})()
local zone={Parent={},Destroying=signal()}
service.start(zone);check(created==0,"empty Hub has no bot")
list={p1};players.PlayerAdded:Fire(p1);check(created==1,"first connected user starts bot before lobby admission")
p1:set("RaceState","GARAGE");check(created==1 and destroyed==0,"first lobby user starts bot")
service.start(zone);p1:set("RaceState","GARAGE");check(created==1,"idempotent single bot")
list={p1,p2};players.PlayerAdded:Fire(p2);p2:set("RaceState","GARAGE");check(created==1,"second user shares bot timeline")
p1:set("KDMRoutePending","RACE_LAUNCH");check(destroyed==0,"remaining lobby user keeps bot")
p2:set("RaceState","RACING");check(destroyed==0,"connected users keep bot regardless of gameplay state")
p2:set("LobbyDriveActive",true);check(created==1 and destroyed==0,"human test drive preserves same timeline")
players.PlayerRemoving:Fire(p2);list={p1};check(destroyed==0,"another connected user keeps bot")
p1:set("KDMRoutePending",nil);check(created==1,"route changes never restart timeline")
players.PlayerRemoving:Fire(p1);list={};check(destroyed==1,"only last server departure removes bot")
list={p1};players.PlayerAdded:Fire(p1);check(created==2,"new server visitor starts fresh timeline")
service.stop();check(destroyed==2 and players.PlayerAdded.count()==0 and players.PlayerRemoving.count()==0,"stop removes bot and global listeners")
check(p1.signals.RaceState.count()==0 and zone.Destroying.count()==0,"stop releases player and zone listeners")
game.PrivateServerId="reserved";service.start(zone);check(created==2,"reserved server has no bot")
game.PrivateServerId="";service.start(zone);check(created==3,"can restart cleanly")
zone.Destroying:Fire();check(destroyed==3,"zone destruction tears down")
for _,path in {"src/client/LobbyDemoController.luau","src/server/init.server.luau","src/client/init.client.luau"} do
 check(luau.compile(fs.readFile(path))~=nil,"production source compiles: "..path)
end
print("PASS: "..count.." Lobby demo geometry, continuous motion, audience and lifecycle checks")
