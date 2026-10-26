local KartInputController = require(script:WaitForChild("KartInputController"))
local KartCameraController = require(script:WaitForChild("KartCameraController"))
local KDMImpactCameraController = require(script:WaitForChild("KDMImpactCameraController"))
local KDMItemVFXController = require(script:WaitForChild("KDMItemVFXController"))
local RaceHudController = require(script:WaitForChild("RaceHudController"))
local GarageUiController = require(script:WaitForChild("GarageUiController"))
local HubUiController = require(script:WaitForChild("HubUiController"))
local HubArrivalCameraController = require(script:WaitForChild("HubArrivalCameraController"))
local MatchRoomUiController = require(script:WaitForChild("MatchRoomUiController"))
local KartVisualMotionController = require(script:WaitForChild("KartVisualMotionController"))
local KDMDriverPedalController = require(script:WaitForChild("KDMDriverPedalController"))
local KDMDriverGripController = require(script:WaitForChild("KDMDriverGripController"))
local KartEffectsController = require(script:WaitForChild("KartEffectsController"))
local KartAudioController = require(script:WaitForChild("KartAudioController"))
local RaceAudioController = require(script:WaitForChild("RaceAudioController"))
local RaceItemUiController = require(script:WaitForChild("RaceItemUiController"))
local SmokeEffectView = require(script:WaitForChild("SmokeEffectView"))
local ShieldEffectsController = require(script:WaitForChild("ShieldEffectsController"))
local TouchDrivingController = require(script:WaitForChild("TouchDrivingController"))
local DriftChargeController = require(script:WaitForChild("DriftChargeController"))
local DriverCelebrationController = require(script:WaitForChild("DriverCelebrationController"))
local FinishCelebrationController = require(script:WaitForChild("FinishCelebrationController"))
local TrackHorizonController = require(script:WaitForChild("TrackHorizonController"))
local TrackCircuitStructuresController = require(script:WaitForChild("TrackCircuitStructuresController"))
local Workspace = game:GetService("Workspace")

local role = Workspace:GetAttribute("KDMServerRole")
while role ~= "HUB" and role ~= "RACE" do
	Workspace:GetAttributeChangedSignal("KDMServerRole"):Wait()
	role = Workspace:GetAttribute("KDMServerRole")
end

print("RobloxKart CLIENT sync OK role=" .. role)
require(script:WaitForChild('RaceRouteTransitionView')).start()
KartInputController.start()
KartCameraController.start()
KDMImpactCameraController.start()
KDMItemVFXController.start()
RaceHudController.start()
require(script:WaitForChild('CheckpointGuidanceController')).start()
TouchDrivingController.start()
DriftChargeController.start()
if role == "HUB" then GarageUiController.start(); MatchRoomUiController.start(); HubUiController.start(); HubArrivalCameraController.start() end
if role == "HUB" then require(script:WaitForChild("LobbyTestDriveController")).start() end
if role == "HUB" then task.defer(require(script:WaitForChild("LobbyDemoController")).start) end
if role == "HUB" then require(script:WaitForChild("PersonalRecordsController")).start() end
require(script:WaitForChild('EconomyController')).start()
require(script:WaitForChild('GarageShopController')).start()
if role=='HUB' then require(script:WaitForChild('WelcomeRewardController')).start() end
if role=='HUB' then require(script:WaitForChild('ActivityRewardView')).start() end
KartVisualMotionController.start()
KDMDriverGripController.start()
KDMDriverPedalController.start()
KartEffectsController.start()
KartAudioController.start()
RaceAudioController.start()
require(script:WaitForChild('CombatHitAudioController')).start()
RaceItemUiController.start()
-- Race loadouts are now fixed; there is no item-selection/preparation overlay.
if role == 'RACE' then require(script:WaitForChild('PublicRaceStatusView')).start() end
if role == "RACE" then TrackHorizonController.start() end
if role == "RACE" then require(script:WaitForChild('MetroCityEnvironment')).start() end
if role == "RACE" then TrackCircuitStructuresController.start() end
require(script:WaitForChild('TrackSurfaceController')).start()
Workspace:GetAttributeChangedSignal("KDMServerRole"):Connect(function()
	if Workspace:GetAttribute("KDMServerRole") == "RACE" then
		require(script:WaitForChild('MetroCityEnvironment')).start()
		TrackCircuitStructuresController.start()
	end
end)
SmokeEffectView.new(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"),game:GetService("Players").LocalPlayer)
ShieldEffectsController.start()
DriverCelebrationController.start()
FinishCelebrationController.start()
