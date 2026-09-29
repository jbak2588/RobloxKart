-- Racer contact is visual-only during the four-player beta.
local RacerCollisionIsolation = {}
RacerCollisionIsolation.__index = RacerCollisionIsolation

local KART_GROUP = "RacerKart"
local DRIVER_GROUP = "RacerDriver"

function RacerCollisionIsolation.new(physicsService)
	return setmetatable({ physicsService = physicsService }, RacerCollisionIsolation)
end

function RacerCollisionIsolation:configure()
	local physics = self.physicsService
	if not physics then return end
	for _, group in { KART_GROUP, DRIVER_GROUP } do
		if not physics:IsCollisionGroupRegistered(group) then physics:RegisterCollisionGroup(group) end
	end
	physics:CollisionGroupSetCollidable(KART_GROUP, KART_GROUP, false)
	physics:CollisionGroupSetCollidable(KART_GROUP, DRIVER_GROUP, false)
	physics:CollisionGroupSetCollidable(DRIVER_GROUP, DRIVER_GROUP, false)
end

function RacerCollisionIsolation:bindKart(kart: Model)
	if not self.physicsService then return end
	local function assign(descendant)
		if descendant:IsA("BasePart") then descendant.CollisionGroup = KART_GROUP end
	end
	for _, descendant in kart:GetDescendants() do assign(descendant) end
	local added = kart.DescendantAdded:Connect(assign)
	kart.Destroying:Connect(function() added:Disconnect() end)
end

function RacerCollisionIsolation:bindDriver(character: Model)
	if not self.physicsService then return { restore = function() end } end
	local originals = {}
	local function assign(descendant)
		if descendant:IsA("BasePart") then
			if originals[descendant] == nil then originals[descendant] = descendant.CollisionGroup end
			descendant.CollisionGroup = DRIVER_GROUP
		end
	end
	for _, descendant in character:GetDescendants() do assign(descendant) end
	local added = character.DescendantAdded:Connect(assign)
	local binding = {}
	function binding:restore()
		if not added then return end
		added:Disconnect()
		added = nil
		for part, original in originals do
			pcall(function() part.CollisionGroup = original end)
			originals[part] = nil
		end
	end
	return binding
end

function RacerCollisionIsolation:audit(kart: Model, character: Model)
	local kartCount, driverCount, mismatches = 0, 0, 0
	for _, descendant in kart:GetDescendants() do
		if descendant:IsA("BasePart") then
			kartCount += 1
			if descendant.CollisionGroup ~= KART_GROUP then mismatches += 1 end
		end
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			driverCount += 1
			if descendant.CollisionGroup ~= DRIVER_GROUP then mismatches += 1 end
		end
	end
	return kartCount, driverCount, mismatches
end

return RacerCollisionIsolation
