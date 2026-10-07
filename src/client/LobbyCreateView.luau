local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local Catalog=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LobbyTitleCatalog"))
local Theme=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KDMUiTheme"))
local View={}

function View.new(panel,submit)
 local frame=Instance.new("Frame")
 frame.Name="CreateLobbyModal";frame.Size=UDim2.fromScale(1,1);frame.BackgroundColor3=Theme.Panel;frame.BorderSizePixel=0;frame.ZIndex=40;frame.Visible=false;frame.Active=true;frame.Parent=panel
 local function text(name,value,y,height)
  local label=Instance.new("TextLabel");label.Name=name;label.Text=value;label.Font=Enum.Font.GothamBold;label.TextSize=14
  label.TextColor3=Theme.TextPrimary;label.BackgroundTransparency=1;label.Position=UDim2.fromOffset(12,y);label.Size=UDim2.new(1,-24,0,height);label.ZIndex=41;label.Parent=frame
  return label
 end
 local heading=text("Heading","CREATE RACE LOBBY",4,38);heading.TextSize=20
 local body=Instance.new("ScrollingFrame");body.Name="Content";body.Position=UDim2.fromOffset(0,44);body.Size=UDim2.new(1,0,1,-104)
 body.BackgroundTransparency=1;body.BorderSizePixel=0;body.ScrollBarThickness=4;body.CanvasSize=UDim2.fromOffset(0,176);body.ZIndex=41;body.Parent=frame
 local fieldLabel=text("TitleLabel","LOBBY NAME (OPTIONAL)",0,20);fieldLabel.Parent=body
 local input=Instance.new("TextBox");input.Name="LobbyTitleInput";input.PlaceholderText="Your Lobby Name";input.Text="";input.ClearTextOnFocus=false;input.MultiLine=false
 input.AutoLocalize=false;input.TextSize=18;input.Font=Enum.Font.Gotham;input.TextColor3=Theme.TextPrimary;input.PlaceholderColor3=Theme.TextSecondary
 input.BackgroundColor3=Theme.Background;input.Position=UDim2.fromOffset(12,24);input.Size=UDim2.new(1,-24,0,40);input.ZIndex=42;input.Parent=body
 local count=text("CharacterCount","0 / 32",65,16);count.TextSize=12;count.TextColor3=Theme.TextSecondary;count.TextXAlignment=Enum.TextXAlignment.Right;count.Parent=body
 local hint=text("Hint","Leave blank to use your racer name.",82,16);hint.TextColor3=Theme.TextSecondary;hint.TextSize=12;hint.Parent=body
 local quick=text("QuickTitles","QUICK TITLES",99,16);quick.Parent=body
 local function button(name,value,x,y,width,parent)
  local b=Instance.new("TextButton");b.Name=name;b.Text=value;b.Font=Enum.Font.GothamBold;b.TextSize=14;b.TextWrapped=true
  b.BackgroundColor3=Theme.Background;b.TextColor3=Theme.TextPrimary;b.BorderSizePixel=0;b.Position=UDim2.new(x,12,y,0);b.Size=UDim2.new(width,-16,0,44);b.ZIndex=42;b.Parent=parent
  return b
 end
 local presets={};local selected
 for index,id in Catalog.Order do
  local b=button(id,Catalog.Presets[id],(index-1)/3,0,1/3,body);b.Position=UDim2.new((index-1)/3,12,0,116);b.AutoLocalize=false
  b.Activated:Connect(function() selected=id;input.Text=Catalog.Presets[id] end);presets[id]=b
 end
 local create=button("Create","CREATE",0,1,.5,frame);create.Position=UDim2.new(0,12,1,-54);create.BackgroundColor3=Theme.PrimaryAction;create.TextColor3=Theme.Background
 local cancel=button("Cancel","CANCEL",.5,1,.5,frame);cancel.Position=UDim2.new(.5,4,1,-54)
 local changing=false;local pending=false
 local function update()
  if changing then return end
  local length=utf8.len(input.Text)
  if not length then changing=true;input.Text="";changing=false;length=0 end
  if length>Catalog.MAX_CODEPOINTS then
   changing=true;input.Text=input.Text:sub(1,utf8.offset(input.Text,Catalog.MAX_CODEPOINTS+1)-1);changing=false;length=Catalog.MAX_CODEPOINTS
  end
  if selected and input.Text~=Catalog.Presets[selected] then selected=nil end
  count.Text=string.format("%d / %d",length,Catalog.MAX_CODEPOINTS)
  for id,b in presets do b.BackgroundColor3=if id==selected then Theme.Selection else Theme.Background end
 end
 local connection=input:GetPropertyChangedSignal("Text"):Connect(update)
 local function close() input:ReleaseFocus();frame.Visible=false end
 local function send()
  if pending or not frame.Visible then return end
  local title=Catalog.normalize(input.Text)
  if not title then return end
  local mode,value="CUSTOM",input.Text
  if title=="" then mode,value="DEFAULT",nil
  elseif selected and input.Text==Catalog.Presets[selected] then mode,value="PRESET",selected end
  pending=true;create.Active=false;close();submit(mode,value)
 end
 create.Activated:Connect(send);cancel.Activated:Connect(close)
 input.FocusLost:Connect(function(enterPressed) if enterPressed then send() end end)
 -- Keyboard reduces available height; content scrolls and footer stays visible.
 local savedPosition,savedSize=panel.Position,panel.Size
 local function keyboard()
  if frame.Visible and UserInputService.OnScreenKeyboardVisible then
   local available=math.max(112,UserInputService.OnScreenKeyboardPosition.Y-panel.Parent.AbsolutePosition.Y-8)
   panel.AnchorPoint=Vector2.new(.5,0);panel.Position=UDim2.new(.5,0,0,4);panel.Size=UDim2.new(savedSize.X.Scale,savedSize.X.Offset,0,available)
  else panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=savedPosition;panel.Size=savedSize end
 end
 local visible=frame:GetPropertyChangedSignal("Visible"):Connect(keyboard)
 local key=UserInputService:GetPropertyChangedSignal("OnScreenKeyboardVisible"):Connect(keyboard)
 local position=UserInputService:GetPropertyChangedSignal("OnScreenKeyboardPosition"):Connect(keyboard)
 frame.Destroying:Connect(function() connection:Disconnect();visible:Disconnect();key:Disconnect();position:Disconnect() end)
 return {open=function() pending=false;create.Active=true;selected=nil;input.Text="";update();frame.Visible=true end,close=close}
end
return View
