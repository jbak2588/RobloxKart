local fs,luau,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/serde')
local source=fs.readFile('src/server/LobbyTestDriveService.luau'):gsub('\r\n','\n')
local n=0;local function check(v,label)assert(v,label);n+=1 end
local function signal()
 local list={};return {Connect=function(_,f)local c={live=true};function c:Disconnect()self.live=false end;table.insert(list,{c,f});return c end,
 Fire=function(_,p)for _,v in list do if v[1].live then v[2](p)end end end}
end
local registered={Default=true,RacerKart=true,RacerDriver=true};local matrix={}
local function key(a,b)local p={a,b};table.sort(p);return table.concat(p,'/')end
local physics={IsCollisionGroupRegistered=function(_,name)return registered[name]==true end,
 RegisterCollisionGroup=function(_,name)registered[name]=true end,
 CollisionGroupSetCollidable=function(_,a,b,v)matrix[key(a,b)]=v end}
local function collides(a,b)local v=matrix[key(a,b)];return v~=false end
-- Execute the production collision/binding functions, not a reimplementation.
local first=assert(source:find('function Service.configureCollision()',1,true))
local last=assert(source:find('local function inside(',first,true))
local code='local Service,bindings,started={},{},true\n'..source:sub(first,last-1)..
 '\nreturn {configure=Service.configureCollision,bind=bindCharacter,set=setParkDriver,restore=restoreCharacter}'
local api=luau.load(code,{environment={Physics=physics}})()
api.configure();api.configure()
check(registered.ParkDriver,'idempotent Park group registration')
for _,other in {'ParkDriver','LobbyAvatar','LobbyKart','LobbyBoundary','RacerKart','RacerDriver'}do
 check(not collides('ParkDriver',other),'Park driver cannot transfer contact impulse to '..other)
end
check(collides('ParkDriver','Default'),'driver still collides with ordinary world')
check(collides('LobbyKart','Default')and collides('LobbyKart','LobbyBoundary'),'kart floor and rim collisions retained')
check(collides('LobbyAvatar','LobbyAvatar'),'walking Hub avatar contact unchanged')
check(collides('RacerDriver','RacerDriver'),'official driver rules not written by Park configuration')
local function part(group)return {Parent=true,CollisionGroup=group,CanCollide=true,IsA=function(_,c)return c=='BasePart'end}end
local function rig()
 local parts={part('Default'),part('CustomAvatar')};local added=signal()
 return {GetDescendants=function()return parts end,DescendantAdded=added},parts,added
end
local a,ap,added=rig();local b,bp=rig();local pa,pb={Character=a},{Character=b}
api.bind(pa,a);api.bind(pb,b)
check(ap[1].CollisionGroup=='LobbyAvatar'and bp[1].CollisionGroup=='LobbyAvatar','binding alone does not isolate walking/legacy avatars')
api.set(pa,true);api.set(pb,true)
for _,p in ap do check(p.CollisionGroup=='ParkDriver'and p.CanCollide,'all body parts assigned without disabling world collisions')end
check(not collides(ap[1].CollisionGroup,bp[1].CollisionGroup),'two seated Park drivers have no avatar contact')
local accessory=part('AccessoryOriginal');added:Fire(accessory)
check(accessory.CollisionGroup=='ParkDriver','late accessory handles inherit active Park isolation')
api.set(pa,false)
check(ap[1].CollisionGroup=='LobbyAvatar'and accessory.CollisionGroup=='LobbyAvatar','exit returns to Hub group')
api.set(pa,true);api.set(pa,true);api.restore(pa)
check(ap[1].CollisionGroup=='Default'and ap[2].CollisionGroup=='CustomAvatar'and accessory.CollisionGroup=='AccessoryOriginal','teardown restores every original group after repeated entry')
local detached=part('Detached');added:Fire(detached)
check(detached.CollisionGroup=='Detached','teardown disconnects descendant listener')
local new,np=rig();pa.Character=new;api.bind(pa,new);api.set(pa,true)
check(np[1].CollisionGroup=='ParkDriver'and ap[1].CollisionGroup=='Default','respawn never rewrites old avatar')
pa.Character=a;api.set(pa,false)
check(np[1].CollisionGroup=='ParkDriver','stale character cleanup cannot rewrite replacement binding')
pa.Character=new;api.restore(pa);api.restore(pa)
check(np[1].CollisionGroup=='Default','cleanup is idempotent')
check(source:find('if timeTrial then setParkDriver(player,true) end',1,true)~=nil,'only Rookie timeTrial entry activates Park group')
check(source:find('RunService.Heartbeat:Wait();RunService.Heartbeat:Wait()\n setParkDriver(player,false)',1,true)~=nil,'exit retains isolation until weld teardown has settled')
local manifest=serde.decode('json',fs.readFile('tests/fixtures/source_freeze_release_f5ebec8.json'))
local freeze=require('./helpers/release_source_freeze')
check(freeze.accepts(manifest,'src/server/LobbyTestDriveService.luau',source),'approved collision-only exact source')
check(not freeze.accepts(manifest,'src/server/LobbyTestDriveService.luau',source:gsub('"ParkDriver","ParkDriver",false','"ParkDriver","ParkDriver",true',1)),'reject regression restoring driver-to-driver collision')
check(not freeze.accepts(manifest,'src/server/LobbyTestDriveService.luau',source..'\n-- unexpected edit'),'reject unrelated source mutation')
print('PASS: '..n..' Park driver collision matrix, two-avatar binding, accessory, lifecycle and mutation checks')
