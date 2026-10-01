-- Stable race item metadata; five implemented items, four active slots.
return table.freeze({
	Nitro = table.freeze({ Id = "Nitro", DisplayName = "NITRO", Type = "Boost", TargetMode = "Self", Implemented = true, InitialCharges = 1, MaxCharges = 2 }),
	Slick = table.freeze({ Id = "Slick", DisplayName = "SLICK", Type = "Attack", TargetMode = "DropBehind", Implemented = true, InitialCharges = 1, MaxCharges = 1 }),
	Shield = table.freeze({ Id = "Shield", DisplayName = "SHIELD", Type = "Defense", TargetMode = "Self", Implemented = true, InitialCharges = 1, MaxCharges = 1 }),
	Missile = table.freeze({ Id = "Missile", DisplayName = "MISSILE", Type = "Attack", TargetMode = "ImmediateAhead", Implemented = true, InitialCharges = 1, MaxCharges = 1 }),
	Smoke = table.freeze({ Id = "Smoke", DisplayName = "SMOKE", Type = "Attack", TargetMode = "DropBehind", Implemented = true, InitialCharges = 1, MaxCharges = 1 }),
})
