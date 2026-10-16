local View={}
function View.start()
 local player=game:GetService('Players').LocalPlayer
 local gui=Instance.new('ScreenGui');gui.Name='KDMPublicRaceStatus';gui.ResetOnSpawn=false
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=31;gui.Parent=player:WaitForChild('PlayerGui')
 local text=Instance.new('TextLabel');text.Name='PublicMatchStatus';text.AnchorPoint=Vector2.new(.5,0)
 text.Position=UDim2.new(.5,0,0,8);text.Size=UDim2.new(.55,0,0,48)
 text.BackgroundColor3=Color3.fromRGB(18,34,58);text.BackgroundTransparency=.12
 text.TextColor3=Color3.fromRGB(255,225,60);text.Font=Enum.Font.GothamBold;text.TextSize=16;text.TextWrapped=true;text.Parent=gui
 local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,10);c.Parent=text
 local connections={}
 local function update()
  local notice=player:GetAttribute('RacePublicJoinNotice')
  local warmup=player:GetAttribute('RacePublicWarmup')==true
  local practice=player:GetAttribute('RacePrivatePractice')==true
  text.Visible=(type(notice)=='string'and notice~='')or warmup or practice
  text.Text=if type(notice)=='string'and notice~=''then notice elseif practice then 'PRIVATE PRACTICE · NO MATCHMAKING'else 'BOT WARM-UP · WAITING FOR PLAYERS'
 end
 for _,name in {'RacePublicWarmup','RacePublicJoinNotice','RacePrivatePractice'}do table.insert(connections,player:GetAttributeChangedSignal(name):Connect(update))end
 gui.Destroying:Connect(function()for _,connection in connections do connection:Disconnect()end end)
 update()
end
return View
