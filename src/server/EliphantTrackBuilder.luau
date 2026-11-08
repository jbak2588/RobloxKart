local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local ServerStorage=game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").Shared
local G = require(Shared.EliphantGeometry)
local RoadPolicy = require(Shared.EliphantRoadPolicy)
local Builder = {
 Geometry = G,
 AsphaltTopOffset = RoadPolicy.AsphaltTopOffset,
 contains = RoadPolicy.contains,
}

-- The Road folder contains a marker, so use the nearest segment of either
-- driving line to center Smoke and choose the Slick recovery heading.
function Builder.centerlineAt(position)
 local point = Vector3.new(position.X, 0, position.Z)
 local nearestPoint, nearestDirection
 local nearestDistanceSquared = math.huge
 for _, samples in {G.Samples, G.AltSamples} do
  for index, startPoint in samples do
   local segment = samples[index % #samples + 1] - startPoint
   local lengthSquared = segment:Dot(segment)
   if lengthSquared > 0 then
    local fraction = math.clamp((point - startPoint):Dot(segment) / lengthSquared, 0, 1)
    local projected = startPoint + segment * fraction
    local offset = point - projected
    local distanceSquared = offset:Dot(offset)
    if distanceSquared < nearestDistanceSquared then
     nearestPoint = projected
     nearestDirection = segment.Unit
     nearestDistanceSquared = distanceSquared
    end
   end
  end
 end
 return nearestPoint, nearestDirection
end

local function inert(part,parent,name)
 part.Name=name
 part.Anchored=true
 part.CanCollide=false
 part.CanTouch=false
 part.CanQuery=false
 part.CastShadow=false
 part.Parent=parent
 return part
end
local function part(parent,name,size,cf,color)
 local p=Instance.new("Part")
 p.Size,p.CFrame,p.Color=size,cf,color or Color3.new(1,1,1)
 p.Material=Enum.Material.SmoothPlastic
 return inert(p,parent,name)
end
local function folder(parent,name)
 local f=Instance.new("Folder");f.Name=name;f.Parent=parent;return f
end
local function triangle(parent,a,b,c)
 local ab,ac,bc=b-a,c-a,c-b
 if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then c,a=a,c
 elseif ac:Dot(ac)>bc:Dot(bc) then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 if ac:Cross(ab).Magnitude<.00001 then return end
 local right,back=ac:Cross(ab).Unit,bc.Unit
 local up=back:Cross(right)
 local h=math.abs(ab:Dot(up))
 for _,s in {{a,b,right,back},{a,c,-right,-back}} do
  local length=math.abs((s[2]-s[1]):Dot(back))
  if length>.00001 then
   local w=Instance.new("WedgePart")
   w.Size=Vector3.new(RoadPolicy.AsphaltThickness,h,length)
   w.CFrame=CFrame.fromMatrix((s[1]+s[2])/2,s[3],up,s[4])
   w.Material=Enum.Material.SmoothPlastic
   w.Color=Color3.fromRGB(58,63,68)
   inert(w,parent,"Asphalt")
  end
 end
end

function Builder.build(prototype,track,top)
 assert(track.Id=="EliphantNose" and track.GeometryId=="EliphantNoseR2","Eliphant Nose identity")
 local previous=prototype:FindFirstChild("TestTrack")
 if previous and previous:GetAttribute("TrackId")==track.Id then return previous end
 local scenery=ServerStorage:WaitForChild("KDMEliphantScenery"):Clone()
 local ground=Workspace:FindFirstChild("Baseplate") or prototype:FindFirstChild("Ground")
 assert(ground and ground:IsA("BasePart"),"Eliphant Nose requires the world ground")
 local root=Instance.new("Model")
 root.Name="TestTrack"
 root:SetAttribute("TrackId",track.Id)
 root:SetAttribute("GeometryId",track.GeometryId)
 root:SetAttribute("CheckpointCount",#G.Checkpoints)
 root:SetAttribute("RoadWidth",60)
 root:SetAttribute("GroundTop",top)
 root:SetAttribute("StartFinishPaintVersion",1)
 root:SetAttribute("StartGridColumns",2)
 root:SetAttribute("StartGridRows",2)
 root:SetAttribute("GridLaunchHeadingVersion",2)
 root:SetAttribute("CenterlineLength",G.ALength)
 root:SetAttribute("AlternativeCenterlineLength",G.BLength)
 local visual=folder(root,"Asphalt")
 local road=folder(root,"Road")
 local triggers=folder(root,"RaceTriggers")
 folder(root,"BarrierTriggers")
 local paint=folder(root,"Markings")
 local marker=part(road,"Domain",Vector3.new(1,.01,1),CFrame.new(0,top+.05,0))
 marker.Transparency=1
 marker:SetAttribute("EliphantRoad",true)
 local height=Vector3.yAxis*(top+RoadPolicy.AsphaltCenterOffset)
 for _,t in G.Triangles do triangle(visual,t[1]+height,t[2]+height,t[3]+height) end
 for _,edge in G.Edges do
  for i=1,#edge-1 do
   local a,b=edge[i]+height+Vector3.yAxis*.055,edge[i+1]+height+Vector3.yAxis*.055
   local dist=(b-a).Magnitude
   if dist>.03 then
    part(paint,"RoadEdge",Vector3.new(.85,.035,dist+.04),CFrame.lookAt((a+b)*.5,b),Color3.fromRGB(232,237,242))
   end
  end
 end
 local function gate(spec,index)
  local p=spec.P+Vector3.yAxis*(top+5)
  local depth = if index then 120 else 12 -- 60 studs on either side of a checkpoint
  local g=part(triggers,if index then "Checkpoint"..index else "StartFinish",Vector3.new(spec.W,12,depth),CFrame.lookAt(p,p+spec.D))
  g.Transparency=1
  g:SetAttribute("RaceGate",true)
  g:SetAttribute("GateType",if index then "Checkpoint" else "StartFinish")
  if index then g:SetAttribute("CheckpointIndex",index) end
 end
 gate(G.Start)
 for i,g in G.Checkpoints do gate(g,i) end
 local sf=CFrame.lookAt(G.Start.P+Vector3.yAxis*(top+.12),G.Start.P+Vector3.yAxis*(top+.12)+G.Start.D)
 for x=0,9 do
  for z=0,1 do
   part(paint,"Checker",Vector3.new(6,.04,4),sf*CFrame.new(-27+x*6,0,z*4-2),
    if (x+z)%2==0 then Color3.new(1,1,1) else Color3.fromRGB(25,27,30))
  end
 end
 for i,cf in track.GridSlots do
  part(paint,"Grid"..i,Vector3.new(10,.04,.45),cf+Vector3.yAxis*(top+.12))
 end
 scenery:PivotTo(scenery:GetPivot()+Vector3.yAxis*top)
 scenery.Parent=root
 if previous then previous:Destroy() end
 -- Keep the flat support under both branches and the full roadside scene.
 local oldFrame,oldSize,oldColor,oldMaterial=ground.CFrame,ground.Size,ground.Color,ground.Material
 local oldClock=Lighting.ClockTime
 local skies={}
 for _,child in Lighting:GetChildren() do
  if child:IsA("Sky") then table.insert(skies,child);child.Parent=nil end
 end
 Lighting.ClockTime=13
 ground.Size=Vector3.new(2048,oldSize.Y,2048)
 ground.CFrame=CFrame.new(240,top-oldSize.Y*.5,0)
 ground.Color=Color3.fromRGB(66,88,63)
 ground.Material=Enum.Material.Grass
 root.Destroying:Connect(function()
  if ground.Parent then
   ground.CFrame,ground.Size,ground.Color,ground.Material=oldFrame,oldSize,oldColor,oldMaterial
  end
  Lighting.ClockTime=oldClock
  for _,sky in skies do sky.Parent=Lighting end
 end)
 root.Parent=prototype
 return root
end

return Builder
