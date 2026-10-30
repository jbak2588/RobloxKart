-- Reusable, fixed-budget UI triangle. No font metrics, images or runtime assets.
local Marker={}
function Marker.rotation(direction,mapRotationDegrees)
 if not direction then return nil end
 local x,z=direction.X,direction.Z
 if x~=x or z~=z or math.abs(x)==math.huge or math.abs(z)==math.huge or x*x+z*z<1e-10 then return nil end
 -- mapPoint projects world +Z upward; GuiObject rotation is clockwise.
 return math.deg(math.atan2(x,z))+(mapRotationDegrees or 0)
end
function Marker.new(parent,name,zIndex)
 local root=Instance.new('Frame');root.Name=name;root.AnchorPoint=Vector2.new(.5,.5)
 root.Size=UDim2.fromOffset(14,14);root.BackgroundTransparency=1;root.BorderSizePixel=0
 root.Active=false;root.ZIndex=zIndex or 4;root.Rotation=0
 root:SetAttribute('DirectionMarkerVersion',1)
 local function row(name,width,y,color,z)
  local p=Instance.new('Frame');p.Name=name;p.AnchorPoint=Vector2.new(.5,0)
  p.Position=UDim2.fromOffset(7,y);p.Size=UDim2.fromOffset(width,1)
  p.BackgroundColor3=color;p.BorderSizePixel=0;p.Active=false;p.ZIndex=z;p.Parent=root
 end
 -- Upward isosceles triangle with a bright inset border, baked once in UI rows.
 for y=0,11 do
  row('Outline',y+1,y+1,Color3.fromRGB(240,250,255),root.ZIndex)
  if y>=3 and y<11 then row('Fill',y-2,y+1,Color3.fromRGB(65,225,245),root.ZIndex+1)end
 end
 root.Parent=parent
 return root
end
function Marker.update(root,direction,mapRotationDegrees)
 local rotation=Marker.rotation(direction,mapRotationDegrees)
 if rotation then root.Rotation=rotation end
end
return Marker
