local Controller={}
function Controller.start()
 local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local WS=game:GetService('Workspace')
 local PromptService=game:GetService('ProximityPromptService');local player=Players.LocalPlayer
 local Policy=require(RS.Shared:WaitForChild('HubLeaderboardPolicy'));local remote=RS:WaitForChild('KDMHubLeaderboardQuery',150)
 if not remote then return end
 local gui=Instance.new('ScreenGui');gui.Name='KDMHubRankings';gui.ResetOnSpawn=false;gui.DisplayOrder=30
 gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets;gui.Enabled=false;gui.Parent=player:WaitForChild('PlayerGui')
 local panel=Instance.new('Frame');panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromScale(.92,.90)
 panel.BackgroundColor3=Color3.fromRGB(70,110,135);panel.BackgroundTransparency=.12;panel.BorderSizePixel=0;panel.Parent=gui
 local cap=Instance.new('UISizeConstraint');cap.MaxSize=Vector2.new(1000,720);cap.Parent=panel
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,18);corner.Parent=panel
 local stroke=Instance.new('UIStroke');stroke.Color=Color3.fromRGB(220,245,255);stroke.Thickness=2;stroke.Parent=panel
 local function label(name,pos,size,text)
  local l=Instance.new('TextLabel');l.Name=name;l.Position=pos;l.Size=size;l.BackgroundTransparency=1;l.Font=Enum.Font.GothamBold
  l.TextColor3=Color3.new(1,1,1);l.TextScaled=true;l.Text=text;l.TextXAlignment=Enum.TextXAlignment.Left;l.Parent=panel
  local c=Instance.new('UITextSizeConstraint');c.MinTextSize=12;c.MaxTextSize=25;c.Parent=l;return l
 end
 local function button(parent,text,pos,size,callback)
  local b=Instance.new('TextButton');b.Size=size;b.Position=pos;b.Text=text;b.BackgroundColor3=Color3.fromRGB(85,186,211);b.BackgroundTransparency=.18
  b.Name=if text=='<'then 'PreviousTrack'elseif text=='>'then 'NextTrack'else 'Action_'..text:gsub('[^%w]','')
  b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamBold;b.TextScaled=true;b.BorderSizePixel=0;b.Parent=parent
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,9);c.Parent=b
  local hit=Instance.new('UISizeConstraint');hit.MinSize=Vector2.new(44,44);hit.Parent=b
  local t=Instance.new('UITextSizeConstraint');t.MinTextSize=11;t.MaxTextSize=20;t.Parent=b;b.Activated:Connect(callback);return b
 end
 label('Title',UDim2.new(0,18,0,10),UDim2.new(1,-100,0,34),'KDM GLOBAL RANKINGS')
 button(panel,'X',UDim2.new(1,-62,0,8),UDim2.fromOffset(48,40),function()gui.Enabled=false end)
 local id='SOLO_Park';local mode='SOLO';local serial=0;local busy=false
 local track=label('Track',UDim2.new(.12,0,0,102),UDim2.new(.76,0,0,30),'ROOKIE RACING PARK / 2-LAP FINISH')
 track.TextXAlignment=Enum.TextXAlignment.Center
 local status=label('Status',UDim2.new(0,18,0,148),UDim2.new(1,-36,0,27),'LOADING')
 local mine=label('MyRecord',UDim2.new(0,18,1,-42),UDim2.new(1,-36,0,30),'MY RECORD: --')
 local list=Instance.new('ScrollingFrame');list.Name='Top50';list.Position=UDim2.new(0,16,0,183);list.Size=UDim2.new(1,-32,1,-236)
 list.BackgroundTransparency=1;list.BorderSizePixel=0;list.ScrollBarThickness=5;list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.new();list.Parent=panel
 local layout=Instance.new('UIListLayout');layout.Padding=UDim.new(0,5);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=list
 local function allowed()
  return player:GetAttribute('RaceState')=='GARAGE'and player:GetAttribute('LobbyDriveActive')~=true and player:GetAttribute('KDMRoutePending')~='RACE_LAUNCH'
 end
 local lastRender
 local function render(data)
  local fingerprint={id,data.status or '',tostring(data.myScore),tostring(data.myRank),tostring(data.preview),tostring(data.indexing)}
  for _,r in data.rows or {}do table.insert(fingerprint,tostring(r.userId)..':'..r.name..':'..tostring(r.score))end
  local stamp=table.concat(fingerprint,'|');if stamp==lastRender then return end;lastRender=stamp
  for _,r in list:GetChildren()do if r:IsA('Frame')then r:Destroy()end end
  local board=Policy.Boards[id]
  track.Text=board.title..(if mode=='CASH'then ''else ' / '..board.laps..'-LAP FINISH')
  local messages={POLICY_PENDING='RANKING POLICY NOT YET CONFIRMED',LOADING='LOADING RANKINGS...',STALE='UPDATE DELAYED - SHOWING LAST SAVED RANKINGS',ERROR='RANKINGS TEMPORARILY UNAVAILABLE'}
  status.Text=messages[data.status]or(if #(data.rows or {})==0 then 'NO VALID RECORDS YET'else 'GLOBAL TOP 50  /  UPDATES ~60s')
  if data.preview then status.Text='STUDIO PREVIEW - NO LIVE DATA'end
  if data.indexing and not data.preview and data.status=='READY'then status.Text='INDEXING SAVED RECORDS / GLOBAL TOP 50'end
  for i,r in data.rows or {}do
   local row=Instance.new('Frame');row.Name='Rank'..i;row.Size=UDim2.new(1,-8,0,44);row.LayoutOrder=i;row.BorderSizePixel=0
   row.BackgroundColor3=if r.userId==player.UserId then Color3.fromRGB(45,200,205)else Color3.fromRGB(40,75,100);row.BackgroundTransparency=.3;row.Parent=list
   local t=Instance.new('TextLabel');t.BackgroundTransparency=1;t.Position=UDim2.fromOffset(10,0);t.Size=UDim2.new(1,-20,1,0)
   t.Font=Enum.Font.GothamBold;t.TextColor3=Color3.new(1,1,1);t.TextSize=16;t.TextXAlignment=Enum.TextXAlignment.Left
   t.TextTruncate=Enum.TextTruncate.AtEnd;t.Text=string.format('%02d   %s',r.rank,r.name);t.Size=UDim2.new(.73,-14,1,0);t.Parent=row
   local score=t:Clone();score.Position=UDim2.new(.73,0,0,0);score.Size=UDim2.new(.27,-12,1,0);score.TextXAlignment=Enum.TextXAlignment.Right;score.Text=Policy.format(board,r.score);score.Parent=row
  end
  mine.Text='MY RECORD: '..(if data.myScore then Policy.format(board,data.myScore)else '--')..(if data.myRank then '  /  # '..data.myRank elseif data.myScore then '  /  OUTSIDE LOADED TOP 50'else '')
 end
 local function refresh()
  if busy or not gui.Enabled then return end;busy=true;serial+=1;local request=serial;local requested=id
  task.spawn(function()
   local ok,data=pcall(function()return remote:InvokeServer(requested)end);busy=false
   if gui.Enabled and request==serial and requested==id then
    if not ok or type(data)~='table'then render({status='ERROR',rows={}})
    elseif data.status~='RATE_LIMITED'then render(data)end
   end
  end)
 end
 local function selectMode(nextMode)
  mode=nextMode;id=if mode=='CASH'then 'CASH'elseif mode=='MULTI'then 'MULTI_Track01Race'else 'SOLO_Park'
  render({status='LOADING',rows={}});refresh()
 end
 for i,d in {{'SOLO','SOLO TIME ATTACK'},{'MULTI','MULTIPLAYER FINISH'},{'CASH','TOTAL K$ EARNED'}}do
  button(panel,d[2],UDim2.new((i-1)/3,8,0,55),UDim2.new(1/3,-16,0,38),function()selectMode(d[1])end)
 end
 local function cycle(delta)
  if mode=='CASH'then return end
  local tracks={};for _,v in Policy.Tracks do if mode=='SOLO'or v.id~='Park'then table.insert(tracks,v)end end
  local index=1;for i,v in tracks do if v.id==Policy.Boards[id].track then index=i end end
  id=mode..'_'..tracks[(index-1+delta)%#tracks+1].id;render({status='LOADING',rows={}});refresh()
 end
 button(panel,'<',UDim2.new(0,16,0,100),UDim2.fromOffset(48,34),function()cycle(-1)end)
 button(panel,'>',UDim2.new(1,-64,0,100),UDim2.fromOffset(48,34),function()cycle(1)end)
 PromptService.PromptTriggered:Connect(function(prompt)
  if prompt.Name~='KDMRankingsPrompt'or not allowed()then return end
  local hub=WS:FindFirstChild('KDMHub');local ranks=hub and hub:FindFirstChild('KDMRankings')
  if not ranks or not prompt:IsDescendantOf(ranks)then return end
  local selected=prompt.Parent:GetAttribute('LeaderboardId');if not Policy.Boards[selected]then return end
  id=selected;mode=Policy.Boards[id].mode;gui.Enabled=true;render({status='LOADING',rows={}});refresh()
 end)
 for _,attr in {'RaceState','LobbyDriveActive','KDMRoutePending'}do player:GetAttributeChangedSignal(attr):Connect(function()if not allowed()then gui.Enabled=false;serial+=1 end end)end
 task.spawn(function()while gui.Parent do if gui.Enabled then refresh()end;task.wait(3)end end)
end
return Controller
