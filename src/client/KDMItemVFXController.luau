-- Short observer-visible Slick tire cue. Server state alone starts it.
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KDMItemVFXConfig"))
local Controller = {}
local stop
function Controller.start()
	if stop then return end
	local records, connections = {}, {}
	local function clearEffect(record)
		if record.effect then record.effect:Destroy(); record.effect = nil end
	end
	local function remove(kart)
		local record = records[kart]
		if not record then return end
		clearEffect(record)
		for _, connection in record.connections do connection:Disconnect() end
		records[kart] = nil
	end
	local function bind(kart)
		if records[kart] or not kart:IsA("Model") or kart:GetAttribute("PrototypeKart") ~= true then return end
		local record = { connections = {}, previous = kart:GetAttribute("KartSlickActive") == true }
		records[kart] = record
		table.insert(record.connections, kart:GetAttributeChangedSignal("KartSlickActive"):Connect(function()
			local active = kart:GetAttribute("KartSlickActive") == true
			clearEffect(record)
			local chassis = kart.PrimaryPart
			if active and not record.previous and chassis and kart:GetAttribute("RaceControlsLocked") ~= true then
				local model = Instance.new("Model")
				model.Name = "KDMSlickTireCue"
				for _, side in {-1, 1} do
					local puff = Instance.new("Part")
					puff.Name, puff.Shape = "TirePuff", Enum.PartType.Ball
					puff.Size, puff.Color = Vector3.new(1.5,.65,1.8), Color3.fromRGB(165,175,185)
					puff.CFrame = chassis.CFrame*CFrame.new(side*2.7, .15, 2.3)
					puff.Transparency, puff.CastShadow = .72, false
					puff.Anchored, puff.CanCollide, puff.CanTouch, puff.CanQuery = true, false, false, false
					puff.Parent = model
				end
				model.Parent, record.effect = Workspace, model
				Debris:AddItem(model, Config.Slick.VisualSmokeLifetime)
			end
			record.previous = active
		end))
		for _, attribute in {"RaceResetSerial", "RaceControlsLocked"} do
			table.insert(record.connections, kart:GetAttributeChangedSignal(attribute):Connect(function() clearEffect(record) end))
		end
		table.insert(record.connections, kart.Destroying:Connect(function() remove(kart) end))
	end
	local prototype = Workspace:WaitForChild("Prototype")
	for _, instance in prototype:GetDescendants() do bind(instance) end
	table.insert(connections, prototype.DescendantAdded:Connect(bind))
	table.insert(connections, prototype.DescendantRemoving:Connect(remove))
	stop = function()
		for kart in records do remove(kart) end
		for _, connection in connections do connection:Disconnect() end
		stop = nil
	end
	table.insert(connections, prototype.Destroying:Connect(function() Controller.destroy() end))
	table.insert(connections, Players.LocalPlayer.AncestryChanged:Connect(function(_, parent) if not parent then Controller.destroy() end end))
end
function Controller.destroy() if stop then stop() end end
return Controller
