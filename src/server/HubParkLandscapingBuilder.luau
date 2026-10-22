-- PARK-A2: small static planting pass using curated prefabs, only in opt-in HUBs.
local Builder={}
function Builder.build(root,origin,trees,mountains)
 local existing=root:FindFirstChild('ParkLandscaping');if existing then return existing end
 local folder=Instance.new('Folder');folder.Name='ParkLandscaping';folder.Parent=root
 local function static(p)
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  -- Preserve the curated asset's LOD. RenderFidelity is editor-write-only.
 end
 local function foot(model)
  local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
  for _,p in model:GetDescendants()do if p:IsA('BasePart')then
   for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do
    local v=p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)/2)
    lo=Vector3.new(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z))
    hi=Vector3.new(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))
   end end end
  end end
  return Vector3.new((lo.X+hi.X)/2,lo.Y,(lo.Z+hi.Z)/2)
 end
 local treeSites={
  {-145,-25,.85,15,'NaturalTreeA'},{145,-25,.9,-25,'NaturalTreeB'},
  {-180,-245,1.1,35,'NaturalTreeA'},{175,-245,1.15,-40,'NaturalTreeB'},
  {-410,-285,1,70,'NaturalTreeA'},{455,-405,1,10,'NaturalTreeB'},
  {-530,-825,1.1,-20,'NaturalTreeA'},{270,-1010,1.2,45,'NaturalTreeB'},
 }
 for i,s in treeSites do
  local prefab=trees and trees:FindFirstChild(s[5])
  if prefab then
   local model=prefab:Clone();model.Name='ParkTree'..i
   local base=foot(model);local target=CFrame.new(origin+Vector3.new(s[1],-.2,s[2]))*CFrame.Angles(0,math.rad(s[4]),0)
   for _,p in model:GetDescendants()do
    if p:IsA('BasePart')then
     local frame=p.CFrame;p.Size*=s[3]
     p.CFrame=target*CFrame.new((frame.Position-base)*s[3])*frame.Rotation;static(p)
    elseif not (p:IsA('Model')or p:IsA('Folder')or p:IsA('SurfaceAppearance'))then p:Destroy()end
   end
   model:SetAttribute('CuratedPrefab',s[5]);model.Parent=folder
  end
 end
 -- The existing asset manifest identifies this same leaf mesh as OB_Bush_a.
 local leaf=trees and trees:FindFirstChild('NaturalTreeA');leaf=leaf and leaf:FindFirstChild('Leaves')
 for i,s in {{-120,-35},{120,-35},{-155,-225},{190,-265},{-410,-305},{450,-420}}do
  if leaf then local p=leaf:Clone();p.Name='ParkShrub'..i;p.Size=Vector3.new(9,7,9)
   p.CFrame=CFrame.new(origin+Vector3.new(s[1],3.3,s[2]))*CFrame.Angles(0,i*.7,0);static(p);p.Parent=folder
  end
 end
 for i,s in {{-150,-60},{150,-60},{-200,-250},{440,-400},{-525,-800}}do
  local p=Instance.new('WedgePart');p.Name='ParkRock'..i;p.Size=Vector3.new(12,8,10)
  p.CFrame=CFrame.new(origin+Vector3.new(s[1],3.7,s[2]))*CFrame.Angles(0,i*.9,0)
  p.Material=Enum.Material.Slate;p.Color=Color3.fromRGB(115,121,115);static(p);p.Parent=folder
 end
 for i,s in {{500,-1080,180,65,150,'HorizonMountainA'},{-570,-970,150,60,150,'HorizonMountainB'},{40,-1100,200,65,150,'HorizonMountainA'}}do
  local prefab=mountains and mountains:FindFirstChild(s[6])
  if prefab then local p=prefab:Clone();p.Name='ParkBackdropHill'..i;p.Size=Vector3.new(s[3],s[4],s[5])
   p.CFrame=CFrame.new(origin+Vector3.new(s[1],s[4]/2-2.2,s[2]));static(p);p.Parent=folder
  end
 end
 return folder
end
return Builder
