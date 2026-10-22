-- Loaded only after server configuration enables the Canary. No client entry point.
local Config=require(script.Parent.ProgressionCanaryConfig)
local Policy=require(script.Parent.ProgressionCanaryPolicy)
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S=require(Shared:WaitForChild("KDMProgressionSchema"))
local schema=S.new(require(Shared:WaitForChild("KartCatalog")),{utcMs=function()return DateTime.now().UnixTimestampMillis end})
local Ops=require(script.Parent.ProgressionOperations)
local Adapter=require(script.Parent.ProgressionDataStoreAdapter)
local Service=require(script.Parent.PlayerProgressionService)
local Runtime=require(script.Parent.ProgressionLiveRuntime)
local Coordinator={}
local runtimes={}
local function diagnostic(player,event,value)
 -- Only bounded event identifiers / selected public catalog ID. Never print profile bodies or errors.
 print(string.format("[KDMProgression] %s userId=%.0f value=%s",event,player.UserId,value or ""))
end
local function context()
 return {isStudio=game:GetService("RunService"):IsStudio(),role=workspace:GetAttribute("KDMServerRole"),
  experienceId=game.GameId,placeId=game.PlaceId,privateServerId=game.PrivateServerId}
end
function Coordinator.allowed(player) return Policy.allowed(Config,context(),player.UserId) end
local function create(player)
 local function authorize() return Coordinator.allowed(player) end
 assert(authorize(),"canary_not_authorized")
 -- Service lookup is deferred until an approved, non-Studio HUB read/write.
 local function dataService()
  assert(authorize(),"canary_access_blocked")
  return game:GetService("DataStoreService")
 end
 local adapter=Adapter.new({schema=schema,key=S.userKey(player.UserId),authorize=authorize,
  getStore=function() return dataService():GetDataStore(Config.StoreName) end,
  getOptions=function() local options=Instance.new("DataStoreGetOptions");options.UseCache=false;return options end,
  budget=function(kind)
   local ds=dataService()
   return ds:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardRead)>0
    and (kind=="read" or ds:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.StandardWrite)>0)
  end})
 return Runtime.new({Service=Service,config=Config,authorize=function(p) return p==player and authorize() end,
  spawn=task.spawn,delay=task.delay,wait=task.wait,clock=os.clock,
  -- Binding is read-only; an explicit validated Garage selection may create a profile.
  coreDependencies={initializeAbsent=true,tools=S,schema=schema,operations=Ops,store=adapter,diagnostic=diagnostic,
   newOperationId=function() return game:GetService("HttpService"):GenerateGUID(false) end}})
end
function Coordinator.bind(player)
 if not Coordinator.allowed(player) then diagnostic(player,"CANARY_DENIED");return false end
 diagnostic(player,"CANARY_ALLOWED")
 if not runtimes[player] then runtimes[player]=create(player) end
 return runtimes[player].bind(player)
end
function Coordinator.select(player,kartId)
 if not Coordinator.allowed(player) then
  -- Non-Canary players retain the existing session-only selection flow.
  if not schema.supportsKart(kartId) then return false end
  player:SetAttribute("SelectedKartId",kartId);return true
 end
 return runtimes[player]~=nil and runtimes[player].select(player,kartId)
end
function Coordinator.selection(player,fallback)
 return if runtimes[player] then runtimes[player].selection(player,fallback) else fallback
end
function Coordinator.remove(player)
 local runtime=runtimes[player]
 if runtime then runtime.remove(player);task.delay(Config.DepartureDrainSeconds,function() if runtimes[player]==runtime then runtimes[player]=nil end end) end
end
function Coordinator.shutdown()
 -- Drain users concurrently; total shutdown bound remains the configured deadline.
 local remaining=0
 for _,runtime in runtimes do remaining+=1;task.spawn(function() runtime.shutdown();remaining-=1 end) end
 local deadline=os.clock()+Config.ShutdownDrainSeconds
 while remaining>0 and os.clock()<deadline do task.wait(0.1) end
end
return table.freeze(Coordinator)
