local fs,luau=require('@lune/fs'),require('@lune/luau')
-- Execute the existing service fixture with full result inputs and retain its assertions.
local source=fs.readFile('tests/r8_a3_service_validation.luau')
source=source:gsub("check%(scope=='Track02_V2B_R1_SOLO_1H_0B'", "check(scope==(if name=='KDM_A3_Race_v1' then 'Track02_V2B_R1_SOLO_1H_0B_L2' else 'Track02_V2B_R1_SOLO_1H_0B')")
source=source:gsub('Service%.lap%(p,lap%*20%)','Service.lap(p,lap*20,20)')
source=source:gsub("p.attrs.RaceState='FINISHED';Service.finish%(p%)", "p.attrs.RaceState='FINISHED';Service.finish(p,{totalTime=40,position=1,positionFinalized=true})")
source=source:gsub('indexCalls==2','indexCalls==3')
source..=[[
local raceScope=S.raceScope(scope,2)
check(value.records.races[raceScope].bestRace.totalMilliseconds==40000,'real service full race timer')
check(value.records.races[raceScope].lastRace.roundGuid==secondGuid,'real service Rematch last snapshot')
check(#value.records.races[raceScope].bestRace.laps==2,'service stores every approved lap')
check(index.KDM_A3_Race_v1==40000 and index.KDM_A3_Lap_v1==20000 and index.KDM_A3_Drift_v1==1,'new race index and old indexes coexist')
check(next(value.pendingRaceIndex)==nil,'actual race index repair clears only confirmed snapshot')
]]
luau.load(source,{debugName='R8A3B-service-full-result'})()

-- Extend the actual adapter/runtime outage fixture with full result snapshots.
source=fs.readFile('tests/r8_a3_runtime_validation.luau')
local anchor='bestLapMilliseconds=45000,bestRaceBoosts=9,'
source=source:gsub(anchor,[[
race={trackId='Track02',geometryId='PrototypeCircuitV2B',rulesetId='KDM_R8A3_RULES_V1',category='SOLO_1H_0B',
 recordScope=S.recordScope('Track02','PrototypeCircuitV2B','KDM_R8A3_RULES_V1','SOLO_1H_0B'),
 targetLaps=2,roundGuid=id or guid,userId=1,totalMilliseconds=95000,laps={45000,50000},finishPosition=1,
 startingHumans=1,startingBots=0,raceBoosts=9,finishedAt=1791650000000,eligible=true,reason='FULL_ROUTE_V1',
 serverAccepted=true,state='FINISHED',positionFinalized=true},bestLapMilliseconds=45000,bestRaceBoosts=9,
]])
source=source:gsub('local k=entry.geometryId',[[if entry.kind=='RACE' then backend.indices.fullRace=entry.snapshot.totalMilliseconds;return true end
local k=entry.geometryId]])
source..=[[
local fullScope=S.raceScope(scope,2)
check(b.value.records.races[fullScope].bestRace.totalMilliseconds==95000,'ACK loss/outage fixture preserves full race')
check(selected.records.races[fullScope].bestRace.roundGuid==guid,'later A2 kart selection preserves full snapshot')
b,p,r,drain=fixture();b.callbackReplay=true;b.ackLost=true;r.submit(p,operation());drain()
check(p.attrs.RaceRecordNewBestRace and p.attrs.RaceRecordSaveState=='SAVE_CONFIRMED','race PB shown only after uncached receipt')
check(b.value.records.races[fullScope].lastRace.totalMilliseconds==95000 and b.indices.fullRace==95000,'profile confirmed and eventual race index')
b,p,r,drain=fixture();b.indexFail=true;r.submit(p,operation());drain()
check(b.value.pendingRaceIndex[fullScope] and p.attrs.RaceRecordSaveState=='SAVE_CONFIRMED','race index outage retains confirmed profile')
b.indexFail=false;r.read(p);check(next(b.value.pendingRaceIndex)==nil,'returning HUB repairs race index')
]]
luau.load(source,{debugName='R8A3B-runtime-full-result'})()

-- Actual RaceController and RaceSession: all four finalized positions and approved timers.
source=fs.readFile('tests/r8_a3_controller_validation.luau')
source=source:gsub('lap=function%(p%)',[[lap=function(p,now,lapTime)
 check(type(lapTime)=='number' and lapTime>0,'official approved lap clock forwarded')]])
source=source:gsub('finish=function%(p%)',[[finish=function(p,result)
 check(result and result.positionFinalized and result.position==p:GetAttribute('RaceFinishPosition'),'settled official position forwarded')
 check(result.totalTime==p:GetAttribute('RaceFinalTime'),'official entire race timer forwarded unchanged')]])
local helper=require('./helpers/gameplay_config')
luau.load(source,{debugName='R8A3B-real-controller',environment={require=function(path)
 if path=='./helpers/gameplay_config' then return helper end;return require(path)
end}})()
print('PASS: full-result service, outage adapter and actual four-player controller integration')
