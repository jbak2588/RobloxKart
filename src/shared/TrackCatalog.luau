local TrackCatalog = {
	DefaultId = "Track01",
	Order = { "Track01", "Track01Race", "Track02" },
	Entries = {
		Track01 = {
			Id = "Track01",
			DisplayName = "Practice Circuit",
			ModelName = "TestTrack",
			GeometryId = "PracticeCircuitV1",
			-- Original V1 grid slots from 88de2b3. The server adds ground height.
			GridSlots = {
				CFrame.new(-350, 0, 465),
				CFrame.new(-340, 0, 465),
				CFrame.new(-355, 0, 480),
				CFrame.new(-345, 0, 480),
			},
		},
		Track01Race = {
			Id = "Track01Race",
			DisplayName = "Practice Circuit",
			ModelName = "TestTrack",
			GeometryId = "PracticeCircuitV1",
			-- Original V1 grid slots from 88de2b3. The server adds ground height.
			GridSlots = {
				CFrame.new(-350, 0, 465),
				CFrame.new(-340, 0, 465),
				CFrame.new(-355, 0, 480),
				CFrame.new(-345, 0, 480),
			},
		},
		Track02 = {
			Id = "Track02",
			DisplayName = "Prototype Circuit V2",
			ModelName = "TestTrack",
			GeometryId = "PrototypeCircuitV2",
			GridSlots = {
				CFrame.new(-365, 0, 465),
				CFrame.new(-355, 0, 465),
				CFrame.new(-365, 0, 480),
				CFrame.new(-355, 0, 480),
			},
		},
	},
}

return table.freeze(TrackCatalog)
