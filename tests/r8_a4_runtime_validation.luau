local fs,luau=require('@lune/fs'),require('@lune/luau')
-- Exercise the actual injected API adapter and runtime under ACK loss / CAS / outages.
local source=fs.readFile('tests/r8_a3_runtime_validation.luau')
source=source:gsub('bestLapMilliseconds=45000,bestRaceBoosts=9,',[[
economy={version=1,humanPosition=1},race={trackId='Track02',geometryId='PrototypeCircuitV2B',rulesetId='KDM_R8A3_RULES_V1',category='SOLO_1H_0B',
 recordScope=S.recordScope('Track02','PrototypeCircuitV2B','KDM_R8A3_RULES_V1','SOLO_1H_0B'),
 targetLaps=2,roundGuid=id or guid,userId=1,totalMilliseconds=95000,laps={45000,50000},finishPosition=1,
 startingHumans=1,startingBots=0,raceBoosts=9,finishedAt=1791650000000,eligible=true,reason='FULL_ROUTE_V1',
 serverAccepted=true,state='FINISHED',positionFinalized=true},bestLapMilliseconds=45000,bestRaceBoosts=9,
]])
source=source:gsub('local k=entry.geometryId',[[if entry.kind=='RACE' then return true end
local k=entry.geometryId]])
source..=[[
b,p,r,drain=fixture();b.callbackReplay=true;b.ackLost=true;r.submit(p,operation());drain()
print('R3_TRACE ACK',b.value.wallet.cash,b.value.wallet.lifetimeEarned,b.value.onboarding.finishEvent.claimed)
check(b.value.wallet.cash==7500 and b.value.wallet.lifetimeEarned==7500,'lost ACK credits exactly once')
check(p.attrs.RaceMoneyState=='SAVE_CONFIRMED' and p.attrs.RaceMoney_total==7500,'payment only after uncached receipt')
r.submit(p,operation());drain();check(b.value.wallet.cash==7500,'server retry exactly once')
b,p,r,drain=fixture();b.failReadAfterWrite=true;r.submit(p,operation());table.remove(b.spawn,1)()
check(p.attrs.RaceMoneyState=='SAVE_PENDING' and not p.attrs.RaceMoney_total,'unconfirmed money hidden')
b.failReadAfterWrite=false;drain();check(p.attrs.RaceMoneyState=='SAVE_CONFIRMED' and b.value.wallet.cash==7500,'retry confirms without duplicate')
b,p,r,drain=fixture();b.writeFail=true;r.submit(p,operation());drain()
check(b.value.wallet.cash==0 and p.attrs.RaceMoneyState~='SAVE_CONFIRMED','write failure zero success claim')
]]
luau.load(source,{debugName='A4-money-runtime'})()
-- Actual record service + finalized timer path; existing record Canary unchanged.
source=fs.readFile('tests/r8_a3_service_validation.luau')
source=source:gsub("check%(scope=='Track02_V2B_R1_SOLO_1H_0B'", "check(scope==(if name=='KDM_A3_Race_v1' then 'Track02_V2B_R1_SOLO_1H_0B_L2' else 'Track02_V2B_R1_SOLO_1H_0B')")
source=source:gsub('Service%.lap%(p,lap%*20%)','Service.lap(p,lap*20,20)')
source=source:gsub("p.attrs.RaceState='FINISHED';Service.finish%(p%)", "p.attrs.RaceState='FINISHED';Service.finish(p,{totalTime=40,position=1,humanPosition=1,positionFinalized=true})")
source=source:gsub('indexCalls==2','indexCalls==3')
source=source:gsub('value.wallet.cash==123','value.wallet.cash==7623')
source..=[[
check(value.wallet.cash==8623 and value.wallet.lifetimeEarned==8500,'actual service binds economy only to finalized result')
check(p.attrs.RaceMoneyState=='NONE','Studio records collector does not submit a live reward')
]]
luau.load(source,{debugName='A4-money-service'})()
