-- One short-lived summary per live job. This directory is display metadata only.
local KDMServerPresence = {}
KDMServerPresence.__index = KDMServerPresence
KDMServerPresence.MAP_NAME = "KDM_ServerPresence_v1"
KDMServerPresence.TTL_SECONDS = 30
KDMServerPresence.HEARTBEAT_SECONDS = 9

-- Resolve once at boot; published jobs retain their real identity unchanged.
function KDMServerPresence.resolveJobKey(jobId, isStudio, guidFactory)
	if type(jobId) == "string" and jobId ~= "" then return jobId end
	if jobId == "" and isStudio then return "studio-" .. guidFactory() end
	return jobId
end

function KDMServerPresence.new(map, jobId, role, trackId, now)
	return setmetatable({ map = map, jobId = jobId, role = role,
		trackId = trackId, now = now or os.time, lastGood = nil }, KDMServerPresence)
end

function KDMServerPresence:publish(players)
	local count = 0
	for _, player in players do
		if self.role ~= "HUB" or player:GetAttribute("KDMRoutePending") ~= "RACE_LAUNCH" then
			count += 1
		end
	end
	local record = { jobId = self.jobId, role = self.role, trackId = self.trackId,
		playerCount = count, updatedAt = self.now() }
	self.map:SetAsync(self.jobId, record, self.TTL_SECONDS, record.updatedAt)
	return record
end

function KDMServerPresence:remove()
	self.map:RemoveAsync(self.jobId)
end

function KDMServerPresence:aggregate()
	local ok, result = pcall(function()
		local lobby, inRace, bound = 0, 0, nil
		while true do
			local rows = self.map:GetRangeAsync(Enum.SortDirection.Ascending, 100, bound)
			for _, row in rows do
				local record = row.value
				if type(record) == "table" and type(record.playerCount) == "number"
					and type(record.updatedAt) == "number"
					and self.now() - record.updatedAt < self.TTL_SECONDS then
					local count = math.max(0, math.floor(record.playerCount))
					if record.role == "HUB" then lobby += count
					elseif record.role == "RACE" then inRace += count end
				end
			end
			if #rows < 100 then break end
			local last = rows[#rows]
			bound = { key = last.key, sortKey = last.sortKey }
		end
		return { online = lobby + inRace, lobby = lobby, inRace = inRace,
			updatedAt = self.now(), stale = false }
	end)
	if ok then self.lastGood = result; return result end
	warn("[KDMPresence] aggregation failed: " .. tostring(result))
	if self.lastGood then
		return { online = self.lastGood.online, lobby = self.lastGood.lobby,
			inRace = self.lastGood.inRace, updatedAt = self.lastGood.updatedAt, stale = true }
	end
	return { stale = true }
end

return KDMServerPresence
