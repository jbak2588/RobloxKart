-- Add the new production module to the old mock inventory, without changing assertions or repository fixtures.
local fs,luau=require('@lune/fs'),require('@lune/luau')
local source=fs.readFile('tests/mobile_touch_validation.luau')
source=source:gsub('"TouchDrivingModel","MobileControlView"','"LobbyDriveLayout","TouchDrivingModel","MobileControlView"')
source=source:gsub('"KartInputController","TouchDrivingModel"','"KartInputController","LobbyDriveLayout","TouchDrivingModel"')
local function req(name)
 if name:sub(1,2)=='./' then return require('../../tests/'..name:sub(3)) end
 return require(name)
end
luau.load(source,{environment={require=req}})()
