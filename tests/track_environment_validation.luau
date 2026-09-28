-- lune run tests/track_environment_validation.luau
-- Builds both production geometries with lightweight Roblox instance mocks.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local count = 0
local function check(value, message) assert(value, message); count += 1 end
local methods = {}
local function object(class)
 local props = { ClassName=class, Name=class, CFrame=rb.CFrame.identity, Size=rb.Vector3.one }
 return setmetatable({ props=props, children={}, attrs={} }, {
  __index=function(self,key)
   if methods[key] then return methods[key] end
   if key=="Position" then return props.CFrame.Position end
   return props[key]
  end,
  __newindex=function(self,key,value)
   if key=="Parent" then
    if props.Parent then local i=table.find(props.Parent.children,self); if i then table.remove(props.Parent.children,i) end end
    if value then table.insert(value.children,self) end
   end
   props[key]=value
  end,
 })
end
function methods:FindFirstChild(name)
 for _, child in self.children do if child.Name==name then return child end end
end
function methods:WaitForChild(name) return assert(self:FindFirstChild(name),name) end
function methods:GetChildren() return table.clone(self.children) end
function methods:IsA(class) return self.ClassName==class or (class=="BasePart" and self.ClassName=="Part") end
function methods:SetAttribute(name,value) self.attrs[name]=value end
function methods:GetAttribute(name) return self.attrs[name] end
function methods:Destroy() self.Parent=nil end
local replicated=object("ReplicatedStorage")
local shared=object("Folder"); shared.Name="Shared"; shared.Parent=replicated
local geometryModule=object("ModuleScript"); geometryModule.Name="TrackGeometry"; geometryModule.Parent=shared
local geometry=luau.load(fs.readFile("src/shared/TrackGeometry.luau"),{environment={Vector3=rb.Vector3,Vector2=rb.Vector2}})()
local env={game={GetService=function(_,name) assert(name=="ReplicatedStorage"); return replicated end},
 require=function(module) assert(module==geometryModule); return geometry end,
 Instance={new=object},Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=rb.CFrame,Color3=rb.Color3,Enum=rb.Enum}
local builder=luau.load(fs.readFile("src/server/TrackBuilder.luau"),{environment=env})()
local prototype=object("Folder")
for _, id in {"PracticeCircuitV1","PrototypeCircuitV2"} do
 local definition=geometry.getDefinition(id)
 local course=geometry.getCourse(definition)
 local track={Id=id,GeometryId=id}
 local world=builder.build(prototype,track,0)
 local cues=world:FindFirstChild("Environment"):FindFirstChild("SpeedCues")
 local objects=world:GetAttribute("SpeedCueObjectCount")
 local parts=world:GetAttribute("SpeedCuePartCount")
 check(cues~=nil and objects>0 and objects<=32,id.." cue object cap")
 check(parts==#cues:GetChildren() and parts<=64,id.." cue part cap")
 local function nearestSampleIndex(part)
  local nearest, distance=1,math.huge
  for index, sample in course.Samples do
   local delta=part.Position-sample
   local planar=rb.Vector2.new(delta.X,delta.Z).Magnitude
   if planar<distance then nearest,distance=index,planar end
  end
  return nearest
 end
 local cueParts=cues:GetChildren()
 check(nearestSampleIndex(cueParts[1])<#course.Samples*0.2,id.." cues begin near track start")
 check(nearestSampleIndex(cueParts[#cueParts])>#course.Samples*0.7,id.." cues reach late track sections")
 check(world:GetAttribute("EnvironmentCueVersion")==1,id.." cache version")
 check(#world:FindFirstChild("Road"):GetChildren()==#course.Samples,id.." road count unchanged")
 check(world:GetAttribute("CenterlineLength")==course.CenterlineLength,id.." centerline unchanged")
 check(world:GetAttribute("RoadWidth")==definition.RoadWidth,id.." width unchanged")
 local gates=world:FindFirstChild("RaceTriggers")
 check(#gates:GetChildren()==#course.CheckpointSamples+1,id.." gate count unchanged")
 for _, part in cues:GetChildren() do
  check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,id.." cue visual only")
 end
 check(builder.build(prototype,track,0)==world,id.." current cache reused")
 world:SetAttribute("EnvironmentCueVersion",0)
 local rebuilt=builder.build(prototype,track,0)
 check(rebuilt~=world and rebuilt:GetAttribute("SpeedCuePartCount")==parts,id.." stale cache rebuilt deterministically")
end
print("PASS: "..count.." track cue, cache and geometry checks")
