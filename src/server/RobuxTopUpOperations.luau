-- An atomic credit and permanent purchase marker in the SAME account key.
-- Robux markers deliberately live outside expiring gameplay receipts.
local O={}
function O.identity(S,catalog,receipt)
 if type(receipt)~='table' or not S.integer(receipt.PlayerId) or receipt.PlayerId<=0
  or type(receipt.PurchaseId)~='string' or #receipt.PurchaseId<1 or #receipt.PurchaseId>256
  or receipt.PurchaseId:find('%c') then return nil end
 local entry=catalog.byProductId(receipt.ProductId)
 if not entry then return nil end
 local key=S.sha256(receipt.PurchaseId)
 local signature=S.sha256(S.canonical({userId=receipt.PlayerId,productId=receipt.ProductId,purchaseId=receipt.PurchaseId,amount=entry.Amount}))
 return key,signature,entry.Amount
end
function O.confirm(S,schema,catalog,read,receipt)
 local key,sig=O.identity(S,catalog,receipt)
 return key~=nil and read.status=='FOUND' and schema.validate(read.value,S.userKey(receipt.PlayerId))
  and not read.value.deleted and read.value.robuxTopUps~=nil and read.value.robuxTopUps[key]==sig
end
function O.reduce(S,schema,catalog,receipt)
 local key,sig,amount=O.identity(S,catalog,receipt)
 if not key then return function()return nil,'INVALID_RECEIPT'end end
 local userId=receipt.PlayerId
 return function(previous)
  if previous and (not schema.validate(previous,S.userKey(userId)) or previous.deleted) then return nil,'READ_ONLY' end
  local p=if previous then S.clone(previous) else schema.default(userId)
  local paid=p.robuxTopUps or {}
  if paid[key] then return if paid[key]==sig then p else nil,if paid[key]==sig then 'REPLAY' else 'IDENTITY_MISMATCH' end
  if p.wallet.cash+amount>schema.maxCash or not S.integer(p.wallet.ledgerRevision+1) then return nil,'WALLET_CAPACITY' end
  paid[key]=sig;p.robuxTopUps=paid
  p.wallet.cash+=amount;p.wallet.ledgerRevision+=1
  -- No lifetimeEarned, first-finish, rewards, inventory, selection or record edits.
  if not schema.validate(p,S.userKey(userId)) then return nil,'PROFILE_CAPACITY' end
  return p,'CREDITED'
 end
end
return table.freeze(O)
