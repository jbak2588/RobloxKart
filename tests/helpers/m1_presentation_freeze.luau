-- Only exact R7-M1 display changes are reversed; unrelated edits remain detectable.
return function(source)
 source=source:gsub("\r\n","\n")
 do local current,prior=[====[		cycleButton.Text = if step == STEP_KART then "USE KART" elseif step == STEP_TRACK and TrackCatalog.Entries[trackId].MatchType == "PUBLIC_RACE" then "LOBBIES" else "SELECT"
]====],[====[		cycleButton.Text = if step == STEP_KART then "USE KART" elseif step == STEP_TRACK and TrackCatalog.Entries[trackId].MatchType == "PUBLIC_RACE" then "ROOMS" else "SELECT"
]====]
 local start=source:find(current,1,true);if start then source=source:sub(1,start-1)..prior..source:sub(start+#current) end end
 do local current,prior=[====[			elseif raceState == "RACING" then string.format("LOBBY %d/%d  •  NEXT %d",
]====],[====[			elseif raceState == "RACING" then string.format("ROOM %d/%d  •  NEXT %d",
]====]
 local start=source:find(current,1,true);if start then source=source:sub(1,start-1)..prior..source:sub(start+#current) end end
 do local current,prior=[====[			availabilityHeading.AutoLocalize=not (roomSnapshot and lobbyWaiting)
			availabilityHeading.TextTruncate=Enum.TextTruncate.AtEnd
			availabilityHeading.Text = if roomSnapshot and lobbyWaiting then roomSnapshot.lobbyTitle or "RACE LOBBY"
				elseif roomSnapshot then string.format("WAITING NEXT  %d", roomSnapshot.queuedCount)
]====],[====[			availabilityHeading.Text = if roomSnapshot then string.format("WAITING NEXT  %d", roomSnapshot.queuedCount)
]====]
 local start=source:find(current,1,true);if start then source=source:sub(1,start-1)..prior..source:sub(start+#current) end end
 do local current,prior=[====[			DisplayName = "Practice Track",
]====],[====[			DisplayName = "Practice Circuit",
]====]
 local start=source:find(current,1,true);if start then source=source:sub(1,start-1)..prior..source:sub(start+#current) end end
 do local current,prior=[====[			DisplayName = "Base Track",
]====],[====[			DisplayName = "Base Circuit",
]====]
 local start=source:find(current,1,true);if start then source=source:sub(1,start-1)..prior..source:sub(start+#current) end end
 do local current,prior=[====[			DisplayName = "Prototype V2 Track",
]====],[====[			DisplayName = "Prototype Circuit V2",
]====]
 local start=source:find(current,1,true);if start then source=source:sub(1,start-1)..prior..source:sub(start+#current) end end
 do local current,prior=[====[			DisplayName = "KDM Hard Track",
]====],[====[			DisplayName = "KDM Hard Circuit",
]====]
 local start=source:find(current,1,true);if start then source=source:sub(1,start-1)..prior..source:sub(start+#current) end end
 do local current,prior=[====[	Base = { Version = 1, KerbRows = 1, SignEvery = 9, SignText = "KDM / BASE TRACK" },
]====],[====[	Base = { Version = 1, KerbRows = 1, SignEvery = 9, SignText = "KDM / BASE CIRCUIT" },
]====]
 local start=source:find(current,1,true);if start then source=source:sub(1,start-1)..prior..source:sub(start+#current) end end
 return source
end
