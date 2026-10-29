-- Reuse the real Garage/Hub signal and responsive-canvas fixture, not a copied UI.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local stateModule=luau.load(fs.readFile("src/client/HubGuidanceState.luau"))()
local n=0
local function check(v,label) assert(v,label);n+=1 end
for _,size in {{844,302},{932,342},{751,244},{760,332},{812,272},{640,230},{390,786},{1920,1022}} do
 for _,action in {"HUB","GARAGE","TRACKS","RACE_RETURN"} do
  local state=stateModule.new()
  if action~="HUB" then stateModule.returned(state,action) end
  local p=stateModule.presentation(state,rb.Vector2.new(size[1],size[2]),"GARAGE",false,"",false)
  check(p.visible,"Hub visible with default Kart")
  check(size[2]-p.bottom-p.height>=0 and p.width+24<=size[1],"safe canvas fits card")
  check(p.compact==(action~="HUB" or size[2]<400),"expanded/return/short policy")
  for _,blocked in {{"RACING",false,"",false},{"GARAGE",true,"",false},
   {"GARAGE",false,"RACE_LAUNCH",false},{"GARAGE",false,"HUB_RETURN",false},{"GARAGE",false,"",true}} do
   check(not stateModule.presentation(state,rb.Vector2.new(size[1],size[2]),unpack(blocked)).visible,"authority precedence")
  end
 end
end
print("PASS: "..n.." guidance state / safe-canvas cases")
local fixture=fs.readFile("tests/garage_transition_validation.luau")
local marker="hubGui:Destroy()"
local injection=[[
local guidance=hubGui.SafeCanvas.NextAction
check(guidance and guidance.Visible,"guidance exists on Hub return")
check((guidance.BackgroundColor3==modules.KDMUiTheme.Panel or guidance.BackgroundTransparency > 0) and not guidance.Active,"non-blocking navy card")
check((guidance.SelectTrack.Text=="RACE NOW" or guidance.SelectTrack.Text=="PLAY TOGETHER"),"race-first primary CTA")
check(guidance:FindFirstChild("FreeTestDrive") ~= nil and (guidance.FreeTestDrive.Text == "TIME ATTACK" or guidance.FreeTestDrive.Text == "TIME ATTACK"), "secondary CTA FreeTestDrive exists")
check(guidance.SelectTrack.AutoLocalize and guidance.Message.AutoLocalize and guidance.Helper.AutoLocalize,"automatic translation candidate")
check(guidance.Helper.Text=="You can use the default kart","Garage is optional")
shortcuts.TRACKS.Activated:Fire()
check(backdrop.TrackPreview.Visible and not hubGui.Enabled,"CTA opens existing Track Select")
controller.close()
check(guidance.Visible and guidance.Heading.Text=="NEXT" and guidance.Message.Text=="Create or join a race","Track return context")
shortcuts.GARAGE.Activated:Fire();controller.close()
check(guidance.Heading.Text=="KART READY" and not guidance.Message.Visible,"Garage return compact")
local roomRemote=replicated.MatchRoomControl
roomRemote.OnClientEvent:Fire("Snapshot",{room={membershipKind="QUEUED"}})
check(not guidance.Visible,"queued membership suppresses guidance")
local previous=remote.fireCount
guidance.SelectTrack.Activated:Fire()
check(not gui.Enabled and remote.fireCount==previous,"queued action cannot compete with room")
roomRemote.OnClientEvent:Fire("Snapshot",{room=nil})
check(guidance.Visible,"cancel queue returns hint")
local rooms=child(playerGui,"ScreenGui","KDMMatchRooms");rooms.Enabled=false
playerGui.ChildAdded:Fire(rooms)
rooms.Enabled=true;check(not guidance.Visible,"Room Browser / invitation UI owns attention")
rooms.Enabled=false;check(guidance.Visible,"Room Browser close restores hint")
player:SetAttribute("KDMRoutePending","HUB_RETURN");check(not guidance.Visible,"route owns guidance")
player:SetAttribute("KDMRoutePending","")
player:SetAttribute("RaceState","FINISHED");player:SetAttribute("RaceState","GARAGE")
check(guidance.Heading.Text=="NEXT RACE","same-server race return context")
for _,resolution in {{932,342},{844,302},{640,230},{751,244},{390,786},{1920,1022}} do
 safeSize=rb.Vector2.new(unpack(resolution));hubGui.SafeCanvas:GetPropertyChangedSignal("AbsoluteSize"):Fire()
 local p,s=guidance.AbsolutePosition,guidance.AbsoluteSize
 check(p.X>=0 and p.Y>=0 and p.X+s.X<=safeSize.X and p.Y+s.Y<=safeSize.Y,"runtime layout within safe bounds")
 check(p.X>=shortcuts.AbsolutePosition.X+shortcuts.AbsoluteSize.X+8,"no overlap with shortcuts")
 check(guidance.SelectTrack.AbsoluteSize.Y>=44,"44px touch target")
 local b=guidance.SelectTrack
 check(b.AbsolutePosition.Y+b.AbsoluteSize.Y<=p.Y+s.Y,"CTA unclipped")
end
for _=1,5 do
 player.CharacterAdded:Fire(player.Character);hubController.start()
 shortcuts.TRACKS.Activated:Fire();controller.close()
 check(#hubGui.SafeCanvas:GetChildren()==1 and guidance.SelectTrack.Activated.count()==1,"respawn/reopen single card and handler")
end
hubGui:Destroy()
check(roomRemote.OnClientEvent.count()==0 and guidance.SelectTrack.Activated.count()==0,"owned Room and CTA connections cleaned")
check(shortcuts.TRACKS.Activated.count()==0 and playerGui.ChildAdded.count()==0,"shortcut and GUI listeners cleaned")
hubController.start();hubController.start()
hubGui=playerGui.KDMHubNavigation
check(#hubGui.SafeCanvas:GetChildren()==1 and roomRemote.OnClientEvent.count()==1,"destroy/restart idempotent")
check(not hubGui.SafeCanvas.NextAction.Message.Visible and hubGui.SafeCanvas.NextAction.SelectTrack.Visible,"fresh controller has minimal actionable guidance")
hubGui:Destroy()
]]
assert(fixture:find(marker,1,true))
fixture=fixture:gsub("hubGui:Destroy%(%)",function()return injection end,1)
luau.load(fixture)()
