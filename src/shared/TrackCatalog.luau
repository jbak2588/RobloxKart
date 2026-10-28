local TrackCatalog = {
	DefaultId = "Track01",
	Order = { "Track01", "Track01Desert", "Track01Race", "Track03" },
	Entries = {
		Track01 = {
			Id = "Track01",
			PreviewImageAssetId = "rbxassetid://75369478362729",
			DisplayName = "Figure-8 Green Island",
			ModelName = "TestTrack",
			GeometryId = "PracticeFigure8V1",
			MatchType = "PUBLIC_RACE",
			MinPlayers = 1,
			MaxPlayers = 4,
			PreviewRotationDegrees = 0,
			TargetLaps = 3,
			BotAllowed = true,
			-- Park-style paint centers: front left/right, then second-row left/right.
			GridSlots = {
				CFrame.new(-91.109069824219, 0.000000000000, 124.459968566895, -0.812990486622, 0.000000000000, 0.582276999950, 0.000000000000, 1.000000000000, 0.000000000000, -0.582276999950, 0.000000000000, -0.812990486622),
				CFrame.new(-113.872802734375, 0.000000000000, 108.156211853027, -0.812990486622, 0.000000000000, 0.582276999950, 0.000000000000, 1.000000000000, 0.000000000000, -0.582276999950, 0.000000000000, -0.812990486622),
				CFrame.new(-73.640762329102, 0.000000000000, 100.070259094238, -0.812990486622, 0.000000000000, 0.582276999950, 0.000000000000, 1.000000000000, 0.000000000000, -0.582276999950, 0.000000000000, -0.812990486622),
				CFrame.new(-96.404495239258, 0.000000000000, 83.766502380371, -0.812990486622, 0.000000000000, 0.582276999950, 0.000000000000, 1.000000000000, 0.000000000000, -0.582276999950, 0.000000000000, -0.812990486622),
			},
		},
		Track01Desert = {
			Id = "Track01Desert",
			PreviewImageAssetId = "rbxassetid://83402336096508",
			DisplayName = "Figure-8 Desert Canyon",
			ModelName = "TestTrack",
			GeometryId = "PracticeFigure8V1",
			MatchType = "PUBLIC_RACE",
			MinPlayers = 1,
			MaxPlayers = 4,
			PreviewRotationDegrees = 0,
			TargetLaps = 3,
			BotAllowed = true,
			-- Park-style paint centers: front left/right, then second-row left/right.
			GridSlots = {
				CFrame.new(-91.109069824219, 0.000000000000, 124.459968566895, -0.812990486622, 0.000000000000, 0.582276999950, 0.000000000000, 1.000000000000, 0.000000000000, -0.582276999950, 0.000000000000, -0.812990486622),
				CFrame.new(-113.872802734375, 0.000000000000, 108.156211853027, -0.812990486622, 0.000000000000, 0.582276999950, 0.000000000000, 1.000000000000, 0.000000000000, -0.582276999950, 0.000000000000, -0.812990486622),
				CFrame.new(-73.640762329102, 0.000000000000, 100.070259094238, -0.812990486622, 0.000000000000, 0.582276999950, 0.000000000000, 1.000000000000, 0.000000000000, -0.582276999950, 0.000000000000, -0.812990486622),
				CFrame.new(-96.404495239258, 0.000000000000, 83.766502380371, -0.812990486622, 0.000000000000, 0.582276999950, 0.000000000000, 1.000000000000, 0.000000000000, -0.582276999950, 0.000000000000, -0.812990486622),
			},
		},
		Track01Race = {
			Id = "Track01Race",
			PreviewImageAssetId = "rbxassetid://129972226920253",
			DisplayName = "Base Track",
			ModelName = "TestTrack",
			GeometryId = "PracticeCircuitV1",
			MatchType = "PUBLIC_RACE",
			MinPlayers = 1,
			MaxPlayers = 4,
			PreviewRotationDegrees = 90,
			TargetLaps = 2,
			BotAllowed = true,
			-- Park-style paint centers. The server adds the existing ground/seat lift.
			GridSlots = {
				CFrame.new(-365.304229736328, 0.000000000000, 467.451538085938, 0.999997917913, 0, -0.002040629532, 0, 1, 0, 0.002040629532, 0, 0.999997917913),
				CFrame.new(-337.744354248047, 0.000000000000, 472.396484375000, 0.999997917913, 0, -0.002040629532, 0, 1, 0, 0.002040629532, 0, 0.999997917913),
				CFrame.new(-371.999206542969, 0.000000000000, 493.748382568359, 0.999997917913, 0, -0.002040629532, 0, 1, 0, 0.002040629532, 0, 0.999997917913),
				CFrame.new(-345.970886230469, 0.000000000000, 504.069610595703, 0.999997917913, 0, -0.002040629532, 0, 1, 0, 0.002040629532, 0, 0.999997917913),
			},
		},
		Track02 = {
			Id = "Track02",
			PreviewImageAssetId = "rbxassetid://104449535838897",
			DisplayName = "Prototype V2B TEST",
			ModelName = "TestTrack",
			GeometryId = "PrototypeCircuitV2B",
			MatchType = "PUBLIC_RACE",
			MinPlayers = 1,
			MaxPlayers = 4,
			PreviewRotationDegrees = 0,
			TargetLaps = 2,
			GridSlots = {
				CFrame.new(-374.854431152344, 0.000000000000, 458.995788574219, 0.999999357528, 0, -0.001133553765, 0, 1, 0, 0.001133553765, 0, 0.999999357528),
				CFrame.new(-346.924011230469, 0.000000000000, 460.968811035156, 0.999999357528, 0, -0.001133553765, 0, 1, 0, 0.001133553765, 0, 0.999999357528),
				CFrame.new(-377.234313964844, 0.000000000000, 488.947265625000, 0.999999357528, 0, -0.001133553765, 0, 1, 0, 0.001133553765, 0, 0.999999357528),
				CFrame.new(-349.297363281250, 0.000000000000, 490.825439453125, 0.999999357528, 0, -0.001133553765, 0, 1, 0, 0.001133553765, 0, 0.999999357528),
			},
		},
		Track03 = {
			Id = "Track03",
			PreviewImageAssetId = "rbxassetid://104244063916395",
			DisplayName = "KDM Hard Track",
			ModelName = "TestTrack",
			GeometryId = "HardCircuitV1",
			MatchType = "PUBLIC_RACE",
			MinPlayers = 1,
			MaxPlayers = 4,
			PreviewRotationDegrees = 180.011251,
			TargetLaps = 2,
			GridSlots = {
				CFrame.new(-374.018218994141, 0.000000000000, 459.985900878906, 0.999999980733, 0, -0.000196302536, 0, 1, 0, 0.000196302536, 0, 0.999999980733),
				CFrame.new(-346.018218994141, 0.000000000000, 460.014099121094, 0.999999980733, 0, -0.000196302536, 0, 1, 0, 0.000196302536, 0, 0.999999980733),
				CFrame.new(-374.045471191406, 0.000000000000, 489.992309570312, 0.999999980733, 0, -0.000196302536, 0, 1, 0, 0.000196302536, 0, 0.999999980733),
				CFrame.new(-346.045471191406, 0.000000000000, 490.007690429688, 0.999999980733, 0, -0.000196302536, 0, 1, 0, 0.000196302536, 0, 0.999999980733),
			},
		},
	},
}

-- New theme has its own room/record/rematch identity; the original Base is intact.
local metro = table.clone(TrackCatalog.Entries.Track01Race)
metro.Id = 'Track01Metro'
metro.DisplayName = 'Metro City Circuit'
metro.PreviewImageAssetId = 'rbxassetid://125455433974318'
metro.GridSlots = table.clone(TrackCatalog.Entries.Track01Race.GridSlots)
TrackCatalog.Entries.Track01Metro = metro
table.insert(TrackCatalog.Order, 4, metro.Id)

function TrackCatalog.botAllowed(trackId)
	local track = TrackCatalog.Entries[trackId]
	return track ~= nil and track.BotAllowed == true and track.MatchType == "PUBLIC_RACE" and track.MaxPlayers >= 2
end

function TrackCatalog.capabilityLabel(track)
	local laps = string.format("%d %s", track.TargetLaps, if track.TargetLaps == 1 then "LAP" else "LAPS")
	if track.MatchType == "PUBLIC_RACE" then
		return string.format("PUBLIC RACE • %d–%d RACERS • %s", track.MinPlayers, track.MaxPlayers, laps)
	end
	return string.format("%s â€¢ %s", if track.MatchType == "SOLO_PRACTICE" then "SOLO PRACTICE" else "SOLO PROTOTYPE", laps)
end

function TrackCatalog.previewKey(track)
	return string.format("%s:%d", track.Id, track.PreviewRotationDegrees)
end

return table.freeze(TrackCatalog)
