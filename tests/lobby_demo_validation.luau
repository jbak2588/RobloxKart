local fs,luau=require("@lune/fs"),require("@lune/luau")
local route=luau.load(fs.readFile("src/shared/LobbyDemoRoute.luau"))()
local policy=luau.load(fs.readFile("src/shared/LobbyDrivePolicy.luau"))()
local geometry=luau.load(fs.readFile("src/shared/LobbyDriveGeometry.luau"))().create(policy)
local count=0
local function check(v,label) assert(v,label);count+=1 end
-- Sweep the real footprint through every pose, including sideways donut exits.
local previous
for i=0,math.ceil(route.CycleSeconds*240) do
 local t=i/120
 local x,z,dx,dz,drift,phase=route.sample(t)
 local a=math.atan2(dz,dx)-math.rad(32)*drift
 check(policy.fits(geometry,x,z,math.cos(a),math.sin(a)),"full kart stays inside existing apron")
 check(math.abs(dx*dx+dz*dz-1)<1e-8,"unit tangent")
 if previous then
  local distance=math.sqrt((x-previous[1])^2+(z-previous[2])^2)
  check(distance<=route.Speed/120+.0001,"continuous travel across donut and lap joins")
 end
 if phase=="DONUT" then
  check(math.abs(math.sqrt((x+120)^2+(z-22)^2)-28)<1e-7,"circle is in front of Lobby exit")
 else check(drift==0,"no smoke while cruising") end
 previous={x,z}
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
local game={PrivateServerId="",GetService=function(_,name)
 return if name=="Players"then players elseif name=="Workspace"then world else {Shared={LobbyDemoRoute=route}}
end}
local service=luau.load(fs.readFile("src/server/LobbyDemoService.luau"),{environment={game=game,require=function(x)return x end,Instance=instances}})()
local zone={Parent={},Destroying=signal()}
service.start(zone);check(created==0,"empty Hub has no bot")
list={p1};players.PlayerAdded:Fire(p1);check(created==0,"not yet admitted has no bot")
p1:set("RaceState","GARAGE");check(created==1 and destroyed==0,"first lobby user starts bot")
service.start(zone);p1:set("RaceState","GARAGE");check(created==1,"idempotent single bot")
list={p1,p2};players.PlayerAdded:Fire(p2);p2:set("RaceState","GARAGE");check(created==1,"second user shares bot timeline")
p1:set("KDMRoutePending","RACE_LAUNCH");check(destroyed==0,"remaining lobby user keeps bot")
p2:set("RaceState","RACING");check(destroyed==1,"last lobby departure removes bot")
p2:set("RaceState","GARAGE");check(created==2,"return starts a fresh timeline")
players.PlayerRemoving:Fire(p2);list={p1};check(destroyed==2,"PlayerRemoving excludes departing audience immediately")
p1:set("KDMRoutePending",nil);check(created==3,"cancelled launch restores lobby demonstration")
service.stop();check(destroyed==3 and players.PlayerAdded.count()==0 and players.PlayerRemoving.count()==0,"stop removes bot and global listeners")
check(p1.signals.RaceState.count()==0 and zone.Destroying.count()==0,"stop releases player and zone listeners")
game.PrivateServerId="reserved";service.start(zone);check(created==3,"reserved server has no bot")
game.PrivateServerId="";service.start(zone);check(created==4,"can restart cleanly")
zone.Destroying:Fire();check(destroyed==4,"zone destruction tears down")
for _,path in {"src/client/LobbyDemoController.luau","src/server/init.server.luau","src/client/init.client.luau"} do
 check(luau.compile(fs.readFile(path))~=nil,"production source compiles: "..path)
end
print("PASS: "..count.." Lobby demo geometry, continuous motion, audience and lifecycle checks")
