local View={}
function View.start()
 local player=game:GetService('Players').LocalPlayer
 local gui=Instance.new('ScreenGui');gui.Name='KDMRaceRouteTransition';gui.ResetOnSpawn=false
 gui.DisplayOrder=80;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
 local shade=Instance.new('Frame');shade.Size=UDim2.fromScale(1,1)
 shade.BackgroundColor3=Color3.fromRGB(10,20,36);shade.BackgroundTransparency=.25
 shade.Active=true;shade.BorderSizePixel=0;shade.Parent=gui
 local text=Instance.new('TextLabel');text.Name='Message'
 text.AnchorPoint=Vector2.new(.5,.5);text.Position=UDim2.fromScale(.5,.5)
 text.Size=UDim2.new(.85,0,0,88);text.BackgroundTransparency=1
 text.Font=Enum.Font.GothamBold;text.TextSize=22;text.TextWrapped=true
 text.TextColor3=Color3.fromRGB(240,247,255);text.Parent=shade
 local function update()
  local route=player:GetAttribute('KDMRoutePending')
  gui.Enabled=route=='RACE_LAUNCH'or route=='HUB_RETURN'
  text.Text=if route=='HUB_RETURN'then 'RETURNING TO LOBBY...'else 'ENTERING RACE ROOM...'
 end
 local connection=player:GetAttributeChangedSignal('KDMRoutePending'):Connect(update)
 gui.Destroying:Connect(function()connection:Disconnect()end)
 update();gui.Parent=player:WaitForChild('PlayerGui')
end
return View
