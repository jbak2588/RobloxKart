local Controller={}
function Controller.start()
 local Players=game:GetService('Players')
 local RS=game:GetService('ReplicatedStorage')
 local p=Players.LocalPlayer
 local pg=p:WaitForChild('PlayerGui')
 if pg:FindFirstChild('KDMWelcomeReward') then return end
 local colors=require(script.Parent.ShopLayout).colors()
 local icons=require(script.Parent.KDMIconCatalog)
 local gui=Instance.new('ScreenGui');gui.Name='KDMWelcomeReward';gui.DisplayOrder=60
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ResetOnSpawn=false;gui.Enabled=false;gui.Parent=pg
 local root=Instance.new('Frame');root.Name='SafeRoot';root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1;root.Parent=gui
 local scrim=Instance.new('TextButton');scrim.Name='Scrim';scrim.Text='';scrim.Modal=true;scrim.AutoButtonColor=false
 scrim.Position=UDim2.fromScale(-1,-1);scrim.Size=UDim2.fromScale(3,3);scrim.BackgroundColor3=Color3.new();scrim.BackgroundTransparency=.3;scrim.Parent=root
 local function surface(name,parent,color)
  local f=Instance.new('Frame');f.Name=name;f.BackgroundColor3=color;f.BorderSizePixel=0;f.Parent=parent
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,12);c.Parent=f
  return f
 end
 local panel=surface('Welcome',root,colors.Background);panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
 local stroke=Instance.new('UIStroke');stroke.Color=colors.Yellow;stroke.Thickness=3;stroke.Parent=panel
 local function text(name,parent,value,color)
  local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Text=value;t.TextColor3=color or colors.White
  t.Font=Enum.Font.GothamBold;t.TextWrapped=true;t.Parent=parent;return t
 end
 local title=text('Title',panel,'KDM RACE COMPLETION EVENT',colors.Yellow)
 local visit=text('VisitReward',panel,'WELCOME, NEW & RETURNING RACERS!',colors.Cyan)
 local bonus=text('FirstFinishBonus',panel,'COMPLETE A RACE: +K$ 5,000',colors.Yellow)
 local explain=text('Explanation',panel,'PLUS your normal race reward! Once per account. Your existing K$ stays unchanged.')
 local parts=surface('KartParts',panel,colors.Panel)
 local items=surface('RaceItems',panel,colors.Panel)
 local partsText=text('Caption',parts,'CUSTOMIZE YOUR KART WITH K$',colors.White)
 local itemsText=text('Caption',items,'BUY RACE ITEMS WITH K$',colors.White)
 local viewport=Instance.new('ViewportFrame');viewport.Name='KartPreview';viewport.BackgroundTransparency=1
 viewport.Ambient=Color3.fromRGB(220,230,245);viewport.LightColor=Color3.new(1,1,1);viewport.Parent=parts
 local world=Instance.new('WorldModel');world.Parent=viewport
 local catalog=require(RS.Shared.KartCatalog)
 local preview=require(RS.Shared.KartVisualFactory).createVisual(catalog.Entries[p:GetAttribute('SelectedKartId')] or catalog.Entries[catalog.DefaultId],true)
 preview.Parent=world
 local camera=Instance.new('Camera');camera.FieldOfView=36;camera.Parent=viewport;viewport.CurrentCamera=camera
 local images={}
 for _,id in {'Nitro','Shield','Missile'}do
  local i=Instance.new('ImageLabel');i.Name=id;i.Image=icons.Items[id];i.BackgroundTransparency=1;i.Parent=items;table.insert(images,i)
 end
 local social=text('Social',panel,'Finish races with friends or other players to keep earning K$!')
 local function button(name,value,color)
  local b=Instance.new('TextButton');b.Name=name;b.Text=value;b.Font=Enum.Font.GothamBold;b.TextColor3=colors.Background
  b.TextWrapped=true;b.BackgroundColor3=color;b.Parent=panel
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,10);c.Parent=b;return b
 end
 local start=button('StartFirstRace','START EVENT RACE',Color3.fromRGB(72,228,96))
 local later=button('Later','LATER',colors.Panel);later.TextColor3=colors.White
 local status=text('Status',panel,'3-LAP PRACTICE · SOLO · BONUS ON COMPLETION',colors.Secondary)
 local busy=false;local dismissed=false;local starting=false
 local function layout()
  local w=math.min(860,math.max(220,root.AbsoluteSize.X-24));local h=math.min(530,math.max(220,root.AbsoluteSize.Y-16))
  panel.Size=UDim2.fromOffset(w,h)
  local compact=h<360
  parts.Visible=h>=280;items.Visible=h>=280
  local function line(t,y,height,size)
   t.Position=UDim2.new(0,12,0,y);t.Size=UDim2.new(1,-24,0,height);t.TextSize=size
  end
  line(title,8,26,if compact then 17 else 24)
  line(visit,36,24,if compact then 13 else 17)
  line(bonus,62,26,if compact then 16 else 22)
  line(explain,89,28,if compact then 11 else 14)
  local cardY=119;local bottom=if compact then 104 else 130;local cardH=math.max(38,h-cardY-bottom)
  parts.Position=UDim2.fromOffset(12,cardY);parts.Size=UDim2.new(.5,-18,0,cardH)
  items.Position=UDim2.new(.5,6,0,cardY);items.Size=UDim2.new(.5,-18,0,cardH)
  for _,t in {partsText,itemsText}do t.Position=UDim2.new(0,4,1,-24);t.Size=UDim2.new(1,-8,0,24);t.TextSize=if compact then 10 else 14 end
  viewport.Position=UDim2.fromOffset(4,2);viewport.Size=UDim2.new(1,-8,1,-26)
  local size=math.min((w/2-32)/3,cardH-26)
  for i,img in images do img.Size=UDim2.fromOffset(size,size);img.Position=UDim2.new((i-.5)/3,-size/2,.5,-size/2-10) end
  local fit=require(RS.Shared.KartPreviewFraming).fit(preview,math.max(.1,(w/2-32)/math.max(1,cardH-26)),36,true)
  if fit then camera.CFrame=fit end
  line(social,h-bottom+4,28,if compact then 11 else 15)
  start.Position=UDim2.new(0,12,1,-bottom+36);start.Size=UDim2.new(.73,-18,0,44);start.TextSize=if compact then 16 else 20
  later.Position=UDim2.new(.73,0,1,-bottom+36);later.Size=UDim2.new(.27,-12,0,44);later.TextSize=14
  line(status,h-22,20,if compact then 10 else 12)
 end
 local function blocked()
  for _,name in {'KDMGarageShop','KDMMatchRooms'}do local g=pg:FindFirstChild(name);if g and g.Enabled then return true end end
  return p:GetAttribute('HubOverlayOpen')==true or p:GetAttribute('KDMProfileOpen')==true
   or p:GetAttribute('LobbyDriveActive')==true or p:GetAttribute('LobbyDrivePending')==true
   or (p:GetAttribute('KDMRoutePending')~=nil and p:GetAttribute('KDMRoutePending')~='')
 end
 local function update()
  gui.Enabled=not dismissed and p:GetAttribute('KDMEconomyState')=='FOUND' and p:GetAttribute('KDMWelcomeSeen')==false
   and p:GetAttribute('KDMFirstFinishClaimed')~=true and p:GetAttribute('RaceState')=='GARAGE' and not blocked()
  if gui.Enabled then layout() end
 end
 local function acknowledge()
  for attempt=1,3 do
   local ok,r=pcall(function()return RS:WaitForChild('KDMEconomy'):InvokeServer('WELCOME_SEEN')end)
   if ok and r.status=='SAVE_CONFIRMED' then return true end
   if attempt<3 then task.wait(1.1) end
  end
  return false
 end
 start.Activated:Connect(function()
  if busy then return end
  busy=true;start.Active=false;later.Active=false;status.Text='ENTERING PRACTICE RACE...'
  task.spawn(function()
   -- A failed acknowledgement must not prevent trying the race or grant any money.
   acknowledge();dismissed=true;starting=true;gui.Enabled=true
   RS:WaitForChild('MatchRoomControl'):FireServer('FirstRace')
   task.delay(25,function()
    if starting and p:GetAttribute('KDMRoutePending')~='RACE_LAUNCH' then
     starting=false;busy=false;start.Active=true;later.Active=true;status.Text='PLEASE TRY AGAIN';gui.Enabled=true
    end
   end)
  end)
 end)
 later.Activated:Connect(function()
  if busy then return end
  dismissed=true;gui.Enabled=false;task.spawn(acknowledge)
 end)
 RS:WaitForChild('MatchRoomControl').OnClientEvent:Connect(function(action,message)
  if starting and action=='Error' then
   starting=false;busy=false;start.Active=true;later.Active=true;gui.Enabled=true;status.Text=tostring(message)
  end
 end)
 for _,name in {'KDMEconomyState','KDMWelcomeSeen','KDMFirstFinishClaimed','RaceState','HubOverlayOpen','KDMProfileOpen','LobbyDriveActive','LobbyDrivePending','KDMRoutePending'}do
  p:GetAttributeChangedSignal(name):Connect(function()if not starting then update()end end)
 end
 for _,name in {'KDMGarageShop','KDMMatchRooms'}do local g=pg:FindFirstChild(name);if g then g:GetPropertyChangedSignal('Enabled'):Connect(function()if not starting then update()end end)end end
 root:GetPropertyChangedSignal('AbsoluteSize'):Connect(layout)
 layout();task.delay(2,update)
end
return Controller
