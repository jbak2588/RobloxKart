local KartInputController = require(script:WaitForChild("KartInputController"))
local KartCameraController = require(script:WaitForChild("KartCameraController"))

print("RobloxKart CLIENT sync OK")
KartInputController.start()
KartCameraController.start()
