-- Exact P2B capability/configuration inverse; unrelated bytes remain detectable.
return function(source)
 source=source:gsub("\r\n","\n")
 local function replace(current,prior)
  local first=source:find(current,1,true)
  if first then source=source:sub(1,first-1)..prior..source:sub(first+#current) end
 end
 replace("not TrackCatalog.botAllowed(self.trackId)","self.trackId~=\"Track01Race\"")
 replace("not TrackCatalog.botAllowed(record.trackId)","record.trackId ~= \"Track01Race\"")
 replace("local TrackCatalog=require(game:GetService(\"ReplicatedStorage\"):WaitForChild(\"Shared\"):WaitForChild(\"TrackCatalog\"))\nlocal ActiveMatchDirectory = {}","local ActiveMatchDirectory = {}")
 replace("TrackCatalog.botAllowed(record.trackId)","record.trackId == \"Track01Race\"")
 replace("productionRecord.state:SetAttribute(\"GridSlot\", TrackCatalog.Entries[productionRecord.state:GetAttribute(\"SelectedTrackId\")].MaxPlayers)","productionRecord.state:SetAttribute(\"GridSlot\", 4)")
 replace("or session:humanCount() == 0 or not TrackCatalog.botAllowed(options.trackId)\n\t\tor not track or track.MaxPlayers < 2 or options.gridSlot ~= track.MaxPlayers","or session:humanCount() == 0 or options.trackId ~= \"Track01Race\"\n\t\tor options.gridSlot ~= TrackCatalog.Entries.Track01Race.MaxPlayers")
 replace("function Controller.addProductionBot(options)\n\tlocal session = Session.active()\n\tlocal track = TrackCatalog.Entries[options.trackId]","function Controller.addProductionBot(options)\n\tlocal session = Session.active()")
 replace("track and TrackCatalog.botAllowed(options.trackId)","track and track.Id == \"Track01Race\"")
 replace("function TrackCatalog.botAllowed(trackId)\n\tlocal track = TrackCatalog.Entries[trackId]\n\treturn track ~= nil and track.BotAllowed == true and track.MatchType == \"PUBLIC_RACE\" and track.MaxPlayers >= 2\nend\n\nfunction TrackCatalog.capabilityLabel(track)","function TrackCatalog.capabilityLabel(track)")
 replace("TargetLaps = 2,\n\t\t\tBotAllowed = true,\n\t\t\t-- Original V1","TargetLaps = 2,\n\t\t\t-- Original V1")
 replace("TargetLaps = 3,\n\t\t\tBotAllowed = true,\n\t\t\t-- Existing forward-facing launch slots; the optional Bot uses the final slot.","TargetLaps = 2,\n\t\t\t-- Reserved forward-facing slots on the launch straight; capacity stays solo.")
 replace("MaxPlayers = 4","MaxPlayers = 1")
 replace("MatchType = \"PUBLIC_RACE\"","MatchType = \"SOLO_PRACTICE\"")
 return source
end
