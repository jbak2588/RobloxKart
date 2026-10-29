-- Dedicated immutable receipt; challenge finishes never enter Solo time indexes.
local P=require(game:GetService('ReplicatedStorage').Shared.ParkOvertakePolicy)
local Reward={}
function Reward.reduce(S,schema,op)
 if type(op)~='table'or not S.guid(op.id)or not S.integer(op.userId)or op.userId<=0
  or op.valid~=true or op.completedLaps~=3 or op.completedCheckpoints~=18
  or not S.integer(op.slot)or op.slot<0 or op.slot>7
  or not S.integer(op.milliseconds)or op.milliseconds<30000 or op.milliseconds>86400000 then
  return function()return nil,'INVALID_OVERTAKE'end
 end
 local distance=P.finishDistance(op.slot)
 -- Shared progress already enforces continuity/gates; also reject impossible total pace.
 if op.milliseconds/1000<distance/120 then return function()return nil,'INVALID_OVERTAKE'end end
 local seconds=op.milliseconds/1000
 if op.botDistances~=nil then
  if type(op.botDistances)~='table'or #op.botDistances~=7 then return function()return nil,'INVALID_OVERTAKE'end end
  for i,d in op.botDistances do
   if not S.integer(i)or i<1 or i>7 or type(d)~='number'or d~=d
    or d<P.botDistance(i,0)or d>P.botDistance(i,seconds)+.01 then return function()return nil,'INVALID_OVERTAKE'end end
  end
 end
 local count=P.countAhead(distance,seconds,op.botDistances)
 if op.ahead~=count then return function()return nil,'INVALID_OVERTAKE'end end
 local amount=P.reward(count)
 local copy=S.freeze(S.clone(op));local sig=S.transactionCanonical(copy);local key='park-overtake:'..copy.id
 return function(previous)
  if previous and (not schema.validate(previous,S.userKey(copy.userId))or previous.deleted)then return nil,'READ_ONLY'end
  local base=previous or schema.default(copy.userId)
  local receipt=base.receipts[key]
  if receipt then return if S.signatureMatches(receipt,sig)then S.clone(base)else nil,if S.signatureMatches(receipt,sig)then 'REPLAY'else 'IDENTITY_MISMATCH'end
  local p,why=schema.prepare(base,copy.transaction);if not p then return nil,why end
  if S.count(p.receipts)>=schema.maxReceipts then return nil,'RECEIPT_CAPACITY'end
  local earned=(p.wallet.lifetimeEarned or 0)+amount
  if p.wallet.cash+amount>schema.maxCash or not S.integer(earned)or not S.integer(p.wallet.ledgerRevision+1)then return nil,'WALLET_CAPACITY'end
  p.wallet.cash+=amount;p.wallet.lifetimeEarned=earned;p.wallet.ledgerRevision+=1
  p.receipts[key]={signature=S.sha256(sig)};schema.stamp(p.receipts[key],copy.transaction)
  return p,'PARK_OVERTAKE_CREDITED'
 end
end
return Reward
