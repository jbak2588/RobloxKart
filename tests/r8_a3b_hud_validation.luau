local fs,luau=require('@lune/fs'),require('@lune/luau')
-- Original HUD assertions remain intact; add requirements for the new separate save row.
local source=fs.readFile('tests/race_result_hud_validation.luau')..[[
results=playerGui:FindFirstChild('RobloxKartRaceHud').Results
set('RaceParticipantCount',1);set('RaceTotalLaps',2);set('RaceState','FINISHED')
set('RaceFinalTime',112.66);set('RaceLap1Time',58.96);set('RaceLap2Time',53.70)
set('RaceBestLapTime',53.70);set('RaceBestLapNumber',2)
set('RaceRecordSaveState','SAVE_PENDING');set('RaceRecordNewBestRace',false)
check(results.RecordSave.Text=='SAVE PENDING' and results.RecordSave.Visible,'pending separately displayed')
check(results.Total.Visible and results.Total.Text:find('1:52.66',1,true),'official total survives save status')
check(results.Best.Text:find('BEST LAP',1,true),'best lap survives save status')
set('RaceRecordNewBestRace',true)
check(results.RecordSave.Text=='SAVE PENDING','PB flag alone never claims confirmed save')
set('RaceRecordSaveState','SAVE_CONFIRMED')
check(results.RecordSave.Text=='NEW BEST RACE','new full race PB only after receipt')
set('RaceRecordNewBestRace',false)
check(results.RecordSave.Text=='RECORD SAVED','slower full race stored as last')
set('RaceRecordSaveState','SAVE_FAILED')
check(results.RecordSave.Text=='RECORD SAVE UNCONFIRMED','no false success')
set('RaceRecordSaveState','NONE');check(not results.RecordSave.Visible,'ordinary accounts retain original HUD')
check(results:FindFirstChild('ReturnGarage',true).Text=='LOBBY','Lobby label preserved')
for _,size in {rb.Vector2.new(932,430),rb.Vector2.new(844,390),rb.Vector2.new(748,303),rb.Vector2.new(724,311),rb.Vector2.new(724,260)} do
 safeSize=size;camera.ViewportSize=size
 for _,racers in {1,4} do
  set('RaceParticipantCount',racers);set('RaceTotalLaps',3);set('RaceRecordSaveState','SAVE_CONFIRMED')
  camera:GetPropertyChangedSignal('ViewportSize'):Fire()
  local origin=results.AbsolutePosition-hud.AbsolutePosition
  check(origin.Y>=0 and origin.Y+results.AbsoluteSize.Y<=size.Y,'save row result safe bounds')
  check(contentFits(),'all lap/total/save/action rows fit the panel')
 end
end
print('PASS: separate saved/PB row, original timing text and mobile safe result panel')
]]
luau.load(source,{debugName='R8A3B-HUD-original-plus-save-row'})()
