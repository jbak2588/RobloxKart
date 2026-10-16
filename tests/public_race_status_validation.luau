local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/race_result_hud_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local controller=luau.load',1,true))-1)
local scenario=[=[
common.workspace=workspace
local top=child(playerGui,'ScreenGui','RobloxKartMobileTopHud')
top.ScreenInsets=rb.Enum.ScreenInsets.None
local map=child(top,'Frame','RaceMiniMap');map.Size=rb.UDim2.fromOffset(104,104)
guiService.TopbarInset=rb.Rect.new(208,0,800,58)
local view=luau.load(fs.readFile('src/client/PublicRaceStatusView.luau'),{environment=common})()
view.start()
local public=playerGui.KDMPublicRaceStatus.PublicMatchStatus
for _,size in {rb.Vector2.new(1024,461),rb.Vector2.new(800,370),rb.Vector2.new(750,302),rb.Vector2.new(932,390)}do
 safeSize=size
 camera.ViewportSize=size
 guiService.TopbarInset=rb.Rect.new(208,0,size.X,58)
 map.Position=rb.UDim2.fromOffset(size.X-116,4)
 playerGui.KDMPublicRaceStatus:GetPropertyChangedSignal('AbsoluteSize'):Fire()
 player:SetAttribute('RaceState','RACING');player:SetAttribute('RacePublicWarmup',true)
 check(public.Visible,'warm-up visible in race')
 check(public.AbsolutePosition.X>=216,'Core UI icon clearance')
 check(public.AbsolutePosition.X+public.AbsoluteSize.X<=map.AbsolutePosition.X-8,'minimap clearance')
 check(public.AbsolutePosition.Y>=0 and public.AbsolutePosition.Y+public.AbsoluteSize.Y<=58,'physical topbar band')
 check(public.AbsolutePosition.Y+public.AbsoluteSize.Y<=58+8,'clear of safe-area missile lane')
 player:SetAttribute('RacePublicJoinNotice','PLAYER JOINING · RESTARTING IN 5')
 check(public.Text=='PLAYER JOINING · RESTARTING IN 5','handoff notice same band')
 player:SetAttribute('RacePublicJoinNotice','')
end
player:SetAttribute('RaceState','FINISHED');check(not public.Visible,'finished clears recruitment banner')
local route=luau.load(fs.readFile('src/client/RaceRouteTransitionView.luau'),{environment=common})()
route.start();local gui=playerGui.KDMRaceRouteTransition
check(not gui.Enabled,'no transition at rest')
player:SetAttribute('KDMRoutePending','RACE_LAUNCH')
check(gui.Enabled and gui.Frame.Message.Text=='ENTERING RACE ROOM...','room transfer visible independently of Garage/browser')
player:SetAttribute('KDMRoutePending','');check(not gui.Enabled,'failure/cancel clears transfer')
player:SetAttribute('KDMRoutePending','HUB_RETURN')
check(gui.Enabled and gui.Frame.Message.Text=='RETURNING TO LOBBY...','return transfer message')
print('PASS '..count..' public topbar status / standalone routing checks')
]=]
luau.load(prefix..scenario)()
