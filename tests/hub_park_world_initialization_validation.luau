-- G2-R1: real world/controller startup under existing deterministic Roblox mocks.
local fs,luau,rb=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox')
local configLoader=require('./helpers/gameplay_config')
local worldSource=fs.readFile('src/server/PrototypeWorld.luau')
local predicate=assert(worldSource:match('(function PrototypeWorld.isHubParkPreview.-)\nfunction PrototypeWorld.start'))
local worldFixture=fs.readFile('tests/race_item_validation.luau')
local worldPrefix=worldFixture:sub(1,assert(worldFixture:find('\nworld.start()',1,true))-1)
worldPrefix=worldPrefix:gsub('require%("%./helpers/gameplay_config"%)','CONFIG_LOADER')
local catalogAt=assert(worldPrefix:find('local world=load(',1,true))
worldPrefix=worldPrefix:sub(1,catalogAt-1)..'modules.TrackCatalog=luau.load(fs.readFile("src/shared/TrackCatalog.luau"),{environment=environment})()\nload("src/shared/HubParkRuntimePolicy.luau",shared,"HubParkRuntimePolicy")\n'..worldPrefix:sub(catalogAt)
local scenarios={
 {name='default HUB',studio=true,role='HUB',suppressed=false},
 {name='OFF HUB',studio=true,role='HUB',flag=false,suppressed=false},
 {name='ON HUB',studio=true,role='HUB',flag=true,suppressed=true},
 {name='unknown published HUB',studio=false,role='HUB',flag=true,suppressed=false},
 {name='approved production HUB',studio=false,role='HUB',flag=true,gameId=10768420544,placeId=127925465904803,suppressed=true},
 {name='production OFF HUB',studio=false,role='HUB',flag=false,gameId=10768420544,placeId=127925465904803,suppressed=false},
 {name='approved staging HUB',studio=false,role='HUB',flag=true,gameId=10772198697,placeId=106553302629620,suppressed=true},
 {name='wrong staging Place',studio=false,role='HUB',flag=true,gameId=10772198697,placeId=1,suppressed=false},
 {name='Studio Bot Test',studio=true,role='HUB',flag=true,bot=true,trackId='Track01Race',suppressed=false},
}
for _,trackId in {'Track01','Track01Race','Track02','Track03'} do
 table.insert(scenarios,{name='RACE '..trackId,studio=true,role='RACE',flag=true,trackId=trackId,suppressed=false})
end
local checks=0
for _,s in scenarios do
 local scenario=[[
services.Workspace:SetAttribute('KDMServerRole',SCENARIO.role)
services.Workspace:SetAttribute('HubParkV1Enabled',SCENARIO.flag)
services.Workspace:SetAttribute('KDMEnableRaceBot',SCENARIO.bot)
services.RunService.studio=SCENARIO.studio
environment.game.GameId=SCENARIO.gameId;environment.game.PlaceId=SCENARIO.placeId
local calls=0
local oldBuild=modules.TrackBuilder.build
modules.TrackBuilder.build=function(prototype,track,...)
 calls+=1;check(track.Id==(SCENARIO.trackId or 'Track01'),'selected official track preserved')
 return oldBuild(prototype,track,...)
end
world.start(if SCENARIO.trackId then {trackId=SCENARIO.trackId} else nil)
check(world.isHubParkPreview()==SCENARIO.suppressed,'strict preview predicate')
check(calls==(if SCENARIO.suppressed then 0 else 1),'official builder invocation')
local prototype=services.Workspace.Prototype
check((prototype:FindFirstChild('TestTrack')==nil)==SCENARIO.suppressed,'no dummy official track')
check(prototype:FindFirstChild('PlayerSpawn')~=nil,'common PlayerSpawn retained')
check(prototype:FindFirstChild('Kart')~=nil,'common kart retained')
check(services.ReplicatedStorage:FindFirstChild('KartControl')~=nil,'common control remote retained')
check(type(world.acquireKartContext)=='function' and type(world.createKartContext)=='function','vehicle APIs retained')
local ctx=assert(world.acquireKartContext(player,CF.new(0,2,900),'Kart05'))
check(world.getKartContext(player)==ctx,'common context acquisition works')
world.releaseKartContext(player)
check(world.getKartContext(player)==nil,'common context release works')
return count
]]
 checks+=luau.load(worldPrefix..scenario,{debugName=s.name,environment={SCENARIO=s,CONFIG_LOADER=configLoader}})()
end
-- Exercise real RaceController startup with NO TestTrack. No dummy geometry or
-- track-binding warning is allowed; player attributes and RaceControl must exist.
local raceFixture=fs.readFile('tests/persistent_room_race_validation.luau')
local racePrefix=raceFixture:sub(1,assert(raceFixture:find('local readyRoster',1,true))-1)
racePrefix=racePrefix:gsub('require%("%./helpers/gameplay_config"%)','CONFIG_LOADER')
local scenario=[[
local PrototypeWorld=modules.PrototypeWorld
local RunService,Workspace=services.RunService,services.Workspace
local ReplicatedStorage=services.ReplicatedStorage
local game=environment.game
load('src/shared/HubParkRuntimePolicy.luau',shared,'HubParkRuntimePolicy')
local require=function(module)return assert(modules[module.Name],module.Name)end
]]..predicate..[[
Workspace:SetAttribute('KDMServerRole','HUB');Workspace:SetAttribute('HubParkV1Enabled',true)
track:Destroy()
local warnings=0;environment.warn=function()warnings+=1 end
check(race.start(),'preview RaceController starts without official geometry')
check(warnings==0,'no missing track initialization warning')
check(services.ReplicatedStorage:FindFirstChild('RaceControl')~=nil,'RaceControl initialized')
check(a:GetAttribute('RaceState')=='GARAGE' and a:GetAttribute('RaceCheckpointCount')==0,'Garage defaults without track')
local late=addPlayer('Late',99,1);services.Players.PlayerAdded:Fire(late)
check(late:GetAttribute('RaceState')=='GARAGE','late player common attributes initialized')
a:SetAttribute('RaceState','PRE_RACE');services.RunService.Heartbeat:Fire(.1)
check(sessionType.active():count()==0,'static preview cannot admit official racers')
check(warnings==0 and not prototype:FindFirstChild('TestTrack'),'no hidden official track creation')
return count
]]
checks+=luau.load(racePrefix..scenario,{environment={CONFIG_LOADER=configLoader}})()
-- Execute the exact Garage dependency guard with a fail-fast absent-track wait.
local garage=fs.readFile('src/server/GarageController.luau')
local guard=assert(garage:match('(\tif not %(PrototypeWorld.isHubParkPreview.-)\n\tlocal ground ='))
for _,s in scenarios do
 local waits=0
 luau.load(guard,{environment={PrototypeWorld={isHubParkPreview=function()return s.suppressed end},
  prototype={WaitForChild=function(_,name)assert(name=='TestTrack');waits+=1 end}}})()
 assert(waits==(if s.suppressed then 0 else 1),s.name..' Garage track wait');checks+=1
end
print('PASS: '..checks..' G2 world/controller/Garage startup checks; '..#scenarios..' role/flag/Bot/staging/track scenarios')
