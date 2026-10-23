local View={}
local GuiService=game:GetService('GuiService')
local MobileView=require(script.Parent.MobileControlView)
function View.format(milliseconds)
 local ms=math.max(0,math.floor(milliseconds or 0))
 return string.format('%02d:%02d.%03d',math.floor(ms/60000),math.floor(ms/1000)%60,ms%1000)
end
-- Preserve the Park reward presentation; shared race guidance owns checkpoints.
function View.new(parent,player,onReplay,onReturn)
 local gui=Instance.new('ScreenGui');gui.Name='KDMRookieParkTrial';gui.ResetOnSpawn=false
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=42;gui.Parent=parent
 local canvas=Instance.new('Frame');canvas.Size=UDim2.fromScale(1,1);canvas.BackgroundTransparency=1;canvas.Parent=gui
 local function text(parent,name,size)
  local l=Instance.new('TextLabel');l.Name=name;l.BackgroundTransparency=1;l.TextColor3=Color3.new(1,1,1)
  l.Font=Enum.Font.GothamBold;l.TextSize=size;l.TextWrapped=true;l.Parent=parent;return l
 end
 local topGui=Instance.new('ScreenGui');topGui.Name='KDMRookieParkTopHud';topGui.ResetOnSpawn=false
 topGui.ScreenInsets=Enum.ScreenInsets.None;topGui.DisplayOrder=42;topGui.Parent=parent
 local timing=text(topGui,'Timing',16);timing.AnchorPoint=Vector2.new(.5,0);timing.Size=UDim2.fromOffset(280,56)
 timing.TextXAlignment=Enum.TextXAlignment.Center
 local countdown=text(canvas,'Countdown',64);countdown.AnchorPoint=Vector2.new(.5,.5);countdown.Position=UDim2.fromScale(.5,.4);countdown.Size=UDim2.fromOffset(230,85)
 countdown.TextStrokeTransparency=.45
 local panel=Instance.new('Frame');panel.Name='LapResult';panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
 panel.BackgroundColor3=Color3.fromRGB(70,110,135);panel.BackgroundTransparency=.4;panel.BorderSizePixel=0;panel.Parent=canvas
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,16);corner.Parent=panel
 local stroke=Instance.new('UIStroke');stroke.Color=Color3.fromRGB(210,245,255);stroke.Thickness=2;stroke.Parent=panel
 local title=text(panel,'Title',20);title.Position=UDim2.fromOffset(12,12);title.Size=UDim2.new(1,-24,0,28);title.Text='ROOKIE PARK • LAP COMPLETE'
 local lap=text(panel,'LapTime',38);lap.Position=UDim2.fromOffset(12,43);lap.Size=UDim2.new(1,-24,0,48)
 local best=text(panel,'PersonalBest',14);best.Position=UDim2.fromOffset(12,94);best.Size=UDim2.new(1,-24,0,22)
 local reward=text(panel,'Reward',24);reward.Position=UDim2.fromOffset(12,120);reward.Size=UDim2.new(1,-24,0,34);reward.TextColor3=Color3.fromRGB(255,230,100)
 local saved=text(panel,'SaveState',12);saved.Position=UDim2.fromOffset(12,155);saved.Size=UDim2.new(1,-24,0,28)
 local function button(name,label,x,callback)
  local b=Instance.new('TextButton');b.Name=name;b.Text=label;b.Position=UDim2.new(x,if x==0 then 12 else 4,1,-58);b.Size=UDim2.new(.5,-16,0,46)
  b.BackgroundColor3=Color3.fromRGB(115,205,230);b.BackgroundTransparency=.25;b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamBold;b.TextSize=16;b.Parent=panel
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,8);c.Parent=b
  b.Activated:Connect(callback);return b
 end
 for _,label in {title,lap,best,reward,saved}do
  label.TextScaled=true;local limit=Instance.new('UITextSizeConstraint');limit.MinTextSize=10;limit.MaxTextSize=label.TextSize;limit.Parent=label
 end
 local replay=button('Replay','REPLAY',0,onReplay);button('ReturnLobby','RETURN LOBBY',.5,onReturn)
 local api={}
 function api:update(active,camera)
  local phase=player:GetAttribute('ParkTrialPhase');gui.Enabled=active and phase~=nil;topGui.Enabled=gui.Enabled
  if not gui.Enabled then return end
  local now=workspace:GetServerTimeNow();local started=player:GetAttribute('ParkTrialStartedAt')or now
  local size=canvas.AbsoluteSize
  local wide=size.X>size.Y and size.X>=600
  panel.AnchorPoint=if wide then Vector2.new(0,.5)else Vector2.new(.5,.5)
  panel.Position=if wide then UDim2.new(0,12,.5,0)else UDim2.fromScale(.5,.5)
  panel.Size=UDim2.fromOffset(if wide then math.min(390,size.X*.5-24)else math.min(390,size.X-24),math.min(250,size.Y-16))
  local top=MobileView.speedTopbarPosition(topGui.AbsoluteSize,GuiService.TopbarInset,280,56)
  timing.Position=UDim2.fromOffset(top.X,top.Y)
  panel.Visible=phase=='FINISHED'or phase=='INVALID';timing.Visible=phase=='RUNNING'
  local cp=player:GetAttribute('ParkTrialCheckpoint')or 0
  local invalid=player:GetAttribute('ParkTrialInvalid')==true
  local missed=player:GetAttribute('ParkTrialMissed')==true
  local personalBest=player:GetAttribute('KDMRookieParkBestMilliseconds')
  timing.Text='SOLO LAP  '..View.format((now-started)*1000)..'\nCHECKPOINT '..cp..'/6'..(if missed then ' • MISSED '..(cp+1)else '')..(if personalBest then '\nBEST '..View.format(personalBest)else '')
  countdown.Visible=phase=='COUNTDOWN'or(phase=='RUNNING'and now-started<1)
  countdown.Text=if phase=='COUNTDOWN'then tostring(math.max(1,math.ceil((player:GetAttribute('ParkTrialGoAt')or now)-now)))else 'GO!'
  title.Text=if phase=='INVALID'then 'LAP INVALID • NO REWARD'else 'ROOKIE PARK • LAP COMPLETE'
  lap.Text=View.format(player:GetAttribute('ParkTrialMilliseconds'))
  local pb=player:GetAttribute('KDMRookieParkBestMilliseconds')
  local state=player:GetAttribute('ParkTrialRewardState')
  best.Text=if pb then 'PERSONAL BEST  '..View.format(pb)elseif state=='SAVING'then 'PERSONAL BEST • SAVING'else 'PERSONAL BEST • NOT SAVED'
  reward.Text=if phase=='INVALID'then 'K$0  -  VALID LAP REQUIRED'elseif state=='CONFIRMED'then '+ K$5,000 • REWARD EARNED'else 'LAP REWARD  K$5,000'
  saved.Text=if phase=='INVALID'then 'REPLAY TO START A NEW VERIFIED LAP'elseif state=='CONFIRMED'then '6/6 CHECKPOINTS • RECORD & REWARD SAVED'elseif state=='UNCONFIRMED'then 'SAVE NOT CONFIRMED • REPLAY TO RACE AGAIN'else 'SAVING RECORD & REWARD…'
  replay.Active=true;replay.Text='REPLAY'
 end
 function api:destroy()gui:Destroy();topGui:Destroy()end
 return api
end
return View
