-- Cosmetic envelope only; native SpawnLocation ForceField has no Size contract.
local Geometry={}
function Geometry.measure(kart,chassis,character)
 local points={}
 local function add(part)
  for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
   table.insert(points,chassis.CFrame:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*.5)))
  end end end
 end
 add(chassis)
 local visual=kart:FindFirstChild("Visual")
 if visual then for _,p in visual:GetDescendants() do if p:IsA("BasePart") then add(p) end end end
 if character then for _,p in character:GetChildren() do if p:IsA("BasePart") then add(p) end end end
 local low,high=points[1],points[1]
 for _,p in points do low=Vector3.new(math.min(low.X,p.X),math.min(low.Y,p.Y),math.min(low.Z,p.Z));high=Vector3.new(math.max(high.X,p.X),math.max(high.Y,p.Y),math.max(high.Z,p.Z)) end
 local center=(low+high)*.5
 local size=high-low+Vector3.new(1.2,1.2,1.2)
 size=Vector3.new(math.max(14,size.X),math.max(11,size.Y),math.max(16,size.Z))
 local scale=1
 for _,p in points do local n=(p-center)/(size*.5);scale=math.max(scale,n.Magnitude*1.03) end
 return size*scale,center
end
return Geometry
