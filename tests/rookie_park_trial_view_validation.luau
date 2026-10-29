local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/mobile_touch_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local input=modules.KartInputController; input.start()',1,true))-1)
local scenario=[=[
services.GuiService.TopbarInset=rb.Rect.new(0,0,932,58)
services.TextService={GetTextSize=function()return V2.new(380,80)end}
local now=0;local viewEnv=table.clone(env);viewEnv.workspace={GetServerTimeNow=function()return now end}
local viewShared={KDMFinishPresentation=object('ModuleScript','KDMFinishPresentation')}
viewEnv.game={GetService=function(_,name)if name=='ReplicatedStorage'then return {Shared=viewShared}end;return services[name]end}
local result=luau.load(fs.readFile('src/client/ResultPresentationView.luau'),{environment=viewEnv})()
local finish=luau.load(fs.readFile('src/shared/KDMFinishPresentation.luau'))()
viewEnv.script={Parent={ResultPresentationView='result'}}
viewEnv.require=function(ref)if ref=='result'then return result elseif ref==viewShared.KDMFinishPresentation then return finish else return modules.MobileControlView end end
local View=luau.load(fs.readFile('src/client/RookieParkTrialView.luau'),{environment=viewEnv})()
local replays,returns=0,0
local view=View.new(pg,player,function()replays+=1 end,function()returns+=1 end)
local gui=pg.KDMRookieParkTrial;local root=gui:FindFirstChildOfClass('Frame');local panel=root.LapResult
local timing=pg.KDMRookieParkTopHud.Timing
local projected=rb.Vector3.new(30,20,10)
local camera={ViewportSize=V2.new(844,390),WorldToViewportPoint=function()return projected end}
check(View.format(61234)=='01:01.234','lap clock millisecond format')
for _,size in {V2.new(750,332),V2.new(844,390),V2.new(932,430),V2.new(390,703)}do
 safeSize=size;camera.ViewportSize=size
 player:SetAttribute('ParkTrialPhase','COUNTDOWN');player:SetAttribute('ParkTrialGoAt',3);player:SetAttribute('ParkTrialCurrentLap',1);player:SetAttribute('ParkTrialCompletedLaps',0)
 for _,case in {{0,'3'},{1,'2'},{2,'1'}}do now=case[1];view:update(true,camera);check(root.Countdown.Visible and root.Countdown.Text==case[2],'server countdown display '..case[2])end
 now=3;player:SetAttribute('ParkTrialPhase','RUNNING');player:SetAttribute('ParkTrialStartedAt',3)
 player:SetAttribute('ParkTrialCheckpoint',2);player:SetAttribute('ParkTrialTarget',rb.Vector3.zero)
 view:update(true,camera);check(root.Countdown.Text=='GO!'and timing.Visible,'GO then individual timer')
 player:SetAttribute('ParkTrialMissed',true);now=10;view:update(true,camera)
 check(timing.Text:find('MISSED 3',1,true)~=nil,'missed checkpoint number remains in unified top timing HUD')
 check(pg.KDMRookieParkTopHud.ScreenInsets==rb.Enum.ScreenInsets.None and timing.Parent==pg.KDMRookieParkTopHud,'lap clock uses same topbar surface as Roblox logo')
 check(root.FinishBanner.FinishText.FinishOutline.Thickness>=3,'shared FINISH has a thick black outline')
 check(root:FindFirstChild('CheckpointDirection')==nil,'custom Park marker removed in favor of shared Figure-8 controller')
 player:SetAttribute('ParkTrialCurrentLap',2);player:SetAttribute('ParkTrialCompletedLaps',1);view:update(true,camera)
 check(root.FinalLapNotice.Visible and root.FinalLapNotice.Text=='FINAL LAP','lap two displays shared-style Final Lap notice')
 now+=2;view:update(true,camera);check(not root.FinalLapNotice.Visible,'Final Lap notice expires without repeating')
 player:SetAttribute('ParkTrialPhase','FINISHING');view:update(true,camera)
 check(not panel.Visible,'result waits for roll and front camera transition')
 player:SetAttribute('ParkTrialPhase','FINISHED');player:SetAttribute('ParkTrialMilliseconds',61234)
 player:SetAttribute('KDMRookieParkTwoLapBestMilliseconds',60000);player:SetAttribute('ParkTrialRewardState','SAVING')
 view:update(true,camera)
 check(panel.Visible and not timing.Visible and panel.LapTime.Text=='01:01.234','lap result replaces running timer')
 check(panel.Replay.Active and panel.Replay.Text=='REPLAY'and not panel.Reward.Text:find('EARNED',1,true),'save pending permits Replay without claiming reward success')
 player:SetAttribute('ParkTrialRewardState','CONFIRMED');view:update(true,camera)
 check(panel.Reward.Text:find('+ K$5,000',1,true)~=nil and panel.SaveState.Text:find('SAVED',1,true)~=nil,'confirmed K$5000 reward highlighted')
 check(panel.NextReward.Text:find('X2',1,true)~=nil,'first result previews X2 Replay reward')
 check(panel.NextReward.Font==rb.Enum.Font.GothamBlack and panel.NextReward.BackgroundTransparency<.2,'next Replay reward has a strong gold-accent card')
 check(panel.NextReward.AbsolutePosition.Y+panel.NextReward.AbsoluteSize.Y<=panel.Replay.AbsolutePosition.Y,'emphasized next reward clears actions at every viewport')
 check(panel.PersonalBest.Text:find('01:00.000',1,true)~=nil,'persistent personal best visible')
 player:SetAttribute('KDMRookieParkTwoLapBestMilliseconds',nil);player:SetAttribute('ParkTrialRewardState','UNCONFIRMED');view:update(true,camera)
 check(panel.Replay.Active and panel.Replay.Text=='REPLAY'and panel.PersonalBest.Text:find('NOT SAVED',1,true)~=nil,'failed save neither blocks Replay nor shows perpetual SAVING')
 check(panel.BackgroundTransparency>=.3 and panel.BackgroundColor3.B>.4,'bright translucent result backdrop')
 for _,node in {panel.Replay,panel.ReturnLobby}do
  check(node.AbsoluteSize.Y>=44,'result action target size')
  check(node.AbsolutePosition.Y+node.AbsoluteSize.Y<=panel.AbsolutePosition.Y+panel.AbsoluteSize.Y,'result buttons within panel')
 end
 player:SetAttribute('ParkTrialRewardMultiplier',2);player:SetAttribute('ParkTrialRewardAmount',10000);view:update(true,camera)
 check(panel.Reward.Text:find('K$10,000',1,true)and panel.NextReward.Text:find('X3',1,true),'second result previews X3 and displays its actual X2 reward')
 player:SetAttribute('ParkTrialRewardMultiplier',nil);player:SetAttribute('ParkTrialRewardAmount',nil)
 panel.Replay.Activated:Fire();panel.ReturnLobby.Activated:Fire()
 check(replays>0 and returns>0,'result actions wired separately')
 player:SetAttribute('ParkTrialPhase','INVALID');view:update(true,camera)
 check(panel.Visible and panel.Reward.Text:find('K$0',1,true)~=nil,'invalid lap never presents reward')
end
safeSize=V2.new(844,390);camera.ViewportSize=safeSize
player:SetAttribute('ParkOvertakeActive',true);player:SetAttribute('ParkTrialPhase','COUNTDOWN');player:SetAttribute('ParkTrialGoAt',now+4)
view:update(true,camera)
local instructions=pg.KDMRookieParkTopHud.OvertakeInstructions
check(instructions.Visible and instructions.Parent==pg.KDMRookieParkTopHud,'instructions use top HUD independently from CoreUI-inset driving canvas')
check(instructions.Position.Y.Offset>=0 and instructions.Position.Y.Offset<=12 and instructions.Size.Y.Offset<=88,'compact instructions stay at top edge')
check(instructions.Size.X.Offset<=404,'instruction background fits measured text plus 24px padding')
services.GuiService.TopbarInset=rb.Rect.new(208,0,844,58);view:update(true,camera)
check(instructions.Position.X.Offset-instructions.Size.X.Offset/2>=220,'instructions clear native Roblox icons by 12px')
check(instructions.Position.X.Offset+instructions.Size.X.Offset/2<=708,'instructions reserve right-side minimap clearance')
player:SetAttribute('ParkTrialGoAt',now+3);view:update(true,camera)
check(instructions.Visible,'instructions remain visible at three seconds')
player:SetAttribute('ParkTrialGoAt',now+2);view:update(true,camera)
check(instructions.Visible,'instructions remain visible at two seconds')
player:SetAttribute('ParkTrialGoAt',now+1);view:update(true,camera)
check(not instructions.Visible,'instructions disappear exactly at one second')
view:update(false,camera);check(not gui.Enabled,'leave clears trial HUD')
view:destroy();check(gui.Parent==nil,'destroy cleanup')
print('PASS '..count..' production Park result/countdown/target/reward presentation checks')
]=]
local loader=require('./helpers/gameplay_config')
luau.load(prefix..scenario,{environment={require=function(path)if path=='./helpers/gameplay_config'then return loader end;return require(path)end}})()
