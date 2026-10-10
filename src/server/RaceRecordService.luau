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
local runtime=nil
local function context()
 return {isStudio=game:GetService("RunService"):IsStudio(),role=workspace:GetAttribute("KDMServerRole"),
  experienceId=game.GameId,placeId=game.PlaceId,privateServerId=game.PrivateServerId,privateServerOwnerId=game.PrivateServerOwnerId}
end
local function allowed(player,kind) return Policy.allowed(Config,context(),player.UserId,kind) end
local function ds(player,kind)
 assert(allowed(player,kind),"record_access_blocked")
 return game:GetService("DataStoreService")
end
local function live()
 if runtime then return runtime end
 runtime=Runtime.new(S,schema,Ops,{allowed=allowed,retryAttempts=Config.RetryAttempts,
  spawn=task.spawn,delay=task.delay,clock=os.clock,wait=task.wait,shutdownSeconds=Config.ShutdownSeconds,
  diagnostic=function(player,event,guid) print(string.format("[KDMRecords] %s userId=%.0f round=%s",event,player.UserId,guid)) end,
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
 end
end
function Service.start(player,now) collector.start(player,now) end
function Service.invalidate(player) collector.invalidate(player) end
function Service.progress(player,now,position,fraction,nextCheckpoint)
 collector.sample(player,now,position,fraction);collector.checkpoints(player,nextCheckpoint)
end
function Service.lap(player,now) collector.lap(player,now) end
function Service.checkpoints(player,nextCheckpoint) collector.checkpoints(player,nextCheckpoint) end
function Service.boost(player,eventId) collector.boost(player,eventId) end
function Service.finish(player)
 local op=collector.finish(player)
 if op and allowed(player,"write") then
  if not live().submit(player,op) then player:SetAttribute("RaceRecordSaveState","SAVE_FAILED") end
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
  local ok,value=pcall(function() return live().read(player) end)
  return if ok then value else {status="ERROR"}
 end
 game:GetService("Players").PlayerRemoving:Connect(function(p) last[p]=nil end)
 game:BindToClose(function() if runtime then runtime.shutdown() end end)
end
return table.freeze(Service)
