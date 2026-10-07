-- lune run tests/track_environment_validation.luau
-- Builds both production geometries with lightweight Roblox instance mocks.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
-- Lune lookAt mirrors diagonal Z; construct Roblox's documented forward basis.
local frames=table.clone(rb.CFrame)
function frames.lookAt(position,target,up)
 local forward=(target-position).Unit
 local right=forward:Cross(up or rb.Vector3.yAxis).Unit
 return rb.CFrame.fromMatrix(position,right,right:Cross(forward),-forward)
end
for _,target in {rb.Vector3.new(18,0,-7),rb.Vector3.new(-7,0,18)} do
 assert(frames.lookAt(rb.Vector3.zero,target).LookVector:Dot(target.Unit)>.99999,"test adapter matches Roblox lookAt direction")
end
local count = 0
local function check(value, message) assert(value, message); count += 1 end
local function cross(a,b)return a.X*b.Z-a.Z*b.X end
local function pointDistance(point,a,b)
 local delta=b-a
 return (point-(a+delta*math.clamp((point-a):Dot(delta)/delta:Dot(delta),0,1))).Magnitude
end
local function segmentDistance(a,b,c,d)
 local u,v=b-a,d-c;local denominator=cross(u,v)
 if math.abs(denominator)>1e-8 then
  local t,q=cross(c-a,v)/denominator,cross(c-a,u)/denominator
  if t>=0 and t<=1 and q>=0 and q<=1 then return 0 end
 end
 return math.min(pointDistance(a,c,d),pointDistance(b,c,d),pointDistance(c,a,b),pointDistance(d,a,b))
end
local methods = {}
local function object(class)
 local props = { ClassName=class, Name=class, CFrame=rb.CFrame.identity, Size=rb.Vector3.one }
 return setmetatable({ props=props, children={}, attrs={} }, {
  __index=function(self,key)
   if methods[key] then return methods[key] end
   if key=="Position" and class=="Part" then return props.CFrame.Position end
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
 Instance={new=object},Vector3=rb.Vector3,Vector2=rb.Vector2,CFrame=frames,Color3=rb.Color3,Enum=rb.Enum,UDim2=rb.UDim2,UDim=rb.UDim}
local builder=luau.load(fs.readFile("src/server/TrackBuilder.luau"),{environment=env})()
local prototype=object("Folder")
for _, id in {"PracticeCircuitV1","PrototypeCircuitV2","HardCircuitV1"} do
 local definition=geometry.getDefinition(id)
 local course=geometry.getCourse(definition)
 local track={Id=id,GeometryId=id}
 local world=builder.build(prototype,track,0)
 local cues=world:FindFirstChild("Environment"):FindFirstChild("SpeedCues")
 local objects=world:GetAttribute("SpeedCueObjectCount")
 local parts=world:GetAttribute("SpeedCuePartCount")
 local isV2=id=="HardCircuitV1"
 local left,right=0,0
 local minimumDot=1
 local normalShoulder,majorShoulder=math.huge,math.huge
 local majorRanges={}
 local exitRanges={}
 local exitMinimum=math.huge
 local version=if isV2 then 6 else 1
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
 check(world:GetAttribute("EnvironmentCueVersion")==version,id.." cache version")
 check(#world:FindFirstChild("Road"):GetChildren()==#course.Samples,id.." road count unchanged")
 check(world:GetAttribute("CenterlineLength")==course.CenterlineLength,id.." centerline unchanged")
 check(world:GetAttribute("RoadWidth")==definition.RoadWidth,id.." width unchanged")
 local gates=world:FindFirstChild("RaceTriggers")
 check(#gates:GetChildren()==#course.CheckpointSamples+1,id.." gate count unchanged")
 for _, part in cues:GetChildren() do
  check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,id.." cue visual only")
 end
 if isV2 then
  local support=world:FindFirstChild("SafetyGround")
  check(support and support.Anchored and support.CanCollide and support.Parent==world,"Hard physical support outside Road")
  check(math.abs(support.Position.Y+support.Size.Y/2)<1e-6,"SafetyGround top equals groundTop")
  local bounds=course.Bounds
  for _,side in {-1,1} do
   local edgeX=support.Position.X+support.Size.X/2*side
   local edgeZ=support.Position.Z+support.Size.Z/2*side
   local bx=if side<0 then bounds.MinX else bounds.MaxX
   local bz=if side<0 then bounds.MinZ else bounds.MaxZ
   check((edgeX-bx)*side>=definition.RoadWidth/2+199.99,"X support recovery margin")
   check((edgeZ-bz)*side>=definition.RoadWidth/2+199.99,"Z support recovery margin")
  end
  for _,point in course.Samples do
   for _,distance in {40,80,100} do
    for _,axis in {rb.Vector3.xAxis,rb.Vector3.zAxis,-rb.Vector3.xAxis,-rb.Vector3.zAxis} do
     local q=point+axis*(definition.RoadWidth/2+distance)
     check(math.abs(q.X-support.Position.X)<support.Size.X/2 and math.abs(q.Z-support.Position.Z)<support.Size.Z/2,"all outer recovery probes physically covered")
    end
   end
  end
  local kerbs=world:FindFirstChild("Kerbs")
  local samples,n=course.Samples,#course.Samples
  local function bend(index)
   local a=(samples[index]-samples[(index-2)%n+1]).Unit
   local b=(samples[index%n+1]-samples[index]).Unit
   return math.acos(math.clamp(a:Dot(b),-1,1))
  end
  local covered={ [1]={[-1]={},[1]={}}, [2]={[-1]={},[1]={}} }
  local sharpExpected={}
  local segment=4
  while segment<=n-3 do
   if bend(segment)>=math.atan(14/105) then
    local first=segment
    while segment<=n-3 and bend(segment)>=math.atan(14/105) do segment+=1 end
    if segment-first>=3 then
     local last=segment-1
     while first>4 and bend(first-1)>=math.atan(14/140) do first-=1 end
     while last<n-3 and bend(last+1)>=math.atan(14/140) do last+=1 end
     for index=first-2,last+2 do sharpExpected[index]=true end
    end
   else segment+=1 end
  end
  local kerbMinimum=math.huge
  local kerbBarrierGap=math.huge
  local function footprint(part)
   local corners={}
   for _,xy in {{-1,-1},{-1,1},{1,1},{1,-1}} do
    local v=part.CFrame:PointToWorldSpace(rb.Vector3.new(part.Size.X/2*xy[1],0,part.Size.Z/2*xy[2]))
    table.insert(corners,rb.Vector3.new(v.X,0,v.Z))
   end
   return corners
  end
  local function rectanglesSeparated(one,two)
   local delta=two.Position-one.Position
   local oneX,oneZ=one.CFrame.RightVector,one.CFrame.LookVector
   local twoX,twoZ=two.CFrame.RightVector,two.CFrame.LookVector
   for _,axis in {oneX,oneZ,twoX,twoZ} do
    local first=one.Size.X/2*math.abs(oneX:Dot(axis))+one.Size.Z/2*math.abs(oneZ:Dot(axis))
    local second=two.Size.X/2*math.abs(twoX:Dot(axis))+two.Size.Z/2*math.abs(twoZ:Dot(axis))
    if math.abs(delta:Dot(axis))>first+second+.001 then return true end
   end
   return false
  end
  for _,part in kerbs:GetChildren() do
   for _,road in world:FindFirstChild("Road"):GetChildren() do
    if (part.Position-road.Position).Magnitude>part.Size.Z/2+road.Size.Z/2+28 then continue end
    check(rectanglesSeparated(part,road),"actual kerb rectangle never overlaps actual overhanging Road Part")
   end
   for _,barrier in world:FindFirstChild("Barriers"):GetChildren() do
    if (part.Position-barrier.Position).Magnitude>part.Size.Z/2+barrier.Size.Z/2+20 then continue end
    check(rectanglesSeparated(part,barrier),"actual outer kerb never overlaps visual barrier")
   end
   local row,side=part:GetAttribute("KerbRow"),part:GetAttribute("KerbSide")
   local first,last=part:GetAttribute("FirstSegment"),part:GetAttribute("LastSegment")
   check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,"all kerbs visual-only")
   check(part.Size.X==3.5,"both rows use approved 3.5-stud stripe width")
   check(last-first<4,"kerb batch bounded to four source segments")
   for index=first,last do
    covered[row][side][index]=true
    if row==2 then check(sharpExpected[index],"outer row stays in sustained sharp groups") end
    for _,alpha in {0,.25,.5,.75,1} do
     local tangent=(samples[index%n+1]-samples[(index-2)%n+1]).Unit
     local following=(samples[(index+1)%n+1]-samples[index]).Unit
     local offset=24+2.6+(row-1)*3.6
     local a=samples[index]+rb.Vector3.new(-tangent.Z,0,tangent.X)*offset*side
     local b=samples[index+1]+rb.Vector3.new(-following.Z,0,following.X)*offset*side
     local point=part.CFrame:PointToObjectSpace(a:Lerp(b,alpha))
     check(math.abs(point.X)<=part.Size.X/2+.001 and math.abs(point.Z)<=part.Size.Z/2+.001,"real merged stripe covers full sampled edge span")
    end
   end
   local corners=footprint(part)
   local radius=part.Size.Z/2+part.Size.X/2+definition.RoadWidth/2+definition.SampleSpacing
   for index,point in samples do
    if (point-rb.Vector3.new(part.Position.X,0,part.Position.Z)).Magnitude>radius then continue end
    for edge=1,4 do
     local distance=segmentDistance(point,samples[index%n+1],corners[edge],corners[edge%4+1])
     kerbMinimum=math.min(kerbMinimum,distance)
     check(distance>=definition.RoadWidth/2,"entire kerb footprint stays outside 48-stud road")
    end
   end
   for _,trigger in world:FindFirstChild("BarrierTriggers"):GetChildren() do
    if (part.Position-trigger.Position).Magnitude>part.Size.Z/2+trigger.Size.Z/2+20 then continue end
    local box=footprint(trigger)
    for edge=1,4 do for other=1,4 do
     local distance=segmentDistance(corners[edge],corners[edge%4+1],box[other],box[other%4+1])
     kerbBarrierGap=math.min(kerbBarrierGap,distance)
     check(distance>.01,"outer kerb row does not intersect frozen trigger footprint")
    end end
   end
  end
  for index=2,n-1 do
   for _,side in {-1,1} do
    check(covered[1][side][index],"all straight/mild/sharp segments have both-edge standard kerb")
    if sharpExpected[index] then check(covered[2][side][index],"sustained sharp entry/apex/exit double kerb coverage") end
   end
  end
  check(not covered[1][-1][1] and not covered[1][1][n],"only two checker-adjacent segments leave a short opening")
  check(world:GetAttribute("SingleKerbPartCount")+world:GetAttribute("DoubleKerbPartCount")==#kerbs:GetChildren(),"single/double part budget exactly accounted")
  check(world:GetAttribute("SingleKerbPartCount")<2*(n-2),"gentle kerb batching saves parts")
  print(string.format("R3C kerbs: single %d double %d groups %d min road distance %.3f min trigger gap %.3f",
   world:GetAttribute("SingleKerbPartCount"),world:GetAttribute("DoubleKerbPartCount"),world:GetAttribute("SharpKerbGroupCount"),kerbMinimum,kerbBarrierGap))
  local straightClusters,curveClusters=0,0
  local startMarker=false
  local directionProof={}
  local stationLanes={}

  local markers=world:FindFirstChild("DirectionMarkers")
  for _, cluster in markers:GetChildren() do
   local index=cluster:GetAttribute("SampleIndex")
   local lane=cluster:GetAttribute("LaneSide")
   check(lane==-1 or lane==1,"lane cue has explicit left/right lane placement")
   stationLanes[index]=stationLanes[index] or {}
   check(not stationLanes[index][lane],"no duplicate cue within the same lane at a station")
   stationLanes[index][lane]=true
   local isCurve=bend(index)>=math.atan(14/350)
   if isCurve then curveClusters+=1 else straightClusters+=1 end
   if index>=3 and index<=9 then startMarker=true end
   local a=(course.Samples[index]-course.Samples[(index-2)%#course.Samples+1]).Unit
   local b=(course.Samples[index%#course.Samples+1]-course.Samples[index]).Unit
   check(cluster:GetAttribute("TurnSide")==nil,"no turn-left/right semantic remains")
   check(#cluster:GetChildren()==6,"three native arrow pairs")
   local tangent=(course.Samples[index%#course.Samples+1]-course.Samples[(index-2)%#course.Samples+1]).Unit
   local expected=tangent
   local laneRight=rb.Vector3.new(-tangent.Z,0,tangent.X)
   for arrow=-1,1 do
    local one=cluster:FindFirstChild("Arrow"..arrow.."Wing-1")
    local two=cluster:FindFirstChild("Arrow"..arrow.."Wing1")
    local head1=one.CFrame.Position+one.CFrame.LookVector*one.Size.Z/2
    local head2=two.CFrame.Position+two.CFrame.LookVector*two.Size.Z/2
    local tail1=one.CFrame.Position-one.CFrame.LookVector*one.Size.Z/2
    local tail2=two.CFrame.Position-two.CFrame.LookVector*two.Size.Z/2
    check((head1-head2).Magnitude<.001,"rendered wings share actual arrow tip")
    local origin=(head1+head2)*.5-tangent*(arrow*8+3)
    check(math.abs((origin-course.Samples[index]):Dot(laneRight)-definition.RoadWidth*.25*lane)<.001,"actual arrow origin at lane center +/-12 studs")
    local dot=((head1+head2-tail1-tail2)*.5).Unit:Dot(expected)
    minimumDot=math.min(minimumDot,dot)
    check(dot>=.98,"rendered arrow tip aligns with actual forward tangent; no reverse/lateral arrows")
    table.insert(directionProof,{sample=index,kind=if not isCurve then "STRAIGHT" elseif a:Cross(b).Y>0 then "LEFT CURVE" else "RIGHT CURVE",
     expected={expected.X,expected.Z},actual={((head1+head2-tail1-tail2)*.5).Unit.X,((head1+head2-tail1-tail2)*.5).Unit.Z},dot=dot})
   end
   for _, part in cluster:GetChildren() do
    check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow,"chevron visual only")
    check(part.Position.Y>0.1 and part.Position.Y<0.2,"raised thin chevron prevents z fighting")
    for _,vertex in footprint(part) do
     local lateral=(vertex-course.Samples[index]):Dot(laneRight)*lane
     check(lateral>8 and lateral<16,"entire cue stays in its lane, clear of center divider and outer edge")
    end
   end
   for _, gate in gates:GetChildren() do
    check((rb.Vector2.new(gate.Position.X,gate.Position.Z)-rb.Vector2.new(course.Samples[index].X,course.Samples[index].Z)).Magnitude>28,"chevron clears gates and finish checker")
   end
  end
  check(straightClusters>0 and curveClusters>0 and startMarker,"forward markings cover straights, curves and immediate start")
  local stationCount=0
  for _,lanes in stationLanes do
   check(lanes[-1] and lanes[1],"each existing station has exactly two lane-center cues")
   stationCount+=1
  end
  check(stationCount==47 and #markers:GetChildren()==94,"47 original stations times two lane cues")
  check(world:GetAttribute("ChevronPartCount")==564,"94 clusters contain 564 native wing Parts")
  print(string.format("R3C forward clusters: %d straight %d curve; start true; dot %.6f",straightClusters,curveClusters,minimumDot))
  if require("@lune/process").args[1]=="Report" then
   fs.writeFile("artifacts/r7-a1-r3c-lane-centres/direction-proof.json",require("@lune/serde").encode("json",directionProof))
  end
  local samples,n=course.Samples,#course.Samples
  local function turn(index)
   local a=(samples[index]-samples[(index-2)%n+1]).Unit
   local b=(samples[index%n+1]-samples[index]).Unit
   return math.acos(math.clamp(a:Dot(b),-1,1)),if a:Cross(b).Y>0 then -1 else 1
  end
  for _,fraction in definition.MajorDriftFractions do
   local center=math.round(fraction*n)+1
   local _,side=turn(center)
   local first,last=center,center
   while first>4 do local angle,sign=turn(first-1);if angle<math.atan(14/350) or sign~=side then break end;first-=1 end
   while last<n-3 do local angle,sign=turn(last+1);if angle<math.atan(14/350) or sign~=side then break end;last+=1 end
   first-=2;last+=2
   table.insert(majorRanges,{first,last})
   table.insert(exitRanges,{math.floor(first+(last-first)*.75),last+math.ceil(60/14)})
  end
  check(#majorRanges==3,"three major shoulder/exit envelopes")
  for _,trigger in world:FindFirstChild("BarrierTriggers"):GetChildren() do
   local index=trigger:GetAttribute("BarrierIndex")
   local major=false
   for _,range in majorRanges do if index>=range[1] and index<=range[2] then major=true end end
   local corners={}
   for _,coordinate in {{-1,-1},{-1,1},{1,1},{1,-1}} do
    local vertex=trigger.CFrame:PointToWorldSpace(rb.Vector3.new(trigger.Size.X/2*coordinate[1],0,trigger.Size.Z/2*coordinate[2]))
    table.insert(corners,rb.Vector3.new(vertex.X,0,vertex.Z))
   end
   local nearest=math.huge
   for segment,point in samples do
    for edge=1,4 do nearest=math.min(nearest,segmentDistance(point,samples[segment%n+1],corners[edge],corners[edge%4+1])) end
   end
   local shoulder=nearest-definition.RoadWidth/2
   check(shoulder>=(if major then 16 else 12),"entire trigger footprint clears required shoulder, all centerline segments")
   if major then majorShoulder=math.min(majorShoulder,shoulder) else normalShoulder=math.min(normalShoulder,shoulder) end
   for _,range in exitRanges do
    check(index<range[1] or index>range[2],"no triggers along last quarter major arc plus 60-stud exit")
    for segment=range[1],range[2] do for edge=1,4 do
     local distance=segmentDistance(samples[segment],samples[segment%n+1],corners[edge],corners[edge%4+1])-definition.RoadWidth/2
     exitMinimum=math.min(exitMinimum,distance)
     check(distance>=18,"trigger volume does not intrude neighboring Drift exit envelope")
    end end
   end
  end
  print(string.format("Hard shoulders: normal %.2f major %.2f exit %.2f; arrow min dot %.6f",normalShoulder,majorShoulder,exitMinimum,minimumDot))
  -- Probe three normal racing lines against the real generated trigger boxes.
  for _, trigger in world:FindFirstChild("BarrierTriggers"):GetChildren() do
   for index, point in course.Samples do
    local tangent=geometry.getTangentAtFraction(course.Samples,(index-1)/#course.Samples)
    local right=rb.Vector3.new(-tangent.Z,0,tangent.X)
    for _, side in {-1,0,1} do
     local line=point+right*(definition.RoadWidth/2-4)*side
     local localPoint=trigger.CFrame:PointToObjectSpace(line)
     check(math.abs(localPoint.X)>trigger.Size.X/2+3 or math.abs(localPoint.Z)>trigger.Size.Z/2+3,"barrier clears inside/center/outside normal line plus kart footprint")
    end
   end
  end
  -- Every long low-curvature corridor has repeated cues, never an unmarked Nitro straight.
  local run={}
  local function verifyStraight()
   if #run*definition.SampleSpacing>=150 then
    local nearby=0
    for _,part in cueParts do
     if part.Name:find("Pole") or part.Name:find("Pylon") or part.Name:find("SignPost") then
      local nearest=nearestSampleIndex(part)
      if nearest>=run[1] and nearest<=run[#run] then nearby+=1 end
     end
    end
    check(nearby>=(if #run*definition.SampleSpacing>=300 then 3 else 2),"meaningful straight repeated speed cues")
   end
   run={}
  end
  for index,point in course.Samples do
   local a=(point-course.Samples[(index-2)%#course.Samples+1]).Unit
   local b=(course.Samples[index%#course.Samples+1]-point).Unit
   if math.acos(math.clamp(a:Dot(b),-1,1))<math.rad(1) then table.insert(run,index) else verifyStraight() end
  end
  verifyStraight()
  local renderer=luau.load(fs.readFile("src/client/TrackMapRenderer.luau"),{environment=env})()
  local previewEvidence={}
  for _,racing in {false,true} do
   local panel=object("Frame")
   local catalog=luau.load(fs.readFile("src/shared/TrackCatalog.luau"),{environment={CFrame=frames}})()
   local rotation=catalog.Entries.Track03.PreviewRotationDegrees
   local calculated=180+math.deg(math.atan2(course.StartTangent.X,-course.StartTangent.Z))
   check(math.abs(rotation-calculated)<1e-5,"Hard heading calculated from actual start tangent")
   local view=renderer.create(panel,definition,racing,rotation)
   local canvas=panel:FindFirstChild("CourseCanvas")
   local mark=canvas:FindFirstChild("StartFinishMarker")
   local rows={}
   if racing then
    view:setMarkerWorldPosition(course.StartPosition)
    local first=canvas:FindFirstChild("KartPosition").Position
    view:setMarkerWorldPosition(course.StartPosition+course.StartTangent*50)
    local second=canvas:FindFirstChild("KartPosition").Position
    local dx,dy=second.X.Scale-first.X.Scale,second.Y.Scale-first.Y.Scale
    check(dy<0 and -dy>math.abs(dx),"actual minimap transform sends forward 50 studs screen-up")
    print(string.format("Hard minimap heading: rotation %.6f dx %.9f dy %.6f",rotation,dx,dy))
   end
   check(mark~=nil,"real V2 renderer creates start marker")
   check(mark.Position.X.Scale>0 and mark.Position.X.Scale<1 and mark.Position.Y.Scale>0 and mark.Position.Y.Scale<1,"V2 start marker inside preview/minimap")
   for _,line in canvas:GetChildren() do if line.Name=="CourseSegment" then
    check(line.Position.X.Scale>=.015 and line.Position.X.Scale<=.985 and line.Position.Y.Scale>=.015 and line.Position.Y.Scale<=.985,"full V2 silhouette fits real generic renderer")
    table.insert(rows,{x=line.Position.X.Scale,y=line.Position.Y.Scale,length=line.Size.X.Scale,rotation=line.Rotation})
   end end
   check(#rows==#course.Samples,"actual sampled curve rendered without truncation")
   previewEvidence[if racing then "minimap" else "garage"]={segments=rows,start={mark.Position.X.Scale,mark.Position.Y.Scale},padding=if racing then 1.14 else 1.04}
   view:destroy()
   check(panel:FindFirstChild("CourseCanvas")==nil,"real renderer lifecycle cleanup")
  end
  if require("@lune/process").args[1]=="Report" then
   fs.writeFile("artifacts/r7-a1-r3c-lane-centres/map-preview-evidence.json",require("@lune/serde").encode("json",previewEvidence))
  end
  print(string.format("V2 budget: Road=%d Kerbs=%d Barriers=%d ChevronClusters=%d ChevronParts=%d SpeedObjects=%d SpeedParts=%d VisualParts=%d",#course.Samples,world:GetAttribute("KerbPartCount"),world:GetAttribute("BarrierPartCount"),world:GetAttribute("ChevronClusterCount"),world:GetAttribute("ChevronPartCount"),objects,parts,world:GetAttribute("VisualPartCount")))
 end
 check(builder.build(prototype,track,0)==world,id.." current cache reused")
 local function signature(root, frozen)
  local rows={}
  local function visit(node,path)
   for _,child in node:GetChildren() do
    local childPath=path.."/"..child.Name
    if frozen and (child.Name=="Kerbs" or child.Name=="DirectionMarkers" or (frozen=="gameplay" and child.Name=="Environment")) then continue end
    if child:IsA("BasePart") then
     table.insert(rows,childPath..tostring(child.CFrame)..tostring(child.Size)..tostring(child.Color)..tostring(child.Material))
    elseif child.ClassName=="TextLabel" then table.insert(rows,childPath..child.Text) end
    visit(child,childPath)
   end
  end
  visit(root,"")
  return table.concat(rows,"\n")
 end
 local expectedSignature=signature(world)
 if isV2 then
  local frozen=require("@lune/serde").hash("sha256",signature(world,true))
  check(frozen=="32af549655290265ed043ccc0ec702a75b830a36177e8d616166c80f3926be5b","all R3B road/barrier/trigger/ground/checkpoint/scenery output frozen")
 end
 if id=="PrototypeCircuitV2" or id=="PracticeCircuitV1" then
  local result=require("@lune/process").exec("git",{"show","647be04b28e63f23e2826cfb0bc1e50b9cad2232:src/server/TrackBuilder.luau"})
  assert(result.ok)
  local baseline=luau.load(result.stdout,{environment=env})().build(object("Folder"),track,0)
  -- K1 intentionally replaces legacy kerbs/scenery. Preserve the exact road,
  -- markings, visible barriers and all race/barrier triggers independently.
  check(signature(baseline,"gameplay")==signature(world,"gameplay"),"Legacy gameplay output exactly matches accepted baseline")
  print(id.." gameplay output SHA256",require("@lune/serde").hash("sha256",signature(world,"gameplay")))
 end
 if require("@lune/process").args[1]=="Report" and isV2 then
  local rows={} local surfaceGuis,textLabels=0,0
  local function inspect(node)
   for _,child in node:GetChildren() do
    if child:IsA("BasePart") then table.insert(rows,{color={child.Color.R,child.Color.G,child.Color.B},attrs={row=child:GetAttribute("KerbRow"),side=child:GetAttribute("KerbSide"),first=child:GetAttribute("FirstSegment"),last=child:GetAttribute("LastSegment")},name=child.Name,position={child.Position.X,child.Position.Y,child.Position.Z},size={child.Size.X,child.Size.Y,child.Size.Z},right={child.CFrame.RightVector.X,child.CFrame.RightVector.Y,child.CFrame.RightVector.Z},forward={child.CFrame.LookVector.X,child.CFrame.LookVector.Y,child.CFrame.LookVector.Z}}) end
    if child.ClassName=="SurfaceGui" then surfaceGuis+=1 end
    if child.ClassName=="TextLabel" then textLabels+=1 end
    inspect(child)
   end
  end
  inspect(world)
  local clusters={}
  for _,cluster in world:FindFirstChild("DirectionMarkers"):GetChildren() do
   table.insert(clusters,{sample=cluster:GetAttribute("SampleIndex")})
  end
  fs.writeFile("artifacts/r7-a1-r3c-lane-centres/build-evidence.json",require("@lune/serde").encode("json",{attributes=world.attrs,parts=rows,clusters=clusters,surfaceGuis=surfaceGuis,textLabels=textLabels,left=left,right=right,minimumDot=minimumDot,normalShoulder=normalShoulder,majorShoulder=majorShoulder,exitMinimum=exitMinimum,majorRanges=majorRanges,exitRanges=exitRanges}))
 end
 world:SetAttribute("EnvironmentCueVersion",if isV2 then 2 else 0)
 local rebuilt=builder.build(prototype,track,0)
 check(rebuilt~=world and rebuilt:GetAttribute("SpeedCuePartCount")==parts,id.." stale cache rebuilt deterministically")
 check(signature(rebuilt)==expectedSignature,id.." deterministic full scenery/road/gate transforms and text")
end
print("PASS: "..count.." track cue, cache and geometry checks")
