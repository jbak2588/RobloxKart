-- Exercise the production Hub with the established Garage/UI fixture.
local fs, luau = require('@lune/fs'), require('@lune/luau')
local fixture = fs.readFile('tests/garage_transition_validation.luau')
local marker = 'local shortcuts=hubGui.Shortcuts'
local probe = [[
local shortcuts=hubGui.Shortcuts
for _,name in {'GarageStationKiosk','RaceStationKiosk','TrackStationKiosk'} do
 local kiosk=child(hub,'Model',name)
 local marker=child(kiosk,'BillboardGui','NavigationMarker');marker.Enabled=true
 player:SetAttribute('HubOverlayOpen',true);player:SetAttribute('HubOverlayOpen',false)
 check(not marker.Enabled,'floating kiosk heading stays hidden '..name)
end
for _,size in {rb.Vector2.new(749,332),rb.Vector2.new(932,352),rb.Vector2.new(1102,407),rb.Vector2.new(1920,1022)} do
 safeSize=size;cameraScreenSize=size;camera.ViewportSize=size
 camera:GetPropertyChangedSignal('ViewportSize'):Fire()
 hubGui.SafeCanvas:GetPropertyChangedSignal('AbsoluteSize'):Fire()
 local wallet=hubGui.WalletCapsule
 check(shortcuts.AbsolutePosition.X==16 and shortcuts.AbsolutePosition.Y>=wallet.AbsolutePosition.Y+wallet.AbsoluteSize.Y+12,'C2 navigation clears wallet')
 local previousBottom=0
 for _,name in {'GARAGE','TRACKS','SHOP'} do
  local b=shortcuts[name]
  check(b.BackgroundTransparency==.58 and b.AbsoluteSize.Y>=44,'C2 transparent 44px menu target')
  check(b.AbsolutePosition.Y>=previousBottom+6,'C2 vertical menu spacing')
  previousBottom=b.AbsolutePosition.Y+b.AbsoluteSize.Y
 end
 -- Native thumbstick artwork starts at y=238 in the smallest Studio probe.
 check(previousBottom<=214,'C2 menu leaves lower-left joystick artwork clear')
 local c=hubGui.SafeCanvas.NextAction
 check(not c.Heading.Visible and c.BackgroundTransparency==1,'C2 has no arrival heading or card fill')
 check(c.FreeTestDrive.AbsolutePosition.Y>=c.SelectTrack.AbsolutePosition.Y+c.SelectTrack.AbsoluteSize.Y+12,'C2 actions always stack vertically')
 check(c.AbsolutePosition.X>=shortcuts.AbsolutePosition.X+shortcuts.AbsoluteSize.X+8,'C2 opposing action lanes do not overlap')
 check(c.FreeTestDrive.AbsoluteSize.Y>=44 and c.SelectTrack.AbsoluteSize.Y>=44,'C2 both CTA targets retain 44px')
end
]]
assert(fixture:find(marker,1,true),'fixture insertion point exists')
fixture=fixture:gsub(marker:gsub('([^%w])','%%%1'),function()return probe end,1)
luau.load(fixture)()
