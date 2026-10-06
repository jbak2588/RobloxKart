local fs,luau,rb=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local S=luau.load(fs.readFile("src/client/HubGuidanceState.luau"))()
local count=0
local function check(value,label) assert(value,label);count+=1 end
local s=S.new()
check(S.nextAction(s)=="GARAGE","fresh chooses Garage")
S.returned(s,"TRACKS");check(S.nextAction(s)=="GARAGE","free Track browse is not confirmation")
S.returned(s,"GARAGE");check(S.nextAction(s)=="TRACKS","default kart Garage visit sufficient")
for _=1,10 do S.returned(s,"TRACKS");check(S.nextAction(s)=="TRACKS","Back never confirms Track") end
S.confirmed(s,"Track01Race");check(S.nextAction(s)=="ROOMS","confirmed Track routes Rooms")
check(s.trackId=="Track01Race","acknowledged track identity retained")
S.returned(s,"GARAGE");check(S.nextAction(s)=="ROOMS","later Garage does not reset progress")
S.returned(s,"RACE_RETURN");check(s.context=="NEXT_RACE" and S.nextAction(s)=="ROOMS","race return bypasses onboarding")
check(S.roomHelper(nil,1)=="CREATE OR JOIN A ROOM","browser helper")
check(S.roomHelper({room={hostUserId=1,state="WAITING"}},1):find("OPTIONAL")~=nil,"host optional Invite")
check(not S.roomHelper({room={hostUserId=2,state="WAITING"}},1):find("INVITE"),"nonhost no host instruction")
check(S.roomHelper({room={membershipKind="QUEUED"}},1)=="WAITING FOR NEXT RACE","queue owns waiting")
check(S.prepHelper("PRE_RACE","WAITING",false)=="SELECT ITEMS • CONFIRM & READY","prep instructions")
check(S.prepHelper("PRE_RACE","WAITING",true)=="READY • WAITING FOR START","ready wait")
for _,phase in {"COUNTDOWN","RACING","FINISHED","GARAGE"} do check(S.prepHelper(phase,"WAITING",false)==nil,"no racing prep overlay") end
print("PASS: "..count.." world/race progression state contracts")
local fixture=fs.readFile("tests/garage_transition_validation.luau")
local marker="local firstDisplay=hub.KDMClientMyKartDisplay"
local injection=[[
local card=hubGui.SafeCanvas.NextAction
local world=hub.KDMClientWorldGuidance
check(card.SelectTrack.Text=="CHOOSE KART" and #world:GetChildren()==3,"fresh Garage card plus three floor directions")
local theme=modules.KDMUiTheme
local function active(destination)
 local n=0
 for _,p in world:GetChildren() do
  check(p.Anchored and not p.CanCollide and not p.CanTouch and not p.CanQuery and not p.CastShadow,"visual flags")
  local text
  for _,node in p.Direction:GetDescendants() do if node.ClassName=="TextLabel" then text=node end end
  if text.TextColor3==theme.PrimaryAction then n+=1;check(p.Name==destination,"correct active destination") end
 end
 check(n==(if destination then 1 else 0),"only one active emphasis")
end
active("GARAGE")
card.SelectTrack.Activated:Fire();check(backdrop.GarageStep.Text=="KART GARAGE","fresh CTA enters real Garage")
active(nil);controller.close();check(card.SelectTrack.Text=="SELECT TRACK","Garage return advances")
active("TRACKS")
card.SelectTrack.Activated:Fire();controller.close()
check(card.SelectTrack.Text=="SELECT TRACK","opening Track without confirm never advances")
modules.TrackCatalog.Entries.Track01.MatchType="PUBLIC_RACE"
card.SelectTrack.Activated:Fire();selectButton.Activated:Fire()
check(card.SelectTrack.Text=="SELECT TRACK","public confirmation waits for server browser acknowledgement")
replicated.MatchRoomControl.OnClientEvent:Fire("Snapshot",{visible=true,trackId="Track01",room=nil})
controller.close()
check(card.SelectTrack.Text=="ROOMS","server browser acknowledgement confirms public Track")
active("RACE")
local before=remote.fireCount
card.SelectTrack.Activated:Fire()
check(remote.fireCount==before+1 and remote.lastFire[1]=="Ready","Rooms CTA reuses existing Ready contract")
check(remote.lastFire[4]=="Track01","existing selected track identity retained")
modules.TrackCatalog.Entries.InvitedPublic={MatchType="PUBLIC_RACE"}
replicated.MatchRoomControl.OnClientEvent:Fire("Snapshot",{visible=true,trackId="InvitedPublic",room=nil})
card.SelectTrack.Activated:Fire()
check(remote.lastFire[4]=="InvitedPublic","Rooms retains acknowledged invite track independent of preview index")
modules.TrackCatalog.Entries.InvitedPublic=nil
services.ProximityPromptService.PromptTriggered:Fire(prompt,player);controller.close()
check(card.SelectTrack.Text=="ROOMS","progress survives later Garage")
for _=1,3 do player.CharacterAdded:Fire(player.Character);hubController.start();check(#world:GetChildren()==3,"respawn no duplicate markers") end
modules.TrackCatalog.Entries.Track01.MatchType="SOLO_PRACTICE"
]]
assert(fixture:find(marker,1,true))
fixture=fixture:gsub(marker,function()return injection.."\n"..marker end,1)
local cleanup="hubGui:Destroy()"
fixture=fixture:gsub("hubGui:Destroy%(%)",function()return [[
local oldWorld=hub.KDMClientWorldGuidance
child(client,"ModuleScript","RoomDisplay")
modules.RoomDisplay=luau.load(fs.readFile("src/client/RoomDisplay.luau"))()
local roomController=luau.load(fs.readFile("src/client/MatchRoomUiController.luau"),{environment=environment})()
roomController.start();roomController.start()
local roomGui=playerGui.KDMMatchRooms
playerGui.ChildAdded:Fire(roomGui)
local helper=roomGui:FindFirstChild("NextAction",true)
local roomRemote=replicated.MatchRoomControl
roomRemote.OnClientEvent:Fire("Snapshot",{visible=true,trackId="Track01",rooms={},maxPlayers=4})
check(helper.Text=="CREATE OR JOIN A ROOM" and not hubGui.SafeCanvas.NextAction.Visible,"real room browser guidance owns attention")
roomRemote.OnClientEvent:Fire("Snapshot",{visible=true,room={state="WAITING",hostUserId=player.UserId,hostName="Host",members={{name="Host"}},available={},maxPlayers=4}})
check(helper.Text:find("OPTIONAL") and not helper.Text:find("CREATE"),"real joined host guidance")
roomRemote.OnClientEvent:Fire("Snapshot",{visible=true,room={state="WAITING",hostUserId=2,hostName="Host",members={{name="Host"}},available={},maxPlayers=4}})
check(helper.Text=="WAIT FOR HOST • ITEMS NEXT","real nonhost helper")
player:SetAttribute("RaceState","RACING");check(not roomGui.Enabled,"real room UI hidden during race")
roomRemote.OnClientEvent:Fire("Snapshot",{visible=true,rooms={},maxPlayers=4})
check(not roomGui.Enabled,"late room snapshot cannot reopen racing overlay")
player:SetAttribute("RaceState","GARAGE")
local listeners=roomRemote.OnClientEvent.count()
roomGui:Destroy();check(roomRemote.OnClientEvent.count()==listeners-1,"room helper controller cleanup")
hubGui:Destroy()
check(oldWorld.Parent==nil,"world view cleanup")
hubController.start();hubController.start()
check(#hub.KDMClientWorldGuidance:GetChildren()==3,"restart one world view")
hubGui=playerGui.KDMHubNavigation;hubGui:Destroy()
]] end,1)
luau.load(fixture)()
