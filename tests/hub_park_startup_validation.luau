local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local policy=luau.load(fs.readFile('src/shared/HubParkRuntimePolicy.luau'))()
local checks=0;local function check(v,label)assert(v,label);checks+=1 end
local ws=rb.Instance.new('Workspace');ws:SetAttribute('KDMServerRole','HUB');ws:SetAttribute('HubParkV1Enabled',true)
check(policy.enabled(ws,false,10772198697,106553302629620),'approved exact staging pair')
for _,ids in {{10768420544,127925465904803},{10772198697,1},{1,106553302629620},{0,0},{10768420544,106553302629620}}do
 check(not policy.enabled(ws,false,ids[1],ids[2]),'deny production/unapproved IDs')
end
for _,role in {'RACE','UNKNOWN'}do ws:SetAttribute('KDMServerRole',role)
 check(not policy.enabled(ws,true,0,0)and not policy.enabled(ws,false,10772198697,106553302629620),'non HUB isolated')end
ws:SetAttribute('KDMServerRole','HUB');ws:SetAttribute('KDMEnableRaceBot',true)
check(not policy.enabled(ws,true,0,0),'Bot harness excluded');ws:SetAttribute('KDMEnableRaceBot',false)
local storage=rb.Instance.new('ServerStorage')
local shared={WaitForChild=function(_,n)return n end}
local studio=true
local game={GameId=0,PlaceId=0,GetService=function(_,n)
 if n=='ReplicatedStorage'then return {WaitForChild=function()return shared end}end
 if n=='RunService'then return {IsStudio=function()return studio end}end
 if n=='ServerStorage'then return storage end
 error(n)
end}
local startup=luau.load(fs.readFile('src/server/HubParkStartup.luau'),{environment={game=game,workspace=ws,
 Instance=rb.Instance,require=function()return policy end}})()
local function child(parent,name,class)local v=rb.Instance.new(class or 'Model');v.Name=name;v.Parent=parent;return v end
local proto=child(ws,'Prototype','Folder');local hub=child(ws,'KDMHub')
local lobby=child(hub,'OriginalGarage');local spawn=child(hub,'HubSpawn','SpawnLocation')
local old=child(proto,'TestTrack');local oval=child(hub,'LobbyFrontTestDriveZone')
local rookie=child(hub,'HubParkRookieLoopG2');local duplicate=child(hub,'HubParkRookieLoopG2')
ws:SetAttribute('HubParkV1Enabled',false);startup.prepare()
check(old.Parent==proto and oval.Parent==hub and rookie.Parent==hub,'OFF does not move serialized geometry')
ws:SetAttribute('HubParkV1Enabled',true);startup.prepare()
local archive=storage:FindFirstChild('HubParkStartupArchive')
check(archive and #archive:GetChildren()==4,'all serialized copies archived outside Workspace')
check(not proto:FindFirstChild('TestTrack')and not hub:FindFirstChild('LobbyFrontTestDriveZone')and not hub:FindFirstChild('HubParkRookieLoopG2'),'fresh generation has no legacy/new duplicates')
check(lobby.Parent==hub and spawn.Parent==hub,'F60 Lobby and HubSpawn retained')
check(old:GetAttribute('G2ArchivedFrom')~=nil and old.Parent==archive,'recoverable archive, no Destroy')
startup.prepare();check(#storage:GetChildren()==1,'empty repeat creates no archive')
local live=child(hub,'LobbyKart_1');live:SetAttribute('LobbyKart',true)
check(not pcall(startup.prepare),'reject active-world cleanup');live.Parent=nil
studio=false;game.GameId=10768420544;game.PlaceId=127925465904803
old.Parent=proto;startup.prepare();check(old.Parent==proto,'production never archived')
game.GameId=10772198697;game.PlaceId=106553302629620;startup.prepare()
check(old.Parent~=proto and old.Parent.Parent==storage,'approved published staging uses same startup segregation')
-- Inspect the final build only; no source asset inventory is repeated.
print('PASS: '..checks..' G2-R2 staging isolation/serialized startup preservation checks')
