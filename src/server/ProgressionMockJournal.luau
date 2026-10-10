-- Memory-only crash/replay model. Exported image simulates a durable append in tests,
-- never disk/cloud durability. No economy reducer or Rival/pair transaction exists here.
local Journal = {}

function Journal.new(S, image, options)
 options = options or {}
 local recoveryBlocked = options.recovery == true and image == nil
 local state = S.clone(image or {events={},tombstones={}})
 local fault = {}
 local api = {}
 function api.inject(nextFault) fault = S.clone(nextFault or {}) end
 function api.snapshot() return S.clone(state) end
 function api.append(event)
  if recoveryBlocked then return {status="BLOCKED",reason="CANONICAL_HISTORY_UNAVAILABLE"} end
  if fault.beforeAppend then return {status="UNGUARANTEED",reason="PROCESS_LOST_BEFORE_APPEND"} end
  if type(event) ~= "table" then return {status="REJECTED"} end
  local ok, id = pcall(S.eventId,event.RoundGuid,event.UserId,event.rewardKind)
  if not ok or not S.integer(event.confirmedAtUtcMs) then return {status="REJECTED"} end
  if state.tombstones[tostring(event.UserId)] then return {status="DELETED"} end
  local signature = S.canonical(event)
  local existing = state.events[id]
  if existing then
   return {status=if existing.signature == signature then "REPLAY" else "IDENTITY_MISMATCH",id=id}
  end
  if S.count(state.events) >= (options.maxEvents or 4096) then return {status="BLOCKED",reason="JOURNAL_CAPACITY"} end
  state.events[id] = {event=S.clone(event),signature=signature,phase="PENDING",attempts=0}
  if fault.afterAppend then return {status="PENDING",reason="PROCESS_LOST_AFTER_APPEND",id=id} end
  return {status="APPENDED",id=id}
 end
 function api.deliver(id, nowUtcMs, consumer)
  if recoveryBlocked then return {status="BLOCKED",reason="CANONICAL_HISTORY_UNAVAILABLE"} end
  local entry = state.events[id]
  if not entry then return {status="BLOCKED",reason="MISSING_CANONICAL_EVENT"} end
  if state.tombstones[tostring(entry.event.UserId)] then return {status="DELETED"} end
  if entry.phase == "DELIVERED" then return {status="DELIVERED",replay=true} end
  if not S.integer(nowUtcMs) or nowUtcMs < entry.event.confirmedAtUtcMs
   or nowUtcMs-entry.event.confirmedAtUtcMs > (options.replayWindowMs or 7*86400000) then
   return {status="BLOCKED",reason="EXPIRED_OR_CLOCK_INVALID"}
  end
  entry.attempts += 1
  local ok, result = pcall(consumer,S.freeze(S.clone(entry.event)),id,entry.signature)
  if not ok or type(result) ~= "table" then return {status="PENDING",reason="CONSUMER_FAILED"} end
  if result.status == "SAVED" then
   if fault.deliveryAckLoss then return {status="PENDING",reason="DELIVERY_ACK_LOST"} end
   entry.phase = "DELIVERED"
   return {status="DELIVERED"}
  end
  return result
 end
 function api.deleteUser(userId)
  S.userKey(userId)
  state.tombstones[tostring(userId)] = true
  for _, entry in state.events do
   if entry.event.UserId == userId then entry.phase = "SUPPRESSED" end
  end
 end
 -- No eviction API: forgetting delivered IDs or tombstones is a live-design blocker.
 return api
end

return table.freeze(Journal)
