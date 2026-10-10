-- Field-only min/max reducer. Receipts are retained; capacity exhaustion fails closed.
local Ops={}
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
 return member and ((op.bestLapMilliseconds==nil and v.fullLapValid==false)
  or (S.integer(op.bestLapMilliseconds,86400000) and op.bestLapMilliseconds>0 and v.fullLapValid==true))
end
function Ops.receiptKey(op) return "race-record:"..op.round.RoundGuid end
function Ops.reduce(S,schema,op)
 if not Ops.valid(S,op) then return function() return nil,"INVALID_RECORD" end end
 local copy=S.freeze(S.clone(op));local signature=S.canonical(copy)
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
  nextValue.receipts[key]={signature=signature,lapImproved=lapImproved,boostImproved=boostImproved}
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
 return if receipt and receipt.signature==S.canonical(op) then receipt else nil
end
function Ops.clearIndex(S,schema,userId,scope,expected)
 return function(previous)
  if not schema.validate(previous,S.userKey(userId)) or previous.deleted then return nil,"READ_ONLY" end
  if not previous.pendingIndex[scope] or S.canonical(previous.pendingIndex[scope])~=S.canonical(expected) then return nil,"INDEX_ADVANCED" end
  local nextValue=S.clone(previous);nextValue.pendingIndex[scope]=nil;return nextValue,"INDEX_REPAIRED"
 end
end
return table.freeze(Ops)
