local View={}
function View.new(parent,canShow,onPlay)
 local gui=Instance.new('ScreenGui');gui.Name='KDMLobbyPostDrive';gui.ResetOnSpawn=false
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=40;gui.Enabled=false;gui.Parent=parent
 local shade=Instance.new('TextButton');shade.Name='Modal';shade.Size=UDim2.fromScale(1,1)
 shade.BackgroundColor3=Color3.new();shade.BackgroundTransparency=.35;shade.Text='';shade.AutoButtonColor=false;shade.Active=true;shade.Modal=true;shade.Parent=gui
 local panel=Instance.new('Frame');panel.Name='Panel';panel.AnchorPoint=Vector2.new(.5,.5)
 panel.Position=UDim2.fromScale(.5,.5);panel.BackgroundColor3=Color3.fromRGB(18,32,49);panel.BorderSizePixel=0;panel.Active=true;panel.Parent=shade
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,14);corner.Parent=panel
 local stroke=Instance.new('UIStroke');stroke.Color=Color3.fromRGB(111,211,245);stroke.Thickness=2;stroke.Parent=panel
 local function text(name,value,y,height,maxSize)
  local label=Instance.new('TextLabel');label.Name=name;label.Text=value;label.BackgroundTransparency=1
  label.Position=UDim2.fromOffset(20,y);label.Size=UDim2.new(1,-40,0,height)
  label.Font=Enum.Font.GothamBold;label.TextColor3=Color3.fromRGB(238,246,255);label.TextWrapped=true;label.TextScaled=true;label.Parent=panel
  local limit=Instance.new('UITextSizeConstraint');limit.MinTextSize=12;limit.MaxTextSize=maxSize;limit.Parent=label
  return label
 end
 text('Title','Enjoyed your test drive?',20,36,24)
 local body=text('Message','Now race against players from around the world! Put your drifting skills and item strategies to the test, climb the rankings, and earn rewards.',68,144,17)
 body.Font=Enum.Font.Gotham
 local self={gui=gui}
 function self:hide() gui.Enabled=false end
 local function button(name,label,x,color)
  local b=Instance.new('TextButton');b.Name=name;b.Text=label;b.AnchorPoint=Vector2.new(0,1)
  b.Position=UDim2.new(x,if x==0 then 20 else 6,1,-20);b.Size=UDim2.new(.5,-26,0,46)
  b.BackgroundColor3=color;b.TextColor3=Color3.fromRGB(12,27,42);b.Font=Enum.Font.GothamBold;b.TextSize=17;b.BorderSizePixel=0;b.Parent=panel
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=b
  return b
 end
 local play=button('PlayNow','Play now',0,Color3.fromRGB(255,209,55))
 local later=button('Later','Later',.5,Color3.fromRGB(111,211,245))
 play.Activated:Connect(function()
  if not gui.Enabled then return end
  local valid=canShow();self:hide();if valid then onPlay() end
 end)
 later.Activated:Connect(function() self:hide() end)
 function self:update()
  if not gui.Enabled then return end
  if not canShow() then self:hide();return end
  local size=shade.AbsoluteSize
  local height=math.min(300,math.max(0,size.Y-24))
  panel.Size=UDim2.fromOffset(math.min(520,math.max(0,size.X-24)),height)
  body.Size=UDim2.new(1,-40,0,math.max(0,height-154))
 end
 function self:show()
  if not canShow() then return end
  gui.Enabled=true;self:update()
 end
 function self:destroy() gui:Destroy() end
 return self
end
return View
