local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local V=roblox.Vector3
local function load(path, environment)
 return luau.load(fs.readFile(path),{environment=environment or {Vector3=V},debugName=path})()
end
local G=load("src/shared/EliphantGeometry.luau")
local assertions=0
local function check(ok,msg)
 assertions+=1;assert(ok,msg)
end
local function length(points)
 local l=0
 for i,a in points do l+=(a-points[i%#points+1]).Magnitude end
 return l
end
print("sampled A/B lengths",length(G.Samples),length(G.AltSamples))
check(math.abs(length(G.Samples)-G.ALength)<.65,"A distance")
check(math.abs(length(G.AltSamples)-G.BLength)<.65,"B distance")
check((G.Samples[1]-G.Start.P).Magnitude<.01,"A start at diagonal checker")
check((G.AltSamples[1]-G.Start.P).Magnitude<.01,"B start at diagonal checker")
check(math.abs(G.Start.D.X)>.5 and math.abs(G.Start.D.Z)>.5,"diagonal start")
check(#G.Checkpoints==6,"six public checkpoints per lap")
for _,t in G.Triangles do check((t[2]-t[1]):Cross(t[3]-t[1]).Magnitude>.00001,"road triangle") end
local roadPolicy = load("src/shared/EliphantRoadPolicy.luau", {
 script = {Parent = {WaitForChild = function(_, name) return name end}},
 require = function(name) assert(name == "EliphantGeometry"); return G end,
})
local root={Shared={EliphantGeometry="EliphantGeometry",EliphantRoadPolicy="EliphantRoadPolicy"}}
local Builder=luau.load(fs.readFile("src/server/EliphantTrackBuilder.luau"),{
 environment={Vector3=V,game={GetService=function()return root end},
  require=function(name) return if name == "EliphantRoadPolicy" then roadPolicy else G end}
})()
for _,points in {G.Samples,G.AltSamples} do
 for _,point in points do check(Builder.contains(point,0),"both centerlines on paved union") end
end
check(Builder.contains(V.new(0,0,-0.0),0),"signed zero in road index")
check(not Builder.contains(V.new(2000,0,2000),8),"grass beyond outer road")
local CF = roblox.CFrame
local track = {
 GetAttribute = function(_, name)
  return ({GeometryId = "EliphantNoseR2", GroundTop = 7})[name]
 end,
}
local prototype = {FindFirstChild = function(_, name) if name == "TestTrack" then return track end end}
local itemGeometry = load("src/server/RaceItemGeometry.luau", {
 Vector3 = V,
 CFrame = CF,
 script = {Parent = {WaitForChild = function(_, name) return name end}},
 require = function(name) assert(name == "EliphantTrackBuilder"); return Builder end,
})
for _, branch in {"A", "B"} do
 local gate = G[branch][2]
 local position = gate.P + gate.D:Cross(V.yAxis) * 12
 local driverPosition = position + gate.D * 10 + V.yAxis * 8
 local chassis = {Position = driverPosition,
  CFrame = CF.fromMatrix(driverPosition, gate.D:Cross(V.yAxis), V.yAxis, -gate.D)}
 local slick = itemGeometry.dropFrame(prototype, chassis, 10)
 local smoke = itemGeometry.smokeDropFrame(prototype, chassis, 10)
 check(slick and smoke, branch .. " hazards deploy away from the Road marker")
 check((slick.Position - V.new(position.X, 7.1425, position.Z)).Magnitude < 0.002,
  branch .. " Slick keeps its lane above the pavement")
 check((V.new(smoke.X, 0, smoke.Z) - gate.P).Magnitude < 4 and smoke.LookVector:Dot(gate.D) > 0.99,
  branch .. " Smoke centers and follows the chosen branch")
 check(itemGeometry.roadFrameAt(prototype, position).LookVector:Dot(gate.D) > 0.99,
  branch .. " Slick recovery follows the chosen branch")
end
local offRoad = {Position = V.new(2000, 8, 2000), CFrame = CF.new(2000, 8, 2000)}
check(not itemGeometry.dropFrame(prototype, offRoad, 10) and not itemGeometry.smokeDropFrame(prototype, offRoad, 10),
 "Neither hazard can be dropped outside the paved union")
local function child(_, name) return name end
local geometry = load("src/shared/TrackGeometry.luau", {
 Vector3 = V, Vector2 = roblox.Vector2, script = {Parent = {WaitForChild = child}},
 require = function(name) assert(name == "EliphantGeometry"); return G end,
})
local noseDefinition = geometry.getDefinition("EliphantNoseR2")
local noseCourse = geometry.getCourse(noseDefinition)
check(#noseCourse.CheckpointSamples == 6 and noseDefinition.MinimumLapDistance > 6487,
 "official route uses six gates and retains the previous minimum-lap bound")
for i = 2, #noseCourse.CheckpointSamples do
 check(noseCourse.CheckpointSamples[i - 1].Fraction < noseCourse.CheckpointSamples[i].Fraction, "gates follow driving order")
end
local RouteProgress = load("src/shared/RaceRouteProgress.luau")
for _, samples in {G.Samples, G.AltSamples} do
 local progress = RouteProgress.new(noseCourse, noseDefinition.RoadWidth)
 local nextGate, pastMerge = 3, false
 for _, point in samples do
  if (point - G.Checkpoints[2].P).Magnitude < 5 then pastMerge = true end
  if pastMerge then nextGate = RouteProgress.step(progress, point, nextGate, roadPolicy.contains(point)) end
 end
 check(nextGate == 7, "both branches can clear all six gates after the validated merge")
end
local jump = RouteProgress.new(noseCourse, noseDefinition.RoadWidth)
RouteProgress.step(jump, G.Checkpoints[2].P, 3, true)
check(RouteProgress.step(jump, G.Checkpoints[4].P, 3, true) == 3, "shortcut jump does not award gates")
local superZPolicy = load("src/shared/SuperZRoadPolicy.luau", {
 Vector3 = V,
 script = {Parent = {WaitForChild = child}},
 require = function(name) assert(name == "TrackGeometry"); return geometry end,
})
local shared = {WaitForChild = child}
local superZItems = load("src/server/RaceItemGeometry.luau", {
 Vector3 = V,
 CFrame = CF,
 game = {GetService = function() return {WaitForChild = function() return shared end} end},
 require = function(name) assert(name == "SuperZRoadPolicy"); return superZPolicy end,
})
track.GetAttribute = function(_, name)
 return ({GeometryId = "SuperZV1", GroundTop = 7})[name]
end
local function atDrop(position, direction)
 local origin = position + direction * 10 + V.yAxis * 8
 return {Position = origin, CFrame = CF.fromMatrix(origin, direction:Cross(V.yAxis), V.yAxis, -direction)}
end
local superZStraight = atDrop(V.new(150, 0, 12), V.xAxis)
local slick = superZItems.dropFrame(prototype, superZStraight, 10)
local smoke = superZItems.smokeDropFrame(prototype, superZStraight, 10)
check(slick and (slick.Position - V.new(150, 7.1, 12)).Magnitude < 0.001,
 "Super Z Slick holds the driver's lane away from the start marker")
check(smoke and (smoke.Position - V.new(150, 7.1, 0)).Magnitude < 0.001,
 "Super Z Smoke centers on the road")
for _, position in {V.new(100, 0, 470), V.new(620, 0, 486)} do
 local _, direction = superZPolicy.centerlineAt(position)
 local driver = atDrop(position, direction)
 check(superZItems.dropFrame(prototype, driver, 10) and superZItems.smokeDropFrame(prototype, driver, 10),
  "Super Z supports drops on the widened corners")
 check(superZItems.roadFrameAt(prototype, position).LookVector:Dot(direction) > 0.999,
  "Super Z Slick recovery follows the local track direction")
end
local grass = atDrop(V.new(450, 0, 480), V.xAxis)
check(not superZItems.dropFrame(prototype, grass, 10) and not superZItems.smokeDropFrame(prototype, grass, 10),
 "Super Z inner grass remains invalid for both items")
local catalog=load("src/shared/TrackCatalog.luau",{CFrame=roblox.CFrame})
local entry=catalog.Entries.EliphantNose
check(catalog.Order[table.find(catalog.Order,"SuperZ")+1]==entry.Id,"Eliphant follows Super Z")
check(entry.PreviewImageAssetId=="rbxassetid://122688300985713","owner preview asset")
check(entry.MatchType=="PUBLIC_RACE" and entry.TargetLaps==3 and entry.MaxPlayers==4
 and #entry.GridSlots==4 and catalog.botAllowed(entry.Id),"four-player, three-lap public race with bot invitations")
for _,slot in entry.GridSlots do
 check(Builder.contains(slot.Position,0) and slot.LookVector:Dot(G.Start.D)>.9999,"grid in road and faces the line")
end
print("PASS Eliphant Nose: "..assertions.." assertions, "..#G.Triangles.." road triangles")
