local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local env = { Vector3 = rb.Vector3, Vector2 = rb.Vector2 }
local function load(path) return luau.load(fs.readFile(path), {environment=env})() end
local geometry = load("src/shared/TrackGeometry.luau")
local progress = load("src/shared/RaceRouteProgress.luau")
local checks = 0
local function check(value, label) assert(value, label); checks += 1 end
for id, definition in geometry.Definitions do
 local course = geometry.getCourse(definition)
 for _, excursion in {false, true} do
  for lap=1,2 do
   local state = progress.new(course, definition.RoadWidth)
   local nextCheckpoint = 1
   for step=0,2000 do
    local fraction = step/2000
    local offset = 0
    if excursion then
     for _, cp in course.CheckpointSamples do
      local gap = math.abs(fraction-cp.Fraction)
      -- A gradual excursion outside the gate, then return beyond it.
      offset = math.max(offset, (definition.RoadWidth/2+30)*math.clamp((0.018-gap)/0.008,0,1))
     end
    end
    local tangent = geometry.getTangentAtFraction(course.Samples,fraction)
    local position = geometry.getSampleAtFraction(course.Samples,fraction)+rb.Vector3.new(-tangent.Z,0,tangent.X)*offset
    local onRoad = offset <= definition.RoadWidth/2+8
    local previous = nextCheckpoint
    nextCheckpoint = progress.step(state,position,nextCheckpoint,onRoad)
    if not onRoad then check(nextCheckpoint==previous,"offroad crossings remain provisional") end
   end
   check(nextCheckpoint==#course.CheckpointSamples+1,id.." ordered lap "..lap.." excursion="..tostring(excursion))
  end
 end
 local state = progress.new(course,definition.RoadWidth)
 local nextCheckpoint=1
 for step=2000,0,-1 do
  nextCheckpoint=progress.step(state,geometry.getSampleAtFraction(course.Samples,step/2000),nextCheckpoint,true)
 end
 check(nextCheckpoint==1,id.." reverse lap rejected")
 state=progress.new(course,definition.RoadWidth)
 progress.step(state,course.StartPosition,1,true)
 local destination=geometry.getSampleAtFraction(course.Samples,course.CheckpointSamples[1].Fraction+0.01)
 check(progress.step(state,destination,1,true)==1,id.." teleport cannot recover skipped checkpoint")
 check(progress.step(progress.new(course,definition.RoadWidth),destination,1,true)==1,id.." reset cannot inherit progress")
end
print("PASS: "..checks.." route recovery checks on both real track geometries")
