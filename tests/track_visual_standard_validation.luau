-- Compare production output to the approved pre-K1 checkpoint, not a second implementation.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local source=fs.readFile("tests/track_environment_validation.luau")
local prefix=source:sub(1,assert(source:find('local prototype=object("Folder")',1,true))-1)
luau.load(prefix..[====[
local process=require("@lune/process")
local serde=require("@lune/serde")
local prior=process.exec("git",{"show","2d1d7f16e4d56f17056b50cd737624a12cf3610b:src/server/TrackBuilder.luau"})
assert(prior.ok)
local baseline=luau.load(prior.stdout,{environment=env})()
local function signature(node)
 local rows={}
 local function visit(item,path)
  local attrs={}
  for key,value in item.attrs do
   if key~="VisualStyleProfile" and key~="VisualStyleVersion" then table.insert(attrs,key.."="..tostring(value)) end
  end
  table.sort(attrs)
  local props={item.ClassName,item.Name,tostring(item.CFrame),tostring(item.Size),tostring(item.Color),tostring(item.Material),tostring(item.Transparency),tostring(item.Anchored),tostring(item.CanCollide),tostring(item.CanTouch),tostring(item.CanQuery),tostring(item.CastShadow),tostring(item.Text),table.concat(attrs,";")}
  table.insert(rows,path..table.concat(props,"|"))
  for _,child in item:GetChildren() do visit(child,path.."/"..child.Name) end
 end
 visit(node,"")
 return table.concat(rows,"\n")
end
local counts={}
local prototype=object("Folder")
for _,entry in {{"Track01","PracticeCircuitV1","Practice"},{"Track01Race","PracticeCircuitV1","Base"},{"Track02","PrototypeCircuitV2","Standard"},{"Track03","HardCircuitV1","Hard"}} do
 local track={Id=entry[1],GeometryId=entry[2]}
 local old=baseline.build(object("Folder"),track,0)
 local world=builder.build(prototype,track,0)
 check(world:GetAttribute("VisualStyleProfile")==entry[3],entry[1].." profile")
 check(world:GetAttribute("VisualStyleVersion")==1,entry[1].." version")
 for _,folder in {"Road","Markings","RaceTriggers","BarrierTriggers","Barriers"} do
  check(signature(world:FindFirstChild(folder))==signature(old:FindFirstChild(folder)),entry[1].." exact "..folder.." geometry/flags/attributes")
 end
 if entry[3]=="Hard" then check(signature(world)==signature(old),"Hard entire output preserved except cache metadata") end
 local kerbs=world:FindFirstChild("Kerbs"):GetChildren()
 for _,part in kerbs do
  check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,"kerb visual flags")
  check(part.Color==rb.Color3.fromRGB(205,48,45) or part.Color==rb.Color3.fromRGB(238,236,229),"family kerb palette")
  if entry[3]~="Hard" then check(part:GetAttribute("KerbRow")==1,"standard single row") end
 end
 if entry[3]~="Hard" then
  for _,side in {-1,1} do
   local nextSegment=2
   for _,part in kerbs do if part:GetAttribute("KerbSide")==side then
    check(part:GetAttribute("FirstSegment")==nextSegment,"continuous edge segments")
    nextSegment=part:GetAttribute("LastSegment")+1
   end end
   check(nextSegment==world:GetAttribute("CenterlineSampleCount"),"edge reaches seam allowance")
  end
  for _,part in world:FindFirstChild("Environment"):FindFirstChild("SpeedCues"):GetChildren() do
   check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,"scenery visual flags")
  end
 end
 local oldParts,newParts=old:GetAttribute("VisualPartCount"),world:GetAttribute("VisualPartCount")
 check(newParts<=oldParts*1.25,entry[1].." visual part growth <=25%")
 counts[entry[1]]={}
 for _,key in {"BarrierTriggerPartCount","KerbPartCount","VisualPartCount","EnvironmentPartCount"} do
  counts[entry[1]][key]={before=old:GetAttribute(key),after=world:GetAttribute(key)}
 end
 print(entry[1],serde.encode("json",counts[entry[1]]))
 check(builder.build(prototype,track,0)==world,"cache reuse")
 world:SetAttribute("VisualStyleVersion",0)
 local rebuilt=builder.build(prototype,track,0)
 check(rebuilt~=world and signature(rebuilt)==signature(world),"version invalidation deterministic")
 check(#prototype:GetChildren()==1,"track switch removes prior track")
end
if process.args[1]=="Report" then
 fs.writeDir("artifacts/r7-k1")
 fs.writeFile("artifacts/r7-k1/counts.json",serde.encode("json",counts))
end
print("PASS: "..count.." K1 style, geometry, collision, budget and lifecycle checks")
]====])()
