local View={}
function View.start()
 local player=game:GetService('Players').LocalPlayer
 local service=game:GetService('GuiService')
 local gui=Instance.new('ScreenGui');gui.Name='KDMPublicRaceStatus';gui.ResetOnSpawn=false
 gui.ScreenInsets=Enum.ScreenInsets.None;gui.ClipToDeviceSafeArea=false;gui.DisplayOrder=31;gui.Parent=player:WaitForChild('PlayerGui')
 local text=Instance.new('TextLabel');text.Name='PublicMatchStatus';text.AnchorPoint=Vector2.new(.5,0)
 text.BackgroundColor3=Color3.fromRGB(18,34,58);text.BackgroundTransparency=.12
 text.TextColor3=Color3.fromRGB(255,225,60);text.Font=Enum.Font.GothamBold;text.TextSize=14;text.TextWrapped=true;text.Parent=gui
 local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,10);c.Parent=text
 local connections={}
 local top=gui.Parent:FindFirstChild('RobloxKartMobileTopHud')
 local hud=gui.Parent:FindFirstChild('RobloxKartRaceHud')
 local map=(top and top:FindFirstChild('RaceMiniMap'))or(hud and hud:FindFirstChild('RaceMiniMap'))
 local function layout()
  -- Physical top band shared with Core UI and the minimap. Combat stays below
  -- in CoreUISafeInsets, on every phone/tablet safe height.
  local band=service.TopbarInset
  local camera=workspace.CurrentCamera
  local viewport=if camera then camera.ViewportSize else gui.AbsoluteSize
  local origin=Vector2.new(math.max(0,(gui.AbsoluteSize.X-viewport.X)/2),math.max(0,(gui.AbsoluteSize.Y-viewport.Y)/2))
  local left=math.max(12,band.Min.X+origin.X+8)
  local right=math.min(gui.AbsoluteSize.X-12,band.Max.X+origin.X-8)
  if map and map.Visible then right=math.min(right,map.AbsolutePosition.X-gui.AbsolutePosition.X-8)end
  local width=math.max(0,math.min(600,right-left))
  local height=math.max(28,math.min(40,band.Height-8))
  text.Position=UDim2.fromOffset((left+right)/2,math.max(4,origin.Y+band.Min.Y+(band.Height-height)/2))
  text.Size=UDim2.fromOffset(width,height)
 end
 local function update()
  local notice=player:GetAttribute('RacePublicJoinNotice')
  local warmup=player:GetAttribute('RacePublicWarmup')==true
  local practice=player:GetAttribute('RacePrivatePractice')==true
  local state=player:GetAttribute('RaceState')
  text.Visible=(state=='RACING'or state=='COUNTDOWN'or state=='PRE_RACE')and ((type(notice)=='string'and notice~='')or warmup or practice)
  text.Text=if type(notice)=='string'and notice~=''then notice elseif practice then 'PRIVATE PRACTICE · NO MATCHMAKING'else 'BOT WARM-UP · WAITING FOR PLAYERS'
  layout()
 end
 for _,name in {'RacePublicWarmup','RacePublicJoinNotice','RacePrivatePractice','RaceState'}do table.insert(connections,player:GetAttributeChangedSignal(name):Connect(update))end
 for _,name in {'AbsoluteSize','AbsolutePosition'}do table.insert(connections,gui:GetPropertyChangedSignal(name):Connect(layout))end
 table.insert(connections,service:GetPropertyChangedSignal('TopbarInset'):Connect(layout))
 if map then for _,name in {'AbsolutePosition','AbsoluteSize','Visible'}do table.insert(connections,map:GetPropertyChangedSignal(name):Connect(layout))end end
 gui.Destroying:Connect(function()for _,connection in connections do connection:Disconnect()end end)
 update()
end
return View
