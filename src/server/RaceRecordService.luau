-- Live binding is deferred. Loading this module never accesses DataStoreService.
local Service={}
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S=require(Shared:WaitForChild("KDMProgressionSchema"))
local schema=S.new(require(Shared:WaitForChild("KartCatalog")))
local Config=require(script.Parent.RaceRecordConfig)
local Policy=require(script.Parent.RaceRecordPolicy)
local Ops=require(script.Parent.RaceRecordOperations)
local Adapter=require(script.Parent.ProgressionDataStoreAdapter)
local Runtime=require(script.Parent.RaceRecordRuntime)
local Collector=require(script.Parent.OfficialRaceRecords)
local PerfBuffer=require(Shared.KDMPerformanceBuffer)
local RecordReset=require(script.Parent.RaceRecordReset)
local resetBusy={}
local runtime=nil
local function context()
 return {isStudio=game:GetService("RunService"):IsStudio(),role=workspace:GetAttribute("KDMServerRole"),
  experienceId=game.GameId,placeId=game.PlaceId,privateServerId=game.PrivateServerId,privateServerOwnerId=game.PrivateServerOwnerId}
end
local function allowed(player,kind) return Policy.allowed(Config,context(),player.UserId,kind) end
local function diagnostic(player,event,guid,row)
 if not PerfBuffer.allowed(game:GetService('RunService'):IsStudio(),player.UserId,game.GameId,game.PlaceId) then return end
 local ctx=context()
 local safe={event=event,round=guid,userId=player.UserId,experienceId=game.GameId,placeId=game.PlaceId,
  publishedVersion=game.PlaceVersion,serverRole=ctx.role,reserved=ctx.privateServerId~='' and ctx.privateServerOwnerId==0,
  privateServerOwnerId=ctx.privateServerOwnerId,session=player:GetAttribute('RaceSessionId'),
  policyRead=allowed(player,'read'),policyWrite=allowed(player,'write')}
 -- Fixed whitelist: no profile values, keys, purchases, platform error strings or receipts.
 for _,key in {'stage','status','reason','attempt','receiptConfirmed','schemaValid','deleted','trackId','geometryId','category',
  'targetLaps','totalMilliseconds','laps','finishPosition','eligible','eligibilityReason','startingHumans','startingBots'} do
  if row then safe[key]=row[key] end
 end
 if safe.policyRead then
  local ok,readBudget,writeBudget=pcall(function()
   local ds=game:GetService('DataStoreService')
   return ds:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead),
    ds:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)
  end)
  if ok then safe.readBudget,safe.writeBudget=readBudget,writeBudget end
 end
 if guid==player:GetAttribute('OfficialRoundGuid') and row and row.stage and row.stage~='QUERY' then
  player:SetAttribute('RaceRecordDiagnostic',row.stage..' / '..(row.status or 'N/A')..' / '..(row.reason or 'NONE'))
  player:SetAttribute('RaceRecordDiagnosticRound',guid)
  player:SetAttribute('RaceRecordReceiptConfirmed',row.receiptConfirmed==true)
 end
 print('[KDMRecordTrace] '..game:GetService('HttpService'):JSONEncode(safe))
end
local function ds(player,kind)
 assert(allowed(player,kind),"record_access_blocked")
 return game:GetService("DataStoreService")
end
local function live()
 if runtime then return runtime end
 runtime=Runtime.new(S,schema,Ops,{allowed=allowed,retryAttempts=Config.RetryAttempts,
  spawn=task.spawn,delay=task.delay,clock=os.clock,wait=task.wait,shutdownSeconds=Config.ShutdownSeconds,
  diagnostic=diagnostic,
  adapter=function(player)
   return Adapter.new({schema=schema,key=S.userKey(player.UserId),authorize=function() return allowed(player,"read") end,
    getStore=function() return ds(player,"read"):GetDataStore(Config.StoreName) end,
    getOptions=function() local opts=Instance.new("DataStoreGetOptions");opts.UseCache=false;return opts end,
    budget=function(kind)
     local store=ds(player,"read")
     return store:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead)>0
      and (kind=="read" or store:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)>0)
    end})
  end,
  index=function(player,entry)
   if entry.kind=="RACE" then
    local snapshot=entry.snapshot
    if not S.raceSnapshotValid(snapshot) or not snapshot.eligible or snapshot.startingBots~=0 then return false end
    local scope=Policy.indexScope(Config,snapshot);if not scope then return false end
    scope..="_L"..snapshot.targetLaps
    local store=ds(player,"repair")
    if store:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedRead)<1
     or store:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedWrite)<1 then return false end
    return pcall(function()
     store:GetOrderedDataStore("KDM_A3_Race_v1",scope):UpdateAsync(tostring(player.UserId),function(old)
      if old~=nil then assert(S.integer(old) and old>0,"invalid_index");return math.min(old,snapshot.totalMilliseconds) end
      return snapshot.totalMilliseconds
     end)
    end)
   end
   local scope=Policy.indexScope(Config,entry);if not scope then return false end
   local store=ds(player,"repair")
   if store:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedRead)<2
    or store:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.OrderedWrite)<2 then return false end
   local ok=pcall(function()
    if entry.lap then
     store:GetOrderedDataStore("KDM_A3_Lap_v1",scope):UpdateAsync(tostring(player.UserId),function(old)
      if old~=nil then assert(S.integer(old) and old>0,"invalid_index");return math.min(old,entry.lap) end
      return entry.lap
     end)
    end
    store:GetOrderedDataStore("KDM_A3_Drift_v1",scope):UpdateAsync(tostring(player.UserId),function(old)
     if old~=nil then assert(S.integer(old),"invalid_index");return math.max(old,entry.boost) end
     return entry.boost
    end)
   end)
   return ok
  end})
 return runtime
end
local collector=Collector.new(S,{utcMs=function() return DateTime.now().UnixTimestampMillis end})
function Service.begin(session,course,checkpointCount)
 local participants=session:orderedParticipants();local roster={}
 for _,p in participants do
  table.insert(roster,if p:GetAttribute("IsBot")==true then {IsBot=true,BotId=p:GetAttribute("BotId")}
   else {IsBot=false,UserId=p.UserId})
 end
 local round=collector.begin({RoundGuid=game:GetService("HttpService"):GenerateGUID(false),
  TrackId=session.trackId,GeometryId=require(Shared:WaitForChild("TrackCatalog")).Entries[session.trackId].GeometryId,
  RulesetId=Config.RulesetId,diagnostic=game:GetService("RunService"):IsStudio(),roster=roster},
  participants,checkpointCount,session.targetLaps,course.CenterlineLength)
 for _,p in participants do
  p:SetAttribute("OfficialRoundGuid",round.RoundGuid);p:SetAttribute("RaceRecordCategory",round.RaceCategory)
  p:SetAttribute("RaceRecordNewPB",false);p:SetAttribute("RaceRecordSaveState","NONE")
  p:SetAttribute("RaceRecordNewBestRace",false)
  p:SetAttribute('RaceRecordDiagnostic',nil);p:SetAttribute('RaceRecordDiagnosticRound',nil)
  p:SetAttribute('RaceRecordReceiptConfirmed',false)
 end
end
function Service.start(player,now) collector.start(player,now) end
function Service.invalidate(player) collector.invalidate(player) end
function Service.progress(player,now,position,fraction,nextCheckpoint)
 collector.sample(player,now,position,fraction);collector.checkpoints(player,nextCheckpoint)
end
function Service.lap(player,now,officialLapTime) collector.lap(player,now,officialLapTime) end
function Service.checkpoints(player,nextCheckpoint) collector.checkpoints(player,nextCheckpoint) end
function Service.boost(player,eventId) collector.boost(player,eventId) end
function Service.finish(player,result)
 local op=collector.finish(player,result)
 local guid=player:GetAttribute('OfficialRoundGuid')
 local race=op and op.race
 pcall(diagnostic,player,'FINISH',guid,{stage='FINISH',status=if not op then 'NO_OPERATION' elseif allowed(player,'write') then 'WRITE_ALLOWED' else 'ACCESS_BLOCKED',
  trackId=race and race.trackId,geometryId=race and race.geometryId,category=race and race.category,
  targetLaps=race and race.targetLaps,totalMilliseconds=race and race.totalMilliseconds,laps=race and race.laps,
  finishPosition=race and race.finishPosition,eligible=race and race.eligible,eligibilityReason=race and race.reason,
  startingHumans=race and race.startingHumans,startingBots=race and race.startingBots})
 if op and allowed(player,"write") then
  local accepted,reason=live().submit(player,op)
  if not accepted then
   pcall(diagnostic,player,'REJECTED',guid,{stage='SUBMIT',status='SAVE_FAILED',reason=reason or 'RUNTIME_REJECTED'})
   player:SetAttribute("RaceRecordSaveState","SAVE_FAILED")
  end
 end
end
function Service.startQuery()
 local storage=game:GetService("ReplicatedStorage")
 local remote=Instance.new("RemoteFunction");remote.Name="KDMGetPersonalRecords";remote.Parent=storage
 local last={}
 remote.OnServerInvoke=function(player)
  if not allowed(player,"read") then return {status="ACCESS_BLOCKED"} end
  local now=os.clock();if last[player] and now-last[player]<4 then return {status="RATE_LIMITED"} end
  last[player]=now
  local ctx=context()
  local resetState
  if player.UserId==Config.ResetUserId and type(game.PlaceVersion)=='number' and ctx.isStudio==false
   and ctx.role=='HUB' and ctx.experienceId==Config.ExperienceId and ctx.placeId==Config.PlaceId and ctx.privateServerId=='' then
   if resetBusy[player.UserId] then return {status='RESET_PENDING'} end
   resetBusy[player.UserId]=true
   local ok,status=pcall(function()
    local backend=ds(player,'read')
    if backend:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead)<3
     or backend:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)<2 then return 'BUDGET_UNAVAILABLE' end
    local store=backend:GetDataStore(Config.StoreName)
    local archive=backend:GetDataStore('KDM_RecordResetBackup_v1')
    local key=S.userKey(player.UserId)
    local ref=Config.ResetId..':'..game:GetService('HttpService'):GenerateGUID(false)
    local function read(backend,k)
     local opts=Instance.new('DataStoreGetOptions');opts.UseCache=false;return backend:GetAsync(k,opts)
    end
    return RecordReset.run(S,schema,{userId=player.UserId,id=Config.ResetId,backupRef=ref,
     utcMs=function()return DateTime.now().UnixTimestampMillis end,
     read=function()return read(store,key)end,readBackup=function()return read(archive,ref)end,
     backup=function(value)archive:UpdateAsync(ref,function(old)return old or value end)end,
     update=function(callback)store:UpdateAsync(key,function(previous,info)
      local value=callback(previous)
      return value,if info then info:GetUserIds() else nil,if info then info:GetMetadata() else nil
     end)end})
   end)
   resetBusy[player.UserId]=nil
   resetState=if ok then status else 'RESET_UNCONFIRMED'
   pcall(diagnostic,player,'RESET',nil,{stage='QUERY',status=resetState})
   if resetState~='RESET_CONFIRMED' and resetState~='ALREADY_RESET' then return {status=resetState} end
  end
  local ok,value=pcall(function() return live().read(player) end)
  if ok and resetState then value.resetState=resetState end
  pcall(diagnostic,player,'QUERY',nil,{stage='QUERY',status=if ok then value.status else 'ERROR',reason=if ok then value.reason else 'QUERY_EXCEPTION'})
  return if ok then value else {status="ERROR"}
 end
 game:GetService("Players").PlayerRemoving:Connect(function(p) last[p]=nil end)
 game:BindToClose(function() if runtime then runtime.shutdown() end end)
end
return table.freeze(Service)
