-- Register actual production modules in the old Garage mock inventory.
-- The guidance test body, injected checks, and every assertion remain unchanged.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture='tests/garage_transition_validation.luau'
local old='"HubGuidanceState", "HubGuidanceView", "HubWorldGuidanceView"'
local new='"LobbyDriveLayout", "MobileControlView", '..old
local proxy=setmetatable({readFile=function(path)
 local source=fs.readFile(path)
 if path==fixture then
  local _,n=source:gsub(old,new);assert(n==1,'ambiguous mock inventory registration')
  source=source:gsub(old,new)
 end
 return source
end},{__index=fs})
local function req(name)
 if name=='@lune/fs' then return proxy end
 if name:sub(1,2)=='./' then return require('../../tests/'..name:sub(3)) end
 return require(name)
end
local path=require('@lune/process').args[1] or 'tests/hub_next_action_guidance_validation.luau'
assert(path=='tests/hub_next_action_guidance_validation.luau' or path=='tests/hub_world_progression_validation.luau','unreviewed harness target')
luau.load(fs.readFile(path),{environment={require=req}})()
