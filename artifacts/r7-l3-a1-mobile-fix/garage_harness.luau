local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/garage_transition_validation.luau')
source=source:gsub('"HubGuidanceState", "HubGuidanceView", "HubWorldGuidanceView"','"LobbyDriveLayout", "MobileControlView", "HubGuidanceState", "HubGuidanceView", "HubWorldGuidanceView"')
local function req(name)
 if name:sub(1,2)=='./' then return require('../../tests/'..name:sub(3)) end
 return require(name)
end
luau.load(source,{environment={require=req}})()
