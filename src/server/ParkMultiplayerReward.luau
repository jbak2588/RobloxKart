local P=require(game:GetService('ReplicatedStorage').Shared.ParkMultiplayerPolicy)
local Reward={}
function Reward.reduce(S,schema,op)
 if type(op)~='table'or not S.guid(op.id)or not S.integer(op.userId)or op.userId<=0
  or op.valid~=true or op.completedLaps~=3 or op.completedCheckpoints~=18
  or not S.integer(op.slot)or op.slot<0 or op.slot>7
  or not S.integer(op.position)or op.position<1 or op.position>8
  or not S.integer(op.humans)or op.humans<1 or op.humans>8
  or not S.integer(op.humanPosition)or op.humanPosition<1 or op.humanPosition>op.humans or op.humanPosition>op.position
  or not S.integer(op.milliseconds)or op.milliseconds<(P.finishProgress()-P.startProgress(op.slot))/120*1000
  or op.milliseconds>P.Timeout*1000 then return function()return nil,'INVALID_PARK_RACE'end end
 local copy=S.freeze(S.clone(op));local sig=S.transactionCanonical(copy);local key='park-race:'..copy.id
 local amount=P.reward(copy.humans,copy.humanPosition)
 return function(previous)
  if previous and(not schema.validate(previous,S.userKey(copy.userId))or previous.deleted)then return nil,'READ_ONLY'end
  local base=previous or schema.default(copy.userId);local receipt=base.receipts[key]
  if receipt then return if S.signatureMatches(receipt,sig)then S.clone(base)else nil,if S.signatureMatches(receipt,sig)then 'REPLAY'else 'IDENTITY_MISMATCH'end
  local p,why=schema.prepare(base,copy.transaction);if not p then return nil,why end
  if S.count(p.receipts)>=schema.maxReceipts then return nil,'RECEIPT_CAPACITY'end
  local earned=(p.wallet.lifetimeEarned or 0)+amount
  if p.wallet.cash+amount>schema.maxCash or not S.integer(earned)or not S.integer(p.wallet.ledgerRevision+1)then return nil,'WALLET_CAPACITY'end
  p.wallet.cash+=amount;p.wallet.lifetimeEarned=earned;p.wallet.ledgerRevision+=1
  p.receipts[key]={signature=S.sha256(sig)};schema.stamp(p.receipts[key],copy.transaction)
  return p,'PARK_RACE_CREDITED'
 end
end
return Reward
