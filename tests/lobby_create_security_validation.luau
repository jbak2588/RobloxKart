local fs,luau=require("@lune/fs"),require("@lune/luau")
local fixture=fs.readFile("tests/match_room_service_validation.luau")
local extra=[=[
failLaunch=false
local injected,filtered="PRIVATE_RAW_SENTINEL","Public Racers"
local onFilter=function()end
local output=filtered
local failed=false
local filterCalls=0
services.TextService={FilterStringAsync=function(_,text,userId)
 filterCalls+=1;check(text==injected or utf8.len(text)==32,"normalized custom only")
 onFilter();if failed then error("test filter failure")end
 return {GetNonChatStringForBroadcastAsync=function()return output end}
end}
local function fresh(id) local p=racer(id);p.Name="Account"..id;browse(p);return p end
local function recordFor(p)
 for _,entry in roomMap.values do if entry.hostUserId==p.UserId then return entry end end
end
for index,bad in {"####","",false} do
 local p=fresh(100+index);output=bad;failed=bad==false
 local before=reservations;action(p,"Create","CUSTOM",injected)
 check(reservations==before and not recordFor(p),"failed filter never reserves/persists")
 check(latest(p,"Error")==titleModules.service.ERROR,"safe failure message")
 action(p,"Create","DEFAULT");check(reservations==before+1,"failed create releases guard")
end
failed=false;output=filtered
for index,payload in {{"PRESET","Malicious"},{"CUSTOM",string.rep("界",33)},{"CUSTOM",string.char(255)},{"CUSTOM",{}},{"invalid","text"}} do
 local p=fresh(110+index);local before=reservations
 action(p,"Create",payload[1],payload[2]);check(reservations==before,"malicious request no reserve")
 action(p,"Create");check(reservations==before+1,"bad input releases guard")
end
local p=fresh(120);local before=reservations
onFilter=function()action(p,"Create","DEFAULT")end
action(p,"Create","CUSTOM",injected);onFilter=function()end
check(reservations==before+1,"yield duplicate create reserved once")
local record=assert(recordFor(p))
check(record.lobbyTitleKind=="CUSTOM" and record.lobbyTitle==filtered,"persist only broadcast filtered")
check(not require("@lune/serde").encode("json",record):find(injected,1,true),"raw absent in record")
local observer=fresh(121)
local found=false
for _,entry in latest(observer,"Snapshot").rooms do if entry.id==record.roomId then
 found=true;check(entry.lobbyTitle==filtered and entry.lobbyTitleKind=="CUSTOM","browser projected title")
end end
check(found,"custom lobby visible")
social:sendInvite(observer.UserId,record)
local invite=social:getInvite(observer.UserId)
check(invite.lobbyTitle==filtered and invite.lobbyTitleKind=="CUSTOM","invite title identity")
for index,change in {
 function(q)q:SetAttribute("SelectedTrackId","Track03")end,
 function(q)q.Parent=nil end,
 function(q)q:SetAttribute("RaceState","RACING")end,
} do
 local q=fresh(130+index);local prior=reservations;onFilter=function()change(q)end
 action(q,"Create","CUSTOM",injected);onFilter=function()end
 check(reservations==prior and not recordFor(q),"stale yield request rejected before reserve")
 q.Parent=players;q:SetAttribute("RaceState","GARAGE");browse(q)
 action(q,"Create");check(reservations==prior+1,"stale request releases guard")
end
local q=fresh(140);action(q,"Create","CUSTOM",string.rep("🚗",32))
check(recordFor(q).lobbyTitle==filtered,"32 Unicode codepoints accepted")
for index,id in titleModules.catalog.Order do
 local q=fresh(150+index);action(q,"Create","PRESET",id)
 check(recordFor(q).lobbyTitle==titleModules.catalog.Presets[id],"actual create preset")
end
local fallback=fresh(160);fallback.DisplayName="";action(fallback,"Create")
local fallbackRoom=assert(recordFor(fallback))
check(fallbackRoom.lobbyTitle=="Account160's Lobby" and fallbackRoom.stagedMembers[1].name=="Account160","default creator/account fallback persisted")
local successor=fresh(161);successor.DisplayName="";action(successor,"Join",fallbackRoom.roomId)
directory:removeStaged(fallbackRoom.roomId,160)
check(directory:get(fallbackRoom.roomId).lobbyTitle=="Account161's Lobby","host transfer account fallback")
print("PASS: "..count.." production create, reservation, filter, guard, stale request and title propagation checks")
]=]
local titles=require("./helpers/lobby_title_modules")
luau.load(fixture.."\n"..extra,{environment={require=function(path)
 if path=="./helpers/lobby_title_modules" then return titles end
 return require(path)
end}})()
