-- Canary read-only viewer. All authorization and profile reads remain server-owned.
local Controller = {}
function Controller.lines(response)
 if type(response) ~= "table" or response.status ~= "FOUND" then
  return {"RECORDS: " .. tostring(if type(response)=="table" then response.status else "ERROR")}
 end
 local records=response.records
 if type(records)~="table" or type(records.scoped)~="table" then return {"RECORDS: ERROR"} end
 local scopes={}
 for scope in records.scoped do table.insert(scopes,scope) end
 table.sort(scopes)
 local lines={"SAVED PERSONAL RECORDS"}
 for _,scope in scopes do
  local score=records.scoped[scope]
  local meta=records.metadata and records.metadata[scope]
  local evidence=meta and (meta.lap or meta.boost)
  table.insert(lines,if evidence then evidence.trackId.." / "..evidence.geometryId.." / "..evidence.category else scope)
  local ms=score.bestLapMilliseconds
  local lap=if type(ms)=="number" and ms>0 then string.format("%d:%06.3f",math.floor(ms/60000),(ms%60000)/1000) else "--"
  table.insert(lines,"PB LAP "..lap.." | BEST BOOSTS "..tostring(score.bestRaceBoosts or 0))
  table.insert(lines,"TOTAL OFFICIAL BOOSTS "..tostring(score.officialBoostLifetime or 0))
 end
 if #scopes==0 then table.insert(lines,"No official finished race saved yet.") end
 return lines
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
 local panel=Instance.new("ScrollingFrame")
 panel.Name="SavedRecords";panel.AnchorPoint=Vector2.new(1,0);panel.Position=UDim2.new(1,-12,0,60)
 panel.Size=UDim2.new(0.8,0,0.5,0);panel.AutomaticCanvasSize=Enum.AutomaticSize.Y
 panel.CanvasSize=UDim2.new();panel.ScrollBarThickness=8
 panel.BackgroundColor3=Color3.fromRGB(20,30,44);panel.Visible=false;panel.Parent=gui
 local limit=Instance.new("UISizeConstraint");limit.MaxSize=Vector2.new(440,280);limit.Parent=panel
 local label=Instance.new("TextLabel")
 label.Name="ReadOnlyRecords";label.Position=UDim2.fromOffset(10,8);label.Size=UDim2.new(1,-28,0,0)
 label.AutomaticSize=Enum.AutomaticSize.Y;label.TextWrapped=true;label.BackgroundTransparency=1
 label.TextColor3=Color3.new(1,1,1);label.Font=Enum.Font.Gotham;label.TextSize=14
 label.TextXAlignment=Enum.TextXAlignment.Left;label.TextYAlignment=Enum.TextYAlignment.Top;label.Parent=panel
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
 for _,name in {"RaceState","HubOverlayOpen","LobbyDriveActive","KDMRoutePending"} do
  table.insert(connections,player:GetAttributeChangedSignal(name):Connect(update))
 end
 gui.Destroying:Connect(function() alive=false;for _,c in connections do c:Disconnect() end end)
 update()
end
return Controller
