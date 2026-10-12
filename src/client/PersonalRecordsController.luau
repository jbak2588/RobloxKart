-- Canary read-only viewer. All authorization and profile reads remain server-owned.
local Controller = {}
local names={Track01="Practice Circuit",Track01Race="Base Circuit",Track02="Prototype Circuit V2B",Track03="KDM Hard Circuit"}
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
 local panel=Instance.new("ScrollingFrame")
 panel.Name="SavedRecords";panel.AnchorPoint=Vector2.new(1,0);panel.Position=UDim2.new(1,-12,0,60)
 panel.Size=UDim2.new(0.8,0,0.5,0);panel.AutomaticCanvasSize=Enum.AutomaticSize.None
 panel.CanvasSize=UDim2.new();panel.ScrollBarThickness=8
 panel.Active=true;panel.ScrollingEnabled=true;panel.ScrollingDirection=Enum.ScrollingDirection.Y
 panel.BackgroundColor3=Color3.fromRGB(20,30,44);panel.Visible=false;panel.Parent=gui
 local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(440,280);limit.Parent=panel
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
function Controller.start()
 local player=game:GetService("Players").LocalPlayer
 if player.UserId~=11700555357 then return end
 local gui=Instance.new("ScreenGui")
 gui.Name="KDMCanaryPersonalRecords";gui.ResetOnSpawn=false;gui.DisplayOrder=25
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=player:WaitForChild("PlayerGui")
 local button=Instance.new("TextButton")
 button.Name="Records";button.Text="MY RECORDS";button.Size=UDim2.fromOffset(132,44)
 button.AnchorPoint=Vector2.new(1,0);button.Position=UDim2.new(1,-12,0,12)
 button.BackgroundColor3=Color3.fromRGB(20,30,44);button.TextColor3=Color3.new(1,1,1)
 button.Font=Enum.Font.GothamBold;button.TextSize=14;button.Parent=gui
 local panel,label,resizeConnections=Controller.createRecordsPanel(gui)
 local busy=false;local last=-math.huge;local alive=true
 local click=button.Activated:Connect(function()
  panel.Visible=not panel.Visible
  if not panel.Visible or busy or os.clock()-last<4 then return end
  busy=true;last=os.clock();label.Text="Loading saved records..."
  task.spawn(function()
   local remote=game:GetService("ReplicatedStorage"):WaitForChild("KDMGetPersonalRecords",10)
   local ok,result=pcall(function() assert(remote,"records_unavailable");return remote:InvokeServer() end)
   if alive then label.Text="PV "..tostring(game.PlaceVersion).."\n"..table.concat(Controller.lines(if ok then result else {status="ERROR"}),"\n");busy=false end
  end)
 end)
 local function update()
  gui.Enabled=player:GetAttribute("RaceState")=="GARAGE" and player:GetAttribute("HubOverlayOpen")~=true
   and player:GetAttribute("LobbyDriveActive")~=true and player:GetAttribute("KDMRoutePending")~="RACE_LAUNCH"
  if not gui.Enabled then panel.Visible=false end
 end
 local connections={click}
 for _,c in resizeConnections do table.insert(connections,c) end
 for _,name in {"RaceState","HubOverlayOpen","LobbyDriveActive","KDMRoutePending"} do
  table.insert(connections,player:GetAttributeChangedSignal(name):Connect(update))
 end
 gui.Destroying:Connect(function() alive=false;for _,c in connections do c:Disconnect() end end)
 update()
end
return Controller
