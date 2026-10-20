-- Server-owned runtime. No service/network lookup; explicit dependencies only.
local Service = {}
function Service.new(deps)
 local S, schema, Ops, store = deps.tools, deps.schema, deps.operations, deps.store
 assert((deps.mode == "MOCK" or (deps.mode == "LIVE_CANARY" and deps.liveAuthorized==true)) and store and deps.newOperationId, "authorized_injection_required")
 local sessions = {}
 local api = {}
 local function diagnose(player,event,kartId)
  if deps.diagnostic then deps.diagnostic(player,event,kartId) end
 end
 local function publish(player, session, state, reason)
  session.state, session.reason = state, reason or ""
  local diagnostic=if state=="SAVED" then "SAVE_CONFIRMED" elseif state=="ERROR" or state=="READ_ONLY" then "SAVE_FAILED"
   elseif state=="READY" then "SESSION_APPLIED" else "SAVE_PENDING"
  if session.lastDiagnostic~=diagnostic then session.lastDiagnostic=diagnostic;diagnose(player,diagnostic) end
  if session.departing then return end
  player:SetAttribute("KartPersistenceMock", deps.mode=="MOCK")
  player:SetAttribute("KartProfileState", state)
  player:SetAttribute("KartSaveState", if state == "SAVED" then "SAVE_CONFIRMED" elseif state == "READ_ONLY" then "READ_ONLY"
   elseif state == "ERROR" then "SAVE_FAILED" elseif state == "READY" then "SESSION_APPLIED" else "SAVE_PENDING")
  player:SetAttribute("KartSaveReason", session.reason)
  player:SetAttribute("KartSelectionGeneration", session.generation)
 end
 local function active(player, session) return sessions[player] == session end
 local function raceLocked(player,session)
  local state=player:GetAttribute("RaceState")
  return session.locked or (state ~= nil and state ~= "GARAGE") or player:GetAttribute("KDMRoutePending")=="RACE_LAUNCH"
 end
 local function apply(player, session, kartId)
  if session.departing or raceLocked(player,session) then return end
  session.kartId = kartId
  player:SetAttribute("SelectedKartId", kartId)
  diagnose(player,"SESSION_APPLIED",kartId)
 end
 local function acknowledge(player, session, request, result)
  if not active(player,session) or session.request ~= request then return end
  if result.status == "READ_ONLY" or result.status == "DELETED" or result.status=="FUTURE" or result.status=="CORRUPT" then
   session.blocked = true; publish(player,session,"READ_ONLY",result.reason or result.status); return
  end
  -- A transport ACK alone is insufficient: validate a read-back receipt and current selection.
  local ok, read = pcall(store.read,session.key)
  if not ok then read={status="ERROR",key=session.key,reason="READ_UNAVAILABLE"} end
  local resolved = Ops.resolveSelection(S,schema,read,session.userId,request.operation)
  if resolved.state == "SAVED" and resolved.profile.selection.lastOpId == request.operation.operationId
   and resolved.profile.selection.kartId == request.operation.kartId then
   session.profile, session.request = resolved.profile, nil
   publish(player,session,"SAVED")
  else
   if result.status~="SAVED" then diagnose(player,"SAVE_FAILED") end
   publish(player,session,if result.status == "PENDING" or result.status == "SAVED" or result.status == "CONFLICT" then "PENDING" else "ERROR",
    result.reason or result.status or resolved.reason)
  end
 end
 function api.flush(player)
  local session = sessions[player]
  if not session or session.locked or session.blocked or not session.profile or not session.desired then return false end
  if session.absent and deps.initializeAbsent==false and player:GetAttribute('KDMAccountQualified')~=true then
   publish(player,session,'READY','SESSION_ONLY');return false
  end
  if not session.request then
   local operation = {kind="SELECT_KART",kartId=session.desired,expectedSelectionRevision=session.profile.selection.revision,
    operationId=deps.newOperationId(),transaction=if schema.issueTransaction then schema.issueTransaction() else nil}
   session.request = {operation=operation,generation=session.generation}
  end
  local request = session.request
  if request.inFlight then return false end
  request.inFlight = true
  publish(player,session,"SAVING")
  local reducer = Ops.selection(S,schema,session.userId,request.operation)
  local function callback(previous)
   if previous == nil and session.absent then
    if deps.initializeAbsent==false then return nil,'ACTIVITY_REQUIRED' end
    previous = schema.default(session.userId)
   end
   return reducer(previous)
  end
  local prepared, transaction = pcall(store.beginUpdate,session.key,callback)
  if not prepared then request.inFlight=false;publish(player,session,"PENDING","STORE_EXCEPTION");return false end
  local function commit()
   if not active(player,session) or session.request ~= request then return end
   local ok, result = pcall(store.commit,transaction)
   request.inFlight = false
   acknowledge(player,session,request,if ok then result else {status="PENDING",reason="STORE_EXCEPTION"})
  end
  if deps.schedule then deps.schedule(commit) else commit() end
  return true
 end
 local function loaded(player,session,read)
  if not active(player,session) then return end
  if read.status == "PENDING" then session.loadTicket=read.ticket;publish(player,session,"LOADING");return end
  if not session.departing then
   player:SetAttribute("KartProfileLoadCompleted",true)
   player:SetAttribute("KartProfileLoadResult",read.status)
  end
  diagnose(player,if read.status=="FOUND" then "PROFILE_FOUND" elseif read.status=="ABSENT" then "PROFILE_ABSENT" else "PROFILE_ERROR")
  if read.status=="FUTURE" or read.status=="CORRUPT" then
   session.blocked=true;publish(player,session,"READ_ONLY",read.status);return
  end
  local result = Ops.load(S,schema,read,session.userId)
  session.loadTicket = nil
  if result.state == "READ_ONLY" or result.state == "DELETED" then
   session.blocked=true;publish(player,session,"READ_ONLY",result.reason or result.state);return
  end
  if not result.profile then session.blocked=true;publish(player,session,"ERROR","LOAD_UNAVAILABLE");return end
  session.profile, session.absent = result.profile, result.state == "NEW"
  if session.generation == 0 then
   apply(player,session,result.profile.selection.kartId)
   local matches=result.saved and result.profile.selection.kartId==session.kartId
   publish(player,session,if matches then "SAVED" else "READY",if matches then nil else "SESSION_ONLY")
   if matches and not session.departing and not raceLocked(player,session) then
    player:SetAttribute("KartRestoredKartId",session.kartId)
    player:SetAttribute("KartRestorationConfirmed",true)
    player:SetAttribute("KartHubGuidanceAction","TRACKS")
    diagnose(player,"RESTORED_KART_ID",session.kartId);diagnose(player,"HUB_GUIDANCE_ACTION","TRACKS")
   end
  else
   -- Never restore over a selection made while the read was pending.
   publish(player,session,"PENDING");api.flush(player)
  end
 end
 function api.bind(player, options)
  if sessions[player] then return false end
  options = options or {}
  local userId = if deps.userId then deps.userId(player) else player.UserId
  local session = {userId=userId,key=S.userKey(userId),generation=0,locked=options.locked==true,kartId=options.kartId or "Kart05"}
  sessions[player]=session
  player:SetAttribute("KartProfileLoadCompleted",false)
  player:SetAttribute("KartProfileLoadResult","LOADING")
  player:SetAttribute("KartRestorationConfirmed",false)
  player:SetAttribute("KartRestoredKartId",nil)
  player:SetAttribute("KartHubGuidanceAction","GARAGE")
  diagnose(player,"HUB_GUIDANCE_ACTION","GARAGE")
  if not session.locked then apply(player,session,session.kartId) end
  publish(player,session,"LOADING")
  local function loadProfile()
   local ok,read=pcall(store.read,session.key)
   loaded(player,session,if ok then read else {status="ERROR",key=session.key})
  end
  if deps.loadSchedule then deps.loadSchedule(loadProfile) else loadProfile() end
  return true
 end
 function api.completeLoad(player)
  local session=sessions[player]
  if not session or not session.loadTicket then return false end
  local ok,read=pcall(store.finishRead,session.loadTicket)
  loaded(player,session,if ok then read else {status="ERROR",key=session.key})
  return true
 end
 function api.loadTimeout(player)
  local session=sessions[player]
  if session and (session.loadTicket or session.state=="LOADING") then publish(player,session,"PENDING","LOAD_TIMEOUT_SESSION_FALLBACK") end
 end
 function api.select(player,kartId)
  local session=sessions[player]
  if not session or raceLocked(player,session) or not schema.supportsKart(kartId) then return false end
  if session.desired == kartId then return true end -- same request retains its operation identity
  session.generation+=1;session.desired=kartId;session.request=nil
  player:SetAttribute("KartRestorationConfirmed",false)
  apply(player,session,kartId)
  if session.blocked then publish(player,session,"READ_ONLY","SESSION_ONLY")
  else publish(player,session,"PENDING");api.flush(player) end
  return true
 end
 function api.selection(player,fallback)
  local session=sessions[player]
  return if session then session.kartId else fallback
 end
 function api.inspect(player)
  local session=sessions[player]
  if not session then return nil end
  return {state=session.state,reason=session.reason,kartId=session.kartId,generation=session.generation,
   operation=if session.request then S.clone(session.request.operation) else nil,locked=session.locked}
 end
 function api.detach(player)
  local session=sessions[player];if session then session.departing=true end
 end
 function api.remove(player) sessions[player]=nil end -- late callbacks cannot apply or commit
 function api.shutdown() table.clear(sessions) end
 return api
end
return table.freeze(Service)
