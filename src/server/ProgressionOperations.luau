-- Pure field reducer. Future money/inventory/result operations deliberately have no handler.
local Operations = {}
Operations.FutureContracts = table.freeze({
 CREDIT_FINISH="A4: immutable FINISHED envelope + atomic credit/receipt/day claims",
 GRANT_PART="future: authoritative entitlement and idempotent receipt",
 PURCHASE_COSMETIC="future: versioned server price; debit + grant + receipt atomically",
 EQUIP_COSMETIC="future: owned compatible slot; cosmetic-only",
 PB_IMPROVED="A3: official scoped result, min/max and pending index",
})

function Operations.load(S, schema, read, userId)
 local key = S.userKey(userId)
 if read.key ~= key then return {state="READ_ONLY",reason="WRONG_USER_KEY"} end
 if read.status == "ABSENT" then return {state="NEW",profile=schema.default(userId),saved=false} end
 if read.status ~= "FOUND" then return {state="UNAVAILABLE",saved=false} end
 local valid, reason = schema.validate(read.value,key)
 if not valid then return {state="READ_ONLY",reason=reason,displayKartId="Kart05",saved=false} end
 if read.value.deleted then return {state="DELETED",saved=false} end
 return {state="READY",profile=S.clone(read.value),saved=true}
end

function Operations.selection(S, schema, userId, operation)
 -- Copy/freeze once: caller mutation cannot alter a transaction waiting for commit.
 local ok, signature = pcall(S.canonical,operation)
 if not ok then return function() return nil,"INVALID_OPERATION" end end
 local op = S.freeze(S.clone(operation))
 return function(previous)
  local valid = schema.validate(previous,S.userKey(userId))
  if not valid then return nil,"READ_ONLY" end
  if previous.deleted then return nil,"DELETED" end
  if op.kind ~= "SELECT_KART" then return nil,"FUTURE_OPERATION_DISABLED" end
  if not schema.supportsKart(op.kartId) or not S.integer(op.expectedSelectionRevision)
   or type(op.operationId) ~= "string" or #op.operationId == 0 or #op.operationId > 128 then return nil,"INVALID_OPERATION" end
  local receiptKey = "selection:" .. op.operationId
  local receipt = previous.receipts[receiptKey]
  if receipt then
   if receipt.signature ~= signature then return nil,"IDENTITY_MISMATCH" end
   return S.clone(previous),"REPLAY"
  end
  if previous.selection.revision ~= op.expectedSelectionRevision then return nil,"CONFLICT" end
  if previous.selection.revision >= 9007199254740991 then return nil,"REVISION_CAPACITY" end
  if S.count(previous.receipts) >= schema.maxReceipts then return nil,"RECEIPT_CAPACITY" end
  local nextValue = S.clone(previous)
  nextValue.selection = {kartId=op.kartId,revision=previous.selection.revision+1,lastOpId=op.operationId}
  nextValue.receipts[receiptKey] = {signature=signature}
  if S.pruneAndCompressReceipts then
   S.pruneAndCompressReceipts(nextValue, receiptKey, schema.maxReceipts)
  end
  return nextValue,"APPLIED"
 end
end

function Operations.resolveSelection(S, schema, read, userId, operation)
 local loaded = Operations.load(S,schema,read,userId)
 if loaded.state ~= "READY" then return {state="PENDING",reason=loaded.reason} end
 local receipt = loaded.profile.receipts["selection:" .. operation.operationId]
 if receipt and receipt.signature == S.canonical(operation) then return {state="SAVED",profile=loaded.profile} end
 if receipt then return {state="READ_ONLY",reason="IDENTITY_MISMATCH"} end
 return {state="PENDING",reason="NO_COMMIT_RECEIPT"}
end

return table.freeze(Operations)
