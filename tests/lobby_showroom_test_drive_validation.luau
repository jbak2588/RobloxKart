local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local policy=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local geom=luau.load(fs.readFile('src/shared/LobbyDriveGeometry.luau'))().create(policy)
local catalog=luau.load(fs.readFile('src/shared/KartCatalog.luau'),{environment={Enum=rb.Enum,Color3=rb.Color3}})()
local signal={Connect=function()return {Disconnect=function()end}end};local count=0
local function check(v,label)assert(v,label);count+=1 end
local players={GetPlayers=function()return {}end,PlayerAdded=signal,PlayerRemoving=signal}
local run={Heartbeat=signal};local physics={IsCollisionGroupRegistered=function()return true end,CollisionGroupSetCollidable=function()end}
local role,bot,canEnter='HUB',false,true
local world={GetAttribute=function(_,key)return if key=='KDMServerRole'then role else bot end}
local shared={WaitForChild=function(_,name)return {Name=name}end}
local modules={KDMStraightSpeedResolver=luau.load(fs.readFile('src/server/KDMStraightSpeedResolver.luau'),{environment={Vector3=rb.Vector3}})(),LobbyDrivePresence=luau.load(fs.readFile('src/server/LobbyDrivePresence.luau'))(),TestDriveQualification=luau.load(fs.readFile('src/server/TestDriveQualification.luau'))(),LobbyPracticeCombat=require('./helpers/lobby_practice_stub'),LobbyDrivePolicy=policy,LobbyDriveGeometry={create=function()return geom end},KartConfig={},KartCatalog=catalog,KartVisualFactory={},LobbyDriftSession={}}
local source=fs.readFile('src/server/LobbyTestDriveService.luau'):gsub('return Service%s*$',[[
createKart=function(player,definition,frame)Service.probedKartId=definition.Id;error('QA_FACTORY_STOP')end
Service.probeDrive=drive
return Service]])
local service=luau.load(source,{environment={script={Parent={KDMStraightSpeedResolver={Name='KDMStraightSpeedResolver'},LobbyDrivePresence={Name='LobbyDrivePresence'},TestDriveQualification={Name='TestDriveQualification'},LobbyDriftSession={Name='LobbyDriftSession'},LobbyPracticeCombat={Name='LobbyPracticeCombat'}}},game={PrivateServerId='',GetService=function(_,name)return ({Players=players,ReplicatedStorage={WaitForChild=function()return shared end},RunService=run,PhysicsService=physics,Workspace=world})[name]end},require=function(m)return modules[m.Name]end,warn=function()end,Instance={new=function()return {OnServerEvent=signal}end},Vector3=rb.Vector3,CFrame=rb.CFrame}})()
local spawn={Position=rb.Vector3.new(0,1,888)};local hub={FindFirstChild=function()return spawn end}
local zone={Parent=hub,Destroying=signal,LobbyFrontDriveStart={CFrame=rb.CFrame.new(20,1.75,816)},GetAttribute=function()return rb.Vector3.new(120,0,766)end}
zone.SetAttribute=function()end;zone.FindFirstChild=function()return nil end
service.start(zone,function()return canEnter end)
local function player()
 local attrs={RaceState='GARAGE',SelectedKartId='Kart01'}
 local humanoid={Health=100};local root={Position=spawn.Position};local character={FindFirstChildOfClass=function()return humanoid end,FindFirstChild=function()return root end}
 return {Character=character,GetAttribute=function(_,k)return attrs[k]end,SetAttribute=function(_,k,v)attrs[k]=v end},attrs
end
for _,id in {'Kart05','Kart06','Kart07','Kart08','Kart09','Kart10','Kart11'}do
 local p,a=player();local ok,msg=pcall(service.probeDrive,p,id)
 check(ok and msg==false and service.probedKartId==id,'actual production selection reaches requested preview factory')
 check(a.SelectedKartId=='Kart01','temporary preview does not mutate persisted/committed selection')
end
for _,bad in {'Kart01','Kart02','Kart04','Unknown','',123,false,{},0/0}do
 local p,a=player();local ok,msg=service.probeDrive(p,bad)
 check(ok==false and msg=='SELECT A KART','malformed/non-V2 preview rejected')
 check(not a.LobbyDrivePending and not a.LobbyDriveActive and not a.LobbyDriveGeneration,'rejected preview allocates no generation/vehicle/pending state')
end
local p,a=player();local ok,msg=pcall(service.probeDrive,p,nil)
check(ok and msg==false and service.probedKartId=='Kart01','old entry path still drives selected Sprint')
for _,guard in {'RACE','BOT','CAN_ENTER','ROUTE','PENDING'}do
 local p,a=player();role=if guard=='RACE'then'RACE'else'HUB';bot=guard=='BOT';canEnter=guard~='CAN_ENTER'
 if guard=='ROUTE'then a.KDMRoutePending='RACE_LAUNCH'elseif guard=='PENDING'then a.LobbyDrivePending=true end
 local result=service.probeDrive(p,'Kart06');check(result==false,'existing admission guard retained: '..guard)
end
print('PASS '..count..' production showroom preview selection / invalid payload / unchanged selection / eligibility checks')
