-- Client-only asphalt polygons share edges. No overlapping rectangular end caps.
local RS=game:GetService('ReplicatedStorage')
local Geometry=require(RS.Shared.TrackGeometry)
local Park=require(RS.Shared.HubParkRookieLoopLayout)
local Standard=require(RS.Shared.TrackSurfaceStandard)
local Ribbon={}
function Ribbon.matte(part,tint)
 tint=tint or Standard.RoadTint
 part.Color=tint
 -- Preserve Desert albedo, remove its wet PBR response on the two rejected roads.
 part.Material=Enum.Material.Concrete;part.MaterialVariant='';part.Reflectance=0
 local t=Instance.new('Texture');t.Name='DesertMatteAlbedo'
 t.Texture='rbxassetid://15217440826';t.Color3=tint
 t.Face=if part:IsA('WedgePart')then(if part.CFrame.RightVector.Y>0 then Enum.NormalId.Right else Enum.NormalId.Left)else Enum.NormalId.Top
 t.StudsPerTileU=24;t.StudsPerTileV=24;t.Parent=part
 return t
end
function Ribbon.triangle(parent,a,b,c,variant,tint)
 local ab,ac,bc=b-a,c-a,c-b
 if ab:Dot(ab)>ac:Dot(ac)and ab:Dot(ab)>bc:Dot(bc)then c,a=a,c
 elseif ac:Dot(ac)>bc:Dot(bc)then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 if ac:Cross(ab).Magnitude<.00001 then return 0 end
 local right=ac:Cross(ab).Unit;local back=bc.Unit;local up=back:Cross(right)
 local h=math.abs(ab:Dot(up));local count=0
 for _,s in {{a,b,right,back},{a,c,-right,-back}}do
  local length=math.abs((s[2]-s[1]):Dot(back))
  if length<.00001 then continue end
  local p=Instance.new('WedgePart');p.Name='AsphaltFace'
  p.Size=Vector3.new(.01,h,length);p.CFrame=CFrame.fromMatrix((s[1]+s[2])/2,s[3],up,s[4])
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  Ribbon.matte(p,tint);p.Parent=parent;count+=1
 end
 return count
end
function Ribbon.build(model,track,park,variant)
 local points={};local half,y
 if park then
  local origin=track:GetAttribute('Origin');y=origin.Y+.015
  for _,p in Park.sample(Park.Segments)do table.insert(points,origin+Vector3.new(p.x,0,p.z))end
  table.remove(points) -- duplicate closing station
  half=(Park.RoadWidth+2*Park.KerbWidth+1)/2
 else
  points=Geometry.getCourse(Geometry.getDefinition(track:GetAttribute('GeometryId'))).Samples
  local ground=track:FindFirstChild('SafetyGround');y=(if ground then ground.Position.Y+ground.Size.Y/2 else 0)+.060
  half=track:GetAttribute('RoadWidth')/2
 end
 -- Collapse exactly collinear interior stations. Curves retain every source sample.
 local kept={}
 for i,p in points do
  local a,b=points[(i-2)%#points+1],points[i%#points+1]
  if (p-a).Unit:Dot((b-p).Unit)<.99999999 then table.insert(kept,p)end
 end
 local edges={}
 for i,p in kept do
  local before=(p-kept[(i-2)%#kept+1]).Unit;local after=(kept[i%#kept+1]-p).Unit
  local n1,n2=Vector3.new(-before.Z,0,before.X),Vector3.new(-after.Z,0,after.X)
  local normal=(n1+n2).Unit;local offset=normal*(half/math.max(.5,normal:Dot(n2)))
  local center=Vector3.new(p.X,y,p.Z);edges[i]={center-offset,center+offset}
 end
 local count=0;local batch
 for i,a in edges do
  if (i-1)%64==0 then batch=Instance.new('Folder');batch.Name='AsphaltBatch' end
  local b=edges[i%#edges+1]
  count+=Ribbon.triangle(batch,a[1],b[1],b[2],variant,if park then Standard.ParkRoadTint else nil)
  count+=Ribbon.triangle(batch,a[1],b[2],a[2],variant,if park then Standard.ParkRoadTint else nil)
  if i%64==0 or i==#edges then batch.Parent=model end
 end
 model:SetAttribute('SharedEdgeRoadFaces',count)
end
return Ribbon
