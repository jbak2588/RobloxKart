local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/race_result_hud_validation.luau')..[[
results=playerGui:FindFirstChild('RobloxKartRaceHud').Results
set('RaceState','FINISHED');set('RaceRecordSaveState','SAVE_PENDING');set('RaceRecordNewPB',false);set('RaceRecordNewBestRace',false)
check(results.RecordSave.Text=='SAVE PENDING',"pending is not stored success")
set('RaceRecordNewPB',true);set('RaceRecordNewBestRace',true)
check(results.RecordSave.Text=='SAVE PENDING',"PB flag alone cannot claim save")
set('RaceRecordSaveState','SAVE_CONFIRMED')
check(results.RecordSave.Text=='NEW BEST RACE',"confirmed PB displayed")
set('RaceRecordNewPB',false);set('RaceRecordNewBestRace',false)
check(results.RecordSave.Text=='RECORD SAVED',"confirmed existing PB result displayed")
set('RaceRecordSaveState','SAVE_FAILED')
check(results.RecordSave.Text=='RECORD SAVE UNCONFIRMED',"failure is not success")
check(results:FindFirstChild('ReturnGarage',true).Text=='LOBBY',"accepted Lobby label retained")
set('RaceRecordSaveState','NONE')
check(results.Best.Text:find('BEST LAP',1,true)~=nil,"normal user original results preserved")
print('PASS: official saved/PB result presentation; original HUD assertions retained')
]]
luau.load(source,{debugName='R8A3-hud-with-original-assertions'})()
