local PrototypeWorld = require(script:WaitForChild("PrototypeWorld"))
local RaceController = require(script:WaitForChild("RaceController"))
local GarageController = require(script:WaitForChild("GarageController"))

print("RobloxKart SERVER sync OK")
PrototypeWorld.start()
RaceController.start()
GarageController.start()
