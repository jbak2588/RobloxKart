-- Pure account transactions. Every callback derives its output from the latest profile.
local Ops={}
function Ops.reduce(S,schema,op)
 local valid=type(op)=='table' and S.integer(op.userId) and op.userId>0 and S.guid(op.id)
  and (op.kind=='BUY_WING' or op.kind=='EQUIP_WING' or op.kind=='GRANT_PASS')
  and op.itemId=='KDM_V2_WING' and (op.kind~='EQUIP_WING' or type(op.equipped)=='boolean')
  and (op.kind~='GRANT_PASS' or S.integer(op.passId) and op.passId>0)
 if not valid then return function() return nil,'INVALID_OPERATION' end end
 local copy=S.freeze(S.clone(op));local signature=S.canonical(copy);local key='economy:'..copy.id
 return function(previous)
  if not previous or not schema.validate(previous,S.userKey(copy.userId)) or previous.deleted then return nil,'READ_ONLY' end
  local receipt=previous.receipts[key]
  if receipt then return if receipt.signature==signature then S.clone(previous) else nil,
   if receipt.signature==signature then 'REPLAY' else 'IDENTITY_MISMATCH' end
  local owned=previous.cosmetics.ownedPartIds[copy.itemId]==true
  if copy.kind~='EQUIP_WING' and owned then return nil,'ALREADY_OWNED' end
  if copy.kind=='EQUIP_WING' and not owned then return nil,'NOT_OWNED' end
  if copy.kind=='BUY_WING' and previous.wallet.cash<3000 then return nil,'INSUFFICIENT_FUNDS' end
  if S.count(previous.receipts)>=schema.maxReceipts then return nil,'RECEIPT_CAPACITY' end
  local p=S.clone(previous)
  if copy.kind~='EQUIP_WING' then
   p.cosmetics.ownedPartIds[copy.itemId]=true
   p.purchaseHistory=p.purchaseHistory or {}
   p.purchaseHistory['wing:'..copy.id]={id=copy.id,itemId=copy.itemId,method=if copy.kind=='BUY_WING' then 'KDM_MONEY' else 'GAME_PASS',passId=copy.passId}
   if copy.kind=='BUY_WING' then p.wallet.cash-=3000 end
  end
  p.cosmetics.equippedPartIdsBySlot.Wing=if copy.kind=='EQUIP_WING' and not copy.equipped then nil else copy.itemId
  if not S.integer(p.wallet.ledgerRevision+1) then return nil,'WALLET_CAPACITY' end
  p.wallet.ledgerRevision+=1
  p.receipts[key]={signature=signature}
  return p,'APPLIED'
 end
end
function Ops.confirm(S,schema,read,op)
 if read.status~='FOUND' or not schema.validate(read.value,S.userKey(op.userId)) or read.value.deleted then return false end
 local r=read.value.receipts['economy:'..op.id]
 return r~=nil and r.signature==S.canonical(op)
end
return table.freeze(Ops)
