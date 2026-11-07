-- Official Super Z uses the owner-approved native meshes and inert Park scenery.
local RS=game:GetService('ReplicatedStorage')
local Geometry=require(RS.Shared.TrackGeometry)
local Builder={}
function Builder.build(prototype,track,groundTop)
 assert(track.Id=='SuperZ'and track.GeometryId=='SuperZV1','Super Z identity')
 local previous=prototype:FindFirstChild('TestTrack')
 if previous and previous:GetAttribute('TrackId')==track.Id and previous:GetAttribute('SuperZReleaseVersion')==1 then return previous end
 local resources=RS:WaitForChild('KDMSuperZResources')
 local root=resources:WaitForChild('SuperZTrack'):Clone();root.Name='TestTrack'
 root:SetAttribute('TrackId',track.Id);root:SetAttribute('GeometryId',track.GeometryId)
 root:SetAttribute('SuperZReleaseVersion',1);root:SetAttribute('LocalOnly',nil)
 local materialService=game:GetService('MaterialService')
 if not materialService:FindFirstChild('SuperZ_Park_Matte')then resources.SuperZ_Park_Matte:Clone().Parent=materialService end
 for _,v in root:GetDescendants()do
  if v:IsA('BasePart')then v.CFrame+=Vector3.yAxis*groundTop end
 end
 -- Replace prototype eight-slot paint with the actual four human race slots.
 root.Markings:Destroy()
 local function folder(name)local f=Instance.new('Folder');f.Name=name;f.Parent=root;return f end
 local road=folder('Road');local triggers=folder('RaceTriggers');folder('BarrierTriggers')
 local function part(parent,name,size,cf)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Anchored=true
  p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Transparency=1;p.Parent=parent;return p
 end
 local marker=part(road,'SuperZRoadDomain',Vector3.new(1,.01,1),CFrame.new(0,groundTop,0));marker:SetAttribute('SuperZRoad',true)
 local course=Geometry.getCourse(Geometry.getDefinition(track.GeometryId))
 local function gate(name,position,direction,index)
  local p=Vector3.new(position.X,groundTop+8,position.Z)
  local g=part(triggers,name,Vector3.new(80,20,20),CFrame.lookAt(p,p+direction))
  g:SetAttribute('RaceGate',true);g:SetAttribute('GateType',if index then 'Checkpoint'else 'StartFinish')
  if index then g:SetAttribute('CheckpointIndex',index)end
 end
 gate('StartFinish',course.StartPosition,course.StartTangent,nil)
 for i,g in course.CheckpointSamples do gate('Checkpoint'..i,g.Position,g.Tangent,i)end
 local markings=folder('Markings')
 local finish=part(markings,'StartLine',Vector3.new(56,.01,8),CFrame.lookAt(Vector3.new(0,groundTop+.285,0),Vector3.new(1,groundTop+.285,0)))
 local tx=Instance.new('Texture');tx.Name='SourceCheckers';tx.Texture='rbxassetid://15424111389';tx.Face=Enum.NormalId.Top;tx.StudsPerTileU=8;tx.StudsPerTileV=8;tx.Parent=finish
 for i,frame in track.GridSlots do
  local f=Instance.new('Folder');f.Name='Grid'..i;f.Parent=markings
  local cf=frame+Vector3.new(0,groundTop+.285,0)
  local front=part(f,'Front',Vector3.new(10,.01,.35),cf*CFrame.new(0,0,-7.5));front.Transparency=0;front.Color=Color3.fromRGB(235,246,250)
  for _,side in {-1,1}do local arm=part(f,'Arm',Vector3.new(.35,.01,4),cf*CFrame.new(side*5,0,-5.5));arm.Transparency=0;arm.Color=front.Color end
 end
 root:SetAttribute('RoadWidth',60);root:SetAttribute('CheckpointCount',#course.CheckpointSamples)
 root:SetAttribute('CenterlineLength',course.CenterlineLength);root:SetAttribute('CenterlineSampleCount',#course.Samples)
 root:SetAttribute('StartFinishPaintVersion',1);root:SetAttribute('GridLaunchHeadingVersion',2)
 root:SetAttribute('StartGridColumns',2);root:SetAttribute('StartGridRows',2)
 root:SetAttribute('GroundTop',groundTop)
 if previous then previous:Destroy()end
 -- The existing world ground provides the unchanged physical contact plane.
 local ground=game:GetService('Workspace'):FindFirstChild('Baseplate')
 if ground then local transparency=ground.Transparency;ground.Transparency=1
  root.Destroying:Connect(function()if ground.Parent then ground.Transparency=transparency end end)
 end
 root.Parent=prototype
 return root
end
return Builder
