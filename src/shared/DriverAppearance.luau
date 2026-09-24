local DriverAppearance = {}

function DriverAppearance.applyToCharacter(character: Model, driver: { [string]: any })
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head")
	if not humanoid or not head or not head:IsA("BasePart") then
		return
	end

	local colors = character:FindFirstChildOfClass("BodyColors") :: BodyColors?
	if not colors then
		colors = Instance.new("BodyColors")
		colors.Parent = character
	end
	colors.TorsoColor3 = driver.Theme
	colors.LeftArmColor3 = driver.Theme
	colors.RightArmColor3 = driver.Theme
	colors.LeftLegColor3 = driver.Theme
	colors.RightLegColor3 = driver.Theme

	local helmet = character:FindFirstChild("KartDriverHelmet")
	if not helmet or not helmet:IsA("BasePart") then
		helmet = Instance.new("Part")
		helmet.Name = "KartDriverHelmet"
		helmet.Shape = Enum.PartType.Ball
		helmet.Size = Vector3.new(2.1, 1.1, 2.1)
		helmet.CanCollide = false
		helmet.CanTouch = false
		helmet.CanQuery = false
		helmet.Massless = true
		helmet.CFrame = head.CFrame * CFrame.new(0, 0.65, 0)
		helmet.Parent = character
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = helmet
		weld.Parent = helmet
	end
	helmet.Color = driver.Theme
end

return DriverAppearance
