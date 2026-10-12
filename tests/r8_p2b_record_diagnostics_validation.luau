local fs,luau,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/serde')
-- Extend the production runtime outage/ACK/replay fixture, preserving every
-- existing assertion and adding stage evidence/fault isolation checks.
local s=fs.readFile('tests/r8_a3_runtime_validation.luau')
s=s:gsub('indices={}', 'indices={},trace={}')
s=s:gsub('self.writes%+=1;',"self.writes+=1;if self.futureDuringWrite then self.value.schemaVersion=2 end;if self.cancelUpdate then return nil end;")
s=s:gsub('backend.lookups%+=1;return backend',"backend.lookups+=1;if backend.storeFail then error('store unavailable') end;return backend")
s=s:gsub('diagnostic=function%(%) end',[[diagnostic=function(_,event,guid,row)
 if backend.diagnosticThrows then error('diagnostic offline') end
 if row then table.insert(backend.trace,row) end
 end]])
s..=[[
local function findTrace(backend,stage,reason)
 for _,row in backend.trace do if row.stage==stage and (not reason or row.reason==reason) then return row end end
end
b,p,r,drain=fixture();b.readFail=true;r.submit(p,operation());drain()
check(findTrace(b,'READ','READ_UNAVAILABLE')~=nil and findTrace(b,'FINAL','RETRY_EXHAUSTED')~=nil,'read outage and retry exhaustion visible without writing')
b,p,r,drain=fixture();b.noBudget=true;r.submit(p,operation());drain()
check(findTrace(b,'READ','BUDGET_UNAVAILABLE')~=nil and b.writes==0,'budget reason cannot masquerade as absent profile')
b,p,r,drain=fixture();b.storeFail=true;r.submit(p,operation());drain()
check(findTrace(b,'READ','STORE_UNAVAILABLE')~=nil and b.writes==0,'store construction failure categorized')
b,p,r,drain=fixture();b.cancelUpdate=true;r.submit(p,operation());drain()
check(findTrace(b,'UPDATE','UPDATE_CANCELLED')~=nil and p.attrs.RaceRecordSaveState=='SAVE_PENDING','cancelled update does not fabricate receipt')
b,p,r,drain=fixture();b.futureDuringWrite=true;r.submit(p,operation());drain()
check(findTrace(b,'FINAL','FUTURE').status=='SAVE_FAILED' and b.value.schemaVersion==2,'failed update after concurrent future profile change remains protected')
b,p,r,drain=fixture();b.value=nil;r.submit(p,operation());drain()
check(findTrace(b,'FINAL','ABSENT').status=='READ_ONLY' and b.writes==0,'absent fail-closed reason')
b,p,r,drain=fixture();b.value.schemaVersion=2;r.submit(p,operation());drain()
check(findTrace(b,'FINAL','FUTURE')~=nil and b.writes==0,'future schema preserved')
b,p,r,drain=fixture();b.value.selection.kartId='INVALID';local before=S.canonical(b.value);r.submit(p,operation());drain()
check(findTrace(b,'FINAL','CORRUPT_SELECTION')~=nil and S.canonical(b.value)==before,'corrupt reason without reset')
b,p,r,drain=fixture();b.value.deleted=true;r.submit(p,operation());drain()
check(findTrace(b,'FINAL','DELETED')~=nil and b.writes==0,'deleted profile protected')
check(r.read(p).reason=='DELETED','HUB read reason does not accidentally report VALID for a deleted profile')
b,p,r,drain=fixture();b.ackLost=true;r.submit(p,operation());drain()
check(findTrace(b,'UPDATE','UPDATE_OUTCOME_UNKNOWN')~=nil and findTrace(b,'FINAL','RECEIPT_MATCH').receiptConfirmed,'lost ACK distinguished from actual saved receipt')
b,p,r,drain=fixture();b.writeFail=true;r.submit(p,operation());drain()
check(findTrace(b,'UPDATE','UPDATE_OUTCOME_UNKNOWN')~=nil and not findTrace(b,'FINAL','RECEIPT_MATCH'),'write failure never confirmed by diagnostic')
b,p,r,drain=fixture();b.diagnosticThrows=true;r.submit(p,operation());drain()
check(p.attrs.RaceRecordSaveState=='SAVE_CONFIRMED' and b.value.records.scoped[scope].officialBoostLifetime==9,'diagnostic exception cannot alter successfully confirmed save')
b,p,r,drain=fixture()
local mixed=operation()
mixed.round=S.freezeRound({RoundGuid=guid,TrackId='Track01Race',GeometryId='PracticeCircuitV1',RulesetId='KDM_R8A3_RULES_V1',
 diagnostic=false,roster={{IsBot=false,UserId=1},{IsBot=false,UserId=2},{IsBot=true,BotId='rookie'}}})
mixed.race={trackId='Track01Race',geometryId='PracticeCircuitV1',rulesetId='KDM_R8A3_RULES_V1',category=mixed.round.RaceCategory,
 recordScope=mixed.round.recordScope,targetLaps=2,roundGuid=guid,userId=1,totalMilliseconds=95000,laps={45000,50000},
 finishPosition=2,startingHumans=2,startingBots=1,raceBoosts=9,finishedAt=mixed.achievedAt,eligible=true,
 reason='FULL_ROUTE_V1',serverAccepted=true,state='FINISHED',positionFinalized=true}
r.submit(p,mixed);drain()
local mixedScope=S.raceScope(mixed.round.recordScope,2)
check(p.attrs.RaceRecordSaveState=='SAVE_CONFIRMED' and b.value.records.races[mixedScope].lastRace.finishPosition==2,'2H+1Bot personal race receipt and finalized position save normally')
check(b.indexCalls==0 and b.value.selection.kartId=='Kart07','Bot exclusion from human index does not block personal save or kart preservation')
r.submit(p,mixed);drain()
check(b.value.records.scoped[mixed.round.recordScope].officialBoostLifetime==9,'mixed-round duplicate does not double Boosts')
b,p,r,drain=fixture();r.submit(p,operation());p.attrs.OfficialRoundGuid='new-round';drain()
check(p.attrs.RaceRecordSaveState=='SAVE_PENDING' and findTrace(b,'FINAL','RECEIPT_MATCH').round==guid,'late result remains scoped to immutable previous round')
local text=require('@lune/serde').encode('json',b.trace)
check(not text:find('u:1',1,true) and not text:find('signature',1,true) and not text:find('wallet',1,true),'stage diagnostics contain no key, receipt signature or full profile')
print('PASS: '..count..' total production-runtime preservation and P2B diagnostic assertions')
]]
luau.load(s,{debugName='P2B-production-record-runtime'})()
local service=fs.readFile('src/server/RaceRecordService.luau')
assert(service:find("guid==player:GetAttribute('OfficialRoundGuid')",1,true),'old trace cannot overwrite new-round diagnostic attrs')
local policy=fs.readFile('src/server/RaceRecordConfig.luau')
assert(not policy:find('11736539305',1,true),'diagnostic partner is not granted record writes')
print('PASS: P2B record read/write/receipt/failure diagnostics, redaction and fault isolation')
