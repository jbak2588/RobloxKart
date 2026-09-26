local DriverAppearance = {}

-- Shared by the Garage preview (including its fallback) and the seated driver.
-- Hats/helmets are deferred to character customization; keep faces visible.
function DriverAppearance.applyHairStyle(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	for _, name in { "KartDriverHelmet", "KartDriverHair" } do
		local previous = character:FindFirstChild(name)
		if previous then
			previous:Destroy()
		end
	end
	-- Preserve accessories: hats stay hidden and inherited hair is restored.
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") and (accessory.AccessoryType == Enum.AccessoryType.Hat
			or accessory.AccessoryType == Enum.AccessoryType.Hair) then
			for _, part in accessory:GetDescendants() do
				if part:IsA("BasePart") then
					if accessory.AccessoryType == Enum.AccessoryType.Hat then
						part.Transparency = 1
					else
						local original = part:GetAttribute("KartOriginalHairTransparency")
						if type(original) ~= "number" then
							original = if part.Transparency < 1 then part.Transparency else 0
							part:SetAttribute("KartOriginalHairTransparency", original)
						end
						part.Transparency = original
					end
				end
			end
		end
	end
end

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

	DriverAppearance.applyHairStyle(character)
end

return DriverAppearance
