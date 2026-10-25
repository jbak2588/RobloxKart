local TrackCatalog = {
	DefaultId = "Track01",
	Order = { "Track01", "Track01Desert", "Track01Race", "Track02", "Track03" },
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
			-- Existing forward-facing launch slots; the optional Bot uses the final slot.
			GridSlots = {
				CFrame.new(-98.898394282067, 0, 125.031263841772) * CFrame.Angles(0, 2.520066031181, 0),
				CFrame.new(-111.906242059067, 0, 115.714832324772) * CFrame.Angles(0, 2.520066031181, 0),
				CFrame.new(-84.923747007067, 0, 105.519492175772) * CFrame.Angles(0, 2.520066031181, 0),
				CFrame.new(-97.931594785067, 0, 96.203060658772) * CFrame.Angles(0, 2.520066031181, 0),
			},
		},
		Track01Desert = {
			Id = "Track01Desert",
			PreviewImageAssetId = "rbxassetid://75369478362729",
			DisplayName = "Figure-8 Desert Canyon",
			ModelName = "TestTrack",
			GeometryId = "PracticeFigure8V1",
			MatchType = "PUBLIC_RACE",
			MinPlayers = 1,
			MaxPlayers = 4,
			PreviewRotationDegrees = 0,
			TargetLaps = 3,
			BotAllowed = true,
			-- Existing forward-facing launch slots; the optional Bot uses the final slot.
			GridSlots = {
				CFrame.new(-98.898394282067, 0, 125.031263841772) * CFrame.Angles(0, 2.520066031181, 0),
				CFrame.new(-111.906242059067, 0, 115.714832324772) * CFrame.Angles(0, 2.520066031181, 0),
				CFrame.new(-84.923747007067, 0, 105.519492175772) * CFrame.Angles(0, 2.520066031181, 0),
				CFrame.new(-97.931594785067, 0, 96.203060658772) * CFrame.Angles(0, 2.520066031181, 0),
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
			DisplayName = "Prototype V2B TEST",
			ModelName = "TestTrack",
			GeometryId = "PrototypeCircuitV2B",
			MatchType = "PUBLIC_RACE",
			MinPlayers = 1,
			MaxPlayers = 4,
			PreviewRotationDegrees = 0,
			TargetLaps = 2,
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
			DisplayName = "KDM Hard Track",
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

function TrackCatalog.botAllowed(trackId)
	local track = TrackCatalog.Entries[trackId]
	return track ~= nil and track.BotAllowed == true and track.MatchType == "PUBLIC_RACE" and track.MaxPlayers >= 2
end

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
