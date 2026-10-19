local View={}
function View.start()
 local p=game:GetService('Players').LocalPlayer
 local gui=Instance.new('ScreenGui');gui.Name='KDMActivityReward';gui.ResetOnSpawn=false;gui.DisplayOrder=62
 gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.Parent=p:WaitForChild('PlayerGui')
 local label=Instance.new('TextLabel');label.Name='Progress';label.AnchorPoint=Vector2.new(.5,0)
 label.Position=UDim2.new(.5,0,0,8);label.Size=UDim2.new(.42,0,0,38);label.BackgroundColor3=Color3.fromRGB(18,34,64)
 label.TextColor3=Color3.new(1,1,1);label.Font=Enum.Font.GothamBold;label.TextSize=13;label.TextWrapped=true
 label.Visible=false;label.Parent=gui
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,8);corner.Parent=label
 local confirmed=false
 local function update()
  if not confirmed and p:GetAttribute('KDMStarterRewardConfirmed')==true then
   confirmed=true;label.Visible=true;label.Text='TEST DRIVE COMPLETE!  +K$ 5,000 SAVED';label.TextColor3=Color3.fromRGB(90,255,110)
   task.delay(8,function()label.Visible=false end);return
  end
  if confirmed then return end
  label.Visible=p:GetAttribute('KDMEconomyState')=='GUEST' and p:GetAttribute('LobbyDriveActive')==true
  label.Text=if (p:GetAttribute('KDMTestDriveMovingSeconds')or 0)>=30 and (p:GetAttribute('KDMTestDriveDistance')or 0)>=300 then 'TEST DRIVE COMPLETE - SAVING K$5,000...' else string.format('STARTER REWARD: K$5,000\nDRIVE %d/30s - DISTANCE %d/300',math.min(30,p:GetAttribute('KDMTestDriveMovingSeconds')or 0),math.min(300,p:GetAttribute('KDMTestDriveDistance')or 0))
 end
 for _,a in {'KDMStarterRewardConfirmed','KDMEconomyState','LobbyDriveActive','KDMTestDriveMovingSeconds','KDMTestDriveDistance'}do p:GetAttributeChangedSignal(a):Connect(update)end
 update()
end
return View
