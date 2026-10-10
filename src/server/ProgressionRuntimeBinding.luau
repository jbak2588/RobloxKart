-- Production stays OFF. Only a server-side Studio harness can inject a Mock service.
local Binding = {}
Binding.KDM_PROGRESS_KART_PERSISTENCE_ENABLED = false
local runtime = nil
local function live()
 if runtime then return runtime end
 -- Local harnesses have no Instance hierarchy; default remains OFF there as well.
 if script and script.Parent and script.Parent:FindFirstChild("ProgressionCanaryConfig") then
  local config=require(script.Parent.ProgressionCanaryConfig)
  if config.Enabled and not game:GetService("RunService"):IsStudio() then
   runtime=require(script.Parent.ProgressionLiveCoordinator)
  end
 end
 return runtime
end
function Binding.installStudioMock(service)
 assert(game:GetService("RunService"):IsStudio(), "studio_mock_only")
 assert(runtime == nil and type(service) == "table" and type(service.bind) == "function", "invalid_mock_runtime")
 runtime = service
end
function Binding.enabled() return live() ~= nil end
function Binding.bind(player)
 if not runtime then return false end
 local bound=runtime.bind(player)
 if bound and runtime.loadTimeout then task.delay(5,function() if runtime then runtime.loadTimeout(player) end end) end
 return bound
end
function Binding.select(player,kartId)
 return runtime ~= nil and runtime.select(player,kartId)
end
function Binding.selection(player,fallback)
 return if runtime then runtime.selection(player,fallback) else fallback
end
function Binding.remove(player) if runtime then runtime.remove(player) end end
function Binding.shutdown() if runtime then runtime.shutdown();runtime=nil end end
return table.freeze(Binding)
