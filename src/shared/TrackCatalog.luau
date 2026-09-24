local TrackCatalog = {
	DefaultId = "Track01",
	Order = { "Track01" },
	Entries = {
		Track01 = {
			Id = "Track01",
			DisplayName = "Prototype Circuit",
			ModelName = "TestTrack",
			-- World X/Z positions; the server adds ground height when placing a kart.
			GridSlots = {
				CFrame.new(-350, 0, 465),
				CFrame.new(-340, 0, 465),
				CFrame.new(-355, 0, 480),
				CFrame.new(-345, 0, 480),
			},
		},
	},
}

return table.freeze(TrackCatalog)
