-- Stable race pickup metadata. Only Nitro has gameplay in C1-A.
return table.freeze({
	Nitro = table.freeze({ Id = "Nitro", DisplayName = "NITRO", Type = "Boost", TargetMode = "Self" }),
	Slick = table.freeze({ Id = "Slick", DisplayName = "SLICK", Type = "Attack", TargetMode = "Behind" }),
	Shield = table.freeze({ Id = "Shield", DisplayName = "SHIELD", Type = "Defense", TargetMode = "Self" }),
	Smoke = table.freeze({ Id = "Smoke", DisplayName = "SMOKE", Type = "Attack", TargetMode = "Behind" }),
})
