-- Generates Smooth Terrain Rolling Hills in Roblox Studio Command Bar / Runner
-- Plan A: Roblox Smooth Terrain (Grass Voxel) Gentle Undulating Ridges matching 180843.png

local Workspace = game:GetService("Workspace")
local terrain = Workspace.Terrain

-- 1. Enable 3D Procedural Grass Decoration
terrain.Decoration = true
if terrain.GrassLength ~= nil then
	terrain.GrassLength = 0.7
end

-- 2. Rolling Hills Spheres (36 spheres surrounding Track01 at >= 50 studs clearance)
local ROLLING_HILLS_SPHERES = {
	-- North Ridge (along Z = 750 to 1100, spanning X = -350 to +350)
	{ pos = Vector3.new(0, -35, 920), radius = 70 },
	{ pos = Vector3.new(120, -42, 960), radius = 78 },
	{ pos = Vector3.new(-110, -38, 940), radius = 74 },
	{ pos = Vector3.new(230, -48, 910), radius = 78 },
	{ pos = Vector3.new(-220, -48, 900), radius = 78 },
	{ pos = Vector3.new(330, -52, 860), radius = 75 },
	{ pos = Vector3.new(-320, -52, 850), radius = 75 },
	{ pos = Vector3.new(60, -35, 840), radius = 60 },
	{ pos = Vector3.new(-70, -35, 830), radius = 60 },
	{ pos = Vector3.new(170, -40, 850), radius = 62 },
	{ pos = Vector3.new(-180, -40, 840), radius = 62 },

	-- South Ridge (along Z = -650 to -1000, spanning X = -350 to +350)
	{ pos = Vector3.new(0, -35, -780), radius = 70 },
	{ pos = Vector3.new(-110, -42, -820), radius = 78 },
	{ pos = Vector3.new(120, -38, -800), radius = 74 },
	{ pos = Vector3.new(-230, -48, -760), radius = 78 },
	{ pos = Vector3.new(220, -48, -750), radius = 78 },
	{ pos = Vector3.new(-330, -52, -720), radius = 75 },
	{ pos = Vector3.new(320, -52, -710), radius = 75 },
	{ pos = Vector3.new(-50, -35, -700), radius = 60 },
	{ pos = Vector3.new(60, -35, -690), radius = 60 },
	{ pos = Vector3.new(-160, -40, -710), radius = 62 },
	{ pos = Vector3.new(170, -40, -700), radius = 62 },

	-- East Flank (outer curve transition, along X = 500 to 750)
	{ pos = Vector3.new(580, -42, 100), radius = 72 },
	{ pos = Vector3.new(620, -46, 280), radius = 76 },
	{ pos = Vector3.new(600, -46, -120), radius = 76 },
	{ pos = Vector3.new(530, -38, 440), radius = 64 },
	{ pos = Vector3.new(510, -38, -320), radius = 64 },
	{ pos = Vector3.new(480, -34, 180), radius = 55 },
	{ pos = Vector3.new(470, -34, -40), radius = 55 },

	-- West Flank (outer straight transition, along X = -500 to -750)
	{ pos = Vector3.new(-560, -42, 100), radius = 72 },
	{ pos = Vector3.new(-610, -46, 280), radius = 76 },
	{ pos = Vector3.new(-590, -46, -120), radius = 76 },
	{ pos = Vector3.new(-520, -38, 440), radius = 64 },
	{ pos = Vector3.new(-500, -38, -320), radius = 64 },
	{ pos = Vector3.new(-470, -34, 180), radius = 55 },
	{ pos = Vector3.new(-460, -34, -40), radius = 55 },
}

local groundY = 0
for i, s in ROLLING_HILLS_SPHERES do
	local center = Vector3.new(s.pos.X, groundY + s.pos.Y, s.pos.Z)
	terrain:FillBall(center, s.radius, Enum.Material.Grass)
end

print(string.format("[KDM:Terrain] Successfully generated %d rolling hills Smooth Terrain spheres with 3D grass decoration!", #ROLLING_HILLS_SPHERES))
