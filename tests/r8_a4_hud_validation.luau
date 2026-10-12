local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/race_result_hud_validation.luau')
source..=[[
set('RaceState','FINISHED');set('RaceTotalLaps',2);set('RaceParticipantCount',1)
set('RaceRecordSaveState','SAVE_CONFIRMED');set('RaceMoneyState','SAVE_PENDING')
check(results.RecordSave.Text:find('PAYMENT UNCONFIRMED',1,true) and not results.RecordSave.Text:find('K$50',1,true),'pending never reports payout')
set('RaceMoney_base',35);set('RaceMoney_bestRace',10);set('RaceMoney_bestLap',5);set('RaceMoney_total',50);set('RaceMoneyState','SAVE_CONFIRMED')
check(results.RecordSave.Text:find('K$50',1,true) and results.RecordSave.Text:find('BASE 35',1,true)
 and results.RecordSave.Text:find('RACE PB 10',1,true) and results.RecordSave.Text:find('LAP PB 5',1,true),'confirmed breakdown')
for _,size in {rb.Vector2.new(749,323),rb.Vector2.new(844,390),rb.Vector2.new(932,430)} do
 safeSize=size;hud.AbsoluteSize=size;camera.ViewportSize=size;camera:GetPropertyChangedSignal('ViewportSize'):Fire()
 check(contentFits(),'money result within mobile safe area '..tostring(size))
end
set('RaceRecordSaveState','SAVE_FAILED');set('RaceMoneyState','SAVE_FAILED')
check(not results.RecordSave.Text:find('K$50',1,true),'failed result cannot retain earned amount')
]]
luau.load(source,{debugName='A4-confirmed-money-HUD'})()
