-- Stable race pickup metadata. Smoke remains deferred.
return table.freeze({
	Nitro = table.freeze({ Id = "Nitro", DisplayName = "NITRO", Type = "Boost", TargetMode = "Self" }),
	Slick = table.freeze({ Id = "Slick", DisplayName = "SLICK", Type = "Attack", TargetMode = "DropBehind" }),
	Shield = table.freeze({ Id = "Shield", DisplayName = "SHIELD", Type = "Defense", TargetMode = "Self" }),
	Smoke = table.freeze({ Id = "Smoke", DisplayName = "SMOKE", Type = "Attack", TargetMode = "Behind" }),
})
