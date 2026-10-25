-- Actual session continuation and atomic official reward reducer, no live DataStore.
local fs,luau,rb,serde=require('@lune/fs'),require('@lune/luau'),require('@lune/roblox'),require('@lune/serde')
local function load(p,e)return luau.load(fs.readFile(p),{environment=e or {},debugName=p})()end
local S=load('src/shared/KDMProgressionSchema.luau')
local catalog=load('src/shared/KartCatalog.luau',{Color3=rb.Color3,Enum=rb.Enum})
local schema=S.new(catalog,{jsonEncode=function(v)return serde.encode('json',v)end})
local Ops=load('src/server/RaceRecordOperations.luau')
local n=0;local function check(ok,message)n+=1;assert(ok,message)end
local function guid(i)return string.format('12345678-1234-1234-1234-%012d',i)end
local function operation(i,rank,m,humans,bots)
 humans=humans or 4
 local roster={};for j=1,humans do table.insert(roster,{IsBot=false,UserId=j})end
 for j=1,(bots or 0)do table.insert(roster,{IsBot=true,BotId='Bot'..j})end
 local round=S.freezeRound({RoundGuid=guid(i),TrackId='Track01Race',GeometryId='PracticeCircuitV1',RulesetId='KDM_R8A3_RULES_V1',diagnostic=false,roster=roster})
 local at=1791650000000+i
 return {kind='OFFICIAL_RECORD',round=round,userId=1,bestLapMilliseconds=60000,bestRaceBoosts=2,achievedAt=at,
 verification={serverAccepted=true,state='FINISHED',targetLaps=2,completedLaps=2,fullLapValid=true,provenance='FULL_ROUTE_V1',boostIdentity='SERVER_SERIAL_V1'},
 economy={version=1,humanPosition=rank,rematchMultiplier=m},race={trackId=round.TrackId,geometryId=round.GeometryId,rulesetId=round.RulesetId,category=round.RaceCategory,
 recordScope=round.recordScope,targetLaps=2,roundGuid=round.RoundGuid,userId=1,totalMilliseconds=120000,laps={60000,60000},finishPosition=rank,
 startingHumans=humans,startingBots=bots or 0,raceBoosts=2,finishedAt=at,eligible=true,reason='FULL_ROUTE_V1',serverAccepted=true,state='FINISHED',positionFinalized=true}}
end
local original=schema.default(1);original.onboarding.finishEvent.claimed=true
local id=1000
for rank,base in {3500,2500,2000,1500}do for m=1,4 do
 id+=1;local op=operation(id,rank,m)
 local profile,status=Ops.reduce(S,schema,op)(original)
 check(status=='APPLIED','rank/multiplier transaction accepted')
 local receipt=Ops.confirm(S,schema,{status='FOUND',value=profile},op)
 check(receipt.money.base==base and receipt.money.rematchBonus==base*(m-1),'only rank base multiplied')
 check(receipt.money.total==base*m+1500,'PB rewards stay unmultiplied')
 check(profile.wallet.cash-original.wallet.cash==base*m+1500 and schema.validate(profile,S.userKey(1)),'wallet and new receipt validate atomically')
 local duplicate,again=Ops.reduce(S,schema,op)(profile)
 check(again=='REPLAY' and S.canonical(duplicate)==S.canonical(profile),'same receipt retry never double pays')
 local altered=S.clone(op);altered.economy.rematchMultiplier=m+1
 local rejected,why=Ops.reduce(S,schema,altered)(profile)
 check(not rejected and why=='IDENTITY_MISMATCH','retry cannot change frozen multiplier')
 local corrupt=S.clone(profile);corrupt.receipts[Ops.receiptKey(op)].money.rematchBonus+=1
 check(not schema.validate(corrupt,S.userKey(1)),'tampered bonus receipt rejected')
end end
local legacy=operation(2000,1,nil);local old=Ops.reduce(S,schema,legacy)(original)
check(schema.validate(old,S.userKey(1)) and old.receipts[Ops.receiptKey(legacy)].money.rematchMultiplier==nil,'legacy receipt schema stays valid')
local initial=schema.default(1);local campaign=operation(2001,1,3)
local paid=Ops.reduce(S,schema,campaign)(initial)
check(paid.receipts[Ops.receiptKey(campaign)].money.total==3500*3+1500+5000,'one-time event bonus never multiplied')
for _,m in {0,-1,1.5,0/0,math.huge}do check(not Ops.valid(S,operation(3000,1,m)),'bad multiplier rejected')end
check(not Ops.valid(S,operation(3001,1,2,1)),'solo cannot submit multiplier')
local invalid=operation(3002,1,2);invalid.race.eligible=false;invalid.race.reason='INVALID_ROUTE_OR_TIMER_RESET'
check(not Ops.valid(S,invalid),'invalid route cannot submit multiplied reward')
local full=S.clone(original);full.wallet.cash=schema.maxCash-1
local denied,why=Ops.reduce(S,schema,operation(3003,1,4))(full)
check(not denied and why=='WALLET_CAPACITY' and full.wallet.cash==schema.maxCash-1,'capacity failure has no partial wallet write')
local fresh=Ops.reduce(S,schema,operation(3004,1,1))(original)
local nextOp=operation(3005,2,2);nextOp.bestLapMilliseconds=65000;nextOp.race.laps={65000,65000};nextOp.race.totalMilliseconds=130000
local nextProfile=Ops.reduce(S,schema,nextOp)(fresh)
check(nextProfile.receipts[Ops.receiptKey(nextOp)].money.total==2500*2,'changed finish rank uses its own base, not previous winner prize')

local node;node={WaitForChild=function(_,key)return if key=='Shared' then node else key end}
local Session=load('src/server/RaceSession.luau',{game={GetService=function()return node end},require=function(key)
 return if key=='TrackCatalog' then {Entries={Track01Race={MaxPlayers=4}}}else {PUBLIC_RACE_MAX_PLAYERS=4}end})
local function player(id)
 local attrs={};return {UserId=id,GetAttribute=function(_,key)return attrs[key]end,SetAttribute=function(_,key,value)attrs[key]=value end}
end
local p,q,r=player(1),player(2),player(3)
local s=Session.new('Track01Race','RACE',2);s:add(p,{});s:add(q,{})
local function begin()s.roundId+=1;s:beginRewardRound()end
begin();check(s:rewardMultiplier(p)==1 and s:rewardMultiplier(q)==1,'first multiplayer start is X1')
s:completeRewardRound(p,true,1);s:completeRewardRound(q,true,2)
check(p:GetAttribute('RaceNextRematchMultiplier')==2 and q:GetAttribute('RaceNextRematchMultiplier')==2,'qualified route advertises next multiplier only')
for _=1,10 do s:requestRewardRematch(p)end;s:requestRewardRematch(q);begin()
check(s:rewardMultiplier(p)==2 and s:rewardMultiplier(q)==2,'duplicate votes cannot skip X2')
s:completeRewardRound(p,true,2);s:completeRewardRound(q,false,1)
s:requestRewardRematch(p);s:requestRewardRematch(q);begin()
check(s:rewardMultiplier(p)==3 and s:rewardMultiplier(q)==1,'DNF/invalid entrant resets independently')
s:completeRewardRound(p,true,1);s:requestRewardRematch(p);s:add(r,{});begin()
check(s:rewardMultiplier(p)==4 and s:rewardMultiplier(r)==1,'new arrival starts X1 while continuing finisher gets X4')
s:remove(p);s:add(p,{});begin();check(s:rewardMultiplier(p)==1,'departure/rejoin resets streak')
s:completeRewardRound(p,true,1);s:requestRewardRematch(p);s.trackId='Track03';begin()
check(s:rewardMultiplier(p)==1,'different track resets streak')
s:remove(q);s:remove(r);s:completeRewardRound(p,true,1);s:requestRewardRematch(p);begin()
check(s:rewardMultiplier(p)==1,'single remaining human does not advance multiplayer streak')
s:completeRewardRound(p,true,1);check(p:GetAttribute('RaceNextRematchMultiplier')==nil,'solo gets no multiplayer promise')
local bot=player(99);bot:SetAttribute('IsBot',true)
s:addBot(bot,{});begin()
s:completeRewardRound(p,true);s:requestRewardRematch(p);begin()
check(s:rewardMultiplier(p)==2,'one human plus bot advances X2')
s:completeRewardRound(p,true);s:requestRewardRematch(p);begin()
check(s:rewardMultiplier(p)==3,'one human plus bot advances X3')
s:completeRewardRound(p,true);s:requestRewardRematch(p);begin()
check(s:rewardMultiplier(p)==4,'one human plus bot advances X4')
for _,m in {2,3,4}do
 local op=operation(3500+m,1,m,1,1)
 check(Ops.valid(S,op),'one human plus bot multiplier is valid')
 local profile,status=Ops.reduce(S,schema,op)(original)
 check(status=='APPLIED' and profile.receipts[Ops.receiptKey(op)].money.rematchBonus==1500*(m-1),'bot race retains1500 base and multiplies only that base')
 local _,duplicate=Ops.reduce(S,schema,op)(profile)
 check(duplicate=='REPLAY','bot rematch receipt idempotent')
end
-- Deferred old-round saves retain their frozen multiplier; current HUD is guarded.
local Runtime=load('src/server/RaceRecordRuntime.luau')
local profile=S.clone(original);local queued={};local writes=0
local adapter={read=function()return {status='FOUND',value=S.clone(profile)}end,
 beginUpdate=function(_,reducer)return reducer end,commit=function(reducer)
  local value,status=reducer(profile);if value then profile=value;writes+=1 end
  return {status=if value then 'PENDING' else 'FAILED',reason=status} -- lost response ACK
 end}
local runtime=Runtime.new(S,schema,Ops,{allowed=function(_,kind)return kind~='repair'end,retryAttempts=1,
 spawn=function(fn)table.insert(queued,fn)end,delay=function()error('unexpected retry after readback')end,
 adapter=function()return adapter end,index=function()return true end})
local viewer=player(1);local oldOp=operation(4000,1,2);local newOp=operation(4001,2,3)
viewer:SetAttribute('OfficialRoundGuid',oldOp.round.RoundGuid)
check(runtime.submit(viewer,oldOp),'old round enqueued')
oldOp.economy.rematchMultiplier=99
viewer:SetAttribute('OfficialRoundGuid',newOp.round.RoundGuid)
check(runtime.submit(viewer,newOp),'new round enqueued independently')
queued[1]()
check(viewer:GetAttribute('RaceMoneyState')=='SAVE_PENDING' and viewer:GetAttribute('RaceMoney_total')==nil,'stale confirmation cannot overwrite current result')
check(profile.receipts['race-record:'..guid(4000)].money.rematchMultiplier==2,'old operation multiplier was frozen before caller mutation')
queued[2]()
check(viewer:GetAttribute('RaceMoneyState')=='SAVE_CONFIRMED' and viewer:GetAttribute('RaceMoney_rematchMultiplier')==3,'current multiplied reward requires receipt readback')
check(viewer:GetAttribute('RaceMoney_total')==2500*3 and writes==2,'next finish rank and multiplier persist once despite lost ACK')
print('PASS: '..n..' actual session and atomic rank/Rematch reward checks')
