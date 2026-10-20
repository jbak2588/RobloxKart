-- Production service lifecycle with simulated Players/Seat physics, no network or stores.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local signal=require('./helpers/practice_ui_nodes').signal
local policy=luau.load(fs.readFile('src/shared/LobbyDrivePolicy.luau'))()
local geometry=luau.load(fs.readFile('src/shared/LobbyDriveGeometry.luau'))().create(policy)
local catalog=luau.load(fs.readFile('src/shared/KartCatalog.luau'),{environment={Enum=rb.Enum,Color3=rb.Color3}})()
local Presence=luau.load(fs.readFile('src/server/LobbyDrivePresence.luau'))()
local players={GetPlayers=function()return {}end,PlayerAdded=signal(),PlayerRemoving=signal()}
local physics={IsCollisionGroupRegistered=function()return true end,CollisionGroupSetCollidable=function()end}
local frames,karts={},{}
local attrs={}
local spawn={Position=rb.Vector3.new(0,1,888),CFrame=rb.CFrame.new(0,1,888)}
local hub={FindFirstChild=function()return spawn end}
local zone={Parent=hub,Destroying=signal(),LobbyFrontDriveStart={CFrame=rb.CFrame.new(20,1.75,816)},
 SetAttribute=function(_,k,v)attrs[k]=v end,FindFirstChild=function()return nil end,
 GetAttribute=function(_,k)return if k=='Center' then rb.Vector3.new(120,0,766)else attrs[k]end}
local world={GetAttribute=function(_,k)return if k=='KDMServerRole'then'HUB'else false end,FindFirstChild=function()return hub end}
local shared={WaitForChild=function(_,n)return {Name=n}end}
local modules={LobbyDrivePresence=Presence,TestDriveQualification=luau.load(fs.readFile('src/server/TestDriveQualification.luau'))(),
 LobbyPracticeCombat=require('./helpers/lobby_practice_stub'),LobbyDrivePolicy=policy,LobbyDriveGeometry={create=function()return geometry end},
 KartConfig={},KartCatalog=catalog,KartVisualFactory={},LobbyDriftSession={new=function()return {}end}}
local parent=setmetatable({}, {__index=function(_,n)return {Name=n}end})
local source=fs.readFile('src/server/LobbyTestDriveService.luau'):gsub('return Service%s*$',[[
createKart=function(player,definition,frame)
 table.insert(frames,frame)
 local body={Parent=true,Anchored=false}
 local seat={Parent=true,Occupant=nil,GetPropertyChangedSignal=function()return signal()end}
 function seat:Sit(h)self.Occupant=h;h.SeatPart=self end
 local kart={Parent=zone,Destroying=signal()}
 function kart:Destroy()self.Parent=nil;body.Parent=nil;seat.Parent=nil end
 table.insert(karts,kart)
 return kart,body,seat
end
Service.enter=drive
return Service]])
local ticks=0
local run={Heartbeat={Connect=function()return {}end,Wait=function()ticks+=1 end}}
local service=luau.load(source,{environment={script={Parent=parent},
 game={PrivateServerId='',GetService=function(_,n)return ({Players=players,ReplicatedStorage={WaitForChild=function()return shared end},RunService=run,PhysicsService=physics,Workspace=world})[n]end},
 require=function(m)return modules[m.Name]end,signal=signal,frames=frames,karts=karts,
 Vector3=rb.Vector3,CFrame=rb.CFrame,Enum=rb.Enum,
 Instance={new=function()return {OnServerEvent=signal()}end}}})()
service.start(zone,function()return true end)
local n=0;local function check(v,m)n+=1;assert(v,m)end
local function newPlayer()
 local a={RaceState='GARAGE',SelectedKartId='Kart05'};local signals={}
 local root={Position=spawn.Position,Parent=true,SetNetworkOwner=function()end,SetNetworkOwnershipAuto=function()end}
 local h={Parent=true,Health=100}
 function h:ChangeState()if self.SeatPart then self.SeatPart.Occupant=nil end;self.SeatPart=nil end
 local char={Parent=true,DescendantAdded=signal(),GetDescendants=function()return {}end,
 FindFirstChild=function()return root end,FindFirstChildOfClass=function()return h end,PivotTo=function()end}
 local p={Parent=players,Character=char,CharacterAdded=signal(),CharacterRemoving=signal(),
 GetAttribute=function(_,k)return a[k]end,SetAttribute=function(_,k,v)local old=a[k];a[k]=v;if old~=v and signals[k]then signals[k]:Fire()end end,
 GetAttributeChangedSignal=function(_,k)if not signals[k]then signals[k]=signal()end;return signals[k]end}
 players.PlayerAdded:Fire(p)
 return p,h
end
check(attrs.LobbyDrivePlayerCount==0,'empty service includes no demo/display racers')
local users={}
for i=1,4 do
 local p,h=newPlayer();users[i]=p
 check(service.enter(p)==true,'production seat admission '..i)
 check(h.SeatPart and p:GetAttribute('LobbyDriveActive')==true,'confirmed real service seat state')
 check(attrs.LobbyDrivePlayerCount==i,'published number equals active service karts')
end
for i=1,4 do for j=i+1,4 do check(frames[i].Position~=frames[j].Position,'independent start slots')end end
local observer=newPlayer()
check(attrs.LobbyDrivePlayerCount==4 and not observer:GetAttribute('LobbyDriveActive'),'late join preserves existing four drivers')
users[1]:SetAttribute('KDMRoutePending','RACE_LAUNCH')
check(attrs.LobbyDrivePlayerCount==3 and not karts[1].Parent,'race launch removes kart and count')
users[2].CharacterRemoving:Fire()
check(attrs.LobbyDrivePlayerCount==2 and not karts[2].Parent,'character removal cleans independently')
players.PlayerRemoving:Fire(users[3])
check(attrs.LobbyDrivePlayerCount==1 and not karts[3].Parent,'departure cleans independently')
check(service.stop(users[4],'exit',true)==true,'normal exit succeeds')
check(attrs.LobbyDrivePlayerCount==0 and not karts[4].Parent,'all four cleaned without leftovers')
local old=#karts
check(service.enter(users[4])==true and #karts==old+1 and attrs.LobbyDrivePlayerCount==1,'same user can re-enter after settled exit')
service.stop(users[4],'end',false)
check(attrs.LobbyDrivePlayerCount==0,'final cleanup')
print(string.format('PASS %d production shared-HUB service admission/slots/late-join/route/departure/re-entry checks (mock Players and physics)',n))
