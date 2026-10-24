-- Pure account transactions. Every callback derives its output from the latest profile.
local Ops={}
function Ops.reduce(S,schema,op)
 local valid=type(op)=='table' and S.integer(op.userId) and op.userId>0 and S.guid(op.id)
  and (op.kind=='BUY_WING' or op.kind=='EQUIP_WING' or op.kind=='GRANT_PASS')
  and op.itemId=='KDM_V2_WING' and (op.kind~='EQUIP_WING' or type(op.equipped)=='boolean')
  and (op.kind~='GRANT_PASS' or S.integer(op.passId) and op.passId>0)
 if not valid then return function() return nil,'INVALID_OPERATION' end end
 local copy=S.freeze(S.clone(op));local canonical=S.transactionCanonical(copy);local hash=S.sha256(canonical);local key='economy:'..copy.id
 return function(previous)
  if not previous or not schema.validate(previous,S.userKey(copy.userId)) or previous.deleted then return nil,'READ_ONLY' end
  local receipt=previous.receipts[key]
  if receipt then
   local match = receipt.signature==canonical or receipt.signature==hash
   return if match then S.clone(previous) else nil,
    if match then 'REPLAY' else 'IDENTITY_MISMATCH'
  end
  local prepared,reason=schema.prepare(previous,copy.transaction)
  if not prepared then return nil,reason end
  previous=prepared
  local owned=previous.cosmetics.ownedPartIds[copy.itemId]==true
  if copy.kind~='EQUIP_WING' and owned then return nil,'ALREADY_OWNED' end
  if copy.kind=='EQUIP_WING' and not owned then return nil,'NOT_OWNED' end
  if copy.kind=='BUY_WING' and previous.wallet.cash<25000 then return nil,'INSUFFICIENT_FUNDS' end
  if S.count(previous.receipts)>=schema.maxReceipts then return nil,'RECEIPT_CAPACITY' end
  local p=S.clone(previous)
  if copy.kind~='EQUIP_WING' then
   p.cosmetics.ownedPartIds[copy.itemId]=true
   p.purchaseHistory=p.purchaseHistory or {}
   p.purchaseHistory['wing:'..copy.id]={id=copy.id,itemId=copy.itemId,method=if copy.kind=='BUY_WING' then 'KDM_MONEY' else 'GAME_PASS',passId=copy.passId}
   if copy.kind=='BUY_WING' then p.wallet.cash-=25000 end
  end
  p.cosmetics.equippedPartIdsBySlot.Wing=if copy.kind=='EQUIP_WING' and not copy.equipped then nil else copy.itemId
  if not S.integer(p.wallet.ledgerRevision+1) then return nil,'WALLET_CAPACITY' end
  p.wallet.ledgerRevision+=1
  p.receipts[key]={signature=hash}
  schema.stamp(p.receipts[key],copy.transaction)
  if S.pruneAndCompressReceipts then
   S.pruneAndCompressReceipts(p, key, schema.maxReceipts)
  end
  return p,'APPLIED'
 end
end
function Ops.confirm(S,schema,read,op)
 if read.status~='FOUND' or not schema.validate(read.value,S.userKey(op.userId)) or read.value.deleted then return false end
 local r=read.value.receipts['economy:'..op.id]
 if not r then return false end
 local sig=S.transactionCanonical(op)
 return r.signature==sig or r.signature==S.sha256(sig)
end
-- Existing active-DNF completion amount; adds identity, not a new reward.
function Ops.dnf(S,schema,op)
 if not S.guid(op.roundGuid) or op.amount~=1500 or op.reason~='ACTIVE_DNF_COMPLETION' then return function()return nil,'INVALID_OPERATION'end end
 local copy=S.freeze(S.clone(op));local sig=S.transactionCanonical(copy);local key='dnf:'..copy.roundGuid
 return function(previous)
  if not previous or not schema.validate(previous,S.userKey(copy.userId)) or previous.deleted then return nil,'READ_ONLY' end
  local r=previous.receipts[key]
  if r then return if S.signatureMatches(r,sig) then S.clone(previous) else nil,if S.signatureMatches(r,sig) then 'REPLAY' else 'IDENTITY_MISMATCH' end
  local p,reason=schema.prepare(previous,copy.transaction);if not p then return nil,reason end
  if S.count(p.receipts)>=schema.maxReceipts then return nil,'RECEIPT_CAPACITY' end
  local earned=(p.wallet.lifetimeEarned or 0)+copy.amount
  if p.wallet.cash+copy.amount>schema.maxCash or not S.integer(earned) or not S.integer(p.wallet.ledgerRevision+1) then return nil,'WALLET_CAPACITY' end
  p.wallet.cash+=copy.amount;p.wallet.lifetimeEarned=earned;p.wallet.ledgerRevision+=1
  p.receipts[key]={signature=S.sha256(sig)};schema.stamp(p.receipts[key],copy.transaction)
  return p,'REWARD_CREDITED'
 end
end

-- Separate HUB-only lap receipts; never an official RACE or leaderboard result.
function Ops.parkLap(S,schema,op)
 local laps=if type(op)=='table'and op.proofVersion==2 then 2 else 1
 local multiplier=if type(op)=='table'then op.rewardMultiplier or 1 else 1
 local bestLap=if type(op)=='table'then op.bestLapMilliseconds or op.milliseconds else nil
 if type(op)~='table' or not S.guid(op.id)or not S.integer(op.userId)or op.userId<=0
  or not S.integer(op.milliseconds)or op.milliseconds<10000 or op.milliseconds>86400000
  or op.completedCheckpoints~=6*laps or op.valid~=true
  or (laps==2 and op.completedLaps~=2)or not S.integer(multiplier)or multiplier<1 or multiplier>math.floor(schema.maxCash/5000)
  or (laps==1 and multiplier~=1)or not S.integer(bestLap)or bestLap<10000 or bestLap>op.milliseconds
  or (op.proofVersion~=nil and op.proofVersion~=2)or (laps==2 and (op.milliseconds<20000 or bestLap*2>op.milliseconds)) then return function()return nil,'INVALID_LAP'end end
 local copy=S.freeze(S.clone(op));local sig=S.transactionCanonical(copy);local key='park-lap:'..copy.id
 return function(previous)
  if previous and (not schema.validate(previous,S.userKey(copy.userId))or previous.deleted)then return nil,'READ_ONLY'end
  local base=previous or schema.default(copy.userId)
  local receipt=base.receipts[key]
  if receipt then return if S.signatureMatches(receipt,sig)then S.clone(base)else nil,if S.signatureMatches(receipt,sig)then 'REPLAY'else 'IDENTITY_MISMATCH'end
  local p,why=schema.prepare(base,copy.transaction);if not p then return nil,why end
  if S.count(p.receipts)>=schema.maxReceipts then return nil,'RECEIPT_CAPACITY'end
  local amount=5000*multiplier
  local earned=(p.wallet.lifetimeEarned or 0)+amount
  if p.wallet.cash+amount>schema.maxCash or not S.integer(earned)or not S.integer(p.wallet.ledgerRevision+1)then return nil,'WALLET_CAPACITY'end
  local old=p.parkTimeTrial
  if old and not S.integer(old.completedLaps+laps)then return nil,'RECORD_CAPACITY'end
  p.parkTimeTrial={version=1,bestMilliseconds=math.min(bestLap,if old then old.bestMilliseconds else math.huge),
   lastMilliseconds=bestLap,completedLaps=(if old then old.completedLaps else 0)+laps}
  if laps==2 then
   local previousRun=p.parkTwoLapTrial
   if previousRun and not S.integer(previousRun.completedRuns+1)then return nil,'RECORD_CAPACITY'end
   p.parkTwoLapTrial={version=1,bestMilliseconds=math.min(copy.milliseconds,if previousRun then previousRun.bestMilliseconds else math.huge),
    lastMilliseconds=copy.milliseconds,completedRuns=(if previousRun then previousRun.completedRuns else 0)+1}
  end
  p.wallet.cash+=amount;p.wallet.lifetimeEarned=earned;p.wallet.ledgerRevision+=1
  p.receipts[key]={signature=S.sha256(sig)};schema.stamp(p.receipts[key],copy.transaction)
  return p,'PARK_LAP_CREDITED'
 end
end

return table.freeze(Ops)
