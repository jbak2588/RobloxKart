local KartInputController = require(script:WaitForChild("KartInputController"))
local KartCameraController = require(script:WaitForChild("KartCameraController"))
local RaceHudController = require(script:WaitForChild("RaceHudController"))

print("RobloxKart CLIENT sync OK")
KartInputController.start()
KartCameraController.start()
RaceHudController.start()
