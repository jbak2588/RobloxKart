local fs,luau=require("@lune/fs"),require("@lune/luau")
local titles=require("./helpers/lobby_title_modules")
local extra=[=[
local serial=0
local function make(kind,legacy)
 serial+=1;local id="title-"..serial
 directory:createPersistent({id=id,matchId="match-"..serial,hostUserId=1,hostName="Racer1",trackId="Track01Race",maxPlayers=4,
 lobbyTitleKind=kind,lobbyTitle=if kind=="DEFAULT" then "Racer1's Lobby" else "Fixed Title"},"access","private")
 if legacy then map.values[id].lobbyTitleKind=nil;map.values[id].lobbyTitle=nil end
 for index=1,2 do
  directory:stage(id,member(index),"token"..index,"Track01Race")
  directory:confirmArrival(id,index,"token"..index,"job")
 end
 return id
end
local function verify(id,kind,host)
 local record=assert(directory:get(id));local public=directory:display(record)
 local expected=if kind=="DEFAULT" then "Racer"..host.."'s Lobby" else "Fixed Title"
 check(record.hostUserId==host and record.lobbyTitle==expected,"stored host/title")
 check(public.lobbyTitle==expected and public.lobbyTitleKind==kind,"public host/title")
 check(public.reservedServerAccessCode==nil,"title projection keeps private code hidden")
end
for _,kind in {"DEFAULT","PRESET","CUSTOM"} do
 local id=make(kind);directory:removeStaged(id,1);verify(id,kind,2)
 id=make(kind);directory:startRound(id,1);directory:leaveMember(id,1);verify(id,kind,2)
 id=make(kind);directory:startRound(id,1)
 local record=directory:get(id);directory:raceState(id,record.matchId,"RACING",2)
 directory:queue(id,member(3));verify(id,kind,1)
 directory:raceState(id,record.matchId,"ROUND_COMPLETE",2)
 directory:nextStaging(id,{member(2)});verify(id,kind,2)
 check(directory:get(id).stagedMembers[2].userId==3,"queue promoted into same titled lobby")
 -- Legacy nonpersistent waiting + claimNext are retained compatibility paths.
 serial+=1;id="classic-"..serial
 directory:create({id=id,trackId="Track01Race",hostUserId=1,hostName="Racer1",ownerJobId="hub-a",maxPlayers=4,members={member(1),member(2)},lobbyTitleKind=kind,lobbyTitle="Fixed Title"})
 directory:leaveWaiting(id,1);verify(id,kind,2)
 directory:waiting({id=id,ownerJobId="hub-a",hostUserId=2,hostName="Racer2",members={member(2)}});verify(id,kind,2)
 local launched=directory:initialLaunch(id,2,"classic-match","access","private")
 directory:raceState(id,"classic-match","ROUND_COMPLETE",1)
 directory:claimNext(id,"classic-match","classic-next","access","private",{member(4)});verify(id,kind,4)
end
local legacy=make("DEFAULT",true)
check(directory:display(directory:get(legacy)).lobbyTitle=="Racer1's Lobby","legacy missing fields displayed default")
directory:removeStaged(legacy,1);verify(legacy,"DEFAULT",2)
print("PASS: "..count.." directory title lifecycle/host transfer/legacy/queue/rematch contracts")
]=]
luau.load(fs.readFile("tests/active_match_directory_validation.luau").."\n"..extra,{environment={require=function(path)
 if path=="./helpers/lobby_title_modules" then return titles end
 return require(path)
end}})()
