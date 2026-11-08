local fs, luau = require("@lune/fs"), require("@lune/luau")
local gameplayConfig = require("./helpers/gameplay_config")
local harness = fs.readFile("tests/track03_four_player_validation.luau")
local prefix = harness:sub(1, assert(harness:find('local geometry=modules.TrackGeometry', 1, true)) - 1)
luau.load(prefix .. [====[
local G = load("src/shared/EliphantGeometry.luau", shared, "EliphantGeometry")
local roadPolicy = load("src/shared/EliphantRoadPolicy.luau", shared, "EliphantRoadPolicy")
child(server, "ModuleScript", "EliphantTrackBuilder")
modules.EliphantTrackBuilder = roadPolicy
local prototype = child(services.Workspace, "Folder", "Prototype")
local track = child(prototype, "Model", "TestTrack")
track:SetAttribute("TrackId", "EliphantNose")
track:SetAttribute("GeometryId", "EliphantNoseR2")
track:SetAttribute("CheckpointCount", #G.Checkpoints)
local road = child(child(track, "Folder", "Road"), "Part", "Domain")
road:SetAttribute("EliphantRoad", true)
local triggers = child(track, "Folder", "RaceTriggers")
local function gate(spec, index)
 local g = child(triggers, "Part", if index then "Checkpoint" .. index else "StartFinish")
 local pos = spec.P + V.yAxis * 5
 g.CFrame = lookAt(pos, pos + spec.D)
 g.Size = V.new(spec.W, 12, if index then 120 else 12)
 g:SetAttribute("RaceGate", true)
 g:SetAttribute("GateType", if index then "Checkpoint" else "StartFinish")
 g:SetAttribute("CheckpointIndex", index)
end
gate(G.Start)
for index, spec in G.Checkpoints do gate(spec, index) end
local player = child(services.Players, "Player", "Driver")
player.UserId, player.DisplayName = 1, "Driver"
player.Character = object("Model")
local human = child(player.Character, "Humanoid", "Humanoid")
human.Health = 100
local kart = child(prototype, "Model", "Kart")
local chassis = child(kart, "Part", "Chassis")
kart.PrimaryPart = chassis
local seat = child(kart, "Seat", "Seat")
seat.Occupant, human.SeatPart = human, seat
local start = catalog.Entries.EliphantNose.GridSlots[1] + V.yAxis * 2
chassis.CFrame = start
kart:SetAttribute("RaceStartCFrame", start)
local context = {owner = player, kart = kart, chassis = chassis, seat = seat}
function context:setSpawnCFrame(frame)
 self.chassis.CFrame = frame
 self.kart:SetAttribute("RaceStartCFrame", frame)
end
child(server, "ModuleScript", "PrototypeWorld")
modules.PrototypeWorld = {
 getKartContext = function() return context end,
 reassertServerAuthority = function() return true end,
}
player:SetAttribute("SelectedTrackId", "EliphantNose")
player:SetAttribute("ReadyOrder", 1)
player:SetAttribute("GridSlot", 1)
local race = load("src/server/RaceController.luau", server, "RaceController")
check(race.start({trackId = "EliphantNose", preformedMatch = true, expectedParticipantCount = 1}), "race starts")
local function tick(dt) now += dt; services.RunService.Heartbeat:Fire(dt) end
local function drive(point, direction)
 local pos = point + V.yAxis * 2
 chassis.CFrame = lookAt(pos, pos + direction)
 chassis.AssemblyLinearVelocity = direction * 75
 tick(1 / 15)
end
player:SetAttribute("RaceState", "PRE_RACE")
tick(.1)
tick(raceConfig.COUNTDOWN_SECONDS + .1)
check(player:GetAttribute("RaceState") == "RACING", "GO")
local function follow(samples, beforeSample)
 for i, point in samples do
  if not beforeSample or beforeSample(point) then drive(point, (samples[i % #samples + 1] - point).Unit) end
 end
 drive(G.Start.P + G.Start.D * 2, G.Start.D)
end
local function nextCheckpoint()
 return player:GetAttribute("RaceNextCheckpoint")
end
local function assertLap(lap)
 check(player:GetAttribute("RaceCurrentLap") == lap and nextCheckpoint() == 1,
  "lap " .. lap .. " starts with CP1 reset")
end
local merge = G.Checkpoints[2]
local skippedSamples, checkedOuter = 0, false
follow(G.Samples, function(point)
 -- Skip the former hidden gate entirely, then drive normally through shared CP2.
 if (point - G.A[2].P).Magnitude < 20 then
  skippedSamples += 1
  return false
 end
 if not checkedOuter and (point - merge.P):Dot(merge.D) > 0 and (point - merge.P).Magnitude < 15 then
  check(nextCheckpoint() == 3 and player:GetAttribute("RaceFinishMissedSerial") == 0,
   "first-lap outer route accepts shared CP2 despite missing the former hidden gate")
  checkedOuter = true
 end
 return true
end)
check(skippedSamples > 0 and checkedOuter, "outer CP2 exercised after a gap at the former gate")
assertLap(2)

local cp = G.Checkpoints[1]
local right = cp.D:Cross(V.yAxis)
local shoulder = right * 35
check(roadPolicy.contains(cp.P + shoulder, raceConfig.ROAD_CORRIDOR_MARGIN), "CP1 shoulder is on the road corridor")
check(not roadPolicy.contains(cp.P + shoulder, 0), "shoulder uses the existing road margin")
drive(cp.P + right * 45 - cp.D * 58, cp.D)
drive(cp.P + right * 45 - cp.D * 53, cp.D)
check(nextCheckpoint() == 1, "continuous grass motion does not clear CP1")
drive(cp.P + shoulder - cp.D * 53, -cp.D)
drive(cp.P + shoulder - cp.D * 54, -cp.D)
check(nextCheckpoint() == 1, "continuous reverse motion inside the widened checkpoint does not clear CP1")
drive(cp.P + shoulder - cp.D * 49, -cp.D)
check(nextCheckpoint() == 2 and player:GetAttribute("RaceCheckpointMissed") == 0,
 "lap-two CP1 uses observed forward movement and the same road margin")

local startedInner, checkedInner = false, false
follow(G.AltSamples, function(point)
 if not startedInner then
  startedInner = (point - cp.P).Magnitude < 15
  if not startedInner then return false end
 end
 if not checkedInner and (point - merge.P):Dot(merge.D) > 0 and (point - merge.P).Magnitude < 15 then
  check(nextCheckpoint() == 3 and player:GetAttribute("RaceFinishMissedSerial") == 0,
   "second-lap inner route accepts the same shared CP2")
  checkedInner = true
 end
 return true
end)
check(checkedInner, "inner CP2 exercised")
assertLap(3)
drive(cp.P - cp.D * 59, cp.D)
check(nextCheckpoint() == 1, "discontinuous jump into CP1 does not clear it")
drive(cp.P - cp.D * 54, cp.D)
check(nextCheckpoint() == 2, "continuous motion clears CP1 within 60 studs")
local later = G.Checkpoints[3]
drive(later.P - later.D * 3, later.D)
drive(later.P + later.D * 3, later.D)
check(nextCheckpoint() == 2 and player:GetAttribute("RaceCheckpointMissed") == 2,
 "crossing CP3 out of order warns about CP2 before the lap ends")
drive(merge.P - merge.D * 45, merge.D)
check(nextCheckpoint() == 2, "discontinuous jump into the shared CP2 does not clear it")
drive(merge.P - merge.D * 40, merge.D)
check(nextCheckpoint() == 3 and player:GetAttribute("RaceCheckpointMissed") == 0,
 "continuous movement clears shared CP2 even with no observed A or B branch history")
print("PASS: " .. count .. " Eliphant lap-transition checkpoint checks")
]====], {environment = {require = function(path)
 return if path == "./helpers/gameplay_config" then gameplayConfig else require(path)
end}})()
