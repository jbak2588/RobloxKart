-- Pure, replay-safe mutations of the existing account. Never calls Roblox services.
local Ops={}
function Ops.new(S,schema,C,Economy)
 local api={}
 local function stock(p)
  return p.shopInventory or {counts={},autoRefill=false,revision=0}
 end
 local function signature(op)
  if op.kind=='REFILL' then return S.canonical({kind=op.kind,id=op.id,userId=op.userId,itemId=op.itemId,roundGuid=op.roundGuid})end
  return S.canonical(op)
 end
 function api.key(op)
  return if op.kind=='REFILL' or op.kind=='REFUND_REFILL' or op.kind=='REFUND_UNUSED_REFILL' or op.kind=='FINALIZE_REFILL' then 'shop-refill:'..tostring(op.roundGuid)..':'..tostring(op.itemId)
   elseif op.kind=='BUY_WING' or op.kind=='EQUIP_WING' then 'economy:'..tostring(op.id) else 'shop:'..tostring(op.id)
 end
 function api.confirm(r,op)
  if op.kind=='BUY_WING' or op.kind=='EQUIP_WING' then return Economy.confirm(S,schema,r,op) end
  if r.status~='FOUND' or not schema.validate(r.value,S.userKey(op.userId)) or r.value.deleted then return false end
  local receipt=r.value.receipts[api.key(op)]
  if op.kind=='REFUND_REFILL' or op.kind=='REFUND_UNUSED_REFILL' then return receipt and receipt.refunded==true end
  if op.kind=='FINALIZE_REFILL' then return receipt and receipt.refill and receipt.refill.state=='DELIVERED' and not receipt.refunded end
  local canonical=signature(op)
  return receipt and (receipt.signature==canonical or receipt.signature==S.sha256(canonical)) and not receipt.refunded
 end
 function api.reduce(op)
  local valid=type(op)=='table' and S.integer(op.userId) and op.userId>0 and S.guid(op.id)
  if not valid then return function()return nil,'INVALID_OPERATION'end end
  if op.kind=='BUY_WING' or op.kind=='EQUIP_WING' then return Economy.reduce(S,schema,op) end
  valid=(op.kind=='BUY_ITEM' and C.Prices[op.itemId]~=nil)
   or (op.kind=='SET_AUTO_REFILL' and type(op.enabled)=='boolean')
   or ((op.kind=='REFILL' or op.kind=='REFUND_REFILL' or op.kind=='REFUND_UNUSED_REFILL' or op.kind=='FINALIZE_REFILL') and C.Prices[op.itemId]~=nil and S.guid(op.roundGuid))
  if not valid then return function()return nil,'INVALID_OPERATION'end end
  local copy=S.freeze(S.clone(op));local key=api.key(copy);local canonical=signature(copy);local signed=S.sha256(canonical)
  return function(previous)
   if not previous or not schema.validate(previous,S.userKey(copy.userId)) or previous.deleted then return nil,'READ_ONLY' end
   local receipt=previous.receipts[key]
   if copy.kind~='REFUND_REFILL' and copy.kind~='REFUND_UNUSED_REFILL' and copy.kind~='FINALIZE_REFILL' and receipt then
    if receipt.refunded then return nil,'REFILL_CLOSED' end
    local match = receipt.signature==canonical or receipt.signature==signed
    return if match then S.clone(previous) else nil,
     if match then 'REPLAY' else 'IDENTITY_MISMATCH'
   end
   local old=stock(previous);local amount=old.counts[copy.itemId] or 0
   if copy.kind=='BUY_ITEM' then
    if previous.wallet.cash<C.Prices[copy.itemId] then return nil,'INSUFFICIENT_FUNDS' end
    if amount>=C.MaxStock then return nil,'STOCK_FULL' end
   elseif copy.kind=='REFILL' then
    if not old.autoRefill then return nil,'AUTO_REFILL_OFF' end
    if amount<1 then return nil,'NO_VOUCHER' end
    local used=0
    for _,id in C.Order do if previous.receipts['shop-refill:'..copy.roundGuid..':'..id] then used+=1 end end
    if used>=C.MaxRoundRefills then return nil,'ROUND_REFILL_LIMIT' end
   elseif copy.kind=='REFUND_REFILL' or copy.kind=='REFUND_UNUSED_REFILL' or copy.kind=='FINALIZE_REFILL' then
    if not receipt or not receipt.refill or receipt.refill.roundGuid~=copy.roundGuid or receipt.refill.itemId~=copy.itemId then return nil,'NO_RESERVATION' end
    if receipt.refunded then return S.clone(previous),'REPLAY' end
    if copy.kind=='FINALIZE_REFILL' and receipt.refill.state=='DELIVERED' then return S.clone(previous),'REPLAY' end
    if copy.kind=='REFUND_REFILL' and receipt.refill.state=='DELIVERED' then return nil,'ALREADY_DELIVERED' end
    if copy.kind=='REFUND_UNUSED_REFILL' and receipt.refill.state~='DELIVERED' then return nil,'NOT_FINALIZED' end
   end
   if not receipt and S.count(previous.receipts)>=schema.maxReceipts then return nil,'RECEIPT_CAPACITY' end
   local p=S.clone(previous);p.shopInventory=S.clone(old)
   if copy.kind=='BUY_ITEM' then
    p.wallet.cash-=C.Prices[copy.itemId];p.shopInventory.counts[copy.itemId]=amount+1
   elseif copy.kind=='REFILL' then p.shopInventory.counts[copy.itemId]=amount-1
   elseif copy.kind=='REFUND_REFILL' or copy.kind=='REFUND_UNUSED_REFILL' then
    p.shopInventory.counts[copy.itemId]=amount+1;p.receipts[key].refunded=true
   elseif copy.kind=='FINALIZE_REFILL' then p.receipts[key].refill.state='DELIVERED'
   else p.shopInventory.autoRefill=copy.enabled end
   if not S.integer(p.wallet.ledgerRevision+1) or not S.integer(p.shopInventory.revision+1) then return nil,'WALLET_CAPACITY' end
   p.wallet.ledgerRevision+=1;p.shopInventory.revision+=1
   if copy.kind~='REFUND_REFILL' and copy.kind~='REFUND_UNUSED_REFILL' and copy.kind~='FINALIZE_REFILL' then
    p.receipts[key]={signature=signed}
    if copy.kind=='REFILL' then p.receipts[key].refill={roundGuid=copy.roundGuid,itemId=copy.itemId,state='RESERVED',jobId=copy.jobId or '',reservedAt=copy.reservedAt or 0} end
   end
   if S.pruneAndCompressReceipts then
    S.pruneAndCompressReceipts(p, key, schema.maxReceipts)
   end
   return p,'APPLIED'
  end
 end
 function api.view(p)
  local inv=stock(p);local counts={}
  for _,id in C.Order do counts[id]=inv.counts[id] or 0 end
  return {status='FOUND',cash=p.wallet.cash,wingOwned=p.cosmetics.ownedPartIds[C.WingId]==true,
   wingEquipped=p.cosmetics.equippedPartIdsBySlot.Wing==C.WingId,counts=counts,autoRefill=inv.autoRefill}
 end
 return api
end
return table.freeze(Ops)
