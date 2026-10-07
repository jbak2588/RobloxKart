-- Production V2 catalog, room directory, payload/arrival and real-course 4-racer lifecycle.
-- Deterministic transport fixtures are not Roblox Players or real Teleport evidence.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local configLoader = require("./helpers/gameplay_config")
local process = require("@lune/process")
local catalog = luau.load(fs.readFile("src/shared/TrackCatalog.luau"), {environment={CFrame=rb.CFrame}})()
local geometry = luau.load(fs.readFile("src/shared/TrackGeometry.luau"), {environment={Vector3=rb.Vector3,Vector2=rb.Vector2}})()
local serde=require("@lune/serde")
local checks = 0
local function check(value,label) assert(value,label);checks+=1 end
local v2=catalog.Entries.Track02
check(v2.MatchType=="PUBLIC_RACE" and v2.MinPlayers==1 and v2.MaxPlayers==4 and v2.TargetLaps==2,"V2 public 1..4 / 2 laps")
check(v2.GeometryId=="PrototypeCircuitV2" and v2.PreviewImageAssetId=="rbxassetid://104449535838897","production identity/image unchanged")
for _,id in {"Track01","Track01Race","Track03"} do
 local track=catalog.Entries[id]
 check(track.TargetLaps==(if id=="Track01" then 1 else 2)
  and track.MaxPlayers==(if id=="Track01" then 1 else 4)
  and track.MatchType==(if id=="Track01" then "SOLO_PRACTICE" else "PUBLIC_RACE"),"existing track "..id)
end
local course=geometry.getCourse(geometry.getDefinition(v2.GeometryId))
check(#v2.GridSlots==4,"four existing V2 grids")
for i,frame in v2.GridSlots do
 check(frame.LookVector:Dot(course.StartTangent)>.99,"grid forward "..i)
 local lateral=math.abs((frame.Position-course.StartPosition):Dot(rb.Vector3.new(-course.StartTangent.Z,0,course.StartTangent.X)))
 check(lateral+4<geometry.getDefinition(v2.GeometryId).RoadWidth*.5,"full kart road clearance "..i)
 for j=i+1,4 do
  local delta=v2.GridSlots[j].Position-frame.Position
  check(math.abs(delta.X)>=8 or math.abs(delta.Z)>=12,"grid envelopes do not overlap "..i.."/"..j)
 end
end
local checkpoint="dd739b88296b360ea21c889b9213dcaf103488d4"
-- K1 authorizes TrackBuilder presentation changes; its generated road/gate/
-- barrier equivalence and Hard output are tested by track_visual_standard_validation.
-- K1A adds only SPEED.Straight; existing balance sections are exactly compared
-- against the K1 checkpoint by straight_speed_validation.
for _,path in {"src/shared/TrackGeometry.luau",
 "src/shared/RaceItemConfig.luau","src/server/RaceLoadout.luau",
 "src/server/RaceItemController.luau","tests/fixtures/garage_phase1b_geometry.json","tests/fixtures/kart_v2_geometry.json"} do
 local baseline=process.exec("git",{"show",checkpoint..":"..path})
 check(baseline.ok and baseline.stdout:gsub("\r\n","\n")==fs.readFile(path):gsub("\r\n","\n"),"checkpoint preserved "..path)
end
local fixturePath="tests/fixtures/garage_phase1b_geometry.json"
local previousFixture=process.exec("git",{"show",checkpoint..":"..fixturePath})
assert(previousFixture.ok)
local previousRows=serde.decode("json",previousFixture.stdout)
local currentRows=serde.decode("json",fs.readFile(fixturePath))
assert(#currentRows==52 and #previousRows==52,"52 geometry snapshots")
for i,row in previousRows do check(serde.encode("json",row)==serde.encode("json",currentRows[i]),"unchanged geometry snapshot "..i)end
print("PASS: 52/52 Phase 1B geometry fixture preservation (historical snapshots; current Hub layout tested separately)")
local modules={TrackCatalog=catalog,DriverCatalog={Entries={Driver01={}}},KartCatalog={Entries={Kart05={}}}}
local env={game={GetService=function() return {WaitForChild=function(self) return self end} end},
 require=function(m) return modules[m.Name] end}
env.game.GetService=function() return {WaitForChild=function(_,name) return {WaitForChild=function(_,key) return {Name=key} end} end} end
local payload=luau.load(fs.readFile("src/server/RaceLaunchPayload.luau"),{environment=env})()
modules.RaceLaunchPayload=payload
modules.RaceConfig=luau.load(fs.readFile("src/shared/RaceConfig.luau"))()
env.script={Parent={WaitForChild=function(_,name)return{Name=name}end}}
modules.RaceMode=luau.load(fs.readFile("src/shared/RaceMode.luau"),{environment=env})()
local arrival=luau.load(fs.readFile("src/server/RaceArrivalPlan.luau"),{environment=env})()
local members={}
for n=1,5 do
 table.insert(members,{userId=1000+n,driverId="Driver01",kartId="Kart05",admissionToken="token"..n})
 local p=payload.buildMatch("j1-match-123456","j1-room-123456",members,"Track02")
 check((p~=nil)==(n<=4),"human payload capacity "..n)
 if p then
  check(p.trackId=="Track02" and #p.participantUserIds==n,"V2 payload identity/count "..n)
  for i=1,n do
   check(p.participantUserIds[i]==1000+i,"roster IDs retained "..n.."/"..i)
   local plan=arrival.forPlayer(p,1000+i)
   check(plan and plan.trackId=="Track02" and plan.maxPlayers==4 and plan.gridSlot==i and plan.mode=="RACE","reserved arrival plan "..n.."/"..i)
  end
  check(arrival.forPlayer(p,1009)==nil,"unlisted arrival rejected "..n)
 end
end
check(payload.buildSolo("j1-match-123456",{UserId=1001},"Track02","Driver01","Kart05")==nil,"V2 direct solo launch rejected")
-- Shared existing Room service fixture: replace its stub catalog with the production catalog.
local room=fs.readFile("tests/match_room_service_validation.luau")
local roomCut=assert(room:find("browse(a); action(a,",1,true))
room=room:sub(1,roomCut-1)
room=room:gsub('local Service = luau.load', 'modules.TrackCatalog=REAL_CATALOG\nlocal Service = luau.load',1)
room..=[=[
browse(a,"Track02");action(a,"Create")
local roomId=launches[1].payload.roomId
check(directory:get(roomId).trackId=="Track02" and directory:get(roomId).maxPlayers==4,"V2 persistent public room")
directory:confirmArrival(roomId,a.UserId,directory:get(roomId).stagedMembers[1].admissionToken,"v2-job")
check(directory:addBot(roomId,{botId="Bot01",name="KDM Rookie [BOT]",kartId="Kart01",gridSlot=4})==nil,"V2 Base-only Bot rejected with three free slots")
for _,p in {b,c,d} do
 browse(p,"Track02");action(p,"Join",roomId)
 local record=directory:get(roomId)
 check(launches[#launches].payload.trackId=="Track02","V2 join launch identity")
 for _,m in record.stagedMembers do if m.userId==p.UserId then directory:confirmArrival(roomId,p.UserId,m.admissionToken,"v2-job") end end
end
check(directory:display(directory:get(roomId)).count==4,"four admitted roster memberships (transport fixture)")
browse(e,"Track02");local before=#launches;action(e,"Join",roomId)
check(#launches==before,"fifth human rejected at admission")
print("PASS: "..count.." V2 public room checks (MemoryStore/Teleport mocked)")
]=]
luau.load(room,{environment={REAL_CATALOG=catalog,require=function(path) return require(path) end},debugName="v2_public_room"})()
-- Existing static card test executes the production GUI and real catalog, including ROOMS activation.
local function run(source,name)
 luau.load(source,{debugName=name,environment={require=function(path)
  if path=="./helpers/gameplay_config" then return configLoader end
  return require(path)
 end}})()
end
run(fs.readFile("tests/track_h3_flow_validation.luau"),"v2_rooms_ui")
-- Reuse the actual sampled-course controller fixture on V2, preserving checkpoint integrity and results/DNF/Rematch.
local race=fs.readFile("tests/track03_four_player_validation.luau")
race=race:gsub("Track03","Track02"):gsub("HardCircuitV1","PrototypeCircuitV2")
race=race:gsub("actual Hard course","actual V2 course")
run(race,"v2_four_racer_production_course")
run(fs.readFile("tests/lap_item_refill_validation.luau"),"v2_two_lap_item_refill")
print("PASS: "..checks.." V2 contract/grid/payload/preservation checks plus production room/UI/4-racer integration")
