-- Injected I/O: official Profile is authoritative; index writes are eventual repair.
local Runtime={}
function Runtime.new(S,schema,Ops,deps)
 local jobs,closing={},false
 local api={}
 local function trace(job,stage,status,reason,extra)
  if not deps.diagnostic then return end
  local row={stage=stage,status=status,reason=reason or 'NONE',attempt=job.attempts+1,
   round=job.op.round.RoundGuid,receiptConfirmed=false}
  if extra then for k,v in extra do row[k]=v end end
  -- Diagnostic failures must never affect persistence or authority.
  pcall(deps.diagnostic,job.player,'SAVE_TRACE',job.op.round.RoundGuid,row)
 end
 local function publish(player,op,status,receipt)
  if player:GetAttribute("OfficialRoundGuid")~=op.round.RoundGuid then return end
  player:SetAttribute("RaceRecordNewPB",receipt~=nil and (receipt.lapImproved or receipt.boostImproved) or false)
  player:SetAttribute("RaceRecordNewBestRace",receipt~=nil and receipt.raceImproved==true)
  player:SetAttribute("RaceRecordSaveState",status)
 end
 local function repair(player,adapter,profile)
  if not deps.allowed(player,"repair") then return end
  for scope,entry in profile.pendingIndex do
   local ok=deps.index(player,entry)
   if ok then adapter.commit(adapter.beginUpdate(S.userKey(player.UserId),Ops.clearIndex(S,schema,player.UserId,scope,entry))) end
  end
  for scope,entry in profile.pendingRaceIndex or {} do
   local ok=deps.index(player,entry)
   if ok then adapter.commit(adapter.beginUpdate(S.userKey(player.UserId),Ops.clearIndex(S,schema,player.UserId,scope,entry))) end
  end
 end
 function api.read(player)
  if not deps.allowed(player,"read") then return {status="ACCESS_BLOCKED"} end
  local adapter=deps.adapter(player);local read=adapter.read(S.userKey(player.UserId))
  if read.status~="FOUND" or not schema.validate(read.value,S.userKey(player.UserId)) or read.value.deleted then
   local reason=read.reason
   if read.status=='FOUND' then local _,validationReason=schema.validate(read.value,S.userKey(player.UserId));reason=validationReason end
   return {status=if read.status=="FOUND" then "READ_ONLY" else read.status,
    reason=if read.status=='FOUND' and read.value.deleted then 'DELETED' else reason}
  end
  repair(player,adapter,read.value)
  return {status="FOUND",records=S.clone(read.value.records)}
 end
 local function attempt(job)
  local player,op=job.player,job.op
  if not deps.allowed(player,"write") then trace(job,'POLICY','ACCESS_BLOCKED');publish(player,op,"ACCESS_BLOCKED");job.done=true;return end
  local adapter=deps.adapter(player);local key=S.userKey(player.UserId)
  -- A failed read must never be interpreted as an absent profile.
  local read=adapter.read(key)
  local valid,validationReason=false,nil
  if read.status=='FOUND' then valid,validationReason=schema.validate(read.value,key) end
  trace(job,'READ',read.status,read.reason or validationReason,{deleted=read.status=='FOUND' and read.value.deleted==true,
   schemaValid=valid})
  local receipt=Ops.confirm(S,schema,read,op)
  if not receipt and read.status=="FOUND" and schema.validate(read.value,key) and not read.value.deleted then
   local result=adapter.commit(adapter.beginUpdate(key,Ops.reduce(S,schema,op)))
   trace(job,'UPDATE',result.status,result.reason or result.outcome)
   if result.status~="SAVED" and result.status~="PENDING" then
    trace(job,'FINAL','SAVE_FAILED',result.reason or result.status)
    publish(player,op,"SAVE_FAILED");job.done=true;return
   end
   -- UseCache=false even after a successful UpdateAsync response or lost ACK.
   read=adapter.read(key);receipt=Ops.confirm(S,schema,read,op)
   trace(job,'VERIFY',read.status,read.reason,{receiptConfirmed=receipt~=nil})
  end
  if receipt then
   trace(job,'FINAL','SAVE_CONFIRMED','RECEIPT_MATCH',{receiptConfirmed=true})
   publish(player,op,"SAVE_CONFIRMED",receipt);job.done=true
   if deps.diagnostic then pcall(deps.diagnostic,player,"RECORD_SAVED",op.round.RoundGuid) end
   repair(player,adapter,read.value);return
  end
  if read.status=="ABSENT" or read.status=="CORRUPT" or read.status=="FUTURE"
   or (read.status=="FOUND" and (read.value.deleted or not schema.validate(read.value,key))) then
   trace(job,'FINAL','READ_ONLY',if read.status=='FOUND' and read.value.deleted then 'DELETED' else read.reason or validationReason or read.status)
   publish(player,op,"READ_ONLY");job.done=true;return
  end
  publish(player,op,"SAVE_PENDING")
  job.attempts+=1
  if job.attempts<deps.retryAttempts and not closing then
   deps.delay(0.5*2^(job.attempts-1),function() job.running=true;local ok=pcall(attempt,job);job.running=false
    if not ok then trace(job,'EXCEPTION','SAVE_PENDING','RUNTIME_EXCEPTION');publish(player,op,"SAVE_PENDING");job.done=true end end)
  else trace(job,'FINAL','SAVE_PENDING','RETRY_EXHAUSTED');job.done=true end
 end
 function api.submit(player,op)
  if closing then return false,'CLOSING' end
  if not Ops.valid(S,op) then return false,'INVALID_RECORD' end
  if player.UserId~=op.userId then return false,'WRONG_USER' end
  if not deps.allowed(player,"write") then return false,'ACCESS_BLOCKED' end
  local key=S.userKey(player.UserId)..":"..op.round.RoundGuid
  if jobs[key] then local same=S.canonical(jobs[key].op)==S.canonical(op);return same,if same then nil else 'IDENTITY_MISMATCH' end
  local count=0
  for k,job in jobs do if job.done then jobs[k]=nil else count+=1 end end
  if count>=16 then return false,'JOB_CAPACITY' end
  local job={player=player,op=S.freeze(S.clone(op)),attempts=0,done=false,running=true};jobs[key]=job
  trace(job,'SUBMIT','SAVE_PENDING')
  publish(player,op,"SAVE_PENDING")
  deps.spawn(function()
   local ok=pcall(attempt,job);job.running=false
   if not ok then trace(job,'EXCEPTION','SAVE_PENDING','RUNTIME_EXCEPTION');publish(player,op,"SAVE_PENDING");job.done=true end
  end)
  return true
 end
 function api.shutdown()
  closing=true
  local deadline=deps.clock()+deps.shutdownSeconds
  -- Jobs keep immutable envelopes after departure. Never start a competing write.
  while deps.clock()<deadline do
   local active=false;for _,job in jobs do if not job.done then active=true end end
   if not active then break end
   deps.wait(0.1)
  end
 end
 return api
end
return table.freeze(Runtime)
