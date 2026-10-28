local fs,luau,rb=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local S=luau.load(fs.readFile("src/client/HubGuidanceState.luau"))()
local count=0
local function check(value,label) assert(value,label);count+=1 end
local s=S.new()
check(S.nextAction(s)=="ROOMS","fresh chooses Garage")
S.returned(s,"TRACKS");check(S.nextAction(s)=="ROOMS","free Track browse is not confirmation")
S.returned(s,"GARAGE");check(S.nextAction(s)=="ROOMS","default kart Garage visit sufficient")
for _=1,10 do S.returned(s,"TRACKS");check(S.nextAction(s)=="ROOMS","Back never confirms Track") end
S.confirmed(s,"Track01Race");check(S.nextAction(s)=="ROOMS","confirmed Track routes Rooms")
check(s.trackId=="Track01Race","acknowledged track identity retained")
S.returned(s,"GARAGE");check(S.nextAction(s)=="ROOMS","later Garage does not reset progress")
S.returned(s,"RACE_RETURN");check(s.context=="NEXT_RACE" and S.nextAction(s)=="ROOMS","race return bypasses onboarding")
check(S.roomHelper(nil,1)=="CREATE OR JOIN A RACE","browser helper")
check(S.roomHelper({room={hostUserId=1,state="WAITING"}},1):find("OPTIONAL")~=nil,"host optional Invite")
check(not S.roomHelper({room={hostUserId=2,state="WAITING"}},1):find("INVITE"),"nonhost no host instruction")
check(S.roomHelper({room={membershipKind="QUEUED"}},1)=="WAITING FOR NEXT RACE","queue owns waiting")
check(S.prepHelper("PRE_RACE","WAITING",false)=="SELECT ITEMS • CONFIRM & READY","prep instructions")
check(S.prepHelper("PRE_RACE","WAITING",true)=="READY • WAITING FOR START","ready wait")
for _,phase in {"COUNTDOWN","RACING","FINISHED","GARAGE"} do check(S.prepHelper(phase,"WAITING",false)==nil,"no racing prep overlay") end
print("PASS: "..count.." world/race progression state contracts")
local fixture=fs.readFile("tests/garage_transition_validation.luau")
local marker="local firstDisplay=hub.KDMClientShowroom"
local injection=[[
local card=hubGui.SafeCanvas.NextAction
local world=hub.KDMClientWorldGuidance
check(card.SelectTrack.Text=="RACE NOW" and card.FreeTestDrive.Text=="TEST DRIVE","current immediate race/practice CTAs")
check(#world:GetChildren()==3,"one three-direction world guidance set")
local quick,drive=0,0
child(client,'ModuleScript','MatchRoomUiController');modules.MatchRoomUiController={quickStart=function()quick+=1 end}
child(client,'ModuleScript','LobbyTestDriveController');modules.LobbyTestDriveController={requestDrive=function()drive+=1 end}
card.SelectTrack.Activated:Fire();check(quick==1 and drive==0,"Race Now reaches quickStart directly")
card.FreeTestDrive.Activated:Fire();check(drive==1 and quick==1,"Test Drive uses its separate entry")
player:SetAttribute('LobbyDriveActive',true)
card.SelectTrack.Activated:Fire();card.FreeTestDrive.Activated:Fire()
check(quick==1 and drive==1,"active driving blocks duplicate starts")
player:SetAttribute('LobbyDriveActive',false)
player:SetAttribute('KDMShopOpen',true);card.SelectTrack.Activated:Fire()
check(quick==1,"shop owns attention")
player:SetAttribute('KDMShopOpen',false)
player:SetAttribute('RaceState','RACING');check(not hubGui.Enabled,"Hub UI hidden during racing")
player:SetAttribute('RaceState','GARAGE')
local oldWorld=world;hubGui:Destroy();check(oldWorld.Parent==nil,"owned world guidance tears down")
hubController.start();check(#hub.KDMClientWorldGuidance:GetChildren()==3,"restart does not duplicate directions")
playerGui.KDMHubNavigation:Destroy()
print('PASS current Race Now/Test Drive guidance and input ownership integration')
]]
local start=assert(fixture:find(marker,1,true))
luau.load(fixture:sub(1,start-1)..injection)()
