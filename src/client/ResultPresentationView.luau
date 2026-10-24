-- Shared result appearance and FINISH banner; gameplay/actions stay with their owners.
local View={}
View.PanelColor=Color3.fromRGB(70,110,135)
View.ButtonColor=Color3.fromRGB(115,205,230)
function View.panel(panel)
 panel.BackgroundColor3=View.PanelColor;panel.BackgroundTransparency=.4;panel.BorderSizePixel=0
 local corner=panel:FindFirstChildOfClass('UICorner')or Instance.new('UICorner');corner.CornerRadius=UDim.new(0,16);corner.Parent=panel
 local stroke=panel:FindFirstChildOfClass('UIStroke')or Instance.new('UIStroke');stroke.Color=Color3.fromRGB(210,245,255);stroke.Thickness=2;stroke.Parent=panel
end
function View.button(button)
 button.BackgroundColor3=View.ButtonColor;button.BackgroundTransparency=.25;button.BorderSizePixel=0;button.TextColor3=Color3.new(1,1,1)
 local corner=button:FindFirstChildOfClass('UICorner')or Instance.new('UICorner');corner.CornerRadius=UDim.new(0,8);corner.Parent=button
end
function View.banner(parent)
 local banner=Instance.new('TextLabel');banner.Name='FinishBanner';banner.Text='';banner.BackgroundTransparency=1
 banner.AnchorPoint=Vector2.new(.5,.5);banner.Position=UDim2.fromScale(.5,.42);banner.Size=UDim2.fromOffset(400,82);banner.Visible=false;banner.Parent=parent
 for row=0,2 do for column=0,15 do
  local tile=Instance.new('Frame');tile.Name='FinishChecker';tile.BorderSizePixel=0
  tile.Position=UDim2.fromScale(column/16,row/3);tile.Size=UDim2.fromScale(1/16,1/3)
  tile.BackgroundColor3=if (row+column)%2==0 then Color3.new(1,1,1)else Color3.new(0,0,0)
  tile.BackgroundTransparency=if column==0 or column==15 then .8 elseif column==1 or column==14 then .5 else .12
  tile.ZIndex=2;tile.Parent=banner
 end end
 local text=Instance.new('TextLabel');text.Name='FinishText';text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
 text.Text='FINISH!';text.AutoLocalize=false;text.Font=Enum.Font.GothamBlack;text.TextColor3=Color3.new(1,1,1);text.TextScaled=true;text.ZIndex=3;text.Parent=banner
 local outline=Instance.new('UIStroke');outline.Name='FinishOutline';outline.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual;outline.Color=Color3.new(0,0,0);outline.Thickness=3;outline.Transparency=0;outline.Parent=text
 local scale=Instance.new('UIScale');scale.Parent=banner
 local place=Instance.new('TextLabel');place.Name='FinishPlace';place.Position=UDim2.new(0,0,1,4);place.Size=UDim2.new(1,0,0,24)
 place.BackgroundTransparency=1;place.Font=Enum.Font.GothamBold;place.Text='';place.TextSize=20;place.TextColor3=Color3.fromRGB(255,218,75);place.Parent=banner
 return banner,scale,place
end
return View
