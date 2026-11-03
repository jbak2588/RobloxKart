local fs,luau=require('@lune/fs'),require('@lune/luau')
local fixture=fs.readFile('tests/garage_transition_validation.luau')
local prefix=fixture:sub(1,assert(fixture:find('controller.start()',1,true))-1)
local scenario=[=[
services.Workspace:SetAttribute('KDMServerRole','HUB');services.Workspace:SetAttribute('HubParkV1Enabled',true)
child(client,'ModuleScript','LobbyTestDriveController')
local requested
modules.LobbyTestDriveController={requestDrive=function(mode)requested=mode;return true end}
controller.start();controller.open('TRACKS')
local gui=playerGui.RobloxKartGarage;local body=gui:FindFirstChild('Frame')
local function findText(value)for _,v in body:GetDescendants()do if v.Text==value then return v end end end
assert(findText('START OVERTAKE'),'existing Overtake remains first')
body.NextChoice.Activated:Fire()
local join=findText('JOIN 8-RACER PARK');assert(join,'new Park multiplayer is second preview')
assert(findText('Rookie Park Multiplayer'),'new distinct preview identity')
local before=remote.fireCount;join.Activated:Fire()
assert(requested=='MULTIPLAYER'and remote.fireCount==before and not gui.Enabled,'dedicated Park mode request, no official Ready protocol')
print('PASS: actual Garage second-card Park multiplayer launch')
]=]
luau.load(prefix..scenario,{debugName='park_multiplayer_garage'})()
