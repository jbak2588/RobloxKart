-- Field-only min/max reducer. Receipts are retained; capacity exhaustion fails closed.
local Ops={}
function Ops.signature(S,op)
 return if op.economy then S.sha256(S.canonical(op)) else S.canonical(op)
end
function Ops.valid(S,op)
 if type(op)~="table" or op.kind~="OFFICIAL_RECORD" or not S.integer(op.userId) or op.userId==0
  or not S.integer(op.achievedAt) or not S.integer(op.bestRaceBoosts,10000) then return false end
 local r,v=op.round,op.verification
 if type(r)~="table" or not S.guid(r.RoundGuid) or r.diagnostic~=false or type(v)~="table"
  or v.serverAccepted~=true or v.state~="FINISHED" or v.provenance~="FULL_ROUTE_V1"
  or v.boostIdentity~="SERVER_SERIAL_V1" or not S.integer(v.targetLaps,3) or v.targetLaps==0
  or v.completedLaps~=v.targetLaps then return false end
 local ok,frozen=pcall(S.freezeRound,r)
 if not ok or frozen.recordScope~=r.recordScope or frozen.RaceCategory~=r.RaceCategory
  or frozen.botCount~=r.botCount or frozen.humanCount~=r.humanCount then return false end
 local member=false;for _,m in frozen.roster do if not m.IsBot and m.UserId==op.userId then member=true end end
 if op.race~=nil then
  local race=op.race
  if not S.raceSnapshotValid(race) or race.userId~=op.userId or race.roundGuid~=frozen.RoundGuid
   or race.recordScope~=r.recordScope or race.targetLaps~=v.targetLaps or race.raceBoosts~=op.bestRaceBoosts
   or race.finishedAt~=op.achievedAt or race.startingHumans~=frozen.humanCount or race.startingBots~=frozen.botCount then return false end
 end
 if op.economy and (not op.race or op.economy.version~=1 or not S.integer(op.economy.humanPosition,frozen.humanCount)
  or op.economy.humanPosition==0 or op.economy.humanPosition>op.race.finishPosition) then return false end
 return member and ((op.bestLapMilliseconds==nil and v.fullLapValid==false)
  or (S.integer(op.bestLapMilliseconds,86400000) and op.bestLapMilliseconds>0 and v.fullLapValid==true))
end
function Ops.receiptKey(op) return "race-record:"..op.round.RoundGuid end
function Ops.reduce(S,schema,op)
 if not Ops.valid(S,op) then return function() return nil,"INVALID_RECORD" end end
 local copy=S.freeze(S.clone(op));local signature=Ops.signature(S,copy)
 return function(previous)
  if previous==nil then return nil,"PROFILE_ABSENT" end
  if not schema.validate(previous,S.userKey(copy.userId)) then return nil,"READ_ONLY" end
  if previous.deleted then return nil,"DELETED" end
  local key=Ops.receiptKey(copy);local receipt=previous.receipts[key]
  if receipt then
   if receipt.signature~=signature then return nil,"IDENTITY_MISMATCH" end
   return S.clone(previous),"REPLAY"
  end
  if S.count(previous.receipts)>=schema.maxReceipts then return nil,"RECEIPT_CAPACITY" end
  local scope=copy.round.recordScope
  if not previous.records.scoped[scope] and S.count(previous.records.scoped)>=64 then return nil,"RECORD_CAPACITY" end
  if copy.round.botCount==0 and not previous.pendingIndex[scope] and S.count(previous.pendingIndex)>=64 then return nil,"INDEX_CAPACITY" end
  local nextValue=S.clone(previous)
  local record=nextValue.records.scoped[scope] or {};nextValue.records.scoped[scope]=record
  local lapImproved=copy.bestLapMilliseconds~=nil and (not record.bestLapMilliseconds or copy.bestLapMilliseconds<record.bestLapMilliseconds)
  local boostImproved=record.bestRaceBoosts==nil or copy.bestRaceBoosts>record.bestRaceBoosts
  local lifetime=(record.officialBoostLifetime or 0)+copy.bestRaceBoosts
  if not S.integer(lifetime) then return nil,"LIFETIME_CAPACITY" end
  record.officialBoostLifetime=lifetime
  nextValue.records.metadata=nextValue.records.metadata or {}
  local meta=nextValue.records.metadata[scope] or {};nextValue.records.metadata[scope]=meta
  local evidence={achievedAt=copy.achievedAt,roundGuid=copy.round.RoundGuid,trackId=copy.round.TrackId,
   geometryId=copy.round.GeometryId,rulesetId=copy.round.RulesetId,category=copy.round.RaceCategory,
   verification=S.clone(copy.verification)}
  if lapImproved then record.bestLapMilliseconds=copy.bestLapMilliseconds;meta.lap=S.clone(evidence) end
  if boostImproved then record.bestRaceBoosts=copy.bestRaceBoosts;meta.boost=S.clone(evidence) end
  local raceImproved=false
  if copy.race then
   local raceScope=S.raceScope(scope,copy.race.targetLaps)
   nextValue.records.races=nextValue.records.races or {}
   if not nextValue.records.races[raceScope] and S.count(nextValue.records.races)>=64 then return nil,"RACE_CAPACITY" end
   local entry=nextValue.records.races[raceScope] or {};nextValue.records.races[raceScope]=entry
   raceImproved=copy.race.eligible and (not entry.bestRace or copy.race.totalMilliseconds<entry.bestRace.totalMilliseconds)
   if raceImproved then entry.bestRace=S.clone(copy.race) end
   if not entry.lastRace or copy.race.finishedAt>entry.lastRace.finishedAt
    or (copy.race.finishedAt==entry.lastRace.finishedAt and copy.race.roundGuid>entry.lastRace.roundGuid) then
    entry.lastRace=S.clone(copy.race)
   end
   if raceImproved and copy.round.botCount==0 then
    nextValue.pendingRaceIndex=nextValue.pendingRaceIndex or {}
    if not nextValue.pendingRaceIndex[raceScope] and S.count(nextValue.pendingRaceIndex)>=64 then return nil,"RACE_INDEX_CAPACITY" end
    nextValue.pendingRaceIndex[raceScope]={kind="RACE",snapshot=S.clone(entry.bestRace)}
   end
  end
  nextValue.receipts[key]={signature=signature,lapImproved=lapImproved,boostImproved=boostImproved}
  if copy.race then nextValue.receipts[key].raceImproved=raceImproved end
  if copy.economy then
   local money={base=0,bestRace=0,bestLap=0,total=0}
   if copy.race.eligible then
    money.base=if copy.round.humanCount>=2 then ({35,25,20,15})[copy.economy.humanPosition]
     elseif copy.round.botCount>0 then 15 else 10
    money.bestRace=if raceImproved then 10 else 0
    money.bestLap=if lapImproved then 5 else 0
    money.total=math.min(50,money.base+money.bestRace+money.bestLap)
   end
   local earned=(nextValue.wallet.lifetimeEarned or 0)+money.total
   if nextValue.wallet.cash+money.total>schema.maxCash or not S.integer(earned)
    or not S.integer(nextValue.wallet.ledgerRevision+1) then return nil,'WALLET_CAPACITY' end
   nextValue.wallet.cash+=money.total;nextValue.wallet.lifetimeEarned=earned
   nextValue.wallet.ledgerRevision+=1;nextValue.receipts[key].money=money
  end
  if copy.round.botCount==0 then
   nextValue.pendingIndex[scope]={trackId=copy.round.TrackId,geometryId=copy.round.GeometryId,
    rulesetId=copy.round.RulesetId,category=copy.round.RaceCategory,
    lap=record.bestLapMilliseconds,boost=record.bestRaceBoosts}
  end
  return nextValue,"APPLIED"
 end
end
function Ops.confirm(S,schema,read,op)
 if read.status~="FOUND" or not schema.validate(read.value,S.userKey(op.userId)) or read.value.deleted then return nil end
 local receipt=read.value.receipts[Ops.receiptKey(op)]
 return if receipt and receipt.signature==Ops.signature(S,op) then receipt else nil
end
function Ops.clearIndex(S,schema,userId,scope,expected)
 return function(previous)
  if not schema.validate(previous,S.userKey(userId)) or previous.deleted then return nil,"READ_ONLY" end
  local field=if expected.kind=="RACE" then "pendingRaceIndex" else "pendingIndex"
  if not previous[field] or not previous[field][scope] or S.canonical(previous[field][scope])~=S.canonical(expected) then return nil,"INDEX_ADVANCED" end
  local nextValue=S.clone(previous);nextValue[field][scope]=nil;return nextValue,"INDEX_REPAIRED"
 end
end
return table.freeze(Ops)
