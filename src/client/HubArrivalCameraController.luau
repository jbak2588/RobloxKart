local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HubArrivalCameraController = {}
local started = false

function HubArrivalCameraController.start()
 if started or Workspace:GetAttribute("KDMServerRole") ~= "HUB" then return end
 started = true
 local player = Players.LocalPlayer
 local generation = 0
 local function frameArrival()
  generation += 1
  local request = generation
  task.spawn(function()
   local deadline = os.clock() + 3
   while request == generation and os.clock() < deadline do
    RunService.RenderStepped:Wait()
    if player:GetAttribute("RaceState") ~= "GARAGE" then return end
    local hub = Workspace:FindFirstChild("KDMHub")
    local spawn = hub and hub:FindFirstChild("HubSpawn")
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local camera = Workspace.CurrentCamera
    if spawn and root and humanoid and camera and not humanoid.SeatPart
     and (root.Position - (spawn.Position + Vector3.new(0, 3, 0))).Magnitude < 5 then
     local forward = spawn.CFrame.LookVector
     local focus = root.Position + forward * 20 + Vector3.new(0, 1, 0)
     camera.CameraType = Enum.CameraType.Custom
     camera.CameraSubject = humanoid
     camera.CFrame = CFrame.lookAt(root.Position - forward * 10 + Vector3.new(0, 5, 0), focus)
     camera.Focus = CFrame.new(root.Position)
     return -- Native camera owns walking, touch/mouse orbit and zoom immediately.
    end
   end
  end)
 end
 player:GetAttributeChangedSignal("HubArrivalSerial"):Connect(frameArrival)
 player.CharacterRemoving:Connect(function() generation += 1 end)
 player:GetAttributeChangedSignal("RaceState"):Connect(function()
  if player:GetAttribute("RaceState") ~= "GARAGE" then generation += 1 end
 end)
 if (player:GetAttribute("HubArrivalSerial") or 0) > 0 then frameArrival() end
end

return HubArrivalCameraController
