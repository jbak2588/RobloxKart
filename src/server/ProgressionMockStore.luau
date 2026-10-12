-- In-memory optimistic store. Construction and all I/O require an explicit test caller.
local MockStore = {}

function MockStore.new(schemaTools, profileSchema, initial, options)
 local S = schemaTools
 options = options or {}
 local data, versions, fault, delayed = S.clone(initial or {}), {}, {}, {}
 local stats = {reads=0,callbacks=0,commits=0,conflicts=0}
 local api = {}
 function api.inject(nextFault) fault = S.clone(nextFault or {}) end
 function api.stats() return S.clone(stats) end
 function api.snapshot() return S.clone(data) end
 local function readNow(key)
  if data[key] == nil then return {status="ABSENT",key=key,version=versions[key] or 0} end
  return {status="FOUND",key=key,value=S.clone(data[key]),version=versions[key] or 0}
 end
 function api.read(key)
  stats.reads += 1
  if fault.readFail then return {status="ERROR",reason="READ_UNAVAILABLE",key=key} end
  local result = readNow(key)
  if fault.delayRead then
   local ticket = {}; delayed[ticket] = result
   return {status="PENDING",ticket=ticket,key=key}
  end
  return result
 end
 function api.finishRead(ticket)
  local result = delayed[ticket]
  if not result then return {status="ERROR",reason="UNKNOWN_TICKET"} end
  delayed[ticket] = nil
  return S.clone(result)
 end
 local function run(callback, old)
  -- A yielded callback cannot be committed; mutation of input is rejected by freeze.
  stats.callbacks += 1
  local thread = coroutine.create(callback)
  local ok, nextValue, outcome = coroutine.resume(thread, S.freeze(S.clone(old)))
  if not ok then return nil, "CALLBACK_ERROR", nextValue end
  if coroutine.status(thread) ~= "dead" then coroutine.close(thread); return nil, "CALLBACK_YIELDED" end
  return nextValue, outcome
 end
 function api.beginUpdate(key, callback)
  assert(type(key) == "string" and type(callback) == "function", "invalid_update")
  local transaction = {key=key,callback=callback,version=versions[key] or 0,consumed=false}
  transaction.value, transaction.outcome, transaction.error = run(callback,data[key])
  if fault.callbackReplay then
   local replay, outcome = run(callback,data[key])
   if S.canonical(replay) ~= S.canonical(transaction.value) or outcome ~= transaction.outcome then
    transaction.value, transaction.outcome = nil, "NONDETERMINISTIC_CALLBACK"
   end
  end
  return transaction
 end
 function api.commit(transaction)
  assert(not transaction.consumed, "transaction_already_consumed")
  transaction.consumed = true
  if fault.writeFail then return {status="PENDING",reason="WRITE_FAILED_BEFORE_COMMIT"} end
  if fault.noResponse then return {status="PENDING",reason="NO_RESPONSE_BEFORE_COMMIT"} end
  if fault.capacityFull then return {status="READ_ONLY",reason="CAPACITY_FULL"} end
  if transaction.version ~= (versions[transaction.key] or 0) then
   stats.conflicts += 1
   transaction.value, transaction.outcome, transaction.error = run(transaction.callback,data[transaction.key])
  end
  if transaction.value == nil then return {status=transaction.outcome or "REJECTED",reason=transaction.error} end
  local valid, reason = profileSchema.validate(transaction.value, transaction.key)
  if not valid then return {status="READ_ONLY",reason=reason} end
  local encoded = S.canonical(transaction.value)
  if S.jsonByteBound(transaction.value) > (options.maxBytes or profileSchema.maxBytes) then return {status="READ_ONLY",reason="CAPACITY_FULL"} end
  -- NOOP after receipt replay does not create another version/side effect.
  if data[transaction.key] == nil or S.canonical(data[transaction.key]) ~= encoded then
   data[transaction.key] = S.clone(transaction.value)
   versions[transaction.key] = (versions[transaction.key] or 0)+1
   stats.commits += 1
  end
  if fault.ackLoss then return {status="PENDING",reason="COMMIT_ACK_LOST"} end
  if fault.delayAck then
   local ticket = {}; delayed[ticket] = {status="SAVED",value=S.clone(data[transaction.key]),outcome=transaction.outcome}
   return {status="PENDING",ticket=ticket,reason="ACK_DELAYED"}
  end
  return {status="SAVED",value=S.clone(data[transaction.key]),outcome=transaction.outcome}
 end
 function api.update(key, callback) return api.commit(api.beginUpdate(key,callback)) end
 return api
end

return table.freeze(MockStore)
