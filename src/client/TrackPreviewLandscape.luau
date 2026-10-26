-- Park's curated maple and the exact low plant prefabs beside the Hub Lobby.
local RS=game:GetService('ReplicatedStorage')
local Plan=require(RS.Shared.TrackPlantingLayout)
local Road=require(RS.Shared.MetroCityLayout)
local Landscape={}
local function foot(prefab,maple)
 local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,p in prefab:GetDescendants()do if p:IsA('BasePart')then
  for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
   local v=p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)/2)
   lo=Vector3.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
   hi=Vector3.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
  end end end
 end end
 local y=lo.Y
 if maple then local t=prefab.Trunk;y=t.CFrame:PointToWorldSpace(Vector3.new(0,-t.Size.Y/2,0)).Y+2 end
 return Vector3.new((lo.X+hi.X)/2,y,(lo.Z+hi.Z)/2),Vector2.new(hi.X-lo.X,hi.Z-lo.Z).Magnitude/2
end
function Landscape.build(parent,track,samples,width,groundY,safe)
 local assets=RS:WaitForChild('KDMHubForestTreePrefabs');local maple=assets.CityMaple
 local base,radius=foot(maple,true)
 local occupied={}
 for _,p in parent:GetChildren()do local center=p:GetAttribute('PlantCenter')
  if center then table.insert(occupied,{x=center.X,z=center.Z,scale=p:GetAttribute('PlantScale')})end
 end
 local sites=Plan.plan(track:GetAttribute('TrackId'),samples,width,radius,Road.roadDistance,occupied)
 local folder=Instance.new('Folder');folder.Name='PreviewGroves';folder.Parent=parent
 local function plant(prefab,name,point,scale,yaw,isMaple)
  local origin=if isMaple then base else foot(prefab,false)
  local clone=prefab:Clone();clone.Name=name
  local frame=CFrame.new(point-Vector3.yAxis*.2)*CFrame.Angles(0,yaw,0)
  for _,p in clone:GetDescendants()do if p:IsA('BasePart')then
   local old=p.CFrame;p.Size*=scale;p.CFrame=frame*CFrame.new((old.Position-origin)*scale)*old.Rotation;safe(p)
  elseif p:IsA('Script')or p:IsA('LocalScript')then p:Destroy()end end
  clone:SetAttribute('PlantScale',scale);clone:SetAttribute('PlantYaw',yaw)
  clone:SetAttribute('RootGroundY',groundY-.2);clone:SetAttribute('CuratedPrefab',prefab.Name)
  clone.Parent=folder;return clone
 end
 local flowers=0
 for i,s in sites do
  local point=Vector3.new(s.x,groundY,s.z)
  local tree=plant(maple,'PreviewMaple'..i,point,s.scale,s.yaw,true)
  tree:SetAttribute('CanopyShoulder',Road.roadDistance(samples,s.x,s.z)-radius*s.scale-width/2)
  -- Same flowering rhododendron, laurel and fern mix as the two Lobby beds.
  for j,name in {'CityRhododendron','CityLaurel','CityFern'}do
   local angle=s.yaw+j*2.094395;local p=point+Vector3.new(math.cos(angle),0,math.sin(angle))*(13+j*2)
   if Road.roadDistance(samples,p.X,p.Z)>=width/2+18 then
    plant(assets[name],'LobbyPlant'..i..'_'..j,p,.55+(i*j%4)*.08,angle,false);flowers+=1
   end
  end
 end
 parent:SetAttribute('PreviewMapleCount',#sites);parent:SetAttribute('LobbyPlantCount',flowers)
end
return Landscape
