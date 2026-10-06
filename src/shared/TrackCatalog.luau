local TrackCatalog = {
	DefaultId = "Track01",
	Order = { "Track01", "Track01Race", "Track02", "Track03" },
	Entries = {
		Track01 = {
			Id = "Track01",
			PreviewImageAssetId = "rbxassetid://132968191916633",
			DisplayName = "Practice Circuit",
			ModelName = "TestTrack",
			GeometryId = "PracticeCircuitV1",
			MatchType = "SOLO_PRACTICE",
			MinPlayers = 1,
			MaxPlayers = 1,
			PreviewRotationDegrees = 0,
			TargetLaps = 1,
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
			PreviewImageAssetId = "rbxassetid://129972226920253",
			DisplayName = "Base Circuit",
			ModelName = "TestTrack",
			GeometryId = "PracticeCircuitV1",
			MatchType = "PUBLIC_RACE",
			MinPlayers = 1,
			MaxPlayers = 4,
			PreviewRotationDegrees = 90,
			TargetLaps = 2,
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
			PreviewImageAssetId = "rbxassetid://104449535838897",
			DisplayName = "Prototype Circuit V2",
			ModelName = "TestTrack",
			GeometryId = "PrototypeCircuitV2",
			MatchType = "SOLO_PROTOTYPE",
			MinPlayers = 1,
			MaxPlayers = 1,
			PreviewRotationDegrees = 0,
			TargetLaps = 3,
			GridSlots = {
				CFrame.new(-365, 0, 465),
				CFrame.new(-355, 0, 465),
				CFrame.new(-365, 0, 480),
				CFrame.new(-355, 0, 480),
			},
		},
		Track03 = {
			Id = "Track03",
			PreviewImageAssetId = "rbxassetid://104244063916395",
			DisplayName = "KDM Hard Circuit",
			ModelName = "TestTrack",
			GeometryId = "HardCircuitV1",
			MatchType = "PUBLIC_RACE",
			MinPlayers = 1,
			MaxPlayers = 4,
			PreviewRotationDegrees = 180.011251,
			TargetLaps = 2,
			GridSlots = {
				CFrame.new(-370, 0, 465),
				CFrame.new(-350, 0, 473),
				CFrame.new(-370, 0, 489),
				CFrame.new(-350, 0, 497),
			},
		},
	},
}

function TrackCatalog.capabilityLabel(track)
	local laps = string.format("%d %s", track.TargetLaps, if track.TargetLaps == 1 then "LAP" else "LAPS")
	if track.MatchType == "PUBLIC_RACE" then
		return string.format("PUBLIC RACE • %d–%d RACERS • %s", track.MinPlayers, track.MaxPlayers, laps)
	end
	return string.format("%s • %s", if track.MatchType == "SOLO_PRACTICE" then "SOLO PRACTICE" else "SOLO PROTOTYPE", laps)
end

function TrackCatalog.previewKey(track)
	return string.format("%s:%d", track.Id, track.PreviewRotationDegrees)
end

return table.freeze(TrackCatalog)
