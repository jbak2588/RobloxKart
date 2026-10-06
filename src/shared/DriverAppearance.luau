local DriverAppearance = {}

-- Legacy DriverId API compatibility only. Roblox Avatar owns visible identity.
function DriverAppearance.applyHairStyle(_character: Model)
end

function DriverAppearance.applyToCharacter(_character: Model, _driver: { [string]: any })
end

return DriverAppearance
