-- Bounded lifecycle wrapper. All I/O and scheduling are injected and server-owned.
local Runtime={}
function Runtime.new(deps)
 local core, players, attempts, closing=nil,{},{},false
 local function retry(player)
  local state=core.inspect(player)
  if not state or not state.operation or state.state=="SAVED" or state.state=="READ_ONLY" or closing then return end
  if state.reason=="CONFLICT" or state.reason=="ACCESS_BLOCKED" then return end
  local id=state.operation.operationId
  attempts[id]=(attempts[id] or 0)+1
  if attempts[id]>=deps.config.RetryAttempts then return end
  deps.delay(0.5*2^(attempts[id]-1),function()
   local latest=core.inspect(player)
   if latest and latest.operation and latest.operation.operationId==id then core.flush(player) end
  end)
 end
 local options=table.clone(deps.coreDependencies)
 options.mode="LIVE_CANARY";options.liveAuthorized=true
 options.loadSchedule=deps.spawn
 options.schedule=function(job)
  deps.spawn(function()
   job()
   for player in players do retry(player) end
  end)
 end
 core=deps.Service.new(options)
 local api={}
 function api.bind(player)
  if closing or not deps.authorize(player) then return false end
  players[player]=true
  local bound=core.bind(player)
  if bound then deps.delay(deps.config.LoadTimeoutSeconds,function() core.loadTimeout(player) end) end
  return bound
 end
 function api.select(player,kartId) return not closing and deps.authorize(player) and core.select(player,kartId) end
 function api.adopt(player,profile) return not closing and deps.authorize(player) and core.adopt(player,profile) end
 function api.selection(player,fallback) return core.selection(player,fallback) end
 function api.inspect(player) return core.inspect(player) end
 function api.remove(player)
  if not players[player] then return end
  core.detach(player)
  local state=core.inspect(player)
  if state and state.operation then core.flush(player) end
  deps.delay(deps.config.DepartureDrainSeconds,function() core.remove(player);players[player]=nil end)
 end
 function api.shutdown()
  closing=true
  for player in players do
   core.detach(player)
   local state=core.inspect(player)
   if state and state.operation then core.flush(player) end
  end
  local deadline=deps.clock()+deps.config.ShutdownDrainSeconds
  while deps.clock()<deadline do
   local pending=false
   for player in players do
    local state=core.inspect(player)
    if state and state.operation and (state.state=="SAVING" or state.state=="PENDING") then pending=true end
   end
   if not pending then break end
   deps.wait(0.1)
  end
  core.shutdown();table.clear(players)
 end
 return api
end
return table.freeze(Runtime)
