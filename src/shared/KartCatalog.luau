local KartCatalog = {
	DefaultId = "Kart01",
	Order = { "Kart01", "Kart02", "Kart03", "Kart04" },
	Entries = {
		Kart01 = {
			Id = "Kart01",
			DisplayName = "Sprint V1",
			VisualModelName = "SprintV1",
			BodyColor = Color3.fromRGB(220, 45, 45),
			AccentColor = Color3.fromRGB(245, 245, 235),
		},
		Kart02 = {
			Id = "Kart02",
			DisplayName = "Sprint V1 White",
			VisualModelName = "SprintV1",
			BodyColor = Color3.fromRGB(240, 240, 240),
			AccentColor = Color3.fromRGB(245, 245, 235),
		},
		Kart03 = {
			Id = "Kart03",
			DisplayName = "Sprint V1 Blue",
			VisualModelName = "SprintV1",
			BodyColor = Color3.fromRGB(45, 115, 230),
			AccentColor = Color3.fromRGB(245, 245, 235),
		},
		Kart04 = {
			Id = "Kart04",
			DisplayName = "Sprint V1 Yellow",
			VisualModelName = "SprintV1",
			BodyColor = Color3.fromRGB(250, 200, 45),
			AccentColor = Color3.fromRGB(245, 245, 235),
		},
	},
}

return table.freeze(KartCatalog)
