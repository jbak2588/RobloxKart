-- Canary read-only viewer. All authorization and profile reads remain server-owned.
local Controller = {}
local names={Track01="Figure-8 Green Island",Track01Desert="Figure-8 Desert Canyon",Track01Race="Base Circuit",Track02="Prototype Circuit V2B",Track03="KDM Hard Circuit"}
local categories={SOLO_1H_0B="Solo",BOT_1H_1B="1 driver + 1 bot",HUMAN_2H_0B="2 drivers",HUMAN_3H_0B="3 drivers",HUMAN_4H_0B="4 drivers"}
local function title(evidence)
 return (names[evidence.trackId] or "Track").." / "..(categories[evidence.category] or "Bot-assisted race")
end
local function time(ms)
 return if type(ms)=="number" and ms>0 then string.format("%d:%06.3f",math.floor(ms/60000),(ms%60000)/1000) else "--"
end
local function snapshot(lines,label,race)
 table.insert(lines,label)
 if not race then table.insert(lines,"No full race saved yet.");return end
 table.insert(lines,"Total Time "..time(race.totalMilliseconds))
 for lap,ms in race.laps do table.insert(lines,"Lap "..lap.."  "..time(ms)) end
 table.insert(lines,"Finish Position "..race.finishPosition.." / "..(race.startingHumans+race.startingBots))
 table.insert(lines,"Starting Racers "..race.startingHumans.." drivers + "..race.startingBots.." bots | Boosts "..race.raceBoosts)
 table.insert(lines,'Round '..race.roundGuid..' | saved UTC ms '..tostring(race.finishedAt))
 if not race.eligible then
  table.insert(lines,if race.reason=="TOTAL_LAP_MISMATCH" then "Not eligible for Best Race: total/lap timer mismatch." else "Not eligible for Best Race: route validation did not pass.")
  if race.eligibilityDetail and race.eligibilityDetail~="" then table.insert(lines,"Validation: "..race.eligibilityDetail)
  else table.insert(lines,"Validation detail unavailable for this older race.") end
 end
end
function Controller.lines(response)
 if type(response) ~= "table" or response.status ~= "FOUND" then
  local lines={"RECORDS: " .. tostring(if type(response)=="table" then response.status else "ERROR")}
  if type(response)=='table' and type(response.reason)=='string' then table.insert(lines,'Reason: '..response.reason) end
  return lines
 end
 local records=response.records
 if type(records)~="table" or type(records.scoped)~="table" then return {"RECORDS: ERROR"} end
 local scopes={}
 for scope in records.scoped do table.insert(scopes,scope) end
 table.sort(scopes)
 local lines={"SAVED PERSONAL RECORDS"}
 if response.resetState then table.insert(lines,'Personal record reset: '..response.resetState) end
 for _,scope in scopes do
  local score=records.scoped[scope]
  local meta=records.metadata and records.metadata[scope]
  local evidence=meta and (meta.lap or meta.boost)
  table.insert(lines,if evidence then title(evidence) else "Saved personal records")
  local races={}
  for key,entry in records.races or {} do
   if entry.lastRace.recordScope==scope then table.insert(races,{key=key,entry=entry}) end
  end
  table.sort(races,function(a,b) return a.key<b.key end)
  if #races==0 then snapshot(lines,"BEST RACE",nil) end
  for _,item in races do
   table.insert(lines,tostring(item.entry.lastRace.targetLaps).." LAP RACE")
   snapshot(lines,"BEST RACE",item.entry.bestRace)
  end
  table.insert(lines,"BEST LAP / PB LAP "..time(score.bestLapMilliseconds))
  table.insert(lines,"DRIFT RECORDS | BEST BOOSTS "..tostring(score.bestRaceBoosts or 0))
  table.insert(lines,"TOTAL OFFICIAL BOOSTS "..tostring(score.officialBoostLifetime or 0))
  for _,item in races do
   table.insert(lines,tostring(item.entry.lastRace.targetLaps).." LAP RACE")
   snapshot(lines,"LAST RACE",item.entry.lastRace)
  end
  table.insert(lines,"")
 end
 if #scopes==0 then table.insert(lines,"No official finished race saved yet.") end
 return lines
end
function Controller.createRecordsPanel(gui)
 local StyleHelper = require(script.Parent:WaitForChild("KDMUiStyleHelper"))
 local panel=Instance.new("ScrollingFrame")
 panel.Name="SavedRecords";panel.AnchorPoint=Vector2.new(1,0);panel.Position=UDim2.new(1,-12,0,60)
 panel.Size=UDim2.new(0.8,0,0.5,0);panel.AutomaticCanvasSize=Enum.AutomaticSize.None
 panel.CanvasSize=UDim2.new();panel.ScrollBarThickness=8
 panel.Active=true;panel.ScrollingEnabled=true;panel.ScrollingDirection=Enum.ScrollingDirection.Y
 panel.BackgroundColor3=Color3.fromRGB(20,30,44);panel.Visible=false;panel.Parent=gui
 StyleHelper.applyModalPanel(panel)
 local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(440,280);limit.Parent=panel
 local close=Instance.new("TextButton");close.Name="Close";close.Text="X";close.Size=UDim2.fromOffset(44,44)
 close.AnchorPoint=Vector2.new(1,0);close.Position=UDim2.new(1,-8,0,8);close.ZIndex=22;close.Parent=panel
 StyleHelper.applyCloseButton(close)
 -- UIGradient also tints TextButton glyphs; draw the caption on a child instead.
 close.Text=""
 local dismissLabel=Instance.new("TextLabel");dismissLabel.Name="DismissLabel";dismissLabel.Text="X"
 dismissLabel.Size=UDim2.fromScale(1,1);dismissLabel.BackgroundTransparency=1;dismissLabel.TextColor3=Color3.new(1,1,1)
 dismissLabel.Font=Enum.Font.GothamBold;dismissLabel.TextSize=18;dismissLabel.TextStrokeTransparency=1;dismissLabel.ZIndex=23;dismissLabel.Parent=close
 close.Activated:Connect(function() panel.Visible=false end)
 local label=Instance.new("TextLabel")
 label.Name="ReadOnlyRecords";label.Position=UDim2.fromOffset(10,8);label.Size=UDim2.new(1,-28,0,0)
 label.AutomaticSize=Enum.AutomaticSize.None;label.TextWrapped=true;label.BackgroundTransparency=1
 label.TextColor3=Color3.new(1,1,1);label.Font=Enum.Font.Gotham;label.TextSize=14
 label.TextXAlignment=Enum.TextXAlignment.Left;label.TextYAlignment=Enum.TextYAlignment.Top;label.Parent=panel
 -- Measure the complete wrapped text independently of the viewport. Nested
 -- automatic sizing can clamp the label to the frame and leave no scroll range.
 local textService=game:GetService("TextService")
 local function resize()
  local width=math.max(1,panel.AbsoluteSize.X-28)
  local bounds=textService:GetTextSize(label.Text,label.TextSize,label.Font,Vector2.new(width,1000000))
  local height=math.ceil(bounds.Y)
  label.Size=UDim2.new(1,-28,0,height)
  panel.CanvasSize=UDim2.fromOffset(0,height+16)
 end
 local connections={label:GetPropertyChangedSignal("Text"):Connect(resize),panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)}
 resize()
 return panel,label,connections
end
-- Mounted only inside the existing profile. No standalone TopBar entry.
function Controller.attachProfile(gui)
 local player=game:GetService("Players").LocalPlayer
 if player.UserId~=11700555357 then return end
 local profile=gui:WaitForChild("DriverCard")
 profile:WaitForChild("Close")
 if profile:FindFirstChild("Records") then return end
 local StyleHelper=require(script.Parent:WaitForChild("KDMUiStyleHelper"))
 local button=Instance.new("TextButton")
 button.Name="Records";button.Text="MY RECORDS";button.Size=UDim2.fromOffset(120,44)
 button.AnchorPoint=Vector2.new(1,1);button.Position=UDim2.new(1,-112,1,-10)
 button.TextColor3=Color3.new(1,1,1);button.Font=Enum.Font.GothamBold;button.TextSize=13
 button.ZIndex=12;button.Parent=profile
 button.BackgroundColor3=Color3.new(1,1,1)
 StyleHelper.apply3DButton(button,Color3.fromRGB(80,140,195),Color3.fromRGB(40,80,125),Color3.fromRGB(25,50,85),8,1)
 button.Text=""
 local caption=Instance.new("TextLabel");caption.Name="RecordsLabel";caption.Text="MY RECORDS";caption.Size=UDim2.fromScale(1,1)
 caption.BackgroundTransparency=1;caption.TextColor3=Color3.new(1,1,1);caption.TextStrokeTransparency=1
 caption.Font=Enum.Font.GothamBold;caption.TextSize=13;caption.ZIndex=13;caption.Parent=button
 local status=profile:FindFirstChild("Status");if status then status.Size=UDim2.new(1,-248,0,48) end
 local panel,label,connections=Controller.createRecordsPanel(profile)
 panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
 panel.Size=UDim2.new(1,-24,1,-24);panel.ZIndex=20;label.ZIndex=21
 local overlay=Instance.new("Frame");overlay.Name="RecordsBackdrop";overlay.Size=UDim2.fromScale(1,1)
 overlay.BackgroundColor3=Color3.fromRGB(18,34,64);overlay.BackgroundTransparency=.2
 overlay.BorderSizePixel=0;overlay.Visible=false;overlay.Active=true;overlay.ZIndex=19;overlay.Parent=profile
 local busy=false;local last=-math.huge;local alive=true
 table.insert(connections,panel:GetPropertyChangedSignal("Visible"):Connect(function()overlay.Visible=panel.Visible end))
 table.insert(connections,profile:GetPropertyChangedSignal("Visible"):Connect(function()if not profile.Visible then panel.Visible=false end end))
 table.insert(connections,button.Activated:Connect(function()
  if not gui.Enabled or not profile.Visible then return end
  panel.Visible=not panel.Visible
  if not panel.Visible or busy or os.clock()-last<4 then return end
  busy=true;last=os.clock();label.Text="Loading saved records..."
  task.spawn(function()
   local remote=game:GetService("ReplicatedStorage"):WaitForChild("KDMGetPersonalRecords",10)
   local ok,result=pcall(function() assert(remote,"records_unavailable");return remote:InvokeServer() end)
   if alive then label.Text="PV "..tostring(game.PlaceVersion).."\n"..table.concat(Controller.lines(if ok then result else {status="ERROR"}),"\n");busy=false end
  end)
 end))
 profile.Destroying:Connect(function()alive=false;for _,c in connections do c:Disconnect() end end)
end
local started=false
function Controller.start()
 local player=game:GetService("Players").LocalPlayer
 if player.UserId~=11700555357 or started then return end
 started=true
 local pg=player:WaitForChild("PlayerGui")
 local function watch(gui)if gui.Name=="KDMMyProfile" then Controller.attachProfile(gui) end end
 local connection=pg.ChildAdded:Connect(watch)
 local existing=pg:FindFirstChild("KDMMyProfile");if existing then watch(existing) end
 pg.Destroying:Connect(function()connection:Disconnect();started=false end)
end
return Controller
