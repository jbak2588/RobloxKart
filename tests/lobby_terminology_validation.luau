local fs,luau,rb,process=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox"),require("@lune/process")
local n=0
local function check(v,l)assert(v,l);n+=1 end
local current=luau.load(fs.readFile("src/shared/TrackCatalog.luau"),{environment={CFrame=rb.CFrame}})()
local old=process.exec("git",{"show","f21c65370079033c72602e63cc40b79306e99236:src/shared/TrackCatalog.luau"})
check(old.ok,"review baseline available")
local baseline=luau.load(old.stdout,{environment={CFrame=rb.CFrame}})()
local names={Track01="Practice Track",Track01Race="Base Track",Track02="Prototype V2 Track",Track03="KDM Hard Track"}
local function equal(a,b)
 if type(a)~="table" or type(b)~="table" then return a==b end
 for k,v in a do if not equal(v,b[k])then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end
for id,name in names do
 check(current.Entries[id].DisplayName==name,"exact name "..id)
 local entry=table.clone(current.Entries[id]);entry.DisplayName=baseline.Entries[id].DisplayName
 if id=="Track01" then
  check(entry.GeometryId=="PracticeFigure8V1" and entry.TargetLaps==2,"P1 Practice-only geometry/laps")
  for _,key in {"GeometryId","TargetLaps","GridSlots"}do entry[key]=baseline.Entries[id][key]end
 end
 check(equal(entry,baseline.Entries[id]),"all non-display catalog fields unchanged "..id)
end
local source=fs.readFile("src/client/MatchRoomUiController.luau")
for _,text in {"RACE LOBBIES","CREATE LOBBY","ENTER LOBBY","CREATING LOBBY...","JOINING LOBBY...","LOBBY STATUS UPDATING...","NO ACTIVE LOBBIES","CREATE OR JOIN A 1–%d RACER LOBBY"}do
 check(source:find(text,1,true)~=nil,"exact visible mapping "..text)
end
check(not source:find('"RACE ROOMS"',1,true)and not source:find('"CREATE ROOM"',1,true),"obsolete browser terms absent")
local server=fs.readFile("src/server/MatchRoomService.luau")
local titles=require("./helpers/lobby_title_modules")
check(titles.service.ERROR=="LOBBY NAME COULDN'T BE USED - TRY ANOTHER","player-facing name filter error")
for errorText in server:gmatch('errorTo%([^\n]+')do check(not errorText:find('"ROOM',1,true),"user error terminology")end
check(server:find('remote.Name = "MatchRoomControl"',1,true)~=nil,"remote identity preserved")
check(fs.readFile("src/server/ActiveMatchDirectory.luau"):find('"KDM_ActiveBaseRooms_v1"',1,true)~=nil,"directory key preserved")
check(fs.readFile("src/server/RoomSocialDirectory.luau"):find('"KDM_RoomInvites_v1"',1,true)~=nil,"invite key preserved")
local g=luau.load(fs.readFile("src/client/HubGuidanceState.luau"))()
local state=g.new();g.confirmed(state,"Track03")
check(g.nextAction(state)=="ROOMS","internal action token preserved")
check(g.presentation(state,rb.Vector2.new(844,390),"GARAGE",false,"",false).button=="LOBBIES","display separates action token")
print("PASS: "..n.." exact terminology / catalog parity / internal protocol contracts")
