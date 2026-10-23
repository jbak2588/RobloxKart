local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/mobile_touch_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('local input=modules.KartInputController; input.start()',1,true))-1)
local scenario=[=[
local now=0;local viewEnv=table.clone(env);viewEnv.workspace={GetServerTimeNow=function()return now end}
local View=luau.load(fs.readFile('src/client/RookieParkTrialView.luau'),{environment=viewEnv})()
local replays,returns=0,0
local view=View.new(pg,player,function()replays+=1 end,function()returns+=1 end)
local gui=pg.KDMRookieParkTrial;local root=gui:FindFirstChildOfClass('Frame');local panel=root.LapResult
local projected=rb.Vector3.new(30,20,10)
local camera={ViewportSize=V2.new(844,390),WorldToViewportPoint=function()return projected end}
check(View.format(61234)=='01:01.234','lap clock millisecond format')
for _,size in {V2.new(750,332),V2.new(844,390),V2.new(932,430),V2.new(390,703)}do
 safeSize=size;camera.ViewportSize=size
 player:SetAttribute('ParkTrialPhase','COUNTDOWN');player:SetAttribute('ParkTrialGoAt',3)
 for _,case in {{0,'3'},{1,'2'},{2,'1'}}do now=case[1];view:update(true,camera);check(root.Countdown.Visible and root.Countdown.Text==case[2],'server countdown display '..case[2])end
 now=3;player:SetAttribute('ParkTrialPhase','RUNNING');player:SetAttribute('ParkTrialStartedAt',3)
 player:SetAttribute('ParkTrialCheckpoint',2);player:SetAttribute('ParkTrialTarget',rb.Vector3.zero)
 view:update(true,camera);check(root.Countdown.Text=='GO!'and root.Timing.Visible,'GO then individual timer')
 player:SetAttribute('ParkTrialMissed',true);projected=rb.Vector3.new(0,20,10);now=10
 view:update(true,camera);check(root.CheckpointDirection.Text:find('MISSED CP 3',1,true)~=nil,'first missed checkpoint number')
 check(root.CheckpointDirection.Text:find('◀',1,true)~=nil,'left target has left arrow')
 projected=rb.Vector3.new(0,0,-1);view:update(true,camera)
 check(root.CheckpointDirection.Text:find('↶',1,true)~=nil,'behind camera requests turn back')
 local cue=root.CheckpointDirection
 check(cue.Position.X.Scale>=.1799 and cue.Position.X.Scale<=.8201 and cue.Position.Y.Scale>=.2399 and cue.Position.Y.Scale<=.6601,'direction stays inside central safe screen')
 player:SetAttribute('ParkTrialPhase','FINISHED');player:SetAttribute('ParkTrialMilliseconds',61234)
 player:SetAttribute('KDMRookieParkBestMilliseconds',60000);player:SetAttribute('ParkTrialRewardState','SAVING')
 view:update(true,camera)
 check(panel.Visible and not root.Timing.Visible and panel.LapTime.Text=='01:01.234','lap result replaces running timer')
 check(not panel.Replay.Active and not panel.Reward.Text:find('EARNED',1,true),'no reward success before storage confirmation')
 player:SetAttribute('ParkTrialRewardState','CONFIRMED');view:update(true,camera)
 check(panel.Reward.Text:find('+ K$5,000',1,true)~=nil and panel.SaveState.Text:find('SAVED',1,true)~=nil,'confirmed K$5000 reward highlighted')
 check(panel.PersonalBest.Text:find('01:00.000',1,true)~=nil,'persistent personal best visible')
 check(panel.BackgroundTransparency>=.3 and panel.BackgroundColor3.B>.4,'bright translucent result backdrop')
 for _,node in {panel.Replay,panel.ReturnLobby}do
  check(node.AbsoluteSize.Y>=44,'result action target size')
  check(node.AbsolutePosition.Y+node.AbsoluteSize.Y<=panel.AbsolutePosition.Y+panel.AbsoluteSize.Y,'result buttons within panel')
 end
 panel.Replay.Activated:Fire();panel.ReturnLobby.Activated:Fire()
 check(replays>0 and returns>0,'result actions wired separately')
 player:SetAttribute('ParkTrialPhase','INVALID');view:update(true,camera)
 check(panel.Visible and panel.Reward.Text:find('K$0',1,true)~=nil,'invalid lap never presents reward')
end
view:update(false,camera);check(not gui.Enabled,'leave clears trial HUD')
view:destroy();check(gui.Parent==nil,'destroy cleanup')
print('PASS '..count..' production Park result/countdown/target/reward presentation checks')
]=]
local loader=require('./helpers/gameplay_config')
luau.load(prefix..scenario,{environment={require=function(path)if path=='./helpers/gameplay_config'then return loader end;return require(path)end}})()
