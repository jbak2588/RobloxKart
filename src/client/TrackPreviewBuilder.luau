local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Geometry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TrackGeometry"))
local Builder = {}

local function segmentDistance(point, first, last)
 local delta = last - first
 local alpha = if delta.Magnitude > .001 then math.clamp((point-first):Dot(delta)/delta:Dot(delta),0,1) else 0
 return (point-first-delta*alpha).Magnitude
end

-- Closed-path RDP keeps the finish sample and an opposite anchor. No mirroring,
-- no production objects: simplify the shared centerline data only.
function Builder.simplify(samples, tolerance)
 local opposite, distance = 2, 0
 for index=2,#samples do
  local d=(samples[index]-samples[1]).Magnitude
  if d>distance then opposite,distance=index,d end
 end
 local points=table.clone(samples);table.insert(points,samples[1])
 local keep={[1]=true,[opposite]=true,[#points]=true}
 local function reduce(first,last)
  local farthest,maximum=nil,tolerance
  for index=first+1,last-1 do
   local d=segmentDistance(points[index],points[first],points[last])
   if d>maximum then farthest,maximum=index,d end
  end
  if farthest then keep[farthest]=true;reduce(first,farthest);reduce(farthest,last) end
 end
 reduce(1,opposite);reduce(opposite,#points)
 local result={}
 for index=1,#samples do if keep[index] then table.insert(result,samples[index]) end end
 return result
end

function Builder.build(track)
 local definition=Geometry.getDefinition(track.GeometryId)
 assert(definition,"Missing preview geometry")
 local course=Geometry.getCourse(definition)
 assert(#course.Samples>=3,"Missing centerline")
 local limit=if track.GeometryId=="HardCircuitV1" then 56 else 40
 local tolerance=1
 local samples=Builder.simplify(course.Samples,tolerance)
 while #samples>limit do tolerance*=1.2;samples=Builder.simplify(course.Samples,tolerance) end
 local scale=.06
 local bounds=course.Bounds
 local center=Vector3.new((bounds.MinX+bounds.MaxX)/2,0,(bounds.MinZ+bounds.MaxZ)/2)
 local function point(p) return (p-center)*scale end
 local width=definition.RoadWidth*scale
 local model=Instance.new("WorldModel");model.Name="TrackDioramaWorld"
 local min,max=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 local count=0
 local function part(name,size,frame,color,material)
  local p=Instance.new("Part")
  p.Name,p.Size,p.CFrame=name,size,frame
  p.Color,p.Material=color,material or Enum.Material.SmoothPlastic
  p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery,p.CastShadow=true,false,false,false,false
  p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
  p.Parent=model;count+=1
  for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
   local v=frame*Vector3.new(x*size.X/2,y*size.Y/2,z*size.Z/2)
   min=Vector3.new(math.min(min.X,v.X),math.min(min.Y,v.Y),math.min(min.Z,v.Z))
   max=Vector3.new(math.max(max.X,v.X),math.max(max.Y,v.Y),math.max(max.Z,v.Z))
  end end end
  return p
 end
 local success,failure=pcall(function()
  part("DioramaPad",Vector3.new((bounds.MaxX-bounds.MinX)*scale+width*2,.8,(bounds.MaxZ-bounds.MinZ)*scale+width*2),CFrame.new(0,-.5,0),Color3.fromRGB(65,96,65))
  for index,first in samples do
   local last=samples[index%#samples+1]
   local a,b=point(first),point(last)
   local delta=b-a;assert(delta.Magnitude>.001,"Degenerate preview segment")
   local forward=delta.Unit
   local right=forward:Cross(Vector3.yAxis)
   local frame=CFrame.fromMatrix((a+b)/2,right,Vector3.yAxis,-forward)
   -- Small overlaps avoid ribbon seams at decimated corners.
   part("Road",Vector3.new(width,.3,delta.Magnitude+width*.35),frame,Color3.fromRGB(44,48,54),Enum.Material.Asphalt)
   for _,side in {-1,1} do
    part("KerbCue",Vector3.new(width*.09,.32,delta.Magnitude+width*.15),frame*CFrame.new(side*width*.54,.015,0),if index%2==0 then Color3.fromRGB(236,232,221) else Color3.fromRGB(213,51,53))
   end
  end
  local start=point(course.StartPosition)
  local tangent=course.StartTangent.Unit
  local frame=CFrame.fromMatrix(start,tangent:Cross(Vector3.yAxis),Vector3.yAxis,-tangent)
  for column=0,3 do for row=0,1 do
   part("StartFinish",Vector3.new(width/4,.06,width/8),frame*CFrame.new((column-1.5)*width/4,.2,(row-.5)*width/8),if (column+row)%2==0 then Color3.new(1,1,1) else Color3.new(0,0,0))
  end end
  for _,side in {-1,1} do part("FinishPost",Vector3.new(.2,2.4,.2),frame*CFrame.new(side*width*.65,1.2,0),Color3.fromRGB(255,215,65)) end
  part("FinishGate",Vector3.new(width*1.3,.2,.2),frame*CFrame.new(0,2.4,0),Color3.fromRGB(255,215,65))
  for _,fraction in {.035,.35,.7} do
   local position=point(Geometry.getSampleAtFraction(course.Samples,fraction))
   local forward=Geometry.getTangentAtFraction(course.Samples,fraction).Unit
   local f=CFrame.fromMatrix(position,forward:Cross(Vector3.yAxis),Vector3.yAxis,-forward)
   part("ForwardCue",Vector3.new(.2,.05,width*.5),f*CFrame.new(0,.21,0),Color3.fromRGB(245,242,220))
   for _,side in {-1,1} do
    part("ForwardCue",Vector3.new(.18,.05,width*.28),f*CFrame.new(side*width*.09,.21,-width*.13)*CFrame.Angles(0,side*math.pi/4,0),Color3.fromRGB(245,242,220))
   end
  end
 end)
 if not success then model:Destroy();error(failure) end
 model:SetAttribute("TrackId",track.Id)
 model:SetAttribute("PreviewSampleCount",#samples)
 return {world=model,min=min,max=max,center=(min+max)/2,productionSamples=#course.Samples,previewSamples=#samples,parts=count,tolerance=tolerance,scale=scale}
end

return Builder
